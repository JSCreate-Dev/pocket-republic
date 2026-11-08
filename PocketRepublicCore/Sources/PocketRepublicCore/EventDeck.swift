import Foundation

/// Good news, trouble, or something strange. The gazette uses the tone for its bar.
public enum EventTone: String, Codable, Sendable {
    case good, bad, weird
}

/// When an island event is allowed to be drawn. Gates are data, not a second
/// rules engine: `passes(in:)` only reads state.
public enum EventGate: Sendable, Equatable {
    case always
    case standing(BuildingKind)
    case treasuryAtLeast(Int64)
    case meanHappinessAtLeast(Int32)
    case corruptionAtLeast(Int32)
    case marketFoodAtLeast(Int32)
    case anyOf([EventGate])
    case allOf([EventGate])

    public func passes(in state: RepublicState) -> Bool {
        switch self {
        case .always:
            return true
        case .standing(let kind):
            return state.buildings.contains { $0.kind == kind && $0.isStanding(on: state.map) }
        case .treasuryAtLeast(let amount):
            return state.treasury >= amount
        case .meanHappinessAtLeast(let floor):
            let alive = state.citizens.filter(\.alive)
            guard !alive.isEmpty else { return false }
            let sum = alive.reduce(Int64(0)) { $0 + Int64($1.happiness) }
            return sum / Int64(alive.count) >= Int64(floor)
        case .corruptionAtLeast(let floor):
            return state.corruption >= floor
        case .marketFoodAtLeast(let amount):
            let stock = state.buildings.reduce(Int32(0)) { partial, building in
                guard building.kind == .market, building.isStanding(on: state.map) else { return partial }
                return partial + building.foodStore
            }
            return stock >= amount
        case .anyOf(let gates):
            return gates.contains { $0.passes(in: state) }
        case .allOf(let gates):
            return gates.allSatisfy { $0.passes(in: state) }
        }
    }
}

public struct IslandEventOption: Sendable, Equatable {
    public let id: Int32
    public let label: String
    public let outcome: String
    public let effect: AgendaEffect

    public init(id: Int32, label: String, outcome: String, effect: AgendaEffect) {
        self.id = id
        self.label = label
        self.outcome = outcome
        self.effect = effect
    }
}

/// One card in the island deck. Effects are ordinary `AgendaEffect`s, applied by
/// `RepublicState.apply` when the player answers or when the card lapses.
public struct IslandEventSpec: Sendable, Equatable {
    public let id: Int32
    public let tone: EventTone
    public let title: String
    public let flavor: String
    /// May contain `{district}`, filled in when the card is raised.
    public let headline: String
    public let why: String
    public let weight: Int32
    public let gate: EventGate
    public let options: [IslandEventOption]
    /// Option applied when the card expires unanswered. Its treasury cost is 0.
    public let ifIgnored: Int32

    public init(id: Int32, tone: EventTone, title: String, flavor: String, headline: String,
                why: String, weight: Int32, gate: EventGate, options: [IslandEventOption],
                ifIgnored: Int32) {
        self.id = id
        self.tone = tone
        self.title = title
        self.flavor = flavor
        self.headline = headline
        self.why = why
        self.weight = weight
        self.gate = gate
        self.options = options
        self.ifIgnored = ifIgnored
    }
}

/// The seeded draw for island events, stored on the republic so a save resumes
/// the same stream. It is not the wellbeing RNG: adding a roll here does not
/// move happiness, crime, or the decree rotation.
public struct IslandEventLog: Codable, Sendable, Equatable {
    public var rng: SeededRNG
    public var lastRaisedDay: Int32
    /// Indexed by `IslandEventSpec.id`. `-9999` means that card has never been raised.
    public var lastFiredDay: [Int32]
    public var recentIDs: [Int32]

    public init(rng: SeededRNG, lastRaisedDay: Int32, lastFiredDay: [Int32], recentIDs: [Int32]) {
        self.rng = rng
        self.lastRaisedDay = lastRaisedDay
        self.lastFiredDay = lastFiredDay
        self.recentIDs = recentIDs
    }

    public static func fresh(worldSeed: UInt64, count: Int) -> IslandEventLog {
        let mixed = worldSeed ^ (EventDeck.streamSalt &* 0x9E37_79B9_7F4A_7C15)
        return IslandEventLog(
            rng: SeededRNG(seed: mixed),
            lastRaisedDay: -9999,
            lastFiredDay: Array(repeating: -9999, count: max(0, count)),
            recentIDs: [])
    }
}

