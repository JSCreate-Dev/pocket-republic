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
