# Strategic AI Hero Task Actor Lifecycle Report

Status: implementation evidence.

This slice hardens saved strategic AI tasks against commander roster state. A task is no longer enough by itself to reserve a target or steer a raid: the owning commander must still exist and be deployable.

Implemented behavior:
- Before saved task reuse, `EnemyAdventureRules` reconciles `commander_roster` actors.
- Missing commander actors are marked `invalid` with `invalid_actor_missing`.
- Recovering commanders are marked `suspended` with `invalid_actor_recovering`.
- Rebuilding commanders that cannot deploy are marked `suspended` with `invalid_actor_rebuilding`.
- Available or active deployable commanders keep valid current tasks.
- Suspended/invalid tasks do not count as active exclusive reservations and are not reused as saved target plans.

Validation evidence:
- `AI_HERO_TASK_ACTOR_LIFECYCLE_REPORT`
- `saved_tasks_require_live_deployable_commander_actors`
- `river_pass_saved_tasks_require_deployable_commander_actor`
- The fixture proves one deployable actor keeps and reuses its saved task, one recovering actor suspends, one rebuilding actor suspends, and one missing actor invalidates.
- The suspended/invalid actor states survive `EnemyTurnRules.normalize_enemy_states(...)`.

Boundaries:
- No save migration.
- No full strategic AI production-readiness claim.
- This slice does not tune target scoring, army strength policy, threat response depth, or long-run generated-map AI performance.
