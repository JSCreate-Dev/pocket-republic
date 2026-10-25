# 2026-10-25 — game feel UI (`cursor/game-feel-ui-6005`)

Presentation only. No simulation edits, no `PROGRESS.md` edit. Merged `origin/main` through `f48dc67` (art direction, then design sections 4–6). Sections 4–6 are spec only and were not built; the design log says they wait until after the IPA milestone.

## What changed

- **Island.** Removed the large "Pocket Republic" navigation title. The right-hand rail (about 40% of the map) is gone. Folded, including portrait and compact landscape, the map is full width: a stats pill (day, residents, treasury, food, happiness, Advance) and a collapsible tool row sit on the map, and the agenda is a half-height bottom sheet that drags between a peek and expanded. Unfolded (vertical fold, or a wide inner display) puts the map on one pane and the agenda on the other. A horizontal fold stacks them. `CityPane` order in `IslandView` (`[.map, .agenda]`) is the swap point; there is no layout picker. The camera starts nearer the town (about 0.85 scale, capped at 4.5–8 tile-widths of the visible map) instead of the old 8–12 tiles measured on the narrow rail. Fold changes still keep the current world point.
- **Government.** The title was drawn twice because `navigationTitle("Government")` used the large title and the first form section was also named "Government". The screen now has one inline title and no section header of that name. Decrees are cards from `DecreeCatalogue`: title, optional flavor, cost or Free, "Need N more" when the treasury is short, faction chips (pleased first, ▲/▼ by strength), and plain-language effects. **Issue decree** sends the enact option. **Not now** only closes the card. Other council items keep their real options.
- **Citizens.** Living citizens are cards with generated pastel portraits, occupation, colored happiness, money, and hunger on every row (Fed, or Hungry N days). Hungry residents sort first.
- **Events.** The log is The Pocket Gazette. Same kind, district, and day become one story. Headlines come from a strings table. The old "days hungry" row dropped `CauseFactor.value`; the because-line now includes that count ("Hungry for 5 days", or "No market within reach for 9 days" when both causes are present). Names expand. A repeating run shows a trend tag. Routine `dayAdvanced` events are omitted; hires and new houses fold into one line ("3 citizens found work · 1 new house built"). **Show me** switches to the island and pans to the event tile, building, or district centroid, with a highlight diamond. Map drawing is otherwise unchanged. There is still no building inspect panel.
- **Theme.** `RepublicTheme` holds the art-direction palette (sea, turquoise, sand, grass, terracotta, cream, alert, pastels), spacing, and SF type (rounded headings). Cream panels, terracotta primary buttons, turquoise accents. The app uses a light color scheme so those panels read as the diorama.
- **Flavor and missing causes.** `DecreeSpec` still has no `flavor` field. The card reads it with `Mirror` when it appears and skips the line when it does not. A story with no `CauseFactor` still prints; the because-line is omitted.

## State

`swift test` in `PocketRepublicCore` with Swift 6.2 on Linux: 56 tests, 0 failures (15 new in `GazetteTests` and `DecreeCardCopyTests`). No iOS simulator in this environment, so folded and unfolded screenshots were not captured. The Xcode target was not compiled here.

## Next

- Game Logic: add `flavor` on `DecreeSpec`, and keep a cause on every negative event. The UI already renders both when present.
- Ios Dev, after the footprint core lands: ghost preview, footprint rendering, and the inspect panel in the agenda pane. Do not build the layout picker until game feel and performance are in shape.
- Someone with the iPhone Duo simulator should check the sheet, the book fold, Dynamic Type, and the starting zoom.
