# Progress

## 2026-10-25 — Game Designer

Added docs/DESIGN.md: building footprints per type, placement rules (road-facing entrance tile, only entrance passable), sprite sizing, inspect panel contents, and game-feel targets including the iPhone Duo layout. Next: Game Logic owns core footprint/placement/isPassable; Ios Dev owns ghost preview, rendering and inspect panel; Visual And Grapchics sizes sprites from the table.

## 2026-10-25 — Game Designer

Added DESIGN.md section 3: decree card layout (title, flavor, cost/Free, faction chips, plain-language effects, Issue decree / Not now) and newspaper-style event feed (grouping by kind+district+day, headline templates per EventKind, because-line from CauseFactor, names, Show me). Next: Ios Dev builds the UI; Game Logic adds a flavor string to DecreeSpec and ensures every negative event carries a cause.
