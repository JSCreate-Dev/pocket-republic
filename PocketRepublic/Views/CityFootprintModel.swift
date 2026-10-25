import CoreGraphics
import Foundation
import PocketRepublicCore

/// What the island needs from the footprint core: size, covered tiles, the
/// entrance, which building occupies a tile, and a placement check that does
/// not change the live city. This type does not decide `isPassable` or walker routes.
protocol CityFootprintModel {
    func footprintWidth(_ kind: BuildingKind) -> Int
    func footprintDepth(_ kind: BuildingKind) -> Int
    func tilesCovered(by building: Building, on map: WorldMap) -> [TileIndex]
    func tilesCovered(placing kind: BuildingKind, at origin: TileIndex, on map: WorldMap) -> [TileIndex]
    func entranceTile(of building: Building, on map: WorldMap) -> TileIndex
    func buildingID(at tile: TileIndex, on map: WorldMap) -> BuildingID?
    func checkPlacement(of kind: BuildingKind, at origin: TileIndex, in state: RepublicState) -> PlacementValidation
}

struct PlacementGhost {
    var result: IntentResult
    var tiles: [TileIndex]
    /// Door tile from `.valid(entrance:)`. Absent when placement is rejected.
    var entrance: TileIndex?
}

extension CityFootprintModel {
    func placementGhost(of kind: BuildingKind, at origin: TileIndex, in state: RepublicState) -> PlacementGhost {
        let tiles = tilesCovered(placing: kind, at: origin, on: state.map)
        switch checkPlacement(of: kind, at: origin, in: state) {
        case .valid(let entrance):
            return PlacementGhost(result: .accepted, tiles: tiles, entrance: entrance)
        case .rejected(let reason):
            return PlacementGhost(result: .rejected(reason), tiles: tiles, entrance: nil)
        }
    }
}

enum CityFootprints {
    static let current: any CityFootprintModel = CoreFootprintModel()
}

/// Reads footprint geometry and placement from PocketRepublicCore. The anchor is
/// the lowest-x, lowest-y tile; the footprint extends in +x and +y.
struct CoreFootprintModel: CityFootprintModel {
    func footprintWidth(_ kind: BuildingKind) -> Int { Int(kind.footprint.width) }
    func footprintDepth(_ kind: BuildingKind) -> Int { Int(kind.footprint.height) }

    func tilesCovered(by building: Building, on map: WorldMap) -> [TileIndex] {
        map.tilesCovered(anchor: building.anchor, footprint: building.kind.footprint)
    }

    func tilesCovered(placing kind: BuildingKind, at origin: TileIndex, on map: WorldMap) -> [TileIndex] {
        map.tilesCovered(anchor: origin, footprint: kind.footprint)
    }

    func entranceTile(of building: Building, on map: WorldMap) -> TileIndex {
        let covered = tilesCovered(by: building, on: map)
        return covered.first(where: { map.isEntrance($0) }) ?? building.entrance
    }

    func buildingID(at tile: TileIndex, on map: WorldMap) -> BuildingID? {
        guard tile.raw >= 0, Int(tile.raw) < map.tileCount else { return nil }
        return map.buildingAt(tile)
    }

    func checkPlacement(of kind: BuildingKind, at origin: TileIndex, in state: RepublicState) -> PlacementValidation {
        SimulationEngine.validatePlacement(kind, at: origin, in: state)
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
        case .notEnoughFertileLand: return "Farms need at least half their tiles on fertile land."
        case .notTouchingWater: return "Docks need a long side against the water."
        case .insufficientTreasury: return "The treasury cannot afford that."
        case .noSuchBuilding: return "That building no longer exists."
        case .cannotDemolishTownHall: return "The town hall must remain."
        case .noPendingDecision, .decisionMismatch, .invalidOption, .noSuchAgendaItem:
            return "That decision is no longer available."
        case .crisisPendingBlocksBuilding: return "Resolve the crisis before building."
        case .operatingModeNotOffered: return "That building has no operating mode."
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
