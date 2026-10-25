import Foundation

/// Pure, discrete, deterministic day tick. No Date(), no persistence, no rendering.
/// `advance` is a total function of (state) -> (state', events).
public enum SimulationEngine {

    /// Advance one simulated day. Returns the events emitted by this tick.
    /// A pending crisis halts time: the player must resolve it first.
    @discardableResult
    public static func advance(_ s: inout RepublicState) -> [GameEvent] {
        // Only crises and elections hold up the clock. Demands, advisories and
        // decrees sit on the agenda without blocking play.
        guard !s.blocksAdvance else { return [] }
        let firstNewEvent = s.events.count

        s.day += 1
        if s.fields.dirty { rebuildSpatialCaches(&s) }

        assignWork(&s)
        produce(&s)
        distributeFood(&s)
        payWages(&s)
        feedCitizens(&s)
        collectTaxes(&s)
        payUpkeep(&s)
        spoil(&s)
        updateWellbeing(&s)
        aggregateDistricts(&s)
        updateFactions(&s)
        updateNationalMood(&s)
        evaluateCrises(&s)
        AgendaGenerator.update(&s)

        return Array(s.events[firstNewEvent...])
    }

    // MARK: - Spatial caches (structural change only, never per tick)

    static func rebuildSpatialCaches(_ s: inout RepublicState) {
        s.fields.rebuild(map: s.map, buildings: s.buildings)
        // Resolve each district's market from an actual inhabited tile. The raw
        // centroid is usually bare ground, which is impassable and therefore
        // connected to nothing -- that silently starved whole districts.
        for i in s.districts.indices {
            let did = s.districts[i].id
            let house = s.buildings.first { $0.kind == .house && $0.district == did && !$0.residents.isEmpty }
            s.districts[i].servingMarket = house.flatMap { s.fields.nearestMarket(at: $0.tile) }
        }
    }

    static func manhattan(_ m: WorldMap, _ a: TileIndex, _ b: TileIndex) -> Int32 {
        abs(m.x(of: a) - m.x(of: b)) + abs(m.y(of: a) - m.y(of: b))
    }

    // MARK: - Employment

    static func assignWork(_ s: inout RepublicState) {
        var openings: [(BuildingID, TileIndex, Int32)] = []
        for b in s.buildings where b.kind.workerCapacity > Int32(b.workers.count) {
            openings.append((b.id, b.tile, b.kind.workerCapacity - Int32(b.workers.count)))
        }
        guard !openings.isEmpty else { return }

        for i in s.citizens.indices {
            guard s.citizens[i].alive, s.citizens[i].work == nil,
                  let home = s.citizens[i].home else { continue }
            let homeTile = s.buildings[Int(home.raw)].tile

            var bestIdx = -1
            var bestDist = Int32.max
            for (k, o) in openings.enumerated() where o.2 > 0 {
                guard s.fields.areConnected(homeTile, o.1) else { continue }
                let d = manhattan(s.map, homeTile, o.1)
                if d < bestDist { bestDist = d; bestIdx = k }
            }
            guard bestIdx >= 0 else { continue }

            let (bid, _, left) = openings[bestIdx]
            openings[bestIdx].2 = left - 1
            s.citizens[i].work = bid
            s.citizens[i].occupation = Occupation.forEmployer(s.buildings[Int(bid.raw)].kind)
            s.citizens[i].daysUnemployed = 0
            s.buildings[Int(bid.raw)].workers.append(s.citizens[i].id)
            s.emit(.citizenEmployed,
                   location: EventLocation(district: s.buildings[Int(bid.raw)].district, building: bid),
                   subjects: [s.citizens[i].id])
        }
    }

    // MARK: - Production

