import Foundation

/// Read-only arrival conditions. Rebuilds derived access on a copy, never the save.
public struct SettlementOutlook: Sendable {
    public let enabled: Bool
    public let population: Int
    public let happiness: Int
    public let requiredHappiness: Int
    public let hungryResidents: Int
    public let freeBeds: Int
    public let openJobs: Int
    public let foodReserveRequired: Int64
    public let nextArrivalDay: Int32?
    public let expectedArrivals: Int
    public let unhousedResidents: Int
    public let availableArrivalJobs: Int
    public let blockers: [String]
    public var ready: Bool { enabled && expectedArrivals > 0 && blockers.isEmpty }

    public init(state: RepublicState) {
        var read = state
        if read.fields.dirty { SimulationEngine.rebuildSpatialCaches(&read) }
        let living = read.citizens.filter(\.alive)
        population = living.count
        unhousedResidents = living.filter { $0.home == nil }.count
        var prepared = read
        SimulationEngine.assignHomes(&prepared)
        SimulationEngine.assignWork(&prepared)
        availableArrivalJobs = prepared.buildings.filter { $0.isStanding(on: prepared.map) }
            .reduce(0) { $0 + max(0, Int($1.kind.workerCapacity) - $1.workers.count) }
        happiness = living.isEmpty ? 0 : Int(living.reduce(Int64(0)) { $0 + Int64($1.happiness) } / Int64(living.count))
        hungryResidents = living.filter { $0.daysHungry > 0 }.count
        let houses = read.buildings.filter { $0.kind == .house && $0.isStanding(on: read.map) }
        let jobs = read.buildings.filter { $0.isStanding(on: read.map) && $0.workers.count < Int($0.kind.workerCapacity) }
        freeBeds = houses.reduce(0) { $0 + max(0, Int($1.kind.housingCapacity) - $1.residents.count) }
        openJobs = jobs.reduce(0) { $0 + max(0, Int($1.kind.workerCapacity) - $1.workers.count) }
        guard let rules = read.config.settlementGrowth else {
            enabled = false; requiredHappiness = 0; foodReserveRequired = 0
            nextArrivalDay = nil; blockers = []; expectedArrivals = 0
            return
        }
        enabled = true
        requiredHappiness = Int(rules.minimumHappiness)
        let reserve = Int64(population + 1) * Int64(max(1, rules.foodReserveDays)) * Int64(read.config.foodPerCitizenPerDay)
        foodReserveRequired = reserve
        let interval = rules.arrivalIntervalDays
        expectedArrivals = interval > 0 ? SettlementAdmissionPlan.homes(in: prepared).count : 0
        nextArrivalDay = interval > 0 && rules.arrivalsPerWave > 0 ? read.day + interval - read.day % interval : nil
        var issues: [String] = []
        if interval <= 0 || rules.arrivalsPerWave <= 0 { issues.append("Arrivals are disabled by this city's rules.") }
        if living.isEmpty { issues.append("The settlement needs existing residents before it can attract newcomers.") }
        if freeBeds == 0 { issues.append("Housing full — build another house.") }
        if availableArrivalJobs == 0 {
            issues.append(openJobs > 0
                ? "Existing residents need the current vacancies first — open more jobs for newcomers."
                : "No open jobs — add a workplace.")
        }
        if prepared.citizens.contains(where: { $0.alive && $0.home == nil }) {
            issues.append("House existing residents first — completed spare homes are filled automatically on the next day.")
        } else if unhousedResidents > 0 && expectedArrivals == 0 && freeBeds > 0 {
            issues.append("Existing residents have first priority for the spare beds.")
        }
        if hungryResidents > 0 { issues.append("Feed all residents — check market stock and road access.") }
        if happiness < requiredHappiness { issues.append("Happiness \(happiness)% — newcomers need at least \(requiredHappiness)%.") }
        let availableHomes = prepared.buildings.filter { $0.kind == .house && $0.isStanding(on: prepared.map) && $0.residents.count < Int($0.kind.housingCapacity) }
        let forecastJobs = prepared.buildings.filter { $0.isStanding(on: prepared.map) && $0.workers.count < Int($0.kind.workerCapacity) }
        let connectedHomes = availableHomes.filter { home in
            forecastJobs.contains { prepared.fields.areConnected(home.tile, $0.tile) }
        }
        if !availableHomes.isEmpty && availableArrivalJobs > 0 && connectedHomes.isEmpty {
            issues.append("Connect spare homes to open workplaces with roads.")
        }
        if !connectedHomes.isEmpty && !connectedHomes.contains(where: { home in
            guard let market = SimulationEngine.shoppingMarket(read, homeTile: home.tile) else { return false }
            return Int64(read.buildings[Int(market.raw)].foodStore) >= reserve
        }) {
            issues.append("A spare home needs a reachable market holding at least \(foodReserveRequired) food for the first newcomer.")
        }
        if expectedArrivals == 0 && issues.isEmpty {
            issues.append("Keep a spare home, a reachable job and enough market food ready together.")
        }
        blockers = issues
    }
}
