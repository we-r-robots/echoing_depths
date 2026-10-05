# hires-ui: critic round 1 (2026-10-05, cloud session): FAIL

Task: docs/tasks/hires-ui-text.md. State judged: commit 9544fc0 (captures listed in f709159). 132 tests pass and tools/smoke.sh passes (checked on a clean checkout of every milestone commit).
The cloud session stopped after this round at the user's request. The loop continues locally from here.

## Result
- **Blind pairs: ours won 2 of 5.** Both wins were against Super Auto Pets. All 3 Sea of Stars pairs went to the reference (ours won pair 2 at full size only).
- **Open review: FAIL.** The causes are unreadable text and overlaps; no rule regression caused by this task was found.
- **Round 1: FAIL.** A pass needs a majority of pairs, including at least one Sea of Stars pair, plus an open-review pass.

**Pairs.** Each pair was judged at full size (1920x1080 per side) and at phone size (the same pair image halved, 960x540 per side). The overall winner is the critic's, and phone size decides legibility questions. Decoded from captures/.keys/hires-ui-r1.txt.

| Pair | Ours | Reference | Full | Phone | Overall | Confidence |
|---|---|---|---|---|---|---|
| 1 | draft/1080/two_picked | Sea of Stars frames_footage2/014 (shop list + detail card) | ref | ref | **ref** | med |
| 2 | encounter/1080/colossus_choices | Sea of Stars 015 ("Sell for 11 G?" modal) | **ours** | ref | **ref** | low |
| 3 | hero_detail/1080/ilse_relic_bound | Sea of Stars 016 (equipment shop list) | ref | ref | **ref** | med |
| 4 | setup/phone/tooltip_open (2340x1080) | Super Auto Pets 015 (tooltip open) | ours | ours | **ours** | med |
| 5 | setup/phone/locked_fallback (2340x1080) | Super Auto Pets 016 (shop) | ours | ours | **ours** | med |

**The biggest remaining gap (critic):**
- The secondary text is thin 1-unit strokes in dim violet-grey (contrast 2.5–3.9:1), so at phone size about a third of the text on every menu screen fades out.
- The screens are no calmer than before, because the finer text never reclaimed any space.

**Verified as working (critic's own measurements):**
- **Legibility floor:** the smallest text measures a 16 px x-height at 1080p, so the 14 px floor holds.
- **Rendering:** glyphs are crisp with no anti-aliasing, and the world is pixel-exact (every edge sits on the 3 px grid in every scene).
- **Wide aspect in battle:** fills the extra width cleanly, with no bars or stretching.
- **Rules:**
  - Numbers sit on their target and clear before the next action (checked frame by frame in fight.mp4 and crystal_demo.mp4).
  - The 2x4 grid per side is unchanged, and the opponent's formation stays hidden on setup.
  - The Fading has no SUDDEN DEATH label.
  - Every touch target is at least 50 px at 1080p.

## Open question for the user (decide before round 2)
**Intro cards and the setup Details view.** The critic flags two surfaces as breaking "Effects are shown as icons, not paragraphs … the tooltip is the only place long effect text appears":
- the battle **intro cards**, which show stat words ("▲ CRIT +15%") and a one- to two-line behaviour sentence;
- the setup **Details** view, which shows five lines of effect prose in the card.

Both existed in this form before this task. The before captures at ccff74d show the same intro-card sentence, so this is not a regression. Either:
- (a) declare them exempt (the intro card and Details are the deliberate "read it once" surfaces) and record that in docs/BUILD.md, or
- (b) convert them to icon chips plus a tooltip, as the critic's fix 1 describes.

## Round-2 fix list (the critic's prioritised list; do these in order)
1. **Intro cards and setup Details: the effects-as-icons rule.** Only if the user picks (b) above.
   - The card becomes the title, one row of shared stat-icon chips with green ▲ / red ▼, and a behaviour glyph with a label of 20 characters or fewer.
   - The full sentence goes only in the tooltip (tap or hold).
   - Drop the repeated "Shardpoint:" prefix.
   - Details opens the tooltip component instead of replacing the rows with prose.
2. **Muted text tier, all screens.**
   - Raise colour (110,112,163), about 3.9:1 on the panel ink, to at least 4.5:1 (around (150,152,195)).
   - Never use (82,82,135) (2.5:1) for informative text.
   - Cases: "replaced on advancing", "No Relic / A Relic binds when equipped", "/ 6", MEMORIES, "1 more to advance", the setup and draft header sub-lines, "Health 4/5", "Order lean · joins the codex", "needs Mercy 1 · 2 memories left".
   - Consider Depths Sans Bold (2-unit stems) for size-10 text on dark panels, so strokes stay 2 px at phone scale.
   - Fixed means every line is readable in a 960 px wide frame.
3. **Setup drag preview.**
   - The floating "Crescent: as Tidebreak" plate covers Holt's name plate, and the dragged sprite covers the "B" of Brannoc.
   - Anchor the plate above the dragged hero or in the board's top strip, and draw name plates above sprites.
4. **Hero detail plates.**
   - The "Paladin NEW" plate overhangs the grid's left frame by about 25 px.
   - The "Cleric" plate crosses its cell's bottom border, and the relic marker hangs into the cell below.
   - Clamp them inside the cell or frame with at least 6 px clearance.
   - Vertically centre the text in the NEW, ACTIVE and BOUND pills ("NEW" has 0 px top padding).
5. **Setup tooltips.** They open on the board floor about 400 px from their row, with a nub pointing at nothing. Open them beside the source row, pointer on the row.
6. **Battle number anchor.**
   - Anchor numbers and tags to the top of the target sprite's real bounds plus a gap, not a fixed height.
   - Current misses: the Stone Sentinel's 21 lands on its chest; the Hollow Rat's 77 floats over the Fading Wisp, so it reads as the Wisp's hit; the Crystal fight's 33 and 24 are ambiguous on overlapping targets.
   - Keep at least 6 px between world labels ("Shardpoint") and HP bars.
7. **Setup chrome.**
   - Hide the empty double rail on the board's left edge.
   - Dock "With one more hero" / "Grew from" under the rows to close the right-panel void.
   - Move the BRACE tag off Holt's sword (above the sprite's bounds).
