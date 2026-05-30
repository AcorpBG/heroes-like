# Strategic AI Baseline KPI Report

Slice: `strategic-ai-quality-pass-10184`

Status: implementation evidence.

This slice adds a focused strategic AI baseline audit before deeper behavior tuning. The report does not change AI decisions, tune content, or claim production readiness. It turns the existing headless strategic AI evidence into capability KPIs and adds Native RMG generated-map turn probes so the next implementation slice can target the largest real gaps instead of adding isolated gates.

Implemented behavior:
- `HeadlessSimulationHarnessRules.build_strategic_ai_baseline_kpi_report(...)` builds `strategic_ai_baseline_kpi_report_v1`.
- The report reuses the existing headless strategic AI subsystems for town economy, recruitment delivery, hero tasking, routes, defense, regrouping, assault grouping, pressure, and objective targeting.
- The report emits capability rows for `town_economy`, `hero_tasking_and_routes`, `defense_regroup_and_assault`, and `objective_pressure`.
- The report records Native RMG generated-map turn-health coverage rows for two supported Small land cases plus one Medium generalization case; the default fast audit marks them as required coverage gaps, with full execution available through the report input config.
- The report records production blockers instead of hiding them: no durable full hero task board, no completed full 100-seed eight-week long-run matrix, and any generated-map generalization gaps.
- The report recommends the next implementation slices from observed blocker rows.

Focused evidence:
- `STRATEGIC_AI_BASELINE_KPI_REPORT`
- `strategic_ai_baseline_kpi_report_v1`
- `production_ready = false`
- `covered_subsystem_count` matches the current strategic AI subsystem list.
- Supported Small generated-map AI turn-health coverage is explicitly tracked instead of inferred from authored fixtures.
- Medium generated-map coverage is measured as a production generalization gap until it is broadly green.
- The audit policy keeps manual-play replacement, automatic tuning, runtime balance changes, authored content writeback, campaign adoption, and production-ready claims disabled.

Validation:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 --scene res://tests/strategic_ai_baseline_kpi_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 --scene res://tests/headless_simulation_harness_report.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```

Remaining gaps:
- This is an audit and KPI layer, not a strategic AI quality completion claim.
- AI still needs a persistent full hero task board, broader generated-map seed coverage, longer multi-week simulations, and production difficulty/personality tuning.
- Campaign-specific AI scripting remains deferred.
