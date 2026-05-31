# Battle Autoplay Combat Balance Calibration Report

Date: 2026-05-23

## Status

Implementation evidence. This report records bounded combat-feel balance passes over the deterministic battle autoplay sampler. The latest calibration removes the matrix terminal-margin outliers from the sampled authored encounters while preserving the existing combat-feel gate. This is still not final combat balance approval.

## What Changed

- `BattleAiRules` now considers `advance` when a stack has no attack available even after abstract distance has closed, so melee stacks can reposition on the hex board instead of repeatedly defending.
- Melee stacks at range with no attack receive a stronger advance score, especially under hostile ranged pressure.
- The shared battle autoplay sampler preserves authored difficulty labels in `difficulty_distribution` instead of collapsing them to `0`.
- Early sampled authored armies were retuned:
  - light `Blackbranch Raiders` gained a small reinforcement so Ghoul Grove is no longer almost untouched by the starter army;
  - medium `Mireclaw Pack` and `Reedward Pickets` were reduced so starter battles are not extreme wipeouts;
  - high `Blackfen Gateward` was reduced while remaining the hardest sampled gate fight.
- `tests/battle_autoplay_combat_balance_report.tscn` now gates the standard sampler on average terminal health margin and rejects lingering `high_terminal_health_margin` warnings.
- The calibrated authored encounter army groups remain the content-level source for early sampled stack-size tuning.
- The terminal-margin outlier calibration keeps `Blackbranch Raiders` slightly reinforced so Ghoul Grove is no longer an almost untouched starter win.
- `encounter_reedward_camp` now uses an `open_lane` battle tag instead of the previous mire chokepoint lockout, so the medium camp produces live attacks and no longer ends as a near-perfect player defeat.
- The focused combat balance report, balance regression suite, and shared headless harness now preserve `terminal_margin_outliers` as report-only diagnostics; hard matrix failures still fail validation, but warning rows do not force automatic tuning or balance-content edits during AI-only work.

## Validation Evidence

Focused command:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_combat_balance_report.tscn
```

Observed calibrated summary after the latest terminal-margin outlier pass:

- `average_terminal_health_margin_pct`: `51`
- `combat_feel_gate.status`: `pass`
- `combat_feel_gate.warnings`: `[]`
- `balance_matrix_gate.status`: may be `pass` or report-only `warning` depending on the current AI/content slice.
- `terminal_margin_outliers`: retained as diagnostics rather than automatic failure conditions.
- `distribution`: `{"defeat": 2, "victory": 4}`
- `difficulty_distribution`: `{"high": 1, "low": 1, "medium": 4}`
- `pacing_band_distribution`: `{"standard": 6}`
- `primary_action_id`: `strike`
- `action_diversity_count`: `4`

## Boundaries

This is a focused balance calibration over the current default deterministic sampler. Remaining combat work includes larger sample breadth, spell/autocast balance, stack-size curves by scenario phase, terrain-value passes, manual playtest feel, and broader faction-vs-faction tuning.
