import Foundation

extension SimulationEngine {
    /// Existing residents get first use of completed spare homes. Stable citizen
    /// and building order makes the recovery replayable; no relocation fee,
    /// grant, population change or RNG draw is involved.
    static func assignHomes(_ state: inout RepublicState) {
        var moved: [CitizenID] = []
        for i in state.citizens.indices where state.citizens[i].alive && state.citizens[i].home == nil {
            let work = state.citizens[i].work
            let homes = state.buildings.filter {
                $0.kind == .house && $0.isStanding(on: state.map)
                    && $0.residents.count < Int($0.kind.housingCapacity)
            }
            // Preserve the existing commute, then prefer access to food. Stable
            // id breaks ties. A bare but completed home is still shelter.
            func rank(_ home: Building) -> Int {
                let food = shoppingMarket(state, homeTile: home.tile) != nil
                let commute = work.map { id in
                    Int(id.raw) >= 0 && Int(id.raw) < state.buildings.count
                        && state.fields.areConnected(home.tile, state.buildings[Int(id.raw)].tile)
                } ?? true
                return (commute ? 0 : 2) + (food ? 0 : 1)
            }
            guard let home = homes.min(by: { a, b in
                let ra = rank(a), rb = rank(b)
                return ra == rb ? a.id < b.id : ra < rb
            }) else { break }
            state.citizens[i].home = home.id
            state.citizens[i].district = home.district
            state.buildings[Int(home.id.raw)].residents.append(state.citizens[i].id)
            moved.append(state.citizens[i].id)
        }
        if !moved.isEmpty {
            state.fields.markDirty()
            rebuildSpatialCaches(&state)
            state.emit(.citizenHoused, subjects: moved,
                       causes: [CauseFactor(.policyChange, value: Int32(moved.count),
                           detail: "Existing residents moved into completed spare homes")],
                       magnitude: Int32(moved.count))
        }
    }
}

/// One source of truth for capacity reserved across a newcomer wave. This is
/// unsaved derived data, consumed by both admission and the readiness reader.
enum SettlementAdmissionPlan {
    static func homes(in state: RepublicState) -> [BuildingID] {
        guard let rules = state.config.settlementGrowth, rules.arrivalsPerWave > 0 else { return [] }
        let living = state.citizens.filter(\.alive)
        guard !living.isEmpty, living.allSatisfy({ $0.home != nil && $0.daysHungry == 0 }),
              living.reduce(Int64(0), { $0 + Int64($1.happiness) }) / Int64(living.count)
                >= Int64(rules.minimumHappiness) else { return [] }
        let jobs = state.buildings.filter { $0.isStanding(on: state.map) && $0.kind.workerCapacity > 0 }
        var vacancies = jobs.map { max(0, Int($0.kind.workerCapacity) - $0.workers.count) }
        let houses = state.buildings.filter { $0.kind == .house && $0.isStanding(on: state.map) }
        var beds = houses.map { max(0, Int($0.kind.housingCapacity) - $0.residents.count) }
        var result: [BuildingID] = []
        // Real capacity bounds malformed/custom wave sizes without changing
        // valid configuration behavior or allocating an unbounded array.
        let limit = min(Int(rules.arrivalsPerWave), beds.reduce(0, +), vacancies.reduce(0, +))
        for _ in 0..<limit {
            let reserve = Int64(living.count + result.count + 1) * Int64(max(1, rules.foodReserveDays))
                * Int64(state.config.foodPerCitizenPerDay)
            guard let h = houses.indices.first(where: { index in
                guard beds[index] > 0,
                      let market = SimulationEngine.shoppingMarket(state, homeTile: houses[index].tile),
                      Int64(state.buildings[Int(market.raw)].foodStore) >= reserve else { return false }
                return jobs.indices.contains { vacancies[$0] > 0 && state.fields.areConnected(houses[index].tile, jobs[$0].tile) }
            }), let j = jobs.indices.first(where: {
                vacancies[$0] > 0 && state.fields.areConnected(houses[h].tile, jobs[$0].tile)
            }) else { break }
            beds[h] -= 1; vacancies[j] -= 1
            result.append(houses[h].id)
        }
        return result
    }
}
