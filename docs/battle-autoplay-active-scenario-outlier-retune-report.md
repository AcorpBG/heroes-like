# Battle Autoplay Active Scenario Outlier Retune Report

Slice: `battle-autoplay-active-scenario-outlier-retune-20260524-10184`

Status: implementation evidence.

This slice uses the full active-scenario breadth queue as a bounded authored-content retune pass. It adjusts army-group counts for a first batch of terminal-margin outliers surfaced by `BATTLE_AUTOPLAY_ACTIVE_SCENARIO_BREADTH_REPORT`; it does not alter runtime combat formulas, AI rules, or the report-only tuning queue.

Retuned authored groups:
- `army_barrow_pickets`
- `army_lantern_battery`
- `army_relay_pickets`
- `army_halo_reserve`
- `army_bellwake_privateers`
- `army_charter_bastion_reserve`
- `army_nightglass_dominion`
- `army_orevein_exactors`

Targeted active-scenario placements included:
- `barrow_pickets`
- `ninefold_bellwake_privateers`
- `glassfen_relay_pickets`
- `charter_beacon_wardens`
- `prismhearth_halo_reserve`
- `daybreak_drum_circle`
- `surge_charter_guard`
- `ninefold_orevein_exactors`

Before retune evidence:
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
- balance_tuning_queue.item_count: `54`
- balance_tuning_queue.high_priority_count: `28`
- balance_tuning_queue.queue_signature: `e4d8c04a`

First pass evidence:
- balance_tuning_queue.item_count: `43`
- balance_tuning_queue.high_priority_count: `18`
- balance_tuning_queue.queue_signature: `b4a2ed49`

Current focused evidence:
- active_scenario_count: `16`
- expected_encounter_count: `51`
- sample_count: `51`
- completed_sample_count: `51`
- stalled_sample_count: `0`
- invalid_order_count: `0`
- missing_scenario_ids: `[]`
- average_terminal_health_margin_pct: `61`
- average_total_damage_per_round: `49`
- combat_feel_gate_status: `pass`
- balance_matrix_gate_status: `warning`
- runtime_consequence_gate_status: `pass`
- runtime_consequence_matrix_gate_status: `warning`
- balance_tuning_queue.status: `action_required`
- balance_tuning_queue.item_count: `40`
- balance_tuning_queue.high_priority_count: `14`
- balance_tuning_queue.medium_priority_count: `26`
- balance_tuning_queue.queue_signature: `04bf99d5`

Remaining top contributors after this bounded pass:
- `daybreak_drum_circle` / `encounter_drum_circle`: defeat, terminal_margin_pct `100`
- `surge_charter_guard` / `encounter_charter_guard`: defeat, terminal_margin_pct `96`
- `ninefold_orevein_exactors` / `encounter_orevein_exactors`: victory, terminal_margin_pct `100`
- `glassfen_aurora_battery` / `encounter_aurora_battery`: defeat, terminal_margin_pct `100`
- `daybreak_array` / `encounter_daybreak_array`: defeat, terminal_margin_pct `94`

Result:
- The active breadth report still covers all 16 active authored scenarios and all 51 current authored encounter placements.
- The retune reduces queue pressure from 54 to 40 total items and from 28 to 14 high-priority items.
- The no-stall, no-invalid-order, and missing-scenario coverage checks remain clear.
- The queue remains `action_required`; this is not final combat balance.

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
