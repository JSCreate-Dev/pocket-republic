# PROGRESS.md

Living handoff for Pocket Republic. Read this file before changing anything. **Current state** matches the tree after the latest handoff change. Until that pull request merges, main is the parent named there. Overwrite that section when the tree changes. The **Log** is history. It includes every note from `docs/log/` through the October handoff, newest first, plus the entries that were already here. Those files stay on disk. Later notes live only under `docs/log/`. A log note describes the branch at the time it was written, so an older note can disagree with **Current state**. **Current state** wins.

Later pull requests still write `docs/log/YYYY-MM-DD-<short-branch>.md` and do not add a heading to the **Log**. After this handoff, also read any `docs/log/` file newer than `docs/log/2026-10-25-handoff.md`. The **North star** is the bar every pull request is judged against.

## North star

Jordan wants Pocket Republic to feel like a lively, living world with a real game feel, not a spreadsheet sim. Every screen is optimized for the iPhone Duo folding display, both folded and unfolded.

[docs/DESIGN.md](docs/DESIGN.md) is the source of truth for footprint sizes, placement rules, inspect-panel contents, sprite sizing, the concrete game-feel targets (including the Duo postures: map and panel side by side when unfolded, a bottom sheet when folded), and section 3 (decree cards and the newspaper-style event feed). Sections 4–6 are the citizen-mind, random-event, and on-device model spec. What to build next, and who owns it, is **Next round** and **Team and process** below.

## Current state

**Ios Dev second round: diagnostic map layers.** The HUD now has a 44-point Layers menu in every supported layout, offering Normal, Fertility, Happiness, Food access and Jobs. It renders the authoritative MapOverlaySnapshot values as viewport-cached ground tints, with buildings dimmed for readability and night wash hidden only while diagnosing. Legends explain fertile soil, district averages, empty districts and stocked/empty/inaccessible markets. Inspecting a tile or building reports the selected layer's actual value. Farms have a direct Show fertility layer action. Overlay state is UI-only; changing it never changes simulation state or consumes money. New cities recenter the camera and clear old selection/routine caches.

Swift 6.2 syntax parsing of the two changed app files and git diff --check passed. The underlying map/core suite passed 147 tests. Xcode typechecking, visual contrast, frame rate, real gestures, color-vision accessibility and fold layouts still need Claude/device verification. No new IPA is claimed. The layer selector works on old saved maps too, while new coastline generation and the unlock tree require a fresh city.

**Game Logic second round: island terrain and overlay data.** New settlements get a seeded rounded coastline, an asymmetric bay, larger fertile/rock regions, connected buildable land and a protected central opening. A usable east-facing dock shore is retained. Explicit-population fixtures keep the established terrain generator. Existing saved tile arrays are not regenerated; this is not elevation or a new terrain kind.

MapOverlaySnapshot is a disposable, pure reader for fertility, district-average happiness, district employment and road/home food access. Water and missing resident data are nil. Food distinguishes stocked (100), empty (35) and inaccessible (0) markets. Dirty distance caches rebuild on a local state copy, so overlay reads cannot alter the real save/hash/RNG. Actual placement fertility, food reach and job status remain authoritative.

Swift 6.2 release: **147 tests, zero failures**, 5.238 seconds. Eight new map/overlay tests include connectivity and legal dock geometry over 18 seed/size combinations, exact replay, unchanged established terrain, save/load map identity, no mutation by reads, live resident means, and market stock/construction/demolition changes. UI overlay rendering is the next separate presentation change; no new iOS build or map-elevation claim.

**Ios Dev roadmap presentation and final placement integration.** Govern now shows a four-node Republic Roadmap with trade/community branches, live requirement bars, permanent unlock state and the one-time infrastructure grant. The Island next-goal chip opens the same reader, pauses the day clock while open, and releases the hold on close/tab exit. Locked catalog entries remain visible with the milestone reason, cannot be selected, and link to requirements. An unlock banner/haptic/VoiceOver announcement fires on a newly earned node, not on initial rendering of a loaded city. Existing cities get an explanatory unrestricted-catalog message.

