"""Mnemowisp: a drifting flame of crystal memory wearing a cracked porcelain
Lumari mask. Shards of what it remembers orbit it. When it dies the flame
unravels upward and only the mask falls."""
import math
from pixlib import Canvas, Part, flash
import rig
from rig import seq

NAME = "wisp"
MONSTER = True
SIZE = (64, 64)
ORIGIN = (32, 60)

MASK = Part("""
...8999...
.8899999..
.899v9999.
8999999999
899##99##9
89#L#9#L#9
899K99K999
899K99K999
8999K99999
.8999##99.
.88999998.
..8899....
""")

MASK_HURT = Part("""
...8999...
.8899w99..
.899vw999.
89999w9999
899##w9##9
89###9###9
899K9wK999
899K99Kw99
8999K999w9
.899#QQ#9.
.88999998.
..8899....
""")

MASK_FALLEN = Part("""
...8899998...
.8899999999..
8#99999998#9.
.88999969988.
...7888877...
""")

SHARD = Part("""
.L.
KLK
JKJ
JKI
.I.
""")

BODY = ("crystal2", "crystal3", "crystal4", "crystal5")


SPINE = [(0, 0), (-1, 7), (-3, 14), (-7, 20), (-13, 23), (-19, 21), (-22, 16), (-21, 12)]
RADII = [8.0, 9.0, 8.5, 7.0, 5.0, 3.4, 2.0, 1.0]


