# Crystal of Remembrance: rework proposals
*Design proposal, 2026-10-05. Not approved for building. Replaces nothing until the user picks a direction; then `06-crystal-of-remembrance.md` is rewritten. All numbers are starting points for tuning.*

Sources: `06-crystal-of-remembrance.md`, `docs/design/balance-report-2026-10-05.md` (section 2 and 6), `docs/design/ideas.md` (Crystal rework entry), `docs/design/class-roster-draft.md` (4b and later), `game/core/combat_sim.gd` (`simulate_crystal`, `_spawn_memory`, `_check_fragments`, `_sudden_death_tick`), `game/core/data/memories.gd`, `game/scenes/battle/battle.gd`.

## 1. What's wrong today
- **The Crystal does nothing.** It is an inert HP bag (`inert = true`) in the two middle back cells. The only threat is the memories and the clock, so the final fight has no boss presence.
- **The clock decides the fight, not the memories.** 97% of Crystal defeats are the Fading. Defeated parties have felled all 4 memories 73% of the time. They lose by running out of time on an undefended Crystal.
- **The threat sits at the end, so outcomes collapse to "3 fragments".** 93% of defeats chip exactly 3. No integrity or memory-strength setting spreads this out (balance report, section 2).
- **Memories are speed bumps.** They are monsters with lore text. Beating one changes nothing in the fight, and their behaviours (heal the most hurt memory, take every second Crystal hit) only make the fight slower.
- **A defeat pays more Glimmers than a victory** (74 vs 57). Fragments pay only on defeat, so a Crystal loss looks better on the results screen than a win, even though the Shard makes the win worth more.
- **Later chapters are already a hidden difficulty tier.** The chapter 2-4 sequence wins 54% against chapter 1's 66% with the same parties. That breaks "the story progresses, not the difficulty".

## 2. Rules every proposal shares
| Topic | Rule |
|---|---|
| Fading | **Not in this fight.** The Crystal's own threat is the clock. Every proposal keeps a hard `max_fight_ms` safety stop (defeat if reached; tuned so <1% of fights hit it). BUILD.md's "sudden death is time-based only" line needs a one-line exception for the Crystal. |
| Grid | 2x4 per side. The Crystal keeps the two middle back cells (back column: physical hits on it are halved). Possessed heroes and summons use normal cells and normal rules. |
| Fragments | Every 25% of integrity lost breaks a fragment (unchanged). The 4th frees the Shard. |
| **Payout (fixes the inversion)** | Fragments pay on **both** outcomes. Defeat: 6 Glimmers per fragment chipped, plus the partial fragment pro rata (`round(24 × integrity lost)`, so 0-23 and 24 distinct values). Victory: the full 24 Glimmers **+ the Shard + the Remembrance**. A win always pays more than any loss, even before the Shard is counted. |
| Story | Defeating a memory for the first time writes its codex entry, win or lose (story track, never currency). Which memories appear comes from story progress only. |
| No tiers | Every memory or summon of every chapter is built to one **power budget** and checked by a new test (section 5): against the balance report's 1,120 recorded Crystal parties, each chapter's win rate must sit within ±4 pp of chapter 1. |
| Cues | Every new effect is an icon + label of 20 characters or fewer; the full sentence lives in the shared tooltip. Labels below are counted. |

## 3. Proposals

### A. Resonant Pulse (the user's AoE blast)
The Crystal acts. On a visible timer it pulses light through the party's grid.

