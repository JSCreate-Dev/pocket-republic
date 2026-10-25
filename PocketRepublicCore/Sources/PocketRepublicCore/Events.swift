import Foundation

public enum EventKind: String, Codable, Sendable {
    case dayAdvanced
    case buildingConstructed
    case buildingAbandoned
    case citizenHungry
    case citizenEmployed
    case citizenUnemployed
    case citizenTurnedToCrime
    case districtNeglected
    case districtProtest
    case foodShortage
    case treasuryEmpty
    case crisisRaised
    case crisisResolved
    case migrationArrival
    case migrationDeparture
    case factionDemandRaised
    case factionDemandIgnored
    case agendaItemResolved
    case decreeIssued
    case electionCalled
    case electionHeld
}

/// Where an event happened. Required for anything district-scoped: "unrest rose" is
/// untunable, "unrest rose in East Docks because no market is within range" is not.
public struct EventLocation: Codable, Sendable, Equatable {
    public var district: DistrictID?
    public var building: BuildingID?
    public var tile: TileIndex?

    public init(district: DistrictID? = nil, building: BuildingID? = nil, tile: TileIndex? = nil) {
        self.district = district
        self.building = building
        self.tile = tile
    }
}

public enum CauseKind: String, Codable, Sendable {
    case noMarketAccess, noClinicAccess, noPoliceAccess
    case foodShortage, unemployment, taxBurden, corruption
    case treasuryDeficit, districtNeglect, poverty, policyChange
}

/// One contributing factor with the actual number behind it, so a crisis can be
/// explained and tuned rather than guessed at.
public struct CauseFactor: Codable, Sendable, Equatable {
    public let kind: CauseKind
    public let value: Int32
    public let detail: String

    public init(_ kind: CauseKind, value: Int32, detail: String = "") {
        self.kind = kind
        self.value = value
        self.detail = detail
    }
}

/// Structured record. Text rendering belongs to the UI layer -- this stays queryable,
/// localisable, and usable as grounding for the v0.3 narration layer.
public struct GameEvent: Codable, Sendable, Identifiable {
    public let id: EventID
    public let day: Int32
    public let kind: EventKind
    public let location: EventLocation
    public let subjects: [CitizenID]
    public let causes: [CauseFactor]
    public let magnitude: Int32
    public let causedBy: EventID?

    public init(id: EventID, day: Int32, kind: EventKind,
                location: EventLocation = EventLocation(),
                subjects: [CitizenID] = [], causes: [CauseFactor] = [],
                magnitude: Int32 = 0, causedBy: EventID? = nil) {
        self.id = id
        self.day = day
        self.kind = kind
        self.location = location
        self.subjects = subjects
        self.causes = causes
        self.magnitude = magnitude
        self.causedBy = causedBy
    }
}

public enum DecisionKind: String, Codable, Sendable, CaseIterable {
    case districtUprising, corruptionScandal, famine, bankruptcy

    /// Dense index for per-kind cooldown bookkeeping.
    public var slot: Int {
        switch self {
        case .districtUprising: return 0
        case .corruptionScandal: return 1
        case .famine: return 2
        case .bankruptcy: return 3
        }
    }
}

public struct DecisionOption: Codable, Sendable, Identifiable {
    public let id: Int32
    public let label: String
    public let monetaryCost: Int64

    public init(id: Int32, label: String, monetaryCost: Int64 = 0) {
        self.id = id
        self.label = label
        self.monetaryCost = monetaryCost
    }
}

/// A crisis awaiting the player. Carries its own causal chain so the UI can say
/// exactly why it fired, and so tuning can verify no crisis is pure RNG.
public struct PendingDecision: Codable, Sendable, Identifiable {
    public let id: DecisionID
    public let kind: DecisionKind
    public let raisedOnDay: Int32
    public let location: EventLocation
    public let causes: [CauseFactor]
    public let options: [DecisionOption]

    public init(id: DecisionID, kind: DecisionKind, raisedOnDay: Int32,
                location: EventLocation, causes: [CauseFactor], options: [DecisionOption]) {
        self.id = id
        self.kind = kind
        self.raisedOnDay = raisedOnDay
        self.location = location
        self.causes = causes
        self.options = options
    }
}
