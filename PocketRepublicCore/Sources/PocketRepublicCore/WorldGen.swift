import Foundation

/// Deterministic world construction. Same seed + same config => byte-identical world.
public enum WorldGenerator {

    public static let districtNames = [
        "Old Town", "Harbour", "East Docks", "Hillside", "Mill Quarter",
        "Saltmarsh", "North Fields", "Cane Row", "Stonegate"
    ]

    static let firstNames = [
        "Mateo", "Sofia", "Diego", "Elena", "Lucia", "Rafael", "Isabel", "Carlos",
        "Nina", "Tomas", "Amara", "Luis", "Carmen", "Pablo", "Maya", "Andres",
        "Rosa", "Felix", "Ana", "Hugo", "Lena", "Marco", "Eva", "Javier", "Clara"
    ]
    static let surnames = [
        "Ruiz", "Castro", "Navarro", "Vega", "Molina", "Serrano", "Pardo",
        "Ibarra", "Quintana", "Salazar", "Montero", "Rivas"
    ]

    public static func generate(seed: UInt64,
                                citizenCount: Int = 120,
                                size: Int32 = 64,
                                config: BalanceConfig = BalanceConfig()) -> RepublicState {
        var map = WorldMap(width: size, height: size)
        var rng = SeededRNG(seed: seed ^ 0xA5A5_1234_DEAD_BEEF)

        // Terrain: water margin, fertile belts inland.
        for y in 0..<size {
            for x in 0..<size {
                let t = map.index(x: x, y: y)
                let edge = min(min(x, y), min(size - 1 - x, size - 1 - y))
                let kind: TerrainKind
                if edge < 3 { kind = .water }
                else if edge < 5 { kind = .sand }
                else if (x &* 7 &+ y &* 13) % 11 < 3 { kind = .fertile }
                else if (x &* 3 &+ y &* 5) % 23 == 0 { kind = .rock }
                else { kind = .grass }
                map.terrain[Int(t.raw)] = kind.rawValue
            }
        }

        // Districts: 3x3 blocks over the land area.
        var districts: [District] = []
        for i in 0..<9 { districts.append(District(id: DistrictID(UInt8(i)), name: districtNames[i])) }
        let band = size / 3
        for y in 0..<size {
            for x in 0..<size {
                let dx = min(2, x / band), dy = min(2, y / band)
                map.districtAt[Int(map.index(x: x, y: y).raw)] = UInt8(dy * 3 + dx)
            }
        }
        for i in 0..<9 {
            let cx = (Int32(i % 3) * band) + band / 2
            let cy = (Int32(i / 3) * band) + band / 2
            districts[i].centroid = map.index(x: cx, y: cy)
        }

        // Road grid every 6 tiles across buildable land.
        for y in 5..<(size - 5) {
            for x in 5..<(size - 5) {
                guard map.terrain(at: map.index(x: x, y: y)).buildable else { continue }
                if x % 6 == 2 || y % 6 == 2 { map.road[Int(map.index(x: x, y: y).raw)] = true }
            }
        }

        var state = RepublicState(worldSeed: seed, config: config, map: map)
        state.districts = districts

        // Civic core at the island centre.
        let mid = size / 2
        _ = place(&state, .townHall, near: state.map.index(x: mid, y: mid))

        // Every district gets a market. A starting city that is already in permanent
        // crisis is untunable; pressure should come from the player outgrowing the
        // services, not from day one. Clinics, schools and police are deliberately
        // sparser, so coverage gaps exist to be noticed and fixed.
        for d in state.districts {
            _ = place(&state, .market, near: d.centroid)
        }
        for i in [0, 4, 8] {
            _ = place(&state, .clinic, near: state.districts[i].centroid)
        }
        for i in [1, 7] {
            _ = place(&state, .school, near: state.districts[i].centroid)
        }
        for i in [0, 2, 4, 6, 8] {
            _ = place(&state, .police, near: state.districts[i].centroid)
        }
        _ = place(&state, .dock, near: state.map.index(x: mid, y: size - 7))

        let farmCount = max(5, citizenCount / 14)
        for _ in 0..<farmCount {
            let x = Int32(rng.int(7...Int(size - 8)))
            let y = Int32(rng.int(7...Int(size - 8)))
            _ = place(&state, .farm, near: state.map.index(x: x, y: y))
        }
        let workshopCount = max(4, citizenCount / 9)
        for _ in 0..<workshopCount {
            let x = Int32(rng.int(8...Int(size - 9)))
            let y = Int32(rng.int(8...Int(size - 9)))
            _ = place(&state, .workshop, near: state.map.index(x: x, y: y))
        }

        // Housing to cover the starting population.
        var housed: Int32 = 0
        var attempt: Int32 = 0
        while housed < Int32(citizenCount) && attempt < Int32(citizenCount) * 8 {
            let x = Int32(rng.int(6...Int(size - 7)))
            let y = Int32(rng.int(6...Int(size - 7)))
            if let id = place(&state, .house, near: state.map.index(x: x, y: y)) {
                housed += state.buildings[Int(id.raw)].kind.housingCapacity
            }
            attempt += 1
        }

        // Citizens, assigned to homes in a fixed order.
        for _ in 0..<citizenCount {
            guard let homeID = freeHouse(&state) else { break }
            let cid = CitizenID(state.nextCitizenRaw)
            state.nextCitizenRaw += 1
            let name = "\(firstNames[rng.int(0...(firstNames.count - 1))]) \(surnames[rng.int(0...(surnames.count - 1))])"
            let homeTile = state.buildings[Int(homeID.raw)].tile
            var c = Citizen(id: cid,
                            name: name,
                            age: Int32(rng.int(18...68)),
                            district: state.map.district(at: homeTile),
                            money: Int64(rng.int(20...90)),
                            happiness: Int32(rng.int(45...70)),
                            loyalty: Int32(rng.int(40...70)),
                            ambition: Int32(rng.int(10...95)),
                            influence: Int32(rng.int(5...80)))
            c.home = homeID
            state.citizens.append(c)
            state.buildings[Int(homeID.raw)].residents.append(cid)
        }

        // Opening balances. Everything after this point is conserved.
        state.treasury = 4000
        for i in state.buildings.indices where !state.buildings[i].kind.isCivic {
            state.buildings[i].funds = 60
        }
        state.ledger.openingMoney = state.totalMoneyInWorld

        // Seed the markets so day 1 is not an instant famine; recorded as an import.
        for i in state.buildings.indices where state.buildings[i].kind == .market {
            state.buildings[i].foodStore = 60
            state.ledger.foodImported += 60
        }

        state.rng = SeededRNG(seed: seed)
        state.fields.markDirty()
        return state
    }