| | |
|---|---|
| **Arc** | 1. The Crystal wakes; one memory surfaces; a pulse ring starts filling over the Crystal. 2. Every 8 s, **Resonant Pulse** hits the party. 3. Each fragment changes the pulse's shape (see below). 4. At fragment 3 the pulse interval drops to 6 s: the Crystal is fighting for its life. 5. The Shard breaks free. |
| **Crystal threats** | Pulse shapes rotate by fragment: 0 = **Row Pulse** (the two rows the Crystal sits in, 1-2), 1 = **Front Pulse** (front column, physical), 2 = **Back Pulse** (back column, magic), 3 = **Full Pulse** (everyone, lower damage). Each pulse is % of max HP plus a flat part, so it is not a level check. |
| **Fragments** | Integrity, as today. |
| **Clock** | The pulse itself. Each pulse is +12% stronger than the last (**Resonance** stacks). It escalates from the first second, so a slow party dies at fragment 1 or 2, not only at 3. |
| **Memories matter** | Each memory **amplifies one pulse shape** while it stands (e.g. the Ferryman widens Row Pulse to 3 rows). Felling it removes that amplification: kill order is now a choice made by formation and targeting. |
| **Defeat pays** | Shared rule. |
| **Player sees** | A ring on the Crystal filling to the next pulse; the cells about to be hit glow on the party grid 1.5 s before. Labels: "Resonant Pulse" (14), "Row Pulse" (9), "Front Pulse" (11), "Back Pulse" (10), "Full Pulse" (10), "Resonance x3" (12). |
| **Sim needs** | A Crystal timer (reuse the `_sd_next` scheduling path that `_sudden_death_tick` uses), a `crystal_pulse` event, area damage by cell set (exists for area abilities), memory hooks that modify the pulse. **New: small.** |
| **Risks** | Formations get a hard counter per shape (Seawall eats every Front Pulse). Rotation keeps any one shape from being always wrong. Pulse damage that is too flat makes it a DPS race again. |

### B. Taken (the user's possession idea, in detail)
The Crystal absorbs a hero's memory and makes them fight for it. The party fights its own hero, who comes back in whatever state the hold leaves them.

