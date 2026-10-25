import Foundation

public enum ServiceKind: UInt8, Codable, Sendable, CaseIterable {
    case market = 0, clinic = 1, school = 2, police = 3, work = 4
}

public enum BuildingKind: UInt8, Codable, Sendable, CaseIterable {
    case townHall = 0, house = 1, farm = 2, market = 3, clinic = 4
    case school = 5, police = 6, workshop = 7, dock = 8

    public var housingCapacity: Int32 {
        switch self { case .house: return 4; default: return 0 }
    }
    public var workerCapacity: Int32 {
        switch self {
        case .farm: return 4
        case .market: return 2
        case .clinic: return 3
        case .school: return 2
        case .police: return 3
        case .workshop: return 5
        case .dock: return 4
        case .townHall: return 2
        case .house: return 0
        }
    }
    /// Civic employers are paid by the treasury; private ones out of their own till.
    public var isCivic: Bool {
        switch self {
        case .clinic, .school, .police, .townHall: return true
        default: return false
        }
    }
    public var provides: ServiceKind? {
        switch self {
        case .market: return .market
        case .clinic: return .clinic
        case .school: return .school
        case .police: return .police
        case .farm, .workshop, .dock, .townHall: return .work
        case .house: return nil
        }
    }
    public var buildCost: Int64 {
        switch self {
        case .house: return 120
        case .farm: return 180
        case .market: return 220
        case .clinic: return 400
        case .school: return 350
        case .police: return 300
        case .workshop: return 260
        case .dock: return 500
        case .townHall: return 0
        }
    }
    public var storesFood: Bool {
        switch self { case .farm, .market: return true; default: return false }
    }
}

/// How a production building is run. Chosen by the player at placement time, so
/// the choice is tied to a spot on the map rather than buried in a menu.
public enum OperatingMode: UInt8, Codable, Sendable, CaseIterable {
    case balanced = 0
    case intensive = 1   // more output, more unrest in the host district
    case careful = 2     // less output, calmer neighbours

    public var outputPercent: Int32 {
        switch self {
        case .balanced: return 100
        case .intensive: return 145
        case .careful: return 75
        }
    }
    /// Unrest added to the host district each day it runs this way.
    public var unrestPerDay: Int32 {
        switch self {
        case .balanced: return 0
        case .intensive: return 1
        case .careful: return -1
        }
    }
}

extension BuildingKind {
    /// Production buildings pose a run-hard / run-clean choice when placed.
    public var offersCommission: Bool {
        switch self {
        case .farm, .workshop, .dock: return true
        default: return false
        }
    }
}

public struct Building: Codable, Sendable, Identifiable {
    public let id: BuildingID
    public let kind: BuildingKind
    public let tile: TileIndex
    public let district: DistrictID
    public let builtOnDay: Int32

    public var workers: [CitizenID] = []
    public var residents: [CitizenID] = []
    public var foodStore: Int32 = 0
    public var funds: Int64 = 0
    public var mode: OperatingMode = .balanced

    public init(id: BuildingID, kind: BuildingKind, tile: TileIndex,
                district: DistrictID, builtOnDay: Int32) {
        self.id = id
        self.kind = kind
        self.tile = tile
        self.district = district
        self.builtOnDay = builtOnDay
    }
}

public struct District: Codable, Sendable, Identifiable {
    public let id: DistrictID
    public let name: String

    // Aggregates recomputed every tick; the renderer draws these at far zoom and
    // the political layer reads them instead of scanning citizens.
    public var population: Int32 = 0
    public var meanHappiness: Int32 = 50
    public var meanLoyalty: Int32 = 50
    public var unrest: Int32 = 0
    public var hungryCount: Int32 = 0
    public var unemployedCount: Int32 = 0
    public var marketCoverage: Int32 = 0   // percent of residents within service range
    public var clinicCoverage: Int32 = 0
    public var policeCoverage: Int32 = 0
    /// Consecutive days this district has lacked basic service coverage. This is the
    /// state that makes "the east docks have been neglected" traceable rather than flavour.
    public var neglectDays: Int32 = 0

    /// Days before this district may raise another crisis. Without hysteresis a
    /// district sitting above the threshold re-raises every single tick, which is a
    /// treadmill rather than a decision.
    public var crisisCooldown: Int32 = 0

    /// Resolved on each distance-field rebuild, not per tick.
    public var servingMarket: BuildingID? = nil
    public var centroid: TileIndex = TileIndex(0)

    public init(id: DistrictID, name: String) {
        self.id = id
        self.name = name
    }
}
