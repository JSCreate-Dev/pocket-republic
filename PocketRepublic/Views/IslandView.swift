import SwiftUI
import SpriteKit
import PocketRepublicCore

/// Map chrome stays thin. Folded, the agenda is a bottom sheet. Unfolded, it
/// sits in the other pane. `panes` is the swap point for a future layout picker.
struct IslandView: View {
    @EnvironmentObject private var game: Game
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var scene = IslandScene(size: CGSize(width: 400, height: 470))
    @State private var tool: CityTool = .inspect
    @State private var selectedTile: TileIndex?
    @State private var toolsOpen = false
    @State private var sheetFraction: CGFloat = 0.5
    @State private var viewportHeight: CGFloat = 1
    @State private var toolHeight: CGFloat = 64
    @GestureState private var sheetDrag: CGFloat = 0
    private let panes: [CityPane] = [.map, .agenda]

    var body: some View {
        GeometryReader { geometry in
            let fraction = min(0.88, max(0.18, sheetFraction - sheetDrag / max(viewportHeight, 1)))
            let layout = CityDisplayLayout(geometry: geometry,
                                           verticalSizeClass: verticalSizeClass,
                                           layoutDirection: layoutDirection,
                                           panes: panes,
                                           sheetFraction: fraction)
            ZStack(alignment: .topLeading) {
                SpriteView(scene: scene)
                    .background(RepublicTheme.sea)
                    .frame(width: layout.mapFrame.width, height: layout.mapFrame.height)
                    .position(x: layout.mapFrame.midX, y: layout.mapFrame.midY)

                VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
                    statusPill
                    if let feedback = game.feedback {
                        banner(feedback, color: RepublicTheme.alert)
                    }
                    if let issue = game.saveIssue {
                        banner(issue, color: RepublicTheme.terracotta)
                    }
                }
                .padding(.top, layout.occlusionTopInset + RepublicTheme.Space.sm)
                .padding(.horizontal, RepublicTheme.Space.sm)
                .frame(width: layout.focus.width, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
                .offset(x: layout.focus.minX, y: layout.focus.minY)

                toolRow(layout)
                    .padding(.horizontal, RepublicTheme.Space.sm)
                    .frame(width: max(0, layout.focus.width - RepublicTheme.Space.lg))
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: ToolHeightKey.self, value: proxy.size.height)
                        }
                    }
                    .offset(x: layout.focus.minX + RepublicTheme.Space.sm,
                            y: max(layout.focus.minY, layout.focus.maxY - toolHeight - RepublicTheme.Space.sm))

