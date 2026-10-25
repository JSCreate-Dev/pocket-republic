import Foundation

/// Where value can sit. Every movement of money is a transfer between two of these;
/// nothing is created by an assignment statement.
public enum Account: Sendable, Equatable {
    case treasury
    case citizen(CitizenID)
    case building(BuildingID)
    /// Off-island. Crossing this boundary is the ONLY way money enters or leaves,
    /// and it is always recorded.
    case external
}

/// Cumulative accounting so conservation is checkable at any tick.
///
/// Money is strictly conserved: the sum of all accounts only changes by recorded
/// external flow. Food is not "conserved" in the physics sense -- farms create it and
/// people eat it -- so it is *accounted*: stocks must reconcile exactly against
/// cumulative production, consumption, spoilage and trade.
public struct Ledger: Codable, Sendable, Equatable {
    public internal(set) var openingMoney: Int64 = 0
    public internal(set) var externalInflow: Int64 = 0
    public internal(set) var externalOutflow: Int64 = 0

    public internal(set) var foodProduced: Int64 = 0
    public internal(set) var foodConsumed: Int64 = 0
    public internal(set) var foodSpoiled: Int64 = 0
    public internal(set) var foodImported: Int64 = 0
    public internal(set) var foodExported: Int64 = 0

    /// What the sum of every money account must equal right now.
    public var expectedMoneyTotal: Int64 { openingMoney + externalInflow - externalOutflow }
    /// What the sum of every food store must equal right now.
    public var expectedFoodTotal: Int64 {
        foodProduced + foodImported - foodConsumed - foodSpoiled - foodExported
    }

    public init() {}
}

/// Raised by the engine's debug invariant check. Never thrown in shipping flow --
/// the tests assert it never happens.
public struct ConservationError: Error, CustomStringConvertible {
    public let description: String
}
