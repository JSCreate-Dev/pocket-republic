import Foundation

/// Standing decrees the player may issue unprompted. This is the Tropico trick:
/// agency that does not wait to be asked for. Pure data, so the design lead can
/// add, retune or remove decrees without touching engine code.
public struct DecreeSpec: Sendable {
    public let name: String
    public let cost: Int64
    public let salience: Int32
    public let effect: AgendaEffect
}

public enum DecreeCatalogue {
    public static let all: [DecreeSpec] = [
        {
            var e = AgendaEffect()
            e.foodImport = 140
            e.favor(.landless, 6); e.favor(.labourers, 3); e.favor(.merchants, -4)
            return DecreeSpec(name: "Decree bread rationing", cost: 220, salience: 12, effect: e)
        }(),
        {
            var e = AgendaEffect()
            e.districtUnrest = -10
            e.favor(.merchants, 6); e.favor(.labourers, 3)
            return DecreeSpec(name: "Proclaim a market festival", cost: 180, salience: 10, effect: e)
        }(),
        {
            var e = AgendaEffect()
            e.corruption = -10; e.legitimacy = 4
            e.favor(.officials, -7); e.favor(.landless, 5); e.favor(.labourers, 4)
            return DecreeSpec(name: "Purge the graft registers", cost: 260, salience: 11, effect: e)
        }(),
        {
            var e = AgendaEffect()
            e.civicWageDelta = 1
            e.favor(.officials, 7); e.favor(.merchants, -4)
            return DecreeSpec(name: "Raise the civic wage", cost: 0, salience: 9, effect: e)
        }(),
        {
            var e = AgendaEffect()
            e.incomeTaxDelta = -3
            e.favor(.labourers, 5); e.favor(.merchants, 5); e.favor(.officials, -3)
            return DecreeSpec(name: "Declare a tax holiday", cost: 0, salience: 9, effect: e)
        }(),
        {
            var e = AgendaEffect()
            e.incomeTaxDelta = 3
            e.favor(.labourers, -5); e.favor(.merchants, -5); e.favor(.officials, 3)
            return DecreeSpec(name: "Levy an emergency rate", cost: 0, salience: 8, effect: e)
        }(),
        {
            var e = AgendaEffect()
            e.districtUnrest = -16; e.legitimacy = -6; e.corruption = 4
            e.favor(.officials, 5); e.favor(.landless, -8); e.favor(.labourers, -4)
            return DecreeSpec(name: "Impose a night curfew", cost: 120, salience: 8, effect: e)
        }(),
        {
            var e = AgendaEffect()
            e.districtNeglectReset = true; e.districtUnrest = -8; e.legitimacy = 3
            e.favor(.labourers, 6)
            return DecreeSpec(name: "Order a public works season", cost: 340, salience: 10, effect: e)
        }(),
    ]
}

