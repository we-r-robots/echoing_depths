# battle-scene: critic round 10 (2026-10-05, local, overnight): FAIL

Judged: hires-ui r7 battle/crystal/monster captures and videos (1ff564a era; battle code unchanged since). Pairs vs SoS combat 013/018/036 and SAP 031/032.

**Decoded:** ours = B in 1,2,3,5; A in 4. Ours **1/5** (won pair 4, KO rear tag vs SAP 031). Lost all three SoS pairs (one hit on a clean stage vs our central pile) and the victory frame vs SAP 032.

**Open review FAIL:** numbers over the wrong unit in 4 of 9 checked hits (Cleave CRIT 103 by Corin, 32 by Moth; Firestorm CRIT 65 KO! nearer Ilse; monsters 77 KO! over the attacker), suspected cause: label anchors use home slots while the attacker lunges into the victim's cell; Unravel effect over roster text; victory band hides survivors, names 'Lantern Company', leaves x1/SKIP up; no beat on the last KO. No hit-stop.

## Critic report (verbatim)

# Battle scene presentation: critic10 report

## Part 1: blind pairs
(Full notes in notes/part1.md. My guess is that pairs 1-3 are Sea of Stars on side A against the game on side B; pair 4 is the game (A) against SAP (B); pair 5 is SAP (A) against the game (B).)

| pair | full | phone | OVERALL | confidence |
|---|---|---|---|---|
| 1 | A | A | A | medium-high |
| 2 | A | A | A | high |
| 3 | A | A | A | medium |
| 4 | A | A | A | low-medium |
| 5 | B | A | A | low |

Against Sea of Stars the game loses all three pairs. SoS always has one focal hit on a clean stage. The game piles both parties, the attacker, the effect ring and two or three numbers into the middle third, and "who did what to whom" comes from the caption bar, not from the stage. Against SAP the game wins the action frame (pair 4), because the caption plus the number tell the story. It loses the end frame (pair 5): the VICTORY band hides the winners and names a team that appears nowhere else on screen.

## OPEN REVIEW: FAIL

Reasons, each one checked frame by frame:

1. **Numbers bar (a) attribution fails in 4 of the 9 hit/KO moments I measured.** I matched each number to its unit using the HUD roll-down a moment later.
   - Brakka Cleave (fight.mp4 about 6.7 s; still `battle/1080/mid_fight_numbers_cleave_crit.png`). "CRIT! 103" is Moth's damage (Moth 116 to 13), but it sits beside **Corin's** face, about 112 px from Corin and 145 px from Moth. "32" is Tamsin's damage (75 to 43), but it sits beside **Moth**, about 80 px from Moth and 200 px from Tamsin. Tamsin, the wizard at about (1270, 650), has no number anywhere near her.
   - Tamsin Firestorm (about 10.1 s; `battle/1080/numbers_crit_firestorm.png`, pair 1). "CRIT! 65 KO!" is Vael's damage, but its centre is about 120 px from Ilse and about 230 px from Vael. Vael is the dissolving sprite below it.
   - Monsters Cleave (`monsters/1080/tall_sentinel_numbers_ko.png`). "77 KO!" belongs to the Hollow Rat, but it sits directly over **Brakka, the attacker**, outside the rat's horizontal span. The rat is hidden behind Brakka at the moment of its KO.
2. **An effect draws over HUD text** (`monsters/1080/ability_banner_unravel.png`). Unravel's red streak lines cross the left roster through "Sable", "116", "148" and Ilse's portrait.
3. **Victory is unclear about who won and hides the winners** (`battle/1080/victory_card.png`, fight.mp4 about 34.6-35.0 s). The band covers y 340-555, exactly where the survivors stand. Sable's head is clipped at the band edge (it looks like a bug). The celebration light pillars rise behind the band, and Ilse can't be seen. The subline says "Lantern Company wins", a name that appears nowhere else; the screen calls the teams "Shardpoint" and "Keeper's Ring". The x1 and SKIP controls stay up after the fight ends.
4. **The last KO has no beat.** Oren's "33 KO!" lands at about 34.45 s, and about 0.2 s later the band slams over it. There's no hold, slow-down or zoom on the deciding blow.

