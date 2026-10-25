import Foundation

/// One faction chip on a decree card. Arrows match the sim delta without printing it.
public struct FactionChip: Sendable, Equatable, Identifiable {
    public let name: String
    public let delta: Int32
    public let arrows: String

    public var id: String { name }
    public var pleased: Bool { delta > 0 }
    public var label: String { "\(name) \(arrows)" }

    public init(name: String, delta: Int32, arrows: String) {
        self.name = name
        self.delta = delta
        self.arrows = arrows
    }
}

/// Presentation of one `DecreeSpec`. `flavor` is filled by the caller when the
/// spec has one; this type does not add the field to the model.
public struct DecreeCardCopy: Sendable, Equatable {
    public let title: String
    public let flavor: String?
    public let cost: Int64
    public let costLabel: String
    public let shortfall: Int64?
    public let canAfford: Bool
    public let chips: [FactionChip]
    public let topPleased: String?
    public let topAngered: String?
    public let effects: [String]

    public var chipLine: String { chips.map(\.label).joined(separator: " · ") }

    public init(title: String, flavor: String?, cost: Int64, costLabel: String,
                shortfall: Int64?, canAfford: Bool, chips: [FactionChip],
                topPleased: String?, topAngered: String?, effects: [String]) {
        self.title = title
        self.flavor = flavor
        self.cost = cost
        self.costLabel = costLabel
        self.shortfall = shortfall
        self.canAfford = canAfford
        self.chips = chips
        self.topPleased = topPleased
        self.topAngered = topAngered
        self.effects = effects
    }

    public static func make(spec: DecreeSpec, treasury: Int64, flavor: String?,
                            district: String?) -> DecreeCardCopy {
        let trimmed = flavor?.trimmingCharacters(in: .whitespacesAndNewlines)
        let flavorText = (trimmed?.isEmpty == false) ? trimmed : nil
        let pay = spec.cost > 0 ? spec.cost : spec.effect.treasuryCost
        let shortfall: Int64? = pay > treasury ? pay - treasury : nil
        let chips = Self.chips(factions: spec.effect.favorFactions, deltas: spec.effect.favorDeltas)
        let pleased = chips.filter(\.pleased)
        let angered = chips.filter { !$0.pleased }
        return DecreeCardCopy(
            title: spec.name,
            flavor: flavorText,
            cost: pay,
            costLabel: pay == 0 ? "Free" : "\(pay)",
            shortfall: shortfall,
            canAfford: shortfall == nil,
            chips: chips,
            topPleased: pleased.max(by: { abs($0.delta) < abs($1.delta) })?.label,
            topAngered: angered.max(by: { abs($0.delta) < abs($1.delta) })?.label,
            effects: effectLines(spec.effect, pay: pay, district: district)
        )
    }

    public static func arrows(for delta: Int32) -> String {
        let count: Int
        switch abs(delta) {
        case 0: return ""
        case 1...3: count = 1
        case 4...6: count = 2
        default: count = 3
        }
        return String(repeating: delta > 0 ? "▲" : "▼", count: count)
    }

    public static func chips(factions: [FactionKind], deltas: [Int32]) -> [FactionChip] {
        var pleased: [FactionChip] = []
        var angered: [FactionChip] = []
        for (index, faction) in factions.enumerated() where index < deltas.count {
            let delta = deltas[index]
            guard delta != 0 else { continue }
            let chip = FactionChip(name: faction.displayName, delta: delta, arrows: arrows(for: delta))
            if delta > 0 { pleased.append(chip) } else { angered.append(chip) }
        }
        return pleased + angered
    }

    /// Only the lines that apply, in the design's order.
    public static func effectLines(_ effect: AgendaEffect, pay: Int64, district: String?) -> [String] {
        var lines: [String] = []
        if pay > 0 { lines.append("−\(pay) now") }
        if effect.treasuryGain > 0 { lines.append("+\(effect.treasuryGain) into the treasury") }
        if effect.incomeTaxDelta != 0 { lines.append(signedPercent("Income tax", effect.incomeTaxDelta)) }
        if effect.businessTaxDelta != 0 { lines.append(signedPercent("Business tax", effect.businessTaxDelta)) }
        if effect.civicWageDelta != 0 {
            let n = effect.civicWageDelta
            lines.append("Civic wage \(n > 0 ? "+" : "−")\(abs(n))/day")
        }
        if effect.districtUnrest != 0 {
            let verb = effect.districtUnrest < 0 ? "falls" : "rises"
            if let district, !district.isEmpty {
                lines.append("Unrest \(verb) in \(district)")
            } else {
                lines.append("Unrest \(verb) across the island")
            }
        }
        if effect.legitimacy > 0 { lines.append("Legitimacy up") }
        if effect.legitimacy < 0 { lines.append("Legitimacy down") }
        if effect.corruption > 0 { lines.append("Corruption up") }
        if effect.corruption < 0 { lines.append("Corruption down") }
        if effect.foodImport > 0 { lines.append("+\(effect.foodImport) food delivered to the market") }
        if effect.districtNeglectReset { lines.append("Neglected district is restored") }
        if let mode = effect.operatingMode {
            let name: String
            switch mode {
            case .balanced: name = "balanced"
            case .intensive: name = "intensive"
            case .careful: name = "careful"
            }
            lines.append("Runs \(name)")
        }
        return lines
    }

    private static func signedPercent(_ name: String, _ delta: Int32) -> String {
        "\(name) \(delta > 0 ? "+" : "−")\(abs(delta))%"
    }
}
