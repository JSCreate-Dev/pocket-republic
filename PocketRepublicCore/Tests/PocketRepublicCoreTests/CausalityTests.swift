import XCTest
@testable import PocketRepublicCore

final class CausalityTests: XCTestCase {

    /// Every crisis must carry the numbers that produced it. This is the property
    /// that makes "traceable to a district/policy cause" checkable rather than aspirational.
    func testEveryCrisisCarriesCausesAndOptions() throws {
        var s = WorldGenerator.generate(seed: 314, citizenCount: 300)
        var seen = 0
        for _ in 0..<800 {
            if let p = s.pending {
                XCTAssertFalse(p.causes.isEmpty, "\(p.kind) raised with no causal factors")
                XCTAssertGreaterThanOrEqual(p.options.count, 2, "\(p.kind) must offer a real choice")
                if p.kind == .districtUprising {
                    XCTAssertNotNil(p.location.district, "an uprising must name its district")
                }
                seen += 1
                _ = SimulationEngine.apply(.resolveDecision(p.id, option: p.options[0].id), to: &s)
            }
            SimulationEngine.advance(&s)
        }
        XCTAssertGreaterThan(seen, 0, "no crises in 800 days")
    }

    /// Crises are a pure function of world state: advancing the RNG stream without
    /// changing conditions must not conjure or suppress one.
    func testCrisesAreNotRandomlySpawned() throws {
        var base = WorldGenerator.generate(seed: 808, citizenCount: 250)
        for _ in 0..<150 { autoResolve(&base); SimulationEngine.advance(&base) }

        var perturbed = base
        var r = perturbed.rng
        _ = (0..<5000).map { _ in r.int(0...100) }   // burn the stream, change nothing else
        perturbed.rng = r

        var a = base, b = perturbed
        SimulationEngine.evaluateCrises(&a)
        SimulationEngine.evaluateCrises(&b)
        XCTAssertEqual(a.pending?.kind, b.pending?.kind,
                       "crisis selection depends on the RNG, not purely on world state")
        XCTAssertEqual(a.pending?.location.district, b.pending?.location.district)
    }

    /// The order-dependence bug from v0.1: corruption was mutated inside the citizen
    /// loop, so citizens later in the array saw a different value. Every citizen must
    /// be evaluated against the same pre-tick snapshot.
    func testAllCitizensSeeTheSameCorruptionWithinATick() throws {
        var s = WorldGenerator.generate(seed: 404, citizenCount: 200)
        for _ in 0..<40 { autoResolve(&s); SimulationEngine.advance(&s) }

        s.corruption = 72                  // above the penalty threshold
        let before = s.corruption
        let deltas = SimulationEngine.updateWellbeing(&s)

        let reported = deltas.flatMap { $0.causes }.filter { $0.kind == .corruption }.map(\.value)
        XCTAssertFalse(reported.isEmpty, "fixture should produce corruption pressure")
        for v in reported {
            XCTAssertEqual(v, before,
                           "a citizen saw corruption \(v) instead of the \(before) snapshot — loop is order-dependent")
        }
    }

    func testEventsCarryLocationForDistrictScopedKinds() throws {
        var s = WorldGenerator.generate(seed: 2718, citizenCount: 300)
        for _ in 0..<400 { autoResolve(&s); SimulationEngine.advance(&s) }

        let districtScoped: Set<EventKind> = [.districtNeglected, .districtProtest, .citizenHungry, .citizenTurnedToCrime]
        let offenders = s.events.filter { districtScoped.contains($0.kind) && $0.location.district == nil }
        XCTAssertTrue(offenders.isEmpty, "\(offenders.count) district-scoped events had no location")
        XCTAssertFalse(s.events.isEmpty)
    }

    /// Neglect must be real accumulated state, not a label applied after the fact.
    func testNeglectAccumulatesWhenADistrictLosesItsMarket() throws {
        var s = WorldGenerator.generate(seed: 61, citizenCount: 250)
        for _ in 0..<30 { autoResolve(&s); SimulationEngine.advance(&s) }

        // Remove every market: coverage collapses, neglect must start climbing.
        for m in s.buildings.filter({ $0.kind == .market }).map(\.id) {
            _ = SimulationEngine.apply(.demolish(m), to: &s)
        }
        let populated = s.districts.filter { $0.population > 0 }.map(\.id)
        XCTAssertFalse(populated.isEmpty)

        for _ in 0..<25 { autoResolve(&s); SimulationEngine.advance(&s) }
        for did in populated {
            XCTAssertGreaterThan(s.districts[Int(did.raw)].neglectDays, 0,
                                 "\(s.districts[Int(did.raw)].name) lost its market but records no neglect")
        }
    }
}
