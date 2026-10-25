import SwiftUI
import SpriteKit
import UIKit
import PocketRepublicCore

/// Screen-space controls use the local scene geometry and Apple's reserved regions.
/// The SpriteKit world stays behind them and is never part of the saved simulation.
struct IslandView: View {
    @EnvironmentObject private var game: Game
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var scene = IslandScene(size: CGSize(width: 400, height: 470))
    @State private var tool: CityTool = .inspect
    @State private var selectedTile: TileIndex?
    @State private var selectedBuildingID: BuildingID?
    @State private var selectedAgendaID: DecisionID?
    @State private var placementHint: String?
    @State private var sheetExpanded = false
    @State private var tentMode = false
    @State private var tentControlsOpen = false

    var body: some View {
        GeometryReader { geometry in
            let layout = CityDisplayLayout(geometry: geometry,
                                           verticalSizeClass: verticalSizeClass,
                                           layoutDirection: layoutDirection,
                                           tentMode: tentMode,
                                           sheetExpanded: sheetExpanded,
                                           tentControlsOpen: tentControlsOpen)
            ZStack(alignment: .topLeading) {
                SpriteView(scene: scene)
                    .background(Color(red: 0.05, green: 0.22, blue: 0.37))

                if layout.isSingleScreen {
                    HStack(alignment: .top, spacing: 8) {
                        status(in: layout)
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
                            .accessibilityHint("Changes the outer display between a bottom panel and a map-first tent view")
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                if layout.mode == .tent && !tentControlsOpen {
                    tentDock()
                        .frame(width: layout.controls.width, height: layout.controls.height)
                        .position(x: layout.controls.midX, y: layout.controls.midY)
                } else {
                    controls(in: layout)
                        .frame(width: layout.controls.width, height: layout.controls.height)
                        .background {
                            if layout.isSingleScreen {
                                UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
                                    .fill(.regularMaterial)
                            } else {
                                Rectangle().fill(.regularMaterial)
                            }
                        }
                        .position(x: layout.controls.midX, y: layout.controls.midY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear {
                scene.scaleMode = .resizeFill
                scene.setFraming(layout.framing)
                scene.render(game.state)
                scene.setSelection(selectedBuildingID)
                configureTapHandler()
            }
            .sensoryFeedback(.selection, trigger: selectedBuildingID) { _, newValue in
                newValue != nil
            }
            .onChange(of: layout.framing) { _, framing in
                scene.setFraming(framing)
            }
        }
        .onReceive(game.$state) { state in
            if let selectedBuildingID,
               BuildingHitTest.occupiedTiles(selectedBuildingID, on: state.map).isEmpty {
                self.selectedBuildingID = nil
            }
            scene.render(state)
            if let selectedAgendaID, !state.agenda.contains(where: { $0.id == selectedAgendaID }) {
                self.selectedAgendaID = nil
            }
        }
        .onChange(of: selectedBuildingID) { _, id in
            scene.setSelection(id)
        }
        .onChange(of: tool) { _, newTool in
            if newTool != .inspect { selectedBuildingID = nil }
        }
    }

    @ViewBuilder private func controls(in layout: CityDisplayLayout) -> some View {
        let content = VStack(spacing: 8) {
            if layout.isSingleScreen {
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
                    }
                }
                .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                    if value.translation.height < -40 { sheetExpanded = true }
                    if value.translation.height > 40 { sheetExpanded = false }
                })
            } else {
                status(in: layout)
            }
            if game.state.pending == nil && selectedAgenda == nil {
                agendaPreviews(layout: layout)
            }
            if !layout.scrollControls { Spacer(minLength: 0) }
            if let pending = game.state.pending {
                crisisCard(pending, layout: layout)
            } else if let item = selectedAgenda {
                agendaCard(item, layout: layout)
            } else {
                if let inspection = buildingInspection {
                    BuildingInspectPanel(
                        inspection: inspection,
                        onClose: { selectedBuildingID = nil },
                        onSetMode: { mode in
                            game.send(.setOperatingMode(inspection.buildingID, mode))
                        },
                        onDemolish: {
                            game.send(.demolish(inspection.buildingID))
                        }
                    )
                    .frame(maxWidth: layout.cardWidth, alignment: .leading)
                } else if let selectedTile {
                    let x = game.state.map.x(of: selectedTile)
                    let y = game.state.map.y(of: selectedTile)
                    Text("Tile \(x), \(y) · \(terrainLabel(at: selectedTile))")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                }
                toolStrip(compact: layout.compactTools, narrow: layout.mode == .singlePortrait)
            }
            Button { game.advance() } label: {
                Label(layout.mode == .singlePortrait ? "Next Day" : "Advance One Day", systemImage: "forward.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(game.state.blocksAdvance || game.saveIssue != nil)
        }
        .padding(.top, layout.occlusionTopInset)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)

        if layout.scrollControls {
            ScrollView(.vertical, showsIndicators: false) { content }
        } else {
            content
        }
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
        VStack(spacing: 5) {
            HStack {
                Text("Day \(game.snapshot.day) · \(game.snapshot.population) residents")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
            }
            HStack(spacing: 5) {
                metric(layout.mode == .singlePortrait ? "Cash" : "Treasury", "$\(game.snapshot.treasury)")
                metric("Food", "\(game.snapshot.foodInStores)")
                metric("Happy", "\(game.snapshot.meanHappiness)%")
            }
            if tool.isBuilding {
                if let placementHint {
                    Text(placementHint)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .lineLimit(layout.scrollControls ? nil : 3)
                }
            } else if let feedback = game.feedback {
                Text(feedback).font(.caption).foregroundStyle(.orange)
                    .lineLimit(layout.scrollControls ? nil : 2)
            }
            if let issue = game.saveIssue {
                Text(issue).font(.caption).foregroundStyle(.red)
                    .lineLimit(layout.scrollControls ? nil : 3)
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedAgenda: AgendaItem? {
        guard let selectedAgendaID else { return nil }
        return game.state.agenda.first(where: { $0.id == selectedAgendaID })
    }

    @ViewBuilder private func agendaPreviews(layout: CityDisplayLayout) -> some View {
        if layout.stackedPreviews {
            VStack(spacing: 5) {
                ForEach(Array(game.state.agenda.prefix(layout.visibleCards))) { item in
                    previewButton(item)
                }
            }
        } else {
            HStack(spacing: 5) {
                ForEach(Array(game.state.agenda.prefix(layout.visibleCards))) { item in
                    previewButton(item)
                }
            }
        }
    }

    private func previewButton(_ item: AgendaItem) -> some View {
        Button {
            selectedAgendaID = item.id
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "text.bubble.fill")
                Text(item.kind.cityTitle).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption2)
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
    }

    private func crisisCard(_ pending: PendingDecision, layout: CityDisplayLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("City crisis", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(pending.kind.cityTitle).font(.subheadline.weight(.semibold))
            if let cause = pending.causes.first {
                Text("\(cause.detail): \(cause.value)")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.kind.cityTitle).font(.headline)
                Spacer()
                Button("Close", systemImage: "xmark") { selectedAgendaID = nil }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Close decision")
            }
            if let cause = item.causes.first {
                Text("\(cause.detail): \(cause.value)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    ForEach(item.options) { option in
                        Button {
                            game.send(.resolveAgendaItem(item.id, option: option.id))
                            selectedAgendaID = nil
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

    @ViewBuilder private func toolStrip(compact: Bool, narrow: Bool) -> some View {
        if narrow {
            HStack(spacing: 4) {
                narrowToolButton(.inspect)
                narrowToolButton(.road)
                Menu {
                    ForEach(CityTool.buildings) { option in
                        Button(option.label, systemImage: option.symbol) {
                            tool = option
                            configureTapHandler()
                        }
                    }
                } label: {
                    Image(systemName: "building.2.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(tool.isBuilding ? .mint : .indigo)
                .accessibilityLabel("Buildings tool")
            }
            .padding(4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else if compact {
            HStack(spacing: 6) {
                toolButton(.inspect)
                toolButton(.road)
                Menu {
                    ForEach(CityTool.buildings) { option in
                        Button(option.label, systemImage: option.symbol) {
                            tool = option
                            configureTapHandler()
                        }
                    }
                } label: {
                    Label(tool.isBuilding ? tool.label : "Buildings", systemImage: "building.2.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(tool.isBuilding ? .mint : .indigo)
            }
            .padding(5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(CityTool.allCases) { option in toolButton(option) }
                }
                .padding(5)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
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
        .tint(tool == option ? .mint : .indigo)
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
        .tint(tool == option ? .mint : .indigo)
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
        scene.setPlacementKind(activeTool.buildingKind, fallbackHover: selectedTile)
        scene.onTileTap = { tile in
            Task { @MainActor in
                if activeTool == .inspect {
                    if let building = BuildingHitTest.building(on: tile, in: game.state) {
                        selectedBuildingID = building.id
                        selectedTile = nil
                    } else {
                        selectedBuildingID = nil
                        selectedTile = tile
                    }
                } else {
                    selectedTile = tile
                    guard game.saveIssue == nil, let intent = activeTool.intent(at: tile) else { return }
                    game.send(intent)
                    if activeTool.isBuilding, game.feedback == nil {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        scene.hidePlacementGhost()
                    }
                }
            }
        }
    }
}

/// A single display keeps the map full-width with a draggable bottom panel.
/// A spanned inner display assigns the world and controls to separate panes.
/// Tent view is selected on the outer landscape display because that posture has no distinct scene signal.
private struct CityDisplayLayout {
    enum Mode { case singlePortrait, singleLandscape, tent, spannedFlat, bookFold, laptopFold }
    let mode: Mode
    let size: CGSize
    let focus: CGRect
    let controls: CGRect
    let occlusionTopInset: CGFloat

    init(geometry: GeometryProxy, verticalSizeClass: UserInterfaceSizeClass?,
         layoutDirection: LayoutDirection, tentMode: Bool,
         sheetExpanded: Bool, tentControlsOpen: Bool) {
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
        } else if size.width >= 580 && size.height >= 500 {
            mode = .spannedFlat
            let paneWidth = size.width / 2
            if layoutDirection == .rightToLeft {
                controls = CGRect(x: 0, y: 0, width: paneWidth, height: size.height)
                focus = CGRect(x: paneWidth, y: 0, width: paneWidth, height: size.height)
            } else {
                focus = CGRect(x: 0, y: 0, width: paneWidth, height: size.height)
                controls = CGRect(x: paneWidth, y: 0, width: paneWidth, height: size.height)
            }
        } else {
            let landscape = size.width > size.height &&
                (verticalSizeClass == .compact || size.height < 500)
            mode = landscape ? (tentMode ? .tent : .singleLandscape) : .singlePortrait
            let height: CGFloat
            if mode == .tent && !tentControlsOpen {
                height = 72
            } else if sheetExpanded {
                height = size.height * 0.82
            } else {
                height = size.height * (landscape ? 0.58 : 0.5)
            }
            let panelHeight = min(size.height, max(0, height))
            focus = CGRect(x: 0, y: 0, width: size.width,
                           height: max(0, size.height - panelHeight))
            controls = CGRect(x: 0, y: size.height - panelHeight,
                              width: size.width, height: panelHeight)
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

    var isSingleScreen: Bool {
        switch mode {
        case .singlePortrait, .singleLandscape, .tent: return true
        case .spannedFlat, .bookFold, .laptopFold: return false
        }
    }
    var canUseTent: Bool { mode == .singleLandscape || mode == .tent }
    var visibleCards: Int {
        switch mode {
        case .spannedFlat, .bookFold, .laptopFold: return 2
        case .singlePortrait, .singleLandscape, .tent: return 1
        }
    }
    var stackedPreviews: Bool { controls.width < 500 }
    var compactTools: Bool { mode != .laptopFold }
    var scrollControls: Bool {
        isSingleScreen || mode == .laptopFold || controls.height - occlusionTopInset < 360
    }
    var cardWidth: CGFloat { max(0, min(controls.width - 36, 360)) }
    var optionListHeight: CGFloat {
        let rows: CGFloat = scrollControls ? 2 : 3
        return rows * 52
    }
    var framing: CameraFraming {
        let tiles: CGFloat
        switch mode {
        case .singlePortrait, .singleLandscape, .bookFold: tiles = 8
        case .tent: tiles = 10
        case .spannedFlat, .laptopFold: tiles = 12
        }
        return CameraFraming(viewSize: size, focusRect: focus, tileWidths: tiles)
    }
}

private enum CityTool: String, CaseIterable, Identifiable {
    case inspect, road, house, farm, market, clinic, school, police, workshop, dock
    static let buildings = allCases.filter { $0 != .inspect && $0 != .road }
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
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
