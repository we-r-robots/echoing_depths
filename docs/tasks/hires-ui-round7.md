# hires-ui: critic round 7 (2026-10-05, local): PASS

State judged: 1ff564a, captures in captures/hires-ui/r7/ and captures/flow/r7/.

**Decoded pairs:** ours = A in 1, 2, 7; B in 3–6. Ours **5/7**: pair 1 draft vs **Sea of Stars party (med)**, pair 2 draft vs FF6 (high), pair 4 hero detail vs Octopath (med), pair 6 setup vs SAP 015 (med), pair 7 setup vs SAP 016 (high). Lost pair 3 (hero detail vs SoS equip, med) and pair 5 (encounter vs StS, low; ours won at full size). Majority including a Sea of Stars pair: **met**.

**Open review: PASS (marginal).** No rule regressions; no label-on-label or label-on-HUD overlaps; all text readable at phone size (16 px min x-height, contrast 6.38–15.7:1).

**Task status: PASSED.** Follow-ups (polish backlog, not blockers): hero-detail advancement prompt too dense; Cleave crit numbers borderline on attribution (CRIT! beside a neighbour's head); Crystal-side roster at size 10 vs 15; encounter result captions; victory card says "Lantern Company" instead of the team name; redundant draft "Ability" tag; setup tooltip body size; PvP splash slide-in clips the 4th portrait in its first frames.

## Critic report (verbatim)

# Critic 7 report: hires UI text layer (round 7)

## Part 1: blind pairs (verdicts written to notes/part1.md before I opened anything else)

| pair | full | phone | OVERALL | confidence |
|---|---|---|---|---|
| 1 | A | A | A | med |
| 2 | A | A | A | high |
| 3 | A | A | A | med |
| 4 | B | B | B | med |
| 5 | B | A | A | low |
| 6 | B | B | B | med |
| 7 | A | A | A | high |

Observations for every pair are in notes/part1.md. Summary:
- **p1 and p2 (party pick):** A has a strong three-level type hierarchy (display title, then gold names, then white stats) and right-aligned figures. It has one clear primary button. It loses some calm to colour noise: class colours, orange frames, alignment glyphs and the redundant "Ability" tag. Against p1's calm thin-font menu, A still wins: it carries about four times the information and stays as readable at phone size. Against p2's 16-bit menu (cramped LV/HP/MP, misaligned "999/ 999"), A wins clearly.
- **p3 (equipment / hero detail):** A wins on calm. B's left column is crowded (stat block, two equipment rows with two icon chips each, a relic, an ability, a footnote). B's "+4/+3/+15" values are smaller than their icon chips, and the "Memories" arrow icons have no legend.
- **p4:** B wins. A's labels are thin and small and sit on textured parchment.
- **p5 (event screen):** B is the better typographic object: title stack, gold quote, consistent cards. But each choice needs decoding (portrait, coloured name, arrow, "+1", "Awakens" and a 5x5 now/after grid). A is plain sentences with coloured outcomes and survives halving better. This is the closest pair, and clarity of choice decides it.
- **p6 and p7 (setup vs shop):** the formation screen wins both. It has large effect rows and a clear Confirm. The shop's tooltip text is tiny at phone size.
- My guess, not part of the blind verdict: the game under test wins about 5 of 7 (p1, p2, p4, p6, p7) and loses the hero-detail and event pairs.

## Part 2: open review

### Battle (stills, fight.mp4)
- **Readable at phone size:** rosters (size 15), caption bar, banner title chips, timer and buttons.
  - Intro cards follow the rule. Keeper's Ring has three gains on row 1, and its cost plus behaviour on row 2. Shardpoint has its behaviour "Tip charges up" on row 2. All labels are 20 characters or fewer.
  - The Fading line and "Fading ×1.36" sit clear of the banners. The VICTORY card is clean.
- **Numbers bar, Cleave crit (fight.mp4 f0068–f0075, still mid_fight_numbers_cleave_crit):**
  - No label overlaps another label, and nothing covers HUD text. The caption "Brakka Cleave ▸ Moth + 2" is on screen the whole time.
  - Attribution is borderline. The roster bars show Moth took the 103 crit, Corin 22 and Tamsin 32.
  - "CRIT!" is drawn against Corin's face, at Corin's head height (1080p x≈1060–1170, y≈150–190). 103 sits between Corin's body and Moth's hood.
  - Tamsin's 32 (x≈1190–1270, y≈420–480) is about equidistant from Moth's hood and Tamsin's hat (centre distances ≈78 vs ≈79 px).
  - Each number is in its own unit's horizontal span, so this is not a clear fail. A player reading fast would still put the crit on Corin.
- **Firestorm (still and video):** the three numbers each sit above their own unit. CRIT!/65 lands over KO'd Vael's flashing sprite. There are no merges.
- **Rear tag:** "Rear 1/2" stacked over 61 is clean. The "Shardpoint" tip tag is legible.
- **Victory card:** says "Lantern Company wins", but the team is "The Lanternrest Company" everywhere else. This is an inconsistency in the text.

### Crystal (stills, crystal_demo.mp4)
- **Fragment break with Firestorm (FRAGMENT 1 OF 4):** 33, 24 and 60 are separate. The boxes for 33 and 24 nearly touch (a gap of about 30 px at 1080), and each number is over its own unit. The memory lore band and the fragment badge are not covered.
- **Fragment 4/4:** the FRAGMENT badge, "Fading ×1.50" and CRIT!/58 are all separate. CRIT!/58 sits on the Crystal itself, which is acceptable.
- **The Crystal-side roster uses a smaller face than the player roster.** "Crystal of Remembrance", "The Ferryman Who Waited", "3 memories faded" and the 360/285 HP values are all in size-10 type, against size-15 names on the left. It is readable at phone size, but the two rosters no longer match. The pips are tiny.
- **Lore line** ("He waited at the crossing…"): size 10 on a translucent band over the world art. It is legible, and it is the smallest prose in battle.
- The memory sprites overlap (a known separate issue, not failed here).

### Monsters
- Clean. The 77/KO! tag and 21 are well separated.
- The KO'd row in the right roster ("Hollow Rat" greyed) keeps 4.5:1. The "Unravel" ability banner is fine.

### Setup (12 states)
- This is the strongest screen. Effect rows are big and the Confirm/Details hierarchy is clear. The "Place 1 more hero to confirm" hint and the IF PLACED / ACTIVE / NONE tags all read at phone size.
- The tooltip in tooltip_open covers the "Ilse untargetable" row while it is open. That is acceptable tooltip behaviour.
- The tooltip body is size 10 next to size-15 rows, which is a large jump.
- The Unformed Details view uses the shared tooltip-style panel, as the exemption allows. The locked-row tooltip prose is inside the tooltip, which is allowed.
- Header subline "their formation stays hidden": contrast 6.38:1, fine.
- The BRACE and KEEPER tags sit on sprites (sprite crowding is known, not failed here).

### Draft
- Good. A big display title, clear picked/unpicked states, a disabled vs enabled "Set out", and party slots.
- The "Ability" tag at the right of each card's ability row is noise.
- The secondary subtitle measures 6.38:1, fine.

### Encounter
- The choice cards are consistent and the resolved card is clear: level, pips, shift, mini-grid and a full-width Continue.
- **Dense captions on the resolved card.** "1 more to Awaken", "Capped at edge" and "Strong shift" are size-10 captions stacked under the bigger LEVEL line, which makes the card the busiest small type in the flow.
- The 5x5 mini-grids in the top party bar are roughly 30 px at phone size and carry information without a legend.

### Hero detail
- Abilities show an icon and a short label ("Cleave  Front foe + sides"). Equipment shows icon chips with ▲/▼. No rule break.
- **The advancement prompt panel is the densest UI in the game.**
  - Stacked in about 330×450 px at phone size: header, path, a sub-box with five stat rows plus tiny bar graphs, "Ability Cleave → Aegis Strike", a HOLD BACK box with two +/- prose lines, and a corner hint.
  - The stat bars are around 3 px tall at phone size.
  - "new class from Lv 1" and "Order lean · joins the codex" are size-10 captions and the weakest-hierarchy text in the game.
- Readable, but not calm. It is the pair-3 failure mode in the live game.
- The "Lv 3 •••" pips in the tab bar are tiny.

### Flow screens
- **Title, Lanternrest, settings, road and results:** clean and consistent. The results tables are right-aligned and well spaced.
- **PvP splash:** shows the rival heroes, crest and name, and no formation. The rule holds.
- **Splash at f00002:** caught mid slide-in. The rival's fourth portrait ("Mira") is clipped at the right edge and the left title touches the edge. This is transient, but the first frames clip.
- The Guardian and Crystal splash variants are fine.

### Before/after
- **Setup whole and battle roster:** the improvement is obvious at both sizes.
- **Encounter text:** subtle at phone size. The text is crisper and finer, but no bigger, so a casual viewer would barely see a difference.
- **Draft card and banner:** clear.

### Measurements
- Sampled secondary text contrast: 6.38:1 to 15.7:1. All are at or above 4.5:1.
- The smallest text observed is size 10 (16 px x-height at 1080, about 8 px when phone-halved). All of it was legible in the halved frames.
- The world stays crisp. The 2340 wide frames extend the floor sensibly, and the HUD anchors to the edges.

## Verdict
| pair | full | phone | OVERALL | conf |
|---|---|---|---|---|
| 1 | A | A | A | med |
| 2 | A | A | A | high |
| 3 | A | A | A | med |
| 4 | B | B | B | med |
| 5 | B | A | A | low |
| 6 | B | B | B | med |
| 7 | A | A | A | high |

**OPEN REVIEW: PASS (marginal).**
- No rule regression. Intro cards, hero detail, setup Details and the PvP splash all follow the rules.
- No label-on-label overlap, and no label covers HUD text.
- All player-facing text is readable at phone size.
- The Cleave-crit attribution is borderline: CRIT! sits at Corin's head and Tamsin's 32 is equidistant from Moth. It is not a clear fail.

**Biggest remaining gap:** the information-heavy panels (the hero-detail advancement prompt, the encounter resolved card, the Crystal roster) still stack many size-10 captions into small boxes, so they read but don't have the calm hierarchy of Sea of Stars and lose head-to-head on calm.

## Prioritised fixes
1. **Hero-detail advancement prompt:** cut it to title, class change, one stat-delta row (only the changed stats) and the two buttons. Move "joins the codex", the corner hint and the HOLD BACK prose into a tooltip or a second step. Drop the 3 px bar graphs or make them at least 6 px.
2. **Cleave/multi-target numbers:** bias each number's x toward its own unit's centre and away from the neighbouring head. Put CRIT! directly above its own number, not beside a neighbour's head.
3. **Crystal-side roster:** use the same size-15 names and HP as the player roster, and shorten long memory names (or let them wrap or ellipsize) instead of dropping to size 10. Make the pips larger.
4. **Encounter resolved card:** merge "1 more to Awaken", "Capped at edge" and "Strong shift" into one line, or into icons with tooltips.
5. **Victory card:** use the real team name ("The Lanternrest Company wins").
6. **Draft:** remove the redundant "Ability" tag.
7. **Setup:** bump the tooltip body to size 15 or bold it, to close the jump from the size-15 rows.
8. **PvP splash:** start the slide-in with the portraits inside the safe area, so no frame clips.
