# 2026-10-25 7:24 PM EDT — Ios Dev — `swift/duo-posture-layouts`

Branch: `swift/duo-posture-layouts` (PR pending).

## Changed

The island now renders distinct display configurations. A single outer display keeps a full-width map with controls in a half-height bottom panel that drags larger; the map camera frames the uncovered region. A wide flat inner display and an active book or laptop division give the map and controls separate panes. In outer landscape, a Tent view button switches to a map-first layout with a slim dock that opens the controls. The app uses this explicit control because the outer display does not provide a distinct tent posture signal. The same `IslandScene` and view state survive layout changes, keeping the camera focus and selection. Core and saves are untouched.

## Verified

`git diff --check` passed. [Build iOS IPA run 40244633312](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/40244633312) passed the core suite, unsigned iOS device build, and IPA upload. On-device posture behavior is pending a Duo playtest. The Local VM has no Swift/Xcode toolchain or iPhone simulator.

## Next

Review the PR workflow and test single portrait, single landscape, fully open, book fold, laptop fold, and the manual tent view on a Duo. The player-selected map/inspect/agenda/stats pane picker remains separate next-round work.
