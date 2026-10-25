import Foundation

/// The only way the outside world (player, UI, later the AI layer) changes state.
/// The renderer never mutates the simulation -- it submits an intent and is told
/// whether it was accepted. Same rule SPEC v0.3 imposes on the LLM: one rule, two clients.
public enum PlayerIntent: Sendable, Equatable {
    case placeBuilding(BuildingKind, at: TileIndex)
    case buildRoad(at: TileIndex)
    case demolish(BuildingID)
    /// How a farm, workshop, or dock is run. Writes the same `OperatingMode` the
    /// placement commission already applies. It does not move money or food.
    case setOperatingMode(BuildingID, OperatingMode)
    case setPolicy(Policy)
    case resolveDecision(DecisionID, option: Int32)
    /// Answer anything on the standing agenda: a faction demand, an advisory, a
    /// decree, a placement commission or an election.
    case resolveAgendaItem(DecisionID, option: Int32)
}

public enum IntentRejection: String, Sendable, Equatable {
    case outOfBounds, notBuildable, occupied, notConnectedToRoad
    case insufficientTreasury, noSuchBuilding, cannotDemolishTownHall
    case noPendingDecision, decisionMismatch, invalidOption
    case noSuchAgendaItem
    case crisisPendingBlocksBuilding
    case operatingModeNotOffered
}

public enum IntentResult: Sendable, Equatable {
    case accepted
    case rejected(IntentRejection)
}

extension SimulationEngine {

    public static func apply(_ intent: PlayerIntent, to s: inout RepublicState) -> IntentResult {
        switch intent {

        case .placeBuilding(let kind, let tile):
            if s.pending != nil { return .rejected(.crisisPendingBlocksBuilding) }
            guard Int(tile.raw) >= 0 && Int(tile.raw) < s.map.tileCount else { return .rejected(.outOfBounds) }
            guard s.map.terrain(at: tile).buildable else { return .rejected(.notBuildable) }
            guard s.map.building(at: tile) == nil, !s.map.isRoad(at: tile) else { return .rejected(.occupied) }
            guard WorldGenerator.touchesRoad(s.map, tile) else { return .rejected(.notConnectedToRoad) }
            guard s.treasury >= kind.buildCost else { return .rejected(.insufficientTreasury) }

            s.transfer(from: .treasury, to: .external, kind.buildCost)
            let id = WorldGenerator.construct(&s, kind, at: tile)
            let site = EventLocation(district: s.map.district(at: tile), building: id, tile: tile)
            s.emit(.buildingConstructed, location: site, magnitude: Int32(kind.buildCost))
            if kind.offersCommission { raiseCommission(&s, building: id, at: site) }
            return .accepted

        case .buildRoad(let tile):
            if s.pending != nil { return .rejected(.crisisPendingBlocksBuilding) }
            guard Int(tile.raw) >= 0 && Int(tile.raw) < s.map.tileCount else { return .rejected(.outOfBounds) }
            guard s.map.terrain(at: tile).buildable else { return .rejected(.notBuildable) }
            guard s.map.building(at: tile) == nil else { return .rejected(.occupied) }
            if s.map.isRoad(at: tile) { return .accepted }
            guard s.treasury >= 10 else { return .rejected(.insufficientTreasury) }
            s.transfer(from: .treasury, to: .external, 10)
            s.map.road[Int(tile.raw)] = true
            s.fields.markDirty()
            return .accepted

        case .demolish(let id):
            guard Int(id.raw) >= 0 && Int(id.raw) < s.buildings.count else { return .rejected(.noSuchBuilding) }
            let b = s.buildings[Int(id.raw)]
            guard b.kind != .townHall else { return .rejected(.cannotDemolishTownHall) }
            // Food in the building is destroyed, and that is recorded rather than vanishing.
            s.spoilFood(at: id, b.foodStore)
            s.transfer(from: .building(id), to: .treasury, s.buildings[Int(id.raw)].funds)
            for cid in b.residents { s.citizens[Int(cid.raw)].home = nil }
            for cid in b.workers {
                s.citizens[Int(cid.raw)].work = nil
                s.citizens[Int(cid.raw)].occupation = .unemployed
            }
            s.buildings[Int(id.raw)].residents = []
            s.buildings[Int(id.raw)].workers = []
            s.map.buildingAt[Int(b.tile.raw)] = -1
            s.fields.markDirty()
            s.emit(.buildingAbandoned,
                   location: EventLocation(district: b.district, building: id, tile: b.tile))
            return .accepted

        case .setOperatingMode(let id, let mode):
            guard Int(id.raw) >= 0, Int(id.raw) < s.buildings.count else {
                return .rejected(.noSuchBuilding)
            }
            guard s.map.buildingAt.contains(id.raw) else { return .rejected(.noSuchBuilding) }
            guard s.buildings[Int(id.raw)].kind.offersCommission else {
                return .rejected(.operatingModeNotOffered)
            }
            s.buildings[Int(id.raw)].mode = mode
            return .accepted

        case .setPolicy(let p):
            s.policy = p
            s.emit(.dayAdvanced, causes: [CauseFactor(.policyChange, value: p.incomeTaxPercent,
                                                      detail: "income tax")])
            return .accepted

        case .resolveAgendaItem(let id, let option):
            guard let idx = s.agenda.firstIndex(where: { $0.id == id }) else {
                return .rejected(.noSuchAgendaItem)
            }
            let item = s.agenda[idx]
            guard let choice = item.options.first(where: { $0.id == option }) else {
                return .rejected(.invalidOption)
            }
            guard s.treasury >= choice.effect.treasuryCost else {
                return .rejected(.insufficientTreasury)
            }
            s.agenda.remove(at: idx)
            s.apply(choice.effect, at: item.location)
            if item.kind == .election {
                s.lastElectionDay = s.day
                s.emit(.electionHeld, location: item.location, causes: item.causes, magnitude: option)
            }
            s.emit(item.kind == .decree ? .decreeIssued : .agendaItemResolved,
                   location: item.location, causes: item.causes, magnitude: option)
            return .accepted

        case .resolveDecision(let did, let option):
            guard let pending = s.pending else { return .rejected(.noPendingDecision) }
            guard pending.id == did else { return .rejected(.decisionMismatch) }
            guard let chosen = pending.options.first(where: { $0.id == option }) else {
                return .rejected(.invalidOption)
            }
            resolve(pending, option: chosen, in: &s)
            return .accepted
        }
    }

