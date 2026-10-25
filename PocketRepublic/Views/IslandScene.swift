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
    private var citizenNodes: [CitizenID: SKSpriteNode] = [:]
    private var visibleCitizenIDs: [CitizenID] = []
    private var routines: [CitizenID: DailyRoutine] = [:]
    private var walkerFacing: [CitizenID: WalkerFacing] = [:]
    private var decoNodes: [Int32: SKSpriteNode] = [:]
    private let reachLayer = SKNode()
    private let ghostLayer = SKNode()
    private var placementKind: BuildingKind?
    private var hoverTile: TileIndex?
    private var lastGhostKey: GhostDrawKey?
    private var lastHint: String?
    private let tileTick = UISelectionFeedbackGenerator()
    var onPlacementHint: ((String?) -> Void)?
    private var tileTextures: [String: SKTexture] = [:]
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
        reachLayer.zPosition = 5
        buildingLayer.zPosition = 10
        selectionLayer.zPosition = 15
        ghostLayer.zPosition = 20
        peopleLayer.zPosition = 30
        addChild(terrainLayer)
        addChild(reachLayer)
        addChild(buildingLayer)
        addChild(selectionLayer)
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
           old.day != state.day || old.map.road != state.map.road || old.map.buildingAt != state.map.buildingAt {
            routines.removeAll()
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
                    let signature = MapArt.tileSignature(x: x, y: y, map: map)
                    if let node = tileNodes[tile.raw] {
                        if node.name != signature { configureTile(node, x: x, y: y, map: map, signature: signature) }
                    } else {
                        let node = SKSpriteNode()
                        node.size = MapArt.tileSize
                        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                        node.position = point(x: x, y: y)
                        configureTile(node, x: x, y: y, map: map, signature: signature)
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
        refreshDecorations(map: map, rect: rect)

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
        refreshSelection()
    }

    /// Highlights every tile `BuildingOccupancy` assigns to the building, not only its origin.
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

    private func configureTile(_ node: SKSpriteNode, x: Int32, y: Int32, map: WorldMap, signature: String) {
        let terrain = map.terrain(at: map.index(x: x, y: y))
        let groundName = MapArt.terrainName(terrain, x: x, y: y)
        node.texture = MapArt.texture(named: groundName) ?? proceduralTile(terrain, road: false)
        node.size = MapArt.tileSize
        node.removeAllChildren()
        if map.isRoad(at: map.index(x: x, y: y)) {
            let mask = MapArt.roadMask(x: x, y: y, map: map)
            let road = SKSpriteNode(texture: MapArt.texture(named: MapArt.roadNames[mask]) ?? proceduralTile(terrain, road: true),
                                    size: MapArt.tileSize)
            road.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            road.zPosition = 0.8
            node.addChild(road)
        }
        for name in MapArt.shoreNames(x: x, y: y, map: map) {
            guard let texture = MapArt.texture(named: name) else { continue }
            let shore = SKSpriteNode(texture: texture, size: MapArt.tileSize)
            shore.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            shore.zPosition = 0.4
            node.addChild(shore)
        }
        node.name = signature
    }

    private func refreshDecorations(map: WorldMap, rect: TileRect) {
        var wanted = Set<Int32>()
        if rect.x0 <= rect.x1 && rect.y0 <= rect.y1 {
            for y in rect.y0...rect.y1 {
                for x in rect.x0...rect.x1 {
                    let tile = map.index(x: x, y: y)
                    guard map.buildingAt(tile) == nil, !map.isRoad(at: tile),
                          let spec = MapArt.decoration(x: x, y: y, terrain: map.terrain(at: tile)),
                          let texture = MapArt.texture(named: spec.name) else { continue }
                    wanted.insert(tile.raw)
                    if decoNodes[tile.raw] == nil {
                        let node = SKSpriteNode(texture: texture, size: spec.size)
                        node.anchorPoint = spec.anchor
                        node.position = point(x: x, y: y)
                        node.zPosition = CGFloat(x + y) / 100
                        buildingLayer.addChild(node)
                        decoNodes[tile.raw] = node
                    }
                }
            }
        }
        for (raw, node) in decoNodes where !wanted.contains(raw) {
            node.removeFromParent()
            decoNodes.removeValue(forKey: raw)
        }
    }

    private func proceduralTile(_ terrain: TerrainKind, road: Bool) -> SKTexture {
        let key = "\(terrain.rawValue)-\(road)"
        if let existing = tileTextures[key] { return existing }
        let image = UIGraphicsImageRenderer(size: MapArt.tileSize).image { _ in
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
        let access = state.buildingAccess()
        var visible: [Citizen] = []
        visible.reserveCapacity(state.citizens.count)
        for citizen in state.citizens where citizen.alive {
            let routine = self.routine(for: citizen, in: state, access: access)
            let tiles = routine.path.isEmpty ? routine.entrances : routine.path
            guard tiles.contains(where: { rect.contains($0, in: map) }) else { continue }
            visible.append(citizen)
        }
        let wanted = Set(visible.map(\.id))
        visibleCitizenIDs = visible.map(\.id)
        for citizen in visible {
            let node: SKSpriteNode
            if let existing = citizenNodes[citizen.id] {
                node = existing
            } else {
                node = SKSpriteNode()
                node.size = MapArt.walkerSize
                node.anchorPoint = CGPoint(x: 0.5, y: 0)
                buildingLayer.addChild(node)
                citizenNodes[citizen.id] = node
            }
            if let routine = routines[citizen.id] {
                applyWalker(node, citizen: citizen, routine: routine, map: map, time: animationTime)
            }
        }
        for (id, node) in citizenNodes where !wanted.contains(id) {
            node.removeFromParent()
            citizenNodes.removeValue(forKey: id)
            walkerFacing.removeValue(forKey: id)
        }
    }

    private func routine(for citizen: Citizen, in state: RepublicState, access: MapBuildingAccess) -> DailyRoutine {
        if let cached = routines[citizen.id] { return cached }
        let planned = WalkerRoutine.plan(for: citizen, in: state, access: access)
        routines[citizen.id] = planned
        return planned
    }

    override func update(_ currentTime: TimeInterval) {
        guard let state = renderedState else { return }
        animationTime = currentTime
        let phase = (currentTime / 100 + Double(state.day % 3) / 3).truncatingRemainder(dividingBy: 1)
        nightLayer.alpha = CGFloat(0.07 + 0.25 * (1 - cos(phase * .pi * 2)) / 2)

        let map = state.map
        for id in visibleCitizenIDs {
            guard let node = citizenNodes[id], Int(id.raw) < state.citizens.count,
                  let routine = routines[id] else { continue }
            applyWalker(node, citizen: state.citizens[Int(id.raw)], routine: routine, map: map, time: currentTime)
        }
    }

    /// One simulated day has no clock of its own. While it stays paused, the scene
    /// plays `DailyRoutine` across 24 hours at two seconds each and slides the
    /// sprite along the core path between those hours.
    private func applyWalker(_ node: SKSpriteNode, citizen: Citizen, routine: DailyRoutine,
                             map: WorldMap, time: TimeInterval) {
        let localTime = time + walkerPhase(for: citizen.id)
        guard let pose = walkerPose(routine, at: localTime, map: map) else { return }
        node.position = pose.position
        node.zPosition = pose.sort
        let facing = pose.facing ?? walkerFacing[citizen.id] ?? .sw
        if pose.moving { walkerFacing[citizen.id] = facing }
        let frame = pose.moving ? Int(localTime / 0.15) % 2 : 0
        let variant = Int(UInt32(bitPattern: citizen.id.raw) % 6)
        node.texture = MapArt.walkerTexture(variant: variant, facing: facing, frame: frame) ?? proceduralWalker
        node.size = MapArt.walkerSize
        node.xScale = abs(node.xScale) * facing.xScale
        if citizen.daysHungry > 0 {
            node.color = MapArt.hungryOrange
            node.colorBlendFactor = 0.55
        } else {
            node.colorBlendFactor = 0
        }
    }

    /// A stable visual-only offset spreads arrivals across most of one simulated hour.
    /// The core routine and its hourly stops remain the same for every citizen.
    private func walkerPhase(for id: CitizenID) -> TimeInterval {
        let hash = UInt32(bitPattern: id.raw) &* 2_654_435_761
        return Double(hash >> 24) / 255 * MapArt.secondsPerHour * 0.75
    }

    private func walkerPose(_ routine: DailyRoutine, at time: TimeInterval, map: WorldMap) -> WalkerPose? {
        guard let fallback = routine.entrances.first ?? routine.path.first else { return nil }
        let hour = time.truncatingRemainder(dividingBy: MapArt.visualDay) / MapArt.secondsPerHour
        for i in routine.dwellStart.indices where i < routine.dwellEnd.count && i < routine.entrances.count {
            if hour >= Double(routine.dwellStart[i]) && hour < Double(routine.dwellEnd[i]) {
                return standing(routine.entrances[i], map: map)
            }
        }
        let legs = min(routine.legPaths.count, routine.entrances.count - 1)
        for i in 0..<legs where i < routine.dwellEnd.count && (i + 1) < routine.dwellStart.count {
            let leave = routine.dwellEnd[i]
            let arrive = routine.dwellStart[i + 1]
            guard hour >= Double(leave), hour < Double(arrive) else { continue }
            let span = Double(arrive - leave)
            let t = span > 0 ? (hour - Double(leave)) / span : 1
            return along(routine.legPaths[i], progress: t, map: map)
        }
        return standing(routine.entrances.last ?? fallback, map: map)
    }

    private func standing(_ tile: TileIndex, map: WorldMap) -> WalkerPose {
        let x = map.x(of: tile), y = map.y(of: tile)
        return WalkerPose(position: point(x: x, y: y), moving: false, facing: nil,
                          sort: CGFloat(x + y) / 100 + 0.02)
    }

    private func along(_ leg: [TileIndex], progress: Double, map: WorldMap) -> WalkerPose {
        guard let first = leg.first else { return standing(TileIndex(0), map: map) }
        guard leg.count > 1 else { return standing(first, map: map) }
        let scaled = max(0, min(0.999, progress)) * Double(leg.count - 1)
        let index = min(leg.count - 2, Int(scaled))
        let a = leg[index], b = leg[index + 1]
        let part = CGFloat(scaled - Double(index))
        let pa = point(for: a, in: map), pb = point(for: b, in: map)
        let dx = map.x(of: b) - map.x(of: a)
        let dy = map.y(of: b) - map.y(of: a)
        let frontX = max(map.x(of: a), map.x(of: b))
        let frontY = max(map.y(of: a), map.y(of: b))
        return WalkerPose(
            position: CGPoint(x: pa.x + (pb.x - pa.x) * part, y: pa.y + (pb.y - pa.y) * part),
            moving: true,
            facing: WalkerFacing.forStep(dx: dx, dy: dy),
            sort: CGFloat(frontX + frontY) / 100 + 0.02
        )
    }

    private var proceduralWalker: SKTexture {
        let key = "walker-dot"
        if let existing = tileTextures[key] { return existing }
        let image = UIGraphicsImageRenderer(size: MapArt.walkerSize).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 3, y: 8, width: 6, height: 6)).fill()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        tileTextures[key] = texture
        return texture
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
                               reason: reason, entrance: preview.entrance?.raw,
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

        guard kind.showsServiceReach, let entrance = preview.entrance else { return }
        let covered = Set(tiles.map(\.raw))
        let reach = ServiceReach.tiles(from: entrance,
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
    var entrance: Int32?
    var tileCount: Int
    var stamp: Int
}

private struct WalkerPose {
    var position: CGPoint
    var moving: Bool
    var facing: WalkerFacing?
    var sort: CGFloat
}

/// `ne` and `sw` are the drawn sheets. NW reuses `ne` flipped, SE reuses `sw` flipped.
private struct WalkerFacing {
    var side: String
    var xScale: CGFloat

    static let ne = WalkerFacing(side: "ne", xScale: 1)
    static let sw = WalkerFacing(side: "sw", xScale: 1)
    static let nw = WalkerFacing(side: "ne", xScale: -1)
    static let se = WalkerFacing(side: "sw", xScale: -1)

    /// Grid step under `IslandScene.point(x:y:)`. N (dy < 0) is up-right, E (dx > 0) is down-right.
    static func forStep(dx: Int32, dy: Int32) -> WalkerFacing {
        if dy < 0 { return .ne }
        if dx > 0 { return .se }
        if dy > 0 { return .sw }
        return .nw
    }
}

/// Names and sizes from `docs/art/road_autotile.json`, `decos.json`, and `docs/art/ASSETS.md`.
private enum MapArt {
    static let tileSize = CGSize(width: 64, height: 32)
    static let walkerSize = CGSize(width: 12, height: 18)
    static let secondsPerHour: TimeInterval = 2
    static var visualDay: TimeInterval { secondsPerHour * 24 }
    static let hungryOrange = UIColor(red: 242 / 255, green: 98 / 255, blue: 42 / 255, alpha: 1)

    /// Index is the neighbour bitmask. N=1, E=2, S=4, W=8, matching `road_autotile.json`.
    static let roadNames = [
        "road_single", "road_end_n", "road_end_e", "road_corner_ne",
        "road_end_s", "road_straight_ns", "road_corner_es", "road_t_nes",
        "road_end_w", "road_corner_wn", "road_straight_ew", "road_t_wne",
        "road_corner_sw", "road_t_swn", "road_t_esw", "road_cross"
    ]

    private static var textures: [String: SKTexture] = [:]

    static func texture(named name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
        guard let image = UIImage(named: name) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        textures[name] = texture
        return texture
    }

    static func mix(_ x: Int32, _ y: Int32) -> Int {
        let h = Int(x) &* 7_385_6093 ^ Int(y) &* 19_349_663
        return h < 0 ? -h : h
    }

    static func terrainName(_ terrain: TerrainKind, x: Int32, y: Int32) -> String {
        let count: Int
        let prefix: String
        switch terrain {
        case .grass: count = 4; prefix = "tile_grass"
        case .fertile: count = 4; prefix = "tile_fertile"
        case .sand: count = 4; prefix = "tile_sand"
        case .rock: count = 3; prefix = "tile_rock"
        case .water: count = 4; prefix = "tile_water"
        }
        return "\(prefix)_\(mix(x, y) % count)"
    }

    /// N (x, y−1) is up-right on screen and E (x+1, y) is down-right, the same axes as the art.
    static func roadMask(x: Int32, y: Int32, map: WorldMap) -> Int {
        var mask = 0
        if isRoad(x, y - 1, map) { mask |= 1 }
        if isRoad(x + 1, y, map) { mask |= 2 }
        if isRoad(x, y + 1, map) { mask |= 4 }
        if isRoad(x - 1, y, map) { mask |= 8 }
        return mask
    }

    static func tileSignature(x: Int32, y: Int32, map: WorldMap) -> String {
        let tile = map.index(x: x, y: y)
        let road = map.isRoad(at: tile) ? roadMask(x: x, y: y, map: map) : -1
        return "\(terrainName(map.terrain(at: tile), x: x, y: y))|\(road)|\(shoreNames(x: x, y: y, map: map).joined(separator: ","))"
    }

    static func shoreNames(x: Int32, y: Int32, map: WorldMap) -> [String] {
        guard map.terrain(at: map.index(x: x, y: y)) == .water else { return [] }
        var names: [String] = []
        if isLand(x, y - 1, map) { names.append("tile_shore_n") }
        if isLand(x + 1, y, map) { names.append("tile_shore_e") }
        if isLand(x, y + 1, map) { names.append("tile_shore_s") }
        if isLand(x - 1, y, map) { names.append("tile_shore_w") }
        if isLand(x + 1, y - 1, map), isWater(x, y - 1, map), isWater(x + 1, y, map) {
            names.append("tile_shore_corner_ne")
        }
        if isLand(x + 1, y + 1, map), isWater(x + 1, y, map), isWater(x, y + 1, map) {
            names.append("tile_shore_corner_se")
        }
        if isLand(x - 1, y + 1, map), isWater(x - 1, y, map), isWater(x, y + 1, map) {
            names.append("tile_shore_corner_sw")
        }
        if isLand(x - 1, y - 1, map), isWater(x, y - 1, map), isWater(x - 1, y, map) {
            names.append("tile_shore_corner_nw")
        }
        return names
    }

    struct Decoration {
        var name: String
        var size: CGSize
        var anchor: CGPoint
    }

    /// Sparse props on empty ground. The core does not store decoration tiles.
    /// Sizes and anchors are the `decos.json` entries.
    static func decoration(x: Int32, y: Int32, terrain: TerrainKind) -> Decoration? {
        let bucket = mix(x, y)
        let name: String
        switch terrain {
        case .sand:
            guard bucket % 9 == 0 else { return nil }
            name = "deco_palm_\((bucket / 9) % 3)"
        case .grass:
            guard bucket % 13 == 0 else { return nil }
            name = ["deco_bush_0", "deco_bush_1", "deco_flowers_0"][(bucket / 13) % 3]
        case .fertile:
            guard bucket % 17 == 0 else { return nil }
            name = ["deco_flowers_0", "deco_bush_0"][(bucket / 17) % 2]
        case .rock:
            guard bucket % 11 == 0 else { return nil }
            name = "deco_rock_\((bucket / 11) % 2)"
        case .water:
            return nil
        }
        guard let size = decoSizes[name] else { return nil }
        return Decoration(name: name, size: size, anchor: CGPoint(x: 0.5, y: 0))
    }

    private static let decoSizes: [String: CGSize] = [
        "deco_palm_0": CGSize(width: 52, height: 65),
        "deco_palm_1": CGSize(width: 44, height: 50),
        "deco_palm_2": CGSize(width: 52, height: 62),
        "deco_bush_0": CGSize(width: 38, height: 33),
        "deco_bush_1": CGSize(width: 38, height: 31),
        "deco_rock_0": CGSize(width: 40, height: 36),
        "deco_rock_1": CGSize(width: 34, height: 26),
        "deco_flowers_0": CGSize(width: 34, height: 22)
    ]

    static func walkerTexture(variant: Int, facing: WalkerFacing, frame: Int) -> SKTexture? {
        texture(named: "walker_\(variant)_\(facing.side)_f\(frame)")
    }

    private static func isRoad(_ x: Int32, _ y: Int32, _ map: WorldMap) -> Bool {
        guard map.contains(x: x, y: y) else { return false }
        return map.isRoad(at: map.index(x: x, y: y))
    }

    private static func isLand(_ x: Int32, _ y: Int32, _ map: WorldMap) -> Bool {
        guard map.contains(x: x, y: y) else { return false }
        return map.terrain(at: map.index(x: x, y: y)) != .water
    }

    private static func isWater(_ x: Int32, _ y: Int32, _ map: WorldMap) -> Bool {
        guard map.contains(x: x, y: y) else { return false }
        return map.terrain(at: map.index(x: x, y: y)) == .water
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
