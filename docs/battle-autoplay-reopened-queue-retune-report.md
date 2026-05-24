# Battle Autoplay Reopened Queue Retune Report

Slice: `battle-autoplay-reopened-queue-retune-20260524-10184`

Status: implementation evidence.

This slice clears the reopened default battle autoplay tuning queue and reduces the active-scenario Basalt Gatehouse outlier with placement-local authored army overrides. The change does not alter combat rules, unit stats, shared army groups, or runtime tuning policy.

Retuned placements:
- `river_pass_ghoul_grove`
- `fen_crown_bone_ferry_watch`
- `ninefold_basalt_gatehouse_watch`

Starting queue evidence:
- Default tuning queue status: `watch`
- Default tuning queue item_count: `4`
- Default tuning queue high_priority_count: `0`
- Default tuning queue medium_priority_count: `4`
- Default tuning queue signature: `d5cdd331`
- Active-scenario breadth queue status: `action_required`
- Active-scenario breadth high_priority_count: `2`
- Active high-priority contributor: `ninefold_basalt_gatehouse_watch`

Placement-local tuning result:
- `river_pass_ghoul_grove` now uses `army_river_pass_ghoul_grove_watch` at the placement. Current focused sample: player `victory`, terminal margin `61`, pacing `standard`, enemy power `1506`, player power `1390`.
- `fen_crown_bone_ferry_watch` now uses `army_fen_crown_bone_ferry_watch` at the placement. Current focused sample: player `defeat`, terminal margin `66`, pacing `standard`, enemy power `1042`, player power `1390`.
- `ninefold_basalt_gatehouse_watch` now uses `army_ninefold_basalt_gatehouse_watch` at the placement. Current active breadth result removes the prior high-priority Basalt Gatehouse contributor.

Focused default queue evidence:
- sample_count: `12`
- combat_feel_gate_status: `pass`
- balance_matrix_gate_status: `pass`
- balance_tuning_queue.status: `clear`
- balance_tuning_queue.item_count: `0`
- balance_tuning_queue.high_priority_count: `0`
- balance_tuning_queue.medium_priority_count: `0`
- balance_tuning_queue.queue_signature: `829808c9`

Active-scenario breadth evidence:
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

Remaining active breadth watch contributors:
- `prismhearth-watch` scenario cohort: average_terminal_health_margin_pct `70`
- `daybreak-spire` scenario cohort: average_terminal_health_margin_pct `72`
- `glassfen-breakers` scenario cohort: average_terminal_health_margin_pct `75`
- `rough` terrain cohort: primary_outcome_pct `100`
- `mireford-skirmish` scenario cohort: primary_outcome_pct `100`

Result:
- The default 12-sample battle tuning queue is clear.
- The active breadth high-priority count is back to `0`.
- The active breadth report still covers all 16 active authored scenarios and all 51 current authored encounter placements with no stalled samples, no invalid orders, and no missing scenario ids.
- Remaining active breadth items are medium-priority watch items; this remains report-only balance backlog, not final combat balance.

Boundaries:
- No automatic tuning.
- No runtime balance mutation.
- No combat model rewrite.
- No shared unit-stat changes.
- No new scenario or campaign breadth.
- No final combat balance approval.

Validation:
```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/battle_autoplay_balance_tuning_queue_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/battle_autoplay_combat_balance_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 --scene res://tests/battle_autoplay_active_scenario_breadth_report.tscn
python3 tools/run_headless_balance_harness.py --suite standard --keep-going
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py tools/run_headless_balance_harness.py
jq empty ops/progress.json content/scenarios.json
git diff --check
```
