#!/usr/bin/env bash
# Record N frames of a scene to mp4 (via Godot movie maker), for critics judging motion.
# usage: tools/video.sh <res://scene.tscn> <out.mp4> <frames> [seed]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENE="$1"; OUT="$(realpath -m "$2")"; N="$3"; SEED="${4:-1}"
TMP="$(mktemp -d)"
timeout 300 godot --path "$ROOT/game" --write-movie "$TMP/m.avi" --fixed-fps 60 --quit-after "$N" \
  --audio-driver Dummy --resolution 1920x1080 -- --scene="$SCENE" --seed="$SEED" >/dev/null 2>&1 || true
ffmpeg -y -loglevel error -i "$TMP/m.avi" -vf "scale=1920:1080:flags=neighbor" -c:v libx264 -pix_fmt yuv420p "$OUT"
rm -rf "$TMP"; echo "$OUT"
