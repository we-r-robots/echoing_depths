#!/usr/bin/env python3
"""Render progress/state.json into progress/index.html (self-contained, thumbnails inlined)."""
import base64, html, io, json, os, time
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = json.load(open(os.path.join(ROOT, "progress/state.json")))
S["updated"] = time.strftime("%Y-%m-%d %H:%M")
json.dump(S, open(os.path.join(ROOT, "progress/state.json"), "w"), indent=2)
e = html.escape

def thumb(path, w=560):
    p = os.path.join(ROOT, path)
    if not os.path.exists(p):
        return ""
    im = Image.open(p).convert("RGB")
    h = int(im.height * w / im.width)
    im = im.resize((w, h), Image.NEAREST if im.width < w else Image.LANCZOS)
    b = io.BytesIO(); im.save(b, "JPEG", quality=78)
    return "data:image/jpeg;base64," + base64.b64encode(b.getvalue()).decode()

LABEL = {"queued": "Queued", "building": "Building", "judging": "Judging", "won": "Beat the bar", "lost": "Lost round"}
counts = {k: sum(1 for p in S["pieces"] if p["status"] == k) for k in LABEL}
total_rounds = sum(len(p["rounds"]) for p in S["pieces"])

cards = []
for p in S["pieces"]:
    rounds = p["rounds"]
    last = rounds[-1] if rounds else None
    hist = "".join(f'<span class="pip {"w" if r["winner"]=="ours" else "l"}" title="Round {i+1}: {"ours" if r["winner"]=="ours" else "bar"} won"></span>' for i, r in enumerate(rounds))
    body = ""
    if last:
        img = thumb(last.get("image", "")) if last.get("image") else ""
        body += f'<p class="gap"><b>{"Critic picked ours" if last["winner"]=="ours" else "Biggest gap"}:</b> {e(last["gap"])}</p>'
        if img:
            body += f'<figure><img src="{img}" alt="Latest capture for {e(p["name"])}"><figcaption>Round {len(rounds)} capture</figcaption></figure>'
    elif p.get("note"):
        body += f'<p class="gap">{e(p["note"])}</p>'
    if not last and p.get("preview"):
        body += f'<figure><img src="{thumb(p["preview"])}" alt="Latest capture for {e(p["name"])}"><figcaption>Latest capture</figcaption></figure>'
    cards.append(f'''<article class="piece s-{p["status"]}">
  <header><span class="chip">{LABEL[p["status"]]}</span><span class="wave">Wave {p["wave"]}</span></header>
  <h3>{e(p["name"])}</h3>
  <p class="bar">Bar: {e(p["bar"])}</p>
  <div class="pips">{hist or '<span class="none">No rounds yet</span>'}<span class="rc">{len(rounds)} round{"s" if len(rounds)!=1 else ""}</span></div>
  {body}
</article>''')

log = "".join(f'<li><time>{e(l["t"])}</time><span>{e(l["msg"])}</span></li>' for l in reversed(S["log"][-40:]))
bars = "".join(f'<li><b>{e(b["name"])}</b><span>{e(b["covers"])}</span></li>' for b in S["bars"])

