"""Faded Warden: a Lumari guardian construct still keeping a vault nobody
remembers. Porcelain helm with a crystal slit, a halo, floating pauldrons and a
cracked crystal heart; its robes are being unwritten by the Fading."""
import math
from pixlib import Canvas, Part, flash
import rig
from rig import seq

NAME = "warden"
MONSTER = True
SIZE = (96, 80)
ORIGIN = (40, 76)  # frame is wider on the attack side; feet point stays at x=40

HELM = Part("""
......67......
.....5778.....
....567w89....
...4567w899...
..4456w88999..
..3456w89999..
..34567#99#9..
..3456788L9L..
..345678K99K..
..34567889J9..
..3456788999..
..345678899#..
...34567889...
...3345678....
....33456.....
.....345......
""")

HELM_HURT = Part("""
......67......
.....5778.....
....567w89....
...4567w899...
..4456w88999..
..3456w89999..
..34567##9##..
..3456w88K9K..
..345w78J99J..
..34567889J9..
..3456788999..
..34567889#Q..
...34567889...
...3345678....
....33456.....
.....345......
""")

HELM_DEAD = Part("""
......67......
.....5778.....
....567w89....
...4567w899...
..4456w88999..
..3456w89999..
..34567#99#9..
..3456w8839399
..345w7839939.
..34567889J9..
..3456788999..
..345678899#..
...34567889...
...3345678....
....33456.....
.....345......
""")

VEIL = Part("""
....vwwxxw....
..vvwwxxxxw...
.vvwwwxxxxxw..
vvwwwxxxxxxwx.
vvwwxxxxxxxwx.
vvwwxxxxxxxxw.
vvwwxxxxxxxxw.
vvwwxxxxxxxxxw
vvvwwxxxxxxxxw
.vvwwxxxxxxxw.
.vvwwwxxxxxxw.
..vvwwxxxxxw..
..vvvwwxxxw...
...vvwwxxw....
...vvvwwv.....
....vvv.......
""")

STONE = ("ink3", "ink5", "fade3", "fade4")   # indigo shadows -> neutral light
PAUL = ("ink4", "ink6", "fade3", "fade4")
ARM = ("ink2", "ink4", "violet2", "fade3")
CLAW = ("ink5", "ink7", "ink9", "ink10")
ROBE = ("violet1", "violet2", "violet3")
SMEAR = ("violet2", "violet3", "violet4", "ink10")

POSE = dict(bob=0, ph=0.0, rx=0, lean=0, arm=(60, 52), back=(22, 50), claw=60, bclaw=110, heart=1, halo=0.0,
            halo_r=16, helm="normal", flash=False, smear=None, burst=0, crumble=0, robe_sway=0, crack=False, hsnap=0)


def claw(cv, hx, hy, ang, n=3, L=6):
    for i in range(n):
        a = ang + (i - (n - 1) / 2) * 24
        rig.blade(cv, hx, hy, a, L - 2 * abs(i - 1), 2.4, edge=CLAW, start=1.0, tip_taper=4)
    rig.blob(cv, hx, hy, 2.6, 2.6, ARM)


def robe(cv, cx, top, ph, sway, crumble):
    """Tattered robe from the waist down, unravelling into falling fragments."""
    px = {}
    bottom = top + 20 - crumble * 5
    for y in range(top, bottom + 1):
        f = (y - top) / 20
        half = 8 + f * 9
        off = sway * f
        for x in range(int(cx - half + off), int(cx + half + off) + 1):
            # ragged hem: teeth whose length moves with phase
            tooth = 2.5 + 2.5 * math.sin(x * 1.3 + ph * 6.28)
            if y > bottom - tooth:
                continue
            u = (x - (cx - half + off)) / (2 * half)
            c = ROBE[0] if u < 0.28 else (ROBE[1] if u < 0.72 else ROBE[2])
            fold = (x - round(off) - cx) % 5
            if fold == 0 and 0.15 < u < 0.9 and y > top + 2:
                c = ROBE[0] if u < 0.72 else ROBE[1]  # vertical fold shadows
            px[(x, y)] = c
    cv.stamp(Part(None, (0, 0), px=px, size=(0, 0)))
    # fragments drifting down and fading out
    for i in range(7):
        k = (ph * 4 + i * 0.37) % 1.0
        x = round(cx - 13 + i * 4.2 + sway)
        y = round(bottom - 1 + k * 10)
        c = "violet3" if k < 0.35 else ("violet2" if k < 0.7 else "fade2")
        cv.put(x, y, c)
        if k < 0.3:
            cv.put(x + 1, y, "violet2")


