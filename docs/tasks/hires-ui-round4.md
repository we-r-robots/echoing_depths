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
