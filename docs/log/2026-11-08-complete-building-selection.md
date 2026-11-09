# Full family renderer selection

2026-11-08 17:15 EST. Role Ios Dev. Branch ui/complete-building-art, dependent on civic/farm art atop 2dd5bfa.

BuildingSpriteCatalog selects golden farm, town hall, clinic, school, police and dock with per-kind legacy fallback. Alongside existing house/workshop/market this gives all nine completed types the same family. Map, finished-building ghost, catalog and roadmap use the same catalog. No new source files/project references, metrics, anchors, core footprints or construction-stage changes.

Verified: all app Swift syntax and whitespace, all 27 golden-scale asset/catalog/fallback checks with --renderer, and existing material, decree-reading, clock and world-light policy harnesses. Core unchanged since 167 passing tests in 7.039 seconds. Xcode/UIKit typechecking and device visuals/performance are not verified.

Claude must check all nine map/catalog/roadmap/ghost images, non-square dock lot/shore alignment, foundation-to-complete transitions, shadows/entrance lights, roof warning badges, low-zoom readability and small/large phone layouts. Existing saves need no reset. True camera/building rotation still needs directional-art/projection/orientation work.
