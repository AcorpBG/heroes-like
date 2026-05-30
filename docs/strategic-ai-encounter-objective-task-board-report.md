# Strategic AI Encounter Objective Task Board Report

Status: implementation evidence.

This slice makes objective-front encounter targets participate in the live strategic AI hero task board instead of remaining transient raid target metadata.

## Implemented Behavior

- `target_kind: encounter` is accepted by task-state normalization.
- Live encounter target assignments can write normalized `enemy_states[].hero_task_state`.
- Saved-task target selection can reconstruct encounter plans from the current encounter placement and staging tiles.
- Encounter tasks reconcile against current placement state: missing encounters invalidate, externally resolved encounters invalidate, and already-contested-by-faction encounters complete.
- Encounter arrival resolution completes the active task when the AI contests or clears the encounter.

## Focused Evidence

`AI_HERO_TASK_ENCOUNTER_OBJECTIVE_REPORT` proves `objective_front_encounters_use_saved_task_continuity`:

- Causeway Stand's `causeway_levee_cutters` objective-front encounter assignment persists as an active `encounter` task.
- `EnemyTurnRules.normalize_enemy_states(...)` preserves the encounter task.
- `EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(...)` reuses the saved encounter task and emits `saved_hero_task`.
- A missing encounter task invalidates with `invalid_target_missing`.
- Resolving the encounter completes the active task and preserves the completed task through normalization.

No save migration is introduced; `SAVE_VERSION` remains unchanged and the save policy is `hero_task_state_live_persist_no_save_migration`.
