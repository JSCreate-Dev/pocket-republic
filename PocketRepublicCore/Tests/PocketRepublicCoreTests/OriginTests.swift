import XCTest
@testable import PocketRepublicCore

final class OriginTests: XCTestCase {

    func testOrdinaryIslandOmitsOriginAndKeepsItsHash() throws {
        let state = WorldGenerator.generate(seed: 2026, citizenCount: 120)
        XCTAssertNil(state.origin)
        XCTAssertFalse(state.agenda.contains { $0.originDilemma == true })
        let data = try JSONEncoder().encode(state)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("\"origin\""))
        XCTAssertLessThan(
            AgendaSheetOrder.rank(tier: .crisis, isIslandEvent: false, isDecree: false),
            AgendaSheetOrder.rank(tier: .advisory, isIslandEvent: false, isDecree: false, isOriginDilemma: true))
        XCTAssertLessThan(
            AgendaSheetOrder.rank(tier: .advisory, isIslandEvent: false, isDecree: false, isOriginDilemma: true),
            AgendaSheetOrder.rank(tier: .advisory, isIslandEvent: true, isDecree: false))
        let loaded = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertNil(loaded.origin)
        XCTAssertEqual(loaded.stateHash(), state.stateHash())
        try loaded.checkConservation()
    }

    func testEachOriginChangesTheOpeningAndReplays() throws {
        let plain = WorldGenerator.generate(seed: 2026, citizenCount: 120)
        for origin in RepublicOrigin.allCases {
            let first = WorldGenerator.generate(seed: 2026, citizenCount: 120, origin: origin)
            let second = WorldGenerator.generate(seed: 2026, citizenCount: 120, origin: origin)
            XCTAssertEqual(first.origin, origin)
            XCTAssertEqual(first.stateHash(), second.stateHash(), "\(origin) must replay")
            XCTAssertNotEqual(first.stateHash(), plain.stateHash(), "\(origin) must differ from an ordinary island")
            XCTAssertEqual(first.agenda.filter { $0.originDilemma == true }.count, 1)
            try first.checkConservation()
            var replay = first
            advance(&replay, days: 2)
            var twin = second
            advance(&twin, days: 2)
            XCTAssertEqual(replay.stateHash(), twin.stateHash())
        }
        let marque = WorldGenerator.generate(seed: 2026, citizenCount: 120, origin: .marque)
        let parade = WorldGenerator.generate(seed: 2026, citizenCount: 120, origin: .parade)
        let pot = WorldGenerator.generate(seed: 2026, citizenCount: 120, origin: .commonPot)
        XCTAssertGreaterThan(marque.treasury, plain.treasury)
        XCTAssertGreaterThan(marque.corruption, plain.corruption)
        XCTAssertGreaterThan(parade.legitimacy, plain.legitimacy)
        XCTAssertLessThan(parade.factions[Int(FactionKind.labourers.rawValue)].favor, 0)
        XCTAssertLessThan(pot.treasury, plain.treasury)
        XCTAssertGreaterThan(pot.totalFoodInWorld, plain.totalFoodInWorld)
    }

    func testDilemmaAppliesOnceAndLoadDoesNotRepeatThePurse() throws {
        var marque = WorldGenerator.generate(seed: 4, citizenCount: 120, origin: .marque)
        let opened = marque.treasury
        let dilemma = try XCTUnwrap(marque.agenda.first { $0.originDilemma == true })
        XCTAssertEqual(SimulationEngine.apply(.resolveAgendaItem(dilemma.id, option: 0), to: &marque), .accepted)
        XCTAssertEqual(marque.treasury, opened - 100)
        XCTAssertEqual(SimulationEngine.apply(.resolveAgendaItem(dilemma.id, option: 1), to: &marque),
                       .rejected(.noSuchAgendaItem))
        XCTAssertEqual(marque.treasury, opened - 100)
        let data = try JSONEncoder().encode(marque)
        let loaded = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertEqual(loaded.treasury, marque.treasury)
        XCTAssertEqual(loaded.corruption, marque.corruption)
        XCTAssertEqual(loaded.origin, .marque)
        try loaded.checkConservation()
    }

    func testTradeoffsAreRealAndTheCompactStaysOpen() {
        var plain = WorldGenerator.generate(seed: 11, citizenCount: 120)
        advance(&plain, days: 1)
        var marque = plain
        marque.origin = .marque
        var pot = plain
        pot.origin = .commonPot
        for i in marque.buildings.indices where marque.buildings[i].kind == .market {
            marque.buildings[i].foodStore = 200
            pot.buildings[i].foodStore = 200
            plain.buildings[i].foodStore = 200
        }
        let marqueFood = marque.totalFoodInWorld
        let potFood = pot.totalFoodInWorld
        let plainFood = plain.totalFoodInWorld
        SimulationEngine.spoil(&marque)
        SimulationEngine.spoil(&pot)
        SimulationEngine.spoil(&plain)
        XCTAssertGreaterThan(marqueFood - marque.totalFoodInWorld, plainFood - plain.totalFoodInWorld)
        XCTAssertLessThan(potFood - pot.totalFoodInWorld, plainFood - plain.totalFoodInWorld)

        var parade = plain
        parade.origin = .parade
        let civic = parade.buildings.filter {
            $0.kind != .house && $0.isStanding(on: parade.map) && $0.kind.isCivic
        }.count
        XCTAssertGreaterThan(civic, 0)
        let paradeTreasury = parade.treasury
        let plainTreasury = plain.treasury
        SimulationEngine.payUpkeep(&parade)
        SimulationEngine.payUpkeep(&plain)
        XCTAssertEqual((plainTreasury - plain.treasury) - (paradeTreasury - parade.treasury), Int64(civic))

        var city = WorldGenerator.generate(seed: 8, citizenCount: 120, origin: .marque)
        place(.house, in: &city)
        advance(&city, days: 2)
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimFounding), to: &city), .accepted)
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.choose(.granary)), to: &city), .accepted)
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.choose(.harbor)), to: &city), .rejected(.seasonPathTaken))
    }

    func testEarlyPathForEachOrigin() throws {
        for origin in RepublicOrigin.allCases {
            var state = WorldGenerator.generate(seed: 2026, citizenCount: 120, origin: origin)
            print("ORIGIN \(origin.rawValue) day 0 treasury \(state.treasury) food \(state.totalFoodInWorld) corruption \(state.corruption) legitimacy \(state.legitimacy)")
            XCTAssertGreaterThan(state.totalFoodInWorld, 0)
            XCTAssertGreaterThan(state.treasury, 500)
            let dilemma = state.agenda.first { $0.originDilemma == true }
            XCTAssertEqual(dilemma?.options.count, 2)
            if let dilemma {
                XCTAssertEqual(SimulationEngine.apply(.resolveAgendaItem(dilemma.id, option: 0), to: &state), .accepted)
            }
            place(.house, in: &state)
            advance(&state, days: 2)
            XCTAssertTrue(RepublicSeasonBook.status(in: state).foundingReady)
            let before = state.treasury
            XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimFounding), to: &state), .accepted)
            XCTAssertEqual(state.treasury, before + RepublicSeasonBook.foundingGrant)
            print("ORIGIN \(origin.rawValue) day \(state.day) treasury \(state.treasury) food \(state.totalFoodInWorld) charter sealed")
            XCTAssertGreaterThan(state.totalFoodInWorld, 0)
            try state.checkConservation()
        }
    }
}

private func place(_ kind: BuildingKind, in state: inout RepublicState) {
    if let pending = state.pending {
        _ = SimulationEngine.apply(.resolveDecision(pending.id, option: pending.options[0].id), to: &state)
    }
    for raw in 0..<state.map.tileCount {
        let tile = TileIndex(Int32(raw))
        guard case .valid = SimulationEngine.validatePlacement(kind, at: tile, in: state) else { continue }
        if case .accepted = SimulationEngine.apply(.placeBuilding(kind, at: tile), to: &state) { return }
    }
    XCTFail("no legal site for \(kind)")
}

private func advance(_ state: inout RepublicState, days: Int) {
    for _ in 0..<days {
        if let pending = state.pending {
            _ = SimulationEngine.apply(.resolveDecision(pending.id, option: pending.options[0].id), to: &state)
        }
        if let blocking = state.agenda.first(where: { $0.tier == .crisis }) {
            _ = SimulationEngine.apply(.resolveAgendaItem(blocking.id, option: blocking.options[0].id), to: &state)
        }
        SimulationEngine.advance(&state)
    }
}
