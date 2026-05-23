# Strategic AI Raid Assault Grouping Report

Status: implementation evidence.

Slice: `strategic-ai-live-raid-assault-grouping-20260523-10184`.

This slice adds focused live evidence for nearby raid-host consolidation before a town assault. A player-captured Duskfen Bastion retake front is seeded in River Pass, a commander-led Mireclaw assault host and an adjacent support column are both assigned to the town, and the normal enemy turn must fold the support column into the assault host before the town-defense battle is queued.

Implemented evidence:
- `AI_RAID_ASSAULT_GROUPING_REPORT` proves `river_pass_nearby_raids_group_for_town_assault`.
- `EnemyAdventureRules.group_nearby_raids_for_town_assault(...)` consolidates adjacent same-faction support raids only when both hosts are assigned to the same player-held town.
- The support host is recorded in `resolved_encounters`, the leader receives the donor stacks, and commander army continuity is refreshed to the grouped strength.
- Public events include `ai_raid_grouped` and pass the public AI event boundary without task, score, reservation, or grouped-internal leaks.
- The grouped assault continues through the normal enemy turn into a `town_defense` battle for `duskfen_bastion`.

Boundaries:
- No save migration.
- No durable `hero_task_state`.
- No multi-commander army board.
- No automatic battle result tuning.
- No full strategic AI quality claim.
