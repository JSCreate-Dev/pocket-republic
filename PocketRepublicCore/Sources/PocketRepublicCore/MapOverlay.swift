import Foundation

public enum MapOverlayMode: String, CaseIterable, Sendable, Identifiable {
    case standard, fertility, happiness, foodAccess, employment
    public var id: String { rawValue }
}

/// Disposable scalar data for a map view. -1 means no data, 0...100 is a real
/// value. It is never saved, and reading it cannot advance the day or RNG.
public struct MapOverlaySnapshot: Sendable {
    public let mode: MapOverlayMode
    public let values: [Int16]

    public init(mode: MapOverlayMode, state: RepublicState) {
        self.mode = mode
        let map = state.map
        var values = [Int16](repeating: -1, count: map.tileCount)
        switch mode {
        case .standard:
            break
        case .fertility:
            for raw in 0..<map.tileCount {
                let tile = TileIndex(Int32(raw))
                if map.terrain(at: tile).buildable { values[raw] = map.terrain(at: tile) == .fertile ? 100 : 0 }
            }
        case .happiness, .employment:
            var counts = [Int64](repeating: 0, count: state.districts.count)
            var totals = counts
            for citizen in state.citizens where citizen.alive {
                let district = Int(citizen.district.raw)
                guard district < counts.count else { continue }
                counts[district] += 1
                if mode == .happiness { totals[district] += Int64(citizen.happiness) }
                else if let work = citizen.work, Int(work.raw) >= 0, Int(work.raw) < state.buildings.count,
                        state.buildings[Int(work.raw)].isStanding(on: map) { totals[district] += 100 }
            }
            for raw in 0..<map.tileCount {
                let tile = TileIndex(Int32(raw)), district = Int(map.district(at: TileIndex(Int32(raw))).raw)
                guard map.terrain(at: tile).buildable, district < counts.count, counts[district] > 0 else { continue }
                values[raw] = Int16(max(0, min(100, totals[district] / counts[district])))
            }
        case .foodAccess:
            // A just-placed road/market must appear immediately, without mutating
            // the real state's derived cache or waiting for Next Day.
            var readState = state
            if readState.fields.dirty { SimulationEngine.rebuildSpatialCaches(&readState) }
            func score(_ market: BuildingID?) -> Int16 {
                guard let market else { return 0 }
                return readState.buildings[Int(market.raw)].foodStore > 0 ? 100 : 35
            }
            for raw in 0..<map.tileCount {
                let tile = TileIndex(Int32(raw))
                guard map.isRoad(at: tile) else { continue }
                let reachable = readState.fields.distance(.market, at: tile) <= readState.config.maxServiceDistance
                values[raw] = reachable ? score(readState.fields.nearestMarket(at: tile)) : 0
            }
            for building in readState.buildings where building.kind == .house && building.isStanding(on: map) {
                let value = score(SimulationEngine.shoppingMarket(readState, homeTile: building.tile))
                for tile in building.tilesCovered(on: map) { values[Int(tile.raw)] = value }
            }
        }
        self.values = values
    }

    public func value(at tile: TileIndex) -> Int16? {
        guard tile.raw >= 0, Int(tile.raw) < values.count, values[Int(tile.raw)] >= 0 else { return nil }
        return values[Int(tile.raw)]
    }
}
