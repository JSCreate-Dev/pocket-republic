import XCTest
@testable import PocketRepublicCore

final class MapAttentionTests: XCTestCase {
    func testAttentionMatchesInspectStatusWithoutChangingState() {
        var state = WorldGenerator.generate(seed: 44)
        for index in state.map.road.indices { state.map.road[index] = false }
        let hash = state.stateHash()
        for building in state.buildings {
            let attention = BuildingInspector.attention(id: building.id, in: state)
            XCTAssertEqual(attention?.kind, .road)
            XCTAssertEqual(attention?.title, BuildingInspector.make(id: building.id, in: state)?.sections.first?.rows.first?.value)
        }
        XCTAssertEqual(hash, state.stateHash())
    }

    func testDeliveredFarmStockDoesNotMeanFoodShortage() throws {
        var state = WorldGenerator.generate(seed: 44)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        let index = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .farm })
        state.buildings[index].foodStore = 0
        XCTAssertNil(BuildingInspector.attention(id: state.buildings[index].id, in: state))
    }

    func testMarketFoodProblemChangesAsStockArrives() throws {
        var state = WorldGenerator.generate(seed: 44)
        SimulationEngine.rebuildSpatialCaches(&state)
        SimulationEngine.assignWork(&state)
        let index = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .market })
        let id = state.buildings[index].id
        state.buildings[index].foodStore = 0
        XCTAssertEqual(BuildingInspector.attention(id: id, in: state)?.kind, .food)
        state.buildings[index].foodStore = 20
        XCTAssertNil(BuildingInspector.attention(id: id, in: state))
    }

    func testConstructionAndDemolishedSitesDoNotWarn() throws {
        var state = WorldGenerator.generate(seed: 44)
        let index = try XCTUnwrap(state.buildings.firstIndex { $0.kind == .workshop })
        let id = state.buildings[index].id
        state.buildings[index].daysRequired = 3
        XCTAssertNil(BuildingInspector.attention(id: id, in: state))
        _ = SimulationEngine.apply(.demolish(id), to: &state)
        XCTAssertNil(BuildingInspector.attention(id: id, in: state))
        XCTAssertNil(BuildingInspector.attention(id: BuildingID(-1), in: state))
    }
}
