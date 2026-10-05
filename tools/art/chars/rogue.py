"""Rogue: hooded knife-fighter in a moss-green mantle with a long amber scarf.
Low crouched silhouette, twin daggers, scarf tails carry the secondary motion."""
import math
from pixlib import Canvas, Part, flash
import rig
from rig import seq

NAME = "rogue"
SIZE = (64, 64)
ORIGIN = (32, 60)

HEAD_BASE = """
.MN.............
.MNNM...........
..MNOONNM.......
..MNOOOOONNM....
.MNOOOOOOOPONM..
MNOOOOOOOPPPONM.
MNOOOOONNNNNOPM.
MNOOONMaaaaaaNNM
MNOONab1cc8#cd..
MNOONab1cc81ccd.
MNOONabbcccccd..
.MNONabbbccccc..
.MNNMaabbbbbb...
..MM............
"""
FACES = {
    "idle": {},
    "blink": {8: "MNOONabbccccccd.", 9: "MNOONab1cc11ccd."},
    "strain": {7: "MNOONM1aaaa1aNNM"},
    "fierce": {7: "MNOONM1aaa1aaNNM", 8: "MNOONab1cc11cd..", 9: "MNOONabbccccccd."},
    "hurt": {8: "MNOONa1bcc1bcd..", 9: "MNOONab1cc1cccd."},
}
HOODS = [{}, {0: "MN..............", 1: ".MNNM..........."}, {0: "..MN............", 1: ".MNNM..........."}]
HEADS = {}
for _f, _e in FACES.items():
    for _h, _he in enumerate(HOODS):
        HEADS[(_f, _h)] = rig.edited(HEAD_BASE, {**_he, **_e}, at=(23, 23))

HEAD_DOWN = Part("""
....MNNM....
..MNOOOONM..
.MNOOPPOONM.
MNOONNNNOONM
MNOaaaaaaONM
MNabbbbbbaNM
MNb11bb11bNM
.MbbbbbbbbM.
.MCDDEEDDCM.
..CDEEEEDC..
""")

SCARF = Part("""
...CDEEFE
..CDDEEFFE
...CDDEED
""", at=(26, 34))

MANTLE = Part("""
.....MNNO
...MNNOOP
..MNNOOP.
.MNNOOP..
MNNOOP...
MNNOO....
.MNN.....
..M......
""", at=(22, 36))

TORSO = Part("""
..MNOOPOM..
.MNOOOPPONM
..3ABBCB4..
..3ABCCB4..
..3ABCCB4..
..2ABBBA3..
..AACEFCA..
..3445564..
""", at=(26, 37))

SCARF_RAMP = ("amber3", "amber4", "amber5", "amber6")
SLEEVE = ("ink3", "ink4", "ink5", "ink6")
WRAP = ("amber1", "amber2", "amber3", "amber4")
TIGHTS = ("ink3", "ink4", "ink5", "ink6")
BANDAGE = ("fade1", "fade2", "fade3", "fade3")
BOOTS = ("amber1", "amber2", "amber2", "amber3")
GLOVE = ("ink2", "ink4", "ink5", "ink6")
STEEL = ("ink6", "ink8", "ink9", "ink10")
SMEAR = ("violet3", "ink9", "ink10")

LEGS = {
    "ready": (((30, 46), (25, 50), (22, 56), (25, 58)), ((34, 46), (39, 49), (40, 56), (43, 58))),
    "low": (((30, 46), (24, 50), (20, 56), (23, 58)), ((34, 46), (40, 49), (41, 56), (44, 58))),
    "dash": (((30, 46), (24, 50), (18, 54), (17, 57)), ((34, 46), (40, 48), (43, 56), (46, 58))),
    "tuck": (((30, 46), (27, 49), (26, 54), (29, 55)), ((34, 46), (38, 48), (37, 53), (40, 54))),
    "kneel": (((30, 46), (27, 53), (22, 58), (24, 58)), ((34, 46), (40, 47), (40, 57), (43, 58))),
}

