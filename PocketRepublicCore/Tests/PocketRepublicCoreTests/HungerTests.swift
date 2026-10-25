import XCTest
@testable import PocketRepublicCore

/// The 200-day unattended city (seed 2026, 250 citizens) used to leave about 47
/// people hungry while farms produced ~372 food/day against 250 needed and markets
/// hoarded thousands of units. This locks that case.
final class HungerTests: XCTestCase {

    func testSurplusDoesNotLeaveCitizensHungry() throws {
        // 2026 is the reported ~47/250 case. 11 left a market empty while its
        // neighbours were hoarding. Both stay in surplus and every household
        // inside the service cap must settle fed.
        //
        // Seed 2026 still has four households whose door is 21 tiles from the
        // nearest market. `maxServiceDistance` is 20. Multi-tile footprints
        // block every tile but the entrance, so the road walk is one step
        // longer than it was when buildings were a single passable tile.
        // Those four are outside the cap on purpose; they are not the surplus bug.
        for seed in [UInt64(2026), 11] {
            var s = WorldGenerator.generate(seed: seed, citizenCount: 250)
            let days = 120
            var hungryInRange = 0
            var hungryBeyondCap = 0
            for day in 1...days {
                autoResolve(&s)
                SimulationEngine.advance(&s)
                guard day >= 40 else { continue }
                var inRange = 0
                var beyond = 0
                for c in s.citizens where c.alive && c.daysHungry > 0 {
                    guard let home = c.home else { inRange += 1; continue }
                    let tile = s.buildings[Int(home.raw)].tile
                    let door = SimulationEngine.marketServiceDistance(s, homeTile: tile)
                    if door > s.config.maxServiceDistance { beyond += 1 } else { inRange += 1 }
                }
                hungryInRange = max(hungryInRange, inRange)
                hungryBeyondCap = max(hungryBeyondCap, beyond)
            }

            let alive = s.citizens.filter(\.alive).count
            let producedPerDay = s.ledger.foodProduced / Int64(days)
            let neededPerDay = Int64(alive) * Int64(s.config.foodPerCitizenPerDay)
            XCTAssertGreaterThan(producedPerDay, neededPerDay,
                                 "seed \(seed) must be a surplus (produced \(producedPerDay), needed \(neededPerDay))")
            XCTAssertGreaterThan(s.totalFoodInWorld, neededPerDay,
                                 "seed \(seed) stores should still hold more than one day of demand")
            XCTAssertEqual(hungryInRange, 0,
                           "seed \(seed): \(hungryInRange) citizens inside market range were hungry on a settled day while the city had a food surplus")
            if seed == 11 {
                XCTAssertEqual(hungryBeyondCap, 0,
                               "seed 11 has no household past the service cap")
            } else {
                XCTAssertEqual(hungryBeyondCap, 4,
                               "seed 2026: footprints leave four doors one step past the service cap, and nobody else")
            }
            try s.checkConservation()
        }
    }
}
