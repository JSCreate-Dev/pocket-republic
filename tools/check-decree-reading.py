#!/usr/bin/env python3
"""Typecheck/test actual Foundation-only decree card reading against the built core."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]

def extract(text, declaration):
    start = text.index(declaration)
    opening = text.index('{', start)
    depth = 0
    for position in range(opening, len(text)):
        depth += (text[position] == '{') - (text[position] == '}')
        if depth == 0:
            return text[start:position+1]
    raise RuntimeError('unclosed declaration')

card = extract((root/'PocketRepublic/Views/DecreeBoard.swift').read_text(), 'struct DecreeCardReading:')
copy = extract((root/'PocketRepublic/Views/AgendaChoiceCard.swift').read_text(), 'enum AgendaEffectCopy {')
harness = r'''
var state = WorldGenerator.generate(seed: 44)
state.agenda.removeAll()
let before = state.stateHash()
for spec in DecreeCatalogue.all {
    let reading = DecreeCardReading.make(spec: spec, state: state)
    precondition(reading.canIssue, "standing card wrongly requires a council slot")
    precondition(!reading.purpose.isEmpty && !reading.duration.isEmpty && !reading.caution.isEmpty)
    precondition(!reading.effects.isEmpty)
}
precondition(state.stateHash() == before)
let wage = DecreeCatalogue.all.first { $0.effect.civicWageDelta != 0 }!
let wageCard = DecreeCardReading.make(spec: wage, state: state)
precondition(wageCard.costLabel == "Free")
precondition(wageCard.duration.contains("per civic worker/day"))
precondition(wageCard.caution.contains("future civic payroll"))
let tax = DecreeCatalogue.all.first { $0.effect.incomeTaxDelta > 0 }!
state.policy.incomeTaxPercent = 80
precondition(DecreeCardReading.make(spec: tax, state: state).duration.contains("80% → 80%"))
let works = DecreeCatalogue.all.first { $0.effect.districtNeglectReset }!
precondition(DecreeCardReading.make(spec: works, state: state).effects.contains("Clears neglect in every district"))
let food = DecreeCatalogue.all.first { $0.effect.foodImport > 0 }!
precondition(SimulationEngine.apply(.issueDecree(food.name), to: &state) == .accepted)
let cooldown = DecreeCardReading.make(spec: food, state: state)
precondition(!cooldown.canIssue && cooldown.availability!.contains("Day 3"))
state.treasury = 0
let short = DecreeCardReading.make(spec: works, state: state)
precondition(!short.canIssue && short.shortfall == works.cost)
print("Decree reading passed: standing availability, read-only state, free/recurring wages, clamped lasting tax, global works, cooldown and shortfall")
'''
build = root/'PocketRepublicCore/.build/release'
with tempfile.TemporaryDirectory(prefix='pocket-decree-reading-') as folder:
    file = Path(folder)/'main.swift'
    binary = Path(folder)/'decree-reading'
    file.write_text('import Foundation\nimport PocketRepublicCore\n' + copy + '\n' + card + '\n' + harness)
    subprocess.run([os.environ.get('SWIFT_EXEC', 'swiftc'), '-I', str(build/'Modules'), str(file),
                    *map(str, (build/'PocketRepublicCore.build').glob('*.o')), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
