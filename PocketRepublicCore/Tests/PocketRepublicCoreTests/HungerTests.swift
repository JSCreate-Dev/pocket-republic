import XCTest
@testable import PocketRepublicCore

/// The 200-day unattended city (seed 2026, 250 citizens) used to leave about 47
/// people hungry while farms produced ~372 food/day against 250 needed and markets
/// hoarded thousands of units. This locks that case.
final class HungerTests: XCTestCase {

    func testSurplusDoesNotLeaveCitizensHungry() throws {
        // 2026 is the reported ~47/250 case. 11 left a market empty while its
        // neighbours were hoarding. Both stay in surplus and both must settle fed.
        for seed in [UInt64(2026), 11] {
            var s = WorldGenerator.generate(seed: seed, citizenCount: 250)
            let days = 120
            var chronic = 0
            for day in 1...days {
                autoResolve(&s)
                SimulationEngine.advance(&s)
                let hungry = s.citizens.filter { $0.alive && $0.daysHungry > 0 }.count
                if day >= 40 { chronic = max(chronic, hungry) }
            }

            let alive = s.citizens.filter(\.alive).count
            let producedPerDay = s.ledger.foodProduced / Int64(days)
            let neededPerDay = Int64(alive) * Int64(s.config.foodPerCitizenPerDay)
            XCTAssertGreaterThan(producedPerDay, neededPerDay,
                                 "seed \(seed) must be a surplus (produced \(producedPerDay), needed \(neededPerDay))")
            XCTAssertGreaterThan(s.totalFoodInWorld, neededPerDay,
                                 "seed \(seed) stores should still hold more than one day of demand")
            XCTAssertEqual(chronic, 0,
                           "seed \(seed): \(chronic) of \(alive) citizens were hungry on a settled day while the city had a food surplus")
            try s.checkConservation()
        }
    }
}
