# Battle Autoplay Active Scenario Breadth Report

Slice: `battle-autoplay-active-scenario-breadth-harness-20260524-10184`

Status: implementation evidence.

This slice adds a report-only active-content breadth gate for deterministic combat-feel sampling. The previous default combat balance reports intentionally sampled 12 authored encounters across four scenarios. This report derives every active authored campaign/skirmish scenario from `content/scenarios.json`, counts all active authored encounter placements, and runs `BattleAutoplayBalanceHarnessRules.build_sampling_report(...)` with that full scenario set.

Current focused evidence:
- report id: `BATTLE_AUTOPLAY_ACTIVE_SCENARIO_BREADTH_REPORT`
- schema: `battle_autoplay_active_scenario_breadth_report_v1`
- policy: `report_only_active_scenario_combat_breadth_probe`
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

Coverage:
- `river-pass`, `causeway-stand`, `fen-crown`, `stonewake-watch`
- `reedbarrow-ferry`, `nightglass-redoubt`, `bogbound-oath`, `charter-pyre`
- `lockmarsh-surge`, `ironbridge-stand`, `prismhearth-watch`, `glassroad-sundering`
- `daybreak-spire`, `glassfen-breakers`, `mireford-skirmish`, `ninefold-confluence`

The broader tuning queue is intentionally allowed to surface action-required items. That is the point of this slice: the four-scenario default gate can remain clear while the full active scenario set still exposes balance work, including terminal-margin outliers and cohort outcome-bias watches. The report keeps this as evidence for future retuning passes instead of writing content or changing runtime balance.

Boundaries:
- No automatic tuning.
- No runtime balance changes.
- No authored content writeback.
- No manual-play replacement.
- No final combat balance approval.

Validation:
```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 --scene res://tests/battle_autoplay_active_scenario_breadth_report.tscn
python3 tools/run_headless_balance_harness.py --suite standard --keep-going
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py tools/run_headless_balance_harness.py
jq empty ops/progress.json
git diff --check
```