8. **Encounter at 19.5:9.**
   - Centre the painting and text column as a group; there is about 380 px of dead black between them now.
   - Show the hero name in hero colour instead of "[Vesper]".
   - Give "Ready to Awaken" at least 16 px lead space.
   - Use a strong border and fill for the selected row.
9. **Hero detail.** Set ORDER and FREEDOM horizontally or rotated, not stacked letter by letter. Make footers one plain clause.
10. **Draft.** Use one serif title plus one sans subtitle in the header. Use fewer colours per card: neutral stat labels, with colour only on values and icons.
11. **Consistency.**
    - Use one arrow glyph for level and stat changes; today there are three ("Lv 2→3", "2 ▸ 3" and "Lv 4 → Lv 1").
    - Every caption shows "▸ target" or a clear untargeted form ("The Weaver of Names Flicker" has none).
12. **Use the reclaimed space.**
    - The text kept its old footprint, so density did not drop and the before/after is not obvious at phone size.
    - Add real breathing room to at least setup and hero detail.
    - Re-shoot the before/after with a phone-size row.

**Smaller items from the critic:**
- Sprites show through the translucent victory band behind the subline.
- The Crystal's "Woven likeness" label crowds the fragment pips, which also slip under the enemy roster's border at victory.
- The 3 px orange button frames are heavier than their labels.
- The Crystal video loops back into the fight start at about 59 s (a capture-length artifact).

**The builder's own known gaps, not covered above:**
- Text is fully crisp only at 1080p and 4K. At 1280x720 and 2560x1440 it is hinted (even stems, ±1 px spacing).
- HP bars under units are still chunky world pixels.
- There is no DEFEAT capture, because both demos end in victory.
- Hearthguard hits show no "Hearth" tag. The event data decides that, not the drawing code.
- The "fading ×1.24" tag on a number repeats the Fading readout.
- The scene test's runtime size check covers only the first 45 frames of each demo.
- Notch insets are untested on a device.
- Damage numbers are now one colour; the old digit sheet was two-tone.
- Sprite crowding on the formation board is a separate, known issue. Don't claim it.

## How round 1 was run (repeat this for round 2)
1. **Captures:** `tools/capture_hires_ui.sh` re-creates captures/hires-ui/ (both resolutions, the videos, before_after/, crops/). captures/hires-ui/INDEX.md describes each file. The pre-task "before" frames came from a checkout of ccff74d.
2. **Pairs:** `tools/blind_pair.py <ours> <ref> captures/hires-ui/critic<N>/pairs/pair<i>_full.png hires-ui-r<N> 1920x1080`, then halve each full pair image (LANCZOS) to make pair<i>_phone.png. Halving keeps A and B in the same order, with one answer key per pair.
   - **Fix for round 2:** pairs 4–5 put a 2340x1080 capture into a 16:9 frame, so our text showed at about 82%. Pass `2340x1080` as the size for the phone pairs instead. Super Auto Pets 015/016 are 960x450, about 2.13:1, so the shapes match.
3. **Critic:** a fresh general-purpose agent is given the brief in Appendix B, with the round folder substituted.
   - It writes Part 1 (blind pairs) to notes/part1.md before it opens any other capture.
   - It never reads captures/.keys/, git history, docs/RESUME.md or progress/.
   - Subagents may be refused writing report.md, so the lead saves the returned report.
4. **Decode and record:** decode captures/.keys/hires-ui-r<N>.txt and log the verdict plus the biggest gap in docs/RESUME.md and `python3 progress/log.py`. Add a round to progress/state.json's hires-ui piece.

