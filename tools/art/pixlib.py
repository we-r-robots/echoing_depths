"""Tiny pixel-art toolkit for Echoing Depths sprites.

Sprites are authored as text pixel maps (one character per pixel) and composed
into animation frames from parts. Everything is in the master palette.

Global legend (dark -> light inside every ramp):
    .            transparent
    0-9          ink1 .. ink10      (indigo shadow/steel ramp, 9 = near white)
    A-G          amber1 .. amber7
    H-L          crystal1 .. crystal5
    M-P          life1 .. life4
    Q-T          blood1 .. blood4
    U-X          fade1 .. fade4
    a-d          skin1 .. skin4
    v-y          violet1 .. violet4
    #            explicit dark line (ink1), never recoloured by outline passes
A character module may pass its own legend overrides to `Part`.
"""
from __future__ import annotations

import os
import re
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
GPL = os.path.join(ROOT, "game", "assets", "palette", "master.gpl")


def load_gpl(path=GPL):
    pal = {}
    order = []
    with open(path) as f:
        for line in f:
            m = re.match(r"\s*(\d+)\s+(\d+)\s+(\d+)\s+(\S+)", line)
            if m:
                r, g, b, name = m.groups()
                pal[name] = (int(r), int(g), int(b))
                order.append(name)
    return pal, order


PAL, ORDER = load_gpl()

RAMPS = {}
for _n in ORDER:
    m = re.match(r"([a-z]+)(\d+)", _n)
    RAMPS.setdefault(m.group(1), []).append(_n)


def _ramp_legend(chars, ramp):
    return {c: f"{ramp}{i + 1}" for i, c in enumerate(chars)}


LEGEND = {}
LEGEND.update(_ramp_legend("0123456789", "ink"))
LEGEND.update(_ramp_legend("ABCDEFG", "amber"))
LEGEND.update(_ramp_legend("HIJKL", "crystal"))
LEGEND.update(_ramp_legend("MNOP", "life"))
LEGEND.update(_ramp_legend("QRST", "blood"))
LEGEND.update(_ramp_legend("UVWX", "fade"))
LEGEND.update(_ramp_legend("abcd", "skin"))
LEGEND.update(_ramp_legend("vwxy", "violet"))
LEGEND["#"] = "LINE"  # explicit ink1 line, kept by passes
for _n in PAL:
    assert _n in LEGEND.values() or _n == "LINE", _n


def color(name):
    if name == "LINE":
        return PAL["ink1"]
    return PAL[name]


def ramp_of(name):
    if name == "LINE":
        return "ink", 0
    m = re.match(r"([a-z]+)(\d+)", name)
    return m.group(1), int(m.group(2)) - 1


def shade(name, steps):
    """Move `steps` along the colour's own ramp (negative = darker)."""
    if name == "LINE":
        return "LINE"
    r, i = ramp_of(name)
    ramp = RAMPS[r]
    return ramp[max(0, min(len(ramp) - 1, i + steps))]


def parse(grid: str, legend=None):
    leg = dict(LEGEND)
    if legend:
        leg.update(legend)
    rows = [ln.strip() for ln in grid.strip("\n").splitlines()]
    rows = [r for r in rows if r and not r.startswith("//")]
    w = max(len(r) for r in rows)
    px = {}
    for y, row in enumerate(rows):
        row = row.ljust(w, ".")  # short rows are padded with transparency
        for x, ch in enumerate(row):
            if ch in ". ":
                continue
            if ch not in leg:
                raise ValueError(f"unknown pixel char {ch!r} in row {y}: {row!r}")
            px[(x, y)] = leg[ch]
    return px, w, len(rows)


