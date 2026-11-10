import XCTest
@testable import PocketRepublicCore

final class CoreFlowPolishTests: XCTestCase {
    func testDisplacedResidentsAutomaticallyRehouseWithoutMoneyOrPopulationChanges() throws {
        var state = prepared()
        let old = try XCTUnwrap(state.buildings.first { $0.kind == .house })
        let people = old.residents
        XCTAssertEqual(SimulationEngine.apply(.demolish(old.id), to: &state), .accepted)
        let new = try XCTUnwrap(WorldGenerator.place(&state, .house, near: state.map.index(x: 32, y: 32)))
        SimulationEngine.rebuildSpatialCaches(&state)
        let treasury = state.treasury
        let population = state.citizens.count
        SimulationEngine.assignHomes(&state)
        XCTAssertTrue(people.allSatisfy { state.citizens[Int($0.raw)].home != nil })
        XCTAssertEqual(Set(state.buildings[Int(new.raw)].residents), Set(people))
        XCTAssertEqual(state.treasury, treasury)
        XCTAssertEqual(state.citizens.count, population)
        XCTAssertEqual(state.events.last?.kind, .citizenHoused)
        let eventCount = state.events.count
        SimulationEngine.assignHomes(&state)
        XCTAssertEqual(state.events.count, eventCount)
        try state.checkConservation()
    }

    func testConstructionDoesNotOfferShelterAndLocalsReserveBedsBeforeNewcomers() throws {
        var state = prepared()
        let old = try XCTUnwrap(state.buildings.first { $0.kind == .house })
        let people = old.residents
        _ = SimulationEngine.apply(.demolish(old.id), to: &state)
        let site = try XCTUnwrap(WorldGenerator.place(&state, .house, near: state.map.index(x: 32, y: 32)))
        state.buildings[Int(site.raw)].daysRequired = 2
        _ = WorldGenerator.place(&state, .workshop, near: state.map.index(x: 32, y: 32))
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignHomes(&state)
        XCTAssertTrue(people.allSatisfy { state.citizens[Int($0.raw)].home == nil })
        state.buildings[Int(site.raw)].daysConstructed = 2
        state.fields.markDirty(); SimulationEngine.rebuildSpatialCaches(&state)
        state.day = 4
        SimulationEngine.assignHomes(&state); SimulationEngine.assignWork(&state)
        XCTAssertTrue(SettlementAdmissionPlan.homes(in: state).isEmpty)
        SimulationEngine.admitNewcomers(&state)
        XCTAssertEqual(state.citizens.count, 16)
        XCTAssertTrue(people.allSatisfy { state.citizens[Int($0.raw)].home == site })
        try state.checkConservation()
    }

    func testForecastReservesExistingResidentsVacanciesWithoutMutating() {
        var state = WorldGenerator.generate(seed: 42)
        _ = WorldGenerator.place(&state, .house, near: state.map.index(x: 32, y: 32))
        let hash = state.stateHash()
        let outlook = SettlementOutlook(state: state)
        XCTAssertGreaterThan(outlook.openJobs, 0)
        XCTAssertEqual(outlook.availableArrivalJobs, 0)
        XCTAssertEqual(outlook.expectedArrivals, 0)
        XCTAssertFalse(outlook.ready)
        XCTAssertTrue(outlook.blockers.contains { $0.contains("Existing residents") })
        XCTAssertEqual(hash, state.stateHash())
    }

