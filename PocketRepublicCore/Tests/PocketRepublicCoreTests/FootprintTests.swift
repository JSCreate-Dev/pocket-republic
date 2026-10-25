import XCTest
@testable import PocketRepublicCore

/// Multi-tile footprints: sizes, placement rules, entrance tie-break, district,
/// occupancy, demolition, and passability. The ghost and the renderer call
/// `validatePlacement` and `WorldMap.buildingAt(_:)`; these tests lock that contract.
final class FootprintTests: XCTestCase {

    func testFootprintSizesMatchTheDesignTable() {
        XCTAssertEqual(BuildingKind.house.footprint, FootprintSize(width: 2, height: 2))
        XCTAssertEqual(BuildingKind.police.footprint, FootprintSize(width: 2, height: 2))
        XCTAssertEqual(BuildingKind.market.footprint, FootprintSize(width: 3, height: 2))
        XCTAssertEqual(BuildingKind.workshop.footprint, FootprintSize(width: 3, height: 2))
        XCTAssertEqual(BuildingKind.farm.footprint, FootprintSize(width: 3, height: 3))
        XCTAssertEqual(BuildingKind.clinic.footprint, FootprintSize(width: 3, height: 3))
        XCTAssertEqual(BuildingKind.school.footprint, FootprintSize(width: 3, height: 3))
        XCTAssertEqual(BuildingKind.townHall.footprint, FootprintSize(width: 3, height: 3))
        XCTAssertEqual(BuildingKind.dock.footprint, FootprintSize(width: 2, height: 3))
        XCTAssertEqual(BuildingKind.allCases.count, 9)
    }

