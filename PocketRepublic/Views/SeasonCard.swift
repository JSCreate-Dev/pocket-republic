import SwiftUI
import PocketRepublicCore

/// The season sits in the island controls. It does not cover the map or Next Day.
struct SeasonCard: View {
    @EnvironmentObject private var game: Game

    private var status: SeasonStatus { RepublicSeasonBook.status(in: game.state) }
    private var treasury: Int64 { game.state.treasury }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            actions
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.96, green: 0.90, blue: 0.74).opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(Color(red: 0.28, green: 0.18, blue: 0.08))
    }

    private var originLine: String {
        switch game.state.origin {
        case .marque: return "The old flag is still in the locker."
        case .parade: return "The square still has his name on it."
        case .commonPot: return "The neighbours already put a pot on the fire."
        case nil: return ""
        }
    }

    private var title: String {
        switch status.beat {
        case .breakGround: return "Charter: break ground"
        case .chooseCompact: return "Charter: choose a compact"
        case .settle: return "Charter: settle the republic"
        case .kept: return status.path == .harbor ? "Harbor compact holds" : "Granary compact holds"
        }
    }

    private var detail: String {
        switch status.beat {
        case .breakGround:
            return status.foundingReady
                ? "A building you placed is open. Seal the charter and the treasury receives $\(RepublicSeasonBook.foundingGrant). Then choose one compact."
                : "Place a building and open it. Houses the island started with do not count. \(originLine)"
        case .chooseCompact:
            return "One compact, for $\(RepublicSeasonBook.pathCost). The other closes. This changes every later day, not just the score."
        case .settle:
            return status.settledReady
                ? "Food is stored and two kinds of buildings you raised are open."
                : "Open a second kind of building you place, and keep food in the markets. Happiness needs to hold at \(RepublicSeasonBook.settledHappiness)% or better, from day \(RepublicSeasonBook.settledDay). Today is day \(game.state.day)."
        case .kept:
            if status.path == .harbor {
                return "Workshops and docks earn $\(RepublicSeasonBook.harborCoinsPerWorker) more per worker. Food spoils \(RepublicSeasonBook.harborSpoilageExtra)% faster. Joblessness hurts less."
            }
            return "Farms feed \(RepublicSeasonBook.granaryFoodPerWorker) more per worker. Private upkeep is $\(RepublicSeasonBook.granaryUpkeepExtra) higher. Joblessness hurts less."
        }
    }

    @ViewBuilder private var actions: some View {
        switch status.beat {
        case .breakGround:
            Button("Seal the charter · receive $\(RepublicSeasonBook.foundingGrant)") { game.send(.advanceSeason(.claimFounding)) }
                .buttonStyle(.borderedProminent)
                .disabled(!status.foundingReady || game.saveIssue != nil)
        case .chooseCompact:
            compactButton(.granary, "Granary compact",
                          "+\(RepublicSeasonBook.granaryFoodPerWorker) food per farm worker. Private upkeep +$\(RepublicSeasonBook.granaryUpkeepExtra).")
            compactButton(.harbor, "Harbor compact",
                          "+$\(RepublicSeasonBook.harborCoinsPerWorker) per workshop and dock worker. Food spoils +\(RepublicSeasonBook.harborSpoilageExtra)%.")
        case .settle:
            Button("Mark the republic settled") { game.send(.advanceSeason(.claimSettled)) }
                .buttonStyle(.borderedProminent)
                .disabled(!status.settledReady || game.saveIssue != nil)
        case .kept:
            EmptyView()
        }
    }

    private func compactButton(_ path: DevelopmentPath, _ name: String, _ tradeoff: String) -> some View {
        let short = max(0, RepublicSeasonBook.pathCost - treasury)
        return Button {
            game.send(.advanceSeason(.choose(path)))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) · $\(RepublicSeasonBook.pathCost)")
                    .font(.caption.weight(.semibold))
                Text(tradeoff)
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
                if short > 0 {
                    Text("Need \(short) more")
                        .font(.caption2.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .disabled(short > 0 || game.saveIssue != nil)
    }
}

enum SeasonCopy {
    static func mapLine(_ state: RepublicState) -> String {
        switch RepublicSeasonBook.status(in: state).beat {
        case .breakGround: return "Next: open a building you place"
        case .chooseCompact: return "Next: choose granary or harbor"
        case .settle: return "Next: a second kind of building, food still stored"
        case .kept: return "Season holding"
        }
    }

    static func celebration(_ state: RepublicState) -> String {
        let season = state.republicSeason
        if season?.settledClaimed == true { return "The republic is settled." }
        if season?.path == .harbor { return "Harbor compact is in force." }
        if season?.path == .granary { return "Granary compact is in force." }
        if season?.foundingClaimed == true {
            return "Charter sealed. The treasury received $\(RepublicSeasonBook.foundingGrant). Choose one compact."
        }
        return "The season moved."
    }
}
