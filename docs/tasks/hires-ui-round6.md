# hires-ui: critic round 6 (2026-10-05, local): FAIL (close)

State judged: f6e2102, captures in captures/hires-ui/r6/ and captures/flow/r6/. Numbers judged against the relaxed BUILD.md bar ("Busy fights: the numbers bar").

**Decoded pairs:** ours = A in 1–4, B in 5–7. Ours **4/7, a majority for the first time**: won pair 2 (draft vs FF6 party, high), pair 4 (hero detail vs Octopath, low), pair 5 (encounter vs StS Big Fish, med), pair 7 (setup locked fallback vs SAP 016, med). Lost pair 1 (draft vs SoS party), pair 3 (hero detail vs SoS equip) on density and three mixed type voices, and pair 6 (setup tooltip vs SAP 015) mainly to a tooltip anchored to the wrong row. **No Sea of Stars pair won**, so the pair condition still fails.

**Open review: FAIL on two overlaps:** setup hint "Tap an effect for the full text" over the GREW FROM heading (r6/setup/phone/active_keepers_ring_confirmed.png); Crystal fragment 2-of-4 break (~31 s) puts a "20" under the lore banner's bottom edge. Everything else passes: 16 px min x-height, 6.4:1 min contrast, phone readability, numbers bar, all spec rules.

## Critic report (verbatim)

# Critic 6 report: hires-ui round 6

## Part 1: blind pairs
(Verdicts were written to notes/part1.md before any other capture was opened. The setup pair6 tooltip fault was later confirmed in r6/setup/phone/tooltip_open.)

| pair | full | phone | OVERALL | confidence |
|---|---|---|---|---|
| pair1 | B | B | B | med |
| pair2 | A | A | A | high |
| pair3 | B | B | B | med |
| pair4 | B | A | A | low |
| pair5 | B | B | B | med |
| pair6 | A | A | A | low |
| pair7 | B | B | B | med |

Key observations:
- **pair1 (draft vs a calm JRPG party menu).** The draft has a clear hierarchy: name, then class and alignment, then stat cells, then ability. But it mixes three type voices (serif display, sans, bold numerals) and leans on a lot of small lavender secondary text. The reference uses one face, generous leading and an empty, calm panel.
- **pair2 (setup vs an SNES status screen).** The game wins easily. The reference has a letter-spaced low-res font, colliding LV/HP/MP labels and a saturated blue gradient.
- **pair3 / pair4 (hero detail vs SoS equipment and Octopath II status).** Hero detail is the densest screen in the game: tabs, portrait, stat row, chip rows, Bound locket, ability, footer prose, a 5x5 grid, and "1 step"/"3 steps" pills sitting on cell borders. Two things save pair4 at phone size: its flat high-contrast panels, and the reference's small grey prose on parchment texture. Against SoS's single list with one highlighted row, it reads as busy.
- **pair5 (encounter vs a Slay the Spire event).** The encounter wins. It has a kicker, title and divider, choice-first rows, hero and effect lines, and an outcome mini-grid. Remaining faults:
  - the centred multi-line body paragraph;
  - the "Awakens" tag changes position between rows;
  - the "now / after" legend is tiny and far from the grids it explains.
