#!/usr/bin/env bash
# Run Godot so it can render, on a desktop or headless (cloud) machine.
# With a display (X11/Wayland) it runs Godot directly. Without one it starts a
# virtual X display (Xvfb) and uses Mesa's software OpenGL, which the project's
# GL Compatibility renderer supports.
# usage: tools/godot_run.sh <godot args...>   (set GODOT=/path/to/godot to override)
# The virtual screen is 3840x2160 (XVFB_SCREEN to override) so 1920x1080, phone-shaped 2340x1080
# and 4K windows all fit without being clamped by the window manager.
set -euo pipefail
GODOT="${GODOT:-godot}"
# Tiling Wayland compositors (Hyprland) resize every new window to its tile, so a capture would
# come out at the tile's size instead of --resolution. On Hyprland the window is launched through
# the compositor with one-off float + size rules for that window only (nothing in the user's
# config changes); output and exit status come back through a temp dir.
RES=""
prev=""
for a in "$@"; do [[ "$prev" == "--resolution" ]] && RES="$a"; prev="$a"; done
XVFB() {
  export LIBGL_ALWAYS_SOFTWARE=1
  exec xvfb-run -a -s "-screen 0 ${XVFB_SCREEN:-3840x2160x24}" "$GODOT" --display-driver x11 --rendering-driver opengl3 "$@"
}
# Capture runs (any run with --resolution) prefer a virtual X display when xvfb-run is installed:
# its window is exactly --resolution whatever the desktop's monitors and scales are
# (GODOT_RUN_DESKTOP=1 keeps them on the desktop).
if [[ -n "$RES" && "${GODOT_RUN_DESKTOP:-0}" != 1 ]] && command -v xvfb-run >/dev/null; then
  XVFB "$@"
fi
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -n "$RES" && "${GODOT_RUN_TILED:-0}" != 1 ]] \
    && command -v hyprctl >/dev/null; then
  T="$(mktemp -d)"
  printf '#!/usr/bin/env bash\necho $$ > %q\n' "$T/pid" > "$T/run.sh"
  printf 'cd %q && exec' "$PWD" >> "$T/run.sh"
  printf ' %q' "$GODOT" "$@" >> "$T/run.sh"
  printf ' > %q 2>&1\n' "$T/log" >> "$T/run.sh"
  chmod +x "$T/run.sh"
  # The wrapper below records godot's exit status once the process ends.
  printf '#!/usr/bin/env bash\n%q\necho $? > %q\n' "$T/run.sh" "$T/status" > "$T/wrap.sh"
  chmod +x "$T/wrap.sh"
  cleanup() { [[ -f "$T/pid" && ! -f "$T/status" ]] && kill "$(cat "$T/pid")" 2>/dev/null; rm -rf "$T"; }
  trap cleanup EXIT
  trap 'exit 124' TERM INT
  # A monitor with scale != 1 (e.g. a 2x laptop panel next to a 1x desktop screen) would give the
  # window a scaled buffer (a 1920x1080 window captured at 3840x2160). Open it on a scale-1 monitor
  # when there is one; otherwise ask for a logical size of RES / scale so the buffer is RES.
  MON="$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
ms = [m for m in json.load(sys.stdin) if not m.get("disabled")]
one = [m for m in ms if abs(m["scale"] - 1) < 1e-3]
if one:
    one.sort(key=lambda m: (not m.get("focused"), -m["width"] * m["height"]))
    print(one[0]["name"], 1)
elif ms:
    m = next((m for m in ms if m.get("focused")), ms[0])
    print(m["name"], m["scale"])
' 2>/dev/null || true)"
  SIZE="${RES/x/ }"; MONRULE=""
  if [[ -n "$MON" ]]; then
    read -r MONNAME MONSCALE <<<"$MON"
    MONRULE=", monitor='$MONNAME'"
    if [[ "$MONSCALE" != 1 ]]; then
      SIZE="$(python3 -c "import sys; w,h=sys.argv[1].split('x'); s=float(sys.argv[2]); print(round(int(w)/s), round(int(h)/s))" "$RES" "$MONSCALE")"
    fi
  fi
  hyprctl dispatch "hl.dsp.exec_cmd('$T/wrap.sh', {float=true, size='$SIZE', no_initial_focus=true$MONRULE})" >/dev/null
  touch "$T/log"
  tail -n +1 -f "$T/log" --pid=$$ &
  TAILPID=$!
  while [[ ! -f "$T/status" ]]; do sleep 0.2; done
  sleep 0.3; kill "$TAILPID" 2>/dev/null || true
  exit "$(cat "$T/status")"
fi
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
  exec "$GODOT" "$@"
fi
command -v xvfb-run >/dev/null || { echo "godot_run: no display and xvfb-run not installed (see tools/cloud_setup.sh)" >&2; exit 1; }
XVFB "$@"
