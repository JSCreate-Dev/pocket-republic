# Pocket Republic — Design

Owner: Game Designer. This doc is the source of truth for building footprints, placement and inspect-panel content, and the game-feel targets every PR is judged against.

**North star:** Pocket Republic should feel like a lively, living world with real game feel, not a spreadsheet sim, and it's built for the iPhone Duo screen, both folded and unfolded.

## 1. Buildings: footprints, placement, inspect

### Why change
Today every building covers one tile (`Building.tile`) and is drawn as a 26×23 px block on a 64×32 isometric tile, so the city reads as tiny dots on a phone.

### What the reference games do
- **Cities: Skylines:** buildings sit on a cell grid and must face a road. Zoned (growable) buildings fill lots that run back from the road, and service buildings ("ploppables") are larger fixed rectangles. Placement shows a green or red ghost, and service buildings preview their coverage.
- **Tropico:** buildings have fixed footprints with an entrance facing a road, and each one has a selectable work mode, the same idea as our `OperatingMode`.
- **Both:** inspect panels lead with the building's status and biggest problem, then staffing and residents, then the numbers, then actions.

### Footprints (tiles, width × depth)
96×96 map; districts are about 21 tiles across.

| Building | Footprint | Extra rule |
|---|---|---|
| House | 2×2 | |
| Police | 2×2 | |
| Market | 3×2 | |
| Workshop | 3×2 | |
| Farm | 3×3 | at least half its tiles fertile |
| Clinic | 3×3 | |
| School | 3×3 | |
| Town Hall | 3×3 | |
| Dock | 2×3 | one long side touches water |

### Placement rules
1. A building is an anchor tile plus its footprint. Every covered tile must be buildable, empty, and not a road.
2. At least one edge tile must touch a road. That tile is the **entrance**.
3. The building belongs to the district of its entrance tile.
4. Pathing: only the entrance tile is passable, and walkers route around the rest of the footprint.
5. Demolishing clears every covered tile.
6. While placing, show a ghost tinted green or red, with the reason taken from `IntentRejection` when it's invalid. For service buildings, also draw their `maxServiceDistance` (20 tiles) reach.
7. Rotation can wait for a later version.

### Sprite sizing (for art)
A W×H-tile building has an isometric base (W+H)×32 px wide and (W+H)×16 px tall at 1x, anchored at its front (bottom) corner, with building height added on top.

### Inspect panel (tap a placed building)
Only show what the core already tracks.
- **Header:** the building's name, type, and district.
- **Status line:** the single biggest problem, like "Understaffed", "No road access", or "No food", or "Running well".
- **People:** workers out of capacity. For houses, residents out of capacity, with each one's hunger and job.
- **Numbers:** food stored (farm and market), funds, upkeep per day, and the day it was built.
- **Service reach** (market, clinic, school, police): how many residents are in range.
- **Actions:** a mode picker (Balanced, Intensive or Careful) for farms, workshops and docks, and a Demolish button that asks for confirmation (not offered for the Town Hall).

## 2. Game feel

### Principles
- **Every number has a visible cause.** If hunger, unrest or treasury changes, the player can see why somewhere on the island.
- **Feedback within 100 ms of a touch:** a highlight, a sound hook or a haptic, before any simulation result.
- **Show before you punish.** A problem appears in the world (an icon, a crowd, a dimmed building) before it costs the player anything.
- **Abundance looks like abundance.** Busy, full, lit places mean a healthy city, and empty, dark, still places mean trouble.
- **No two games play the same.** Every new game rolls a fresh 64-bit **game seed** from system entropy. That one roll is the only non-deterministic moment, and it's stored in the save. The seed drives:
  - the island layout: coastline, fertile land, rock, district shapes and names, and starting resources (`WorldGen`),
  - the starting citizens: names, ages, traits (4.2), occupations, and so the faction mix,
  - the event deck: daily draws (5.1), plus **2–3 rare one-off events per run**, picked at game start from a rare pool (5.6) and each able to fire at most once,
  - the LLM flavor: the request seed and the persona picks (section 6).

  Determinism holds **within a save**, for replays and tests. A new game never reuses a seed. A "Replay this island" option or a seed shown for sharing can come later.

