# Strategic AI Spawn Commander Selection Report

Status: implementation evidence.

This slice makes durable strategic AI task state affect live commander deployment. Raid spawning now prefers an available, deployable commander with a reachable saved strategic task before falling back to the existing roster rotation.

Implemented behavior:
- `EnemyTurnRules._spawn_raid` now calls saved-task-aware commander selection before building the raid commander state.
- `EnemyAdventureRules.select_raid_commander_roster_hero_id_for_spawn` keeps the existing availability, occupancy, and roster-rotation fallback rules.
- Deployable commanders with reachable saved tasks are preferred over the rotation pick.
- Still-recovering or rebuilding commanders do not become spawn candidates even when they have saved tasks.
- The selected raid still flows through normal target assignment, saved-task reuse, event surfacing, and task-board persistence.

Validation evidence:
- `AI_HERO_TASK_SPAWN_COMMANDER_SELECTION_REPORT`
- `saved_tasks_influence_live_commander_deployment`
- `spawn_prefers_tarn_saved_task_over_sable_rotation`
- `recovering_saved_task_actor_does_not_override_rotation`
- The fixture proves a saved-task commander deploys ahead of the normal rotation, reuses the saved target, persists an active task, and keeps unavailable saved-task actors out of deployment.

Boundaries:
- No save migration.
- No full strategic AI production-readiness claim.
- This slice does not add multi-hero army grouping, retreat policy, or long-run generated-map AI quality gates.
