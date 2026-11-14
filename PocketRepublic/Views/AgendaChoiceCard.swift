import SwiftUI
import PocketRepublicCore

/// Plain-language lines for an `AgendaEffect`. Treasury cost stays off decree
/// cards, which already show a price, and on for an event option.
enum AgendaEffectCopy {
    static func lines(_ effect: AgendaEffect, includeTreasury: Bool = false) -> [String] {
        var lines: [String] = []
        if includeTreasury, effect.treasuryCost > 0 { lines.append("Costs $\(effect.treasuryCost) now") }
        if includeTreasury, effect.treasuryGain > 0 { lines.append("Pays $\(effect.treasuryGain)") }
        if effect.foodImport > 0 { lines.append("Brings in \(effect.foodImport) food") }
        if let export = effect.foodExport, export > 0 {
            lines.append("Sends up to \(export) food off the island. The coin scales with what standing markets can ship.")
        }
        if effect.legitimacy != 0 { lines.append(signed("Public trust", effect.legitimacy)) }
        if effect.corruption != 0 { lines.append(signed("Corruption", effect.corruption)) }
        if effect.incomeTaxDelta != 0 { lines.append(signed("Household tax", effect.incomeTaxDelta, suffix: " points")) }
        if effect.businessTaxDelta != 0 { lines.append(signed("Business tax", effect.businessTaxDelta, suffix: " points")) }
        if effect.civicWageDelta != 0 { lines.append(signed("Public pay", effect.civicWageDelta)) }
        if effect.districtUnrest != 0 { lines.append(signed("District unrest", effect.districtUnrest)) }
        if effect.districtNeglectReset { lines.append("Clears neglect in the district") }
        let chips = factionChips(effect)
        if !chips.isEmpty { lines.append(chips) }
        return lines
    }

    static func factionChips(_ effect: AgendaEffect) -> String {
        let count = min(effect.favorFactions.count, effect.favorDeltas.count)
        let chips = (0..<count).compactMap { index -> String? in
            let delta = effect.favorDeltas[index]
            guard delta != 0 else { return nil }
            return "\(effect.favorFactions[index].displayName) \(arrows(delta))"
        }
        let pleased = chips.filter { $0.contains("▲") }
        let angered = chips.filter { $0.contains("▼") }
        return (pleased + angered).joined(separator: " · ")
    }

    private static func arrows(_ delta: Int32) -> String {
        let count: Int
        switch abs(delta) {
        case 1...3: count = 1
        case 4...6: count = 2
        default: count = 3
        }
        return String(repeating: delta > 0 ? "▲" : "▼", count: count)
    }

    private static func signed(_ title: String, _ value: Int32, suffix: String = "") -> String {
        let mark = value > 0 ? "+" : ""
        return "\(title) \(mark)\(value)\(suffix)"
    }

    private static func signed(_ title: String, _ value: Int64, suffix: String = "") -> String {
        let mark = value > 0 ? "+" : ""
        return "\(title) \(mark)\(value)\(suffix)"
    }
}

/// A cause the player can read. Island-event values are a day or a spec id, so
/// they are never printed beside the sentence.
enum CauseSpeech {
    static func line(_ cause: CauseFactor) -> String? {
        let detail = cause.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if cause.kind == .islandEvent {
            return detail.isEmpty ? nil : detail
        }
        switch detail {
        case "days hungry":
            return "hungry for \(cause.value) \(cause.value == 1 ? "day" : "days")"
        case "workplace closed":
            return "their workplace closed"
        case "market coverage %":
            return "market coverage is \(cause.value)%"
        case "hungry residents":
            return "\(cause.value) hungry residents"
        case "citizens hungry 3+ days", "income tax":
            return detail == "income tax" ? "household tax is \(cause.value)%" : detail
        case "destitute":
            return "destitute"
        default:
            guard !detail.isEmpty else { return nil }
            if cause.value != 0, !detail.contains(String(cause.value)) {
                return "\(detail) (\(cause.value))"
            }
            return detail
        }
    }
}

struct AgendaChoiceCard: View {
    let item: AgendaItem
    let treasury: Int64
    let day: Int32
    var saveBlocked: Bool = false
    var onResolve: (Int32) -> Void
    var onClose: (() -> Void)? = nil

    private var reading: Reading { Reading(item: item, treasury: treasury, day: day) }

