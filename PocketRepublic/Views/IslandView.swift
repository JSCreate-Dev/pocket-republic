import SwiftUI
import SpriteKit
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
    @State private var selectedAgendaID: DecisionID?

    var body: some View {
        GeometryReader { geometry in
            let layout = CityDisplayLayout(geometry: geometry,
                                           verticalSizeClass: verticalSizeClass,
                                           layoutDirection: layoutDirection)
            ZStack(alignment: .topLeading) {
                SpriteView(scene: scene)
                    .background(Color(red: 0.05, green: 0.22, blue: 0.37))

                controls(in: layout)
                    .frame(width: layout.controls.width, height: layout.controls.height)
                    .position(x: layout.controls.midX, y: layout.controls.midY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear {
                scene.scaleMode = .resizeFill
                scene.setFraming(layout.framing)
                scene.render(game.state)
                configureTapHandler()
            }
            .onChange(of: layout.framing) { _, framing in
                scene.setFraming(framing)
            }
        }
        .onReceive(game.$state) { state in
            scene.render(state)
            if let selectedAgendaID, !state.agenda.contains(where: { $0.id == selectedAgendaID }) {
                self.selectedAgendaID = nil
            }
        }
    }

    @ViewBuilder private func controls(in layout: CityDisplayLayout) -> some View {
        let content = VStack(spacing: 8) {
            status(in: layout)
            if game.state.pending == nil && selectedAgenda == nil {
                agendaPreviews(layout: layout)
            }
            if !layout.scrollControls { Spacer(minLength: 0) }
            if let pending = game.state.pending {
                crisisCard(pending, layout: layout)
            } else if let item = selectedAgenda {
                agendaCard(item, layout: layout)
            } else {
                if let selectedTile {
                    let x = game.state.map.x(of: selectedTile)
                    let y = game.state.map.y(of: selectedTile)
                    Text("Tile \(x), \(y) · \(terrainLabel(at: selectedTile))")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                }
                toolStrip(compact: layout.compactTools)
            }
            Button { game.advance() } label: {
                Label("Advance One Day", systemImage: "forward.fill")
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
                .background(.thinMaterial)
        } else {
            content
        }
    }

    private func status(in layout: CityDisplayLayout) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text("Day \(game.snapshot.day) · \(game.snapshot.population) residents")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
            }
            HStack(spacing: 5) {
                metric("Treasury", "$\(game.snapshot.treasury)")
                metric("Food", "\(game.snapshot.foodInStores)")
                metric("Happy", "\(game.snapshot.meanHappiness)%")
            }
            if let feedback = game.feedback {
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

    @ViewBuilder private func toolStrip(compact: Bool) -> some View {
        if compact {
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

    private func configureTapHandler() {
        let activeTool = tool
        scene.onTileTap = { tile in
            Task { @MainActor in
                selectedTile = tile
                if let intent = activeTool.intent(at: tile) { game.send(intent) }
            }
        }
    }
}

/// Uses the offered safe-area bounds, then the fold's active reserved region when present.
/// A partial book fold gets a right/left control pane; a laptop fold gets a lower pane.
/// Tent posture on the outer display is an ordinary compact-height landscape layout.
private struct CityDisplayLayout {
    enum Mode { case singlePortrait, singleLandscape, innerFlat, bookFold, laptopFold }
    let mode: Mode
    let size: CGSize
    let focus: CGRect
    let controls: CGRect
    let occlusionTopInset: CGFloat

    init(geometry: GeometryProxy, verticalSizeClass: UserInterfaceSizeClass?,
         layoutDirection: LayoutDirection) {
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
        } else if verticalSizeClass == .compact && size.width > size.height {
            mode = .singleLandscape
            let railWidth = min(300, max(220, size.width * 0.36))
            focus = CGRect(x: 0, y: 0, width: size.width - railWidth, height: size.height)
            controls = CGRect(x: size.width - railWidth, y: 0,
                              width: railWidth, height: size.height)
        } else if size.width >= 580 && size.height >= 500 {
            mode = .innerFlat
            let railWidth = min(380, size.width * 0.42)
            focus = CGRect(x: 0, y: 0, width: size.width - railWidth, height: size.height)
            controls = CGRect(x: size.width - railWidth, y: 0,
                              width: railWidth, height: size.height)
        } else {
            mode = .singlePortrait
            focus = bounds
            controls = bounds
        }
        // Standard containers handle safe areas. This extra check protects our
        // manually positioned panel from an active camera occlusion inside them.
        if #available(iOS 27.1, *) {
            occlusionTopInset = geometry.reservedRegions(kind: .occlusion)
                .map(\.frame)
                .filter { $0.intersects(controls) && $0.minY <= controls.minY + 80 }
                .map { max(0, $0.maxY - controls.minY) }
                .max() ?? 0
        } else {
            occlusionTopInset = 0
        }
    }

    var visibleCards: Int {
        switch mode {
        case .innerFlat, .bookFold, .laptopFold: return 2
        case .singlePortrait, .singleLandscape: return 1
        }
    }
    var stackedPreviews: Bool { controls.width < 500 }
    var compactTools: Bool { mode != .laptopFold }
    var scrollControls: Bool {
        mode == .singleLandscape || mode == .laptopFold || controls.height - occlusionTopInset < 360
    }
    var cardWidth: CGFloat { max(0, min(controls.width - 36, 360)) }
    var optionListHeight: CGFloat {
        let rows: CGFloat = scrollControls ? 2 : (mode == .singlePortrait ? 2 : 3)
        return rows * 52
    }
    var framing: CameraFraming {
        let tiles: CGFloat
        switch mode {
        case .singlePortrait: tiles = 9
        case .singleLandscape: tiles = 8
        case .innerFlat: tiles = 12
        case .bookFold: tiles = 8
        case .laptopFold: tiles = 12
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

    func intent(at tile: TileIndex) -> PlayerIntent? {
        switch self {
        case .inspect: return nil
        case .road: return .buildRoad(at: tile)
        case .house: return .placeBuilding(.house, at: tile)
        case .farm: return .placeBuilding(.farm, at: tile)
        case .market: return .placeBuilding(.market, at: tile)
        case .clinic: return .placeBuilding(.clinic, at: tile)
        case .school: return .placeBuilding(.school, at: tile)
        case .police: return .placeBuilding(.police, at: tile)
        case .workshop: return .placeBuilding(.workshop, at: tile)
        case .dock: return .placeBuilding(.dock, at: tile)
        }
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
