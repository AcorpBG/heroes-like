# Strategic AI Commander Assault Consolidation Report

Status: implementation evidence.

Slice: `strategic-ai-commander-assault-consolidation-10184`.

This slice improves real strategic AI multi-army behavior for town assaults. Previously, `group_nearby_raids_for_town_assault(...)` could absorb adjacent commanderless support columns, but two named commanders assigned to the same player-held town could stay as disconnected attackers. The AI can now consolidate a nearby commander-led support host into the lead town assault when that support host is not the stronger commander army.

Implemented behavior:
- Adjacent same-faction raids assigned to the same player-held town remain eligible for grouping.
- Commanderless support grouping still works as before.
- Commander-led support grouping is allowed only when the leader also has a commander and the donor army is not stronger than the lead army.
- The donor stacks are transferred into the leader's `enemy_army`, and the leader commander continuity is refreshed.
- The donor raid is marked resolved and emits through the existing public `ai_raid_grouped` surface.
- The donor commander is not deleted. Its roster entry is released to `available`, clears `active_placement_id`, keeps base army continuity, has `current_strength: 0`, and is therefore non-deployable until rebuilt by the existing recruitment/rebuild path.
- A matching active live town task for the donor commander is completed when the donor host consolidates into the lead assault.

Focused evidence:
- `AI_RAID_ASSAULT_GROUPING_REPORT` still proves `river_pass_nearby_raids_group_for_town_assault` for commanderless support columns.
- The same report now proves `river_pass_commander_raids_group_for_town_assault`: Vaska absorbs Sable's adjacent assault host against `duskfen_bastion`, Sable's support raid is resolved, Sable's town task completes, and Sable stays on the commander roster as an available but non-deployable rebuild target.

Boundaries:
- No save migration.
- No multi-commander battle payload. The consolidated assault is still one lead commander with a larger army.
- No full strategic AI quality claim.
