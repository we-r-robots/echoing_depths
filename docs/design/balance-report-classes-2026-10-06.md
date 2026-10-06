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

---

## Rounds 2 and 3 (classes-r2 branch, 2026-10-06)

This rerun uses the same runner and settings (`--runs=1500 --fights=1500`). It recorded 25,342 fights and ran 334,792 swap sims. It reflects the branch's final state:
- the round-2 and round-3 classes;
- the narrowed charge lock;
- the separate ability timer.

### What changed before this run
- **Classes:**
  - Fighter: Halberdier, Lightsworn (replaces Paladin), Bladebreaker, Ravager, Aegisbearer. Shackler is displayed as Warden of Chains. Iron Marshal's adjacency is now "all".
  - Rogue: Saboteur, Nightwatch, Informant, and the Duelist's Riposte rework.
  - Healer: Bloodletter, the Gravecaller's nameless husk, and the Confessor's Retribution Flame.
  - Mage: Reliquarist (formerly Enshriner).
- **Charge lock narrowed** (playtest fix): statuses a unit puts on others no longer stop its charge. Only its standing summons do.
- **Separate ability timer** (user rule): a full bar casts at the next action boundary and leaves the ATB gauge untouched.
- **Approved tuning:**
  - Bloodletter's drain starts at 40% of the damage it deals, shared among its allies.
  - Gate fixes, so that every advanced class beats its base:
    - Iron Marshal: the drive costs 3% max HP (was 6%) and gives +20 charge. Marshal's Blow 1.8 → 2.3.
    - Informant: Atk/Mag re-leaned to 18/18 (same budget). Shield power 6.5.
    - Unseen Arrest: stun 2.5 → 3 s.
    - Starcaller: boons +40% (were +30%), shield 2.6, +50 charge.
    - Column Ward: 1.8 → 2.4.
    - Tithe: gives 2.0× (was 1.6×).
    - Reliquary: seal 3.5 → 5 s.

### Runs
- Victory 53.4%. The Crystal is won 68.6% of the times it is reached.
- Fight win rates: PvP 54.1%, monsters 80.1%, guardians 81.8%.
- **PROVISIONAL stand-ins: 0.0%** (18.5% before round 2). Every region now has its own class.

### Fight length (benchmark, 2,000 fights each)
"Before" is this branch with the old jump-the-queue rule.

| | Before (jump the queue) | After (separate timer) |
|---|---|---|
| PvP mean / median | 26.6 s / 25.6 s | 26.7 s / 25.8 s |
| PvP fights reaching the Fading | 14.7% | 15.0% |
| Monster mean / median | 25.1 s / 24.0 s | 25.3 s / 24.6 s |
| Monster fights reaching the Fading | 14.6% | 14.3% |
| Actions per PvP fight | 34.4 | 35.1 |

Fights are not ending earlier, and the Fading is reached about as often as before.

### Advanced vs base gate (user rule: advanced > base)
**Method.**
- This is a paired swap test over 400 random fights, PvP and monsters.
- In each fight, hero 0 plays the advanced class and then its base class, both at level 2.
- The slot, party, opponent and seed stay the same.
- The suite version (`tests/test_class_gate.gd`) runs 80 fights and needs a margin of **+5 pp**.
- The stat total is HP/5 + Atk + Def + Mag + Spd at level 1. Growth budgets are also well above each base's: Fighter 10.0 vs 8.1, Rogue 8.2 vs 6.6, Healer 7.5 vs 5.9, Mage 7.5 vs 5.7.

| Class | Base | Stat total (adv / base) | Advanced wins | Base wins | Delta |
|---|---|---|---|---|---|
| Unseen Warden | Rogue | 95 / 67 | 44.0% | 37.8% | +6.2 pp |
| Nightwatch | Rogue | 95 / 67 | 44.0% | 37.8% | +6.2 pp |
| Reliquarist | Mage | 84 / 59 | 44.0% | 37.2% | +6.8 pp |
| Tithekeeper | Healer | 89 / 61 | 42.5% | 35.0% | +7.5 pp |
| Aegisbearer | Fighter | 104 / 73 | 46.8% | 38.2% | +8.5 pp |
| Threadmender | Healer | 89 / 61 | 43.5% | 35.0% | +8.5 pp |
| Informant | Rogue | 95 / 67 | 46.2% | 37.8% | +8.5 pp |
| Iron Marshal | Fighter | 104 / 73 | 47.2% | 38.2% | +9.0 pp |
| Starcaller | Mage | 84 / 59 | 47.2% | 37.2% | +10.0 pp |
| Saboteur | Rogue | 95 / 67 | 48.0% | 37.8% | +10.2 pp |
| Lumenward | Healer | 89 / 61 | 46.8% | 35.0% | +11.8 pp |
| Lampwright | Mage | 84 / 59 | 49.2% | 37.2% | +12.0 pp |
| Bladebreaker | Fighter | 104 / 73 | 50.2% | 38.2% | +12.0 pp |
| Lightsworn | Fighter | 104 / 73 | 51.0% | 38.2% | +12.8 pp |
| Wickburner | Healer | 89 / 61 | 48.0% | 35.0% | +13.0 pp |
| Gravecaller | Healer | 89 / 61 | 48.2% | 35.0% | +13.2 pp |
| Nightshade | Rogue | 95 / 67 | 51.0% | 37.8% | +13.2 pp |
| Warden of Chains | Fighter | 104 / 73 | 52.2% | 38.2% | +14.0 pp |
| Confessor | Healer | 89 / 61 | 49.2% | 35.0% | +14.2 pp |
| Chronist | Mage | 84 / 59 | 52.0% | 37.2% | +14.8 pp |
| Rekindler | Healer | 89 / 61 | 49.8% | 35.0% | +14.8 pp |
| Duelist | Rogue | 95 / 67 | 52.8% | 37.8% | +15.0 pp |
| Runebinder | Mage | 84 / 59 | 54.2% | 37.2% | +17.0 pp |
| Cleric | Healer | 89 / 61 | 52.0% | 35.0% | +17.0 pp |
| Assassin | Rogue | 95 / 67 | 55.0% | 37.8% | +17.2 pp |
| Halberdier | Fighter | 104 / 73 | 55.8% | 38.2% | +17.5 pp |
| Archmage | Mage | 84 / 59 | 56.2% | 37.2% | +19.0 pp |
| Fadewalker | Rogue | 95 / 67 | 57.5% | 37.8% | +19.8 pp |
| Ravager | Fighter | 104 / 73 | 58.2% | 38.2% | +20.0 pp |
| Cutpurse | Rogue | 95 / 67 | 58.2% | 37.8% | +20.5 pp |
| Bloodletter | Healer | 89 / 61 | 56.8% | 35.0% | +21.8 pp |
| Stormwake | Mage | 84 / 59 | 60.2% | 37.2% | +23.0 pp |
| Warlock | Mage | 84 / 59 | 61.8% | 37.2% | +24.5 pp |
| Wildfire | Mage | 84 / 59 | 62.5% | 37.2% | +25.2 pp |
| Berserker | Fighter | 104 / 73 | 64.0% | 38.2% | +25.8 pp |
| Echoblade | Fighter | 104 / 73 | 65.0% | 38.2% | +26.8 pp |

