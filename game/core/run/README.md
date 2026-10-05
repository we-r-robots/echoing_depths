# game/core/run — the run layer

Pure logic (no nodes, no rendering). A run is deterministic from `(seed, options, Echo pool state)`.
All numbers are placeholders in **`run_tuning.gd`** (`RUN`, `LEGEND_GATE`, lore / Vault lists).
Combat is the core sim (`core/combat_sim.gd`); formations are core's (`core/formation.gd`): the run
only stores the player's 2x4 placement and passes it to the sim.

| File | What it is |
|---|---|
| `run.gd` | The run state machine and public API (below) |
| `run_tuning.gd` | Every run number: map shape, phases, health, fights, rewards, legend gate |
| `legend_gate.gd` | The Legendary gate: `eligible(hero, state)`, `chance(state)`, `roll(rng, state)`, `encounter_for(class)`; swap when designed |
| `legend_memories.json` | One legend's-memory encounter per authored advanced class (8), EncounterDB format, art empty |
| `encounter_catalog.gd` | Encounters = `data/encounters/*.json` (via `scenes/encounter/encounter_db.gd`) + `encounter_pool.json`; choice binding |
| `encounter_pool.json` | 60 encounters in the EncounterDB format (art empty), 12 per kind; with the 5 authored: 65. Extra fields: `luck`, `rest`, `item`, `recruit` |
| `echo_pool.gd` | Local Echo pool (`user://echo_pool.json`), per-floor seeding and per-floor matching |
| `run_bot.gd` | Seeded bot (`greedy` / `random`) for tests and simulated playthroughs |

## API

```gdscript
const Run = preload("res://core/run/run.gd")
var run := Run.new()
run.start_run(seed, {"best_floor": 3, "story_chapter": 1})   # -> current_node()
run.current_node()     # what the player sees now (never the map)
run.choose(i)          # draft pick / encounter choice (incl. a legend's memory) / Advance-Hold
run.set_formation([[col,row], ...])      # one cell per party hero, any time before a fight
run.resolve_fight()    # core sim result (events for playback) + "opponent" (full, revealed now) + "run": {won, kind, health, ended}
run.advance()          # to the next (hidden) node
run.summary()          # meta-progression payload (final once step == "ended")
run.party_view(); run.combat_party(); run.is_over(); run.log_lines()
```

`start_run` options: `pool` (an EchoPool object) or `pool_path` (default `user://echo_pool.json`),
`save_echo` (default true: the finished run's snapshot is added and saved), `best_floor` (meta's
deepest floor so far, for one-time depth milestones), `start_pool_size` (Tavern), `party_name`,
`log` (default true: fight results carry the event log).

### Steps (`current_node().step`)

Every view has `depth`, `floor`, `phase` (gathering / advancement / legend), `health`,
`max_health`, `vault`, `party` (heroes: class, tier, level, memories, alignment, effective
alignment, items, slot, held, legendary).

| step | extra fields | next call |
|---|---|---|
| `draft` | `offered` [{index, name, class, alignment, taken}], `picks_left` | `choose(i)` twice |
| `choice` | `type: "encounter"`, `kind` (riddle/chance/moral/monster/recruitment, or `legend`), `encounter_id`, `title`, `text`, `choices` [{index, id, label, hero_index, hero_name, class, shift, rare, recruit?, legend?, rest?, uncertain?}] (a `rest` choice has hero_index −1) | `choose(i)` |
| `decision` | `type: "advance"` (0 Advance, 1 Hold back), `hero_index` | `choose(0/1)` |
| `fight` | `type: "monster" / "pvp" / "guardian" / "crystal"`, `opponent` {name, title, banner} only (formation hidden until the fight), `attempt` | `set_formation` (optional), `resolve_fight()` |
| `outcome` | `last`: what the choice or fight did (memory, item, recruit, lore, outcome text, fight result) | `advance()` |
| `ended` | `outcome`: `"victory"` / `"fallen"` | `summary()` |

Node flow: encounter = choice → decisions → (monster kind: fight) → outcome. PvP and floor
guardian = fight → outcome. The last node is the Crystal of Remembrance: one fight, no retry;
it ends the run either way.

## Rules as built

- **Hidden map:** encounter layers of 2–3 parallel nodes (Slay the Spire style), edges to nearby
  nodes of the next encounter layer. PvP and guardian layers are single fixed points on every path:
  the choice made before one decides the encounter after it. Choice *i* leads to `route[i % n]` of a
  hidden seeded shuffle (every route has ≥ 2 targets, so choices 0 and 1 always diverge). Every
  node gets a different encounter id, so a run never repeats one. No public method or view
  contains routes, layers or upcoming nodes.
- **Run arc (`RUN.floors`):** 5 floors, `EEEPEG`, `EPEPEG` x3, `EPEPEC` (E encounter, P PvP,
  G floor guardian, C the Crystal of Remembrance): 30 nodes, 16 encounters, 9 PvP, 4 guardians, the Crystal.
  Guardians are authored in **`guardians.json`** (name, intro shown before the fight, monster
  composition, level, per-monster `level_offset`, `loss_health`): the Sentinel Warden, the Lantern
  Thieves, the Choir of the Unremembered, the Gate of Seals. Losing one costs 2/2/3/3 health
  against 1 for PvP; the party limps on. Health 10. Greedy-bot win rates fall floor by floor
  (~49/43/40/25 %) and stay below that floor's PvP rate.
