# Echoing Depths: Design Overview
*Working title.*

## Premise
A 2D pixel-graphics fantasy RPG combining dungeon crawling, async PvP, and auto-battler combat. The art style draws heavily on pixel-era JRPGs.

The world is being slowly erased by the Fading. Legends say that the deadly Memory Vaults beneath the land hold Shards of a crystal that can restore what the Fading has taken, and these legends have drawn many groups of adventurers to the Vaults. To claim a Shard, adventurers must face perilous monsters, riddles, decisions of chance, and, most importantly, other adventurers who want the Shard for themselves.

**Tone:** Mythic and wondrous, with a melancholic undercurrent.

## Scope of This Spec
These documents define the premise, core mechanics, and foundation of the story and lore. Detailed content (individual classes, abilities, items, encounters) and balance numbers are left to the development team. Examples and numbers throughout are illustrative placeholders.

## Inspiration Titles
### World Building and Class System
- Final Fantasy
- NES/SNES-era JRPGs

### Game Mechanics
- Super Auto Pets (combat)
- The Bazaar (encounters)
- Slay the Spire (map and encounters)

## Document Index
| File | Contents |
|---|---|
| `01-world-and-lore.md` | The Fading, the Lumari, the Memory Vaults, Echoes, Lanternrest, true history, in-world beliefs |
| `02-heroes-and-classes.md` | Heroes, the alignment grid, memories, advanced and Legendary classes, Relics |
| `03-runs-and-combat.md` | Run structure, hidden map, encounters, PvP, combat model, formations, run rewards |
| `04-meta-progression.md` | Lanternrest village, Shards, story remembrance, Monuments |

Each file ends with its own open questions.

## Possible Future Additions
Ideas worth revisiting after the main game is defined.
- **Tournament / ranked mode:** Victorious parties compete against each other in battles only, with no PvE encounters, earning rewards after each battle to level and equip their heroes. Unresolved: lore framing (e.g. Champion of the Lantern, the Lantern Trials, a Crown Shard), how players enter, and how alignment-based leveling works without encounter choices.

## Rejected Ideas
These ideas were considered and dropped. They are listed here so they are not proposed again.
- **Map previews of rewards:** The map is never player-facing, so path choices cannot show what they yield.
- **Echoes earning rewards while the player is away.**
- **Patrons** (a pre-run choice of a restored NPC): replaced by Adventurers' Guild Doctrines.
- **Conflicting Histories** (mutually exclusive village restorations): the village must never contain regrettable choices.
- **Advanced classes broadly gated behind meta progression:** only extreme corner classes are an exception.
- **Echo absorption / Vivid memories from PvP:** PvP is not currently planned to grant memories.
- **A standard fallback advanced class:** unnecessary, because every grid position produces an advanced class.
- **The Aspect system** (six Aspects, two per class, the Aspect wheel, the opposition rule): replaced by the alignment grid.
- **The Reliquary** (holding memories to assign later): memories are now bound to the hero in the encounter choice.
- **Different starting alignments for heroes of the same class:** each base class has one fixed starting position.
- **Separate "Crossed" classes:** with fixed starting positions, the far corner's class already serves as the super-rare class.
- **Alignment on weapons and armor while equipped:** only the Relic slot carries alignment, so the item upgrade loop stays intact. A one-time boon or affliction on accepting other items is noted as a fallback in `02-heroes-and-classes.md`.
