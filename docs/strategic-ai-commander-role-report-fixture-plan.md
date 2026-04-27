# Strategic AI Commander Role Report Fixture Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-commander-role-report-fixture-planning-10184`.

## Purpose

Plan exact deterministic fixture cases and report payloads for a future `AI_COMMANDER_ROLE_STATE_REPORT` before adopting commander-role schema, save migration, report helpers, tests, live behavior, or full AI hero task state.

This slice is planning only. It does not implement report helpers/tests, add schema, change AI behavior, tune coefficients, edit production JSON, add durable event logs, migrate saves, add defense-specific durable state, change pathing/body-tile/approach behavior, change renderer/editor behavior, import generated PNGs, migrate neutral encounters, add `content/resources.json`, change wood resource ids, activate rare resources, overhaul market caps, or rebalance River Pass.

## Evidence Baseline

Use these completed proof surfaces as fixture authority:

- `docs/strategic-ai-capture-countercapture-defense-proof-report.md`: Mireclaw `river-pass` report proves `river_free_company` and `river_signal_post` rank first and second when player-controlled, Free Company seizure flips controller to `faction_mireclaw`, public assignment/seizure events stay compact, and the full selector can still prefer `riverwatch_hold`.
- `docs/strategic-ai-glassroad-defense-proof-report.md`: Embercourt `glassroad-sundering` report proves `glassroad_watch_relay` and `glassroad_starlens` rank first and second when player-controlled, relay assignment and retake/controller flip work, `halo_spire_bridgehead` remains the accepted town-front sanity target, and `riverwatch_market` town governor stabilization is visible.
- `docs/strategic-ai-commander-role-state-plan.md`: future role values are `raider`, `defender`, `retaker`, `stabilizer`, `recovering`, and `reserve`; role state stays separate from current raid encounter fields and current commander roster continuity.

Current code inspection is evidence only: `EnemyAdventureRules.gd` already normalizes commander identity, status, recovery day, target memory, army continuity, and active encounter linkage; `EnemyTurnRules.gd` already normalizes enemy state, commander rosters, town governor pressure, raid reinforcement, and commander rebuild surfaces. Do not change either file for this slice.

## Future Report Contract

The future report should print exactly one line headed:

```text
AI_COMMANDER_ROLE_STATE_REPORT <json>
```

Top-level payload fields:

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

Each `cases[]` entry must use this stable shape:

```json
{
  "case_id": "mireclaw_free_company_retaker",
  "scenario_id": "river-pass",
  "faction_id": "faction_mireclaw",
  "fixture_state": {},
  "commander": {
    "roster_hero_id": "hero_vaska",
    "status": "available",
    "active_placement_id": "",
    "recovery_day": 0,
    "army_status": "ready",
    "memory_summary": ""
  },
  "active_encounter_link": {
    "linked": false,
    "placement_id": "",
    "target_kind": "",
    "target_id": ""
  },
  "target": {
    "target_kind": "resource",
    "target_id": "river_free_company",
    "target_label": "Riverwatch Free Company Yard",
    "front_id": "riverwatch_signal_yard",
    "origin_kind": "town",
    "origin_id": "duskfen_bastion"
  },
  "role_proposal": {
    "role": "retaker",
    "role_status": "assigned",
    "validity": "valid",
    "assignment_id_hint": "faction_mireclaw:hero_vaska:river_free_company",
    "priority_reason_codes": ["persistent_income_denial", "recruit_denial", "route_pressure", "player_town_support"],
    "public_reason": "recruit and income denial",
    "report_debug_reason": "report-only target score and fixture annotation",
    "expected_next_transition": "spawn_or_link_raid"
  },
  "supporting_evidence": {
    "resource_rank": 1,
    "accepted_full_selector_target_id": "riverwatch_hold",
    "reference_report": "docs/strategic-ai-capture-countercapture-defense-proof-report.md"
  },
  "public_role_event": {
    "event_type": "ai_commander_role_assigned",
    "faction_id": "faction_mireclaw",
    "actor_id": "hero_vaska",
    "target_kind": "resource",
    "target_id": "river_free_company",
    "public_importance": "high",
    "reason_codes": ["persistent_income_denial", "recruit_denial", "route_pressure", "player_town_support"],
    "public_reason": "recruit and income denial",
    "state_policy": "derived"
  },
  "case_pass_criteria": []
}
```

