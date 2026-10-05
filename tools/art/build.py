#!/usr/bin/env python3
"""Build every sprite sheet, SpriteFrames .tres and the FX sheets.

usage: python3 tools/art/build.py            # writes game/assets/sprites/...
       python3 tools/art/build.py --sheet    # also captures/hero-sprites/sheet.png

Each character lives in tools/art/chars/<name>.py and exposes:
    NAME, SIZE=(w, h), ORIGIN=(x, y)   # feet point inside the frame
    ANIMS = [ {name, fps, loop, frames:[(params, duration_multiplier)], events:{}} ]
    render(params) -> pixlib.Canvas    # one finished frame
"""
from __future__ import annotations

import importlib
import json
import os
import sys

sys.dont_write_bytecode = True  # keep tools/art free of __pycache__
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "chars"))

from PIL import Image  # noqa: E402
import pixlib  # noqa: E402

ROOT = pixlib.ROOT
OUT = os.path.join(ROOT, "game", "assets", "sprites")
CHARS = ["fighter", "rogue", "healer", "mage", "wisp", "shardback", "warden", "fx"]


def load_char(name):
    return importlib.import_module(name)


def render_char(mod):
    rows = []
    for an in mod.ANIMS:
        frames, durs = [], []
        for params, dur in an["frames"]:
            frames.append(mod.render(dict(params)))
            durs.append(dur)
        rows.append((an["name"], frames, durs))
    return rows


def write_char(mod, kind="characters"):
    name = mod.NAME
    fw, fh = mod.SIZE
    rows = render_char(mod)
    cols = max(len(r[1]) for r in rows)
    sheet = Image.new("RGBA", (fw * cols, fh * len(rows)), (0, 0, 0, 0))
    for j, (_an, frames, _d) in enumerate(rows):
        for i, cv in enumerate(frames):
            sheet.alpha_composite(cv.to_image(), (i * fw, j * fh))
    d = os.path.join(OUT, kind, name)
    os.makedirs(d, exist_ok=True)
    png = os.path.join(d, f"{name}.png")
    sheet.save(png)
    res_png = "res://" + os.path.relpath(png, os.path.join(ROOT, "game")).replace(os.sep, "/")
    write_tres(os.path.join(d, f"{name}.tres"), res_png, mod, rows)
    meta = {
        "size": [fw, fh],
        "origin": list(mod.ORIGIN),
        "anims": {an["name"]: {"fps": an["fps"], "loop": an["loop"], "frames": len(an["frames"]),
                               "events": an.get("events", {})} for an in mod.ANIMS},
    }
    return rows, meta


def write_tres(path, res_png, mod, rows):
    fw, fh = mod.SIZE
    subs = []
    anim_txt = []
    sid = 0
    for j, (an_name, frames, durs) in enumerate(rows):
        an = next(a for a in mod.ANIMS if a["name"] == an_name)
        fr = []
        for i, d in enumerate(durs):
            sid += 1
            subs.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_{sid}"]\n'
                        f'atlas = ExtResource("1_sheet")\n'
                        f'region = Rect2({i * fw}, {j * fh}, {fw}, {fh})\n')
            fr.append(f'{{\n"duration": {float(d)},\n"texture": SubResource("AtlasTexture_{sid}")\n}}')
        anim_txt.append('{\n"frames": [' + ", ".join(fr) + '],\n'
                        f'"loop": {"true" if an["loop"] else "false"},\n'
                        f'"name": &"{an_name}",\n"speed": {float(an["fps"])}\n}}')
    txt = (f'[gd_resource type="SpriteFrames" load_steps={len(subs) + 2} format=3]\n\n'
           f'[ext_resource type="Texture2D" path="{res_png}" id="1_sheet"]\n\n'
           + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anim_txt) + "]\n")
    with open(path, "w") as f:
        f.write(txt)


def contact_sheet(all_rows, path, scale=3):
    """Every character's frames, 3x, on dark indigo, one block per character."""
    from PIL import ImageDraw
    bg = pixlib.PAL["ink2"]
    pad = 8 * scale
    blocks = []
    for name, mod, rows in all_rows:
        fw, fh = mod.SIZE
        cols = max(len(r[1]) for r in rows)
        label_w = 70 * scale // 3 * 2
        im = Image.new("RGBA", (label_w + fw * cols * scale, fh * len(rows) * scale + 14), bg + (255,))
        dr = ImageDraw.Draw(im)
        dr.text((4, 2), name.upper(), fill=pixlib.PAL["amber6"])
        for j, (an, frames, _d) in enumerate(rows):
            dr.text((4, 14 + j * fh * scale + fh * scale // 2 - 6), an, fill=pixlib.PAL["ink8"])
            for i, cv in enumerate(frames):
                im.alpha_composite(cv.to_image(scale), (label_w + i * fw * scale, 14 + j * fh * scale))
        blocks.append(im)
    W = max(b.width for b in blocks) + 2 * pad
    H = sum(b.height for b in blocks) + pad * (len(blocks) + 1)
    out = Image.new("RGB", (W, H), bg)
    y = pad
    for b in blocks:
        out.paste(b, (pad, y), b)
        y += b.height + pad
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    return path


def main():
    want_sheet = "--sheet" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    metas = {}
    meta_path = os.path.join(OUT, "sprite_meta.json")
    if os.path.exists(meta_path):
        with open(meta_path) as f:
            metas = json.load(f)
    all_rows = []
    for name in CHARS:
        if only and name not in only:
            continue
        mod = load_char(name)
        kind = "fx" if name == "fx" else ("monsters" if getattr(mod, "MONSTER", False) else "heroes")
        rows, meta = write_char(mod, kind)
        meta["kind"] = kind
        meta["path"] = f"res://assets/sprites/{kind}/{name}/{name}.tres"
        metas[name] = meta
        all_rows.append((name, mod, rows))
        print(f"built {kind}/{name}: " + ", ".join(f"{r[0]}({len(r[1])})" for r in rows))
    if not only:
        import env
        env.main(OUT)
    with open(meta_path, "w") as f:
        json.dump(metas, f, indent=1, sort_keys=True)
    if want_sheet:
        p = contact_sheet(all_rows, os.path.join(ROOT, "captures", "hero-sprites", "sheet.png"))
        print("sheet:", p)


if __name__ == "__main__":
    main()