    static func produce(_ s: inout RepublicState) {
        for i in s.buildings.indices {
            let b = s.buildings[i]
            let workers = Int32(b.workers.count)
            guard workers > 0 else { continue }
            let scale = Int64(b.mode.outputPercent)
            switch b.kind {
            case .farm:
                let covered = b.tilesCovered(on: s.map)
                let fertile = covered.reduce(into: 0) { count, tile in
                    if s.map.terrain(at: tile) == .fertile { count += 1 }
                }
                let bonus = !covered.isEmpty && fertile * 2 >= covered.count
                    ? s.config.fertileBonus : 0
                let yield = Int64(workers * (s.config.farmYieldPerWorker + bonus)) * scale / 100
                s.produceFood(at: b.id, Int32(yield))
            case .workshop, .dock:
                // Exports: the only money entering the island, and it is recorded.
                s.transfer(from: .external, to: .building(b.id),
                           Int64(workers) * s.config.workshopOutputPerWorker * scale / 100)
            default:
                break
            }
            if b.mode.unrestPerDay != 0 {
                let d = Int(b.district.raw)
                s.districts[d].unrest = clamp(s.districts[d].unrest + b.mode.unrestPerDay)
            }
        }
    }

    /// Farms sell to the nearest road-connected market. Food moves, money moves back.
    static func distributeFood(_ s: inout RepublicState) {
        let markets = s.buildings.filter { $0.kind == .market }
        guard !markets.isEmpty else { return }
        for i in s.buildings.indices where s.buildings[i].kind == .farm {
            let farm = s.buildings[i]
            guard farm.foodStore > 0 else { continue }
            guard let market = markets
                .filter({ s.fields.areConnected(farm.tile, $0.tile) })
                .min(by: { manhattan(s.map, farm.tile, $0.tile) < manhattan(s.map, farm.tile, $1.tile) })
            else { continue }

            let moved = s.shipFood(from: farm.id, to: market.id,
                                   min(farm.foodStore, s.config.farmToMarketShipPerDay))
            if moved > 0 {
                s.transfer(from: .building(market.id), to: .building(farm.id),
                           Int64(moved) * max(1, s.config.foodPrice / 2))
            }
        }
    }

    static func payWages(_ s: inout RepublicState) {
        for i in s.buildings.indices {
            let b = s.buildings[i]
            guard !b.workers.isEmpty else { continue }
            let payer: Account = b.kind.isCivic ? .treasury : .building(b.id)
            let wage = b.kind.isCivic ? s.policy.civicWage : s.config.privateWage
            for cid in b.workers {
                s.transfer(from: payer, to: .citizen(cid), wage)
            }
        }
    }

    /// Citizens buy the day's food from their district's market. No market in range,
    /// no stock, or no money => hunger. All three are distinguishable causes.
    static func feedCitizens(_ s: inout RepublicState) {
        let need = s.config.foodPerCitizenPerDay
        for i in s.citizens.indices {
            guard s.citizens[i].alive, let home = s.citizens[i].home else { continue }
            let homeTile = s.buildings[Int(home.raw)].tile
            let did = s.citizens[i].district

            _ = did
            // "Which market" and "how far" come from the same traversal, so a citizen
            // counted as covered can always actually buy.
            guard let marketID = s.fields.nearestMarket(at: homeTile),
                  s.fields.distance(.market, at: homeTile) <= s.config.maxServiceDistance else {
                s.citizens[i].daysHungry += 1
                continue
            }
            guard s.buildings[Int(marketID.raw)].foodStore >= need else {
                s.citizens[i].daysHungry += 1
                continue
            }
            let price = Int64(need) * s.config.foodPrice
            let paid = s.transfer(from: .citizen(s.citizens[i].id), to: .building(marketID), price)
            if paid >= price {
                s.consumeFood(at: marketID, need)
                s.citizens[i].daysHungry = 0
            } else {
                // Could not afford it; refund so no money is stranded.
                s.transfer(from: .building(marketID), to: .citizen(s.citizens[i].id), paid)
                s.citizens[i].daysHungry += 1
            }
        }
    }

