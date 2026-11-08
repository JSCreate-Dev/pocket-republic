import XCTest
@testable import PocketRepublicCore

final class SettlementTests: XCTestCase {
    func testOpeningIsSmallConnectedAndLeavesLandToBuild() throws {
        for seed: UInt64 in [0, 1, 11, 42, 2026, UInt64.max] {
            var state = WorldGenerator.generate(seed: seed)
            XCTAssertEqual(state.citizens.count, 16)
            XCTAssertEqual(state.buildings.count, 8)
            XCTAssertEqual(state.buildings.filter { $0.kind == .house }.count, 4)
            XCTAssertFalse(state.buildings.contains { [.clinic, .school, .police, .dock].contains($0.kind) })
            XCTAssertLessThan(state.map.road.filter { $0 }.count, 120)
            XCTAssertEqual(state.treasury, 1600)
            SimulationEngine.rebuildSpatialCaches(&state)
            SimulationEngine.assignWork(&state)
            XCTAssertTrue(state.citizens.allSatisfy {
                guard let home = $0.home else { return false }
                return SimulationEngine.shoppingMarket(state, homeTile: state.buildings[Int(home.raw)].tile) != nil
            })
            XCTAssertEqual(state.citizens.filter { $0.work == nil }.count, 3)
            try state.checkConservation()
        }
    }

