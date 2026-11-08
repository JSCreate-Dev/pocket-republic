import SwiftUI
import PocketRepublicCore

/// The Pocket Gazette. It only reads events the core already recorded.
struct GazetteView: View {
    @EnvironmentObject private var game: Game

    private var days: [GazetteDay] { GazetteReading.days(in: game.state) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RepublicTheme.Space.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("The Pocket Gazette")
                        .font(.system(.title2, design: .serif).weight(.bold))
                    Text("Day \(game.state.day)")
                        .font(RepublicTheme.body(.subheadline))
                        .foregroundStyle(RepublicTheme.inkSoft)
                }
                if days.isEmpty {
                    Text("The press is quiet. Island events and city news land here after the day advances.")
                        .font(RepublicTheme.body())
                        .foregroundStyle(RepublicTheme.inkSoft)
                }
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
                        Text("Day \(day.day)")
                            .font(RepublicTheme.heading(.caption))
                            .foregroundStyle(RepublicTheme.turquoise)
                            .textCase(.uppercase)
                        ForEach(day.stories) { story in
                            storyCard(story)
                        }
                    }
                }
            }
            .padding(RepublicTheme.Space.md)
        }
        .background(RepublicTheme.cream)
        .foregroundStyle(RepublicTheme.ink)
    }

    private func storyCard(_ story: GazetteStory) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(story.tone.bar)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(story.headline)
                    .font(.system(.headline, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                if let result = story.result {
                    Text(result)
                        .font(RepublicTheme.body(.subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let because = story.because {
                    Text("Because \(because)")
                        .font(RepublicTheme.body(.caption))
                        .foregroundStyle(RepublicTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(RepublicTheme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 1, green: 251 / 255, blue: 242 / 255), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct GazetteDay: Identifiable {
    var day: Int32
    var stories: [GazetteStory]
    var id: Int32 { day }
}

struct GazetteStory: Identifiable {
    var id: String
    var headline: String
    var result: String?
    var because: String?
    var tone: GazetteTone
}

enum GazetteTone {
    case good, bad, weird, crisis, plain

    var bar: Color {
        switch self {
        case .good: return RepublicTheme.grass
        case .bad: return Color(red: 242 / 255, green: 164 / 255, blue: 122 / 255)
        case .weird: return RepublicTheme.turquoise
        case .crisis: return Color(red: 200 / 255, green: 50 / 255, blue: 30 / 255)
        case .plain: return RepublicTheme.sand
        }
    }
}

enum GazetteReading {
    static func days(in state: RepublicState) -> [GazetteDay] {
        let answered = Set(state.events.compactMap { event -> String? in
            guard event.kind == .islandEvent, let split = islandSplit(event) else { return nil }
            return split.headline
        })
        var byDay: [Int32: [GazetteStory]] = [:]
        var grouped: [GroupKey: [GameEvent]] = [:]
        for event in state.events {
            if event.kind == .islandEvent {
                if let story = islandStory(event, suppressing: answered) {
                    byDay[event.day, default: []].append(story)
                }
                continue
            }
            if event.kind == .agendaItemResolved, event.causes.contains(where: { $0.kind == .islandEvent }) {
                continue
            }
            let key = GroupKey(day: event.day, kind: event.kind, district: event.location.district?.raw ?? 255)
            grouped[key, default: []].append(event)
        }
        for (key, events) in grouped {
            byDay[key.day, default: []].append(ordinaryStory(events, in: state))
        }
        return byDay.keys.sorted(by: >).map { day in
            GazetteDay(day: day, stories: (byDay[day] ?? []).sorted { rank($0) < rank($1) })
        }
    }

    private static func rank(_ story: GazetteStory) -> Int {
        switch story.tone {
        case .crisis: return 0
        case .bad: return 1
        case .weird: return 2
        case .good: return 3
        case .plain: return 4
        }
    }

    private static func islandSplit(_ event: GameEvent) -> (headline: String, result: String)? {
        guard let detail = event.causes.first?.detail, !detail.isEmpty else { return nil }
        guard let range = detail.range(of: ". ") else { return nil }
        let headline = String(detail[..<range.lowerBound])
        let result = String(detail[range.upperBound...])
        guard !headline.isEmpty, !result.isEmpty else { return nil }
        return (headline, result)
    }

    private static func islandStory(_ event: GameEvent, suppressing answered: Set<String>) -> GazetteStory? {
        guard let detail = event.causes.first?.detail, !detail.isEmpty else { return nil }
        if let split = islandSplit(event) {
            return GazetteStory(
                id: "island-\(event.id.raw)",
                headline: split.headline,
                result: split.result,
                because: nil,
                tone: tone(headline: split.headline, result: split.result)
            )
        }
        if answered.contains(detail) { return nil }
        return GazetteStory(
            id: "island-\(event.id.raw)",
            headline: detail,
            result: "Still waiting on a choice.",
            because: nil,
            tone: tone(headline: detail, result: nil)
        )
    }

    private static func tone(headline: String, result: String?) -> GazetteTone {
        let match = EventDeck.all.first { spec in
            if let result, spec.options.contains(where: { $0.outcome == result }) { return true }
            if headline.localizedCaseInsensitiveContains(spec.title) { return true }
            let stem = spec.headline.replacingOccurrences(of: "{district}", with: "").trimmingCharacters(in: .whitespaces)
            let token = stem.split(separator: " ").prefix(3).joined(separator: " ")
            return !token.isEmpty && headline.contains(token)
        }
        switch match?.tone {
        case .good: return .good
        case .bad: return .bad
        case .weird: return .weird
        case nil: return .plain
        }
    }

    private static func ordinaryStory(_ events: [GameEvent], in state: RepublicState) -> GazetteStory {
        let event = events[0]
        let count = events.count
        let place = districtName(event.location.district, in: state).map { " in \($0)" } ?? ""
        let names = subjectNames(events, in: state)
        let headline: String
        let tone: GazetteTone
        switch event.kind {
        case .citizenHungry:
            headline = "\(count) \(count == 1 ? "family" : "families") went hungry\(place)"
            tone = .bad
        case .citizenUnemployed:
            headline = "\(count) \(count == 1 ? "worker lost a job" : "workers lost their jobs")\(place)"
            tone = .bad
        case .citizenEmployed:
            headline = "\(count) \(count == 1 ? "citizen found work" : "citizens found work")"
            tone = .good
        case .citizenTurnedToCrime:
            headline = names.map { "\($0) turned to crime\(place)" } ?? "Someone turned to crime\(place)"
            tone = .bad
        case .buildingConstructed:
            headline = "A new building opened\(place)"
            tone = .good
        case .buildingSiteStarted:
            headline = "Ground was broken\(place)"
            tone = .plain
        case .buildingAbandoned:
            headline = "A building was cleared\(place)"
            tone = .plain
        case .decreeIssued:
            let name = event.causes.first?.detail ?? "a decree"
            headline = "By decree: \(name)"
            tone = .plain
        case .crisisRaised:
            headline = "A crisis was raised\(place)"
            tone = .crisis
        case .crisisResolved:
            headline = "A crisis was resolved\(place)"
            tone = .good
        case .treasuryEmpty:
            headline = "The treasury is empty"
            tone = .crisis
        case .districtNeglected:
            headline = districtName(event.location.district, in: state).map { "\($0) feels forgotten" } ?? "A district feels forgotten"
            tone = .bad
        case .districtProtest:
            headline = "Crowds gather\(place)"
            tone = .crisis
        case .electionCalled:
            headline = "An election is called"
            tone = .crisis
        case .electionHeld:
            headline = "The republic has voted"
            tone = .plain
        case .factionDemandRaised:
            headline = "A faction asks for action"
            tone = .bad
        case .factionDemandIgnored:
            headline = "A faction feels ignored"
            tone = .bad
        case .foodShortage:
            headline = "Food ran short\(place)"
            tone = .bad
        case .migrationArrival:
            let arrivals = max(count, Int(event.magnitude))
            headline = arrivals == 1 ? "1 newcomer arrived" : "\(arrivals) newcomers arrived"
            tone = .plain
        case .migrationDeparture:
            headline = "Citizens left the island"
            tone = .bad
        case .agendaItemResolved:
            headline = "The council made a choice"
            tone = .plain
        case .dayAdvanced:
            headline = "The tax rate changed"
            tone = .plain
        case .islandEvent:
            headline = event.causes.first?.detail ?? "An island event"
            tone = .plain
        }
        let because = event.causes.compactMap(CauseSpeech.line).first
        let named = names.map { "\($0). " } ?? ""
        return GazetteStory(
            id: "\(event.kind.rawValue)-\(event.day)-\(event.location.district?.raw ?? 0)-\(events.map { String($0.id.raw) }.joined(separator: ","))",
            headline: headline,
            result: named.isEmpty ? nil : String(named.dropLast(2)),
            because: because,
            tone: tone
        )
    }

    private static func districtName(_ id: DistrictID?, in state: RepublicState) -> String? {
        guard let id else { return nil }
        let index = Int(id.raw)
        guard index >= 0, index < state.districts.count else { return nil }
        return state.districts[index].name
    }

    private static func subjectNames(_ events: [GameEvent], in state: RepublicState) -> String? {
        var names: [String] = []
        for event in events {
            for id in event.subjects {
                guard id.raw >= 0, Int(id.raw) < state.citizens.count else { continue }
                let citizen = state.citizens[Int(id.raw)]
                guard citizen.id == id else { continue }
                if !names.contains(citizen.name) { names.append(citizen.name) }
                if names.count == 3 { break }
            }
        }
        guard !names.isEmpty else { return nil }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return "\(names[0]) and \(names[1])" }
        return "\(names[0]), \(names[1]) and \(names[2])"
    }

    private struct GroupKey: Hashable {
        var day: Int32
        var kind: EventKind
        var district: UInt8
    }
}
