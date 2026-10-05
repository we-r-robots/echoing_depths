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
  hyprctl dispatch "hl.dsp.exec_cmd('$T/wrap.sh', {float=true, size='${RES/x/ }', no_initial_focus=true})" >/dev/null
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
export LIBGL_ALWAYS_SOFTWARE=1
exec xvfb-run -a -s "-screen 0 ${XVFB_SCREEN:-3840x2160x24}" "$GODOT" --display-driver x11 --rendering-driver opengl3 "$@"
