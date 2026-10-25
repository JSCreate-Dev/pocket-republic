import Foundation

public enum TerrainKind: UInt8, Codable, Sendable, CaseIterable {
    case water = 0, sand = 1, grass = 2, fertile = 3, rock = 4
    public var buildable: Bool { self != .water }
}

/// Struct-of-arrays tile storage. 96x96 = 9216 tiles costs ~37 KB in these flat
/// arrays and encodes in microseconds; the same grid as an array of rich tile
/// objects is heavy in memory and slow to serialise every tick.
public struct WorldMap: Codable, Sendable {
    public let width: Int32
    public let height: Int32

    public var terrain: [UInt8]       // TerrainKind.rawValue
    public var districtAt: [UInt8]    // DistrictID.raw
    public var buildingAt: [Int32]    // BuildingID.raw, or -1
    public var road: [Bool]

    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
        let n = Int(width * height)
        self.terrain = [UInt8](repeating: TerrainKind.grass.rawValue, count: n)
        self.districtAt = [UInt8](repeating: 0, count: n)
        self.buildingAt = [Int32](repeating: -1, count: n)
        self.road = [Bool](repeating: false, count: n)
    }

    public var tileCount: Int { Int(width * height) }

    @inlinable public func index(x: Int32, y: Int32) -> TileIndex { TileIndex(y * width + x) }
    @inlinable public func x(of t: TileIndex) -> Int32 { t.raw % width }
    @inlinable public func y(of t: TileIndex) -> Int32 { t.raw / width }
    @inlinable public func contains(x: Int32, y: Int32) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    public func terrain(at t: TileIndex) -> TerrainKind {
        TerrainKind(rawValue: terrain[Int(t.raw)]) ?? .grass
    }
    public func district(at t: TileIndex) -> DistrictID { DistrictID(districtAt[Int(t.raw)]) }
    public func building(at t: TileIndex) -> BuildingID? {
        let v = buildingAt[Int(t.raw)]
        return v < 0 ? nil : BuildingID(v)
    }
    public func isRoad(at t: TileIndex) -> Bool { road[Int(t.raw)] }

    /// A tile the road network can traverse. Buildings are passable so that a house
    /// touching a road is reachable without modelling doorways.
    @inlinable public func isPassable(_ t: TileIndex) -> Bool {
        let i = Int(t.raw)
        return road[i] || buildingAt[i] >= 0
    }

    public func neighbours(of t: TileIndex) -> [TileIndex] {
        let cx = x(of: t), cy = y(of: t)
        var out: [TileIndex] = []
        out.reserveCapacity(4)
        if cx > 0 { out.append(TileIndex(t.raw - 1)) }
        if cx < width - 1 { out.append(TileIndex(t.raw + 1)) }
        if cy > 0 { out.append(TileIndex(t.raw - width)) }
        if cy < height - 1 { out.append(TileIndex(t.raw + width)) }
        return out
    }
}
