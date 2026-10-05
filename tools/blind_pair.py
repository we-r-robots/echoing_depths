#!/usr/bin/env python3
"""Make a blind A/B comparison image for a critic.

usage: tools/blind_pair.py <ours.png> <reference.png> <out_pair.png> <piece-name> [WxH]

Both images are fitted to the same frame, 960x540 by default (about a phone
held at arm's length; pass 1920x1080 for a full-size pair), letterboxed on black
(nearest-neighbour for pixel art), and placed side by side in random order,
labelled only "A" and "B". The answer key is appended to captures/.keys/<piece>.txt,
which critics must never read; the lead agent reveals it after the verdict.
"""
import os, random, sys, time
from PIL import Image, ImageDraw

W, H = (int(v) for v in sys.argv[5].split("x")) if len(sys.argv) > 5 else (960, 540)

def fit(path):
    im = Image.open(path).convert("RGB")
    # Treat both sides the same way: first integer-upscale small pixel-art captures
    # toward a 1920x1080 screen (as the game is shown), then fit everything to the
    # comparison frame with the same filter, so neither side looks smaller or blurrier.
    k = max(1, int(min(1920 / im.width, 1080 / im.height)))
    if k > 1:
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    s = min(W / im.width, H / im.height)
    if s < 1:
        im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H))
    canvas.paste(im, ((W - im.width) // 2, (H - im.height) // 2))
    return canvas

ours, ref, out, piece = sys.argv[1:5]
pair = [("ours", fit(ours)), ("reference", fit(ref))]
random.shuffle(pair)
img = Image.new("RGB", (W * 2 + 24, H + 48), (20, 20, 20))
d = ImageDraw.Draw(img)
for i, (_, im) in enumerate(pair):
    x = i * (W + 24)
    img.paste(im, (x, 48))
    d.text((x + W // 2 - 4, 16), "AB"[i], fill=(255, 255, 255))
img.save(out)
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
keys = os.path.join(root, "captures", ".keys")
os.makedirs(keys, exist_ok=True)
with open(os.path.join(keys, f"{piece}.txt"), "a") as f:
    f.write(f"{time.strftime('%F %T')} {out} A={pair[0][0]} B={pair[1][0]}\n")
print(out)
