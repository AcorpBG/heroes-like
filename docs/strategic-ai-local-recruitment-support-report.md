# Strategic AI Local Recruitment Support Report

Status: implementation evidence.

Slice: `strategic-ai-local-recruitment-support-10184`.

This slice changes live enemy recruitment support behavior. Enemy town governors no longer choose active raid reinforcement targets only from global abstract raid need. The recruiting town now supplies its own location to raid reinforcement scoring, unreachable hosts are skipped for direct support, and reachable nearby hosts receive locality value before troops are committed.

Implemented behavior:
- `EnemyAdventureRules.raid_reinforcement_route_distance(...)` measures pathing distance from the recruiting town to an active raid host.
- `EnemyTurnRules._best_raid_reinforcement_target(...)` accepts the recruiting town, rejects unreachable raid hosts, applies locality scoring, and keeps support distance in debug payloads.
- Town recruitment destination reports expose `supply_distance` for validation, while public AI events remain compact and score-table internals stay hidden.
- The focused Duskfen town-governor fixture now seeds a nearby and a farther competing raid and proves Duskfen supports the nearby raid first.

Boundaries:
- No save migration.
- No new strategic-AI production-ready claim.
- No convoy actor system yet; this is direct town-to-host support becoming route/locality aware.
- No broad generated-map seed matrix in this slice.

Validation:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_town_governor_pressure_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_multi_scenario_recruitment_delivery_report.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
