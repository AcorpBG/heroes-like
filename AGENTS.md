# AGENTS.md

This repository is for a full-production, release-bound fantasy strategy game inspired by the feel of Heroes of Might and Magic II.

## Read first
- `project.md`, then `PLAN.md`.
- `docs/lessons-learned.md` ("Native RMG Recovery Discipline") before any native RMG or parity work: code, tools, validators, reports or progress claims. Name an unrecovered H3MapEd function or data structure as the blocker; never paper over it with heuristics, density scalars, gates, brute-force retries or final-map delta tuning.
- `python tools/progress.py status` for the current state of `ops/progress.json`; don't load the file whole.

## Project files
- `project.md`: the game, its phases, engine, script and content rules, architecture principles and durable constraints. Short and stable, no progress notes. Record major architectural choices here.
- `PLAN.md`: the owner's decisions in force, the open slices with the docs they reference, and "Recently completed".
- `ops/progress.json`: the status of the same slices, entered before work begins: `pending`, `in_progress`, `blocked`, or `completed` once the implementation and its validation meet the referenced docs.
- `docs/`: specifications and evidence. A doc completes only a documentation slice.
- Edit in place, don't append. An open slice has one entry in each file, at most 600 characters: goal, files, owner decision.
- A completed slice becomes one line under "Recently completed", at most 300 characters: id, commit, what changed. Its `progress.json` entry keeps id, status, date, commit and that line.
- Numbers, check counts, logs and evidence go in the commit message or a `docs/` file.
- An owner decision is one dated line under "Owner decisions in force", removed when superseded or done.
- Entries older than 30 days move to the month's file in `docs/plan-history/` and `ops/progress-archive/`. Don't edit the archives; grep them.
- `python tools/progress.py add` and `set-status` write both files in this format; `archive` moves the old entries.
- Budgets: `AGENTS.md` 14 KB, `PLAN.md` 60 KB, `ops/progress.json` 300 KB. `tools/core_suite.py` fails above them (`python tools/progress.py check`); then archive the oldest completed entries. Only the owner raises a budget.
- Several agents work at once: commit only your own hunks of `PLAN.md` and `progress.json`.

## Authored maps, scenarios and campaigns are archived
- Owner decisions, 2026-10-05 to 2026-10-10: every authored map, scenario and campaign is obsolete and will be redone. Until the owner selects that rework, don't add, fix, retune, rebalance, re-validate or select them, and don't make them playable. They are in `archive/authored-scenarios-2026-10-08/` (see its README); `ContentService` still loads them by id as hidden test setups.
- Their tests are deleted (`docs/authored-scenarios-obsolete.md`). Tests that load one only as a harness are quarantined: don't run, fix or use them. Use generated maps.
- Generated maps, shared content definitions and the scenario and campaign runtime code stay live.

## What counts as progress
- Not a toy prototype or a fake MVP: build toward a shippable product in staged slices that strengthen the final architecture, with no throwaway code.
- Progress means a change in live game behavior, native or runtime behavior, shipped content, production tooling the slice needs, or a source-backed recovery artifact that unblocks a named implementation step.
- Contracts, diagnostics, reports, gates, audits, metadata, verifier wiring, snapshots, comparison tables and progress-file edits are support work, not progress. Add them only to validate a behavior change in the same slice, for a documentation or tooling slice, or when the owner asks.
- A gameplay, AI, balance, native RMG, save/load, UI, content or packaging slice is complete only when the behavior is in and its validation passed.
- When blocked, name the missing function, data structure, runtime behavior, source file or recovered-state proof. Don't call it "closer", "green", "wired" or "done".
- Native RMG checkpoint progress needs native generated state or the final map payload to match the recovered H3MapEd private-state and final-writeout comparison for the phase.

## Validation budget
Owner decisions, 2026-10-10 and 2026-10-19: test the durable behavior, verify your own change, and stop.
- While working, run the one or two tests that cover your change, again only after changing code they cover.
- Before pushing to main: `python tools/core_suite.py` (Windows, a few minutes) passes, apart from `tests/known_failures.txt`. That plus your focused tests is the whole validation.
- A failure your change did not cause: don't fix, bisect or compare it. If it is a core test, add `test_name  # what fails, date` to `tests/known_failures.txt` and mention it in the handoff.
- Linux is paused (owner, 2026-10-21) until the owner calls a Linux pass: no Linux builds, runs, tests or server work. Native changes rebuild the Windows libraries only; say in the handoff that the Linux ones fall behind. Keep the code portable. After the pass, the core suite runs once on Linux for native, file-path, save-format, RNG, build or packaging changes.
- AI-vs-AI matches, full-match quality runs, performance profiles and balance sweeps run only when the owner asks.
- `tests/validate_repo.py`, the core suite's content check, must pass. Keep it generic: no checks for one slice, source text, UI strings, file sizes or tuned numbers.
- Verify a fix with a scratchpad check (a probe, a replay of the failing seed) and delete it. Add a core case (`CORE_TESTS` in `tools/core_suite.py`) only for durable game-breaking behavior no core test covers, never for one fix's mechanism; don't brief other sessions to add one. Check feature and UI work by running the game once, with a screenshot for visual work, not with a report scene.
- Tests assert behavior that rarely changes and breaks the game when wrong (compiling, boot, deterministic generation and battles, launching a generated game, save/load, victory, economy and town rules, content schemas), never UI strings, layout coordinates, tuned numbers or other files' source text.
- Unchanged: native RMG parity checks per `docs/lessons-learned.md`, and export and packaging validation on both platforms for release candidates.

