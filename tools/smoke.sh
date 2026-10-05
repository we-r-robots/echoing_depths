#!/usr/bin/env bash
# Smoke test: can this machine build, test and RENDER the game?
# Prints PASS/FAIL per step. Used to validate a new cloud environment.
# usage: tools/smoke.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0
step() { printf '%-34s' "$1"; }

step "godot binary"
if v=$(godot --version 2>/dev/null); then echo "PASS ($v)"; else echo "FAIL"; exit 1; fi

step "import project"
# A fresh clone has no import cache, and Godot loads the project theme at startup
# before the first scan, logging a load error for every texture and font it uses.
# So on a fresh clone check only from the scan onward, then require a clean warm start.
fresh=0; [[ -d game/.godot/imported ]] || fresh=1
godot --path game --headless --import >/tmp/smoke_import.log 2>&1
if (( fresh )) && grep -q first_scan_filesystem /tmp/smoke_import.log; then
  sed -n '/first_scan_filesystem/,$p' /tmp/smoke_import.log >/tmp/smoke_import_checked.log
  godot --path game --headless --import >>/tmp/smoke_import_checked.log 2>&1
else
  cp /tmp/smoke_import.log /tmp/smoke_import_checked.log
fi
if grep -qiE "^(ERROR|SCRIPT ERROR)" /tmp/smoke_import_checked.log; then echo "FAIL (see /tmp/smoke_import_checked.log)"; fail=1; else echo "PASS"; fi

step "test suite"
out=$(godot --path game --headless -s res://tests/run_all.gd 2>&1 | tail -1)
if echo "$out" | grep -q " 0 failed, 0 engine errors"; then echo "PASS ($out)"; else echo "FAIL ($out)"; fail=1; fi

step "python3 Pillow"
if v=$(python3 -c 'import PIL.Image; print(PIL.__version__)' 2>/dev/null); then echo "PASS ($v)"; else echo "FAIL (python3 cannot import PIL.Image; see tools/cloud_setup.sh)"; fail=1; fi

step "render a battle frame"
rm -rf captures/smoke_cloud
CAPTURE_TIMEOUT=300 tools/capture.sh res://scenes/battle/battle.tscn captures/smoke_cloud 120,600 >/tmp/smoke_capture.log 2>&1
img=captures/smoke_cloud/f00600.png
if [[ -f "$img" ]]; then
  stats=$(python3 - "$img" <<'EOF'
import sys
from PIL import Image, ImageStat
im = Image.open(sys.argv[1]).convert("RGB")
st = ImageStat.Stat(im)
mean = sum(st.mean) / 3
colours = len(im.getcolors(1 << 20) or [])
print(f"{im.size[0]}x{im.size[1]} mean={mean:.1f} colours={colours}")
ok = im.size == (1920, 1080) and mean > 15 and colours > 50
sys.exit(0 if ok else 2)
EOF
)
  if [[ $? -eq 0 ]]; then echo "PASS ($stats)"; else echo "FAIL (blank or wrong size: $stats)"; fail=1; fi
else
  echo "FAIL (no image; see /tmp/smoke_capture.log)"; fail=1
fi

step "record a short video"
CAPTURE_TIMEOUT=300 tools/video.sh res://scenes/battle/battle.tscn captures/smoke_cloud/clip.mp4 180 >/tmp/smoke_video.log 2>&1
if [[ -s captures/smoke_cloud/clip.mp4 ]]; then echo "PASS"; else echo "FAIL (see /tmp/smoke_video.log)"; fail=1; fi

echo
[[ $fail -eq 0 ]] && echo "SMOKE TEST: PASS" || echo "SMOKE TEST: FAIL"
exit $fail
