#!/usr/bin/env python3
"""Generates the Echoing Depths UI fonts (original pixel-styled glyphs, CC0 by the project).

Outputs TrueType fonts into ../ :
  depths_sans.ttf        body and labels: cap 11, x-height 8, 1-unit strokes
  depths_sans_bold.ttf   same glyphs with 2-unit vertical stems
  depths_serif.ttf       titles and names: cap 14, x-height 9, 2-unit stems, 1-unit serifs

Every glyph is drawn on a pixel grid (glyphs_sans.py, glyphs_serif.py) and traced into square
outlines. The em is 15 grid units, so a Godot font size of 10 (UI design px, 640x360 space) is
rasterised at 30 px per em on a 1920x1080 screen: exactly 2 screen px per font pixel. Any font
size that is a multiple of 5 lands on whole screen pixels at 1080p (see ui/ui_text.gd).

Run: python3 make_fonts.py [--preview out.png]   (needs fontTools: pip install fonttools)
"""
import os
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

U = 64                 # font units per grid unit
EM = 15                # grid units per em
UPEM = U * EM


def norm(rows):
    w = max(len(r) for r in rows)
    rows = [r.ljust(w, '.') for r in rows]
    while w > 1 and all(r[w - 1] == '.' for r in rows):
        w -= 1
    return [r[:w] for r in rows], w


def smear(rows):
    """Bold: every ink pixel also inks its right neighbour (vertical stems become 2 units)."""
    out = []
    for r in rows:
        w = len(r) + 1
        out.append(''.join('#' if (i < len(r) and r[i] == '#') or (i > 0 and r[i - 1] == '#') else '.' for i in range(w)))
    return out


def cells_of(top, rows):
    """Ink cells as (x, y) with y = the unit's bottom edge, baseline at 0."""
    cells = set()
    for ry, r in enumerate(rows):
        y = top - 1 - ry
        for x, c in enumerate(r):
            if c == '#':
                cells.add((x, y))
    return cells


def trace(cells):
    """Union of unit squares -> closed contours (clockwise outside, counter-clockwise holes, y up)."""
    edges = {}
    def add(a, b):
        edges.setdefault(a, []).append(b)
    for (x, y) in cells:
        if (x, y + 1) not in cells:
            add((x, y + 1), (x + 1, y + 1))       # top, left to right
        if (x + 1, y) not in cells:
            add((x + 1, y + 1), (x + 1, y))       # right, downward
        if (x, y - 1) not in cells:
            add((x + 1, y), (x, y))               # bottom, right to left
        if (x - 1, y) not in cells:
            add((x, y), (x, y + 1))               # left, upward
    loops = []
    while edges:
        start = next(iter(edges))
        loop = [start]
        cur = start
        prev_dir = None
        while True:
            outs = edges[cur]
            if len(outs) > 1 and prev_dir is not None:
                # pinch point: keep turning right so touching corners stay separate loops
                def turn(n):
                    d = (n[0] - cur[0], n[1] - cur[1])
                    cross = prev_dir[0] * d[1] - prev_dir[1] * d[0]
                    return cross   # negative = right turn (clockwise)
                outs.sort(key=turn)
            nxt = outs.pop(0)
            if not outs:
                del edges[cur]
            prev_dir = (nxt[0] - cur[0], nxt[1] - cur[1])
            cur = nxt
            if cur == start:
                break
            loop.append(cur)
        # drop collinear points
        pts = []
        n = len(loop)
        for i in range(n):
            a, b, c = loop[i - 1], loop[i], loop[(i + 1) % n]
            if (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]) != 0:
                pts.append(b)
        loops.append(pts)
    return loops


def glyph_name(ch):
    if ch == ' ':
        return 'space'
    if ch == ' ':
        return 'nbspace'
    return 'uni%04X' % ord(ch)


