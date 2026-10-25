# PROGRESS.md

Living handoff for Pocket Republic. Read this file before changing anything. **Current state** is the tree on main today. Overwrite that section when the tree changes. The **Log** is history. It now includes every note from `docs/log/` through this handoff, newest first, and the entries that were already here. Those files stay on disk. A log note describes the branch at the time it was written, so an older note can disagree with **Current state**. **Current state** wins.

Later pull requests still write `docs/log/YYYY-MM-DD-<short-branch>.md` and do not add a heading to the **Log**. After this handoff, also read any `docs/log/` file newer than `docs/log/2026-10-25-handoff.md`. The **North star** is the bar every pull request is judged against.

## North star

Jordan wants Pocket Republic to feel like a lively, living world with a real game feel, not a spreadsheet sim. Every screen is optimized for the iPhone Duo folding display, both folded and unfolded.

[docs/DESIGN.md](docs/DESIGN.md) is the source of truth for footprint sizes, placement rules, inspect-panel contents, sprite sizing, the concrete game-feel targets (including the Duo postures: map and panel side by side when unfolded, a bottom sheet when folded), and section 3 (decree cards and the newspaper-style event feed). Sections 4–6 are the citizen-mind, random-event, and on-device model spec. What to build next, and who owns it, is **Next round** and **Team and process** below.

## Current state

Code snapshot: main `a93d04f` on 25 October 2026, after PR #22 added all eight foundation and scaffold imagesets from design section 7.6. This branch redraws the finished market, workshop and dock on true 3×2 or 2×3 diamonds. PR #10, the diorama HUD, decree cards, and the gazette, is still separate from this tree. The core construction state and SpriteKit stage rendering remain separate work.

