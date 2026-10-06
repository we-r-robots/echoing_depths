# Advanced Class Options (for user approval)
*Research draft, 2026-10-05. Nothing here is approved or built. The user approves every advanced class personally; this is a menu, not a roster. Names are proposals. Amounts are balance and left to tuning.*

## Method
I read the spec (00 to 06), BUILD.md's non-negotiables, the class-roster draft (sections 1, 4b and "More user answers"), open-questions.md, `legend_memories.json`, and the code (`data/classes.gd`, `alignment.gd`, `data/abilities.gd`). Starting regions and corner distances below come from the code's `start_alignment` values and `region_of()`. I also surveyed job systems: Final Fantasy V, Tactics and XIV, Bravely Default I/II, Octopath Traveler I/II, Triangle Strategy, Tactics Ogre Reborn, Unicorn Overlord, Chained Echoes and Sea of Stars. Each option names its source idea, then adapts it to an auto-battler on a 2×4 grid: no manual targeting, abilities fire on charge, the back column deals and takes half physical damage with no exceptions, units move only by swaps, and summons don't count toward shapes. Each base class has one stat budget, so the 9 classes differ only in how it's spread (the "lean" in the Fantasy column). Every option adds a play pattern, not more power. Corner options marked **TWIST** bend the base class's core idea, following the Necromancer model. The other corners are strong, focused leans of their quadrant. Previous-draft ideas were reused only where they held up, and some were renamed.

## Grid legend
Axes: **Mercy (+) ↔ Cruelty (−)** and **Order (+) ↔ Freedom (−)**. Code region codes: `LG` = Mercy+Order, `CG` = Mercy+Freedom, `LE` = Cruelty+Order, `CE` = Cruelty+Freedom, `N` = neutral cross, `*` = corner. "Steps" = fewest single-axis memory steps from the start (threshold is 3 memories, so anything above 3 needs a strong shift, holding back, a Relic or a Guild trait).

| Base | Start (code) | Start region | Steps to regions | Twisted (hardest) corner(s) |
|---|---|---|---|---|
| Fighter | `[0,+1]` | **N** | N 0 · M+O 1 · C+O 1 · M+F 3 · C+F 3 · M+O★ 3 · C+O★ 3 · **M+F★ 5 · C+F★ 5** | **Mercy+Freedom corner and Cruelty+Freedom corner** (tied, 5 steps) |
| Rogue | `[−1,−1]` | **C+F** | C+F 0 · N 1 · C+F★ 2 · M+F 2 · C+O 2 · M+O 4 · C+O★ 4 · M+F★ 4 · **M+O★ 6** | **Mercy+Order corner** (6 steps) |
| Healer | `[+1,+1]` | **M+O** | M+O 0 · N 1 · M+O★ 2 · M+F 2 · C+O 2 · C+F 4 · M+F★ 4 · C+O★ 4 · **C+F★ 6** | **Cruelty+Freedom corner** (6 steps; Necromancer) |
| Mage | `[+1,−1]` | **M+F** | M+F 0 · N 1 · M+F★ 2 · M+O 2 · C+F 2 · C+O 4 · M+O★ 4 · C+F★ 4 · **C+O★ 6** | **Cruelty+Order corner** (6 steps) |

Existing classes, checked against `classes.gd` (all match the brief): Fighter Paladin `LG`, Berserker `CE`; Rogue Duelist `CG`, Assassin `LE`; Healer Cleric `LG`, Necromancer `CE*`; Mage Archmage `N`, Warlock `CE`.

Table key: **Pos** = preferred column. Physical classes sit in front; magic and support sit in back. Status words (stun, blind, sap, poison, shield, mark, hidden, slow, haste, seal, regen) refer to the approved shared timed-status system.

---

## Fighter: the general front-liner (start N)

### N: neutral cross (0 steps, START region; most Fighters land here)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Holdfast** | The wall that chooses who gets hit (HP/Def) | Shelters its row | For a few seconds, melee aimed at its row neighbours hits it instead. | Front, middle row | Middle of Tidebreak, Keeper's Ring; shelters a fragile Duelist or Berserker beside it | FFXIV tanks' Cover/Provoke |
| **Armsbearer** | Reads the foe and picks the right weapon (Atk/Def) | Right tool for foe | Hits the front foe; stuns it if it's a caster, saps its Atk if it's a brawler. | Front | Generalist that fits any party; punishes Lighthouse posts and front casters | Octopath II's Armsmaster |
| **Drillmaster** | Keeps the line in step (HP/Spd) | Calls the cadence | Hits the front foe and pushes each edge-adjacent ally's gauge forward. | Front | Seawall/Tidebreak tempo; offsets their Spd cost | FFT Squire's Yell |

