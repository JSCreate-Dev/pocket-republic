import XCTest
@testable import PocketRepublicCore

final class WalkerRoutineTests: XCTestCase {

    func testEmployedCitizenWalksHomeWorkMarketHome() throws {
        let (state, citizen) = try employedShopper()
        let access = state.buildingAccess()
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: access)
        XCTAssertEqual(routine.stops.filter { [.home, .work, .market].contains($0) }, [.home, .work, .market, .home])
        XCTAssertEqual(routine.tile(atHour: 0), routine.entrances[0])
        XCTAssertEqual(routine.tile(atHour: 3), routine.entrances[0])
        XCTAssertEqual(routine.tile(atHour: 10), routine.entrances[1])
        XCTAssertEqual(routine.tile(atHour: routine.dwellStart[2]), routine.entrances[2])
        XCTAssertEqual(routine.tile(atHour: 23), routine.entrances.last!)
        XCTAssertEqual(routine.entrances[0], routine.entrances.last!)
        XCTAssertNotEqual(routine.entrances[0], routine.entrances[1])
        XCTAssertNotEqual(routine.entrances[1], routine.entrances[2])

        let homeTile = state.buildings[Int(citizen.home!.raw)].tile
        let market = try XCTUnwrap(SimulationEngine.shoppingMarket(state, homeTile: homeTile))
        XCTAssertEqual(routine.entrances[2], access.entrance(of: market),
                       "the market stop is the entrance of the market this citizen buys from")
        XCTAssertEqual(routine, WalkerRoutine.plan(for: citizen, in: state, access: access))

