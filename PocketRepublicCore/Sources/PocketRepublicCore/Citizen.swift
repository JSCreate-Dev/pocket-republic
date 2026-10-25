public struct CitizenID: Codable, Hashable {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct Citizen: Codable, Identifiable {
    public var id: CitizenID
    public var name: String
    public var occupation: String
    public var ambition: Int
    public var loyalty: Int
    public var wealth: Int
    public var happiness: Int
    public var influence: Int
    public var criminal: Bool
    public var memories: [String]

    public init(
        id: CitizenID,
        name: String,
        occupation: String,
        ambition: Int,
        loyalty: Int,
        wealth: Int,
        happiness: Int,
        influence: Int,
        criminal: Bool = false,
        memories: [String] = []
    ) {
        self.id = id
        self.name = name
        self.occupation = occupation
        self.ambition = ambition
        self.loyalty = loyalty
        self.wealth = wealth
        self.happiness = happiness
        self.influence = influence
        self.criminal = criminal
        self.memories = memories
    }
}
