# hires-ui: critic round 2 (2026-10-05, local): FAIL

State judged: 4a08adb, captures in captures/hires-ui/r2/. Pairs made with 2340x1080 framing for the phone pairs.

**Decoded pairs:** 1 draft vs SoS 014: reference. 2 encounter vs SoS 015: reference. 3 hero detail vs SoS 016: reference. 4 setup tooltip vs SAP 015: ours. 5 setup locked fallback vs SAP 016: ours. **Ours 2/5**, no Sea of Stars pair won. The critic noted the SAP frames are pillarboxed, blurry and watermarked, so those two wins carry little weight.

**Open review: FAIL.** Biggest gap: damage numbers float about one grid row above their target (the round-2 anchor change), so multi-target hits read on the wrong unit.

## Critic report (verbatim)

# hires-ui round 2: critic 2 report

Part 1 verdicts were written to `captures/hires-ui/critic2/notes/part1.md` before I opened any other capture. They are reproduced in short form here.

## Part 1: blind pairs

| Pair | Full size | Phone size | OVERALL | Confidence |
|---|---|---|---|---|
| 1 (hero draft cards vs shop list + detail plate) | B | B | **B** | medium |
| 2 (sell-confirm modal vs riddle with 3 choice rows) | A | A | **A** | medium |
| 3 (shop list vs hero detail + 5x5 grid) | A | A | **A** | medium-high |
| 4 (pets shop, pillarboxed vs formation setup, wide) | B | B | **B** | medium |
| 5 (formation setup, wide vs pets shop, pillarboxed) | A | A | **A** | medium |

Main reasons:
- **Pair 1 (B wins).** B has one focus, a big uniform list and generous rows. A is crisp and has a real serif/sans hierarchy. But each of its 3 cards stacks about 12 text items, so the smallest tier (stat labels, front/back, BASIC/ABILITY) gets thin at phone size. The dimmed unpicked card lowers the contrast of everything on it, and the header reads as three disconnected pieces.
- **Pair 2 (A wins).** A is one calm decision. B's choice rows are crowded: name, answer, memory delta, an outlined "Ready to Awaken" badge and a five-colour alignment line on one row, plus tiny mini-grids at the row ends.
- **Pair 3 (A wins).** A is a single clean list. B's left panel has 8 or more tiers of text all at about the same small size, so the hierarchy flattens. The vertical ORDER/FREEDOM labels are hard to read, and the grid says "Cleric" while the class line says "Healer".
- **Pair 4 (B wins).** A is pillarboxed with black bars on the wide frame and soft from compression. Its tooltip body is unreadable at either size, and a recorder watermark covers a button. B is crisp and consistent. B's faults: the floating "Defence" tooltip overlaps the board edge, and the muted header text is small.
- **Pair 5 (A wins).** A is clean, with icon chips per effect and a clear title / badge / subline order. Its faults: the lower half of the item panel is dead space, and "Crescent locked" appears three times. B has the same pillarbox, blur and watermark problems as pair 4.

## Part 2: open review of the game under test

### What is good (briefly)
- **Font and size floor.** The pixel-styled sans and serif render at a clean 2 screen px per font px. Edges are crisp, with no blur and no anti-aliased mush, which matches the direction "pixel look, not extreme".
- **x-height.** Measured on the 1080p frames, it is 16 px for all body, label and secondary text (setup header, tooltips, roster, victory subtitle, hero detail, encounter, draft) and 22 px for caps labels. That is above the claimed 14 px floor.
- **Contrast.** Every informative text I measured is at least 5.5:1, and muted text is about 6.4:1. Only disabled buttons ("Confirm" while a drag preview is showing; "Set out" after leaving) are 4.4:1. That is acceptable for disabled controls, but note it.
- **Chrome.** Panels, chips and buttons sit at the same 2x pixel scale as the text, so it does not look like two resolutions pasted together. The world is still crisp, nearest-filtered pixel art.
- **Rules that hold.**
  - Battle intro cards follow the rule: title, a row of chips with ▲/▼, and glyph labels of 20 characters or fewer.
  - The opponent's formation is hidden on setup.
  - Setup uses the 2x4 grid.
  - Setup Details renders in the shared tooltip box.
  - Battle and setup touch targets measured at 48 px or more (banner chips about 58x60, x1/SKIP 117x55, setup buttons about 180x50).

