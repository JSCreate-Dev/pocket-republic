import Foundation
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

    var pace: Pace = .paused
    var sceneActive = true
    var modalHold = false
    var blockedByCrisis = false
    var islandEventWaiting = false
    var saveBlocked = false

    /// Seconds until the next single advance, or nil when the clock must not fire.
    var tickInterval: TimeInterval? {
        guard sceneActive, !modalHold, !blockedByCrisis, !islandEventWaiting, !saveBlocked else { return nil }
        guard case .playing(let seconds) = pace else { return nil }
        guard seconds >= 1.5, seconds <= 30, seconds.isFinite else { return nil }
        return seconds
    }

    /// Never more than one sim-day per timer fire.
    var advancesPerTick: Int { tickInterval == nil ? 0 : 1 }

    var controlLabel: String {
        guard tickInterval != nil else {
            if case .playing = pace { return "\(paceLabel), held" }
            return "Paused"
        }
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
            return "Paused for a crisis. The day waits for that choice. Next Day is held too."
        }
        if islandEventWaiting {
            return "Paused while an island event is waiting, so it cannot lapse in the background. Choose an option, or press Next Day yourself."
        }
        switch pace {
        case .paused:
            return "Paused. Next Day advances one sim-day. A speed repeats that same step on a timer. Construction changes on the day, not between days."
        case .playing(let seconds):
            return "One sim-day every \(Self.spoken(seconds)) seconds, through the same advance as Next Day. It stops if you leave the app, open a confirmation, or an island event is waiting."
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

    func attach(_ game: Game) {
        self.game = game
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
        reschedule()
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