    static func collectTaxes(_ s: inout RepublicState) {
        let rate = Int64(max(0, s.policy.incomeTaxPercent))
        for i in s.citizens.indices where s.citizens[i].alive {
            let due = s.citizens[i].money * rate / 100
            if due > 0 { s.transfer(from: .citizen(s.citizens[i].id), to: .treasury, due) }
        }
        let brate = Int64(max(0, s.policy.businessTaxPercent))
        for i in s.buildings.indices where !s.buildings[i].kind.isCivic {
            let due = s.buildings[i].funds * brate / 100
            if due > 0 { s.transfer(from: .building(s.buildings[i].id), to: .treasury, due) }
        }
    }

    static func payUpkeep(_ s: inout RepublicState) {
        var total: Int64 = 0
        for b in s.buildings where b.kind != .house {
            total += b.kind.isCivic ? s.config.upkeepCivic : s.config.upkeepPrivate
        }
        let paid = s.transfer(from: .treasury, to: .external, total)
        if paid < total {
            s.emit(.treasuryEmpty,
                   causes: [CauseFactor(.treasuryDeficit, value: Int32(clamping: total - paid),
                                        detail: "unpaid upkeep")],
                   magnitude: Int32(clamping: total - paid))
        }
    }

    static func spoil(_ s: inout RepublicState) {
        for i in s.buildings.indices where s.buildings[i].kind.storesFood {
            let lost = s.buildings[i].foodStore * s.config.marketSpoilagePercent / 100
            if lost > 0 { s.spoilFood(at: s.buildings[i].id, lost) }
        }
    }

    // MARK: - Wellbeing: strictly two-phase

    /// Phase 1 reads an immutable view of the world and produces deltas; phase 2
    /// applies them in ID order. No citizen's outcome depends on its array position,
    /// which is both a correctness property and what makes the read phase
    /// parallelisable when the population grows.
    struct CitizenDelta {
        var happiness: Int32 = 0
        var loyalty: Int32 = 0
        var becomesCriminal = false
        var causes: [CauseFactor] = []
    }

