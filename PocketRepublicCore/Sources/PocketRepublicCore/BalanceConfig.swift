import Foundation

/// Every tunable number in the simulation, in one Codable place.
/// Balance is data, not code: the design lead tunes this struct without touching
/// engine logic, and a config can be serialised next to a seed to reproduce a run.
public struct BalanceConfig: Codable, Sendable, Equatable {
    // Production
    public var farmYieldPerWorker: Int32 = 5
    public var fertileBonus: Int32 = 2
    public var workshopOutputPerWorker: Int64 = 7

    // Consumption
    public var foodPerCitizenPerDay: Int32 = 1
    public var foodPrice: Int64 = 2

    // Wages (paid from employer funds; civic employers draw on the treasury)
    public var privateWage: Int64 = 4
    public var civicWage: Int64 = 4

    // Taxation
    public var incomeTaxPercent: Int32 = 15
    public var businessTaxPercent: Int32 = 10

    // Upkeep per building per day, by kind
    public var upkeepCivic: Int64 = 3
    public var upkeepPrivate: Int64 = 1

    // Logistics
    public var marketSpoilagePercent: Int32 = 5
    public var farmToMarketShipPerDay: Int32 = 40
    /// Road-distance reach of a service building. Districts are ~21 tiles across,
    /// so anything under ~20 leaves a quarter of a district permanently unservable
    /// no matter what the player does. Tune down only alongside denser service
    /// placement, or coverage stops being a decision and becomes a dead zone.
    public var maxServiceDistance: UInt16 = 20

    // Wellbeing
    public var hungerHappinessPenalty: Int32 = 9
    public var hungerLoyaltyPenalty: Int32 = 5
    public var noMarketAccessPenalty: Int32 = 4
    public var clinicCoverageBonus: Int32 = 3
    public var schoolCoverageBonus: Int32 = 2
    public var unemploymentPenalty: Int32 = 3
    public var taxPainPerPercentOver: Int32 = 10   // tax points above this start to hurt
    public var happinessDrift: Int32 = 2           // +/- random jitter, the ONLY RNG on wellbeing
    /// Loyalty regained per day by a citizen with no live grievance (fed, employed,
    /// market within reach). Without this, loyalty has only decrements and decays
    /// irreversibly to zero, so it stops distinguishing a well-run republic from a
    /// failing one and legitimacy loses its only population-level input.
    public var loyaltyRecoveryPerDay: Int32 = 2
    /// Ceiling that contentment alone can carry loyalty to; above this it has to be
    /// earned politically (resolved crises, popular policy).
    public var loyaltyContentmentCeiling: Int32 = 70

    // District neglect -> political pressure
    public var neglectUnrestPerDay: Int32 = 2
    public var neglectDecayPerDay: Int32 = 3
    public var districtUnrestCrisisThreshold: Int32 = 70
    public var corruptionCrisisThreshold: Int32 = 65
    /// Corruption converges toward a policing/criminality-derived target at
    /// 1/nth of the gap per day rather than ratcheting one point at a time.
    /// A ratchet has no recovery path: it pins at 100 and the player can never
    /// earn it back, which reads as a broken game rather than a hard one.
    public var corruptionDriftDivisor: Int32 = 12
    public var famineCrisisDays: Int32 = 3

    // Crisis pacing. The design target is one meaningful decision per 2-3
    // day-advances; these are the knobs that set it.
    public var districtCrisisCooldownDays: Int32 = 25
    public var globalCrisisCooldownDays: Int32 = 2
    /// On resolution a district's unrest is forced this far below the threshold,
    /// so the same crisis cannot immediately re-fire.
    public var crisisResolutionRelief: Int32 = 20
    /// Minimum days before the same national crisis (famine, scandal, bankruptcy)
    /// may be raised again.
    public var nationalCrisisCooldownDays: Int32 = 18

    // Decision stream. The target is that something actionable is on screen every
    // single day-advance; only crises block the advance itself.
    public var agendaTargetSize: Int32 = 3
    public var factionDemandCooldownDays: Int32 = 10
    public var demandExpiryDays: Int32 = 6
    public var advisoryExpiryDays: Int32 = 4
    public var ignoredDemandFavorCost: Int32 = 6
    /// Unrest at which an advisory offers a cheap fix, well below the crisis line.
    public var advisoryUnrestFloor: Int32 = 25
    public var advisoryUnemploymentPercent: Int32 = 12
    public var electionIntervalDays: Int32 = 120
    /// A faction needs this share of its members sharing one grievance before it
    /// will make a demand about it.
    public var factionConcernPercent: Int32 = 20

    public init() {}
}
