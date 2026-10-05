"""Combat FX: physical hit spark, magic burst, heal glow. 48x48 frames,
centred on the frame (ORIGIN is the effect's centre / the heal's ground point)."""
import math
from pixlib import Canvas, Part
import rig

NAME = "fx"
SIZE = (48, 48)
ORIGIN = (24, 24)
C = (24, 24)


def star(cv, cx, cy, long, short, core, ray, tip):
    """Four long rays + four short diagonals, tapering, bright centre."""
    for i in range(1, long + 1):
        w = 1 if i > long // 2 else 2
        c = core if i <= 2 else (ray if i < long - 1 else tip)
        for dx, dy, nx, ny in ((1, 0, 0, 1), (-1, 0, 0, 1), (0, 1, 1, 0), (0, -1, 1, 0)):
            cv.put(cx + dx * i, cy + dy * i, c)
            if w == 2:
                cv.put(cx + dx * i + nx, cy + dy * i + ny, ray)
                cv.put(cx + dx * i - nx, cy + dy * i - ny, ray)
    for i in range(1, short + 1):
        c = ray if i < short else tip
        for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            cv.put(cx + dx * i, cy + dy * i, c)
    rig.blob(cv, cx, cy, 2.2, 2.2, (core, core, core, core), sep=False)


def spike(cv, cx, cy, ang, length, base, colors):
    """Tapered triangular ray; colors = (outer, mid, core)."""
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    for y in range(cy - length - 2, cy + length + 3):
        for x in range(cx - length - 2, cx + length + 3):
            ox, oy = x - cx, y - cy
            t = ox * dx + oy * dy
            s_ = abs(-ox * dy + oy * dx)
            if t < 0 or t > length:
                continue
            w = base * (1 - t / length)
            if s_ > w + 0.3:
                continue
            c = colors[2] if s_ < w * 0.35 and t < length * 0.75 else (colors[1] if s_ < w * 0.75 else colors[0])
            cv.put(x, y, c)


def burst_star(cv, cx, cy, L, l, base, colors, rot=0):
    for k in range(4):
        spike(cv, cx, cy, rot + k * 90, L, base, colors)
        spike(cv, cx, cy, rot + 45 + k * 90, l, base * 0.6, colors)
    rig.blob(cv, cx, cy, base + 0.5, base + 0.5, (colors[2],) * 4, sep=False)


def shards(cv, cx, cy, r, n, c1, c2, rot=0.3, L=3):
    for k in range(n):
        a = rot + k * 6.28 / n
        x0, y0 = cx + r * math.cos(a), cy + r * math.sin(a)
        for j in range(L):
            cv.put(round(x0 + j * math.cos(a)), round(y0 + j * math.sin(a)), c1 if j == L - 1 else c2)


