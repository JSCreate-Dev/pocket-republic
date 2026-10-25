import SwiftUI
import PocketRepublicCore
#if canImport(UIKit)
import UIKit
#endif

/// Decree cards and the rest of the council. Used on the Government screen and
/// in the Duo agenda pane. "Not now" only closes a decree card.
struct AgendaBoard: View {
    @EnvironmentObject private var game: Game
    var tileCaption: String?
    /// Extra room under a folded-sheet grabber. Government leaves this at zero.
    var topInset: CGFloat = 0
    /// The island pane scrolls on its own. Government already scrolls.
    var scrolls: Bool = true
    @State private var openDecree: String?

    var body: some View {
        if scrolls {
            ScrollView { columns }
                .background(RepublicTheme.cream)
                .foregroundStyle(RepublicTheme.ink)
        } else {
            columns
        }
    }

    private var columns: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.md) {
            if let tileCaption {
                Text(tileCaption)
                    .font(RepublicTheme.body(.caption))
                    .foregroundStyle(RepublicTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let pending = game.state.pending {
                crisisCard(pending)
            }
            decreeSection
            councilSection
        }
        .padding(scrolls ? RepublicTheme.Space.md : 0)
        .padding(.top, scrolls ? RepublicTheme.Space.sm + topInset : topInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var decreeSection: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Text("Decrees")
                .font(RepublicTheme.heading(.title3))
            ForEach(DecreeCatalogue.all, id: \.name) { spec in
                decreeRow(spec)
            }
        }
    }

    @ViewBuilder private var councilSection: some View {
        let items = game.state.agenda.filter { $0.kind != .decree }
        if !items.isEmpty {
            Text("Before the council")
                .font(RepublicTheme.heading(.title3))
            ForEach(items) { item in
                councilCard(item)
            }
        }
    }

    private func decreeRow(_ spec: DecreeSpec) -> some View {
        let card = DecreeCardCopy.make(
            spec: spec,
            treasury: game.state.treasury,
            flavor: DecreeFlavor.read(spec),
            district: nil
        )
        let open = openDecree == spec.name
        return VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Button {
                openDecree = open ? nil : spec.name
            } label: {
                VStack(alignment: .leading, spacing: RepublicTheme.Space.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: RepublicTheme.Space.sm) {
                        Text(card.title)
                            .font(RepublicTheme.heading(.headline))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: RepublicTheme.Space.sm)
                        costLabel(card)
                    }
                    factionSummary(card)
                }
                .padding(RepublicTheme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RepublicTheme.sand.opacity(0.35), in: RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(card.title), \(card.costLabel)")

            if open {
                decreeCard(spec, card: card)
            }
        }
    }

    private func decreeCard(_ spec: DecreeSpec, card: DecreeCardCopy) -> some View {
        let item = agendaItem(named: spec.name)
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            if let flavor = card.flavor {
                Text(flavor)
                    .font(RepublicTheme.body(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            costLabel(card)
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
                            .padding(.horizontal, RepublicTheme.Space.sm)
                            .padding(.vertical, RepublicTheme.Space.xs)
                            .background((chip.pleased ? RepublicTheme.grass : RepublicTheme.alert).opacity(0.22), in: Capsule())
                    }
                }
            }
            ForEach(card.effects, id: \.self) { line in
                Text(line)
                    .font(RepublicTheme.body(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if item == nil && card.canAfford {
                Text("Not before the council today")
                    .font(RepublicTheme.body(.caption))
                    .foregroundStyle(RepublicTheme.inkSoft)
            }
            Button("Issue decree") {
                guard let item, let option = item.options.first(where: { $0.label != "Not now" }) else { return }
                tap()
                game.send(.resolveAgendaItem(item.id, option: option.id))
                openDecree = nil
            }
            .buttonStyle(TerracottaButtonStyle(enabled: item != nil && card.canAfford && game.saveIssue == nil))
            .disabled(item == nil || !card.canAfford || game.saveIssue != nil)

            Button("Not now") { openDecree = nil }
                .buttonStyle(QuietButtonStyle())
        }
        .padding(RepublicTheme.Space.md)
        .background(RepublicTheme.cream, in: RoundedRectangle(cornerRadius: RepublicTheme.Space.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RepublicTheme.Space.radius, style: .continuous).stroke(RepublicTheme.sand, lineWidth: 1))
    }

    private func councilCard(_ item: AgendaItem) -> some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Text(councilTitle(item))
                .font(RepublicTheme.heading(.headline))
                .fixedSize(horizontal: false, vertical: true)
            if let why = CauseCopy.why(item.causes) {
                Text(why)
                    .font(RepublicTheme.body(.subheadline))
                    .foregroundStyle(RepublicTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(item.options.enumerated()), id: \.element.id) { index, option in
                if index == 0 {
                    Button {
                        tap()
                        game.send(.resolveAgendaItem(item.id, option: option.id))
                    } label: {
                        Text(option.label).fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(TerracottaButtonStyle(enabled: game.saveIssue == nil))
                    .disabled(game.saveIssue != nil)
                } else {
                    Button {
                        tap()
                        game.send(.resolveAgendaItem(item.id, option: option.id))
                    } label: {
                        Text(option.label).fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(game.saveIssue != nil)
                }
            }
        }
        .dioramaCard(fill: RepublicTheme.sand.opacity(0.28))
    }

    private func crisisCard(_ pending: PendingDecision) -> some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Text(pending.kind.spoken)
                .font(RepublicTheme.heading(.title3))
                .foregroundStyle(RepublicTheme.terracotta)
            Text("The next day waits for your choice.")
                .font(RepublicTheme.body(.caption))
                .foregroundStyle(RepublicTheme.inkSoft)
            if let why = CauseCopy.why(pending.causes) {
                Text(why)
                    .font(RepublicTheme.body(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(pending.options) { option in
                Button {
                    tap()
                    game.send(.resolveDecision(pending.id, option: option.id))
                } label: {
                    VStack(spacing: 2) {
                        Text(option.label).fixedSize(horizontal: false, vertical: true)
                        if option.monetaryCost > 0 {
                            Text("\(option.monetaryCost)")
                                .font(RepublicTheme.body(.caption))
                        }
                    }
                }
                .buttonStyle(TerracottaButtonStyle(enabled: game.saveIssue == nil))
                .disabled(game.saveIssue != nil)
            }
        }
        .dioramaCard(fill: RepublicTheme.alert.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: RepublicTheme.Space.radius, style: .continuous).stroke(RepublicTheme.terracotta, lineWidth: 2))
    }

    private func costLabel(_ card: DecreeCardCopy) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
            Text(card.costLabel)
        }
        .font(RepublicTheme.heading(.subheadline))
        .foregroundStyle(card.canAfford ? RepublicTheme.ink : RepublicTheme.alert)
        .opacity(card.canAfford ? 1 : 0.75)
        .accessibilityLabel(card.cost == 0 ? "Free" : "Cost \(card.cost)")
    }

    @ViewBuilder private func factionSummary(_ card: DecreeCardCopy) -> some View {
        let parts = [card.topPleased, card.topAngered].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(RepublicTheme.body(.caption))
                .foregroundStyle(RepublicTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func agendaItem(named name: String) -> AgendaItem? {
        game.state.agenda.first { item in
            item.kind == .decree && item.options.contains { $0.label == name }
        }
    }

    private func councilTitle(_ item: AgendaItem) -> String {
        switch item.kind {
        case .factionDemand:
            if let faction = item.faction { return "\(faction.displayName) demand" }
            return "Faction demand"
        case .advisoryTradeoff: return "Council advice"
        case .buildingCommission: return "New building commission"
        case .election: return "Election"
        case .decree: return item.options.first?.label ?? "Decree"
        }
    }

    private func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

/// Reads `DecreeSpec.flavor` when Game Logic adds it. Absent today, so the card skips the line.
enum DecreeFlavor {
    static func read(_ spec: DecreeSpec) -> String? {
        for child in Mirror(reflecting: spec).children where child.label == "flavor" {
            if let text = child.value as? String { return text }
            let inner = Mirror(reflecting: child.value)
            if inner.displayStyle == .optional, let text = inner.children.first?.value as? String {
                return text
            }
        }
        return nil
    }
}

private extension DecisionKind {
    var spoken: String {
        switch self {
        case .districtUprising: return "District uprising"
        case .corruptionScandal: return "Corruption scandal"
        case .famine: return "Famine"
        case .bankruptcy: return "Bankruptcy"
        }
    }
}
