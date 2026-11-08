# Settlement outlook

2026-11-08 08:20 EST (09:20 EDT). Role Game Logic; branch gameplay/settlement-outlook; base 6b02991 (citizen-depth handoff, atop integrated 9928415).

Read-only SettlementOutlook exposes simultaneous growth blockers, free beds/jobs, happiness threshold, hunger, next scheduled check, and reserve for the first newcomer at a connected home's shopping market. Dirty spatial caches rebuild on a local copy. No saved fields, economic rules or arrival scheduling change. The existing arrival implementation remains authoritative. Readiness is a current snapshot and conditions must hold at the actual check; second arrivals need additional capacity.

Verified: 154 release tests, zero failures, 6.317 seconds. Four new tests cover concurrent gates and no state/hash changes, legacy behavior, actual first arrival agreement, reserve, and disconnection. No iOS runtime validation.
