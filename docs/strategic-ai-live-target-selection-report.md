# Strategic AI Live Target Selection Report

Status: implementation evidence.

This slice adopts the first bounded live hero-task behavior surface: new enemy raids can use derived commander candidate tasks to choose resource-front targets before falling back to the existing global target selector, then persist those assignments into the normalized strategic hero task board.

Implemented behavior:
- `EnemyAdventureRules.assign_target(...)` now asks `ai_hero_task_live_target_selection_plan(...)` for a commander target plan when a raid has no valid target.
- The live plan is limited to resource-front task classes `retake_site`, `contest_site`, and `defend_front`.
- Existing active raid targets and persisted active task reservations are treated as reservations, so a companion commander does not duplicate the same exclusive resource target.
- Route movement beyond existing raid movement, public UI task surfacing, and save migrations remain out of scope.

Validation evidence:
- `AI_HERO_TASK_LIVE_TARGET_SELECTION_REPORT`
- `river_pass_vaska_live_task_targets_free_company`: the existing global selector chooses `town:riverwatch_hold`, while the live commander task selector chooses `resource:river_free_company`.
- `river_pass_sable_respects_free_company_reservation`: with Vaska already assigned to `river_free_company`, Sable selects `river_signal_post`.
- `SAVE_VERSION` remains unchanged and `hero_task_state_live_persist_no_save_migration` proves assignment persistence without a save migration.

Remaining deferred surfaces:
- route actor execution beyond existing raid movement;
- public UI task surfacing;
- broader strategic AI target classes beyond this resource-front adoption.
