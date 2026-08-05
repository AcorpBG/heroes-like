# AGENTS.md

This repository is for a full-production, release-bound fantasy strategy game inspired by the feel of Heroes of Might and Magic II.

## Read first
- `project.md`
- `PLAN.md`
- `docs/lessons-learned.md`

`docs/lessons-learned.md`, especially "Native RMG Recovery Discipline", is mandatory context before touching native RMG/parity work. It records the owner-called-out source-parity mistakes that must not be repeated, including treating disassembly or partial decompile as complete source, patching from final-map deltas, translating HoMM3 semantics too early, accepting report/gate progress as implementation progress, and iterating experiments instead of naming unrecovered functions or data structures.

For native RMG work, read that file before editing code, tools, validators, reports, or progress claims. Unrecovered H3MapEd functions/data structures must be named as blockers instead of being papered over with heuristics, density scalars, gates, brute-force retries, or final-map delta tuning.

Do not load all of `ops/progress.json` by default. It is an operations tracker, not onboarding context. Use the heroes-progress workflow/helper to query the current implementation status and selected next slice when needed. If available, run: `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress_status.py /root/dev/heroes-like`.

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
- Do not mark a gameplay, AI, balance, native RMG, save/load, UI, content, or packaging slice complete unless the implemented behavior is present and the relevant validation has passed. If only a diagnostic changed, the slice is still pending or blocked.
- If implementation is blocked, state the exact missing function, data structure, runtime behavior, source file, or recovered-state proof. Do not describe being "closer", "green", "wired", or "done" when the actual behavior still does not exist.
- For native RMG specifically, checkpoint progress requires native generated state or final map payload behavior to match the recovered H3MapEd private-state/final-writeout comparison for the selected phase. New checkers, exporters, contracts, snapshots, and reports do not count as checkpoint progress unless they accompany that behavior change.

## Engineering rules
- Default engine assumption: Godot 4 unless a documented decision in `project.md` changes it.
- Mandatory platform target: the game is both Windows and Linux, not Linux-only. Any engine, native/GDExtension, build, packaging, file-path, save/load, tooling, or validation work must consider both platforms up front.
- For native/GDExtension work, keep Linux and Windows build outputs, `.gdextension` library entries, helper scripts, docs, and validation expectations in sync. Do not land Linux-only native changes unless the slice explicitly records a temporary Windows blocker and follow-up.
- Prefer data-driven content for factions, heroes, units, spells, map objects, resources, towns, and campaign metadata.
- Keep core systems modular: overworld, combat, AI, economy, save/load, UI, content pipeline.
- Avoid direct cloning of copyrighted names, assets, maps, factions, unit art, music, or text.
- Use original placeholder content where needed.
- No temporary git worktrees. Work directly in this repo.
- Local commits are fine when they are coherent. Push completed validated work to GitHub unless AcOrP explicitly says not to for that slice.

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

## Codex execution-host lifecycle
- If a `functions.exec` call returns `Script running with cell ID ...`, do not start another `functions.exec` call. Drain that exact cell with the top-level `functions.wait` tool until it completes, or terminate it explicitly.
- When awaiting `tools.write_stdin` or another long nested tool call inside `functions.exec`, set the outer `// @exec` `yield_time_ms` at least as long as the nested wait. Do not create a new outer cell for every poll of one process.
- On `code-mode host has too many active cells`, stop retrying. Drain every known yielded cell first; if no cell ids remain available, the Codex execution host must be restarted. This is a Codex host failure, not evidence that a repository slice or the game is blocked.

## Completion marker
When finished with a run, print:
`FINAL: <what changed>; TESTS: <result>; STATUS: <done|blocked>`
