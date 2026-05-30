# Strategic AI Task Retask Cancellation Report

Status: implementation evidence.

This slice makes live strategic AI retasks explicit in the durable hero task board. When a commander is redirected to a different objective, the previous open task is preserved as `cancelled` with `last_validation: cancelled_by_retask` and `invalidated_by_task_id` pointing at the replacement task.

Implemented behavior:
- Same-actor task upserts no longer silently drop an open previous task when the actor changes objective.
- A genuinely different replacement objective cancels the old task and appends the new active task.
- Reassigning the same actor to the same task target/class still refreshes the active task without false cancellation.
- Town-defense retasks are persisted as `defend_front`, not generic `raid_town`, so lifecycle reconciliation treats them as owned-front defense.
- The optional task-state normalizer accepts `cancelled_by_retask` as a live validation code.
- Public AI events still hide task ids, retask internals, and score/debug fields.

Validation evidence:
- `AI_HERO_TASK_RETASK_CANCELLATION_REPORT`
- `retasked_commanders_cancel_previous_open_task`
- `town_defense_retask_cancels_previous_resource_task`
- The fixture proves a live Duskfen town-defense retask cancels Vaska's previous Free Company resource task, creates the new active defense task, links the old task to the replacement task id, and survives enemy-state normalization.

Boundaries:
- No save migration.
- No full strategic AI production-readiness claim.
- This slice does not tune defensive scoring, add new objectives, or change route movement.
