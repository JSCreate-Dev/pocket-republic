import Combine
import Foundation
import PocketRepublicCore

/// Intents remain on the main actor. Launch/recovery file work runs off actor;
/// normal autosave retains the existing synchronous, ordered write boundary.
@MainActor final class Game: ObservableObject {
    @Published private(set) var state: RepublicState
    @Published private(set) var saveIssue: String?
    @Published private(set) var feedback: String?
    @Published private(set) var launchReady = false
    @Published private(set) var loadingMessage = "Opening your republic…"
    @Published private(set) var busy = false
    @Published private(set) var lastSavedAt: Date?
    @Published private(set) var backupPreview: CitySavePreview?
    @Published private(set) var canRetrySave = false
    @Published private(set) var citySession = UUID()
    let hasPrototypeSave: Bool
    private let repository: CitySaveRepository?
    private var preparing = false

    init(saveLocation: URL? = nil) {
        hasPrototypeSave = UserDefaults.standard.object(forKey: "pocket.republic.save.v1") != nil
        repository = (saveLocation ?? (try? Self.makeSaveURL())).map(CitySaveRepository.init(primary:))
        // Never shown or persisted. Heavy decoding/world generation happens only
        // after the launch view has mounted, not inside StateObject creation.
        state = RepublicState(worldSeed: 0, config: BalanceConfig(), map: WorldMap(width: 1, height: 1))
    }

    var snapshot: WorldSnapshot { state.snapshot() }
    func clearFeedback() { feedback = nil }

    func prepare() async {
        guard !preparing, !launchReady else { return }
        preparing = true; busy = true
        defer { preparing = false; busy = false; launchReady = true }
        guard let repository else { saveIssue = "City storage is unavailable on this device."; return }
        loadingMessage = "Checking your saved island…"
        let result = await Task.detached(priority: .userInitiated) { repository.load() }.value
        backupPreview = result.backup
        if let saved = result.state {
            state = saved; lastSavedAt = result.savedAt; saveIssue = nil
        } else if let issue = result.issue {
            saveIssue = issue
        } else {
            loadingMessage = "Preparing a new island…"
            let fresh = await Task.detached(priority: .userInitiated) { Self.freshState() }.value
            do {
                loadingMessage = "Saving your founding charter…"
                let date = try await Task.detached(priority: .userInitiated) { try repository.write(fresh) }.value
                state = fresh; lastSavedAt = date; saveIssue = nil
            } catch { state = fresh; canRetrySave = true; saveIssue = "The new island could not be saved. Retry before playing." }
        }
    }

    @discardableResult func send(_ intent: PlayerIntent) -> Bool {
        guard launchReady, !busy, saveIssue == nil else { return false }
        var next = state
        switch SimulationEngine.apply(intent, to: &next) {
        case .accepted:
            state = next; feedback = nil; save(); return true
        case .rejected(let reason):
            if case .placeBuilding(let kind, _) = intent,
               let locked = DevelopmentTree.lockReason(for: kind, in: state) { feedback = locked }
            else { feedback = reason.playerFacingReason }
            return false
        }
    }

    func advance() {
        guard launchReady, !busy, saveIssue == nil else { return }
        guard !state.blocksAdvance else { feedback = "Resolve the crisis before advancing."; return }
        var next = state
        SimulationEngine.advance(&next)
        state = next; feedback = nil; save()
    }

    @discardableResult func startNewCity(origin: RepublicOrigin? = nil) async -> Bool {
        guard !busy else { return false }
        guard let repository else { feedback = "City storage is unavailable. The selected city was not replaced."; return false }
        busy = true; defer { busy = false }
        let fresh = await Task.detached(priority: .userInitiated) { Self.freshState(origin: origin) }.value
        do {
            let date = try await Task.detached(priority: .userInitiated) { try repository.write(fresh) }.value
            // Publish only after replacement succeeds. Never delete the old file
            // first and never replace the live city with an unsaved draft.
            state = fresh; citySession = UUID(); lastSavedAt = date; saveIssue = nil; canRetrySave = false; feedback = nil
            refreshBackup(); return true
        } catch {
            feedback = "The new city was not created. The selected city is unchanged. Check available device storage and try again."
            return false
        }
    }

