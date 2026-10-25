import Foundation

/// Plain-language lines for a `CauseFactor`. Presentation only: the simulation
/// still stores the structured cause. A missing cause stays nil so the UI can
/// omit the line until the core attaches one.
public enum CauseCopy {
    public static let factionNames: Set<String> = ["Labourers", "Merchants", "Officials", "Landless"]

    /// Details the simulation writes today. Anything else that already reads as a
    /// sentence is shown as-is, so a future cause string does not need a UI change.
    static let knownDetails: Set<String> = [
        "days hungry", "market coverage %", "hungry residents", "without work",
        "income tax", "national", "destitute", "treasury", "unpaid upkeep",
        "national corruption", "citizens in the black market", "demand ignored",
        "new works", "mandate"
    ]

    public static func line(_ cause: CauseFactor) -> String {
        if let prose = prose(cause) { return prose }
        let detail = cause.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = cause.value
        switch cause.kind {
        case .foodShortage:
            if detail == "days hungry" || detail.isEmpty {
                return "Hungry for \(spell(value)) \(value == 1 ? "day" : "days")"
            }
            if detail == "hungry residents" {
                return "\(value) residents are hungry"
            }
            if detail.contains("citizens hungry") {
                return "\(value) \(detail)"
            }
            if factionNames.contains(detail) {
                return "The \(detail) cannot find enough food"
            }
            return "The market ran out of food"
        case .noMarketAccess:
            if detail == "market coverage %" {
                return "Only \(value)% of residents can reach a market"
            }
            if factionNames.contains(detail) {
                return "The \(detail) have no market within reach"
            }
            if !detail.isEmpty && !knownDetails.contains(detail) {
                return "No market within reach in \(detail)"
            }
            return "No market within reach"
        case .noClinicAccess:
            if factionNames.contains(detail) { return "The \(detail) have no clinic within reach" }
            if !detail.isEmpty && !knownDetails.contains(detail) {
                return "No clinic within reach in \(detail)"
            }
            return "No clinic within reach"
        case .noPoliceAccess:
            if detail == "citizens in the black market" {
                return "\(value) citizens are in the black market"
            }
            if factionNames.contains(detail) { return "The \(detail) have no police within reach" }
            if !detail.isEmpty && !knownDetails.contains(detail) {
                return "No police within reach in \(detail)"
            }
            return "No police within reach"
        case .unemployment:
            if detail == "without work" { return "\(value) are without work" }
            if factionNames.contains(detail) { return "The \(detail) are out of work" }
            if !detail.isEmpty && !knownDetails.contains(detail) {
                return "\(value) people are without work in \(detail)"
            }
            return "\(value) people are without work"
        case .taxBurden:
            return "Income tax is \(value)%"
        case .corruption:
            if detail == "national corruption" || detail == "national" {
                return "National corruption is \(value)"
            }
            return "Corruption stands at \(value)"
        case .treasuryDeficit:
            if detail == "unpaid upkeep" { return "\(value) in upkeep went unpaid" }
            return "The treasury stands at \(value)"
        case .districtNeglect:
            let place = (detail.isEmpty || knownDetails.contains(detail)) ? "The district" : detail
            if value > 0 { return "\(place) has been neglected for \(spell(value)) days" }
            return "\(place) has been neglected"
        case .poverty:
            return "Destitute, with \(value) left"
        case .policyChange:
            if detail == "mandate" { return "The mandate stands at \(value)" }
            if detail == "income tax" { return "Income tax is \(value)%" }
            if detail == "new works" { return "New works are proposed" }
            if detail == "demand ignored" { return "A demand was ignored" }
            if factionNames.contains(detail) { return "The \(detail) are part of this" }
            if !detail.isEmpty { return detail }
            return "Policy changed"
        }
    }

    /// One "why" sentence for a crisis or a story. Prefers a full sentence already
    /// stored on the cause, then the neglect-plus-market case from the design, then
    /// the first cause. Empty causes return nil.
    public static func why(_ causes: [CauseFactor]) -> String? {
        guard let top = causes.first else { return nil }
        if let prose = prose(top) { return prose }
        if let neglect = causes.first(where: { $0.kind == .districtNeglect }),
           causes.contains(where: { $0.kind == .noMarketAccess }),
           neglect.value > 0 {
            let place = neglect.detail.isEmpty ? "The district" : neglect.detail
            let n = neglect.value
            return "\(place) has gone \(spell(n)) \(n == 1 ? "day" : "days") without a market in range"
        }
        if let hungry = causes.first(where: {
            $0.kind == .foodShortage && ($0.detail == "days hungry" || $0.detail.isEmpty)
        }), causes.contains(where: { $0.kind == .noMarketAccess }) {
            let n = max(hungry.value, 1)
            return "No market within reach for \(spell(n)) \(n == 1 ? "day" : "days")"
        }
        return line(top)
    }

    static func prose(_ cause: CauseFactor) -> String? {
        let detail = cause.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty, !knownDetails.contains(detail), !factionNames.contains(detail) else { return nil }
        let words = detail.split(separator: " ")
        if detail.contains(".") || words.count >= 6 { return detail }
        return nil
    }

    static func spell(_ value: Int32) -> String { String(value) }
}
