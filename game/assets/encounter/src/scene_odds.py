"""The Keeper of Even Odds: a brass automaton kneeling on one knee in a Lumari alcove,
one lantern lit in its left hand, one dark in its right.
The figure is built from hand-designed brass plates (planar tones, bevels, rivets, specular strips)."""
from kit import *
from paint import _tp, XF

OUT = os.path.join(ROOT, 'assets', 'encounter', 'odds')
CX = 168
SCALE = 1.4
FLOOR = 274
LIT_HAND = (108, 186)
DARK_HAND = (214, 206)
LIT = (108, 212)     # lantern centres
DARK = (214, 232)


def room(cv):
    X, Y = cv.x, cv.y
    bricks(cv, Y < FLOOR, base='ink3', alt='ink4', mortar='ink2', seed=31, bh=11, bw=(16, 30))
    arch_out = ((np.abs(X - CX) < 112) & (Y > 64)) | (((X - CX) ** 2 + (Y - 64) ** 2) < 112 ** 2)
    arch_in = ((np.abs(X - CX) < 96) & (Y > 64)) | (((X - CX) ** 2 + (Y - 64) ** 2) < 96 ** 2)
    ring = arch_out & ~arch_in & (Y < FLOOR)
    cv.put(ring, IDX['ink4'])
    ang = np.arctan2(Y - 64, X - CX)
    cv.put(ring & (Y < 64) & (np.abs(np.sin(ang * 9)) < 0.1), IDX['ink2'])
    cv.put(ring & (Y >= 64) & ((Y.astype(int) % 20) == 0), IDX['ink2'])
    cv.put(ring & ~shift(ring, 0, 1), IDX['ink6'])
    cv.put(outer_edge(ring), IDX['ink1'])
    inner = arch_in & (Y < FLOOR)
    bricks(cv, inner, base='ink2', alt='ink3', mortar='ink1', seed=33, bh=8, bw=(10, 20))
    fr = inner & (np.abs(Y - 90) < 4)
    cv.put(fr, IDX['ink2'])
    cv.put(fr & (np.abs(np.sin(X * 0.6)) > 0.65) & (np.abs(Y - 90) < 2), IDX['ink5'])
    stalactites(cv, 21, 16, xmax=360)
    fl = Y >= FLOOR
    cv.shade(fl, 0.5 + 0.2 * (fbm(W, H, 10, 2, 7) - 0.5), ramp('ink2', 'ink3', 'ink4'), 0, 1)
    for yy in (FLOOR, 286, 302, 324, 352):
        cv.put(fl & (Y == yy), IDX['ink1'])
    for k in range(-12, 14):
        cv.put(line_mask(cv, [(CX + k * 26, FLOOR), (CX + k * 46, 360)], 1) & fl, IDX['ink1'])
    # plaque set in the floor before it
    pq = (np.abs(X - CX) < 26) & (np.abs(Y - 296) < 7)
    cv.put(pq, IDX['ink4'])
    cv.put(pq & ~shift(pq, 0, 1), IDX['ink6'])
    cv.put(outer_edge(pq), IDX['ink1'])
    for k in range(-20, 21, 4):
        cv.put((np.abs(X - (CX + k)) < 1) & (np.abs(Y - 294) < 2) & pq, IDX['ink2'])
        cv.put((np.abs(X - (CX + k + 2)) < 1) & (np.abs(Y - 299) < 1) & pq, IDX['ink2'])


def rivets(cv, pts, fig):
    for (x, y) in pts:
        x, y = (int(round(v)) for v in _tp((x, y)))
        if fig[y, x]:
            cv.idx[y, x] = IDX['amber7']
            cv.idx[y + 1, x] = IDX['amber1']


B_LIT, B_MID, B_DRK = 'amber5', 'amber3', 'amber1'   # near side
F_LIT, F_MID, F_DRK = 'amber3', 'amber2', 'ink2'     # far side (behind the body)


