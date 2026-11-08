#!/usr/bin/env python3
"""Compile the real Foundation-only light policy and check visual bounds."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'PocketRepublic/Views/IslandScene.swift').read_text()
policy = source.split('// MARK: - Pure world lighting\n', 1)[1]
harness = r'''
func values(_ p: IslandLightProfile) -> [Double] {
    [p.nightAlpha, p.sunAlpha, p.vignetteAlpha, p.shadowAlpha, p.entryAlpha]
}
var darkest = 0.0
var brightest = 1.0
for step in 0...2400 {
    let sample = IslandLightProfile.sample(elapsed: Double(step) / 10, reduceMotion: false)
    precondition(values(sample).allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })
    precondition(sample.nightAlpha <= 0.22 + 1e-12)
    precondition(sample.sunAlpha <= 0.052 + 1e-12)
    precondition(sample.vignetteAlpha <= 0.12 + 1e-12)
    darkest = max(darkest, sample.nightAlpha)
    brightest = min(brightest, sample.nightAlpha)
    let next = values(IslandLightProfile.sample(elapsed: Double(step) / 10 + 0.1, reduceMotion: false))
    precondition(zip(values(sample), next).allSatisfy { abs($0 - $1) < 0.01 }, "visible discontinuity")
    let periodic = values(IslandLightProfile.sample(elapsed: Double(step) / 10 + 240, reduceMotion: false))
    precondition(zip(values(sample), periodic).allSatisfy { abs($0 - $1) < 1e-10 })
}
precondition(darkest - brightest > 0.19)
let steady = values(IslandLightProfile.sample(elapsed: 0, reduceMotion: true))
for time in [0.0, 100, 240, 9000, Double.infinity, Double.nan, -100] {
    precondition(values(IslandLightProfile.sample(elapsed: time, reduceMotion: true)) == steady)
    precondition(values(IslandLightProfile.sample(elapsed: time, reduceMotion: false)).allSatisfy { $0.isFinite })
}
print("World lighting policy passed: bounded veils, continuity, full cycle, periodicity, Reduce Motion, invalid time")
'''
with tempfile.TemporaryDirectory(prefix='pocket-lighting-') as folder:
    swift = Path(folder) / 'lighting.swift'
    binary = Path(folder) / 'lighting-check'
    swift.write_text('import Foundation\n' + policy + '\n' + harness)
    subprocess.run([os.environ.get('SWIFT_EXEC', 'swiftc'), str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
