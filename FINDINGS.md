# P0 implementation and verification status

> **Historical.** This is the Oct 24, 2026 extraction note. The living handoff is [PROGRESS.md](PROGRESS.md). Read that file before acting on anything below. Later commits have superseded parts of this page, including the spatial save, the SpriteKit island, factions, and the CI runner.



- Extracted the deterministic day and decision rules into the local `PocketRepublicCore` Swift package. It contains `CitizenID`, `Citizen`, `Republic`, `SeededRNG`, `Engine`, and `SaveCodec` without SwiftUI, Date, or UserDefaults use.
- Stored a separate immutable `worldSeed` and advancing `rngState` in `Republic`. Initial citizen IDs are stable integers. The engine saves its RNG state after each day, and its tests cover replay, save/resume, pending-crisis pauses, and the same-day corruption ordering case.
- Moved wall-clock catch-up and `UserDefaults` access to the app `Game` adapter. Saves have schema version 2. Missing saves create a new republic; corrupt or older saves are preserved and block changes until an explicit restart. No automatic overwrite occurs on a decode failure.
- Added GitHub Actions macOS CI for core tests and an unsigned iOS device IPA. This has not run because a repository destination is still unspecified and GitHub access is unavailable to this thread. The browser remains at Google sign-in; automatic approval review rejected sending a live GitHub token into an unsandboxed terminal.
- After simulation review, clamped offline elapsed time before `Int` conversion, rejected unknown saved crises and invalid choices, and stopped already-criminal citizens from generating repeated discovery events. The pure catch-up conversion has extreme-value tests.

## P1 backlog

Households, relationships, businesses, prices, employment, migration, factions, election cycle, policing, courts, persistent event causality, SpriteKit renderer, widget, and full save migration/recovery remain future work. Food production is fixed below consumption in v0.1, so food depletes even with policy changes; redesigning that economy remains backlog rather than an unreviewed P0 tweak.

## Verification limits

Static checks can verify files, package references, and workflow structure here. There is no local Swift compiler, Xcode, or iOS SDK; no core tests, Apple SDK build, device signing, or installation have run. The first macOS CI run is the compiler gate. Signing is intended to happen on the owner's device after downloading the unsigned IPA.
