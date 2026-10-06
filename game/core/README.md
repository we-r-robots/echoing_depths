# game/core — combat simulation

Pure game logic. No nodes, no rendering, no global randomness. Given the same seed and
inputs, `CombatSim.simulate()` returns a byte-identical result (compare with
`JSON.stringify(result, "", true)`). Async PvP Echoes depend on this.

All numbers are placeholders and live in `core/data/*.gd` (plain const Dictionaries).

## Files

| File | What it is |
|---|---|
| `combat_sim.gd` | The simulation. `simulate(seed, party_a, party_b, options) -> Dictionary` |
| `rng.gd` | Own seeded RNG (xoshiro128**, integer-only). Methods: `next_u32`, `next_float`, `int_range`, `float_range`, `pick` |
| `game_data.gd` | Read-only accessors for the data tables + `validate_party()` |
| `hero_stats.gd` | `compute(hero) -> {hp,atk,def,mag,spd}`: class stats at level + equipment (no formation) |
| `formation.gd` | `detect(cells)` formation shape, `compositions(base_ids)` class-composition buffs |
| `alignment.gd` | 5×5 grid, relic offset/clamping, region codes, advanced/legendary class lookup |
| `echo.gd` | Echo snapshot: `make(party, meta)`, `to_json`, `from_json`, `from_dict` (versioned, validated) |
| `narrator.gd` | `narrate(events) -> PackedStringArray` human-readable log (demo CLI, captions, debugging) |
| `party_gen.gd` | Seeded generators: `random_party(rng)`, `monster_group(rng, depth)`, `demo_party()`, `demo_rival()` |
| `data/tuning.gd` | Timeline, damage, crit, back-row, sudden-death numbers; level caps; `DATA_VERSION` |
| `data/classes.gd` | Base classes, the approved advanced classes (one per approved region), the Legendary, Vault monsters; stat budgets (`BUDGET`) and class renames (`CLASS_RENAMES`) |
| `data/abilities.gd` | Basic attacks and abilities (one schema, data-driven effects) |
| `data/items.gd` | Weapons, armor (flat stats), relics (stats + alignment offset) |
| `data/formations.gd` | Formation shapes (buff + debuff each) and composition buffs |
| `data/memories.gd` | Crystal of Remembrance: the Crystal's tuning and the authored memories (chapter, lore, behaviour) |
| `data/statuses.gd` | Timed statuses (stun, blind, sap/boon, slow, poison, burn, regen, shield, hidden, heal block, heal inversion, charge seal, link; round 2: disarm, sabotage, riposte, watch, enshrine, seal immunity): names, short labels, tooltips, icons, stacking rules, tick rates |

Load scripts with `preload` (no `class_name` globals are registered):

```gdscript
const CombatSim = preload("res://core/combat_sim.gd")
const PartyGen = preload("res://core/party_gen.gd")
var result := CombatSim.simulate(42, PartyGen.demo_party(), PartyGen.demo_rival())
for ev in result.events: ...
```

## Commands

```sh
godot --path game --headless -s res://tests/run_all.gd                 # all tests, exit 1 on failure
godot --path game --headless -s res://tests/benchmark.gd [-- --n=1000]  # perf + fight-length distribution
godot --path game --headless -s res://tests/demo_fight.gd [-- --seed=7] # readable log of one fight
godot --path game --headless -s res://tests/balance_classes.gd [-- --runs=1500 --fights=1500]  # class balance (swap test)
#   demo options: --random (two random parties)  --monsters=DEPTH (demo party vs Vault monsters)
```

## Input: party / hero format

A party is `{"name": String, "heroes": Array}`. An Echo dictionary (see below) is also a valid party.

```gdscript
{
  "name": "Brakka",                 # display name
  "class": "fighter",               # id in data/classes.gd (base, advanced, legendary or monster)
  "level": 3,                       # 1..MAX_LEVEL[tier]
  "items": {"weapon": "iron_sword", "armor": "", "relic": "dawn_locket"},  # "" or missing = empty
  "alignment": [0, 1],              # UNDERLYING grid position [good_evil, lawful_chaotic]; not used in combat
  "slot": [0, 1]                    # [col, row]; col 0 = front, 1 = back; row 0..3 top to bottom
}
```

A party may also carry `"unlocked_formations": [shape id, ...]`: the Training Grounds shapes this
side has unlocked. Missing = the default set (`Formations.DEFAULT_UNLOCKED`: Kindred, Vigil,
Lamplight, Tidebreak, Choir). Strays is always available.

**Formation state** (`Formation.effective(party)`, shared with the setup UI):

```
static func effective(party: Dictionary) -> Dictionary
# -> {"state": "active"|"strays"|"unformed"|"locked_fallback"|"locked_unformed",
#     "shape": geometric shape (a SHAPES entry, STRAYS, or UNFORMED),
#     "effective": what fights, "sub_cells": [[col,row], ...], "locked": bool}
```
Cells are read in slot order. A locked shape's fallback is the largest unlocked connected
sub-shape among its heroes (ties: SHAPES data order, then the first such subset in slot order);
its bonus, cost, roles and behaviour apply only to those heroes. Fewer than 2 units: `"none"`.

