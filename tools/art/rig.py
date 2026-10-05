"""Procedural helpers used by the character modules: shaded limbs, blades,
smears and sparkles. All output is palette names written into a Canvas, so the
same outline/separation passes apply to everything."""
from __future__ import annotations

import math
from pixlib import Canvas, Part, sep_color


def _seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    L2 = vx * vx + vy * vy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / L2))
    cx, cy = ax + t * vx, ay + t * vy
    # signed side: >0 is to the right of a->b direction (screen coords)
    side = (px - ax) * vy - (py - ay) * vx
    return math.hypot(px - cx, py - cy), t, side


def limb(canvas: Canvas, pts, radius, ramp, light=(0.6, -0.8), sep=True, tag=None,
         start_cap=True):
    """Draw a jointed limb through `pts` (list of (x, y)) as shaded capsules.
    ramp = (dark, mid, light[, highlight]) palette names. Shading follows the
    light direction projected on each pixel's offset from the bone."""
    lx, ly = light
    mine = {}
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    r = radius
    for y in range(int(min(ys) - r - 1), int(max(ys) + r + 2)):
        for x in range(int(min(xs) - r - 1), int(max(xs) + r + 2)):
            best = None
            for (a, b) in zip(pts, pts[1:]):
                d, t, _ = _seg_dist(x, y, a[0], a[1], b[0], b[1])
                if best is None or d < best[0]:
                    best = (d, a, b, t)
            d, a, b, t = best
            if d > r + 0.01:
                continue
            cx = a[0] + t * (b[0] - a[0])
            cy = a[1] + t * (b[1] - a[1])
            ox, oy = x - cx, y - cy
            n = math.hypot(ox, oy)
            dot = 0 if n < 0.3 else (ox * lx + oy * ly) / n
            if dot > 0.55 and len(ramp) > 3 and d > r - 1.01:
                c = ramp[3]
            elif dot > 0.2:
                c = ramp[2]
            elif dot < -0.35:
                c = ramp[0]
            else:
                c = ramp[1]
            mine[(x, y)] = c
    part = Part(None, (0, 0), px=mine, size=(0, 0))
    canvas.stamp(part, sep=sep, tag=tag)
    return mine


def blob(canvas, cx, cy, rx, ry, ramp, light=(0.6, -0.8), sep=True):
    """Shaded ellipsoid (fists, bodies, orbs): Lambert on a sphere normal so the
    terminator curves, with a light coming from `light` and toward the viewer."""
    lx, ly = light
    L = (lx * 0.8, ly * 0.8, 0.55)
    n = math.sqrt(sum(v * v for v in L))
    L = tuple(v / n for v in L)
    mine = {}
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            ox, oy = (x - cx) / max(rx, 0.5), (y - cy) / max(ry, 0.5)
            d = ox * ox + oy * oy
            if d > 1.0:
                continue
            oz = math.sqrt(max(0.0, 1 - d))
            lam = ox * L[0] + oy * L[1] + oz * L[2]
            if lam > 0.82 and len(ramp) > 3:
                c = ramp[3]
            elif lam > 0.5:
                c = ramp[2]
            elif lam < 0.12:
                c = ramp[0]
            else:
                c = ramp[1]
            mine[(x, y)] = c
    canvas.stamp(Part(None, (0, 0), px=mine, size=(0, 0)), sep=sep)
    return mine


def blade(canvas, gx, gy, angle, length, width=3, edge=("ink6", "ink8", "ink9", "ink10"),
          tip_taper=3, start=0.0, sep=True):
    """Straight blade from grip point (gx, gy) at `angle` degrees (0 = right,
    90 = down, screen coords). The upper/lit edge gets the bright tones."""
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx  # normal
    mine = {}
    hw = width / 2.0
    ext = length + width + 2
    for y in range(int(gy - ext), int(gy + ext + 1)):
        for x in range(int(gx - ext), int(gx + ext + 1)):
            ox, oy = x - gx, y - gy
            t = ox * dx + oy * dy
            s = ox * nx + oy * ny
            if t < start or t > length:
                continue
            w = hw
            if t > length - tip_taper:
                w = hw * max(0.0, (length - t) / tip_taper) + 0.35
            if abs(s) > w:
                continue
            # light comes from upper right: the edge whose normal faces it is bright
            lit = (nx * 0.6 + ny * -0.8)
            side = s * (1 if lit >= 0 else -1)
            band = (side + hw) / (2 * hw)
            k = max(0, min(len(edge) - 1, int(band * len(edge))))
            if t > length - tip_taper:
                k = max(k, len(edge) - 2)
            c = edge[k]
            mine[(x, y)] = c
    canvas.stamp(Part(None, (0, 0), px=mine, size=(0, 0)), sep=sep)
    return mine


