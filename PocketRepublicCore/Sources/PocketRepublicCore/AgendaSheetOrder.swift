import Foundation

/// Which agenda row the closed phone should show first.
/// A crisis, including an election, outranks an optional island event.
public enum AgendaSheetOrder {
    public static func rank(tier: AgendaTier, isIslandEvent: Bool, isDecree: Bool) -> Int {
        if tier == .crisis { return 0 }
        if isIslandEvent { return 1 }
        if isDecree { return 3 }
        return 2
    }
}
