"""Healer: lantern-bearer of Lanternrest. White robe with crystal sash, long
indigo hair, a staff with a hanging amber lantern that swings as she moves."""
import math
from pixlib import Canvas, Part, flash
import rig
from rig import seq

NAME = "healer"
SIZE = (64, 64)
ORIGIN = (32, 60)

HEAD_BASE = """
......2344.....
....2344554....
...234455654...
..23445556654..
.2344455555654.
.23444KLLKKL54.
234445ccc5cc5..
23445b1cc81cd..
2344ab1cc81cc..
2344abbcccccd..
234.aabbcccc...
23...aabbb.....
"""
FACES = {
    "idle": {},
    "blink": {7: "23445bbccccbd..", 8: "2344ab1cc11cc.."},
    "serene": {7: "23445bbccccbd..", 8: "2344ab11c11cc..", 10: "234.aabbcbcc..."},
    "fierce": {6: "2344451cc51c5..", 7: "23445b1cc11cd..", 8: "2344abbcccccc.."},
    "hurt": {7: "23445b1bcc1cd..", 8: "2344abb1c1ccc..", 10: "234.aabbcQ1c..."},
}
HEADS = {f: rig.edited(HEAD_BASE, e, at=(24, 22)) for f, e in FACES.items()}

HEAD_DOWN = Part("""
....234432....
..2344554432..
.234455554432.
2344KLLLLK4432
234cccccccc432
23cc11cc11cc32
23cccccccccc32
.2abbcbbcbba2.
..2aabbbbaa2..
""")

HAIR = Part("""
.2334.
23344.
23344.
2334..
2334..
2234..
.234..
.223..
..23..
..2...
""", at=(22, 33))

ROBE = Part("""
.......bc..........
.....67bc897.......
....5678999987.....
...LKKKKKKKLLK.....
..JKKLLKKKLLLKJ....
..IJJKKKKKKKJJI....
...5678899999987...
...567889999998....
...5JKKKKKLLKK.....
...56IJKKKKJ7......
...56788979987.....
..5677889799987....
..56778897999987...
..567788979999987..
.5677889799999987..
.56778897999999987.
.567788979999999987
5677888979999999987
5677888979999999987
5667788979999999987
5667788897999999987
CDDEEEFFFFFEEEEEDDC
.CCDDDDDDDDDDDDDCC.
""", at=(22, 34))

LANTERN = Part("""
..C..
.CDC.
CFGFC
DGGGD
CFGFC
.CDC.
..B..
""")
LANTERN_DIM = Part("""
..C..
.CDC.
CBCBC
BCDCB
CBCBC
.BCB.
..A..
""")

SLEEVE = ("ink6", "ink7", "ink8", "ink9")
SKIN = ("skin1", "skin2", "skin3", "skin4")
WOOD = ("amber1", "amber2", "amber3", "amber4")
BOOT = ("amber1", "amber2", "amber3", "amber3")
SMEAR = ("amber4", "amber5", "amber6", "amber7")

ROBE_RAMP = ("ink6", "ink7", "ink8", "ink9")
TALL = 2  # the healer stands two pixels taller than the others
_R = ROBE.stretched(12, TALL)
ROBES = {
    "idle": (_R, 0),
    "rise": (_R.stretched(3), -1),
    "twist": (_R.shaded(-1, only=("ink",)), 0),
    "open": (_R.shaded(1, only=("ink",)), 0),
    "hunch": (_R.squashed(5), 1),
}

POSE = dict(kb=0, crouch=0, lean=0, sway=0, flare=0, robe="idle", face="idle", hand=(41, 44), sang=-95, top=20,
            bot=15, back=None, lsw=0, smear=None, glow=0, motes=None, flash=False, down=0, hair=0)


def staff(cv, hx, hy, ang, top, bot, lsw, glow, draw_lantern=True):
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    t = (hx + top * dx, hy + top * dy)
    b = (hx - bot * dx, hy - bot * dy)
    rig.limb(cv, [b, t], 0.9, WOOD, sep=False)
    cx, cy = round(t[0]), round(t[1])
    for q, c in (((0, -1), "amber3"), ((1, -2), "amber4"), ((2, -2), "amber3"), ((3, -1), "amber2")):
        cv.put(cx + q[0], cy + q[1], c)
    if draw_lantern:
        lx, ly = cx + 3 + lsw, cy
        cv.put(lx - (lsw > 0), ly, "amber2")
        lan = LANTERN if glow >= 0 else LANTERN_DIM
        cv.stamp(lan, lx - 2, ly + 1)
        if glow > 0:
            cx2, cy2 = lx, ly + 4
            for i in range(3, 4 + glow * 2):
                c = "amber7" if i < 3 + glow else "amber5"
                for dx2, dy2 in ((i, 0), (-i, 0), (0, i + 1), (0, -i - 1)):
                    cv.put(cx2 + dx2, cy2 + dy2, c)
            for d in range(3, 3 + glow):
                for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
                    cv.put(cx2 + sx * d, cy2 + sy * d, "amber5" if d > 3 else "amber6")
    return t


