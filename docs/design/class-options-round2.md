# Advanced Class Options, Round 2 (for user review)
*Research draft, 2026-10-06. Nothing here is approved or built. You approve every class yourself, so this is a menu for your round-2 votes, not a roster. Names are proposals (ruling 10: "we can adjust names easily"). Amounts are balance and are left to tuning.*

**Sources.** Your verdicts, notes and rulings (`class-verdicts-round1.md`, which this doc treats as authoritative), the round-1 menu (`advanced-class-options.md`, which has the grid legend, step counts and mechanics list), the roster draft, the spec (`01-world-and-lore.md`, `02-heroes-and-classes.md`, `03-runs-and-combat.md`, `05-formations.md`), the back-column code (`combat_sim.gd` `_damage`, `tuning.gd` `back_row_phys_mult = 0.5`), and the horizontal-scaling rule (options, not power; strength comes from combos). The job-system references are FF V/VI/XII/XIV/T/TA, Tactics Ogre Reborn, Octopath I/II, Bravely Default I/II, Triangle Strategy and Unicorn Overlord.

**How to read the tables.** Each option has a name, a one-line identity, an **ability** (one plain sentence, the kind a player reads at a glance in the tooltip), a **column**, its **synergies**, and its **inspiration**. **NEW** means it's new this round. **REWORK** means a round-1 "maybe" changed to follow your note. **CARRIED** means a "maybe" you left without a note, shown unchanged so you can still vote on it. **MOVED** means an approved or "maybe" class proposed for a new home (section 3). ★ marks my recommendation for the region, with one line on why.

**Unique, not stronger.** No option in a region is a variant of another or a strict upgrade of one. Where an option sits close to a class elsewhere, the row says how it differs.

---

## 0. At a glance

| Region | Options here | ★ Pick |
|---|---|---|
| Fighter N (start) | 6: Halberdier, Squire (NEW); Warden of Chains, Linebreaker (MOVED); Armsbearer, Drillmaster (CARRIED) | **Warden of Chains** |
| Fighter Mercy+Freedom quad | 4: Freeshield, Rallier (NEW); Bladebreaker (REWORK, MOVED); Wayguard (CARRIED) | **Bladebreaker** |
| Fighter Mercy+Order corner | 6: Truce-keeper, Subduer (NEW); Vowkeeper (REWORK); Aegisbearer (CARRIED); Lightsworn, Lantern-bearer (MOVED) | **Vowkeeper** |
| Fighter Cruelty+Freedom TWIST | 4: Ravager, Spiteguard (NEW); Hollowsworn A, Hollowsworn B (REWORK) | **Hollowsworn A (Deathless)** |
| Rogue N | 7: Fence, Slinger (NEW); Vaultrunner, Snareshot (REWORK); Chancer (CARRIED); Saboteur, Locksmith (MOVED) | **Vaultrunner** |
| Rogue Mercy+Freedom quad | 3: Charmer, Luckbringer (NEW); Duelist (REWORK) | **Duelist (Riposte as a counter)** |
| Rogue Mercy+Order quad | 5: Informant, Cloakbearer (NEW); Nightwatch (REWORK); Veilwright (CARRIED); Locksmith (MOVED) | **Locksmith** |
| Rogue Mercy+Freedom corner | 4: Featherstep, Masquer (NEW); Wispdancer A, Wispdancer B (REWORK) | **Wispdancer A** |
| Mage Cruelty+Order TWIST | 3: Enshriner, Unwriter, Siphonist (all NEW) | **Enshriner** |

That gives 19 new options and 10 reworks across the 9 open regions. Sections 2 to 9 cover the reworks in approved regions, the homes, the overlap, the pick-ones, Gravecaller, ranged physical, the unvoted options and names.

---

## 1. The 9 OPEN regions

### Fighter: N (start region, 0 steps; most Fighters land here)
This region needs a simple, readable class, since it's what a Fighter usually becomes.

| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Warden of Chains** (MOVED; approved in round 1) | Locks the enemy line in place (Def/Atk) | Hits the front foe and stuns it and the foe behind it. | Front | Stops swaps and Hold the Door; holds a Berserker or Assassin for your hitters | Tactics Ogre's Terror Knight lockdown |
| **Halberdier** (NEW) | Reach: the polearm that finds the second rank (Atk/HP) | Hits the front foe and the foe behind it in the same row. | Front | Softens Choir and Lumari Chorus without moving them; Crescent's Atk bonus; Keystone's Flank on the same row | The Pierce attacks of Unicorn Overlord's spear units; FFT Lancer |
| **Squire** (NEW) | Takes the blows so the casters can cast (HP/Def) | For a few seconds, every hit it takes also gives charge to the ally behind it. | Front, with a back ally in its row | Lamplight, Hearth, Lighthouse post; feeds Archmage, Cleric, Warlock | FFT Squire; FE Pair Up support |
| **Linebreaker** (MOVED: Spymaster's idea, Fighter flavour) | Crashes through the enemy's ranks (Atk/HP) | Hits the front foe; the foes' formation behaviour stops for a few seconds (their stat bonus stays). | Front | Answers Keeper's Ring, Hold the Door, Opening Volley, Shardpoint | Spymaster (round 1) + Unicorn Overlord's formation-breaking charges |
| **Armsbearer** (CARRIED) | Reads the foe and picks the right weapon (Atk/Def) | Hits the front foe; stuns it if it's a caster, saps its Atk if it's a brawler. | Front | Fits any party; punishes Lighthouse posts | Octopath II Armsmaster |
| **Drillmaster** (CARRIED) | Keeps the line in step (HP/Spd) | Hits the front foe and pushes each edge-adjacent ally's gauge forward. | Front | Seawall, Tidebreak tempo | FFT Squire's Yell |

★ **Warden of Chains:** it's already approved and needs a spot ("possibly used to fill another spot"), and "hit and stun two" reads instantly. One caution: it puts a stun on the most common Fighter, so it's a natural place for the ruling-5 stun playtest. If that worries you, **Halberdier** is the stun-free pick.
*Squire vs Kindred:* Kindred gives charge to the partner on melee hits only, while the formation holds. Squire is a class ability: any hit, for a short window, to the ally behind it.

### Fighter: Mercy+Freedom quadrant (3 steps)
| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Bladebreaker** (REWORK, MOVED from the approved M+F twist) | The blade that ends fights without killing (HP/Def, low Atk) | Disarms the strongest front foe: for a few seconds it can't make basic attacks, though it still gains charge when hit. | Front | Neuters Berserker, Assassin, Duelist; pairs with Confessor and Runebinder for a full shutdown | FFT Knight's Rend Weapon; your note |
| **Freeshield** (NEW) | Throws its own guard to whoever needs it (HP/Spd) | Gives its Def to the most hurt ally for a few seconds and fights without it. | Front | Pairs with a healer to survive its open window; glass Archmage, Duelist | FFXIV Paladin's Intervention |
| **Rallier** (NEW) | A shout that lifts the ones about to break (HP/Atk) | Hits the front foe; every ally below half HP gains Spd for a few seconds. | Front | Rekindler (revived allies return hurt), Wickburner, Tithekeeper; late-fight comebacks | Fire Emblem's Rally skills |
| **Wayguard** (CARRIED) | Free-ranging rescuer (HP/Spd) | Swaps places with the most hurt ally and gives it a shield. | Front ↔ anywhere | Vault Door, Echo Step | FE Rescue |

**Bladebreaker rework (your note: "disarm for a few seconds, which prevents auto attacks, which would also lower their charge amount, but would still gain charge from damage").** A disarmed unit skips its basic attacks, so it builds no charge from acting, but it still charges from the damage it takes. If its bar fills anyway, it can still use its ability: only the weapon is gone. Its region (the M+F twist) is already filled by the approved Echoblade, so I propose this quadrant as its home. Disarming instead of killing is mercy, and breaking the rules of a duel is freedom. If you'd rather keep it as Echoblade's alternative in the twist, the ability text stays the same.
★ **Bladebreaker:** you've already designed this version, and it gives a "maybe" a home where it fits the theme better.

### Fighter: Mercy+Order corner (3 steps; strong lean)
| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Vowkeeper** (REWORK) | Bodyguard sworn to the ally behind it (HP/Def, low Atk) | Takes the ranged and magic hits aimed at the ally behind it, for a few seconds. | Front, with a back ally in its row | Lamplight, Vault Door; keeps an Archmage or Cleric alive; answers ranged physical (section 7) | FFV Knight's Cover |
| **Truce-keeper** (NEW) | Ends the fight for two (HP/Def) | Calls a truce with the strongest front foe: for a few seconds, neither of them can attack. | Front | Benches a Berserker while your back line works; Strays partners | FFT Orator's talk skills; Triangle Strategy's persuasion |
| **Subduer** (NEW) | Arrests, never executes (Atk/Def) | Hits the front foe hard, but never below 1 HP; a foe left at 1 HP is stunned. | Front | Assassin and Necromancer finish what it leaves; Gravecaller's mark | Fire Emblem capture; the "leave it at 1 HP" move (False Swipe) |
| **Aegisbearer** (CARRIED) | The unbreakable post (HP/Def) | Gains a large shield, and every foe's melee hits it while the shield holds. | Front | Lighthouse post, Keeper's Ring | BDII Bastion |
| **Lightsworn** (MOVED, if it loses the M+O quad pick; section 5) | Oath-bound guardian of the weakest (HP/Def) | Hits the front foe and gives the lowest-HP ally a shield. | Front | Glass casters | FFV Knight |
| **Lantern-bearer** (MOVED from Healer; section 3) | Carries the town's light at the front (HP/Spd) | Raises the lantern: every ally gains a burst of charge. | Front | Duelist, Archmage, Shardpoint; ability-heavy parties | BDII Bard BP songs; the Keeper's lantern |

**Vowkeeper rework (your note: "Needs ability text simplified").** It was "for a few seconds, ranged and magic hits aimed at the back ally in its row land on it instead." The new text is one clause: *Takes the ranged and magic hits aimed at the ally behind it.* The 20-character label is **"Guards back ally"**.
★ **Vowkeeper:** it's the only Fighter that guards against magic and ranged, and that matters more if ranged physical gets stronger (section 7). Lightsworn and Lantern-bearer are here only if you move them.

### Fighter: Cruelty+Freedom corner (5 steps; TWIST)
A twist bends the Fighter's essence, which is to stand, endure and guard the line.

| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Hollowsworn A, "Deathless"** (REWORK) | Endurance pushed past death (HP/Atk) | For a few seconds it can't fall; when that ends, it strikes the front foe for all the damage it took. | Front | Draws fire on purpose (Hearth post, Shardpoint tip); Threadmender links feed it damage; Rekindler as backup | FFXIV Dark Knight's Living Dead |
| **Hollowsworn B, "Unburied"** (REWORK) | Falls, and gets back up anyway (HP/Atk) | Swears a hollow oath: the next time it would fall, it fights on for a few seconds, can't be healed, then falls for good. | Front | Hold the Door; trades with the Assassin's burst | Undead knight archetype (Tactics Ogre's undead) |
| **Ravager** (NEW) | The guard who stopped caring who stands beside it (Atk/HP) | Hits every foe in the front column, and every ally next to it, hard. | Front, alone | The reason to play Strays (no neighbours, no friendly fire); Keeper's Ring is a bad home | FF Berserk/Confuse friendly fire |
| **Spiteguard** (NEW) | Its pain is contagious (HP/Def) | Binds itself to the strongest foe: for a few seconds, every hit it takes also hurts that foe. | Front | Seawall's Share the Blow and Tidebreak's Brace (it is hit more); Lighthouse post | FFTA Defender's damage-return counters |

**Hollowsworn rework (your note: "I like the general concept, might need to work with it some").** Round 1 had "can't drop below 1 HP and hits harder; then loses half its HP," which had two moving parts and a hidden cost. **A** keeps the "won't fall" window and turns the damage it soaked into one visible payoff blow. **B** keeps the fantasy of a body that won't stay down, as a one-time delayed fall. Both follow ruling 4. A unit at 1 HP stands and wins. It gains no charge while its own effect is active. The window is short and ends on its own, so nothing goes infinite in the Fading.
★ **Hollowsworn A:** it's the concept you liked, with one cause and one visible effect, and it twists "endure for the line" into "endure to punish".
*Spiteguard vs Threadmender:* Threadmender shares damage between two allies. Spiteguard copies its own pain onto a foe.

### Rogue: N (1 step)
| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Vaultrunner** (REWORK: ranged) | Scout who calls the target (Spd, low Atk) | Throws a marking knife at the weakest foe: it takes a hit, and allies deal more damage to it for a few seconds. | Back (ranged, section 7) | Assassin, Archmage, Nightshade; Choir | Octopath Analyze; FFXIV Mug vulnerability |
| **Snareshot** (REWORK of Trapwright: renamed, ranged) | Strings snares across the field (Spd/Def) | Shoots a snare line across its row: the next foe to attack anyone in that row is stunned. | Back (ranged) | Protects its row partner; punishes melee into Kindred; Warden of Chains | Triangle Strategy's Jens (traps) |
| **Fence** (NEW) | Moves stolen goods to friends (Spd) | Steals the best buff from a foe (shield, haste or regen) and gives it to an ally. | Front | Counters Lumenward, Lampwright and haste parties; feeds your carry | Octopath Thief's Steal; FF Dispel |
| **Slinger** (NEW) | A stone for every caster (Spd/Atk) | Slings a stone at every foe in the back column. | Back (ranged) | Choir, Lumari Chorus, Lighthouse breaker without moving anyone | Unicorn Overlord Hunter; Octopath Hunter |
| **Chancer** (CARRIED) | Lives by the dice (Spd/crit) | Hits a random foe with one random effect: double damage, stun, poison or steal charge. | Front | Wildcard | FFVI Setzer, BDII Gambler |
| **Saboteur** (MOVED: Spymaster reflavoured) | Cuts the ropes that hold the enemy's ranks (Spd) | Sabotages the foes' formation: its behaviour stops for a few seconds (their stat bonus stays). | Front | Same as Linebreaker; choose the Fighter or the Rogue version, not both | Spymaster (round 1); Triangle Strategy's Anna |
| **Locksmith** (MOVED; alternative home) | See the Rogue M+O quad | | | | |

**Vaultrunner rework (your note: "good candidate for ranged weapon").** Round 1 dealt no damage, so it could stand in the back. Now it throws a knife, and its home is the back column under whichever ranged rule you pick in section 7.
**Trapwright rework (your note: "Rename, also could this use a ranged weapon?").** The snare is now fired across the row from a crossbow, so it works from the back. Rename options: **Snareshot** (★), **Tripline**, **Wirejack**.
*Fence vs the rejected Unshackler:* Unshackler cleansed allies and stole a shield. Fence does no cleansing; it only takes one buff and hands it over.
★ **Vaultrunner:** you flagged it for ranged yourself, and focus-fire marking is the clearest neutral Rogue support.

### Rogue: Mercy+Freedom quadrant (2 steps)
| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Duelist** (REWORK; EXISTING class) | Reads the blade and answers it (Spd/Atk) | Riposte: parries the next melee hit on it (no damage) and answers with a critical counter; if no one swings within a few seconds, it lunges at the front foe instead. | Front | Shardpoint tip (draws every melee hit), Crescent crit; Pitfighter-style pulls | FFV/BDII Swordmaster, FFT "Counter" |
| **Charmer** (NEW) | Turns the enemy's arm aside with a smile (Spd) | Charms the foe with the highest Atk: its next attack hits one of its own allies. | Front | Berserker parties (multi-hit charmed = chaos); Fence; disrupts Kindred | FFT Orator's Entice; FF Charm |
| **Luckbringer** (NEW) | Shares its luck with the party (Spd/crit) | Tosses a lucky coin: every ally crits more for a few seconds. | Front or back (no damage of its own) | Crescent, Strays (+5% crit already), Shardpoint tip, Assassin | BDII Performer and Gambler; Unicorn Overlord's crit buffs |

**Duelist rework (your note: "Shouldn't Riposte be a counter-attack?").** Yes. The live version hits and refills charge, which is a chain and not a riposte. This version is one perfect parry and one crit answer, with a lunge fallback so it isn't wasted against magic or all-back parties. *It differs from the rejected Wanderfist*, which countered every melee hit for a few seconds as a tank. The Duelist blocks one hit cleanly and answers it, which is precision, not toughness. The Legendary template (The Last Blade of Veil) still fits.
★ **Duelist:** it's live, it has a Legendary template, and your note fixes its identity.

### Rogue: Mercy+Order quadrant (4 steps)
| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Locksmith** (MOVED; approved in round 1) | A thief who now keeps the Vault's locks (Spd/Mag) | Locks the most charged foe: it gains no charge for a few seconds. | Front | Cutpurse, Runebinder (section 4), Confessor; anti-ability parties | Thief-turned-guard; FF Silence |
| **Nightwatch** (REWORK; "Name is great") | Watches over its friends in the dark (Def/Spd) | Keeps watch: the next foe to hit an ally beside it is struck and stunned. | Front, middle row | Tidebreak, Seawall, Keeper's Ring; Warden of Chains | XCOM Overwatch; FE counters |
| **Informant** (NEW) | Knows where the blow will land (Spd) | Learns the enemy's next move: the ally the next enemy ability will hit gains a shield first. | Back (no damage of its own) | Counters Archmage, Assassin and Warlock burst; Lumenward overheal | Triangle Strategy's Anna (scouting) |
| **Cloakbearer** (NEW) | Hides the ones who can't hide themselves (Spd/Def) | Throws its cloak over the weakest ally: that ally can't be targeted for a moment. | Front | Keeper's Ring (stacks two protected units); saves a glass carry from Assassin | FF Vanish cast on an ally |
| **Veilwright** (CARRIED) | Hides friends in smoke (Spd/Def) | Blinds every foe in the front column for a few seconds. | Front | Counters melee rush | FF Ninja smoke bomb |

**Nightwatch rework.** You liked the name and gave no note on the ability. Round 1's "for a few seconds, strike any foe that hits an adjacent ally" was a timed aura, too close to the rejected Wanderfist's counter stance. The rework fires once, with a stun, so it reads as a guard catching one attacker.
★ **Locksmith:** you said "This ability needs to be in the game! Maybe consider this class for another region/corner". It's one step from the Unseen Warden corner, so the thief-to-enforcer arc is told in neighbouring regions.

### Rogue: Mercy+Freedom corner (4 steps; strong lean)
| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Wispdancer A** (REWORK) | Dances in and out of danger alone (Spd) | Hits the front foe, then hops to the empty slot across its row; if an ally stands there, it stays and dodges the next hit instead. | Front ↔ back | Vault Door (leaves room); Echo Step; draws melee then slips to half physical | Octopath/FFXIV Dancer steps |
| **Wispdancer B** (REWORK) | Dances with a partner, only to rescue (Spd) | Hits the front foe, then trades places with the ally across its row only if that ally is in front and more hurt; otherwise it dodges the next hit. | Front ↔ back | Vault Door, Lamplight; Wayguard-style rescue | Octopath Dancer partner steps |
| **Featherstep** (NEW) | Never there when the blow lands (Spd) | Dodges the next two hits on it; each dodge gives charge to the ally with the least. | Front | Shardpoint tip, Hearth post (draws melee); feeds slow casters | Octopath/BDII evasion lines |
| **Masquer** (NEW) | Wears a friend's face so the foe aims wrong (Spd/HP) | Disguises itself as the weakest ally: for a few seconds, attacks aimed at that ally hit the Masquer instead. | Front | Protects any glass carry from any attack type; Lumenward shields on the Masquer | FF Cover, done by disguise |

**Wispdancer rework (your notes: "dancing could be detrimental to other party members ... what happens if there is no hero in the same row? I like the general idea").** Round 1 always swapped with the row ally, so it could push a back caster into melee, and it was undefined when the row was empty. **A** never moves an ally. It moves only into an empty slot, and if the slot is taken it dodges instead, so every case is covered and none of them hurts the party. **B** keeps a partner dance but only allows the helpful swap (a hurt front ally goes to the back, where it takes half physical damage). Both say what happens in every row state.
*Masquer vs Vowkeeper:* Vowkeeper is tied to one row and covers only ranged and magic. Masquer covers the weakest ally anywhere, from every attack type, for a shorter window.
★ **Wispdancer A:** it's the idea you liked, with both of your problems removed and the shortest rule.

### Mage: Cruelty+Order corner (6 steps; TWIST, the Mage's super-rare class)
All three round-1 options (Mirrormind, Hushbinder, Reckoner) were rejected. The Mage's essence is magic drawn from **the memory in things**: it releases power stored in the world. The furthest twist is a Mage that does the opposite, which is what the Lumari did (`01-world-and-lore.md`, True History): it draws, seals or erases memory instead of releasing it. Healer → Gravecaller twists life into death. These twist **release into confinement**.

| Option | Identity | Ability | Column | Synergies | Inspired by |
|---|---|---|---|---|---|
| ★ **Enshriner** (NEW) | Seals the living in crystal, as the Lumari sealed themselves (Mag/Def) | Seals the strongest foe in crystal for a few seconds: it can't act or be hit, and its formation loses it while sealed. | Back | Breaks Keeper's Ring (the front three aren't all standing), Hold the Door, Tidebreak; isolates a carry while you kill its support | The Lumari sealing; FF Petrify/Banish |
| **Unwriter** (NEW) | Magic that makes a foe forget what it became (Mag) | Unwrites a foe's Awakening: for a few seconds it uses its base-class ability instead (a monster uses its basic attack). | Back | Best against Legendaries and twist classes; Locksmith (charge sealed + ability downgraded) | FF Toad/Mini (unmaking a unit's form); the Fading's second rule |
| **Siphonist** (NEW) | Draws the world thin to feed itself (Mag/HP) | Draws Mag out of every foe for a few seconds and adds it all to its own. | Back | Answers Lumari Chorus and Choir; feeds its own next hit; weak into physical parties (a real sidegrade) | FF Osmose; the Lumari "draw" |

*How these avoid round 1's problems.* None of them copies a foe's ability (Mirrormind), silences the whole field including your own side (Hushbinder), or hits both sides (Reckoner). *Enshriner vs stun:* a stunned foe can still be hit. A sealed foe is untouchable but also out of its shape. That's a real trade, since you protect the target while breaking its team. Rule needed: a sealed unit still counts as standing for the fight-end check, so you can't win by sealing the last foe. *Unwriter vs Runebinder/Locksmith:* the foe still charges and still casts, just a weaker spell.
★ **Enshriner:** it's the Lumari's own act (sealing memory in crystal) used on the living, which is the deepest twist of "the memory in things", and it creates a new pattern of breaking shapes by removing a piece. **Unwriter** is the more lore-pure runner-up, since erasing what a hero remembered is exactly the Fading's rule.

---

## 2. Reworks of the other "maybes" (approved regions)
These sit in regions you've already filled, so they're alternates or candidates to move. Notes are quoted.

| Class (region) | Your note | Rework |
|---|---|---|
| **Bladebreaker** (Fighter M+F twist) | "disarm for a few seconds, which prevents auto attacks, which would also lower their charge amount, but would still gain charge from damage" | Done in §1, moved to Fighter M+F quad. |
| **Vowkeeper** (Fighter M+O corner) | "Needs ability text simplified" | Done in §1: *Takes the ranged and magic hits aimed at the ally behind it.* |
| **Duelist** (Rogue M+F quad) | "Shouldn't Riposte be a counter-attack?" | Done in §1. |
| **Bountyhand** (Rogue C+O quad, Assassin approved) | "What happens if his bar fills again and the first mark is still alive? ... the idea of the bounty I like" | *Marks the foe with the highest Atk as its bounty; while the bounty lives, its ability strikes the bounty hard instead of marking again; when the bounty falls, its charge refills and it picks the next.* So a full bar always does something: the first cast marks, later casts hunt. |
| **Wispdancer** (Rogue M+F corner) | harm to allies; empty row | Done in §1 (A and B). |
| **Trapwright** (Rogue N) | "Rename, also could this use a ranged weapon?" | Done in §1 as **Snareshot** (or Tripline, Wirejack). |
| **Vaultrunner** (Rogue N) | "good candidate for ranged weapon" | Done in §1. |
| **Hollowsworn** (Fighter C+F twist) | "I like the general concept, might need to work with it some" | Done in §1 (A and B). |
| **Shackler** (Fighter C+O quad, approved) | "rename" | 3 names: **Hooksman** (★: a polearm hook drags casters forward; it no longer echoes Warden of Chains), **Gaoler** (from the first roster draft), **Dragnet**. |
| **Iron Marshal** (Fighter C+O corner, approved) | "maybe it could be each adjacent" | *Edge-adjacent means only the slots touching its sides (up to 3 allies on the 2×4 grid); "each adjacent" would add the diagonals (up to 5 allies, so more tempo but more HP paid).* |
| **Lanternbearer** (Healer M+O corner) | "This belongs somewhere else" | Homes in §3. |
| **Spymaster** (Rogue C+O corner) | "I like this idea of formation debuff, maybe this belongs somewhere else with a slightly different flavor" | Homes in §3 (Saboteur or Linebreaker). |
| **Bonesetter** (Healer C+O quad) | "cool idea for an ability" | Healer has no open region. Keep the idea for a Legendary ability (Tithekeeper's line), or for a future base-class-6 Legendary. |
| **Nightwatch** (Rogue M+O quad) | "Name is great" | Done in §1. |

**Maybes without a note**, carried unchanged for your vote. In open regions: Armsbearer, Drillmaster, Wayguard, Aegisbearer, Chancer, Veilwright. In approved regions (alternates only): Sunderer, Bloodsworn, Pitfighter, Lampsnuffer, Hearthsinger. One possible move is **Pitfighter** to Fighter N, if you want a taunt there instead of a stun.

---

## 3. Homes for homeless classes

Advanced classes are unique to their base class (`02-heroes-and-classes.md`). Warden of Chains and Locksmith stay in their base class. Lanternbearer has **no open Healer region left**, so a move means giving the idea to another base class (same ability, new body and stats).

| Class | Candidate 1 | Candidate 2 | Note |
|---|---|---|---|
| **Warden of Chains** (Fighter) | ★ **Fighter N** (the start region; a chain-stunner as the default Fighter) | **Fighter M+O corner** ("arrest, don't kill", next to Truce-keeper and Subduer) | In N it competes with Halberdier. In the corner it competes with Vowkeeper. Iron Marshal keeps the C+O corner. |
| **Locksmith** (Rogue) | ★ **Rogue M+O quad** (a thief-turned-guard, next to the Unseen Warden corner) | **Rogue N** (locks as a neutral trade) | Either way, Runebinder changes (§4). |
| **Lanternbearer** (Healer idea) | **Fighter M+O corner** as **Lantern-bearer**: the Fighter who carries the lantern at the front, "every ally gains charge" | **Rogue M+O quad** as a **Lamplighter**: the town's lamplighter who sneaks light to allies (the Keeper is a forgetful old lamplighter) | Both make the lamp-name cluster worse (§9). If moved, rename it **Beaconkeeper** or **Torchbearer**. My lean is the Fighter corner, because a front-line light-carrier fits the Lantern Saint line. |
| **Spymaster** (Rogue; "slightly different flavor") | **Rogue N** as **Saboteur**: cuts the signal ropes, same formation blackout, earthier and neutral rather than an elite spy | **Fighter N** as **Linebreaker**: the same blackout done by force, crashing into the ranks | Pick only one of the two. My lean is Saboteur, because the "formation debuff" idea stays a Rogue trick. |

**What fills each open region if you take my ★ homes:** Fighter N gets Warden of Chains. Rogue M+O quad gets Locksmith. Lanternbearer is an option in the Fighter M+O corner, and Spymaster-as-Saboteur is an option in Rogue N. The other open regions are filled from §1.

---

## 4. Overlap: Runebinder and Locksmith both seal charge

Both currently say "the foe gains no charge for a few seconds".

| Option | Change | Result |
|---|---|---|
| ★ **A. Locksmith keeps the seal; Runebinder becomes a rune-trap** | Runebinder: *Binds the most charged foe in runes: when it next uses its ability, the runes snap and it takes heavy magic damage.* | Locksmith **prevents** the cast, while Runebinder **punishes** it. They combo (lock it, and when the lock lifts the trap fires) instead of stacking the same effect. This also matches your visual note for Runebinder: "a series of runes connecting and binding the hero/monster". |
| **B. Split by timing** | Locksmith: *takes all of the foe's charge and locks it away, giving it back after a few seconds.* Runebinder keeps "gains no charge". | Delay vs stall. The difference is subtle to read, and it changes the ability you said "needs to be in the game". |
| **C. Split by source** | Locksmith stops charge from acting; Runebinder stops charge from being hit. | Precise, but players can't tell the two apart at a glance. |

★ **A:** you asked for Locksmith's ability exactly as written, and the rune-trap gives Runebinder its own pattern and visual.

---

## 5. The two PICK-ONE regions

### Fighter Mercy+Order quad: Paladin vs Lightsworn
| | Paladin (EXISTING) | Lightsworn |
|---|---|---|
| Ability | Hits the front foe and heals the most hurt ally. | Hits the front foe and gives the lowest-HP ally a shield. |
| Timing | After the damage (repairs) | Before the damage (prevents) |
| Already in game | Live, with the Lantern Saint Legendary | Nothing |
| Overlaps | Cleric heals too, but from the back | Lumenward's shields and overheal-shield tweak, and Lampwright's column shields: shields are already well covered |
| If it loses | Lantern Saint needs a new parent (a cost) | Can move to the **Fighter M+O corner** (open), where it competes with Vowkeeper |

**Lean: Paladin.** It's live, has its Legendary, and is the only front-line healer. Lightsworn's shield is the third shield class, so it's the safer one to move or drop.

### Healer Cruelty+Freedom quad: Bloodletter vs Hexmender
| | Bloodletter | Hexmender |
|---|---|---|
| Ability | Hits every foe lightly and heals all allies from the damage. | For a few seconds, healing on the target foe hurts it instead. |
| Your note | "might be too strong" | "tough decision for this quadrant" |
| Works into | Every party (always useful) | Only parties that heal (Cleric, Paladin, Wickburner, monsters with Mend); does little otherwise |
| Overlaps | Necromancer drains too, but one target and self only | **Confessor** (approved) already blocks foe healing, and Hexmender is the stronger form of the same counter |
| Power risk | Area drain scales with the number of foes. Tune it lightly; it's not a design flaw | Swingy: a hard counter in PvP, inert against monsters |
| If it loses | No open Healer region | No open Healer region. Optionally **merge it into Confessor**, which you said "should be flame related": *Hits a foe with cleansing fire; for a few seconds its heals burn it instead.* |

**Lean: Bloodletter, with its drain tuned down.** Hexmender's idea isn't lost if it folds into the flame Confessor, which keeps one anti-heal class instead of two.

---

## 6. Gravecaller when no one has fallen yet (ruling 7)

| Option | Ability when no one has fallen | Pros | Cons |
|---|---|---|---|
| ★ **A. Mark for the grave** | Marks the weakest foe: if it falls within a few seconds, it rises at once on Gravecaller's side as a husk. | Always does something, it's the same fantasy (a claim on the dying), and it combos with Assassin, Subduer and Nightshade | A mark that expires unused does nothing |
| **B. Nameless husk** | Raises a weak husk of the Vault's long-dead into an empty front slot (weaker than any raised hero). | Simple; gives back-heavy parties an early front line | Close to Echoblade (fills a front slot), and needs an empty front slot |
| **C. Hold the grave open** | Keeps its charge full and casts the instant anyone falls; until then it only basic attacks. | No new effect needed | Can do nothing for a whole fight; feels bad against tanky parties |

★ **A:** it keeps Gravecaller about death rather than summoning, and it's never idle when it has a foe to mark.

---

## 7. Back row: ranged physical attacks (ruling 2)

**Today:** `03-runs-and-combat.md`: "Heroes in the back column deal and take half physical damage. Magic is unaffected." In code (`combat_sim.gd` `_damage`), every physical hit is ×0.5 if the attacker is in back and ×0.5 if the target is in back, so back-to-back is ×0.25. BUILD.md lists this as a spec non-negotiable, so whichever option you choose must also be written into BUILD.md and 03.

Your question: "what about ranged physical attacks? they should also be hitting for more damage".

All three options add one tag, **ranged**, to physical abilities and basic attacks from a bow, sling, crossbow or thrown knife. Melee stays exactly as it is. Ranged hits already count as "ranged" for the Lamplight guardian, the Lighthouse post and Vowkeeper, so those counters keep working.

| Option | Rule | Pros | Cons |
|---|---|---|---|
| **1. Bows belong in back** | Ranged physical ignores the **attacker's** back-column halving. The target's halving stays. | Smallest change (skip one multiplier); answers your question directly | The back becomes strictly better for ranged classes (safe *and* full damage), so there's no placement decision |
| ★ **2. Each weapon has its column** | Ranged physical is halved when fired from the **front** column instead of the back. Target halving stays. Melee is unchanged. | A clean mirror (swords want the front, bows the back); keeps a placement decision; Shackler/Hooksman, Hold the Door and Wispdancer pulling an archer forward become a real cost | Two rules to learn (one icon each: a sword and a bow on the column) |
| **3. Ranged ignores columns, at a cost** | Ranged physical ignores **both** column rules but has lower power (about ¾) wherever it stands. | One flat rule, the same everywhere; archers become casters' natural counter | Removes placement for archers, and back-heavy shapes (Choir, Lumari Chorus) lose their physical safety to ranged |

★ **Option 2:** it gives ranged attackers full damage from the back, as you asked, without making the back strictly better, so it keeps column choice as a decision (horizontal, not vertical).

**Classes that would use it:** Vaultrunner, Snareshot and Slinger (Rogue N), and future monsters such as Vault archers. No Fighter needs it, since Halberdier's reach is melee. Base classes stay generic, so this isn't a new Archer base class. A ranged base class could be a later idea.

---

## 8. The 8 unvoted round-1 options

| Option | Base / region | Ability (round 1) | Could fill an open region? |
|---|---|---|---|
| **Banneret** | Fighter M+O quad (PICK ONE) | For a few seconds, the party's formation bonus counts double. | **Yes: Fighter M+O corner** (order taken to its extreme), or Fighter N |
| **Salvewright** | Healer N (Threadmender approved) | Clears every status from the most afflicted ally and heals it. | No: Healer has no open region. Note that the game still has **no cleanse** among the approved classes, so it's the best Healer alternate if you ever reopen a region |
| **Hearthwitch** | Healer M+F corner (Wickburner approved) | Heals every ally in whichever column has lost the most HP. | No |
| **Embalmer** | Healer C+O corner (Confessor approved) | For a few seconds, the weakest ally can't drop below 1 HP but can't act. | No (and close to Hollowsworn A's "can't fall" window) |
| **Mirage Weaver** | Mage M+F quad (Stormwake approved) | Hits the front foe and blinds every foe in its row. | No: the only open Mage region is the twist, and this isn't a twist |
| **Glyphwright** | Mage N (Archmage approved) | Marks the foes' most crowded row; after a few seconds, a rune bursts on every unit in it. | No. If you take Runebinder option A (§4), the two rune ideas are near each other, so choose one |
| **Stonereader** | Mage N (Archmage approved) | Row 1 slows a foe, row 2 burns, row 3 shields an ally, row 4 stuns. | No (strong idea; a candidate for a Legendary or a future base class) |
| **Ashcaller** | Mage C+F quad (Warlock approved) | Hits every foe in the front column and poisons them. | No |

---

## 9. Name overlaps (rejected names skipped)

| Overlap | Why it matters | Fix options |
|---|---|---|
| **Wickburner** (Healer) vs **The Mother of Wicks** (Cleric's Legendary) | Same base class, same word: players may assume one leads to the other | (a) Rename Wickburner to **Tallowheart** or **Emberheart**. (b) Make it a feature by moving The Mother of Wicks to Wickburner (a candle-burning saint fits it better than Cleric does), and give Cleric a new legend |
| **Lanternbearer** vs **Lantern Saint** (+ Lampwright, Lumenward, Lightsworn, Lampsnuffer) | The lamp/light cluster gets crowded, especially if Lanternbearer moves to the Fighter M+O corner beside Paladin → Lantern Saint | Rename to **Beaconkeeper** or **Torchbearer**. Keep "Lantern" for Lanternrest and the Saint |
| **Warden of Chains** (Fighter) vs **Unseen Warden** (Rogue) | Two "Wardens", both control classes | My lean: leave both, since they're different bases. If it bothers you, rename Warden of Chains to **Gaolmaster** (keep Unseen Warden, which is your idea) |
| **Shackler** vs **Warden of Chains** | Both chain-themed in neighbouring Fighter regions | Rename Shackler to **Hooksman** (§2) |
| **Nightwatch** vs **Nightshade** | Both Rogue, both "Night-" | You like the name Nightwatch, so if it's picked, consider renaming Nightshade to **Venomist** (the first draft's name) |
| **Wispdancer** vs the **Fading Wisp** monster | Players may read the class as Fading-aligned | Minor. Rename to **Mistdancer** if you like |
| **Hollowsworn** vs the **Hollow Rat** monster | Minor | Leave it, or use **Deathless** as the class name if you pick Hollowsworn A |
| **Runebinder** vs **The Debt-Binder** (Warlock's Legendary) | Minor; different bases | Leave it |
| New names this round | Checked against every approved class, Legendary template, formation, monster and item in `game/core/data/` | Truce-keeper was "Peacewarden" (renamed to avoid a third Warden); Subduer and Ravager avoid a third and fourth "-blade" |

---

## Mechanics the new options would need
Most reuse round 1's list (timed statuses, gauge op, swaps, reactive triggers, summons). New this round:
- **No-basic-attack status** (Bladebreaker disarm), **truce pair** (Truce-keeper), **HP floor on its own hits** (Subduer).
- **Damage mirror to a bound foe** (Spiteguard), **stored-damage strike** (Hollowsworn A), **delayed fall** (Hollowsworn B), **friendly-fire area** (Ravager).
- **Buff steal-and-give** (Fence), **redirect to self by disguise** (Masquer), **dodge counters** (Featherstep), **ally hidden** (Cloakbearer, reusing `_ring_protected`), **next-ability target preview** (Informant; the sim is deterministic, so it can be computed).
- **Seal out of play** (Enshriner: untargetable and out of shape, but still counts as standing), **base-ability swap** (Unwriter), **stat draw over time** (Siphonist).
- **Ranged tag** on physical effects plus the column rule from §7.
- **Rune-trap on next cast** (Runebinder option A), **grave mark** (Gravecaller option A).
