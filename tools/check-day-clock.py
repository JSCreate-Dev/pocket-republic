#!/usr/bin/env python3
"""Compile/check the actual Foundation-only clock policy without an iOS SDK."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'PocketRepublic/Simulation/DayClock.swift').read_text()
policy = source.split('/// One timer for the whole app.')[0]
policy = policy.replace('import PocketRepublicCore\n', '').replace('import Combine\n', '')
swift = os.environ.get('SWIFT_EXEC') or shutil.which('swiftc')
if not swift:
    raise SystemExit('Set SWIFT_EXEC to a Swift 6.2 swiftc executable')
checks = r'''
@main struct ClockChecks {
    static func main() {
        var p = DayClockPolicy()
        precondition(p.tickInterval == DayClockPolicy.leisurely, "Days must play by default")
        precondition(p.advancesPerTick == 1, "No catch-up batches")
        p.islandEventWaiting = true
        precondition(p.tickInterval != nil, "Optional event cards must not hold time")
        p.blockedByCrisis = true
        precondition(p.tickInterval == nil && p.controlLabel == "Decision")
        p.blockedByCrisis = false
        p.modalHold = true
        precondition(p.tickInterval == nil && p.controlLabel == "Confirming")
        p.modalHold = false
        p.sceneActive = false
        precondition(p.tickInterval == nil && p.advancesPerTick == 0)
        p.sceneActive = true
        p.saveBlocked = true
        precondition(p.tickInterval == nil && p.controlLabel == "Save issue")
        p.saveBlocked = false
        p.pace = .paused
        precondition(p.tickInterval == nil && p.controlLabel == "Paused")
        p.pace = .playing(DayClockPolicy.steady)
        precondition(p.tickInterval == 3.5 && p.controlLabel == "Steady")
        for bad in [0.0, -1, 31, Double.nan, Double.infinity] {
            p.pace = .playing(bad)
            precondition(p.tickInterval == nil, "Invalid speed must never schedule")
        }
        print("Clock policy checks passed: automatic default, optional events, all holds, pause, pace, no catch-up, invalid speeds")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='pocket-clock-') as scratch:
    folder = Path(scratch)
    (folder / 'Policy.swift').write_text(policy)
    (folder / 'Checks.swift').write_text(checks)
    subprocess.run([swift, str(folder / 'Policy.swift'), str(folder / 'Checks.swift'), '-o', str(folder / 'checks')], check=True)
    subprocess.run([str(folder / 'checks')], check=True)
