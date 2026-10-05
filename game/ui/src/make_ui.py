#!/usr/bin/env python3
"""Generates the shared UI kit textures (master palette only) into game/ui/.
9-slice panels: margins are noted next to each; theme.tres uses the same values.
Icons in icons/ are white masks: tint them with a palette colour via modulate (exact palette result)."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.dirname(HERE)
PAL = {}
with open(os.path.join(UI, '..', 'assets', 'palette', 'master.gpl')) as f:
    for line in f:
        p = line.split()
        if len(p) >= 4 and p[0].isdigit():
            PAL[p[3]] = (int(p[0]), int(p[1]), int(p[2]))


def C(name, a=255):
    return PAL[name] + (a,)


def img(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < im.width and 0 <= y < im.height:
                im.putpixel((x, y), col)


def chamfer_shape(w, h, c):
    """Mask of a rectangle with c-px 45-degree chamfered corners."""
    m = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            dx = min(x, w - 1 - x)
            dy = min(y, h - 1 - y)
            m[y][x] = dx + dy >= c
    return m


def layered(w, h, c, layers):
    """layers: list of (inset, colour) drawn outer to inner; each a chamfered rect inset by `inset`."""
    im = img(w, h)
    for inset, col in layers:
        m = chamfer_shape(w - 2 * inset, h - 2 * inset, max(c - inset, 0) if c else 0)
        for y in range(h - 2 * inset):
            for x in range(w - 2 * inset):
                if m[y][x]:
                    im.putpixel((x + inset, y + inset), col)
    return im


def save(im, name):
    path = os.path.join(UI, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


KNOT = ["##.", "#.#", ".##"]


def corner_knots(im, col, inset=3):
    w, h = im.size
    for (ox, oy, fx, fy) in [(inset, inset, 1, 1), (w - inset - 3, inset, -1, 1), (inset, h - inset - 3, 1, -1), (w - inset - 3, h - inset - 3, -1, -1)]:
        for y in range(3):
            for x in range(3):
                sx = x if fx == 1 else 2 - x
                sy = y if fy == 1 else 2 - y
                if KNOT[sy][sx] == '#':
                    im.putpixel((ox + x, oy + y), col)


def main():
    # -- panel (Sea of Stars style): ink1 outer, ink5 hairline, ink2 fill, ink3 top highlight, corner knots.  margins 6
    p = layered(24, 24, 0, [(0, C('ink1')), (1, C('ink5')), (2, C('ink1')), (3, C('ink2'))])
    rect(p, 3, 3, 20, 3, C('ink3'))
    corner_knots(p, C('ink6'), 3)
    save(p, 'panel.png')
    # translucent variant for overlays on art.  margins 6
    p2 = layered(24, 24, 0, [(0, C('ink1', 230)), (1, C('ink4')), (2, C('ink1', 230)), (3, C('ink1', 215))])
    save(p2, 'panel_dim.png')
    # gilded variant for rare / strong-shift moments.  margins 6
    p3 = layered(24, 24, 0, [(0, C('ink1')), (1, C('amber4')), (2, C('amber1')), (3, C('ink1')), (4, C('ink2'))])
    rect(p3, 4, 4, 19, 4, C('ink3'))
    corner_knots(p3, C('amber6'), 1)
    save(p3, 'panel_rare.png')

    # -- choice bar: chamfered ends (c=5), teal border like a bevelled plate.  margins l/r 8, t/b 6
    W, H, c = 32, 40, 6
    base = [(0, C('ink1')), (1, C('crystal2')), (2, C('ink1')), (3, C('ink2'))]
    n = layered(W, H, c, base)
    rect(n, 6, 3, W - 7, 3, C('ink3'))
    save(n, 'choice_normal.png')
    hv = layered(W, H, c, [(0, C('ink1')), (1, C('crystal4')), (2, C('crystal1')), (3, C('ink3'))])
    rect(hv, 6, 3, W - 7, 3, C('ink4'))
    save(hv, 'choice_hover.png')
    pr = layered(W, H, c, [(0, C('ink1')), (1, C('crystal5')), (2, C('crystal2')), (3, C('crystal1'))])
    save(pr, 'choice_pressed.png')
    ds = layered(W, H, c, [(0, C('ink1')), (1, C('fade1')), (2, C('ink1')), (3, C('ink1'))])
    save(ds, 'choice_disabled.png')
    # rare: gilded double border with gems on the chamfers
    rr = layered(W, H, c, [(0, C('ink1')), (1, C('amber5')), (2, C('amber2')), (3, C('ink1')), (4, C('ink2'))])
    rect(rr, 7, 4, W - 8, 4, C('ink3'))
    save(rr, 'choice_rare.png')
    rh = layered(W, H, c, [(0, C('ink1')), (1, C('amber6')), (2, C('amber3')), (3, C('amber1')), (4, C('ink3'))])
    rect(rh, 7, 4, W - 8, 4, C('ink4'))
    save(rh, 'choice_rare_hover.png')

    # -- generic button (Continue etc.): smaller chamfer.  margins 6
    b = layered(24, 20, 4, [(0, C('ink1')), (1, C('amber3')), (2, C('ink1')), (3, C('ink2'))])
    rect(b, 4, 3, 19, 3, C('ink3'))
    save(b, 'button_normal.png')
    bh = layered(24, 20, 4, [(0, C('ink1')), (1, C('amber5')), (2, C('amber1')), (3, C('ink3'))])
    save(bh, 'button_hover.png')
    bp = layered(24, 20, 4, [(0, C('ink1')), (1, C('amber6')), (2, C('amber2')), (3, C('amber1'))])
    save(bp, 'button_pressed.png')
    bd = layered(24, 20, 4, [(0, C('ink1')), (1, C('fade1')), (2, C('ink1')), (3, C('ink1'))])
    save(bd, 'button_disabled.png')
    # focus ring: transparent centre, crystal outline. margins 6
    fo = layered(24, 20, 4, [(0, C('crystal5')), (1, (0, 0, 0, 0))])
    save(fo, 'focus.png')

    # -- top bar strip: 1x30, bottom bevel.  stretch horizontally
    tb = img(4, 32)
    for y in range(32):
        col = C('ink1')
        if y == 29:
            col = C('ink3')
        elif y == 30:
            col = C('ink4')
        elif y == 31:
            col = C('ink1')
        rect(tb, 0, y, 3, y, col)
    save(tb, 'topbar.png')

    # -- frame for portraits (26x26, 24x24 window). margins 1
    fr = img(28, 28)
    rect(fr, 0, 0, 27, 27, C('ink1'))
    rect(fr, 1, 1, 26, 26, C('ink5'))
    rect(fr, 2, 2, 25, 25, C('ink2'))
    save(fr, 'portrait_frame.png')

    # -- ornament divider: hairline with a centre lozenge (amber) 96x7
    dv = img(96, 7)
    for x in range(96):
        d = abs(x - 47.5)
        if d > 6:
            col = C('ink5') if d < 34 else C('ink4')
            if d < 46:
                dv.putpixel((x, 3), col)
    loz = ["...#...", "..#a#..", ".#aAa#.", "#aAAAa#", ".#aAa#.", "..#a#..", "...#..."]
    for y, row in enumerate(loz):
        for x, ch in enumerate(row):
            if ch != '.':
                dv.putpixel((44 + x, y), C({'#': 'amber2', 'a': 'amber4', 'A': 'amber6'}[ch]))
    for sx in (36, 57):
        dv.putpixel((sx, 3), C('amber3'))
        dv.putpixel((sx + 1, 3), C('amber3'))
    save(dv, 'divider.png')

    # -- icons (white masks)
    icons = {
        # kinds 9x9
        'kind_riddle': [".#######.", "#.......#", "#..###..#", "#.#...#.#", "#.#.#.#.#", "#.#...#.#", "#..###..#", "#.......#", ".#######."],
        'kind_chance': ["..#####..", ".#.....#.", "#..#....#", "#.......#", "#...#...#", "#.......#", "#....#..#", ".#.....#.", "..#####.."],
        'kind_monster': ["#.......#", "##.....##", "#.#...#.#", "#..###..#", "#.......#", ".#.#.#.#.", ".##.#.##.", "..#...#..", "...###..."],
        'kind_recruitment': ["...###...", "..#...#..", "..#.#.#..", "..#...#..", "...###...", "....#....", "..#####..", "....#....", "...#.#..."],
        'kind_moral': ["....#....", ".#######.", ".#..#..#.", "#.#.#.#.#", "#.#.#.#.#", "###.#.###", "....#....", "....#....", ".#######."],
        'kind_pvp': ["#.......#", ".#.....#.", "..#...#..", "...#.#...", "....#....", "...#.#...", "..#...#..", "##.....##", "##.....##"],
        # classes 7x7
        'class_fighter': ["......#", ".....#.", "....#..", "#..#...", ".##....", ".##....", "#..#..."],
        'class_rogue': ["...#...", "...#...", "..###..", "..###..", "...#...", "..###..", "...#..."],
        'class_healer': ["..###..", "..#.#..", "###.###", "#.....#", "###.###", "..#.#..", "..###.."],
        'class_mage': ["...#...", "...#...", "#######", ".##.##.", "..#.#..", ".#...#.", "#.....#"],
        # arrows 7x7 (up), others derived
        'arrow_up': ["...#...", "..###..", ".#####.", "#######", "..###..", "..###..", "..###.."],
        'arrow_upright': ["..#####", "...####", "....###", "...####", "..###.#", ".###...", "###...."],
        'arrow2_up': ["...#...", "..###..", ".#####.", "...#...", "..###..", ".#####.", "#######"],
        'star': ["...#...", "...#...", ".#####.", "..###..", "..#.#..", ".#...#.", "......."],
        'pip_full': ["###", "###", "###"],
        'pip_empty': ["###", "#.#", "###"],
        'chevron': ["#..", "##.", "###", "##.", "#.."],
        'heart': [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."],
    }
    for name, rows in icons.items():
        w = max(len(r) for r in rows)
        im = img(w, len(rows))
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == '#':
                    im.putpixel((x, y), (255, 255, 255, 255))
        save(im, f'icons/{name}.png')
        if name in ('arrow_up', 'arrow2_up'):
            stem = name[:-3]
            save(im.rotate(180), f'icons/{stem}_down.png')
            save(im.rotate(90), f'icons/{stem}_left.png')
            save(im.rotate(-90), f'icons/{stem}_right.png')
        if name == 'arrow_upright':
            save(im.transpose(Image.FLIP_LEFT_RIGHT), 'icons/arrow_upleft.png')
            save(im.transpose(Image.FLIP_TOP_BOTTOM), 'icons/arrow_downright.png')
            save(im.rotate(180), 'icons/arrow_downleft.png')

    # memory gem (full colour) 7x9
    gem = ["...#...", "..#c#..", ".#cCc#.", "#cCWCc#", "#cCCCb#", ".#cCb#.", "..#b#..", "...#...", "......."]
    cm = {'#': 'crystal2', 'c': 'crystal3', 'C': 'crystal4', 'W': 'ink10', 'b': 'crystal2'}
    im = img(7, 8)
    for y, row in enumerate(gem[:8]):
        for x, ch in enumerate(row):
            if ch != '.':
                im.putpixel((x, y), C(cm[ch]))
    save(im, 'icons/memory_gem.png')
    # big memory gem 13x15 for the resolution card
    big = [
        "......#......", ".....#c#.....", "....#cCc#....", "...#cCWCc#...", "..#cCWWCCc#..", ".#cCCWCCCCc#.",
        "#cCCCCCCCCCb#", "#ccCCCCCCCbb#", ".#ccCCCCCbb#.", "..#ccCCCbb#..", "...#ccCbb#...", "....#cbb#....",
        ".....#b#.....", "......#......"]
    im = img(13, len(big))
    for y, row in enumerate(big):
        for x, ch in enumerate(row):
            if ch != '.':
                im.putpixel((x, y), C(cm[ch]))
    save(im, 'icons/memory_gem_big.png')
    print('ui kit done')


if __name__ == '__main__':
    main()
