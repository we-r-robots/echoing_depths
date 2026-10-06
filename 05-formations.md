# Formations
*Approved direction, 2026-10-05. All bonus and cost amounts are balance, not spec: they are tuned in code (game/core/data/formations.gd) and may differ from the starting values below.*

## Principles
- **Shapes grow with the party.** At 2 heroes the formations are dominoes, at 3 trominoes, at 4 tetrominoes. Each shape is a smaller shape plus one hero, so a formation builds toward its larger form as the party grows. The party cap stays at 4.
- **Orientation matters.** The same outline is a different formation depending on which cells are in the front column and which in the back. For example, an L with its single block in front differs from one with its single block behind.
- **Every formation gives a stat bonus and a behaviour.** The behaviour must only make sense in that geometry. For example, no "protect the back row" when everyone stands in front.
- **Every formation has a cost.** It's either a debuff or a weakness that follows from the shape.
- **Every behaviour is visible.** When a behaviour fires, the battle shows it on the board (the rule in "Spec non-negotiables").
- **Shapes must be edge-connected.** Heroes placed so that **no two stand side by side** form **Strays**, a real formation of its own (see below). A placement that is partly connected but is no single shape is split into its **connected parts**, and **every part that forms a shape counts** (user decision 2026-10-06, replacing Unformed-gets-nothing): e.g. two separate side-by-side pairs give two 2-hero formations, each with its own bonus and behaviour applied to its own heroes. A part that is no shape falls back to its largest unlocked shape inside it; heroes in no counting shape get nothing. Only a party with no shape anywhere is **Unformed**.
- **Names loosely follow the lore:** the tide of the Fading, the lantern and its Keeper, the Lumari, and memory and echoes.

## Grid Reminder
Each side has 2 columns (F = front, B = back) and 4 rows. Melee hits the front column first, then the back once the front is empty, aiming at the same row or the nearest one. The back column deals and takes half physical damage.

Diagrams below show columns as `F B`, rows top to bottom. `■` is a hero, `·` is an empty slot. A shape can sit at any height in the grid.

## Parts: How a Side's Formation Is Read
*Implemented 2026-10-06 (code: `Formation.effective()` in game/core/formation.gd; data format in game/core/README.md).*
1. Split the placed heroes into **edge-connected parts**. A lone hero is not a part.
2. **No two heroes touch at all:** the side is **Strays** (one formation over everyone). Nothing else below applies.
3. Judge each part on its own:
   - an **unlocked shape** counts as itself;
   - a **locked shape**, or a part that matches no shape, counts as its **largest unlocked shape inside it** (ties go to the shape listed first in this document), on those heroes only;
   - a part with no unlocked shape inside gives nothing.
4. Every counting part gets its own bonus, cost, roles and behaviour, on its own heroes only. A behaviour never reaches across parts: e.g. Kindred's charge goes only to the other Kindred hero, and a Lamplight guardian only covers its own back partner.
5. Heroes in no counting part get nothing (the setup board marks them NO SHAPE).
6. **Unformed** (no formation) only when no part counts.
7. A Saboteur's cut ropes and the Keeper's dimmed lantern stop the behaviour of **every** part on that side. Stat bonuses and costs stay.

Example (the playtest case): Vael front row 1 + Ash front row 2 = **Kindred**; Brakka back row 3 + Corin back row 4 = **Vigil**. The side fights as Kindred + Vigil: Vael and Ash get Front Def +10% and Shoulder to shoulder; Brakka and Corin get Mag +10% and Covering fire.

Echoes recorded before this rule (Echo v1/v2) keep the old whole-side rule, so they replay exactly as recorded.

## Dominoes (2 heroes)
| Shape | Layout | Bonus | Behaviour | Cost |
|---|---|---|---|---|
| **Kindred** | `■ ·` / `■ ·` | Front Def +10% | *Shoulder to shoulder:* when one is hit by melee, the other gains charge. | Nobody guards the back if the line falls. |
| **Vigil** | `· ■` / `· ■` | Mag +10% | *Covering fire:* when one is attacked in melee, the other's next basic action targets that attacker. | No front line: melee reaches them at once. |
| **Lamplight** | `■ ■` (same row) | Back unit Mag/heal +10% | *Guardian:* the front unit intercepts the first ranged or magic hit aimed at its back partner, once per fight. | The front unit takes the extra hit. |

## Trominoes (3 heroes)
| Shape | Builds from | Layout | Bonus | Behaviour | Cost |
|---|---|---|---|---|---|
| **Tidebreak** | Kindred | 3 front | Front Def +15% | *Brace:* a hit on the middle unit passes 20% of its damage to each neighbour. | Spd −5%. |
| **Choir** | Vigil | 3 back | Mag +15% | *Opening volley:* the back row's ATB gauges start fuller, so they act first. | No front line. |
| **Keystone** | Kindred or Lamplight | 2 front + 1 back at an end | Front Atk +10% | *Flank:* the back unit deals +20% to the enemy in its own row. | The front unit next to the gap draws more melee. |
| **Hearth** | Vigil or Lamplight | 1 front at an end + 2 back | Back heal and charge +10% | *Hearthguard:* the lone front unit takes 10% less damage for each living back ally. | That front unit is the only wall. |

