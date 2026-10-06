# BUILT on branch formation-parts (2026-10-06): every formation part counts

User decision 2026-10-06 (05-formations.md, BUILD.md): a partly connected side fights with every connected part that forms a shape. Playtest case: Vael F1 + Ash F2 (Kindred) and Brakka B3 + Corin B4 (Vigil) got "No formation"; now both pairs count.

Work:
- core/formation.gd `effective()`: return a list of parts, each {shape, effective, sub_cells, locked}; state "parts" when more than one counts. Per part: an unlocked shape counts; a locked shape falls back to its largest unlocked sub-shape; a part with no shape falls back to its largest unlocked sub-shape (heroes outside get nothing). Strays only when no two heroes touch at all.
- combat_sim: per-side `_shape/_beh/_bid/_guard_uses` become per-part; each behaviour applies to its own heroes (roles per part). Stat bonuses per part, on its heroes only.
- Setup screens (formation_panel, formation_board, FormationWords) show every counting part, outlined, with its name and bonus; the battle banner names each part.
- Tests: two pairs, pair + trio, a locked part with fallback, Strays unchanged, deterministic replay of saved Echoes (bump the Echo/save version if behaviour changes old Echoes).
- Balance: two pairs vs one 4-shape of the same heroes; flag if splitting routinely wins.
