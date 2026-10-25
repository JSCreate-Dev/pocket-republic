# Pocket Republic iOS project

Open `PocketRepublic.xcodeproj` in Xcode 16.4 or later. The app targets iOS 17+ and links the local `PocketRepublicCore` Swift package. `PocketRepublicCore` has no SwiftUI, Date, or UserDefaults dependency; `Game` adapts it to SwiftUI, wall-clock catch-up, and local saving.

## Build an unsigned IPA

With this directory at the root of a GitHub repository, a push or manual dispatch runs `.github/workflows/unsigned-ipa.yml` on a macOS 15 runner with Xcode 16.4. The workflow runs core tests, builds the iOS device app with signing disabled, then uploads `PocketRepublic-unsigned.ipa` and its SHA-256 hash as an artifact. Extract the artifact ZIP before using the IPA in an on-device signing app. This workflow has not run yet, so no compiled IPA is available.

The bundle ID is currently the placeholder `com.example.PocketRepublic`. Change it if your signing method requires a different ID. The workflow does not sign or install the app. An iPhone alone cannot compile the SwiftUI project; compilation needs Xcode on macOS or macOS CI.

## Saves

New saves use schema version 2, a stable `CitizenID`, and stored `worldSeed` and `rngState`. An unreadable or older save is preserved and the app stops changes until **Restart Republic** is explicitly chosen. The v0.1 source was never built, and this project does not migrate its hypothetical version 1 saves.

The original v0.1 source and spec remain in `/home/jsmith/projects/pocket-republic/v0.1/`. Households, factions, SpriteKit, WidgetKit, and other P1 work remain backlog items.
