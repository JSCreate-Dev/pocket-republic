# 2026-10-25 — Footprint hunger range

Branch: `cursor/footprint-hunger-range-68a0`

## What changed

`HungerTests.testSurplusDoesNotLeaveCitizensHungry` failed on main (`4a7bd36`, footprints plus the hunger fix). Seed 2026 left 22 of 250 hungry; seed 11 left 16. Food was in surplus. Walker commit `85a4215` is not on main (it sits on the pre-footprint hunger branch) and that same test passes there.

Multi-tile farms on the fertile patches ship a full crew's yield. `distributeFood` finished one farm, demand and surplus, before the next. The lowest-index farms sold the whole daily budget. Around the twelfth farm every market till was down to its wage reserve, so later farms never sold a unit. Their crews worked full barns for no pay and could not buy food that was already on the shelf.

Farms now take turns: one unit per farm per pass, shortfall first (even when the till cannot prepay), then paid surplus. Wage cash is still withheld. A market's door is still its entrance.

Seed 2026 still has four households whose door is 21 road tiles from the nearest market. `maxServiceDistance` is 20. Footprints block every tile but the entrance, so that walk is one step longer than when a building was a single passable tile. Those four are outside the cap; they are not the surplus bug. The test now requires nobody inside the cap to be hungry, and locks those four as the only exception. Seed 11 still requires zero.

## State

`swift test` in `PocketRepublicCore` (Swift 6.2, Linux): 66 tests, 0 failures. No iPhone run. `PROGRESS.md` was not edited.
