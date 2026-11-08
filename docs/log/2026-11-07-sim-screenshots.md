# Simulator screenshots

- **When:** 2026-11-07, 9:39 PM EST
- **Role:** capture-only. No gameplay change is intended for main.
- **Branch:** `cursor/sim-screenshots-49ee`, cut from main `744e692` (island events, construction stages, closed-phone sheet, Gazette, play/pause).
- **Changed:** A launch argument `--pocket-republic-screenshot-fixture` builds a seed-2026 city and then overwrites a foundation, a scaffold, a pending Carnival card, or three Gazette rows. Ordinary launches skip it and still use the normal save. A separate workflow, `.github/workflows/simulator-screenshots.yml`, builds the iOS Simulator app on the hosted `xcode-27` runner and captures PNGs with `xcrun simctl io <udid> screenshot`. `PROGRESS.md` and the production IPA workflow are unchanged.
- **Verified:** Not yet. The workflow run is the check. These shots are a simulator, not a physical iPhone Duo, and the planted card and Gazette rows are not an advanced play session.
- **Next:** Download the artifact if the run is green. One CI fix is allowed if the first run fails.
