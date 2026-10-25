import XCTest
@testable import PocketRepublicCore

final class BuildingInspectionTests: XCTestCase {

    func testTileCentersRoundTrip() {
        let map = WorldMap(width: 5, height: 4)
        for y in 0..<map.height {
            for x in 0..<map.width {
                let point = CityProjection.worldPoint(x: x, y: y)
                XCTAssertEqual(BuildingHitTest.tile(at: point, in: map), map.index(x: x, y: y))
            }
        }
        XCTAssertNil(BuildingHitTest.tile(at: CityPoint(x: 1_000_000, y: 1_000_000), in: map))
    }

    /// A footprint tile that is not the origin still selects the occupying building.
    func testOccupancyBeatsOriginTile() {
        var state = makeState(width: 6, height: 6)
        let origin = state.map.index(x: 1, y: 1)
        let covered = state.map.index(x: 2, y: 2)
        let id = place(.clinic, at: origin, in: &state)
        state.map.buildingAt[Int(origin.raw)] = -1
        state.map.buildingAt[Int(covered.raw)] = id.raw

        let hit = BuildingHitTest.building(at: CityProjection.worldPoint(x: 2, y: 2), in: state)
        XCTAssertEqual(hit?.id, id)
        XCTAssertEqual(hit?.tile, origin, "the tap resolves occupancy, not Building.tile")
        XCTAssertNil(BuildingHitTest.building(at: CityProjection.worldPoint(x: 1, y: 1), in: state))
        XCTAssertEqual(BuildingHitTest.occupiedTiles(id, on: state.map), [covered])
    }

    func testRoadAccessUsesAnyOccupiedTileAndIgnoresDiagonals() {
        var state = makeState()
        let origin = state.map.index(x: 2, y: 2)
        let covered = state.map.index(x: 3, y: 2)
        let id = place(.workshop, at: origin, in: &state, alsoCovering: [covered])

        pave(4, 3, in: &state)
        XCTAssertFalse(BuildingHitTest.hasRoadAccess(id, on: state.map), "a diagonal road is not access")

        pave(3, 1, in: &state)
        XCTAssertTrue(BuildingHitTest.hasRoadAccess(id, on: state.map),
                      "a road beside a non-origin footprint tile counts")
    }

    func testCatalogMatchesTheInspectSpec() throws {
        let service: Set<BuildingKind> = [.market, .clinic, .school, .police]
        let modeKinds: Set<BuildingKind> = [.farm, .workshop, .dock]
        for kind in BuildingKind.allCases {
            var state = makeState()
            pave(2, 1, in: &state)
            let id = place(kind, at: state.map.index(x: 2, y: 2), in: &state, day: 6)
            let inspection = try XCTUnwrap(BuildingInspector.make(id: id, in: state))
            XCTAssertFalse(inspection.name.isEmpty)
            XCTAssertFalse(inspection.typeName.isEmpty)
            XCTAssertEqual(inspection.districtName, "Old Town")
            XCTAssertEqual(inspection.canDemolish, kind != .townHall)
            XCTAssertEqual(inspection.modeChoices.isEmpty, !modeKinds.contains(kind))
            if modeKinds.contains(kind) {
                XCTAssertEqual(inspection.modeChoices.map(\.label), ["Balanced", "Intensive", "Careful"])
                XCTAssertEqual(inspection.selectedMode, .balanced)
            } else {
                XCTAssertNil(inspection.selectedMode)
            }
            XCTAssertEqual(inspection.sections.map(\.id), ["status", "people", "numbers"])

            let titles = inspection.sections.flatMap(\.rows).map(\.title)
            if kind == .house {
                XCTAssertTrue(titles.contains("Residents"))
                XCTAssertFalse(titles.contains("Workers"))
            } else {
                XCTAssertTrue(titles.contains("Workers"))
                XCTAssertFalse(titles.contains("Residents"))
            }
            let numbers = try XCTUnwrap(inspection.sections.first { $0.id == "numbers" })
            var expected = [String]()
            if kind.storesFood { expected.append("Food stored") }
            expected.append(contentsOf: ["Funds", "Upkeep"])
            if service.contains(kind) { expected.append("Residents in range") }
            expected.append("Built")
            XCTAssertEqual(numbers.rows.map(\.title), expected)
        }
    }

