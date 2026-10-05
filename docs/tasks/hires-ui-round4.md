# hires-ui: critic round 4 (2026-10-05, local): FAIL

State judged: dac80e1, captures in captures/hires-ui/r4/ and captures/flow/r4/ (first round to include the playable-flow screens). The critic's write was refused; this record is from its returned report. Part 1 notes: captures/hires-ui/critic4/notes/part1.md.

## Result
**Decoded pairs:** ours = A in pair 1, B in pairs 2–5. Ours **2/5**: won both Super Auto Pets pairs (setup tooltip vs SAP 015, low; locked fallback vs SAP 016, med). Lost all three Sea of Stars pairs: draft vs SoS 014 (med), encounter vs SoS 015 (med), hero detail vs SoS 016 (med).

**Open review: FAIL**, on three faults:
- **Clipping:** Lanternrest's "Lumari Chorus" tile label renders as "umari Chorus"; 4-tall shape icons poke above their tile frames.
- **Contrast:** the PvP splash "Tap to begin" pulses between 1.01:1 and 3.89:1 (below 4.5:1).
- **Crystal timing:** in crystal_demo.mp4 (~47–49 s at 10 fps) "FRAGMENT 3 OF 4" holds the caption box through Ilse's whole Smite (cast, 30, KO!), and her caption shows only after the number clears.

**Biggest gap (critic):** battle and setup text is genuinely readable now, but the new flow screens and the Crystal banner timing still ship clipped, near-invisible or out-of-step text.

**Verified:** 2x4 grid; intro cards and hero detail abilities as icon + label ≤ 20 chars; Details in the shared tooltip; splash shows rival heroes, never their formation; numbers on their own target and cleared per action (Cleave crit 22/CRIT 103/32 matched to roster HP; Crystal Firestorm 33/24/60; Fading ticks); touch targets ≥ 48 px; before/after obvious at full size and at phone size for setup and roster (modest for encounter).

