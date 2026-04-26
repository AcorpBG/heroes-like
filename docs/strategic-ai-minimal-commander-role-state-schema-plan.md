# Strategic AI Minimal Commander Role State Schema Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-minimal-commander-role-state-schema-planning-10184`.

## Purpose

Decide the exact minimal commander-role state schema boundary before implementing `AI_COMMANDER_ROLE_STATE_REPORT`, fixture-only normalization, live commander-role behavior, save migration, or full AI hero task state.

This slice is planning only. It does not implement schema, reports, tests, live behavior, production JSON edits, coefficient tuning, durable event logs, save migration, full AI hero task state, defense-specific durable state, pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, `content/resources.json`, `wood` to `timber` migration, rare resources, market-cap overhaul, or River Pass rebalance.

## Inputs

Use these documents as requirements:

- `docs/strategic-ai-commander-role-state-plan.md`
- `docs/strategic-ai-commander-role-report-fixture-plan.md`
- `docs/strategic-ai-capture-countercapture-defense-proof-report.md`
- `docs/strategic-ai-glassroad-defense-proof-report.md`

Code inspection only:

- `scripts/core/EnemyAdventureRules.gd`
- `scripts/core/EnemyTurnRules.gd`
- `scripts/core/SessionStateStore.gd`
- `scripts/autoload/SaveService.gd`

Current code reality:

- `SessionStateStore.SAVE_VERSION` is `9`.
- `enemy_states[]` is the current durable per-faction AI state under `session.overworld`.
- `enemy_states[].commander_roster[]` already normalizes named commander identity, `status`, `active_placement_id`, `recovery_day`, outcome record, `target_memory`, `army_continuity`, and `commander_state`.
- Active spawned raids still live as `session.overworld.encounters[]` entries with `spawned_by_faction_id`, target fields, movement/arrival fields, `enemy_army`, and embedded `enemy_commander_state`.
- Public AI events are currently derived records, not durable logs.

## Schema Boundary Decision

The minimal future schema location is:

```text
session.overworld.enemy_states[].commander_roster[].commander_role_state
```

Do not use an `enemy_states[].commander_roles` side table for the first schema. The roster entry is already the identity and continuity owner, and role state must follow `roster_hero_id` across available, active, recovering, and rebuilt states. A side table would add an id-resolution layer before the code has full AI hero state or cross-commander task planning.

The record is optional in old saves and may be absent until a later implementation slice writes it. Missing state is normalized as a derived `reserve`, `recovering`, or `active` view for reports, not as a save migration requirement.

## Minimal Record

Future saved shape:

```json
{
  "schema_version": 1,
  "role": "reserve",
  "role_status": "available",
  "assignment_id": "",
  "target_kind": "",
  "target_id": "",
  "front_id": "",
  "origin_kind": "",
  "origin_id": "",
  "priority_reason_codes": [],
  "assigned_day": 0,
  "expires_day": 0,
  "continuity_policy": "clear_when_invalid",
  "fallback_role": "reserve",
  "last_validation": "valid"
}
```

Fields deliberately excluded from the live schema:

- `target_label`
- `public_reason`
- `debug_reason_ref`
- score-table fields
- fixture annotations
- path arrays or movement budgets
- body tiles, approach offsets, or route plans
- defense locks such as `site_defended_until_day`
- durable event summaries
- full AI hero task plans, spell plans, artifact plans, or equipment plans

Labels and public text are recomputed from target data and reason codes. Debug details stay report-only. This avoids stale saved text after content names or public reason vocabulary change.

## Enums

Initial `role` values:

- `reserve`: commander has no committed role.
- `raider`: commander pressures a town, hero, site, artifact, or encounter through the current raid actor model.
- `defender`: commander protects an AI-owned town, site, or front through future local hold/intercept logic.
- `retaker`: commander prioritizes recapturing a player-held or recently lost faction-critical site.
- `stabilizer`: commander supports a recently secured or fragile site/front without becoming defense-specific site state.
- `recovering`: commander is blocked by recovery, rebuild, or depleted host state.

No other roles are accepted in schema version 1.

Initial `role_status` values:

