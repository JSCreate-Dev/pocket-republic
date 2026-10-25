import XCTest
@testable import PocketRepublicCore

final class ConservationTests: XCTestCase {

    /// No free-floating treasury math: money only enters or leaves through a
    /// recorded external flow, every single tick.
    func testMoneyAndFoodReconcileEveryTickFor400Days() throws {
        var s = WorldGenerator.generate(seed: 2026, citizenCount: 300)
        try s.checkConservation()

        for day in 0..<400 {
            autoResolve(&s)
            SimulationEngine.advance(&s)
            do {
                try s.checkConservation()
            } catch {
                XCTFail("conservation broke on day \(day): \(error)")
                return
            }
        }
    }

    func testConservationHoldsAcrossConstructionAndDemolition() throws {
        var s = WorldGenerator.generate(seed: 11, citizenCount: 100)
        for _ in 0..<20 { autoResolve(&s); SimulationEngine.advance(&s) }
        autoResolve(&s)   // building is blocked while a crisis awaits the player

        // Build everything we can afford on legal tiles.
        var built = 0
        for raw in 0..<Int32(s.map.tileCount) where built < 12 {
            let t = TileIndex(raw)
            if case .accepted = SimulationEngine.apply(.placeBuilding(.house, at: t), to: &s) {
                built += 1
                try s.checkConservation()
            }
        }
        XCTAssertGreaterThan(built, 0, "expected at least one legal build site")

        for _ in 0..<10 { autoResolve(&s); SimulationEngine.advance(&s); try s.checkConservation() }

        // Demolishing destroys stored food -- which must be *recorded* as spoilage,
        // not silently removed from the totals.
        let targets = s.buildings.filter { $0.kind == .house }.prefix(5).map(\.id)
        for id in targets {
            _ = SimulationEngine.apply(.demolish(id), to: &s)
            try s.checkConservation()
        }
    }

    func testCrisisResolutionsDoNotMintMoney() throws {
        // Seed 555 stays calm once surplus hunger is fixed (unrest never rises, so
        // the old famine does not trip). 314 still raises district uprisings, which
        // is the path this check has to walk.
        var s = WorldGenerator.generate(seed: 314, citizenCount: 250)
        var resolved = 0
        for _ in 0..<600 {
            if let p = s.pending {
                // Exercise both branches.
                let opt = p.options[resolved % p.options.count].id
                _ = SimulationEngine.apply(.resolveDecision(p.id, option: opt), to: &s)
                resolved += 1
                try s.checkConservation()
            }
            SimulationEngine.advance(&s)
            try s.checkConservation()
        }
        XCTAssertGreaterThan(resolved, 0, "no crisis fired in 600 days -- cadence test fixture is wrong")
    }

    func testExternalFlowIsTheOnlySourceOfNewMoney() throws {
        var s = WorldGenerator.generate(seed: 77, citizenCount: 120)
        let opening = s.ledger.openingMoney
        for _ in 0..<100 { autoResolve(&s); SimulationEngine.advance(&s) }
        let delta = s.totalMoneyInWorld - opening
        XCTAssertEqual(delta, s.ledger.externalInflow - s.ledger.externalOutflow,
                       "money changed without crossing the recorded external boundary")
    }
}
