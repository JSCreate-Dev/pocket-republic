import Combine
import Foundation
import PocketRepublicCore

/// The app boundary: intents go into the core, then a new read-only state goes to UI.
@MainActor final class Game: ObservableObject {
    @Published private(set) var state: RepublicState
    @Published private(set) var saveIssue: String?
    @Published private(set) var feedback: String?

    /// The old prototype's UserDefaults save is intentionally left untouched.
    let hasPrototypeSave: Bool
    private let saveURL: URL?

    init() {
        hasPrototypeSave = UserDefaults.standard.object(forKey: "pocket.republic.save.v1") != nil
        let url = try? Self.makeSaveURL()
        saveURL = url

        if let url, FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let file = try JSONDecoder().decode(SpatialSave.self, from: data)
                let loaded = file.state
                guard file.formatVersion == 1,
                      file.checksum != 0,
                      file.checksum == loaded.stateHash(),
                      Self.isValid(loaded) else {
                    throw SaveError.invalidState
                }
                state = loaded
                saveIssue = nil
            } catch {
                state = Self.freshState()
                saveIssue = "The city save could not be read. It is preserved; choose Start New City in Govern to replace it."
            }
        } else {
            state = Self.freshState()
            saveIssue = url == nil ? "City storage is unavailable on this device." : nil
        }
        if let url, !FileManager.default.fileExists(atPath: url.path) {
            save()
        }
    }

    var snapshot: WorldSnapshot { state.snapshot() }

    func send(_ intent: PlayerIntent) {
        guard saveIssue == nil else { return }
        var next = state
        switch SimulationEngine.apply(intent, to: &next) {
        case .accepted:
            state = next
            feedback = nil
            save()
        case .rejected(let reason):
            feedback = reason.playerFacingReason
        }
    }

    func advance() {
        guard saveIssue == nil else { return }
        guard !state.blocksAdvance else {
            feedback = "Resolve the crisis before advancing."
            return
        }
        var next = state
        SimulationEngine.advance(&next)
        state = next
        feedback = nil
        save()
    }

    func startNewCity() {
        guard let saveURL else {
            saveIssue = "City storage is unavailable on this device."
            return
        }
        do {
            if FileManager.default.fileExists(atPath: saveURL.path) {
                try FileManager.default.removeItem(at: saveURL)
            }
            state = Self.freshState()
            saveIssue = nil
            feedback = nil
            save()
        } catch {
            saveIssue = "Could not replace the city save: \(error.localizedDescription)"
        }
    }

    private func save() {
        guard saveIssue == nil, let saveURL else { return }
        var saved = state
        saved.trimEvents(keepingLast: 500)
        do {
            let data = try JSONEncoder().encode(SpatialSave(
                formatVersion: 1,
                checksum: saved.stateHash(),
                state: saved
            ))
            try data.write(to: saveURL, options: .atomic)
            state = saved
        } catch {
            saveIssue = "City changes could not be saved: \(error.localizedDescription)"
        }
    }

    private static func freshState() -> RepublicState {
        WorldGenerator.generate(seed: UInt64.random(in: UInt64.min...UInt64.max))
    }

    private static func isValid(_ saved: RepublicState) -> Bool {
        let map = saved.map
        guard saved.schemaVersion == RepublicState.currentSchemaVersion,
              map.width > 0, map.height > 0, map.width <= 256, map.height <= 256,
              !saved.districts.isEmpty, saved.districts.count <= 256,
              saved.factions.count == FactionKind.allCases.count,
              saved.crisisKindCooldown.count == DecisionKind.allCases.count else { return false }
        let count = Int(map.width) * Int(map.height)
        guard map.terrain.count == count, map.districtAt.count == count,
              map.road.count == count, map.buildingAt.count == count,
              map.districtAt.allSatisfy({ Int($0) < saved.districts.count }) else { return false }

        func validTile(_ tile: TileIndex) -> Bool {
            tile.raw >= 0 && Int(tile.raw) < count
        }
        func validBuilding(_ id: BuildingID) -> Bool {
            id.raw >= 0 && Int(id.raw) < saved.buildings.count
        }
        func validCitizen(_ id: CitizenID) -> Bool {
            id.raw >= 0 && Int(id.raw) < saved.citizens.count
        }
        func validDistrict(_ id: DistrictID) -> Bool {
            Int(id.raw) < saved.districts.count
        }
        func validLocation(_ location: EventLocation) -> Bool {
            (location.tile.map(validTile) ?? true)
                && (location.building.map(validBuilding) ?? true)
                && (location.district.map(validDistrict) ?? true)
        }

        for (index, district) in saved.districts.enumerated() {
            guard district.id.raw == UInt8(index), validTile(district.centroid),
                  district.servingMarket.map(validBuilding) ?? true else { return false }
        }
        for (index, faction) in saved.factions.enumerated() {
            guard faction.kind.rawValue == UInt8(index) else { return false }
        }
        for (index, building) in saved.buildings.enumerated() {
            guard building.id.raw == Int32(index), validTile(building.tile),
                  validDistrict(building.district),
                  building.workers.allSatisfy(validCitizen),
                  building.residents.allSatisfy(validCitizen) else { return false }
        }
        for (tile, raw) in map.buildingAt.enumerated() {
            guard raw >= -1 else { return false }
            if raw >= 0 {
                guard validBuilding(BuildingID(raw)),
                      saved.buildings[Int(raw)].tile.raw == Int32(tile) else { return false }
            }
        }
        for (index, citizen) in saved.citizens.enumerated() {
            guard citizen.id.raw == Int32(index), validDistrict(citizen.district) else { return false }
            for id in [citizen.home, citizen.work].compactMap({ $0 }) {
                guard validBuilding(id) else { return false }
            }
        }
        if !saved.fields.dirty {
            guard saved.fields.fields.count == ServiceKind.allCases.count,
                  saved.fields.fields.allSatisfy({ $0.count == count }),
                  saved.fields.component.count == count,
                  saved.fields.nearestMarket.count == count else { return false }
            for raw in saved.fields.nearestMarket where raw >= 0 {
                guard validBuilding(BuildingID(raw)) else { return false }
            }
        }
        if let pending = saved.pending {
            guard validLocation(pending.location), !pending.options.isEmpty else { return false }
        }
        for item in saved.agenda {
            guard validLocation(item.location), !item.options.isEmpty else { return false }
        }
        for event in saved.events where !validLocation(event.location) { return false }
        return true
    }

    private static func makeSaveURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent("PocketRepublic", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("spatial-v1.json")
    }

    private enum SaveError: Error { case invalidState }
}

private struct SpatialSave: Codable {
    let formatVersion: Int
    let checksum: UInt64
    let state: RepublicState
}