### Per screen

**Battle (PvP), including fight.mp4**
1. **RULE BREAK: numbers do not sit on their target's head.**
   - In the Cleave crit (`mid_fight_numbers_cleave_crit.png`, fight.mp4 about 6.5 to 7.3 s) I checked against the roster HP changes:
     - Moth 116 → 13, so 103 is Moth's.
     - Corin 187 → 165, so 22 is Corin's.
     - Tamsin 75 → 43, so 32 is Tamsin's.
   - "CRIT! 103" spawns directly on **Corin's** head (the unit in the row behind Moth), about 115 px above Moth's hood.
   - "32" sits beside **Moth's** head, not Tamsin's.
   - "22" floats about 150 px to the left of Corin with no unit under it.
   - The cause: the number anchor is about 100 to 130 px (about 35 to 40 world px) above the head. On the packed isometric grid that is exactly one row's offset, so every multi-target hit reads as landing on the unit behind the target.
   - Single-target hits (25, 26, 30) are also 100 px or more high, but there is nothing behind them to mislead.
   - Firestorm (`numbers_crit_firestorm.png`) has the same problem: "CRIT! 65" floats between Ilse and Brakka, and the left "32" is not over any head.
2. **Numbers run together.** In the Fading, two numbers on the same head render side by side with a gap narrower than one glyph: "14 11" (`fading_readout`, about 32 s), "18 14", and "5 4" (about 27.75 s). At phone size these read as "1411", "1814" and "54".
3. **VFX covers numbers.** The Cleave slash and impact stars draw over "CRIT! 103" (the "1" is hidden at about 6.8 s). Numbers must draw above effects.
4. **Intro card crossfade.** For about 0.25 s at the start (about 2.25 s) the intro card overlaps the ghost of the "Shardpoint" / "Keeper's Ring" corner banner, so title text is visible behind title text. This is minor and transitional.
5. **"Rear 1/2" tag.** It sits tight on top of its number with almost no gap. Readable, but it should breathe.
6. **Phone size.** All HUD text is readable. World-space cues such as "Shardpoint" and "Grief of the harvest" are small orange or white text with no backing over a busy floor. "Grief of the harvest" (crystal) is close to unreadable at phone size.

**Crystal, including crystal_demo.mp4**
1. **CLIPPING / TRUNCATION.** The action caption cuts long memory names with an ellipsis:
   - "Sable Stab ▸ The Miller's Last Ha…" (1080p, about 45 s)
   - "The Ferryman Wh… Strike ▸ Brakka"
   - "Brakka Strike ▸ The Lamplighter's…"
   - "Vael Bolt ▸ Crystal of Remembran…"

   It happens on most crystal actions. A truncated target name in the one line that says who hit whom is a fail.
2. **Stacked numbers.** In `fragment_banner`, "33 / 24 / 60" form a near-touching diagonal staircase over the Ferryman and the crystal, and it is unclear which belongs to whom.
3. **Lore strip.** The italic-feel lore line ("He waited at the crossing…") is 16 px x-height and high contrast, so it passes. It is the longest line in the HUD, though, and at phone size it is the hardest text to read on this screen.
4. **Right roster.** With 5 entries the panel grows upward to about y = 815 at 1080p and nearly touches the crystal's HP pips.

**Monsters**
- Numbers sit on targets correctly here: 77 on the Hollow Rat's crest, KO! on its body, and 24 above Brakka.
- "21" floats left of the Stone Sentinel's head and is borderline.
- No text faults at phone size.

