"""The Last Name in Hollowmere: an old woman backlit by a pale sun where a village used to be.
The only colour left is the red name-ribbon in her hand."""
from kit import *

OUT = os.path.join(ROOT, 'assets', 'encounter', 'hollowmere')
SUN = (196, 206)
HORIZON = 232
CLOAK = ramp('ink1', 'ink2', 'ink3', 'ink4')


def woman_mask(cv):
    X, Y = cv.x, cv.y
    m = poly_mask(cv, [(146, 184), (164, 166), (176, 170), (186, 180), (192, 196), (196, 214), (201, 236), (210, 263), (176, 265), (140, 264), (144, 240), (148, 214), (150, 196)])
    m |= ellipse_mask(cv, 154, 172, 12, 12)                         # hooded head, bowed forward
    m |= poly_mask(cv, [(146, 166), (166, 160), (176, 168), (150, 186)])
    m |= capsule_mask(cv, [(156, 194), (136, 204), (120, 200)], 4)    # arm out, offering the ribbon
    m |= ellipse_mask(cv, 117, 199, 4, 3)
    m |= capsule_mask(cv, [(190, 206), (206, 214)], 3)               # other hand on the cane
    m |= line_mask(cv, [(207, 212), (214, 264)], 2)                  # cane
    return m


def capsule_mask(cv, pts, r):
    m = np.zeros((cv.h, cv.w), bool)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        abx, aby = bx - ax, by - ay
        t = np.clip(((cv.x - ax) * abx + (cv.y - ay) * aby) / (abx * abx + aby * aby), 0, 1)
        m |= (cv.x - ax - t * abx) ** 2 + (cv.y - ay - t * aby) ** 2 < r * r
    return m


def ribbon_pts():
    pts = []
    for i in range(46):
        t = i / 45.0
        x = 116 - 70 * t + 6 * np.sin(t * 9)
        y = 200 + 10 * t + 7 * np.sin(t * 7 + 1)
        pts.append((x, y))
    return pts


