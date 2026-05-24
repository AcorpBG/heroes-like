# Battle Autoplay Active Scenario Second Outlier Retune Report

Slice: `battle-autoplay-active-scenario-second-outlier-retune-20260524-10184`

Status: implementation evidence.

This slice continues the active-scenario breadth tuning work with a second bounded authored army-group retune. It targets the remaining high-priority terminal-margin contributors from the previous pass and keeps the balance harness report-only: no runtime combat formula changes, no automatic tuning, and no authored content writeback from the harness.

Retuned authored groups:
- `army_nightglass_dominion`
- `army_charter_bastion_reserve`
- `army_orevein_exactors`
- `army_aurora_battery`
- `army_daybreak_matrix`
- `army_ford_reavers`

Targeted active-scenario placements included:
- `daybreak_drum_circle`
- `surge_charter_guard`
- `ninefold_orevein_exactors`
- `glassfen_aurora_battery`
- `daybreak_array`
- `bridge_ford_reavers`

Starting evidence from the previous pass:
- active_scenario_count: `16`
- expected_encounter_count: `51`
- sample_count: `51`
- completed_sample_count: `51`
- stalled_sample_count: `0`
- invalid_order_count: `0`
- missing_scenario_ids: `[]`
- combat_feel_gate_status: `pass`
- balance_matrix_gate_status: `warning`
- runtime_consequence_gate_status: `pass`
- runtime_consequence_matrix_gate_status: `warning`
- balance_tuning_queue.status: `action_required`
- balance_tuning_queue.item_count: `40`
- balance_tuning_queue.high_priority_count: `14`
- balance_tuning_queue.queue_signature: `04bf99d5`

Intermediate evidence:
- balance_tuning_queue.status: `action_required`
- balance_tuning_queue.item_count: `28`
- balance_tuning_queue.high_priority_count: `4`
- balance_tuning_queue.queue_signature: `e0c17322`

Current focused evidence:
- active_scenario_count: `16`
- expected_encounter_count: `51`
- sample_count: `51`
- completed_sample_count: `51`
- stalled_sample_count: `0`
- invalid_order_count: `0`
- missing_scenario_ids: `[]`
- average_terminal_health_margin_pct: `55`
- average_total_damage_per_round: `47`
- combat_feel_gate_status: `pass`
- balance_matrix_gate_status: `pass`
- runtime_consequence_gate_status: `pass`
- runtime_consequence_matrix_gate_status: `warning`
- balance_tuning_queue.status: `watch`
- balance_tuning_queue.item_count: `23`
- balance_tuning_queue.high_priority_count: `0`
- balance_tuning_queue.medium_priority_count: `23`
- balance_tuning_queue.queue_signature: `f7818555`

Remaining watch contributors after this bounded pass:
- `daybreak-spire` scenario cohort: average_terminal_health_margin_pct `70`
- `player_disadvantaged` matchup cohort: average_terminal_health_margin_pct `83`
- `glassfen-breakers` scenario cohort: average_terminal_health_margin_pct `86`
- `road` terrain cohort: average_terminal_health_margin_pct `79`
- `rough` terrain cohort: primary_outcome_pct `100`

Result:
- The active breadth report still covers all 16 active authored scenarios and all 51 current authored encounter placements.
- The second retune reduces queue pressure from 40 to 23 total items and from 14 to 0 high-priority items.
- The active breadth balance matrix gate moves from `warning` to `pass`.
- The no-stall, no-invalid-order, and missing-scenario coverage checks remain clear.
- The queue remains `watch`; this is not final combat balance.

Boundaries:
- No automatic tuning.
- No authored content writeback.
- No runtime balance changes.
- No combat model rewrite.
- No final combat balance approval.

Validation:
```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 --scene res://tests/battle_autoplay_active_scenario_breadth_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/battle_autoplay_combat_balance_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 --scene res://tests/battle_autoplay_difficulty_sweep_report.tscn
python3 tools/run_headless_balance_harness.py --suite standard --keep-going
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py tools/run_headless_balance_harness.py
jq empty ops/progress.json
git diff --check
```