Building receipts distinguish accepted construction from storage failure and remain until dismissed. Roads now report the accepted tile count and actual charge; a partially successful stroke says stopped early and retains the uncommitted preview. In build mode, starting a two-finger gesture restores the preview position from before the first finger touched, then latches navigation until all fingers lift. No background placement occurs. Local syntax/whitespace checks passed; Xcode and real-touch/visual confirmation remain Claude/device work.

**Ios Dev placement feedback, based on integrated build 143 (`e6508e8`).** Building placement now uses the explicit accepted/rejected result from Game.send, not the absence of an error string. An accepted placement records a persistent on-screen receipt (name, cost, opening day, current save status), highlights the construction footprint, and offers View construction site. It does not auto-open the tall inspect panel over the result. The receipt stays until dismissed, the site is removed, or a new city is started. Rejection preserves the preview and gives error feedback. A save failure is distinct from acceptance.

Build mode uses one finger to position the ghost. Two fingers navigate without changing the selected site; lifting back to one finger remains latched until all touches lift. Inspect mode still pans normally. Preview copy explicitly says nothing is built until Place is tapped, and Place includes the price. Async tap/hover callbacks ignore a stale tool or hidden Island tab.

Verified with Swift 6.2 syntax parsing of Game, IslandView and IslandScene plus git diff --check. No Xcode, UIKit interaction tests, simulator screenshots or phone results are claimed. Claude must build and verify the actual feedback, accessibility announcement, gesture transitions, and saved-state behavior. No core rules or terrain changes in this patch.

**Game Logic development tree, based on integrated build 143 (`e6508e8`).** New cities now save a four-node roadmap. A Working Town requires the starting population employed and a completed player-funded workplace, then unlocks clinics and grants $180. Harbor Charter (18 residents, everyone fed, two days of market food) unlocks docks and grants $250. Community Care (24 housed residents and an open clinic) unlocks schools and grants $350. A Civic Town (28 residents, an open school, happiness 45) unlocks police and grants $300. Harbor and Community branch from Working Town; Civic follows Community. Basics remain unrestricted. Earned unlocks never revoke.

The tick awards eligible nodes in fixed order after national mood, before crisis/agenda evaluation. Grants use external ledger transfers and each award emits an existing republicSeason event. Preview and placement enforce the same gate. To keep this core-only patch compatible with the app's exhaustive rejection switch, locked placement reuses seasonNotReady; the new UI reads DevelopmentTree.lockReason for the specific explanation. Optional progress/rules are omitted in old saves, including build-143 settlements, so their checksums and unrestricted catalogs remain intact. Only fresh cities get the tree.

Local Swift 6.2 release: **139 tests, zero failures**, 5.533 seconds. The normal construction/growth test reaches all four nodes on day 28 with 28 residents and $3,323. Tests cover gating, no spending on rejection, instant construction, construction timing, permanent unlocks, no duplicate grants, and old/new save continuation. iOS build is for Claude. Separate placement-receipt and roadmap presentation changes are not included in this core patch.

User priorities remain: unmistakable placement success/failure; one-finger positioning distinct from two-finger navigation; deeper terrain and district identity; citizen-purpose cues. Terrain/elevation and physical-phone behavior are not changed or verified here.

Integration of PR #32 (Game Logic) and PR #33 (Ios Dev) off main `97c1a2c` (PR #31).

