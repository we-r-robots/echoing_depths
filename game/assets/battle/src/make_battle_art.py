"""Battle scene art for Echoing Depths (master palette only, hard bands, no dithering).

Run: python3 game/assets/battle/src/make_battle_art.py
Writes into game/assets/battle/:
  bg_vault.png   672x392 Vault chamber (16 px shake margin on every side; screen (0,0) = (16,16))
  digits.png     damage-number font, 6 colour rows x 14 glyphs "0123456789+-:x", cell 10x13
  burst.png      chromatic impact starburst, 6 frames of 64x64
  slash.png      melee slash crescent, 5 frames of 48x48
  flame.png      brazier flame, 6 frames of 16x28
  glow.png       banded soft light 96x48 (additive)
Uses paint.py from assets/encounter/src (read only).
"""
import os
import sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'encounter', 'src'))
from paint import *  # noqa: E402,F401

OUT = os.path.join(HERE, '..')
M = 16                      # shake margin
W, H = 640 + 2 * M, 360 + 2 * M
HORIZON = 146 + M           # wall meets floor (screen y 146)
VP = (320 + M, -300 + M)    # floor vanishing point
CX = 320 + M
BRAZIERS = [(30 + M, 262 + M), (610 + M, 262 + M)]   # screen coords of brazier bowls


def P(*n):
    return IDX[n[0]] if len(n) == 1 else [IDX[k] for k in n]