def paint(woman=True, ribbon=True):
    cv = Canvas(W, H, IDX['ink1'])
    X, Y = cv.x, cv.y
    # sky: stepped light rising toward the sun, broken by cloud courses
    d = np.sqrt(((X - SUN[0]) / 1.6) ** 2 + (Y - SUN[1]) ** 2)
    sky = np.clip(1 - d / 220, 0, 1)
    cv.shade(Y < HORIZON, noisy(sky, 2, 0.12), ramp('ink2', 'ink3', 'ink4', 'fade1', 'fade2', 'fade3'), 0.0, 1.0)
    # clouds: long flat banks, underlit by the sun (lighter bottoms), darker tops
    rng = np.random.default_rng(4)
    for i in range(9):
        cy = int(rng.integers(40, 190)); cx = int(rng.integers(-40, 320)); cw = int(rng.integers(70, 180)); ch = int(rng.integers(5, 11))
        knots = np.arange(cx - 10, cx + cw + 20, 12)
        top = cy - rng.integers(0, ch, len(knots))
        xs = np.arange(W)
        tl = np.interp(xs, knots, top, left=1e9, right=1e9)
        taper = np.minimum(X - cx, cx + cw - X) * 0.25
        bank = (Y >= tl[None, :]) & (Y <= cy + 2) & (Y >= cy + 2 - taper) & (X >= cx) & (X <= cx + cw)
        cv.idx[bank] = DARKER[cv.idx[bank]]
        under = bank & ~shift(bank, 0, -1)
        cv.idx[under] = LIGHTER[LIGHTER[cv.idx[under]]]
    # the pale sun, low on the horizon, with a stepped halo
    cv.put(ellipse_mask(cv, SUN[0], SUN[1], 15, 15) & (Y < HORIZON), IDX['fade4'])
    cv.put(ellipse_mask(cv, SUN[0], SUN[1], 11, 11) & (Y < HORIZON), IDX['ink10'])
    # far hills, two layers, darkening toward us
    xs = np.arange(W)
    for k, (base, amp, tone, sd) in enumerate([(214, 10, 'ink4', 1), (224, 7, 'ink3', 2)]):
        hy = base - amp * fbm(W, 1, 40, 3, sd)[0] * 2
        hill = (Y >= hy[None, :]) & (Y < HORIZON)
        cv.put(hill, IDX[tone])
        cv.put(hill & ~shift(hill, 0, 1) & (np.abs(X - SUN[0]) < 120), IDX['fade1'])
    # the ghost village: houses half-erased, their lit sides fading into specks
    nz = value_noise(W, H, 3, 51)
    for (hx, hw, hh, gone) in [(14, 22, 16, 0.25), (40, 34, 28, 0.3), (84, 26, 22, 0.4), (228, 30, 30, 0.55), (268, 24, 20, 0.65)]:
        hy = HORIZON + 2
        wall = (X >= hx) & (X < hx + hw) & (Y < hy) & (Y >= hy - hh)
        roof = poly_mask(cv, [(hx - 3, hy - hh), (hx + hw / 2, hy - hh - hw * 0.5), (hx + hw + 3, hy - hh)])
        house = wall | roof
        keep = nz > gone
        cv.put(house & keep, IDX['ink3'])
        cv.put(roof & keep, IDX['ink2'])
        cv.put(wall & keep & (X > hx + hw - 5), IDX['fade1'])  # sun-facing side
        cv.put(edge_of(house) & keep, IDX['fade2'])
        win = (np.abs(X - (hx + 7)) < 2.5) & (np.abs(Y - (hy - hh + 8)) < 2.5)
        cv.put(win & keep, IDX['ink1'])
        cv.put((np.abs(X - (hx + hw / 2)) < 3) & (Y > hy - 10) & (Y < hy) & keep, IDX['ink1'])
        rr = np.random.default_rng(hx)
        for i in range(30):
            sx, sy = int(rr.integers(hx, hx + hw)), int(rr.integers(hy - hh - 30, hy - hh + 4))
            cv.idx[sy, sx] = IDX['fade2' if rr.random() < 0.6 else 'fade3']
    # ground: dead grass in stepped bands, tufts catching the backlight
    g = Y >= HORIZON
    gl = np.clip(1 - np.abs(X - SUN[0]) / 200, 0, 1) * np.clip(1 - (Y - HORIZON) / 90, 0, 1)
    cv.shade(g, noisy(gl, 6, 0.2), ramp('ink1', 'ink2', 'ink3', 'ink4'), 0, 0.8)
    rng = np.random.default_rng(12)
    for i in range(160):
        tx, ty = int(rng.integers(0, 330)), int(rng.integers(HORIZON + 3, 352))
        ln = int(rng.integers(2, 6))
        col = 'fade2' if abs(tx - SUN[0]) < 70 and ty < 270 else 'ink3'
        for j in range(ln):
            if 0 <= ty - j < H:
                cv.idx[ty - j, tx + (j // 2) * (1 if i % 2 else -1)] = IDX[col if j == ln - 1 else 'ink2']
    # path of worn stones to where the door was
    for i, (px_, py_) in enumerate([(120, 300), (138, 284), (152, 272), (164, 262)]):
        blob(cv, px_, py_, 9 - i, 3, ramp('ink1', 'ink2', 'ink3', 'ink4'), SUN, amb=0.1)

    if woman:
        m = woman_mask(cv)
        cv.put(m, IDX['ink1'])
        # cloak folds in near-black, then a bright rim where the sun wraps her edges
        for pts in ([(162, 198), (158, 230), (156, 262)], [(180, 206), (184, 236), (188, 262)], [(170, 224), (170, 262)]):
            cv.put(line_mask(cv, pts, 1) & m, IDX['ink2'])
        near = np.clip(1 - np.sqrt((X - SUN[0]) ** 2 + (Y - SUN[1]) ** 2) / 90, 0, 1)
        e1 = m & ~shift(m, -1, 0)
        e2 = m & ~shift(m, 0, 1)
        e3 = m & ~shift(m, 1, 0)
        cv.put((e1 | e2) & (near > 0.15), IDX['fade3'])
        cv.put((e1 | e2) & (near > 0.5), IDX['fade4'])
        cv.put(e3 & (near > 0.35), IDX['fade2'])
        inner = edge_of(m)
        inner2 = edge_of(m & ~inner)
        cv.put(inner2 & (near > 0.3) & (cv.idx == IDX['ink1']), IDX['ink3'])
        cv.put(inner & (near > 0.3) & (cv.idx == IDX['ink1']), IDX['fade1'])
        cv.put((e1 | e2) & (near > 0.25), IDX['fade3'])
        cv.put((e1 | e2) & (near > 0.5), IDX['fade4'])
        # face glimpsed under the hood: a sliver of gray cheek
        cv.put((np.abs(X - 147) < 2) & (Y > 172) & (Y < 178), IDX['fade1'])
        # her feet dissolving into the grass
        feet = m & (Y > 252) & (value_noise(W, H, 3, 77) < 0.5)
        cv.put(feet, IDX['ink3'])
        if ribbon:
            pts = ribbon_pts()
            rib = line_mask(cv, pts, 3)
            cv.put(outer_edge(rib), IDX['ink1'])
            cv.put(rib, IDX['blood2'])
            cv.put(line_mask(cv, [(x, y - 1) for x, y in pts], 1), IDX['blood3'])
            cv.put(line_mask(cv, [(x, y + 1) for x, y in pts], 1) & rib, IDX['blood1'])
            for i in range(4, 45, 6):
                x, y = pts[i]
                cv.idx[int(y) - 1, int(x)] = IDX['blood4']   # stitched names catching light
            tail = line_mask(cv, [pts[-1], (pts[-1][0] - 6, pts[-1][1] + 5)], 1)
            cv.put(tail, IDX['blood2'])

    vignette(cv, 170, 200, 240, 210, 2.8)
    light_pass(cv, -np.clip((X - 300) / 50.0, 0, 4))
    cv.clean(passes=1)
    return cv


def main():
    full = paint(True, True)
    no_rib = paint(True, False)
    base = paint(False, False)
    base.save(os.path.join(OUT, 'bg.png'))
    diff_layer(no_rib, base, os.path.join(OUT, 'woman.png'))
    diff_layer(full, no_rib, os.path.join(OUT, 'ribbon.png'))
    glow_layer(os.path.join(OUT, 'glow.png'), SUN[0], SUN[1], 60, ['ink3', 'ink4', 'fade1'])
    print('hollowmere done')


if __name__ == '__main__':
    main()
