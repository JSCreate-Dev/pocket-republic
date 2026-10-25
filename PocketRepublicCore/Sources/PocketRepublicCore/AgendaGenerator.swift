import Foundation

/// Builds the per-tick decision stream.
///
/// The design target is that the player always has something worth doing, without
/// manufacturing fake emergencies. Four sources, in descending urgency:
///
///   1. crises      - rare, blocking, already handled by the crisis evaluator
///   2. faction demands  - a real grievance held by a real group; ignoring costs favor
///   3. advisories  - a drifting district number, framed as a choice while it is cheap
///   4. decrees     - standing, player-initiated, always available
///
/// Only the last is unconditional, and that is deliberate: it is what makes
/// "something every tick" true by construction instead of by crisis spam.
public enum AgendaGenerator {

    public static func update(_ s: inout RepublicState) {
        expire(&s)
        electionCheck(&s)
        if s.pending == nil && !s.agenda.contains(where: { $0.tier == .crisis }) {
            topUp(&s)
        }
    }

    // MARK: - Expiry

    static func expire(_ s: inout RepublicState) {
        var survivors: [AgendaItem] = []
        survivors.reserveCapacity(s.agenda.count)
        for item in s.agenda {
            if item.isLive(on: s.day) {
                survivors.append(item)
                continue
            }
            // Letting a demand lapse is a real, remembered cost -- but never fatal.
            if item.ignoreCost > 0, let f = item.faction {
                let i = Int(f.rawValue)
                s.factions[i].adjust(-item.ignoreCost, on: s.day,
                                     reason: item.causes.first?.kind ?? .districtNeglect,
                                     detail: "demand ignored")
                s.factions[i].ignoredDemands += 1
                s.emit(.factionDemandIgnored, location: item.location,
                       causes: item.causes, magnitude: item.ignoreCost)
            }
        }
        s.agenda = survivors
    }

    // MARK: - Top-up

    static func topUp(_ s: inout RepublicState) {
        let target = Int(max(1, s.config.agendaTargetSize))
        guard s.agenda.count < target else { return }

        var candidates: [AgendaItem] = []
        candidates.append(contentsOf: factionDemands(&s))
        candidates.append(contentsOf: advisories(&s))
        candidates.sort { $0.salience == $1.salience ? $0.id.raw < $1.id.raw : $0.salience > $1.salience }

        for c in candidates where s.agenda.count < target {
            guard !s.agenda.contains(where: { $0.kind == c.kind && $0.faction == c.faction
                                              && $0.location.district == c.location.district }) else { continue }
            s.agenda.append(c)
            if let f = c.faction, c.kind == .factionDemand {
                s.factions[Int(f.rawValue)].lastDemandDay = s.day
                s.emit(.factionDemandRaised, location: c.location, causes: c.causes)
            }
        }

        // Floor guarantee. Decrees are standing offers, so there is always at
        // least one actionable thing even in a perfectly run republic.
        if s.agenda.count < target {
            for d in decrees(&s) where s.agenda.count < target {
                guard !s.agenda.contains(where: { $0.kind == .decree && $0.options.first?.label == d.options.first?.label })
                else { continue }
                s.agenda.append(d)
            }
        }
    }

    // MARK: - Faction demands

