# 2026-11-07 7:26 PM EST — Ios Dev — `cursor/island-events-pacing-b8f6`

Presentation only, off main `6278c09` (PR #27). PR #26 stays merged at `8c4accd` and is not reopened. `PocketRepublicCore` was not edited. The stamp is Eastern time.

## Changed

Island events from the core deck are playable cards instead of a generic Council advice row.

- Title, tone, filled headline, flavor, and why come from `item.islandEvent` and the two cause details (flavor, then headline). The day number stored on the cause is not printed.
- Option buttons are the core's `item.options`. Resolve sends `PlayerIntent.resolveAgendaItem`. A cost above the treasury disables the button and says how much is missing. Effects, including food export, are listed from `AgendaEffect`.
- The card names the lapse option and the last open day. **Not now** only hides the card. It does not take the ignore effect.
- A council row with no `islandEventID` keeps a spoken title, a because-line, and the same affordability rule.
- The closed-screen preview puts a crisis-tier row, including an election, ahead of an island event. On a one-card phone that button is the election. An island event auto-opens only when nothing is blocking the day. Closing the island card leaves the election button in place. While another card is open, the election stays as its own button.
- The Events tab is The Pocket Gazette: days, island headlines and outcomes, and a because-line for ordinary news. An outcome hides only the earlier raise whose event id it answers. A later card with the same headline stays. `agendaItemResolved` for an island card is not shown twice.

Optional day pacing stays in the app.

- The speed menu defaults to Paused. Leisurely is 6 seconds, Steady 3.5, Brisk 2. Each fire calls `Game.advance()` once. There is no second timer and no catch-up batch.
- The clock lives on the app, so a fold or rotation does not create another one. It stops when the scene is not active, when a demolish or new-city confirmation is open, when a crisis blocks the day, and while an island event is still on the agenda. Manual Next Day remains.
- Construction still changes only when a sim-day advances. The inspect line says so.

## Verified

No Swift toolchain, Xcode, simulator, or iPhone here, so this branch was not compiled locally and there are no phone screenshots. Core tests were not re-run. PR #27 measured 100 tests, 0 failures, 159 s debug. The unsigned IPA workflow is unchanged and is the compile check.

There is no app test host in CI, so `DayClockPolicy` (one advance or none, no tick while inactive, held, or paused) is not executed as a test. The rules are the struct in `PocketRepublic/Simulation/DayClock.swift`.

## Regression

Release review of `1396a68`: an election (`tier.crisis`, day 120) can sit beside an island event. The island card auto-opened and, after Not now, the one phone preview was still the island event, so the election that disables Next Day could not be reached from the island sheet. Confirmed in `previewRank` and `openIslandEventIfNeeded`. The clock already refuses `advance` while `blocksAdvance` is true; that guard stays.

The Gazette dropped every later raise whose headline string matched any older outcome. A second carnival in the same district disappeared. Suppression now pairs by event id: an outcome consumes only an earlier unmatched raise with that headline.

`AgendaSheetOrder` and `IslandEventPaper` are readers only. They do not post cards or change a save. `AgendaSheetOrderTests` locks the election above the island event. `IslandEventPaperTests` locks a repeated carnival headline. Generation, the event stream, and the schema are unchanged. A reported core check, not re-run in this pass, passed 6 seeds plus save/load, RNG continuity, and no double resolution. No device test.

## Phone checklist

1. New city. Finished buildings do not pop.
2. Place a house. Foundation immediately. Next Day moves it to scaffold, then to the finished house, once.
3. Choose Steady. Days pass without tapping Next Day. Leave the app. No days pass, and none are caught up on return.
4. Rotate and fold while Steady is selected. The day does not jump several times.
5. When an island event appears, play holds. The card shows title, flavor, headline, why, and real buttons. An unaffordable choice is disabled. Not now leaves it on the agenda.
6. Choose an option. The Gazette shows the headline and the outcome, not a raw flavor-and-day line.
7. Open Cancel construction. Play holds until the dialog closes.
8. Next Day still advances one day while the speed menu says Paused.
9. On a day when an election and an island event are both open, the closed phone shows the election, Next Day stays disabled, and Play does not skip the day. Not now on the island event, if you can reach it from Govern, does not remove the election button.
10. After a carnival has already been answered, a later carnival in the same district still appears in the Gazette.

## Next

Phone playtest. Then the rest of the section 5 deck and `DecreeSpec.flavor`, which are core.
