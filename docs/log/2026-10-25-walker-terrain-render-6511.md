# 2026-10-25 — Walkers follow the daily routine, and batch 2 ground art is on the map

Branch: `cursor/walker-terrain-render-6511`

## What changed

Presentation only. `PocketRepublicCore` was not modified.

Walkers no longer shuttle home and back, and the drifting yellow road dots are gone. `IslandScene` reads `WalkerRoutine.plan` (`DailyRoutine`: home, work when employed, the market `shoppingMarket` already chose, then home). Doors are the entrances that plan returns. The simulated day has no clock, so while it stays paused the scene plays that plan across 24 hours at two seconds each and slides the sprite along `legPaths` between hours. Sprites are `walker_<0-5>_{ne|sw}_f0/f1`, 12×18, anchor (0.5, 0), nearest filtering. North (up-right) and west use the `ne` sheet; south and east use `sw`, flipped for west and east. Frame 1 plays only while moving. Hungry citizens keep the orange tint. A missing sheet falls back to a white dot.

Terrain, roads, and decorations replace the flat diamonds and grey roads. Ground tiles are `tile_<type>_N`, chosen with a stable hash of the tile coordinates, 64×32, anchor (0.5, 0.5). A missing imageset still draws the old diamond. Roads are overlays from `road_autotile.json`. N=1 is (x, y−1) and E=2 is (x+1, y). Under `point(x:y:)` those steps are up-right and down-right, so the bitmask is not remapped. Water tiles stack `tile_shore_*` where the edge faces land. Decorations use the `decos.json` sizes and anchor (0.5, 0) on empty sand, grass, fertile, and rock, picked by the same hash. The core stores no decoration map. Water frame 2 and palm sway are not played.

## State

`swift` is not installed in this environment, so `swift test` was not run. No iPhone run. `PROGRESS.md` was not edited.
