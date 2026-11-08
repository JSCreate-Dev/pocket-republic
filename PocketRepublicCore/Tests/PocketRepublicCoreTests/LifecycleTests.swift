import XCTest
@testable import PocketRepublicCore

/// Demolition leaves the building record in place so ids stay dense. These tests
/// lock the rule that a ghost does not charge upkeep, hire, produce, serve, or
/// attract a walker.
final class LifecycleTests: XCTestCase {

    func testDemolishedBuildingsStopChargingUpkeep() throws {
        var s = makeFlatWorld()
        let police = try place(.police, at: s.map.index(x: 1, y: 6), in: &s)
        let market = try place(.market, at: s.map.index(x: 5, y: 6), in: &s)
        let open = s.treasury
        SimulationEngine.payUpkeep(&s)
        XCTAssertEqual(s.treasury, open - s.config.upkeepCivic - s.config.upkeepPrivate)

        XCTAssertEqual(SimulationEngine.apply(.demolish(police), to: &s), .accepted)
        let afterPolice = s.treasury
        SimulationEngine.payUpkeep(&s)
        XCTAssertEqual(s.treasury, afterPolice - s.config.upkeepPrivate,
                       "a demolished civic building must not keep its upkeep")

        XCTAssertEqual(SimulationEngine.apply(.demolish(market), to: &s), .accepted)
        let bare = s.treasury
        SimulationEngine.payUpkeep(&s)
        XCTAssertEqual(s.treasury, bare)

        var pacing = EventPacing.standard
        pacing.chancePercent = 0
        s.config.eventPacing = pacing
        for _ in 0..<5 { SimulationEngine.advance(&s) }
        XCTAssertEqual(s.treasury, bare, "later days must not bill a building that is gone")
        XCTAssertFalse(s.buildings[Int(police.raw)].isStanding(on: s.map))
        XCTAssertTrue(s.buildings[Int(police.raw)].isOperational,
                      "construction-finished stays true; standing is the economy gate")
        try s.checkConservation()
    }

    func testDemolishedWorkplaceIsNotRestaffedOrPaid() throws {
        var s = makeFlatWorld()
        let house = try place(.house, at: s.map.index(x: 1, y: 6), in: &s)
        let farm = try place(.farm, at: s.map.index(x: 5, y: 6), in: &s)
        let worker = addCitizen(home: house, in: &s)
        SimulationEngine.rebuildSpatialCaches(&s)

        SimulationEngine.assignWork(&s)
        XCTAssertEqual(s.citizens[Int(worker.raw)].work, farm)

        XCTAssertEqual(SimulationEngine.apply(.demolish(farm), to: &s), .accepted)
        XCTAssertNil(s.citizens[Int(worker.raw)].work)

        SimulationEngine.assignWork(&s)
        XCTAssertNil(s.citizens[Int(worker.raw)].work, "the ghost farm must not hire")
        XCTAssertTrue(s.buildings[Int(farm.raw)].workers.isEmpty)
        let beforeFood = s.buildings[Int(farm.raw)].foodStore
        SimulationEngine.produce(&s)
        XCTAssertEqual(s.buildings[Int(farm.raw)].foodStore, beforeFood)

        // A stale pointer, as if a later system put the worker back on the rubble.
        s.citizens[Int(worker.raw)].work = farm
        s.citizens[Int(worker.raw)].occupation = .farmer
        s.buildings[Int(farm.raw)].workers = [worker]
        s.transfer(from: .external, to: .building(farm), 40)
        let pocket = s.citizens[Int(worker.raw)].money
        SimulationEngine.payWages(&s)
        XCTAssertEqual(s.citizens[Int(worker.raw)].money, pocket, "a ghost does not pay wages")

        SimulationEngine.assignWork(&s)
        XCTAssertNil(s.citizens[Int(worker.raw)].work)
        XCTAssertEqual(s.citizens[Int(worker.raw)].occupation, .unemployed)
        XCTAssertTrue(s.buildings[Int(farm.raw)].workers.isEmpty)
        XCTAssertTrue(s.events.contains {
            $0.kind == .citizenUnemployed && $0.subjects == [worker]
                && $0.causes.contains { $0.detail == "workplace closed" }
        })
        try s.checkConservation()
    }

