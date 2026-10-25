import Combine
import Foundation
import PocketRepublicCore

@MainActor final class Game: ObservableObject {
    @Published var state: Republic
    @Published private(set) var saveIssue: String?

    private let key = "pocket.republic.save.v1"

    init() {
        let now = Date().timeIntervalSince1970
        let storedObject = UserDefaults.standard.object(forKey: key)
        let result: SaveDecodeResult
        if let data = storedObject as? Data {
            result = SaveCodec.decode(data)
        } else if storedObject == nil {
            result = .missing
        } else {
            result = .corrupt
        }

        switch result {
        case .missing:
            state = Self.newRepublic(at: now)
            saveIssue = nil
            save()
        case .loaded(let saved):
            state = saved
            saveIssue = nil
            catchUp()
        case .corrupt:
            state = Self.newRepublic(at: now)
            saveIssue = "The saved republic could not be read. Its data has been preserved. Restart Republic to replace it."
        case .unsupportedVersion(let version):
            state = Self.newRepublic(at: now)
            saveIssue = "Saved republic version \(version) is unsupported. Its data has been preserved. Restart Republic to replace it."
        }
    }

    var approval: Int { Engine.approval(of: state) }

    func save() {
        guard saveIssue == nil else { return }
        var candidate = state
        candidate.lastSavedAtEpochSeconds = Date().timeIntervalSince1970
        do {
            let data = try SaveCodec.encode(candidate)
            UserDefaults.standard.set(data, forKey: key)
            state = candidate
        } catch {
            saveIssue = "The republic could not be saved. Restart Republic to start a new save."
        }
    }

    func catchUp() {
        guard saveIssue == nil else { return }
        let elapsed = Date().timeIntervalSince1970 - state.lastSavedAtEpochSeconds
        guard elapsed.isFinite else {
            saveIssue = "The saved republic has an invalid timestamp. Its data has been preserved. Restart Republic to replace it."
            return
        }
        let days = elapsed >= 64800 ? 3 : max(0, Int(elapsed / 21600))
        for _ in 0..<days where state.pending == nil {
            advance()
        }
    }

    func advance() {
        guard saveIssue == nil, state.pending == nil else { return }
        state = Engine.advance(state)
        save()
    }

    func decide(_ choice: Int) {
        guard saveIssue == nil, state.pending != nil else { return }
        state = Engine.decide(choice, in: state)
        save()
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: key)
        saveIssue = nil
        state = Self.newRepublic(at: Date().timeIntervalSince1970)
        save()
    }

    private static func newRepublic(at timestamp: Double) -> Republic {
        var newState = Engine.makeInitialState(worldSeed: UInt64.random(in: UInt64.min...UInt64.max))
        newState.lastSavedAtEpochSeconds = timestamp
        return newState
    }
}
