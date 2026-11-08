# Continuous world lighting

2026-11-08 08:40 EST (09:40 EDT). Role Ios Dev. Branch ui/world-lighting; base 33e19fa (three-round handoff).

Continuous 240-second cosmetic light cycle replaces the existing currentTime/day-number expression, avoiding brightness jumps at each simulation tick. Local visual time uses clamped frame deltas to avoid catch-up after suspension. The existing separate citizen visual clock is unchanged. This is decorative atmosphere, not an authoritative day/night simulation.

Warm additive full-map veil, restrained cool night overlay, cached radial edge vignette, varying existing shadow opacity, and warm entrance ground pools on occupied standing buildings. No claimed window relighting, moving sun direction, physically based shadows or new electricity system. Entrance lights are positioned from actual core entrance tiles, reused and culled with visible buildings. All atmosphere hides in overlays; layer alpha updates at most ten times per second.

Reduce Motion holds steady golden daylight and visible water actions reconfigure when the setting changes live. No particle system or full-map per-frame texture traversal. Original assets and new workshop/market textures stay intact.

Verified: tools/check-world-lighting.py compiles the actual pure policy extracted from IslandScene and checks 2,401 cycle samples, continuous small steps, bounded opacity, periodicity, finite invalid-time handling and constant Reduce Motion output. DayClock policy harness, app Swift syntax parser and whitespace checks pass. Core unchanged since 154 tests passed in previous handoff.

Claude must compile Xcode/UIKit/asset target and test physical brightness/readability, entrance pool placement, camera/vignette coverage at zoom limits, diagnostic toggles, new-city reset, live Reduce Motion changes, foreground return and device frame rate. No iPhone or Xcode verification was possible here.
