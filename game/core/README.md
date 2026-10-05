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
| `data/classes.gd` | Base classes, illustrative advanced/legendary classes, Vault monsters |
| `data/abilities.gd` | Basic attacks and abilities (one schema, data-driven effects) |
| `data/items.gd` | Weapons, armor (flat stats), relics (stats + alignment offset) |
| `data/formations.gd` | Formation shapes (buff + debuff each) and composition buffs |

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
Lamplight, Tidebreak, Choir). A shape that isn't unlocked fights as Strays.

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

## Output: result dictionary

| Key | Type | Meaning |
|---|---|---|
| `winner` | int | `0` side A, `1` side B, `-1` draw |
| `reason` | String | `"wipe"`, `"fading"` (ended during a sudden-death tick: the Fading), `"timeout"` (hard cap; should never happen) |
| `duration` / `duration_ms` | float / int | fight length in simulated seconds / ms |
| `sudden_death_ticks` | int | ticks that occurred |
| `survivors` | Array[int] | uids standing at the end |
| `seed`, `data_version` | int | inputs echoed back |
| `events` | Array[Dictionary] | the event log below (empty if `options.log == false`) |

Options: `{"log": false}` skips building events (same outcome, faster);
`{"tuning": {...}}` overrides keys of `Tuning.COMBAT` (used by tests).

## Event log schema

`tests/test_schema.gd` checks every event of ~1000 fights (including forced sudden death) against
this section: exact field set, types and enumerated values. If the two ever disagree, that test fails.

**Schema changelog** (for consumers):
- *Latest:* Keeper's Ring keeper can't be single-targeted at all while the ring stands (any
  selector; splash still hits); the Lighthouse post also draws single-target ranged/magic attacks.
  `game/core/run/run.gd` now passes `unlocked_formations` (run option) and the monument records
  the shape that actually fought.
- *Formation redesign (05-formations.md).* Shapes are dominoes/trominoes/tetrominoes
  (Kindred, Vigil, Lamplight; Tidebreak, Choir, Keystone, Hearth; Seawall, Lumari Chorus, Vault Door,
  Crescent, Lighthouse, Keeper's Ring, Shardpoint, Echo Step) or Strays; the old 11 shapes and
  Loose Ranks are gone. Parties may carry `unlocked_formations`; a locked shape fights as Strays.
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
| `locked` | bool | the arranged shape isn't unlocked, so it fights as Strays |
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
| `class`, `class_name` | String | class id and display name |
| `base_class`, `tier` | String | e.g. `"fighter"`, `"advanced"`; monsters have `tier = "monster"` |
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
| `guardian` | Lamplight | front unit as it takes the intercepted hit / `defend` | the back partner it covered |
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
| `scattered` | Strays | the struck primary target (splash didn't spread) / `defend` | attacker |

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
| `area` | String | `"single"`, `"all_enemies"` or `"all_allies"`. `"all_enemies"` with `target >= 0` = big hit on `target` plus splash on every other enemy (Firestorm, Hexfire, Unravel, Shard Burst) |
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
| `kind` | String | `"physical"`, `"magic"` or `"sudden_death"` |
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
`"act"` (after a basic action), `"hit"` (took damage), `"effect"` (an ability granted charge),
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

### `fight_end`

Fields: `winner` (0, 1, -1), `reason` (as in the result), `survivors` (uids). Its `t` is the
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
| `all_enemies` / `all_allies` / `self` | as named |

Effect `to`: `primary` (re-picked with the selector if the primary fell mid-action), `primary_adjacent`
(rows ±1 in the primary's column), `primary_column`, `primary_column_rest` (the column minus the
primary), `other_enemies` (every enemy but the primary), `melee_enemy` (whoever melee targeting
would hit), `front_enemies` (the column melee would hit), `front_random`, `random_enemy`,
`all_enemies`, `all_allies`, `lowest_hp_ally`, `self`.

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
`region_of` gives `N`, `LG/CG/LE/CE`, or a corner `LG*/CG*/LE*/CE*`. `advanced_class_for(base, pos)`
prefers the exact corner class, then the quadrant/neutral class, else `""` (not authored yet).

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
