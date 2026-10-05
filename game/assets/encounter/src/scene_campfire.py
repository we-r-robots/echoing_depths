"""A Light Left Burning: a girl in a too-large coat beside a dying lantern; her shadow towers on the cave wall."""
from kit import *

OUT = os.path.join(ROOT, 'assets', 'encounter', 'campfire')
LAMP = (204, 252)
COAT = ramp('ink1', 'ink2', 'life1', 'life2', 'life2', 'life3')
SKIN_R = ramp('skin1', 'skin2', 'skin3', 'skin4')
HAIR = ramp('ink1', 'blood1', 'blood2', 'amber2', 'amber3')
FLOOR = 262


def girl(cv):
    """Paints the girl; returns her mask."""
    X, Y = cv.x, cv.y
    L = LAMP
    m = np.zeros((H, W), bool)
    coat = poly_mask(cv, [(122, 184), (150, 178), (166, 208), (174, 264), (112, 266), (108, 222)])
    lc = np.clip(1 - np.sqrt((X - L[0]) ** 2 + (Y - L[1]) ** 2) / 170, 0, 1)
    cv.shade(coat, 0.1 + 0.9 * lc * (0.4 + 0.6 * smoothstep(108, 170, X)), COAT, 0, 1)
    for fx, fy in ((128, 206), (148, 214)):
        cv.put(line_mask(cv, [(fx, fy), (fx + 4, 250), (fx + 2, 264)], 1) & coat, IDX['ink1'])
    m |= coat
    m |= capsule(cv, [(146, 238), (172, 222), (180, 262)], 8, COAT, L, amb=0.05, outline=False)
    m |= blob(cv, 186, 264, 9, 5, ramp('ink1', 'ink2', 'amber1', 'amber2'), L, amb=0.05, outline=False)
    m |= capsule(cv, [(152, 196), (170, 216), (180, 214)], 5, COAT, L, amb=0.05, outline=False)
    # the cut hand, bound in a strip of cloth with a red spot
    m |= blob(cv, 183, 213, 4, 4, SKIN_R, L, amb=0.1, outline=False)
    cv.put((np.abs(X - 183) < 3) & (np.abs(Y - 213) < 1.5), IDX['fade4'])
    cv.idx[213, 184] = IDX['blood3']
    knife = line_mask(cv, [(186, 211), (200, 200)], 1)
    cv.put(knife, IDX['fade4']); m |= knife
    cv.put(line_mask(cv, [(188, 209), (193, 205)], 1), IDX['ink10'])
    m |= capsule(cv, [(138, 168), (130, 196)], 8, HAIR, L, amb=0.05, outline=False)
    m |= blob(cv, 142, 162, 17, 18, HAIR, L, amb=0.05, outline=False)
    face = blob(cv, 151, 166, 10, 13, SKIN_R, L, amb=0.05, outline=False)
    m |= face
    cv.put(face & (X < 147), IDX['skin1'])
    fringe = poly_mask(cv, [(134, 150), (162, 152), (160, 158), (148, 157), (138, 166)])
    cv.shade(fringe, lc + 0.25, HAIR, 0, 1.2)
    m |= fringe
    cv.put((np.abs(X - 156) < 2) & (np.abs(Y - 165) < 0.6), IDX['ink1'])
    m |= capsule(cv, [(136, 180), (158, 182)], 4, ramp('ink1', 'blood1', 'blood2', 'blood3'), L, amb=0.05, outline=False)
    m |= capsule(cv, [(140, 182), (134, 206)], 3, ramp('ink1', 'blood1', 'blood2', 'blood3'), L, amb=0.05, outline=False)
    # warm rim on everything facing the lamp, dark outline elsewhere
    cv.put(outer_edge(m), IDX['ink1'])
    rim = m & ~shift(m, -1, 0) & (X > 140)
    cv.put(rim & (lc > 0.25), IDX['amber4'])
    cv.put(m & ~shift(m, 0, 1) & ~shift(m, -1, 1) & (lc > 0.3), IDX['amber3'])
    return m


