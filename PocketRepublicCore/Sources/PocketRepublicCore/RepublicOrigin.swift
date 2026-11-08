import Foundation

/// A story the player picks before a new city. Nil is an ordinary island, and
/// the same nil an old save decodes to. Modifiers are read from this value.
/// They are not added again when the city is loaded.
public enum RepublicOrigin: String, Codable, Sendable, Equatable, CaseIterable {
    /// Retired privateers. The docks still pay, and the warehouses are careless.
    case marque
    /// The last general's island. The offices still run. The jobless were never his concern.
    case parade
    /// Neighbours who share the pot. Food keeps. Coin from the docks is thinner.
    case commonPot

    public var title: String {
        switch self {
        case .marque: return "Letters of Marque"
        case .parade: return "The General's Square"
        case .commonPot: return "The Common Pot"
        }
    }

    public var pitch: String {
        switch self {
        case .marque:
            return "The old crews left a fat purse and a bad reputation. Docks earn a little more, and food spoils a little faster."
        case .parade:
            return "His portrait is still on the customs house. Civic upkeep is cheaper. People without work feel it more."
        case .commonPot:
            return "The neighbours cook from one pot. Food lasts longer. Workshops and docks earn less coin."
        }
    }
}

public enum RepublicOriginBook {
    public static let marqueExportBonus: Int64 = 1
    public static let marqueSpoilageExtra: Int32 = 2
    public static let marquePurse: Int64 = 400
    public static let paradeCivicDiscount: Int64 = 1
    public static let paradeUnemploymentExtra: Int32 = 1
    public static let potExportPenalty: Int64 = 1
    public static let potSpoilageRelief: Int32 = 2
    public static let potPurseShortfall: Int64 = 600
    public static let potExtraFood: Int32 = 40

    /// One-time opening numbers and a single dilemma. Safe to call only from world generation.
    public static func stamp(_ origin: RepublicOrigin?, on s: inout RepublicState) {
        guard let origin else { return }
        s.origin = origin
        switch origin {
        case .marque:
            s.corruption = 28
            s.legitimacy = 52
            s.transfer(from: .external, to: .treasury, marquePurse)
            s.factions[Int(FactionKind.merchants.rawValue)].adjust(6, on: 0, reason: .policyChange, detail: "old crew")
            s.factions[Int(FactionKind.officials.rawValue)].adjust(-6, on: 0, reason: .policyChange, detail: "old crew")
        case .parade:
            s.corruption = 16
            s.legitimacy = 78
            s.factions[Int(FactionKind.officials.rawValue)].adjust(8, on: 0, reason: .policyChange, detail: "the square")
            s.factions[Int(FactionKind.labourers.rawValue)].adjust(-8, on: 0, reason: .policyChange, detail: "the square")
            s.factions[Int(FactionKind.landless.rawValue)].adjust(-6, on: 0, reason: .policyChange, detail: "the square")
        case .commonPot:
            if s.treasury >= potPurseShortfall {
                s.transfer(from: .treasury, to: .external, potPurseShortfall)
            }
            for i in s.buildings.indices where s.buildings[i].kind == .market && s.buildings[i].isStanding(on: s.map) {
                s.buildings[i].foodStore += potExtraFood
                s.ledger.foodImported += Int64(potExtraFood)
            }
            s.factions[Int(FactionKind.labourers.rawValue)].adjust(4, on: 0, reason: .policyChange, detail: "the pot")
            s.factions[Int(FactionKind.merchants.rawValue)].adjust(-4, on: 0, reason: .policyChange, detail: "the pot")
        }
        postDilemma(origin, on: &s)
    }

    public static func exportAdjustment(workers: Int32, scale: Int64, in state: RepublicState) -> Int64 {
        guard workers > 0 else { return 0 }
        var perWorker: Int64 = 0
        if state.republicSeason?.path == .harbor { perWorker += RepublicSeasonBook.harborCoinsPerWorker }
        switch state.origin {
        case .marque: perWorker += marqueExportBonus
        case .commonPot: perWorker -= potExportPenalty
        default: break
        }
        let coins = Int64(workers) * perWorker * scale / 100
        return coins
    }

    public static func spoilageAdjustment(in state: RepublicState) -> Int32 {
        switch state.origin {
        case .marque: return marqueSpoilageExtra
        case .commonPot: return -potSpoilageRelief
        default: return 0
        }
    }

    public static func civicUpkeep(in state: RepublicState) -> Int64 {
        let base = state.config.upkeepCivic
        guard state.origin == .parade else { return base }
        return max(0, base - paradeCivicDiscount)
    }

    public static func unemploymentExtra(in state: RepublicState) -> Int32 {
        state.origin == .parade ? paradeUnemploymentExtra : 0
    }

    private static func postDilemma(_ origin: RepublicOrigin, on s: inout RepublicState) {
        let built = dilemma(origin)
        s.agenda.append(AgendaItem(
            id: AgendaGenerator.nextID(&s),
            kind: .advisoryTradeoff,
            tier: .advisory,
            raisedOnDay: 0,
            expiresOnDay: 6,
            faction: nil,
            location: EventLocation(),
            causes: [
                CauseFactor(.policyChange, value: 0, detail: built.title),
                CauseFactor(.policyChange, value: 0, detail: built.flavor)
            ],
            options: built.options,
            salience: 70,
            originDilemma: true))
    }

    private static func dilemma(_ origin: RepublicOrigin) -> (title: String, flavor: String, options: [AgendaOption]) {
        switch origin {
        case .marque:
            var pay = AgendaEffect()
            pay.treasuryCost = 100
            pay.corruption = -6
            pay.legitimacy = 5
            pay.favor(.labourers, 4)
            var cut = AgendaEffect()
            cut.treasuryGain = 140
            cut.corruption = 5
            cut.favor(.merchants, 5)
            cut.favor(.landless, -3)
            return (
                "The last crew wants paying",
                "They still have a key to the customs shed.",
                [
                    AgendaOption(id: 0, label: "Pay them off (−100, cleaner books)", effect: pay),
                    AgendaOption(id: 1, label: "Keep a quiet cut (+140, corruption up)", effect: cut)
                ]
            )
        case .parade:
            var down = AgendaEffect()
            down.legitimacy = -5
            down.districtUnrest = 3
            down.favor(.labourers, 6)
            down.favor(.landless, 4)
            down.favor(.officials, -5)
            var leave = AgendaEffect()
            leave.legitimacy = 4
            leave.favor(.officials, 6)
            leave.favor(.labourers, -4)
            return (
                "The portraits in the square",
                "He is gone. The bronze is not.",
                [
                    AgendaOption(id: 0, label: "Take the portraits down", effect: down),
                    AgendaOption(id: 1, label: "Leave the square named for him", effect: leave)
                ]
            )
        case .commonPot:
            var open = AgendaEffect()
            open.foodImport = 50
            open.favor(.landless, 5)
            open.favor(.merchants, -3)
            var sell = AgendaEffect()
            sell.treasuryGain = 160
            sell.favor(.merchants, 5)
            sell.favor(.landless, -4)
            return (
                "The first surplus",
                "The pot is full and the merchants can smell it.",
                [
                    AgendaOption(id: 0, label: "Open the stores (food for the neighbours)", effect: open),
                    AgendaOption(id: 1, label: "Sell a share (+160)", effect: sell)
                ]
            )
        }
    }
}
