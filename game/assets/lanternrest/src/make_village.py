"""Lanternrest village art (master palette only, hard bands, no dithering).

Run: python3 game/assets/lanternrest/src/make_village.py
Writes into game/assets/lanternrest/:
  sky.png          FAR_W x 360 far layer (dusk sky, moon, distant hills and half-erased roofs);
                   scrolls at half the camera speed
  ground.png       WORLD_W x 360 village ground (meadow, path, plaza, trees), transparent sky
  <place>.png      each tappable place, cropped, painted in world space under the same light
  <place>_hi.png   its 1 px highlight outline (amber), for hover / tap
  lantern_glow.png, vault_glow.png   additive light layers
  flame_0..3.png   the lantern's flame (animated)
  mist.png         a drifting mist band drawn over the fogged side areas
  layout.json      every layer's world position, the places' tap zones and the banner anchor
Uses paint.py / kit.py from assets/encounter/src (read only), like the battle art.
The world is WORLD_W x 360: wider than any screen (640 at 16:9, 780 at 19.5:9), scrolled sideways.
"""
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'encounter', 'src'))
from kit import *  # noqa: E402,F401,F403
from kit import _map  # noqa: E402

OUT = os.path.join(HERE, '..')
WORLD_W, WORLD_H = 1280, 360
FAR_W = 1040                 # >= 780 + (1280 - 640) / 2: covers the widest view at half speed
SKYLINE = 232                # far meadow meets the sky
BACK = 290                   # buildings and plots stand on this line (behind the path)
PATH = (293, 313)            # the road through the village
LANTERN = (640, 96)          # the lantern's flame (world px)
VAULT_X = 360
PLOTS = {'plot_w1': 214, 'plot_w2': 506, 'plot_e1': 800, 'plot_e2': 966, 'plot_e3': 1072}
FOG_W = (0, 176)             # the mist's reach on the west side
FOG_E = (1108, WORLD_W)

layout = {'world': [WORLD_W, WORLD_H], 'far_w': FAR_W, 'layers': {}, 'places': {}}


# ------------------------------------------------------------------ helpers
def lantern_light(cv, r=330.0):
    """0..1 warm light from the lantern, squashed vertically (it pools on the ground)."""
    d = np.sqrt((cv.x - LANTERN[0]) ** 2 + ((cv.y - LANTERN[1] - 150) * 1.6) ** 2)
    return np.clip(1 - d / r, 0, 1)


def edge_dark(cv):
    """Darkening toward the fogged edges of the village (whole ramp steps)."""
    dx = np.abs(cv.x - LANTERN[0])
    return np.clip((dx - 380) / 140.0, 0, 1.0)


def light_world(cv, mask, warm_amt=1.0, base=-0.5):
    """The shared lighting pass for anything painted in world space: lift near the lantern, sink
    toward the edges, tint warm close to the light."""
    lf = lantern_light(cv)
    light_pass(cv, noisy(lf * 2.6 + base, 11, 0.12, cell=30) - edge_dark(cv), mask)
    tint_pass(cv, noisy(lf * 1.25 * warm_amt, 12, 0.12, cell=30), WARM, mask)


def crop_save(cv, name, mask=None):
    """Saves the canvas's painted pixels (within mask) cropped to their bounds; records the offset."""
    m = cv.idx >= 0
    if mask is not None:
        m &= mask
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
    c = Canvas(x1 - x0, y1 - y0)
    c.idx = np.where(m[y0:y1, x0:x1], cv.idx[y0:y1, x0:x1], -1)
    c.save(os.path.join(OUT, name + '.png'))
    layout['layers'][name] = [x0, y0]
    return m


def hi_save(mask, name, color='amber6'):
    """A 1 px outline around a place's silhouette (the hover / tap highlight)."""
    cv = Canvas(WORLD_W, WORLD_H)
    cv.put(outer_edge(mask), IDX[color])
    crop_save(cv, name + '_hi')


def glow_save(name, cx, cy, r, colors, sy=1.0, w=None, h=None):
    w = w or int(r * 2 + 4)
    h = h or int(r * 2 * sy + 4)
    gl = Canvas(w, h)
    lx, ly = w / 2.0, h / 2.0
    d = np.sqrt((gl.x - lx) ** 2 + ((gl.y - ly) / sy) ** 2) / r
    v = np.clip(1 - d, 0, 1) * len(colors)
    out = np.full((h, w), -1)
    for i, c in enumerate(colors):
        frac = np.clip(v - i, 0, 1)
        out = np.where((v > i) & seam_mask(gl, frac * 0.999), IDX[c], out)
    gl.idx = out
    gl.save(os.path.join(OUT, name + '.png'))
    layout['layers'][name] = [int(round(cx - lx)), int(round(cy - ly))]


def place(pid, zone, plate_y=None):
    """A tap zone [x, y, w, h] in world px and the y its name plate sits above."""
    layout['places'][pid] = {'zone': [int(v) for v in zone], 'plate_y': int(plate_y if plate_y is not None else zone[1])}