`fixture_state` may include report-only annotations such as `fixture_previous_controller` or `fixture_recent_pressure_count`. These annotations must not be saved, added to production JSON, or treated as live schema.

## Deterministic Cases

### 1. Mireclaw Free Company Retaker

Case id: `mireclaw_free_company_retaker`.

Setup:

- Scenario: `river-pass`.
- Enemy faction: `faction_mireclaw`, label `Duskfen Marsh Claim`.
- Use normalized commander roster and select first available Mireclaw commander: `hero_vaska`.
- Set `river_free_company` controller to `player`.
- Set `river_signal_post` controller to `player` so the ordering comparator is present.
- Add report-only fixture annotation: `fixture_previous_controller: "faction_mireclaw"` for `river_free_company`.
- No active encounter is linked to `hero_vaska`.

Expected payload:

- `role_proposal.role`: `retaker`.
- `role_proposal.role_status`: `assigned`.
- `target.target_id`: `river_free_company`.
- `target.front_id`: `riverwatch_signal_yard`.
- `target.origin_id`: `duskfen_bastion`.
- `priority_reason_codes` includes `persistent_income_denial`, `recruit_denial`, `route_pressure`, and `player_town_support`.
- `public_reason`: `recruit and income denial`.
- `supporting_evidence.resource_rank`: `1`.
- `supporting_evidence.accepted_full_selector_target_id`: `riverwatch_hold`.
- `expected_next_transition`: `spawn_or_link_raid`.

Pass/fail:

- Pass if Free Company is the proposed role target and role is exactly `retaker`.
- Fail if a simple pickup outranks the Free Company role proposal.
- Fail if the full-selector town-front sanity result is treated as a blocker.
- Fail if public output leaks score fields.

### 2. Mireclaw Free Company Raider

Case id: `mireclaw_free_company_raider`.

Setup:

- Same scenario, faction, commander, and staged player ownership as the retaker case.
- Do not add `fixture_previous_controller`.
- Add report-only fixture annotation: `fixture_denial_only: true`.

Expected payload:

- `role_proposal.role`: `raider`.
- `target.target_id`: `river_free_company`.
- `priority_reason_codes` includes `persistent_income_denial`, `recruit_denial`, `route_pressure`, and `player_town_support`.
- `public_reason`: `recruit and income denial`.
- `supporting_evidence.resource_rank`: `1`.
- `expected_next_transition`: `spawn_or_link_raid`.

Pass/fail:

- Pass if Free Company is the proposed role target and role is exactly `raider`.
- Fail if the report collapses retaker and raider into one ambiguous role without fixture-state explanation.
- Fail if the case implies coefficient tuning is needed.

### 3. Mireclaw Signal Post Companion

Case id: `mireclaw_signal_post_companion`.

Setup:

- Scenario: `river-pass`.
- Enemy faction: `faction_mireclaw`.
- Primary commander `hero_vaska` is already proposed for `river_free_company` in the same synthetic report batch, or report-only `fixture_primary_target_covered: "river_free_company"` is set.
- Select next available Mireclaw commander: `hero_sable`.
- Set `river_signal_post` controller to `player`.

Expected payload:

- `role_proposal.role`: `raider`.
- `target.target_id`: `river_signal_post`.
- `target.front_id`: `riverwatch_signal_yard`.
- `target.origin_id`: `duskfen_bastion`.
- `priority_reason_codes` includes `persistent_income_denial`, `route_vision`, and `player_town_support`.
- `public_reason`: `income and route vision denial`.
- `supporting_evidence.resource_rank`: `2` when Free Company is present and uncovered; `1` when Free Company is fixture-covered or unavailable.
- `expected_next_transition`: `spawn_or_link_raid`.

Pass/fail:

- Pass if Signal Post is selected only as companion or fallback coverage, not by demoting Free Company evidence.
- Fail if the Signal Post role duplicates an already covered Free Company assignment.
- Fail if public reason text uses report-only score terminology.

### 4. Embercourt Glassroad Relay Defender

Case id: `embercourt_glassroad_relay_defender`.

Setup:

- Scenario: `glassroad-sundering`.
- Enemy faction: `faction_embercourt`, label `Charter Road Wardens`.
- Use normalized commander roster and select `hero_caelen`.
- Set `glassroad_watch_relay` controller to `faction_embercourt`.
- Add report-only fixture annotation: `fixture_threatened_by_player_front: true`.
- Keep `halo_spire_bridgehead` as the accepted full-selector town-front sanity target.

Expected payload:

- `role_proposal.role`: `defender`.
- `target.target_id`: `glassroad_watch_relay`.
- `target.front_id`: `glassroad_charter_front`.
- `target.origin_id`: `riverwatch_market`.
- `priority_reason_codes` includes `persistent_income_denial`, `route_vision`, and `player_town_support`.
- `public_reason`: `income and route vision denial`.
- `supporting_evidence.accepted_full_selector_target_id`: `halo_spire_bridgehead`.
- `expected_next_transition`: `hold_front_or_intercept`.

Pass/fail:

- Pass if an Embercourt-owned but threatened relay can produce `defender` without adding defense-specific durable site state.
- Fail if the case requires `site_defended_until_day`, `defense_lock`, or any new durable defense field.
- Fail if the full-selector town front is treated as contradictory evidence.

### 5. Embercourt Glassroad Relay Retaker

Case id: `embercourt_glassroad_relay_retaker`.

Setup:

- Scenario: `glassroad-sundering`.
- Enemy faction: `faction_embercourt`.
- Select `hero_caelen` unless reserved by another same-batch case; otherwise select `hero_mira`.
- Set `glassroad_watch_relay` controller to `player`.
- Add report-only fixture annotation: `fixture_previous_controller: "faction_embercourt"`.
- Keep `glassroad_starlens` controller as `player` for companion ordering.

Expected payload:

- `role_proposal.role`: `retaker`.
- `target.target_id`: `glassroad_watch_relay`.
- `priority_reason_codes` includes `persistent_income_denial`, `route_vision`, and `player_town_support`.
- `public_reason`: `income and route vision denial`.
- `supporting_evidence.resource_rank`: `1`.
- `supporting_evidence.accepted_full_selector_target_id`: `halo_spire_bridgehead`.
- `expected_next_transition`: `spawn_or_link_raid`.

Pass/fail:

- Pass if relay retake is proposed without coefficient tuning or defense-specific durable state.
- Fail if `glassroad_starlens`, simple pickups, or town-front sanity output displace the relay retake case.
- Fail if the report omits the accepted staged controller-flip evidence reference.

### 6. Embercourt Glassroad Stabilizer

Case id: `embercourt_glassroad_stabilizer`.

Setup:

- Scenario: `glassroad-sundering`.
- Enemy faction: `faction_embercourt`.
- Select `hero_seren` or `hero_lyra` as the proposed support commander.
- Set `glassroad_starlens` controller to `faction_embercourt` or use report-only `fixture_recently_secured: true`.
- Include `riverwatch_market` town-governor stabilization evidence from the Glassroad report.

Expected payload:

- `role_proposal.role`: `stabilizer`.
- `target.target_id`: `glassroad_starlens`.
- `target.front_id`: `glassroad_charter_front`.
- `priority_reason_codes` includes `route_pressure`.
- `public_reason`: `route pressure`.
- `supporting_evidence.starlens_response_profile.action_label`: `Relight Shrine`.
- `supporting_evidence.starlens_response_profile.watch_days`: `3`.
- `supporting_evidence.starlens_response_profile.readiness_bonus`: `1`.
- `supporting_evidence.starlens_response_profile.pressure_bonus`: `1`.
- `supporting_evidence.starlens_response_profile.recovery_relief`: `2`.
- `expected_next_transition`: `support_front_stabilization`.

Pass/fail:

- Pass if Starlens can be proposed as a stabilizer target while preserving its current coarse `route pressure` public reason.
- Fail if the case claims Starlens has proved a broad seizure path.
- Fail if the case invents new site metadata to make the reason stronger.

### 7. Commander Recovery Blocks Assignment

Case id: `commander_recovery_blocks_assignment`.

Setup:

- Scenario: `river-pass`.
- Enemy faction: `faction_mireclaw`.
- Use `hero_vaska` with `status: "recovering"` and `recovery_day` greater than report day.
- Keep `river_free_company` player-controlled and otherwise attractive.
- Optionally include a second available commander to prove fallback assignment separately.

Expected payload:

- Recovering commander entry:
  - `role_proposal.role`: `recovering`.
  - `role_proposal.role_status`: `cooldown`.
  - `role_proposal.validity`: `blocked`.
  - `target.target_id`: empty string.
  - `expected_next_transition`: `wait_until_recovery_day`.
- If fallback commander is included:
  - fallback commander may receive `retaker` or `raider` for `river_free_company`.
  - public output must distinguish blocked commander from fallback assignment.

