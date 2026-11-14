#!/usr/bin/env python3
"""Compile actual app readers/policies; no Apple renderer or fake UI assertions."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
island = (root / 'PocketRepublic/Views/IslandView.swift').read_text()
journey = island.split('struct OpeningJourney {', 1)[1].split('struct IslandPrompt {', 1)[0]
scene = (root / 'PocketRepublic/Views/IslandScene.swift').read_text()
life = scene.split('// MARK: - Pure living-world presentation', 1)[1].split('// MARK: - Pure world lighting', 1)[0]
lane = scene.split('private func laneOffset(', 1)[1].split('    private var proceduralWalker:', 1)[0]
lane = 'func laneOffset(' + lane
decrees = (root / 'PocketRepublic/Views/DecreeBoard.swift').read_text()
outcome = decrees.split('enum DecreeOutcomeReading {', 1)[1].split('/// The same authoritative nodes drive', 1)[0]
checks = r'''
var state = WorldGenerator.generate(seed: 42)
SimulationEngine.rebuildSpatialCaches(&state)
let original = state.stateHash()
precondition(OpeningJourney(state: state, record: "").finishedCount == 0)
precondition(OpeningJourney(state: state, record: "42:nonsense").finishedCount == 0)
precondition(OpeningJourney(state: state, record: "99:15").finishedCount == 0)
precondition(state.stateHash() == original)
let centre = state.map.index(x: 32, y: 32)
let workshop = WorldGenerator.place(&state, .workshop, near: centre)!
state.buildings[Int(workshop.raw)].daysRequired = 3
SimulationEngine.assignWork(&state)
precondition(OpeningJourney(state: state, record: "").finishedCount == 0, "Ordering a site must not complete a lesson")
state.buildings[Int(workshop.raw)].daysConstructed = 3
SimulationEngine.rebuildSpatialCaches(&state)
SimulationEngine.assignWork(&state)
for i in state.citizens.indices { state.citizens[i].happiness = 60 }
let working = OpeningJourney(state: state, record: "")
precondition(working.finishedCount == 1)
_ = WorldGenerator.place(&state, .house, near: centre)!
SimulationEngine.rebuildSpatialCaches(&state)
let welcome = OpeningJourney(state: state, record: working.record)
precondition(welcome.finishedCount == 3)
for i in state.citizens.indices { state.citizens[i].happiness = 20 }
let retained = OpeningJourney(state: state, record: welcome.record)
precondition(retained.finishedCount == 3, "A later fluctuation does not undo witnessed learning")
precondition(retained.instruction(fallback: "URGENT FOOD", goal: "food") == "URGENT FOOD")
precondition(!retained.complete, "No arrivals lesson without arrivals")
let checkpoint = state.stateHash()
_ = OpeningJourney(state: state, record: retained.record)
precondition(state.stateHash() == checkpoint)

for id: Int32 in [0, 1, 2, 55, -1] {
    var last = -1.0
    for step in 0...1000 {
        let t = Double(step) / 1000
        let next = IslandWalkPresentation.progress(t, citizen: id)
        precondition(next >= last && next >= 0 && next <= 1)
        last = next
    }
    precondition(IslandWalkPresentation.progress(0, citizen: id) == 0)
    precondition(abs(IslandWalkPresentation.progress(1, citizen: id) - 1) < 1e-12)
}
let laneMap = WorldGenerator.generate(seed: 42).map
let halfWidth: CGFloat = 32
let halfHeight: CGFloat = 16
var checkedRoad = false
for raw in 0..<laneMap.tileCount {
    let tile = TileIndex(Int32(raw))
    guard laneMap.isRoad(at: tile), laneMap.building(at: tile) == nil else { continue }
    let roads = laneMap.neighbours(of: tile).filter { laneMap.isRoad(at: $0) }
    guard roads.count >= 2 else { continue }
    let leg = [roads[0], tile, roads[1]]
    precondition(laneOffset(at: 0, leg: leg, map: laneMap) == .zero)
    precondition(laneOffset(at: 2, leg: leg, map: laneMap) == .zero)
    let shift = laneOffset(at: 1, leg: leg, map: laneMap)
    precondition(abs(shift.x) <= 2.1 && abs(shift.y) <= 1.1)
    checkedRoad = true
}
precondition(checkedRoad)
for building in state.buildings where building.occupiesGround(on: state.map) {
    let leg = [building.entrance, building.entrance, building.entrance]
    precondition(laneOffset(at: 1, leg: leg, map: state.map) == .zero)
}
precondition(IslandWalkPresentation.progress(.nan, citizen: 1) == 0)
precondition(IslandWalkPresentation.progress(0.2, citizen: 1) != IslandWalkPresentation.progress(0.2, citizen: 2))
func business(_ hour: Double = 12, _ staff: Int = 2, _ food: Int = 35,
              quiet: Bool = false, reduced: Bool = false, operational: Bool = true) -> IslandBusinessProfile {
    IslandBusinessProfile(hour: hour, operational: operational, workers: staff, food: food,
                          tracksFood: true, quiet: quiet, reducedMotion: reduced)
}
precondition(business().open && business().animate && business().stockDetails == 4)
precondition(!business(2).open && !business(20).animate)
precondition(!business(12, 0).open && !business(operational: false).open)
precondition(business(12, 2, 0).stockDetails == 0)
precondition(!business(quiet: true).animate && !business(reduced: true).animate)
precondition(!business(.infinity).open)

for x: Int32 in 0...64 {
    for y: Int32 in 0...64 {
        let depth = IslandEnvironmentProfile.waterDepth(x: x, y: y)
        precondition(depth >= 0 && depth <= 1)
        precondition(depth == IslandEnvironmentProfile.waterDepth(x: x, y: y))
        precondition(abs(depth - IslandEnvironmentProfile.waterDepth(x: x + 1, y: y)) < 0.2)
        precondition(abs(depth - IslandEnvironmentProfile.waterDepth(x: x, y: y + 1)) < 0.2)
    }
}
var political = WorldGenerator.generate(seed: 44)
let wage = DecreeCatalogue.all.first { $0.effect.civicWageDelta > 0 }!
let before = political
precondition(SimulationEngine.apply(.issueDecree(wage.name), to: &political) == .accepted)
let politicalHash = political.stateHash()
let receipt = DecreeOutcomeReading.lines(before: before, after: political)
precondition(receipt.contains { $0.contains("Public pay:") && $0.contains("→") })
precondition(receipt.contains { $0.contains("approval:") })
precondition(!receipt.contains { $0.contains("Treasury:") }, "A free decree must not invent a charge")
precondition(political.stateHash() == politicalHash)
print("Living island passed: ordered milestones, site vs opening, persisted progress, urgent needs, read-only readers, monotonic individual walking, business hours/staff/stock/quiet/reduced motion, actual decree results")
'''
with tempfile.TemporaryDirectory(prefix='pocket-living-') as folder:
    temp = Path(folder)
    main = temp / 'main.swift'
    main.write_text('import Foundation\nstruct OpeningJourney {' + journey + life
                    + lane + '\nenum DecreeOutcomeReading {' + outcome + checks)
    files = sorted((root / 'PocketRepublicCore/Sources/PocketRepublicCore').glob('*.swift'))
    subprocess.run([os.environ.get('SWIFT_EXEC', 'swiftc'), '-Onone', *map(str, files),
                    str(main), '-o', str(temp / 'checks')], check=True)
    subprocess.run([str(temp / 'checks')], check=True)
