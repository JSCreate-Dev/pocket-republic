# Phone layout and opening advice

- Date: 2026-11-10, Eastern time (EST; November).
- Role: Ios Dev.
- Branch: ui/phone-layout-fix.
- Base: integration/settlement-and-polish at 139960ac38c6e18f3228833fdb3836ba74e1bc38.
- Evidence: Jordan’s portrait screenshot; bottom navigation obscures time controls and the HUD hides the town. This is a repair to the previous navigation pass.
- Change: allocate navigation below content, measure intrinsic dock and HUD heights, reserve visible camera space, remove the persistent roadmap row in favor of an island-menu entry, and count only additional jobs needed in day-zero advice.
- Validation: Swift 6.2 app parsing; actual viewport-bounds scenarios; actual IslandPrompt preview/shortage/construction/housing/food/read-only checks. No core source change or full core-suite rerun.
- Remaining: Xcode typecheck/build and actual phone landscape/portrait/fold, Dynamic Type and VoiceOver. Verify the dock’s complete time row, camera focus preservation and sheets. No IPA or main merge produced here.