def arm(cv, sh, hd, bend=-1):
    ex = (sh[0] + hd[0]) / 2 + bend
    ey = max(sh[1], hd[1]) + 1 if hd[1] > sh[1] - 3 else (sh[1] + hd[1]) / 2 + 1
    rig.limb(cv, [sh, (ex, ey)], 1.6, SLEEVE)
    rig.limb(cv, [(ex, ey), (hd[0] - 0.5, hd[1])], 2.0, SLEEVE)
    rig.blob(cv, hd[0], hd[1], 1.2, 1.2, SKIN)


def down_pose(stage):
    """Fallen on her side toward us, robe pooled, hair spilled, lantern gone dark."""
    cv = Canvas(*SIZE)
    lift = 1 if stage == 1 else 0
    for i in range(7):  # long hair fanned on the floor
        cv.put(9 + i, 57 - lift + (i % 2), "ink3" if i % 3 else "ink4")
    rig.blob(cv, 31, 56 - lift, 17, 4.2, ROBE_RAMP, sep=False)
    for x in (20, 25, 31, 37, 41):
        cv.put(x, 56 - lift, "ink7")
    cv.put(16, 59, "amber5"); cv.put(17, 59, "amber6"); cv.put(44, 59, "amber5"); cv.put(43, 59, "amber6")
    rig.limb(cv, [(42, 56 - lift), (46, 57 - lift)], 1.0, BOOT)
    rig.blob(cv, 28, 52 - lift, 8, 4.5, ROBE_RAMP)            # torso under the robe
    rig.blob(cv, 39, 53 - lift, 6, 3.2, ROBE_RAMP)            # knees drawn up under the robe
    for x in range(31, 34):
        for y in range(48, 56):
            cv.put(x, y - lift, "crystal4" if y % 3 else "crystal3")  # crystal sash
    cv.stamp(HEAD_DOWN.rot90(3), 11, 44 - lift, sep=True)
    rig.limb(cv, [(26, 50 - lift), (30, 53 - lift), (34, 52 - lift)], 1.5, SLEEVE)
    rig.blob(cv, 34, 52 - lift, 1.2, 1.2, SKIN)
    staff(cv, 40, 58, -2, 14, 6, 0, -1, draw_lantern=False)
    cv.stamp(LANTERN_DIM, 55, 52)
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
    L = rig.Lean(SIZE, 46 + cr, p["lean"])
    robe, rdy = ROBES[p["robe"]]
    ux, uy = kb, cr
    hdy = -TALL + rdy
    sh_b = L.p((29 + ux, 37 + uy + hdy))
    sh_f = L.p((34 + ux, 37 + uy + hdy))
    hx, hy = L.p((p["hand"][0] + ux, p["hand"][1] + uy + hdy))
    hd = L.dx(28 + uy + hdy)
    if p["smear"]:
        rig.arc(L.back, 34 + ux + L.dx(38 + uy), 38 + uy + hdy, 14, 21, *p["smear"], SMEAR)
    L.back.stamp(HAIR, ux + p["hair"], uy + hdy)
    if p["back"]:
        arm(L.back_rigid, sh_b, L.p((p["back"][0] + ux, p["back"][1] + uy + hdy)), 0)
    else:
        arm(L.back_rigid, sh_b, (sh_b[0] - 2, sh_b[1] + 8), -1)
    for fx_ in (28, 35):
        rig.limb(L.legs, [(fx_ + kb, 58), (fx_ + 2 + kb, 58)], 1.0, BOOT)
    robe = robe.sheared(9, p["sway"]).flared(10, p["flare"])
    L.body.stamp(robe, ux - p["flare"], uy, sep=True)
    L.head.stamp(HEADS[p["face"]], ux + hd, uy + hdy, sep=True)
    staff(L.front_rigid, hx, hy, p["sang"], p["top"], p["bot"], p["lsw"], p["glow"])
    arm(L.front_rigid, sh_f, (hx, hy))
    L.compose(cv)
    cv.rim(-1, 1, 0, 56)
    if p["motes"]:
        for (mx, my, c) in p["motes"]:
            if c == "+":
                rig.sparkle(cv, mx + ux, my + uy, 1, "amber7", "life4")
            else:
                cv.put(mx + ux, my + uy, c)
    cv.outline()
    if p["flash"]:
        cv = flash(cv)
    return cv


def _idle():
    out = []
    breath = ["idle", "idle", "rise", "rise", "rise", "idle"]
    sway = [0, -1, -1, 0, 1, 1, 0, -1]
    lan = [0, -1, -1, 0, 1, 1, 0, 0, -1, 0, 1, 0]
    for i in range(12):
        out.append(({"robe": breath[i % 6], "sway": [0, -1, 0, 1][i % 4], "lsw": [0, -1, 0, 1, 1, 0][i % 6] if False else lan[i],
                     "hair": [0, 0, -1, -1, 0][i % 5], "face": "blink" if i == 10 else "idle",
                     "hand": (41, 44) if breath[i % 6] == "idle" else (41, 43)}, 1))
    return out


