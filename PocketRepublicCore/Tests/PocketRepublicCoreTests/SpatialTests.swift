import XCTest
@testable import PocketRepublicCore

final class SpatialTests: XCTestCase {

    func testDistanceFieldMeasuresRoadDistanceNotStraightLine() throws {
        var map = WorldMap(width: 16, height: 16)
        // A single corridor: row 4 from x=1..14, then column 14 down to y=10.
        for x in Int32(1)...14 { map.road[Int(map.index(x: x, y: 4).raw)] = true }
        for y in Int32(4)...10 { map.road[Int(map.index(x: 14, y: y).raw)] = true }

        let source = map.index(x: 1, y: 4)
        let dist = DistanceFields.bfs(map: map, sources: [source])

        XCTAssertEqual(dist[Int(map.index(x: 1, y: 4).raw)], 0)
        XCTAssertEqual(dist[Int(map.index(x: 5, y: 4).raw)], 4)
        // Straight-line distance to (14,10) is 13; road distance is 13+6=19.
        XCTAssertEqual(dist[Int(map.index(x: 14, y: 10).raw)], 19)
        // Off-network tile is unreachable, not "far".
        XCTAssertEqual(dist[Int(map.index(x: 2, y: 9).raw)], DistanceFields.unreachable)
    }

    func testDisconnectedRegionsAreNotReachable() throws {
        var map = WorldMap(width: 20, height: 20)
        for x in Int32(1)...5 { map.road[Int(map.index(x: x, y: 2).raw)] = true }
        for x in Int32(12)...18 { map.road[Int(map.index(x: x, y: 2).raw)] = true }
        let comp = DistanceFields.labelComponents(map: map)
        let a = map.index(x: 2, y: 2), b = map.index(x: 15, y: 2)
        XCTAssertGreaterThanOrEqual(comp[Int(a.raw)], 0)
        XCTAssertGreaterThanOrEqual(comp[Int(b.raw)], 0)
        XCTAssertNotEqual(comp[Int(a.raw)], comp[Int(b.raw)], "separate road islands must not be connected")
    }

    /// The performance contract: fields are rebuilt on structural change, not per tick.
    func testFieldsRebuildOnBuildAndNotDuringPlainTicks() throws {
        var s = WorldGenerator.generate(seed: 5, citizenCount: 80)
        SimulationEngine.advance(&s)
        XCTAssertFalse(s.fields.dirty, "fields should be clean after a tick")

        for _ in 0..<5 { SimulationEngine.advance(&s) }
        XCTAssertFalse(s.fields.dirty, "plain ticks must not dirty the spatial cache")

        // A road changes structure, so the cache must be invalidated.
        autoResolve(&s)   // a pending crisis legitimately blocks building
        var placed = false
        for raw in 0..<Int32(s.map.tileCount) {
            let t = TileIndex(raw)
            if case .accepted = SimulationEngine.apply(.buildRoad(at: t), to: &s) {
                if s.fields.dirty { placed = true; break }
            }
        }
        XCTAssertTrue(placed, "building a road must mark the distance fields dirty")
    }

    func testBuildingOnWaterIsRejected() throws {
        var s = WorldGenerator.generate(seed: 9, citizenCount: 40)
        let water = (0..<Int32(s.map.tileCount)).first { s.map.terrain(at: TileIndex($0)) == .water }
        let t = TileIndex(try XCTUnwrap(water))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: t), to: &s),
                       .rejected(.notBuildable))
    }

    func testBuildingRequiresRoadAccessAndCostsTreasury() throws {
        var s = WorldGenerator.generate(seed: 9, citizenCount: 40)
        let before = s.treasury
        var accepted = false
        for raw in 0..<Int32(s.map.tileCount) {
            if case .accepted = SimulationEngine.apply(.placeBuilding(.market, at: TileIndex(raw)), to: &s) {
                accepted = true
                break
            }
        }
        XCTAssertTrue(accepted)
        XCTAssertEqual(s.treasury, before - BuildingKind.market.buildCost)
    }

    func testDistrictsPartitionTheMapAndAggregatePopulation() throws {
        var s = WorldGenerator.generate(seed: 13, citizenCount: 200)
        SimulationEngine.advance(&s)
        XCTAssertEqual(s.districts.count, 9)
        let totalInDistricts = s.districts.reduce(into: Int32(0)) { $0 += $1.population }
        XCTAssertEqual(totalInDistricts, Int32(s.citizens.filter { $0.alive }.count),
                       "every living citizen must belong to exactly one district")
    }

    func testPlacementAppearsInCulledSnapshotAfterSaveRoundTrip() throws {
        var state = WorldGenerator.generate(seed: 2026, citizenCount: 40)
        var placed: TileIndex?
        for raw in 0..<Int32(state.map.tileCount) {
            let tile = TileIndex(raw)
            if case .accepted = SimulationEngine.apply(.placeBuilding(.house, at: tile), to: &state) {
                placed = tile
                break
            }
        }
        let tile = try XCTUnwrap(placed)
        let id = try XCTUnwrap(state.map.building(at: tile))
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(RepublicState.self, from: data)
        let x = restored.map.x(of: tile), y = restored.map.y(of: tile)
        let frame = restored.snapshot(visibleRect: (x, y, x, y))
        XCTAssertEqual(frame.visibleBuildings.map(\.id), [id])
        XCTAssertEqual(frame.day, state.day)
    }
}
