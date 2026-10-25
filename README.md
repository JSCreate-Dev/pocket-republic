# Pocket Republic iOS project

Open `PocketRepublic.xcodeproj` in Xcode 16.4 or later. The app targets iOS 17+ and links the local `PocketRepublicCore` Swift package. This package is the spatial city simulation from `/home/jsmith/projects/pocket-republic/core/` (copied here so the Xcode project is self-contained). The app sends `PlayerIntent` values to `SimulationEngine` and draws a read-only `WorldSnapshot` in SpriteKit.

The island tab now renders terrain, roads, buildings, camera pan/zoom, placement tools, a small moving crowd, and cosmetic day/night lighting. The simple colored building blocks are integration art, not final sprites. The simulation only advances when **Advance One Day** is pressed; animated walkers and lighting never advance or randomize the core.

## Build an unsigned IPA

With this directory at the root of a GitHub repository, a push or manual dispatch runs `.github/workflows/unsigned-ipa.yml` on a macOS 15 runner with Xcode 16.4. The workflow runs core tests, builds the iOS device app with signing disabled, then uploads `PocketRepublic-unsigned.ipa` and its SHA-256 hash as an artifact. Extract the artifact ZIP before using the IPA in an on-device signing app. An actual Apple SDK build and on-device run of this spatial integration are still required.

The bundle ID is currently the placeholder `com.example.PocketRepublic`. Change it if your signing method requires a different ID. The workflow does not sign or install the app. An iPhone alone cannot compile the SwiftUI project; compilation needs Xcode on macOS or macOS CI.

## Saves

The spatial city uses `Application Support/PocketRepublic/spatial-v1.json`, written atomically with a versioned envelope and state checksum. A corrupt or unsupported spatial save is preserved until **Start New City** is explicitly chosen. The earlier `pocket.republic.save.v1` UserDefaults save remains untouched; the new simulation starts a separate city because its world, economy, and citizen schemas differ.

The original v0.1 source and spec remain in `/home/jsmith/projects/pocket-republic/v0.1/`. The copied core has passed 40 tests under Linux Swift 6.2. That does not verify iOS compilation, linking, touch handling, or frame rate.
