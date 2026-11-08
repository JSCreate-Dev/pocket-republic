import XCTest
@testable import PocketRepublicCore

/// The island deck is a small set of agenda cards on the existing effect path.
/// Rolls use a stream derived from the world seed, not the wellbeing RNG.
final class IslandEventTests: XCTestCase {

    func testDeckIsSmallBoundedAndHasAnIgnoreOption() {
        XCTAssertEqual(EventDeck.all.count, 6)
        XCTAssertEqual(Set(EventDeck.all.map(\.id)).count, EventDeck.all.count)
        let tones = Set(EventDeck.all.map(\.tone))
        XCTAssertTrue(tones.contains(.good))
        XCTAssertTrue(tones.contains(.bad))
        XCTAssertTrue(tones.contains(.weird))
        for spec in EventDeck.all {
            XCTAssertEqual(spec.options.map(\.id), Array(0..<Int32(spec.options.count)))
            let ignore = spec.options.first { $0.id == spec.ifIgnored }
            XCTAssertNotNil(ignore, spec.title)
            XCTAssertEqual(ignore?.effect.treasuryCost, 0, "\(spec.title) ignore must not spend")
            XCTAssertEqual(ignore?.effect.treasuryGain, 0, "\(spec.title) ignore must not pay")
            XCTAssertNil(ignore?.effect.foodExport, "\(spec.title) ignore must not export food")
            XCTAssertFalse(spec.flavor.isEmpty)
            XCTAssertFalse(spec.headline.isEmpty)
            XCTAssertFalse(spec.why.isEmpty)
            for option in spec.options {
                XCTAssertLessThanOrEqual(option.effect.treasuryCost, 250)
                XCTAssertLessThanOrEqual(option.effect.treasuryGain, 300)
                XCTAssertLessThanOrEqual(abs(option.effect.legitimacy), 6)
                XCTAssertLessThanOrEqual(abs(option.effect.corruption), 8)
                XCTAssertLessThanOrEqual(abs(option.effect.districtUnrest), 8)
                XCTAssertLessThanOrEqual(option.effect.foodImport, 120)
                XCTAssertLessThanOrEqual(option.effect.foodExport ?? 0, 80)
                XCTAssertEqual(option.effect.incomeTaxDelta, 0)
                XCTAssertEqual(option.effect.civicWageDelta, 0)
                XCTAssertTrue(option.effect.favorDeltas.allSatisfy { abs($0) <= 6 })
                XCTAssertFalse(option.label.isEmpty)
                XCTAssertFalse(option.outcome.isEmpty)
            }
        }
    }