/// A short, fixed deck. Section 5 of the design describes fourteen cards and a
/// set of rare one-offs; this slice is the six that fit the effects the core
/// already applies, plus food leaving the island. There is no second decision
/// framework and no model call.
public enum EventDeck {
    /// Mixes with `worldSeed` to open the event stream. Stable across versions.
    public static let streamSalt: UInt64 = 0x6576_656e_7473_0001

    public static let all: [IslandEventSpec] = makeDeck()

    public static func spec(_ id: Int32) -> IslandEventSpec? {
        guard id >= 0, Int(id) < all.count, all[Int(id)].id == id else {
            return all.first { $0.id == id }
        }
        return all[Int(id)]
    }
}

enum IslandEvents {
    /// Roll today's card, if the quiet rules and the deck allow one.
    /// Always consumes the chance roll (when the percent is above zero) so two
    /// games that share a seed stay locked together.
    static func update(_ s: inout RepublicState) {
        let count = EventDeck.all.count
        var log = s.islandEventLog ?? .fresh(worldSeed: s.worldSeed, count: count)
        if log.lastFiredDay.count < count {
            log.lastFiredDay.append(contentsOf: Array(repeating: -9999, count: count - log.lastFiredDay.count))
        }
        let pacing = s.config.activeEventPacing
        let fires = log.rng.chance(Int(max(0, pacing.chancePercent)))
        let quiet = log.lastRaisedDay >= 0 && s.day - log.lastRaisedDay <= max(0, pacing.quietDays)
        let afterCrisis = crisisQuiet(s, days: max(0, pacing.postCrisisQuietDays))
        let already = s.agenda.contains { $0.islandEventID != nil }
        if fires, !quiet, !afterCrisis, !already, let spec = pick(&log, in: s, pacing: pacing) {
            post(spec, to: &s, pacing: pacing)
            log.lastRaisedDay = s.day
            let index = Int(spec.id)
            if index >= 0, index < log.lastFiredDay.count { log.lastFiredDay[index] = s.day }
            log.recentIDs.append(spec.id)
            let cap = Int(max(0, pacing.recentExclusion))
            if cap == 0 {
                log.recentIDs.removeAll()
            } else if log.recentIDs.count > cap {
                log.recentIDs.removeFirst(log.recentIDs.count - cap)
            }
        }
        s.islandEventLog = log
    }

    /// The unanswered card takes its ignore option. That option does not spend
    /// treasury; a costly choice has to be pressed on purpose.
    static func lapse(_ s: inout RepublicState, _ item: AgendaItem) {
        let ignoreID = item.islandEvent?.ifIgnored
        let option = item.options.first { $0.id == ignoreID } ?? item.options.last
        guard let option, option.effect.treasuryCost == 0 else { return }
        s.apply(option.effect, at: item.location)
        recordOutcome(&s, item: item, option: option)
    }

    static func recordOutcome(_ s: inout RepublicState, item: AgendaItem, option: AgendaOption) {
        let outcome = item.islandEvent?.options.first { $0.id == option.id }?.outcome ?? option.label
        let headline = item.causes.dropFirst().first?.detail ?? item.causes.first?.detail ?? item.islandEvent?.title ?? "An island event"
        s.emit(.islandEvent,
               location: item.location,
               causes: [CauseFactor(.islandEvent, value: option.id, detail: "\(headline). \(outcome)")],
               magnitude: option.id)
    }

    static func post(_ spec: IslandEventSpec, to s: inout RepublicState, pacing: EventPacing) {
        let venue = venue(in: s)
        let headline = spec.headline.replacingOccurrences(of: "{district}", with: venue?.name ?? "the island")
        let location = EventLocation(district: venue?.id)
        s.agenda.append(AgendaItem(
            id: AgendaGenerator.nextID(&s),
            kind: .advisoryTradeoff,
            tier: .advisory,
            raisedOnDay: s.day,
            expiresOnDay: s.day + max(1, pacing.expiryDays),
            faction: nil,
            location: location,
            causes: [
                CauseFactor(.islandEvent, value: s.day, detail: spec.flavor),
                CauseFactor(.islandEvent, value: spec.id, detail: headline)
            ],
            options: spec.options.map { AgendaOption(id: $0.id, label: $0.label, effect: $0.effect) },
            salience: 60 + spec.weight,
            islandEventID: spec.id))
        s.emit(.islandEvent,
               location: location,
               causes: [CauseFactor(.islandEvent, value: spec.id, detail: headline)],
               magnitude: spec.id)
    }

