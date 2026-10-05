"""Mage: violet-robed memory-weaver under a huge floppy hat. Silver hair,
crystal eyes glowing in the brim's shadow, staff crowned by a floating Shard."""
import math
from pixlib import Canvas, Part, flash
import rig
from rig import seq

NAME = "mage"
SIZE = (64, 64)
ORIGIN = (32, 60)

HAT = Part("""
......vwx.........
.....vwxxw........
.....vwxxxw.......
....vwwxxyxw......
....vwwxxyyxw.....
...vwwwxxxyxxw....
...AABBCDEEDCBB...
..vvwwwxxxxxyyxw..
vvwwwwwxxxxxxyyxww
1vvwwwwwwxxxxxxxxw
.11vvvvwwwwwwwwvv.
""", at=(21, 17))

TIPS = [Part(g, at=(21, 17)) for g in ("""
..vw..
...vww
....vw
""", """
.vww..
...vww
....vw
""", """
......
.vvwww
....vw
""", """
v.....
.vvww.
...vww
""")]

HEAD_BASE = """
.899989988..
88912111198.
89aaaaaaaa8.
89abLbbLKc..
.8abbbbbbcc.
.88abbbbcb..
...aabbb....
"""
FACES = {
    "idle": {},
    "blink": {3: "89abbbbbbc.."},
    "focus": {3: "89abLbbLLc..", 5: ".88abbbbab.."},
    "fierce": {2: "89aaa1aaa18.", 3: "89abLbbLKc..", 5: ".88abbb1ab.."},
    "hurt": {3: "89ab1bb1bc..", 5: ".88abbbQ1b.."},
}
HEADS = {f: rig.edited(HEAD_BASE, e, at=(25, 27)) for f, e in FACES.items()}

HEAD_DOWN = Part("""
..89999988..
.8999999998.
89aaaaaaaa98
89ab1bb1ba98
.8abbbbbba8.
..aabbbbaa..
""")

HAIR = Part("""
..899
.8998
89988
8988.
.88..
.8...
""", at=(22, 30))

ROBE = Part("""
......bc.........
....vwbcxw.......
...vwwxxyyx......
..vwwxxxyyyx.....
..vwwxxxxyyx.....
..vwwxxxxyyx.....
..vwwFxxxxyx.....
..vAABCDEDCBA....
..vwwxxFxxyx.....
..vwwxxFxxyyx....
.vvwwxxFxxxyx....
.vwwxxxFxxxyyx...
.vwwxxxFxxxxyx...
vvwwxxxFxxxxyyx..
vwwwxxxFxxxxxyx..
vwwxxxxFxxxxxyyx.
vwwwxxxFxxxxxxyx.
vwwxxxxFxxxxxxyyx
vwwwxxxFxxxxxxxyx
CDDEEEFFFFEEEEEDC
.CCDDDDDDDDDDDCC.
""", at=(23, 37))

SHARD = Part("""
..L..
.KLK.
JKLKJ
IJKJI
.IJI.
..I..
""")

SLEEVE = ("violet1", "violet2", "violet3", "violet4")
SKIN = ("skin1", "skin2", "skin3", "skin4")
WOOD = ("ink2", "ink3", "ink5", "ink6")
BOOT = ("ink2", "ink3", "ink4", "ink4")
SMEAR = ("violet2", "violet3", "violet4", "crystal5")

ROBE_RAMP = ("violet1", "violet2", "violet3", "violet4")
SHORT = 2  # the mage is the smallest of the party; the hat carries her silhouette
_R = ROBE.squashed(12, SHORT)
ROBES = {
    "idle": (_R, 0),
    "rise": (_R.stretched(3), -1),
    "twist": (_R.shaded(-1, only=("violet",)), 0),
    "open": (_R.shaded(1, only=("violet",)), 0),
    "hunch": (_R.squashed(4), 1),
}

