import Foundation

/// What walker routing needs from the building layer.
///
/// A building covers its footprint. `Building.tile` is the entrance
/// (`Building.entrance`), and that is the only footprint tile
/// `WorldMap.isPassable` allows. `MapBuildingAccess` records that door and
/// forwards `isPassable` and `building(at:)`. This file does not redefine
/// passability.
public protocol BuildingAccess {
    func building(at tile: TileIndex) -> BuildingID?
    func entrance(of building: BuildingID) -> TileIndex?
    func isPassable(_ tile: TileIndex) -> Bool
}

public struct MapBuildingAccess: BuildingAccess, Sendable {
    public let map: WorldMap
    /// Entrance tile raw, indexed by `BuildingID.raw`. -1 if that slot is empty.
    public let entranceTile: [Int32]

    public init(map: WorldMap, buildings: [Building]) {
        self.map = map
        var tiles = [Int32](repeating: -1, count: buildings.count)
        for b in buildings where b.occupiesGround(on: map) {
            let i = Int(b.id.raw)
            if i >= 0, i < tiles.count { tiles[i] = b.tile.raw }
        }
        self.entranceTile = tiles
    }

    public func building(at tile: TileIndex) -> BuildingID? { map.building(at: tile) }

    public func entrance(of building: BuildingID) -> TileIndex? {
        let i = Int(building.raw)
        guard i >= 0, i < entranceTile.count, entranceTile[i] >= 0 else { return nil }
        return TileIndex(entranceTile[i])
    }

    public func isPassable(_ tile: TileIndex) -> Bool { map.isPassable(tile) }
}

extension RepublicState {
    public func buildingAccess() -> MapBuildingAccess {
        MapBuildingAccess(map: map, buildings: buildings)
    }
}

public enum Pathfinder {
    /// Shortest walk under `access.isPassable`. Neighbour order is the map's
    /// fixed west, east, north, south by default. A nonzero variation rotates
    /// equal-distance choices deterministically without taking longer detours.
    public static func path<A: BuildingAccess>(from start: TileIndex, to end: TileIndex,
                                               map: WorldMap, access: A, variation: UInt64 = 0) -> [TileIndex] {
        if start == end { return [start] }
        let n = map.tileCount
        guard Int(start.raw) >= 0, Int(start.raw) < n, Int(end.raw) >= 0, Int(end.raw) < n else {
            return [start]
        }
        guard access.isPassable(end) else { return [start] }
        var parent = [Int32](repeating: -1, count: n)
        parent[Int(start.raw)] = start.raw
        var queue = [Int32](repeating: 0, count: n)
        var head = 0
        var tail = 1
        queue[0] = start.raw
        while head < tail {
            let cur = queue[head]
            head += 1
            if cur == end.raw { break }
            let neighbours = map.neighbours(of: TileIndex(cur))
            let offset = variation == 0 ? 0 : Int((variation &+ UInt64(cur)) % UInt64(max(1, neighbours.count)))
            for index in neighbours.indices {
                let next = neighbours[(index + offset) % neighbours.count]
                let ni = Int(next.raw)
                guard parent[ni] < 0 else { continue }
                guard access.isPassable(next) else { continue }
                parent[ni] = cur
                queue[tail] = next.raw
                tail += 1
            }
        }
        guard parent[Int(end.raw)] >= 0 else { return [start] }
        var reversed = [end]
        var cur = end.raw
        while cur != start.raw {
            let previous = parent[Int(cur)]
            if previous < 0 || previous == cur { break }
            cur = previous
            reversed.append(TileIndex(cur))
        }
        return Array(reversed.reversed())
    }
}

/// One citizen's day: home, then work if they have it, then the market they buy
/// food from, then home again. Hours are 0..<24 inside the simulated day.
public struct DailyRoutine: Equatable, Sendable {
    public enum Stop: String, Equatable, Sendable {
        case home, work, market, clinic, civic, leisure
    }

    public var stops: [Stop]
    public var entrances: [TileIndex]
    /// Inclusive hour the citizen is standing on `entrances[i]`.
    public var dwellStart: [Int]
    /// Exclusive hour that dwell ends. The gap before the next dwell is travel.
    public var dwellEnd: [Int]
    /// `legPaths[i]` walks from `entrances[i]` to `entrances[i + 1]`, both ends included.
    public var legPaths: [[TileIndex]]
    public var path: [TileIndex]

    public func tile(atHour hour: Int) -> TileIndex {
        let h = min(23, max(0, hour))
        guard let fallback = entrances.first ?? path.first else { return TileIndex(0) }
        for i in dwellStart.indices where i < dwellEnd.count && i < entrances.count {
            if h >= dwellStart[i] && h < dwellEnd[i] { return entrances[i] }
        }
        for i in 0..<(entrances.count - 1) where i < legPaths.count && i < dwellEnd.count && (i + 1) < dwellStart.count {
            let leave = dwellEnd[i]
            let arrive = dwellStart[i + 1]
            if h >= leave && h < arrive {
                return Self.along(legPaths[i], fromHour: leave, toHour: arrive, hour: h)
            }
        }
        return entrances.last ?? fallback
    }

    static func along(_ leg: [TileIndex], fromHour: Int, toHour: Int, hour: Int) -> TileIndex {
        guard let first = leg.first else { return TileIndex(0) }
        guard leg.count > 1, toHour > fromHour else { return leg.last ?? first }
        let span = toHour - fromHour
        let steps = leg.count - 1
        let t = hour - fromHour
        let idx = min(steps, max(1, (steps * (t + 1)) / span))
        return leg[idx]
    }
}

