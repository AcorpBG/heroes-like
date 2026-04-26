# Strategic AI Hero Task-State Save-Normalizer Preservation Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-hero-task-state-save-normalizer-preservation-planning-10184`.

## Purpose

Plan a future report-only proof that optional future `enemy_states[].hero_task_state` can be preserved and normalized by `EnemyTurnRules.normalize_enemy_states(...)` when present, while old saves without the field continue to mean no saved tasks.

This slice is planning only. It does not implement report helpers/tests, change `EnemyTurnRules`, write `hero_task_state`, bump `SAVE_VERSION`, migrate saves, add durable event logs, add defense-specific durable state, tune coefficients, edit production JSON, implement full AI hero task state, adopt live commander-role behavior, adopt live AI hero behavior, change target selection, change raid movement or arrival, change town-governor choices, change pathing/body-tile/approach behavior, change renderer/editor behavior, import generated PNGs, migrate neutral encounters, add `content/resources.json`, migrate `wood` to `timber`, activate rare resources, overhaul market caps, rebalance River Pass, push, or open a PR.

## Evidence Boundary

Accepted inputs:

- `docs/strategic-ai-hero-task-state-adoption-sequencing-plan.md` recommends this normalizer preservation planning slice before schema planning or live behavior adoption.
- `docs/strategic-ai-hero-task-state-report-gate-review.md` passed. It proved derived candidate tasks, old-save absence, no save version change, and compact public task events without saved task boards.
- `docs/strategic-ai-hero-task-state-boundary-plan.md` defines the draft future `session.overworld.enemy_states[].hero_task_state` location, task ids, task lifecycle, invalidation rules, old-save policy, and rollback/escape hatch.
- `scripts/core/EnemyTurnRules.gd` currently rebuilds `enemy_states[]` from known fields in `normalize_enemy_states(...)`; an optional future `hero_task_state` field would be dropped unless intentionally preserved or normalized in a later implementation.
- `scripts/core/SessionStateStore.gd` keeps `SAVE_VERSION := 9`.
- `scripts/autoload/SaveService.gd` normalizes top-level payloads through `SessionStateStore.normalize_payload(...)` and writes the current `SAVE_VERSION`; it does not own enemy task semantics.

## Report Marker

Future focused report marker:

```text
AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT
```

The report is a diagnostic gate, not a schema adoption gate. It should use synthetic in-memory fixture payloads only and should print one payload line for automated review.

Top-level payload fields:

```json
{
  "ok": true,
  "schema_status": "hero_task_state_normalizer_preservation_report_only",
  "behavior_policy": "observe_normalization_only",
  "save_policy": "no_hero_task_state_producer_no_disk_write",
  "save_service_policy": "payload_boundary_only_no_ai_task_semantics",
  "save_version_before": 9,
  "save_version_after": 9,
  "cases_reviewed": 0,
  "normalized_enemy_state_checks": [],
  "malformed_state_checks": [],
  "unknown_field_isolation_checks": [],
  "failures": []
}
```

Case payload shape:

```json
{
  "case_id": "future_optional_field_preservation_valid_board",
  "ok": true,
  "scenario_id": "river-pass",
  "faction_id": "faction_mireclaw",
  "input_present": true,
  "normalized_present": true,
  "input_task_count": 1,
  "normalized_task_count": 1,
  "expected_policy": "preserve_explicit_optional_field_only",
  "observed_policy": "preserved_and_normalized",
  "save_version_before": 9,
  "save_version_after": 9,
  "notes": []
}
```

## Preservation Policy

The future proof should establish this policy before any schema writer exists:

- Missing `hero_task_state` remains missing. Do not inject an empty task board into old saves or normalized enemy states.
- A synthetic fixture-only `hero_task_state` dictionary may be preserved by `EnemyTurnRules.normalize_enemy_states(...)` only through an explicit future preservation/normalization branch.
- Preservation is narrow. It must not keep arbitrary unknown enemy-state fields as live state.
- Valid task-state fields should be normalized to ids, enums, bounded ints, arrays of strings, and compact validation codes. Display labels, score tables, fixture annotations, route arrays, body tiles, approach offsets, public reason text, and event logs stay out.
- Malformed future task-state records should be ignored, dropped from the normalized task-state view, or marked invalid in report output. They must not corrupt `commander_roster`, active raids, treasury, posture, pressure, or save version.
- The report must distinguish "field absent", "field present but invalid", "field present and empty", and "field present with valid normalized tasks".
- No report fixture writes task state to a production save file. Disk save/load coverage is deferred until a later schema plan explicitly approves old-save fixtures.

