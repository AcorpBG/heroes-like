# Strategic AI Spawn Commander Selection Report

Status: implementation evidence.

This slice makes durable strategic AI task state affect live commander deployment. Raid spawning now prefers an available, deployable commander with a reachable saved strategic task before falling back to the existing roster rotation.

Follow-up slice `strategic-ai-target-aware-spawn-point-selection-10184` extends the same live deployment path so multi-spawn factions choose the open spawn point that best serves saved commander tasks or fresh strategic targets instead of blindly using config order.

Implemented behavior:
- `EnemyTurnRules._spawn_raid` now calls saved-task-aware commander selection before building the raid commander state.
- `EnemyAdventureRules.select_raid_commander_roster_hero_id_for_spawn` keeps the existing availability, occupancy, and roster-rotation fallback rules.
- Deployable commanders with reachable saved tasks are preferred over the rotation pick.
- Still-recovering or rebuilding commanders do not become spawn candidates even when they have saved tasks.
- The selected raid still flows through normal target assignment, saved-task reuse, event surfacing, and task-board persistence.
- When multiple spawn points are open, `EnemyTurnRules._spawn_raid` now scores each point by saved-task reachability first, then live strategic target priority and distance, while preserving the selected saved-task commander.

Validation evidence:
- `AI_HERO_TASK_SPAWN_COMMANDER_SELECTION_REPORT`
- `saved_tasks_influence_live_commander_deployment`
- `spawn_prefers_tarn_saved_task_over_sable_rotation`
- `recovering_saved_task_actor_does_not_override_rotation`
- `spawn_point_prefers_saved_task_reachable_origin_over_first_open`
- The fixture proves a saved-task commander deploys ahead of the normal rotation, reuses the saved target, persists an active task, and keeps unavailable saved-task actors out of deployment.
- The follow-up fixture proves River Pass no longer deploys from the first open spawn point when the second open point is closer to the saved Free Company objective.

Boundaries:
- No save migration.
- No full strategic AI production-readiness claim.
- This slice does not add multi-hero army grouping, retreat policy, or long-run generated-map AI quality gates.
