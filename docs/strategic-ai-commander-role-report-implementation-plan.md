# Strategic AI Commander Role Report Implementation Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-commander-role-report-implementation-planning-10184`.

## Purpose

Plan the implementation boundaries for a future `AI_COMMANDER_ROLE_STATE_REPORT` before adding report helpers, Godot report coverage, fixture-only state views, live commander-role behavior, save migration, or full AI hero task state.

This slice is planning only. It does not implement report helpers/tests, change AI behavior, tune coefficients, edit production JSON, add durable event logs, migrate saves, add defense-specific durable state, add live commander-role behavior, write schema, change pathing/body-tile/approach behavior, change renderer/editor behavior, import generated PNGs, migrate neutral encounters, add `content/resources.json`, change wood resource ids, activate rare resources, overhaul market caps, or rebalance River Pass.

## Inputs

Authoritative planning inputs:

- `docs/strategic-ai-commander-role-state-plan.md`
- `docs/strategic-ai-commander-role-report-fixture-plan.md`
- `docs/strategic-ai-minimal-commander-role-state-schema-plan.md`
- `docs/strategic-ai-capture-countercapture-defense-proof-report.md`
- `docs/strategic-ai-glassroad-defense-proof-report.md`
- `docs/strategic-ai-town-governor-pressure-report-gate-review.md`

Code inspection inputs:

- `scripts/core/EnemyAdventureRules.gd`
- `scripts/core/EnemyTurnRules.gd`
- `tests/ai_site_control_proof_report.gd`
- `tests/ai_glassroad_defense_proof_report.gd`
- `tests/ai_town_governor_pressure_report.gd`

## Boundary Decision

Recommended next slice: `strategic-ai-commander-role-report-implementation-10184`.

Do not split out another fixture-only state normalization planning slice. The completed fixture plan and minimal schema plan already define the normalization contract. The next useful evidence is a report-only implementation that proves the contract against current River Pass and Glassroad fixtures without writing schema or changing live behavior.

Do not plan a live-client gate next. A live gate should wait until role state changes visible enemy-turn pacing, arrival frequency, map pressure, public turn text, pathing, save state, scenario content, or UI composition.

Do not pause the AI foundation track yet. Commander-role reporting is the next narrow evidence surface needed before full AI hero state, live commander-role behavior, or durable event logs can be justified.

## Helper Ownership

Future implementation should keep helper ownership narrow:

| Owner | Future responsibility | Boundary |
| --- | --- | --- |
| `EnemyAdventureRules.gd` | Report-only commander role state views, role proposal helpers, target/front/reason derivation, public role event construction, active encounter linkage, resource-target evidence, public leak utility. | Helpers must be pure or duplicate-safe report helpers. They must not mutate production content, saves, live target selection, raid advancement, coefficients, or pathing. |
| `EnemyTurnRules.gd` | Existing town-governor pressure report evidence only. | Do not add commander-role ownership here. The commander-role report may call `town_governor_pressure_report(...)` for supporting evidence, but role state belongs with commander/adventure AI helpers. |
| `tests/ai_commander_role_state_report.gd` | Deterministic fixture construction, exact case assertions, payload assembly, failure printing, and public leak assertions. | Test scene owns staged fixture mutations on fresh sessions only. It must not become a production normalizer. |
| `tests/ai_commander_role_state_report.tscn` | Minimal report runner scene matching existing focused AI report scenes. | No UI, no renderer/editor coverage, no live-client routing. |
| `docs/strategic-ai-commander-role-report-implementation-report.md` | Future implementation report summarizing output, caveats, and validation. | Written only in the future implementation slice, not this planning slice. |

Concrete helper names may change to match local style, but the future implementation should keep these conceptual boundaries:

- `commander_role_state_report(session, config, faction_id, cases)`
- `commander_role_state_view(...)`
- `commander_role_proposal_for_resource_target(...)`
- `commander_role_proposal_for_recovery(...)`
- `commander_role_active_encounter_link(...)`
- `commander_role_public_event(...)`
- `commander_role_front_id(...)`
- `commander_role_public_reason_from_codes(...)`
- `commander_role_public_leak_check(...)`

These helpers should sit near existing strategic AI report/event helpers in `EnemyAdventureRules.gd`, not in scene controllers and not in save/session services.

## Fixture Normalization Policy

Fixture normalization is report-only view construction.

Allowed:

- Build a fresh session with `ScenarioFactory.create_session(...)`.
- Run existing normalization calls used by current focused reports.
- Duplicate or mutate the in-memory test session for deterministic fixture setup.
- Set resource controllers, commander status/recovery, commander memory, active encounter linkage, and treasury only inside the test session.
- Store fixture-only annotations under each report case's `fixture_state`, including:
  - `fixture_previous_controller`
  - `fixture_denial_only`
  - `fixture_primary_target_covered`
  - `fixture_threatened_by_player_front`
  - `fixture_recently_secured`
  - `fixture_recent_pressure_count`
- Derive a role state view from existing roster status, active encounter target fields, resource pressure report rows, and fixture annotations.

Not allowed:

- Saving `commander_role_state` into session payloads.
- Bumping `SessionStateStore.SAVE_VERSION`.
- Editing `normalize_enemy_states(...)` or `normalize_commander_roster(...)` to persist role fields.
- Adding production JSON fields, sidecar schemas, or authored front ids.
- Treating fixture annotations as live schema.
- Adding defense locks such as `site_defended_until_day`.
- Making live target choice depend on role proposal helpers.

