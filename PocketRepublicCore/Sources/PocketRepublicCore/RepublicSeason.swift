import Foundation

/// One lasting development compact. The other one closes when this is chosen.
public enum DevelopmentPath: String, Codable, Sendable, Equatable {
    /// More food from every farm worker. Private workplaces cost more to keep open.
    case granary
    /// Workshops and docks earn more coin. Stored food spoils faster.
    case harbor
}

/// What the player can ask the season to do. The engine rejects a step that is
/// early, repeated, or the compact that was not chosen.
public enum SeasonStep: Sendable, Equatable {
    case claimFounding
    case choose(DevelopmentPath)
    case claimSettled
}

/// Recorded once. Nil on a save from before the season, which still decodes.
public struct RepublicSeason: Codable, Sendable, Equatable {
    public var foundingClaimed: Bool
    public var path: DevelopmentPath?
    public var settledClaimed: Bool

    public init(foundingClaimed: Bool = false, path: DevelopmentPath? = nil, settledClaimed: Bool = false) {
        self.foundingClaimed = foundingClaimed
        self.path = path
        self.settledClaimed = settledClaimed
    }
}

public enum SeasonBeat: String, Sendable, Equatable {
    case breakGround
    case chooseCompact
    case settle
    case kept
}

/// Rules and the one-time payments. Effects are applied by reading this record
/// during production, upkeep, spoilage, and wellbeing. They are not paid again on load.
public enum RepublicSeasonBook {
    public static let foundingGrant: Int64 = 120
    public static let pathCost: Int64 = 280
    public static let granaryFoodPerWorker: Int32 = 1
    public static let granaryUpkeepExtra: Int64 = 1
    public static let harborCoinsPerWorker: Int64 = 2
    public static let harborSpoilageExtra: Int32 = 4
    public static let settledLegitimacy: Int32 = 4
    public static let settledDay: Int32 = 5
    public static let settledHappiness: Int32 = 40

    public static func status(in state: RepublicState) -> SeasonStatus {
        let season = state.republicSeason ?? RepublicSeason()
        let kinds = playerOpenKinds(in: state)
        let happiness = meanHappiness(in: state)
        let foundingReady = !season.foundingClaimed && !kinds.isEmpty
        let settledReady = season.foundingClaimed && season.path != nil && !season.settledClaimed
            && kinds.count >= 2 && state.day >= settledDay
            && state.totalFoodInWorld > 0 && happiness >= settledHappiness
        let beat: SeasonBeat
        if season.settledClaimed {
            beat = .kept
        } else if season.path != nil {
            beat = .settle
        } else if season.foundingClaimed {
            beat = .chooseCompact
        } else {
            beat = .breakGround
        }
        return SeasonStatus(beat: beat, foundingReady: foundingReady, path: season.path,
                            settledReady: settledReady, playerKinds: kinds.count,
                            happiness: happiness, food: state.totalFoodInWorld)
    }

    /// Buildings the player paid to raise. Worldgen uses `daysRequired == 0`.
    public static func playerOpenKinds(in state: RepublicState) -> Set<BuildingKind> {
        Set(state.buildings.compactMap { building in
            guard building.daysRequired > 0, building.isStanding(on: state.map) else { return nil }
            return building.kind
        })
    }

    public static func meanHappiness(in state: RepublicState) -> Int32 {
        let alive = state.citizens.filter(\.alive)
        guard !alive.isEmpty else { return 0 }
        return Int32(alive.reduce(Int64(0)) { $0 + Int64($1.happiness) } / Int64(alive.count))
    }

    public static func granaryUpkeepSurcharge(for building: Building, in state: RepublicState) -> Int64 {
        guard state.republicSeason?.path == .granary, building.isStanding(on: state.map),
              !building.kind.isCivic, building.kind != .house else { return 0 }
        return granaryUpkeepExtra
    }

    public static func harborOutputBonus(workers: Int32, scale: Int64, in state: RepublicState) -> Int64 {
        guard state.republicSeason?.path == .harbor, workers > 0 else { return 0 }
        return Int64(workers) * harborCoinsPerWorker * scale / 100
    }

    public static func spoilagePercent(in state: RepublicState) -> Int32 {
        let base = state.config.marketSpoilagePercent
        guard state.republicSeason?.path == .harbor else { return base }
        return base + harborSpoilageExtra
    }

    public static func unemploymentPenalty(in state: RepublicState) -> Int32 {
        let base = state.config.unemploymentPenalty
        guard state.republicSeason?.settledClaimed == true else { return base }
        return max(0, base - 1)
    }

    public static func apply(_ step: SeasonStep, to s: inout RepublicState) -> IntentResult {
        var season = s.republicSeason ?? RepublicSeason()
        switch step {
        case .claimFounding:
            guard !season.foundingClaimed else { return .rejected(.seasonAlreadyClaimed) }
            guard !playerOpenKinds(in: s).isEmpty else { return .rejected(.seasonNotReady) }
            s.transfer(from: .external, to: .treasury, foundingGrant)
            season.foundingClaimed = true
            s.republicSeason = season
            s.emit(.republicSeason, causes: [CauseFactor(.policyChange, value: Int32(foundingGrant),
                                                         detail: "The charter is sealed")])
            return .accepted

        case .choose(let path):
            guard season.foundingClaimed else { return .rejected(.seasonFoundingRequired) }
            guard season.path == nil else { return .rejected(.seasonPathTaken) }
            guard s.treasury >= pathCost else { return .rejected(.insufficientTreasury) }
            s.transfer(from: .treasury, to: .external, pathCost)
            season.path = path
            s.republicSeason = season
            let detail = path == .granary
                ? "The granary compact is in force"
                : "The harbor compact is in force"
            s.emit(.republicSeason, causes: [CauseFactor(.policyChange, value: Int32(pathCost), detail: detail)])
            return .accepted

        case .claimSettled:
            guard !season.settledClaimed else { return .rejected(.seasonAlreadyClaimed) }
            guard status(in: s).settledReady else { return .rejected(.seasonNotReady) }
            season.settledClaimed = true
            s.republicSeason = season
            s.legitimacy = clamp(s.legitimacy + settledLegitimacy)
            s.emit(.republicSeason, causes: [CauseFactor(.policyChange, value: settledLegitimacy,
                                                         detail: "The republic is settled")])
            return .accepted
        }
    }
}

public struct SeasonStatus: Sendable, Equatable {
    public var beat: SeasonBeat
    public var foundingReady: Bool
    public var path: DevelopmentPath?
    public var settledReady: Bool
    public var playerKinds: Int
    public var happiness: Int32
    public var food: Int64
}
