# AGENTS.md

This repository is for a full-production, release-bound fantasy strategy game inspired by the feel of Heroes of Might and Magic II.

## Read first
- `project.md`
- `PLAN.md`
- `docs/lessons-learned.md`

`docs/lessons-learned.md`, especially "Native RMG Recovery Discipline", is mandatory context before touching native RMG/parity work. It records the owner-called-out source-parity mistakes that must not be repeated, including treating disassembly or partial decompile as complete source, patching from final-map deltas, translating HoMM3 semantics too early, accepting report/gate progress as implementation progress, and iterating experiments instead of naming unrecovered functions or data structures.

For native RMG work, read that file before editing code, tools, validators, reports, or progress claims. Unrecovered H3MapEd functions/data structures must be named as blockers instead of being papered over with heuristics, density scalars, gates, brute-force retries, or final-map delta tuning.

Do not load all of `ops/progress.json` by default. It is an operations tracker, not onboarding context. Use the heroes-progress workflow/helper to query the current implementation status and selected next slice when needed. If available, run: `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress_status.py /root/dev/heroes-like`.

## Authored maps, scenarios and campaigns are archived
- Owner decision, 2026-10-05: every authored map, scenario and campaign is obsolete and will be redone completely. Until the owner selects that rework, put no effort into them: do not add, fix, retune, rebalance or re-validate them, and do not select them as a slice.
- Owner decision, 2026-10-08: they are archived in `archive/authored-scenarios-2026-10-08/` (`scenarios.json`, `campaigns.json`, `terrain_layers.json`, `tools/author_*.py`; see its README). The game offers none of them (archived `domain_status`; the main menu shows Campaign as "Coming soon"), but `ContentService` still loads them by id, so tests keep using them as hidden setups. Do not make them playable again before the rework.
- Owner decision, 2026-10-10: the tests and `tests/validate_repo.py` checks about authored scenarios and campaigns are deleted (see `docs/authored-scenarios-obsolete.md`). The other tests that load an authored scenario only as a harness are quarantined: do not run them, fix them or use them to verify new work. Use generated maps.
- Generated maps, shared content definitions and the scenario/campaign runtime code are not covered and stay live. Plan ids: `content-authored-scenarios-obsolete-20261005`, `content-authored-scenarios-archived-20261008`.

## Planning document roles
- `project.md` is the strategic project document. It defines the game, phases, engine/script/content rules, architecture principles, and durable implementation constraints. Keep it concise and stable. Do not use it as a progress log, implementation diary, or place for near-term note piles.
- `PLAN.md` is the tactical execution plan derived from `project.md`. It breaks phases into concrete implementation slices and references the relevant requirement docs under `docs/`. Keep it executable and compact enough for coding-agent context. Do not append verbose history, worker logs, or progress-tracker prose.
- `ops/progress.json` is the operational implementation tracker for `PLAN.md`. Planned slices should exist there before work begins. Status must represent implementation reality: `pending` before work, `in_progress` while active, `blocked` when blocked, and `completed` only after the implementation and validation satisfy the referenced requirements/docs.
- Requirement/design documents under `docs/` are evidence and specifications. Producing a doc is not the same as completing the implementation slice unless the slice is explicitly documentation-only.
- Do not mark gameplay/system/content slices complete just because a plan, report, or foundation document was produced. Track documentation readiness separately from implementation completion.

## Product rule
- This is not a toy prototype and not a fake MVP. Build toward a shippable product from day one.
- Still work in staged slices. Each slice should strengthen the final architecture, not create throwaway code.

## Implementation progress discipline
- Real implementation progress means one of these changed in the repo: live game behavior, native/runtime behavior, shipped content, production tooling required by the selected slice, or a source-backed recovery artifact that directly unblocks a named implementation step.
- Contracts, diagnostics, reports, gates, audits, metadata surfaces, verifier wiring, snapshots, comparison tables, and progress-file edits are not implementation progress by themselves. They are support work only.
- Do not spend a turn creating new evidence surfaces when the selected work needs runtime/native implementation, unless the user explicitly asks for an audit/report or the evidence is required to validate a same-slice behavior change.
- Do not mark a gameplay, AI, balance, native RMG, save/load, UI, content, or packaging slice complete unless the implemented behavior is present and the relevant validation has passed (as defined in "Validation budget" below). If only a diagnostic changed, the slice is still pending or blocked.
- If implementation is blocked, state the exact missing function, data structure, runtime behavior, source file, or recovered-state proof. Do not describe being "closer", "green", "wired", or "done" when the actual behavior still does not exist.
- For native RMG specifically, checkpoint progress requires native generated state or final map payload behavior to match the recovered H3MapEd private-state/final-writeout comparison for the selected phase. New checkers, exporters, contracts, snapshots, and reports do not count as checkpoint progress unless they accompany that behavior change.

