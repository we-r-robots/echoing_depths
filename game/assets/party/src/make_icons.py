#!/usr/bin/env python3
"""Generates the hero-detail screen icons into game/assets/party/.
Masks ('#' = white) are tinted in code with a palette colour via modulate.
Coloured sprites use palette letters (see KEY)."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
PAL = {}
with open(os.path.join(OUT, '..', 'palette', 'master.gpl')) as f:
    for line in f:
        p = line.split()
        if len(p) >= 4 and p[0].isdigit():
            PAL[p[3]] = (int(p[0]), int(p[1]), int(p[2]), 255)

MASKS = {
    'stat_atk': """
.....##
....###
...###.
#.###..
.###...
.##....
#.#....""",
    'stat_def': """
#######
#######
#######
#######
.#####.
..###..
...#...""",
    'stat_mag': """
...#...
...#...
..###..
#######
..###..
...#...
...#...""",
    'stat_spd': """
..####.
.####..
#####..
..####.
.####..
####...
.##....""",
    'stat_hp': """
.##.##.
#######
#######
#######
.#####.
..###..
...#...""",
    'slot_weapon': """
.......##
......###
.....###.
....###..
#..###...
.####....
..##.....
.#.##....
#........""",
    'slot_armor': """
.##...##.
####.####
#########
#########
.#######.
.#######.
.#######.
.##...##.
.........""",
    'slot_relic': """
..#...#..
...#.#...
....#....
...###...
..#####..
.###.###.
..#####..
...###...
....#....""",
    'lock': """
.###.
#...#
#...#
#####
##.##
#####""",
    'ability': """
...#...
..###..
.#####.
#######
.#####.
..###..
...#...""",
    'start': """
..###..
.#...#.
#.....#
#..#..#
#.....#
.#...#.
..###..""",
    'tick': """
......#
.....##
#...##.
##.##..
.###...
..#....""",
    'dot': """
.##.
####
####
.##.""",
}

KEY = {'k': 'ink1', 'w': 'ink10', 'l': 'ink9', 'm': 'ink7', 'a': 'amber5', 'A': 'amber6'}
SPRITES = {
    # white glove pointer (points right), outlined in ink
    'pointer': """
..kkkk.......
.kwwwwkkkkkk.
kwwwwwwwwwwwk
kwlwwwkkkkkk.
kwlwwwwwk....
kwllwwwk.....
.kmlwwwwk....
..kkkkkk.....""",
}


def mask(name, rows):
    rows = [r for r in rows.strip('\n').split('\n')]
    h, w = len(rows), max(len(r) for r in rows)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == '#':
                im.putpixel((x, y), (255, 255, 255, 255))
    im.save(os.path.join(OUT, name + '.png'))


def sprite(name, rows):
    rows = [r for r in rows.strip('\n').split('\n')]
    h, w = len(rows), max(len(r) for r in rows)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in KEY:
                im.putpixel((x, y), PAL[KEY[ch]])
    im.save(os.path.join(OUT, name + '.png'))


for n, r in MASKS.items():
    mask(n, r)
for n, r in SPRITES.items():
    sprite(n, r)
print('ok')
