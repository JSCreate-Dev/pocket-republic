import Foundation

/// Presentation readers, not a second quest/economy system. Never saved.
public enum CityFocusAction: Equatable, Sendable {
    case build(BuildingKind)
    case inspect(BuildingID)
    case overlay(MapOverlayMode)
    case growth, roadmap
}

public struct CityFocus: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let actionLabel: String
    public let action: CityFocusAction
    public let current: Int
    public let target: Int
    public var fraction: Double { min(1, max(0, Double(current) / Double(max(1, target)))) }
}

public enum CityFocusReader {
    public static func goals(in state: RepublicState) -> [CityFocus] {
        let outlook = SettlementOutlook(state: state)
        let living = state.citizens.filter(\.alive)
        let jobless = living.filter { $0.work == nil }.count
        var goals: [CityFocus] = []
        func waiting(_ building: Building) -> CityFocus {
            CityFocus(id: "site-\(building.id.raw)", title: "\(String(describing: building.kind).capitalized) under construction",
                      detail: "Opens on Day \(building.opensOnDay). Plan the next neighbourhood while work continues.",
                      actionLabel: "View construction", action: .inspect(building.id),
                      current: Int(building.daysConstructed), target: Int(building.daysRequired))
        }
        if outlook.hungryResidents > 0 {
            goals.append(CityFocus(id: "food", title: "Get everyone fed",
                detail: "\(outlook.hungryResidents) residents are hungry. Check market stock, road access and residents' money.",
                actionLabel: "Check food access", action: .overlay(.foodAccess),
                current: outlook.population - outlook.hungryResidents, target: outlook.population))
        }
        if jobless > 0 {
            if outlook.openJobs >= jobless {
                goals.append(CityFocus(id: "jobs-access", title: "Connect people to work",
                    detail: "\(jobless) seeking work; \(outlook.openJobs) vacancies. Residents take connected jobs automatically on the next day.",
                    actionLabel: "Check employment", action: .overlay(.employment),
                    current: outlook.population - jobless, target: outlook.population))
            } else if let site = state.buildings.first(where: { $0.isUnderConstruction && $0.occupiesGround(on: state.map) && $0.kind.workerCapacity > 0 }) {
                goals.append(waiting(site))
            } else {
                let shortage = jobless - outlook.openJobs
                goals.append(CityFocus(id: "jobs-build", title: "Give the town room to work",
                    detail: "\(shortage) additional job slots are needed. Existing vacancies fill automatically; a workshop creates more room for the town to work.",
                    actionLabel: "Plan a workshop", action: .build(.workshop),
                    current: outlook.population - shortage, target: outlook.population))
            }
        }
        let threshold = state.config.settlementGrowth?.minimumHappiness ?? 40
        if outlook.population > 0 && outlook.happiness < threshold {
            goals.append(CityFocus(id: "happiness", title: "Make the island worth staying for",
                detail: "Happiness is \(outlook.happiness)%. Food, jobs, service access and tax burden are useful things to investigate; no single fix is guaranteed.",
                actionLabel: "Check happiness", action: .overlay(.happiness),
                current: outlook.happiness, target: Int(threshold)))
        }
        if outlook.enabled && outlook.freeBeds == 0 {
            if let site = state.buildings.first(where: { $0.kind == .house && $0.isUnderConstruction && $0.occupiesGround(on: state.map) }) {
                goals.append(waiting(site))
            } else {
                goals.append(CityFocus(id: "housing", title: "Make room for new neighbours",
                    detail: "All standing homes are full. Add housing, then keep jobs and market supplies ready for arrivals.",
                    actionLabel: "Plan a house", action: .build(.house), current: 0,
                    target: Int(max(1, state.config.settlementGrowth?.arrivalsPerWave ?? 2))))
            }
        }
        if goals.isEmpty && outlook.enabled {
            if outlook.ready {
                let interval = max(1, state.config.settlementGrowth?.arrivalIntervalDays ?? 4)
                goals.append(CityFocus(id: "arrivals", title: "Keep the welcome ready",
                    detail: "Next arrival check: Day \(outlook.nextArrivalDay ?? state.day). Conditions must still hold then; capacity is checked for each newcomer.",
                    actionLabel: "Review arrival readiness", action: .growth,
                    current: Int(state.day % interval), target: Int(interval)))
            } else {
                goals.append(CityFocus(id: "supply-network", title: "Check the supply network",
                    detail: outlook.blockers.first ?? "Review connected homes, workplaces and stocked markets.",
                    actionLabel: "Review growth blockers", action: .growth, current: 0, target: 1))
            }
        }
        goals.append(CityFocus(id: "development", title: "Choose the next chapter",
            detail: state.development == nil
                ? "Review the founding charter and build the neighbourhoods residents need. Your existing building catalog stays available."
                : "Develop trade and community. Earned unlocks stay earned; you decide which neighbourhood grows next.",
            actionLabel: "Review charter and roadmap", action: .roadmap,
            current: state.development?.unlocked.count ?? 0,
            target: state.development == nil ? 0 : DevelopmentUnlock.allCases.count))
        return goals
    }
}

public struct CityDaySnapshot: Sendable {
    public let seed: UInt64
    public let day: Int32
    public let population: Int
    public let treasury: Int64
    public let food: Int64
    public let happiness: Int
    public let hungry: Int
    public let standing: Set<BuildingID>

    public init(state: RepublicState) {
        seed = state.worldSeed; day = state.day
        let living = state.citizens.filter(\.alive)
        population = living.count; treasury = state.treasury; food = state.totalFoodInWorld
        happiness = living.isEmpty ? 0 : Int(living.reduce(Int64(0)) { $0 + Int64($1.happiness) } / Int64(living.count))
        hungry = living.filter { $0.daysHungry > 0 }.count
        standing = Set(state.buildings.filter { $0.isStanding(on: state.map) }.map(\.id))
    }
}

public struct CityDayResult: Identifiable, Sendable {
    public let seed: UInt64
    public let fromDay: Int32
    public let day: Int32
    public let populationDelta: Int
    public let treasuryDelta: Int64
    public let foodDelta: Int64
    public let happinessDelta: Int
    public let newlyOpened: Int
    public let hungry: Int
    public var id: String { "\(seed)-\(fromDay)-\(day)" }
    public var headline: String {
        if hungry > 0 { return "Some neighbours need food" }
        if populationDelta > 0 { return "The town is growing" }
        if newlyOpened > 0 { return "New doors are open" }
        if happinessDelta < 0 { return "Residents are less content" }
        if happinessDelta > 0 { return "Life on the island is improving" }
        return "A day in the life of your republic"
    }

    public static func compare(_ previous: CityDaySnapshot, _ next: CityDaySnapshot) -> CityDayResult? {
        guard previous.seed == next.seed, next.day > previous.day else { return nil }
        return CityDayResult(seed: next.seed, fromDay: previous.day, day: next.day,
            populationDelta: next.population - previous.population,
            treasuryDelta: next.treasury - previous.treasury, foodDelta: next.food - previous.food,
            happinessDelta: next.happiness - previous.happiness,
            newlyOpened: next.standing.subtracting(previous.standing).count, hungry: next.hungry)
    }
}