All 36 advanced classes clear the margin. Before the gate fixes, three failed: Informant (+2.0 pp), Iron Marshal (+3.7 to +4.8 pp) and Reliquarist (+3.0 pp).

### Classes (swap test, the method of section 2)
| Class | All | PvP | Note |
|---|---|---|---|
| Stormwake / Wildfire / Warlock | 82.4 / 82.2 / 80.7% | 71.6 / 71.4 / 68.4% | The Mage line still leads |
| Bloodletter | 72.7% | 61.7% | **Top healer** (Cleric 67.1%). See the note below the table |
| Halberdier | 68.8% | 60.7% | Third Fighter, behind Berserker and Echoblade |
| Lightsworn | 63.0% | 53.8% | Paladin was 55.8% |
| Iron Marshal | 60.5% | 52.4% | Was 45.6% in round 1 |
| Lumenward | 59.3% | 46.1% | Was 56.5% in round 1 |
| Bladebreaker / Aegisbearer / Ravager | 59.0 / 55.4 / 54.5% | 51.1 / 48.5 / 48.1% | Fighter control and friendly fire sit low among Fighters |
| Informant | 53.0% | 39.8% | No damage ability. Crystal win rate 17.5% |
| Nightshade | 52.4% | 39.9% | Was 48.4% |
| Saboteur / Nightwatch | 50.9 / 47.9% | 40.2 / 36.9% | Lowest Rogues, with Unseen Warden |
| Unseen Warden | 47.8% | 37.4% | Was 44.6%. Still the lowest class |

**Bloodletter.** The user noted it "might be too strong". Its drain is already modest: 40%, shared among allies. A Bloodletting cast in random PvP averaged 72 damage to foes and 17 HP healed; Sanctuary averaged 38 damage and 41 healed. Its strength is the area damage.

### Before and after the charge-lock fix (swap test, all fights)
| Class | Round 1 | Round 2 (old lock) | Final |
|---|---|---|---|
| Lumenward | 56.5% | 56.9% | 59.3% |
| Nightshade | 48.4% | 49.2% | 52.4% |
| Unseen Warden | 44.6% | 45.8% | 47.8% |
| Iron Marshal | 45.6% | 49.3% | 60.5% |
| Gravecaller | 64.7% | 63.1% | 65.4% |

"Final" is the narrowed lock with the separate timer and the gate fixes.

**Lumenward vs the base Healer.** The swap test's base rows are swaps among the four base classes, so they can't be compared with the advanced rows. The like-for-like check is the gate. In the same slot and the same fight, Lumenward beats the base Healer by **+11.8 pp** (46.8% vs 35.0%). Lumen Ward was not retuned. Among the healers it is still third from the bottom.

### Outliers to watch
- **Mage damage line** at 78–82%, as in round 1.
- **Bloodletter** leads the healers by 5.6 pp. If it needs a cut, the lever is its area damage (power 0.5), not the drain.
- **Unseen Warden, Nightwatch, Saboteur and Informant** are the bottom four. All are control classes with no damage ability. Each beats its base, but in head-to-head swaps against the damage Rogues they lose in 25–35% of slots.
- **Near-strict pairs:**
  - Echoblade over Ravager (35/6) and over Aegisbearer (32/5).
  - Berserker over Ravager (37/4).
  - Every damage Rogue over Nightwatch (about 31–34 / 5–6).
  - Bloodletter over Threadmender (26/2) and over Lumenward (25/2).

### PROVISIONAL items behind these numbers
- **Reliquarist seal rules (a)–(d):** the sealed unit still counts as standing, still takes the Fading, gets 8 s of seal immunity on release, and is invisible to melee.
- **Informant:** its shield splits evenly against an area ability. When no foe is at 70+ charge, it shields the weakest ally.
- **Gravecaller:** casts Grave Bolt when its front column is full.
- **Lantern Saint:** its parent is Lightsworn.
