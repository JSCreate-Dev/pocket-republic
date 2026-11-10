import XCTest
@testable import PocketRepublicCore

final class TownFlowTests: XCTestCase {
    func testUrgentFoodTripPrecedesWorkAndCannotOverlap() throws {
        var state = WorldGenerator.generate(seed: 3, citizenCount: 80)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        var citizen = try XCTUnwrap(state.citizens.first { c in
            guard let home = c.home, let work = c.work,
                  let market = SimulationEngine.shoppingMarket(state, homeTile: state.buildings[Int(home.raw)].tile) else { return false }
            return work != market
        })
        citizen.daysHungry = 2
        let before = state.stateHash()
        let route = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        XCTAssertEqual(route.stops, [.home, .market, .work, .home])
        for i in route.stops.indices {
            XCTAssertLessThan(route.dwellStart[i], route.dwellEnd[i])
            if i > 0 { XCTAssertLessThan(route.dwellEnd[i-1], route.dwellStart[i]) }
        }
        XCTAssertEqual(route.entrances.first, route.entrances.last)
        XCTAssertEqual(before, state.stateHash())
        XCTAssertEqual(route, WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess()))
    }

    func testDemandVisitBelongsToTheCitizensFactionAndExpires() throws {
        var state = WorldGenerator.generate(seed: 3, citizenCount: 80)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        var citizen = try XCTUnwrap(state.citizens.first { c in
            let phase = (UInt64(c.id.raw) + state.worldSeed) % 5
            return c.home != nil && c.occupation == .farmer && phase < 3
        })
        citizen.daysHungry = 0; citizen.age = 30; citizen.loyalty = 80
        state.config.maxServiceDistance = 1000
        let demand = AgendaItem(id: DecisionID(900), kind: .factionDemand, tier: .demand,
            raisedOnDay: 0, expiresOnDay: 1, faction: .labourers, location: EventLocation(), causes: [], options: [])
        state.agenda = [demand]
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        XCTAssertTrue(routine.stops.contains(.civic))
        state.day = 2
        XCTAssertFalse(WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess()).stops.contains(.civic))
    }

    func testFestivalOnlyExtendsMarketDwellAfterItWasFunded() throws {
        var state = WorldGenerator.generate(seed: 3, citizenCount: 80)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        var citizen = try XCTUnwrap(state.citizens.first { c in
            guard (UInt64(c.id.raw) + state.worldSeed) % 5 == 3, let home = c.home,
                  let work = c.work, let market = SimulationEngine.shoppingMarket(state, homeTile: state.buildings[Int(home.raw)].tile)
            else { return false }
            return work != market
        })
        citizen.age = 30; citizen.loyalty = 80; citizen.daysHungry = 0
        let normal = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        let market = try XCTUnwrap(normal.stops.firstIndex(of: .market))
        state.decreeLastIssued = ["Proclaim a market festival": state.day]
        let festive = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        XCTAssertGreaterThan(festive.dwellEnd[market], normal.dwellEnd[market])
        XCTAssertEqual(festive.entrances, normal.entrances, "no second trip to the same market door")
        state.day = 2
        var ordinary = state; ordinary.decreeLastIssued = nil
        XCTAssertEqual(WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess()),
                       WalkerRoutine.plan(for: citizen, in: ordinary, access: ordinary.buildingAccess()))
    }

    func testTutorialInspectsPendingWorkInsteadOfOrderingDuplicate() throws {
        var state = WorldGenerator.generate(seed: 7)
        var site: BuildingID?
        for raw in 0..<Int32(state.map.tileCount) {
            if case .accepted = SimulationEngine.apply(.placeBuilding(.workshop, at: TileIndex(raw)), to: &state) {
                site = state.buildings.last?.id
                break
            }
        }
        let id = try XCTUnwrap(site)
        let before = state.stateHash()
        let lesson = SettlementGuide.lessons(in: state)[0]
        XCTAssertFalse(lesson.complete)
        XCTAssertEqual(lesson.action, .inspect(id))
        XCTAssertEqual(before, state.stateHash())
    }

    func testWalkerClockIgnoresEconomicDaysAndBackgroundGaps() {
        var clock = WalkerPresentationClock()
        XCTAssertFalse(clock.advance(frame: 100, reducedMotion: false))
        XCTAssertFalse(clock.advance(frame: 10_000, reducedMotion: false))
        XCTAssertEqual(clock.elapsed, 10.1, accuracy: 0.00001)
        _ = clock.advance(frame: 10_001, reducedMotion: true)
        XCTAssertEqual(clock.elapsed, 10.1, accuracy: 0.00001)
        var midnights = 0
        for step in 1...600 {
            if clock.advance(frame: 10_001 + Double(step) / 10, reducedMotion: false) { midnights += 1 }
        }
        XCTAssertEqual(midnights, 1)
        clock.reset()
        XCTAssertEqual(clock.elapsed, 10)
    }

    func testFieldGuideCountsStandingCapacityNotOrdersAndIsReadOnly() {
        let state = WorldGenerator.generate(seed: 7)
        let before = state.stateHash()
        let guide = SettlementGuide.lessons(in: state)
        XCTAssertEqual(guide.count, 4)
        XCTAssertFalse(guide[0].complete)
        XCTAssertFalse(guide[1].complete)
        XCTAssertFalse(guide[3].complete)
        XCTAssertTrue(guide.allSatisfy { !$0.instruction.isEmpty && !$0.evidence.isEmpty })
        XCTAssertEqual(before, state.stateHash())
    }

    func testFactionReportUsesLiveMembershipButPreservesRecordedPolitics() {
        var state = WorldGenerator.generate(seed: 7)
        for i in state.citizens.indices { state.citizens[i].occupation = .farmer }
        state.citizens[0].alive = false
        let index = Int(FactionKind.labourers.rawValue)
        state.factions[index].adjust(-8, on: state.day, reason: .policyChange, detail: "test")
        state.factions[index].dominantConcern = .foodShortage
        state.factions[index].concernWeight = 75
        let hash = state.stateHash()
        let report = FactionReport(kind: .labourers, state: state)
        XCTAssertEqual(report.members, 15)
        XCTAssertEqual(report.favor, -8)
        XCTAssertEqual(report.concern, .foodShortage)
        XCTAssertEqual(report.memory.first?.delta, -8)
        XCTAssertEqual(FactionReport(kind: .merchants, state: state).members, 0)
        XCTAssertEqual(hash, state.stateHash())
    }
}
