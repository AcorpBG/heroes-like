# Battle Autoplay Difficulty Sweep Balance Harness Report

Slice: `battle-difficulty-sweep-balance-harness-20260523-10184`

This slice extends the existing deterministic battle autoplay balance harness with `battle_autoplay_difficulty_sweep_v1`. The sweep runs the authored encounter sample set separately for normal and hard launch difficulties, then emits per-difficulty rows plus a `normal_vs_hard` delta summary.

The report checks that each sampled battle preserves `launch_difficulty_distribution`, completes without stalled samples or invalid orders, and exposes difficulty-effect evidence through terminal margin, damage pacing, remaining health, and outcome deltas. The sweep remains report-only: it gives combat-feel and balance work better evidence before content scaling, but it does not tune content automatically.

Validation entry point:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_autoplay_difficulty_sweep_report.tscn
```

Current evidence after `battle-autoplay-hard-difficulty-watch-retune-20260524-10184`:

- Normal: 12/12 completed samples, `average_terminal_health_margin_pct: 44`, `average_total_damage_per_round: 41`, primary outcome `defeat` at 50%, and `tuning_queue_item_count: 0`.
- Hard: 12/12 completed samples, `average_terminal_health_margin_pct: 53`, `average_total_damage_per_round: 43`, primary outcome `defeat` at 75%, and `tuning_queue_item_count: 3`.
- `normal_vs_hard`: enemy remaining health +20, player remaining health -11, terminal margin +9, total damage per round +2.

No automatic tuning or content writeback.

No final combat balance approval.