**Settlement growth (PR #32, Game Logic).** Ordinary new cities now begin with **16 residents, four houses, a town hall, one market, one farm and one workshop**, $1,600 and a short central street network. Clinics, schools, police, the dock and island-wide roads are earned through play. Explicit `citizenCount` generation remains the established-city fixture used by the existing economy and scale tests. Existing saves keep their cities. New cities save optional `BalanceConfig.settlementGrowth`: every fourth day, up to two newcomers can arrive when an open house has reachable job vacancies and a stocked market with two days of food for the resulting population. Existing residents get first chance at jobs. Construction sites do not count. Hunger or average happiness below 40 stops arrivals. Newcomers bring $40 each through an external ledger transfer and generate a Gazette arrival event. No new save schema is required; missing growth settings stay nil on old saves. Walker schedules vary by occupation, citizen and simulation day. Older residents periodically visit reachable clinics; discontented residents sometimes visit the hall; fed residents sometimes make an evening market visit. Routes are still legal road paths, cosmetic, deterministic and independent of saved RNG. This is not the full citizen-minds system. Verified locally with Swift 6.2 release: **130 tests, zero failures**, 5.932 seconds.

**Island-first polish (PR #33, Ios Dev).** The island no longer reserves a navigation-title band. Its HUD is a compact, width-capped charcoal resource strip with warm brass accents, and building/work/housing feedback. The lower dock has a single row on wide displays and two rows on narrow displays, 44-point targets, restrained selection and a distinct Next Day action. Idle controls reserve 76 points on wide displays instead of up to 148. Build catalog tiles show existing building art, price and construction days. Detail cards and fold-reserved panes keep their existing behavior. Citizens find work automatically; the HUD says to expand the economy, not assign workers. Verified: Swift 6.2 parser on all three changed Swift files. Build 143 verified SwiftUI typechecking and the device build; physical Duo posture interaction was not verified by CI.

PR #24 remains the construction clock in the core: foundation, scaffold, complete, in whole sim-days. PR #26 draws those stages. PR #27 did not retune build times. A demolished building is no longer a ghost workplace: `isStanding(on:)` is the economy gate, and `visibleBuildings` omits rubble. Sites still draw, because they own their tiles.

`PocketRepublicCore` on main `744e692` executed **105 tests, 0 failures** in that IPA run (151.665 seconds in the log). PR #27 had measured 100 before the sheet-order and gazette-paper tests. This branch's push of the origins pass executed **116 tests, 0 failures** (137.683 seconds) in [run 42440421955](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/42440421955). Seed 2026 for 200 days in the PR #27 log: hungry 0, market coverage 100% in every district, with `maxServiceDistance` 21 on a new city. A save that already stores 20 keeps 20. A reported core check of the event deck passed 6 seeds plus save/load, RNG continuity, and no double resolution. No iPhone run was part of that check.

The repo is a SwiftUI app plus a SpriteKit island. The simulation is the pure-Swift package `PocketRepublicCore` (tools version 6.0, deployment target iOS 17). The core sources import Foundation only. The app sends `PlayerIntent` values into `SimulationEngine` and draws a read-only `WorldSnapshot`. **Next Day** (closed screen) and **Advance One Day** (split pane) both call `Game.advance()`. The day-speed menu can repeat that same call on one app-owned timer. It starts paused. It does not run while the app is inactive, while a confirmation is open, while a crisis blocks the day, or while an island event is still on the agenda, and it never catches up days that passed in the background. Animated walkers, the day/night wash, scaffold builders, and the completion pop do not write simulation state. A stage still changes only when a sim-day advances. Core rules for determinism, money, food, crises, tick order, balance data, and saves are in [AGENTS.md](AGENTS.md) and [PocketRepublicCore/README.md](PocketRepublicCore/README.md). Follow those. Do not re-derive them from this summary.

The core has agenda, decrees, and factions. `DecreeCatalogue` is data applied through `RepublicState.apply`. `DecreeSpec` has `name`, `cost`, `salience`, and `effect`. It has no flavor string. Factions are `labourers`, `merchants`, `officials`, and `landless`. Only a crisis or an election blocks the day advance. The standing agenda does not.

Four tabs: Island, People, Govern, and Gazette. Govern is decree cards, legitimacy, corruption, the income-tax stepper, council and island-event cards, and Start New City. Start New City opens a picker. The current city is replaced only after an ordinary island or one of the three origins is chosen. People is one card per living citizen. The Gazette groups the core event log by day. An island event shows its filled headline and, once answered, the outcome sentence. `IslandEventPaper` drops only the earlier raise whose event id that outcome answers, so a later card with the same headline stays. `AgendaSheetOrder` puts a crisis-tier row, including an election, ahead of an origin dilemma, then an island event. Both are readers. They do not post cards or change a save. The package tests cover those two regressions. Ordinary news gets a headline and a because-line. The raw `flavor: <day>` line is not shown. On the island sheet an election, or any other agenda row with crisis tier, outranks an origin dilemma and an island event. The one-card phone preview is that blocking choice, and an island card does not auto-open over it. Play cannot advance while `blocksAdvance` is true.

### Multi-tile footprints (PR #12)

Buildings occupy multi-tile footprints. The anchor is the minimum-x, minimum-y corner, and the footprint extends in +x and +y. Footprints do not rotate. Sizes match the design table: house and police 2×2, market and workshop 3×2, farm, clinic, school, and town hall 3×3, dock 2×3. `WorldMap.tilesCovered`, `buildingAt(_:)`, `isPassable`, and `isEntrance` are the lookups. Roads are passable, and so is each building's entrance. Every other footprint tile blocks movement. `SimulationEngine.validatePlacement` previews a site and does not change state. The entrance is the lowest tile index among perimeter tiles that orthogonally touch a road. The building's district is that entrance's district. Farms need at least half their tiles on fertile land. Docks need one full long side against water. Demolish clears every tile the building still occupies. `RepublicState.schemaVersion` is 3 (see construction stages below). A schema 1 or 2 save does not decode. The file is kept until the player chooses **Start New City**. World generation paints extra 4×4 fertile patches and parks the dock on the east shore.

A new city uses `WorldGenerator.generate`, whose default `size` is 64, so the island is 64×64. [docs/DESIGN.md](docs/DESIGN.md) section 1 says 96×96. Scale tests pass `size: 96` themselves. That gap is map tuning, listed in next round item 4.

### Hunger (PR #11 and PR #14)

The surplus-and-hungry failure is fixed. Farms used to ship a whole day's output to the single nearest market, that market paid for food it could not sell and went broke, and distance was measured on the floor tile instead of the door. `distributeFood` now shares the day's sales: one unit per farm per pass, shopper shortfall first (the food still moves when the till cannot prepay), then paid surplus to markets that can buy without spending wage money. Reach, feeding, coverage, faction tallies, and the no-market penalty all use the door.

PR #27 set `maxServiceDistance` to 21 for a new city, which is the extra step a footprint adds between a door and the road. `HungerTests` on main now requires nobody hungry inside or past that cap on seeds 2026 and 11, and it locks the fresh default at 21. A save that already stored 20 keeps 20. The map is still 64×64. The design doc still says 96×96.

### Tap-to-inspect (PR #7)

Tapping a placed building, with Inspect selected, selects the building that occupies that tile and opens `BuildingInspectPanel` in the controls sheet or side pane. The panel sizes to its content. Copy and field order live in `BuildingInspectCatalog`: status, then staffing, then numbers, then actions. A site reports construction ahead of the problem list. For a finished building, status priority is no road access, then understaffed, then no food, otherwise "Running well". Houses show residents out of capacity, with each living resident's job and hunger. Farms, workshops, and docks switch `OperatingMode` by sending `PlayerIntent.setOperatingMode`. Demolish asks for confirmation, then sends `PlayerIntent.demolish`. A site says **Cancel construction** and tells the player the money is not refunded. The Town Hall has no demolish button. Every occupied tile is highlighted. A selection haptic fires with the selection. Empty ground or Close clears it. Road and building tools still place on tap. A drag pans, and a pinch zooms. A tap on empty ground still shows the tile caption. The sprite wiggle and follow-a-resident are not built.

### Placement ghost and sprite rendering (PR #9, art from PR #4)

`CityFootprints.current` is `CoreFootprintModel`. It reads `BuildingKind.footprint`, `tilesCovered`, `buildingAt`, `isEntrance`, and `validatePlacement`. Each building is a sprite anchored at `(0.5, 0)` on the south corner of the tiles it covers. Node size comes from `BuildingSpriteCatalog`, which copies `docs/art/sprites.json`: a house is 128×125, a town hall is 192×222, and every width is (W+H)×32. The image name is `building_<kind>`. Nine imagesets live in `PocketRepublic/Assets.xcassets/Buildings/`. A missing image would draw a placeholder of the same point size. The images are in the catalog, so the island loads them. Market and workshop now use 3×2 diamonds with their long axis on +x; dock uses a separately drawn 2×3 diamond with its long axis on +y. Their canvas sizes and asset names are unchanged. While a building tool is selected, a ghost follows the tile under the finger. It uses the foundation sprite when the build takes days, and the finished sprite when it opens immediately. It is tinted green when `validatePlacement` accepts the site and red when it rejects it. The `IntentRejection` sentence shows on the map and in the control pane. Market, clinic, school, and police also draw the tiles within `maxServiceDistance` (20) on the passable network, measured from the entrance `validatePlacement` returns. A rejected placement has no entrance, so it draws no reach. A light impact haptic fires when a building lands, and the ghost hides so the new sprite is not covered by an occupied tint.

`docs/art/sprites.json` is on main. The comment that said it was missing has been removed.

### Walker routines (PR #15, the re-land of PR #13)

`WalkerRoutine.plan` builds a deterministic day. Hours are 0..<24, and a dwell's end hour is exclusive, so the gap before the next dwell is the walk. An employed citizen with a market in range is home from hour 0 until hour 7, at work from hour 8 until hour 15, at the market `shoppingMarket` already uses from hour 16 until hour 18, and home again from hour 20. Someone without a job skips work and shops earlier. A door past `maxServiceDistance` gets no market stop. Hours 0..<24 pick a tile on that walk. Destinations are entrance tiles from `BuildingAccess`. `MapBuildingAccess` records `Building.tile` (the entrance) and forwards `WorldMap.isPassable` and `building(at:)`. `Pathfinder` is a deterministic BFS on that access. The plan is a pure function, so the save and the state hash do not store it. `WalkerRoutineTests` covers the hour schedule, unemployed citizens, a door out of range, entrance tiles from the access interface, and a path around a blocked 3×3 footprint.

`IslandScene` now calls `WalkerRoutine.plan` for each living citizen and caches the `DailyRoutine`, clearing that cache after a simulated day or road/building occupancy change. It draws citizens whose routine path or entrances cross the viewport; the old 24-employed-citizen cap and drifting yellow road dots are gone. The scene plays the 24-hour plan as a repeating 48-second visual day (two seconds per hour), interpolating along `legPaths` between dwell hours while the simulation waits for **Advance One Day**. A stable offset derived from each citizen ID staggers pose changes and walk frames across up to 1.5 seconds, so visible walkers no longer move in lockstep. It uses 12×18 `walker_<0-5>_{ne|sw}_f0/f1` sprites with nearest filtering, a moving frame only while walking, and an orange tint for hungry citizens. Missing walker art falls back to a white dot. This is code and CI build verification; no iPhone animation or frame-rate check was done.

### CI, bundle id, and art

PR #5 is the workflow named **Build iOS IPA** (`.github/workflows/unsigned-ipa.yml`). It runs on the hosted `xcode-27` runner with `DEVELOPER_DIR` set to Xcode 27.1, on every push, including each merge to main, and on fork pull requests. The job runs `swift test --package-path PocketRepublicCore`, then builds an unsigned `iphoneos` app. The test-build artifact is `PocketRepublic-unsigned-ipa`. The bundle id is `com.jscreate.pocketrepublic`, defined only in `Config/PocketRepublic.xcconfig`. Debug and Release both include that file. Optional signing secrets can also upload `PocketRepublic-signed-ipa`. They are not required for a sideload build. The main run for `a93d04f` completed successfully. An iPhone install or run was not verified on this art branch. The Xcode project still records `CreatedOnToolsVersion = 15.0` and `LastUpgradeCheck = 1500`. The deployment target is iOS 17.0, and `TARGETED_DEVICE_FAMILY` is 1 (iPhone only).

PR #1 added [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md) and the 1024×1024 app icon (`AppIcon`, 8-bit RGB, no alpha), selected with `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`. PR #4 added the nine building sprites and `docs/art/sprites.json`; this branch replaces the market, workshop, and dock images in place to correct their base geometry. PR #6 added batch 2 under `PocketRepublic/Assets.xcassets/`: 31 terrain imagesets, 16 road overlays, 14 decorations, 26 walker and cart imagesets, and 7 UI icons (94 imagesets), plus `docs/art/ASSETS.md`, `UI_STYLE.md`, `road_autotile.json`, and `decos.json`. PR #17 connected the ground and walker art to `IslandScene`: terrain variants use a stable coordinate hash; 16 road overlays use the N/E/S/W neighbour mask; shore overlays face adjacent land; and sparse decorations are selected on empty sand, grass, fertile, or rock. Ground and road sprites are 64×32. Missing terrain or road art falls back to a procedural tile; decorations with missing art are skipped. The water animation and palm sway are not played. Cart images and batch 2 UI icons are not referenced by the app's Swift sources.

### Saves

A valid city is `Application Support/PocketRepublic/spatial-v1.json` (envelope `formatVersion` 1, checksum `stateHash()`, `RepublicState.schemaVersion` 3), written atomically. A corrupt or unsupported file, including a schema 1 or 2 save, is kept and blocks play until **Start New City**. The app reads the `UserDefaults` key `pocket.republic.save.v1` only to detect the old prototype. It never decodes or migrates it. A new city draws `worldSeed` once with `UInt64.random` at the app boundary (`Game.freshState`). After that, `worldSeed` and `rng` live in the saved state. Changing `worldSeed` drops the scene's construction memory so a new city does not inherit another city's pops.

### Construction, on the island (this branch)

The core rules from PR #24 are unchanged and still the source of truth. `Building.daysConstructed` and `daysRequired` are stored. `stage(in:)`, `isUnderConstruction`, `constructionProgress`, `stageProgress(in:)`, and `opensOnDay` are derived. `advanceConstruction` runs at the start of `advance`. A site does nothing until it opens. Worldgen and a loaded finished building stay `complete` (`daysRequired == 0` or `daysConstructed >= daysRequired`). Schema is 3. A multiplier of 0 still opens a building the day it is placed.

`IslandScene` now reads that stage. Foundation and scaffold use the section 7.6 imagesets (`site_foundation_*`, `site_scaffold_*`), same `(W+H)×32` width and `(0.5, 0)` anchor as the finished `building_<kind>` sprite. 3×2 and 2×3 stay separate. A missing imageset draws a flat placeholder of the same point size. The placement ghost is the foundation when the build takes at least one day, and the finished sprite when it does not.

Transitions play once per stage change, remembered on the scene by building id. The first picture of a city or a loaded save is quiet: existing buildings, including ones already under construction, do not bounce or pop just because the view drew them. A building placed during play lands with a short scale bounce and a dust puff. Foundation to scaffold cross-fades in about 0.2 seconds. Scaffold to complete (or foundation straight to complete when the build is one day) plays the pop: scale 0.85 → 1.06 → 1.00, a larger dust ring, and one light haptic. Panning, folding, resizing, and the extra `render` from saving do not start those actions again. Culling a sprite and bringing it back does not replay a transition that already played. Two decorative builders and a pennant walk a scaffold; they are not citizens and write no state. They are removed when the building opens.

Walkers keep playing a 48-second visual day over a paused sim day. Construction progress does not tick between days. The inspect row says the stage changes when the sim-day advances, and that Play uses that same step and starts paused. There is no continuous simulation behind the sprite.

The inspect panel keeps the core's status string and paints it as a timber banner, with the stage and day count, a progress bar from the core's percent, **Cancel construction** (no refund), and "Takes effect when it opens" on the mode picker. `InspectTone` is still `.calm`. Adding `.progress` would be a core change and was left for the core owner. A service ghost that will not work yet is captioned `Reach when it opens, in N days`.

### Duo layout, decrees, and citizens (this branch)

Phone and a wide flat window (the iPad case that used to split 50/50) keep the map full width. A short dock holds Inspect, Build, Road, pause, and Next Day. A decision, the catalog, or an inspect card opens above that dock and scrolls. It does not take a blank half of the screen. Book and laptop folds still follow `reservedRegions` on iOS 27.1, and that pane packs from the top. Outer landscape can still switch to a tent dock. Footprints, road overlays, building anchors, and walker routes are the same scene.

### Map-first building (this branch)

Build opens a catalog grouped as Homes, Food, Work, and Services. Choosing one shows the existing footprint ghost, the price, and `validatePlacement`'s reason. Place sends `placeBuilding`. Cancel leaves the map. Services draw `ServiceReach` from `maxServiceDistance`. A finished service building draws that same reach; a site does not pretend it is open.

Road is a mode. One finger adds up to 24 tiles. Two fingers pan and pinch together: the midpoint follows the same camera delta as one finger, then the pinch stays on that midpoint. A second finger latches the gesture so lifting one finger does not add a road tile. Pave sends `buildRoad` in order at $10 a tile and stops on the first rejection. The core is still one tile at a time. Leaving the Island tab returns the tool to Inspect, clears the draft and the ghost, and releases only the build and catalog clock holds.

The charter is one line on the HUD (tap it for the card). Hungry residents, when the districts report any, are named from `hungryCount`. An election or other crisis still opens on the island and blocks the day. An island event or origin dilemma is a button, not a card that covers the map. The live clock still pauses while that event is waiting, while a crisis blocks, and while Build, Road, or the catalog is up. People, Govern, and the Gazette stay tabs. Start New City is unchanged.

People are cards (hungry first, initials portrait, happiness, money, hunger). Govern shows decree cards from `DecreeCatalogue` and `AgendaEffect`: title, cost or Free, "Need N more", faction arrows, and the effect lines the spec already stores. **Issue decree** sends the enact option. **Not now** only closes the card, because the core's dismiss option would remove the offer and emit `decreeIssued`. There is no decree flavor line: `DecreeSpec` has no `flavor` field.

Island events from PR #27 are ordinary agenda rows with `islandEventID`. The island sheet and Govern show `spec.title`, tone, the filled headline, the flavor sentence, why it fired, and the core's option buttons. A button whose `treasuryCost` is above the treasury is disabled and says how much is missing. The lapse line names the free option and the last open day. **Not now** only hides the card. Expiry still applies that free option inside `advance`, and it does not spend the treasury. A council row with no `islandEventID` keeps a plain title, a because-line, and the same affordability rule. The closed-screen preview puts a crisis-tier row, including an election, ahead of an origin dilemma, then an island event, then other advice, then a decree. On a one-card phone the blocking choice is the button. An island event does not auto-open over it. An origin dilemma does not auto-open over a crisis.

### Season of the republic (this branch)

A new city shows one objective on the island, above the tools and beside Next Day: place a building and open it. Worldgen buildings do not count (`daysRequired == 0`). Sealing the charter pays $120 into the treasury from outside the economy, once. The card says the treasury receives $120, the button says receive $120, and the banner says the treasury received $120 and to choose one compact. The compact is the next beat. It is not part of the grant.

The compact costs $280 and only one can be taken. **Granary** adds 1 food per farm worker each day and adds $1 of upkeep on every private workplace. **Harbor** adds $2 per workshop or dock worker each day and raises food spoilage by 4 points. The other button is rejected after the choice, including after save and load.

The longer mark is a settled republic: two kinds of buildings the player opened, food still in stores, mean happiness at least 40, and day 5 or later. That pays +4 legitimacy once and lowers the unemployment happiness penalty by 1 from then on. A save from before the season has no `republicSeason` key, still decodes, and still matches its checksum. An older city can seal the charter once if it already opened a player building. It does not get paid again on load.

**Start New City** asks which island, and the current city stays until that choice. Ordinary is the old island: no `origin` key, no opening dilemma, no formula change. **Letters of Marque** opens with corruption 28, legitimacy 52, +$400, merchants +6, officials −6, then +$1 per dock or workshop worker and spoilage +2. **The General's Square** opens with corruption 16, legitimacy 78, officials +8, labourers −8, landless −6, then civic upkeep −$1 (floor 0) and the unemployment penalty +1. **The Common Pot** moves $600 out when the treasury can cover it, puts 40 food on each standing market (recorded as imported), labourers +4, merchants −4, then spoilage −2 (floor 0) and export coin −$1 per worker (pay never goes below 0). Each origin posts one advisory dilemma, two choices, ignore cost 0, gone after day 6, and a lapse only drops the card. The compact is still chosen after the charter. Origins stack with it. The same seed and origin replay. Loading does not pay the purse again.

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

- **A stored city can still have market cap 20.** New cities use 21. PR #27's hunger test expects zero hungry on seeds 2026 and 11 at that cap. The map is still 64×64 against the design's 96×96.
- **Batch 2 presentation is partial.** `IslandScene` draws the terrain, roads, decorations, and walker sprites. Water animation and palm sway are static. Cart images and most batch 2 UI icons are still not referenced by Swift. Market, workshop, and dock use the corrected diamonds from PR #23.
- **No device playtest of this tree.** Stage sprites, the pop, the sheet, island-event cards, the Gazette, and day speed need an iPhone. CI is the compile check.
- **Decrees still have no flavor string.** `DecreeSpec.flavor` is a core addition. The Gazette is a reading of the existing log, not the full section 3 newspaper (no Show me camera pan, and some headlines are generic when the event has no place or name). PR #10 stays open and conflicting. Do not treat it as the current UI.
- **Inspect has no wiggle and no follow.** The panel sits in the bottom sheet when the phone is closed and in the side pane when the window is split. Tapping a building does not wiggle the sprite. Tapping a resident does not follow them.
- **Two save leftovers.** `pocket.republic.save.v1` is detected and never migrated. A spatial file from schema 1 or 2 does not decode under schema 3. The app keeps that file until **Start New City**.
- **A new city is 64×64.** The design doc says 96×96. See next round item 4.

## Open items

Finished on main: footprints, the hunger fix through PR #27's cap of 21, tap-to-inspect, sprites and the placement ghost, walker routines, the unsigned IPA, construction stages in the core and on the island (PR #24 and PR #26), the eight site imagesets, the non-square finished sprites, and the six-card island deck plus demolished-building lifecycle (PR #27). This branch is the player-facing reading of those events, plus an optional day timer. The ordered work is **Next round**.

### Game Designer

Section 7 is in the game. One open design question remains: a commission is still raised at placement, days before a farm opens. Sections 4 and 6, and the rest of section 5, are still spec.

### Game Logic

Still open, and not this branch: `DecreeSpec.flavor`, a cause on every negative event that still lacks one, the other eight section 5 cards and the rare one-offs, citizen minds, the on-device model hook, and a 96×96 map. `CauseKind.underConstruction` (spec 7.9) is still optional. Deferred inside 7.13: real builder citizens, material costs, `demolishRefundPercent`. `InspectTone.progress` is optional. The app already paints that row. Day pacing did not need a core clock.

### Visual And Grapchics

Site art and the corrected diamonds are on main. Water, palms, carts, and a sound for place and open are still unwired. No new art is in this branch.

### Ios Dev

Island-event cards, the Gazette, the paused-by-default day speed, and the season arc are on this branch. Still open: a phone playtest, a fuller newspaper, the inspect wiggle, and follow-a-resident. A player-chosen panel layout stays deferred. PR #10 and PR #25 stay open. Do not rebase them and do not close them from here. Do not reopen PR #26 or PR #28.

## Next round (priority order)

1. **Phone playtest of the season and the existing loop.** Place a house. The charter stays closed until it opens, then Seal the charter pays $120 once. Choose Granary or Harbor and confirm the other compact will not take. Open a second kind of building. When food and happiness hold, mark the republic settled once. A celebration line and haptic fire on the claim, not on launch or rotation. Next Day and the map stay available. An election still outranks an island event. Play stays paused by default and does not run in the background.

2. **The rest of the event deck, and decree flavor.** Core owns the other cards and `DecreeSpec.flavor`. The card and the Gazette already have a place to show flavor when that string exists.

3. **Inspect wiggle, follow-a-resident, and the remaining ambient art.** Water, palms, carts, and a real sound asset.

4. **Map size.** 64×64 versus the design's 96×96. The market cap for a new city is already 21.

5. **Citizen minds.** [docs/DESIGN.md](docs/DESIGN.md) section 4. Rolls stay on seeded streams.

6. **The small on-device model hook.** Section 6. iOS 17 stays the minimum.

7. **Custom iPhone Duo layouts.** Deferred until this loop has been played.

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
