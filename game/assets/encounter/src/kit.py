"""Shared building blocks for encounter illustrations (on top of paint.py)."""
import numpy as np
from paint import *
from paint import _tp, _ts, XF

W, H = 640, 360


def backdrop(cv, glow_xy, glow_r, bands, fade_from=250, fade_to=460):
    """Dark vault air with a banded radial glow, darkening toward the UI column on the right."""
    gx, gy = glow_xy
    l = radial(cv, gx, gy, glow_r, 0.9) ** 1.5
    # break the rings with rough stone so light bands read as painted, not compass-drawn
    l = np.clip(l + 0.16 * (fbm(cv.w, cv.h, 28, 4, int(gx + gy)) - 0.5), 0, 1)
    l *= 1 - 0.85 * smoothstep(fade_from, fade_to, cv.x)
    cv.shade(np.ones((cv.h, cv.w), bool), l, ramp(*bands), 0.0, 0.75)


def blob(cv, cx, cy, rx, ry, rmp, light, amb=0.12, mask_extra=None, outline=True, rim=None, lz=60.0, power=1.0):
    """Ellipsoid shaded by a point light (lx, ly) in banded ramp steps. Returns its mask."""
    nx = (cv.x - cx) / rx
    ny = (cv.y - cy) / ry
    d2 = nx * nx + ny * ny
    m = d2 < 1.0
    if mask_extra is not None:
        m &= mask_extra
    nz = np.sqrt(np.clip(1 - d2, 0, 1))
    lx, ly = light
    vx = lx - cv.x; vy = ly - cv.y; vz = lz
    vl = np.sqrt(vx * vx + vy * vy + vz * vz) + 1e-6
    lam = np.clip((nx * vx + ny * vy + nz * vz) / vl, 0, 1) ** power
    cv.shade(m, amb + (1 - amb) * lam, rmp, 0.0, 1.0)
    if rim is not None:
        e = edge_of(m)
        side = (nx * (lx - cx) + ny * (ly - cy)) > 0
        cv.put(e & side, rim)
    if outline:
        cv.put(outer_edge(m) & (cv.idx != -2), IDX['ink1'])
    return m


def poly_shade(cv, pts, rmp, light, base=0.4, amb=0.1, outline=True):
    """Flat-ish polygon lit by distance to a light (good for planes, cloth, stone slabs)."""
    m = poly_mask(cv, pts)
    lx, ly = light
    d = np.sqrt((cv.x - lx) ** 2 + (cv.y - ly) ** 2)
    l = np.clip(base + amb + (1 - d / 220.0) * 0.6, 0, 1)
    cv.shade(m, l, rmp, 0.0, 1.0)
    if outline:
        cv.put(outer_edge(m), IDX['ink1'])
    return m


def erode(cv, mask, amount, seed, color=None, drift=(0, -1), specks=60):
    """Fading erosion: noise-eats a mask's pixels and scatters a few specks drifting away."""
    n = value_noise(cv.w, cv.h, 6, seed)
    gone = mask & (n < amount)
    cv.idx[gone] = -3  # placeholder: caller repaints background under it
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(mask & ~gone)
    pts = []
    if len(xs):
        for i in range(specks):
            k = rng.integers(0, len(xs))
            dist = rng.integers(3, 26)
            pts.append((xs[k] + drift[0] * dist + rng.integers(-3, 4), ys[k] + drift[1] * dist))
    return gone, pts


def floor_band(cv, y0, rmp, light_x, spread=200):
    m = cv.y >= y0
    l = np.clip(1 - np.abs(cv.x - light_x) / spread, 0, 1) * np.clip(1 - (cv.y - y0) / 120, 0.2, 1)
    l *= 1 - 0.85 * smoothstep(260, 460, cv.x)
    cv.shade(m, l, rmp, 0.0, 0.9)
    return m


