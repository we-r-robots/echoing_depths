"""Fighter: young crimson-caped swordsman with a two-handed blade.

Every key pose is a whole-body pose: torso variant (twist / open chest / hunch /
drawn shoulder rise), expression head, cape shape, crouch, and a lean that
shears the whole upper body around the hip. Hair, cape and headband tails run
on their own cycles in idle.
"""
import math
from pixlib import Canvas, Part, flash
import rig
from rig import seq, edited

NAME = "fighter"
SIZE = (64, 64)
ORIGIN = (32, 60)

HEAD_BASE = """
.......AB.......
....A.ABCB.AB...
...ABBBCCCBBCB..
..ABCCCCDDCCCB..
AABCCCCDDDDCCCB.
.ABCCCCCCDDDCCCB
..ABQRRRRRRSSSTA
.AABQRRRRSSSSTTA
AABCCBCBCcCDcCB.
.ABCBbb1cc81cd..
..ABBab1cc81cc..
..AABabbcccccdc.
...AAabbbcccb...
.....aabbbb.....
"""
HAT = (24, 21)
FACES = {
    "idle": {},
    "blink": {9: ".ABCBbbccccccd..", 10: "..ABBab1cc11cc.."},
    "strain": {9: ".ABCBbb1cc81cd..", 12: "...AAabbbc91b..."},
    "fierce": {8: "AABCCBCBC1CD1CB.", 9: ".ABCBbb1cc11cd..", 10: "..ABBabccccccc..", 12: "...AAabbbcQ1b..."},
    "hurt": {9: ".ABCBb1bcc1bcd..", 10: "..ABBab1cc1ccc..", 11: "..AABabbccccc1c.", 12: "...AAabbbcQQb..."},
}
HAIRS = [
    {},
    {0: "......AB........", 1: "...A..ABCB.AB..."},
    {0: "......AB........", 1: "...A.ABCB..AB..."},
    {1: "....A.ABCB..AB..", 2: "...ABBBCCCBBCBB."},
]
HEADS = {}
for _f, _e in FACES.items():
    for _h, _he in enumerate(HAIRS):
        HEADS[(_f, _h)] = edited(HEAD_BASE, {**_he, **_e}, at=HAT)

# frontal face, eyes shut: used lying on the floor in the KO pose
HEAD_DOWN = Part("""
.....ABBA.....
..A.ABCCBA.A..
..ABBCCDCBBA..
.ABCCDDDDCCBA.
.ABCDDDDDDCBA.
ABQRRRRRRRRSBA
ABQRRSSSSRRSTA
ABCcCcDDcCcCBA
.Bbcccccccccb.
.Bb11cccc11cb.
.Bbccccccccb..
..abbcbbcbba..
...aabbbbaa...
""")

TORSO = Part("""
.....bcc.....
....3abc3....
..R345678ST..
.QR3567899ST.
.QR3567899ST.
.QR356789ST..
.QR34567SST..
.QRR34556ST..
..ABBCEDCBA..
..Q46RS68ST..
..Q46RS67SR..
.QQ35RS46SR..
.Q..QR..RS...
""", at=(25, 34))

CAPES = [Part(g, at=(18, 35)) for g in ("""
........QRR...
.......QRRR...
......QRRSR...
.....QRRRSR...
.....QRRSR....
....QRRRSR....
....QRRSRR....
...QRRRSR.....
...QRRSRR.....
..QRRRSR......
..QRRSRR......
..QQRRR.......
...QQR........
""", """
........QRR...
.......QRRR...
......QRRSR...
.....QRRRSR...
....QRRRSR....
....QRRSRR....
...QRRRSR.....
...QRRSRR.....
..QRRRSR......
..QRRSRR......
.QRRRSR.......
.QQRRR........
..QQ..........
""", """
........QRR...
.......QRRR...
......QRRSR...
.....QRRRSR...
....QRRRSR....
...QRRRSRR....
...QRRSRR.....
..QRRRSR......
..QRRSRR......
.QRRRSR.......
QQRRSR........
.QQRR.........
..............
""", """
........QRR...
.......QRRR...
.....QQRRSR...
....QRRRRSR...
...QRRRRSR....
..QRRRSRRR....
.QRRRSRRR.....
QRRRSRRR......
QRRSRRR.......
.QQRRR........
..QQ..........
..............
..............
""")]