This means the future implementation can prove optional preservation without approving any live producer of `hero_task_state`.

## Fixture Cases

1. `old_save_absence_no_task_board`
   - Input: River Pass session with normal enemy state and no `hero_task_state`.
   - Expected: normalized enemy state still has no `hero_task_state`; report view says `saved_task_board_present: false` and `saved_task_count: 0`.
   - Save expectation: `SAVE_VERSION` stays `9`; no migration warning is required.

2. `future_optional_field_preservation_valid_board`
   - Input: synthetic fixture-only `hero_task_state` with `schema_version: 1`, `planner_epoch`, and one valid `retake_site` task for `river_free_company`.
   - Expected: a later explicit normalizer branch preserves the optional field and normalizes the task record without adding public text, route details, score tables, or fixture annotations.
   - Save expectation: no producer writes this field; the report only observes in-memory normalization.

3. `future_optional_empty_board_preservation`
   - Input: synthetic `hero_task_state` with `schema_version: 1`, `planner_epoch`, and empty `tasks`.
   - Expected: field remains present because it was explicitly present in the input, but task count stays zero. Old-save absence remains distinguishable from explicit empty future state.

4. `malformed_non_dictionary_task_state`
   - Input: `hero_task_state` is a string, array, or number.
   - Expected: report marks the field invalid and normalized view omits it or treats it as no saved tasks. Commander roster continuity and other enemy state fields remain valid.

5. `malformed_task_record_tolerance`
   - Input: `hero_task_state.tasks[]` contains records missing `task_id`, `owner_faction_id`, `actor_id`, `task_class`, or `target_id`, plus one valid task.
   - Expected: invalid records are dropped or marked invalid in report-only details; the valid task remains if the board itself is valid. No duplicate target reservation or live behavior change is triggered.

6. `unknown_task_fields_sanitized`
   - Input: valid task record plus unknown task fields such as `debug_score`, `fixture_state`, `route_tiles`, `approach`, and `public_reason`.
   - Expected: unknown/debug/public/path fields are not preserved in normalized `hero_task_state`; the report records sanitized fields.

7. `unknown_enemy_state_field_isolation`
   - Input: enemy state includes `hero_task_state` and unrelated junk keys such as `debug_ai_blob`, `temporary_planner_state`, and `future_magic_state`.
   - Expected: only the approved known enemy state fields and explicitly handled `hero_task_state` survive. Arbitrary junk is dropped.

8. `save_service_payload_boundary`
   - Input: top-level payload fixture that passes through `SessionStateStore.normalize_payload(...)` / `SaveService` inspection boundaries without asking `SaveService` to interpret task semantics.
   - Expected: `SaveService` remains a payload/version/summary boundary. It does not validate task ids, task classes, reservations, actor ownership, routes, reason codes, or public task events.

9. `commander_roster_continuity_with_malformed_task_state`
   - Input: existing commander roster plus malformed task state.
   - Expected: `EnemyAdventureRules.normalize_commander_roster(...)` output remains stable; malformed task state does not remove commanders, reset recovery, clear active placement links, or rewrite target memory.

## SaveService Boundary

`SaveService` must not become the semantic owner of strategic AI task state.

Allowed SaveService responsibilities:

- reject empty or structurally unsafe payloads;
- call `SessionStateStore.normalize_payload(...)`;
- stamp `save_version` with `SessionStateStore.SAVE_VERSION`;
- maintain save metadata, slot summaries, and restore validity;
- reject saves from newer versions.

Forbidden SaveService responsibilities for this feature:

- validate task ids, task classes, actor ids, target ids, reservations, role adapters, routes, front ids, or reason codes;
- generate or repair `hero_task_state`;
- decide whether tasks are complete, stale, invalid, or executable;
- own migration of strategic AI task semantics;
- produce public AI task events or reason text.

Task-state semantics belong to future enemy-turn/adventure rule helpers. `SaveService` remains a top-level payload boundary.