public enum WalkerRoutine {
    public static func plan<A: BuildingAccess>(for citizen: Citizen, in state: RepublicState,
                                               access: A) -> DailyRoutine {
        guard let home = citizen.home, let homeDoor = access.entrance(of: home) else {
            return DailyRoutine(stops: [], entrances: [], dwellStart: [], dwellEnd: [],
                                legPaths: [], path: [])
        }
        var stops: [DailyRoutine.Stop] = [.home]
        var doors = [homeDoor]
        // A stop is meaningful only if the citizen can actually reach it from
        // the previous destination. Never animate a jump across a broken road.
        func append(_ stop: DailyRoutine.Stop, door: TileIndex) {
            guard door != doors.last else { return }
            let route = Pathfinder.path(from: doors.last!, to: door, map: state.map, access: access)
            guard route.last == door else { return }
            stops.append(stop)
            doors.append(door)
        }
        if let work = citizen.work, state.buildings[Int(work.raw)].isStanding(on: state.map),
           let door = access.entrance(of: work) {
            append(.work, door: door)
        }
        let homeTile = state.buildings[Int(home.raw)].tile
        if let market = SimulationEngine.shoppingMarket(state, homeTile: homeTile),
           let door = access.entrance(of: market) {
            append(.market, door: door)
        }
        // Purposeful extra trips. Older residents visit a clinic periodically;
        // discontented residents gather at the hall; others sometimes socialise.
        // The seed/identity/day offset varies the day without consuming saved RNG.
        let phase = (UInt64(citizen.id.raw) &+ state.worldSeed &+ UInt64(max(0, state.day))) % 5
        let visit: (BuildingKind, DailyRoutine.Stop)?
        if citizen.age >= 55 && phase == 0 { visit = (.clinic, .clinic) }
        else if citizen.loyalty < 30 && phase < 2 { visit = (.townHall, .civic) }
        else if citizen.daysHungry == 0 && phase == 2 { visit = (.market, .leisure) }
        else { visit = nil }
        if let (kind, purpose) = visit {
            let candidates = state.buildings.filter { $0.kind == kind && $0.isStanding(on: state.map) }
                .sorted {
                    let a = SimulationEngine.manhattan(state.map, homeDoor, $0.tile)
                    let b = SimulationEngine.manhattan(state.map, homeDoor, $1.tile)
                    return a == b ? $0.id.raw < $1.id.raw : a < b
                }
            if let destination = candidates.first(where: { building in
                guard let door = access.entrance(of: building.id) else { return false }
                let route = Pathfinder.path(from: homeDoor, to: door, map: state.map, access: access)
                return route.last == door && route.count <= Int(state.config.maxServiceDistance) + 1
            }), let door = access.entrance(of: destination.id) {
                append(purpose, door: door)
            }
        }
        if stops.count == 1 {
            return DailyRoutine(stops: [.home], entrances: [homeDoor],
                                dwellStart: [0], dwellEnd: [24], legPaths: [], path: [homeDoor])
        }
        stops.append(.home)
        doors.append(homeDoor)

        let (dwellStart, dwellEnd) = dwells(for: stops, citizen: citizen, day: state.day)
        var legs: [[TileIndex]] = []
        var full: [TileIndex] = []
        for i in 1..<doors.count {
            // Stable per citizen, day and leg. Equal-length routes vary without
            // consuming saved RNG or changing shortest-path service distances.
            let variation = state.worldSeed &+ UInt64(max(0, citizen.id.raw)) &* 31
                &+ UInt64(max(0, state.day)) &* 17 &+ UInt64(i) &* 7 &+ 1
            let leg = Pathfinder.path(from: doors[i - 1], to: doors[i], map: state.map,
                                      access: access, variation: variation)
            legs.append(leg)
            if full.isEmpty { full = leg }
            else { full.append(contentsOf: leg.dropFirst()) }
        }
        return DailyRoutine(stops: stops, entrances: doors, dwellStart: dwellStart,
                            dwellEnd: dwellEnd, legPaths: legs, path: full)
    }

    /// Different occupations start at different hours. Individual and daily
    /// offsets keep the town from moving in lockstep; all gaps remain travel.
    static func dwells(for stops: [DailyRoutine.Stop], citizen: Citizen, day: Int32) -> (start: [Int], end: [Int]) {
        let hasWork = stops.contains(.work)
        let hasVisit = stops.contains(.clinic) || stops.contains(.civic) || stops.contains(.leisure)
        let shift = Int((Int64(citizen.id.raw) + Int64(max(0, day))) % 3) - 1
        let early = citizen.occupation == .farmer || citizen.occupation == .dockhand
        let workStart = (early ? 7 : 8) + shift
        var start: [Int] = []
        var end: [Int] = []
        for stop in stops {
            switch stop {
            case .home where start.isEmpty:
                start.append(0); end.append(hasWork ? workStart - 1 : 7 + shift)
            case .work:
                start.append(workStart); end.append(14 + shift)
            case .market:
                start.append(hasWork ? 16 + shift : 9 + shift)
                end.append(hasWork ? 17 + shift : 11 + shift)
            case .clinic, .civic, .leisure:
                start.append(hasWork ? 19 : 14 + shift)
                end.append(hasWork ? 21 : 17 + shift)
            case .home:
                start.append(hasVisit ? (hasWork ? 22 : 19 + shift) : (hasWork ? 20 : 14 + shift))
                end.append(24)
            }
        }
        return (start, end)
    }
}