PAULDRON = Part("""
.4678.
4678999
356789.
.3456.
""", at=(33, 35))

TAILS = [Part(g, at=(19, 27)) for g in ("""
.QRR.
QRR..
.QR..
""", """
..QR.
QRRR.
Q....
""", """
.....
QQRR.
.QR..
""", """
QQRR.
..QR.
.....
""")]

PANTS = ("amber1", "amber2", "amber3", "amber3")
GREAVE = ("ink4", "ink6", "ink8", "ink9")
SKIN = ("skin1", "skin2", "skin3", "skin4")
BOOTS = ("amber1", "amber2", "amber3", "amber4")
GAUNT = ("ink4", "ink6", "ink8", "ink9")
STEEL = ("ink5", "ink7", "ink9", "ink10")
SMEAR = ("ink6", "ink8", "ink9", "ink10", "ink10")
CAPE_RAMP = ("blood1", "blood2", "blood3", "blood4")

# torso key drawings derived from the base: turned away (narrow, in shadow),
# chest opened to the viewer (wide, lit), hunched (shorter, shadowed), and a
# drawn shoulder rise (chest row repeated). Head/shoulder offsets follow each.
TORSOS = {
    "idle": (TORSO, (0, 0)),
    "rise": (TORSO.stretched(3), (0, -1)),
    "twist": (TORSO.narrowed(6).shaded(-1), (-1, 0)),
    "open": (TORSO.widened(6).shaded(1, only=("ink", "blood")), (1, 0)),
    "hunch": (TORSO.squashed(4).shaded(-1), (0, 1)),
}

LEGS = {
    "ready": (((30, 46), (26, 52), (24, 57), (27, 58)), ((35, 46), (39, 51), (40, 57), (43, 58))),
    "crouch": (((30, 46), (25, 51), (23, 57), (26, 58)), ((35, 46), (40, 50), (41, 57), (44, 58))),
    "lunge": (((30, 46), (24, 51), (20, 57), (23, 58)), ((35, 46), (41, 50), (43, 57), (46, 58))),
    "kneel": (((30, 46), (27, 53), (22, 58), (24, 58)), ((35, 46), (41, 47), (41, 57), (44, 58))),
}

POSE = dict(kb=0, crouch=0, lean=0, legs="ready", torso="idle", face="idle", hair=0, sw=-50, hand=(39, 44),
            back=(37, 46), cape=0, tails=0, smear=None, fx=None, flash=False, down=0)


def sword(cv, hx, hy, ang, length=21):
    a = math.radians(ang + 180)
    rig.bar(cv, hx, hy, ang + 180, 3, "amber2", width=2)
    cv.put(round(hx + 3.6 * math.cos(a)), round(hy + 3.6 * math.sin(a)), "amber5")
    if math.sin(math.radians(ang)) > 0.5:
        length = min(length, (58 - hy) / math.sin(math.radians(ang)))
    rig.blade(cv, hx, hy, ang, length, 4, edge=STEEL, start=2.5, tip_taper=3 if length > 15 else 0.01)
    a = math.radians(ang)
    gx, gy = hx + 2 * math.cos(a), hy + 2 * math.sin(a)
    rig.bar(cv, gx + 2.5 * math.sin(a), gy - 2.5 * math.cos(a), ang + 90, 5, "amber4", width=1.6)


def arm(cv, sh, el, hd):
    rig.limb(cv, [sh, el], 1.5, SKIN)
    rig.limb(cv, [el, hd], 1.5, GAUNT)
    rig.blob(cv, hd[0], hd[1], 1.4, 1.4, GAUNT)


