import Foundation

/// One fact on the inspect panel. The view renders rows in section order and
/// does not switch on building kind. Add a fact by extending `BuildingInspectCatalog`.
public struct InspectRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var value: String
    public var tone: InspectTone

    public init(id: String, title: String, value: String, tone: InspectTone) {
        self.id = id
        self.title = title
        self.value = value
        self.tone = tone
    }
}

public enum InspectTone: String, Equatable, Sendable {
    /// The single biggest problem. Shown in the warning color.
    case problem
    /// "Running well".
    case calm
    /// A labeled number.
    case plain
    /// One house resident.
    case person
}

public struct InspectSection: Equatable, Sendable, Identifiable {
    public var id: String
    public var rows: [InspectRow]

    public init(id: String, rows: [InspectRow]) {
        self.id = id
        self.rows = rows
    }
}

public struct InspectModeChoice: Equatable, Sendable, Identifiable {
    public var mode: OperatingMode
    public var label: String
    public var id: UInt8 { mode.rawValue }

    public init(mode: OperatingMode, label: String) {
        self.mode = mode
        self.label = label
    }
}

/// Read-only description of one placed building. Built from state the core already
/// stores. Buildings have no separate name field; `name` and `typeName` are the
/// display copy for `BuildingKind` in `BuildingInspectCatalog`.
public struct BuildingInspection: Equatable, Sendable {
    public var buildingID: BuildingID
    public var name: String
    public var typeName: String
    public var districtName: String
    /// Status, then people, then numbers.
    public var sections: [InspectSection]
    /// Empty unless this kind offers an operating mode.
    public var modeChoices: [InspectModeChoice]
    public var selectedMode: OperatingMode?
    public var canDemolish: Bool

    public init(buildingID: BuildingID, name: String, typeName: String, districtName: String,
                sections: [InspectSection], modeChoices: [InspectModeChoice],
                selectedMode: OperatingMode?, canDemolish: Bool) {
        self.buildingID = buildingID
        self.name = name
        self.typeName = typeName
        self.districtName = districtName
        self.sections = sections
        self.modeChoices = modeChoices
        self.selectedMode = selectedMode
        self.canDemolish = canDemolish
    }
}

public enum BuildingInspector {
    /// Nil when the id is missing or no tile is still occupied (demolished buildings
    /// stay in the array, but `buildingAt` no longer names them).
    public static func make(id: BuildingID, in state: RepublicState) -> BuildingInspection? {
        guard let building = placedBuilding(id, in: state) else { return nil }
        let copy = BuildingInspectCatalog.copy(for: building.kind)
        let choices = BuildingInspectCatalog.modeChoices(for: building.kind)
        var sections = [statusSection(building, state)]
        if let people = peopleSection(building, state) {
            sections.append(people)
        }
        sections.append(numbersSection(building, state))
        return BuildingInspection(
            buildingID: building.id,
            name: copy.name,
            typeName: copy.typeName,
            districtName: districtName(building.district, in: state),
            sections: sections,
            modeChoices: choices,
            selectedMode: choices.isEmpty ? nil : building.mode,
            canDemolish: building.kind != .townHall
        )
    }

    private static func placedBuilding(_ id: BuildingID, in state: RepublicState) -> Building? {
        guard id.raw >= 0, Int(id.raw) < state.buildings.count else { return nil }
        let building = state.buildings[Int(id.raw)]
        guard building.id == id else { return nil }
        guard !BuildingHitTest.occupiedTiles(id, on: state.map).isEmpty else { return nil }
        return building
    }

    private static func statusSection(_ building: Building, _ state: RepublicState) -> InspectSection {
        let (value, tone) = status(building, state)
        return InspectSection(id: "status", rows: [
            InspectRow(id: "status", title: "Status", value: value, tone: tone)
        ])
    }

    /// A site reports its stage and ignores the problem list: it has no staff and no
    /// stock yet, so "Understaffed" would just be noise (docs/DESIGN.md section 7.8).
    /// The tone is `.calm`, not a new `.progress` case - adding one would break the
    /// app's exhaustive switch over `InspectTone`, which is the iOS role's change.
    private static func status(_ building: Building, _ state: RepublicState) -> (String, InspectTone) {
        if building.isUnderConstruction {
            return (BuildingInspectCatalog.constructionStatus(building, config: state.config), .calm)
        }
        for problem in BuildingInspectCatalog.problemPriority
        where BuildingInspectCatalog.matches(problem, building: building, state: state) {
            return (BuildingInspectCatalog.label(problem), .problem)
        }
        return (BuildingInspectCatalog.runningWell, .calm)
    }

