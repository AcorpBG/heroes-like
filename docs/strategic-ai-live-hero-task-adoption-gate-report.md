# Strategic AI Live Hero Task Adoption Gate Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `strategic-ai-live-hero-task-adoption-10184`.

## Purpose

Implement the final P2.8 live hero task adoption gate after the hero task-state boundary, normalizer preservation, public event boundary, economy pressure follow-up, and commander-role adoption boundary work.

This gate does not adopt live hero task behavior. It records why live behavior, schema writes, save migration, durable event history, and executable task state remain deferred.

## Implementation

- Added `EnemyAdventureRules.ai_hero_task_live_adoption_gate_report(...)`.
- Added `EnemyAdventureRules.ai_hero_task_live_adoption_gate_public_leak_check(...)`.
- Added focused Godot coverage in `tests/ai_hero_task_live_adoption_gate_report.gd` and `.tscn`.

The helper consumes the prior report shapes:

- `AI_HERO_TASK_STATE_BOUNDARY_REPORT`
- `AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT`
- `AI_COMMANDER_ROLE_ADOPTION_BOUNDARY_REPORT`

## Gate Result

Report-only ready:

- candidate task reports;
- optional task normalizer preservation;
- commander-role boundary evidence.

Deferred:

- task schema writer;
- save migration;
- live target selection;
- route and actor execution;
- save/resume proof for executable tasks;
- manual live-client pacing review;
- durable event history.

`SessionStateStore.SAVE_VERSION` remains `9`. No save migration was performed. `wood` remains canonical.

## Boundary

The report prints one `AI_HERO_TASK_LIVE_ADOPTION_GATE_REPORT` payload with:

- `schema_status: "live_hero_task_adoption_gate_report_only"`
- `behavior_policy: "no_live_hero_task_behavior_adoption"`
- `save_policy: "no_hero_task_state_write_no_save_migration"`
- `event_log_policy: "no_durable_event_log"`

Public gate events are compact report surfaces and are checked for raw score/debug/internal field leaks. They omit task ids, source ids, score tables, route details, body tiles, approach data, task-state schema internals, and save-version fields.

## Validation

Focused report:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_hero_task_live_adoption_gate_report.tscn
```

Relevant boundary reports:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_hero_task_state_boundary_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_hero_task_state_normalizer_preservation_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_adoption_boundary_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_public_event_log_boundary_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
```

Expected result: each report prints one payload with `ok: true`.

## Completion Decision

The final P2.8 child is completed as a bounded adoption gate/deferral proof. Strategic AI live hero task behavior remains behind later schema, route/actor execution, save/resume, and live-client review gates.
