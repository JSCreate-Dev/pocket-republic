# Progress

## 2026-10-25 — Building sprites v1

- Added nine imagesets under `PocketRepublic/Assets.xcassets/Buildings/` with `provides-namespace` false. Names are `building_` plus the `BuildingKind` case name (`townHall`, `house`, `farm`, `market`, `clinic`, `school`, `police`, `workshop`, `dock`). Each PNG is 8-bit RGBA with an alpha channel, and each `Contents.json` is valid JSON.
- Committed `docs/art/sprites.json` with per-building footprint, 1x size, and anchor `(0.5, 0.0)`.
- Wrote the Building sprites section in `docs/art/SPRITES.md`. `docs/ART_DIRECTION.md` is only on an open branch, so the section lives here until that file is on main.
- Left rendering and simulation code unchanged, including `IslandScene.swift`, for the in-flight multi-tile footprint work.
