# 2026-11-10 08:59 EST — Ios Dev — ui/actionable-map-notices

- Rendered core notices as standard-map billboards: road/staff/food problems, blue construction hammer, green opening seal. Real problems rank first; screen-edge/28-point spacing and 12-building budget keep the view legible.
- Added up to six visible resident notices for housing, meals, seeking work or a blocked job route. Needs/access are cached once per rendered state, selection twice/sec, positions updated with walkers; no per-frame BFS or particle effect. Indoor/interrupted/removed walkers cannot leave visible badges behind.
- Added 44-point notice hit areas, tap-to-resident inspection and plain next steps in both map and People inspectors. The People tab is the fallback for citizens indoors or without a real map position. Icons use existing SF Symbols, no new generated art.
- Added map-menu toggle and text legend. Notices hide during building/road sessions and data layers. Hidden markers cannot intercept taps. Route selection remains separate from the toggle.
- Growth detail and day journal now expose the new capacity/working-resident facts. Kept all prior tour/tutorial/faction/placement work.
- Verified app Swift syntax, actual extracted decree/tour/day-clock/world-lighting harnesses and whitespace. Core dependency passed 193 release tests. No Xcode SDK/typecheck, unsigned IPA, phone layout/touch/VoiceOver or performance result is claimed.
- Required phone check: density at all zooms, under roofs/near HUD and sheet edges, glyph clarity, touch targets, changing needs/indoor transitions/deaths/new city, legend/toggle, fold layouts and Dynamic Type. Build the combined source before distributing.
