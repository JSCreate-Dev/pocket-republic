import SpriteKit
import UIKit
import PocketRepublicCore

/// 1x node sizes copied from `docs/art/sprites.json` and design section 7.6.
/// Set the sprite node's size from `pointSize`, never from `SKTexture.size()`:
/// a few @2x/@3x heights are one pixel off the 1x height. Every anchor is
/// (0.5, 0), the bottom-front corner of the picture, including foundation and
/// scaffold so a stage swap does not slide the building on the ground.
///
/// `artTilesWide` and `artTilesDeep` describe the picture only. Which tiles a
/// building occupies still comes from `CityFootprintModel`.
struct BuildingSpriteSpec {
    var artTilesWide: Int
    var artTilesDeep: Int
    var pointSize: CGSize
    var imageName: String
    var anchor: CGPoint { CGPoint(x: 0.5, y: 0) }
}

enum BuildingSpriteCatalog {
    static func spec(for kind: BuildingKind) -> BuildingSpriteSpec {
        _ = widthsMatchArtRule
        return make(kind)
    }

    private static let widthsMatchArtRule: Bool = {
        for kind in BuildingKind.allCases {
            let spec = make(kind)
            let base = (spec.artTilesWide + spec.artTilesDeep) * 32
            assert(Int(spec.pointSize.width) == base,
                   "sprite width for \(kind) must be (W+H)×32, matching sprites.json")
        }
        return true
    }()

    private static func make(_ kind: BuildingKind) -> BuildingSpriteSpec {
        switch kind {
        case .townHall:
            return BuildingSpriteSpec(artTilesWide: 3, artTilesDeep: 3,
                                      pointSize: CGSize(width: 192, height: 222),
                                      imageName: "building_townHall")
        case .house:
            return BuildingSpriteSpec(artTilesWide: 2, artTilesDeep: 2,
                                      pointSize: CGSize(width: 128, height: 125),
                                      imageName: UIImage(named: "building_house_golden") == nil ? "building_house" : "building_house_golden")
        case .police:
            return BuildingSpriteSpec(artTilesWide: 2, artTilesDeep: 2,
                                      pointSize: CGSize(width: 128, height: 114),
                                      imageName: "building_police")
        case .market:
            return BuildingSpriteSpec(artTilesWide: 3, artTilesDeep: 2,
                                      pointSize: CGSize(width: 160, height: 123),
                                      imageName: UIImage(named: "building_market_golden") == nil ? "building_market" : "building_market_golden")
        case .workshop:
            return BuildingSpriteSpec(artTilesWide: 3, artTilesDeep: 2,
                                      pointSize: CGSize(width: 160, height: 163),
                                      imageName: UIImage(named: "building_workshop_golden") == nil ? "building_workshop" : "building_workshop_golden")
        case .farm:
            return BuildingSpriteSpec(artTilesWide: 3, artTilesDeep: 3,
                                      pointSize: CGSize(width: 192, height: 154),
                                      imageName: "building_farm")
        case .clinic:
            return BuildingSpriteSpec(artTilesWide: 3, artTilesDeep: 3,
                                      pointSize: CGSize(width: 192, height: 185),
                                      imageName: "building_clinic")
        case .school:
            return BuildingSpriteSpec(artTilesWide: 3, artTilesDeep: 3,
                                      pointSize: CGSize(width: 192, height: 206),
                                      imageName: "building_school")
        case .dock:
            return BuildingSpriteSpec(artTilesWide: 2, artTilesDeep: 3,
                                      pointSize: CGSize(width: 160, height: 140),
                                      imageName: "building_dock")
        }
    }
}

/// Footprint shape for the shared site art. 3×2 and 2×3 are different diamonds.
enum SiteFootprintShape {
    case twoByTwo, threeByTwo, twoByThree, threeByThree

    static func of(_ kind: BuildingKind) -> SiteFootprintShape {
        switch (kind.footprint.width, kind.footprint.height) {
        case (2, 2): return .twoByTwo
        case (3, 2): return .threeByTwo
        case (2, 3): return .twoByThree
        default: return .threeByThree
        }
    }
}

