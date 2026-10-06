#!/usr/bin/env bash
# Re-creates the hires-ui capture set (see captures/hires-ui/INDEX.md for what each file shows).
# usage: tools/capture_hires_ui.sh [out_dir] [screen ...]
#   out_dir  default captures/hires-ui
#   screen   any of: battle crystal monsters classes setup draft encounter hero_detail videos crops before_after
#            (default: all). Stills are written at 1920x1080 into <screen>/1080/ and at 2340x1080
#            (capture.sh --phone) into <screen>/phone/, named by state as in INDEX.md.
# Each (scene, demo args, resolution) runs once and captures all its frames, then the frames are
# renamed. Frame numbers are game frames at a fixed 60 fps (deterministic; seed 1), so a run that
# captures fewer frames gives the same images. Slow on software GL: set CAPTURE_TIMEOUT if needed.
# before_after/ needs the old 640x360 captures in <out_dir>/before/ (made before the hi-res UI task);
# it is skipped when they are missing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$(realpath -m "${1:-captures/hires-ui}")"
shift || true
WANT=("$@")
export CAPTURE_TIMEOUT="${CAPTURE_TIMEOUT:-1500}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

want() {
  [[ ${#WANT[@]} -eq 0 ]] && return 0
  local s
  for s in "${WANT[@]}"; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

# group <screen> <scene> "<name:frame> ..." [scene args...]
# Captures the frames at 1080 and phone and copies them to <OUT>/<screen>/{1080,phone}/<name>.png.
# The env var ENC (if set) is passed as ENCOUNTER_DEMO.
group() {
  local screen="$1" scene="$2" pairs="$3"
  shift 3
  local frames="" p
  for p in $pairs; do frames="${frames:+$frames,}${p#*:}"; done
  local res mode tag dir
  for res in 1080 phone ${WIDE:-}; do
    mode=""; [[ "$res" == phone ]] && mode="--phone"
    # wide: a short desktop window (~2.6:1; Godot renders the largest whole-scale view inside it,
    # 1864x720 for 1890x730)
    [[ "$res" == wide ]] && mode="--res=1890x730"
    tag="$(echo "$screen-$scene-$*-$res" | md5sum | cut -c1-10)"
    dir="$TMP/$tag"
    echo "  $screen/$res: $scene ${*:-} frames $frames"
    ENCOUNTER_DEMO="${ENC:-}" tools/capture.sh $mode "$scene" "$dir" "$frames" 1 "$@" >/dev/null 2>&1 || true
    mkdir -p "$OUT/$screen/$res"
    for p in $pairs; do
      local f; f="$(printf 'f%05d.png' "${p#*:}")"
      if [[ -f "$dir/$f" ]]; then cp "$dir/$f" "$OUT/$screen/$res/${p%%:*}.png"
      else echo "    MISSING $screen/$res/${p%%:*}.png (frame ${p#*:})" >&2; fi
    done
  done
}

# battle screens also capture a wide, short window (round 17: the HUD never covers the board)
WIDE=wide
if want battle; then
  echo "battle"
  group battle res://scenes/battle/battle.tscn "start_intro_cards:90 ability_banner_cleave:400 mid_fight_numbers_cleave_crit:445 smite_beam_ko:492 numbers_crit_firestorm:625 ko_rear_tag:793 banner_waits_corin_cleave:1035 caption_mend_strikes:1250 caption_mend_heals_self:1512 fading_line:1700 fading_readout:1950 victory_first_frame:2129 victory_card:2200"
  group battle res://scenes/battle/battle.tscn "tooltip_open_banner_chip:300" --tip=2
fi

if want crystal; then
  echo "crystal"
  group crystal res://scenes/battle/battle_crystal.tscn "start_intro_cards:90 memory_surfaces_lore:180 ability_banner_memory:720 firestorm_numbers:830 fragment_banner:840 smite_under_lore:1866 fragment_4_of_4_in_the_fading:3332 victory_shard_breaks_free:3472"
fi

if want monsters; then
  echo "monsters"
  group monsters res://scenes/battle/battle_monsters.tscn "caption_and_numbers:433 tall_sentinel_numbers_ko:583 ability_banner_unravel:643"
fi

if want classes; then
  # round 17: the class showcase fights (timed statuses, the approved advanced classes)
  echo "classes"
  group classes res://scenes/battle/battle_classes_a.tscn "a_echo_summoned:680 a_hidden_silhouette:810 a_drive_on_gauges:945 a_stun_blind_rows:1012 a_nameless_husk:1196 a_shackle_caption:1530 a_shackle_swap_walk:1600 a_rune_seal_bind:2222 a_miss_blind:2268 a_skip_turn_lost:2294 a_rekindled:3036"
  group classes res://scenes/battle/battle_classes_b.tscn "b_vanishing_hidden:386 b_retribution_flame:498 b_aegis_strike_shield:622 b_poisoned:800 b_shield_absorb:1224 b_wildfire:1332 b_fire_jumps:1497 b_lumen_ward:1600 b_link_tether:1822"
  group classes res://scenes/battle/battle_classes_c.tscn "c_start_statuses:172 c_pilfer_steals:470 c_hexed_heal_cost:560 c_slow_field:875 c_tithe:1190 c_husk_raised:1424 c_column_ward:1522 c_shield_absorb:1684 c_hexfire_climbs:2262 c_hexfire_top:2275"
  group classes res://scenes/battle/battle_classes_d.tscn "d_riposte_guard:282 d_parry:316 d_keep_watch:380 d_watch_catch:414 d_whirlwind:560 d_long_reach:760 d_reliquary:1040 d_read_the_orders:1145 d_raise_the_aegis:1590 d_bloodletting:1900"
  group classes res://scenes/battle/battle_classes_e.tscn "e_parry:539 e_break_blade_disarm:612 e_cut_the_ropes:732 e_raise_the_aegis:890 e_disarmed_skip:927 e_nameless_husk:1200"
  group classes res://scenes/battle/battle_classes_c.tscn "c_status_tooltip:240" --status-tip=1.0
  group classes res://scenes/battle/battle_classes_b.tscn "b_unit_card:420" --unit-tip=1.0
fi


WIDE=""
if want setup; then
  echo "setup"
  group setup res://scenes/party_setup/formation_setup.tscn "active_kindred:60 drag_preview_tidebreak:150 drag_preview_locked_crescent:250 tooltip_open:420 locked_fallback:540 unformed:640 unformed_details:700 active_keepers_ring_confirmed:1050"
  group setup res://scenes/party_setup/formation_setup.tscn "strays:120" --demo=strays
  group setup res://scenes/party_setup/formation_setup.tscn "no_shapes_unlocked_drag_preview:150 no_shapes_unlocked_locked_row_tooltip:420 no_shapes_unlocked_unformed:640" --unlocked=none
fi

if want draft; then
  echo "draft"
  group draft res://scenes/party_setup/draft.tscn "no_picks:60 first_pick:120 two_picked:240 changed_mind:480 set_out:700"
fi

if want encounter; then
  echo "encounter"
  group encounter res://scenes/encounter/encounter.tscn "colossus_choices:150 colossus_resolved:480"
  # (a scene arg, not the ENCOUNTER_DEMO env var: on Hyprland godot_run.sh launches through hyprctl,
  # which doesn't pass the environment, so round 2's hound captures were the colossus)
  group encounter res://scenes/encounter/encounter.tscn "hound_choices:150 hound_resolved:480" --encounter=hollow_hound:name_it
fi

if want hero_detail; then
  echo "hero_detail"
  group hero_detail res://scenes/party/hero_detail.tscn "ilse_relic_bound:120 brannoc_ready:240 advancement_prompt:420 advanced_paladin:600"
  group hero_detail res://scenes/party/hero_detail.tscn "held_back:600" --demo=hold
fi

if want videos; then
  echo "videos (1920x1080)"
  mkdir -p "$OUT/battle" "$OUT/crystal"
  CAPTURE_TIMEOUT="${VIDEO_TIMEOUT:-3600}" tools/video.sh res://scenes/battle/battle.tscn "$OUT/battle/fight.mp4" 2300 >/dev/null
  CAPTURE_TIMEOUT="${VIDEO_TIMEOUT:-3600}" tools/video.sh res://scenes/battle/battle_crystal.tscn "$OUT/crystal/crystal_demo.mp4" 3560 >/dev/null
  mkdir -p "$OUT/classes"
  for q in a b c d e; do
    case $q in a) n=3400 ;; b) n=2000 ;; c) n=2400 ;; d) n=2050 ;; e) n=2700 ;; esac
    CAPTURE_TIMEOUT="${VIDEO_TIMEOUT:-3600}" tools/video.sh res://scenes/battle/battle_classes_$q.tscn "$OUT/classes/classes_$q.mp4" $n >/dev/null
  done