# ------------------------------------------------------------------ the far layer (sky)
def sky():
    cv = Canvas(FAR_W, WORLD_H, IDX['ink1'])
    X, Y = cv.x, cv.y
    # banded dusk: deep ink at the top, a violet seam and a last indigo light low over the hills
    t = Y / 240.0 + 0.06 * (fbm(FAR_W, WORLD_H, 40, 3, 2) - 0.5)
    cv.shade(np.ones((WORLD_H, FAR_W), bool), t, ramp('ink1', 'ink1', 'ink2', 'ink2', 'ink3', 'violet1', 'ink4'), 0.0, 1.0)
    # long thin clouds catching the last light
    rng = np.random.default_rng(4)
    for i in range(5):
        cx = rng.integers(0, FAR_W); cy = rng.integers(60, 190); ln = rng.integers(50, 150)
        band = (np.abs(Y - cy - 0.04 * (X - cx)) < 1.5 + 1.2 * np.clip(1 - np.abs(X - cx) / ln, 0, 1)) & (np.abs(X - cx) < ln)
        cv.put(band, IDX['ink3'] if cy < 140 else IDX['ink4'])
        cv.put(band & ~shift(band, 0, 1), IDX['ink4'] if cy < 140 else IDX['violet1'])
    # stars, few and still
    for i in range(70):
        sx, sy = int(rng.integers(2, FAR_W - 2)), int(rng.integers(30, 170))
        cv.idx[sy, sx] = IDX['ink7'] if rng.random() < 0.7 else IDX['ink9']
        if rng.random() < 0.08:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                cv.idx[sy + dy, sx + dx] = IDX['ink6']
    # a thin moon, high and to the east of the lantern
    mx, my = 780, 62
    moon = ellipse_mask(cv, mx, my, 9, 9) & ~ellipse_mask(cv, mx + 5, my - 2, 8, 8)
    cv.put(ellipse_mask(cv, mx, my, 15, 15) & ~ellipse_mask(cv, mx, my, 9, 9) & seam_mask(cv, np.full((WORLD_H, FAR_W), 0.5)), IDX['ink3'])
    cv.put(moon, IDX['ink9'])
    cv.put(moon & (X < mx - 4), IDX['ink10'])
    # far hills, two ridges, the nearer one darker
    xs = np.arange(FAR_W)
    for k, (base, amp, tone, rimc, seed) in enumerate(((206, 16, 'ink3', 'ink4', 5), (222, 12, 'ink2', 'ink3', 9))):
        n = fbm(FAR_W, 1, 70, 3, seed)[0]
        top = base - amp * n - 6 * np.sin(xs / 90.0 + k)
        ridge = Y >= top[None, :]
        cv.put(ridge, IDX[tone])
        cv.put(ridge & ~shift(ridge, 0, 1), IDX[rimc])
        if k == 0:
            # half-erased roofs and a broken tower on the far ridge: the old town, faded grey
            for (rx, w, h) in ((140, 14, 10), (162, 10, 8), (420, 12, 9), (436, 8, 14), (790, 16, 9), (812, 9, 7), (960, 12, 8)):
                ry = int(top[rx]) + 2
                house = poly_mask(cv, [(rx, ry), (rx + w, ry), (rx + w, ry - h), (rx + w // 2, ry - h - 6), (rx, ry - h)])
                cv.put(house, IDX['fade1'])
                cv.put(house & (value_noise(FAR_W, WORLD_H, 2, rx) < 0.3), IDX['ink3'])
            tx = 600
            ty = int(top[tx]) + 2
            tower = (X >= tx) & (X < tx + 7) & (Y < ty) & (Y >= ty - 26 + (X - tx) % 3)
            cv.put(tower, IDX['fade1'])
    # a low mist band along the far meadow
    mist = (Y > 224) & (Y < 232) & (fbm(FAR_W, WORLD_H, 30, 2, 8) > 0.45)
    cv.put(mist, IDX['ink4'])
    cv.clean(passes=1)
    cv.save(os.path.join(OUT, 'sky.png'))


# ------------------------------------------------------------------ the ground layer
def ground():
    cv = Canvas(WORLD_W, WORLD_H)
    X, Y = cv.x, cv.y
    xs = np.arange(WORLD_W)
    # the near meadow's top edge: gentle swells, a rise behind the vault (the hill is the vault's)
    n = fbm(WORLD_W, 1, 60, 3, 21)[0]
    top = SKYLINE - 6 * n - 3 * np.sin(xs / 70.0)
    land = Y >= top[None, :]
    cv.shade(land, 0.35 + 0.25 * smoothstep(SKYLINE, 300, Y) + 0.1 * (fbm(WORLD_W, WORLD_H, 14, 3, 3) - 0.5),
             ramp('ink2', 'ink3', 'ink3', 'ink4', 'ink4'), 0, 1)
    cv.put(land & ~shift(land, 0, 1), IDX['ink4'])
    # meadow tufts in rows (texture, read as grass, not noise)
    rng = np.random.default_rng(31)
    for i in range(520):
        tx, ty = int(rng.integers(0, WORLD_W)), int(rng.integers(SKYLINE + 4, WORLD_H - 2))
        if PATH[0] - 2 <= ty <= PATH[1] + 2:
            continue
        h = 1 + int(rng.integers(0, 3)) + (ty - SKYLINE) // 50
        for k in range(h):
            if 0 <= ty - k < WORLD_H:
                cv.idx[ty - k, tx] = IDX['life2'] if k == h - 1 else IDX['life1']
        if tx + 1 < WORLD_W and h > 1:
            cv.idx[ty - 1, tx + 1] = IDX['life1']
    # the road: packed earth, ruts, edged by a darker verge
    road_top = PATH[0] + 1.5 * np.sin(xs / 45.0)
    road_bot = PATH[1] + 2.0 * np.sin(xs / 60.0 + 1)
    road = (Y >= road_top[None, :]) & (Y <= road_bot[None, :])
    cv.shade(road, 0.45 + 0.2 * (fbm(WORLD_W, WORLD_H, 8, 2, 41) - 0.5), ramp('ink3', 'ink4', 'ink4', 'ink5'), 0, 1)
    cv.put(road & ~shift(road, 0, 1), IDX['ink2'])
    cv.put(road & ~shift(road, 0, -1), IDX['ink2'])
    for i in range(80):
        px_, py_ = int(rng.integers(0, WORLD_W)), int(rng.integers(PATH[0] + 2, PATH[1] - 1))
        cv.idx[py_, px_] = IDX['ink5']
        if px_ + 1 < WORLD_W:
            cv.idx[py_ + 1, px_ + 1] = IDX['ink2']
    # the plaza around the lantern: worn cobbles in an ellipse
    plaza = ellipse_mask(cv, LANTERN[0], 300, 92, 22)
    tmp = Canvas(WORLD_W, WORLD_H)
    bricks(tmp, np.ones((WORLD_H, WORLD_W), bool), base='ink4', alt='ink5', mortar='ink2', bh=5, seed=8, bw=(6, 11))
    cv.idx[plaza] = tmp.idx[plaza]
    cv.put(outer_edge(plaza) & land, IDX['ink2'])
    # trees: dark crowns at the back, two near the plaza catch the lantern light
    for (tx, ty, r) in ((120, 222, 20), (290, 212, 16), (560, 214, 18), (720, 208, 22), (1010, 214, 18), (1190, 220, 22)):
        trunk = (np.abs(X - tx) < 2 + (Y > ty + r) * 1) & (Y > ty) & (Y < ty + r + 18)
        cv.put(trunk, IDX['ink2'])
        crown = np.zeros((WORLD_H, WORLD_W), bool)
        trng = np.random.default_rng(tx)
        for k in range(6):
            cx_ = tx + trng.integers(-r // 2, r // 2 + 1); cy_ = ty + trng.integers(-r // 2, r // 3)
            crown |= ellipse_mask(cv, cx_, cy_, r * 0.62, r * 0.5)
        lit = np.clip(1 - np.sqrt((X - LANTERN[0]) ** 2 + (Y - LANTERN[1]) ** 2) / 260.0, 0, 1)
        dirx = np.sign(LANTERN[0] - tx)
        face = np.clip(0.5 + 0.5 * dirx * (X - tx) / r, 0, 1)
        cv.shade(crown, 0.15 + 0.35 * face * (0.4 + lit) + 0.15 * (fbm(WORLD_W, WORLD_H, 4, 2, tx) - 0.5),
                 ramp('ink1', 'ink2', 'life1', 'life2', 'life3'), 0, 1)
        cv.put(outer_edge(crown), IDX['ink1'])
    # fence posts along the road's far verge between places
    for fx in list(range(250, 300, 12)) + list(range(560, 586, 12)) + list(range(1000, 1050, 12)):
        post = (X >= fx) & (X < fx + 2) & (Y >= PATH[0] - 9) & (Y < PATH[0])
        cv.put(post, IDX['amber1'])
        cv.put(post & (X == fx), IDX['amber2'])
    # the front verge: a darker band of taller grass at the bottom edge frames the view
    front = (Y > 340 + 4 * fbm(WORLD_W, WORLD_H, 12, 2, 77)) & land
    cv.put(front, IDX['ink2'])
    cv.put(front & ~shift(front, 0, 1), IDX['life1'])

    light_world(cv, cv.idx >= 0)
    # the vault's cold light spills onto the road in front of its door
    cold = np.clip(1 - np.sqrt((X - VAULT_X) ** 2 + ((Y - 300) * 2.2) ** 2) / 70.0, 0, 1)
    tint_pass(cv, noisy(cold * 1.4, 13, 0.3), COOL, cv.idx >= 0)
    cv.clean(passes=1)
    crop_save(cv, 'ground')
    return cv


# ------------------------------------------------------------------ the lantern
def lantern():
    cv = Canvas(WORLD_W, WORLD_H)
    X, Y = cv.x, cv.y
    lx, ly = LANTERN
    fig = np.zeros((WORLD_H, WORLD_W), bool)
    # plinth: three worn steps
    for i, (w, y0) in enumerate(((60, 294), (46, 287), (32, 280))):
        step = (np.abs(X - lx) < w / 2) & (Y >= y0) & (Y < y0 + 7)
        face = 0.35 + 0.45 * np.clip(1 - np.abs(X - lx + 6) / (w / 2), 0, 1)
        cv.shade(step, face, ramp('ink2', 'ink3', 'ink4', 'ink5', 'ink6'), 0, 1)
        cv.put(step & (Y == y0), IDX['ink7'])
        cv.put(step & (Y == y0 + 6), IDX['ink2'])
        fig |= step
    # the post: iron, a lit edge facing the viewer's left, collars
    post = (np.abs(X - lx) < 3.5) & (Y >= 122) & (Y < 280)
    cv.shade(post, np.clip(0.75 - (X - lx + 3) / 7.0, 0, 1) * 0.9, ramp('ink1', 'ink2', 'ink3', 'ink5'), 0, 1)
    fig |= post
    for cy in (150, 210, 262):
        col = (np.abs(X - lx) < 5) & (Y >= cy) & (Y < cy + 3)
        cv.shade(col, np.clip(0.8 - (X - lx + 4) / 10.0, 0, 1), ramp('ink2', 'ink3', 'ink4', 'ink6'), 0, 1)
        fig |= col
    base = (np.abs(X - lx) < 7) & (Y >= 268) & (Y < 280)
    cv.shade(base, np.clip(0.8 - (X - lx + 6) / 14.0, 0, 1), ramp('ink2', 'ink3', 'ink4', 'ink5'), 0, 1)
    fig |= base
    # the arm the banner hangs from
    arm = (X >= lx - 22) & (X < lx) & (Y >= 156) & (Y < 158)
    cv.put(arm, IDX['ink3'])
    cv.put(arm & (Y == 156), IDX['ink5'])
    fig |= arm
    for hx in (lx - 21, lx - 5):
        ring = (X == hx) & (Y >= 158) & (Y < 161)
        cv.put(ring, IDX['ink4'])
        fig |= ring
    # the banner cloth (the team's crest is drawn on it in-engine: layout 'banner')
    bx0, by0 = lx - 24, 160
    cloth = poly_mask(cv, [(bx0, by0), (bx0 + 21, by0), (bx0 + 21, by0 + 30), (bx0 + 10.5, by0 + 25), (bx0, by0 + 30)])
    cv.shade(cloth, 0.45 + 0.35 * np.clip((X - bx0) / 21.0, 0, 1) * 0 + 0.3 * np.sin((X - bx0) / 3.5) ** 2,
             ramp('blood1', 'blood1', 'blood2'), 0, 1)
    cv.put(cloth & (Y == by0), IDX['amber3'])
    fig |= cloth
    layout['banner'] = [int(bx0 + 4), int(by0 + 4)]
    # the lantern housing: a tall crystal-glass cage with an iron cap and finial
    cage = poly_mask(cv, [(lx - 13, 84), (lx + 13, 84), (lx + 10, 120), (lx - 10, 120)])
    glass = poly_mask(cv, [(lx - 10, 87), (lx + 10, 87), (lx + 8, 117), (lx - 8, 117)])
    cv.put(cage, IDX['ink2'])
    gl = np.clip(1 - np.sqrt((X - lx) ** 2 + ((Y - ly) * 0.8) ** 2) / 15.0, 0, 1)
    cv.shade(glass, gl, ramp('amber3', 'amber4', 'amber5', 'amber6', 'amber7'), 0, 0.85)
    bars = glass & ((np.abs(X - lx) < 0.6) | (np.abs(Y - 102) < 0.6))
    cv.put(bars, IDX['amber2'])
    fig |= cage
    cap = poly_mask(cv, [(lx - 17, 85), (lx + 17, 85), (lx + 9, 74), (lx - 9, 74)])
    cv.shade(cap, np.clip(0.8 - (X - lx + 12) / 30.0, 0, 1), ramp('ink1', 'ink2', 'ink3', 'ink4', 'amber2'), 0, 1)
    cv.put(cap & (Y == 84), IDX['amber3'])
    roof = poly_mask(cv, [(lx - 8, 75), (lx + 8, 75), (lx, 62)])
    cv.shade(roof, np.clip(0.7 - (X - lx + 6) / 16.0, 0, 1), ramp('ink1', 'ink2', 'ink3', 'ink4'), 0, 1)
    fin = ellipse_mask(cv, lx, 58, 3, 3) & ~ellipse_mask(cv, lx, 58, 1.2, 1.2)
    cv.put(fin, IDX['ink4'])
    bottom = poly_mask(cv, [(lx - 11, 119), (lx + 11, 119), (lx + 5, 126), (lx - 5, 126)])
    cv.shade(bottom, np.clip(0.9 - (X - lx + 8) / 20.0, 0, 1), ramp('ink1', 'ink2', 'ink3', 'amber2'), 0, 1)
    fig |= cap | roof | fin | bottom
    cv.put(outer_edge(fig), IDX['ink1'])
    fig |= outer_edge(fig)
    # warm rim on the side of everything facing the glass, then the world light
    rimm = edge_of(fig) & (Y > 120) & (X > lx - 30) & (cv.idx != IDX['ink1'])
    light_world(cv, fig & ~glass, warm_amt=1.3, base=-0.4)
    cv.put(rimm & (X < lx) & (Y < 200) & ~cloth, IDX['amber3'])
    cv.clean(mask=fig & ~glass, passes=1)
    m = crop_save(cv, 'lantern')
    hi_save(m, 'lantern')
    place('lantern', [lx - 32, 54, 64, 248], plate_y=52)
    glow_save('lantern_glow', lx, ly + 6, 120, ['amber1', 'amber2', 'amber3'], sy=0.9)
    # the flame: four frames of a small amber tongue inside the glass
    for f in range(4):
        fc = Canvas(9, 16)
        sway = (0, 1, 0, -1)[f]
        hgt = (11, 12, 10, 12)[f]
        for y in range(16):
            t = (15 - y) / hgt
            if t > 1:
                continue
            half = 3.6 * np.sin(np.pi * min(t * 1.15, 1.0)) * (1 - 0.35 * t)
            cxp = 4 + sway * t
            for x in range(9):
                d = abs(x - cxp)
                if d <= half:
                    fc.idx[y, x] = IDX['amber7'] if d < half * 0.4 and t < 0.7 else IDX['amber6'] if d < half * 0.75 else IDX['amber5']
        fc.save(os.path.join(OUT, 'flame_%d.png' % f))
    layout['layers']['flame'] = [lx - 4, ly - 4]


# ------------------------------------------------------------------ the vault entrance
def vault():
    cv = Canvas(WORLD_W, WORLD_H)
    X, Y = cv.x, cv.y
    vx = VAULT_X
    xs = np.arange(WORLD_W)
    # the hill the stair is cut into: faceted rock, a grassy crown
    n = fbm(WORLD_W, 1, 26, 3, 61)[0]
    ht = 168 + 40 * ((xs - vx) / 104.0) ** 2 + 8 * n
    hill = (Y >= ht[None, :]) & (np.abs(X - vx) < 104) & (Y < BACK + 2)
    hill &= ~((Y > 270) & (np.abs(X - vx) > 92 - (Y - 270) * 0.8))
    rock(cv, hill, ('ink1', 'ink2', 'ink3', 'ink4', 'ink5'), (LANTERN[0] - 100, 120), seed=62, scale=16)
    crown = hill & (Y < ht[None, :] + 4 + 3 * value_noise(WORLD_W, WORLD_H, 3, 63))
    cv.put(crown, IDX['life1'])
    cv.put(crown & ~shift(crown, 0, 1), IDX['life2'])
    fig = hill.copy()
    # the doorway: two carved pillars and a lintel, a dark stair falling into cold light
    door = ((np.abs(X - vx) < 19) & (Y >= 238) & (Y < BACK)) | ellipse_mask(cv, vx, 238, 19, 14)
    door &= Y < BACK
    frame = ((np.abs(X - vx) < 30) & (Y >= 226) & (Y < BACK)) | ellipse_mask(cv, vx, 232, 30, 24)
    frame &= (Y < BACK) & ~door
    tmp = Canvas(WORLD_W, WORLD_H)
    bricks(tmp, frame, base='ink4', alt='ink5', mortar='ink2', bh=6, seed=64, bw=(6, 10))
    cv.idx[frame] = tmp.idx[frame]
    lintel = (np.abs(X - vx) < 34) & (Y >= 204) & (Y < 212)
    cv.shade(lintel, 0.5 + 0.3 * np.clip((LANTERN[0] - X) / -300.0 + 1, 0, 1), ramp('ink2', 'ink3', 'ink4', 'ink5', 'ink6'), 0, 1)
    cv.put(lintel & (Y == 204), IDX['ink7'])
    cv.put(lintel & (Y == 211), IDX['ink2'])
    # a carved crystal sigil on the keystone
    key = poly_mask(cv, [(vx, 196), (vx + 6, 206), (vx, 216), (vx - 6, 206)])
    cv.put(key, IDX['ink5'])
    cv.put(poly_mask(cv, [(vx, 200), (vx + 3, 206), (vx, 212), (vx - 3, 206)]), IDX['crystal4'])
    cv.idx[205, vx - 1] = IDX['crystal5']
    cv.put(outer_edge(key), IDX['ink1'])
    # the stair: steps narrowing into the dark, lit cyan from below
    cv.put(door, IDX['ink1'])
    for i in range(6):
        sy = BACK - 3 - i * 7
        st = door & (Y >= sy) & (Y < sy + 3) & (np.abs(X - vx) < 17 - i * 2)
        cv.put(st, IDX['crystal1'] if i < 3 else IDX['ink2'])
        cv.put(st & (Y == sy), IDX['crystal2'] if i < 2 else IDX['crystal1'])
    deep = door & ellipse_mask(cv, vx, 250, 9, 7)
    cv.put(deep, IDX['crystal1'])
    cv.put(door & ellipse_mask(cv, vx, 251, 4, 3), IDX['crystal2'])
    fig |= frame | lintel | key | door
    # standing stones either side, old ropes of faded cloth between them
    for sx_, h in ((vx - 54, 34), (vx + 56, 28)):
        stone = poly_mask(cv, [(sx_ - 6, BACK), (sx_ + 6, BACK), (sx_ + 4, BACK - h), (sx_ - 1, BACK - h - 4), (sx_ - 5, BACK - h + 2)])
        cv.shade(stone, 0.4 + 0.4 * np.clip((X - sx_ + 6) / 12.0, 0, 1) * (1 if sx_ > vx else 0.4), ramp('ink2', 'ink3', 'ink4', 'ink5'), 0, 1)
        cv.put(outer_edge(stone), IDX['ink1'])
        fig |= stone | outer_edge(stone)
    for k in range(3):
        rope = line_mask(cv, [(vx - 52, BACK - 30 + k * 3), (vx - 32, BACK - 22 + k * 4)], 1)
        cv.put(rope & ~door, IDX['fade2'] if k != 1 else IDX['blood2'])
    cv.put(outer_edge(fig) & (Y < BACK + 1), IDX['ink1'])
    fig |= outer_edge(fig) & (Y < BACK + 1)
    light_world(cv, fig & ~door & ~key, warm_amt=0.8, base=-0.6)
    cv.clean(mask=fig & ~door, passes=1)
    m = crop_save(cv, 'vault')
    hi_save(m, 'vault')
    place('vault', [vx - 40, 196, 80, BACK - 196 + 6], plate_y=170)
    glow_save('vault_glow', vx, 262, 34, ['crystal1', 'crystal2'], sy=1.1)


# ------------------------------------------------------------------ empty plots
def plot(pid, cx, seed):
    cv = Canvas(WORLD_W, WORLD_H)
    X, Y = cv.x, cv.y
    rng = np.random.default_rng(seed)
    w, d = 64, 14
    y1 = BACK
    y0 = BACK - d
    fig = np.zeros((WORLD_H, WORLD_W), bool)
    # bare earth inside an old foundation of fitted stones (a trapezoid seen from the road)
    earth = poly_mask(cv, [(cx - w / 2 + 6, y0), (cx + w / 2 - 6, y0), (cx + w / 2, y1), (cx - w / 2, y1)])
    cv.shade(earth, 0.4 + 0.25 * (fbm(WORLD_W, WORLD_H, 6, 2, seed) - 0.5), ramp('ink2', 'amber1', 'ink3', 'ink3'), 0, 1)
    fig |= earth
    edge = outer_edge(earth) | edge_of(earth)
    stones = edge & (value_noise(WORLD_W, WORLD_H, 3, seed + 1) > 0.32)
    cv.put(stones, IDX['ink5'])
    cv.put(stones & ~shift(stones, 0, 1), IDX['ink6'])
    cv.put(stones & ~shift(stones, 0, -1), IDX['ink3'])
    fig |= stones
    # a few weeds and a stake with a blank board: room to build
    for i in range(10):
        wx = int(rng.integers(cx - w // 2 + 4, cx + w // 2 - 4)); wy = int(rng.integers(y0 + 2, y1 - 1))
        for k in range(int(rng.integers(1, 4))):
            cv.idx[wy - k, wx] = IDX['life2'] if k else IDX['life1']
            fig[wy - k, wx] = True
    sx = cx - w // 2 + 10 + int(rng.integers(0, 8))
    stake = (X >= sx) & (X < sx + 2) & (Y >= y0 - 18) & (Y < y0 + 6)
    cv.put(stake, IDX['amber1'])
    cv.put(stake & (X == sx), IDX['amber2'])
    board = (X >= sx - 6) & (X < sx + 8) & (Y >= y0 - 18) & (Y < y0 - 10)
    cv.put(board, IDX['amber2'])
    cv.put(board & (Y == y0 - 18), IDX['amber3'])
    cv.put(outer_edge(board | stake), IDX['ink1'])
    fig |= board | stake | outer_edge(board | stake)
    # a thin skin of grey: the Fading has the plot, the light has not yet reached it
    light_world(cv, fig, warm_amt=0.7, base=-0.3)
    m = crop_save(cv, pid)
    hi_save(m, pid)
    place(pid, [cx - w // 2 - 2, y0 - 22, w + 4, d + 26], plate_y=y0 - 22)


# ------------------------------------------------------------------ the Training Grounds
def grounds(cx=PLOTS['plot_e1']):
    """A barracks yard: a long timber hall with a lit window, a fenced yard with two training
    dummies and an archery target, a weapon rack by the door."""
    cv = Canvas(WORLD_W, WORLD_H)
    X, Y = cv.x, cv.y
    fig = np.zeros((WORLD_H, WORLD_W), bool)
    TIMBER = ramp('ink1', 'amber1', 'amber1', 'amber2', 'amber3')
    hx0, hx1 = cx - 82, cx + 2
    wall_top, base = 250, BACK
    # the yard floor: trodden sand
    yard = poly_mask(cv, [(hx1 - 4, base - 12), (cx + 84, base - 12), (cx + 88, base + 1), (hx1 - 8, base + 1)])
    cv.shade(yard, 0.45 + 0.3 * (fbm(WORLD_W, WORLD_H, 6, 2, 81) - 0.5), ramp('ink3', 'amber1', 'amber2', 'amber2'), 0, 1)
    fig |= yard
    # hall walls: vertical planks on a stone footing
    wall = (X >= hx0) & (X < hx1) & (Y >= wall_top) & (Y < base)
    plank = (np.floor((X - hx0) / 5) % 2)
    cv.shade(wall, 0.55 + 0.15 * plank + 0.1 * (fbm(WORLD_W, WORLD_H, 5, 2, 82) - 0.5), TIMBER, 0, 1)
    cv.put(wall & (((X - hx0) % 5) == 0), IDX['amber1'])
    footing = (X >= hx0 - 2) & (X < hx1 + 2) & (Y >= base - 5) & (Y < base)
    tmp = Canvas(WORLD_W, WORLD_H)
    bricks(tmp, footing, base='ink4', alt='ink5', mortar='ink2', bh=3, seed=83, bw=(4, 8))
    cv.idx[footing] = tmp.idx[footing]
    # beams
    for bx_ in (hx0, hx0 + 28, hx0 + 56, hx1 - 3):
        beam = (X >= bx_) & (X < bx_ + 3) & (Y >= wall_top) & (Y < base - 5)
        cv.put(beam, IDX['amber2'])
        cv.put(beam & (X == bx_), IDX['amber3'])
    fig |= wall | footing
    # roof: dark slate in courses, eaves overhanging
    roof = poly_mask(cv, [(hx0 - 7, wall_top + 2), (hx1 + 7, wall_top + 2), (hx1 - 6, 222), (hx0 + 6, 222)])
    cv.shade(roof, 0.3 + 0.5 * smoothstep(222, 252, Y), ramp('ink1', 'ink2', 'ink3', 'ink4', 'ink5'), 0, 1)
    cv.put(roof & ((Y - 222) % 5 == 0), IDX['ink2'])
    cv.put(roof & (Y == 222), IDX['ink5'])
    ridge = (X >= hx0 + 5) & (X < hx1 - 5) & (Y >= 220) & (Y < 222)
    cv.put(ridge, IDX['ink4'])
    chimney = (X >= hx0 + 14) & (X < hx0 + 21) & (Y >= 210) & (Y < 226)
    tmp = Canvas(WORLD_W, WORLD_H)
    bricks(tmp, chimney, base='ink4', alt='ink5', mortar='ink2', bh=3, seed=84, bw=(3, 5))
    cv.idx[chimney] = tmp.idx[chimney]
    fig |= roof | ridge | chimney
    # door (dark, a lit crack) and a warm window: someone trains here now
    door = (X >= hx0 + 34) & (X < hx0 + 48) & (Y >= base - 27) & (Y < base - 5)
    cv.put(door, IDX['amber1'])
    cv.put(door & (X == hx0 + 34), IDX['amber2'])
    cv.put(door & (X == hx0 + 47), IDX['ink1'])
    cv.put((X == hx0 + 41) & (Y >= base - 25) & (Y < base - 6), IDX['ink2'])
    win = (X >= hx0 + 10) & (X < hx0 + 24) & (Y >= wall_top + 9) & (Y < wall_top + 20)
    cv.shade(win, np.clip(1 - np.abs(X - hx0 - 17) / 9.0, 0, 1), ramp('amber3', 'amber4', 'amber5', 'amber6'), 0, 1)
    cv.put(win & ((X == hx0 + 17) | (Y == wall_top + 14)), IDX['amber2'])
    cv.put(outer_edge(win), IDX['ink1'])
    win2 = (X >= hx0 + 60) & (X < hx0 + 72) & (Y >= wall_top + 9) & (Y < wall_top + 20)
    cv.shade(win2, np.clip(1 - np.abs(X - hx0 - 66) / 8.0, 0, 1), ramp('amber2', 'amber3', 'amber4', 'amber5'), 0, 1)
    cv.put(win2 & ((X == hx0 + 66) | (Y == wall_top + 14)), IDX['amber1'])
    cv.put(outer_edge(win2), IDX['ink1'])
    # a sign board over the door: crossed swords, burnt in
    sign = (X >= hx0 + 31) & (X < hx0 + 51) & (Y >= wall_top + 1) & (Y < wall_top + 9)
    cv.put(sign, IDX['amber3'])
    cv.put(sign & (Y == wall_top + 1), IDX['amber4'])
    cv.put(line_mask(cv, [(hx0 + 35, wall_top + 7), (hx0 + 46, wall_top + 2)], 1) | line_mask(cv, [(hx0 + 35, wall_top + 2), (hx0 + 46, wall_top + 7)], 1), IDX['amber1'])
    cv.put(outer_edge(sign), IDX['ink1'])
    # weapon rack by the door: three spears and a shield
    rx = hx0 + 52
    for k in range(3):
        cv.put(line_mask(cv, [(rx + k * 3, base - 1), (rx + 2 + k * 3, base - 30)], 1), IDX['amber2'])
        cv.idx[base - 31, rx + 2 + k * 3] = IDX['ink8']
        cv.idx[base - 32, rx + 2 + k * 3] = IDX['ink9']
    shield = ellipse_mask(cv, rx + 9, base - 9, 4, 5)
    cv.put(shield, IDX['blood2'])
    cv.put(shield & (X < rx + 9), IDX['blood3'])
    cv.put(outer_edge(shield), IDX['ink1'])
    rack = (X >= rx - 1) & (X < rx + 11) & (Y == base - 16)
    cv.put(rack, IDX['amber1'])
    fig |= line_mask(cv, [(rx, base), (rx + 10, base - 32)], 3) | shield | rack
    # training dummies: a post, a crossbar for arms, a straw sack body and a round head
    STRAW = ramp('amber1', 'amber2', 'amber3', 'amber4', 'amber5')
    for dx_ in (cx + 18, cx + 44):
        post = (X >= dx_ - 1) & (X < dx_ + 1) & (Y >= base - 34) & (Y < base)
        cv.put(post, IDX['amber1'])
        bar = (X >= dx_ - 9) & (X < dx_ + 10) & (Y >= base - 26) & (Y < base - 24)
        cv.put(bar, IDX['amber2'])
        cv.put(bar & (Y == base - 26), IDX['amber3'])
        body = ellipse_mask(cv, dx_, base - 17, 5, 9)
        lam = np.clip(0.5 + 0.5 * (LANTERN[0] - X) / 8.0 * 0.0 + 0.5 * -(X - dx_) / 5.0, 0, 1)
        cv.shade(body, 0.25 + 0.55 * lam, STRAW, 0, 1)
        for by_ in (base - 22, base - 12):
            cv.put(body & (Y == by_), IDX['amber1'])
        head = ellipse_mask(cv, dx_, base - 31, 4, 4)
        cv.shade(head, 0.3 + 0.5 * np.clip(-(X - dx_) / 4.0 + 0.5, 0, 1), STRAW, 0, 1)
        m_ = post | bar | body | head
        cv.put(outer_edge(m_), IDX['ink1'])
        fig |= m_ | outer_edge(m_)
    # the archery target on its easel: rings of white, red and gold
    tx_, ty_ = cx + 72, base - 22
    legs = line_mask(cv, [(tx_ - 6, base), (tx_, ty_ - 10)], 1) | line_mask(cv, [(tx_ + 6, base), (tx_, ty_ - 10)], 1) | line_mask(cv, [(tx_ + 2, base), (tx_ + 1, ty_)], 1)
    cv.put(legs, IDX['amber1'])
    d = np.sqrt((X - tx_) ** 2 + (Y - ty_) ** 2)
    tgt = d < 9.5
    cv.put(tgt, IDX['fade4'])
    cv.put(d < 7.5, IDX['blood3'])
    cv.put(d < 5.5, IDX['fade4'])
    cv.put(d < 3.5, IDX['blood3'])
    cv.put(d < 1.6, IDX['amber5'])
    cv.put(tgt & (X > tx_ + 3) & (d > 7.5), IDX['fade3'])
    # two arrows in it
    for (ax_, ay_) in ((tx_ - 2, ty_ - 3), (tx_ + 4, ty_ + 2)):
        cv.put(line_mask(cv, [(ax_, ay_), (ax_ - 6, ay_ - 4)], 1), IDX['amber2'])
        cv.idx[ay_ - 4, ax_ - 6] = IDX['ink9']
    cv.put(outer_edge(tgt | legs), IDX['ink1'])
    fig |= tgt | legs | outer_edge(tgt | legs)
    # a low rail fence along the yard's front
    for fx in range(hx1 + 2, cx + 90, 9):
        post = (X >= fx) & (X < fx + 2) & (Y >= base - 9) & (Y < base + 1)
        cv.put(post, IDX['amber2'])
        cv.put(post & (X == fx), IDX['amber3'])
        fig |= post
    rail = (X >= hx1 + 2) & (X < cx + 90) & ((Y == base - 7) | (Y == base - 3))
    cv.put(rail, IDX['amber2'])
    fig |= rail
    cv.put(outer_edge(fig) & (Y < base + 2), IDX['ink1'])
    fig |= outer_edge(fig) & (Y < base + 2)
    lit = win | win2
    light_world(cv, fig & ~lit & ~tgt, warm_amt=1.0, base=-0.5)
    cv.clean(mask=fig & ~lit & ~tgt, passes=1)
    m = crop_save(cv, 'grounds')
    hi_save(m, 'grounds')
    place('grounds', [hx0 - 8, 214, cx + 92 - (hx0 - 8), BACK - 214 + 4], plate_y=206)
    glow_save('grounds_glow', hx0 + 17, wall_top + 15, 16, ['amber1', 'amber2'], sy=0.8)


# ------------------------------------------------------------------ fog over the side areas
def fog(pid, x0, x1, inner_left):
    cv = Canvas(WORLD_W, WORLD_H)
    X, Y = cv.x, cv.y
    # the mist's ragged inner edge: streaky noise (stretched sideways) so it reads as drifting mist
    big = fbm(WORLD_W, WORLD_H * 6, 40, 3, x0 + 5)
    n = big[::6][:WORLD_H]
    if inner_left:      # the east bank: mist grows denser toward the right
        dist = (X - x0) / float(x1 - x0)
    else:
        dist = (x1 - X) / float(x1 - x0)
    dens = np.clip(dist * 1.5 + 0.55 * (n - 0.5) - 0.1, 0, 1)
    area = (X >= x0) & (X < x1) & (dens > 0.08)
    # ghost roofs inside the mist: the village that is still forgotten
    ghosts = np.zeros((WORLD_H, WORLD_W), bool)
    rng = np.random.default_rng(x0 + 1)
    for k in range(4):
        gx = int(rng.integers(x0 + 20, x1 - 40)); gw = int(rng.integers(24, 40)); gh = int(rng.integers(18, 30))
        gy = BACK - int(rng.integers(0, 30))
        ghosts |= poly_mask(cv, [(gx, gy), (gx + gw, gy), (gx + gw, gy - gh), (gx + gw // 2, gy - gh - 14), (gx, gy - gh)])
    # thin bank near the village, thick grey-indigo toward the edge, lighter streaks where it curls
    tone = np.clip(0.25 + dens * 0.45 + 0.6 * (n - 0.5), 0, 1)
    cv.shade(area, tone, ramp('ink2', 'ink3', 'ink4', 'ink4', 'fade1', 'fade2'), 0, 1)
    gm = area & ghosts & (dens < 0.92)
    cv.put(gm, IDX['ink3'])
    cv.put(gm & ~shift(ghosts, 0, 1), IDX['fade1'])
    cv.put(area & edge_of(area) & (dens < 0.2), IDX['ink4'])
    cv.clean(mask=area, passes=1)
    m = crop_save(cv, pid)
    hi_save(m & (dens < 0.35) & (dens > 0.12) | (m & edge_of(m) & (Y > 40) & (Y < WORLD_H - 2) & ((X > x0 + 1) & (X < x1 - 1))), pid, color='ink8')
    zx0, zx1 = (x0 + 24, x1) if inner_left else (x0, x1 - 24)
    place(pid, [zx0, 150, zx1 - zx0, 180], plate_y=170)


def mist_band():
    """A long low band of mist that drifts over the fog banks (drawn with partial alpha)."""
    w, h = 260, 60
    cv = Canvas(w, h)
    n = fbm(w, h, 20, 3, 91)
    d = np.clip(1 - np.abs(cv.y - h / 2) / (h / 2), 0, 1) * (0.6 + 0.8 * (n - 0.5))
    cv.shade(d > 0.25, d, ramp('fade1', 'fade2', 'fade2', 'fade3'), 0.25, 1.0)
    cv.clean(passes=1)
    cv.save(os.path.join(OUT, 'mist.png'))


def main():
    os.makedirs(OUT, exist_ok=True)
    sky()
    ground()
    lantern()
    vault()
    for i, (pid, cx) in enumerate(PLOTS.items()):
        plot(pid, cx, 100 + i * 7)
    grounds()
    fog('fog_west', FOG_W[0], FOG_W[1], False)
    fog('fog_east', FOG_E[0], FOG_E[1], True)
    mist_band()
    with open(os.path.join(OUT, 'layout.json'), 'w') as f:
        json.dump(layout, f, indent=1, sort_keys=True)
    print('lanternrest village done')


if __name__ == '__main__':
    main()
