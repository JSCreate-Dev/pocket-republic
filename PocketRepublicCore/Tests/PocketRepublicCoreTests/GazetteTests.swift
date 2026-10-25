import XCTest
@testable import PocketRepublicCore

final class GazetteTests: XCTestCase {
    private let harbour = DistrictID(1)

    private func hungry(_ id: Int64, citizen: Int32, day: Int32 = 5, district: DistrictID? = nil,
                        days: Int32 = 1, market: Bool = false) -> GameEvent {
        var causes = [CauseFactor(.foodShortage, value: days, detail: "days hungry")]
        if market {
            causes.append(CauseFactor(.noMarketAccess, value: 40, detail: "Harbour"))
        }
        return GameEvent(id: EventID(id), day: day, kind: .citizenHungry,
                         location: EventLocation(district: district ?? harbour),
                         subjects: [CitizenID(citizen)], causes: causes)
    }

    private var names: GazetteNames {
        GazetteNames(
            districts: [1: "Harbour", 2: "East Docks"],
            citizens: [
                0: "Ana Reyes", 1: "Tomas Ortiz", 2: "Isabel Rivas", 3: "Mateo Ruiz"
            ],
            buildings: [1: "house", 2: "clinic", 3: "market"]
        )
    }

    func testGroupsSameDistrictAndDay() {
        let events = (0..<4).map { hungry(Int64($0 + 1), citizen: Int32($0)) }
        let editions = EventGazette.editions(events: events, names: names)
        XCTAssertEqual(editions.count, 1)
        XCTAssertEqual(editions[0].masthead, "Day 5 · The Pocket Gazette")
        XCTAssertEqual(editions[0].stories.count, 1)
        let story = editions[0].stories[0]
        XCTAssertEqual(story.headline, "4 families went hungry in Harbour")
        XCTAssertEqual(story.count, 4)
        XCTAssertEqual(story.names, ["Ana Reyes", "Tomas Ortiz", "Isabel Rivas", "Mateo Ruiz"])
        XCTAssertEqual(EventGazette.nameLine(story.names), "Ana Reyes, Tomas Ortiz, Isabel Rivas and 1 other")
        XCTAssertEqual(story.because, "Hungry for 1 day")
        XCTAssertNil(story.trend)
        XCTAssertFalse(story.headline.contains("citizenHungry"))
        XCTAssertFalse(story.because?.contains("days hungry") == true)
    }

    func testHungryCauseKeepsTheDayCount() {
        let line = CauseCopy.line(CauseFactor(.foodShortage, value: 5, detail: "days hungry"))
        XCTAssertEqual(line, "Hungry for 5 days")
        let both = CauseCopy.why([
            CauseFactor(.foodShortage, value: 9, detail: "days hungry"),
            CauseFactor(.noMarketAccess, value: 40, detail: "Harbour")
        ])
        XCTAssertEqual(both, "No market within reach for 9 days")
    }

    func testMissingCauseOmitsTheBecauseLine() {
        let event = GameEvent(id: EventID(1), day: 5, kind: .citizenHungry,
                              location: EventLocation(district: harbour),
                              subjects: [CitizenID(0)])
        let story = EventGazette.editions(events: [event], names: names)[0].stories[0]
        XCTAssertEqual(story.headline, "1 family went hungry in Harbour")
        XCTAssertNil(story.because)
    }

    func testSeparateDistrictsAndDaysStaySeparate() {
        let events = [
            hungry(1, citizen: 0, day: 5, district: harbour),
            hungry(2, citizen: 1, day: 5, district: DistrictID(2)),
            hungry(3, citizen: 2, day: 4, district: harbour)
        ]
        let editions = EventGazette.editions(events: events, names: names)
        XCTAssertEqual(editions.map(\.day), [5, 4])
        XCTAssertEqual(editions[0].stories.count, 2)
        XCTAssertTrue(editions[0].stories.contains { $0.headline == "1 family went hungry in Harbour" })
        XCTAssertTrue(editions[0].stories.contains { $0.headline == "1 family went hungry in East Docks" })
    }

