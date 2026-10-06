"""Lanternrest as a top-down 3/4 town at night (docs/BUILD.md "Lanternrest view: top-down 3/4").

Run: python3 game/assets/lanternrest/src/make_town.py
Writes into game/assets/lanternrest/ (round 3: authored albedo + smooth light, two town stages):

  town_<stage>.png      the whole town's ALBEDO (master palette only, hand-placed pixels via code):
                        ground, kerbed brick streets, the plaza, houses, trees, clutter, ruins, the
                        Lantern and the Vault entrance, erased into the Fading toward the edges.
                        Surfaces carry their own form shading (the moon high in the north-west) but no
                        lamp light.
  light_<stage>.png     the night light for that stage (RGB, smooth, no bands, no dither): an indigo
                        night everywhere, warm pools around every lit lamp and the Lantern, the Vault's
                        cold light, edges facing a lamp catching it (fence tops, roof rims, kerb and
                        cobble lips), lit glass at full. The screen multiplies the town by it (a
                        CanvasItem MUL blend), so light TINTS the authored colours instead of
                        repainting them.
  <place>.png           each tappable place's albedo, cut out where it differs from the base town
  <place>_lit_<stage>.png  the place as it looks lit (albedo x light), for the lift over the panel dim
  <place>_hi.png / _press.png   the standard outline hugging its silhouette (hover: 2 px; pressed:
                        3 px, brighter), drawn above the light
  glow_*.png            additive bloom (smooth alpha, one hue each): lamp heads, the Lantern's cage
                        and its breathing pool, lit windows, the Vault's rising shaft
  mist_body_<stage>.png the mist over the edges (half resolution, smooth alpha, drawn x2 filtered)
  mist_wisp.png         drifting banks (half resolution, smooth alpha)
  flame_0..3, banner_0..2, grass_0..1, gear   small sprites
  layout.json           world size, layer positions, places (tap zone, sign anchor, pin anchor),
                        lights (with the progress stage that lights them), smoke, grass, banners,
                        the plaza's rect, the light at the banner per stage

Stages (docs/tasks/lanternrest-critic2.md "Round-3 build"):
  fresh   a new save: only the Lantern and three street lamps burn; the cottages by the plaza are
          dark and boarded; the mist sits close.
  built   after the first run comes home (meta.runs >= 1): the high street's lamps are relit, the
          two cottages reopen (lit windows, smoke, window boxes, barrels), planters and bunting
          on the plaza, the mist pushed back a little. The Training Grounds (a place, its own
          signal) bring their yard lamp.
Shadows are indigo: the darkest albedo colour is ink1, never black; the screen adds a faint ink
lift so lit black never reaches (0, 0, 0).
Uses paint.py from assets/encounter/src (read only) for the palette and noise.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'encounter', 'src'))
from paint import IDX, NAMES, RGB, fbm, value_noise  # noqa: E402

OUT = os.path.join(HERE, '..')
W, H = 1920, 720
TILE = 16
LANTERN = (960, 416)            # the monument's foot (the dais centre), world px
PLAZA = (960, 410, 126, 80)     # centre and radii of the plaza (a rounded square)
ROAD_EW = (390, 428)            # the high street's carriageway (y range)
ROAD_NS = (936, 984)            # the north-south street's carriageway (x range)
STAGES = ('fresh', 'built')
LIFT = (6, 6, 12)               # added on screen after the light (no lit pixel reaches black)

layout = {'world': [W, H], 'tile': TILE, 'start': [960, 376], 'layers': {}, 'places': {}, 'lights': [],
          'smoke': [], 'grass': [], 'banners': {}, 'stages': list(STAGES), 'lift': list(LIFT),
          'plaza': [PLAZA[0] - PLAZA[2], PLAZA[1] - PLAZA[3], 2 * PLAZA[2], 2 * PLAZA[3]], 'banner_light': {}}

# ------------------------------------------------------------------ palette tools
N = len(NAMES)
LUM = np.array([0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in RGB.astype(float)])
CHAINS = {
    'ink': ['ink1', 'ink2', 'ink3', 'ink4', 'ink5', 'ink6', 'ink7', 'ink8', 'ink9', 'ink10'],
    'amber': ['ink1', 'amber1', 'amber2', 'amber3', 'amber4', 'amber5', 'amber6', 'amber7'],
    'crystal': ['ink1', 'ink2', 'crystal1', 'crystal2', 'crystal3', 'crystal4', 'crystal5', 'ink10'],
    'life': ['ink1', 'ink2', 'life1', 'life2', 'life3', 'life4'],
    'blood': ['ink1', 'amber1', 'blood1', 'blood2', 'blood3', 'blood4'],
    'fade': ['ink1', 'ink2', 'fade1', 'fade2', 'fade3', 'fade4', 'ink10'],
    'skin': ['ink2', 'amber1', 'skin1', 'skin2', 'skin3', 'skin4'],
    'violet': ['ink1', 'ink2', 'violet1', 'violet2', 'violet3', 'violet4'],
}
FAM = {}
for fam, ch in CHAINS.items():
    for n in ch:
        if n.startswith(fam):
            FAM[n] = fam
for n in CHAINS['ink']:
    FAM[n] = 'ink'
MAXS = 6
STEP = np.zeros((2 * MAXS + 1, N), np.int32)    # STEP[s + MAXS][i]: colour i moved s steps
for i, n in enumerate(NAMES):
    ch = CHAINS[FAM[n]]
    p = ch.index(n)
    for s in range(-MAXS, MAXS + 1):
        STEP[s + MAXS, i] = IDX[ch[int(np.clip(p + s, 0, len(ch) - 1))]]


def nearest_map(names):
    """Each palette colour -> the colour of `names` with the nearest luminance (a hue swap)."""
    cand = np.array([IDX[n] for n in names])
    out = np.zeros(N, np.int32)
    for i in range(N):
        out[i] = cand[np.argmin(np.abs(LUM[cand] - LUM[i]))]
    return out


GRAY = nearest_map(['ink2', 'fade1', 'fade2', 'fade3', 'fade4'])
# half-faded: colours drift toward the cool greys of the ink ramp (still a little blue)
HALF = nearest_map(['ink2', 'ink3', 'ink4', 'ink5', 'ink6', 'ink7', 'ink8', 'fade2', 'fade3'])
for _n in ('ink1', 'ink2'):
    GRAY[IDX[_n]] = IDX['fade1']


def C(name):
    return IDX[name]


# ------------------------------------------------------------------ the world's channels
K_GROUND, K_WALL, K_ROOF_S, K_ROOF_N, K_ROOF_W, K_ROOF_E, K_VERT, K_EMIT, K_TOP = range(9)
NORMALS = {
    K_GROUND: (0.0, 0.0, 1.0), K_WALL: (0.0, 1.0, 0.25), K_ROOF_S: (0.0, 0.62, 0.78),
    K_ROOF_N: (0.0, -0.62, 0.78), K_ROOF_W: (-0.62, 0.0, 0.78), K_ROOF_E: (0.62, 0.0, 0.78),
    K_VERT: (0.0, 0.7, 0.7), K_EMIT: (0.0, 0.0, 1.0), K_TOP: (0.0, 0.0, 1.0),
}
# form shading baked into the albedo (whole palette steps): the moon high in the north-west
FORM = {K_GROUND: 0, K_WALL: -1, K_ROOF_S: 0, K_ROOF_N: 1, K_ROOF_W: 1, K_ROOF_E: -1,
        K_VERT: 0, K_EMIT: 0, K_TOP: 0}


class World:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.idx = np.full((h, w), -1, np.int32)
        self.kind = np.zeros((h, w), np.int8)
        yy, xx = np.mgrid[0:h, 0:w]
        self.X = xx.astype(np.float32)
        self.Y = yy.astype(np.float32)
        self.gy = self.Y.copy()
        self.hz = np.zeros((h, w), np.float32)
        self.dark = np.zeros((h, w), np.int8)
        self.owner = np.zeros((h, w), np.int16)
        self.lip = np.zeros((h, w), bool)        # edges that catch a lamp's light

    def copy(self):
        c = World.__new__(World)
        c.w, c.h, c.X, c.Y = self.w, self.h, self.X, self.Y
        for k in ('idx', 'kind', 'gy', 'hz', 'dark', 'owner', 'lip'):
            setattr(c, k, getattr(self, k).copy())
        return c


class Local:
    """A window onto the world (views: writes land in the world). Coordinates are world px."""

    def __init__(self, wd, x0, y0, w, h, owner=0):
        self.wd = wd
        self.x0, self.y0 = max(0, int(x0)), max(0, int(y0))
        self.x0, self.y0 = min(self.x0, wd.w), min(self.y0, wd.h)
        self.x1, self.y1 = max(self.x0, min(wd.w, int(x0 + w))), max(self.y0, min(wd.h, int(y0 + h)))
        self.w, self.h = self.x1 - self.x0, self.y1 - self.y0
        sl = (slice(self.y0, self.y1), slice(self.x0, self.x1))
        self.idx, self.kind, self.gy = wd.idx[sl], wd.kind[sl], wd.gy[sl]
        self.hz, self.dark, self.owner, self.lip = wd.hz[sl], wd.dark[sl], wd.owner[sl], wd.lip[sl]
        self.X, self.Y = wd.X[sl], wd.Y[sl]
        self.own = owner

    def poly(self, pts):
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([(float(x - self.x0), float(y - self.y0)) for x, y in pts], fill=1)
        return np.array(im, bool)

    def rect(self, x, y, w, h):
        return (self.X >= x) & (self.X < x + w) & (self.Y >= y) & (self.Y < y + h)

    def ellipse(self, cx, cy, rx, ry):
        return ((self.X + 0.5 - cx) / rx) ** 2 + ((self.Y + 0.5 - cy) / ry) ** 2 <= 1.0

    def line(self, pts, width=1):
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).line([(float(x - self.x0), float(y - self.y0)) for x, y in pts], fill=1, width=width)
        return np.array(im, bool)

    def noise(self, cell, seed, octaves=1):
        """World-anchored noise sampled in this window (patterns line up across calls)."""
        if self.w == 0 or self.h == 0:
            return np.zeros((self.h, self.w))
        if octaves == 1:
            n = value_noise(self.x1, self.y1, cell, seed)
        else:
            n = fbm(self.x1, self.y1, cell, octaves, seed)
        return n[self.y0:self.y1, self.x0:self.x1]

    def put(self, mask, color, kind=None, gy=None, hz=None, own=True, lip=None):
        if not mask.any():
            return
        if isinstance(color, str):
            self.idx[mask] = IDX[color]
        elif np.isscalar(color):
            self.idx[mask] = int(color)
        else:
            self.idx[mask] = color[mask]
        if kind is not None:
            self.kind[mask] = kind
        if gy is not None:
            self.gy[mask] = gy if np.isscalar(gy) else gy[mask]
        if hz is not None:
            self.hz[mask] = hz if np.isscalar(hz) else hz[mask]
        if own and self.own:
            self.owner[mask] = self.own
        self.dark[mask] = 0
        self.lip[mask] = False if lip is None else lip

    def shade(self, mask, steps=-1):
        """Darkens what is already there by whole steps (contact shadows)."""
        if not mask.any():
            return
        self.idx[mask] = STEP[MAXS + steps, np.maximum(self.idx[mask], 0)]

    def shadow(self, mask, steps=-1):
        """Darkens the ground under mask (ground only) by whole steps."""
        m = mask & (self.kind == K_GROUND) & (self.idx >= 0)
        self.shade(m, steps)


def shift_mask(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = mask[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return out


def edges(mask):
    up = np.zeros_like(mask); up[1:] = mask[:-1]
    dn = np.zeros_like(mask); dn[:-1] = mask[1:]
    lf = np.zeros_like(mask); lf[:, 1:] = mask[:, :-1]
    rt = np.zeros_like(mask); rt[:, :-1] = mask[:, 1:]
    return up, dn, lf, rt


def outer(mask):
    up, dn, lf, rt = edges(mask)
    return ~mask & (up | dn | lf | rt)


def dilate(mask, r):
    m = mask.copy()
    for _ in range(r):
        m = m | outer(m)
    return m


def rng_for(seed):
    return np.random.default_rng(seed)


def hash01(a, b, seed):
    """A stable 0..1 hash of integer arrays (per brick / per cell randomness)."""
    v = (a.astype(np.int64) * 73856093) ^ (b.astype(np.int64) * 19349663) ^ (seed * 83492791)
    v = (v ^ (v >> 13)) * 1274126177
    v = v ^ (v >> 16)
    return (v & 0xFFFF) / 65536.0


def id_joints(cid):
    """1 px joints between cells of an id field (right and lower neighbours differ)."""
    j = np.zeros(cid.shape, bool)
    j[:, :-1] |= cid[:, :-1] != cid[:, 1:]
    j[:-1, :] |= cid[:-1, :] != cid[1:, :]
    return j


# ------------------------------------------------------------------ the fields
_FOGN = []


def fog_field(X, Y, stage='fresh'):
    """0 in the remembered middle, 1 deep in the mist. The town is half-erased: the mist sits close
    to the north (in sight from the plaza) and further off east and west; the first run home pushes
    it back a little."""
    if not _FOGN:
        _FOGN.append(fbm(W, H, 48, 3, 77).astype(np.float32))
    k = 1.0 if stage == 'fresh' else 1.1
    dx = (X - 960.0)
    dy = (Y - 404.0)
    ry = np.where(dy < 0, 178.0, 290.0) * k
    rx = np.where(dx < 0, 660.0, 680.0) * k
    d = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
    n = _FOGN[0][: X.shape[0], : X.shape[1]] if X.shape == (H, W) else 0.5
    return np.clip((d + 0.24 * (n - 0.5) - 0.80) / 0.36, 0, 1).astype(np.float32)


# ------------------------------------------------------------------ surfaces
def bricks(L, mask, bw, bh, seed, tones, mortar, vertical=False, lip=True, chip=0.04, kind=K_GROUND, hz=0, gy=None):
    """Brick / sett paving in running bond on a world-anchored grid: a tone per brick, a lit top
    lip, a darker lower edge, a few chipped or sunken bricks."""
    X = L.X.astype(np.int64)
    Y = L.Y.astype(np.int64)
    if vertical:
        X, Y = Y, X
    row = Y // (bh + 1)
    off = (row % 2) * ((bw + 1) // 2)
    col = (X + off) // (bw + 1)
    jx = (X + off) % (bw + 1) == bw
    jy = Y % (bh + 1) == bh
    joint = jx | jy
    h = hash01(col, row, seed)
    t = np.array([IDX[n] for n in tones])
    colr = t[np.minimum((h * len(t)).astype(int), len(t) - 1)]
    body = mask & ~joint
    L.put(body, colr, kind, gy, hz)
    L.put(mask & joint, mortar, kind, gy, hz)
    if lip:
        top = body & ((Y % (bh + 1)) == 0) & (h > 0.18)
        L.idx[top] = STEP[MAXS + 1, L.idx[top]]
        L.lip[top] = True
        low = body & ((Y % (bh + 1)) == bh - 1) & (bh > 2)
        L.idx[low] = STEP[MAXS - 1, L.idx[low]]
    h2 = hash01(col, row, seed + 5)
    sunk = body & (h2 < chip)
    L.idx[sunk] = STEP[MAXS - 1, L.idx[sunk]]
    return body


def cells_paving(L, mask, cid, seed, tones, mortar, kind=K_GROUND):
    """Paving from any cell id field (sett rings, flagstones): tone per cell, joints, lit lips."""
    joint = id_joints(cid)
    h = hash01(cid, cid // 7, seed)
    t = np.array([IDX[n] for n in tones])
    colr = t[np.minimum((h * len(t)).astype(int), len(t) - 1)]
    body = mask & ~joint
    L.put(body, colr, kind)
    L.put(mask & joint, mortar, kind)
    up = np.zeros_like(joint); up[1:] = joint[:-1]
    lip = body & up & (h > 0.15)
    L.idx[lip] = STEP[MAXS + 1, L.idx[lip]]
    L.lip[lip] = True
    return body


# ------------------------------------------------------------------ small authored stamps
# characters: '.' clear, '+' one step lighter than what is there, '-' one darker, '=' two darker,
# or a palette letter from the stamp's own map
STAMPS = {
    'tuft': [".+.+.", "+-+.+", ".---."],
    'tuft2': ["..+..", ".+.+.", "+-+-+", ".---."],
    'blades': ["+...+", "+.+.+", "-+-+-"],
    'clover': [".a.a.", "aaaaa", ".aba.", "..b.."],
    'flower_w': [".w.", "wyw", ".w.", ".g."],
    'flower_r': [".r.", "ryr", ".r.", ".g."],
    'flower_v': [".v.", "vyv", ".v.", ".g."],
    'flowers': ["w...r.", "...g..", ".v...w", "..g.g."],
    'pebble': [".pq", "pqq", "qqd"],
    'stones': ["pq..", "qd.p", "..pq"],
    'leaf': ["o.", ".n"],
    'mush': [".rr.", "rrwr", ".ff.", ".ff."],
    'dirt': [".ss.", "sttss", ".sss."],
    'twig': ["n...", ".n..", "..nn"],
}
STAMP_MAP = {'a': 'life3', 'b': 'life1', 'w': 'fade4', 'y': 'amber6', 'g': 'life2', 'r': 'blood3', 'v': 'violet3',
             'p': 'ink7', 'q': 'ink5', 'd': 'ink3', 'o': 'amber4', 'n': 'amber2', 'f': 'fade3', 's': 'skin1',
             't': 'amber1'}


def stamp(wd, x, y, name, only=None, cmap=None):
    rows = STAMPS[name]
    cm = dict(STAMP_MAP)
    if cmap:
        cm.update(cmap)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == '.':
                continue
            px, py = x + i, y + j
            if not (0 <= px < W and 0 <= py < H):
                continue
            if only is not None and not only[py, px]:
                continue
            c = wd.idx[py, px]
            if c < 0:
                continue
            if ch == '+':
                wd.idx[py, px] = STEP[MAXS + 1, c]
            elif ch == '-':
                wd.idx[py, px] = STEP[MAXS - 1, c]
            elif ch == '=':
                wd.idx[py, px] = STEP[MAXS - 2, c]
            else:
                wd.idx[py, px] = IDX[cm[ch]]


# ------------------------------------------------------------------ ground
def superellipse(X, Y, cx, cy, rx, ry, p=4):
    return (np.abs(X - cx) / rx) ** p + (np.abs(Y - cy) / ry) ** p


def ground(wd, stage):
    """Grass with tile-scale variation, packed-earth verges, kerbed brick streets with sidewalks,
    the plaza of sett rings, lanes; small authored detail on every tile."""
    L = Local(wd, 0, 0, W, H)
    X, Y = L.X, L.Y
    fog = fog_field(X, Y, stage)
    # grass: two greens in broad patches, tile-scale tone steps (16 px), darker under the edges
    cl = fbm(W, H, 40, 3, 3)
    g = np.where(cl > 0.47, IDX['life3'], IDX['life2'])
    # mid-scale clumps (soft-edged, not tiles): lighter meadow and darker tussocks
    cm = fbm(W, H, 12, 2, 4)
    g = np.where((cm > 0.66) & (cl > 0.36), IDX['life3'], g)
    g = np.where((cm < 0.30) & (cl < 0.58), IDX['life2'], g)
    L.put(np.ones((H, W), bool), g, K_GROUND)
    # long grass strokes in the darker patches (short horizontal dashes, not speckle)
    st = (value_noise(W, H, 3, 6) > 0.74) & (cl < 0.47) & ((Y.astype(int) % 3) == 0)
    L.put(st, 'life1', K_GROUND)
    # packed earth: worn verges where feet leave the streets
    earth = np.zeros((H, W), bool)
    n = fbm(W, H, 14, 3, 9)
    wob = 4 * (n - 0.5)
    earth |= (Y + wob > ROAD_EW[0] - 22) & (Y - wob < ROAD_EW[1] + 20) & (fbm(W, H, 9, 2, 10) > 0.42)
    earth |= (X + wob > ROAD_NS[0] - 18) & (X - wob < ROAD_NS[1] + 18) & (fbm(W, H, 9, 2, 11) > 0.42)
    dirt = np.where(fbm(W, H, 5, 2, 12) > 0.55, IDX['skin1'], IDX['amber2'])
    L.put(earth, dirt, K_GROUND)
    L.put(earth & (value_noise(W, H, 2, 13) > 0.88), 'ink4', K_GROUND)

    # the streets: carriageways of blue-grey setts, kerbs, brick sidewalks
    def street_masks():
        ew = (Y >= ROAD_EW[0]) & (Y < ROAD_EW[1]) & (X >= 60) & (X < W - 60)
        ns = (X >= ROAD_NS[0]) & (X < ROAD_NS[1]) & (Y >= 30) & (Y < H)
        back = (Y >= 200) & (Y < 224) & (X >= 200) & (X < 1720)
        south = (Y >= 702) & (X >= 120) & (X < 1800)
        return ew | ns | back | south
    road = street_masks()
    walk = dilate(road, 15) & ~road
    pd = superellipse(X, Y, *PLAZA)
    plaza = pd < 1.0
    # streets break apart toward the mist (missing setts, grass through them)
    brk = fbm(W, H, 7, 2, 14)
    broken = brk < (fog - 0.12) * 1.25
    road_kept = road & ~broken & ~plaza
    walk_kept = walk & ~(brk < (fog - 0.02) * 1.3) & ~plaza
    # sidewalks first (lighter brick), then the kerb ring, then the carriageway
    bricks(L, walk_kept, 9, 4, 31, ['fade1', 'ink6', 'fade1', 'ink6', 'ink7'], 'ink4', chip=0.06)
    kerb = (dilate(road, 3) & ~road) & ~plaza & ~(brk < (fog - 0.05) * 1.3)
    up, dn, lf, rt = edges(road)
    # kerb: a lit top and a dark face toward the carriageway; joints every 12 px
    L.put(kerb, 'ink8', K_GROUND, lip=True)
    face = kerb & (shift_mask(road, 0, -1) | shift_mask(road, -1, 0) | shift_mask(road, 1, 0))
    L.put(face, 'ink5', K_GROUND)
    near_v = np.zeros_like(road)
    for d in (1, 2, 3):
        near_v |= shift_mask(road, 0, d) | shift_mask(road, 0, -d)
    hk = kerb & near_v
    kj = (hk & (X.astype(int) % 12 == 0)) | (kerb & ~hk & (Y.astype(int) % 12 == 0))
    L.put(kj & ~face, 'ink5', K_GROUND)
    # the kerb casts a short shadow onto the street below and right of it (the moon is north-west)
    sh = road_kept & (shift_mask(kerb, 0, 1) | shift_mask(kerb, 0, 2) | shift_mask(kerb, 1, 0))
    car = road_kept.copy()
    bricks(L, car, 6, 3, 21, ['ink5', 'ink6', 'ink5', 'ink4', 'ink6', 'fade1'], 'ink3', chip=0.05)
    L.shade(sh & (L.idx >= 0), -1)
    # centre wear: a paler, smoother band where wheels and feet run
    cw = car & (((np.abs(Y - (ROAD_EW[0] + ROAD_EW[1]) / 2) < 7) & (Y >= ROAD_EW[0]) & (Y < ROAD_EW[1])) |
                ((np.abs(X - (ROAD_NS[0] + ROAD_NS[1]) / 2) < 9) & (X >= ROAD_NS[0]) & (X < ROAD_NS[1])))
    cw &= fbm(W, H, 6, 2, 16) > 0.45
    L.idx[cw & (L.idx != IDX['ink3'])] = STEP[MAXS + 1, L.idx[cw & (L.idx != IDX['ink3'])]]
    # gutters: a darker line of setts just inside each kerb
    gut = car & ~cw & dilate(kerb, 1) & ~kerb
    L.shade(gut, -1)
    # broken street: grit and grass where setts are gone
    gone = (road | walk) & ~plaza & ~road_kept & ~walk_kept
    L.put(gone & (fbm(W, H, 4, 2, 17) > 0.5), 'skin1', K_GROUND)
    # loose setts lying where the street broke
    for k in range(260):
        r = rng_for(1700 + k)
        x, y = int(r.integers(4, W - 8)), int(r.integers(4, H - 6))
        if gone[y, x]:
            L.put(L.rect(x, y, 3, 2), 'ink5', K_GROUND)
            L.put(L.rect(x, y, 3, 1), 'ink7', K_GROUND)

    # the plaza: rings of setts round the Lantern, broad flagstones in the corners, a kerb of long
    # stones round it, a dais ring at the foot of the monument
    rx = (X - LANTERN[0])
    ry = (Y - LANTERN[1]) * 1.55
    rr = np.sqrt(rx * rx + ry * ry)
    ring = (rr / 8.5).astype(np.int64)
    rmid = (ring + 0.5) * 8.5
    nseg = np.maximum(6, np.round(2 * np.pi * rmid / 9.5)).astype(np.int64)
    ang = (np.arctan2(ry, rx) + np.pi) / (2 * np.pi)
    seg = np.floor(ang * nseg + (ring % 2) * 0.5).astype(np.int64) % nseg
    cid_r = ring * 10000 + seg
    fx = ((X - PLAZA[0] + 400) // 13).astype(np.int64)
    fy = ((Y - PLAZA[1] + 400) // 9).astype(np.int64)
    fx2 = ((X - PLAZA[0] + 400 + (fy % 2) * 6) // 13).astype(np.int64)
    cid_f = 5000000 + fy * 1000 + fx2
    inner = plaza & (rr < 119)
    corner = plaza & ~inner
    cells_paving(L, inner, cid_r, 41, ['fade2', 'ink7', 'fade2', 'fade1', 'ink7', 'fade3'], 'ink4')
    cells_paving(L, corner, cid_f, 42, ['ink6', 'fade1', 'ink7', 'fade1'], 'ink4')
    # a band of darker setts every few rings (a pattern you read from above)
    band = inner & ((ring == 6) | (ring == 10)) & (L.idx != IDX['ink4'])
    L.idx[band] = STEP[MAXS - 1, L.idx[band]]
    # cracked and sunken flags
    crk = plaza & (L.idx != IDX['ink4']) & (value_noise(W, H, 3, 43) > 0.87) & (value_noise(W, H, 1, 44) > 0.55)
    L.idx[crk] = STEP[MAXS - 1, L.idx[crk]]
    # the plaza's kerb (long stones) and its shadow on the grass beyond
    rim = plaza & (pd > 0.86) & ~(road | walk)
    pk = (cid_f // 3) * 3
    cells_paving(L, rim, pk, 45, ['ink7', 'ink8', 'ink7'], 'ink4')
    L.shadow(outer(plaza) & ~road & ~walk, -1)
    # moss through the joints toward the mist, weeds in the cracks
    moss = (plaza | road | walk) & ((L.idx == IDX['ink4']) | (L.idx == IDX['ink3']))
    moss &= (fbm(W, H, 8, 3, 18) + 0.7 * fog > 0.78)
    L.put(moss & (value_noise(W, H, 2, 19) > 0.4), 'life1', K_GROUND)
    if stage == 'fresh':
        # a fresh town: weeds through the plaza's joints
        wj = plaza & (L.idx == IDX['ink4']) & (value_noise(W, H, 4, 46) > 0.80)
        L.put(wj, 'life2', K_GROUND)
    return road, walk, plaza, kerb


def ground_detail(wd, stage, free):
    """Small authored marks on every tile: tufts, clover, flowers, pebbles, leaves, mushrooms; worn
    dirt and weeds where paving meets grass. `free` is where nothing stands."""
    grass = free & (wd.kind == K_GROUND) & np.isin(wd.idx, [IDX['life1'], IDX['life2'], IDX['life3']])
    names_g = ['tuft', 'tuft', 'tuft2', 'blades', 'clover', 'tuft', 'flower_w', 'flower_r', 'flower_v', 'flowers',
               'pebble', 'stones', 'leaf', 'mush', 'twig', 'dirt']
    weights = np.array([10, 8, 6, 6, 4, 6, 2, 2, 2, 2, 3, 2, 3, 1, 2, 2], float)
    cum = np.cumsum(weights / weights.sum())
    # every tile draws from its own stream, so the stages agree wherever the ground agrees
    for ty in range(0, H, 16):
        for tx in range(0, W, 16):
            r = np.random.default_rng(ty * 7919 + tx * 31 + 55).random(6)
            for k in range(2):
                x, y = tx + int(r[3 * k] * 12), ty + int(r[3 * k + 1] * 12)
                if x + 6 >= W or y + 5 >= H or not grass[y, x]:
                    continue
                name = names_g[int(np.searchsorted(cum, r[3 * k + 2]))]
                if not grass[y:y + len(STAMPS[name]), x:x + len(STAMPS[name][0])].all():
                    continue
                stamp(wd, x, y, name, grass)
    # paving: weeds in joints, leaves, a twig or a loose pebble
    pave = free & (wd.kind == K_GROUND) & np.isin(wd.idx, [IDX['ink3'], IDX['ink4'], IDX['ink5'], IDX['ink6'], IDX['ink7'], IDX['fade1'], IDX['fade2']])
    pr = np.random.default_rng(56).random((1400, 2))
    for k in range(1400):
        x, y = 2 + int(pr[k, 0] * (W - 10)), 2 + int(pr[k, 1] * (H - 8))
        if not pave[y, x]:
            continue
        name = ['tuft', 'leaf', 'blades', 'leaf', 'twig', 'pebble'][k % 6]
        stamp(wd, x, y, name, pave, {'p': 'ink8', 'q': 'ink6'} if name == 'pebble' else None)


def path(wd, pts, width, seed, kind='dirt'):
    """A worn lane (dirt, or broken flagstones) along a polyline."""
    L = Local(wd, 0, 0, W, H)
    m = L.line(pts, width)
    n = fbm(W, H, 6, 2, seed)
    m |= L.line(pts, width + 4) & (n > 0.55)
    m &= (wd.kind == K_GROUND) & np.isin(wd.idx, [IDX['life1'], IDX['life2'], IDX['life3'], IDX['skin1'], IDX['amber2'], IDX['ink4']])
    if kind == 'dirt':
        L.put(m, np.where(n > 0.5, IDX['skin1'], IDX['amber2']), K_GROUND)
        L.put(m & (value_noise(W, H, 2, seed + 1) > 0.85), 'ink4', K_GROUND)
        # two ruts and a tuft spine
        core = L.line(pts, max(1, width - 6)) & m
        L.put(core & (value_noise(W, H, 2, seed + 2) > 0.6), 'life1', K_GROUND)
    else:
        cid = ((L.X // 8).astype(np.int64) * 1000 + ((L.Y + (L.X // 8) % 2 * 3) // 6).astype(np.int64))
        cells_paving(L, m & (n > 0.25), cid, seed, ['ink6', 'fade1', 'ink7'], 'ink4')


# ------------------------------------------------------------------ props
def drop_shadow(L, mask, dx=3, dy=2, steps=-1):
    L.shadow(shift_mask(mask, dx, dy) & ~mask, steps)


def tree(wd, cx, base_y, r=16, seed=1, own=0, kind='oak'):
    """A round-crowned tree seen from above at a slant: trunk and roots below, a crown of leaf
    clusters lit from the upper left (the moon); a pine is three stacked tiers."""
    rng = rng_for(seed)
    L = Local(wd, cx - r - 16, base_y - 2 * r - 44, 2 * r + 40, 2 * r + 54, own)
    L.shadow(L.ellipse(cx + 6, base_y + 1, r * 1.05, r * 0.45), -2)
    trunk = L.rect(cx - 2, base_y - 16, 6, 16) | L.poly([(cx - 5, base_y), (cx + 7, base_y), (cx + 3, base_y - 5), (cx - 1, base_y - 5)])
    L.put(trunk, 'amber1', K_VERT, base_y, 6)
    L.put(trunk & (L.X <= cx - 1), 'skin1', K_VERT, base_y, 6)
    L.put(trunk & (L.X >= cx + 3), 'ink2', K_VERT, base_y, 6)
    L.put(trunk & ((L.Y.astype(int) * 3 + L.X.astype(int)) % 7 == 0), 'ink2', K_VERT, base_y, 6)
    crown = np.zeros((L.h, L.w), bool)
    shade = np.zeros((L.h, L.w), np.float32)
    if kind == 'pine':
        for k, (w_, y_) in enumerate(((r, base_y - 14), (r * 0.8, base_y - 14 - r * 0.7), (r * 0.55, base_y - 14 - r * 1.3))):
            tri = L.poly([(cx - w_, y_), (cx + 1 + w_, y_), (cx + 0.5, y_ - r * 1.0)])
            v = np.clip(0.6 - 0.5 * (L.X - cx) / max(w_, 1) - 0.25 * (L.Y - y_) / r, 0, 1)
            shade = np.where(tri, v, shade)
            # a dark lower rim on each tier
            shade = np.where(tri & (L.Y > y_ - 2), 0.05, shade)
            crown |= tri
        pal = ['ink2', 'life1', 'crystal1', 'life2', 'life3']
    else:
        cy = base_y - 16 - r * 0.8
        blobs = [(cx, cy, r, r * 0.85)]
        for k in range(9):
            a = rng.random() * 2 * np.pi
            d = r * 0.6
            blobs.append((cx + np.cos(a) * d, cy + np.sin(a) * d * 0.8, r * (0.42 + 0.2 * rng.random()), r * (0.38 + 0.18 * rng.random())))
        blobs.sort(key=lambda b: b[1])
        for (bx, by, rx, ry) in blobs:
            m = L.ellipse(bx, by, rx, ry)
            nx = (L.X - bx) / rx
            ny = (L.Y - by) / ry
            v = np.clip(0.62 - 0.42 * nx - 0.55 * ny, 0, 1)
            shade = np.where(m, v, shade)
            crown |= m
        pal = ['ink2', 'life1', 'life2', 'life3', 'life4']
    t = np.array([IDX[n] for n in pal])
    q = np.clip((shade * 4.4).astype(int), 0, 4)
    leaf = L.noise(2, seed + 3) > 0.62
    q = np.where(leaf & (q > 0), q - 1, q)
    L.put(crown, t[q], K_TOP, base_y, 34)
    up, dn, lf, rt = edges(crown)
    rimm = crown & (~up | ~lf) & (q >= 2)
    L.lip[rimm] = True
    L.put(outer(crown) & (L.Y > base_y - 16 - r), 'ink2', K_TOP, base_y, 20)
    return crown


def bush(wd, cx, cy, r=6, seed=2, own=0, berries=False):
    L = Local(wd, cx - r - 6, cy - r - 6, 2 * r + 14, 2 * r + 12, own)
    L.shadow(L.ellipse(cx + 3, cy + r * 0.5, r, r * 0.5), -1)
    m = np.zeros((L.h, L.w), bool)
    rng = rng_for(seed)
    sh = np.zeros((L.h, L.w), np.float32)
    for k in range(5):
        bx = cx + (rng.random() - 0.5) * r
        by = cy + (rng.random() - 0.5) * r * 0.6
        rr = r * (0.55 + 0.3 * rng.random())
        e = L.ellipse(bx, by, rr, rr * 0.8)
        v = np.clip(0.55 - 0.5 * (L.X - bx) / rr - 0.55 * (L.Y - by) / rr, 0, 1)
        sh = np.where(e, v, sh)
        m |= e
    t = np.array([IDX[n] for n in ['ink2', 'life1', 'life2', 'life3']])
    L.put(m, t[np.clip((sh * 3.6).astype(int), 0, 3)], K_TOP, cy + r * 0.6, 4)
    L.put(outer(m) & (L.Y > cy), 'ink2', K_TOP, cy + r * 0.6, 2)
    if berries:
        for k in range(5):
            x, y = int(cx + (rng.random() - 0.5) * r * 1.2), int(cy + (rng.random() - 0.5) * r)
            if 0 <= y - L.y0 < L.h and 0 <= x - L.x0 < L.w and m[y - L.y0, x - L.x0]:
                wd.idx[y, x] = IDX['blood3']


def crate(wd, x, y, own=0, w=10, h=8, top=5):
    """A wooden crate: a lit top face, a front face with planks and a cross brace."""
    L = Local(wd, x - 2, y - top - 2, w + 10, h + top + 8, own)
    body = L.rect(x, y, w, h)
    lid = L.rect(x, y - top, w, top)
    drop_shadow(L, body | lid, 3, 2, -2)
    L.put(lid, 'amber3', K_TOP, y + h, h)
    L.put(lid & (L.Y == y - top), 'skin2', K_TOP, y + h, h, lip=True)
    L.put(lid & ((L.X - x) % 4 == 3), 'amber2', K_TOP, y + h, h)
    L.put(body, 'amber2', K_WALL, y + h, 2)
    L.put(body & ((L.X == x) | (L.X == x + w - 1) | (L.Y == y) | (L.Y == y + h - 1)), 'amber1', K_WALL, y + h, 2)
    diag = body & (np.abs((L.X - x) * (h - 1) - (L.Y - y) * (w - 1)) < w * 0.7)
    L.put(diag, 'amber1', K_WALL, y + h, 2)


def barrel(wd, cx, base, own=0, lid='amber3'):
    L = Local(wd, cx - 8, base - 16, 18, 20, own)
    body = L.rect(cx - 4, base - 9, 9, 9) | L.rect(cx - 3, base - 10, 7, 11)
    top = L.ellipse(cx + 0.5, base - 10, 4.6, 2.2)
    drop_shadow(L, body | top, 3, 1, -2)
    L.put(body, 'amber2', K_WALL, base, 4)
    L.put(body & (L.X <= cx - 2), 'amber3', K_WALL, base, 4)
    L.put(body & (L.X >= cx + 3), 'amber1', K_WALL, base, 4)
    L.put(body & ((L.Y == base - 7) | (L.Y == base - 3)), 'ink4', K_WALL, base, 4)
    L.put(body & ((L.Y == base - 7) | (L.Y == base - 3)) & (L.X <= cx - 2), 'ink6', K_WALL, base, 4, lip=True)
    L.put(top, lid, K_TOP, base, 10)
    L.put(top & (L.ellipse(cx + 0.5, base - 10, 3.0, 1.2)), 'amber1', K_TOP, base, 10)
    L.put(top & ~L.ellipse(cx + 0.5, base - 9.4, 4.6, 2.2), STEP[MAXS + 1, IDX[lid]], K_TOP, base, 10, lip=True)


def sacks(wd, x, base, own=0, n=2):
    L = Local(wd, x - 4, base - 12, 10 * n + 10, 16, own)
    for k in range(n):
        cx = x + k * 7
        m = L.ellipse(cx + 3, base - 4, 4, 4) | L.rect(cx + 2, base - 9, 3, 2)
        drop_shadow(L, m, 2, 1, -1)
        L.put(m, 'skin2', K_WALL, base, 4)
        L.put(m & (L.X > cx + 4), 'skin1', K_WALL, base, 4)
        L.put(m & (L.X < cx + 2) & (L.Y < base - 4), 'skin3', K_WALL, base, 4, lip=True)
        L.put(L.rect(cx + 2, base - 8, 3, 1), 'amber1', K_WALL, base, 6)


def firewood(wd, x, base, own=0, w=14):
    L = Local(wd, x - 2, base - 10, w + 8, 14, own)
    m = L.rect(x, base - 7, w, 7)
    drop_shadow(L, m, 3, 1, -2)
    L.put(m, 'amber2', K_WALL, base, 3)
    for j in range(0, 7, 3):
        for i in range(0, w, 3):
            o = (j // 3) % 2
            L.put(L.rect(x + i + o, base - 7 + j, 2, 2), 'skin2', K_WALL, base, 3)
            L.put(L.rect(x + i + o, base - 7 + j, 1, 1), 'skin3', K_WALL, base, 3, lip=True)
    L.put(L.rect(x, base - 8, w, 1), 'amber1', K_TOP, base, 8)


def bucket(wd, x, base, own=0):
    L = Local(wd, x - 2, base - 8, 10, 10, own)
    m = L.rect(x, base - 5, 5, 5)
    drop_shadow(L, m, 2, 1, -1)
    L.put(m, 'ink5', K_WALL, base, 3)
    L.put(m & (L.X == x), 'ink7', K_WALL, base, 3, lip=True)
    L.put(L.rect(x, base - 6, 5, 1), 'ink3', K_TOP, base, 6)
    L.put(L.rect(x + 1, base - 6, 3, 1), 'crystal1', K_TOP, base, 6)


def planter(wd, x, base, w=20, own=0, bloom=True, seed=7):
    """A wooden flower box: plank front, soil, flowers in bloom (or dry stalks)."""
    rng = rng_for(seed)
    L = Local(wd, x - 2, base - 12, w + 8, 16, own)
    box = L.rect(x, base - 5, w, 5)
    drop_shadow(L, box, 2, 1, -2)
    L.put(box, 'amber2', K_WALL, base, 3)
    L.put(box & (L.Y == base - 5), 'amber3', K_WALL, base, 3, lip=True)
    L.put(box & ((L.X - x) % 6 == 5), 'amber1', K_WALL, base, 3)
    L.put(L.rect(x + 1, base - 6, w - 2, 1), 'skin1', K_TOP, base, 5)
    leaves = L.rect(x + 1, base - 9, w - 2, 3) & (L.noise(2, seed) > 0.35)
    L.put(leaves, 'life2' if bloom else 'amber1', K_TOP, base, 7)
    L.put(leaves & (L.noise(1, seed + 1) > 0.6), 'life3' if bloom else 'skin1', K_TOP, base, 7, lip=True)
    if bloom:
        cols = ['blood3', 'amber5', 'fade4', 'violet3']
        for k in range(w // 3):
            px, py = x + 1 + int(rng.integers(0, w - 2)), base - 8 - int(rng.integers(0, 3))
            L.put(L.rect(px, py, 1, 1), cols[k % len(cols)], K_TOP, base, 8)


def fence(wd, pts, own=0, broken=None, seed=3, post_every=8, color='amber2'):
    """A post-and-rail fence along a polyline (rails on horizontal runs, posts everywhere)."""
    rng = rng_for(seed)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        L = Local(wd, min(ax, bx) - 6, min(ay, by) - 14, abs(bx - ax) + 14, abs(by - ay) + 20, own)
        n = int(max(abs(bx - ax), abs(by - ay)) / post_every)
        horiz = abs(bx - ax) >= abs(by - ay)
        for k in range(n + 1):
            t = k / max(n, 1)
            px, py = int(round(ax + (bx - ax) * t)), int(round(ay + (by - ay) * t))
            if broken is not None and rng.random() < broken:
                continue
            post = L.rect(px, py - 8, 2, 8)
            drop_shadow(L, post, 2, 1, -1)
            L.put(post, color, K_VERT, py, 4)
            L.put(post & (L.X == px + 1), 'amber1', K_VERT, py, 4)
            L.put(L.rect(px, py - 9, 2, 1), 'skin2', K_TOP, py, 8, lip=True)
        if horiz:
            for ry in (6, 3):
                rail = L.line([(ax, ay - ry), (bx, by - ry)], 1)
                if broken is not None:
                    gap = L.noise(6, seed + ry) < broken * 0.9
                    rail &= ~gap
                L.put(rail & (L.idx != IDX[color]), 'amber3' if ry == 6 else 'amber2', K_VERT, ay, ry, lip=ry == 6)
                L.shadow(L.line([(ax + 1, ay - ry + 4), (bx + 1, by - ry + 4)], 1) & (L.kind == K_GROUND), -1)


def lamp_post(wd, x, base, lit=True, own=0, broken=False):
    """An iron street lamp: a post, a curled arm, a hanging glass head (lit: emissive)."""
    L = Local(wd, x - 8, base - 36, 22, 42, own)
    post = L.rect(x, base - 28, 2, 28)
    foot = L.rect(x - 1, base - 3, 4, 3)
    drop_shadow(L, post | foot, 3, 1, -1)
    L.put(post | foot, 'ink3', K_VERT, base, 10)
    L.put(post & (L.X == x), 'ink5', K_VERT, base, 10, lip=True)
    L.put(L.rect(x - 1, base - 4, 4, 1), 'ink5', K_VERT, base, 4, lip=True)
    if broken:
        L.put(L.rect(x, base - 28, 2, 10), 'ink2', K_VERT, base, 10)
        L.put(L.rect(x + 2, base - 1, 5, 1), 'ink4', K_TOP, base, 1)
        return None
    L.put(L.rect(x + 2, base - 28, 5, 1) | L.rect(x - 1, base - 29, 3, 1), 'ink3', K_VERT, base, 28)
    L.put(L.rect(x + 6, base - 28, 1, 3), 'ink3', K_VERT, base, 26)
    cap = L.rect(x + 4, base - 25, 5, 1) | L.rect(x + 5, base - 26, 3, 1)
    head = L.rect(x + 4, base - 24, 5, 5)
    L.put(cap, 'ink4', K_VERT, base, 26, lip=True)
    if lit:
        L.put(head, 'amber6', K_EMIT, base, 22)
        L.put(L.rect(x + 5, base - 23, 3, 3), 'amber7', K_EMIT, base, 22)
        L.put(L.rect(x + 4, base - 19, 5, 1), 'ink3', K_VERT, base, 22)
    else:
        L.put(head, 'ink2', K_VERT, base, 22)
        L.put(L.rect(x + 5, base - 23, 1, 2), 'ink5', K_VERT, base, 22, lip=True)
        L.put(L.rect(x + 4, base - 19, 5, 1), 'ink3', K_VERT, base, 22)
    return (x + 6, base - 21)


def well(wd, cx, base, own=0):
    L = Local(wd, cx - 18, base - 36, 38, 44, own)
    ring = L.ellipse(cx, base - 6, 13, 7)
    inner = L.ellipse(cx, base - 7, 9, 4.5)
    front = L.rect(cx - 13, base - 6, 27, 6) & ~L.ellipse(cx, base + 3, 14, 4)
    drop_shadow(L, ring | front, 4, 2, -2)
    m = front | (ring & ~inner)
    bricks(L, m, 4, 3, 41, ['ink6', 'ink7', 'fade1'], 'ink4', kind=K_WALL, hz=4, gy=base)
    L.put(inner, 'ink1', K_GROUND)
    L.put(inner & (L.Y > base - 7), 'crystal1', K_GROUND)
    for px in (cx - 12, cx + 11):
        L.put(L.rect(px, base - 26, 2, 20), 'amber2', K_VERT, base, 14)
        L.put(L.rect(px, base - 26, 1, 20), 'amber3', K_VERT, base, 14, lip=True)
    roof = L.poly([(cx - 16, base - 25), (cx + 16, base - 25), (cx + 12, base - 33), (cx - 12, base - 33)])
    L.put(roof, 'blood2', K_ROOF_S, base, 30)
    L.put(roof & ((L.Y - base) % 2 == 0), 'blood1', K_ROOF_S, base, 30)
    L.put(L.rect(cx - 12, base - 34, 24, 1), 'blood3', K_ROOF_N, base, 32, lip=True)
    L.put(L.rect(cx - 16, base - 25, 32, 1), 'blood1', K_ROOF_S, base, 30)
    L.put(L.rect(cx - 10, base - 18, 20, 1), 'amber1', K_VERT, base, 16)
    L.put(L.rect(cx - 1, base - 17, 3, 4), 'ink4', K_VERT, base, 14)
    L.put(L.rect(cx - 2, base - 13, 5, 3), 'amber2', K_VERT, base, 12)


def bench(wd, x, base, own=0, broken=False):
    L = Local(wd, x - 2, base - 12, 22, 16, own)
    seat = L.rect(x, base - 6, 16, 3)
    legs = L.rect(x + 1, base - 3, 1, 3) | L.rect(x + 14, base - 3, 1, 3)
    back = L.rect(x, base - 10, 16, 2) | L.rect(x + 1, base - 8, 1, 2) | L.rect(x + 14, base - 8, 1, 2)
    if broken:
        seat &= L.X < x + 10
        back &= L.X < x + 6
    drop_shadow(L, seat | legs | back, 2, 2, -1)
    L.put(back, 'amber2', K_WALL, base, 6)
    L.put(back & (L.Y == base - 10), 'amber3', K_WALL, base, 6, lip=True)
    L.put(seat, 'amber3', K_TOP, base, 4)
    L.put(seat & (L.Y == base - 6), 'amber4', K_TOP, base, 4, lip=True)
    L.put(seat & (L.Y == base - 4), 'amber2', K_TOP, base, 4)
    L.put(legs, 'ink3', K_VERT, base, 1)


def signpost(wd, x, base, seed=1, own=0, arrow=-1):
    """A leaning wooden signpost with a blank board pointing into the mist."""
    L = Local(wd, x - 14, base - 26, 30, 30, own)
    post = L.rect(x, base - 20, 2, 20)
    drop_shadow(L, post, 3, 1, -1)
    L.put(post, 'amber2', K_VERT, base, 10)
    L.put(post & (L.X == x), 'amber3', K_VERT, base, 10, lip=True)
    bx = x - 11 if arrow < 0 else x + 2
    board = L.rect(bx, base - 19, 11, 5)
    tip = L.poly([(bx - 3, base - 17), (bx, base - 20), (bx, base - 14)] if arrow < 0 else [(bx + 14, base - 17), (bx + 11, base - 20), (bx + 11, base - 14)])
    L.put(board | tip, 'skin2', K_WALL, base, 18)
    L.put((board | tip) & (L.Y == base - 19), 'skin3', K_WALL, base, 18, lip=True)
    L.put(L.rect(bx + 2, base - 17, 7, 1), 'amber2', K_WALL, base, 18)


def rubble(wd, x, y, n, seed, own=0, spread=8):
    rng = rng_for(seed)
    L = Local(wd, x - spread - 6, y - spread - 6, 2 * spread + 14, 2 * spread + 12, own)
    for k in range(n):
        rx_ = x + (rng.random() - 0.5) * 2 * spread
        ry_ = y + (rng.random() - 0.5) * spread
        r_ = L.ellipse(rx_, ry_, 1.5 + rng.random() * 2, 1.2 + rng.random())
        drop_shadow(L, r_, 1, 1, -1)
        L.put(r_, ['ink5', 'ink6', 'fade1'][k % 3], K_TOP, ry_, 1)
        L.put(r_ & (L.Y < ry_ - 0.5), 'ink7', K_TOP, ry_, 1, lip=True)
    for k in range(max(1, n // 4)):
        px = int(x + (rng.random() - 0.5) * 2 * spread)
        py = int(y + (rng.random() - 0.5) * spread)
        L.put(L.line([(px, py), (px + 6, py - 2)], 1), 'amber2', K_TOP, py, 1)


def bunting(wd, x0, x1, y, seed=5):
    """Pennants on a sagging line across a street (built town)."""
    L = Local(wd, x0 - 2, y - 2, x1 - x0 + 4, 14)
    cols = ['blood3', 'amber5', 'crystal3', 'fade4', 'life3']
    for x in range(x0, x1):
        t = (x - x0) / (x1 - x0)
        sag = int(round(6 * 4 * t * (1 - t)))
        L.put(L.rect(x, y + sag, 1, 1), 'ink3', K_VERT, y + 60, 40)
        if (x - x0) % 6 == 2 and 3 < x - x0 < x1 - x0 - 3:
            c = cols[((x - x0) // 6) % len(cols)]
            tri = L.poly([(x - 1.5, y + sag + 1), (x + 2.5, y + sag + 1), (x + 0.5, y + sag + 5)])
            L.put(tri, c, K_VERT, y + 60, 40)


# ------------------------------------------------------------------ buildings
def shingles(L, mask, base, dark, light, row=4, tw=5, seed=1, kind=K_ROOF_S, gy=0, hz=30, horizontal=True):
    """Roof tiles in courses: each course's lower edge dark, a lit lip on top, staggered joints."""
    L.put(mask, base, kind, gy, hz)
    yy = (L.Y - L.y0).astype(int)
    xx = (L.X - L.x0).astype(int)
    if horizontal:
        course = yy // row
        L.put(mask & (yy % row == row - 1), dark, kind, gy, hz)
        joint = ((xx + (course % 2) * (tw // 2)) % tw == 0) & (yy % row != row - 1)
        L.put(mask & joint, dark, kind, gy, hz)
        L.put(mask & (yy % row == 0) & ~joint, light, kind, gy, hz, lip=True)
    else:
        course = xx // row
        L.put(mask & (xx % row == row - 1), dark, kind, gy, hz)
        joint = ((yy + (course % 2) * (tw // 2)) % tw == 0) & (xx % row != row - 1)
        L.put(mask & joint, dark, kind, gy, hz)
    chips = mask & (L.noise(3, seed) > 0.84)
    L.idx[chips] = STEP[MAXS - 1, L.idx[chips]]


ROOFS = {
    'red': ('blood2', 'blood1', 'blood3'),
    'slate': ('ink5', 'ink3', 'ink7'),
    'teal': ('crystal2', 'crystal1', 'crystal3'),
    'thatch': ('amber3', 'amber2', 'amber4'),
    'brown': ('skin1', 'amber1', 'skin2'),
}
WALLS = {
    'plaster': ('fade3', 'fade2', 'amber2'),       # fill, shade, timber
    'stone': ('ink6', 'ink5', 'ink4'),
    'timber': ('amber2', 'amber1', 'amber1'),
    'brick': ('blood1', 'amber1', 'ink3'),
}


def house(wd, x, base, w, wall_h, roof_h, roof='red', walls='plaster', ridge='ew', own=0, seed=1,
          windows=None, door=None, lit_windows=(), chimney=None, ruined=0.0, vines=0.0, sign=None,
          boarded=False, boxes=False, clutter=None):
    """A house in 3/4 view: the front wall faces south (toward the viewer), the roof above it.
    ridge 'ew': the front slope faces south and a strip of the back slope shows above the ridge.
    ridge 'ns': a gable faces the viewer, two slopes (west, east). ruined 0..1 breaks it apart.
    boarded: planks over the windows and door (a dark house); boxes: window boxes in bloom.
    clutter: 'lived' (barrels, crates, firewood) / 'empty' (rubble, broken planks) at its feet."""
    rng = rng_for(seed)
    top = base - wall_h - roof_h
    L = Local(wd, x - 10, top - 12, w + 32, wall_h + roof_h + 28, own)
    rc = ROOFS[roof]
    wc = WALLS[walls]
    wall = L.rect(x, base - wall_h, w, wall_h)
    sh = L.poly([(x + w, base - wall_h - roof_h + 6), (x + w + 10, base - wall_h - roof_h + 12), (x + w + 10, base + 4), (x + 4, base + 4), (x, base)])
    L.shadow(sh, -2)
    L.shadow(L.rect(x - 1, base, w + 2, 2), -1)
    if walls in ('stone', 'brick'):
        bricks(L, wall, 6 if walls == 'stone' else 4, 3, seed + 7, [wc[0], wc[0], wc[1]], wc[2], kind=K_WALL, gy=base, hz=0)
        L.hz[wall] = (base - L.Y[wall])
        L.lip[wall] = False
        if L.own:
            L.owner[wall] = L.own
    else:
        L.put(wall, wc[0], K_WALL, base, base - L.Y)
        if walls == 'plaster':
            frame = L.rect(x, base - wall_h, 2, wall_h) | L.rect(x + w - 2, base - wall_h, 2, wall_h)
            frame |= L.rect(x, base - wall_h, w, 2) | L.rect(x, base - wall_h // 2, w, 1)
            nb = max(2, w // 22)
            for k in range(1, nb):
                frame |= L.rect(x + k * w // nb, base - wall_h, 2, wall_h)
            # braces in the upper panels
            for k in range(nb):
                px0 = x + k * w // nb + 2
                frame |= L.line([(px0, base - wall_h // 2 - 1), (px0 + 6, base - wall_h + 2)], 1) & wall
            L.put(wall & frame, wc[2], K_WALL, base, base - L.Y)
            stains = wall & ~frame & (L.noise(3, seed + 2) > 0.72)
            L.put(stains, wc[1], K_WALL, base, base - L.Y)
            # brick showing where plaster fell
            patch = wall & ~frame & (L.noise(5, seed + 21) > 0.8)
            L.put(patch & ((L.Y.astype(int) % 3) == 0), 'blood1', K_WALL, base, base - L.Y)
        else:
            planks = wall & ((L.X - x) % 4 == 3)
            L.put(planks, wc[1], K_WALL, base, base - L.Y)
            L.put(wall & ((L.X - x) % 4 == 0) & (L.noise(2, seed + 5) > 0.5), 'amber3', K_WALL, base, base - L.Y)
    # the eave's shadow on the wall's top
    L.put(L.rect(x, base - wall_h, w, 2), STEP[MAXS - 1, IDX[wc[1]]], K_WALL, base, wall_h)
    plinth = L.rect(x, base - 3, w, 3)
    bricks(L, plinth, 5, 2, seed + 9, ['ink5', 'ink4'], 'ink3', kind=K_WALL, gy=base, hz=1, lip=False)
    L.put(L.rect(x, base - 3, w, 1), 'ink6', K_WALL, base, 3, lip=True)
    if L.own:
        L.owner[plinth] = L.own
    if door is not None:
        dx = x + door
        d = L.rect(dx, base - 15, 9, 15)
        L.put(d, 'amber1', K_WALL, base, 6)
        L.put(L.rect(dx + 1, base - 14, 7, 14), 'amber2', K_WALL, base, 6)
        L.put(L.rect(dx + 1, base - 14, 7, 14) & ((L.X - dx) % 3 == 0), 'amber1', K_WALL, base, 6)
        L.put(L.rect(dx + 6, base - 8, 1, 1), 'amber5', K_WALL, base, 6)
        L.put(L.rect(dx - 1, base - 16, 11, 1), wc[2] if walls == 'plaster' else 'ink4', K_WALL, base, 16, lip=True)
        step = L.rect(dx - 1, base, 11, 2)
        L.put(step, 'ink6', K_TOP, base + 2, 1)
        L.put(L.rect(dx - 1, base, 11, 1), 'ink7', K_TOP, base + 2, 1, lip=True)
        if boarded:
            for k in range(2):
                yy = base - 12 + k * 6
                L.put(L.line([(dx - 1, yy + 3), (dx + 9, yy)], 1), 'skin2', K_WALL, base, 8)
            L.put(L.rect(dx + 1, base - 14, 1, 1) | L.rect(dx + 7, base - 4, 1, 1), 'fade4', K_WALL, base, 8)
    for i, wx in enumerate(windows or []):
        wx = x + wx
        wy = base - wall_h + 6
        lit = i in lit_windows
        frame = L.rect(wx - 1, wy - 1, 9, 9)
        glass = L.rect(wx, wy, 7, 7)
        L.put(frame, 'amber1', K_WALL, base, base - wy)
        if lit:
            L.put(glass, 'amber5', K_EMIT, base, base - wy)
            L.put(L.rect(wx, wy, 3, 3), 'amber6', K_EMIT, base, base - wy)
            L.put(glass & ((L.X == wx + 3) | (L.Y == wy + 3)), 'amber2', K_EMIT, base, base - wy)
        else:
            L.put(glass, 'ink2', K_WALL, base, base - wy)
            L.put(glass & ((L.X == wx + 3) | (L.Y == wy + 3)), 'amber1', K_WALL, base, base - wy)
            L.put(L.rect(wx + 1, wy + 1, 1, 2), 'ink6', K_WALL, base, base - wy, lip=True)
        # shutters, sill
        if not boarded and ruined < 0.5:
            for sx in (wx - 4, wx + 8):
                L.put(L.rect(sx, wy - 1, 3, 9), 'crystal2' if (seed % 3 == 0) else ('blood1' if seed % 3 == 1 else 'life1'), K_WALL, base, base - wy)
                L.put(L.rect(sx, wy - 1, 3, 9) & (L.Y.astype(int) % 3 == 0), 'ink2', K_WALL, base, base - wy)
        L.put(L.rect(wx - 2, wy + 8, 11, 1), 'ink6', K_TOP, base, base - wy - 8, lip=True)
        if boarded:
            for k in range(2):
                L.put(L.line([(wx - 2, wy + 1 + 4 * k), (wx + 8, wy + 3 + 2 * k)], 1), 'skin2', K_WALL, base, base - wy)
            L.put(L.rect(wx + 6, wy - 1, 2, 1), 'fade3', K_WALL, base, base - wy)   # a cobweb
        if boxes and (lit or i % 2 == 0):
            planter(wd, wx - 3, wy + 14, 13, own, True, seed + 30 + i)
    eave = base - wall_h + 3
    if ridge == 'ew':
        ry = top + roof_h * 0.35
        front = L.poly([(x - 4, eave), (x + w + 4, eave), (x + w + 2, ry), (x - 2, ry)])
        back = L.poly([(x - 2, ry), (x + w + 2, ry), (x + w, top), (x, top)])
        shingles(L, front, rc[0], rc[1], rc[2], 4, 6, seed + 3, K_ROOF_S, base, 40)
        shingles(L, back & ~front, rc[0], rc[1], rc[2], 3, 6, seed + 4, K_ROOF_N, base, 50)
        L.put(L.rect(x - 2, int(ry), w + 4, 2), rc[2], K_ROOF_N, base, 54, lip=True)
        L.put(L.rect(x - 2, int(ry) + 1, w + 4, 1), rc[1], K_ROOF_N, base, 54)
        L.put(L.rect(x - 4, eave - 1, w + 8, 2), rc[1], K_ROOF_S, base, 36)
        L.put(L.rect(x - 4, eave - 2, w + 8, 1), rc[2], K_ROOF_S, base, 36, lip=True)
        roofm = front | back
    else:
        cx = x + w / 2.0
        gable_top = base - wall_h - roof_h * 0.45
        gable = L.poly([(x + 3, base - wall_h + 1), (x + w - 3, base - wall_h + 1), (cx, gable_top)])
        L.put(gable, wc[0] if walls != 'stone' else 'ink5', K_WALL, base, base - L.Y)
        L.put(gable & (np.abs(L.X - cx) < 1), wc[2], K_WALL, base, base - L.Y)
        L.put(gable & (L.Y > base - wall_h - 3), STEP[MAXS - 1, IDX[wc[1]]], K_WALL, base, base - L.Y)
        L.put(L.rect(int(cx) - 2, int(gable_top) + 7, 5, 5), 'ink2', K_WALL, base, 30)
        L.put(L.rect(int(cx) - 2, int(gable_top) + 7, 5, 1), 'amber1', K_WALL, base, 30)
        left = L.poly([(x - 4, eave), (cx, gable_top - 2), (cx, top), (x - 2, top + roof_h * 0.55)])
        right = L.poly([(x + w + 4, eave), (cx, gable_top - 2), (cx, top), (x + w + 2, top + roof_h * 0.55)])
        shingles(L, left, rc[0], rc[1], rc[2], 4, 5, seed + 3, K_ROOF_W, base, 44, horizontal=False)
        shingles(L, right & ~left, rc[0], rc[1], rc[2], 4, 5, seed + 4, K_ROOF_E, base, 44, horizontal=False)
        L.put(L.line([(x - 4, eave), (cx, gable_top - 2)], 2) | L.line([(x + w + 4, eave), (cx, gable_top - 2)], 2), rc[2], K_ROOF_S, base, 40, lip=True)
        L.put(L.rect(int(cx) - 1, top, 2, int(gable_top - top)), rc[2], K_ROOF_N, base, 60, lip=True)
        roofm = left | right
    L.put(outer(roofm) & ~wall & (L.Y < eave + 2) & (L.kind == K_GROUND), 'ink2', K_ROOF_N, base, 30)
    smoke = None
    if chimney is not None:
        cxp = x + chimney
        ch = L.rect(cxp, top - 6, 6, 14) & ~(L.Y > top + 8)
        bricks(L, ch, 3, 2, seed + 11, ['blood1', 'amber1', 'ink4'], 'ink2', kind=K_WALL, gy=base, hz=60, lip=False)
        if L.own:
            L.owner[ch] = L.own
        L.put(L.rect(cxp - 1, top - 7, 8, 2), 'ink5', K_TOP, base, 64, lip=True)
        L.put(L.rect(cxp + 1, top - 7, 4, 1), 'ink1', K_TOP, base, 64)
        smoke = (cxp + 3, top - 8)
    if sign is not None:
        sx = x + sign
        L.put(L.rect(sx - 4, base - wall_h + 1, 9, 1), 'ink3', K_WALL, base, 18)
        L.put(L.rect(sx, base - wall_h + 1, 1, 4), 'ink3', K_WALL, base, 18)
        board = L.rect(sx - 5, base - wall_h + 5, 11, 8)
        L.put(board, 'amber2', K_WALL, base, 16)
        L.put(board & (L.Y == base - wall_h + 5), 'amber3', K_WALL, base, 16, lip=True)
        L.put(L.rect(sx - 2, base - wall_h + 7, 5, 4), 'amber4', K_WALL, base, 16)   # a painted mug
        L.put(L.rect(sx + 3, base - wall_h + 8, 1, 2), 'amber4', K_WALL, base, 16)
        L.put(L.rect(sx - 2, base - wall_h + 7, 5, 1), 'fade4', K_WALL, base, 16)
    if vines > 0:
        v = (wall | roofm) & (fbm(L.w, L.h, 4, 2, seed + 13) < 0.25 + 0.3 * vines) & (L.Y > base - wall_h - roof_h * vines)
        L.put(v, np.where(L.noise(2, seed + 14) > 0.5, IDX['life2'], IDX['life1']), None)
        L.put(v & (L.noise(1, seed + 15) > 0.75), 'life3', None, lip=True)
    if ruined > 0:
        n = fbm(L.w, L.h, 9, 3, seed + 15)
        hole = roofm & (n < 0.18 + 0.45 * ruined)
        L.put(hole, 'ink2', K_GROUND, base - wall_h, 0)
        raft = hole & ((L.X - x) % 7 == 0)
        L.put(raft, 'skin1', K_ROOF_S, base, 30, lip=True)
        L.put(outer(hole) & roofm, rc[1], K_ROOF_S, base, 30)
        broken_top = wall & (L.Y < base - wall_h + 6 * ruined + 3 * n) & (n < 0.4)
        L.put(broken_top, 'ink2', K_WALL, base, 10)
        boards = wall & (L.noise(5, seed + 16) > 0.82)
        L.put(boards, 'amber1', K_WALL, base, 8)
    if clutter:
        _clutter(wd, x, base, w, own, seed, clutter, ruined)
    return smoke


def _clutter(wd, x, base, w, own, seed, how, ruined):
    """Things at a building's feet: barrels, crates, sacks, firewood, a bucket (lived in) or rubble
    and fallen planks (empty)."""
    rng = rng_for(seed + 500)
    if how == 'lived':
        side = x - 12 if rng.random() < 0.5 else x + w + 2
        barrel(wd, side + 5, base + 2, own)
        if rng.random() < 0.7:
            barrel(wd, side + 5 + (8 if side > x else -8), base + 4, own)
        cx_ = x + w - 18 if side < x else x + 4
        pick = rng.integers(0, 3)
        if pick == 0:
            crate(wd, cx_, base - 4, own)
            crate(wd, cx_ + 2, base - 11, own, 7, 5, 3)
        elif pick == 1:
            firewood(wd, cx_, base + 1, own)
        else:
            sacks(wd, cx_, base + 2, own, 2)
        if rng.random() < 0.5:
            bucket(wd, x + w // 2 + 8, base + 3, own)
    else:
        rubble(wd, x + int(rng.integers(0, w)), base + 3, int(4 + 8 * ruined), seed + 501, own)
        if rng.random() < 0.6:
            rubble(wd, x + int(rng.integers(0, w)), base + 5, 5, seed + 502, own)


# ------------------------------------------------------------------ the places
OWN = {}


def own_id(pid):
    if pid not in OWN:
        OWN[pid] = len(OWN) + 1
    return OWN[pid]


def lantern(wd, stage):
    """The Lantern: a squat monument at the plaza's heart. A round dais of setts with four bollards,
    a stepped octagonal plinth, a stone pedestal the company's banner hangs on, and a great iron
    lantern: a glass cage with the flame inside (animated), a pyramid cap and a ring on top."""
    cx, base = LANTERN
    o = own_id('lantern')
    L = Local(wd, cx - 48, base - 100, 96, 128, o)
    # the dais: a low round platform of setts (its front face 3 px), a lit rim
    dtop = L.ellipse(cx, base - 2, 42, 26)
    side = np.zeros((L.h, L.w), bool)
    for t in range(4):
        side |= L.ellipse(cx, base + 1 - t, 42, 26)
    side &= ~dtop
    L.shadow(L.ellipse(cx + 5, base + 4, 44, 26) & ~dtop & ~side, -1)
    rx = L.X - cx
    ry = (L.Y - (base - 2)) * 1.6
    rr = np.sqrt(rx * rx + ry * ry)
    cid = (rr / 5).astype(np.int64) * 1000 + ((np.arctan2(ry, rx) + np.pi) * np.maximum(rr, 5) / 7).astype(np.int64)
    cells_paving(L, dtop, cid, 51, ['fade3', 'fade2', 'ink8', 'fade3'], 'ink5')
    L.owner[dtop] = o
    bricks(L, side, 7, 3, 52, ['ink6', 'ink5', 'ink6'], 'ink4', kind=K_WALL, gy=base + 4, hz=2, lip=False)
    L.owner[side] = o
    rimm = dtop & ~L.ellipse(cx, base - 1.2, 41, 25)
    L.put(rimm & (L.Y < base - 2), 'fade4', K_TOP, base, 3, lip=True)
    L.put(rimm & (L.Y >= base - 2), 'fade3', K_TOP, base, 3, lip=True)
    # an inlaid brass ring and a compass of four points in the dais
    ringm = dtop & (np.abs(rr - 33) < 0.7)
    L.put(ringm, 'ink5', K_GROUND)
    for a in range(4):
        ang = a * np.pi / 2 + np.pi / 4
        px, py = cx + np.cos(ang) * 33, base - 2 + np.sin(ang) * 33 / 1.6
        L.put(L.ellipse(px, py, 1.6, 1.2), 'ink6', K_GROUND)
        L.put(L.rect(int(px) - 1, int(py) - 1, 1, 1), 'fade4', K_GROUND, lip=True)
    # four bollards on the dais' rim with a chain between neighbours
    for a in (0.25, 0.75, 1.25, 1.75):
        ang = a * np.pi
        bx, by = cx + np.cos(ang) * 38, base - 2 + np.sin(ang) * 38 / 1.6
        bx, by = int(round(bx)), int(round(by))
        post = L.rect(bx - 1, by - 6, 3, 6)
        drop_shadow(L, post, 2, 1, -1)
        L.put(post, 'ink4', K_VERT, by, 3)
        L.put(post & (L.X == bx - 1), 'ink6', K_VERT, by, 3, lip=True)
        L.put(L.rect(bx - 1, by - 7, 3, 1), 'amber4', K_TOP, by, 7, lip=True)
    # the plinth: two stepped octagons (seen from above at a slant)
    for k, (rxk, ryk, hgt, tone) in enumerate(((22, 11, 6, 'ink6'), (16, 8, 5, 'ink7'))):
        yb = base - 4 - k * 6
        topm = L.ellipse(cx + 0.5, yb - hgt, rxk, ryk) & (np.abs(L.X - cx - 0.5) + np.abs(L.Y - (yb - hgt)) * rxk / ryk * 0.75 < rxk * 1.18)
        sd = np.zeros((L.h, L.w), bool)
        for t in range(hgt + 1):
            sd |= L.ellipse(cx + 0.5, yb - t, rxk, ryk) & (np.abs(L.X - cx - 0.5) + np.abs(L.Y - (yb - t)) * rxk / ryk * 0.75 < rxk * 1.18)
        sd &= ~topm
        bricks(L, sd, 6, 2, 53 + k, [tone, 'ink5', tone], 'ink4', kind=K_WALL, gy=base + 2, hz=4 + k * 6, lip=False)
        L.owner[sd] = o
        L.put(sd & (L.X < cx - rxk * 0.55), STEP[MAXS + 1, IDX[tone]], K_WALL, base + 2, 4 + k * 6)
        L.put(sd & (L.X > cx + rxk * 0.6), STEP[MAXS - 1, IDX[tone]], K_WALL, base + 2, 4 + k * 6)
        L.put(topm, 'fade2', K_TOP, base, 8 + k * 6)
        L.put(topm & ~L.ellipse(cx + 0.5, yb - hgt + 0.8, rxk - 1, ryk - 1), 'fade4', K_TOP, base, 8 + k * 6, lip=True)
    # the pedestal: a square stone pillar, its front face carrying the banner
    px0, px1 = cx - 10, cx + 11
    ptop, pbot = base - 46, base - 15
    ped = L.rect(px0, ptop, px1 - px0, pbot - ptop)
    bricks(L, ped, 6, 3, 57, ['fade2', 'ink7', 'fade2', 'fade1'], 'ink5', kind=K_WALL, gy=base, hz=0, lip=False)
    L.hz[ped] = (base - L.Y[ped])
    L.owner[ped] = o
    L.put(ped & (L.X < px0 + 2), 'fade3', K_WALL, base, 20, lip=True)
    L.put(ped & (L.X >= px1 - 3), 'ink5', K_WALL, base, 20)
    L.put(ped & (L.X == px1 - 3), 'ink4', K_WALL, base, 20)
    # base moulding and cornice
    L.put(L.rect(px0 - 2, pbot - 3, px1 - px0 + 4, 3), 'ink7', K_WALL, base, 14)
    L.put(L.rect(px0 - 2, pbot - 3, px1 - px0 + 4, 1), 'fade4', K_WALL, base, 14, lip=True)
    L.put(L.rect(px0 - 2, ptop - 3, px1 - px0 + 4, 4), 'ink7', K_WALL, base, 48)
    L.put(L.rect(px0 - 2, ptop - 3, px1 - px0 + 4, 1), 'fade4', K_TOP, base, 50, lip=True)
    L.put(L.rect(px0 - 2, ptop, px1 - px0 + 4, 1), 'ink4', K_WALL, base, 46)
    # the banner's brass rod
    L.put(L.rect(cx - 10, ptop + 2, 21, 1), 'amber4', K_VERT, base, 44, lip=True)
    L.put(L.rect(cx - 11, ptop + 1, 2, 3) | L.rect(cx + 10, ptop + 1, 2, 3), 'amber3', K_VERT, base, 44)
    layout['banner'] = [cx - 10, ptop + 3]
    # the lantern: an iron base plate with a brass rim
    gy0 = ptop - 3
    L.put(L.rect(cx - 14, gy0 - 4, 29, 4), 'ink3', K_VERT, base, 52)
    L.put(L.rect(cx - 14, gy0 - 4, 29, 1), 'amber4', K_VERT, base, 54, lip=True)
    L.put(L.rect(cx - 12, gy0 - 1, 25, 1), 'ink2', K_VERT, base, 50)
    # the glass cage: slightly wider at the top, four panes of lit glass between iron posts
    gb, gt = gy0 - 4, gy0 - 28
    cage = L.poly([(cx - 11, gb), (cx + 12, gb), (cx + 14, gt), (cx - 13, gt)])
    L.put(cage, 'amber6', K_EMIT, base, 70)
    L.put(cage & L.rect(cx - 8, gt + 3, 17, 19), 'amber7', K_EMIT, base, 70)
    L.put(cage & (L.Y > gb - 4), 'amber5', K_EMIT, base, 70)
    sl = (gb - L.Y) / float(gb - gt)
    bars = cage & ((np.abs(L.X - (cx - 11 - 2 * sl)) < 1.0) | (np.abs(L.X - (cx + 12 + 2 * sl)) < 1.0) |
                   (np.abs(L.X - (cx - 4 - 0.6 * sl)) < 0.5) | (np.abs(L.X - (cx + 5 + 0.6 * sl)) < 0.5) |
                   (L.Y == gt + 11))
    L.put(bars, 'ink3', K_VERT, base, 70)
    L.put(bars & (L.X < cx - 9), 'ink5', K_VERT, base, 70, lip=True)
    L.put(L.rect(cx - 13, gt - 1, 28, 2), 'ink3', K_VERT, base, 78)
    # the cap: a pyramid of iron plates, a lit rim on the moon side, a finial ring
    cap = L.poly([(cx - 17, gt - 1), (cx + 18, gt - 1), (cx + 4, gt - 13), (cx - 3, gt - 13)])
    L.put(cap, 'ink3', K_ROOF_S, base, 90)
    L.put(cap & (L.X < cx - 2), 'ink5', K_ROOF_W, base, 90)
    L.put(cap & (L.X > cx + 6), 'ink2', K_ROOF_E, base, 90)
    L.put(cap & ((L.X.astype(int) - cx) % 5 == 0), 'ink2', K_ROOF_S, base, 90)
    L.put(L.rect(cx - 17, gt - 1, 35, 1), 'amber3', K_ROOF_S, base, 88, lip=True)
    L.put(L.line([(cx - 17, gt - 1), (cx - 3, gt - 13)], 1), 'ink6', K_ROOF_W, base, 92, lip=True)
    ring = L.ellipse(cx + 0.5, gt - 17, 3.5, 3.5) & ~L.ellipse(cx + 0.5, gt - 17, 1.8, 1.8)
    L.put(ring, 'amber4', K_VERT, base, 96, lip=True)
    L.put(ring & (L.X > cx + 1), 'amber2', K_VERT, base, 96)
    L.put(L.rect(cx - 1, gt - 14, 3, 1), 'ink4', K_VERT, base, 94)
    # the flame burns in the cage (animated in Godot)
    layout['flame'] = [cx - 5, gt + 5]
    zone = [cx - 30, gt - 22, 61, base + 10 - (gt - 22)]
    layout['places']['lantern'] = {'zone': zone, 'sign': [cx, gt - 24]}
    layout['lights'].append({'id': 'lantern', 'x': cx, 'y': base, 'h': 70, 'r': 210, 'k': 0.95,
                             'color': 'lantern', 'glow': 'glow_lantern', 'gx': cx + 1, 'gy': gt + 12,
                             'place': 'lantern', 'stage': 'fresh'})


def banner_cloth(px=19, h=22):
    """The company banner on the Lantern's pedestal (the crest is drawn over it in Godot), 3 sway
    frames."""
    frames = []
    for f in range(3):
        cv = np.full((h + 5, px + 4), -1, np.int32)
        sway = [0, 1, -1][f]
        for y in range(h):
            off = int(round(sway * (y / h) ** 2 * 1.5)) if y > 2 else 0
            x0 = 1 + off
            row = np.full(px, IDX['blood2'])
            row[0] = IDX['amber4']
            row[-1] = IDX['amber4']
            row[1] = IDX['blood3']
            row[-2] = IDX['blood1']
            if y < 1:
                row[:] = IDX['amber4']
            cv[y, x0: x0 + px] = row
            if y == h - 3:
                cv[y, x0 + 1: x0 + px - 1] = IDX['amber3']
        for y in range(h, h + 5):
            k = y - h
            off = int(round(sway * 1.5))
            l0 = 1 + off + k
            r0 = 1 + off + px - k
            cv[y, l0: 1 + off + px // 2 - k // 2] = IDX['blood2']
            cv[y, 1 + off + px // 2 + 1 + k // 2: r0] = IDX['blood2']
            cv[y, l0] = IDX['amber4']
            cv[y, r0 - 1] = IDX['amber4']
        frames.append(cv)
    return frames


def flame_frames():
    shapes = [
        ["....7.....", "...77.....", "...767....", "..7667....", "..76667...", ".766567...", ".765556...",
         "766555667.", ".6555556..", ".6555556..", "..65556...", "...666...."],
        [".....7....", "....77....", "...767....", "...7667...", "..76667...", "..765667..", ".7655567..",
         ".66555566.", ".6555556..", "..655556..", "..65556...", "...666...."],
        ["...7......", "...77.....", "..767.....", "..7667....", ".76667....", ".7656667..", ".6655567..",
         "7665556...", ".6555556..", ".6555556..", "..65556...", "...666...."],
        ["......7...", ".....77...", "....767...", "...7667...", "..766667..", "..765567..", ".7655566..",
         ".66555667.", ".6555556..", ".6555556..", "..65556...", "...666...."],
    ]
    cmap = {'7': 'amber7', '6': 'amber6', '5': 'amber5'}
    out = []
    for s in shapes:
        cv = np.full((len(s), len(s[0])), -1, np.int32)
        for y, row in enumerate(s):
            for x, ch in enumerate(row):
                if ch in cmap:
                    cv[y, x] = IDX[cmap[ch]]
        out.append(cv)
    return out


def vault(wd, stage):
    """The Vault entrance: a carved stone portal in a rock outcrop. Grass and a crystal vein on the
    rock, a lintel with Lumari crystal inlays, carved jambs, the dark mouth with worn steps going
    down and cold light rising out of it; a marker stone with a crystal and a trodden path."""
    cx, base = 768, 338
    o = own_id('vault')
    L = Local(wd, cx - 64, base - 100, 128, 124, o)
    rng = rng_for(61)
    # the outcrop: angular boulders, back to front; each has a lit top face and a darker front
    # face, a light rim where its top meets the sky, ink crevices between them, moss on the tops
    L.shadow(L.ellipse(cx + 14, base - 4, 64, 14), -2)
    boulders = [
        [(cx - 30, base - 72), (cx - 8, base - 90), (cx + 16, base - 88), (cx + 30, base - 70), (cx + 20, base - 50), (cx - 24, base - 52)],
        [(cx - 58, base - 40), (cx - 50, base - 66), (cx - 26, base - 74), (cx - 12, base - 56), (cx - 20, base - 20), (cx - 52, base - 14)],
        [(cx + 14, base - 58), (cx + 34, base - 76), (cx + 56, base - 66), (cx + 62, base - 36), (cx + 52, base - 14), (cx + 18, base - 18)],
        [(cx - 64, base - 8), (cx - 62, base - 26), (cx - 44, base - 34), (cx - 30, base - 22), (cx - 34, base - 4)],
        [(cx + 34, base - 6), (cx + 38, base - 28), (cx + 56, base - 34), (cx + 66, base - 20), (cx + 62, base - 4)],
    ]
    rock = np.zeros((L.h, L.w), bool)
    for k, pts in enumerate(boulders):
        m = L.poly(pts)
        ys = [p_[1] for p_ in pts]
        fh = max(6, int((max(ys) - min(ys)) * 0.42))
        front = m & ~shift_mask(m, 0, -fh)
        topf = m & ~front
        xs_ = [p_[0] for p_ in pts]
        u = (L.X - min(xs_)) / max(1, max(xs_) - min(xs_))
        tt = np.array([IDX[n] for n in ('ink8', 'ink7', 'ink6')])
        ft = np.array([IDX[n] for n in ('ink5', 'ink4', 'violet1', 'ink3')])
        L.put(topf, tt[np.clip((u * 3).astype(int), 0, 2)], K_ROOF_N, base - 6, 40)
        L.put(front, ft[np.clip((u * 4).astype(int), 0, 3)], K_WALL, base - 6, base - 6 - L.Y)
        up_, dn_, lf_, rt_ = edges(m)
        L.put(topf & ~up_, 'ink9', K_ROOF_N, base - 6, 44, lip=True)
        L.put(topf & ~lf_ & (u < 0.5), 'ink8', K_ROOF_N, base - 6, 44, lip=True)
        L.put(front & ~dn_, 'ink2', K_WALL, base - 6, 2)
        L.put(outer(m) & rock, 'ink2', K_WALL, base - 6, 20)
        # cracks: a line or two down the front, a chip on the top
        c0 = pts[1]
        L.put(L.line([(c0[0] + 4, c0[1] + fh), (c0[0] + 8, c0[1] + fh + 10)], 1) & front, 'ink2', K_WALL, base - 6, 10)
        L.put(L.line([(c0[0] + 6, c0[1] + 4), (c0[0] + 12, c0[1] + 6)], 1) & topf, 'ink5', K_ROOF_N, base - 6, 40)
        # moss on the top face
        moss = topf & (L.noise(4, 63 + k) > 0.62)
        L.put(moss, 'life2', K_ROOF_N, base - 6, 42)
        L.put(moss & (L.noise(1, 66 + k) > 0.6), 'life3', K_ROOF_N, base - 6, 42, lip=True)
        rock |= m
    L.put(outer(rock) & (L.kind == K_GROUND), 'ink2', K_TOP, base - 6, 2)
    for (tx_, ty_) in ((cx - 40, base - 70), (cx + 40, base - 74), (cx - 2, base - 92), (cx + 58, base - 40)):
        stamp(wd, tx_, ty_, 'tuft2', None, None)
    # a crystal vein in the rock (Lumari)
    for (vx, vy, vl) in ((cx - 36, base - 40, 7), (cx + 38, base - 46, 6), (cx + 26, base - 22, 5)):
        sh_ = L.poly([(vx - 2, vy), (vx + 2, vy), (vx + 1, vy - vl), (vx - 1, vy - vl)])
        L.put(sh_, 'crystal3', K_EMIT, base - 6, 30)
        L.put(sh_ & (L.X < vx), 'crystal5', K_EMIT, base - 6, 30)
        L.put(L.rect(vx + 3, vy - 3, 2, 3), 'crystal2', K_EMIT, base - 6, 30)
    # the portal: a carved frame cut into the rock's south face
    fx0, fx1 = cx - 20, cx + 21
    ftop, fbot = base - 54, base - 8
    frame = L.rect(fx0, ftop, fx1 - fx0, fbot - ftop)
    bricks(L, frame, 7, 4, 67, ['ink7', 'fade2', 'ink7', 'ink8'], 'ink4', kind=K_WALL, gy=base - 6, hz=0)
    L.hz[frame] = base - L.Y[frame]
    L.owner[frame] = o
    # the lintel: a heavy stone with crystal inlays and a keystone
    lin = L.poly([(fx0 - 5, ftop + 2), (fx1 + 5, ftop + 2), (fx1 + 2, ftop - 6), (fx0 - 2, ftop - 6)])
    L.put(lin, 'fade2', K_WALL, base - 6, 50)
    L.put(lin & (L.Y < ftop - 4), 'fade3', K_WALL, base - 6, 52, lip=True)
    L.put(lin & (L.Y > ftop), 'ink6', K_WALL, base - 6, 48)
    for k in range(5):
        ix = fx0 + 2 + k * 8
        L.put(L.rect(ix, ftop - 3, 3, 2), 'crystal4', K_EMIT, base - 6, 50)
        L.put(L.rect(ix, ftop - 3, 1, 1), 'crystal5', K_EMIT, base - 6, 50)
    ks = L.poly([(cx - 4, ftop - 9), (cx + 5, ftop - 9), (cx + 3, ftop + 1), (cx - 2, ftop + 1)])
    L.put(ks, 'ink7', K_WALL, base - 6, 54)
    L.put(L.poly([(cx - 2, ftop - 7), (cx + 3, ftop - 7), (cx + 0.5, ftop - 1)]), 'crystal5', K_EMIT, base - 6, 54)
    L.put(L.rect(cx, ftop - 6, 1, 3), 'ink10', K_EMIT, base - 6, 54)
    # carved jambs: runes and a column of crystal studs
    for jx in (fx0 + 1, fx1 - 6):
        jamb = L.rect(jx, ftop + 3, 5, fbot - ftop - 3)
        L.put(jamb, 'ink7', K_WALL, base - 6, 20)
        L.put(jamb & (L.X == jx), 'fade3', K_WALL, base - 6, 20, lip=True)
        L.put(jamb & (L.X == jx + 4), 'ink5', K_WALL, base - 6, 20)
        for k in range(5):
            ry_ = ftop + 6 + k * 8
            L.put(L.rect(jx + 2, ry_, 1, 4) | L.rect(jx + 1, ry_ + 1, 3, 1), 'ink4', K_WALL, base - 6, 20)
            if k % 2 == 0:
                L.put(L.rect(jx + 2, ry_ + 5, 1, 1), 'crystal4', K_EMIT, base - 6, 20)
    # the mouth: dark, steps going down into it, cold light from below (brighter deeper)
    mx0, mx1 = fx0 + 6, fx1 - 6
    mouth = L.rect(mx0, ftop + 3, mx1 - mx0, fbot - ftop - 3)
    L.put(mouth, 'ink1', K_EMIT, base - 6, 10)
    for k in range(8):
        sy = fbot - 4 - k * 5
        tread = L.rect(mx0, sy, mx1 - mx0, 4) & mouth
        lipc = ['ink5', 'ink4', 'crystal1', 'crystal2', 'crystal2', 'crystal3', 'crystal3', 'crystal4'][k]
        body = ['ink3', 'ink2', 'ink2', 'ink2', 'crystal1', 'crystal1', 'crystal1', 'crystal2'][k]
        kd = K_TOP if k < 2 else K_EMIT
        L.put(tread, body, kd, base - 6, k * 2)
        L.put(tread & (L.Y == sy), lipc, kd, base - 6, k * 2, lip=k < 2)
        L.put(tread & (np.abs(L.X - cx) < 4) & (L.Y == sy), STEP[MAXS - 1, IDX[lipc]], kd, base - 6, k * 2)
    L.put(mouth & (L.Y < ftop + 7), 'crystal3', K_EMIT, base - 6, 10)
    L.put(mouth & (L.Y < ftop + 5) & (np.abs(L.X - cx) < 6), 'crystal4', K_EMIT, base - 6, 10)
    L.put(mouth & ((L.X == mx0) | (L.X == mx1 - 1)), 'ink1', K_EMIT, base - 6, 10)
    # the threshold and the worn steps up to it, an apron of flags
    apron = L.rect(cx - 26, base - 8, 53, 10) & ~L.rect(cx - 26, base - 8, 3, 3) & ~L.rect(cx + 24, base - 8, 3, 3)
    cid = ((L.X - cx + 100) // 7).astype(np.int64) * 100 + ((L.Y - base + 100) // 4).astype(np.int64)
    cells_paving(L, apron, cid, 68, ['ink7', 'fade2', 'ink7'], 'ink4')
    L.owner[apron] = o
    L.put(L.rect(mx0 - 2, base - 8, mx1 - mx0 + 4, 2), 'fade3', K_TOP, base, 2, lip=True)
    L.shadow(L.rect(cx - 26, base + 2, 54, 2), -1)
    # two crystal braziers flanking the steps
    for bx in (cx - 30, cx + 28):
        bowl = L.rect(bx - 2, base - 11, 6, 3)
        stem = L.rect(bx, base - 8, 2, 8)
        drop_shadow(L, stem | bowl, 2, 1, -1)
        L.put(stem, 'ink3', K_VERT, base, 6)
        L.put(bowl, 'ink4', K_VERT, base, 10)
        L.put(L.rect(bx - 2, base - 11, 6, 1), 'ink6', K_VERT, base, 10, lip=True)
        L.put(L.poly([(bx - 1, base - 11), (bx + 3, base - 11), (bx + 1, base - 17)]), 'crystal4', K_EMIT, base, 14)
        L.put(L.rect(bx, base - 14, 1, 2), 'crystal5', K_EMIT, base, 14)
    # the marker stone: a standing stone with a crystal set in its head
    sx, sy = cx + 46, base + 10
    ms = L.poly([(sx - 4, sy), (sx + 5, sy), (sx + 4, sy - 16), (sx, sy - 19), (sx - 3, sy - 15)])
    drop_shadow(L, ms, 3, 1, -2)
    L.put(ms, 'ink6', K_WALL, sy, sy - L.Y)
    L.put(ms & (L.X < sx - 1), 'ink7', K_WALL, sy, sy - L.Y, lip=True)
    L.put(ms & (L.X > sx + 2), 'ink5', K_WALL, sy, sy - L.Y)
    L.put(L.rect(sx - 1, sy - 13, 3, 3), 'crystal4', K_EMIT, sy, 14)
    L.put(L.rect(sx - 1, sy - 13, 1, 1), 'crystal5', K_EMIT, sy, 14)
    L.put(L.rect(sx - 1, sy - 8, 3, 1) | L.rect(sx, sy - 7, 1, 3), 'ink4', K_WALL, sy, 6)
    layout['places']['vault'] = {'zone': [cx - 52, base - 86, 104, 100], 'sign': [cx, base - 86]}
    layout['lights'].append({'id': 'vault', 'x': cx, 'y': base - 4, 'h': 20, 'r': 90, 'k': 0.72,
                             'color': 'cool', 'glow': 'glow_vault', 'gx': cx, 'gy': base - 40, 'place': 'vault',
                             'stage': 'fresh'})


def plot(wd, pid, x, y, w, h, seed, variant=0, board_at=(8, 2)):
    """An empty plot: a lot of trodden earth and weeds with a faint marker line of pegs and string,
    old foundations (each plot its own layout: footings, a cellar hole, a scorched floor, a timber
    pile), a broken fence, and a post-and-board sign with a hammer painted on it."""
    o = own_id(pid)
    rng = rng_for(seed)
    L = Local(wd, x - 8, y - 22, w + 18, h + 30, o)
    lot = L.rect(x, y, w, h)
    n = L.noise(5, seed, 2)
    L.put(lot, np.where(n > 0.55, IDX['skin1'], IDX['amber2']), K_GROUND)
    L.put(lot & (L.noise(1, seed + 7) > 0.88), 'skin2', K_GROUND)
    L.put(lot & (n < 0.32), np.where(L.noise(2, seed + 8) > 0.5, IDX['life2'], IDX['life1']), K_GROUND)
    for k in range(int(w * h / 80)):
        tx, ty = x + int(rng.integers(2, w - 6)), y + int(rng.integers(3, h - 4))
        stamp(wd, tx, ty, ['tuft', 'tuft2', 'pebble', 'blades', 'twig'][k % 5])
    fx0, fy0, fx1, fy1 = x + 14, y + 16, x + w - 14, y + h - 12
    if variant == 0:
        # footings: a broken rectangle of foundation stones with a corner stone
        ring = L.rect(fx0, fy0, fx1 - fx0, fy1 - fy0) & ~L.rect(fx0 + 4, fy0 + 4, fx1 - fx0 - 8, fy1 - fy0 - 8)
        ring &= L.noise(6, seed + 2) > 0.28
        bricks(L, ring, 5, 3, seed + 3, ['fade2', 'fade3', 'ink7'], 'ink5', kind=K_TOP, hz=2)
        L.owner[ring] = o
        L.shadow(outer(ring) & (L.Y > fy0), -1)
    elif variant == 1:
        # a cellar hole with planks over half of it
        hole = L.rect(fx0 + 6, fy0 + 4, fx1 - fx0 - 12, fy1 - fy0 - 8)
        L.put(hole, 'ink2', K_GROUND)
        L.put(hole & (L.Y < fy0 + 7), 'ink4', K_WALL, fy0 + 4, 3)
        for k in range(0, fx1 - fx0 - 12, 5):
            if k < (fx1 - fx0 - 12) * 0.55:
                L.put(L.rect(fx0 + 6 + k, fy0 + 3, 4, fy1 - fy0 - 6), 'amber2', K_TOP, fy1, 2)
                L.put(L.rect(fx0 + 6 + k, fy0 + 3, 4, 1), 'amber3', K_TOP, fy1, 2, lip=True)
        ring = outer(hole) & lot
        L.put(ring, 'ink6', K_TOP, fy1, 1, lip=True)
    elif variant == 2:
        # a scorched floor: cracked slabs, soot, a fallen beam
        fl = L.rect(fx0, fy0, fx1 - fx0, fy1 - fy0) & (L.noise(5, seed + 4) > 0.3)
        cid = ((L.X - x) // 9).astype(np.int64) * 100 + ((L.Y - y) // 6).astype(np.int64)
        cells_paving(L, fl, cid, seed + 5, ['ink6', 'fade1', 'ink5'], 'ink3')
        L.put(fl & (L.noise(4, seed + 6) > 0.7), 'ink3', K_GROUND)
        L.put(L.line([(fx0 + 4, fy1 - 4), (fx1 - 8, fy0 + 6)], 2), 'amber1', K_TOP, fy1, 2)
    else:
        # stakes and string, a pile of new timber and a stack of stones waiting
        L.put(L.rect(fx0 + 4, fy1 - 10, 22, 6), 'skin2', K_TOP, fy1, 3)
        for k in range(4):
            L.put(L.rect(fx0 + 4, fy1 - 10 + k * 2 - (k > 1), 22, 1), 'skin3' if k % 2 == 0 else 'amber2', K_TOP, fy1, 3, lip=k == 0)
        L.shadow(L.rect(fx0 + 6, fy1 - 4, 22, 2), -1)
        bricks(L, L.rect(fx1 - 22, fy0 + 4, 14, 8), 4, 2, seed + 9, ['fade2', 'ink7'], 'ink5', kind=K_TOP, hz=3)
    # the marker: pegs at the corners with a pale string between them (where the walls will stand)
    st = [(x + 6, y + 8), (x + w - 7, y + 8), (x + w - 7, y + h - 4), (x + 6, y + h - 4)]
    for (sx, sy) in st:
        L.put(L.rect(sx, sy - 5, 1, 5), 'amber4', K_VERT, sy, 3)
        L.put(L.rect(sx, sy - 6, 1, 1), 'blood3', K_VERT, sy, 5)
    for a, b in zip(st, st[1:] + st[:1]):
        s_ = L.line([(a[0], a[1] - 4), (b[0], b[1] - 4)], 1)
        L.put(s_ & (L.kind == K_GROUND), 'fade3', K_TOP, None, 3)
    rubble(wd, x + int(rng.integers(10, w - 10)), y + h - 6, 6, seed + 11, o)
    fence(wd, [(x, y + h), (x, y), (x + w - 2, y), (x + w - 2, y + h)], o, broken=0.3, seed=seed + 5)
    # the sign: a board on two posts, a hammer painted on it
    bx, by = x + board_at[0], y + board_at[1] + 16
    for px in (bx + 2, bx + 13):
        L.put(L.rect(px, by - 7, 2, 9), 'amber2', K_VERT, by + 2, 5)
        L.put(L.rect(px, by - 7, 1, 9), 'amber3', K_VERT, by + 2, 5, lip=True)
    board = L.rect(bx, by - 16, 17, 10)
    L.put(board, 'skin2', K_WALL, by + 2, 10)
    L.put(board & ((L.Y == by - 16) | (L.X == bx)), 'skin3', K_WALL, by + 2, 10, lip=True)
    L.put(board & ((L.Y == by - 7) | (L.X == bx + 16)), 'amber2', K_WALL, by + 2, 10)
    L.put(L.rect(bx + 4, by - 13, 7, 2) | L.rect(bx + 7, by - 11, 2, 4), 'ink3', K_WALL, by + 2, 10)
    L.put(L.rect(bx + 4, by - 13, 2, 2), 'amber5', K_WALL, by + 2, 10)
    L.shadow(L.rect(bx + 3, by + 2, 14, 2), -1)
    layout['places'][pid] = {'zone': [x - 2, y - 12, w + 4, h + 14], 'sign': [x + w // 2, y - 8],
                             'pin': [bx + 8, by - 17]}


def training_grounds(wd):
    """The Training Grounds: a fenced barracks yard of packed sand, a lean-to barracks with a
    weapon rack, straw dummies, an archery target and a banner; a lamp lights the yard."""
    pid = 'grounds'
    x, y, w, h = 1072, 448, 176, 96
    o = own_id(pid)
    L = Local(wd, x - 8, y - 46, w + 22, h + 56, o)
    yard = L.rect(x, y, w, h)
    n = L.noise(6, 72, 2)
    L.put(yard, 'skin3', K_GROUND)
    L.put(yard & (n > 0.62), 'skin2', K_GROUND)
    L.put(yard & (n < 0.3), 'amber3', K_GROUND)
    L.put(yard & (L.noise(1, 73) > 0.9), 'skin4', K_GROUND)
    for (rx_, ry_) in ((x + 31, y + 57), (x + 57, y + 63), (x + 83, y + 57)):
        L.put(yard & L.ellipse(rx_, ry_, 11, 5) & ~L.ellipse(rx_, ry_, 9, 3.6), 'skin2', K_GROUND)
    for k in range(30):
        r = rng_for(740 + k)
        stamp(wd, x + int(r.integers(4, w - 8)), y + int(r.integers(30, h - 4)), ['pebble', 'twig', 'tuft'][k % 3])
    smoke = house(wd, x + 6, y + 36, 74, 20, 22, roof='thatch', walls='timber', ridge='ew', own=o, seed=74,
                  windows=[8, 52], door=30, lit_windows=(1,), chimney=60)
    if smoke:
        layout['smoke'].append({'x': smoke[0], 'y': smoke[1], 'place': pid})
    rx = x + 88
    L.put(L.rect(rx, y + 6, 22, 2), 'amber2', K_VERT, y + 20, 12, lip=True)
    L.put(L.rect(rx, y + 16, 22, 2), 'amber1', K_VERT, y + 20, 4)
    for k in range(5):
        L.put(L.rect(rx + 2 + k * 4, y - 2 + (k % 2) * 2, 1, 20), 'ink6' if k % 2 else 'amber3', K_VERT, y + 20, 10)
        L.put(L.rect(rx + 1 + k * 4, y - 3 + (k % 2) * 2, 3, 2), 'ink8', K_VERT, y + 20, 18, lip=True)
    L.shadow(L.rect(rx + 2, y + 20, 22, 3), -1)
    for k, (dx, dy) in enumerate(((x + 30, y + 56), (x + 56, y + 62), (x + 82, y + 56))):
        post = L.rect(dx, dy - 22, 2, 22)
        body = L.ellipse(dx + 1, dy - 13, 5, 7)
        head = L.ellipse(dx + 1, dy - 23, 3.5, 3.5)
        arms = L.rect(dx - 7, dy - 17, 16, 2)
        L.shadow(L.ellipse(dx + 5, dy + 1, 8, 3), -2)
        L.put(post, 'amber2', K_VERT, dy, 10)
        L.put(arms, 'amber2', K_VERT, dy, 16, lip=True)
        L.put(body, 'amber4', K_VERT, dy, 12)
        L.put(body & (L.X > dx + 2), 'amber3', K_VERT, dy, 12)
        L.put(body & ((L.Y - dy) % 4 == 0), 'amber2', K_VERT, dy, 12)
        L.put(head, 'skin3', K_VERT, dy, 22, lip=True)
        L.put(head & (L.X > dx + 2), 'skin2', K_VERT, dy, 22)
        L.put(L.rect(dx - 1, dy - 24, 1, 1) | L.rect(dx + 2, dy - 24, 1, 1), 'ink2', K_VERT, dy, 22)
    tx, ty = x + 142, y + 54
    L.shadow(L.ellipse(tx + 6, ty + 2, 11, 3), -2)
    L.put(L.rect(tx - 7, ty - 14, 2, 14) | L.rect(tx + 6, ty - 14, 2, 14), 'amber2', K_VERT, ty, 8)
    for k, (r_, col) in enumerate(((10, 'fade4'), (8, 'blood2'), (6, 'fade4'), (4, 'blood2'), (2, 'amber5'))):
        L.put(L.ellipse(tx + 0.5, ty - 18, r_, r_), col, K_WALL, ty, 18)
    L.put(outer(L.ellipse(tx + 0.5, ty - 18, 10, 10)), 'amber1', K_WALL, ty, 18)
    L.put(L.line([(tx + 3, ty - 20), (tx + 9, ty - 25)], 1), 'amber3', K_VERT, ty, 22)
    bpx, bpy = x + 160, y + 26
    L.put(L.rect(bpx, bpy - 34, 2, 34), 'ink3', K_VERT, bpy, 20)
    L.put(L.rect(bpx - 1, bpy - 36, 4, 2), 'amber4', K_VERT, bpy, 34, lip=True)
    L.shadow(L.rect(bpx + 2, bpy, 6, 2), -1)
    layout['banners']['grounds'] = [bpx + 2, bpy - 33]
    fence(wd, [(x + 70, y), (x, y), (x, y + h), (x + w, y + h), (x + w, y), (x + 118, y)], o, broken=0.0, seed=75)
    head = lamp_post(wd, x + 124, y + 20, True, o)
    sacks(wd, x + 150, y + 90, o, 3)
    barrel(wd, x + 12, y + 92, o)
    layout['places'][pid] = {'zone': [x - 2, y - 12, w + 6, h + 16], 'sign': [x + 40, y - 12]}
    layout['lights'].append({'id': 'grounds_lamp', 'x': x + 130, 'y': y + 20, 'h': 24, 'r': 70, 'k': 0.62,
                             'color': 'warm', 'glow': 'glow_lamp', 'gx': head[0], 'gy': head[1], 'place': pid,
                             'stage': 'fresh'})


def fog_place(pid, x, y, w, h, sign):
    layout['places'][pid] = {'zone': [x, y, w, h], 'sign': list(sign)}


# ------------------------------------------------------------------ the town
STREET_LAMPS = [  # (x, base y, the stage that lights it: 'fresh' from the start, 'built' after the
    #               first run, None never (in the mist))
    (852, 384, 'built'), (1062, 384, 'fresh'), (852, 442, 'fresh'), (1060, 442, 'built'),
    (700, 384, 'fresh'), (1236, 384, 'built'), (920, 300, 'built'), (1000, 520, 'built'),
    (560, 384, None), (1390, 384, None), (920, 220, None), (1000, 612, None),
    (420, 442, None), (1520, 442, None),
]
LAMP_COLOR = {'lantern': (1.0, 0.80, 0.52), 'warm': (1.0, 0.72, 0.40), 'cool': (0.40, 0.92, 1.0), 'window': (1.0, 0.68, 0.36)}


def town(wd, stage):
    """Everything but the optional places: streets, the plaza, houses, ruins at the edges, trees,
    clutter, lamps. The cottages by the plaza are dark in a fresh town and lived in once built."""
    built = stage == 'built'
    road, walk, plaza, kerb = ground(wd, stage)
    path(wd, [(760, 346), (790, 372), (850, 388)], 12, 101)
    path(wd, [(1064, 374), (1064, 352)], 7, 102)
    path(wd, [(1172, 374), (1172, 352)], 7, 103)
    path(wd, [(990, 600), (1060, 600)], 7, 104)
    path(wd, [(640, 374), (640, 352)], 7, 105)
    path(wd, [(1424, 374), (1424, 352)], 6, 106)
    smoke = []
    # the two cottages by the plaza: dark and boarded at first, lived in once the town is rebuilt
    s = house(wd, 1028, 352, 72, 26, 34, roof='red', walls='plaster', ridge='ew', seed=201,
              windows=[8, 50], door=30, lit_windows=(0, 1) if built else (), chimney=56, sign=66 if built else None,
              boarded=not built, boxes=built, clutter='lived' if built else 'empty', ruined=0.0 if built else 0.12)
    if built:
        smoke.append(s)
    s = house(wd, 1132, 352, 84, 30, 42, roof='teal', walls='stone', ridge='ns', seed=202,
              windows=[10, 62], door=38, lit_windows=(1,) if built else (), chimney=12, vines=0.3,
              boarded=not built, boxes=built, clutter='lived' if built else 'empty', ruined=0.0 if built else 0.2)
    if built:
        smoke.append(s)
    house(wd, 604, 352, 72, 26, 34, roof='slate', walls='timber', ridge='ew', seed=203,
          windows=[10, 52], door=30, ruined=0.35, vines=0.5, boarded=True, clutter='empty')
    # second row (north, toward the mist): taller, emptier, greyer
    house(wd, 1000, 256, 96, 34, 46, roof='red', walls='plaster', ridge='ew', seed=204,
          windows=[10, 40, 72], door=58, ruined=0.4, vines=0.4, clutter='empty')
    house(wd, 1120, 250, 64, 28, 40, roof='slate', walls='stone', ridge='ns', seed=205,
          windows=[8], door=34, ruined=0.6, clutter='empty')
    house(wd, 812, 244, 64, 26, 36, roof='brown', walls='timber', ridge='ns', seed=206,
          windows=[8, 46], door=26, ruined=0.5, vines=0.6, clutter='empty')
    house(wd, 836, 168, 80, 30, 40, roof='red', walls='plaster', ridge='ew', seed=207,
          windows=[10, 58], door=34, ruined=0.7)
    house(wd, 1012, 160, 112, 36, 50, roof='slate', walls='stone', ridge='ew', seed=208,
          windows=[12, 44, 88], door=64, ruined=0.8)
    house(wd, 700, 186, 72, 28, 38, roof='teal', walls='plaster', ridge='ns', seed=209,
          windows=[8, 52], door=30, ruined=0.7)
    house(wd, 1220, 176, 80, 28, 40, roof='red', walls='timber', ridge='ew', seed=210,
          windows=[8, 52], door=30, ruined=0.8)
    # west, into the mist
    house(wd, 336, 352, 80, 28, 40, roof='red', walls='plaster', ridge='ns', seed=211,
          windows=[8, 60], door=36, ruined=0.8, clutter='empty')
    house(wd, 200, 360, 72, 26, 34, roof='slate', walls='stone', ridge='ew', seed=212,
          windows=[8], door=40, ruined=0.9)
    house(wd, 360, 520, 88, 30, 40, roof='brown', walls='timber', ridge='ew', seed=213,
          windows=[8, 64], door=40, ruined=0.7, clutter='empty')
    house(wd, 520, 528, 72, 26, 36, roof='red', walls='plaster', ridge='ns', seed=214,
          windows=[8, 54], door=30, ruined=0.6, vines=0.5, clutter='empty')
    house(wd, 420, 244, 72, 28, 38, roof='teal', walls='stone', ridge='ns', seed=215,
          windows=[8, 52], door=30, ruined=0.9)
    house(wd, 88, 520, 80, 28, 40, roof='red', walls='timber', ridge='ew', seed=216,
          windows=[8], door=40, ruined=1.0)
    # east, into the mist
    house(wd, 1516, 352, 88, 30, 42, roof='red', walls='plaster', ridge='ew', seed=221,
          windows=[8, 66], door=40, ruined=0.7, vines=0.4, clutter='empty')
    house(wd, 1648, 360, 72, 26, 36, roof='slate', walls='stone', ridge='ns', seed=222,
          windows=[8], door=30, ruined=0.9)
    house(wd, 1300, 528, 80, 28, 38, roof='teal', walls='timber', ridge='ew', seed=223,
          windows=[8, 60], door=36, ruined=0.5, vines=0.3, clutter='empty')
    house(wd, 1460, 540, 88, 30, 40, roof='red', walls='stone', ridge='ns', seed=224,
          windows=[10, 66], door=40, ruined=0.8, clutter='empty')
    house(wd, 1560, 236, 80, 28, 40, roof='brown', walls='plaster', ridge='ew', seed=225,
          windows=[8, 58], door=34, ruined=0.9)
    house(wd, 1760, 520, 80, 28, 40, roof='red', walls='plaster', ridge='ew', seed=226,
          windows=[8], door=40, ruined=1.0)
    house(wd, 1340, 244, 72, 28, 38, roof='red', walls='stone', ridge='ns', seed=227,
          windows=[8, 52], door=30, ruined=0.8)
    # south
    house(wd, 760, 640, 80, 28, 40, roof='slate', walls='plaster', ridge='ew', seed=231,
          windows=[8, 60], door=36, ruined=0.8)
    house(wd, 1150, 660, 96, 30, 42, roof='red', walls='stone', ridge='ew', seed=232,
          windows=[10, 70], door=44, ruined=0.9)
    # trees: a ring of old trees, a few by the houses (at least eave height)
    trees = [(1112, 306, 15, 'oak'), (888, 334, 12, 'oak'), (1276, 344, 17, 'oak'),
             (624, 462, 16, 'oak'), (1290, 466, 14, 'oak'), (860, 566, 17, 'oak'),
             (640, 254, 18, 'pine'), (1484, 304, 16, 'oak'), (300, 304, 18, 'pine'), (1640, 304, 17, 'pine'),
             (640, 606, 18, 'oak'), (1250, 616, 16, 'oak'), (480, 446, 14, 'oak'), (1420, 456, 15, 'pine'),
             (180, 466, 18, 'oak'), (1740, 466, 18, 'oak'), (1840, 304, 20, 'pine'), (80, 304, 20, 'pine'),
             (960, 134, 16, 'pine'), (760, 124, 18, 'oak'), (1160, 114, 17, 'pine'), (1400, 144, 18, 'oak'),
             (500, 144, 18, 'pine'), (1700, 144, 18, 'oak'), (260, 144, 20, 'oak'), (1880, 606, 20, 'oak'),
             (40, 646, 20, 'pine'), (1560, 666, 18, 'pine'), (360, 666, 18, 'oak'), (960, 696, 17, 'oak'),
             (560, 330, 13, 'oak'), (1278, 548, 12, 'oak')]
    for i, (tx, ty, r, k) in enumerate(trees):
        tree(wd, tx, ty, r, 300 + i, kind=k)
    for i, (bx, by) in enumerate([(1024, 358), (1104, 358), (1128, 358), (1222, 360), (598, 358), (682, 358),
                                  (1010, 474), (830, 474), (1288, 404), (628, 404), (1000, 350), (742, 354),
                                  (796, 354), (900, 500), (1180, 470)]):
        bush(wd, bx, by, 5 + i % 3, 400 + i, berries=i % 4 == 0)
    # the plaza's furniture: the well, benches (broken at first), planters and bunting once built
    well(wd, 884, 496)
    bench(wd, 898, 366, broken=not built)
    bench(wd, 1004, 366)
    bench(wd, 1006, 476, broken=not built)
    if built:
        for (px, py) in ((872, 362), (1030, 362), (872, 474), (1028, 488)):
            planter(wd, px, py, 18, 0, True, px)
        bunting(wd, 932, 990, 300, 9)
        bunting(wd, 1086, 1150, 372, 11)
        crate(wd, 1290, 430)
        barrel(wd, 1300, 440)
    else:
        rubble(wd, 1290, 436, 6, 33)
    barrel(wd, 640, 462)
    crate(wd, 690, 342)
    crate(wd, 694, 335, w=7, h=5, top=3)
    sacks(wd, 716, 350, n=2)
    firewood(wd, 586, 360)
    bucket(wd, 1122, 362)
    # fences along the street edges near the plots and the far ends
    fence(wd, [(1290, 476), (1360, 476)], broken=0.3, seed=501)
    fence(wd, [(560, 476), (660, 476)], broken=0.4, seed=502)
    fence(wd, [(1180, 342), (1250, 342)], broken=0.1, seed=503)
    # signposts where the streets go into the mist
    signpost(wd, 230, 378, 1, arrow=-1)
    signpost(wd, 1690, 378, 2, arrow=1)
    signpost(wd, 970, 90, 3, arrow=-1)
    signpost(wd, 946, 640, 4, arrow=1)
    # street lamps
    for (lx, ly, st) in STREET_LAMPS:
        lit = st == 'fresh' or (st == 'built' and built)
        head = lamp_post(wd, lx, ly, lit, broken=st is None and lx in (420, 1520))
        if st is not None:
            layout['lights'].append({'id': 'lamp_%d_%d' % (lx, ly), 'x': lx + 6, 'y': ly, 'h': 22, 'r': 84, 'k': 0.8,
                                     'color': 'warm', 'glow': 'glow_lamp', 'gx': head[0], 'gy': head[1], 'stage': st})
    # lit windows throw a little warm light (built)
    for (wx_, wy_) in ((1040, 332), (1082, 332), (1198, 328)):
        layout['lights'].append({'id': 'window_%d' % wx_, 'x': wx_, 'y': 360, 'h': 18, 'r': 34, 'k': 0.45,
                                 'color': 'window', 'glow': 'glow_window', 'gx': wx_, 'gy': wy_, 'stage': 'built'})
    fog_ruins(wd, stage)
    for s_ in smoke:
        if s_:
            layout['smoke'].append({'x': s_[0], 'y': s_[1], 'stage': 'built'})
    return road, walk, plaza


RESERVED = [  # place zones and their surroundings: no ruins or trees here
    (650, 236, 230, 130), (900, 280, 130, 160), (470, 270, 140, 100), (680, 440, 140, 100),
    (1060, 420, 200, 140), (1326, 270, 140, 100), (1000, 545, 130, 95),
]


def free_box(wd, x, y, w, h):
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x1 <= x0 or y1 <= y0:
        return False
    for rx, ry, rw, rh in RESERVED:
        if x < rx + rw and x + w > rx and y < ry + rh and y + h > ry:
            return False
    k = wd.kind[y0:y1, x0:x1]
    return bool((k == K_GROUND).all())


def fog_ruins(wd, stage):
    """The half-erased town under the mist: rows of ruined houses along broken back streets,
    placed where nothing else stands (the same in every stage)."""
    rng = rng_for(901)
    roofs = ['red', 'slate', 'teal', 'brown', 'red', 'thatch']
    walls_ = ['plaster', 'stone', 'timber', 'brick']
    rows = [(118, range(40, 1880, 112)), (700, range(20, 1880, 116)), (604, range(40, 600, 120)),
            (604, range(1360, 1880, 120)), (300, range(40, 330, 120)), (300, range(1620, 1880, 120)),
            (460, range(20, 300, 118)), (460, range(1650, 1880, 118))]
    n = 0
    for base, xs in rows:
        for x0 in xs:
            x = int(x0 + rng.integers(-10, 10))
            w = int(rng.choice([64, 72, 80, 96]))
            wall_h = int(rng.integers(24, 34))
            roof_h = int(rng.integers(32, 48))
            b = int(base + rng.integers(-8, 8))
            ridge = 'ns' if rng.random() < 0.45 else 'ew'
            ruin = float(rng.uniform(0.55, 1.0))
            vines = float(rng.uniform(0, 0.6))
            if not free_box(wd, x - 6, b - wall_h - roof_h - 10, w + 24, wall_h + roof_h + 16):
                continue
            n += 1
            wins = [8, w - 16] if w > 70 else [8]
            house(wd, x, b, w, wall_h, roof_h, roof=roofs[n % len(roofs)], walls=walls_[n % len(walls_)],
                  ridge=ridge, seed=1000 + n, windows=wins, door=w // 2 - 4, ruined=ruin, vines=vines,
                  clutter='empty')
    for k in range(60):
        tx, ty = int(rng.integers(20, W - 20)), int(rng.integers(40, H - 4))
        r = int(rng.integers(14, 21))
        f = fog_field(np.array([[tx]], np.float32), np.array([[ty]], np.float32))
        if f[0, 0] < 0.35:
            continue
        if free_box(wd, tx - r - 4, ty - 2 * r - 18, 2 * r + 12, 2 * r + 22):
            tree(wd, tx, ty, r, 1500 + k, kind='pine' if k % 3 == 0 else 'oak')


PLACES = {
    'lantern': lantern,
    'vault': vault,
    'plot_w1': lambda wd: plot(wd, 'plot_w1', 688, 456, 120, 72, 801, 0, (8, 2)),
    'plot_w2': lambda wd: plot(wd, 'plot_w2', 480, 288, 112, 64, 802, 1, (8, 0)),
    'plot_e1': lambda wd: plot(wd, 'plot_e1', 1088, 456, 144, 80, 803, 3, (10, 2)),
    'plot_e2': lambda wd: plot(wd, 'plot_e2', 1336, 288, 112, 64, 804, 2, (8, 0)),
    'plot_s1': lambda wd: plot(wd, 'plot_s1', 1008, 560, 112, 64, 805, 0, (8, 0)),
    'grounds': training_grounds,
}
OPTIONAL = ['plot_w1', 'plot_w2', 'plot_e1', 'plot_e2', 'plot_s1', 'grounds']


# ------------------------------------------------------------------ the Fading
def fade_world(wd, stage):
    """Erases the town into the mist: colour drains first from the ground, then from everything;
    dark outlines fade to grey; deeper in, whole chunks are gone (flat grey nothing with a pale
    frayed edge); streets were already broken apart where they were laid."""
    fog = fog_field(wd.X, wd.Y, stage)
    valid = wd.idx >= 0
    emit = wd.kind == K_EMIT
    rag = fbm(W, H, 10, 2, 81).astype(np.float32)
    f = fog + 0.26 * (rag - 0.5)
    half = valid & ~emit & (f > 0.22) & ((wd.kind == K_GROUND) | (f > 0.34))
    wd.idx[half] = HALF[wd.idx[half]]
    grey = valid & (f > 0.46)
    wd.idx[grey] = GRAY[wd.idx[grey]]
    # outlines fade: the darkest pixels lift to grey
    dk = valid & (f > 0.38) & np.isin(wd.idx, [IDX['ink1'], IDX['ink2'], IDX['ink3']])
    wd.idx[dk] = IDX['fade1']
    # erased chunks: blocky (4 px cells) so the gaps read as missing pieces, not noise
    cx, cy = (wd.X // 4).astype(np.int64), (wd.Y // 3).astype(np.int64)
    blk = hash01(cx, cy, 82)
    e = fog + 0.34 * (fbm(W, H, 12, 3, 83) - 0.5) + 0.10 * (blk - 0.5)
    gone = valid & (e > 0.66)
    edge = outer(gone) & valid
    wd.idx[gone] = IDX['fade2']
    wd.kind[gone] = K_GROUND
    wd.lip[gone] = False
    # a few remnant marks inside the nothing (a post, a stone) keep it from reading as a flat fill
    rem = gone & (hash01(cx, cy, 84) > 0.985)
    wd.idx[rem] = IDX['fade1']
    up = np.zeros_like(gone); up[1:] = gone[:-1]
    lf = np.zeros_like(gone); lf[:, 1:] = gone[:, :-1]
    fr = edge & (up | lf)
    wd.idx[fr] = IDX['fade3']
    return fog


# ------------------------------------------------------------------ light
def light_map(wd, lights, fog, stage):
    """The night light (H, W, 3) float in 0..1: an indigo night, warm and cold pools that tint
    toward their colour by distance and facing, a catch-light on edges facing a lamp, emissive
    pixels at full. Smooth: no bands."""
    kind = wd.kind
    valid = wd.idx >= 0
    amb = np.array([0.44, 0.50, 0.70], np.float32)
    famb = np.array([0.46, 0.48, 0.56], np.float32)
    Lm = amb[None, None, :] * (1 - fog[..., None]) + famb[None, None, :] * fog[..., None]
    # surfaces facing away from the moon sit a little deeper in the night
    form = np.ones((H, W), np.float32)
    form[kind == K_WALL] = 0.92
    form[kind == K_ROOF_E] = 0.88
    form[(kind == K_ROOF_N) | (kind == K_ROOF_W)] = 1.06
    Lm *= form[..., None]
    wsum = np.zeros((H, W), np.float32)
    csum = np.zeros((H, W, 3), np.float32)
    keep = np.ones((H, W), np.float32)
    rim = np.zeros((H, W), np.float32)
    nrm = np.zeros((H, W, 3), np.float32)
    for k, n in NORMALS.items():
        nrm[kind == k] = n
    raised = (kind != K_GROUND) & valid
    for l in lights:
        r = l['r']
        x0, x1 = int(max(0, l['x'] - r)), int(min(W, l['x'] + r + 1))
        y0, y1 = int(max(0, l['y'] - r)), int(min(H, l['y'] + r + 1))
        sl = (slice(y0, y1), slice(x0, x1))
        X, Y, gy, hz = wd.X[sl], wd.Y[sl], wd.gy[sl], wd.hz[sl]
        dx = l['x'] - X
        dy = l['y'] - gy
        dz = l['h'] - hz
        dist = np.sqrt(dx * dx + dy * dy) + 1e-3
        d3 = np.sqrt(dx * dx + dy * dy + dz * dz) + 1e-3
        n_ = nrm[sl]
        lam = np.clip((n_[..., 0] * dx + n_[..., 1] * dy + n_[..., 2] * dz) / d3, 0, 1)
        ks = kind[sl]
        lam = np.where(ks == K_GROUND, 1.0, 0.25 + 0.75 * lam)
        t = np.clip(dist / r, 0, 1)
        fall = (1 - t * t) ** 2 * (0.55 + 0.45 * np.exp(-3.0 * t))
        wv = np.clip(l['k'] * fall * lam, 0, 0.98).astype(np.float32)
        c = np.array(LAMP_COLOR[l['color']], np.float32)
        wsum[sl] += wv
        csum[sl] += wv[..., None] * c[None, None, :]
        keep[sl] *= (1 - wv)
        # catch-light: lips (kerb tops, brick lips, rails, rims) and raised edges facing the lamp
        sx = np.sign(dx).astype(int)
        sy = np.sign((l['y'] - l['h'] * 0.5) - Y).astype(int)
        rs = raised[sl]
        pad = np.pad(rs, 1)
        hh, ww = rs.shape
        yy, xx = np.mgrid[0:hh, 0:ww]
        nb = pad[np.clip(yy + sy + 1, 0, hh + 1), np.clip(xx + sx + 1, 0, ww + 1)]
        edge = rs & ~nb
        rim[sl] += (wd.lip[sl] * 0.55 + edge * 0.45) * wv * 1.25
    wl = 1 - keep
    cmix = csum / np.maximum(wsum[..., None], 1e-5)
    out = Lm * (1 - wl[..., None]) + cmix * 0.92 * wl[..., None]
    out += rim[..., None] * np.where(wsum[..., None] > 0, cmix, 0) * 0.5
    out = np.clip(out, 0, 1)
    out[kind == K_EMIT] = 1.0
    out[~valid] = 0
    return out


# ------------------------------------------------------------------ output
def save_idx(a, name, x0=0, y0=0, alpha=None):
    os.makedirs(OUT, exist_ok=True)
    h, w = a.shape
    out = np.zeros((h, w, 4), np.uint8)
    m = a >= 0
    out[m, :3] = RGB[a[m]]
    out[m, 3] = 255 if alpha is None else alpha[m]
    Image.fromarray(out, 'RGBA').save(os.path.join(OUT, name + '.png'))
    layout['layers'][name] = [int(x0), int(y0)]


def save_rgba(rgb, alpha, name, x0=0, y0=0):
    out = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    out[..., :3] = np.clip(np.round(rgb), 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(np.round(alpha), 0, 255).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(os.path.join(OUT, name + '.png'))
    layout['layers'][name] = [int(x0), int(y0)]


def lit_rgb(idx, light):
    """What the screen shows: albedo x light + the lift (for the lift sprites and previews)."""
    rgb = RGB[np.maximum(idx, 0)].astype(np.float32) * light + np.array(LIFT, np.float32)
    return np.clip(rgb, 0, 255)


def crop_box(mask):
    ys, xs = np.nonzero(mask)
    return int(ys.min()), int(ys.max()) + 1, int(xs.min()), int(xs.max()) + 1


def outline_sprite(m, name, x0, y0, inner, outer_c, width=2):
    """The standard outline round a silhouette: `inner` hugging it, `outer_c` outside (1 px each;
    width 3 adds another inner ring)."""
    pad = 4
    hh, ww = m.shape
    mm = np.zeros((hh + 2 * pad, ww + 2 * pad), bool)
    mm[pad:pad + hh, pad:pad + ww] = m
    a = np.full(mm.shape, -1, np.int32)
    r1 = outer(mm)
    r2 = outer(mm | r1)
    a[r1] = IDX[inner]
    a[r2] = IDX[outer_c]
    if width >= 3:
        r0 = mm & ~(shift_mask(mm, 1, 0) & shift_mask(mm, -1, 0) & shift_mask(mm, 0, 1) & shift_mask(mm, 0, -1))
        a[r0] = IDX[inner]
    save_idx(a, name, x0 - pad, y0 - pad)


def glow_radial(name, r, color, peak, sy=1.0, power=2.0):
    """An additive light: one hue, smooth alpha falloff (no rings, no dither)."""
    w = int(2 * r + 2)
    h = int(2 * r * sy + 2)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx + 0.5 - w / 2) ** 2 + ((yy + 0.5 - h / 2) / sy) ** 2) / r
    a = np.clip(1 - d, 0, 1) ** power * peak * 255
    rgb = np.zeros((h, w, 3), np.float32) + np.array(color, np.float32)
    save_rgba(rgb, a, name)
    layout['layers'][name] = [w // 2, h // 2]


def glow_shaft(name, w, h, color, peak):
    """The Vault's light rising from the stairwell: a soft column, brightest at its foot."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx + 0.5 - w / 2) / (w / 2)
    ny = (yy + 0.5) / h                 # 0 top .. 1 foot
    a = np.exp(-(nx * nx) * 3.0) * ny ** 1.6 * peak
    a += np.clip(1 - np.sqrt((nx * 0.8) ** 2 + ((ny - 1) * 3.2) ** 2), 0, 1) ** 2 * peak * 0.6
    rgb = np.zeros((h, w, 3), np.float32) + np.array(color, np.float32)
    save_rgba(rgb, np.clip(a, 0, 1) * 255, name)
    layout['layers'][name] = [w // 2, h - 6]


def smooth_up(a, w, h):
    im = Image.fromarray(a.astype(np.float32), 'F').resize((w, h), Image.BILINEAR)
    return np.asarray(im, np.float32)


def stretched_noise(w, h, sx, cell, seed):
    sw = max(4, int(w / sx))
    n = fbm(sw, h, cell, 3, seed).astype(np.float32)
    return smooth_up(n, w, h)


def mist_textures(stage):
    """The mist: a translucent body over the edges (smooth alpha up to ~0.6, a cold grey darker than
    the lit plaza) at half resolution, and drifting banks (shared by the stages)."""
    hw, hh = W // 2, H // 2
    gx, gy = np.meshgrid(np.arange(W, dtype=np.float32), np.arange(H, dtype=np.float32))
    f = fog_field(gx, gy, stage)[::2, ::2]
    n1 = stretched_noise(hw, hh, 2.5, 20, 91)
    n2 = stretched_noise(hw, hh, 3.5, 9, 92)
    v = f + 0.30 * (n1 - 0.5) + 0.10 * (n2 - 0.5)
    t = np.clip((v - 0.12) / 0.80, 0, 1)
    a = (t * t * (3 - 2 * t)) * 0.62
    deep = np.array([66, 72, 92], np.float32)
    pale = np.array([96, 104, 122], np.float32)
    rgb = deep[None, None, :] * (1 - n1[..., None]) + pale[None, None, :] * n1[..., None]
    save_rgba(rgb, a * 255, 'mist_body_' + stage)
    if stage == 'fresh':
        s = stretched_noise(hw, hh, 3.5, 14, 93)
        t2 = stretched_noise(hw, hh, 2.5, 6, 94)
        reach = np.clip(f * 1.5 + 0.18, 0, 1)
        wv = np.clip(((0.75 * s + 0.25 * t2) - 0.42) / 0.25, 0, 1) * reach
        wa = (wv * wv * (3 - 2 * wv)) * 0.30
        rgb2 = np.zeros((hh, hw, 3), np.float32) + np.array([120, 128, 146], np.float32)
        save_rgba(rgb2, wa * 255, 'mist_wisp')


def grass_frames():
    """A swaying tuft (2 frames) for the idle animation."""
    f0 = ["..4.....", ".34..4..", ".3.4.3..", "..33.3..", "..2323..", "...22..."]
    f1 = ["...4....", "..34.4..", "..3.43..", "..33.3..", "..2323..", "...22..."]
    cmap = {'4': 'life4', '3': 'life3', '2': 'life2'}
    out = []
    for s in (f0, f1):
        cv = np.full((6, 8), -1, np.int32)
        for y, row in enumerate(s):
            for x, ch in enumerate(row):
                if ch in cmap:
                    cv[y, x] = IDX[cmap[ch]]
        out.append(cv)
    return out


def gear_icon():
    s = ["....##....", "..#.##.#..", ".########.", "..##..##..", "####..####", "####..####", "..##..##..",
         ".########.", "..#.##.#..", "....##...."]
    a = np.full((10, 10), -1, np.int32)
    for y, row in enumerate(s):
        for x, ch in enumerate(row):
            if ch == '#':
                a[y, x] = IDX['ink10']
    save_idx(a, 'gear')


def stage_lights(stage):
    return [l for l in layout['lights'] if l.get('stage') == 'fresh' or (stage == 'built' and l.get('stage') == 'built')]


def main():
    bases = {}
    lights = {}
    smokes = {}
    for stage in STAGES:
        OWN.clear()
        layout['lights'] = []
        layout['smoke'] = []
        wd = World(W, H)
        town(wd, stage)
        for pid in ('lantern', 'vault'):
            PLACES[pid](wd, stage)
        ground_detail(wd, stage, (wd.owner == 0))
        bases[stage] = wd
        for l in layout['lights']:
            lights.setdefault(l['id'], l)
        for s_ in layout['smoke']:
            smokes.setdefault((s_['x'], s_['y']), s_)
    # the optional places (plots, the Training Grounds): painted over the fresh base, cut out where
    # they differ (one albedo serves both stages: the stages agree round them)
    layout['lights'] = []
    layout['smoke'] = []
    cut = {}
    for pid in OPTIONAL:
        w2 = bases['fresh'].copy()
        n_before = len(layout['lights'])
        PLACES[pid](w2)
        own = w2.owner == OWN[pid]
        diff = (w2.idx != bases['fresh'].idx) | own
        y0, y1, x0, x1 = crop_box(diff)
        same = (bases['fresh'].idx[y0:y1, x0:x1] == bases['built'].idx[y0:y1, x0:x1]).mean()
        assert same > 0.99, (pid, same)
        cut[pid] = [w2, own, diff, layout['lights'][n_before:]]
    for l in layout['lights']:
        lights.setdefault(l['id'], l)
    for s_ in layout['smoke']:
        smokes.setdefault((s_['x'], s_['y']), s_)
    layout['lights'] = list(lights.values())
    layout['smoke'] = list(smokes.values())
    # erase into the mist (per stage); the optional places fade with the fresh town
    fogs = {}
    for stage in STAGES:
        fogs[stage] = fade_world(bases[stage], stage)
    for pid in OPTIONAL:
        fade_world(cut[pid][0], 'fresh')
    for stage in STAGES:
        wd = bases[stage]
        save_idx(wd.idx, 'town_' + stage)
        ls = [l for l in layout['lights'] if l.get('stage') == 'fresh' and 'place' not in l or
              l.get('place') in ('lantern', 'vault') or stage == 'built' and l.get('stage') == 'built']
        wl = wd
        if stage == 'built':
            # the town as built carries the Training Grounds on plot_e1 (their own signal)
            ls = ls + cut['grounds'][3]
            wl = wd.copy()
            w2, own, diff, _ = cut['grounds']
            for k in ('idx', 'kind', 'gy', 'hz', 'lip'):
                getattr(wl, k)[diff] = getattr(w2, k)[diff]
        lm = light_map(wl, ls, fogs[stage], stage)
        Image.fromarray(np.clip(np.round(lm * 255), 0, 255).astype(np.uint8), 'RGB').save(os.path.join(OUT, 'light_' + stage + '.png'))
        layout['layers']['light_' + stage] = [0, 0]
        bx, by = layout['banner']
        layout['banner_light'][stage] = [round(float(v), 3) for v in lm[by + 8, bx + 8]]
        if os.environ.get('LR3_PREVIEW'):
            Image.fromarray(lit_rgb(wl.idx, lm).astype(np.uint8), 'RGB').save('/tmp/claude-1000/-home-bender-git-fantasy-battler-echoing-depths/75b82711-cbaf-463c-b3a7-7deabec7dc7c/scratchpad/lr3/lit_%s.png' % stage)
        for pid in ('lantern', 'vault'):
            m = wd.owner == OWN[pid]
            y0, y1, x0, x1 = crop_box(m)
            rgb = lit_rgb(wd.idx[y0:y1, x0:x1], lm[y0:y1, x0:x1])
            save_rgba(rgb, m[y0:y1, x0:x1] * 255, '%s_lit_%s' % (pid, stage), x0, y0)
        for pid in OPTIONAL:
            if stage == 'fresh' and pid == 'grounds':
                continue
            w2, own, diff, _ = cut[pid]
            y0, y1, x0, x1 = crop_box(diff)
            rgb = lit_rgb(w2.idx[y0:y1, x0:x1], lm[y0:y1, x0:x1])
            save_rgba(rgb, diff[y0:y1, x0:x1] * 255, '%s_lit_%s' % (pid, stage), x0, y0)
    # albedo cut-outs and outlines
    for pid in ('lantern', 'vault'):
        m = bases['fresh'].owner == OWN[pid]
        y0, y1, x0, x1 = crop_box(m)
        save_idx(np.where(m[y0:y1, x0:x1], bases['fresh'].idx[y0:y1, x0:x1], -1), pid, x0, y0)
        outline_sprite(m[y0:y1, x0:x1], pid + '_hi', x0, y0, 'amber6', 'amber3')
        outline_sprite(m[y0:y1, x0:x1], pid + '_press', x0, y0, 'amber7', 'amber5', 3)
    for pid in OPTIONAL:
        w2, own, diff, _ = cut[pid]
        y0, y1, x0, x1 = crop_box(diff)
        save_idx(np.where(diff[y0:y1, x0:x1], w2.idx[y0:y1, x0:x1], -1), pid, x0, y0)
        sil = own[y0:y1, x0:x1]
        outline_sprite(sil, pid + '_hi', x0, y0, 'amber6', 'amber3')
        outline_sprite(sil, pid + '_press', x0, y0, 'amber7', 'amber5', 3)
    # the mist's places: districts at the street ends, outlined like any place
    fog_place('fog_west', 88, 336, 184, 136, (184, 352))
    fog_place('fog_east', 1648, 336, 184, 136, (1736, 352))
    fog_place('fog_north', 864, 40, 192, 112, (960, 72))
    fog_place('fog_south', 864, 626, 192, 88, (960, 640))
    for pid in ('fog_west', 'fog_east', 'fog_north', 'fog_south'):
        zx, zy, zw, zh = layout['places'][pid]['zone']
        yy, xx = np.mgrid[0:zh, 0:zw].astype(np.float32)
        e = ((xx + 0.5 - zw / 2) / (zw / 2)) ** 2 + ((yy + 0.5 - zh / 2) / (zh / 2)) ** 2
        n = fbm(zw, zh, 14, 2, 700 + zx % 97)
        m = e + 0.55 * (n - 0.5) < 0.86
        # a district: the blob squared off along the street grid (8 px steps)
        m = np.kron(m[4::8, 4::8], np.ones((8, 8), bool))[:zh, :zw]
        m = np.pad(m, ((0, zh - m.shape[0]), (0, zw - m.shape[1])))
        outline_sprite(m, pid + '_hi', zx, zy, 'amber6', 'amber3')
        outline_sprite(m, pid + '_press', zx, zy, 'amber7', 'amber5', 3)
    # additive light (smooth)
    glow_radial('glow_lantern', 46, (255, 196, 110), 0.55, 0.9, 2.2)
    glow_radial('glow_pool', 170, (255, 170, 80), 0.10, 0.62, 1.4)
    glow_radial('glow_lamp', 22, (255, 190, 100), 0.50, 0.9, 2.2)
    glow_radial('glow_window', 13, (255, 176, 90), 0.38, 0.9, 2.0)
    glow_shaft('glow_vault', 44, 64, (90, 230, 240), 0.26)
    glow_radial('glow_lamp_pool', 60, (255, 176, 84), 0.16, 0.62, 1.6)
    glow_radial('glow_crystal', 10, (110, 240, 240), 0.45, 1.0, 2.0)
    for i, f in enumerate(flame_frames()):
        save_idx(f, 'flame_%d' % i)
    for i, f in enumerate(banner_cloth()):
        save_idx(f, 'banner_%d' % i)
    for i, f in enumerate(grass_frames()):
        save_idx(f, 'grass_%d' % i)
    for stage in STAGES:
        mist_textures(stage)
    gear_icon()
    # grass tufts that sway (animated in Godot): on grass in the clear middle, not under things
    rng = rng_for(601)
    tufts = []
    wd = bases['fresh']
    fog = fogs['fresh']
    zones = [p['zone'] for p in layout['places'].values()]
    tries = 0
    while len(tufts) < 90 and tries < 50000:
        tries += 1
        tx, ty = int(rng.integers(300, 1620)), int(rng.integers(200, 660))
        if wd.kind[ty, tx] == K_GROUND and wd.idx[ty, tx] in (IDX['life2'], IDX['life3']) and \
                abs(tx - 960) + abs(ty - 408) > 140 and fog[ty, tx] < 0.08 and \
                (wd.kind[ty - 8:ty + 2, tx - 5:tx + 5] == K_GROUND).all() and \
                not any(z[0] - 4 <= tx <= z[0] + z[2] + 4 and z[1] - 4 <= ty <= z[1] + z[3] + 4 for z in zones):
            tufts.append([tx - 4, ty - 6])
    layout['grass'] = tufts
    assert (RGB.sum(1) > 0).all()
    with open(os.path.join(OUT, 'layout.json'), 'w') as fh:
        json.dump(layout, fh, indent=1, sort_keys=True)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
