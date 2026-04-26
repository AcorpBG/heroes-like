# Strategic AI Hero Task-State Boundary Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-hero-task-state-boundary-planning-10184`.

## Purpose

Define the future real strategic AI hero task-state boundary after the passed commander-role live-turn transcript/report gate.

This slice is planning only. It does not implement task state, reports, tests, schema writes, save migration, durable event logs, defense-specific durable state, live commander-role behavior, production JSON edits, coefficient tuning, pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, `content/resources.json`, `wood` to `timber` migration, rare resources, market-cap overhaul, or River Pass rebalance.

## Evidence Baseline

Accepted inputs:

- `docs/strategic-ai-commander-role-live-turn-transcript-report-gate-review.md` passed. The focused report printed `AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT` with `ok: true`, `schema_status: "derived_turn_transcript_report_only"`, `behavior_policy: "observe_existing_enemy_turn_only"`, and `save_policy: "no_commander_role_state_write"`.
- `docs/strategic-ai-commander-role-live-turn-transcript-report-implementation-report.md` records the current report-only helper boundary in `EnemyAdventureRules.gd`.
- `docs/strategic-ai-commander-role-adoption-sequencing-plan.md` deferred minimal `commander_role_state` writes and full AI hero task state until a later gate proves the need.
- `docs/strategic-ai-minimal-commander-role-state-schema-plan.md` defined a narrow future optional `commander_role_state` under commander roster entries, but explicitly kept it out of live saves.
- `docs/strategic-ai-commander-role-state-plan.md` split current raid encounter fields, commander roster continuity, and future commander-role state into separate layers.

Current code reality:

- `EnemyTurnRules.gd` owns enemy-turn orchestration, normalizes `enemy_states[]`, runs town-governor cycles, advances raids, and rebuilds commander hosts.
- `EnemyAdventureRules.gd` owns active raid targeting, raid movement/arrival resolution, commander roster normalization, target memory, commander report helpers, and the derived turn transcript helpers.
- `SessionStateStore.gd` still has `SAVE_VERSION := 9`.
- `SaveService.gd` normalizes top-level payloads through `SessionStateStore.normalize_payload(...)`; it does not own strategic AI semantics.
- `EnemyTurnRules.normalize_enemy_states(...)` currently reconstructs each enemy state with known fields. Any future task-state schema under `enemy_states[]` must be explicitly normalized or preserved there, or it will be dropped during enemy-turn normalization.

## Boundary Decision

Future real AI hero task state should be a separate faction task layer, not a hidden expansion of current active raid records and not a premature replacement for commander roster continuity.

Keep four layers separate:

| Layer | Current or future | Ownership |
| --- | --- | --- |
| Commander roster continuity | Current | `enemy_states[].commander_roster[]` owns named commander identity, recovery, record, target memory, army continuity, and active placement link. |
| Active map actor | Current | `session.overworld.encounters[]` owns spawned raid position, movement, arrival, target coordinates, seizure/contest resolution, and embedded commander state while a raid is active. |
| Commander role view/state | Current derived, future optional schema | A compact adapter that explains commander role and front intent. It is not enough for full pathing, route reservations, scouting, spells, artifacts, or multi-turn hero work. |
| AI hero task state | Future | A faction-owned task board that assigns real AI heroes or commander actors to strategic jobs, owns task lifecycle and target reservations, and delegates route/movement execution to actor/path systems. |

The future task layer should be introduced first through report-only candidate task views, then fixture reports, then a schema planning gate. It should not write saves or control live behavior until the report proves a continuity need that cannot be derived from existing active raids, commander roster state, target memory, and turn snapshots.

## Future Task Record Shape

The preferred future schema location is planning-only:

```text
session.overworld.enemy_states[].hero_task_state
```

Draft shape:

```json
{
  "schema_version": 1,
  "planner_epoch": 0,
  "tasks": [
    {
      "task_id": "task:river-pass:faction_mireclaw:hero_vaska:retake_site:resource:river_free_company:day_4:seq_1",
      "owner_faction_id": "faction_mireclaw",
      "actor_kind": "commander_roster",
      "actor_id": "hero_vaska",
      "source_kind": "commander_role_adapter",
      "source_id": "role:river-pass:faction_mireclaw:hero_vaska:retaker:resource:river_free_company:day_4",
      "task_class": "retake_site",
      "task_status": "planned",
      "target_kind": "resource",
      "target_id": "river_free_company",
      "front_id": "riverwatch_signal_yard",
      "origin_kind": "town",
      "origin_id": "duskfen_bastion",
      "priority_reason_codes": ["persistent_income_denial", "recruit_denial"],
      "assigned_day": 4,
      "expires_day": 7,
      "continuity_policy": "persist_until_invalid",
      "route_policy": "derive_route_on_turn",
      "last_validation": "valid"
    }
  ]
}
```

Fields deliberately excluded from early task state:

- localized labels or public reason text;
- score-table fields;
- fixture annotations;
- full path arrays;
- movement point budgets;
- body tiles, approach offsets, or route geometry;
- spell plans, artifact plans, equipment plans, or tactical battle plans;
- durable public event history;
- defense-specific site locks such as `site_defended_until_day`.

Labels and public text must be recomputed from ids and reason codes. Full pathing and movement details should remain owned by route/path systems or active actors, not duplicated into strategic task records.

## Task Ids

Task ids must be deterministic, stable across save/load, and free of display text.

Recommended canonical format:

```text
task:<scenario_id>:<faction_id>:<actor_id>:<task_class>:<target_kind>:<target_id>:day_<assigned_day>:seq_<local_sequence>
```

Rules:

- Use stable ids only: scenario id, faction id, actor id, task class, target kind, target id, day, and a deterministic per-faction sequence.
- Do not use target labels, public reason phrases, generated names, coordinates alone, or localized text.
- If a commander role assignment already has a deterministic `assignment_id`, preserve it as `source_id` and create a separate task id. Do not reuse role assignment ids as primary task ids once the task layer exists.
- If the same actor is retasked to the same target on a later day, the new day and sequence create a new task id.
- If a task survives multiple days, retain the original task id until completion, failure, cancellation, or invalidation.

## Ownership And Lifecycle

Task ownership:

- The faction task board owns task records and target reservations.
- The commander roster owns actor identity, availability, recovery, target memory, and optional `current_task_id` only after a later schema gate approves it.
- Active encounter or future hero actor state owns position, map movement, arrival, and battle/interaction resolution.
- Town-governor state owns build, recruit, garrison, and rebuild decisions. Task state may reference governor evidence, but it must not become a durable town-governor log.

Task lifecycle:

| Status | Meaning |
| --- | --- |
| `candidate` | Derived proposal in a report only. Never saved. |
| `planned` | Future saved task exists, but no map actor has claimed it yet. |
| `reserved` | Target/front is reserved for an actor to avoid duplicate assignment. |
| `active` | A live map actor or future AI hero is executing the task. |
| `suspended` | Actor is temporarily blocked by recovery, rebuild, unreachable route, or turn cap. |
| `completed` | Target interaction, seizure, defense handoff, or objective condition completed. |
| `failed` | Actor defeated, target removed, route impossible, or script invalidated the task. |
| `cancelled` | Planner intentionally retasked the actor or cleared the front. |
| `invalid` | Validation found contradiction and the next planner pass must clear or retask. |

Allowed first task classes:

- `raid_town`
- `retake_site`
- `contest_site`
- `stabilize_front`
- `defend_front`
- `recover_commander`
- `rebuild_host`
- `reserve`

Defer scout, collector, courier, artifact hunter, spell caster, main-army campaign objective runner, and full route-chain classes until pathing, fog/scouting, spell, artifact, and object-approach boundaries are planned together.

