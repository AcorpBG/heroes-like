# Battle Autoplay Active Watch Cohort Retune Report

Slice: `battle-autoplay-active-watch-cohort-retune-20260524-10184`

Status: implementation evidence.

This slice continues active-scenario combat tuning after the default 12-sample queue was cleared. It uses placement-local authored `enemy_army` overrides to reduce remaining medium-priority active breadth watch contributors without changing shared unit stats, shared encounter definitions, shared army groups, or combat rules.

Retuned placements:
- `prismhearth_halo_reserve`
- `daybreak_array`
- `daybreak_drum_circle`
- `glassfen_relay_pickets`
- `glassfen_glasswing_sortie`
- `bridge_silt_hunters`

Guarded attempt reverted:
- `ninefold_orevein_exactors` was tested with a lighter placement-local army to split the rough-terrain outcome cohort, but the result crossed a cliff into a `96-97` terminal-margin player win. The override was removed and the placement returned to the shared non-outlier baseline.

Starting active-breadth evidence:
- active_scenario_count: `16`
- expected_encounter_count: `51`
- sample_count: `51`
- completed_sample_count: `51`
- stalled_sample_count: `0`
- invalid_order_count: `0`
- missing_scenario_ids: `[]`
- combat_feel_gate_status: `pass`
- balance_matrix_gate_status: `pass`
- runtime_consequence_gate_status: `pass`
- runtime_consequence_matrix_gate_status: `warning`
- balance_tuning_queue.status: `watch`
- balance_tuning_queue.item_count: `16`
- balance_tuning_queue.high_priority_count: `0`
- balance_tuning_queue.medium_priority_count: `16`
- balance_tuning_queue.queue_signature: `d8a427ba`

Current active-breadth evidence:
- active_scenario_count: `16`
- expected_encounter_count: `51`
- sample_count: `51`
- completed_sample_count: `51`
- stalled_sample_count: `0`
- invalid_order_count: `0`
- missing_scenario_ids: `[]`
- average_terminal_health_margin_pct: `51`
- average_total_damage_per_round: `47`
- combat_feel_gate_status: `pass`
- balance_matrix_gate_status: `pass`
- runtime_consequence_gate_status: `pass`
- runtime_consequence_matrix_gate_status: `warning`
- balance_tuning_queue.status: `watch`
- balance_tuning_queue.item_count: `7`
- balance_tuning_queue.high_priority_count: `0`
- balance_tuning_queue.medium_priority_count: `7`
- balance_tuning_queue.queue_signature: `0d5a4b3b`

Focused default queue evidence:
- sample_count: `12`
- combat_feel_gate_status: `pass`
- balance_matrix_gate_status: `pass`
- balance_tuning_queue.status: `clear`
- balance_tuning_queue.item_count: `0`
- balance_tuning_queue.high_priority_count: `0`
- balance_tuning_queue.medium_priority_count: `0`
- balance_tuning_queue.queue_signature: `829808c9`

Representative retuned sample rows:
- `prismhearth_halo_reserve`: player `defeat`, terminal margin `50`, pacing `extended`.
- `daybreak_array`: player `defeat`, terminal margin `69`, pacing `standard`.
- `daybreak_drum_circle`: player `victory`, terminal margin `37`, pacing `standard`.
- `glassfen_relay_pickets`: player `victory`, terminal margin `58`, pacing `extended`.
- `glassfen_glasswing_sortie`: player `defeat`, terminal margin `42`, pacing `standard`.
- `bridge_silt_hunters`: player `victory`, terminal margin `37`, pacing `standard`.

Remaining active-breadth watch contributors:
- `rough` terrain cohort: primary_outcome_pct `100`
- `mireford-skirmish` scenario cohort: primary_outcome_pct `100`
- `ironbridge-stand` scenario cohort: primary_outcome_pct `100`
- `glassroad_archive_wardens` sample: terminal_health_margin_pct `80`
- `ninefold_prism_matrix` sample: terminal_health_margin_pct `77`

Result:
- Active breadth queue pressure dropped from `16` to `7` items.
- High-priority active breadth items remain at `0`.
- The active breadth balance matrix gate remains `pass`.
- The default 12-sample battle tuning queue remains `clear`.
- Remaining items are medium-priority watch evidence; this is not final combat balance.

Boundaries:
- No automatic tuning.
- No runtime balance mutation.
- No shared unit-stat changes.
- No combat model rewrite.
- No new scenario or campaign breadth.
- No final combat balance approval.

Validation:
```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 --scene res://tests/battle_autoplay_active_scenario_breadth_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/battle_autoplay_balance_tuning_queue_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/battle_autoplay_combat_balance_report.tscn
python3 tools/run_headless_balance_harness.py --suite standard --keep-going
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py tools/run_headless_balance_harness.py
jq empty ops/progress.json content/scenarios.json
git diff --check
```