IDLE = _idle()

ATTACK = seq(
    ({"crouch": 1, "lean": -2, "robe": "twist", "face": "fierce", "sway": 1, "hand": (34, 38), "sang": -140, "top": 18, "bot": 10, "lsw": 1, "hair": 1}, 1),
    ({"crouch": 2, "lean": -4, "robe": "twist", "face": "fierce", "sway": 2, "hand": (31, 35), "sang": -165, "top": 18, "bot": 8, "lsw": 2, "hair": 1}, 2),
    ({"crouch": 1, "lean": 2, "kb": 1, "robe": "open", "face": "fierce", "sway": -2, "hand": (40, 38), "sang": -40, "top": 18, "bot": 8, "lsw": -2,
      "smear": (-165, -40), "hair": -1}, 1),
    ({"crouch": 2, "lean": 4, "kb": 2, "robe": "open", "face": "fierce", "sway": -3, "flare": 1, "hand": (42, 43), "sang": 12, "top": 18, "bot": 8,
      "lsw": -2, "smear": (-130, 15), "hair": -2}, 2),
    ({"crouch": 2, "lean": 4, "kb": 2, "robe": "open", "face": "fierce", "sway": -2, "hand": (41, 45), "sang": 35, "top": 18, "bot": 8, "lsw": 2, "hair": -2}, 1),
    ({"crouch": 1, "lean": 2, "kb": 1, "robe": "idle", "face": "idle", "sway": -1, "hand": (41, 44), "sang": 10, "top": 18, "bot": 8, "lsw": 1, "hair": -1}, 2),
    ({"robe": "rise", "sway": 0, "hand": (41, 43), "sang": -80, "lsw": 0}, 1),
)

_M1 = [(30, 50, "life4"), (44, 46, "amber6"), (26, 42, "+")]
_M2 = [(31, 44, "life4"), (45, 40, "amber6"), (27, 36, "+"), (40, 50, "life3"), (22, 48, "amber5")]
_M3 = [(32, 38, "life4"), (46, 33, "amber7"), (27, 30, "+"), (40, 44, "+"), (21, 42, "amber6"), (35, 52, "life4")]
_M4 = [(33, 31, "life3"), (47, 27, "amber5"), (27, 24, "amber6"), (41, 37, "+"), (20, 35, "life4"), (36, 45, "+")]

CAST = seq(
    ({"crouch": 1, "robe": "hunch", "face": "serene", "sway": 1, "hand": (39, 40), "sang": -92, "lsw": 1}, 1),
    ({"lean": -1, "robe": "rise", "face": "serene", "sway": 0, "flare": 1, "hand": (38, 34), "sang": -88, "lsw": -1, "glow": 1, "motes": _M1}, 1),
    ({"lean": -2, "robe": "open", "face": "serene", "sway": -1, "flare": 2, "hand": (38, 32), "sang": -88, "lsw": 0, "glow": 1, "motes": _M2, "hair": -1}, 1),
    ({"lean": -2, "robe": "open", "face": "idle", "sway": 0, "flare": 3, "hand": (38, 31), "sang": -88, "lsw": 1, "glow": 2, "motes": _M3, "hair": -1}, 2),
    ({"lean": -3, "robe": "open", "face": "idle", "sway": 1, "flare": 3, "hand": (38, 31), "sang": -88, "lsw": 0, "glow": 3, "motes": _M4, "hair": -1}, 2),
    ({"lean": -1, "robe": "rise", "sway": 0, "flare": 1, "hand": (38, 37), "sang": -90, "lsw": -1, "glow": 1}, 1),
    ({"robe": "idle", "sway": 0, "lsw": 0}, 1),
)

HIT = seq(
    ({"kb": -2, "lean": -3, "robe": "hunch", "face": "hurt", "sway": 2, "hand": (42, 43), "sang": -78, "lsw": 2, "hair": 1, "flash": True}, 1),
    ({"kb": -2, "crouch": 1, "lean": -4, "robe": "hunch", "face": "hurt", "sway": 3, "hand": (42, 44), "sang": -75, "lsw": 2, "hair": 1}, 2),
    ({"kb": -1, "crouch": 1, "lean": -2, "robe": "idle", "face": "hurt", "sway": 1, "hand": (42, 44), "sang": -85, "lsw": -1}, 1),
    ({"lean": -1, "face": "blink", "sway": 0, "lsw": 0}, 1),
)

KO = seq(
    ({"kb": -2, "lean": -4, "robe": "hunch", "face": "hurt", "sway": 2, "hand": (42, 43), "sang": -78, "lsw": 2, "flash": True}, 1),
    ({"kb": -3, "crouch": 3, "lean": -3, "robe": "hunch", "face": "hurt", "sway": 2, "hand": (39, 47), "sang": -70, "lsw": 2, "glow": -1}, 2),
    ({"kb": -2, "crouch": 6, "lean": 4, "robe": "hunch", "face": "hurt", "sway": 0, "flare": 2, "hand": (40, 50), "sang": -60, "lsw": 1, "glow": -1}, 3),
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
