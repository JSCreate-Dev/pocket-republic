# 2026-10-25 2:25 PM EDT — Ios Dev — `swift/walker-phase-stagger`

Branch: `swift/walker-phase-stagger` (PR pending).

## Changed

The scene derives a stable offset of 0–1.5 seconds from each citizen ID and applies it to walker pose and moving-frame selection. Citizens now cross routine hour boundaries at different visual times. Idle walkers remain on frame 0, and hungry tint still uses `daysHungry`. `WalkerRoutine.plan`, core state, saves, and the shared visual day clock are unchanged. `PROGRESS.md` Current state now reflects PR #17 and this branch.

## Verified

The diff check passed. A calculation for citizen IDs 0–23 yielded 24 distinct visual offsets spanning 0–1.471 seconds. The code path uses the same local time for pose and moving frames, and leaves the tint branch unchanged. This Local VM has no Swift or Xcode toolchain, and no iPhone or simulator attached; an iOS build and visual/device check remain pending.

## Next

Review the PR workflow's iOS build, then playtest a crowded view on iPhone Duo for natural stagger and texture/tint appearance.
