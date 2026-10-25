import Foundation

/// Headline templates, kept as data so a later localization pass can replace the table.
public struct HeadlineTemplate: Sendable, Equatable {
    public let singular: String
    public let plural: String

    public init(singular: String, plural: String) {
        self.singular = singular
        self.plural = plural
    }
}

public enum HeadlineTable {
    public static let templates: [EventKind: HeadlineTemplate] = [
        .citizenHungry: .init(singular: "1 family went hungry in {district}",
                              plural: "{n} families went hungry in {district}"),
        .foodShortage: .init(singular: "{market} ran out of food",
                             plural: "{market} ran out of food"),
        .citizenUnemployed: .init(singular: "1 worker lost their job in {district}",
                                  plural: "{n} workers lost their jobs in {district}"),
        .citizenEmployed: .init(singular: "1 citizen found work",
                                plural: "{n} citizens found work"),
        .citizenTurnedToCrime: .init(singular: "{name} turned to crime in {district}",
                                     plural: "{n} citizens turned to crime in {district}"),
        .districtNeglected: .init(singular: "{district} feels forgotten: no {service} for {days} days",
                                  plural: "{district} feels forgotten: no {service} for {days} days"),
        .districtProtest: .init(singular: "Crowds gather in {district}",
                                plural: "Crowds gather in {district}"),
        .buildingConstructed: .init(singular: "A new {building} opens in {district}",
                                    plural: "{n} new {building} open in {district}"),
        .buildingAbandoned: .init(singular: "The {building} in {district} stands empty",
                                  plural: "{n} buildings in {district} stand empty"),
        .migrationArrival: .init(singular: "1 newcomer arrived",
                                 plural: "{n} newcomers arrived"),
        .migrationDeparture: .init(singular: "1 citizen left the island",
                                   plural: "{n} citizens left the island"),
        .factionDemandRaised: .init(singular: "The {faction} demand action on {concern}",
                                    plural: "The {faction} demand action on {concern}"),
        .factionDemandIgnored: .init(singular: "The {faction} feel ignored",
                                     plural: "The {faction} feel ignored"),
        .decreeIssued: .init(singular: "By decree: {decree}",
                             plural: "By decree: {decree}"),
        .crisisRaised: .init(singular: "Crisis in {district}: {kind}",
                             plural: "Crisis in {district}: {kind}"),
        .crisisResolved: .init(singular: "{district} crisis resolved",
                               plural: "{district} crisis resolved"),
        .treasuryEmpty: .init(singular: "The treasury is empty",
                              plural: "The treasury is empty"),
        .electionCalled: .init(singular: "An election is called",
                               plural: "An election is called"),
        .electionHeld: .init(singular: "The republic has voted",
                             plural: "The republic has voted"),
        .agendaItemResolved: .init(singular: "The council settled a matter",
                                   plural: "The council settled {n} matters"),
        .dayAdvanced: .init(singular: "The day passed",
                            plural: "The day passed")
    ]
}

public enum StoryWeight: Int, Sendable, Equatable, Comparable {
    case crisis = 0
    case decision = 1
    case bad = 2
    case good = 3
    case routine = 4

    public static func < (lhs: StoryWeight, rhs: StoryWeight) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct GazetteNames: Sendable, Equatable {
    public var districts: [UInt8: String]
    public var citizens: [Int32: String]
    public var buildings: [Int32: String]

    public init(districts: [UInt8: String] = [:], citizens: [Int32: String] = [:],
                buildings: [Int32: String] = [:]) {
        self.districts = districts
        self.citizens = citizens
        self.buildings = buildings
    }

    public static func from(_ state: RepublicState) -> GazetteNames {
        var names = GazetteNames()
        for district in state.districts { names.districts[district.id.raw] = district.name }
        for citizen in state.citizens { names.citizens[citizen.id.raw] = citizen.name }
        for building in state.buildings { names.buildings[building.id.raw] = building.kind.spokenName }
        return names
    }

    func district(of location: EventLocation) -> (name: String, known: Bool) {
        guard let id = location.district, let name = districts[id.raw], !name.isEmpty else {
            return ("the island", false)
        }
        return (name, true)
    }

    func citizen(_ id: CitizenID) -> String? { citizens[id.raw] }

    func building(_ id: BuildingID?) -> String {
        guard let id, let name = buildings[id.raw], !name.isEmpty else { return "building" }
        return name
    }
}

public extension BuildingKind {
    /// Lowercase name used in gazette headlines.
    var spokenName: String {
        switch self {
        case .townHall: return "town hall"
        case .house: return "house"
        case .farm: return "farm"
        case .market: return "market"
        case .clinic: return "clinic"
        case .school: return "school"
        case .police: return "police station"
        case .workshop: return "workshop"
        case .dock: return "dock"
        }
    }
}

public struct GazetteStory: Sendable, Equatable, Identifiable {
    public let id: String
    public let day: Int32
    public let kind: EventKind
    public let weight: StoryWeight
    public let headline: String
    public let because: String?
    public let names: [String]
    public let trend: String?
    public let location: EventLocation
    public let eventIDs: [EventID]
    public let count: Int

