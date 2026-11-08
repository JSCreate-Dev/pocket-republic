import Foundation

/// Which island-event raises the Gazette should hide.
///
/// An outcome is a later `islandEvent` whose detail is `"<headline>. <result>"`.
/// It suppresses only an earlier unmatched raise with that same headline, matched
/// by event id. A newer card that repeats the headline stays visible.
public enum IslandEventPaper {
    public static func suppressedRaiseIDs(in events: [GameEvent]) -> Set<Int64> {
        var open: [String: [Int64]] = [:]
        var suppressed: Set<Int64> = []
        let island = events.filter { $0.kind == .islandEvent }.sorted { $0.id.raw < $1.id.raw }
        for event in island {
            guard let detail = event.causes.first?.detail, !detail.isEmpty else { continue }
            if let headline = outcomeHeadline(in: detail) {
                var queue = open[headline] ?? []
                if let index = queue.firstIndex(where: { $0 < event.id.raw }) {
                    suppressed.insert(queue.remove(at: index))
                    open[headline] = queue
                }
            } else {
                open[detail, default: []].append(event.id.raw)
            }
        }
        return suppressed
    }

    /// The headline half of an answered card. A raise has no `". "` separator.
    public static func outcomeHeadline(in detail: String) -> String? {
        guard let range = detail.range(of: ". ") else { return nil }
        let headline = String(detail[..<range.lowerBound])
        let result = String(detail[range.upperBound...])
        guard !headline.isEmpty, !result.isEmpty else { return nil }
        return headline
    }
}
