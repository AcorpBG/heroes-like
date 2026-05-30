# Strategic AI Hero Task Lifecycle Reconciliation Report

Status: implementation evidence.

This slice hardens the persistent strategic AI hero task board from a write-only surface into behavior state that is reconciled before reuse. Saved tasks are now checked against current map ownership and target existence before they can steer a raid.

Implemented behavior:
- `EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(...)` reads task-board state after lifecycle reconciliation.
- Open resource tasks whose target is already controlled by the faction are marked `completed`.
- Open resource tasks whose target is missing are marked `invalid` with `invalid_target_missing`.
- Open non-persistent resource tasks already consumed by another controller are marked `invalid_target_resolved`.
- Open town attack/retake tasks whose target town is already held by the faction are marked `completed`.
- Expired planned/reserved/active tasks are marked `cancelled` with `invalid_task_expired`.
- Completed, cancelled, and invalid tasks are not reused as saved target plans or exclusive reservations.

Validation evidence:
- `AI_HERO_TASK_LIFECYCLE_RECONCILIATION_REPORT`
- `saved_tasks_reused_only_while_current_and_open`
- `river_pass_saved_tasks_reconcile_before_reuse`
- The fixture proves one valid saved task is reused with `saved_hero_task`, while already-owned resource/town tasks complete, a missing resource task invalidates, and an expired task cancels.
- The normalized task board preserves `invalid_task_expired` and `invalid_target_missing` through `EnemyTurnRules.normalize_enemy_states(...)`.

Boundaries:
- No save migration.
- No claim of full strategic AI production readiness.
- This slice does not tune target scoring, army grouping quality, diplomacy, retreat policy, or generated-map long-run AI performance.