    @discardableResult
    static func updateWellbeing(_ s: inout RepublicState) -> [CitizenDelta] {
        let cfg = s.config
        let corruptionNow = s.corruption          // snapshot: constant for every citizen today
        let taxNow = s.policy.incomeTaxPercent
        let maxD = cfg.maxServiceDistance

        var deltas = [CitizenDelta](repeating: CitizenDelta(), count: s.citizens.count)
        var rng = s.rng

        for i in s.citizens.indices {
            guard s.citizens[i].alive else { continue }
            let c = s.citizens[i]
            var d = CitizenDelta()

            guard let home = c.home else {
                d.happiness -= 5
                deltas[i] = d
                continue
            }
            let homeTile = s.buildings[Int(home.raw)].tile
            let district = s.districts[Int(c.district.raw)]

            var grievance = false
            if c.daysHungry > 0 {
                d.happiness -= cfg.hungerHappinessPenalty
                d.loyalty -= cfg.hungerLoyaltyPenalty
                d.causes.append(CauseFactor(.foodShortage, value: c.daysHungry, detail: "days hungry"))
                grievance = true
            }
            let marketDist = s.fields.distance(.market, at: homeTile)
            if marketDist > maxD {
                d.happiness -= cfg.noMarketAccessPenalty
                d.loyalty -= cfg.noMarketAccessPenalty / 2
                d.causes.append(CauseFactor(.noMarketAccess, value: Int32(min(marketDist, 9999)),
                                            detail: district.name))
                grievance = true
            }
            if s.fields.distance(.clinic, at: homeTile) <= maxD {
                d.happiness += cfg.clinicCoverageBonus
            } else {
                d.causes.append(CauseFactor(.noClinicAccess, value: 1, detail: district.name))
            }
            if s.fields.distance(.school, at: homeTile) <= maxD {
                d.happiness += cfg.schoolCoverageBonus
            }
            if c.work == nil {
                d.happiness -= cfg.unemploymentPenalty
                d.loyalty -= cfg.unemploymentPenalty / 2
                d.causes.append(CauseFactor(.unemployment, value: c.daysUnemployed, detail: district.name))
                grievance = true
            }
            let taxPain = max(0, taxNow - cfg.taxPainPerPercentOver) / 5
            if taxPain > 0 {
                d.happiness -= taxPain
                d.loyalty -= taxPain
                d.causes.append(CauseFactor(.taxBurden, value: taxNow, detail: "income tax"))
            }
            if corruptionNow > 50 {
                d.loyalty -= (corruptionNow - 50) / 10
                d.causes.append(CauseFactor(.corruption, value: corruptionNow, detail: "national"))
            }
            if district.neglectDays > 5 {
                d.loyalty -= min(4, district.neglectDays / 5)
                d.causes.append(CauseFactor(.districtNeglect, value: district.neglectDays,
                                            detail: district.name))
            }

            // A citizen with nothing to complain about recovers loyalty, up to the
            // ceiling contentment alone can buy. This is what makes loyalty a
            // two-way signal instead of a countdown.
            if !grievance && c.loyalty < cfg.loyaltyContentmentCeiling {
                d.loyalty += cfg.loyaltyRecoveryPerDay
            }

            // The only RNG touching wellbeing: small symmetric jitter, drawn in ID order.
            d.happiness += Int32(rng.int(Int(-cfg.happinessDrift)...Int(cfg.happinessDrift)))

            let unpoliced = s.fields.distance(.police, at: homeTile) > maxD
            if !c.criminal, c.money < 8, c.ambition > 65, unpoliced, rng.chance(10) {
                d.becomesCriminal = true
                d.causes.append(CauseFactor(.poverty, value: Int32(clamping: c.money), detail: "destitute"))
                d.causes.append(CauseFactor(.noPoliceAccess, value: 1, detail: district.name))
            }
            deltas[i] = d
        }
        s.rng = rng

        // Phase 2.
        for i in s.citizens.indices {
            guard s.citizens[i].alive else { continue }
            let d = deltas[i]
            s.citizens[i].happiness = clamp(s.citizens[i].happiness + d.happiness)
            let wasBelowCeiling = s.citizens[i].loyalty < cfg.loyaltyContentmentCeiling
            s.citizens[i].loyalty = clamp(s.citizens[i].loyalty + d.loyalty)
            if wasBelowCeiling && d.loyalty > 0 {
                s.citizens[i].loyalty = min(s.citizens[i].loyalty, cfg.loyaltyContentmentCeiling)
            }
            if s.citizens[i].work == nil { s.citizens[i].daysUnemployed += 1 }
            if d.becomesCriminal {
                s.citizens[i].criminal = true
                s.corruption = clamp(s.corruption + 2)
                s.emit(.citizenTurnedToCrime,
                       location: EventLocation(district: s.citizens[i].district),
                       subjects: [s.citizens[i].id], causes: d.causes)
            }
            if s.citizens[i].daysHungry == 1 {
                s.emit(.citizenHungry,
                       location: EventLocation(district: s.citizens[i].district),
                       subjects: [s.citizens[i].id],
                       causes: d.causes.filter { $0.kind == .foodShortage || $0.kind == .noMarketAccess })
            }
        }
        return deltas
    }

    // MARK: - District aggregation