**Setup**
1. **Overlap.** In `no_shapes_unlocked_locked_row_tooltip`, the "Keeper's Ring (locked)" tooltip's bottom edge cuts through the **"Brannoc" name plate**, which reads "Branno…" with its lower half covered. This is in both 1080 and phone.
2. **Details popup.** In `unformed_details`, the Details box covers Sable's sprite and name plate on the board while the right panel's lower half sits empty. The box would fit in the panel and leave the board readable.
3. **Tooltip wrapping.** The locked tooltip paragraph wraps "charge / +40%" and "Ilse / can't" across lines. It is a dense 6-line block in body size with no line spacing, readable at phone size but only just.
4. **Dead space.** In every state, the lower half of the item panel is dead space (pair 5).
5. **Repeated text.** "Crescent locked" appears three times on one screen: subline, list row and board footer.
6. **Sprite crowding** on the board hides name plates (for example Ilse's staff over "Brannoc" in `drag_preview_locked_crescent`). This is a known, separate issue.

**Draft**
- No clipping. Text is readable at phone size.
- Hierarchy is flat: about 12 items per card, nearly all at the same 16 px size. The serif names are the only real step up.
- The unpicked card is dimmed to 5.5:1. It passes, but it makes the whole card look disabled rather than "not picked".

**Encounter**
1. **Wide-aspect fault.** On 2340x1080 the illustration ends in a hard vertical edge at x ≈ 210, leaving a near-black strip down the left side with the rock and floor shapes cut off. That is effectively a black bar, which the aspect spec forbids.
2. **Choice rows.** They are dense:
   - per row: name, answer, memory delta and "Ready to Awaken" badge on two lines
   - a five-colour alignment line ("Cruelty +1 Freedom +1 ★ Strong shift")
   - 5x5 mini-grids at the row ends, about 70 px, that cannot be read at phone size.
3. **Capture defect.** `hound_choices` and `hound_resolved` are pixel-identical to the colossus captures (I diffed them and the bbox is None). The hollow hound encounter was never captured, so it was not reviewed.

**Hero detail**
1. **Possible rule break, for the lead to rule on.** The Ability block shows a two-line effect sentence with numbers ("Heals the weakest ally (220%), then melee enemy for 90% magic.", "Hits the foe in front for 170% physical, then heals…"). The non-negotiable says the tooltip is the only place long effect text appears, and only setup Details is exempt.
2. **Small icons.**
   - The "Taken" path arrows and memory pips are about 33x33 px at 1080p.
   - The draft card class glyphs are about 40 px.

   If they carry tooltips, their hit areas must be at least 48x48. Check this, because the visible boxes are below it.
3. **Flat hierarchy.** About 8 tiers of text at one size (pair 3).
   - The vertical "ORDER" and "FREEDOM" labels are hard to read at phone size.
   - The grid cell label "Cleric" sits next to the class line "Healer", which confuses.
   - "Lv 4 → 1" in Advance reads like a loss.

### Before / after
- At **full size** the difference is clear. The old screens were chunky, bold 3x pixel type; the new ones have finer, crisper glyphs, and the serif titles are much better.
- At **phone size** it is **not obvious, and in places it is worse**:
  - The old bold all-caps "SHARDPOINT" banner and the old bold roster names are punchier and easier to read than the new regular-weight "Shardpoint" and roster names.
  - The setup rows look thinner after the change than before.
  - The encounter text is the only region that is clearly better at phone size.

  The migration traded weight for refinement. Against the Super Auto Pets "punchy, big type" bar, the phone-size result is calmer but weaker.

## Verdict

| Pair | Winner at full size | Winner at phone size | OVERALL | Confidence |
|---|---|---|---|---|
| 1 | B | B | B | medium |
| 2 | A | A | A | medium |
| 3 | A | A | A | medium-high |
| 4 | B | B | B | medium |
| 5 | A | A | A | medium |

**OPEN REVIEW: FAIL**
- **Rule regression:** battle damage numbers do not sit on their target's head. Multi-target hits land on the unit behind (Cleave: Moth's 103 on Corin, Tamsin's 32 on Moth).
- **Truncation:** the crystal action caption ellipsizes target and actor names ("The Miller's Last Ha…").
- **Overlap:** the setup locked-row tooltip cuts the "Brannoc" name plate. Fading numbers run together ("14 11" reads as one number).
- **Wide aspect:** the encounter illustration leaves a black strip at the left on 2340x1080.

**THE BIGGEST REMAINING GAP:** damage numbers float about one grid row (about 110 px at 1080p) above their target, so in any multi-target hit the player reads each number on the wrong unit.

### Fix list (most important first)
1. **Battle and crystal, damage numbers.** Anchor each number just above its target's head:
   - at most about 12 world px (about 36 px at 1080p) above the head's top
   - spawn there and rise at most about 20 px
   - for multi-target actions, keep each number in its target's horizontal span instead of spreading them apart.

   **Fixed** means that in the Cleave frame 103 sits on Moth, 32 on Tamsin and 22 on Corin, checked against the roster HP changes.
2. **Battle Fading, adjacent numbers.** When two numbers share a head, stack them vertically with a gap of at least 0.5 line, or merge them. **Fixed** means "14 11" never reads as "1411" at 960 px wide.
3. **Battle, draw order.** Draw damage numbers and tags above all slash and impact VFX. **Fixed** means "CRIT! 103" is fully visible in every frame of the Cleave.
4. **Crystal caption.** Show long names in full. Options:
   - let the caption panel grow, since the space between the rosters allows it
   - drop to two lines (actor and ability / ▸ target)
   - use a short name ("The Miller").

   **Fixed** means no "…" anywhere in the caption across the whole crystal_demo.mp4.
5. **Setup, locked-row tooltip.** Place the tooltip so it never covers a name plate: clamp it above or below the plate row, or put it beside the panel row inside the panel.
   - Also place Details inside the right panel's empty lower half instead of over the board.
   - **Fixed** means no name plate is covered in `no_shapes_unlocked_locked_row_tooltip` or `unformed_details`.
6. **Encounter, wide aspect.** Extend the illustration's backdrop (wall and floor) to the left edge on 19.5:9, or centre the art with matching extended background. **Fixed** means no hard cut or near-black strip at x < 210 in `encounter/phone/*`.
7. **Phone-size punch.** Raise the weight or size of the top tier so the phone frame reads as punchy as the old one:
   - battle corner banner title
   - roster names and HP
   - action caption
   - setup effect rows

   For example, bold the sans at the same size, or move it up one size step. **Fixed** means the phone row of `before_after/battle_banner.png` and `battle_roster.png` reads at least as strong after as before.
8. **Hierarchy on dense screens** (draft cards, hero detail left panel, encounter rows). Add a real size step between name/title, primary value and secondary text, and cut repeated text:
   - "Crescent locked" ×3
   - the dense "Ready to Awaken" badge on every row (show it once)
   - hero detail side labels: make ORDER and FREEDOM horizontal, or larger.
9. **Hero detail ability text.** Get a lead ruling on whether two-line ability effect sentences must move into the tooltip under the effects-as-icons rule. If yes, show the ability name + glyph + label of 20 characters or fewer and put the sentence in the shared tooltip.
10. **Touch targets.** Confirm that the hit areas of the hero detail "Taken" arrows, memory pips and draft class glyphs are at least 48x48 px (they are 33 to 40 px visible). Pad the hit areas if not.
11. **World-space cues.** Give "Shardpoint" / "Grief of the harvest" type labels a dark backing plate or outline so they read at phone size over the floor.
12. **Capture harness.** Re-capture the hollow hound encounter: the `ENCOUNTER_DEMO=hollow_hound` captures are duplicates of the colossus captures.
