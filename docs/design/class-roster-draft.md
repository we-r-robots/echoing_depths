# Class Roster Draft (for review)
*Draft proposal, 2026-10-05. Nothing here is implemented or approved yet. Names, numbers and abilities are for you to mark up. Amounts are balance and are left to tuning.*

## 1. What exists today (from code)

| Piece | Where | What it does |
|---|---|---|
| Base classes | `game/core/data/classes.gd` (`BASE_CLASS_IDS`) | Fighter, Rogue, Healer, Mage. Each has a fixed `start_alignment` `[good_evil, lawful_chaotic]`: Fighter `[0,+1]`, Rogue `[-1,-1]`, Healer `[+1,+1]`, Mage `[+1,-1]`. |
| Grid regions | `game/core/alignment.gd` `region_of()` | The 5x5 grid splits into 9 regions: `N` (the neutral cross, any 0), the quadrants `LG CG LE CE`, and the corners `LG* CG* LE* CE*` (both axes at ±2). That makes 9 per base class and 36 in total (`02-heroes-and-classes.md`). |
| Choosing an advanced class | `alignment.gd` `advanced_class_for()`, `game/core/run/run.gd` `_advance_hero()` | At the threshold the hero's effective position (underlying + Relic offset) picks the class with that exact region. A corner without its own class falls back to its quadrant. A region with no class gets the nearest authored class, flagged `placeholder`. |
| Abilities | `game/core/data/abilities.gd` | One schema for every ability: `target` + an `effects` list. The ops are `damage` / `heal` / `charge`. Options include `hits`, `drain` and `bonus_below_hp`, and the targets cover primary, adjacent, column, all and lowest-HP. **There is no status system** (no timed buffs, debuffs, shields or DoTs). The positional logic lives only in formation behaviours and Crystal memory behaviours in `game/core/combat_sim.gd`. |
| Short labels | `game/scenes/party/party_model.gd` `ability_short()` | Generates the ≤ 20-character ability label from the effects. New abilities need an authored `short` label once effects get richer. |
| Legendary gate | `game/core/run/legend_gate.gd`, `run_tuning.gd` `LEGEND_GATE`, `tuning.gd` `MAX_LEGENDARY_PER_PARTY = 1` | Eligibility starts at advanced level 3 (max advanced level is 4). The chance is 8%, +8% per missed node, capped at 60%, and the memory appears once per run. It's only offered when the class has an authored Legendary. |
| Legend's-memory encounters | `game/core/run/legend_memories.json` | Templates exist for all 8 advanced classes, but only Paladin's is live. The dormant names are The Red Tide (Berserker), The Last Blade of Veil (Duelist), The Quiet Hand (Assassin), The Mother of Wicks (Cleric), The Grey Shepherd (Necromancer), The First Scholar (Archmage) and The Debt-Binder (Warlock). |

**Existing advanced classes (8):** Fighter: Paladin (LG), Berserker (CE). Rogue: Duelist (CG), Assassin (LE). Healer: Cleric (LG), Necromancer (CE*). Mage: Archmage (N), Warlock (CE).
**Existing Legendary (1):** Lantern Saint (from Paladin, ability `lantern_oath`).

**Gap worth fixing first:** the region each hero starts in has no class for 3 of the 4 base classes: Fighter `N`, Rogue `CE` and Mage `CG`. The most common outcome for those heroes is a placeholder class today.

## Roster principles used below
- **One stat budget per base class.** All 9 advanced classes of a base class share one stat total and differ only in how it's spread (the "lean"). A corner class is never stronger, only rarer and stranger.
- **Each class answers or enables a play pattern**, not a bigger number: e.g. a formation shape, a counter to a shape, or a way to play the Fading.
- **The back column rule holds with no exceptions.** Physical classes want the front. Back-column classes are magic or support. Nothing ignores the half-damage rule. Moving a unit (§2 Gaoler, Wisp Dancer) changes which column it stands in, and the rule then applies to the new column.
- **Steps** = the fewest single-axis memory steps from the base class's start. The threshold is 3 memories, so anything over 3 needs a strong shift, holding back, a Relic or a Guild trait.