    func testDemolishedMarketStopsServingAndRouting() throws {
        var s = makeFlatWorld()
        let house = try place(.house, at: s.map.index(x: 1, y: 6), in: &s)
        let market = try place(.market, at: s.map.index(x: 6, y: 6), in: &s)
        let clinic = try place(.clinic, at: s.map.index(x: 10, y: 6), in: &s)
        let door = s.buildings[Int(house.raw)].entrance
        SimulationEngine.rebuildSpatialCaches(&s)
        XCTAssertEqual(s.fields.nearestMarket(at: door), market)
        XCTAssertLessThan(s.fields.distance(.clinic, at: door), .max)

        XCTAssertEqual(SimulationEngine.apply(.demolish(market), to: &s), .accepted)
        XCTAssertEqual(SimulationEngine.apply(.demolish(clinic), to: &s), .accepted)

        // The distance cache is rebuilt on the next advance. Routing must still
        // refuse the door the map no longer owns, before that rebuild.
        let access = s.buildingAccess()
        XCTAssertNil(access.entrance(of: market))
        XCTAssertNil(access.entrance(of: clinic))
        let resident = addCitizen(home: house, in: &s)
        let routine = WalkerRoutine.plan(for: s.citizens[Int(resident.raw)], in: s, access: access)
        XCTAssertFalse(routine.stops.contains(.market))
        XCTAssertFalse(routine.stops.contains(.work))

        SimulationEngine.rebuildSpatialCaches(&s)
        XCTAssertNil(s.fields.nearestMarket(at: door))
        XCTAssertNil(SimulationEngine.shoppingMarket(s, homeTile: door))
        XCTAssertEqual(s.fields.distance(.clinic, at: door), DistanceFields.unreachable)
        XCTAssertEqual(s.fields.distance(.market, at: door), DistanceFields.unreachable)
        XCTAssertFalse(s.snapshot().visibleBuildings.contains { $0.id == market })
        try s.checkConservation()
    }

    private func makeFlatWorld() -> RepublicState {
        var s = RepublicState(worldSeed: 7, config: BalanceConfig(), map: WorldMap(width: 16, height: 14))
        s.config.constructionDaysMultiplierPercent = 0
        s.districts = [District(id: DistrictID(0), name: "Old Town")]
        for raw in 0..<Int32(s.map.tileCount) {
            s.map.terrain[Int(raw)] = TerrainKind.fertile.rawValue
        }
        for x in Int32(0)..<16 { s.map.road[Int(s.map.index(x: x, y: 5).raw)] = true }
        s.transfer(from: .external, to: .treasury, 10_000)
        s.fields.rebuild(map: s.map, buildings: s.buildings)
        return s
    }

    private func place(_ kind: BuildingKind, at tile: TileIndex, in s: inout RepublicState) throws -> BuildingID {
        let outcome = SimulationEngine.apply(.placeBuilding(kind, at: tile), to: &s)
        XCTAssertEqual(outcome, .accepted, "could not place \(kind)")
        return try XCTUnwrap(s.buildings.last?.id)
    }

    private func addCitizen(home: BuildingID, in s: inout RepublicState) -> CitizenID {
        let id = CitizenID(s.nextCitizenRaw)
        s.nextCitizenRaw += 1
        var citizen = Citizen(id: id, name: "Ada", age: 30, district: DistrictID(0),
                              money: 0, happiness: 55, loyalty: 55, ambition: 40, influence: 10)
        citizen.home = home
        s.citizens.append(citizen)
        s.buildings[Int(home.raw)].residents.append(id)
        s.transfer(from: .external, to: .citizen(id), 12)
        return id
    }
}
