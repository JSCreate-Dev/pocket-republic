import Foundation

/// Seeded terrain for new settlements only. No height field, RNG consumption or
/// saved-map regeneration. A protected central build area keeps the opening viable.
enum IslandTerrain {
    static func paint(_ map: inout WorldMap, seed: UInt64) {
        let size = map.width
        let mid = size / 2
        let centre = Int64(size - 1)
        let salt = seed ^ 0x4953_4C41_4E44
        func protected(_ x: Int32, _ y: Int32) -> Bool {
            abs(x - mid) <= 12 && abs(y - mid) <= 12
        }
        for y in 0..<size {
            for x in 0..<size {
                let index = Int(map.index(x: x, y: y).raw)
                let edge = min(min(x, y), min(size - 1 - x, size - 1 - y))
                guard edge >= 3 else { map.terrain[index] = TerrainKind.water.rawValue; continue }
                if protected(x, y) { continue }
                let dx = Int64(x) * 2 - centre, dy = Int64(y) * 2 - centre
                let coast = Int64(size - 8) + (noise(x, y, scale: 9, seed: salt) - 50) / 10
                if dx * dx + dy * dy > coast * coast {
                    map.terrain[index] = TerrainKind.water.rawValue
                    continue
                }
                let region = noise(x, y, scale: 10, seed: salt ^ 0xF3A7)
                let terrain: TerrainKind = region >= 59 ? .fertile : (region <= 32 ? .rock : .grass)
                map.terrain[index] = terrain.rawValue
            }
        }
        // One seeded coastal bay makes the shoreline asymmetric. Never cut the
        // opening's build area, and keep the east landing shore available.
        let side = Int(hash(0, 0, seed: salt) % 3)
        let radius = max(3, size / 9)
        let along = mid + Int32(hash(1, 0, seed: salt) % UInt64(max(1, size / 4))) - size / 8
        let bx: Int32 = side == 0 ? 4 : (side == 1 ? along : size - 6)
        let by: Int32 = side == 0 ? along : (side == 1 ? 4 : size - 8)
        for y in 3..<(size - 3) {
            for x in 3..<(size - 3) where !protected(x, y) {
                let dx = x - bx, dy = y - by
                if dx * dx + dy * dy <= radius * radius {
                    map.terrain[Int(map.index(x: x, y: y).raw)] = TerrainKind.water.rawValue
                }
            }
        }
        // The unrotated dock needs a full east/west-facing long edge. Preserve a
        // reachable, unoccupied east shore instead of generating an impossible goal.
        for y in max(3, mid - 4)...min(size - 4, mid + 6) {
            for x in (size - 7)..<(size - 3) { map.terrain[Int(map.index(x: x, y: y).raw)] = TerrainKind.sand.rawValue }
            for x in (size - 3)..<size { map.terrain[Int(map.index(x: x, y: y).raw)] = TerrainKind.water.rawValue }
        }
        // Remove detached specks of land; all buildable ground should be reachable
        // from the starter area before the player chooses road routes.
        var seen = [Bool](repeating: false, count: map.tileCount)
        let start = map.index(x: mid, y: mid)
        var queue = [start]
        seen[Int(start.raw)] = true
        var head = 0
        while head < queue.count {
            let tile = queue[head]; head += 1
            for next in map.neighbours(of: tile) where !seen[Int(next.raw)] && map.terrain(at: next).buildable {
                seen[Int(next.raw)] = true; queue.append(next)
            }
        }
        for raw in 0..<map.tileCount where !seen[raw] { map.terrain[raw] = TerrainKind.water.rawValue }
        let coastMap = map
        for y in 3..<(size - 3) {
            for x in 3..<(size - 3) where !protected(x, y) {
                let tile = map.index(x: x, y: y)
                if coastMap.terrain(at: tile).buildable && coastMap.neighbours(of: tile).contains(where: { coastMap.terrain(at: $0) == .water }) {
                    map.terrain[Int(tile.raw)] = TerrainKind.sand.rawValue
                }
            }
        }
    }

    private static func hash(_ x: Int32, _ y: Int32, seed: UInt64) -> UInt64 {
        var value = seed ^ UInt64(x) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(y) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// Bilinear integer noise makes regions instead of per-tile confetti.
    private static func noise(_ x: Int32, _ y: Int32, scale: Int32, seed: UInt64) -> Int64 {
        let gx = x / scale, gy = y / scale
        let fx = Int64(x % scale), fy = Int64(y % scale), width = Int64(scale)
        let a = Int64(hash(gx, gy, seed: seed) % 101)
        let b = Int64(hash(gx + 1, gy, seed: seed) % 101)
        let c = Int64(hash(gx, gy + 1, seed: seed) % 101)
        let d = Int64(hash(gx + 1, gy + 1, seed: seed) % 101)
        return (a * (width - fx) * (width - fy) + b * fx * (width - fy)
                + c * (width - fx) * fy + d * fx * fy) / (width * width)
    }
}