- **pair6 (Super Auto Pets shop vs setup, Keeper's Ring tooltip).** The setup screen loses on a real bug: the "Def / Front heroes get Def +30%." tooltip opens under the Shield Brothers row with its caret pointing at the Shield Brothers icon, while the selected row is Front Def, two rows up. It also shows a large empty board, and the header meta is two thin dim lines.
- **pair7 (SAP vs setup, Tidebreak).** Setup wins. The icon list is clean, Confirm vs Details is clear, and the locked effects are folded into one row. SAP carries far less information, and its small signs are hard to read.

## Part 2: open review (game under test)

**Measured.**
- x-height of the smallest body text ("3 memories faded", the victory subtitle) is 16 px at 1080p, which meets the 14 px floor.
- The dimmest informative text is lavender (147,150,192) on (21,19,39), at 6.4:1. Disabled Confirm is 6.8:1. Fading readout is 13:1. All clear 4.5:1.
- Phone-size readability is good on every screen I checked: battle, crystal, monsters, setup, draft, encounter, hero detail, title, Lanternrest, road, results, settings, PvP splashes.

**Battle and video (fight.mp4, crystal_demo.mp4, sampled at 4 fps).**
- Cleave crit, Firestorm, Fading double hits (10/12, 19/24) and the KO! pills (56 KO!, 64 KO!, 77 KO!) each sit over their own unit.
- No merged digits seen.
- Captions are present while numbers show.
- Fading line and ×1.36 / ×1.50 readout are clear of the rosters.
- Fragment break 2 of 4: the "20" number is clipped into the bottom edge of the lore banner (top of the digits under the banner's lower rule, frames 0125–0126). A number touching a HUD banner's edge breaks rule (c) of the numbers bar. It is small and brief, but it is a break.
- Fragment 3 of 4: the "31" number sits just under the lore banner and does not overlap it.
- Monsters: the Sentinel's "21" sits over its head and the "77 KO!" pill sits between Brakka and the Wisp. Attribution is acceptable.

**Setup.**
- **Overlap (FAIL).** On r6/setup/phone/active_keepers_ring_confirmed.png (2340×1080), the hint "Tap an effect for the full text" is drawn on top of the "GREW FROM" heading. Text sits on text in a player-facing panel.
- **Tooltip misattribution.** In r6/setup/phone/tooltip_open (Keeper's Ring), the Front Def tooltip anchors under Shield Brothers, with the caret on Shield Brothers' icon. The tooltip needs to anchor to the row it explains. This is not a hard rule break, but it is a clarity defect that a blind judge spotted at once.
- **Mislabelled capture.** The 1080 and phone captures named active_keepers_ring_confirmed show different states (Keystone vs Keeper's Ring). That is a capture-labelling slip, not a UI fault.
- **Unexplained disabled Confirm.** Confirm is greyed while a hero is on the bench or in "IF PLACED" states, with nothing saying why.

**Battle intro cards.** The Keeper's Ring card reads "Oren +40%" twice: heal and charge, told apart only by the icon. Two further chips have no label at all, while the Shardpoint card labels every chip. This follows the rule but is inconsistent and ambiguous.

**Hero detail.** Within the rule: abilities are an icon plus a short label, and equipment effects are chips. It is still the busiest screen:
- "1 step" pills overlap the cell borders;
- the advancement panel's stat rows are small and dense;
- the footer prose wraps to a widow line.

**Encounter / run encounter.** Clean.
- "Awakens" tag placement is inconsistent between rows.
- The run encounter's result card is narrower and has a short centred Continue, while the standalone encounter uses a full-width Continue. The code reportedly shares one card, but the two still look different.

**Flow screens.** Readable and consistent.
- Lanternrest lock badges straddle the tile corners.
- Road and settings are very sparse: large empty space and small modal panels.

**before_after.** battle_roster shows a clear but modest difference. setup_whole compares different states (Keeper's Ring before, Keystone after), which defeats "same UI moment". At phone size the old 3-px bitmap text was already roughly legible, so the gain is visible but not dramatic.

**Rules.**
- Intro cards: title, chip row and behaviour labels of 20 characters or fewer. OK.
- Hero detail abilities: icon plus short label. OK.
- Setup Details renders inside the shared tooltip. OK.
- PvP splash shows rival heroes, crest and name, with no formation. OK.
- Opponent formation stays hidden ("their formation stays hidden"). OK.
- No game-logic changes were visible.
- No rule regressions found.

## OPEN REVIEW: FAIL
Two failures:
- A text-on-text overlap in setup at phone aspect ("Tap an effect…" over "GREW FROM").
- A damage number cut into the Crystal lore banner's edge at fragment 2 (numbers bar rule c).

**THE BIGGEST REMAINING GAP:** the setup panel's flow layout is not robust. Its hint and section headings collide, and its tooltip anchors to the wrong row, so the one screen the player must read before every fight still mislabels or overprints its own effects.

## Prioritised fixes
1. **Setup right panel.** Give "Tap an effect for the full text" its own reserved line, above or below the GREW FROM / WITH ONE MORE HERO section, never overlapping it. Test every state at 2340×1080.
2. **Setup tooltip.** Anchor it to the selected row: caret under that row's icon, opening directly below it, or above when it lacks room. Never anchor it below the last row.
3. **Crystal lore banner.** Treat the banner rect, plus a few px of margin, as HUD in the label solver, so fragment-break numbers drop below it instead of touching it.
4. **Intro cards.** Make chip labelling consistent: label every chip or none. Disambiguate duplicate labels ("Oren heal +40%" / "Oren charge +40%").
5. **Setup Confirm.** When it is disabled, say why in one dim line (e.g. "Place 1 more hero").
6. **Hero detail.** Move the step pills fully inside their cells, give the advancement stat block more leading, and fix the footer widow.
7. **Encounter.** Pin "Awakens" to one position per row, and move the now/after legend next to the first grid.
8. **Before/after.** Re-cut setup_whole on the same state on both sides.

## Round-7 build (local, 2026-10-05)
Built against the round-6 fix list. Captures for critic round 7 in `captures/hires-ui/r7/` (before frames copied from r6/before/) and `captures/flow/r7/`.

- **1a Setup overlap (open review).** The card's note line is its own reserved line over the foot (`FormationPanel.NOTE_H`): the hint "Tap an effect for the full text", or why Confirm is disabled. Rows end above it, and the growth block (GREW FROM / WITH ONE MORE HERO) shows only when it fits whole above it (with six rows it is left to Details). **Test:** `tests/probe_setup_panel.gd`, a new *probe phase* in `run_all.gd` (a Node that walks a screen over frames so `_draw` runs). At 1920x1080 and 2340x1080 it opens the card for every state (every shape that forms with all / default / no shapes unlocked: active, Strays, Unformed, locked fallback, locked unformed; heroes on the bench; a drag preview), every row's tooltip and Details. `UIText` records every text it draws (`UIText.recording`, ink boxes per canvas item, cleared on each redraw). The probe checks that no two text boxes overlap (text under the opaque tooltip is skipped), that text stays inside the card and tooltip, and that the tooltip stays inside the card. About 44,500 checks; run against the round-6 panel it fails (hint text over the growth chips, and every row tooltip off its row).
- **1b Crystal banner (open review).** In the label solver, every banner is HUD with a 4 px margin (`BattleHUD.BANNER_MARGIN`: fragment banner, lore banner, Fading line). A Crystal fight reserves the tallest lore banner (3 lines) for the whole fight, because a number placed before a memory surfaces stays on screen under it (the round-6 "20"). **Test:** `test_label_layout::test_real_crystal_fight` now checks every frame that each live label, as drawn, keeps 3 px clear of the lore and fragment banners.
- **2 Setup tooltip anchor.** A new Tip placement, `"row"`: the card's width, directly under its own row (or directly over it when the foot leaves no room), with the caret on that row's icon. The probe checks that every row's tooltip opens within 6 px under or over its own row; on the round-6 panel every row fails.
- **3 Sea of Stars gap.**
  - Draft card: the name is the card's one serif line. Class and starting alignment share one line. The stats are two aligned label/value columns (HP Atk Def | Mag Spd Row) at one 17 px pitch, with a bright value right-aligned under a muted label. Then one ability row. The ability's sentence and the basic attack are in its tooltip. The pick-number badge and the stage's class tag are gone (the ribbon says First / Second pick). 6 lines per card, down from 8.
  - Hero detail: the same two stat columns (14 px pitch). The ability (name plus 20-character label) is on one row. The Relic row is a plain row: one highlight per screen (the hero's tab), with the Relic marked by its amber name, lock and BOUND. The status note wraps balanced, so there is no widow. The step labels sit in a band inside their cells, 3 px clear of the bevel.
  - Advancement: stat rows at a 14 px pitch, "(+22)" in the bold sans (it was the regular sans, a third voice), and the ability arrow spaced by the bold width.
- **4 Smaller.**
  - Intro cards: every chip keeps a label, in one style per row ("Oren Heal +40%", else "Heal +40%"). When gains and costs don't fit one row, the costs move beside the behaviour glyph. Test `test_intro_cards`: no unlabelled or repeated chip, every label is 20 characters or fewer, every row fits.
  - Setup: a disabled Confirm says why on the note line ("Place 1 more hero to confirm").
  - Encounter: "Awakens" is always on line 1, against the mini grid; when the title leaves no room, the glyph alone holds the same spot. The now/after legend sits on the first grid, with markers at grid-cell size.
  - Run encounter: the encounter screen's heading (rule, kind icon, KIND, rule; divider ornament) and a full-width Continue under the same result card.
  - Capture states: captures now block real pointer input (`capture.gd`: `gui_disable_input`). A pointer over the floating capture window had steered the 1080 setup demo in round 6 (a hero never left the bench). The 1080 and phone shots of each named state now match, and setup_whole's before/after is the same Keeper's Ring tooltip moment.
- **Not done:** sprite crowding (separate task). The growth block is not shown on a 6-row card (no room above the note line; Details lists it).
