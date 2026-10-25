# Pocket Republic — Design

Owner: Game Designer. This doc is the source of truth for building footprints, placement and inspect-panel content, and the game-feel targets every PR is judged against.

**North star:** Pocket Republic should feel like a lively, living world with real game feel, not a spreadsheet sim, and it's built for the iPhone Duo screen, both folded and unfolded.

## 1. Buildings: footprints, placement, inspect

### Why change
Today every building covers one tile (`Building.tile`) and is drawn as a 26×23 px block on a 64×32 isometric tile, so the city reads as tiny dots on a phone.

### What the reference games do
- **Cities: Skylines:** buildings sit on a cell grid and must face a road. Zoned (growable) buildings fill lots that run back from the road, and service buildings ("ploppables") are larger fixed rectangles. Placement shows a green or red ghost, and service buildings preview their coverage.
- **Tropico:** buildings have fixed footprints with an entrance facing a road, and each one has a selectable work mode, the same idea as our `OperatingMode`.
- **Both:** inspect panels lead with the building's status and biggest problem, then staffing and residents, then the numbers, then actions.

### Footprints (tiles, width × depth)
96×96 map; districts are about 21 tiles across.

| Building | Footprint | Extra rule |
|---|---|---|
| House | 2×2 | |
| Police | 2×2 | |
| Market | 3×2 | |
| Workshop | 3×2 | |
| Farm | 3×3 | at least half its tiles fertile |
| Clinic | 3×3 | |
| School | 3×3 | |
| Town Hall | 3×3 | |
| Dock | 2×3 | one long side touches water |

### Placement rules
1. A building is an anchor tile plus its footprint. Every covered tile must be buildable, empty, and not a road.
2. At least one edge tile must touch a road. That tile is the **entrance**.
3. The building belongs to the district of its entrance tile.
4. Pathing: only the entrance tile is passable, and walkers route around the rest of the footprint.
5. Demolishing clears every covered tile.
6. While placing, show a ghost tinted green or red, with the reason taken from `IntentRejection` when it's invalid. For service buildings, also draw their `maxServiceDistance` (20 tiles) reach.
7. Rotation can wait for a later version.

### Sprite sizing (for art)
A W×H-tile building has an isometric base (W+H)×32 px wide and (W+H)×16 px tall at 1x, anchored at its front (bottom) corner, with building height added on top.

### Inspect panel (tap a placed building)
Only show what the core already tracks.
- **Header:** the building's name, type, and district.
- **Status line:** the single biggest problem, like "Understaffed", "No road access", or "No food", or "Running well".
- **People:** workers out of capacity. For houses, residents out of capacity, with each one's hunger and job.
- **Numbers:** food stored (farm and market), funds, upkeep per day, and the day it was built.
- **Service reach** (market, clinic, school, police): how many residents are in range.
- **Actions:** a mode picker (Balanced, Intensive or Careful) for farms, workshops and docks, and a Demolish button that asks for confirmation (not offered for the Town Hall).

## 2. Game feel

### Principles
- **Every number has a visible cause.** If hunger, unrest or treasury changes, the player can see why somewhere on the island.
- **Feedback within 100 ms of a touch:** a highlight, a sound hook or a haptic, before any simulation result.
- **Show before you punish.** A problem appears in the world (an icon, a crowd, a dimmed building) before it costs the player anything.
- **Abundance looks like abundance.** Busy, full, lit places mean a healthy city, and empty, dark, still places mean trouble.

### Moments that should feel rewarding
1. **Placing a building.** The ghost snaps to the grid, then the building lands with a small bounce, a puff of dust, a light haptic and a sound hook. Within seconds its first workers walk in through the entrance.
2. **A building comes alive.** Lights switch on, the workshop chimney smokes, farm carts roll out toward the market, and a ship docks.
3. **Covering a neighbourhood.** Placing a clinic, school or police station sends a coverage ring rippling out, and houses in range briefly show a happy icon.
4. **Market day.** The crowd at the market grows with its food supply, so stalls look full and busy when the city is fed.
5. **Advancing the day.** The light sweeps from dusk to dawn, people head home at night and out to work in the morning, and a short summary counts up the changes (+population, +treasury, problems fixed).
6. **Fixing a problem.** Hunger or unrest icons over a district clear one by one, and walkers' mood visibly lifts.
7. **Resolving a crisis.** A protest crowd disperses and the district's color returns to normal.
8. **Milestones.** Population thresholds raise a flag on the Town Hall, with a small celebration at night (lanterns or fireworks).
9. **Inspecting.** The tapped building gives a quick wiggle and a highlight, and the panel slides in. Tapping a resident follows them for a moment.

### iPhone Duo layout
- **Unfolded:** the map on one panel, and the inspect or agenda panel on the other, so the map never gets covered.
- **Folded:** the panel becomes a bottom sheet over the map, with a half-height default and drag-to-expand.
- **Fold and unfold** keep the camera's focus and the current selection.

### Anti-goals
- No screens that are only tables.
- Nothing changes silently.
- No modal popups mid-placement. Crises and choices go to the agenda panel.