out = f'''<title>Echoing Depths Build</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@500;700&family=Atkinson+Hyperlegible:wght@400;700&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
/* Layout: a lantern-lit ledger. Summary strip, then a card per piece, log alongside. */
:root {{
  --bg: #eef0f7; --surface: #ffffff; --ink: #1f1d3a; --muted: #525287; --line: #bfc2dc;
  --amber: #a3502a; --crystal: #1c5a73; --win: #2f5a3a; --lose: #8a1f33; --fade: #77777e;
  --display: "Pixelify Sans", "Courier New", monospace; --body: "Atkinson Hyperlegible", system-ui, sans-serif; --mono: "JetBrains Mono", ui-monospace, monospace;
}}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{
  --bg: #0b0a14; --surface: #151327; --ink: #eceef7; --muted: #9396c0; --line: #2c2a52;
  --amber: #f2a541; --crystal: #4fc4c9; --win: #8bbf5a; --lose: #ff7a6b; --fade: #a7a7ad; color-scheme: dark }} }}
:root[data-theme="dark"] {{
  --bg: #0b0a14; --surface: #151327; --ink: #eceef7; --muted: #9396c0; --line: #2c2a52;
  --amber: #f2a541; --crystal: #4fc4c9; --win: #8bbf5a; --lose: #ff7a6b; --fade: #a7a7ad; color-scheme: dark }}
body {{ background: var(--bg); color: var(--ink); font: 15px/1.5 var(--body); padding: 28px 16px 48px; }}
.wrap {{ max-width: 1180px; margin: 0 auto; display: grid; gap: 28px; }}
h1 {{ font: 700 clamp(28px, 5vw, 44px)/1.05 var(--display); margin: 0; letter-spacing: .01em; text-wrap: balance; }}
h1 em {{ font-style: normal; color: var(--amber); }}
.sub {{ color: var(--muted); margin: 6px 0 0; max-width: 65ch; }}
.meta {{ font: 12px var(--mono); color: var(--muted); margin-top: 10px; }}
.summary {{ display: flex; flex-wrap: wrap; gap: 10px 28px; font: 600 13px var(--mono); border-block: 1px solid var(--line); padding-block: 12px; }}
.summary span b {{ font: 700 22px var(--display); margin-right: 6px; font-variant-numeric: tabular-nums; }}
.cols {{ display: grid; grid-template-columns: minmax(0, 1fr) 300px; gap: 28px; align-items: start; }}
@media (max-width: 860px) {{ .cols {{ grid-template-columns: minmax(0,1fr); }} }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 300px), 1fr)); gap: 16px; }}
.piece {{ background: var(--surface); border: 1px solid var(--line); border-radius: 4px; padding: 14px 16px; display: grid; gap: 6px; align-content: start; min-width: 0; }}
.piece header {{ display: flex; justify-content: space-between; align-items: center; }}
.chip {{ font: 600 11px var(--mono); text-transform: uppercase; letter-spacing: .08em; padding: 2px 8px; border-radius: 2px; border: 1px solid currentColor; color: var(--fade); }}
.s-building .chip, .s-judging .chip {{ color: var(--amber); }}
.s-won .chip {{ color: var(--win); }} .s-lost .chip {{ color: var(--lose); }}
.wave {{ font: 11px var(--mono); color: var(--muted); }}
.piece h3 {{ font: 700 18px/1.2 var(--display); margin: 4px 0 0; }}
.bar {{ margin: 0; color: var(--crystal); font-size: 13px; }}
.pips {{ display: flex; flex-wrap: wrap; gap: 4px; align-items: center; min-height: 14px; }}
.pip {{ width: 10px; height: 10px; }} .pip.w {{ background: var(--win); }} .pip.l {{ background: var(--lose); }}
.none, .rc {{ font: 11px var(--mono); color: var(--muted); }} .rc {{ margin-left: auto; }}
.gap {{ margin: 4px 0 0; font-size: 14px; }}
figure {{ margin: 6px 0 0; }} figure img {{ width: 100%; image-rendering: pixelated; border-radius: 2px; display: block; }}
figcaption {{ font: 11px var(--mono); color: var(--muted); margin-top: 4px; }}
aside {{ display: grid; gap: 24px; min-width: 0; }}
aside h2 {{ font: 700 15px var(--display); margin: 0 0 8px; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); }}
ul {{ list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }}
.bars li {{ display: grid; }} .bars span {{ color: var(--muted); font-size: 13px; }}
.log li {{ display: grid; grid-template-columns: 44px 1fr; gap: 8px; font-size: 13px; }}
.log time {{ font: 11px/1.9 var(--mono); color: var(--muted); }}
</style>
<div class="wrap">
  <div>
    <h1>Echoing <em>Depths</em></h1>
    <p class="sub">A 2D pixel-art auto-battler for PC and Android. Each piece gets a builder and a separate critic. The critic puts our capture next to the bar with labels hidden, and the piece keeps looping until the critic picks ours.</p>
    <p class="meta">Updated {S["updated"]} · Godot 4.7 · 640×360</p>
  </div>
  <div class="summary">
    <span><b>{counts["won"]}</b>beat the bar</span><span><b>{counts["building"]+counts["judging"]}</b>in progress</span><span><b>{counts["queued"]}</b>queued</span><span><b>{total_rounds}</b>critic rounds</span>
  </div>
  <div class="cols">
    <section class="grid">{"".join(cards)}</section>
    <aside>
      <div><h2>The bars</h2><ul class="bars">{bars}</ul></div>
      <div><h2>Activity</h2><ul class="log">{log or "<li><time></time><span>Starting.</span></li>"}</ul></div>
    </aside>
  </div>
</div>
'''
open(os.path.join(ROOT, "progress/index.html"), "w").write(out)
print("progress/index.html", len(out))