| | |
|---|---|
| **Arc** | 1. One memory surfaces. 2. At fragment 1 the Crystal **takes** a hero: they walk across to the Crystal's grid, tinted crystal-cyan. 3. The party fights its own hero and the memory; the hold breaks. 4. At fragment 3 it takes again (never the same hero twice in a row). 5. The Shard breaks free. |
| **Who is taken** | The hero **nearest the Crystal**: in rows 1-2 (the Crystal's rows), front column first, then back column, then rows 0/3; ties by highest current HP. Visible and predictable at setup. |
| **Where it goes** | The mirrored cell on the Crystal's side: same row, same column type (a front hero stands in the enemy front column). If occupied, the next free cell in memory spawn order. Its own cell on the party's side stays reserved. |
| **Control duration** | The hold breaks at the first of: **(a)** 10 s, **(b)** the next fragment breaks, **(c)** the hero drops to 25% HP or lower ("shaken free"). So the party frees them by hitting the Crystal *or* by beating them down. |
| **Damage kept** | HP carries over both ways. Damage taken while taken stays; damage the taken hero dealt to its friends stays. Charge is kept; the ATB gauge resets to 0 on each crossing. |
| **Can it die?** | **Default: no.** While taken, hits cannot take it below 1 HP; reaching 25% breaks the hold anyway. *Option for the user:* it can die, and a hero who dies taken stays in the Vault as an Echo (lore fits; very punishing). |
| **On the Crystal's side** | It acts as itself: same basic, same ability, aimed at its former allies (a taken Healer mends memories, a taken Mage casts on the party). It loses its share of the party's formation, and the party's shape is re-evaluated without it ("Shape broken" cue; it reforms on return). It gains nothing extra. |
| **Return** | Walks back to its reserved cell with **"Remembered"**: +25 charge (it remembers who it is). If every other hero falls while one is taken, the hold breaks at once and the hero fights alone: possession can never wipe a party by itself. Never takes the last standing hero. |
| **Formation counterplay** | Decide who stands nearest the Crystal: a sturdy, low-damage Fighter there is a cheap hostage; a Mage there is a disaster. Shapes with empty middle-front cells push the grab to the back column. Melee hits the front column first, so a taken hero placed front is beaten down by melee (fast release, more HP lost); a back-column hostage takes half physical (slower release, more hits on the Crystal instead). Healers soften the cost after return. |
| **Clock** | **Pull** (weak): each hold the Crystal completes on timeout (a) heals it 5% integrity. A party that ignores the hostage loses ground. Pair with A's pulse for a real clock (see F). |
| **Memories matter** | Memories guard the hostage: while a memory stands next to the taken hero, the taken hero takes 30% less damage. Memories now protect something the party wants back. |
| **Defeat pays** | Shared rule. |
| **Player sees** | A crystal tether from the Crystal to the hero; a hold bar under the taken hero showing 10 s and the 25% mark. Labels: "Taken by the Crystal" (20), "Hold breaks at 25%" (18), "Shaken free" (11), "Remembered" (10), "Shape broken" (12). |
| **Sim needs** | **New: medium-high.** A unit changing side mid-fight: `side`, `_sides[]`, `_alive[]`, cell occupancy, targeting (`_select`, `_melee_col`), formation re-evaluation (`in_shape`, `_bid`), a 1 HP floor flag, events `possess` / `release`. Presentation: walk across, tint, tether, hold bar. |
| **Risks** | 2-hero parties lose half their party (mitigate: 6 s hold when 2 stand). Healers on the Crystal's side may stall. Re-evaluating formation mid-fight touches the most delicate code. Players may read "attack your own hero" as a bug: the hold bar and 25% marker must make it obvious. |

### C. The Sleepers (the user's Lumari-memory summons, with lore)
The Crystal stops releasing small folk memories and instead **wakes stored Lumari**: fewer, stronger, authored mini-bosses. A Legendary is a powerful Lumari memory (class roster 4b), so these are the very memories heroes channel when they go Legendary.

| | |
|---|---|
| **Arc** | 1. A Lumari sleeper wakes with a lore card (name, one line, one mechanic). 2. At fragment 2 a second sleeper wakes. 3. Each sleeper felled is **calmed**: it lends the party a Boon for the rest of the fight. 4. At fragment 3 the Crystal re-wakes the first calmed sleeper at half HP ("Re-woken"); its Boon is lost while it stands. 5. The Shard breaks free with the Remembrance. |
| **Crystal threats** | Two sleepers instead of four memories. Each has one signature mechanic that bends the board. Examples (names and lore are **placeholders**; the user and team author Lumari names): |

| Sleeper (placeholder) | Lore line | Mechanic (label) | Boon when calmed (label) |
|---|---|---|---|
| The Door Warden | "She held the Vault door while her people were written into the crystal." (today's Lumari Knight) | Guards the Crystal: melee aimed at the Crystal hits her first ("Holds the door", 14) | Front units take 15% less ("Warden's oath", 13) |
| The Cantor of the Deep Choir | "He sang the census so no name would be dropped. He is still on the first verse." | Every 6 s sings: memories gain charge ("Census song", 11) | Party charge +10% ("The song goes on", 16) |
| The Draw-Wright | "She built the first lens that drew memory out of the world. It felt like nothing at all." | Draws 20 charge from the most charged hero (today's Draw) ("Draws memory", 12) | Her draw now feeds the party ("Lens turned", 11) |
| The Glasswright | "Every Vault wall is a window she ground by hand." | Reflects 25% of magic hit on the Crystal ("Mirror glass", 12) | Magic +10% ("Clear glass", 11) |
| The Archivist Who Wrote Herself Last | "There was no room left on the page." | Copies the heroes' formation (today's Weaver) ("Writes you down", 15) | Formation bonus +50% ("Rewritten", 9) |

| | |
|---|---|
| **Fragments** | Integrity. |
| **Clock** | **Dreaming**: every 5 s while a sleeper stands, the Crystal regains 1% integrity (never past a broken fragment). Sleepers must be dealt with; a stall loses ground but never kills by itself, so the sleepers themselves are what kills. Add A's pulse if that is too soft. |
| **Memories matter** | Boons make kill order a real decision; Re-woken punishes ignoring them. First calm writes the codex and can unlock a Lanternrest NPC (story track). Meeting a sleeper also names which Legendary channels it (a lore hint, never a stat). |
| **"New ones as you win" without tiers** | **(1) Different, not harder:** each chapter adds sleepers to the pool; every sleeper fits one power budget (same HP x damage product against the reference parties), enforced by the ±4 pp test. **(2) The pool widens, it does not replace:** a run draws 2 sleepers from all unlocked, weighted toward the newest, so veterans see more variety, not more power. **(3) Unlocks come from the story track** (wins, unique encounters, Legendaries, BUILD.md), never bought. **(4) Optional "Call a deeper sleeper"** for lore only is listed and **not recommended**: it is a difficulty selector by another name. |
| **Defeat pays** | Shared rule. Sleepers calmed on a loss still write the codex. |
| **Player sees** | Lore card on wake (title, one chip row, mechanic glyph + label); Boon icon added to the party's formation strip. Labels: "Lumari Sleeper" (14), "Calmed" (6), "Re-woken" (8), "Dreaming" (8), plus the table's. |
| **Sim needs** | Mostly data: new memory entries in `memories.gd` with new behaviour ids, a party-side boon list (applied like formation mods), a Crystal regen tick. **New: small-medium.** Art: Lumari sprites (character art direction is undecided, so placeholders). |
| **Risks** | Authoring cost per sleeper (lore + mechanic + tuning). Power budget drift (already happening today). Without a strong clock the fight may feel long. |

### D. The Four Facets
The Crystal is four facets, one per row. Each facet holds one threat; breaking it is a fragment and silences that threat. Formation decides which threats you end first.

| | |
|---|---|
| **Arc** | 1. All four facets light; each shows its threat icon. 2. Heroes strike the facet in their own row (nearest live facet when it is broken). 3. Each broken facet ends its threat and releases its memory, now **calmed** onto the party's side for 8 s as a short ally. 4. The last facet is the Heart: breaking it frees the Shard. |
| **Crystal threats** | Facet 0: **Pulse** (A's row pulse). Facet 1: **Take** (B's possession). Facet 2: **Ward** (memories take 30% less). Facet 3: **Wellspring** (a memory surfaces every 12 s). The facet order is seeded per run so rows matter differently each time. |
| **Fragments** | One per facet broken (each facet = 25% of integrity). |
| **Clock** | The unbroken facets: Pulse escalates, Wellspring keeps adding memories. Leaving a threat up for long is what kills. |
| **Memories matter** | Each facet's memory fights for the Crystal while the facet stands and briefly fights *for you* once it breaks ("remembered kindly", an open question in spec 06). |
| **Defeat pays** | Shared rule (fragments = facets). |
| **Player sees** | Four facet icons stacked on the Crystal, each with its threat glyph and HP pip; setup screen shows them, so formation is planned against them. Labels: "Pulse Facet" (11), "Take Facet" (10), "Ward Facet" (10), "Wellspring" (10), "Facet broken" (12). |
| **Sim needs** | The Crystal as 4 row-bound sub-targets (it spans rows 1-2 today; it would span 0-3 of the back column, leaving memories only the front column), row-based Crystal targeting, per-facet timers. **New: medium-high.** |
| **Risks** | The Crystal filling the whole back column changes the battle layout picture. Row targeting for the Crystal is a special case on top of melee rules. Rich but the hardest to read at a glance. |

### E. Echoes of the Fallen
The lore says heroes who die in a Vault never leave. The Crystal releases **your own fallen heroes** (from earlier defeats) as its memories.

| | |
|---|---|
| **Arc** | 1. The Crystal surfaces an Echo of one of your fallen heroes, with their name, class and how they fell. 2. At each of fragments 1 and 2, another. 3. Felling one **lays it to rest**: its name goes on the Hall of Remembrance's memorial wall. 4. The Shard breaks free. |
| **Crystal threats** | Your own former heroes, with their real abilities. With no fallen heroes yet, authored memories fill in. |
| **Fragments** | Integrity. |
| **Clock** | Needs A's pulse (Echoes alone have no clock). |
| **Memories matter** | Personal stakes, recognisable abilities; laying one to rest is a story beat. |
| **No tiers** | Echoes come at a **fixed memory power budget** (stats normalised to the chapter-1 memory budget, abilities kept), not at the level they died at. |
| **Defeat pays** | Shared rule. |
| **Player sees** | Name plate with the hero's own name and crest. Labels: "Echo of the Fallen" (18), "Laid to rest" (12). |
| **Sim needs** | A store of fallen heroes per player (run end data plus the Echo pool already hold parties), heroes spawned through the memory path with a normalised stat block. **New: medium.** |
| **Risks** | Repetitive for players who lose a lot; early players have none; abilities from the player hero pool make the fight a mirror match rather than a boss. Strong as **one** memory slot inside another proposal, weak alone. |

### F. The Waking Crystal (combination: A + B + C)
The Crystal pulses on a clock, wakes Lumari sleepers, and once per fight takes a hero. Threats are spread across the fight, not stacked at the end.

| | |
|---|---|
| **Arc** | 1. **0%:** the Crystal wakes; Sleeper 1 surfaces with its lore card; the pulse ring starts (Row Pulse every 9 s). 2. **Fragment 1:** the pulse becomes Front Pulse; Sleeper 2 wakes. 3. **Fragment 2:** **Taken**: the hero nearest the Crystal is taken (B's rules). 4. **Fragment 3:** the Crystal cracks open: Full Pulse every 6 s, no new memories; the Remembrance glows inside. 5. **Shard.** |
| **Crystal threats** | Pulse (A), two sleepers (C), one possession (B). |
| **Fragments** | Integrity. |
| **Clock** | The pulse with Resonance stacks (+10% per pulse). It hurts from the first seconds, so defeats spread over fragments 0-3. Target spread to tune toward: no fragment count holds more than 40% of defeats. |
| **Memories matter** | Sleepers amplify one pulse shape while they stand (A) and grant Boons when calmed (C). A sleeper standing next to the taken hero shields it (B). |
| **Defeat pays** | Shared rule. |
| **Player sees** | Pulse ring + glowing target cells; sleeper lore cards; tether and hold bar. At most two new labels on screen at once (pulse and one other). Labels as in A, B, C. |
| **Sim needs** | A (small) + C (small-medium) + B (medium-high). Build order: A, then C, then B, each playable on its own. |
| **Risks** | Busiest fight in the game: readability on a phone. Mitigate by never stacking two new threats on the same beat (the arc already spaces them). Tuning three systems at once. |

## 4. Comparison
| Proposal | Impact | Readability | Build cost | Risk to the no-tiers rule | Lore fit |
|---|---|---|---|---|---|
| A. Resonant Pulse | Medium: real boss, but one-note | **High** | **Low** | Low | Medium (the Crystal "remembering" violently) |
| B. Taken | **High**: the fight everyone remembers | Medium (needs hold bar) | High | Low | High (memory absorbed into the crystal, the Lumari's own fate) |
| C. The Sleepers | High: kill order, Boons, lore | High | Low-medium (data) + authoring | **Medium** (new sleepers per chapter must hold the budget) | **Very high** (Lumari, Legendaries, True History) |
| D. Four Facets | High: formation planned against threats | Low-medium | High | Low | Medium |
| E. Echoes of the Fallen | Medium, personal | High | Medium | Low (normalised) | High, but repetitive |
| F. The Waking Crystal (A+B+C) | **Very high** | Medium | High (staged) | Medium (as C) | Very high |

## 5. Recommendation
**Build F in three playable stages: A, then C, then B.**
1. **Stage 1, A + the payout fix:** turn the Fading off for the Crystal, add the pulse and Resonance, pay fragments on both outcomes. Cheapest change that gives the Crystal presence and fixes "defeat pays more". Re-run the balance report's Crystal counterfactual: success = win rate 55-70% and no fragment count above 40% of defeats.
2. **Stage 2, C:** replace the four folk memories with two Lumari sleepers per fight and Boons. Folk memories stay as floor encounters and story events. Add the **chapter-parity test** (each chapter within ±4 pp of chapter 1 on the 1,120 recorded parties) so "new ones as you win" can never become a tier.
3. **Stage 3, B:** possession at fragment 2. Highest risk, so it lands on a fight that already works.
- E is best as an occasional memory slot inside C later. D is a good second-generation idea if F's fight still feels flat.

## 6. Questions for the user
1. Can a taken hero **die** while taken (and stay in the Vault as an Echo), or does it always come back (1 HP floor)?
2. Who should the Crystal take: **nearest the Crystal** (formation counterplay), the **most charged**, or the **highest level**?
3. Fading **fully off** in the Crystal fight, replaced by the pulse? (BUILD.md needs a one-line exception.)
4. Should Lumari sleepers be **the memories behind specific Legendaries** (meet the Door Warden, later channel her)? Names and lore would come from you and the team.
5. "New ones as you win": **widen the pool, same power** (recommended), or no new ones at all? Confirm the optional harder sleeper is out.
6. Should a calmed memory **fight for you briefly** (D's idea), or only grant a Boon?
7. Payout: 24 Glimmers for the full chip on a win, pro rata on a loss. Fine as a start?