    public var previewNames: [String] { Array(names.prefix(3)) }
    public var othersCount: Int { max(0, names.count - 3) }
}

public struct GazetteEdition: Sendable, Equatable, Identifiable {
    public var id: Int32 { day }
    public let day: Int32
    public let masthead: String
    public let stories: [GazetteStory]
    public let routineLine: String?
}

/// Groups the event log into a newspaper. Same kind, same district, same day.
public enum EventGazette {
    public static func editions(events: [GameEvent], names: GazetteNames) -> [GazetteEdition] {
        let buckets = Dictionary(grouping: events) { key(for: $0) }
        let days = Set(events.map(\.day)).sorted(by: >)
        return days.compactMap { day in
            edition(day: day, buckets: buckets, names: names)
        }
    }

    public static func nameLine(_ names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        let shown = Array(names.prefix(3))
        let extra = names.count - shown.count
        if shown.count == 1 && extra == 0 { return shown[0] }
        if extra == 0 {
            guard let last = shown.last else { return nil }
            if shown.count == 2 { return "\(shown[0]) and \(last)" }
            return shown.dropLast().joined(separator: ", ") + " and " + last
        }
        return shown.joined(separator: ", ") + " and \(extra) " + (extra == 1 ? "other" : "others")
    }

    public static func ordinal(_ n: Int) -> String {
        let mod100 = n % 100
        if (11...13).contains(mod100) { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }

    private struct GroupKey: Hashable {
        let day: Int32
        let kind: EventKind
        let district: UInt8?
    }

    private static func key(for event: GameEvent) -> GroupKey {
        GroupKey(day: event.day, kind: event.kind, district: event.location.district?.raw)
    }

    private static func edition(day: Int32, buckets: [GroupKey: [GameEvent]],
                                names: GazetteNames) -> GazetteEdition? {
        let keys = buckets.keys.filter { $0.day == day }
        var stories: [GazetteStory] = []
        var hires = 0
        var houses = 0
        for groupKey in keys {
            let group = (buckets[groupKey] ?? []).sorted { $0.id < $1.id }
            guard !group.isEmpty else { continue }
            if groupKey.kind == .dayAdvanced { continue }
            if groupKey.kind == .citizenEmployed {
                hires += count(of: group)
                continue
            }
            if groupKey.kind == .buildingConstructed && group.allSatisfy({ names.building($0.location.building) == "house" }) {
                houses += group.count
                continue
            }
            if let story = story(groupKey: groupKey, events: group, buckets: buckets, names: names) {
                stories.append(story)
            }
        }
        stories.sort { lhs, rhs in
            if lhs.weight != rhs.weight { return lhs.weight < rhs.weight }
            return (lhs.eventIDs.first ?? EventID(0)) < (rhs.eventIDs.first ?? EventID(0))
        }
        let routine = routineLine(hires: hires, houses: houses)
        guard !stories.isEmpty || routine != nil else { return nil }
        return GazetteEdition(day: day, masthead: "Day \(day) · The Pocket Gazette",
                              stories: stories, routineLine: routine)
    }

    private static func routineLine(hires: Int, houses: Int) -> String? {
        var parts: [String] = []
        if hires == 1 { parts.append("1 citizen found work") }
        else if hires > 1 { parts.append("\(hires) citizens found work") }
        if houses == 1 { parts.append("1 new house built") }
        else if houses > 1 { parts.append("\(houses) new houses built") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func story(groupKey: GroupKey, events: [GameEvent],
                              buckets: [GroupKey: [GameEvent]], names: GazetteNames) -> GazetteStory? {
        let kind = groupKey.kind
        let weight = weight(for: kind)
        guard weight != .routine else { return nil }
        let n = count(of: events)
        let people = subjectNames(in: events, names: names)
        let place = names.district(of: events[0].location)
        let causes = events.flatMap(\.causes)
        let headline = headline(kind: kind, count: n, events: events, names: names, people: people, place: place)
        let because = CauseCopy.why(causes)
        let trend = trendLine(day: groupKey.day, kind: kind, district: groupKey.district,
                              causes: causes, buckets: buckets)
        let districtPart = groupKey.district.map(String.init) ?? "island"
        return GazetteStory(
            id: "\(groupKey.day)-\(kind.rawValue)-\(districtPart)",
            day: groupKey.day,
            kind: kind,
            weight: weight,
            headline: headline,
            because: because,
            names: people,
            trend: trend,
            location: mergedLocation(events),
            eventIDs: events.map(\.id),
            count: n
        )
    }

    private static func count(of events: [GameEvent]) -> Int {
        var seen = Set<Int32>()
        var people = 0
        for event in events {
            for subject in event.subjects where seen.insert(subject.raw).inserted { people += 1 }
        }
        return people > 0 ? people : events.count
    }

    private static func subjectNames(in events: [GameEvent], names: GazetteNames) -> [String] {
        var seen = Set<Int32>()
        var result: [String] = []
        for event in events {
            for subject in event.subjects where seen.insert(subject.raw).inserted {
                if let name = names.citizen(subject), !name.isEmpty { result.append(name) }
            }
        }
        return result
    }

    private static func mergedLocation(_ events: [GameEvent]) -> EventLocation {
        let first = events[0].location
        let tile = events.compactMap(\.location.tile).first ?? first.tile
        let building = events.compactMap(\.location.building).first ?? first.building
        return EventLocation(district: first.district, building: building, tile: tile)
    }

    private static func weight(for kind: EventKind) -> StoryWeight {
        switch kind {
        case .crisisRaised, .districtProtest, .treasuryEmpty:
            return .crisis
        case .crisisResolved, .electionCalled, .electionHeld, .decreeIssued,
             .agendaItemResolved, .factionDemandRaised:
            return .decision
        case .citizenHungry, .foodShortage, .citizenUnemployed, .citizenTurnedToCrime,
             .districtNeglected, .buildingAbandoned, .migrationDeparture, .factionDemandIgnored:
            return .bad
        case .citizenEmployed, .buildingConstructed, .migrationArrival:
            return .good
        case .dayAdvanced:
            return .routine
        }
    }

    private static func trendLine(day: Int32, kind: EventKind, district: UInt8?,
                                  causes: [CauseFactor], buckets: [GroupKey: [GameEvent]]) -> String? {
        var run = 1
        var cursor = day - 1
        while buckets[GroupKey(day: cursor, kind: kind, district: district)] != nil {
            run += 1
            cursor -= 1
        }
        let hungry = causes.compactMap { cause -> Int? in
            guard cause.kind == .foodShortage,
                  cause.detail == "days hungry" || cause.detail.isEmpty else { return nil }
            return Int(cause.value)
        }.max() ?? 0
        let days = max(run, hungry)
        guard days >= 2 else { return nil }
        return "\(ordinal(days)) day running"
    }

    private static func headline(kind: EventKind, count: Int, events: [GameEvent],
                                 names: GazetteNames, people: [String],
                                 place: (name: String, known: Bool)) -> String {
        let district = place.known ? place.name : "the island"
        let n = count
        switch kind {
        case .citizenHungry:
            if place.known {
                return n == 1 ? "1 family went hungry in \(district)" : "\(n) families went hungry in \(district)"
            }
            return n == 1 ? "1 family went hungry" : "\(n) families went hungry"
        case .foodShortage:
            return "\(names.building(events[0].location.building)) ran out of food"
        case .citizenUnemployed:
            let noun = n == 1 ? "1 worker lost their job" : "\(n) workers lost their jobs"
            return place.known ? "\(noun) in \(district)" : noun
        case .citizenEmployed:
            return n == 1 ? "1 citizen found work" : "\(n) citizens found work"
        case .citizenTurnedToCrime:
            if n == 1, let name = people.first {
                return place.known ? "\(name) turned to crime in \(district)" : "\(name) turned to crime"
            }
            return place.known ? "\(n) citizens turned to crime in \(district)" : "\(n) citizens turned to crime"
        case .districtNeglected:
            let service = serviceName(in: events.flatMap(\.causes))
            let days = events.flatMap(\.causes).first { $0.kind == .districtNeglect }?.value ?? 0
            let whereText = place.known ? district : "The island"
            return "\(whereText) feels forgotten: no \(service) for \(days) days"
        case .districtProtest:
            return place.known ? "Crowds gather in \(district)" : "Crowds gather"
        case .buildingConstructed:
            let word = buildingWord(in: events, names: names)
            if n == 1 { return place.known ? "A new \(word) opens in \(district)" : "A new \(word) opens" }
            let plural = word == "building" ? "buildings" : "\(word)s"
            return place.known ? "\(n) new \(plural) open in \(district)" : "\(n) new \(plural) open"
        case .buildingAbandoned:
            if n == 1 {
                let word = buildingWord(in: events, names: names)
                return place.known ? "The \(word) in \(district) stands empty" : "The \(word) stands empty"
            }
            return place.known ? "\(n) buildings in \(district) stand empty" : "\(n) buildings stand empty"
        case .migrationArrival:
            return n == 1 ? "1 newcomer arrived" : "\(n) newcomers arrived"
        case .migrationDeparture:
            return n == 1 ? "1 citizen left the island" : "\(n) citizens left the island"
        case .factionDemandRaised:
            let faction = factionName(in: events) ?? "people"
            let concern = concernName(in: events)
            return "The \(faction) demand action on \(concern)"
        case .factionDemandIgnored:
            let faction = factionName(in: events) ?? "people"
            return "The \(faction) feel ignored"
        case .decreeIssued:
            let title = events.flatMap(\.causes).first {
                $0.kind == .policyChange && !$0.detail.isEmpty && !CauseCopy.knownDetails.contains($0.detail)
                    && !CauseCopy.factionNames.contains($0.detail)
            }?.detail ?? "a new order"
            return "By decree: \(title)"
        case .crisisRaised:
            let label = crisisLabel(in: events)
            return place.known ? "Crisis in \(district): \(label)" : "Crisis: \(label)"
        case .crisisResolved:
            return place.known ? "\(district) crisis resolved" : "The crisis is resolved"
        case .treasuryEmpty:
            return "The treasury is empty"
        case .electionCalled:
            return "An election is called"
        case .electionHeld:
            return "The republic has voted"
        case .agendaItemResolved:
            return n == 1 ? "The council settled a matter" : "The council settled \(n) matters"
        case .dayAdvanced:
            return "The day passed"
        }
    }

    private static func buildingWord(in events: [GameEvent], names: GazetteNames) -> String {
        let words = Set(events.map { names.building($0.location.building) })
        if words.count == 1, let word = words.first { return word }
        return "building"
    }

    private static func serviceName(in causes: [CauseFactor]) -> String {
        if causes.contains(where: { $0.kind == .noMarketAccess }) { return "market" }
        if causes.contains(where: { $0.kind == .noClinicAccess }) { return "clinic" }
        if causes.contains(where: { $0.kind == .noPoliceAccess }) { return "police" }
        return "services"
    }

    private static func factionName(in events: [GameEvent]) -> String? {
        events.flatMap(\.causes).map(\.detail).first { CauseCopy.factionNames.contains($0) }
    }

    private static func concernName(in events: [GameEvent]) -> String {
        guard let kind = events.flatMap(\.causes).first?.kind else { return "the city" }
        switch kind {
        case .foodShortage: return "food"
        case .unemployment: return "work"
        case .taxBurden: return "taxes"
        case .corruption: return "corruption"
        case .noPoliceAccess: return "policing"
        case .noMarketAccess: return "markets"
        case .noClinicAccess: return "clinics"
        case .districtNeglect: return "neglect"
        case .poverty: return "poverty"
        case .treasuryDeficit: return "the treasury"
        case .policyChange: return "policy"
        }
    }

    private static func crisisLabel(in events: [GameEvent]) -> String {
        let causes = events.flatMap(\.causes)
        if causes.contains(where: { $0.kind == .foodShortage && $0.detail.contains("citizens hungry") }) {
            return "famine"
        }
        if causes.contains(where: { $0.kind == .corruption }) { return "a corruption scandal" }
        if causes.contains(where: { $0.kind == .districtNeglect }) { return "an uprising" }
        if causes.contains(where: { $0.kind == .treasuryDeficit }) { return "bankruptcy" }
        if causes.contains(where: { $0.kind == .foodShortage }) { return "famine" }
        return "trouble"
    }
}
