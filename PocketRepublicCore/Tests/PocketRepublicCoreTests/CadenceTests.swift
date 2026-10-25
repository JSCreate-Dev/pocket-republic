import XCTest
@testable import PocketRepublicCore

/// Measures the revised design target: a real decision available to the player on
/// *every* day-advance, not one crisis every few days. Mostly a reporting harness
/// for the balance pass, with one hard assertion on the guarantee itself.
final class CadenceTests: XCTestCase {

    func testEveryDayOffersSomethingActionable() {
        var worstRun = 0
        for seed in UInt64(1)...5 {
            var s = WorldGenerator.generate(seed: seed, citizenCount: 500)
            var byTier = [Int: Int]()
            var byKind = [String: Int]()
            var idleDays = 0
            var blockingDays = 0
            let days = 300

            for _ in 0..<days {
                autoResolve(&s)
                SimulationEngine.advance(&s)
                if s.blocksAdvance { blockingDays += 1 }
                if s.agenda.isEmpty && s.pending == nil {
                    idleDays += 1
                } else {
                    for item in s.agenda {
                        byTier[Int(item.tier.rawValue), default: 0] += 1
                        byKind[item.kind.rawValue, default: 0] += 1
                    }
                }
                // A player who answers one thing a day.
                if let top = s.agenda.max(by: { $0.salience < $1.salience }) {
                    _ = SimulationEngine.apply(.resolveAgendaItem(top.id, option: 0), to: &s)
                }
            }

            let tiers = byTier.sorted { $0.key < $1.key }
                .map { "\(AgendaTier(rawValue: UInt8($0.key))!)=\($0.value)" }
                .joined(separator: " ")
            print("[cadence] seed \(seed): \(idleDays) idle days of \(days); "
                  + "\(blockingDays) blocked; offers by tier: \(tiers)")
            print("[cadence]   kinds: \(byKind.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" })")
            worstRun = max(worstRun, idleDays)
        }
        print("[cadence] TARGET zero idle days; WORST SEED had \(worstRun)")
        XCTAssertEqual(worstRun, 0, "the player had nothing actionable on \(worstRun) days")
    }

    /// Crises should be the rare spike on top of the standing agenda, not the
    /// stream itself. Run across seeds: a single-seed version of this passes or
    /// fails on luck, which is worse than no test.
    func testCrisesAreTheExceptionNotTheStream() {
        var rates: [Int] = []
        let days = 300
        for seed in UInt64(1)...6 {
            var s = WorldGenerator.generate(seed: seed, citizenCount: 500)
            var crises = 0
            for _ in 0..<days {
                if s.pending != nil { crises += 1 }
                autoResolve(&s)
                SimulationEngine.advance(&s)
                if let top = s.agenda.max(by: { $0.salience < $1.salience }) {
                    _ = SimulationEngine.apply(.resolveAgendaItem(top.id, option: 0), to: &s)
                }
            }
            rates.append(crises)
        }
        let worst = rates.max() ?? 0
        let mean = rates.reduce(0, +) / rates.count
        print("[cadence] crisis days per \(days) by seed: \(rates) (mean \(mean), worst \(worst))")
        print("[cadence] NOTE target is a rare spike; worst seed is \(worst * 100 / days)% of days")
        XCTAssertLessThan(worst, days / 2,
                          "on the worst seed the clock is held by a crisis \(worst) of \(days) days")
    }
}
