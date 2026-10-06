# Lanternrest: critic round 2 (2026-10-06): FAIL 0/4 (top-down town)

Judged: captures/lanternrest/r2/ (merge ff22aa1). Pairs vs Emberville 647462/647457/647453/647464. Decoded: ours = A, A, A, B. The critic picked the reference in all 4; ours won only pair 2 at phone size (anchored Vault panel legible vs Emberville's tiny tooltip). **Blind leak:** the Emberville press shots carry the game logo and a worthplaying watermark; future pairs use references/emberville/clean/ (cropped, logo-free).

UI layer close to shippable (anchoring, dim, contrast, text floors pass). Environment fails.

Biggest gap: flat blobs and stepped light rings instead of dense, unified-scale authored pixel art; the Vault doesn't read as a vault and the Lantern reads as a tower window; the mist is an opaque grey sheet with greyscale house copies, not a visibly half-erased town.

## Fix list
Environment:
1. Lantern: a squat iconic monument in the plaza centre (~1.3× house height), plinth, glass cage, visible flame, warm bloom on cobbles; north road reads as a road; banner merged into it.
2. Vault: carved stone portal or cellar door in a rock outcrop, Lumari crystal inlays, cyan light rising from the stairwell, worn steps, trodden path, marker stone; no wireframe arc, no cyan puddle; selection outline follows the portal.
3. Lighting: no stepped radial rings (4–6 tones with a 30-level jump); smooth falloff that tints, and light catching edges (fence tops, roof rims, cobble highlights).
4. Mist: translucent drifting haze (40–60%), soft edges, no rectangular tiles, no speckle dither; ghost buildings visibly erased (missing chunks, fading outlines, streets breaking apart into the mist); fog darker than the lit village so the plaza stays brightest; the south edge's half-erased treatment on all four borders.
5. Sparse start: at the start only the central lantern (plus 2–3 lamps at most) is lit; nearby houses dark, boarded or greyed; light and detail return as the town is rebuilt.
6. Ground and roads: tile-scale grass variation, flowers, stones, wear, clutter at building edges; roads with kerbs, edge shadow, centre wear; authored detail every ~200 px.
7. One pixel scale: flagstones ≤2–3× brick size; trees at least eave height.
8. Plots: a readable post-and-board sign, varied rubble/foundation layouts, a faint ground marker.
UI:
9. Touch: every tappable place (plots, mist) has an always-visible small label, pin or sign sprite (no hover on phones).
10. A visible pressed state (depress/flash/outline + light pulse).
11. World labels overlapped by a panel are hidden or under the dim (no "Th", "Training Gr" clipped at panel edges).
12. Scroll arrows fixed at screen-edge centres; the hint toast never overlaps an arrow or the plaza.
13. Mist selection: district-shaped region with the standard outline weight, or an "Unexplored" signpost at the fog edge.
14. Training Grounds panel: rewrap the intro (orphan "know."), one alignment for status lines, formation glyphs ≥3×3 cells at 6+ px.
15. Gear menu: dim, active state, close affordance.
Deferred (characters): residents and street life.

## Round-3 build (2026-10-06, branch lanternrest-r3)

Compared directly against Emberville 647453/647456/647457/647458/647462/647464 (fog over ruins, rebuilt street, night lamps).

**How the town is drawn now** (`assets/lanternrest/src/make_town.py`, `scenes/lanternrest/town_layers.gd`):
- **Albedo in the master palette** (`town_<stage>.png`): hand-placed pixels via code with form shading only (the moon high in the north-west); no lamp light is baked in.
- **Light is a separate smooth layer** (`light_<stage>.png`), multiplied over the world on screen (CanvasItem `BLEND_MODE_MUL`). It tints the authored colours instead of repainting them.
  - Indigo night everywhere, with warm and cold pools that blend toward their light's colour by distance and facing.
  - Catch-light on edges facing a lamp: kerb tops, brick and sett lips, fence and rail tops, roof rims and ridges, rock rims.
  - Glass and crystals are emissive (shown at full).
  - 8-bit gradients: no bands and no dither.
- **Bloom and flicker are additive.** Smooth one-hue glows: the Lantern's cage and its breathing ground pool, a pool and head bloom per lit lamp, lit windows, and the Vault's rising shaft. A faint ink lift is added so lit black never reaches (0,0,0).
- **The flame, the Vault's rising motes and the place outlines draw above the light.**
- **The palette rule:** authored art stays in the master palette. Off-palette colours come only from the light blend on screen, which is what the brief asked for.

**Fix items:**
1. **Lantern:** now a squat monument at the plaza's heart, about 1.3x house height. It has a round sett dais with four bollards, a two-step octagonal plinth, a stone pedestal and a great iron lantern (lit glass cage with an animated flame, pyramid cap, ring finial). The company banner and crest hang on the pedestal's front, merged into it. Sett rings run round it. The north street is kerbed with a sidewalk, so it reads as a road.
2. **Vault:** a carved portal in a rock outcrop. Angular boulders with lit tops, dark fronts, ink crevices and moss. A lintel with a row of Lumari crystal inlays and a crystal keystone, and carved rune jambs with crystal studs. Worn steps go down into the dark, lit cyan from below and brightest at the far end; a soft cyan shaft and motes rise out of it. There is a flagged apron, two crystal braziers, a standing marker stone with a crystal, and a trodden lane to the high street. The selection outline follows the portal's silhouette.
3. **Lighting:** the stepped rings are gone; see the smooth light layer above.
4. **Mist:**
   - The body is a translucent cold grey at half resolution, drawn x2 filtered: smooth alpha up to about 0.6 and darker than the lit plaza. It has no tiles and no dither.
   - Wisps drift over it.
   - Under the mist the town is erased, the same way on all four borders:
     - colour drains (ground first);
     - dark outlines fade to grey;
     - whole blocky chunks are missing (flat grey nothing with a pale frayed edge);
     - streets and sidewalks break apart into grit and loose setts.
5. **Sparse start** (two stages, see the signals below):
   - **Fresh:** only the Lantern and 3 street lamps burn. The two cottages by the plaza are dark and boarded (planks over the windows and door, a cobweb, rubble). Benches are broken, weeds grow through the plaza's joints, and the mist sits close.
   - **Built:** 5 more lamps are relit. The cottages reopen with lit windows, shutters, window boxes, a tavern sign, barrels, crates, firewood and chimney smoke. Planters and bunting appear on the plaza, and the mist is pushed back about 10%.
6. **Ground:**
   - Grass has broad and mid-scale clumps (no square tiles).
   - Every 16 px tile carries authored stamps: tufts, blades, clover, white, red and violet flowers, pebbles, leaves, mushrooms, twigs and dirt.
   - Streets are carriageways of small setts with kerbs (a lit top and a dark face), the kerb's shadow, gutters, centre wear and brick sidewalks.
   - Worn earth verges line the streets; joints carry weeds and moss.
   - Building feet carry clutter: barrels, crates, sacks, firewood and buckets, or rubble and planks at empty houses.
7. **One scale:** street setts are 6x3, sidewalk bricks 9x4, plaza setts about 9x6 and the plaza kerb stones are long. Trees are bigger (radius 12-20), at least eave height.
8. **Plots:** each has a post-and-board sign with a hammer painted on it. There are four foundation layouts (footings, a cellar hole with planks, a scorched floor with a fallen beam, a timber pile with stacked stones). Corner pegs with a pale string mark the lot faintly; rubble and a broken fence complete it.
9. **Touch:** every place shows a marker without hover.
   - The Lantern, the Vault and the Training Grounds keep their signs.
   - The mist's four places have always-on "Unexplored" signboards (plus a wooden signpost in the art at each street end).
   - Each empty plot has a small hammer pin; its name sign shows on hover, press or open.
   - Tested: `test_every_place_has_a_touch_marker`.
10. **Pressed state:** a press shows a 3 px brighter outline (amber7/amber5) pushed down 1 px, the place's light pulses to 1.7x (hover is a 2 px outline at 1.35x), and its sign turns to a bright fill with an amber7 edge, pushed down 1 px. Tested: `test_pressed_looks_different_from_hover`.
11. **Labels under panels:** signs and pins that a panel (or the gear menu) would cover are hidden, never clipped. Tested: `test_panels_hide_the_labels_they_overlap`.
12. **Scroll arrows:** fixed at the edge centres. A tap on one pages before any place under it. Signs and pins are nudged off the arrow spots. The hint sits on the bottom edge beside the down arrow, on whichever side keeps it off the plaza and the Lantern. Tested: `test_edge_cues_sit_fixed_at_the_edge_centres`, `test_hint_keeps_off_the_cues_and_the_plaza`; the probe checks no arrow covers a sign or pin.
13. **Mist selection:** a district-shaped region, squared to the street grid, with the standard outline (the same 2 px hover and 3 px press outlines as every place), plus the "Unexplored" signboard.
14. **Training Grounds panel:**
    - The intro is one line that fits ("Learn shapes with Shards. Each grows from one you know."), so no word is orphaned.
    - Every status line starts at the name's left edge with its icon: check, Shard crystal (new for prices) or lock.
    - Shape glyphs draw on the whole 2x4 board in 6 px cells (were up to 4 rows at 4 px).
    - The panel is 302 px wide.
15. **Gear menu:** the same 0.5 dim as the panels (a tap on it closes the menu). The gear shows pressed while the menu is open, and the menu has a Close button. Tested: `test_gear_menu_dims_shows_active_and_closes`.

Deferred (characters): residents and street life.

**Which progress signal drives what** (`Village.stage(meta)`, `Village.entry_on()`; lights and chimneys in layout.json carry `stage` and optional `place`):

| Signal | What lights up |
|---|---|
| Fresh save (no signal) | `town_fresh` / `light_fresh` / `mist_body_fresh`. The Lantern, the Vault's cold light, and street lamps (1062,384), (852,442) and (700,384). Nothing else burns. |
| `meta.runs >= 1` (first run home), or the Training Grounds built → stage `built` | `town_built` / `light_built` / `mist_body_built`. Lamps (852,384), (1060,442), (1236,384), (920,300) and (1000,520) relit; the two cottages reopened (3 lit windows, 2 smoking chimneys, window boxes, a tavern sign, barrels); plaza planters, bunting and mended benches; the mist pulled back. |
| Training Grounds built (`Village.is_built("grounds")`, today the same rule: runs >= 1) | The yard replaces plot_e1: its sprite, the yard lamp's glow and pool, its chimney smoke and its banner. Its light is baked into `light_built`. If a future rule built the yard without the built stage, a third light map would be needed; today the two signals coincide. |

**Tests:** tests/test_lanternrest.gd now has 19 tests, including the new ones named above and `test_town_lights_up_with_progress` and `test_training_grounds_intro_and_tiles_read`. The probe checks that no arrow covers a sign or pin. Full suite: 262 tests, 0 failed, 0 engine errors.

**Captures:** `tools/capture_lanternrest.sh` → `captures/lanternrest/r3/<state>/{1080,phone}/f00090.png` (same state names as r2).

**Frame time** (the round-2 script: 1920x1080, GL Compatibility, panning the camera every frame, 600 frames, on a shared machine at load average 10–13):
- **Desktop GPU:** median 0.71–0.91 ms (title screen 0.38 ms).
- **Software GL on the virtual display** (tools/godot_run.sh, as the captures run): median 15.9 ms against 10.3 ms for the title screen on the same run. That is about +5.6 ms for the four full-screen blend layers (albedo, MUL light, filtered mist body and wisps). Round 2 was +2 ms.
- **Cost:** scripts cost well under 1 ms. No shaders.
- **Room left:** on a real GPU the town is about 1 ms. If a low-end phone needs room, the mist wisp layer is the first to drop.
