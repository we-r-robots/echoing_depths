#!/usr/bin/env python3
"""Generates the party-setup (draft + formation) icons into game/assets/party_setup/.
Masks ('#' = white) are tinted in code with a palette colour. Coloured sprites use KEY letters."""
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
    'plus': """
..#..
..#..
#####
..#..
..#..""",
    # serif-matched glyphs the Depths Serif font lacks (2 px strokes, 10 px digit height)
    'serif_plus': """
..##..
..##..
######
######
..##..
..##..""",
    'serif_pct': """
##....##
##...##.
....##..
...##...
...##...
..##....
..##....
.##.....
##...##.
#....##.""",
}

KEY = {'o': 'ink1', 'w': 'ink10', 'l': 'ink9', 's': 'ink7', '.': None}
SPRITES = {
    # pointing hand cursor (demo / tutorial), tip at (3, 0)
    'hand_point': """
..oo.......
.owlo......
.owlo......
.owlooo....
.owlwlwoo..
oowlwlwlwo.
owowwwwwlwo
owlwwwwwwlo
.owwwwwwwlo
.olwwwwwwlo
..olwwwwlo.
...olwwlo..
....oooo...""",
    # closed grabbing hand (while dragging)
    'hand_grab': """
...........
...........
...........
..oooooo...
.owlwlwlwo.
oowlwlwlwlo
owowwwwwwlo
owlwwwwwwlo
.owwwwwwwlo
.olwwwwwwlo
..olwwwwlo.
...olwwlo..
....oooo...""",
}


def mask(name, art):
    rows = [r for r in art.strip('\n').split('\n')]
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == '#':
                im.putpixel((x, y), (255, 255, 255, 255))
    im.save(os.path.join(OUT, name + '.png'))


def sprite(name, art):
    rows = [r for r in art.strip('\n').split('\n')]
    w = max(len(r) for r in rows)
    im = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            c = KEY.get(ch)
            if c:
                im.putpixel((x, y), PAL[c])
    im.save(os.path.join(OUT, name + '.png'))


for k, v in MASKS.items():
    mask(k, v)
for k, v in SPRITES.items():
    sprite(k, v)
print('ok')