What passes:
- **Formations and grid.** The 2x4 per-side grid shows as floor cells. The formation name and icon chips sit top-left and top-right, the chips light when an effect applies (the Crit chip lights on the cleave crit), and a "Shardpoint" or "Stand in the Crossing" tag pops under the unit when a formation behaviour fires. The intro cards follow the icon rule.
- **The Fading.** It reads as a fading memory: the arena drains to grey, the line "The memory of this battle is fading…" appears, then the "Fading ×1.36" readout, and the colour returns at victory. No "sudden death" wording anywhere.
- **Ability banners.** They're in step: the "NAME · ABILITY / Cleave" kicker runs about 0.6 s of wind-up, then hands over to the "Actor Ability ▸ Target" caption on impact.
- **Numbers.** Legible at phone size, with no digit-on-digit merging in anything I sampled.
- **Frame timing.** The 60 fps video has constant frame timing and no repeated-frame runs during action (only 3-4-frame holds in the Fading section). This is an offline render, so it proves nothing about live frame rate.

Pacing, measured: one action every 1.0-1.5 s. Basic attacks wind up for about 0.3 s, abilities for about 0.6 s (banner plus charge ring). Impact brings a white flash and about 0.4 s of whole-field shake. Numbers stay about 0.7-1.0 s, and the HUD rolls down over about 0.6-0.8 s. At x1 the fight is followable, but only because one caption at a time names actor and target. **No hit-stop:** at the 103 crit, frame-to-frame change jumps straight from about 1 to about 20 and stays high, with no 3-6-frame freeze. So crits and normal hits land with the same weight, and the shake blurs the impact frame instead of holding it.

Crystal fight (presentation bugs only):
- **(C1)** In `crystal/1080/victory_shard_breaks_free.png` the "Shard breaks free" sprite is drawn at a far larger pixel scale than the world (about 24 px blocks against 6 px). It's cut off by the top of the screen and by the VICTORY band, so it reads as a cyan blob.
- **(C2)** At victory, The Weaver of Names is still standing with 87 HP and an HP bar, so the win reads as unfinished.
- **(C3)** The memory lore band covers the back-row heads (Sable) and the Crystal's tip during live combat, and the Miller line wraps a two-word widow ("collect it.").
- **(C4)** "fading ×1.48" per-hit tags are lowercase while the top readout says "Fading ×1.48"; I saw the same on the battle-scene Fading tags.

## THE BIGGEST REMAINING GAP
Melee and AoE moments collapse into one central pile: the attacker dashes into the target's cell, numbers spawn at the impact point instead of over their own victim, and there's no hit-stop. So who hit whom, and how hard, is read from the caption bar, not seen on the stage. Sea of Stars and SAP both make the stage itself tell you.

## Fix list (prioritised)

