# Strategic AI Raid Regroup Retreat Report

Slice: `strategic-ai-raid-regroup-retreat-20260523-10184`
Follow-up slice: `strategic-ai-regroup-task-board-10184`

Status: implementation evidence.

## Scope

This slice adds one bounded strategic-AI behavior: understrength raids retreat to an owned matching-faction town, pull spare garrison units into the field host, and then resume normal targeting once the host reaches a usable strength floor.

This is not a full strategic AI quality claim.
No full strategic AI quality claim.

## Behavior

- `EnemyAdventureRules.raid_regroup_needed(...)` compares current raid strength against the desired raid strength and a minimum regroup floor.
- Active understrength raids retarget to the nearest reachable owned town for their faction with target kind `regroup`.
- Arrival at the regroup town transfers garrison stacks into the raid army until the strength gap is covered or the garrison is exhausted.
- Commander army continuity is synchronized after the transfer.
- If the host is no longer under the regroup floor, the regroup target is cleared so the next raid step can choose a fresh offensive or defensive objective.
- The behavior emits `ai_target_assigned` for the retreat order and `ai_raid_regrouped` for the garrison merge.
- Regroup orders now persist as durable strategic AI hero tasks with `target_kind: regroup` and `task_class: rebuild_host`.
- Saved regroup tasks can rebuild a reachable town-regroup plan from the current owned same-faction town state and carry the `saved_hero_task` reason.
- Missing regroup towns invalidate with `invalid_target_missing`; towns no longer owned by the matching AI faction invalidate with `invalid_controller_changed`.
- A successful regroup that rebuilds the host enough to resume completes the matching active task before the raid target is cleared.
- `EnemyTurnRules.normalize_enemy_states(...)` preserves `target_kind: regroup` task records without a save-version migration.

## Focused Fixture

`tests/ai_raid_regroup_retreat_report.tscn` uses River Pass with a damaged Mireclaw Vaska raid initially aimed at the player-controlled Free Company Camp. The raid starts understrength, chooses Duskfen Bastion instead of the original resource objective, folds the town's `unit_bog_brute` garrison into the host, records `last_regroup_town_id`, completes the durable regroup task, and leaves the original resource under player control. The same fixture also proves saved regroup-task reuse, missing-town invalidation, wrong-controller invalidation, and normalization preservation.

## Validation

Focused command:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_raid_regroup_retreat_report.tscn
```

Repository gates:

```sh
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```

## Remaining Gap

This closes a narrow retreat/regroup failure mode. Broader strategic AI quality remains open: enemy economy planning, multi-hero grouping, town defense, retreat timing, objective sequencing, and difficulty tuning still need dedicated implementation and balance passes.