class Part:
    """A pixel map placed at `at` (top-left, canvas coordinates at root offset 0)."""

    def __init__(self, grid, at=(0, 0), legend=None, px=None, size=None):
        if px is not None:
            self.px, (self.w, self.h) = px, size
        else:
            self.px, self.w, self.h = parse(grid, legend)
        self.at = at

    def flipped(self):
        px = {(self.w - 1 - x, y): c for (x, y), c in self.px.items()}
        return Part(None, self.at, px=px, size=(self.w, self.h))

    def recolor(self, mapping):
        px = {k: mapping.get(v, v) for k, v in self.px.items()}
        return Part(None, self.at, px=px, size=(self.w, self.h))

    def moved(self, dx, dy):
        return Part(None, (self.at[0] + dx, self.at[1] + dy), px=self.px, size=(self.w, self.h))

    def sheared(self, y0, amount):
        """Shift rows below y0 sideways, growing linearly to `amount` at the
        bottom row (cloth sway generated from one drawing)."""
        if amount == 0:
            return self
        span = max(1, self.h - 1 - y0)
        px = {}
        for (x, y), c in self.px.items():
            dx = 0 if y < y0 else round(amount * (y - y0) / span)
            px[(x + dx, y)] = c
        return Part(None, self.at, px=px, size=(self.w, self.h))

    def stretched(self, at_row, n=1):
        """Duplicate row `at_row` n times, pushing the rows above it up (the part
        grows upward; its bottom stays put). Used for drawn shoulder rises."""
        px = {}
        for (x, y), c in self.px.items():
            if y < at_row:
                px[(x, y)] = c
            else:
                px[(x, y + n)] = c
            if y == at_row:
                for k in range(n):
                    px[(x, y + k)] = c
        return Part(None, (self.at[0], self.at[1] - n), px=px, size=(self.w, self.h + n))

    def squashed(self, at_row, n=1):
        """Remove n rows starting at `at_row`; rows above drop down (hunch)."""
        px = {}
        for (x, y), c in self.px.items():
            if at_row <= y < at_row + n:
                continue
            px[(x, y if y > at_row else y + n)] = c
        return Part(None, (self.at[0], self.at[1] + n), px=px, size=(self.w, self.h - n))

    def widened(self, at_col, n=1):
        """Duplicate column at_col (chest opens toward the viewer); grows right."""
        px = {}
        for (x, y), c in self.px.items():
            if x < at_col:
                px[(x, y)] = c
            else:
                px[(x + n, y)] = c
            if x == at_col:
                for k in range(1, n + 1):
                    px[(x + k, y)] = c
        return Part(None, self.at, px=px, size=(self.w + n, self.h))

    def narrowed(self, at_col, n=1):
        px = {}
        for (x, y), c in self.px.items():
            if at_col <= x < at_col + n:
                continue
            px[(x if x < at_col else x - n, y)] = c
        return Part(None, (self.at[0] + n, self.at[1]), px=px, size=(self.w - n, self.h))

    def shaded(self, steps, only=None):
        """Move every pixel `steps` along its ramp (turning toward/away from light)."""
        px = {k: (shade(v, steps) if (only is None or ramp_of(v)[0] in only) else v)
              for k, v in self.px.items()}
        return Part(None, self.at, px=px, size=(self.w, self.h))

    def flared(self, y0, amount):
        """Widen rows below y0 about the part's centre, growing to `amount` px on
        each side at the bottom row (robe hems flaring out on a cast)."""
        if amount == 0:
            return self
        span = max(1, self.h - 1 - y0)
        rows = {}
        for (x, y), c in self.px.items():
            rows.setdefault(y, {})[x] = c
        px = {}
        for y, row in rows.items():
            if y < y0:
                for x, c in row.items():
                    px[(x, y)] = c
                continue
            xs = sorted(row)
            x0, x1 = xs[0], xs[-1]
            grow = round(amount * (y - y0) / span)
            nx0, nx1 = x0 - grow, x1 + grow
            for nx in range(nx0, nx1 + 1):
                # nearest-neighbour sample back into the original row
                f = 0 if nx1 == nx0 else (nx - nx0) / (nx1 - nx0)
                sx = round(x0 + f * (x1 - x0))
                while sx not in row and sx < x1:
                    sx += 1
                if sx in row:
                    px[(nx, y)] = row[sx]
        return Part(None, self.at, px=px, size=(self.w + 2 * amount, self.h))

    def rot90(self, k=1):
        """Exact quarter turns (clockwise), pivoting around the top-left."""
        px, w, h = self.px, self.w, self.h
        for _ in range(k % 4):
            px = {(h - 1 - y, x): c for (x, y), c in px.items()}
            w, h = h, w
        return Part(None, self.at, px=px, size=(w, h))


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}
        self.tag = {}  # pixel -> layer id, for separation lines

    def put(self, x, y, c, tag=None):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c
            if tag is not None:
                self.tag[(x, y)] = tag

    def stamp(self, part, dx=0, dy=0, sep=False, tag=None, only_over=False):
        """Draw a part. sep=True draws a darker contour of this part onto pixels
        already on the canvas, so overlapping limbs read as separate shapes."""
        ox, oy = part.at[0] + dx, part.at[1] + dy
        mine = {(x + ox, y + oy) for (x, y) in part.px}
        if sep:
            for (x, y) in mine:
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    q = (nx, ny)
                    if q in mine or q not in self.px:
                        continue
                    c = self.px[q]
                    if c == "LINE":
                        continue
                    self.px[q] = sep_color(c)
        for (x, y), c in part.px.items():
            if only_over and (x + ox, y + oy) not in self.px:
                continue
            self.put(x + ox, y + oy, c, tag)

    def outline(self, mode="selective", lit_side=+1):
        """Outer contour. 'selective': ink1 on the shadow/bottom side and a dark
        tone of the neighbouring ramp on the lit (top/front) side."""
        add = {}
        for (x, y), c in list(self.px.items()):
            for nx, ny, d in ((x + 1, y, "r"), (x - 1, y, "l"), (x, y + 1, "d"), (x, y - 1, "u")):
                if (nx, ny) in self.px or not (0 <= nx < self.w and 0 <= ny < self.h):
                    continue
                if mode == "ink" or c == "LINE":
                    oc = "ink1"
                else:
                    lit = d == "u" or (d == "r" and lit_side > 0) or (d == "l" and lit_side < 0)
                    oc = outline_color(c) if lit else "ink1"
                prev = add.get((nx, ny))
                if prev is None or prev != "ink1" and oc == "ink1":
                    add[(nx, ny)] = oc
        self.px.update(add)

    def rim(self, side=-1, steps=1, y0=0, y1=None, skip=("ink1", "LINE"), color=None, top=True):
        """Back-light: pixels whose `side` neighbour is empty move up their ramp,
        or take a rim `color` (coloured crystal back-light). Run before outline().
        side=-1 lights the left (back) edge; top=True also lights upward edges
        on the back half with one step."""
        y1 = self.h if y1 is None else y1
        ch = {}
        for (x, y), c in self.px.items():
            if c in skip or not (y0 <= y < y1):
                continue
            if (x + side, y) not in self.px:
                ch[(x, y)] = color if color else shade(c, steps)
            elif top and (x, y - 1) not in self.px and (x + side, y - 1) not in self.px:
                ch[(x, y)] = shade(c, 1)
        self.px.update(ch)

    def sheared_rows(self, pivot_y, lean, top_y=None):
        """Lean everything above pivot_y: row y shifts by lean*(pivot-y)/(pivot-top).
        Returns a new canvas (pixels genuinely move, rows stair-step)."""
        ys = [y for _, y in self.px]
        if not ys or lean == 0:
            return self
        top = min(ys) if top_y is None else top_y
        span = max(1, pivot_y - top)
        out = Canvas(self.w, self.h)
        for (x, y), c in self.px.items():
            dx = 0 if y >= pivot_y else round(lean * (pivot_y - y) / span)
            out.put(x + dx, y, c)
        return out

    def merge(self, other, sep=False):
        """Stamp another canvas's pixels on top (optionally with separation line)."""
        self.stamp(Part(None, (0, 0), px=dict(other.px), size=(0, 0)), sep=sep)

    def to_image(self, scale=1, bg=None):
        im = Image.new("RGBA", (self.w, self.h), bg + (255,) if bg else (0, 0, 0, 0))
        p = im.load()
        for (x, y), c in self.px.items():
            p[x, y] = color(c) + (255,)
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        return im


