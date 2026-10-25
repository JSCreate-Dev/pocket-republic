import Foundation

/// SplitMix64. Value type, Codable, and stored *inside* the world state so that
/// save -> load resumes the identical stream. The global `Int.random` is banned in
/// this module; a non-reproducible world cannot be tested, bisected or replayed.
public struct SeededRNG: RandomNumberGenerator, Codable, Sendable, Equatable {
    public private(set) var state: UInt64

    public init(seed: UInt64) { self.state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Inclusive integer in range, drawn from this stream.
    public mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// True with probability `percent`/100.
    public mutating func chance(_ percent: Int) -> Bool {
        guard percent > 0 else { return false }
        return int(0...99) < percent
    }

    /// A derived independent stream, so adding a new system that draws numbers does
    /// not shift every existing draw and invalidate saved worlds.
    public func substream(_ salt: UInt64) -> SeededRNG {
        SeededRNG(seed: state ^ (salt &* 0x9E37_79B9_7F4A_7C15))
    }
}