## Validation budget
Owner decision, 2026-10-10. Testing had grown to about half of all agent time, mostly re-running stale tests, and agents wrote more test and probe code than game code. Test the durable behavior, verify your own change, and stop.
- **While working:** run only the one or two tests that cover what you changed. Re-run a test only after changing code it covers.
- **Before pushing to main:** run `python tools/core_suite.py` (Windows, a few minutes). It must pass, apart from entries in `tests/known_failures.txt`. The core suite plus your focused tests is the whole validation for a normal change.
- **A failure your change did not cause:** do not fix it, bisect it, or compare against older commits. If it is a core test, add one line to `tests/known_failures.txt` (`test_name  # what fails, date`). Mention it in the handoff and move on.
- **Linux runs:** only when the change touches native/GDExtension code, file paths, the save format, RNG/determinism, the build or packaging. In those cases run `tools/core_suite.py` on Linux once. Otherwise Windows is enough.
- **AI-vs-AI matches, full-match quality runs, performance profiles and balance sweeps:** only when the owner asks. They are evaluation tools, not regression tests.
- **`tests/validate_repo.py`:** the content check, the first step of `tools/core_suite.py` (a few seconds, no Godot). It checks that content JSON parses, ids are unique, `<domain>_id` references resolve, art manifests cover every unit, hero, spell, building and faction, runtime `res://` files exist, and scenes are wired. It must pass. Keep it generic: do not add checks for one slice, source text, UI strings, file sizes or tuned numbers.
- **New tests:** do not add a test file for every change. A bug fix in a core area adds a case to the core test that covers it. If no core test covers that area, add one and list it in `CORE_TESTS` in `tools/core_suite.py`. Check feature and UI work by running the game once (with a screenshot for visual work), not with a permanent report scene.
- **What a test may assert:** behavior that rarely changes and breaks the game when wrong. Examples are scripts compiling, boot, deterministic generation and battles, a generated game launching, save/load, elimination and victory, economy and town rules, and content schemas. Never assert exact UI strings, layout coordinates, balance numbers designers tune, or the source text of other files.
- **Probes and match runners:** write them only to debug a specific failure. Keep them in the scratchpad and delete them at the end.
- **Unchanged:** native RMG parity checks per `docs/lessons-learned.md`, and full export/packaging validation on both platforms for release candidates.

## Engineering rules
- Default engine assumption: Godot 4 unless a documented decision in `project.md` changes it.
- Mandatory platform target: the game is both Windows and Linux, not Linux-only. Any engine, native/GDExtension, build, packaging, file-path, save/load, tooling, or validation work must consider both platforms up front. Code must work on both; running tests on both is required only for the change types listed under "Validation budget".
- For native/GDExtension work, keep Linux and Windows build outputs, `.gdextension` library entries, helper scripts, docs, and validation expectations in sync. Do not land Linux-only native changes unless the slice explicitly records a temporary Windows blocker and follow-up.
- Godot's `.import` and `.uid` sidecars are tracked (owner decision, 2026-10-10): they hold each asset's import settings and stable id. Commit new art, audio and scripts together with their sidecars; if Godot has not written them yet, run a headless import (`godot --headless --path . --import`) first. Sidecars of archived source media under `art/*/source/` stay ignored with the media. Only the `.godot/` cache stays out of Git.
- Prefer data-driven content for factions, heroes, units, spells, map objects, resources, towns, and campaign metadata.
- Keep core systems modular: overworld, combat, AI, economy, save/load, UI, content pipeline.
- Avoid direct cloning of copyrighted names, assets, maps, factions, unit art, music, or text.
- Use original placeholder content where needed.
- No temporary git worktrees. Work directly in this repo.
- Local commits are fine when they are coherent. Always push completed validated work to GitHub and merge it into the default branch when there are no conflicts, unless AcOrP explicitly says otherwise for that slice. If working directly on the default branch, push it without creating an unnecessary merge. If conflicts occur, report them rather than forcing the merge or overwriting remote changes.
- The owner plays and tests from the main checkout (`D:\Games\godot\heroes-like` on Windows), not from agent worktrees. After pushing to the default branch from a worktree or another clone, bring that checkout up to date in the same run, so GitHub is never ahead of the build the owner plays:
  - It must be on the default branch with no local-only commits (`git rev-list --count origin/main..HEAD` is 0).
  - Incoming files must not overlap the owner's uncommitted changes in `git status --short`. Never stash, reset, checkout or discard the owner's local edits or deletions.
  - Update with `git merge --ff-only origin/main`. If it cannot fast-forward, stop and report it instead of forcing.
  - Tell the owner to restart Godot or the running game.

