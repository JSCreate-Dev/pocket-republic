# Pocket Republic: UI Style v1 (SwiftUI)
Mockup: `ui_style_sheet.png` (source `ui_style_sheet.html`; all labels are sample data). Content and wording rules come from docs/DESIGN.md §3; this file covers only the look. Use light, warm panels throughout and don't use stock dark `List` styling.

## Color tokens
| Token | Hex | Use |
|---|---|---|
| panel | #F4EBDD | sheet / panel background (cream walls) |
| surface | #FFF8EC | cards, rows, HUD pill |
| surfaceNews | #FFFBF2 | newspaper stories |
| ink | #3A2A1E | primary text |
| ink2 | #7A6A5A | secondary text, captions |
| divider | #E2D3BC | hairlines |
| track | #E8DCC8 | bar tracks, segmented bg |
| primary | #D2552E | primary buttons, selected segment text (terracotta) |
| primaryShadow | #9E3D1F | 2pt bottom "press" edge on primary |
| accent | #00C2EE | highlights, focus ring |
| accentInk | #0E5E8C | links ("Show me ›"), section labels, secondary button text |
| outline | #A9D8C8 | secondary button border |
| good | #5DAA45 (text #2E6B25 on #DDF0D3) | good news, pleased chips, healthy bars |
| warn | #F2A47A | bad-news bar |
| alert | #F2622A | hunger bar (same orange as hungry walkers) |
| crisis | #C8321E | crisis bar |
| danger | #B3361A on #FBE3DA, border #E8A08A | destructive button, status line, "Need N more" |
| angered chip | text #A63A16 on #F8D9CC | |
| highlight | #F5D58A | trend tag, happiness mid |
| gold | #F5C542 | coin, happiness bar |

## Typography (SF Pro Rounded: `.system(size:weight:design:.rounded)`)
- Panel title 20 heavy · Card title 18 heavy · Body 15 regular · Secondary 13.5 regular · Caption 12.5 medium · Section label 12 bold, uppercase, tracking 1, accentInk
- Decree flavor: 13.5 italic, #6E5A48
- Newspaper: masthead "The Pocket Gazette" New York/serif (`.serif` design) 20 bold, with a double rule below. Headlines are serif 16.5. Weight follows severity: crisis = black, bad = semibold, good = regular.
- Numbers: `.monospacedDigit()` in the HUD.

## Shape, shadow, spacing
- Radii: panel 20, card 16, story/row 10–12, button 12, chip and pill capsule.
- Shadows: panel `black(ink) 18% r14 y4`; card `12% r6 y2`; HUD pill `20% r10 y3`.
- Spacing on a 4-pt grid: panel padding 16, card padding 14, row padding 8×10, gap between cards 12, between chips 4.
- Hit targets ≥ 44 pt.

## Components
**HUD stats pill.** A capsule on `surface`, pinned at top-safe-area center (on the Duo, put it on the map pane). Items: icon_coin treasury, icon_people population, icon_food net food/day (signed), icon_happy happiness %, icon_day "Day N". Icons are 20 pt with a 5 pt gap and 14 pt between items; text is 15 bold. Bump on change: scale 1.15→1 spring, tinted good/danger for 0.6 s.

**Decree card** (DESIGN §3 order). Title (18 heavy, optional icon_decree), with cost right-aligned (icon_coin + amount, or "Free" in good green, never ": 0"). If unaffordable, show the cost in danger red plus "Need N more" and disable the primary button. Next comes the **flavor line** in italic, then faction chips (pleased first: ▲/▲▲/▲▲▲, then angered ▼…), then a bullet list of the effects that apply, then buttons: primary "Issue decree" and secondary "Not now" (which only closes the card). A compact list row shows title, cost/Free, and its top pleased and angered chip. Crisis decisions use the same card plus a "Why this happened" line styled like the event "because" line.

**Event feed (newspaper).** A panel with masthead "The Pocket Gazette" and "Day N" on the right, grouped by day. Each story card uses `surfaceNews`, radius 10, with a 6 pt left bar colored by severity: crisis #C8321E (with icon_alert), bad #F2A47A, good #5DAA45 (with a ✓). It contains:
1. Headline (serif, past tense, with a number and place), plus an optional trend tag ("3rd day running", 11 heavy on highlight, radius 6).
2. **"Because"** line (13, #8A3A1E, "Because" in bold). It's required on every negative story.
3. Names subhead (12.5 ink2, dotted underline, tappable to show the full list).
4. "Show me ›" (12.5 heavy accentInk, trailing), which pans the camera to the event.
Order is crisis, then bad, then good. Routine events fold into one caption line under a divider.

**Citizen row.** A 38 pt circular portrait (initials on the shirt color, or a later walker-head crop), name 15 heavy, job · workplace 12.5 ink2, and two 60×7 bars on the right: Hunger (fill alert orange when hungry, good green when fed) and Happy (gold, turning green above 70%).

**Inspect panel.** A panel sheet: header with name (20 heavy), "Type · District" caption and a close ×. Then a status line chip in danger colors for the biggest problem (omit it when fine), a key/value grid (15 regular / bold right-aligned, icons inline), a segmented mode picker (track bg, selected = white with primary text), citizen rows for houses, and a destructive "Demolish…" with a confirm alert. On the Duo, it docks in the second pane, otherwise it's a bottom sheet with detents `.medium/.large`.

**Buttons.**
- Primary: primary fill, white 15 heavy, with a 2 pt primaryShadow bottom edge. Pressed: offset y+2, no edge.
- Secondary: clear, 2 pt outline border, accentInk text.
- Destructive: danger bg #FBE3DA, 2 pt #E8A08A border, #B3361A text.
- Disabled: 40% opacity.

## Icons
`icon_coin, icon_people, icon_food, icon_happy, icon_day, icon_decree, icon_alert` are imagesets at 24 pt (24/48/72 px), full color, rendered as `.original`.
