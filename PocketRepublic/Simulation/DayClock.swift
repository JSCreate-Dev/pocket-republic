import Foundation
import Combine
import PocketRepublicCore

/// When the app may call `Game.advance()` on a timer.
///
/// One tick is exactly one advance, the same path as Next Day. A hold, a
/// backgrounded app, or a paused pace yields no tick and never a catch-up batch.
struct DayClockPolicy: Equatable {
    enum Pace: Equatable {
        case paused
        case playing(TimeInterval)
    }

    static let leisurely: TimeInterval = 6
    static let steady: TimeInterval = 3.5
    static let brisk: TimeInterval = 2

    var pace: Pace = .playing(DayClockPolicy.leisurely)
    var sceneActive = true
    var modalHold = false
    var blockedByCrisis = false
    var islandEventWaiting = false
    var saveBlocked = false

    /// Seconds until the next single advance, or nil when the clock must not fire.
    var tickInterval: TimeInterval? {
        guard sceneActive, !modalHold, !blockedByCrisis, !saveBlocked else { return nil }
        guard case .playing(let seconds) = pace else { return nil }
        guard seconds >= 1.5, seconds <= 30, seconds.isFinite else { return nil }
        return seconds
    }

    /// Never more than one sim-day per timer fire.
    var advancesPerTick: Int { tickInterval == nil ? 0 : 1 }

    var controlLabel: String {
        if case .paused = pace { return "Paused" }
        if !sceneActive { return "Away" }
        if saveBlocked { return "Save issue" }
        if blockedByCrisis { return "Decision" }
        if modalHold { return "Confirming" }
        return paceLabel
    }

    var paceLabel: String {
        switch pace {
        case .paused: return "Paused"
        case .playing(let seconds) where seconds == Self.leisurely: return "Leisurely"
        case .playing(let seconds) where seconds == Self.steady: return "Steady"
        case .playing(let seconds) where seconds == Self.brisk: return "Brisk"
        case .playing(let seconds): return "Every \(Self.spoken(seconds))s"
        }
    }

    var explanation: String {
        if !sceneActive {
            return "Paused while Pocket Republic is away. Missed time is not caught up, and the treasury does not move in the background."
        }
        if saveBlocked {
            return "Paused until the city save can be written."
        }
        if modalHold {
            return "Paused while a confirmation is open."
        }
        if blockedByCrisis {
            return "Paused for a crisis or an election. The next day waits for that choice. Next Day is held too, and Play cannot skip it."
        }
        switch pace {
        case .paused:
            return "Paused. Next Day advances one sim-day. A speed repeats that same step on a timer. Construction changes on the day, not between days."
        case .playing(let seconds):
            return "One sim-day every \(Self.spoken(seconds)) seconds, through the same advance as Next Day. It pauses for blocking crises, destructive confirmations, storage errors or leaving the app. Browsing and optional island events do not stop time."
        }
    }

    private static func spoken(_ seconds: TimeInterval) -> String {
        if seconds == seconds.rounded() { return String(Int(seconds)) }
        return String(format: "%.1f", seconds)
    }
}

/// One timer for the whole app. Views must not create another.
@MainActor
final class DayClock: ObservableObject {
    @Published private(set) var policy = DayClockPolicy()
    private var timer: Timer?
    private var generation = 0
    private var game: Game?
    private var modalTokens: Set<String> = []
    private var resumeInterval = DayClockPolicy.leisurely

    func attach(_ game: Game) {
        self.game = game
        note(game)
        // A default-playing policy may have identical flags on first attach;
        // note's equality guard must not prevent the first timer from starting.
        reschedule()
    }

    func note(_ game: Game) {
        var next = policy
        next.blockedByCrisis = game.state.blocksAdvance
        next.islandEventWaiting = game.state.agenda.contains { $0.islandEventID != nil }
        next.saveBlocked = game.saveIssue != nil
        guard next != policy else { return }
        policy = next
        reschedule()
    }

    func setPace(_ pace: DayClockPolicy.Pace) {
        guard policy.pace != pace else { return }
        policy.pace = pace
        if case .playing(let seconds) = pace { resumeInterval = seconds }
        reschedule()
    }

    func togglePause() {
        if case .paused = policy.pace { setPace(.playing(resumeInterval)) }
        else { setPace(.paused) }
    }

    func setSceneActive(_ active: Bool) {
        guard policy.sceneActive != active else { return }
        policy.sceneActive = active
        reschedule()
    }

    func setModal(_ token: String, presented: Bool) {
        if presented {
            modalTokens.insert(token)
        } else {
            modalTokens.remove(token)
        }
        let hold = !modalTokens.isEmpty
        guard policy.modalHold != hold else { return }
        policy.modalHold = hold
        reschedule()
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        generation += 1
        guard let interval = policy.tickInterval else { return }
        let token = generation
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                guard self.policy.advancesPerTick == 1 else { return }
                self.game?.advance()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
