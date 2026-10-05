#!/usr/bin/env bash
# Capture screenshots of a scene at given frames, unattended, on PC.
# usage: tools/capture.sh <res://scene.tscn> <out_dir> <frames e.g. 30,90,180> [seed]
# The movie-maker fixed fps keeps frame timing deterministic (60 frames = 1s of game time).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENE="$1"; OUT="$(realpath -m "$2")"; AT="$3"; SEED="${4:-1}"
mkdir -p "$OUT"
timeout "${CAPTURE_TIMEOUT:-120}" "$ROOT/tools/godot_run.sh" --path "$ROOT/game" --fixed-fps 60 --disable-vsync --audio-driver Dummy \
  --resolution 1920x1080 -- --scene="$SCENE" --shots="$OUT" --at="$AT" --seed="$SEED" --quit 2>&1 \
  | grep -vE "^(Godot Engine|OpenGL API|$)" || true
ls "$OUT"
