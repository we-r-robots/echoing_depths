# Task: High-Resolution UI Text Layer
*Approved by the user, 2026-10-05. Read docs/BUILD.md (especially "Spec non-negotiables") and docs/RESUME.md first.*

**Status (2026-10-05):** milestones 1–4 are built and pushed. Critic rounds 1 and 2 FAILED (2 of 5 blind pairs each; records in docs/tasks/hires-ui-round1.md and hires-ui-round2.md). Round-3 fixes are built; captures in captures/hires-ui/r3/, awaiting critic round 3 (build record at the end of docs/tasks/hires-ui-round2.md).

## Decision
The **world** (battle stage, sprites, encounter illustrations, effects) stays pixel art authored at **640x360**, integer-scaled to the screen. **All UI text and UI chrome** (menus, cards, tooltips, captions, banners, damage numbers and tags, HUD, roster panels) moves to a **higher-resolution UI layer**, so text has more pixels per glyph and reads clearly on a phone.

**Font direction (the user's words):** mimic a pixel font, but readability is important, so don't take the pixel look to an extreme. That means a pixel-STYLED font with clean, regular glyphs drawn at roughly twice the detail of today's 11 px bitmap fonts. It should sit comfortably next to the pixel art, without blurry anti-aliasing and without chunky, hard-to-read glyphs. Original, or licensed CC0/OFL, recorded in game/assets/CREDITS.md. Keep the game's two voices: a sans for body and labels, and a serif for titles and names (see game/assets/fonts/ and the theme in game/ui/).

## Rationale (from critic history)
Most repeated critic failures are text problems caused by 5–7 px glyphs at 640x360:
- **Phone legibility:** flagged on the setup screens, the alignment screen and the encounter screen.
- **Labels over the ≤20 character rule:** they fall back to a smaller font because the large face doesn't fit.
- **Dense panels:** they can't get Sea of Stars' calm, because text is physically large.
- **Battle number/tag collisions** ("1719", "Hlighthoused", "shared" running into numbers), a cramped banner icon row, caption overflow, and the Fading line overlapping banners.

Finer text takes less screen space at the same readability, which attacks all of these.

**What this will NOT fix:** sprite crowding on the formation board, the white-out and darkness on ability moments (a separate queued fix), and sprite art quality. Don't claim those.

## Spec
1. **Rendering setup (Godot 4.7, GL Compatibility):** the world must stay pixel-perfect, integer-scaled and nearest-filtered. UI text renders at a higher resolution (target: a UI design space of 1280x720, or native resolution, with text crisp at 2x, 3x and 6x window scales). A recommended approach: render the world in a 640x360 SubViewport shown with integer scaling and nearest filtering, and set the root window's stretch mode to `canvas_items`, so Controls and fonts rasterise at native resolution. Choose whatever works best, but explain it in docs/BUILD.md.
2. **Aspect:** use stretch aspect `expand`, so wider phones (about 19.5:9) show more arena instead of black bars. The world stage fills the extra width sensibly (more floor and wall, nothing important off the 16:9 safe area), and UI anchors adapt.
3. **Fonts:** a sans and a serif with the same character set as today plus `+`, `%`, arrows (▲▼▸), `·`, `×` and `…`. Set sizes in the shared theme (game/ui/theme.tres), with named sizes for body, label, title and number. **Minimum: no player-facing text below an x-height that reads clearly on a 6-inch 1080p phone.** Define that as a concrete pixel number at 1080p in docs/BUILD.md and enforce it.
4. **Migrate every screen** to the UI layer and the new theme fonts:
   - battle HUD, banner icons and chips, captions, the ability banner, damage numbers and tags, the Fading line, the roster panels, the victory/defeat cards and the intro cards;
   - the formation setup and draft screens;
   - the encounter screen;
   - the hero detail / alignment screen (game/scenes/party/);
   - the shared tooltip, EffectChip and BigText (BigText's hand-drawn + and % glyphs may become unnecessary).

   World-space numbers must still track their unit's head exactly. Convert positions through the world viewport's transform.
5. **Capture harness:** tools/capture.sh / game/autoload/capture.gd currently save the 640x360 viewport image. Change them to save the full window at the capture resolution (1920x1080), so critics see the real UI detail. Also add a phone-shaped capture option (e.g. 2340x1080), and keep `tools/blind_pair.py` and `tools/smoke.sh` working, updating the smoke test's size check.
6. **Don't change game logic, data, balance or art assets.** Keep every existing verified rule:
   - numbers on targets and cleared per action;
   - no edge clipping;
   - icons with tooltips (hover on PC, tap or press-and-hold on touch);
   - the opponent's formation hidden;
   - and the rest of "Spec non-negotiables".

## Expectations and acceptance
- **Tests and smoke test:** all tests pass (`godot --path game --headless -s res://tests/run_all.gd`), and `tools/smoke.sh` passes.
- **Captures:** re-captured at 1920x1080 and at a phone aspect, into captures/hires-ui/:
  - each screen's main states;
  - battle stills, plus fight.mp4 and the Crystal demo;
  - the setup screen states (active, Strays, Unformed, locked fallback, tooltip open);
  - the draft;
  - the encounter;
  - the hero detail screen.
- **Readability check:** text at the defined minimum size is readable when a 1080p frame is shown at phone size, with no overlaps or clipping. Before/after crops of the same UI moments make the difference obvious.
- **Gauntlet loop:**
  - **Builder:** a builder agent does the migration.
  - **Critic:** a separate harsh critic with fresh context judges it blind against Sea of Stars' menus (references/sea_of_stars/frames_footage2/, via `tools/fetch_references.sh`) and Super Auto Pets' shop frames 015/016, using `tools/blind_pair.py`. The critic must not read captures/.keys/.
  - **Pass condition:** ours wins most pairs, including at least one Sea of Stars pair, readability holds on phone-sized frames, and no rule regresses. Loop builder and critic until the critic picks ours.
- **Commits and push:** commit at each milestone (tests green) with the repo's usual co-author trailer, and push to `gauntlet-build` on GitHub. Append a short status line to docs/RESUME.md and to progress/state.json's log (`python3 progress/log.py "<msg>"`).
