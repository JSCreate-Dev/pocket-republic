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
        if outlook.unhousedResidents > 0 {
            let site = state.buildings.first { $0.kind == .house && $0.isUnderConstruction && $0.occupiesGround(on: state.map) }
            goals.append(CityFocus(id: "rehousing", title: "Give existing neighbours a home",
                detail: "\(outlook.unhousedResidents) residents need shelter. Existing residents take completed spare homes before newcomers, automatically on the next daily update.",
                actionLabel: site != nil ? "View housing construction" : outlook.freeBeds > 0 ? "Review spare housing" : "Plan a house",
                action: site.map { .inspect($0.id) } ?? (outlook.freeBeds > 0 ? .growth : .build(.house)),
                current: outlook.population - outlook.unhousedResidents, target: outlook.population))
        }
        if outlook.hungryResidents > 0 {
            goals.append(CityFocus(id: "food", title: "Get everyone fed",
                detail: "\(outlook.hungryResidents) residents are hungry. " + (living.first(where: { $0.daysHungry > 0 }).map {
                    "\($0.name): " + CitizenNeeds.foodExplanation(for: $0, in: state)
                } ?? "Check market access, stock and household cash."),
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
        if outlook.enabled && outlook.freeBeds == 0 && outlook.unhousedResidents == 0 {
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
                    detail: "Next arrival check: Day \(outlook.nextArrivalDay ?? state.day). Current capacity supports \(outlook.expectedArrivals) of \(state.config.settlementGrowth?.arrivalsPerWave ?? 0) newcomers after local housing and hiring. Conditions must still hold then.",
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
    public let employed: Int
    public let standing: Set<BuildingID>

    public init(state: RepublicState) {
        seed = state.worldSeed; day = state.day
        let living = state.citizens.filter(\.alive)
        population = living.count; treasury = state.treasury; food = state.totalFoodInWorld
        happiness = living.isEmpty ? 0 : Int(living.reduce(Int64(0)) { $0 + Int64($1.happiness) } / Int64(living.count))
        hungry = living.filter { $0.daysHungry > 0 }.count
        employed = living.filter { $0.work != nil }.count
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
    public let fewerHungry: Int
    public let employmentDelta: Int
    public var id: String { "\(seed)-\(fromDay)-\(day)" }
    public var headline: String {
        if fewerHungry > 0 {
            return hungry == 0 ? "Everyone is fed again" : "\(fewerHungry) fewer neighbours missed meals"
        }
        if hungry > 0 { return "Some neighbours need food" }
        if populationDelta > 0 { return "The town is growing" }
        if newlyOpened > 0 { return "New doors are open" }
        if employmentDelta > 0 { return "\(employmentDelta) more residents are working" }
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
            newlyOpened: next.standing.subtracting(previous.standing).count, hungry: next.hungry,
            fewerHungry: max(0, previous.hungry - next.hungry), employmentDelta: next.employed - previous.employed)
    }
}

/// A replayable field guide tied to standing capacity and actual arrivals.
/// Ordering a site is not reported as completing a working neighbourhood.
public struct SettlementLesson: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let instruction: String
    public let evidence: String
    public let complete: Bool
    public let action: CityFocusAction
    public let actionLabel: String
}

public enum SettlementGuide {
    public static func lessons(in state: RepublicState) -> [SettlementLesson] {
        let town = SettlementOutlook(state: state)
        let population = town.population
        let employed = state.citizens.filter { $0.alive && $0.work != nil }.count
        let slots = employed + town.openJobs
        let beds = state.buildings.filter { $0.kind == .house && $0.isStanding(on: state.map) }
            .reduce(0) { $0 + Int($1.kind.housingCapacity) }
        let workSite = state.buildings.first { $0.kind.workerCapacity > 0 && $0.isUnderConstruction && $0.occupiesGround(on: state.map) }
        let homeSite = state.buildings.first { $0.kind == .house && $0.isUnderConstruction && $0.occupiesGround(on: state.map) }
        let workAction: CityFocusAction = slots > population ? .overlay(.employment)
            : workSite.map { .inspect($0.id) } ?? .build(.workshop)
        let homeAction: CityFocusAction = homeSite.map { .inspect($0.id) } ?? .build(.house)
        let happiness = Int(state.config.settlementGrowth?.minimumHappiness ?? 40)
        return [
            SettlementLesson(id: "work", title: "1. Give residents somewhere to work",
                instruction: "Open Build, choose a workshop, then move its preview beside a road. Green means the footprint is valid; tap Place to order it. Inspect the site to watch construction. Residents take reachable vacancies automatically on a daily update.",
                evidence: "\(slots) standing job slots for \(population) residents. Construction sites do not count yet.",
                complete: slots > population && employed == population, action: workAction,
                actionLabel: slots > population ? "Review automatic hiring" : workSite == nil ? "Open workshop tool" : "View workplace construction"),
            SettlementLesson(id: "homes", title: "2. Prepare a welcome",
                instruction: "Order a house beside the connected street network. A foundation is only a site: wait for it to open before newcomers can use its beds. Cancel closes the preview; it does not demolish an ordered building.",
                evidence: "\(beds) standing beds; \(town.freeBeds) available for newcomers.",
                complete: town.freeBeds > 0, action: homeAction, actionLabel: homeSite == nil ? "Open house tool" : "View housing construction"),
            SettlementLesson(id: "supply", title: "3. Follow the food",
                instruction: "Inspect the farm and market, then check Food Access. Total food alone is not enough: residents need a reachable market and money. Farms need fertile land, workers and a route to customers.",
                evidence: "\(town.hungryResidents) hungry; happiness \(town.happiness)% (arrival threshold \(happiness)%).",
                complete: population > 0 && town.hungryResidents == 0 && town.happiness >= happiness,
                action: .overlay(.foodAccess), actionLabel: "Check food access"),
            SettlementLesson(id: "arrivals", title: "4. See the town grow",
                instruction: "Let the days run. Housing, jobs, food and happiness must be ready when the arrival check occurs. If the population stalls, read the actual blocker rather than buying another building at random.",
                evidence: town.enabled ? "\(population) residents. The founding settlement started with 16." : "This older city's founding growth guide does not apply.",
                complete: !town.enabled || population > 16, action: .growth, actionLabel: "Check arrival conditions")
        ]
    }
}