def bar(canvas, x0, y0, angle, length, c, width=1, sep=False):
    """Thin straight stroke (hilts, staff shafts) using pixel-centre sampling."""
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    mine = {}
    hw = width / 2.0
    for y in range(int(y0 - length - 2), int(y0 + length + 3)):
        for x in range(int(x0 - length - 2), int(x0 + length + 3)):
            ox, oy = x - x0, y - y0
            t = ox * dx + oy * dy
            s = ox * nx + oy * ny
            if -0.5 <= t <= length + 0.5 and abs(s) <= hw:
                mine[(x, y)] = c if isinstance(c, str) else c(t, s)
    canvas.stamp(Part(None, (0, 0), px=mine, size=(0, 0)), sep=sep)
    return mine


def arc(canvas, cx, cy, r0, r1, a0, a1, ramp, sep=False, taper=True):
    """Crescent smear between radii r0..r1 over angles a0->a1 (degrees, screen).
    Brightest at the leading edge (a1), thinning toward the trailing end."""
    mine = {}
    lo, hi = min(a0, a1), max(a0, a1)
    for y in range(int(cy - r1 - 1), int(cy + r1 + 2)):
        for x in range(int(cx - r1 - 1), int(cx + r1 + 2)):
            d = math.hypot(x - cx, y - cy)
            ang = math.degrees(math.atan2(y - cy, x - cx))
            # bring into range
            while ang < lo:
                ang += 360
            while ang > lo + 360:
                ang -= 360
            if ang > hi:
                continue
            f = (ang - a0) / (a1 - a0) if a1 != a0 else 1  # 0 trailing .. 1 leading
            inner = r0 + (r1 - r0) * ((1 - f) ** 1.6) * 0.9 if taper else r0
            if d < inner or d > r1:
                continue
            k = min(len(ramp) - 1, int(f * len(ramp)))
            if d > r1 - 1.0:
                k = len(ramp) - 1 if f > 0.3 else k
            mine[(x, y)] = ramp[k]
    canvas.stamp(Part(None, (0, 0), px=mine, size=(0, 0)), sep=sep)
    return mine


def sparkle(canvas, x, y, size, c_core, c_ray):
    canvas.put(x, y, c_core)
    for i in range(1, size + 1):
        cc = c_ray if i > 1 else c_core
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            canvas.put(x + dx, y + dy, cc)


def lie_down(cv, stage, cx=30, under=None, extra=None):
    """Quarter-turn a limp standing body so it lies on its back, head toward the
    rear. stage 1 = mid-fall bounce (2px up), 2 = flat. `under(canvas, x0, x1, y)`
    draws things beneath the body (spread cloak), `extra(canvas)` on top."""
    W = cv.w
    pts = {(y, W - 1 - x): c for (x, y), c in cv.px.items()}
    maxy = max(y for _, y in pts)
    minx, maxx = min(x for x, _ in pts), max(x for x, _ in pts)
    dx = cx - (minx + maxx) // 2
    lift = 2 if stage == 1 else 0
    dy = 59 - maxy - lift
    out = Canvas(cv.w, cv.h)
    if under:
        under(out, minx + dx, maxx + dx, 59 - lift)
    for (x, y), c in pts.items():
        out.put(x + dx, y + dy, c)
    if extra:
        extra(out)
    return out


def legs(canvas, stance, rx, ry, thigh, shin, boot, thigh_r=2.0, shin_r=1.6):
    for hip, knee, ank, toe in stance:
        o = lambda q: (q[0] + rx, q[1] + ry)
        limb(canvas, [o(hip), o(knee)], thigh_r, thigh)
        limb(canvas, [o(knee), o(ank)], shin_r, shin)
        limb(canvas, [(o(ank)[0], o(ank)[1] - 1), o(ank), o(toe)], 1.5, boot)


def seq(*frames):
    return [(f, d) for f, d in frames]