### Mechanic flags
| Flag | Meaning |
|---|---|
| **OK** | Expressible in today's ability schema. |
| **S** | Small schema addition: a new effect op, target or condition (gauge push, "self alone", "Fading active", HP transfer, column pick). |
| **ST** | Needs the **shared timed-status system** (one new system: icon + ≤ 20-character label + duration; used by Shield, Mark, Seal, Hidden, Venom, Overwatch, Vow, Bulwark, Unhealable). Several reuse existing sim hooks: Hidden = `_ring_protected`, Bulwark = `draw`, Vow = Lamplight guardian. |
| **M** | A new mechanic beyond that: moving units, summoning, revival, copying abilities or behaviours. Each one has a precedent in the sim, noted in the row. |

## 2. Advanced classes per base class

### Fighter (start `[0,+1]`, N)
| Region | Steps | Class | Identity (lean) | Ability label | Tooltip | Position | Combos it opens | Flag |
|---|---|---|---|---|---|---|---|---|
| LG | 1 | **Paladin** (EXISTING) | Sustaining front line (HP/Def) | Hit foe + heal ally | Aegis Strike: hits the front foe and heals the most hurt ally. | Front | Seawall, Tidebreak; keeps a lone Hearth post alive | OK |
| CE | 3 | **Berserker** (EXISTING) | Wants to be hit (Atk, high charge on hit) | Front foes x3 | Rampage: strikes random front foes three times. | Front | Kindred (partner hit = charge), Hearth post, Shardpoint tip | OK |
| N | 0 | **Vaultwarden** | The wall that chooses who gets hit (HP/Def) | Draws row melee | Bulwark: for a few seconds, melee aimed at its row neighbours hits it instead. | Front, middle row | Tidebreak / Keeper's Ring middle; shelters Berserker or Duelist beside it | ST (reuses `draw`) |
| LE | 1 | **Gaoler** | Breaks back-heavy shapes (Atk/Def) | Drags foe to front | Chain: pulls the nearest back-column foe into the empty front slot of its row, where it takes full physical damage. | Front | Counters Choir and Lumari Chorus; sets up Assassin and Berserker | M (moves a unit; precedent: Hold the Door) |
| CG | 3 | **Outrider** | Harries casters (Spd/Atk) | Delays a back foe | Ride Down: hits a back-column foe (half physical, as usual) and pushes its gauge back. | Front | Counters Opening Volley; buys time for slow Seawall teams | S (gauge op) |
| LG* | 3 | **Oathkeeper** | Bodyguard for one ally (HP/Def, low Atk) | Guards row partner | Vow: for a few seconds, ranged and magic hits aimed at the back ally in its row land on it. | Front, paired with a back ally | Lamplight, Vault Door; shields a glass Archmage | ST (reuses guardian) |
| LE* | 3 | **Iron Marshal** | Drives allies, at a price (Def/HP) | Allies act sooner | Drive Them On: fills each adjacent ally's gauge, and they lose a little HP. | Front, beside hitters | Archmage, Assassin and Warlock next to it; Vault Door, Crescent | S (gauge op) |
| CG* | 5 | **Knight Errant** | Fights best alone (Atk/Spd) | Alone: hits harder | Lone Stand: hits the front foe, much harder when no ally stands beside it. | Front, apart | Strays; spaced Echo Step | S (condition) |
| CE* | 5 | **Grey Reaver** | Plays for the Fading (HP/Atk) | Stronger in Fading | Fading Edge: hits the front foe, harder once the Fading has begun. | Front | Stall teams (Keeper's Ring, healers); Greycaller (Mage) | S (condition) |

### Rogue (start `[-1,-1]`, CE)
| Region | Steps | Class | Identity (lean) | Ability label | Tooltip | Position | Combos it opens | Flag |
|---|---|---|---|---|---|---|---|---|
| CG | 2 | **Duelist** (EXISTING) | Chains abilities (Spd/Atk) | Front foe + charge | Riposte: hits the front foe and refills part of its own charge. | Front | Shardpoint tip, Crescent | OK |
| LE | 2 | **Assassin** (EXISTING) | Finisher (Atk/crit) | Hits weakest foe | Execute: hits the weakest foe, harder below 40% HP. | Front | Gaoler, Pathfinder; Flank | OK |
| CE | 0 | **Cutpurse** | Starves enemy abilities (Spd) | Steals charge | Pilfer: hits the most charged foe and takes some of its charge. | Front | Denies big casters; feeds Shardpoint and Duelist-style chains | S (precedent: memory `draw_memory`) |
| N | 1 | **Pathfinder** | Spotter for focus fire (Spd, low Atk) | Marks a foe | Mark: marks the weakest foe; allies deal more damage to it for a few seconds. | Back (support, no damage to halve) | Assassin, Archmage, Tempest; Choir | ST |
| CE* | 2 | **Fadewalker** | Strike and vanish (Spd/crit) | Strike, then vanish | Fade Out: hits the weakest foe, then can't be targeted for a moment. | Front | Pulls fire onto Vaultwarden or Paladin; Strays | ST (reuses `_ring_protected`) |
| LG | 4 | **Nightwatch** | Punishes melee on its friends (Def/Spd) | Counters attackers | Overwatch: for a few seconds, it strikes any foe that hits an adjacent ally in melee. | Front, middle row | Tidebreak, Seawall, Keeper's Ring | ST |
| LE* | 4 | **Venomist** | Slow, certain damage (Mag/Spd) | Poisons a foe | Slow Venom: poisons the healthiest foe for magic damage over several seconds. | Back (magic) | Long fights, Keeper's Ring stalls; answers Last Stand | ST |
| CG* | 4 | **Wisp Dancer** | Trades places to dodge (Spd) | Swaps with row ally | Shift: hits the front foe, then swaps columns with the ally in its row. | Front ↔ back | Vault Door, Echo Step; rotates a hurt tank to the back | M (moves a unit; precedent: Hold the Door) |
| LG* | 6 | **Keybearer** | Lumari key thief, super rare (Spd/Mag) | Steals their shape | Unlock: for a few seconds, the foes' formation behaviour goes dark and works for its own side instead. | Back | Hard counter to any one shape; formation mind games in PvP | M (precedent: Keeper's `dim_lantern`) |

