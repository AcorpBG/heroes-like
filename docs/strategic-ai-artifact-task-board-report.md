# Strategic AI Artifact Task Board Report

Status: implementation evidence.

This slice makes artifact and relic targets participate in the live strategic AI hero task board instead of staying transient raid metadata.

## Implemented Behavior

- `target_kind: artifact` is accepted by task-state normalization.
- Live artifact target assignments can write normalized `enemy_states[].hero_task_state`.
- Saved-task target selection can reconstruct artifact plans from current artifact placements.
- Artifact tasks reconcile against current placement state: missing relics invalidate, externally collected relics invalidate, and relics already collected by the faction complete.
- Artifact pickup resolution completes the active matching task when the AI secures the relic.
- Artifact pickup now also routes through the later `strategic-ai-artifact-equipment-10184` slice, so the active commander claims/equips the secured relic and persists the equipment state.

## Focused Evidence

`AI_HERO_TASK_ARTIFACT_OBJECTIVE_REPORT` proves `artifact_targets_use_saved_task_continuity`:

- River Pass's priority `warcrest_ruin` relic assignment persists as an active `artifact` task.
- `EnemyTurnRules.normalize_enemy_states(...)` preserves the artifact task.
- `EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(...)` reuses the saved artifact task and emits `saved_hero_task`.
- A missing relic task invalidates with `invalid_target_missing`.
- A relic collected by another side invalidates with `invalid_target_resolved`.
- Securing the relic completes the active task and preserves the completed task through normalization.
- Securing Warcrest Pennon equips `artifact_warcrest_pennon` in Vaska's banner slot and exposes live `battle_attack` / `battle_initiative` artifact bonuses.

No save migration is introduced; `SAVE_VERSION` remains unchanged and the save policy is `hero_task_state_live_persist_no_save_migration`.
