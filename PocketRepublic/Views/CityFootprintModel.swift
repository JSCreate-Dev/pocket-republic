import CoreGraphics
import Foundation
import PocketRepublicCore

/// What the island needs from the footprint core: size, covered tiles, the
/// entrance, which building occupies a tile, and a placement check that does
/// not change the live city.
///
/// `LegacyOneTileFootprintModel` is a temporary stand-in. The simulation still
/// stores one tile per building. When Game Logic's API lands, replace
/// `CityFootprints.current` and leave the call sites alone. This type does not
/// decide `isPassable` or walker routes.
protocol CityFootprintModel {
    func footprintWidth(_ kind: BuildingKind) -> Int
    func footprintDepth(_ kind: BuildingKind) -> Int
    func tilesCovered(by building: Building, on map: WorldMap) -> [TileIndex]
    func tilesCovered(placing kind: BuildingKind, at origin: TileIndex, on map: WorldMap) -> [TileIndex]
    func entranceTile(of building: Building, on map: WorldMap) -> TileIndex
    func entranceTile(placing kind: BuildingKind, at origin: TileIndex, on map: WorldMap) -> TileIndex
    func buildingID(at tile: TileIndex, on map: WorldMap) -> BuildingID?
    func checkPlacement(of kind: BuildingKind, at origin: TileIndex, in state: RepublicState) -> IntentResult
}

struct PlacementGhost {
    var result: IntentResult
    var tiles: [TileIndex]
    var entrance: TileIndex
}

extension CityFootprintModel {
    func placementGhost(of kind: BuildingKind, at origin: TileIndex, in state: RepublicState) -> PlacementGhost {
        PlacementGhost(
            result: checkPlacement(of: kind, at: origin, in: state),
            tiles: tilesCovered(placing: kind, at: origin, on: state.map),
            entrance: entranceTile(placing: kind, at: origin, on: state.map)
        )
    }
}

enum CityFootprints {
    /// Temporary. Point this at the core adapter when `tilesCovered`, the
    /// entrance tile, occupancy, and a side-effect-free placement check exist.
    static let current: any CityFootprintModel = LegacyOneTileFootprintModel()
}

/// TEMPORARY STUB. Every building is the single `Building.tile` the core stores
/// today. Placement validity is `SimulationEngine.apply` on a copy, so the live
/// city is unchanged. Delete this type when the core footprint API lands.
struct LegacyOneTileFootprintModel: CityFootprintModel {
    func footprintWidth(_: BuildingKind) -> Int { 1 }
    func footprintDepth(_: BuildingKind) -> Int { 1 }

    func tilesCovered(by building: Building, on map: WorldMap) -> [TileIndex] {
        guard contains(building.tile, map) else { return [] }
        return [building.tile]
    }

    func tilesCovered(placing _: BuildingKind, at origin: TileIndex, on map: WorldMap) -> [TileIndex] {
        guard contains(origin, map) else { return [] }
        return [origin]
    }

    func entranceTile(of building: Building, on _: WorldMap) -> TileIndex { building.tile }

    func entranceTile(placing _: BuildingKind, at origin: TileIndex, on _: WorldMap) -> TileIndex {
        origin
    }

    func buildingID(at tile: TileIndex, on map: WorldMap) -> BuildingID? {
        guard contains(tile, map) else { return nil }
        return map.building(at: tile)
    }

    func checkPlacement(of kind: BuildingKind, at origin: TileIndex, in state: RepublicState) -> IntentResult {
        var copy = state
        return SimulationEngine.apply(.placeBuilding(kind, at: origin), to: &copy)
    }

    private func contains(_ tile: TileIndex, _ map: WorldMap) -> Bool {
        tile.raw >= 0 && Int(tile.raw) < map.tileCount
    }
}

/// South corner of the tiles a building covers. The sprite's anchor sits here.
struct IsoFootprintLayout {
    var minX: Int32
    var minY: Int32
    var maxX: Int32
    var maxY: Int32

    /// Painter's order. The front tile (largest x + y) draws in front.
    var frontSort: CGFloat { CGFloat(maxX + maxY) }

    func southCorner(halfWidth: CGFloat, halfHeight: CGFloat) -> CGPoint {
        CGPoint(x: CGFloat(maxX - maxY) * halfWidth,
                y: -CGFloat(maxX + maxY + 1) * halfHeight)
    }

    static func make(tiles: [TileIndex], map: WorldMap) -> IsoFootprintLayout? {
        let valid = tiles.filter { $0.raw >= 0 && Int($0.raw) < map.tileCount }
        guard let first = valid.first else { return nil }
        var minX = map.x(of: first), maxX = minX
        var minY = map.y(of: first), maxY = minY
        for tile in valid.dropFirst() {
            let x = map.x(of: tile), y = map.y(of: tile)
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
        return IsoFootprintLayout(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }
}

extension BuildingKind {
    /// Market, clinic, school, and police preview `maxServiceDistance`.
    var showsServiceReach: Bool {
        switch self {
        case .market, .clinic, .school, .police: return true
        default: return false
        }
    }
}

extension IntentRejection {
    var playerFacingReason: String {
        switch self {
        case .outOfBounds: return "That tile is outside the island."
        case .notBuildable: return "You cannot build on this terrain."
        case .occupied: return "That tile is occupied."
        case .notConnectedToRoad: return "Buildings need an adjacent road."
        case .insufficientTreasury: return "The treasury cannot afford that."
        case .noSuchBuilding: return "That building no longer exists."
        case .cannotDemolishTownHall: return "The town hall must remain."
        case .noPendingDecision, .decisionMismatch, .invalidOption, .noSuchAgendaItem:
            return "That decision is no longer available."
        case .crisisPendingBlocksBuilding: return "Resolve the crisis before building."
        }
    }
}

/// Tiles within a road distance of `entrance`, using the map's current
/// `isPassable`. Read-only. This does not change passability or routing.
enum ServiceReach {
    static func tiles(from entrance: TileIndex, maxDistance: UInt16, on map: WorldMap) -> [TileIndex] {
        guard maxDistance > 0, entrance.raw >= 0, Int(entrance.raw) < map.tileCount else { return [] }
        var distance = [UInt16](repeating: .max, count: map.tileCount)
        var queue = [entrance]
        distance[Int(entrance.raw)] = 0
        var head = 0
        var reached: [TileIndex] = []
        while head < queue.count {
            let current = queue[head]
            head += 1
            let soFar = distance[Int(current.raw)]
            if soFar >= maxDistance { continue }
            for next in map.neighbours(of: current) where map.isPassable(next) {
                let index = Int(next.raw)
                if distance[index] != .max { continue }
                distance[index] = soFar + 1
                reached.append(next)
                queue.append(next)
            }
        }
        return reached
    }
}
