# Strategic AI Hero Hunt Task Board Report

Task: #10184
Slice: `strategic-ai-hero-hunt-task-board-10184`
Follow-up slice: `strategic-ai-hero-intercept-risk-gating-10184`
Follow-up slice: `strategic-ai-hero-hunt-support-grouping-10184`

## Purpose

Make exposed player-hero hunt targets durable strategic AI tasks instead of transient raid choices.

## Implementation evidence

- Live hero target assignments can write normalized `enemy_states[].hero_task_state`.
- `EnemyTurnRules.normalize_optional_hero_task_state(...)` accepts `target_kind: "hero"`.
- `EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(...)` rebuilds saved hero-hunt plans from the current player hero position, so a moving target is followed instead of replaying stale coordinates.
- Missing player-hero targets invalidate through task lifecycle reconciliation.
- Queued hero-intercept battles complete the matching active hero-hunt task.
- Hero hunt target candidates now carry public reason codes for exposed hero pressure.
- Hero-intercept execution now uses a live readiness gate before queueing `hero_intercept`: weak hunters retask to regroup or shadow with `hero_hunt_risk_regroup` / `hero_hunt_risk_shadow` instead of completing the hunt task through a suicide battle.
- The follow-up report case `weak_hero_hunt_regroups_before_intercept` proves an underpowered Vaska hunt host reaches Lyra's tile but does not start `session.battle`, while a reinforced hunt host still queues and closes `hero_intercept`.
- Exposed-hero hunt fronts now participate in active-front support selection and nearby raid grouping. A support commander can choose the live hero-hunt front, preserve `hero_hunt` / `exposed_hero` reason metadata, and merge into the lead hunter before the intercept decision.
- The follow-up report case `hero_hunt_support_groups_before_intercept` proves Sable selects Vaska's exposed-hero front through `active_front_support`, the normal raid advance emits `ai_raid_grouped`, Sable's support host is resolved, and the donor hero-hunt task is completed without a save migration.

Focused runtime report:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 60 --scene res://tests/ai_hero_task_hero_hunt_report.tscn
```

Expected report id: `AI_HERO_TASK_HERO_HUNT_REPORT`.

## Save policy

No save migration is introduced. Existing saves without `hero_task_state` still mean no saved tasks. The slice uses the existing `hero_task_state_live_persist_no_save_migration` policy and does not change `SessionStateStore.SAVE_VERSION`.

## Residual risk

This closes hero-hunt task-board continuity, intercept risk gating, and same-front support grouping for exposed player heroes. It does not claim full release-ready strategic AI: long-run generated-map quality, retreat judgment, broader objective planning, adventure spell planning, and live-client pacing still need production passes.