- `available`: valid reserve with no active assignment.
- `assigned`: assigned to a target/front but not yet represented by a live map actor.
- `active`: linked to an active spawned raid or equivalent future actor.
- `cooldown`: blocked by recovery day.
- `rebuilding`: blocked by shattered or depleted army continuity.
- `invalid`: target/front no longer valid and must be retasked or cleared.

Initial `target_kind` values:

- empty string for no target
- `town`
- `resource`
- `artifact`
- `encounter`
- `hero`
- `front`
- `commander`

Initial `origin_kind` values:

- empty string for no origin
- `town`
- `spawn_point`
- `front`
- `commander`

Initial `continuity_policy` values:

- `persist_until_invalid`
- `clear_when_invalid`
- `clear_on_arrival`
- `cooldown_then_reserve`

Initial `last_validation` values:

- `valid`
- `invalid_target_missing`
- `invalid_target_resolved`
- `invalid_controller_changed`
- `invalid_commander_unavailable`
- `invalid_front_quiet`
- `blocked_recovery`
- `blocked_rebuild`
- `report_only`

## Defaults And Normalization

Default by commander roster state:

| Existing roster state | Derived default role state |
| --- | --- |
| `status: "recovering"` and `recovery_day > session.day` | `role: "recovering"`, `role_status: "cooldown"`, `fallback_role: "reserve"`, `last_validation: "blocked_recovery"` |
| available but `army_continuity` is shattered/depleted and `commander_can_deploy` would be false | `role: "recovering"`, `role_status: "rebuilding"`, `fallback_role: "reserve"`, `last_validation: "blocked_rebuild"` |
| `status: "active"` with `active_placement_id` | derived active role from linked encounter target if available; otherwise `role: "raider"`, `role_status: "active"`, `assignment_id` derived from linked actor |
| available and deployable with no role state | `role: "reserve"`, `role_status: "available"` |
| malformed, unknown, or future enum values | normalize to `reserve`/`available` with `last_validation: "invalid_target_missing"` unless recovery/rebuild state says otherwise |

Normalization is adapter behavior, not a save migration. It should be safe to run over old saves and report fixtures without bumping `SAVE_VERSION`.

## Assignment Id Derivation

`assignment_id` is saved only when a later implementation writes live role state. It is deterministic and never uses localized labels.

Canonical format:

```text
role:<scenario_id>:<faction_id>:<roster_hero_id>:<role>:<target_kind>:<target_id>:day_<assigned_day>
```

Example:

```text
role:river-pass:faction_mireclaw:hero_vaska:retaker:resource:river_free_company:day_4
```

For report fixtures before saved role state exists, `assignment_id_hint` may use the same components. Fixture hints are not schema fields.

If the same commander is retasked to the same target on a later day, the day suffix creates a new assignment id. If a future long-lived full AI hero task needs cross-day task ids, it can adapter-map this id into a task id rather than changing old saves in place.

## Front Id Derivation

Do not add authored front ids or production content metadata for this slice.

Initial front ids are derived through a small adapter table in future report/normalization code, based on scenario and target ids proven by current reports:

| Scenario | Targets | Derived `front_id` |
| --- | --- | --- |
| `river-pass` | `river_free_company`, `river_signal_post`, `riverwatch_hold`, `duskfen_bastion` | `riverwatch_signal_yard` |
| `glassroad-sundering` | `glassroad_watch_relay`, `glassroad_starlens`, `halo_spire_bridgehead`, `riverwatch_market` | `glassroad_charter_front` |

Fallback derivation:

- town target: `town:<target_id>`
- resource target with linked town or objective context: `<scenario_id>:resource:<target_id>`
- other target: `<scenario_id>:<target_kind>:<target_id>`
- no target: empty string

Future authored front metadata can replace this adapter after real AI hero/front planning exists. Until then, front ids are a report/state grouping aid, not pathing, renderer, editor, or scenario behavior.

## Public Reason Recomposition

`public_reason` is not saved.

Public text is recomputed from `priority_reason_codes` using the existing compact vocabulary proven by the event surfacing and proof reports:

