import SwiftUI
import PocketRepublicCore

struct MainView: View {
    @EnvironmentObject private var game: Game
    @EnvironmentObject private var clock: DayClock
    @State private var tab = ScreenshotFixture.initialTab
    @State private var confirmNewCity = false

    var body: some View {
        TabView(selection: $tab) {
            island.tabItem { Label("Island", systemImage: "map.fill") }.tag(0)
            people.tabItem { Label("People", systemImage: "person.3.fill") }.tag(1)
            govern.tabItem { Label("Govern", systemImage: "building.columns.fill") }.tag(2)
            events.tabItem { Label("Gazette", systemImage: "newspaper.fill") }.tag(3)
        }
        .tint(.mint)
        .modifier(ScreenshotFixtureIdentity())
        .onChange(of: game.state.pending?.id) { _, pendingID in
            if pendingID != nil { tab = 0 }
        }
        .onAppear { clock.note(game) }
        .onChange(of: clockCue) { _, _ in clock.note(game) }
        .onChange(of: confirmNewCity) { _, shown in
            clock.setModal("new-city", presented: shown)
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
