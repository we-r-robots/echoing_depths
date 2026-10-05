#!/usr/bin/env bash
# Record N frames of a scene to mp4 (via Godot movie maker), for critics judging motion.
# usage: tools/video.sh [--phone | --res=WxH] <res://scene.tscn> <out.mp4> <frames> [seed] [scene args...]
#   Records the full window at 1920x1080 by default, 2340x1080 with --phone.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="1920x1080"
case "${1:-}" in
  --phone) RES="2340x1080"; shift ;;
  --res=*) RES="${1#--res=}"; shift ;;
esac
SCENE="$1"; OUT="$(realpath -m "$2")"; N="$3"; SEED="${4:-1}"
shift $(( $# < 4 ? $# : 4 ))
W="${RES%x*}"; H="${RES#*x}"
TMP="$(mktemp -d)"
timeout "${CAPTURE_TIMEOUT:-600}" "$ROOT/tools/godot_run.sh" --path "$ROOT/game" --write-movie "$TMP/m.avi" --fixed-fps 60 --quit-after "$N" \
  --audio-driver Dummy --resolution "$RES" -- --scene="$SCENE" --seed="$SEED" "$@" >/dev/null 2>&1 || true
ffmpeg -y -loglevel error -i "$TMP/m.avi" -vf "scale=${W}:${H}:flags=neighbor" -c:v libx264 -crf 18 -pix_fmt yuv420p "$OUT"
rm -rf "$TMP"; echo "$OUT"
