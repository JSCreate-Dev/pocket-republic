import Foundation

/// What a map touch is allowed to do. SpriteKit applies the numbers; this type
/// does not see a view. Tests cover the policy, not the real gesture recognizer.
public struct MapGesturePolicy: Equatable, Sendable {
    public var roadMode = false
    public private(set) var multiFinger = false
    public private(set) var dragged = false

    public enum Move: Equatable, Sendable {
        case ignore
        case roadPoint
        /// `panX` and `panY` are the midpoint's movement in scene points, the same
        /// delta a one-finger pan already subtracts from the camera.
        /// `scaleFactor` is previous distance / current distance, matching the
        /// existing pinch. Nil means do not change scale.
        case navigate(panX: Double, panY: Double, scaleFactor: Double?)
    }

    public init() {}

    public mutating func began(activeFingers: Int) {
        if activeFingers >= 2 {
            multiFinger = true
            dragged = true
        } else if activeFingers == 1, !multiFinger {
            dragged = false
        }
    }

    public mutating func moved(activeFingers: Int, panX: Double, panY: Double,
                               oldDistance: Double, newDistance: Double,
                               treatAsDrag: Bool) -> Move {
        if activeFingers >= 2 {
            multiFinger = true
            dragged = true
            let factor: Double? = (oldDistance > 0 && newDistance > 5) ? oldDistance / newDistance : nil
            return .navigate(panX: panX, panY: panY, scaleFactor: factor)
        }
        if multiFinger { return .ignore }
        if roadMode {
            dragged = true
            return .roadPoint
        }
        if treatAsDrag { dragged = true }
        return .navigate(panX: panX, panY: panY, scaleFactor: nil)
    }

    /// True only for a one-finger road tap that never dragged and never gained a second finger.
    public mutating func ended(remainingFingers: Int) -> Bool {
        let roadTap = roadMode && !multiFinger && !dragged && remainingFingers == 0
        if remainingFingers == 0 {
            multiFinger = false
            dragged = false
        }
        return roadTap
    }
}

/// Camera after a pan, then a pinch around the anchor. Larger scale shows more map,
/// which is how `SKCameraNode` is already used. Pan is subtracted, same as one finger.
public struct MapCameraNudge: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var scale: Double

    public static func applying(x: Double, y: Double, scale: Double,
                                panX: Double, panY: Double,
                                anchorX: Double, anchorY: Double,
                                scaleFactor: Double?) -> MapCameraNudge {
        var camX = x - panX
        var camY = y - panY
        var next = scale
        if let scaleFactor, scaleFactor > 0, scale > 0 {
            next = min(2.6, max(0.55, scale * scaleFactor))
            let applied = next / scale
            camX = anchorX - (anchorX - camX) * applied
            camY = anchorY - (anchorY - camY) * applied
        }
        return MapCameraNudge(x: camX, y: camY, scale: next)
    }
}

/// Build and catalog holds that must drop when the Island tab is not showing.
/// Other tokens (a demolish confirm, Start New City) stay.
public struct IslandSessionHold: Equatable, Sendable {
    public var toolIsInspect: Bool
    public var catalogOpen: Bool
    public var roadDraftCount: Int
    public var hasPlacement: Bool
    public var modalTokens: Set<String>

    public static let buildToken = "build"
    public static let catalogToken = "catalog"

    public init(toolIsInspect: Bool, catalogOpen: Bool, roadDraftCount: Int,
                hasPlacement: Bool, modalTokens: Set<String>) {
        self.toolIsInspect = toolIsInspect
        self.catalogOpen = catalogOpen
        self.roadDraftCount = roadDraftCount
        self.hasPlacement = hasPlacement
        self.modalTokens = modalTokens
    }

    public mutating func leaveIsland() {
        toolIsInspect = true
        catalogOpen = false
        roadDraftCount = 0
        hasPlacement = false
        modalTokens.remove(Self.buildToken)
        modalTokens.remove(Self.catalogToken)
    }
}
