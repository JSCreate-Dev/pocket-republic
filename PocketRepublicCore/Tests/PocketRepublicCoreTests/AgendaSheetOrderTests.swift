import XCTest
@testable import PocketRepublicCore

final class AgendaSheetOrderTests: XCTestCase {
    func testElectionOutranksACoexistingIslandEvent() {
        let election = AgendaSheetOrder.rank(tier: .crisis, isIslandEvent: false, isDecree: false)
        let island = AgendaSheetOrder.rank(tier: .advisory, isIslandEvent: true, isDecree: false)
        let decree = AgendaSheetOrder.rank(tier: .decree, isIslandEvent: false, isDecree: true)
        XCTAssertLessThan(election, island)
        XCTAssertLessThan(island, decree)
    }

    func testOneCardPreviewIsTheBlockingChoice() {
        let rows = [
            AgendaSheetOrder.rank(tier: .advisory, isIslandEvent: true, isDecree: false),
            AgendaSheetOrder.rank(tier: .crisis, isIslandEvent: false, isDecree: false),
            AgendaSheetOrder.rank(tier: .decree, isIslandEvent: false, isDecree: true)
        ]
        let first = rows.enumerated().min { $0.element < $1.element }?.offset
        XCTAssertEqual(first, 1)
    }
}
