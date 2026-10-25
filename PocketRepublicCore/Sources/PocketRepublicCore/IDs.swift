import Foundation

// Stable, small, deterministic identities. Deliberately not UUID: these are
// cross-referenced by buildings, households and the road graph, and they must be
// reproducible from a seed and cheap in the save file.

public struct CitizenID: Hashable, Codable, Comparable, Sendable {
    public let raw: Int32
    public init(_ raw: Int32) { self.raw = raw }
    public static func < (a: Self, b: Self) -> Bool { a.raw < b.raw }
}

public struct BuildingID: Hashable, Codable, Comparable, Sendable {
    public let raw: Int32
    public init(_ raw: Int32) { self.raw = raw }
    public static func < (a: Self, b: Self) -> Bool { a.raw < b.raw }
    public static let none = BuildingID(-1)
}

public struct DistrictID: Hashable, Codable, Comparable, Sendable {
    public let raw: UInt8
    public init(_ raw: UInt8) { self.raw = raw }
    public static func < (a: Self, b: Self) -> Bool { a.raw < b.raw }
}

public struct TileIndex: Hashable, Codable, Comparable, Sendable {
    public let raw: Int32
    public init(_ raw: Int32) { self.raw = raw }
    public static func < (a: Self, b: Self) -> Bool { a.raw < b.raw }
}

public struct EventID: Hashable, Codable, Comparable, Sendable {
    public let raw: Int64
    public init(_ raw: Int64) { self.raw = raw }
    public static func < (a: Self, b: Self) -> Bool { a.raw < b.raw }
}

public struct DecisionID: Hashable, Codable, Sendable {
    public let raw: Int64
    public init(_ raw: Int64) { self.raw = raw }
}
