import XCTest
@testable import PocketRepublicCore

/// Construction stages, per docs/DESIGN.md section 7.12.
final class ConstructionTests: XCTestCase {

    // MARK: - The day table and the split (7.3, 7.4)

    func testBuildTimesMatchTheSpecTable() {
        let config = BalanceConfig()
        XCTAssertEqual(config.constructionDays(for: .townHall), 0, "the town hall is never a site")
        XCTAssertEqual(config.constructionDays(for: .house), 2)
        for kind in [BuildingKind.police, .market, .workshop, .farm] {
            XCTAssertEqual(config.constructionDays(for: kind), 3, "\(kind)")
        }
        for kind in [BuildingKind.clinic, .school, .dock] {
            XCTAssertEqual(config.constructionDays(for: kind), 4, "\(kind)")
        }
    }

    func testFoundationSplitAlwaysLeavesAScaffoldDay() {
        let config = BalanceConfig()
        XCTAssertEqual(config.foundationDays(forRequired: 0), 0)
        XCTAssertEqual(config.foundationDays(forRequired: 1), 1, "a one-day build is all foundation")
        XCTAssertEqual(config.foundationDays(forRequired: 2), 1)
        XCTAssertEqual(config.foundationDays(forRequired: 3), 1)
        XCTAssertEqual(config.foundationDays(forRequired: 4), 2)
        XCTAssertEqual(config.foundationDays(forRequired: 9), 3)
    }

    func testMultiplierScalesEveryBuildAndOnlyZeroIsInstant() {
        var config = BalanceConfig()
        config.constructionDaysMultiplierPercent = 200
        XCTAssertEqual(config.constructionDays(for: .house), 4)
        config.constructionDaysMultiplierPercent = 50
        XCTAssertEqual(config.constructionDays(for: .house), 1)
        config.constructionDaysMultiplierPercent = 10
        XCTAssertEqual(config.constructionDays(for: .house), 1, "rounding never silently skips the site")
        config.constructionDaysMultiplierPercent = 0
        XCTAssertEqual(config.constructionDays(for: .house), 0)
        XCTAssertEqual(config.constructionDays(for: .dock), 0)
    }

    // MARK: - The stage walk (7.12 item 1)

    func testClinicPlacedOnDayTenWalksFoundationScaffoldComplete() throws {
        var s = makeFlatWorld()
        s.day = 10
        let id = try placeOrFail(.clinic, at: s.map.index(x: 2, y: 6), in: &s)

        XCTAssertEqual(s.buildings[Int(id.raw)].daysRequired, 4)
        XCTAssertEqual(s.buildings[Int(id.raw)].builtOnDay, 10)
        XCTAssertEqual(s.buildings[Int(id.raw)].opensOnDay, 14)

        let expected: [(stage: ConstructionStage, progress: Double)] = [
            (.foundation, 0.0), (.foundation, 0.25), (.scaffold, 0.5), (.scaffold, 0.75), (.complete, 1.0),
        ]
        for (done, want) in expected.enumerated() {
            let b = s.buildings[Int(id.raw)]
            XCTAssertEqual(b.daysConstructed, Int32(done))
            XCTAssertEqual(b.stage(in: s.config), want.stage, "after \(done) days of work")
            XCTAssertEqual(b.constructionProgress, want.progress, accuracy: 0.0001)
            XCTAssertEqual(b.isUnderConstruction, want.stage != .complete)
            if done < expected.count - 1 { tickPrologue(&s) }
        }

        // Finished buildings stay put: more ticks must not count past the requirement.
        for _ in 0..<3 { tickPrologue(&s) }
        XCTAssertEqual(s.buildings[Int(id.raw)].daysConstructed, 4)
        XCTAssertEqual(s.buildings[Int(id.raw)].stage(in: s.config), .complete)
    }

    func testStageProgressCountsWithinTheCurrentStage() throws {
        var s = makeFlatWorld()
        let id = try placeOrFail(.market, at: s.map.index(x: 2, y: 6), in: &s)   // 3 days: 1 + 2
        let steps: [(done: Int32, of: Int32)] = [(0, 1), (0, 2), (1, 2)]
        for want in steps {
            let progress = s.buildings[Int(id.raw)].stageProgress(in: s.config)
            XCTAssertEqual(progress.done, want.done)
            XCTAssertEqual(progress.of, want.of)
            tickPrologue(&s)
        }
        XCTAssertFalse(s.buildings[Int(id.raw)].isUnderConstruction)
    }

