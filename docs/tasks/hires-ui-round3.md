# hires-ui: critic round 3 (2026-10-05, local): FAIL

State judged: f4afbce, captures in captures/hires-ui/r3/. This round the critic was told to ignore capture artifacts (letterboxing, blur, watermarks) on either side.

**Decoded pairs (ours = B in 1, 3, 5; A in 2, 4; the critic recognised our side from shared heroes and chrome):** overall the reference wins all 5, ours 0/5. At phone size ours wins 3/5: pair 2 (encounter vs SoS 015) and both SAP pairs; draft (SoS 014) and hero detail (SoS 016) lose at both sizes.

**Open review: FAIL (narrow).** Every text readable at phone size, contrast and size floors hold, no rule regression; fails on four overlaps (hero detail NEW tag, Firestorm CRIT/KO near a neighbour, setup nameplates over sprites, setup tooltip over the board). Biggest gap: the UI is legible but not calm; dense hero detail, encounter and setup board, and primary buttons with no weight.

## Critic report (verbatim)

# hires-ui round 3: critic 3 report

## Part 1: blind pairs
(Part 1 verdicts were written to notes/part1.md before I opened any other capture.) The game-under-test side is obvious from its shared heroes, fonts and chrome: B in pairs 1, 3 and 5, A in pairs 2 and 4. I judged on UI merit anyway.

| Pair | Full size | Phone size | OVERALL | Confidence |
|---|---|---|---|---|
| 1 (shop list vs hero draft) | A | A | **A** | med |
| 2 (event choice vs sell modal) | B | A | **B** | low |
| 3 (shop list vs hero detail) | A | A | **A** | high |
| 4 (formation setup vs SAP shop, 2340) | B | A | **B** | low |
| 5 (SAP vs formation setup, 2340) | A | B | **A** | med |

The reference side wins all 5 pairs overall. At phone size the game wins 3 of 5 (pairs 2, 4, 5), so raw legibility is now competitive. It loses on calm, hierarchy and punch.

Key observations, game side:
- **Draft (p1 B):** three type styles on each card (serif name, sans body, caps badge). Stat label row is dim and tight above its numbers. The primary "Set out" button is a small, dim outline, weaker than the "ALIGNMENT" badge.
- **Encounter (p2 A):** each choice row carries 3 lines (name, Lv, Awakens, alignment shift). The "now / after" legend is crammed above the first row. The 5x5 mini grids are tiny and cryptic.
- **Hero detail (p3 B):** information overload. Party bar, stats, equipment, ability, the 5x5 grid with step tags, axis labels and a footer line all show at once. Ilse is "Healer" in the panel but "Cleric" on her grid tile. "Taken ->->" and "Lv 3/6 ◆◆· 2/3" are cryptic. "offset" is orange on brown and low contrast. The footer sentence floats outside any panel.
- **Setup (p4 A / p5 B):** the effect list is large and clean, which is the best part of the game's UI. Problems:
  - The tooltip lands over Brannoc's sword and Sable.
  - Board nameplates and the BRACE tag collide with sprites.
  - There is a large dead void in the right panel.
  - The Details and Confirm buttons are thin outlines, with no primary punch.
  - The tooltip says "Defence" while the row says "Def".
- **Reference sides:** Sea of Stars wins on one calm sans, a strong selection bar and aligned columns. SAP wins on giant Roll and Freeze buttons and badge numbers. SAP's own tooltip body text is tiny.

## Part 2: open review of the game under test

### Damage numbers (fight.mp4, crystal_demo.mp4, checked frame by frame at 10 fps against roster HP)
- **Fight Cleave (f68-76):** numbers sit on the struck units.
- **Fight Firestorm (f99-107).** Roster goes Brakka 116->84, Sable 116->84, Ilse 148->128, Vael 61->KO:
  - Brakka 32, Sable 32 and Ilse 20 are each over their own head.
  - The Vael CRIT 65 sits above Vael's hat tip, but at Ilse's head height and over Ilse's staff orb. Vael's "KO!" butts into Ilse's HP bar. Each number is on its target, but this one reads ambiguously.
  - All numbers clear at the next action (f108, "Oren Smite > Brakka"). PASS.