enum SiteSpriteCatalog {
    /// Section 7.6 sizes. The finished sprite stays in `BuildingSpriteCatalog`.
    static func spec(kind: BuildingKind, stage: ConstructionStage) -> (size: CGSize, imageName: String) {
        let shape = SiteFootprintShape.of(kind)
        switch stage {
        case .foundation:
            switch shape {
            case .twoByTwo: return (CGSize(width: 128, height: 74), "site_foundation_2x2")
            case .threeByTwo: return (CGSize(width: 160, height: 90), "site_foundation_3x2")
            case .twoByThree: return (CGSize(width: 160, height: 90), "site_foundation_2x3")
            case .threeByThree: return (CGSize(width: 192, height: 106), "site_foundation_3x3")
            }
        case .scaffold:
            switch shape {
            case .twoByTwo: return (CGSize(width: 128, height: 96), "site_scaffold_2x2")
            case .threeByTwo: return (CGSize(width: 160, height: 112), "site_scaffold_3x2")
            case .twoByThree: return (CGSize(width: 160, height: 112), "site_scaffold_2x3")
            case .threeByThree: return (CGSize(width: 192, height: 136), "site_scaffold_3x3")
            }
        case .complete:
            let finished = BuildingSpriteCatalog.spec(for: kind)
            return (finished.pointSize, finished.imageName)
        }
    }
}