def sep_color(c):
    r, i = ramp_of(c)
    if r == "ink":
        return "ink1" if i <= 3 else shade(c, -3)
    if i <= 1:
        return "ink2"
    return shade(c, -2)


def outline_color(c):
    r, i = ramp_of(c)
    if r in ("ink", "violet", "crystal"):
        return {"ink": "ink1", "violet": "violet1", "crystal": "crystal1"}[r] if r != "ink" else "ink1"
    if r == "skin":
        return "amber1"
    if r == "amber":
        return "amber1"
    if r == "blood":
        return "blood1"
    if r == "life":
        return "life1"
    if r == "fade":
        return "ink2"
    return "ink1"


def flash(canvas, tone="ink10", keep_outline=True):
    """Hit-flash copy: body pixels become a light tone, contour stays dark."""
    out = Canvas(canvas.w, canvas.h)
    for k, c in canvas.px.items():
        if keep_outline and c in ("ink1", "LINE", "blood1", "amber1", "life1", "violet1", "crystal1", "ink2"):
            out.px[k] = "ink2"
        else:
            r, i = ramp_of(c)
            out.px[k] = tone if i >= 1 else "ink8"
    return out


def tint(canvas, ramp_map):
    """Recolour by ramp: {'blood': 'fade'} etc. keeps relative brightness."""
    out = Canvas(canvas.w, canvas.h)
    for k, c in canvas.px.items():
        r, i = ramp_of(c)
        if r in ramp_map:
            tr = RAMPS[ramp_map[r]]
            j = round(i * (len(tr) - 1) / max(1, len(RAMPS[r]) - 1))
            out.px[k] = tr[j]
        else:
            out.px[k] = c
    return out


def line(canvas, x0, y0, x1, y1, c):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        canvas.put(x0, y0, c)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
