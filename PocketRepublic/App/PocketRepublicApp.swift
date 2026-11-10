import SwiftUI

@main struct PocketRepublicApp: App {
    @StateObject private var game = Game()
    @StateObject private var clock = DayClock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RepublicLaunchView()
                .environmentObject(game).environmentObject(clock)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in clock.setSceneActive(phase == .active) }
                .onChange(of: game.busy) { _, busy in clock.setModal("storage-work", presented: busy) }
        }
    }
}

/// A real boot gate: no economic timer or scene is mounted until the player
/// continues a verified city. The artwork is the actual installed game family.
private struct RepublicLaunchView: View {
    @EnvironmentObject private var game: Game
    @EnvironmentObject private var clock: DayClock
    @State private var entered = false
    @State private var startingMap = false
    @State private var mapReady = false
    @State private var mapAttempt = UUID()
    @State private var newCity = false
    @State private var showRecovery = false

    var body: some View {
        ZStack {
            if entered {
                let attempt = mapAttempt
                MainView(onIslandReady: {
                    guard entered, mapAttempt == attempt else { return }
                    mapReady = true; startingMap = false; clock.setModal("launch", presented: false)
                })
                    .allowsHitTesting(mapReady).accessibilityHidden(!mapReady)
                    .onAppear { clock.attach(game); clock.setModal("launch", presented: !mapReady) }
            }
            if !entered || !mapReady { welcome.zIndex(10) }
        }
        .onChange(of: game.citySession) { _, _ in
            mapReady = false
            clock.setModal("launch", presented: true)
        }
        .onAppear { clock.setModal("launch", presented: !entered || !mapReady) }
        .task { await game.prepare() }
        .sheet(isPresented: $showRecovery) {
            NavigationStack {
                ScrollView {
                    CitySaveControls(onLoaded: { showRecovery = false; enterIsland() }).padding(16)
                }
                .navigationTitle("Your saved island").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showRecovery = false }.disabled(game.busy) } }
            }
        }
        .sheet(isPresented: $newCity) {
            NewCitySheet { origin in
                Task {
                    if await game.startNewCity(origin: origin) { newCity = false; enterIsland() }
                }
            }
        }
    }

    private func enterIsland() {
        mapAttempt = UUID()
        let attempt = mapAttempt
        startingMap = true
        Task { await Task.yield(); if mapAttempt == attempt { entered = true } }
    }

    private func cancelMapLoading() {
        mapAttempt = UUID()
        entered = false; startingMap = false; mapReady = false
        clock.setModal("launch", presented: true)
    }

    private var welcome: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: geometry.size.height < 500 ? 12 : 22) {
                    Text("POCKET REPUBLIC").font(.system(.title, design: .rounded).weight(.bold))
                        .tracking(2).foregroundStyle(RepublicTheme.brass).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                    HStack(alignment: .bottom, spacing: -18) {
                        Image("building_house_golden").resizable().scaledToFit().frame(maxWidth: 94, maxHeight: 104)
                        Image("building_townHall_golden").resizable().scaledToFit().frame(maxWidth: 150, maxHeight: 174)
                        Image("building_farm_golden").resizable().scaledToFit().frame(maxWidth: 116, maxHeight: 100)
                    }
                    .frame(maxWidth: .infinity).frame(height: min(180, max(80, geometry.size.height * 0.26))).accessibilityHidden(true)
                    Text("A small island. A republic to shape.")
                        .font(.title3.weight(.medium)).multilineTextAlignment(.center)
                    if !game.launchReady || startingMap || (entered && !mapReady) {
                        ProgressView(game.launchReady ? "Opening the island map…" : game.loadingMessage)
                            .frame(minHeight: 44).accessibilityLabel(game.launchReady ? "Opening the island map" : game.loadingMessage)
                        if game.launchReady {
                            Button("Back to saved island", action: cancelMapLoading)
                                .frame(minHeight: 44).buttonStyle(.bordered)
                        }
                        Text("Checking the city file and preparing the island. Time is held until the map is ready.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    } else {
                        cityActions
                    }
                }
                .padding(24).frame(maxWidth: 540)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .background(LinearGradient(colors: [Color(red: 0.04, green: 0.13, blue: 0.16), RepublicTheme.panel],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var cityActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            if game.saveIssue == nil {
                Text("Your island · Day \(game.state.day)").font(.headline)
                Text("\(game.state.citizens.filter(\.alive).count) residents · $\(game.state.treasury)")
                    .font(.subheadline.monospacedDigit())
                if let date = game.lastSavedAt {
                    Text("Saved \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Continue your republic", action: enterIsland)
                    .frame(maxWidth: .infinity, minHeight: 48).buttonStyle(.borderedProminent).tint(RepublicTheme.terracotta)
                Button("Saved island & backup") { showRecovery = true }
                    .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.bordered)
                Text("Days begin when you continue. Your island did not advance while the app was closed.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                CitySaveControls(onLoaded: enterIsland)
            }
            if let feedback = game.feedback {
                Text(feedback).font(.caption).foregroundStyle(RepublicTheme.brass)
            }
            Button("Start a new city", role: .destructive) { newCity = true }
                .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.bordered)
                .disabled(game.busy)
            Text("New City replaces the selected island only after its save succeeds. A verified previous save is kept as a rolling backup.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(18).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .disabled(game.busy)
    }
}
