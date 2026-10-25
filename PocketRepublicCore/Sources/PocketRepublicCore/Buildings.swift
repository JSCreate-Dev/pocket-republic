import Foundation

public enum ServiceKind: UInt8, Codable, Sendable, CaseIterable {
    case market = 0, clinic = 1, school = 2, police = 3, work = 4
}

/// Width along +x and height along +y, in tiles. Footprints do not rotate:
/// the anchor is always the minimum-x, minimum-y corner.
public struct FootprintSize: Sendable, Equatable, Hashable {
    public let width: Int32
    public let height: Int32

    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }

    public var area: Int { Int(width * height) }
}

public enum BuildingKind: UInt8, Codable, Sendable, CaseIterable {
    case townHall = 0, house = 1, farm = 2, market = 3, clinic = 4
    case school = 5, police = 6, workshop = 7, dock = 8

    /// Design table in `docs/DESIGN.md`. Width is x, height is y.
    public var footprint: FootprintSize {
        switch self {
        case .house, .police: return FootprintSize(width: 2, height: 2)
        case .market, .workshop: return FootprintSize(width: 3, height: 2)
        case .farm, .clinic, .school, .townHall: return FootprintSize(width: 3, height: 3)
        case .dock: return FootprintSize(width: 2, height: 3)
        }
    }

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

/// How far along a building site is. Drawn differently at each step
/// (docs/DESIGN.md section 7.2); derived from the day counts, never stored.
public enum ConstructionStage: UInt8, Codable, Sendable, CaseIterable {
    case foundation = 0
    case scaffold = 1
    case complete = 2
}

public struct Building: Codable, Sendable, Identifiable {
    public let id: BuildingID
    public let kind: BuildingKind
    /// Minimum-x, minimum-y corner. `PlayerIntent.placeBuilding` takes this tile.
    public let anchor: TileIndex
    /// The one road-facing door. Only this footprint tile is passable.
    public let entrance: TileIndex
    public let district: DistrictID
    public let builtOnDay: Int32

    public var workers: [CitizenID] = []
    public var residents: [CitizenID] = []
    public var foodStore: Int32 = 0
    public var funds: Int64 = 0
    public var mode: OperatingMode = .balanced

    // MARK: Construction (docs/DESIGN.md section 7)

    /// Whole sim-days of work already done on this site. Only ever counted up by
    /// `SimulationEngine.advanceConstruction`, one per tick.
    public var daysConstructed: Int32 = 0
    /// Total days of work this site needs. `0` means "was never a site" - worldgen
    /// buildings and anything placed while `constructionDaysMultiplierPercent == 0`.
    public var daysRequired: Int32 = 0

    /// A site on the ground that is not finished yet. It owns its tiles and has been
    /// paid for, but has no workers, residents, production, upkeep, or service reach.
    public var isUnderConstruction: Bool { daysRequired > 0 && daysConstructed < daysRequired }
    /// The one gate every simulation step checks before touching a building.
    public var isOperational: Bool { !isUnderConstruction }

    /// Derived for the renderer and inspect panel, never stored: a `Double` in
    /// `RepublicState` would make `stateHash()` non-canonical.
    public var constructionProgress: Double {
        guard daysRequired > 0 else { return 1.0 }
        return min(1.0, Double(daysConstructed) / Double(daysRequired))
    }

    /// The day this site becomes operational. Equal to `builtOnDay` when it never was one.
    public var opensOnDay: Int32 { builtOnDay + max(0, daysRequired) }

    /// Which of the three stages to draw. Finished buildings are always `.complete`.
    public func stage(in config: BalanceConfig) -> ConstructionStage {
        guard isUnderConstruction else { return .complete }
        return daysConstructed < config.foundationDays(forRequired: daysRequired) ? .foundation : .scaffold
    }

    /// Days done and days needed *within the current stage*, for "2 of 3 days" text.
    public func stageProgress(in config: BalanceConfig) -> (done: Int32, of: Int32) {
        guard isUnderConstruction else { return (max(0, daysRequired), max(0, daysRequired)) }
        let foundation = config.foundationDays(forRequired: daysRequired)
        if daysConstructed < foundation { return (daysConstructed, foundation) }
        return (daysConstructed - foundation, daysRequired - foundation)
    }

    /// Service range, employment, and pathing all use the entrance.
    public var tile: TileIndex { entrance }

    public init(id: BuildingID, kind: BuildingKind, anchor: TileIndex, entrance: TileIndex,
                district: DistrictID, builtOnDay: Int32, daysRequired: Int32 = 0) {
        self.id = id
        self.kind = kind
        self.anchor = anchor
        self.entrance = entrance
        self.district = district
        self.builtOnDay = builtOnDay
        self.daysRequired = max(0, daysRequired)
    }

    /// Footprint tiles in row-major order. Empty tiles of a demolished building
    /// are still reported; occupancy lives on the map.
    public func tilesCovered(on map: WorldMap) -> [TileIndex] {
        map.tilesCovered(anchor: anchor, footprint: kind.footprint)
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
