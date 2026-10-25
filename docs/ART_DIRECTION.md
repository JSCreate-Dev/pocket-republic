# Pocket Republic: Art Direction

Status: v1 building catalog, with corrected non-square footprint bases (Oct 25, 2026).

## The feel
A sunny, slightly tongue-in-cheek tropical island republic: think a cozy toy-diorama version of Tropico. Warm, readable and friendly, never gritty. Politics come through in the props and the town hall (flags, balconies, pastel colonial facades), not through darkness.

## Style rules
- **Projection:** 2:1 isometric, matching the current 64x32 tile grid in `IslandScene.swift`. Light comes from the top-left; shadows fall bottom-right.
- **Rendering:** clean flat shapes with one level of soft shading (a light face, a shadow face, and a roof). Thin darker outline on the outside silhouette only. No photoreal textures or noise.
- **Readability first:** every building has to be identifiable by silhouette and roof color at the farthest zoom. Avoid fine detail that turns to mush below about 40 px.
- **Scale:** buildings sit on whole-tile footprints, sized from the Game Designer spec. A W×H footprint is (W+H)×32 px wide at 1x, with the base diamond (W+H)×16 tall, anchored at the front (south) corner.
- **Anchor:** the sprite's anchor is the bottom (south) corner of its footprint diamond, so z-sorting by `x + y` keeps working.

## Palette
| Role | Hex |
| --- | --- |
| Sea (deep) | `#0E5E8C` |
| Sea (shallow) / UI accent | `#00C2EE` |
| Sand | `#E8C77A` |
| Grass | `#5DAA45` |
| Fertile soil / farm fields | `#3E8236` |
| Rock | `#7C807C` |
| Roof terracotta | `#D2552E` |
| Walls cream | `#F4EBDD` |
| Flag / alert orange | `#F2622A` |
| Pastel walls (houses) | `#F2B8C6`, `#F5D58A`, `#A9D8C8`, `#F2A47A` |

## Building language (for when sprites start)
- **Town hall:** cream walls, columns, terracotta dome and flag. The visual anchor of the island (matches the app icon).
- **House:** small pastel cottage, terracotta roof; vary wall color per instance from the pastel set.
- **Farm:** field rows in fertile green with a small barn.
- **Market:** striped awnings over stalls.
- **Clinic:** white with a teal cross sign.
- **School:** yellow walls, bell tower.
- **Police:** blue-grey walls, flat roof, lamp over the door.
- **Workshop:** brick and timber with a chimney.
- **Dock:** wooden pier extending into water tiles.

## Building sprites

v1 imagesets for every `BuildingKind`, in `PocketRepublic/Assets.xcassets/Buildings/`. The folder sets `provides-namespace` to false, so asset names stay `building_` plus the case name. Footprints, 1x pixel sizes, and anchors are recorded in `docs/art/sprites.json`.

### Footprints

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

### Sizing

A W×H tile building's isometric base is (W+H)×32 px wide at 1x, with the building's height on top of that base. Each sprite is exactly that wide at 1x. Game Designer set this rule.

### Anchor and draw order

The anchor is (0.5, 0.0): the bottom-front corner of the footprint diamond. Z-sort by tile x+y, the same order used today.

### Names

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

### Non-square bases

Market and workshop use separately composed 3×2 diamonds with their long axis on +x. Dock uses a 2×3 diamond with its long axis on +y and a water strip along the right shore. All three retain their existing image names, canvas sizes, and `(0.5, 0)` SpriteKit anchor.

## Citizens
Tiny 2-3 color figures (about 6x10 px at 1x). Hungry citizens keep the existing orange tint so the hunger signal stays readable.

## UI
SF Pro, rounded weight for headings. Cream panels (`#F4EBDD`) with terracotta primary buttons and turquoise accents, so the inspect panel feels like part of the island.

## App icon
`PocketRepublic/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`: the town hall on a round island in turquoise water, full-bleed square with no alpha (iOS applies the corner mask).