fi

if want crops; then
  # The same formation-setup frame at x2, x3 and x6, cropped to one design-space region and
  # nearest-zoomed to 12 screen px per design px, stacked: shows the text is crisp at 1080p and 4K.
  echo "crops (1280x720, 1920x1080, 3840x2160)"
  for r in 1280x720 1920x1080 3840x2160; do
    tools/capture.sh --res=$r res://scenes/party_setup/formation_setup.tscn "$TMP/res/$r" 420 >/dev/null 2>&1 || true
  done
  mkdir -p "$OUT/crops"
  python3 - "$TMP/res" "$OUT/crops" <<'EOF'
import sys
from PIL import Image, ImageDraw
src, out = sys.argv[1], sys.argv[2]
regions = {'card': (430, 40, 630, 106), 'heading': (60, 34, 260, 64)}
for name, (x0, y0, x1, y1) in regions.items():
    tiles = []
    for r, s in [('1280x720', 2), ('1920x1080', 3), ('3840x2160', 6)]:
        im = Image.open('%s/%s/f00420.png' % (src, r))
        c = im.crop((x0 * s, y0 * s, x1 * s, y1 * s))
        z = 12 // s
        tiles.append((r, z, c.resize((c.width * z, c.height * z), Image.NEAREST)))
    W = tiles[0][2].width
    H = sum(t.height + 28 for _, _, t in tiles)
    img = Image.new('RGB', (W, H), (30, 30, 30))
    d = ImageDraw.Draw(img)
    y = 0
    for r, z, t in tiles:
        d.text((6, y + 6), '%s  (nearest zoom to 12 px per design px: %dx)' % (r, z), fill=(255, 255, 255))
        img.paste(t, (0, y + 28))
        y += t.height + 28
    img.save('%s/%s_720_1080_4k.png' % (out, name))
    print('   ', name, img.size)