    private static func peopleSection(_ building: Building, _ state: RepublicState) -> InspectSection? {
        // Nobody lives or works at a site, so showing "0 / 4" invites the owner to
        // go looking for a staffing problem that does not exist yet.
        if building.isUnderConstruction { return nil }
        if building.kind == .house {
            let living = aliveResidents(of: building, in: state)
            var rows = [
                InspectRow(id: "residents", title: "Residents",
                           value: "\(living.count) / \(building.kind.housingCapacity)", tone: .plain)
            ]
            for citizen in living {
                let job = BuildingInspectCatalog.jobTitle(citizen.occupation)
                rows.append(InspectRow(
                    id: "resident-\(citizen.id.raw)",
                    title: citizen.name,
                    value: "\(job) · \(hungerText(citizen.daysHungry))",
                    tone: .person
                ))
            }
            return InspectSection(id: "people", rows: rows)
        }
        let capacity = building.kind.workerCapacity
        guard capacity > 0 else { return nil }
        return InspectSection(id: "people", rows: [
            InspectRow(id: "workers", title: "Workers",
                       value: "\(building.workers.count) / \(capacity)", tone: .plain)
        ])
    }

    private static func numbersSection(_ building: Building, _ state: RepublicState) -> InspectSection {
        var rows: [InspectRow] = []
        for fact in BuildingInspectCatalog.numberFacts {
            if let row = numberRow(fact, building: building, state: state) {
                rows.append(row)
            }
        }
        return InspectSection(id: "numbers", rows: rows)
    }

    private static func numberRow(_ fact: BuildingInspectCatalog.NumberFact, building: Building,
                                  state: RepublicState) -> InspectRow? {
        switch fact {
        case .opensOnDay:
            guard building.isUnderConstruction else { return nil }
            return InspectRow(id: fact.rawValue, title: "Opens",
                              value: "Day \(building.opensOnDay)", tone: .plain)
        case .buildProgress:
            guard building.isUnderConstruction else { return nil }
            return InspectRow(id: fact.rawValue, title: "Progress",
                              value: "\(Int((building.constructionProgress * 100).rounded(.down)))%",
                              tone: .plain)
        case .foodStored:
            guard building.isOperational, building.kind.storesFood else { return nil }
            return InspectRow(id: fact.rawValue, title: "Food stored",
                              value: "\(building.foodStore)", tone: .plain)
        case .funds:
            guard building.isOperational else { return nil }
            return InspectRow(id: fact.rawValue, title: "Funds",
                              value: "$\(building.funds)", tone: .plain)
        case .upkeep:
            // A site is not charged upkeep until it opens, so quoting a rate here
            // would contradict `SimulationEngine.payUpkeep`.
            guard building.isOperational else { return nil }
            let rate = BuildingInspectCatalog.dailyUpkeep(building.kind, config: state.config)
            return InspectRow(id: fact.rawValue, title: "Upkeep",
                              value: "$\(rate)/day", tone: .plain)
        case .residentsInRange:
            guard building.isOperational else { return nil }
            guard BuildingInspectCatalog.serviceKinds.contains(building.kind) else { return nil }
            let count = residentsInRange(of: building, in: state)
            return InspectRow(id: fact.rawValue, title: "Residents in range",
                              value: "\(count)", tone: .plain)
        case .dayBuilt:
            return InspectRow(id: fact.rawValue,
                              title: building.isUnderConstruction ? "Placed" : "Built",
                              value: "Day \(building.builtOnDay)", tone: .plain)
        }
    }

    /// Road distance from this building's occupied tiles to each resident's home.
    /// Uses `DistanceFields.bfs` and `WorldMap.isPassable`, so a later entrance-only
    /// passability rule is picked up without a second pathfinder.
    private static func residentsInRange(of building: Building, in state: RepublicState) -> Int {
        let sources = BuildingHitTest.occupiedTiles(building.id, on: state.map)
        guard !sources.isEmpty else { return 0 }
        let distance = DistanceFields.bfs(map: state.map, sources: sources)
        let limit = state.config.maxServiceDistance
        var count = 0
        for citizen in state.citizens where citizen.alive {
            guard let home = citizen.home else { continue }
            let tiles = BuildingHitTest.occupiedTiles(home, on: state.map)
            guard !tiles.isEmpty else { continue }
            var nearest = DistanceFields.unreachable
            for tile in tiles {
                let index = Int(tile.raw)
                if index >= 0, index < distance.count {
                    nearest = min(nearest, distance[index])
                }
            }
            if nearest <= limit { count += 1 }
        }
        return count
    }

    private static func aliveResidents(of building: Building, in state: RepublicState) -> [Citizen] {
        building.residents.compactMap { id in
            guard id.raw >= 0, Int(id.raw) < state.citizens.count else { return nil }
            let citizen = state.citizens[Int(id.raw)]
            guard citizen.alive, citizen.id == id else { return nil }
            return citizen
        }
    }

    private static func hungerText(_ days: Int32) -> String {
        if days <= 0 { return "Fed" }
        if days == 1 { return "Hungry 1 day" }
        return "Hungry \(days) days"
    }

