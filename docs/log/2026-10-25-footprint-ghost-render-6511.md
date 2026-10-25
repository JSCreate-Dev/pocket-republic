# 2026-10-25 11:40 AM EDT — Ios Dev — `cursor/footprint-ghost-render-6511`

Presentation only. The footprint core (sizes, placement rules, `tilesCovered`, entrances, occupancy, `isPassable`) stays with Game Logic. This branch merged main through `f48dc67` (art direction v1, then design sections 4–6 in PR #8). Those new sections are spec only and are not implemented here. `PROGRESS.md` was not edited.

## What changed

- Buildings draw as sprites anchored at `(0.5, 0)` on the south corner of the tiles `CityFootprintModel` reports. Node size comes from the `docs/art/sprites.json` table on PR #4 (house 128×125, town hall 192×222, and the rest of that file), not from the PNG pixel size. A few @2x/@3x heights are one pixel off, so `SKTexture.size()` is not used.
- The image name is `building_<kind>`. If that imageset is in the catalog the sprite is used; otherwise a placeholder of the same point size is drawn. Light is treated as coming from the top left (west face lighter, east face darker), matching `docs/ART_DIRECTION.md`.
- While a building tool is selected, a ghost of that sprite follows the tile under the finger. It tints green when `SimulationEngine.apply` would accept the placement and red when it would not, with the `IntentRejection` sentence on the map and in the control pane (both Duo postures). Market, clinic, school, and police also draw the tiles within `maxServiceDistance` (20) along the current passable network.
- A light haptic fires when a building lands, and the ghost hides so the new sprite is not immediately covered by an "occupied" preview.
- `CityFootprints.current` is `LegacyOneTileFootprintModel`. That stub reports one tile (`Building.tile`), treats that tile as the entrance, reads occupancy from `WorldMap.building(at:)`, and runs placement by copying state and calling `SimulationEngine.apply`. It does not change the live city.

## State

- The simulation is still one building id per tile. Art-sized sprites are anchored on that single tile's south corner, so a house drawn at 128 pt hangs wider than the cell the simulator occupies until the core reports a real footprint.
- `isPassable` and the cosmetic walker shuttle are unchanged. Walkers still route through every building tile.
- `PocketRepublicCore` was not modified. This environment has no Swift toolchain and no iPhone, so `swift test` and the device build were not run.
- PR #4's imagesets are not on main. This branch already uses their names and point sizes, so it draws placeholders now and the real sprites after that PR merges.

## Next steps

- Replace `CityFootprints.current` with Game Logic's API (`footprintWidth` / `footprintDepth`, `tilesCovered`, entrance tile, occupancy lookup, side-effect-free placement check). Call sites in `IslandScene` should stay. The south corner then moves to the front of the real footprint, and the sprite widths already match `(W+H)×32`.
- Do not change `isPassable` in that swap; Game Logic owns passability and walker routing and will read the entrance and occupancy from the core model.
- `docs/ART_DIRECTION.md` still says sprite canvas width is footprint width in tiles × 64. That matches `(W+H)×32` for squares only. Non-square kinds in `sprites.json` (market, workshop, dock) are 160 pt wide, not 192. This branch follows `sprites.json` and `docs/DESIGN.md`.