    func testStatusPriority() throws {
        var cutOff = makeState()
        let cutOffID = place(.market, at: cutOff.map.index(x: 2, y: 2), in: &cutOff)
        staff(cutOffID, count: 0, in: &cutOff)
        cutOff.buildings[Int(cutOffID.raw)].foodStore = 0
        XCTAssertEqual(try status(of: cutOffID, in: cutOff), "No road access")

        var short = makeState()
        pave(2, 1, in: &short)
        let shortID = place(.market, at: short.map.index(x: 2, y: 2), in: &short)
        short.buildings[Int(shortID.raw)].foodStore = 0
        XCTAssertEqual(try status(of: shortID, in: short), "Understaffed")

        var empty = makeState()
        pave(2, 1, in: &empty)
        let emptyID = place(.market, at: empty.map.index(x: 2, y: 2), in: &empty)
        staff(emptyID, count: Int(BuildingKind.market.workerCapacity), in: &empty)
        empty.buildings[Int(emptyID.raw)].foodStore = 0
        XCTAssertEqual(try status(of: emptyID, in: empty), "No food")

        var fine = makeState()
        pave(2, 1, in: &fine)
        let fineID = place(.market, at: fine.map.index(x: 2, y: 2), in: &fine)
        staff(fineID, count: Int(BuildingKind.market.workerCapacity), in: &fine)
        fine.buildings[Int(fineID.raw)].foodStore = 8
        let inspection = try XCTUnwrap(BuildingInspector.make(id: fineID, in: fine))
        XCTAssertEqual(try status(of: fineID, in: fine), "Running well")
        XCTAssertEqual(row(inspection, "Food stored")?.value, "8")
        XCTAssertEqual(row(inspection, "Workers")?.value, "2 / 2")
        XCTAssertEqual(inspection.sections.first?.rows.first?.tone, .calm)
    }

    func testHouseResidentsHungerAndJob() throws {
        var state = makeState()
        pave(1, 2, in: &state)
        let house = place(.house, at: state.map.index(x: 2, y: 2), in: &state, day: 4)
        state.buildings[Int(house.raw)].funds = 15
        addResident(home: house, name: "Elena Ruiz", occupation: .farmer, daysHungry: 2, in: &state)
        addResident(home: house, name: "Luis Vega", occupation: .unemployed, daysHungry: 0, in: &state)
        var dead = Citizen(id: CitizenID(Int32(state.citizens.count)), name: "Gone", age: 40,
                           district: DistrictID(0), money: 0, happiness: 10, loyalty: 10,
                           ambition: 1, influence: 1)
        dead.alive = false
        dead.home = house
        dead.daysHungry = 9
        state.citizens.append(dead)
        state.buildings[Int(house.raw)].residents.append(dead.id)

        let inspection = try XCTUnwrap(BuildingInspector.make(id: house, in: state))
        XCTAssertEqual(inspection.name, "House")
        XCTAssertEqual(inspection.typeName, "Housing")
        XCTAssertEqual(try status(of: house, in: state), "No food")
        XCTAssertEqual(row(inspection, "Residents")?.value, "2 / 4")
        XCTAssertEqual(row(inspection, "Elena Ruiz")?.value, "Farmer · Hungry 2 days")
        XCTAssertEqual(row(inspection, "Luis Vega")?.value, "Unemployed · Fed")
        XCTAssertNil(row(inspection, "Gone"))
        XCTAssertNil(row(inspection, "Workers"))
        XCTAssertNil(row(inspection, "Food stored"))
        XCTAssertEqual(row(inspection, "Funds")?.value, "$15")
        XCTAssertEqual(row(inspection, "Upkeep")?.value, "$0/day")
        XCTAssertEqual(row(inspection, "Built")?.value, "Day 4")
        XCTAssertTrue(inspection.modeChoices.isEmpty)
        XCTAssertTrue(inspection.canDemolish)
        XCTAssertEqual(inspection.sections.map(\.id), ["status", "people", "numbers"])
    }

