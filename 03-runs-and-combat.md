# Runs and Combat
*All numbers are placeholders pending balance.*

## The Map
- Each run generates a map similar to Slay the Spire's.
- **The map is never player-facing.** It only determines the possibilities available in a run.
- Each encounter presents choices about how to handle it. Each choice silently determines the next node on the map, and the player does not know which choice leads where.
- Players never see upcoming encounters, so the map does not influence their choices.

## Encounters
- Encounters include monsters, riddles, chance events, recruitment, and PvP against Echoes.
- Choices in non-PvP encounters are tied to the heroes in the current party, based on their classes, and each carries an alignment shift. Recruiting a hero adds choices tied to that hero. See `02-heroes-and-classes.md`.
- Rare choices carry strong shifts (diagonal or two steps).
- Players can find items through encounters to power up their heroes. Only Relics carry alignment, and they bind on equip.

## Party
- Players start by choosing from an offered pool of heroes and begin with two heroes.
- Players can have a maximum of four heroes.

## Run Structure
A run moves through three phases:
1. **Gathering (early):** Several encounters take place before the first PvP fight. Recruitment is prominent, and memories build base levels. This phase persists through the first few PvP fights.
2. **Advancement (mid):** Heroes reach the advancement threshold and become advanced classes.
3. **Legend (late):** The Legendary gate becomes reachable.

## PvP
- Rival parties are Echoes of real players' parties.
- PvP fights occur at fixed points in the run. After the opening Gathering encounters, PvP is planned for roughly every other encounter.
- **Win:** The party advances. No memory reward is currently planned.
- **Loss:** The party loses health.
- The run ends when the party's health is depleted or when the Vault is completed.

## Combat Model
- Fights play out automatically with no player input.
- **Speed timeline (ATB-style):** Each hero has an action gauge that fills at a rate set by Spd. When full, the hero acts and the gauge resets.
- **Stats (JRPG-lite):** HP, Atk, Def, Mag, Spd.
  - Physical damage compares Atk against Def.
  - Magic damage compares Mag against Mag. *(Tentative: Mag covers both magic damage and magic resistance.)*
- **Charge-based abilities:** Each hero has a charge meter that builds when they act and when they take damage. When full, the hero casts their ability at the very next action boundary, ahead of any waiting basic attack; abilities and basic attacks run on separate timers, so the cast doesn't use up the attack gauge (user rule, 2026-10-06). Charge rates differ by class.
- **One ability per tier:** Each hero has one active ability, replaced when they advance (Base → Advanced → Legendary).
- **Ending a fight:** A fight ends when one side has no heroes standing. Damage escalates after a set time (sudden death) to prevent stalemates.

## Formations and Group Buff System
- **Grid:** Side view in the style of FF1. Each side has two columns (front and back) of four slots each. A party of four fills four of the eight slots.
- **Targeting** *(proposed)*:
  - Melee attacks hit the enemy's front column (the back column once the front is empty), targeting the same row or the nearest occupied row.
  - Ranged attacks and magic can hit any slot. Each ability defines its own target.
  - Heroes in the back column deal and take half physical damage. Magic is unaffected.
- Different formations provide different buffs. For example, three heroes in the back column with one in front, shaped like a tetromino, could provide a defensive bonus, while other formations might improve damage or status effects.
- Every formation has at least one buff and at least one debuff.
- *Possible feature:* small buffs that depend on base class composition (e.g. "Well Rounded" for having four different classes).

## Memory Supply
Memories come only from non-PvP encounters, so a run's memory total is roughly the number of non-PvP encounters.

Reference for sizing runs, comparing threshold schemes (advance + Legendary):

| Scheme | Per-hero max | All 4 Advanced | Full party maxed |
|---|---|---|---|
| 3 + 3 | 6 | 12 | 24 |
| 3 + 5 | 8 | 12 | 32 |
| 4 + 4 | 8 | 16 | 32 |
| 3 + 6 | 9 | 12 | 36 |

Meaningful choices happen between "All 4 Advanced" and "Full party maxed." Below that range, parties feel underpowered; near the top, every hero is maxed and choices stop mattering. The Legendary gate further limits how many heroes reach the top tier.

## Run Rewards
**Every run, win or lose:**
- **Glimmers:** Memory fragments scaled by depth reached and PvP wins. Enough Glimmers form into a Shard.
- **Lore items:** Kept regardless of the run's outcome.
- **Depth milestones:** Reaching a new floor for the first time grants a one-time reward.

**Victory only:**
- A full **Shard**, granted immediately. A victory should be worth several losing runs' worth of Glimmers.
- A **Monument record** of the winning party. See `04-meta-progression.md`.
- A **Vault Heart memory:** bonus Lumari lore from the final chamber. It deepens the story but is not required to follow the main plot.

## Statuses and Rulings (2026-10-06)
- **Timed statuses** are built (`game/core/data/statuses.gd`): stun, blind, sap and boon, slow, poison, burn, regen, shield, hidden, heal block, heal inversion, charge seal and damage link; round 2 adds disarm (no basic attacks), sabotage (the side's formation behaviour stops), riposte (a parry stance), watch (a guard over the allies beside it), enshrine (sealed in crystal) and seal immunity. Each has a duration, a source and a stacking rule.
- **Status damage is non-physical:** the back-column halving never applies to it.
- **Hidden units:** melee skips a hidden front unit to the nearest visible front unit, and reaches the back column only when no visible front unit stands. Area attacks still hit hidden units.
- **Fight end:** a unit at 1 HP is standing, so its side has not lost. Summons never count as standing.
- **Charge:** a unit gains no charge while a summon it called still stands (narrowed after playtest, 2026-10-06: statuses it puts on others no longer stop its charge). The Fading's damage builds no charge. Hits taken during an ability charge a unit only up to 99, so one ability never readies another.
- **Summons** (Echoblade's echo, Gravecaller's husks, nameless husks included) don't count toward formation shapes.
- **Sealed units** (Enshriner, PROVISIONAL): a unit sealed in crystal still counts as standing and still takes the Fading's damage, can't be sealed again for a while after release, and counts as not visible for melee targeting.
- **Stun:** no diminishing returns yet; playtest first.

## Open Questions
- Targeting rules (confirm the proposal above).
- Back row: should ranged physical attacks hit for more (user note, ruling 2)?
- How weapons and armor affect stats and abilities.
- Sudden death timing.
- *Possible feature:* variant lean modifiers act as passives, differentiating heroes of the same advanced class in combat.
- Total encounters per run, length of the Gathering phase, and number of PvP fights.
- Party health: amount, and loss per PvP defeat.
- Whether some encounters grant more than one memory.
- Whether PvP wins grant any reward beyond advancing.
- Matchmaking for Echoes (e.g. by restoration progress or a hidden rating).