extension RepublicState {
    /// Single application path for every agenda option, crisis or decree alike.
    /// Keeping this generic is what stops the decision stream from turning into a
    /// thousand-arm switch as content grows.
    mutating func apply(_ e: AgendaEffect, at location: EventLocation) {
        var gain = e.treasuryGain
        if let requested = e.foodExport, requested > 0 {
            let shipped = exportFood(upTo: requested, preferring: location)
            if shipped < requested {
                gain = gain * Int64(shipped) / Int64(max(1, requested))
            }
        }
        if e.treasuryCost > 0 { transfer(from: .treasury, to: .external, e.treasuryCost) }
        if gain > 0 { transfer(from: .external, to: .treasury, gain) }

        if e.foodImport > 0 {
            // Food entering the world must be recorded, or conservation breaks.
            // A market that is still a site, or one that has been demolished, cannot
            // hold food, so walk past it to one that is open.
            var target: BuildingID?
            let candidates = [
                location.building,
                buildings.first(where: {
                    $0.kind == .market && $0.district == location.district && $0.isStanding(on: map) })?.id,
                buildings.first(where: { $0.kind == .market && $0.isStanding(on: map) })?.id,
            ]
            for candidate in candidates {
                guard let c = candidate else { continue }
                let b = buildings[Int(c.raw)]
                if b.kind.storesFood && b.isStanding(on: map) { target = c; break }
            }
            if let t = target {
                buildings[Int(t.raw)].foodStore += e.foodImport
                ledger.foodImported += Int64(e.foodImport)
            }
        }

        if let mode = e.operatingMode, let b = location.building {
            buildings[Int(b.raw)].mode = mode
        }
        if e.legitimacy != 0 { legitimacy = clamp(legitimacy + e.legitimacy) }
        if e.corruption != 0 { corruption = clamp(corruption + e.corruption) }
        if e.incomeTaxDelta != 0 {
            policy.incomeTaxPercent = max(0, min(80, policy.incomeTaxPercent + e.incomeTaxDelta))
        }
        if e.businessTaxDelta != 0 {
            policy.businessTaxPercent = max(0, min(80, policy.businessTaxPercent + e.businessTaxDelta))
        }
        if e.civicWageDelta != 0 { policy.civicWage = max(0, policy.civicWage + e.civicWageDelta) }

        if let did = location.district {
            let i = Int(did.raw)
            if e.districtUnrest != 0 {
                districts[i].unrest = clamp(districts[i].unrest + e.districtUnrest)
            }
            if e.districtNeglectReset { districts[i].neglectDays = 0 }
        } else {
            for i in districts.indices {
                if e.districtUnrest != 0 { districts[i].unrest = clamp(districts[i].unrest + e.districtUnrest) }
                if e.districtNeglectReset { districts[i].neglectDays = 0 }
            }
        }

        for (n, f) in e.favorFactions.enumerated() where n < e.favorDeltas.count {
            let d = e.favorDeltas[n]
            factions[Int(f.rawValue)].adjust(d, on: day, reason: .policyChange, detail: "decision")
            if d > 0 { factions[Int(f.rawValue)].honouredDemands += 1 }
        }
    }
}


extension DecreeCatalogue {
    public static func nextAvailableDay(_ name: String, in state: RepublicState) -> Int32? {
        guard let last = state.decreeLastIssued?[name] else { return nil }
        let next = last + state.config.effectiveDecreeCooldownDays
        return next > state.day ? next : nil
    }

    public static func unavailableReason(for spec: DecreeSpec, in state: RepublicState) -> String? {
        if state.blocksAdvance { return "Resolve the blocking council decision first." }
        if let day = nextAvailableDay(spec.name, in: state) { return "Available again on Day \(day)." }
        let cost = max(spec.cost, spec.effect.treasuryCost)
        if state.treasury < cost { return "Need $\(cost - state.treasury) more in the treasury." }
        if spec.effect.foodImport > 0 && !state.buildings.contains(where: { $0.kind == .market && $0.isStanding(on: state.map) }) {
            return "Open a market before importing food."
        }
        return nil
    }
}

extension SimulationEngine {
    /// Direct button and council offer share one validated application path.
    static func enactStandingDecree(_ name: String, in state: inout RepublicState) -> IntentResult {
        guard let spec = DecreeCatalogue.all.first(where: { $0.name == name }) else { return .rejected(.decreeUnavailable) }
        if DecreeCatalogue.nextAvailableDay(name, in: state) != nil { return .rejected(.decreeCoolingDown) }
        let cost = max(spec.cost, spec.effect.treasuryCost)
        guard state.treasury >= cost else { return .rejected(.insufficientTreasury) }
        guard DecreeCatalogue.unavailableReason(for: spec, in: state) == nil else { return .rejected(.decreeUnavailable) }
        var effect = spec.effect
        effect.treasuryCost = cost
        state.apply(effect, at: EventLocation())
        if state.decreeLastIssued == nil { state.decreeLastIssued = [:] }
        state.decreeLastIssued?[name] = state.day
        state.agenda.removeAll { $0.kind == .decree && $0.causes.contains { $0.detail == name } }
        state.emit(.decreeIssued, causes: [CauseFactor(.policyChange, value: Int32(clamping: cost), detail: name)])
        return .accepted
    }
}
