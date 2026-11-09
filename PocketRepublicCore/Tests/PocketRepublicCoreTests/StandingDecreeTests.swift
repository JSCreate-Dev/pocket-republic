import XCTest
@testable import PocketRepublicCore

final class StandingDecreeTests: XCTestCase {
    func testDirectDecreeWorksWithoutCouncilOfferAndConservesResources() throws {
        var state = WorldGenerator.generate(seed: 44)
        state.agenda.removeAll()
        let treasury = state.treasury
        let food = state.totalFoodInWorld
        XCTAssertEqual(SimulationEngine.apply(.issueDecree("Decree bread rationing"), to: &state), .accepted)
        XCTAssertEqual(state.treasury, treasury - 220)
        XCTAssertEqual(state.totalFoodInWorld, food + 140)
        XCTAssertEqual(state.events.last?.kind, .decreeIssued)
        try state.checkConservation()
    }

    func testCooldownSurvivesSaveAndRejectionIsAtomic() throws {
        var state = WorldGenerator.generate(seed: 44)
        let name = "Declare a tax holiday"
        XCTAssertEqual(SimulationEngine.apply(.issueDecree(name), to: &state), .accepted)
        let encoded = try JSONEncoder().encode(state)
        var restored = try JSONDecoder().decode(RepublicState.self, from: encoded)
        let hash = restored.stateHash()
        XCTAssertEqual(SimulationEngine.apply(.issueDecree(name), to: &restored), .rejected(.decreeCoolingDown))
        XCTAssertEqual(restored.stateHash(), hash)
        restored.day += restored.config.effectiveDecreeCooldownDays
        XCTAssertEqual(SimulationEngine.apply(.issueDecree(name), to: &restored), .accepted)
    }

    func testNoFoodPurchaseWithoutStandingMarket() {
        var state = WorldGenerator.generate(seed: 44)
        for i in state.buildings.indices where state.buildings[i].kind == .market {
            _ = SimulationEngine.apply(.demolish(state.buildings[i].id), to: &state)
        }
        let hash = state.stateHash()
        XCTAssertEqual(SimulationEngine.apply(.issueDecree("Decree bread rationing"), to: &state), .rejected(.decreeUnavailable))
        XCTAssertEqual(state.stateHash(), hash)
    }

    func testPublicWorksActuallyClearsAllDistrictNeglect() {
        var state = WorldGenerator.generate(seed: 44)
        for i in state.districts.indices { state.districts[i].neglectDays = 9 }
        XCTAssertEqual(SimulationEngine.apply(.issueDecree("Order a public works season"), to: &state), .accepted)
        XCTAssertTrue(state.districts.allSatisfy { $0.neglectDays == 0 })
    }

    func testLegacyEncodingOmitsNewOptionalFields() throws {
        let state = WorldGenerator.generate(seed: 44)
        let data = try JSONEncoder().encode(state)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("decreeLastIssued"))
        XCTAssertFalse(json.contains("decreeCooldownDays"))
        XCTAssertEqual(try JSONDecoder().decode(RepublicState.self, from: data).stateHash(), state.stateHash())
    }

    func testCouncilAndDirectPathsShareCooldown() {
        var state = WorldGenerator.generate(seed: 44)
        let offer = AgendaGenerator.decrees(&state).first!
        state.agenda.append(offer)
        let name = offer.causes[0].detail
        XCTAssertEqual(SimulationEngine.apply(.resolveAgendaItem(offer.id, option: 0), to: &state), .accepted)
        XCTAssertEqual(SimulationEngine.apply(.issueDecree(name), to: &state), .rejected(.decreeCoolingDown))
    }
}