# ------------------------------------------------------------------------------------------ bg
def background():
    cv = Canvas(W, H, IDX['ink1'])
    X, Y = cv.x, cv.y
    rng = np.random.default_rng(3)

    # light fields shared by wall and floor
    shaft_c = CX - 10 + (Y - 0) * 0.22          # light shaft falls slightly to the right
    shaft = np.clip(1 - np.abs(X - shaft_c) / (70 + Y * 0.18), 0, 1) ** 1.3
    warm = np.zeros((H, W))
    for bx, by in BRAZIERS:
        d = np.sqrt((X - bx) ** 2 + ((Y - by) * 1.9) ** 2)
        warm = np.maximum(warm, np.clip(1 - d / 150.0, 0, 1) ** 2.0)
    door = radial(cv, CX, 70 + M, 150, 0.8)

    # ------------------------------------------------ back wall: big ashlar blocks
    wall = Y < HORIZON
    nwall = fbm(W, H, 20, 4, 5)
    lw = 0.10 + 0.30 * door ** 1.4 + 0.28 * shaft * smoothstep(0, HORIZON, Y) + 0.40 * warm \
        + 0.10 * (nwall - 0.5) + 0.14 * smoothstep(40 + M, HORIZON, Y)
    cv.shade(wall, lw, ramp('ink1', 'ink2', 'ink3', 'ink4', 'ink5'), 0.0, 0.85)
    # block courses
    course_h = 18
    for yy in range(HORIZON - course_h, -1, -course_h):
        row = (Y >= yy) & (Y < yy + 1) & wall
        cv.put(row & (lw > 0.12), IDX['ink1'])
        lit = (Y >= yy + 1) & (Y < yy + 2) & wall & (lw > 0.36)
        cv.put(lit, IDX['ink5'])
        off = 0 if ((yy // course_h) % 2) else 26
        for xx in range(-off, W, 52):
            j = rng.integers(-6, 6)
            v = (X >= xx + j) & (X < xx + j + 1) & (Y >= yy) & (Y < yy + course_h) & wall
            cv.put(v & (lw > 0.12), IDX['ink1'])

    # pillars framing the vault door and the alcoves
    for px, pw in [(CX - 150, 30), (CX + 120, 30), (CX - 300, 34), (CX + 266, 34)]:
        pm = (X >= px) & (X < px + pw) & wall
        tpl = (X - px) / pw
        cyl = np.sqrt(np.clip(1 - (2 * tpl - 1) ** 2, 0, 1))
        lp = 0.12 + 0.45 * cyl * (0.4 + door + warm) + 0.15 * shaft
        flutes = (np.abs(np.sin(tpl * np.pi * 5)) < 0.18)
        cv.shade(pm, lp - 0.08 * flutes, ramp('ink1', 'ink2', 'ink3', 'ink4', 'ink5', 'ink6'), 0.0, 1.0)
        cv.put(edge_of(pm) & ((X == px) | (X == px + pw - 1)), IDX['ink1'])
        # base plinth
        base = (X >= px - 4) & (X < px + pw + 4) & (Y >= HORIZON - 12) & (Y < HORIZON)
        cv.shade(base, 0.25 + 0.4 * (warm + door * 0.5) + 0.1 * (Y == HORIZON - 12), ramp('ink2', 'ink3', 'ink4', 'ink5'), 0, 1)
        cv.put(base & (Y == HORIZON - 12), IDX['ink6'])
        cv.put(outer_edge(base) & wall & ~pm, IDX['ink1'])
        # capital band
        cap = (X >= px - 3) & (X < px + pw + 3) & (Y >= 18 + M) & (Y < 26 + M)
        cv.shade(cap, 0.3 + 0.3 * door, ramp('ink2', 'ink3', 'ink4', 'ink5'), 0, 1)
        cv.put(cap & (Y == 18 + M), IDX['ink6'])

    # arched alcoves between outer pillars and inner pillars, each with a Lumari statue silhouette
    for acx in [CX - 225, CX + 225]:
        d = np.sqrt((X - acx) ** 2 + ((Y - (70 + M)) * 1.0) ** 2)
        arch = ((d < 40) & (Y < 70 + M)) | ((np.abs(X - acx) < 40) & (Y >= 70 + M) & (Y < HORIZON - 12))
        inner = 0.05 + 0.18 * np.clip(1 - np.abs(X - acx) / 40, 0, 1) + 0.25 * warm
        cv.shade(arch, inner, ramp('ink1', 'ink2', 'ink3'), 0, 0.6)
        cv.put(outer_edge(arch) & wall, IDX['ink4'])
        cv.put(shift(outer_edge(arch), 0, -1) & wall & ~arch, IDX['ink2'])
        # statue: robed figure holding a lantern (silhouette + rim light)
        sx = acx
        body = poly_mask(cv, [(sx - 13, HORIZON - 12), (sx - 9, 78 + M), (sx - 6, 66 + M), (sx + 6, 66 + M),
                              (sx + 9, 78 + M), (sx + 13, HORIZON - 12)])
        head = ellipse_mask(cv, sx, 58 + M, 7, 9)
        hood = poly_mask(cv, [(sx - 8, 62 + M), (sx, 46 + M), (sx + 8, 62 + M)])
        st = body | head | hood
        cv.put(st, IDX['ink2'])
        rim_side = (X > sx + 2) if acx < CX else (X < sx - 2)
        cv.put(edge_of(st) & rim_side, IDX['ink4'])
        # stone lantern in hands, cold crystal light
        lx = sx + (8 if acx < CX else -8)
        lan = ellipse_mask(cv, lx, 86 + M, 3, 4)
        cv.put(radial(cv, lx, 86 + M, 16) > 0.35, IDX['crystal1'])
        cv.put(st & (radial(cv, lx, 86 + M, 16) > 0.35), IDX['ink3'])
        cv.put(lan, IDX['crystal4'])
        cv.put(ellipse_mask(cv, lx, 85 + M, 1.2, 1.6), IDX['crystal5'])
        cv.put(outer_edge(lan), IDX['ink1'])

    # the vault door: concentric stone rings with a crystal glyph ring and a sealed eye
    dcx, dcy = CX, 76 + M
    d = np.sqrt((X - dcx) ** 2 + (Y - dcy) ** 2)
    ang = np.arctan2(Y - dcy, X - dcx)
    halo = (d < 92) & (d >= 70) & wall
    cv.shade(halo, 0.35 * np.clip(1 - (d - 70) / 22, 0, 1) + 0.1 * shaft, ramp('ink2', 'crystal1', 'crystal1'), 0, 0.45)
    ring_o = (d < 70) & (d >= 62)
    cv.shade(ring_o, 0.45 + 0.35 * np.cos(ang + 2.2) * 0.5 + 0.2 * shaft, ramp('ink2', 'ink3', 'ink4', 'ink5', 'ink6'), 0, 1)
    cv.put((np.abs(d - 70) < 0.6), IDX['ink1'])
    cv.put((np.abs(d - 62) < 0.6), IDX['ink1'])
    # ring segments (stone keys)
    keys = ring_o & (np.abs(np.sin(ang * 12)) < 0.06)
    cv.put(keys, IDX['ink1'])
    disc = d < 62
    cv.shade(disc, 0.25 + 0.22 * np.clip(1 - d / 62, 0, 1) + 0.25 * shaft + 0.08 * (fbm(W, H, 10, 3, 9) - 0.5),
             ramp('ink2', 'ink3', 'ink4', 'ink5'), 0, 0.85)
    glyph_r = (np.abs(d - 50) < 4.5)
    marks = glyph_r & (np.abs(np.sin(ang * 18)) > 0.55) & (np.abs(np.sin(ang * 18 * 3 + d)) > 0.3)
    cv.put(glyph_r & ~marks, IDX['ink2'])
    cv.put(marks, IDX['crystal2'])
    cv.put(marks & (np.sin(ang * 5 + 1) > 0.4), IDX['crystal3'])
    cv.put(np.abs(d - 45) < 0.6, IDX['ink1'])
    cv.put(np.abs(d - 55) < 0.6, IDX['ink1'])
    # seam cross
    cv.put(disc & (d < 44) & ((np.abs(X - dcx) < 0.6) | (np.abs(Y - dcy) < 0.6)), IDX['ink1'])
    # central eye/lantern sigil
    eye = (((X - dcx) / 16) ** 2 + ((Y - dcy) / 8) ** 2 < 1) & (d < 20)
    cv.put(radial(cv, dcx, dcy, 30) > 0.2, IDX['crystal1'])
    cv.put(radial(cv, dcx, dcy, 30) > 0.5, IDX['crystal2'])
    cv.put(eye, IDX['crystal3'])
    cv.put(eye & (d < 5), IDX['crystal4'])
    cv.put(d < 2.2, IDX['crystal5'])
    cv.put(outer_edge(eye), IDX['ink1'])

    # crystal clusters growing out of the wall base / pillar feet
    def crystal(cx, cy, n, size, seed, lit=1.0):
        r = np.random.default_rng(seed)
        for k in range(n):
            ox = r.integers(-size, size)
            hgt = r.integers(size, size * 3)
            wd = r.integers(2, max(3, size // 2 + 2))
            lean = r.integers(-4, 5)
            pts = [(cx + ox - wd, cy), (cx + ox + wd, cy), (cx + ox + wd // 2 + lean, cy - hgt), (cx + ox - wd // 2 + lean + 1, cy - hgt + 2)]
            m = poly_mask(cv, pts)
            cv.put(m, IDX['crystal2'])
            cv.put(m & (X > cx + ox + lean * (cy - Y) / max(hgt, 1)), IDX['crystal3'])
            cv.put(edge_of(m) & (X < cx + ox), IDX['crystal4'] if lit > 0.5 else IDX['crystal3'])
            cv.put(outer_edge(m) & (cv.idx != IDX['crystal2']) & (cv.idx != IDX['crystal3']), IDX['ink1'])
            cv.put(ellipse_mask(cv, cx + ox + lean + 0.5, cy - hgt + 3, 0.8, 1.5) & m, IDX['crystal5'])
    crystal(CX - 160, HORIZON - 10, 4, 6, 1)
    crystal(CX + 158, HORIZON - 10, 5, 7, 2)
    crystal(CX - 312, HORIZON - 4, 3, 5, 4)
    crystal(CX + 300, HORIZON - 6, 4, 6, 5)

    # ------------------------------------------------ zoomed battle view: keep the lowest wall band
    # The battle camera shows the field at 2x, so the floor fills the screen and the wall is a band
    # above it. Copy the bottom WALL_H rows of the painted wall to the top of a fresh canvas.
    WALL_H = 104
    H0 = WALL_H + M                     # new horizon (screen y 52)
    old = cv.idx.copy()
    cv = Canvas(W, H, IDX['ink1'])
    X, Y = cv.x, cv.y
    cv.idx[:H0, :] = old[HORIZON - H0:HORIZON, :]
    step = (Y >= H0) & (Y < H0 + 4)
    cv.shade(step, 0.45 - 0.002 * np.abs(X - CX), ramp('ink2', 'ink3', 'ink4', 'ink5', 'ink6'), 0, 1)
    cv.put((Y == H0), IDX['ink6'])
    cv.put((Y == H0 + 4), IDX['ink1'])

    # ------------------------------------------------ oblique tiled floor (matches battle_layout.gd)
    SLOPE = 20.0 / 22.0
    TW, TH = 58.0, 22.0
    Y0 = 138 + M                          # a seam row (half-way between grid rows)
    fl = Y > H0 + 4
    u = (X - CX - SLOPE * (Y - Y0)) / TW
    v = (Y - Y0) / TH
    ti = np.floor(u).astype(int)
    tj = np.floor(v).astype(int)
    tile_noise = (np.sin(ti * 12.9898 + tj * 78.233) * 43758.5453) % 1.0
    Yc = (tj + 0.5) * TH + Y0
    Xc = (ti + 0.5) * TW + CX + SLOPE * (Yc - Y0)
    BRZ = [(26 + M, 168 + M), (614 + M, 168 + M)]
    arena = np.clip(1 - np.sqrt(((Xc - CX) / 300.0) ** 2 + ((Yc - (170 + M)) / 120.0) ** 2), 0, 1) ** 0.7
    warm_t = np.zeros_like(Xc)
    for bx, by in BRZ:
        d = np.sqrt((Xc - bx) ** 2 + ((Yc - by) * 1.4) ** 2)
        warm_t = np.maximum(warm_t, np.clip(1 - d / 130.0, 0, 1) ** 1.6)
    shaft_t = np.clip(1 - np.abs(Xc - (CX - 30 + Yc * 0.25)) / 90.0, 0, 1)
    lf = 0.16 + 0.26 * arena + 0.12 * shaft_t + 0.06 * (tile_noise - 0.5) \
        + 0.08 * smoothstep(H0 + 30, H0, Yc) - 0.14 * smoothstep(300 + M, 392, Yc)
    cv.shade(fl, lf, ramp('ink1', 'ink2', 'ink3', 'ink4', 'ink5', 'ink6'), 0.0, 0.95)
    wl = warm_t + 0.08 * (tile_noise - 0.5)
    for th, col in [(0.30, 'amber1'), (0.55, 'skin1'), (0.80, 'amber2')]:
        cv.put(fl & (wl > th), IDX[col])
    fu = u - np.floor(u)
    fv = v - np.floor(v)
    seam_u = (fu < 1.0 / TW) & fl
    seam_v = (fv < 1.0 / TH) & fl
    seams = seam_u | seam_v
    cv.put(seams, IDX['ink1'])
    lip = shift(seam_v, 0, 1) & ~seams & fl
    cur = cv.idx.copy()
    for a_, b_ in [('ink3', 'ink4'), ('ink4', 'ink5'), ('ink5', 'ink6'), ('amber1', 'skin1'), ('skin1', 'amber2'), ('amber2', 'amber3')]:
        cv.put(lip & (cur == IDX[a_]), IDX[b_])
    for k in range(26):
        x0 = rng.integers(M, W - M); y0 = rng.integers(H0 + 14, H - 30)
        pts = [(x0, y0)]
        for s_ in range(rng.integers(3, 6)):
            x0 += rng.integers(-9, 10); y0 += rng.integers(-2, 4)
            pts.append((x0, y0))
        cv.put(line_mask(cv, pts, 1) & fl, IDX['ink1'])
    # central Lumari sigil between the two front lines, faint crystal
    scx, scy = CX, 226 + M
    sig_d = np.sqrt(((X - scx - SLOPE * (Y - scy)) / 70.0) ** 2 + ((Y - scy) / 70.0) ** 2)
    for rr, col in [(1.0, 'crystal1'), (0.82, 'crystal1'), (0.36, 'crystal2')]:
        cv.put((np.abs(sig_d - rr) < 0.022) & fl, IDX[col])
    sang = np.arctan2(Y - scy, X - scx - SLOPE * (Y - scy))
    cv.put((sig_d > 0.86) & (sig_d < 0.96) & (np.abs(np.sin(sang * 22)) > 0.75) & fl, IDX['crystal2'])
    cv.put((sig_d > 0.40) & (sig_d < 0.78) & (np.abs(np.sin(sang * 4)) < 0.04) & fl, IDX['crystal1'])
    cv.put((sig_d < 0.10) & fl, IDX['crystal2'])
    # scattered shards
    for k in range(40):
        x0 = rng.integers(M, W - M); y0 = rng.integers(H0 + 10, H - 10)
        r = ellipse_mask(cv, x0, y0, 2, 1)
        cv.put(r, IDX['ink2'])
        cv.put(shift(r, 0, -1) & ~r, IDX['ink4'] if rng.random() < 0.6 else IDX['crystal2'])
    # braziers
    for bx, by in BRZ:
        ped = poly_mask(cv, [(bx - 4, by + 2), (bx + 4, by + 2), (bx + 6, by + 22), (bx - 6, by + 22)])
        cv.shade(ped, 0.6 - 0.02 * (Y - by) + 0.2 * (X < bx), ramp('ink1', 'ink2', 'amber1', 'amber2'), 0, 0.9)
        cv.put(outer_edge(ped), IDX['ink1'])
        base = poly_mask(cv, [(bx - 9, by + 22), (bx + 9, by + 22), (bx + 10, by + 26), (bx - 10, by + 26)])
        cv.put(base, IDX['ink2'])
        cv.put(base & (Y == by + 22), IDX['amber2'])
        bowl = ellipse_mask(cv, bx, by, 12, 5) & (Y >= by - 2)
        cv.shade(bowl, 0.8 - 0.08 * (Y - by + 2), ramp('ink2', 'amber1', 'amber2', 'amber3'), 0, 0.9)
        cv.put(ellipse_mask(cv, bx, by - 2, 11, 2.5), IDX['amber5'])
        cv.put(ellipse_mask(cv, bx, by - 2, 8, 1.5), IDX['amber6'])
        cv.put(outer_edge(bowl | ellipse_mask(cv, bx, by - 2, 11, 2.5)), IDX['ink1'])

    cv.clean(passes=1)
    cv.save(os.path.join(OUT, 'bg_vault.png'))


# ------------------------------------------------------------------------------------- digits
GLYPHS = {
    '0': ["..####..", ".######.", "###..###", "###..###", "###..###", "###..###", "###..###", ".######.", "..####.."],
    '1': ["...###..", "..####..", ".#####..", "...###..", "...###..", "...###..", "...###..", ".#######", ".#######"],
    '2': [".######.", "########", "##...###", "....####", "..#####.", ".####...", "####....", "########", "########"],
    '3': ["#######.", "########", ".....###", "..#####.", "..######", ".....###", "##...###", "########", ".######."],
    '4': ["....###.", "...####.", "..#####.", ".###.##.", "###..##.", "########", "########", ".....##.", ".....##."],
    '5': ["########", "########", "###.....", "#######.", "########", ".....###", "##...###", "########", ".######."],
    '6': ["..#####.", ".######.", "###.....", "#######.", "########", "###..###", "###..###", "########", ".######."],
    '7': ["########", "########", ".....###", "....###.", "...###..", "...###..", "..###...", "..###...", "..###..."],
    '8': [".######.", "########", "###..###", ".######.", ".######.", "###..###", "###..###", "########", ".######."],
    '9': [".######.", "########", "###..###", "###..###", "########", ".#######", ".....###", ".######.", ".#####.."],
    '+': ["........", "...##...", "...##...", ".######.", ".######.", "...##...", "...##...", "........", "........"],
    '-': ["........", "........", "........", ".######.", ".######.", "........", "........", "........", "........"],
    ':': ["........", "...##...", "...##...", "........", "........", "...##...", "...##...", "........", "........"],
    'x': ["........", "........", "##...##.", ".##.##..", "..###...", ".##.##..", "##...##.", "........", "........"],
}
CHARS = "0123456789+-:x"
# rows: fill top, fill bottom (lower 4 rows), outline
DIGIT_ROWS = [
    ('ink10', 'ink9', 'ink1'),       # 0 physical
    ('violet4', 'violet3', 'ink1'),  # 1 magic
    ('amber6', 'amber5', 'ink1'),  # 2 crit
    ('life4', 'life3', 'ink1'),     # 3 heal
    ('blood4', 'blood3', 'ink1'),  # 4 sudden death
    ('fade4', 'fade3', 'ink1'),      # 5 muted / timer
]
CW, CH = 10, 13


def digits():
    img = Image.new('RGBA', (CW * len(CHARS), CH * len(DIGIT_ROWS)), (0, 0, 0, 0))
    px = img.load()
    for r, (top, bot, out) in enumerate(DIGIT_ROWS):
        for c, ch in enumerate(CHARS):
            g = GLYPHS[ch]
            ox, oy = c * CW + 1, r * CH + 2
            on = set()
            for y, line in enumerate(g):
                for x, v in enumerate(line):
                    if v == '#':
                        on.add((x, y))
            for (x, y) in on:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1, 2):
                        q = (x + dx, y + dy)
                        if q not in on:
                            X, Y = ox + q[0], oy + q[1]
                            if 0 <= X < img.width and 0 <= Y < img.height and px[X, Y][3] == 0:
                                px[X, Y] = PAL[out] + (255,)
            for (x, y) in on:
                px[ox + x, oy + y] = PAL[top if y < 5 else bot] + (255,)
    img.save(os.path.join(OUT, 'digits.png'))


# -------------------------------------------------------------------------------------- burst
def burst():
    S = 64
    frames = []
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    c = S / 2 - 0.5
    ang = np.arctan2(yy - c, xx - c)
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2)
    rng = np.random.default_rng(4)
    spikes = rng.random(14) * 0.6 + 0.6
    def spike_r(a, base, amp):
        k = (a + np.pi) / (2 * np.pi) * 14
        i = np.floor(k).astype(int) % 14
        f = k - np.floor(k)
        tri = 1 - np.abs(f - 0.5) * 2
        return base + amp * spikes[i] * tri ** 3
    for f, (base, amp, core, ring) in enumerate([(4, 8, 4, 0), (8, 20, 7, 0), (9, 26, 6, 0), (7, 22, 3, 18), (4, 12, 0, 24), (0, 0, 0, 28)]):
        a = np.zeros((S, S), dtype=np.int32) - 1
        rr = spike_r(ang, base, amp)
        def put(m, name):
            a[m] = IDX[name]
        if base > 0:
            put(d < spike_r(ang + 0.06, base, amp), 'violet3')        # chromatic fringe (offset spikes)
            put(d < spike_r(ang - 0.06, base, amp), 'crystal4')
            put(d < rr, 'ink10')
            put(d < rr * 0.55, 'amber7')
            if core > 0:
                put(d < core, 'ink10')
        if ring > 0:
            put((np.abs(d - ring) < 1.0) & (np.sin(ang * 9 + f) > -0.2), 'crystal5' if f < 5 else 'violet3')
        frames.append(a)
    sheet = Image.new('RGBA', (S * len(frames), S), (0, 0, 0, 0))
    for i, a in enumerate(frames):
        out = np.zeros((S, S, 4), np.uint8)
        m = a >= 0
        out[m, :3] = RGB[a[m]]
        out[m, 3] = 255
        sheet.paste(Image.fromarray(out, 'RGBA'), (i * S, 0))
    sheet.save(os.path.join(OUT, 'burst.png'))


# -------------------------------------------------------------------------------------- slash
def slash():
    S = 48
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    sheet = Image.new('RGBA', (S * 5, S), (0, 0, 0, 0))
    for f in range(5):
        a = np.zeros((S, S), dtype=np.int32) - 1
        # crescent: outer circle minus offset inner circle, swept over an angle window
        cx, cy = 18, 24
        d1 = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        d2 = np.sqrt((xx - cx + 5) ** 2 + (yy - cy) ** 2)
        ang = np.degrees(np.arctan2(yy - cy, xx - cx))
        lo = -80 + f * 10
        hi = -60 + f * 40 if f < 3 else 80
        win = (ang > lo) & (ang < min(hi, 80))
        thick = [5, 7, 7, 4, 2][f]
        cres = (d1 < 21) & (d2 > 21 - thick) & win
        a[cres] = IDX['ink10']
        a[cres & (d2 > 21 - thick * 0.45)] = IDX['amber6'] if f < 3 else IDX['ink9']
        a[cres & (d1 > 19.5)] = IDX['amber5'] if f < 3 else IDX['ink8']
        if f >= 3:
            a[cres & (np.sin(xx * 1.7 + yy) > 0.5)] = -1
        out = np.zeros((S, S, 4), np.uint8)
        m = a >= 0
        out[m, :3] = RGB[a[m]]
        out[m, 3] = 255
        sheet.paste(Image.fromarray(out, 'RGBA'), (f * S, 0))
    sheet.save(os.path.join(OUT, 'slash.png'))


# -------------------------------------------------------------------------------------- flame
def flame():
    Wf, Hf = 16, 28
    sheet = Image.new('RGBA', (Wf * 6, Hf), (0, 0, 0, 0))
    yy, xx = np.mgrid[0:Hf, 0:Wf].astype(float)
    for f in range(6):
        ph = f / 6 * 2 * np.pi
        a = np.zeros((Hf, Wf), dtype=np.int32) - 1
        t = (Hf - 1 - yy) / (Hf - 1)          # 0 bottom .. 1 top
        sway = np.sin(ph + t * 4.0) * 2.2 * t
        wid = 6.5 * (1 - t) ** 0.8 * (1 + 0.15 * np.sin(ph * 2 + t * 9))
        dx = np.abs(xx - 7.5 - sway)
        body = dx < wid
        a[body] = IDX['amber3']
        a[body & (dx < wid * 0.72) & (t < 0.82)] = IDX['amber4']
        a[body & (dx < wid * 0.48) & (t < 0.6)] = IDX['amber5']
        a[body & (dx < wid * 0.28) & (t < 0.38)] = IDX['amber6']
        a[body & (dx < wid * 0.15) & (t < 0.2)] = IDX['amber7']
        # flicker tongues/embers
        r = np.random.default_rng(f + 1)
        for k in range(3):
            ex = int(7 + r.integers(-5, 6)); ey = int(r.integers(1, 9))
            a[ey, ex] = IDX['amber5'] if k else IDX['amber6']
        out = np.zeros((Hf, Wf, 4), np.uint8)
        m = a >= 0
        out[m, :3] = RGB[a[m]]
        out[m, 3] = 255
        sheet.paste(Image.fromarray(out, 'RGBA'), (f * Wf, 0))
    sheet.save(os.path.join(OUT, 'flame.png'))


# --------------------------------------------------------------------------------------- glow
def glow():
    Wg, Hg = 96, 48
    yy, xx = np.mgrid[0:Hg, 0:Wg].astype(float)
    d = np.sqrt(((xx - Wg / 2 + 0.5) / (Wg / 2)) ** 2 + ((yy - Hg / 2 + 0.5) / (Hg / 2)) ** 2)
    l = np.clip(1 - d, 0, 1)
    alpha = np.floor(l * 4) / 4 * 0.55  # 4 hard bands
    out = np.zeros((Hg, Wg, 4), np.uint8)
    out[..., :3] = 255
    out[..., 3] = (alpha * 255).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(os.path.join(OUT, 'glow.png'))


# ------------------------------------------------------------------------------------ crystal
def crystal():
    """The Crystal of Remembrance: a tall faceted crystal on a stone root, 4 frames of inner-glow
    pulse (crystal cyan shell, memory-violet heart). 56x96 per frame, feet at (28, 93)."""
    Wc, Hc = 56, 96
    sheet = Image.new('RGBA', (Wc * 4, Hc), (0, 0, 0, 0))
    for f in range(4):
        cv = Canvas(Wc, Hc)
        X, Y = cv.x, cv.y
        # main spire + two side spires
        main = poly_mask(cv, [(28, 2), (41, 22), (39, 78), (28, 88), (17, 78), (15, 22)])
        left = poly_mask(cv, [(10, 40), (17, 52), (17, 82), (9, 86), (4, 74), (5, 52)])
        right = poly_mask(cv, [(47, 34), (52, 48), (51, 80), (45, 87), (39, 80), (40, 48)])
        body = main | left | right
        # facet shading: light from upper left; facets split by x
        heart = np.exp(-(((X - 28) / 9.0) ** 2 + ((Y - 50) / 20.0) ** 2))
        pulse = [0.0, 0.25, 0.45, 0.25][f]
        l = 0.35 + 0.35 * (X < 28) - 0.15 * (X > 34) + 0.25 * (Y < 30) + (0.5 + pulse) * heart
        cv.shade(main, l, ramp('crystal1', 'crystal2', 'crystal3', 'crystal4', 'crystal5', 'ink10'), 0.0, 1.4)
        cv.shade(left, l - 0.15, ramp('crystal1', 'crystal2', 'crystal3', 'crystal4'), 0.0, 1.2)
        cv.shade(right, l - 0.25, ramp('crystal1', 'crystal2', 'crystal3', 'crystal4'), 0.0, 1.2)
        # memory-violet heart
        hm = main & (heart > 0.45 - 0.15 * pulse)
        cv.shade(hm, heart + pulse, ramp('violet2', 'violet3', 'violet4', 'ink10'), 0.4, 1.5)
        # facet edges
        for a, b in [((28, 2), (28, 88)), ((15, 22), (28, 30)), ((41, 22), (28, 30)), ((28, 30), (28, 88))]:
            m = line_mask(cv, [a, b], 1) & main
            cv.put(m & (X < 29), IDX['crystal5'])
        cv.put(line_mask(cv, [(10, 40), (11, 84)], 1) & left, IDX['crystal4'])
        cv.put(line_mask(cv, [(47, 34), (45, 85)], 1) & right, IDX['crystal3'])
        cv.put(outer_edge(body), IDX['ink1'])
        # stone root
        root = ellipse_mask(cv, 28, 89, 24, 6) & ~body
        cv.shade(root, 0.5 - 0.02 * (Y - 86) + 0.15 * (X < 28), ramp('ink2', 'ink3', 'ink4', 'ink5'), 0, 0.8)
        cv.put(outer_edge(root | body) & (Y > 84), IDX['ink1'])
        # sparkles
        rng = np.random.default_rng(f + 3)
        for k in range(3):
            sx, sy = int(rng.integers(14, 42)), int(rng.integers(8, 70))
            if main[sy, sx]:
                cv.put((np.abs(X - sx) + np.abs(Y - sy)) < 1.5, IDX['ink10'])
        sheet.paste(cv.to_image(), (f * Wc, 0))
    sheet.save(os.path.join(OUT, 'crystal.png'))
    # the Shard that breaks free: 14x26
    cv = Canvas(14, 26)
    X, Y = cv.x, cv.y
    m = poly_mask(cv, [(7, 0), (13, 8), (11, 22), (7, 25), (3, 22), (1, 8)])
    cv.shade(m, 0.4 + 0.4 * (X < 7) + 0.4 * np.exp(-(((X - 7) / 3) ** 2 + ((Y - 12) / 6) ** 2)), ramp('crystal2', 'crystal3', 'crystal4', 'crystal5', 'ink10'), 0, 1.2)
    cv.put(line_mask(cv, [(7, 1), (7, 24)], 1) & m & (Y > 3), IDX['crystal5'])
    cv.put(outer_edge(m), IDX['ink1'])
    cv.save(os.path.join(OUT, 'shard.png'))


if __name__ == '__main__':
    crystal()
    background()
    digits()
    burst()
    slash()
    flame()
    glow()
    print('ok')
