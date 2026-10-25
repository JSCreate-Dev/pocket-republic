import Foundation
import XCTest
@testable import PocketRepublicCore

final class EngineTests: XCTestCase {
    func testSameSeedAndActionsProduceSameState() throws {
        var first = Engine.makeInitialState(worldSeed: 12345)
        var second = Engine.makeInitialState(worldSeed: 12345)
        XCTAssertEqual(first.citizens.map(\.id), second.citizens.map(\.id))
        XCTAssertEqual(first.citizens.first?.id, CitizenID(1))

        for _ in 0..<12 {
            if first.pending != nil {
                first = Engine.decide(0, in: first)
                second = Engine.decide(0, in: second)
            }
            first = Engine.advance(first)
            second = Engine.advance(second)
        }
        XCTAssertEqual(try encoded(first), try encoded(second))
    }

    func testSavedRNGResumesTheSameSequence() throws {
        let original = Engine.advance(Engine.makeInitialState(worldSeed: 98765))
        let data = try SaveCodec.encode(original)
        guard case .loaded(let restored) = SaveCodec.decode(data) else {
            return XCTFail("Expected a readable save")
        }
        XCTAssertEqual(restored.worldSeed, original.worldSeed)
        XCTAssertEqual(restored.rngState, original.rngState)
        XCTAssertEqual(restored.citizens.map(\.id), original.citizens.map(\.id))
        XCTAssertEqual(try encoded(Engine.advance(restored)), try encoded(Engine.advance(original)))
    }

    func testNewCorruptionDoesNotAffectLaterCitizensOnSameDay() {
        var selectedSeed: UInt64?
        var expectedDrift = 0
        for seed in UInt64(1)...UInt64(10_000) {
            var rng = SeededRNG(state: seed)
            _ = rng.nextInt(upperBound: 7) // first citizen happiness
            _ = rng.nextInt(upperBound: 7) // first citizen wealth
            if rng.nextInt(upperBound: 100) < 12 {
                selectedSeed = seed
                expectedDrift = rng.nextInt(upperBound: 7) - 3
                break
            }
        }
        guard let seed = selectedSeed else { return XCTFail("No qualifying seed found") }
        let first = Citizen(id: CitizenID(1), name: "First", occupation: "Worker", ambition: 90, loyalty: 80, wealth: 0, happiness: 50, influence: 0)
        let second = Citizen(id: CitizenID(2), name: "Second", occupation: "Worker", ambition: 10, loyalty: 60, wealth: 20, happiness: 50, influence: 0)
        let start = Republic(worldSeed: seed, food: 1000, tax: 0, services: 0, security: 50, corruption: 50, citizens: [first, second])
        let next = Engine.advance(start)
        XCTAssertTrue(next.citizens[0].criminal)
        XCTAssertEqual(next.citizens[1].loyalty, 60 + expectedDrift / 2)
        XCTAssertEqual(next.corruption, 51)
    }

    func testPendingDecisionPausesDayAndRNG() throws {
        var state = Engine.makeInitialState(worldSeed: 4)
        state.pending = "scandal"
        XCTAssertEqual(try encoded(Engine.advance(state)), try encoded(state))
        XCTAssertEqual(Engine.decide(0, in: state).rngState, state.rngState)
        XCTAssertEqual(try encoded(Engine.decide(99, in: state)), try encoded(state))
    }

    func testAlreadyCriminalCitizenDoesNotRepeatCrime() {
        let citizen = Citizen(id: CitizenID(1), name: "First", occupation: "Worker", ambition: 90, loyalty: 80, wealth: 0, happiness: 50, influence: 0, criminal: true)
        let start = Republic(worldSeed: 123, food: 1000, tax: 0, services: 0, security: 50, corruption: 50, citizens: [citizen])
        let next = Engine.advance(start)
        XCTAssertEqual(next.corruption, 49)
        XCTAssertFalse(next.news.contains { $0.contains("black-market trading") })
    }

    func testCatchUpClampsBeforeIntegerConversion() {
        XCTAssertEqual(OfflineCatchUp.days(elapsedSeconds: -Double.greatestFiniteMagnitude), 0)
        XCTAssertEqual(OfflineCatchUp.days(elapsedSeconds: Double.greatestFiniteMagnitude), 3)
        XCTAssertEqual(OfflineCatchUp.days(elapsedSeconds: 54000), 2)
        XCTAssertNil(OfflineCatchUp.days(elapsedSeconds: .nan))
    }

    func testSaveCodecSeparatesMissingCorruptAndUnsupported() throws {
        if case .missing = SaveCodec.decode(nil) {} else { XCTFail("Expected missing") }
        if case .corrupt = SaveCodec.decode(Data("invalid".utf8)) {} else { XCTFail("Expected corrupt") }
        if case .unsupportedVersion(1) = SaveCodec.decode(Data("{\"day\":1}".utf8)) {} else { XCTFail("Expected legacy version") }

        var future = Engine.makeInitialState(worldSeed: 1)
        future.schemaVersion = 99
        if case .unsupportedVersion(99) = SaveCodec.decode(try SaveCodec.encode(future)) {} else { XCTFail("Expected unsupported version") }

        var unknownEvent = Engine.makeInitialState(worldSeed: 1)
        unknownEvent.pending = "unknown"
        if case .corrupt = SaveCodec.decode(try SaveCodec.encode(unknownEvent)) {} else { XCTFail("Expected unknown event to be rejected") }
    }

    private func encoded(_ state: Republic) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(state)
    }
}