Pass/fail:

- Pass if recovering commander never receives an active assignment.
- Pass if a separate available commander can still be assigned.
- Fail if the report assigns a recovering commander to Free Company because the target score is high.
- Fail if recovery data is duplicated into a new durable schema field.

### 8. Commander Memory Continuity

Case id: `commander_memory_continuity`.

Setup:

- Scenario: `river-pass`.
- Enemy faction: `faction_mireclaw`.
- Select `hero_vaska`.
- Set current target candidate to `river_free_company`.
- Add existing-compatible target memory to the commander seed:
  - `focus_target_id`: `river_free_company`.
  - `focus_target_label`: `Riverwatch Free Company Yard`.
  - `focus_pressure_count`: `2`.
- Keep `river_free_company` player-controlled.

Expected payload:

- `role_proposal.role`: `retaker` if `fixture_previous_controller` is present; otherwise `raider`.
- `target.target_id`: `river_free_company`.
- `commander.memory_summary`: includes `Riverwatch Free Company Yard`.
- `priority_reason_codes` includes `persistent_income_denial` and `recruit_denial`.
- `role_proposal.report_debug_reason` may mention target memory.
- `public_role_event.public_reason`: `recruit and income denial`.
- Public event summary may say the commander returns to the Free Company yard, but must not expose memory counters.

Pass/fail:

- Pass if memory appears in report/debug explanation and commander summary.
- Fail if memory changes target ordering by an unexplained hidden bonus.
- Fail if public output leaks raw `focus_pressure_count`, score tables, or target-memory internals.

## Public Leak Checks

The future report must run leak checks over every `public_role_event`, public assignment/seizure/pressure event copied into the payload, and any compact public role summary.

Allowed public role/event keys:

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

Detailed score fields, fixture annotations, and target-memory counters may appear only in `supporting_evidence`, `fixture_state`, or `role_proposal.report_debug_reason`. Public `debug_reason` fields may exist for compatibility with current compact event records, but they must not contain blocked score or memory tokens.

## Report Pass Criteria

The future `AI_COMMANDER_ROLE_STATE_REPORT` passes only if:

- All eight cases return their exact expected target ids, roles, role statuses, public reasons, and reason-code minimums.
- `river_free_company` remains the primary Mireclaw River Pass denial/retake target, with `river_signal_post` as companion or fallback coverage.
- `glassroad_watch_relay` remains the primary Embercourt Glassroad relay defender/retaker target, with `glassroad_starlens` as the stabilizer companion.
- Recovering commanders are blocked from active assignments.
- Commander memory appears in report/debug continuity without leaking raw counters to public output.
- Public leak checks pass.
- The report references accepted full-selector town-front sanity outputs instead of treating them as failures.
- The implementation does not tune coefficients, edit production JSON, add schema/save migration, add durable event logs, add defense-specific durable state, or change live behavior.

## Validation Commands

Planning-only validation for this slice:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

Future report implementation validation should add only after schema planning accepts the fixture contract:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_state_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_glassroad_defense_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

Manual live-client gate remains deferred until a later slice changes visible enemy-turn pacing, arrival frequency, map pressure, public turn text, pathing, save state, production scenario content, or UI composition.

## Staged Next Steps

1. `strategic-ai-minimal-commander-role-state-schema-planning-10184`
   - Decide exact field location, enum set, defaults, old-save compatibility, assignment id derivation, front id derivation, public-reason recomputation, and adapter path to later full AI hero state.
   - Still no runtime behavior adoption.

2. `strategic-ai-commander-role-report-implementation-10184`
   - Implement report-only helpers and focused Godot coverage for the fixture cases if the schema plan accepts this fixture contract.
   - No target ordering or coefficient changes.

3. `strategic-ai-commander-role-state-fixture-implementation-10184`
   - Add fixture-only normalization if needed to prove role state shape.
   - Do not write production saves or make live behavior depend on the state.

4. `strategic-ai-live-client-gate-planning-10184`
   - Plan a manual enemy-turn gate only after role reports or state adoption affect visible turn playback, arrival frequency, map pressure, or player-facing threat composition.

## Completion Decision

Commander-role report fixture planning is complete.

Recommended next current slice: `strategic-ai-minimal-commander-role-state-schema-planning-10184`.

Rationale: the report fixtures now define exact cases and payload expectations. The next useful work is to decide the minimal schema boundary and compatibility rules before implementing report helpers/tests or adopting live behavior.
