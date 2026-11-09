# Island material rendering

2026-11-08 16:45 EST. Role Ios Dev; branch ui/island-material-rendering; depends on island material assets and decree/placement changes atop 2741dbe.

MapArt remaps terrain/roads to new surfaces with per-original-name legacy fallback and linear filtering for replacement textures. Grass/fertile use one surface to reduce checkerboard tones; fertility remains gameplay data shown by diagnostic overlays. Water phase aligns with scene time when tiles enter viewport. Coastal tint is restrained and existing white foam quieter. No full-map texture traversal or new shaders. Existing world lighting and Reduce Motion action reconfiguration retained.

Small UI polish: precision controls wrap to two rows below available width while keeping 44pt minimum targets. Decree reading removes unused agenda-slot IDs now that the core supports direct issuance; cost calculation matches the shared validator.

Verified: all app Swift syntax, extracted clock and lighting policy harnesses, 63 export validation checks, exact original 3x masks, git diff whitespace. Core unchanged since 160 tests passed. UIKit/SpriteKit typechecking, Xcode assets compilation, wave animation, camera/tiling/filtering, real dock fit and frame rate require Claude/device verification.

Rotation remains unimplemented for the documented art/projection/footprint reasons in the placement log. Do not present a screen-spin button as true world rotation.

Additional verification: tools/check-decree-reading.py extracts the actual Foundation-only card/effect-copy models and compiles them against the real core objects. Standing availability, no state writes, free-but-recurring payroll copy, tax clamp, global works scope, cooldown and treasury shortfall checks pass.
