import SwiftUI
import PocketRepublicCore

struct MainView: View {
    @EnvironmentObject private var game: Game
    @EnvironmentObject private var clock: DayClock
    @State private var tab = 0
    @State private var confirmNewCity = false

    var body: some View {
        TabView(selection: $tab) {
            island.tabItem { Label("Island", systemImage: "map.fill") }.tag(0)
            people.tabItem { Label("People", systemImage: "person.3.fill") }.tag(1)
            govern.tabItem { Label("Govern", systemImage: "building.columns.fill") }.tag(2)
            events.tabItem { Label("Gazette", systemImage: "newspaper.fill") }.tag(3)
        }
        .tint(.mint)
        .onChange(of: game.state.pending?.id) { _, pendingID in
            if pendingID != nil { tab = 0 }
        }
        .onAppear { clock.note(game) }
        .onChange(of: clockCue) { _, _ in clock.note(game) }
        .onChange(of: confirmNewCity) { _, shown in
            clock.setModal("new-city", presented: shown)
        }
        .sheet(isPresented: $confirmNewCity) {
            NewCitySheet { origin in
                game.startNewCity(origin: origin)
                confirmNewCity = false
            }
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
            CitizenDirectory()
                .navigationTitle("People")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var govern: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RepublicTheme.Space.lg) {
                    DecreeBoard()
                    save
                }
                .padding(RepublicTheme.Space.md)
            }
            .background(RepublicTheme.cream)
            .navigationTitle("Govern")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var save: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            if game.hasPrototypeSave {
                Text("Your earlier prototype save remains on this device. This city uses a separate save.")
                    .font(RepublicTheme.body(.caption))
                    .foregroundStyle(RepublicTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let issue = game.saveIssue {
                Text(issue)
                    .font(RepublicTheme.body(.subheadline))
                    .foregroundStyle(RepublicTheme.alert)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Start New City", role: .destructive) { confirmNewCity = true }
                .frame(minHeight: 44)
        }
        .dioramaCard()
    }

    private var events: some View {
        NavigationStack {
            GazetteView()
                .navigationTitle("Gazette")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var clockCue: String {
        let agenda = game.state.agenda.map { "\($0.id.raw):\($0.islandEventID ?? -1)" }.joined(separator: ",")
        return "\(game.state.day)|\(game.state.blocksAdvance)|\(game.saveIssue ?? "")|\(agenda)"
    }
}

private struct NewCitySheet: View {
    var start: (RepublicOrigin?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The current city is replaced only when you pick a start. Your earlier prototype save stays.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    originRow(nil, "An ordinary island", "No special purse and no special grudge. The charter is still yours to earn.")
                    ForEach(RepublicOrigin.allCases, id: \.rawValue) { origin in
                        originRow(origin, origin.title, origin.pitch)
                    }
                }
                .padding(16)
            }
            .navigationTitle("New city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func originRow(_ origin: RepublicOrigin?, _ title: String, _ pitch: String) -> some View {
        Button {
            start(origin)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(pitch)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(12)
        }
        .buttonStyle(.bordered)
    }
}
