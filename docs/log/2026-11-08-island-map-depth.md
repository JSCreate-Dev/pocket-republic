# 2026-11-08 12:20 PM EST — Game Logic — gameplay/island-map-depth

Additional round requested after the progression/placement pass. Base 0498e66, itself based on build 143 e6508e8. Core only.

New settlement terrain uses integer seeded noise and a rounded/bayed coastline, coherent fertile and rocky regions, a protected central start and a usable east dock landing shore. Flood fill removes disconnected land specks. No RNG stream is consumed. Explicit-population fixtures retain the old generator and old saves retain their recorded map. This is terrain composition, not elevation, mountains or new artwork.

MapOverlayMode and MapOverlaySnapshot expose none/fertility/happiness/food access/employment as disposable 0...100 values, with nil/no data distinct from a bad score. Social overlays are district averages of living residents; uninhabited districts have no score. Food is road/home coverage and current market stock, not affordability or a starvation forecast. A local dirty cache rebuild makes structural edits visible without mutating the real state.

147 Swift 6.2 release tests passed, zero failures, 5.238 seconds. Eight added tests cover replay/variation, connected land and legal dock shores over 18 seed/size combinations, established fixture terrain, exact soil overlay, social means/no data, empty/demolished/unfinished market coverage and non-mutating save/load identity. The full development-tree scripted progression remains green. No iOS or physical map review is claimed.
