# 2026-11-07 6:48 PM EST — Ios Dev — `cursor/construction-presentation-b8f6`

Presentation only, off main `3df2368` (PR #24). `PocketRepublicCore` was not edited. November 7 is EST; the older notes say EDT because they were written in October.

## Changed

The island draws the construction stage the core already stores.

- `IslandScene` picks `site_foundation_*` or `site_scaffold_*` from the footprint shape, and `building_<kind>` when `stage(in:)` is `.complete`. Anchors stay `(0.5, 0)`. 3×2 and 2×3 stay on their own imagesets. A missing image draws a same-size placeholder.
- A building placed during play lands with a short bounce and a dust puff. Foundation to scaffold cross-fades in about 0.2 seconds. Opening plays one pop (scale 0.85 → 1.06 → 1.00), a dust ring, and one light haptic. The scene remembers the stage it has shown. The first picture of a city or a loaded save is quiet, so worldgen buildings and a save do not pop on every redraw. Panning and the extra render from saving do not replay the pop.
- A scaffold gets two decorative builders and a pennant. They are not citizens.
- The ghost is the foundation when the build takes at least one day. A service reach preview says `Reach when it opens, in N days`.
- The inspect panel paints the core's construction status as a timber banner, shows the progress percent, says the bar moves when Next Day is pressed, labels demolish **Cancel construction** with no refund, and notes that the operating mode takes effect when the building opens. `InspectTone.progress` was not added.
- Closed portrait and landscape use a full-width map and a draggable bottom sheet, adapted from open PR #25. Next Day stays pinned. A wide window splits map and controls. Book and laptop folds still follow `reservedRegions`. Tent view is an explicit outer-landscape choice. PR #25 was not pushed, closed, or merged.
- People are cards. Govern shows decree cards from `DecreeCatalogue` (cost or Free, shortfall, faction arrows, effect lines). **Issue decree** sends the enact option. **Not now** only closes the card. Flavor is omitted because `DecreeSpec` has none. The Events tab and the gazette were left alone. PR #10's core files were not copied. PR #10 was not pushed, closed, or merged.

The sim day still advances only when the player presses Next Day or Advance One Day. Scaffold motion does not increment `daysConstructed`.

## Verified

No Swift toolchain, Xcode, iOS simulator, or iPhone in this environment. `swift test` was not run. Core sources were not modified, so the PR #24 suite (88 tests, 0 failures, debug, on `3df2368`) is the last measurement. Main's unsigned IPA for `3df2368` is [run 40244319564](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/40244319564). This branch's compile is CI's job. PNG sizes of the eight site imagesets match section 7.6.

## Not done

- Phone playtest of stages, the pop, the sheet, and decrees.
- `InspectTone.progress` and `DecreeSpec.flavor`, both core additions. The app does not need the first one to draw the banner.
- Gazette and event grouping. Wait for the core event pass.
- Sound assets. Placement and the pop have a haptic and dust only.
- PR #10 and PR #25 remain open on their own branches.

## Next

Playtest checklist is in the pull request. Then the gazette, after flavor text and causes exist on the core.
