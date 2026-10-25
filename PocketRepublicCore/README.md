# PocketRepublicCore

Deterministic, headless simulation core for Pocket Republic. Pure Swift: it must
never import SwiftUI, SpriteKit or UIKit. That constraint is what keeps the
renderer replaceable and lets the whole thing test on Linux CI with no Mac.

## Running the tests

No Swift toolchain is needed on the host — the Ubuntu Swift builds do not run on
this Arch box (missing `libncurses.so.6`, `libpython3.9.so.1.0` and friends).
Use the official image:

```bash
cd /home/jsmith/projects/pocket-republic/core
docker run --rm -v "$PWD":/pkg -w /pkg swift:6.2 swift test            # 40 tests
docker run --rm -v "$PWD":/pkg -w /pkg swift:6.2 swift test -c release # for timings
```

Debug timings are ~12x slower than release; quote release numbers only.

## The contract with the renderer

Intents in, snapshots out. The renderer never mutates simulation state:

```swift
let result = SimulationEngine.apply(.placeBuilding(.farm, at: tile), to: &state)
SimulationEngine.advance(&state)                 // one day
let frame = state.snapshot(visibleRect: camera)  // viewport-culled, read-only
```

`advance` is a no-op while `state.blocksAdvance` is true. Only crises and
elections block; the standing agenda never stalls the clock.

## Tick order

`advance()` runs these in order, and the order is load-bearing:

1. `rebuildSpatialCaches` — only when `fields.dirty` (a build/demolish happened)
2. `assignWork` → `produce` → `distributeFood` → `payWages`
3. `feedCitizens` → `collectTaxes` → `payUpkeep` → `spoil`
4. `updateWellbeing` — strictly two-phase: read an immutable snapshot, collect
   `CitizenDelta`s, then apply in ID order. No citizen sees another's same-day
   change, which is what makes the tick order-independent and parallelisable later.
5. `aggregateDistricts` → `updateFactions` → `updateNationalMood`
6. `evaluateCrises` → `AgendaGenerator.update`

## Invariants the tests enforce

- **Determinism.** Same seed, same everything, for 500+ days. The RNG lives
  *inside* serialised state, so save→load resumes the identical stream.
  Never use global `Int.random`; draw from `state.rng`.
- **Money is conserved.** Every movement goes through `transfer(from:to:)`.
  `externalInflow`/`externalOutflow` are the only way money enters or leaves.
  `checkConservation()` throws if the books disagree.
- **Food is accounted.** produced + imported − consumed − spoiled − exported
  must equal what is actually in stores.
- **No pure-RNG crises.** Every crisis and every faction demand carries
  `CauseFactor`s naming the district or policy that caused it. RNG only jitters
  happiness and rotates which decrees are offered.
- **Something actionable every tick.** `agenda` is never empty after a tick, at
  both 500 and 1000 citizens, across seeds.

### Serialisation gotcha

Do not store a dictionary whose keys are neither `String` nor `Int`. Swift
`Codable` encodes those as a flat array in iteration order, which makes the save
file and the state hash non-canonical between runs. `DistanceFields.fields` and
`AgendaEffect` favor pairs both use parallel/dense arrays for this reason.

## The decision stream

Four tiers, in descending urgency. Only `.crisis` blocks the clock:

| Tier | Source | Expires | Ignoring it |
|---|---|---|---|
| `.crisis` | `evaluateCrises`, elections | never | blocks play |
| `.demand` | a faction's real dominant grievance | `demandExpiryDays` | costs favor |
| `.advisory` | a district stat drifting below the crisis line | `advisoryExpiryDays` | free |
| `.decree` | `DecreeCatalogue`, always available | never | free |

Decrees are the floor guarantee: because they never expire and are always
offered, "something every tick" is true by construction rather than by crisis spam.

**Factions** (`labourers`, `merchants`, `officials`, `landless`) are a readout,
not a separate opinion system — membership is derived from occupation every
tick. `favor` (−100…100) persists for the whole campaign and is remembered in a
bounded `memory` list, so a cheap decision now is paid back or charged for later.

**Adding decision content does not mean touching the engine.** Options carry an
`AgendaEffect` — pure data — applied through one generic path in
`RepublicState.apply(_:at:)`. Add a `DecreeSpec` to `DecreeCatalogue.all` and it
is in the game.

## Tuning surface

Everything numeric lives in `BalanceConfig`. Balance is data, not code: a config
serialises next to a seed to reproduce a run exactly. Nothing in the engine
hardcodes a tunable.

`EconomyReportTests.testPrintEconomyReport` and `CadenceTests` print dashboards
rather than asserting taste — run them after a config change to see the effect.

## Known state, honestly

- 40 tests pass, debug and release.
- Release: **0.518 ms/tick** at 1000 citizens / 453 buildings; distance-field
  rebuild **3.795 ms** over 9216 tiles; save **777 KB** uncompressed JSON.
- Zero idle days across seeds at 500 and 1000 citizens.
- Crisis days: 14–34 per 300, depending on seed.
- **Hunger with a surplus is fixed.** The old 200-day run (seed 2026, 250
  citizens) left ~47 people hungry while farms produced ~372/day against 250
  needed. Farms dumped every unit on the single nearest market, that market
  paid for food it could not sell and went broke, and ten houses were counted
  one step out of range because distance was measured on the floor tile instead
  of the door. `HungerTests` locks the settled city at zero hunger.
