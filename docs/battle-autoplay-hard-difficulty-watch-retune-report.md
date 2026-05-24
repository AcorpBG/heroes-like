# Battle Autoplay Hard Difficulty Watch Retune Report

Slice: `battle-autoplay-hard-difficulty-watch-retune-20260524-10184`

Status: implementation evidence.

This slice reduces the current hard-difficulty row from the latest `battle_autoplay_difficulty_sweep_v1` watch baseline without weakening the normal queue or changing runtime difficulty rules.

Before this pass:
- Normal row: `tuning_queue_status = clear`, `tuning_queue_item_count = 0`, `tuning_queue_signature = 829808c9`.
- Hard row: `tuning_queue_status = watch`, `tuning_queue_item_count = 6`, `tuning_queue_signature = f3f8507f`.
- Hard contributors included `forest`, `causeway-stand`, `low`, `formation_guard`, `stonewake-watch`, and `river_pass_ghoul_grove`.

Implemented retune:
- `content/scenarios.json` strengthens the River Pass Ghoul Grove placement-local watch by raising `unit_blackbranch_cutthroat` from 11 to 13 and `unit_mire_slinger` from 6 to 7.
- `content/army_groups.json` softens `army_blackfen_gateward` from 4/5/5 to 3/4/5 across Bog Brute, Mire Slinger, and Blackbranch Cutthroat.
- `content/army_groups.json` softens `army_willow_mill_pack` from 10/9 to 8/8 across Bog Brute and Mire Slinger.
- `tests/battle_autoplay_difficulty_sweep_report.gd` now requires `MAX_NORMAL_TUNING_QUEUE_ITEMS := 0` and `MAX_HARD_TUNING_QUEUE_ITEMS := 3`.

Focused evidence:
- `BATTLE_AUTOPLAY_DIFFICULTY_SWEEP_REPORT`
- `sweep_signature = 4361f7f7`
- Normal row remains clear: `tuning_queue_item_count = 0`, `tuning_queue_signature = 829808c9`.
- Hard row improves to `tuning_queue_item_count = 3`, `tuning_queue_signature = c286b819`.
- Hard row queue categories are reduced to `cohort_outcome_bias_watch`.
- Hard terminal-margin/sample watches are clear.
- Normal-vs-hard remains observable: enemy remaining health delta `20`, player remaining health delta `-11`, terminal margin delta `9`, total damage per round delta `2`, and `no_observed_effect = false`.

Boundaries:
- No automatic tuning or authored content writeback.
- No runtime balance mutation.
- No broad unit-stat rewrite.
- No final combat balance approval.