    // MARK: - A site reaches nobody until it opens (7.12 item 2)

    func testHouseNextDoorIsUnservedUntilTheMarketOpensAndServedThatSameDay() throws {
        var s = makeFlatWorld()
        let houseID = try placeOrFail(.house, at: s.map.index(x: 1, y: 6), in: &s)
        let marketID = try placeOrFail(.market, at: s.map.index(x: 4, y: 6), in: &s)
        let houseTile = s.buildings[Int(houseID.raw)].entrance
        let marketTile = s.buildings[Int(marketID.raw)].entrance

        // Day 1 and 2: the market is a site, so it is not a source of anything.
        for day in 1...2 {
            tickPrologue(&s)
            XCTAssertTrue(s.buildings[Int(marketID.raw)].isUnderConstruction)
            XCTAssertNil(s.fields.nearestMarket(at: houseTile), "day \(day): a site is not a market yet")
            XCTAssertFalse(s.fields.isWithin(.market, of: houseTile, max: s.config.maxServiceDistance),
                           "day \(day): nobody is in range of a building site")
            XCTAssertNil(s.fields.nearestMarket(at: marketTile),
                         "day \(day): not even its own doorstep")
        }

        // Day 3 finishes it, and the fields are rebuilt in the same prologue -- that is
        // the whole reason advanceConstruction runs before the dirty check.
        tickPrologue(&s)
        XCTAssertFalse(s.buildings[Int(marketID.raw)].isUnderConstruction)
        XCTAssertEqual(s.fields.nearestMarket(at: houseTile), marketID)
        XCTAssertTrue(s.fields.isWithin(.market, of: houseTile, max: s.config.maxServiceDistance))
    }

    // MARK: - A site costs nothing to run (7.12 item 3)

    func testSiteIsChargedNoUpkeepUntilItOpens() throws {
        var s = makeFlatWorld()
        let before = s.treasury
        SimulationEngine.payUpkeep(&s)
        XCTAssertEqual(s.treasury, before, "empty world: nothing to pay for")

        let id = try placeOrFail(.police, at: s.map.index(x: 2, y: 6), in: &s)
        let afterPlacement = s.treasury
        SimulationEngine.payUpkeep(&s)
        XCTAssertEqual(s.treasury, afterPlacement, "a site pays no upkeep")

        while s.buildings[Int(id.raw)].isUnderConstruction { tickPrologue(&s) }
        let afterOpening = s.treasury
        SimulationEngine.payUpkeep(&s)
        XCTAssertEqual(s.treasury, afterOpening - s.config.upkeepCivic,
                       "once open it is charged like any other civic building")
    }

    func testSiteTakesNoStaffNoProductionAndNoWages() throws {
        var s = WorldGenerator.generate(seed: 2026, citizenCount: 120)
        for _ in 0..<15 { autoResolve(&s); SimulationEngine.advance(&s) }
        autoResolve(&s)
        let id = try placeAnywhere(.farm, in: &s)

        while s.buildings[Int(id.raw)].isUnderConstruction {
            autoResolve(&s)
            SimulationEngine.advance(&s)
            let site = s.buildings[Int(id.raw)]
            guard site.isUnderConstruction else { break }
            XCTAssertTrue(site.workers.isEmpty, "assignWork must not staff a site")
            XCTAssertEqual(site.foodStore, 0, "a site grows nothing")
            XCTAssertEqual(site.funds, 0, "no wages in, no taxes out")
        }
        XCTAssertFalse(s.buildings[Int(id.raw)].isUnderConstruction)
    }