    func testWeightOrdersCrisisBeforeBadNews() {
        let crisis = GameEvent(
            id: EventID(1), day: 8, kind: .crisisRaised,
            location: EventLocation(district: harbour),
            causes: [
                CauseFactor(.districtNeglect, value: 9, detail: "Harbour"),
                CauseFactor(.noMarketAccess, value: 20, detail: "market coverage %")
            ])
        let hungryEvent = hungry(2, citizen: 0, day: 8)
        let editions = EventGazette.editions(events: [hungryEvent, crisis], names: names)
        XCTAssertEqual(editions[0].stories.map(\.weight), [.crisis, .bad])
        XCTAssertEqual(editions[0].stories[0].headline, "Crisis in Harbour: an uprising")
        XCTAssertEqual(editions[0].stories[0].because, "Harbour has gone 9 days without a market in range")
    }

    func testSingleHiresAndHousesFoldIntoTheRoutineLine() {
        let hires = (0..<3).map { index -> GameEvent in
            GameEvent(id: EventID(Int64(index + 1)), day: 6, kind: .citizenEmployed,
                      location: EventLocation(district: DistrictID(UInt8(index + 1)), building: BuildingID(2)),
                      subjects: [CitizenID(Int32(index))])
        }
        let house = GameEvent(id: EventID(9), day: 6, kind: .buildingConstructed,
                              location: EventLocation(district: harbour, building: BuildingID(1), tile: TileIndex(4)))
        let day = GameEvent(id: EventID(10), day: 6, kind: .dayAdvanced,
                            causes: [CauseFactor(.policyChange, value: 10, detail: "income tax")])
        let editions = EventGazette.editions(events: hires + [house, day], names: names)
        XCTAssertEqual(editions.count, 1)
        XCTAssertTrue(editions[0].stories.isEmpty)
        XCTAssertEqual(editions[0].routineLine, "3 citizens found work · 1 new house built")
    }

    func testAClinicOpeningStaysAStory() {
        let clinic = GameEvent(id: EventID(1), day: 2, kind: .buildingConstructed,
                               location: EventLocation(district: harbour, building: BuildingID(2)))
        let editions = EventGazette.editions(events: [clinic], names: names)
        XCTAssertEqual(editions[0].stories[0].headline, "A new clinic opens in Harbour")
        XCTAssertEqual(editions[0].stories[0].weight, .good)
        XCTAssertNil(editions[0].routineLine)
    }

    func testTrendUsesConsecutiveDaysOrHungerCount() {
        let streak = [3, 4, 5].map { day in hungry(Int64(day), citizen: 0, day: Int32(day), days: 1) }
        let editions = EventGazette.editions(events: streak, names: names)
        let latest = editions.first { $0.day == 5 }?.stories[0]
        XCTAssertEqual(latest?.trend, "3rd day running")

        let long = hungry(1, citizen: 0, days: 9)
        let trend = EventGazette.editions(events: [long], names: names)[0].stories[0].trend
        XCTAssertEqual(trend, "9th day running")
        XCTAssertEqual(EventGazette.ordinal(11), "11th")
        XCTAssertEqual(EventGazette.ordinal(22), "22nd")
    }

    func testHeadlinesNeverUseTheRawKindName() {
        let kinds: [EventKind] = [
            .citizenHungry, .foodShortage, .citizenUnemployed, .citizenTurnedToCrime,
            .districtNeglected, .districtProtest, .buildingConstructed, .buildingAbandoned,
            .migrationArrival, .migrationDeparture, .factionDemandRaised, .factionDemandIgnored,
            .decreeIssued, .crisisRaised, .crisisResolved, .treasuryEmpty,
            .electionCalled, .electionHeld, .agendaItemResolved
        ]
        for (index, kind) in kinds.enumerated() {
            let event = GameEvent(id: EventID(Int64(index + 1)), day: 1, kind: kind,
                                  location: EventLocation(district: harbour, building: BuildingID(3)),
                                  subjects: [CitizenID(0)],
                                  causes: [CauseFactor(.foodShortage, value: 2, detail: "Labourers")])
            let editions = EventGazette.editions(events: [event], names: names)
            let story = try? XCTUnwrap(editions.first?.stories.first)
            XCTAssertNotNil(story, "missing story for \(kind.rawValue)")
            XCTAssertFalse(story?.headline.contains(kind.rawValue) ?? true, story?.headline ?? "")
        }
        XCTAssertEqual(HeadlineTable.templates.count, 21)
    }

