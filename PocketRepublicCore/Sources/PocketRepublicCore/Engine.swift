public enum Engine {
    private static let names = ["Mateo", "Sofia", "Diego", "Elena", "Lucia", "Rafael", "Isabel", "Carlos", "Nina", "Tomas", "Amara", "Luis", "Carmen", "Pablo", "Maya", "Andres", "Rosa", "Felix", "Ana", "Hugo", "Lena", "Marco", "Eva", "Javier", "Clara"]
    private static let occupations = ["Farmer", "Merchant", "Worker", "Teacher", "Doctor"]

    public static func makeInitialState(worldSeed: UInt64) -> Republic {
        var state = Republic(worldSeed: worldSeed)
        state.citizens = names.enumerated().map { index, name in
            Citizen(
                id: CitizenID(index + 1),
                name: name,
                occupation: occupations[index % occupations.count],
                ambition: 25 + (index * 17) % 70,
                loyalty: 30 + (index * 13) % 60,
                wealth: 20 + (index * 19) % 80,
                happiness: 45 + (index * 7) % 45,
                influence: 10 + (index * 11) % 70
            )
        }
        return state
    }

    public static func approval(of state: Republic) -> Int {
        guard !state.citizens.isEmpty else { return 0 }
        return state.citizens.map(\.loyalty).reduce(0, +) / state.citizens.count
    }

    public static func advance(_ oldState: Republic) -> Republic {
        guard oldState.pending == nil else { return oldState }
        var state = oldState
        var rng = SeededRNG(state: state.rngState)
        state.day += 1
        let farmers = state.citizens.filter { $0.occupation == "Farmer" }.count
        state.food = max(0, state.food + farmers * 4 - state.citizens.count * 2)
        state.treasury += state.citizens.count * state.tax / 2 - state.services * 2 - state.security
        if state.treasury < 0 { state.legitimacy = clamp(state.legitimacy - 3) }

        // Every citizen sees the same start-of-day corruption. Accumulate new cases afterward.
        let corruptionAtStart = state.corruption
        let hungry = state.food < state.citizens.count
        let taxPain = max(0, state.tax - 20) / 5
        let care = state.services / 25
        var newCorruption = 0
        for index in state.citizens.indices {
            let drift = rng.nextInt(upperBound: 7) - 3 + care - taxPain - (hungry ? 7 : 0)
            state.citizens[index].happiness = clamp(state.citizens[index].happiness + drift)
            state.citizens[index].loyalty = clamp(state.citizens[index].loyalty + drift / 2 - (corruptionAtStart > 50 ? 2 : 0))
            state.citizens[index].wealth = max(0, state.citizens[index].wealth + rng.nextInt(upperBound: 7) - state.tax / 10 - (hungry ? 4 : 0))
            if !state.citizens[index].criminal && state.citizens[index].wealth < 10 && state.citizens[index].ambition > 65 && rng.nextInt(upperBound: 100) < 12 {
                state.citizens[index].criminal = true
                newCorruption += 2
                let name = state.citizens[index].name
                log("\(name) was linked to black-market trading.", in: &state)
            }
            if state.citizens[index].loyalty < 25 && state.citizens[index].influence > 50 && rng.nextInt(upperBound: 100) < 16 {
                state.unrest = clamp(state.unrest + 9)
                let name = state.citizens[index].name
                log("\(name) organized an opposition rally.", in: &state)
            }
        }
        state.corruption = clamp(state.corruption + newCorruption + (state.security < 30 ? 2 : -1))
        let currentApproval = Self.approval(of: state)
        state.unrest = clamp(state.unrest + (currentApproval < 40 ? 5 : -2) + (state.food == 0 ? 8 : 0))
        state.legitimacy = clamp(state.legitimacy + (currentApproval > 60 ? 1 : -2) - (state.corruption > 65 ? 2 : 0))
        if state.food == 0 { log("Food reserves exhausted. Families demand action.", in: &state) }
        if state.unrest >= 75 && state.legitimacy < 45 {
            state.pending = "revolution"
            log("A revolutionary coalition demands your resignation!", in: &state)
        } else if state.corruption >= 65 && rng.nextInt(upperBound: 100) < 18 {
            state.pending = "scandal"
            log("A corruption scandal has reached the presidential palace.", in: &state)
        } else if state.day % 5 == 0 {
            log("The island council reports \(currentApproval)% public approval.", in: &state)
        }
        state.rngState = rng.state
        return state
    }

    public static func decide(_ choice: Int, in oldState: Republic) -> Republic {
        guard let event = oldState.pending else { return oldState }
        guard event == "revolution" || event == "scandal" else { return oldState }
        guard choice == 0 || choice == 1 else { return oldState }
        var state = oldState
        if event == "revolution" {
            if choice == 0 {
                state.treasury -= 600
                state.unrest = 30
                state.legitimacy = clamp(state.legitimacy + 15)
                log("Negotiations produced a fragile peace.", in: &state)
            } else {
                state.security = clamp(state.security + 15)
                state.unrest = 45
                state.legitimacy = clamp(state.legitimacy - 20)
                log("Security forces dispersed the uprising; public trust collapsed.", in: &state)
            }
        } else if event == "scandal" {
            if choice == 0 {
                state.corruption = clamp(state.corruption - 25)
                state.legitimacy = clamp(state.legitimacy + 10)
                log("An independent investigation began.", in: &state)
            } else {
                state.corruption = clamp(state.corruption + 10)
                state.legitimacy = clamp(state.legitimacy - 15)
                log("The administration suppressed the investigation.", in: &state)
            }
        }
        state.pending = nil
        return state
    }

    private static func clamp(_ number: Int) -> Int {
        min(100, max(0, number))
    }

    private static func log(_ message: String, in state: inout Republic) {
        state.news.insert("Day \(state.day): \(message)", at: 0)
        state.news = Array(state.news.prefix(35))
    }
}