def heart(cv, cx, cy, level, dead=False):
    shape = ["..L..", ".KLK.", "JKLKJ", "IJKJI", ".IJI.", "..I.."]
    if dead:
        m = {"L": "fade3", "K": "fade2", "J": "fade2", "I": "fade1"}
    else:
        m = {"L": "ink10" if level > 1 else "crystal5", "K": "crystal5" if level > 0 else "crystal4",
             "J": "crystal4", "I": "crystal3"}
    for y, row in enumerate(shape):
        for x, ch in enumerate(row):
            if ch != ".":
                cv.put(cx - 2 + x, cy - 3 + y, m[ch])
    if level > 1 and not dead:
        rig.sparkle(cv, cx, cy - 1, level, "ink10", "crystal5")


def halo(cv, cx, cy, r, rot, bright):
    """Thin solid ring with travelling crystal beads."""
    n = int(6.28 * r * 1.6)
    beads = {int((rot + k / 4) * n) % n for k in range(4)}
    for i in range(n):
        a = i * 6.28 / n
        x, y = round(cx + r * math.cos(a)), round(cy + r * math.sin(a))
        lit = math.cos(a - 5.5) > 0.3
        c = ("violet4" if bright else "violet3") if lit else "violet2"
        if any(abs(i - b) <= 1 for b in beads):
            c = "crystal5" if bright else "crystal4"
        cv.put(x, y, c)