### Presentation fixes (no new character art needed)
1. **Anchor every number, CRIT! and KO! to its own victim** (Cleave, Firestorm, monster Cleave). Spawn it at the victim's head-top anchor (the sprite's top edge plus a small gap, centred on the victim's x) and stagger simultaneous labels by row. Never spawn it at the impact or effect origin. Add a test that takes each label's spawn point and asserts it's nearest its own unit and within its x-span; the 103, 32, 65 and 77 cases above should be fixtures.
2. **The attacker must not cover the victim.** For melee lunges, stop the attacker at the edge of the victim's cell (about ⅓ sprite width short) and keep the victim drawn on top for the impact frames. In the monsters cleave the rat should be visible when "KO!" fires.
3. **Add hit-stop.** Freeze the attacker and victim for 3 frames on a normal hit and 6-8 frames on a CRIT or KO, then shake. Scale the shake down for normal hits so crits read heavier.
4. **Victory staging.** Move the band to the top third, or slide it in only after a beat. Hold about 0.6 s with a slight slow-down on the final KO first. Light the survivors with pillars visible and unclipped, and fade the losers' corpses. Name the winning side by the label the screen already uses (a "Shardpoint wins" chip coloured like the left team), or use the team name consistently everywhere including the top labels. Hide x1 and SKIP when the fight ends.
5. **Keep VFX off the HUD.** Clip Unravel's streaks, and every field effect, to the battlefield rect so they never cross the roster panels, caption bar or timer.
6. **Separate the teams at a glance.** Mirror matches currently rely on position alone. Tint each side's floor cells (amber left, cyan right, as the panels already are), and give each unit a thin team-colour rim or foot-plate, so a unit that has dashed into the middle still reads as its own side.
7. **Make the AoE readable.** Replace the single giant tilted ellipse (Firestorm, the vertical hoop on Cleave) with a per-target ground ring plus a visible cast line or projectile from the caster. Keep the white flash to 2-3 frames and don't let it fully erase the struck sprite, which it currently does for Ilse and Vael.
8. **Make Fading ticks distinct.** Tick numbers are plain red digits in the same font and size as hits, nothing marks them as the Fading, and the caption still shows the last action ("Sable Stab ▸ Oren"), so the ticks read as the Stab hitting both sides. Render ticks in Fading grey with a small mote glyph, and clear or dim the caption during a tick-only beat. Use one casing for "Fading ×N".
9. **"Rear 1/2" jargon.** Show it as an icon (the back-column half-damage glyph from the shared set) with the text in the tooltip, consistent with the icon rule. On Backstab it currently reads as a contradiction.
10. **Crystal.** Redraw the victory shard at world pixel scale, fully on screen and above the band (C1). Dissolve the remaining memories when the Crystal breaks (C2). Cap the lore band at one line or shorten the text, and keep it clear of back-row heads (C3).

### Depends on character art (park until the redesign)
- Opposing duplicates (Brakka/Corin, Sable/Moth and so on) are identical sprites, so side identity rests on position. Fix 6 mitigates this; distinct designs solve it.
- Attack anticipation poses, impact frames and KO collapse animations. Today a KO is a white noisy dissolve, and a cast is a ring plus a sparkle with no casting pose.
- Silhouette separation in the crowded centre (hoods, hats and staffs overlapping at 2x zoom).

## Round-15 build (2026-10-05, local builder)

Presentation only: no combat logic, data, balance or character sprites changed. Captures: `captures/battle-scene/r15/` (`tools/capture_hires_ui.sh captures/battle-scene/r15 battle crystal monsters videos`).

