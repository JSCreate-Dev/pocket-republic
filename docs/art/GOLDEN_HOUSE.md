# Golden-hour house, first production art slice

Jordan approved the Golden Hour Island City concept and the isolated house preview on 8 November 2026. The new sprite has ivory stucco, weathered terracotta, teal shutters and a timber veranda. It is an actual transparent game asset, not the full concept scene.

The sibling imageset building_house_golden preserves the original building_house assets for fallback/comparison. Canvas dimensions are 128×125, 256×250 and 384×375 at 1x/2x/3x. The gameplay footprint stays 2×2 and the SpriteKit anchor stays (0.5, 0). No core balance, collision, pathing, save or selection rule changes.

Generated with the built-in image tool using the approved scene as style reference and the old house as geometry reference. The original generated 1269×1240 RGBA sprite was trimmed, proportionally fitted and bottom-centered into the existing canvas using ImageMagick; lower scales derive from the 3x export. There is no baked long cast shadow outside the footprint; renderer lighting supplies that separately.

Prompt: one orthographic isometric Caribbean colonial house on transparent background, premium detailed terracotta, ivory stucco, teal shutters, small shaded veranda, fixed 2×2 ground diamond, warm upper-left sunlight, ambient shading only, no scenery, text, roads or other buildings.

Checks: inspect generated sprite; verify RGBA transparency, expected dimensions and fully transparent corners for all three exports. The bottom-centered silhouette needs a real in-game footprint/road-occlusion check. The rest of the buildings and ground art are still the earlier style. Do not call this a complete AAA art conversion.
