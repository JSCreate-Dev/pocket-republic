import XCTest
@testable import PocketRepublicCore

final class IslandEventPaperTests: XCTestCase {
    private let headline = "Carnival fills the streets of Harbor"

    func testRepeatedHeadlineStaysAfterAnOlderOutcome() {
        let firstRaise = raise(id: 1, day: 10)
        let outcome = answer(id: 2, day: 12, result: "The square stayed quiet")
        let secondRaise = raise(id: 3, day: 40)
        let suppressed = IslandEventPaper.suppressedRaiseIDs(in: [firstRaise, outcome, secondRaise])
        XCTAssertEqual(suppressed, Set([Int64(1)]))
        XCTAssertFalse(suppressed.contains(3))
    }

    func testOutcomeDoesNotConsumeARaiseThatFollowsIt() {
        let outcome = answer(id: 2, day: 12, result: "The square stayed quiet")
        let later = raise(id: 5, day: 40)
        XCTAssertTrue(IslandEventPaper.suppressedRaiseIDs(in: [outcome, later]).isEmpty)
    }

    func testDifferentHeadlinesDoNotCross() {
        let carnival = raise(id: 1, day: 10)
        let other = GameEvent(
            id: EventID(2), day: 11, kind: .islandEvent,
            causes: [CauseFactor(.islandEvent, value: 3, detail: "Nets come up full off Harbor")],
            magnitude: 3)
        let carnivalOutcome = answer(id: 4, day: 14, result: "The square stayed quiet")
        let suppressed = IslandEventPaper.suppressedRaiseIDs(in: [carnival, other, carnivalOutcome])
        XCTAssertEqual(suppressed, Set([Int64(1)]))
        XCTAssertFalse(suppressed.contains(2))
    }

    private func raise(id: Int64, day: Int32) -> GameEvent {
        GameEvent(
            id: EventID(id), day: day, kind: .islandEvent,
            causes: [CauseFactor(.islandEvent, value: 0, detail: headline)],
            magnitude: 0)
    }

    private func answer(id: Int64, day: Int32, result: String) -> GameEvent {
        GameEvent(
            id: EventID(id), day: day, kind: .islandEvent,
            causes: [CauseFactor(.islandEvent, value: 1, detail: "\(headline). \(result)")],
            magnitude: 1)
    }
}
