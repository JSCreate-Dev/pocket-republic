# PROGRESS.md

Living handoff for Pocket Republic. Read this file before changing anything. **Current state** matches the tree after the latest handoff change. Until that pull request merges, main is the parent named there. Overwrite that section when the tree changes. The **Log** is history. It includes every note from `docs/log/` through the October handoff, newest first, plus the entries that were already here. Those files stay on disk. Later notes live only under `docs/log/`. A log note describes the branch at the time it was written, so an older note can disagree with **Current state**. **Current state** wins.

Later pull requests still write `docs/log/YYYY-MM-DD-<short-branch>.md` and do not add a heading to the **Log**. After this handoff, also read any `docs/log/` file newer than `docs/log/2026-10-25-handoff.md`. The **North star** is the bar every pull request is judged against.

## North star

Jordan wants Pocket Republic to feel like a lively, living world with a real game feel, not a spreadsheet sim. Every screen is optimized for the iPhone Duo folding display, both folded and unfolded.

[docs/DESIGN.md](docs/DESIGN.md) is the source of truth for footprint sizes, placement rules, inspect-panel contents, sprite sizing, the concrete game-feel targets (including the Duo postures: map and panel side by side when unfolded, a bottom sheet when folded), and section 3 (decree cards and the newspaper-style event feed). Sections 4–6 are the citizen-mind, random-event, and on-device model spec. What to build next, and who owns it, is **Next round** and **Team and process** below.

## Current state

**Phone layout repair, based on integration 139960ac38c6e18f3228833fdb3836ba74e1bc38.** Jordan’s latest portrait screenshot exposes the new bottom navigation covering the second dock row and the town framing beneath a tall HUD. MainView now allocates navigation as a sibling beneath the content, rather than an inset beside manually positioned map controls. The map measures its dock’s intrinsic height and reserves it when larger text or narrow width produces taller controls. The camera’s focus rectangle excludes the measured HUD where space allows; existing camera focus preservation remains in use. The persistent unlock row moves into the island menu; unlock announcements and the roadmap itself remain available.

**Honest opening advice.** The jobs prompt subtracts existing vacancies from residents awaiting work. A fresh seed-42 settlement says “Make room for 3 more jobs”, explains that existing jobs fill automatically, and keeps the workshop preview action. The ready-vacancy case explains automatic hiring and road access. All readers remain read-only; no hiring, simulation, save-format, art or economy change is included.

**Validation and remaining device work.** Swift 6.2 app syntax parsing, actual viewport-bounds checks and actual prompt/preview checks pass. These exercise portrait, short landscape, unfolded and enlarged dock/HUD bounds, day-zero and assigned employment, construction, housing, hunger, legal deterministic previews and no state mutation. This does not establish SwiftUI typechecking or rendering on iOS. Claude must build with Xcode and verify both clock rows above navigation, Dynamic Type, fold/rotation, placement, preserved selection/camera, sheets and first-frame loading. Core source is unchanged; the previously reported 193-test suite has not been rerun for this UI-only repair. Earlier island-first catalog, navigation, tutorial, news, launch/save recovery and simulation safeguards remain. No IPA or GitHub publication is claimed.

## Spec that is not built

[docs/DESIGN.md](docs/DESIGN.md) sections 4 and 6 are spec only. There is no `CitizenMind` or `Narrator` type. Section 5's deck is six cards in the core (carnival, celebrity visit, smuggler ring, fishing bonanza, generous expat, foreign trade offer), posted as advisory agenda rows. Hurricane, strike, blight, the rest of the 14, and the rare one-offs are not built. Section 6, the on-device model, is not built. The minimum target stays iOS 17.

## Owner playtest feedback (Oct 25, 2026)

Jordan tested on an iPhone. No art assets were in that build.

1. Walker dots go back and forth between spots.
2. Buildings should take up more space, with bigger footprints.
3. Research how building placement and assets work in Cities: Skylines and Tropico. That research is written up in [docs/DESIGN.md](docs/DESIGN.md).
4. Tapping a placed item should show details about it.

Footprints and tap-to-inspect are on main. PR #17 replaced the shuttling dots with daily-routine walker sprites and drew the batch 2 ground art; the result has not been checked on an iPhone. The reference-game research is the design doc, including the Tropico work-mode idea that `OperatingMode` already follows. Construction stages are drawn on this branch. They still need a phone playtest. That is next round item 1.

## Known issues

- The latest combined source still needs a real Xcode/phone build. Previous successful IPA checks do not validate these new views, camera tour or emitters.
- Fixed-angle sprites and unrotated footprints remain. True view/building rotation needs directional art, projection/hit-test/depth/road-mask work and saved rectangular orientation.
- Citizen animation and the light cycle remain visual clocks, separate from six-second economic ticks. Walk plans refresh at visual midnight (up to one 48-second visual cycle later), not at each economic update. Blocked walks can temporarily disappear until then. This is not a traffic/commute economy.
- New maps remain 64×64; the design's 96×96 expansion is not done. Older saves retain their market-distance configuration. Schema 1/2 spatial saves and the old prototype key are not automatically migrated.
- The journal retains six day summaries for the current visit. Persisted city events are still read through Gazette, not a new report database.
- The full citizen-mind/on-device narrator spec and fuller event deck are not implemented. Progression remains the existing four-node roadmap/season arc; the new goals explain it rather than inventing rewards.
- All nine finished-building families are detailed, but construction, vegetation, character and directional animation art are not fully restyled. Real place/open sounds and movie/voice/music assets are absent.

## Open items

### Game Designer

Review first-minute goal order, six-second pacing, the final explicit tutorial choice and the placement commission that can precede opening. Longer-lived production/trade/district objectives need a concrete balanced design before new mechanics are added.

### Game Logic

Keep conservation/determinism and old-save checks green. Remaining depth includes fuller caused events, rare one-offs, citizen minds and future production/trade choices. This round fixes local rehousing/missed-meal recovery and shares admission capacity planning. Future production/trade depth remains scoped separately.

### Visual And Grapchics

Finished-building and ground families are wired with fallbacks. Next art work is cohesive environmental/character/construction layers, directional assets, restrained ambient animation and real sound assets. Water is animated; it is no longer a static/unwired item.

### Ios Dev

Build/typecheck the combined source and playtest real phone/fold layouts, tour cancellation/clock restoration, journal actions/day results, goal progression, marker/route interaction, Reduce Motion, VoiceOver, zoom and frame rate. Autoplay is enabled by default; no background catch-up. Reading optional cards stays nonblocking.

## Next round (priority order)

1. Build the complete launch/save-recovery handoff on f07285d, or select the supplied incremental route after the exact prior handoff. Phone-test cold/warm launch, Continue/frame gate/Back, tutorial timing, real old saves, save failure/retry, backup restore/same-seed reset and New City failure; then recheck housing/growth/notices.
2. Tune feedback/caption density and goal order from actual play. Validate net changes versus purchases and continued progress without duplicate-project nudges.
3. Design/test longer-lived production, trade and district choices plus the fuller event deck.
4. Implement true rotation as a separate art/projection/orientation feature; do not fake it with a screen spin.
5. Restyle remaining environment/character/construction art and add measured audio/ambient work with accessibility/performance checks.
6. Keep citizen-mind/narrator and 96×96 work explicitly scoped and profiled rather than assumed built.

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