    func testNobodyIsHiredIntoASiteAndHiringStartsTheDayItOpens() throws {
        var s = makeFlatWorld()
        s.config.constructionDaysMultiplierPercent = 0        // an already-standing house
        let houseID = try placeOrFail(.house, at: s.map.index(x: 1, y: 6), in: &s)
        s.config.constructionDaysMultiplierPercent = 100      // and a brand-new farm site
        let farmID = try placeOrFail(.farm, at: s.map.index(x: 5, y: 6), in: &s)

        s.citizens = [Citizen(id: CitizenID(0), name: "Ada", age: 30, district: DistrictID(0),
                              money: 10, happiness: 50, loyalty: 50, ambition: 50, influence: 10)]
        s.citizens[0].home = houseID
        s.buildings[Int(houseID.raw)].residents = [CitizenID(0)]

        while s.buildings[Int(farmID.raw)].isUnderConstruction {
            tickPrologue(&s)
            SimulationEngine.assignWork(&s)
            guard s.buildings[Int(farmID.raw)].isUnderConstruction else { break }
            XCTAssertNil(s.citizens[0].work, "there is no job at a building site")
            XCTAssertTrue(s.buildings[Int(farmID.raw)].workers.isEmpty)
        }

        XCTAssertEqual(s.citizens[0].work, farmID, "the farm hires on the day it opens")
        XCTAssertEqual(s.buildings[Int(farmID.raw)].workers, [CitizenID(0)])
        XCTAssertEqual(s.citizens[0].occupation, .farmer)
    }

    // MARK: - Conservation across the whole window and a cancel (7.12 item 4)

    func testMoneyAndFoodReconcileAcrossPlacementConstructionCompletionAndCancel() throws {
        var s = WorldGenerator.generate(seed: 11, citizenCount: 100)
        for _ in 0..<20 { autoResolve(&s); SimulationEngine.advance(&s) }
        autoResolve(&s)

        let kept = try placeAnywhere(.market, in: &s)
        let cancelled = try placeAnywhere(.clinic, in: &s)
        try s.checkConservation()

        // Two days in, cancel one of them mid-build and keep ticking through the other's
        // completion. Demolition pays no refund, so the books must still balance.
        for _ in 0..<2 { autoResolve(&s); SimulationEngine.advance(&s); try s.checkConservation() }
        XCTAssertTrue(s.buildings[Int(cancelled.raw)].isUnderConstruction)
        XCTAssertEqual(SimulationEngine.apply(.demolish(cancelled), to: &s), .accepted)
        try s.checkConservation()

        for day in 0..<20 {
            autoResolve(&s)
            SimulationEngine.advance(&s)
            do { try s.checkConservation() } catch {
                XCTFail("conservation broke \(day) days after the cancel: \(error)")
                return
            }
        }
        XCTAssertFalse(s.buildings[Int(kept.raw)].isUnderConstruction, "the kept site opened")
    }

    func testCancelledSiteStopsBuildingAndNeverAnnouncesThatItOpened() throws {
        var s = makeFlatWorld()
        let id = try placeOrFail(.dock, at: s.map.index(x: 11, y: 6), in: &s)
        tickPrologue(&s)
        XCTAssertEqual(s.buildings[Int(id.raw)].daysConstructed, 1)

        XCTAssertEqual(SimulationEngine.apply(.demolish(id), to: &s), .accepted)
        let frozen = s.buildings[Int(id.raw)].daysConstructed
        for _ in 0..<10 { tickPrologue(&s) }

        XCTAssertEqual(s.buildings[Int(id.raw)].daysConstructed, frozen,
                       "a cancelled site must not keep building on cleared ground")
        XCTAssertFalse(s.events.contains { $0.kind == .buildingConstructed && $0.location.building == id },
                       "a cancelled site must never report that it opened")
    }

    // MARK: - Events (7.9)

    func testGroundBreakingAndOpeningAreSeparateEvents() throws {
        var s = makeFlatWorld()
        let id = try placeOrFail(.house, at: s.map.index(x: 2, y: 6), in: &s)

        let atPlacement = s.events.filter { $0.location.building == id }
        XCTAssertEqual(atPlacement.map(\.kind), [.buildingSiteStarted])
        XCTAssertEqual(atPlacement.first?.magnitude, Int32(BuildingKind.house.buildCost))

        tickPrologue(&s)
        XCTAssertFalse(s.events.contains { $0.kind == .buildingConstructed },
                       "mid-build is not an opening")
        tickPrologue(&s)
        XCTAssertEqual(s.events.filter { $0.location.building == id }.map(\.kind),
                       [.buildingSiteStarted, .buildingConstructed])
        XCTAssertEqual(s.events.last?.day, s.day, "the opening is dated the day the work finished")
    }

