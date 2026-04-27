# Strategic AI Public Event Log Boundary Report

Status: implemented.
Date: 2026-04-27.
Slice: `strategic-ai-public-event-log-boundary-10184`.

## Scope

This slice implements a derived, bounded public Strategic AI event log boundary for existing event records.

It does not add a durable event log, save migration, `SAVE_VERSION` bump, live hero task adoption, AI coefficient tuning, broad strategic AI behavior changes, production content migration, UI dashboard work, terrain/editor work, or economy/resource activation.

## Implementation

- Added `EnemyAdventureRules.ai_public_event_log(...)` to derive a bounded public event list from existing AI event records.
- Added `EnemyAdventureRules.ai_public_event_log_entry(...)` to strip debug/report-only fields such as event ids, sequence, coordinates, state policy, debug reasons, score refs, score breakdowns, priority tables, fixture data, save/migration markers, and other internal fields.
- Added `EnemyAdventureRules.ai_public_event_log_boundary_report(...)` and `ai_public_event_log_leak_check(...)` as report helpers.
- Routed `OverworldRules.describe_enemy_activity(...)` through the shared derived public-event helper instead of maintaining a separate compact event projection.
- Added `tests/ai_public_event_log_boundary_report.gd/.tscn`.

The selected policy is `derived_ephemeral_report_only`: public summaries are derived from existing turn/report events and existing durable facts, with no new stored event list.

## Evidence

Focused report:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_public_event_log_boundary_report.tscn
```

Result: passed. The report printed `AI_PUBLIC_EVENT_LOG_BOUNDARY_REPORT` with `"ok": true`.

The fixture proves:

- a polluted `ai_target_assigned` source event containing score/debug/report-only fields produces a public-safe assignment summary for `river_free_company`;
- `ai_pressure_summary` remains meaningful for `riverwatch_hold`;
- `ai_site_seized` remains meaningful for `river_free_company`;
- `hidden_debug` and `ai_target_scored` source events are filtered out of the public log;
- the public log is bounded by the requested limit;
- public events retain event type, target kind/id/label, public importance, summary, reason codes, and public reason;
- public events do not expose `debug_reason`, score fields, score refs, sequence ids, coordinates, fixture fields, durable/save/migration markers, or report-only breakdowns;
- `SessionStateStore.SAVE_VERSION` remains unchanged.

Compatibility report:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
```

Result: passed. Existing assignment, pressure, seizure, contest, threat, and dispatch surfacing evidence still works.
