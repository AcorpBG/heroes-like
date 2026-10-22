// Phase 4's shared ports reach these, which Phase 5's slice 09 ports (its claims in the
// shared-helper note): each throws state::NotPorted until then. Slice 09 deletes this file.

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

namespace aurelion::rules::port {

namespace artifact_rules {

DictRef _select_rarity_source_reward(State &state, Atom source_tag, Atom rarity, Atom source_key, ArrayRef excluded_artifact_ids) {
	(void)source_tag; (void)rarity; (void)source_key; (void)excluded_artifact_ids; (void)state;
	throw state::NotPorted("ArtifactRules._select_rarity_source_reward");
}

} // namespace artifact_rules

namespace enemy_adventure_rules {

ArrayRef _ai_hero_task_prune_live_tasks(State &state, ArrayRef tasks, int64_t day) {
	(void)tasks; (void)day; (void)state;
	throw state::NotPorted("EnemyAdventureRules._ai_hero_task_prune_live_tasks");
}

} // namespace enemy_adventure_rules

namespace overworld_rules {

Atom _normalized_enemy_front_faction_id(State &state, DictRef session, DictRef front, DictRef town) {
	(void)session; (void)front; (void)town; (void)state;
	throw state::NotPorted("OverworldRules._normalized_enemy_front_faction_id");
}

void _teach_visiting_town_spells(State &state, DictRef session, DictRef town) {
	(void)session; (void)town; (void)state;
	throw state::NotPorted("OverworldRules._teach_visiting_town_spells");
}

int64_t _town_occupation_seed_pressure(State &state, DictRef session, DictRef town) {
	(void)session; (void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_occupation_seed_pressure");
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
