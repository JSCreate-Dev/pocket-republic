import Foundation

/// Isometric projection shared by the island scene and tap tests.
/// Half-width 32 and half-height 16 match the 64×32 terrain diamond.
public enum CityProjection {
    public static let halfWidth: Double = 32
    public static let halfHeight: Double = 16

    public static func worldPoint(x: Int32, y: Int32) -> CityPoint {
        CityPoint(
            x: Double(x - y) * halfWidth,
            y: -Double(x + y) * halfHeight
        )
    }
}

public struct CityPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Reads of which building covers a tile. `tiles(of:on:)` walks the same lookup.
public enum BuildingOccupancy {
    public static func occupant(at tile: TileIndex, on map: WorldMap) -> BuildingID? {
        guard tile.raw >= 0, Int(tile.raw) < map.tileCount else { return nil }
        return map.buildingAt(tile)
    }

    public static func tiles(of id: BuildingID, on map: WorldMap) -> [TileIndex] {
        var tiles: [TileIndex] = []
        tiles.reserveCapacity(4)
        for raw in 0..<map.tileCount {
            let tile = TileIndex(Int32(raw))
            if occupant(at: tile, on: map) == id { tiles.append(tile) }
        }
        return tiles
    }
}

/// Tap picking for placed buildings.
///
/// Occupancy comes from `BuildingOccupancy`, not `Building.tile`. A footprint can
/// cover tiles other than its origin; the building that occupies the tapped tile
/// is the one that gets inspected. Footprint sizes themselves stay with Game Logic.
public enum BuildingHitTest {
    public static func tile(at point: CityPoint, in map: WorldMap) -> TileIndex? {
        let sx = point.x / CityProjection.halfWidth
        let sy = -point.y / CityProjection.halfHeight
        let x = Int32(((sx + sy) / 2).rounded())
        let y = Int32(((sy - sx) / 2).rounded())
        guard map.contains(x: x, y: y) else { return nil }
        return map.index(x: x, y: y)
    }

    public static func building(at point: CityPoint, in state: RepublicState) -> Building? {
        guard let tile = tile(at: point, in: state.map) else { return nil }
        return building(on: tile, in: state)
    }

    /// The building occupying `tile`, even when `tile` is not that building's origin.
    public static func building(on tile: TileIndex, in state: RepublicState) -> Building? {
        guard let id = BuildingOccupancy.occupant(at: tile, on: state.map) else { return nil }
        guard id.raw >= 0, Int(id.raw) < state.buildings.count else { return nil }
        let building = state.buildings[Int(id.raw)]
        guard building.id == id else { return nil }
        return building
    }

    /// Every tile `BuildingOccupancy` assigns to `id`, origin or not.
    public static func occupiedTiles(_ id: BuildingID, on map: WorldMap) -> [TileIndex] {
        BuildingOccupancy.tiles(of: id, on: map)
    }

    /// True when any occupied tile has a road on a 4-neighbour, matching placement's
    /// "an edge tile touches a road" rule. A diagonal road does not count.
    public static func hasRoadAccess(_ id: BuildingID, on map: WorldMap) -> Bool {
        occupiedTiles(id, on: map).contains { tile in
            map.neighbours(of: tile).contains { map.isRoad(at: $0) }
        }
    }
}