def paint(with_girl=True):
    cv = Canvas(W, H, IDX['ink1'])
    X, Y = cv.x, cv.y
    # cave: back wall and ceiling of faceted rock, floor of packed earth and stones
    wall = Y < FLOOR
    strata(cv, wall, seed=21, tones=('ink3', 'ink4', 'ink4', 'ink5'), slant=-0.08)
    # a ledge of darker boulders framing the nook
    n = fbm(W, H, 30, 3, 4)
    frame = ((X < 40 + 60 * n) | (Y < 30 + 50 * n) | ((X > 290 + 40 * n) & (X < 380))) & (Y < 300)
    strata(cv, frame, seed=7, tones=('ink2', 'ink3'), hmin=10, hmax=18, slant=0.1)
    cv.put(edge_of(frame) & ~shift(frame, 1, 1), IDX['ink1'])
    floor = Y >= FLOOR
    cv.shade(floor, 0.55 + 0.15 * (fbm(W, H, 12, 2, 13) - 0.5), ramp('ink2', 'ink3', 'ink4', 'ink5'), 0, 1)
    cv.put(floor & (Y == FLOOR), IDX['ink1'])
    # pebbles
    rng = np.random.default_rng(5)
    for i in range(30):
        px_, py_ = int(rng.integers(40, 320)), int(rng.integers(FLOOR + 4, 350))
        blob(cv, px_, py_, int(rng.integers(2, 6)), int(rng.integers(1, 3)), ramp('ink1', 'ink3', 'ink4', 'ink5'), LAMP, amb=0.1)
    # her pack and bedroll
    blob(cv, 90, 248, 24, 20, ramp('ink1', 'ink2', 'amber1', 'amber2', 'amber3'), LAMP, amb=0.02)
    capsule(cv, [(74, 236), (104, 232)], 3, ramp('ink1', 'amber1', 'amber2'), LAMP, amb=0.05)
    capsule(cv, [(56, 272), (100, 274)], 7, ramp('ink1', 'blood1', 'blood2', 'amber2'), LAMP, amb=0.05)

    # warm lantern light over the whole nook: steps up near the lamp, sinks to black at the frame
    d = np.sqrt(((X - LAMP[0]) / 1.0) ** 2 + ((Y - LAMP[1]) / 0.8) ** 2)
    lf = np.clip(1 - d / 300, 0, 1)
    light_pass(cv, noisy(lf * 3.0 - 1.0, 3, 0.5))
    tint_pass(cv, noisy(lf * 1.5, 4, 0.3), WARM)

    if with_girl:
        gm = girl(cv)
        # her shadow, thrown huge onto the wall behind
        k = 1.7
        fx_, fy_ = 150, FLOOR  # her feet: the shadow stretches up the wall from here, away from the lamp
        sx = np.clip(fx_ + (X - fx_ + 40) / k, 0, W - 1).astype(int)
        sy = np.clip(fy_ + (Y - fy_) / k, 0, H - 1).astype(int)
        shadow = gm[sy, sx] & wall & ~gm
        light_pass(cv, np.full((H, W), -2.0), shadow)

    # the dying lantern
    lx, ly = LAMP
    cage = (np.abs(X - lx) < 7) & (Y > ly - 6) & (Y < ly + 11)
    glass = (np.abs(X - lx) < 5) & (Y > ly - 4) & (Y < ly + 9)
    base = (np.abs(X - lx) < 8) & (np.abs(Y - (ly + 12)) < 2)
    cap = poly_mask(cv, [(lx - 8, ly - 5), (lx + 8, ly - 5), (lx, ly - 13)])
    cv.put(cage, IDX['amber2'])
    cv.shade(glass, radial(cv, lx, ly + 5, 8), ramp('amber3', 'amber4', 'amber5', 'amber6'), 0, 0.9)
    cv.put(ellipse_mask(cv, lx, ly + 5, 1.5, 2.5), IDX['amber7'])
    cv.put(base, IDX['amber3']); cv.put(cap, IDX['amber3']); cv.put(cap & (X > lx), IDX['amber2'])
    cv.put(outer_edge(cage | cap | base), IDX['ink1'])
    cv.put(line_mask(cv, [(lx - 3, ly - 13), (lx, ly - 18), (lx + 3, ly - 13)], 1), IDX['amber2'])

    vignette(cv, LAMP[0] - 40, LAMP[1] - 50, 260, 230, 2.5)
    light_pass(cv, -np.clip((X - 300) / 50.0, 0, 4))
    cv.clean(passes=1)
    return cv


def main():
    full = paint(True)
    base = paint(False)
    base.save(os.path.join(OUT, 'bg.png'))
    diff_layer(full, base, os.path.join(OUT, 'girl.png'))
    glow_layer(os.path.join(OUT, 'glow.png'), LAMP[0], LAMP[1] + 4, 40, ['amber1', 'amber2', 'amber3'])
    print('campfire done')


if __name__ == '__main__':
    main()
