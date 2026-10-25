# P0 implementation and verification status

- Extracted the deterministic day and decision rules into the local `PocketRepublicCore` Swift package. It contains `CitizenID`, `Citizen`, `Republic`, `SeededRNG`, `Engine`, and `SaveCodec` without SwiftUI, Date, or UserDefaults use.
- Stored a separate immutable `worldSeed` and advancing `rngState` in `Republic`. Initial citizen IDs are stable integers. The engine saves its RNG state after each day, and its tests cover replay, save/resume, pending-crisis pauses, and the same-day corruption ordering case.
- Moved wall-clock catch-up and `UserDefaults` access to the app `Game` adapter. Saves have schema version 2. Missing saves create a new republic; corrupt or older saves are preserved and block changes until an explicit restart. No automatic overwrite occurs on a decode failure.
- Added GitHub Actions macOS CI for core tests and an unsigned iOS device IPA. This has not been run because GitHub authentication and a repository destination are unavailable in this bot's browser.

## P1 backlog

Households, relationships, businesses, prices, employment, migration, factions, election cycle, policing, courts, persistent event causality, SpriteKit renderer, widget, and full save migration/recovery remain future work.

## Verification limits

Static checks can verify files, package references, and workflow structure here. There is no local Swift compiler, Xcode, or iOS SDK; no core tests, Apple SDK build, device signing, or installation have run. The first macOS CI run is the compiler gate. Signing is intended to happen on the owner's device after downloading the unsigned IPA.
