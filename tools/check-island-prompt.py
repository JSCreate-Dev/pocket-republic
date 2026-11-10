#!/usr/bin/env python3
"""Compile the actual app-side opening advice, without the Apple UI frameworks."""
import os, subprocess, tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/'PocketRepublic/Views/IslandView.swift').read_text().split('struct IslandPrompt {',1)[1].split('// MARK: - Pure founding tour policy',1)[0]
checks=r'''
var state = WorldGenerator.generate(seed: 42)
SimulationEngine.rebuildSpatialCaches(&state)
let openingHash = state.stateHash()
let opening = IslandPrompt.make(in: state)
precondition(opening.title.contains("3") && !opening.title.contains("16"))
precondition(opening.message.contains("automatically"))
precondition(state.stateHash() == openingHash)
SimulationEngine.assignWork(&state)
for i in state.citizens.indices { state.citizens[i].happiness = 60 }
let before = state.stateHash()
let candidate = IslandPrompt.suggestedSite(for: .workshop, in: state)
precondition(candidate != nil)
if case .valid = SimulationEngine.validatePlacement(.workshop, at: candidate!, in: state) {} else { preconditionFailure("suggested site must be legal") }
precondition(IslandPrompt.suggestedSite(for: .workshop, in: state) == candidate)
precondition(state.stateHash() == before, "preview must not spend or mutate")
let work = IslandPrompt.make(in: state)
precondition(work.action == .build(.workshop) && work.title.contains("3"))
precondition(state.stateHash() == before)
let centre = state.map.index(x: 32, y: 32)
let site = WorldGenerator.place(&state, .workshop, near: centre)!
state.buildings[Int(site.raw)].daysRequired = 3
let waiting = IslandPrompt.make(in: state)
precondition(waiting.action == .inspect(site), "Do not offer another workshop while one is building")
state.buildings[Int(site.raw)].daysConstructed = 3
SimulationEngine.rebuildSpatialCaches(&state)
SimulationEngine.assignWork(&state)
precondition(IslandPrompt.make(in: state).action == .build(.house))
state.citizens[0].daysHungry = 1
precondition(IslandPrompt.make(in: state).action == .overlay(.foodAccess))
print("Island prompt passed: real job shortage, pending construction, housing and food actions; reader does not mutate state")
'''
# Run in the same source module as the core to exercise genuine internal fixture
# setup without exporting simulation mutation helpers solely for a test.
with tempfile.TemporaryDirectory(prefix='pocket-prompt-') as folder:
    temp=Path(folder)
    main=temp/'main.swift'; main.write_text('import Foundation\nstruct IslandPrompt {'+source+'\n'+checks)
    files=sorted((root/'PocketRepublicCore/Sources/PocketRepublicCore').glob('*.swift'))
    subprocess.run([os.environ.get('SWIFT_EXEC','swiftc'),'-Onone',*map(str,files),str(main),'-o',str(temp/'checks')],check=True)
    subprocess.run([str(temp/'checks')],check=True)
