# 2026-11-07 9:38 PM EST — Ios Dev — `cursor/republic-season-b8f6`

Off main `744e692` (PR #28). Core, tests, and the island UI. Generation of elections and island events is unchanged. PR #10 and PR #25 were not closed.

## Design

One season, three beats, stored as optional `republicSeason` so a schema 3 save from before this change still decodes and still matches `stateHash()`.

1. **Break ground.** Open a building the player placed (`daysRequired > 0` and still standing). Seal the charter once: $120 enters from outside the books. Worldgen buildings do not qualify.
2. **One compact, $280.** Granary: +1 food per farm worker, and +$1 upkeep on each private workplace. Harbor: +$2 per workshop or dock worker, and food spoilage +4 points. The other compact is rejected, including after save and load.
3. **Settled.** Two kinds of player buildings open, food still stored, mean happiness at least 40, day at least 5. Legitimacy +4 once, and the unemployment happiness penalty stays 1 lower.

The island shows the current beat without covering the map or Next Day. A claim plays one haptic and a line. Load and resize do not replay it. The season does not block the day.

## Tests

`SeasonTests` covers a not-ready charter, the grant exactly once, a short treasury, exclusive compacts, save/load, granary food and upkeep, harbor coin and spoilage, a missing `republicSeason` key, and a scripted playthrough from a new city through settled. The trace is printed as `SEASON ...`.

## Not claimed

No iPhone and no simulator. The unsigned IPA workflow is unchanged and is the device compile.

## 2026-11-07 10:05 PM EST — same branch, origins and the charter line

The charter card on `c8bcdcf` said the seal cost $120. `claimFounding` pays $120 into the treasury. The ready line, the button, and the banner now say the treasury receives $120, then the player chooses one compact. Season rules are otherwise unchanged.

**Start New City** now asks before it replaces the city. Ordinary leaves `origin` nil. Three origins stamp once inside `WorldGenerator.generate` and are read again each tick:

- Letters of Marque: corruption 28, legitimacy 52, +$400, merchants +6, officials −6. Later days: +$1 per dock or workshop worker, spoilage +2. Dilemma: pay the crew ($100, corruption −6, legitimacy +5, labourers +4) or keep a cut (+$140, corruption +5, merchants +5, landless −3).
- The General's Square: corruption 16, legitimacy 78, officials +8, labourers −8, landless −6. Later days: civic upkeep −$1 (floor 0), unemployment penalty +1. Dilemma: take the portraits down (legitimacy −5, unrest +3, labourers +6, landless +4, officials −5) or leave the name (legitimacy +4, officials +6, labourers −4).
- The Common Pot: −$600 when the treasury can cover it, +40 food on each standing market recorded as imported, labourers +4, merchants −4. Later days: spoilage −2 (floor 0), export coin −$1 per worker, pay clamped at 0. Dilemma: open the stores (50 food, landless +5, merchants −3) or sell a share (+$160, merchants +5, landless −4).

The dilemma is advisory, ranked under a crisis and over an island event, and it does not open itself on top of an election. It expires on day 6 with ignore cost 0, so a lapse only removes the card. The compact is still chosen after the charter. `OriginTests` covers the three openings, replay, a nil save with no `origin` key, one resolution, spoilage and civic upkeep, a compact still available after an origin, and a short path that seals the charter for each origin. The trace is printed as `ORIGIN ...`.

No iPhone and no simulator. The unsigned IPA workflow is unchanged. Push CI [run 42440421955](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/42440421955) executed 116 tests, 0 failures, in 137.683 seconds. The unsigned IPA artifact is `PocketRepublic-unsigned-ipa` id 13600619355, 5453618 bytes, expires 2027-02-06T02:53:42Z. Signed upload was skipped. The `ORIGIN` trace on seed 2026: marque day 0 treasury 4400 food 540, day 2 treasury 6485 food 663 charter sealed; parade day 0 treasury 4000 food 540, day 2 treasury 6192 food 688 charter sealed; common pot day 0 treasury 3400 food 900, day 2 treasury 5560 food 1101 charter sealed.
