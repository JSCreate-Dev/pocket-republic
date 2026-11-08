# Workshop and market art family

2026-11-08 08:35 EST (09:35 EDT). Role Visual And Graphics. Branch art/workshop-market-golden; base 60c661b (map/growth handoff).

New detailed workshop and market sprites match approved house materials. Existing art remains as fallback. Six RGBA PNGs cover universal 1x/2x/3x; existing logical dimensions and bottom-center canvas anchor retained. Built-in image generator used; prompts/provenance in docs/art/golden-workshop-market-prompts.md. ImageMagick trims/fits/pads/exports; no manual redraw.

Verified: correct pixel sizes, four transparent corners per file, visual inspection of generated sources and 3x exports; distinct material details survive downscale. No actual iOS rendering or road geometry certification. Artist-rendered footprint edges require phone alignment inspection; core occupancy does not change. No other building art or terrain is replaced.
