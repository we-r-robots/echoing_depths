#!/usr/bin/env bash
# Capture screenshots of a scene at given frames, unattended, on PC.
# usage: tools/capture.sh [--phone | --res=WxH] <res://scene.tscn> <out_dir> <frames e.g. 30,90,180> [seed] [scene args...]
#   Saves the full window at the capture resolution: 1920x1080 by default (16:9), 2340x1080 with
#   --phone (19.5:9). The UI renders at native resolution, the world at 640x360 scaled x3.
#   Scene args are passed to the scene's demo mode, e.g. --unlocked=none, --tip=2, --fight=crystal.
# The movie-maker fixed fps keeps frame timing deterministic (60 frames = 1s of game time).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="1920x1080"
case "${1:-}" in
  --phone) RES="2340x1080"; shift ;;
  --res=*) RES="${1#--res=}"; shift ;;
esac
SCENE="$1"; OUT="$(realpath -m "$2")"; AT="$3"; SEED="${4:-1}"
shift $(( $# < 4 ? $# : 4 ))
mkdir -p "$OUT"
# A window manager may still resize the window (a tiling compositor, rarely even with the float
# rule in godot_run.sh): check every shot is RES and run again (up to 3 tries) when one isn't.
for try in 1 2 3; do
  timeout "${CAPTURE_TIMEOUT:-300}" "$ROOT/tools/godot_run.sh" --path "$ROOT/game" --fixed-fps 60 --disable-vsync --audio-driver Dummy \
    --resolution "$RES" -- --scene="$SCENE" --shots="$OUT" --at="$AT" --seed="$SEED" --quit "$@" 2>&1 \
    | grep -vE "^(Godot Engine|OpenGL API|$)" || true
  python3 - "$OUT" "$RES" "$AT" <<'EOF' && break
import os, sys
from PIL import Image
out, res, at = sys.argv[1], sys.argv[2], sys.argv[3]
want = tuple(int(v) for v in res.split("x"))
bad = [f for f in ("f%05d.png" % int(a) for a in at.split(",")) if os.path.exists(os.path.join(out, f))
       and Image.open(os.path.join(out, f)).size != want]
if bad:
    print("capture: window was not %s for %s, retrying" % (res, ", ".join(bad)), file=sys.stderr)
    sys.exit(1)
EOF
done
ls "$OUT"