★ Holdfast: the start region needs a simple, readable class, and "who gets hit" is the Fighter's core decision.

### Mercy+Order quadrant (1 step)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Paladin** (EXISTING) | Sustaining front line (HP/Def) | Hit foe + heal ally | Aegis Strike: hits the front foe and heals the most hurt ally. | Front | Seawall, Tidebreak; keeps a lone Hearth post alive | FFIV/FFT Paladin |
| **Banneret** | Fights for the formation, not itself (HP/Def) | Raises the banner | For a few seconds, the party's formation bonus counts double. | Front | Makes shape choice matter more: Crescent, Vault Door, Keeper's Ring | Unicorn Overlord's leader-unit bonuses |
| **Lightsworn** | Oath-bound guardian of the weakest (HP/Def) | Shields the weakest | Hits the front foe and gives the lowest-HP ally a shield. | Front | Pairs with glass casters; Lamplight guardian on top | FFV Knight's Cover |

★ Paladin: it's already live with its Legendary (Lantern Saint), and it's the only front-line healer.

### Cruelty+Order quadrant (1 step)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Shackler** | Drags casters into the light (Atk/Def) | Drags back foe fwd | Hits the front foe in its row and swaps it with the foe behind it, pulling the back unit forward. | Front | Breaks Choir, Lumari Chorus, Lighthouse; sets up Assassin and Berserker | Triangle Strategy's push/pull attacks |
| **Sunderer** | Breaks armour so others can kill (Atk/Def) | Sunders armour | Hits the front foe and saps its Def for a few seconds. | Front | Focus fire with Berserker, Assassin, Kindred | FFT Knight's Rend/Break arts |
| **Headsman** | Law's blade on the helpless (Atk) | Strikes the helpless | Hits the front foe; deals double to a stunned, sapped or marked foe. | Front | Finisher for any status party (Unseen Warden, Frostbinder) | Octopath's Break-then-burst |

★ Shackler: it's the clearest new play pattern (enemy swap), it's a direct counter to all-back shapes, and it uses only the approved swap.

### Mercy+Freedom quadrant (3 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Wayguard** | Free-ranging rescuer (HP/Spd) | Swaps in to rescue | Swaps places with the most hurt ally and gives it a shield. | Front ↔ anywhere | Pulls a hurt front-liner back to half physical; Vault Door, Echo Step | FE Rescue/Swap |
| **Outrider** | Harries casters (Spd/Atk) | Delays a caster | Hits the most charged foe (half physical if back) and pushes its gauge back. | Front | Counters Opening Volley; buys time for slow Seawall | FFX Delay Attack, FE cavalry |
| **Wanderfist** | Unarmoured, answers every blow (HP/Spd) | Counter stance | For a few seconds, it strikes back at every foe that hits it in melee. | Front | Draws melee in Hearth/Shardpoint tip; punishes Berserker-style multi-hits | FFV Monk's Counter |

★ Wayguard: it turns the swap rule into mercy, and every party can use it.

### Cruelty+Freedom quadrant (3 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Berserker** (EXISTING) | Wants to be hit (Atk, high charge on hit) | Front foes x3 | Rampage: strikes random front foes three times. | Front | Kindred (partner hit = charge), Hearth post, Shardpoint tip | FFV Berserker |
| **Bloodsworn** | Pays in its own blood (HP/Atk) | Pays HP to cleave | Spends some of its own HP to hit every foe in the front column hard. | Front | Pair with Paladin, Wickkeeper, Lifebond healers; Seawall-breaker | FFIV/FFXIV Dark Knight |
| **Pitfighter** | Picks the fight it wants (Atk/HP) | Calls out a foe | Hits the strongest foe in front; that foe must attack it for a few seconds. | Front | Pins the enemy's best hitter; protects Strays partners | FFXIV Provoke, gladiator archetype |

★ Berserker: it's live, has a Legendary template (The Red Tide), and has a clear charge-on-hit identity.

