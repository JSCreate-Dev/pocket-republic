# PROGRESS.md

Living handoff for Pocket Republic. Overwrite **Current state** on every change. Add a **Log** entry at the top of the log (newest first). The **North star** is the bar every pull request is judged against.

## North star

Jordan wants Pocket Republic to feel like a lively, living world with a real game feel, not a spreadsheet sim. Every screen is optimized for the iPhone Duo folding display, both folded and unfolded.

[docs/DESIGN.md](docs/DESIGN.md) is the source of truth for footprint sizes, placement rules, inspect-panel contents, sprite sizing, the concrete game-feel targets (including the Duo postures: map and panel side by side when unfolded, a bottom sheet when folded), and section 3 (decree cards and the newspaper-style event feed). Implementation ownership is the locked split in Current state below.

## Current state

Snapshot of `cursor/building-inspect-panel-ef49` on top of main `b960f52`, read against the code on 2026-10-25. `swift test` in `PocketRepublicCore` passed 51 tests on Swift 6.2 (Linux, debug). This environment has no iOS SDK, so the island UI was not run on a simulator or a phone.

### What works

The repo is a SwiftUI app plus a SpriteKit island, with the simulation in the pure-Swift package `PocketRepublicCore` (tools version 6.0, iOS 17 / macOS 14). The core sources import Foundation only. The app sends `PlayerIntent` values into `SimulationEngine` and draws a read-only `WorldSnapshot`. The clock advances only when **Advance One Day** is pressed. Animated walkers and the day/night wash do not write simulation state.

The core has agenda, decrees, and factions. `DecreeCatalogue` is data applied through `RepublicState.apply`. `DecreeSpec` has `name`, `cost`, `salience`, and `effect` (including `favorFactions` / `favorDeltas`). It has no flavor string yet. Factions are `labourers`, `merchants`, `officials`, and `landless`, with membership derived from occupation. Only a crisis (`pending` or a crisis-tier agenda item) blocks the day advance. The island shows crisis and agenda cards; Govern lists agenda items as option buttons and an income-tax stepper; People lists living citizens; Events lists the log newest first, with a prettified `EventKind` title and the first cause's detail. `EventKind` already covers the cases in the design's headline table, and each `GameEvent` can carry `CauseFactor`s, subjects, and a location.

The island scene draws procedural isometric terrain diamonds (64×32), grey roads, and one colored rectangle per building (26×23 pt, town hall 26×32) anchored near the tile. Camera pan and pinch-zoom work. Tools cover inspect, road, house, farm, market, clinic, school, police, workshop, and dock. Inspect is the default. A tap that is not a drag, with Inspect selected, uses the shared isometric hit test and then `WorldMap.buildingAt`. Whichever building occupies that tile is selected, including a footprint tile that is not `Building.tile`. Every occupied tile is highlighted. `BuildingInspectPanel` opens in the controls column. The view sizes to its content and does not present itself as a sheet, so a later layout pass can put the same view in the unfolded side pane or the folded bottom sheet. It shows the kind's display name, type, and district; one status line (no road access, then understaffed, then no food, otherwise "Running well"); workers out of capacity, or for a house the residents out of capacity with each person's hunger and job; food stored on farms and markets; funds; upkeep per day; residents within `maxServiceDistance` for market, clinic, school, and police; and the day built. Farms, workshops, and docks switch `OperatingMode` by sending `PlayerIntent.setOperatingMode` (the placement commission was the only writer of that field before this). Demolish asks for confirmation, then sends the existing `PlayerIntent.demolish`. The Town Hall offers no demolish button. Empty ground or Close clears the selection. Road and building tools still place on tap, and a drag still pans or pinches. A tap on empty ground still shows the `Tile x, y` caption. The design's side-by-side and bottom-sheet hosts, the sprite wiggle, and follow-a-resident are not in this change. Footprint sizes, hunger, and walker routing are unchanged.

Walkers are cosmetic. Up to 24 employed citizens whose home–work route crosses the viewport are white dots (orange when `daysHungry > 0`). Each dot shuttles along that route on a 20-second loop: 8s out, 2s dwell, 8s back, 2s dwell. Extra yellow dots drift on a sine around every 7th road tile. That matches the Oct 25 playtest note that the dots go back and forth.

