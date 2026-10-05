#!/usr/bin/env python3
"""Preview one character's animations at zoom: tools/art/preview.py fighter [anim] [scale] [out.png]
Writes a strip per animation on a dark indigo background (scratch use)."""
import sys
sys.dont_write_bytecode = True
from PIL import Image
import build

name = sys.argv[1]
anim = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "all" else None
scale = int(sys.argv[3]) if len(sys.argv) > 3 else 6
out = sys.argv[4] if len(sys.argv) > 4 else f"/tmp/prev_{name}.png"
mod = build.load_char(name)
rows = build.render_char(mod)
if anim:
    rows = [r for r in rows if r[0] == anim]
fw, fh = mod.SIZE
maxn = max(len(r[1]) for r in rows)
sheet = Image.new("RGBA", (fw * maxn * scale, fh * len(rows) * scale), (21, 19, 39, 255))
for j, (an, frames, _durs) in enumerate(rows):
    for i, cv in enumerate(frames):
        im = cv.to_image(scale)
        sheet.alpha_composite(im, (i * fw * scale, j * fh * scale))
sheet.save(out)
print(out)
