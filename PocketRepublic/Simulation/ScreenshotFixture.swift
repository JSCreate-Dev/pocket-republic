import Foundation
import SwiftUI
import PocketRepublicCore

/// Capture-only city for the simulator screenshot workflow.
///
/// Ordinary launches never read this. It runs only when the process was started
/// with `--pocket-republic-screenshot-fixture <scene>`. The city is
/// `WorldGenerator.generate(seed: 2026)` with a few fields overwritten so a
/// foundation, a scaffold, an island-event card, or the Gazette is on screen.
/// The simulation is not advanced. This is not a played day and not a physical
/// iPhone Duo.
enum ScreenshotFixture {
    static let flag = "--pocket-republic-screenshot-fixture"
    static let seed: UInt64 = 2026

    enum Scene: String {
        case island
        case event
        case gazette
        case wide
    }

    static var scene: Scene? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: flag) else { return nil }
        if index + 1 < args.count, let named = Scene(rawValue: args[index + 1]) {
            return named
        }
        return .island
    }

    static var initialTab: Int { scene == .gazette ? 3 : 0 }

    static var accessibilityIdentifier: String? {
        scene.map { "screenshot-fixture-\($0.rawValue)" }
    }

    static func makeState(for scene: Scene) -> RepublicState {
        var state = WorldGenerator.generate(seed: seed)
        paintConstructionSites(&state)
        switch scene {
        case .island:
            break
        case .event, .wide:
            plantIslandEvent(&state)
        case .gazette:
            plantGazette(&state)
        }
        return state
    }

    /// Town hall at the camera centre becomes a foundation. The nearest other
    /// building becomes a scaffold. Worldgen itself only places finished buildings.
    private static func paintConstructionSites(_ state: inout RepublicState) {
        guard let hallIndex = state.buildings.firstIndex(where: { $0.kind == .townHall }) else { return }
        let hall = state.buildings[hallIndex]
        state.buildings[hallIndex].daysRequired = 4
        state.buildings[hallIndex].daysConstructed = 0

        let hx = state.map.x(of: hall.anchor)
        let hy = state.map.y(of: hall.anchor)
        let nearest = state.buildings.indices
            .filter { state.buildings[$0].id != hall.id }
            .min { lhs, rhs in
                distance(state.buildings[lhs], hx: hx, hy: hy, map: state.map)
                    < distance(state.buildings[rhs], hx: hx, hy: hy, map: state.map)
            }
        guard let nearest else { return }
        var required = state.config.constructionDays(for: state.buildings[nearest].kind)
        if required < 2 { required = 3 }
        let foundation = state.config.foundationDays(forRequired: required)
        state.buildings[nearest].daysRequired = required
        state.buildings[nearest].daysConstructed = foundation
    }

    private static func distance(_ building: Building, hx: Int32, hy: Int32, map: WorldMap) -> Int32 {
        let dx = map.x(of: building.anchor) - hx
        let dy = map.y(of: building.anchor) - hy
        return dx * dx + dy * dy
    }

    /// Pending Carnival card. `IslandView` opens it because nothing blocks the day.
    private static func plantIslandEvent(_ state: inout RepublicState) {
        guard let spec = EventDeck.spec(0) else { return }
        let district = centerDistrict(in: state)
        let headline = spec.headline.replacingOccurrences(of: "{district}", with: district.name)
        state.agenda.append(AgendaItem(
            id: DecisionID(90_001),
            kind: .advisoryTradeoff,
            tier: .advisory,
            raisedOnDay: state.day,
            expiresOnDay: state.day + 3,
            faction: nil,
            location: EventLocation(district: district.id),
            causes: [
                CauseFactor(.islandEvent, value: state.day, detail: spec.flavor),
                CauseFactor(.islandEvent, value: spec.id, detail: headline)
            ],
            options: spec.options.map { AgendaOption(id: $0.id, label: $0.label, effect: $0.effect) },
            salience: 60 + spec.weight,
            islandEventID: spec.id
        ))
    }

    /// Stories the Gazette already knows how to read. They were not produced by a tick.
    private static func plantGazette(_ state: inout RepublicState) {
        let district = centerDistrict(in: state)
        let location = EventLocation(district: district.id)
        state.events.append(GameEvent(
            id: EventID(90_001),
            day: state.day,
            kind: .islandEvent,
            location: location,
            causes: [CauseFactor(
                .islandEvent,
                value: 0,
                detail: "Carnival fills the streets of \(district.name). The treasury paid for the lanterns"
            )]
        ))
        state.events.append(GameEvent(
            id: EventID(90_002),
            day: state.day,
            kind: .buildingSiteStarted,
            location: location
        ))
        state.events.append(GameEvent(
            id: EventID(90_003),
            day: state.day,
            kind: .migrationArrival,
            location: location,
            magnitude: 4
        ))
    }

    private static func centerDistrict(in state: RepublicState) -> District {
        if let hall = state.buildings.first(where: { $0.kind == .townHall }),
           let district = state.districts.first(where: { $0.id == hall.district }) {
            return district
        }
        return state.districts[0]
    }
}

/// Marks a fixture launch in the accessibility tree. Ordinary launches are unchanged.
struct ScreenshotFixtureIdentity: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if let id = ScreenshotFixture.accessibilityIdentifier {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