Duo layout landed on 2026-10-25 (commits `1c4cdcd` through `1c26ce3`). `CityDisplayLayout` uses iOS 27.1 `reservedRegions` for a vertical book fold (controls on the trailing pane) and a horizontal laptop fold (controls in the lower pane), plus portrait, landscape, and wide flat rails. The target is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`). Deployment target stays iOS 17.0, so pre-27.1 devices skip the reserved-region branches. [docs/DESIGN.md](docs/DESIGN.md) still asks for a stronger split: unfolded map on one pane and inspect/agenda on the other, folded bottom sheet, camera and selection kept across the fold.

Saves: a valid city is `Application Support/PocketRepublic/spatial-v1.json` (envelope `formatVersion` 1, checksum `stateHash()`, `RepublicState.schemaVersion` 1), written atomically. A corrupt or unsupported file is kept and blocks play until **Start New City**. The app reads `UserDefaults` key `pocket.republic.save.v1` only to detect the old prototype; it never decodes or migrates it. A new city draws its `worldSeed` once with `UInt64.random` at the app boundary. After that, `worldSeed` and `rng` live in the saved state.

The test tree contains **51** `func test` methods (the previous 41, plus `BuildingInspectionTests` for hit-testing, the inspect model, and `setOperatingMode`). [PocketRepublicCore/README.md](PocketRepublicCore/README.md) records a Linux Swift 6.2 pass and says 40 tests, plus release timings (about 0.52 ms/tick at 1000 citizens). This pass re-ran the suite in debug on Swift 6.2 and did not re-measure those release timings. `EconomyReportTests` prints the 200-day dashboard and only asserts that the 250 citizens stay alive.

### Unverified

`runs-on: xcode-27` in `.github/workflows/unsigned-ipa.yml` is a real GitHub-hosted label. The [GitHub changelog for 2026-10-15](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/) marks the image generally available: macOS 27, Xcode 27 toolchain, Apple silicon only, labels `xcode-27` and `xcode-27-xlarge`. The [runner image readme](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md) (image `20261023.0307.1`) lists Xcode 27.1 as the default at `/Applications/Xcode_27.1.app`, which is the workflow's `DEVELOPER_DIR`, and includes the iOS 27.1 SDK plus an iPhone Duo simulator. That readme's announcement list still links the earlier public-preview issue, so preview-versus-GA wording disagrees across GitHub pages; the changelog is the GA notice. This workflow builds a generic `iphoneos` device app and does not boot the Duo simulator. No green run of this workflow is recorded in the repo.

[README.md](README.md) still says to open the project in Xcode 16.4 on a macOS 15 runner. The workflow used that pair until commit `d1e6ac2` (2026-10-25), which switched the label and `DEVELOPER_DIR` and did not update the README. `IslandView` calls `reservedRegions` inside `#available(iOS 27.1, *)`. That symbol still has to exist in the SDK at compile time, so the Xcode 16.4 instruction does not match the current island file. The Xcode project still says `CreatedOnToolsVersion = 15.0` and `LastUpgradeCheck = 1500`.

Jordan's iPhone playtest is recorded below. Which binary that was, and whether CI produced it, is not in the repo.

### Known issues

- **Hunger with food surplus.** [PocketRepublicCore/README.md](PocketRepublicCore/README.md) records a 200-day unattended run (the same shape as `EconomyReportTests.testPrintEconomyReport`: seed 2026, 250 citizens, `autoResolve` picking option 0) in which 47 of 250 citizens are hungry (~19%) while production is about 372/day against 250/day needed and about 164/day spoils. The test prints those lines and does not assert them, and this pass did not re-run it. The mechanism in `feedCitizens` matches that diagnosis: a citizen goes hungry when the home tile has no market inside `maxServiceDistance`, the market lacks a full ration, or the citizen cannot pay `foodPrice` (a short payment is refunded). `spoil` then removes `marketSpoilagePercent` of each farm and market store. Supply is in surplus on paper; distribution and affordability leave people hungry.
- **One-tile buildings, placeholder art.** `WorldMap.buildingAt` stores one building id per tile. Sprites are flat UIColor blocks. `Assets.xcassets` on this branch contains AccentColor only (no app icon, no building images).
- **Placeholder bundle id** `com.example.PocketRepublic` on Debug and Release.
- **Legacy save left behind.** `pocket.republic.save.v1` is detected and never migrated.
- **Inspect host is still the controls rail.** The panel view does not present a sheet. The design's unfolded side-by-side pane and folded bottom sheet are not built, and a tap does not wiggle the sprite or follow a resident.
- **Walkers are a home–work shuttle**, unrelated to entrances or the clock.
- **Decrees and events read as raw rows.** Agenda options show the label and a bare dismiss. The event list can repeat the same kind and cause on separate rows. [docs/DESIGN.md](docs/DESIGN.md) section 3 is the target presentation. `DecreeSpec` has no `flavor` field yet.

### Design on main

[docs/DESIGN.md](docs/DESIGN.md) came in with PR #2 (`dd87c6e`), including section 3. Sections 1–2 specify multi-tile footprints on the 96×96 map:

