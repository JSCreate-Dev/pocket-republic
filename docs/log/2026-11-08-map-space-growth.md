# Map space and growth guidance

2026-11-08 08:20 EST (09:20 EDT). Role Ios Dev; branch ui/map-space-and-growth; base settlement-outlook core change atop 6b02991.

Road/bare tile inspection no longer creates a large empty bottom panel in map-first layouts. A dismissible floating tile chip sits above the dock; split layouts keep existing tile content. Growth guidance exposes a full-height reading sheet with simultaneous blockers. Housing and happiness can both appear in the compact HUD, and hungry-resident alerts also open the diagnostic view. Cream-screen navigation bars request light appearance/background for readable titles.

Verified: Swift 6.2 app syntax parser, actual DayClock policy harness, git diff --check. Core release 154 tests pass. Xcode/UIKit runtime, iPhone small/wide layout, chip wrapping, camera framing and navigation contrast still need Claude/device checks. No new art, terrain regeneration or save reset.