    func retrySave() {
        guard canRetrySave, !busy else { return }
        saveIssue = nil
        save()
    }

    func saveNow() {
        guard launchReady, !busy, saveIssue == nil else { return }
        feedback = nil
        save()
    }

    @discardableResult func retryLoad() async -> Bool {
        guard !busy, !canRetrySave, let repository else { return false }
        busy = true; defer { busy = false }
        let result = await Task.detached(priority: .userInitiated) { repository.load() }.value
        backupPreview = result.backup
        guard let saved = result.state else {
            saveIssue = result.issue ?? "No saved island was found. Choose New City deliberately to begin."
            return false
        }
        state = saved; citySession = UUID(); lastSavedAt = result.savedAt; saveIssue = nil; feedback = nil
        return true
    }

    @discardableResult func restoreBackup() async -> Bool {
        guard !busy, let repository else { return false }
        busy = true; defer { busy = false }
        do {
            let restored = try await Task.detached(priority: .userInitiated) { try repository.restore() }.value
            state = restored.state; citySession = UUID(); lastSavedAt = restored.savedAt; saveIssue = nil; canRetrySave = false; feedback = nil
            refreshBackup(); return true
        } catch { feedback = "The backup was not restored. The selected city is unchanged. Check device storage or try loading again."; return false }
    }

    private func save() {
        guard saveIssue == nil, let repository else { return }
        var saved = state; saved.trimEvents(keepingLast: 500)
        do {
            lastSavedAt = try repository.write(saved)
            state = saved; canRetrySave = false
        } catch {
            canRetrySave = true
            saveIssue = "City changes could not be saved. Play is paused; Retry Save keeps your current changes."
        }
    }

    func refreshBackup() { backupPreview = repository?.backupSummary() }

    nonisolated private static func freshState(origin: RepublicOrigin? = nil) -> RepublicState {
        WorldGenerator.generate(seed: UInt64.random(in: UInt64.min...UInt64.max), origin: origin)
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

}

// MARK: - Foundation save boundary
struct CitySavePreview: Sendable {
    let day: Int32
    let residents: Int
    let savedAt: Date?
    init(state: RepublicState, savedAt: Date?) {
        day = state.day; residents = state.citizens.filter(\.alive).count; self.savedAt = savedAt
    }
}

struct CitySaveLoad: Sendable {
    let state: RepublicState?
    let savedAt: Date?
    let backup: CitySavePreview?
    let issue: String?
}

struct CitySaveRepository: Sendable {
    let primary: URL
    var backup: URL { primary.deletingLastPathComponent().appendingPathComponent("spatial-backup.json") }
    var preserved: URL { primary.deletingLastPathComponent().appendingPathComponent("spatial-preserved.json") }
    var preservedBackup: URL { primary.deletingLastPathComponent().appendingPathComponent("spatial-preserved-backup.json") }

    func load() -> CitySaveLoad {
        let preview = backupSummary()
        guard FileManager.default.fileExists(atPath: primary.path) else {
            // Do not silently create a fresh city over a missing primary when a
            // backup exists; make recovery an explicit player choice.
            return CitySaveLoad(state: nil, savedAt: nil, backup: preview,
                issue: FileManager.default.fileExists(atPath: backup.path)
                    ? (preview == nil ? "The main city file is missing and the backup could not be verified. Files are preserved; retry loading or deliberately choose New City."
                       : "The main city file is missing. Restore the verified backup or choose New City.") : nil)
        }
        do {
            let state = try CitySaveCodec.decode(Data(contentsOf: primary))
            return CitySaveLoad(state: state, savedAt: modificationDate(primary), backup: preview, issue: nil)
        } catch {
            return CitySaveLoad(state: nil, savedAt: nil, backup: preview,
                issue: "The saved city could not be verified. Its file is preserved. Retry Load or choose from the available recovery options below.")
        }
    }

