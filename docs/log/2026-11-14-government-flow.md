# Government flow and policy controls

- Date/time: 2026-11-14 12:52 AM EST.
- Role: Ios Dev.
- Branch: ui/government-flow.
- Base: 565bdbb936270f39e164b29fb62087d987bd1c11, integration/settlement-and-polish.
- Govern leads with an actual need, one priority letter, three lasting policies and understandable political context; decrees have inline purpose filters and briefing-to-card navigation.
- Policy review is read-only until Apply, explains the actual daily cash tax model and staffed public payroll, preserves unrelated fields, rejects stale/seed/bounds/crisis cases and uses existing setPolicy/save handling. Dismissal paths release clock holds. Direct rate changes do not promise decree approval bonuses.
- Added business-tax outcome receipt; simplified public-trust/household-tax/public-pay presentation names while retaining stable decree IDs and core fields.
- Verification: Swift 6.2 release core 193/193 passed in 6.324 seconds execution (excluding compilation); app frontend syntax parsing; actual government policy/readers, decree reading, clock, save recovery and Living Island checks pass. A first policy test fixture attempted an unchanged default rate and was corrected to exercise a real change; unchanged-rate rejection remains intentional.
- Core, save schema, ledger and RNG are unchanged. No new decree effect or imaginary revenue/happiness projection.
- Required next: Xcode typecheck/build and phone review of Apply/Keep current/swipe/scene/tab/session clock release, recommended-decree scroll, priority letters and deadlines, large text/VoiceOver/fold, old-save compatibility, and actual next-day wages/taxes. No IPA/main merge claimed.
