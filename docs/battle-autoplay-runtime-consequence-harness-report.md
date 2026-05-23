# Battle Autoplay Runtime Consequence Harness Report

Slice: `battle-autoplay-runtime-consequence-harness-20260523-10184`

## Purpose

The deterministic battle autoplay sampler already records initial ability presence and combat-feel outcomes. This slice extends that evidence into runtime consequences so balance work can see whether sampled authored battles actually exercise ability and status systems during play.

## What Changed

- `BattleAutoplayBalanceHarnessRules.run_battle_sample(...)` now emits a per-sample `battle_autoplay_runtime_consequence_profile_v1`.
- The shared sample summary now emits `runtime_consequence_distribution` with `battle_autoplay_runtime_consequence_distribution_v1`.
- The summary also emits `runtime_consequence_gate` using `report_only_runtime_consequence_thresholds_v1`.
- `tests/battle_autoplay_runtime_consequence_report.tscn` proves deterministic distribution signatures, status application events, ability-driven runtime consequences, ability source evidence, and per-sample profile signatures.
- Existing combat balance and balance regression reports now assert the runtime consequence gate alongside the combat-feel and balance-matrix gates.

## Current Evidence

- `runtime_consequence_gate.status`: `pass`
- `distribution_signature`: `a537a308`
- `sample_count`: `12`
- `samples_with_status_consequence_count`: `12`
- `samples_with_ability_consequence_count`: `10`
- `samples_with_spell_consequence_count`: `12`
- `total_status_application_event_count`: `55`
- `total_ability_effect_observation_count`: `118`
- `total_spell_effect_observation_count`: `117`
- `observed_source_types`: `ability`, `spell`
- `observed_effect_ids`: `status_harried`, `status_staggered`, `spell:spell_bloodwake_drum:attack_buff`, `spell:spell_stone_veil:defense_buff`

## Boundaries

- No automatic tuning or content writeback.
- No final combat balance approval.
- No new spell or unit ability content.
- No broad encounter roster retune.

## Verification

Run:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_runtime_consequence_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_combat_balance_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/balance_regression_report_suite.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
