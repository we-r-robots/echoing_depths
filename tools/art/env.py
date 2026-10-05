"""Showcase environment art: a Memory Vault floor strip and contact shadows.
Deterministic (seeded) so rebuilds are byte-identical."""
import os
import random
from PIL import Image
import pixlib

PAL = pixlib.PAL


def floor(path, w=640, h=112):
    rnd = random.Random(7)
    im = Image.new("RGBA", (w, h), PAL["ink2"] + (255,))
    p = im.load()

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            p[x, y] = PAL[c] + (255,)

    # rows of slabs, taller toward the viewer (cheap perspective)
    rows = [(0, 9), (9, 13), (22, 18), (40, 26), (66, 46)]
    for ri, (y0, rh) in enumerate(rows):
        x = -rnd.randint(0, 40)
        base = ["ink4", "ink4", "ink3", "ink3", "ink2"][ri]
        hi = ["ink5", "ink5", "ink4", "ink4", "ink3"][ri]
        while x < w:
            sw = rnd.randint(40, 70) + ri * 10
            for yy in range(y0, min(h, y0 + rh)):
                for xx in range(x, x + sw):
                    c = base
                    if yy == y0 + 1:
                        c = hi  # lit top lip of each slab
                    put(xx, yy, c)
            # seams
            for yy in range(y0, min(h, y0 + rh)):
                put(x, yy, "ink1")
            for xx in range(x, x + sw):
                put(xx, y0, "ink1" if ri else "ink2")
            # worn chips and cracks
            for _ in range(2 + ri):
                cx, cy = rnd.randint(x + 3, x + sw - 3), rnd.randint(y0 + 3, max(y0 + 3, y0 + rh - 2))
                for k in range(rnd.randint(2, 5)):
                    put(cx + k, cy + (k // 2) * rnd.choice((0, 1)), "ink2" if ri < 3 else "ink1")
            x += sw
    # crystal veins running through the stone, with a few glints
    for _ in range(9):
        x, y = rnd.randint(0, w), rnd.randint(4, h - 10)
        for k in range(rnd.randint(10, 30)):
            put(x, y, "crystal2")
            if k % 7 == 3:
                put(x, y - 1, "crystal3")
            if k % 11 == 5:
                put(x, y, "crystal4")
            x += 1
            y += rnd.choice((-1, 0, 0, 1)) if y > 3 else 1
    # back edge: a thin lit rim where the floor meets the dark
    for x in range(w):
        put(x, 0, "ink6" if (x // 3) % 5 else "ink5")
    im.save(path)


def shadow(path, w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    p = im.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d = ((x - cx) / (w / 2)) ** 2 + ((y - cy) / (h / 2)) ** 2
            if d <= 1:
                p[x, y] = PAL["ink1"] + (255,)
    im.save(path)


def main(out):
    d = os.path.join(out, "env")
    os.makedirs(d, exist_ok=True)
    floor(os.path.join(d, "vault_floor.png"))
    shadow(os.path.join(d, "shadow_s.png"), 22, 5)
    shadow(os.path.join(d, "shadow_m.png"), 34, 6)
    shadow(os.path.join(d, "shadow_l.png"), 40, 7)
