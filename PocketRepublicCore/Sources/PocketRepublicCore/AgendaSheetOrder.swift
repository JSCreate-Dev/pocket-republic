import Foundation

/// Which agenda row the closed phone should show first.
/// A crisis, including an election, outranks an optional island event.
public enum AgendaSheetOrder {
    public static func rank(tier: AgendaTier, isIslandEvent: Bool, isDecree: Bool, isOriginDilemma: Bool = false) -> Int {
        if tier == .crisis { return 0 }
        if isOriginDilemma { return 1 }
        if isIslandEvent { return 2 }
        if isDecree { return 4 }
        return 3
    }
}