### Moments that should feel rewarding
1. **Placing a building.** The ghost snaps to the grid, then the building lands with a small bounce, a puff of dust, a light haptic and a sound hook. Within seconds its first workers walk in through the entrance.
2. **A building comes alive.** Lights switch on, the workshop chimney smokes, farm carts roll out toward the market, and a ship docks.
3. **Covering a neighbourhood.** Placing a clinic, school or police station sends a coverage ring rippling out, and houses in range briefly show a happy icon.
4. **Market day.** The crowd at the market grows with its food supply, so stalls look full and busy when the city is fed.
5. **Advancing the day.** The light sweeps from dusk to dawn, people head home at night and out to work in the morning, and a short summary counts up the changes (+population, +treasury, problems fixed).
6. **Fixing a problem.** Hunger or unrest icons over a district clear one by one, and walkers' mood visibly lifts.
7. **Resolving a crisis.** A protest crowd disperses and the district's color returns to normal.
8. **Milestones.** Population thresholds raise a flag on the Town Hall, with a small celebration at night (lanterns or fireworks).
9. **Inspecting.** The tapped building gives a quick wiggle and a highlight, and the panel slides in. Tapping a resident follows them for a moment.

### iPhone Duo layout
- **Unfolded:** the map on one panel, and the inspect or agenda panel on the other, so the map never gets covered.
- **Folded:** the panel becomes a bottom sheet over the map, with a half-height default and drag-to-expand.
- **Fold and unfold** keep the camera's focus and the current selection.

### Anti-goals
- No screens that are only tables.
- Nothing changes silently.
- No modal popups mid-placement. Crises and choices go to the agenda panel.

## 3. Decrees and events: how they read

Playtest problem: decree buttons read like "Raise the civic wage: 0" and "Purge the graft registers: 260", each with a bare "Not now", and the event log is four identical "Citizen Hungry · days hungry" rows. Every field below already exists in the core (`DecreeSpec`, `AgendaEffect`, `GameEvent`, `CauseFactor`, citizen and district names), so this is presentation work only.

### Decree card
The card is laid out top to bottom like this.

