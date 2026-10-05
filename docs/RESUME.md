# Resuming the gauntlet loop

If a session ends mid-run (usage cap, restart), a new lead agent resumes from here.

- Prompt being run: the gauntlet-loop prompt (builder + separate harsh critic per piece, blind A/B vs bar, loop until the critic picks ours).
- Bars: Sea of Stars (art, animation, battle presentation, UI), Super Auto Pets (combat readability/punch), Slay the Spire (encounter screens), 60fps. PC-only testing for now; Android emulator checks deferred, keep the project exportable.
- Live state: `progress/state.json` (piece status + critic rounds), rendered by `python3 progress/render.py` and published to https://claude.ai/artifact/XBLUiLDzGfoaMgHW1ARe6i (republish `progress/index.html`). Log entries: `python3 progress/log.py "<msg>" [piece status]`.
- Builder rules and tools: `docs/BUILD.md`. Blind keys in `captures/.keys/` (critics never read them).
- To resume: read state.json; for any piece in "building", check its files and captures, then run a critic round; for "judging", re-run the critic. Then continue with the next wave.
- Nothing is committed to git unless the user asks.

## Paused 2026-10-03 ~22:00 ET at 93% usage (all agents stopped by the lead; do NOT start queued pieces until the user says so)
Queued and not started: party-formation, run-loop, lanternrest, title.
Each in-flight builder was stopped mid-work. Edits may be half-applied, so check the tree first. The builders can be resumed (SendMessage to the old agent, if still available) or restarted fresh with their round's critic feedback (recorded in progress/state.json "rounds").
- combat-core: round-3 fixes DONE (65 tests pass). Critic round 3 was stopped before reporting, so re-run it (critic scripts in captures/combat-core/critic2/).
- hero-sprites: round-3 rework IN PROGRESS. The builder was hand-drawing full-body key poses at a new, taller scale (Fighter head/torso/cape grids started). Finish all 7 characters, check with captures/hero-sprites/critic2/analyze2.py (idle legs/pelvis move on >=50% of frames, top edge varies >=2 px, attack body shifts >=4 px at contact, anticipation >=2 px lower), fix the Mage neck, KO fall frames, hit squash, monsters. Then blind pairs at matched 3x scale and critic round 3.
- encounter-screen: round-3 rework IN PROGRESS: repainting the Keeper, hound, girl and Hollowmere figures as hand-placed pixel maps (was on the Keeper), plus text size, the Keeper room bake, edge clamp display, recruit payoff, dead space, and the Rogue start matching core. Then re-capture all five, six blind pairs, critic round 3.
- battle-scene: builder had handled the new combat schema (formation_proc, primary, pierce) and was checking the monster fight. Not yet judged. Finish, capture stills and video, blind pairs vs Sea of Stars and Super Auto Pets, critic round 1.
- alignment-ui: round-2 rework just started (grid dominant, legend to one line, bigger brighter text, codex reveal on first entry, step counts consistent). Then blind pairs (tools/blind_pair.py now scales both sides equally) and critic round 2.
OPEN QUESTION FOR THE USER: the Fighter starts at (0,+1) on the neutral axis (core/data/classes.gd), so it has no single super-rare far corner. Ask before changing it.
User requirement: fights use the spec's 2-column x 4-row grid per side with visible formation buffs; never SAP-style lanes (docs/BUILD.md "Spec non-negotiables").

## User decisions 2026-10-04
- Sudden death: time-based only (remove the last-unit trigger `last_stand_sudden_death_ms`). Themed as the Fading: the battle's memory fading, the arena greying, damage escalating.
- QUEUED REDESIGN, do after the current loops pass: formations should give distinct effects per arrangement (each shape its own kind of buff/debuff), not flat stat percentages for the front/back rows. Discuss the design with the user before building.

## Status 2026-10-04 (session at 75%; no new agents to be started this session)
- combat-core: round 5 fixes DONE (68 tests; Fading time-only, reason "fading"; tick KOs 5.8% PvP; back row always x0.5; every formation effect cues once; ~1.2 ms per fight). NEXT: critic round 5 (probes in captures/combat-core/critic4/). Note for the critic: long tails (8 s+) are back at 11–15% by user decision.
- battle-scene: round 5 fixes DONE, captures in captures/battle-scene/r7/ (popups pinned to targets and removed per action, a deeper Fading with a slow colour return, ability board moments incl. Backstab blink, brighter formation procs). Builder's own admitted gaps: the Fading lasts only ~3 s in the demo fight (the sim ends 2 s after it starts, so the demo needs a longer Fading window), adjacent-row multi-hit numbers can overlap for a frame, the Sentinel's number sits ~30 px below its head, lunges not lengthened, Sentinel/Wisp overlap not fixed, colour returns evenly rather than outward from winners, and only some final contact sheets were re-read. NEXT: blind pairs (blind4 method) and critic round 5.
- On hold (user): hero-sprites round 3, encounter-screen round 3, alignment-ui round 2, plus all queued pieces.
- battle-scene blind pairs: use only real COMBAT frames as references (SoS frames with attacks or hits, SAP battle frames 002/031/032), never menus or tooltips. Round 6 scored 3/5, but 2 wins came against menu/tooltip frames.
- combat-core: PASSED critic round 6 (2026-10-04). Polish follow-ups (not blocking, do with the formation redesign): composition buffs in the fight-start banner show names without numbers (narrator.gd `_comps_text`); a CRIT annotation hides the back-row cut on 3.9% of physical hits; party-wide start cues name a single unit; normal Fading ticks still offset side B by 0.2 s; mutual-wipe wins by side HP fraction aren't explained on screen.
