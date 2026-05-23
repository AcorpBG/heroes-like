# Battle Autoplay Combat Balance Calibration Report

Date: 2026-05-23

## Status

Implementation evidence. This slice uses the deterministic battle autoplay sampler to make a bounded combat-feel balance pass instead of only reporting the prior terminal-margin warning. It changes tactical autoplay scoring for no-attack melee repositioning and retunes the sampled early authored encounter army groups. This is a first calibration pass for the standard sampler, not final combat balance approval.

## What Changed

- `BattleAiRules` now considers `advance` when a stack has no attack available even after abstract distance has closed, so melee stacks can reposition on the hex board instead of repeatedly defending.
- Melee stacks at range with no attack receive a stronger advance score, especially under hostile ranged pressure.
- The shared battle autoplay sampler preserves authored difficulty labels in `difficulty_distribution` instead of collapsing them to `0`.
- Early sampled authored armies were retuned:
  - light `Blackbranch Raiders` gained a small reinforcement so Ghoul Grove is no longer almost untouched by the starter army;
  - medium `Mireclaw Pack` and `Reedward Pickets` were reduced so starter battles are not extreme wipeouts;
  - high `Blackfen Gateward` was reduced while remaining the hardest sampled gate fight.
- `tests/battle_autoplay_combat_balance_report.tscn` now gates the standard sampler on average terminal health margin and rejects lingering `high_terminal_health_margin` warnings.

## Validation Evidence

Focused command:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_combat_balance_report.tscn
```

Observed calibrated summary:

- `average_terminal_health_margin_pct`: `55`
- `combat_feel_gate.status`: `pass`
- `combat_feel_gate.warnings`: `[]`
- `distribution`: `{"defeat": 3, "victory": 3}`
- `difficulty_distribution`: `{"high": 1, "low": 1, "medium": 4}`
- `pacing_band_distribution`: `{"standard": 6}`
- `primary_action_id`: `strike`
- `action_diversity_count`: `4`

## Boundaries

This is a focused balance calibration over the current default deterministic sampler. Remaining combat work includes larger sample breadth, spell/autocast balance, stack-size curves by scenario phase, terrain-value passes, manual playtest feel, and broader faction-vs-faction tuning.