| Building | Footprint | Extra rule |
|---|---|---|
| House | 2×2 | |
| Police | 2×2 | |
| Market | 3×2 | |
| Workshop | 3×2 | |
| Farm | 3×3 | at least half its tiles fertile |
| Clinic | 3×3 | |
| School | 3×3 | |
| Town Hall | 3×3 | |
| Dock | 2×3 | one long side touches water |

Placement in that doc: anchor plus footprint, every covered tile buildable and empty, road-facing entrance, district taken from the entrance tile, only the entrance passable, demolish clears every covered tile, green/red ghost from `IntentRejection`, service buildings preview `maxServiceDistance` (20). Rotation waits. None of `tilesCovered`, a placement-check query, or `isPassable` exist in code yet.

Section 3 specifies the decree card (title, flavor, cost or Free, faction chips, plain-language effects, **Issue decree** / **Not now**) and the newspaper-style event feed (group by kind, district, and day; headline templates; a because-line from `CauseFactor`; names; **Show me**).

### Ownership (locked)

This split supersedes the shorter handoff line in the 11:17 AM Game Designer log and the one-line "Next" note inside [docs/DESIGN.md](docs/DESIGN.md). The design rules in that doc stay authoritative. Section 3's follow-ups sit with the same roles: Ios Dev builds the decree and event UI, Game Logic adds `flavor` on `DecreeSpec` and keeps a cause on every negative event.

- **Game Logic** owns the footprint core: sizes, `tilesCovered`, placement rules, entrance tile, district, building-at-tile lookup, placement-check query, and `isPassable`. Game Logic also owns the hunger fix and walker routing. **The core PR merges first.**
- **Ios Dev** owns the ghost preview, rendering, the inspect panel, and CI, built on Game Logic's core API. Ios Dev also owns the decree-card and event-feed UI from section 3.
- **Game Designer** owns [docs/DESIGN.md](docs/DESIGN.md).
- **Visual And Grapchics** owns sprites (sized from the design table) and the app icon.

### Parallel work not on this branch

PR #1 (`cursor/art-direction-and-icon-108e`) adds `docs/ART_DIRECTION.md`, a 1024×1024 app icon, and its own short `PROGRESS.md`. It is not contained here. Merging it will collide with this file.

## Owner playtest feedback (Oct 25, 2026)

Jordan tested on an iPhone. No art assets were in that build.

1. Walker dots go back and forth between spots.
2. Buildings should take up more space, with bigger footprints.
3. Research how building placement and assets work in Cities: Skylines and Tropico. That research is written up in [docs/DESIGN.md](docs/DESIGN.md).
4. Tapping a placed item should show details about it.

## Open items by role

### Ios Dev

Built on Game Logic's core API, after the core PR merges.

- Ghost preview: green or red, reason from `IntentRejection`, service reach for market, clinic, school, and police.
- Render footprints from the core sizes and `tilesCovered`, including the sprite base in [docs/DESIGN.md](docs/DESIGN.md). Move the island toward the Duo postures in that doc (unfolded map plus panel, folded bottom sheet, selection and camera kept).
- Inspect panel contents landed on `cursor/building-inspect-panel-ef49` (see the log). Still open: host that same view in the unfolded side pane and the folded bottom sheet, and the inspect wiggle / follow-a-resident moment.
- Decree cards and the newspaper event feed from section 3: title, flavor, cost or Free, faction chips, plain-language effects, **Issue decree** / **Not now**, and stories grouped by kind, district, and day with a because-line, names, and **Show me**.
- CI and device build: get `.github/workflows/unsigned-ipa.yml` green on `xcode-27`, update the README toolchain lines so they match the workflow, and replace bundle id `com.example.PocketRepublic` when signing needs a real id.

### Game Logic

The core PR merges first.

- Footprint core: sizes, `tilesCovered`, placement rules, entrance tile, district from the entrance, building-at-tile lookup, placement-check query, `isPassable` (entrance passable, the rest of the footprint not).
- Hunger fix for the surplus-and-hungry run above. Cause is market reach, stock at the market, and whether the citizen can pay, with spoilage on top.
- Walker routing that uses entrances and `isPassable`. Today's dots are the cosmetic shuttle described in Current state.
- Add a `flavor` string to `DecreeSpec`. Keep a `CauseFactor` on every negative event so the feed's because-line has something to read.

### Game Designer