## Native rules engine
Owner decisions D5, D8, D10 and D11 (2026-10-20 to 10-23), `docs/native-rules-engine-transition.md`.
- Every rule is native, one copy, under `src/gdextension/rules/core/`. Registries: `port/registry.cpp` (battles), `turn_registry.cpp` and `ai_registry.cpp` (the AI's day), `day_registry.cpp` (day processing), `human_registry.cpp` (the human player, screens, setup, saves, content, editor). The GDScript functions others call are thin wrappers over `BattleEngine`, `TurnEngine`/`AiEngine`, `DayEngine` and `HumanEngine`. A path the port leaves out is a SCRIPT ERROR and a real bug.
- A rule change goes into the C++ only; a battle or day change also needs one six-seed native check against main (`tools/rules_parity.py check`). After a battle change, rebuild `battle_sim_cli`, which the battle AI arena and tuner run (variants are weight sets in `content/battle_ai_weights.json`).
- GDScript-only rules remain in the campaign runtime, the authored scenarios' setup (`ScenarioFactory.create_session`, the authored skirmish browser) until their rework, and the few the transition doc names.
- Map packages and the H3MapEd generator core are one copy in the rules core (`map_packages.cpp`, `map_generation.cpp`); a change needs one six-seed `rules_parity.py check . . --runner-b`. The `MapDocument` and `ScenarioDocument` accessors also have a Godot copy (`src/gdextension/src/map_document.cpp`, `scenario_document.cpp`): change both in one commit.
- A port slice freezes the functions it moves (its `PLAN.md` entry names them) until its merge; urgent fixes land in GDScript on main for the branch to port. On the branch, `HEROES_NATIVE_HUMAN=shadow` checks them on the six seeds, and the merge makes them NATIVE entries (`tools/native_battle_switch.py`); before pushing, one six-seed native check against main plus the core suite. Arena, holdout, edge-probe, payload-corpus and timing runs are only for the formal G1 and phase merges. No review workflows for slice docs.
- Never run parity checks, timing runs or native builds while an owner AI batch is running.

## Engineering rules
- Godot 4, unless `project.md` records otherwise.
- The game ships on Windows and Linux. Code, native builds, `.gdextension` entries, helper scripts and docs work on both and stay in sync; no Linux-only native change without a recorded Windows blocker and follow-up.
- `.import` and `.uid` sidecars are tracked: commit them with new art, audio and scripts (run `godot --headless --path . --import` if missing). Those of archived media under `art/*/source/` stay ignored; only `.godot/` stays out of Git.
- Content is data-driven. Keep overworld, combat, AI, economy, save/load, UI and the content pipeline modular.
- Don't clone copyrighted names, assets, maps, factions, unit art, music or text; use original placeholders.
- Prefer clear folder structure and production-minded tooling over clever hacks.
- Work in the main checkout or your session's own worktree (a Claude app worktree, `heroes-like-pi`); create no other worktrees or clones.

## Git and the owner's checkout
- Commit as `AcorpBG <10956556+AcorpBG@users.noreply.github.com>`; GitHub rejects the private global address.
- Push completed, validated work to main when there are no conflicts, unless AcOrP says otherwise; on main, without a merge commit. Report conflicts; never force.
- The owner plays from `D:\Games\godot\heroes-like`. After pushing to main from anywhere else, update it in the same run:
  - It is on main with no local-only commits (`git rev-list --count origin/main..HEAD` is 0).
  - Incoming files don't overlap the owner's uncommitted changes (`git status --short`). Never stash, reset, checkout or discard them.
  - `git merge --ff-only origin/main`; if it cannot fast-forward, stop and report.
  - A new `src/gdextension/*.gdextension` file needs one `godot --headless --path . --import` there, with a throwaway user profile.
  - Don't replace libraries in `bin/` while a Godot from that checkout has them loaded.
  - Tell the owner to restart Godot or the game.

## Screen composition
- The art or play surface dominates; text is secondary. No large text panels, stacked report boxes or generic geometry over it.
- What doesn't fit edge rails, a command spine, a footer pocket, tabs or popouts is hidden, collapsed or moved off the main surface.
- Scenic screens, the main menu above all, stay scenery-first, with negative space.
- A screen that reads like a text dashboard, panel farm or geometry mockup gets redesigned, not polished.
- The main menu shows a few top-level commands, each opening a secondary menu or overlay.

## Cleanup before the handoff
- Remove the task's own temporary files in the project, `.artifacts` and temp folders: probes, exports, throwaway profiles, reports, logs, screenshots, test packages, final validation copies included; old KEEP markers or evidence links are no reason to keep them. Keep a delivery package only when the owner asks.
- Check paths, ownership and running processes first. Never sweep a whole workspace, `.artifacts` or `/tmp`, and never assume an untracked file is disposable: maps under `maps/` can be the owner's saves.
- Delete with literal absolute paths: no globs under variables, no `$(...)` targets, no `cd && rm`.
- Keep caches, source, art and provenance, saves, backups, files in use, unrelated files and all native RMG reverse-engineering material.
- Report what you removed, the space recovered and whether it is rebuildable; if ownership is unclear, ask. Finish with `git status --short` and check that the commit holds only your files.

## Codex execution-host lifecycle
- If a `functions.exec` call returns `Script running with cell ID ...`, do not start another `functions.exec` call. Drain that exact cell with the top-level `functions.wait` tool until it completes, or terminate it explicitly.
- When awaiting `tools.write_stdin` or another long nested tool call inside `functions.exec`, set the outer `// @exec` `yield_time_ms` at least as long as the nested wait. Do not create a new outer cell for every poll of one process.
- On `code-mode host has too many active cells`, stop retrying. Drain every known yielded cell first; if no cell ids remain available, the Codex execution host must be restarted. This is a Codex host failure, not evidence that a repository slice or the game is blocked.

## Completion marker
When finished with a run, print:
`FINAL: <what changed>; TESTS: <result>; STATUS: <done|blocked>`