    func testPartialWavePredictionMatchesActualAdmissionAndSaveReplay() throws {
        var state = prepared()
        _ = WorldGenerator.place(&state, .house, near: state.map.index(x: 32, y: 32))
        _ = WorldGenerator.place(&state, .workshop, near: state.map.index(x: 32, y: 32))
        SimulationEngine.rebuildSpatialCaches(&state); SimulationEngine.assignWork(&state)
        let m = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .market })
        let delta = state.buildings[m].foodStore - 34
        state.buildings[m].foodStore = 34
        if delta >= 0 { state.ledger.foodExported += Int64(delta) } else { state.ledger.foodImported -= Int64(delta) }
        state.day = 3
        let outlook = SettlementOutlook(state: state)
        XCTAssertTrue(outlook.ready, outlook.blockers.joined(separator: "; "))
        XCTAssertEqual(outlook.expectedArrivals, 1)
        var loaded = try JSONDecoder().decode(RepublicState.self, from: JSONEncoder().encode(state))
        state.day = 4; loaded.day = 4
        SimulationEngine.admitNewcomers(&state); SimulationEngine.admitNewcomers(&loaded)
        XCTAssertEqual(state.citizens.count, 17)
        XCTAssertEqual(state.stateHash(), loaded.stateHash())
        try state.checkConservation()
    }

    func testNoticesAreActionableAndDisappearWhenResolved() throws {
        var state = prepared()
        let id = state.citizens[0].id
        state.citizens[0].home = nil
        XCTAssertEqual(CitizenNeeds.attention(for: id, in: state)?.kind, .housing)
        state.citizens[0].home = state.buildings.first { $0.kind == .house }!.id
        state.citizens[0].daysHungry = 1
        XCTAssertEqual(CitizenNeeds.attention(for: id, in: state)?.kind, .food)
        state.citizens[0].daysHungry = 0
        state.citizens[0].work = nil
        XCTAssertEqual(CitizenNeeds.attention(for: id, in: state)?.kind, .work)
        state.citizens[0].alive = false
        XCTAssertNil(CitizenNeeds.attention(for: id, in: state))
        XCTAssertNil(CitizenNeeds.attention(for: CitizenID(-1), in: state))
        let hash = state.stateHash()
        _ = CitizenNeeds.notices(in: state)
        XCTAssertEqual(hash, state.stateHash())
    }

    func testMealExplanationDistinguishesCashFromStockAndLastMeal() throws {
        var state = prepared()
        let c = state.citizens[0]
        let home = try XCTUnwrap(c.home)
        let market = try XCTUnwrap(SimulationEngine.shoppingMarket(state, homeTile: state.buildings[Int(home.raw)].tile))
        state.buildings[Int(market.raw)].foodStore = 100
        var hungry = c; hungry.daysHungry = 2; hungry.money = 0
        XCTAssertTrue(CitizenNeeds.foodExplanation(for: hungry, in: state).contains("costs"))
        state.buildings[Int(market.raw)].foodStore = 0
        XCTAssertTrue(CitizenNeeds.foodExplanation(for: hungry, in: state).contains("stock"))
        state.buildings[Int(market.raw)].foodStore = 100; hungry.money = 100
        XCTAssertTrue(CitizenNeeds.foodExplanation(for: hungry, in: state).contains("last daily meal"))
        state.config.maxServiceDistance = 0
        XCTAssertTrue(CitizenNeeds.foodExplanation(for: hungry, in: state).contains("road reach"))
    }

    func testDayResultRecognisesRecoveringFoodAndJobs() {
        var state = prepared()
        state.citizens[0].daysHungry = 2; state.citizens[1].daysHungry = 1
        let before = CityDaySnapshot(state: state)
        state.day += 1
        state.citizens[0].daysHungry = 0; state.citizens[1].daysHungry = 0
        let result = CityDayResult.compare(before, CityDaySnapshot(state: state))
        XCTAssertEqual(result?.fewerHungry, 2)
        XCTAssertEqual(result?.headline, "Everyone is fed again")
    }

    func testBuildingNoticeTracksConstructionOpeningAndDemolition() throws {
        var state = prepared()
        let id = try XCTUnwrap(WorldGenerator.place(&state, .house, near: state.map.index(x: 32, y: 32)))
        state.buildings[Int(id.raw)].daysRequired = 2
        XCTAssertEqual(BuildingInspector.attention(id: id, in: state)?.kind, .construction)
        state.buildings[Int(id.raw)].daysConstructed = 2
        state.day = state.buildings[Int(id.raw)].opensOnDay
        XCTAssertEqual(BuildingInspector.attention(id: id, in: state)?.kind, .opened)
        state.day += 1
        XCTAssertNil(BuildingInspector.attention(id: id, in: state))
        _ = SimulationEngine.apply(.demolish(id), to: &state)
        XCTAssertNil(BuildingInspector.attention(id: id, in: state))
    }

    func testFullTickRehousesAfterOpeningAndResumesLocalEmployment() throws {
        var state = prepared()
        let old = try XCTUnwrap(state.buildings.first { $0.kind == .house })
        let ids = old.residents
        _ = SimulationEngine.apply(.demolish(old.id), to: &state)
        let house = try XCTUnwrap(WorldGenerator.place(&state, .house, near: state.map.index(x: 32, y: 32)))
        state.buildings[Int(house.raw)].daysRequired = 1
        state.pending = nil; state.agenda.removeAll()
        var loaded = try JSONDecoder().decode(RepublicState.self, from: JSONEncoder().encode(state))
        SimulationEngine.advance(&state); SimulationEngine.advance(&loaded)
        XCTAssertEqual(state.stateHash(), loaded.stateHash())
        XCTAssertTrue(ids.allSatisfy { state.citizens[Int($0.raw)].home == house })
        XCTAssertEqual(state.events.filter { $0.kind == .citizenHoused }.count, 1)
        try state.checkConservation()
    }

    func testDisconnectedWorkerHasActionableRouteNoticeWithoutChangingState() throws {
        var state = prepared()
        let worker = try XCTUnwrap(state.citizens.first { $0.work != nil })
        for i in state.map.road.indices { state.map.road[i] = false }
        state.fields.markDirty()
        let hash = state.stateHash()
        XCTAssertEqual(CitizenNeeds.attention(for: worker.id, in: state)?.title, "Work route blocked")
        XCTAssertEqual(state.stateHash(), hash)
    }

    func testDayResultExplainsNetEmploymentImprovement() throws {
        var state = prepared()
        let person = try XCTUnwrap(state.citizens.firstIndex { $0.work == nil })
        let before = CityDaySnapshot(state: state)
        state.day += 1
        _ = WorldGenerator.place(&state, .workshop, near: state.map.index(x: 32, y: 32))
        SimulationEngine.rebuildSpatialCaches(&state); SimulationEngine.assignWork(&state)
        XCTAssertNotNil(state.citizens[person].work)
        let result = try XCTUnwrap(CityDayResult.compare(before, CityDaySnapshot(state: state)))
        XCTAssertEqual(result.employmentDelta, 3)
        // A building opening has presentation priority; the truthful job delta
        // remains available for reports without calling it income or production.
        XCTAssertEqual(result.newlyOpened, 1)
        try state.checkConservation()
    }

    func testUnhousedResidentIsNotSilentlyReportedAsFed() throws {
        var state = prepared()
        state.citizens[0].home = nil
        state.citizens[1].alive = false
        SimulationEngine.feedCitizens(&state)
        XCTAssertEqual(state.citizens[0].daysHungry, 1)
        XCTAssertEqual(state.citizens[1].daysHungry, 0)
        try state.checkConservation()
    }

    private func prepared() -> RepublicState {
        var state = WorldGenerator.generate(seed: 42)
        SimulationEngine.rebuildSpatialCaches(&state); SimulationEngine.assignWork(&state)
        return state
    }
}
