# 2026-11-08 12:45 PM EST — Ios Dev — ui/automatic-days-and-panels

Base dbf0033 from integration/settlement-and-polish, the IPA Jordan tested in IMG_0176.jpeg. Main is unchanged.

The screenshot showed clipped roadmap content and Leisurely, held. Roadmap now gets a full-height scroll sheet with Done; charter and overlay help use the same reader. The HUD keeps a short layer row, with detailed legends behind Info. Unlock announcements dismiss after seven seconds. Other bottom content has explicit available height and scroll indicators.

Autoplay defaults to one day per six seconds. Attach explicitly schedules the initial timer even when note finds no state change. Pause/resume is direct and retains the last speed; speed has its own menu. Build/roadmap/catalog/optional event browsing do not hold time. Destructive confirmations, blocking crises/elections, save errors and backgrounding still hold. Optional cards can expire through the existing ignored-option behavior. No background catch-up.

Checks: Swift 6.2 Foundation policy compile/execution via tools/check-day-clock.py; parser on IslandView and DayClock; git diff --check. The real Foundation run-loop timer, sheet geometry, user gestures and visual layout require iOS verification. Core gameplay and saves are unchanged.

The approved golden-hour art direction remains the next art pass. A new generated house asset is being prepared separately; this patch does not contain it or claim the full concept image is implemented.
