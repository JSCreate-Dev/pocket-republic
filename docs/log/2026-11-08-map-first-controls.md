# 2026-11-08 10:15 PM EST — Ios Dev — `cursor/map-first-controls-b8f6`

Off main `1bab3cf` (PR #29). App controls only. The core, saves, origins, and the season rules are unchanged. PR #10, PR #25, and PR #30 were not merged or closed.

## What changed

A wide flat window no longer splits the city into a map half and an empty management half. The map is full width on a phone and on that wide window. Inspect, Build, Road, pause, and Next Day sit in a short dock.

Build is a catalog: Homes, Food, Work, Services. The ghost, the price, and the existing rejection sentence show before Place. Cancel drops the tool. Service reach uses `maxServiceDistance` and only while the building is open, or as the placement preview.

Road mode records a stroke of at most 24 tiles. Two fingers pan and pinch in one gesture: `MapCameraNudge` subtracts the midpoint delta, then scales around that midpoint, using the same pinch ratio as before (previous distance / current distance). Once a second finger is down, the gesture stays a navigation until every finger lifts, so a finger-count change does not append a road tile. Pave commits each tile through `buildRoad` and stops when the core rejects one.

Leaving Island for People, Govern, or the Gazette sets the tool back to Inspect, closes the catalog, clears the road draft and the placement ghost, and releases the `build` and `catalog` clock tokens. A demolish confirmation and Start New City keep their own tokens. The scene object is not recreated, so the camera stays. `MapGestureTests` locks that policy. Those tests do not drive SwiftUI or SpriteKit.

An election still opens and blocks the day. An island event is a button. The clock still refuses to tick while that event is on the agenda, while a crisis is up, or while a build tool or the catalog is open.

## Phone checklist

No iPhone and no simulator run is claimed.

- Wide window: the map is full width and the dock is a short bar, not a blank half pane.
- Build, choose a house, read the price and any rejection, Place or Cancel.
- Road: one finger adds tiles. Two fingers pan and pinch without adding tiles. Lift one finger and the other does not extend the road. Pave or Cancel.
- Switch to People and back. The tool is Inspect, the draft is gone, and Play is not stuck on the build hold. A crisis still blocks the day. The camera has not jumped.
- An election opens on the island. An island event is a button. Demolish still asks, and still says the money is not refunded.

## Not claimed

The unsigned IPA workflow is the device compile. No new simulation, traffic, or zoning. Core tests do not exercise the real SwiftUI or SpriteKit gestures.
