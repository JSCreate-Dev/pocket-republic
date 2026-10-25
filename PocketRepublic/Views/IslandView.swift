import SwiftUI
import SpriteKit
import PocketRepublicCore

/// Screen-space controls stay in SwiftUI's safe area; the SpriteKit camera owns only world space.
struct IslandView: View {
    @EnvironmentObject private var game: Game
    @State private var scene = IslandScene(size: CGSize(width: 400, height: 470))
    @State private var tool: CityTool = .inspect
    @State private var selectedTile: TileIndex?
    @State private var selectedAgendaID: DecisionID?

    var body: some View {
        GeometryReader { geometry in
            let budget = DecisionCardBudget(sceneSize: geometry.size)
            ZStack {
                SpriteView(scene: scene)
                    .background(Color(red: 0.05, green: 0.22, blue: 0.37))

                VStack(spacing: 8) {
                    if game.state.pending == nil && selectedAgenda == nil {
                        agendaPreviews(budget: budget)
                    }
                    Spacer(minLength: 0)
                    if let pending = game.state.pending {
                        crisisCard(pending, budget: budget)
                    } else if let item = selectedAgenda {
                        agendaCard(item, budget: budget)
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
                        toolStrip(compact: budget.compact)
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onAppear {
            scene.scaleMode = .resizeFill
            scene.render(game.state)
            configureTapHandler()
        }
        .onReceive(game.$state) { state in
            scene.render(state)
            if let selectedAgendaID, !state.agenda.contains(where: { $0.id == selectedAgendaID }) {
                self.selectedAgendaID = nil
            }
        }
    }

    private var selectedAgenda: AgendaItem? {
        guard let selectedAgendaID else { return nil }
        return game.state.agenda.first(where: { $0.id == selectedAgendaID })
    }

    private func agendaPreviews(budget: DecisionCardBudget) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(game.state.agenda.prefix(budget.visibleCards))) { item in
                Button {
                    selectedAgendaID = item.id
                } label: {
                    HStack(spacing: 6) {
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
            Spacer(minLength: 0)
        }
        .accessibilityLabel("City decisions")
    }

    private func crisisCard(_ pending: PendingDecision, budget: DecisionCardBudget) -> some View {
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
                            Text(option.label)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(maxHeight: budget.optionListHeight)
        }
        .frame(maxWidth: budget.cardWidth, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private func agendaCard(_ item: AgendaItem, budget: DecisionCardBudget) -> some View {
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
                            Text(option.label)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(maxHeight: budget.optionListHeight)
        }
        .frame(maxWidth: budget.cardWidth, alignment: .leading)
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

/// Geometry is measured inside the NavigationStack/TabView safe area. No fixed Duo inset
/// is valid across the two displays, fold positions, rotation, and system UI changes.
private struct DecisionCardBudget {
    let compact: Bool
    let visibleCards: Int
    let visibleOptionRows: Int
    let cardWidth: CGFloat

    init(sceneSize: CGSize) {
        compact = sceneSize.width < 580 || sceneSize.height < 500
        visibleCards = compact ? 1 : 2
        visibleOptionRows = compact ? 2 : 3
        cardWidth = max(0, min(sceneSize.width - 40, compact ? 400 : 360))
    }

    var optionListHeight: CGFloat { CGFloat(visibleOptionRows) * 52 }
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
