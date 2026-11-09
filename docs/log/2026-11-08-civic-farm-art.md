# Complete finished-building art family

2026-11-08 17:15 EST. Role Visual And Graphics. Branch art/civic-and-farm-family; base 2dd5bfa (living-map handoff, atop tested 2741dbe).

Six new detailed sibling sprites: farm, town hall, clinic, school, police and dock. They match approved house/workshop/market materials, warm light and phone-scale silhouettes. Existing type identities remain recognizable. All nine finished kinds now have golden siblings. Original art stays.

Built-in image generation supplied the art, with original kind and approved house as references. Prompts: docs/art/civic-family-prompts.md. ImageMagick exporter tools/art/export_civic_family.py fits existing logical canvases with six-pixel 3x top/side allowance and bottom-center ground contact. 18 new RGBA PNGs at universal 1x/2x/3x; no construction-stage replacement.

Verified: six generated sources and six 1x exports visually inspected; all nine kinds/27 family scales pass size/mode/corner/catalog/fallback checks via tools/art/check_building_family.py. Visible-art top/side margins for six new 3x outputs checked separately. Core unchanged from 167-test map-life pass; no broad rerun.

Actual Xcode asset compilation, physical contrast, plot/road/entrance alignment (especially 2x3 dock), shadow fit and zoom filtering remain unverified. The illustrative ground bases do not change core collision. Fixed-angle source art is not directional or ready for view rotation. No raw generated source files are required in app resources.
