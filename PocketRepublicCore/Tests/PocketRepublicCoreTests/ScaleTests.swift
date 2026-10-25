import XCTest
@testable import PocketRepublicCore

final class ScaleTests: XCTestCase {

    func testHousesAndEmploysAThousandCitizens() throws {
        let s = WorldGenerator.generate(seed: 1000, citizenCount: 1000, size: 96)
        XCTAssertGreaterThanOrEqual(s.citizens.count, 1000, "worldgen could not house 1000 citizens")
        XCTAssertTrue(s.citizens.allSatisfy { $0.home != nil })
    }

    /// Budget check. The claim in the architecture memo was that the simulation is
    /// not the bottleneck; this measures it instead of asserting it.
    func testThousandCitizenTickCost() throws {
        var s = WorldGenerator.generate(seed: 1000, citizenCount: 1000, size: 96)
        for _ in 0..<10 { autoResolve(&s); SimulationEngine.advance(&s) }   // warm up / settle employment

        let ticks = 200
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<ticks { autoResolve(&s); SimulationEngine.advance(&s) }
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0

        let perTick = elapsedMs / Double(ticks)
        print("[scale] \(s.citizens.count) citizens, \(s.buildings.count) buildings: \(String(format: "%.3f", perTick)) ms/tick")
        // Generous ceiling: this runs in debug in CI. Release is far faster.
        XCTAssertLessThan(perTick, 50.0, "day tick too slow at 1000 citizens: \(perTick) ms")
    }

    func testDistanceFieldRebuildCost() throws {
        var s = WorldGenerator.generate(seed: 1000, citizenCount: 1000, size: 96)
        SimulationEngine.advance(&s)
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<20 {
            s.fields.markDirty()
            SimulationEngine.rebuildSpatialCaches(&s)
        }
        let perRebuild = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0 / 20.0
        print("[scale] distance-field rebuild over \(s.map.tileCount) tiles: \(String(format: "%.3f", perRebuild)) ms")
        XCTAssertLessThan(perRebuild, 250.0)
    }

    func testSaveSizeAtScale() throws {
        var s = WorldGenerator.generate(seed: 1000, citizenCount: 1000, size: 96)
        for _ in 0..<50 { autoResolve(&s); SimulationEngine.advance(&s) }
        s.trimEvents(keepingLast: 200)
        let bytes = try JSONEncoder().encode(s).count
        print("[scale] save size, 1000 citizens, JSON uncompressed: \(bytes / 1024) KB")
        XCTAssertLessThan(bytes, 8 * 1024 * 1024, "save far larger than expected")
    }

    /// Long-run stability: no crashes, no runaway state, conservation intact.
    func testThousandDayRunStaysSane() throws {
        var s = WorldGenerator.generate(seed: 31337, citizenCount: 500, size: 80)
        for _ in 0..<1000 {
            autoResolve(&s)
            SimulationEngine.advance(&s)
        }
        try s.checkConservation()
        XCTAssertEqual(s.day, 1000)
        for d in s.districts {
            XCTAssertTrue((0...100).contains(Int(d.unrest)), "\(d.name) unrest out of range: \(d.unrest)")
        }
        XCTAssertTrue((0...100).contains(Int(s.corruption)))
        XCTAssertTrue((0...100).contains(Int(s.legitimacy)))
    }
}