def keeper(cv, awake=False):
    """Profile, facing left: back knee on the floor, front knee raised, head bowed.
    Near arm reaches forward with the lit lantern; far arm hangs behind with the dark one."""
    X, Y = cv.x, cv.y
    f = np.zeros((H, W), bool)
    # ---- far side first: far arm + dark lantern hand
    limb(cv, (186, 152), (204, 182), 11, 9, F_LIT, F_MID, F_DRK, f)
    joint(cv, 204, 182, 6, F_LIT, F_MID, F_DRK, f)
    limb(cv, (204, 182), DARK_HAND, 9, 7, F_LIT, F_MID, F_DRK, f)
    pmap(cv, DARK_HAND[0] - 3, DARK_HAND[1] - 2, [".#BA#.", "#BAA1#", "#A111#", ".#11#."], mask_out=f)
    # ---- back leg: thigh down to the knee on the floor, shin back along the floor, toes curled
    limb(cv, (184, 210), (194, 262), 20, 14, B_LIT, B_MID, B_DRK, f)
    joint(cv, 194, 263, 9, 'amber4', 'amber3', 'amber1', f)
    limb(cv, (196, 266), (232, 268), 11, 8, 'amber3', 'amber2', 'amber1', f, light_dir=(0, -1))
    plate(cv, [(228, 258), (238, 262), (240, 274), (226, 274)], 'amber2', hi='amber4', fig=f)
    # ---- pelvis + waist gear (visible from the side)
    plate(cv, [(160, 200), (194, 198), (198, 216), (164, 220)], B_MID, hi='amber5', lo='amber1', fig=f)
    joint(cv, 178, 208, 7, 'amber6', 'amber4', 'amber2', f)
    cv.put(ellipse_mask(cv, 178, 208, 2, 2), IDX['ink1'])
    # ---- front leg: thigh forward to the raised knee, shin straight down, foot flat
    limb(cv, (170, 214), (134, 218), 20, 15, B_LIT, B_MID, B_DRK, f, light_dir=(0, -1))
    limb(cv, (134, 222), (136, 266), 14, 11, B_LIT, B_MID, B_DRK, f)
    joint(cv, 133, 220, 10, 'amber7', 'amber5', 'amber3', f)
    plate(cv, [(118, 264), (144, 264), (146, 275), (114, 275)], 'amber3', hi='amber5', lo='amber1', fig=f)
    cv.put(line_mask(cv, [(130, 228), (131, 262)], 1), IDX['amber6'])
    # ---- torso: deep barrel chest leaning forward, plates and seams
    torso = plate(cv, [(152, 150), (186, 140), (198, 160), (196, 196), (162, 202), (148, 178)], B_MID, fig=f)
    plate(cv, [(152, 150), (166, 146), (160, 176), (162, 202), (148, 178)], B_LIT, hi='amber7', fig=f)
    plate(cv, [(186, 140), (198, 160), (196, 196), (188, 198), (190, 160)], B_DRK, fig=f)
    for (p, q) in (((150, 166), (196, 160)), ((156, 186), (196, 178))):
        cv.put(line_mask(cv, [p, q], 1) & torso, IDX['amber1'])
        cv.put(line_mask(cv, [(p[0], p[1] + 1), (q[0], q[1] + 1)], 1) & torso & (X < 188), IDX['amber6'])
    cv.put(line_mask(cv, [(155, 154), (151, 176)], 1) & torso, IDX['amber7'])
    # crystal heart glimpsed in the chest from the side
    disc(cv, 160, 158, 5, 'amber1', f)
    disc(cv, 160, 158, 3, 'crystal3' if awake else 'crystal2', f)
    pmap(cv, 159, 157, ['L' if awake else 'J'])
    rivets(cv, [(170, 148), (180, 146), (192, 164), (194, 184), (166, 198), (180, 196)], f)
    # neck, bent forward
    limb(cv, (176, 142), (164, 130), 9, 8, 'amber3', 'amber2', 'amber1', f)
    for k in range(3):
        cv.put(line_mask(cv, [(172 - k * 4 - 3, 136 - k * 3 + 3), (172 - k * 4 + 3, 136 - k * 3 - 3)], 1) & f, IDX['amber4'])
    # ---- head: a bowed cowl helm, visor slit facing down-left, crest sweeping back
    helm = disc(cv, 158, 120, 14, B_MID, f, ry=15)
    plate(cv, [(144, 116), (152, 104), (160, 104), (154, 120), (150, 132), (145, 128)], B_LIT, hi='amber7', fig=f)
    plate(cv, [(166, 108), (172, 116), (172, 128), (166, 134)], B_DRK, fig=f)
    # face plate, in its own shadow under the cowl
    plate(cv, [(143, 120), (156, 122), (156, 136), (146, 136)], 'amber2', fig=f)
    plate(cv, [(144, 121), (150, 122), (150, 135), (146, 135)], 'amber3', fig=f)
    cv.put(line_mask(cv, [(144, 126), (155, 128)], 1), IDX['ink1'])
    cv.put(line_mask(cv, [(146, 126), (151, 127)], 1), IDX['amber7' if awake else 'amber3'])
    for gy in (131, 133):
        cv.put(line_mask(cv, [(146, gy), (153, gy + 1)], 1), IDX['amber1'])
    # crest fin sweeping back from the brow
    plate(cv, [(152, 104), (160, 100), (180, 96), (172, 106), (162, 108)], 'amber4', hi='amber6', lo='amber2', fig=f)
    # winding key in its back
    cv.put(line_mask(cv, [(196, 164), (212, 156)], 2), IDX['amber2'])
    for (kx, ky) in ((214, 150), (218, 160)):
        cv.put(ellipse_mask(cv, kx, ky, 4, 3), IDX['amber3'])
        cv.put(ellipse_mask(cv, kx, ky, 2, 1), IDX['ink1'])
        f |= ellipse_mask(cv, kx, ky, 4, 3)
    # ---- near arm: shoulder pauldron, upper arm, forearm reaching forward, fist with the lantern ring
    limb(cv, (172, 152), (146, 176), 12, 10, B_LIT, B_MID, B_DRK, f)
    joint(cv, 146, 177, 7, 'amber6', 'amber4', 'amber2', f)
    limb(cv, (146, 177), LIT_HAND, 10, 8, B_LIT, B_MID, B_DRK, f, light_dir=(-0.3, -1))
    for k, (yy, ww) in enumerate([(144, 22), (150, 22), (156, 19)]):
        plate(cv, [(170 - ww // 2, yy + 7), (170 - ww // 2 + 3, yy), (170 + ww // 2 - 2, yy), (170 + ww // 2, yy + 7)],
              'amber5' if k != 1 else 'amber6', hi='amber7', lo='amber1', fig=f)
    pmap(cv, LIT_HAND[0] - 4, LIT_HAND[1] - 3, [".#FE#.", "#FEED#", "#EDDC#", "#DCCB#", ".#BB#."], mask_out=f)
    # extra plate seams: chest medallion, thigh lames, forearm bands
    cv.put(line_mask(cv, [(170, 150), (176, 196)], 1) & f, IDX['amber1'])
    for (cx_, cy_) in ((182, 176),):
        cv.put((np.abs(np.hypot(X - _tp((cx_, cy_))[0], Y - _tp((cx_, cy_))[1]) - 6) < 0.7) & f, IDX['amber1'])
        cv.put((np.abs(np.hypot(X - _tp((cx_, cy_))[0], Y - _tp((cx_, cy_))[1]) - 3) < 0.7) & f, IDX['amber5'])
    for t_ in (0.35, 0.65):
        pa = (170 + (134 - 170) * t_, 206); pb = (170 + (134 - 170) * t_, 226)
        cv.put(line_mask(cv, [pa, pb], 1) & f, IDX['amber1'])
    for t_ in (0.3, 0.6):
        cv.put(line_mask(cv, [(128, 222 + 44 * t_), (142, 222 + 44 * t_)], 1) & f, IDX['amber2'])
    # piston along the back of the thigh
    cv.put(line_mask(cv, [(196, 214), (200, 246)], 2), IDX['ink3'])
    cv.put(line_mask(cv, [(197, 214), (199, 230)], 1), IDX['fade3'])
    # gear teeth round the hip joint
    for k in range(12):
        a_ = k * np.pi / 6
        cv.put(ellipse_mask(cv, 178 + 9 * np.cos(a_), 208 + 9 * np.sin(a_), 1.5, 1.5) & f, IDX['amber2'])
    # shoulder gear exposed under the pauldron
    joint(cv, 176, 160, 5, 'amber6', 'amber3', 'amber1', f)
    cv.put(ellipse_mask(cv, 176, 160, 1.5, 1.5), IDX['ink1'])
    # verdigris patina in the shaded plates, and pitted wear
    pat = f & (value_noise(W, H, 3, 41) > 0.84) & np.isin(cv.idx, [IDX['amber1'], IDX['amber2']])
    cv.put(pat, IDX['life2'])
    cv.put(pat & (value_noise(W, H, 2, 42) > 0.6), IDX['life3'])
    pits = f & (value_noise(W, H, 2, 43) > 0.85) & np.isin(cv.idx, [IDX['amber4'], IDX['amber5']])
    cv.put(pits, IDX['amber3'])
    # rims: warm on the lantern side, cold on the back
    rim(cv, f, -1, 0, 'amber7', X < 170)
    rim(cv, f, 0, -1, 'amber6', X < 175)
    rim(cv, f, 1, 0, 'crystal2', X > 180)
    outline(cv, f)
    return f


def lantern(cv, hand, lit):
    """A Lumari lantern hung on a short chain from the fist (stamped at 2x so it reads at 1x)."""
    X, Y = cv.x, cv.y
    hx, hy = (int(round(v)) for v in _tp(hand))
    m = np.zeros((H, W), bool)
    XF_saved = XF[0]
    XF[0] = None
    for yy in range(hy + 3, hy + 13, 3):
        link = (np.abs(X - hx) < 1.5) & (Y >= yy) & (Y < yy + 2)
        cv.put(link, IDX['ink1' if not lit else 'amber2'])
        m |= link
    mp = (["....##....", "...#EE#...", "..#DEED#..", ".########.", "#DD#GG#DD#", "#D#GGGG#D#", "#D#GGGG#D#",
           "#D#GFFG#D#", "#D#GFFG#D#", "#D#GGGG#D#", ".########.", "..#CCCC#..", "...####..."]
          if lit else
          ["....##....", "...#44#...", "..#4554#..", ".########.", "#44#22#44#", "#4#2222#4#", "#4#2JJ2#4#",
           "#4#2IJ2#4#", "#4#2222#4#", "#4#2222#4#", ".########.", "..#3333#..", "...####..."])
    top = hy + 13
    K = 3
    for ry, row in enumerate(mp):
        for rx, ch in enumerate(row):
            if ch in PMAP:
                for dy in range(K):
                    for dx in range(K):
                        x, y = hx - 5 * K + rx * K + dx, top + ry * K + dy
                        cv.idx[y, x] = IDX[PMAP[ch]]
                        m[y, x] = True
    if lit:
        cv.put(ellipse_mask(cv, hx, top + 21, 2, 4), IDX['ink10'])
    XF[0] = XF_saved
    return m


def paint(lit=True, dark=True, awake=False, keeper_on=True):
    cv = Canvas(W, H, IDX['ink1'])
    X, Y = cv.x, cv.y
    room(cv)
    if keeper_on:
        sh = ellipse_mask(cv, CX + 10, 277, 100, 6) & (Y >= FLOOR)
        light_pass(cv, np.full((H, W), -1.5), sh)
    # baked neutral light: the alcove is visible whatever happens to the lanterns
    d = np.sqrt((X - CX) ** 2 + ((Y - 190) * 0.9) ** 2)
    light_pass(cv, noisy(0.6 - np.clip(d / 140, 0, 2.6), 5, 0.4))
    with scaled(CX, FLOOR, SCALE):
        if keeper_on:
            keeper(cv, awake)
        if lit:
            lantern(cv, LIT_HAND, True)
        if dark:
            lantern(cv, DARK_HAND, False)
    vignette(cv, CX, 190, 250, 220, 2.6)
    light_pass(cv, -np.clip((X - 300) / 50.0, 0, 4))
    cv.clean(passes=1)
    return cv


def main():
    full = paint()
    base = paint(lit=False, dark=False)
    base.save(os.path.join(OUT, 'bg.png'))
    diff_layer(full, paint(lit=False), os.path.join(OUT, 'lit.png'))
    diff_layer(full, paint(dark=False), os.path.join(OUT, 'dark.png'))
    diff_layer(paint(awake=True), full, os.path.join(OUT, 'awake.png'))
    # the lit lantern's warmth, as additive light (removed with the lantern)
    XF[0] = (CX, FLOOR, SCALE)
    lh = _tp(LIT_HAND); dh = _tp(DARK_HAND)
    XF[0] = None
    LIT = (lh[0], lh[1] + 32); DARK = (dh[0], dh[1] + 32)
    print('lit lantern at', LIT)
    glow_layer(os.path.join(OUT, 'warm.png'), LIT[0], LIT[1], 150, ['amber1', 'amber1', 'amber2'], sy=0.9)
    glow_layer(os.path.join(OUT, 'glow.png'), LIT[0], LIT[1], 34, ['amber2', 'amber3', 'amber4'])
    glow_layer(os.path.join(OUT, 'cold.png'), DARK[0], DARK[1], 26, ['crystal1', 'crystal2'])
    print('odds done')


if __name__ == '__main__':
    main()
