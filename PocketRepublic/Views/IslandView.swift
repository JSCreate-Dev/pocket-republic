import SwiftUI
import SpriteKit
import PocketRepublicCore

struct IslandView: View {
    @EnvironmentObject private var game: Game
    @State private var scene = IslandScene(size: CGSize(width: 400, height: 470))
    @State private var tool: CityTool = .inspect
    @State private var selectedTile: TileIndex?

    var body: some View {
        VStack(spacing: 0) {
            SpriteView(scene: scene)
                .background(Color(red: 0.05, green: 0.22, blue: 0.37))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(CityTool.allCases) { option in
                        Button(option.label) {
                            tool = option
                            configureTapHandler()
                        }
                        .buttonStyle(.bordered)
                        .tint(tool == option ? .mint : .secondary)
                    }
                }
                .padding(8)
            }
            .background(.black.opacity(0.35))
            if let selectedTile {
                let x = game.state.map.x(of: selectedTile)
                let y = game.state.map.y(of: selectedTile)
                Text("Tile \(x), \(y) · \(terrainLabel(at: selectedTile))")
                    .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.bottom, 5)
                    .background(.black.opacity(0.35))
            }
        }
        .onAppear {
            scene.scaleMode = .resizeFill
            scene.render(game.state)
            configureTapHandler()
        }
        .onReceive(game.$state) { state in scene.render(state) }
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

private enum CityTool: String, CaseIterable, Identifiable {
    case inspect, road, house, farm, market, clinic, school, police, workshop, dock
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

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