POSE = dict(kb=0, crouch=0, lean=0, sway=0, flare=0, robe="idle", face="idle", hand=(40, 46), sang=-80, top=15,
            bot=8, back=None, tip=0, sbob=0, smear=None, charge=0, bolt=None, flash=False, down=0, hat_dy=0)


def staff(cv, hx, hy, ang, top, bot, sbob, charge):
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    t = (hx + top * dx, hy + top * dy)
    b = (hx - bot * dx, hy - bot * dy)
    rig.limb(cv, [b, t], 0.9, WOOD, sep=False)
    tx, ty = round(t[0]), round(t[1])
    cv.put(tx - 1, ty - 1, "ink5")
    cv.put(tx + 1, ty - 1, "ink6")
    cv.put(tx - 2, ty - 2, "ink4")
    cv.put(tx + 2, ty - 2, "ink6")
    sx, sy = tx - 2, ty - 8 + sbob
    cv.stamp(SHARD, sx, sy)
    if charge:
        cx, cy = sx + 2, sy + 3
        for i in range(charge * 3):
            ang2 = i * 2 * math.pi / (charge * 3) + charge
            r = 5 + charge
            c = "violet4" if i % 2 else "crystal5"
            cv.put(round(cx + r * math.cos(ang2)), round(cy + r * math.sin(ang2)), c)
        rig.sparkle(cv, cx, cy, 1 + charge, "ink10", "crystal5")
    return (sx + 2, sy + 3)


def arm(cv, sh, hd, bend=-1):
    ex = (sh[0] + hd[0]) / 2 + bend
    ey = max(sh[1], hd[1]) + 1 if hd[1] > sh[1] - 3 else (sh[1] + hd[1]) / 2 + 1
    rig.limb(cv, [sh, (ex, ey)], 1.6, SLEEVE)
    rig.limb(cv, [(ex, ey), (hd[0] - 0.5, hd[1])], 2.1, SLEEVE)
    rig.blob(cv, hd[0], hd[1], 1.2, 1.2, SKIN)


def down_pose(stage):
    """Crumpled on her side toward us, robe pooled, hat tumbled off, shard dimmed."""
    cv = Canvas(*SIZE)
    lift = 1 if stage == 1 else 0
    hat = HAT.moved(-HAT.at[0], -HAT.at[1])
    cv.stamp(hat, 0, 48 - lift * 2)                          # hat fallen behind her
    rig.blob(cv, 32, 56 - lift, 15, 4.0, ROBE_RAMP, sep=False)
    for x in (22, 27, 34, 40):
        cv.put(x, 55 - lift, "violet1")
    for x in range(19, 46):
        cv.put(x, 59, "amber4" if x % 4 else "amber5")       # gold hem trim along the floor
    rig.blob(cv, 30, 52 - lift, 7, 4.2, ROBE_RAMP)
    rig.blob(cv, 39, 53 - lift, 5, 3.0, ROBE_RAMP)
    for i in range(5):
        cv.put(14 + i, 57 - lift + (i % 2), "ink8" if i % 2 else "ink9")  # silver hair spilled
    cv.stamp(HEAD_DOWN.rot90(3), 16, 46 - lift, sep=True)
    rig.limb(cv, [(28, 50 - lift), (32, 53 - lift), (36, 52 - lift)], 1.6, SLEEVE)
    rig.blob(cv, 36, 52 - lift, 1.2, 1.2, SKIN)
    rig.limb(cv, [(40, 58), (54, 57)], 0.9, WOOD, sep=False)
    cv.stamp(SHARD.shaded(-2), 55, 53)
    return cv


