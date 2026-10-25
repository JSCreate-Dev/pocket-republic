public struct Republic: Codable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var worldSeed: UInt64
    public var rngState: UInt64
    public var day: Int
    public var treasury: Int
    public var food: Int
    public var tax: Int
    public var services: Int
    public var security: Int
    public var corruption: Int
    public var legitimacy: Int
    public var unrest: Int
    public var citizens: [Citizen]
    public var news: [String]
    public var pending: String?
    public var lastSavedAtEpochSeconds: Double

    public init(
        worldSeed: UInt64,
        rngState: UInt64? = nil,
        day: Int = 1,
        treasury: Int = 5000,
        food: Int = 130,
        tax: Int = 15,
        services: Int = 50,
        security: Int = 50,
        corruption: Int = 10,
        legitimacy: Int = 65,
        unrest: Int = 10,
        citizens: [Citizen] = [],
        news: [String] = ["Welcome, Governor. Your republic awaits."],
        pending: String? = nil,
        lastSavedAtEpochSeconds: Double = 0
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.worldSeed = worldSeed
        self.rngState = rngState ?? worldSeed
        self.day = day
        self.treasury = treasury
        self.food = food
        self.tax = tax
        self.services = services
        self.security = security
        self.corruption = corruption
        self.legitimacy = legitimacy
        self.unrest = unrest
        self.citizens = citizens
        self.news = news
        self.pending = pending
        self.lastSavedAtEpochSeconds = lastSavedAtEpochSeconds
    }
}
