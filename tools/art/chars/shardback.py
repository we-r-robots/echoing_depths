"""Shardback: a grey vault-beast, half eaten by the Fading, whose back has
grown a ridge of Crystal of Remembrance. Charges with its stone brow; its
crystals flare when it calls the Vault's memory; when it dies they go grey."""
import math
from pixlib import Canvas, Part, flash, tint
import rig
from rig import seq

NAME = "shardback"
MONSTER = True
SIZE = (64, 64)
ORIGIN = (32, 60)

HL = {"U": "ink3", "V": "ink5", "W": "fade2", "X": "fade3"}
HEAD = Part("""
...44.........
..4554........
.356665WWW....
.35WWWWWWWXW..
3VWWWWWWWWWXW.
3VW#LWWWWWWWXW
UVWW#WWWWWWWWX
UVVWWWWWWWVV43
.UVVWWWWWV9V3.
.UUVVVVVV99U..
..UUUUUU9.....
""", at=(38, 35), legend=HL)

HEAD_HURT = Part("""
...44.........
..4554........
.356665WWW....
.35WWWWWWWXW..
3VWWWWWWWWWXW.
3VW##WWWWWWWXW
UVWWLWWWWWWWWX
UVVWWWWWWWVV43
.UVVWWWWWV9V3.
.UUVVVVVV99U..
..UUUUUU9.....
""", at=(38, 35), legend=HL)

HEAD_DEAD = Part("""
...44.........
..4554........
.356665WWW....
.35WWWWWWWXW..
3VWWWWWWWWWXW.
3VW##WWWWWWWXW
UVWWUWWWWWWWWX
UVVWWWWWWWVV43
.UVVWWWWWV9V3.
.UUVVVVVV99U..
..UUUUUU9.....
""", at=(38, 35), legend=HL)

HIDE = ("ink3", "ink5", "fade2", "fade3")
LEGC = ("ink2", "ink4", "ink5", "fade2")
HOOF = ("ink2", "ink3", "ink4", "ink5")
GREY = ("fade1", "fade2", "fade3", "fade4", "fade4")

# back-ridge crystals: (x, y on the back, angle, length, width)
CRYSTALS = [(20, 40, -150, 9, 4), (24, 37, -120, 13, 5), (30, 35, -100, 16, 6), (36, 36, -75, 11, 5), (40, 39, -55, 7, 4)]

POSE = dict(rx=0, ry=0, by=0, hdx=0, hdy=0, legs="stand", grow=0, glint=0, glow=0, tail=0,
            head="normal", flash=False, streak=0, spikes=None, dead=0, grey=False)

# leg sets: (hip, knee, foot) back-far, front-far, back-near, front-near
LEGS = {
    "stand": [((22, 47), (21, 52), (21, 57)), ((37, 47), (38, 52), (38, 57)),
              ((25, 48), (24, 53), (24, 58)), ((40, 48), (41, 53), (41, 58))],
    "brace": [((22, 47), (19, 52), (17, 57)), ((37, 47), (40, 52), (41, 57)),
              ((25, 48), (22, 53), (20, 58)), ((40, 48), (43, 53), (44, 58))],
    "run": [((22, 47), (18, 51), (14, 54)), ((37, 47), (42, 51), (45, 55)),
            ((25, 48), (21, 52), (18, 57)), ((40, 48), (45, 52), (48, 57))],
    "fold": [((22, 52), (18, 56), (16, 58)), ((37, 52), (42, 56), (44, 58)),
             ((25, 53), (21, 57), (18, 58)), ((40, 53), (45, 57), (47, 58))],
}