                agendaLayer(layout)
                    .frame(width: layout.agendaFrame.width, height: layout.agendaFrame.height)
                    .position(x: layout.agendaFrame.midX, y: layout.agendaFrame.midY)
            }
            .onAppear {
                viewportHeight = geometry.size.height
                scene.scaleMode = .resizeFill
                scene.setFraming(layout.framing)
                scene.render(game.state)
                configureTapHandler()
                if let spot = game.spotlight { scene.reveal(tileX: spot.x, tileY: spot.y) }
            }
            .onChange(of: geometry.size.height) { _, height in viewportHeight = height }
            .onChange(of: layout.framing) { _, framing in scene.setFraming(framing) }
            .onPreferenceChange(ToolHeightKey.self) { toolHeight = $0 }
        }
        .onReceive(game.$state) { state in
            scene.render(state)
        }
        .onChange(of: game.spotlight?.token) { _, token in
            guard token != nil, let spot = game.spotlight else { return }
            scene.reveal(tileX: spot.x, tileY: spot.y)
        }
    }

    private var statusPill: some View {
        let day = VStack(alignment: .leading, spacing: 0) {
            Text("Day \(game.snapshot.day)")
                .font(RepublicTheme.heading(.caption))
            Text("\(game.snapshot.population) residents")
                .font(RepublicTheme.body(.caption2))
                .foregroundStyle(RepublicTheme.inkSoft)
        }
        let metrics = HStack(spacing: RepublicTheme.Space.sm) {
            metric("dollarsign.circle.fill", "$\(game.snapshot.treasury)", "Treasury")
            metric("fork.knife", "\(game.snapshot.foodInStores)", "Food")
            metric("face.smiling", "\(game.snapshot.meanHappiness)%", "Happiness")
        }
        let advance = Button { game.advance() } label: {
            Label("Advance", systemImage: "forward.fill")
                .font(RepublicTheme.heading(.caption))
                .labelStyle(.titleAndIcon)
                .frame(minHeight: 44)
                .padding(.horizontal, RepublicTheme.Space.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(RepublicTheme.terracotta)
        .accessibilityLabel("Advance One Day")
        .disabled(game.state.blocksAdvance || game.saveIssue != nil)

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: RepublicTheme.Space.sm) {
                day
                Spacer(minLength: RepublicTheme.Space.sm)
                metrics
                advance
            }
            VStack(alignment: .leading, spacing: RepublicTheme.Space.xs) {
                HStack { day; Spacer(minLength: 0); advance }
                metrics
            }
        }
        .padding(.horizontal, RepublicTheme.Space.md)
        .padding(.vertical, RepublicTheme.Space.sm)
        .background(RepublicTheme.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .foregroundStyle(RepublicTheme.ink)
    }

    private func metric(_ symbol: String, _ value: String, _ name: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(RepublicTheme.turquoise)
            Text(value)
                .font(RepublicTheme.heading(.caption))
                .lineLimit(1)
                .minimumScaleFactor(dynamicType.isAccessibilitySize ? 0.8 : 0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(value)")
    }

    private func banner(_ text: String, color: Color) -> some View {
        Text(text)
            .font(RepublicTheme.body(.caption))
            .foregroundStyle(RepublicTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(dynamicType.isAccessibilitySize ? nil : 3)
            .padding(.horizontal, RepublicTheme.Space.md)
            .padding(.vertical, RepublicTheme.Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous))
            .padding(.horizontal, RepublicTheme.Space.sm)
    }

    @ViewBuilder private func toolRow(_ layout: CityDisplayLayout) -> some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.xs) {
            Button {
                toolsOpen.toggle()
            } label: {
                Label(toolsOpen ? "Hide tools" : tool.label, systemImage: toolsOpen ? "chevron.down" : tool.symbol)
                    .font(RepublicTheme.heading(.caption))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(RepublicTheme.turquoise)
            .foregroundStyle(RepublicTheme.ink)
            .accessibilityLabel(toolsOpen ? "Hide tools" : "\(tool.label) tool, show tools")

            if toolsOpen {
                toolStrip(narrow: layout.focus.width < 420)
            }
        }
        .padding(RepublicTheme.Space.xs)
        .background(RepublicTheme.cream.opacity(0.94), in: RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous))
    }

    @ViewBuilder private func toolStrip(narrow: Bool) -> some View {
        if narrow {
            HStack(spacing: 4) {
                narrowToolButton(.inspect)
                narrowToolButton(.road)
                Menu {
                    ForEach(CityTool.buildings) { option in
                        Button(option.label, systemImage: option.symbol) { select(option) }
                    }
                } label: {
                    Image(systemName: "building.2.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(tool.isBuilding ? RepublicTheme.terracotta : RepublicTheme.turquoise)
                .accessibilityLabel("Buildings tool")
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(CityTool.allCases) { option in toolButton(option) }
                }
            }
        }
    }

    private func narrowToolButton(_ option: CityTool) -> some View {
        Button { select(option) } label: {
            Image(systemName: option.symbol)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(tool == option ? RepublicTheme.terracotta : RepublicTheme.turquoise)
        .accessibilityLabel("\(option.label) tool")
    }

    private func toolButton(_ option: CityTool) -> some View {
        Button { select(option) } label: {
            Label(option.label, systemImage: option.symbol)
                .font(RepublicTheme.heading(.caption))
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(tool == option ? RepublicTheme.terracotta : RepublicTheme.turquoise)
        .accessibilityLabel("\(option.label) tool")
    }

    private func select(_ option: CityTool) {
        tool = option
        configureTapHandler()
    }

    private func agendaLayer(_ layout: CityDisplayLayout) -> some View {
        AgendaBoard(tileCaption: tileCaption, topInset: layout.posture == .folded ? 16 : 0)
            .clipShape(RoundedRectangle(cornerRadius: layout.posture == .folded ? 22 : 0, style: .continuous))
            .overlay(alignment: .top) {
                if layout.posture == .folded {
                    Capsule()
                        .fill(RepublicTheme.rock.opacity(0.55))
                        .frame(width: 48, height: 5)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(Rectangle())
                        .gesture(sheetGesture)
                        .accessibilityLabel("Agenda")
                        .accessibilityValue(sheetFraction > 0.7 ? "Expanded" : "Half height")
                        .accessibilityAdjustableAction { direction in
                            sheetFraction = direction == .increment ? 0.88 : 0.5
                        }
                }
            }
            .shadow(color: .black.opacity(layout.posture == .folded ? 0.18 : 0.08), radius: 10, y: -2)
    }

    private var sheetGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($sheetDrag) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let next = sheetFraction - value.translation.height / max(viewportHeight, 1)
                sheetFraction = min(0.88, max(0.18, next))
            }
    }

    private var tileCaption: String? {
        guard let selectedTile else { return nil }
        let x = game.state.map.x(of: selectedTile)
        let y = game.state.map.y(of: selectedTile)
        return "Tile \(x), \(y) · \(terrainLabel(at: selectedTile))"
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

private struct ToolHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 64
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
