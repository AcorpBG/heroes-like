# Strategic AI Hero Intercept Risk Gating Report

Status: implementation evidence.

Slice: `strategic-ai-hero-intercept-risk-gating-10184`.

This slice prevents hero-hunt execution from turning every in-range player hero target into an immediate field battle. `EnemyTurnRules._hero_intercept_ready_report` now compares the hunter host against the target hero's army and desired raid strength before creating a `hero_intercept` battle payload. The concrete readiness helper is `_hero_intercept_ready_report`. Weak hunters preserve commander continuity by regrouping or shadowing instead of throwing themselves into a bad fight.

Implemented behavior:
- Strong hero-hunt hosts still queue `hero_intercept` and complete the matching active hero task.
- Weak hero-hunt hosts at intercept range do not start `session.battle`.
- `EnemyAdventureRules.redirect_hero_intercept_for_risk` retasks weak hunters to a reachable same-faction regroup town when one exists; the public retask helper is `redirect_hero_intercept_for_risk`.
- If no regroup town is available, the hunter shadows the target with `hero_hunt_risk_shadow` and a one-day `hero_intercept_delay_until_day`.
- Public events continue through `ai_target_assigned` with player-readable "stalking stronger hero" language and no internal score/task leakage.

Focused evidence:
- `AI_HERO_TASK_HERO_HUNT_REPORT` still proves `hero_hunt_assigns_reuses_follows_and_closes_task`.
- The same report now proves `weak_hero_hunt_regroups_before_intercept`.
- Existing town-assault risk, raid regroup, and commander spawn reports remain in the validation set so the new gate does not break the broader strategic AI turn flow.

Validation commands:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_hero_task_hero_hunt_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_town_retake_assault_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_raid_regroup_retreat_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_hero_task_spawn_commander_selection_report.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```

Boundaries:
- No save migration.
- No battle-result tuning.
- No new dashboard/report treadmill.
- No full strategic AI quality claim.
