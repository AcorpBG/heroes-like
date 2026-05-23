# Strategic AI Town Retake Assault Report

Status: implementation evidence.

Slice: `strategic-ai-live-town-retake-assault-harness-20260523-10184`.

This slice adds focused live evidence for the enemy town-retake path. A player-captured Duskfen Bastion retake front is seeded in River Pass, a no-target Mireclaw raid starts at battle range, and the normal enemy turn must assign Duskfen through strategic target selection and queue a real `town_defense` battle.

Implemented evidence:
- `AI_TOWN_RETAKE_ASSAULT_REPORT` proves `river_pass_retake_front_queues_town_defense_battle`.
- The fixture validates `EnemyAdventureRules.choose_target(...)` prefers `duskfen_bastion` for the retake front.
- The fixture also validates `EnemyAdventureRules.ai_live_town_retake_target_selection_plan(...)` prefers `duskfen_bastion` before commander resource-target adoption, so a live commander raid cannot ignore an active town-retake front to raid a nearby site.
- `EnemyTurnRules.run_enemy_turn(...)` assigns the no-target raid to the town, advances/refreshes it into battle range, and queues `session.battle`.
- The battle context is `town_defense` with `town_placement_id = duskfen_bastion`.
- Public events include `ai_target_assigned` and pass the public AI event boundary without task, score, or reservation leaks.

Boundaries:
- No save migration.
- No durable `hero_task_state`.
- No automatic battle result tuning.
- No full strategic AI quality claim.
