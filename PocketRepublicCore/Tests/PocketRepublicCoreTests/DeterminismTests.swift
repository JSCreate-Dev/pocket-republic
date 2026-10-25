import XCTest
@testable import PocketRepublicCore

final class DeterminismTests: XCTestCase {

    /// The property the whole core exists to guarantee: same seed, same world.
    func testSameSeedProducesIdenticalWorldAfter500Days() throws {
        var a = WorldGenerator.generate(seed: 42, citizenCount: 200)
        var b = WorldGenerator.generate(seed: 42, citizenCount: 200)
        XCTAssertEqual(a.stateHash(), b.stateHash(), "worldgen must be deterministic")

        for _ in 0..<500 {
            autoResolve(&a)
            autoResolve(&b)
            SimulationEngine.advance(&a)
            SimulationEngine.advance(&b)
        }
        XCTAssertEqual(a.day, b.day)
        XCTAssertEqual(a.stateHash(), b.stateHash(), "500 days diverged on identical seeds")
    }

    func testDifferentSeedsDiverge() throws {
        var a = WorldGenerator.generate(seed: 1, citizenCount: 120)
        var b = WorldGenerator.generate(seed: 2, citizenCount: 120)
        for _ in 0..<120 { autoResolve(&a); autoResolve(&b); SimulationEngine.advance(&a); SimulationEngine.advance(&b) }
        XCTAssertNotEqual(a.stateHash(), b.stateHash(), "distinct seeds should not converge")
    }

    /// Save -> load must resume the identical RNG stream, not just the same numbers.
    func testSaveLoadResumesIdenticalStream() throws {
        var live = WorldGenerator.generate(seed: 7, citizenCount: 150)
        for _ in 0..<60 { autoResolve(&live); SimulationEngine.advance(&live) }

        let data = try JSONEncoder().encode(live)
        var restored = try JSONDecoder().decode(RepublicState.self, from: data)
        // Distance fields are a derived cache; a real load rebuilds them.
        restored.fields.markDirty()
        SimulationEngine.rebuildSpatialCaches(&restored)
        live.fields.markDirty()
        SimulationEngine.rebuildSpatialCaches(&live)

        for _ in 0..<60 { autoResolve(&live); autoResolve(&restored); SimulationEngine.advance(&live); SimulationEngine.advance(&restored) }
        XCTAssertEqual(live.stateHash(), restored.stateHash(), "round-tripped save diverged")
    }

    func testRNGStreamIsReproducibleAndSerialisable() throws {
        var r1 = SeededRNG(seed: 99)
        _ = (0..<50).map { _ in r1.int(0...1000) }
        let encoded = try JSONEncoder().encode(r1)
        var r2 = try JSONDecoder().decode(SeededRNG.self, from: encoded)
        let next1 = (0..<20).map { _ in r1.int(0...1000) }
        let next2 = (0..<20).map { _ in r2.int(0...1000) }
        XCTAssertEqual(next1, next2)
    }

    func testSchemaVersionIsPersisted() throws {
        let s = WorldGenerator.generate(seed: 3, citizenCount: 30)
        let data = try JSONEncoder().encode(s)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, RepublicState.currentSchemaVersion)
    }
}

/// Crises pause time by design, so long unattended runs need a stand-in player.
/// Always picks option 0 so the choice itself stays deterministic.
/// Clears everything that holds up the clock: crisis decisions and crisis-tier
/// agenda items (elections). Standing demands, advisories and decrees are left
/// alone on purpose -- they must never stall a run.
func autoResolve(_ s: inout RepublicState) {
    if let p = s.pending {
        _ = SimulationEngine.apply(.resolveDecision(p.id, option: p.options[0].id), to: &s)
    }
    while let blocking = s.agenda.first(where: { $0.tier == .crisis }) {
        _ = SimulationEngine.apply(
            .resolveAgendaItem(blocking.id, option: blocking.options[0].id), to: &s)
    }
}
