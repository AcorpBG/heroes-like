# Strategic AI Hero Hunt Task Board Report

Task: #10184
Slice: `strategic-ai-hero-hunt-task-board-10184`

## Purpose

Make exposed player-hero hunt targets durable strategic AI tasks instead of transient raid choices.

## Implementation evidence

- Live hero target assignments can write normalized `enemy_states[].hero_task_state`.
- `EnemyTurnRules.normalize_optional_hero_task_state(...)` accepts `target_kind: "hero"`.
- `EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(...)` rebuilds saved hero-hunt plans from the current player hero position, so a moving target is followed instead of replaying stale coordinates.
- Missing player-hero targets invalidate through task lifecycle reconciliation.
- Queued hero-intercept battles complete the matching active hero-hunt task.
- Hero hunt target candidates now carry public reason codes for exposed hero pressure.

Focused runtime report:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 60 --scene res://tests/ai_hero_task_hero_hunt_report.tscn
```

Expected report id: `AI_HERO_TASK_HERO_HUNT_REPORT`.

## Save policy

No save migration is introduced. Existing saves without `hero_task_state` still mean no saved tasks. The slice uses the existing `hero_task_state_live_persist_no_save_migration` policy and does not change `SessionStateStore.SAVE_VERSION`.

## Residual risk

This closes hero-hunt task-board continuity. It does not claim full release-ready strategic AI: long-run generated-map quality, multi-army grouping, retreat judgment, broader objective planning, adventure spell planning, and live-client pacing still need production passes.