**Validation** (`GameData.validate_party`, applied by `simulate()` and `Echo.from_*`):
a side is a *monster side* if every unit is a monster class, otherwise a *player side*.
Player sides/Echoes: 2–4 heroes (parties start with two), no monster classes, at most 1 Legendary (`Tuning.MAX_LEGENDARY_PER_PARTY`,
placeholder for the spec's Legendary gate). Monster sides: 1–8 monsters, no heroes. Every hero needs a
String `class` that exists, a whole-number `level` in range (JSON whole floats like `2.0` are accepted,
`2.7` is rejected, never truncated), a whole-number on-grid unique `slot`, `alignment` in −2..2, an
`items` Dictionary with known slot keys holding String ids of items of that slot, and a String `name`
of at most 24 characters if present; `unlocked_formations`, if present, must be an Array of known
shape ids. Any bad input returns `{"error": [String...], "winner": -1, "events": []}`; it never
raises a script error.

## The Crystal of Remembrance

```gdscript
var r := CombatSim.simulate_crystal(seed, party, {"integrity": 360, "memories": ["ferryman", "lamplighters_child", "miller", "weaver"]})
```

The enemy side is the **Crystal** (an inert unit, `tier: "crystal"`, `span: 2`, filling back
column rows 1–2; it never acts, gains no charge, isn't healed, isn't eroded by the Fading and never
counts as standing) plus the **memories** it releases (`data/memories.gd`, `tier: "memory"`). The
Crystal is targeted under the normal grid rules: memories in the front column shield it from melee;
back-first, lowest-HP and other ranged/magic targeting can reach it; physical hits on it are halved
like any back-column target. Memories surface into free enemy slots (front column rows 1, 2, 0, 3,
then back rows 0, 3; if none is free, the memory waits and surfaces when one falls) at the start and
at fragments 1–3. Every 25 % of integrity lost emits `crystal_fragment`; the 4th ends the fight in
victory, `reason: "shard"`, `winner: 0`. If the party falls, `winner: 1`, `reason: "wipe"` (or
`"fading"`/`"timeout"`), and `fragments` says how many were chipped (the run turns them into
Glimmers). The enemy side has no formation (banner id `"crystal_chamber"`). Integrity 360 by
default (`Memories.CRYSTAL`); a late-run party breaks it about half the time.

## Output: result dictionary

| Key | Type | Meaning |
|---|---|---|
| `winner` | int | `0` side A, `1` side B, `-1` draw |
| `reason` | String | `"wipe"`, `"fading"` (ended during a sudden-death tick: the Fading), `"timeout"` (hard cap; should never happen), `"shard"` (Crystal fight: the 4th fragment) |
| `duration` / `duration_ms` | float / int | fight length in simulated seconds / ms |
| `sudden_death_ticks` | int | ticks that occurred |
| `survivors` | Array[int] | uids standing at the end |
| `seed`, `data_version` | int | inputs echoed back |
| `fragments` | int | Crystal fragments chipped (0–4; always 0 outside the Crystal fight) |
| `events` | Array[Dictionary] | the event log below (empty if `options.log == false`) |

Options: `{"log": false}` skips building events (same outcome, faster);
`{"tuning": {...}}` overrides keys of `Tuning.COMBAT` and of `Statuses.TUNING` (used by tests);
`{"start_statuses": [{"side", "slot": [col,row], "status", "dur_ms", ...effect keys, "src_side",
"src_slot", "from_ability"}]}` puts statuses on units at t = 0 (tests and tools only; the effect keys
are those of an ability's `status` effect, below); `{"start_hp": [{"side", "slot", "hp"}]}` starts
units hurt (tests and tools only; set after `fight_start`, whose snapshots show full HP).

## Event log schema

`tests/test_schema.gd` checks every event of ~1000 fights (including forced sudden death) against
this section: exact field set, types and enumerated values. If the two ever disagree, that test fails.

**Schema changelog** (for consumers):
- *Latest: round-2 classes (2026-10-06, class-verdicts-round2.md).* No new event types. New status
  ids **`disarm`**, **`sabotage`**, **`riposte`**, **`watch`**, **`enshrine`**, **`seal_immune`**;
  `status_end.reason` gains **`"triggered"`** (a Riposte stance spent on a parry, a watch that caught
  an attacker); `miss.reason` gains **`"parry"`** (the Duelist parried the hit: no `damage` event;
  its counter follows at the same `t` as a `damage` event from the Duelist with action
  `"riposte_counter"`, always a crit); `skip.reason` gains **`"disarm"`** (a disarmed unit's turn
  passes without a basic attack). A Nightwatch's catch is a `damage` (action `"watch_strike"`) plus a
  `stun` `status`, at the same `t` as the hit it caught. Both reactions come from a unit that is not
  the acting one, inside another unit's action. Ravager's Whirlwind lands its ally hits and
  Bloodletting lands its heals 0.15 s after the action's impact (effect `delay_ms`). A nameless husk
  (Gravecaller, nobody fallen) is a `spawn` with `summon: "husk"`, `raised: -1`, unit `class`
  `"nameless_husk"` and `class_name` `"Nameless Husk"` (base class `"fighter"`: no art of its own).
  Class `paladin` is gone (saved Paladins load as `lightsworn`); `shackler`'s display name is
  "Warden of Chains".
- *Latest: timed statuses, approved advanced classes, rulings (2026-10-06, class-verdicts-round1.md).*
  New events **`status`**, **`status_end`**, **`miss`**, **`skip`**, **`absorb`**, **`move`**,
  **`gauge`**, **`revive`** (below). Damage kind **`"status"`** (poison/burn ticks, hexed heals, HP
  costs; never halved by the back column) with mod/primary ids `poison`, `burn`, `heal_invert`,
  `cost`, `tithe`, `link` (a linked partner's share; it can also appear on physical/magic hits).
  `action_start.area` gains **`"column"`** (Hexfire's column of fire, hit space by space up the
  column; each unit's `damage` is stamped when the fire reaches it). `spawn` gains **`summon`**
  (`""`, `"echo"`, `"husk"`), **`summoner`** (uid, −1 for Crystal memories) and **`raised`** (the
  fallen uid a husk was raised from, else −1); summons use `reason` `"summon"` / `"raise"`, empty
  `memory`/`lore`, `chapter` 0, and unit `tier` **`"summon"`**. A fully absorbed hit has no
  `damage` event (only its `absorb`). Hidden units are never single-targeted (melee skips a hidden
  front unit to the nearest visible one, and reaches the back only when no visible front unit stands).
- *Latest: formation states (05-formations.md, user decision).* `Formation.effective(party)` returns
  `{"state", "shape", "effective", "sub_cells", "locked"}` (contract below). **Strays** = no two
  heroes edge-adjacent (always available); **Unformed** = partly joined, no shape (no bonus, cost or
  behaviour; id `"unformed"`, "No formation"); a **locked** shape falls back to its largest unlocked
  connected sub-shape among the placed heroes and fights as that shape on those heroes only, else
  Unformed. The banner `formation` gains `state` and `sub_cells`. Draw/taunt use the single melee
  definition (physical melee-targeted or dash; only the Lighthouse taunt also pulls single-target
  ranged/magic); Keeper's Ring also guards against `to: "random_enemy"`; a Lighthouse taunt beats
  Vigil covering fire.
- *Latest: the Crystal of Remembrance (06-crystal-of-remembrance.md).* New entry point
  `CombatSim.simulate_crystal(seed, party, {"integrity", "memories"}, options)`. New events
  **`spawn`** and **`crystal_fragment`**; new end `reason` **`"shard"`**; `fight_end` (and the
  result) gain **`fragments`**; unit snapshots gain **`span`** (1, or 2 for the Crystal) and tiers
  `"memory"` / `"crystal"`; charge `reason` `"drain"`; damage mod ids `harvest`, `mirror`; memory
  behaviour cues are `formation_proc` with `source: "memory:<id>"`. Uids of spawned memories
  continue after the existing units.
- *Latest:* Scattered only spares Strays not standing next to the struck unit (a locked, connected
  shape takes normal splash); Guardian ignores area/splash hits; covering fire respects Keeper's
  Ring; Brace/Share numbers from a back-row attacker also carry `back_row_attacker`.
- *Earlier:* Keeper's Ring keeper can't be single-targeted at all while the ring stands (any
  selector; splash still hits); the Lighthouse post also draws single-target ranged/magic attacks.
  `game/core/run/run.gd` now passes `unlocked_formations` (run option) and the monument records
  the shape that actually fought.
- *Formation redesign (05-formations.md).* Shapes are dominoes/trominoes/tetrominoes
  (Kindred, Vigil, Lamplight; Tidebreak, Choir, Keystone, Hearth; Seawall, Lumari Chorus, Vault Door,
  Crescent, Lighthouse, Keeper's Ring, Shardpoint, Echo Step) or Strays; the old 11 shapes and
  Loose Ranks are gone. Parties may carry `unlocked_formations`; a locked shape fights as Strays (superseded: see formation states).
  `formation` (in `fight_start` sides and the banner event) gains `shape`, `shape_name`, `locked`,
  `behaviour` `{id, name, text}` and `cost` (text); `buffs` = the shape's bonus, `debuffs` = the
  cost's stat part (may be empty: some costs are a weakness of the geometry). `formation_proc`
  gains `effect` and `related`; behaviour cues have `stat: ""`. New event **`formation_move`**
  (Hold the door). New damage mod/primary ids: `brace`, `share_the_blow`, `flank`, `hearthguard`,
  `echo_step`, `chorus_splash`. New stat `dmg_taken_pct`. Echo **v2** stores `unlocked_formations`.
  The composition "Choir" (2+ Healers) is renamed `choir_of_healers` (the shape owns "Choir").
- *Latest (after critic round 5):* `damage.primary` id `back_row` is replaced by
  `back_row_attacker` (0.5), `back_row_target` (0.5) or `back_row_both` (0.25), so the annotation
  says whose back row. Formation cues are now **strictly truthful** (the cue backlog is removed; see
  `formation_proc`). On a Fading tick that wipes both sides, both sides' numbers land at the same
  instant. Player-facing text for damage kind `"sudden_death"` is "fades for N" / "the Fading".
- *Latest (after critic round 4):* sudden death is **time-based only** (user decision): the
  last-stand early start is gone, so `fight_start.sudden_death_at` is always when it begins. In the
  fiction it is **the Fading** (the battle's memory fading: drain the arena toward Fading grey, no
  generic "SUDDEN DEATH" label). The fight-ending `reason` for it is now **`"fading"`** (was
  `"sudden_death"`); event type `sudden_death` and damage kind `"sudden_death"` keep their names.
  Ticks are spaced 1.5 s from when each actually fired. `vs_back_column` removed: a back-column
  target always takes ×0.5 physical and the `back_row` tag is the true net factor. Every
  formation/composition effect (small ones too) now cues once per fight.
- *Latest (after critic round 3):* mod/primary id `pierce` **removed** (Backstab/Execute are halved
  into the back column like everything else); new `charge.queue` field; `formation_proc` only for
  effects ≥ 10 %, once per fight per effect, never for a KO'd unit, never on a hit that already carries
  a formation tag (~3 per fight); heal abilities with nobody to heal report the smite target and
  `anim: "cast"`; sudden death can start early (4 s after a side is down to its last unit).
- *After critic round 2:* new event `formation_proc`; new damage field `primary` (the one annotation to show); sudden-death `damage.mods` entries are `{"id": "sudden_death", "mult": 1.0}`
  Dictionaries (they were wrongly bare Strings); formation mods on hits only at ≥ 10 %; side B's
  sudden-death numbers land 0.2 s after side A's; `action_start.area` can be `"all_enemies"` while
  `target` is a uid (a primary hit plus splash on everyone else).
- *After critic round 1:* `mods` became `{id, mult}` Dictionaries; `formation` event; `label`; `charge.ready`.

Every event is a Dictionary with:

- `"type"`: String, one of the types below.
- `"t"`: float, simulated seconds since fight start (millisecond precision; `t = ms / 1000.0`).

**Ordering guarantee:** events are sorted by `t` (non-decreasing). Events with equal `t`
are in causal order (e.g. `damage` → `charge` → `ko`). The first event is always
`fight_start` and the last is always `fight_end`.

**Names:** always display a unit by its `label` (from `fight_start`), not `name`: labels are unique
per side (duplicate names become `"Tamsin 2"`, `"Tamsin 3"`). The generators also give every unit on a
side a distinct name (monsters of one kind are lettered: `"Hollow Rat A"`, `"Hollow Rat B"`).

**Unit ids:** `uid` is an int, stable for the fight: side A's units first, then side B's,
each side ordered by slot (`col * 10 + row`, i.e. front column top→bottom, then back column).
`src = -1` means "no unit" (sudden death).

**Playback model (active-wait ATB):** actions never overlap. An `action_start` at time `t`
with `duration d` owns the screen for `[t, t + d)`; its effects (`damage`, `heal`, `charge`,
`ko`) are stamped at the `impact` time inside that window (wind-up first, then the hit).
After an action there is a short gap (`action_gap_ms`, 0.1 s) before the next one.
Basic actions last 0.45–0.55 s, abilities 0.65–0.91 s; a unit's own turn comes around about every 4.3 s.
Gauges fill only between actions, so a scene can play the log in real time
(1 simulated second = 1 real second) and simply fire each event when the clock reaches its `t`.

### `fight_start` (t = 0)

| Field | Type | Meaning |
|---|---|---|
| `seed` | int | |
| `data_version` | int | balance data version |
| `sudden_death_at` | float | seconds when sudden death begins |
| `gauge_fill_per_spd` | float | gauge fraction gained per simulated second per point of Spd while the timeline runs (gauge fill rate of a unit = `spd * gauge_fill_per_spd`) |
| `sides` | Array[2] | one entry per side, below |

Side entry: `side` (0/1), `name`, `formation`, `compositions` = list of `{id, name, mods}` that
are active, `units` = list of unit snapshots. `formation`:

| Field | Type | Meaning |
|---|---|---|
| `id`, `name` | String | the shape that **fights** (`"strays"` / "Strays" if scattered or locked) |
| `shape`, `shape_name` | String | the shape the player **arranged** (geometry) |
| `state` | String | `active`, `strays`, `unformed`, `locked_fallback`, `locked_unformed` (`none` for the Crystal / a single unit) |
| `sub_cells` | Array | `[col, row]` cells the fighting shape applies to: all cells when active, the sub-shape's cells when `locked_fallback`, `[]` otherwise |
| `locked` | bool | the arranged shape isn't unlocked (it falls back, see `state`) |
| `buffs` | Array | the bonus: modifiers `{scope, stat, value}` (scope `all`/`front`/`back` or a role: `post`, `tip`, `keeper`, `flanker`, `gap`, `middle`) |
| `debuffs` | Array | the stat part of the cost (may be empty) |
| `behaviour` | `{id, name, text}` | the shape's behaviour |
| `cost` | String | the cost, in words |

Unit snapshots:

| Unit field | Type | Meaning |
|---|---|---|
| `uid`, `side` | int | |
| `name` | String | hero name as given |
| `label` | String | unique-per-side display name; use this in UI |
| `class`, `class_name` | String | class id and display name (memory id / name for memories; `"crystal"` for the Crystal) |
| `span` | int | rows occupied from `row` down: 1, or 2 for the Crystal |
| `base_class`, `tier` | String | e.g. `"fighter"`, `"advanced"`; monsters `"monster"`; Crystal memories `"memory"`; the Crystal `"crystal"` |
| `level` | int | |
| `col`, `row` | int | slot (col 0 front, 1 back; row 0..3) |
| `hp`, `max_hp`, `atk`, `def`, `mag`, `spd` | int | final combat stats (class + level + items + formation + composition) |
| `crit` | float | crit chance 0..1 |
| `charge`, `charge_max` | int | starting charge (0–99, see Charge below) and max (100) |
| `gauge` | float | starting ATB gauge fraction 0..1 (seeded) |
| `basic`, `ability` | `{id, name}` | the unit's basic action and its tier ability |

### `formation` (t = 0, one per side, right after `fight_start`)

A banner cue: "Side A forms Tidebreak: bonus | behaviour | cost" (or "Strays", noting a locked
shape). Fields: `side`, `formation` (as above), `compositions` (active composition buffs). Same data
as in `fight_start`, as its own timeline event; it lists every bonus, behaviour and cost.

### `formation_proc`

A formation or composition effect applying **right now**: show it as a small cue on the unit
(e.g. "Shield: Def +40%" on the defender as the hit lands). Rules, to keep it a clear cause, not noise:
- every formation and composition effect (all sizes; they are all also in the fight-start
  `formation` banner) cues **once per fight per side/source/stat**, the first time it applies
  (`hp_pct` at t = 0); there are no repeat cues;
- at most one cue per instant (one per hit, one for a whole area attack); never for a unit that was
  just knocked out; never on a hit that already carries a `formation` tag (that hit shows the
  effect as its sized multiplier instead, so the two numbers can't contradict each other).

**Truth beats coverage:** a cue only ever names a unit that is doing its trigger at that exact
instant (attacking, being hit, taking its turn, critting, gaining charge, healing). An effect
that loses its instant is not cued later; it stays surfaced by the fight-start `formation` banner
(every buff and debuff, always) and, for always-on HP effects, the t = 0 start cue.

**Behaviour cues** (`stat: ""`, `effect` = behaviour id) fire only when the behaviour actually
happens, on the unit doing it, with the same truth rule; a repeating behaviour cues at most every
6 s per side (`behaviour_cue_interval_ms`); a behaviour cue takes the instant (no stat cue then).

| `effect` | Shape | Cue on / trigger | `related` |
|---|---|---|---|
| `shoulder_to_shoulder` | Kindred | partner as it gains charge / `charge` | unit that was hit |
| `covering_fire` | Vigil | partner whose basic action is retargeted / `turn` | the attacker it now targets |
| `guardian` | Lamplight | front unit as it takes the intercepted hit (only a single-target ranged/magic hit aimed at the partner, never splash or area) / `defend` | the back partner it covered |
| `brace` | Tidebreak | middle unit as it is hit / `defend` | attacker |
| `opening_volley` | Choir, Lumari Chorus | back units' head start / `start` | −1 |
| `flank` | Keystone, Crescent | back unit as it hits the enemy in its row / `attack` | target |
| `draws_melee` | Keystone/Crescent gap, Shardpoint tip | unit as it takes the drawn hit / `defend` | attacker |
| `hearthguard` | Hearth, Lighthouse | lone front unit as it is hit / `defend` | attacker |
| `taunt` | Lighthouse | the post as it takes a drawn hit (melee, dash, or single-target ranged/magic; not area) / `defend` | attacker |
| `share_the_blow` | Seawall | unit as it is hit / `defend` | attacker |
| `chorus_splash` | Lumari Chorus | attacker as its magic splash lands / `attack` | target |
| `keepers_ring` | Keeper's Ring | the unit hit instead of the keeper (while all three front units stand the keeper can't be single-targeted at all; area splash still reaches it) / `defend` | the keeper |
| `shardpoint` | Shardpoint | the tip as it gains charge / `charge` | the ally that acted |
| `echo_step` | Echo Step | unit as halved splash lands / `defend` | attacker |
| `scattered` | Strays | the struck primary target, when splash was kept off Strays not standing next to it (splash only spreads within the struck unit's edge-connected group) / `defend` | attacker |

About 8 cues per PvP fight, 7 vs monsters (stat + behaviour cues). In-fight coverage of stat
cues varies by effect; every bonus, behaviour and cost is always in the banner.

| Field | Type | Meaning |
|---|---|---|
| `side` | int | side whose formation/composition it is |
| `uid` | int | the unit it applied to |
| `source` | String | `"formation:<id>"` or `"comp:<id>"` |
| `name` | String | display name ("Shield", "Well Rounded") |
| `stat` | String | `hp_pct`, `atk_pct`, `def_pct`, `mag_pct`, `spd_pct`, `crit_add`, `charge_pct`, `heal_pct`, `dmg_taken_pct`; `""` for a behaviour cue |
| `effect` | String | the stat id for a stat cue, or the behaviour id (table above) |
| `value` | float | signed size from data (`0.3` = +30 %, `-0.1` = −10 %; `crit_add` is added crit chance); for behaviours its size (e.g. `0.2` share, `15` charge) |
| `related` | int | the other unit involved (table above), or −1 |
| `sign` | String | `"buff"` or `"debuff"` |
| `trigger` | String | when it first applied: `start` (t = 0, max HP), `turn` (Spd, at the unit's `action_start`), `attack` (Atk/Mag as it deals damage), `defend` (Def/Mag as it takes damage), `crit` (crit bonus on a crit), `charge` (charge bonus as it gains charge), `heal` (healing bonus) |

Emitted at the same `t` as its cause, right after the causing event.

### `spawn` (Crystal fight)

A memory surfaces from the Crystal. Fields: `side` (1), `uid` (new, after all existing uids),
`slot` `[col, row]`, `unit` (a full unit snapshot, as in `fight_start`), `memory` (id), `chapter`
(story chapter), `lore` (its line, to show as it appears), `reason` (`"start"` or `"fragment"`).
From then on it acts like any unit.

### `crystal_fragment` (Crystal fight)

The Crystal cracks. Fields: `index` (1–4), `integrity` (after the hit), `max_integrity`. Emitted
right after the damage that crossed the threshold; fragments 1–3 are followed by a `spawn`, the 4th
by `fight_end` with `reason: "shard"`.

**Memory behaviour cues** are `formation_proc` events with `source: "memory:<id>"`, `name` = the
memory's name, `stat: ""`, `effect` = its behaviour, same truth rule:

| Memory (chapter) | `effect` | Behaviour | Cue on / trigger |
|---|---|---|---|
| The Lamplighter's Child (1) | `kindle` | her basic action also heals the most hurt memory | her, as she heals / `heal` |
| The Ferryman Who Waited (1) | `shield_crystal` | every 2nd single-target hit aimed at the Crystal lands on him | him, as he takes it / `defend` (`related` = Crystal) |
| The Miller's Last Harvest (1) | `harvest` | +25 % damage per fallen memory (mod `harvest`) | him, as he hits / `attack` |
| The Weaver of Names (1) | `mirror` | copies the heroes' formation: vs a guarding shape −25 % damage taken, vs an attacking shape +25 % dealt (mod `mirror`) | her, as she hits or is hit |
| A Lumari Knight's Last Stand (2) | `last_stand` | the first felling blow leaves her at 1 HP, fully charged | her / `defend` |
| The Draw (3) | `draw_memory` | each basic attack moves 20 charge from the most charged hero to itself (`charge` reason `"drain"`) | it, as it hits / `attack` (`related` = hero) |
| The Sealing (3) | `hasten_fading` | each of its turns brings the Fading 1 s closer | it / `turn` |
| The Keeper (4) | `dim_lantern` | while he stands, the heroes' formation behaviours (and the Lighthouse taunt) go dark; stat bonuses and costs remain | him / `turn` |

### `formation_move`

Vault Door's *Hold the door*: when a front unit falls, the back unit in its row steps forward into
its slot (emitted right after that `ko`). Animate the move; from then on the unit is in the front
column (melee targets it, back-row halving no longer applies to it). Fields: `side`, `uid`,
`from` `[1, row]`, `to` `[0, row]`, `source` (`"formation:vault_door"`), `effect`
(`"hold_the_door"`), `replaces` (uid of the fallen unit). The side's formation stays the one
detected at fight start.

### `action_start`

| Field | Type | Meaning |
|---|---|---|
| `uid` | int | actor |
| `action` | String | action id (`data/abilities.gd`) |
| `name` | String | display name ("Strike", "Cleave"...) |
| `kind` | String | `"basic"` or `"ability"` (charged ability) |
| `anim` | String | animation hint: `melee`, `melee_big`, `shoot`, `cast`, `cast_big`, `heal`, `heal_big`, `dash`, `slam`, `slam_big` |
| `target` | int | primary target uid, or `-1` for pure area actions (`all_allies` heals) |
| `target_side` | int | side being targeted (own side for heals) |
| `area` | String | `"single"`, `"all_enemies"`, `"all_allies"` or `"column"` (Hexfire: `target` is the bottom unit; the fire climbs the column one space at a time). `"all_enemies"` with `target >= 0` = big hit on `target` plus splash on every other enemy (Firestorm, Hexfire, Unravel, Shard Burst) |
| `duration` | float | seconds this action occupies the timeline |
| `impact` | float | absolute time (seconds) its effects land |
| `gauges` | Array[float] | every unit's ATB gauge fraction at this moment, indexed by uid (actor = 1.0, KO'd = 0.0). Between actions gauges rise linearly at `spd * gauge_fill_per_spd` per second, clamped at 1.0; during an action they are frozen; a unit whose `charge` event has `ready: true` snaps to 1.0 |

### `ability`

Emitted at the same `t` right after `action_start` when `kind == "ability"` (banner/flash cue).
Fields: `uid`, `action`, `name`.

### `damage`

| Field | Type | Meaning |
|---|---|---|
| `src` | int | attacker uid, `-1` for sudden death |
| `dst` | int | target uid |
| `amount` | int | damage number to display (may exceed remaining HP; HP clamps at 0) |
| `kind` | String | `"physical"`, `"magic"`, `"sudden_death"` or `"status"` (poison/burn ticks, hexed heals, HP costs: `src` is who caused it, `action` is `"status:<id>"` for ticks, `primary`/`mods` `[{id: <status or cost>, mult: 1.0}]`) |
| `crit` | bool | critical hit |
| `mods` | Array[Dictionary] | every modifier that shaped this hit, each `{"id", "mult", ...}`, see below (detail) |
| `primary` | Dictionary | **the one annotation to show on this number**, or `{}` for a plain hit. Same shape as a `mods` entry, plus ids `crit` (`mult` 1.5), `back_row_attacker` (attacker in the back column, 0.5), `back_row_target` (target in the back column, 0.5) and `back_row_both` (both, 0.25). Priority: `crit` > `execute` > back row > `formation` > `sudden_death` |
| `hp` | int | target HP after the hit |
| `action` | String | action id that caused it (`""` for sudden death) |

Entries in `mods` (in the order they were applied). `mult` is the signed size: `0.5` halves the
hit, `1.25` makes it 25 % bigger.

| `id` | Extra fields | Meaning |
|---|---|---|
| `formation` | `source` (`"formation:shield"` or `"comp:well_rounded"`), `name` (`"Shield"`), `side` (whose formation) | the **combined** effect of both sides' formation and composition stat changes on this hit, named after the dominant source. Only present when it changes the hit by ≥ 10 % (`formation_mod_threshold`); smaller effects show only as `formation_proc` cues. At most one per hit. `mult < 1` = the hit was weakened (e.g. a defender's Wall), `> 1` = strengthened (e.g. an attacker's Anvil) |
| `back_row_attacker` | | physical hit from a back-column attacker, `mult` 0.5 |
| `back_row_target` | | physical hit into a back-column target, `mult` 0.5 |
| `execute` | | the action's low-HP bonus applied, `mult` 1.5 |
| `sudden_death` | | sudden-death damage multiplier (`mult` 1.25, 1.5, ...); on tick damage `mult` is 1.0 |
| `flank` | | Keystone / Crescent back unit hitting the enemy in its own row (`mult` 1.2 / 1.3) |
| `hearthguard` | | Hearth / Lighthouse lone front unit: less damage per living back ally (`mult` < 1) |
| `echo_step` | | Echo Step: splash halved (`mult` 0.5) |
| `chorus_splash` | | Lumari Chorus magic splash (`mult` 1.1) |
| `brace` / `share_the_blow` | | on the **passed-on** number a neighbour takes (`mult` = the share, 0.2 / 0.3); the struck unit's own number is reduced by the shares. Only single-target actions pass shares (an area or multi-hit action keeps one number per unit) |

`crit` is reported separately as a bool (`× crit_mult` 1.5); when true, `primary` is `crit`.

### `heal`

Fields: `src`, `dst`, `amount` (HP actually restored, > 0), `hp` (after), `action`.
Life-drain heals are `heal` events with `src == dst`.

### `charge`

Fields: `uid`, `charge` (new value 0..100), `delta` (signed change), `ready` (bool, `charge == 100`),
`queue` (int: when `ready`, how many fully charged units act before it; 0 = it acts next; always 0
when not ready), `reason`:
`"act"` (after a basic action), `"hit"` (took damage), `"effect"` (an ability granted charge), `"drain"` (The Draw took charge away),
`"spent"` (reset to 0 when the ability fires). **When `ready` becomes true the unit jumps the turn
queue:** its gauge snaps to full and it acts as soon as the current action ends (fully charged units
go first, in queue order), and a sudden-death tick waits until it has acted. Show "acts next" only
for `queue == 0` (that promise is never broken); show "queued" for `queue > 0`.
**Cascade cap:** charge gained from hits *during an ability* stops at 99, so one ability's hits never
ready another; the unit readies on its next hit or action.

### `ko`

Fields: `uid`, `by` (uid of the killer, `-1` for sudden death). The unit's HP is 0 and it never acts again.

### `sudden_death`

A tick that occupies the timeline like an action. Fields: `tick` (1, 2, ...),
`hp_pct` (fraction of max HP every living unit loses this tick = `tick × 0.08`),
`damage_mult` (multiplier now applied to all attack damage), `heal_mult` (multiplier on healing),
`duration` (seconds). Its `damage` events (kind `"sudden_death"`, `src` −1, `primary` and `mods`
`[{"id": "sudden_death", "mult": 1.0}]`) land at `t + duration/2` for side A and 0.2 s later for side B
(`sudden_death_side_stagger_ms`), so at most 4 numbers land at once; a tick that wipes both
sides lands both sides' numbers together, so the screen matches the HP-fraction tiebreak.

### `status`

A status lands on a unit, or an application stacks onto / refreshes one it already has.

| Field | Type | Meaning |
|---|---|---|
| `uid` | int | the unit that has it |
| `status` | String | id in `data/statuses.gd`: `stun`, `blind`, `sap`, `boon`, `slow`, `poison`, `burn`, `regen`, `shield`, `hidden`, `heal_block`, `heal_invert`, `charge_seal`, `link`, `disarm`, `sabotage`, `riposte`, `watch`, `enshrine`, `seal_immune` |
| `src` | int | who applied it (the unit itself for self-buffs) |
| `stat` | String | `atk`/`def`/`mag`/`spd` for `sap`/`boon`, else `""` |
| `value` | float | its size now: stat fraction (−0.3 = −30 %), slow fraction, damage or healing per tick, shield HP, link share |
| `stacks` | int | 1, or the poison stack count (max 3) |
| `duration` | float | seconds left from this event |
| `action` | String | the action that applied it (`""` for `start_statuses`) |

Show it as the status's icon on the unit (`EffectIcons.status_icon(id)`, with its `short` label and
`text` tooltip from `data/statuses.gd`), until its `status_end`.

### `status_end`

Fields: `uid`, `status`, `stat`, `reason`: `"expired"`, `"ko"` (the unit fell), `"triggered"` (a
`riposte` spent on a parry, a `watch` that caught an attacker), `"broken"` (a used-up
shield, or the other end of a link fell), `"replaced"` (a new link replaced the old one).

### `miss`

Fields: `src`, `dst`, `action`, `reason`: `"parry"` (the Duelist `dst` parried `src`'s melee hit: no
`damage`; its critical counter follows at the same `t`), `"blind"` (a blinded unit's hit missed: no `damage`
event) or `"heal_block"` (a heal on a branded unit did nothing: no `heal` event).

### `skip`

A stunned unit's turn comes and is lost, or a disarmed unit's turn passes with no basic attack (a
disarmed unit with a full bar uses its ability instead, with no `skip`). Fields: `uid`, `reason`
(`"stun"` or `"disarm"`), `duration` (seconds the
lost turn occupies the timeline, 0.3; then the usual gap). Its gauge resets as if it had acted; its
charge is kept.

### `absorb`

A shield took (part of) a hit. Fields: `uid`, `src` (attacker, −1 for none), `amount` (absorbed),
`shield` (shield HP left; 0 = it broke, a `status_end` with reason `"broken"` follows). Emitted just
before the hit's `damage` event, which carries only what got through (no `damage` event if nothing did).

### `move`

A unit is moved by an ability (Warden of Chains, id `shackler`): fields `side`, `uid`, `from` `[col,row]`, `to`
`[col,row]`, `src` (the actor), `effect` (`"pulled"` for the back unit drawn forward, `"pushed"` for
the front unit sent back). Two `move` events per swap (pulled first). From then on the unit is in its
new column (melee targeting and the back-row halving follow it); the side's formation stays the one
detected at fight start.

### `gauge`

An ally's ATB gauge is filled (Iron Marshal): fields `uid`, `src`, `gauge` (new fraction 0..1;
1.0 = it acts next, after any fully charged unit already waiting).

### `revive`

A fallen unit stands again (Rekindler): fields `uid`, `src`, `hp`. It is alive in its old slot with
0 charge and an empty gauge; its old statuses are gone.

### `fight_end`

Fields: `winner` (0, 1, -1), `reason` (as in the result), `survivors` (uids; never the Crystal), `fragments` (int). Its `t` is the
end of the last action, i.e. the fight length.

## Rules implemented

**Stats:** `stat = class.stats + class.growth × (level − 1) + item stats`, floored; then
formation and composition percentages multiply (`× (1 + sum of pct)`), floored, min 1.
Alignment never affects stats.

**Damage:** `power × damage_scale × A² / (A + D)` where physical uses attacker Atk vs target Def
and magic uses attacker Mag vs target Mag (`damage_scale` 1.65). Then back-row ×0.5 (physical only,
each end, no exceptions; Backstab (3.2) and Execute (2.6) get their identity from targeting the
lowest-HP enemy anywhere, back column included, and from high base power, so a halved hit is still
solid), execute bonus, crit ×1.5, ±8 % seeded variance, sudden-death multiplier; rounded, min 1.

**Healing:** `power × healer Mag × heal_scale (0.6) × (1 + heal_pct) × sudden-death heal mult`, capped at missing HP.
Heal abilities also smite the melee target (Mend, Sanctuary), so a charged healer always fires. If
nobody on its side is hurt (or sudden death has cut healing to 0), the heal is skipped and the action
is announced as the smite: `target`/`target_side` point at the smite target, `area` is `"single"`,
`anim` is `"cast"`.

**Ability punch:** every ability's primary hit is ~1.6–2.7× its class's basic power (plus splash,
heals or riders), so an ability beats the same unit's average basic action in > 99 % of casts.
Area abilities are a big primary hit plus a smaller splash on the rest; no action lands more than
4–5 numbers at once.

**Timeline:** gauge fills at `Spd × 9` units/ms (max 100 000): Spd 10 fills an empty gauge in
1.11 s of running time. Starting gauges are seeded 30–65 %. Nobody acts before 0.6 s. Ties:
fully charged first, then fullest gauge, then higher Spd, then lower uid. The gauge resets to 0 on acting.

**Charge:** 0–100. Start = class `start_charge` (20–40) + `start_charge_bonus` (25) ± a seeded
`start_charge_spread` (25), clamped to 0–99, so first abilities are spread over the fight.
`+charge_on_act × charge_act_scale (0.25)` after each basic action (class rates differ: 30–50 before
scaling); `+charge_on_hit × charge_hit_scale (0.8) × %maxHP lost` when damaged (a "hurt" trigger);
both scaled by `charge_pct` buffs. At 100 the unit jumps the turn queue and its next action is the
class ability, which resets charge to 0 (`full_charge_jumps_queue`). Abilities end up ~27 % of
actions; ~88 % of units fire at least once per fight.

**Targeting** (per action `target` selector; per effect `to`):

| Selector | Rule |
|---|---|
| `melee` | enemy front column (back column once the front is empty); same row, else nearest occupied row; equal distance → upper row |
| `back_first` | enemy back column if anyone stands there, else front; same/nearest row as above |
| `lowest_hp_enemy` | lowest current HP (ties → lower uid) |
| `lowest_hp_ally` | lowest HP fraction on own side, including self |
| `random_enemy` | seeded random |
| `most_charged_enemy` / `highest_hp_enemy` | most charge / most current HP (never the Crystal; ties → lower uid) |
| `column_bottom` | the bottom unit of the enemy back column (the front if the back is empty) |
| `strongest_front_enemy` | in the column melee would hit, the foe with the highest Atk or Mag (whichever of its two is larger, current values); ties → more current HP, then lower uid (Bladebreaker) |
| `strongest_sealable_enemy` | the same "strongest" rule over every foe, skipping units already sealed or crystal-worn (`seal_immune`) (Enshriner) |
| `random_ally` | seeded random living ally (self included) |
| `all_enemies` / `all_allies` / `self` | as named |

Every single-target enemy selector skips **hidden** units and the ringed Keeper; area effects still
reach them.

Effect `to`: `primary` (re-picked with the selector if the primary fell mid-action), `primary_adjacent`
(rows ±1 in the primary's column), `primary_column`, `primary_column_rest` (the column minus the
primary), `other_enemies` (every enemy but the primary), `melee_enemy` (whoever melee targeting
would hit), `front_enemies` (the column melee would hit), `front_random`, `random_enemy`,
`all_enemies`, `all_allies`, `lowest_hp_ally`, `self`; and (advanced classes) `adjacent_allies`
(the effect's `adjacency`: `"edge"` or `"all"`), `column_allies`, `other_allies`,
`primary_neighbours` (edge-adjacent to the primary on its side, both columns), `most_charged_enemy`,
`highest_hp_enemy`, `random_ally`, `column_sweep` (Hexfire); round 2: `primary_behind` (the foe in
the back column of a front primary's row, Halberdier), `strongest_front_enemy`,
`strongest_sealable_enemy`. An effect's `delay_ms` lands it that long after the action's impact
(Whirlwind's ally hits, Bloodletting's heals). `lowest_hp_ally` passes over a branded
(heal-blocked) ally while anyone else can be picked.

**Statuses** (`data/statuses.gd`): timed effects on units, applied by an ability effect
`{"op": "status", "status": id, "to": ..., "dur_ms": ms, ...}`. Durations run on fight time (the
Fading's clock, action time included); ticks (1 s), burn jumps (`spread_ms`) and expiries are
processed between actions (one that falls due during an action lands right after it, at the action's
end), in uid order, so the log stays deterministic. Stacking per status: `refresh` (one instance; the
longer duration and the larger size win), `stack` (poison: up to 3 stacks, each adds its per-tick
damage and refreshes the duration), `replace` (link). Sap and boon keep one instance per stat.

| Status | What the sim does |
|---|---|
| `stun` | every turn the unit would take before it wears off is lost (`skip` event) |
| `blind` | each of its hits on a foe misses with chance `blind_miss` (0.5; `miss` event). The RNG is drawn only while blinded |
| `sap` / `boon` | `value` × the stat (from its fight-start value; floor 20 %) |
| `slow` | its gauge fills `value` slower (floor 20 % speed) |
| `poison` / `burn` | **status damage** every second: `power × damage_scale × Mag² / (Mag + target Mag)`, fixed when applied. Burn jumps every `spread_ms` to one edge-adjacent unburnt unit beside it (a copy with the time left) |
| `regen` | heals `power × heal_scale × Mag` every second (scaled by the Fading's healing cut) |
| `shield` | absorbs damage (attacks, status damage, shares) before HP; `amount`, or `power × heal_scale × Mag`. The Fading and HP costs go straight through |
| `hidden` | no single-target selector picks it (melee, back-first, lowest/highest HP, most charged, random, draws, covering fire); area and splash still hit it. Melee skips a hidden front unit to the nearest visible front unit and reaches the back column only when no visible front unit stands (ruling 1) |
| `heal_block` | heals on it do nothing (`miss` reason `heal_block`) |
| `heal_invert` | heals on it deal that much status damage instead |
| `charge_seal` | it gains no charge |
| `link` | it and its `partner` split every hit either takes (`link_share` 0.5 goes to the partner, primary id `link`); ends on both when either falls |
| `disarm` | it makes no basic attacks: each turn without a full bar is a `skip` (reason `disarm`), so it builds no charge from acting. Hits still charge it, and a full bar still fires its ability (Bladebreaker) |
| `sabotage` | its **side's** formation behaviour stops while any living unit of that side has it (the behaviour id reads `"sabotaged"`; the shape's stat bonus and its costs, such as draws, stay; a Lighthouse taunt goes dark). Restored when the last one ends (Saboteur) |
| `riposte` | the next melee hit on it **from the acting unit** is parried (`miss` reason `parry`, no damage) and answered at once with the `riposte_counter` action's effects (a sure crit) on the attacker; the status ends `"triggered"`. If it expires, its `then` follow-up (`riposte_lunge`) plays (Duelist) |
| `watch` | the next hit **by the acting foe** on an ally edge-adjacent to it (`adjacency`) is caught: the status ends `"triggered"`, and the watcher plays `watch_strike`'s effects on the attacker (a hit plus a 2 s `stun`). One catch per watch (Nightwatch) |
| `enshrine` | **PROVISIONAL rules, q-9.** Sealed in crystal: its gauge is frozen and it never acts; no attack, area, splash, share, link, heal, status or status tick reaches it (its existing statuses keep their timers); the formation loses it (out of the shape: behaviour checks skip it, Keeper's Ring counts one fewer front unit). (a) it still counts as standing, (b) the Fading still erodes it, (d) it counts as not visible for melee targeting (as hidden, ruling 1). A follow-up action due while sealed is lost. On release it becomes `seal_immune` (Enshriner) |
| `seal_immune` | (c) crystal-worn: it can't be sealed again for `seal_immune_ms` (8 s, PROVISIONAL); applied when an `enshrine` ends, owned by nobody |

**Status damage is non-physical** (ruling 2, user 2026-10-06): damage kind `"status"`, never halved
by the back column at either end, never a crit, not raised by the Fading's damage multiplier. It
builds hit charge like any damage. HP costs (Iron Marshal, Wickburner, the Tithe) are status damage
too, but never drop a unit below 1 HP, ignore shields and links, and build no charge.

**Sudden death (the Fading):** time-based only. From 36 s (`sudden_death_at`), a tick every 1.5 s
(measured from when the previous tick actually fired; a tick waits for a fully charged unit's action): every living unit loses `tick × 8 %` max HP,
attack damage ×(1 + 0.25 × ticks), healing ×(1 − 0.25 × ticks). If a tick wipes both sides,
the side with the higher HP fraction before the tick wins (exact tie = draw; `reason` `"fading"`);
that winner then has no `survivors`. Hard cap 120 s
(winner by HP fraction) exists only as a safety net.

**Formations (05-formations.md):** the occupied cells are matched at any height, with top/bottom
mirrored variants counting as the same shape and front/back orientation mattering, against
`data/formations.gd`: dominoes Kindred, Vigil, Lamplight; trominoes Tidebreak, Choir, Keystone,
Hearth; tetrominoes Seawall, Lumari Chorus, Vault Door, Crescent, Lighthouse, Keeper's Ring,
Shardpoint, Echo Step. Anything not edge-connected (or 5+ monsters) is **Strays** (Spd +5 %, crit
+5 %, splash never spreads to them). Each shape has a bonus, a behaviour (implemented in
`combat_sim.gd`, cued as above) and a cost. A shape fights only if it is in the side's
`unlocked_formations` (else Strays). "Melee" for behaviours = a physical attack aimed by melee
targeting, or a dash (Backstab / Execute). Draw/taunt pull melee (including dashes) onto the gap
unit / post / tip, and the Lighthouse post also draws single-target ranged and magic attacks.
Numbers are placeholders; several were tuned from the doc to keep every shape at
41–58 % against the field (see `data/formations.gd`).
Composition buffs are kept (they don't conflict): Well Rounded (4 different), Shield Brothers (2+
Fighters), Night Pack (2+ Rogues), Choir of Healers (2+ Healers), Arcane Circle (2+ Mages).

**Alignment:** positions `[good_evil, lawful_chaotic]` in −2..+2. `apply_shift` keeps the underlying
position on the grid; `effective = clamp(underlying + relic offset)`. Only relics carry offsets.
`region_of` gives `N`, `LG/CG/LE/CE`, or a corner `LG*/CG*/LE*/CE*`. `region_class(base, region)` is
the approved class of exactly that region (`""` if none yet). `advanced_class_for(base, pos)` returns
the region's class; in a region with no approved class it returns the approved class of the
**nearest region by grid steps** from the hero's cell (ties: the region nearer the base's start
cell, then the order N, LG, CG, LE, CE, LG\*, CG\*, LE\*, CE\*). **PROVISIONAL** (2026-10-06)
until the user approves a class for every region; `is_fallback(base, pos)` marks the stand-ins (the
run records them as `placeholder`). After round 2 only two regions are open: Fighter LG\* (stands in
as Lightsworn) and Rogue CG\* (stands in as Duelist).

**Advanced classes (rounds 1 and 2, `docs/design/class-verdicts-round1.md`, `-round2.md`).** Only
APPROVED regions have a class; the two still-open regions fall back as above.

| Base | Region → class | Open (stand-in) |
|---|---|---|
| Fighter | N Halberdier · LG Lightsworn · CG Bladebreaker · LE Warden of Chains (id `shackler`) · CE Berserker · LE\* Iron Marshal · CG\* Echoblade · CE\* Ravager | LG\* → Lightsworn (LG, 1 step) |
| Rogue | N Saboteur · LG Nightwatch · CG Duelist · LE Assassin · CE Cutpurse · LE\* Nightshade · LG\* Unseen Warden · CE\* Fadewalker | CG\* → Duelist (CG, 1 step) |
| Healer | N Threadmender · LG Cleric · CG Rekindler · LE Tithekeeper · CE Bloodletter · LG\* Lumenward · CG\* Wickburner · LE\* Confessor · CE\* Gravecaller | none |
| Mage | N Archmage · LG Lampwright · CG Stormwake · LE Runebinder · CE Warlock · LG\* Chronist · CG\* Starcaller · LE\* Enshriner · CE\* Wildfire | none |

Ability mechanics (numbers in `data/abilities.gd`):

| Class | Ability | What the sim does |
|---|---|---|
| Halberdier | Long Reach | hits the front foe (1.8) and the foe in the back column of its row (`to: "primary_behind"`, 1.4; physical, so halved in the back column). Nobody behind: one hit |
| Lightsworn | Aegis Strike (Paladin's ability name) | hits the front foe (1.7) and gives the lowest-HP ally a `shield` for 6 s, sized from the Lightsworn's **Def** (`"scale": "def"`: 1.6 × heal_scale × Def). Replaces the retired Paladin |
| Bladebreaker | Break Blade | hits the strongest front foe (`strongest_front_enemy`, 1.4) and `disarm`s it for 6 s |
| Ravager | Whirlwind | hits every foe in the front column (1.5) and, 0.15 s later, every ally around it (`adjacency: "all"`, diagonals included; 1.5). With nobody beside it (Strays) only foes are hurt |
| Warden of Chains (`shackler`) | Shackle | hits the front foe, then the foe behind it (same row, back column) is pulled forward and the struck foe pushed back (`move` ×2). Renamed from Shackler in round 2 (q-5); the id stays `shackler` |
| Iron Marshal | Drive On | each ally around it (`adjacency: "all"`, diagonals included; round-2 q-6) gets a full gauge (`gauge`) and pays 6 % max HP (`damage` kind `status`, primary `cost`, never below 1 HP). No ally around it: Marshal's Blow |
| Saboteur | Cut the Ropes | hits the front foe (1.6), then every foe gets `sabotage` for 4 s: their formation behaviour stops (op `"sabotage"`; skipped when the foes have no behaviour) |
| Duelist | Riposte (round-2 rework) | takes guard: `riposte` on itself for 3.5 s. The next melee hit on it is parried and answered with a sure-crit counter (1.9); if nobody swings in time, it lunges at the front foe (`riposte_lunge`, 2.0, a follow-up like Unseen Arrest's) |
| Nightwatch | Keep Watch | `watch` on itself for 6 s: the next foe to hit an edge-adjacent ally is struck (1.3) and stunned (2 s). With no ally beside it: Night Blow |
| Bloodletter | Bloodletting | a light magic hit on every foe (0.5), then 0.15 s later heals every ally an even share of **40 %** of the damage it dealt (op `"drain_heal"`, `pct`; healing rules apply). The drain starts conservative (user: "might be too strong") |
| Enshriner | Enshrine | seals the strongest sealable foe (`strongest_sealable_enemy`) in crystal: `enshrine` 3.5 s (rules above, PROVISIONAL). Nobody sealable: Shrine Shard (1.8 magic). The name is data only (it will change) |
| Echoblade | Call Echo | an echo (40 % HP, its stats, basic Strike only, never charges) in the empty front slot nearest its row (`spawn`, `summon: "echo"`). Front column full: Echo Strike |
| Cutpurse | Pilfer | hits the most charged foe and moves up to 30 of its charge to itself (`charge` reason `drain` on the foe) |
| Fadewalker | Vanishing Cut | hits the weakest foe, then `hidden` for 2 s |
| Nightshade | Slow Venom | `poison` on the healthiest foe for 6 s (stacks ×3) |
| Unseen Warden | Unseen Arrest | `hidden` for 1.5 s; when it ends, a follow-up action (also `kind: "ability"`, no charge spent): `stun` 2.5 s on the most charged foe, `blind` 4 s on the units edge-adjacent to it |
| Threadmender | Bind Lives | `link` the healthiest and the weakest ally for 5 s. Fewer than two: Smite |
| Lumenward | Lumen Ward | a small heal on every ally; healing past full HP becomes a `shield` of that size (user tweak) |
| Rekindler | Rekindle | the first fallen ally (its slot free) stands again at 30 % HP, once per fight (`revive`); otherwise Kindle Mend (heal the weakest + smite) |
| Tithekeeper | Tithe | the healthiest ally pays 12 % max HP (primary `tithe`), the weakest is healed 1.6× that |
| Wickburner | Burn to Mend | pays 12 % of its max HP (primary `cost`), heals every other ally |
| Confessor | Brand of Flame | hits the weakest foe and brands it: `heal_block` 5 s (flame-themed, user note) |
| Gravecaller | Raise Husk | the most recently fallen unit of either side (not a summon, not raised before) returns on the Gravecaller's side as a husk in an empty front slot: 50 % of its HP/Atk/Def/Mag, 75 % Spd, its basic action only (`spawn`, `summon: "husk"`, `raised`). With nobody fallen (round-2 q-3) a **nameless husk** of the Vault's long-dead rises instead: fixed HP 30, Atk 8, Def 4, Mag 2, Spd 6, Claw (below a raised level-1 Mage, the weakest raised hero), `raised: -1`. **PROVISIONAL**: with no free front slot it casts Grave Bolt (hits the weakest foe) |
| Stormwake | Chain Storm | three separate magic hits on random foes |
| Starcaller | Draw a Star | one random gift to a random ally: Atk, Mag or Spd +30 % (`boon`, 6 s), a `shield`, or +40 charge |
| Lampwright | Column Ward | `shield` on every ally in its column |
| Runebinder | Rune Seal | hits the most charged foe and `charge_seal`s it for 4 s |
| Chronist | Slow the Field | `slow` (40 %) on every foe for 5 s |
| Wildfire | Wildfire | hits a random foe and sets it burning (`burn` 6 s); every 2 s the fire jumps to an unburnt foe beside it |
| Warlock | Hexfire (user tweak) | a column of fire from the bottom of the foes' back column (the front if the back is empty) climbing one space at a time (`area: "column"`) |

An ability with `requires` plays its `fallback` action when it has nothing to work on (the charge is
still spent; `action_start.action` names the fallback).

**Summons** (echo, husk; ruling 6): unit `tier: "summon"`, new uids after the existing ones. They act
with their basic action, never gain charge, are never in the shape (no bonus, cost, role or
behaviour, they don't connect Strays), never count as standing (a side whose last hero falls has
lost even if summons stand; they're never `survivors` and don't enter the Fading's HP-fraction
tiebreak). They do stand in a front slot, so they shield the back column from melee.

**Rulings 4 (fight end and charge):** a unit at 1 HP is standing, so a side with any standing unit
has not lost. A unit gains **no charge while an effect of its own ability is in play** (a status it
applied with its ability, on anyone, or its summon still standing). The Fading builds no charge.
Charge from status-damage ticks stops at 99, like an ability's hits (the unit readies on its next
hit or action). A stunned unit that was fully charged acts as soon as the stun ends.

**Stat budget (ruling 8):** every advanced class of a base spends the same level-1 total and growth
total, `Σ stat × weight` with HP weighted 1/5 (`Classes.BUDGET_WEIGHTS`): Fighter 104 / 10.0, Rogue
95 / 8.2, Healer 89 / 7.5, Mage 84 / 7.5 (`Classes.BUDGET`, the mean of each base's live classes
before the rule). Crit and charge rates are identity, not budget. Paladin, Berserker, Duelist,
Assassin, Archmage and Warlock were normalised to it; the round-2 classes (Halberdier, Lightsworn,
Bladebreaker, Ravager, Saboteur, Nightwatch, Bloodletter, Enshriner) were built on it.

**Renamed classes:** `Classes.CLASS_RENAMES` (`necromancer` → `gravecaller`; round 2: `paladin` →
`lightsworn`) is applied to every
loaded Echo (`Echo._migrate`, so pools too), to Monument heroes in meta, and through
`GameData.canonical_class` (and the legend's-memory lookup, so `legend_lightsworn` serves an old
Paladin); run saves from older rules are dropped (`RUN_SAVE_VERSION` 4). The Lantern Saint's parent
is now Lightsworn: **PROVISIONAL** until the user confirms (`provisional` in its class data).

**Monster groups** (`PartyGen.monster_group(rng, depth)`): 3 monsters below depth 6, else 4, all at
level `3 + (depth − 1) / 3`: shallow groups are a real fight for a mid-run party, deep ones out-power it.

## Echo snapshots

`Echo.make(party, meta)` → `{"format": "echoing_depths.echo", "version": 2, "data_version", "name",
"meta", "heroes": [normalised heroes], "unlocked_formations": [...]}` (the Training Grounds unlocks
the player had when it was recorded; an Echo fights with exactly those). v1 Echoes still load and
get the default unlocked set. `Echo.to_json` writes sorted-key JSON; `Echo.from_json` /
`from_dict` validate (rules above, on the raw input before anything is normalised), migrate older
versions (`_migrate` hook), reject newer or non-whole versions, and convert
JSON floats back to ints, so JSON → Echo → JSON is byte-identical and replays match the live fight.
Hostile input is type-checked field by field before any conversion and never raises a script error:
`format` must be the exact String, `version` a whole number, `data_version` a whole number in
0..1 000 000, `name` a String ≤ 32 chars, `meta` an object ≤ 2048 chars of JSON, hero names ≤ 24
chars, the whole JSON text ≤ 65 536 chars.
Stats are not stored: an Echo is re-derived from current class data when replayed
(`data_version` records what it was captured under).

## Determinism rules (for anyone editing core)

- Only `rng.gd` produces randomness; one RNG per fight, seeded from the fight seed.
  Never call `randi()`, `randf()`, `randomize()` or `RandomNumberGenerator` in core.
  (Do not name RNG methods `randf`/`randi_range`: Godot's global functions shadow them.)
- The timeline is integer milliseconds and integer gauge units.
- Iterate arrays in stable order (units sorted by side, then slot); data Dictionaries keep insertion order.
- `test_rng.gd` pins the RNG's output: changing it changes every stored replay.
- All 64 seed bits matter: seeds below 2^32 keep their original streams, higher bits are mixed in.