    func testChoicesAreValidatedAndTradeoffsAreBounded() throws {
        var s = makeFlatWorld()
        let market = try place(.market, at: s.map.index(x: 2, y: 6), in: &s)
        s.produceFood(at: market, 100)
        let trade = try XCTUnwrap(EventDeck.spec(5))
        IslandEvents.post(trade, to: &s, pacing: .standard)
        let card = try XCTUnwrap(s.agenda.last { $0.islandEventID == trade.id })
        XCTAssertEqual(card.kind, .advisoryTradeoff)
        XCTAssertEqual(card.tier, .advisory)
        XCTAssertFalse(s.blocksAdvance)
        XCTAssertEqual(card.causes.first?.detail, trade.flavor)
        let headline = try XCTUnwrap(card.causes.dropFirst().first?.detail)
        XCTAssertEqual(headline, "A foreign freighter offers coin for the harvest")
        var named = makeFlatWorld()
        IslandEvents.post(try XCTUnwrap(EventDeck.spec(0)), to: &named, pacing: .standard)
        XCTAssertEqual(named.agenda.last?.causes.dropFirst().first?.detail,
                       "Carnival fills the streets of Old Town")
        XCTAssertTrue(s.events.contains {
            $0.kind == .islandEvent && $0.causes.first?.detail == headline
        })

        let treasury = s.treasury
        XCTAssertEqual(SimulationEngine.apply(.resolveAgendaItem(card.id, option: 9), to: &s),
                       .rejected(.invalidOption))
        XCTAssertEqual(s.treasury, treasury)
        XCTAssertNotNil(s.agenda.first { $0.id == card.id })

        XCTAssertEqual(SimulationEngine.apply(.resolveAgendaItem(card.id, option: 0), to: &s), .accepted)
        XCTAssertEqual(s.buildings[Int(market.raw)].foodStore, 20)
        XCTAssertEqual(s.ledger.foodExported, 80)
        XCTAssertEqual(s.treasury, treasury + 300)
        XCTAssertEqual(s.factions[Int(FactionKind.merchants.rawValue)].favor, 5)
        XCTAssertTrue(s.events.contains {
            $0.kind == .islandEvent && ($0.causes.first?.detail.contains("Eighty crates") ?? false)
        })
        try s.checkConservation()

        var thin = makeFlatWorld()
        let stall = try place(.market, at: thin.map.index(x: 2, y: 6), in: &thin)
        thin.produceFood(at: stall, 40)
        IslandEvents.post(trade, to: &thin, pacing: .standard)
        let short = try XCTUnwrap(thin.agenda.last { $0.islandEventID == trade.id })
        let thinTreasury = thin.treasury
        XCTAssertEqual(SimulationEngine.apply(.resolveAgendaItem(short.id, option: 0), to: &thin), .accepted)
        XCTAssertEqual(thin.buildings[Int(stall.raw)].foodStore, 0)
        XCTAssertEqual(thin.ledger.foodExported, 40)
        XCTAssertEqual(thin.treasury, thinTreasury + 150, "coin scales with the crates that actually shipped")
        try thin.checkConservation()

        var broke = makeFlatWorld()
        broke.transfer(from: .treasury, to: .external, broke.treasury - 100)
        let gala = try XCTUnwrap(EventDeck.spec(1))
        IslandEvents.post(gala, to: &broke, pacing: .standard)
        let invite = try XCTUnwrap(broke.agenda.last { $0.islandEventID == gala.id })
        XCTAssertEqual(SimulationEngine.apply(.resolveAgendaItem(invite.id, option: 0), to: &broke),
                       .rejected(.insufficientTreasury))
        XCTAssertEqual(broke.treasury, 100)
        XCTAssertEqual(broke.legitimacy, 65)
        XCTAssertNotNil(broke.agenda.first { $0.id == invite.id })
        try broke.checkConservation()
    }

    func testIgnoringACardAppliesOnlyTheFreeOption() throws {
        var s = makeFlatWorld()
        let ring = try XCTUnwrap(EventDeck.spec(2))
        IslandEvents.post(ring, to: &s, pacing: .standard)
        let card = try XCTUnwrap(s.agenda.last)
        let treasury = s.treasury
        let corruption = s.corruption
        IslandEvents.lapse(&s, card)
        XCTAssertEqual(s.treasury, treasury, "lapse must not raid or take the cut")
        XCTAssertEqual(s.corruption, corruption + 2)
        XCTAssertTrue(s.events.contains {
            $0.kind == .islandEvent && ($0.causes.first?.detail.contains("boats were gone") ?? false)
        })
        let day = s.day
        SimulationEngine.advance(&s)
        XCTAssertEqual(s.day, day + 1, "an island event is advisory and must not stop the clock")
        try s.checkConservation()
    }

    func testASecondCardWaitsAndARecentCardStaysOut() throws {
        var s = makeFlatWorld()
        var pacing = EventPacing.standard
        pacing.chancePercent = 100
        pacing.quietDays = 0
        pacing.postCrisisQuietDays = 0
        pacing.repeatDays = 30
        pacing.recentExclusion = 0
        s.config.eventPacing = pacing
        s.day = 20
        let expat = try XCTUnwrap(EventDeck.spec(4))
        IslandEvents.post(expat, to: &s, pacing: pacing)
        IslandEvents.update(&s)
        XCTAssertEqual(s.agenda.filter { $0.islandEventID != nil }.count, 1,
                       "a card already on the table blocks a second draw")

        var quiet = makeFlatWorld()
        quiet.config.eventPacing = pacing
        quiet.day = 12
        var log = IslandEventLog.fresh(worldSeed: quiet.worldSeed, count: EventDeck.all.count)
        log.lastFiredDay = Array(repeating: quiet.day, count: EventDeck.all.count)
        quiet.islandEventLog = log
        IslandEvents.update(&quiet)
        XCTAssertTrue(quiet.agenda.allSatisfy { $0.islandEventID == nil },
                      "the repeat window keeps every recently raised card out of the draw")
    }

