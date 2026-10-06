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