### Healer (start `[+1,+1]`, LG)
| Region | Steps | Class | Identity (lean) | Ability label | Tooltip | Position | Combos it opens | Flag |
|---|---|---|---|---|---|---|---|---|
| LG | 0 | **Cleric** (EXISTING) | Party-wide sustain (Mag) | Heal all + hit foe | Sanctuary: heals every ally and smites the front foe. | Back | Choir, Hearth | OK |
| CE* | 6 | **Necromancer** (EXISTING) | Heals by killing (Mag) | Drains weakest foe | Grave Drain: hits the weakest foe and heals itself from the damage. | Back | Assassin focus; Keeper's Ring keeper | OK |
| N | 1 | **Wickkeeper** | Heals whoever stands beside it (HP/Mag) | Heals neighbours | Steady Flame: heals itself and every ally edge-adjacent to it. | Middle of a shape | Keeper's Ring keeper, Tidebreak middle, Vault Door | S (self-adjacent target) |
| LG* | 2 | **Lanternbearer** | Ability engine (Mag/Spd) | Charges all allies | Vigil Light: gives every ally a burst of charge. | Back | Duelist, Archmage, Shardpoint; any ability-heavy party | OK (`charge` to `all_allies`) |
| CG | 2 | **Rekindler** | Second chances (Mag/HP) | Revives a fallen | Rekindle: brings the most recently fallen ally back at low HP, once per fight; otherwise heals the weakest. | Back | Berserker, Knight Errant; Hold the Door | M (revival) |
| LE | 2 | **Tithekeeper** | Moves HP, never adds it (HP/Def) | Moves HP to weakest | Tithe: takes HP from the healthiest ally and gives more back to the weakest. | Back | Big-HP fronts (Vaultwarden, Paladin) feed glass casters | S (HP transfer) |
| CE | 4 | **Bloodletter** | Spreads small drains (Mag) | Drains every foe | Leechcraft: hits every foe lightly and heals all allies from the damage. | Back | Wide fights, Crystal fights, Venomist | S (drain to allies) |
| CG* | 4 | **Hearthwitch** | Heals by column (Mag) | Heals hurt column | Hearth Song: heals every ally in whichever column has lost the most HP. | Back | Seawall (front column) or Choir / Lumari Chorus (back column) | S (column pick) |
| LE* | 4 | **Confessor** | Anti-healer (Mag/Def) | Blocks foe healing | Confess: hits a foe; it can't be healed for a few seconds. | Back | Counters Cleric and Wickkeeper parties and Kindle memories | ST |

