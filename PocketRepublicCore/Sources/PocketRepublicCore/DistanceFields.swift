import Foundation

/// Multi-source BFS distance over the road network, one field per service kind.
///
/// Roads are uniform cost, so BFS is exact and O(tiles) -- no priority queue needed.
/// Recomputed only when the player changes structure (build / demolish / road), never
/// per tick. Every per-citizen "is there a market near me" query is then an O(1)
/// array lookup instead of a search.
public struct DistanceFields: Codable, Sendable {
    public static let unreachable: UInt16 = .max

    /// Dense, indexed by ServiceKind.rawValue. Deliberately NOT a dictionary:
    /// Swift encodes a dictionary with non-String/Int keys as a flat array in
    /// iteration order, which made the serialised world -- and therefore the state
    /// hash and the save file -- non-canonical between runs.
    public private(set) var fields: [[UInt16]] = []
    /// Connected-component label per tile (-1 = impassable). Exact reachability test
    /// in O(1) without a field per building.
    public private(set) var component: [Int32] = []
    /// BuildingID.raw of the closest market by ROAD distance for every tile (-1 if
    /// none is reachable). Lets a house resolve both "how far" and "which market"
    /// from the same traversal, so coverage and purchasing can never disagree.
    public private(set) var nearestMarket: [Int32] = []
    public private(set) var dirty: Bool = true

    public init() {}

    public mutating func markDirty() { dirty = true }

    public func distance(_ service: ServiceKind, at tile: TileIndex) -> UInt16 {
        let i = Int(service.rawValue)
        guard i < fields.count, Int(tile.raw) < fields[i].count else { return Self.unreachable }
        return fields[i][Int(tile.raw)]
    }

    public func isWithin(_ service: ServiceKind, of tile: TileIndex, max: UInt16) -> Bool {
        distance(service, at: tile) <= max
    }

    /// Recompute all fields. Called at the top of a tick only when dirty.
    public mutating func rebuild(map: WorldMap, buildings: [Building]) {
        var sourcesByService: [UInt8: [TileIndex]] = [:]
        for b in buildings {
            guard let s = b.provides else { continue }
            // `tile` is the entrance: the only footprint cell connected to the roads.
            sourcesByService[s.rawValue, default: []].append(b.tile)
        }
        var next = [[UInt16]](repeating: [], count: ServiceKind.allCases.count)
        for service in ServiceKind.allCases {
            let sources = sourcesByService[service.rawValue] ?? []
            next[Int(service.rawValue)] = Self.bfs(map: map, sources: sources)
        }
        fields = next
        component = Self.labelComponents(map: map)
        nearestMarket = Self.nearestSourceMap(
            map: map,
            sources: buildings.filter { $0.kind == .market }.map { ($0.id.raw, $0.tile) })
        dirty = false
    }

    public func areConnected(_ a: TileIndex, _ b: TileIndex) -> Bool {
        guard !component.isEmpty else { return false }
        let ca = component[Int(a.raw)], cb = component[Int(b.raw)]
        return ca >= 0 && ca == cb
    }

    /// One BFS per source, keeping a running argmin. Sources are few (markets), tiles
    /// are many, and this only runs on structural change.
    static func nearestSourceMap(map: WorldMap, sources: [(Int32, TileIndex)]) -> [Int32] {
        var best = [UInt16](repeating: unreachable, count: map.tileCount)
        var owner = [Int32](repeating: -1, count: map.tileCount)
        for (id, tile) in sources.sorted(by: { $0.0 < $1.0 }) {
            let d = bfs(map: map, sources: [tile])
            for i in 0..<map.tileCount where d[i] < best[i] {
                best[i] = d[i]
                owner[i] = id
            }
        }
        return owner
    }

    public func nearestMarket(at tile: TileIndex) -> BuildingID? {
        guard Int(tile.raw) < nearestMarket.count else { return nil }
        let v = nearestMarket[Int(tile.raw)]
        return v < 0 ? nil : BuildingID(v)
    }

    static func labelComponents(map: WorldMap) -> [Int32] {
        var label = [Int32](repeating: -1, count: map.tileCount)
        var stack = [Int32](repeating: 0, count: map.tileCount)
        var nextLabel: Int32 = 0
        for start in 0..<map.tileCount {
            let st = TileIndex(Int32(start))
            guard map.isPassable(st), label[start] < 0 else { continue }
            var top = 0
            label[start] = nextLabel
            stack[top] = Int32(start); top += 1
            while top > 0 {
                top -= 1
                let cur = TileIndex(stack[top])
                for n in map.neighbours(of: cur) where map.isPassable(n) && label[Int(n.raw)] < 0 {
                    label[Int(n.raw)] = nextLabel
                    stack[top] = n.raw; top += 1
                }
            }
            nextLabel += 1
        }
        return label
    }

    static func bfs(map: WorldMap, sources: [TileIndex]) -> [UInt16] {
        var dist = [UInt16](repeating: unreachable, count: map.tileCount)
        guard !sources.isEmpty else { return dist }

        // Flat ring buffer rather than Array.removeFirst, which is O(n).
        var queue = [Int32](repeating: 0, count: map.tileCount)
        var head = 0, tail = 0

        // Sorted for determinism: BFS distances are order-independent, but keeping
        // the traversal order fixed keeps any future tie-breaking reproducible.
        for t in sources.sorted() where dist[Int(t.raw)] == unreachable {
            dist[Int(t.raw)] = 0
            queue[tail] = t.raw
            tail += 1
        }

        while head < tail {
            let cur = TileIndex(queue[head]); head += 1
            let d = dist[Int(cur.raw)]
            if d == unreachable { continue }
            let nd = d &+ 1
            for n in map.neighbours(of: cur) {
                let ni = Int(n.raw)
                guard map.isPassable(n), dist[ni] > nd else { continue }
                dist[ni] = nd
                queue[tail] = n.raw
                tail += 1
            }
        }
        return dist
    }
}

extension Building {
    var provides: ServiceKind? { kind.provides }
}
