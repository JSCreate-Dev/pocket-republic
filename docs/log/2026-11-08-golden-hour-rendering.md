# 2026-11-08 12:52 PM EST — Ios Dev — ui/golden-hour-rendering

Base 678a678, following c254263 (autoplay/panels) and dbf0033 (tested prior integration). Activates the approved house asset if available, with legacy fallback. Catalog imagery uses the same mapping. Adds cached blurred directional ground shadows under visible buildings, stage-sensitive dimensions, warm ground grading, staggered existing water frames, and a gentler night wash. Diagnostic overlays hide shadows/night wash; water action setup respects the current Reduce Motion setting.

No new gameplay rules, footprint/anchor sizes, collision, pathing or save fields. Existing cities get the visual/clock fixes. Other buildings still use old art, so this is a first production slice and not a completed AAA conversion.

Checks: original generated house and 3x export visually inspected; exact 1x/2x/3x dimensions and RGBA/corner transparency validated. Clock policy harness passes. Swift 6.2 parser on all changed app files; whitespace clean. The full unchanged core suite: 147 release tests, zero failures, 5.307 seconds. No UIKit screenshot, Xcode typecheck, actual Timer/gesture test or frame-rate result.

Claude: apply the combined patch to dbf0033 or rebase over newer integration changes, run the clock policy harness and core suite, compile the IPA and return exact SHA/artifact. Check first-attach autoplay, real pause/resume, blocking confirmations, full-sheet scrolling, warm house scale/anchor, stage shadows, Normal/diagnostic switch, water motion and frame rate. Do not silently alter core balance or claim the entire concept scene is now present.