def down_pose(stage):
    """Collapsed on the floor: on his back with knees drawn up, head rolled toward
    the camera, cape pooled under him, sword dropped. stage 1 = still settling."""
    cv = Canvas(*SIZE)
    lift = 1 if stage == 1 else 0
    # pooled cape
    rig.blob(cv, 27, 58 - lift, 15, 2.6, CAPE_RAMP, sep=False)
    for x, c in ((15, "blood2"), (19, "blood1"), (24, "blood2"), (31, "blood1"), (37, "blood2")):
        cv.put(x, 57 - lift, c)
    cv.put(12, 56 - lift, "blood3"); cv.put(13, 57 - lift, "blood3"); cv.put(11, 57 - lift, "blood2")
    # far arm flopped on the floor behind the head
    rig.limb(cv, [(23, 54 - lift), (18, 57 - lift), (13, 58 - lift)], 1.4, SKIN)
    rig.blob(cv, 12, 58 - lift, 1.4, 1.2, GAUNT)
    # legs: knees up, boots planted
    for hip, knee, foot in (((34, 54), (39, 47 + lift), (43, 57)), ((35, 55), (42, 51 + lift), (47, 58))):
        rig.limb(cv, [(hip[0], hip[1] - lift), knee], 2.0, PANTS)
        rig.limb(cv, [knee, (foot[0], foot[1] - 1)], 1.6, GREAVE)
        rig.limb(cv, [(foot[0] - 1, foot[1] - 1), (foot[0] + 2, foot[1])], 1.4, BOOTS)
    torso = TORSO.rot90(3)  # back on the floor, chest up
    cv.stamp(torso, 22, 46 - lift, sep=True)
    cv.stamp(PAULDRON.rot90(3), 22, 47 - lift, sep=True)
    cv.stamp(HEAD_DOWN.rot90(3), 9, 44 - lift, sep=True)
    # near arm across the chest
    rig.limb(cv, [(25, 48 - lift), (29, 52 - lift)], 1.5, SKIN)
    rig.limb(cv, [(29, 52 - lift), (33, 50 - lift)], 1.5, GAUNT)
    rig.blob(cv, 33, 50 - lift, 1.4, 1.4, GAUNT)
    sword(cv, 47, 58, -4, 14)
    return cv