## Role-To-Task Adapter Path

The adapter path should be one-way until full task state exists.

Mapping:

| Commander role | Candidate task class |
| --- | --- |
| `raider` targeting a town | `raid_town` |
| `raider` targeting a resource/site | `contest_site` |
| `retaker` | `retake_site` |
| `defender` | `defend_front` |
| `stabilizer` | `stabilize_front` |
| `recovering` with recovery day | `recover_commander` |
| `recovering` with depleted host | `rebuild_host` |
| `reserve` | `reserve` |

Adapter stages:

1. Report-only `candidate_task` records derive from existing commander-role proposals and live-turn transcript snapshots.
2. Candidate tasks keep `source_kind: "commander_role_adapter"` and point back to role assignment hints or transcript role records.
3. A future report verifies candidate task ids, ownership, invalidation, and route ownership without writing state.
4. A later schema planning gate decides whether `hero_task_state.tasks[]` is worth saving.
5. If schema adoption happens, `commander_role_state` becomes compatibility input, not the primary task engine.

The adapter must not make live target selection depend on candidate tasks during report-only phases.

## Route And Task Ownership

Task state owns strategic intent:

- actor id;
- task class;
- target id;
- front id;
- origin id;
- reason codes;
- assignment day and expiry;
- target reservation state;
- lifecycle status.

Route state does not belong in the first task record. Future route ownership should be split:

- active encounter/future AI hero actor owns current tile, destination tile, movement consumed, and arrival result;
- route/path helpers own path computation and reachability checks;
- object/body-tile/approach metadata remains inactive until a pathing adoption slice approves it;
- task state may store `route_policy` and a stable destination reference, but not path arrays or body-tile assumptions.

This keeps task state from becoming a stale path cache after terrain, roads, object footprints, approach offsets, or passability rules change.

## Invalidation Rules

Every task validation pass should produce a compact `last_validation` code.

Target invalidation:

- `invalid_target_missing`: target id no longer resolves.
- `invalid_target_resolved`: encounter/object/objective was cleared.
- `invalid_controller_changed`: target controller changed so the task class no longer applies.
- `invalid_target_reserved`: another active task owns the same exclusive target.
- `invalid_front_quiet`: front no longer has pressure worth servicing.

Actor invalidation:

- `invalid_actor_missing`: roster hero or future AI hero actor no longer resolves.
- `invalid_actor_recovering`: actor is in recovery cooldown.
- `invalid_actor_rebuilding`: actor host is depleted or shattered.
- `invalid_actor_active_elsewhere`: actor is linked to a different active placement/task.
- `invalid_actor_defeated`: active actor was defeated or removed.

Route and world invalidation:

- `invalid_origin_missing`: origin town/spawn/front no longer resolves.
- `invalid_origin_controller_changed`: origin is no longer owned by the faction.
- `invalid_route_unreachable`: route helper cannot find a valid route under current rules.
- `invalid_approach_unavailable`: future approach/body-tile metadata says the target cannot be entered.
- `invalid_script_lock`: scenario script state blocks the task.
- `invalid_scenario_complete`: scenario is no longer in progress.

Lifecycle transitions:

- arrival that flips or contests a target should complete or retask the active task;
- arrival that fails to change the world should mark failed or suspended with a reason;
- recovery should suspend only if the task remains strategically valid;
- expiry should cancel stale tasks unless policy says `persist_until_invalid`;
- malformed future task records should be ignored or downgraded, not allowed to corrupt commander roster continuity.

## Save And Schema Risks

No save/schema write is approved by this plan.

Risks before any schema adoption:

- `SAVE_VERSION` is currently `9`; a task-state write must not silently imply a version bump.
- `EnemyTurnRules.normalize_enemy_states(...)` currently rebuilds enemy state dictionaries with known fields. Future `hero_task_state` would be lost unless normalization is updated intentionally.
- `EnemyAdventureRules.normalize_commander_roster(...)` similarly owns commander roster shape. A future `current_task_id` or role/task pointer must be normalized explicitly.
- Active raids already contain embedded `enemy_commander_state`. Task state must not duplicate active movement, target coordinates, or arrival state in a way that can desync.
- Scenario scripts can spawn encounters without named commander ownership. Task schema must allow unowned or legacy raid actors to continue.
- Old saves have no task board and no role state. Absence must normalize to an empty task board plus derived candidate tasks in reports.
- Public text in saves will stale after content names or reason vocabulary change. Save ids and reason codes only.
- A full AI hero task system will eventually need fog/scouting, spells, artifacts, pathing, object approach, and battle readiness. The first schema must be adapter-friendly, not a dead-end planner.

Old-save compatibility policy:

- Missing `hero_task_state` means no saved tasks.
- Existing active raids remain authoritative.
- Existing commander roster entries remain valid.
- Derived candidate tasks may be generated for reports, but not written back.
- Malformed future task records should be dropped from the normalized task view, not from the save payload, until a migration plan exists.
- No `SAVE_VERSION` bump is allowed without explicit old-save fixtures.

## Rollback And Escape Hatch

For this planning slice:

- No rollback code is needed because no implementation is changed.

For the recommended report/fixture planning and report-only implementation path:

- Disable or remove the task report helpers/scenes.
- Keep existing commander-role state and live-turn transcript reports.
- Continue deriving commander roles from current raids, roster state, and target memory.
- Do not change saves, production JSON, target selection, raid movement, or UI.

For a later schema adoption:

- The first escape hatch must be "ignore optional `hero_task_state`" during planning/execution.
- A strip/migration tool is not approved unless a separate save migration plan exists.
- Live AI should retain a fallback path that uses existing active raid and commander roster behavior when task state is absent, invalid, or disabled.
- If task state causes duplicate target ownership or stale route behavior, disable task execution and keep report-only candidate generation until fixed.

## Fixture And Report Prerequisites

Recommended future report marker:

```text
AI_HERO_TASK_STATE_BOUNDARY_REPORT
```

The next report/fixture planning slice should define exact cases and payloads before implementation. Minimum planned cases:

1. `river_pass_free_company_task_candidate`
   - Source: Vaska Reedmaw retaker evidence from the passed transcript gate.
   - Expected candidate task: `retake_site` for `river_free_company`.
   - Checks: deterministic task id, role source id, target owner, lifecycle `candidate`, no saved state.

2. `river_pass_signal_post_companion_task_candidate`
   - Source: Sable Muckscribe raider view for `river_signal_post`.
   - Expected candidate task: `contest_site`.
   - Checks: no duplicate ownership of `river_free_company`, compact reason codes, no score-table leakage.

3. `glassroad_relay_retake_to_defend_transition`
   - Source: Caelen Ashgrove before/after relay transcript.
   - Expected candidate transition: `retake_site` before turn, `defend_front` or `stabilize_front` after controller flip.
   - Checks: arrival/controller change invalidates or completes the retake task candidate.

4. `glassroad_starlens_stabilizer_candidate`
   - Source: Seren Valechant stabilizer view with no active commander.
   - Expected candidate task: `stabilize_front` or report-only no-op when no actor can claim it.
   - Checks: task ownership explains why no live actor is spawned.

5. `commander_recovery_blocks_task_claim`
   - Source: existing recovery/rebuild report evidence.
   - Expected candidate task: `recover_commander` or `rebuild_host`, with no target reservation.

6. `old_save_no_task_state_compatibility`
   - Source: session with existing enemy roster/raids and no task state.
   - Expected result: empty saved task board, derived candidate tasks only, `SAVE_VERSION` unchanged.

7. `duplicate_target_reservation_report_only`
   - Source: two commanders proposing the same exclusive target.
   - Expected result: one primary candidate and one `invalid_target_reserved` or no-op candidate, without coefficient tuning.