    // MARK: - The off switch reproduces today's behaviour (7.12 item 6)

    func testMultiplierZeroOpensEverythingAtPlacementLikeBefore() throws {
        var s = makeFlatWorld()
        s.config.constructionDaysMultiplierPercent = 0
        let id = try placeOrFail(.clinic, at: s.map.index(x: 2, y: 6), in: &s)
        let b = s.buildings[Int(id.raw)]

        XCTAssertEqual(b.daysRequired, 0)
        XCTAssertFalse(b.isUnderConstruction)
        XCTAssertEqual(b.stage(in: s.config), .complete)
        XCTAssertEqual(b.opensOnDay, b.builtOnDay)
        XCTAssertEqual(s.events.filter { $0.location.building == id }.map(\.kind), [.buildingConstructed],
                       "with construction off, placement is still the opening")

        tickPrologue(&s)
        XCTAssertEqual(s.events.filter { $0.kind == .buildingConstructed }.count, 1,
                       "and it is not announced twice")
    }

    // MARK: - Worldgen hands over a working city (7.12 item 7)

    func testWorldgenBuildingsAreCompleteOnDayZero() {
        let s = WorldGenerator.generate(seed: 2026, citizenCount: 200)
        XCTAssertEqual(s.day, 0)
        for b in s.buildings {
            XCTAssertEqual(b.daysRequired, 0, "worldgen \(b.kind) must not come out as a site")
            XCTAssertTrue(b.isOperational)
            XCTAssertEqual(b.stage(in: s.config), .complete)
        }
        XCTAssertFalse(s.citizens.filter { $0.home != nil }.isEmpty, "a fresh city has housed citizens")
        let markets = s.buildings.filter { $0.kind == .market }
        XCTAssertFalse(markets.isEmpty)
        XCTAssertTrue(markets.contains { $0.foodStore > 0 }, "and a market with food in it")
        // Worldgen leaves the caches dirty by design, so build them the way the tick
        // prologue would and check the market is a source with no day elapsed.
        var built = s
        SimulationEngine.rebuildSpatialCaches(&built)
        XCTAssertEqual(built.day, 0)
        XCTAssertTrue(markets.contains { built.fields.nearestMarket(at: $0.entrance) == $0.id },
                      "a worldgen market is a source on day 0, with no construction to wait for")
    }

    // MARK: - Save shape (7.10)

    func testConstructionStateIsTwoIntegersAndNoFloats() throws {
        var s = makeFlatWorld()
        _ = try placeOrFail(.clinic, at: s.map.index(x: 2, y: 6), in: &s)
        tickPrologue(&s)

        let data = try JSONEncoder().encode(s)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let buildings = try XCTUnwrap(json["buildings"] as? [[String: Any]])
        let site = try XCTUnwrap(buildings.last)
        XCTAssertEqual(site["daysConstructed"] as? Int, 1)
        XCTAssertEqual(site["daysRequired"] as? Int, 4)
        XCTAssertNil(site["constructionProgress"], "progress is derived, never stored")
        XCTAssertNil(site["stage"], "the stage is derived, never stored")
    }

