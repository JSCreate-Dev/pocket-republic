import SpriteKit
import UIKit
import PocketRepublicCore

/// A disposable picture of the core state. No SpriteKit node is saved or simulated.
final class IslandScene: SKScene {
    var onTileTap: ((TileIndex) -> Void)?

    private let terrainLayer = SKNode()
    private let buildingLayer = SKNode()
    private let peopleLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let nightLayer = SKSpriteNode(color: .black, size: .zero)
    private var renderedState: RepublicState?
    private var tileNodes: [Int32: SKSpriteNode] = [:]
    private var buildingNodes: [BuildingID: SKSpriteNode] = [:]
    private var citizenNodes: [CitizenID: SKShapeNode] = [:]
    private var visibleCitizenIDs: [CitizenID] = []
    private var ambientNodes: [Int32: SKShapeNode] = [:]
    private var tileTextures: [String: SKTexture] = [:]
    private var routeCache: [RouteKey: [TileIndex]] = [:]
    private var visibleRect: TileRect?
    private var cameraInitialized = false
    private var touchStart: CGPoint?
    private var wasDragged = false

    private let halfWidth: CGFloat = 32
    private let halfHeight: CGFloat = 16

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = UIColor(red: 0.05, green: 0.22, blue: 0.37, alpha: 1)
        isUserInteractionEnabled = true
        terrainLayer.zPosition = 0
        buildingLayer.zPosition = 10
        peopleLayer.zPosition = 30
        addChild(terrainLayer)
        addChild(buildingLayer)
        addChild(peopleLayer)
        addChild(cameraNode)
        camera = cameraNode
        nightLayer.zPosition = 100
        cameraNode.addChild(nightLayer)
        resizeNightLayer()
    }

    required init?(coder: NSCoder) { fatalError("Use init(size:)") }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.ignoresSiblingOrder = true
        refreshVisible(force: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        resizeNightLayer()
        refreshVisible(force: true)
    }

    func render(_ state: RepublicState) {
        if let old = renderedState,
           old.map.road != state.map.road || old.map.buildingAt != state.map.buildingAt {
            routeCache.removeAll()
        }
        renderedState = state
        if !cameraInitialized {
            let middle = state.map.width / 2
            cameraNode.position = point(x: middle, y: middle)
            cameraNode.setScale(1.1)
            cameraInitialized = true
        }
        refreshVisible(force: true)
    }

    private func point(x: Int32, y: Int32) -> CGPoint {
        CGPoint(x: CGFloat(x - y) * halfWidth,
                y: -CGFloat(x + y) * halfHeight)
    }

    private func point(for tile: TileIndex, in map: WorldMap) -> CGPoint {
        point(x: map.x(of: tile), y: map.y(of: tile))
    }

    private func tile(at position: CGPoint, in map: WorldMap) -> TileIndex? {
        let sx = position.x / halfWidth
        let sy = -position.y / halfHeight
        let x = Int32(((sx + sy) / 2).rounded())
        let y = Int32(((sy - sx) / 2).rounded())
        guard map.contains(x: x, y: y) else { return nil }
        return map.index(x: x, y: y)
    }

    private func viewport(in map: WorldMap) -> TileRect {
        let w = size.width * cameraNode.xScale / 2
        let h = size.height * cameraNode.yScale / 2
        let c = cameraNode.position
        let corners = [CGPoint(x: c.x-w, y: c.y-h), CGPoint(x: c.x+w, y: c.y-h),
                       CGPoint(x: c.x-w, y: c.y+h), CGPoint(x: c.x+w, y: c.y+h)]
        let xy = corners.map { p -> (CGFloat, CGFloat) in
            let sx = p.x / halfWidth, sy = -p.y / halfHeight
            return ((sx + sy) / 2, (sy - sx) / 2)
        }
        let xs = xy.map(\.0), ys = xy.map(\.1)
        return TileRect(
            x0: max(0, Int32(floor(xs.min() ?? 0)) - 3),
            y0: max(0, Int32(floor(ys.min() ?? 0)) - 3),
            x1: min(map.width - 1, Int32(ceil(xs.max() ?? 0)) + 3),
            y1: min(map.height - 1, Int32(ceil(ys.max() ?? 0)) + 3)
        )
    }

    private func refreshVisible(force: Bool = false) {
        guard let state = renderedState else { return }
        let map = state.map
        let rect = viewport(in: map)
        guard force || rect != visibleRect else { return }
        visibleRect = rect

        var wantedTiles = Set<Int32>()
        if rect.x0 <= rect.x1 && rect.y0 <= rect.y1 {
            for y in rect.y0...rect.y1 {
                for x in rect.x0...rect.x1 {
                    let tile = map.index(x: x, y: y)
                    wantedTiles.insert(tile.raw)
                    let texture = texture(for: map.terrain(at: tile), road: map.isRoad(at: tile))
                    if let node = tileNodes[tile.raw] {
                        if force { node.texture = texture }
                    } else {
                        let node = SKSpriteNode(texture: texture, size: CGSize(width: 64, height: 32))
                        node.position = point(x: x, y: y)
                        terrainLayer.addChild(node)
                        tileNodes[tile.raw] = node
                    }
                }
            }
        }
        for (id, node) in tileNodes where !wantedTiles.contains(id) {
            node.removeFromParent()
            tileNodes.removeValue(forKey: id)
        }

        let frame = state.snapshot(visibleRect: (rect.x0, rect.y0, rect.x1, rect.y1))
        var wantedBuildings = Set<BuildingID>()
        for building in frame.visibleBuildings where map.building(at: building.tile) == building.id {
            wantedBuildings.insert(building.id)
            if buildingNodes[building.id] == nil {
                let node = SKSpriteNode(color: building.kind.color,
                                        size: CGSize(width: 26, height: building.kind == .townHall ? 32 : 23))
                node.anchorPoint = CGPoint(x: 0.5, y: 0.12)
                node.position = point(for: building.tile, in: map)
                node.zPosition = CGFloat(map.x(of: building.tile) + map.y(of: building.tile)) / 100
                buildingLayer.addChild(node)
                buildingNodes[building.id] = node
            }
        }
        for (id, node) in buildingNodes where !wantedBuildings.contains(id) {
            node.removeFromParent()
            buildingNodes.removeValue(forKey: id)
        }
        refreshPeople(state: state, rect: rect)
    }

    private func texture(for terrain: TerrainKind, road: Bool) -> SKTexture {
        let key = "\(terrain.rawValue)-\(road)"
        if let existing = tileTextures[key] { return existing }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 32)).image { _ in
            let diamond = UIBezierPath()
            diamond.move(to: CGPoint(x: 32, y: 0))
            diamond.addLine(to: CGPoint(x: 64, y: 16))
            diamond.addLine(to: CGPoint(x: 32, y: 32))
            diamond.addLine(to: CGPoint(x: 0, y: 16))
            diamond.close()
            (road ? UIColor(red: 0.43, green: 0.43, blue: 0.40, alpha: 1) : terrain.color).setFill()
            diamond.fill()
            UIColor.black.withAlphaComponent(0.16).setStroke()
            diamond.lineWidth = 1
            diamond.stroke()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        tileTextures[key] = texture
        return texture
    }

    private func refreshPeople(state: RepublicState, rect: TileRect) {
        let map = state.map
        let visible = state.citizens.filter { citizen in
            guard citizen.alive, let home = citizen.home, let work = citizen.work,
                  Int(home.raw) < state.buildings.count, Int(work.raw) < state.buildings.count else { return false }
            return rect.contains(state.buildings[Int(home.raw)].tile, in: map)
                || rect.contains(state.buildings[Int(work.raw)].tile, in: map)
        }.prefix(24)
        let wanted = Set(visible.map(\.id))
        visibleCitizenIDs = visible.map(\.id)
        for citizen in visible where citizenNodes[citizen.id] == nil {
            let node = SKShapeNode(circleOfRadius: 3)
            node.fillColor = citizen.daysHungry > 0 ? .orange : .white
            node.strokeColor = .black
            node.lineWidth = 1
            peopleLayer.addChild(node)
            citizenNodes[citizen.id] = node
        }
        for (id, node) in citizenNodes where !wanted.contains(id) {
            node.removeFromParent()
            citizenNodes.removeValue(forKey: id)
        }

        let roads = tileNodes.keys.sorted().filter { map.road[Int($0)] }
        let stride = max(1, roads.count / 12)
        let wantedAmbient = Set(Swift.stride(from: 0, to: roads.count, by: stride).prefix(12).map { roads[$0] })
        for raw in wantedAmbient where ambientNodes[raw] == nil {
            let node = SKShapeNode(circleOfRadius: 2)
            node.fillColor = .yellow
            node.strokeColor = .clear
            peopleLayer.addChild(node)
            ambientNodes[raw] = node
        }
        for (raw, node) in ambientNodes where !wantedAmbient.contains(raw) {
            node.removeFromParent()
            ambientNodes.removeValue(forKey: raw)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard let state = renderedState else { return }
        let map = state.map
        let phase = (currentTime / 100 + Double(state.day % 3) / 3).truncatingRemainder(dividingBy: 1)
        nightLayer.alpha = CGFloat(0.07 + 0.25 * (1 - cos(phase * .pi * 2)) / 2)

        for id in visibleCitizenIDs {
            guard Int(id.raw) < state.citizens.count else { continue }
            let citizen = state.citizens[Int(id.raw)]
            guard let home = citizen.home, let work = citizen.work,
                  Int(home.raw) < state.buildings.count, Int(work.raw) < state.buildings.count else { continue }
            let origin = state.buildings[Int(home.raw)].tile
            let destination = state.buildings[Int(work.raw)].tile
            let route = path(from: origin, to: destination, in: map)
            let offset = Double(UInt32(bitPattern: citizen.id.raw &* 7 &+ state.day &* 11) % 20)
            let t = (currentTime + offset).truncatingRemainder(dividingBy: 20)
            let progress = t < 8 ? t / 8 : (t < 10 ? 1 : (t < 18 ? 1 - (t - 10) / 8 : 0))
            citizenNodes[id]?.position = position(along: route, progress: progress, in: map)
        }
        for (raw, node) in ambientNodes {
            let base = point(for: TileIndex(raw), in: map)
            let drift = currentTime + Double(raw % 17)
            node.position = CGPoint(x: base.x + CGFloat(sin(drift * 0.8) * 9),
                                    y: base.y + CGFloat(cos(drift * 0.8) * 3))
        }
    }

    private func position(along path: [TileIndex], progress: Double, in map: WorldMap) -> CGPoint {
        guard let first = path.first else { return .zero }
        guard path.count > 1 else { return point(for: first, in: map) }
        let scaled = max(0, min(1, progress)) * Double(path.count - 1)
        let index = min(path.count - 2, Int(scaled))
        let a = point(for: path[index], in: map), b = point(for: path[index + 1], in: map)
        let part = CGFloat(scaled - Double(index))
        return CGPoint(x: a.x + (b.x - a.x) * part, y: a.y + (b.y - a.y) * part)
    }

    /// Presentation-only paths; the simulation's accessibility fields remain authoritative.
    private func path(from start: TileIndex, to end: TileIndex, in map: WorldMap) -> [TileIndex] {
        let key = RouteKey(from: start.raw, to: end.raw)
        if let cached = routeCache[key] { return cached }
        if start == end { return [start] }
        var queue = [start]
        var head = 0
        var parent: [Int32: Int32] = [start.raw: start.raw]
        while head < queue.count && parent[end.raw] == nil {
            let current = queue[head]
            head += 1
            for next in map.neighbours(of: current) where map.isPassable(next) && parent[next.raw] == nil {
                parent[next.raw] = current.raw
                queue.append(next)
            }
        }
        guard parent[end.raw] != nil else {
            routeCache[key] = [start]
            return [start]
        }
        var reverse = [end]
        var current = end.raw
        while current != start.raw {
            guard let previous = parent[current] else { break }
            current = previous
            reverse.append(TileIndex(current))
        }
        let result = Array(reverse.reversed())
        routeCache[key] = result
        return result
    }

    private func resizeNightLayer() {
        nightLayer.size = CGSize(width: size.width * 5, height: size.height * 5)
        nightLayer.position = .zero
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            touchStart = touch.location(in: self)
            wasDragged = false
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let active = (event?.allTouches ?? touches).filter { $0.phase == .moved || $0.phase == .stationary }
        if active.count >= 2 {
            let pair = Array(active.prefix(2))
            let p0 = pair[0].location(in: self), p1 = pair[1].location(in: self)
            let q0 = pair[0].previousLocation(in: self), q1 = pair[1].previousLocation(in: self)
            let oldDistance = hypot(q0.x - q1.x, q0.y - q1.y)
            let newDistance = hypot(p0.x - p1.x, p0.y - p1.y)
            if newDistance > 5 {
                cameraNode.setScale(max(0.55, min(2.6, cameraNode.xScale * oldDistance / newDistance)))
                refreshVisible()
            }
            wasDragged = true
        } else if let touch = touches.first {
            let p = touch.location(in: self), previous = touch.previousLocation(in: self)
            cameraNode.position.x -= p.x - previous.x
            cameraNode.position.y -= p.y - previous.y
            if let touchStart, hypot(p.x - touchStart.x, p.y - touchStart.y) > 8 { wasDragged = true }
            refreshVisible()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { touchStart = nil }
        guard !wasDragged, let state = renderedState, let touch = touches.first,
              let tile = tile(at: touch.location(in: self), in: state.map) else { return }
        onTileTap?(tile)
    }
}

private struct RouteKey: Hashable { let from: Int32; let to: Int32 }

private struct TileRect: Equatable {
    let x0: Int32, y0: Int32, x1: Int32, y1: Int32
    func contains(_ tile: TileIndex, in map: WorldMap) -> Bool {
        let x = map.x(of: tile), y = map.y(of: tile)
        return x >= x0 && x <= x1 && y >= y0 && y <= y1
    }
}

private extension TerrainKind {
    var color: UIColor {
        switch self {
        case .water: return UIColor(red: 0.09, green: 0.43, blue: 0.65, alpha: 1)
        case .sand: return UIColor(red: 0.78, green: 0.70, blue: 0.46, alpha: 1)
        case .grass: return UIColor(red: 0.32, green: 0.61, blue: 0.35, alpha: 1)
        case .fertile: return UIColor(red: 0.24, green: 0.51, blue: 0.28, alpha: 1)
        case .rock: return UIColor(red: 0.48, green: 0.50, blue: 0.48, alpha: 1)
        }
    }
}

private extension BuildingKind {
    var color: UIColor {
        switch self {
        case .townHall: return .systemYellow
        case .house: return .systemOrange
        case .farm: return .systemGreen
        case .market: return .systemPink
        case .clinic: return .systemRed
        case .school: return .systemTeal
        case .police: return .systemBlue
        case .workshop: return .brown
        case .dock: return .systemGray
        }
    }
}