enum BuildingArtwork {
    /// Finished catalog sprite, or the foundation/scaffold imageset for a site.
    /// A missing imageset draws a same-size placeholder so the stage still reads.
    static func makeNode(kind: BuildingKind, stage: ConstructionStage = .complete) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(kind: kind, stage: stage),
                                size: SiteSpriteCatalog.spec(kind: kind, stage: stage).size)
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        return node
    }

    static func tileMarkerTexture(size: CGSize) -> SKTexture {
        let key = CGSizeKey(size)
        if let cached = markerTextures[key] { return cached }
        let image = renderer(size).image { _ in
            let path = diamond(in: size)
            UIColor.white.setFill()
            path.fill()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        markerTextures[key] = texture
        return texture
    }

    /// Shared, blurred ground silhouettes. Footprint math and the bottom-front
    /// anchor stay separate from the decorative shadow cast down/right.
    static func makeGroundShadow(kind: BuildingKind, stage: ConstructionStage) -> SKSpriteNode {
        let baseWidth = CGFloat(kind.footprint.width + kind.footprint.height) * 32
        let baseHeight = baseWidth / 2
        let bodyHeight = SiteSpriteCatalog.spec(kind: kind, stage: stage).size.height
        let rise = max(8, bodyHeight - baseHeight)
        let dx = max(8, rise * 0.55), dy = max(5, rise * 0.24)
        let pad: CGFloat = 12
        let size = CGSize(width: ceil(baseWidth + dx + pad * 2), height: ceil(baseHeight + dy + pad * 2))
        let front = CGPoint(x: pad + baseWidth / 2, y: pad + baseHeight)
        let key = "\(kind.rawValue)-\(stage)"
        let texture: SKTexture
        if let cached = groundShadows[key] { texture = cached }
        else {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = false
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                context.cgContext.setShadow(offset: .zero, blur: 6,
                                            color: UIColor.black.withAlphaComponent(0.18).cgColor)
                let path = UIBezierPath()
                path.move(to: front)
                path.addLine(to: CGPoint(x: front.x - baseWidth / 2, y: front.y - baseHeight / 2))
                path.addLine(to: CGPoint(x: front.x, y: front.y - baseHeight))
                path.addLine(to: CGPoint(x: front.x + baseWidth / 2, y: front.y - baseHeight / 2))
                path.addLine(to: CGPoint(x: front.x + baseWidth / 2 + dx, y: front.y - baseHeight / 2 + dy))
                path.addLine(to: CGPoint(x: front.x + dx, y: front.y + dy))
                path.close()
                UIColor.black.withAlphaComponent(0.2).setFill()
                path.fill()
            }
            texture = SKTexture(image: image)
            texture.filteringMode = .linear
            groundShadows[key] = texture
        }
        let node = SKSpriteNode(texture: texture, size: size)
        node.anchorPoint = CGPoint(x: front.x / size.width, y: 1 - front.y / size.height)
        node.isUserInteractionEnabled = false
        return node
    }

    private static var groundShadows: [String: SKTexture] = [:]
    private static var spriteTextures: [String: SKTexture] = [:]
    private static var markerTextures: [CGSizeKey: SKTexture] = [:]

    private static func texture(kind: BuildingKind, stage: ConstructionStage) -> SKTexture {
        let spec = SiteSpriteCatalog.spec(kind: kind, stage: stage)
        if let cached = spriteTextures[spec.imageName] { return cached }
        let texture: SKTexture
        if let image = UIImage(named: spec.imageName) {
            texture = SKTexture(image: image)
            texture.filteringMode = .linear
        } else if stage == .complete {
            texture = placeholder(kind: kind, size: spec.size)
        } else {
            texture = sitePlaceholder(stage: stage, size: spec.size)
        }
        spriteTextures[spec.imageName] = texture
        return texture
    }

    /// Flat dug earth, or a short timber frame, when the site imageset is missing.
    private static func sitePlaceholder(stage: ConstructionStage, size: CGSize) -> SKTexture {
        let image = renderer(size).image { _ in
            let width = size.width
            let height = size.height
            let diamondHeight = width / 2
            let south = CGPoint(x: width / 2, y: height)
            let east = CGPoint(x: width, y: height - diamondHeight / 2)
            let north = CGPoint(x: width / 2, y: height - diamondHeight)
            let west = CGPoint(x: 0, y: height - diamondHeight / 2)
            let earth = UIColor(red: 0.55, green: 0.40, blue: 0.24, alpha: 1)
            fill(polygon([west, south, east, north]), earth)
            stroke(polygon([west, south, east, north]))
            if stage == .scaffold {
                let timber = UIColor(red: 0.62, green: 0.45, blue: 0.22, alpha: 1)
                timber.setStroke()
                let frame = UIBezierPath()
                frame.move(to: west)
                frame.addLine(to: CGPoint(x: west.x + 8, y: west.y - 28))
                frame.move(to: east)
                frame.addLine(to: CGPoint(x: east.x - 8, y: east.y - 28))
                frame.move(to: CGPoint(x: west.x + 8, y: west.y - 28))
                frame.addLine(to: CGPoint(x: east.x - 8, y: east.y - 28))
                frame.lineWidth = 3
                frame.stroke()
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func placeholder(kind: BuildingKind, size: CGSize) -> SKTexture {
        let paint = KindPaint.forKind(kind)
        let image = renderer(size).image { _ in
            let width = size.width
            let height = size.height
            let diamondHeight = width / 2
            let lift = height - diamondHeight
            let south = CGPoint(x: width / 2, y: height)
            let east = CGPoint(x: width, y: height - diamondHeight / 2)
            let north = CGPoint(x: width / 2, y: height - diamondHeight)
            let west = CGPoint(x: 0, y: height - diamondHeight / 2)
            func raised(_ point: CGPoint) -> CGPoint {
                CGPoint(x: point.x, y: point.y - lift)
            }

            fill(polygon([west, south, raised(south), raised(west)]), paint.wall.shaded(1.08))
            fill(polygon([south, east, raised(east), raised(south)]), paint.wall.shaded(0.72))
            fill(polygon([raised(west), raised(south), raised(east), raised(north)]), paint.roof)
            stroke(polygon([west, south, raised(south), raised(west)]))
            stroke(polygon([south, east, raised(east), raised(south)]))
            stroke(polygon([raised(west), raised(south), raised(east), raised(north)]))
            drawDoor(south: south, lift: lift, width: width)
            drawMark(paint.mark, roofCenter: CGPoint(x: width / 2, y: raised(south).y - diamondHeight / 2),
                     width: width)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    private static func renderer(_ size: CGSize) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format)
    }

    private static func diamond(in size: CGSize) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: size.width / 2, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height / 2))
        path.close()
        return path
    }

    private static func polygon(_ points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.close()
        return path
    }

    private static func fill(_ path: UIBezierPath, _ color: UIColor) {
        color.setFill()
        path.fill()
    }

    private static func stroke(_ path: UIBezierPath) {
        UIColor.black.withAlphaComponent(0.35).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private static func drawDoor(south: CGPoint, lift: CGFloat, width: CGFloat) {
        let doorWidth = max(8, width * 0.07)
        let doorHeight = max(10, lift * 0.42)
        let rect = CGRect(x: south.x - doorWidth / 2,
                          y: south.y - lift * 0.08 - doorHeight,
                          width: doorWidth,
                          height: doorHeight)
        UIColor(white: 0.12, alpha: 0.9).setFill()
        UIBezierPath(rect: rect).fill()
    }

    private static func drawMark(_ mark: KindMark, roofCenter: CGPoint, width: CGFloat) {
        let ink = UIColor.white.withAlphaComponent(0.92)
        ink.setFill()
        ink.setStroke()
        switch mark {
        case .none:
            break
        case .cross:
            let arm = max(7, width * 0.045)
            UIBezierPath(rect: CGRect(x: roofCenter.x - arm, y: roofCenter.y - 2, width: arm * 2, height: 4)).fill()
            UIBezierPath(rect: CGRect(x: roofCenter.x - 2, y: roofCenter.y - arm, width: 4, height: arm * 2)).fill()
        case .bell:
            UIBezierPath(ovalIn: CGRect(x: roofCenter.x - 6, y: roofCenter.y - 8, width: 12, height: 12)).fill()
        case .shield:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: roofCenter.x, y: roofCenter.y - 9))
            path.addLine(to: CGPoint(x: roofCenter.x + 8, y: roofCenter.y - 4))
            path.addLine(to: CGPoint(x: roofCenter.x, y: roofCenter.y + 8))
            path.addLine(to: CGPoint(x: roofCenter.x - 8, y: roofCenter.y - 4))
            path.close()
            path.fill()
        case .awning:
            let band = UIBezierPath(rect: CGRect(x: roofCenter.x - width * 0.16,
                                                 y: roofCenter.y + width * 0.04,
                                                 width: width * 0.32,
                                                 height: 5))
            UIColor(white: 0.15, alpha: 0.85).setFill()
            band.fill()
        case .chimney:
            UIColor(white: 0.16, alpha: 0.95).setFill()
            UIBezierPath(rect: CGRect(x: roofCenter.x + width * 0.08, y: roofCenter.y - 16,
                                      width: 8, height: 16)).fill()
        case .tower:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: roofCenter.x, y: roofCenter.y - 16))
            path.addLine(to: CGPoint(x: roofCenter.x + 7, y: roofCenter.y))
            path.addLine(to: CGPoint(x: roofCenter.x - 7, y: roofCenter.y))
            path.close()
            path.fill()
        case .planks:
            UIColor.white.withAlphaComponent(0.55).setStroke()
            let line = UIBezierPath()
            line.move(to: CGPoint(x: roofCenter.x - width * 0.18, y: roofCenter.y))
            line.addLine(to: CGPoint(x: roofCenter.x + width * 0.18, y: roofCenter.y))
            line.lineWidth = 2
            line.stroke()
        }
    }
}