EOF
fi

if want before_after; then
  # Old 640x360 capture shown x3 (nearest, as it was on a 1080p screen) beside the new 1920x1080
  # capture of the same design-space region, then both again at phone size (halved). Needs before/ and the new stills (setup, battle,
  # encounter, draft).
  echo "before_after"
  python3 - "$OUT" <<'EOF'
import os, sys
from PIL import Image, ImageDraw
root = sys.argv[1]
out = os.path.join(root, 'before_after')
cases = {
    'setup_card': ('before/setup/f00420.png', 'setup/1080/tooltip_open.png', (424, 34, 634, 200)),
    'setup_board_labels': ('before/setup/f00420.png', 'setup/1080/tooltip_open.png', (60, 34, 330, 140)),
    'setup_whole': ('before/setup/f00420.png', 'setup/1080/tooltip_open.png', (0, 0, 640, 360)),
    'battle_roster': ('before/battle/f00600.png', 'battle/1080/numbers_crit_firestorm.png', (0, 270, 330, 360)),
    'battle_banner': ('before/battle/f00600.png', 'battle/1080/numbers_crit_firestorm.png', (0, 0, 330, 60)),
    'encounter_text': ('before/encounter/f00480.png', 'encounter/1080/colossus_resolved.png', (336, 60, 636, 180)),
    'draft_card': ('before/draft/f00240.png', 'draft/1080/two_picked.png', (86, 140, 240, 330)),
}
for name, (b, a, (x0, y0, x1, y1)) in cases.items():
    bp, ap = os.path.join(root, b), os.path.join(root, a)
    if not (os.path.exists(bp) and os.path.exists(ap)):
        print('    skip', name, '(missing', bp if not os.path.exists(bp) else ap, ')')
        continue
    os.makedirs(out, exist_ok=True)
    before = Image.open(bp).convert('RGB').crop((x0, y0, x1, y1))
    before = before.resize((before.width * 3, before.height * 3), Image.NEAREST)
    after = Image.open(ap).convert('RGB').crop((x0 * 3, y0 * 3, x1 * 3, y1 * 3))
    w, h = before.width, before.height
    # second row: the same pair at phone size (the 1080p frame shown 960 px wide, LANCZOS)
    bh = before.resize((w // 2, h // 2), Image.LANCZOS)
    ah = after.resize((w // 2, h // 2), Image.LANCZOS)
    img = Image.new('RGB', (w * 2 + 30, h + 40 + h // 2 + 40), (24, 24, 24))
    d = ImageDraw.Draw(img)
    d.text((8, 12), 'BEFORE: 640x360 frame shown x3 at 1080p', fill=(230, 230, 230))
    d.text((w + 38, 12), 'AFTER: native 1920x1080 UI layer (same region)', fill=(230, 230, 230))
    img.paste(before, (0, 40))
    img.paste(after, (w + 30, 40))
    d.text((8, h + 52), 'PHONE SIZE (frame shown 960 px wide): before', fill=(230, 230, 230))
    d.text((w // 2 + 38, h + 52), 'PHONE SIZE: after', fill=(230, 230, 230))
    img.paste(bh, (0, h + 80))
    img.paste(ah, (w // 2 + 30, h + 80))
    img.save(os.path.join(out, name + '.png'))
    print('   ', name, img.size)
EOF
fi

echo "done: $OUT"
