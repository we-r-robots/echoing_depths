# Running the build in Claude Code cloud sessions

Cloud sessions run on an Anthropic-managed Ubuntu VM and use the account's cloud session credits first. They work from the **GitHub mirror** (`github` remote, `we-r-robots/echoing_depths`), because cloud sessions can only clone from and push to GitHub. Gitea (`origin`) stays the primary remote.

## One-time environment setup (claude.ai/code)
1. Connect GitHub and pick the repo `we-r-robots/echoing_depths`.
2. Create or edit the environment:
   - **Network access:** Full (needs github.com for the Godot download; YouTube only if critics must re-download reference footage).
   - **Setup script:** paste the body of `tools/cloud_setup.sh` (installs Xvfb, Mesa software OpenGL, ffmpeg, Pillow, yt-dlp and Godot 4.7.2).
3. Start a session on branch `gauntlet-build`.

## Smoke test (first cloud session)
Ask the session to run `tools/smoke.sh` and report the output. It checks the Godot binary, project import, the full test suite, Pillow for `python3`, rendering a battle frame (not blank, 640x360), and recording a short video. Rendering uses `tools/godot_run.sh`, which starts a virtual display automatically when no screen exists; it is slower than a GPU, so the capture timeouts are raised.

## Reference footage
`references/` is gitignored (other games' footage is never committed). Cloud critics need it for blind comparisons, so run `tools/fetch_references.sh`: it pulls the stills, contact sheets and 1280-wide clips from the private orphan branch `refs` on GitHub (never merged into the game; GitHub only, not Gitea), and only falls back to yt-dlp if that branch is unreachable. YouTube blocks cloud VMs, so the branch is the cloud path.

## Getting work back
A cloud session pushes a branch to GitHub. Locally: `git fetch github`, review, merge into `gauntlet-build`, then `git push origin gauntlet-build` to Gitea (or `claude --teleport <session-id>` to pull the session into the CLI).

## Working alongside the local session (coordination)
- **Source of truth:** `gauntlet-build` on GitHub. Gitea (`origin` locally) is mirrored from it by the local session.
- **Before starting work and before every push:** `git pull --rebase` on gauntlet-build. Never force-push. Never rewrite pushed history.
- **Small commits, pushed promptly**, each with the co-author trailer, tests green.
- **Ownership:** one task owns a set of files at a time (see the task file in docs/tasks/). Don't edit files outside your task's scope; if you must, say so in the commit message and RESUME.md.
- **Shared log:** append status lines to docs/RESUME.md and `python3 progress/log.py "<msg>"`. The local session publishes the progress page.
- **User decisions:** record them in docs/BUILD.md ("Spec non-negotiables") or the relevant spec file (00-06), never only in chat.
