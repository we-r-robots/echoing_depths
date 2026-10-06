# Heroes and Classes
*All numbers are placeholders pending balance.*

## Heroes
- **Base classes (starting roster):** Fighter, Rogue, Healer, Mage. More base classes can be added later.
- Heroes have three equipment slots: armor, weapon, and **Relic** (formerly the charm slot). See Relics below.
- Heroes level up by absorbing memories. Auto-battlers usually level units by buying duplicates; memories replace that system.
- Stat growth comes from a hero's class. Alignment determines advanced classes and does not affect stats.
- Each hero has one active ability, replaced at each tier. See the Combat Model in `03-runs-and-combat.md`.

## The Alignment Grid
- Two axes: **Good ↔ Evil** and **Lawful ↔ Chaotic**. *Axis names TBD.* Options that may suit the tone better include Mercy ↔ Cruelty and Order ↔ Freedom.
- The grid is **5×5**, from −2 to +2 on each axis. Positions are written as (Good/Evil, Lawful/Chaotic), with Good and Lawful positive.
- **Each base class has a fixed starting position.** Every hero of a class starts in the same place (e.g. Healer at (+1, +1), illustrative).
- A hero's position at the advancement threshold determines their advanced class.

## Memories
- Memories come from **encounter choices**. Each choice is tied to one hero, based on their class, and carries an alignment shift.
- Taking a choice gives that hero a memory (+1 level) and moves them on the grid. Memories are bound to the hero in the choice and cannot be reassigned.
- **Core tension:** To level a particular hero, the player may have to accept an alignment shift they don't want for them, or pick another hero's choice instead.
- **Movement:** A standard choice moves a hero one step on one axis.
- **Strong shifts:** Rare choices move a hero diagonally (both axes) or two steps on one axis. Their frequency is a tuning lever for how reachable the corners are.

## Progression Tiers
| Tier | How it is reached |
|---|---|
| Base | Starting class |
| Advanced | The hero reaches the advancement threshold (2 memories, user decision 2026-10-05: level 1 + 2 memories = level 3). Their grid position sets the class, and their level resets to 1. |
| Legendary | Further levels after advancing, plus a gate (see below). |

**Terminology TBD.** Options:

| Tier 1 | Tier 2 | Tier 3 |
|---|---|---|
| Base | Awakened | Legendary |
| Kindled | Awakened | Remembered |
| Novice | Awakened | Echo-Bound |

### Holding Back Advancement
At the threshold, the player can choose to suppress a hero's Advancement. The hero keeps absorbing memories and travels farther on the grid, at the cost of fighting without an advanced class during that stretch.

## Advanced Classes
**Every advanced class and variant is unique to its base class.** The base class determines which advancements are possible, and the grid determines which one a hero gets.

### Layered Structure (per base class)
| | Lawful 2 | Lawful 1 | Neutral | Chaotic 1 | Chaotic 2 |
|---|---|---|---|---|---|
| **Good 2** | ★ LG | LG | N | CG | ★ CG |
| **Good 1** | LG | LG | N | CG | CG |
| **Neutral** | N | N | N | N | N |
| **Evil 1** | LE | LE | N | CE | CE |
| **Evil 2** | ★ LE | LE | N | CE | ★ CE |

- **Core classes (5):** Each quadrant (LG, CG, LE, CE) is one class covering 3 cells. The neutral cross (N) is one class covering 9 cells.
- **Corner classes (4):** The corners (★) are distinct classes.
- **Variants:** A hero's exact cell within a region adds a lean modifier (e.g. Lawful lean, Good lean). These come from a shared modifier system rather than being designed cell by cell.
- **Total:** 9 classes per base class, or 36 across 4 base classes.

### Approved Advanced Classes (rounds 1-3, 2026-10-06)
The user approves every class personally (`docs/design/class-verdicts-round1.md` and `class-verdicts-round2.md`; round 3 relayed by the lead; abilities in `docs/design/advanced-class-options.md` and `class-options-round2.md`). Built so far, one per approved region (codes: `LG` Mercy+Order, `CG` Mercy+Freedom, `LE` Cruelty+Order, `CE` Cruelty+Freedom, `N` neutral cross, `*` corner):

