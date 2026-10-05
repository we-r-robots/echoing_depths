#!/usr/bin/env bash
# Setup for a Claude Code cloud environment (Ubuntu 24.04, runs as root).
# Paste the body of this script into the environment's setup script, or run it
# at session start. Needs network access level "Full" (or Custom allowing
# github.com and the Ubuntu mirrors). Keep it under ~5 minutes so it caches.
set -euo pipefail
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# Virtual display + software OpenGL for Godot rendering, plus capture tooling.
apt-get install -y -qq xvfb xauth libgl1-mesa-dri libglx-mesa0 libgl1 libegl1 \
  libxcursor1 libxinerama1 libxrandr2 libxi6 libxkbcommon0 libasound2t64 \
  ffmpeg python3-pil unzip ca-certificates curl >/dev/null
pip install -q --break-system-packages yt-dlp 2>/dev/null || pip install -q yt-dlp || true

if ! command -v godot >/dev/null; then
  url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/godot.zip"
  unzip -q "$tmp/godot.zip" -d "$tmp"
  install -m 755 "$tmp"/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot
  rm -rf "$tmp"
fi
godot --version
