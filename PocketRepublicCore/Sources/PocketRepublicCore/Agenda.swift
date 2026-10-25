import Foundation

/// How much the player is allowed to ignore an item.
public enum AgendaTier: UInt8, Codable, Sendable, Comparable {
    /// Blocks the next day-advance until answered. Rare on purpose.
    case crisis = 0
    /// A faction wants something. Ignoring it costs favor, never the run.
    case demand = 1
    /// An advisor framing a drifting number as a choice while it is still cheap.
    case advisory = 2
    /// Player-initiated, always available, never expires.
    case decree = 3

    public static func < (a: AgendaTier, b: AgendaTier) -> Bool { a.rawValue < b.rawValue }
}

public enum AgendaKind: String, Codable, Sendable {
    case factionDemand
    case advisoryTradeoff
    case decree
    case buildingCommission
    case election
}

/// What an option does, expressed as data. Resolution applies this generically,
/// so adding decision content never means adding an arm to a switch in the
/// engine -- which is what lets the decision stream get wide enough to offer
/// something every single tick without the tick code growing with it.
public struct AgendaEffect: Codable, Sendable, Equatable {
    public var treasuryCost: Int64 = 0
    public var treasuryGain: Int64 = 0
    public var legitimacy: Int32 = 0
    public var corruption: Int32 = 0
    public var incomeTaxDelta: Int32 = 0
    public var businessTaxDelta: Int32 = 0
    public var civicWageDelta: Int64 = 0
    public var districtUnrest: Int32 = 0
    public var districtNeglectReset: Bool = false
    public var foodImport: Int32 = 0
    /// Parallel arrays, not a dictionary keyed by the enum: Codable encodes such a
    /// dictionary as a flat array in iteration order, which already cost us a
    /// non-canonical save file once.
    public var favorFactions: [FactionKind] = []
    public var favorDeltas: [Int32] = []
    /// Applied to `location.building`, for placement-time commissions.
    public var operatingMode: OperatingMode? = nil

    public init() {}

    public mutating func favor(_ f: FactionKind, _ d: Int32) {
        favorFactions.append(f)
        favorDeltas.append(d)
    }
}

public struct AgendaOption: Codable, Sendable, Identifiable, Equatable {
    public let id: Int32
    public let label: String
    public let effect: AgendaEffect

    public init(id: Int32, label: String, effect: AgendaEffect) {
        self.id = id
        self.label = label
        self.effect = effect
    }
}

/// One actionable thing on screen. The UI renders these; the engine guarantees
/// the list is never empty at the end of a tick.
public struct AgendaItem: Codable, Sendable, Identifiable, Equatable {
    public let id: DecisionID
    public let kind: AgendaKind
    public let tier: AgendaTier
    public let raisedOnDay: Int32
    /// nil = never expires (decrees are standing offers).
    public let expiresOnDay: Int32?
    public let faction: FactionKind?
    public let location: EventLocation
    public let causes: [CauseFactor]
    public let options: [AgendaOption]
    /// Cost in faction favor of letting this lapse. Zero for advisories and decrees.
    public let ignoreCost: Int32
    /// Ranking weight, derived from simulation state. Higher = more pressing.
    public let salience: Int32

    public init(id: DecisionID, kind: AgendaKind, tier: AgendaTier, raisedOnDay: Int32,
                expiresOnDay: Int32?, faction: FactionKind?, location: EventLocation,
                causes: [CauseFactor], options: [AgendaOption],
                ignoreCost: Int32 = 0, salience: Int32 = 0) {
        self.id = id
        self.kind = kind
        self.tier = tier
        self.raisedOnDay = raisedOnDay
        self.expiresOnDay = expiresOnDay
        self.faction = faction
        self.location = location
        self.causes = causes
        self.options = options
        self.ignoreCost = ignoreCost
        self.salience = salience
    }

    public func isLive(on day: Int32) -> Bool {
        guard let e = expiresOnDay else { return true }
        return day <= e
    }
}