def render(params):
    p = dict(POSE)
    p.update(params)
    cv = Canvas(*SIZE)  # drawn in 80-wide space; the extra 16px on the right catch swings
    bob = p["bob"]
    cx = 40 + p["rx"]
    cr = p["crumble"]
    L = rig.Lean(SIZE, 50 + bob + cr * 3, p["lean"] if cr < 3 else 0)
    hcx, hcy = cx + 1, 20 + bob + (cr * 9 if cr else 0)
    hd = L.dx(hcy) + p["hsnap"]
    if cr < 2:
        halo(L.back_rigid, hcx - 2 + hd, hcy + 2, p["halo_r"], p["halo"], p["heart"] > 1)
        veil = VEIL.sheared(4, round(math.sin(p["ph"] * 6.28) * 1.5) - p["lean"] // 2)
        L.back.stamp(veil, hcx - 11, hcy - 6)
    sh_b = L.p((cx - 11, 35 + bob + cr * 6))
    bh = L.p((p["back"][0] + p["rx"], p["back"][1] + bob + cr * 6))
    if cr < 3:
        rig.limb(L.back_rigid, [sh_b, ((sh_b[0] + bh[0]) / 2 - 2, (sh_b[1] + bh[1]) / 2 + 2), bh], 2.1, ARM)
        claw(L.back_rigid, bh[0], bh[1], p["bclaw"], 3, 8)
    robe(L.legs, cx, 50 + bob + cr * 3, p["ph"], p["robe_sway"], cr)
    ch_y = 39 + bob + cr * 6
    if cr < 3:
        rig.blob(L.body, cx - 11, 32 + bob + cr * 6 + round(math.sin(p["ph"] * 6.28 + 1)), 6.5, 5, ("ink3", "ink4", "fade2", "fade3"))
    rig.blob(L.body, cx, ch_y, 12, 9.5, STONE, sep=False)
    rig.blob(L.body, cx, ch_y + 10, 8, 4.5, STONE, sep=True)
    for dx in range(-8, 9):
        L.body.put(cx + dx, ch_y + 7, "ink3")
    for dy in range(-7, 7):
        if abs(dy) > 2:
            L.body.put(cx - 4, ch_y + dy, "ink4")
    fr = L.front_rigid
    hx_, hy_ = L.p((cx + 3, ch_y - 1))
    heart(fr, hx_, hy_, p["heart"], dead=cr >= 2)
    if p["crack"]:
        for (dx, dy) in ((5, -4), (6, -5), (7, -5), (1, 2), (0, 3), (-1, 4), (6, 2), (7, 3)):
            fr.put(hx_ - 3 + dx, hy_ + 1 + dy, "violet3")
    helm = {"normal": HELM, "hurt": HELM_HURT, "dead": HELM_DEAD}[p["helm"]]
    hx0, hy0 = hcx - 7 + hd, hcy - 8
    if cr >= 3:
        hx0, hy0 = cx - 4, 55
    cramp = ("crystal2", "crystal3", "crystal4", "crystal5", "ink10") if cr < 2 else ("fade1", "fade2", "fade3", "fade4", "fade4")
    for (dx, dy, a, Ln, w) in ((4, 2, -120, 9, 3), (6, 1, -100, 11, 3), (8, 2, -78, 7, 3)):
        rig.crystal(L.head, hx0 + dx, hy0 + dy, a, Ln, w, cramp)
    L.head.stamp(helm, hx0, hy0, sep=True)
    sh_f = L.p((cx + 10, 34 + bob + cr * 6))
    fh = L.p((p["arm"][0] + p["rx"], p["arm"][1] + bob + cr * 6))
    if p["smear"]:
        rig.arc(L.back, sh_f[0], sh_f[1], 20, 27, *p["smear"], SMEAR)
    if cr < 3:
        el = ((sh_f[0] + fh[0]) / 2 + 2, max(sh_f[1], fh[1]) + 2 if fh[1] > sh_f[1] - 4 else (sh_f[1] + fh[1]) / 2)
        rig.limb(fr, [sh_f, el, fh], 2.3, ARM)
        claw(fr, fh[0], fh[1], p["claw"], 3, 11)
        rig.blob(fr, sh_f[0] + 1, sh_f[1] - 3 + round(math.sin(p["ph"] * 6.28)), 7.5, 5.5, PAUL)
    L.compose(cv)
    if p["burst"]:
        r = 5 + p["burst"] * 6
        for i in range(16):
            a = i * 6.28 / 16
            x, y = round(hx_ + r * math.cos(a)), round(hy_ + r * 0.8 * math.sin(a))
            cv.put(x, y, "violet4" if i % 2 else "crystal5")
            if p["burst"] < 3:
                cv.put(round(hx_ + (r - 2) * math.cos(a)), round(hy_ + (r - 2) * 0.8 * math.sin(a)), "violet3")
    if cr >= 3:
        for (x0, y0, rr) in ((cx - 10, 72, 3), (cx + 9, 72, 3.5), (cx - 3, 73, 2.5), (cx + 15, 73, 2)):
            rig.blob(cv, x0, y0, rr + 1, rr, STONE)
    cv.rim(-1, 1, 8, 50, color="crystal4",
           skip=("ink1", "LINE", "violet1", "violet2", "violet3", "violet4", "crystal2", "crystal3", "crystal4", "crystal5", "ink10"))
    cv.outline()
    if p["flash"]:
        cv = flash(cv)
    return cv


def _idle():
    out = []
    n = 8
    for i in range(n):
        out.append(({"bob": round(-2 * math.sin(i * 6.28 / n)), "ph": i / n, "halo": i / (n * 5),
                     "heart": 2 if i in (0, 1) else 1, "robe_sway": round(math.sin(i * 6.28 / n + 1))}, 1))
    return out


ATTACK = seq(
    ({"lean": -2, "arm": (52, 26), "claw": -80, "ph": 0.1, "halo": 0.02, "bob": -1, "robe_sway": 1}, 1),
    ({"lean": -5, "rx": -1, "arm": (46, 14), "claw": -120, "back": (24, 46), "ph": 0.2, "halo": 0.04, "bob": -3, "robe_sway": 3}, 2),
    ({"lean": 3, "rx": 1, "arm": (66, 28), "claw": -20, "back": (20, 52), "ph": 0.3, "halo": 0.06, "smear": (-120, -20), "bob": 0, "robe_sway": -2}, 1),
    ({"lean": 6, "rx": 2, "arm": (66, 56), "claw": 70, "back": (18, 54), "ph": 0.4, "halo": 0.08, "smear": (-90, 70), "bob": 2, "robe_sway": -4}, 2),
    ({"lean": 6, "rx": 2, "arm": (62, 61), "claw": 90, "back": (18, 54), "ph": 0.5, "halo": 0.1, "bob": 2, "robe_sway": -4}, 2),
    ({"lean": 3, "rx": 1, "arm": (61, 57), "claw": 70, "ph": 0.6, "halo": 0.12, "bob": 1, "robe_sway": -2}, 1),
    ({"lean": 0, "arm": (60, 53), "claw": 60, "ph": 0.7, "halo": 0.14, "bob": 0, "robe_sway": 1}, 2),
)

CAST = seq(
    ({"lean": -1, "arm": (60, 42), "back": (20, 42), "claw": -30, "bclaw": -150, "heart": 2, "ph": 0.1, "halo": 0.02, "robe_sway": 1}, 1),
    ({"lean": -2, "arm": (63, 32), "back": (17, 32), "claw": -60, "bclaw": -120, "heart": 2, "ph": 0.2, "halo": 0.06, "halo_r": 17, "bob": -2, "robe_sway": 2}, 1),
    ({"lean": -3, "arm": (64, 28), "back": (16, 28), "claw": -70, "bclaw": -110, "heart": 3, "ph": 0.3, "halo": 0.1, "halo_r": 18, "bob": -3, "robe_sway": 3}, 2),
    ({"lean": -3, "arm": (65, 26), "back": (15, 26), "claw": -70, "bclaw": -110, "heart": 3, "ph": 0.4, "halo": 0.14, "halo_r": 19, "bob": -3, "burst": 1, "robe_sway": 2}, 1),
    ({"lean": 4, "rx": 1, "arm": (64, 40), "back": (19, 40), "claw": -20, "bclaw": -160, "heart": 2, "ph": 0.5, "halo": 0.18, "halo_r": 18, "bob": -1, "burst": 2, "robe_sway": -3}, 1),
    ({"lean": 3, "arm": (62, 48), "back": (20, 48), "claw": 40, "bclaw": 140, "heart": 1, "ph": 0.6, "halo": 0.2, "halo_r": 17, "burst": 3, "robe_sway": -2}, 2),
    ({"lean": 0, "ph": 0.7, "halo": 0.22, "robe_sway": 0}, 1),
)

HIT = seq(
    ({"rx": -2, "lean": -4, "hsnap": -2, "helm": "hurt", "flash": True, "ph": 0.1, "robe_sway": 3, "arm": (58, 48), "claw": 30}, 1),
    ({"rx": -3, "lean": -5, "hsnap": -2, "helm": "hurt", "crack": True, "ph": 0.2, "robe_sway": 4, "arm": (56, 50), "back": (20, 46), "heart": 0, "bob": 1}, 2),
    ({"rx": -2, "lean": -2, "hsnap": -1, "helm": "hurt", "crack": True, "ph": 0.3, "robe_sway": 2}, 1),
    ({"rx": -1, "lean": -1, "ph": 0.4, "robe_sway": 1}, 1),
)

KO = seq(
    ({"rx": -2, "lean": -4, "hsnap": -2, "helm": "hurt", "flash": True, "ph": 0.1, "robe_sway": 3, "crack": True}, 1),
    ({"rx": -3, "lean": -3, "hsnap": -1, "helm": "hurt", "crack": True, "ph": 0.2, "heart": 0, "arm": (54, 58), "claw": 100, "bob": 2, "robe_sway": 2}, 2),
    ({"rx": -2, "lean": 4, "helm": "dead", "crack": True, "ph": 0.3, "heart": 0, "crumble": 1, "arm": (52, 60), "claw": 110}, 2),
    ({"rx": -2, "lean": 2, "helm": "dead", "ph": 0.4, "heart": 0, "crumble": 2, "arm": (50, 62), "claw": 120}, 2),
    ({"rx": -2, "helm": "dead", "ph": 0.5, "heart": 0, "crumble": 3}, 4),
)

ANIMS = [
    {"name": "idle", "fps": 7, "loop": True, "frames": _idle()},
    {"name": "attack", "fps": 12, "loop": False, "frames": ATTACK, "events": {"impact": 3}},
    {"name": "cast", "fps": 10, "loop": False, "frames": CAST, "events": {"impact": 4}},
    {"name": "hit", "fps": 12, "loop": False, "frames": HIT},
    {"name": "ko", "fps": 9, "loop": False, "frames": KO},
]
