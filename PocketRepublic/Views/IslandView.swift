import SwiftUI
import SpriteKit
import UIKit
import PocketRepublicCore

/// Screen-space controls use the local scene geometry and Apple's reserved regions.
/// The SpriteKit world stays behind them and is never part of the saved simulation.
struct IslandView: View {
    var islandVisible: Bool
    var onGovern: () -> Void = {}
    var onReady: () -> Void = {}
    @EnvironmentObject private var game: Game
    @EnvironmentObject private var clock: DayClock
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var appPhase
    @AppStorage("pocket.republic.intro.seed.v1") private var touredSeed = ""
    @AppStorage("pocket.republic.intro.enabled.v1") private var automaticTours = true
    @AppStorage("pocket.republic.tutorial.active-seed.v1") private var guidedSeed = ""
    @AppStorage("pocket.republic.field-guide.visible.v1") private var showFieldGuide = true
    @AppStorage("pocket.republic.opening-journey.v1") private var journeyRecord = ""
    @State private var hudHeight: CGFloat = 0
    @State private var dockHeight: CGFloat = 0
    @State private var sceneReady = false
    @State private var scene = IslandScene(size: CGSize(width: 400, height: 470))
    @State private var tool: CityTool = .inspect
    @State private var selectedTile: TileIndex?
    @State private var selectedBuildingID: BuildingID?
    @State private var selectedCitizenID: CitizenID?
    @State private var citizenActivity = ""
    @State private var selectedAgendaID: DecisionID?
    @State private var placementHint: String?
    @State private var sheetExpanded = false
    @State private var tentMode = false
    @State private var tentControlsOpen = false
    @State private var dismissedIslandEvent: DecisionID?
    @State private var dismissedBlocking: DecisionID?
    @State private var seenSeason: String?
    @State private var seasonBanner: String?
    @State private var showCatalog = false
    @State private var queuedBuilding: BuildingKind?
    @State private var queuedBuildingSeed: UInt64?
    @State private var islandMoment: String?
    @State private var momentUntilDay: Int32 = -1
    @State private var showBuildHelp = false
    @State private var showCharter = false
    @State private var showRoadmap = false
    @State private var unlockedBanner: DevelopmentUnlock?
    @State private var placeTile: TileIndex?
    @State private var roadDraft: [TileIndex] = []
    @State private var placementReceipt: PlacementReceipt?
    @State private var roadReceipt: RoadReceipt?
    @State private var mapOverlay: MapOverlayMode = .standard
    @State private var showLayerHelp = false
    @State private var showNoticesHelp = false
    @AppStorage("pocket.republic.map-notices.v1") private var mapNotices = true
    @State private var showGrowth = false
    @State private var showJournal = false
    @State private var focusGoals: [CityFocus] = []
    @State private var guideLessons: [SettlementLesson] = []
    @State private var dayBaseline: CityDaySnapshot?
    @State private var dayResults: [CityDayResult] = []
    @State private var queuedFocus: CityFocusAction?
    @State private var queuedTour = false
    @State private var queuedGovernment = false
    @State private var tour = FoundingTourPolicy()
    @State private var tourRun = UUID()

