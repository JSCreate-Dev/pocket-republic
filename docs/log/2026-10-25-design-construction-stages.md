# 2026-10-25 — Game Designer — `design/construction-stages`

Time: 25 October 2026, evening (EDT). Role: Game Designer. Branch: `design/construction-stages`.

## What changed

Spec only. No Swift, project, CI or asset file is touched.

`docs/DESIGN.md` gains **section 7, Construction stages**, the spec for next round item 1:

- **7.2–7.4 — stages and timings.** Three stages, `foundation`, `scaffold`, `complete`. Build days: house 2, police/market/workshop/farm 3, clinic/school/dock 4, town hall 0 (only worldgen places it, and day 0 has to be playable). Four days is the ceiling because the clock only moves when the player taps Advance One Day. All of it is data: `BalanceConfig.constructionDaysByKind` (dense 9-element `[Int32]`), `constructionDaysMultiplierPercent` (100 default, 0 reproduces today's instant build), `constructionFoundationPercent` (33, which gives 1+1, 1+2 and 2+2). The core stores two `Int32`s per building — days done and days required — and derives stage, a 0-to-1 `constructionProgress`, and `opensOnDay`. No `Double` and no dictionary enters the save, so `stateHash()` stays canonical.
- **7.5 — what it costs and produces.** Full build cost at placement (the existing `treasury → external` move, unchanged), then nothing: no upkeep, wages, workers, residents, production, food, business tax or service reach until it opens. The site claims its tiles and blocks pathing from the moment it is placed, entrance passable, as a finished building does. Demolish works through the existing path with no refund; `demolishRefundPercent` is named and deferred. The cost of the design is stated rather than hidden: a market is three days from feeding anyone, so the ghost's reach preview has to say when, and the lever if it plays badly is the multiplier, not an exception.
- **7.6 — art.** 8 new imagesets, foundation and scaffold per footprint shape, with exact 1x sizes, at the same `(W+H)×32` width and `(0.5, 0)` anchor as the finished sprites. 3×2 and 2×3 are drawn separately because their base diamonds point the other way — the same mistake the existing square-based market/workshop/dock sprites made. Scaffold heights are below every finished sprite of the same footprint, so completion reads as the building standing up.
- **7.7 — rendering.** Foundation lands on the tap with the existing bounce, dust, haptic and sound hook; stage change cross-fades on the day advance; completion is the pop (0.85 → 1.06 → 1.00 over ~0.25 s, dust ring, haptic). Scaffold sites have two looping builder figures that are decoration and write no simulation state. No progress number on the map.
- **7.8 — inspect.** `Under construction` goes first in `problemPriority` with its own tone, the people section is hidden, numbers become Opens / Progress / Placed, Demolish reads Cancel construction, and the ghost's reach preview is captioned with the wait.
- **7.9 — events.** `buildingConstructed` moves to completion day, which makes section 3's "A new {building} opens in {district}" headline true; a new `EventKind.buildingSiteStarted` fires at placement. The placement commission still fires at placement but its expiry becomes `max(advisoryExpiryDays, required + 2)`, so a 4-day dock's run-hard/clean question cannot expire the morning it opens.
- **7.10–7.11 — core changes and invariants.** New `advanceConstruction` step at the top of `advance`, before the `fields.dirty` check, so a building completing on day N is a service source that same day. A per-function skip checklist for `assignWork`, `produce`, `distributeFood`, `spoil`, `payWages`, `collectTaxes`, `payUpkeep`, `DistanceFields.rebuild`, `WorldGenerator.freeHouse` and `BuildingInspector`. `WorldGenerator.construct` must build worldgen buildings complete. `schemaVersion` 2 → 3, no migration. Construction draws zero RNG, so the seeded streams in 4.7 and `DeterminismTests` are unaffected; money and food identities are untouched because the change only removes movements.
- **7.12–7.13 — verification and deferrals.** Seven tests worth writing, plus a read of which existing tests are affected. Deferred: builders as real employed citizens, material costs, partial refunds, and reusing the stage machinery for repair after the hurricane event.

Small consistency edits elsewhere in the same doc: the header line and placement rule 7 in section 1, game-feel moment 1 in section 2 (the bounce now belongs to the foundation), and the `buildingSiteStarted` row in section 3's headline table.

`PROGRESS.md` **Current state** is overwritten to match the tree: the new construction-stage subsection, and the walker and ground-art paragraphs brought in line with PR #17, which had landed on main without a `PROGRESS.md` edit.

## What I verified

- Read `AGENTS.md`, `PROGRESS.md` and `docs/DESIGN.md` first, as step 1 and step 2 require.
- Read the core before writing numbers: `Buildings.swift`, `Intents.swift`, `SimulationEngine.swift`, `BalanceConfig.swift`, `DistanceFields.swift`, `BuildingInspection.swift`, `Snapshot.swift`, `WorldGen.swift`, `RepublicState.swift`, and the test suite. Every type, field and function the spec names exists on main, and the field names are copied from the source rather than invented.
- The PR #17 facts in **Current state** come from `docs/log/2026-10-25-walker-terrain-render-6511.md` plus a read of `IslandScene.swift`.

**Not verified:** `swift test` was not run — this branch changes no Swift, so the suite cannot have moved. Section 7.12's claim that the existing placement tests stay green is a prediction from reading them, not a measurement. No iPhone run, no CI run watched.

## Next steps

1. **Game Logic** implements 7.10: the `ConstructionStage` type, the two `Building` fields, the three `BalanceConfig` knobs, `advanceConstruction`, the skip checklist, `schemaVersion` 3, and the tests in 7.12. Re-run `swift test` and report the real count.
2. **Visual And Grapchics** draws the 8 imagesets in 7.6, at those exact sizes and anchors, 3×2 and 2×3 separately.
3. **Ios Dev** renders the stages and the pop (7.7) and the inspect changes (7.8), after the core state exists.

Open question for the lead, flagged rather than decided: whether the placement commission should instead be raised on completion. The spec keeps it at placement with a longer expiry, because the tradeoff belongs to choosing the spot.
