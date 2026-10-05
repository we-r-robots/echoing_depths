"""The Weeping Colossus: a half-drowned Lumari head weeping light into a still pool."""
import numpy as np
from paint import *

W, H = 640, 360
OUT = os.path.join(ROOT, 'assets', 'encounter', 'colossus')
WATER = 268
LAMP = (240, 272)
FIGHTER = ["....####....", "...######...", "...######...", "...######...", "....####....", "..########..", ".##########.",
           "############", "############", "############", ".##########.", ".##########.", ".##########.", "..########..",
           "..########..", "..########..", "..###..###..", "..###..###..", "..###..###..", "..###..###..", ".####..####.", ".####..####."]
HEALER = ["...####...", "..######..", ".########.", ".########.", ".########.", "..######..", ".########.", "##########",
          "##########", "##########", "##########", "##########", "##########", "##########", "##########", "##########",
          "##########", "###########", "###########", "############", "############", "############"]
MAGE = [".....#....", "....##....", "....##....", "...###....", "...####...", "..#####...", "..######..", "##########",
        "...####...", "..######..", ".########.", ".########.", ".########.", ".########.", ".########.", "..######..",
        "..######..", "..######..", "..######..", ".########.", ".########.", "##########", "##########"]


def head_field(cv):
    # head frame: centre, tilt
    cx, cy, ang = 168.0, 168.0, np.radians(-14)
    sx, sy = 84.0, 112.0
    dx = cv.x - cx; dy = cv.y - cy
    u = (dx * np.cos(ang) + dy * np.sin(ang)) / sx
    v = (-dx * np.sin(ang) + dy * np.cos(ang)) / sy
    au = np.abs(u)
    r2 = (u / 0.92) ** 2 + (v / 1.0) ** 2
    # jaw narrows toward chin
    jaw = 1 + 0.35 * smoothstep(0.2, 0.95, v)
    r2 = (u * jaw / 0.92) ** 2 + v ** 2
    mask = r2 < 1.0
    base = np.sqrt(np.clip(1 - r2, 0, 1)) ** 0.6
    h = base * 1.0
    h += 0.10 * gauss(au, v, 0.0, -0.33, 0.85, 0.07) * (au < 0.8)  # brow
    h -= 0.20 * gauss(au, v, 0.36, -0.15, 0.17, 0.10)            # sockets
    h += 0.09 * gauss(au, v, 0.36, -0.13, 0.13, 0.05)            # lids
    h -= 0.05 * gauss(au, v, 0.36, -0.10, 0.12, 0.012)           # lid seam
    nose = 0.22 * np.exp(-(u / 0.085) ** 2) * smoothstep(-0.28, 0.0, v) * (1 - smoothstep(0.2, 0.26, v))
    h += nose
    h += 0.10 * gauss(u, v, 0.0, 0.20, 0.13, 0.06)               # nose tip
    h -= 0.04 * gauss(au, v, 0.07, 0.25, 0.04, 0.025)            # nostrils
    h += 0.07 * gauss(au, v, 0.52, 0.08, 0.15, 0.13)             # cheekbones
    h -= 0.05 * gauss(au, v, 0.40, 0.30, 0.10, 0.10)             # cheek hollow
    h += 0.07 * gauss(u, v, 0.0, 0.415, 0.22, 0.035)             # upper lip
    h += 0.08 * gauss(u, v, 0.0, 0.50, 0.17, 0.04)               # lower lip
    h -= 0.07 * gauss(u, v, 0.0, 0.457, 0.21, 0.010)             # mouth seam
    h += 0.06 * gauss(u, v, 0.0, 0.72, 0.20, 0.10)               # chin
    noise = fbm(cv.w, cv.h, 24, 4, 3)
    h += 0.035 * (noise - 0.5)
    # ears: carved lobes on both sides at eye-to-nose height
    ear = (((au - 0.90) / 0.10) ** 2 + ((v - 0.02) / 0.20) ** 2) < 1.0
    h = np.where(ear & ~mask, 0.35 + 0.15 * np.sqrt(np.clip(1 - ((au - 0.90) / 0.10) ** 2 - ((v - 0.02) / 0.20) ** 2, 0, 1)), h)
    h -= 0.08 * gauss(au, v, 0.91, 0.03, 0.035, 0.10) * ear
    mask = mask | ear
    # carved hair: an arched hairline, then wave-grooves following the skull
    hairline = -0.50 + 0.22 * u ** 2
    hair = (v < hairline) & mask
    r = np.sqrt(r2)
    groove = np.sin(r * 46.0 + u * 3.0)
    h += hair * (0.03 * groove + 0.04)
    # thin diadem riding the hairline
    band = (v > hairline - 0.035) & (v < hairline + 0.005) & mask & (au < 0.85)
    h += 0.03 * band
    return mask, h * 90.0, u, v, band