If a future helper needs to normalize malformed role-state data for fixture coverage, it should return a local dictionary view with `schema_status: "report_fixture_only"` and leave the source session unchanged.

## Report Scene Shape

The future report scene should mirror the existing focused AI reports:

- Script: `tests/ai_commander_role_state_report.gd`
- Scene: `tests/ai_commander_role_state_report.tscn`
- Node type: `Node`
- Entry point: `_ready()` defers `_run()`
- Success output: exactly one line starting with `AI_COMMANDER_ROLE_STATE_REPORT `
- Failure output: same marker with `{"ok": false, ...}` and process exit `1`
- Success exit: process exit `0`

Top-level payload:

```json
{
  "ok": true,
  "report_id": "AI_COMMANDER_ROLE_STATE_REPORT",
  "schema_status": "report_fixture_only",
  "day": 1,
  "cases": [],
  "public_leak_check": {},
  "caveats": []
}
```

Case coverage must include all eight cases from the fixture plan:

1. `mireclaw_free_company_retaker`
2. `mireclaw_free_company_raider`
3. `mireclaw_signal_post_companion`
4. `embercourt_glassroad_relay_defender`
5. `embercourt_glassroad_relay_retaker`
6. `embercourt_glassroad_stabilizer`
7. `commander_recovery_blocks_assignment`
8. `commander_memory_continuity`

Each case must include:

- `case_id`
- `scenario_id`
- `faction_id`
- `fixture_state`
- `commander`
- `active_encounter_link`
- `target`
- `role_proposal`
- `supporting_evidence`
- `public_role_event`
- `case_pass_criteria`

The implementation should assert exact target ids, role values, role statuses, expected public reasons, reason-code minimums, recovery blocking, memory summary presence, accepted town-front sanity references, and public leak results.

## Public Leak Checks

The public leak check should recursively inspect every `public_role_event`, any copied compact public AI event, and any compact public summary string.

Allowed public keys are the existing compact event keys plus commander role actor fields:

- `event_id`
- `day`
- `sequence`
- `event_type`
- `faction_id`
- `faction_label`
- `actor_id`
- `actor_label`
- `target_kind`
- `target_id`
- `target_label`
- `target_x`
- `target_y`
- `visibility`
- `public_importance`
- `summary`
- `reason_codes`
- `public_reason`
- `debug_reason`
- `state_policy`

Blocked public tokens:

- `base_value`
- `persistent_income_value`
- `recruit_value`
- `scarcity_value`
- `denial_value`
- `route_pressure_value`
- `town_enablement_value`
- `objective_value`
- `faction_bias`
- `travel_cost`
- `guard_cost`
- `assignment_penalty`
- `final_priority`
- `final_score`
- `income_value`
- `growth_value`
- `pressure_value`
- `category_bonus`
- `raid_score`
- `focus_pressure_count`
- `rivalry_count`
- `fixture_previous_controller`
- `fixture_denial_only`
- `fixture_primary_target_covered`
- `fixture_threatened_by_player_front`
- `fixture_recently_secured`
- `fixture_recent_pressure_count`

Detailed score rows and fixture annotations may appear only under `supporting_evidence`, `fixture_state`, or `role_proposal.report_debug_reason`. Public `debug_reason` fields remain allowed for compatibility with current compact event records, but their values must not contain blocked tokens.

## Exact Implementation Sequence

Future implementation should proceed in this order:

1. Add report-only role constants and blocked public leak token lists in `EnemyAdventureRules.gd`.
2. Add pure helper adapters for front-id derivation and public-reason recomposition from reason codes.
3. Add a report-only commander role state view that derives `reserve`, `active`, `recovering`, `cooldown`, and `rebuilding` from existing commander roster and active encounter state without writing the session.
4. Add resource-target role proposal helpers that consume current `resource_pressure_report(...)` rows and fixture annotations to decide only the planned report roles: `raider`, `retaker`, `defender`, `stabilizer`, `recovering`, and `reserve`.
5. Add active encounter link and assignment id hint helpers using deterministic components only.
6. Add public role event construction through the existing compact event vocabulary, with `event_type: "ai_commander_role_assigned"` and `state_policy: "derived"`.
7. Add recursive public leak checks.
8. Add `tests/ai_commander_role_state_report.gd` and `.tscn` with the eight deterministic cases.
9. Add future implementation report doc summarizing the output and caveats.
10. Run the full validation command set, including existing focused strategic AI reports.
11. Commit locally if all validation passes. Do not push.

This order keeps report helpers isolated first, then proves them through a focused scene, then records the evidence. It intentionally avoids schema writes, live role adoption, save migration, coefficient tuning, and full AI hero task implementation.

## Validation Commands

Planning-slice validation:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

Future report implementation validation:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_state_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_glassroad_defense_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

Manual live-client gate remains deferred unless the future report implementation changes visible enemy-turn pacing, arrival frequency, map pressure, public turn text, pathing, save state, production scenario content, or UI composition.

## Completion Decision

Commander-role report implementation boundary planning is complete.

Recommended next current slice: `strategic-ai-commander-role-report-implementation-10184`.

Rationale: the fixture contract and minimal schema boundary are complete. The next valuable step is report-only implementation and focused Godot coverage for the eight cases, still without live commander-role behavior, schema writes, save migration, durable event logs, coefficient tuning, defense-specific durable state, production JSON migration, pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, rare-resource activation, market-cap overhaul, or River Pass rebalance.