    /// Push a district's unrest clear of the crisis threshold and start its cooldown.
    /// Suppression buys less time than conceding, but both must actually resolve the
    /// prompt -- otherwise it re-fires on the next tick.
    static func settle(_ s: inout RepublicState, _ did: DistrictID, relief: Int32) {
        let i = Int(did.raw)
        let ceiling = s.config.districtUnrestCrisisThreshold - s.config.crisisResolutionRelief
        s.districts[i].unrest = max(0, min(s.districts[i].unrest - relief, ceiling))
        s.districts[i].crisisCooldown = relief >= 45
            ? s.config.districtCrisisCooldownDays
            : s.config.districtCrisisCooldownDays / 2
    }

    static func resolve(_ d: PendingDecision, option: DecisionOption, in s: inout RepublicState) {
        if option.monetaryCost > 0 {
            s.transfer(from: .treasury, to: .external, option.monetaryCost)
        }
        switch (d.kind, option.id) {
        case (.districtUprising, 0):   // concede: fund the district
            if let did = d.location.district {
                settle(&s, did, relief: 45)
                s.districts[Int(did.raw)].neglectDays = 0
            }
            s.legitimacy = clamp(s.legitimacy + 8)
        case (.districtUprising, 1):   // suppress
            if let did = d.location.district {
                settle(&s, did, relief: 25)
            }
            s.legitimacy = clamp(s.legitimacy - 18)
            s.corruption = clamp(s.corruption + 6)
        case (.corruptionScandal, 0):
            s.corruption = clamp(s.corruption - 28)
            s.legitimacy = clamp(s.legitimacy + 10)
        case (.corruptionScandal, 1):
            s.corruption = clamp(s.corruption + 10)
            s.legitimacy = clamp(s.legitimacy - 15)
        case (.famine, 0):
            // Emergency import: money leaves, food enters, both recorded. Sized
            // against the population, so it actually relieves the shortage rather
            // than topping up one market for half a day.
            let alive = Int32(s.citizens.reduce(into: 0) { $0 += $1.alive ? 1 : 0 })
            let bought = max(200, alive * s.config.foodPerCitizenPerDay * 4)
            let markets = s.buildings.filter { $0.kind == .market }.map(\.id)
            if !markets.isEmpty {
                let share = bought / Int32(markets.count)
                var handed: Int32 = 0
                for m in markets {
                    s.buildings[Int(m.raw)].foodStore += share
                    handed += share
                }
                s.ledger.foodImported += Int64(handed)
            }
            // Clear the hunger counters the relief actually answers, so the same
            // crisis is not re-raised from stale state the next morning.
            for i in s.citizens.indices where s.citizens[i].alive {
                s.citizens[i].daysHungry = 0
            }
        case (.famine, 1):
            s.legitimacy = clamp(s.legitimacy - 12)
        case (.bankruptcy, 0):
            s.policy.incomeTaxPercent = min(60, s.policy.incomeTaxPercent + 10)
        case (.bankruptcy, 1):
            s.transfer(from: .external, to: .treasury, 1500)   // foreign loan
            s.legitimacy = clamp(s.legitimacy - 6)
        default:
            break
        }
        s.emit(.crisisResolved, location: d.location, causes: d.causes, magnitude: option.id)
        s.pending = nil
    }
}

extension SimulationEngine {
    /// A newly placed production building asks how it should be run, on the spot,
    /// so the tradeoff is attached to a place on the map rather than a menu.
    static func raiseCommission(_ s: inout RepublicState, building: BuildingID, at site: EventLocation) {
        var hard = AgendaEffect()
        hard.operatingMode = .intensive
        hard.favor(.merchants, 4)
        hard.favor(.labourers, -4)
        var clean = AgendaEffect()
        clean.operatingMode = .careful
        clean.favor(.labourers, 4)
        clean.favor(.merchants, -3)
        var steady = AgendaEffect()
        steady.operatingMode = .balanced

        s.agenda.append(AgendaItem(
            id: AgendaGenerator.nextID(&s), kind: .buildingCommission, tier: .advisory,
            raisedOnDay: s.day, expiresOnDay: s.day + s.config.advisoryExpiryDays,
            faction: nil, location: site,
            causes: [CauseFactor(.policyChange, value: 0, detail: "new works")],
            options: [AgendaOption(id: 0, label: "Run it hard", effect: hard),
                      AgendaOption(id: 1, label: "Run it clean", effect: clean),
                      AgendaOption(id: 2, label: "Run it steady", effect: steady)],
            salience: 30))
    }
}

@inlinable func clamp(_ n: Int32, _ lo: Int32 = 0, _ hi: Int32 = 100) -> Int32 {
    min(hi, max(lo, n))
}
