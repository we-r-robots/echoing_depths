"""Tiny palette-locked painter used to author Echoing Depths encounter illustrations.

Everything is computed as float fields with numpy, then quantised onto ramps of the
master palette with hard bands (no dithering), then cleaned of stray pixels.
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
PAL_PATH = os.path.join(ROOT, 'assets', 'palette', 'master.gpl')


def load_palette():
    pal = {}
    with open(PAL_PATH) as f:
        for line in f:
            p = line.split()
            if len(p) >= 4 and p[0].isdigit():
                pal[p[3]] = (int(p[0]), int(p[1]), int(p[2]))
    return pal


PAL = load_palette()
NAMES = list(PAL.keys())
RGB = np.array([PAL[n] for n in NAMES], dtype=np.uint8)
IDX = {n: i for i, n in enumerate(NAMES)}


def ramp(*names):
    return np.array([IDX[n] for n in names], dtype=np.int32)


STONE = ramp('ink1', 'ink2', 'ink3', 'ink4', 'ink5', 'ink6', 'ink7', 'ink8', 'ink9')
CRYS = ramp('ink2', 'crystal1', 'crystal2', 'crystal3', 'crystal4', 'crystal5', 'ink10')
AMB = ramp('amber1', 'amber2', 'amber3', 'amber4', 'amber5', 'amber6', 'amber7')
FADE = ramp('ink2', 'fade1', 'fade2', 'fade3', 'fade4', 'ink10')
VIO = ramp('ink2', 'violet1', 'violet2', 'violet3', 'violet4')
LIFE = ramp('ink1', 'life1', 'life2', 'life3', 'life4')
BLOOD = ramp('ink1', 'blood1', 'blood2', 'blood3', 'blood4')
SKIN = ramp('ink2', 'skin1', 'skin2', 'skin3', 'skin4')


class Canvas:
    """Holds a palette-index image (-1 = transparent)."""

    def __init__(self, w, h, fill=-1):
        self.w, self.h = w, h
        self.idx = np.full((h, w), fill, dtype=np.int32)
        yy, xx = np.mgrid[0:h, 0:w]
        self.x = xx.astype(np.float64)
        self.y = yy.astype(np.float64)

    def put(self, mask, values):
        """values: palette index (int) or int array same shape."""
        if np.isscalar(values):
            self.idx[mask] = values
        else:
            self.idx[mask] = values[mask]

    def shade(self, mask, light, rmp, lo=0.0, hi=1.0):
        """Quantise light (0..1 field) onto ramp within mask."""
        t = np.clip((light - lo) / max(hi - lo, 1e-6), 0, 0.9999)
        vals = rmp[(t * len(rmp)).astype(np.int32)]
        self.idx[mask] = vals[mask]

    def to_image(self):
        out = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        m = self.idx >= 0
        out[m, :3] = RGB[self.idx[m]]
        out[m, 3] = 255
        return Image.fromarray(out, 'RGBA')

    def save(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.to_image().save(path)

    def clean(self, mask=None, passes=1):
        """Remove isolated single pixels (replace by most common 4-neighbour)."""
        for _ in range(passes):
            a = self.idx
            up = np.roll(a, 1, 0); dn = np.roll(a, -1, 0)
            lf = np.roll(a, 1, 1); rt = np.roll(a, -1, 1)
            iso = (a != up) & (a != dn) & (a != lf) & (a != rt)
            # choose neighbour that matches at least one other neighbour, else up
            rep = np.where((lf == rt) | (lf == up) | (lf == dn), lf, np.where((rt == up) | (rt == dn), rt, up))
            if mask is not None:
                iso &= mask
            iso[0, :] = iso[-1, :] = False
            iso[:, 0] = iso[:, -1] = False
            a[iso] = rep[iso]


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def gauss(x, y, cx, cy, sx, sy):
    return np.exp(-(((x - cx) / sx) ** 2 + ((y - cy) / sy) ** 2))


_rng = np.random.default_rng(7)


def value_noise(w, h, cell, seed=0):
    rng = np.random.default_rng(seed)
    gw, gh = w // cell + 3, h // cell + 3
    grid = rng.random((gh, gw))
    yy, xx = np.mgrid[0:h, 0:w] / cell
    x0 = xx.astype(int); y0 = yy.astype(int)
    fx = xx - x0; fy = yy - y0
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    a = grid[y0, x0]; b = grid[y0, x0 + 1]; c = grid[y0 + 1, x0]; d = grid[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(w, h, cell=32, octaves=4, seed=0):
    tot = np.zeros((h, w)); amp = 1.0; s = 0.0
    for o in range(octaves):
        tot += amp * value_noise(w, h, max(2, cell >> o), seed + o * 17)
        s += amp; amp *= 0.5
    return tot / s


XF = [None]   # optional (cx, cy, scale) applied to figure coordinates (set via kit.scaled)


def _tp(p):
    if XF[0] is None:
        return p
    cx, cy, s = XF[0]
    return (cx + (p[0] - cx) * s, cy + (p[1] - cy) * s)


def _ts(r):
    return r if XF[0] is None else r * XF[0][2]


def poly_mask(cv, pts):
    """Even-odd polygon fill mask (pts list of (x,y))."""
    from PIL import ImageDraw
    im = Image.new('L', (cv.w, cv.h), 0)
    ImageDraw.Draw(im).polygon([tuple(map(float, _tp(p))) for p in pts], fill=1)
    return np.array(im, dtype=bool)


def line_mask(cv, pts, width=1):
    from PIL import ImageDraw
    im = Image.new('L', (cv.w, cv.h), 0)
    ImageDraw.Draw(im).line([tuple(map(float, _tp(p))) for p in pts], fill=1, width=max(1, int(round(_ts(width)))) if width > 1 else 1)
    return np.array(im, dtype=bool)


def ellipse_mask(cv, cx, cy, rx, ry):
    cx, cy = _tp((cx, cy)); rx, ry = _ts(rx), _ts(ry)
    return ((cv.x - cx) / rx) ** 2 + ((cv.y - cy) / ry) ** 2 <= 1.0


def edge_of(mask):
    """Pixels in mask with at least one 4-neighbour outside."""
    up = np.roll(mask, 1, 0); dn = np.roll(mask, -1, 0)
    lf = np.roll(mask, 1, 1); rt = np.roll(mask, -1, 1)
    return mask & ~(up & dn & lf & rt)


def outer_edge(mask):
    up = np.roll(mask, 1, 0); dn = np.roll(mask, -1, 0)
    lf = np.roll(mask, 1, 1); rt = np.roll(mask, -1, 1)
    return ~mask & (up | dn | lf | rt)


def shift(mask, dx, dy):
    return np.roll(np.roll(mask, dy, 0), dx, 1)


def normals_from_height(h, scale=1.0):
    gy, gx = np.gradient(h * scale)
    nz = np.ones_like(h)
    n = np.stack([-gx, -gy, nz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n


def lambert(n, d):
    d = np.array(d, dtype=np.float64); d /= np.linalg.norm(d)
    return np.clip((n * d).sum(-1), 0, 1)


def point_light(cv, n, h, lx, ly, lz, radius):
    """Lambert from a point light with smooth falloff. h in px units of height."""
    dx = lx - cv.x; dy = ly - cv.y; dz = lz - h
    dist = np.sqrt(dx * dx + dy * dy + dz * dz) + 1e-6
    ndl = np.clip((n[..., 0] * dx + n[..., 1] * dy + n[..., 2] * dz) / dist, 0, 1)
    fall = np.clip(1 - dist / radius, 0, 1) ** 2
    return ndl * fall


def radial(cv, cx, cy, r, sy=1.0):
    d = np.sqrt((cv.x - cx) ** 2 + ((cv.y - cy) / sy) ** 2)
    return np.clip(1 - d / r, 0, 1)


def save_frames(frames, path):
    for i, f in enumerate(frames):
        f.save(path.format(i))
