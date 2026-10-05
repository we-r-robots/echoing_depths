#!/usr/bin/env bash
# Re-download the reference footage critics compare against (gitignored, never committed),
# then extract the frames and contact sheets the critic prompts refer to.
# usage: tools/fetch_references.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# 1) Preferred: the private orphan branch `refs` on the GitHub mirror (works in cloud sessions,
#    which can't reach YouTube). It is never merged into the game.
for remote in $(git -C "$ROOT" remote); do
  if git -C "$ROOT" ls-remote --exit-code "$remote" refs/heads/refs >/dev/null 2>&1; then
    git -C "$ROOT" fetch -q "$remote" refs
    git -C "$ROOT" archive FETCH_HEAD references | tar -x -C "$ROOT"
    echo "references ready (from $remote/refs)"
    exit 0
  fi
done
# 2) Fallback: re-download from YouTube with yt-dlp.
mkdir -p "$ROOT/references"; cd "$ROOT/references"
get() { # dir name section url-or-search
  mkdir -p "$1"; [[ -s "$1/$2.mp4" ]] && return 0
  yt-dlp -q --no-warnings -f "bv*[height<=1080][ext=mp4]/bv*[height<=1080]" --download-sections "*$3" -o "$1/$2.%(ext)s" "$4"
}
frames() { # dir video outdir every_n_s
  mkdir -p "$1/$3"; ls "$1/$3"/*.png >/dev/null 2>&1 && return 0
  ffmpeg -loglevel error -y -i "$1/$2" -vf "fps=1/$4,scale=960:-1" "$1/$3/%03d.png"
}
get sea_of_stars   footage  60-420   "https://www.youtube.com/watch?v=hPZ3uauoTVY"
get sea_of_stars   footage2 300-900  "ytsearch1:Sea of Stars walkthrough part 2 no commentary 1080p"
get super_auto_pets footage 60-420   "https://www.youtube.com/watch?v=fIbQsRf5KUg"
get slay_the_spire footage  60-420   "https://www.youtube.com/watch?v=OAmEZuJzSiM"
get slay_the_spire events   300-1500 "https://www.youtube.com/watch?v=om5NhHhkCPI"
frames sea_of_stars footage.mp4 frames 10
frames sea_of_stars footage2.mp4 frames_footage2 8
frames super_auto_pets footage.mp4 frames 10
frames slay_the_spire footage.mp4 frames 10
frames slay_the_spire events.mp4 frames_events 20
echo "references ready"
