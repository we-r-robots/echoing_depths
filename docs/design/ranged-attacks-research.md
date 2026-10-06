# Ranged Physical Attacks: Research and Rule Options (for user review)
*Research draft, 2026-10-06. Nothing here is approved or built. It answers ruling q-4 in `class-verdicts-round2.md`. All amounts are balance, not spec, and are left to tuning.*

**Your ask (q-4):** "Archers should be better in the back, and worse in the front, and they should do full damage everywhere, but may need their damage adjusted accordingly. Open to explore more ideas, research how similar games accomplish this."

**How this doc reads "full damage everywhere":** the **target's** column must not cut a ranged hit, so a back-row foe is a real target for an archer and not a ×0.5 waste. Proposal 2 also covers the stricter reading, where the archer's own column doesn't cut its damage either.

**Today's rule** (`03-runs-and-combat.md`; BUILD.md "Spec non-negotiables"; `combat_sim.gd` `_damage`; `tuning.gd` `back_row_phys_mult = 0.5`): a physical hit is ×0.5 when the attacker stands in back and ×0.5 again when the target stands in back. Magic ignores columns. Under this rule, an archer in back hits a back foe for a quarter of its damage. The rule fails all three of your wants.

**Contents**
1. How shipped games do it (rule, effect on placement, known balance problems)
2. What the research says, in six lessons
3. Four rule sets for Echoing Depths, with worked numbers (★ is Proposal 1)
4. Interactions: counters, formations, approved classes, the Fading
5. Ideas not proposed, and why
6. If a proposal is approved: what changes

---

## 1. How shipped games handle position and range

### Final Fantasy row systems (FF2 to FF9)
| Game | Exact rule | What it does to placement | Known problems |
|---|---|---|---|
| **FF1** | No rows. Party order sets how often enemies target each hero: slot 1 is targeted 50% of the time, slot 2 25%, slots 3 and 4 12.5% each [S1]. | Tank first, casters last. Order is the whole positional game. | None as such, but it's one-dimensional: once you sort the order, the choice is made. |
| **FF2** | Two rows. Enemy physical attacks can't reach the back row while anyone stands in front; bows and spells can [S2]. In the back row, melee weapons deal and take half damage; bows and magic are full [S3]. | Bow users and casters go in back; melee goes in front. | A melee hero in back is close to useless, so the "choice" is really fixed by weapon. |
| **FF3** | Back row deals and takes half physical damage. Bows hit for full damage from the back, as does black magic [S4]. | Rangers and mages in back. | Bows are two-handed and arrows are consumable, so FF3 balanced the free back-row damage with a weapon cost [S4]. |
| **FF4** | Two rows of up to three (a 2-3 or 3-2 shape for the whole party) [S5]. Per the engine research wiki, the penalty is to **accuracy**, not damage: attacking from the back halves accuracy, attacking a back target halves it again (¼ combined), and back-row physical defense is doubled. Harps, whips, bows, the Boomerang/Full Moon and the Dwarf Axe set a "backrow bit" that removes the penalty [S6]. | Rosa (bow) and Rydia (whip) live in back. The party shape is a whole-party toggle, not per hero. | A known "backrow glitch" can leave the bit set permanently, removing the penalty forever [S6]. Accuracy penalties add miss RNG. |
| **FF5** | Back row deals and takes half physical damage. Bows ignore the damage reduction [S7]. Bows, whips, Rising Sun and Thor's Hammer share the "Aerial" category [S7]. | Hunters, and anyone with a bow or whip, go in back for free safety. | The long-range weapons get a strictly better deal: full damage and half damage taken. |
| **FF6** | Short-range physical attacks deal half from the back row. Boomerangs (Rising Sun, Moonring Blade), Setzer's cards, Hawkeye-type throwing weapons and bells deal full power. Magic and most commands (Blitz, Bushido, Tools) ignore rows [S8][S9]. | Ranged and command users sit in back for free. | Most damage in FF6 isn't the Fight command, so the row rule mainly works as free defense for the back row. Item descriptions are wrong in places: the Rune Chime claims full back-row power but doesn't have it [S8]. |
| **FF7** (context) | Back row deals and takes less from short-range attacks. Long-range weapons (Barret's guns, Yuffie, Vincent) are exempt. The **Long Range** materia gives any hero the exemption [S10]. | Long-range heroes always go in back. With the materia, so does everyone else. | Long Range makes the back row strictly better, so the row choice disappears for the whole party. |
| **FF9** | Back row reduces the damage taken from, and dealt by, short-range attacks. Long-range weapons (all rackets, plus others) get no reduction while keeping the defensive benefit [S11][S12]. | The guide's own advice: "Always keep ranged weapon users in the back row" [S11]. | The same as FF5 and FF7: for ranged heroes, the back is free safety. |

**The pattern:** every mainline FF exempts the **attacker's** penalty for long-range weapons. That's your round-2 Option 1. Every one of them also ends up with "always put the archer in back", because the back costs the archer nothing. FF3 is the only one that charges a price for it (two-handed weapon, consumable ammo).

### Tactics games
| Game | Exact rule | What it does to placement | Known problems |
|---|---|---|---|
| **Final Fantasy Tactics** | No rows. Bows reach 3 to 5 tiles horizontally, +1 for every 2 height levels above the target. They fire in an arc over obstacles. Crossbows (Bowgun range 4) fire in a straight line [S13]. Damage doesn't change with distance. | High ground for archers. The choice between arc and line of fire comes down to the map. | Range plus height lets archers threaten most of the map. The cost is low damage, not a positional penalty. |
| **Tactics Ogre (SNES to Reborn)** | Bows can shoot past their listed range, and altitude adds range [S14]. | Archers want high ground and shoot casters and healers in the enemy backline [S14]. | Archers were "overpowered" in the SNES version, nerfed in the PSP remake, and are "humbler" in Reborn [S14]. This is the clearest case of a ranged-everywhere, full-damage attacker becoming dominant, followed by years of nerfs. |
| **Unicorn Overlord** | Front and rear rows in a 3×2 unit grid. **Row doesn't change damage.** It changes **reach**: an attack without range can't target the rear row while anyone stands in front. Bow, magick and piercing skills, and fliers (Gryphon Knight, Feathersword), can hit the rear row directly [S15][S16]. | Tanks in front; archers and mages in rear, where melee can't reach them [S17]. An archer in front is just exposed. | Balance runs through counter triangles, not row multipliers: fliers halve ground melee hit rate but take double damage from archers [S17]. Rows matter mainly through reach and through skill conditions. |
| **Darkest Dungeon (1 & 2)** | Four ranks. **Each skill states the ranks it can be used from and the ranks it can hit.** For example, the Arbalest's Sniper Shot is used from ranks 3–4 and hits ranks 1–3. Nearly all her skills need ranks 3–4 [S18]. DD2 does the same (Bounty Hunter's Flashbang from 2–4, Collect Bounty from 1–3) [S19]. | Every hero has a home rank. Building a party is fitting rank footprints together. | Being moved out of rank ("shuffle") turns rank-locked heroes into dead turns. Community advice is to avoid the Arbalest and Leper in shuffle fights [S20]. Heroes with skills for every rank (Highwayman) are valued for it [S20]. Position disruption is the counterplay, and it is harsh. |

