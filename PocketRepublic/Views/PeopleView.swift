import SwiftUI
import PocketRepublicCore

struct PeopleView: View {
    @EnvironmentObject private var game: Game

    private var citizens: [Citizen] {
        game.state.citizens.filter(\.alive).sorted { lhs, rhs in
            if lhs.daysHungry != rhs.daysHungry { return lhs.daysHungry > rhs.daysHungry }
            if lhs.happiness != rhs.happiness { return lhs.happiness < rhs.happiness }
            return lhs.name < rhs.name
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: RepublicTheme.Space.sm) {
                if citizens.isEmpty {
                    Text("No one lives on the island yet.")
                        .font(RepublicTheme.body())
                        .foregroundStyle(RepublicTheme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(citizens) { citizen in
                    CitizenRow(citizen: citizen)
                }
            }
            .padding(RepublicTheme.Space.md)
        }
        .background(RepublicTheme.cream)
    }
}

private struct CitizenRow: View {
    let citizen: Citizen
    @ScaledMetric(relativeTo: .headline) private var portraitSide: CGFloat = 56

    var body: some View {
        HStack(alignment: .top, spacing: RepublicTheme.Space.md) {
            portrait
            VStack(alignment: .leading, spacing: RepublicTheme.Space.xs) {
                Text(citizen.name)
                    .font(RepublicTheme.heading(.headline))
                    .fixedSize(horizontal: false, vertical: true)
                Text(citizen.occupation.spoken)
                    .font(RepublicTheme.body(.subheadline))
                    .foregroundStyle(RepublicTheme.inkSoft)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RepublicTheme.Space.sm) { chips }
                    VStack(alignment: .leading, spacing: RepublicTheme.Space.xs) { chips }
                }
            }
        }
        .dioramaCard(fill: RepublicTheme.sand.opacity(0.28))
        .accessibilityElement(children: .combine)
    }

    private var portrait: some View {
        let bucket = citizen.name.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) % RepublicTheme.pastels.count }
        let pastel = RepublicTheme.pastels[bucket < 0 ? bucket + RepublicTheme.pastels.count : bucket]
        return ZStack {
            Circle().fill(pastel)
            Text(initials)
                .font(RepublicTheme.heading(.headline))
                .foregroundStyle(RepublicTheme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(width: portraitSide, height: portraitSide)
        .overlay(Circle().stroke(citizen.daysHungry > 0 ? RepublicTheme.alert : RepublicTheme.grass, lineWidth: 3))
        .accessibilityHidden(true)
    }

    @ViewBuilder private var chips: some View {
        Text("Happiness \(citizen.happiness)%")
            .font(RepublicTheme.body(.caption).weight(.semibold))
            .padding(.horizontal, RepublicTheme.Space.sm)
            .padding(.vertical, RepublicTheme.Space.xs)
            .background(mood.opacity(0.22), in: Capsule())
            .foregroundStyle(mood)
        hunger
        Text("$\(citizen.money)")
            .font(RepublicTheme.body(.caption).weight(.semibold))
            .foregroundStyle(RepublicTheme.inkSoft)
    }

    private var hunger: some View {
        let hungry = citizen.daysHungry > 0
        let title = hungry
            ? "Hungry \(citizen.daysHungry) \(citizen.daysHungry == 1 ? "day" : "days")"
            : "Fed"
        return Label(title, systemImage: hungry ? "fork.knife" : "leaf.fill")
            .font(RepublicTheme.body(.caption).weight(.semibold))
            .foregroundStyle(hungry ? RepublicTheme.alert : RepublicTheme.fertile)
            .labelStyle(.titleAndIcon)
    }

    private var initials: String {
        let parts = citizen.name.split(separator: " ")
        return String(parts.prefix(2).compactMap(\.first)).uppercased()
    }

    private var mood: Color {
        if citizen.happiness >= 60 { return RepublicTheme.fertile }
        if citizen.happiness >= 40 { return RepublicTheme.terracotta }
        return RepublicTheme.alert
    }
}

private extension Occupation {
    var spoken: String {
        switch self {
        case .unemployed: return "Unemployed"
        case .farmer: return "Farmer"
        case .shopkeeper: return "Shopkeeper"
        case .nurse: return "Nurse"
        case .teacher: return "Teacher"
        case .officer: return "Officer"
        case .artisan: return "Artisan"
        case .dockhand: return "Dockhand"
        case .official: return "Official"
        }
    }
}
