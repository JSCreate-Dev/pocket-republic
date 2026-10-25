# Pocket Republic iOS project

Open `PocketRepublic.xcodeproj` in Xcode 27.1+. Targets iOS 17+, links the local `PocketRepublicCore` Swift package (the spatial city simulation). The app sends `PlayerIntent` to `SimulationEngine` and draws a read-only `WorldSnapshot` in SpriteKit. The simulation only advances on **Advance One Day**; animated walkers and lighting are cosmetic.

See [PROGRESS.md](PROGRESS.md) for current state, open items, and team process. See [AGENTS.md](AGENTS.md) for core invariants.

## Build an IPA

Every push and PR runs `.github/workflows/unsigned-ipa.yml` on the hosted `xcode-27` Xcode 27.1 runner: core tests, then an unsigned device IPA (`PocketRepublic-unsigned.ipa` + SHA-256) ready to sideload, no signing needed. Setting the optional signing secrets also produces a signed, ad-hoc-exported `PocketRepublic-signed.ipa`.

Bundle id is `com.jscreate.pocketrepublic` (`Config/PocketRepublic.xcconfig`). An iPhone alone cannot compile this project.

## Saves

City state is `Application Support/PocketRepublic/spatial-v1.json`, written atomically with a versioned envelope and checksum. A corrupt or unsupported save is preserved until **Start New City** is chosen explicitly. The legacy `pocket.republic.save.v1` UserDefaults save is untouched and separate.
