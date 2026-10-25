# 2026-10-25 — Game Logic — `cursor/building-footprints-671d`

## What changed

Multi-tile footprints in `PocketRepublicCore`. Sizes match `docs/DESIGN.md` (anchor is the minimum-x, minimum-y corner; no rotation). Placement, demolition, snapshots, and saves use the footprint. `isPassable` is true for roads and for each building's entrance only. World generation paints extra fertile 4×4 patches so a farm can meet the half-fertile rule, and parks the dock on the east shore. `RepublicState.schemaVersion` is 2. `BuildingOccupancy.occupant` now calls `WorldMap.buildingAt(_:)`.

## State

Core only. Ghost preview, sprites, and the inspect panel UI are unchanged. Walker routines were not edited; they already call `isPassable`.

`swift test` in `PocketRepublicCore` on Swift 6.2 (Linux, debug): 65 tests, 0 failures, after merging main `e2aa20c`. One inspect fixture needed the entrance tile marked passable; that test was re-run green. No Xcode project file edits.

## Next steps

Ios Dev can call `validatePlacement` for the ghost and `buildingAt(_:)` for which building covers a tile. Hunger and walker routing are still open.
