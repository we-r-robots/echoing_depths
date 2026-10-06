# Balance report: approved advanced classes, 2026-10-06

This is a headless simulation only. The only data change behind it is the ruling-8 stat-budget normalisation; nothing was retuned to fix balance. It uses the same method as `balance-report-2026-10-05.md` section 4. The runner is `game/tests/balance_classes.gd`, and anyone can rerun it:

`godot --path game --headless -s res://tests/balance_classes.gd -- --runs=1500 --fights=1500`

## Method

- **Runs:** 1,500 greedy-bot runs (seeds 100000–101499). They play against one growing Echo pool kept in `user://sandbox/`, so the player's files are never touched. Default Training Grounds unlocks. The runs recorded 25,024 fights as they were met: the party, the opponent and the kind of fight.
- **Swap test:** 1,500 recorded fights that had at least one advanced hero, sampled evenly. Each hero slot is swapped to every class of its tier: the 27 advanced classes, or the 4 base classes. Level and items stay the same. The party is then re-placed with the default auto-placement (preferred column, rows 1, 2, 0, 3) and the fight is re-fought with 2 seeds. That is 257,326 sims.
- **Pairs:** for every advanced slot, two classes of the same base are compared. "A beats B" means A won more of the 2 seeds than B did. Pairs that differ by less than 10 pp are not listed.
- **Caveats:**
  - The bot never arranges formations, and it plays the class it lands in.
  - PvP is bot against bot Echoes.
  - The swap test re-places the whole party. A class that needs a neighbour (Iron Marshal) or an empty front slot (Echoblade, Gravecaller) is judged in whatever spot auto-placement gives it.
  - With 2 seeds per fight, treat differences under about 3 pp as noise.
  - Run-level numbers are not comparable with the 2026-10-05 report: recruitment, guardians and the Crystal all changed in between (playtest-1 fixes).

## 1. Runs

- Victory **49.8%**. The Crystal is won 67.0% of the times it is reached.
- Fight win rates: PvP 56.1%, monsters 77.9%, guardians 77.5%.
- **PROVISIONAL stand-ins:** 18.5% of advanced heroes landed in a region with no approved class and took the nearest approved region's class. The 2026-10-05 report had 52%.
- Classes heroes end runs in:
  - Paladin 1,115, Cutpurse 893, Cleric 664, Fadewalker 657, Archmage 650, Threadmender 383, Stormwake 320, Lumenward 283, Warlock 207, Lampwright 176, Shackler 132.
  - Every other class has fewer than 100.
  - Paladin is inflated by the fallback: Fighters start on the neutral cross, which has no approved class. LG and LE tie at one step, and the data order picks LG.

## 2. Classes (swap test: win rate when the slot plays this class)

| Class | Base | All | PvP | Guardian | Monster | Crystal |
|---|---|---|---|---|---|---|
| Stormwake | Mage | **81.5%** | 72.0% | 92.6% | 86.6% | 95.3% |
| Wildfire | Mage | **79.9%** | 70.2% | 92.3% | 88.0% | 83.1% |
| *Mage (base)* | Mage | 77.7% | 65.2% | 94.3% | 88.0% | 100.0% |
| Warlock (column Hexfire) | Mage | 77.6% | 66.9% | 91.1% | 85.6% | 84.6% |
| Archmage | Mage | 77.0% | 65.4% | 91.3% | 85.3% | 86.9% |
| Echoblade | Fighter | 74.4% | 71.1% | 82.1% | 76.8% | 67.8% |
| Runebinder | Mage | 74.1% | 63.0% | 87.8% | 81.6% | 84.3% |
| Berserker | Fighter | 73.0% | 72.1% | 75.8% | 72.4% | 72.3% |
| Chronist | Mage | 72.4% | 59.9% | 87.9% | 81.0% | 83.8% |
| *Healer (base)* | Healer | 69.0% | 56.5% | 87.3% | 77.3% | 50.0% |
| Assassin | Rogue | 66.8% | 61.6% | 70.8% | 69.9% | 78.9% |
| *Rogue (base)* | Rogue | 66.1% | 53.1% | 82.9% | 77.7% | 75.0% |
| Shackler | Fighter | 65.8% | 59.9% | 79.0% | 70.7% | 53.2% |
| Rekindler | Healer | 65.1% | 56.4% | 80.8% | 72.6% | 55.8% |
| Cleric | Healer | 64.9% | 57.7% | 79.0% | 71.2% | 53.5% |
| Gravecaller | Healer | 64.7% | 56.5% | 80.4% | 73.9% | 48.5% |
| Fadewalker | Rogue | 64.7% | 60.7% | 66.3% | 68.1% | 75.5% |
| *Fighter (base)* | Fighter | 64.5% | 53.3% | 80.8% | 71.7% | 75.0% |
| Starcaller | Mage | 64.5% | 50.8% | 81.0% | 74.0% | 77.7% |
| Lampwright | Mage | 63.8% | 51.9% | 79.1% | 73.9% | 68.5% |
| Cutpurse | Rogue | 63.4% | 59.9% | 67.6% | 68.1% | 61.5% |
| Confessor | Healer | 62.4% | 54.7% | 74.7% | 69.6% | 56.6% |
| Duelist | Rogue | 62.2% | 58.8% | 63.9% | 64.8% | 70.8% |
| Wickburner | Healer | 59.8% | 51.7% | 74.5% | 67.5% | 49.2% |
| Lumenward | Healer | 56.5% | 47.7% | 71.5% | 65.1% | 46.8% |
| Paladin | Fighter | 55.8% | 49.9% | 66.0% | 62.1% | 47.7% |
| Threadmender | Healer | 54.5% | 44.3% | 70.2% | 64.8% | 46.8% |
| Tithekeeper | Healer | 50.3% | 41.0% | 64.7% | 61.1% | 39.9% |
| **Nightshade** | Rogue | **48.4%** | 40.7% | 57.5% | 60.0% | 39.9% |
| **Iron Marshal** | Fighter | **45.6%** | 38.6% | 55.6% | 55.0% | 36.4% |
| **Unseen Warden** | Rogue | **44.6%** | 37.8% | 55.8% | 57.3% | 22.0% |