## Failure Conditions

The future preservation report should fail if any of these occur:

- `SAVE_VERSION` changes during the report.
- Missing `hero_task_state` is treated as an error or is converted into a saved empty board.
- A valid synthetic optional `hero_task_state` is dropped after the later explicit preservation implementation exists.
- Malformed `hero_task_state` corrupts commander roster continuity, active raids, treasury, pressure, posture, captured artifacts, or normalized faction ids.
- Unknown enemy-state junk is preserved as live state.
- Unknown task fields such as score tables, fixture annotations, routes, body tiles, approach offsets, or public reason text survive normalized task-state output.
- `SaveService` gains strategic AI task validation or repair responsibility.
- The report writes a production save, edits production JSON, changes target selection, changes raid movement/arrival, changes town-governor choices, or emits live UI output.

## Exact Implementation Sequence

Future implementation should proceed in this order:

1. Add a pure report-only helper in `EnemyTurnRules.gd` or a narrowly owned helper near it that normalizes a synthetic optional `hero_task_state` dictionary. The helper must not create a task board when the field is absent.
2. Add an explicit preservation branch inside `EnemyTurnRules.normalize_enemy_states(...)` that copies normalized `hero_task_state` only when the source enemy state already has that field and the helper returns a valid optional board.
3. Keep all task semantics minimal: ids, enums, day/epoch ints, reason-code arrays, lifecycle/validation codes, and sanitized task arrays only.
4. Add a focused Godot report scene such as `tests/ai_hero_task_state_normalizer_preservation_report.gd` / `.tscn`.
5. Build the nine synthetic fixture cases in memory from current River Pass and Glassroad scenario sessions. Do not edit production JSON or write save files.
6. Print exactly one `AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT` line.
7. Assert no save version change by checking `SessionStateStore.SAVE_VERSION` before and after.
8. Assert `SaveService` boundary by inspecting that no task semantic helper is added to `SaveService` and by using it only as payload/version context if needed.
9. Add an implementation report document recording the payload result, failure checks, and deferred boundaries.
10. Run validation commands and commit locally only if they pass.

## Validation Commands

For this planning slice and the future report-only implementation gate:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

For the later report implementation only:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_hero_task_state_normalizer_preservation_report.tscn
```

## Rollback And Escape Hatch

For this planning slice:

- No rollback code is needed because no implementation changed.
- If the plan is rejected, remove this document and restore `PLAN.md`, `ops/progress.json`, and `ops/acorp_attention.md` to the previous recommended next slice.

For the future report implementation:

- Remove or disable the focused normalizer preservation report scene/helpers.
- Keep `AI_HERO_TASK_STATE_BOUNDARY_REPORT` as the current task-state evidence boundary.
- Treat missing `hero_task_state` as no saved tasks and continue deriving candidate tasks from current commander-role/report snapshots.
- Ignore malformed optional `hero_task_state` rather than migrating or repairing it.
- Do not bump `SAVE_VERSION`, write schema, migrate saves, change live target selection, change movement/arrival, change town-governor choices, or introduce durable event logs.

For a later schema adoption:

- The first runtime escape hatch must be "ignore optional `hero_task_state` and fall back to existing active raids, commander rosters, target memory, and derived reports."
- If optional task state causes duplicate target ownership, stale actor links, stale route assumptions, or old-save regressions, disable task execution and return to report-only candidate generation.

## Recommended Next Slice

Run `strategic-ai-hero-task-state-save-normalizer-preservation-report-implementation-10184` next.

That slice should implement only the report-only proof described here. It should not approve schema writes, save migration, `SAVE_VERSION` bumps, durable event logs, defense-specific durable state, coefficient tuning, production JSON edits, full AI hero task-state implementation, live commander-role behavior, live AI hero behavior, target selection changes, raid movement/arrival changes, town-governor choice changes, pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, resource migration, market overhaul, River Pass rebalance, push, or PR creation.

## Completion Decision

Strategic AI hero task-state save-normalizer preservation planning is complete.

The minimum useful next proof is the focused `AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT`: prove old-save absence, explicit optional-field preservation, malformed-state tolerance, unknown-field isolation, `SaveService` semantic boundaries, and no save-version change before any minimal schema planning or live AI hero task behavior work starts.