    var body: some View {
        GeometryReader { geometry in
            let layout = CityDisplayLayout(geometry: geometry,
                                           verticalSizeClass: verticalSizeClass,
                                           layoutDirection: layoutDirection,
                                           tentMode: tentMode,
                                           sheetExpanded: sheetExpanded,
                                           tentControlsOpen: tentControlsOpen,
                                           detailOpen: detailOpen,
                                           cardOpen: cardOpen,
                                           hudHeight: hudHeight, dockHeight: dockHeight)
            ZStack(alignment: .topLeading) {
                SpriteView(scene: scene, isPaused: !islandVisible || appPhase != .active)
                    .allowsHitTesting(!tour.active).accessibilityHidden(tour.active)
                    .background(Color(red: 0.05, green: 0.22, blue: 0.37))

                if layout.mapFirst {
                    HStack(alignment: .top, spacing: 8) {
                        status(in: layout)
                            .frame(maxWidth: 560)
                            .background(GeometryReader { hud in
                                Color.clear.preference(key: IslandHUDHeight.self, value: hud.size.height)
                            })
                        Spacer(minLength: 0)
                        if layout.canUseTent {
                            Button {
                                tentMode.toggle()
                                tentControlsOpen = false
                                sheetExpanded = false
                            } label: {
                                Label(tentMode ? "Single screen" : "Tent view",
                                      systemImage: "rectangle.split.2x1")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityHint("Switches the outer landscape display between a bottom panel and a map-first tent view")
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .opacity(tour.active ? 0 : 1).allowsHitTesting(!tour.active).accessibilityHidden(tour.active)
                }

                if layout.mapFirst, !tour.active, let tile = selectedTile, !cardOpen, tool == .inspect {
                    HStack(spacing: 8) {
                        Text("Tile \(game.state.map.x(of: tile)), \(game.state.map.y(of: tile)) · \(terrainLabel(at: tile))\(overlayTileDescription(tile))")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                        Button { selectedTile = nil } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Close tile inspection")
                    }
                    .padding(.leading, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .frame(width: max(0, min(420, layout.focus.width - 16)))
                    .position(x: layout.focus.midX, y: max(28, layout.focus.maxY - 32))
                }

                if layout.mode == .tent && !tentControlsOpen {
                    tentDock()
                        .opacity(tour.active ? 0 : 1).allowsHitTesting(!tour.active).accessibilityHidden(tour.active)
                        .frame(width: layout.controls.width, height: layout.controls.height)
                        .position(x: layout.controls.midX, y: layout.controls.midY)
                } else {
                    controls(in: layout)
                        .frame(width: layout.controls.width, height: layout.controls.height)
                        .background {
                            if layout.mapFirst && detailOpen {
                                UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                                    .fill(.regularMaterial)
                            } else if !layout.mapFirst {
                                Rectangle().fill(.regularMaterial)
                            }
                        }
                        .position(x: layout.controls.midX, y: layout.controls.midY)
                        .opacity(tour.active ? 0 : 1).allowsHitTesting(!tour.active).accessibilityHidden(tour.active)
                }
                if tour.active {
                    if layout.mapFirst {
                        foundingTourOverlay.transition(.opacity).zIndex(20)
                    } else {
                        foundingTourOverlay
                            .frame(width: layout.controls.width, height: layout.controls.height)
                            .position(x: layout.controls.midX, y: layout.controls.midY)
                            .transition(.opacity).zIndex(20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(Rectangle())
            .onPreferenceChange(IslandHUDHeight.self) { hudHeight = $0 }
            .onPreferenceChange(IslandDockHeight.self) { dockHeight = $0 }
            .onAppear {
                let session = game.citySession
                scene.onFirstFrame = {
                    guard game.citySession == session else { return }
                    sceneReady = true
                    onReady()
                    considerOpeningTour()
                }
                scene.scaleMode = .resizeFill
                scene.setFraming(layout.framing)
                scene.render(game.state)
                scene.setOverlay(mapOverlay)
                scene.setNoticesVisible(mapNotices)
                scene.setSelection(selectedBuildingID)
                scene.setCitizenSelection(selectedCitizenID)
                configureTapHandler()
                presentAttention()
                if seenSeason == nil { seenSeason = seasonSignature }
                considerOpeningTour()
            }
            .sensoryFeedback(.selection, trigger: selectedBuildingID) { _, newValue in
                newValue != nil
            }
            .onChange(of: layout.framing) { _, framing in
                scene.setFraming(framing)
            }
        }
        .sheet(isPresented: $showCatalog, onDismiss: finishCatalog) {
            CityReadingSheet("Build something") { catalog }
        }
        .sheet(isPresented: $showJournal, onDismiss: finishJournal) {
            CityReadingSheet("Island Journal") {
                IslandJournalPanel(goals: focusGoals, lessons: guideLessons, results: dayResults,
                    automaticTours: $automaticTours,
                    canTour: !game.state.blocksAdvance && game.saveIssue == nil && tool == .inspect,
                    onGoal: { action in queuedFocus = action; showJournal = false },
                    onTour: { queuedTour = true; showJournal = false },
                    onGuide: startTutorial,
                    onGovernment: { queuedGovernment = true; showJournal = false })
            }
        }
        .task(id: tourRun) {
            guard tour.active else { return }
            await Task.yield()
            guard !Task.isCancelled, tour.active else { return }
            scene.presentTourBeat(tour.beat, reduceMotion: reduceMotion || UIAccessibility.isVoiceOverRunning)
            guard !UIAccessibility.isVoiceOverRunning else { return }
            for _ in 0..<(FoundingTourPolicy.beatCount - 1) {
                do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
                guard !Task.isCancelled, tour.active else { return }
                guard !UIAccessibility.isVoiceOverRunning else { return }
                guard tour.advanceAutomatically() else { return }
                scene.presentTourBeat(tour.beat, reduceMotion: reduceMotion)
            }
        }
        .onChange(of: mapNotices) { _, shown in scene.setNoticesVisible(shown) }
        .onChange(of: reduceMotion) { _, reduced in if reduced { scene.stopTourMotion() } }
        .onChange(of: appPhase) { _, phase in
            if phase != .active { finishTour() } else { considerOpeningTour() }
        }
        .onChange(of: game.saveIssue) { _, issue in if issue != nil { finishTour() } }
        .sheet(isPresented: $showRoadmap) {
            CityReadingSheet("Republic Roadmap") {
                DevelopmentRoadmap()
                SeasonCard()
            }
        }
        .sheet(isPresented: $showGrowth) {
            CityReadingSheet("New neighbours") { growthDetails }
        }
        .sheet(isPresented: $showCharter) {
            CityReadingSheet("Your island’s story") { SeasonCard() }
        }
        .sheet(isPresented: $showNoticesHelp) {
            CityReadingSheet("Map notices") {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Broken link: a building needs road access", systemImage: "link")
                    Label("Question mark: a building needs workers", systemImage: "person.fill.questionmark")
                    Label("Fork and knife: a market or resident needs food", systemImage: "fork.knife")
                    Label("Blue hammer: construction is still in progress", systemImage: "hammer.fill")
                    Label("Green seal: a building opened today", systemImage: "checkmark.seal.fill")
                    Label("House: a resident needs housing", systemImage: "house.fill")
                    Label("Briefcase: a resident is looking for work", systemImage: "briefcase.fill")
                    Text("Tap a notice to inspect its building or resident and read the next step. Problems take priority over opening notices. Up to 12 building and 6 resident notices appear nearby; resident notices follow visible walkers and hide indoors. The People tab covers everyone, including residents without a map position.")
                    Text("Notices clear as the underlying problem clears. They hide while building, drawing roads or using data overlays. Turn them off from the map menu any time.")
                }.font(.subheadline).foregroundStyle(RepublicTheme.ink)
            }
        }
        .sheet(isPresented: $showLayerHelp) {
            CityReadingSheet(mapOverlay.title) {
                Text(mapOverlay.legend)
                    .font(.body).frame(maxWidth: .infinity, alignment: .leading)
                    .padding().dioramaCard()
                Text("Layers show current simulation data. They do not spend money or change the city. Choose Normal map to restore the usual picture.")
                    .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
            }
        }
        .task(id: unlockedBanner) {
            guard let earned = unlockedBanner else { return }
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled, unlockedBanner == earned else { return }
            unlockedBanner = nil
        }
        .onReceive(game.$state) { state in
            observeIsland(state)
            if state.blocksAdvance || game.saveIssue != nil { finishTour() }
            if let id = selectedCitizenID,
               id.raw < 0 || Int(id.raw) >= state.citizens.count || !state.citizens[Int(id.raw)].alive {
                selectedCitizenID = nil
            }
            if let receipt = placementReceipt, state.map.buildingAt(receipt.anchor) != receipt.id {
                placementReceipt = nil
            }
            if let selectedBuildingID,
               BuildingHitTest.occupiedTiles(selectedBuildingID, on: state.map).isEmpty {
                self.selectedBuildingID = nil
            }
            scene.render(state)
            if let selectedAgendaID, !state.agenda.contains(where: { $0.id == selectedAgendaID }) {
                self.selectedAgendaID = nil
            }
        }
        .onChange(of: game.state.worldSeed) { _, _ in
            finishTour()
            queuedFocus = nil
            queuedTour = false
            queuedGovernment = false
            showJournal = false
            leaveBuildSession()
            selectedAgendaID = nil
            dismissedIslandEvent = nil
            dismissedBlocking = nil
            seenSeason = seasonSignature
            seasonBanner = nil
            showGrowth = false
            showLayerHelp = false
            showCharter = false
            mapOverlay = .standard
            selectedCitizenID = nil
            showRoadmap = false
            unlockedBanner = nil
            placementReceipt = nil
            roadReceipt = nil
            selectedBuildingID = nil
            selectedTile = nil
            considerOpeningTour()
        }
        .onChange(of: game.state.treasury) { _, _ in
            if tool == .road { scene.setRoadPreview(roadMarks) }
        }
        .onChange(of: mapOverlay) { _, mode in
            scene.setOverlay(mode)
        }
        .onChange(of: tool) { _, newTool in
            if newTool != .inspect {
                selectedCitizenID = nil
                selectedBuildingID = nil
                scene.setSelection(nil)
            }
            if newTool != .road {
                roadDraft = []
                scene.setRoadPreview([])
            }
            if !newTool.isBuilding { placeTile = nil }
            if newTool != .inspect { showCatalog = false }
            clock.setModal(IslandSessionHold.buildToken, presented: false)
            configureTapHandler()
        }
        .onChange(of: showRoadmap) { _, shown in
            clock.setModal("roadmap", presented: false)
        }
        .onChange(of: game.state.development?.unlocked ?? []) { old, new in
            guard let earned = new.last(where: { !old.contains($0) }) else { return }
            unlockedBanner = earned
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: "Unlocked \(earned.title). \(earned.reward)")
        }
        .onChange(of: showCatalog) { _, shown in
            if shown { selectedCitizenID = nil }
            clock.setModal(IslandSessionHold.catalogToken, presented: shown)
        }
        .onChange(of: islandVisible) { _, visible in
            if !visible { finishTour(); leaveBuildSession() } else { considerOpeningTour() }
        }
        .onDisappear {
            finishTour()
            if !islandVisible { leaveBuildSession() }
        }
        .onChange(of: selectedCitizenID) { _, id in
            citizenActivity = ""
            scene.setCitizenSelection(id)
        }
        .onChange(of: selectedBuildingID) { _, id in
            scene.setSelection(id)
            if let building = selectedBuilding, building.kind.showsServiceReach, !building.isUnderConstruction {
                scene.showInspectReach(from: building.tile)
            } else {
                scene.showInspectReach(from: nil)
            }
        }
        .onChange(of: attentionCue) { _, _ in
            presentAttention()
        }
        .onChange(of: seasonSignature) { _, newValue in
            let previous = seenSeason
            seenSeason = newValue
            guard previous != nil, previous != newValue else { return }
            seasonBanner = SeasonCopy.celebration(game.state)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    @ViewBuilder private func controls(in layout: CityDisplayLayout) -> some View {
        let scrolling = VStack(spacing: 8) {
            if let chip = attentionChip {
                Button {
                    selectedAgendaID = chip.id
                    showCatalog = false
                } label: {
                    Text(previewTitle(chip))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(RepublicDockButton())
                .accessibilityHint("Opens this decision without covering the map")
            }
            if let pending = game.state.pending {
                crisisCard(pending, layout: layout)
            } else if let item = selectedAgenda {
                agendaCard(item, layout: layout)
            } else if tool.isBuilding {
                placeBar
            } else if tool == .road {
                roadBar
            } else {
                if let citizen = selectedCitizen {
                    citizenCard(citizen)
                } else if let inspection = buildingInspection {
                    if let building = selectedBuilding, mapOverlay != .standard {
                        Text(String(overlayTileDescription(building.anchor).dropFirst(3)))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                    }
                    if let id = selectedBuildingID, let issue = BuildingInspector.attention(id: id, in: game.state) {
                        Text(issue.help).font(.caption).foregroundStyle(RepublicTheme.brass)
                            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 8)
                    }
                    BuildingInspectPanel(
                        inspection: inspection,
                        underConstruction: selectedBuilding?.isUnderConstruction == true,
                        onClose: { selectedBuildingID = nil },
                        onSetMode: { mode in
                            game.send(.setOperatingMode(inspection.buildingID, mode))
                        },
                        onDemolish: {
                            game.send(.demolish(inspection.buildingID))
                        }
                    )
                    .frame(maxWidth: layout.cardWidth, alignment: .leading)
                } else if let selectedTile, !layout.mapFirst {
                    let x = game.state.map.x(of: selectedTile)
                    let y = game.state.map.y(of: selectedTile)
                    Text("Tile \(x), \(y) · \(terrainLabel(at: selectedTile))\(overlayTileDescription(selectedTile))")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                }
                if !layout.mapFirst {
                    toolStrip(compact: layout.compactTools, narrow: false)
                }
            }
        }
        .padding(.horizontal, 8)

        VStack(spacing: 8) {
            if layout.mapFirst {
                EmptyView()
            } else if layout.isSingleScreen {
                sheetGrabber(layout)
            } else {
                status(in: layout)
                    .padding(.horizontal, 8)
            }
            if layout.mapFirst {
                if detailOpen {
                    ScrollView(.vertical, showsIndicators: true) { scrolling }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            } else if layout.scrollControls {
                ScrollView(.vertical, showsIndicators: true) { scrolling }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                scrolling
            }
            if layout.mapFirst {
                mapDock(wide: layout.controls.width >= 640)
            } else {
                if tool.isBuilding { placementActions.padding(.horizontal, 8) }
                dayClockControls
                    .padding(.horizontal, 8)
                Button { game.advance() } label: {
                    Label("Advance One Day", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(game.state.blocksAdvance || game.saveIssue != nil)
                .padding(.horizontal, 8)
            }
        }
        .padding(.top, layout.occlusionTopInset)
        .padding(.bottom, 8)
    }

    private func mapDock(wide: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            if wide {
                HStack(spacing: 8) {
                    dockTools
                    Rectangle().fill(RepublicTheme.paper.opacity(0.15)).frame(width: 1, height: 24)
                    clockTools
                }
            }
            VStack(spacing: 6) {
                HStack(spacing: 6) { dockTools }
                HStack(spacing: 6) { clockTools }
            }
        }
        .padding(8)
        .background(RepublicTheme.panel.opacity(0.97), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(RepublicTheme.brass.opacity(0.25)))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .frame(maxWidth: 680)
        .padding(.horizontal, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { dock in
            Color.clear.preference(key: IslandDockHeight.self, value: dock.size.height)
        })
    }

    @ViewBuilder private var dockTools: some View {
        if tool.isBuilding {
            placementActions
        } else {
        dockTool(.inspect)
        Button {
            leaveBuildSession()
            queuedBuilding = nil
            showCatalog = true
        } label: {
            Label("Build", systemImage: "hammer.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(RepublicDockButton(selected: showCatalog || tool.isBuilding))
        .accessibilityLabel(showCatalog ? "Close build catalog" : "Open build catalog")
        dockTool(.road)
        }
    }

    private var clockButtonTitle: String {
        if case .paused = clock.policy.pace { return "Play" }
        return clock.policy.tickInterval == nil ? "Waiting" : "Pause"
    }

    @ViewBuilder private var clockTools: some View {
        Button {
            clock.togglePause()
        } label: {
            Label(clockButtonTitle, systemImage: clock.policy.pace == .paused ? "play.fill" : "pause.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(RepublicDockButton())
        .accessibilityHint("Pauses or resumes automatic days")
        Menu {
            Button("Slow · 6 seconds per day") { clock.setPace(.playing(DayClockPolicy.leisurely)) }
            Button("Normal · 3.5 seconds per day") { clock.setPace(.playing(DayClockPolicy.steady)) }
            Button("Fast · 2 seconds per day") { clock.setPace(.playing(DayClockPolicy.brisk)) }
        } label: {
            Image(systemName: "speedometer").frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(RepublicDockButton())
        .accessibilityLabel("Day speed")
        Button { game.advance() } label: {
            Label("Next Day", systemImage: "forward.end.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(RepublicDockButton(primary: true))
        .disabled(game.state.blocksAdvance || game.saveIssue != nil)
    }

    private func dockTool(_ option: CityTool) -> some View {
        Button {
            leaveBuildSession()
            tool = option
            showCatalog = false
            configureTapHandler()
        } label: {
            Label(option.label, systemImage: option.symbol)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(RepublicDockButton(selected: tool == option))
        .accessibilityLabel("\(option.label) tool")
        .accessibilityAddTraits(tool == option ? .isSelected : [])
    }

    private func sheetGrabber(_ layout: CityDisplayLayout) -> some View {
        HStack {
            Button {
                sheetExpanded.toggle()
            } label: {
                Capsule().fill(.secondary).frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sheetExpanded ? "Collapse controls" : "Expand controls")
            if layout.mode == .tent {
                Button("Hide controls", systemImage: "chevron.down") {
                    tentControlsOpen = false
                    sheetExpanded = false
                }
                .font(.caption)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 8)
        .gesture(DragGesture(minimumDistance: 16).onEnded { value in
            if value.translation.height < -36 { sheetExpanded = true }
            if value.translation.height > 36 { sheetExpanded = false }
        })
    }

    private func tentDock() -> some View {
        Button {
            tentControlsOpen = true
        } label: {
            HStack {
                Label("Open city controls", systemImage: "slider.horizontal.3")
                Spacer()
                Text("Day \(game.snapshot.day)")
                Image(systemName: "chevron.up")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
        .accessibilityHint("Shows tools, decisions, and the Next Day button")
    }

    private func status(in layout: CityDisplayLayout) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        dayPopulation
                        resourceStrip
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        dayPopulation
                        resourceStrip
                    }
                }
                Spacer(minLength: 0)
                Menu {
                    Button(roadmapLine, systemImage: "flag.fill") {
                        if DevelopmentTree.isEnabled(in: game.state) { showRoadmap = true }
                        else { showCharter = true }
                    }
                    Button("Island notebook", systemImage: "book.closed") { showJournal = true }
                    Button("Let’s build your town", systemImage: "graduationcap") { startTutorial() }
                        .disabled(game.state.blocksAdvance || game.saveIssue != nil)
                    Toggle("Building & resident notices", isOn: $mapNotices)
                    Button("Explain map icons", systemImage: "info.circle") { showNoticesHelp = true }
                    Divider()
                    Picker("Map layer", selection: $mapOverlay) {
                        ForEach(MapOverlayMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                } label: {
                    Image(systemName: mapOverlay == .standard ? "square.3.layers.3d" : mapOverlay.symbol)
                        .foregroundStyle(RepublicTheme.brass)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Map layers and Island Journal: \(mapOverlay.title)")
                .accessibilityHint("Switches fertility, happiness, food access and job overlays")
            }
            if mapOverlay != .standard {
                HStack(spacing: 8) {
                    Label(mapOverlay.title, systemImage: mapOverlay.symbol)
                        .font(.caption.weight(.semibold)).foregroundStyle(RepublicTheme.brass)
                    Spacer(minLength: 0)
                    Button { showLayerHelp = true } label: {
                        Image(systemName: "info.circle").frame(width: 44, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Explain \(mapOverlay.title) colors")
                }
            }
            if guidedSeed == String(game.state.worldSeed) {
                tutorialCoach
            } else {
            if let issue = game.saveIssue {
                Text(issue).font(.caption).foregroundStyle(.red)
            } else if let hint = tool.isBuilding ? placementHint : game.feedback {
                Text(hint).font(.caption).foregroundStyle(RepublicTheme.brass).lineLimit(2)
            } else if hungryResidents > 0 {
                Button { performFocus(.overlay(.foodAccess)) } label: {
                    Label("\(hungryResidents) neighbours need food", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold)).foregroundStyle(RepublicTheme.sand)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            if unlockedBanner == nil && mapOverlay == .standard && game.saveIssue == nil && game.feedback == nil && !tool.isBuilding && hungryResidents == 0 {
                Button { performFocus(islandPrompt.action) } label: {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let result = dayResults.first, result.populationDelta > 0 || result.newlyOpened > 0 {
                                Text(result.headline).fontWeight(.semibold).foregroundStyle(RepublicTheme.brass)
                            }
                            Text(developmentHint).lineLimit(2)
                            Text(islandPrompt.button).foregroundStyle(RepublicTheme.brass)
                        }
                        Image(systemName: "arrow.right.circle")
                    }
                    .font(.caption2).foregroundStyle(RepublicTheme.paper.opacity(0.85))
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Take the next step on your island")
            }
            }
            if let islandMoment, game.state.day <= momentUntilDay {
                HStack(alignment: .top) {
                    Label(islandMoment, systemImage: "sparkles").font(.caption.weight(.medium))
                    Spacer(minLength: 4)
                    Button { self.islandMoment = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss town news")
                }.foregroundStyle(RepublicTheme.brass)
            }
            if let seasonBanner {
                Text(seasonBanner).font(.caption.weight(.bold)).foregroundStyle(RepublicTheme.brass)
            }
            if let receipt = placementReceipt, tool == .inspect { placementConfirmation(receipt) }
            if let receipt = roadReceipt { roadConfirmation(receipt) }
            if let unlocked = unlockedBanner {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Unlocked: \(unlocked.title)").font(.caption.weight(.bold))
                        Text(unlocked.reward).font(.caption2)
                    }
                    Spacer(minLength: 0)
                    Button { showRoadmap = true } label: {
                        Text("View").font(.caption.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain)
                    Button { unlockedBanner = nil } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Dismiss unlock announcement")
                }
                .padding(8)
                .background(RepublicTheme.brass.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .foregroundStyle(RepublicTheme.paper)
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RepublicTheme.panel.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(RepublicTheme.brass.opacity(0.22)))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }

    private func overlayTileDescription(_ tile: TileIndex) -> String {
        guard mapOverlay != .standard else { return "" }
        guard let score = MapOverlaySnapshot(mode: mapOverlay, state: game.state).value(at: tile) else {
            return " · \(mapOverlay.title): no data"
        }
        switch mapOverlay {
        case .standard: return ""
        case .fertility: return score == 100 ? " · Fertile soil" : " · Not fertile"
        case .foodAccess:
            return score == 100 ? " · Stocked market in reach" : (score > 0 ? " · Market in reach, empty" : " · No market access")
        case .happiness: return " · District happiness \(score)/100"
        case .employment: return " · District employment \(score)%"
        }
    }

    private var roadmapLine: String {
        guard DevelopmentTree.isEnabled(in: game.state) else { return SeasonCopy.mapLine(game.state) }
        if let goal = DevelopmentTree.nextGoal(in: game.state) { return "Next unlock: \(goal.id.title)" }
        return "Roadmap complete · Your republic is growing"
    }

    private func roadConfirmation(_ receipt: RoadReceipt) -> some View {
        HStack(spacing: 8) {
            Image(systemName: receipt.complete ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(RepublicTheme.brass)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(receipt.count) road tiles paved\(receipt.complete ? "" : " · stopped early")")
                    .font(.caption.weight(.bold))
                Text("−$\(receipt.cost) · \(game.saveIssue == nil ? "Your island is saved." : "Not saved — see storage warning")")
                    .font(.caption2)
            }
            Spacer(minLength: 0)
            Button {
                scene.focus(on: receipt.anchor)
            } label: {
                Image(systemName: "scope").frame(width: 44, height: 44)
            }.buttonStyle(.plain).accessibilityLabel("View paved road")
            Button { roadReceipt = nil } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }.buttonStyle(.plain).accessibilityLabel("Dismiss road confirmation")
        }
        .padding(8)
        .background(RepublicTheme.brass.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func placementConfirmation(_ receipt: PlacementReceipt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: game.saveIssue == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(RepublicTheme.brass)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(receipt.name) \(receipt.buildDays > 0 ? "construction started" : "placed")")
                        .font(.caption.weight(.bold))
                    Text("−$\(receipt.cost) · \(receipt.opensOnDay > game.state.day ? "Opens day \(receipt.opensOnDay)" : "Now open")")
                        .font(.caption2)
                    Text(game.saveIssue == nil ? "Your island is saved." : "Placed, but could not save. See the storage warning.")
                        .font(.caption2).foregroundStyle(RepublicTheme.paper.opacity(0.8))
                }
                Spacer(minLength: 0)
                Button { placementReceipt = nil } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).accessibilityLabel("Dismiss placement confirmation")
            }
            Button {
                tool = .inspect
                selectedTile = nil
                selectedBuildingID = receipt.id
                scene.setSelection(receipt.id)
                scene.focus(on: receipt.anchor)
            } label: {
                Label("Check the building", systemImage: "scope")
                    .font(.caption.weight(.semibold)).frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(RepublicTheme.brass.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }

    private var foundingTourOverlay: some View {
        FoundingTourOverlay(beat: tour.beat, population: Int(game.snapshot.population),
            nextGoal: focusGoals.first?.title ?? "Build a working settlement",
            onSkip: finishTour, onContinue: advanceTour)
    }

    private func startTutorial() {
        guard islandVisible, !tour.active, !game.state.blocksAdvance, game.saveIssue == nil else { return }
        guidedSeed = String(game.state.worldSeed)
        showFieldGuide = true
        showJournal = false
    }

    private var openingJourney: OpeningJourney { OpeningJourney(state: game.state, record: journeyRecord) }

    private var tutorialReadyForPolitics: Bool { openingJourney.complete }

    private var islandPrompt: IslandPrompt { IslandPrompt.make(in: game.state) }

    private var tutorialCoach: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(openingJourney.chapter).font(.caption2.weight(.semibold))
                Spacer(minLength: 4)
                Text("\(openingJourney.finishedCount) / 4").font(.caption2.monospacedDigit())
            }.foregroundStyle(RepublicTheme.paper.opacity(0.8))
            ProgressView(value: Double(openingJourney.finishedCount), total: 4)
                .tint(RepublicTheme.brass).accessibilityLabel("Founding milestones")
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tutorialReadyForPolitics ? "Your town is growing" : islandPrompt.title)
                        .font(.caption.weight(.bold)).foregroundStyle(RepublicTheme.brass)
                    Text(tool.isBuilding ? "Find a spot beside the road. When the preview turns green, tap Build here."
                         : tool == .road ? "Draw a route, then tap Lay road. Two fingers move the map."
                         : tutorialReadyForPolitics ? "Meet the people behind your republic. Their worries will shape your next choices."
                         : openingJourney.instruction(fallback: islandPrompt.message, goal: focusGoals.first?.id ?? ""))
                        .font(.caption).foregroundStyle(RepublicTheme.paper).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button { guidedSeed = "" } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).accessibilityLabel("Hide advice; return from the island menu")
            }
            if tool == .inspect {
                HStack(spacing: 12) {
                    Button(tutorialReadyForPolitics ? "Meet your people" : islandPrompt.button) {
                        if tutorialReadyForPolitics { guidedSeed = ""; onGovern() }
                        else { performFocus(islandPrompt.action) }
                    }
                    .font(.caption.weight(.semibold)).frame(minHeight: 44)
                    .buttonStyle(.borderedProminent).tint(RepublicTheme.terracotta)
                    .disabled(game.state.blocksAdvance || game.saveIssue != nil)
                    if clock.policy.pace == .paused {
                        Button("Resume days") { clock.togglePause() }
                            .font(.caption.weight(.semibold)).frame(minHeight: 44).buttonStyle(.plain)
                    } else {
                        Button("Tell me more") { showJournal = true }.font(.caption).frame(minHeight: 44).buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var developmentHint: String {
        islandPrompt.title
    }

    private func observeIsland(_ state: RepublicState) {
        focusGoals = CityFocusReader.goals(in: state)
        guideLessons = SettlementGuide.lessons(in: state)
        let journey = OpeningJourney(state: state, record: journeyRecord)
        if journey.record != journeyRecord { journeyRecord = journey.record }
        let snapshot = CityDaySnapshot(state: state)
        guard let previous = dayBaseline, previous.seed == snapshot.seed else {
            dayBaseline = snapshot
            dayResults = []; islandMoment = nil
            queuedBuilding = nil; queuedBuildingSeed = nil
            return
        }
        if let result = CityDayResult.compare(previous, snapshot) {
            if result.populationDelta > 0 {
                islandMoment = "\(result.populationDelta) new neighbours! Your little town is growing."
            } else if result.newlyOpened > 0 {
                let opened = state.buildings.first { snapshot.standing.contains($0.id) && !previous.standing.contains($0.id) }
                islandMoment = opened.map { "Your \(($0.kind == .police ? "police station" : String(describing: $0.kind).lowercased())) is open. A new part of town is ready." }
            } else if result.employmentDelta > 0 {
                islandMoment = "\(result.employmentDelta) more neighbours are working today."
            } else if result.fewerHungry > 0 {
                islandMoment = result.hungry == 0 ? "Everyone is fed again. That’s a good day for the island." : "Fewer neighbours are going hungry. Keep it up."
            }
            if result.populationDelta > 0 || result.newlyOpened > 0 || result.employmentDelta > 0 || result.fewerHungry > 0 { momentUntilDay = state.day + 1 }
            dayResults.insert(result, at: 0)
            dayResults = Array(dayResults.prefix(6))
            dayBaseline = snapshot
        }
    }

    private func finishJournal() {
        let action = queuedFocus
        let replay = queuedTour
        let government = queuedGovernment
        queuedFocus = nil
        queuedTour = false
        queuedGovernment = false
        guard islandVisible else { return }
        if replay { startTour(); return }
        if government {
            if tutorialReadyForPolitics { guidedSeed = "" }
            onGovern()
            return
        }
        guard let action else { return }
        performFocus(action)
    }

    private func finishCatalog() {
        let kind = queuedBuilding
        let seed = queuedBuildingSeed
        queuedBuilding = nil; queuedBuildingSeed = nil
        guard islandVisible, appPhase == .active, seed == game.state.worldSeed, let kind else { return }
        performFocus(.build(kind))
    }

    private func performFocus(_ action: CityFocusAction) {
        if game.state.blocksAdvance { presentAttention(); return }
        switch action {
        case .build(let kind):
            guard game.saveIssue == nil, DevelopmentTree.canBuild(kind, in: game.state),
                  let option = CityTool.allCases.first(where: { $0.buildingKind == kind }) else { return }
            leaveBuildSession()
            tool = option
            showCatalog = false
            placeTile = IslandPrompt.suggestedSite(for: kind, in: game.state)
            if let placeTile { scene.focus(on: placeTile) }
            configureTapHandler()
        case .inspect(let id): inspectCitizenBuilding(id)
        case .overlay(let mode): tool = .inspect; mapOverlay = mode
        case .growth: showGrowth = true
        case .roadmap: showRoadmap = true
        }
    }

    private func considerOpeningTour() {
        guard FoundingTourPolicy.shouldAutostart(day: game.state.day, seed: game.state.worldSeed,
            seenSeed: touredSeed, enabled: automaticTours && game.state.development != nil,
            blocked: !sceneReady || game.state.blocksAdvance || game.saveIssue != nil || !islandVisible || appPhase != .active || UIApplication.shared.applicationState != .active || UIAccessibility.isVoiceOverRunning)
        else { return }
        startTour()
    }

    private func startTour() {
        guard sceneReady, islandVisible, appPhase == .active, UIApplication.shared.applicationState == .active, tool == .inspect, !game.state.blocksAdvance, game.saveIssue == nil else { return }
        guard withAnimation((reduceMotion || UIAccessibility.isReduceMotionEnabled) ? nil : .easeInOut(duration: 0.2), { tour.begin() }) else { return }
        touredSeed = String(game.state.worldSeed)
        selectedCitizenID = nil
        selectedBuildingID = nil
        selectedTile = nil
        showCatalog = false
        tourRun = UUID()
        clock.setModal("founding-tour", presented: true)
    }

    private func advanceTour() {
        guard tour.active else { return }
        if tour.beat == FoundingTourPolicy.beatCount - 1 {
            finishTour()
            startTutorial()
            return
        }
        if tour.advance() { scene.presentTourBeat(tour.beat, reduceMotion: reduceMotion || UIAccessibility.isVoiceOverRunning) }
        else { finishTour() }
    }

    private func finishTour() {
        withAnimation((reduceMotion || UIAccessibility.isReduceMotionEnabled) ? nil : .easeInOut(duration: 0.2)) { tour.finish() }
        scene.endTourCamera()
        clock.setModal("founding-tour", presented: false)
    }

    private var growthDetails: some View {
        let outlook = SettlementOutlook(state: game.state)
        return VStack(alignment: .leading, spacing: 16) {
            Text(outlook.enabled ? "What newcomers need" : "City capacity")
                .font(RepublicTheme.heading(.title2))
            Text("\(outlook.freeBeds) spare beds · \(outlook.openJobs) open jobs")
            Text("Happiness \(outlook.happiness)% · \(outlook.hungryResidents) hungry residents")
            if outlook.enabled {
                Text("Current capacity supports \(outlook.expectedArrivals) of \(game.state.config.settlementGrowth?.arrivalsPerWave ?? 0) newcomers after existing residents take available homes and jobs. This uses today's completed buildings and stock; conditions can change before the check.")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                if outlook.ready {
                    Label("Ready for the next arrival check", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(RepublicTheme.fertile)
                }
                ForEach(outlook.blockers, id: \.self) { blocker in
                    Label(blocker, systemImage: "exclamationmark.circle")
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let day = outlook.nextArrivalDay {
                    Text("Next scheduled check: Day \(day). Conditions must still hold then. This checks capacity for the first newcomer; a second arrival needs another bed, job and additional food.")
                        .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
                }
            } else {
                Text("This established city's saved rules do not enable newcomer waves.")
            }
            Text("Residents take available jobs automatically. A spare home must connect to a workplace and a sufficiently stocked market. Happiness shows the current average; it does not identify an individual cause.")
                .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
        }
        .foregroundStyle(RepublicTheme.ink)
        .padding().dioramaCard()
    }

    private var dayPopulation: some View {
        HStack(spacing: 8) {
            Text("DAY \(game.snapshot.day)")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(RepublicTheme.brass)
            Label("\(game.snapshot.population)", systemImage: "person.2.fill")
                .font(.caption.weight(.medium))
                .accessibilityLabel("\(game.snapshot.population) residents")
        }
        .fixedSize()
    }

    private var resourceStrip: some View {
        HStack(spacing: 14) {
            resource("Treasury", "$\(game.snapshot.treasury)", icon: "banknote")
            resource("Food stored", "\(game.snapshot.foodInStores)", icon: "leaf.fill")
            resource("Happiness", "\(game.snapshot.meanHappiness)%", icon: "face.smiling")
        }
    }

    private func resource(_ title: String, _ value: String, icon: String) -> some View {
        Label(value, systemImage: icon)
            .font(.caption.weight(.semibold)).monospacedDigit()
            .lineLimit(1).fixedSize()
            .accessibilityLabel("\(title): \(value)")
    }

    private var selectedAgenda: AgendaItem? {
        guard let selectedAgendaID else { return nil }
        return game.state.agenda.first(where: { $0.id == selectedAgendaID })
    }

    private var previewAgenda: [AgendaItem] {
        game.state.agenda.sorted { lhs, rhs in
            previewRank(lhs) < previewRank(rhs)
        }
    }

    /// A choice that blocks the day outranks an island event. On a one-card
    /// phone sheet the first rank is the only button, so the election stays reachable.
    private func previewRank(_ item: AgendaItem) -> Int {
        AgendaSheetOrder.rank(tier: item.tier, isIslandEvent: item.islandEventID != nil,
                              isDecree: item.kind == .decree, isOriginDilemma: item.originDilemma == true)
    }

    @ViewBuilder private func agendaPreviews(layout: CityDisplayLayout) -> some View {
        let items = Array(previewAgenda.prefix(layout.visibleCards))
        if layout.stackedPreviews {
            VStack(spacing: 5) {
                ForEach(items) { item in
                    previewButton(item)
                }
            }
        } else {
            HStack(spacing: 5) {
                ForEach(items) { item in
                    previewButton(item)
                }
            }
        }
    }

    private func previewButton(_ item: AgendaItem) -> some View {
        Button {
            selectedAgendaID = item.id
            if item.islandEventID != nil { dismissedIslandEvent = nil }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: item.islandEventID == nil ? "text.bubble.fill" : "newspaper.fill")
                Text(previewTitle(item)).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption2)
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(previewTint(item))
        .accessibilityHint(item.tier == .crisis ? "This choice blocks the next day" : "Opens this choice")
    }

    private func previewTitle(_ item: AgendaItem) -> String {
        if item.tier == .crisis { return "\(item.kind.cityTitle) · day is waiting" }
        if item.originDilemma == true { return item.causes.first?.detail ?? "Opening" }
        return item.islandEvent?.title ?? item.kind.cityTitle
    }

    private func previewTint(_ item: AgendaItem) -> Color {
        if item.tier == .crisis { return Color(red: 0.78, green: 0.22, blue: 0.12) }
        switch item.islandEvent?.tone {
        case .good: return Color(red: 0.24, green: 0.55, blue: 0.28)
        case .bad: return Color(red: 0.72, green: 0.28, blue: 0.16)
        case .weird: return Color(red: 0.05, green: 0.45, blue: 0.62)
        case nil: return .indigo
        }
    }

    private func crisisCard(_ pending: PendingDecision, layout: CityDisplayLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("City crisis", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(pending.kind.cityTitle).font(.subheadline.weight(.semibold))
            if let line = pending.causes.compactMap(CauseSpeech.line).first {
                Text("Because \(line)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("The next day waits for your choice.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    ForEach(pending.options) { option in
                        Button {
                            game.send(.resolveDecision(pending.id, option: option.id))
                        } label: {
                            Text(option.label).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(maxHeight: layout.optionListHeight)
        }
        .frame(maxWidth: layout.cardWidth, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private func agendaCard(_ item: AgendaItem, layout: CityDisplayLayout) -> some View {
        AgendaChoiceCard(
            item: item,
            treasury: game.state.treasury,
            day: game.state.day,
            saveBlocked: game.saveIssue != nil,
            onResolve: { option in
                game.send(.resolveAgendaItem(item.id, option: option))
                selectedAgendaID = nil
            },
            onClose: {
                if item.tier == .crisis { dismissedBlocking = item.id }
                if item.islandEventID != nil { dismissedIslandEvent = item.id }
                selectedAgendaID = nil
            }
        )
        .frame(maxWidth: layout.cardWidth, alignment: .leading)
    }

    private var seasonSignature: String {
        let season = game.state.republicSeason
        return "\(season?.foundingClaimed == true)|\(season?.path?.rawValue ?? "")|\(season?.settledClaimed == true)"
    }

    private var blockingItem: AgendaItem? {
        game.state.agenda.first { $0.tier == .crisis }
    }

    private var blockingAgendaID: DecisionID? { blockingItem?.id }

    private var liveIslandEventID: DecisionID? {
        game.state.agenda.first { $0.islandEventID != nil }?.id
    }

    /// Pending id, blocking agenda id, and island-event id. A new election changes
    /// this even when the island card does not.
    private var attentionCue: String {
        let pending = game.state.pending?.id.raw ?? -1
        let blocking = blockingAgendaID?.raw ?? -1
        let island = liveIslandEventID?.raw ?? -1
        return "\(pending)|\(blocking)|\(island)"
    }

    /// A pending crisis or an election opens its card. An island event stays a
    /// button so it does not cover the map or steal the build tools.
    private func presentAttention() {
        if game.state.pending != nil {
            selectedAgendaID = nil
            return
        }
        if let blocking = blockingAgendaID {
            if dismissedBlocking != blocking && selectedAgendaID != blocking {
                selectedAgendaID = blocking
            }
            return
        }
    }

    private var dayClockControls: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("Paused") { clock.setPace(.paused) }
                Button("Slow · 6 seconds per day") { clock.setPace(.playing(DayClockPolicy.leisurely)) }
                Button("Normal · 3.5 seconds per day") { clock.setPace(.playing(DayClockPolicy.steady)) }
                Button("Fast · 2 seconds per day") { clock.setPace(.playing(DayClockPolicy.brisk)) }
            } label: {
                Label(clockButtonTitle, systemImage: clock.policy.tickInterval == nil ? "pause.fill" : "play.fill")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.bordered)
            Text(clock.policy.explanation)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private func toolStrip(compact: Bool, narrow: Bool) -> some View {
        HStack(spacing: 8) {
            toolButton(.inspect)
            Button {
                leaveBuildSession(); queuedBuilding = nil; showCatalog = true
            } label: {
                Label("Build", systemImage: "hammer.fill").frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.borderedProminent).tint(RepublicTheme.panel)
            toolButton(.road)
        }.padding(6)
    }

    private func narrowToolButton(_ option: CityTool) -> some View {
        Button {
            tool = option
            configureTapHandler()
        } label: {
            Image(systemName: option.symbol)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(tool == option ? RepublicTheme.brass : RepublicTheme.panel)
        .accessibilityLabel("\(option.label) tool")
    }

    private func toolButton(_ option: CityTool) -> some View {
        Button {
            tool = option
            configureTapHandler()
        } label: {
            Label(option.label, systemImage: option.symbol)
                .font(.caption.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(tool == option ? RepublicTheme.brass : RepublicTheme.panel)
        .accessibilityLabel("\(option.label) tool")
    }

    private func terrainLabel(at tile: TileIndex) -> String {
        let map = game.state.map
        guard Int(tile.raw) >= 0 && Int(tile.raw) < map.tileCount else { return "Outside island" }
        if map.isRoad(at: tile) { return "Road" }
        if let id = map.building(at: tile), Int(id.raw) < game.state.buildings.count {
            return String(describing: game.state.buildings[Int(id.raw)].kind).capitalized
        }
        return String(describing: map.terrain(at: tile)).capitalized
    }

    private var selectedCitizen: Citizen? {
        guard let id = selectedCitizenID, id.raw >= 0, Int(id.raw) < game.state.citizens.count else { return nil }
        let citizen = game.state.citizens[Int(id.raw)]
        return citizen.alive && citizen.id == id ? citizen : nil
    }

    private func citizenCard(_ citizen: Citizen) -> some View {
        let routine = WalkerRoutine.plan(for: citizen, in: game.state, access: game.state.buildingAccess())
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(citizen.name).font(.headline)
                    Text("Age \(citizen.age) · \(String(describing: citizen.occupation).capitalized)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button { selectedCitizenID = nil } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }.accessibilityLabel("Close resident inspection")
            }
            if let notice = CitizenNeeds.attention(for: citizen.id, in: game.state) {
                Label(notice.title, systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(RepublicTheme.brass)
                Text(notice.help).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            Text(citizenActivity.isEmpty ? "Daily routine" : citizenActivity)
                .font(.subheadline.weight(.semibold)).foregroundStyle(RepublicTheme.brass)
            Text("Happiness \(citizen.happiness)% · $\(citizen.money) · \(citizen.daysHungry == 0 ? "Fed" : "Hungry for \(citizen.daysHungry) days")")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            Text("Gold line: today's planned trips. Residents find jobs automatically.")
                .font(.caption2).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    citizenBuildingLink(citizen.home, fallback: "No home")
                    citizenBuildingLink(citizen.work, fallback: "Seeking work")
                }
                VStack(spacing: 8) {
                    citizenBuildingLink(citizen.home, fallback: "No home")
                    citizenBuildingLink(citizen.work, fallback: "Seeking work")
                }
            }
            DisclosureGroup("Daily stops") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(routine.stops.indices, id: \.self) { index in
                        Text("\(routine.dwellStart[index]):00–\(routine.dwellEnd[index]):00 · \(routine.stops[index].rawValue.capitalized)")
                            .font(.caption)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func citizenBuildingLink(_ id: BuildingID?, fallback: String) -> some View {
        let name: String
        if let id, id.raw >= 0, Int(id.raw) < game.state.buildings.count {
            let kind = game.state.buildings[Int(id.raw)].kind
            let title = kind == .townHall ? "Town hall" : String(describing: kind).capitalized
            name = "\(title) #\(id.raw + 1)"
        } else { name = fallback }
        return Button(name) { inspectCitizenBuilding(id) }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered).disabled(id == nil)
    }

    private func inspectCitizenBuilding(_ id: BuildingID?) {
        guard let id, id.raw >= 0, Int(id.raw) < game.state.buildings.count else { return }
        let building = game.state.buildings[Int(id.raw)]
        guard building.occupiesGround(on: game.state.map) else { return }
        selectedCitizenID = nil
        selectedBuildingID = id
        scene.focus(on: building.entrance)
    }

    private var selectedBuilding: Building? {
        guard let selectedBuildingID else { return nil }
        guard selectedBuildingID.raw >= 0, Int(selectedBuildingID.raw) < game.state.buildings.count else { return nil }
        let building = game.state.buildings[Int(selectedBuildingID.raw)]
        return building.id == selectedBuildingID ? building : nil
    }

    private var buildingInspection: BuildingInspection? {
        guard tool == .inspect, let selectedBuildingID else { return nil }
        return BuildingInspector.make(id: selectedBuildingID, in: game.state)
    }

    private func configureTapHandler() {
        let activeTool = tool
        scene.onPlacementHint = { hint in
            Task { @MainActor in
                if placementHint != hint { placementHint = hint }
            }
        }
        scene.roadDrawing = activeTool == .road
        scene.setPlacementKind(activeTool.buildingKind, fallbackHover: placeTile)
        scene.onHoverTile = { tile in
            Task { @MainActor in
                guard !tour.active, tool == activeTool, islandVisible else { return }
                if activeTool.isBuilding { placeTile = tile }
            }
        }
        scene.onRoadTile = { tile in
            Task { @MainActor in
                guard !tour.active, tool == .road, activeTool == .road, islandVisible,
                      roadDraft.last != tile, roadDraft.count < 24 else { return }
                roadDraft.append(tile)
                scene.setRoadPreview(roadMarks)
            }
        }
        scene.onCitizenTap = { id in
            Task { @MainActor in
                guard !tour.active, activeTool == .inspect, tool == .inspect, islandVisible else { return }
                showCatalog = false
                selectedBuildingID = nil
                selectedTile = nil
                selectedCitizenID = id
            }
        }
        scene.onCitizenActivity = { id, activity in
            Task { @MainActor in
                guard selectedCitizenID == id, citizenActivity != activity else { return }
                citizenActivity = activity
            }
        }
        scene.onTileTap = { tile in
            Task { @MainActor in
                guard !tour.active, tool == activeTool, islandVisible else { return }
                if activeTool == .inspect {
                    selectedCitizenID = nil
                    if let building = BuildingHitTest.building(on: tile, in: game.state) {
                        selectedBuildingID = building.id
                        selectedTile = nil
                    } else {
                        selectedBuildingID = nil
                        scene.setSelection(nil)
                        selectedTile = tile
                    }
                } else if activeTool.isBuilding {
                    placeTile = tile
                }
            }
        }
    }

    /// Drops the build and catalog clock holds. A demolish confirm and Start New City
    /// keep their own tokens. The scene object, and therefore the camera, stays.
    private func leaveBuildSession() {
        showRoadmap = false
        clock.setModal("roadmap", presented: false)
        var hold = IslandSessionHold(
            toolIsInspect: tool == .inspect,
            catalogOpen: showCatalog,
            roadDraftCount: roadDraft.count,
            hasPlacement: placeTile != nil,
            modalTokens: [IslandSessionHold.buildToken, IslandSessionHold.catalogToken])
        hold.leaveIsland()
        showCatalog = hold.catalogOpen
        roadDraft = []
        placeTile = nil
        scene.setRoadPreview([])
        scene.hidePlacementGhost()
        if tool != .inspect {
            tool = .inspect
        } else {
            scene.roadDrawing = false
            scene.setPlacementKind(nil, fallbackHover: nil)
        }
    }

    private var cardOpen: Bool {
        selectedAgenda != nil || game.state.pending != nil || buildingInspection != nil || selectedCitizen != nil || tool.isBuilding
    }

    private var detailOpen: Bool {
        cardOpen || attentionChip != nil || tool != .inspect
    }

    private var hungryResidents: Int32 {
        game.state.districts.reduce(0) { $0 + $1.hungryCount }
    }

    private var attentionChip: AgendaItem? {
        if game.state.pending != nil || selectedAgenda != nil { return nil }
        if let blocking = blockingItem { return blocking }
        if let origin = game.state.agenda.first(where: { $0.originDilemma == true }) { return origin }
        if let id = liveIslandEventID {
            return game.state.agenda.first { $0.id == id }
        }
        return nil
    }

    private var roadMarks: [(tile: TileIndex, accepted: Bool)] {
        var spent = 0
        return roadDraft.map { tile in
            let map = game.state.map
            if Int(tile.raw) < 0 || Int(tile.raw) >= map.tileCount { return (tile, false) }
            if map.isRoad(at: tile) { return (tile, true) }
            let open = map.terrain(at: tile).buildable && map.building(at: tile) == nil && game.state.pending == nil
            let affordable = game.state.treasury >= Int64(spent + 10)
            if open && affordable {
                spent += 10
                return (tile, true)
            }
            return (tile, false)
        }
    }

    private var placeBar: some View {
        let kind = tool.buildingKind
        let verdict: String
        let canPlace: Bool
        if let kind, let placeTile {
            switch SimulationEngine.validatePlacement(kind, at: placeTile, in: game.state) {
            case .valid:
                canPlace = true
                let days = game.state.config.constructionDays(for: kind)
                verdict = "Ready to build · entrance beside a road. " + (days > 0 ? "Opens in \(days) day\(days == 1 ? "" : "s")." : "Opens today.")
            case .rejected(let reason):
                canPlace = false
                verdict = DevelopmentTree.lockReason(for: kind, in: game.state) ?? reason.playerFacingReason
            }
        } else {
            canPlace = false
            verdict = "Drag the preview to a spot beside the road. Use two fingers to move the map."
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(tool.label) · $\(kind?.buildCost ?? 0)")
                .font(.caption.weight(.semibold))
            Label(verdict, systemImage: canPlace ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(canPlace ? RepublicTheme.fertile : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            if kind == .farm && mapOverlay != .fertility {
                Button("Show fertility layer") { mapOverlay = .fertility }
                    .font(.caption.weight(.semibold)).frame(minHeight: 44)
            }
            if let kind {
                Text(game.state.treasury >= kind.buildCost ? "You’ll have $\(game.state.treasury - kind.buildCost) left." : "You need $\(kind.buildCost - game.state.treasury) more.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            DisclosureGroup("Adjust by one square", isExpanded: $showBuildHelp) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    nudgeButton("west", symbol: "arrow.up.left", dx: -1, dy: 0)
                    nudgeButton("north", symbol: "arrow.up.right", dx: 0, dy: -1)
                    nudgeButton("south", symbol: "arrow.down.left", dx: 0, dy: 1)
                    nudgeButton("east", symbol: "arrow.down.right", dx: 1, dy: 0)
                }
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        nudgeButton("west", symbol: "arrow.up.left", dx: -1, dy: 0)
                        nudgeButton("north", symbol: "arrow.up.right", dx: 0, dy: -1)
                    }
                    HStack(spacing: 8) {
                        nudgeButton("south", symbol: "arrow.down.left", dx: 0, dy: 1)
                        nudgeButton("east", symbol: "arrow.down.right", dx: 1, dy: 0)
                    }
                }
            }
            }
            Text("Nothing is bought until you tap Build here.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var placementActions: some View {
        let kind = tool.buildingKind
        let canPlace = canConfirmPlacement
        return HStack {
                Button("Build here · $\(kind?.buildCost ?? 0)") {
                    guard let kind, let placeTile else { return }
                    guard game.send(.placeBuilding(kind, at: placeTile)),
                          let id = game.state.map.buildingAt(placeTile) else {
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        return
                    }
                    let building = game.state.buildings[Int(id.raw)]
                    roadReceipt = nil
                    placementReceipt = PlacementReceipt(id: id, anchor: building.anchor,
                        name: String(describing: kind).capitalized, cost: kind.buildCost,
                        buildDays: building.daysRequired, opensOnDay: building.opensOnDay)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    scene.hidePlacementGhost()
                    self.placeTile = nil
                    tool = .inspect
                    selectedTile = nil
                    // Keep the site highlighted without opening a tall inspect
                    // panel over the result. View site opens that panel explicitly.
                    selectedBuildingID = nil
                    scene.setSelection(id)
                    scene.focus(on: building.entrance)
                    UIAccessibility.post(notification: .announcement,
                        argument: "\(String(describing: kind).capitalized) construction started. Cost \(kind.buildCost).")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canPlace || game.saveIssue != nil)
                Button("Cancel") {
                    placeTile = nil
                    tool = .inspect
                    scene.hidePlacementGhost()
                }
                .buttonStyle(.bordered)
            }
            .frame(minHeight: 44)
    }

    private var canConfirmPlacement: Bool {
        guard let kind = tool.buildingKind, let placeTile, game.saveIssue == nil else { return false }
        if case .valid = SimulationEngine.validatePlacement(kind, at: placeTile, in: game.state) { return true }
        return false
    }

    private func nudgePlacement(dx: Int32, dy: Int32) {
        guard let tile = placeTile else { return }
        let map = game.state.map
        let x = map.x(of: tile) + dx, y = map.y(of: tile) + dy
        guard x >= 0, x < map.width, y >= 0, y < map.height else { return }
        let next = map.index(x: x, y: y)
        placeTile = next
        scene.movePlacement(to: next)
    }

    private func nudgeButton(_ label: String, symbol: String, dx: Int32, dy: Int32) -> some View {
        Button { nudgePlacement(dx: dx, dy: dy) } label: {
            Image(systemName: symbol).frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(placeTile == nil)
        .accessibilityLabel("Move preview one tile \(label)")
    }

    private var roadBar: some View {
        let fresh = roadMarks.filter { $0.accepted && !game.state.map.isRoad(at: $0.tile) }.count
        let blocked = roadMarks.contains { !$0.accepted }
        return VStack(alignment: .leading, spacing: 6) {
            Text(fresh > 0 ? "Lay \(fresh) road squares · $\(fresh * 10)" : "Draw the road with one finger. Use two fingers to move the map.")
                .font(.caption.weight(.semibold))
            if blocked {
                Text("A red square is blocked or too expensive. The road will stop before it.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            HStack {
                Button("Lay road") { paveDraft() }
                    .buttonStyle(.borderedProminent)
                    .disabled(fresh == 0 || game.saveIssue != nil)
                Button("Cancel") {
                    roadDraft = []
                    scene.setRoadPreview([])
                    tool = .inspect
                }
                .buttonStyle(.bordered)
            }
            .frame(minHeight: 44)
        }
    }

    private var catalog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What does your island need?").font(RepublicTheme.heading(.title2))
            Text("Choose a building, then find its place on the island. Time waits while you choose.")
                .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
            ForEach(CityTool.buildings.filter { option in
                option.buildingKind.map { DevelopmentTree.canBuild($0, in: game.state) } ?? false
            }) { option in buildCard(option, available: true) }
            DisclosureGroup("Coming later") {
                VStack(spacing: 10) {
                    ForEach(CityTool.buildings.filter { option in
                        option.buildingKind.map { !DevelopmentTree.canBuild($0, in: game.state) } ?? false
                    }) { option in buildCard(option, available: false) }
                }.padding(.top, 10)
            }.font(.subheadline)
        }.foregroundStyle(RepublicTheme.ink)
    }

    private func buildCard(_ option: CityTool, available: Bool) -> some View {
        Button {
            guard let kind = option.buildingKind, available else { return }
            queuedBuilding = kind
            queuedBuildingSeed = game.state.worldSeed
            showCatalog = false
        } label: {
            HStack(spacing: 14) {
                if let kind = option.buildingKind {
                    Image(BuildingSpriteCatalog.spec(for: kind).imageName)
                        .resizable().scaledToFit().frame(width: 66, height: 76).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(option.label).font(.headline)
                        Text(IslandPrompt.purpose(kind)).font(.subheadline)
                        if available {
                            let days = game.state.config.constructionDays(for: kind)
                            Text(days == 0 ? "$\(kind.buildCost) · Opens right away" : "$\(kind.buildCost) · Ready in \(days) days")
                                .font(.caption.weight(.semibold)).foregroundStyle(RepublicTheme.inkSoft)
                            if game.state.treasury < kind.buildCost {
                                Text("You need $\(kind.buildCost - game.state.treasury) more.").font(.caption).foregroundStyle(RepublicTheme.terracotta)
                            }
                            if case .build(let needed) = islandPrompt.action, needed == kind {
                                Label("Your neighbours could use this", systemImage: "star.fill")
                                    .font(.caption2.weight(.semibold)).foregroundStyle(RepublicTheme.fertile)
                            }
                        } else {
                            Text(DevelopmentTree.lockReason(for: kind, in: game.state) ?? "Keep growing your town.")
                                .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
                        }
                    }.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: available ? "chevron.right" : "lock.fill").font(.caption)
                }
            }.padding(12).frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(RepublicTheme.sand.opacity(available ? 0.24 : 0.12), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).disabled(!available || game.saveIssue != nil)
    }

    private func paveDraft() {
        var rest = roadDraft
        var placed = 0
        var first: TileIndex?
        roadReceipt = nil
        while let tile = rest.first {
            let inBounds = tile.raw >= 0 && Int(tile.raw) < game.state.map.tileCount
            let fresh = inBounds && !game.state.map.isRoad(at: tile)
            guard game.send(.buildRoad(at: tile)) else {
                if let first, placed > 0 {
                    placementReceipt = nil
                    roadReceipt = RoadReceipt(count: placed, cost: placed * 10, anchor: first, complete: false)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                roadDraft = rest
                scene.setRoadPreview(roadMarks)
                return
            }
            if fresh {
                placed += 1
                if first == nil { first = tile }
            }
            rest.removeFirst()
        }
        if let first, placed > 0 {
            placementReceipt = nil
            roadReceipt = RoadReceipt(count: placed, cost: placed * 10, anchor: first, complete: true)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: "\(placed) road tiles paved. Cost \(placed * 10).")
        }
        roadDraft = []
        scene.setRoadPreview([])
        tool = .inspect
    }
}

/// A single display keeps the map full width with a draggable bottom panel.
/// A spanned inner display puts the world and the controls on separate panes.
/// Tent view is chosen on the outer landscape display, which has no separate scene signal.
private struct IslandHUDHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct IslandDockHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: - Pure map viewport bounds
struct IslandMapBounds {
    let focus: CGRect
    let controls: CGRect

    init(size: CGSize, desiredPanelHeight: CGFloat, hudHeight: CGFloat, dockHeight: CGFloat) {
        let width = max(0, size.width)
        let height = max(0, size.height)
        let panelHeight = min(height, max(desiredPanelHeight, dockHeight + 8))
        let mapHeight = max(0, height - panelHeight)
        let top = min(max(0, hudHeight + 16), max(0, mapHeight - 80))
        focus = CGRect(x: 0, y: top, width: width, height: mapHeight - top)
        controls = CGRect(x: 0, y: mapHeight, width: width, height: panelHeight)
    }
}

private struct CityDisplayLayout {
    enum Mode { case singlePortrait, singleLandscape, tent, spannedFlat, bookFold, laptopFold }
    let mode: Mode
    let size: CGSize
    let focus: CGRect
    let controls: CGRect
    let occlusionTopInset: CGFloat

    let detailOpen: Bool
    let cardOpen: Bool

    init(geometry: GeometryProxy, verticalSizeClass: UserInterfaceSizeClass?,
         layoutDirection: LayoutDirection, tentMode: Bool,
         sheetExpanded: Bool, tentControlsOpen: Bool, detailOpen: Bool, cardOpen: Bool,
         hudHeight: CGFloat, dockHeight: CGFloat) {
        self.detailOpen = detailOpen
        self.cardOpen = cardOpen
        let size = geometry.size
        self.size = size
        let bounds = CGRect(origin: .zero, size: size)
        var division: CGRect?
        if #available(iOS 27.1, *) {
            division = geometry.reservedRegions(kind: .division)
                .map(\.frame)
                .filter { $0.intersects(bounds) }
                .max(by: { $0.width * $0.height < $1.width * $1.height })
        }
        if let seam = division?.intersection(bounds), !seam.isNull,
           seam.width > 0, seam.height > 0 {
            if seam.height >= seam.width {
                let left = CGRect(x: 0, y: 0, width: max(0, seam.minX), height: size.height)
                let right = CGRect(x: seam.maxX, y: 0,
                                   width: max(0, size.width - seam.maxX), height: size.height)
                mode = .bookFold
                if layoutDirection == .rightToLeft {
                    controls = left.width >= 180 ? left : right
                    focus = left.width >= 180 ? right : left
                } else {
                    controls = right.width >= 180 ? right : left
                    focus = right.width >= 180 ? left : right
                }
            } else {
                mode = .laptopFold
                focus = CGRect(x: 0, y: 0, width: size.width, height: max(0, seam.minY))
                controls = CGRect(x: 0, y: seam.maxY, width: size.width,
                                  height: max(0, size.height - seam.maxY))
            }
        } else {
            let wide = size.width >= 700 && size.height >= 500
            let landscape = size.width > size.height &&
                (verticalSizeClass == .compact || size.height < 500)
            if wide {
                mode = .spannedFlat
            } else {
                mode = landscape ? (tentMode ? .tent : .singleLandscape) : .singlePortrait
            }
            let height: CGFloat
            if mode == .tent && !tentControlsOpen {
                height = 72
            } else if cardOpen {
                height = min(340, max(220, size.height * 0.40))
            } else if detailOpen {
                height = size.width >= 640 ? 150 : 196
            } else {
                height = size.width >= 640 ? 76 : 128
            }
            let viewport = IslandMapBounds(size: size, desiredPanelHeight: height,
                                           hudHeight: hudHeight, dockHeight: dockHeight)
            focus = viewport.focus
            controls = viewport.controls
        }
        // Standard containers handle safe areas. This check protects a manual
        // control pane from a camera occlusion that lands inside it.
        let panel = controls
        if #available(iOS 27.1, *) {
            occlusionTopInset = geometry.reservedRegions(kind: .occlusion)
                .map(\.frame)
                .filter { $0.intersects(panel) && $0.minY <= panel.minY + 80 }
                .map { max(0, $0.maxY - panel.minY) }
                .max() ?? 0
        } else {
            occlusionTopInset = 0
        }
    }

    var mapFirst: Bool {
        switch mode {
        case .bookFold, .laptopFold: return false
        default: return true
        }
    }
    var isSingleScreen: Bool {
        switch mode {
        case .singlePortrait, .singleLandscape, .tent: return true
        case .spannedFlat, .bookFold, .laptopFold: return false
        }
    }
    /// The scene cannot tell a tent posture from ordinary outer landscape.
    var canUseTent: Bool { mode == .singleLandscape || mode == .tent }
    var visibleCards: Int {
        switch mode {
        case .spannedFlat, .bookFold, .laptopFold: return 2
        case .singlePortrait, .singleLandscape, .tent: return 1
        }
    }
    var stackedPreviews: Bool { controls.width < 500 }
    /// Full-width sheets keep a short tool row. A wide lower pane can show every tool.
    var compactTools: Bool { mode != .laptopFold && controls.width < 640 }
    var scrollControls: Bool {
        isSingleScreen || mode == .laptopFold || controls.height - occlusionTopInset < 360
    }
    var cardWidth: CGFloat { max(0, min(controls.width - 36, 420)) }
    var optionListHeight: CGFloat {
        let rows: CGFloat = scrollControls ? 2 : 3
        return rows * 52
    }
    var framing: CameraFraming {
        let tiles: CGFloat
        switch mode {
        case .singlePortrait, .singleLandscape, .bookFold: tiles = 8
        case .tent: tiles = 10
        case .spannedFlat: tiles = 18
        case .laptopFold: tiles = 12
        }
        return CameraFraming(viewSize: size, focusRect: focus, tileWidths: tiles)
    }
}

private enum CityTool: String, CaseIterable, Identifiable {
    case inspect, road, house, farm, market, clinic, school, police, workshop, dock
    static let buildings = allCases.filter { $0 != .inspect && $0 != .road }
    var id: String { rawValue }
    var label: String {
        switch self {
        case .inspect: return "Look"
        case .house: return "Home"
        case .police: return "Police station"
        default: return rawValue.capitalized
        }
    }
    var isBuilding: Bool { self != .inspect && self != .road }
    var symbol: String {
        switch self {
        case .inspect: return "hand.point.up.left.fill"
        case .road: return "road.lanes"
        case .house: return "house.fill"
        case .farm: return "leaf.fill"
        case .market: return "basket.fill"
        case .clinic: return "cross.case.fill"
        case .school: return "books.vertical.fill"
        case .police: return "shield.fill"
        case .workshop: return "hammer.fill"
        case .dock: return "ferry.fill"
        }
    }

    var buildingKind: BuildingKind? {
        switch self {
        case .inspect, .road: return nil
        case .house: return .house
        case .farm: return .farm
        case .market: return .market
        case .clinic: return .clinic
        case .school: return .school
        case .police: return .police
        case .workshop: return .workshop
        case .dock: return .dock
        }
    }

    func intent(at tile: TileIndex) -> PlayerIntent? {
        if let kind = buildingKind { return .placeBuilding(kind, at: tile) }
        if self == .road { return .buildRoad(at: tile) }
        return nil
    }
}

private extension AgendaKind {
    var cityTitle: String {
        switch self {
        case .factionDemand: return "Faction demand"
        case .advisoryTradeoff: return "Council advice"
        case .decree: return "Decree"
        case .buildingCommission: return "Building commission"
        case .election: return "Election"
        }
    }
}

private extension DecisionKind {
    var cityTitle: String {
        switch self {
        case .districtUprising: return "District uprising"
        case .corruptionScandal: return "Corruption scandal"
        case .famine: return "Famine"
        case .bankruptcy: return "Bankruptcy"
        }
    }
}


/// An accepted placement receipt is UI state, never part of the city save.
private struct PlacementReceipt {
    let id: BuildingID
    let anchor: TileIndex
    let name: String
    let cost: Int64
    let buildDays: Int32
    let opensOnDay: Int32
}


private struct RoadReceipt {
    let count: Int
    let cost: Int
    let anchor: TileIndex
    let complete: Bool
}


/// Read-only content gets the whole sheet instead of a clipped slice above the dock.
private struct CityReadingSheet<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.dismiss) private var dismiss

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) { content }
                    .frame(maxWidth: 620)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(RepublicTheme.cream)
            .foregroundStyle(RepublicTheme.ink)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct IslandJournalPanel: View {
    @AppStorage("pocket.republic.field-guide.visible.v1") private var showGuide = true
    let goals: [CityFocus]
    let lessons: [SettlementLesson]
    let results: [CityDayResult]
    @Binding var automaticTours: Bool
    let canTour: Bool
    let onGoal: (CityFocusAction) -> Void
    let onTour: () -> Void
    let onGuide: () -> Void
    let onGovernment: () -> Void
    @State private var expandedLesson: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldGuide
            Text("What next?").font(RepublicTheme.heading(.title2))
            Text("A few things your neighbours could use. Choose what matters to you; they will find their own jobs.")
                .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
            ForEach(goals) { goal in
                VStack(alignment: .leading, spacing: 10) {
                    Text(goal.title).font(RepublicTheme.heading(.headline))
                    Text(goal.detail).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    if goal.target > 0 {
                        HStack {
                            ProgressView(value: goal.fraction).tint(RepublicTheme.grass)
                            Text("\(goal.current) / \(goal.target)").font(.caption.monospacedDigit())
                        }
                    }
                    Button(goal.actionLabel) { onGoal(goal.action) }
                        .frame(minHeight: 44).buttonStyle(.borderedProminent).tint(RepublicTheme.terracotta)
                }.dioramaCard()
            }
            Text("While you were building").font(RepublicTheme.heading(.title2))
            if results.isEmpty {
                Text("The first day result appears after the clock advances. Net changes include your building orders and policy decisions.")
                    .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
            }
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.day - result.fromDay == 1 ? "Day \(result.day)" : "Days \(result.fromDay + 1)–\(result.day)")
                        .font(.caption.weight(.bold)).foregroundStyle(RepublicTheme.inkSoft)
                    Text(result.headline).font(RepublicTheme.heading(.headline))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 8) {
                        stat("Residents", signed(Int64(result.populationDelta)), positive: result.populationDelta >= 0)
                        stat("Money change", money(result.treasuryDelta), positive: result.treasuryDelta >= 0)
                        stat("Food stock", signed(result.foodDelta), positive: result.foodDelta >= 0)
                        stat("Happiness", "\(signed(Int64(result.happinessDelta))) pts", positive: result.happinessDelta >= 0)
                        stat("Working residents", signed(Int64(result.employmentDelta)), positive: result.employmentDelta >= 0)
                    }
                    if result.newlyOpened > 0 {
                        Label("\(result.newlyOpened) buildings opened", systemImage: "building.2.fill").font(.caption)
                    }
                    if result.hungry > 0 {
                        Label("\(result.hungry) residents still need food", systemImage: "fork.knife")
                            .font(.caption).foregroundStyle(RepublicTheme.alert)
                    }
                }.dioramaCard()
            }
            Text("These are the last six day results from this visit. Gazette keeps the detailed city events.")
                .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
            Toggle("Show me around new islands", isOn: $automaticTours)
            Button("Show me around", action: onTour)
                .frame(minHeight: 44).buttonStyle(.bordered).disabled(!canTour)
            Text("Tours pause the clock and can be skipped. Finish any active building or road session before replaying.")
                .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
        }.foregroundStyle(RepublicTheme.ink)
    }

    private var fieldGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Getting your town started", isOn: $showGuide)
                .font(RepublicTheme.heading(.title3))
            if showGuide {
                Text("Learn by building. These checks describe the town right now, so they can change as residents arrive. No timers, extra fees or tutorial rewards.")
                    .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
                Text("\(lessons.filter(\.complete).count) of \(lessons.count) conditions ready")
                    .font(.caption.weight(.semibold))
                Button("Show the advice on my island", action: onGuide)
                    .frame(minHeight: 44).buttonStyle(.bordered)
                ForEach(lessons) { lesson in lessonCard(lesson) }
                Text("5. Govern with consequences")
                    .font(RepublicTheme.heading(.headline))
                Text("Open Govern to meet the factions and compare decrees. Read the upfront cost, lasting policy, and approval changes before confirming. Favour is remembered political support; happiness and loyalty describe residents. Optional reading keeps time running—pause from the island dock if you want time to think.")
                    .font(.subheadline)
                Button("Meet the factions in Govern", action: onGovernment)
                    .frame(minHeight: 44).buttonStyle(.bordered)
                Text("You can hide this guide and reopen it here any time. Residents choose jobs automatically; their map walks illustrate planned daily life, while money, food and arrivals settle on daily updates.")
                    .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
            }
        }.dioramaCard(fill: RepublicTheme.sand.opacity(0.35))
        .onAppear { expandedLesson = lessons.first(where: { !$0.complete })?.id }
    }

    private func lessonCard(_ lesson: SettlementLesson) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expandedLesson == lesson.id },
            set: { expandedLesson = $0 ? lesson.id : nil }
        )) {
            VStack(alignment: .leading, spacing: 10) {
                Text(IslandPrompt.lesson(lesson.id)).fixedSize(horizontal: false, vertical: true)
                Text(lesson.evidence.replacingOccurrences(of: "standing", with: "finished")).font(.caption.weight(.semibold))
                if !lesson.complete {
                    Button(lesson.actionLabel) { onGoal(lesson.action) }
                        .frame(minHeight: 44).buttonStyle(.bordered)
                }
            }.font(.subheadline).padding(.top, 8)
        } label: {
            Label(lesson.title, systemImage: lesson.complete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(lesson.complete ? RepublicTheme.fertile : RepublicTheme.ink)
        }.dioramaCard()
    }

    private func stat(_ label: String, _ value: String, positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(RepublicTheme.inkSoft)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(positive ? RepublicTheme.fertile : RepublicTheme.alert)
        }
    }
    private func signed(_ value: Int64) -> String { value >= 0 ? "+\(value)" : "\(value)" }
    private func money(_ value: Int64) -> String { value >= 0 ? "+$\(value)" : "−$\(value.magnitude)" }
}

private struct FoundingTourOverlay: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let beat: Int
    let population: Int
    let nextGoal: String
    let onSkip: () -> Void
    let onContinue: () -> Void

    private var title: String {
        switch beat {
        case 0: return "A new republic"
        case 1: return "People make a town"
        default: return "Learn to lead"
        }
    }
    private var caption: String {
        switch beat {
        case 0: return "\(population) residents call this island home. The next neighbourhood is yours to shape."
        case 1: return "Food, work and a place to live keep the island moving. Residents find their own jobs."
        default: return "Start the hands-on tutorial: place a workshop, watch hiring, add homes, follow food and meet your factions. You can skip or reopen it from the field guide."
        }
    }
    private var continueButton: some View {
        Button(beat == 2 ? "Let’s build your town" : "Continue", action: onContinue)
            .frame(minWidth: 120, maxWidth: .infinity, minHeight: 44).buttonStyle(.borderedProminent).tint(RepublicTheme.terracotta)
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack {
                    if geometry.size.width >= 260 && !textSize.isAccessibilitySize {
                        Text("POCKET REPUBLIC").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(2)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 8)
                    Button("Skip", action: onSkip)
                        .font(.subheadline.weight(.semibold)).frame(minWidth: 72, minHeight: 44)
                        .accessibilityLabel("Skip opening tour")
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
                .background(LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(beat + 1) / 3").font(.caption.monospacedDigit()).foregroundStyle(RepublicTheme.brass)
                            Text(title).font(RepublicTheme.heading(.title2)).accessibilityAddTraits(.isHeader)
                            Text(caption).font(.subheadline)
                            if textSize.isAccessibilitySize { continueButton }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: max(32, min(textSize.isAccessibilitySize ? 300 : 150,
                                               geometry.size.height - (textSize.isAccessibilitySize ? 110 : 170))))
                    if !textSize.isAccessibilitySize { continueButton }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.black.opacity(0.68), .black.opacity(0.96)], startPoint: .top, endPoint: .bottom))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.001))
            .accessibilityElement(children: .contain)
        }
    }
}

/// A short local voice for the existing, real needs; not a new quest or reward.
// MARK: - Observed opening milestones (presentation only)
struct OpeningJourney {
    let mask: Int
    let seed: UInt64
    var record: String { "\(seed):\(mask)" }
    var finishedCount: Int { (0..<4).prefix { mask & (1 << $0) != 0 }.count }
    var complete: Bool { finishedCount == 4 }
    var chapter: String {
        ["A living from the island", "A place to call home", "A good place to live", "Your first new neighbours", "Your republic begins"][finishedCount]
    }

    init(state: RepublicState, record: String) {
        seed = state.worldSeed
        let parts = record.split(separator: ":")
        var earned = parts.count == 2 && UInt64(parts[0]) == seed ? (Int(parts[1]) ?? 0) & 15 : 0
        let lessons = SettlementGuide.lessons(in: state)
        // Record evidence in order. A foundation or a click never completes a step.
        // Once witnessed on this island, ordinary fluctuations do not undo the lesson.
        for (index, lesson) in lessons.prefix(4).enumerated() {
            guard earned & (1 << index) != 0 || lesson.complete else { break }
            earned |= 1 << index
        }
        if state.config.settlementGrowth != nil && state.citizens.filter(\.alive).count > 16 { earned = 15 }
        mask = earned
    }

    func instruction(fallback: String, goal: String) -> String {
        guard goal == "housing" || goal == "arrivals" else { return fallback }
        switch finishedCount {
        case 1: return "Work is underway. Give your next neighbours a home beside the connected streets, then let the builders finish."
        case 2: return "Homes and work are ready. Keep meals within reach and see what would make life here happier."
        case 3: return "You’ve made room for a future here. Let the days run; neighbours arrive when homes, jobs, food and happiness are still ready at the arrival check."
        default: return fallback
        }
    }
}

struct IslandPrompt {
    let title: String
    let message: String
    let button: String
    let action: CityFocusAction

    static func make(in state: RepublicState) -> IslandPrompt {
        let goals = CityFocusReader.goals(in: state)
        let goal = goals.first!
        let people = state.citizens.filter(\.alive)
        let outOfWork = people.filter { $0.work == nil }.count
        if goal.id == "rehousing" {
            return Self(title: "Some neighbours need a home", message: "Let’s get them settled. A finished house gives them somewhere to live.", button: goal.actionLabel, action: goal.action)
        }
        if goal.id == "food" {
            return Self(title: "People are going hungry", message: "Let’s check their market. Food needs a road to their homes, and they need money to buy it.", button: "Check their food", action: goal.action)
        }
        if goal.id.hasPrefix("site-"), case .inspect(let id) = goal.action,
           id.raw >= 0, Int(id.raw) < state.buildings.count {
            let site = state.buildings[Int(id.raw)]
            let left = max(0, site.daysRequired - site.daysConstructed)
            return Self(title: "The builders are at work", message: "Your \(String(describing: site.kind).lowercased()) needs \(left) more day\(left == 1 ? "" : "s") of building. Let the days run; the jobs or beds become available when it opens.", button: "Check progress", action: goal.action)
        }
        if goal.id.hasPrefix("jobs") {
            let shortage = max(0, outOfWork - SettlementOutlook(state: state).openJobs)
            return Self(title: goal.id == "jobs-access" ? "Jobs are ready for your neighbours" : "Make room for \(shortage) more jobs", message: goal.id == "jobs-access" ? "Neighbours take connected jobs as the day begins. Check that their homes and workplaces share a road." : "Existing jobs fill automatically as the day begins. A workshop gives the rest of your neighbours somewhere to work.", button: goal.id == "jobs-access" ? "Show the jobs" : "Build a workshop", action: goal.action)
        }
        if goal.id == "housing" {
            return Self(title: "Make room for new neighbours", message: "Your homes are full. One more house is the start of a new street.", button: "Build a home", action: goal.action)
        }
        if goal.id == "happiness" {
            return Self(title: "Your neighbours could be happier", message: "Let’s look at what’s bothering them before spending more money.", button: "See how they’re doing", action: goal.action)
        }
        if goal.id == "supply-network" {
            return Self(title: "Get ready for new neighbours", message: goal.detail.replacingOccurrences(of: "spare home", with: "empty home").replacingOccurrences(of: "workplace", with: "place to work"), button: "See what’s missing", action: goal.action)
        }
        if goal.id == "arrivals" {
            return Self(title: "There’s room to grow", message: "Homes, work and food are ready. Keep them that way and new neighbours can arrive at the next check.", button: "Who’s moving in?", action: goal.action)
        }
        return Self(title: "What kind of island will you build?", message: "A busy harbour, a close-knit town, or a little of both. Your next steps are yours to choose.", button: "See what’s next", action: goal.action)
    }

    /// A legal starting preview near town. Never places, charges or reserves it.
    static func suggestedSite(for kind: BuildingKind, in state: RepublicState) -> TileIndex? {
        let centre = state.buildings.first(where: { $0.kind == .townHall })?.anchor
            ?? state.map.index(x: state.map.width / 2, y: state.map.height / 2)
        func distance(_ tile: TileIndex) -> Int32 {
            let dx = state.map.x(of: tile) - state.map.x(of: centre)
            let dy = state.map.y(of: tile) - state.map.y(of: centre)
            return abs(dx) + abs(dy)
        }
        var choices = (0..<state.map.tileCount).map { TileIndex(Int32($0)) }
        choices.sort { left, right in
            let a = distance(left), b = distance(right)
            return a == b ? left.raw < right.raw : a < b
        }
        return choices.first {
            if case .valid = SimulationEngine.validatePlacement(kind, at: $0, in: state) { return true }
            return false
        }
    }

    static func lesson(_ id: String) -> String {
        switch id {
        case "work": return "Choose a workshop and find a spot beside the road. Tap Build here when you’re happy with it. The builders will get started, and neighbours will take the jobs once it opens."
        case "homes": return "Build another home beside a road. Give the builders a couple of days, and you’ll have room to welcome new neighbours."
        case "supply": return "Take a look at the farm and market. A full storehouse is only useful if people can get to the market and afford their meals."
        default: return "Keep a home, a job and enough food ready. When people are happy with life here, more neighbours can join you. The island checks every few days."
        }
    }

    static func purpose(_ kind: BuildingKind) -> String {
        switch kind {
        case .house: return "A home for \(kind.housingCapacity) neighbours."
        case .workshop: return "Creates \(kind.workerCapacity) jobs for your town."
        case .farm: return "Grow food for the island. Needs fertile ground."
        case .market: return "Bring food within reach of nearby homes."
        case .clinic: return "Care for the people in your neighbourhood."
        case .school: return "Give your growing community a school."
        case .police: return "Help keep the neighbourhood safe."
        case .dock: return "Open the island to trade."
        case .townHall: return "The heart of your republic."
        }
    }
}

// MARK: - Pure founding tour policy
/// UI-only state. A skipped/finished tour never changes core saves or rewards.
struct FoundingTourPolicy: Equatable {
    static let beatCount = 3
    private(set) var active = false
    private(set) var beat = 0
    var clockHeld: Bool { active }

    static func shouldAutostart(day: Int32, seed: UInt64, seenSeed: String, enabled: Bool, blocked: Bool) -> Bool {
        enabled && !blocked && day == 0 && seenSeed != String(seed)
    }
    mutating func begin() -> Bool {
        guard !active else { return false }
        beat = 0; active = true
        return true
    }
    mutating func advance() -> Bool {
        guard active else { return false }
        if beat + 1 < Self.beatCount { beat += 1; return true }
        active = false
        return false
    }
    /// The final beat waits for an explicit tutorial choice, even when a player
    /// taps Continue faster than the timer. A timer must never choose for them.
    mutating func advanceAutomatically() -> Bool {
        guard active, beat < Self.beatCount - 1 else { return false }
        beat += 1
        return true
    }
    mutating func finish() { active = false }
}