- **The Fading (fight f273-347, crystal f505-541):** tick numbers land on each living unit (fight 4/5/4, 11/14/12, 14/18/16; crystal 10/12, 19/24/15). They clear before the next action. The "fading xN" tag rides on the hit number. PASS.
- **Crystal Firestorm (c136-150).** Numbers are correct: Ferryman 33 (105->72), Lamplighter 24, Crystal 60 (328->268). **The caption is out of sync:**
  - While the numbers are up, the caption reads "FRAGMENT 1 OF 4".
  - "Vael Firestorm ▸ all foes" then appears at c152-156, after the numbers have cleared, with no hit on screen. It reads as a second cast.
- No numbers carried over to a later action in either video. No rule break found on numbers.

### Per screen

**Battle (stills and fight.mp4)**
1. **Phone readability:** every text read at 960 and 1170 wide. Smallest are the victory subtitle "Lantern Company wins · 25.7 s" and the "Shardpoint" world tag; the tag measures a 16 px x-height at 1080. OK.
2. **Overlaps:**
   - The Firestorm crowding above (CRIT 65 / 20 / KO!).
   - The Fading line "The memory of this battle is fading..." and "Fading ×1.36" sit on the arena with no backing plate; still readable.
   - The victory band animates in letter by letter ("VIC") over the sprites. Fine.
3. **Hierarchy:** clean. Serif titles, sans body, mono numbers.
   - Intro card stat chips on Keeper's Ring show only "+40% +40% +30% +5%" next to icons. Two "+40%" with different icons and no subject (Ilse) is unclear at a glance.
4. **World:** crisp pixel art.
5. **Wide (2340):** the arena extends sensibly, HUD anchors hold, nothing is stranded.

**Crystal**
- Lore panel ("The Ferryman Who Waited" plus a one-line body) is readable at phone size (x-height about 16 px, contrast 11:1).
- The caption desync described above.
- Memory sprites overlap (known separate issue).

**Monsters:** OK.
- The Stone Sentinel's number goes beside its head (tall unit), as intended.
- "KO!" on the Hollow Rat overlaps Brakka's sword arc. Minor.

**Setup**
1. All readable at phone size. Dim lines ("Their formation stays hidden until the fight", "GREW FROM", "Order lean") measure about 6.4:1. OK.
2. **Overlaps:**
   - locked_fallback: the BRACE tag and Brannoc nameplate butt against Sable's bow.
   - drag_preview_locked_crescent: the Brannoc nameplate sits on top of Ilse's staff and Sable's hand.
   - tooltip_open: the Defence tooltip covers Brannoc's sword and Sable's head.
   - These come from sprite crowding (known issue), but they are text-on-art overlaps.
3. **Hierarchy:**
   - The BACK/FRONT column headers only align with the top row of the skewed grid.
   - "Defence" (tooltip) vs "Def" (row).
   - The empty "+" slot marks are tiny and dim.
4. **Chrome:** consistent.
5. **Wide:** the panel and board are centred, with dark margins. Acceptable.
6. **Rules:** the opponent's formation stays hidden ("Their formation stays hidden..."), the 2x4 grid is present, and Details renders inside the shared tooltip box. OK.

**Draft**
- Readable.
- Ability blurb "Front foe and its sides" (23 characters) does not match hero detail's "Front foe + sides". Same ability, two labels.
- "Set out" stays a weak outline even when enabled. Disabled it is 4.4:1, which is fine for a disabled control but reads as off.

**Encounter**
- Readable.
- Choice rows are dense (3 lines plus a mini grid).
- Party-bar level pips ("Lv 2 •••") are tiny.
- The resolved card hierarchy is good.

**Hero detail**
- Readable, but the densest screen.
- In advanced_paladin, the "Paladin NEW" tag overflows its grid cell and runs across the cell border into the next cell.
- The "!" ready badge touches the "B" of "Brannoc" in the party bar.
- "Healer" vs "Cleric" naming on the same screen.
- The "Taken" arrows are about 33 px. If they are tooltip hosts, they are under 48 px.
- Ability shows icon + short label ("Cleave / Front foe + sides"). Rule OK.

### Before/after
- **Full size: obvious.** Effect rows on the setup card are larger and smoother, and the encounter body is crisper.
- **Phone size: only modest.** On the roster crop the "after" is actually thinner and less punchy than the bold "before". The encounter gain is small at 960 wide.