### Mercy+Order corner (3 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Vowkeeper** | Bodyguard sworn to one ally (HP/Def, low Atk) | Guards row partner | For a few seconds, ranged and magic hits aimed at the back ally in its row land on it instead. | Front, paired | Lamplight, Vault Door; keeps an Archmage or Cleric alive | FFV Knight's Cover, FE Pair Up |
| **Aegisbearer** | The unbreakable post (HP/Def) | Unbreaking wall | Gains a large shield, and every foe's melee hits it while the shield holds. | Front | Lighthouse post, Keeper's Ring; answers burst | BDII Bastion, FFXIV Hallowed Ground |

★ Vowkeeper: it guards against magic and ranged, which no other Fighter does, and it pairs naturally with the back column.

### Cruelty+Order corner (3 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Iron Marshal** | Drives allies, at a price (Def/HP) | Drives allies on | Fills each edge-adjacent ally's gauge, and each loses a little HP. | Front, beside hitters | Archmage, Assassin, Warlock beside it; Crescent, Vault Door | Bravely Default's Brave (act now, pay later) |
| **Warden of Chains** | Locks the enemy line in place (Def/Atk) | Chains the line | Hits the front foe and stuns it and the foe in its row behind. | Front | Stops swaps and Hold the Door; sets up Headsman | Tactics Ogre's Terror Knight lockdown |

★ Iron Marshal: it's tempo with a visible cost, which is pure order bought with cruelty.