    static func factionDemands(_ s: inout RepublicState) -> [AgendaItem] {
        var out: [AgendaItem] = []
        let cfg = s.config
        for f in s.factions {
            guard f.members > 0,
                  let concern = f.dominantConcern,
                  s.day - f.lastDemandDay >= cfg.factionDemandCooldownDays else { continue }

            let worst = neediestDistrict(s, for: concern)
            let causes = [CauseFactor(concern, value: f.concernWeight, detail: f.kind.displayName)]
            var options: [AgendaOption] = []

            switch concern {
            case .foodShortage:
                var give = AgendaEffect()
                give.treasuryCost = 260
                give.foodImport = 180
                give.favor(f.kind, 8)
                give.favor(.merchants, -3)
                options = [AgendaOption(id: 0, label: "Buy in grain and hand it out", effect: give),
                           AgendaOption(id: 1, label: "Tell them the stores will hold", effect: refuse(f.kind))]
            case .unemployment:
                var work = AgendaEffect()
                work.treasuryCost = 320
                work.favor(f.kind, 9)
                work.districtUnrest = -12
                work.legitimacy = 2
                options = [AgendaOption(id: 0, label: "Fund a public works gang", effect: work),
                           AgendaOption(id: 1, label: "Leave it to the private yards", effect: refuse(f.kind))]
            case .taxBurden:
                var cut = AgendaEffect()
                cut.incomeTaxDelta = -4
                cut.favor(f.kind, 7)
                cut.favor(.officials, -4)
                options = [AgendaOption(id: 0, label: "Cut the income levy four points", effect: cut),
                           AgendaOption(id: 1, label: "Hold the rate", effect: refuse(f.kind))]
            case .noPoliceAccess, .corruption:
                var police = AgendaEffect()
                police.treasuryCost = 240
                police.corruption = -8
                police.favor(f.kind, 7)
                police.favor(.landless, -4)
                options = [AgendaOption(id: 0, label: "Put more constables on the street", effect: police),
                           AgendaOption(id: 1, label: "Ignore the complaint", effect: refuse(f.kind))]
            case .noMarketAccess, .noClinicAccess, .districtNeglect:
                var fund = AgendaEffect()
                fund.treasuryCost = 300
                fund.districtNeglectReset = true
                fund.districtUnrest = -14
                fund.favor(f.kind, 8)
                options = [AgendaOption(id: 0, label: "Commission services for the quarter", effect: fund),
                           AgendaOption(id: 1, label: "Promise it for next season", effect: refuse(f.kind))]
            case .poverty:
                var dole = AgendaEffect()
                dole.treasuryCost = 200
                dole.favor(f.kind, 8)
                dole.favor(.merchants, -4)
                dole.districtUnrest = -8
                options = [AgendaOption(id: 0, label: "Open a relief fund", effect: dole),
                           AgendaOption(id: 1, label: "Refuse the dole", effect: refuse(f.kind))]
            case .treasuryDeficit, .policyChange:
                continue
            }

            out.append(AgendaItem(
                id: nextID(&s), kind: .factionDemand, tier: .demand, raisedOnDay: s.day,
                expiresOnDay: s.day + cfg.demandExpiryDays, faction: f.kind,
                location: EventLocation(district: worst), causes: causes, options: options,
                ignoreCost: cfg.ignoredDemandFavorCost,
                salience: 40 + f.concernWeight - max(0, f.favor / 4)))
        }
        return out
    }

    static func refuse(_ f: FactionKind) -> AgendaEffect {
        var e = AgendaEffect()
        e.favor(f, -4)
        return e
    }

    // MARK: - Advisories

    static func advisories(_ s: inout RepublicState) -> [AgendaItem] {
        var out: [AgendaItem] = []
        let cfg = s.config
        for d in s.districts where d.population > 0 {
            // Surface a number while it is still drifting, not once it detonates.
            if d.unrest >= cfg.advisoryUnrestFloor && d.unrest < cfg.districtUnrestCrisisThreshold {
                var wages = AgendaEffect()
                wages.civicWageDelta = 1
                wages.districtUnrest = -10
                wages.favor(.labourers, 5)
                wages.favor(.merchants, -3)
                var constables = AgendaEffect()
                constables.treasuryCost = 180
                constables.districtUnrest = -14
                constables.corruption = -3
                constables.favor(.officials, 4)
                constables.favor(.landless, -3)
                out.append(AgendaItem(
                    id: nextID(&s), kind: .advisoryTradeoff, tier: .advisory, raisedOnDay: s.day,
                    expiresOnDay: s.day + cfg.advisoryExpiryDays, faction: nil,
                    location: EventLocation(district: d.id),
                    causes: [CauseFactor(.districtNeglect, value: d.unrest, detail: d.name)],
                    options: [AgendaOption(id: 0, label: "Raise the civic wage", effect: wages),
                              AgendaOption(id: 1, label: "Station constables in \(d.name)", effect: constables),
                              AgendaOption(id: 2, label: "Let it ride", effect: AgendaEffect())],
                    salience: 20 + d.unrest / 2))
            }
            if d.unemployedCount * 100 / max(1, d.population) >= cfg.advisoryUnemploymentPercent {
                var yards = AgendaEffect()
                yards.treasuryCost = 220
                yards.favor(.labourers, 5)
                yards.districtUnrest = -8
                var relief = AgendaEffect()
                relief.treasuryCost = 140
                relief.favor(.landless, 6)
                relief.favor(.merchants, -3)
                out.append(AgendaItem(
                    id: nextID(&s), kind: .advisoryTradeoff, tier: .advisory, raisedOnDay: s.day,
                    expiresOnDay: s.day + cfg.advisoryExpiryDays, faction: nil,
                    location: EventLocation(district: d.id),
                    causes: [CauseFactor(.unemployment, value: d.unemployedCount, detail: d.name)],
                    options: [AgendaOption(id: 0, label: "Subsidise the yards in \(d.name)", effect: yards),
                              AgendaOption(id: 1, label: "Pay direct relief instead", effect: relief),
                              AgendaOption(id: 2, label: "Do nothing this week", effect: AgendaEffect())],
                    salience: 18 + d.unemployedCount))
            }
        }
        return out
    }

