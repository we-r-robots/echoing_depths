#!/usr/bin/env bash
# Captures Lanternrest (scenes/lanternrest/lanternrest.tscn demo states) at 1920x1080 and 2340x1080.
# usage: tools/capture_lanternrest.sh [out_dir]      (default captures/lanternrest)
#   writes <out_dir>/<state>/{1080,phone}/f00090.png
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="${1:-captures/lanternrest}"
SCENE=res://scenes/lanternrest/lanternrest.tscn
# <state name>|<scene args>
STATES=(
  "fresh|--state=fresh"
  "fresh_west|--state=fresh --scroll=west"
  "fresh_east|--state=fresh --scroll=east"
  "identity|--state=fresh --panel=identity"
  "built|--state=built"
  "built_new|--state=built --new"
  "built_east|--state=built --scroll=east"
  "hover_vault|--state=built --hover=vault"
  "hover_plot|--state=built --scroll=east --hover=plot_e2"
  "panel_lantern|--state=built --panel=lantern"
  "panel_vault|--state=built --panel=vault"
  "panel_vault_saved|--state=built --panel=vault --saved"
  "panel_grounds|--state=built --panel=grounds"
  "panel_plot|--state=built --panel=plot_w1"
  "panel_fog|--state=fresh --panel=fog_east"
)
for st in "${STATES[@]}"; do
  n=${st%%|*}; args=${st#*|}
  # shellcheck disable=SC2086
  tools/capture.sh "$SCENE" "$OUT/$n/1080" 90 1 $args >/dev/null 2>&1 || true
  # shellcheck disable=SC2086
  tools/capture.sh --phone "$SCENE" "$OUT/$n/phone" 90 1 $args >/dev/null 2>&1 || true
  echo "  $n"
done
echo "done: $OUT"