    static func aggregateDistricts(_ s: inout RepublicState) {
        let maxD = s.config.maxServiceDistance
        var pop = [Int32](repeating: 0, count: s.districts.count)
        var happy = [Int64](repeating: 0, count: s.districts.count)
        var loyal = [Int64](repeating: 0, count: s.districts.count)
        var hungry = [Int32](repeating: 0, count: s.districts.count)
        var jobless = [Int32](repeating: 0, count: s.districts.count)
        var mkt = [Int32](repeating: 0, count: s.districts.count)
        var clin = [Int32](repeating: 0, count: s.districts.count)
        var pol = [Int32](repeating: 0, count: s.districts.count)

        for c in s.citizens where c.alive {
            let d = Int(c.district.raw)
            pop[d] += 1
            happy[d] += Int64(c.happiness)
            loyal[d] += Int64(c.loyalty)
            if c.daysHungry > 0 { hungry[d] += 1 }
            if c.work == nil { jobless[d] += 1 }
            guard let home = c.home else { continue }
            let t = s.buildings[Int(home.raw)].tile
            if s.fields.distance(.market, at: t) <= maxD { mkt[d] += 1 }
            if s.fields.distance(.clinic, at: t) <= maxD { clin[d] += 1 }
            if s.fields.distance(.police, at: t) <= maxD { pol[d] += 1 }
        }

        for i in s.districts.indices {
            if s.districts[i].crisisCooldown > 0 { s.districts[i].crisisCooldown -= 1 }
            let n = max(1, pop[i])
            s.districts[i].population = pop[i]
            s.districts[i].meanHappiness = Int32(happy[i] / Int64(n))
            s.districts[i].meanLoyalty = Int32(loyal[i] / Int64(n))
            s.districts[i].hungryCount = hungry[i]
            s.districts[i].unemployedCount = jobless[i]
            s.districts[i].marketCoverage = mkt[i] * 100 / n
            s.districts[i].clinicCoverage = clin[i] * 100 / n
            s.districts[i].policeCoverage = pol[i] * 100 / n

            guard pop[i] > 0 else {
                s.districts[i].neglectDays = 0
                s.districts[i].unrest = 0
                continue
            }

            // Neglect is an explicit, inspectable counter -- the state behind
            // "the east docks have been neglected for forty days".
            let underserved = s.districts[i].marketCoverage < 60 || hungry[i] * 100 / n > 25
            if underserved {
                s.districts[i].neglectDays += 1
            } else {
                s.districts[i].neglectDays = max(0, s.districts[i].neglectDays - 1)
            }

            // Unrest is a pure function of observable district conditions. No RNG.
            var pressure: Int32 = 0
            pressure += hungry[i] * 100 / n / 4
            pressure += jobless[i] * 100 / n / 8
            pressure += (100 - s.districts[i].marketCoverage) / 10
            pressure += min(20, s.districts[i].neglectDays * s.config.neglectUnrestPerDay / 2)
            if s.districts[i].meanHappiness < 35 { pressure += 6 }
            if s.districts[i].meanLoyalty < 30 { pressure += 6 }

            let relief: Int32 = (s.districts[i].meanHappiness > 55 ? s.config.neglectDecayPerDay : 0)
                + (s.districts[i].policeCoverage > 60 ? 1 : 0)
            s.districts[i].unrest = clamp(s.districts[i].unrest + pressure - relief - 2)

            if s.districts[i].neglectDays == 10 {
                s.emit(.districtNeglected,
                       location: EventLocation(district: s.districts[i].id),
                       causes: [
                        CauseFactor(.districtNeglect, value: s.districts[i].neglectDays, detail: s.districts[i].name),
                        CauseFactor(.noMarketAccess, value: s.districts[i].marketCoverage, detail: "market coverage %")
                       ],
                       magnitude: s.districts[i].unrest)
            }
        }
    }

