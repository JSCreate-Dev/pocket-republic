# Core-flow and map-notice review

## What changed and why

- A demolished home could leave a resident permanently unhoused even after spare housing opened. Daily order is now construction/cache rebuild → local rehousing → hiring → arrivals → normal economy. Existing residents reserve available beds first; no relocation payment or population increase is invented. Household district/market metadata refreshes after moves.
- Residents without homes were skipped by feeding and could remain tagged fed. Missed meals are now counted; normal shelter allocation can restore the household market route. Existing wellbeing formulas remain in place.
- The growth reader could describe vacancies as spare when the next tick would allocate them to local jobseekers. Forecasting prepares a copy with local housing/hiring and shares the exact capacity planner used by admission. Partial waves reserve beds/jobs and increasing food requirements per admitted person. The forecast describes current capacity, not a guarantee of future happiness or stock.
- Rehousing and food/job recovery now have truthful events/goals/results. Notices distinguish current access/stock/cash from the last meal report. No new core saved fields or random draws.
- Construction is informational rather than a staffing alarm. The old marker regression test intentionally changes its construction expectation while retaining demolition/invalid-id checks.

## Display constraints

Real problems beat opening notices. Roof notices cap at 12, resident notices at 6, with a screen-size/spacing budget. Only visible walkers have map markers; do not invent a location for an unhoused or indoor citizen. People inspectors show the same text needs. Badge selection uses cached data twice/sec; only world positions change per frame. Hide/toggle checks also prevent invisible badges stealing taps. Marker scale stays readable across camera zoom.

## Verified versus pending

193 core release tests pass, including conservation and JSON save/replay. App source parses; extracted actual model/policy harnesses pass. A three-line Gazette case is included with the new EventKind to preserve exhaustive consumers. There is no Apple SDK here: Xcode typechecking and real device icon/touch/layout/frame-rate/VoiceOver review remain required. Construction badge height is a presentation approximation and should be checked against the actual site art. No true camera/building rotation or traffic economy is added.