Report payload should include:

- `schema_status: "task_state_boundary_report_only"`;
- `behavior_policy: "derive_candidate_tasks_only"`;
- `save_policy: "no_hero_task_state_write"`;
- task id checks;
- actor ownership checks;
- target reservation checks;
- role-to-task source checks;
- invalidation checks;
- public leak checks;
- old-save compatibility check.

## Validation Gates

Gate 1: boundary planning.

- This document exists.
- PLAN and progress trackers mark the boundary slice complete.
- No code, production JSON, schema, save, or behavior changes are made.

Gate 2: report/fixture planning.

- Define exact `AI_HERO_TASK_STATE_BOUNDARY_REPORT` payload and deterministic fixtures.
- Confirm every candidate task can be derived from current transcript/role evidence.
- Keep report-only status and no schema writes.

Gate 3: report-only implementation.

- Implement pure helper/report coverage only after Gate 2.
- Prove task ids, ownership, invalidation, old-save absence, and public leak boundaries.
- Keep `SAVE_VERSION` unchanged and task candidates unsaved.

Gate 4: schema adoption planning.

- Only start if Gate 3 proves continuity or duplicate-ownership problems that cannot be handled by derived reports.
- Decide exact normalization in `EnemyTurnRules` and any commander roster pointer policy.
- Add old-save and malformed-state fixtures before any write.

Gate 5: live behavior adoption.

- Only start after schema adoption proves safe, route ownership is planned, and live-client pacing/readability gates are defined.
- Manual live-client review is required if visible turn pacing, arrival frequency, map pressure, save/resume state, or player-facing turn text changes.

Gate 6: route/pathing/body-tile adoption.

- Separate from task state.
- Requires object approach/body-tile metadata, path validation, editor placement checks, and renderer readability gates.

## Option Comparison

| Option | Value | Risk | Decision |
| --- | --- | --- | --- |
| Minimal task-state planning/report first | Turns the passed commander-role transcript into concrete candidate task ids, ownership, lifecycle, invalidation, and old-save checks without changing behavior or saves. | Low if kept report-only. Main risk is report scope creep into a fake planner. | Recommended next. |
| Schema adoption now | Starts real saved task continuity and can expose normalizer/save risks. | Premature. `EnemyTurnRules.normalize_enemy_states(...)` would need schema-aware changes, route ownership is not planned, and no report has proved saved tasks are needed. | Defer. |
| Live behavior adoption now | Makes AI heroes feel more real sooner. | Too broad. It pulls in route planning, duplicate target ownership, active actor control, save/resume, UI pacing, and manual gates before task boundaries are proven. | Defer. |
| Pause commander roles/task work | Avoids schema risk. | Leaves no bridge from useful transcript evidence to future full AI heroes. | Reject as default. |

## Recommended Next Slice

Run `strategic-ai-hero-task-state-report-fixture-planning-10184`.

Scope:

- Plan the exact `AI_HERO_TASK_STATE_BOUNDARY_REPORT` payload and fixture cases.
- Keep all records derived/report-only.
- Use the passed River Pass and Glassroad transcript cases as the first evidence.
- Cover task ids, role-to-task adapter records, ownership, target reservation, invalidation, old-save absence, public leak checks, and validation commands.

Do not implement report helpers/tests, write schema, migrate saves, change live AI behavior, tune coefficients, add durable event logs, add defense-specific durable state, edit production JSON, change route/pathing/body-tile/approach behavior, change renderer/editor behavior, import assets, or rebalance River Pass.

## Completion Decision

Strategic AI hero task-state boundary planning is complete.

The project should move next to report/fixture planning, not schema adoption, live behavior adoption, or a pause. The minimum useful next proof is a report-only candidate task boundary that shows deterministic task ids, ownership, lifecycle, invalidation, save/schema risk handling, and old-save compatibility before any durable state exists.
