import Foundation

public struct Policy: Codable, Sendable, Equatable {
    public var incomeTaxPercent: Int32
    public var businessTaxPercent: Int32
    public var civicWage: Int64

    public init(incomeTaxPercent: Int32, businessTaxPercent: Int32, civicWage: Int64) {
        self.incomeTaxPercent = incomeTaxPercent
        self.businessTaxPercent = businessTaxPercent
        self.civicWage = civicWage
    }
}

public struct RepublicState: Codable, Sendable {
    /// 2: buildings store an anchor plus an entrance, and the map records entrance tiles.
    /// Saves written at version 1 do not decode; the app keeps the file and waits for a new city.
    public static let currentSchemaVersion = 2
    public var schemaVersion: Int = RepublicState.currentSchemaVersion

    public let worldSeed: UInt64
    public var rng: SeededRNG
    public var config: BalanceConfig
    public var policy: Policy

    public var day: Int32 = 0
    public var map: WorldMap
    public var buildings: [Building] = []     // dense, indexed by BuildingID.raw
    public var citizens: [Citizen] = []       // dense, indexed by CitizenID.raw
    public var districts: [District] = []     // dense, indexed by DistrictID.raw
    public var fields = DistanceFields()

    public var treasury: Int64 = 0
    public var ledger = Ledger()

    public var corruption: Int32 = 10
    public var legitimacy: Int32 = 65

    public var events: [GameEvent] = []
    public var pending: PendingDecision? = nil
    public var lastCrisisDay: Int32 = -9999
    /// Per-kind cooldown, indexed by DecisionKind.slot. District uprisings get
    /// hysteresis from the district itself; the national crises need their own,
    /// or a lasting condition re-raises the same prompt every other day forever.
    public var crisisKindCooldown: [Int32] = Array(repeating: 0, count: DecisionKind.allCases.count)

    /// Standing interest groups, dense and indexed by FactionKind.rawValue.
    public var factions: [Faction] = FactionKind.allCases.map(Faction.init)
    /// Everything actionable on screen right now. The engine's contract is that
    /// this is never empty after a tick.
    public var agenda: [AgendaItem] = []
    public var lastElectionDay: Int32 = -9999

    /// A day-advance is blocked only by genuine crises, not by the standing agenda.
    public var blocksAdvance: Bool {
        pending != nil || agenda.contains { $0.tier == .crisis }
    }

    var nextEventRaw: Int64 = 1
    var nextDecisionRaw: Int64 = 1
    var nextBuildingRaw: Int32 = 0
    var nextCitizenRaw: Int32 = 0

    public init(worldSeed: UInt64, config: BalanceConfig, map: WorldMap) {
        self.worldSeed = worldSeed
        self.rng = SeededRNG(seed: worldSeed)
        self.config = config
        self.map = map
        self.policy = Policy(incomeTaxPercent: config.incomeTaxPercent,
                             businessTaxPercent: config.businessTaxPercent,
                             civicWage: config.civicWage)
    }
}

// MARK: - Accounts and conserved transfers

extension RepublicState {
    public func balance(of account: Account) -> Int64 {
        switch account {
        case .treasury: return treasury
        case .citizen(let id): return citizens[Int(id.raw)].money
        case .building(let id): return buildings[Int(id.raw)].funds
        case .external: return .max
        }
    }

    mutating func credit(_ account: Account, _ amount: Int64) {
        guard amount != 0 else { return }
        switch account {
        case .treasury: treasury += amount
        case .citizen(let id): citizens[Int(id.raw)].money += amount
        case .building(let id): buildings[Int(id.raw)].funds += amount
        case .external: ledger.externalOutflow += amount
        }
    }

    /// Move money between accounts, capped at what the payer actually has.
    /// Returns the amount really moved. This is the only way money changes hands.
    @discardableResult
    mutating func transfer(from: Account, to: Account, _ amount: Int64) -> Int64 {
        guard amount > 0 else { return 0 }
        let available: Int64
        if case .external = from { available = amount } else { available = max(0, balance(of: from)) }
        let moved = min(amount, available)
        guard moved > 0 else { return 0 }

        if case .external = from { ledger.externalInflow += moved } else { credit(from, -moved) }
        if case .external = to { ledger.externalOutflow += moved } else { credit(to, moved) }
        return moved
    }

    public var totalMoneyInWorld: Int64 {
        var total = treasury
        for c in citizens { total += c.money }
        for b in buildings { total += b.funds }
        return total
    }

    public var totalFoodInWorld: Int64 {
        var total: Int64 = 0
        for b in buildings { total += Int64(b.foodStore) }
        return total
    }
}

// MARK: - Accounted food movements

extension RepublicState {
    mutating func produceFood(at id: BuildingID, _ amount: Int32) {
        guard amount > 0 else { return }
        buildings[Int(id.raw)].foodStore += amount
        ledger.foodProduced += Int64(amount)
    }

    @discardableResult
    mutating func shipFood(from: BuildingID, to: BuildingID, _ amount: Int32) -> Int32 {
        guard amount > 0 else { return 0 }
        let moved = min(amount, buildings[Int(from.raw)].foodStore)
        guard moved > 0 else { return 0 }
        buildings[Int(from.raw)].foodStore -= moved
        buildings[Int(to.raw)].foodStore += moved
        return moved   // internal move: totals unchanged, nothing to record
    }

    @discardableResult
    mutating func consumeFood(at id: BuildingID, _ amount: Int32) -> Int32 {
        guard amount > 0 else { return 0 }
        let taken = min(amount, buildings[Int(id.raw)].foodStore)
        guard taken > 0 else { return 0 }
        buildings[Int(id.raw)].foodStore -= taken
        ledger.foodConsumed += Int64(taken)
        return taken
    }

    mutating func spoilFood(at id: BuildingID, _ amount: Int32) {
        guard amount > 0 else { return }
        let lost = min(amount, buildings[Int(id.raw)].foodStore)
        guard lost > 0 else { return }
        buildings[Int(id.raw)].foodStore -= lost
        ledger.foodSpoiled += Int64(lost)
    }

    /// Debug-only invariant. Tests assert this never trips.
    public func checkConservation() throws {
        if totalMoneyInWorld != ledger.expectedMoneyTotal {
            throw ConservationError(description:
                "money: accounts=\(totalMoneyInWorld) expected=\(ledger.expectedMoneyTotal) on day \(day)")
        }
        if totalFoodInWorld != ledger.expectedFoodTotal {
            throw ConservationError(description:
                "food: stores=\(totalFoodInWorld) expected=\(ledger.expectedFoodTotal) on day \(day)")
        }
    }
}

// MARK: - Event emission

extension RepublicState {
    mutating func emit(_ kind: EventKind,
                       location: EventLocation = EventLocation(),
                       subjects: [CitizenID] = [],
                       causes: [CauseFactor] = [],
                       magnitude: Int32 = 0,
                       causedBy: EventID? = nil) {
        let e = GameEvent(id: EventID(nextEventRaw), day: day, kind: kind,
                          location: location, subjects: subjects, causes: causes,
                          magnitude: magnitude, causedBy: causedBy)
        nextEventRaw += 1
        events.append(e)
    }

    /// The log is append-only but unbounded; the app trims it when persisting.
    public mutating func trimEvents(keepingLast n: Int) {
        if events.count > n { events.removeFirst(events.count - n) }
    }
}
