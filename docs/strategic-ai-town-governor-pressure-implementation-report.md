# Strategic AI Town Governor Pressure Implementation Report

Status: completed implementation.
Date: 2026-04-26.
Slice: `strategic-ai-town-governor-pressure-report-implementation-10184`.

## Scope

This slice implements behavior-neutral report/debug surfacing for existing enemy town governor choices.

It does not change chosen builds, recruitment destinations, raid launch thresholds, target scoring, resource economy, pathing, saves, production JSON, renderer/editor behavior, neutral encounter metadata, generated assets, or River Pass balance.

## Delivered

- Added `EnemyTurnRules.town_governor_pressure_report(...)` for focused enemy town governor inspection.
- Added town build candidate reports with the selected build, compact public reason, and debug-only component values: income, growth, quality, readiness, pressure, recovery, market, category, garrison need, raid need, cost, affordability, and final score.
- Refactored the existing build chooser to read its final score from the same breakdown helper, preserving the existing decision path while making the score explainable.
- Added recruitment destination breakdowns for the existing destination chooser: garrison safety, active raid reinforcement, and commander rebuild.
- Added compact derived event helpers for `ai_town_built`, `ai_town_recruited`, `ai_garrison_reinforced`, `ai_raid_reinforced`, and `ai_commander_rebuilt`, reusing the existing compact AI event contract.
- Added focused Godot report coverage in `tests/ai_town_governor_pressure_report.gd` and `.tscn`.

## River Pass Coverage

The focused report uses River Pass Duskfen / Mireclaw as the first example.

The report proves:

- Duskfen selects `building_slingers_post` with compact public reason `feeds raid hosts`.
- The build report includes detailed debug components without moving those fields into public events.
- A low-garrison case routes recruitment to garrison reinforcement with public reason `stabilizes garrison`.
- An active-raid case routes recruitment to raid reinforcement with public reason `feeds raid hosts`.
- A shattered-commander case routes recruitment to commander rebuild with public reason `rebuilds command`.
- Public derived events do not expose score-table fields such as `final_score`, `income_value`, `growth_value`, `pressure_value`, `category_bonus`, or `raid_score`.

Focused report command:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

Result: passed. The command printed `AI_TOWN_GOVERNOR_PRESSURE_REPORT` with `"ok": true`.

## Follow-Up

Next slice: `strategic-ai-town-governor-pressure-report-gate-10184`.

The gate should rerun and review the focused report, confirm the public event leak checks stay clean, decide whether the report-only boundary passes, and decide whether any live-client enemy-turn gate is needed before faction personality or commander-role planning.
