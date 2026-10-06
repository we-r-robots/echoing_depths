"""Lanternrest as a top-down 3/4 town (docs/BUILD.md "Lanternrest view: top-down 3/4").

Run: python3 game/assets/lanternrest/src/make_town.py
Writes into game/assets/lanternrest/:
  town.png              the whole town at night, W x H world px: ground, streets, houses, trees, props,
                        lit by the lantern and the lamp posts and greyed toward the mist (fresh state:
                        no optional places painted in)
  <place>.png           each tappable place, painted into the same world under the same light and cut
                        out where it differs from town.png (its shadow and light on the ground included)
  <place>_hi.png        the place one light step brighter with a 1 px amber outline hugging its
                        silhouette (hover / press)
  glow_*.png            additive light (palette colours, alpha in hard steps: no dithering)
  flame_0..3.png        the lantern's flame; banner_0..2.png the yard's banner; grass_0..1.png a tuft
  mist_body.png         the mist over the edges (fade greys, alpha in hard steps, feathered by bands)
  mist_wisp.png         drifting wisps (half resolution, drawn at x2)
  gear.png              the top bar's gear glyph
  layout.json           world size, every layer's position, the places (tap zone, sign anchor), the
                        lights, chimney smoke, grass tufts and the banner anchors
Light is banded in whole palette steps (no light_pass / tint_pass / glow_layer: their checker seam
reads as dithering). Shadows are indigo: the darkest world colour is ink1, never black.
Uses paint.py from assets/encounter/src (read only) for the palette and noise.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'encounter', 'src'))
from paint import IDX, NAMES, RGB, PAL, fbm, value_noise  # noqa: E402

OUT = os.path.join(HERE, '..')
W, H = 1920, 720
TILE = 16
LANTERN = (960, 408)          # the lantern's foot (world px); its flame burns 76 px above
PLAZA = (960, 408, 112, 72)   # centre and radii of the plaza
ROAD_EW = (384, 432)          # the high street (y range)
ROAD_NS = (928, 992)          # the north-south street (x range)

layout = {'world': [W, H], 'tile': TILE, 'start': [960, 376], 'layers': {}, 'places': {}, 'lights': [], 'smoke': [],
          'grass': [], 'banners': {}}

# ------------------------------------------------------------------ palette tools
N = len(NAMES)
LUM = np.array([0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in RGB.astype(float)])
CHAINS = {
    'ink': ['ink1', 'ink2', 'ink3', 'ink4', 'ink5', 'ink6', 'ink7', 'ink8', 'ink9', 'ink10'],
    'amber': ['ink1', 'ink2', 'amber1', 'amber2', 'amber3', 'amber4', 'amber5', 'amber6', 'amber7'],
    'crystal': ['ink1', 'ink2', 'crystal1', 'crystal2', 'crystal3', 'crystal4', 'crystal5', 'ink10'],
    'life': ['ink1', 'ink2', 'life1', 'life2', 'life3', 'life4'],
    'blood': ['ink1', 'ink2', 'blood1', 'blood2', 'blood3', 'blood4'],
    'fade': ['ink1', 'ink2', 'fade1', 'fade2', 'fade3', 'fade4', 'ink10'],
    'skin': ['ink1', 'ink2', 'skin1', 'skin2', 'skin3', 'skin4'],
    'violet': ['ink1', 'ink2', 'violet1', 'violet2', 'violet3', 'violet4'],
}
FAM = {}
for fam, ch in CHAINS.items():
    for n in ch:
        if n not in FAM or fam != 'ink' and n.startswith(fam):
            FAM[n] = fam
for n in CHAINS['ink']:
    FAM[n] = 'ink'
MAXS = 6
STEP = np.zeros((2 * MAXS + 1, N), np.int32)    # STEP[s + MAXS][i]: colour i moved s light steps
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


def family_map(names, families, keep=('ink1', 'ink2')):
    """nearest_map applied only to colours of the given families (others keep their hue); the
    darkest indigos stay indigo even inside a light (the shadows keep their colour)."""
    m = nearest_map(names)
    out = np.arange(N, dtype=np.int32)
    for i, n in enumerate(NAMES):
        if FAM[n] in families and n not in keep:
            out[i] = m[i]
    return out


STONY = ('ink', 'fade', 'crystal', 'violet')
# the outer ring of a lamp's light: stone and grey turn a muted warm brown
WARM_SOFT = family_map(['amber1', 'skin1', 'amber2', 'skin2', 'skin3', 'skin4'], STONY)
# the heart of the lantern's light: stone and wood turn amber
WARM = family_map(['amber1', 'amber2', 'amber3', 'amber4', 'amber5', 'amber6', 'amber7'], STONY + ('skin',))
COOL = family_map(['ink2', 'crystal1', 'crystal2', 'crystal3', 'crystal4', 'crystal5'], ('ink', 'fade', 'skin', 'amber', 'life'))
GRAY = nearest_map(['ink1', 'ink2', 'fade1', 'fade2', 'fade3', 'fade4'])
FADE_UP = np.arange(N, dtype=np.int32)   # one step lighter along the neutral greys
for _a, _b in (('ink1', 'ink2'), ('ink2', 'fade1'), ('fade1', 'fade2'), ('fade2', 'fade3'), ('fade3', 'fade4')):
    FADE_UP[IDX[_a]] = IDX[_b]
OPAQUE_TEST = None


def C(name):
    return IDX[name]


# ------------------------------------------------------------------ the world's channels
K_GROUND, K_WALL, K_ROOF_S, K_ROOF_N, K_ROOF_W, K_ROOF_E, K_VERT, K_EMIT, K_TOP = range(9)
NORMALS = {
    K_GROUND: (0.0, 0.0, 1.0), K_WALL: (0.0, 1.0, 0.25), K_ROOF_S: (0.0, 0.62, 0.78),
    K_ROOF_N: (0.0, -0.62, 0.78), K_ROOF_W: (-0.62, 0.0, 0.78), K_ROOF_E: (0.62, 0.0, 0.78),
    K_VERT: (0.0, 0.7, 0.7), K_EMIT: (0.0, 0.0, 1.0), K_TOP: (0.0, 0.0, 1.0),
}
# night baseline per surface (whole light steps): the moon is high in the north-west
AMBIENT = {K_GROUND: -1, K_WALL: -2, K_ROOF_S: -1, K_ROOF_N: 0, K_ROOF_W: 0, K_ROOF_E: -2,
           K_VERT: -1, K_EMIT: 0, K_TOP: -1}


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

    def copy(self):
        c = World.__new__(World)
        c.w, c.h, c.X, c.Y = self.w, self.h, self.X, self.Y
        for k in ('idx', 'kind', 'gy', 'hz', 'dark', 'owner'):
            setattr(c, k, getattr(self, k).copy())
        return c


class Local:
    """A window onto the world (views: writes land in the world). Coordinates are world px."""

    def __init__(self, wd, x0, y0, w, h, owner=0):
        self.wd = wd
        self.x0, self.y0 = max(0, int(x0)), max(0, int(y0))
        self.x1, self.y1 = min(wd.w, int(x0 + w)), min(wd.h, int(y0 + h))
        self.w, self.h = self.x1 - self.x0, self.y1 - self.y0
        sl = (slice(self.y0, self.y1), slice(self.x0, self.x1))
        self.idx, self.kind, self.gy = wd.idx[sl], wd.kind[sl], wd.gy[sl]
        self.hz, self.dark, self.owner = wd.hz[sl], wd.dark[sl], wd.owner[sl]
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

    def put(self, mask, color, kind=None, gy=None, hz=None, own=True):
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

    def shadow(self, mask, steps=-1):
        """Darkens what lies under mask (ground only) by whole steps."""
        m = mask & (self.kind == K_GROUND)
        self.dark[m] = np.minimum(self.dark[m], steps)


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


def rng_for(seed):
    return np.random.default_rng(seed)


# ------------------------------------------------------------------ the fields
def fog_field(X, Y):
    """0 in the remembered middle, 1 deep in the mist. The town is half-erased: the mist sits close
    to the north (visible from the plaza) and further off east and west."""
    dx = (X - 960.0)
    dy = (Y - 404.0)
    ry = np.where(dy < 0, 172.0, 280.0)
    rx = np.where(dx < 0, 690.0, 700.0)
    d = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
    n = fbm(W, H, 48, 3, 77)[: X.shape[0], : X.shape[1]] if X.shape == (H, W) else 0.5
    return np.clip((d + 0.26 * (n - 0.5) - 0.80) / 0.36, 0, 1)


# ------------------------------------------------------------------ ground
def voronoi_cells(w, h, cw, ch, seed, jitter=0.8, stagger=True):
    """Cell id and edge mask of a jittered-grid Voronoi (cobbles / flagstones)."""
    rng = rng_for(seed)
    gw, gh = w // cw + 3, h // ch + 3
    jx = (rng.random((gh, gw)) - 0.5) * jitter * cw
    jy = (rng.random((gh, gw)) - 0.5) * jitter * ch
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    gx0 = np.floor(xx / cw).astype(int)
    gy0 = np.floor(yy / ch).astype(int)
    best = np.full((h, w), 1e9, np.float32)
    second = np.full((h, w), 1e9, np.float32)
    cid = np.zeros((h, w), np.int64)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            gx = np.clip(gx0 + ox, 0, gw - 1)
            gy = np.clip(gy0 + oy, 0, gh - 1)
            off = (gy % 2) * 0.5 * cw if stagger else 0
            cx = gx * cw + cw * 0.5 + off + jx[gy, gx]
            cy = gy * ch + ch * 0.5 + jy[gy, gx]
            d = np.sqrt(((xx - cx) / cw) ** 2 + ((yy - cy) / ch) ** 2) * min(cw, ch)
            nb = d < best
            second = np.where(nb, best, np.minimum(second, d))
            cid = np.where(nb, gy * 10000 + gx, cid)
            best = np.where(nb, d, best)
    return cid, (second - best) < 1.05


def stones(L, mask, cw, ch, seed, tones, mortar, hi=True, wear=None):
    """Paint cobbles / slabs into mask: per-stone tone, a lit top-left lip, a dark lower-right edge."""
    cid, gap = voronoi_cells(L.w, L.h, cw, ch, seed)
    cid = cid[: L.h, : L.w]
    gap = gap[: L.h, : L.w]
    rng = rng_for(seed + 1)
    pick = (cid * 2654435761 % 1000) / 1000.0
    t = np.array([IDX[n] for n in tones])
    col = t[np.minimum((pick * len(t)).astype(int), len(t) - 1)]
    body = mask & ~gap
    L.put(body, col, K_GROUND)
    L.put(mask & gap, mortar, K_GROUND)
    if hi:
        up, dn, lf, rt = edges(body)
        lip = body & (~up | ~lf) & (pick > 0.15)
        L.idx[lip] = STEP[MAXS + 1, L.idx[lip]]
        low = body & (~dn | ~rt)
        L.idx[low] = STEP[MAXS - 1, L.idx[low]]
    if wear is not None:
        # moss and grit in the joints toward the edges
        m = mask & gap & wear
        L.idx[m] = IDX['life1']


def ground(wd):
    L = Local(wd, 0, 0, W, H)
    X, Y = L.X, L.Y
    rng = rng_for(5)
    # grass: one green with broad, hard-edged darker swathes (no blotches), then tufts
    cl = fbm(W, H, 56, 3, 3)
    g = np.where(cl > 0.42, IDX['life3'], IDX['life2'])
    L.put(np.ones((H, W), bool), g, K_GROUND)
    # tufts: small dark "w" marks and a lit blade over them (reads as grass, not noise)
    for _ in range(9000):
        tx, ty = int(rng.integers(2, W - 3)), int(rng.integers(2, H - 2))
        base_c = wd.idx[ty, tx]
        dark = STEP[MAXS - 1, base_c]
        wd.idx[ty, tx] = dark
        wd.idx[ty, tx + 2] = dark
        wd.idx[ty - 1, tx + 1] = dark
        if rng.random() < 0.45:
            wd.idx[ty - 1, tx] = STEP[MAXS + 1, base_c]
            wd.idx[ty - 2, tx] = STEP[MAXS + 1, base_c]
    # packed earth: narrow verges along the streets and a worn ring round the plaza
    earth = np.zeros((H, W), bool)
    n = fbm(W, H, 14, 3, 9)
    wob = 5 * (n - 0.5)
    earth |= (Y + wob > ROAD_EW[0] - 6) & (Y - wob < ROAD_EW[1] + 5)
    earth |= (X + wob > ROAD_NS[0] - 5) & (X - wob < ROAD_NS[1] + 5)
    pd = (np.abs(X - PLAZA[0]) / (PLAZA[2] + 8)) ** 4 + (np.abs(Y - PLAZA[1]) / (PLAZA[3] + 7)) ** 4
    earth |= pd + 0.3 * (n - 0.5) < 1.0
    earth &= fbm(W, H, 6, 2, 10) > 0.3
    dirt = np.where(fbm(W, H, 5, 2, 12) > 0.55, IDX['skin2'], IDX['amber2'])
    L.put(earth, dirt, K_GROUND)
    peb = earth & (value_noise(W, H, 2, 13) > 0.86)
    L.put(peb, 'ink4', K_GROUND)
    # the streets: cobbles in rows, edged by a kerb of long stones
    road = ((Y >= ROAD_EW[0]) & (Y < ROAD_EW[1]) & (X >= 96) & (X < W - 96)) | \
           ((X >= ROAD_NS[0]) & (X < ROAD_NS[1]) & (Y >= 40) & (Y < H - 24)) | \
           ((Y >= 196) & (Y < 220) & (X >= 240) & (X < 1680)) | \
           ((Y >= 708) & (X >= 120) & (X < 1800))
    # streets break up toward the world's edges (half-erased)
    f = fog_field(X, Y)
    road &= ~(fbm(W, H, 7, 2, 14) < (f - 0.1) * 1.3)
    stones(L, road, 6, 5, 21, ['ink5', 'ink5', 'ink6', 'fade1', 'ink5', 'ink4'], 'ink3', wear=fbm(W, H, 9, 2, 15) > 0.6)
    kerb = outer(road) & (L.kind == K_GROUND)
    L.put(kerb & (value_noise(W, H, 3, 16) > 0.25), 'ink3', K_GROUND)
    # the plaza: a rounded square of big flagstones in courses, a kerb of long stones round it and
    # a ring of slabs round the lantern's plinth
    pd = (np.abs(X - PLAZA[0]) / PLAZA[2]) ** 4 + (np.abs(Y - PLAZA[1]) / PLAZA[3]) ** 4
    plaza = pd < 1.0
    rim = plaza & (pd > 0.80)
    inner = plaza & ~rim
    stones(L, inner, 12, 9, 23, ['ink6', 'fade1', 'ink6', 'ink5', 'fade2'], 'ink4')
    # cracked slabs
    crk = inner & (L.idx != IDX['ink4']) & (value_noise(W, H, 3, 17) > 0.86) & (value_noise(W, H, 1, 18) > 0.5)
    L.idx[crk] = STEP[MAXS - 1, L.idx[crk]]
    stones(L, rim, 9, 5, 22, ['ink5', 'ink4', 'ink5'], 'ink2')
    # the dais ring round the plinth
    dr = np.sqrt(((X - LANTERN[0]) / 40.0) ** 2 + ((Y - LANTERN[1] + 2) / 27.0) ** 2)
    dais = (dr < 1.0) & (dr > 0.72)
    ang = np.arctan2((Y - LANTERN[1]) * 1.5, X - LANTERN[0])
    dseam = np.abs((ang + np.pi) * 18 / np.pi - np.round((ang + np.pi) * 18 / np.pi)) < 0.14
    L.put(dais & ~dseam, 'fade2', K_GROUND)
    L.put(dais & dseam, 'ink4', K_GROUND)
    L.put(dais & (dr > 0.94), 'ink4', K_GROUND)
    L.put((dr <= 0.72) & (dr > 0.66), 'ink4', K_GROUND)
    # moss creeping through the slabs toward the mist
    moss = (plaza | road) & (fbm(W, H, 8, 3, 18) + 0.6 * f > 0.85)
    L.put(moss & (value_noise(W, H, 2, 19) > 0.45), 'life1', K_GROUND)
    return road, plaza


def path(wd, pts, width, seed, kind='dirt'):
    """A worn lane (dirt, or broken flagstones) along a polyline."""
    L = Local(wd, 0, 0, W, H)
    m = L.line(pts, width)
    n = fbm(W, H, 6, 2, seed)
    m |= L.line(pts, width + 4) & (n > 0.55)
    m &= wd.kind == K_GROUND
    if kind == 'dirt':
        L.put(m, np.where(n > 0.5, IDX['skin2'], IDX['amber2']), K_GROUND)
        L.put(m & (value_noise(W, H, 2, seed + 1) > 0.85), 'ink4', K_GROUND)
    else:
        stones(L, m, 7, 6, seed, ['ink5', 'ink6', 'fade1'], 'ink3')


# ------------------------------------------------------------------ props
def drop_shadow(L, mask, dx=4, dy=3, steps=-1):
    sh = np.zeros_like(mask)
    sy, sx = slice(max(dy, 0), None), slice(max(dx, 0), None)
    src_y = slice(0, mask.shape[0] - max(dy, 0))
    src_x = slice(0, mask.shape[1] - max(dx, 0))
    sh[sy, sx] = mask[src_y, src_x]
    L.shadow(sh & ~mask, steps)


def tree(wd, cx, base_y, r=14, seed=1, own=0, kind='oak'):
    """A round-crowned tree seen from above at a slant: trunk below, a crown of leaf clusters lit
    from the upper left (moon) and, near the lantern, from the plaza."""
    rng = rng_for(seed)
    L = Local(wd, cx - r - 12, base_y - 2 * r - 30, 2 * r + 30, 2 * r + 40, own)
    # ground shadow: an oval to the lower right
    L.shadow(L.ellipse(cx + 5, base_y + 1, r * 0.95, r * 0.42), -2)
    # trunk
    trunk = L.rect(cx - 2, base_y - 12, 5, 12) | L.poly([(cx - 4, base_y), (cx + 5, base_y), (cx + 2, base_y - 4), (cx - 1, base_y - 4)])
    L.put(trunk, 'amber1', K_VERT, base_y, 6)
    L.put(trunk & (L.X <= cx - 1), 'skin1', K_VERT, base_y, 6)
    L.put(trunk & (L.X >= cx + 3), 'ink2', K_VERT, base_y, 6)
    # crown: clusters
    cy = base_y - 12 - r * 0.8
    crown = np.zeros((L.h, L.w), bool)
    blobs = [(cx, cy, r, r * 0.85)]
    for k in range(7):
        a = rng.random() * 2 * np.pi
        d = r * 0.55
        blobs.append((cx + np.cos(a) * d, cy + np.sin(a) * d * 0.8, r * (0.45 + 0.2 * rng.random()), r * (0.4 + 0.18 * rng.random())))
    shade = np.zeros((L.h, L.w), np.float32)
    for (bx, by, rx, ry) in blobs:
        m = L.ellipse(bx, by, rx, ry)
        # sphere-ish light from upper left
        nx = (L.X - bx) / rx
        ny = (L.Y - by) / ry
        v = np.clip(0.55 - 0.45 * nx - 0.55 * ny, 0, 1)
        shade = np.where(m, np.maximum(shade, v) if False else v, shade)
        crown |= m
    pal = ['ink2', 'life1', 'life2', 'life3', 'life4'] if kind == 'oak' else ['ink2', 'life1', 'crystal1', 'life2', 'life3']
    t = np.array([IDX[n] for n in pal])
    q = np.clip((shade * 4.2).astype(int), 0, 4)
    leaf = value_noise(L.w, L.h, 2, seed + 3) > 0.6
    q = np.where(leaf & (q > 0), q - 1, q)
    L.put(crown, t[q], K_TOP, base_y, 30)
    L.put(outer(crown) & (L.Y > cy), 'ink1', K_TOP, base_y, 20)
    return crown


def bush(wd, cx, cy, r=6, seed=2, own=0, berries=False):
    L = Local(wd, cx - r - 6, cy - r - 6, 2 * r + 14, 2 * r + 12, own)
    L.shadow(L.ellipse(cx + 3, cy + r * 0.5, r, r * 0.5), -1)
    m = np.zeros((L.h, L.w), bool)
    rng = rng_for(seed)
    sh = np.zeros((L.h, L.w), np.float32)
    for k in range(4):
        bx = cx + (rng.random() - 0.5) * r
        by = cy + (rng.random() - 0.5) * r * 0.6
        rr = r * (0.55 + 0.3 * rng.random())
        e = L.ellipse(bx, by, rr, rr * 0.8)
        v = np.clip(0.55 - 0.5 * (L.X - bx) / rr - 0.55 * (L.Y - by) / rr, 0, 1)
        sh = np.where(e, v, sh)
        m |= e
    t = np.array([IDX[n] for n in ['ink2', 'life1', 'life2', 'life3']])
    L.put(m, t[np.clip((sh * 3.6).astype(int), 0, 3)], K_TOP, cy + r * 0.6, 4)
    L.put(outer(m) & (L.Y > cy), 'ink1', K_TOP, cy + r * 0.6, 2)
    if berries:
        for k in range(4):
            x, y = int(cx + (rng.random() - 0.5) * r * 1.2), int(cy + (rng.random() - 0.5) * r)
            if m[y - L.y0, x - L.x0]:
                wd.idx[y, x] = IDX['blood3']


def crate(wd, x, y, own=0, w=10, h=8, top=5):
    """A wooden crate: a lit top face, a front face with planks, a shadow to the lower right."""
    L = Local(wd, x - 2, y - top - 2, w + 10, h + top + 8, own)
    body = L.rect(x, y, w, h)
    lid = L.rect(x, y - top, w, top)
    drop_shadow(L, body | lid, 3, 2, -2)
    L.put(lid, 'amber3', K_TOP, y + h, h)
    L.put(lid & (L.Y == y - top), 'skin2', K_TOP, y + h, h)
    L.put(body, 'amber2', K_WALL, y + h, 2)
    L.put(body & ((L.Y - y) % 4 == 3), 'amber1', K_WALL, y + h, 2)
    L.put(body & ((L.X == x) | (L.X == x + w - 1)), 'amber1', K_WALL, y + h, 2)


def barrel(wd, cx, base, own=0):
    L = Local(wd, cx - 8, base - 16, 18, 20, own)
    body = L.rect(cx - 4, base - 9, 9, 9) | L.rect(cx - 3, base - 10, 7, 11)
    top = L.ellipse(cx + 0.5, base - 10, 4.6, 2.2)
    drop_shadow(L, body | top, 3, 1, -2)
    L.put(body, 'amber2', K_WALL, base, 4)
    L.put(body & (L.X <= cx - 2), 'amber3', K_WALL, base, 4)
    L.put(body & (L.X >= cx + 3), 'amber1', K_WALL, base, 4)
    L.put(body & ((L.Y == base - 7) | (L.Y == base - 3)), 'ink3', K_WALL, base, 4)
    L.put(top, 'amber3', K_TOP, base, 10)
    L.put(top & (L.ellipse(cx + 0.5, base - 10, 3.0, 1.2)), 'amber1', K_TOP, base, 10)


def fence(wd, pts, own=0, broken=None, seed=3, post_every=8, color='amber2'):
    """A post-and-rail fence along a polyline (horizontal runs show both rails, vertical runs posts)."""
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
            L.put(L.rect(px, py - 9, 2, 1), 'skin2', K_TOP, py, 8)
        if horiz:
            for ry in (6, 3):
                rail = L.line([(ax, ay - ry), (bx, by - ry)], 1)
                if broken is not None:
                    gap = value_noise(L.w, L.h, 6, seed + ry) < broken * 0.9
                    rail &= ~gap
                L.put(rail & (L.idx != IDX[color]), 'amber3' if ry == 6 else 'amber2', K_VERT, ay, ry)
                L.shadow(L.line([(ax + 1, ay - ry + 4), (bx + 1, by - ry + 4)], 1) & (L.kind == K_GROUND), -1)


def lamp_post(wd, x, base, lit=True, own=0, broken=False):
    """An iron lamp post: a lantern head on an arm. Lit ones hold a warm glass (emissive)."""
    L = Local(wd, x - 8, base - 34, 20, 40, own)
    post = L.rect(x, base - 26, 2, 26)
    foot = L.rect(x - 1, base - 3, 4, 3)
    drop_shadow(L, post | foot, 3, 1, -1)
    L.put(post | foot, 'ink3', K_VERT, base, 10)
    L.put(post & (L.X == x), 'ink5', K_VERT, base, 10)
    if broken:
        L.put(L.rect(x, base - 26, 2, 9), 'ink2', K_VERT, base, 10)
        return
    arm = L.rect(x + 2, base - 26, 4, 1)
    L.put(arm, 'ink3', K_VERT, base, 26)
    cap = L.rect(x + 3, base - 26, 5, 2)
    head = L.rect(x + 3, base - 24, 5, 5)
    L.put(cap, 'ink4', K_VERT, base, 26)
    if lit:
        L.put(head, 'amber5', K_EMIT, base, 22)
        L.put(L.rect(x + 4, base - 23, 3, 3), 'amber7', K_EMIT, base, 22)
        L.put(L.rect(x + 3, base - 19, 5, 1), 'ink3', K_VERT, base, 22)
    else:
        L.put(head, 'ink2', K_VERT, base, 22)
        L.put(L.rect(x + 4, base - 23, 2, 2), 'fade1', K_VERT, base, 22)
    return (x + 5, base - 21)


def well(wd, cx, base, own=0):
    L = Local(wd, cx - 18, base - 34, 38, 42, own)
    ring = L.ellipse(cx, base - 6, 13, 7)
    inner = L.ellipse(cx, base - 7, 9, 4.5)
    front = L.rect(cx - 13, base - 6, 27, 6) & ~L.ellipse(cx, base + 3, 14, 4)
    drop_shadow(L, ring | front, 4, 2, -2)
    stones(L, front | (ring & ~inner), 5, 4, 41, ['ink5', 'ink6', 'fade1'], 'ink3')
    L.kind[(front | ring) & ~inner] = K_WALL
    L.gy[(front | ring)] = base
    L.put(inner, 'ink1', K_GROUND)
    L.put(inner & (L.Y > base - 7), 'crystal1', K_GROUND)
    # the winch frame and its little roof
    for px in (cx - 12, cx + 11):
        L.put(L.rect(px, base - 26, 2, 20), 'amber2', K_VERT, base, 14)
    roof = L.poly([(cx - 16, base - 25), (cx + 16, base - 25), (cx + 12, base - 32), (cx - 12, base - 32)])
    L.put(roof, 'blood2', K_ROOF_S, base, 30)
    L.put(roof & ((L.Y - base) % 2 == 0), 'blood1', K_ROOF_S, base, 30)
    L.put(L.rect(cx - 12, base - 33, 24, 1), 'blood3', K_ROOF_N, base, 32)
    L.put(L.rect(cx - 10, base - 18, 20, 1), 'amber1', K_VERT, base, 16)
    L.put(L.rect(cx - 1, base - 17, 3, 4), 'ink4', K_VERT, base, 14)


def bench(wd, x, base, own=0):
    L = Local(wd, x - 2, base - 10, 22, 14, own)
    seat = L.rect(x, base - 6, 16, 3)
    legs = L.rect(x + 1, base - 3, 1, 3) | L.rect(x + 14, base - 3, 1, 3)
    back = L.rect(x, base - 9, 16, 2)
    drop_shadow(L, seat | legs | back, 2, 2, -1)
    L.put(back, 'amber2', K_WALL, base, 6)
    L.put(seat, 'amber3', K_TOP, base, 4)
    L.put(legs, 'amber1', K_VERT, base, 1)


def flowers(wd, x, y, w, h, seed, colors=('blood3', 'amber5', 'violet3')):
    rng = rng_for(seed)
    for k in range(int(w * h / 18)):
        px, py = x + int(rng.integers(0, w)), y + int(rng.integers(0, h))
        if wd.kind[py, px] == K_GROUND:
            wd.idx[py, px] = IDX[colors[int(rng.integers(0, len(colors)))]]


# ------------------------------------------------------------------ buildings
def shingles(L, mask, base, dark, light, row=4, tw=5, seed=1, kind=K_ROOF_S, gy=0, hz=30, horizontal=True):
    """Roof tiles in courses: each course's lower edge dark, a lit lip on top, staggered joints."""
    rng = rng_for(seed)
    L.put(mask, base, kind, gy, hz)
    yy = (L.Y - L.y0).astype(int)
    xx = (L.X - L.x0).astype(int)
    if horizontal:
        course = yy // row
        L.put(mask & (yy % row == row - 1), dark, kind, gy, hz)
        joint = ((xx + (course % 2) * (tw // 2)) % tw == 0) & (yy % row != row - 1)
        L.put(mask & joint, dark, kind, gy, hz)
        L.put(mask & (yy % row == 0) & ~joint, light, kind, gy, hz)
    else:
        course = xx // row
        L.put(mask & (xx % row == row - 1), dark, kind, gy, hz)
        joint = ((yy + (course % 2) * (tw // 2)) % tw == 0) & (xx % row != row - 1)
        L.put(mask & joint, dark, kind, gy, hz)
    # a few tiles slipped or mossy
    chips = mask & (value_noise(L.w, L.h, 3, seed) > 0.82)
    L.idx[chips] = STEP[MAXS - 1, L.idx[chips]]


ROOFS = {
    'red': ('blood2', 'blood1', 'blood2'),
    'slate': ('violet1', 'ink2', 'ink5'),
    'teal': ('crystal1', 'ink2', 'crystal2'),
    'thatch': ('amber2', 'amber1', 'amber3'),
    'brown': ('skin1', 'amber1', 'skin2'),
}
WALLS = {
    'plaster': ('fade3', 'fade2', 'amber2'),       # fill, shade, timber
    'stone': ('ink6', 'ink5', 'ink4'),
    'timber': ('amber2', 'amber1', 'amber1'),
    'brick': ('blood1', 'amber1', 'ink3'),
}


def house(wd, x, base, w, wall_h, roof_h, roof='red', walls='plaster', ridge='ew', own=0, seed=1,
          windows=None, door=None, lit_windows=(), chimney=None, ruined=0.0, vines=0.0, sign=None):
    """A house in 3/4 view: its front wall faces south (toward the viewer), the roof above it.
    ridge 'ew': the front slope faces south and a strip of the back slope shows above the ridge.
    ridge 'ns': a gable faces the viewer, two slopes (west, east). ruined 0..1 breaks it apart.
    Returns the wall rect and the roof mask."""
    rng = rng_for(seed)
    top = base - wall_h - roof_h
    L = Local(wd, x - 8, top - 10, w + 28, wall_h + roof_h + 24, own)
    rc = ROOFS[roof]
    wc = WALLS[walls]
    wall = L.rect(x, base - wall_h, w, wall_h)
    # ground shadow: the building's bulk to the lower right
    sh = L.poly([(x + w, base - wall_h - roof_h + 6), (x + w + 10, base - wall_h - roof_h + 12), (x + w + 10, base + 4), (x + 4, base + 4), (x, base)])
    L.shadow(sh, -2)
    L.shadow(L.rect(x - 1, base, w + 2, 2), -2)
    # front wall
    if walls == 'stone' or walls == 'brick':
        stones_mask = wall
        stones(L, stones_mask, 7 if walls == 'stone' else 5, 4, seed + 7, [wc[0], wc[0], wc[1]], wc[2])
        L.kind[stones_mask] = K_WALL
        L.gy[stones_mask] = base
        L.hz[stones_mask] = (base - L.Y[stones_mask])
        if L.own:
            L.owner[stones_mask] = L.own
    else:
        L.put(wall, wc[0], K_WALL, base, base - L.Y)
        if walls == 'plaster':
            # timber frame: corner posts, a mid beam, a few braces
            frame = L.rect(x, base - wall_h, 2, wall_h) | L.rect(x + w - 2, base - wall_h, 2, wall_h)
            frame |= L.rect(x, base - wall_h, w, 2) | L.rect(x, base - wall_h // 2, w, 1)
            for k in range(1, max(2, w // 22)):
                frame |= L.rect(x + k * w // max(2, w // 22), base - wall_h, 2, wall_h)
            L.put(wall & frame, wc[2], K_WALL, base, base - L.Y)
            stains = wall & ~frame & (value_noise(L.w, L.h, 3, seed + 2) > 0.7)
            L.put(stains, wc[1], K_WALL, base, base - L.Y)
        else:
            planks = wall & ((L.X - x) % 4 == 3)
            L.put(planks, wc[1], K_WALL, base, base - L.Y)
    # plinth
    plinth = L.rect(x, base - 3, w, 3)
    stones(L, plinth, 5, 3, seed + 9, ['ink4', 'ink5'], 'ink2', hi=False)
    L.kind[plinth] = K_WALL
    L.gy[plinth] = base
    if L.own:
        L.owner[plinth] = L.own
    # door and windows
    if door is not None:
        dx = x + door
        d = L.rect(dx, base - 15, 9, 15)
        L.put(d, 'amber1', K_WALL, base, 6)
        L.put(L.rect(dx + 1, base - 14, 7, 14), 'amber2', K_WALL, base, 6)
        L.put(L.rect(dx + 1, base - 14, 7, 14) & ((L.X - dx) % 3 == 0), 'amber1', K_WALL, base, 6)
        L.put(L.rect(dx + 6, base - 8, 1, 1), 'amber5', K_WALL, base, 6)
        L.put(L.rect(dx - 1, base - 16, 11, 1), wc[2] if walls == 'plaster' else 'ink3', K_WALL, base, 16)
        step = L.rect(dx - 1, base, 11, 2)
        L.put(step, 'ink5', K_TOP, base + 2, 1)
    for i, wx in enumerate(windows or []):
        wx = x + wx
        wy = base - wall_h + 6
        lit = i in lit_windows
        frame = L.rect(wx - 1, wy - 1, 9, 9)
        glass = L.rect(wx, wy, 7, 7)
        L.put(frame, 'amber1', K_WALL, base, base - wy)
        if lit:
            L.put(glass, 'amber5', K_EMIT, base, base - wy)
            L.put(glass & ((L.X == wx + 3) | (L.Y == wy + 3)), 'amber2', K_EMIT, base, base - wy)
            L.put(L.rect(wx, wy, 3, 3), 'amber6', K_EMIT, base, base - wy)
        else:
            L.put(glass, 'ink2', K_WALL, base, base - wy)
            L.put(glass & ((L.X == wx + 3) | (L.Y == wy + 3)), 'amber1', K_WALL, base, base - wy)
            L.put(L.rect(wx + 1, wy + 1, 1, 2), 'crystal2', K_WALL, base, base - wy)
        L.put(L.rect(wx - 2, wy + 8, 11, 1), 'amber2', K_TOP, base, base - wy - 8)
    # roof
    eave = base - wall_h + 3
    if ridge == 'ew':
        ry = top + roof_h * 0.35
        front = L.poly([(x - 4, eave), (x + w + 4, eave), (x + w + 2, ry), (x - 2, ry)])
        back = L.poly([(x - 2, ry), (x + w + 2, ry), (x + w, top), (x, top)])
        shingles(L, front, rc[0], rc[1], rc[2], 4, 6, seed + 3, K_ROOF_S, base, 40)
        shingles(L, back & ~front, rc[0], rc[1], rc[2], 3, 6, seed + 4, K_ROOF_N, base, 50)
        L.put(L.rect(x - 2, int(ry), w + 4, 1), rc[2], K_ROOF_N, base, 54)
        L.put(L.rect(x - 4, eave - 1, w + 8, 2), rc[1], K_ROOF_S, base, 36)
        roofm = front | back
    else:
        cx = x + w / 2.0
        gable_top = base - wall_h - roof_h * 0.45
        gable = L.poly([(x + 3, base - wall_h + 1), (x + w - 3, base - wall_h + 1), (cx, gable_top)])
        L.put(gable, wc[0] if walls != 'stone' else 'ink5', K_WALL, base, base - L.Y)
        L.put(gable & (np.abs(L.X - cx) < 1), wc[2], K_WALL, base, base - L.Y)
        L.put(L.rect(int(cx) - 2, int(gable_top) + 7, 5, 5), 'ink2', K_WALL, base, 30)
        left = L.poly([(x - 4, eave), (cx, gable_top - 2), (cx, top), (x - 2, top + roof_h * 0.55)])
        right = L.poly([(x + w + 4, eave), (cx, gable_top - 2), (cx, top), (x + w + 2, top + roof_h * 0.55)])
        shingles(L, left, rc[0], rc[1], rc[2], 4, 5, seed + 3, K_ROOF_W, base, 44, horizontal=False)
        shingles(L, right & ~left, rc[0], rc[1], rc[2], 4, 5, seed + 4, K_ROOF_E, base, 44, horizontal=False)
        L.put(L.line([(x - 4, eave), (cx, gable_top - 2)], 2) | L.line([(x + w + 4, eave), (cx, gable_top - 2)], 2), rc[2], K_ROOF_S, base, 40)
        L.put(L.rect(int(cx) - 1, top, 2, int(gable_top - top)), rc[2], K_ROOF_N, base, 60)
        roofm = left | right
    L.put(outer(roofm) & ~wall & (L.Y < eave + 2) & (L.kind == K_GROUND), 'ink1', K_ROOF_N, base, 30)
    smoke = None
    if chimney is not None:
        cxp = x + chimney
        ch = L.rect(cxp, top - 6, 6, 14) & ~(L.Y > top + 8)
        stones(L, ch, 3, 3, seed + 11, ['blood1', 'amber1', 'ink4'], 'ink2', hi=False)
        L.kind[ch] = K_WALL
        L.gy[ch] = base
        L.hz[ch] = 60
        if L.own:
            L.owner[ch] = L.own
        L.put(L.rect(cxp - 1, top - 7, 8, 2), 'ink4', K_TOP, base, 64)
        L.put(L.rect(cxp + 1, top - 7, 4, 1), 'ink1', K_TOP, base, 64)
        smoke = (cxp + 3, top - 8)
    if sign is not None:
        sx = x + sign
        L.put(L.rect(sx, base - wall_h + 1, 1, 4), 'ink3', K_WALL, base, 18)
        board = L.rect(sx - 5, base - wall_h + 5, 11, 7)
        L.put(board, 'amber2', K_WALL, base, 16)
        L.put(L.rect(sx - 3, base - wall_h + 7, 7, 3), 'amber3', K_WALL, base, 16)
    if vines > 0:
        v = (wall | roofm) & (fbm(L.w, L.h, 4, 2, seed + 13) < 0.25 + 0.3 * vines) & (L.Y > base - wall_h - roof_h * vines)
        L.put(v, np.where(value_noise(L.w, L.h, 2, seed + 14) > 0.5, IDX['life2'], IDX['life1']), None)
    if ruined > 0:
        # holes in the roof (rafters over a dark inside), a broken wall top, rubble at the foot
        n = fbm(L.w, L.h, 9, 3, seed + 15)
        hole = roofm & (n < 0.18 + 0.45 * ruined)
        L.put(hole, 'ink2', K_GROUND, base - wall_h, 0)
        raft = hole & ((L.X - x) % 7 == 0)
        L.put(raft, 'skin1', K_ROOF_S, base, 30)
        L.put(outer(hole) & roofm, rc[1], K_ROOF_S, base, 30)
        broken_top = wall & (L.Y < base - wall_h + 6 * ruined + 3 * n) & (n < 0.4)
        L.put(broken_top, 'ink2', K_WALL, base, 10)
        boarded = wall & (value_noise(L.w, L.h, 5, seed + 16) > 0.82)
        L.put(boarded, 'amber1', K_WALL, base, 8)
        for k in range(int(10 * ruined)):
            rx_ = x + int(rng.integers(-4, w + 4))
            ry_ = base + int(rng.integers(0, 6))
            r_ = L.ellipse(rx_, ry_, 2 + rng.random() * 2, 1.5)
            L.put(r_ & (L.kind == K_GROUND), 'ink4', K_TOP, ry_, 1)
            L.put(r_ & (L.kind == K_TOP) & (L.Y < ry_), 'ink6', K_TOP, ry_, 1)
    return smoke


# ------------------------------------------------------------------ the places
OWN = {}


def own_id(pid):
    if pid not in OWN:
        OWN[pid] = len(OWN) + 1
    return OWN[pid]


def lantern(wd):
    """The Lantern: a stepped stone plinth, an iron column, a crossbar with the company's banner
    and a great lamp whose flame (animated) is the town's heart."""
    cx, base = LANTERN
    o = own_id('lantern')
    L = Local(wd, cx - 40, base - 104, 80, 116, o)
    # plinth: three stepped octagons seen from above at a slant
    for k, (rx, ry, hgt, tone) in enumerate(((22, 9, 5, 'ink5'), (16, 7, 5, 'ink6'), (10, 5, 4, 'ink6'))):
        yb = base - k * 5
        topm = L.ellipse(cx + 0.5, yb - hgt, rx, ry * 0.75)
        side = np.zeros((L.h, L.w), bool)
        for t in range(hgt + 1):
            side |= L.ellipse(cx + 0.5, yb - t, rx, ry * 0.75)
        side &= ~topm
        if k == 0:
            L.shadow(L.ellipse(cx + 8, base + 3, rx + 6, ry), -2)
        stones(L, side, 6, 5, 50 + k, [tone, 'ink5', 'fade1'], 'ink3', hi=False)
        L.kind[side] = K_WALL
        L.gy[side] = base + 2
        L.hz[side] = 4
        L.owner[side] = o
        L.put(topm, tone, K_TOP, base, 6 + k * 5)
        L.put(topm & ~L.ellipse(cx + 0.5, yb - hgt - 0.7, rx - 1, ry * 0.75 - 1), 'ink7', K_TOP, base, 6 + k * 5)
    # the column
    col = L.rect(cx - 2, base - 84, 5, 72)
    L.put(col, 'ink3', K_VERT, base, base - L.Y)
    L.put(col & (L.X == cx - 2), 'ink5', K_VERT, base, base - L.Y)
    L.put(col & (L.X == cx + 2), 'ink2', K_VERT, base, base - L.Y)
    L.put(col & ((L.Y - base) % 14 == 0), 'ink5', K_VERT, base, base - L.Y)
    # the crossbar the banner hangs from
    L.put(L.rect(cx + 2, base - 66, 21, 2), 'ink3', K_VERT, base, 66)
    L.put(L.rect(cx + 2, base - 66, 21, 1), 'ink5', K_VERT, base, 66)
    L.put(L.rect(cx + 22, base - 67, 2, 3), 'amber3', K_VERT, base, 66)
    L.put(L.line([(cx + 3, base - 58), (cx + 9, base - 64)], 1), 'ink3', K_VERT, base, 60)
    # the lamp: a cage with a glass of light (flame drawn on top, animated)
    fy = base - 92
    cage = L.poly([(cx - 11, fy + 12), (cx + 12, fy + 12), (cx + 9, fy - 12), (cx - 8, fy - 12)])
    L.put(cage, 'amber5', K_EMIT, base, 90)
    L.put(cage & L.rect(cx - 7, fy - 9, 15, 19), 'amber6', K_EMIT, base, 90)
    L.put(cage & L.rect(cx - 4, fy - 6, 9, 12), 'amber7', K_EMIT, base, 90)
    bars = cage & ((np.abs(L.X - (cx - 9 + (fy + 12 - L.Y) / 12.0)) < 0.7) | (np.abs(L.X - (cx + 10 - (fy + 12 - L.Y) / 12.0)) < 0.7) |
                   (np.abs(L.X - cx - 0.5) < 0.6) | (L.Y == fy))
    L.put(bars, 'ink3', K_VERT, base, 90)
    L.put(L.rect(cx - 12, fy + 11, 25, 3), 'ink3', K_VERT, base, 84)
    L.put(L.rect(cx - 12, fy + 11, 25, 1), 'amber3', K_VERT, base, 84)
    L.put(L.rect(cx - 5, fy + 14, 11, 2), 'ink3', K_VERT, base, 82)
    roofm = L.poly([(cx - 11, fy - 12), (cx + 12, fy - 12), (cx + 6, fy - 19), (cx - 5, fy - 19)])
    L.put(roofm, 'ink3', K_ROOF_N, base, 100)
    L.put(roofm & (L.X < cx), 'ink5', K_ROOF_N, base, 100)
    L.put(L.rect(cx - 11, fy - 13, 23, 1), 'amber3', K_ROOF_N, base, 100)
    L.put(L.rect(cx - 2, fy - 22, 5, 3), 'ink4', K_VERT, base, 104)
    L.put(L.rect(cx - 1, fy - 26, 3, 4) & ~L.rect(cx, fy - 25, 1, 2), 'amber4', K_VERT, base, 106)
    layout['flame'] = [cx - 4, fy - 8]
    layout['banner'] = [cx + 4, base - 64]
    layout['places']['lantern'] = {'zone': [cx - 24, base - 112, 48, 124], 'sign': [cx, base - 114]}
    layout['lights'].append({'id': 'lantern', 'x': cx, 'y': base, 'h': 92, 'r': 200, 'k': 0.95,
                             'color': 'warm', 'glow': 'glow_lantern', 'gx': cx + 1, 'gy': fy, 'place': 'lantern'})


def banner_cloth(px=17, h=21):
    """The lantern's hanging banner (the crest is drawn over it in Godot), 3 sway frames."""
    frames = []
    for f in range(3):
        cv = np.full((h + 4, px + 4), -1, np.int32)
        sway = [0, 1, 0][f]
        for y in range(h):
            off = int(round(sway * (y / h) ** 2 * 2)) if f != 2 else -int(round((y / h) ** 2))
            if y < 2:
                off = 0
            x0 = 1 + off
            row = np.full(px, IDX['blood2'])
            row[0] = IDX['blood1']
            row[-1] = IDX['blood1']
            row[1] = IDX['blood3']
            if y < 2:
                row[:] = IDX['amber3']
            cv[y, x0: x0 + px] = row
        # a forked tail
        for y in range(h, h + 4):
            k = y - h
            off = int(round(sway * 2)) if f == 1 else (-1 if f == 2 else 0)
            cv[y, 1 + off + k: 1 + off + px // 2 - 1 - k] = IDX['blood2']
            cv[y, 1 + off + px // 2 + 1 + k: 1 + off + px - k] = IDX['blood2']
        frames.append(cv)
    return frames


def flame_frames():
    shapes = [
        ["...7....", "..767...", "..767...", ".76667..", ".76567..", "766556..", ".65556..", "..555..."],
        ["....7...", "...76...", "..767...", ".76667..", ".76567..", ".665567.", ".65556..", "..555..."],
        ["...7....", "..77....", "..767...", ".7667...", "766567..", ".66556..", ".65556..", "..555..."],
        [".....7..", "...767..", "..7667..", ".76667..", ".76567..", ".665566.", ".65556..", "..555..."],
    ]
    cmap = {'7': 'amber7', '6': 'amber6', '5': 'amber5'}
    out = []
    for s in shapes:
        cv = np.full((8, 8), -1, np.int32)
        for y, row in enumerate(s):
            for x, ch in enumerate(row):
                if ch in cmap:
                    cv[y, x] = IDX[cmap[ch]]
        out.append(cv)
    return out


def vault(wd):
    """The Vault entrance: a carved arch at the foot of a grassy mound, stairs going down into the
    earth between low walls, cold Lumari light rising from below (a crystal keystone, cyan)."""
    cx, base = 768, 336
    o = own_id('vault')
    L = Local(wd, cx - 52, base - 92, 104, 112, o)
    # the mound the vault runs into
    mound = L.ellipse(cx, base - 46, 46, 30) | L.ellipse(cx - 20, base - 40, 30, 22) | L.ellipse(cx + 22, base - 40, 28, 22)
    mound &= L.Y < base - 22
    L.shadow(L.ellipse(cx + 10, base - 22, 50, 10), -2)
    v = np.clip(0.55 - 0.4 * (L.X - cx) / 46 - 0.6 * (L.Y - (base - 46)) / 30, 0, 1)
    t = np.array([IDX[n] for n in ['life1', 'life2', 'life3', 'life3']])
    L.put(mound, t[np.clip((v * 3.6).astype(int), 0, 3)], K_ROOF_N, base - 22, 20)
    # its foot in shadow, a ring of old kerb stones where it meets the ground
    foot = mound & ~shift_mask(mound, 0, 3)
    L.put(foot, 'ink2', K_WALL, base - 22, 2)
    L.shadow(shift_mask(mound, 3, 4) & ~mound, -1)
    rim_ = mound & ~shift_mask(mound, 0, -1)
    L.put(rim_, 'life4', K_ROOF_N, base - 22, 22)
    # stones poking out of the mound
    for (sx, sy) in ((cx - 34, base - 52), (cx + 30, base - 56), (cx - 10, base - 70), (cx + 12, base - 72)):
        r_ = L.ellipse(sx, sy, 4, 3)
        L.put(r_, 'ink5', K_ROOF_N, base - 22, 22)
        L.put(r_ & (L.Y < sy - 1), 'ink7', K_ROOF_N, base - 22, 22)
    # the arch: two piers and a round head of voussoirs, facing south
    ax0, ax1 = cx - 22, cx + 22
    atop = base - 62
    arch_outer = L.rect(ax0, atop + 12, 44, 30) | L.ellipse(cx, atop + 13, 22, 13)
    arch_inner = L.rect(cx - 13, atop + 14, 26, 30) | L.ellipse(cx, atop + 15, 13, 8)
    face = arch_outer & ~arch_inner & (L.Y < base - 20)
    stones(L, face, 6, 5, 62, ['ink6', 'ink5', 'fade2'], 'ink3')
    L.kind[face] = K_WALL
    L.gy[face] = base - 20
    L.hz[face] = 20
    L.owner[face] = o
    # voussoir joints radiating
    ang = np.arctan2(L.Y - (atop + 13), L.X - cx)
    vj = face & (L.Y < atop + 16) & (np.abs(((ang + np.pi) * 7 / np.pi) - np.round((ang + np.pi) * 7 / np.pi)) < 0.12)
    L.put(vj, 'ink3', K_WALL, base - 20, 20)
    # the crystal keystone (cold light)
    ks = L.poly([(cx - 4, atop - 1), (cx + 5, atop - 1), (cx + 3, atop + 7), (cx - 2, atop + 7)])
    L.put(ks, 'crystal4', K_EMIT, base - 20, 40)
    L.put(ks & (L.X < cx), 'crystal5', K_EMIT, base - 20, 40)
    L.put(outer(ks) & face, 'ink2', K_WALL, base - 20, 40)
    # the dark mouth, cold light rising out of the deep
    mouth = arch_inner & (L.Y < base - 20)
    L.put(mouth, 'ink1', K_EMIT, base - 20, 10)
    glowm = mouth & (L.Y > atop + 22)
    L.put(glowm, 'crystal1', K_EMIT, base - 20, 10)
    L.put(mouth & (L.Y > atop + 32), 'crystal2', K_EMIT, base - 20, 10)
    L.put(mouth & (L.Y > atop + 37) & (np.abs(L.X - cx) < 8), 'crystal3', K_EMIT, base - 20, 10)
    # the stairwell: low walls left and right, steps going down toward the arch
    well_ = L.rect(cx - 18, base - 22, 37, 24)
    for k in range(6):
        sy = base - 22 + k * 4
        tread = L.rect(cx - 14, sy, 29, 4)
        tone = ['crystal2', 'crystal1', 'ink3', 'ink4', 'ink4', 'ink5'][k]
        L.put(tread, tone, K_TOP if k > 1 else K_EMIT, base, -20 + k * 4)
        L.put(tread & (L.Y == sy), STEP[MAXS + 1, IDX[tone]] if k > 1 else IDX['crystal3'], K_TOP if k > 1 else K_EMIT, base, -20 + k * 4)
        L.put(tread & (L.Y == sy + 3), 'ink2', K_TOP, base, -20 + k * 4)
    for wx in (cx - 18, cx + 15):
        wall_ = L.rect(wx, base - 24, 4, 26)
        stones(L, wall_, 4, 4, 63 + wx, ['ink5', 'ink6'], 'ink3', hi=False)
        L.kind[wall_] = K_WALL
        L.gy[wall_] = base + 2
        L.hz[wall_] = 4
        L.owner[wall_] = o
        L.put(L.rect(wx, base - 25, 4, 1), 'ink7', K_TOP, base, 6)
    # two crystal braziers on the wall ends
    for bx in (cx - 17, cx + 16):
        L.put(L.rect(bx - 1, base - 3, 4, 4), 'ink3', K_WALL, base + 2, 4)
        L.put(L.rect(bx - 1, base - 7, 4, 4), 'crystal3', K_EMIT, base + 2, 8)
        L.put(L.rect(bx, base - 8, 2, 2), 'crystal5', K_EMIT, base + 2, 8)
    L.shadow(L.rect(cx - 19, base + 2, 40, 3), -1)
    layout['places']['vault'] = {'zone': [cx - 36, base - 82, 72, 90], 'sign': [cx, base - 84]}
    layout['lights'].append({'id': 'vault', 'x': cx, 'y': base - 10, 'h': 14, 'r': 72, 'k': 0.6,
                             'color': 'cool', 'glow': 'glow_vault', 'gx': cx, 'gy': base - 24, 'place': 'vault'})


def plot(wd, pid, x, y, w, h, seed, board_at=(4, 4)):
    """An empty plot: a fenced lot of trodden earth and weeds, old foundation stones, corner stakes
    with a string between them and a weathered board on a post."""
    o = own_id(pid)
    rng = rng_for(seed)
    L = Local(wd, x - 6, y - 16, w + 14, h + 22, o)
    lot = L.rect(x, y, w, h)
    n = fbm(L.w, L.h, 5, 2, seed)
    L.put(lot, 'skin2', K_GROUND)
    L.put(lot & (value_noise(L.w, L.h, 1, seed + 7) > 0.9), 'skin3', K_GROUND)
    for k in range(int(w * h / 90)):
        tx, ty = x + int(rng.integers(2, w - 4)), y + int(rng.integers(3, h - 2))
        c = IDX['life3'] if rng.random() < 0.5 else IDX['life2']
        wd.idx[ty, tx] = c
        wd.idx[ty, tx + 2] = c
        wd.idx[ty - 1, tx + 1] = c
    # foundation stones: a broken rectangle inside the lot
    fx0, fy0, fx1, fy1 = x + 14, y + 16, x + w - 14, y + h - 12
    ring = L.rect(fx0, fy0, fx1 - fx0, fy1 - fy0) & ~L.rect(fx0 + 4, fy0 + 4, fx1 - fx0 - 8, fy1 - fy0 - 8)
    ring &= value_noise(L.w, L.h, 6, seed + 2) > 0.3
    stones(L, ring, 5, 4, seed + 3, ['fade3', 'fade4', 'ink8'], 'ink5')
    L.kind[ring] = K_TOP
    L.hz[ring] = 2
    L.owner[ring] = o
    L.shadow(outer(ring) & (L.Y > fy0), -1)
    # stakes and string marking where walls will stand
    st = [(fx0 - 4, fy0 - 4), (fx1 + 3, fy0 - 4), (fx1 + 3, fy1 + 3), (fx0 - 4, fy1 + 3)]
    for (sx, sy) in st:
        L.put(L.rect(sx, sy - 5, 1, 5), 'amber4', K_VERT, sy, 3)
        L.put(L.rect(sx, sy - 6, 1, 1), 'blood3', K_VERT, sy, 5)
    for a, b in zip(st, st[1:] + st[:1]):
        s_ = L.line([(a[0], a[1] - 4), (b[0], b[1] - 4)], 1)
        L.put(s_ & (L.kind == K_GROUND), 'fade4', K_TOP, None, 3)
    # a few loose stones and a pile of timber
    for k in range(4):
        rx_, ry_ = x + int(rng.integers(6, w - 6)), y + int(rng.integers(6, h - 4))
        r_ = L.ellipse(rx_, ry_, 2.2, 1.6)
        L.put(r_ & (L.kind == K_GROUND), 'ink5', K_TOP, ry_, 1)
    # the fence: three sides, with gaps; open toward the street
    fence(wd, [(x, y + h), (x, y), (x + w - 2, y), (x + w - 2, y + h)], o, broken=0.25, seed=seed + 5)
    # the weathered board on a post (a faded lantern mark)
    bx, by = x + board_at[0], y + h - 2 if board_at[1] < 0 else y + board_at[1] + 14
    L.put(L.rect(bx + 5, by - 6, 2, 8), 'amber2', K_VERT, by + 2, 5)
    board = L.rect(bx, by - 15, 12, 9)
    L.put(board, 'skin2', K_TOP, by + 2, 10)
    L.put(board & ((L.Y == by - 15) | (L.Y == by - 7) | (L.X == bx) | (L.X == bx + 11)), 'amber2', K_TOP, by + 2, 10)
    L.put(L.rect(bx + 5, by - 13, 2, 5) | L.rect(bx + 4, by - 12, 4, 3), 'fade4', K_TOP, by + 2, 10)
    L.put(L.rect(bx + 5, by - 12, 2, 2), 'amber5', K_TOP, by + 2, 10)
    L.shadow(L.rect(bx + 3, by + 1, 10, 2), -1)
    layout['places'][pid] = {'zone': [x - 2, y - 10, w + 4, h + 12], 'sign': [x + w // 2, y - 8]}


def training_grounds(wd):
    """The Training Grounds: a fenced barracks yard of packed sand, a lean-to barracks with a
    weapon rack, straw dummies, an archery target and a banner; a lamp lights the yard."""
    pid = 'grounds'
    x, y, w, h = 1072, 448, 176, 96
    o = own_id(pid)
    rng = rng_for(71)
    L = Local(wd, x - 8, y - 46, w + 22, h + 56, o)
    yard = L.rect(x, y, w, h)
    n = fbm(L.w, L.h, 6, 2, 72)
    L.put(yard, 'skin3', K_GROUND)
    L.put(yard & (n > 0.66), 'skin2', K_GROUND)
    L.put(yard & (value_noise(L.w, L.h, 1, 73) > 0.9), 'skin4', K_GROUND)
    # scuffed rings where the dummies have been circled
    for (rx_, ry_) in ((x + 31, y + 57), (x + 57, y + 63), (x + 83, y + 57)):
        L.put(yard & L.ellipse(rx_, ry_, 11, 5) & ~L.ellipse(rx_, ry_, 9, 3.6), 'skin2', K_GROUND)
    # footprints / scuffs in rings around the dummies
    # the barracks lean-to along the back
    smoke = house(wd, x + 6, y + 36, 74, 20, 22, roof='thatch', walls='timber', ridge='ew', own=o, seed=74,
                  windows=[8, 52], door=30, lit_windows=(1,), chimney=60)
    if smoke:
        layout['smoke'].append({'x': smoke[0], 'y': smoke[1], 'place': pid})
    # weapon rack beside it
    rx = x + 88
    L.put(L.rect(rx, y + 6, 22, 2), 'amber2', K_VERT, y + 20, 12)
    L.put(L.rect(rx, y + 16, 22, 2), 'amber1', K_VERT, y + 20, 4)
    for k in range(5):
        L.put(L.rect(rx + 2 + k * 4, y - 2 + (k % 2) * 2, 1, 20), 'ink6' if k % 2 else 'amber3', K_VERT, y + 20, 10)
        L.put(L.rect(rx + 1 + k * 4, y - 3 + (k % 2) * 2, 3, 2), 'ink8', K_VERT, y + 20, 18)
    L.shadow(L.rect(rx + 2, y + 20, 22, 3), -1)
    # straw dummies
    for k, (dx, dy) in enumerate(((x + 30, y + 56), (x + 56, y + 62), (x + 82, y + 56))):
        post = L.rect(dx, dy - 22, 2, 22)
        body = L.ellipse(dx + 1, dy - 13, 5, 7)
        head = L.ellipse(dx + 1, dy - 23, 3.5, 3.5)
        arms = L.rect(dx - 7, dy - 17, 16, 2)
        L.shadow(L.ellipse(dx + 5, dy + 1, 8, 3), -2)
        L.put(post, 'amber2', K_VERT, dy, 10)
        L.put(arms, 'amber2', K_VERT, dy, 16)
        L.put(body, 'amber3', K_VERT, dy, 12)
        L.put(body & (L.X > dx + 2), 'amber2', K_VERT, dy, 12)
        L.put(body & ((L.Y - dy) % 4 == 0), 'amber1', K_VERT, dy, 12)
        L.put(head, 'skin2', K_VERT, dy, 22)
        L.put(head & (L.X > dx + 2), 'skin1', K_VERT, dy, 22)
        L.put(L.rect(dx - 1, dy - 24, 1, 1) | L.rect(dx + 2, dy - 24, 1, 1), 'ink2', K_VERT, dy, 22)
    # the archery target on an easel
    tx, ty = x + 142, y + 54
    L.shadow(L.ellipse(tx + 6, ty + 2, 11, 3), -2)
    L.put(L.rect(tx - 7, ty - 14, 2, 14) | L.rect(tx + 6, ty - 14, 2, 14), 'amber2', K_VERT, ty, 8)
    for k, (r_, col) in enumerate(((10, 'fade4'), (8, 'blood2'), (6, 'fade4'), (4, 'blood2'), (2, 'amber5'))):
        L.put(L.ellipse(tx + 0.5, ty - 18, r_, r_), col, K_WALL, ty, 18)
    L.put(outer(L.ellipse(tx + 0.5, ty - 18, 10, 10)), 'amber1', K_WALL, ty, 18)
    L.put(L.line([(tx + 3, ty - 20), (tx + 9, ty - 25)], 1), 'amber3', K_VERT, ty, 22)
    # the yard's banner pole (cloth animated in Godot)
    bpx, bpy = x + 160, y + 26
    L.put(L.rect(bpx, bpy - 34, 2, 34), 'ink3', K_VERT, bpy, 20)
    L.put(L.rect(bpx - 1, bpy - 36, 4, 2), 'amber4', K_VERT, bpy, 34)
    L.shadow(L.rect(bpx + 2, bpy, 6, 2), -1)
    layout['banners']['grounds'] = [bpx + 2, bpy - 33]
    # fence around the yard, a gate open toward the street
    fence(wd, [(x + 70, y), (x, y), (x, y + h), (x + w, y + h), (x + w, y), (x + 118, y)], o, broken=0.0, seed=75)
    # the yard lamp
    lamp_post(wd, x + 124, y + 20, True, o)
    layout['places'][pid] = {'zone': [x - 2, y - 12, w + 6, h + 16], 'sign': [x + 40, y - 12]}
    layout['lights'].append({'id': 'grounds_lamp', 'x': x + 126, 'y': y + 20, 'h': 24, 'r': 64, 'k': 0.5,
                             'color': 'warm', 'glow': 'glow_lamp', 'gx': x + 129, 'gy': y - 1, 'place': pid})


def fog_place(pid, x, y, w, h, sign):
    layout['places'][pid] = {'zone': [x, y, w, h], 'sign': list(sign)}


# ------------------------------------------------------------------ lighting
_JIT = []


def _jitter():
    """A fixed low-frequency wobble on the light bands (the same for the town and every cut-out)."""
    if not _JIT:
        _JIT.append(((value_noise(W, H, 9, 5) - 0.5) * 0.06).astype(np.float32))
    return _JIT[0]


def _ragged():
    if len(_JIT) < 2:
        _jitter()
        _JIT.append(value_noise(W, H, 5, 6).astype(np.float32))
    return _JIT[1]


def light_world(wd, lights, region=None, fog=None):
    """Bakes the night light into palette steps: a night baseline per surface, the moon on the
    north-west faces, lamp light by distance and facing (warm hue in bands), the Vault's cold
    light, rim light on edges that face a lamp, and the grey of the Fading toward the mist."""
    if region is None:
        region = (0, 0, wd.w, wd.h)
    x0, y0, x1, y1 = region
    sl = (slice(y0, y1), slice(x0, x1))
    idx = wd.idx[sl].copy()
    kind = wd.kind[sl]
    X, Y, gy, hz = wd.X[sl], wd.Y[sl], wd.gy[sl], wd.hz[sl]
    valid = idx >= 0
    steps = np.zeros(idx.shape, np.float32)
    for k, a in AMBIENT.items():
        steps[kind == k] = a
    nrm = np.zeros(idx.shape + (3,), np.float32)
    for k, n in NORMALS.items():
        nrm[kind == k] = n
    warm = np.zeros(idx.shape, np.float32)
    cool = np.zeros(idx.shape, np.float32)
    jit = _jitter()[sl]
    for l in lights:
        if l['x'] + l['r'] < x0 or l['x'] - l['r'] > x1 or l['y'] + l['r'] < y0 or l['y'] - l['r'] > y1:
            continue
        dx = l['x'] - X
        dy = l['y'] - gy
        dz = l['h'] - hz
        dist = np.sqrt(dx * dx + dy * dy) + 1e-3
        d3 = np.sqrt(dx * dx + dy * dy + dz * dz) + 1e-3
        lam = np.clip((nrm[..., 0] * dx + nrm[..., 1] * dy + nrm[..., 2] * dz) / d3, 0, 1)
        lam = np.where(kind == K_GROUND, 1.0, 0.35 + 0.65 * lam)
        fall = np.clip(1 - dist / l['r'], 0, 1) ** 1.6
        v = l['k'] * fall * lam + jit
        if l['color'] == 'warm':
            warm = np.maximum(warm, v) + 0.25 * np.minimum(warm, v)
        else:
            cool = np.maximum(cool, v)
    steps += np.floor(np.clip(warm, 0, 1) * 3.0 + 0.1) + np.floor(np.clip(cool, 0, 1) * 2.5)
    # rim light: edges of raised things that face a lit side
    raised = (kind != K_GROUND) & valid
    up, dn, lf, rt = edges(raised)
    exposed = raised & ~(up & dn & lf & rt)
    steps += np.where(exposed & (warm > 0.3), 1, 0)
    steps += wd.dark[sl]
    emit = kind == K_EMIT
    steps[emit] = 0
    s = np.clip(np.round(steps).astype(int), -MAXS, MAXS)
    out = idx.copy()
    out[valid] = STEP[s[valid] + MAXS, idx[valid]]
    # hue: warm light recolours in bands; the vault's light cools
    wsoft = valid & ~emit & (warm > 0.16) & (warm <= 0.55)
    wfull = valid & ~emit & (warm > 0.55)
    csel = valid & ~emit & (cool > 0.25) & (warm <= 0.3)
    out[wsoft] = WARM_SOFT[out[wsoft]]
    out[wfull] = WARM[out[wfull]]
    out[csel] = COOL[out[csel]]
    # the Fading: grey toward the mist, flatter deeper in
    if fog is not None:
        # a ragged, feathered border: small-scale wobble on the fog field
        f = fog[sl] + (_ragged()[sl] - 0.5) * 0.22
        g0 = valid & (f > 0.12) & ~emit
        out[g0] = GRAY[out[g0]]
        g = valid & (f > 0.3) & ~emit
        out[g] = FADE_UP[out[g]]
        # deep in the mist the ground loses its pattern; only joints and ruins keep their marks
        flat = valid & (f > 0.6) & (kind == K_GROUND)
        out[flat] = np.where(LUM[out[flat]] < LUM[IDX['fade1']] - 1, IDX['fade1'], IDX['fade2'])
        gl = valid & emit & (f > 0.3)
        out[gl] = GRAY[out[gl]]
    out[~valid] = -1
    return out


def clean(a, mask=None, passes=1):
    for _ in range(passes):
        up = np.roll(a, 1, 0); dn = np.roll(a, -1, 0)
        lf = np.roll(a, 1, 1); rt = np.roll(a, -1, 1)
        iso = (a != up) & (a != dn) & (a != lf) & (a != rt) & (a >= 0)
        rep = np.where((lf == rt) | (lf == up) | (lf == dn), lf, np.where((rt == up) | (rt == dn), rt, up))
        iso &= rep >= 0
        if mask is not None:
            iso &= mask
        iso[0, :] = iso[-1, :] = False
        iso[:, 0] = iso[:, -1] = False
        a[iso] = rep[iso]
    return a


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


def crop(a, mask):
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return np.where(mask[y0:y1, x0:x1], a[y0:y1, x0:x1], -1), int(x0), int(y0)


def glow_tex(name, r, colors, alphas, sy=1.0):
    """An additive light: palette colours in hard rings, alpha per ring (no seams, no dither)."""
    w = int(2 * r + 2)
    h = int(2 * r * sy + 2)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx + 0.5 - w / 2) ** 2 + ((yy + 0.5 - h / 2) / sy) ** 2) / r
    n = len(colors)
    band = np.floor((1 - np.clip(d, 0, 1)) * n).astype(int)   # 0 outside .. n-1 at the centre
    band = np.where(d >= 1, -1, np.minimum(band, n - 1))
    a = np.full((h, w), -1, np.int32)
    al = np.zeros((h, w), np.uint8)
    for i in range(n):
        m = band == i
        a[m] = IDX[colors[i]]
        al[m] = alphas[i]
    save_idx(a, name, 0, 0, al)
    layout['layers'][name] = [w // 2, h // 2]   # glows store their centre offset


def mist_textures(fog, wd_base):
    """The mist: a body over the edges in hard alpha steps (feathered by bands that follow the
    fog field with soft lobes), lighter where it is deepest, plus a half-resolution wisp layer."""
    n1 = stretched_noise(W, H, 2.5, 40, 91)
    n2 = stretched_noise(W, H, 4.0, 16, 92)
    v = fog + 0.34 * (n1 - 0.5) + 0.10 * (n2 - 0.5)
    levels = [(-0.08 + 0.11 * i, 'fade2' if i < 5 else 'fade3', 22 + 14 * i) for i in range(9)]
    a = np.full((H, W), -1, np.int32)
    al = np.zeros((H, W), np.uint8)
    for th, col, alpha in levels:
        m = v > th
        a[m] = IDX[col]
        al[m] = alpha
    save_idx(a, 'mist_body', 0, 0, al)
    # wisps (half resolution, drawn at x2): long soft banks that drift, thin ones reaching in
    # toward the plaza so the opening view already shows the town fraying at its edges
    hw, hh = W // 2, H // 2
    f2 = fog[::2, ::2]
    s = stretched_noise(hw, hh, 3.5, 14, 93)
    t = stretched_noise(hw, hh, 2.5, 6, 94)
    reach = np.clip(f2 * 1.6 + 0.22, 0, 1)
    wv = (0.75 * s + 0.25 * t) * reach
    b = np.full((hh, hw), -1, np.int32)
    bl = np.zeros((hh, hw), np.uint8)
    for th, col, alpha in ((0.36, 'fade3', 26), (0.46, 'fade3', 44), (0.56, 'fade4', 62)):
        m = wv > th
        b[m] = IDX[col]
        bl[m] = alpha
    save_idx(b, 'mist_wisp', 0, 0, bl)


def stretched_noise(w, h, sx, cell, seed):
    """fbm stretched sideways by sx (mist lies in long banks), smooth (bilinear) upsampling."""
    sw = max(4, int(w / sx))
    n = fbm(sw, h, cell, 3, seed).astype(np.float32)
    im = Image.fromarray(n, 'F').resize((w, h), Image.BILINEAR)
    return np.asarray(im, np.float32)


def grass_frames():
    """A swaying tuft (2 frames) for the idle animation."""
    f0 = ["..4.....", ".34..4..", ".3.4.3..", "..33.3..", "..2323..", "...22..."]
    f1 = ["...4....", "..34.4..", "..3.43..", "..33.3..", "..2323..", "...22..."]
    cmap = {'4': 'life3', '3': 'life2', '2': 'life1'}
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


# ------------------------------------------------------------------ the town
STREET_LAMPS = [  # (x, base y, lit)
    (856, 380, True), (1062, 380, True), (858, 446, True), (1050, 446, True),
    (700, 380, True), (1236, 380, True), (916, 300, True), (998, 520, True),
    (560, 380, False), (1390, 380, False), (916, 220, False), (998, 610, False),
    (420, 446, False), (1520, 446, False),
]


def town(wd):
    """Everything but the places: streets, the plaza, houses, ruins at the edges, trees, props."""
    road, plaza = ground(wd)
    # lanes: to the Vault, behind the cottages, to the south plot
    path(wd, [(770, 344), (790, 370), (860, 392)], 12, 101)
    path(wd, [(1060, 380), (1064, 352)], 7, 102)
    path(wd, [(1176, 380), (1176, 352)], 7, 103)
    path(wd, [(992, 600), (1060, 600)], 7, 104)
    path(wd, [(640, 380), (640, 352)], 7, 105)
    path(wd, [(1424, 380), (1424, 352)], 6, 106)
    smoke = []
    # north side of the high street (front walls face the street)
    s = house(wd, 1028, 352, 72, 26, 34, roof='red', walls='plaster', ridge='ew', seed=201,
              windows=[8, 50], door=30, lit_windows=(0,), chimney=56, sign=66)
    smoke.append(s)
    s = house(wd, 1132, 352, 84, 30, 42, roof='teal', walls='stone', ridge='ns', seed=202,
              windows=[10, 62], door=38, lit_windows=(), chimney=12, vines=0.3)
    smoke.append(s)
    house(wd, 604, 352, 72, 26, 34, roof='slate', walls='timber', ridge='ew', seed=203,
          windows=[10, 52], door=30, ruined=0.35, vines=0.5)
    # second row (north, toward the mist): taller, emptier, greyer
    house(wd, 1000, 256, 96, 34, 46, roof='red', walls='plaster', ridge='ew', seed=204,
          windows=[10, 40, 72], door=58, ruined=0.4, vines=0.4)
    house(wd, 1120, 250, 64, 28, 40, roof='slate', walls='stone', ridge='ns', seed=205,
          windows=[8], door=34, ruined=0.6)
    house(wd, 812, 244, 64, 26, 36, roof='brown', walls='timber', ridge='ns', seed=206,
          windows=[8, 46], door=26, ruined=0.5, vines=0.6)
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
          windows=[8, 60], door=36, ruined=0.8)
    house(wd, 200, 360, 72, 26, 34, roof='slate', walls='stone', ridge='ew', seed=212,
          windows=[8], door=40, ruined=0.9)
    house(wd, 360, 520, 88, 30, 40, roof='brown', walls='timber', ridge='ew', seed=213,
          windows=[8, 64], door=40, ruined=0.7)
    house(wd, 520, 528, 72, 26, 36, roof='red', walls='plaster', ridge='ns', seed=214,
          windows=[8, 54], door=30, ruined=0.6, vines=0.5)
    house(wd, 420, 244, 72, 28, 38, roof='teal', walls='stone', ridge='ns', seed=215,
          windows=[8, 52], door=30, ruined=0.9)
    house(wd, 88, 520, 80, 28, 40, roof='red', walls='timber', ridge='ew', seed=216,
          windows=[8], door=40, ruined=1.0)
    # east, into the mist
    house(wd, 1516, 352, 88, 30, 42, roof='red', walls='plaster', ridge='ew', seed=221,
          windows=[8, 66], door=40, ruined=0.7, vines=0.4)
    house(wd, 1648, 360, 72, 26, 36, roof='slate', walls='stone', ridge='ns', seed=222,
          windows=[8], door=30, ruined=0.9)
    house(wd, 1300, 528, 80, 28, 38, roof='teal', walls='timber', ridge='ew', seed=223,
          windows=[8, 60], door=36, ruined=0.5, vines=0.3)
    house(wd, 1460, 540, 88, 30, 40, roof='red', walls='stone', ridge='ns', seed=224,
          windows=[10, 66], door=40, ruined=0.8)
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
    # trees: a ring of old trees around the town, a few by the houses
    trees = [(1112, 300, 13, 'oak'), (884, 330, 10, 'oak'), (1272, 340, 15, 'oak'),
             (620, 456, 14, 'oak'), (1290, 460, 12, 'oak'), (860, 560, 15, 'oak'),
             (640, 250, 16, 'pine'), (1484, 300, 14, 'oak'), (300, 300, 16, 'pine'), (1640, 300, 15, 'pine'),
             (640, 600, 16, 'oak'), (1250, 610, 14, 'oak'), (480, 440, 12, 'oak'), (1420, 452, 13, 'pine'),
             (180, 460, 16, 'oak'), (1740, 460, 16, 'oak'), (1840, 300, 18, 'pine'), (80, 300, 18, 'pine'),
             (960, 130, 14, 'pine'), (760, 120, 16, 'oak'), (1160, 110, 15, 'pine'), (1400, 140, 16, 'oak'),
             (500, 140, 16, 'pine'), (1700, 140, 16, 'oak'), (260, 140, 18, 'oak'), (1880, 600, 18, 'oak'),
             (40, 640, 18, 'pine'), (1560, 660, 16, 'pine'), (360, 660, 16, 'oak'), (960, 690, 15, 'oak')]
    for i, (tx, ty, r, k) in enumerate(trees):
        tree(wd, tx, ty, r, 300 + i, kind=k)
    # bushes and flowers along the house fronts
    for i, (bx, by) in enumerate([(1024, 358), (1104, 358), (1128, 358), (1222, 360), (598, 358), (682, 358),
                                  (1010, 470), (830, 470), (1288, 400), (628, 400), (1000, 350)]):
        bush(wd, bx, by, 5 + i % 3, 400 + i, berries=i % 4 == 0)
    flowers(wd, 1030, 356, 30, 4, 410)
    flowers(wd, 1140, 358, 70, 4, 411, ('amber5', 'fade4'))
    # props: crates and barrels by the cottages, a well and benches on the plaza
    crate(wd, 1108, 342)
    crate(wd, 1112, 334, w=8, h=6, top=4)
    barrel(wd, 1022, 352)
    barrel(wd, 1222, 350)
    barrel(wd, 1230, 352)
    crate(wd, 690, 342)
    well(wd, 884, 492)
    bench(wd, 900, 360)
    bench(wd, 1004, 360)
    bench(wd, 1004, 470)
    crate(wd, 1290, 430)
    barrel(wd, 640, 456)
    # fences along the street edges near the plots and the far ends
    fence(wd, [(1290, 470), (1360, 470)], broken=0.3, seed=501)
    fence(wd, [(560, 470), (660, 470)], broken=0.4, seed=502)
    fence(wd, [(1180, 340), (1250, 340)], broken=0.1, seed=503)
    # street lamps
    for (lx, ly, lit) in STREET_LAMPS:
        head = lamp_post(wd, lx, ly, lit, broken=not lit and lx in (420, 1520))
        if lit:
            layout['lights'].append({'id': 'lamp_%d_%d' % (lx, ly), 'x': lx + 5, 'y': ly, 'h': 22, 'r': 64, 'k': 0.5,
                                     'color': 'warm', 'glow': 'glow_lamp', 'gx': head[0], 'gy': head[1]})
    # lit windows throw a little warm light
    layout['lights'].append({'id': 'window_c1', 'x': 1040, 'y': 356, 'h': 16, 'r': 40, 'k': 0.4,
                             'color': 'warm', 'glow': 'glow_window', 'gx': 1040, 'gy': 336})
    fog_ruins(wd)
    for s_ in smoke:
        if s_:
            layout['smoke'].append({'x': s_[0], 'y': s_[1]})
    # grass tufts that sway (animated in Godot); on grass, not under things
    rng = rng_for(601)
    tufts = []
    fog = fog_field(wd.X, wd.Y)
    while len(tufts) < 70:
        tx, ty = int(rng.integers(300, 1620)), int(rng.integers(200, 640))
        if wd.kind[ty, tx] == K_GROUND and wd.idx[ty, tx] in (IDX['life2'], IDX['life3']) and \
                abs(tx - 960) + abs(ty - 408) > 120 and fog[ty, tx] < 0.08 and \
                (wd.kind[ty - 8:ty + 2, tx - 5:tx + 5] == K_GROUND).all():
            tufts.append([tx - 4, ty - 6])
    layout['grass'] = tufts


RESERVED = [  # place zones and their surroundings: no ruins or trees here
    (650, 236, 230, 120), (900, 280, 130, 160), (470, 270, 140, 100), (680, 440, 140, 100),
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


def fog_ruins(wd):
    """The half-erased town under the mist: rows of ruined houses along broken back streets,
    placed where nothing else stands (the mist greys them; their silhouettes show through)."""
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
            if not free_box(wd, x - 6, b - wall_h - roof_h - 10, w + 24, wall_h + roof_h + 16):
                continue
            n += 1
            ridge = 'ns' if rng.random() < 0.45 else 'ew'
            wins = [8, w - 16] if w > 70 else [8]
            house(wd, x, b, w, wall_h, roof_h, roof=roofs[n % len(roofs)], walls=walls_[n % len(walls_)],
                  ridge=ridge, seed=1000 + n, windows=wins, door=w // 2 - 4,
                  ruined=float(rng.uniform(0.55, 1.0)), vines=float(rng.uniform(0, 0.6)))
    # dead and living trees between them
    for k in range(60):
        tx, ty = int(rng.integers(20, W - 20)), int(rng.integers(40, H - 4))
        f = fog_field(np.array([[tx]], np.float32), np.array([[ty]], np.float32))
        if f[0, 0] < 0.35:
            continue
        r = int(rng.integers(12, 19))
        if free_box(wd, tx - r - 4, ty - 2 * r - 14, 2 * r + 12, 2 * r + 18):
            tree(wd, tx, ty, r, 1500 + k, kind='pine' if k % 3 == 0 else 'oak')


PLACES = {
    'lantern': lantern,
    'vault': vault,
    'plot_w1': lambda wd: plot(wd, 'plot_w1', 688, 456, 120, 72, 801, (8, 2)),
    'plot_w2': lambda wd: plot(wd, 'plot_w2', 480, 288, 112, 64, 802, (8, 0)),
    'plot_e1': lambda wd: plot(wd, 'plot_e1', 1088, 456, 144, 80, 803, (10, 2)),
    'plot_e2': lambda wd: plot(wd, 'plot_e2', 1336, 288, 112, 64, 804, (8, 0)),
    'plot_s1': lambda wd: plot(wd, 'plot_s1', 1008, 560, 112, 64, 805, (8, 0)),
    'grounds': training_grounds,
}


def main():
    wd = World(W, H)
    town(wd)
    fog = fog_field(wd.X, wd.Y)
    base_lights = [l for l in layout['lights'] if 'place' not in l]
    # the lantern and the Vault always stand: their light falls on the town in every state
    always = ['lantern', 'vault']
    for pid in always:
        PLACES[pid](wd)
    lit_lights = [l for l in layout['lights'] if l.get('place') in (None, 'lantern', 'vault')]
    # the always-standing places are part of town.png; their own pixels are also cut out (the
    # lift over the panel shade) with a highlight sprite
    base_lit = clean(light_world(wd, lit_lights, fog=fog), passes=1)
    save_idx(base_lit, 'town')
    for pid in always:
        o = OWN[pid]
        m = wd.owner == o
        hi = np.where(m, STEP[MAXS + 1, np.maximum(base_lit, 0)], -1)
        hi[outer(m)] = IDX['amber6']
        ring = outer(m | outer(m))
        hi[ring] = IDX['amber3']
        a, x0, y0 = crop(hi, hi >= 0)
        save_idx(a, pid + '_hi', x0, y0)
        # the place's own pixels: for the lift (drawn over the panel shade)
        a, x0, y0 = crop(base_lit, m)
        save_idx(a, pid, x0, y0)
    # optional places (plots, the Training Grounds): painted on the base, cut out by difference
    for pid in ['plot_w1', 'plot_w2', 'plot_e1', 'plot_e2', 'plot_s1', 'grounds']:
        w2 = wd.copy()
        n_before = len(layout['lights'])
        PLACES[pid](w2)
        new_lights = layout['lights'][n_before:]
        o = OWN[pid]
        own = w2.owner == o
        ys, xs = np.nonzero(own)
        pad = max([int(l['r']) for l in new_lights] + [20])
        reg = (max(0, xs.min() - pad), max(0, ys.min() - pad), min(W, xs.max() + pad), min(H, ys.max() + pad))
        lit = clean(light_world(w2, lit_lights + new_lights, reg, fog), passes=1)
        sub = base_lit[reg[1]:reg[3], reg[0]:reg[2]]
        diff = (lit != sub) | own[reg[1]:reg[3], reg[0]:reg[2]]
        diff[:3, :] = False
        diff[-3:, :] = False
        diff[:, :3] = False
        diff[:, -3:] = False
        a, x0, y0 = crop(lit, diff)
        save_idx(a, pid, x0 + reg[0], y0 + reg[1])
        m = own[reg[1]:reg[3], reg[0]:reg[2]]
        hi = np.where(m, STEP[MAXS + 1, np.maximum(lit, 0)], -1)
        hi[outer(m)] = IDX['amber6']
        hi[outer(m | outer(m))] = IDX['amber3']
        a, x0, y0 = crop(hi, hi >= 0)
        save_idx(a, pid + '_hi', x0 + reg[0], y0 + reg[1])
    # the mist's places: where streets vanish into it
    fog_place('fog_west', 96, 344, 176, 128, (184, 340))
    fog_place('fog_east', 1648, 344, 176, 128, (1736, 340))
    fog_place('fog_north', 864, 40, 192, 112, (960, 60))
    fog_place('fog_south', 864, 628, 192, 88, (960, 630))
    for pid in ('fog_west', 'fog_east', 'fog_north', 'fog_south'):
        zx, zy, zw, zh = layout['places'][pid]['zone']
        yy, xx = np.mgrid[0:zh, 0:zw].astype(np.float32)
        e = ((xx + 0.5 - zw / 2) / (zw / 2)) ** 2 + ((yy + 0.5 - zh / 2) / (zh / 2)) ** 2
        n = fbm(zw, zh, 12, 2, 700 + zx % 97)
        m = e + 0.5 * (n - 0.5) < 0.9
        a = np.where(m, IDX['fade4'], -1)
        al = np.where(m, 60, 0).astype(np.uint8)
        edge = outer(m)
        a[edge] = IDX['amber6']
        al[edge] = 255
        save_idx(a, pid + '_hi', zx, zy, al)
    # additive lights
    glow_tex('glow_lantern', 150, ['amber1', 'amber2', 'amber3', 'amber4', 'amber5', 'amber6'], [26, 30, 34, 40, 52, 70], 0.8)
    glow_tex('glow_lamp', 46, ['amber1', 'amber2', 'amber3', 'amber4', 'amber5'], [26, 30, 36, 46, 70], 0.8)
    glow_tex('glow_window', 22, ['amber2', 'amber3', 'amber4'], [24, 34, 50], 0.8)
    glow_tex('glow_vault', 52, ['crystal1', 'crystal2', 'crystal3', 'crystal4'], [20, 26, 34, 48], 0.85)
    for i, f in enumerate(flame_frames()):
        save_idx(f, 'flame_%d' % i)
    for i, f in enumerate(banner_cloth()):
        save_idx(f, 'banner_%d' % i)
    for i, f in enumerate(grass_frames()):
        save_idx(f, 'grass_%d' % i)
    mist_textures(fog, base_lit)
    gear_icon()
    # no pure black anywhere in the world art
    assert (RGB.sum(1) > 0).all()
    with open(os.path.join(OUT, 'layout.json'), 'w') as fh:
        json.dump(layout, fh, indent=1, sort_keys=True)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