    var body: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(reading.title)
                    .font(RepublicTheme.heading(.headline))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let onClose {
                    Button(reading.isIslandEvent ? "Not now" : "Close", action: onClose)
                        .font(RepublicTheme.body(.caption))
                }
            }
            if let tone = reading.toneLabel {
                Text(tone)
                    .font(RepublicTheme.body(.caption).weight(.semibold))
                    .foregroundStyle(reading.toneColor)
            }
            if let headline = reading.headline {
                Text(headline)
                    .font(RepublicTheme.heading(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let flavor = reading.flavor {
                Text(flavor)
                    .font(RepublicTheme.body(.subheadline))
                    .foregroundStyle(RepublicTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let why = reading.why {
                Text("Why: \(why)")
                    .font(RepublicTheme.body(.caption))
                    .foregroundStyle(RepublicTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(reading.because, id: \.self) { line in
                Text(line)
                    .font(RepublicTheme.body(.caption))
                    .foregroundStyle(RepublicTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let expiry = reading.expiry {
                Text(expiry)
                    .font(RepublicTheme.body(.caption).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(reading.options) { option in
                optionButton(option)
            }
            if reading.isIslandEvent, let onClose {
                Text("Not now only hides this card. It does not spend money or take the lapse.")
                    .font(RepublicTheme.body(.caption2))
                    .foregroundStyle(RepublicTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RepublicTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RepublicTheme.sand.opacity(0.35), in: RoundedRectangle(cornerRadius: RepublicTheme.Space.radius, style: .continuous))
        .foregroundStyle(RepublicTheme.ink)
    }

    private func optionButton(_ option: Reading.Option) -> some View {
        Button {
            onResolve(option.id)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(option.label)
                    .font(RepublicTheme.heading(.subheadline))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let outcome = option.outcome {
                    Text(outcome)
                        .font(RepublicTheme.body(.caption))
                        .foregroundStyle(RepublicTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(option.effects, id: \.self) { line in
                    Text(line)
                        .font(RepublicTheme.body(.caption))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let shortfall = option.shortfall {
                    Text("Need \(shortfall) more")
                        .font(RepublicTheme.body(.caption).weight(.semibold))
                        .foregroundStyle(RepublicTheme.alert)
                }
                if option.isLapse {
                    Text("This is what happens if the card expires unanswered.")
                        .font(RepublicTheme.body(.caption2))
                        .foregroundStyle(RepublicTheme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                option.canAfford ? RepublicTheme.cream : RepublicTheme.cream.opacity(0.55),
                in: RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!option.canAfford || saveBlocked)
        .opacity(option.canAfford && !saveBlocked ? 1 : 0.55)
    }
}

private struct Reading {
    struct Option: Identifiable {
        var id: Int32
        var label: String
        var outcome: String?
        var effects: [String]
        var shortfall: Int64?
        var canAfford: Bool
        var isLapse: Bool
    }

    var title: String
    var toneLabel: String?
    var toneColor: Color
    var headline: String?
    var flavor: String?
    var why: String?
    var because: [String]
    var expiry: String?
    var isIslandEvent: Bool
    var options: [Option]

    init(item: AgendaItem, treasury: Int64, day: Int32) {
        if let spec = item.islandEvent {
            isIslandEvent = true
            title = spec.title
            headline = item.causes.dropFirst().first?.detail ?? spec.headline
            flavor = item.causes.first?.detail ?? spec.flavor
            why = spec.why
            because = []
            switch spec.tone {
            case .good:
                toneLabel = "Good news"
                toneColor = RepublicTheme.fertile
            case .bad:
                toneLabel = "Trouble"
                toneColor = RepublicTheme.alert
            case .weird:
                toneLabel = "Strange news"
                toneColor = RepublicTheme.turquoise
            }
            let lapse = spec.options.first { $0.id == spec.ifIgnored }
            if let expires = item.expiresOnDay {
                let lapseName = lapse?.label ?? "the free choice"
                expiry = "Open through day \(expires). If it lapses, the island takes “\(lapseName)”. That lapse does not spend the treasury."
            } else {
                expiry = nil
            }
            options = item.options.map { option in
                let specOption = spec.options.first { $0.id == option.id }
                let cost = option.effect.treasuryCost
                let shortfall: Int64? = cost > treasury ? cost - treasury : nil
                return Option(
                    id: option.id,
                    label: option.label,
                    outcome: specOption?.outcome,
                    effects: AgendaEffectCopy.lines(option.effect, includeTreasury: true),
                    shortfall: shortfall,
                    canAfford: shortfall == nil,
                    isLapse: option.id == spec.ifIgnored
                )
            }
        } else if item.originDilemma == true {
            isIslandEvent = false
            title = item.causes.first?.detail ?? "An opening"
            headline = nil
            flavor = item.causes.dropFirst().first?.detail
            why = "Letting it expire changes nothing. Either choice is final."
            because = []
            toneLabel = nil
            toneColor = RepublicTheme.ink
            expiry = item.expiresOnDay.map { "Open through day \($0)." }
            options = item.options.map { option in
                let cost = option.effect.treasuryCost
                let shortfall: Int64? = cost > treasury ? cost - treasury : nil
                return Option(id: option.id, label: option.label, outcome: nil,
                              effects: AgendaEffectCopy.lines(option.effect, includeTreasury: true),
                              shortfall: shortfall, canAfford: shortfall == nil, isLapse: false)
            }
        } else {
            isIslandEvent = false
            title = item.kind.spokenTitle
            headline = nil
            flavor = nil
            why = nil
            because = item.causes.compactMap { cause in
                CauseSpeech.line(cause).map { "Because \($0)" }
            }
            toneLabel = nil
            toneColor = RepublicTheme.ink
            if let expires = item.expiresOnDay {
                expiry = day <= expires ? "Open through day \(expires)." : "This offer has reached its last day."
            } else {
                expiry = nil
            }
            options = item.options.map { option in
                let cost = option.effect.treasuryCost
                let shortfall: Int64? = cost > treasury ? cost - treasury : nil
                return Option(
                    id: option.id,
                    label: option.label,
                    outcome: nil,
                    effects: AgendaEffectCopy.lines(option.effect, includeTreasury: true),
                    shortfall: shortfall,
                    canAfford: shortfall == nil,
                    isLapse: false
                )
            }
        }
        _ = day
    }
}

extension AgendaKind {
    var spokenTitle: String {
        switch self {
        case .factionDemand: return "Faction demand"
        case .advisoryTradeoff: return "Council advice"
        case .decree: return "Decree"
        case .buildingCommission: return "Building commission"
        case .election: return "Election"
        }
    }
}
