# 2026-11-08 12:05 PM EST — Game Logic — gameplay/development-tree

Base e6508e8 (integrated build 143), not old main. No main merge or production action.

Four deterministic, automatically awarded milestones; clinic/dock/school/police access and one-time infrastructure grants. House/farm/market/workshop and roads remain available. The core tracks player-commissioned workplaces by ID so instant builds count, while worldgen and unfinished/cleared sites do not. Recorded unlocks are permanent.

Optional development and developmentRules fields preserve pre-tree saves and checksums, including build-143 settlement cities. Fresh cities opt in. Placement and its preview enforce the same gate, using the existing seasonNotReady rejection for source compatibility. The specific UI explanation is DevelopmentTree.lockReason; no new EventKind or IntentRejection cases break exhaustive app readers.

139 release tests passed with Swift 6.2, zero failures, 5.533 seconds. Normal construction and growth earned all four nodes by day 28 (population 28, funds $3,323). Nine new tests cover locks, construction timing, instant-build identity, permanent awards, grants, legacy saves and deterministic continuation. No iOS or physical phone run.

Future priority: clearer placement outcomes and gesture separation, then terrain shape/landmarks and district depth. Do not claim those as implemented by this core PR. Claude handles integration/IPA. Role-specific PRs should be based on current main only after the build-143 prerequisite changes land, or reviewed against the integration branch explicitly; do not silently stack on stale main.
