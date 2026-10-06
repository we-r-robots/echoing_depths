# battle-scene: critic round 11 (2026-10-05, local, overnight): FAIL, piece PARKED

Judged: round-15 build (6320e9b), captures/battle-scene/r15/. Pairs vs SoS combat 013/018/036 and SAP 031/032 (same frames as round 10).

**Decoded:** ours = B in 1,3; A in 2,4,5. Ours **2/5** (round 10: 1/5). Won pair 4 (Backstab KO vs SAP 031) and pair 5 (victory vs SAP 032, newly won). Lost all three Sea of Stars action frames.

**Fixed since round 10 (critic confirmed):** victory names the real team, survivors visible, speed controls gone; hit-stop registers; no label-on-label or label-on-HUD in 14+ hits; single-target attribution passes; Fading reads as fading memory; 60 fps timing clean.

**Open review FAIL:**
1. Attribution still ambiguous at the big moments: Cleave "CRIT! 103" (Moth's) drawn over Corin's legs; Firestorm "CRIT! 65 KO!" (Vael's) on Ilse's staff, KO! box over Brakka.
2. Captions misreport multi-target abilities: "Oren Mend ▸ self" while the main event is CRIT! 24 on Ilse; "Ilse Mend ▸ Sable + 1" hides that the +1 is an enemy killed by a heal ability.
3. Melee staging piles sprites: the Cleave lunge lands inside the enemy block; the Backstab attacker stands inside two units; the diagonal grid lets heroes overlap at rest.
4. Smite/Mend light column is a flat, hard-edged ~330 px rectangle (reads as a debug quad).
5. Brakka's Cleave banner appears while enemy Corin is still mid-swing (mirror match reads as Corin casting).
6. Victory: survivors huddle in a corner, the centre is corpses, the band's first 2 frames are empty black.

**Biggest remaining gap:** at area crits, KOs and backstabs the attacker, targets and numbers stack on top of each other, so you need the caption to know who hit whom.

## Decision: park the piece
The user's direction was "try a couple more rounds and move on" (busy numbers may be acceptable chaos). Rounds 10 and 11 ran since. The top gap (bodies overlapping in the grid and on lunges) is tied to sprite footprint, which the character redesign will change. Parked until the new character art, with this backlog:

### Backlog, presentation only (cheap, can be done any time)
1. Multi-target labels stack upward above their own target's head, never sideways; KO! box away from neighbours or under the number.
2. Captions name every kind of target ("Oren Mend ▸ Ilse · heals self", "Ilse Mend ▸ Sable · strikes Corin"); "+N" only for same-kind extras.
3. Pixel-art beam for Smite/Mend (target width, banded/dithered, soft top, ground ring).
4. Hold the next banner until the previous actor is idle and its trail has cleared (or dim the previous actor).
5. Victory: survivors step forward centre-front, corpses fade back, banner text on its first frame, drop the redundant timer.
6. Fading: show the line before the readout, start the readout at the first real step (no ×1.00), show the per-hit "Fading ×N" tag only on the first hit after each step.
7. Crystal: Firestorm 33/60/24 knot at 13.6–14.6 s; the "20" at 30.7 s touches the lore band.

### Depends on the character redesign
- Grid spacing and lunge stop points sized to the new sprite footprint (no two bodies overlapping at rest).
- Side identity in mirror matches (team-coded palettes/silhouettes; presentation can add tinted HP bars).
- Wind-up, flinch and KO-fall poses.

## Critic report (summary of the hand-back)
Part 1 notes: captures/battle-scene/critic11/notes/part1.md. Table: 1 A (ref) high; 2 B (ref) high; 3 A (ref) med-high; 4 A (ours) med; 5 A (ours) med. Lost the SoS frames because SoS shows one focal event per frame with attacker and target far apart; ours shows overlapping sprites, rings, sparks and numbers in one knot.

## Round-16 build (2026-10-06, local builder): the presentation backlog, items 1-7

Presentation only (game/scenes/battle, tests, capture frame list): no combat logic, data, balance or character sprites changed. Not judged by a critic. Captures: `captures/battle-scene/r16/` (`tools/capture_hires_ui.sh captures/battle-scene/r16 battle crystal monsters videos`; frame numbers updated for the banner holds, new stills listed below).

1. **Labels stand in their own column.** Numbers, CRIT! and KO! use a column mode in `label_layout.gd`: the box's centre stays within `COL_SLACK` (3 world px) of its unit's head centre, and when it meets another label or a wall it climbs (sinking over its own body only when nothing is free above). It is legal when, straight down from it to its own head, there is no other unit's body (as drawn, plus a displaced unit's home and lunge spot, with the knock-back slack); a unit standing behind this one (or the Crystal) only counts above this unit's head. The KO! pill moved under the number, so a crit kill is no wider than its number (adjacent rows are 20 px apart; a crit label is ~25 px). The free solver (sideways/down) remains for formation cues and as a fallback; no number fell back in the demo fights. `tests/test_label_layout.gd`: every number at placement and on every drawn frame passes the column rule; the critic's cases Cleave "CRIT! 103" (Moth), "22" (Corin), "32" (Tamsin) and Firestorm "CRIT! 65 KO!" (Vael) each sit over their own target's head span and above its head on every frame they are up. The monster "77 KO!" stands on the rat's own body (the Fading Wisp's body fills the column above its head). Note for critics: BUILD.md's numbers bar (a) says "nearer its own unit"; a stacked number above a front-row head can be nearer the face of the unit one row behind while standing in its own column.
2. **Captions name every kind of target.** `battle.gd _caption_targets` reads the action's damage and heal events ahead: "Ilse Mend ▸ Sable · strikes Corin", "Oren Mend ▸ Ilse · heals self"; "+ N" counts only units touched the same way ("Brakka Cleave ▸ Moth + 2"). A self-heal from a heal ability no longer says DRAIN.
3. **Pixel-art beam.** `BattleFX.beam`: as wide as the target's body (a hero's width at most), a dark rim, body and bright core, falls to the feet in ~5 frames, a dithered soft top, fades by thinning its dither (tiled 1/2, 1/4, 1/8 patterns aligned to the world grid, never alpha), narrows as it goes, a pixel ground ring at the feet; over the unit it is a quarter-pixel veil so the sprite shows through. Smite, every heal (Mend, Sanctuary), and every former `pillar()` (a memory surfacing, the opening volley, a taunt) use it; the flat rectangle is gone.
4. **Banners wait.** Before an ability's action starts, the clock holds (`HOLD_MAX` 0.6 s) while the previous actor is still lunging/walking home, in its attack or cast strip (`battle_unit.swing_left`, its own clock, so tests see it too) or its trail is drawn; during the hold that actor plays out on a private clock with its recovery frames at double speed (`HOLD_ANIM_SPEED`). Holds in the PvP demo are 10-14 frames. `tests/test_battle_presentation.gd` checks no banner comes up while the previous actor is busy (it fails 5 times with the hold disabled).
5. **Victory restage.** The survivors walk to the centre front (`VICTORY_GAP` 40, feet at `VICTORY_Y` 204, 0.7 s), the fallen fade back to under half and draw behind them; the band is whole with VICTORY and the result line on its first frame (lighter screen flash); the clock is hidden at the result (the result line gives the time).
6. **Fading.** The readout shows only after the line and from the first real step (`hud.fading_readout()`: never ×1.00); the per-hit "Fading ×N" tag marks only the first hit after each step.
7. **Crystal.** The Firestorm 33/60/24 knot is now three columns (33 over the Ferryman, 60 on the Crystal's top, 24 over the Lamplighter's Child, `crystal/*/firestorm_numbers`); the lore banner keeps a wider clear band (`LORE_MARGIN` 10 UI px, tested), so the Smite "20" on the Crystal's top sits further from it (`crystal/*/smite_under_lore`).

New stills: `battle/*/smite_beam_ko`, `banner_waits_corin_cleave`, `caption_mend_strikes`, `caption_mend_heals_self`, `victory_first_frame`; `crystal/*/firestorm_numbers`, `smite_under_lore`. Videos: `battle/fight.mp4` (2300 frames), `crystal/crystal_demo.mp4` (3560).

**Frame time** (headless, `--perf`, spectacle High; `--perf` now also reports the battle's own work per frame, its `_process` plus the effects', numbers' and HUD's draws, and the three heaviest frames): work p50 ~0.5 ms, p99 ~1.1-1.2 ms, max 6.3-10.2 ms (the max frames are first-use frames: the first action at 1.38 s, the Crystal at 11.18 s); wall max 7.0-13.7 ms over two runs per fight (headless loop floor 6.9 ms; round-15 base measured the same way: 11.7 / 14.8 / 11.9 ms). Under 16.7 ms everywhere.

Tests: 185 tests, 0 failed (new: `test_battle_presentation.gd`; `test_label_layout.gd` extended). `tools/smoke.sh`: PASS.

## Round-17 build: statuses and classes (2026-10-06, local builder)

Presentation only (game/scenes/battle, tests, capture list): no combat logic, data, balance or character sprites changed. Not judged by a critic. Captures: `captures/battle-scene/r17/` (`tools/capture_hires_ui.sh captures/battle-scene/r17 battle crystal monsters classes videos`; the new `classes` group, stills at 1080 and phone).

**Demo fights.** `--fight=classes --sequence=a|b|c` (or `scenes/battle/battle_classes_{a,b,c}.tscn`; `battle_demo.gd CLASS_DEMOS`, level-4 parties, seeds found by search so each sequence plays its classes' abilities):
- **a** (418, 40.5 s, into the Fading): Shackler, Echoblade, Rekindler, Archmage vs Iron Marshal, Unseen Warden, Runebinder, Gravecaller. Hidden, stun + the lost turn, blind + MISS, the echo, Shackle's swap, Drive On, Rune Seal, Rekindle. (Nobody falls before the Gravecaller acts here, so it casts its provisional Grave Bolt.)
- **b** (201, 23 s): Fadewalker, Nightshade, Lumenward, Wildfire vs Paladin, Berserker, Threadmender, Confessor. Hidden, poison ticks, Brand of Flame + a BLOCKED heal, Lumen Ward's overheal shield + absorb, Wildfire + the fire jumping, Bind Lives' tether + shared ticks.
- **c** (559, 26 s): Cutpurse, Lampwright, Tithekeeper, Warlock vs Chronist, Wickburner, Starcaller, Gravecaller, with a hex, a regen and a sap put on at t = 0 (`start_statuses`, a tools option: no approved class applies heal inversion or regen). Hexfire's column, a raised husk, Pilfer, Tithe, Column Ward, Slow the Field, Draw a Star, Burn to Mend's hexed heal.

**Statuses on units** (`battle_status.gd`, new):
- A compact row of chips per unit on the UI layer: the shared 9x9 status icon on an 11 px chip (green frame helpful, red harmful), a 2 px duration line under it that drains, one pip per poison stack, sap/boon drawn as the stat's icon with its ▲/▼. New and refreshed chips flash. At most 5 (the newest).
- Placement: under the HP plate; else beside the plate on the side away from the centre line; else above the head. A spot is taken when it would leave the field or touch the HUD (rosters, caption, banners), a live label or another row; a row keeps its spot while it stays free. Labels placed later treat rows as walls (`_layout_ctx`), so a number climbs over a row in column mode. Row-3 units in the middle of the field (under the caption) get their row above the head.
- Tap/hover a row: the shared tooltip, titled "Corin: 2 effects", lists each status as icon + sentence (the stat and value for sap/boon, stacks for poison, the shield's HP left). 16 px touch target. `--status-tip=S` opens it for captures.
- On the board: **stun** puts stars over the head, and the lost turn is its own moment (STUNNED in the column, a wobble, the gauge emptying, caption "Brakka is stunned · turn lost"). **Miss** shows MISS in the target's column (column rule). **Absorb** is a crystal number with the shield glyph, and the shield is a bright line over the HP bar that shrinks, then shatters. **Poison/burn ticks** are numbers one size down (20) with the status glyph (venom drop, flame) and no flinch or hit-stop; Fading ticks keep the grey mote; embers and venom beads drift off afflicted units. **Hidden** fades the unit to a translucent ink silhouette. **Heal-block** (Branded): a smouldering frame on the plate, BLOCKED and a grey fizzling beam when a heal fails. **Heal-inversion** (Hexed): a violet frame and "hexed heal" numbers. **Charge seal**: a rune ring with a bar across the unit's charge gem. **Link**: a thin dotted amber tether, chest to chest, that flares when a share passes ("linked" / link-glyph numbers). **Slow**: the ATB line turns crystal.

**Class abilities.**
- **Echoblade** echo and **Gravecaller** husk fade in at their slot: the echo gets a crystal rim and cool tint and an afterimage trail from its caster. The husk is grey-violet and hollow (grey shader 0.55 + violet), with a wisp from the fallen body. Each gets a SUMMONED / RAISED word. Summons draw a hollow gem instead of a charge gem and stay out of the roster, so the party's rows stay put.
- **Shackler**: the pull and push walk together as one moment with "Dragged Forward" / "Shoved Back" cues and the chain line from the Shackler. **Iron Marshal**: a spark flies to each driven ally's gauge ("Acts Now"), and the HP cost shows as a heart-glyph number tagged cost.
- **Rekindler**: embers rise and an amber beam, then REKINDLED +HP.
- **Warlock** Hexfire: fire columns rise on each space of the column bottom to top, 110 ms apart, on the fight's clock, so each lands with that unit's number. Caption "▸ back column".
- **Wildfire**: when the fire jumps, an arc of flame from the burning neighbour and "Fire Jumps".
- **Runebinder**: six runes appear one by one round the target, chained together, then close in (user note), and the gem is sealed. **Confessor** Brand of Flame: fire projectile, flame burst, smouldering frame. **Lumenward**: a beam per heal, then a shield bubble and line where the heal overflowed.
- Also: Cutpurse's stolen charge flies gem to gem. Stormwake's three strikes are each a bolt. Starcaller's gift is named ("Vael · Mag +30%", "charge +40").
- **Captions** name the effect: "Tamsin Rune Seal ▸ Sable · sealed", "Moth Unseen Arrest ▸ Brakka · stunned · 2 blinded", "Sable Call Echo ▸ Echo of Sable · summoned", "Corin Drive On ▸ Tamsin + 1 · act now", "Brakka Shackle ▸ Corin · drags Tamsin forward", "Ilse Lumen Ward ▸ all allies · 1 shielded · Brakka blocked", "Moth Burn to Mend ▸ all allies · pays HP · heal hurts Tamsin", "Ilse Tithe ▸ self · takes from Brakka". A caption too wide even for two lines drops one size (never cut). Caption read-ahead now stops at the action's end and counts only its own action's events, so a later poison tick is never "+1". **Cut-ins** name the class ("MOTH · UNSEEN WARDEN") and show the ability's icon chip.
- Fixed on the way: a self-heal from Tithe was labelled DRAIN (now only actions that drain).

**HUD rects are pure layout.** `hud.caption_layout()` and `hud.panel_rect()` are used by both the draw and `blocked_rects()`. Headless tests never draw, so they never saw the two-line caption or the rosters as walls; now they do.

**Frame time** (headless, `--perf`, spectacle High, two runs per class fight, after a warm-up run): FRAMETIME_PLACEHOLDER. Under 16.7 ms everywhere. (A first run right after editing scripts showed one 17.7 ms wall frame, from the script recompile; it doesn't recur.)

**Tests:** TESTS_PLACEHOLDER (new: `test_battle_statuses.gd`, 6 tests, and the three class scenes in the scene phase). It plays all three fights frame by frame at 1080p and at phone width and checks every frame: rows inside the field, off the HUD, off live labels and off each other; every `status` event's chip drawn before it ends; every label off the HUD, the rows and other labels, in its own column; the MISS / STUNNED / SUMMONED / REKINDLED / BLOCKED / Acts Now / Fire Jumps / cost / tithe / hexed-heal words and numbers; each class's caption; Hexfire bottom to top. Mutation-checked: rows ignoring the HUD and labels, or a status never drawn, both fail it. `tools/smoke.sh`: SMOKE_PLACEHOLDER.

**Sim notes (reported, not fixed):**
1. The `status` event for `link` has no `partner` field (the sim keeps one internally). The scene pairs the two ends by order (two `link` events with the same source at the same moment). A `partner` field would be safer.
2. A Wildfire jump's `status` event doesn't say which burning unit it jumped from. The scene picks the first edge-adjacent burning unit on that side.
3. Not a bug, worth knowing: when an ability's primary target falls to its own hit, the rider retargets (Brand of Flame killed Sable and branded Brakka; Wildfire killed Moth and set Oren alight). The captions read "▸ Sable · Brakka branded".