[docs/DESIGN.md](docs/DESIGN.md) is on main (PR #2, `dd87c6e`), sections 1–3. Follow-up edits stay in that doc when a rule has to change. Implementation ownership lives in this file.

### Visual And Grapchics

- Building sprites sized from the footprint table in [docs/DESIGN.md](docs/DESIGN.md). The island still draws flat color blocks.
- App icon. The catalog on this branch has none. PR #1 has a 1024×1024 icon and `docs/ART_DIRECTION.md` in flight.

### Later / backlog

- Player-customizable iPhone Duo layouts (choose what each panel shows, for example map, inspect, agenda, or stats). Owner: Ios Dev. Deferred by Jordan until performance and game feel are optimized.

## Log

### 2026-10-25 11:33 AM EDT — Ios Dev — `cursor/building-inspect-panel-ef49`

- **Changed:** Tap-to-inspect. `BuildingInspectPanel` is a self-contained view in the island controls column (not a bottom sheet). Selection highlights every tile `buildingAt` assigns to the building. The model is `BuildingInspection`, ordered status, then staffing, then numbers, from fields the core already tracks. The only core command added is `PlayerIntent.setOperatingMode`, because nothing else could change `OperatingMode` after the placement commission. Footprints, hunger, and walker routing were not touched.
- **Verified:** `swift test` in `PocketRepublicCore` on Swift 6.2 (Linux, debug): 51 tests, 0 failures. No iOS SDK here, so the panel, highlight, and haptic were not run on a simulator or a phone. No screenshot.
- **Next:** Game Logic's footprint core still comes before ghost preview and footprint rendering. This panel already selects by occupancy, so multi-tile `buildingAt` entries should light up without a second picker. A later layout PR can host `BuildingInspectPanel` in the unfolded side pane and the folded bottom sheet.

### 2026-10-25 11:25 AM EDT — Docs agent — `cursor/progress-log-d016` (PR #3)

- **Changed:** Rebased onto main `dd87c6e` after PR #2 was squash-merged. Kept `docs/DESIGN.md` as it is on main, including section 3 (decree cards and the newspaper-style event feed). Folded both Game Designer log entries into this file, newest first. Pointed `AGENTS.md` at section 3.
- **Verified:** After the rebase, `docs/DESIGN.md` still has sections 1–3. The only conflict was `PROGRESS.md`. `DecreeSpec` has no `flavor` field; `EventKind` already lists the headline kinds in section 3. No Swift, project, or CI edits.
- **Next:** PR #3 should merge to main. Game Logic's footprint-core PR still merges before Ios Dev builds the ghost, renderer, inspect panel, and CI on that API. Section 3's UI is Ios Dev; the flavor string and negative-event causes are Game Logic.

### 2026-10-25 11:23 AM EDT — Game Designer — `design/footprints-and-game-feel` (PR #2, now `dd87c6e` on main)

- **Changed:** Added `docs/DESIGN.md` section 3: decree card layout (title, flavor, cost or Free, faction chips, plain-language effects, **Issue decree** / **Not now**) and a newspaper-style event feed (grouping by kind, district, and day, headline templates per `EventKind`, a because-line from `CauseFactor`, names, **Show me**).
- **Verified:** Docs only. No code changes.
- **Next (as written in that commit):** Ios Dev builds the UI. Game Logic adds a flavor string to `DecreeSpec` and ensures every negative event carries a cause.

### 2026-10-25 11:21 AM EDT — Docs agent — `cursor/progress-log-d016`

- **Changed:** Expanded this file into the handoff (North star, current state, playtest, open items, backlog) and locked the ownership split: Game Logic owns the footprint core, the hunger fix, and walker routing, and that core PR merges first; Ios Dev owns ghost preview, rendering, the inspect panel, and CI on that API. Added `AGENTS.md`. Marked `FINDINGS.md` historical. Kept the Game Designer entry below.
- **Verified:** Read the app, core, 41 test methods, workflow, asset catalog, README, and `docs/DESIGN.md` as it stood before section 3. Checked `runs-on: xcode-27` against the GitHub changelog (2026-10-15) and the `xcode-27` image readme (`20261023.0307.1`). Did not re-run `swift test` (no Swift toolchain here) and did not change Swift, the Xcode project, CI, or `docs/DESIGN.md`.
- **Next:** Game Logic opens the core PR first. Ios Dev's ghost, rendering, inspect panel, and CI build on that API. PR #1 also adds a `PROGRESS.md` and will conflict with this file until someone folds it in.

### 2026-10-25 11:17 AM EDT — Game Designer — `design/footprints-and-game-feel` (PR #2, now `dd87c6e` on main)

- **Changed:** Added `docs/DESIGN.md`: building footprints per type, placement rules (road-facing entrance tile, only the entrance passable), sprite sizing, inspect panel contents, and game-feel targets including the iPhone Duo layout.
- **Verified:** Docs only, on that branch. No code changes.
- **Next (as written in that commit):** Game Logic owns core footprint, placement, and `isPassable`; Ios Dev owns ghost preview, rendering, and the inspect panel; Visual And Grapchics sizes sprites from the table. The 11:21 AM entry above is the locked ownership for implementation, including the hunger fix, walker routing, the placement-check query, and CI.
