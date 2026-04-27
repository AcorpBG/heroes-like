# Strategic AI Commander Role Live-Turn Transcript Report Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-commander-role-live-turn-transcript-report-planning-10184`.

## Purpose

Plan a future behavior-neutral `AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT` over existing enemy-turn execution.

The later report should connect the already-passed commander-role report evidence to the real enemy-turn path without changing target selection, raid movement, raid arrival, town-governor choices, save data, production JSON, coefficients, or public UI composition.

This slice is planning only. It does not implement reports, tests, report helpers, schema writes, save migration, durable event logs, defense-specific durable state, full AI hero tasks, live commander-role behavior, production JSON edits, coefficient tuning, pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, `content/resources.json`, wood id change, rare resources, market-cap changes, or River Pass rebalance.

## Evidence Baseline

- `docs/strategic-ai-commander-role-adoption-sequencing-plan.md` selected derived live-turn transcript/report surfacing as the next bridge before schema or live behavior adoption.
- `docs/strategic-ai-commander-role-report-gate-review.md` passed the focused `AI_COMMANDER_ROLE_STATE_REPORT` gate with eight cases and a passing public leak check.
- `docs/strategic-ai-commander-role-report-implementation-report.md` records that commander-role report helpers live in `EnemyAdventureRules.gd`, remain report-only, and do not alter `assign_target`, `choose_target`, `advance_raids`, saves, or coefficients.
- `docs/strategic-ai-minimal-commander-role-state-schema-plan.md` defines the future optional `enemy_states[].commander_roster[].commander_role_state` field, but no schema write is approved.
- `EnemyTurnRules.run_enemy_turn(...)` is the current live enemy-turn owner. It normalizes enemy state, runs each enemy empire cycle, applies town economy/build/recruit/reinforcement logic, advances raids, queues battles, spawns raids, advances siege pressure, updates posture, and returns a compact message.
- `EnemyAdventureRules.advance_raids(...)` is the current raid execution owner. It assigns targets, moves active raids, resolves arrivals, updates arrival/seizure/contest state, and emits compact derived event records.

## Ownership Decision

The future transcript report should keep ownership layered:

| Layer | Owner | Responsibility |
| --- | --- | --- |
| Fixture orchestration | `tests/ai_commander_role_turn_transcript_report.gd` and `.tscn` | Build deterministic sessions, apply fixture-only setup, snapshot before state, call existing `EnemyTurnRules.run_enemy_turn(...)` once, snapshot after state, print one report line. |
| Live turn execution | `EnemyTurnRules.gd` | Remains the behavior authority. The transcript must not fork or replace `_run_empire_cycle(...)`, `_spawn_raid(...)`, recruitment routing, battle queueing, siege, posture, or the returned message. |
| Transcript assembly | `EnemyAdventureRules.gd` report-only helpers | Build derived before/after commander-role proposals, active commander links, raid movement/arrival summaries, target assignment/no-op records, public transcript events, and leak checks from snapshots and existing event vocabulary. |
| Town-governor support | Existing `EnemyTurnRules.town_governor_pressure_report(...)` and compact town-governor event helpers | Provide supporting references only. Town-governor build/recruit/reinforcement decisions are not transcript authority and must not expose score tables in public transcript events. |

This keeps `EnemyAdventureRules.gd` as the commander-role/report helper owner while acknowledging that `EnemyTurnRules.gd` remains the live enemy-turn behavior owner.

## Report Marker

The later implementation should print exactly one line starting with:

```text
AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT
```

## Payload Shape

Top-level payload:

```json
{
  "ok": true,
  "report_id": "AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT",
  "schema_status": "derived_turn_transcript_report_only",
  "behavior_policy": "observe_existing_enemy_turn_only",
  "save_policy": "no_commander_role_state_write",
  "cases": [],
  "public_leak_check": {},
  "validation_caveats": []
}
```

Case payload:

```json
{
  "case_id": "river_pass_mireclaw_signal_yard_turn",
  "scenario_id": "river-pass",
  "faction_id": "faction_mireclaw",
  "day_before": 1,
  "day_after": 2,
  "fixture_setup": {},
  "turn_result": {
    "ok": true,
    "message_summary": ""
  },
  "phase_records": [],
  "active_commander_links": {
    "before": [],
    "after": []
  },
  "derived_role_proposals": {
    "before_turn": [],
    "after_turn": []
  },
  "target_assignment_records": [],
  "target_no_op_records": [],
  "raid_movement_summary": [],
  "raid_arrival_summary": [],
  "town_governor_supporting_event_refs": [],
  "public_transcript_events": [],
  "case_pass_criteria": []
}
```