1. **Attribution, for real.** Root cause (measured, not guessed): the label solver judged each label against every unit's *home slot with its idle frame*, using centre-to-body-box distance. At the moment of a hit the units are drawn elsewhere: the victims knocked back and in their hit frames (Corin was drawn 10 px right of his solver box at the Cleave), the attacker lunged into the target's cell. And in the 22 px-row grid a label just above a front-row head sits beside the *face* of the unit one row behind while still being "nearest" by box distance (Cleave 103: 8.5 px to Moth's home box vs 9.5 to Corin's; against the drawn boxes Corin was nearer, 3.5 vs 11.5). Fix: `battle_unit.drawn_rect()` (the opaque core of the current animation frame at the sprite's current position, every frame core measured once per sheet at load); `_layout_ctx` gives the solver the drawn bodies plus `also` rects for a displaced unit (its home and its lunge spot); `LabelLayout` adds a face-point rule (`HEAD_RATIO` 0.8: a label's centre is at most 0.8 of the way to any other face compared with its own) and knock-back slack (`KNOCK` 5 px, others nearer and own farther). `tests/test_label_layout.gd` now checks every live label on every frame of the real PvP, monster and Crystal fights against the units *as drawn that frame* (a unit dashing to or from its strike spot is a transient), with the critic's four cases as fixtures that must be on screen ≥ 20 frames and sit nearest their own victim's face: Cleave "CRIT! 103" on Moth, "32" on Tamsin, Firestorm "CRIT! 65 KO!" on Vael, monsters "77 KO!" on the Hollow Rat. Solver cost kept down (flattened geometry, cost-ordered coarse search, a fine pass only for legality): ~2 ms a label, ≤ 9 ms on a fallback.
2. **Staging.** A melee lunge stops so the attack strip's front edge lands `LUNGE_GAP` (0.34) of the victim's width short of its body (reach from the sprites' measured cores, never less than before). A struck victim draws above everyone for `VICTIM_TOP` (0.32 s), a falling unit through its KO (`KO_TOP` 1 s), so the attacker never hides it (the monster Cleave's rat is visible under its 77 KO!).
3. **Hit-stop.** `HITSTOP_FRAMES` {hit: [2, 3, 3], big: [4, 6, 8]} per Battle Effects Low/Medium/High; "big" = crit, KO or an ability's first blow. Everyone holds (attacker and victim in their impact poses), then the shake (`SHAKE_AFTER` {hit: [0.5, 1, 1.5], big: [2, 3, 4]}) starts when the hold ends. Tunable at the top of battle.gd. The ability wind-up freeze (cut-in) is separate and unchanged.
4. **Victory restage.** The deciding blow gets `FINAL_HOLD` 0.6 s at `FINAL_SLOW` 0.35× with its number still up; then the band comes in across the top (over the formation badges), so the survivors, their pillars and hops stay visible and unclipped. The subline names the winner as the screen does: each roster now carries its team's name on a tab ("The Lanternrest Company", "Echo of the Ashen Pact", "Vault Monsters"), and the result line uses the same name in the side colour. x1 / SKIP hide when the fight ends; the clock stops at the fight's end. (The demo party is named with the game's default team name, `GameState.DEFAULT_TEAM`.)
5. **Effects never cross the HUD.** The streaks over the roster were the ability cut-in's speed lines (`fmod` went negative for the left team and drew them left of the band): fixed with `fposmod` inside the band. World effects are also clipped to the battlefield every frame (`BattleFX.clip_rects` = the HUD rects in world px): rings, sweeps and particles skip the HUD, pillars start under banners.
6. **Side identity.** Every floor cell carries its side's colour (amber left, cyan right in PvP; blood for monsters), and each unit has a team-colour foot plate that travels with it (drawn over its shadow).
7. **Area attacks.** Cleave: one blade line on the attacker's side of the struck column, no hoop, no slash sprites over the victims. Firestorm (and every all-foes cast): one bolt from the caster to each target, a ground ring under each struck unit, a small burst per target; the giant tilted ellipse is gone (Unravel's per-target spiral is small). The hit and KO strips open on a white silhouette frame (art): playback now skips it and the shader flash peaks at 0.7, so the impact flashes for 2-3 frames without erasing the sprite; the hit spark sits on the struck edge, off the face.
8. **Fading ticks.** Tick numbers are Fading grey with a small mote glyph before the digits (never a hit's red); the caption dims while only ticks happen; "Fading ×1.48" everywhere.
9. **Rear.** "Rear 1/2" is the shared `rear_half` icon (new in `ui/effect_icons`, a half-struck shield; two for a quarter) with the sentence in the shared tooltip (tap/hover areas over the live icons, 16 px minimum).
10. **Crystal.** The freed Shard is drawn at world pixel scale and settles in the open middle of the field, under the band; the memories still standing dissolve when the Crystal breaks; the lore band is one line (as wide as the view allows, an ellipsis if a line ever overflows), and its reserve includes the camera's travel.

Frame time (spectacle High, headless, uncapped, per frame): PvP avg 0.6 ms (base 0.9), max 9 ms (base 9); monsters max 9; Crystal max ~10-15 ms on the frames where a label falls back (base 8). The windowed software-GL probe shows no average regression beyond noise.

Known gaps: the critic case "CRIT! 103" still sits at the junction of Corin and Moth because Moth stands one row in front of Corin (it is above Moth's head and nearest Moth's face by the new rule, but a viewer may still glance at Corin); the Crystal's own labels often take the solver's fallback; the rear icon's tooltip lives only while its number is up.