    func testASchemaTwoSaveDoesNotDecode() throws {
        var s = makeFlatWorld()
        _ = try placeOrFail(.house, at: s.map.index(x: 2, y: 6), in: &s)
        let data = try JSONEncoder().encode(s)
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        // Exactly what a file written before this change looks like.
        json["schemaVersion"] = 2
        let old = try XCTUnwrap(json["buildings"] as? [[String: Any]]).map { building -> [String: Any] in
            var copy = building
            copy.removeValue(forKey: "daysConstructed")
            copy.removeValue(forKey: "daysRequired")
            return copy
        }
        json["buildings"] = old

        let downgraded = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try JSONDecoder().decode(RepublicState.self, from: downgraded),
                             "a schema 2 save must not decode into schema 3")
    }

    // MARK: - Inspect (7.8)

    func testInspectReportsTheStageAndHidesNumbersThatDoNotApplyYet() throws {
        var s = makeFlatWorld()
        let id = try placeOrFail(.market, at: s.map.index(x: 2, y: 6), in: &s)
        tickPrologue(&s)

        let site = try XCTUnwrap(BuildingInspector.make(id: id, in: s))
        let status = try XCTUnwrap(site.sections.first?.rows.first)
        XCTAssertEqual(status.value, "Under construction · Scaffold, 0 of 2 days")
        XCTAssertEqual(status.tone, .calm, "a site is not a problem to be fixed")
        XCTAssertNil(site.sections.first { $0.id == "people" }, "nobody works at a site yet")

        let numbers = try XCTUnwrap(site.sections.first { $0.id == "numbers" })
        let titles = numbers.rows.map(\.title)
        XCTAssertEqual(titles, ["Opens", "Progress", "Placed"])
        XCTAssertEqual(numbers.rows.first?.value, "Day 3")
        XCTAssertEqual(numbers.rows[1].value, "33%")

        while s.buildings[Int(id.raw)].isUnderConstruction { tickPrologue(&s) }
        let open = try XCTUnwrap(BuildingInspector.make(id: id, in: s))
        XCTAssertNotNil(open.sections.first { $0.id == "people" }, "an open market has staff rows")
        let openTitles = try XCTUnwrap(open.sections.first { $0.id == "numbers" }).rows.map(\.title)
        XCTAssertEqual(openTitles, ["Food stored", "Funds", "Upkeep", "Residents in range", "Built"])
    }

    // MARK: - Fixtures

    /// A buildable island with one road row at y = 5, fertile soil so farms are legal,
    /// a water column at x = 13 so the dock is legal, and money in the bank. Small and
    /// quiet on purpose: no citizens, no factions, so a tick does exactly one thing.
    private func makeFlatWorld() -> RepublicState {
        var s = RepublicState(worldSeed: 7, config: BalanceConfig(), map: WorldMap(width: 14, height: 14))
        s.districts = [District(id: DistrictID(0), name: "Old Town")]
        for raw in 0..<Int32(s.map.tileCount) {
            s.map.terrain[Int(raw)] = TerrainKind.fertile.rawValue
        }
        for y in Int32(0)..<14 { s.map.terrain[Int(s.map.index(x: 13, y: y).raw)] = TerrainKind.water.rawValue }
        for x in Int32(0)..<13 { s.map.road[Int(s.map.index(x: x, y: 5).raw)] = true }
        s.transfer(from: .external, to: .treasury, 10_000)
        s.fields.rebuild(map: s.map, buildings: s.buildings)
        return s
    }

    /// The first three statements of `SimulationEngine.advance`, and only those, so the
    /// ordering claim in 7.10 is what is under test rather than a whole day of economy.
    private func tickPrologue(_ s: inout RepublicState) {
        s.day += 1
        SimulationEngine.advanceConstruction(&s)
        if s.fields.dirty { SimulationEngine.rebuildSpatialCaches(&s) }
    }

    private func placeOrFail(_ kind: BuildingKind, at tile: TileIndex,
                             in s: inout RepublicState) throws -> BuildingID {
        let outcome = SimulationEngine.apply(.placeBuilding(kind, at: tile), to: &s)
        XCTAssertEqual(outcome, .accepted, "could not place \(kind)")
        guard outcome == .accepted else { throw XCTSkip("placement rejected") }
        return try XCTUnwrap(s.buildings.last?.id)
    }

    /// Place on the first legal anchor in a generated world.
    private func placeAnywhere(_ kind: BuildingKind, in s: inout RepublicState) throws -> BuildingID {
        for raw in 0..<Int32(s.map.tileCount) {
            if case .accepted = SimulationEngine.apply(.placeBuilding(kind, at: TileIndex(raw)), to: &s) {
                return try XCTUnwrap(s.buildings.last?.id)
            }
        }
        throw XCTSkip("no legal site for \(kind) in this world")
    }
}
