import SwiftUI
import PocketRepublicCore

struct MainView: View {
    var onIslandReady: () -> Void = {}
    @EnvironmentObject private var game: Game
    @EnvironmentObject private var clock: DayClock
    @State private var tab = 0
    @AppStorage("pocket.republic.tutorial.active-seed.v1") private var guidedSeed = ""
    @State private var confirmNewCity = false
    @State private var showSaveManager = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                island.opacity(tab == 0 ? 1 : 0).allowsHitTesting(tab == 0).accessibilityHidden(tab != 0)
                if tab == 1 { people }
                if tab == 2 { govern }
                if tab == 3 { events }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            HStack(spacing: 4) {
                navigationButton(0, "Island", "map.fill")
                navigationButton(1, "People", "person.3.fill")
                navigationButton(2, "Govern", "building.columns.fill")
                navigationButton(3, "News", "newspaper.fill")
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RepublicTheme.panel)
        }
        .tint(RepublicTheme.brass)
        .onChange(of: game.state.pending?.id) { _, pendingID in
            if pendingID != nil { tab = 0 }
        }
        .onAppear { clock.note(game) }
        .onChange(of: game.citySession) { _, _ in tab = 0; clock.note(game) }
        .onChange(of: clockCue) { _, _ in clock.note(game) }
        .onChange(of: confirmNewCity) { _, shown in
            clock.setModal("new-city", presented: shown)
        }
        .onChange(of: showSaveManager) { _, shown in
            clock.setModal("save-manager", presented: shown)
            if shown { game.refreshBackup() }
        }
        .sheet(isPresented: $showSaveManager) {
            NavigationStack {
                ScrollView { CitySaveControls(onLoaded: { showSaveManager = false }).padding(16) }
                    .navigationTitle("Your saved island").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSaveManager = false } } }
            }
        }
        .sheet(isPresented: $confirmNewCity) {
            NewCitySheet { origin in
                Task {
                    if await game.startNewCity(origin: origin) { confirmNewCity = false }
                }
            }
        }
    }

    private func navigationButton(_ value: Int, _ title: String, _ symbol: String) -> some View {
        Button {
            tab = value
            if value == 2, SettlementGuide.lessons(in: game.state).first(where: { $0.id == "arrivals" })?.complete == true {
                guidedSeed = ""
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }.frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(tab == value ? RepublicTheme.brass : RepublicTheme.paper)
            .background(tab == value ? RepublicTheme.brass.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityAddTraits(tab == value ? .isSelected : [])
    }

    private var island: some View {
        NavigationStack {
            IslandView(islandVisible: tab == 0, onGovern: { tab = 2 }, onReady: onIslandReady)
                .id(game.citySession)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var people: some View {
        NavigationStack {
            CitizenDirectory()
                .navigationTitle("People")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbarBackground(RepublicTheme.cream, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var govern: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RepublicTheme.Space.lg) {
                    Text("A town to look after").font(RepublicTheme.heading(.title2)).foregroundStyle(RepublicTheme.ink)
                    Text("Listen to your neighbours. Decide what kind of place this will become.")
                        .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
                    DecreeBoard()
                    DisclosureGroup("Where could we go next?") { DevelopmentRoadmap() }
                        .foregroundStyle(RepublicTheme.ink)
                    save
                }
                .padding(RepublicTheme.Space.md)
            }
            .background(RepublicTheme.cream)
            .navigationTitle("Govern")
            .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbarBackground(RepublicTheme.cream, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
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
            if let date = game.lastSavedAt {
                Label("Saved \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.icloud")
                    .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
            }
            Button("Saved island & recovery") { showSaveManager = true }.frame(minHeight: 44)
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
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbarBackground(RepublicTheme.cream, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var clockCue: String {
        let agenda = game.state.agenda.map { "\($0.id.raw):\($0.islandEventID ?? -1)" }.joined(separator: ",")
        return "\(game.state.day)|\(game.state.blocksAdvance)|\(game.saveIssue ?? "")|\(agenda)"
    }
}

struct NewCitySheet: View {
    @EnvironmentObject private var game: Game
    var start: (RepublicOrigin?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose a founding charter. The selected city is replaced only after the new city is safely saved; a verified previous save becomes the rolling backup. Your earlier prototype save stays.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    originRow(nil, "An ordinary island", "No special purse and no special grudge. The charter is still yours to earn.")
                    if game.busy { ProgressView("Preparing and saving the new island…") }
                    if let feedback = game.feedback { Text(feedback).foregroundStyle(RepublicTheme.alert) }
                    ForEach(RepublicOrigin.allCases, id: \.rawValue) { origin in
                        originRow(origin, origin.title, origin.pitch)
                    }
                }
                .padding(16)
            }
            .onAppear { game.clearFeedback() }
            .interactiveDismissDisabled(game.busy)
            .navigationTitle("New city")
            .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbarBackground(RepublicTheme.cream, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(game.busy)
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
        .buttonStyle(.bordered).disabled(game.busy)
    }
}

/// Shared by boot recovery and the in-game save browser. Loading a backup is
/// always explicit; a failed read never offers saving the placeholder city.
struct CitySaveControls: View {
    @EnvironmentObject private var game: Game
    var onLoaded: () -> Void = {}
    @State private var confirmRestore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("On this device").font(.title2.weight(.bold))
            Text("Your island saves as you play. You can also go back to the previous save if you need to.")
                .font(.subheadline)
            if let issue = game.saveIssue {
                Label(issue, systemImage: "exclamationmark.triangle.fill").foregroundStyle(RepublicTheme.alert)
                if game.canRetrySave {
                    Button("Retry Save") { game.retrySave() }
                        .frame(minHeight: 44).buttonStyle(.borderedProminent)
                    Text("Try saving again to keep the changes you’ve just made. Loading an older save would lose them.").font(.caption)
                } else {
                    Button("Retry Load") { Task { _ = await game.retryLoad() } }
                        .frame(minHeight: 44).buttonStyle(.bordered)
                }
            } else {
                Text("Current island · Day \(game.state.day) · \(game.state.citizens.filter(\.alive).count) residents")
                    .font(.headline)
                if let date = game.lastSavedAt { Text("Saved \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption) }
                Button("Save Now") { game.saveNow(); game.refreshBackup() }
                    .frame(minHeight: 44).buttonStyle(.bordered)
                Button("Continue") { onLoaded() }.frame(minHeight: 44).buttonStyle(.borderedProminent)
            }
            if let backup = game.backupPreview {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Previous save · Day \(backup.day)", systemImage: "clock.arrow.circlepath").font(.headline)
                    Text("\(backup.residents) residents").font(.subheadline)
                    if let date = backup.savedAt { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption) }
                    Button("Restore this backup", role: .destructive) { confirmRestore = true }
                        .frame(minHeight: 44).buttonStyle(.bordered)
                    Text("Go back to this point in your island’s story. Anything you did after it will be lost. We keep one previous save, not a list of islands.").font(.caption)
                }.padding(12).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Your previous save will appear here after you’ve played a little longer.").font(.caption)
            }
            if let feedback = game.feedback { Text(feedback).font(.caption).foregroundStyle(RepublicTheme.brass) }
            if game.busy { ProgressView("Checking and restoring the island…") }
            Text("If a save won’t open, we keep it safe. Your saves stay on this device.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(game.busy)
        .confirmationDialog("Replace the selected island with this backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore backup", role: .destructive) {
                Task { if await game.restoreBackup() { onLoaded() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Progress after the displayed backup will be lost. The currently selected file is preserved separately before replacement.") }
        .task { game.clearFeedback(); game.refreshBackup() }
    }
}