All transcript records must include one of these source markers:

- `state_policy: "derived"`
- `state_policy: "report_only"`
- `schema_status: "report_fixture_only"`
- `source_policy: "snapshot_derived"`

No transcript record may imply saved role state, durable event state, or live role adoption.

## Fixture Setup

The later implementation should cover two deterministic cases first.

### River Pass Mireclaw Signal Yard Turn

Case id: `river_pass_mireclaw_signal_yard_turn`.

Setup:

- Create `river-pass` as a skirmish session on normal difficulty.
- Normalize overworld state, fog, enemy states, raid armies, and commander rosters through existing public helpers.
- Set `river_free_company` and `river_signal_post` to player-controlled through fixture-only session mutation, matching the prior report evidence.
- Ensure the Mireclaw enemy state has either one existing active raid or enough existing pressure to launch one through current `_can_launch_raid(...)` behavior. The fixture may patch session state only inside the test scene; it must not edit production JSON.
- Keep `riverwatch_hold` as the accepted full-selector town-front sanity target.

Expected evidence:

- Before-turn role proposals identify Free Company as the primary retaker/raider pressure target and Signal Post as the companion route-vision/income target.
- Target assignment records show either a current assignment to Free Company or a no-op reason explaining why town-front pressure, unchanged target, recovery, max raids, no open spawn point, or launch threshold prevented assignment.
- Raid movement summary shows the raid host's before/after coordinates and distance delta when an active raid moves.
- Arrival summary shows site seizure/contest only if the existing movement path reaches the target this turn.
- Public transcript events stay compact and score-free.

### Glassroad Embercourt Relay Turn

Case id: `glassroad_embercourt_relay_turn`.

Setup:

- Create `glassroad-sundering` as a skirmish session on normal difficulty.
- Normalize overworld state, fog, enemy states, raid armies, and commander rosters through existing public helpers.
- Set `glassroad_watch_relay` and, where useful, `glassroad_starlens` to player-controlled or AI-controlled per subcase fixture state.
- Ensure the Embercourt enemy state has an active raid or enough pressure to exercise current launch/movement behavior without production JSON edits.
- Keep `halo_spire_bridgehead` as the accepted full-selector town-front sanity target and `riverwatch_market` as the supporting town-governor surface.

Expected evidence:

- Before-turn role proposals can express relay defender, relay retaker, and Starlens stabilizer views as derived/report-only records.
- After-turn proposals reflect the existing turn result without persisting role state.
- Town-governor supporting event references include only compact references to build/recruit/garrison/raid/rebuild decisions.
- Public transcript events do not leak build/recruit score tables or fixture annotations.

## Enemy-Turn Phase Records

The transcript should report phase records as derived observations, not as new live instrumentation. Required phase ids:

1. `normalize_enemy_states`
2. `town_income_and_governor_projection`
3. `town_build_recruit_reinforce`
4. `pressure_gain`
5. `advance_existing_raids`
6. `battle_queue_checks`
7. `spawn_raid_if_ready`
8. `siege_and_posture`
9. `turn_summary`

Each phase record should use compact fields:

```json
{
  "phase_id": "advance_existing_raids",
  "source_policy": "snapshot_derived",
  "faction_id": "faction_mireclaw",
  "before_counts": {},
  "after_counts": {},
  "event_ref_ids": [],
  "no_op_reason": ""
}
```

Detailed score rows may appear only under case-level report/debug `supporting_evidence` if needed. They must not appear in `public_transcript_events`.

## Active Commander Links

Active commander links should be derived before and after the turn from:

- `enemy_states[].commander_roster[]`
- active spawned raid encounters under `session.overworld.encounters[]`
- embedded `enemy_commander_state`
- existing `EnemyAdventureRules.commander_role_active_encounter_link(...)`

Required fields:

```json
{
  "roster_hero_id": "hero_vaska",
  "commander_label": "Vaska Reedmaw",
  "status": "active",
  "active_placement_id": "faction_mireclaw_raid_1",
  "linked": true,
  "target_kind": "resource",
  "target_id": "river_free_company",
  "target_label": "Riverwatch Free Company Yard",
  "army_status": "ready",
  "memory_summary": "Riverwatch Free Company Yard",
  "state_policy": "derived"
}
```

If no active link exists, the record should still explain the derived no-link reason: `reserve`, `recovering`, `rebuilding`, `no_spawned_actor`, or `scenario_spawn_without_roster_commander`.