## Tetrominoes (4 heroes)
| Shape | Builds from | Layout | Bonus | Behaviour | Cost |
|---|---|---|---|---|---|
| **Seawall** (I) | Tidebreak | 4 front | Front Def +20% | *Share the blow:* 25% of each hit spreads to the unit in the next row. | Spd −10%, and no back row to protect or protect from. |
| **Lumari Chorus** (I) | Choir | 4 back | Mag +20% | *Opening volley* (stronger), plus magic splash +10%. | No front line, and physical attackers deal half. |
| **Vault Door** (O) | Lamplight ×2 | 2 front + 2 back, side by side | All stats +5% | *Hold the door:* when a front unit falls, the back unit in its row steps forward into its slot. | No standout strength. |
| **Crescent** (L) | Keystone | 3 front + 1 back at an end | Front Atk +15% | *Flank* (stronger): the back unit also crits more often against the enemy in its row. | The open end draws melee. |
| **Lighthouse** (L) | Hearth | 1 front at an end + 3 back | Back Mag/heal +15% | *Hearthguard* (stronger), and the lit post draws ranged and magic attacks too, sheltering the three behind it from casters. | The post can fall fast. |
| **Keeper's Ring** (T) | Tidebreak | 3 front + 1 back in the middle | Middle back unit: heal and charge +20% | *Keeper's ring:* while all three front units stand, the ringed unit can't be targeted at all: not by melee, dashes, ranged or magic. | Front units take +5% damage. |
| **Shardpoint** (T) | Hearth | 1 front in the middle + 3 back | The tip gets crit +15% | *Shardpoint:* the tip gains charge whenever an ally behind it acts. | The tip draws every melee hit. |
| **Echo Step** (S/Z) | Keystone or Hearth | 2 front + 2 back, offset | Spd +5% | *Echo step:* the offset spacing halves splash from area abilities. | Def −5%. |

## Strays
Heroes deliberately spread out so that no two stand side by side (edge-adjacent), like scattered memories. Strays is its own formation, available from the start.
- **Bonus:** each unit gets Spd +5% and crit +5%; they hunt alone.
- **Behaviour:** *Scattered:* no splash from area abilities spreads between Strays, since nobody stands next to anyone.
- **Cost:** no shape behaviour ever fires.

## Training Grounds: Unlocking Formations
Any shape can be formed from the first run, but a shape's bonus and behaviour only apply once it is **unlocked at the Training Grounds** in Lanternrest. This matches the original meta-progression spec ("adds formations").
- **A locked shape falls back to its largest unlocked part:** if some heroes in it form a smaller unlocked shape (e.g. a locked Seawall containing an unlocked Tidebreak), the side fights as that smaller shape, and the screens state exactly which shape and bonus apply. If no unlocked part fits, that part gives nothing; when no part of the side counts, it is **Unformed** (no bonus, no cost). This is judged per connected part (see "Parts" above).
- **Unlocked from the start:** the three dominoes and their direct tromino growth (Kindred, Vigil, Lamplight, Tidebreak, Choir), so early runs already have real choices.
- **Unlocked with Shards:** the remaining trominoes and the tetrominoes, as a tree that follows how shapes grow (e.g. Tidebreak leads to Seawall and Keeper's Ring).
- **Fairness:** per the meta principles (variety, not power), every shape has a cost, so unlocks widen options rather than add raw power. An Echo fights with the unlocks its player had when it was recorded.

## Legendary: The Legend's Memory
- **Eligibility:** a hero becomes eligible once they reach advanced level 3.
- **The chance:** from then on, each encounter node has a rising chance to become a **legend's memory**. It starts at 8% and adds 8% after each node where it doesn't appear, up to a 60% cap. It appears at most once per run.
- **The encounter:** it is a special event tied to the hero's advanced class. Taking it is how they become Legendary. Your existing ideas still fit here: the legend's relic-memory, and possibly a sacrifice (giving something up to carry a legend).
- **The cap:** the 1-per-party Legendary cap stays.

## Decided
- Shapes grow with the party, from dominoes to trominoes to tetrominoes. The party cap stays at 4.
- Legendary uses a rising chance.
- Names loosely follow the lore.
- An opponent's formation is hidden until the fight starts (to revisit through playtesting).
- Strays require heroes spread out (no two side by side) and are their own formation. Partly connected placements: every connected part that forms a shape counts on its own heroes (user decision 2026-10-06). A locked shape falls back to its largest unlocked smaller shape, else Unformed (user decision 2026-10-05).
- The Training Grounds unlocks formation bonuses. Drills were dropped as too much to track.
- The legend's-memory numbers stand as drafted for now (8%, +8% per node, 60% cap).
- Strays' bonus doesn't scale.

## Open Questions
- Whether the legend's memory requires a sacrifice.
- The exact Shard cost and order of the Training Grounds unlock tree.