### Measured minimums
- The smallest world tag measures a 16 px x-height and the lore body about 16 px, both above the 14 px floor.
- All informative dim text I sampled is 5.7 to 6.4:1. Body text is 10 to 11:1.

## Verdict

| Pair | Full | Phone | OVERALL | Confidence |
|---|---|---|---|---|
| 1 | A | A | A | med |
| 2 | B | A | B | low |
| 3 | A | A | A | high |
| 4 | B | A | B | low |
| 5 | A | B | A | med |

**OPEN REVIEW: FAIL (narrow).**
- No rule regression found: numbers are on their own target and cleared per action, nothing is clipped at screen edges, the opponent's formation is hidden, the 2x4 grid is present, effects are icons, and intro and hero-detail labels are 20 characters or fewer.
- Every player-facing text is readable at phone size.
- It fails the "no overlaps" bar on four points:
  - hero detail "Paladin NEW" overflowing its cell;
  - Firestorm CRIT 65 sitting on Ilse's staff, with KO! on Ilse's HP bar;
  - setup nameplates and the BRACE tag drawn over neighbouring sprites;
  - the setup tooltip covering units.

**THE BIGGEST REMAINING GAP:** Readability now holds up at phone size, but the UI is not calm. Hero detail, encounter and the setup board pack too many small competing elements, and the primary actions have no visual weight, so it still loses to Sea of Stars and SAP on hierarchy and punch.