    private static func pick(_ log: inout IslandEventLog, in s: RepublicState,
                             pacing: EventPacing) -> IslandEventSpec? {
        let recentCap = Int(max(0, pacing.recentExclusion))
        let recent = recentCap == 0 ? [] : Array(log.recentIDs.suffix(recentCap))
        let lastTwo = log.recentIDs.suffix(2)
        let soothe = lastTwo.count == 2 && lastTwo.allSatisfy { EventDeck.spec($0)?.tone == .bad }
        let bonus = max(1, pacing.toneBalanceMultiplier)
        var weighted: [(IslandEventSpec, Int32)] = []
        for spec in EventDeck.all.sorted(by: { $0.id < $1.id }) {
            guard spec.gate.passes(in: s), spec.weight > 0 else { continue }
            if recent.contains(spec.id) { continue }
            let index = Int(spec.id)
            if index >= 0, index < log.lastFiredDay.count {
                let fired = log.lastFiredDay[index]
                if fired >= 0 && s.day - fired <= max(0, pacing.repeatDays) { continue }
            }
            var weight = spec.weight
            if soothe, spec.tone != .bad { weight *= bonus }
            if weight > 0 { weighted.append((spec, weight)) }
        }
        let total = weighted.reduce(Int32(0)) { $0 + $1.1 }
        guard total > 0 else { return nil }
        let roll = Int32(log.rng.int(0...Int(total - 1)))
        var cursor: Int32 = 0
        for (spec, weight) in weighted {
            cursor += weight
            if roll < cursor { return spec }
        }
        return weighted.last?.0
    }

    private static func crisisQuiet(_ s: RepublicState, days: Int32) -> Bool {
        guard days > 0 else { return false }
        return s.events.contains { $0.kind == .crisisResolved && s.day - $0.day <= days }
    }

    private static func venue(in s: RepublicState) -> District? {
        let populated = s.districts.filter { $0.population > 0 }
        if let best = populated.max(by: { lhs, rhs in
            if lhs.population != rhs.population { return lhs.population < rhs.population }
            return lhs.id.raw > rhs.id.raw
        }) {
            return best
        }
        return s.districts.min { $0.id.raw < $1.id.raw }
    }
}

