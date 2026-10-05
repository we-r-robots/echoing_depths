"""Shared hero body: pelvis-driven poses at 80x80 (heroes ~50 px tall).

A key pose is: a hand-drawn torso drawing for that pose (with its own anchors
for neck, shoulders and hips), a pelvis position, planted foot positions and
hand targets. Legs and arms are solved with two-bone IK each frame, so when the
pelvis drops the knees are redrawn bent, not shifted. Each hero module supplies
its drawings, ramps and an `extras` hook for cloth, hair and weapons.

Full-frame overrides: if tools/art/poses/<hero>/<anim>_<i>.txt exists it is
used verbatim as that frame (a hand-edited pixel map; see bake())."""
from __future__ import annotations

import math
import os
from pixlib import Canvas, Part, flash, parse, LEGEND
import rig

HERE = os.path.dirname(os.path.abspath(__file__))
POSES = os.path.join(HERE, "poses")


def ik(a, c, l1, l2, bend=1):
    """Two-bone IK: joint between a and c with bone lengths l1, l2. bend=+1 puts
    the joint on the right of a->c (knees forward for a right-facing hero)."""
    dx, dy = c[0] - a[0], c[1] - a[1]
    d = math.hypot(dx, dy)
    d = min(d, l1 + l2 - 0.01)
    d = max(d, abs(l1 - l2) + 0.01)
    # law of cosines
    cosA = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    A = math.acos(max(-1.0, min(1.0, cosA)))
    base = math.atan2(dy, dx)
    ang = base - bend * A
    return (a[0] + l1 * math.cos(ang), a[1] + l1 * math.sin(ang))


class Torso:
    """A torso drawing plus its anchors (local pixel coords)."""

    def __init__(self, grid, hip, neck, shf, shb, hipf, hipb, legend=None):
        self.part = Part(grid, legend=legend)
        self.hip, self.neck, self.shf, self.shb, self.hipf, self.hipb = hip, neck, shf, shb, hipf, hipb

    def place(self, pelvis):
        ox, oy = pelvis[0] - self.hip[0], pelvis[1] - self.hip[1]
        at = lambda q: (q[0] + ox, q[1] + oy)
        return (ox, oy), {k: at(getattr(self, k)) for k in ("neck", "shf", "shb", "hipf", "hipb")}


def override_path(name, anim, i):
    return os.path.join(POSES, name, f"{anim}_{i}.txt")


def load_override(name, anim, i, size):
    p = override_path(name, anim, i)
    if not os.path.exists(p):
        return None
    with open(p) as f:
        txt = f.read()
    px, w, h = parse(txt)
    cv = Canvas(*size)
    cv.px = dict(px)
    return cv


INV = {}
for _k, _v in LEGEND.items():
    INV.setdefault(_v, _k)
INV["ink1"] = "#"


def bake(cv, path):
    """Write a finished frame as an editable pixel map."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rows = []
    for y in range(cv.h):
        rows.append("".join(INV.get(cv.px.get((x, y)), ".") if (x, y) in cv.px else "." for x in range(cv.w)))
    with open(path, "w") as f:
        f.write("\n".join(rows) + "\n")


def leg(cv, hip, foot, l1, l2, thigh, shin, boot, r1, r2, toe=4, bend=1, boot_h=2):
    knee = ik(hip, foot, l1, l2, bend)
    ank = (foot[0], foot[1] - boot_h)
    rig.limb(cv, [hip, knee], r1, thigh)
    rig.limb(cv, [knee, ank], r2, shin)
    # boot: a chunky wedge from the ankle to the toe
    rig.limb(cv, [(ank[0] - 0.5, ank[1]), (foot[0] + 0.5, foot[1] - 0.5), (foot[0] + toe, foot[1])], 1.8, boot)
    return knee


def arm(cv, sh, hand, l1, l2, upper, fore, fist, r1, r2, bend=-1, fist_r=1.8):
    el = ik(sh, hand, l1, l2, bend)
    rig.limb(cv, [sh, el], r1, upper)
    rig.limb(cv, [el, hand], r2, fore)
    rig.blob(cv, hand[0], hand[1], fist_r, fist_r, fist)
    return el
