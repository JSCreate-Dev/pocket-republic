# Tutorial, politics and town-flow review

Base: f07285d (the linked successful IPA run). New work is separated into Game Logic and iOS commits.

## Issues addressed

- Intro previously ended as a camera tour. It now waits for Start settlement tutorial / Skip and opens a first unmet lesson, then keeps a compact coach on the map. Automatic advancement cannot choose on the player's behalf.
- A placed foundation could be mistaken for success. Guide evidence uses standing capacity and actual jobs; pending sites link to inspection instead of duplicate orders.
- Political arrows lacked context. Cards explain occupation membership, real mood versus approval, last-daily concern versus current members, demand deadline/ignore cost and recent government memory. Decree detail shows current context, remaining treasury and clamped approval projections.
- Daily route regeneration could move a citizen to a different part of a walk every six seconds. Economic ticks now leave the plan alone until visual midnight. Hungry workers prioritize food, civic demand visits belong to that faction, and funded festivals extend actual market dwell.

## Intentional limits

- After the first newcomer wave, the coach advances to Govern even if growth fills the spare beds again; it does not trap the player in an endless housing tutorial.
- Tutorial checks reflect live conditions and can regress; they are not saved achievements. Guide hide/active-seed preferences are app UI state only. Existing saves remain valid.
- Visual plans can trail the current economic snapshot by up to one 48-second visual day. A topology-invalid walk is hidden until midnight; no per-frame BFS or interpolation through new obstacles. New residents enter presentation at their planned visual position; boats, crowd collision avoidance and a continuous traffic economy are not added.
- The decorative light cycle remains independent. Reduce Motion freezes walk time. No new sounds or art assets in this pass.
- Faction shared concerns are last-daily reports, not recomputed promises. Approval changes are political memory, not guaranteed happiness. Memory records that the engine labels only “decision” are shown honestly as Government decision.

## Evidence and acceptance

181 core release tests pass. App parser and actual decree/tour/day-clock/light harnesses pass. Read the full core log supplied in the ZIP. No iOS SDK means parser checks cannot establish SwiftUI typechecking or runtime layout. Claude must compile and playtest on iPhone before handing over an IPA. Review onboarding, first housing/work loop, interruptions, accessibility and reduced motion before adding more scope.
