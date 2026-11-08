import Foundation

/// Optional on RepublicState: pre-tree saves keep unrestricted construction.
public struct DevelopmentProgress: Codable, Sendable, Equatable {
    public var unlocked: [DevelopmentUnlock] = []
    /// Player-funded workplaces, including instant construction. Worldgen is not progress.
    public var commissionedWorkplaces: [BuildingID] = []
    public init() {}
}

public enum DevelopmentUnlock: String, Codable, Sendable, CaseIterable, Identifiable {
    case workingTown, harborCharter, communityCare, civicTown
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .workingTown: return "A Working Town"
        case .harborCharter: return "Harbor Charter"
        case .communityCare: return "Community Care"
        case .civicTown: return "A Civic Town"
        }
    }
    public var building: BuildingKind {
        switch self {
        case .workingTown: return .clinic
        case .harborCharter: return .dock
        case .communityCare: return .school
        case .civicTown: return .police
        }
    }
    public var prerequisite: DevelopmentUnlock? {
        switch self {
        case .workingTown: return nil
        case .harborCharter, .communityCare: return .workingTown
        case .civicTown: return .communityCare
        }
    }
    public var reward: String {
        switch self {
        case .workingTown: return "Build clinics to care for your residents."
        case .harborCharter: return "Build docks and open the island to trade."
        case .communityCare: return "Build schools for a growing community."
        case .civicTown: return "Build police stations to protect your town."
        }
    }
}

public struct DevelopmentRules: Codable, Sendable, Equatable {
    public var workingPopulation: Int32 = 16
    public var harborPopulation: Int32 = 18
    public var communityPopulation: Int32 = 24
    public var civicPopulation: Int32 = 28
    public var reserveDays: Int32 = 2
    public var civicHappiness: Int32 = 45
    public var workingGrant: Int64 = 180
    public var harborGrant: Int64 = 250
    public var communityGrant: Int64 = 350
    public var civicGrant: Int64 = 300
    public init() {}
}

public struct DevelopmentRequirement: Sendable, Equatable {
    public let title: String
    public let current: Int64
    public let target: Int64
    public var met: Bool { current >= target }
}

/// A reader shared by roadmap, catalog, HUD and placement; never grants an unlock.
public struct DevelopmentNode: Sendable, Identifiable {
    public let id: DevelopmentUnlock
    public let unlocked: Bool
    public let prerequisiteMet: Bool
    public let requirements: [DevelopmentRequirement]
    public let grant: Int64
    public var ready: Bool { prerequisiteMet && requirements.allSatisfy(\.met) }
}

public enum DevelopmentTree {
    public static func isEnabled(in state: RepublicState) -> Bool {
        state.development != nil && state.config.developmentRules != nil
    }

    public static func canBuild(_ kind: BuildingKind, in state: RepublicState) -> Bool {
        guard isEnabled(in: state), let milestone = DevelopmentUnlock.allCases.first(where: { $0.building == kind }) else { return true }
        return state.development?.unlocked.contains(milestone) == true
    }

    public static func lockReason(for kind: BuildingKind, in state: RepublicState) -> String? {
        guard !canBuild(kind, in: state), let milestone = DevelopmentUnlock.allCases.first(where: { $0.building == kind }) else { return nil }
        return "Earn \(milestone.title) to unlock this building."
    }

