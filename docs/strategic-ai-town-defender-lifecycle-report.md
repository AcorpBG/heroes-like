# Strategic AI Town Defender Lifecycle Report

Status: implementation evidence.

Slice: `strategic-ai-town-defender-lifecycle-10184`.

This slice makes stationed town defenders part of the live enemy commander lifecycle instead of leaving them as town metadata that roster normalization can ignore.

Implemented behavior:
- `EnemyAdventureRules.normalize_all_commander_rosters(...)` now normalizes town defender commander state before roster status is rebuilt.
- `_active_commander_map(...)` includes valid town defenders as active commander assignments using `town_defense:<town_id>`.
- Valid town defenders require enemy town ownership, matching controlling faction, and a current `ai_defense_until_day` or front `defense_until_day`.
- Expired or invalid town defender assignments clear `ai_defender_commander_state`, `ai_defender_roster_hero_id`, `ai_defended_by_faction_id`, and active defense metadata.
- Commander selection skips stationed defenders while the town-defense assignment is active, then allows them back into deployment once the defense window expires.

Focused evidence:
- `AI_TOWN_DEFENSE_RETASK_REPORT`
- `stationed_commander_status = active`
- `stationed_active_placement_id = town_defense:duskfen_bastion`
- `replacement_selection_while_stationed = hero_sable`
- `released_commander_status = available`
- `defender_metadata_cleared_after_expiry = true`

Boundaries:
- No save migration.
- No broad strategic-AI production-ready claim.
- No full defender rotation policy; this only proves active/release lifecycle for the existing town-defense arrival assignment.
