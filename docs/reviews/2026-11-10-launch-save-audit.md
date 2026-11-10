# Launch, persistence and visual handoff audit

## Gaps closed

1. Game initialization did synchronous disk decoding/world generation before UI. It now starts with an unsaved placeholder and prepares the real city off actor after the launch screen mounts. Main/timer do not start for that placeholder.
2. New City deleted the selected file before writing its replacement. It now prepares/validates/writes first, then publishes. A failed operation keeps the selected in-memory city and primary bytes.
3. Failed autosaves only offered starting over. Retry Save now retains current unsaved changes; Retry Load is a separate read-recovery action and cannot accidentally persist the placeholder.
4. No player-visible backup recovery existed. One verified rolling backup has day/residents/file date, explicit replacement confirmation, preserved current bytes and no automatic rollback. No-op saves leave the older recovery point intact. Invalid backup bytes are preserved before rotation.
5. Restoring the same seed could retain future selections and journal history. A new session id rebuilds the map/UI on successful restore/reload/replacement.
6. The simulation/tour could begin while the map was still preparing. A scene-first-frame callback holds the clock and delays the tour; cancel/back and session guards protect stale completion.
7. Launch had no coherent visual entry. A brass/charcoal/ocean screen composes actual golden house/hall/farm assets with flexible widths, compact-height sizing, scroll fallback and real stage labels. No external/fake gameplay imagery.

## Evidence and boundaries

The real Game implementation and Foundation codec/repository compile/run in the save check using only a minimal Combine shim; the storage logic is not reimplemented in a mock. Real temp-file checks cover fresh/verified/corrupt/missing files, bad backup, no-op rotation, explicit restore, failed replacement, unsaved retry and session reset. Core source is identical to the previous 193 passing tests. Existing model/policy and asset checks pass. No iOS SDK or actual publication/render lifecycle is verified here.

The app still has one island plus one rolling backup, no multi-slot list/import/cloud/prototype migration. A backup can be one tick older. Preserved recovery files are internal safety copies, not an exposed save-history browser. Old binaries need not understand newer event kinds. Autosaves remain synchronous and should be profiled on device. No fake percentage, timed delay or claim of a custom native OS launch storyboard is made.

## Claude device checklist

- Cold launch a genuine old spatial save and first launch without one; no placeholder island or simulation days before Continue. Confirm the loaded day/date, Continue and first frame/tour order.
- Cancel map opening and retry. Background/foreground during loading/generation/restoration and return from Govern. No stale callbacks may release the wrong launch token.
- Corrupt/missing primary with valid/invalid/no backup; never overwrite on failed read. Restore only the displayed verified point after confirmation. Test same seed/day restore clears map selections/journal.
- Simulate storage failure: accepted unsaved changes must offer Retry Save, preserve in-memory state and block play; New City/restore failure must not publish a new selection or delete the primary. Repair storage and retry.
- Verify new-city charter/cancel/disabled-during-write flow, normal save timestamps/no-op behavior, one rolling backup, legacy prototype untouched, old/new saves reopen.
- Review art/contrast at narrow and landscape sizes, fold postures, large text/VoiceOver/Reduce Motion, actual Combine publication and save-time/frame-rate performance.
