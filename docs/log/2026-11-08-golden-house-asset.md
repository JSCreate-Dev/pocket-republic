# 2026-11-08 12:55 PM EST — Visual And Graphics — art/golden-house

Base c254263 (clock/panel fix over dbf0033). Added one approved golden-hour house asset, in a new sibling imageset, retaining original house art. Detailed stucco, terracotta, shutters and veranda follow the approved concept. Canvas sizes 128×125 / 256×250 / 384×375; transparent RGBA, bottom-center anchor and 2×2 footprint retained.

Built-in image generation with approved scene/old sprite references. ImageMagick performs deterministic scale/export only. See docs/art/GOLDEN_HOUSE.md for prompt and provenance. No gameplay or renderer-code changes in this role patch. Renderer activation and cast shadows follow separately.

Visual inspection and PNG metadata/corner-alpha checks done. No device render, Xcode asset compilation or full-style consistency claim; the rest of the art remains old.
