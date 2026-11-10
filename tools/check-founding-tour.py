#!/usr/bin/env python3
"""Compile the actual UI-only founding tour policy and check lifecycle gates."""
import os
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root/'PocketRepublic/Views/IslandView.swift').read_text().split('// MARK: - Pure founding tour policy\n', 1)[1]
harness = r'''
precondition(FoundingTourPolicy.shouldAutostart(day: 0, seed: 44, seenSeed: "", enabled: true, blocked: false))
precondition(!FoundingTourPolicy.shouldAutostart(day: 1, seed: 44, seenSeed: "", enabled: true, blocked: false))
precondition(!FoundingTourPolicy.shouldAutostart(day: 0, seed: 44, seenSeed: "44", enabled: true, blocked: false))
precondition(!FoundingTourPolicy.shouldAutostart(day: 0, seed: 44, seenSeed: "", enabled: false, blocked: false))
precondition(!FoundingTourPolicy.shouldAutostart(day: 0, seed: 44, seenSeed: "", enabled: true, blocked: true))
for exitBeat in 0..<3 {
    var policy = FoundingTourPolicy()
    precondition(policy.begin() && policy.clockHeld)
    precondition(!policy.begin())
    for _ in 0..<exitBeat { precondition(policy.advance()) }
    policy.finish()
    precondition(!policy.clockHeld && !policy.advance())
    policy.finish()
    precondition(!policy.active)
    precondition(policy.begin() && policy.beat == 0)
}
var auto = FoundingTourPolicy()
precondition(auto.begin())
precondition(auto.advanceAutomatically() && auto.beat == 1)
precondition(auto.advance() && auto.beat == 2)
precondition(!auto.advanceAutomatically() && auto.active && auto.clockHeld)
auto.finish()
precondition(!auto.clockHeld)
var policy = FoundingTourPolicy()
precondition(policy.begin())
precondition(policy.advance() && policy.beat == 1)
precondition(policy.advance() && policy.beat == 2)
precondition(!policy.advance() && !policy.clockHeld)
precondition(!policy.advance())
print("Founding tour policy passed: fresh-only/seen/disabled/blocked gates, three beats, duplicate-start guard, skip/cancel/restart and hold release")
'''
with tempfile.TemporaryDirectory(prefix='pocket-tour-') as folder:
    file = Path(folder)/'tour.swift'
    binary = Path(folder)/'tour-check'
    file.write_text('import Foundation\n'+source+'\n'+harness)
    subprocess.run([os.environ.get('SWIFT_EXEC','swiftc'),str(file),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