private func makeDeck() -> [IslandEventSpec] {
    func built(_ body: (inout AgendaEffect) -> Void) -> AgendaEffect {
        var effect = AgendaEffect()
        body(&effect)
        return effect
    }

    let carnivalFund = built {
        $0.treasuryCost = 150
        $0.districtUnrest = -8
        $0.favor(.merchants, 4)
        $0.favor(.labourers, 3)
    }
    let celebrityHost = built {
        $0.treasuryCost = 250
        $0.legitimacy = 5
        $0.favor(.officials, 6)
    }
    let raid = built {
        $0.treasuryCost = 100
        $0.corruption = -6
        $0.favor(.merchants, -4)
    }
    let cut = built {
        $0.treasuryGain = 200
        $0.corruption = 8
        $0.legitimacy = -3
    }
    let slip = built { $0.corruption = 2 }
    let shareCatch = built {
        $0.foodImport = 120
        $0.favor(.landless, 6)
    }
    let sellCatch = built {
        $0.treasuryGain = 180
        $0.favor(.merchants, 4)
    }
    let acceptPurse = built {
        $0.treasuryGain = 250
        $0.favor(.officials, -5)
    }
    let nameStreet = built {
        $0.treasuryGain = 150
        $0.legitimacy = 2
    }
    let sellHarvest = built {
        $0.foodExport = 80
        $0.treasuryGain = 300
        $0.favor(.merchants, 5)
    }
    let keepHarvest = built { $0.favor(.labourers, 3) }
    let nothing = AgendaEffect()

    return [
        IslandEventSpec(
            id: 0, tone: .good, title: "Carnival",
            flavor: "Drums on the square, and every stall stays open late.",
            headline: "Carnival fills the streets of {district}",
            why: "A market is open and the island is in a good mood.",
            weight: 4,
            gate: .allOf([.standing(.market), .meanHappinessAtLeast(50)]),
            options: [
                IslandEventOption(id: 0, label: "Fund the lanterns (−150, calmer streets)",
                                  outcome: "The treasury paid for the lanterns", effect: carnivalFund),
                IslandEventOption(id: 1, label: "Let the day pass",
                                  outcome: "The square stayed quiet", effect: nothing)
            ],
            ifIgnored: 1),
        IslandEventSpec(
            id: 1, tone: .weird, title: "Celebrity visit",
            flavor: "The harbour has never seen so many pressed shirts.",
            headline: "A famous crooner drops anchor off {district}",
            why: "The treasury can afford a gala.",
            weight: 2,
            gate: .treasuryAtLeast(400),
            options: [
                IslandEventOption(id: 0, label: "Host the gala (−250, legitimacy up)",
                                  outcome: "The palace hosted a gala", effect: celebrityHost),
                IslandEventOption(id: 1, label: "Decline politely",
                                  outcome: "The crooner sailed on", effect: nothing)
            ],
            ifIgnored: 1),
        IslandEventSpec(
            id: 2, tone: .bad, title: "Smuggler ring",
            flavor: "Night boats, no flags, and a customs ledger with a missing page.",
            headline: "Smugglers are running rum through {district}",
            why: "A dock is open, or corruption has somewhere to hide.",
            weight: 3,
            gate: .anyOf([.standing(.dock), .corruptionAtLeast(30)]),
            options: [
                IslandEventOption(id: 0, label: "Raid the cove (−100, corruption down)",
                                  outcome: "Constables seized the boats", effect: raid),
                IslandEventOption(id: 1, label: "Take a cut (+200, corruption up)",
                                  outcome: "The customs house took its share", effect: cut),
                IslandEventOption(id: 2, label: "Let them slip away",
                                  outcome: "The lanterns went dark and the boats were gone", effect: slip)
            ],
            ifIgnored: 2),
        IslandEventSpec(
            id: 3, tone: .good, title: "Fishing bonanza",
            flavor: "The morning boats can barely clear the water.",
            headline: "Nets come up full off {district}",
            why: "The dock and a market are both open.",
            weight: 3,
            gate: .allOf([.standing(.dock), .standing(.market)]),
            options: [
                IslandEventOption(id: 0, label: "Share the catch (food for the poor)",
                                  outcome: "The catch was given away on the quay", effect: shareCatch),
                IslandEventOption(id: 1, label: "Sell the catch (+180)",
                                  outcome: "The catch was sold before noon", effect: sellCatch),
                IslandEventOption(id: 2, label: "Leave it with the boats",
                                  outcome: "The boats kept what they caught", effect: nothing)
            ],
            ifIgnored: 2),
        IslandEventSpec(
            id: 4, tone: .good, title: "Generous expat",
            flavor: "Foreign ink, a fat purse, and a request for a street with their name.",
            headline: "An islander abroad sends money home",
            why: "The letter arrived with no strings the treasury can see.",
            weight: 2,
            gate: .always,
            options: [
                IslandEventOption(id: 0, label: "Accept the purse (+250, officials sour)",
                                  outcome: "The purse went to the treasury, and the clerks scowled", effect: acceptPurse),
                IslandEventOption(id: 1, label: "Name a street after them (+150)",
                                  outcome: "A street took the new name, and a smaller gift was kept", effect: nameStreet),
                IslandEventOption(id: 2, label: "Send the letter back",
                                  outcome: "The letter went back unopened", effect: nothing)
            ],
            ifIgnored: 2),
        IslandEventSpec(
            id: 5, tone: .good, title: "Foreign trade offer",
            flavor: "The captain will pay in coin and sail before dusk.",
            headline: "A foreign freighter offers coin for the harvest",
            why: "The dock is open and the markets are holding a surplus.",
            weight: 4,
            gate: .allOf([.standing(.dock), .marketFoodAtLeast(80)]),
            options: [
                IslandEventOption(id: 0, label: "Sell eighty crates (+300, markets lose food)",
                                  outcome: "Eighty crates left on the freighter", effect: sellHarvest),
                IslandEventOption(id: 1, label: "Keep the harvest",
                                  outcome: "The harvest stayed in the markets", effect: keepHarvest)
            ],
            ifIgnored: 1)
    ]
}
