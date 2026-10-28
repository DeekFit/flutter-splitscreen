import Flutter
import UIKit

/// A separate handler per channel keeps cancel/listen independent.
@MainActor
final class EventTransport: NSObject, @preconcurrency FlutterStreamHandler {
    var sink: FlutterEventSink?
    var changed: (@MainActor () -> Void)?
    // Flutter invokes stream handlers on the platform (main) thread. The
    // preconcurrency conformance bridges its legacy nonisolated protocol and
    // checks the main-actor boundary in Swift 6.
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        changed?()
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        changed?()
        return nil
    }
}

@MainActor
final class HierarchyObserver: UIView {
    var changed: (@MainActor () -> Void)?
    override func didMoveToWindow() { super.didMoveToWindow(); changed?() }
    override func didMoveToSuperview() { super.didMoveToSuperview(); changed?() }
    override func layoutSubviews() { super.layoutSubviews(); changed?() }
    override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); changed?() }
}

@MainActor
protocol AttachmentRetryScheduling: AnyObject {
    func schedule(_ retry: @escaping @MainActor () -> Void)
    func cancel()
}

/// Retry only while the registrar has no usable hierarchy. Ready views refresh
/// through UIKit callbacks, so an idle subscription has no periodic work.
@MainActor
final class MainQueueAttachmentRetry: AttachmentRetryScheduling {
    private var work: DispatchWorkItem?
    private var generation = 0

    func schedule(_ retry: @escaping @MainActor () -> Void) {
        cancel()
        let expectedGeneration = generation
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self, self.generation == expectedGeneration else { return }
                self.work = nil
                retry()
            }
        }
        self.work = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func cancel() {
        generation += 1
        work?.cancel()
        work = nil
    }
}

/// View-scoped lifecycle coordinator; injectable providers allow XCTest fixtures.
@MainActor
final class DuoObservation {
    let angle = EventTransport()
    let layout = EventTransport()
    private var viewProvider: (@MainActor () -> UIView?)?
    private let hinge: HingeProviding
    private let regions: RegionProviding
    private let hierarchyIsActive: @MainActor (UIView) -> Bool
    private let attachmentRetry: AttachmentRetryScheduling
    private var observer: HierarchyObserver?
    private weak var attachedScene: UIWindowScene?
    private var attachedWindowID: ObjectIdentifier?
    private var attachedSceneID: ObjectIdentifier?
    private var snapshotBounds: CGRect?
    private var snapshotCoordinates: [CGPoint]?
    private var needsLayoutReplay = false
    private var suspended = false
    private var observing = false
    private var generation = 0
    private var reading: HingeReading?
    private var initialized = false
    private var pending: [UUID: @MainActor (Bool) -> Void] = [:]
    private var timeouts: [UUID: DispatchWorkItem] = [:]
    private var previous: FoldSnapshot?
    private var notifications: [NSObjectProtocol] = []
    private var refreshing = false
    private var tornDown = false

