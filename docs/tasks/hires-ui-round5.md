# hires-ui: critic round 5 (2026-10-05, local): FAIL

State judged: 51bd7b2, captures in captures/hires-ui/r5/ and captures/flow/r5/. First round with the matched references (see docs/tasks/hires-ui-text.md, "Reference update").

**Decoded pairs:** ours = A in 1–2, B in 3–7. Ours **2/7**: won pair 2 (draft vs FF6 SNES party) and pair 4 (hero detail vs Octopath status). Lost pair 1 (draft vs SoS party), pair 3 (hero detail vs SoS equip), and pairs 5–7 (encounter vs StS Big Fish; setup vs SAP 015/016), which ours won at full size but lost at phone size. No Sea of Stars pair won.

**Open review: FAIL.** Biggest gap: screens are calm only when they carry little; under load (multi-target hits, a 5-row Crystal roster, encounter payoffs in tiny grids) elements collide or shrink below legibility. Rule issues: Firestorm numbers drift off their targets (fight.mp4 10.0–10.2 s); world formation plates ~11 px x-height (< 14 px floor); hero detail equipment effects as plain text ("+6 Def -1 Spd") instead of icon chips (covered by the user's "keep it consistent" ruling: convert).

## Critic report (verbatim)

# hires-ui critic round 5: report

Scope: Part 1 judged only from critic5/pairs (verdicts written to notes/part1.md before anything else was opened). Part 2 judged from r5 stills, flow/r5 stills, fight.mp4, crystal_demo.mp4 (frames every 0.5 s plus targeted full-res crops), before_after, docs/BUILD.md and docs/tasks/hires-ui-text.md. I did not open captures/.keys/, git history, RESUME, progress/ or earlier critic folders. Scratch files are in critic5/notes/.

## Part 1: blind pairs

| pair | full | phone | OVERALL | confidence |
|---|---|---|---|---|
| 1 (draft vs JRPG party menu) | B | B | **B** | med |
| 2 (draft vs SNES party menu) | A | A | **A** | med |
| 3 (JRPG equip vs hero detail) | A | A | **A** | med |
| 4 (Octopath status vs hero detail) | B | B | **B** | med |
| 5 (StS "Big Fish" vs Weeping Colossus) | B | A | **A** | low |
| 6 (SAP shop vs setup, Keeper's Ring) | B | A | **A** | low |
| 7 (SAP shop vs setup, Tidebreak locked) | B | A | **A** | low |

The game under test is plainly identifiable: it is A in pairs 1–2 and B in pairs 3–7. On that reading it wins **2 of 7** (pairs 2 and 4). It wins **no Sea of Stars pair**, and it loses the encounter and both setup pairs on phone legibility. The pass bar (a majority of 7, including a Sea of Stars pair) is **not met**.

Per-pair observations (full detail in notes/part1.md):
- **P1 (lost to the party menu):** our header hierarchy is weak ("Choose two heroes" is barely larger than the sentence beside it). Each card stacks about 7 text styles (name, class, alignment, stat label, value, ability, description, basic). The alignment footnote is the dimmest, smallest line on screen and reads as an afterthought. The reference uses one face, one size per tier, a single unmistakable focus bar, and generous leading.
- **P2 (won vs FF6):** the SNES menu stacks LV/HP/MP with no leading, so "9999/9999" collides, and its wide-tracked caps break word shapes. Our cards are cleaner and hold up at phone size.
- **P3 (lost to the equip screen):** our stat header labels sit left while the values sit right-aligned in the cells below, so "HP" and "200" don't line up. The Memories row is three unlabelled arrow glyphs. The axis labels ORDER, CRUELTY and FREEDOM share one bottom baseline, so they read as a row of tabs, not compass sides. "Close" floats outside both panels. The reference gives three clean zones and puts the "+17" delta in an accent colour exactly where the eye lands.
- **P4 (won vs Octopath):** Octopath is denser, with about 10 px text on parchment chrome. Ours survives at phone size.
- **P5 (lost at phone size):** our title block is the most premium thing in the whole set at full size. But the choice rows hug the right edge, the "now/after" legend is micro text, and the 5x5 grids that carry each choice's payoff can't be read at phone size. Each row asks the player to decode 4 data types. StS's full-width "[Banana] Heal 25 HP." bars read instantly. The text also uses straight quotes ("A memory.").
- **P6/P7 (lost at phone size):** our effect list is large and clean, the best text on the screen. But the header is two-line micro text, and three type scales compete (header < panel title < effect rows). The P6 tooltip is crammed under the list with a bracket line running from the selected row. In P7, "Tap an effect to read it" sits in a large empty dim pane, and the board caption "Crescent locked: fighting as Tidebreak" is small and dim and repeats the panel. SAP's huge Roll/Freeze/End-turn buttons dominate the hierarchy even at thumbnail size.

## Part 2: open review

### Battle (fight.mp4, stills)
1. **A world label clips into the roster panel (FAIL).** At fight.mp4 about 5.1 s, the formation plate "Keeper's ring" appears at about x 1240–1420, y 850–880 at 1080p. Its last glyph runs under the enemy roster frame and the plate sits on the caption box's top rule. The plate also says "ring" in lower case while the banner says "Keeper's Ring". (crop: notes/kr.png)
2. **Multi-target numbers lose their targets (Firestorm, fight about 10.0–10.2 s; notes/fsx.png).** Checked against the roster: Sable 116→84 shows "32", Ilse 148→128 shows "20", Brakka 116→84 shows "32", and Vael 61→KO shows "CRIT! 65" plus "KO!".
   - Sable's "32" floats about a full sprite height above Sable's hood, in the wall, attached to nobody.
   - Ilse's "20" sits at Sable's shoulder, closer to Sable than to Ilse.
   - Vael's "CRIT! 65" is drawn over Ilse's skirt and HP-bar end.
   - Vael's "KO!" sits on the purple ATB diamond and between two HP bars.

   The numbers are all correct, but at phone size you cannot tell which number belongs to whom. That breaks the spec's "numbers on targets" rule (item 6).
3. **Cleave crit (fight 6.5–7.0 s):** 22 (Corin), CRIT! 103 (Moth) and 32 (Tamsin) are correct and on target. But at 6.5 s, "CRIT!" and "103" are drawn inside the slash VFX and touch each other, and the stack of three numbers plus a tag occupies about 120 px. Acceptable, but crowded.
4. **The KO! tag is drawn on top of sprites, red on red.** Examples: crystal 19.5 s (on the Ferryman), crystal 39.5 s (on Brakka) and monsters/tall_sentinel_numbers_ko. In the monsters still, "77" and "KO!" for the Hollow Rat land on the Fading Wisp's body and touch the Wisp's HP bar, so the player reads it as the Wisp being KO'd. That last case is partly the known sprite crowding, but the tag placement makes it worse.
5. **Fading damage tag.** "fading x1.48" (fight 34.0 s) uses an ASCII "x" while the readout uses "×1.48". Its baseline touches the number's box. "The memory of this battle is fading…" floats on the ring art with no backing; it is legible, but the Fading readout and the line sit in different type styles.
6. **The caption names only one target for multi-target abilities.** "Brakka Cleave ▸ Moth" shows while three numbers are on screen. Firestorm correctly says "all foes".
7. **Smallest text.** World formation plates ("Shardpoint", "Keeper's ring", "Grief of the harvest") measure about 11 px x-height at 1080p, below the claimed 14 px minimum. They carry information: a formation trigger and its source.
8. **Good:** the roster, captions, ability banner (kicker caps about 20 px), timer and intro cards are all readable at 960 px. Intro-card behaviour labels are 20 characters or fewer ("Brakka draws melee", "Tip charges up", "Oren untargetable"). The victory card is clean.

### Crystal (crystal_demo.mp4, stills)
9. **The five-row enemy roster hides the Crystal's own bar and fragment pips (FAIL).** At 44.0 s the segmented Crystal bar and the 2-of-4 pips are visible (notes/cr_44.png). From about 46.0 s, when "The Weaver of Names" adds a fifth roster row, the panel grows up to y about 758 and covers both completely (notes/cr_47.png, cr_pips.png at 49.6 s), for most of the run-up to the final fragment. At 55.0 s, when they show again, the pips run into Sable's green HP bar (notes/cr_pips55.png). This round's "Crystal pips beside its bar" fix is therefore invisible exactly when it matters most.
10. The Firestorm fragment break (13.5–14.5 s) has numbers on target: Crystal 60, Ferryman 33, the newly spawned Lamplighter 24. The fragment banner sits in its own slot and the lore caption is no longer hidden. Good.
11. **VICTORY drop-in.** At 55.5 s the title reads "VICTᴼ" with a raised "O" mid-animation. It is transient, but it reads like a glyph bug for one frame.
12. **Roster names.** The 5-row enemy roster uses a smaller size for enemy names ("The Miller's Last Harvest"). It is readable at 1080p but marginal at 960 px.

### Setup (formation)
13. Readable at phone size. The effect list is excellent. Details renders inside the shared tooltip component (unformed_details): rule OK. The locked-row tooltip is full prose inside the tooltip component: OK.
14. **Hierarchy problems.** The header packs four strings into about 40 px ("Formation / Before the fight / The Drowned Archive · Depth 7 / Next: Echo of the Ashen Vow / Their formation stays hidden…").
    - The panel title ("Keeper's Ring", "No formation", "Strays") is a step smaller than the effect rows under it.
    - "Tap an effect to read it" floats in a large empty pane.
    - "If placed: 🔒 Crescent: as Tidebreak" and "IF PLACED / 🔒 Crescent locked" say the same thing twice on one screen.
    - The selected-row bracket line in tooltip_open runs down the panel edge into the tooltip. It reads as a stray rule.
15. Sprite crowding on the board (Brannoc/Sable, Ilse/Brannoc) is noted only, as instructed.

### Draft
16. Readable and centred at 16:9 and 19.5:9. The footnote has adequate contrast (about 9:1) but low visual priority. The header title and subtitle are too close in size. "Set out" is disabled-grey until two picks, which is fine.

### Encounter
17. The Colossus choice rows end about 10 px from the screen edge at 16:9. Stray ◆ markers sit outside row 3. The "now/after" legend and the 5x5 grids are illegible at phone size. The ★ after "Freedom +1" is unexplained on screen. The text uses straight quotes.
18. **The flow encounter doesn't match the encounter screen.** The run_encounter resolved state (flow/r5/run_encounter f00300) is plain centred text ("Wren absorbs a memory. Level 2 → 3 / Order +2"), not the designed result card used in hires-ui/r5/encounter/hound_resolved. The top bar is also laid out differently: depth sits on a second line with hearts in flow, but top-right in the encounter screen. The same screen has two visual languages.
19. "gray" (hound text) vs "grey" (Crystal lore): a minor spelling inconsistency.

### Hero detail
20. **Rule concern.** Equipment rows show stat effects as plain text ("+6 Atk", "+6 Def -1 Spd"), with no stat icons and no red ▼ on the cost (-1 Spd). BUILD.md says each stat effect is a stat icon with ▲/▼, using one shared icon set on every screen. Abilities follow the rule; items do not. Either fix this or get a recorded user exemption.
21. Stat labels are left-aligned while values are right-aligned (HP over a right-aligned 200). The Memories glyphs are unlabelled. The bottom axis labels share one baseline. "Close" floats outside both panels. The advancement panel (advancement_prompt) is good and dense but orderly.

### Flow screens
22. **Title, settings, results, road, Lanternrest:** all readable at phone size and consistent in chrome. The PvP splash shows the rival's heroes with name and crest and no formation: rule OK. The PvP splash portraits are tiny (about 48 px) against a mostly empty screen, which is weak for a hero reveal. The road victory card abbreviates "3 mem." and leaves a large dead band. The results screen is good.

### Before/after
23. **Setup:** the difference is obvious at phone size. **Battle banner:** the "before" bold caps SHARDPOINT reads punchier at phone size than the "after" serif "Shardpoint". The difference is visible, but it does not demonstrate an improvement for that element.

### Wide aspect
24. Battle and setup use the extra width sensibly. Run_encounter leaves a dead strip about 115 px wide on the right of the choice column. The Lanternrest and draft layouts are centred and fine.

### Minimums
- Contrast samples of the dimmest informative text (setup header subtitle, "formation stays hidden", "Tap an effect", the draft footnote, KO'd roster names, the relic hint) all came out at 6:1 or better. The world plates are the one exception: they miss the x-height floor (about 11 px), not the contrast floor.

## OPEN REVIEW: **FAIL**
Reasons:
- Clipping or occlusion beyond the known sprite crowding: the "Keeper's ring" plate runs under the roster (item 1), and the Crystal bar and pips are hidden by the 5-row roster (item 9).
- Multi-target numbers drift off their targets, against spec item 6 "numbers on targets" (item 2).
- World plates fall below the stated 14 px x-height (item 7).
- Possible effects-as-icons breach in hero-detail equipment (item 20).

## Biggest remaining gap
When a screen has to carry a lot at once (multi-target hits, a 5-row Crystal roster, encounter payoffs in tiny grids), the UI still lets elements collide or shrink below legibility, so a screen is calm only when it is carrying little.

## Prioritised fix list
1. **Crystal roster occlusion:** cap the enemy roster at 4 rows (KO'd memories collapse into one "3 memories faded" row), or grow the panel sideways or downward. Never draw it over world units' bars. Also keep the Crystal pips clear of any hero HP bar (offset them or put them in the roster row).
2. **World plates:** keep formation plates ("Shardpoint", "Keeper's ring", "Grief of the harvest") clear of every HUD rect (clamp to the arena rect minus the roster and caption rects). Raise their x-height to 14 px or more, and use the same capitalisation as the banner ("Keeper's Ring").
3. **Multi-target number placement:** anchor each number to its own unit's head. Resolve collisions by nudging sideways within that unit's column, not by stacking upward (Firestorm's "32" must not leave Sable). Offset back-row numbers so they don't sit on the front-row sprite. Put "KO!" beside the number, not on the sprite or the ATB diamond. Add a solid backing pill to KO! so it isn't red-on-red.
4. **Captions for multi-target abilities:** "Brakka Cleave ▸ Moth + 2" or "▸ front + sides".
5. **Fading tag:** use "×" in the damage tag to match the readout, and leave 4 px or more between the tag and its number.
6. **Encounter:** move the choice column in from the edge (24 px or more of margin). Enlarge the mini grids or replace them with a "cell → cell" arrow chip readable at 960 px. Drop the stray ◆ markers. Use curly quotes. Bring the flow resolved state (run_encounter) onto the designed result card and the same top bar.
7. **Hero detail:** put equipment stat effects through the shared icon chips (Atk sword ▲, Spd boot ▼ red), or record a user exemption. Align stat labels and values on one axis. Label the Memories row or give it a tooltip affordance. Anchor Close inside the frame. Put Order/Freedom on the left and right sides of the grid rather than on the bottom baseline.
8. **Setup:** make the panel title the largest text in the panel. Merge the header into two lines (location; next fight + hidden-formation note). Remove the duplicate locked-shape message. Fill or collapse the "Tap an effect to read it" pane. Restyle the tooltip connector line.
9. **Draft:** make the header title clearly a title (one size step up, or put the subtitle under it).
10. **Polish:** VICTORY drop-in frame artefact; PvP splash portraits at least 2× larger; "3 mem." spelled out; gray/grey consistency.

## Round-6 build (local, 2026-10-05)
Built against the round-5 fix list, fixing the load failures structurally. Captures for critic round 6 in `captures/hires-ui/r6/` (before frames copied from r5/before/) and `captures/flow/r6/`.

- **1 Battle labels under load: one layout solver.** `scenes/battle/label_layout.gd` (pure, world px) places every label of an action (number, CRIT!, tag, KO! pill, formation plate). The bar (coordinator, 2026-10-05, after TFT / Octopath / SAP footage): (a) attribution: each label is nearer its own unit than any other and its centre stays within its own unit's horizontal span (the opaque core of the idle sprite, columns >= 30% full, plus 3 px); (b) no two labels overlap; (c) no label covers HUD text (`battle_hud.gd blocked_rects()`: badges, fragment banner, lore slot in Crystal fights, caption as drawn, roster panels, timer row, plus the Crystal's bar). Covering a neighbour's sprite or HP bar is allowed (a small cost, so a clear spot wins a tie). A label starts over its unit's head (plates: under its HP plate), moves sideways within the span or down over its own body, and never stacks upward. KO! is a pill beside its number (dark fill, red rim). The solver sees units at their home slot (not mid knock-back); HP plates stay on the home slot while a unit lunges. `tests/test_label_layout.gd` checks (a)–(c) for every 4-hero shape vs every 4-hero shape at every height with a whole side taking "CRIT! 188 KO!", both parties in the Fading with "fading ×1.48" tags, and every placement in the real PvP (Cleave crit, Firestorm, the Fading, KOs), monster (Hollow Rat KO) and Crystal demo fights, played through the real battle scene at the 1080p layout (the test runner now runs tests on the first frame so scenes can enter the tree). Checked frame by frame in the new fight.mp4 at 5.1, 6.7, 7.0, 10.0, 10.1 and 10.2 s (Firestorm: Sable 32, Ilse 20 and Brakka 32 over their own heads; Vael's "CRIT! 65 KO!" over Vael), in crystal_demo.mp4 at 14, 44, 47, 49.6, 52 and 55 s, and in the monster stills (a `--label-boxes` scene arg draws bodies, plates and label boxes for these checks).
- **2 Crystal roster.** A roster never passes 4 rows: past that the fallen fold into one row ("3 memories faded"), and if the living still overflow the last row says "+N more". The Crystal's fragment pips moved into its roster row; its world bar sits right of centre, clear of the front-row memory beside it. Test: the Crystal demo checks every 10 frames that the roster stays <= 4 rows (it reaches the cap), clears the Crystal's bar, and no hero plate touches it.
- **3 World plates.** Formation and memory plates go through the solver (clear of every HUD rect and the caption), in banner case ("Keeper's Ring", "Grief of the Harvest"). Their x-height is 16 px at 1080p (size 10 Depths Sans Bold, measured on the r5 frame: rows 106–121); `test_label_layout::test_world_labels_meet_the_text_floor` checks every world label size against the 14 px floor.
- **4 Hero detail.** Equipment stat effects are the shared EffectChip (stat icon, green ▲ / red ▼, "+6"; the sentence in the shared Tip; `EffectIcons.item_effects`). Stat label and value share one centre line per column; the memories row counts "2/3"; Order and Freedom sit at the grid's left and right sides (the panel widened to 346); Close is inside the grid panel's bottom-right corner.
- **5 Phone-size losses.** Encounter: the choice column ends 24 px from the frame edge; mini-grid cells 7 -> 9 px (rows 56 tall); no gold studs or strong-shift star; curly quotes (`UIText.curly`, display only); the result card is one shared `EncounterResultCard` used by the encounter screen and the run's encounter node, which also takes the encounter screen's top bar (place and depth top right, health under it). Setup: header in two lines (place · depth; next fight · their formation stays hidden), panel title serif 20 (largest in the panel), the locked shape said once (no board toast, the drag plate names only what fights), the empty hint pane collapsed to one line, and the reading pane points at its row with a caret instead of a margin rule.
- **6 Captions and polish.** Single-target captions name the extra targets ("Brakka Cleave ▸ Moth + 2", read ahead from the action's damage events); "fading ×1.48"; the draft title serif 20 with the subtitle on its baseline; VICTORY settles as one word (no per-letter drop); PvP splash portraits at 2x; "3 memories"; "grey" everywhere in prose (encounter, guardian and legend text, team epithet).
- **Not done:** sprite crowding (separate task); the draft cards' content was left as is (header only).
