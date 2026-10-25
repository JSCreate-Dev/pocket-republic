import Foundation

/// Standing interest groups. Districts answer "where is the problem"; factions
/// answer "who is angry about it and will they remember". Membership is derived
/// from what a citizen actually does for a living, so a faction's mood is a real
/// readout of the simulation rather than a separate opinion system bolted on top.
public enum FactionKind: UInt8, Codable, Sendable, CaseIterable {
    case labourers = 0      // farmers, dockhands, artisans
    case merchants = 1      // shopkeepers and the private purse
    case officials = 2      // civic payroll: clerks, officers, teachers, nurses
    case landless = 3       // the unemployed and the destitute

    public var displayName: String {
        switch self {
        case .labourers: return "Labourers"
        case .merchants: return "Merchants"
        case .officials: return "Officials"
        case .landless: return "Landless"
        }
    }

    public static func of(_ occupation: Occupation) -> FactionKind {
        switch occupation {
        case .farmer, .dockhand, .artisan: return .labourers
        case .shopkeeper: return .merchants
        case .official, .officer, .teacher, .nurse: return .officials
        case .unemployed: return .landless
        }
    }
}

/// One remembered act of government, kept so a cheap decision today can be paid
/// back (or charged for) much later. Bounded: only the recent past is retained.
public struct FavorRecord: Codable, Sendable, Equatable {
    public let day: Int32
    public let delta: Int32
    public let reason: CauseKind
    public let detail: String

    public init(day: Int32, delta: Int32, reason: CauseKind, detail: String) {
        self.day = day
        self.delta = delta
        self.reason = reason
        self.detail = detail
    }
}

public struct Faction: Codable, Sendable, Equatable {
    public let kind: FactionKind
    /// -100 (hostile) ... +100 (devoted). Persists across the whole campaign.
    public var favor: Int32 = 0
    public var members: Int32 = 0
    public var meanHappiness: Int32 = 50
    public var meanLoyalty: Int32 = 50
    /// The grievance most of this faction's members share right now; this is what
    /// a demand gets generated from, which is why demands are never pure RNG.
    public var dominantConcern: CauseKind? = nil
    public var concernWeight: Int32 = 0
    public var lastDemandDay: Int32 = -9999
    public var ignoredDemands: Int32 = 0
    public var honouredDemands: Int32 = 0
    public var memory: [FavorRecord] = []

    public init(kind: FactionKind) { self.kind = kind }

    /// Favor is the long memory, so it is clamped wider than the 0...100 stats.
    public mutating func adjust(_ delta: Int32, on day: Int32, reason: CauseKind, detail: String) {
        favor = max(-100, min(100, favor + delta))
        memory.append(FavorRecord(day: day, delta: delta, reason: reason, detail: detail))
        if memory.count > 24 { memory.removeFirst(memory.count - 24) }
    }
}