Base-tier rows are swaps among the 4 base classes, so compare them only with each other.

### Outliers

- **The Mage line is still the strongest.** All 8 Mage classes sit at 64–82%, and the five damage Mages (Stormwake, Wildfire, Warlock, Archmage, Runebinder) sit at 74–82%. This repeats the 2026-10-05 finding: guardians and the Crystal are a magic check.
- **Top:** Stormwake (81.5%) and Wildfire (79.9%).
  - Stormwake's three random hits are never stopped by Strays or Echo Step.
  - Wildfire's burn jumps through packed bot shapes.
- **Bottom:** Unseen Warden (44.6%), Iron Marshal (45.6%) and Nightshade (48.4%). All three are low-damage control or tempo classes that the swap test underrates, for three reasons:
  - They give up a damage ability.
  - Ruling 4 stops their charge while their effect is in play (Nightshade for 6 s of poison; the Warden through its 1.5 s of stealth and the stun).
  - The Warden's arrest only delays one ability.
- **Healer line spread (50–65%).**
  - Damage-carrying healers (Rekindler's Kindle Mend, Cleric, Gravecaller's Grave Bolt, Confessor) sit at 62–65%.
  - Pure support (Threadmender's link, Tithekeeper's zero-sum tithe, Lumenward's small heal) sits at 50–57%.
  - Tithekeeper and Threadmender also often fall back to a plain Smite when they lack two distinct allies.
- **Within-base near-strict pairs** (A beats B in that share of slots / loses in this share; the rest tie):
  - Fighter:
    - Echoblade over Iron Marshal 44/2.
    - Berserker over Iron Marshal 43/2.
    - Echoblade over Paladin 31/3.
    - Berserker over Paladin 30/3.
  - Rogue: every damage Rogue (Assassin, Cutpurse, Fadewalker, Duelist) beats Unseen Warden (33–38 / 5–6) and Nightshade (28–34 / 5–6).
  - Healer:
    - Tithekeeper loses to Gravecaller 3/27 and to Rekindler 3/27.
    - Cleric beats Tithekeeper 27/2 and Threadmender 21/2.
  - Mage: Stormwake beats Lampwright 30/3 and Starcaller 29/2; Wildfire beats Lampwright 28/2.
  - Under the horizontal-scaling rule (options, not power), these are the pairs to look at in round 2.

## 3. The user's watch items

- **Cleric: heal plus smite.**
  - In 3,000 PvP fights, a Sanctuary cast averages **47.5 HP healed plus 33.3 damage** (smite rider). That is the highest combined value of any healer ability. For comparison:
    - Mend: 30.4 healed + 20.7 damage.
    - Lumen Ward: 33.1 healed + 16.4 shielded.
    - Burn to Mend: 48.3 healed, minus its HP cost.
    - Tithe: 24.3 healed, paid by an ally.
  - In the swap test Cleric (64.9%) is level with the other damage-carrying healers, but it beats the pure-support healers in about 20% of slots while almost never losing to them (2–3%).
  - Verdict: it is not out of line with the top healers, but it is the strongest "safe" pick. Keep watching.
- **Bloodletter: not built.** The Healer CE quadrant is PICK ONE (Bloodletter or Hexmender), so nothing is built there. Healers who land in it fall back to Threadmender (N, one step away), or tie between N and Gravecaller (CE★) on its edge cells and take Threadmender because N is nearer their start. The user's "might be too strong" can't be measured until one is picked. The heal-inversion status Hexmender needs is already in the status system (tested).
- **Iron Marshal.**
  - Lowest Fighter (45.6%). Loses to every other Fighter class except Paladin (22/5 in its favour against Paladin).
  - In the swap test, auto-placement often leaves it without an edge-adjacent ally, so it plays its fallback strike (Marshal's Blow). When it does drive allies on, each pays 6% max HP, and ruling 4 doesn't lock its charge because the gauge fill is instant.
  - The user mused "maybe each adjacent". The adjacency set is now a data field (`drive_on` effect `adjacency`: `"edge"` → `"all"`), so that variant is a one-word data change to try in round 2. It was not tried here (no retuning).

## 4. PROVISIONAL items this report depends on

- **Nearest-region fallback for regions with no approved class.** Fighter N, CG, LG★, CE★; Rogue N, LG, CG★; Healer CE; Mage LE★. This gives 18.5% of advanced heroes a stand-in class and inflates Paladin, Cutpurse and Threadmender counts.
- **Gravecaller with nobody fallen casts Grave Bolt** (hits the weakest foe). In 3,000 PvP fights it cast Grave Bolt 137 times and Raise Husk 157 times, so its rate leans on the provisional half.
