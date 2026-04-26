# Strategic AI Hero Task-State Report Fixture Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-hero-task-state-report-fixture-planning-10184`.

## Purpose

Define the exact future `AI_HERO_TASK_STATE_BOUNDARY_REPORT` payload and deterministic fixture cases after the completed task-state boundary plan.

This slice is planning only. It does not implement report helpers, tests, schema writes, save migration, durable event logs, full AI hero task state, defense-specific durable state, live commander-role behavior, production JSON edits, coefficient tuning, pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, `content/resources.json`, `wood` to `timber` migration, rare resources, market-cap overhaul, or River Pass rebalance.

## Evidence Baseline

Accepted inputs:

- `docs/strategic-ai-hero-task-state-boundary-plan.md` defines future task ids, ownership, lifecycle, role-to-task mapping, invalidation, old-save compatibility, rollback, and validation gates.
- `docs/strategic-ai-commander-role-live-turn-transcript-report-gate-review.md` passed with `AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT`, `ok: true`, derived turn transcript status, River Pass Free Company retake/controller flip, Glassroad Watch Relay retake/controller flip, Starlens stabilizer evidence, source-marker checks, and public leak checks.
- `docs/strategic-ai-commander-role-live-turn-transcript-report-implementation-report.md` records the current report-only helper boundary in `EnemyAdventureRules.gd`.
- `docs/strategic-ai-minimal-commander-role-state-schema-plan.md` records the future role-state schema boundary but keeps it out of saves.
- `tests/ai_commander_role_turn_transcript_report.gd` supplies the current deterministic River Pass and Glassroad fixture setup pattern.

Current code reality to preserve:

- `EnemyTurnRules.run_enemy_turn(...)` is the live enemy-turn authority.
- `EnemyAdventureRules.gd` owns report-only commander-role and transcript helpers.
- `EnemyTurnRules.normalize_enemy_states(...)` currently rebuilds known enemy-state fields and would drop any future `hero_task_state` unless a later schema slice intentionally preserves or normalizes it.
- Old saves currently have no `hero_task_state`.
- `SessionStateStore.SAVE_VERSION` remains `9`.

## Report Marker

Future report line:

```text
AI_HERO_TASK_STATE_BOUNDARY_REPORT <json>
```

Top-level payload:

```json
{
  "ok": true,
  "report_id": "AI_HERO_TASK_STATE_BOUNDARY_REPORT",
  "schema_status": "task_state_boundary_report_only",
  "behavior_policy": "derive_candidate_tasks_only",
  "save_policy": "no_hero_task_state_write",
  "source_policy": "commander_role_adapter_from_report_snapshots",
  "save_version_before": 9,
  "save_version_after": 9,
  "cases": [],
  "candidate_task_id_check": {},
  "actor_ownership_check": {},
  "target_ownership_check": {},
  "role_to_task_source_check": {},
  "target_reservation_check": {},
  "invalidation_check": {},
  "old_save_absence_check": {},
  "public_leak_check": {},
  "failure_conditions": [],
  "validation_caveats": []
}
```

Payload rules:

- `cases[]` are report-only fixture cases. They must not be saved into the session.
- Candidate tasks use `task_status: "candidate"` unless the case is explicitly checking blocked, invalid, completed, or unclaimed report states.
- Every candidate task carries `state_policy: "report_only"` and `source_kind: "commander_role_adapter"`.
- Source ids point back to role assignment hints or deterministic role adapter records. Task ids never reuse role ids.
- Public task events omit internal `task_id`, score fields, debug breakdowns, fixture annotations, path details, and save/schema fields.
- Any saved `hero_task_state` in these fixtures is a failure unless the specific old-save absence case is proving absence.

## Candidate Task Record

Future report-only candidate task shape:

