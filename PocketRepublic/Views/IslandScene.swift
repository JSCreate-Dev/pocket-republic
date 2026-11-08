import SpriteKit
import UIKit
import PocketRepublicCore

/// A disposable picture of the core state. No SpriteKit node is saved or simulated.
final class IslandScene: SKScene {
    var onTileTap: ((TileIndex) -> Void)?

    private let terrainLayer = SKNode()
    private let shadowLayer = SKNode()
    private var buildingShadows: [BuildingID: SKSpriteNode] = [:]
    private let buildingLayer = SKNode()
    private let overlayLayer = SKNode()
    private var overlayMode: MapOverlayMode = .standard
    private var overlaySnapshot: MapOverlaySnapshot?
    private var overlayNodes: [Int32: SKSpriteNode] = [:]
    private var overlayMarker: SKTexture?
    private let peopleLayer = SKNode()
    private let cameraNode = SKCameraNode()
    private let nightLayer = SKSpriteNode(color: UIColor(red: 0.06, green: 0.10, blue: 0.22, alpha: 1), size: .zero)
    private let sunlightLayer = SKSpriteNode(color: UIColor(red: 1, green: 0.65, blue: 0.28, alpha: 1), size: .zero)
    private let vignetteLayer = SKSpriteNode()
    private let entryLightLayer = SKNode()
    private var entryLights: [BuildingID: SKSpriteNode] = [:]
    private var lightingElapsed: TimeInterval = 0
    private var previousLightingFrame: TimeInterval?
    private var previousLightingUpdate: TimeInterval = -.infinity
    private var reducedLightingMotion = UIAccessibility.isReduceMotionEnabled
    private var renderedState: RepublicState?
    private var tileNodes: [Int32: SKSpriteNode] = [:]
    private var buildingNodes: [BuildingID: SKNode] = [:]
    /// What the player has already been shown. Effects key off this, not off redraws.
    private var siteVisuals: [BuildingID: SiteVisual] = [:]
    private var siteLayouts: [BuildingID: IsoFootprintLayout] = [:]
    private var presentedSeed: UInt64?
    private var presentationPrimed = false
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
    var onHoverTile: ((TileIndex?) -> Void)?
    var onRoadTile: ((TileIndex) -> Void)?
    var roadDrawing = false
    private var roadPreview: [(tile: TileIndex, accepted: Bool)] = []
    private var inspectEntrance: TileIndex?
    private var tileTextures: [String: SKTexture] = [:]
    private var visibleRect: TileRect?
    private var animationTime: TimeInterval = 0
    private var cameraInitialized = false
    private var cameraUserAdjusted = false
    private var framing: CameraFraming?
    private var touchStart: CGPoint?
    private var hoverBeforeGesture: TileIndex?
    private var gesture = MapGesturePolicy()
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
        shadowLayer.zPosition = 2
        entryLightLayer.zPosition = 3
        entryLightLayer.alpha = 0
        overlayLayer.zPosition = 4
        buildingLayer.zPosition = 10
        selectionLayer.zPosition = 15
        ghostLayer.zPosition = 20
        peopleLayer.zPosition = 30
        addChild(terrainLayer)
        addChild(shadowLayer)
        addChild(entryLightLayer)
        addChild(overlayLayer)
        addChild(reachLayer)
        addChild(buildingLayer)
        addChild(selectionLayer)
        addChild(ghostLayer)
        addChild(peopleLayer)
        addChild(cameraNode)
        camera = cameraNode
        sunlightLayer.zPosition = 95
        sunlightLayer.blendMode = .add
        sunlightLayer.alpha = 0.035
        cameraNode.addChild(sunlightLayer)
        vignetteLayer.texture = Self.radialTexture(vignette: true)
        vignetteLayer.zPosition = 101
        vignetteLayer.alpha = 0.08
        cameraNode.addChild(vignetteLayer)
        nightLayer.zPosition = 100
        nightLayer.alpha = 0.02
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
        if presentedSeed != state.worldSeed {
            resetConstructionPresentation()
            lightingElapsed = 0
            previousLightingFrame = nil
            previousLightingUpdate = -.infinity
            routines.removeAll()
            selectedBuildingID = nil
            presentedSeed = state.worldSeed
            cameraInitialized = false
            cameraUserAdjusted = false
        }
        noteConstruction(in: state)
        renderedState = state
        overlaySnapshot = overlayMode == .standard ? nil : MapOverlaySnapshot(mode: overlayMode, state: state)
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
        drawRoadPreview()
        drawInspectReach()
    }

    func setRoadPreview(_ marks: [(tile: TileIndex, accepted: Bool)]) {
        roadPreview = marks
        if placementKind == nil { drawRoadPreview() }
    }

    func showInspectReach(from entrance: TileIndex?) {
        inspectEntrance = entrance
        if placementKind == nil { drawInspectReach() }
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
            siteLayouts[building.id] = layout
            presentBuilding(building, layout: layout, config: state.config)
            presentShadow(building, layout: layout, config: state.config)
            presentEntryLight(building, map: map)
        }
        let goneBuildings = buildingNodes.keys.filter { !wantedBuildings.contains($0) }
        for id in goneBuildings {
            buildingNodes[id]?.removeFromParent()
            buildingNodes.removeValue(forKey: id)
            buildingShadows.removeValue(forKey: id)?.removeFromParent()
            entryLights.removeValue(forKey: id)?.removeFromParent()
            siteLayouts.removeValue(forKey: id)
        }
        refreshPeople(state: state, rect: rect)
        refreshSelection()
        drawOverlay(state: state)
    }

    func setOverlay(_ mode: MapOverlayMode) {
        guard overlayMode != mode else { return }
        overlayMode = mode
        overlaySnapshot = renderedState.flatMap { mode == .standard ? nil : MapOverlaySnapshot(mode: mode, state: $0) }
        let diagnostic = mode != .standard
        buildingLayer.alpha = diagnostic ? 0.65 : 1
        terrainLayer.alpha = diagnostic ? 0.7 : 1
        peopleLayer.alpha = diagnostic ? 0.75 : 1
        nightLayer.isHidden = diagnostic
        sunlightLayer.isHidden = diagnostic
        vignetteLayer.isHidden = diagnostic
        entryLightLayer.isHidden = diagnostic
        shadowLayer.isHidden = diagnostic
        refreshVisible(force: true)
    }

    private func drawOverlay(state: RepublicState) {
        guard overlayMode != .standard, let overlaySnapshot else {
            overlayLayer.removeAllChildren()
            overlayNodes.removeAll()
            return
        }
        if overlayMarker == nil { overlayMarker = BuildingArtwork.tileMarkerTexture(size: MapArt.tileSize) }
        let wanted = Set(tileNodes.keys.filter { state.map.terrain(at: TileIndex($0)) != .water })
        for raw in wanted {
            let tile = TileIndex(raw)
            let score = overlaySnapshot.value(at: tile)
            let node: SKSpriteNode
            if let existing = overlayNodes[raw] { node = existing }
            else {
                node = SKSpriteNode(texture: overlayMarker, size: MapArt.tileSize)
                node.isUserInteractionEnabled = false
                node.colorBlendFactor = 1
                node.position = point(for: tile, in: state.map)
                overlayNodes[raw] = node
                overlayLayer.addChild(node)
            }
            node.color = overlayColor(score)
            node.alpha = score == nil ? 0.2 : 0.58
        }
        for raw in overlayNodes.keys.filter({ !wanted.contains($0) }) {
            overlayNodes.removeValue(forKey: raw)?.removeFromParent()
        }
    }

    private func overlayColor(_ score: Int16?) -> UIColor {
        guard let score else { return UIColor(white: 0.55, alpha: 1) }
        if overlayMode == .fertility {
            return score == 100 ? UIColor(red: 0.22, green: 0.85, blue: 0.38, alpha: 1)
                : UIColor(red: 0.65, green: 0.48, blue: 0.27, alpha: 1)
        }
        if overlayMode == .foodAccess {
            if score == 100 { return UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1) }
            return score > 0 ? UIColor(red: 0.95, green: 0.68, blue: 0.2, alpha: 1)
                : UIColor(red: 0.9, green: 0.25, blue: 0.18, alpha: 1)
        }
        let t = CGFloat(max(0, min(100, Int(score)))) / 100
        if t < 0.5 {
            return UIColor(red: 0.9, green: 0.25 + t * 0.9, blue: 0.18, alpha: 1)
        }
        return UIColor(red: 0.9 - (t - 0.5) * 1.4, green: 0.7 + (t - 0.5) * 0.2,
                       blue: 0.18 + (t - 0.5) * 0.44, alpha: 1)
    }

    /// A new city, or the first picture of a loaded save, must not replay pops.
    private func resetConstructionPresentation() {
        for (_, node) in buildingNodes { node.removeFromParent() }
        buildingNodes.removeAll()
        shadowLayer.removeAllChildren()
        buildingShadows.removeAll()
        entryLightLayer.removeAllChildren()
        entryLights.removeAll()
        siteLayouts.removeAll()
        siteVisuals.removeAll()
        presentationPrimed = false
    }

    /// Records which sites exist. The first picture of a city is quiet: worldgen
    /// buildings and a loaded save are already whatever stage the core says.
    private func noteConstruction(in state: RepublicState) {
        var live = Set<BuildingID>()
        if !presentationPrimed {
            for building in state.buildings {
                live.insert(building.id)
                siteVisuals[building.id] = SiteVisual(
                    displayed: nil,
                    sawSite: building.isUnderConstruction,
                    quiet: true
                )
            }
            presentationPrimed = true
        } else {
            for building in state.buildings {
                live.insert(building.id)
                if var visual = siteVisuals[building.id] {
                    if building.isUnderConstruction { visual.sawSite = true }
                    siteVisuals[building.id] = visual
                } else {
                    siteVisuals[building.id] = SiteVisual(
                        displayed: nil,
                        sawSite: building.isUnderConstruction,
                        quiet: false
                    )
                }
            }
        }
        let staleSites = siteVisuals.keys.filter { !live.contains($0) }
        for id in staleSites {
            siteVisuals.removeValue(forKey: id)
        }
    }

    /// Shows the sprite that matches `building.stage`. A transition plays once
    /// per stage change. Panning, folding, and `render` do not start it again.
    private func presentBuilding(_ building: Building, layout: IsoFootprintLayout, config: BalanceConfig) {
        let stage = building.stage(in: config)
        var visual = siteVisuals[building.id] ?? SiteVisual(displayed: nil, sawSite: building.isUnderConstruction, quiet: true)
        let hadNode = buildingNodes[building.id] != nil
        let container = buildingContainer(building.id, layout: layout)
        let stageChanged = visual.displayed != nil && visual.displayed != stage
        let firstShow = visual.displayed == nil

        if visual.quiet {
            installBody(stage, kind: building.kind, on: container, dimmed: stage != .complete)
            visual.quiet = false
            visual.displayed = stage
        } else if stageChanged && hadNode {
            if stage == .complete && visual.sawSite {
                installBody(stage, kind: building.kind, on: container, dimmed: false)
                playCompletionPop(on: container)
            } else if stage == .scaffold, visual.displayed == .foundation {
                crossfadeBody(to: stage, kind: building.kind, on: container)
            } else {
                installBody(stage, kind: building.kind, on: container, dimmed: stage != .complete)
            }
            visual.displayed = stage
        } else if firstShow {
            installBody(stage, kind: building.kind, on: container, dimmed: stage != .complete)
            if stage == .complete && visual.sawSite {
                playCompletionPop(on: container)
            } else if stage != .complete || building.daysRequired == 0 {
                playPlacementLand(on: container)
            }
            visual.displayed = stage
        } else if !hadNode {
            installBody(stage, kind: building.kind, on: container, dimmed: stage != .complete)
            if stageChanged, stage == .complete, visual.sawSite {
                playCompletionPop(on: container)
            }
            visual.displayed = stage
        }
        if building.isUnderConstruction { visual.sawSite = true }
        siteVisuals[building.id] = visual
        configureCrew(on: container, stage: visual.displayed ?? stage, kind: building.kind)
    }

    private func presentShadow(_ building: Building, layout: IsoFootprintLayout, config: BalanceConfig) {
        let stage = building.stage(in: config)
        let key = "\(stage)"
        let shadow: SKSpriteNode
        if let existing = buildingShadows[building.id], existing.name == key { shadow = existing }
        else {
            buildingShadows[building.id]?.removeFromParent()
            shadow = BuildingArtwork.makeGroundShadow(kind: building.kind, stage: stage)
            shadow.name = key
            buildingShadows[building.id] = shadow
            shadowLayer.addChild(shadow)
        }
        shadow.position = layout.southCorner(halfWidth: halfWidth, halfHeight: halfHeight)
        shadow.alpha = stage == .complete ? 1 : 0.55
    }

    private func buildingContainer(_ id: BuildingID, layout: IsoFootprintLayout) -> SKNode {
        if let existing = buildingNodes[id] {
            existing.position = layout.southCorner(halfWidth: halfWidth, halfHeight: halfHeight)
            existing.zPosition = layout.frontSort / 100
            return existing
        }
        let container = SKNode()
        container.position = layout.southCorner(halfWidth: halfWidth, halfHeight: halfHeight)
        container.zPosition = layout.frontSort / 100
        container.isUserInteractionEnabled = false
        buildingLayer.addChild(container)
        buildingNodes[id] = container
        return container
    }

    private func installBody(_ stage: ConstructionStage, kind: BuildingKind, on container: SKNode, dimmed: Bool) {
        container.childNode(withName: "outgoing")?.removeFromParent()
        container.childNode(withName: "body")?.removeFromParent()
        let body = BuildingArtwork.makeNode(kind: kind, stage: stage)
        body.name = "body"
        body.alpha = dimmed ? 0.94 : 1
        body.zPosition = 0
        container.addChild(body)
    }

    /// Foundation to scaffold. About 0.2s, dust at the base, no haptic.
    private func crossfadeBody(to stage: ConstructionStage, kind: BuildingKind, on container: SKNode) {
        if let current = container.childNode(withName: "body") {
            current.name = "outgoing"
            current.removeAllActions()
            current.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
        let body = BuildingArtwork.makeNode(kind: kind, stage: stage)
        body.name = "body"
        body.alpha = 0
        body.zPosition = 0
        container.addChild(body)
        body.run(.fadeAlpha(to: 0.94, duration: 0.2))
        puffDust(on: container, scale: 1.15)
    }

    /// The opening. Plays once, then `displayed` stays `.complete`.
    private func playCompletionPop(on container: SKNode) {
        guard let body = container.childNode(withName: "body") else { return }
        body.removeAction(forKey: "pop")
        body.setScale(0.85)
        body.alpha = 1
        body.run(.sequence([
            .scale(to: 1.06, duration: 0.14),
            .scale(to: 1.0, duration: 0.11)
        ]), withKey: "pop")
        puffDust(on: container, scale: 1.7)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// The foundation (or an instant open) landing under the finger.
    private func playPlacementLand(on container: SKNode) {
        guard let body = container.childNode(withName: "body") else { return }
        body.removeAction(forKey: "land")
        body.setScale(0.9)
        body.run(.sequence([
            .scale(to: 1.05, duration: 0.12),
            .scale(to: 1.0, duration: 0.08)
        ]), withKey: "land")
        puffDust(on: container, scale: 1.05)
    }

    private func puffDust(on container: SKNode, scale: CGFloat) {
        container.childNode(withName: "dust")?.removeFromParent()
        let dust = SKShapeNode(circleOfRadius: 18)
        dust.name = "dust"
        dust.fillColor = UIColor(red: 0.72, green: 0.62, blue: 0.42, alpha: 0.45)
        dust.strokeColor = .clear
        dust.position = CGPoint(x: 0, y: 10)
        dust.zPosition = 2
        dust.setScale(0.35)
        container.addChild(dust)
        dust.run(.sequence([
            .group([
                .scale(to: scale, duration: 0.28),
                .fadeOut(withDuration: 0.28)
            ]),
            .removeFromParent()
        ]))
    }

    /// Two decorative builders and a pennant on a scaffold. They are not citizens.
    private func configureCrew(on container: SKNode, stage: ConstructionStage, kind: BuildingKind) {
        if stage != .scaffold {
            container.childNode(withName: "crew")?.removeFromParent()
            container.childNode(withName: "pennant")?.removeFromParent()
            return
        }
        if container.childNode(withName: "crew") == nil {
            let crew = SKNode()
            crew.name = "crew"
            crew.zPosition = 1
            for index in 0..<2 {
                let walker = SKSpriteNode()
                walker.size = CGSize(width: 14, height: 22)
                walker.anchorPoint = CGPoint(x: 0.5, y: 0)
                walker.name = "builder-\(index)"
                crew.addChild(walker)
            }
            container.addChild(crew)
        }
        if container.childNode(withName: "pennant") == nil {
            let cloth = SKShapeNode(path: pennantPath())
            cloth.name = "pennant"
            cloth.fillColor = UIColor(red: 0.82, green: 0.33, blue: 0.18, alpha: 0.95)
            cloth.strokeColor = UIColor(white: 0.2, alpha: 0.4)
            cloth.lineWidth = 0.5
            let height = SiteSpriteCatalog.spec(kind: kind, stage: .scaffold).size.height
            cloth.position = CGPoint(x: 10, y: height * 0.72)
            cloth.zPosition = 3
            container.addChild(cloth)
        }
    }

    private func pennantPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 16))
        path.addLine(to: CGPoint(x: 11, y: 11))
        path.closeSubpath()
        return path
    }

    private func stepCrew(time: TimeInterval) {
        for (id, container) in buildingNodes {
            guard let crew = container.childNode(withName: "crew"),
                  let layout = siteLayouts[id] else { continue }
            let loop = footprintLoop(layout)
            guard loop.count >= 2 else { continue }
            let period: TimeInterval = 7
            let phase = Double(UInt32(bitPattern: id.raw) % 100) / 100
            for index in 0..<2 {
                guard let walker = crew.childNode(withName: "builder-\(index)") as? SKSpriteNode else { continue }
                let offset = Double(index) * 0.5
                let t = ((time / period) + phase + offset).truncatingRemainder(dividingBy: 1)
                let pose = pointOnLoop(loop, t: t < 0 ? t + 1 : t)
                walker.position = pose.point
                walker.xScale = pose.facing.xScale
                let frame = Int(time / 0.18) % 2
                walker.texture = MapArt.walkerTexture(variant: index, facing: pose.facing, frame: frame) ?? proceduralWalker
            }
            if let pennant = container.childNode(withName: "pennant") {
                pennant.zRotation = sin(time * 2.4 + phase * 6) * 0.22
            }
        }
    }

    private func footprintLoop(_ layout: IsoFootprintLayout) -> [CGPoint] {
        let origin = layout.southCorner(halfWidth: halfWidth, halfHeight: halfHeight)
        let corners = [
            diamondTip(.south, x: layout.maxX, y: layout.maxY),
            diamondTip(.east, x: layout.maxX, y: layout.minY),
            diamondTip(.north, x: layout.minX, y: layout.minY),
            diamondTip(.west, x: layout.minX, y: layout.maxY)
        ]
        return corners.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
    }

    private enum DiamondTip { case north, east, south, west }

    private func diamondTip(_ tip: DiamondTip, x: Int32, y: Int32) -> CGPoint {
        let center = point(x: x, y: y)
        switch tip {
        case .north: return CGPoint(x: center.x, y: center.y + halfHeight)
        case .east: return CGPoint(x: center.x + halfWidth, y: center.y)
        case .south: return CGPoint(x: center.x, y: center.y - halfHeight)
        case .west: return CGPoint(x: center.x - halfWidth, y: center.y)
        }
    }

    private func pointOnLoop(_ loop: [CGPoint], t: Double) -> (point: CGPoint, facing: WalkerFacing) {
        let scaled = t * Double(loop.count)
        let index = min(loop.count - 1, Int(scaled))
        let next = (index + 1) % loop.count
        let part = CGFloat(scaled - Double(index))
        let a = loop[index]
        let b = loop[next]
        let point = CGPoint(x: a.x + (b.x - a.x) * part, y: a.y + (b.y - a.y) * part)
        let facing: WalkerFacing
        if b.x >= a.x && b.y >= a.y { facing = .ne }
        else if b.x >= a.x { facing = .se }
        else if b.y < a.y { facing = .sw }
        else { facing = .nw }
        return (point, facing)
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
        node.removeAction(forKey: "water-ripple")
        node.texture = MapArt.texture(named: groundName) ?? proceduralTile(terrain, road: false)
        switch terrain {
        case .water: node.color = UIColor(red: 0.08, green: 0.62, blue: 0.66, alpha: 1)
        case .sand: node.color = UIColor(red: 0.96, green: 0.78, blue: 0.48, alpha: 1)
        case .grass, .fertile: node.color = UIColor(red: 0.72, green: 0.76, blue: 0.38, alpha: 1)
        case .rock: node.color = UIColor(red: 0.72, green: 0.65, blue: 0.53, alpha: 1)
        }
        node.colorBlendFactor = terrain == .water ? 0.12 : 0.07
        if terrain == .water, !UIAccessibility.isReduceMotionEnabled,
           let first = MapArt.texture(named: groundName), let next = MapArt.texture(named: "\(groundName)_f1") {
            let delay = Double(MapArt.mix(x, y) % 4) * 0.22
            node.run(.sequence([.wait(forDuration: delay),
                                .repeatForever(.animate(with: [first, next], timePerFrame: 0.95, resize: false, restore: true))]),
                     withKey: "water-ripple")
        }
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
        updateLighting(at: currentTime)
        stepCrew(time: currentTime)

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
        // Residents enter their home/workplace instead of standing on its
        // doorstep for the whole shift. Public stops retain visible visitors.
        let hour = localTime.truncatingRemainder(dividingBy: MapArt.visualDay) / MapArt.secondsPerHour
        let indoors = routine.stops.indices.contains { index in
            guard index < routine.dwellStart.count, index < routine.dwellEnd.count else { return false }
            return (routine.stops[index] == .home || routine.stops[index] == .work)
                && hour >= Double(routine.dwellStart[index]) && hour < Double(routine.dwellEnd[index])
        }
        node.alpha = indoors ? 0 : 1
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
        onHoverTile?(next)
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

        let buildDays = state.config.constructionDays(for: kind)
        let ghostStage: ConstructionStage = buildDays > 0 ? .foundation : .complete
        let ghost = BuildingArtwork.makeNode(kind: kind, stage: ghostStage)
        ghost.color = tint
        ghost.colorBlendFactor = buildDays > 0 ? 0.4 : 0.55
        ghost.alpha = 0.88
        ghost.position = layout.southCorner(halfWidth: halfWidth, halfHeight: halfHeight)
        ghost.zPosition = 1
        ghostLayer.addChild(ghost)

        let height = SiteSpriteCatalog.spec(kind: kind, stage: ghostStage).size.height
        if let reason {
            let badge = reasonBadge(reason)
            badge.position = CGPoint(x: ghost.position.x, y: ghost.position.y + height + 16)
            badge.zPosition = 2
            ghostLayer.addChild(badge)
        }

        guard kind.showsServiceReach, let entrance = preview.entrance else { return }
        if buildDays > 0 {
            let wait = buildDays == 1 ? "Reach when it opens, in 1 day" : "Reach when it opens, in \(buildDays) days"
            let caption = reasonBadge(wait)
            caption.position = CGPoint(x: ghost.position.x, y: ghost.position.y + height + (reason == nil ? 18 : 46))
            caption.zPosition = 2
            ghostLayer.addChild(caption)
        }
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

    /// Cosmetic light is independent of simulation ticks and saved state. A
    /// clamped frame delta prevents background time from fast-forwarding it.
    private func updateLighting(at time: TimeInterval) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        if reduceMotion != reducedLightingMotion {
            reducedLightingMotion = reduceMotion
            // Reconfigure visible water to stop/start existing ripple actions.
            for node in tileNodes.values { node.name = nil }
            refreshVisible(force: true)
            previousLightingUpdate = -.infinity
        }
        if let previous = previousLightingFrame, !reduceMotion {
            lightingElapsed += min(0.1, max(0, time - previous))
        }
        previousLightingFrame = time
        // Only the cached veil/shadow/light nodes change, at most ten times/sec.
        guard time - previousLightingUpdate >= 0.1 else { return }
        previousLightingUpdate = time
        let light = IslandLightProfile.sample(elapsed: lightingElapsed, reduceMotion: reduceMotion)
        nightLayer.alpha = CGFloat(light.nightAlpha)
        sunlightLayer.alpha = CGFloat(light.sunAlpha)
        vignetteLayer.alpha = CGFloat(light.vignetteAlpha)
        shadowLayer.alpha = CGFloat(light.shadowAlpha)
        entryLightLayer.alpha = CGFloat(light.entryAlpha)
    }

    private func presentEntryLight(_ building: Building, map: WorldMap) {
        let occupied = !building.residents.isEmpty || !building.workers.isEmpty
        guard building.isStanding(on: map), occupied else {
            entryLights.removeValue(forKey: building.id)?.removeFromParent()
            return
        }
        let light: SKSpriteNode
        if let cached = entryLights[building.id] { light = cached }
        else {
            light = SKSpriteNode(texture: Self.entryGlowTexture, size: CGSize(width: 46, height: 23))
            light.blendMode = .add
            entryLights[building.id] = light
            entryLightLayer.addChild(light)
        }
        light.position = point(for: building.entrance, in: map)
    }

    private static let entryGlowTexture = radialTexture(vignette: false)

    /// One small cached gradient, not one texture or light shader per building.
    private static func radialTexture(vignette: Bool) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { output in
            let context = output.cgContext
            let colors: [CGColor] = vignette
                ? [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.black.cgColor]
                : [UIColor(red: 1, green: 0.64, blue: 0.22, alpha: 0.8).cgColor,
                   UIColor(red: 1, green: 0.48, blue: 0.12, alpha: 0.25).cgColor, UIColor.clear.cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray, locations: [0, 0.4, 1]) else { return }
            context.drawRadialGradient(gradient, startCenter: CGPoint(x: 64, y: 64), startRadius: 0,
                                       endCenter: CGPoint(x: 64, y: 64), endRadius: 90,
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private func resizeNightLayer() {
        nightLayer.size = CGSize(width: size.width * 5, height: size.height * 5)
        nightLayer.position = .zero
        sunlightLayer.size = nightLayer.size
        sunlightLayer.position = .zero
        vignetteLayer.size = size
        vignetteLayer.position = .zero
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        gesture.roadMode = roadDrawing
        let fingers = fingerCount(in: event, fallback: touches)
        if touchStart == nil && !gesture.multiFinger { hoverBeforeGesture = hoverTile }
        gesture.began(activeFingers: fingers)
        if fingers >= 2, placementKind != nil {
            // A second finger turns the entire gesture into navigation. Restore
            // the site's position from before the first finger touched down.
            hoverTile = hoverBeforeGesture
            onHoverTile?(hoverTile)
            refreshPlacementGhost()
        }
        guard fingers < 2, !gesture.multiFinger, let touch = touches.first else { return }
        touchStart = touch.location(in: self)
        updateHover(at: touchStart!)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        gesture.roadMode = roadDrawing
        let active = (event?.allTouches ?? touches).filter { $0.phase != .ended && $0.phase != .cancelled }
        let fingers = active.count
        if fingers >= 2 {
            let pair = Array(active.prefix(2))
            let p0 = pair[0].location(in: self), p1 = pair[1].location(in: self)
            let q0 = pair[0].previousLocation(in: self), q1 = pair[1].previousLocation(in: self)
            let newMid = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            let oldMid = CGPoint(x: (q0.x + q1.x) / 2, y: (q0.y + q1.y) / 2)
            let decision = gesture.moved(
                activeFingers: fingers,
                panX: Double(newMid.x - oldMid.x), panY: Double(newMid.y - oldMid.y),
                oldDistance: Double(hypot(q0.x - q1.x, q0.y - q1.y)),
                newDistance: Double(hypot(p0.x - p1.x, p0.y - p1.y)),
                treatAsDrag: true)
            if case .navigate(let panX, let panY, let scaleFactor) = decision {
                applyNavigate(panX: panX, panY: panY, scaleFactor: scaleFactor, anchor: newMid)
            }
            return
        }
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        // In build mode a single finger positions the ghost, not the camera.
        // A pinch latches multiFinger until every touch lifts, so dropping back
        // to one finger cannot unexpectedly move the chosen site.
        if placementKind != nil {
            guard !gesture.multiFinger else { return }
            _ = gesture.moved(activeFingers: 1, panX: 0, panY: 0,
                              oldDistance: 0, newDistance: 0, treatAsDrag: true)
            updateHover(at: p)
            return
        }
        let previous = touch.previousLocation(in: self)
        let far = touchStart.map { hypot(p.x - $0.x, p.y - $0.y) > 8 } ?? false
        let decision = gesture.moved(
            activeFingers: max(fingers, 1),
            panX: Double(p.x - previous.x), panY: Double(p.y - previous.y),
            oldDistance: 0, newDistance: 0,
            treatAsDrag: roadDrawing || far)
        switch decision {
        case .roadPoint:
            if let state = renderedState, let tile = tile(at: p, in: state.map) {
                onRoadTile?(tile)
            }
        case .navigate(let panX, let panY, let scaleFactor):
            applyNavigate(panX: panX, panY: panY, scaleFactor: scaleFactor, anchor: p)
            updateHover(at: p)
        case .ignore:
            break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(touches, event: event, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(touches, event: event, cancelled: true)
    }

    private func finishTouch(_ touches: Set<UITouch>, event: UIEvent?, cancelled: Bool) {
        gesture.roadMode = roadDrawing
        let remaining = fingerCount(in: event, fallback: [])
        let wasDrag = gesture.dragged
        let wasMulti = gesture.multiFinger
        let roadTap = gesture.ended(remainingFingers: remaining)
        if remaining == 0 {
            touchStart = nil
            hoverBeforeGesture = nil
        }
        guard !cancelled, remaining == 0, let state = renderedState, let touch = touches.first,
              let tile = tile(at: touch.location(in: self), in: state.map) else { return }
        if roadTap {
            onRoadTile?(tile)
        } else if !roadDrawing && !wasDrag && !wasMulti {
            onTileTap?(tile)
        }
    }

    private func fingerCount(in event: UIEvent?, fallback: Set<UITouch>) -> Int {
        let all = event?.allTouches ?? fallback
        return all.filter { $0.phase != .ended && $0.phase != .cancelled }.count
    }

    private func applyNavigate(panX: Double, panY: Double, scaleFactor: Double?, anchor: CGPoint) {
        let nudged = MapCameraNudge.applying(
            x: Double(cameraNode.position.x), y: Double(cameraNode.position.y),
            scale: Double(cameraNode.xScale),
            panX: panX, panY: panY,
            anchorX: Double(anchor.x), anchorY: Double(anchor.y),
            scaleFactor: scaleFactor)
        cameraNode.position = CGPoint(x: nudged.x, y: nudged.y)
        cameraNode.setScale(nudged.scale)
        cameraUserAdjusted = true
        clampCameraToMap()
        refreshVisible()
    }

    /// Keep the confirmed site's position inside the usable map, above controls.
    func focus(on tile: TileIndex) {
        guard let state = renderedState, tile.raw >= 0, Int(tile.raw) < state.map.tileCount else { return }
        let world = point(for: tile, in: state.map)
        let focus = framing?.focusRect ?? CGRect(origin: .zero, size: size)
        let dx = focus.midX - size.width / 2
        let dy = focus.midY - size.height / 2
        cameraNode.position = CGPoint(x: world.x - dx * cameraNode.xScale,
                                      y: world.y + dy * cameraNode.yScale)
        cameraUserAdjusted = true
        clampCameraToMap()
        refreshVisible()
    }

    private func drawRoadPreview() {
        guard placementKind == nil, let map = renderedState?.map else { return }
        ghostLayer.removeAllChildren()
        guard !roadPreview.isEmpty else { return }
        let markerSize = CGSize(width: halfWidth * 2, height: halfHeight * 2)
        let markerTexture = BuildingArtwork.tileMarkerTexture(size: markerSize)
        for mark in roadPreview {
            let node = SKSpriteNode(texture: markerTexture, size: markerSize)
            node.color = mark.accepted
                ? UIColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1)
                : UIColor(red: 0.90, green: 0.22, blue: 0.20, alpha: 1)
            node.colorBlendFactor = 0.9
            node.alpha = 0.55
            node.position = point(for: mark.tile, in: map)
            ghostLayer.addChild(node)
        }
    }

    private func drawInspectReach() {
        guard placementKind == nil, let entrance = inspectEntrance, let state = renderedState else {
            if placementKind == nil { reachLayer.removeAllChildren() }
            return
        }
        reachLayer.removeAllChildren()
        let map = state.map
        let markerSize = CGSize(width: halfWidth * 2, height: halfHeight * 2)
        let markerTexture = BuildingArtwork.tileMarkerTexture(size: markerSize)
        let reach = ServiceReach.tiles(from: entrance, maxDistance: state.config.maxServiceDistance, on: map)
        for tile in reach {
            let node = SKSpriteNode(texture: markerTexture, size: markerSize)
            node.color = UIColor(red: 0.98, green: 0.78, blue: 0.22, alpha: 1)
            node.colorBlendFactor = 1
            node.alpha = 0.30
            node.position = point(for: tile, in: map)
            reachLayer.addChild(node)
        }
    }
}

/// Remembers which construction picture a building has already shown.
/// `quiet` is the first paint of a city or a loaded save: no bounce and no pop.
private struct SiteVisual {
    var displayed: ConstructionStage?
    var sawSite: Bool
    var quiet: Bool
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


extension MapOverlayMode {
    var title: String {
        switch self {
        case .standard: return "Normal map"
        case .fertility: return "Fertility"
        case .happiness: return "Happiness"
        case .foodAccess: return "Food access"
        case .employment: return "Jobs"
        }
    }
    var symbol: String {
        switch self {
        case .standard: return "map"
        case .fertility: return "leaf.fill"
        case .happiness: return "face.smiling"
        case .foodAccess: return "basket.fill"
        case .employment: return "briefcase.fill"
        }
    }
    var legend: String {
        switch self {
        case .standard: return ""
        case .fertility: return "Green: fertile soil · brown: other land. Farms need at least 5 fertile tiles in their 3×3 footprint."
        case .happiness: return "District averages: red 0 → amber 50 → green 100. Gray: no residents."
        case .foodAccess: return "Homes & roads: green stocked market · amber empty market · red no access · gray no coverage data."
        case .employment: return "District residents employed: red 0% → amber 50% → green 100%. Gray: no residents."
        }
    }
}

// MARK: - Pure world lighting
/// Presentation-only policy, extracted by tools/check-world-lighting.py.
struct IslandLightProfile {
    let nightAlpha: Double
    let sunAlpha: Double
    let vignetteAlpha: Double
    let shadowAlpha: Double
    let entryAlpha: Double

    static func sample(elapsed: Double, reduceMotion: Bool) -> IslandLightProfile {
        let seconds = elapsed.isFinite ? max(0, elapsed) : 0
        let phase = reduceMotion ? 0.18 : (seconds / 240 + 0.18).truncatingRemainder(dividingBy: 1)
        let sun = cos(phase * .pi * 2)
        let t = min(1, max(0, (0.15 - sun) / 0.9))
        let night = t * t * (3 - 2 * t)
        let twilight = max(0, 1 - abs(sun) / 0.65) * (1 - night * 0.8)
        return IslandLightProfile(nightAlpha: 0.02 + 0.20 * night,
                                  sunAlpha: 0.012 + 0.04 * twilight,
                                  vignetteAlpha: 0.08 + 0.04 * night,
                                  shadowAlpha: 0.90 - 0.72 * night,
                                  entryAlpha: 0.75 * night)
    }
}