    func testPlacementRejectsOutOfBoundsFootprint() {
        var state = blankRepublic(size: 16)
        // Anchor is on the map; the 2×2 extends past the edge.
        let corner = state.map.index(x: 15, y: 15)
        XCTAssertEqual(SimulationEngine.validatePlacement(.house, at: corner, in: state),
                       .rejected(.outOfBounds))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: corner), to: &state),
                       .rejected(.outOfBounds))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: TileIndex(-1)), to: &state),
                       .rejected(.outOfBounds))
        XCTAssertEqual(state.buildings.count, 0)
    }

    func testPlacementRejectsUnbuildableTile() {
        var state = blankRepublic(size: 16)
        paint(&state, 5, 5, .water)
        road(&state, 4, 3)
        let anchor = state.map.index(x: 4, y: 4)
        XCTAssertEqual(SimulationEngine.validatePlacement(.house, at: anchor, in: state),
                       .rejected(.notBuildable))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: anchor), to: &state),
                       .rejected(.notBuildable))
    }

    func testPlacementRejectsOverlapAndRoads() {
        var state = blankRepublic(size: 16)
        road(&state, 4, 3)
        let anchor = state.map.index(x: 4, y: 4)
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: anchor), to: &state), .accepted)
        let before = state.map.buildingAt

        // Overlaps the placed house on two tiles.
        let overlap = state.map.index(x: 5, y: 5)
        road(&state, 5, 7)
        XCTAssertEqual(SimulationEngine.validatePlacement(.house, at: overlap, in: state),
                       .rejected(.occupied))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: overlap), to: &state),
                       .rejected(.occupied))

        // A road tile inside the footprint is occupied, even with another road nearby.
        road(&state, 10, 10)
        road(&state, 8, 9)
        let onRoad = state.map.index(x: 8, y: 8)
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: onRoad), to: &state),
                       .rejected(.occupied))
        XCTAssertEqual(state.map.buildingAt, before)
        XCTAssertEqual(state.buildings.count, 1)
    }

    func testPlacementRejectsMissingRoad() {
        var state = blankRepublic(size: 16)
        let anchor = state.map.index(x: 4, y: 4)
        XCTAssertEqual(SimulationEngine.validatePlacement(.police, at: anchor, in: state),
                       .rejected(.notConnectedToRoad))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.police, at: anchor), to: &state),
                       .rejected(.notConnectedToRoad))
        XCTAssertTrue(state.buildings.isEmpty)
    }

    func testFarmRequiresAtLeastHalfFertile() throws {
        var state = blankRepublic(size: 16)
        road(&state, 2, 4)
        let anchor = state.map.index(x: 3, y: 4)
        // 4 of 9 is short of half. 5 of 9 is enough (`2 * fertile >= 9`).
        markFertile(&state, anchor: (3, 4), count: 4)
        XCTAssertEqual(SimulationEngine.validatePlacement(.farm, at: anchor, in: state),
                       .rejected(.notEnoughFertileLand))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.farm, at: anchor), to: &state),
                       .rejected(.notEnoughFertileLand))

        markFertile(&state, anchor: (3, 4), count: 5)
        guard case .valid(let entrance) = SimulationEngine.validatePlacement(.farm, at: anchor, in: state) else {
            return XCTFail("five fertile tiles should be legal")
        }
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.farm, at: anchor), to: &state), .accepted)
        let farm = try XCTUnwrap(state.building(covering: anchor))
        let fertile = farm.tilesCovered(on: state.map).filter { state.map.terrain(at: $0) == .fertile }.count
        XCTAssertGreaterThanOrEqual(fertile * 2, farm.kind.footprint.area)
        XCTAssertEqual(farm.entrance, entrance)
        XCTAssertEqual(farm.tile, entrance)
    }

    func testDockRequiresALongSideOnWater() throws {
        var state = blankRepublic(size: 16)
        // 2×3 at (4,4). Long sides are the vertical edges. Road touches the top-left.
        road(&state, 4, 3)
        let anchor = state.map.index(x: 4, y: 4)

        // Water only along the short southern side.
        paint(&state, 4, 7, .water)
        paint(&state, 5, 7, .water)
        XCTAssertEqual(SimulationEngine.validatePlacement(.dock, at: anchor, in: state),
                       .rejected(.notTouchingWater))

        paint(&state, 4, 7, .grass)
        paint(&state, 5, 7, .grass)
        // One water tile on the eastern long side is not the whole side.
        paint(&state, 6, 4, .water)
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.dock, at: anchor), to: &state),
                       .rejected(.notTouchingWater))

        paint(&state, 6, 5, .water)
        paint(&state, 6, 6, .water)
        guard case .valid = SimulationEngine.validatePlacement(.dock, at: anchor, in: state) else {
            return XCTFail("a fully watered long side should be legal")
        }
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.dock, at: anchor), to: &state), .accepted)
        let dock = try XCTUnwrap(state.building(covering: anchor))
        XCTAssertEqual(dock.tilesCovered(on: state.map).count, 6)
        XCTAssertTrue(longSideOnWater(dock, on: state.map))
    }

    func testEntranceTieBreakIsLowestTileIndex() {
        var state = blankRepublic(size: 16)
        // 2×2 at (5,5). Roads touch (6,5), (5,6) and (6,6), but not (5,5).
        road(&state, 7, 5)
        road(&state, 5, 7)
        road(&state, 6, 7)
        let anchor = state.map.index(x: 5, y: 5)
        guard case .valid(let entrance) = SimulationEngine.validatePlacement(.house, at: anchor, in: state) else {
            return XCTFail("expected a legal house")
        }
        let expected = state.map.index(x: 6, y: 5)
        XCTAssertEqual(entrance, expected, "lowest tile index among road-touching edge tiles")
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: anchor), to: &state), .accepted)
        XCTAssertEqual(state.buildings[0].entrance, expected)
        XCTAssertTrue(state.map.isEntrance(expected))
        XCTAssertFalse(state.map.isEntrance(anchor))
    }

    func testDistrictComesFromTheEntranceTile() {
        var state = blankRepublic(size: 20)
        // 2×2 straddling a hand-painted district boundary. Only (11,10) touches a road.
        for y in 0..<20 {
            for x in 0..<20 {
                let tile = state.map.index(x: Int32(x), y: Int32(y))
                state.map.districtAt[Int(tile.raw)] = x >= 11 ? 4 : 0
            }
        }
        road(&state, 12, 10)
        let anchor = state.map.index(x: 10, y: 10)
        XCTAssertEqual(state.map.district(at: anchor).raw, 0)
        guard case .valid(let entrance) = SimulationEngine.validatePlacement(.house, at: anchor, in: state) else {
            return XCTFail("expected a legal house on the district boundary")
        }
        XCTAssertEqual(entrance, state.map.index(x: 11, y: 10))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: anchor), to: &state), .accepted)
        let house = state.buildings[0]
        XCTAssertEqual(house.district.raw, 4)
        XCTAssertEqual(house.district, state.map.district(at: house.entrance))
    }

    func testOccupancyLookupAndPassableEntrance() throws {
        var state = blankRepublic(size: 16)
        road(&state, 2, 4)
        let anchor = state.map.index(x: 3, y: 4)
        let hashBeforePreview = state.stateHash()
        guard case .valid(let entrance) = SimulationEngine.validatePlacement(.market, at: anchor, in: state) else {
            return XCTFail("market should fit")
        }
        XCTAssertEqual(state.stateHash(), hashBeforePreview, "preview must not mutate state")
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.market, at: anchor), to: &state), .accepted)

        let market = try XCTUnwrap(state.building(covering: anchor))
        XCTAssertEqual(market.kind, .market)
        XCTAssertEqual(market.entrance, entrance)
        let covered = market.tilesCovered(on: state.map)
        XCTAssertEqual(covered.count, 6)
        XCTAssertEqual(covered, state.map.tilesCovered(anchor: anchor, footprint: .init(width: 3, height: 2)))
        for tile in covered {
            XCTAssertEqual(state.map.buildingAt(tile), market.id)
            XCTAssertEqual(state.map.building(at: tile), state.map.buildingAt(tile))
            XCTAssertEqual(state.building(covering: tile)?.id, market.id)
            if tile == entrance {
                XCTAssertTrue(state.map.isPassable(tile))
                XCTAssertTrue(state.map.isEntrance(tile))
            } else {
                XCTAssertFalse(state.map.isPassable(tile), "non-entrance footprint tiles block movement")
                XCTAssertFalse(state.map.isEntrance(tile))
            }
        }
        let outside = state.map.index(x: 3, y: 6)
        XCTAssertNil(state.map.buildingAt(outside))
        XCTAssertNil(state.building(covering: outside))
        XCTAssertFalse(state.map.isPassable(outside))
        XCTAssertTrue(state.map.isPassable(state.map.index(x: 2, y: 4)))

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertEqual(restored.map.buildingAt, state.map.buildingAt)
        XCTAssertEqual(restored.map.entranceAt, state.map.entranceAt)
        XCTAssertEqual(restored.buildings[0].anchor, anchor)
        XCTAssertEqual(restored.buildings[0].entrance, entrance)
    }

    func testFootprintBlocksMovementExceptTheEntrance() {
        var map = WorldMap(width: 12, height: 12)
        for x in Int32(1)...8 { map.road[Int(map.index(x: x, y: 2).raw)] = true }
        var state = RepublicState(worldSeed: 1, config: BalanceConfig(), map: map)
        state.treasury = 10_000
        // Lower road sits against the south edge of the 2×2. Those tiles are not the entrance.
        for x in Int32(1)...8 { state.map.road[Int(state.map.index(x: x, y: 5).raw)] = true }
        let anchor = state.map.index(x: 3, y: 3)
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: anchor), to: &state), .accepted)
        let house = state.buildings[0]
        XCTAssertEqual(house.entrance, state.map.index(x: 3, y: 3))
        XCTAssertTrue(state.map.isPassable(house.entrance))
        XCTAssertFalse(state.map.isPassable(state.map.index(x: 4, y: 3)))
        XCTAssertFalse(state.map.isPassable(state.map.index(x: 3, y: 4)))
        XCTAssertFalse(state.map.isPassable(state.map.index(x: 4, y: 4)))

        let dist = DistanceFields.bfs(map: state.map, sources: [state.map.index(x: 1, y: 2)])
        XCTAssertLessThan(dist[Int(state.map.index(x: 8, y: 2).raw)], DistanceFields.unreachable)
        // (1,2) to (3,2) is 2 along the road, then one step onto the entrance (3,3).
        XCTAssertEqual(dist[Int(house.entrance.raw)], 3)
        XCTAssertEqual(dist[Int(state.map.index(x: 1, y: 5).raw)], DistanceFields.unreachable,
                       "the footprint must not bridge the two roads")
    }

    func testDemolishClearsEveryCoveredTile() {
        var state = blankRepublic(size: 16)
        road(&state, 2, 4)
        let anchor = state.map.index(x: 3, y: 4)
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.clinic, at: anchor), to: &state), .accepted)
        let clinic = state.buildings[0]
        let covered = clinic.tilesCovered(on: state.map)
        XCTAssertEqual(covered.count, 9)
        XCTAssertEqual(SimulationEngine.apply(.demolish(clinic.id), to: &state), .accepted)
        for tile in covered {
            XCTAssertNil(state.map.building(at: tile))
            XCTAssertFalse(state.map.isEntrance(tile))
            XCTAssertFalse(state.map.isPassable(tile))
        }
        XCTAssertNil(state.building(covering: anchor))
        // The record remains, but it no longer owns the ground, so a new building can use it.
        XCTAssertEqual(state.buildings.count, 1)
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.clinic, at: anchor), to: &state), .accepted)
        XCTAssertEqual(state.map.building(at: anchor), state.buildings[1].id)
    }

    func testValidatePlacementAgreesWithApplyAndDoesNotSpend() {
        var poor = blankRepublic(size: 12)
        poor.treasury = 0
        road(&poor, 2, 2)
        let anchor = poor.map.index(x: 2, y: 3)
        let hash = poor.stateHash()
        XCTAssertEqual(SimulationEngine.validatePlacement(.house, at: anchor, in: poor),
                       .rejected(.insufficientTreasury))
        XCTAssertEqual(SimulationEngine.apply(.placeBuilding(.house, at: anchor), to: &poor),
                       .rejected(.insufficientTreasury))
        XCTAssertEqual(poor.stateHash(), hash)

        var blocked = blankRepublic(size: 12)
        road(&blocked, 2, 2)
        blocked.pending = PendingDecision(
            id: DecisionID(1), kind: .famine, raisedOnDay: 0,
            location: EventLocation(), causes: [],
            options: [DecisionOption(id: 0, label: "Wait")])
        XCTAssertEqual(SimulationEngine.validatePlacement(.house, at: anchor, in: blocked),
                       .rejected(.crisisPendingBlocksBuilding))
        XCTAssertEqual(blocked.buildings.count, 0)
    }

    func testGeneratedCityObeysFootprints() {
        let state = WorldGenerator.generate(seed: 42, citizenCount: 120)
        XCTAssertEqual(state.citizens.count, 120, "every starting citizen needs a house")
        XCTAssertFalse(state.buildings.filter { $0.kind == .farm }.isEmpty)
        XCTAssertEqual(state.buildings.filter { $0.kind == .dock }.count, 1)
        for building in state.buildings {
            let covered = building.tilesCovered(on: state.map)
            XCTAssertEqual(covered.count, building.kind.footprint.area, "\(building.kind) footprint clipped")
            var doors = 0
            for tile in covered {
                XCTAssertEqual(state.map.buildingAt(tile), building.id)
                if tile == building.entrance {
                    XCTAssertTrue(state.map.isPassable(tile))
                    XCTAssertTrue(state.map.isEntrance(tile))
                    doors += 1
                } else {
                    XCTAssertFalse(state.map.isPassable(tile))
                }
            }
            XCTAssertEqual(doors, 1)
            XCTAssertEqual(building.district, state.map.district(at: building.entrance))
            XCTAssertTrue(state.map.neighbours(of: building.entrance).contains { state.map.isRoad(at: $0) })
            if building.kind == .farm {
                let fertile = covered.filter { state.map.terrain(at: $0) == .fertile }.count
                XCTAssertGreaterThanOrEqual(fertile * 2, covered.count)
            }
            if building.kind == .dock {
                XCTAssertTrue(longSideOnWater(building, on: state.map))
            }
        }
    }

    // MARK: - Fixtures

    private func blankRepublic(size: Int32) -> RepublicState {
        var state = RepublicState(worldSeed: 1, config: BalanceConfig(), map: WorldMap(width: size, height: size))
        state.treasury = 1_000_000
        state.districts = (0..<9).map { District(id: DistrictID(UInt8($0)), name: "District \($0)") }
        return state
    }

    private func road(_ state: inout RepublicState, _ x: Int32, _ y: Int32) {
        state.map.road[Int(state.map.index(x: x, y: y).raw)] = true
    }

    private func paint(_ state: inout RepublicState, _ x: Int32, _ y: Int32, _ kind: TerrainKind) {
        state.map.terrain[Int(state.map.index(x: x, y: y).raw)] = kind.rawValue
    }

    /// Paints the first `count` footprint tiles, row-major, as fertile and the rest as grass.
    private func markFertile(_ state: inout RepublicState, anchor: (Int32, Int32), count: Int) {
        var seen = 0
        for dy in 0..<3 {
            for dx in 0..<3 {
                paint(&state, anchor.0 + Int32(dx), anchor.1 + Int32(dy), seen < count ? .fertile : .grass)
                seen += 1
            }
        }
    }

    private func longSideOnWater(_ building: Building, on map: WorldMap) -> Bool {
        let originX = map.x(of: building.anchor)
        let originY = map.y(of: building.anchor)
        let width = building.kind.footprint.width
        let height = building.kind.footprint.height
        func water(_ x: Int32, _ y: Int32) -> Bool {
            map.contains(x: x, y: y) && map.terrain(at: map.index(x: x, y: y)) == .water
        }
        if height > width {
            let left = (0..<height).allSatisfy { water(originX - 1, originY + $0) }
            let right = (0..<height).allSatisfy { water(originX + width, originY + $0) }
            return left || right
        }
        let top = (0..<width).allSatisfy { water(originX + $0, originY - 1) }
        let bottom = (0..<width).allSatisfy { water(originX + $0, originY + height) }
        return top || bottom
    }
}
