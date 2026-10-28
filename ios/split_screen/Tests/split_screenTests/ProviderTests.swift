import Flutter
import UIKit
import XCTest
@testable import split_screen

private final class FixtureHinge: HingeProviding {
    var callback: ((HingeReading?) -> Void)?
    var starts = 0
    var stops = 0
    func start(on view: UIView, update: @escaping (HingeReading?) -> Void) {
        starts += 1
        callback = update
    }
    func stop() { stops += 1; callback = nil }
    func send(_ reading: HingeReading?) { callback?(reading) }
}

private final class FixtureRegions: RegionProviding {
    var frames: [CGRect] = []
    var queries = 0
    func divisions(in view: UIView) -> [CGRect] { queries += 1; return frames }
}

private final class FixtureAttachmentRetry: AttachmentRetryScheduling {
    var callback: (() -> Void)?
    func schedule(_ retry: @escaping () -> Void) { callback = retry }
    func cancel() { callback = nil }
    func fire() {
        let retry = callback
        callback = nil
        retry?()
    }
}

final class ProviderTests: XCTestCase {
    func testInactivityKeepsGeometryAndResumeQueriesChangedDivisions() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        let retry = FixtureAttachmentRetry()
        var active = true
        regions.frames = [CGRect(x: 390, y: 0, width: 20, height: 600)]
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in active }, attachmentRetry: retry)
        defer { observation.teardown() }
        var snapshots: [[String: Any]] = []
        _ = observation.layout.onListen(withArguments: nil) {
            snapshots.append($0 as! [String: Any])
        }
        let count = snapshots.count
        let queries = regions.queries
        active = false
        observation.refresh()
        regions.frames = [CGRect(x: 300, y: 0, width: 30, height: 600)]
        observation.refresh()
        XCTAssertEqual(snapshots.count, count)
        XCTAssertEqual(regions.queries, queries)
        active = true
        observation.refresh()
        XCTAssertEqual(snapshots.count, count + 1)
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.first?["left"] as? Double, 300)
        // A subsequent authoritative query can remove the split, even with no angle sample.
        regions.frames = []
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
    }

    func testSuspendedLayoutListenerReplaysOnlyCompatibleGeometry() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let view = UIView(frame: window.bounds)
        window.addSubview(view)
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        var active = true
        regions.frames = [CGRect(x: 390, y: 0, width: 20, height: 600)]
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in active })
        defer { observation.teardown() }
        _ = observation.angle.onListen(withArguments: nil) { _ in }
        _ = observation.layout.onListen(withArguments: nil) { _ in }
        active = false
        observation.refresh()
        _ = observation.layout.onCancel(withArguments: nil)
        var snapshots: [[String: Any]] = []
        _ = observation.layout.onListen(withArguments: nil) { snapshots.append($0 as! [String: Any]) }
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
        let queries = regions.queries
        // Same bounds size but a different mapping into the host window.
        let count = snapshots.count
        view.center.x += 10
        observation.refresh()
        XCTAssertEqual(snapshots.count, count)
        XCTAssertEqual(regions.queries, queries)
        _ = observation.layout.onCancel(withArguments: nil)
        snapshots.removeAll()
        _ = observation.layout.onListen(withArguments: nil) { snapshots.append($0 as! [String: Any]) }
        XCTAssertTrue(snapshots.isEmpty) // Incompatible coordinates are never replayed.
        view.removeFromSuperview()
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
    }

    func testSuspendedViewportChangesAndHostReplacementInvalidateCoordinates() {
        var view: UIView? = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        var active = true
        regions.frames = [CGRect(x: 390, y: 0, width: 20, height: 600)]
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in active })
        var snapshots: [[String: Any]] = []
        _ = observation.layout.onListen(withArguments: nil) { snapshots.append($0 as! [String: Any]) }
        active = false
        observation.refresh()
        let count = snapshots.count
        view?.bounds = CGRect(x: 10, y: 20, width: 600, height: 800)
        observation.refresh()
        XCTAssertEqual(snapshots.count, count) // No empty snapshot during suspension.
        regions.frames = [CGRect(x: 0, y: 390, width: 600, height: 20)]
        active = true
        observation.refresh()
        XCTAssertEqual(snapshots.last?["width"] as? Double, 600)
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.first?["top"] as? Double, 390)
        let stale = hinge.callback
        active = false
        let replacement = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        withExtendedLifetime(view) { view = replacement }
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
        stale?(HingeReading(radians: 1, posture: .halfOpened))
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
        active = true
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
        withExtendedLifetime(view) { view = nil }
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
        observation.teardown()
        let teardownCount = snapshots.count
        stale?(nil)
        observation.refresh()
        XCTAssertEqual(snapshots.count, teardownCount)
        XCTAssertNil(hinge.callback)
    }

    func testSceneNotificationsSuspendWithoutClearingAndDisconnectInvalidates() throws {
        // CocoaPods supplies a scene host. SwiftPM's hostless runner may not.
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw XCTSkip("This fixture needs a UIWindowScene host")
        }
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        let view = controller.view!
        window.addSubview(view)
        view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        regions.frames = [CGRect(x: 390, y: 0, width: 20, height: 600)]
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { $0.window != nil })
        defer { observation.teardown() }
        var snapshots: [[String: Any]] = []
        _ = observation.layout.onListen(withArguments: nil) { snapshots.append($0 as! [String: Any]) }
        let count = snapshots.count
        let stale = hinge.callback
        for name in [UIScene.willDeactivateNotification, UIScene.didEnterBackgroundNotification] {
            NotificationCenter.default.post(name: name, object: scene)
            XCTAssertNil(hinge.callback)
            XCTAssertEqual(snapshots.count, count)
        }
        regions.frames = [CGRect(x: 300, y: 0, width: 20, height: 600)]
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertEqual(snapshots.count, count + 1)
        stale?(nil)
        XCTAssertEqual(snapshots.count, count + 1)
        NotificationCenter.default.post(name: UIScene.didDisconnectNotification, object: scene)
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
        // Changing windows at the same size also invalidates cached geometry.
        let replacement = UIWindow(windowScene: scene)
        replacement.addSubview(view)
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
        view.removeFromSuperview()
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
    }

    func testSceneReplacementRejectsOldSceneCallbacks() throws {
        guard UIApplication.shared.supportsMultipleScenes,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw XCTSkip("Scene replacement requires a multi-scene application host")
        }
        let activated = expectation(description: "second scene activation")
        var replacementScene: UIWindowScene?
        let token = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification, object: nil, queue: .main) { notification in
            guard let candidate = notification.object as? UIWindowScene else { return }
            guard candidate !== scene, replacementScene == nil else { return }
            replacementScene = candidate
            activated.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil) { error in
            XCTFail("Could not activate fixture scene: \(error)")
            activated.fulfill()
        }
        wait(for: [activated], timeout: 10)
        let newScene = try XCTUnwrap(replacementScene)
        defer { UIApplication.shared.requestSceneSessionDestruction(newScene.session, options: nil) }
        let window = UIWindow(windowScene: scene)
        let replacementWindow = UIWindow(windowScene: newScene)
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        window.addSubview(view)
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        regions.frames = [CGRect(x: 390, y: 0, width: 20, height: 600)]
        var active = true
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in active })
        defer { observation.teardown() }
        var snapshots: [[String: Any]] = []
        _ = observation.layout.onListen(withArguments: nil) { snapshots.append($0 as! [String: Any]) }
        // Activation is injected here because opening the second scene can
        // deactivate the first scene on this simulator's windowing mode.
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
        let stale = hinge.callback
        active = false
        replacementWindow.addSubview(view)
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
        let count = snapshots.count
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        stale?(nil)
        XCTAssertNil(hinge.callback)
        XCTAssertEqual(snapshots.count, count)
        active = true
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: newScene)
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
    }

    func testReadyAngleSubscriptionDoesNotPollOrQueryRegions() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        let retry = FixtureAttachmentRetry()
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in true }, attachmentRetry: retry)
        defer { observation.teardown() }
        var angles: [Double] = []
        _ = observation.angle.onListen(withArguments: nil) {
            if let value = $0 as? Double { angles.append(value) }
        }
        // Once attached, even waiting for the initial callback needs no polling.
        XCTAssertNil(retry.callback)
        hinge.send(HingeReading(radians: .pi, posture: .flat))
        hinge.send(HingeReading(radians: 0, posture: .unknown))
        XCTAssertEqual(angles, [180, 0])
        XCTAssertEqual(regions.queries, 0)
        XCTAssertNil(retry.callback)

        _ = observation.layout.onListen(withArguments: nil) { _ in }
        XCTAssertGreaterThan(regions.queries, 0)
        _ = observation.layout.onCancel(withArguments: nil)
        let queries = regions.queries
        hinge.send(HingeReading(radians: 1, posture: .halfOpened))
        view.subviews.first?.setNeedsLayout()
        view.subviews.first?.layoutIfNeeded()
        XCTAssertEqual(regions.queries, queries)
        XCTAssertNil(retry.callback)
        _ = observation.angle.onCancel(withArguments: nil)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testLayoutAndHingeCallbacksRefreshLateRegionsWithoutPolling() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        let retry = FixtureAttachmentRetry()
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in true }, attachmentRetry: retry)
        defer { observation.teardown() }
        var snapshots: [[String: Any]] = []
        _ = observation.layout.onListen(withArguments: nil) {
            if let payload = $0 as? [String: Any] { snapshots.append(payload) }
        }
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
        let anchor = view.subviews.first!
        // A division appearing after the provisional empty result is detected
        // by a layout callback even when the hinge has not moved.
        regions.frames = [CGRect(x: 390, y: 0, width: 20, height: 600)]
        anchor.setNeedsLayout()
        anchor.layoutIfNeeded()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
        hinge.send(HingeReading(radians: 1, posture: .halfOpened))
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.first?["state"] as? String,
                       "halfOpened")
        // The region can settle after the hinge callback; layout picks it up.
        regions.frames = []
        anchor.setNeedsLayout()
        anchor.layoutIfNeeded()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
        let count = snapshots.count
        anchor.setNeedsLayout()
        anchor.layoutIfNeeded()
        XCTAssertEqual(snapshots.count, count)
        XCTAssertNil(retry.callback)
    }

    func testOnlyUnattachedSubscriptionsRetryAndCancellationStopsRetries() {
        var view: UIView?
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        let retry = FixtureAttachmentRetry()
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in true }, attachmentRetry: retry)
        defer { observation.teardown() }
        _ = observation.angle.onListen(withArguments: nil) { _ in }
        XCTAssertNotNil(retry.callback)
        XCTAssertEqual(hinge.starts, 0)
        view = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        retry.fire()
        XCTAssertEqual(hinge.starts, 1)
        XCTAssertNil(retry.callback)
        hinge.send(nil) // An ordinary iPhone must also remain idle.
        XCTAssertNil(retry.callback)
        // Releasing UIView synchronously calls didMoveToSuperview on its
        // children. Finish mutating the captured provider before that callback
        // reads it, rather than triggering Swift's exclusive-access trap.
        withExtendedLifetime(view) { view = nil }
        observation.refresh()
        XCTAssertNotNil(retry.callback)
        let cancelledRetry = retry.callback
        _ = observation.angle.onCancel(withArguments: nil)
        XCTAssertNil(retry.callback)
        cancelledRetry?()
        XCTAssertEqual(hinge.starts, 1)
        XCTAssertEqual(regions.queries, 0)
        observation.teardown()
        XCTAssertNil(retry.callback)
    }

    func testGeometryConversionMarginsZeroSeamsAndTolerance() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let source = UIView(frame: CGRect(x: 10, y: 20, width: 780, height: 580))
        root.addSubview(source)
        let frames = [CGRect(x: 380, y: -20, width: 20, height: 600),
                      CGRect(x: -10, y: 280, width: 800, height: 0),
                      CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10)]
        let snapshot = FoldSnapshot.make(view: root, source: source, frames: frames, state: "halfOpened")!
        XCTAssertEqual(snapshot.frames.count, 2)
        XCTAssertTrue(snapshot.frames.contains(CGRect(x: 390, y: 0, width: 20, height: 600)))
        XCTAssertTrue(snapshot.frames.contains(CGRect(x: 0, y: 300, width: 800, height: 0)))
        let near = FoldSnapshot(size: snapshot.size, frames: snapshot.frames.map {
            $0.offsetBy(dx: 0.005, dy: 0)
        }, state: snapshot.state)
        XCTAssertTrue(snapshot.approximatelyEquals(near))
        let different = FoldSnapshot(size: snapshot.size, frames: snapshot.frames.map {
            $0.offsetBy(dx: 0.02, dy: 0)
        }, state: snapshot.state)
        XCTAssertFalse(snapshot.approximatelyEquals(different))
    }

    func testDegreesAndPostureDoNotInventSamples() {
        XCTAssertEqual(HingeReading(radians: .pi, posture: .flat).degrees!, 180, accuracy: 0.0001)
        XCTAssertEqual(HingeReading(radians: 0, posture: .unknown).degrees, 0)
        XCTAssertNil(HingeReading(radians: .nan, posture: .flat).degrees)
        XCTAssertEqual(HingeReading(radians: 1, posture: .halfOpened).state, "halfOpened")
        XCTAssertEqual(HingeReading(radians: 1, posture: .flat).state, "flat")
        XCTAssertEqual(HingeReading(radians: 1, posture: .unknown).state, "unknown")
    }

    func testTransportChannelsCancelIndependently() {
        let angle = EventTransport()
        let layout = EventTransport()
        var angles: [Double] = []
        var layouts = 0
        XCTAssertNil(angle.onListen(withArguments: nil) { if let n = $0 as? Double { angles.append(n) } })
        XCTAssertNil(layout.onListen(withArguments: nil) { _ in layouts += 1 })
        angle.sink?(123.0)
        XCTAssertNil(layout.onCancel(withArguments: nil))
        angle.sink?(0.0)
        XCTAssertEqual(angles, [123,0])
        XCTAssertEqual(layouts, 0)
        XCTAssertNotNil(angle.sink)
        XCTAssertNil(layout.sink)
        _ = angle.onCancel(withArguments: nil)
    }

    func testInitialCallbackLateGeometryPauseResumeAndTeardown() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        var usable = false
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in usable })
        var capabilities: [Bool] = []
        var angles: [Double] = []
        var snapshots: [[String: Any]] = []
        _ = observation.angle.onListen(withArguments: nil) { if let n = $0 as? Double { angles.append(n) } }
        _ = observation.layout.onListen(withArguments: nil) { if let p = $0 as? [String: Any] { snapshots.append(p) } }
        observation.capability { capabilities.append($0) }
        XCTAssertTrue(capabilities.isEmpty)
        XCTAssertEqual(hinge.starts, 0)
        usable = true
        observation.refresh()
        XCTAssertTrue(capabilities.isEmpty) // Must await initial provider callback.
        hinge.send(HingeReading(radians: .pi, posture: .flat))
        XCTAssertEqual(capabilities, [true])
        XCTAssertEqual(angles, [180])
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 0)
        regions.frames = [CGRect(x: 390, y: 0, width: 20, height: 600)]
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
        let count = snapshots.count
        observation.refresh()
        XCTAssertEqual(snapshots.count, count)
        // Only region activity controls publication, regardless of hinge posture.
        hinge.send(HingeReading(radians: 0, posture: .unknown))
        XCTAssertEqual(angles.last, 0)
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
        let staleCallback = hinge.callback
        usable = false
        observation.refresh()
        XCTAssertEqual((snapshots.last?["features"] as? [[String: Any]])?.count, 1)
        staleCallback?(HingeReading(radians: .pi, posture: .flat))
        XCTAssertEqual(angles.last, 0)
        let pausedCount = snapshots.count
        observation.refresh()
        XCTAssertEqual(snapshots.count, pausedCount)
        usable = true
        observation.refresh()
        XCTAssertEqual(hinge.starts, 2)
        hinge.send(HingeReading(radians: 1, posture: .halfOpened))
        XCTAssertEqual(angles.count, 3)
        view.bounds.size = CGSize(width: 600, height: 800)
        regions.frames = [CGRect(x: 0, y: 390, width: 600, height: 20)]
        observation.refresh()
        XCTAssertEqual(snapshots.last?["width"] as? Double, 600)
        observation.capability { capabilities.append($0) }
        XCTAssertEqual(capabilities, [true,true])
        observation.teardown()
        XCTAssertTrue(view.subviews.isEmpty)
        XCTAssertNil(hinge.callback)
        XCTAssertNil(observation.angle.sink)
        XCTAssertNil(observation.layout.sink)
    }

    func testAttachmentTimeoutIsRetryableAndTeardownResolvesPendingCallbacks() {
        let hinge = FixtureHinge()
        let regions = FixtureRegions()
        var view: UIView?
        let observation = DuoObservation(view: { view }, hinge: hinge, regions: regions,
                                         hierarchyIsActive: { _ in true })
        let timeout = expectation(description: "bounded initialization")
        observation.capability { available in XCTAssertFalse(available); timeout.fulfill() }
        wait(for: [timeout], timeout: 3)
        view = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        var resolved: Bool?
        observation.capability { resolved = $0 }
        XCTAssertNil(resolved)
        hinge.send(HingeReading(radians: 1, posture: .halfOpened))
        XCTAssertEqual(resolved, true)
        // A new unattached hierarchy must not inherit the previous capability.
        view = nil
        observation.refresh()
        var teardownResult: Bool?
        observation.capability { teardownResult = $0 }
        observation.teardown()
        XCTAssertEqual(teardownResult, false)
    }
}
