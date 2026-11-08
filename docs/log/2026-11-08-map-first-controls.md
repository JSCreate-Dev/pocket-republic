# 2026-11-08 10:15 PM EST — Ios Dev — `cursor/map-first-controls-b8f6`

Off main `1bab3cf` (PR #29). App controls only. The core, saves, origins, and the season rules are unchanged. PR #10, PR #25, and PR #30 were not merged or closed.

## What changed

A wide flat window no longer splits the city into a map half and an empty management half. The map is full width on a phone and on that wide window. Inspect, Build, Road, pause, and Next Day sit in a short dock.

Build is a catalog: Homes, Food, Work, Services. The ghost, the price, and the existing rejection sentence show before Place. Cancel drops the tool. Service reach uses `maxServiceDistance` and only while the building is open, or as the placement preview.

Road mode records a stroke of at most 24 tiles. Two fingers move the map. Pave commits each tile through `buildRoad` and stops when the core rejects one.

An election still opens and blocks the day. An island event is a button. The clock still refuses to tick while that event is on the agenda, while a crisis is up, or while a build tool or the catalog is open.

## Not claimed

No iPhone and no simulator. The unsigned IPA workflow is unchanged and is the device compile. No new simulation, traffic, or zoning.
