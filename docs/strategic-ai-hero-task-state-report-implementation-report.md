# Strategic AI Hero Task-State Boundary Report Implementation

Status: completed report-only implementation.
Date: 2026-04-26.
Slice: `strategic-ai-hero-task-state-report-implementation-10184`.

## Purpose

Implement the planned `AI_HERO_TASK_STATE_BOUNDARY_REPORT` as a report-only boundary over existing commander-role snapshots and enemy-turn evidence.

This slice does not write `hero_task_state`, migrate saves, bump `SAVE_VERSION`, add durable event logs, add defense-specific durable state, tune coefficients, edit production JSON, implement full AI hero task state, adopt live commander-role behavior, change target selection, change raid movement or arrival, change town-governor choices, change pathing/body-tile/approach behavior, change renderer/editor behavior, import generated PNGs, migrate neutral encounters, add `content/resources.json`, change wood resource ids, activate rare resources, overhaul market caps, rebalance River Pass, push, or open a PR.

## Delivered

- Added report-only AI hero task helpers in `scripts/core/EnemyAdventureRules.gd`.
- Added focused Godot coverage in `tests/ai_hero_task_state_boundary_report.gd` and `.tscn`.
- The report prints one `AI_HERO_TASK_STATE_BOUNDARY_REPORT` payload with:
  - `schema_status: "task_state_boundary_report_only"`
  - `behavior_policy: "derive_candidate_tasks_only"`
  - `save_policy: "no_hero_task_state_write"`
  - `source_policy: "commander_role_adapter_from_report_snapshots"`
- Covered all seven planned cases from `docs/strategic-ai-hero-task-state-report-fixture-plan.md`.

## Helper Boundary

The new helpers derive report views only:

- deterministic candidate task ids;
- role-to-task adapter records from commander-role report proposals;
- resource target snapshots;
- actor ownership checks against commander rosters;
- target ownership checks against current resource controllers;
- report-only exclusive/shared/no-reservation handling;
- controller-flip transition reporting for retake-to-defend handoff;
- old-save absence inspection for missing `enemy_states[].hero_task_state`;
- compact public task events;
- recursive public leak checks.

The helpers do not call target selection, do not drive movement or arrival, do not write task boards, and do not alter save normalization. The Glassroad transition fixture observes existing `EnemyTurnRules.run_enemy_turn(...)` once to prove the controller-flip boundary; candidate tasks remain diagnostic output only.

## Output Evidence

The passing report proves:

- River Pass Free Company produces deterministic Vaska retake-site candidate `task:river-pass:faction_mireclaw:hero_vaska:retake_site:resource:river_free_company:day_1:seq_1`.
- River Pass Signal Post produces deterministic Sable contest-site companion candidate `task:river-pass:faction_mireclaw:hero_sable:contest_site:resource:river_signal_post:day_1:seq_2`.
- Glassroad Watch Relay distinguishes the completed retake intent from the new defend-front candidate after existing raid arrival flips controller to `faction_embercourt`.
- Glassroad Starlens produces an unclaimed/shared-front stabilizer candidate and does not claim a live actor.
- Recovery and rebuild candidates are blocked with `invalid_actor_recovering` and `invalid_actor_rebuilding` and reserve no map target.
- Old-save absence reports `saved_task_board_present: false`, `saved_task_count: 0`, and `SAVE_VERSION` remains `9`.
- Duplicate target reservation arbitration keeps one primary Free Company reservation and marks the duplicate report-only candidate `invalid_target_reserved`.
- Compact public task events omit task ids, source ids, score tables, fixture annotations, route/path fields, save/schema fields, body tiles, and approach data.

## Caveats

- Candidate task id uniqueness is checked per fixture case because the duplicate reservation case intentionally repeats the Free Company primary id as a separate report-only scenario.
- The Glassroad transition fixture mutates a local test session by calling existing enemy-turn logic once; this observes current behavior and does not make candidate tasks behavior-driving.
- Public task events are diagnostic compact surfaces, not a live-client UI composition.

## Validation

Planned validation for the implementation slice:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_hero_task_state_boundary_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_turn_transcript_report.tscn
```

The focused hero task-state boundary report was run during implementation and passed. Full validation results are recorded by the slice completion commands.

## Next Step

Recommended next slice: `strategic-ai-hero-task-state-report-gate-review-10184`.

Review the focused report output and decide whether it is sufficient to keep schema writes, save migration, durable event logs, defense-specific durable state, coefficient tuning, full AI hero task-state implementation, and live commander-role behavior deferred.