def body(cv, cx, cy, grey, ph=0):
    rig.blob(cv, cx - 7, cy + 1, 8.5, 6.5, HIDE, light=(0.5, -0.85), sep=False)   # haunch
    rig.blob(cv, cx + 4, cy - 1, 10, 8, HIDE, light=(0.5, -0.85), sep=False)      # shoulders
    # shaggy belly fringe
    for x in range(cx - 13, cx + 12):
        depth = 6 if x > cx - 4 else 5
        base = cy + depth + (1 if x > cx - 4 else 0)
        if (x + ph) % 3 == 0:
            cv.put(x, base + 1, "ink3")
            cv.put(x, base, "ink3")
        else:
            cv.put(x, base, "ink3")
            cv.put(x, base - 1, "ink4")
    # stone plates on the flank
    for (dx, dy, c) in ((-6, 0, "ink5"), (-5, 0, "ink5"), (-4, -1, "fade2"), (1, 2, "ink5"), (2, 2, "ink5"),
                        (3, 1, "fade2"), (7, -4, "fade4"), (8, -4, "fade4"), (9, -3, "fade4"), (-9, 2, "ink4")):
        cv.put(cx + dx, cy + dy, c)
    # the Fading eating at its rump: specks peeling off backwards
    for i, (dx, dy) in enumerate(((-16, -1), (-18, 2), (-15, 4), (-20, 0), (-17, -3))):
        k = (ph + i) % 4
        cv.put(cx + dx - k, cy + dy - (k // 2), "fade3" if k < 2 else "fade2")


def render(params):
    p = dict(POSE)
    p.update(params)
    cv = Canvas(*SIZE)
    rx, ry = p["rx"], p["ry"]
    by = ry + p["by"]
    legs = LEGS[p["legs"]]
    o = lambda q, d=0: (q[0] + rx, q[1] + ry + d)
    # far legs
    for hip, knee, foot in legs[:2]:
        rig.limb(cv, [o(hip, p["by"]), o(knee)], 2.5, ("ink2", "ink3", "fade1", "fade1"))
        rig.limb(cv, [o(knee), o(foot)], 1.9, ("ink2", "ink3", "fade1", "fade1"))
    # tail
    tx, ty = 17 + rx, 42 + by
    rig.limb(cv, [(tx, ty), (tx - 3, ty - 2 + p["tail"]), (tx - 5, ty - 1 + 2 * p["tail"])], 1.2, HIDE)
    rig.crystal(cv, tx - 5, ty - 1 + 2 * p["tail"], -160, 4, 3, GREY if p["grey"] else
                ("crystal2", "crystal3", "crystal4", "crystal5", "ink10"))
    ramp = GREY if p["grey"] else ("crystal2", "crystal3", "crystal4", "crystal5", "ink10")
    # crystals behind the body edge
    for i, (x, y, a, L, w) in enumerate(CRYSTALS):
        Lg = L + p["grow"] * (2 if i in (1, 2, 3) else 1)
        rig.crystal(cv, x + rx, y + by + 2, a, Lg, w, ramp)
    body(cv, 31 + rx, 44 + by, p["grey"], p.get("ph", 0))
    # near legs
    for hip, knee, foot in legs[2:]:
        rig.limb(cv, [o(hip, p["by"]), o(knee)], 2.8, LEGC)
        rig.limb(cv, [o(knee), o(foot)], 2.1, LEGC)
        rig.limb(cv, [(o(foot)[0] - 1, o(foot)[1]), (o(foot)[0] + 1, o(foot)[1])], 1.0, HOOF)
    h = {"normal": HEAD, "hurt": HEAD_HURT, "dead": HEAD_DEAD}[p["head"]]
    cv.stamp(h, rx + p["hdx"], by + p["hdy"], sep=True)
    rig.crystal(cv, 44 + rx + p["hdx"], 37 + by + p["hdy"], -35 - 3 * p["hdy"], 9 + p["grow"], 4, ramp)
    # glints travelling along the ridge
    if p["glint"] and not p["grey"]:
        x, y, a, L, w = CRYSTALS[p["glint"] - 1]
        ar = math.radians(a)
        gx, gy = round(x + rx + (L - 2) * math.cos(ar)), round(y + by + 2 + (L - 2) * math.sin(ar))
        rig.sparkle(cv, gx, gy, 2, "ink10", "crystal5")
    if p["glow"]:
        for i, (x, y, a, L, w) in enumerate(CRYSTALS):
            ar = math.radians(a)
            Lg = L + p["grow"] * (2 if i in (1, 2, 3) else 1)
            gx, gy = round(x + rx + (Lg + 2) * math.cos(ar)), round(y + by + 2 + (Lg + 2) * math.sin(ar))
            if i % 2 == p["glow"] % 2:
                rig.sparkle(cv, gx, gy, 1 + (p["glow"] > 1), "ink10", "crystal5")
    if p["streak"]:
        for i, yy in enumerate((38, 44, 50)):
            for k in range(p["streak"] - 2 * (i == 1)):
                cv.put(14 + rx - k - 3 * i, yy + ry, "fade3" if k < 3 else "fade2")
    if p["spikes"]:
        for (sx, sy, L) in p["spikes"]:
            rig.crystal(cv, sx, sy, -90, L, 4)
    cv.rim(-1, 1, 0, 56, color="crystal3", skip=("ink1", "LINE", "crystal2", "crystal3", "crystal4", "crystal5", "ink10"))
    cv.outline()
    if p["flash"]:
        cv = flash(cv)
    return cv


IDLE = seq(
    ({"ph": 0, "by": 0, "tail": 0, "glint": 0}, 1),
    ({"ph": 1, "by": 0, "tail": 1, "glint": 1, "hdy": 0}, 1),
    ({"ph": 2, "by": 1, "tail": 1, "glint": 2, "hdy": 0}, 1),
    ({"ph": 3, "by": 1, "tail": 0, "glint": 3, "hdy": 1}, 1),
    ({"ph": 4, "by": 1, "tail": -1, "glint": 4, "hdy": 1}, 1),
    ({"ph": 5, "by": 0, "tail": -1, "glint": 5, "hdy": 1}, 1),
    ({"ph": 6, "by": 0, "tail": 0, "glint": 0, "hdy": 0}, 1),
    ({"ph": 7, "by": 0, "tail": 1, "glint": 0, "hdy": 0}, 1),
)

ATTACK = seq(
    ({"rx": -2, "by": 1, "legs": "brace", "hdx": -1, "hdy": 2, "tail": 1}, 1),
    ({"rx": -4, "by": 2, "legs": "brace", "hdx": -1, "hdy": 3, "tail": 2}, 2),
    ({"rx": 5, "by": 0, "legs": "run", "hdx": 1, "hdy": 2, "streak": 8, "tail": -1}, 1),
    ({"rx": 8, "by": -1, "legs": "run", "hdx": 2, "hdy": -2, "streak": 4, "tail": -2}, 2),
    ({"rx": 6, "by": 0, "legs": "brace", "hdx": 1, "hdy": 0, "tail": 0}, 1),
    ({"rx": 3, "by": 0, "legs": "stand", "tail": 1}, 2),
)

CAST = seq(
    ({"by": 1, "legs": "brace", "hdy": 1, "glow": 1}, 1),
    ({"by": 2, "legs": "brace", "hdy": 2, "grow": 1, "glow": 2}, 1),
    ({"by": 2, "legs": "brace", "hdy": 2, "grow": 2, "glow": 3}, 2),
    ({"by": -1, "ry": -2, "legs": "stand", "hdy": -2, "grow": 3, "glow": 2}, 1),
    ({"by": 2, "legs": "brace", "hdy": 1, "grow": 1, "spikes": [(50, 59, 8), (55, 59, 12), (60, 59, 7)]}, 2),
    ({"by": 1, "legs": "stand", "grow": 0, "spikes": [(55, 59, 5), (60, 59, 3)]}, 1),
    ({"by": 0, "legs": "stand"}, 1),
)

HIT = seq(
    ({"rx": -3, "by": 1, "legs": "brace", "hdx": -3, "hdy": -2, "head": "hurt", "flash": True, "tail": 2}, 1),
    ({"rx": -4, "by": 2, "legs": "brace", "hdx": -3, "hdy": -1, "head": "hurt", "tail": 2, "grow": -1}, 2),
    ({"rx": -2, "by": 1, "legs": "brace", "hdx": -1, "hdy": 1, "head": "hurt", "tail": 1}, 1),
    ({"rx": -1, "hdy": 0, "tail": 0}, 1),
)

KO = seq(
    ({"rx": -3, "hdx": -2, "hdy": -1, "head": "hurt", "flash": True, "tail": 2}, 1),
    ({"rx": -3, "by": 2, "hdx": -1, "hdy": 3, "head": "hurt", "tail": 1, "legs": "brace"}, 2),
    ({"rx": -3, "by": 5, "ry": 0, "hdy": 6, "head": "hurt", "legs": "fold", "tail": 0}, 2),
    ({"rx": -3, "by": 7, "hdy": 8, "head": "dead", "legs": "fold", "tail": 0, "grey": True}, 2),
    ({"rx": -3, "by": 7, "hdy": 8, "head": "dead", "legs": "fold", "tail": 0, "grey": True}, 4),
)

ANIMS = [
    {"name": "idle", "fps": 7, "loop": True, "frames": IDLE},
    {"name": "attack", "fps": 14, "loop": False, "frames": ATTACK, "events": {"impact": 3}},
    {"name": "cast", "fps": 12, "loop": False, "frames": CAST, "events": {"impact": 4}},
    {"name": "hit", "fps": 12, "loop": False, "frames": HIT},
    {"name": "ko", "fps": 10, "loop": False, "frames": KO},
]
