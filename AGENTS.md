# AGENTS.md

Working rules for every agent on Pocket Republic: Ios Dev, Game Logic, Game Designer, Visual And Grapchics, and anyone coordinating them.

## North star

Read [PROGRESS.md](PROGRESS.md) before you change anything. The **North star** at the top of that file is the bar every pull request is judged against: a lively, living world with a real game feel, and every screen laid out for the iPhone Duo both folded and unfolded.

[docs/DESIGN.md](docs/DESIGN.md) spells out footprints, placement, the inspect panel, sprite sizing, and the concrete feel targets. Section 3 specifies decree cards and the newspaper-style event feed. A change that is correct in isolation and still makes the city feel like a spreadsheet, or that only fits one Duo posture, is not done.

## Every task

1. Read `PROGRESS.md` (North star, Current state, open items, the latest log).
2. Read `docs/DESIGN.md` before touching buildings, placement, inspect, art, the Duo layout, decree cards, or the event feed.
3. Work on a feature branch and open a pull request. Never push to `main`.
4. Keep the pull request small and inside one role's area. The locked split and the merge order are in `PROGRESS.md`: **Game Logic's footprint-core PR merges first.** Ios Dev builds the ghost preview, rendering, the inspect panel, and CI on that core API. Do not implement both sides in one pull request.
5. In the same pull request, overwrite **Current state** in `PROGRESS.md` so it matches the tree after your change. Do not add a new **Log** entry there. Write `docs/log/YYYY-MM-DD-<short-branch>.md` instead: date and time in EDT, agent or role, branch or PR, what changed, what you verified (tests, CI, device), and next steps or blockers. Entries already in the `PROGRESS.md` log stay there.
6. Leave `FINDINGS.md` as history. Do not treat it as the current plan.

## Core invariants

`PocketRepublicCore` stays free of SwiftUI, SpriteKit, and UIKit. That is what keeps the renderer replaceable and lets the package test on Linux.

- **Determinism.** The same seed produces the same world. `SeededRNG` lives inside `RepublicState` (`worldSeed` plus `rng`) and is part of the save, so save and load resume the same stream. The core does not call global `Int.random` or `SystemRandomNumberGenerator`. Draw from `state.rng`. A new city may draw `worldSeed` once at the app boundary (`Game.freshState`); after that the seed is stored.
- **Money is conserved.** Movement goes through `RepublicState.transfer(from:to:)`. `externalInflow` and `externalOutflow` are how money enters or leaves. `checkConservation()` is the check the tests keep green.
- **Food is accounted.** `produced + imported − consumed − spoiled − exported` equals what is in stores (`Ledger.expectedFoodTotal`).
- **Crises have causes.** Every crisis and faction demand carries `CauseFactor`s. RNG jitters happiness and rotates which decrees are offered. It does not spawn a crisis by itself.
- **The clock.** `advance` is a no-op while `blocksAdvance` is true. Only crises and elections block. The standing agenda does not. After a tick, `agenda` is non-empty.
- **Tick order is load-bearing.** Follow the order in [PocketRepublicCore/README.md](PocketRepublicCore/README.md). Wellbeing is two-phase: read a snapshot, collect deltas, apply in id order.
- **Balance is data.** Tunable numbers live in `BalanceConfig`, serialized with the seed.
- **Saved-data rules.** Do not store a `Codable` dictionary whose keys are neither `String` nor `Int` (Swift encodes those in iteration order and the state hash stops being stable). The spatial save is `Application Support/PocketRepublic/spatial-v1.json` with `formatVersion` 1 and a `stateHash()` checksum. A file that fails validation is preserved and blocks play until the player chooses **Start New City**. Do not overwrite it on decode failure. The legacy `UserDefaults` key `pocket.republic.save.v1` stays untouched until a deliberate migration exists.

## Tests

From this repo, with Swift 6.2 (the toolchain the core README records as passing; this package's tools version is 6.0):

```bash
cd PocketRepublicCore
swift test
```

The unsigned-IPA workflow runs the same suite with `swift test --package-path PocketRepublicCore`. Debug runs are much slower than release; quote release timings only. `EconomyReportTests` and `CadenceTests` print dashboards. Read the printout after a balance change. The hungry-count figure in the core README is not an assertion.

The core README's Docker example still uses the old path `/home/jsmith/projects/pocket-republic/core`. Use `PocketRepublicCore` in this repo.