**Why the Sea of Stars pairs keep losing (critic's notes):** density. SoS 014/015/016 are a shop list, a one-question sell modal and an equipment list; our draft has ~8 lines per card and five stat boxes, the encounter's choice titles are louder than its screen title, and hero detail shows three panels, a stat strip, equipment rows and a grid with four axis labels and four step plates.

## Round-5 fix list (critic's priorities)
1. Lanternrest tiles: label fits (shrink or wrap) with ≥ 8 px inner padding; shape icon scaled and centred inside the tile.
2. PvP splash "Tap to begin": the pulse never drops below 4.5:1 (e.g. between (147,150,192) and white), slightly larger, or a real button.
3. Crystal fragment banner: clears (or moves to its own slot above the board) before the next wind-up, so every hit's caption is on screen when its number appears.
4. Setup tooltip: a solid pane that masks the "WITH ONE MORE HERO" chip row (no stub bars under it), plus a highlight or connector to its source row.
5. Crystal enemy roster panel covers the Crystal's HP bar and a pip (fragment_4_of_4_in_the_fading): keep the bar clear.
6. Crystal lore subtitle: use the theme body sans or serif at body size, normal tracking (it's the thin condensed face now).
7. Encounter rows: always show "▲ Awakens" with its label (or icon + tap tooltip); shrink choice titles below the screen title.
8. Results: separator in "The Drowned Archive · The party fell on floor 4."; hide the world plaque/sprite showing through behind the panels.
9. Bad wraps: settings "hit-/stop", hero detail lone "grid.".
10. Draft footer: drop the input-field border; icon plus a plain caption line.
11. Battle crit stacking: lift "CRIT!" above its number or spread multi-target numbers so labels clear neighbouring sprites.

Smaller notes: setup board sprites bunch in the right half with the left half empty (pairs 4–5); hero detail "BOUND" row has two highlight treatments (fill and pill); hero detail Close is a small ghost button; draft "Order · Mercy" tags are noise at phone size.

## Round-5 build (local, 2026-10-05)
Built against the round-5 fix list above. Captures for critic round 5 in `captures/hires-ui/r5/` (before frames copied from r4/before/); flow screens in `captures/flow/r5/<screen>/{1080,phone}/` (now `tools/capture_flow.sh`, which adds the splash at frame 2 and the victory results, guardian splash and Crystal splash states).

- **1 Lanternrest tiles.** Training Grounds is 3 columns of 94x32 tiles: the shape icon (4 px cells, 19 px for a 4-tall shape) centred vertically in a fixed icon column, the name beside it left-aligned. The longest name ("Lumari Chorus", 66 px) keeps 8 px to the tile edge; the lock is a corner badge on the tile's top-right edge, clear of the name. Banner Hall narrowed to 266 so the panels never touch. Tests: `test_flow::test_lanternrest_tile_labels_and_icons_fit` (all 15 names fit with 8 px padding; every icon inside its tile, centred, clear of the name); the scene phase of `run_all.gd` now fails any one-line Label or Button whose text is wider than its box, spills out of the button/panel it sits on, or runs off the screen (it caught the old tiles when re-tried at the old widths).
- **2 PvP splash "Tap to begin".** Size 15 bold, visible from the first frame, pulsing in colour only between INK8 and INK10 (alpha stays 1): measured 6.9:1 at its dimmest in the frame-2 capture. Test: `test_ui_text::test_splash_hint_pulse_keeps_contrast` (>= 4.5:1 on INK3 over the whole pulse).
- **3 Crystal fragment banner.** Cause (battle_hud.gd): the banner shared the caption slot and `_draw_caption` returned while it showed (1.6 s); when the next action began during that time, `show_caption` started the banner first, so that whole action (Ilse's Smite: cast, 30, KO) played under "FRAGMENT 3 OF 4". Now the banner has its own slot at the top centre between the two formation badges (heading size when it fits there, else label size), shows as the fragment breaks, and never hides a caption; the wait/restore logic is gone. Checked frame by frame in the new crystal_demo.mp4 at 10 fps around all four breaks (13.6 s, 31.0 s, 46.1 s, 54.6 s): the breaking action's caption stays up with its numbers, and the next action's caption (Ilse Smite at 15.6 s and 47.9 s) is on screen before its number appears.
- **4 Setup reading pane.** A zone tooltip fills the whole reading pane (no narrower box with the growth row's bars round it), the growth block is not drawn while the pane is open, and the pane is wired to its row: an accent frame round the row and a rule down the card's left margin into the pane.
- **5 Crystal plate.** The four fragment pips sit on the integrity bar's line (right of it), so the five-row enemy roster in the Fading no longer covers them.
- **6 Lore caption** in the bold body face, in a wider box (480, wrap 456).
- **7 Encounter rows.** Choice titles are serif at the title size (a step under the screen title). Every Awakening shows the amber glyph and the word "Awakens", in one place on every row: the end of line 1, right-aligned before the mini grid.
- **8 Results.** "The Drowned Archive · The party fell on floor 4."; the backdrop is dimmed to 0.93 so the statue and plaque no longer show round the panels.
- **9 Wraps.** `UIText.wrap_lines` never leaves a lone last word when the line above can give it one (hero detail "on / the grid."); settings says "shake and a pause on heavy hits" (no hyphen to break).
- **10 Draft footer.** No box: a hairline, the alignment mark and one plain caption line.
- **11 Crit stacking.** CRIT! / KO! head words sit clear of the number's two-font-pixel ring (gap 3 + 2 font px, HEAD_H up by 2 world px).
- **Results vs Lanternrest totals.** Not a game bug: the real flow fills "Lanternrest now holds ..." from GameState.meta after banking (game_state.gd apply_summary). The two standalone demos used different made-up numbers (results said 1 Shard, Lanternrest's demo village 3); the results demo now says 87 Glimmers and 3 Shards, matching the Lanternrest demo.
- **Scan.** Disabled buttons' text raised from 4.1:1 to about 6.4:1 on their fill ("Form a Shard"); hero detail's held-back "Advance now" pushed the HELD tag off the card, so the button says "Advance" (the tag says held); hero detail BOUND is a lock and a word (no second pill treatment inside the lit row); Close is a standard 76x22 secondary button.
- **Not done:** sprite crowding on the setup board (separate task); draft "Order · Mercy" tags kept (they are the card's alignment, not decoration).
