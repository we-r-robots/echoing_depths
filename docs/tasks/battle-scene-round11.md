# battle-scene: critic round 11 (2026-10-05, local, overnight): FAIL, piece PARKED

Judged: round-15 build (6320e9b), captures/battle-scene/r15/. Pairs vs SoS combat 013/018/036 and SAP 031/032 (same frames as round 10).

**Decoded:** ours = B in 1,3; A in 2,4,5. Ours **2/5** (round 10: 1/5). Won pair 4 (Backstab KO vs SAP 031) and pair 5 (victory vs SAP 032, newly won). Lost all three Sea of Stars action frames.

**Fixed since round 10 (critic confirmed):** victory names the real team, survivors visible, speed controls gone; hit-stop registers; no label-on-label or label-on-HUD in 14+ hits; single-target attribution passes; Fading reads as fading memory; 60 fps timing clean.

**Open review FAIL:**
1. Attribution still ambiguous at the big moments: Cleave "CRIT! 103" (Moth's) drawn over Corin's legs; Firestorm "CRIT! 65 KO!" (Vael's) on Ilse's staff, KO! box over Brakka.
2. Captions misreport multi-target abilities: "Oren Mend ▸ self" while the main event is CRIT! 24 on Ilse; "Ilse Mend ▸ Sable + 1" hides that the +1 is an enemy killed by a heal ability.
3. Melee staging piles sprites: the Cleave lunge lands inside the enemy block; the Backstab attacker stands inside two units; the diagonal grid lets heroes overlap at rest.
4. Smite/Mend light column is a flat, hard-edged ~330 px rectangle (reads as a debug quad).
5. Brakka's Cleave banner appears while enemy Corin is still mid-swing (mirror match reads as Corin casting).
6. Victory: survivors huddle in a corner, the centre is corpses, the band's first 2 frames are empty black.

**Biggest remaining gap:** at area crits, KOs and backstabs the attacker, targets and numbers stack on top of each other, so you need the caption to know who hit whom.

## Decision: park the piece
The user's direction was "try a couple more rounds and move on" (busy numbers may be acceptable chaos). Rounds 10 and 11 ran since. The top gap (bodies overlapping in the grid and on lunges) is tied to sprite footprint, which the character redesign will change. Parked until the new character art, with this backlog:

### Backlog, presentation only (cheap, can be done any time)
1. Multi-target labels stack upward above their own target's head, never sideways; KO! box away from neighbours or under the number.
2. Captions name every kind of target ("Oren Mend ▸ Ilse · heals self", "Ilse Mend ▸ Sable · strikes Corin"); "+N" only for same-kind extras.
3. Pixel-art beam for Smite/Mend (target width, banded/dithered, soft top, ground ring).
4. Hold the next banner until the previous actor is idle and its trail has cleared (or dim the previous actor).
5. Victory: survivors step forward centre-front, corpses fade back, banner text on its first frame, drop the redundant timer.
6. Fading: show the line before the readout, start the readout at the first real step (no ×1.00), show the per-hit "Fading ×N" tag only on the first hit after each step.
7. Crystal: Firestorm 33/60/24 knot at 13.6–14.6 s; the "20" at 30.7 s touches the lore band.

### Depends on the character redesign
- Grid spacing and lunge stop points sized to the new sprite footprint (no two bodies overlapping at rest).
- Side identity in mirror matches (team-coded palettes/silhouettes; presentation can add tinted HP bars).
- Wind-up, flinch and KO-fall poses.

## Critic report (summary of the hand-back)
Part 1 notes: captures/battle-scene/critic11/notes/part1.md. Table: 1 A (ref) high; 2 B (ref) high; 3 A (ref) med-high; 4 A (ours) med; 5 A (ours) med. Lost the SoS frames because SoS shows one focal event per frame with attacker and target far apart; ours shows overlapping sprites, rings, sparks and numbers in one knot.
