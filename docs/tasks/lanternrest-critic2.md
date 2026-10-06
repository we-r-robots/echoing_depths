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
