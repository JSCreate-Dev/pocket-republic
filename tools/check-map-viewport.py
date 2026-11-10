#!/usr/bin/env python3
"""Exercise actual app viewport bounds without importing Apple UI frameworks."""
import os
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'PocketRepublic/Views/IslandView.swift').read_text()
policy = source.split('// MARK: - Pure map viewport bounds', 1)[1].split('private struct CityDisplayLayout', 1)[0]
checks = r'''
for size in [CGSize(width: 390, height: 700), CGSize(width: 320, height: 450),
             CGSize(width: 844, height: 290), CGSize(width: 900, height: 900)] {
    for hud: CGFloat in [80, 160, 260] {
        for dock: CGFloat in [110, 180, 250] {
            let view = IslandMapBounds(size: size, desiredPanelHeight: 128, hudHeight: hud, dockHeight: dock)
            precondition(view.controls.maxY == size.height, "Dock must stay inside the content above navigation")
            precondition(view.controls.height >= dock + 8)
            precondition(view.focus.maxY <= view.controls.minY)
            precondition(view.focus.height > 0 && view.focus.minY >= 0)
            if size.height - view.controls.height >= hud + 96 {
                precondition(view.focus.minY >= hud + 16, "Town must be framed below the measured HUD")
            }
        }
    }
}
let normal = IslandMapBounds(size: CGSize(width: 390, height: 700), desiredPanelHeight: 128, hudHeight: 120, dockHeight: 110)
let large = IslandMapBounds(size: CGSize(width: 390, height: 700), desiredPanelHeight: 128, hudHeight: 200, dockHeight: 180)
precondition(large.focus.midY > normal.focus.midY)
precondition(large.controls.minY < normal.controls.minY)
print("Map viewport passed: portrait, short landscape, unfolded and enlarged controls; camera avoids HUD where space allows")
'''
with tempfile.TemporaryDirectory(prefix='pocket-viewport-') as folder:
    path = Path(folder)
    main = path / 'main.swift'
    main.write_text('import Foundation\n' + policy + checks)
    subprocess.run([os.environ.get('SWIFT_EXEC', 'swiftc'), str(main), '-o', str(path / 'checks')], check=True)
    subprocess.run([str(path / 'checks')], check=True)