```json
{
  "task_id": "task:river-pass:faction_mireclaw:hero_vaska:retake_site:resource:river_free_company:day_1:seq_1",
  "task_status": "candidate",
  "owner_faction_id": "faction_mireclaw",
  "actor_kind": "commander_roster",
  "actor_id": "hero_vaska",
  "actor_label": "Vaska Reedmaw",
  "source_kind": "commander_role_adapter",
  "source_id": "role:river-pass:faction_mireclaw:hero_vaska:retaker:resource:river_free_company:day_1",
  "source_role": "retaker",
  "source_timing": "before_turn",
  "task_class": "retake_site",
  "target_kind": "resource",
  "target_id": "river_free_company",
  "target_controller_before": "player",
  "target_controller_after": "player",
  "front_id": "riverwatch_signal_yard",
  "origin_kind": "town",
  "origin_id": "duskfen_bastion",
  "priority_reason_codes": ["persistent_income_denial", "recruit_denial"],
  "assigned_day": 1,
  "expires_day": 4,
  "continuity_policy": "persist_until_invalid",
  "route_policy": "derive_route_on_turn",
  "reservation": {
    "reservation_status": "primary",
    "reservation_scope": "exclusive_target",
    "reservation_key": "resource:river_free_company"
  },
  "last_validation": "valid",
  "state_policy": "report_only"
}
```

Fields deliberately excluded:

- score tables and `resource_score_breakdown`;
- `debug_reason`, `target_debug_reason`, `final_priority`, or raw priority components;
- localized labels as ids;
- path arrays, movement budgets, body tiles, approach offsets, or route geometry;
- durable public events;
- saved `hero_task_state`;
- fixture-only annotations such as `fixture_previous_controller` or `fixture_primary_target_covered`.

## Fixture Cases

### `river_pass_free_company_task_candidate`

Source evidence:

- Scenario: `river-pass`.
- Faction: `faction_mireclaw`.
- Actor: `hero_vaska`.
- Source role: `retaker`.
- Source timing: `before_turn`.
- Source target: `resource:river_free_company`.
- Source id: `role:river-pass:faction_mireclaw:hero_vaska:retaker:resource:river_free_company:day_1`.

Expected candidate:

- `task_id`: `task:river-pass:faction_mireclaw:hero_vaska:retake_site:resource:river_free_company:day_1:seq_1`.
- `task_class`: `retake_site`.
- `task_status`: `candidate`.
- `target_controller_before`: `player`.
- `target_owner_expected`: `player-held contested resource`.
- `front_id`: `riverwatch_signal_yard`.
- `origin_id`: `duskfen_bastion`.
- Minimum reason codes: `persistent_income_denial`, `recruit_denial`.
- Reservation: primary `exclusive_target` reservation on `resource:river_free_company`.

Required checks:

- Candidate task id is deterministic and contains no display text.
- Actor resolves in Mireclaw commander roster and belongs to `faction_mireclaw`.
- Target resolves to a River Pass resource node and is controlled by `player` in the fixture.
- Source id matches the role-to-task adapter input and is not reused as the task id.
- No `hero_task_state` appears in the session.

### `river_pass_signal_post_companion_task_candidate`

Source evidence:

- Scenario: `river-pass`.
- Faction: `faction_mireclaw`.
- Actor: `hero_sable`.
- Source role: `raider`.
- Source timing: `before_turn`.
- Source target: `resource:river_signal_post`.
- Companion fixture note stays report-only: `fixture_primary_target_covered: "river_free_company"`.
- Source id: `role:river-pass:faction_mireclaw:hero_sable:raider:resource:river_signal_post:day_1`.

Expected candidate:

- `task_id`: `task:river-pass:faction_mireclaw:hero_sable:contest_site:resource:river_signal_post:day_1:seq_2`.
- `task_class`: `contest_site`.
- `task_status`: `candidate`.
- `target_controller_before`: `player`.
- `front_id`: `riverwatch_signal_yard`.
- `origin_id`: `duskfen_bastion`.
- Minimum reason codes: `persistent_income_denial`, `route_vision`.
- Reservation: primary `exclusive_target` reservation on `resource:river_signal_post`.