### Mercy+Freedom corner (5 steps; TWIST #1)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Bladebreaker** (TWIST) | The blade that refuses to wound (HP/Def, low Atk) | Disarms a foe | Breaks the strongest front foe's weapon: its Atk is sapped hard and its attacks may miss for a few seconds. | Front | Neuters Berserker, Duelist, Assassin; Seawall walls that never die | FFT Knight's Rend Weapon |
| **Strayblade** (TWIST) | Abandons the line to fight alone (Atk/Spd) | Alone: hits harder | Hits the front foe, far harder when no ally stands edge-adjacent. | Front, apart | The reason to play Strays and Echo Step; weak inside shapes | Wandering-swordsman archetype (FFT Samurai) |
| **Echoblade** (TWIST) | A fighter who becomes many memories (Atk/Spd) | Calls its echo | Summons an echo of itself in an empty front slot that copies its basic attack until struck down. | Front | Fills a front line for back-heavy parties (doesn't count toward shapes) | FF Ninja's Image, FFXIV Bunshin |

★ Bladebreaker: it's the cleanest inversion of the Fighter's essence (a weapon that unmakes weapons), the way the Necromancer inverts the Healer.

### Cruelty+Freedom corner (5 steps; TWIST #2)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Hollowsworn** (TWIST) | The fighter who refuses to fall (HP/Atk) | Will not fall | For a few seconds it can't drop below 1 HP and hits harder; when the time runs out, it loses half its HP. | Front | Holds the line through a burst; combos with Rekindler, Wickkeeper, Lifebond | FFXIV Dark Knight's Living Dead |
| **Grey Reaver** (TWIST) | Fights for the Fading itself (HP/Atk) | Feeds on the grey | Hits the front foe, far harder once the Fading has begun. | Front | Stall teams (Keeper's Ring, healers), Greycaller | FFXIV Reaper's soul gauge |
| **Cravenguard** (TWIST) | A shield turned to self-preservation (HP/Spd) | Hides behind ally | When hurt, swaps behind the healthiest ally in its row and hits the foe that struck it. | Front ↔ back | Vault Door, Seawall rotations; cruel tanking | Original; inverts FFV Knight's Cover |

★ Hollowsworn: "stand and endure" pushed past death is the Fighter's essence twisted, and it's simple to read on the board.

---

## Rogue: speed, stealth, theft, precision (start C+F)

### Cruelty+Freedom quadrant (0 steps, START region)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Cutpurse** | Starves enemy abilities (Spd) | Steals charge | Hits the most charged foe and takes some of its charge for itself. | Front | Denies big casters; feeds Shardpoint tip | FF Thief's Steal, FFV Mug |
| **Lampsnuffer** | Puts out the enemy's light (Spd/Atk) | Snuffs the light | Hits the strongest foe and blinds it for a few seconds. | Front | Shields a Wanderfist or Holdfast from the hardest hitter | FF Blind, FFT Ninja smoke |

★ Cutpurse: theft is the Rogue's core idea and needs only a charge op.

### N: neutral cross (1 step)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Vaultrunner** | Scout who calls the target (Spd, low Atk) | Marks the weak | Marks the weakest foe; allies deal more damage to it for a few seconds. | Back (support) | Assassin, Archmage, Headsman; Choir | Octopath's Analyze, FFXIV Mug vulnerability |
| **Trapwright** | Sets snares on the line (Spd/Def) | Lays a snare | Sets a snare in its row: the next foe to attack that row is stunned. | Front | Punishes melee into Kindred; with Headsman | Triangle Strategy's Jens |
| **Chancer** | Lives by the dice (Spd/crit) | Rolls the bones | Hits a random foe with one random effect: double damage, stun, poison or steal charge. | Front | Wildcard for any party; fun in PvP | FFVI Setzer, BDII Gambler |

★ Vaultrunner: it gives the Rogue a back-column support role without breaking the half-physical rule, since it deals no damage.

### Cruelty+Freedom corner (2 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Fadewalker** | Strikes and vanishes (Spd/crit) | Strike, then vanish | Hits the weakest foe, then is hidden (can't be targeted) for a moment. | Front | Pulls fire onto Holdfast or Paladin; Strays | FFT/FFXIV Ninja's Hide |
| **Gutterknife** | Dirty fighting, many cuts (Spd/Atk) | Bleeds the line | Cuts every foe in the front column, poisoning each for a few seconds. | Front | Answers Seawall and Tidebreak; stacks with Nightshade | Octopath Thief's bleed arts |

★ Fadewalker: hit-and-vanish is the purest freedom-cruelty Rogue, and it reuses the Keeper's Ring untargetable hook.

### Mercy+Freedom quadrant (2 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Duelist** (EXISTING) | Chains abilities (Spd/Atk) | Front foe + charge | Riposte: hits the front foe and refills part of its own charge. | Front | Shardpoint tip, Crescent | FF/BDII Swordmaster |
| **Almsthief** | Steals from the strong, gives to the weak (Spd) | Steals and shares | Takes charge from the most charged foe and gives it to the weakest ally. | Front | Feeds Cleric, Archmage; denies casters | FF Mug + Robin Hood |

★ Duelist: it's live with a Legendary template (The Last Blade of Veil).

### Cruelty+Order quadrant (2 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Assassin** (EXISTING) | Finisher (Atk/crit) | Hits weakest foe | Execute: hits the weakest foe, harder below 40% HP. | Front | Shackler, Vaultrunner; Flank | FFT Assassin |
| **Bountyhand** | Works the contract (Atk/Spd) | Takes a contract | Marks the foe with the highest Atk; when it falls, the Bountyhand refills its charge. | Front | Long fights against one carry; Echo PvP | FFXII hunt marks |

★ Assassin: it's live with a Legendary template (The Quiet Hand).

### Mercy+Order quadrant (4 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Nightwatch** | Punishes melee on its friends (Def/Spd) | Watches over allies | For a few seconds, it strikes any foe that hits an edge-adjacent ally in melee. | Front, middle row | Tidebreak, Seawall, Keeper's Ring | XCOM-style Overwatch, FE counters |
| **Veilwright** | Hides friends in smoke (Spd/Def) | Smoke veil | Blinds every foe in the front column for a few seconds. | Front | Buys time for Choir and Hearth; counters melee rush | FF Ninja smoke bomb |

★ Nightwatch: it's a reactive guard, which is new for a Rogue, and it gives middle-row slots a purpose.

### Cruelty+Order corner (4 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Nightshade** | Slow, certain poison (Spd/Mag) | Slow venom | Poisons the healthiest foe for heavy damage over several seconds. | Front | Long fights, Keeper's Ring stalls; Gutterknife | Octopath Apothecary, BDII Salve-Maker poisons |
| **Spymaster** | Has read the enemy's orders (Spd) | Cuts their signals | For a few seconds, the foe's formation behaviour goes dark (its stat bonus stays). | Front | Answers Keeper's Ring, Hold the Door, Opening Volley | Triangle Strategy's Anna, Unicorn Overlord scouting |

★ Nightshade: it's patient, ordered killing, distinct from the Assassin's burst.

### Mercy+Freedom corner (4 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Wispdancer** | Dances in and out of danger (Spd) | Trades places | Hits the front foe, then swaps columns with the ally in its row. | Front ↔ back | Vault Door, Echo Step; rotates a hurt tank back | Octopath/FFXIV Dancer partner steps |
| **Unshackler** | Frees what others bind (Spd/Def) | Breaks the chains | Clears stun, blind and sap from every ally and steals one shield from a foe. | Front | The answer to CC-heavy parties | FF Esuna + BDII Thief's steal |

★ Wispdancer: free movement is the purest Mercy+Freedom Rogue, and it uses the approved swap.

### Mercy+Order corner (6 steps; TWIST)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Unseen Warden** (TWIST) | Stealth turned to enforcement (Spd/Def, low Atk) | Unseen arrest | Slips out of sight for a moment, then stuns the most charged foe and blinds the foes beside it. | Front | Stops the enemy's big ability; feeds Headsman, Sunderer | User idea; FF Stop + Triangle Strategy's Anna |
| **Locksmith** (TWIST) | A thief who now keeps the Vault's locks (Spd/Mag) | Locks away power | Seals the most charged foe: it gains no charge for a few seconds. | Front | Anti-ability with Cutpurse; counters Lanternbearer | Thief turned guard; FF Silence |
| **Gentle Hand** (TWIST) | Steals harm instead of gold (Spd/Def) | Steals the blow | Saps the strongest foe's Atk and gives that much Def to the weakest ally for a few seconds. | Front | Protects glass casters; mercy through theft | Original; inverts FF Mug |

★ Unseen Warden: it's the user's lean and fits the twist rule exactly (the stealth Rogue becomes the enforcer, with control instead of damage).

---

## Healer: mending and life (start M+O)

### Mercy+Order quadrant (0 steps, START region)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Cleric** (EXISTING) | Party-wide sustain (Mag) | Heal all + hit foe | Sanctuary: heals every ally and smites the front foe. | Back | Choir, Hearth | FF White Mage |
| **Wickkeeper** | Heals whoever stands beside it (HP/Mag) | Heals neighbours | Heals itself and every ally edge-adjacent to it. | Middle of a shape | Keeper's Ring keeper, Tidebreak middle, Vault Door | FFXIV WHM Asylum |

★ Cleric: it's live with a Legendary template (The Mother of Wicks).

### N: neutral cross (1 step)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Salvewright** | Field medic with remedies (Mag/Spd) | Cures and mends | Clears every status from the most afflicted ally and heals it. | Back | The answer to stun, poison and sap parties | Octopath Apothecary, BDII Salve-Maker |
| **Threadmender** | Ties two lives together (HP/Mag) | Binds two lives | Links the healthiest and the weakest ally: for a few seconds they share all damage taken. | Back | Big-HP fronts protect glass backs; Hollowsworn | FFXIV Scholar's Fey Union, Sage's Kardia |

★ Salvewright: once statuses ship, a cleanse is the most needed counter.

### Mercy+Order corner (2 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Lanternbearer** | Ability engine (Mag/Spd) | Charges all allies | Gives every ally a burst of charge. | Back | Duelist, Archmage, Shardpoint; ability-heavy parties | BDII Bard's BP songs |
| **Lumenward** | Barrier-weaver (Mag/Def) | Shields everyone | Gives every ally a small shield. | Back | Seawall, Tidebreak; blunts Warlock and Firestorm | FFXIV Scholar/Sage barriers |

★ Lanternbearer: it's an engine, not raw healing, so it opens combos rather than adding power.

### Mercy+Freedom quadrant (2 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Rekindler** | Second chances (Mag/HP) | Relights a fallen | Brings the first fallen ally back at low HP once per fight; otherwise heals the weakest. | Back | Berserker, Hollowsworn; Hold the Door | FF Raise/Phoenix Down |
| **Hearthsinger** | Wandering song of warmth (Mag/Spd) | Song of warmth | Gives every ally regen for several seconds. | Back | Long fights; Seawall's spread damage | FFV/BDII Bard |

★ Rekindler: revival is a unique pattern that changes how players use fragile classes.

### Cruelty+Order quadrant (2 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Tithekeeper** | Moves HP, never adds it (HP/Def) | Tithes the strong | Takes HP from the healthiest ally and gives more back to the weakest. | Back | Big-HP fronts (Holdfast, Paladin) feed glass casters | The "blood transfusion" trope |
| **Bonesetter** | Harsh medicine that works (Mag/Def) | Sets the bone | Heals the weakest ally a lot, but it's stunned for a moment. | Back | Rotate with Wispdancer/Wayguard; strong into slow fights | Original (battlefield medicine) |

★ Tithekeeper: "order at a cruel price" fits as a redistribution rule, and it never inflates total HP.

### Cruelty+Freedom quadrant (4 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Bloodletter** | Spreads small drains (Mag) | Drains every foe | Hits every foe lightly and heals all allies from the damage. | Back | Wide fights, Crystal fights, Nightshade | FFT/Tactics Ogre Drain |
| **Hexmender** | Curses healing itself (Mag) | Turns heals to harm | For a few seconds, healing on the target foe hurts it instead. | Back | Hard counter to Cleric and Wickkeeper parties | FF's Zombie status |

★ Bloodletter: it heals by hurting, the clear Cruelty+Freedom healer short of the Necromancer.

### Mercy+Freedom corner (4 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Wickburner** | Burns itself to light others (HP/Mag) | Burns to mend | Spends a share of its own HP to heal every ally by more. | Back | With Rekindler, Threadmender; heavy-HP lean | The Keeper's story (burning his own memory) |
| **Hearthwitch** | Heals by column (Mag) | Heals hurt column | Heals every ally in whichever column has lost the most HP. | Back | Seawall (front) or Choir/Lumari Chorus (back) | Unicorn Overlord's row-targeted skills |

★ Wickburner: it mirrors the lore's central sacrifice and has a visible cost.

### Cruelty+Order corner (4 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Confessor** | Denies the foe's mending (Mag/Def) | Blocks foe healing | Hits a foe; it can't be healed for a few seconds. | Back | Counters Cleric, Wickkeeper, Kindle memories | Original; anti-Regen curses |
| **Embalmer** | Preserves life by freezing it (Mag/HP) | Preserves an ally | For a few seconds, the weakest ally can't drop below 1 HP but can't act. | Back | Saves a carry through burst; stalls into Grey Reaver | FF Stop, FFXIV Holmgang |

★ Confessor: it's the simplest strong counter-pick, which PvP needs.

### Cruelty+Freedom corner (6 steps; TWIST)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Necromancer** (EXISTING, TWIST) | Heals by killing (Mag) | Drains weakest foe | Grave Drain: hits the weakest foe and heals itself from the damage. | Back | Assassin focus; Keeper's Ring keeper | FF/Tactics Ogre Necromancer |
| **Blightwright** (TWIST) | Mending turned to wasting (Mag) | Spreads the blight | Poisons the weakest foe; when it dies, the poison spreads to its neighbours. | Back | Packed shapes (Seawall, Vault Door); Nightshade | FFT Bio, inverted Esuna |
| **Gravecaller** (TWIST) | Raises the fallen as hollow husks (Mag) | Raises a husk | Raises the most recently fallen unit (either side) as a husk on its side's empty front slot. | Back | Front line for back-heavy parties; doesn't count toward shapes | Tactics Ogre's undead raising |

★ Necromancer: it's the user's model twist, it's live, and it has The Grey Shepherd template.

---

## Mage: arcane power and the memory in things (start M+F)

### Mercy+Freedom quadrant (0 steps, START region)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Stormwake** | Scattered lightning (Mag/Spd) | Random foes x3 | Strikes random foes three times (separate hits, not splash, so Strays and Echo Step don't stop it). | Back | Answers Strays; chips Crystal memories | FFVI random multi-hit spells |
| **Mirage Weaver** | Illusions that confuse the aim (Mag/Spd) | Weaves mirages | Hits the front foe and blinds every foe in its row for a few seconds. | Back | Protects Holdfast and Wanderfist; slows Berserker | FFT Oracle, BDII Phantom |

★ Stormwake: the start region needs a simple, readable damage class, and its pattern differs from Archmage and Warlock.

### N: neutral cross (1 step)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Archmage** (EXISTING) | Focused blast (Mag) | Back row + sides | Meteor: hits a back-column foe hard and splashes its neighbours. | Back | Choir, Lumari Chorus | FF Black Mage |
| **Glyphwright** | Writes delayed runes (Mag) | Writes a rune | Marks the foes' most crowded row; after a few seconds, a rune bursts on every unit in it. | Back | Punishes Vault Door and Seawall; Shackler packs them tighter | FFT charge-time spells |
| **Stonereader** | Draws on the memory in the stones beneath its row (Mag) | Reads the stones | Row 1 slows a foe, row 2 burns, row 3 shields an ally, row 4 stuns. | Back | Placement puzzle; same class, four roles | FFV/FFT Geomancer (terrain-based) |

★ Archmage: it's live with The First Scholar template. Stonereader is the strongest new idea here.

### Mercy+Freedom corner (2 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Spellsinger** | Tempo for the whole party (Spd/Mag) | Hastens allies | Pushes every ally's gauge forward. | Back | Opening Volley, Choir; Seawall that lacks Spd | FF Time Mage Haste, BDII Bard |
| **Starcaller** | Reads fortunes in the sky (Mag) | Draws a star | Gives a random ally one random buff: Atk, Mag, Spd, shield or charge. | Back | Freedom wildcard; scales with party variety | FFXIV Astrologian cards |

★ Spellsinger: haste is the clearest freedom-mercy spell, and every comp uses it differently.

### Mercy+Order quadrant (2 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Lampwright** | Shields a column (Mag/Def) | Shields its column | Gives every ally in its column a shield. | Back (or front to shield the wall) | Choir/Lumari Chorus, Seawall | FF Protect/Shell |
| **Glasswright** | Builds walls of Lumari crystal (Mag/Def) | Raises crystal wall | Raises a crystal barrier in an empty front slot; it never acts and draws melee until it breaks. | Back | Gives Choir a front line (doesn't count toward shapes) | Triangle Strategy's ice walls |

★ Lampwright: it's a positional shield, and the choice of column matters.

### Cruelty+Freedom quadrant (2 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Warlock** (EXISTING) | Wide damage (Mag) | Back row + all foes | Hexfire: hits a back-column foe and every other foe. | Back | Opening Volley, Lumari Chorus splash; weak into Strays | FF Black Mage area spells |
| **Ashcaller** | Lingering curse-fire (Mag) | Ash on the line | Hits every foe in the front column and poisons them. | Back | Seawall/Tidebreak breaker; Nightshade | FF Bio |

★ Warlock: it's live with The Debt-Binder template.

### Cruelty+Order quadrant (4 steps)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Runebinder** | Shuts down abilities (Mag) | Seals foe's charge | Hits the most charged foe; it gains no charge for a few seconds. | Back | With Cutpurse, a full anti-ability party | FF Silence, FFT Oracle |
| **Frostbinder** | Cold, exact control (Mag) | Freezes a foe | Hits the front foe and stuns it for a moment. | Back | Feeds Headsman; slows Berserker | FF Stop/Break |

★ Runebinder: ability denial is a clear order-cruelty pattern, distinct from the Rogue's theft.

### Mercy+Order corner (4 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Chronist** | Keeps time for the whole field (Mag/Spd) | Slows the field | Slows every foe for a few seconds. | Back | Counters Opening Volley and Spd parties; Bloodletter | FFV Time Mage Slowga |
| **Mirrorward** | Turns spells back on their caster (Mag/Def) | Raises a mirror | The next magic hit on each ally in its column bounces back to the caster. | Back | Counters Warlock, Archmage, Firestorm | FF Reflect |

★ Chronist: slowing the whole field is an ordered, merciful mirror of Spellsinger.

### Cruelty+Freedom corner (4 steps; strong lean)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Greycaller** | Calls the Fading early (Mag/HP) | Brings the Fading | Hits a foe and brings the Fading closer. | Back | Grey Reaver; Bloodletter, Nightshade late game | Crystal memory `hasten_fading` (precedent in sim) |
| **Wildfire** | Fire that spreads where it likes (Mag) | Fire that spreads | Burns a random foe; the fire jumps to an edge-adjacent foe each few seconds. | Back | Punishes packed shapes; weak into Strays | Triangle Strategy's burning tiles |

★ Greycaller: it plays the Fading itself, which is unique to this world.

### Cruelty+Order corner (6 steps; TWIST)
| Name | Fantasy | Ability label | Tooltip | Pos | Play pattern / combos | Inspired by |
|---|---|---|---|---|---|---|
| ★ **Mirrormind** (TWIST) | Draws a foe's memory and casts it (Mag) | Casts foe's ability | Recall: casts the target foe's own ability against its side. | Back | Reads the enemy party; mirrors what they brought | FFV Blue Mage/Mimic; the Lumari "draw" |
| **Hushbinder** (TWIST) | Magic turned to forbid magic (Mag/Def) | Silences all magic | Saps every unit's Mag, its own included, and stops all ability charge for a few seconds. | Back | Physical parties (Berserker, Assassin) with a silencer | FF Silence-all, Disgaea's anti-magic |
| **Reckoner** (TWIST) | Cold arithmetic over the field (Mag) | Counts the field | Hits every unit, either side, in the most crowded row. | Back | Pair with Strays or Echo Step for safety | FFT Arithmetician |

★ Mirrormind: drawing out a foe's memory is the Lumari sin turned into a spell, and it bends the Mage's essence (its own art) the furthest.

---

## Mechanics these options would need (beyond the timed-status system)
| Mechanic | Used by | Precedent in sim |
|---|---|---|
| Gauge push/delay op | Drillmaster, Outrider, Iron Marshal, Spellsinger, Chronist | none (small op) |
| Charge steal/give, charge seal | Cutpurse, Almsthief, Locksmith, Runebinder, Hushbinder | memory `draw_memory` |
| Conditional damage (alone, Fading active, foe has a status, below HP) | Strayblade, Grey Reaver, Headsman | `bonus_below_hp` |
| Ally swap and enemy swap | Shackler, Wayguard, Wispdancer, Cravenguard | Hold the Door |
| Taunt/redirect (row, single foe, column) | Holdfast, Pitfighter, Aegisbearer, Vowkeeper | `draw`, Lamplight guardian |
| Reactive triggers (counter, overwatch, snare, on-hurt) | Wanderfist, Nightwatch, Trapwright, Cravenguard | formation behaviours |
| Summons (echo, crystal wall, husk) | Echoblade, Glasswright, Gravecaller | inert Crystal unit |
| Revival once per fight | Rekindler | none |
| Can't-drop-below-1 window | Hollowsworn, Embalmer | none |
| Damage link between two units | Threadmender | Tidebreak's Brace (shared damage) |
| HP transfer and self-HP cost | Tithekeeper, Bloodsworn, Wickburner, Iron Marshal | `drain` |
| Heal inversion and heal block | Hexmender, Confessor | none |
| Cleanse and steal shield | Salvewright, Unshackler | none |
| Formation tweaks (double the bonus, suppress the behaviour) | Banneret, Spymaster | Keeper's `dim_lantern` |
| Delayed area, spreading effect | Glyphwright, Wildfire, Blightwright | none |
| Row-dependent ability | Stonereader | none |
| Random-effect table | Chancer, Starcaller | `random_enemy` |
| Ability copy | Mirrormind | none |
| Fading clock push | Greycaller | memory `hasten_fading` |
| Authored `short` labels and tooltips in data | all | `ability_short()` can't phrase these |

## Conflicts and risks noticed
- **Hidden front units vs melee targeting.** If a hidden front unit (Fadewalker, Unseen Warden) counts as "empty", melee would spill onto the back column. Rule needed: melee skips to the nearest *visible* front unit, and reaches the back only when no front unit is standing.
- **Poison, bleed and burn vs the back-column rule.** Statuses must be magic-typed (unaffected by column), or every DoT on a back unit raises a "piercing" question. Recommend: all status damage is non-physical, stated once in the status system.
- **Enemy swaps (Shackler, Cravenguard on hit).** The user approved swaps; I assume the formation shape stays as computed at fight start (as Hold the Door does). Swapping an *enemy* is still within one side, but please confirm it's in scope.
- **Hollowsworn, Embalmer and the fight-end rule.** "A fight ends when one side has no heroes standing" needs a ruling for units held at 1 HP. Also make sure they can't outlast the Fading.
- **Stun-lock in PvP.** Unseen Warden, Frostbinder, Warden of Chains, Trapwright and Armsbearer together could chain stuns. Suggest diminishing returns (a short immunity after a stun ends).
- **Summons and shapes.** Echoblade, Glasswright and Gravecaller fill front slots without counting toward shapes (current rule). A summon in a front slot still shields the back column from melee, so it's a real effect. The user's "summoner tile choice" idea would fit all three.
- **Gravecaller raising enemy units** is a mild form of ability/unit stealing, so it may collide with the "no strictly stronger" principle. It's an option only.
- **Stat budget vs existing classes.** The 8 live advanced classes don't share one stat total per base (e.g. Paladin and Berserker spread different totals). Normalise them when the one-budget rule is applied.
- **Corner classes behind Guild traits** must stay sidegrades (spec: meta gives variety, not power). Mirrormind and Spymaster are the most likely to read as "just better" in PvP; watch them.
- **Name overlap.** "Grey Reaver" and "Greycaller" sound alike, as do "Wickkeeper", "Wickburner" and the legend "The Mother of Wicks"; "Lanternbearer" sits near "Lantern Saint". Rename where the user dislikes the overlap.