## Prioritised fix list
1. **Battle and crystal: number and tag stacking.**
   - Problem: when two targets share a column band (Ilse over Vael), the lower unit's number rides at the upper unit's head height (CRIT 65 on Ilse's staff orb), and its KO! hits the upper unit's HP bar.
   - Fix: run collision avoidance on numbers and tags against other units' heads and bars. Nudge each label horizontally toward its own sprite's centre, so every label touches only its own unit.
2. **Crystal: caption sync.**
   - Problem: the "FRAGMENT n OF 4" banner pre-empts the Firestorm caption, which then reappears after the hits.
   - Fix: show the action caption while its numbers are up, and queue the fragment banner after it, or drop the stale caption instead of restoring it.
3. **Hero detail: grid tile tag.**
   - Problem: "Paladin NEW" overflows its cell.
   - Fix: put NEW on its own line, or as a small corner badge, and keep the tag inside the cell bounds.
   - Also keep the "!" badge clear of the name text.
4. **Hero detail: naming and density.**
   - Use one class word per hero (Healer vs Cleric).
   - Replace "Taken ->->" with a labelled mini-trail, or move it into a tooltip.
   - Move the footer sentence into the panel.
   - Give "Taken" arrows and other tooltip hosts 48 px hit areas.
5. **Setup board labels.**
   - Problem: nameplates, BRACE and KEEPER tags collide with neighbouring sprites, and the tooltip covers units.
   - Fix: anchor the tooltip beside the effect list (in the right panel, or to the left of the hovered row) rather than over the board, and offset nameplates below each tile's footprint.
   - Use "Def" in both the tooltip title and the row.
6. **Primary buttons on every screen** (Set out, Confirm, Advance, Continue): give the primary action a filled amber button with dark text and size it larger than secondary actions, as SAP's Roll does. Today every button is the same thin outline.
7. **Encounter choice rows:** cut to two lines (choice title; then hero + one gain chip), and move "Strong shift" / "capped at edge" into the tooltip. Enlarge the mini grids or drop them for a single arrow chip.
8. **Draft:** make ability blurbs match hero detail ("Front foe + sides"). Raise stat label contrast and spacing. Fill the right panel void on setup by moving GREW FROM up or tightening the panel height.
9. **Intro cards:** add the subject to bare "+40%" chips ("Ilse +40%"), or group them under "Ilse:", so two identical numbers are distinguishable.
10. **Battle roster:** the after-crop is thinner than the before. Use a slightly heavier weight or one size up for names and HP, so the phone-size punch beats the old frame.

## Round-4 build (local, 2026-10-05)
Built against the round-3 fix list after studying Sea of Stars footage2 014/015/016 and SAP 015/016 beside our r3 draft, encounter, hero detail and setup captures. Captures for critic round 4 in `captures/hires-ui/r4/` (before frames copied from r3/before/); flow screens in `captures/flow/r4/<screen>/{1080,phone}/`.

- **0 Capture tooling.** With the 2x laptop panel (eDP-1) beside the 1x DP-2, Hyprland captures came out at 3840x2160. `tools/godot_run.sh` now uses `xvfb-run` for every capture run (any `--resolution`) when it is installed; otherwise the hyprctl path opens the window on a scale-1 monitor (the focused one first, else the largest), or at RES / scale when every monitor is scaled. No change to the user's Hyprland config. smoke.sh passes; every r4 still is 1920x1080 or 2340x1080.
- **1 Overlaps.**
  - Hero detail: NEW is a corner badge straddling the cell's top-right edge, so the "Paladin" plaque fits its cell; the party tab's "!" badge sits on the portrait's far corner, clear of the name.
  - Battle: before each number, KO! or heal, `battle.gd _avoid_for()` hands BattleFX the other living units' heads/shoulders and HP plates (world rects) and the target's own body; `BattleFX._clear_of_units()` moves a popup that would touch a neighbour down onto its own unit (at most 55% of its height) and sideways toward its own centre line, never into another popup. A killing blow's number drops with the collapsing unit. Firestorm frame 600-640: CRIT 65 sits on Vael, KO! on Vael's body, clear of Ilse's staff and HP plate.
  - Setup: each name plate (and its role tag) slides left/down under its own feet until it clears the other heroes' opaque sprite pixels (measured from their idle frames, the dragged hero included) and the plates already placed (`FormationBoard._plate_spot`). Brannoc's plate no longer touches Sable's bow; in the locked-Crescent drag preview, where the dragged Ilse stands on Brannoc's own slot, his plate moves beside her but still clips her staff slightly (no free spot left; sprite crowding).
  - Setup tooltip: every effect row's tooltip opens in the card's reading pane under the list (zone placement), never over the board.
- **2 Crystal caption.** The fragment banner waits until the action that broke the fragment has had its numbers on screen (caption up, popups cleared) and then takes the slot; the old caption is dropped, never restored. If the next action starts first, the banner shows first and that action's own caption follows.
- **3 Calm and punch.**
  - Primary actions are a theme variation `PrimaryButton`: filled amber, dark text at size 15, 28 design px tall (secondary 22, outline). Used for Set out, Confirm, Continue (encounter, run encounter, road), Advance (road, hero card, advancement card), To Lanternrest, New run (Lanternrest and title's first entry). Helper: `FlowUI.primary()` / `make_primary()`.
  - Encounter rows: two lines: the action, then hero + the move (arrow + words) with an amber Awakens glyph/word and "+ X joins". The level step, strong shift, edge cap and how to read the grid are in the tooltip on the mini grid (tap it; the rest of the row chooses).
  - Hero detail: one class word (the grid token wears the card's class: Healer, not Cleric); the tier pill dropped (the stage star marks an advanced class; its class line's tooltip holds the Legendary gate); level on one line and "Memories" as one labelled trail of 16x16 (48 px) wells, each arrow drawn x2, empty wells for the memories still to go; section headers removed (icons name the strips); the relic row reads "+1 Mercy +10 HP" with no low-contrast "offset"; the status sentence is inside the hero card; party tabs lose their mini grids.
  - Draft: one serif (the name), everything else bold sans; ability = icon + name + the same short label as hero detail (`PartyModel.ability_short`); stat labels INK9 with more room above the values; the caps ALIGNMENT badge replaced by the alignment mark and a plain sentence.
  - Setup: Confirm is the amber primary; the card's free lower half is a framed reading pane ("Tap an effect to read it") where tips open; tooltip titles say "Def" (and Atk/Mag/Spd/HP), matching the rows.
  - Battle: intro stat chips keep their subject ("Oren +40%", "Brakka Crit +15%"); roster names and HP at size 15 bold (rows 20 design px) when every name on that side fits, else the side stays at 10.
- **Not done:** sprite crowding (separate task); the encounter party bar's small level pips; on a two-axis shift with an Awakening (e.g. Brannoc "Cruelty +1, Freedom +1") the row shows the amber Awakens glyph without the word (no room beside the grid; the tooltip says it).
