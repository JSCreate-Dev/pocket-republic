# Pocket Republic art batch 2: asset list
Everything is an Xcode `.imageset` (@1x/@2x/@3x PNG with alpha + Contents.json). Drop the folders into `Assets.xcassets`. Sizes below are @1x points.
Generator scripts are in `tools/art/` (terrain/roads `gen2.py`, decos/walkers/icons `gen3.py`, preview `prev.py`; run with `PYTHONHASHSEED=1`).

## Coordinate convention (read first)
Grid (x,y). Screen iso: tile (x,y) center at screenX=(x−y)·32, screenDown=(x+y)·16 (in SpriteKit, negate for y-up).
**N = (x, y−1)** sits up-right on screen and shares the tile's top-right edge. **E = (x+1, y)** is down-right, **S = (x, y+1)** down-left, **W = (x−1, y)** up-left.
Checked against `IslandScene.point(x:y:)` (`halfWidth` 32, `halfHeight` 16): screen x = (x − y) · 32 and SpriteKit y = −(x + y) · 16. That puts N up-right, E down-right, S down-left, and W up-left, so the road asset names match the bitmask and were not renamed.

## Terrain tiles: 64×32, anchor (0.5,0.5)
`tile_grass_0..3`, `tile_fertile_0..3`, `tile_sand_0..3`, `tile_rock_0..2`, `tile_water_0..3`, plus water frame 2 `tile_water_0..3_f1`.
Each is an opaque diamond with no outline, overdrawn about 1% past the edge so neighbours butt without hairline gaps. Pick the variant with a stable hash, e.g. `let h = (x &* 73856093) ^ (y &* 19349663); variant = abs(h) % count`. Never use random, so the map doesn't reshuffle.
Water animation: `SKAction.repeatForever(.animate(with:[f0,f1], timePerFrame: 0.8))`, with the start phase offset by the hash.

## Shoreline foam: 64×32 overlays, anchor (0.5,0.5), z just above the water tile
`tile_shore_n/e/s/w` draws foam along the edge facing land in that direction. `tile_shore_corner_ne/se/sw/nw` is for land only diagonally (only when both orthogonal neighbours of that corner are water). Stack every overlay that applies on a water tile.

## Roads: 64×32 transparent overlays drawn on top of the terrain tile, anchor (0.5,0.5)
Bitmask = N·1 + E·2 + S·4 + W·8 (bit set when that neighbour is a road). Also in `road_autotile.json`.
| mask | asset | mask | asset |
|---|---|---|---|
|0|road_single|8|road_end_w|
|1|road_end_n|9|road_corner_wn|
|2|road_end_e|10|road_straight_ew|
|3|road_corner_ne|11|road_t_wne|
|4|road_end_s|12|road_corner_sw|
|5|road_straight_ns|13|road_t_swn|
|6|road_corner_es|14|road_t_esw|
|7|road_t_nes|15|road_cross|
The `road_end_X` and `road_t_XYZ` names list the connected sides. For example, road_end_n connects only to N, and road_t_nes is open N, E and S.

## Decorations: anchor (0.5, 0) at the tile center (a few px below looks grounded), 1-tile footprint
deco_palm_0 52×65, deco_palm_1 44×50, deco_palm_2 52×62, deco_bush_0 38×33, deco_bush_1 (flowering) 38×31, deco_rock_0 40×36, deco_rock_1 34×26, deco_flowers_0 34×22 (also in `decos.json`).
Palm sway: `deco_palm_N_sway1` (canopy sheared right) and `_sway2` (left). Loop f0→sway1→f0→sway2 at about 0.5 s per frame, phase from the hash. Or skip the frames and use the cheap version: an SKAction rotate of ±2° with anchor at the base, easeInEaseOut.
Z-order follows the same rule as buildings: z = x + y of the footprint's south tile (plus a small fraction for walkers inside the tile).

## Walkers: 12×18 at 1x (10×16 figure + 1 px outline), anchor (0.5, 0) at the feet
`walker_0..5_{ne|sw}_f{0|1}`. There are 6 shirt/skin/hair combos. For NW use `ne` frames with xScale −1, and for SE use `sw` with xScale −1. Alternate f0/f1 every 0.15 s while moving, and hold f0 when idle. The art is pixel art, so set `texture.filteringMode = .nearest`.
Hungry: keep the existing orange tint via `colorBlendFactor` 0.55 with #F2622A.
`cart_0_f0/_f1` is 20×15 (wheel spoke frames, faces east, xScale −1 to flip), anchor (0.5,0).

## Icons: 24 pt (24/48/72 px)
icon_coin, icon_people, icon_food, icon_happy, icon_day, icon_decree, icon_alert. See UI_STYLE.md.

## Previews
`terrain_preview.png` shows an island patch composited at @2x. `ui_style_sheet.png` is the UI mockup.
