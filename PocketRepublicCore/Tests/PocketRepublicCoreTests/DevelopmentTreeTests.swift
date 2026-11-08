import XCTest
@testable import PocketRepublicCore

final class DevelopmentTreeTests: XCTestCase {
    func testFreshCityHasAnActionableTreeAndRecoveryTools() throws {
        let state = WorldGenerator.generate(seed: 2026)
        XCTAssertEqual(DevelopmentTree.nodes(in: state).count, 4)
        XCTAssertEqual(DevelopmentTree.nextGoal(in: state)?.id, .workingTown)
        for kind: BuildingKind in [.house, .farm, .market, .workshop] {
            XCTAssertTrue(DevelopmentTree.canBuild(kind, in: state))
        }
        for kind: BuildingKind in [.clinic, .dock, .school, .police] {
            XCTAssertFalse(DevelopmentTree.canBuild(kind, in: state))
            XCTAssertNotNil(DevelopmentTree.lockReason(for: kind, in: state))
        }
        XCTAssertTrue(state.development?.unlocked.isEmpty == true)
        try state.checkConservation()
    }

    func testDirectIntentCannotBypassCatalogLocksOrSpendMoney() {
        var state = WorldGenerator.generate(seed: 2026)
        let before = state.stateHash()
        let tile = state.map.index(x: 33, y: 36)
        XCTAssertEqual(SimulationEngine.validatePlacement(.clinic, at: tile, in: state), .rejected(.seasonNotReady))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.clinic, at: tile), to: &state), .rejected(.seasonNotReady))
        XCTAssertEqual(before, state.stateHash())
    }

    func testWorkplaceCompletionUnlocksClinicAndPaysOnlyOnce() throws {
        var state = WorldGenerator.generate(seed: 2026)
        let site = try place(.workshop, in: &state)
        for _ in 0..<2 { autoResolve(&state); SimulationEngine.advance(&state) }
        XCTAssertFalse(DevelopmentTree.canBuild(.clinic, in: state))
        autoResolve(&state); SimulationEngine.advance(&state)
        XCTAssertTrue(state.citizens.allSatisfy { $0.work != nil })
        XCTAssertTrue(DevelopmentTree.canBuild(.clinic, in: state))
        XCTAssertEqual(state.development?.commissionedWorkplaces, [site])
        XCTAssertEqual(state.development?.unlocked, [.workingTown])
        let treasury = state.treasury
        let inflow = state.ledger.externalInflow
        DevelopmentTree.advance(&state)
        XCTAssertEqual(state.treasury, treasury)
        XCTAssertEqual(state.ledger.externalInflow, inflow)
        XCTAssertTrue(state.events.contains { $0.causes.contains { $0.detail.contains("A Working Town") } })
        try state.checkConservation()
    }

    func testInstantBuildCountsButWorldgenDoesNot() throws {
        var state = WorldGenerator.generate(seed: 2026)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        DevelopmentTree.advance(&state)
        XCTAssertFalse(DevelopmentTree.canBuild(.clinic, in: state))
        state.config.constructionDaysMultiplierPercent = 0
        _ = try place(.workshop, in: &state)
        autoResolve(&state); SimulationEngine.advance(&state)
        XCTAssertTrue(DevelopmentTree.canBuild(.clinic, in: state))
        try state.checkConservation()
    }

    func testUnlockDoesNotRelockWhenPopulationOrWorkplaceDrops() throws {
        var state = WorldGenerator.generate(seed: 2026)
        let site = try place(.workshop, in: &state)
        for _ in 0..<3 { autoResolve(&state); SimulationEngine.advance(&state) }
        autoResolve(&state)
        XCTAssertEqual(SimulationEngine.apply(.demolish(site), to: &state), .accepted)
        for _ in 0..<3 { autoResolve(&state); SimulationEngine.advance(&state) }
        XCTAssertTrue(DevelopmentTree.canBuild(.clinic, in: state))
        XCTAssertFalse(DevelopmentTree.nodes(in: state).first!.ready)
        try state.checkConservation()
    }

    func testBuild143SaveKeepsUnrestrictedCatalogAndChecksum() throws {
        var state = WorldGenerator.generate(seed: 2026)
        // These nil optionals reproduce the previous save shape, including a
        // settlementGrowth city made by build 143.
        state.development = nil
        state.config.developmentRules = nil
        let data = try JSONEncoder().encode(state)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("\"development\""))
        XCTAssertFalse(text.contains("\"developmentRules\""))
        var loaded = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertEqual(loaded.stateHash(), state.stateHash())
        for kind in BuildingKind.allCases { XCTAssertTrue(DevelopmentTree.canBuild(kind, in: loaded)) }
        XCTAssertTrue(DevelopmentTree.nodes(in: loaded).isEmpty)
        DevelopmentTree.advance(&loaded)
        XCTAssertEqual(loaded.stateHash(), state.stateHash())
    }

    func testSaveLoadContinuesAwardsWithoutDuplicateGrant() throws {
        var live = WorldGenerator.generate(seed: 42)
        _ = try place(.workshop, in: &live)
        _ = try place(.house, in: &live)
        for _ in 0..<3 { autoResolve(&live); SimulationEngine.advance(&live) }
        let data = try JSONEncoder().encode(live)
        var loaded = try JSONDecoder().decode(RepublicState.self, from: data)
        for _ in 0..<9 {
            autoResolve(&live); autoResolve(&loaded)
            SimulationEngine.advance(&live); SimulationEngine.advance(&loaded)
        }
        XCTAssertEqual(live.stateHash(), loaded.stateHash())
        XCTAssertTrue(DevelopmentTree.canBuild(.dock, in: loaded))
        XCTAssertEqual(loaded.development?.unlocked.filter { $0 == .workingTown }.count, 1)
        XCTAssertEqual(loaded.development?.unlocked.filter { $0 == .harborCharter }.count, 1)
        try loaded.checkConservation()
    }

    func testDemolishedOrUnfinishedClinicDoesNotUnlockSchool() throws {
        var state = WorldGenerator.generate(seed: 2026)
        state.development?.unlocked = [.workingTown]
        state.config.developmentRules?.communityPopulation = 16
        let clinic = try place(.clinic, in: &state)
        DevelopmentTree.advance(&state)
        XCTAssertFalse(DevelopmentTree.canBuild(.school, in: state))
        state.buildings[Int(clinic.raw)].daysConstructed = 4
        autoResolve(&state)
        XCTAssertEqual(SimulationEngine.apply(.demolish(clinic), to: &state), .accepted)
        DevelopmentTree.advance(&state)
        XCTAssertFalse(DevelopmentTree.canBuild(.school, in: state))
    }

    func testWholeTreeCanBeEarnedThroughNormalConstructionAndGrowth() throws {
        var state = WorldGenerator.generate(seed: 2026)
        _ = try place(.workshop, in: &state)
        _ = try place(.house, in: &state)
        for _ in 0..<4 { autoResolve(&state); SimulationEngine.advance(&state) }
        XCTAssertTrue(DevelopmentTree.canBuild(.dock, in: state))
        _ = try place(.clinic, in: &state)
        _ = try place(.farm, in: &state)
        _ = try place(.workshop, in: &state)
        _ = try place(.workshop, in: &state)
        _ = try place(.house, in: &state)
        _ = try place(.house, in: &state)
        for _ in 0..<16 { autoResolve(&state); SimulationEngine.advance(&state) }
        XCTAssertTrue(DevelopmentTree.canBuild(.school, in: state), "population \(state.citizens.count), funds \(state.treasury)")
        _ = try place(.school, in: &state)
        for _ in 0..<8 { autoResolve(&state); SimulationEngine.advance(&state) }
        XCTAssertEqual(state.development?.unlocked, DevelopmentUnlock.allCases)
        XCTAssertTrue(DevelopmentTree.nextGoal(in: state) == nil)
        for kind in BuildingKind.allCases { XCTAssertTrue(DevelopmentTree.canBuild(kind, in: state)) }
        try state.checkConservation()
        print("DEVELOPMENT day \(state.day), population \(state.citizens.count), funds \(state.treasury), unlocks \(state.development?.unlocked.count ?? 0)")
    }

    @discardableResult private func place(_ kind: BuildingKind, in state: inout RepublicState) throws -> BuildingID {
        autoResolve(&state)
        let mid = state.map.index(x: state.map.width / 2, y: state.map.height / 2)
        let sites = (0..<state.map.tileCount).map { TileIndex(Int32($0)) }.sorted {
            let a = SimulationEngine.manhattan(state.map, mid, $0)
            let b = SimulationEngine.manhattan(state.map, mid, $1)
            return a == b ? $0.raw < $1.raw : a < b
        }
        for tile in sites {
            guard case .valid = SimulationEngine.validatePlacement(kind, at: tile, in: state) else { continue }
            XCTAssertEqual(SimulationEngine.apply(.placeBuilding(kind, at: tile), to: &state), .accepted)
            return try XCTUnwrap(state.map.buildingAt(tile))
        }
        XCTFail("No affordable legal \(kind) site; funds \(state.treasury)")
        throw NSError(domain: "DevelopmentTest", code: 1)
    }
}
