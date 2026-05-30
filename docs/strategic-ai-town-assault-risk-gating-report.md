# Strategic AI Town Assault Risk Gating Report

Status: implementation evidence.

Slice: `strategic-ai-town-assault-risk-gating-10184`.

This slice moves town-assault execution away from unconditional battle queueing. `EnemyTurnRules._town_assault_ready_report` now compares an arriving AI raid host against desired raid strength, target garrison strength, and `OverworldRules.town_battle_readiness(...)` before creating a `town_defense` battle payload. The concrete readiness helper is `_town_assault_ready_report`.

Implemented behavior:
- Strong retake hosts still queue `town_defense` through the existing Duskfen Bastion retake flow.
- Weak hosts at battle range do not start `session.battle`.
- `EnemyAdventureRules.redirect_town_assault_for_risk` retasks weak hosts to a reachable same-faction regroup town when one exists; the public retask helper is `redirect_town_assault_for_risk`.
- If no regroup town is available, the host stages briefly on the current town assault target with `assault_risk_staging` and a one-day `assault_delay_until_day`.
- Public events continue through `ai_target_assigned` with player-readable "staging stronger assault" language and no internal score/task leakage.

Focused evidence:
- `AI_TOWN_RETAKE_ASSAULT_REPORT` still proves `river_pass_retake_front_queues_town_defense_battle`.
- The same report now proves `weak_retake_front_stages_before_town_battle`.
- Existing raid regroup and assault grouping reports remain in the validation set so the new readiness gate does not break commander consolidation or retreat behavior.

Validation commands:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_town_retake_assault_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_raid_assault_grouping_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_raid_regroup_retreat_report.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```

Boundaries:
- No save migration.
- No battle-result tuning.
- No new strategic AI dashboard or broad report treadmill.
- No full strategic AI quality claim.
