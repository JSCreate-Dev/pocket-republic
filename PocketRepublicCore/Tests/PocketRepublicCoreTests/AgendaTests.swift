import XCTest
@testable import PocketRepublicCore

/// The design target: something actionable on screen every single day-advance,
/// without manufacturing crises to fill the gaps.
final class AgendaTests: XCTestCase {

    /// Clears anything blocking the clock. Elections and crises block; the rest
    /// deliberately does not.
    private func unblock(_ s: inout RepublicState) {
        if let p = s.pending {
            _ = SimulationEngine.apply(.resolveDecision(p.id, option: 0), to: &s)
        }
        while let e = s.agenda.first(where: { $0.tier == .crisis }) {
            _ = SimulationEngine.apply(.resolveAgendaItem(e.id, option: 0), to: &s)
        }
    }

    func testSomethingActionableEveryTickAt500Citizens() {
        var s = WorldGenerator.generate(seed: 77, citizenCount: 500)
        var emptyDays: [Int32] = []
        for _ in 0..<500 {
            unblock(&s)
            SimulationEngine.advance(&s)
            if s.agenda.isEmpty && s.pending == nil { emptyDays.append(s.day) }
        }
        XCTAssertTrue(emptyDays.isEmpty,
                      "player had nothing to do on \(emptyDays.count) days: \(emptyDays.prefix(12))")
    }

    func testSomethingActionableEveryTickAt1000Citizens() {
        var s = WorldGenerator.generate(seed: 404, citizenCount: 1000)
        var empty = 0
        for _ in 0..<300 {
            unblock(&s)
            SimulationEngine.advance(&s)
            if s.agenda.isEmpty && s.pending == nil { empty += 1 }
        }
        XCTAssertEqual(empty, 0, "agenda ran dry on \(empty) of 300 days at 1000 citizens")
    }

    /// A stream of one repeated item would satisfy "never empty" and still be
    /// terrible, so variety is asserted separately.
    func testDecisionStreamHasVariety() {
        var s = WorldGenerator.generate(seed: 11, citizenCount: 500)
        var kinds = Set<AgendaKind>()
        var labels = Set<String>()
        var resolved = 0
        for _ in 0..<300 {
            unblock(&s)
            SimulationEngine.advance(&s)
            for item in s.agenda {
                kinds.insert(item.kind)
                labels.formUnion(item.options.map(\.label))
            }
            // Act on the most pressing thing, like a player would.
            if let top = s.agenda.max(by: { $0.salience < $1.salience }) {
                if case .accepted = SimulationEngine.apply(
                    .resolveAgendaItem(top.id, option: 0), to: &s) { resolved += 1 }
            }
        }
        print("[agenda] kinds seen: \(kinds.map(\.rawValue).sorted())")
        print("[agenda] distinct option labels: \(labels.count), resolved \(resolved) items")
        XCTAssertGreaterThanOrEqual(kinds.count, 3, "decision stream is too monotonous: \(kinds)")
        XCTAssertGreaterThanOrEqual(labels.count, 10, "only \(labels.count) distinct choices exist")
    }

    func testAgendaDoesNotBlockTheClockButCrisesDo() {
        var s = WorldGenerator.generate(seed: 5, citizenCount: 300)
        for _ in 0..<40 { unblock(&s); SimulationEngine.advance(&s) }
        XCTAssertFalse(s.agenda.isEmpty)

        // Non-crisis items present: the day must still advance.
        s.pending = nil
        s.agenda.removeAll { $0.tier == .crisis }
        let before = s.day
        SimulationEngine.advance(&s)
        XCTAssertEqual(s.day, before + 1, "standing agenda should never stall the clock")

        // A crisis-tier item must stall it.
        let blocker = AgendaItem(id: DecisionID(999_999), kind: .election, tier: .crisis,
                                 raisedOnDay: s.day, expiresOnDay: nil, faction: nil,
                                 location: EventLocation(), causes: [],
                                 options: [AgendaOption(id: 0, label: "x", effect: AgendaEffect())])
        s.agenda.append(blocker)
        let held = s.day
        SimulationEngine.advance(&s)
        XCTAssertEqual(s.day, held, "a crisis-tier item must hold the clock")
    }

    func testIgnoredDemandsCostFavorWithoutEndingTheRun() {
        var s = WorldGenerator.generate(seed: 2024, citizenCount: 500)
        // Never answer anything that is not blocking.
        for _ in 0..<200 { unblock(&s); SimulationEngine.advance(&s) }
        let ignored = s.factions.reduce(into: Int32(0)) { $0 += $1.ignoredDemands }
        let minFavor = s.factions.map(\.favor).min() ?? 0
        print("[agenda] ignored \(ignored) demands; lowest faction favor \(minFavor)")
        XCTAssertGreaterThan(ignored, 0, "no demand ever lapsed, so the ignore cost is untested")
        XCTAssertLessThan(minFavor, 0, "ignoring demands should cost favor")
        XCTAssertGreaterThanOrEqual(minFavor, -100, "favor must stay bounded")
        XCTAssertTrue(s.citizens.contains { $0.alive }, "ignoring demands must not end the run")
    }

