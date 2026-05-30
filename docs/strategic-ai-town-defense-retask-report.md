# Strategic AI Town Defense Retask Report

Status: implementation evidence.

Slice: `strategic-ai-town-defense-retask-20260523-10184`.

This slice adds a live defensive retask path for active enemy raid hosts. When a same-faction enemy town is on a stabilizing front and the player is threatening that area, a non-understrength raid can retask away from opportunistic resource pressure and move to defend the town.

The focused fixture uses Duskfen Bastion in River Pass as the threatened stabilizing town.

Follow-up slice: `strategic-ai-multi-scenario-town-defense-retask-20260524-10184`.

Later follow-up: `strategic-ai-town-defense-arrival-10184` makes arrival at that defended town produce live garrison/commander consequences instead of stopping at retarget metadata.

Current follow-up: `strategic-ai-defense-overcommit-control-10184` keeps useful pressure commanders from piling onto town or resource defense fronts that are already covered by current garrison plus committed defenders.

The shared headless simulation harness now broadens that proof through `strategic_ai_multi_scenario_town_defense_retask` and `live_enemy_town_defense_retask_across_scenario_breadth`. It runs the normal enemy end-turn cycle across `river-pass`, `prismhearth-watch`, `glassroad-sundering`, `glassfen-breakers`, and `ninefold-confluence`, covering 9 enemy faction cases.

Implemented behavior:
- `EnemyAdventureRules.advance_raids(...)` now checks `_redirect_raid_to_threatened_town_defense(...)` after understrength regroup logic and before normal target assignment.
- Understrength regroup remains higher priority than town defense.
- Defensive retasks use `target_kind = "town"` with `town_defense` and `front_stabilization` reason codes.
- Defensive town targets remain valid when the town is enemy-owned, belongs to the same faction, and the raid target carries the explicit `town_defense` reason code.
- The public activity surface emits `ai_target_assigned` with `defending threatened town` and no hero task board, score, or reservation data.
- Multi-scenario coverage requires every seeded active raid to preserve its previous resource target metadata, retask to a same-faction owned stabilizing town, expose `town_defense` and `front_stabilization`, leave the abandoned resource target uncaptured for that turn, and keep public event logs free of internal tokens.
- Town faction checks now honor `controlling_faction_id` for enemy-owned occupied towns, so occupied controller bases such as `halo_spire` can defend under their actual enemy faction instead of their template faction.
- Resource-site defense retasks no longer overwrite an already selected `town_defense` raid target in the same turn.
- Town-defense candidate selection now subtracts current garrison strength and other active same-faction town-defense commitments before retasking another commander.
- Resource-site defense candidate selection now subtracts active same-faction site-defense commitments before retasking another commander.
- Covered town and resource fronts leave active pressure targets untouched instead of rewriting their previous-target metadata.

Validation evidence:
- `AI_TOWN_DEFENSE_RETASK_REPORT`
- `river_pass_active_raid_defends_stabilizing_duskfen`
- `duskfen_bastion`
- `river_free_company`
- `town_defense`
- `front_stabilization`
- `ai_target_assigned`
- `strategic_ai_multi_scenario_town_defense_retask`
- `live_enemy_town_defense_retask_across_scenario_breadth`
- `scenario_count = 5`
- `faction_case_count = 9`
- `retasked_faction_count = 9`
- `target_assignment_event_count = 13`
- `covered_town_defense_does_not_retask_second_commander`
- `covered_resource_defense_does_not_retask_second_commander`
- `no_hero_task_state_write_no_save_migration`
- `save_version_before`
- `save_version_after`

Boundaries:
- No durable commander task board.
- No save migration.
- No broad strategic AI quality claim.
- This proves one live defense retask fixture, not complete recruiting, grouping, retreat, objective, or difficulty tuning.