The full critic notes (Part 1 verbatim) and the Part 2 review follow in Appendix A.

## Appendix A: the critic's notes (round 1)
Part 1 is verbatim from notes/part1.md, written before the critic opened any other capture. Here A is the left image and B the right; for the decoding, see the table at the top.

### Part 1: blind pairs (written before opening any other capture)

Method: each pair image was split into its A (left) and B (right) halves. I viewed each phone half at native
960x540, each full half as four 960x540 quadrants at 1:1, and zoomed the smallest text (nearest x2/x3).
The pair composites are 3864x1128 (48 px label band; A at x 0-1919, 24 px gap, B at x 1944-3863).

#### Pair 1: A = hero-pick screen with three cards; B = food shop list with a parchment detail card

A (hero pick)
- Full size: glyph edges are crisp. Strong two-family hierarchy: serif hero names ("Fenn", "Isolde") and serif
  skill names ("Strike", "Cleave"), with a pixel sans for body text. Stat cells (HP/Atk/Def/Mag/Spd over the value)
  are tidy and aligned.
- Header (top-left): "Choose two heroes" (serif, gold) runs straight into a two-line sans block ("to begin the
  descent" / "More can join on the road: four at most."). That makes three styles on one baseline band. It reads
  like a sentence broken into two typefaces. The dim second line is small and low contrast at phone size.
- Density: each card has 7 text rows plus a 5-cell stat strip and two right-aligned tags (BASIC / ABILITY,
  front/back). Five label colours appear per stat strip, and role colours (red, orange, teal, purple) add more.
  Three cards side by side make a busy wall of text.
- The unselected card (Dagny, centre) is dimmed as a whole, text included. At phone size its grey-on-navy body
  ("Holy hit, front foe", "Heals the weakest ally") is the hardest text on screen to read.
- Small grey tags "BASIC" / "ABILITY" and the bottom hint bar ("ALIGNMENT  Each class starts at a fixed place...")
  are readable at phone size but sit near the floor. The hint bar's text is long, one line, light grey.
- Chrome: thin 1 px-style frames, an orange selected border and pick banners ("First pick", "Second pick") are
  consistent. They look plain next to B but are clean.

B (food shop)
- At phone size the list rows ("Mooncradle Fish Pie 18 G", "Roast Sandwich 8 G") are big, well spaced and
  instantly readable. The selected row is a strong blue bar with a pointer. The hierarchy is obvious.
- Full size: everything is visibly soft and upscaled (blurred glyph edges, fuzzy icons). Typographic crispness is
  clearly worse than A's at 1:1.
- Redundancy: "An Evermist Island classic." appears twice, in the top bar and in the detail card. A "Zhain Gaming"
  watermark sits on the parchment card.
- Controller prompts "SELL" / "BACK" (bottom right) are tiny small caps, near illegible at phone size.
- Chrome is premium and consistent: ornamented panel corners, a parchment card with torn edges, a stat ribbon
  "+55 HP / +5 MP (Party)", and tidy ingredient chips.
- Calm: a single focus, generous row height and few colours. The bottom of the list panel is empty but not
  distracting.

Verdict: full size **B** (low: A is crisper, but B's chrome and calm win); phone **B** (med); OVERALL **B** (med).

#### Pair 2: A = narrative "Riddle" encounter (art left, text and 3 choice cards right); B = "Sell for 11 G?" modal over a shop

A (riddle encounter)
- Full size: excellent title block: small "RIDDLE" label with rules, a large serif gold title "The Weeping
  Colossus", an ornament, then the body. Crisp glyphs, and a clear top-down hierarchy.
- Body paragraph (right, centre): about 70-character lines of light grey sans. x-height is roughly 6-7 px at phone
  size: legible but under-sized for a 6" phone, and the wide lines make it tiring.
- Choice cards (right, lower): each packs a bracketed coloured name ("[Vesper]"), the answer, "+1 Memory Lv 2→3",
  a boxed "Ready to Awaken" tag jammed right after the "3", and a direction line ("Cruelty +1 Freedom +1
  ★ Strong shift"). Up to five colours per card plus a mini 4x4 grid on the right. Noisy and tight. The tag box
  nearly touches the preceding text.
- "★ Strong shift" (third card) and "Lv 2 •••" (top bar) are dim and small.
- The top bar (portrait, name, Lv, pips, mini grid x3, then "Depth 4" plus four lantern pips) is neat. The mini
  grids are cryptic without a legend (the "Grid: ■ now □ after this choice" legend is far away, above the cards).
- The third card's selection markers are tiny diamonds at its left and right edges: a weak focus cue.

B (sell modal)
- At phone size the main text ("Rock Lid", "Sell for 11 G ?", "Keep" / "Sell") is big and instantly clear. The
  dimmed list behind makes the modal the only focus. This is very calm.
- Micro labels are tiny: "ITEM NAME", "OWNED / PRICE", "PREVIOUSLY EQUIPPED" (cap height about 4-5 px at phone),
  and "KEEP" by the B button. These are effectively illegible at phone size.
- Full size: soft, upscaled blur on all text and icons. Watermark "Zhain Gaming" in the empty area.
- The modal has a dead empty band between "Sell for 11 G ?" and the buttons. The right panel shows two portraits
  with nothing beside them, which looks unfinished.
- The stat-change preview (sword 41 → 36 (-5), 32 → 28 (-4)) is clear with red deltas.

Verdict: full size **A** (med: crisper, better typographic hierarchy, B's micro labels are tiny); phone **B**
(low: B's working text is far larger and calmer, A's paragraph and cards are small and busy); OVERALL **B** (low).

#### Pair 3: A = hero detail (stats, equipment, ability, 5x5 alignment grid); B = equipment shop list

A (hero detail)
- Full size: crisp. Section headers ("STATS", "EQUIPMENT", "ABILITY") use rules, and the stat strip is aligned.
  The bound item row (orange) stands out.
- Many dim, low-contrast greys at the floor: "/ 6", "MEMORIES", "Taken", "1 more to advance", "replaced on
  advancing", and the ability description "Heals the weakest ally (220%), then melee enemy for 90% magic." (dim
  grey, two lines). At phone size these are the weakest texts on any screen in Part 1.
- The vertical axis labels "ORDER" / "FREEDOM" are stacked letter by letter (left and right of the grid). Stacked
  caps are slow to read, and "FREEDOM" runs down the full right edge.
- In the grid, the "Cleric" label plate under the portrait crosses the cell's lower border into the next cell, and
  a small orange marker hangs below it. The cell content spills over the cell edges.
- Footer hint "Ilse's Dawn Locket is bound and holds them a step off their memories' path, on Cleric ground." is
  long and jargon-heavy, in small light-grey type.
- Density: two panels packed edge to edge, a 4-hero tab bar and a location box. There is little breathing room.
  Colour count is high (brown, purple, teal, red tiles; orange, teal, green, red labels).

B (equipment shop)
- At phone size the item names and owned/price numbers are big, evenly spaced and right-aligned in chips. They are
  instantly readable, and the selected row is unmistakable.
- "SOLD OUT" chips, the "ITEM NAME" / "OWNED / PRICE" column heads and the "BUY" prompt are tiny small caps, at the
  edge of legibility at phone size.
- Full size: upscaled blur again. Watermark present.
- The right panel (three portraits, no info beside them) is mostly empty.
- Chrome is consistent and premium (ornamented corners, chip cells, dividers). Calm, with one focus.

Verdict: full size **B** (low); phone **B** (med); OVERALL **B** (med).

#### Pair 4: A = cartoon auto-battler shop (phone recording, letterboxed); B = "Formation / Before the fight" screen (letterboxed: a wide frame shrunk into 16:9)

A (cartoon shop)
- Big, punchy primary type: "Roll", "Freeze", the team name "The Obtuse Millionaires" in a heavy outlined face, and
  resource counters (0, 9, 0/10, 3). These are readable at a glance at phone size.
- Secondary text is tiny and blurred (low-bitrate capture): "Lose → -2" under the heart, "Lvl" badges, the "3 GOLD"
  signpost, and the tooltip body "Give a pet Meat Bone. (Attack for 4 more damage.)" (about 4 px x-height at phone,
  blurry italics).
- The "End turn" button label is unreadable, overwritten by an "XRecorder" watermark.
- Compression mush on all edges at full size.
- Chrome is consistent (white rounded chips, orange buttons), but the scene is loud: saturated greens and yellows
  everywhere, with text over busy art.

B (formation screen)
- Crisp glyphs at full size. Clean header: "Formation" (serif gold), "Before the fight" over a dim "The Drowned
  Archive · Depth 7", and on the right "Next: Echo of the Ashen Vow" over "Their formation stays hidden until the
  fight" with hearts and "Health 4/5".
- The frame is shrunk (letterboxed) here, so all text is about 82% size. The bonus list ("Ilse Healing +40%", etc.)
  is about 5 px x-height at phone size: crisp but small. "GREW FROM" and the dim header sub-lines are smaller still.
- The "Defence / Front heroes get Def +30%" tooltip floats at the bottom of the board area, detached from what it
  describes, with a stray pointer nub at its top-right corner.
- Odd chrome: a vertical double rail on the left edge of the board panel, and a large empty dark area on the left
  half of the board panel.
- The right panel is consistent: an icon chip per bonus, dividers, two outlined buttons (Details / Confirm). Calm
  palette.

Verdict: full size **B** (high); phone **B** (med); OVERALL **B** (med).

#### Pair 5: A = formation screen (Tidebreak variant, letterboxed); B = cartoon shop (same recording style as pair 4 A)

A (formation screen)
- Same clean header and right panel as pair 4 B. Crisp text, calm palette, clear title / label / body hierarchy.
- The "BRACE" tag is drawn over Holt's sword blade (centre of the board): a direct overlap of a label on a sprite.
- The right panel is half empty: five rows, then a large void above Details / Confirm.
- Status line "Crescent locked: fighting as Tidebreak" (bottom of the board) is light grey and small.
- At about 82% scale the list text is about 5 px x-height at phone: readable but small.
- Same vertical double rail at the left of the board, and the empty dark band.

B (cartoon shop)
- "Roll" is huge and instant. Counters are readable at a glance.
- "End turn" is again unreadable (watermark). The "Battle" signpost and "3 GOLD" signpost are tiny. "Lose → -2" and
  "Lvl" badges are tiny and blurred.
- Heavy compression at full size, with soft edges throughout.
- The frozen shrimp (ice block) reads well, but the overall scene is visually loud.

Verdict: full size **A** (high); phone **A** (med); OVERALL **A** (med).

#### Part 1 summary table

| Pair | Full size | Phone size | OVERALL | Confidence |
|---|---|---|---|---|
| 1 | B | B | B | med |
| 2 | A | B | B | low |
| 3 | B | B | B | med |
| 4 | B | B | B | med |
| 5 | A | A | A | med |

### Part 2: open review of the game under test (critic round 1, as returned)

**Method:**
- LANCZOS phone-size copies of all 88 stills (960 px wide for 1080p, 1170 px for 2340x1080) and full-resolution quadrants of each.
- Nearest-neighbour zooms, glyphs measured as ASCII bitmaps, colours sampled for contrast ratios, and an edge-phase test on the world pixel grid.
- ffmpeg frames from both videos: 4 fps and 3 fps contact sheets, plus 15 fps for the Firestorm hit at 9.6–11.1 s of fight.mp4.

#### Global measurements

**Legibility floor holds.**
- Body and labels at size 10 measure a 16 px x-height at 1080p (2 px per font pixel). Measured on the intro-card body, the lore caption and the "Shardpoint" world label.
- Small caps measure a 22 px cap height (GREW FROM, MEMORIES).
- World tags ("Rear 1/2", "fading ×1.25") are at 3 px per font pixel, a 24 px x-height.
- Nothing is below the 14 px floor. The claim "smallest text = 16 px" is true.

**Rendering is clean.**
- **Crisp glyphs:** serif titles have 3–5 colours per crop, so there is no anti-aliasing.
- **World is perfect pixel art:** 100% of edges sit on a 3 px grid in battle (1080 and 2340), encounter, setup, draft and hero-detail sprites. No blur.
- **Two pixel grids:** text is on a 2 px grid, while borders, chips and effect icons are on the 3 px world grid. It reads as intentional and mostly harmonious. But the 1-unit-stroke sans looks thin inside 3 px frames, and at phone size its strokes are 1 px.

**The muted text tier is too dim.** Body text is 10–11:1 and the bright tier 15.7:1, but two muted colours are used for informative text:

| Colour | Contrast | Used for |
|---|---|---|
| (110,112,163) | 3.9:1 | header sub-lines on setup and draft; "Health 4/5"; "/ 6"; MEMORIES; "1 more to advance"; "Order lean · joins the codex" |
| (82,82,135) | 2.5:1 | "replaced on advancing"; "No Relic / A Relic binds when equipped" |

**Touch targets are fine.**

| Target | Size at 1080p |
|---|---|
| x1 / SKIP | 120x54 |
| Banner chips | 60x60, 9 px gaps |
| Setup Details / Confirm | about 178x55 |
| Close | about 130x50 |
| Set out | about 220x50 |
| Encounter rows | about 870x130 |
| Setup effect rows | about 66 px tall |

#### Battle (PvP, monsters, fight.mp4)

**Readable at phone size:** names, HP, the caption, the timer, the buttons, the banners, the tooltip and the numbers. The intro-card behaviour sentence is the weakest text but is readable.

**Overlaps:**
- In ko_rear_tag, the "Shardpoint" world label touches the HP bar above it (0–1 px) and the diamond icon.
- In tall_sentinel, the Stone Sentinel's "21" lands on its chest, not its head.
- In the same frame, the Hollow Rat's "77" floats about 90 px above the rat, over the Fading Wisp's face, so it reads as a hit on the Wisp.
- Sprites show through the translucent victory band behind the subline.
- Nothing is clipped at screen edges.

**Font:**
- The hierarchy is clear. The ability band (small caps "BRAKKA · ABILITY" over the serif "Cleave") is good.
- The intro card repeats its own title ("Shardpoint: The tip…").

**Chrome:** consistent. The 3 px orange button frames are heavier than their labels.

**Wide aspect is good.** At 2340 the world shows more floor and both torches, with no bars and no stretching. Banners and rosters anchor to the corners, and the caption and timer stay centred.

**Rules:**
- **Numbers:** on target and cleared per action. At 9.87–10.60 s, Firestorm's 32 / 20 / 32 / CRIT! 65 / KO! sit on their targets. All clear at 10.67 s, before Smite's 22 at 11.00 s.
- **Grid:** the 2x4 grid per side is unchanged.
- **The Fading:** presented in the fiction, with no SUDDEN DEATH label.
- **Tooltips:** the banner chips open the shared tooltip. The press-and-hold path cannot be shown in stills.
- **Break, by the letter of the rule:** the intro cards show stat effects as words ("▲ CRIT +15%", "▲ HEAL +40% CHARGE +40%") rather than shared stat icons. They also show a two-line effect paragraph outside any tooltip ("Keeper's ring: While all three front units stand, the ringed back unit can't be targeted at all (area splash still reaches it)."). BUILD.md says "the tooltip is the only place long effect text appears".
- **Lead's note:** this text predates the migration; see "Open question" above.

#### Crystal (stills and crystal_demo.mp4)
- **Lore caption:** 16 px light sans on a translucent band, readable but the faintest combat text. Beams and particles show through behind the words.
- **"Woven likeness" label (49.3 s):** crowds the fragment pips, and a particle crosses the "n".
- **Fragment pips:** at victory they slip under the enemy roster panel's top border.
- **Numbers 33 and 24 (fragment_banner):** they sit about 50 px apart on overlapping targets, so it is unclear which is whose.
- **Numbers on target:** they land on the Crystal and clear per action (31 shows at 46.0–47.0 s and is gone at 47.33 s).
- **Long memory names:** they fit the roster without truncation.
- **Caption with no target:** "The Weaver of Names Flicker" has no "▸ target", unlike every other caption.
- **Capture artifact:** the video loops into the fight start at about 59 s.

#### Monster fight
Same as battle: the number anchor is wrong for tall or overlapping units. Otherwise clean.

#### Formation setup

**Readability:**
- The main text is good.
- The muted 3.9:1 lines are faint: "The Drowned Archive · Depth 7", "Their formation stays hidden until the fight", "Health 4/5".

**Overlaps (fail):**
- In drag_preview_locked_crescent, the floating plate "Crescent: as Tidebreak" covers Holt's name plate (only fragments of "Holt" are visible).
- The dragged Ilse sprite covers the "B" of "Brannoc". That is a UI label covered by a UI plate or sprite, not just sprite crowding.
- In locked_fallback, the BRACE tag sits on Holt's sword.

**Font:** good (serif title, ACTIVE pill, icon plus a short label). The Details view (unformed_details) puts five lines of effect prose in the card, which raises the same rule concern as the intro cards.

**Chrome:**
- An empty double rail runs down the board's left edge (x≈36–56 at 1080) in every non-drag state. It looks like a seam.
- The right panel has a large void between the rows and the "With one more hero" chips.
- The board's lower-left is empty.
- Tooltips ("Defence / Front heroes get Def +30%.", and the locked-row tooltip) open on the board floor, about 400 px from the row they explain, with a nub that points at nothing.

**Wide aspect:** fine.

**Rules:** the opponent's formation stays hidden, with an explicit line saying so. Effect rows are icons with tooltips.

#### Draft
- **Readability:** all readable. The dimmed card body is 4.3:1, dim on purpose. "More can join on the road: four at most." is 3.9:1 and faint.
- **Overlaps:** none.
- **Header:** one sentence split across faces.
- **Colour:** about 7 colours per card.
- **Hint bar:** a long single-line ALIGNMENT hint.
- **Chrome and wide aspect:** both fine.

#### Encounter

**Readability:**
- The prose (16 px x-height, 11.2:1) is readable but small for paragraphs on a 6" phone.
- "★ Strong shift", the Lv pips and "Depth 4" plus the lantern pips are small.

**Spacing and cues:**
- "Ready to Awaken" starts only 12 px after the "3" at 1080p (6 px at phone size).
- The selected row is marked only by two tiny diamonds.

**Text style:**
- The choice rows use a dev-style "[Vesper]" in brackets.
- Arrow glyphs are inconsistent: "Lv 2→3" here, "2 ▸ 3" on the resolved card, "Lv 4 → Lv 1" on hero detail.

**Wide aspect is weak.** At 2340 the painting stays left and the text column anchors to the right edge, leaving about 380 px of dead black between the art and its narrative.

#### Hero detail

**Readability (fail):**
- "replaced on advancing" and "No Relic / A Relic binds when equipped" are 2.5:1 with 1 px strokes at phone size, and fail at arm's length.
- These are 3.9:1: "/ 6", MEMORIES, "1 more to advance", "Order lean · joins the codex", "needs Mercy 1 · 2 memories left".

**Overlaps (fail):**
- In advanced_paladin, the "Paladin NEW" plate overhangs the grid's left frame by about 25 px toward the ORDER arrow.
- The "NEW" text touches the top of its pill: 0 px padding at the top, 6 px at the bottom.
- In ilse_relic_bound, the "Cleric" plate crosses its cell's bottom border, and the relic marker hangs into the cell below.

**Layout and text:**
- ORDER and FREEDOM are stacked letter by letter.
- Footers are long and full of jargon.
- Two dense panels sit edge to edge.

**Wide aspect:** fine.

**Rules:** fine. The grid is 5x5 and only the Relic carries alignment.

#### Before / after
Is the difference obvious? Only partly.
- **Obvious:** battle_banner (chunky "SHARDPOINT" becomes the serif "Shardpoint") and encounter_text (a bigger serif title).
- **Not obvious:** in setup_card, setup_board_labels and draft_card the size and layout are the same. Only the stroke changes, from bold 3 px to thin 2 px.
- **At phone size,** before and after are nearly the same, and the old bold face arguably punches harder.
- **Promised space not reclaimed:** the "finer text frees space for calm" rationale was never acted on. The text kept its old footprint, so density is unchanged.

#### Verdict (as returned; A/B decoded in the table at the top)

| Pair | Winner at full size | Winner at phone size | OVERALL | Confidence |
|---|---|---|---|---|
| 1 | B | B | B | med |
| 2 | A | B | B | low |
| 3 | B | B | B | med |
| 4 | B | B | B | med |
| 5 | A | A | A | med |

**OPEN REVIEW: FAIL.** The rendering itself is solid: a crisp 16 px x-height floor that the critic verified, perfect 3 px world pixels and good wide-aspect battle. It fails on three counts:
- **Unreadable text:** on hero detail, "replaced on advancing" and "No Relic / A Relic binds when equipped" (2.5:1) are not readable at phone size.
- **Overlapping text:** on the setup drag preview, the plate covers "Holt" and the sprite covers "Brannoc". On hero detail, the Paladin plate crosses the grid frame and the Cleric plate and marker cross cell borders.
- **Rule break, by the letter:** the battle intro cards (stat words plus a two-line behaviour paragraph) and the setup Details view break "Effects are shown as icons, not paragraphs … the tooltip is the only place long effect text appears". The first two counts fail the review even if the lead rules these surfaces exempt.

The critic's prioritised fix list is reproduced as the "Round-2 fix list" at the top of this file.

## Appendix B: the critic brief used in round 1
For round 2, replace critic1 with critic2 in the paths and update the pair list.

> You are a HARSH, independent CRITIC for the Echoing Depths gauntlet loop (Godot pixel-art auto-battler, repo /home/user/echoing_depths). You have fresh context: you did not build this and owe the builder nothing. Your job is to find what is wrong, not to encourage. Vague praise is useless; specific, located, fixable faults are what the builder needs.
>
> ## Strict rules
> - NEVER read, list or open anything under captures/.keys/ (blind answer keys). Do not run tools that read it. Do not read git history, commit messages, docs/RESUME.md or progress/ (they would reveal which side is ours).
> - Judge only from the images listed below plus the two rule documents named below (docs/BUILD.md and docs/tasks/hires-ui-text.md).
> - Part 1 uses ONLY the pair images in /home/user/echoing_depths/captures/hires-ui/critic1/pairs/. Do not open anything else under captures/ until your Part 1 verdicts are written to /home/user/echoing_depths/captures/hires-ui/critic1/notes/part1.md.
> - Do not edit any file in the repo. Write your scratch files only under /home/user/echoing_depths/captures/hires-ui/critic1/notes/.
>
> ## What is being judged
> A UI migration: all UI text and chrome of the game moved to a higher-resolution layer with a new pixel-STYLED but readable font, while the world stays 640x360 pixel art. The user's font direction: "mimic a pixel font, but readability is important, so don't take the pixel look to an extreme." Judge UI text and chrome quality, clarity, hierarchy, calm and readability, against the bar of the reference games: Sea of Stars menus (calm, clean, readable, premium) and Super Auto Pets shop (instantly readable, punchy, big type).
>
> ## Part 1 — blind pairs (do this FIRST, before looking at any other image)
> Each pair image shows two game screens, labelled A and B. One is from the game under test, one is a reference game. You are not told which. For each pair, judge ONLY these dimensions, on what you see: text legibility (at this size, which approximates a phone held at arm's length), typographic quality (font, spacing, hierarchy), UI chrome quality (panels, frames, alignment, consistency), clarity of information and calm (density, noise, clutter, overlaps). Do not judge which game is "more fun" or the world art.
> For each pair give: the winner (A or B), a confidence (low/med/high), and 3–6 concrete observations per side (location + what is wrong or right). Be decisive: a tie is not allowed.
> Pairs:
> - Pair 1: /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair1_full.png (each side 1920x1080: full size) and /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair1_phone.png (the same pair halved: each side 960x540, about a 6" phone at arm's length)
> - Pair 2: /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair2_full.png (each side 1920x1080: full size) and /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair2_phone.png (the same pair halved: each side 960x540, about a 6" phone at arm's length)
> - Pair 3: /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair3_full.png (each side 1920x1080: full size) and /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair3_phone.png (the same pair halved: each side 960x540, about a 6" phone at arm's length)
> - Pair 4: /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair4_full.png (each side 1920x1080: full size) and /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair4_phone.png (the same pair halved: each side 960x540, about a 6" phone at arm's length)
> - Pair 5: /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair5_full.png (each side 1920x1080: full size) and /home/user/echoing_depths/captures/hires-ui/critic1/pairs/pair5_phone.png (the same pair halved: each side 960x540, about a 6" phone at arm's length)
> In every pair image, A is the LEFT image and B is the RIGHT image (the letters are drawn small at the top). For each pair give a winner at full size, a winner at phone size, and an OVERALL winner; when the two sizes disagree, the phone-size result decides legibility questions.
>
> ## Part 2 — open review of the game under test (after Part 1 is written down)
> Images of the game under test (full resolution; 1920x1080 is a 16:9 PC/phone frame, 2340x1080 is a 19.5:9 wide phone):
> - /home/user/echoing_depths/captures/hires-ui/<screen>/1080/*.png and /home/user/echoing_depths/captures/hires-ui/<screen>/phone/*.png for every screen folder: battle, crystal, monsters, setup, draft, encounter, hero_detail. /home/user/echoing_depths/captures/hires-ui/INDEX.md says what each file shows (read it only in Part 2).
> - Videos: /home/user/echoing_depths/captures/hires-ui/battle/fight.mp4 and /home/user/echoing_depths/captures/hires-ui/crystal/crystal_demo.mp4 (1080p). Extract frames with ffmpeg into /home/user/echoing_depths/captures/hires-ui/critic1/notes/ to check that numbers sit on their target's head and clear per action.
> - /home/user/echoing_depths/captures/hires-ui/before_after/*.png: the same UI regions before (old 640x360 frame shown x3) and after. The task requires that the difference is obvious; say whether it is.
> - Ignore /home/user/echoing_depths/captures/hires-ui/before/ and /home/user/echoing_depths/captures/hires-ui/crops/.
>
> For phone-size readability, also view each image downscaled to phone size (a 6-inch phone held at arm's length ≈ a 960 px wide 16:9 frame, or 1170 px wide for 2340x1080). Make the downscaled copies yourself with Pillow (LANCZOS) into /home/user/echoing_depths/captures/hires-ui/critic1/notes/ and look at them. The game claims a minimum text x-height of 14 px (x-height at 1080p; the builder says the smallest text in the game is 16 px) at 1080p; check the smallest text you can find against it (measure in px on the full-res frame).
>
> Check and report, per screen:
> 1. Readability at phone size: every piece of player-facing text must be readable in the downscaled frame. List each text that is not, with its location.
> 2. Overlaps, clipping, text running into other text or numbers, text cut off at panel or screen edges, truncated labels.
> 3. Font quality: pixel-styled but readable (not chunky, not blurry, not anti-aliased mush); consistent sizes; a clear hierarchy (title / name / label / body / number); the sans and serif used consistently. Zoom into crops (nearest-neighbour 3x) to inspect glyph edges.
> 4. Chrome consistency: do panels, borders, icons and buttons sit at a consistent pixel scale with the text, or does it look like two different resolutions pasted together in a bad way? Is the world still crisp pixel art (no blur, no uneven pixels)?
> 5. Wide aspect (2340x1080): does the world fill the extra width sensibly (no black bars, no stretched art), are UI anchors sensible, is anything important cut off or stranded?
> 6. Rule regressions: read docs/BUILD.md section "Spec non-negotiables" and docs/tasks/hires-ui-text.md section "Spec" item 6. Any break is an automatic FAIL. In particular: battle damage numbers sit on their target's head and are cleared per action; nothing clipped at screen edges; effects are icons with tooltips and the tooltip is reachable on touch; the opponent's formation stays hidden on the setup screen; battle uses the 2x4 formation grid per side; touch targets look at least 48x48 px at 1080p.
>
> ## Verdict
> End with:
> - A table: pair, winner at full size, winner at phone size, OVERALL winner (A/B), confidence.
> - OPEN REVIEW: PASS or FAIL. PASS requires ALL of: every player-facing text readable at phone size, no overlaps or clipping, and no rule regression. (The pair results are decoded by the lead afterwards; the round passes only if the game under test also wins a majority of pairs including at least one Sea of Stars pair. You can't know which side is which, so just judge each pair honestly.)
> - THE BIGGEST REMAINING GAP: one sentence naming the single most important thing still wrong.
> - A prioritised fix list for the builder (most important first), each item concrete: screen, element, what is wrong, what "fixed" looks like.
> Write the full report to /home/user/echoing_depths/captures/hires-ui/critic1/report.md as well as returning it as your final message.
