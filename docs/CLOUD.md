# Running the build in Claude Code cloud sessions

Cloud sessions run on an Anthropic-managed Ubuntu VM and use the account's cloud session credits first. They work from the **GitHub mirror** (`github` remote, `we-r-robots/echoing_depths`), because cloud sessions can only clone from and push to GitHub. Gitea (`origin`) stays the primary remote.

## One-time environment setup (claude.ai/code)
1. Connect GitHub and pick the repo `we-r-robots/echoing_depths`.
2. Create or edit the environment:
   - **Network access:** Full (needs github.com for the Godot download; YouTube only if critics must re-download reference footage).
   - **Setup script:** paste the body of `tools/cloud_setup.sh` (installs Xvfb, Mesa software OpenGL, ffmpeg, Pillow, yt-dlp and Godot 4.7.2).
3. Start a session on branch `gauntlet-build`.

## Smoke test (first cloud session)
Ask the session to run `tools/smoke.sh` and report the output. It checks the Godot binary, project import, the full test suite, rendering a battle frame (not blank, 640x360), and recording a short video. Rendering uses `tools/godot_run.sh`, which starts a virtual display automatically when no screen exists; it is slower than a GPU, so the capture timeouts are raised.

## Reference footage
`references/` is gitignored (other games' footage is never committed). Cloud critics need it for blind comparisons, so a session must re-download it with `tools/fetch_references.sh` (yt-dlp; sources listed in the script; frame numbering matches the local copies). If YouTube blocks the cloud VM, keep the visual critic rounds local and run logic work (core, run layer, tests) in the cloud.

## Getting work back
A cloud session pushes a branch to GitHub. Locally: `git fetch github`, review, merge into `gauntlet-build`, then `git push origin gauntlet-build` to Gitea (or `claude --teleport <session-id>` to pull the session into the CLI).