### Turn-based JRPGs with a party "back"
| Game | Exact rule | What it does to placement | Known problems |
|---|---|---|---|
| **Octopath Traveler I / II** | **No row system.** II fights with four active heroes [S21]. (Your brief listed II; the front/back pairs belong to *Octopath Traveler 0*.) | n/a | n/a |
| **Octopath Traveler 0** (2025) | 8 heroes in four front/back pairs. **Only the front row acts.** The back row can't attack, but it gains BP, triggers passives and regenerates HP/SP. Swapping a pair is free [S21][S22]. Some skills gain a bonus if the hero started the turn in back and swapped forward [S22]. | The back is a bench. Position is a rotation and timing choice. | It doesn't map to ranged weapons. The useful idea is "stored up in back, released when you step forward". |
| **Bravely Default / Second / II** | No front/back row in the guides checked. The positional layer is replaced by Brave/Default: Default guards (less damage taken) and banks a turn [S23]. | n/a | n/a |
| **Persona / SMT** | *Revelations: Persona* used a placement grid where position constrained who could act on whom. *Persona 2: Eternal Punishment* removed the grid, so that placement no longer restricted actions [S24]. Later Persona and SMT games have no rows. Guns are a separate command, not a row exemption. | P1: weapon reach decides placement. | Atlus dropped the grid as cumbersome, which is a warning about rule weight. |
| **Legend of Mana** | Real-time action. The bow has the longest range of any starting weapon and can stun-lock enemies before they close in [S25]. | Stay far away. | Widely called the best starting weapon [S25]: range, safety and full damage together dominate. |