    func testSameSeedReplaysAcrossSaveAndLoad() throws {
        var live = WorldGenerator.generate(seed: 42, citizenCount: 60)
        var twin = live
        for _ in 0..<20 {
            autoResolve(&live)
            autoResolve(&twin)
            SimulationEngine.advance(&live)
            SimulationEngine.advance(&twin)
        }
        XCTAssertEqual(live.stateHash(), twin.stateHash())
        XCTAssertNotNil(live.islandEventLog)

        let data = try JSONEncoder().encode(live)
        var restored = try JSONDecoder().decode(RepublicState.self, from: data)
        restored.fields.markDirty()
        SimulationEngine.rebuildSpatialCaches(&restored)
        live.fields.markDirty()
        SimulationEngine.rebuildSpatialCaches(&live)
        for _ in 0..<20 {
            autoResolve(&live)
            autoResolve(&restored)
            SimulationEngine.advance(&live)
            SimulationEngine.advance(&restored)
        }
        XCTAssertEqual(live.stateHash(), restored.stateHash())
        XCTAssertEqual(live.islandEventLog?.recentIDs, restored.islandEventLog?.recentIDs)
        XCTAssertEqual(live.islandEventLog?.rng, restored.islandEventLog?.rng)
        try live.checkConservation()
    }

    func testDifferentSeedsDivergeAndTheMainRngIsLeftAlone() throws {
        var first = WorldGenerator.generate(seed: 1, citizenCount: 40)
        var second = WorldGenerator.generate(seed: 2, citizenCount: 40)
        SimulationEngine.advance(&first)
        SimulationEngine.advance(&second)
        XCTAssertNotEqual(first.islandEventLog?.rng, second.islandEventLog?.rng)

        var paced = WorldGenerator.generate(seed: 3, citizenCount: 40)
        var silent = paced
        var off = EventPacing.standard
        off.chancePercent = 0
        silent.config.eventPacing = off
        for _ in 0..<20 {
            autoResolve(&paced)
            autoResolve(&silent)
            SimulationEngine.advance(&paced)
            SimulationEngine.advance(&silent)
        }
        XCTAssertEqual(paced.rng, silent.rng,
                       "event rolls must use their own stream, not the wellbeing RNG")
        XCTAssertNotNil(paced.islandEventLog)
    }

    func testALongRunActuallyRaisesACard() throws {
        var s = WorldGenerator.generate(seed: 2026, citizenCount: 80)
        for _ in 0..<80 { autoResolve(&s); SimulationEngine.advance(&s) }
        let stories = s.events.filter { $0.kind == .islandEvent }
        XCTAssertFalse(stories.isEmpty, "seed 2026 should see the deck inside 80 days")
        XCTAssertTrue(stories.allSatisfy { $0.causes.contains { !$0.detail.isEmpty } })
        try s.checkConservation()
    }

    func testFreshSaveOmitsTheNewKeysAndStillRoundTrips() throws {
        let fresh = WorldGenerator.generate(seed: 4, citizenCount: 20)
        let data = try JSONEncoder().encode(fresh)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(text.contains("\"islandEventLog\""))
        XCTAssertFalse(text.contains("\"eventPacing\""))
        XCTAssertFalse(text.contains("\"foodExport\""))
        XCTAssertFalse(text.contains("\"islandEventID\""))
        XCTAssertEqual(fresh.schemaVersion, 3)
        let loaded = try JSONDecoder().decode(RepublicState.self, from: data)
        XCTAssertNil(loaded.islandEventLog)
        XCTAssertNil(loaded.config.eventPacing)
        XCTAssertEqual(loaded.stateHash(), fresh.stateHash())

        var played = fresh
        SimulationEngine.advance(&played)
        let playedData = try JSONEncoder().encode(played)
        let playedText = try XCTUnwrap(String(data: playedData, encoding: .utf8))
        XCTAssertTrue(playedText.contains("\"islandEventLog\""),
                      "the first advanced day persists the event stream")
        let restored = try JSONDecoder().decode(RepublicState.self, from: playedData)
        XCTAssertEqual(restored.islandEventLog?.rng, played.islandEventLog?.rng)
        XCTAssertEqual(restored.stateHash(), played.stateHash())
    }

    private func makeFlatWorld() -> RepublicState {
        var s = RepublicState(worldSeed: 7, config: BalanceConfig(), map: WorldMap(width: 16, height: 12))
        s.config.constructionDaysMultiplierPercent = 0
        s.districts = [District(id: DistrictID(0), name: "Old Town")]
        for raw in 0..<Int32(s.map.tileCount) {
            s.map.terrain[Int(raw)] = TerrainKind.grass.rawValue
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
}