| Base (start) | Approved region → class | No approved class yet (stand-in) |
|---|---|---|
| Fighter (N) | N Halberdier, LG Lightsworn, CG Bladebreaker, LE Warden of Chains, CE Berserker, LG★ Aegisbearer, LE★ Iron Marshal, CG★ Echoblade, CE★ Ravager | none |
| Rogue (CE) | N Saboteur, LG Nightwatch, CG Duelist, LE Assassin, CE Cutpurse, LG★ Unseen Warden, CG★ Informant, LE★ Nightshade, CE★ Fadewalker | none |
| Healer (LG) | N Threadmender, LG Cleric, CG Rekindler, LE Tithekeeper, CE Bloodletter, LG★ Lumenward, CG★ Wickburner, LE★ Confessor, CE★ Gravecaller | none |
| Mage (CG) | N Archmage, LG Lampwright, CG Stormwake, LE Runebinder, CE Warlock, LG★ Chronist, CG★ Starcaller, LE★ Reliquarist, CE★ Wildfire | none |

Round-2 and round-3 abilities, as the player reads them:

| Class | Ability |
|---|---|
| Halberdier | Hits the front foe and the foe behind it in the same row. |
| Lightsworn | Aegis Strike: hits the front foe and gives the lowest-HP ally a shield. |
| Bladebreaker | Disarms the strongest front foe for a few seconds: no basic attacks, so no charge from acting, but it still charges from damage and can still use a full bar. |
| Ravager | Whirlwind: hits every foe in the front column and every ally around it (diagonals included), hard. At home in Strays. |
| Warden of Chains | Its chains drag the foe behind the front foe forward (the former Shackler; same ability). |
| Iron Marshal | Drive On now reaches every adjacent ally, diagonals included. |
| Saboteur | Hits the front foe and stops the foes' formation behaviour for a few seconds (their stat bonus stays). |
| Duelist | Riposte: parries the next melee hit on it and answers with a critical counter; lunges at the front foe if nobody swings in time. |
| Nightwatch | Keeps watch: the next foe to hit an ally beside it is struck and stunned (once). |
| Bloodletter | Hits every foe lightly and heals all allies from the damage (a share of 40 % to start). |
| Gravecaller | Raises the fallen as before; with nobody fallen, a nameless husk of the Vault's long-dead, weaker than any raised hero. |
| Reliquarist (was Enshriner) | Keeps the strongest foe (highest Atk or Mag) in a crystal reliquary for a few seconds, as the Lumari kept their memories: it can't act or be hit, and its formation loses it. |
| Aegisbearer | Raises a large shield; while it holds, every foe's melee hits it (a front-column taunt). |
| Informant | Learns the enemy's next move: whoever the next enemy ability will hit gets a shield first. Sits in the back; no damage of its own. |
| Confessor | Retribution flame: brands the foe that last hurt an ally (else the strongest foe); for a few seconds every heal it receives burns it instead. |

- The Paladin retired in round 2; the Lightsworn holds its region and keeps its ability name. Saved Paladins (Echoes, pools, monuments) load as Lightsworn. The Necromancer was dropped in round 1; saved Necromancers load as Gravecallers.
- **PROVISIONAL:** the Lantern Saint (Legendary) now advances from the Lightsworn. The user hasn't confirmed this parent.
- Every region now has an approved class (round 3). The nearest-region stand-in rule stays in the code only as a safety net; no cell uses it.
- **PROVISIONAL (Informant):** if the next enemy ability hits several allies, each gets a shield and the total is split evenly; if no enemy ability is coming soon (no foe at 70+ charge), the weakest ally gets the shield.
- **Advanced is stronger than base** (user rule, 2026-10-06): heroes earn an advanced class by spending memories, so every advanced class beats its own base class at equal level (a tested balance gate); advanced classes are sidegrades to each other.
- **PROVISIONAL:** the Gravecaller with no free front slot strikes the weakest foe (Grave Bolt) instead of raising a husk.
- **PROVISIONAL (Reliquarist, q-9; playtesting will settle these):** (a) a sealed unit still counts as standing, so sealing the last foe can't win; (b) the Fading still damages a sealed unit; (c) a unit just freed from a seal can't be sealed again for 8 s; (d) a sealed front unit counts as not visible for melee targeting, so melee reaches past it (as with hidden units, ruling 1). Nothing else reaches a sealed unit: no hit, heal, status or status tick.

