# Actionable map attention and citizen activity

2026-11-08 17:05 EST. Role Game Logic. Branch gameplay/map-attention, base 0ed3743 (decrees/island/placement handoff, atop tested 2741dbe).

Typed BuildingAttention shares inspection's road/staff/food priority with concrete help and no service-range BFS. Road checks use the building footprint instead of a full-map occupancy scan. Empty farm/dock stock can mean delivered food, so only empty markets or hungry home residents are food shortages. Inspection and map status remain aligned.

DailyRoutine.activity returns exact staying/traveling activity over existing half-open schedule intervals. Invalid hours, empty routines and unreachable legs do not invent walking. This is a reader of the existing visual plan, not a new hourly economy.

Verified: Swift 6.2 release 167 tests, zero failures, 7.039 seconds. Four map-attention tests and three activity tests cover priority agreement, read-only hash, empty/restocked stores, missing/construction/demolished sites, exact departure/arrival boundaries, invalid hours and unreachable legs. No new saved fields or balance changes.
