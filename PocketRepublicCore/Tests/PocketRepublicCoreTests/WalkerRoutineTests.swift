import XCTest
@testable import PocketRepublicCore

final class WalkerRoutineTests: XCTestCase {

    func testEmployedCitizenWalksHomeWorkMarketHome() throws {
        let (state, citizen) = try employedShopper()
        let access = state.buildingAccess()
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: access)
        XCTAssertEqual(routine.stops, [.home, .work, .market, .home])
        XCTAssertEqual(routine.tile(atHour: 0), routine.entrances[0])
        XCTAssertEqual(routine.tile(atHour: 6), routine.entrances[0])
        XCTAssertEqual(routine.tile(atHour: 10), routine.entrances[1])
        XCTAssertEqual(routine.tile(atHour: 16), routine.entrances[2])
        XCTAssertEqual(routine.tile(atHour: 23), routine.entrances[3])
        XCTAssertEqual(routine.entrances[0], routine.entrances[3])
        XCTAssertNotEqual(routine.entrances[0], routine.entrances[1])
        XCTAssertNotEqual(routine.entrances[1], routine.entrances[2])

        let homeTile = state.buildings[Int(citizen.home!.raw)].tile
        let market = try XCTUnwrap(SimulationEngine.shoppingMarket(state, homeTile: homeTile))
        XCTAssertEqual(routine.entrances[2], access.entrance(of: market),
                       "the market stop is the entrance of the market this citizen buys from")
        XCTAssertEqual(routine, WalkerRoutine.plan(for: citizen, in: state, access: access))

        let travel = routine.tile(atHour: 7)
        XCTAssertTrue(routine.legPaths[0].contains(travel))
        XCTAssertNotEqual(routine.stops, [.home, .work, .home])
    }

    func testUnemployedCitizenSkipsWorkAndStillShops() throws {
        let (state, citizen) = try employedShopper()
        var idle = citizen
        idle.work = nil
        let routine = WalkerRoutine.plan(for: idle, in: state, access: state.buildingAccess())
        XCTAssertEqual(routine.stops, [.home, .market, .home])
        XCTAssertFalse(routine.stops.contains(.work))
        XCTAssertEqual(routine.tile(atHour: 9), routine.entrances[1])
        XCTAssertEqual(routine.tile(atHour: 22), routine.entrances[2])
    }

    func testNoMarketWhenTheDoorIsOutOfRange() throws {
        var (state, citizen) = try employedShopper()
        state.config.maxServiceDistance = 0
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        XCTAssertEqual(routine.stops, [.home, .work, .home])
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
