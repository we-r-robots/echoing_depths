#!/usr/bin/env bash
# Captures Lanternrest, the top-down 3/4 town (scenes/lanternrest/lanternrest.tscn demo states), at
# 1920x1080 and 2340x1080 (19.5:9 phone).
# usage: tools/capture_lanternrest.sh [out_dir] [state ...]   (default captures/lanternrest/r3, all)
#   writes <out_dir>/<state>/{1080,phone}/f00090.png
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="${1:-captures/lanternrest/r3}"
shift || true
SCENE=res://scenes/lanternrest/lanternrest.tscn
# <state name>|<scene args>
STATES=(
  "fresh|--state=fresh"
  "fresh_west|--state=fresh --cam=west"
  "fresh_east|--state=fresh --cam=east"
  "fresh_north|--state=fresh --cam=north"
  "fresh_south|--state=fresh --cam=south"
  "identity|--state=fresh --panel=identity"
  "built|--state=built"
  "built_new|--state=built --new"
  "menu|--state=built --menu"
  "hover_lantern|--state=built --hover=lantern"
  "hover_vault|--state=built --hover=vault"
  "hover_grounds|--state=built --hover=grounds"
  "hover_plot_w1|--state=built --hover=plot_w1"
  "hover_plot_w2|--state=built --hover=plot_w2"
  "hover_plot_e2|--state=built --hover=plot_e2"
  "hover_plot_s1|--state=built --hover=plot_s1"
  "hover_fog_north|--state=built --hover=fog_north"
  "hover_fog_west|--state=built --hover=fog_west"
  "hover_fog_east|--state=built --hover=fog_east"
  "hover_fog_south|--state=built --hover=fog_south"
  "press_vault|--state=built --press=vault"
  "panel_lantern|--state=built --panel=lantern"
  "panel_vault|--state=built --panel=vault"
  "panel_vault_saved|--state=built --panel=vault --saved"
  "panel_grounds|--state=built --panel=grounds"
  "panel_plot|--state=built --panel=plot_w1"
  "panel_plot_s1|--state=built --panel=plot_s1"
  "panel_fog_north|--state=fresh --panel=fog_north"
  "panel_fog_east|--state=fresh --panel=fog_east"
)
only=("$@")
for st in "${STATES[@]}"; do
  n=${st%%|*}; args=${st#*|}
  if (( ${#only[@]} )) && [[ ! " ${only[*]} " =~ " $n " ]]; then continue; fi
  # shellcheck disable=SC2086
  tools/capture.sh "$SCENE" "$OUT/$n/1080" 90 1 $args >/dev/null 2>&1 || true
  # shellcheck disable=SC2086
  tools/capture.sh --phone "$SCENE" "$OUT/$n/phone" 90 1 $args >/dev/null 2>&1 || true
  echo "  $n"
done
echo "done: $OUT"