## Derived Role Proposals

The transcript should include derived role proposals before and after the turn.

Required proposal fields:

```json
{
  "timing": "before_turn",
  "roster_hero_id": "hero_vaska",
  "role": "retaker",
  "role_status": "assigned",
  "validity": "valid",
  "target_kind": "resource",
  "target_id": "river_free_company",
  "front_id": "riverwatch_signal_yard",
  "priority_reason_codes": ["persistent_income_denial", "recruit_denial"],
  "public_reason": "recruit and income denial",
  "assignment_id_hint": "role:river-pass:faction_mireclaw:hero_vaska:retaker:resource:river_free_company:day_1",
  "expected_next_transition": "spawn_or_retarget_existing_raid",
  "state_policy": "report_only"
}
```

Before-turn proposals answer "what role vocabulary describes the state the current turn is about to execute?" After-turn proposals answer "what role vocabulary describes the state after the existing turn result?" Neither proposal may change the turn.

## Target Assignment And No-Op Reasons

Target assignment records should derive from existing active raid target fields and `ai_target_assigned` events. Required fields:

- `placement_id`
- `roster_hero_id`
- `previous_target_signature`
- `current_target_signature`
- `assignment_changed`
- `target_kind`
- `target_id`
- `target_label`
- `reason_codes`
- `public_reason`
- `event_ref_id`
- `state_policy: "derived"`

No-op records are required when no target assignment event exists for a relevant commander. Allowed no-op reasons:

- `target_unchanged`
- `no_active_commander`
- `commander_recovering`
- `commander_rebuilding`
- `no_valid_target`
- `town_front_dominates_selector`
- `pressure_below_launch_threshold`
- `max_active_raids_reached`
- `no_open_spawn_point`
- `no_available_commander`
- `town_governor_only_turn`
- `battle_queued_before_spawn`
- `no_existing_raid_to_move`
- `report_fixture_not_configured_for_assignment`

The report should fail if a no-op record uses an unrecognized reason or hides a relevant missing assignment without explanation.

## Raid Movement And Arrival Summary

Movement records should compare before/after active raid snapshots:

```json
{
  "placement_id": "faction_mireclaw_raid_1",
  "roster_hero_id": "hero_vaska",
  "from": {"x": 7, "y": 1},
  "to": {"x": 6, "y": 2},
  "target_kind": "resource",
  "target_id": "river_free_company",
  "goal_distance_before": 5,
  "goal_distance_after": 4,
  "arrived_before": false,
  "arrived_after": false,
  "movement_policy": "existing_advance_raids",
  "state_policy": "derived"
}
```

Arrival records should summarize existing arrival side effects only:

- target kind/id/label
- target controller before/after when relevant
- `ai_site_seized` or `ai_site_contested` event refs
- pillage message refs if current code emits one
- battle queue refs if the arrival queues a battle
- `state_policy: "derived"`

The report must not create new arrival state, controller flips, route effects, body-tile behavior, or pathing behavior.

## Town-Governor Supporting Event References

Town-governor references should be compact pointers to current support events, not full town-governor reports.

Allowed public/support event types:

- `ai_town_built`
- `ai_town_recruited`
- `ai_garrison_reinforced`
- `ai_raid_reinforced`
- `ai_commander_rebuilt`

Reference shape:

```json
{
  "event_ref_id": "1:faction_mireclaw:ai_garrison_reinforced:duskfen_bastion",
  "event_type": "ai_garrison_reinforced",
  "town_placement_id": "duskfen_bastion",
  "target_kind": "town",
  "target_id": "duskfen_bastion",
  "public_reason": "stabilizes garrison",
  "reason_codes": ["garrison_safety"],
  "supports_front_id": "riverwatch_signal_yard",
  "state_policy": "derived"
}
```

Build/recruit score fields such as `garrison_score`, `raid_score`, `rebuild_score`, selected-build score rows, and raw treasury affordability details must stay out of public transcript events.

## Public Transcript Events

The future public transcript event set should be compact and recursively leak-checked. Allowed event shapes should be limited to:

- `ai_commander_role_observed`
- `ai_target_assigned`
- `ai_raid_moved`
- `ai_raid_arrived`
- `ai_site_seized`
- `ai_site_contested`
- `ai_town_governor_support_ref`
- `ai_turn_phase_summary`

Allowed public fields:

- `event_id`
- `day`
- `sequence`
- `event_type`
- `phase_id`
- `faction_id`
- `faction_label`
- `actor_id`
- `actor_label`
- `target_kind`
- `target_id`
- `target_label`
- `target_x`
- `target_y`
- `from_x`
- `from_y`
- `to_x`
- `to_y`
- `visibility`
- `public_importance`
- `summary`
- `reason_codes`
- `public_reason`
- `debug_reason`
- `state_policy`

The public events can include `debug_reason` only if it is a compact phrase such as `derived commander role`, `existing raid movement`, or `supporting town governor event`. It must not contain score-table values, fixture names, raw memory counters, or saved-state claims.

## Public Leak Checks

The later report should run a recursive public leak check over `public_transcript_events` and any compact public summaries.

Blocked public tokens:

- score-table keys: `base_value`, `persistent_income_value`, `recruit_value`, `scarcity_value`, `denial_value`, `route_pressure_value`, `town_enablement_value`, `objective_value`, `faction_bias`, `travel_cost`, `guard_cost`, `assignment_penalty`, `final_priority`, `final_score`, `garrison_score`, `raid_score`, `rebuild_score`
- fixture tokens: `fixture_previous_controller`, `fixture_denial_only`, `fixture_primary_target_covered`, `fixture_threatened_by_player_front`, `fixture_recently_secured`, `fixture_recent_pressure_count`, `fixture_state`
- raw memory/detail tokens: `focus_pressure_count`, `rivalry_count`, `resource_score_breakdown`, `target_memory`, `commander_role_state`
- save/schema claims: `saved`, `durable`, `migration`, `SAVE_VERSION`

The check should fail if any public event contains an unapproved key or blocked token. Detailed report/debug evidence can still include score rows under non-public fields if needed.

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

Later implementation-slice validation should add:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_turn_transcript_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_state_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_glassroad_defense_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

## Failure Conditions

The later implementation should fail the report if any of these are true:

- The payload does not print exactly one `AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT` line.
- A transcript record lacks an explicit derived/report-only source marker.
- Any code writes `commander_role_state`, bumps `SAVE_VERSION`, creates a durable event log, edits production JSON, or changes live enemy-turn behavior.
- Before/after derived role proposals cannot be linked to the relevant commander roster entries or active encounters.
- A relevant commander has no target assignment record and no recognized no-op reason.
- Movement or arrival summaries contradict the before/after active raid snapshots.
- Arrival summary claims a controller flip, site contest, battle queue, or pillage effect that did not happen in existing turn execution.
- Town-governor references expose build/recruit score tables in public transcript events.
- Public transcript leak checks fail.
- River Pass or Glassroad fixtures require coefficient tuning, production JSON edits, pathing/body-tile/approach adoption, schema writes, or durable state to pass.

## Exact Implementation Sequence

Recommended future implementation sequence:

1. Add `tests/ai_commander_role_turn_transcript_report.gd` and `.tscn` as focused report coverage.
2. Add fixture setup helpers in the test scene only for River Pass and Glassroad session preparation.
3. Add pure snapshot helpers in `EnemyAdventureRules.gd` for active raids, commander roster links, resource controllers, target signatures, and compact event refs.
4. Add a report-only transcript assembly helper in `EnemyAdventureRules.gd` that accepts before session snapshot, after session snapshot, faction config, and the existing `run_enemy_turn(...)` result.
5. Add before/after derived role proposal builders that reuse the existing commander-role state report helpers and mark every proposal `state_policy: "report_only"`.
6. Add target assignment and recognized no-op derivation from existing target fields and `ai_target_assigned` events.
7. Add raid movement and arrival summary derivation from before/after active raid snapshots.
8. Add town-governor supporting event reference extraction from existing compact town-governor events, without copying score tables into public transcript events.
9. Add compact public transcript event builders and a recursive public leak check for the expanded transcript vocabulary.
10. Run the focused Godot transcript report and the existing commander-role/site-control/Glassroad/town-governor reports.
11. Add an implementation report document recording output and caveats.
12. Run full validation, then commit locally if it passes. Do not push.

## Recommended Next Slice

Recommended next slice: `strategic-ai-commander-role-live-turn-transcript-report-implementation-10184`.

That slice should implement the report-only transcript exactly within this plan. It should still avoid schema writes, save migration, durable event logs, defense-specific durable state, coefficient tuning, production JSON edits, full AI hero tasks, live commander-role behavior, pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, `content/resources.json`, wood id change, rare resources, market-cap changes, and River Pass rebalance.

If the implementation discovers that a useful transcript cannot be derived from before/after snapshots and existing event/report helpers, the correct fallback is a gate review or full AI hero task-state planning slice, not schema adoption or coefficient tuning.
