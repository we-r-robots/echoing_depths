#!/usr/bin/env bash
# Captures the playable-flow screens (each scene's standalone demo) at 1920x1080 and 2340x1080.
# usage: tools/capture_flow.sh [out_dir]      (default captures/flow/latest)
#   writes <out_dir>/<screen>/{1080,phone}/fNNNNN.png at the frames listed below (60 frames = 1 s)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="${1:-captures/flow/latest}"
for sc in title:60,180 pvp_splash:2,60,180 results:60,180 settings:60,180 run_encounter:120,300 road:60,180; do
  n=${sc%%:*}; f=${sc#*:}
  tools/capture.sh res://scenes/flow/$n.tscn "$OUT/$n/1080" "$f" >/dev/null 2>&1 || true
  tools/capture.sh --phone res://scenes/flow/$n.tscn "$OUT/$n/phone" "$f" >/dev/null 2>&1 || true
  echo "  $n"
done
# other demo states of the same scenes: <name>:<scene>:<frames>:<scene arg>
for sc in results_victory:results:180:--outcome=victory pvp_splash_guardian:pvp_splash:180:--mode=guardian pvp_splash_crystal:pvp_splash:180:--mode=crystal; do
  IFS=: read -r n scene f arg <<<"$sc"
  tools/capture.sh res://scenes/flow/$scene.tscn "$OUT/$n/1080" "$f" 1 "$arg" >/dev/null 2>&1 || true
  tools/capture.sh --phone res://scenes/flow/$scene.tscn "$OUT/$n/phone" "$f" 1 "$arg" >/dev/null 2>&1 || true
  echo "  $n"
done
tools/capture.sh res://scenes/lanternrest/lanternrest.tscn "$OUT/lanternrest/1080" 60,180 >/dev/null 2>&1 || true
tools/capture.sh --phone res://scenes/lanternrest/lanternrest.tscn "$OUT/lanternrest/phone" 60,180 >/dev/null 2>&1 || true
echo "  lanternrest (all states: tools/capture_lanternrest.sh)"
echo "done: $OUT"