def build(glyphs, path, family, style, metrics, space, bold=False, overrides=None):
    asc, desc, cap, xh = metrics['asc'], metrics['desc'], metrics['cap'], metrics['xh']
    order = ['.notdef', 'space', 'nbspace']
    cmap = {32: 'space', 0xA0: 'nbspace'}
    shapes = {}
    adv = {}
    for ch, (top, rows) in glyphs.items():
        if overrides and ch in overrides:
            top, rows = overrides[ch]
            rows, w = norm(rows)
        else:
            rows, w = norm(rows)
            if bold:
                rows = smear(rows)
                w += 1
        name = glyph_name(ch)
        order.append(name)
        cmap[ord(ch)] = name
        shapes[name] = trace(cells_of(top, rows))
        adv[name] = w + 1
    sp = space + (1 if bold else 0)
    adv['space'] = sp
    adv['nbspace'] = sp
    shapes['space'] = []
    shapes['nbspace'] = []
    # .notdef: a hollow box
    nd = set()
    for y in range(0, cap):
        for x in range(0, 6):
            if x in (0, 5) or y in (0, cap - 1):
                nd.add((x, y))
    shapes['.notdef'] = trace(nd)
    adv['.notdef'] = 7
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    glyf = {}
    hmtx = {}
    for name in order:
        pen = TTGlyphPen(None)
        xs = []
        for loop in shapes[name]:
            pen.moveTo((loop[0][0] * U, loop[0][1] * U))
            for p in loop[1:]:
                pen.lineTo((p[0] * U, p[1] * U))
            pen.closePath()
            xs += [p[0] for p in loop]
        glyf[name] = pen.glyph()
        hmtx[name] = (adv[name] * U, (min(xs) * U) if xs else 0)
    fb.setupGlyf(glyf)
    fb.setupHorizontalMetrics(hmtx)
    fb.setupHorizontalHeader(ascent=asc * U, descent=-desc * U, lineGap=0)
    fb.setupNameTable({
        'familyName': family, 'styleName': style, 'uniqueFontIdentifier': f'{family} {style}',
        'fullName': f'{family} {style}', 'psName': (family + '-' + style).replace(' ', ''),
        'version': 'Version 2.000', 'copyright': 'Echoing Depths project, CC0 1.0',
        'licenseDescription': 'CC0 1.0 Universal (public domain dedication)',
    })
    fb.setupOS2(sTypoAscender=asc * U, sTypoDescender=-desc * U, sTypoLineGap=0,
                usWinAscent=asc * U, usWinDescent=desc * U, sxHeight=xh * U, sCapHeight=cap * U,
                fsType=0, usWeightClass=700 if bold else 400, fsSelection=(0x20 if bold else 0x40) | 0x80)
    fb.setupPost(isFixedPitch=0)
    fb.setupHead(unitsPerEm=UPEM)
    fb.save(path)
    print(os.path.basename(path), len(glyphs), 'glyphs')


def preview(fonts, out_png, scale=3):
    """Pixel preview of every glyph set (ink only, no TTF needed)."""
    from PIL import Image, ImageDraw
    rows_out = []
    for label, glyphs, metrics, bold, overrides in fonts:
        line = []
        for ch, (top, rows) in glyphs.items():
            if overrides and ch in overrides:
                top, rows = overrides[ch]
                rows, w = norm(rows)
            else:
                rows, w = norm(rows)
                if bold:
                    rows = smear(rows)
                    w += 1
            line.append((ch, top, rows, w))
        rows_out.append((label, metrics, line))
    W = 1400
    pad = 4
    y = 0
    placements = []
    for label, metrics, line in rows_out:
        lh = metrics['asc'] + metrics['desc'] + 2
        x = 0
        y += 4
        for ch, top, rows, w in line:
            if x + w + 2 > W // scale:
                x = 0
                y += lh
            placements.append((x, y + metrics['asc'] - top, rows, metrics, y))
            x += w + 2
        y += lh + 4
    img = Image.new('RGB', (W, (y + pad) * scale), (21, 19, 39))
    d = ImageDraw.Draw(img)
    for x, gy, rows, metrics, base_y in placements:
        # baseline guide
        by = base_y + metrics['asc']
        for ry, r in enumerate(rows):
            for rx, c in enumerate(r):
                if c == '#':
                    d.rectangle([(x + rx) * scale, (gy + ry) * scale, (x + rx + 1) * scale - 1, (gy + ry + 1) * scale - 1], fill=(236, 238, 247))
    img.save(out_png)
    print('preview', out_png, img.size)


def main():
    import glyphs_sans as S
    sans_m = {'asc': 12, 'desc': 4, 'cap': S.CAP, 'xh': S.XH}
    fonts = [('sans', S.G, sans_m, False, None), ('sans bold', S.G, sans_m, True, S.BOLD)]
    serif = None
    try:
        import glyphs_serif as T
        serif = T
        serif_m = {'asc': T.ASC_LINE, 'desc': T.DESC_LINE, 'cap': T.CAP, 'xh': T.XH}
        fonts.append(('serif', T.G, serif_m, False, None))
    except ImportError:
        pass
    if '--preview' in sys.argv:
        preview(fonts, sys.argv[sys.argv.index('--preview') + 1])
        return
    build(S.G, os.path.join(OUT, 'depths_sans.ttf'), 'Depths Sans', 'Regular', sans_m, S.SPACE)
    build(S.G, os.path.join(OUT, 'depths_sans_bold.ttf'), 'Depths Sans', 'Bold', sans_m, S.SPACE, bold=True, overrides=S.BOLD)
    if serif:
        build(serif.G, os.path.join(OUT, 'depths_serif.ttf'), 'Depths Serif', 'Regular', serif_m, serif.SPACE)


if __name__ == '__main__':
    main()
