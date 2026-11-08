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
        // Footprints block every tile but the entrance, so the road walk is one
        // step longer than when a building was a single passable tile. The cap
        // is 21, which is that step and no more: seed 2026's farthest door sits
        // on the cap, and a tile at 22 is still out of range.
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
            XCTAssertEqual(hungryBeyondCap, 0,
                           "seed \(seed): a door inside the cap went hungry, or a door past it was left there")
            XCTAssertEqual(s.config.maxServiceDistance, 21)
            var farthest: UInt16 = 0
            var onTheCap = 0
            for c in s.citizens where c.alive {
                guard let home = c.home else { continue }
                let tile = s.buildings[Int(home.raw)].tile
                let door = SimulationEngine.marketServiceDistance(s, homeTile: tile)
                guard door < .max else { continue }
                if door > farthest { farthest = door }
                if door == s.config.maxServiceDistance { onTheCap += 1 }
            }
            XCTAssertLessThanOrEqual(farthest, s.config.maxServiceDistance,
                                     "seed \(seed) has a door at \(farthest), past the cap")
            if seed == 2026 {
                XCTAssertEqual(farthest, 21,
                               "seed 2026's farthest market walk should sit on the cap, not inside a looser one")
                XCTAssertGreaterThan(onTheCap, 0)
            }
            try s.checkConservation()
        }
    }

    /// 21 is the footprint step. The next road tile is still a placement decision.
    func testServiceCapLeavesTheNextTileOutOfRange() {
        var map = WorldMap(width: 40, height: 4)
        for x in Int32(0)..<40 { map.road[Int(map.index(x: x, y: 1).raw)] = true }
        let dist = DistanceFields.bfs(map: map, sources: [map.index(x: 0, y: 1)])
        let cap = BalanceConfig().maxServiceDistance
        XCTAssertEqual(cap, 21)
        XCTAssertLessThanOrEqual(dist[Int(map.index(x: 21, y: 1).raw)], cap)
        XCTAssertGreaterThan(dist[Int(map.index(x: 22, y: 1).raw)], cap)
    }
}