    // MARK: - Decrees (always available)

    static func decrees(_ s: inout RepublicState) -> [AgendaItem] {
        var out: [AgendaItem] = []
        for spec in DecreeCatalogue.all where spec.cost <= s.treasury {
            var enact = spec.effect
            enact.treasuryCost = spec.cost
            out.append(AgendaItem(
                id: nextID(&s), kind: .decree, tier: .decree, raisedOnDay: s.day,
                expiresOnDay: nil, faction: nil, location: EventLocation(),
                causes: [CauseFactor(.policyChange, value: Int32(clamping: spec.cost), detail: spec.name)],
                options: [AgendaOption(id: 0, label: spec.name, effect: enact),
                          AgendaOption(id: 1, label: "Not now", effect: AgendaEffect())],
                salience: spec.salience))
        }
        // Rotate so the standing offers are not identical every single day. The
        // draw comes from the seeded stream, so replays stay identical.
        if out.count > 1 {
            let pivot = s.rng.int(0...(out.count - 1))
            out = Array(out[pivot...]) + Array(out[..<pivot])
        }
        return out
    }

    // MARK: - Elections

    static func electionCheck(_ s: inout RepublicState) {
        let interval = max(1, s.config.electionIntervalDays)
        guard s.day > 0, s.day % interval == 0,
              !s.agenda.contains(where: { $0.kind == .election }) else { return }

        // The periodic checkpoint that totals up how the republic has been run.
        let mandate = s.legitimacy + s.factions.reduce(into: Int32(0)) { $0 += $1.favor } / 4
        var causes: [CauseFactor] = [CauseFactor(.policyChange, value: mandate, detail: "mandate")]
        for f in s.factions where f.members > 0 {
            causes.append(CauseFactor(.policyChange, value: f.favor, detail: f.kind.displayName))
        }

        var honest = AgendaEffect()
        honest.legitimacy = mandate >= 50 ? 12 : -14
        honest.favor(.officials, 4)
        var buy = AgendaEffect()
        buy.treasuryCost = 900
        buy.legitimacy = 6
        buy.corruption = 12
        buy.favor(.merchants, 6)
        buy.favor(.landless, -6)
        var postpone = AgendaEffect()
        postpone.legitimacy = -20
        postpone.corruption = 8
        postpone.favor(.officials, -8)
        postpone.favor(.labourers, -8)

        s.agenda.append(AgendaItem(
            id: nextID(&s), kind: .election, tier: .crisis, raisedOnDay: s.day,
            expiresOnDay: nil, faction: nil, location: EventLocation(), causes: causes,
            options: [AgendaOption(id: 0, label: "Stand on the record", effect: honest),
                      AgendaOption(id: 1, label: "Spend freely on the campaign", effect: buy),
                      AgendaOption(id: 2, label: "Postpone the vote", effect: postpone)],
            salience: 100))
        s.emit(.electionCalled, location: EventLocation(), causes: causes, magnitude: mandate)
    }

    // MARK: - Helpers

    static func neediestDistrict(_ s: RepublicState, for concern: CauseKind) -> DistrictID? {
        let populated = s.districts.filter { $0.population > 0 }
        guard !populated.isEmpty else { return nil }
        switch concern {
        case .foodShortage:
            return populated.max { $0.hungryCount < $1.hungryCount }?.id
        case .unemployment, .poverty:
            return populated.max { $0.unemployedCount < $1.unemployedCount }?.id
        case .noMarketAccess:
            return populated.min { $0.marketCoverage < $1.marketCoverage }?.id
        case .noClinicAccess:
            return populated.min { $0.clinicCoverage < $1.clinicCoverage }?.id
        case .noPoliceAccess, .corruption:
            return populated.min { $0.policeCoverage < $1.policeCoverage }?.id
        default:
            return populated.max { $0.unrest < $1.unrest }?.id
        }
    }

    static func nextID(_ s: inout RepublicState) -> DecisionID {
        let id = DecisionID(s.nextDecisionRaw)
        s.nextDecisionRaw += 1
        return id
    }
}
