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
    private let reachLayer = SKNode()
    private let ghostLayer = SKNode()
    private var placementKind: BuildingKind?
    private var hoverTile: TileIndex?
    private var lastGhostKey: GhostDrawKey?
    private var lastHint: String?
    private let tileTick = UISelectionFeedbackGenerator()
    var onPlacementHint: ((String?) -> Void)?
    private var tileTextures: [String: SKTexture] = [:]
    private var routeCache: [RouteKey: [TileIndex]] = [:]
    private var visibleRect: TileRect?
    private var animationTime: TimeInterval = 0
    private var cameraInitialized = false
    private var cameraUserAdjusted = false
    private var framing: CameraFraming?
    private var touchStart: CGPoint?
    private var wasDragged = false

    private let halfWidth: CGFloat = 32
    private let halfHeight: CGFloat = 16

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = UIColor(red: 0.05, green: 0.22, blue: 0.37, alpha: 1)
        isUserInteractionEnabled = true
        terrainLayer.zPosition = 0
        reachLayer.zPosition = 5
        buildingLayer.zPosition = 10
        ghostLayer.zPosition = 20
        peopleLayer.zPosition = 30
        addChild(terrainLayer)
        addChild(reachLayer)
        addChild(buildingLayer)
        addChild(ghostLayer)
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
        tileTick.prepare()
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
        refreshPlacementGhost()
    }

    /// Building tool for the placement ghost. `fallbackHover` is used only until
    /// a finger chooses a tile.
    func setPlacementKind(_ kind: BuildingKind?, fallbackHover: TileIndex?) {
        var changed = placementKind != kind
        placementKind = kind
        if kind == nil {
            if hoverTile != nil { changed = true }
            hoverTile = nil
        } else if hoverTile == nil, let fallbackHover {
            hoverTile = fallbackHover
            changed = true
        }
        if changed { refreshPlacementGhost() }
    }

    /// Drop the ghost after a building lands so the new sprite is not covered by a red "occupied" preview.
    func hidePlacementGhost() {
        guard hoverTile != nil else { return }
        hoverTile = nil
        refreshPlacementGhost()
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

        let buildingRect = rect.expanded(by: 16, map: map)
        var wantedBuildings = Set<BuildingID>()
        let footprints = CityFootprints.current
        for building in state.buildings {
            let covered = footprints.tilesCovered(by: building, on: map)
            guard let anchor = covered.first,
                  footprints.buildingID(at: anchor, on: map) == building.id,
                  let layout = IsoFootprintLayout.make(tiles: covered, map: map),
                  covered.contains(where: { buildingRect.contains($0, in: map) }) else { continue }
            wantedBuildings.insert(building.id)
            if buildingNodes[building.id] == nil {
                let node = BuildingArtwork.makeNode(kind: building.kind)
                node.position = layout.southCorner(halfWidth: halfWidth, halfHeight: halfHeight)
                node.zPosition = layout.frontSort / 100
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

    private func updateHover(at location: CGPoint) {
        guard placementKind != nil, let map = renderedState?.map else { return }
        let next = tile(at: location, in: map)
        guard next != hoverTile else { return }
        hoverTile = next
        if next != nil {
            tileTick.selectionChanged()
            tileTick.prepare()
        }
        refreshPlacementGhost()
    }

    private func refreshPlacementGhost() {
        guard let kind = placementKind, let origin = hoverTile, let state = renderedState else {
            clearGhost()
            return
        }
        let preview = CityFootprints.current.placementGhost(of: kind, at: origin, in: state)
        let accepted: Bool
        let reason: String?
        switch preview.result {
        case .accepted:
            accepted = true
            reason = nil
        case .rejected(let rejection):
            accepted = false
            reason = rejection.playerFacingReason
        }
        let key = GhostDrawKey(kind: kind.rawValue, origin: origin.raw, accepted: accepted,
                               reason: reason, entrance: preview.entrance.raw,
                               tileCount: preview.tiles.count, stamp: placementStamp(state))
        if key == lastGhostKey { return }
        lastGhostKey = key
        if reason != lastHint {
            lastHint = reason
            onPlacementHint?(reason)
        }

        ghostLayer.removeAllChildren()
        reachLayer.removeAllChildren()
        let map = state.map
        var tiles = preview.tiles
        if tiles.isEmpty { tiles = [origin] }
        guard let layout = IsoFootprintLayout.make(tiles: tiles, map: map) else { return }

        let tint = accepted
            ? UIColor(red: 0.22, green: 0.78, blue: 0.32, alpha: 1)
            : UIColor(red: 0.90, green: 0.22, blue: 0.20, alpha: 1)
        let markerSize = CGSize(width: halfWidth * 2, height: halfHeight * 2)
        let markerTexture = BuildingArtwork.tileMarkerTexture(size: markerSize)
        for tile in tiles {
            let marker = SKSpriteNode(texture: markerTexture, size: markerSize)
            marker.color = tint
            marker.colorBlendFactor = 0.9
            marker.alpha = 0.5
            marker.position = point(for: tile, in: map)
            ghostLayer.addChild(marker)
        }

        let ghost = BuildingArtwork.makeNode(kind: kind)
        ghost.color = tint
        ghost.colorBlendFactor = 0.55
        ghost.alpha = 0.82
        ghost.position = layout.southCorner(halfWidth: halfWidth, halfHeight: halfHeight)
        ghost.zPosition = 1
        ghostLayer.addChild(ghost)

        if let reason {
            let badge = reasonBadge(reason)
            let height = BuildingSpriteCatalog.spec(for: kind).pointSize.height
            badge.position = CGPoint(x: ghost.position.x, y: ghost.position.y + height + 16)
            badge.zPosition = 2
            ghostLayer.addChild(badge)
        }

        guard kind.showsServiceReach else { return }
        let covered = Set(tiles.map(\.raw))
        let reach = ServiceReach.tiles(from: preview.entrance,
                                       maxDistance: state.config.maxServiceDistance,
                                       on: map)
        for tile in reach where !covered.contains(tile.raw) {
            let node = SKSpriteNode(texture: markerTexture, size: markerSize)
            node.color = UIColor(red: 0.98, green: 0.78, blue: 0.22, alpha: 1)
            node.colorBlendFactor = 1
            node.alpha = 0.30
            node.position = point(for: tile, in: map)
            node.zPosition = CGFloat(map.x(of: tile) + map.y(of: tile)) / 100
            reachLayer.addChild(node)
        }
    }

    private func clearGhost() {
        ghostLayer.removeAllChildren()
        reachLayer.removeAllChildren()
        lastGhostKey = nil
        guard lastHint != nil else { return }
        lastHint = nil
        onPlacementHint?(nil)
    }

    private func placementStamp(_ state: RepublicState) -> Int {
        var hash = state.pending == nil ? 17 : 31
        hash = hash &* 33 &+ Int(truncatingIfNeeded: state.treasury)
        for flag in state.map.road {
            hash = hash &* 33 &+ (flag ? 1 : 0)
        }
        for id in state.map.buildingAt {
            hash = hash &* 33 &+ Int(id)
        }
        return hash
    }

    private func reasonBadge(_ text: String) -> SKNode {
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        let width = max(label.frame.width + 16, 44)
        let height = max(label.frame.height + 10, 22)
        let badge = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 7)
        badge.fillColor = UIColor(white: 0.08, alpha: 0.82)
        badge.strokeColor = UIColor.white.withAlphaComponent(0.25)
        badge.lineWidth = 1
        badge.addChild(label)
        return badge
    }

    private func resizeNightLayer() {
        nightLayer.size = CGSize(width: size.width * 5, height: size.height * 5)
        nightLayer.position = .zero
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            touchStart = location
            wasDragged = false
            updateHover(at: location)
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
        if let touch = touches.first {
            updateHover(at: touch.location(in: self))
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

    func expanded(by pad: Int32, map: WorldMap) -> TileRect {
        TileRect(x0: max(0, x0 - pad), y0: max(0, y0 - pad),
                 x1: min(map.width - 1, x1 + pad), y1: min(map.height - 1, y1 + pad))
    }
}

private struct GhostDrawKey: Equatable {
    var kind: UInt8
    var origin: Int32
    var accepted: Bool
    var reason: String?
    var entrance: Int32
    var tileCount: Int
    var stamp: Int
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