    /// Factions are a readout, not a separate opinion system: membership and
    /// grievance are both derived from citizen state every tick, so a demand always
    /// traces back to something the player could have seen coming.
    static func updateFactions(_ s: inout RepublicState) {
        let maxD = s.config.maxServiceDistance
        let corrupt = s.corruption
        let taxNow = s.policy.incomeTaxPercent
        let slots = 8

        var members = [Int32](repeating: 0, count: FactionKind.allCases.count)
        var happy = [Int64](repeating: 0, count: FactionKind.allCases.count)
        var loyal = [Int64](repeating: 0, count: FactionKind.allCases.count)
        var tally = [Int32](repeating: 0, count: FactionKind.allCases.count * slots)

        for c in s.citizens where c.alive {
            let f = Int(FactionKind.of(c.occupation).rawValue)
            members[f] += 1
            happy[f] += Int64(c.happiness)
            loyal[f] += Int64(c.loyalty)
            let base = f * slots

            if c.daysHungry > 0 { tally[base + 0] += 1 }
            if c.work == nil { tally[base + 1] += 1 }
            if c.money < 8 { tally[base + 2] += 1 }
            if taxNow > s.config.taxPainPerPercentOver { tally[base + 3] += 1 }
            if corrupt > 60 { tally[base + 4] += 1 }
            if let home = c.home {
                let t = s.buildings[Int(home.raw)].tile
                if s.fields.distance(.market, at: t) > maxD { tally[base + 5] += 1 }
                if s.fields.distance(.police, at: t) > maxD { tally[base + 6] += 1 }
                if s.fields.distance(.clinic, at: t) > maxD { tally[base + 7] += 1 }
            }
        }

        let order: [CauseKind] = [.foodShortage, .unemployment, .poverty, .taxBurden,
                                  .corruption, .noMarketAccess, .noPoliceAccess, .noClinicAccess]
        for i in s.factions.indices {
            let n = members[i]
            s.factions[i].members = n
            guard n > 0 else {
                s.factions[i].dominantConcern = nil
                s.factions[i].concernWeight = 0
                continue
            }
            s.factions[i].meanHappiness = Int32(happy[i] / Int64(n))
            s.factions[i].meanLoyalty = Int32(loyal[i] / Int64(n))

            let base = i * slots
            var bestSlot = -1
            var bestCount: Int32 = 0
            for k in 0..<slots where tally[base + k] > bestCount {
                bestCount = tally[base + k]
                bestSlot = k
            }
            let share = bestCount * 100 / n
            if bestSlot >= 0 && share >= s.config.factionConcernPercent {
                s.factions[i].dominantConcern = order[bestSlot]
                s.factions[i].concernWeight = share
            } else {
                s.factions[i].dominantConcern = nil
                s.factions[i].concernWeight = 0
            }
        }
    }

    static func updateNationalMood(_ s: inout RepublicState) {
        let criminals = s.citizens.reduce(into: Int32(0)) { $0 += ($1.criminal && $1.alive) ? 1 : 0 }
        let pop = max(Int32(1), Int32(s.citizens.count))
        let policedShare = s.districts.reduce(into: Int32(0)) { $0 += $1.policeCoverage }
            / max(1, Int32(s.districts.count))

        // Corruption chases a target instead of ratcheting, so policing and crime
        // reduction actually buy it back down.
        let policeGap = max(0, 60 - policedShare)
        let crimeShare = criminals * 100 / pop
        let target = clamp(policeGap + crimeShare / 2)
        let gap = target - s.corruption
        if gap != 0 {
            let step = max(1, abs(gap) / max(1, s.config.corruptionDriftDivisor))
            s.corruption = clamp(s.corruption + (gap > 0 ? step : -step))
        }

        let meanLoyalty = s.districts.filter { $0.population > 0 }
            .reduce(into: Int32(0)) { $0 += $1.meanLoyalty }
            / max(1, Int32(s.districts.filter { $0.population > 0 }.count))
        let active = s.factions.filter { $0.members > 0 }
        let meanFavor = active.isEmpty ? 0
            : active.reduce(into: Int32(0)) { $0 += $1.favor } / Int32(active.count)
        s.legitimacy = clamp(s.legitimacy
                             + (meanLoyalty > 55 ? 1 : -1)
                             + (meanFavor > 25 ? 1 : 0)
                             - (meanFavor < -25 ? 1 : 0)
                             - (s.corruption > 65 ? 2 : 0)
                             - (s.treasury < 0 ? 2 : 0))
    }

    // MARK: - Crises: deterministic, attributable, never spawned by a dice roll

