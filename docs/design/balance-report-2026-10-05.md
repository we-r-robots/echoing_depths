# Balance report, 2026-10-05

Headless simulation only. No game code, data or tuning was changed. Built on `gauntlet-build` at f24ddd1.

## Method

- **Runs:** 3,000 runs with `run_bot` "greedy" (seeds 100000–102999) and 1,000 with "random" (seeds 500000–500999). Each policy gets its own fresh Echo pool, which grows as runs finish, as `tests/run_sim.gd` does. Default Training Grounds unlocks. `story_chapter` 1. Per-run `best_floor` is carried over, so depth milestones pay once per career (only the first run gets them).
- **Bot behaviour:** the greedy bot rests at 7 health or less, recruits while the party is under 4 and levels the least-remembered hero. It holds back 20% of the time. **It never calls `set_formation`**, so heroes keep the auto-placement: preferred column, rows 1, 2, 0, 3. Every bot formation is therefore a side effect of the class mix, and the shapes a 4-hero bot party forms (Vault Door, Shardpoint, Keeper's Ring) are locked by default, so they fall back.
- **Counterfactuals:** these replay recorded fights, using the party as it was at that fight against the opponent it really met (PvP Echo, monster group or guardian).
  - Crystal: all 1,120 parties that reached the Crystal, 3 seeds each, per tuning variant. Variants are passed through `simulate_crystal` options or the `tuning` override.
  - Formations: up to 900 fights per party size. Every shape of that size, plus Strays and Unformed, all unlocked, 2 seeds. Heroes are assigned two ways: *smart* (front-preferring and sturdier heroes take the front cells) and *random*.
  - Classes: 6,143 hero slots. The hero is swapped to each class of its tier at the same level and the party is re-placed with the default auto-placement, 2 seeds.
- **Caveats:** the bot plays formations badly and gets no Training Grounds unlocks, so the run-level numbers describe a weak player. PvP is bot against bot Echoes, so its win rate sits near 50% by construction. Only 8 advanced classes exist: **52% of heroes end the run in a placeholder class** (the nearest authored class stands in for an unauthored region), which inflates the counts for Cleric, Paladin, Archmage and Duelist. Counterfactual fights use 2–3 seeds, so treat differences under about 3 pp as noise.

## 1. Run outcomes (greedy bot, n = 3,000)

**Victory: 24.7%.** The Crystal is reached in 37.3% of runs and won 66.2% of the time when reached. The random policy wins 10.8% of runs.

| Where runs end | Share of runs |
|---|---|
| Floor 3 guardian | 17.1% |
| Floor 4 guardian | 21.6% |
| Floor 4 PvP / monster | 10.0% / 3.5% |
| Floor 5 PvP / monster | 6.3% / 3.2% |
| Floor 5 Crystal (defeat) | 12.6% |
| Victory | 24.7% |
| Other (floor 2–3 PvP and monsters) | 0.9% |

By node type, the killing blow is a guardian in 38.8% of runs, PvP in 16.9%, the Crystal in 12.6% and a monster fight in 7.0%. No run dies before floor 3.

| Floor | Reached | Mean health on entry | Entering at ≤ 3 health | PvP win | Guardian win | Monster win |
|---|---|---|---|---|---|---|
| 1 | 100% | 10.0 | 0% | 52.5% | 48.2% | 84.2% |
| 2 | 100% | 8.4 | 0% | 58.5% | 45.9% | 76.7% |
| 3 | 100% | 6.6 | 6% | 57.5% | 38.1% | 66.8% |
| 4 | 82% | 4.9 | 37% | 58.3% | **28.9%** | 63.3% |
| 5 | 47% | 4.7 | 41% | 58.4% | Crystal 66.2% | 55.9% |

The guardians are the run's wall. Losing one costs 2, 2, 3 and 3 health, and the floor-4 guardian (29% win) costs 3. In the class-swap test, guardians are mostly a magic check: magic advanced classes win 61–62% of guardian fights, physical ones 24–33% (section 4).

## 2. The Crystal

On defeat, **92.8% of parties chip exactly 3 fragments** (3 seeds; the run data shows 93%, the earlier sample 97%).

**Why:** 97% of Crystal defeats (365 of 378) end in **the Fading**, not by the memories. A defeated party has felled all 4 memories in 73% of cases and 3 of them in 26%. Fragment 3 breaks at about 28 s (median) and releases the last memory. The party clears it, and then the Fading (36 s) wears it down while it hits an undefended Crystal in the last quarter. The Crystal is a damage race against the clock, so defeats pile up between 75% and 100% integrity lost (mean 0.87, sd 0.09).

Variants were re-fought with the same 1,120 parties, 3 seeds each (3,360 fights per row):

| Variant | Win | Fragments on defeat (2 / 3) | Integrity lost on defeat: mean (p10–p90) | Reaches the Fading |
|---|---|---|---|---|
| **Current: integrity 600, 4 memories** | 65.9% | 7% / 93% | 0.87 (0.76–0.97) | 63% |
| Integrity 450 | 87.8% | 2% / 98% | 0.88 | 39% |
| Integrity 800 | 31.6% | 17% / 83% | 0.83 (0.70–0.96) | 89% |
| Integrity 1000 | 11.5% | 39% / 61% | 0.77 (0.62–0.93) | 97% |
| 3 memories | 85.0% | 17% / 83% | 0.86 | 42% |
| 2 memories | 98.1% | 0% / 100% | 0.91 | 10% |
| Chapter 2–4 memories (Knight, Draw, Sealing, Keeper) | 54.1% | 18% / 82% | 0.83 | 68% |
| Party 1 level lower (as if memories were stronger) | 46.9% | 11% / 89% | 0.85 | 77% |
| Party 1 level higher | 87.3% | 2% / 98% | 0.89 | 42% |
| Fading at 48 s | 95.5% | 1% / 99% | 0.91 | 16% |
| Integrity 750, Fading at 44 s | 77.6% | 5% / 95% | 0.88 | 53% |
| Integrity 900, Fading at 48 s | 71.3% | 5% / 95% | 0.89 | 58% |

- **No integrity or memory-strength setting breaks the cluster** without wrecking the win rate. Only integrity 1000 (11% win) gets 2 fragments above a third of defeats. The cause is structural: the threat sits at the end of the fight (each fragment adds a memory, and the clock runs out last).
- **Paying by integrity instead of by fragment** gives 12 distinct values instead of two. Glimmers = round(24 × integrity lost) has sd 2.1 Glimmers on the current tuning. The spread is still narrow, but it is honest: every hit counts.
- **Win rate by party size:** 2 heroes 89% (n = 36), 3 heroes 90%, 4 heroes 62%. Bot 4-hero parties usually fight as Kindred (the fallback for a locked Vault Door, 60%) or Tidebreak (42%). Those shapes put melee heroes in front, where they spend the clock on memories instead of the Crystal. Bot parties that fall back to Choir (back-heavy, magic) win 72%. This is a placement effect more than a size effect.

## 3. Formations

Counterfactual: the same fight and opponent, each shape forced, all shapes unlocked. *Smart* = sensible hero assignment. "Top" = the share of parties for which the shape is the best or tied best (smart).

**4 heroes (900 fights; the average shape wins about 55%)**

| Shape | Smart | Random | Reaches the Fading | Top |
|---|---|---|---|---|
| **Lighthouse** | **66.3%** | 52.8% | 16% | 64% |
| Strays | 60.1% | 43.8% | 11% | 54% |
| Crescent | 57.9% | 48.6% | 4% | 51% |
| Vault Door | 56.2% | 45.2% | 7% | 48% |
| Lumari Chorus | 54.3% | 51.6% | 19% | 49% |
| *Unformed (no bonus, no cost)* | *53.7%* | 38.3% | 10% | 44% |
| Shardpoint | 52.1% | 41.6% | 14% | 44% |
| Echo Step | 51.7% | 37.9% | 11% | 44% |
| Keeper's Ring | 51.2% | 39.4% | 7% | 42% |
| **Seawall** | **44.3%** | 45.5% | 4% | 35% |

**3 heroes (900 fights)**

| Shape | Smart | Random |
|---|---|---|
| Strays | 42.4% | 30.3% |
| Hearth | 42.3% | 31.3% |
| Keystone | 38.5% | 30.5% |
| *Unformed* | *35.1%* | 25.2% |
| Choir | 34.0% | 35.7% |
| **Tidebreak** | **25.8%** | 26.5% |

**2 heroes (728 fights; mostly guardians, hence the low rates)**

| Shape | Smart | Random |
|---|---|---|
| Lamplight | 31.3% | 22.4% |
| Strays | 30.8% | 23.1% |
| Kindred | 27.2% | 24.2% |
| Vigil | 27.1% | 23.8% |

Flags:

- **Dominant:** Lighthouse (+11 pp over the 4-hero average; best for 64% of parties, and best against guardians at 58% where others reach 27–51%).
- **Strays sits 2nd at 4 heroes and 1st at 3, with no behaviour.** Spd +5% and crit +5% beat most shape bonuses together with their costs.
- **Never worth it:** Seawall (worse than Unformed by 9 pp) and Tidebreak (worse than Unformed by 9 pp). The +55% / +45% front Def does not pay for Share the blow (30%) and Brace (20%) spreading hits, plus the Spd cost. Shardpoint, Echo Step and Keeper's Ring land at or below Unformed: their costs eat their bonuses.
- **Usage (bot, real runs):** 4-hero bot parties mostly form Vault Door, which falls back to **Kindred** (11,447 fights, 65% won), or Shardpoint, which falls back to Choir (5,663 fights, 71%). Choir as an effective shape wins 68–79% wherever it appears. Tidebreak, real or as a fallback from Keeper's Ring or Seawall, wins 35–49%. The default fallback order (Kindred first, by data order) quietly gives most 4-hero parties a 2-hero bonus.

## 4. Classes (swap test: same slot, level and items; auto-placement)

| Base class | All fights | PvP | Guardian | Monster |
|---|---|---|---|---|
| **Mage** | **69.5%** | 69.2% | 62.5% | 80.2% |
| Healer | 59.2% | 60.3% | 46.0% | 70.7% |
| Rogue | 59.0% | 60.8% | 44.6% | 68.4% |
| Fighter | 55.4% | 58.8% | 36.4% | 63.1% |

| Advanced | Base | All | PvP | Guardian | Monster |
|---|---|---|---|---|---|
| **Warlock** | Mage | **68.9%** | 68.1% | 61.9% | 80.2% |
| **Archmage** | Mage | **67.0%** | 65.5% | 61.2% | 79.8% |
| Necromancer (corner) | Healer | 64.4% | 67.6% | 42.0% | 74.1% |
| Berserker | Fighter | 59.1% | 63.4% | 32.7% | 68.2% |
| Cleric | Healer | 54.2% | 56.7% | 33.0% | 66.0% |
| Assassin | Rogue | 51.4% | 54.3% | 28.0% | 63.1% |
| Duelist | Rogue | 51.2% | 54.9% | 24.1% | 63.7% |
| **Paladin** | Fighter | **48.7%** | 51.8% | 25.3% | 60.0% |

These results agree with the real runs: a Mage in a PvP party adds +7 pp of win rate against the floor average, and a Warlock adds +9 pp.

Flags against the horizontal-scaling rule (options, not power):

- **The Mage line is strictly stronger:** +10 pp as a base class and +14 to 20 pp as an advanced class over the physical lines, in every fight type and party size. Guardians and the Crystal are where it shows most.
- **Within a base, near-strict pairs:**
  - Necromancer beats Cleric in 21% of slots and loses in 4% (the rest tie).
  - Berserker beats Paladin 22% / 5%.
  - Archmage against Warlock (9 / 12) and Duelist against Assassin (14 / 14) are balanced.
- **Necromancer is a corner class**, rare and meant to be meta-gated (spec 02/04: corners must be sidegrades). It is +10 pp over Cleric, so it breaks that rule.
- Paladin is the weakest advanced class and the only one with an authored Legendary (Lantern Saint: 31 runs, too few to judge).

## 5. The Fading (36 s)

| Fight type | Reaches the Fading | Ended by it | Median length (p90) |
|---|---|---|---|
| PvP | 5.7% | 3.6% | 22.0 s (33.5) |
| Monster | 14.2% | 8.8% | 25.7 s (38.3) |
| Guardian | 22.5% | 13.1% | 30.2 s (39.5) |
| **Crystal** | **64.5%** | **32.6%** | 41.0 s (44.3) |
| All fights | 13.2% | 7.9% | |

- "Most fights end before it" holds for PvP and monster fights. Guardians brush against the limit.
- In the Crystal fight, the Fading **is** the loss condition (97% of defeats, section 2).
- After the Fading starts, the party wins 55% of PvP fights, 51% of monster fights and 37% of guardian fights. Guardians outlast the party in the Fading.

## 6. Meta economy (greedy, steady state: milestones already claimed)

| Outcome | Runs | Glimmers (mean) | Of which depth / PvP / fragments | Shards |
|---|---|---|---|---|
| All | 3,000 | 44.2 | 25.0 / 17.0 / 2.2 | 0.25 |
| Victory | 742 | 57.1 | 30 / 27.1 / 0 | 1 |
| Fallen | 2,258 | 40.0 (range 12–84) | 23.3 / 13.7 / 2.9 | 0 |
| Fallen at the Crystal | 378 | 73.8 | 30 / 26.2 / 17.6 | 0 |

- **Per run:** 0.69 Shard-equivalents, so 1.45 runs per Shard. Glimmers alone form a Shard every 2.3 runs.
- **Victory vs loss:** a victory (57 Glimmers + 1 Shard) is worth 3.9 average losing runs and 2.1 Crystal defeats, which matches "several losing runs".
- **Losing at the Crystal pays more Glimmers than winning** (74 vs 57) because fragments pay only on defeat. That is fine once the Shard is counted, but it is visible on the results screen.
- **Depth milestones** add only 20 Glimmers over a whole career (4 per floor, once).
- **Price check at bot skill:**
  - All 10 locked shapes (2 at 1 Shard, 8 at 2 Shards) cost 18 Shards, about 26 runs.
  - The 5 paid crests (125 Glimmers) take about 3 runs.
  - The first 3-hero shape takes about 1.5 runs.

## Recommendations (in priority order; numbers to try)

1. **Crystal payout: pay by integrity, not by fragment.** Glimmers on defeat = round(24 × integrity lost), the same total as 4 × 6 today. This gives 12 distinct values, at the cost of one line of code. If you want a real spread of outcomes, the fight has to kill earlier than the last quarter. Two untested options:
   - Release 2 memories at the start and one at fragments 1 and 2, with none at fragment 3.
   - Have the Fading start at a fragment count instead of at 36 s.
   No integrity or memory-strength tuning achieved this in the tests.
2. **Mage line power.** Try Mage, Archmage and Warlock Mag −15% (Mage 20→17, Archmage 31→26, Warlock 29→25), or lower `back_row_phys_mult` protection for casters. Alternatively, raise guardian Mag so guardians stop being a magic-only check. Re-run the swap test until the four lines sit within ±4 pp.
3. **Necromancer vs Cleric, Berserker vs Paladin.** Necromancer Mag 28→25 and HP 140→130. Paladin Def 22→25 or a stronger `aegis_strike`, or Berserker Atk 30→27.
4. **Formations:**
   - Seawall: Share the blow 0.30→0.15 and front Def +55%→+30%.
   - Tidebreak: Brace 0.20→0.10.
   - Strays: drop the crit +5% (keep Spd +5%).
   - Lighthouse: back Mag/heal +10%→+5%, or make the post's taunt draw only single-target magic.
   - Shardpoint, Echo Step and Keeper's Ring: halve their costs.
   - Re-run until every shape beats Unformed with smart placement.
5. **Floor 4 guardian:** win rate 29% and it costs 3 health. Try loss_health 3→2, or level −1. That should lift victories toward about 30% without touching the Crystal.
6. **Locked-shape fallback:** prefer the fallback whose bonus suits the cells (or Lamplight over Kindred for 2F+2B), or unlock Vault Door by default. Most 4-hero parties currently fight with a 2-hero front-Def bonus.
7. **Re-measure with a formation-aware bot** (one that tries each shape and keeps the best) before tuning shapes for real. Today's run-level formation usage reflects auto-placement, not player choice.
