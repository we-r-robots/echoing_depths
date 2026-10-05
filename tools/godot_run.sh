#!/usr/bin/env bash
# Run Godot so it can render, on a desktop or headless (cloud) machine.
# With a display (X11/Wayland) it runs Godot directly. Without one it starts a
# virtual X display (Xvfb) and uses Mesa's software OpenGL, which the project's
# GL Compatibility renderer supports.
# usage: tools/godot_run.sh <godot args...>   (set GODOT=/path/to/godot to override)
set -euo pipefail
GODOT="${GODOT:-godot}"
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
  exec "$GODOT" "$@"
fi
command -v xvfb-run >/dev/null || { echo "godot_run: no display and xvfb-run not installed (see tools/cloud_setup.sh)" >&2; exit 1; }
export LIBGL_ALWAYS_SOFTWARE=1
exec xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --display-driver x11 --rendering-driver opengl3 "$@"