def render(params):
    p = dict(POSE)
    p.update(params)
    if p["down"]:
        cv = down_pose(p["down"])
        cv.rim(-1, 1, 0, 60, color=None)
        cv.outline()
        return cv
    cv = Canvas(*SIZE)
    kb, cr = p["kb"], p["crouch"]
    L = rig.Lean(SIZE, 46 + cr, p["lean"])
    torso, (tdx, tdy) = TORSOS[p["torso"]]
    ux, uy = kb, cr                      # upper body offset from crouch / knockback
    hx, hy = L.p((p["hand"][0] + ux, p["hand"][1] + uy))
    sh_b = L.p((29 + ux + tdx, 37 + uy + tdy))
    sh_f = L.p((35 + ux + tdx, 37 + uy + tdy))
    hd = L.dx(28 + uy + tdy)             # head moves as one piece

    if p["smear"]:
        a0, a1 = p["smear"][:2]
        width = p["smear"][2] if len(p["smear"]) > 2 else 5
        rig.arc(L.back, 35 + ux + L.dx(40 + uy), 40 + uy, 23 - width, 23, a0, a1, SMEAR)
    L.back.stamp(CAPES[p["cape"]], ux + tdx, uy + tdy)
    if p["back"]:
        bkx, bky = L.p((p["back"][0] + ux, p["back"][1] + uy))
        arm(L.back_rigid, sh_b, ((sh_b[0] + bkx) / 2, max(sh_b[1], bky) + 1), (bkx, bky))
    else:
        arm(L.back_rigid, sh_b, (sh_b[0] - 2, sh_b[1] + 5), (sh_b[0] - 1, sh_b[1] + 9))
    stance = []
    for hip, knee, ank, toe in LEGS[p["legs"]]:
        stance.append(((hip[0] + kb, hip[1] + cr), (knee[0] + kb // 2 + (cr > 1) * (1 if knee[0] > 32 else -1), knee[1] + cr // 2), ank, toe))
    rig.legs(L.legs, stance, 0, 0, PANTS, GREAVE, BOOTS)
    L.body.stamp(torso, ux, uy, sep=True)
    sw = p["sw"]
    sw_behind = -200 < sw < -120 or sw > 200
    if sw_behind:
        sword(L.back_rigid, hx, hy, sw)
    L.head.stamp(TAILS[p["tails"]], ux + tdx + hd, uy + tdy)
    L.head.stamp(HEADS[(p["face"], p["hair"])], ux + tdx + hd, uy + tdy, sep=True)
    fr = L.front_rigid
    if not sw_behind:
        sword(fr, hx, hy, sw)
    if p["back"]:
        rig.blob(fr, bkx, bky, 1.4, 1.4, GAUNT)
    ex = (sh_f[0] + hx) / 2 - 1
    ey = max(sh_f[1], hy) + 2 if hy > sh_f[1] - 3 else (sh_f[1] + hy) / 2
    arm(fr, sh_f, (ex, ey), (hx, hy))
    pd = PAULDRON.shaded(-1) if p["torso"] in ("twist", "hunch") else PAULDRON
    fr.stamp(pd, ux + tdx + L.dx(37 + uy), uy + tdy, sep=True)
    L.compose(cv)
    cv.rim(-1, 1, 0, 56)
    fx(cv, p, hx, hy)
    cv.outline()
    if p["flash"]:
        cv = flash(cv)
    return cv


def fx(cv, p, hx, hy):
    k = p["fx"]
    if not k:
        return
    if k.startswith("charge"):
        n = int(k[-1])
        a = math.radians(p["sw"])
        for i, t in enumerate((6, 11, 16, 20)[:n + 1]):
            x, y = round(hx + t * math.cos(a)), round(hy + t * math.sin(a))
            rig.sparkle(cv, x + (2 if i % 2 else -2), y, 1 + (i == n), "amber7", "amber5")
        cv.put(round(hx + 21 * math.cos(a)), round(hy + 21 * math.sin(a)), "amber7")
    if k.startswith("quake"):
        n = int(k[-1])
        for i in range(n + 2):
            x = hx + 4 + i * 3
            cv.put(x, 58 - (i % 2), "amber6" if i < n + 1 else "amber4")
            cv.put(x, 57 - (i % 2) - (i < 2), "amber5")
        rig.sparkle(cv, hx + 1, 55, 2 + n, "amber7", "amber5")


# idle: body breath on a 6-frame cycle (drawn shoulder rise), cape on 4, hair on 3,
# headband tails on 4 offset by 2 -> 12 unique frames, nothing moves in lockstep
def _idle():
    out = []
    breath = ["idle", "idle", "rise", "rise", "rise", "idle"]
    capes = [0, 1, 2, 1]
    for i in range(12):
        out.append(({"torso": breath[i % 6], "cape": capes[i % 4], "hair": [0, 1, 2][i % 3],
                     "tails": (i + 2) % 4, "face": "blink" if i == 9 else "idle",
                     "sw": -50 + (1 if breath[i % 6] == "rise" else 0),
                     "hand": (39, 43) if breath[i % 6] == "rise" else (39, 44)}, 1))
    return out


IDLE = _idle()

ATTACK = seq(
    # anticipation: sink, twist away, blade back over the shoulder, cape lifts
    ({"crouch": 1, "lean": -2, "torso": "twist", "face": "strain", "sw": -125, "hand": (32, 40), "back": (30, 42),
      "cape": 3, "tails": 1, "hair": 1}, 1),
    ({"crouch": 3, "lean": -4, "legs": "crouch", "torso": "twist", "face": "strain", "sw": -160, "hand": (29, 39),
      "back": (28, 41), "cape": 3, "tails": 2, "hair": 2}, 2),
    # strike: uncoil, chest opens to the viewer, thick smear
    ({"crouch": 1, "lean": 2, "kb": 1, "legs": "lunge", "torso": "open", "face": "fierce", "sw": -45,
      "hand": (40, 36), "back": (38, 38), "smear": (-175, -45, 6), "cape": 2, "tails": 3, "hair": 2}, 1),
    # contact, held
    ({"crouch": 2, "lean": 4, "kb": 2, "legs": "lunge", "torso": "open", "face": "fierce", "sw": 28,
      "hand": (42, 45), "back": (40, 46), "smear": (-150, 28, 7), "cape": 3, "tails": 3, "hair": 3}, 2),
    ({"crouch": 3, "lean": 5, "kb": 2, "legs": "lunge", "torso": "open", "face": "fierce", "sw": 58,
      "hand": (41, 48), "back": (39, 48), "smear": (-40, 58, 5), "cape": 3, "tails": 3, "hair": 3}, 2),
    # follow-through: overshoot settles, cape and hair still dragging
    ({"crouch": 2, "lean": 3, "kb": 1, "legs": "lunge", "torso": "idle", "face": "strain", "sw": 40,
      "hand": (41, 47), "back": (39, 47), "cape": 3, "tails": 2, "hair": 3}, 1),
    ({"crouch": 1, "lean": 1, "kb": 1, "legs": "crouch", "torso": "idle", "face": "idle", "sw": -10,
      "hand": (40, 45), "cape": 2, "tails": 1, "hair": 1}, 2),
    ({"crouch": 0, "lean": 0, "torso": "rise", "face": "idle", "sw": -45, "cape": 1, "tails": 0, "hair": 0}, 1),
)

CAST = seq(
    ({"crouch": 1, "lean": -1, "torso": "twist", "face": "strain", "sw": -80, "hand": (37, 38), "back": (35, 40), "cape": 1, "tails": 1}, 1),
    ({"crouch": 0, "lean": -2, "torso": "rise", "face": "fierce", "sw": -90, "hand": (36, 29), "back": (35, 31), "cape": 3, "tails": 2, "hair": 1, "fx": "charge0"}, 1),
    ({"crouch": 0, "lean": -2, "torso": "rise", "face": "fierce", "sw": -90, "hand": (36, 28), "back": (35, 30), "cape": 2, "tails": 3, "hair": 2, "fx": "charge1"}, 1),
    ({"crouch": 0, "lean": -3, "torso": "open", "face": "fierce", "sw": -90, "hand": (36, 28), "back": (35, 30), "cape": 3, "tails": 2, "hair": 1, "fx": "charge2"}, 1),
    ({"crouch": 0, "lean": -3, "torso": "open", "face": "fierce", "sw": -90, "hand": (36, 27), "back": (35, 29), "cape": 2, "tails": 1, "hair": 2, "fx": "charge3"}, 2),
    # plant the blade
    ({"crouch": 4, "lean": 4, "legs": "crouch", "torso": "hunch", "face": "fierce", "sw": 90, "hand": (40, 42), "back": (38, 42), "cape": 3, "tails": 3, "hair": 3, "fx": "quake0"}, 1),
    ({"crouch": 4, "lean": 4, "legs": "crouch", "torso": "hunch", "face": "fierce", "sw": 90, "hand": (40, 42), "back": (38, 42), "cape": 2, "tails": 2, "hair": 3, "fx": "quake2"}, 2),
    ({"crouch": 2, "lean": 1, "torso": "idle", "sw": 20, "hand": (39, 45), "cape": 1, "tails": 1}, 1),
    ({"crouch": 0, "lean": 0, "torso": "rise", "sw": -45, "cape": 0, "tails": 0}, 1),
)

HIT = seq(
    ({"kb": -2, "lean": -3, "torso": "hunch", "face": "hurt", "sw": -35, "hand": (39, 45), "back": (37, 46), "cape": 3, "tails": 3, "hair": 3, "flash": True}, 1),
    ({"kb": -2, "crouch": 1, "lean": -4, "torso": "hunch", "face": "hurt", "sw": -30, "hand": (39, 46), "back": (37, 47), "cape": 3, "tails": 3, "hair": 2}, 2),
    ({"kb": -1, "crouch": 1, "lean": -2, "torso": "idle", "face": "hurt", "sw": -42, "hand": (39, 45), "cape": 2, "tails": 2, "hair": 1}, 1),
    ({"kb": 0, "lean": -1, "face": "blink", "sw": -54, "cape": 1, "tails": 1}, 1),
)

KO = seq(
    ({"kb": -2, "lean": -4, "torso": "hunch", "face": "hurt", "sw": -35, "hand": (39, 45), "back": (37, 46), "cape": 3, "hair": 3, "flash": True}, 1),
    ({"kb": -3, "crouch": 3, "lean": -3, "legs": "crouch", "torso": "hunch", "face": "hurt", "sw": 20, "hand": (39, 47), "back": None, "cape": 3, "hair": 2}, 2),
    ({"kb": -2, "crouch": 6, "lean": 4, "legs": "kneel", "torso": "hunch", "face": "hurt", "sw": 100, "hand": (39, 44), "back": None, "cape": 1, "hair": 1}, 3),
    ({"down": 1}, 1),
    ({"down": 2}, 4),
)

ANIMS = [
    {"name": "idle", "fps": 8, "loop": True, "frames": IDLE},
    {"name": "attack", "fps": 12, "loop": False, "frames": ATTACK, "events": {"impact": 3}},
    {"name": "cast", "fps": 12, "loop": False, "frames": CAST, "events": {"impact": 5}},
    {"name": "hit", "fps": 12, "loop": False, "frames": HIT},
    {"name": "ko", "fps": 10, "loop": False, "frames": KO},
]
