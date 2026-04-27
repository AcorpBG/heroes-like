# Strategic AI Event Surfacing Implementation Report

Status: completed implementation.
Date: 2026-04-26.
Slice: `strategic-ai-event-surfacing-implementation-10184`.

## Scope

This slice implements compact strategic AI event and threat reason surfacing from existing `EnemyAdventureRules` / `EnemyTurnRules` paths.

It does not add a saved AI event log, save migration, production JSON migration, `content/resources.json`, wood id change, rare-resource activation, market-cap overhaul, pathing/body-tile/approach adoption, renderer/editor behavior changes, generated PNG import, neutral encounter migration, full AI hero task state, broad strategic AI rewrite, or River Pass rebalance.

## Delivered

- Added reusable strategic AI event helpers for target assignment, pressure summary, site seizure, and site contest records.
- Added compact target reason fields to town and resource candidates: reason codes, public reason, public importance, and debug reason.
- Kept full resource score breakdowns in `resource_pressure_report(...)` and focused report output only.
- Extended `advance_raids(...)` to return ephemeral `events` alongside existing one-line messages.
- Returned structured `ai_site_seized` records from resource-site seizure and `ai_site_contested` records from objective encounter contest.
- Added compact reason phrases to visible threat focus and local dispatch summaries without adding a new dashboard or text-heavy UI surface.
- Added `tests/ai_event_surfacing_report.gd` and `.tscn` as focused Godot report coverage.

## River Pass Coverage

The focused report proves compact records for:

- `river_free_company` target assignment with `persistent_income_denial`, `recruit_denial`, and `player_town_support`.
- `river_signal_post` target assignment with `persistent_income_denial`, `route_vision`, and `player_town_support`.
- `riverwatch_hold` pressure summary with `town_siege` and `objective_front`.
- `river_free_company` seizure messaging and structured `ai_site_seized`.
- `river_pass_ghoul_grove` objective-front contest as structured `ai_site_contested`.

The report also checks that public event records and threat/dispatch text do not leak full score table fields such as `final_priority`, `base_value`, or `assignment_penalty`.

## Validation

Focused report command:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
```

Result: passed. The command printed `AI_EVENT_SURFACING_REPORT` with `"ok": true`.

Existing economy pressure report was also rerun:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
```

Result: passed. The command printed `AI_ECONOMY_PRESSURE_REPORT` with `"ok": true`.

## Follow-Up

Next slice should be `strategic-ai-event-surfacing-report-gate-10184`:

- Rerun the focused report plus standard validators.
- Review whether public wording is compact enough for the live-client threat/dispatch surfaces.
- Decide whether a manual gate should inspect a real enemy turn around the signal-yard sites before broader strategic AI expansion.