Required checks:

- The candidate does not reserve or claim `river_free_company`.
- The task id sequence is deterministic after the Free Company candidate.
- Actor/target ownership stays inside `faction_mireclaw` and River Pass.
- Public task event uses compact reason text only.
- No score-table or fixture annotation leaks into public output.

### `glassroad_relay_retake_to_defend_transition`

Source evidence:

- Scenario: `glassroad-sundering`.
- Faction: `faction_embercourt`.
- Actor: `hero_caelen`.
- Source target: `resource:glassroad_watch_relay`.
- Before-turn source role: `retaker`.
- After-turn source role: `defender`.
- The passed transcript gate proved arrival and controller flip from `player` to `faction_embercourt`.

Expected before-turn candidate:

- `task_id`: `task:glassroad-sundering:faction_embercourt:hero_caelen:retake_site:resource:glassroad_watch_relay:day_1:seq_1`.
- `source_id`: `role:glassroad-sundering:faction_embercourt:hero_caelen:retaker:resource:glassroad_watch_relay:day_1`.
- `task_class`: `retake_site`.
- `target_controller_before`: `player`.
- Reservation: primary `exclusive_target` reservation on `resource:glassroad_watch_relay`.
- Minimum reason codes: `persistent_income_denial`, `route_vision`.

Expected transition check:

- Arrival summary references `glassroad_watch_relay`.
- Controller changes to `faction_embercourt`.
- Retake candidate is no longer valid as an open retake after arrival.
- Transition result records `completed_by_controller_flip`.
- Stale retake reservation is released in the report view.
- `last_validation_after_arrival`: `invalid_controller_changed` for the old retake candidate.

Expected after-turn candidate:

- `task_id`: `task:glassroad-sundering:faction_embercourt:hero_caelen:defend_front:resource:glassroad_watch_relay:day_1:seq_2`.
- `source_id`: `role:glassroad-sundering:faction_embercourt:hero_caelen:defender:resource:glassroad_watch_relay:day_1`.
- `task_class`: `defend_front`.
- `target_controller_before`: `faction_embercourt`.
- `task_status`: `candidate`.
- Reservation: primary `exclusive_target` reservation on `resource:glassroad_watch_relay`.

Required checks:

- The report distinguishes completed retake intent from the new defend-front candidate.
- No defense-specific durable field such as `site_defended_until_day` is introduced.
- The transition is derived from transcript snapshots and arrival/controller data only.

### `glassroad_starlens_stabilizer_candidate`

Source evidence:

- Scenario: `glassroad-sundering`.
- Faction: `faction_embercourt`.
- Actor: `hero_seren`.
- Source role: `stabilizer`.
- Source timing: `before_turn` and `after_turn`.
- Source target: `resource:glassroad_starlens`.
- The passed transcript gate records no active commander for Seren.

Expected candidate:

- `task_id`: `task:glassroad-sundering:faction_embercourt:hero_seren:stabilize_front:resource:glassroad_starlens:day_1:seq_3`.
- `source_id`: `role:glassroad-sundering:faction_embercourt:hero_seren:stabilizer:resource:glassroad_starlens:day_1`.
- `task_class`: `stabilize_front`.
- `task_status`: `candidate`.
- `claim_status`: `report_only_unclaimed`.
- `target_controller_before`: `faction_embercourt`.
- `front_id`: `glassroad_charter_front`.
- `origin_id`: `riverwatch_market`.
- Minimum reason code: `route_pressure`.
- Reservation: `shared_front` or `none`, not an exclusive target claim.

Required checks:

- Actor resolves in Embercourt commander roster but has no active placement link.
- Report explains that no live actor is spawned because task candidates do not drive behavior.
- The stabilizer candidate does not block Caelen's relay defense reservation.
- Public event remains compact and does not imply a saved defense state.

### `commander_recovery_rebuild_blocks_task_claim`