    func testServiceReachUsesMaxServiceDistance() throws {
        var state = makeState(width: 40, height: 3)
        for x in Int32(0)...30 { pave(x, 0, in: &state) }
        let clinic = place(.clinic, at: state.map.index(x: 0, y: 1), in: &state)
        let near = place(.house, at: state.map.index(x: 18, y: 1), in: &state)
        let far = place(.house, at: state.map.index(x: 19, y: 1), in: &state)
        addResident(home: near, name: "Near", occupation: .unemployed, daysHungry: 0, in: &state)
        addResident(home: far, name: "Far", occupation: .unemployed, daysHungry: 0, in: &state)
        var dead = Citizen(id: CitizenID(Int32(state.citizens.count)), name: "Absent", age: 20,
                           district: DistrictID(0), money: 0, happiness: 10, loyalty: 10,
                           ambition: 1, influence: 1)
        dead.alive = false
        dead.home = near
        state.citizens.append(dead)
        addResident(home: nil, name: "Homeless", occupation: .unemployed, daysHungry: 0, in: &state)

        state.config.maxServiceDistance = 20
        let inRange = try XCTUnwrap(BuildingInspector.make(id: clinic, in: state))
        XCTAssertEqual(row(inRange, "Residents in range")?.value, "1")

        state.config.maxServiceDistance = 19
        let tooFar = try XCTUnwrap(BuildingInspector.make(id: clinic, in: state))
        XCTAssertEqual(row(tooFar, "Residents in range")?.value, "0")
    }

    func testUpkeepReadsBalanceConfig() throws {
        var state = makeState()
        pave(2, 1, in: &state)
        state.config.upkeepCivic = 9
        state.config.upkeepPrivate = 4
        let clinic = place(.clinic, at: state.map.index(x: 2, y: 2), in: &state)
        let farm = place(.farm, at: state.map.index(x: 4, y: 2), in: &state)
        pave(4, 1, in: &state)
        let clinicPanel = try XCTUnwrap(BuildingInspector.make(id: clinic, in: state))
        let farmPanel = try XCTUnwrap(BuildingInspector.make(id: farm, in: state))
        XCTAssertEqual(row(clinicPanel, "Upkeep")?.value, "$9/day")
        XCTAssertEqual(row(farmPanel, "Upkeep")?.value, "$4/day")
        XCTAssertNil(row(farmPanel, "Residents in range"))
        XCTAssertEqual(row(farmPanel, "Food stored")?.value, "0")
    }

    func testDemolishedBuildingIsNotInspectable() {
        var state = makeState()
        let tile = state.map.index(x: 1, y: 1)
        let id = place(.house, at: tile, in: &state)
        state.map.buildingAt[Int(tile.raw)] = -1
        XCTAssertNil(BuildingHitTest.building(on: tile, in: state))
        XCTAssertNil(BuildingInspector.make(id: id, in: state))
    }

