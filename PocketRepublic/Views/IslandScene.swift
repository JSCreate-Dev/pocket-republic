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
    private var animationTime: TimeInterval = 0
    private var cameraInitialized = false
    private var cameraUserAdjusted = false
    private var framing: CameraFraming?
    private var touchStart: CGPoint?
    private var wasDragged = false
    private let selectionLayer = SKNode()
    private var selectionNodes: [Int32: SKShapeNode] = [:]
    private var selectedBuildingID: BuildingID?

    private let halfWidth: CGFloat = CGFloat(CityProjection.halfWidth)
    private let halfHeight: CGFloat = CGFloat(CityProjection.halfHeight)

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = UIColor(red: 0.05, green: 0.22, blue: 0.37, alpha: 1)
        isUserInteractionEnabled = true
        terrainLayer.zPosition = 0
        buildingLayer.zPosition = 10
        selectionLayer.zPosition = 15
        peopleLayer.zPosition = 30
        addChild(terrainLayer)
        addChild(buildingLayer)
        addChild(selectionLayer)
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
        if cameraInitialized && !cameraUserAdjusted { applyDefaultZoom() }
        clampCameraToMap()
        refreshVisible(force: true)
    }

    /// Keeps the same world point in the usable pane when the fold or orientation changes.
    func setFraming(_ next: CameraFraming) {
        guard framing != next else { return }
        let previous = framing
        let oldScale = cameraNode.xScale
        let worldAtFocus: CGPoint?
        if cameraInitialized, let previous {
            let oldX = previous.focusRect.midX - previous.viewSize.width / 2
            let oldY = previous.focusRect.midY - previous.viewSize.height / 2
            worldAtFocus = CGPoint(x: cameraNode.position.x + oldX * oldScale,
                                   y: cameraNode.position.y - oldY * oldScale)
        } else {
            worldAtFocus = nil
        }
        framing = next
        if cameraInitialized {
            if !cameraUserAdjusted { applyDefaultZoom() }
            if let worldAtFocus {
                let newX = next.focusRect.midX - next.viewSize.width / 2
                let newY = next.focusRect.midY - next.viewSize.height / 2
                cameraNode.position = CGPoint(x: worldAtFocus.x - newX * cameraNode.xScale,
                                              y: worldAtFocus.y + newY * cameraNode.yScale)
            }
            clampCameraToMap()
            refreshVisible(force: true)
        }
    }

    func render(_ state: RepublicState) {
        if let old = renderedState,
           old.map.road != state.map.road || old.map.buildingAt != state.map.buildingAt {
            routeCache.removeAll()
        }
        renderedState = state
        if !cameraInitialized {
            let middle = state.map.width / 2
            let worldCenter = point(x: middle, y: middle)
            applyDefaultZoom()
            if let framing {
                let x = framing.focusRect.midX - framing.viewSize.width / 2
                let y = framing.focusRect.midY - framing.viewSize.height / 2
                cameraNode.position = CGPoint(x: worldCenter.x - x * cameraNode.xScale,
                                              y: worldCenter.y + y * cameraNode.yScale)
            } else {
                cameraNode.position = worldCenter
            }
            cameraInitialized = true
        }
        clampCameraToMap()
        refreshVisible(force: true)
    }

    /// Default scale uses the usable world pane, never the full width across a fold.
    private func applyDefaultZoom() {
        let usableWidth = framing?.focusRect.width ?? size.width
        guard usableWidth > 0 else { return }
        let tilesAcross = framing?.tileWidths ?? 9
        cameraNode.setScale(max(0.55, min(2.6, tilesAcross * halfWidth * 2 / usableWidth)))
    }

    /// Keep at least part of the island inside the camera after a fold, rotation, or pan.
    private func clampCameraToMap() {
        guard let map = renderedState?.map else { return }
        let minX = -CGFloat(map.height - 1) * halfWidth
        let maxX = CGFloat(map.width - 1) * halfWidth
        let minY = -CGFloat(map.width + map.height - 2) * halfHeight
        let padX = size.width * cameraNode.xScale * 0.25
        let padY = size.height * cameraNode.yScale * 0.25
        cameraNode.position.x = min(max(cameraNode.position.x, minX - padX), maxX + padX)
        cameraNode.position.y = min(max(cameraNode.position.y, minY - padY), padY)
    }

    private func point(x: Int32, y: Int32) -> CGPoint {
        CGPoint(x: CGFloat(x - y) * halfWidth,
                y: -CGFloat(x + y) * halfHeight)
    }

    private func point(for tile: TileIndex, in map: WorldMap) -> CGPoint {
        point(x: map.x(of: tile), y: map.y(of: tile))
    }

    private func tile(at position: CGPoint, in map: WorldMap) -> TileIndex? {
        BuildingHitTest.tile(at: CityPoint(x: Double(position.x), y: Double(position.y)), in: map)
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
        refreshSelection()
    }

    /// Highlights every tile `buildingAt` assigns to the building, not only its origin.
    func setSelection(_ id: BuildingID?) {
        let pulse = id != nil && id != selectedBuildingID
        selectedBuildingID = id
        refreshSelection(pulse: pulse)
    }

    private func refreshSelection(pulse: Bool = false) {
        guard let state = renderedState else {
            for (_, node) in selectionNodes { node.removeFromParent() }
            selectionNodes.removeAll()
            return
        }
        let tiles = selectedBuildingID.map { BuildingHitTest.occupiedTiles($0, on: state.map) } ?? []
        let wanted = Set(tiles.map(\.raw))
        for tile in tiles where selectionNodes[tile.raw] == nil {
            let node = SKShapeNode(path: selectionDiamond())
            node.fillColor = UIColor.systemMint.withAlphaComponent(0.33)
            node.strokeColor = .white
            node.lineWidth = 2
            node.position = point(for: tile, in: state.map)
            node.zPosition = 1
            node.isUserInteractionEnabled = false
            selectionLayer.addChild(node)
            selectionNodes[tile.raw] = node
            if pulse {
                node.setScale(1.08)
                node.run(.scale(to: 1, duration: 0.12))
            }
        }
        for (raw, node) in selectionNodes where !wanted.contains(raw) {
            node.removeFromParent()
            selectionNodes.removeValue(forKey: raw)
        }
    }

    private func selectionDiamond() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: halfHeight))
        path.addLine(to: CGPoint(x: halfWidth, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -halfHeight))
        path.addLine(to: CGPoint(x: -halfWidth, y: 0))
        path.closeSubpath()
        return path
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
        // Retain already drawn walkers across small viewport changes. A route can
        // cross the view even when both its home and workplace lie outside it.
        let candidates = state.citizens.filter { citizen in
            guard citizen.alive, let home = citizen.home, let work = citizen.work,
                  Int(home.raw) < state.buildings.count, Int(work.raw) < state.buildings.count else { return false }
            return path(from: state.buildings[Int(home.raw)].tile,
                        to: state.buildings[Int(work.raw)].tile, in: map)
                .contains { rect.contains($0, in: map) }
        }
        let retained = candidates.filter { citizenNodes[$0.id] != nil }
        let newcomers = candidates.filter { citizenNodes[$0.id] == nil }
        let visible = Array((retained + newcomers).prefix(24))
        let wanted = Set(visible.map(\.id))
        visibleCitizenIDs = visible.map(\.id)
        for citizen in visible {
            if citizenNodes[citizen.id] == nil {
                let node = SKShapeNode(circleOfRadius: 3)
                node.fillColor = citizen.daysHungry > 0 ? .orange : .white
                node.strokeColor = .black
                node.lineWidth = 1
                peopleLayer.addChild(node)
                citizenNodes[citizen.id] = node
            }
            // Newly entered walkers start on their route, never at scene origin.
            citizenNodes[citizen.id]?.position = position(for: citizen, at: animationTime, in: state)
        }
        for (id, node) in citizenNodes where !wanted.contains(id) {
            node.removeFromParent()
            citizenNodes.removeValue(forKey: id)
        }

        // Sample roads by stable tile ID so panning cannot reshuffle every extra.
        let wantedAmbient = Set(tileNodes.keys.filter { raw in
            map.road[Int(raw)] && (UInt32(bitPattern: raw) &* 2_654_435_761) % 7 == 0
        })
        for raw in wantedAmbient where ambientNodes[raw] == nil {
            let node = SKShapeNode(circleOfRadius: 2)
            node.fillColor = .yellow
            node.strokeColor = .clear
            node.position = point(for: TileIndex(raw), in: map)
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
        animationTime = currentTime
        let phase = (currentTime / 100 + Double(state.day % 3) / 3).truncatingRemainder(dividingBy: 1)
        nightLayer.alpha = CGFloat(0.07 + 0.25 * (1 - cos(phase * .pi * 2)) / 2)

        for id in visibleCitizenIDs {
            guard Int(id.raw) < state.citizens.count else { continue }
            let citizen = state.citizens[Int(id.raw)]
            guard let home = citizen.home, let work = citizen.work,
                  Int(home.raw) < state.buildings.count, Int(work.raw) < state.buildings.count else { continue }
            citizenNodes[id]?.position = position(for: citizen, at: currentTime, in: state)
        }
        for (raw, node) in ambientNodes {
            let base = point(for: TileIndex(raw), in: map)
            let drift = currentTime + Double(raw % 17)
            node.position = CGPoint(x: base.x + CGFloat(sin(drift * 0.8) * 9),
                                    y: base.y + CGFloat(cos(drift * 0.8) * 3))
        }
    }

    private func position(for citizen: Citizen, at time: TimeInterval, in state: RepublicState) -> CGPoint {
        guard let home = citizen.home, let work = citizen.work,
              Int(home.raw) < state.buildings.count, Int(work.raw) < state.buildings.count else { return .zero }
        let route = path(from: state.buildings[Int(home.raw)].tile,
                         to: state.buildings[Int(work.raw)].tile, in: state.map)
        let offset = Double(UInt32(bitPattern: citizen.id.raw &* 7 &+ state.day &* 11) % 20)
        let t = (time + offset).truncatingRemainder(dividingBy: 20)
        let progress = t < 8 ? t / 8 : (t < 10 ? 1 : (t < 18 ? 1 - (t - 10) / 8 : 0))
        return position(along: route, progress: progress, in: state.map)
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
                cameraUserAdjusted = true
                clampCameraToMap()
                refreshVisible()
            }
            wasDragged = true
        } else if let touch = touches.first {
            let p = touch.location(in: self), previous = touch.previousLocation(in: self)
            cameraNode.position.x -= p.x - previous.x
            cameraNode.position.y -= p.y - previous.y
            cameraUserAdjusted = true
            clampCameraToMap()
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

struct CameraFraming: Equatable {
    let viewSize: CGSize
    let focusRect: CGRect
    let tileWidths: CGFloat
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
