import XCTest
@testable import PocketRepublicCore

/// Not a pass/fail suite -- a tuning dashboard. Prints the quantities the balance
/// targets are expressed in so the design lead can see the effect of a config change
/// immediately. Assertions are structural only.
final class EconomyReportTests: XCTestCase {

    func testPrintEconomyReport() throws {
        let citizens = 250
        var s = WorldGenerator.generate(seed: 2026, citizenCount: citizens)
        let days = 200
        for _ in 0..<days { autoResolve(&s); SimulationEngine.advance(&s) }

        let alive = s.citizens.filter(\.alive)
        let employed = alive.filter { $0.work != nil }.count
        let hungry = alive.filter { $0.daysHungry > 0 }.count
        let criminal = alive.filter(\.criminal).count
        let meanHappy = alive.reduce(into: 0) { $0 += Int($1.happiness) } / max(1, alive.count)
        let meanLoyal = alive.reduce(into: 0) { $0 += Int($1.loyalty) } / max(1, alive.count)
        let meanMoney = alive.reduce(into: Int64(0)) { $0 += $1.money } / Int64(max(1, alive.count))

        let farms = s.buildings.filter { $0.kind == .farm }
        let farmWorkers = farms.reduce(into: 0) { $0 += $1.workers.count }
        let farmCapacity = farms.reduce(into: Int32(0)) { $0 += $1.kind.workerCapacity }

        var lines: [String] = []
        lines.append("")
        lines.append("====== ECONOMY REPORT (seed 2026, \(citizens) citizens, \(days) days) ======")
        lines.append("  FOOD   produced/day  \(s.ledger.foodProduced / Int64(days))")
        lines.append("         consumed/day  \(s.ledger.foodConsumed / Int64(days))")
        lines.append("         spoiled/day   \(s.ledger.foodSpoiled / Int64(days))")
        lines.append("         in stores now \(s.totalFoodInWorld)")
        lines.append("         farms \(farms.count), staffed \(farmWorkers)/\(farmCapacity)")
        lines.append("  MONEY  treasury      \(s.treasury)")
        lines.append("         mean wallet   \(meanMoney)")
        lines.append("         ext inflow    \(s.ledger.externalInflow)  outflow \(s.ledger.externalOutflow)")
        lines.append("  PEOPLE employed      \(employed)/\(alive.count)")
        lines.append("         hungry        \(hungry)")
        lines.append("         criminal      \(criminal)")
        lines.append("         happiness     \(meanHappy)   loyalty \(meanLoyal)")
        lines.append("  STATE  corruption \(s.corruption)  legitimacy \(s.legitimacy)")
        lines.append("  DISTRICTS")
        for d in s.districts {
            let name: String = d.name.padding(toLength: 13, withPad: " ", startingAt: 0)
            let pop: String = String(d.population).padding(toLength: 5, withPad: " ", startingAt: 0)
            let mkt: String = String(d.marketCoverage).padding(toLength: 5, withPad: " ", startingAt: 0)
            let clinic: String = String(d.clinicCoverage).padding(toLength: 5, withPad: " ", startingAt: 0)
            let unrest: String = String(d.unrest).padding(toLength: 5, withPad: " ", startingAt: 0)
            lines.append("    \(name) pop \(pop) mkt \(mkt)% clinic \(clinic)% unrest \(unrest) neglect \(d.neglectDays)")
        }
        lines.append("========================================================================")
        print(lines.joined(separator: "\n"))

        XCTAssertEqual(alive.count, citizens)
    }

    /// Supply arithmetic, so a chronic shortage is visible as a number rather than
    /// surfacing indirectly as a famine crisis every few days.
    func testFoodSupplyHeadroom() throws {
        var s = WorldGenerator.generate(seed: 4, citizenCount: 250)
        for _ in 0..<100 { autoResolve(&s); SimulationEngine.advance(&s) }
        let producedPerDay = Double(s.ledger.foodProduced) / 100.0
        let neededPerDay = Double(s.citizens.filter(\.alive).count) * Double(s.config.foodPerCitizenPerDay)
        let ratio = producedPerDay / neededPerDay
        print("[economy] food supply ratio: \(String(format: "%.2f", ratio)) "
              + "(produced \(String(format: "%.0f", producedPerDay))/day vs needed \(String(format: "%.0f", neededPerDay))/day, "
              + "spoilage \(s.config.marketSpoilagePercent)%)")
        XCTAssertGreaterThan(producedPerDay, 0, "no food is being produced at all")
    }
}