1. **Title**, in imperative voice, exactly as `DecreeSpec.name` gives it ("Purge the graft registers").
2. **Flavor line**, one sentence in the republic's voice that says what it means in the world: "Auditors open every ledger in the Ministry. Some officials will not sleep tonight." Add a `flavor` string to `DecreeSpec`, so that's data and not code.
3. **Cost**, shown as a coin icon and amount ("260"). When `cost == 0`, show **"Free"**. Never show ": 0". If the treasury can't afford it, grey out the cost in red with "Need 40 more".
4. **Who it pleases and who it angers.** One chip per faction from `favorFactions`/`favorDeltas`, with an up or down arrow and a strength (▲ small 1–3, ▲▲ medium 4–6, ▲▲▲ large 7+), and pleased chips first: "Landless ▲▲ · Labourers ▲ · Officials ▼▼▼". Show the strength as arrows rather than raw numbers, so it stays readable and still matches the sim.
5. **What it changes**, in plain words, only the lines that apply:
   - Treasury: "−260 now"
   - Taxes: "Income tax −3%" or "+3%"
   - Wages: "Civic wage +1/day"
   - Order: "Unrest falls across the island" (or "in Harbor" when it's scoped to a district)
   - Trust: "Legitimacy up" or "down", "Corruption down"
   - Food: "+140 food delivered to the market"
   - Neglect: "Neglected district is restored"
6. **Buttons:** a primary **"Issue decree"** and a quiet secondary **"Not now"**. "Not now" only closes the card. It isn't an option with a cost.

Example: **Raise the civic wage**, Free. "Clerks, nurses and teachers get a little more in every pay packet." Officials ▲▲▲ · Merchants ▼▼. Civic wage +1/day, paid from the treasury every day after this.

The decree list shows each decree as a compact row (title, cost or "Free", and its top pleased and angered faction), and tapping a row opens the full card. Crisis decisions (`PendingDecision`) use the same card layout, plus a "Why this happened" line built from its `causes` ("Harbor has gone 9 days without a market in range").

### Events: newspaper style
The event feed is the island's newspaper, so it reports stories, not rows.

**Grouping.** Combine events with the same `kind` and the same district on the same day into one story, with a count.
- 4 × `citizenHungry` in Harbor → **"4 families went hungry in Harbor"**
- Show up to three names from `subjects` as the subhead ("Ana Reyes, Tomás Ortiz and 2 others"), and tapping the subhead lists them all.

**Each story shows:**
1. A **headline** in plain past tense with a number and a place: "4 families went hungry in Harbor".
2. A **"because" line** taken from the top `CauseFactor`: "No market within reach for 9 days" or "Market ran out of food".
3. **Names** of up to three subjects.
4. A **trend tag** when it's repeating: "3rd day running" (from `daysHungry` or repeat counts).
5. A **"Show me" tap** that pans the camera to `location` and highlights the building or district.

**Ordering and weight.**
- Group the feed by day under a masthead ("Day 14 · The Pocket Gazette").
- Within a day, list it in this order: crises and decisions, then bad news, then good news, then routine.
- Headline weight follows severity. Crises are bold with a colored bar, bad news is regular, and good news is lighter with a green tick.
- Fold routine events (`dayAdvanced`, single hires) into one line at the bottom: "3 citizens found work · 1 new house built".

**Headline templates** (per `EventKind`, singular and plural):

| Kind | Headline |
|---|---|
| citizenHungry | "{n} families went hungry in {district}" |
| foodShortage | "{market} ran out of food" |
| citizenUnemployed | "{n} workers lost their jobs in {district}" |
| citizenEmployed | "{n} citizens found work" |
| citizenTurnedToCrime | "{name} turned to crime in {district}" |
| districtNeglected | "{district} feels forgotten: no {service} for {days} days" |
| districtProtest | "Crowds gather in {district}" |
| buildingConstructed | "A new {building} opens in {district}" |
| buildingAbandoned | "The {building} in {district} stands empty" |
| migrationArrival / Departure | "{n} newcomers arrived" / "{n} citizens left the island" |
| factionDemandRaised | "The {faction} demand action on {concern}" |
| factionDemandIgnored | "The {faction} feel ignored" |
| decreeIssued | "By decree: {decree title}" |
| crisisRaised / Resolved | "Crisis in {district}: {kind}" / "{district} crisis resolved" |
| treasuryEmpty | "The treasury is empty" |
| electionCalled / Held | "An election is called" / "The republic has voted" |

**Rules:**
- Every negative story has a "because" line, so if a cause is missing the core should be fixed rather than the line dropped.
- Never show the raw enum name or a bare number.
- Write templates as data (a strings table), so they can be localized later.

## 4. Citizen minds

Inspiration: Tropico 6. Citizens aren't units, they're small people with needs, a temperament, and an opinion of you. **Rule: every choice a citizen makes has a cause you can read (a `CauseFactor`) and something you can see on the island.**

### 4.1 Needs (0–100 each, recomputed daily)
| Need | Satisfied by (existing core) | Low means |
|---|---|---|
| Food | fed today, `daysHungry == 0` | hunger |
| Housing | has `home`, house not over capacity | sleeping rough, wants to move |
| Job | has `work`. Quality comes from wage and the building's `OperatingMode` (Intensive lowers it) | quits or idles |
| Fun & faith | market, and a festival or church in range (a church or tavern building can come later; for now, the market plus festivals) | boredom, grumbling |
| Safety | police coverage, low crime nearby | fear, wants to move |
| Liberty | low curfew and crackdown history, low corruption | resentment, protest |

**Happiness** is the weighted mean of the needs, and `Citizen.happiness` already exists, so this just defines how it's computed. The lowest need is the citizen's **top complaint**, which the inspect panel and thought bubbles show.

### 4.2 Traits (1–2 per citizen, fixed at birth, from seeded RNG)
Traits change the weight of a need or the odds of a choice. Starter set:
- **Devout:** fun & faith counts double, likes festivals.
- **Ambitious:** job quality counts double, more likely to start a side business (uses `ambition`).
- **Rebellious:** liberty counts double, more likely to protest, and a curfew angers them twice as much.
- **Loyalist:** opinion of the government decays more slowly, and they ignore some gossip.
- **Thrifty:** saves `money`, rarely emigrates, hates tax hikes.
- **Gossip:** spreads mood twice as far.
- **Wanderer:** much more likely to emigrate or move house.

### 4.3 Opinion of El Presidente
- `Citizen.loyalty` (already exists) is their opinion of the government, 0–100.
- It moves daily toward happiness, faster when a decree or event touches them directly (their faction's favor delta, their district).
- Their faction comes from occupation (it already does), and faction favor nudges member loyalty, so a decree the Labourers hate pulls every labourer's opinion down a little.
- Each citizen keeps a **memory of their last three reasons** ("Curfew in Harbor", "Fed during the famine"), which the inspect panel shows. Reuse `FavorRecord`'s shape.

### 4.4 Gossip (word of mouth)
- Once a day, each citizen trades mood with up to 2 neighbours: housemates, coworkers, or someone at the same market.
- Loyalty drifts 10% toward the neighbour's (doubled for a Gossip, halved for a Loyalist).
- This is how unrest **spreads** through a district instead of switching on everywhere at once.
- **Visible:** two walkers stop and chat with a little speech bubble showing the mood icon.
- Cap it: only citizens whose mood differs by 20 or more bother to gossip, which keeps the cost per tick low.

### 4.5 Small choices citizens make
Every choice is checked once a day with seeded RNG, has a clear trigger, emits a `GameEvent` with causes, and shows up in the world.

| Choice | Trigger | Visible on the island | Event cause |
|---|---|---|---|
| Take a job | unemployed and an open job in range, pick by job quality | walks to the new workplace with a briefcase icon | unemployment |
| Quit | job need under 25 for 5 days, or a better job in range | storms out, then a "Hiring" sign on the building | jobQuality (new) |
| Move house | housing or safety under 30, and a free house elsewhere | walks across the island carrying a bundle | housing (new) / noPoliceAccess |
| Protest | liberty or happiness under 25, and 3 or more nearby agree (via gossip) | a crowd with placards at the Town Hall or district centre | existing `districtProtest` |
| Side business | Ambitious, money over 200, market need unmet nearby | a market stall pops up next to their house | entrepreneurship (new) |
| Turn to crime | `daysUnemployed` 10 or more and poverty | hooded walker, with a crime icon on the house (`criminal` already exists) | existing `citizenTurnedToCrime` |
| Emigrate | happiness under 20 for 7 days, or loyalty under 10 | walks to the dock and boards a boat | existing `migrationDeparture` |

**Caps:** at most 2% of the population makes a big choice (quit, move, emigrate, crime) per day, so the island never empties out overnight.

### 4.6 New core fields needed (flagged for Game Logic, next round)
- `Citizen.needs: [UInt8]` (6 values) and `Citizen.traits: UInt8` (bitmask)
- `Citizen.memory: [FavorRecord]` (cap 3)
- `CauseKind`: add `jobQuality`, `housing`, `liberty`, `boredom`, `entrepreneurship`, `gossip`
- `EventKind`: add `citizenQuit`, `citizenMoved`, `citizenStartedBusiness`
- A side business is a lightweight `Building` of kind `stall` (1×1, no build cost, owned by the citizen), or it reuses `market` at reduced capacity. Pick whichever is simpler.
- `BalanceConfig`: need weights, gossip rate, choice thresholds, and the daily choice cap. Everything is tunable data.

Determinism: every roll uses `SeededRNG` in a fixed citizen order, so replays stay identical and the tests stay green.

### 4.7 Every roll is seeded (determinism contract)
All randomness in sections 4 and 5 comes from `SeededRNG`, drawn inside the tick in a fixed order, so a run replays exactly the same from its seed plus its intent log. Nothing uses system time, `Double.random`, dictionary iteration order, or how fast the model happens to answer.

Each tick draws in this order:
1. **Births and arrivals:** trait rolls for new citizens (1–2 traits each, by ascending `CitizenID`).
2. **Gossip:** for each citizen by ascending `CitizenID`, pick up to 2 partners from a candidate list sorted by `CitizenID`, then apply the drift. Deltas are computed from the start-of-tick snapshot and applied after the pass, so the order a citizen comes up in doesn't change the result.
3. **Citizen choices:** for each citizen by ascending `CitizenID`, check the triggers. If several choices qualify, pick one with a weighted roll. The 2% daily cap is filled in that same ID order.
4. **Event draw:** one roll for "does an event fire today". If one fires, one weighted roll over the eligible deck, sorted by event id.
5. **Event outcomes:** `randomOutcome` branches roll when the option resolves, not when the card is shown.

The tests should cover the same seed and intents giving an identical state hash after N days (it extends `DeterminismTests`), and that each step consumes the same number of RNG draws whether or not an LLM is attached (section 6).

**Separate random streams for each system.** The game seed isn't used directly. Each system derives its own stream: `streamSeed = hash(gameSeed, systemTag)` with tags `map`, `citizens`, `gossip`, `choices`, `events`, `flavor`. Each stream advances only when its own system rolls. Adding a roll to one system never shifts what another produces, so old saves, replays and golden tests stay stable as features grow. The save stores the game seed and each stream's position.

### 4.8 Visual cue per choice (for art)
| Choice or state | Cue |
|---|---|
| Top complaint | thought-bubble icon over the walker: bread, house, briefcase, mask, shield or dove, matching the 6 needs |
| Take a job | briefcase icon, walking to work |
| Quit | storm-off puff, plus a "Hiring" sign on the building |
| Move house | walker carrying a bundle |
| Protest | placard walkers gathering at the Town Hall or district centre |
| Side business | a small stall appears next to their house |
| Turn to crime | shadowy, hooded walker that only appears at night |
| Emigrate | walker with a suitcase heading to the dock and boarding a boat |
| Gossip | two walkers stop, with a speech bubble showing the mood icon |

Event cards reuse the decree card and Pocket Gazette layouts from the art style sheet.

## 5. Random events

Events are the island's weather. They're short, flavourful choices that make each run different, and they're delivered through the existing agenda: a new `AgendaKind.islandEvent`, using the **decree-card layout** from section 3, with options as `AgendaOption`s carrying `AgendaEffect`s.

### 5.1 Pacing
- **Roll once a day.** The base chance is 12%, which works out to about one event every 8 days.
- **Quiet period:** no event for 4 days after the last one, or for 2 days after a crisis resolves.
- **No repeats:** an event can't fire again for 30 days, and the last 3 events drawn are excluded from the draw.
- **Weighted draw:** `weight = base × conditionMultiplier`, from the deck below. An event whose conditions fail gets weight 0.
- **Tone balance:** if the last two events were both bad, good and weird events get ×2 weight for the next draw.
- **Tier:** most events are `advisory`, so ignoring them is allowed, and that lets the default option happen. Hurricane, Strike and Blight are `crisis` tier and block the day until answered.
- **Expiry:** advisory events expire after 3 days, and the "Ignore" or "Not now" option applies on expiry.
- Seeded RNG makes it deterministic.

### 5.2 The deck (14 events)
Effects use existing `AgendaEffect` fields unless they're marked **new**.

| # | Event | Tone | Trigger | Choices and consequences | Headline |
|---|---|---|---|---|---|
| 1 | **Hurricane season** | bad | day 20 or later, weight 3, ×2 if there's a dock | **Batten down** (−200 treasury, nothing destroyed) · **Ride it out** (1–2 random buildings damaged, **new**: building disabled for 5 days; unrest +5) | "Hurricane batters the island" |
| 2 | **Foreign trade offer** | good | dock exists, weight 4 | **Sell surplus food** (−food from markets, +300 treasury, Merchants ▲▲) · **Refuse** (Labourers ▲) | "Foreign freighter offers coin for our harvest" |
| 3 | **Carnival** | good | happiness ≥ 50, market exists, weight 4 | **Fund it** (−150, all-island unrest −8, Merchants ▲, Labourers ▲) · **Skip** (nothing) | "Carnival fills the streets of {district}" |
| 4 | **Dockworkers' strike** | bad | Labourers favor ≤ −10, weight 5 | **Meet demands** (civic wage +1, Labourers ▲▲, Merchants ▼) · **Break the strike** (unrest +10 in district, legitimacy −4, Labourers ▼▼▼) · **Wait** (production buildings at 0% for 3 days, **new**) | "Dockworkers down tools in {district}" |
| 5 | **Celebrity visit** | weird | treasury ≥ 400, weight 2 | **Host a gala** (−250, legitimacy +5, Officials ▲) · **Decline politely** (nothing) | "Famous crooner drops anchor in our harbour" |
| 6 | **Smuggler ring** | bad | corruption ≥ 30 or a dock exists, weight 3 | **Raid them** (−100, corruption −6, Merchants ▼) · **Take a cut** (+200, corruption +8, legitimacy −3) | "Smugglers caught running rum through {district}" |
| 7 | **Crop blight** | bad | 2+ farms, weight 3 | **Burn the fields** (farms at 0% for 3 days, then normal) · **Import seed** (−180, food +100) · **Hope** (farms at 50% for 8 days) | "Blight spreads across the {district} fields" |
| 8 | **Tourist boat** | good | dock and market, happiness ≥ 45, weight 3 | **Welcome them** (+150, market food −30, Merchants ▲▲) · **Turn them away** (Landless ▲) | "Tourists flood the market, wallets open" |
| 9 | **Miracle at the well** | weird | weight 2 | **Declare a holy site** (Devout citizens ▲, fun & faith +10 in district) · **Have it studied** (−50, legitimacy +2) | "Villagers swear the well water glows" |
| 10 | **Generous expat** | good | weight 2 | **Accept the gift** (+250, Officials ▼, since it looks like a bribe) · **Name a street after them** (+150, no downside) | "Islander abroad sends money home" |
| 11 | **Rumours of a coup** | bad | legitimacy ≤ 30 or Officials favor ≤ −20, weight 3 | **Purge the plotters** (Officials ▼▼, legitimacy −5, unrest −10) · **Pay them off** (−300, Officials ▲▲, corruption +5) · **Address the nation** (legitimacy +3, works only if happiness ≥ 50, otherwise unrest +5) | "Whispers of a plot in the Ministry" |
| 12 | **Baby boom** | good | food surplus for 10 days, weight 2 | **Celebrate** (+3–5 newborn citizens, housing pressure rises) · **Quietly ignore** (same births, no bonus) | "Cradles full across the republic" |
| 13 | **Stray volcano smoke** | weird | weight 1 | **Evacuate {district}** (−100, district idle for 1 day) · **Keep calm** (50% nothing, 50% unrest +6) | "Strange smoke rises over the hills" |
| 14 | **Fishing bonanza** | good | dock exists, weight 3 | **Free fish for all** (food +150, Landless ▲▲) · **Sell it** (+200, Merchants ▲) | "Nets burst with fish off {district}" |

### 5.3 Card layout
This reuses the section 3 decree card, with three additions.
- **Picture strip:** one illustrated banner per event (art, later). Until then, use a coloured tone bar: green for good, red for bad, purple for weird.
- **"Why now" line**, from the trigger's `CauseFactor`: "Labourers' favor has fallen to −14".
- **Each option shows its effect chips**, just like a decree. The default or ignore option is marked "(if ignored)".

Headlines go into the section 3 newspaper feed under the event's tone, and the chosen option shows as a subhead ("The President battened down the hatches").

### 5.4 Visible on the island
Every event has a world moment:
- **Hurricane:** rain, shaking trees, damaged roofs.
- **Trade offer and tourist boat:** a ship docks.
- **Carnival:** lanterns and crowds at the market.
- **Strike:** placard walkers outside the workplace.
- **Celebrity:** a parade from the dock to the Town Hall.
- **Smugglers:** a night boat with lantern flickers.
- **Blight:** fields turn brown.
- **Miracle:** a glowing well and a queue of people.
- **Coup rumours:** officials huddled at the Town Hall at night.
- **Baby boom:** prams on the streets.
- **Volcano smoke:** a smoke plume.
- **Fishing bonanza:** boats with full nets.

### 5.5 New core fields needed (next round)
- `AgendaKind.islandEvent`, and an `EventDeck` catalogue as pure data, like `DecreeCatalogue` (id, tone, weight, condition closure, options, headline template, flavor).
- `RepublicState.eventHistory` (last fired day per event id, plus the last 3 ids), and `lastEventDay`.
- `AgendaEffect` additions: `disableBuildingDays`, `productionPercentDays` (percent plus days, for strike and blight), `spawnCitizens`, `districtNeedDelta` (need index plus amount), `randomOutcome` (a 50/50 branch, resolved with seeded RNG).
- `BalanceConfig`: event base chance, quiet days, repeat window, tone-balance multiplier.

### 5.6 Rare one-off events
At game start, the `events` stream picks **2–3** of these. Each fires at most once, at a random day in its window, as long as its conditions hold.
| Event | Window | Choices | Headline |
|---|---|---|---|
| **Sunken galleon found** | days 15–60, dock exists | **Salvage it** (+600, Merchants ▲▲) · **Museum** (legitimacy +6, fun & faith +10 island-wide) | "Divers find a Spanish galleon off the reef" |
| **Rival island's envoy** | days 30–90 | **Alliance** (trade +, Officials ▲, Labourers ▼) · **Snub** (legitimacy +4, no trade) | "Envoy from San Esteban requests an audience" |
| **Total eclipse** | days 20–80 | **Declare a holiday** (−100, all unrest −10) · **Science lecture** (legitimacy +3, Devout ▼) | "Sky goes dark at noon. Islanders gather in the streets" |
| **Exiled revolutionary returns** | days 40–100, Landless favor ≥ 0 | **Welcome a hero** (Landless ▲▲▲, Officials ▼▼) · **Arrest on arrival** (Officials ▲, unrest +12) | "A famous exile steps off the ferry" |
| **Oil on the beach** | days 25–90 | **Drill** (+250 every 10 days, liberty and happiness −5 in the district) · **Protect the beach** (tourist events ×2 weight) | "Black tar washes up on {district} beach" |
| **Island's centenary** | days 50–120 | **Grand parade** (−300, loyalty +5 for everyone) · **Modest speech** (legitimacy +2) | "The republic turns one hundred" |

## 6. LLM hook (future: small on-device model)

Goal: a small on-device language model can later give citizens and events more personality **without** touching the rules, the determinism, or the frame rate. Version 1 ships with only the rule-based implementation.

### 6.1 What the model may and may not do
- **May:** pick **one option from a list the core has already validated** (which job, protest or not, which eligible event card fires), and write **flavor**: citizen thoughts, gossip lines, newspaper copy, and event card text.
- **May not:** change state, invent options, change numbers, or fire anything the core didn't offer. The core validates every answer, and anything unexpected falls back to the rules.

### 6.2 One narrow interface
```swift
protocol CitizenMind {
    /// options are already legal; returns an index into options plus a short reason.
    func decide(_ ctx: MindContext, options: [MindOption]) -> MindChoice
}
protocol Narrator {
    func flavor(_ req: FlavorRequest) -> String   // thoughts, gossip, headlines, card text
}
struct MindChoice { let index: Int; let reason: CauseKind; let text: String? }
```
- `MindContext` is a small, plain summary: needs, traits, loyalty, memory (3 reasons), faction, and district stats. No raw save data.
- `RuleMind` and `RuleNarrator` are the version 1 implementations. They use the section 4 weights plus seeded rolls, and the template headlines from sections 3 and 5.
- `ModelMind` and `ModelNarrator` come later, wrapping the on-device model behind the same protocols.

### 6.3 Never block a tick
- The core **asks ahead**: at the end of day N it queues requests for the decisions due on day N+1, async, batched once per in-game day, off the main thread.
- When a decision comes due, it uses the model's answer if it has arrived and validates. Otherwise it uses `RuleMind`'s answer. Either way, the answer used is **written to the save** (the decision log), along with which source produced it.
- **Replays read the decision log** and never call the model again, so saves and replays stay fully deterministic.
- To keep RNG usage identical with or without a model, `RuleMind` always runs its roll first. The model's answer can replace the chosen index, but the draw count never changes.
- **Flavor text** can arrive late. The card or newspaper shows the template text first and swaps in the model's line when it arrives. It's cached in the save and never re-generated on load.

### 6.4 Platform options
| | Apple Foundation Models (on-device) | Bundled tiny model (Core ML / llama.cpp-class) |
|---|---|---|
| Availability | iOS 26+, Apple Intelligence devices only, when the model reports itself **ready** (not off, unsupported or downloading) | any device we choose to support |
| App size | none | adds tens to hundreds of MB |
| Effort | small, using Apple's API with guided generation for picking from a list | we own conversion, quantization and updates |
| Fallback | `RuleMind` everywhere else | `RuleMind` on low-memory devices |

- **Minimum target stays iOS 17.0.** The model path sits behind `if #available(iOS 26, *)` plus a runtime readiness check, and every other device uses the rule-based mind.
- **Recommended first:** Foundation Models where it's available, and rules everywhere else. Revisit a bundled model only if the rule-based minds feel flat in playtests.

### 6.5 Budget per in-game day
- At most **one batched request per day**, covering up to about 20 citizen decisions (pick the most salient: protest, emigrate, crime), plus at most 1 event card and about 5 headlines.
- Aim for **under 1.5 s of total model time per in-game day**, entirely off the main thread. If it runs over, the rules' answers stand.
- **Battery:** skip model calls in Low Power Mode, when the device is thermally throttled, or when the game is backgrounded, and use the rules instead.
- Everyone else always uses `RuleMind`. The model shapes a handful of visible "characters" each day, not the whole population.
