import Foundation

/// Immutable read model handed to the renderer. The renderer gets this plus the
/// tick's events; it never holds a reference to mutable simulation state.
public struct WorldSnapshot: Sendable {
    public let day: Int32
    public let treasury: Int64
    public let population: Int32
    public let corruption: Int32
    public let legitimacy: Int32
    public let meanHappiness: Int32
    public let foodInStores: Int64
    public let districts: [District]
    public let pending: PendingDecision?

    /// Buildings inside a tile rect, for viewport culling without scanning them all.
    public let visibleBuildings: [Building]
}

extension RepublicState {
    public func snapshot(visibleRect: (x0: Int32, y0: Int32, x1: Int32, y1: Int32)? = nil) -> WorldSnapshot {
        let alive = citizens.filter { $0.alive }
        let meanH = alive.isEmpty ? 0 : Int32(alive.reduce(into: Int64(0)) { $0 += Int64($1.happiness) } / Int64(alive.count))
        var visible = buildings
        if let r = visibleRect {
            visible = buildings.filter {
                let x = map.x(of: $0.tile), y = map.y(of: $0.tile)
                return x >= r.x0 && x <= r.x1 && y >= r.y0 && y <= r.y1
            }
        }
        return WorldSnapshot(day: day, treasury: treasury, population: Int32(alive.count),
                             corruption: corruption, legitimacy: legitimacy,
                             meanHappiness: meanH, foodInStores: totalFoodInWorld,
                             districts: districts, pending: pending,
                             visibleBuildings: visible)
    }

    /// Stable content hash, for determinism tests and save verification.
    public func stateHash() -> UInt64 {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(self) else { return 0 }
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data {
            h ^= UInt64(byte)
            h = h &* 0x0000_0100_0000_01B3
        }
        return h
    }
}
