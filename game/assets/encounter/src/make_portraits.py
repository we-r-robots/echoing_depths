"""Placeholder hero portraits (24x24, master palette). Left halves are mirrored for symmetry.
Swap for the sprite builder's heroes later; only the PNG paths in data/encounters/demo_party.json matter."""
import os
from PIL import Image
from paint import PAL, ROOT

OUT = os.path.join(ROOT, 'assets', 'encounter', 'portraits')

KEY = {
    'k': 'ink1', 'K': 'ink2', 'i': 'ink3', 'j': 'ink4',
    'g': 'ink5', 'G': 'ink7', 'W': 'ink9', 'X': 'ink10',
    'w': 'ink8', 'f': 'fade3',
    'd': 'skin1', 's': 'skin2', 'S': 'skin3', 'h': 'skin4',
    'r': 'blood2', 'R': 'blood3', 'p': 'blood4',
    'A': 'amber4', 'a': 'amber6', 'y': 'amber3', 'b': 'amber2',
    'c': 'crystal5', 'C': 'crystal4',
    'L': 'life3', 'l': 'life2', 'D': 'life1', 'E': 'life4',
    'V': 'violet3', 'v': 'violet2', 'u': 'violet1', 'U': 'violet4',
    'e': 'ink1', 'm': 'blood2', 'n': 'skin1',
}

FIGHTER = [
    "............",
    "............",
    "..........kk",
    "........kkGG",
    ".......kGGWW",
    "......kGWWGG",
    ".....kGWGggg",
    ".....kGGgggg",
    "....kGGggggg",
    "....kGgggggg",
    "....kGgkkkkk",
    "....kGgkKcKk",
    "....kGgkkkkk",
    "....kGgggggk",
    "....kjgggggk",
    ".....kjgggjk",
    ".....kkjjjjk",
    "...kkrrkkkkk",
    "..krRRrkGGGg",
    ".krRRRkGWWGg",
    ".krRRkGWGggg",
    "krRRrkGGgggg",
    "krRRrkjggggg",
    "krRrrkjjgggg",
]
FIGHTER_EXTRA = {(1, 13): 'R', (2, 13): 'R', (2, 14): 'r', (0, 14): 'R', (1, 14): 'R', (3, 14): 'r', (1, 15): 'r', (0, 15): 'r'}

HEALER = [
    "............",
    "............",
    ".........kkk",
    ".......kkXXX",
    "......kXXXXX",
    ".....kXXWWWW",
    "....kXXWkkkk",
    "....kXWkdsss",
    "...kXWkdsSSS",
    "...kXWkdSShh",
    "...kXWksSShh",
    "...kXWksekSS",
    "...kXWksSSSS",
    "...kXWkdsSSS",
    "...kXWkdssSS",
    "...kXWwkdssm",
    "...kXWwwkkdd",
    "..kXWwwwAkkk",
    "..kXwwwwAAAA",
    ".kXWwwwwwAya",
    ".kXwwwwwwwAA",
    "kXWwwwwwwwwA",
    "kXwwwwwwwwww",
    "kXwwwwwwwwww",
]

MAGE = [
    "............",
    "...........k",
    "..........kV",
    "..........kV",
    ".........kVU",
    ".........kVV",
    "........kVVV",
    "........kVVv",
    ".......kVVvv",
    "......kVVvvv",
    "..kkkkVVVvvv",
    ".kVVVVVVVvvv",
    ".kkuuuuuuuuu",
    "..kkkkkkkkkk",
    "....kKKKKKKK",
    "....kKKKKKKK",
    "....kKKcCKKK",
    "....kKKKKKKK",
    "....kkKKKKKw",
    "...kVVkKKKww",
    "..kVVVVkkwww",
    ".kVvVVVVkwwa",
    "kVVvvVVVVkww",
    "kVvvvvVVVVkw",
]

ROGUE = [
    "............",
    "............",
    "..........kk",
    "........kkLL",
    ".......kLLLL",
    "......kLLLEE",
    ".....kLLEllll",
    ".....kLlkkkkk",
    "....kLLkdsss",
    "....kLlkdsSS",
    "....kLlksSSS",
    "....kLlkkekh",
    "....kLlksSSS",
    "....kLlkDDDD",
    "....kLlkDlll",
    "....kLlkDlll",
    "....kLlkkDDD",
    "...kLLlllkkk",
    "..kLLlllDDDD",
    ".kLLllDDsDDD",
    ".kLlllDDDDDD",
    "kLLlllDDDDbb",
    "kLlllDDDDDDD",
    "kLlllDDDDDDD",
]


def build(half, extra=None):
    img = Image.new('RGBA', (24, 24), (0, 0, 0, 0))
    for y, row in enumerate(half):
        row = row[:12].ljust(12, '.')
        full = row + row[::-1]
        for x, c in enumerate(full):
            if c != '.':
                img.putpixel((x, y), PAL[KEY[c]] + (255,))
    for (x, y), c in (extra or {}).items():
        img.putpixel((x + 6, y - 13), PAL[KEY[c]] + (255,))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    f = build(FIGHTER)
    # red plume sweeping back off the helm crest
    for (x, y, c) in [(12, 1, 'R'), (13, 1, 'R'), (14, 1, 'r'), (13, 0, 'R'), (14, 0, 'R'), (15, 0, 'r'), (15, 1, 'r'),
                      (16, 1, 'r'), (16, 2, 'r'), (11, 2, 'R'), (12, 2, 'p'), (11, 1, 'R'), (10, 2, 'k'), (13, 2, 'R')]:
        f.putpixel((x, y), PAL[KEY[c]] + (255,))
    f.save(os.path.join(OUT, 'fighter.png'))
    build(HEALER).save(os.path.join(OUT, 'healer.png'))
    m = build(MAGE)
    # bent hat tip
    for (x, y, c) in [(11, 0, '.'), (12, 0, '.'), (12, 1, 'k'), (13, 0, 'k'), (14, 0, 'k'), (13, 1, 'V'), (11, 1, '.'), (11, 2, 'k')]:
        if c == '.':
            m.putpixel((x, y), (0, 0, 0, 0))
        else:
            m.putpixel((x, y), PAL[KEY[c]] + (255,))
    m.save(os.path.join(OUT, 'mage.png'))
    build(ROGUE).save(os.path.join(OUT, 'rogue.png'))
    print('portraits done')


if __name__ == '__main__':
    main()