def main(crown=True):
    cv = Canvas(W, H, IDX['ink1'])
    X, Y = cv.x, cv.y

    # ---------------------------------------------------------------- sky / vault darkness
    halo = radial(cv, 172, 120, 300, 0.85)
    bgl = 0.06 + 0.55 * halo ** 1.6
    # fade to black toward the right where UI sits
    bgl *= 1 - 0.75 * smoothstep(260, 470, X)
    bg_r = ramp('ink1', 'ink2', 'ink3', 'crystal1', 'ink4')
    cv.shade(np.ones((H, W), bool), bgl, bg_r, 0.0, 0.62)

    # halo rings (Lumari sigil behind the head)
    d = np.sqrt((X - 176) ** 2 + ((Y - 118) / 0.97) ** 2)
    ring1 = (np.abs(d - 128) < 1.0)
    ring2 = (np.abs(d - 140) < 0.6)
    ticks = (np.abs(d - 134) < 4) & (np.abs(np.sin(np.arctan2(Y - 118, X - 176) * 18)) < 0.07)
    cv.put((ring1 | ticks) & (X < 330), IDX['crystal2'])
    cv.put(ring2 & (X < 330), IDX['ink4'])

    # far arches: columns rising into the dark
    for (ax, aw, top, shade) in [(-10, 46, -40, 'ink2'), (52, 22, 10, 'ink2'), (300, 30, 0, 'ink2')]:
        col = (X >= ax) & (X < ax + aw) & (Y > top)
        cv.put(col & (Y < WATER), IDX[shade])
        lit = (X >= ax + aw - 2) & (X < ax + aw) & (Y > top) & (Y < WATER)
        if ax < 330:
            cv.put(lit, IDX['ink3'])
        # capital
        cap = (X >= ax - 3) & (X < ax + aw + 3) & (Y > top + 60) & (Y < top + 66)
        cv.put(cap & (Y > 0), IDX['ink3' if ax < 400 else 'ink2'])
    # pointed arch outline linking near columns
    for cxa, r in [(176, 150), (176, 170)]:
        a = (np.abs(np.sqrt((X - cxa) ** 2 + ((Y - 150) * 0.8) ** 2) - r) < 0.8) & (Y < 150) & (X < 360)
        cv.put(a, IDX['ink3'])

    # hanging crystal stalactites (top)
    rng = np.random.default_rng(11)
    for i in range(26):
        sx = rng.integers(-10, 420)
        ln = rng.integers(10, 44)
        wd = rng.integers(3, 8)
        pts = [(sx, -1), (sx + wd, -1), (sx + wd // 2 + 1, ln)]
        m = poly_mask(cv, pts)
        lit = sx < 330
        cv.put(m, IDX['ink2'])
        cv.put(m & (X > sx + wd / 2), IDX['ink3' if lit else 'ink2'])
        if lit and rng.random() < 0.5:
            tip = m & (Y > ln - 6)
            cv.put(tip & (X > sx + wd / 2), IDX['crystal2'])

    # ---------------------------------------------------------------- the colossus head
    mask, h, u, v, band = head_field(cv)
    above = mask & (Y < WATER + 2)
    n = normals_from_height(h, 1.0)
    # lights: brow crystal (cyan), weeping eyes (cyan), lantern (amber, from lower right), cold fill from upper left
    crys_x, crys_y = 147, 52
    Lc = point_light(cv, n, h, crys_x, crys_y - 10, 140, 230) * 1.25
    eyeL = (130, 158); eyeR = (190, 143)
    Le = point_light(cv, n, h, eyeL[0], eyeL[1] + 30, 120, 120) * 0.6 + point_light(cv, n, h, eyeR[0], eyeR[1] + 30, 120, 120) * 0.6
    La = point_light(cv, n, h, LAMP[0], LAMP[1], 50, 130) * 1.3
    Lf = lambert(n, (-0.5, -0.9, 0.6)) * 0.30
    Lb = lambert(n, (0.2, -1.0, 0.15)) * 0.18
    cyan = Lc + Le
    tot = cyan + La + Lf + Lb + 0.06
    # choose ramp by dominant light
    stone_mask = above.copy()
    cv.shade(stone_mask, tot, ramp('ink1', 'ink2', 'ink3', 'ink4', 'ink5', 'ink6', 'ink7'), 0.0, 1.0)
    cyan_dom = above & (cyan > La * 1.2) & (tot > 0.42)
    cv.shade(cyan_dom, tot, ramp('ink3', 'crystal1', 'crystal2', 'crystal3', 'crystal4', 'crystal5'), 0.25, 1.35)
    amb_dom = above & (La > cyan * 0.9) & (La > 0.22)
    cv.shade(amb_dom, La + 0.1 * tot, ramp('ink3', 'amber1', 'amber2', 'amber3', 'amber4', 'amber5'), 0.1, 1.15)

    # cracks: a long fracture down the face and some smaller ones
    crack = line_mask(cv, [(196, 70), (190, 92), (199, 110), (192, 132), (203, 156), (197, 186), (208, 214), (204, 246), (212, 270)], 1)
    crack |= line_mask(cv, [(199, 110), (214, 118), (226, 116)], 1)
    crack |= line_mask(cv, [(110, 214), (118, 228), (114, 246), (122, 268)], 1)
    crack &= above
    cv.put(crack, IDX['ink1'])
    cv.put(shift(crack, 1, 0) & above & ~crack & (cyan > 0.3), IDX['crystal3'])

    # silhouette: dark outline on shadow side, cyan rim on lit (upper) side
    edge = edge_of(mask) & (Y < WATER)
    cv.put(edge, IDX['ink1'])
    rim = edge_of(mask & ~shift(mask, 2, 3)) & (Y < 200) & mask
    cv.put(rim & (X < 210), IDX['crystal3'])
    # back-light from the halo on the shadowed right flank
    rimr = mask & ~shift(mask, -2, 0) & (Y < WATER - 4) & (X > 190)
    cv.put(rimr, IDX['crystal1'])
    cv.put(mask & ~shift(mask, -1, 0) & (Y < 230) & (X > 200), IDX['crystal2'])

    # circlet: geometric band with inset glyphs
    cv.put(band & above, IDX['ink2'])
    bglyph = band & (np.abs(np.sin(u * 30)) > 0.9)
    cv.put(bglyph & (cyan > 0.25), IDX['crystal3'])
    cv.put(edge_of(band) & (Y < WATER), IDX['ink1'])

    # closed eyes: curved glowing lid seams (downturned arcs) + tears of light
    tears = []
    for (ex, ey), tilt in [(eyeL, 0.25), (eyeR, 0.25)]:
        pts = []
        for i in range(17):
            t_ = (i / 16.0) * 2 - 1
            pts.append((ex + t_ * 16, ey + 3 * (1 - t_ * t_) - t_ * 16 * tilt))
        seam = line_mask(cv, pts, 1)
        cv.put(shift(seam, 0, -1) & mask & ~seam, IDX['ink2'])
        cv.put(seam & mask, IDX['crystal4'])
        cv.put(seam & mask & (np.abs(cv.x - ex) < 9), IDX['crystal5'])
        cv.put(shift(seam, 0, 1) & mask & ~seam, IDX['crystal2'])
        tears.append((ex - 5, ey + 5))
    for k, (tx, ty) in enumerate(tears):
        pts = []
        yy = ty
        while yy <= WATER:
            pts.append((tx + 2.0 * np.sin(yy * 0.08 + k) + (yy - ty) * (0.02 if k == 0 else 0.07), yy))
            yy += 3
        tr = line_mask(cv, pts, 1)
        wide = tr | shift(tr, 1, 0)
        cv.put(shift(wide, -1, 0) & mask & ~wide, IDX['crystal2'])
        tmask = Y <= WATER
        cv.put(wide & tmask, IDX['crystal4'])
        cv.put(tr & tmask & ((cv.y.astype(int) // 5) % 3 != 0), IDX['crystal5'])
    global TEARS
    TEARS = tears
    TEARX = [int(tears[0][0] + 2.0 * np.sin(WATER * 0.08) + (WATER - tears[0][1]) * 0.02),
             int(tears[1][0] + 2.0 * np.sin(WATER * 0.08 + 1) + (WATER - tears[1][1]) * 0.07)]

    # brow crystal cluster (grows out of the circlet)
    shards = [
        [(140, 66), (150, 66), (147, 18)],
        [(132, 68), (141, 66), (128, 34)],
        [(150, 67), (160, 70), (166, 30)],
        [(158, 72), (166, 74), (178, 48)],
        [(122, 70), (131, 69), (114, 50)],
    ]
    for pts in (shards if crown else []):
        m = poly_mask(cv, pts)
        cx = sum(p[0] for p in pts) / 3
        tipx = pts[2][0]
        # facet split: left face dimmer, right face bright
        left = m & ((X - pts[0][0]) * (pts[2][1] - pts[0][1]) - (Y - pts[0][1]) * (tipx - pts[0][0]) < 0)
        mid_line = m & (np.abs((X - (pts[0][0] + pts[1][0]) / 2) - (Y - 70) * (tipx - (pts[0][0] + pts[1][0]) / 2) / (pts[2][1] - 70)) < 0.6)
        cv.put(m, IDX['crystal3'])
        cv.put(m & (X > (pts[0][0] + pts[1][0]) / 2 + (Y - 70) * (tipx - (pts[0][0] + pts[1][0]) / 2) / (pts[2][1] - 70)), IDX['crystal4'])
        cv.put(mid_line, IDX['crystal5'])
        cv.put(edge_of(m), IDX['crystal2'])
        tip = m & (Y < pts[2][1] + 5)
        cv.put(tip, IDX['ink10'])

    if not crown:
        # the empty socket where the crystal was wrenched out, and a few snapped stumps
        sock = ellipse_mask(cv, 146, 69, 12, 4)
        cv.put(sock, IDX['ink1'])
        cv.put(edge_of(sock) & (Y < 70), IDX['crystal2'])
        for (sx_, h_) in ((138, 8), (147, 12), (155, 7)):
            stump = poly_mask(cv, [(sx_ - 3, 70), (sx_ + 3, 70), (sx_ + 1, 70 - h_)])
            cv.put(stump, IDX['crystal3'])
            cv.put(stump & (X > sx_), IDX['crystal4'])
            cv.put(stump & (Y < 71 - h_ + 3), IDX['crystal5'])

    # ---------------------------------------------------------------- pool
    water = Y >= WATER
    wl = 0.12 + 0.45 * np.clip(1 - np.abs(X - 170) / 220, 0, 1) * np.clip(1 - (Y - WATER) / 110, 0, 1)
    wl *= 1 - 0.8 * smoothstep(260, 470, X)
    cv.shade(water, wl, ramp('ink1', 'ink2', 'ink3', 'crystal1'), 0.0, 0.5)
    # reflection of the head (mirrored, broken into ripple bands)
    ry = 2 * WATER - Y
    rip = np.sin(Y * 0.9) * 2.5 * np.clip((Y - WATER) / 40, 0.2, 1)
    rx = np.clip(X + rip, 0, W - 1).astype(int)
    ryi = np.clip(ry, 0, H - 1).astype(int)
    refl_src = mask[ryi, rx] & water & (Y < WATER + 95)
    band_on = (np.floor((Y - WATER) / 2).astype(int) % 3) != 2
    cv.put(refl_src & band_on, IDX['ink2'])
    tear_refl = (np.abs(X + rip - TEARX[0]) < 1.5) | (np.abs(X + rip - TEARX[1]) < 1.5)
    cv.put(tear_refl & water & band_on & (Y < WATER + 70), IDX['crystal3'])
    # glow pools where tears meet water
    for tx in TEARX:
        g = ellipse_mask(cv, tx, WATER + 3, 22, 4) & water
        cv.put(g, IDX['crystal2'])
        g2 = ellipse_mask(cv, tx, WATER + 2, 11, 2) & water
        cv.put(g2, IDX['crystal4'])
    # waterline highlight
    wline = (Y == WATER) & mask[np.clip(WATER - 1, 0, H - 1)][None, :].repeat(H, 0)
    cv.put(wline, IDX['crystal3'])
    # horizontal sparkle lines across the pool
    rng = np.random.default_rng(5)
    for i in range(70):
        yy = rng.integers(WATER + 4, H)
        xx = rng.integers(0, 360)
        ln = rng.integers(3, 14)
        m = (Y == yy) & (X >= xx) & (X < xx + ln)
        c = 'crystal2' if abs(xx - 170) < 120 else 'ink3'
        cv.put(m, IDX[c])

    # ---------------------------------------------------------------- foreground outcrop + the party, seen from behind
    lamp_x, lamp_y = LAMP
    ledge = poly_mask(cv, [(190, 360), (198, 326), (214, 310), (240, 303), (270, 301), (300, 304), (320, 312), (336, 330), (344, 360)])
    cv.put(ledge, IDX['ink1'])
    warm = radial(cv, lamp_x, lamp_y, 70)
    lt = edge_of(ledge) & (Y < 345)
    cv.put(lt & (warm > 0.4), IDX['amber3'])
    cv.put(lt & (warm > 0.12) & (warm <= 0.4), IDX['amber1'])
    lt2 = shift(lt, 0, 1) & ledge & ~lt & (warm > 0.45)
    cv.put(lt2, IDX['amber1'])
    # left foreground rock frame
    rockL = poly_mask(cv, [(0, 296), (20, 288), (44, 300), (66, 330), (84, 360), (0, 360)])
    cv.put(rockL, IDX['ink1'])
    cv.put(edge_of(rockL) & (Y < 340) & (X > 4) & (X < 60), IDX['ink3'])

    figs = [
        (226, 304, FIGHTER), (250, 302, HEALER), (272, 304, MAGE),
    ]
    for px0, by, shp in figs:
        hgt = len(shp)
        body = np.zeros((H, W), bool)
        for ry, row in enumerate(shp):
            for rxx, c in enumerate(row):
                if c == '#':
                    body[by - hgt + ry, px0 + rxx] = True
        cv.put(body, IDX['ink1'])
        # rim light from lantern: pixels whose neighbour toward the lamp is outside the body
        dxs = np.sign(lamp_x - (px0 + len(shp[0]) / 2))
        rim1 = body & ~shift(body, -int(dxs) if dxs else 0, 1)
        rimt = body & ~shift(body, 0, 1)
        cv.put((rim1 | rimt) & (warm > 0.25), IDX['amber2'])
        cv.put(rimt & (warm > 0.6), IDX['amber3'])
    # staff from healer's raised hand up to the lantern
    staff = line_mask(cv, [(253, 290), (lamp_x + 2, lamp_y + 3)], 1)
    cv.put(staff, IDX['ink1'])
    cv.put(shift(staff, 1, 0) & ~staff & (Y > lamp_y + 4), IDX['amber2'])
    lan = [".#.", "###", "#o#", "#o#", "###"]
    for ry, row in enumerate(lan):
        for rxx, c in enumerate(row):
            if c != '.':
                cv.idx[lamp_y - 2 + ry, lamp_x - 1 + rxx] = IDX['amber2' if c == '#' else 'amber7']

    cv.clean(passes=1)
    if not crown:
        return cv
    full = Canvas(W, H)
    full.idx = cv.idx.copy()

    # ---------------------------------------------------------------- animated overlays
    # glow: one faint halo band around the brow crystal (additive, pulsed in engine)
    gl = Canvas(W, H)
    rr = radial(gl, 147, 46, 40)
    gl.idx = np.where(rr > 0.35, IDX['crystal1'], -1)
    gl.save(os.path.join(OUT, 'glow.png'))
    # shine: the brightest pixels (shard faces, lid seams) re-lit a step brighter; pulsing this makes the light breathe
    sh = Canvas(W, H)
    up = {IDX['crystal4']: IDX['crystal5'], IDX['crystal5']: IDX['ink10'], IDX['crystal3']: IDX['crystal4']}
    region = (Y < 80) & (X > 100) & (X < 190) | ((Y > 130) & (Y < 175) & (X > 105) & (X < 215))
    for k_, v_ in up.items():
        sh.idx[(cv.idx == k_) & region] = v_
    sh.save(os.path.join(OUT, 'shine.png'))
    # tears: beads of light sliding down both streams (8 frames)
    for f in range(8):
        tf = Canvas(W, H)
        for k, (tx, ty) in enumerate(TEARS):
            for n in range(12):
                by = int(ty + 6 + n * 21 + f * 21 / 8.0)
                if by >= WATER - 1:
                    continue
                bx = int(tx + 2.0 * np.sin(by * 0.08 + k) + (by - ty) * (0.02 if k == 0 else 0.07))
                tf.idx[by:by + 3, bx:bx + 2] = IDX['ink10']
                tf.idx[by - 2:by, bx:bx + 2] = IDX['crystal5']
        tf.save(os.path.join(OUT, f'tears_{f}.png'))
    warmc = Canvas(W, H)
    rr = radial(warmc, LAMP[0], LAMP[1] + 1, 16)
    warmc.idx = np.where(rr > 0.5, IDX['amber2'], np.where(rr > 0.05, IDX['amber1'], -1))
    warmc.save(os.path.join(OUT, 'lantern_glow.png'))

    # ripple frames: moving sparkle lines on the pool (4 frames)
    for f in range(4):
        rp = Canvas(W, H)
        rng = np.random.default_rng(100 + f)
        for i in range(36):
            yy = int(rng.integers(WATER + 3, H - 2))
            xx = int(rng.integers(20, 330))
            ln = int(rng.integers(2, 9))
            near = abs(xx - 170) < 110
            rp.idx[yy, xx:xx + ln] = IDX['crystal3' if near else 'crystal2']
        rp.save(os.path.join(OUT, f'ripple_{f}.png'))
    print('colossus done')
    return full


if __name__ == '__main__':
    full = main(True)
    base = main(False)
    base.save(os.path.join(OUT, 'bg.png'))
    from kit import diff_layer
    diff_layer(full, base, os.path.join(OUT, 'crown.png'))
