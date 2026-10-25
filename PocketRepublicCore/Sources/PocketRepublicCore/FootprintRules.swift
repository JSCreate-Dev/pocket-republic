import Foundation

/// Result of a placement preview. Does not mutate the republic.
/// `entrance` is the road-facing tile the building would use.
public enum PlacementValidation: Sendable, Equatable {
    case valid(entrance: TileIndex)
    case rejected(IntentRejection)
}

extension RepublicState {
    /// The building whose footprint covers `tile`, or nil if nothing is built there.
    /// `WorldMap.buildingAt(_:)` is the id lookup the inspect panel and the ghost use.
    public func building(covering tile: TileIndex) -> Building? {
        guard let id = map.building(at: tile), Int(id.raw) < buildings.count else { return nil }
        return buildings[Int(id.raw)]
    }
}

extension SimulationEngine {
    /// Placement check for the ghost and for `apply`. Reads `state` and does not
    /// change it. On success, `entrance` is the door tile (see `FootprintRules`
    /// for the tie-break). Rejection order is: pending crisis, out of bounds,
    /// not buildable, occupied (building or road), farm fertility, dock water,
    /// no road access, then treasury.
    public static func validatePlacement(_ kind: BuildingKind,
                                         at anchor: TileIndex,
                                         in state: RepublicState) -> PlacementValidation {
        if state.pending != nil { return .rejected(.crisisPendingBlocksBuilding) }
        let site = FootprintRules.assess(kind, anchoredAt: anchor, on: state.map)
        if let reason = site.rejection { return .rejected(reason) }
        guard let entrance = site.entrance else { return .rejected(.notConnectedToRoad) }
        if state.treasury < kind.buildCost { return .rejected(.insufficientTreasury) }
        return .valid(entrance: entrance)
    }
}

/// Pure footprint geometry shared by placement, world generation, and demolition.
enum FootprintRules {
    struct Site {
        var rejection: IntentRejection?
        var entrance: TileIndex?
    }

    /// Geometric rules only. Treasury and a pending crisis are the caller's concern.
    static func assess(_ kind: BuildingKind, anchoredAt anchor: TileIndex, on map: WorldMap) -> Site {
        let footprint = kind.footprint
        guard anchor.raw >= 0, Int(anchor.raw) < map.tileCount else {
            return Site(rejection: .outOfBounds, entrance: nil)
        }
        let originX = map.x(of: anchor), originY = map.y(of: anchor)
        guard map.contains(x: originX + footprint.width - 1, y: originY + footprint.height - 1) else {
            return Site(rejection: .outOfBounds, entrance: nil)
        }

        let tiles = map.tilesCovered(anchor: anchor, footprint: footprint)
        if tiles.contains(where: { !map.terrain(at: $0).buildable }) {
            return Site(rejection: .notBuildable, entrance: nil)
        }
        if tiles.contains(where: { map.building(at: $0) != nil || map.isRoad(at: $0) }) {
            return Site(rejection: .occupied, entrance: nil)
        }
        if kind == .farm {
            let fertile = tiles.reduce(into: 0) { count, tile in
                if map.terrain(at: tile) == .fertile { count += 1 }
            }
            // "At least half": 5 of a farm's 9 tiles. `2 * fertile >= area` is the integer form.
            if fertile * 2 < tiles.count {
                return Site(rejection: .notEnoughFertileLand, entrance: nil)
            }
        }
        if kind == .dock, !longSideTouchesWater(anchor: anchor, footprint: footprint, on: map) {
            return Site(rejection: .notTouchingWater, entrance: nil)
        }
        guard let entrance = entranceTile(anchor: anchor, footprint: footprint, tiles: tiles, on: map) else {
            return Site(rejection: .notConnectedToRoad, entrance: nil)
        }
        return Site(rejection: nil, entrance: entrance)
    }

    /// Edge tiles that orthogonally touch a road, outside the footprint.
    /// Tie-break is the lowest `TileIndex` (row-major: smallest y, then smallest x).
    /// `tiles` is already in that order, so the first hit wins.
    static func entranceTile(anchor: TileIndex,
                             footprint: FootprintSize,
                             tiles: [TileIndex],
                             on map: WorldMap) -> TileIndex? {
        let originX = map.x(of: anchor), originY = map.y(of: anchor)
        let covered = Set(tiles)
        for tile in tiles {
            let x = map.x(of: tile), y = map.y(of: tile)
            let onEdge = x == originX || x == originX + footprint.width - 1
                || y == originY || y == originY + footprint.height - 1
            guard onEdge else { continue }
            let touchesRoad = map.neighbours(of: tile).contains { neighbour in
                !covered.contains(neighbour) && map.isRoad(at: neighbour)
            }
            if touchesRoad { return tile }
        }
        return nil
    }

    /// A long side is an edge whose length is `max(width, height)`. The whole side
    /// must sit against water: every tile's outward neighbour is water.
    static func longSideTouchesWater(anchor: TileIndex, footprint: FootprintSize, on map: WorldMap) -> Bool {
        let originX = map.x(of: anchor), originY = map.y(of: anchor)
        let width = footprint.width, height = footprint.height
        if height > width {
            return columnTouchesWater(x: originX, y: originY, length: height, dx: -1, on: map)
                || columnTouchesWater(x: originX + width - 1, y: originY, length: height, dx: 1, on: map)
        }
        if width > height {
            return rowTouchesWater(x: originX, y: originY, length: width, dy: -1, on: map)
                || rowTouchesWater(x: originX, y: originY + height - 1, length: width, dy: 1, on: map)
        }
        return false
    }

    private static func columnTouchesWater(x: Int32, y: Int32, length: Int32, dx: Int32, on map: WorldMap) -> Bool {
        for step in 0..<length {
            let nx = x + dx, ny = y + step
            guard map.contains(x: nx, y: ny), map.terrain(at: map.index(x: nx, y: ny)) == .water else {
                return false
            }
        }
        return length > 0
    }

    private static func rowTouchesWater(x: Int32, y: Int32, length: Int32, dy: Int32, on map: WorldMap) -> Bool {
        for step in 0..<length {
            let nx = x + step, ny = y + dy
            guard map.contains(x: nx, y: ny), map.terrain(at: map.index(x: nx, y: ny)) == .water else {
                return false
            }
        }
        return length > 0
    }
}