Source evidence:

- Fixture creates report-only blocked commander views from existing recovery/rebuild role logic.
- No live target selection or town-governor behavior changes are allowed.

Expected recovery candidate:

- Actor: `hero_vaska`.
- `task_id`: `task:river-pass:faction_mireclaw:hero_vaska:recover_commander:commander:hero_vaska:day_1:seq_1`.
- `source_id`: `role:river-pass:faction_mireclaw:hero_vaska:recovering:commander:hero_vaska:day_1`.
- `task_class`: `recover_commander`.
- `task_status`: `blocked`.
- `target_kind`: `commander`.
- `target_id`: `hero_vaska`.
- `last_validation`: `invalid_actor_recovering`.
- Reservation: none.

Expected rebuild candidate:

- Actor: `hero_sable`.
- `task_id`: `task:river-pass:faction_mireclaw:hero_sable:rebuild_host:commander:hero_sable:day_1:seq_2`.
- `source_id`: `role:river-pass:faction_mireclaw:hero_sable:recovering:commander:hero_sable:day_1`.
- `task_class`: `rebuild_host`.
- `task_status`: `blocked`.
- `target_kind`: `commander`.
- `target_id`: `hero_sable`.
- `last_validation`: `invalid_actor_rebuilding`.
- Reservation: none.

Required checks:

- Recovery and rebuild candidates do not reserve resource, town, or front targets.
- Blocked commanders cannot claim `river_free_company`, `river_signal_post`, `glassroad_watch_relay`, or `glassroad_starlens`.
- Public output may say commander recovering or commander rebuilding, but must not expose rebuild score, recovery pressure, raw memory counters, or fixture annotations.

### `old_save_no_task_state_compatibility`

Source evidence:

- A normalized session with existing enemy roster/raids and no `enemy_states[].hero_task_state`.

Expected report result:

- `saved_task_board_present`: false.
- `saved_task_count`: 0.
- `derived_candidate_tasks_allowed`: true.
- `save_version_before`: 9.
- `save_version_after`: 9.
- `normalization_policy`: `missing_hero_task_state_means_no_saved_tasks`.
- `write_check`: `no_hero_task_state_write`.

Required checks:

- Missing task state does not fail report generation.
- Existing active raids and commander roster entries remain the evidence source.
- Candidate tasks may be derived for the report but are not written back.
- Any future malformed saved task fixture must be ignored by the task view, not used to mutate enemy roster continuity.

### `duplicate_target_reservation_report_only`

Source evidence:

- Scenario: `river-pass`.
- Faction: `faction_mireclaw`.
- Two report-only role proposals target `resource:river_free_company`.
- No coefficient tuning is allowed to resolve the duplicate.

Reservation arbitration rule for the report:

1. Active linked commander beats unlinked commander.
2. If both are linked or both unlinked, task-class priority is `retake_site`, `defend_front`, `contest_site`, `stabilize_front`, `raid_town`, `reserve`.
3. If still tied, lower `roster_hero_id` lexicographic order wins.
4. The loser must be marked report-only invalid or no-op, not retargeted by hidden scoring.

Expected primary candidate:

- Actor: `hero_vaska`.
- `task_id`: `task:river-pass:faction_mireclaw:hero_vaska:retake_site:resource:river_free_company:day_1:seq_1`.
- Reservation: primary `exclusive_target` on `resource:river_free_company`.
- `last_validation`: `valid`.

Expected duplicate candidate:

- Actor: `hero_sable`.
- `task_id`: `task:river-pass:faction_mireclaw:hero_sable:contest_site:resource:river_free_company:day_1:seq_2`.
- Reservation: rejected duplicate on `resource:river_free_company`.
- `task_status`: `invalid`.
- `last_validation`: `invalid_target_reserved`.
- `invalidated_by_task_id`: Vaska's primary task id.

Required checks:

- Exactly one primary reservation exists for `resource:river_free_company`.
- The duplicate case does not alter target selection, coefficients, commander roster, active raids, or saved state.
- Public output either omits the rejected duplicate or emits a compact no-op reason without internal reservation details.

## Required Cross-Case Checks

Candidate task id checks:

- All `task_id` values match `task:<scenario_id>:<faction_id>:<actor_id>:<task_class>:<target_kind>:<target_id>:day_<assigned_day>:seq_<local_sequence>`.
- Task ids are unique within the report.
- Task ids are stable when the same fixture is rerun.
- Task ids contain no labels, spaces, localized text, coordinates-only targets, public reasons, or generated names.
- `source_id` is present for every role-derived task and is not equal to `task_id`.

Actor ownership checks:

- `owner_faction_id` matches the enemy config faction.
- `actor_kind` is `commander_roster` for these fixtures.
- `actor_id` resolves to a commander roster entry for the owning faction.
- Active actors, when present, link through `active_placement_id` or active raid snapshot.
- Cross-faction actor references are fatal report errors.

Target ownership checks:

- Resource targets resolve to scenario resource nodes.
- Controller states match fixture setup before and after turn snapshots.
- `retake_site` requires a player-held or non-owner-held faction-interest target before arrival.
- `defend_front` and `stabilize_front` require an owner-held or recently secured target/front.
- Commander recovery/rebuild targets are commanders, not map resources.

Role-to-task source checks:

- `retaker` maps to `retake_site`.
- Resource `raider` maps to `contest_site`.
- `defender` maps to `defend_front`.
- `stabilizer` maps to `stabilize_front`.
- `recovering` with cooldown maps to `recover_commander`.
- `recovering` with depleted host maps to `rebuild_host`.
- Every source role record has `state_policy: "report_only"` or `source_policy: "snapshot_derived"`.

Target reservation checks:

- `retake_site`, `contest_site`, and `defend_front` use exclusive target reservations.
- `stabilize_front` uses shared front reservation or no reservation until real task execution exists.
- `recover_commander` and `rebuild_host` use no map target reservation.
- Duplicate exclusive reservations produce exactly one primary and one `invalid_target_reserved` or no-op candidate.
- Reservation checks are report-only and do not write target locks to session state.

Invalidation checks:

- Controller flip from player to owner completes the old retake candidate and marks the old retake validation as `invalid_controller_changed` for further retake use.
- Recovery cooldown blocks map-task claims with `invalid_actor_recovering`.
- Depleted or shattered host blocks map-task claims with `invalid_actor_rebuilding`.
- Duplicate exclusive target claims use `invalid_target_reserved`.
- Missing target fixtures use `invalid_target_missing` if added later.
- Invalid records must not corrupt commander roster continuity or active raid state.

Old-save absence checks:

- Missing `hero_task_state` means no saved task board.
- `SAVE_VERSION` remains `9`.
- The report does not add `hero_task_state` to `enemy_states[]`.
- Existing active raids and commander rosters remain authoritative.
- Derived candidate tasks are allowed only inside the report payload.

Public leak checks:

- Public task events use a compact shape: `event_id`, `day`, `sequence`, `event_type`, `faction_id`, `faction_label`, `actor_id`, `actor_label`, `task_class`, `target_kind`, `target_id`, `target_label`, `front_id`, `visibility`, `public_importance`, `summary`, `reason_codes`, `public_reason`, and `state_policy`.
- Public task events omit `task_id`, `source_id`, `assignment_id_hint`, score fields, raw priority fields, `resource_breakdown`, fixture annotations, route details, save/schema fields, and invalidation internals.
- Blocked public tokens include `resource_score_breakdown`, `final_priority`, `debug_reason`, `target_debug_reason`, `fixture_`, `score`, `priority_table`, `breakdown`, `hero_task_state`, `commander_role_state`, `SAVE_VERSION`, `body_tiles`, and `approach`.
- Report/debug candidate records may contain task ids and source ids; public records may not.

## Future Implementation Sequence