TORSOS = {
    "idle": (TORSO, (0, 0)),
    "rise": (TORSO.stretched(2), (0, -1)),
    "twist": (TORSO.narrowed(5).shaded(-1), (-1, 0)),
    "open": (TORSO.widened(5).shaded(1, only=("ink", "amber")), (1, 0)),
    "hunch": (TORSO.squashed(3).shaded(-1), (0, 1)),
}
SMEAR = ("ink6", "ink8", "violet4", "ink10", "ink10")
MANTLE_RAMP = ("life1", "life2", "life3", "life4")

POSE = dict(kb=0, crouch=1, lean=0, legs="ready", torso="idle", face="idle", hood=0, hand=(40, 45), fang=-25,
            back=(34, 39), bang=-70, tails=0, wind=0, smear=None, smear2=None, knives=None, flash=False, down=0, ry=0)


def dagger(cv, hx, hy, ang, length=8):
    a = math.radians(ang)
    rig.blade(cv, hx, hy, ang, length, 2.4, edge=STEEL, start=1.5, tip_taper=2)
    gx, gy = hx + 1.2 * math.cos(a), hy + 1.2 * math.sin(a)
    rig.bar(cv, gx + 1.5 * math.sin(a), gy - 1.5 * math.cos(a), ang + 90, 3, "amber4", width=1.2)
    cv.put(round(hx - 2 * math.cos(a)), round(hy - 2 * math.sin(a)), "amber5")


def arm(cv, sh, hd, bend=1):
    ex = (sh[0] + hd[0]) / 2 - bend
    ey = max(sh[1], hd[1]) + 1 if hd[1] > sh[1] - 3 else (sh[1] + hd[1]) / 2 + 1
    rig.limb(cv, [sh, (ex, ey)], 1.4, SLEEVE)
    rig.limb(cv, [(ex, ey), hd], 1.4, WRAP)
    rig.blob(cv, hd[0], hd[1], 1.3, 1.3, GLOVE)