- `town_siege` -> `town siege remains the main front`
- `persistent_income_denial` + `recruit_denial` -> `recruit and income denial`
- `persistent_income_denial` + `route_vision` -> `income and route vision denial`
- `persistent_income_denial` -> `income denial`
- `recruit_denial` -> `recruit denial`
- `route_vision` -> `route vision denial`
- `route_pressure` -> `route pressure`
- `objective_front` -> `objective front`
- `site_seized` -> `site seized`
- `site_contested` -> `site contested`
- `commander_memory` -> `known commander focus`

The future report may display `public_reason`, but it must treat it as derived. Score-table names, fixture annotations, and raw memory counters must not appear in public events or compact summaries.

## Fixture-Only Annotations

The following remain fixture/report-only and must not be saved into `commander_role_state`:

- `fixture_previous_controller`
- `fixture_denial_only`
- `fixture_primary_target_covered`
- `fixture_threatened_by_player_front`
- `fixture_recently_secured`
- `fixture_recent_pressure_count`
- any raw score component
- raw `focus_pressure_count` or `rivalry_count` in public event payloads

Fixture annotations may live under `fixture_state` in `AI_COMMANDER_ROLE_STATE_REPORT` cases. They are requirements shims for deterministic reports, not live schema.

## Old-Save Compatibility

No save migration is approved.

Old saves with no `commander_role_state` must continue to load because the field is optional and nested under existing roster entries. Compatibility behavior:

- Save version stays `9` until a later implementation intentionally changes the save format.
- `SessionStateStore.normalize_payload(...)` continues to preserve unknown nested fields under `overworld`.
- `EnemyTurnRules.normalize_enemy_states(...)` and `EnemyAdventureRules.normalize_commander_roster(...)` are the likely future adapter path, but this slice does not edit them.
- Existing active raids with embedded `enemy_commander_state` remain authoritative for active map actors.
- Scenario-spawned encounters without named roster commanders remain valid and get no mandatory role owner.
- If old saves contain malformed future `commander_role_state`, normalization should drop or downgrade only that nested role state, not the commander roster entry.

## Adapter Path

Future implementation should keep adapters layered:

1. `normalize_commander_role_state(entry, session, faction_id)` builds a safe role view from optional saved role state plus existing roster status.
2. `role_state_from_active_encounter(entry, encounter, session)` derives active role linkage from the existing raid actor.
3. `role_state_for_report_fixture(case)` overlays fixture-only annotations without writing saves.
4. `public_role_event_from_state(role_state)` emits compact derived event records.
5. Later full AI hero state can map `commander_role_state` into a task record:
   - `roster_hero_id` -> hero actor id
   - `role` -> task class
   - `target_kind` / `target_id` / `front_id` -> task target
   - `assignment_id` -> legacy task id or previous assignment reference
   - `priority_reason_codes` -> explainability input

The adapter should be one-way at first: full AI hero state may consume legacy role records later, but this minimal schema should not depend on full hero movement, fog memory, spell/artifact planning, or path plans.

## Validation Strategy

For this planning slice:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

For the next report implementation planning slice, define exact helper boundaries and file ownership only. Do not implement helpers/tests until that slice explicitly moves to implementation.

For future report implementation, validation should include the existing focused proof reports plus the new commander-role report scene, while preserving public leak checks and avoiding coefficient changes.

## Migration Risks

- Saving labels or public text would stale after content or vocabulary changes. Save ids and reason codes only.
- Saving defense-specific site state would contradict the Glassroad proof result that no such state is currently needed.
- Duplicating active raid target fields into role state can desync from `encounters[]`; active raid actors stay authoritative for movement and arrival.
- Overloading `role_status` with existing commander `status` can create contradiction; role status is assignment validity, while commander status remains availability/recovery.
- Front ids derived from a tiny adapter may be too coarse for later maps; keep them replaceable.
- Full AI hero state will eventually need richer task data. This schema must remain an adapter-friendly continuity record, not a dead-end task engine.

## Completion Decision

Minimal commander-role state schema planning is complete.

Recommended next current slice: `strategic-ai-commander-role-report-implementation-planning-10184`.

Rationale: fixture cases and schema boundaries are now both documented, but implementation should still get one narrow planning pass for report helper ownership, fixture normalization policy, validation scene shape, and public leak checks before report code/tests are added.
