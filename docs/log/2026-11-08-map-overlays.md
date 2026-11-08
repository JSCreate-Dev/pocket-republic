# 2026-11-08 12:25 PM EST — Ios Dev — ui/map-overlays

Base 92efe76 (second core round), following build-143-based development and placement patches. Jordan requested Tropico-like happiness/fertility overlays.

A 44-point HUD Layers menu offers Normal, Fertility, Happiness, Food access and Jobs. It is part of the shared status view, including reserved fold panes. Viewport-cached tile markers use the core's scalar read model; the snapshot refreshes on state changes and layer selection, not every animation frame. Buildings dim and diagnostic colors stay readable through the cosmetic day/night wash. Standard mode restores the original picture.

Each mode has a textual legend. Social scores are district averages with gray/no-data on empty districts. Fertility is actual soil, not a promise that an occupied 3x3 site is legal. Food marks roads and finished homes; stocked, empty and inaccessible markets differ. It is not a household affordability forecast. Tapping ground or inspecting a building shows the value. Farm preview links directly to Fertility. No layer writes the game state or creates a timer.

A new city also recenters the camera and clears prior routine/selection caches; rotations and normal redraws retain the current camera as before.

Checks: Swift 6.2 syntax parsing, git diff --check. Core map/overlay data was tested in 147 passing release tests. No iOS build, image render, frame-rate result, physical interaction, VoiceOver run or visual acceptance is claimed. Claude builds and Jordan verifies actual layout/color/gestures. Old maps support overlays without regeneration; fresh cities are needed for new terrain and progression.
