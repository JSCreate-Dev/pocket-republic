# 2026-11-08 11:00 AM EST — Game Logic — gameplay/settlement-growth

Off main 97c1a2c. Core only; no app, art, or CI configuration changes.

## Changed

Ordinary new cities start as a compact 16-person settlement with eight completed buildings, $1,600 and local roads. The old established generator remains available through an explicit citizenCount argument. Existing season/origin fixtures now explicitly request 120 citizens; their old regression assertions are retained.

Optional saved growth settings gate two arrivals every four days on finished housing, reachable job vacancies, happiness, no current hunger, and a local market reserve. Hiring residents runs first; newcomer money uses external transfers. Existing saves omit the optional and never acquire automatic arrivals.

Schedules vary by identity, occupation and day. Clinic visits, hall gatherings and market social trips have real reachable destinations and do not change simulation state. This does not implement the full citizen minds spec or new visual cues.

## Verification

Swift 6.2 release suite: 130 tests, zero failures, 5.932 seconds. Nine settlement tests plus the existing regression suite. Existing city economy report remains green. Six-day opening runway on seed 2026; unemployment is intentionally a pressure after that. Phone and iOS build unverified here.

## Next

Playtest a fresh city: add a workshop to employ the three jobseekers, then a house for newcomers. Check food and jobs as population grows. Add visible citizen purposes and stronger growth/political consequences next. UI polish is a separate PR off main.
