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
        if e.treasuryCost > 0 { transfer(from: .treasury, to: .external, e.treasuryCost) }
        if e.treasuryGain > 0 { transfer(from: .external, to: .treasury, e.treasuryGain) }

        if e.foodImport > 0 {
            // Food entering the world must be recorded, or conservation breaks.
            // A market that is still a building site cannot hold food, so walk past
            // it to one that is open rather than dropping the delivery.
            var target: BuildingID?
            let candidates = [
                location.building,
                buildings.first(where: {
                    $0.kind == .market && $0.district == location.district && $0.isOperational })?.id,
                buildings.first(where: { $0.kind == .market && $0.isOperational })?.id,
            ]
            for candidate in candidates {
                guard let c = candidate else { continue }
                let b = buildings[Int(c.raw)]
                if b.kind.storesFood && b.isOperational { target = c; break }
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
        } else if e.districtUnrest != 0 {
            for i in districts.indices {
                districts[i].unrest = clamp(districts[i].unrest + e.districtUnrest)
            }
        }

        for (n, f) in e.favorFactions.enumerated() where n < e.favorDeltas.count {
            let d = e.favorDeltas[n]
            factions[Int(f.rawValue)].adjust(d, on: day, reason: .policyChange, detail: "decision")
            if d > 0 { factions[Int(f.rawValue)].honouredDemands += 1 }
        }
    }
}
