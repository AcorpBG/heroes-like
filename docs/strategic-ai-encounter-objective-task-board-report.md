# Strategic AI Encounter Objective Task Board Report

Status: implementation evidence.

This slice makes objective-front encounter targets participate in the live strategic AI hero task board instead of remaining transient raid target metadata.

Follow-up implementation slice `strategic-ai-encounter-arrival-risk-gating-10184` closes the next live behavior hole: an AI raid can no longer auto-clear or contest a guarded encounter objective just because it reached the staging tile.

## Implemented Behavior

- `target_kind: encounter` is accepted by task-state normalization.
- Live encounter target assignments can write normalized `enemy_states[].hero_task_state`.
- Saved-task target selection can reconstruct encounter plans from the current encounter placement and staging tiles.
- Encounter tasks reconcile against current placement state: missing encounters invalidate, externally resolved encounters invalidate, and already-contested-by-faction encounters complete.
- Encounter arrival resolution completes the active task when the AI contests or clears the encounter.
- Encounter arrival now runs a guard-strength readiness check before clearing or contesting the objective.
- Weak encounter-objective hosts keep the saved task active and retask with `encounter_risk_regroup` when a same-faction regroup town is reachable, or `encounter_risk_staging` when they must wait for support at the front.

## Focused Evidence

`AI_HERO_TASK_ENCOUNTER_OBJECTIVE_REPORT` proves `objective_front_encounters_use_saved_task_continuity_and_arrival_risk_gating`:

- Causeway Stand's `causeway_levee_cutters` objective-front encounter assignment persists as an active `encounter` task.
- `EnemyTurnRules.normalize_enemy_states(...)` preserves the encounter task.
- `EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(...)` reuses the saved encounter task and emits `saved_hero_task`.
- A missing encounter task invalidates with `invalid_target_missing`.
- A strong host resolves the encounter through live `advance_raids(...)`, completes the active task, and preserves the completed task through normalization.
- `weak_encounter_objective_regroups_before_clear` proves a host above the generic regroup floor but below the guarded objective requirement does not resolve `causeway_levee_cutters`, keeps the task active, emits public-safe retask evidence, and records `encounter_risk_regroup`.

No save migration is introduced; `SAVE_VERSION` remains unchanged and the save policy is `hero_task_state_live_persist_no_save_migration`.
