# Standing decree agency

2026-11-08 16:40 EST. Role Game Logic. Branch gameplay/decree-agency, base 2741dbe (tested world-lighting integration).

Standing catalog can issue directly without an agenda offer. Existing council enactment forwards to the same validator/application path, paying once and emitting one decree event. Cooldown defaults to three days per decree, serialized as optional string-keyed day history; optional BalanceConfig override keeps old unmodified save encodings stable. Blocking crises/elections, insufficient funds and missing standing markets reject without side effects. Council decline no longer records an issued decree. Public works previously advertised neglect reset but global effect application failed to reset it; now all districts reset.

Verified: Swift 6.2 release 160 tests, zero failures, 7.936 seconds. New direct decree, conservation, save/cooldown, atomic rejection, market, global neglect and old optional-field omission tests. No new schema version or reset. Cooldowns intentionally alter repeated-decree balance; further phone playtesting is needed.
