# Full Play Runtime Performance Review

Owner request, 2026-09-05: play and profile the whole game, review its code, optimize/refactor what is necessary, and update relevant documents. Phase 6 child: `performance-full-play-runtime-review-20260905`. Baseline: `bd42b459`, following the completed Large-town/End Turn improvements.

## Coverage and measurement

- Inventory all shipped runtime subsystem/file owners: boot/router/content, menus/settings, map generation/adoption, overworld movement/pathing/fog/rendering/interactions, town/economy, heroes/artifacts/spells, combat/AI/presentation, strategic AI, objectives/scripts/campaign, persistence and audio/lifecycle. Record which paths were deeply inspected and which only inventoried; do not imply every line or content combination was exhaustively reviewed.
- Complete at least one representative authored scenario in the real scene/router flow through town actions, overworld travel/interactions, legal tactical actions, post-battle reports and outcome. Use deterministic automated controls where practical, clearly distinguished from manual hardware play. No injected victory, added resources/army, teleports or skipped simulation may be called normal-play evidence.
- Exercise campaign progression and save/resume/recovery routes, plus a second faction/combat context where feasible. Label staged domain fixtures separately from complete live playthroughs.
- Exercise deterministic Large setup (`large-runtime-profile-10225`, 108x108, Veilmourn/Orso), legal movement/interactions, town orders and at least ten simulated days or a natural terminal outcome. Record the actual span; short setup/three-turn tests do not stand in for extended play. Keep the prior three-purchase/turn control available.
- Capture full command wall time, first usable scene/frame where relevant, simulation/query/save/render buckets, and process memory. Include autosave, animation/input gating and any deferred work in the appropriate measurement. Do not sum nested timers or compare differently instrumented workloads as speedups.
- Inspect rendered captures at 1920x1080 and 1280x720. Headless CPU and Linux software-rendered evidence is not native Windows/GPU certification.

## Implementation discipline

Fix measured repeated work and correctness defects in affected performance boundaries, not just profiling/report code. Prefer short-lived query contexts and explicit ownership/invalidation over persistent caches with incomplete keys. Preserve costs, prerequisites, development, movement/pathing/fog, AI choices, battle RNG and casualties, progression, content identity, version-9 saves and transaction recovery. Never improve timings by omitting simulation, suppressing legitimate objects or skipping autosaves.

The full input sweep exposed town visual-body snapping trapping the right-stick tile cursor. Correct that input-domain boundary: controller step/reset must select exact grid cells, while pointer/object selection keeps its existing visual-body-to-entrance mapping. Preserve route validation, costs, interactions and gameplay state; verify actual controller preview/cancel/commit and unchanged generated town body entry.

Native RMG semantics are not selected for change. Any necessary native optimization must first identify source-owned behavior and prove supported phase/private-state/final-output equivalence under `docs/lessons-learned.md`, and retain Linux/Windows native parity; otherwise record it as a separate named gap.

Before/after controls must use the same scenario, seed, action sequence, rules and instrumentation. Compare complete state trees where deterministic. If clock/id/presentation fields prevent exact comparison, name each source and isolate it explicitly; never discard gameplay or decision differences to obtain parity. Tests must fail when an optimization changes output, uses stale data, leaks a read scope across mutation or silently turns into a self-comparison.

## Required validation and handoff

Python owns new orchestration/reports; existing engine owners or disposable GDScript probes may drive actual runtime paths. Reuse existing live-validation and regression infrastructure where it exercises the selected behavior honestly. Run:

```sh
python3 tests/validate_repo.py
python3 tests/large_town_turn_optimization_regression.py
python3 tests/named_save_files_regression.py
git diff --check
python3 tests/packaging_linux_export_smoke.py
python3 tests/packaging_windows_export_smoke.py
```

Add the selected full-play/extended-map runner and affected domain regressions to the report. Keep heavy benchmarks isolated and exports serial, save data isolated, both PCKs below 250000000 bytes, and test packaged startup/generated Overworld/Town entry on Linux and Windows (Wine limitations explicit). Preserve pre-existing unrelated untracked retention files and reports.

Update PLAN/progress while work is active; complete only after implemented improvements and real validation. Update `project.md` for durable architecture decisions only, profiling usage when workflows change, and a concise source-backed report with controls, gains, failures, remaining hotspots and review gaps. Commit/push only coherent validated work, verify HEAD against origin/main and report remaining git status. Neither full-play samples nor a code inventory establish whole-product release readiness.