def ring(cv, cx, cy, r, c, gaps=0, sy=1.0, rot=0.0, c2=None):
    n = max(8, int(6.28 * r * 1.5))
    for i in range(n):
        if gaps and (i * gaps // n) % 2 == 1:
            continue
        a = rot + i * 6.28 / n
        cc = c2 if (c2 and math.sin(a) > 0.2) else c
        cv.put(round(cx + r * math.cos(a)), round(cy + r * sy * math.sin(a)), cc)


def hit_spark(i):
    cv = Canvas(*SIZE)
    cx, cy = C
    hot = ("amber5", "amber7", "ink10")
    if i == 0:
        burst_star(cv, cx, cy, 8, 4, 2.5, hot)
    elif i == 1:
        burst_star(cv, cx, cy, 17, 9, 3.5, hot, rot=0)
        ring(cv, cx, cy, 9, "amber7")
    elif i == 2:
        burst_star(cv, cx, cy, 13, 6, 2.5, ("amber4", "amber6", "amber7"), rot=10)
        ring(cv, cx, cy, 12, "amber6", gaps=6)
        shards(cv, cx, cy, 14, 6, "amber7", "amber5", L=3)
    elif i == 3:
        burst_star(cv, cx, cy, 6, 3, 1.5, ("amber3", "amber4", "amber6"), rot=20)
        ring(cv, cx, cy, 15, "amber4", gaps=8)
        shards(cv, cx, cy, 18, 6, "amber6", "amber4", L=2)
    else:
        shards(cv, cx, cy, 21, 6, "amber4", "amber3", L=1)
    if i < 3:
        cv.outline(mode="ink")
    return cv


def magic_burst(i):
    cv = Canvas(*SIZE)
    cx, cy = C
    if i in (0, 1):
        # gathering motes spiralling inward
        r = 16 - i * 7
        for k in range(8):
            a = k * 0.785 + i * 0.6
            c = "crystal5" if k % 2 else "violet4"
            cv.put(round(cx + r * math.cos(a)), round(cy + r * math.sin(a)), c)
            cv.put(round(cx + (r + 2) * math.cos(a - 0.2)), round(cy + (r + 2) * math.sin(a - 0.2)), "violet3")
        rig.blob(cv, cx, cy, 1 + i, 1 + i, ("violet3", "violet4", "ink10", "ink10"), sep=False)
    elif i == 2:
        rig.blob(cv, cx, cy, 6, 6, ("violet3", "violet4", "crystal5", "ink10"), sep=False)
        star(cv, cx, cy, 10, 0, "ink10", "crystal5", "violet4")
    elif i == 3:
        rig.blob(cv, cx, cy, 5, 5, ("violet2", "violet3", "violet4", "crystal5"), sep=False)
        ring(cv, cx, cy, 10, "violet4", c2="crystal5")
        ring(cv, cx, cy, 11, "violet3")
        shards(cv, cx, cy, 13, 8, "crystal5", "violet4", rot=0.2)
    elif i == 4:
        ring(cv, cx, cy, 14, "violet3", c2="violet4")
        ring(cv, cx, cy, 8, "violet2", gaps=8)
        shards(cv, cx, cy, 16, 8, "crystal4", "violet3", rot=0.2)
        rig.sparkle(cv, cx, cy, 2, "crystal5", "violet3")
    elif i == 5:
        ring(cv, cx, cy, 17, "violet2", gaps=10)
        shards(cv, cx, cy, 19, 8, "violet3", "violet2", rot=0.2, L=2)
    else:
        for k in range(6):
            a = k * 1.05 + 0.4
            cv.put(round(cx + 20 * math.cos(a)), round(cy + 20 * math.sin(a)), "violet2")
    return cv


def heal_glow(i):
    cv = Canvas(*SIZE)
    cx, gy = 24, 40  # ground point of the heal
    r = min(15, 6 + i * 2.5)
    if i < 7:
        ring(cv, cx, gy, r, "amber6" if i < 4 else "amber4", sy=0.35, c2="life4" if i < 5 else None)
        if i < 5:
            ring(cv, cx, gy, max(2, r - 3), "life3", sy=0.35, gaps=6)
    # column of light
    if 1 <= i <= 5:
        h = 12 + min(i, 4) * 6
        width = 3 if i < 5 else 1
        for y in range(gy - h, gy):
            f = (gy - y) / h
            w = round(width * (1 - f * 0.7))
            for dx in range(-w, w + 1):
                c = "amber7" if abs(dx) < max(1, w - 1) and f < 0.7 else ("amber6" if f < 0.85 else "amber5")
                cv.put(cx + dx, y, c)
        for sx in (-6, 6):
            for y in range(gy - h // 2 - (i * 2), gy - 2):
                if (y + i) % 4:
                    cv.put(cx + sx, y, "life4" if (y // 4) % 2 else "amber6")
    # rising motes and crosses
    seeds = [(-9, 0.0), (8, 0.15), (-4, 0.35), (11, 0.5), (3, 0.62), (-12, 0.78), (6, 0.9)]
    for k, (dx, ph) in enumerate(seeds):
        t = i / 7.0 + ph
        if t > 1.15 or i == 0:
            continue
        y = round(gy - 4 - t * 30)
        x = cx + dx + round(math.sin(t * 9 + k))
        if k % 3 == 0:
            for (ox, oy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
                cv.put(x + ox, y + oy, "amber7" if (ox, oy) == (0, 0) else ("life4" if abs(ox) + abs(oy) == 1 else "life3"))
        else:
            cv.put(x, y, "amber7" if t < 0.6 else "amber5")
            cv.put(x, y + 1, "amber5" if t < 0.6 else "amber3")
    return cv


FUN = {"hit_spark": hit_spark, "magic_burst": magic_burst, "heal_glow": heal_glow}
N = {"hit_spark": 5, "magic_burst": 7, "heal_glow": 8}


def render(p):
    return FUN[p["fx"]](p["i"])


ANIMS = [
    {"name": "hit_spark", "fps": 20, "loop": False, "frames": [({"fx": "hit_spark", "i": i}, 1) for i in range(5)]},
    {"name": "magic_burst", "fps": 16, "loop": False, "frames": [({"fx": "magic_burst", "i": i}, 2 if i == 2 else 1) for i in range(7)]},
    {"name": "heal_glow", "fps": 12, "loop": False, "frames": [({"fx": "heal_glow", "i": i}, 1) for i in range(8)]},
]
