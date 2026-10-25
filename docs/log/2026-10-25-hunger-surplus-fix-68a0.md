# 2026-10-25 — Hunger surplus fix

Branch: `cursor/hunger-surplus-fix-68a0`

## What changed

A 120-day unattended city (seed 2026, 250 citizens) was leaving about 47 people hungry while farms produced roughly 372 food a day against 250 needed, and markets held thousands of units.

Three mechanisms stacked:

- Farms shipped their whole output to the single nearest market (straight-line distance). That market hoarded food and others sold out, so shoppers at the empty markets went hungry.
- The oversupplied market paid the farm up front for every unit, including food nobody bought. Its till ran dry, so it stopped paying shopkeepers. Farms that kept delivering into a broke market were not paid and stopped paying farmers. Those workers had no coins in front of full shelves (about 19 employed people: farmers and shopkeepers).
- Ten houses sat at road distance 21. `maxServiceDistance` is 20. Their only door is a road tile at distance 20, but the check used the floor tile, one step inside, so they were treated as unreachable every day.

`distributeFood` now fills each market up to a day's demand for the people who shop there, even when the till cannot prepay (sales cash arrives later in the tick). Anything left over is sold only to markets that can pay without spending wage money. `shoppingMarket` / `marketServiceDistance` measure reach at the door (the floor tile or an adjacent road, whichever is closer). Feeding, market coverage, faction tallies, and the no-market happiness penalty all use that same door.

Seed 555 no longer raises a crisis once this hunger is gone, so `testCrisisResolutionsDoNotMintMoney` follows seed 314, which still raises district uprisings.

## State

`swift test` in `PocketRepublicCore` (Swift 6.2, Linux): 42 tests, 0 failures. `HungerTests` covers seeds 2026 and 11 for 120 days: production and stores stay above one day of demand, and from day 40 on nobody is hungry. No iPhone run. `PROGRESS.md` was not edited.

## Next

Walker routines are a separate branch: multi-stop days (home, work, market, home) aimed at entrance tiles through a small access interface, without rewriting `isPassable`. The footprint core (sizes, occupancy, `isPassable`) is still a different PR and should merge before the renderer follows these routes.
