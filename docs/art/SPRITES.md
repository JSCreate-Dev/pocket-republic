# Building sprites

v1 imagesets for every `BuildingKind`, in `PocketRepublic/Assets.xcassets/Buildings/`. The folder sets `provides-namespace` to false, so asset names stay `building_` plus the case name. Footprints, 1x pixel sizes, and anchors are recorded in `docs/art/sprites.json`.

## Footprints

| Building | `BuildingKind` | Footprint |
| --- | --- | --- |
| House | `house` | 2×2 |
| Police | `police` | 2×2 |
| Market | `market` | 3×2 |
| Workshop | `workshop` | 3×2 |
| Farm | `farm` | 3×3 |
| Clinic | `clinic` | 3×3 |
| School | `school` | 3×3 |
| Town Hall | `townHall` | 3×3 |
| Dock | `dock` | 2×3 |

## Sizing

A W×H tile building's isometric base is (W+H)×32 px wide at 1x, with the building's height on top of that base. Each sprite is exactly that wide at 1x. Game Designer set this rule.

## Anchor and draw order

The anchor is (0.5, 0.0): the bottom-front corner of the footprint diamond. Z-sort by tile x+y, the same order used today.

## Names

Asset names are `building_` plus the `BuildingKind` case name:

- `building_townHall`
- `building_house`
- `building_farm`
- `building_market`
- `building_clinic`
- `building_school`
- `building_police`
- `building_workshop`
- `building_dock`

## v1 limitation

The 3×2 and 2×3 sprites are drawn on square bases, so the base reads slightly off on non-square footprints (Market, Workshop, and Dock). A v2 pass will redraw those. Dock's water edge is the front-right side.
