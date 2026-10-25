import SpriteKit
import UIKit
import PocketRepublicCore

/// 1x node sizes copied from `docs/art/sprites.json` (PR #4). That file is not
/// on main yet, so the numbers live here and rendering works either way.
///
/// Set the sprite node's size from `pointSize`, never from `SKTexture.size()`:
/// a few @2x/@3x heights are one pixel off the 1x height. Every anchor in that
/// file is (0.5, 0), the bottom-front corner of the picture.
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
                                      imageName: "building_house")
        case .police:
            return BuildingSpriteSpec(artTilesWide: 2, artTilesDeep: 2,
                                      pointSize: CGSize(width: 128, height: 114),
                                      imageName: "building_police")
        case .market:
            return BuildingSpriteSpec(artTilesWide: 3, artTilesDeep: 2,
                                      pointSize: CGSize(width: 160, height: 123),
                                      imageName: "building_market")
        case .workshop:
            return BuildingSpriteSpec(artTilesWide: 3, artTilesDeep: 2,
                                      pointSize: CGSize(width: 160, height: 163),
                                      imageName: "building_workshop")
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

enum BuildingArtwork {
    /// Catalog sprite when `building_<kind>` exists, otherwise a placeholder of
    /// the same point size. Dropping the imageset in is the whole art swap.
    static func makeNode(kind: BuildingKind) -> SKSpriteNode {
        let spec = BuildingSpriteCatalog.spec(for: kind)
        let node = SKSpriteNode(texture: texture(for: kind), size: spec.pointSize)
        node.anchorPoint = spec.anchor
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

    private static var spriteTextures: [String: SKTexture] = [:]
    private static var markerTextures: [CGSizeKey: SKTexture] = [:]

    private static func texture(for kind: BuildingKind) -> SKTexture {
        let spec = BuildingSpriteCatalog.spec(for: kind)
        if let cached = spriteTextures[spec.imageName] { return cached }
        let texture: SKTexture
        if let image = UIImage(named: spec.imageName) {
            texture = SKTexture(image: image)
            texture.filteringMode = .linear
        } else {
            texture = placeholder(kind: kind, size: spec.pointSize)
        }
        spriteTextures[spec.imageName] = texture
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