### Mage (start `[+1,-1]`, CG)
| Region | Steps | Class | Identity (lean) | Ability label | Tooltip | Position | Combos it opens | Flag |
|---|---|---|---|---|---|---|---|---|
| N | 1 | **Archmage** (EXISTING) | Focused blast (Mag) | Back row + sides | Meteor: hits a back-column foe hard and splashes its neighbours. | Back | Choir, Lumari Chorus | OK |
| CE | 2 | **Warlock** (EXISTING) | Wide damage (Mag) | Back row + all foes | Hexfire: hits a back-column foe and every other foe. | Back | Opening Volley, Lumari Chorus splash; weak into Strays | OK |
| CG | 0 | **Tempest** | Scattered strikes (Mag/Spd) | Random foes x3 | Chain Lightning: strikes random foes three times (not splash, so Strays and Echo Step don't stop it). | Back | Answers Strays; spreads chip damage on the Crystal's memories | OK (`random_enemy`, `hits`) |
| CG* | 2 | **Spellsinger** | Tempo for the whole party (Spd/Mag) | Hastens allies | Quickening: pushes every ally's gauge forward. | Back | Opening Volley, Choir; front Seawall teams that lack Spd | S (gauge op) |
| LG | 2 | **Lampwright** | Shields a column (Mag/Def) | Shields its column | Warding Lamp: gives every ally in its column a shield that absorbs damage. | Back (shields the back) or front (shields the wall) | Choir / Lumari Chorus, Seawall | ST |
| LE | 4 | **Runebinder** | Shuts down abilities (Mag) | Seals foe's charge | Seal: hits the most charged foe; it gains no charge for a few seconds. | Back | With Cutpurse, a full anti-ability party; counters Lanternbearer | ST |
| LG* | 4 | **Glasswright** | Builds walls of crystal (Mag/Def) | Raises crystal wall | Crystal Wall: raises a crystal barrier in an empty front slot; it never acts and draws melee until it breaks. | Back | Gives Choir / Lumari Chorus a front line; Strays gaps | M (summon; precedent: the inert Crystal unit) |
| CE* | 4 | **Greycaller** | Calls the Fading early (Mag/HP) | Brings the Fading | Call the Grey: hits a foe and brings the Fading closer. | Back | Grey Reaver; Bloodletter and Venomist late game | S (precedent: memory `hasten_fading`) |
| LE* | 6 | **Mnemonist** | Steals a foe's memory, super rare (Mag) | Casts foe's ability | Recall: casts the target foe's own ability against its side. | Back | Reads the enemy party; mirrors whatever they brought | M (ability copy) |

## 3. Legendaries
Today the spec has one Legendary per advanced class (36), and the code has a legend's-memory template for each of the 8 existing classes. This draft proposes **one headline Legendary per base class**, each reachable from a small family of related advanced classes, to cover the roster without authoring 36 at once (see open questions).

| Legendary | Base | Grows from (advanced Lv 3) | Stat lean | Behaviour (label + tooltip) | Lore |
|---|---|---|---|---|---|
| **Lantern Saint** (EXISTING) | Fighter | Paladin | HP/Def | *Lantern Oath*: cleaves the front foe and heals the most hurt ally. | Held the first Lanternrest gate alone for a night and a day. |
| **The Red Tide** (proposed; dormant name) | Fighter | Berserker, Grey Reaver, Knight Errant | Atk/HP, low Def | **"Rises as allies fall"**: gains Atk and charge each time an ally falls; the blow that would fell it grants one last action first. | A warlord whose fury held back the first Fading for a season. |
| **The Quiet Hand** (dormant name) | Rogue | Assassin, Fadewalker, Cutpurse | Spd/crit | **"Unseen until it acts"**: it can't be targeted until its first action, and each foe it fells refills its gauge. | Nobody remembers his face. That was the point. |
| **The Mother of Wicks** (dormant name) | Healer | Cleric, Wickkeeper, Lanternbearer, Rekindler | Mag/HP | **"Relights a fallen"**: once per fight, the first ally to fall rises at a quarter of their HP; her heals also give charge. | Kept the sick alive through the first Fading with a candle and a refusal. |
| **The First Scholar** (dormant name) | Mage | Archmage, Lampwright, Mnemonist, Runebinder | Mag, low HP | **"Unfinished equation"**: each ability she casts strengthens her next one; at the third, she casts it twice. | The Lumari who first wrote memory into crystal. |

The other dormant templates (The Last Blade of Veil, The Grey Shepherd, The Debt-Binder) stay ready for a second wave, attached to Duelist, Necromancer and Warlock.

**Making them feel rare** (on top of the existing advanced Lv 3 gate, the rising chance, once per run and 1 per party):
- **A sacrifice when accepting:** the hero's Relic is absorbed into the legend (lost), or, with no Relic, the party loses 1 health. Declining keeps the existing "ordinary memory" choice.
- **Family-locked:** only the listed advanced classes can receive each legend's memory, so a run has to aim for it.
- **Visible weight:** a unique battle intro card for the legend, a legend crest on the PvP splash and Monument, and the lore NPC remembered into Lanternrest on first reach (spec, tentative).

## 4. Open questions for you
1. **One Legendary per base class (this draft) or per advanced class (spec: 36)?** A middle path is one per family now and more later.
2. Is **moving units** (Gaoler drag, Wisp Dancer swap) acceptable? The column rule still applies after the move, but it changes the board mid-fight. Does the formation shape stay as computed at fight start (the way Hold the Door works today)?
3. **A shared timed-status system:** do you approve it? About 10 classes need it. The alternative is reworking them into instant effects only.
4. **Summons** (Glasswright's wall): should a summoned unit count toward formation shapes? The draft says no.
5. **Two super-rare 6-step corners** (Keybearer, Mnemonist) steal the enemy's shape or ability. Is that the right flavour for "extreme" corners, or should corners stay simpler?
6. **The Legendary sacrifice**: is the Relic or 1 party health right, or should it be something else (levels, a memory)?
7. **Names:** are any of these off-tone? (Possible swaps: Outrider → Lantern Rider, Gaoler → Chainwarden, Tempest → Stormwake.)
8. Should **lean variants** (the hero's exact cell inside a region) tweak these abilities, or only stats?

## 4b. User answers (2026-10-05)
**Process: the user approves each class before any work goes into it.** This draft is a proposal only; nothing in it is approved for building yet. Classes are reviewed with the user one by one (or family by family) before implementation.
1. **Legendaries: one per advanced class** (36, as the spec says), not one per base class. Also worth exploring: a Legendary for a **base class levelled to 6**.
2. **Moving units: yes, as swaps only** (two units trade places), so it shakes up formations without breaking the formation-bonus logic. Watch it for balance; it may be strong.
3. **Statuses: yes**, build the shared timed-status system (needed across the larger roster).
4. **Summons and shapes: undecided.** User idea: in the formation setup screen the player picks the tile a summoner summons to; if two summoners target the same tile and a cast lands while that tile's summon is still alive, the summon levels up instead of being replaced.
5. *(Corner shape/ability stealers: not yet answered.)*
6. **Legendary sacrifice: undecided.** The user's only idea so far is sacrificing another hero, which may be hard to balance.
7. **Names:** the user is fine with letting players rename heroes. (Question 7 was about class and Legendary names; still open.)
8. **No lean variants: every class is unique.** The grid's regions already divide the classes; don't tweak abilities by exact cell.

## 5. What I'd build first
1. **Fill the starting regions** so no common hero becomes a placeholder: Vaultwarden (Fighter N), Cutpurse (Rogue CE), Tempest (Mage CG). These are OK/S only.
2. **Small schema additions:** the gauge op, effect conditions (alone, Fading active), self-adjacent and column targets, HP transfer, and drain to allies. Together they unlock Outrider, Iron Marshal, Knight Errant, Grey Reaver, Spellsinger, Wickkeeper, Tithekeeper, Bloodletter, Hearthwitch, Greycaller and Lanternbearer.
3. **Authored `short` labels and tooltips** in ability data (`ability_short()` can't phrase the new effects).
4. **The shared timed-status system** with icons. It unlocks Pathfinder, Fadewalker, Nightwatch, Venomist, Oathkeeper, Lampwright, Runebinder and Confessor.
5. **Legendary families:** make the gate family-aware, and turn on The Quiet Hand, The Mother of Wicks, The First Scholar and The Red Tide.
6. **The M mechanics**, one at a time with playtests: movement, summon, revival, then ability and shape stealing.
