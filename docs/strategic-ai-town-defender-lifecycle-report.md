# Strategic AI Town Defender Lifecycle Report

Status: implementation evidence.

Slice: `strategic-ai-town-defender-lifecycle-10184`.
Related follow-up slice: `strategic-ai-town-defender-rotation-10184`.

This slice makes stationed town defenders part of the live enemy commander lifecycle instead of leaving them as town metadata that roster normalization can ignore.

Implemented behavior:
- `EnemyAdventureRules.normalize_all_commander_rosters(...)` now normalizes town defender commander state before roster status is rebuilt.
- `_active_commander_map(...)` includes valid town defenders as active commander assignments using `town_defense:<town_id>`.
- Valid town defenders require enemy town ownership, matching controlling faction, an active `defend` or `stabilizing` town front, and a current `ai_defense_until_day` or front `defense_until_day`.
- Expired, invalid, or strategically cleared town defender assignments clear `ai_defender_commander_state`, `ai_defender_roster_hero_id`, `ai_defended_by_faction_id`, and active defense metadata.
- Commander selection skips stationed defenders while the town-defense assignment is active, then allows them back into deployment once the defense window expires or the defended front is cleared.

Focused evidence:
- `AI_TOWN_DEFENSE_RETASK_REPORT`
- `stationed_commander_status = active`
- `stationed_active_placement_id = town_defense:duskfen_bastion`
- `replacement_selection_while_stationed = hero_sable`
- `released_commander_status = available`
- `defender_metadata_cleared_after_expiry = true`
- `stationed_town_defender_releases_when_front_clears`
- `defender_metadata_cleared = true`

Boundaries:
- No save migration.
- No broad strategic-AI production-ready claim.
- This is still not a full defender rotation doctrine for all fronts; it closes the stale-stationed-commander case for cleared town fronts.