        let travel = routine.tile(atHour: routine.dwellEnd[0])
        XCTAssertTrue(routine.legPaths[0].contains(travel))
        XCTAssertNotEqual(routine.stops, [.home, .work, .home])
    }

    func testUnemployedCitizenSkipsWorkAndStillShops() throws {
        let (state, citizen) = try employedShopper()
        var idle = citizen
        idle.work = nil
        let routine = WalkerRoutine.plan(for: idle, in: state, access: state.buildingAccess())
        XCTAssertEqual(routine.stops.filter { [.home, .work, .market].contains($0) }, [.home, .market, .home])
        XCTAssertFalse(routine.stops.contains(.work))
        XCTAssertEqual(routine.tile(atHour: routine.dwellStart[1]), routine.entrances[1])
        XCTAssertEqual(routine.tile(atHour: 22), routine.entrances.last!)
    }

    func testNoMarketWhenTheDoorIsOutOfRange() throws {
        var (state, citizen) = try employedShopper()
        state.config.maxServiceDistance = 0
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        XCTAssertEqual(routine.stops.filter { [.home, .work, .market].contains($0) }, [.home, .work, .home])
        XCTAssertFalse(routine.stops.contains(.market))
    }

    func testRoutineTargetsTheEntranceFromTheAccessInterface() throws {
        let (state, citizen) = try employedShopper()
        let home = try XCTUnwrap(citizen.home)
        let floor = state.buildings[Int(home.raw)].tile
        let door = try XCTUnwrap(state.map.neighbours(of: floor).first { state.map.isRoad(at: $0) })
        let access = DoorOverride(base: state.buildingAccess(), building: home, door: door)
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: access)
        XCTAssertEqual(routine.entrances[0], door)
        XCTAssertNotEqual(door, floor)
        XCTAssertEqual(access.building(at: floor), home)
    }

    func testPathGoesAroundABlockedFootprint() {
        var map = WorldMap(width: 11, height: 9)
        func markRoad(_ x: Int32, _ y: Int32) {
            map.road[Int(map.index(x: x, y: y).raw)] = true
        }
        for x in Int32(2)...8 {
            markRoad(x, 2)
            markRoad(x, 4) // cuts through the footprint; passable on the map, blocked by access
            markRoad(x, 6) // south edge, so the entrance at (5, 5) has a walkable doorstep
        }
        for y in Int32(2)...6 {
            markRoad(2, y)
            markRoad(8, y)
        }
        let building = BuildingID(1)
        var occupied: [Int32: BuildingID] = [:]
        var blocked: [TileIndex] = []
        let entrance = map.index(x: 5, y: 5)
        for y in Int32(3)...5 {
            for x in Int32(4)...6 {
                let tile = map.index(x: x, y: y)
                occupied[tile.raw] = building
                if tile != entrance { blocked.append(tile) }
            }
        }
        let access = FootprintAccess(occupied: occupied, entrance: entrance, building: building,
                                     roads: Set(map.road.enumerated().compactMap { $0.element ? Int32($0.offset) : nil }))
        let start = map.index(x: 2, y: 4)
        let goal = map.index(x: 8, y: 4)
        let path = Pathfinder.path(from: start, to: goal, map: map, access: access)
        XCTAssertEqual(path.first, start)
        XCTAssertEqual(path.last, goal)
        XCTAssertGreaterThan(path.count, 7, "the straight cut is 7 tiles; the walk must go around")
        for tile in blocked {
            XCTAssertFalse(path.contains(tile), "path entered blocked footprint tile \(tile.raw)")
        }
        let toDoor = Pathfinder.path(from: start, to: entrance, map: map, access: access)
        XCTAssertEqual(toDoor.last, entrance)
        XCTAssertFalse(toDoor.contains(map.index(x: 5, y: 4)))
        XCTAssertEqual(access.building(at: entrance), building)
        XCTAssertEqual(access.entrance(of: building), entrance)
        XCTAssertFalse(access.isPassable(map.index(x: 5, y: 4)))
        XCTAssertTrue(access.isPassable(entrance))
    }

    func testRouteVariationPreservesShortestLengthAndPassability() {
        var map = WorldMap(width: 8, height: 8)
        for i in map.road.indices { map.road[i] = true }
        let access = MapBuildingAccess(map: map, buildings: [])
        let start = map.index(x: 1, y: 1)
        let end = map.index(x: 6, y: 6)
        let baseline = Pathfinder.path(from: start, to: end, map: map, access: access)
        var distinct = Set<String>()
        for variation in UInt64(1)...16 {
            let route = Pathfinder.path(from: start, to: end, map: map, access: access, variation: variation)
            XCTAssertEqual(route.count, baseline.count)
            XCTAssertEqual(route.last, end)
            XCTAssertTrue(route.allSatisfy { access.isPassable($0) })
            for pair in zip(route, route.dropFirst()) {
                XCTAssertTrue(map.neighbours(of: pair.0).contains(pair.1))
            }
            distinct.insert(route.map { String($0.raw) }.joined(separator: ","))
        }
        XCTAssertGreaterThan(distinct.count, 1)
    }

    func testDisconnectedWorkerStaysHomeWithoutTeleporting() throws {
        var (state, citizen) = try employedShopper()
        for i in state.map.road.indices { state.map.road[i] = false }
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        XCTAssertEqual(routine.stops, [.home])
        XCTAssertTrue(routine.legPaths.isEmpty)
    }

    func testRoutineReaderDoesNotChangeSavedState() throws {
        let (state, citizen) = try employedShopper()
        let before = state.stateHash()
        let first = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        XCTAssertEqual(first, WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess()))
        XCTAssertEqual(before, state.stateHash())
    }

    func testActivityChangesAtDepartureAndArrival() throws {
        let (state, citizen) = try employedShopper()
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        XCTAssertEqual(routine.activity(atHour: 0), .staying(.home))
        XCTAssertEqual(routine.activity(atHour: Double(routine.dwellEnd[0]) - 0.01), .staying(.home))
        XCTAssertEqual(routine.activity(atHour: Double(routine.dwellEnd[0])), .traveling(to: routine.stops[1]))
        XCTAssertEqual(routine.activity(atHour: Double(routine.dwellStart[1])), .staying(routine.stops[1]))
        XCTAssertEqual(routine.activity(atHour: 23.99), .staying(.home))
    }

    func testActivityRejectsInvalidHoursAndEmptyRoutines() throws {
        let (state, citizen) = try employedShopper()
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        for hour in [Double.nan, .infinity, -1, 24] { XCTAssertNil(routine.activity(atHour: hour)) }
        var empty = routine
        empty.stops = []
        XCTAssertNil(empty.activity(atHour: 12))
    }

    func testActivityDoesNotCallAnUnreachableLegWalking() throws {
        let (state, citizen) = try employedShopper()
        var routine = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        routine.legPaths[0] = [routine.entrances[0]]
        XCTAssertNil(routine.activity(atHour: Double(routine.dwellEnd[0])))
    }

    private func employedShopper() throws -> (RepublicState, Citizen) {
        var state = WorldGenerator.generate(seed: 3, citizenCount: 80)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        let citizen = try XCTUnwrap(state.citizens.first { c in
            guard let home = c.home, let work = c.work else { return false }
            let tile = state.buildings[Int(home.raw)].tile
            guard let market = SimulationEngine.shoppingMarket(state, homeTile: tile) else { return false }
            let homeTile = state.buildings[Int(home.raw)].tile
            let workTile = state.buildings[Int(work.raw)].tile
            let marketTile = state.buildings[Int(market.raw)].tile
            return homeTile != workTile && workTile != marketTile
        })
        return (state, citizen)
    }
}

private struct DoorOverride: BuildingAccess {
    var base: MapBuildingAccess
    var building: BuildingID
    var door: TileIndex
    func building(at tile: TileIndex) -> BuildingID? { base.building(at: tile) }
    func entrance(of id: BuildingID) -> TileIndex? {
        id == building ? door : base.entrance(of: id)
    }
    func isPassable(_ tile: TileIndex) -> Bool { base.isPassable(tile) || tile == door }
}

private struct FootprintAccess: BuildingAccess {
    var occupied: [Int32: BuildingID]
    var entrance: TileIndex
    var building: BuildingID
    var roads: Set<Int32>
    func building(at tile: TileIndex) -> BuildingID? { occupied[tile.raw] }
    func entrance(of id: BuildingID) -> TileIndex? { id == building ? entrance : nil }
    func isPassable(_ tile: TileIndex) -> Bool {
        if occupied[tile.raw] != nil { return tile == entrance }
        return roads.contains(tile.raw)
    }
}
