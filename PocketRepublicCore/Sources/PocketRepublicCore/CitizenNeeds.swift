import Foundation

/// One current, actionable notice per living resident. A notice is derived from
/// real state, not a new debuff, opinion system or stored flag.
public struct CitizenAttention: Equatable, Sendable {
    public enum Kind: String, Sendable { case housing, food, work }
    public let kind: Kind
    public let title: String
    public let help: String
    public let priority: Int
}

public enum CitizenNeeds {
    /// Rebuild derived access once for a batch of map notices, never per frame.
    public static func notices(in state: RepublicState) -> [CitizenID: CitizenAttention] {
        var read = state
        if read.fields.dirty { SimulationEngine.rebuildSpatialCaches(&read) }
        return Dictionary(uniqueKeysWithValues: read.citizens.compactMap { citizen in
            attention(for: citizen.id, in: read).map { (citizen.id, $0) }
        })
    }

    public static func attention(for id: CitizenID, in state: RepublicState) -> CitizenAttention? {
        guard id.raw >= 0, Int(id.raw) < state.citizens.count else { return nil }
        let citizen = state.citizens[Int(id.raw)]
        guard citizen.id == id, citizen.alive else { return nil }
        if citizen.home == nil {
            return CitizenAttention(kind: .housing, title: "Needs a home", help: "Existing residents take completed spare homes automatically on the next daily update.", priority: 0)
        }
        if citizen.daysHungry > 0 {
            return CitizenAttention(kind: .food, title: "Needs food", help: foodExplanation(for: citizen, in: state), priority: 1)
        }
        if citizen.work == nil {
            return CitizenAttention(kind: .work, title: "Looking for work", help: "Residents take reachable standing vacancies automatically. Construction sites cannot hire yet.", priority: 2)
        }
        if let home = citizen.home, let work = citizen.work,
           Int(home.raw) >= 0, Int(home.raw) < state.buildings.count,
           Int(work.raw) >= 0, Int(work.raw) < state.buildings.count {
            var read = state
            if read.fields.dirty { SimulationEngine.rebuildSpatialCaches(&read) }
            if !read.fields.areConnected(read.buildings[Int(home.raw)].tile, read.buildings[Int(work.raw)].tile) {
                return CitizenAttention(kind: .work, title: "Work route blocked",
                    help: "This resident has a job but cannot plan a road trip to it. Connect the home and workplace street networks.", priority: 2)
            }
        }
        return nil
    }

    public static func foodExplanation(for citizen: Citizen, in state: RepublicState) -> String {
        guard let home = citizen.home else { return "No home yet. Provide completed housing so the household can reach a market." }
        var read = state
        if read.fields.dirty { SimulationEngine.rebuildSpatialCaches(&read) }
        guard let market = SimulationEngine.shoppingMarket(read, homeTile: read.buildings[Int(home.raw)].tile) else {
            return "No market within road reach. Connect the home to a standing market; importing food does not fix the road."
        }
        let need = read.config.foodPerCitizenPerDay
        if read.buildings[Int(market.raw)].foodStore < need {
            return "The reachable market lacks a daily meal's stock. Check farm staffing and deliveries, or import food."
        }
        let price = Int64(need) * read.config.foodPrice
        if citizen.money < price {
            return "Market food is available, but this resident has $\(citizen.money) and a daily meal costs $\(price). Check work and wages."
        }
        return "Road access, stock and cash are sufficient now. Hunger records the last daily meal; check again after the next daily update."
    }
}
