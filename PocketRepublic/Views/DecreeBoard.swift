import SwiftUI
import PocketRepublicCore

/// Decree cards built from `DecreeSpec` and the live agenda. `DecreeSpec` has no
/// flavor string yet, so the card leaves that line out instead of inventing one.
/// "Not now" only closes the card. It does not send the agenda's dismiss option,
/// which would remove the offer and record a decree.
struct DecreeBoard: View {
    @EnvironmentObject private var game: Game
    @State private var openDecree: String?

    var body: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.lg) {
            standing
            tax
            decrees
            council
        }
    }

    private var standing: some View {
        HStack(alignment: .top, spacing: RepublicTheme.Space.md) {
            meter("Legitimacy", game.snapshot.legitimacy, highIsGood: true)
            meter("Corruption", game.snapshot.corruption, highIsGood: false)
        }
        .dioramaCard(fill: RepublicTheme.sand.opacity(0.35))
    }

    private func meter(_ title: String, _ value: Int32, highIsGood: Bool) -> some View {
        let worried = highIsGood ? value < 40 : value > 60
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(RepublicTheme.body(.caption))
                .foregroundStyle(RepublicTheme.inkSoft)
            Text("\(value)%")
                .font(RepublicTheme.heading(.title2))
                .foregroundStyle(worried ? RepublicTheme.alert : RepublicTheme.fertile)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tax: some View {
        Stepper(value: Binding(
            get: { Int(game.state.policy.incomeTaxPercent) },
            set: { newValue in
                var next = game.state.policy
                next.incomeTaxPercent = Int32(newValue)
                game.send(.setPolicy(next))
            }
        ), in: 0...60, step: 5) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Income tax")
                    .font(RepublicTheme.heading(.headline))
                Text("\(game.state.policy.incomeTaxPercent)%")
                    .font(RepublicTheme.body(.title3))
                    .foregroundStyle(RepublicTheme.turquoise)
            }
        }
        .dioramaCard()
        .disabled(game.saveIssue != nil)
    }

    private var decrees: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Text("Decrees")
                .font(RepublicTheme.heading(.title3))
            ForEach(DecreeCatalogue.all, id: \.name) { spec in
                decreeRow(spec)
            }
        }
    }

    @ViewBuilder private var council: some View {
        let items = game.state.agenda.filter { $0.kind != .decree }.sorted { lhs, rhs in
            func rank(_ item: AgendaItem) -> Int {
                AgendaSheetOrder.rank(tier: item.tier, isIslandEvent: item.islandEventID != nil, isDecree: item.kind == .decree)
            }
            return rank(lhs) < rank(rhs)
        }
        if !items.isEmpty {
            Text("Before the council")
                .font(RepublicTheme.heading(.title3))
            ForEach(items) { item in
                councilCard(item)
            }
        }
    }

    private func decreeRow(_ spec: DecreeSpec) -> some View {
        let card = DecreeCardReading.make(spec: spec, state: game.state)
        let open = openDecree == spec.name
        return VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Button {
                openDecree = open ? nil : spec.name
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: RepublicTheme.Space.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(RepublicTheme.heading(.headline))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let summary = card.chipSummary {
                            Text(summary)
                                .font(RepublicTheme.body(.caption))
                                .foregroundStyle(RepublicTheme.inkSoft)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: RepublicTheme.Space.sm)
                    Text(card.costLabel)
                        .font(RepublicTheme.heading(.subheadline))
                        .foregroundStyle(card.canAfford ? RepublicTheme.fertile : RepublicTheme.alert)
                }
                .padding(RepublicTheme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RepublicTheme.sand.opacity(0.35), in: RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(card.title), \(card.costLabel)")

            if open {
                decreeDetail(card)
            }
        }
    }

    private func decreeDetail(_ card: DecreeCardReading) -> some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            if let shortfall = card.shortfall {
                Text("Need \(shortfall) more")
                    .font(RepublicTheme.body(.caption).weight(.semibold))
                    .foregroundStyle(RepublicTheme.alert)
            }
            if !card.chips.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), alignment: .leading)], alignment: .leading, spacing: RepublicTheme.Space.xs) {
                    ForEach(card.chips) { chip in
                        Text(chip.label)
                            .font(RepublicTheme.body(.caption).weight(.semibold))
                            .foregroundStyle(chip.pleased ? RepublicTheme.fertile : RepublicTheme.alert)
                    }
                }
            }
            ForEach(card.effects, id: \.self) { line in
                Text(line)
                    .font(RepublicTheme.body(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                issue(card)
            } label: {
                Text("Issue decree")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(RepublicTheme.terracotta)
            .disabled(!card.canIssue || game.saveIssue != nil)
            Button("Not now") { openDecree = nil }
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .dioramaCard()
    }

    private func issue(_ card: DecreeCardReading) {
        guard let id = card.agendaID, let option = card.enactOption else { return }
        game.send(.resolveAgendaItem(id, option: option))
        openDecree = nil
    }

    private func councilCard(_ item: AgendaItem) -> some View {
        AgendaChoiceCard(
            item: item,
            treasury: game.state.treasury,
            day: game.state.day,
            saveBlocked: game.saveIssue != nil,
            onResolve: { option in
                game.send(.resolveAgendaItem(item.id, option: option))
            }
        )
    }
}

/// App-side reading of a decree. Keeps the card off `PocketRepublicCore`.
struct DecreeCardReading: Identifiable {
    struct Chip: Identifiable {
        var name: String
        var delta: Int32
        var arrows: String
        var id: String { name }
        var pleased: Bool { delta > 0 }
        var label: String { "\(name) \(arrows)" }
    }

    var title: String
    var costLabel: String
    var shortfall: Int64?
    var canAfford: Bool
    var chips: [Chip]
    var effects: [String]
    var agendaID: DecisionID?
    var enactOption: Int32?
    var id: String { title }
    var canIssue: Bool { canAfford && agendaID != nil && enactOption != nil }
    var chipSummary: String? {
        let shown = chips.prefix(2).map(\.label)
        return shown.isEmpty ? nil : shown.joined(separator: " · ")
    }

    static func make(spec: DecreeSpec, state: RepublicState) -> DecreeCardReading {
        let pay = spec.cost > 0 ? spec.cost : spec.effect.treasuryCost
        let shortfall: Int64? = pay > state.treasury ? pay - state.treasury : nil
        let offer = state.agenda.first { item in
            item.kind == .decree && item.causes.contains { $0.detail == spec.name }
        }
        let enact = offer?.options.first { $0.id == 0 } ?? offer?.options.first
        return DecreeCardReading(
            title: spec.name,
            costLabel: pay == 0 ? "Free" : "$\(pay)",
            shortfall: shortfall,
            canAfford: shortfall == nil,
            chips: chips(factions: spec.effect.favorFactions, deltas: spec.effect.favorDeltas),
            effects: AgendaEffectCopy.lines(spec.effect),
            agendaID: offer?.id,
            enactOption: enact?.id
        )
    }

    private static func chips(factions: [FactionKind], deltas: [Int32]) -> [Chip] {
        let count = min(factions.count, deltas.count)
        return (0..<count).compactMap { index in
            let delta = deltas[index]
            guard delta != 0 else { return nil }
            return Chip(name: factions[index].displayName, delta: delta, arrows: arrows(delta))
        }.sorted { lhs, rhs in
            if lhs.pleased != rhs.pleased { return lhs.pleased }
            return abs(lhs.delta) > abs(rhs.delta)
        }
    }

    private static func arrows(_ delta: Int32) -> String {
        let count: Int
        switch abs(delta) {
        case 0: return ""
        case 1...3: count = 1
        case 4...6: count = 2
        default: count = 3
        }
        return String(repeating: delta > 0 ? "▲" : "▼", count: count)
    }

}
