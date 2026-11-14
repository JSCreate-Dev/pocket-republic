#!/usr/bin/env python3
"""Compile the actual government draft/readers with the real core, without Apple UI."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'PocketRepublic/Views/DecreeBoard.swift').read_text()
models = source.split('// MARK: - Government policy readers (no simulation mutation)', 1)[1].split('/// App-side reading of a decree.', 1)[0]
outcome = source.split('enum DecreeOutcomeReading {', 1)[1].split('/// The same authoritative nodes drive', 1)[0]
checks = r'''
var state = WorldGenerator.generate(seed: 42)
SimulationEngine.rebuildSpatialCaches(&state)
SimulationEngine.assignWork(&state)
let hash = state.stateHash()
let draft = GovernmentPolicyDraft(field: .household, state: state)
precondition(draft.policy(value: draft.original, in: state) == nil)
precondition(draft.policy(value: -1, in: state) == nil)
precondition(draft.policy(value: 81, in: state) == nil)
let proposed: Int64 = draft.original == 5 ? 10 : 5
let next = draft.policy(value: proposed, in: state)!
precondition(next.incomeTaxPercent == proposed)
precondition(next.businessTaxPercent == state.policy.businessTaxPercent && next.civicWage == state.policy.civicWage)
precondition(state.stateHash() == hash, "Review must not mutate the city")
var unrelated = state
unrelated.policy.businessTaxPercent = 17
precondition(draft.policy(value: proposed, in: unrelated)!.businessTaxPercent == 17, "Rebase the edited field without overwriting another policy")
unrelated.policy.incomeTaxPercent += 1
precondition(draft.policy(value: proposed, in: unrelated) == nil, "Reject a stale edit to this field")
var otherCity = WorldGenerator.generate(seed: 99)
precondition(draft.policy(value: proposed, in: otherCity) == nil)
otherCity.pending = PendingDecision(id: DecisionID(1), kind: .bankruptcy, raisedOnDay: 0,
    location: EventLocation(), causes: [], options: [])
let held = GovernmentPolicyDraft(field: .business, state: otherCity)
precondition(held.policy(value: 15, in: otherCity) == nil)
precondition(GovernmentBrief(state: otherCity).title.contains("decision"))

for field in GovernmentPolicyField.allCases {
    let edit = GovernmentPolicyDraft(field: field, state: state)
    let preferred: Int64 = field == .publicPay ? 6 : 15
    let value: Int64 = preferred == edit.original ? preferred + 1 : preferred
    guard let policy = edit.policy(value: value, in: state) else { preconditionFailure("Fixture must change the field") }
    var changed = state
    precondition(SimulationEngine.apply(.setPolicy(policy), to: &changed) == .accepted)
    precondition(changed.treasury == state.treasury && changed.factions == state.factions)
    precondition(changed.citizens.map(\.money) == state.citizens.map(\.money))
    precondition(changed.ledger == state.ledger)
    try changed.checkConservation()
    let receipt = DecreeOutcomeReading.lines(before: state, after: changed)
    precondition(receipt.count == 1 && receipt[0].contains("→"))
    let decoded = try JSONDecoder().decode(RepublicState.self, from: JSONEncoder().encode(changed))
    precondition(decoded.stateHash() == changed.stateHash())
}
let wageDraft = GovernmentPolicyDraft(field: .publicPay, state: state)
precondition(wageDraft.policy(value: 21, in: state) == nil)
let publicStaff = state.buildings.filter { $0.kind.isCivic && $0.isStanding(on: state.map) }.reduce(0) { $0 + $1.workers.count }
let pay = GovernmentPolicyReading(field: .publicPay, value: 6, state: state)
precondition(pay.headline.contains("$\(publicStaff * 6) per day"))
precondition(pay.detail.contains("No money moves"))
precondition(GovernmentPolicyReading(field: .publicPay, value: 0, state: state).warning != nil)
precondition(GovernmentPolicyReading(field: .publicPay, value: Int64.max, state: state).warning != nil)
precondition(GovernmentPolicyReading(field: .household, value: 80, state: state).warning != nil)
precondition(GovernmentPolicyReading(field: .household, value: 0, state: state).warning == nil)
precondition(GovernmentPolicyReading(field: .business, value: 15, state: state).detail.contains("not a tax on sales or profit"))
for decree in DecreeCatalogue.all {
    precondition(GovernmentDecreeGroup.all.includes(decree))
    precondition(GovernmentDecreeGroup.allCases.filter { $0 != .all && $0.includes(decree) }.count == 1)
}
var tense = state
for i in tense.citizens.indices { tense.citizens[i].daysHungry = 0 }
tense.treasury = 1000; tense.corruption = 0; tense.districts[0].unrest = 50
precondition(GovernmentBrief(state: tense).suggestion == "Proclaim a market festival")
var hungry = state
hungry.citizens[0].daysHungry = 1
precondition(GovernmentBrief(state: hungry).suggestion == "Decree bread rationing")
precondition(state.stateHash() == hash)
print("Government policy passed: read-only drafts, field-only merge, stale/seed/crisis guards, bounds, real intents and receipts, no upfront money/favor changes, conservation, save roundtrip, payroll/tax copy, decree groups and need briefing")
'''
with tempfile.TemporaryDirectory(prefix='pocket-government-') as folder:
    temp = Path(folder)
    main = temp / 'main.swift'
    main.write_text('import Foundation\n' + models + '\nenum DecreeOutcomeReading {' + outcome + checks)
    files = sorted((root / 'PocketRepublicCore/Sources/PocketRepublicCore').glob('*.swift'))
    subprocess.run([os.environ.get('SWIFT_EXEC', 'swiftc'), '-Onone', *map(str, files), str(main), '-o', str(temp / 'checks')], check=True)
    subprocess.run([str(temp / 'checks')], check=True)