    public static func nodes(in state: RepublicState) -> [DevelopmentNode] {
        guard let rules = state.config.developmentRules, isEnabled(in: state) else { return [] }
        let citizens = state.citizens.filter { $0.alive }
        let population = Int64(citizens.count)
        let employed = Int64(citizens.filter { c in
            guard let work = c.work, Int(work.raw) >= 0, Int(work.raw) < state.buildings.count else { return false }
            return state.buildings[Int(work.raw)].isStanding(on: state.map)
        }.count)
        let fed = Int64(citizens.filter { $0.daysHungry == 0 }.count)
        let homes = Int64(citizens.filter { c in
            guard let home = c.home, Int(home.raw) >= 0, Int(home.raw) < state.buildings.count else { return false }
            return state.buildings[Int(home.raw)].isStanding(on: state.map)
        }.count)
        let reserve = state.buildings.filter { $0.kind == .market && $0.isStanding(on: state.map) }
            .reduce(Int64(0)) { $0 + Int64($1.foodStore) }
        let foodTarget = max(1, population) * Int64(max(1, rules.reserveDays)) * Int64(max(1, state.config.foodPerCitizenPerDay))
        let happiness = citizens.isEmpty ? 0 : citizens.reduce(Int64(0)) { $0 + Int64($1.happiness) } / population
        let workplaces = (state.development?.commissionedWorkplaces ?? []).filter { id in
            let i = Int(id.raw)
            return i >= 0 && i < state.buildings.count && state.buildings[i].isStanding(on: state.map)
        }.count
        func count(_ kind: BuildingKind) -> Int64 {
            Int64(state.buildings.filter { $0.kind == kind && $0.isStanding(on: state.map) }.count)
        }
        func requirement(_ title: String, _ current: Int64, _ target: Int64) -> DevelopmentRequirement {
            DevelopmentRequirement(title: title, current: current, target: target)
        }
        return DevelopmentUnlock.allCases.map { milestone in
            let requirements: [DevelopmentRequirement]
            let grant: Int64
            switch milestone {
            case .workingTown:
                grant = rules.workingGrant
                requirements = [requirement("Residents", population, Int64(rules.workingPopulation)),
                                requirement("Residents with jobs", employed, max(1, population)),
                                requirement("New workplace open", Int64(workplaces), 1)]
            case .harborCharter:
                grant = rules.harborGrant
                requirements = [requirement("Residents", population, Int64(rules.harborPopulation)),
                                requirement("Residents fed", fed, max(1, population)),
                                requirement("Market food reserve", reserve, foodTarget)]
            case .communityCare:
                grant = rules.communityGrant
                requirements = [requirement("Residents", population, Int64(rules.communityPopulation)),
                                requirement("Residents housed", homes, max(1, population)),
                                requirement("Clinic open", count(.clinic), 1)]
            case .civicTown:
                grant = rules.civicGrant
                requirements = [requirement("Residents", population, Int64(rules.civicPopulation)),
                                requirement("School open", count(.school), 1),
                                requirement("Happiness", happiness, Int64(rules.civicHappiness))]
            }
            let unlocked = state.development?.unlocked.contains(milestone) == true
            let prerequisiteMet = milestone.prerequisite.map { state.development?.unlocked.contains($0) == true } ?? true
            return DevelopmentNode(id: milestone, unlocked: unlocked, prerequisiteMet: prerequisiteMet, requirements: requirements, grant: max(0, grant))
        }
    }

    public static func nextGoal(in state: RepublicState) -> DevelopmentNode? {
        let locked = nodes(in: state).filter { !$0.unlocked }
        return locked.first { $0.prerequisiteMet } ?? locked.first
    }

    /// Tick-only, canonical ordering and one award per milestone, no RNG. Grants use accounted external inflow.
    static func advance(_ state: inout RepublicState) {
        guard isEnabled(in: state) else { return }
        for id in DevelopmentUnlock.allCases {
            guard let node = nodes(in: state).first(where: { $0.id == id }), !node.unlocked, node.ready else { continue }
            state.development?.unlocked.append(id)
            state.transfer(from: .external, to: .treasury, node.grant)
            state.emit(.republicSeason, causes: [CauseFactor(.policyChange, value: Int32(DevelopmentUnlock.allCases.firstIndex(of: id) ?? 0),
                                                           detail: "Unlocked \(id.title). \(id.reward) Infrastructure grant: $\(node.grant).")])
        }
    }
}