    @discardableResult func write(_ state: RepublicState) throws -> Date {
        let data = try CitySaveCodec.encode(state)
        if FileManager.default.fileExists(atPath: primary.path) {
            let old = try Data(contentsOf: primary)
            if let previous = try? CitySaveCodec.decode(old) {
                if previous.stateHash() == state.stateHash() { return modificationDate(primary) ?? Date() }
                if FileManager.default.fileExists(atPath: backup.path) {
                    let previousBackup = try Data(contentsOf: backup)
                    if (try? CitySaveCodec.decode(previousBackup)) == nil {
                        try previousBackup.write(to: preservedBackup, options: .atomic)
                    }
                }
                try old.write(to: backup, options: .atomic)
            } else {
                try old.write(to: preserved, options: .atomic)
            }
        }
        try data.write(to: primary, options: .atomic)
        return modificationDate(primary) ?? Date()
    }

    func restore() throws -> (state: RepublicState, savedAt: Date) {
        let data = try Data(contentsOf: backup)
        let saved = try CitySaveCodec.decode(data)
        // Preserve the current primary separately; never rotate it over the
        // chosen recovery point, and never touch backup on failed restoration.
        if FileManager.default.fileExists(atPath: primary.path) {
            try Data(contentsOf: primary).write(to: preserved, options: .atomic)
        }
        try data.write(to: primary, options: .atomic)
        return (saved, modificationDate(primary) ?? Date())
    }

    func backupSummary() -> CitySavePreview? {
        guard let data = try? Data(contentsOf: backup), let state = try? CitySaveCodec.decode(data) else { return nil }
        return CitySavePreview(state: state, savedAt: modificationDate(backup))
    }

    private func modificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }
}

struct SpatialSave: Codable {
    let formatVersion: Int
    let checksum: UInt64
    let state: RepublicState
}

enum CitySaveCodec {
    enum Failure: Error { case invalidState }
    static func decode(_ data: Data) throws -> RepublicState {
        let file = try JSONDecoder().decode(SpatialSave.self, from: data)
        guard file.formatVersion == 1, isValid(file.state), file.checksum != 0,
              file.checksum == file.state.stateHash() else { throw Failure.invalidState }
        try file.state.checkConservation()
        return file.state
    }
    static func encode(_ state: RepublicState) throws -> Data {
        guard isValid(state) else { throw Failure.invalidState }
        try state.checkConservation()
        return try JSONEncoder().encode(SpatialSave(formatVersion: 1, checksum: state.stateHash(), state: state))
    }
    static func isValid(_ saved: RepublicState) -> Bool {
        let map = saved.map
        guard saved.schemaVersion == RepublicState.currentSchemaVersion,
              map.width > 0, map.height > 0, map.width <= 256, map.height <= 256,
              !saved.districts.isEmpty, saved.districts.count <= 256,
              saved.factions.count == FactionKind.allCases.count,
              saved.crisisKindCooldown.count == DecisionKind.allCases.count else { return false }
        let count = Int(map.width) * Int(map.height)
        guard map.terrain.count == count, map.districtAt.count == count,
              map.road.count == count, map.buildingAt.count == count,
              map.entranceAt.count == count,
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
            guard building.id.raw == Int32(index),
                  validTile(building.anchor), validTile(building.entrance),
                  validDistrict(building.district),
                  building.workers.allSatisfy(validCitizen),
                  building.residents.allSatisfy(validCitizen) else { return false }
            // A demolished building stays in the array with its footprint cleared.
            guard map.building(at: building.entrance) == building.id else { continue }
            guard map.isEntrance(building.entrance),
                  map.district(at: building.entrance) == building.district else { return false }
            let covered = building.tilesCovered(on: map)
            guard covered.count == building.kind.footprint.area,
                  covered.allSatisfy({ map.building(at: $0) == building.id }) else { return false }
        }
        for (tile, raw) in map.buildingAt.enumerated() {
            guard raw >= -1 else { return false }
            if raw >= 0 {
                let id = BuildingID(raw)
                guard validBuilding(id),
                      saved.buildings[Int(raw)].tilesCovered(on: map).contains(TileIndex(Int32(tile)))
                else { return false }
            }
        }
        for (index, isEntrance) in map.entranceAt.enumerated() where isEntrance {
            let tile = TileIndex(Int32(index))
            guard let id = map.building(at: tile),
                  saved.buildings[Int(id.raw)].entrance == tile else { return false }
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

}