`PocketRepublicCore` contains **71** `func test` methods. The latest main **Build iOS IPA** run, for `a93d04f` (PR #22), completed successfully ([run 40224664561](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/40224664561)). This confirms CI compilation and packaging, not an install or run on an iPhone. The local Linux VM has no `swift` or `xcodebuild`; `cd PocketRepublicCore && swift test` exits 127 there. The core README's release timings (about 0.52 ms/tick at 1000 citizens) were not re-measured.

The repo is a SwiftUI app plus a SpriteKit island. The simulation is the pure-Swift package `PocketRepublicCore` (tools version 6.0, deployment target iOS 17). The core sources import Foundation only. The app sends `PlayerIntent` values into `SimulationEngine` and draws a read-only `WorldSnapshot`. The clock advances only when **Advance One Day** is pressed. Animated walkers and the day/night wash do not write simulation state. Core rules for determinism, money, food, crises, tick order, balance data, and saves are in [AGENTS.md](AGENTS.md) and [PocketRepublicCore/README.md](PocketRepublicCore/README.md). Follow those. Do not re-derive them from this summary.

The core has agenda, decrees, and factions. `DecreeCatalogue` is data applied through `RepublicState.apply`. `DecreeSpec` has `name`, `cost`, `salience`, and `effect`. It has no flavor string. Factions are `labourers`, `merchants`, `officials`, and `landless`. Only a crisis or an election blocks the day advance. The standing agenda does not.

Four tabs: Island, People, Govern, and Events. Govern lists agenda items as option buttons and an income-tax stepper. The navigation title and a form section both say Government. People lists living citizens. Events lists the log newest first, with a prettified `EventKind` title and the first cause's detail. The cause's number is omitted. `EventKind` covers the headline kinds in design section 3, and each `GameEvent` can carry `CauseFactor`s, subjects, and a location. The decree cards and the newspaper feed from that section are the unfinished work in PR #10.

### Multi-tile footprints (PR #12)

Buildings occupy multi-tile footprints. The anchor is the minimum-x, minimum-y corner, and the footprint extends in +x and +y. Footprints do not rotate. Sizes match the design table: house and police 2×2, market and workshop 3×2, farm, clinic, school, and town hall 3×3, dock 2×3. `WorldMap.tilesCovered`, `buildingAt(_:)`, `isPassable`, and `isEntrance` are the lookups. Roads are passable, and so is each building's entrance. Every other footprint tile blocks movement. `SimulationEngine.validatePlacement` previews a site and does not change state. The entrance is the lowest tile index among perimeter tiles that orthogonally touch a road. The building's district is that entrance's district. Farms need at least half their tiles on fertile land. Docks need one full long side against water. Demolish clears every tile the building still occupies. `RepublicState.schemaVersion` is 2. A schema 1 save does not decode. The file is kept until the player chooses **Start New City**. World generation paints extra 4×4 fertile patches and parks the dock on the east shore.

A new city uses `WorldGenerator.generate`, whose default `size` is 64, so the island is 64×64. [docs/DESIGN.md](docs/DESIGN.md) section 1 says 96×96. Scale tests pass `size: 96` themselves. That gap is map tuning, listed in next round item 7.

### Hunger (PR #11 and PR #14)

The surplus-and-hungry failure is fixed. Farms used to ship a whole day's output to the single nearest market, that market paid for food it could not sell and went broke, and distance was measured on the floor tile instead of the door. `distributeFood` now shares the day's sales: one unit per farm per pass, shopper shortfall first (the food still moves when the till cannot prepay), then paid surplus to markets that can buy without spending wage money. Reach, feeding, coverage, faction tallies, and the no-market penalty all use the door.

On seed 2026, four households stay hungry because their doors are 21 road tiles from the nearest market, one past `maxServiceDistance` (20). Multi-tile footprints block every tile but the entrance, so that walk is one step longer than when a building was a single passable tile. `HungerTests.testSurplusDoesNotLeaveCitizensHungry` runs seeds 2026 and 11 for 120 days. From day 40 it requires nobody inside the cap to be hungry, and it locks those four as the only exception on seed 2026. Seed 11 must have zero. The city stays in surplus. Those four are tuning for the next round. They are not a return of the distribution bug.

### Tap-to-inspect (PR #7)

Tapping a placed building, with Inspect selected, selects the building that occupies that tile and opens `BuildingInspectPanel` in the island controls column. The panel sizes to its content and does not present itself as a sheet. Copy and field order live in `BuildingInspectCatalog`: status, then staffing, then numbers, then actions. Status priority is no road access, then understaffed, then no food, otherwise "Running well". Houses show residents out of capacity, with each living resident's job and hunger. Farms, workshops, and docks switch `OperatingMode` by sending `PlayerIntent.setOperatingMode`. Demolish asks for confirmation, then sends `PlayerIntent.demolish`. The Town Hall has no demolish button. Every occupied tile is highlighted. A selection haptic fires with the selection. Empty ground or Close clears it. Road and building tools still place on tap. A drag pans, and a pinch zooms. A tap on empty ground still shows the tile caption. The unfolded side pane, the folded bottom sheet, the sprite wiggle, and follow-a-resident are not built.

### Placement ghost and sprite rendering (PR #9, art from PR #4)

`CityFootprints.current` is `CoreFootprintModel`. It reads `BuildingKind.footprint`, `tilesCovered`, `buildingAt`, `isEntrance`, and `validatePlacement`. Each building is a sprite anchored at `(0.5, 0)` on the south corner of the tiles it covers. Node size comes from `BuildingSpriteCatalog`, which copies `docs/art/sprites.json`: a house is 128×125, a town hall is 192×222, and every width is (W+H)×32. The image name is `building_<kind>`. Nine imagesets live in `PocketRepublic/Assets.xcassets/Buildings/`. A missing image would draw a placeholder of the same point size. The images are in the catalog, so the island loads them. Market and workshop now use 3×2 diamonds with their long axis on +x; dock uses a separately drawn 2×3 diamond with its long axis on +y. Their canvas sizes and asset names are unchanged. While a building tool is selected, a ghost of that sprite follows the tile under the finger, tinted green when `validatePlacement` accepts the site and red when it rejects it. The `IntentRejection` sentence shows on the map and in the control pane. Market, clinic, school, and police also draw the tiles within `maxServiceDistance` (20) on the passable network, measured from the entrance `validatePlacement` returns. A rejected placement has no entrance, so it draws no reach. A light impact haptic fires when a building lands, and the ghost hides so the new sprite is not covered by an occupied tint.

`BuildingArtwork.swift` still comments that `docs/art/sprites.json` is not on main. The file is on main.

### Walker routines (PR #15, the re-land of PR #13)

`WalkerRoutine.plan` builds a deterministic day. Hours are 0..<24, and a dwell's end hour is exclusive, so the gap before the next dwell is the walk. An employed citizen with a market in range is home from hour 0 until hour 7, at work from hour 8 until hour 15, at the market `shoppingMarket` already uses from hour 16 until hour 18, and home again from hour 20. Someone without a job skips work and shops earlier. A door past `maxServiceDistance` gets no market stop. Hours 0..<24 pick a tile on that walk. Destinations are entrance tiles from `BuildingAccess`. `MapBuildingAccess` records `Building.tile` (the entrance) and forwards `WorldMap.isPassable` and `building(at:)`. `Pathfinder` is a deterministic BFS on that access. The plan is a pure function, so the save and the state hash do not store it. `WalkerRoutineTests` covers the hour schedule, unemployed citizens, a door out of range, entrance tiles from the access interface, and a path around a blocked 3×3 footprint.

`IslandScene` now calls `WalkerRoutine.plan` for each living citizen and caches the `DailyRoutine`, clearing that cache after a simulated day or road/building occupancy change. It draws citizens whose routine path or entrances cross the viewport; the old 24-employed-citizen cap and drifting yellow road dots are gone. The scene plays the 24-hour plan as a repeating 48-second visual day (two seconds per hour), interpolating along `legPaths` between dwell hours while the simulation waits for **Advance One Day**. A stable offset derived from each citizen ID staggers pose changes and walk frames across up to 1.5 seconds, so visible walkers no longer move in lockstep. It uses 12×18 `walker_<0-5>_{ne|sw}_f0/f1` sprites with nearest filtering, a moving frame only while walking, and an orange tint for hungry citizens. Missing walker art falls back to a white dot. This is code and CI build verification; no iPhone animation or frame-rate check was done.

### CI, bundle id, and art

PR #5 is the workflow named **Build iOS IPA** (`.github/workflows/unsigned-ipa.yml`). It runs on the hosted `xcode-27` runner with `DEVELOPER_DIR` set to Xcode 27.1, on every push, including each merge to main, and on fork pull requests. The job runs `swift test --package-path PocketRepublicCore`, then builds an unsigned `iphoneos` app. The test-build artifact is `PocketRepublic-unsigned-ipa`. The bundle id is `com.jscreate.pocketrepublic`, defined only in `Config/PocketRepublic.xcconfig`. Debug and Release both include that file. Optional signing secrets can also upload `PocketRepublic-signed-ipa`. They are not required for a sideload build. The main run for `a93d04f` completed successfully. An iPhone install or run was not verified on this art branch. The Xcode project still records `CreatedOnToolsVersion = 15.0` and `LastUpgradeCheck = 1500`. The deployment target is iOS 17.0, and `TARGETED_DEVICE_FAMILY` is 1 (iPhone only).

PR #1 added [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md) and the 1024×1024 app icon (`AppIcon`, 8-bit RGB, no alpha), selected with `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`. PR #4 added the nine building sprites and `docs/art/sprites.json`; this branch replaces the market, workshop, and dock images in place to correct their base geometry. PR #6 added batch 2 under `PocketRepublic/Assets.xcassets/`: 31 terrain imagesets, 16 road overlays, 14 decorations, 26 walker and cart imagesets, and 7 UI icons (94 imagesets), plus `docs/art/ASSETS.md`, `UI_STYLE.md`, `road_autotile.json`, and `decos.json`. PR #17 connected the ground and walker art to `IslandScene`: terrain variants use a stable coordinate hash; 16 road overlays use the N/E/S/W neighbour mask; shore overlays face adjacent land; and sparse decorations are selected on empty sand, grass, fertile, or rock. Ground and road sprites are 64×32. Missing terrain or road art falls back to a procedural tile; decorations with missing art are skipped. The water animation and palm sway are not played. Cart images and batch 2 UI icons are not referenced by the app's Swift sources.

### Duo layout and saves

`CityDisplayLayout` uses iOS 27.1 `reservedRegions` for a vertical book fold (controls on the trailing pane) and a horizontal laptop fold (controls in the lower pane), plus portrait, landscape, and wide flat rails. On a tall closed portrait window, the control rail now leaves its unused middle transparent, the navigation title is inline, and Cash and Next Day fit the narrow width. Compact-height windows still scroll the rail. Pre-27.1 devices skip the reserved-region branches. The design's stronger split, unfolded map on one pane and the panel on the other, folded bottom sheet, camera and selection kept across the fold, is what PR #10 started. It is not on main. A player-facing layout picker is deferred until game feel is optimized.

A valid city is `Application Support/PocketRepublic/spatial-v1.json` (envelope `formatVersion` 1, checksum `stateHash()`, `RepublicState.schemaVersion` 2), written atomically. A corrupt or unsupported file is kept and blocks play until **Start New City**. The app reads the `UserDefaults` key `pocket.republic.save.v1` only to detect the old prototype. It never decodes or migrates it. A new city draws `worldSeed` once with `UInt64.random` at the app boundary (`Game.freshState`). After that, `worldSeed` and `rng` live in the saved state.

### Construction stages (spec and site art)

[docs/DESIGN.md](docs/DESIGN.md) section 7 is the construction-stage spec for next round item 1. Three stages: `foundation`, `scaffold`, `complete`. Build time is 2 days for a house, 3 for police, market, workshop and farm, 4 for clinic, school and dock, and 0 for the town hall, all in `BalanceConfig.constructionDaysByKind` with a `constructionDaysMultiplierPercent` (0 reproduces today's instant build) and a `constructionFoundationPercent` split. The core stores two `Int32`s per building, days done and days required, and derives stage and a 0-to-1 progress; no `Double` and no dictionary enters the save. A site claims its tiles at placement, is charged its full build cost there, and until it opens has no workers, residents, production, food, upkeep, wages or service reach. `advanceConstruction` is a new step at the top of `advance`, before the `fields.dirty` check, so a building that completes on day N is a service source that same day. `buildingConstructed` moves to completion day and a new `EventKind.buildingSiteStarted` fires at placement. `RepublicState.schemaVersion` goes 2 to 3, so a schema 2 save does not decode. Section 7.6 specifies 8 new imagesets, foundation and scaffold for each of the four footprint shapes, at the same `(W+H)×32` width and `(0.5, 0)` anchor as the finished sprites, with 3×2 and 2×3 drawn separately. PR #22 added the eight site imagesets under `Buildings/`. The core stage state and SpriteKit stage rendering are not yet in this branch.

### Spec that is not built

[docs/DESIGN.md](docs/DESIGN.md) sections 4, 5, and 6 are spec only. There is no `CitizenMind` or `Narrator` type in the core. Section 4 is citizen needs, traits, opinion of El Presidente, gossip, and choices with visible causes, plus the seeded-roll contract. Section 5 is a 14-event random deck and rare one-off events. Section 6 is the small on-device model: it may pick among options the core has already validated and write flavor text, the answer used is written into the save, and the rule-based mind is the fallback. The minimum target stays iOS 17.

## Owner playtest feedback (Oct 25, 2026)

Jordan tested on an iPhone. No art assets were in that build.

1. Walker dots go back and forth between spots.
2. Buildings should take up more space, with bigger footprints.
3. Research how building placement and assets work in Cities: Skylines and Tropico. That research is written up in [docs/DESIGN.md](docs/DESIGN.md).
4. Tapping a placed item should show details about it.

Footprints and tap-to-inspect are on main. PR #17 replaced the shuttling dots with daily-routine walker sprites and drew the batch 2 ground art; the result has not been checked on an iPhone. The reference-game research is the design doc, including the Tropico work-mode idea that `OperatingMode` already follows. Construction that rises in stages, the next feel target, is next round item 1.

## Known issues

- **Four households sit one tile past market range.** Seed 2026, 250 citizens: from day 40, four doors are 21 road tiles from the nearest market. `maxServiceDistance` is 20. Everyone inside the cap is fed, and the city has a food surplus. Seed 11 has nobody past the cap. Next round item 7 is the tuning pass.
- **Batch 2 presentation is partial.** `IslandScene` draws the terrain, roads, decorations, and walker sprites. Water animation and palm sway are static, and the batch 2 UI icons and cart images are not referenced by the app's Swift sources. The UI style sheet is not applied to the tabs. Market, workshop, and dock sprites sit on square bases.
- **Walker motion has no device playtest.** `IslandScene` reads `WalkerRoutine.plan` and animates its home/work/market/home route, but smoothness, pacing, and camera performance have not been verified on an iPhone.
- **Decrees and events still read as rows.** Agenda options show the label. The event list can repeat the same kind on separate rows and drops `CauseFactor.value`. `DecreeSpec` has no `flavor` field. Some negative events can still omit a cause. PR #10 is the unfinished presentation, and it is parked.
- **Inspect lives in the controls column.** The unfolded side pane, the folded bottom sheet, the sprite wiggle, and follow-a-resident are not built. The panel view itself can move without a rewrite.
- **Two save leftovers.** `pocket.republic.save.v1` is detected and never migrated. A spatial file from schema 1 does not decode under schema 2, and the app keeps that file until **Start New City**.
- **A new city is 64×64.** The design doc says 96×96. See next round item 7.

## Open items

Finished, and not open: multi-tile footprints (PR #12), the surplus hunger fix (PR #11 and PR #14), tap-to-inspect (PR #7), the placement ghost and building-sprite rendering (PR #9 and PR #4), walker routines in the core (PR #15), walker and ground rendering (PR #17), the Xcode 27.1 unsigned IPA and bundle id `com.jscreate.pocketrepublic` (PR #5), the nine building imagesets (PR #4), and the batch 2 catalog (PR #6). The ordered work is **Next round**. The role notes here match that list.

### Game Designer

The construction-stage spec and timings (next round 1) are written: [docs/DESIGN.md](docs/DESIGN.md) section 7, with the core fields and tick-order change in 7.10, the art list in 7.6, the stage rendering and pop in 7.7, and the test expectations in 7.12. Game Logic, Visual And Grapchics and Ios Dev can start from that. [docs/DESIGN.md](docs/DESIGN.md) stays the source of truth, including sections 4–6 when their turn arrives.

### Game Logic

Construction-stage state (next round 1). A `flavor` string on `DecreeSpec`, and a cause on every negative event (next round 3). Citizen minds and the random event deck (next round 4). The on-device model hook on the core side (next round 5). Market range and map tuning, including the four seed-2026 doors and the 64 versus 96 map (next round 7).

### Visual And Grapchics

Foundation and scaffold sprites for each footprint size, same (W+H)×32 width and anchor (next round 1). The 3×2 and 2×3 building sprites are still on square bases. That redraw waits behind the construction art.

### Ios Dev

Stage rendering and the finished pop, after the spec and the core state exist (next round 1). PR #10, parked (next round 2). Finish the ambient presentation pass with an iPhone playtest of the PR #17 walkers and ground, plus the inspect wiggle and follow-a-resident (next round 6). Custom Duo layouts stay deferred (next round 8).

## Next round (priority order)

1. **Tropico-style construction stages.** A placed building rises in real time through foundation, then scaffold with builders, then the finished building with a pop. It does not function while it is under construction. The core stores whole days done and days needed for each stage, and it exposes progress as a number from 0 to 1. Game Designer has written the spec and the timings ([docs/DESIGN.md](docs/DESIGN.md) section 7). Game Logic owns the core state. Visual And Grapchics draws the foundation and scaffold sprites for each footprint size, using the same (W+H)×32 width and the same anchor as the finished sprite. Ios Dev renders the stages and the pop.

2. **PR #10, the diorama HUD, decree cards, and the gazette.** That pull request is unfinished and parked. It is the presentation pass for design section 3: the map-forward Duo layout, decree cards, and the newspaper-style event feed. Leave it parked until the lead picks it up. Do not rebase it onto a side branch.

3. **Decree flavor text, and causes on negative events.** `DecreeSpec` needs a `flavor` string so a card can say what the decree means in the world. Every negative event needs a `CauseFactor` so the feed's because-line has something to read. Game Logic owns both. The card and newspaper UI stay with Ios Dev, inside the parked PR #10 work.

4. **Citizen minds and the random event deck.** [docs/DESIGN.md](docs/DESIGN.md) sections 4 and 5. Needs, traits, opinion, gossip, and choices with visible causes, then the 14-event deck with its triggers, choices, headlines, pacing, and repeat rules. New core fields are flagged in sections 4.6 and 5.5. Rolls stay on seeded streams, one game seed, then a stream per system.

5. **The small on-device LLM hook.** Section 6. The model picks among options the core has already validated, and it writes flavor text. It does not change state, invent options, or change numbers. The core logs the output it used in the save, so a replay reads the log and does not call the model again. A rule-based mind is the fallback when the model is missing, late, or refused. The minimum target stays iOS 17. The model path, when it exists, sits behind iOS 26 availability. Version 1 can ship with only the rule-based implementation.

6. **Finish and playtest ambient life; add the inspect wiggle and follow-a-resident.** PR #17 made the island sample `DailyRoutine` and draw batch 2 terrain, roads, decorations, and walker sprites. Check the motion, pacing, and rendering on an iPhone. Inspecting should wiggle the selected sprite, and tapping a resident should follow them for a moment. The batch 2 UI style, carts, water animation, and palm sway remain unwired. This work stays behind item 1.

7. **Market range and map tuning.** The four seed-2026 households whose doors are 21 tiles from a market, one past the 20-tile cap, are the known remainder. A new city is 64×64, and the design doc says 96×96. Change the cap, the generated roads, or the map size on purpose, and re-read `HungerTests` and the economy dashboard after the change.

8. **Custom iPhone Duo layouts.** Let the player choose what each panel shows, for example map, inspect, agenda, or stats. Owner: Ios Dev. Deferred until game feel is optimized.

## Team and process

**Project Lead** coordinates and merges. **Game Logic** owns the core simulation in `PocketRepublicCore`. **Ios Dev** owns the UI, rendering, and CI. **Visual And Grapchics** owns art. **Game Designer** owns [docs/DESIGN.md](docs/DESIGN.md). One pull request stays inside one role. The core stays free of SwiftUI, SpriteKit, and UIKit.

Merge one pull request at a time, and wait for main's **Build iOS IPA** run to go green before merging the next. Stack pull requests only on main. PR #13 was stacked on the hunger-fix branch, that branch was squash-merged without the walker commits, and the work had to be re-landed as PR #15.

Each pull request writes its note in `docs/log/YYYY-MM-DD-<short-branch>.md` and does not edit the **Log** in this file. It does overwrite **Current state** so the snapshot matches the tree. Leave [FINDINGS.md](FINDINGS.md) as history.

New objects in `project.pbxproj` use a random 24-character hex id. The file still contains an older block of sequential placeholder ids. Leave those in place, and do not copy them for a new file.

Test builds are unsigned IPAs. Download the `PocketRepublic-unsigned-ipa` artifact from the **Build iOS IPA** workflow. Signing secrets are optional and are not required for a sideload build.

Keep cloud agents lean and one-pass. An agent does its one change, opens the pull request, and stops. It does not watch CI. Reserve further usage for the lead's merge and for the unsigned IPA.

## Log

Folded from `docs/log/` on 25 October 2026, newest landed work first. The notes below the 11:36 AM entry were already in this file and are unchanged. Where a note describes a branch that later moved, **Current state** is the tree on main.

### 2026-10-25 1:25 PM EDT — Visual And Grapchics — `cursor/terrain-roads-walkers-ui-5b58` (PR #6)

Source: `docs/log/2026-10-25-terrain-roads-walkers-ui.md`, stamped 11:34 AM EDT on the branch. Landed as `46abf5e`, the tip of main. The note was written before the footprint, sprite, and walker commits were on that branch, so its "UIColor building blocks" line is the branch at writing time. On main today the island draws building sprites. See **Current state**.

- **Changed:** Added 94 imagesets under `PocketRepublic/Assets.xcassets/` in `Terrain/` (31), `Roads/` (16), `Decorations/` (14), `Walkers/` (26), and `UI/` (7). Each folder sets `provides-namespace` to false, so the names stay `tile_*`, `road_*`, `deco_*`, `walker_*`, `cart_0_*`, and `icon_*`. Docs are in `docs/art/`: `ASSETS.md`, `UI_STYLE.md`, `road_autotile.json`, `decos.json`, `terrain_preview.png`, `ui_style_sheet.png`, and `ui_style_sheet.html`. Generator scripts are in `tools/art/`. The branch was cut from `b960f52` and then merged `origin/main` at `3b88a5c` (PR #1). No Swift edits. `docs/ART_DIRECTION.md` stayed as PR #1 left it.
- **Verified:** Every imageset PNG is 8-bit RGBA with an alpha channel. Terrain diamonds are opaque inside the tile and transparent in the corners. Every `Contents.json` parses. Tile and road sprites are 64×32 at 1x. The batch is about 2.7 MB. The largest file is `docs/art/terrain_preview.png` at about 1.1 MB. The road bitmask in `docs/art/ASSETS.md` matches `IslandScene.point(x:y:)`: N=1 is `(x, y−1)` up-right, E=2 is `(x+1, y)` down-right, S=4 is `(x, y+1)` down-left, W=8 is `(x−1, y)` up-left. Road assets were not renamed. No Swift toolchain, Xcode, or iPhone, so `swift test`, `actool`, and the device build were not run.
- **Next (as written then):** Ios Dev wires the art. Pick terrain variants by a deterministic hash of the tile index, draw roads as overlays chosen by the bitmask, use nearest filtering for walkers, flip the other two directions with `xScale = -1`, keep the hungry orange tint, and follow `docs/art/UI_STYLE.md` for the HUD pill, decree cards, the Gazette, citizen rows, and the inspect panel. Known gaps called out in the note: no blending between terrain types, faint roads on sand, mockup fonts substituted for SF Pro Rounded, and the 3×2 and 2×3 building sprites still on square bases (that art is PR #4).

### 2026-10-25 1:09 PM EDT — Game Logic — `cursor/walker-routines-main-68a0` (PR #15)

Source: `docs/log/2026-10-25-walker-routines-main-68a0.md`. Re-land of PR #13 onto main.

- **Changed:** PR #13 never reached main. It was merged into the hunger branch after that branch had already been squash-merged, so `origin/main` never received the walker files. This branch copies only what `1d32878` added on top of its parent `3fdab91`: `WalkerRouting.swift`, `WalkerRoutineTests.swift`, and the original walker log. The hunger diff is not reapplied. The branch is based on `b032bb2` (PR #9), which already includes multi-tile footprints and the round-robin food shipments from PR #14. `Building.tile` is the entrance. `MapBuildingAccess` records that door and forwards `WorldMap.isPassable` and `building(at:)`. The island scene from PR #9 still draws the home–work shuttle, and that shuttle already walks passable tiles between entrance tiles, so the sprite and ghost rendering was left as PR #9 wrote it. Food distribution is untouched.
- **Verified:** `swift test` in `PocketRepublicCore` (Swift 6.2, Linux): 71 tests, 0 failures. No iPhone run. `PROGRESS.md` was not edited on that branch.
- **Next:** The scene should sample `DailyRoutine`. That is next round item 6.

### 2026-10-25 12:41 PM EDT — Ios Dev — `cursor/footprint-ghost-render-6511` (PR #9)

Source: `docs/log/2026-10-25-footprint-ghost-render-6511.md`, stamped 11:40 AM EDT. The file still describes `LegacyOneTileFootprintModel` and one building id per tile. That was the branch before it was brought onto the footprint core. The merged pull request, and the tree on main, use `CoreFootprintModel`. See **Current state**.

- **Changed:** Presentation only. Buildings draw as sprites anchored at `(0.5, 0)` on the south corner, sized from the `docs/art/sprites.json` table (house 128×125, town hall 192×222, widths (W+H)×32). The image name is `building_<kind>`, with a same-size placeholder when the imageset is absent. While a building tool is selected, a green or red ghost follows the finger. The `IntentRejection` sentence shows on the map and in the control pane. Market, clinic, school, and police draw tiles within `maxServiceDistance` (20). A light haptic fires when a building lands, and the ghost hides. The branch merged main through `f48dc67` (art direction, then design sections 4–6). Those sections were not implemented. `PROGRESS.md` was not edited.
- **Verified:** `PocketRepublicCore` was not modified on the early branch. No Swift toolchain and no iPhone, so `swift test` and the device build were not run there. Main was later merged with merge commit `4d24aff` (through `4a7bd36`).
- **Next (as written then):** Point `CityFootprints.current` at the core API. That swap is what landed. The 3×2 and 2×3 sprites in `sprites.json` are 160 pt wide. The art-direction line that says canvas width is footprint width in tiles × 64 matches (W+H)×32 for squares only.

### 2026-10-25 12:35 PM EDT — Game Logic — `cursor/footprint-hunger-range-68a0` (PR #14)

Source: `docs/log/2026-10-25-footprint-hunger-range-68a0.md`.

- **Changed:** `HungerTests.testSurplusDoesNotLeaveCitizensHungry` failed on main at `4a7bd36` (footprints plus the first hunger fix). Seed 2026 left 22 of 250 hungry. Seed 11 left 16. Food was in surplus. Multi-tile farms shipped a full crew's yield, and `distributeFood` finished one farm, including surplus, before it offered the next farm a sale. The lowest-index farms sold the whole daily budget. Around the twelfth farm every market till was down to the wage reserve, so later farms never sold a unit. Their crews were not paid and could not buy food that was already on the shelf. Farms now take turns: one unit per farm per pass, shortfall first even when the till cannot prepay, then paid surplus. Wage cash stays reserved. A market's door is still its entrance. Seed 2026 still has four households whose door is 21 road tiles from the nearest market. `maxServiceDistance` is 20. Those four are outside the cap on purpose. The test requires nobody inside the cap to be hungry, locks those four as the only exception, and still requires zero on seed 11.
- **Verified:** `swift test` in `PocketRepublicCore` (Swift 6.2, Linux): 66 tests, 0 failures. No iPhone run. `PROGRESS.md` was not edited.
- **Next:** The four households are next round item 7.

### 2026-10-25 11:58 AM EDT — Game Logic — `cursor/walker-daily-routines-68a0` (PR #13)

Source: `docs/log/2026-10-25-walker-daily-routines-68a0.md`. This pull request merged into `cursor/hunger-surplus-fix-68a0`, not into main. PR #15 is the copy that landed. The note below is the original branch, including lines that were only true before footprints (it says today's entrance is the building's single tile).

- **Changed:** `WalkerRoutine.plan` builds a day from needs and the clock: home in the morning, work through the middle of the day when the citizen has a job, the market `shoppingMarket` names, then home at night. Hours 0..<24 pick a tile on that walk. Destinations come from `BuildingAccess`. `MapBuildingAccess.isPassable` forwards `WorldMap.isPassable`. `Pathfinder` is a deterministic BFS. The island scene on that branch still animated the home–work shuttle.
- **Verified:** `WalkerRoutineTests` covers the hour schedule, unemployed citizens, no market stop when the door is out of range, entrance tiles from the access interface, and a path around a blocked 3×3 footprint. `swift test` on Swift 6.2 Linux, after merging the main of that day: 57 tests, 0 failures. No iPhone run. `PROGRESS.md` was not edited.
- **Next (as written then):** The footprint core should supply the real entrance. The scene should draw `DailyRoutine`. The parent branch was the hunger fix.

### 2026-10-25 11:58 AM EDT — Game Logic — `cursor/hunger-surplus-fix-68a0` (PR #11)

Source: `docs/log/2026-10-25-hunger-surplus-fix-68a0.md`.

- **Changed:** A 120-day unattended city (seed 2026, 250 citizens) left about 47 people hungry while farms produced roughly 372 food a day against 250 needed, and markets held thousands of units. Three mechanisms stacked. Farms shipped their whole output to the single nearest market, so that market hoarded food and others sold out. The oversupplied market paid up front for every unit, including food nobody bought, the till ran dry, and shopkeepers and then farmers went unpaid (about 19 employed people with no coins in front of full shelves). Ten houses sat at road distance 21 because the check used the floor tile, one step inside the door, against `maxServiceDistance` 20. `distributeFood` now fills each market up to a day's demand for the people who shop there, even when the till cannot prepay. Leftover production is sold only to markets that can pay without spending wage money. Reach is measured at the door. Seed 555 no longer raises a crisis once this hunger is gone, so `testCrisisResolutionsDoNotMintMoney` follows seed 314, which still raises district uprisings.
- **Verified:** `swift test` in `PocketRepublicCore` (Swift 6.2, Linux): 42 tests, 0 failures, on that branch before footprints. `HungerTests` then required zero hunger from day 40 on for seeds 2026 and 11. PR #14 is the later adjustment: four seed-2026 households past the cap, after footprints lengthened the walk. No iPhone run. `PROGRESS.md` was not edited.
- **Next (as written then):** Walker routines were a separate branch. The footprint core was a different pull request and was meant to merge before the renderer followed the routes.

### 2026-10-25 11:58 AM EDT — Game Logic — `cursor/building-footprints-671d` (PR #12)

Source: `docs/log/2026-10-25-building-footprints-671d.md`.

- **Changed:** Multi-tile footprints in `PocketRepublicCore`. Sizes match `docs/DESIGN.md`. The anchor is the minimum-x, minimum-y corner. There is no rotation. Placement, demolition, snapshots, and saves use the footprint. `isPassable` is true for roads and for each building's entrance only. World generation paints extra fertile 4×4 patches so a farm can meet the half-fertile rule, and parks the dock on the east shore. `RepublicState.schemaVersion` is 2. `BuildingOccupancy.occupant` calls `WorldMap.buildingAt(_:)`.
- **Verified:** `swift test` in `PocketRepublicCore` on Swift 6.2 (Linux, debug): 65 tests, 0 failures, after merging main `e2aa20c`. One inspect fixture needed the entrance tile marked passable. That test was re-run green. No Xcode project edits on that pull request.
- **Next (as written then):** Ios Dev can call `validatePlacement` for the ghost and `buildingAt(_:)` for which building covers a tile. That is what PR #9 does on main. Hunger and walker routing were still open when this note was written. Both have since landed (PR #14 and PR #15), with the four-household remainder called out above.

### 2026-10-25 11:39 AM EDT — Game Designer — `design/citizen-minds-and-events` (PR #8)

Source: `docs/log/2026-10-25-design-citizen-minds-and-events.md`. Merged as `f48dc67`.

- **Changed:** Added `docs/DESIGN.md` sections 4 (citizen needs, traits, opinion of El Presidente, gossip, and choices with visible causes) and 5 (a 14-event random deck with triggers, choices, headlines, pacing, and repeat rules). Also added the seeded-roll determinism contract (4.7), a visual cue per citizen choice (4.8), section 6 (the LLM hook: `CitizenMind` and `Narrator`, rule-based v1, ask-ahead so a tick never blocks, a decision log in the save, Foundation Models behind iOS 26 availability with the iOS 17 minimum), the "no two games play the same" principle with per-system seeded streams, and section 5.6 rare one-off events. `PROGRESS.md` was left unchanged on that pull request.
- **Verified:** Spec only. No code changes. New core fields are flagged in 4.6 and 5.5.
- **Next:** Sections 4–6 are next round items 4 and 5. They are not implemented on main.

### 2026-10-25 11:38 AM EDT — Ios Dev — `cursor/ci-ipa-bundle-id-71ac` (PR #5)

Source: `docs/log/2026-10-25-ci-ipa-bundle-id.md`. The 11:34 AM and 11:28 AM notes for the same pull request are further down this log.

- **Changed:** Merged `origin/main` (`3b88a5c`, PR #1) with a merge commit. Kept art direction v1, `AppIcon.appiconset`, and `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` together with the bundle id in `Config/PocketRepublic.xcconfig` (`com.jscreate.pocketrepublic` on Debug and Release, no inline `PRODUCT_BUNDLE_IDENTIFIER`). Left the existing log entries in place. `AGENTS.md` and the preamble of this file then said future notes go in `docs/log/`.
- **Verified:** No conflict markers. The app icon and `docs/ART_DIRECTION.md` are in the tree. Prior push run [40207372598](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/40207372598) uploaded `PocketRepublic-unsigned-ipa` with `CFBundleIdentifier` `com.jscreate.pocketrepublic`. No local Swift toolchain and no iPhone on that pass.
- **Next (as written then):** Optional signing still needs `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISIONING_PROFILE_BASE64`, and `APPLE_TEAM_ID` only if a signed IPA is wanted. The footprint-core pull request this note was waiting on has since merged.

### 2026-10-25 11:36 AM EDT — Visual And Grapchics — `cursor/building-sprites-v1-5b58` (PR #4)

- **Changed:** Merged `origin/main` at `3b88a5c` (PR #1) with a merge commit. Kept every log entry from both sides, newest first, without duplicating the shared older entries. Moved the Building sprites section from `docs/art/SPRITES.md` into [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md) and deleted `docs/art/SPRITES.md`. The art-direction status line now says v1 sprites are in. Current state matches this tree: icon and art direction from main, plus the nine building imagesets. No Swift edits.
- **Verified:** `docs/ART_DIRECTION.md` still has main's feel, style, palette, building language, citizens, UI, and app-icon sections. The only status-line edit is that v1 sprites are in. No remaining references to `docs/art/SPRITES.md` outside this log. No Swift toolchain, Xcode, or iPhone here, so `swift test`, `actool`, and the device build were not run.
- **Next:** Ios Dev loads `SKTexture(imageNamed: "building_\(kind)")`, sets `anchorPoint` to `(0.5, 0)`, sizes from `docs/art/sprites.json`, and positions the sprite at the footprint's front (south) corner, after Game Logic's footprint-core PR. A v2 pass redraws the 3×2 and 2×3 sprites. PR #6 stays a separate art batch.

### 2026-10-25 11:34 AM EDT — Ios Dev — `cursor/ci-ipa-bundle-id-71ac` (PR #5)

- **Changed:** No product code. Recorded the post-merge CI result in this log.
- **Verified:** Push run [40207372598](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/40207372598) on `21da51c` succeeded on `xcode-27` with Xcode 27.1 (`27A9275`). It uploaded `PocketRepublic-unsigned-ipa` (415,372 bytes). The IPA's `CFBundleIdentifier` is `com.jscreate.pocketrepublic`, `DTSDKName` is `iphoneos27.1`, and the minimum OS is 17.0. The signed upload was skipped because the four optional signing secrets are unset. That unsigned file is the sideload test build.
- **Next:** Optional signing still needs `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISIONING_PROFILE_BASE64`, and `APPLE_TEAM_ID` only if a signed IPA is wanted. Game Logic's footprint-core PR still merges before ghost preview, footprint rendering, and the inspect panel.

### 2026-10-25 11:33 AM EDT — Ios Dev — `cursor/building-inspect-panel-ef49` (PR #7)

- **Changed:** Tap-to-inspect. `BuildingInspectPanel` is a self-contained view in the island controls column (not a bottom sheet). Selection highlights every tile the occupancy map assigns to the building. The model is `BuildingInspection`, ordered status, then staffing, then numbers, from fields the core already tracks. The only core command added is `PlayerIntent.setOperatingMode`, because nothing else could change `OperatingMode` after the placement commission. Footprints, hunger, and walker routing were not touched.
- **Verified:** `swift test` in `PocketRepublicCore` on Swift 6.2 (Linux, debug): 51 tests, 0 failures. No iOS SDK here, so the panel, highlight, and haptic were not run on a simulator or a phone. No screenshot.
- **Next:** Game Logic's footprint core still comes before ghost preview and footprint rendering. Occupancy reads go through `BuildingOccupancy`, so their `buildingAt` can replace the array in that one type. A later layout PR can host `BuildingInspectPanel` in the unfolded side pane and the folded bottom sheet.

### 2026-10-25 11:29 AM EDT — Visual And Grapchics — `cursor/building-sprites-v1-5b58` (PR #4)

- **Changed:** Merged `origin/main` at `b960f52` (PRs #2 and #3) with a merge commit. Kept this file from main and added this entry. Added nine building imagesets under `PocketRepublic/Assets.xcassets/Buildings/` (`provides-namespace` false; names `building_townHall`, `building_house`, `building_farm`, `building_market`, `building_clinic`, `building_school`, `building_police`, `building_workshop`, `building_dock`), plus `docs/art/sprites.json`. The Building sprites section stays in `docs/art/SPRITES.md` because `docs/ART_DIRECTION.md` is still only on open PR #1. No change to `IslandScene.swift` or the simulation.
- **Verified:** Every PNG is 8-bit RGBA with transparent pixels, and every `Contents.json` is valid JSON. Each 1x width is (W+H)×32 and matches `sprites.json`. Clinic, dock, market, and school @2x/@3x heights are one pixel off the 1x height; widths are exact. No Swift toolchain or iPhone here, so `swift test` and the device build were not run. This pull request does not change Swift.
- **Next:** Game Logic's footprint-core PR still merges first. Ios Dev then loads `SKTexture(imageNamed: "building_\(kind)")`, sets `anchorPoint` to `(0.5, 0)`, sizes from `docs/art/sprites.json`, and positions the sprite at the footprint's front (south) corner. A v2 pass redraws the 3×2 and 2×3 sprites, which sit on square bases. PR #1 still needs its `PROGRESS.md` folded in when it merges.

### 2026-10-25 11:28 AM EDT — Visual And Grapchics — `cursor/art-direction-and-icon-108e` (PR #1)

- **Changed:** Merged `origin/main` (`b960f52`) with a merge commit. Kept this file from main, refreshed Current state for the art that is now in the tree, and added this entry. `docs/ART_DIRECTION.md` is art direction v1. Added `PocketRepublic/Assets.xcassets/AppIcon.appiconset` (Xcode 14+ single-size 1024×1024 universal iOS icon) and set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` on the app target Debug and Release configurations. The asset catalog was already in the target resources. The short `PROGRESS.md` from this branch is not kept.
- **Verified:** `AppIcon-1024.png` is 1024×1024, 8-bit RGB (color type 2), with no alpha and no `tRNS` chunk. `Contents.json` parses. No simulation, gameplay, bundle ID, or CI edits. No Xcode or `actool` here, so the catalog was not compiled. No Swift toolchain, so `swift test` was not run.
- **Next:** Building sprites are Visual And Grapchics' remaining art work, sized from the footprint table in `docs/DESIGN.md` and the style in `docs/ART_DIRECTION.md`. The island still draws flat color blocks. Game Logic's footprint-core PR still merges before Ios Dev builds the ghost, renderer, inspect panel, and CI.

### 2026-10-25 11:28 AM EDT — Ios Dev — `cursor/ci-ipa-bundle-id-71ac` (PR #5)

- **Changed:** Merged `origin/main` (`b960f52`, PR #3) into this branch. Kept the shared `PROGRESS.md` and put this entry at the top of the log. Replaced bundle id `com.example.PocketRepublic` with `com.jscreate.pocketrepublic`, defined only in `Config/PocketRepublic.xcconfig`. The unsigned IPA is the sideload artifact for test builds. The workflow uploads `PocketRepublic-unsigned-ipa` on every push, including each merge to `main`, and on pull requests. Signing secrets stay optional and only add `PocketRepublic-signed-ipa` when all four are set.
- **Verified:** Run `40206715750` on the pre-merge commit succeeded on `xcode-27` with Xcode 27.1 (`27A9275`). The artifact is an `iphoneos27.1` IPA whose `CFBundleIdentifier` is `com.jscreate.pocketrepublic`. The signed step logged that `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISIONING_PROFILE_BASE64`, and `APPLE_TEAM_ID` are unset, and skipped that upload. Core tests ran in that job (41 tests). No local Swift toolchain here. The main-and-pull-request trigger is in this merge and still needs its own green run.
- **Next:** Optional signing, if wanted later, needs those four secrets plus an Apple Distribution certificate and an Ad Hoc profile for `com.jscreate.pocketrepublic`. Game Logic's footprint-core PR still merges before ghost preview, footprint rendering, and the inspect panel. The 11:34 AM entry records the green upload.

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
