# Workshop/market renderer selection

2026-11-08 08:35 EST (09:35 EDT). Role Ios Dev. Branch ui/workshop-market-art; depends on workshop-market art change atop 60c661b.

BuildingSpriteCatalog chooses golden workshop/market assets with original-image fallback. Catalog and map share this source. Logical canvas sizes, bottom-center anchors, footprint/collision and construction stages are unchanged.

Verified: Swift 6.2 syntax parsing of BuildingArtwork, whitespace checks and asset export dimensions/alpha. Core unchanged since 154 passing tests. Claude must build Xcode asset catalog and verify road alignment, preview-to-built transition and thumbnail readability on both phone widths.
