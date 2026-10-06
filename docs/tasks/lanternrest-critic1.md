# Lanternrest: critic round 1 (2026-10-06): FAIL 0/3

Judged: captures/lanternrest/r1/ (gauntlet-build 66b404c era). Pairs vs Sea of Stars night-town frames (frames_footage2 005/013/009). Decoded: ours = B, B, A; the critic picked the reference in all three (high confidence). Ours wins only on label readability at phone size.

Biggest gap: a flat, evenly lit strip of props under an empty sky, with painted-on dithered "light" and static-noise "mist"; no light, depth or surface detail, so it reads as a labelled menu backdrop.

Full report: the critic's hand-back is reproduced in captures/lanternrest/critic1/report.md (gitignored) and summarised in the fix list below.

## Fix list (environment and UI, no character art needed)
1. Lantern light: smooth glow, brightest at the lamp; lit cobbles instead of a flat orange ellipse; warm edge light on facing surfaces; no checker dither (BUILD.md: dithering-free shading).
2. Mist: soft drifting layered grey, feathered edge, town desaturates toward it, faint silhouettes; stays below the sky.
3. Mist wisps visible in the opening view (the town is "half-erased").
4. Camera start: at 16:9 the Vault, the lantern and the first building fit the safe area; scroll arrows never on a tappable place.
5. Fill the sky and add depth: far ridge/rooftops, mid village layer, dark foreground strip; parallax on drag; empty sky ≤25%.
6. Ground and walkway: cobbles, dirt and grass instead of camouflage noise; worn stone walkway.
7. Remove the pure-black mass left of the Vault (indigo shadows only).
8. Plots: foundation stones, stake-and-string, a weathered board with a symbol; panel says what it can become and how.
9. Mist panel: says what thins the mist; points at the mist.
10. Tappable places: hover brightens and pulses the place's light; the outline hugs the building/door; small idle animations (lamp flicker, door glow, chimney smoke, banner sway).
11. Labels: hanging signboards in the game's frame style with a pointer stem (optionally fade when still).
12. Panels: all dim the world the same way and point at their place without covering it (plot panel vs Vault; identity picker vs lantern).
13. Training Grounds: learned shapes with a check, locked shapes dimmed with unlock condition; one lock style.
14. Lantern panel: "87 / 100 Glimmers" on the bar; why "Form a Shard" is disabled; prices/conditions on locked crests; consider splitting identity from Glimmers.
15. HUD currencies stay at full contrast while a panel is open (2.9:1 now).
16. The hint text disappears after the first drag and tap (or the first run).
17. Replace the prominent "Title" HUD button with a smaller menu/gear (Settings, Return to title).

Character-dependent (later): townsfolk at each place, the party waiting at the Vault on a saved run, Hall of Remembrance and monument plaza.

## Round-2 build: top-down town (2026-10-06, branch lanternrest-topdown)

The user's decision (docs/BUILD.md "Lanternrest view: top-down 3/4") replaces the side-on strip. Lanternrest is now a top-down 3/4 town at night on a 16 px grid, 1920 x 720 world px (three 16:9 screens wide, two high), panned in two dimensions and tapped. References compared directly: Emberville 647453/647456/647457 (fogged ruins, place panel), 647458/647462 (street, plaza), 647460/647464 (lamp pools), 647459/647463 (fenced plots), and Sea of Stars frames_footage2 005, 009-013 (night town).

**Art** (`game/assets/lanternrest/src/make_town.py`, master palette, no `light_pass` / `tint_pass` / `glow_layer`):
- The town is painted with per-pixel surface data (ground, south wall, roof slopes, posts, emissive), then lit in whole palette steps: a night baseline per surface (the moon high in the north-west), lamp light by distance and facing, warm hue in two hard bands (muted brown, then amber at the lantern's heart), the Vault's cold light, rim light on edges facing a lamp. No checker seams; the darkest colour is ink1 (indigo), never black.
- Places: the Lantern (stepped plinth, iron column, a large caged lamp with an animated flame, the company's banner and crest on its arm, a ring of slabs on a flagstone plaza); the Vault entrance (a grassy barrow, a carved arch with a crystal keystone, stairs down between low walls, cyan light from below, crystal braziers); the Training Grounds (fenced sand yard, thatched barracks with a lit window and smoking chimney, three straw dummies, a target, a weapon rack, a banner, a lamp; after the first run, NEW tag); five empty plots (fenced lots with gaps, foundation stones, stakes and string, a weathered board); four mist places where the streets vanish.
- Depth and life: houses with front walls, roofs (both ridge directions), chimneys and shadows; street lamps with pools (lit near the lantern, dark and broken toward the mist); trees, bushes, flowers, crates, barrels, a well, benches, fences. Idle: lantern flicker, Vault pulse, lamp waver, chimney smoke, banner sway, swaying grass, drifting mist wisps. Places glow brighter while hovered (x1.35) and pressed (x1.6).
- Mist: the town greys toward the edges (desaturated to neutral greys, lifted a step deeper in); over it a mist body in nine small alpha steps of one grey (banded, not dithered) and half-resolution wisps that drift. Rows of ruined houses and a broken back street show through as silhouettes. The north mist is in the opening view (the town is half-erased).

**Screen** (`scenes/lanternrest/`): `lanternrest.gd` (camera, input, panels, signs, cues, hint, gear), `village.gd` (places data and unlock rules), `village_place.gd` (a place: art, moving parts, highlight), `town_layers.gd` (lights, smoke and grass, mist).
- Navigation: drag / swipe with fling, mouse wheel (shift for sideways), arrow keys, the PC screen edges, tappable edge cues (slid along the edge off places, signs and the hint). Camera clamped to the town, on whole pixels. It opens centred on the plaza with the Vault and the lantern (and their signs) in view at 640 and 780 px wide; after a build it shifts just enough to show the new place.
- Panels anchored to places: the camera slides the place about a quarter of the way in, the panel opens on the other half with a pointer to the place; one shared 0.5 dim below the top bar; z order dim, lifted place (with its sign), panel. `finish_camera()` ends the slide for tests. The first-visit identity picker points at the lantern.
- Signboards in the frame style with a stem, bold size 10 (x-height 16 px at 1080p), main places always, others on hover.
- Hint: shortens after a pan or a visit, gone once both are done or a run is finished (`meta.village_hint_done`).
- Gear button instead of Title: Settings, Return to title.
- Training Grounds tiles: learned (check, "Learned"), learnable (Shard price), locked (dimmed, lock, the shape it grows from). Lantern panel: Glimmers first, "87 / 100 Glimmers" on the bar, the reason when Form a Shard is off, prices under locked crests.

**Tests**: tests/test_lanternrest.gd (13) and tests/probe_lanternrest.gd (signs, cues, every panel at 1080p and 19.5:9). Full suite: 245 tests, 0 failed, 0 engine errors.

**Frame time** (1920x1080, GL Compatibility, panning, a shared machine at load ~18): median 12.3-13.2 ms vs 10.2 ms for the title screen on the same run, so the town adds about 2 ms; scripts cost under 0.1 ms per frame. No shaders.

**Captures**: tools/capture_lanternrest.sh -> captures/lanternrest/r2/<state>/{1080,phone}/f00090.png.

**Wording questions for the user** (current text kept): see the builder's report.