    func testFavorIsBankedAndRemembered() {
        var s = WorldGenerator.generate(seed: 31, citizenCount: 400)
        for _ in 0..<120 {
            unblock(&s)
            SimulationEngine.advance(&s)
            // Always side with the labourers when they ask.
            if let ask = s.agenda.first(where: { $0.kind == .factionDemand && $0.faction == .labourers }) {
                _ = SimulationEngine.apply(.resolveAgendaItem(ask.id, option: 0), to: &s)
            }
        }
        let lab = s.factions[Int(FactionKind.labourers.rawValue)]
        print("[agenda] labourers favor \(lab.favor), memory entries \(lab.memory.count)")
        XCTAssertFalse(lab.memory.isEmpty, "favor changes should be remembered")
        XCTAssertLessThanOrEqual(lab.memory.count, 24, "memory must stay bounded")
    }

    /// No pure-RNG asks: every demand names a faction that exists and a grievance
    /// its members actually hold.
    func testDemandsTraceToARealGrievance() {
        var s = WorldGenerator.generate(seed: 8, citizenCount: 500)
        var checked = 0
        for _ in 0..<200 {
            unblock(&s)
            SimulationEngine.advance(&s)
            for item in s.agenda where item.kind == .factionDemand {
                let f = try! XCTUnwrap(item.faction)
                XCTAssertGreaterThan(s.factions[Int(f.rawValue)].members, 0,
                                     "\(f) demanded something with no members")
                XCTAssertFalse(item.causes.isEmpty, "a demand with no stated cause is flavour text")
                XCTAssertGreaterThanOrEqual(item.options.count, 2)
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0, "no faction demand was ever generated")
    }

    func testAgendaGenerationIsDeterministic() {
        func run(_ seed: UInt64) -> [String] {
            var s = WorldGenerator.generate(seed: seed, citizenCount: 400)
            var trace: [String] = []
            for _ in 0..<150 {
                if let p = s.pending {
                    _ = SimulationEngine.apply(.resolveDecision(p.id, option: 0), to: &s)
                }
                while let e = s.agenda.first(where: { $0.tier == .crisis }) {
                    _ = SimulationEngine.apply(.resolveAgendaItem(e.id, option: 0), to: &s)
                }
                SimulationEngine.advance(&s)
                trace.append(s.agenda.map { "\($0.id.raw):\($0.kind.rawValue)" }.joined(separator: ","))
            }
            return trace
        }
        XCTAssertEqual(run(99), run(99), "same seed must produce the same decision stream")
        XCTAssertNotEqual(run(99), run(100))
    }

    func testElectionsRecurOnScheduleAndBlockUntilAnswered() {
        var s = WorldGenerator.generate(seed: 60, citizenCount: 300)
        var elections = 0
        for _ in 0..<400 {
            if let p = s.pending {
                _ = SimulationEngine.apply(.resolveDecision(p.id, option: 0), to: &s)
            }
            if let e = s.agenda.first(where: { $0.kind == .election }) {
                elections += 1
                let before = s.day
                SimulationEngine.advance(&s)
                XCTAssertEqual(s.day, before, "an election must hold the clock until answered")
                _ = SimulationEngine.apply(.resolveAgendaItem(e.id, option: 0), to: &s)
            }
            SimulationEngine.advance(&s)
        }
        print("[agenda] elections held in 400 days: \(elections)")
        XCTAssertGreaterThanOrEqual(elections, 2, "elections should recur as a periodic checkpoint")
    }

    func testPlacingWorksRaisesARunHardOrCleanChoiceAtThatSite() {
        var s = WorldGenerator.generate(seed: 3, citizenCount: 200)
        for _ in 0..<5 { unblock(&s); SimulationEngine.advance(&s) }
        unblock(&s)
        s.treasury = 10_000
        s.ledger.externalInflow += 10_000

        var placed: BuildingID? = nil
        for t in 0..<s.map.tileCount {
            let tile = TileIndex(Int32(t))
            if case .accepted = SimulationEngine.apply(.placeBuilding(.workshop, at: tile), to: &s) {
                placed = s.map.building(at: tile)
                break
            }
        }
        let id = try! XCTUnwrap(placed, "could not place a workshop anywhere")
        let commission = try! XCTUnwrap(
            s.agenda.first { $0.kind == .buildingCommission && $0.location.building == id },
            "placing a workshop did not raise a run-hard/run-clean choice")
        XCTAssertEqual(commission.options.count, 3)

        _ = SimulationEngine.apply(.resolveAgendaItem(commission.id, option: 0), to: &s)
        XCTAssertEqual(s.buildings[Int(id.raw)].mode, .intensive,
                       "the commission choice should actually change how the works runs")
    }

    /// Decrees move money and import food; conservation must survive all of it.
    func testConservationHoldsWhileIssuingDecrees() throws {
        var s = WorldGenerator.generate(seed: 1234, citizenCount: 400)
        for _ in 0..<250 {
            unblock(&s)
            SimulationEngine.advance(&s)
            if let d = s.agenda.first(where: { $0.kind == .decree }) {
                _ = SimulationEngine.apply(.resolveAgendaItem(d.id, option: 0), to: &s)
            }
            try s.checkConservation()
        }
    }
}
