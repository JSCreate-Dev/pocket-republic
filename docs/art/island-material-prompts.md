# Island surface material provenance

Four square surface textures generated with the built-in image generator, then projected through ImageMagick onto existing isometric masks. Exact original road-mask alpha is retained. Final project-bound exports live in PocketRepublic/Assets.xcassets/IslandMaterials, at 1x/2x/3x. Original art remains unchanged for fallback.

Grass/fertile share one surface to reduce checkerboard hue shifts; diagnostic fertility remains authoritative. Water has a wrapped-offset second frame; roads use limestone over sixteen original masks. Export: tools/art/export_island_materials.py --grass SOURCE --water SOURCE --sand SOURCE --rock SOURCE.

## grass

Seamless overhead tropical surface material, evenly lit and restrained.

## water

Seamless overhead tropical surface material, evenly lit and restrained.

## sand

Use case: stylized-concept. Asset type: seamless square flat overhead game-ground material. warm pale Caribbean beach sand, tiny grains, restrained irregular mineral flecks, faint natural mottling, no footprints no objects no ripples no cracks. Match refined hand-painted material rendering of a high-quality Caribbean city building game. Consistent average hue across the entire square, low contrast, neutral even light, continuous tileable edges, no border, no vignette, no horizon, no camera perspective, no dramatic shadows. Entire image is surface material.

## rock

Use case: stylized-concept. Asset type: seamless square flat overhead game-ground material. weathered tropical limestone and compacted mineral ground, warm muted grey stone with fine natural grain and subtle small fractures, no large separate rocks no grass no objects. Match refined hand-painted material rendering of a high-quality Caribbean city building game. Consistent average hue across the entire square, low contrast, neutral even light, continuous tileable edges, no border, no vignette, no horizon, no camera perspective, no dramatic shadows. Entire image is surface material.

## Grass final color refinement

Edit only the grass color palette of this seamless overhead tropical meadow material. Keep fine short grass texture, scale, uniform lighting, framing and seamless edge design. Change the yellow-olive cast to a richer natural tropical leaf green: balanced medium green with subdued moss highlights and dark soil flecks, overall around RGB 82 131 68, not fluorescent lime and not brown. Preserve restrained contrast so many adjacent tiles form a continuous meadow. No objects, no clumps, no border, no vignette.

These are material illustrations, not elevation, new shoreline geometry, directional sprites or 3D assets. Device checks are required for filtering, tiling, seams and water animation.