def ribbon(canvas, x0, y0, length, phase, ramp, amp=1.6, wave=9.0, droop=0.25, r0=1.3, r1=0.6,
           direction=-1, sep=False):
    """Cloth tail trailing from (x0, y0) toward `direction` (-1 = left/back) as a
    travelling sine wave; `phase` (0..1) animates it. Thick at the root."""
    pts = []
    n = max(2, int(length / 2))
    for i in range(n + 1):
        t = i / n
        x = x0 + direction * t * length
        y = y0 + droop * t * length + amp * t * math.sin(2 * math.pi * (t * length / wave - phase))
        pts.append((x, y))
    half = len(pts) // 2 + 1
    limb(canvas, pts[:half], r0, ramp, sep=sep)
    limb(canvas, pts[half - 1:], r1 + 0.01, ramp, sep=False)


def crystal(canvas, bx, by, angle, length, width, ramp=("crystal2", "crystal3", "crystal4", "crystal5", "ink10"),
            sep=False):
    """Faceted crystal prism growing from base (bx, by) toward `angle` degrees.
    Left facet dark, centre mid, right facet bright, a white glint near the tip."""
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    hw = width / 2.0
    mine = {}
    ext = length + width + 2
    for y in range(int(by - ext), int(by + ext + 1)):
        for x in range(int(bx - ext), int(bx + ext + 1)):
            ox, oy = x - bx, y - by
            t = ox * dx + oy * dy
            s = ox * nx + oy * ny
            if t < -0.5 or t > length:
                continue
            tip = length * 0.62
            w = hw if t < tip else hw * (length - t) / (length - tip)
            if abs(s) > w + 0.25:
                continue
            # facet by which side of the axis, flipped so the lit facet faces up-right
            lit = nx * 0.6 + ny * -0.8
            side = s if lit >= 0 else -s
            if side > hw * 0.3:
                c = ramp[3]
            elif side < -hw * 0.3:
                c = ramp[1]
            else:
                c = ramp[2]
            if t > length - 2.2 and side > -0.6:
                c = ramp[4]
            if abs(side) > w - 0.6 and side < 0:
                c = ramp[0]
            mine[(x, y)] = c
    canvas.stamp(Part(None, (0, 0), px=mine, size=(0, 0)), sep=sep)
    return mine


def rows_of(grid):
    return [r.strip() for r in grid.strip("\n").splitlines() if r.strip() and not r.strip().startswith("//")]


def edited(grid, edits, at=(0, 0), legend=None):
    """Part from `grid` with some rows replaced: edits = {row_index: "new row"}.
    Expression and hair variants are small, diffable edits of one base drawing."""
    rows = rows_of(grid)
    for i, r in edits.items():
        rows[i] = r
    return Part("\n".join(rows), at=at, legend=legend)


def layered(cv_size):
    """Three canvases drawn in order back -> legs -> front; the two upper ones
    lean together around the hip so the whole upper body commits to a pose."""
    return Canvas(*cv_size), Canvas(*cv_size), Canvas(*cv_size)


def commit(cv, back, legs_cv, front, pivot_y, lean):
    """Merge layers into cv, shearing the upper-body layers by `lean` px at the top."""
    cv.merge(back.sheared_rows(pivot_y, lean, top_y=pivot_y - 26))
    cv.merge(legs_cv, sep=True)
    cv.merge(front.sheared_rows(pivot_y, lean, top_y=pivot_y - 26), sep=True)
    return cv


class Lean:
    """Upper-body lean around the hip. Soft layers (cloth, torso, smears) are
    sheared row by row; rigid pieces (head, arms, weapons) are drawn on their own
    canvases with coordinates moved by the lean at their height, so they stay
    solid. Order: back, back_rigid, legs, body, head, front_rigid."""

    SPAN = 26

    def __init__(self, size, pivot, lean):
        self.pivot, self.lean = pivot, lean
        self.back, self.back_rigid, self.legs, self.body, self.head, self.front_rigid = (
            Canvas(*size) for _ in range(6))

    def dx(self, y):
        if y >= self.pivot or not self.lean:
            return 0
        return round(self.lean * (self.pivot - y) / self.SPAN)

    def p(self, q):
        return (q[0] + self.dx(q[1]), q[1])

    def compose(self, cv):
        top = self.pivot - self.SPAN
        cv.merge(self.back.sheared_rows(self.pivot, self.lean, top_y=top))
        cv.merge(self.back_rigid)
        cv.merge(self.legs, sep=True)
        cv.merge(self.body.sheared_rows(self.pivot, self.lean, top_y=top), sep=True)
        cv.merge(self.head, sep=True)
        cv.merge(self.front_rigid, sep=True)
        return cv
