"""The Hound That Forgot Its Name: a gaunt gray hound, profile, snarling, hackles up.
Designed silhouette and fur planes; it stands against dark stone, the cold arch light behind its haunches."""
from kit import *

OUT = os.path.join(ROOT, 'assets', 'encounter', 'hound')
FLOOR = 270
ARCH = (282, 180)
EYE = (96, 160)
FUR = {'hi': 'fade4', 'lit': 'fade3', 'mid': 'fade2', 'low': 'fade1', 'sh': 'ink3', 'deep': 'ink2'}

SIL = [(60, 168), (66, 163), (80, 158), (92, 151), (99, 147), (106, 122), (110, 124), (116, 145), (124, 149),
       (130, 140), (136, 147), (142, 132), (149, 145), (156, 128), (163, 143), (170, 126), (177, 141), (184, 130),
       (191, 145), (199, 136), (205, 149), (218, 154), (236, 158), (252, 162), (264, 168), (272, 182), (272, 200),
       (266, 214), (270, 234), (278, 262), (280, 270), (260, 270), (258, 262), (258, 242), (250, 222), (240, 216),
       (232, 222), (226, 214), (214, 220), (204, 214), (192, 220), (182, 213), (170, 214), (160, 226), (158, 262),
       (162, 270), (140, 270), (142, 262), (138, 230), (128, 214), (116, 204), (106, 196), (96, 190), (86, 192),
       (70, 190), (64, 186), (74, 182), (88, 179), (94, 176), (78, 175), (64, 174)]


