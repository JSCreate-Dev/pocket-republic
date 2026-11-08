# 2026-11-07 7:10 PM EST — Game Logic — `cursor/core-lifecycle-events-0113`

Core only, branched from main `3df2368` and fast-forwarded onto main `8c4accd` (PR #26, presentation) before the commit. PR #26's app files and `PROGRESS.md` are untouched. November 7 is EST.

## Changed

Demolished buildings were still live. `isOperational` means "construction finished", and demolition only clears the map, so a ghost kept its upkeep, its job openings, its service field, and a door walkers could still be sent to.

- `Building.occupiesGround(on:)` and `Building.isStanding(on:)` are the economy gate. `isOperational`, `daysConstructed`, `daysRequired`, and `stage(in:)` are unchanged, so the construction presentation keeps compiling against the same API.
- Upkeep, wages, taxes, spoilage, production, food shipment, hiring, famine relief, decree food delivery, and both distance fields skip anything that is not standing. `assignWork` drops a citizen whose workplace no longer owns its door and emits `citizenUnemployed` with detail `workplace closed`. `MapBuildingAccess.entrance(of:)` returns nil for a ghost, so a routine planned before the next rebuild does not walk onto rubble. The distance cache itself still rebuilds on the next advance.
- `WorldSnapshot.visibleBuildings` omits records that do not occupy ground. Sites still appear, because they own their tiles.

Market range. On seed 2026 the four hungry doors are a real 21-tile road walk, one step longer because a footprint blocks every tile but the entrance. `maxServiceDistance` for a **new** city is 21. A tile at 22 is still out of range, and the reach preview reads the same config, so the overlay grows by that one step. A save that already stores 20 keeps 20. The map stays 64×64.

Island events. Six cards from design section 5, posted as ordinary agenda rows and applied by `RepublicState.apply`. No second framework and no model call.

- Carnival, celebrity visit, smuggler ring, fishing bonanza, generous expat, foreign trade offer. Good, bad, and weird are all in the deck. Hurricane, strike, blight, the rest of the 14, and the rare one-offs are not.
- The row's `kind` stays `.advisoryTradeoff` and its `tier` stays `.advisory`. `AgendaKind` did not grow, because `DecreeBoard.councilTitle` and `IslandView.cityTitle` switch on it exhaustively. `islandEventID` is the link. Ignoring the card, or letting it expire, applies the free option only. Smugglers' lapse is corruption +2. The others do not move the treasury.
- Rolls use `IslandEventLog.rng`, derived from `worldSeed` and stored on the republic. The wellbeing RNG is not drawn. The log is nil until the first advanced day, and nil optionals are omitted from the JSON, so a schema 3 save from before this change still decodes and still matches its checksum. `schemaVersion` stays 3. There is no migration.
- `AgendaEffect.foodExport` removes food from standing markets and records `foodExported`. If the stalls are short, the coin scales with the crates that actually ship.

## How the app should read an island event

The current screens already show the card and the gazette line. A later presentation pass can replace the generic titles without a core change.

**While it is on the agenda.** `item.islandEventID != nil`, or `item.islandEvent`, which is the `EventDeck` entry.

| What to show | Where it lives |
|---|---|
| Title | `item.islandEvent?.title` |
| Tone (good / bad / weird) | `item.islandEvent?.tone` |
| Flavor, the sentence under the title | `item.causes.first?.detail` (also `spec.flavor`) |
| Filled headline, district already substituted | `item.causes.dropFirst().first?.detail` |
| Why it fired | `item.islandEvent?.why` |
| Buttons | `item.options`. The label already states the tradeoff. Send `PlayerIntent.resolveAgendaItem(item.id, option: option.id)` |
| If they never answer | the option whose id is `spec.ifIgnored`. Expiry sends it. Do not also send it from "Not now" unless that button is meant to take the ignore effect |

`item.kind.councilTitle` and `item.kind.cityTitle` both say **Council advice** until those switches branch on `islandEventID`. The cause row prints `detail: value`, and the value is the day the card was raised, so the flavor currently shows with a trailing day number.

**In the Events list.** `EventKind.islandEvent` already becomes "Island Event" from `rawValue`. The first cause's `detail` is the headline when the card is raised, and `headline. outcome` after the choice. `magnitude` is the spec id on the way in and the option id on the way out.

**Do not add `AgendaKind.islandEvent`** unless both exhaustive switches are updated in the same change. The core will keep posting `.advisoryTradeoff`.

Construction stages, build times, and `advanceConstruction` were not retuned.

## Verified

`swift test` in `PocketRepublicCore` with Swift 6.2 (swift-6.2-RELEASE) on Linux, debug:

**100 tests, 0 failures, 159 s.**

That is the previous 88 plus 12: 3 lifecycle, 8 island-event, 1 service-cap. The new tests cover ghost upkeep, a workplace that must not hire or pay, a demolished market and clinic dropping out of the distance fields and out of `WalkerRoutine`, deck bounds, a rejected option and an unaffordable gala, food export at full price and at half when the stall is short, lapse applying only the free option, one card at a time, the repeat window, save/load of the event stream, two seeds diverging, the wellbeing RNG staying put when the event chance is 0, and a fresh save omitting `islandEventLog`, `eventPacing`, `foodExport`, and `islandEventID`.

Seed 2026, 250 citizens, 200 days, from `EconomyReportTests`: food 476 produced against 250 needed (ratio 1.90), **hungry 0**, every district at 100% market coverage. North Fields unrest was 83 with market coverage still 100. Debug timing, not the core README's release figure (the same run measured about 13 ms/tick at 1000 citizens). No iPhone.

**Build iOS IPA** on `30e6b89` succeeded: [run 42427776978](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/42427776978). The core test step and the unsigned device build both passed. Signed upload was skipped (no Apple secrets).

## Not done

- The other eight section 5 cards, the rare one-offs, citizen minds, and any model hook.
- `DecreeSpec.flavor`. PR #26 already leaves that line off the decree card.
- Crisis-tier events. Nothing new blocks **Next Day**.
- A 96×96 map.
- `PROGRESS.md`. It still describes PR #26.
