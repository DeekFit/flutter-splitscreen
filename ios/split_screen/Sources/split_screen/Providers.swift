import UIKit

struct HingeReading {
    enum Posture { case unknown, halfOpened, flat }
    let radians: CGFloat
    let posture: Posture
    var degrees: Double? {
        let value = Double(radians) * 180 / .pi
        return value.isFinite ? value : nil
    }
    var state: String {
        switch posture {
        case .halfOpened: return "halfOpened"
        case .flat: return "flat"
        case .unknown: return "unknown"
        }
    }
}

protocol HingeProviding: AnyObject {
    func start(on view: UIView, update: @escaping (HingeReading?) -> Void)
    func stop()
}

protocol RegionProviding {
    func divisions(in view: UIView) -> [CGRect]
}

/// These adapters are the only code that knows about the Duo SDK.
@available(iOS 27.1, *)
final class SystemHingeProvider: HingeProviding {
    private weak var view: UIView?
    private var interaction: UIHingeInteraction?

    func start(on view: UIView, update: @escaping (HingeReading?) -> Void) {
        stop()
        let interaction = UIHingeInteraction { _, context in
            guard let hinge = context.hinge else { update(nil); return }
            let posture: HingeReading.Posture
            switch hinge.status {
            case .partiallyOpen: posture = .halfOpened
            case .fullyOpen: posture = .flat
            default: posture = .unknown
            }
            update(HingeReading(radians: hinge.angle, posture: posture))
        }
        self.view = view
        self.interaction = interaction
        view.addInteraction(interaction)
    }

    func stop() {
        if let interaction = interaction { view?.removeInteraction(interaction) }
        interaction = nil
        view = nil
    }
}

@available(iOS 27.1, *)
struct SystemRegionProvider: RegionProviding {
    func divisions(in view: UIView) -> [CGRect] {
        // Frames already include the system's interactive margins. Never inset.
        view.reservedRegions(kind: .division).filter { $0.isActive }.map { $0.frame }
    }
}

struct FoldSnapshot {
    let size: CGSize
    let frames: [CGRect]
    let state: String
    var payload: [String: Any] {
        ["width": Double(size.width), "height": Double(size.height),
         "features": frames.map { frame in
             ["left": Double(frame.minX), "top": Double(frame.minY),
              "right": Double(frame.maxX), "bottom": Double(frame.maxY),
              "state": state] as [String: Any]
         }]
    }

    static func make(view: UIView, source: UIView, frames: [CGRect], state: String) -> FoldSnapshot? {
        let size = view.bounds.size
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        let viewport = CGRect(origin: .zero, size: size)
        let converted = frames.compactMap { frame -> CGRect? in
            guard frame.origin.x.isFinite, frame.origin.y.isFinite,
                  frame.width.isFinite, frame.height.isFinite,
                  frame.width >= 0, frame.height >= 0 else { return nil }
            // UIView coordinates are logical points. Account for a nonzero bounds origin.
            let local = view.convert(frame, from: source).offsetBy(
                dx: -view.bounds.minX, dy: -view.bounds.minY)
            guard local.minX.isFinite, local.minY.isFinite,
                  local.maxX.isFinite, local.maxY.isFinite else { return nil }
            // Manual intersection preserves zero-area fold seams.
            let left = max(viewport.minX, local.minX)
            let top = max(viewport.minY, local.minY)
            let right = min(viewport.maxX, local.maxX)
            let bottom = min(viewport.maxY, local.maxY)
            guard right >= left, bottom >= top,
                  right > left || bottom > top else { return nil }
            return CGRect(x: left, y: top, width: right-left, height: bottom-top)
        }.sorted {
            if $0.minX != $1.minX { return $0.minX < $1.minX }
            if $0.minY != $1.minY { return $0.minY < $1.minY }
            if $0.width != $1.width { return $0.width < $1.width }
            return $0.height < $1.height
        }
        return FoldSnapshot(size: size, frames: converted, state: state)
    }

    func approximatelyEquals(_ other: FoldSnapshot) -> Bool {
        func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a-b) <= 0.01 }
        return near(size.width, other.size.width) && near(size.height, other.size.height)
            && (frames.isEmpty || state == other.state) && frames.count == other.frames.count
            && zip(frames, other.frames).allSatisfy { a, b in
                near(a.minX,b.minX) && near(a.minY,b.minY)
                && near(a.maxX,b.maxX) && near(a.maxY,b.maxY)
            }
    }
}
