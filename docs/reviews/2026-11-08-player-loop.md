# Player-loop review — November 8

Reviewed the pending complete handoff plus fresh start, progression gates, saving boundaries, placement/reset interaction, clock policy, visual routines, map diagnostics and presentation lifecycle. This is source/core verification, not a full physical playtest.

## Findings addressed

- First-day guidance: raw WorldGen has 13 slots for 16 residents before hiring. Suggest missing capacity rather than misleading road/hiring work; acknowledge pending construction instead of suggesting duplicates.
- Feedback: observed day boundaries now yield exact net deltas and new opening counts. Same-day edits/new seeds cannot fabricate a day report; purchases are explicitly included, not called profit.
- Agency: goal actions only open existing tools/readers and never grant or spend resources. Legacy saves get no fake locked-tree counters.
- Presentation: a short optional in-engine camera/caption opening gives the island context, while the main map remains the actual world. Clock pace survives the bounded hold and all exits release it.
- Lifecycle: new islands now clear stale build/road/decision selections and queued journal actions. Tour start checks live foreground state, blocks underlying map input in all postures, and guards deferred map callbacks; changing accessibility settings cannot restart camera motion from an older task capture.
- Motion: one small cached plume per active-looking workshop and a finite opening ripple; diagnostic/accessibility gates stop new decorative movement and existing pops/crew where appropriate.

## Evidence

174 release core tests pass (seven added), 8.192s. Extracted real tour-policy harness passes auto-start/seen/disabled/blocked and finish/skip/cancel/restart/hold cases. Existing real decree-reading, clock/light and asset checks pass; all app files parse. All prior art/interactions carried forward byte-for-byte before this change.

## Practical limits / next validation

- Xcode typechecking/asset build and real iPhone/folded/large-text/VoiceOver interaction still required. Check tour camera framing/exit restoration, particles, no accidental placements, action queues, old saves and frame rate. Pure policy tests do not prove native timer or UI lifecycle behavior.
- No prerecorded movie, voice/music or new full economic subsystem. The existing decorative citizen/light clocks remain separate from economic ticks.
- A four-node roadmap and nine building kinds still limit longer-term variety. New guidance makes existing decisions clearer; sustained production/trade/district depth needs later designed mechanics and balance tests.
- True rotation still needs directional art, projection/hit testing/depth/viewport/road masks and oriented saved footprints. No fake screen-spin control was added.