    init(view: @escaping @MainActor () -> UIView?, hinge: HingeProviding, regions: RegionProviding,
         hierarchyIsActive: @escaping @MainActor (UIView) -> Bool = {
             $0.window?.windowScene?.activationState == .foregroundActive
         }, attachmentRetry: AttachmentRetryScheduling? = nil) {
        viewProvider = view
        self.hinge = hinge
        self.regions = regions
        self.hierarchyIsActive = hierarchyIsActive
        self.attachmentRetry = attachmentRetry ?? MainQueueAttachmentRetry()
        angle.changed = { [weak self] in
            guard let self = self else { return }
            if let degrees = self.reading?.degrees { self.angle.sink?(degrees) }
            self.demandChanged()
        }
        layout.changed = { [weak self] in
            guard let self = self else { return }
            self.needsLayoutReplay = self.layout.sink != nil
            self.demandChanged()
            if self.layout.sink != nil { self.observer?.setNeedsLayout() }
        }
        for name in [UIScene.didActivateNotification, UIScene.willDeactivateNotification,
                     UIScene.didEnterBackgroundNotification,
                     UIScene.didDisconnectNotification] {
            notifications.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let scene = notification.object as? UIWindowScene else { return }
                // NotificationCenter's .main queue guarantees this executor.
                MainActor.assumeIsolated {
                    guard let self = self,
                          scene === self.observer?.window?.windowScene || scene === self.attachedScene else { return }
                    self.suspended = name != UIScene.didActivateNotification
                    if name == UIScene.didDisconnectNotification { self.invalidateLayout() }
                    self.refresh()
                }
            })
        }
    }

    func capability(_ completion: @escaping @MainActor (Bool) -> Void) {
        guard !tornDown else { completion(false); return }
        let id = UUID()
        pending[id] = completion
        let timeout = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.resolve(id, value: false) }
        }
        timeouts[id] = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: timeout)
        demandChanged()
        if initialized { resolveAll(reading?.degrees != nil) }
    }

    private var demanded: Bool { angle.sink != nil || layout.sink != nil || !pending.isEmpty }

    private func demandChanged() {
        guard !tornDown else { return }
        if demanded {
            refresh()
        } else {
            attachmentRetry.cancel()
            pause()
            previous = nil
            snapshotBounds = nil
            snapshotCoordinates = nil
            observer?.changed = nil
            observer?.removeFromSuperview()
            observer = nil
        }
    }

    func refresh() {
        guard !tornDown, demanded, !refreshing else { return }
        attachmentRetry.cancel()
        refreshing = true
        defer {
            refreshing = false
            if !tornDown, demanded, !observing, !suspended {
                attachmentRetry.schedule { [weak self] in self?.refresh() }
            }
        }
        guard let view = viewProvider?() else {
            pause()
            invalidateLayout()
            observer?.changed = nil
            observer?.removeFromSuperview()
            observer = nil
            attachedWindowID = nil
            attachedSceneID = nil
            attachedScene = nil
            return
        }
        if observer?.superview !== view {
            pause()
            invalidateLayout()
            observer?.changed = nil
            observer?.removeFromSuperview()
            let anchor = HierarchyObserver(frame: view.bounds)
            anchor.backgroundColor = .clear
            anchor.isUserInteractionEnabled = false
            anchor.isAccessibilityElement = false
            anchor.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            observer = anchor
            anchor.changed = { [weak self] in self?.refresh() }
            view.addSubview(anchor)
            anchor.setNeedsLayout()
        }
        guard let anchor = observer else { pause(); return }
        let scene = anchor.window?.windowScene
        let windowID = anchor.window.map(ObjectIdentifier.init)
        let sceneID = scene.map(ObjectIdentifier.init)
        if attachedWindowID != windowID || attachedSceneID != sceneID {
            pause()
            invalidateLayout()
            attachedWindowID = windowID
            attachedSceneID = sceneID
            attachedScene = scene
            suspended = scene.map { $0.activationState != .foregroundActive } ?? false
        }
        guard !suspended, hierarchyIsActive(anchor) else {
            pause()
            // Discard incompatible cached coordinates without publishing an
            // invented empty region query during suspension. Flutter separately
            // rejects snapshots whose viewport does not match its own metrics.
            if let bounds = snapshotBounds,
               bounds != view.bounds || snapshotCoordinates != coordinates(of: view) {
                snapshotBounds = nil
                snapshotCoordinates = nil
            }
            if needsLayoutReplay, snapshotBounds != nil, let snapshot = previous {
                needsLayoutReplay = false
                layout.sink?(snapshot.payload)
            }
            return
        }
        anchor.frame = view.bounds
        if !observing {
            observing = true
            initialized = false
            generation += 1
            let currentGeneration = generation
            hinge.start(on: anchor) { [weak self] value in
                guard let self = self, self.observing,
                      self.generation == currentGeneration else { return }
                self.initialized = true
                self.reading = value
                if let degrees = value?.degrees { self.angle.sink?(degrees) }
                self.resolveAll(value?.degrees != nil)
                self.publish()
                // UIKit may finish updating regions after the hinge callback.
                // Query once more in layout, where UIKit tracks dependencies.
                if self.layout.sink != nil { self.observer?.setNeedsLayout() }
            }
        }
        publish()
    }

    private func publish() {
        guard observing, layout.sink != nil, let anchor = observer,
              let view = anchor.superview else { return }
        let frames = regions.divisions(in: anchor)
        guard let snapshot = FoldSnapshot.make(view: view, source: anchor, frames: frames,
                                               state: reading?.state ?? "unknown") else { return }
        snapshotBounds = view.bounds
        snapshotCoordinates = coordinates(of: view)
        if !needsLayoutReplay, let old = previous, old.approximatelyEquals(snapshot) { return }
        needsLayoutReplay = false
        previous = snapshot
        layout.sink?(snapshot.payload)
    }

    private func pause() {
        observing = false
        generation += 1
        hinge.stop()
        reading = nil
        initialized = false
    }

    /// Only host/viewport invalidation or an active region query may clear layout.
    /// Sensor suspension must leave the last valid split in place.
    private func invalidateLayout() {
        snapshotBounds = nil
        snapshotCoordinates = nil
        guard let old = previous else { return }
        let empty = FoldSnapshot(size: old.size, frames: [], state: "unknown")
        previous = empty
        if needsLayoutReplay || !old.approximatelyEquals(empty) {
            needsLayoutReplay = false
            layout.sink?(empty.payload)
        }
    }

    // Three points capture the viewport's affine mapping into its window,
    // including movement or transforms that do not change the bounds size.
    private func coordinates(of view: UIView) -> [CGPoint] {
        let bounds = view.bounds
        return [bounds.origin, CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.minX, y: bounds.maxY)].map { view.convert($0, to: view.window) }
    }

    private func resolve(_ id: UUID, value: Bool) {
        timeouts.removeValue(forKey: id)?.cancel()
        let callback = pending.removeValue(forKey: id)
        callback?(value)
        demandChanged()
    }

    private func resolveAll(_ value: Bool) {
        for id in Array(pending.keys) { resolve(id, value: value) }
    }

    func teardown() {
        guard !tornDown else { return }
        tornDown = true
        attachmentRetry.cancel()
        pause()
        invalidateLayout()
        angle.sink = nil
        layout.sink = nil
        angle.changed = nil
        layout.changed = nil
        observer?.changed = nil
        observer?.removeFromSuperview()
        observer = nil
        attachedScene = nil
        attachedWindowID = nil
        attachedSceneID = nil
        viewProvider = nil
        for token in notifications { NotificationCenter.default.removeObserver(token) }
        notifications.removeAll()
        resolveAll(false)
    }
}
