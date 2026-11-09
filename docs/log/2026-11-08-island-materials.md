# Island material family

2026-11-08 16:45 EST. Role Visual And Graphics; branch art/island-surface-materials, base decree/placement UI atop 2741dbe.

Generated restrained leaf-green meadow, turquoise water, pale beach sand and weathered limestone surfaces. Isometric projection and original alpha masks preserve tile/road geometry exactly. Five surface frames (including water's second wrapped-offset frame) and sixteen limestone road shapes export at universal 1x/2x/3x. Original art remains. Fertile ground shares grass; use the fertility diagnostic for true data.

Built-in image generator produced the source art; final prompts in docs/art/island-material-prompts.md. ImageMagick handles deterministic export with tools/art/export_island_materials.py; tools/art/check_island_materials.py checks sizes, alpha, catalogs and exact 3x legacy silhouettes. 63 exports pass; individual exports and tiled material mosaic visually inspected.

Limitations: these are materials, not terrain elevation, new shoreline geometry or directional building assets. Repetition, zoom filtering, actual wave timing and all-region color harmony need an iPhone build. No physical-device screenshot is claimed.
