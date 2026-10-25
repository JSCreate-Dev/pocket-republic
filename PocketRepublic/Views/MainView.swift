import SwiftUI
import PocketRepublicCore

struct MainView: View {
    @EnvironmentObject private var game: Game
    @State private var tab = 0
    @State private var confirmNewCity = false

    var body: some View {
        TabView(selection: $tab) {
            island.tabItem { Label("Island", systemImage: "map.fill") }.tag(0)
            people.tabItem { Label("People", systemImage: "person.3.fill") }.tag(1)
            govern.tabItem { Label("Govern", systemImage: "building.columns.fill") }.tag(2)
            events.tabItem { Label("Events", systemImage: "newspaper.fill") }.tag(3)
        }
        .tint(.mint)
        .onChange(of: game.state.pending?.id) { _, pendingID in
            if pendingID != nil { tab = 0 }
        }
        .confirmationDialog("Start a new city?", isPresented: $confirmNewCity) {
            Button("Start New City", role: .destructive) { game.startNewCity() }
        } message: {
            Text("This replaces the spatial city save. Your earlier prototype save stays untouched.")
        }
    }

    private var island: some View {
        NavigationStack {
            IslandView()
                .navigationTitle("Pocket Republic")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var people: some View {
        NavigationStack {
            List(game.state.citizens.filter(\.alive)) { citizen in
                VStack(alignment: .leading, spacing: 3) {
                    Text(citizen.name).font(.headline)
                    Text("\(String(describing: citizen.occupation).capitalized) · Happiness \(citizen.happiness)% · $\(citizen.money)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Citizens")
        }
    }

    private var govern: some View {
        NavigationStack {
            Form {
                Section("Government") {
                    Text("Legitimacy: \(game.snapshot.legitimacy)%")
                    Text("Corruption: \(game.snapshot.corruption)%")
                    Stepper("Income tax: \(game.state.policy.incomeTaxPercent)%", value: Binding(
                        get: { Int(game.state.policy.incomeTaxPercent) },
                        set: { newValue in
                            var next = game.state.policy
                            next.incomeTaxPercent = Int32(newValue)
                            game.send(.setPolicy(next))
                        }
                    ), in: 0...60, step: 5)
                }
                .disabled(game.saveIssue != nil)

                Section("Decisions") {
                    ForEach(game.state.agenda) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.kind.title).font(.headline)
                            if let cause = item.causes.first {
                                Text("\(cause.detail): \(cause.value)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(item.options) { option in
                                Button(option.label) {
                                    game.send(.resolveAgendaItem(item.id, option: option.id))
                                }
                            }
                        }
                    }
                }
                .disabled(game.saveIssue != nil)

                Section("Save") {
                    if game.hasPrototypeSave {
                        Text("Your earlier prototype save remains on this device. This city uses a separate save.")
                            .font(.caption)
                    }
                    if let issue = game.saveIssue { Text(issue).foregroundStyle(.red) }
                    Button("Start New City", role: .destructive) { confirmNewCity = true }
                }
            }
            .navigationTitle("Government")
        }
    }

    private var events: some View {
        NavigationStack {
            List(Array(game.state.events.reversed())) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.kind.title).font(.headline)
                    Text("Day \(event.day)" + event.causes.first.map { " · \($0.detail)" }.orEmpty)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Events")
        }
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

private extension AgendaKind {
    var title: String {
        switch self {
        case .factionDemand: return "Faction demand"
        case .advisoryTradeoff: return "Council advice"
        case .decree: return "Decree"
        case .buildingCommission: return "New building commission"
        case .election: return "Election"
        }
    }
}

private extension EventKind {
    var title: String { rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
}
