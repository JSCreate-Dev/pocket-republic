# Citizen daily-life presentation

2026-11-08 08:20 EST (09:20 EDT). Role: Ios Dev. Branch ui/citizen-daily-life, based on Game Logic citizen routes atop integrated 9928415.

Citizen cards show home/work identities, age and a disclosure of the authoritative planned routine. Disclosure planning is limited to expanded cards. Home/work dwell makes sprites invisible indoors; travel and public stops remain visible. Map animation still uses the established cosmetic 48-second day independently of the six-second simulation tick; this is labeled planned island hours, not live authoritative activity.

Verified: Swift 6.2 syntax parsing of CitizenDirectory and IslandScene; diff whitespace checks. Cannot run Xcode/UIKit or a physical device here. Claude must typecheck/build and verify small/large screens and sprite reappearance. No new Swift files or project references.
