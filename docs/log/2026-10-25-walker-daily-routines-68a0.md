# 2026-10-25 — Walker daily routines

Branch: `cursor/walker-daily-routines-68a0`

## What changed

Citizens no longer have only a home–work pair for the renderer to shuttle. `WalkerRoutine.plan` builds a day from needs and the clock: home in the morning, work through the middle of the day when they have a job, the market `shoppingMarket` says they buy from, then home at night. Hours 0..<24 pick a tile on that walk.

Destinations are entrance tiles from `BuildingAccess` (`building(at:)`, `entrance(of:)`, `isPassable`). Today's entrance is the building's single tile. `MapBuildingAccess.isPassable` forwards `WorldMap.isPassable` and does not replace it, so the footprint core can swap in real occupancy and entrance tiles without this routing changing shape. `Pathfinder` is a deterministic BFS on that access.

The island scene still animates the old home–work shuttle. It can sample `DailyRoutine` when the renderer picks this up.

## State

`WalkerRoutineTests` covers the home → work → market → home hour schedule, unemployed citizens skipping work, no market stop when the door is out of range, entrance tiles coming from the access interface, and a path around a blocked 3×3 footprint that never enters it. `swift test` on Swift 6.2 Linux, after merging current main: 57 tests, 0 failures. No iPhone run. `PROGRESS.md` was not edited.

## Next

The footprint PR should replace `MapBuildingAccess.entranceTile` and passability with its entrance and occupancy lookup. The SpriteKit scene should draw `DailyRoutine` instead of the two-point shuttle. Hunger fix is the parent branch (`cursor/hunger-surplus-fix-68a0`).