### Stat Budget (ruling 8)
Each base class has one stat budget for its advanced classes: they differ only in how it is spread. Total = HP ÷ 5 + Atk + Def + Mag + Spd at level 1, and the same sum of the per-level growth.

| Base | Level-1 total | Growth total |
|---|---|---|
| Fighter | 104 | 10.0 |
| Rogue | 95 | 8.2 |
| Healer | 89 | 7.5 |
| Mage | 84 | 7.5 |

The budgets are the averages of each base's live advanced classes before the rule; Paladin, Berserker, Duelist, Assassin, Archmage and Warlock were adjusted to them, and the round-2 classes were built on them. Crit chance and charge rates are class identity and sit outside the budget.

### Corner Rarity
Rarity comes from each corner's distance from the class's fixed starting position. For a Healer starting at (+1, +1), with a threshold of 3 and single-axis steps:

| Corner | Steps needed | Rarity |
|---|---|---|
| (+2, +2) | 2 | Reachable normally |
| (+2, −2) and (−2, +2) | 4 | Rare: needs a strong shift or holding back |
| (−2, −2) | 6 | Super rare (e.g. Gravecaller): needs both |

- The far corner's class is the super-rare class for that base class.
- **Extreme classes may be impossible or near impossible to reach without meta progression.** Starting traits from the Adventurers' Guild provide the push. This is an intentional exception to the rule that advanced classes are not gated behind meta progression. The required meta progression should be light.
- The class each position produces stays hidden until the player first reaches it, at which point it is recorded in the codex.

## Relics
- The Relic slot is the **only equipment slot with alignment**.
- A Relic **binds** to a hero once equipped and cannot be swapped out. *Lore for why Relics bind is TBD.*
- **Alignment effect: static offset.** The Relic adds a fixed offset to the hero's underlying grid position. Effective position = underlying position + offset, clamped to ±2.
  - Near a grid edge, the offset acts as a buffer. For example, a hero at Good +2 with a +1 Good Relic who absorbs a −1 memory has an underlying position of +1 but stays at an effective +2.
  - **Fallbacks if more alignment movement is needed:** the Relic pulls the hero one step with each memory absorbed, or the Relic alters the alignment shifts of the memories the hero absorbs.
- Weapons and armor carry no alignment, so the normal item upgrade loop is unaffected.
- **Noted for later:** If more alignment sources are needed to make advanced classes reachable, accepting other items could apply a one-time boon or affliction. It would shift the hero's alignment permanently, stay with that hero, and not transfer or trigger again when the item is swapped.

## Legendary Classes
- Each advanced class has one Legendary version (36 across 4 base classes).
- Becoming Legendary should be a deliberate, difficult choice. Few Legendaries should appear per run.
- **A gate is required.** A **sacrifice** is the favored direction and is to be explored later. Under this approach, carrying a legend requires letting something go.
- Other gate options, which can be combined:
  - The legend's own relic-memory, found deep in the Vault at most once per run.
  - A depth gate, such as a sanctum encounter past a certain floor.
  - A hard cap of one Legendary per party.
- The first time a player reaches a Legendary class, its lore NPC is remembered into Lanternrest. *(Tentative.)*

## Open Questions
- Each base class's starting position on the alignment grid.
- Advanced class, corner class, and Legendary names and identities.
- Variant lean modifiers.
- Advancement threshold and levels from Advanced to Legendary.
- Frequency of strong shifts.
- Holding back rules: whether memories still grant levels while held, what the hero loses while held, and whether there is a limit.
- Relic offset sizes, and whether a Relic can offset both axes.
- Lore for why Relics bind.
- Whether alignment keeps shifting after Advancement, and whether it matters for Legendary.
- Encounter generation: giving players real alignment tension without leaving a hero with no acceptable way to level.
- What happens to memories once every hero is at max level.
- Sacrifice design for the Legendary gate.
- Whether Legendary classes and lore NPCs should exist for all 36 advanced classes, or only some.