    static func freeHouse(_ s: inout RepublicState) -> BuildingID? {
        for b in s.buildings where b.kind == .house
            && Int32(b.residents.count) < b.kind.housingCapacity {
            return b.id
        }
        return nil
    }

    /// Place on the first buildable, unoccupied, non-road tile at or near `target`,
    /// spiralling outward. Deterministic.
    @discardableResult
    static func place(_ s: inout RepublicState, _ kind: BuildingKind, near target: TileIndex) -> BuildingID? {
        let tx = s.map.x(of: target), ty = s.map.y(of: target)
        for radius in 0..<12 {
            for dy in -Int32(radius)...Int32(radius) {
                for dx in -Int32(radius)...Int32(radius) {
                    guard max(abs(dx), abs(dy)) == Int32(radius) || radius == 0 else { continue }
                    let x = tx + dx, y = ty + dy
                    guard s.map.contains(x: x, y: y) else { continue }
                    let t = s.map.index(x: x, y: y)
                    guard s.map.terrain(at: t).buildable,
                          s.map.building(at: t) == nil,
                          !s.map.isRoad(at: t),
                          touchesRoad(s.map, t) else { continue }
                    return construct(&s, kind, at: t)
                }
            }
        }
        return nil
    }

    static func touchesRoad(_ map: WorldMap, _ t: TileIndex) -> Bool {
        map.neighbours(of: t).contains { map.isRoad(at: $0) }
    }

    static func construct(_ s: inout RepublicState, _ kind: BuildingKind, at t: TileIndex) -> BuildingID {
        let id = BuildingID(s.nextBuildingRaw)
        s.nextBuildingRaw += 1
        let b = Building(id: id, kind: kind, tile: t,
                         district: s.map.district(at: t), builtOnDay: s.day)
        s.buildings.append(b)
        s.map.buildingAt[Int(t.raw)] = id.raw
        s.fields.markDirty()
        return id
    }
}
