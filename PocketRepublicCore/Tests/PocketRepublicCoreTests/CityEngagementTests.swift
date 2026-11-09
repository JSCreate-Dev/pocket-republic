import XCTest
@testable import PocketRepublicCore

final class CityEngagementTests: XCTestCase {
    func testFreshTownSuggestsAutomaticEmploymentAndHousing() {
        let state = WorldGenerator.generate(seed: 44)
        let hash = state.stateHash()
        let goals = CityFocusReader.goals(in: state)
        XCTAssertEqual(goals.first?.action, .build(.workshop))
        XCTAssertEqual(goals.first?.current, 13)
        XCTAssertEqual(goals.first?.target, 16)
        XCTAssertTrue(goals.contains { $0.action == .build(.house) })
        XCTAssertEqual(state.stateHash(), hash)
    }

    func testHungryResidentsComeBeforeExpansion() {
        var state = WorldGenerator.generate(seed: 44)
        state.citizens[0].daysHungry = 2
        let goal = CityFocusReader.goals(in: state).first!
        XCTAssertEqual(goal.action, .overlay(.foodAccess))
        XCTAssertLessThan(goal.fraction, 1)
    }

    func testExistingConstructionDoesNotSuggestDuplicateWorkshops() throws {
        var state = WorldGenerator.generate(seed: 44)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        let index = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .workshop })
        state.buildings[index].daysRequired = 3
        let goals = CityFocusReader.goals(in: state)
        XCTAssertFalse(goals.contains { $0.action == .build(.workshop) })
        XCTAssertTrue(goals.contains { $0.action == .inspect(state.buildings[index].id) })
    }

    func testDayResultUsesRealDeltasAndRejectsSameDayOrNewCity() {
        var state = WorldGenerator.generate(seed: 44)
        let before = CityDaySnapshot(state: state)
        state.day += 1
        state.treasury -= 120
        state.citizens[0].happiness -= 16
        let result = CityDayResult.compare(before, CityDaySnapshot(state: state))!
        XCTAssertEqual(result.treasuryDelta, -120)
        XCTAssertEqual(result.happinessDelta, -1)
        XCTAssertEqual(result.populationDelta, 0)
        XCTAssertNil(CityDayResult.compare(before, before))
        var other = WorldGenerator.generate(seed: 45)
        other.day = 4
        XCTAssertNil(CityDayResult.compare(before, CityDaySnapshot(state: other)))
    }

    func testOpensOnlyStandingNewSitesAndNeverReplaysOldBuildings() throws {
        var state = WorldGenerator.generate(seed: 44)
        let index = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .workshop })
        state.buildings[index].daysRequired = 2
        let before = CityDaySnapshot(state: state)
        state.day = 2
        state.buildings[index].daysConstructed = 2
        let after = CityDaySnapshot(state: state)
        XCTAssertEqual(CityDayResult.compare(before, after)?.newlyOpened, 1)
        state.day = 3
        XCTAssertEqual(CityDayResult.compare(after, CityDaySnapshot(state: state))?.newlyOpened, 0)
    }

    func testReadyTownWaitsForArrivalsInsteadOfMoreConstruction() throws {
        var state = WorldGenerator.generate(seed: 44)
        let centre = state.map.index(x: 32, y: 32)
        XCTAssertNotNil(WorldGenerator.place(&state, .house, near: centre))
        XCTAssertNotNil(WorldGenerator.place(&state, .workshop, near: centre))
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        for index in state.citizens.indices {
            state.citizens[index].happiness = 60
            state.citizens[index].daysHungry = 0
        }
        let market = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .market })
        state.buildings[market].foodStore = 1000
        let goals = CityFocusReader.goals(in: state)
        XCTAssertEqual(goals.first?.action, .growth)
        XCTAssertFalse(goals.contains { if case .build = $0.action { return true }; return false })
    }

    func testLegacyAndEmptyStatesOfferAReadableFallback() {
        var state = WorldGenerator.generate(seed: 44, citizenCount: 120)
        state.citizens = []
        let goals = CityFocusReader.goals(in: state)
        XCTAssertEqual(goals.last?.action, .roadmap)
        XCTAssertEqual(goals.last?.target, 0)
        XCTAssertTrue(goals.allSatisfy { $0.fraction.isFinite && $0.fraction >= 0 && $0.fraction <= 1 })
    }
}
