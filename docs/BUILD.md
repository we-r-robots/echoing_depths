# Echoing Depths — Build Guide (for builder and critic agents)

The design spec is the five files in the repo root (`00-overview.md` … `04-meta-progression.md`).
Their **Rejected Ideas** list is a hard constraint. Numbers in the spec are placeholders; pick sensible ones and keep them in data, not code.

## Engine and layout
- Godot 4.7, GDScript, GL Compatibility renderer (runs on PC, Android, iOS). Project lives in `game/`.
- Internal resolution **640×360**, integer-scaled (1920×1080 = 3×). All art is authored at 1× pixel size. No sub-pixel motion, no filtering, no rotation/scale of pixel art except by whole numbers.
- `game/core/` — pure game logic (no nodes, no rendering). Deterministic given a seed. This is what async PvP Echoes and tests depend on.
- `game/scenes/<area>/` — one folder per screen. `game/assets/<kind>/` — art, fonts, audio.
- `game/tests/` — headless tests: `godot --path game --headless -s res://tests/run_all.gd`.
- Touch-first UI: every interaction must work with a single tap/click; minimum hit target 16×16 px at 1×. No hover-only information.

## Art direction
- Tone: mythic and wondrous, melancholic undercurrent. Pixel-era JRPG lineage, presented at a modern standard (Sea of Stars is the bar: dynamic lighting feel, rich dithering-free shading, lively idle animation, strong silhouettes, juicy hit effects).
- **Master palette:** `game/assets/palette/master.gpl` (and `master.png`). Use only these colours unless a piece's critic agrees an addition is needed; add it to the palette file when you do.
  - Indigo is the shadow colour of the world (never pure black). Lantern amber = warmth, hope, Lanternrest. Crystal cyan = Lumari, memory, Shards. Fading gray = erasure, desaturated things the Fading has touched. Violet = magic.
- Art is original and authored in this repo (hand-placed pixels via scripts, or drawn and saved as PNG). Any third-party asset must be CC0 and recorded in `game/assets/CREDITS.md`. Never copy or trace reference-game assets.

## Spec non-negotiables (every builder follows these; every critic checks them and FAILS a piece that breaks one)
Super Auto Pets is a bar for readability and punch only. Never copy its structure (single lanes, shop, tiers bought by duplicates).
- **Battle layout is the FF1-style side view from 03-runs-and-combat.md:** each side has a 2-column (front/back) x 4-row grid, 8 slots per side, with up to 4 heroes occupying any 4 of them. Parties face each other across the screen. Never a single lane or queue.
- **Formations matter and are visible:** the shape of the occupied slots is a named formation (game/core/data/formations.gd) with at least one buff and one debuff. The player arranges heroes in the grid before a fight, and the battle shows which formation is active and when its effects apply.
- **Targeting:** melee hits the front column (back once front is empty), same or nearest row; ranged/magic per ability; back column deals and takes half physical damage.
- **Combat:** ATB gauges by Spd, charge meter filling to an ability, no player input during the fight.
- **Sudden death is time-based only** (user decision 2026-10-04): it starts only when a fight runs past a set time, never because a side is down to its last unit. Most fights should end before it. In the fiction it is the Fading: the memory of the battle is fading, so the arena drains toward Fading grey and the damage escalates as it erodes. Present it that way (no generic "SUDDEN DEATH" label).
- **Heroes level by memories from encounter choices,** never by buying duplicates. Alignment is a 5x5 grid; only the Relic slot carries alignment.
- Party of 2 to start, max 4. Each base class has one fixed starting alignment.
- **Effects are shown as icons, not paragraphs** (user decision 2026-10-05): each stat effect is a small stat icon (Def shield, Atk sword, Mag star, Spd boot, heal, charge, crit) with a green ▲ for a buff or a red ▼ for a cost; each behaviour has its own small glyph. The full text appears in a tooltip on hover (PC) or tap / press-and-hold (touch). The tooltip is the only place long effect text appears, and touch must always reach it (no hover-only info). Use one shared icon set and tooltip component for every screen.
- Any scene showing heroes in combat or ready for combat uses the formation grid. A sprite showcase is a labelled gallery (one framed cell per character), never two parties facing each other or a single line-up.

## Capture and judging tools
- `tools/capture.sh <res://scene.tscn> <out_dir> <frames> [seed]` — unattended screenshots at given frame numbers (60 frames = 1 s).
- `tools/video.sh <res://scene.tscn> <out.mp4> <frames> [seed]` — record motion.
- `tools/blind_pair.py <ours.png> <ref.png> <out.png> <piece>` — blind A/B image. Critics must never read `captures/.keys/`.
- Reference material (for comparison only): `references/sea_of_stars/` (frames/ = boss battle, frames_footage2/ = town, dialogue, menus), `references/super_auto_pets/` (shop and battle), `references/slay_the_spire/` (frames/ = StS2 combat and map, frames_events/ = StS1 event screens; ignore the facecam bottom-right) — `contact*.png` sheets, `footage*.mp4`.
- Put capture output under `captures/<piece>/` (gitignored).

## Working rules for parallel builders
- Only edit files in the area you own (named in your task). If you need a change to shared files (`project.godot`, `game/core/` when not yours), make the minimal change and report it.
- A scene you build must be capturable standalone: `tools/capture.sh res://scenes/<area>/<scene>.tscn ...` must show a realistic, populated state with no input (use demo data in a `demo` mode).
- Run the Godot project headless once after adding assets (`godot --path game --headless --import`) and fix every error and warning you introduce.