def render(params):
    p = dict(POSE)
    p.update(params)
    if p["down"]:
        cv = down_pose(p["down"])
        cv.rim(-1, 1, 0, 60)
        cv.outline()
        return cv
    cv = Canvas(*SIZE)
    kb, cr = p["kb"], p["crouch"]
    L = rig.Lean(SIZE, 48 + cr, p["lean"])
    robe, rdy = ROBES[p["robe"]]
    ux, uy = kb, cr
    hdy = SHORT + rdy
    sh_b = L.p((29 + ux, 39 + uy + hdy))
    sh_f = L.p((34 + ux, 39 + uy + hdy))
    hx, hy = L.p((p["hand"][0] + ux, p["hand"][1] + uy + hdy))
    hd = L.dx(30 + uy + hdy)
    if p["smear"]:
        rig.arc(L.back, 35 + ux + L.dx(41 + uy), 41 + uy + hdy, 12, 19, *p["smear"], SMEAR)
    L.back.stamp(HAIR, ux, uy + hdy)
    if p["back"]:
        arm(L.back_rigid, sh_b, L.p((p["back"][0] + ux, p["back"][1] + uy + hdy)), 0)
    else:
        arm(L.back_rigid, sh_b, (sh_b[0] - 2, sh_b[1] + 7), -1)
    for fx_ in (28, 35):
        rig.limb(L.legs, [(fx_ + kb, 58), (fx_ + 2 + kb, 58)], 1.0, BOOT)
    robe = robe.sheared(8, p["sway"]).flared(9, p["flare"])
    L.body.stamp(robe, ux - p["flare"], uy, sep=True)
    L.head.stamp(HEADS[p["face"]], ux + hd, uy + hdy, sep=True)
    hat_y = uy + hdy + p["hat_dy"]
    hdh = L.dx(20 + hat_y)
    L.head.stamp(HAT, ux + hdh, hat_y, sep=True)
    L.head.stamp(TIPS[p["tip"]], ux + hdh, hat_y)
    staff(L.front_rigid, hx, hy, p["sang"], p["top"], p["bot"], p["sbob"], p["charge"])
    arm(L.front_rigid, sh_f, (hx, hy))
    L.compose(cv)
    cv.rim(-1, 1, 0, 56)
    if p["bolt"]:
        x0, y0, n = p["bolt"]
        for i in range(n):
            c = ("crystal5", "violet4", "violet3", "violet2")[min(3, i // 2)]
            cv.put(x0 - i, y0 + (i % 3 == 1) - (i % 3 == 2), c)
        rig.sparkle(cv, x0 + 1, y0, 2, "ink10", "crystal5")
    cv.outline()
    if p["flash"]:
        cv = flash(cv)
    return cv


def _idle():
    out = []
    breath = ["idle", "idle", "rise", "rise", "rise", "idle"]
    for i in range(12):
        out.append(({"robe": breath[i % 6], "sway": [0, -1, 0, 1][i % 4], "tip": [0, 1, 2, 3, 2][i % 5],
                     "sbob": [0, -1, -1, 0, 1, 1][(i + 2) % 6], "face": "blink" if i == 5 else "idle",
                     "hand": (40, 46) if breath[i % 6] == "idle" else (40, 45)}, 1))
    return out


IDLE = _idle()

ATTACK = seq(
    ({"crouch": 1, "lean": -2, "robe": "twist", "face": "focus", "sway": 1, "hand": (35, 42), "sang": -120, "tip": 1, "sbob": 1}, 1),
    ({"crouch": 2, "lean": -4, "robe": "twist", "face": "focus", "sway": 2, "hand": (33, 40), "sang": -135, "tip": 2, "sbob": 2, "hat_dy": -1}, 2),
    ({"crouch": 1, "lean": 2, "kb": 1, "robe": "open", "face": "fierce", "sway": -2, "hand": (42, 42), "sang": -45, "tip": 3,
      "smear": (-150, -45), "sbob": -1}, 1),
    ({"crouch": 2, "lean": 4, "kb": 2, "robe": "open", "face": "fierce", "sway": -3, "flare": 1, "hand": (44, 44), "sang": -10,
      "top": 13, "tip": 3, "smear": (-120, -10), "bolt": (62, 35, 9)}, 2),
    ({"crouch": 2, "lean": 4, "kb": 2, "robe": "open", "face": "fierce", "sway": -2, "hand": (43, 45), "sang": -15, "tip": 2}, 1),
    ({"crouch": 1, "lean": 2, "kb": 1, "robe": "idle", "sway": -1, "hand": (42, 45), "sang": -40, "tip": 1}, 2),
    ({"robe": "rise", "sway": 0, "hand": (40, 45), "sang": -70, "tip": 0}, 1),
)

CAST = seq(
    ({"crouch": 1, "robe": "hunch", "face": "focus", "sway": 1, "hand": (39, 44), "sang": -85, "tip": 1}, 1),
    ({"lean": -1, "robe": "rise", "face": "focus", "flare": 1, "hand": (39, 38), "sang": -88, "tip": 2, "charge": 1, "back": (35, 41)}, 1),
    ({"lean": -2, "robe": "open", "face": "focus", "sway": -1, "flare": 2, "hand": (39, 36), "sang": -88, "tip": 3, "charge": 2, "back": (35, 40), "sbob": -1, "hat_dy": -1}, 2),
    ({"lean": -3, "robe": "open", "face": "fierce", "sway": 0, "flare": 3, "hand": (39, 36), "sang": -88, "tip": 2, "charge": 3, "back": (35, 40), "sbob": -2, "hat_dy": -1}, 2),
    ({"crouch": 1, "lean": 4, "kb": 1, "robe": "open", "face": "fierce", "sway": -3, "flare": 2, "hand": (44, 41), "sang": -40, "tip": 3, "charge": 2,
      "smear": (-120, -40)}, 1),
    ({"crouch": 1, "lean": 2, "robe": "idle", "sway": -1, "flare": 1, "hand": (43, 43), "sang": -45, "tip": 2}, 2),
    ({"robe": "rise", "sway": 0, "tip": 1}, 1),
)

HIT = seq(
    ({"kb": -2, "lean": -3, "robe": "hunch", "face": "hurt", "sway": 2, "hand": (41, 45), "sang": -65, "tip": 3, "hat_dy": -1, "flash": True}, 1),
    ({"kb": -2, "crouch": 1, "lean": -4, "robe": "hunch", "face": "hurt", "sway": 3, "hand": (41, 46), "sang": -62, "tip": 3, "hat_dy": -2}, 2),
    ({"kb": -1, "crouch": 1, "lean": -2, "robe": "idle", "face": "hurt", "sway": 1, "hand": (40, 46), "sang": -72, "tip": 2, "hat_dy": -1}, 1),
    ({"lean": -1, "face": "blink", "sway": 0, "tip": 1}, 1),
)

KO = seq(
    ({"kb": -2, "lean": -4, "robe": "hunch", "face": "hurt", "sway": 2, "hand": (41, 45), "sang": -65, "tip": 3, "hat_dy": -2, "flash": True}, 1),
    ({"kb": -3, "crouch": 3, "lean": -3, "robe": "hunch", "face": "hurt", "sway": 2, "hand": (40, 48), "sang": -60, "tip": 3, "hat_dy": -4}, 2),
    ({"kb": -2, "crouch": 6, "lean": 4, "robe": "hunch", "face": "hurt", "flare": 2, "hand": (41, 50), "sang": -50, "tip": 2, "hat_dy": -3}, 3),
    ({"down": 1}, 1),
    ({"down": 2}, 4),
)

ANIMS = [
    {"name": "idle", "fps": 6, "loop": True, "frames": IDLE},
    {"name": "attack", "fps": 14, "loop": False, "frames": ATTACK, "events": {"impact": 3}},
    {"name": "cast", "fps": 10, "loop": False, "frames": CAST, "events": {"impact": 4}},
    {"name": "hit", "fps": 12, "loop": False, "frames": HIT},
    {"name": "ko", "fps": 10, "loop": False, "frames": KO},
]