    func testFutureCauseSentenceIsKept() {
        let sentence = "The east market closed its stalls before noon."
        let line = CauseCopy.why([CauseFactor(.foodShortage, value: 1, detail: sentence)])
        XCTAssertEqual(line, sentence)
    }
}

final class DecreeCardCopyTests: XCTestCase {
    func testFreeWageCardUsesArrowsAndSkipsAZeroCost() {
        guard let wage = DecreeCatalogue.all.first(where: { $0.name == "Raise the civic wage" }) else {
            return XCTFail("missing civic wage decree")
        }
        let card = DecreeCardCopy.make(spec: wage, treasury: 500, flavor: nil, district: nil)
        XCTAssertEqual(card.title, "Raise the civic wage")
        XCTAssertNil(card.flavor)
        XCTAssertEqual(card.costLabel, "Free")
        XCTAssertNil(card.shortfall)
        XCTAssertTrue(card.canAfford)
        XCTAssertEqual(card.effects, ["Civic wage +1/day"])
        XCTAssertFalse(card.effects.joined(separator: " ").contains(": 0"))
        XCTAssertEqual(card.chips.map(\.label), ["Officials ▲▲▲", "Merchants ▼▼"])
        XCTAssertEqual(card.topPleased, "Officials ▲▲▲")
        XCTAssertEqual(card.topAngered, "Merchants ▼▼")
    }

    func testPurgeShowsCostShortfallAndTrustLines() {
        guard let purge = DecreeCatalogue.all.first(where: { $0.name == "Purge the graft registers" }) else {
            return XCTFail("missing purge decree")
        }
        let card = DecreeCardCopy.make(spec: purge, treasury: 220, flavor: "  ", district: nil)
        XCTAssertEqual(card.costLabel, "260")
        XCTAssertEqual(card.shortfall, 40)
        XCTAssertFalse(card.canAfford)
        XCTAssertNil(card.flavor)
        XCTAssertEqual(card.effects, ["−260 now", "Legitimacy up", "Corruption down"])
        XCTAssertEqual(card.topPleased, "Landless ▲▲")
        XCTAssertEqual(card.topAngered, "Officials ▼▼▼")
        XCTAssertEqual(card.chips.first?.label, "Landless ▲▲")
        XCTAssertEqual(card.chips.last?.label, "Officials ▼▼▼")
    }

    func testFlavorIsShownOnlyWhenProvided() {
        let wage = DecreeCatalogue.all[0]
        let spoken = "Clerks, nurses and teachers get a little more in every pay packet."
        let card = DecreeCardCopy.make(spec: wage, treasury: 0, flavor: spoken, district: "Harbour")
        XCTAssertEqual(card.flavor, spoken)
    }

    func testArrowBands() {
        XCTAssertEqual(DecreeCardCopy.arrows(for: 1), "▲")
        XCTAssertEqual(DecreeCardCopy.arrows(for: 3), "▲")
        XCTAssertEqual(DecreeCardCopy.arrows(for: 4), "▲▲")
        XCTAssertEqual(DecreeCardCopy.arrows(for: 6), "▲▲")
        XCTAssertEqual(DecreeCardCopy.arrows(for: 7), "▲▲▲")
        XCTAssertEqual(DecreeCardCopy.arrows(for: -8), "▼▼▼")
        XCTAssertEqual(DecreeCardCopy.arrows(for: 0), "")
    }

    func testScopedUnrestNamesTheDistrict() {
        var effect = AgendaEffect()
        effect.districtUnrest = -16
        effect.legitimacy = -6
        effect.corruption = 4
        let lines = DecreeCardCopy.effectLines(effect, pay: 120, district: "Harbour")
        XCTAssertEqual(lines, [
            "−120 now",
            "Unrest falls in Harbour",
            "Legitimacy down",
            "Corruption up"
        ])
    }
}