Recommended next implementation sequence for `strategic-ai-hero-task-state-report-implementation-10184`:

1. Add report-only constants and helper entry points in `EnemyAdventureRules.gd`; do not touch `EnemyTurnRules.run_enemy_turn(...)` behavior.
2. Add deterministic candidate task id generation and sequence ordering.
3. Add role-to-task adapter conversion from existing commander-role proposal records.
4. Add actor ownership and target ownership validators for resource and commander targets.
5. Add report-only target reservation arbitration.
6. Add invalidation helpers for controller change, recovery, rebuild, missing target, and duplicate reservation.
7. Add old-save absence inspection that verifies missing task state remains absent and `SAVE_VERSION` stays unchanged.
8. Add compact public task event construction and recursive public leak checks.
9. Add `tests/ai_hero_task_state_boundary_report.gd` and `.tscn` with the seven cases above.
10. Print exactly one `AI_HERO_TASK_STATE_BOUNDARY_REPORT` line.
11. Add an implementation report doc after the focused report passes.
12. Run validation and commit locally if all checks pass.

The future implementation may reuse the current River Pass and Glassroad fixture setup pattern from `tests/ai_commander_role_turn_transcript_report.gd`. If a transition case needs before/after arrival evidence, it may call existing `EnemyTurnRules.run_enemy_turn(...)` once for that fixture as observation only; candidate task helpers must still not drive target selection, movement, arrival, town-governor choices, or saves.

## Failure Conditions

The future report implementation must fail if any of these occur:

- Top-level `schema_status`, `behavior_policy`, or `save_policy` differs from the planned values.
- A fixture writes or preserves a new `hero_task_state` field.
- `SAVE_VERSION` changes.
- Candidate task ids are missing, unstable, duplicated, or contain display text.
- A task reuses a commander-role `assignment_id_hint` as its primary `task_id`.
- Actor ownership crosses faction boundaries or references a missing commander.
- Target ownership contradicts the fixture setup.
- A duplicate exclusive target has more than one primary reservation.
- Recovery or rebuild candidates reserve map targets.
- Glassroad relay retake remains open after the controller flip.
- Starlens stabilizer claims a live actor that the transcript says does not exist.
- Public events leak score tables, debug breakdowns, fixture annotations, schema/save fields, pathing/body-tile/approach details, or task internals.
- The report implementation changes production JSON, live AI behavior, target selection, raid movement, raid arrival, town-governor decisions, save normalization, renderer/editor behavior, or pathing.

## Validation Commands

Required validation for this planning slice:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

Future report-only implementation should also run:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_hero_task_state_boundary_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_turn_transcript_report.tscn
```

## Recommended Next Slice

Run `strategic-ai-hero-task-state-report-implementation-10184`.

Scope for that slice:

- Implement pure/report-only `AI_HERO_TASK_STATE_BOUNDARY_REPORT` helpers and a focused Godot report scene for the seven planned cases.
- Keep every candidate task derived/report-only.
- Keep `SAVE_VERSION` unchanged.
- Do not write `hero_task_state`, migrate saves, add durable event logs, add defense-specific durable state, tune coefficients, edit production JSON, implement full AI hero task state, adopt live commander-role behavior, change target selection, change raid movement/arrival, change town-governor choices, change pathing/body-tile/approach behavior, change renderer/editor behavior, import generated PNGs, migrate neutral encounters, add resources, overhaul markets, or rebalance River Pass.

Do not start schema adoption yet. The implementation gate must first prove candidate task ids, actor/target ownership, source links, target reservations, invalidation, old-save absence, and public leak boundaries in a report-only payload.

## Completion Decision

Strategic AI hero task-state report fixture planning is complete.

The project should proceed to report-only implementation of `AI_HERO_TASK_STATE_BOUNDARY_REPORT`, not schema adoption, save migration, live behavior adoption, coefficient tuning, defense-specific durable state, or full AI hero task-state implementation.
