# Living map inspection

2026-11-08 17:05 EST. Role Ios Dev. Branch ui/living-map-inspection; depends on map-attention core, atop previous 0ed3743 handoff.

Inspect taps can select an outdoor citizen via camera-space proximity, show a ground ring and full planned-day path, plus name/age/occupation/happiness/hunger/wallet and activity. Activity uses the actual core schedule intervals and the same visual clock as walker poses, checked at most 2Hz and emitted only on change. Home/work links focus the actual plot and open its inspection. Route is planned-day data, not traffic simulation. Indoor sprites are untappable; walkers behind nearer building bounds are conservatively excluded. Existing drag and multi-finger latches stay.

Up to twelve nearby roof signs reuse typed core road/staff/food attention, capped to limit clutter. Signs open the specific building regardless of the tile beneath the roof. Inspector displays concrete next-step help. Routes/signs hide during diagnostic overlays and build/road tools. State changes/new cities clear invalid citizen selection and caches; existing camera focus helper is reused. Existing app files only, no Xcode source references.

Verified: all app Swift syntax, whitespace checks; core 167 tests passed. No Xcode/UIKit/SpriteKit typechecking or physical phone test. Claude must check touch targets and zoom, crowded/occluded citizens, badge overlap/culling, dark material contrast, route updates after road edits/day changes, new-city reset, home/work links and both phone widths/fold layouts. Activity remains a decorative visual-day plan, independent of six-second economic ticks. No manual job assignment, new saved state, traffic/commute economy or true view/building rotation is claimed.
