# Strategic AI Resource Site Defense Report

Status: implementation evidence.

This slice closes a narrow strategic AI gap: persistent resource sites controlled by an enemy faction could become invalid/no-op targets for that same faction, so a raid could seize an economy site but not deliberately hold it when the player threatened it.

Implemented behavior:
- `EnemyAdventureRules` recognizes `site_defense`, `defend_front`, and `front_stabilization` as resource-defense reason codes.
- Owned persistent resource sites under explicit front pressure or nearby player threat can retask active raids through `_redirect_raid_to_threatened_resource_defense`.
- Resource target validation now keeps same-faction persistent sites valid only for defense-coded orders.
- Arriving at a defended persistent site records `ai_defended_by_faction_id`, `ai_defended_day`, `ai_defense_until_day`, and `ai_defense_rating` on the resource node.
- Defense arrivals emit public `ai_site_defended` activity with the public reason `defending held site`.
- The shared headless harness requires `strategic_ai_live_resource_site_defense`.

Validation target:
- `live_raid_defends_owned_persistent_resource_site`
- Scenario: `river-pass`
- Faction: `faction_mireclaw`
- Defended site: `river_free_company`
- Abandoned offensive target: `river_signal_post`
- Required public event evidence: `ai_target_assigned`, `ai_site_defended`
- Required state evidence: `ai_defended_by_faction_id = faction_mireclaw`

Boundaries:
- No save migration.
- No persistent hero task board.
- No full strategic AI quality claim.
- No broad economy retuning.
