# Pocket Republic: Art Direction

Status: v1, set by Visual And Grapchics (Oct 25, 2026). Building sprites are on hold until Game Designer's footprint recommendation lands.

## The feel
A sunny, slightly tongue-in-cheek tropical island republic: think a cozy toy-diorama version of Tropico. Warm, readable and friendly, never gritty. Politics come through in the props and the town hall (flags, balconies, pastel colonial facades), not through darkness.

## Style rules
- **Projection:** 2:1 isometric, matching the current 64x32 tile grid in `IslandScene.swift`. Light comes from the top-left; shadows fall bottom-right.
- **Rendering:** clean flat shapes with one level of soft shading (a light face, a shadow face, and a roof). Thin darker outline on the outside silhouette only. No photoreal textures or noise.
- **Readability first:** every building has to be identifiable by silhouette and roof color at the farthest zoom. Avoid fine detail that turns to mush below about 40 px.
- **Scale:** buildings sit on whole-tile footprints, sized from the Game Designer spec. Sprite canvas width = footprint width in tiles x 64 px (art at @3x for device, so 192 px per tile).
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

## Citizens
Tiny 2-3 color figures (about 6x10 px at 1x). Hungry citizens keep the existing orange tint so the hunger signal stays readable.

## UI
SF Pro, rounded weight for headings. Cream panels (`#F4EBDD`) with terracotta primary buttons and turquoise accents, so the inspect panel feels like part of the island.

## App icon
`PocketRepublic/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`: the town hall on a round island in turquoise water, full-bleed square with no alpha (iOS applies the corner mask).
