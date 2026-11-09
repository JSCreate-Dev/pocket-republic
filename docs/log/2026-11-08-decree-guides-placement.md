# Decree guidance and precision placement

2026-11-08 16:40 EST. Role Ios Dev. Branch ui/decree-guides-and-precision-placement; depends on standing-decree core changes atop 2741dbe.

Cards now explain why/when to use each decree, its precise effects, cooldown, and lasting versus instant scope. Free civic wage has future payroll impact; tax holiday has no automatic expiry; rationing purchases stock rather than adding an ongoing ration system; curfew presently affects meters, not walker schedules. Confirmation revalidates current conditions and receipts/errors explain outcome. Existing cost/faction effects retained. Tax stepper now covers core's 0...80 range.

Placement previews finished art, marks validated road entrance, shows footprint/budget and provides four 44pt single-tile adjustments using the same placement validator. Confirm/Cancel move outside the detail scroller into the dock. Construction still begins at the proper foundation after confirmation.

Verified: Swift 6.2 parser on all four changed app files; core dependency 160 tests pass. Xcode typecheck, native confirmations, preview hit-testing, narrow/wide/folded dock layout, golden entrance marker and physical finger behavior remain unverified.

Rotation feasibility: do not add a camera spin that turns the painted buildings sideways. Real quarter-turn views require transformed map projection/inverse hit testing, viewport/camera/depth ordering, rotated road/shore masks and directional building art. Building rotation additionally needs saved optional orientation, width/depth swaps for non-square footprints, placement/entrance/dock-shore rules and oriented art. These need a separate feature pass with regression tests; no rotate button is claimed here.
