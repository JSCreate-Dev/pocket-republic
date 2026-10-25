# 2026-10-25 2:17 PM EDT — Ios Dev — `swift/duo-rail-polish`

Owner's Duo screenshots showed the closed portrait control rail filling a large empty column and wrapping Treasury and Advance One Day. The Island navigation title also occupied a large header.

This branch uses an inline Island title, Cash and Next Day labels in the narrow rail, and keeps tall portrait controls top and bottom with transparent space between. Shorter windows retain a scrollable rail. It changes presentation only; the core and save format are untouched.

Verified: reviewed the owner's screenshots, checked the diff, and confirmed the branch is based on current main `3db7d17`. The iOS SDK build and on-device result are pending the pull-request workflow and owner's next Duo test.
