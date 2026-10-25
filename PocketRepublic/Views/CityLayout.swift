import SwiftUI

/// Which surface fills a Duo pane. Swap `panes` to move the agenda to the other
/// side. A layout picker is backlog and is not built here. Inspect will share
/// the agenda pane when that panel exists.
enum CityPane: Equatable {
    case map
    case agenda
}

/// Folded phones use a bottom sheet. A vertical fold or a wide inner display
/// puts the map and the agenda side by side. A horizontal fold stacks them.
struct CityDisplayLayout: Equatable {
    enum Posture: Equatable { case folded, sideBySide, stacked }

    let posture: Posture
    let size: CGSize
    let mapFrame: CGRect
    let agendaFrame: CGRect
    let focus: CGRect
    let occlusionTopInset: CGFloat

    init(geometry: GeometryProxy, verticalSizeClass: UserInterfaceSizeClass?,
         layoutDirection: LayoutDirection, panes: [CityPane], sheetFraction: CGFloat) {
        let size = geometry.size
        self.size = size
        let bounds = CGRect(origin: .zero, size: size)
        var seam: CGRect?
        if #available(iOS 27.1, *) {
            let raw = geometry.reservedRegions(kind: .division)
                .map(\.frame)
                .filter { $0.intersects(bounds) }
                .max(by: { $0.width * $0.height < $1.width * $1.height })
            if let raw {
                let cut = raw.intersection(bounds)
                if !cut.isNull, cut.width > 0, cut.height > 0 { seam = cut }
            }
        }
        let order = panes.count >= 2 ? Array(panes.prefix(2)) : [.map, .agenda]
        let resolved = Self.resolve(
            size: size,
            seam: seam,
            wideAndTall: size.width >= 580 && size.height >= 500 && verticalSizeClass != .compact,
            rtl: layoutDirection == .rightToLeft,
            order: order,
            sheetFraction: min(0.88, max(0.18, sheetFraction))
        )
        posture = resolved.posture
        mapFrame = resolved.map
        agendaFrame = resolved.agenda
        focus = resolved.focus

        if #available(iOS 27.1, *) {
            occlusionTopInset = geometry.reservedRegions(kind: .occlusion)
                .map(\.frame)
                .filter { $0.intersects(resolved.map) && $0.minY <= resolved.map.minY + 80 }
                .map { max(0, $0.maxY - resolved.map.minY) }
                .max() ?? 0
        } else {
            occlusionTopInset = 0
        }
    }

    var framing: CameraFraming {
        let width = max(focus.width, 1)
        // Scale near 0.85 keeps a town's worth of tiles on screen. The old
        // 8–12 tile count, measured on a narrow side rail, started zoomed out.
        let tiles = min(8, max(4.5, 0.85 * width / 64))
        return CameraFraming(viewSize: size, focusRect: focus, tileWidths: tiles)
    }

    private struct Resolved: Equatable {
        var posture: Posture
        var map: CGRect
        var agenda: CGRect
        var focus: CGRect
    }

    private enum Axis { case horizontal, vertical }

    private static func resolve(size: CGSize, seam: CGRect?, wideAndTall: Bool, rtl: Bool,
                                order: [CityPane], sheetFraction: CGFloat) -> Resolved {
        if let seam, seam.height >= seam.width {
            let left = CGRect(x: 0, y: 0, width: max(0, seam.minX), height: size.height)
            let right = CGRect(x: seam.maxX, y: 0, width: max(0, size.width - seam.maxX), height: size.height)
            if let split = assign(first: left, second: right, order: order, rtl: rtl,
                                  minEdge: 180, axis: .horizontal) {
                return Resolved(posture: .sideBySide, map: split.map, agenda: split.agenda, focus: split.map)
            }
        } else if let seam {
            let top = CGRect(x: 0, y: 0, width: size.width, height: max(0, seam.minY))
            let bottom = CGRect(x: 0, y: seam.maxY, width: size.width, height: max(0, size.height - seam.maxY))
            if let split = assign(first: top, second: bottom, order: order, rtl: false,
                                  minEdge: 120, axis: .vertical) {
                return Resolved(posture: .stacked, map: split.map, agenda: split.agenda, focus: split.map)
            }
        } else if wideAndTall {
            let agendaWidth = min(420, max(280, size.width * 0.4))
            let leading = CGRect(x: 0, y: 0, width: size.width - agendaWidth, height: size.height)
            let trailing = CGRect(x: size.width - agendaWidth, y: 0, width: agendaWidth, height: size.height)
            if let split = assign(first: leading, second: trailing, order: order, rtl: rtl,
                                  minEdge: 180, axis: .horizontal) {
                return Resolved(posture: .sideBySide, map: split.map, agenda: split.agenda, focus: split.map)
            }
        }
        return folded(size: size, sheetFraction: sheetFraction)
    }

    private static func assign(first: CGRect, second: CGRect, order: [CityPane], rtl: Bool,
                               minEdge: CGFloat, axis: Axis) -> (map: CGRect, agenda: CGRect)? {
        var slots = [first, second]
        if rtl { slots.reverse() }
        var map = CGRect.null
        var agenda = CGRect.null
        for (index, pane) in order.enumerated() {
            let slot = slots[index]
            switch pane {
            case .map: map = slot
            case .agenda: agenda = slot
            }
        }
        let agendaEdge = axis == .horizontal ? agenda.width : agenda.height
        let mapEdge = axis == .horizontal ? map.width : map.height
        guard agendaEdge >= minEdge, mapEdge >= minEdge else { return nil }
        return (map, agenda)
    }

    private static func folded(size: CGSize, sheetFraction: CGFloat) -> Resolved {
        let sheetHeight = size.height * sheetFraction
        let map = CGRect(origin: .zero, size: size)
        let agenda = CGRect(x: 0, y: size.height - sheetHeight, width: size.width, height: sheetHeight)
        let focus = CGRect(x: 0, y: 0, width: size.width, height: max(1, size.height - sheetHeight))
        return Resolved(posture: .folded, map: map, agenda: agenda, focus: focus)
    }
}
