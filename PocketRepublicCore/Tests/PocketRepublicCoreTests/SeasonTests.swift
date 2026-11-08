import XCTest
@testable import PocketRepublicCore

/// The season arc: a placed building, one compact, then a settled republic.
final class SeasonTests: XCTestCase {

    func testFreshCityOmitsTheSeasonAndStillMatchesItsHash() throws {
        let state = WorldGenerator.generate(seed: 2026, citizenCount: 120)
        XCTAssertNil(state.republicSeason)
        XCTAssertEqual(RepublicSeasonBook.status(in: state).beat, .breakGround)
        XCTAssertFalse(RepublicSeasonBook.status(in: state).foundingReady)
        let data = try JSONEncoder().encode(state)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("republicSeason"))
        let loaded = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertNil(loaded.republicSeason)
        XCTAssertEqual(loaded.stateHash(), state.stateHash())
    }

    func testFoundingPaysOnceAndASecondClaimDoesNot() {
        var state = WorldGenerator.generate(seed: 11, citizenCount: 120)
        let before = state.treasury
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimFounding), to: &state),
                       .rejected(.seasonNotReady))
        XCTAssertEqual(state.treasury, before)
        place(.house, in: &state)
        advance(&state, days: 2)
        XCTAssertTrue(RepublicSeasonBook.status(in: state).foundingReady)
        let ready = state.treasury
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimFounding), to: &state), .accepted)
        XCTAssertEqual(state.treasury, ready + RepublicSeasonBook.foundingGrant)
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimFounding), to: &state),
                       .rejected(.seasonAlreadyClaimed))
        XCTAssertEqual(state.treasury, ready + RepublicSeasonBook.foundingGrant)
        XCTAssertEqual(state.events.last?.kind, .republicSeason)
    }

    func testCompactsAreExclusiveAndTheTreasuryIsNotMinted() throws {
        var state = claimedFounding(seed: 7)
        state.treasury = RepublicSeasonBook.pathCost - 1
        let short = state.treasury
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.choose(.granary)), to: &state),
                       .rejected(.insufficientTreasury))
        XCTAssertEqual(state.treasury, short)
        XCTAssertNil(state.republicSeason?.path)
        state.treasury = 1000
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.choose(.harbor)), to: &state), .accepted)
        XCTAssertEqual(state.treasury, 1000 - RepublicSeasonBook.pathCost)
        XCTAssertEqual(state.republicSeason?.path, .harbor)
        let after = state.treasury
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.choose(.granary)), to: &state),
                       .rejected(.seasonPathTaken))
        XCTAssertEqual(state.treasury, after)
        XCTAssertEqual(state.republicSeason?.path, .harbor)
        let data = try JSONEncoder().encode(state)
        var loaded = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertEqual(loaded.republicSeason?.path, .harbor)
        XCTAssertEqual(loaded.stateHash(), state.stateHash())
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.choose(.granary)), to: &loaded),
                       .rejected(.seasonPathTaken))
        XCTAssertEqual(loaded.treasury, state.treasury)
    }

    func testGranaryFeedsMoreAndCostsMoreUpkeep() {
        var plain = WorldGenerator.generate(seed: 11, citizenCount: 120)
        advance(&plain, days: 1)
        var granary = plain
        granary.republicSeason = RepublicSeason(foundingClaimed: true, path: .granary, settledClaimed: false)
        let plainFood = plain.totalFoodInWorld
        let granaryFood = granary.totalFoodInWorld
        SimulationEngine.produce(&plain)
        SimulationEngine.produce(&granary)
        XCTAssertGreaterThan(granary.totalFoodInWorld - granaryFood, plain.totalFoodInWorld - plainFood)
        let privateSites = granary.buildings.filter {
            $0.isStanding(on: granary.map) && !$0.kind.isCivic && $0.kind != .house
        }.count
        XCTAssertGreaterThan(privateSites, 0)
        let before = granary.treasury
        let plainTreasury = plain.treasury
        SimulationEngine.payUpkeep(&plain)
        SimulationEngine.payUpkeep(&granary)
        XCTAssertEqual(plain.treasury - plainTreasury - (granary.treasury - before), Int64(privateSites))
    }

    func testHarborEarnsMoreAndSpoilsMore() {
        var plain = WorldGenerator.generate(seed: 11, citizenCount: 120)
        advance(&plain, days: 1)
        var harbor = plain
        harbor.republicSeason = RepublicSeason(foundingClaimed: true, path: .harbor, settledClaimed: false)
        let plainMoney = plain.totalMoneyInWorld
        let harborMoney = harbor.totalMoneyInWorld
        SimulationEngine.produce(&plain)
        SimulationEngine.produce(&harbor)
        XCTAssertGreaterThan(harbor.totalMoneyInWorld - harborMoney, plain.totalMoneyInWorld - plainMoney)
        for i in harbor.buildings.indices where harbor.buildings[i].kind == .market {
            harbor.buildings[i].foodStore = 100
            plain.buildings[i].foodStore = 100
        }
        let harborFood = harbor.totalFoodInWorld
        let plainFood = plain.totalFoodInWorld
        SimulationEngine.spoil(&harbor)
        SimulationEngine.spoil(&plain)
        XCTAssertGreaterThan(harborFood - harbor.totalFoodInWorld, plainFood - plain.totalFoodInWorld)
    }

    func testPlaythroughReachesSettledExactlyOnce() {
        var state = WorldGenerator.generate(seed: 2026, citizenCount: 120)
        print("SEASON start day \(state.day) treasury \(state.treasury) kinds \(RepublicSeasonBook.playerOpenKinds(in: state).count)")
        place(.house, in: &state)
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimFounding), to: &state),
                       .rejected(.seasonNotReady), "a site is not yet a finished building")
        advance(&state, days: 2)
        let status = RepublicSeasonBook.status(in: state)
        print("SEASON day \(state.day) house open kinds \(status.playerKinds) food \(status.food) happy \(status.happiness)")
        XCTAssertTrue(status.foundingReady)
        let treasury = state.treasury
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimFounding), to: &state), .accepted)
        XCTAssertEqual(state.treasury, treasury + RepublicSeasonBook.foundingGrant)
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.choose(.granary)), to: &state), .accepted)
        XCTAssertEqual(state.treasury, treasury + RepublicSeasonBook.foundingGrant - RepublicSeasonBook.pathCost)
        print("SEASON compact granary treasury \(state.treasury)")
        unblock(&state)
        place(.farm, in: &state)
        advance(&state, days: 3)
        var ready = RepublicSeasonBook.status(in: state)
        var extra = 0
        while !ready.settledReady && extra < 8 {
            advance(&state, days: 1)
            extra += 1
            ready = RepublicSeasonBook.status(in: state)
        }
        print("SEASON day \(state.day) kinds \(ready.playerKinds) food \(ready.food) happy \(ready.happiness) settled \(ready.settledReady) extraDays \(extra)")
        XCTAssertTrue(ready.settledReady, "the arc should finish inside a short run")
        let legitimacy = state.legitimacy
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimSettled), to: &state), .accepted)
        XCTAssertEqual(state.legitimacy, min(100, legitimacy + RepublicSeasonBook.settledLegitimacy))
        XCTAssertEqual(RepublicSeasonBook.unemploymentPenalty(in: state), state.config.unemploymentPenalty - 1)
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimSettled), to: &state),
                       .rejected(.seasonAlreadyClaimed))
        XCTAssertEqual(SimulationEngine.apply(.advanceSeason(.claimFounding), to: &state),
                       .rejected(.seasonAlreadyClaimed))
        print("SEASON kept path \(state.republicSeason?.path?.rawValue ?? "none") legitimacy \(state.legitimacy)")
    }

    private func claimedFounding(seed: UInt64) -> RepublicState {
        var state = WorldGenerator.generate(seed: seed, citizenCount: 120)
        place(.house, in: &state)
        advance(&state, days: 2)
        _ = SimulationEngine.apply(.advanceSeason(.claimFounding), to: &state)
        return state
    }

    private func place(_ kind: BuildingKind, in state: inout RepublicState) {
        unblock(&state)
        for raw in 0..<state.map.tileCount {
            let tile = TileIndex(Int32(raw))
            guard case .valid = SimulationEngine.validatePlacement(kind, at: tile, in: state) else { continue }
            let result = SimulationEngine.apply(.placeBuilding(kind, at: tile), to: &state)
            if case .accepted = result { return }
        }
        XCTFail("no legal site for \(kind)")
    }

    private func unblock(_ state: inout RepublicState) {
        if let pending = state.pending {
            _ = SimulationEngine.apply(.resolveDecision(pending.id, option: pending.options[0].id), to: &state)
        }
        if let blocking = state.agenda.first(where: { $0.tier == .crisis }) {
            _ = SimulationEngine.apply(.resolveAgendaItem(blocking.id, option: blocking.options[0].id), to: &state)
        }
    }

    private func advance(_ state: inout RepublicState, days: Int) {
        for _ in 0..<days {
            unblock(&state)
            SimulationEngine.advance(&state)
        }
    }
}
