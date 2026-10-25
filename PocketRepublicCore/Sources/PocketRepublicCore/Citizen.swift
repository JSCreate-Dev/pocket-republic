import Foundation

public enum Occupation: UInt8, Codable, Sendable, CaseIterable {
    case unemployed = 0, farmer = 1, shopkeeper = 2, nurse = 3
    case teacher = 4, officer = 5, artisan = 6, dockhand = 7, official = 8

    public static func forEmployer(_ kind: BuildingKind) -> Occupation {
        switch kind {
        case .farm: return .farmer
        case .market: return .shopkeeper
        case .clinic: return .nurse
        case .school: return .teacher
        case .police: return .officer
        case .workshop: return .artisan
        case .dock: return .dockhand
        case .townHall: return .official
        case .house: return .unemployed
        }
    }
}

public struct Citizen: Codable, Sendable, Identifiable {
    public let id: CitizenID
    public var name: String
    public var age: Int32

    public var home: BuildingID?
    public var work: BuildingID?
    public var district: DistrictID

    public var money: Int64
    public var happiness: Int32
    public var loyalty: Int32
    public var ambition: Int32
    public var influence: Int32

    public var criminal: Bool = false
    public var daysHungry: Int32 = 0
    public var daysUnemployed: Int32 = 0
    public var alive: Bool = true

    public var occupation: Occupation = .unemployed

    public init(id: CitizenID, name: String, age: Int32, district: DistrictID,
                money: Int64, happiness: Int32, loyalty: Int32,
                ambition: Int32, influence: Int32) {
        self.id = id
        self.name = name
        self.age = age
        self.district = district
        self.money = money
        self.happiness = happiness
        self.loyalty = loyalty
        self.ambition = ambition
        self.influence = influence
    }
}