- **The Crystal of Remembrance (06-crystal-of-remembrance.md):** the final node runs
  `CombatSim.simulate_crystal` with `RUN.crystal_integrity` (600) and a 4-memory sequence from the
  `story_chapter` run option (default 1): every memory of that chapter first, filled from earlier
  chapters, seeded order. The view shows the Crystal's name and intro (`guardians.json` → `crystal`),
  never the memories. No retreat and no retry: `reason == "shard"` wins the run; otherwise the
  party falls there (health 0) and each chipped fragment pays `glimmers_per_fragment` (6) Glimmers.
  Memories knocked out (a `ko` on a uid from a `spawn`) are listed in `memories_defeated` for the
  codex. Greedy bot: ~58 % win at the Crystal, ~21 % run victory.
- **Rest:** 12 encounters carry a party-wide `rest` choice: +1 health, but nobody gains a memory there.
- **Phases by floor:** Gathering floors 1–2 (recruitment weighted 4×), Advancement 3–4, Legend 5
  (a label; the Legendary gate does not use depth).
- **Alignment steering:** 23 encounters give one class a second choice pointing another way
  (some with `luck`: a chance the shift and outcome turn out differently; shown as `uncertain`).
  Measured: ~22 % of encounter nodes give some hero two choices. Strong shifts are ~13 % of choices.
- **Memories:** a non-PvP choice binds to a party hero of the choice's class (EncounterDB rule; with
  two heroes of a class, the one with fewer memories) and gives +1 level (tier cap) and the shift.
  Strong shifts come from the data (~1 in 6 choices). PvP never grants memories.
- **Advancement:** at 3 memories a base hero is offered Advance / Hold back, again after each
  later memory while held (base cap level 6). The class comes from the *effective* position
  (relic offset included) via `Alignment.advanced_class_for`; when the region's class is not
  authored yet, the nearest authored advanced class of that base stands in (`placeholder_class`).
- **Legendary gate (`legend_gate.gd`, 05-formations.md):** only offered when the hero's advanced
  class has an authored Legendary (today only Paladin → Lantern Saint); the other 7 templates in
  `legend_memories.json` stay dormant until their Legendaries exist. Once a hero reaches advanced level 3,
  each later encounter node rolls 8 %, +8 % after each node where it does not appear, cap 60 %.
  On success that node *becomes* the hero's legend's memory (its own title, text and choices:
  accept the legend, or let it go as an ordinary memory). At most once per run; declining ends it.
  No depth gate; core's 1-per-party cap stays. Advanced classes without an authored Legendary
  keep their class and are flagged.
- **Items:** some choices grant an item; won monster fights drop one 50 %. Weapons/armor replace
  only if better. Relics bind on equip: never replaced; a relic goes to the next hero with a free
  relic slot, else is left behind.
- **Recruitment:** recruit choices add a hero (class `*` = seeded base class) while the party has < 4.
- **Fights:** monster groups from `PartyGen.monster_group`, count = party size (2–4), level
  1 + layer/4. PvP: an Echo **recorded on the same floor** (seeded pick among that floor's 20 most
  recent real Echoes; generated ones join only while a floor has < 4 real ones; nearest floor if empty).
- **Team names:** a run's party is "The <epithet> <company>" (576 combinations, `RUN` tuning
  lists) unless `party_name` is passed; Echo snapshots carry `meta.team_name` and `meta.crest`
  (option `crest`, "" for now) for the future splash screen. A run never meets the same rival
  name twice. Pre-fight log lines show no strength numbers.
- **Echo pool:** JSON at `user://echo_pool.json`, seeded with 6 generated Echoes per floor; every
  finished run (won or fallen) records one snapshot per floor reached (the party as it first met
  rivals on that floor; `core/echo.gd` format, meta: floor, depth, outcome, seed). Max 600.
- **Rewards (summary):** Glimmers = 1/layer + 4/PvP win + 4/new floor; `lore_items`; `new_floors`;
  victory adds 1 Shard, `monument` {party, formation, vault} and `remembrance` {id, name, lore}
  (`RunTuning.REMEMBRANCES`, one per chapter: the memory the final fragment frees; never spawned in the fight).

## Commands

```sh
godot --path game --headless -s res://tests/run_all.gd                          # includes tests/test_run.gd
godot --path game --headless -s res://tests/run_sim.gd -- --seed=1 [--n=200] [--policy=greedy|random]
```

Summary also carries: `crystal_reached`, `fragments`, `memories_defeated`, `story_chapter`, `encounters_seen`, `legend_offered`, `guardian_wins/losses`, `rests`, `healed`,
`health_lost_by_phase`, `death` {depth, floor, node, phase}, `encounter_nodes`, `two_choice_nodes`,
`echo` (last snapshot recorded) and `echoes_recorded`.