def _ghost(cv, cx, cy, ph, sx=1.0, sy=1.0, lean=0.0, erode=0.0, arms=(0, 0), reach=0):
    """Hooded spectre: tapered stroke along SPINE (head at the top, tail curling
    behind), swaying with phase `ph`. erode in 0..1 eats it from the tail up."""
    pts = []
    for i, (x, y) in enumerate(SPINE):
        t = i / (len(SPINE) - 1)
        w = 2.2 * t * math.sin(6.28 * (t * 0.9 - ph))
        pts.append((cx + x * sx + lean * (1 - t) + w * 0.4, cy + y * sy + w * 0.6, RADII[i] * (sx + sy) / 2))
    keep = len(pts) - erode * (len(pts) - 1)
    samples = []
    for i in range(len(pts) - 1):
        for k in range(8):
            f = k / 8
            j = i + f
            if j > keep - 1:
                break
            a, b = pts[i], pts[i + 1]
            samples.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, j / (len(pts) - 1)))
    px = {}
    for (sxp, syp, r, t) in samples:
        for y in range(int(syp - r - 1), int(syp + r + 2)):
            for x in range(int(sxp - r - 1), int(sxp + r + 2)):
                d = math.hypot(x - sxp, y - syp)
                if d > r:
                    continue
                score = (r - d) / max(r, 0.1)  # 1 at centre
                prev = px.get((x, y))
                if prev and prev[0] >= score:
                    continue
                px[(x, y)] = (score, (x - sxp) / max(r, .1), (y - syp) / max(r, .1), t)
    out = {}
    for (x, y), (score, ox, oy, t) in px.items():
        lit = ox * 0.6 + oy * -0.8
        glow = score + 0.35 * lit - 0.5 * t     # lit from within, brighter up front
        if lit > 0.6 and score < 0.3 and t < 0.75:
            c = "crystal5"                      # rim light on the leading edge
        elif glow > 0.75:
            c = "crystal5"
        elif glow > 0.38:
            c = "crystal4"
        elif glow > -0.05:
            c = "crystal3"
        elif glow > -0.4:
            c = "crystal2"
        else:
            c = "violet2"
        if t > 0.72:
            c = {"crystal5": "crystal4", "crystal4": "crystal3", "crystal3": "crystal2", "crystal2": "violet2", "violet2": "violet1"}[c]
        if t > 0.88:
            c = "violet3" if lit > 0 else "violet2"
        out[(x, y)] = c
    # hood recess: dark hollow the mask sits in
    hx, hy, hr = pts[0]
    for (x, y) in list(out):
        dx, dy = x - (hx + 1.5), y - (hy + 1.5)
        if (dx / (hr * 0.72)) ** 2 + (dy / (hr * 0.85)) ** 2 <= 1:
            out[(x, y)] = "crystal1" if dx < 1 else "crystal2"
    # memory heart glowing in the chest
    mx, my, _ = pts[1]
    mx, my = round(mx - 2), round(my + 2)
    for (dx, dy), c in (((0, -2), "crystal5"), ((-1, -1), "crystal5"), ((0, -1), "ink10"), ((1, -1), "crystal5"),
                        ((-1, 0), "crystal4"), ((0, 0), "ink10"), ((1, 0), "crystal5"), ((0, 1), "crystal4")):
        if (mx + dx, my + dy) in out:
            out[(mx + dx, my + dy)] = c
    # flame licks rising off the back of the shroud
    for k, (i, h0) in enumerate(((1, 5), (2, 4), (3, 3))):
        if i > keep - 1:
            continue
        bxp, byp, r = pts[i]
        h = h0 + round(1.5 * math.sin(6.28 * (ph + k * 0.33)))
        x0, y0 = round(bxp - r * 0.7), round(byp - r * 0.6)
        for j in range(h):
            for dx in range(-max(0, (h - j) // 3), 1):
                out.setdefault((x0 + dx - j // 2, y0 - j), "crystal3" if j < h - 1 else "crystal4")
    part = Part(None, (0, 0), px=out, size=(0, 0))
    cv.stamp(part)
    # arms of light reaching forward
    if erode < 0.6:
        for k, (ax, ay) in enumerate(((5, 9), (2, 11))):
            x0, y0 = cx + ax * sx + lean, cy + ay * sy
            rig.ribbon(cv, x0, y0, 7 + reach, ph + 0.3 * k + arms[k], ("crystal3", "crystal4", "crystal5", "ink10"),
                       amp=1.0, wave=8, droop=0.9 - 0.12 * reach, r0=1.1, r1=0.6, direction=1)
    return pts


POSE = dict(rx=0, ry=0, bob=0, ph=0.0, orb=0.0, orb_r=14, sx=1.0, sy=1.0, lean=0, erode=0.0, reach=0, mask="normal",
            mdx=0, flash=False, glow=0, streak=0, shards=3, fire=None, die=0, motes=None)


def render(params):
    p = dict(POSE)
    p.update(params)
    cv = Canvas(*SIZE)
    cx, cy = 36 + p["rx"], 24 + p["ry"] + p["bob"]
    orbit = []
    for i in range(p["shards"]):
        a = p["orb"] * 6.28 + i * 6.28 / p["shards"]
        orbit.append((math.sin(a), round(cx - 4 + p["orb_r"] * 1.15 * math.cos(a)), round(cy + 12 + p["orb_r"] * 0.4 * math.sin(a))))
    for depth, x, y in orbit:
        if depth < 0:
            cv.stamp(SHARD, x - 1, y - 2)
    if p["streak"]:
        for i, yy in enumerate((cy - 4, cy, cy + 4)):
            for k in range(p["streak"] - 3 * (i == 1)):
                cv.put(cx - 10 - k - 2 * i, yy, "crystal4" if k < 3 else "crystal3")
    if p["die"] < 3 and p["erode"] < 0.5:
        for k in range(2):  # veil streamers trailing off the hood
            rig.ribbon(cv, cx - 5 + p["lean"], cy - 4 + 3 * k, 13 - 3 * k, p["ph"] + 0.4 * k,
                       ("violet1", "violet2", "violet3", "violet4"), amp=1.5, wave=10, droop=0.35 + 0.2 * k, r0=1.3, r1=0.7)
    if p["die"] < 3:
        _ghost(cv, cx, cy, p["ph"], p["sx"], p["sy"], p["lean"], p["erode"], reach=p["reach"])
    if p["glow"]:
        rig.sparkle(cv, cx + 2, cy + 2, 1 + p["glow"], "ink10", "crystal5")
    m = {"normal": MASK, "hurt": MASK_HURT}.get(p["mask"])
    if m and p["die"] < 3:
        cv.stamp(m, cx - 3 + p["mdx"] + p["lean"], cy - 4, sep=False)
    for depth, x, y in orbit:
        if depth >= 0:
            cv.stamp(SHARD, x - 1, y - 2)
    if p["die"] < 3 and p["erode"] < 0.5:
        for k, (dx, dy) in enumerate(((-6, -12), (0, -15), (6, -12))):  # crown of floating shards
            bobk = round(1.2 * math.sin(6.28 * (p["ph"] + k * 0.33)))
            rig.crystal(cv, cx + dx + p["lean"] + p["mdx"], cy + dy + bobk + 4, -90 + dx * 3, 5 + (k == 1) * 2, 3)
    if p["fire"]:
        for (fx_, fy_) in p["fire"]:
            cv.stamp(SHARD.rot90(1), fx_, fy_)
            for k in range(1, 6):
                cv.put(fx_ - k, fy_ + 1, "crystal4" if k < 3 else "crystal2")
    if p["die"] >= 3:
        cv.stamp(MASK_FALLEN, 27, 55)
    if p["motes"]:
        for (x, y, c) in p["motes"]:
            cv.put(x, y, c)
    cv.rim(-1, 1, 0, 60, color="violet4", skip=("ink1", "LINE", "ink8", "ink9", "ink10", "violet4", "crystal5"))
    cv.outline()
    if p["flash"]:
        cv = flash(cv)
    return cv


def _idle():
    out = []
    n = 8
    for i in range(n):
        out.append(({"bob": round(-2 * math.sin(i * 6.28 / n)), "ph": i / n, "orb": i / n,
                     "mdx": 1 if i in (2, 3) else 0}, 1))
    return out


ATTACK = seq(
    ({"rx": -2, "sx": 1.05, "sy": 0.95, "lean": -1, "ph": 0.1, "orb": 0.1}, 1),
    ({"rx": -4, "ry": -1, "sx": 1.1, "sy": 0.9, "lean": -3, "ph": 0.3, "orb": 0.2, "orb_r": 12, "reach": -2}, 2),
    ({"rx": 8, "sx": 1.2, "sy": 0.85, "lean": 3, "ph": 0.5, "orb": 0.35, "streak": 9, "orb_r": 16, "reach": 4}, 1),
    ({"rx": 11, "ry": 1, "sx": 1.0, "sy": 1.0, "lean": 3, "ph": 0.7, "orb": 0.45, "streak": 4, "mdx": 1, "reach": 7}, 2),
    ({"rx": 7, "lean": 1, "ph": 0.9, "orb": 0.55, "reach": 3}, 1),
    ({"rx": 2, "ph": 0.0, "orb": 0.65}, 2),
)

CAST = seq(
    ({"ph": 0.1, "orb": 0.0, "orb_r": 13, "glow": 0}, 1),
    ({"ph": 0.3, "orb": 0.15, "orb_r": 15, "glow": 1, "bob": -1, "reach": 2}, 1),
    ({"ph": 0.5, "orb": 0.35, "orb_r": 17, "glow": 2, "bob": -2, "sx": 1.05, "sy": 1.05, "reach": 3}, 1),
    ({"ph": 0.7, "orb": 0.6, "orb_r": 18, "glow": 3, "bob": -2, "sx": 1.05, "sy": 1.05, "reach": 4}, 2),
    ({"ph": 0.9, "shards": 0, "glow": 1, "fire": [(50, 26), (53, 33), (49, 40)], "rx": -1, "lean": 2, "reach": 6}, 1),
    ({"ph": 0.1, "shards": 0, "fire": [(58, 26), (61, 33), (57, 40)], "rx": -2, "lean": 1, "reach": 3}, 2),
    ({"ph": 0.3, "shards": 3, "orb": 0.8, "orb_r": 10, "rx": -1}, 1),
)

HIT = seq(
    ({"rx": -3, "sx": 0.9, "sy": 1.08, "lean": -2, "ph": 0.2, "orb": 0.1, "mask": "hurt", "flash": True}, 1),
    ({"rx": -4, "sx": 0.9, "sy": 1.08, "lean": -3, "ph": 0.4, "orb": 0.12, "mask": "hurt", "mdx": -1, "erode": 0.15}, 2),
    ({"rx": -2, "lean": -1, "ph": 0.6, "orb": 0.15, "mask": "hurt"}, 1),
    ({"rx": -1, "ph": 0.8, "orb": 0.2}, 1),
)

_D1 = [(22, 30, "crystal5"), (18, 24, "crystal4"), (14, 34, "crystal3"), (26, 20, "crystal5")]
_D2 = [(22, 22, "crystal4"), (18, 15, "crystal3"), (14, 26, "crystal4"), (27, 11, "crystal5"), (32, 16, "crystal5"), (38, 20, "crystal4")]
_D3 = [(23, 12, "crystal3"), (19, 6, "crystal2"), (15, 16, "crystal3"), (28, 3, "crystal4"), (33, 7, "crystal4"), (39, 11, "crystal3"), (35, 30, "crystal5")]
_D4 = [(20, 2, "crystal2"), (16, 8, "crystal2"), (34, 1, "crystal3"), (40, 4, "crystal2"), (35, 20, "crystal3")]

KO = seq(
    ({"rx": -3, "sx": 0.9, "sy": 1.08, "lean": -2, "ph": 0.2, "mask": "hurt", "flash": True}, 1),
    ({"rx": -2, "ry": 3, "lean": -1, "ph": 0.4, "mask": "hurt", "erode": 0.35, "shards": 2, "motes": _D1}, 2),
    ({"rx": -1, "ry": 9, "ph": 0.6, "mask": "hurt", "erode": 0.7, "shards": 1, "sx": 0.85, "sy": 0.8, "motes": _D2}, 2),
    ({"die": 3, "shards": 0, "motes": _D3}, 2),
    ({"die": 3, "shards": 0, "motes": _D4}, 4),
)

ANIMS = [
    {"name": "idle", "fps": 8, "loop": True, "frames": _idle()},
    {"name": "attack", "fps": 14, "loop": False, "frames": ATTACK, "events": {"impact": 3}},
    {"name": "cast", "fps": 12, "loop": False, "frames": CAST, "events": {"impact": 4}},
    {"name": "hit", "fps": 12, "loop": False, "frames": HIT},
    {"name": "ko", "fps": 10, "loop": False, "frames": KO},
]