def down_pose(stage):
    """Curled on her side facing us: mantle pooled, scarf spilled, knees drawn up."""
    cv = Canvas(*SIZE)
    lift = 1 if stage == 1 else 0
    rig.blob(cv, 26, 58 - lift, 14, 2.4, MANTLE_RAMP, sep=False)
    rig.ribbon(cv, 18, 56 - lift, 12, 0.3, SCARF_RAMP, amp=0.8, wave=10, droop=0.15, r0=1.3, r1=0.9)
    for hip, knee, foot in (((33, 54), (39, 49 + lift), (42, 57)), ((34, 55), (41, 53 + lift), (45, 58))):
        rig.limb(cv, [(hip[0], hip[1] - lift), knee], 1.9, TIGHTS)
        rig.limb(cv, [knee, (foot[0], foot[1] - 1)], 1.5, BANDAGE)
        rig.limb(cv, [(foot[0] - 1, foot[1] - 1), (foot[0] + 2, foot[1])], 1.3, BOOTS)
    cv.stamp(TORSO.rot90(3), 24, 47 - lift, sep=True)
    cv.stamp(HEAD_DOWN.rot90(3), 13, 45 - lift, sep=True)
    rig.limb(cv, [(26, 49 - lift), (30, 53 - lift), (34, 51 - lift)], 1.4, SLEEVE)
    rig.blob(cv, 34, 51 - lift, 1.3, 1.3, GLOVE)
    dagger(cv, 47, 58, 4, 7)
    dagger(cv, 9, 58, 176, 7)
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
    kb, cr, ry = p["kb"], p["crouch"], p["ry"]
    L = rig.Lean(SIZE, 46 + cr + ry, p["lean"])
    torso, (tdx, tdy) = TORSOS[p["torso"]]
    ux, uy = kb, cr + ry
    sh_b = L.p((29 + ux + tdx, 38 + uy + tdy))
    sh_f = L.p((34 + ux + tdx, 38 + uy + tdy))
    fh = L.p((p["hand"][0] + ux, p["hand"][1] + uy))
    bh = L.p((p["back"][0] + ux, p["back"][1] + uy)) if p["back"] else None
    hd = L.dx(30 + uy + tdy)
    if p["smear"]:
        rig.arc(L.back, 36 + ux + L.dx(43 + uy), 43 + uy, 9, 16, *p["smear"], SMEAR)
    if p["smear2"]:
        rig.arc(L.back, 35 + ux + L.dx(41 + uy), 41 + uy, 8, 14, *p["smear2"], SMEAR)
    ph = p["tails"] / 6.0
    lift = p["wind"]
    rig.ribbon(L.back, 28 + ux + tdx, 36 + uy + tdy, 15 + lift, ph, SCARF_RAMP, amp=1.6, wave=13,
               droop=0.32 - 0.05 * lift, r0=1.7, r1=1.1)
    L.back.stamp(MANTLE, ux + tdx, uy + tdy)
    if bh:
        dagger(L.back_rigid, bh[0], bh[1], p["bang"], 7)
        arm(L.back_rigid, sh_b, bh, 0)
    else:
        arm(L.back_rigid, sh_b, (sh_b[0] - 1, sh_b[1] + 8), 1)
    stance = []
    for hip, knee, ank, toe in LEGS[p["legs"]]:
        stance.append(((hip[0] + kb, hip[1] + cr + ry), (knee[0] + kb // 2, knee[1] + (cr + ry) // 2), (ank[0], ank[1] + min(0, ry)), (toe[0], toe[1] + min(0, ry))))
    rig.legs(L.legs, stance, 0, 0, TIGHTS, BANDAGE, BOOTS, 2.0, 1.6)
    L.body.stamp(torso, ux, uy, sep=True)
    L.head.stamp(HEADS[(p["face"], p["hood"])], ux + tdx + hd, uy + tdy, sep=True)
    L.head.stamp(SCARF, ux + tdx + hd, uy + tdy, sep=True)
    dagger(L.front_rigid, fh[0], fh[1], p["fang"])
    arm(L.front_rigid, sh_f, fh)
    L.compose(cv)
    cv.rim(-1, 1, 0, 56)
    if p["knives"]:
        for (kx, ky) in p["knives"]:
            for i in range(6):
                c = "ink10" if i == 0 else ("ink8" if i < 3 else "violet3")
                cv.put(kx - i, ky, c)
            cv.put(kx + 1, ky, "ink9")
    cv.outline()
    if p["flash"]:
        cv = flash(cv)
    return cv


def _idle():
    out = []
    breath = ["idle", "idle", "rise", "rise", "rise", "idle"]
    bounce = [1, 1, 1, 2, 2, 1]
    for i in range(12):
        out.append(({"torso": breath[i % 6], "crouch": bounce[i % 6], "hood": [0, 1, 0, 2][i % 4],
                     "tails": i % 6 if False else (i * 6 // 4) % 6, "face": "blink" if i == 7 else "idle",
                     "hand": (40, 45) if i % 6 < 3 else (40, 46), "fang": -25 if i % 6 < 3 else -22}, 1))
    return out


IDLE = _idle()

ATTACK = seq(
    ({"crouch": 3, "lean": -3, "legs": "low", "torso": "twist", "face": "strain", "hand": (34, 45), "fang": 160,
      "back": (30, 41), "bang": -110, "tails": 1, "hood": 1}, 2),
    ({"crouch": 2, "lean": 3, "kb": 2, "legs": "dash", "torso": "open", "face": "fierce", "hand": (41, 41), "fang": -60,
      "back": (34, 41), "bang": -80, "smear": (-125, -40), "tails": 2, "wind": 4, "hood": 2}, 1),
    ({"crouch": 2, "lean": 5, "kb": 3, "legs": "dash", "torso": "open", "face": "fierce", "hand": (45, 46), "fang": 15,
      "back": (34, 41), "bang": -80, "smear": (-110, 40), "tails": 3, "wind": 5, "hood": 2}, 2),
    ({"crouch": 3, "lean": 5, "kb": 3, "legs": "dash", "torso": "twist", "face": "fierce", "hand": (39, 49), "fang": 70,
      "back": (43, 40), "bang": -10, "smear2": (-160, -10), "tails": 4, "wind": 4, "hood": 1}, 2),
    ({"crouch": 2, "lean": 2, "kb": 1, "ry": -3, "legs": "tuck", "torso": "idle", "face": "strain", "hand": (39, 44),
      "fang": -30, "back": (34, 39), "tails": 5, "wind": 2, "hood": 0}, 1),
    ({"crouch": 3, "lean": 0, "legs": "low", "torso": "hunch", "face": "idle", "hand": (40, 46), "fang": -25, "tails": 0, "hood": 1}, 2),
    ({"crouch": 1, "lean": 0, "torso": "rise", "tails": 1, "hood": 0}, 1),
)

CAST = seq(
    ({"crouch": 3, "lean": -3, "legs": "low", "torso": "twist", "face": "strain", "hand": (30, 41), "fang": -150,
      "back": (30, 42), "bang": -120, "tails": 1, "hood": 1}, 2),
    ({"crouch": 2, "lean": 3, "legs": "low", "torso": "open", "face": "fierce", "hand": (43, 39), "fang": -10,
      "back": (31, 41), "tails": 2, "wind": 2, "hood": 2, "knives": [(48, 36), (50, 39), (47, 42)]}, 1),
    ({"crouch": 2, "lean": 4, "legs": "low", "torso": "open", "face": "fierce", "hand": (44, 40), "fang": 0,
      "back": (31, 41), "tails": 3, "wind": 2, "hood": 2, "knives": [(56, 35), (58, 39), (55, 43)]}, 1),
    ({"crouch": 2, "lean": 3, "legs": "ready", "torso": "idle", "face": "strain", "hand": (43, 41), "fang": 0,
      "back": (31, 41), "tails": 4, "hood": 1, "knives": [(63, 34), (63, 39), (62, 44)]}, 2),
    ({"crouch": 1, "lean": 0, "torso": "rise", "hand": (40, 45), "tails": 5, "hood": 0}, 1),
)

HIT = seq(
    ({"kb": -2, "lean": -3, "torso": "hunch", "face": "hurt", "hand": (38, 43), "fang": -60, "tails": 3, "wind": 3, "hood": 2, "flash": True}, 1),
    ({"kb": -2, "crouch": 2, "lean": -4, "torso": "hunch", "face": "hurt", "hand": (37, 44), "fang": -70, "back": (32, 41), "tails": 4, "wind": 2, "hood": 2}, 2),
    ({"kb": -1, "crouch": 2, "lean": -2, "face": "hurt", "hand": (39, 45), "tails": 5, "hood": 1}, 1),
    ({"lean": -1, "face": "blink", "tails": 0}, 1),
)

KO = seq(
    ({"kb": -2, "lean": -4, "torso": "hunch", "face": "hurt", "hand": (37, 43), "fang": -70, "tails": 3, "wind": 3, "flash": True}, 1),
    ({"kb": -3, "crouch": 4, "lean": -3, "legs": "low", "torso": "hunch", "face": "hurt", "hand": (37, 47), "fang": 80, "back": None, "tails": 2}, 2),
    ({"kb": -2, "crouch": 6, "lean": 4, "legs": "kneel", "torso": "hunch", "face": "hurt", "hand": (39, 50), "fang": 80, "back": None, "tails": 1}, 3),
    ({"down": 1}, 1),
    ({"down": 2}, 4),
)

ANIMS = [
    {"name": "idle", "fps": 8, "loop": True, "frames": IDLE},
    {"name": "attack", "fps": 14, "loop": False, "frames": ATTACK, "events": {"impact": 2}},
    {"name": "cast", "fps": 12, "loop": False, "frames": CAST, "events": {"impact": 3}},
    {"name": "hit", "fps": 12, "loop": False, "frames": HIT},
    {"name": "ko", "fps": 10, "loop": False, "frames": KO},
]
