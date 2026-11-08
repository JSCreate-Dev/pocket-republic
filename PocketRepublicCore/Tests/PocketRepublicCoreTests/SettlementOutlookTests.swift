import XCTest
@testable import PocketRepublicCore

final class SettlementOutlookTests: XCTestCase {
    func testReportsConcurrentHousingJobsAndMoodBlockersWithoutMutating() {
        var state = WorldGenerator.generate(seed: 42)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        for i in state.citizens.indices { state.citizens[i].happiness = 37 }
        state.fields.markDirty()
        let hash = state.stateHash()
        let outlook = SettlementOutlook(state: state)
        XCTAssertEqual(outlook.happiness, 37)
        XCTAssertEqual(outlook.freeBeds, 0)
        XCTAssertEqual(outlook.openJobs, 0)
        XCTAssertGreaterThanOrEqual(outlook.blockers.count, 3)
        XCTAssertFalse(outlook.ready)
        XCTAssertEqual(state.stateHash(), hash)
        XCTAssertTrue(state.fields.dirty)
    }

    func testLegacyRulesDoNotPromiseArrivals() {
        let outlook = SettlementOutlook(state: WorldGenerator.generate(seed: 1, citizenCount: 120))
        XCTAssertFalse(outlook.enabled)
        XCTAssertFalse(outlook.ready)
        XCTAssertNil(outlook.nextArrivalDay)
    }

    func testReadyReportMatchesActualFirstArrivalAndMarketReserve() throws {
        var state = WorldGenerator.generate(seed: 42)
        let centre = state.map.index(x: 32, y: 32)
        XCTAssertNotNil(WorldGenerator.place(&state, .house, near: centre))
        XCTAssertNotNil(WorldGenerator.place(&state, .workshop, near: centre))
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        for i in state.citizens.indices { state.citizens[i].happiness = 60; state.citizens[i].daysHungry = 0 }
        let market = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .market })
        state.buildings[market].foodStore = 1000
        state.day = 3
        let outlook = SettlementOutlook(state: state)
        XCTAssertTrue(outlook.ready, outlook.blockers.joined(separator: "; "))
        XCTAssertEqual(outlook.nextArrivalDay, 4)
        XCTAssertEqual(outlook.foodReserveRequired, 34)
        let count = state.citizens.count
        state.day = 4
        SimulationEngine.admitNewcomers(&state)
        XCTAssertGreaterThan(state.citizens.count, count)
    }

    func testFoodAndDisconnectionAreVisible() throws {
        var state = WorldGenerator.generate(seed: 42)
        let centre = state.map.index(x: 32, y: 32)
        XCTAssertNotNil(WorldGenerator.place(&state, .house, near: centre))
        XCTAssertNotNil(WorldGenerator.place(&state, .workshop, near: centre))
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        for i in state.buildings.indices where state.buildings[i].kind == .market { state.buildings[i].foodStore = 0 }
        XCTAssertTrue(SettlementOutlook(state: state).blockers.contains { $0.contains("market") })
        for i in state.map.road.indices { state.map.road[i] = false }
        state.fields.markDirty()
        XCTAssertTrue(SettlementOutlook(state: state).blockers.contains { $0.contains("Connect spare homes") })
    }
}