## Screen composition hard rules
- Do not cover the dominant screen surface with large text panels, stacked report boxes, or generic geometry just to expose existing data.
- If information does not fit in compact edge rails, a command spine, a footer pocket, tabs, or contextual popouts, hide it, collapse it, or move it off the main surface instead of laying more panels over the art.
- Scenic screens, especially the main menu, must stay scenery-first. The art or play surface is primary. Text is secondary.
- If a screen starts reading like a text dashboard, panel farm, or placeholder geometry mockup, stop and redesign the composition instead of polishing the same mistake.
- Preserve negative space. Do not spend the whole screen budget on labels, boxes, and explanatory text.
- Main-menu top-level buttons should open secondary menus or overlays for detailed options and selection flows. Do not dump all campaign, skirmish, save, guide, and settings detail directly onto the main menu surface.
- Keep the first-view main menu clean: a few obvious top-level commands on the main screen, deeper selection and configuration only after entering the relevant submenu.

## Process rules
- Update `PLAN.md` when scope, sequencing, or decisions change.
- Update `ops/progress.json` whenever a step starts, completes, or is blocked.
- If you make a major architectural choice, record it clearly in `project.md`.
- Prefer clear folder structure and production-minded tooling over clever hacks.
- Do not treat contracts, diagnostics, reports, gates, audits, metadata surfaces, verifier wiring, snapshots, or comparison tables as implementation progress by themselves. They are allowed only when they directly support or validate a source-backed behavior change in the same slice, or when the slice is explicitly documentation/tooling-only.
- Do not land metadata-only or report-only changes as a substitute for real game/runtime/native behavior. If a diagnostic exposes missing implementation, name the missing function/data structure/behavior as the blocker instead of presenting the diagnostic as progress.
- For native RMG work, follow `docs/lessons-learned.md`: prove recovered H3MapEd behavior through phase/private-state parity before changing generation rules, and do not replace missing recovery with density scalars, gates, brute-force retries, or final-map report tuning.

## Mandatory completion cleanup

- Always perform a cleanup pass after completing work, before the final handoff. Inspect task-created files in the project, `.artifacts`, and temporary locations such as `/tmp`; remove temporary probes, obsolete intermediate exports, disposable test profiles/prefixes, and other task-owned files that are no longer needed.
- Verify exact paths, ownership, and that no active process is using the targets before deleting anything. Never sweep an entire workspace, `.artifacts`, or `/tmp`, and never assume an untracked file is disposable.
- Preserve caches unless the owner explicitly requests cache cleanup. Preserve source, original/generated art and provenance, saves, backups, and all native RMG reverse-engineering material, including disassembly, private-state traces, reference data, and recovery tooling wherever they are stored. Do not modify unrelated pre-existing files.
- Owner retention direction (2026-09-17): do not retain non-RMG generated evidence or temporary artifacts after work is complete. Remove task-owned reports, logs, screenshots, contact sheets, probes, temporary profiles, and test exports/packages, including final validation copies, after reporting the results. Recent timestamps, old KEEP markers, and historical evidence links are not reasons to keep these outputs indefinitely. Keep an actual delivery package only when the owner explicitly requests it; preserve the source and tooling needed to rebuild it. This does not authorize deleting tracked source/design documents, original art/provenance, caches, saves, backups, active-process files, or unrelated data. Keep RMG reverse-engineering evidence intact.
- Measure material cleanup and briefly report what was removed, how much space was recovered, and whether it is rebuildable. If nothing is safely removable, say so; if ownership or retention is unclear, retain the files and ask before deleting them.
- Finish with `git status --short` and confirm cleanup did not remove required deliverables or include unrelated files in the commit.

## Codex execution-host lifecycle
- If a `functions.exec` call returns `Script running with cell ID ...`, do not start another `functions.exec` call. Drain that exact cell with the top-level `functions.wait` tool until it completes, or terminate it explicitly.
- When awaiting `tools.write_stdin` or another long nested tool call inside `functions.exec`, set the outer `// @exec` `yield_time_ms` at least as long as the nested wait. Do not create a new outer cell for every poll of one process.
- On `code-mode host has too many active cells`, stop retrying. Drain every known yielded cell first; if no cell ids remain available, the Codex execution host must be restarted. This is a Codex host failure, not evidence that a repository slice or the game is blocked.

## Completion marker
When finished with a run, print:
`FINAL: <what changed>; TESTS: <result>; STATUS: <done|blocked>`