    func testEstablishedFixturesAndOldSavesDoNotGainArrivals() throws {
        let state = WorldGenerator.generate(seed: 42, citizenCount: 120)
        XCTAssertNil(state.config.settlementGrowth)
        let data = try JSONEncoder().encode(state)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("settlementGrowth"))
        let restored = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertEqual(state.stateHash(), restored.stateHash())
        XCTAssertEqual(restored.citizens.count, 120)
    }

    func testHousingAndJobsAndFoodAreAllRequired() throws {
        var state = prepared()
        let original = state.citizens.count
        state.day = 4
        SimulationEngine.admitNewcomers(&state)
        XCTAssertEqual(state.citizens.count, original, "Full houses block growth")
        let centre = state.map.index(x: 32, y: 32)
        XCTAssertNotNil(WorldGenerator.place(&state, .house, near: centre))
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.admitNewcomers(&state)
        XCTAssertEqual(state.citizens.count, original, "No open jobs blocks growth")
        XCTAssertNotNil(WorldGenerator.place(&state, .workshop, near: centre))
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        let market = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .market })
        let stored = state.buildings[market].foodStore
        state.buildings[market].foodStore = 0
        state.ledger.foodExported += Int64(stored)
        SimulationEngine.admitNewcomers(&state)
        XCTAssertEqual(state.citizens.count, original, "An empty market blocks growth")
        state.buildings[market].foodStore = 100
        state.ledger.foodImported += 100
        SimulationEngine.admitNewcomers(&state)
        XCTAssertEqual(state.citizens.count, original + 2)
        XCTAssertEqual(state.events.last?.kind, .migrationArrival)
        XCTAssertEqual(state.events.last?.subjects.count, 2)
        SimulationEngine.assignWork(&state)
        XCTAssertTrue(state.citizens.suffix(2).allSatisfy { $0.home != nil && $0.work != nil })
        try state.checkConservation()
    }

    func testConstructionDoesNotAttractResidentsBeforeItOpens() throws {
        var state = prepared()
        let centre = state.map.index(x: 32, y: 32)
        let home = try XCTUnwrap(WorldGenerator.place(&state, .house, near: centre))
        state.buildings[Int(home.raw)].daysRequired = 2
        _ = WorldGenerator.place(&state, .workshop, near: centre)
        SimulationEngine.rebuildSpatialCaches(&state)
        state.day = 4
        SimulationEngine.admitNewcomers(&state)
        XCTAssertEqual(state.citizens.count, 16)
    }

    func testOpeningGivesTimeToCreateJobsBeforeHunger() throws {
        var state = WorldGenerator.generate(seed: 2026)
        for _ in 0..<6 {
            autoResolve(&state)
            SimulationEngine.advance(&state)
            XCTAssertEqual(state.citizens.filter { $0.daysHungry > 0 }.count, 0)
            try state.checkConservation()
        }
        XCTAssertEqual(state.citizens.count, 16, "Growth waits for player-built capacity")
    }

    func testSaveLoadKeepsGrowthAndRoutineDeterministic() throws {
        var state = prepared()
        let centre = state.map.index(x: 32, y: 32)
        _ = WorldGenerator.place(&state, .house, near: centre)
        _ = WorldGenerator.place(&state, .workshop, near: centre)
        SimulationEngine.rebuildSpatialCaches(&state)
        let data = try JSONEncoder().encode(state)
        var loaded = try JSONDecoder().decode(RepublicState.self, from: data)
        for _ in 0..<24 {
            autoResolve(&state); autoResolve(&loaded)
            SimulationEngine.advance(&state); SimulationEngine.advance(&loaded)
        }
        XCTAssertEqual(state.stateHash(), loaded.stateHash())
        XCTAssertGreaterThan(state.citizens.count, 16)
        try loaded.checkConservation()
    }

    func testTimetablesVaryByPersonAndDayWithoutChangingState() {
        var state = prepared()
        let before = state.stateHash()
        let routines = state.citizens.map { WalkerRoutine.plan(for: $0, in: state, access: state.buildingAccess()) }
        XCTAssertGreaterThan(Set(routines.map { $0.dwellStart.description }).count, 2)
        XCTAssertEqual(state.stateHash(), before)
        state.day += 1
        let later = state.citizens.map { WalkerRoutine.plan(for: $0, in: state, access: state.buildingAccess()) }
        XCTAssertNotEqual(routines, later)
        for routine in later {
            XCTAssertEqual(routine.dwellEnd.last, 24)
            for i in 1..<routine.dwellStart.count {
                XCTAssertGreaterThanOrEqual(routine.dwellStart[i], routine.dwellEnd[i - 1])
            }
            for (i, path) in routine.legPaths.enumerated() {
                XCTAssertEqual(path.first, routine.entrances[i])
                XCTAssertEqual(path.last, routine.entrances[i + 1])
            }
        }
    }

    func testResidentsFindNewJobsWithoutIndividualAssignments() throws {
        var state = prepared()
        let jobseekers = state.citizens.filter { $0.work == nil }.map(\.id)
        let centre = state.map.index(x: 32, y: 32)
        let building = try XCTUnwrap(WorldGenerator.place(&state, .workshop, near: centre))
        state.buildings[Int(building.raw)].daysRequired = 3
        for _ in 0..<2 { autoResolve(&state); SimulationEngine.advance(&state) }
        XCTAssertTrue(jobseekers.allSatisfy { state.citizens[Int($0.raw)].work == nil })
        autoResolve(&state); SimulationEngine.advance(&state)
        XCTAssertTrue(jobseekers.allSatisfy { state.citizens[Int($0.raw)].work == building })
        XCTAssertEqual(state.buildings[Int(building.raw)].workers.count, 3)
        try state.checkConservation()
    }

    func testTripsHaveNeedsAndReachableDestinations() throws {
        var state = prepared()
        let centre = state.map.index(x: 32, y: 32)
        let clinic = try XCTUnwrap(WorldGenerator.place(&state, .clinic, near: centre))
        SimulationEngine.rebuildSpatialCaches(&state)
        var resident = state.citizens[0]
        resident.age = 65
        state.day = Int32((5 - (state.worldSeed + UInt64(resident.id.raw)) % 5) % 5)
        let visit = WalkerRoutine.plan(for: resident, in: state, access: state.buildingAccess())
        XCTAssertTrue(visit.stops.contains(.clinic))
        let stop = try XCTUnwrap(visit.stops.firstIndex(of: .clinic))
        XCTAssertEqual(visit.entrances[stop], state.buildings[Int(clinic.raw)].tile)
        resident.age = 25; resident.loyalty = 15
        let gathering = WalkerRoutine.plan(for: resident, in: state, access: state.buildingAccess())
        XCTAssertTrue(gathering.stops.contains(.civic))
        state.config.maxServiceDistance = 0
        let isolated = WalkerRoutine.plan(for: resident, in: state, access: state.buildingAccess())
        XCTAssertFalse(isolated.stops.contains(.civic))
        try state.checkConservation()
    }

    private func prepared() -> RepublicState {
        var state = WorldGenerator.generate(seed: 2026)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        return state
    }
}
