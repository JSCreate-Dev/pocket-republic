# Pocket Republic iOS project

Open `PocketRepublic.xcodeproj` in Xcode 27.1 or later. The app targets iOS 17+ and links the local `PocketRepublicCore` Swift package. This package is the spatial city simulation from `/home/jsmith/projects/pocket-republic/core/` (copied here so the Xcode project is self-contained). The app sends `PlayerIntent` values to `SimulationEngine` and draws a read-only `WorldSnapshot` in SpriteKit.

The island tab renders textured terrain and roads, building and walker sprites, decorations, camera pan/zoom, placement tools, and cosmetic day/night lighting. Cart art and the batch 2 UI icons are not wired into the app. The simulation only advances when **Advance One Day** is pressed; animated walkers and lighting never advance or randomize the core.

## Build an IPA

Pushes, including every merge to `main`, and pull requests run `.github/workflows/unsigned-ipa.yml` on the GitHub-hosted `xcode-27` runner with Xcode 27.1. That image is the hosted runner that includes the iOS 27.1 SDK. The workflow runs the core tests, builds an unsigned device IPA, and uploads `PocketRepublic-unsigned.ipa` plus its SHA-256. That unsigned IPA is the test-build artifact: unzip it and sideload it. It does not need Apple signing secrets.

When the optional repository secrets listed in `PROGRESS.md` are all set, the same workflow also exports a signed IPA and uploads `PocketRepublic-signed.ipa`. The default export method is ad hoc.

The bundle identifier is `com.jscreate.pocketrepublic`, defined in `Config/PocketRepublic.xcconfig`. An iPhone alone cannot compile the SwiftUI project.

## Saves

The spatial city uses `Application Support/PocketRepublic/spatial-v1.json`, written atomically with a versioned envelope and state checksum. A corrupt or unsupported spatial save is preserved until **Start New City** is explicitly chosen. The earlier `pocket.republic.save.v1` UserDefaults save remains untouched; the new simulation starts a separate city because its world, economy, and citizen schemas differ.

The original v0.1 source and spec remain in `/home/jsmith/projects/pocket-republic/v0.1/`. For main `3db7d17`, [Build iOS IPA run 40218820097](https://github.com/JSCreate-Dev/pocket-republic/actions/runs/40218820097) passed 71 core tests with zero failures and built an unsigned iOS device app with Xcode 27.1. CI compilation does not verify installation, touch handling, or frame rate on an iPhone.
