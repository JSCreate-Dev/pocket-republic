# 2026-10-25 — Walker daily routines, re-landed on main

Branch: `cursor/walker-routines-main-68a0`

## What changed

PR #13 never reached main. It was merged into the hunger branch after that branch had already been squash-merged, so `origin/main` never received the walker files. This branch copies only what `1d32878` added on top of its parent `3fdab91`: `WalkerRouting.swift`, `WalkerRoutineTests.swift`, and the original walker log. The hunger diff is not reapplied.

Main already has multi-tile footprints and the round-robin `distributeFood` from #14, and this branch includes #9 (`b032bb2`). `Building.tile` is the entrance. `MapBuildingAccess` records that door and forwards `WorldMap.isPassable` and `building(at:)`. #9's island scene still draws the home–work shuttle, and that shuttle already walks `isPassable` tiles between `building.tile` doors, so the routines use the same entrances and the sprite and ghost rendering is left as #9 wrote it. Food distribution is untouched.

## State

`swift test` in `PocketRepublicCore` (Swift 6.2, Linux): 71 tests, 0 failures. No iPhone run. `PROGRESS.md` was not edited.