def stalactites(cv, seed, n, lit_color='ink3', tip=None, xmax=420):
    rng = np.random.default_rng(seed)
    for i in range(n):
        sx = int(rng.integers(-10, xmax)); ln = int(rng.integers(8, 40)); wd = int(rng.integers(3, 8))
        m = poly_mask(cv, [(sx, -1), (sx + wd, -1), (sx + wd // 2 + 1, ln)])
        cv.put(m, IDX['ink2'])
        if sx < 320:
            cv.put(m & (cv.x > sx + wd / 2), IDX[lit_color])
            if tip and rng.random() < 0.4:
                cv.put(m & (cv.y > ln - 5) & (cv.x > sx + wd / 2), IDX[tip])


def pix(cv, x, y, rows, cmap):
    for ry, row in enumerate(rows):
        for rx, ch in enumerate(row):
            if ch != '.' and ch in cmap:
                yy, xx = y + ry, x + rx
                if 0 <= yy < cv.h and 0 <= xx < cv.w:
                    cv.idx[yy, xx] = IDX[cmap[ch]]


def halo_layer(path, cx, cy, r, colors):
    gl = Canvas(W, H)
    rr = radial(gl, cx, cy, r)
    steps = len(colors)
    out = np.full((H, W), -1)
    for i, c in enumerate(colors):
        out = np.where(rr > (i + 0.5) / (steps + 0.5), IDX[c], out)
    gl.idx = out
    gl.save(path)


def capsule(cv, pts, r, rmp, light, amb=0.12, outline=True, lz=60.0):
    """Shaded tube along a polyline (limbs, tails, pipes)."""
    best = np.full((cv.h, cv.w), 1e9)
    nxs = np.zeros((cv.h, cv.w)); nys = np.zeros((cv.h, cv.w))
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        abx, aby = bx - ax, by - ay
        L2 = abx * abx + aby * aby + 1e-9
        t = np.clip(((cv.x - ax) * abx + (cv.y - ay) * aby) / L2, 0, 1)
        px = ax + t * abx; py = ay + t * aby
        dx = cv.x - px; dy = cv.y - py
        d = np.sqrt(dx * dx + dy * dy)
        sel = d < best
        best = np.where(sel, d, best)
        nxs = np.where(sel, dx / r, nxs); nys = np.where(sel, dy / r, nys)
    m = best < r
    nz = np.sqrt(np.clip(1 - nxs ** 2 - nys ** 2, 0, 1))
    lx, ly = light
    vx = lx - cv.x; vy = ly - cv.y; vz = lz
    vl = np.sqrt(vx * vx + vy * vy + vz * vz) + 1e-6
    lam = np.clip((nxs * vx + nys * vy + nz * vz) / vl, 0, 1)
    cv.shade(m, amb + (1 - amb) * lam, rmp, 0.0, 1.0)
    if outline:
        cv.put(outer_edge(m), IDX['ink1'])
    return m


# ------------------------------------------------------------------ light passes (palette-aware)
def _map(pairs):
    m = np.arange(len(NAMES), dtype=np.int32)
    for a, b in pairs:
        m[IDX[a]] = IDX[b]
    return m


def _chain(names):
    return [(names[i], names[i - 1]) for i in range(1, len(names))]


_INK = ['ink1', 'ink2', 'ink3', 'ink4', 'ink5', 'ink6', 'ink7', 'ink8', 'ink9', 'ink10']
_AMB = ['ink1', 'amber1', 'amber2', 'amber3', 'amber4', 'amber5', 'amber6', 'amber7']
_CRY = ['ink2', 'crystal1', 'crystal2', 'crystal3', 'crystal4', 'crystal5', 'ink10']
_FAD = ['ink2', 'fade1', 'fade2', 'fade3', 'fade4', 'ink10']
_LIF = ['ink1', 'life1', 'life2', 'life3', 'life4']
_BLD = ['ink1', 'blood1', 'blood2', 'blood3', 'blood4']
_SKN = ['ink2', 'skin1', 'skin2', 'skin3', 'skin4']
_VIO = ['ink2', 'violet1', 'violet2', 'violet3', 'violet4']
DARKER = _map(sum([_chain(c) for c in (_INK, _AMB, _CRY, _FAD, _LIF, _BLD, _SKN, _VIO)], []))
LIGHTER = _map(sum([[(b, a) for a, b in _chain(c)] for c in (_INK, _AMB[1:], _CRY[1:], _FAD[1:], _LIF[1:], _BLD[1:], _SKN[1:], _VIO[1:])], []))
WARM = _map([('ink3', 'amber1'), ('ink4', 'amber1'), ('ink5', 'amber2'), ('ink6', 'amber3'), ('ink7', 'amber3'),
             ('ink8', 'amber4'), ('ink9', 'amber5'), ('ink10', 'amber6'), ('fade1', 'amber2'), ('fade2', 'amber3'),
             ('fade3', 'amber4'), ('fade4', 'amber5'), ('crystal1', 'amber1'), ('crystal2', 'amber2'), ('life1', 'amber1'), ('life2', 'amber2')])
COOL = _map([('ink3', 'crystal1'), ('ink4', 'crystal1'), ('ink5', 'crystal2'), ('ink6', 'crystal2'), ('ink7', 'crystal3'),
             ('ink8', 'crystal3'), ('ink9', 'crystal4'), ('ink10', 'crystal5'), ('fade1', 'crystal1'), ('fade2', 'crystal2'), ('fade3', 'crystal3')])
GRAYM = _map([('amber1', 'ink3'), ('amber2', 'fade1'), ('amber3', 'fade1'), ('amber4', 'fade2'), ('amber5', 'fade3'),
              ('crystal1', 'ink3'), ('crystal2', 'fade1'), ('crystal3', 'fade2'), ('ink4', 'fade1'), ('ink5', 'fade1'), ('ink6', 'fade2')])


def seam_mask(cv, frac, width=0.07):
    """Stepped bands with a 1-px checker seam where a band boundary falls (no smooth dithering)."""
    chk = ((cv.x.astype(int) + cv.y.astype(int)) % 2) == 0
    return (frac > 0.5 + width) | ((np.abs(frac - 0.5) <= width) & chk)


def light_pass(cv, steps, mask=None):
    """Lighten (steps>0) or darken (steps<0) palette pixels by whole ramp steps, with checker seams."""
    if mask is None:
        mask = np.ones((cv.h, cv.w), bool)
    mask = mask & (cv.idx >= 0)
    a = np.abs(steps)
    n = np.floor(a).astype(int) + seam_mask(cv, a - np.floor(a)).astype(int)
    lut = np.where(steps > 0, 1, -1)
    for k in range(1, int(n.max()) + 1 if n.size else 1):
        sel = mask & (n >= k)
        up = sel & (lut > 0)
        dn = sel & (lut < 0)
        cv.idx[up] = LIGHTER[cv.idx[up]]
        cv.idx[dn] = DARKER[cv.idx[dn]]


def tint_pass(cv, amount, table, mask=None):
    """Recolour into a light's hue where amount>=0.5 (checker seam around 0.5)."""
    if mask is None:
        mask = np.ones((cv.h, cv.w), bool)
    sel = mask & (cv.idx >= 0) & seam_mask(cv, np.clip(amount, 0, 1))
    cv.idx[sel] = table[cv.idx[sel]]


def vignette(cv, cx, cy, rx, ry, strength=2.5, mask=None):
    d = np.sqrt(((cv.x - cx) / rx) ** 2 + ((cv.y - cy) / ry) ** 2)
    d = d + 0.18 * (fbm(cv.w, cv.h, 16, 3, 99) - 0.5)
    light_pass(cv, -np.clip((d - 0.55) * strength, 0, strength), mask)


def bricks(cv, mask, base='ink3', alt='ink4', mortar='ink2', bh=9, seed=1, bw=(14, 26)):
    """Stone courses: per-brick tone, lit top lip, dark under-edge, noise chips."""
    rng = np.random.default_rng(seed)
    rows = int(cv.h / bh) + 2
    out = np.full((cv.h, cv.w), IDX[mortar])
    for r in range(rows):
        y0 = r * bh
        x = -int(rng.integers(0, bw[1]))
        while x < cv.w:
            w = int(rng.integers(*bw))
            tone = IDX[base] if rng.random() < 0.6 else IDX[alt]
            if rng.random() < 0.12:
                tone = DARKER[IDX[base]]
            ys = slice(max(y0 + 1, 0), min(y0 + bh, cv.h))
            xs = slice(max(x + 1, 0), min(x + w, cv.w))
            out[ys, xs] = tone
            if y0 + 1 < cv.h:
                out[y0 + 1, xs] = LIGHTER[tone]
            if 0 <= y0 + bh - 1 < cv.h:
                out[y0 + bh - 1, xs] = DARKER[tone]
            x += w
    chips = value_noise(cv.w, cv.h, 3, seed + 5) < 0.18
    out = np.where(chips & (out != IDX[mortar]), DARKER[out], out)
    cv.idx[mask] = out[mask]


def rock(cv, mask, ramp_names, light, seed=3, scale=18):
    """Clustered rock: noise-faceted planes shaded by a light, 4+ tones, dark crevices."""
    rmp = ramp(*ramp_names)
    n = fbm(cv.w, cv.h, scale, 3, seed)
    facet = np.floor(n * 7) / 7.0
    gy, gx = np.gradient(facet * 30)
    lx, ly = light
    dx = lx - cv.x; dy = ly - cv.y
    dist = np.sqrt(dx * dx + dy * dy) + 1
    lam = np.clip(0.5 + (-gx * dx - gy * dy) / dist * 0.9, 0, 1)
    fall = np.clip(1 - dist / 260, 0, 1)
    v = 0.15 + 0.85 * (0.4 * lam + 0.6) * fall
    cv.shade(mask, v, rmp, 0, 1)
    crev = mask & (np.abs(np.gradient(facet)[0]) + np.abs(np.gradient(facet)[1]) > 0.05) & (value_noise(cv.w, cv.h, 4, seed + 1) < 0.6)
    cv.put(crev, rmp[0])


def glow_layer(path, cx, cy, r, colors, sy=1.0):
    """Stepped halo with checker seams for additive layers."""
    gl = Canvas(W, H)
    d = np.sqrt((gl.x - cx) ** 2 + ((gl.y - cy) / sy) ** 2) / r
    v = np.clip(1 - d, 0, 1) * len(colors)
    out = np.full((H, W), -1)
    for i, c in enumerate(colors):
        frac = np.clip(v - i, 0, 1)
        on = seam_mask(gl, frac * 0.999) if i < len(colors) else frac > 0
        out = np.where((v > i) & on, IDX[c], out)
    gl.idx = out
    gl.save(path)


def diff_layer(full, base, path):
    """Pixels of `full` that differ from `base` (used for removable/outcome layers)."""
    c = Canvas(W, H)
    c.idx = np.where(full.idx != base.idx, full.idx, -1)
    c.save(path)


def boulders(cv, region, rmp, light, seed=1, rmin=10, rmax=30, count=90, lz=80.0):
    """Packed boulders (back to front), each a shaded ellipsoid cluster with an ink1 outline."""
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(region)
    if len(xs) == 0:
        return
    items = []
    for i in range(count):
        k = rng.integers(0, len(xs))
        r = rng.uniform(rmin, rmax)
        items.append((ys[k], xs[k], r, r * rng.uniform(0.6, 0.95)))
    items.sort()
    for (y, x, rx, ry) in items:
        m = blob(cv, x, y, rx, ry, rmp, light, amb=0.05, outline=False, lz=lz, mask_extra=region)
        cv.put(outer_edge(m) & region, IDX['ink1'])
        # a few chips on the lit face
        ch = m & (value_noise(cv.w, cv.h, 3, int(x * 7 + y)) < 0.12)
        cv.idx[ch] = DARKER[cv.idx[ch]]


def strata(cv, region, seed=1, tones=('ink3', 'ink4'), hmin=12, hmax=26, slant=0.0):
    """Angular rock courses: jagged slabs with a lit top lip, flat face, dark underside, vertical cracks."""
    rng = np.random.default_rng(seed)
    out = np.full((cv.h, cv.w), IDX['ink1'])
    y = -int(rng.integers(0, hmax))
    xs = np.arange(cv.w)
    prev = np.full(cv.w, y, dtype=float)
    while y < cv.h + hmax:
        hgt = rng.integers(hmin, hmax)
        # jagged lower boundary: piecewise linear random walk
        knots = np.arange(-20, cv.w + 40, rng.integers(14, 30))
        ky = y + hgt + rng.integers(-5, 6, len(knots)) + slant * knots
        bot = np.interp(xs, knots, ky)
        tone = IDX[tones[int(rng.integers(0, len(tones)))]]
        for x in range(cv.w):
            t0, t1 = int(prev[x]), int(bot[x])
            if t1 <= t0:
                continue
            ys = slice(max(t0, 0), min(t1, cv.h))
            out[ys, x] = tone
            if 0 <= t0 + 1 < cv.h:
                out[max(t0, 0):min(t0 + 2, cv.h), x] = LIGHTER[tone]
            if 0 <= t1 - 1 < cv.h:
                out[max(t1 - 3, 0):min(t1, cv.h), x] = DARKER[tone]
            if 0 <= t1 < cv.h:
                out[t1, x] = IDX['ink1']
        # vertical cracks
        for c in range(int(rng.integers(3, 8))):
            cx = int(rng.integers(0, cv.w))
            for yy in range(int(prev[cx]) + 2, int(bot[cx]) - 1):
                if 0 <= yy < cv.h:
                    out[yy, cx] = IDX['ink1']
                    if cx + 1 < cv.w:
                        out[yy, cx + 1] = LIGHTER[out[yy, cx + 1]] if out[yy, cx + 1] != IDX['ink1'] else out[yy, cx + 1]
        prev = bot
        y += hgt
    cv.idx[region] = out[region]


def noisy(field, seed, amt=0.25, cell=14):
    h, w = field.shape
    return field + amt * (fbm(w, h, cell, 3, seed) - 0.5)


def cyl_shade(cv, mask, rmp, light_dir_x=-1.0, amb=0.05, vert=None):
    """Shade a mask as a vertical cylinder (per-row width), light coming from the left (-1) or right (+1)."""
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return
    xmin = np.full(cv.h, 1e9); xmax = np.full(cv.h, -1e9)
    np.minimum.at(xmin, ys, xs); np.maximum.at(xmax, ys, xs)
    mid = (xmin + xmax) / 2.0
    half = np.maximum((xmax - xmin) / 2.0, 1)
    nx = np.clip((cv.x - mid[:, None]) / half[:, None], -1, 1)
    nz = np.sqrt(np.clip(1 - nx * nx, 0, 1))
    lam = np.clip(nx * light_dir_x * 0.8 + nz * 0.6, 0, 1)
    v = amb + (1 - amb) * lam
    if vert is not None:
        v = v * vert
    cv.shade(mask, v, rmp, 0, 1)


# ------------------------------------------------------------------ hand-designed figures
PMAP = {}
PMAP.update({c: f'ink{i + 1}' for i, c in enumerate('0123456789')})
PMAP.update({c: f'amber{i + 1}' for i, c in enumerate('ABCDEFG')})
PMAP.update({c: f'crystal{i + 1}' for i, c in enumerate('HIJKL')})
PMAP.update({c: f'life{i + 1}' for i, c in enumerate('MNOP')})
PMAP.update({c: f'blood{i + 1}' for i, c in enumerate('QRST')})
PMAP.update({c: f'fade{i + 1}' for i, c in enumerate('UVWX')})
PMAP.update({c: f'skin{i + 1}' for i, c in enumerate('abcd')})
PMAP.update({c: f'violet{i + 1}' for i, c in enumerate('vwxy')})
PMAP['#'] = 'ink1'


class scaled:
    """with scaled(cx, cy, s): figure coordinates (polygons, discs, lines, pixel-map anchors) scale about (cx, cy)."""
    def __init__(self, cx, cy, s):
        self.v = (cx, cy, s)

    def __enter__(self):
        XF[0] = self.v

    def __exit__(self, *a):
        XF[0] = None


def pmap(cv, x, y, rows, mirror=False, mask_out=None):
    """Stamp a text pixel map (legend: 0-9 ink, A-G amber, H-L crystal, M-P life, Q-T blood,
    U-X fade, a-d skin, v-y violet, # ink1, . clear). mirror=True appends the mirrored half."""
    m = np.zeros((cv.h, cv.w), bool)
    x, y = (int(round(v)) for v in _tp((x, y)))
    for ry, row in enumerate(rows):
        full = row + row[::-1] if mirror else row
        for rx, ch in enumerate(full):
            if ch in PMAP:
                yy, xx = y + ry, x + rx
                if 0 <= yy < cv.h and 0 <= xx < cv.w:
                    cv.idx[yy, xx] = IDX[PMAP[ch]]
                    m[yy, xx] = True
    if mask_out is not None:
        mask_out |= m
    return m


def plate(cv, pts, tone, hi=None, lo=None, line=None, fig=None):
    """One designed plane: flat tone, optional lit top edge (hi), dark bottom edge (lo), border (line)."""
    m = poly_mask(cv, pts)
    cv.put(m, IDX[tone])
    if hi:
        cv.put(m & ~shift(m, 0, 1), IDX[hi])
    if lo:
        cv.put(m & ~shift(m, 0, -1), IDX[lo])
    if line:
        cv.put(edge_of(m) & ~(m & ~shift(m, 0, 1) if hi else np.zeros_like(m)), IDX[line])
    if fig is not None:
        fig |= m
    return m


def disc(cv, cx, cy, r, tone, fig=None, ry=None):
    m = ellipse_mask(cv, cx, cy, r, ry if ry else r)
    cv.put(m, IDX[tone])
    if fig is not None:
        fig |= m
    return m


def outline(cv, fig, color='ink1'):
    cv.put(outer_edge(fig), IDX[color])


def rim(cv, fig, dx, dy, color, region=None):
    """Edge pixels of the figure facing direction (dx,dy) (e.g. -1,0 = left)."""
    e = fig & ~shift(fig, -dx, -dy)
    if region is not None:
        e &= region
    cv.put(e, IDX[color])
    return e


def limb(cv, a, b, wa, wb, lit, mid, dark, fig=None, light_dir=(-1.0, -0.3)):
    """A tapered limb segment as two planes split lengthwise: the half facing the light is `lit`,
    the other `mid`, with a `dark` back edge. Returns its mask."""
    ax, ay = a; bx, by = b
    dx, dy = bx - ax, by - ay
    # widths are in figure units; poly_mask scales the points
    L = max(np.hypot(dx, dy), 1e-6)
    nx, ny = -dy / L, dx / L
    if nx * light_dir[0] + ny * light_dir[1] < 0:
        nx, ny = -nx, -ny
    pa1 = (ax + nx * wa / 2, ay + ny * wa / 2); pa2 = (ax - nx * wa / 2, ay - ny * wa / 2)
    pb1 = (bx + nx * wb / 2, by + ny * wb / 2); pb2 = (bx - nx * wb / 2, by - ny * wb / 2)
    m = poly_mask(cv, [pa1, pb1, pb2, pa2])
    cv.put(m, IDX[mid])
    lit_half = poly_mask(cv, [pa1, pb1, (bx + nx * wb * 0.05, by + ny * wb * 0.05), (ax + nx * wa * 0.05, ay + ny * wa * 0.05)])
    cv.put(lit_half & m, IDX[lit])
    back = poly_mask(cv, [(ax - nx * wa * 0.3, ay - ny * wa * 0.3), (bx - nx * wb * 0.3, by - ny * wb * 0.3), pb2, pa2])
    cv.put(back & m, IDX[dark])
    if fig is not None:
        fig |= m
    return m


def joint(cv, x, y, r, lit, mid, dark, fig=None):
    m = disc(cv, x, y, r, dark, fig)
    disc(cv, x - r * 0.15, y - r * 0.15, r * 0.75, mid)
    disc(cv, x - r * 0.35, y - r * 0.35, max(r * 0.35, 1), lit)
    return m


tp = _tp