def hound(cv):
    X, Y = cv.x, cv.y
    f = np.zeros((H, W), bool)
    # far legs, behind the body, in shadow
    plate(cv, [(150, 214), (164, 214), (170, 262), (174, 270), (156, 270), (156, 262)], 'ink3', hi='fade1', fig=f)
    plate(cv, [(238, 214), (252, 214), (250, 240), (256, 264), (258, 270), (240, 270), (242, 262), (240, 240)], 'ink3', hi='fade1', fig=f)
    # tail: ragged, dissolving upward
    plate(cv, [(262, 168), (274, 150), (282, 128), (290, 122), (288, 134), (282, 152), (272, 172)], FUR['mid'], hi=FUR['hi'], fig=f)
    body = plate(cv, SIL, FUR['mid'], fig=f)
    # big planes: shoulder, ribcage, haunch (lit from behind-right and above), belly in shadow
    plate(cv, [(118, 150), (150, 146), (164, 170), (150, 204), (124, 208), (112, 186)], FUR['low'])           # shoulder in shade
    plate(cv, [(164, 150), (220, 156), (226, 190), (200, 206), (166, 204), (156, 176)], FUR['mid'])           # ribcage
    plate(cv, [(226, 158), (264, 168), (272, 186), (268, 210), (246, 214), (230, 196)], FUR['lit'])           # haunch toward the light
    plate(cv, [(244, 166), (264, 170), (270, 184), (256, 182)], FUR['hi'])
    plate(cv, [(140, 206), (236, 206), (232, 220), (214, 220), (192, 220), (170, 214), (150, 214)], FUR['sh'])  # belly
    plate(cv, [(128, 212), (156, 214), (158, 262), (142, 262), (138, 230)], FUR['low'])                    # near foreleg
    plate(cv, [(146, 216), (156, 216), (158, 262), (152, 262)], FUR['sh'])
    plate(cv, [(250, 214), (268, 212), (270, 234), (278, 262), (262, 262), (258, 242)], FUR['mid'])        # near hind leg
    plate(cv, [(262, 214), (268, 214), (270, 234), (276, 260), (270, 260), (264, 236)], FUR['lit'])
    # rib shadows
    for k in range(4):
        cv.put(line_mask(cv, [(176 + k * 11, 172), (182 + k * 11, 200)], 1) & body, IDX['fade1'])
    # head planes: forehead lit, cheek, muzzle, jaw in shadow
    plate(cv, [(80, 158), (99, 147), (118, 150), (112, 166), (92, 166)], FUR['lit'])
    plate(cv, [(92, 166), (112, 166), (116, 186), (98, 190), (88, 180)], FUR['low'])
    plate(cv, [(60, 168), (80, 158), (92, 166), (88, 176), (64, 174)], FUR['mid'])
    plate(cv, [(62, 168), (80, 160), (84, 162), (66, 168)], FUR['hi'])
    # ear: inner shadow
    plate(cv, [(103, 144), (108, 126), (112, 144)], 'ink3')
    # hackles catch the cold light
    for i in range(0, 20, 2):
        a = SIL[9 + i // 2] if 9 + i // 2 < 21 else SIL[20]
    rim(cv, f, 0, -1, FUR['hi'], (X > 125) & (X < 270))
    rim(cv, f, 1, 0, FUR['hi'], X > 200)
    rim(cv, f, 1, 0, FUR['lit'], X <= 200)
    # fur texture: short strokes raked back along the body
    rng = np.random.default_rng(8)
    ys, xs = np.nonzero(body & (X > 110) & (X < 260))
    for i in range(160):
        k = rng.integers(0, len(xs))
        x, y = xs[k], ys[k]
        tone = cv.idx[y, x]
        L = int(rng.integers(2, 5))
        for j in range(L):
            yy, xx = y + j // 2, x + j
            if body[yy, xx]:
                cv.idx[yy, xx] = DARKER[tone] if i % 3 else LIGHTER[tone]
    # the snarl: open mouth, dark gums, two fangs each side
    mouth = poly_mask(cv, [(66, 175), (94, 177), (92, 181), (72, 184)])
    cv.put(mouth, IDX['blood1'])
    cv.put(mouth & ~shift(mouth, 0, -1), IDX['blood2'])
    pmap(cv, 69, 174, ["X", "X", "W", "W"])            # upper canine
    pmap(cv, 83, 176, ["X", "X", "W"])
    pmap(cv, 75, 181, [".", "W", "X", "X"])             # lower canine
    pmap(cv, 61, 167, ["##", "#1"])                     # nose
    cv.put(line_mask(cv, [(86, 162), (98, 158)], 1), IDX['fade1'])   # snarl wrinkles
    cv.put(line_mask(cv, [(84, 166), (94, 163)], 1), IDX['fade1'])
    # eye: one red ember under a heavy brow
    cv.put(line_mask(cv, [(90, 156), (102, 154)], 1), IDX['ink2'])
    pmap(cv, EYE[0] - 2, EYE[1] - 1, ["#RS#", "#ST#", ".##."])
    # the Fading takes its hindquarters: gray static, holes, specks lifting away
    eat = f & (value_noise(W, H, 3, 17) < smoothstep(236, 292, X) * 0.85)
    cv.put(eat & (value_noise(W, H, 2, 5) < 0.5), IDX['ink2'])
    cv.put(eat & (value_noise(W, H, 2, 5) >= 0.5), IDX['fade1'])
    rng = np.random.default_rng(3)
    ys, xs = np.nonzero(f & (X > 236))
    for i in range(120):
        k = rng.integers(0, len(xs))
        d = int(rng.integers(2, 40))
        x = xs[k] + d // 3 + int(rng.integers(-2, 3)); y = ys[k] - d
        if 0 <= y < H and 0 <= x < W:
            cv.idx[y, x] = IDX['fade3' if d < 14 else 'fade1']
    outline(cv, f)
    return f


def room(cv):
    X, Y = cv.x, cv.y
    bricks(cv, Y < FLOOR, base='ink3', alt='ink2', mortar='ink1', seed=4, bh=10, bw=(18, 34))
    # the arch, off to the right behind the haunches, full of cold mist light
    ax, top, hw = ARCH[0], 70, 34
    opening = ((np.abs(X - ax) < hw) & (Y > top + hw) & (Y < FLOOR)) | (((X - ax) ** 2 + (Y - top - hw) ** 2) < hw * hw)
    frame = ((np.abs(X - ax) < hw + 8) & (Y > top + hw) & (Y < FLOOR)) | (((X - ax) ** 2 + (Y - top - hw) ** 2) < (hw + 8) ** 2)
    frame &= ~opening
    cv.put(frame, IDX['ink4'])
    ang = np.arctan2(Y - top - hw, X - ax)
    cv.put(frame & (Y < top + hw) & (np.abs(np.sin(ang * 7)) < 0.12), IDX['ink2'])
    cv.put(frame & (Y >= top + hw) & ((Y.astype(int) % 14) == 0), IDX['ink2'])
    cv.put(outer_edge(frame) & ~opening, IDX['ink1'])
    d = np.sqrt(((X - ax) / 40) ** 2 + ((Y - 190) / 110) ** 2)
    cv.shade(opening, noisy(np.clip(1.1 - d, 0, 1), 11, 0.15), ramp('ink4', 'fade1', 'fade2', 'fade3'), 0.05, 1.0)
    for i in range(6):
        sy = 210 + i * 9
        cv.put(opening & (Y >= sy) & (Y < sy + 2) & (np.abs(X - ax) < 14 + i * 4), IDX['fade1'])
    fl = Y >= FLOOR
    bricks(cv, fl, base='ink3', alt='ink2', mortar='ink1', bh=6, seed=12, bw=(18, 34))
    lp = np.clip(1 - np.sqrt(((X - ax) / 150) ** 2 + ((Y - 230) / 120) ** 2), 0, 1)
    light_pass(cv, noisy(lp * 2.6 - 1.0, 3, 0.4), ~opening)
    tint_pass(cv, lp * 1.3, GRAYM, ~opening)
    # sconce with a dead torch on the left wall, chains
    for cx_, ln in ((40, 120),):
        for yy in range(0, ln, 4):
            cv.put((np.abs(X - cx_) < 1.5) & (Y >= yy) & (Y < yy + 3) & ((yy // 4) % 2 == 0), IDX['ink3'])
            cv.put((np.abs(X - cx_) < 0.6) & (Y >= yy + 2) & (Y < yy + 4), IDX['ink2'])


def outcome_layers(cv, kind):
    """Small after-images left by each outcome."""
    X, Y = cv.x, cv.y
    if kind == 'tufts':     # Brannoc stood his ground: torn fur, claw gouges in the flagstones
        for (x, y) in ((120, 262), (150, 266), (178, 260), (200, 266)):
            pmap(cv, x, y, ["..W.", ".VW.", "VUV.", ".U.."])
        for k in range(3):
            cv.put(line_mask(cv, [(140 + k * 5, 272), (156 + k * 5, 284)], 1), IDX['ink1'])
            cv.put(line_mask(cv, [(141 + k * 5, 272), (157 + k * 5, 284)], 1), IDX['ink4'])
    elif kind == 'dog':     # named, it lies down: a small curled dog, fading
        pmap(cv, 132, 252, [
            ".......####.........",
            ".....##VVVV##.......",
            "....#VWWWWVVU#..##..",
            "...#VWXWWWVVVU##VU#.",
            "..#VWWWWWVVVVUUVU#..",
            ".#VWWWWVVVVVUUUU#...",
            "#UVVVVVVVVUUUUU1#...",
            "#1UUUUUUUUU1111#....",
            ".################...",
        ])
        pmap(cv, 147, 256, ["##"])
    elif kind == 'ash':     # burned: a drift of ash with violet embers
        cv.put(ellipse_mask(cv, 170, 268, 46, 5) & (Y < 271), IDX['fade1'])
        cv.put(ellipse_mask(cv, 170, 266, 30, 3), IDX['fade2'])
        rng = np.random.default_rng(6)
        for i in range(18):
            x, y = 130 + int(rng.integers(0, 80)), 262 + int(rng.integers(0, 8))
            cv.idx[y, x] = IDX['violet3' if i % 3 else 'violet4']


def paint(with_hound=True, extra=None):
    cv = Canvas(W, H, IDX['ink1'])
    X, Y = cv.x, cv.y
    room(cv)
    if with_hound:
        sh = ellipse_mask(cv, 186, 272, 110, 5) & (Y >= FLOOR)
        light_pass(cv, np.full((H, W), -2.0), sh)
        with scaled(170, FLOOR, 1.15):
            hound(cv)
    if extra:
        outcome_layers(cv, extra)
    vignette(cv, 190, 190, 240, 210, 2.8)
    light_pass(cv, -np.clip((X - 320) / 40.0, 0, 4))
    cv.clean(passes=1)
    return cv


def main():
    full = paint(True)
    base = paint(False)
    base.save(os.path.join(OUT, 'bg.png'))
    diff_layer(full, base, os.path.join(OUT, 'hound.png'))
    for k in ('tufts', 'dog', 'ash'):
        diff_layer(paint(False, k), base, os.path.join(OUT, f'{k}.png'))
    XF[0] = (170, FLOOR, 1.15)
    ex, ey = tp(EYE)
    XF[0] = None
    print('eye at', ex, ey)
    glow_layer(os.path.join(OUT, 'glow.png'), ex, ey, 14, ['blood1', 'blood2'])
    glow_layer(os.path.join(OUT, 'mist.png'), ARCH[0], 200, 60, ['ink3', 'ink4'], sy=1.6)
    print('hound done')


if __name__ == '__main__':
    main()
