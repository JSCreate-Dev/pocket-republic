import XCTest
@testable import PocketRepublicCore

final class MapDepthTests: XCTestCase {
    func testNewIslandTerrainVariesBySeedAndReplaysExactly() throws {
        let a = WorldGenerator.generate(seed: 1)
        let b = WorldGenerator.generate(seed: 2)
        let replay = WorldGenerator.generate(seed: 1)
        XCTAssertNotEqual(a.map.terrain, b.map.terrain)
        XCTAssertEqual(a.stateHash(), replay.stateHash())
        XCTAssertEqual(a.citizens.count, 16)
        XCTAssertEqual(a.buildings.count, 8)
        try a.checkConservation()
        try b.checkConservation()
    }

    func testLandIsConnectedAndEastDockShoreIsUsableAcrossSeedsAndSizes() throws {
        for size: Int32 in [32, 64, 96] {
            for seed: UInt64 in [0, 1, 11, 42, 2026, UInt64.max] {
                let state = WorldGenerator.generate(seed: seed, size: size)
                var map = state.map
                let start = map.index(x: size / 2, y: size / 2)
                var visited: Set<TileIndex> = [start]
                var queue = [start], head = 0
                while head < queue.count {
                    let tile = queue[head]; head += 1
                    for next in map.neighbours(of: tile) where map.terrain(at: next).buildable && !visited.contains(next) {
                        visited.insert(next); queue.append(next)
                    }
                }
                XCTAssertEqual(visited.count, map.terrain.filter { $0 != TerrainKind.water.rawValue }.count,
                               "disconnected land on seed \(seed), size \(size)")
                let anchor = map.index(x: size - 5, y: size / 2)
                map.road[Int(map.index(x: size - 6, y: size / 2 + 1).raw)] = true
                XCTAssertNil(FootprintRules.assess(.dock, anchoredAt: anchor, on: map).rejection,
                             "no viable dock shore on seed \(seed), size \(size)")
                try state.checkConservation()
            }
        }
    }

    func testEstablishedFixturesKeepTheirOriginalTerrain() {
        let a = WorldGenerator.generate(seed: 1, citizenCount: 120)
        let b = WorldGenerator.generate(seed: 2, citizenCount: 120)
        XCTAssertEqual(a.map.terrain, b.map.terrain, "The established fixture retains the old generator")
    }

    func testFertilityOverlayMatchesRealFarmSoilAndDoesNotWriteState() {
        let state = WorldGenerator.generate(seed: 2026)
        let hash = state.stateHash()
        let overlay = MapOverlaySnapshot(mode: .fertility, state: state)
        for raw in 0..<state.map.tileCount {
            let tile = TileIndex(Int32(raw))
            switch state.map.terrain(at: tile) {
            case .water: XCTAssertNil(overlay.value(at: tile))
            case .fertile: XCTAssertEqual(overlay.value(at: tile), 100)
            default: XCTAssertEqual(overlay.value(at: tile), 0)
            }
        }
        XCTAssertEqual(state.stateHash(), hash)
        XCTAssertNil(overlay.value(at: TileIndex(-1)))
        XCTAssertNil(overlay.value(at: TileIndex(Int32(state.map.tileCount))))
    }

    func testSocialOverlaysUseLivingResidentsAndEmptyDistrictsHaveNoData() throws {
        var state = WorldGenerator.generate(seed: 2026)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        for i in state.citizens.indices { state.citizens[i].alive = i < 2 }
        state.citizens[0].happiness = 20
        state.citizens[1].happiness = 80
        state.citizens[1].work = nil
        let district = state.citizens[0].district
        state.citizens[1].district = district
        let tile = try XCTUnwrap(state.buildings.first { $0.kind == .house && $0.district == district }?.anchor)
        let happiness = MapOverlaySnapshot(mode: .happiness, state: state)
        let employment = MapOverlaySnapshot(mode: .employment, state: state)
        XCTAssertEqual(happiness.value(at: tile), 50)
        XCTAssertEqual(employment.value(at: tile), 50)
        let empty = try XCTUnwrap((0..<state.map.tileCount).map { TileIndex(Int32($0)) }.first {
            state.map.terrain(at: $0).buildable && state.map.district(at: $0) != district
        })
        XCTAssertNil(happiness.value(at: empty))
        XCTAssertNil(employment.value(at: empty))
    }

    func testFoodOverlayDistinguishesStockedEmptyAndDemolishedMarkets() throws {
        var state = WorldGenerator.generate(seed: 2026)
        let home = try XCTUnwrap(state.buildings.first { $0.kind == .house })
        let market = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .market })
        XCTAssertTrue(state.fields.dirty)
        let before = state.stateHash()
        XCTAssertEqual(MapOverlaySnapshot(mode: .foodAccess, state: state).value(at: home.anchor), 100)
        XCTAssertEqual(state.stateHash(), before, "Rebuilds only a disposable cache copy")
        state.buildings[market].foodStore = 0
        XCTAssertEqual(MapOverlaySnapshot(mode: .foodAccess, state: state).value(at: home.anchor), 35)
        _ = SimulationEngine.apply(.demolish(state.buildings[market].id), to: &state)
        XCTAssertEqual(MapOverlaySnapshot(mode: .foodAccess, state: state).value(at: home.anchor), 0)
    }

    func testUnfinishedMarketDoesNotShowFalseFoodCoverage() throws {
        var state = WorldGenerator.generate(seed: 2026)
        let home = try XCTUnwrap(state.buildings.first { $0.kind == .house })
        let market = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .market })
        state.buildings[market].daysRequired = 3
        state.fields.markDirty()
        XCTAssertEqual(MapOverlaySnapshot(mode: .foodAccess, state: state).value(at: home.anchor), 0)
    }

    func testOverlayReadsAndSaveLoadKeepTheExactMapAndHash() throws {
        let state = WorldGenerator.generate(seed: 42)
        let before = state.stateHash()
        for mode in MapOverlayMode.allCases { _ = MapOverlaySnapshot(mode: mode, state: state) }
        XCTAssertEqual(state.stateHash(), before)
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertEqual(restored.stateHash(), before)
        XCTAssertEqual(restored.map.terrain, state.map.terrain)
        let standard = MapOverlaySnapshot(mode: .standard, state: restored)
        XCTAssertTrue(standard.values.allSatisfy { $0 == -1 })
    }
}
