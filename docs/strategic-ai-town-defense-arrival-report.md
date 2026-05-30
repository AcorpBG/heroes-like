# Strategic AI Town Defense Arrival Report

Status: implementation evidence.

Slice: `strategic-ai-town-defense-arrival-10184`.

This slice closes the live gap after town-defense retargeting. A raid that reaches an owned threatened town on `town_defense` orders now hardens the town instead of merely arriving with a defensive target label.

Implemented behavior:
- `EnemyAdventureRules._resolve_arrived_target(...)` now routes enemy-owned `town` targets with `town_defense` reason codes into `_defend_town_target(...)`.
- `_defend_town_target(...)` merges the arrived raid host into the town garrison, writes live front defense fields, marks the town as AI-defended, stores the commander as `ai_defender_commander_state`, completes the saved hero task, and emits `ai_town_defended`.
- The stationed commander is synced to the enemy commander roster as active on `town_defense:<town_id>` so the same commander cannot immediately be redeployed elsewhere.
- `BattleRules.create_town_assault_payload(...)` uses a stationed AI defender commander when present, so the strengthened town assault battle uses the actual defending commander instead of always falling back to the generic town captain.
- Town-assault survivor sync preserves or clears stationed defender metadata as the town remains enemy-owned or changes owner.
- Later follow-up `strategic-ai-town-defender-lifecycle-10184` makes the stationed defender count as an active roster assignment until the defense window expires or the town no longer qualifies.

Focused evidence:
- `AI_TOWN_DEFENSE_RETASK_REPORT`
- `river_pass_active_raid_defends_stabilizing_duskfen`
- `ai_town_defended`
- `garrison_strength_before`
- `garrison_strength_after`
- `stationed_commander_id`
- `town_assault_enemy_commander_id`
- `unit_bog_brute`
- `duskfen_bastion`

Boundaries:
- No save migration.
- No broad strategic-AI production-ready claim.
- No full defensive assignment release policy; this slice makes arrival produce real town-defense consequences and keeps the commander stationed until later battle/aftermath handling changes that state.
