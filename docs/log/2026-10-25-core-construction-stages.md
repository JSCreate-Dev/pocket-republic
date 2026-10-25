# 2026-10-25 7:05 PM EDT — Game Logic — `core/construction-stages`

Branch: `core/construction-stages`, off main `4ba14c1` (includes #18, #19, #20, #21). Implements the spec from PR #20, [docs/DESIGN.md](../DESIGN.md) section 7.

## Changed

A placed building is now a site that takes sim-days to open.

- `Building` stores `daysConstructed: Int32` and `daysRequired: Int32`. Everything else is derived: `isUnderConstruction`, `isOperational`, `constructionProgress: Double`, `opensOnDay`, `stage(in:)`, `stageProgress(in:)`. No `Double` and no dictionary entered the save, so `stateHash()` stays canonical. New `ConstructionStage` enum (`foundation`, `scaffold`, `complete`).
- `BalanceConfig` gains `constructionDaysByKind: [Int32]` (dense, indexed by `BuildingKind.rawValue`), `constructionDaysMultiplierPercent` (100) and `constructionFoundationPercent` (33), plus `constructionDays(for:)` and `foundationDays(forRequired:)`. Days: 2 house; 3 police, market, workshop, farm; 4 clinic, school, dock; 0 town hall. Only a multiplier of exactly 0 makes a build instant — rounding never silently skips the site.
- `SimulationEngine.advanceConstruction` is the first step of `advance`, before the `fields.dirty` check, so a market that finishes on day N is a service source that same day. It marks the fields dirty on any completion and emits `buildingConstructed` there.
- Every other step skips a site: `assignWork`, `produce`, `distributeFood` (market stalls and farm lots), `payWages`, `collectTaxes`, `payUpkeep`, `spoil`, `DistanceFields.rebuild` (service fields and `nearestMarket`), `WorldGenerator.freeHouse`, famine relief in `Intents`, and decree food delivery in `Decrees`.
- Placement charges the full build cost and claims the tiles, then emits the new `EventKind.buildingSiteStarted`. A farm/workshop/dock commission now expires at `max(advisoryExpiryDays, daysRequired + 2)` so the choice outlives the build.
- `WorldGenerator.construct` takes an explicit `daysRequired`, defaulting to 0, so a new city still starts with finished buildings.
- `RepublicState.schemaVersion` 2 → 3.
- Inspect: `Under construction · Scaffold, 0 of 2 days`, no people section, and `Opens` / `Progress` / `Placed` in place of `Food stored`, `Funds`, `Upkeep`, `Residents in range`.
- `docs/DESIGN.md` 7.8 and 7.10 amended for the two deliberate deviations below. `PROGRESS.md` Current state overwritten.

## Verified

`docker run --rm -v "$PWD":/pkg -w /pkg swift:6.2 swift test` from `PocketRepublicCore`, on this Linux VM, which has no native Swift toolchain:

- main `4ba14c1` first, as a baseline: **71 tests, 0 failures**, 275 s.
- this branch: **88 tests, 0 failures**, 288 s.

Those are debug timings, roughly 12x slower than release, so they say nothing about the core README's per-tick figures. No existing test file was edited; the 17 new tests are all in `ConstructionTests.swift`. The placement, hunger, conservation, determinism and agenda suites passed untouched, which was the specific thing to confirm.

The new tests cover spec 7.12 end to end: the day table and the foundation split; a clinic walking foundation → scaffold → complete with `constructionProgress` 0.0 → 0.25 → 0.5 → 0.75 → 1.0; a house next door to a new market staying unserved until the day the market opens and served that same day; no upkeep charged until it opens and `upkeepCivic` the moment it does; nobody hired into a site and hiring starting the day it opens; money and food reconciling across placement, the whole build, completion and a cancel mid-build; a cancelled site freezing and never announcing that it opened; `buildingSiteStarted` and `buildingConstructed` as separate events on the right days; `constructionDaysMultiplierPercent = 0` reproducing the old instant build including the event it emits; worldgen buildings complete on day 0; two integers and no float in the encoded save; a schema 2 save failing to decode; and the inspect panel's rows.

The iOS target was read but not changed, and is **not** build-verified here — there is no Xcode on this machine, so CI is the first real check. The one app-side risk was `EventKind`: `MainView` prettifies `rawValue` and does not switch exhaustively, so the new case is safe.

## Deliberate deviations from the spec, both recorded in `docs/DESIGN.md`

1. **No `InspectTone.progress`.** 7.8 asks for a new tone. `PocketRepublic/Views/BuildingInspectPanel.swift` switches over `InspectTone` exhaustively with no `default`, so adding a case would fail the iOS build from a core-only PR. The status row ships with `.calm` and a construction branch ahead of `problemPriority` instead. Adding the tone is an Ios Dev change.
2. **Field names.** 7.10 named these `constructionDaysDone` / `constructionDaysRequired`; the request asked for `daysConstructed` / `daysRequired`, which is what shipped. 7.10 now records both.

## Not done, and one pre-existing bug

**Nothing renders differently.** The renderer still draws every building with its finished sprite, so on the island a site looks complete while the core treats it as unbuilt. The 8 imagesets in 7.6 do not exist and `IslandScene` does not read the stage. `WorldSnapshot.visibleBuildings` carries whole `Building` values, so the stage is already available with no further core change. 7.8's app-side copy (mode picker annotation, **Cancel construction**, the captioned reach preview) is also app-side.

**Pre-existing, untouched:** `payUpkeep` iterates `s.buildings where b.kind != .house` with no occupancy check, so a *demolished* building keeps paying upkeep forever. This branch adds an `isOperational` guard there but deliberately does not add an occupancy guard — that would move treasury balance and every downstream hash, which belongs in its own PR with its own test.

## Next

Visual And Grapchics: the 8 foundation and scaffold imagesets per 7.6. Ios Dev: stage rendering and the pop per 7.7, `InspectTone.progress`, and 7.8's copy. Open design question for Game Designer: the commission is still raised at placement, so the owner is asked how a farm will be run up to 3 days before it opens — moving it to completion day is a one-line change if that reads wrong in a playtest.