    private static func districtName(_ id: DistrictID, in state: RepublicState) -> String {
        let index = Int(id.raw)
        guard index < state.districts.count else { return "" }
        return state.districts[index].name
    }
}

/// Copy, field order, and which problem wins. Reorder `problemPriority` or
/// `numberFacts` when the design of the panel changes; the view does not know.
enum BuildingInspectCatalog {
    struct KindCopy: Equatable {
        var name: String
        var typeName: String
    }

    enum NumberFact: String {
        case opensOnDay, buildProgress, foodStored, funds, upkeep, residentsInRange, dayBuilt
    }

    enum BuildingProblem: String {
        case noRoadAccess, understaffed, noFood
    }

    /// Road access first (the building is off the network), then staffing (an empty
    /// workplace cannot relieve a shortage), then an empty store or a hungry house.
    static let problemPriority: [BuildingProblem] = [.noRoadAccess, .understaffed, .noFood]
    static let runningWell = "Running well"
    static let numberFacts: [NumberFact] = [.opensOnDay, .buildProgress, .foodStored, .funds,
                                            .upkeep, .residentsInRange, .dayBuilt]
    static let serviceKinds: Set<BuildingKind> = [.market, .clinic, .school, .police]

    static func copy(for kind: BuildingKind) -> KindCopy {
        switch kind {
        case .townHall: return KindCopy(name: "Town Hall", typeName: "Civic")
        case .house: return KindCopy(name: "House", typeName: "Housing")
        case .farm: return KindCopy(name: "Farm", typeName: "Food")
        case .market: return KindCopy(name: "Market", typeName: "Service")
        case .clinic: return KindCopy(name: "Clinic", typeName: "Service")
        case .school: return KindCopy(name: "School", typeName: "Service")
        case .police: return KindCopy(name: "Police", typeName: "Service")
        case .workshop: return KindCopy(name: "Workshop", typeName: "Industry")
        case .dock: return KindCopy(name: "Dock", typeName: "Industry")
        }
    }

    static func modeChoices(for kind: BuildingKind) -> [InspectModeChoice] {
        guard kind.offersCommission else { return [] }
        return OperatingMode.allCases.map { InspectModeChoice(mode: $0, label: modeLabel($0)) }
    }

    static func modeLabel(_ mode: OperatingMode) -> String {
        switch mode {
        case .balanced: return "Balanced"
        case .intensive: return "Intensive"
        case .careful: return "Careful"
        }
    }

    static func stageLabel(_ stage: ConstructionStage) -> String {
        switch stage {
        case .foundation: return "Foundation"
        case .scaffold: return "Scaffold"
        case .complete: return "Complete"
        }
    }

    /// "Under construction · Scaffold, 2 of 3 days".
    static func constructionStatus(_ building: Building, config: BalanceConfig) -> String {
        let progress = building.stageProgress(in: config)
        let stage = stageLabel(building.stage(in: config))
        return "Under construction · \(stage), \(progress.done) of \(progress.of) days"
    }

    static func label(_ problem: BuildingProblem) -> String {
        switch problem {
        case .noRoadAccess: return "No road access"
        case .understaffed: return "Understaffed"
        case .noFood: return "No food"
        }
    }

    static func matches(_ problem: BuildingProblem, building: Building, state: RepublicState) -> Bool {
        switch problem {
        case .noRoadAccess:
            return !BuildingHitTest.hasRoadAccess(building.id, on: state.map)
        case .understaffed:
            let capacity = building.kind.workerCapacity
            return capacity > 0 && Int32(building.workers.count) < capacity
        case .noFood:
            if building.kind.storesFood && building.foodStore <= 0 { return true }
            if building.kind == .house {
                return building.residents.contains { id in
                    guard id.raw >= 0, Int(id.raw) < state.citizens.count else { return false }
                    let citizen = state.citizens[Int(id.raw)]
                    return citizen.alive && citizen.id == id && citizen.daysHungry > 0
                }
            }
            return false
        }
    }

    static func jobTitle(_ occupation: Occupation) -> String {
        switch occupation {
        case .unemployed: return "Unemployed"
        case .farmer: return "Farmer"
        case .shopkeeper: return "Shopkeeper"
        case .nurse: return "Nurse"
        case .teacher: return "Teacher"
        case .officer: return "Officer"
        case .artisan: return "Artisan"
        case .dockhand: return "Dockhand"
        case .official: return "Official"
        }
    }

    /// Mirrors `SimulationEngine.payUpkeep`: houses are not charged, civic buildings
    /// use `upkeepCivic`, and other workplaces use `upkeepPrivate`.
    static func dailyUpkeep(_ kind: BuildingKind, config: BalanceConfig) -> Int64 {
        if kind == .house { return 0 }
        return kind.isCivic ? config.upkeepCivic : config.upkeepPrivate
    }
}