    static func evaluateCrises(_ s: inout RepublicState) {
        for k in s.crisisKindCooldown.indices where s.crisisKindCooldown[k] > 0 {
            s.crisisKindCooldown[k] -= 1
        }
        guard s.pending == nil else { return }
        let cfg = s.config

        // Minimum spacing between any two crises, so the player gets days to act
        // rather than an unbroken queue of prompts.
        guard s.day - s.lastCrisisDay >= cfg.globalCrisisCooldownDays else { return }

        // 1. District uprising -- the worst eligible district above threshold.
        if s.crisisKindCooldown[DecisionKind.districtUprising.slot] == 0,
           let worst = s.districts.filter({
            $0.population > 0 && $0.crisisCooldown == 0 && $0.unrest >= cfg.districtUnrestCrisisThreshold
        }).max(by: { $0.unrest < $1.unrest }) {
            raise(&s, kind: .districtUprising,
                  location: EventLocation(district: worst.id),
                  causes: [
                    CauseFactor(.districtNeglect, value: worst.neglectDays, detail: worst.name),
                    CauseFactor(.noMarketAccess, value: worst.marketCoverage, detail: "market coverage %"),
                    CauseFactor(.foodShortage, value: worst.hungryCount, detail: "hungry residents"),
                    CauseFactor(.unemployment, value: worst.unemployedCount, detail: "without work")
                  ],
                  options: [
                    DecisionOption(id: 0, label: "Fund the district", monetaryCost: 500),
                    DecisionOption(id: 1, label: "Send in the police")
                  ])
            return
        }

        // 2. Famine -- national food stores empty while people go hungry.
        let hungryTotal = s.citizens.reduce(into: Int32(0)) { $0 += ($1.alive && $1.daysHungry >= cfg.famineCrisisDays) ? 1 : 0 }
        if s.crisisKindCooldown[DecisionKind.famine.slot] == 0,
           hungryTotal * 100 / max(1, Int32(s.citizens.count)) >= 20 {
            raise(&s, kind: .famine,
                  location: EventLocation(),
                  causes: [
                    CauseFactor(.foodShortage, value: hungryTotal, detail: "citizens hungry \(cfg.famineCrisisDays)+ days"),
                    CauseFactor(.treasuryDeficit, value: Int32(clamping: s.treasury), detail: "treasury")
                  ],
                  options: [
                    DecisionOption(id: 0, label: "Import emergency grain", monetaryCost: 600),
                    DecisionOption(id: 1, label: "Ration and endure")
                  ])
            return
        }

        // 3. Corruption scandal -- threshold on an accumulated, caused quantity.
        if s.crisisKindCooldown[DecisionKind.corruptionScandal.slot] == 0,
           s.corruption >= cfg.corruptionCrisisThreshold {
            let criminals = s.citizens.reduce(into: Int32(0)) { $0 += ($1.criminal && $1.alive) ? 1 : 0 }
            raise(&s, kind: .corruptionScandal,
                  location: EventLocation(),
                  causes: [
                    CauseFactor(.corruption, value: s.corruption, detail: "national corruption"),
                    CauseFactor(.noPoliceAccess, value: criminals, detail: "citizens in the black market")
                  ],
                  options: [
                    DecisionOption(id: 0, label: "Open an independent inquiry", monetaryCost: 250),
                    DecisionOption(id: 1, label: "Bury the report")
                  ])
            return
        }

        // 4. Bankruptcy.
        if s.crisisKindCooldown[DecisionKind.bankruptcy.slot] == 0, s.treasury < 0 {
            raise(&s, kind: .bankruptcy,
                  location: EventLocation(),
                  causes: [CauseFactor(.treasuryDeficit, value: Int32(clamping: s.treasury), detail: "treasury")],
                  options: [
                    DecisionOption(id: 0, label: "Raise taxes"),
                    DecisionOption(id: 1, label: "Take a foreign loan")
                  ])
        }
    }

    static func raise(_ s: inout RepublicState, kind: DecisionKind,
                      location: EventLocation, causes: [CauseFactor], options: [DecisionOption]) {
        let d = PendingDecision(id: DecisionID(s.nextDecisionRaw), kind: kind,
                                raisedOnDay: s.day, location: location,
                                causes: causes, options: options)
        s.nextDecisionRaw += 1
        s.pending = d
        s.lastCrisisDay = s.day
        s.crisisKindCooldown[kind.slot] = s.config.nationalCrisisCooldownDays
        s.emit(.crisisRaised, location: location, causes: causes)
    }
}