private struct CGSizeKey: Hashable {
    var width: Int
    var height: Int
    init(_ size: CGSize) {
        width = Int(size.width)
        height = Int(size.height)
    }
}

private enum KindMark { case none, cross, bell, shield, awning, chimney, tower, planks }

private struct KindPaint {
    var wall: UIColor
    var roof: UIColor
    var mark: KindMark

    static func forKind(_ kind: BuildingKind) -> KindPaint {
        switch kind {
        case .townHall:
            return KindPaint(wall: rgb(0.90, 0.74, 0.22), roof: rgb(0.98, 0.88, 0.46), mark: .tower)
        case .house:
            return KindPaint(wall: rgb(0.93, 0.52, 0.20), roof: rgb(0.86, 0.28, 0.18), mark: .none)
        case .farm:
            return KindPaint(wall: rgb(0.55, 0.40, 0.24), roof: rgb(0.36, 0.66, 0.30), mark: .none)
        case .market:
            return KindPaint(wall: rgb(0.90, 0.42, 0.58), roof: rgb(0.98, 0.70, 0.55), mark: .awning)
        case .clinic:
            return KindPaint(wall: rgb(0.86, 0.28, 0.28), roof: rgb(0.96, 0.55, 0.52), mark: .cross)
        case .school:
            return KindPaint(wall: rgb(0.18, 0.55, 0.60), roof: rgb(0.45, 0.78, 0.80), mark: .bell)
        case .police:
            return KindPaint(wall: rgb(0.20, 0.38, 0.78), roof: rgb(0.45, 0.60, 0.90), mark: .shield)
        case .workshop:
            return KindPaint(wall: rgb(0.52, 0.34, 0.22), roof: rgb(0.40, 0.28, 0.24), mark: .chimney)
        case .dock:
            return KindPaint(wall: rgb(0.42, 0.46, 0.50), roof: rgb(0.62, 0.66, 0.70), mark: .planks)
        }
    }
}

private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
    UIColor(red: red, green: green, blue: blue, alpha: 1)
}

private extension UIColor {
    func shaded(_ factor: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        return UIColor(red: min(1, red * factor), green: min(1, green * factor),
                       blue: min(1, blue * factor), alpha: alpha)
    }
}