    func testSetOperatingModeUsesTheCommandAndLeavesTheMapAlone() throws {
        var state = makeState()
        pave(2, 1, in: &state)
        let farm = place(.farm, at: state.map.index(x: 2, y: 2), in: &state)
        state.fields.rebuild(map: state.map, buildings: state.buildings)
        XCTAssertFalse(state.fields.dirty)
        let treasury = state.treasury

        XCTAssertEqual(SimulationEngine.apply(.setOperatingMode(farm, .careful), to: &state), .accepted)
        XCTAssertEqual(state.buildings[Int(farm.raw)].mode, .careful)
        XCTAssertFalse(state.fields.dirty)
        XCTAssertEqual(state.treasury, treasury)
        XCTAssertEqual(state.day, 0)

        let house = place(.house, at: state.map.index(x: 4, y: 2), in: &state)
        pave(4, 1, in: &state)
        XCTAssertEqual(SimulationEngine.apply(.setOperatingMode(house, .intensive), to: &state),
                       .rejected(.operatingModeNotOffered))
        XCTAssertEqual(state.buildings[Int(house.raw)].mode, .balanced)
        XCTAssertEqual(state.buildings[Int(farm.raw)].mode, .careful)

        for kind in [BuildingKind.workshop, .dock] {
            var works = makeState()
            let id = place(kind, at: works.map.index(x: 1, y: 1), in: &works)
            XCTAssertEqual(SimulationEngine.apply(.setOperatingMode(id, .intensive), to: &works), .accepted)
            XCTAssertEqual(works.buildings[Int(id.raw)].mode, .intensive)
        }

        XCTAssertEqual(SimulationEngine.apply(.setOperatingMode(BuildingID(40), .balanced), to: &state),
                       .rejected(.noSuchBuilding))
        state.map.buildingAt[Int(state.buildings[Int(farm.raw)].tile.raw)] = -1
        XCTAssertEqual(SimulationEngine.apply(.setOperatingMode(farm, .intensive), to: &state),
                       .rejected(.noSuchBuilding))
    }

    // MARK: - Fixtures

    private func makeState(width: Int32 = 8, height: Int32 = 8) -> RepublicState {
        var state = RepublicState(worldSeed: 1, config: BalanceConfig(), map: WorldMap(width: width, height: height))
        state.districts = [District(id: DistrictID(0), name: "Old Town")]
        return state
    }

    @discardableResult
    private func place(_ kind: BuildingKind, at tile: TileIndex, in state: inout RepublicState,
                       alsoCovering extra: [TileIndex] = [], day: Int32 = 4) -> BuildingID {
        let id = BuildingID(Int32(state.buildings.count))
        state.buildings.append(Building(id: id, kind: kind, tile: tile,
                                        district: DistrictID(0), builtOnDay: day))
        state.map.buildingAt[Int(tile.raw)] = id.raw
        for other in extra where Int(other.raw) >= 0 && Int(other.raw) < state.map.tileCount {
            state.map.buildingAt[Int(other.raw)] = id.raw
        }
        return id
    }

    private func pave(_ x: Int32, _ y: Int32, in state: inout RepublicState) {
        state.map.road[Int(state.map.index(x: x, y: y).raw)] = true
    }

    private func staff(_ id: BuildingID, count: Int, in state: inout RepublicState) {
        var workers: [CitizenID] = []
        for index in 0..<count {
            let cid = CitizenID(Int32(state.citizens.count))
            state.citizens.append(Citizen(
                id: cid, name: "Worker \(index)", age: 30, district: DistrictID(0),
                money: 5, happiness: 50, loyalty: 50, ambition: 1, influence: 1
            ))
            workers.append(cid)
        }
        state.buildings[Int(id.raw)].workers = workers
    }

    @discardableResult
    private func addResident(home: BuildingID?, name: String, occupation: Occupation, daysHungry: Int32,
                             in state: inout RepublicState) -> CitizenID {
        let id = CitizenID(Int32(state.citizens.count))
        var citizen = Citizen(id: id, name: name, age: 30, district: DistrictID(0),
                              money: 10, happiness: 50, loyalty: 50, ambition: 1, influence: 1)
        citizen.home = home
        citizen.occupation = occupation
        citizen.daysHungry = daysHungry
        state.citizens.append(citizen)
        if let home, Int(home.raw) < state.buildings.count {
            state.buildings[Int(home.raw)].residents.append(id)
        }
        return id
    }

    private func status(of id: BuildingID, in state: RepublicState) throws -> String {
        let inspection = try XCTUnwrap(BuildingInspector.make(id: id, in: state))
        return try XCTUnwrap(inspection.sections.first?.rows.first).value
    }

    private func row(_ inspection: BuildingInspection, _ title: String) -> InspectRow? {
        inspection.sections.flatMap(\.rows).first { $0.title == title }
    }
}
