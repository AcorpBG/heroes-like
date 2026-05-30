# Strategic AI Hero Task Resumption Report

Status: implementation evidence.

This slice makes suspended strategic AI hero tasks recoverable. A commander returning from recovery or rebuild can resume a saved objective instead of leaving the task board with permanently dead suspended work.

Implemented behavior:
- `EnemyAdventureRules` now reconciles `suspended` tasks as well as planned/reserved/active tasks.
- If the owning commander exists and is deployable, a suspended task is reactivated to `planned` with `last_validation: valid`.
- Reactivated tasks still run through expiration and target lifecycle checks before they can be reused.
- Expired resumed tasks cancel with `invalid_task_expired`.
- Resumed tasks whose target is already owned by the faction complete instead of being reused.
- Valid resumed tasks can drive saved target selection and get the `saved_hero_task` reason code.

Validation evidence:
- `AI_HERO_TASK_RESUMPTION_REPORT`
- `suspended_saved_tasks_reactivate_before_target_reuse`
- `river_pass_suspended_tasks_resume_for_deployable_commanders`
- The fixture proves one suspended deployable commander's task reactivates and is reused, one stale resumed task cancels, and one already-owned resumed task completes.

Boundaries:
- No save migration.
- No full strategic AI production-readiness claim.
- This slice does not yet make raid spawning prefer available commanders with planned saved tasks.