### Auto-battlers and mobile
| Game | Exact rule | What it does to placement | Known problems |
|---|---|---|---|
| **TFT** | No damage modifier by position. Range is counted in hexes. Melee units must walk to targets, and that walk is the backline's protection [S26]. | Ranged carry in a back corner. A corner is reachable from only two directions, and the tanks plus the map edge do the defending [S26]. | The corner carry is the default for every board, so Riot answers with **targeted counters** instead of damage rules: assassins jump to the backline, and **Zephyr** banishes whichever enemy stands in the hex mirroring its holder [S27]. Placement turns into reading the counters. |
| **Hearthstone Battlegrounds** | One line. Leftmost minion attacks first, attacks pick random enemies, and Taunt must be attacked first [S28]. Cleave hits neighbours. Some minions snipe (e.g. Zapp Slywick attacks the lowest-Attack enemy) [S28]. | Highest attack on the left, cleave units not first, the carry in slot 2 to dodge Zapp [S28]. | Ordering is mostly solved by a sort rule. Interest comes from **abilities that read position**, not from a positional damage rule. |
| **Super Auto Pets** | One line. The front pet fights first. Many abilities read neighbours ("friend ahead attacks", "friend behind") [S29]. **Snipers** deal damage to positions outside the melee exchange: Snake hits a random enemy when the friend ahead attacks, Dolphin hits the lowest-HP enemy, Hedgehog hits all [S29]. | The order is set by triggers: who must be behind whom. | Position matters through triggers. Snipe damage ignores position entirely, and SAP balances it by keeping per-shot damage small. |
| **AFK Arena / AFK Journey** | Fixed slots: 2 front and 3 back in AFK Arena [S30]. No damage modifier by slot. The position decides who gets hit first. | Tanks in front; marksmen, mages and healers in back, because "anyone with range will have low health" [S30][S31]. | Backline safety is answered by heroes and skills that dive or target the back row, the same counter-tool pattern as TFT. |
| **Summoners War** | Turn order runs on an Attack Bar filled by Attack Speed [S32]. In the main game, positional protection comes from skills (Taunt, Defend, Protect), not from a grid. *(From general knowledge; the snippets found didn't settle whether any mode adds rows.)* | n/a | Speed tuning becomes the whole game. Position is a non-factor. |

---

## 2. What the research says, in six lessons

1. **The FF exemption makes the back strictly better.** FF3 to FF9 all exempt the attacker's back-row penalty for bows, and each one turns into "always put the archer in back" [S11]. FF7's Long Range materia spread that to everyone [S10]. If the archer gives nothing up in back, placement is no longer a decision.
2. **Shipped games charge a price for full damage from safety.** FF3 used two-handed bows and consumable ammo [S4]. FFT keeps bow damage low. Tactics Ogre nerfed archers over two remakes [S14]. Super Auto Pets keeps snipe damage small [S29]. The common lever is **lower base power**, which matches your "may need their damage adjusted".
3. **Reach is a lever as strong as damage.** Unicorn Overlord uses no row damage multipliers at all. Row decides who *can* be targeted [S15][S16]. Darkest Dungeon makes the attacker's own rank decide *which skill exists* [S18].
4. **Ranged safety needs a targeted counter, not a blanket rule.** TFT has assassins and Zephyr [S27], Unicorn Overlord has fliers and piercing [S16], Darkest Dungeon has shuffle [S20]. Echoing Depths already has several (Lamplight guardian, Lighthouse post, Warden of Chains' drag), and Vowkeeper is a proposal.
5. **Position should read in one glance.** Atlus dropped Persona's grid [S24], and FF4 hid a hard rule behind an accuracy roll [S6]. Rules that read well show up as a visible tag on the hit.
6. **Free safety plus full damage at range dominates.** Legend of Mana's bow [S25] and SNES Tactics Ogre archers [S14] are the warnings.

---

## 3. Rule sets for Echoing Depths

### What stays the same in every proposal
- Add one tag, **ranged**, for physical hits from a bow, sling, crossbow or thrown knife. Magic and status damage are unchanged.
- **Melee is unchanged:** ×0.5 if the attacker is in back, ×0.5 if the target is in back.
- **Dashes stay melee.** Backstab and Execute travel to their target, so they keep the melee rule. This keeps "ranged" meaning projectiles only.
- **Targeting:** I suggest the archer's basic shot aims at **its own row (nearest occupied row), back column first**. The defender can then see where the shot will land and answer it with a same-row guard: the Lamplight guardian, Vowkeeper, or Hearth/Lighthouse shapes. Abilities can still pick their own targets.

### Worked-number setup
Damage is `power × 1.8 × A² / (A + D)` (`damage_scale` 1.8). Every hit below lands on the same reference dummy (Def 12, Mag 12), so the stats cancel out and only the column rules differ. No crits, no variance.
- **Fighter**, Strike (power 1.0, Atk 18): **19.4** at ×1.
- **Mage**, Bolt (magic, power 0.8, Mag 20): **18.0** everywhere.
- **Archer**, a hypothetical Rogue-line Shot (Atk 19, raw 20.96 per power point): power 0.9 gives 18.9, 0.85 gives 17.8, 0.8 gives 16.8.

**Melee and magic today, the same in every proposal:**

| Attacker → target column | Back→Front | Back→Back | Front→Front | Front→Back |
|---|---|---|---|---|
| Fighter (melee) | 9.7 | 4.9 | 19.4 | 9.7 (only once the front column is empty) |
| Mage (magic) | 18.0 | 18.0 | 18.0 | 18.0 |
| *Archer, Shot 0.9, under today's rule* | *9.4* | *4.7* | *18.9* | *9.4* |

The italic row is the problem: today an archer is a worse Fighter.

---

### ★ Proposal 1: "Swords to the front, bows to the back" (the mirror)
**Rule:** a ranged hit **ignores the target's column**. Fired from the **back** column it deals full damage. Fired from the **front** column it deals ×`ranged_front_mult` (start at 0.5). Ranged power is set lower than melee (Shot about 0.8).

| Proposal 1 | Back→Front | Back→Back | Front→Front | Front→Back |
|---|---|---|---|---|
| **Archer** (Shot 0.8) | **16.8** | **16.8** | 8.4 | 8.4 |
| Fighter (melee) | 9.7 | 4.9 | 19.4 | 9.7 (front empty) |
| Mage (magic) | 18.0 | 18.0 | 18.0 | 18.0 |

- **Your three wants:** (1) better in back: yes, full damage, and it takes half from physical hits. (2) Worse in front: yes, half damage, and it takes full. (3) Full damage everywhere: yes, the target's column never matters.
- **Placement decision:** this is the exact mirror of melee. Each weapon has one good column, so the decision moves to the party: back slots are contested by archers, mages and healers. A party that sends everyone back loses its front wall (Lumari Chorus already pays "no front line"). Archers end up in front only when a shape needs them there (Seawall, Tidebreak, Kindred) or when a foe puts them there. That's a real cost, not a dead option. (A Mage already has no reason to stand in front, so this is consistent.)
- **Horizontal check:** a back archer (16.8) is a sidegrade to a Mage (18.0), not an upgrade. It hits Def instead of Mag, so it hunts low-Def casters: 20.0 against a Mage's Def 7, 15.8 against a Fighter-tank's Def 14. It is also weaker per hit than a front Fighter (19.4) in exchange for safety and reach. That's the price lesson 2 says to charge.
- **Tuning knobs:** Shot/ability `power` (main), `ranged_front_mult` (how much worse the front is: 0.5 is a strict mirror, 0.75 is gentler).
- **Player-facing rule (one icon per weapon: a sword on the front column, a bow on the back column):** *"Swords hit full from the front, bows hit full from the back, each deals half from the wrong column, and bows hit any column at full."*
- **Cost in code:** about six lines in `_damage` plus the tag. A new `ranged_front` mod reuses the existing `back_row_attacker` annotation path, so the ▼ shows on the hit.

---

### Proposal 2: "Point-blank" (front archers lose reach, not damage)
**Rule:** a ranged hit deals **full damage everywhere** and ignores both columns. But fired from the **front** column it **targets like melee**: front column only, same or nearest row, and the back column only once the front is empty. Ranged power about 0.8.

| Proposal 2 | Back→Front | Back→Back | Front→Front | Front→Back |
|---|---|---|---|---|
| **Archer** (Shot 0.8) | **16.8** | **16.8** | **16.8** | can't target while front stands; then 16.8 |
| Fighter (melee) | 9.7 | 4.9 | 19.4 | 9.7 (front empty) |
| Mage (magic) | 18.0 | 18.0 | 18.0 | 18.0 |

- **Your three wants:** (1) better in back: it can shoot anywhere, and it is safer. (2) Worse in front: it loses its choice of target and becomes a weaker Fighter. (3) Full damage everywhere: yes, in the strictest reading. No multiplier ever touches it.
- **Placement decision:** the front archer is still a full-damage attacker, so it is a weak option rather than a bad one. This follows Unicorn Overlord's reach-not-damage model [S15][S16]. The catch: if an archer's ability already targets the front ("hit the front foe"), standing in front costs it nothing at all.
- **Tuning knobs:** ranged `power` only. Optionally a small `ranged_front_mult` (0.85) if a front archer turns out too close to a Fighter.
- **Player-facing rule (one icon: a bow with a short arrow on the front column):** *"In the front column, a bow can only hit the enemy front line."*
- **Risk:** this makes the archer's target selector part of the balance. Every ranged ability needs a "from the front" targeting fallback, which is Darkest Dungeon-style rank text in disguise.

---

### Proposal 3: "Range bands" (distance, with melee re-read as distance)
**Observation:** today's melee rule is already a distance rule. Count the gap as d = attacker column + target column + 1: front→front is d1, back→front and front→back are d2, back→back is d3. Melee then deals ×1, ×0.5, ×0.25, which is exactly ×0.5 per step. **Rule:** ranged mirrors it: **d1 (front→front) ×0.5**, which is too close to draw; **d2 and d3 deal full damage**. Ranged power about 0.8.

| Proposal 3 | Back→Front (d2) | Back→Back (d3) | Front→Front (d1) | Front→Back (d2) |
|---|---|---|---|---|
| **Archer** (Shot 0.8) | **16.8** | **16.8** | 8.4 | **16.8** |
| Fighter (melee) | 9.7 | 4.9 | 19.4 | 9.7 (front empty) |
| Mage (magic) | 18.0 | 18.0 | 18.0 | 18.0 |

- **Your three wants:** (1) better in back: always full. (2) Worse in front: only against front targets. (3) Full damage everywhere: back targets are always full.
- **Placement decision:** this is the richest for the archer itself. A front archer becomes a backline sniper that is easy to hit, which is a real niche and gives more options. It also stays readable as one idea: swords like it close, bows like it far.
- **Weakness:** the selector problem in reverse. If the basic Shot aims back-first, a front archer almost never shoots d1, so the "worse in front" barely bites except against all-front parties (Seawall, Tidebreak). To keep want 2, the Shot must aim at the same row, front first, which weakens the caster-hunter role.
- **Tuning knobs:** `ranged_d1_mult` (0.5), ranged `power`. The melee multipliers stay as they are.
- **Player-facing rule (one icon: a bow with a red ▼ when it fires across the front lines):** *"Bows are weak point-blank: a bow shot from the front line at the enemy front line deals half."*

---

### Proposal 4: "Cover" (the defender's placement matters too)
**Rule:** a ranged hit fired from the **back** deals full damage, and from the **front** ×0.75. A **back-column target with a living ally in front of it in the same row is in cover** and takes ×0.75 from ranged. A target with no one in front of it in its row takes full. Ranged power about 0.85.

| Proposal 4 | Back→Front | Back→Back | Front→Front | Front→Back |
|---|---|---|---|---|
| **Archer** (Shot 0.85) | **17.8** | 13.4 in cover / **17.8** open | 13.4 | 10.0 in cover / 13.4 open |
| Fighter (melee) | 9.7 | 4.9 | 19.4 | 9.7 (front empty) |
| Mage (magic) | 18.0 | 18.0 | 18.0 | 18.0 |

- **Your three wants:** (1) yes. (2) Yes, ×0.75. (3) Mostly: ×0.75 in cover is never "useless", but it isn't literally full.
- **Placement decision:** the strongest of the four. It adds a **defensive** decision: cover rows versus open rows. Lamplight, Vault Door, Hearth and Keystone shapes cover their back units for free. Choir, Lumari Chorus and Strays are open, which gives back-heavy shapes a natural weakness to archers. When a front unit falls, its row is exposed, so killing a front unit "opens" a row: a visible, story-like moment.
- **Weakness:** two icons (a bow on the column, and a shield badge on covered units) and two knobs. It is the heaviest rule to read, and it overlaps with the Lamplight guardian, which already protects the same-row back partner.
- **Tuning knobs:** `ranged_front_mult` (0.75), `ranged_cover_mult` (0.75), ranged `power`.
- **Player-facing rule:** *"Bows hit full from the back and ¾ from the front; a back-row hero with an ally in front of it is in cover and takes ¾ from bows."*

---

### Summary
| | Rule in one line | Back→F / Back→B / Front→F / Front→B (Archer) | Your wants 1 / 2 / 3 | Placement decision | Readability | Knobs |
|---|---|---|---|---|---|---|
| **★ 1. Mirror** | Bows full from back, ½ from front; target column ignored | 16.8 / 16.8 / 8.4 / 8.4 | ✓ / ✓ / ✓ | Party-level: who takes the back slots | One icon per weapon | power, `ranged_front_mult` |
| 2. Point-blank | Full everywhere; from the front, targets like melee | 16.8 / 16.8 / 16.8 / (front empty) | ✓ / ✓ (reach) / ✓✓ | Weak (selector-dependent) | One icon | power |
| 3. Range bands | ½ only front→front; else full | 16.8 / 16.8 / 8.4 / 16.8 | ✓ / partial / ✓ | Rich for the archer; selector-dependent | One icon, needs the distance idea | power, `ranged_d1_mult` |
| 4. Cover | Back full, front ¾; covered back targets take ¾ | 17.8 / 13.4–17.8 / 13.4 / 10.0–13.4 | ✓ / ✓ / mostly | Strongest: attacker *and* defender | Two icons | power, front mult, cover mult |
| *Today* | ½ attacker back, ½ target back | *9.4 / 4.7 / 18.9 / 9.4* | ✗ / ✗ / ✗ | Archer is a worse Fighter | n/a | n/a |

**★ Recommendation: Proposal 1 (the mirror).** It meets all three wants literally and is the smallest rule to read: a sword icon on the front column, a bow icon on the back. It is also the smallest code change. It doesn't depend on which target the archer's selector picks. It keeps placement a real decision, because the back's four slots are now contested by three roles, and getting pulled forward has a real price. It answers lesson 1 (the FF trap) with the mirror's front penalty and lesson 2 with lower Shot power. If playtests show archers never leaving the back and that feeling stale, **Proposal 4's cover rule is the natural add-on**. It sits on top of Proposal 1 without changing it (set the front multiplier to 0.5 or 0.75 and add `ranged_cover_mult`).

---

## 4. Interactions (for ★ Proposal 1, with notes on the others)

### Existing and proposed counters
- **Lamplight guardian** already intercepts the first ranged or magic hit on its back partner (`_damage` checks `magic or not _cur_melee`), so no change is needed. With the same-row selector suggested above, the guardian sits exactly where archer fire lands. That's a good fit.
- **Lighthouse post** already draws ranged and magic. With archers, the Lighthouse becomes the anti-archer shape, and its cost (the post can fall fast) becomes real.
- **Keeper's Ring** makes the ringed unit untargetable, so it is immune to snipes. No change.
- **Vowkeeper ("Guards back ally", Fighter Mercy+Order corner, still unvoted):** with archers in the game it has a clear job. Ranged physical gives it a second threat to answer, which strengthens the case for picking it.
- **Warden of Chains (approved; Shackle drags the back foe in the struck row forward):** under Proposals 1, 3 and 4 this becomes the **hard counter to archers**. The dragged archer drops to ×0.5 (or ×0.75), takes full melee, and can be hit by melee. That's a clean counter triangle (archer beats casters, Warden beats archers, casters beat Warden). Under Proposal 2 the dragged archer loses reach instead.

### Formations (`05-formations.md`)
- **Lumari Chorus** cost text "physical attackers deal half" needs rewording to "**melee** attackers deal half" (all proposals).
- **Choir / Lumari Chorus + archers:** *Opening volley* on three or four back archers is a strong opening burst with no wall. Melee reaches them at once (their stated cost). Watch it in the balance sim.
- **Keystone / Crescent *Flank*:** the back unit deals +20% to the foe in its own row, and Crescent adds more crits. A back archer here deals full ×1.2 to its own row, which is a combo, as horizontal scaling wants. Today Flank mostly compensates a back melee unit's half damage, so with archers it becomes a real damage shape. Watch the numbers.
- **Vault Door *Hold the door*:** the back unit steps forward when its front partner falls. A stepping archer drops to ×0.5, which is a real cost. Players may prefer to put a melee hero behind the door, which is good (a decision).
- **Hearth / Lighthouse:** one wall plus back archers is a natural "turret" party. The cost (the lone post) carries over.
- **Seawall / Tidebreak / Kindred (all front):** an archer here pays the front penalty, so these shapes stay melee shapes. Consistent with "behaviour must make sense in that geometry".
- **Strays:** no cover and no guardians, so Strays are fully exposed to archers (most visible under Proposal 4).
- **Echo Step:** halves splash. Neutral, unless archer abilities splash.

### Approved classes (round 1 and round 2)
- **No approved class is ranged yet.** Rogue N went to Saboteur, and the candidates you flagged (Vaultrunner, "good candidate for ranged weapon"; Trapwright, "could this use a ranged weapon?"; Snareshot; Slinger) are unpicked. So the rule can be chosen now without re-tuning a live class. The first users would be monsters (Vault archers) and any future Rogue pick.
- **Duelist** (parries the next **melee** hit): ranged doesn't trigger the parry, so archers are a natural counter to Duelist. That's fine and readable.
- **Bladebreaker** (disarm: no basic attacks): archers lean on basic Shots, so Bladebreaker answers them well.
- **Nightwatch** (strikes and stuns the next foe that hits an adjacent ally): works against ranged.
- **Halberdier** (front foe and the foe behind it): the second hit is melee, so a back target stays ×0.5. Unchanged.
- **Assassin / backstab and Execute dashes:** they stay melee (see §3). If you would rather they ignore the target column, that's a separate call.

### The Fading
- Fading tick damage is a percentage of max HP to everyone, with no column rule, and its "+25% dealt per tick" multiplies every hit. So no proposal changes the Fading directly.
- **Indirect effect:** back units outlive front units when melee is the main damage, so late fights become back-row fights. Today only mages deal full damage from there. Under any proposal, back archers do too, so **ranged-heavy parties gain an edge in fights that reach the Fading**. Track the win rate of fights past 36 s with ranged-heavy sides in the class balance runner (`tests/balance_classes.gd`). Shot power is the knob.

---

## 5. Ideas not proposed, and why
- **Round-2 Option 1 (skip only the attacker's halving; the FF rule):** fails want 3 (back targets still ×0.5) and want 2 (front isn't worse). The research shows it collapses into "always in back" [S11].
- **Round-2 Option 3 (ranged ignores columns at ¾ power everywhere):** fails wants 1 and 2. There's no placement decision for archers.
- **Accuracy instead of damage (FF4):** the sim has no hit roll except blind. Adding one brings RNG and an invisible rule [S6].
- **Per-class column abilities (Darkest Dungeon):** "from the back: Volley; from the front: Point-blank Kick". This is good **class** design, not a system rule. It's worth using for one ranged advanced class (e.g. Slinger or Snareshot), where a change of ability is the class's identity, while Proposal 1 stays the global rule.
- **Bench / swap rows (Octopath 0):** doesn't fit a 4-hero auto-battler with no input.
- **Height or terrain range (FFT, Tactics Ogre):** no terrain in the grid.

---

## 6. If a proposal is approved: what changes
*(Listed, not done. This doc touches no code or spec.)*
- `03-runs-and-combat.md` targeting bullet, and BUILD.md "Spec non-negotiables" targeting line: add the ranged column rule.
- `05-formations.md`: Grid Reminder line, and Lumari Chorus cost ("melee attackers deal half").
- `tuning.gd`: `ranged_front_mult` (and `ranged_cover_mult` if Proposal 4 is added later).
- `abilities.gd`: a `ranged` flag on effects, plus a Shot basic and its selector (same row, back first).
- `combat_sim.gd` `_damage`: the ranged branch, plus a `ranged_front` mod for the hit annotation.
- `class-options-round2.md` §7: point to this doc as the answer to q-4.

---

## Sources
- [S1] StrategyWiki, *Final Fantasy/Parties* (party order targeting): https://strategywiki.org/wiki/Final_Fantasy/Parties
- [S2] Wikipedia, *Final Fantasy II*: https://en.wikipedia.org/wiki/Final_Fantasy_II
- [S3] GamerCorner, *FFII Party Planning*: https://guides.gamercorner.net/ffii/party-planning/
- [S4] The Let's Play Archive, *Final Fantasy III DS*, Update 70: https://lparchive.org/Final-Fantasy-III-DS/Update%2070
- [S5] Wikibooks, *Final Fantasy IV/Characters/Rosa*: https://en.wikibooks.org/wiki/Final_Fantasy_IV/Characters/Rosa
- [S6] Free Enterprise Wiki, *rows* (FF4 engine behaviour): https://wiki.ff4fe.com/doku.php?id=rows
- [S7] Final Fantasy Wiki, *Final Fantasy V equipment properties*: https://finalfantasy.fandom.com/wiki/Final_Fantasy_V_equipment_properties
- [S8] Almar's Guides, *Final Fantasy VI Advance weapons*: https://almarsguides.com/retro/walkthroughs/gba/games/finalfantasyviadvance/misc/lists/weapons/
- [S9] Final Fantasy Wiki, *Rising Sun*: https://finalfantasy.fandom.com/wiki/Rising_Sun
- [S10] Jegged, *FFVII Front and Back Row*: https://jegged.com/Games/Final-Fantasy-VII/Tips-and-Tricks/Front-and-Back-Row.html
- [S11] Jegged, *FFIX Front and Back Row Mechanics*: https://jegged.com/Games/Final-Fantasy-IX/Tips-and-Tricks/Front-and-Back-Row-Mechanics.html
- [S12] Final Fantasy Wiki, *Multina Racket (FFIX)*: https://finalfantasy.fandom.com/wiki/Multina_Racket_(Final_Fantasy_IX)
- [S13] Final Fantasy Wiki, *Bowgun* (FFT bow and crossbow range): https://finalfantasy.fandom.com/wiki/Bowgun
- [S14] GamePretty, *Tactics Ogre Reborn: Spoiler-free Tips for Beginners*: https://gamepretty.com/tactics-ogre-reborn-spoiler-free-tips-for-beginners/
- [S15] GameFAQs, *Unicorn Overlord: Front row/back row clarification*: https://gamefaqs.gamespot.com/boards/426397-unicorn-overlord/80716994
- [S16] GameFAQs, *Unicorn Overlord: placing a unit in front or back*: https://gamefaqs.gamespot.com/boards/426397-unicorn-overlord/80706176
- [S17] RPG Site, *Unicorn Overlord class types*: https://www.rpgsite.net/news/15338-unicorn-overlord-rolls-out-initial-wave-of-class-types-leaders-promotions-and-more-allies-enemies
- [S18] Darkest Dungeon Wiki (wiki.gg), *Arbalest*: https://darkestdungeon.wiki.gg/wiki/Arbalest
- [S19] Darkest Dungeon 2 Wiki (Fextralife), *Flashbang*: https://darkestdungeon2.wiki.fextralife.com/Flashbang and *Collect Bounty*: https://darkestdungeon2.wiki.fextralife.com/Collect+Bounty
- [S20] Steam Community, *Darkest Dungeon* discussions (shuffle, Arbalest, Highwayman): https://steamcommunity.com/app/262060/discussions/0/1693795812305181751
- [S21] RPG Site, *Octopath Traveler 0 preview* (8-person party, front/back pairs): https://www.rpgsite.net/preview/18318-octopath-traveler-0-feels-like-a-great-console-rpg-but-the-large-party-size-has-me-a-little-concerned
- [S22] RPG Site, *Octopath Traveler 0: How to attack from the back row*: https://www.rpgsite.net/guide/19082-octopath-traveler-0-how-to-attack-from-back-row
- [S23] GamerGuides, *Bravely Default: Brave and Default*: https://gamerguides.com/bravely-default/guide/gameplay/battle-system/brave-and-default
- [S24] Wikipedia, *Persona 2: Eternal Punishment*: https://en.wikipedia.org/wiki/Persona_2:_Eternal_Punishment
- [S25] Twinfinite, *Legend of Mana best starting weapon*: https://twinfinite.net/guides/legend-of-mana-best-starting-weapon/
- [S26] Metabot, *TFT Positioning Guide*: https://metabot.gg/en/TFT/guides/tft-positioning-guide-frontline-backline ; Mobalytics, *TFT positioning guide*: https://mobalytics.gg/blog/tft/tft-positioning-guide-how-to-get-the-most-from-your-units/
- [S27] Mobalytics, *How to counter Assassin and Shade comps* (Zephyr): https://mobalytics.gg/blog/tft/tft-how-to-counter-assassin-shade-comps/
- [S28] Blizzard forums, *Positioning in Battlegrounds*: https://us.forums.blizzard.com/en/hearthstone/t/positioning-in-battlegrounds/20447 ; ONE Esports, *Hearthstone Battlegrounds: everything you need to know*: https://www.oneesports.gg/gaming/hearthstone-battlegrounds-everything-you-need-to-know-about-blizzards-auto-battler/
- [S29] Super Auto Pets Wiki, *Snake*: https://superautopets.wiki.gg/wiki/Snake ; *Badger*: https://superautopets.wiki.gg/wiki/Badger
- [S30] AFK Arena Wiki, *Lineups guide*: https://afk-arena.fandom.com/wiki/Lineups_guide
- [S31] Prima Games, *Best team formations in AFK Journey*: https://primagames.com/gaming/best-team-formations-for-every-situation-in-afk-journey
- [S32] Summoners War Wiki, *Attack Bar*: https://summonerswar.fandom.com/wiki/Attack_Bar

*Note on sourcing:* several wiki pages (Final Fantasy Wiki, GameFAQs) blocked direct fetching. Where a row above cites them, the claim comes from their search-result excerpts. The Summoners War positioning note is from general knowledge and is marked as such.
