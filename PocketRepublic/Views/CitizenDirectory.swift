import SwiftUI
import PocketRepublicCore

/// Citizen cards. Hungry people sort first. Portraits are generated from the name;
/// they are not a second simulation of the person.
struct CitizenDirectory: View {
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
                    CitizenCard(citizen: citizen)
                }
            }
            .padding(RepublicTheme.Space.md)
        }
        .background(RepublicTheme.cream)
    }
}

private struct CitizenCard: View {
    let citizen: Citizen
    @EnvironmentObject private var game: Game
    @State private var showDay = false
    @ScaledMetric(relativeTo: .headline) private var portraitSide: CGFloat = 56

    var body: some View {
        HStack(alignment: .top, spacing: RepublicTheme.Space.md) {
            portrait
            VStack(alignment: .leading, spacing: RepublicTheme.Space.xs) {
                Text(citizen.name)
                    .font(RepublicTheme.heading(.headline))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Age \(citizen.age) · \(citizen.occupation.spoken)")
                    .font(RepublicTheme.body(.subheadline))
                    .foregroundStyle(RepublicTheme.inkSoft)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RepublicTheme.Space.sm) { chips }
                    VStack(alignment: .leading, spacing: RepublicTheme.Space.xs) { chips }
                }
                Text("Home: \(buildingName(citizen.home))")
                    .font(RepublicTheme.body(.caption))
                    .foregroundStyle(RepublicTheme.inkSoft)
                Text("Work: \(buildingName(citizen.work))")
                    .font(RepublicTheme.body(.caption))
                    .foregroundStyle(RepublicTheme.inkSoft)
                if let notice = CitizenNeeds.attention(for: citizen.id, in: game.state) {
                    DisclosureGroup {
                        Text(notice.help).font(.caption).fixedSize(horizontal: false, vertical: true)
                    } label: {
                        Label(notice.title, systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(RepublicTheme.alert)
                    }
                }
                DisclosureGroup("Today's routine", isExpanded: $showDay) {
                    if showDay { dayDetails }
                }
                .font(RepublicTheme.body(.subheadline))
                .tint(RepublicTheme.ink)
            }
        }
        .dioramaCard(fill: RepublicTheme.sand.opacity(0.28))
        .accessibilityElement(children: .combine)
    }

    private func buildingName(_ id: BuildingID?) -> String {
        guard let id, id.raw >= 0, Int(id.raw) < game.state.buildings.count else { return "None" }
        let building = game.state.buildings[Int(id.raw)]
        let name: String
        switch building.kind {
        case .house: name = "House"
        case .farm: name = "Farm"
        case .market: name = "Market"
        case .workshop: name = "Workshop"
        case .townHall: name = "Town Hall"
        case .clinic: name = "Clinic"
        case .school: name = "School"
        case .police: name = "Police"
        case .dock: name = "Dock"
        }
        return "\(name) #\(id.raw + 1)"
    }

    private var dayDetails: some View {
        let state = game.state
        let routine = WalkerRoutine.plan(for: citizen, in: state, access: state.buildingAccess())
        return VStack(alignment: .leading, spacing: RepublicTheme.Space.xs) {
            Text("Planned island hours · roads determine reachable stops")
                .font(RepublicTheme.body(.caption))
                .foregroundStyle(RepublicTheme.inkSoft)
            ForEach(routine.stops.indices, id: \.self) { index in
                Text("\(routine.dwellStart[index]):00–\(routine.dwellEnd[index]):00 · \(routine.stops[index].rawValue.capitalized)")
                    .font(RepublicTheme.body(.caption))
            }
            if routine.stops.isEmpty { Text("No home to start a daily route.") }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, RepublicTheme.Space.xs)
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
