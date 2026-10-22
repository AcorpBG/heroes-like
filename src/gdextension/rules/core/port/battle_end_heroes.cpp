// The battle ends' hero rules: whether the human has anything left, the human
// player's heroes after a battle (the leader's hand-over, a fallen hero removed,
// a troop kept from the garrison), an enemy commander's record, memory and
// roster entry after a battle, the hero task board's pruning, and an artifact
// drawn by rarity.

#include "aurelion_rules/port/battle_ends.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// d.get(key, {}): the field, or a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// {"ok": false, "message": message}.
DictRef failure(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

} // namespace

// Defined in player_elimination.cpp and enemy_states.cpp, declared in no header.
namespace player_elimination_rules {
int64_t towns_held(State &state, DictRef session, DictRef player);
int64_t heroes_held(State &state, DictRef session, DictRef player);
} // namespace player_elimination_rules

namespace enemy_adventure_rules {
ArrayRef normalize_commander_roster(State &state, DictRef session, Atom faction_id, const Value &roster_value);
DictRef build_roster_commander_state(State &state, Atom roster_hero_id, Atom faction_id, DictRef existing_state, const Value &record_source);
DictRef sync_commander_army_continuity(State &state, DictRef commander_state, const Value &army_source, Atom encounter_id);
DictRef commander_army_continuity(State &state, const Value &source);
DictRef _normalized_commander_record(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _normalized_commander_memory(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _apply_commander_memory_metadata(State &state, DictRef commander_state, const Value &memory_source);
} // namespace enemy_adventure_rules

// PlayerEliminationRules.

namespace player_elimination_rules {

bool human_has_nothing_left(State &state, DictRef session) {
	for (const Value &player : gd::field_items(state, session_view::overworld(state, session), str(key::players))) {
		if (gd::is_dict(player) && gd::bool_field(state, player.ref, key::human, false)) {
			return towns_held(state, session, player.ref) == 0 && heroes_held(state, session, player.ref) == 0;
		}
	}
	return false;
}

} // namespace player_elimination_rules

// HeroCommandRules.

namespace hero_command_rules {

bool active_hero_is_primary(State &state, DictRef session) {
	const DictRef hero = active_hero(state, session);
	return !gd::is_empty(state, hero) && gd::bool_field(state, hero, key::is_primary, false);
}

void hand_over_primary(State &state, DictRef session, Atom fallen_id) {
	const DictRef overworld = session_view::overworld(state, session);
	Value heroes_value;
	const ArrayRef heroes = state.lookup(overworld, str(key::player_heroes), heroes_value) ? gd::as_array(heroes_value) : state.new_array();
	Atom next_id = key::empty;
	int64_t best_experience = -1;
	for (const Value &hero : gd::items(state, array_value(heroes))) {
		if (gd::is_dict(hero) && text(state, hero.ref, key::id, key::empty) != fallen_id && gd::int_field(state, hero.ref, key::experience, 0) > best_experience) {
			best_experience = gd::int_field(state, hero.ref, key::experience, 0);
			next_id = text(state, hero.ref, key::id, key::empty);
		}
	}
	for (int64_t index = 0; index < state.array_size(heroes); ++index) {
		const Value hero = state.at(heroes, index);
		if (gd::is_dict(hero)) {
			state.set(hero.ref, str(key::is_primary), bool_value(text(state, hero.ref, key::id, key::empty) == next_id));
		}
	}
	state.set(overworld, str(key::player_heroes), array_value(heroes));
	state.set(session, str(key::hero_id), str(next_id));
	const DictRef flags = gd::as_dict(gd::index(state, session, str(key::flags)));
	Value fallen_value;
	const ArrayRef fallen = state.lookup(flags, str(key::primary_hero_fallen), fallen_value) && gd::is_array(fallen_value) ? fallen_value.ref : state.new_array();
	if (fallen_id != key::empty && !gd::array_has(state, fallen, str(fallen_id))) {
		state.append(fallen, str(fallen_id));
	}
	state.set(flags, str(key::primary_hero_fallen), array_value(fallen));
	_sync_active_hero_mirror(state, session);
}

bool keep_hero_troop_from_garrison(State &state, DictRef session, DictRef town, Atom hero_id) {
	const DictRef hero = hero_by_id(state, session, hero_id);
	if (gd::is_empty(state, hero) || gd::is_empty(state, town)) {
		return false;
	}
	// hero.get("army", {}).get("stacks", []): a missing field counts no stacks.
	Value army;
	Value hero_stacks;
	if (state.lookup(hero, str(key::army), army)) {
		hero_stacks = ai::vget(state, army, key::stacks, Value());
	}
	if (_valid_stack_count(state, hero_stacks) > 0) {
		return false;
	}
	Value garrison_value;
	const ArrayRef garrison = state.lookup(town, str(key::garrison), garrison_value) && gd::is_array(garrison_value)
			? gd::deep_duplicate_array(state, garrison_value.ref)
			: state.new_array();
	int64_t largest = -1;
	for (int64_t index = 0; index < state.array_size(garrison); ++index) {
		const Value stack = state.at(garrison, index);
		if (gd::is_dict(stack) && text(state, stack.ref, key::unit_id, key::empty) != key::empty && gd::int_field(state, stack.ref, key::count, 0) > 0) {
			if (largest < 0 || gd::int_field(state, stack.ref, key::count, 0) > gd::int_field(state, gd::as_dict(state.at(garrison, largest)), key::count, 0)) {
				largest = index;
			}
		}
	}
	if (largest < 0) {
		return false;
	}
	const DictRef chosen = gd::as_dict(state.at(garrison, largest));
	const Atom unit_id = text(state, chosen, key::unit_id, key::empty);
	state.set(chosen, str(key::count), int_value(gd::sub(gd::int_field(state, chosen, key::count, 0), 1)));
	if (gd::int_field(state, chosen, key::count, 0) <= 0) {
		gd::remove_at(state, garrison, largest);
	}
	_set_holder_stacks(state, session, town, key::garrison, garrison);
	const DictRef troop = state.new_dict();
	state.set(troop, str(key::unit_id), str(unit_id));
	state.set(troop, str(key::count), int_value(1));
	state.set(troop, str(key::slot_index), int_value(0));
	const ArrayRef troops = state.new_array();
	state.append(troops, dict_value(troop));
	_set_holder_stacks(state, session, town, hero_id, troops);
	return true;
}

DictRef remove_active_hero_after_defeat(State &state, DictRef session) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	commit_active_hero(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_hero_id = text(state, overworld, key::active_hero_id, key::empty);
	const DictRef removed_hero = hero_by_id(state, session, active_hero_id);
	if (gd::is_empty(state, removed_hero)) {
		return failure(state, key::no_active_hero_is_available);
	}
	if (gd::bool_field(state, removed_hero, key::is_primary, false)) {
		return failure(state, key::the_primary_hero_cannot_be_removed);
	}

	const ArrayRef remaining = state.new_array();
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (gd::is_dict(hero) && text(state, hero.ref, key::id, key::empty) != active_hero_id) {
			state.append(remaining, hero);
		}
	}
	state.set(overworld, str(key::player_heroes), array_value(remaining));
	Atom next_active_id = gd::stringify_or_fallback(state, gd::index(state, session, str(key::hero_id)));
	if (_hero_index_by_id(state, remaining, next_active_id) < 0 && state.array_size(remaining) > 0) {
		next_active_id = text(state, gd::as_dict(state.at(remaining, 0)), key::id, key::empty);
	}
	state.set(overworld, str(key::active_hero_id), str(next_active_id));
	_sync_active_hero_mirror(state, session);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(gd::format(state, key::s_falls_in_battle, {str(text(state, removed_hero, key::name, key::the_hero_text))})));
	state.set(result, str(key::removed_hero_name), str(text(state, removed_hero, key::name, key::the_hero_text)));
	state.set(result, str(key::next_active_name), str(text(state, active_hero(state, session), key::name, key::empty)));
	return result;
}

void _set_holder_stacks(State &state, DictRef session, DictRef town, Atom holder_id, ArrayRef stacks) {
	const DictRef overworld = session_view::overworld(state, session);
	if (holder_id == key::garrison) {
		if (gd::is_empty(state, town)) {
			return;
		}
		// session.overworld.get("towns", []): a missing field has no entries.
		Value towns;
		if (!state.lookup(overworld, str(key::towns), towns)) {
			return;
		}
		const int64_t size = ai::vsize(state, towns);
		for (int64_t index = 0; index < size; ++index) {
			const Value entry = ai::vindex(state, towns, int_value(index));
			if (!gd::is_dict(entry)) {
				continue;
			}
			if (text(state, entry.ref, key::placement_id, key::empty) != text(state, town, key::placement_id, key::empty)) {
				continue;
			}
			state.set(entry.ref, str(key::garrison), array_value(stacks));
			state.set(town, str(key::garrison), array_value(stacks));
			// towns[index] = entry: only an Array or a Dictionary holds one.
			if (gd::is_array(towns)) {
				state.set_at(towns.ref, index, entry);
			} else {
				state.set(gd::as_dict(towns), int_value(index), entry);
			}
			state.set(overworld, str(key::towns), towns);
			return;
		}
		return;
	}

	// session.overworld.get("player_heroes", []): a missing field has no hero.
	Value heroes_value;
	if (!state.lookup(overworld, str(key::player_heroes), heroes_value)) {
		return;
	}
	const ArrayRef heroes = gd::as_array(heroes_value);
	const int64_t hero_index = _hero_index_by_id(state, heroes, holder_id);
	if (hero_index < 0) {
		return;
	}
	const Value hero = state.at(heroes, hero_index);
	const DictRef army = _normalize_army(state, field_or_new_dict(state, gd::as_dict(hero), key::army), holder_id);
	state.set(army, str(key::stacks), array_value(stacks));
	state.set(hero.ref, str(key::army), dict_value(army));
	state.set_at(heroes, hero_index, hero);
	state.set(overworld, str(key::player_heroes), heroes_value);
	if (text(state, overworld, key::active_hero_id, key::empty) == holder_id) {
		_sync_active_hero_mirror(state, session);
	}
}

} // namespace hero_command_rules

// EnemyAdventureRules.

namespace enemy_adventure_rules {

Atom apply_resolved_commander_aftermath(State &state, DictRef session, Atom faction_id, const Value &commander_state, Atom outcome_id) {
	if (faction_id == key::empty || !gd::is_dict(commander_state)) {
		return key::empty;
	}
	const Atom roster_hero_id = text(state, commander_state.ref, key::roster_hero_id, key::empty);
	if (roster_hero_id == key::empty) {
		return key::empty;
	}
	const DictRef overworld = session_view::overworld(state, session);
	// session.overworld.get("enemy_states", []): a missing field has no states.
	Value states;
	if (!state.lookup(overworld, str(key::enemy_states), states) || !gd::is_array(states)) {
		return key::empty;
	}
	const int64_t state_count = state.array_size(states.ref);
	for (int64_t index = 0; index < state_count; ++index) {
		const Value enemy_state = state.at(states.ref, index);
		if (!gd::is_dict(enemy_state) || player_identity_rules::controller_id(state, enemy_state.ref, key::empty) != faction_id) {
			continue;
		}
		const ArrayRef roster = normalize_commander_roster(state, session, faction_id, state.get(enemy_state.ref, str(key::commander_roster), array_value(state.new_array())));
		const int64_t roster_size = state.array_size(roster);
		for (int64_t roster_index = 0; roster_index < roster_size; ++roster_index) {
			const Value entry_value = state.at(roster, roster_index);
			if (!gd::is_dict(entry_value) || text(state, entry_value.ref, key::roster_hero_id, key::empty) != roster_hero_id) {
				continue;
			}
			const DictRef entry = entry_value.ref;
			DictRef updated_state = advance_commander_record(state, commander_state.ref, outcome_id);
			if (outcome_id == key::defeated) {
				const DictRef continuity = commander_army_continuity(state, dict_value(updated_state));
				Atom defeated_encounter_id = text(state, continuity, key::encounter_id, key::empty);
				if (defeated_encounter_id == key::empty) {
					defeated_encounter_id = text(state, commander_army_continuity(state, commander_state), key::encounter_id, key::empty);
				}
				const DictRef army_source = state.new_dict();
				state.set(army_source, str(key::stacks), array_value(state.new_array()));
				updated_state = sync_commander_army_continuity(state, updated_state, dict_value(army_source), defeated_encounter_id);
			}
			state.set(entry, str(key::status), str(key::recovering));
			state.set(entry, str(key::active_placement_id), str(key::empty));
			state.set(entry, str(key::last_outcome), str(outcome_id));
			// entry[field] = max(0, int(updated_state.get(field, entry.get(field, 0)))).
			const auto record_count = [&](Atom field) {
				const Value entry_count = state.get(entry, str(field), int_value(0));
				const int64_t count = gd::to_int(state, state.get(updated_state, str(field), entry_count));
				state.set(entry, str(field), int_value(compat::engine_max<int64_t>(0, count)));
			};
			record_count(key::deployments);
			record_count(key::battle_wins);
			record_count(key::times_defeated);
			record_count(key::strategic_successes);
			state.set(entry, str(key::renown), int_value(commander_renown(state, dict_value(updated_state))));
			const DictRef roster_commander_state = build_roster_commander_state(state, roster_hero_id, faction_id, updated_state, entry_value);
			state.set(entry, str(key::commander_state), dict_value(roster_commander_state));
			state.set(entry, str(key::target_memory), dict_value(commander_target_memory(state, dict_value(roster_commander_state))));
			state.set(entry, str(key::commander_role_state), dict_value(commander_live_role_state(state, dict_value(roster_commander_state))));
			state.set(entry, str(key::army_continuity), dict_value(commander_army_continuity(state, dict_value(roster_commander_state))));
			int64_t recovery_days = 0;
			Atom summary = key::empty;
			if (outcome_id == key::defeated) {
				recovery_days = 3;
				summary = gd::format(state, key::s_is_routed_and_will_not, {
						str(commander_display_name(state, entry_value)),
						int_value(recovery_days),
						str(recovery_days == 1 ? key::empty : key::s),
				});
			} else if (outcome_id == key::assault_victory) {
				recovery_days = 1;
				summary = gd::format(state, key::s_is_consolidating_the_breach_and, {
						str(commander_display_name(state, entry_value)),
						int_value(recovery_days),
						str(recovery_days == 1 ? key::empty : key::s),
				});
			} else {
				state.set(entry, str(key::status), str(key::available));
			}
			state.set(entry, str(key::recovery_day), int_value(recovery_days > 0 ? gd::add(ai::session_int(state, session, key::day), recovery_days) : 0));
			state.set_at(roster, roster_index, entry_value);
			state.set(enemy_state.ref, str(key::commander_roster), array_value(roster));
			state.set_at(states.ref, index, enemy_state);
			state.set(overworld, str(key::enemy_states), states);
			return summary;
		}
	}
	return key::empty;
}

int64_t commander_renown(State &state, const Value &source) {
	const DictRef record = _normalized_commander_record(state, source, dict_value(state.new_dict()));
	return compat::engine_max<int64_t>(0, gd::int_field(state, record, key::renown, 0));
}

DictRef record_target_assignment(State &state, DictRef commander_state, Atom target_kind, Atom target_id, Atom target_label, int64_t target_x, int64_t target_y) {
	if (gd::is_empty(state, commander_state) || target_kind == key::empty || target_id == key::empty) {
		return _apply_commander_memory_metadata(state, commander_state, dict_value(commander_state));
	}
	const DictRef updated = gd::deep_duplicate_dict(state, commander_state);
	const DictRef memory = _normalized_commander_memory(state, dict_value(updated), dict_value(state.new_dict()));
	const bool is_focus_match = target_kind == text(state, memory, key::focus_target_kind, key::empty)
			&& target_id == text(state, memory, key::focus_target_id, key::empty);
	const bool is_last_match = target_kind == text(state, memory, key::last_target_kind, key::empty)
			&& target_id == text(state, memory, key::last_target_id, key::empty);
	int64_t next_focus_count = 1;
	if (is_focus_match) {
		next_focus_count = gd::add(compat::engine_max<int64_t>(1, gd::int_field(state, memory, key::focus_pressure_count, 0)), 1);
	} else if (is_last_match) {
		next_focus_count = compat::engine_max<int64_t>(2, gd::int_field(state, memory, key::focus_pressure_count, 0));
	}
	state.set(memory, str(key::focus_target_kind), str(target_kind));
	state.set(memory, str(key::focus_target_id), str(target_id));
	state.set(memory, str(key::focus_target_label), str(target_label));
	state.set(memory, str(key::focus_pressure_count), int_value(next_focus_count));
	state.set(memory, str(key::last_target_kind), str(target_kind));
	state.set(memory, str(key::last_target_id), str(target_id));
	state.set(memory, str(key::last_target_label), str(target_label));
	state.set(memory, str(key::front_label), str(target_label));
	state.set(memory, str(key::front_x), int_value(target_x));
	state.set(memory, str(key::front_y), int_value(target_y));
	state.set(updated, str(key::target_memory), dict_value(memory));
	return _apply_commander_memory_metadata(state, updated, dict_value(memory));
}

DictRef record_rivalry(State &state, DictRef commander_state, Atom rival_kind, Atom rival_id, Atom rival_label) {
	if (gd::is_empty(state, commander_state) || rival_kind == key::empty || rival_id == key::empty) {
		return _apply_commander_memory_metadata(state, commander_state, dict_value(commander_state));
	}
	const DictRef updated = gd::deep_duplicate_dict(state, commander_state);
	const DictRef memory = _normalized_commander_memory(state, dict_value(updated), dict_value(state.new_dict()));
	int64_t rivalry_count = 1;
	if (rival_kind == text(state, memory, key::rival_kind, key::empty) && rival_id == text(state, memory, key::rival_id, key::empty)) {
		rivalry_count = gd::add(compat::engine_max<int64_t>(1, gd::int_field(state, memory, key::rivalry_count, 0)), 1);
	}
	state.set(memory, str(key::rival_kind), str(rival_kind));
	state.set(memory, str(key::rival_id), str(rival_id));
	state.set(memory, str(key::rival_label), str(rival_label));
	state.set(memory, str(key::rivalry_count), int_value(rivalry_count));
	state.set(updated, str(key::target_memory), dict_value(memory));
	return _apply_commander_memory_metadata(state, updated, dict_value(memory));
}

ArrayRef _ai_hero_task_prune_live_tasks(State &state, ArrayRef tasks, int64_t day) {
	const ArrayRef kept = state.new_array();
	for (const Value &task : gd::items(state, array_value(tasks))) {
		if (!gd::is_dict(task)) {
			continue;
		}
		const int64_t expires_day = gd::int_field(state, task.ref, key::expires_day, 0);
		if (expires_day > 0 && gd::add(expires_day, 3) < day) {
			continue;
		}
		state.append(kept, task);
	}
	gd::sort_custom(state, kept, [&state](const Value &a, const Value &b) {
		const DictRef left = gd::as_dict(a);
		const DictRef right = gd::as_dict(b);
		const int64_t a_priority = _ai_hero_task_retention_priority(state, left);
		const int64_t b_priority = _ai_hero_task_retention_priority(state, right);
		if (a_priority != b_priority) {
			return a_priority > b_priority;
		}
		if (gd::int_field(state, left, key::assigned_day, 0) == gd::int_field(state, right, key::assigned_day, 0)) {
			return state.text(text(state, left, key::task_id, key::empty)) < state.text(text(state, right, key::task_id, key::empty));
		}
		return gd::int_field(state, left, key::assigned_day, 0) > gd::int_field(state, right, key::assigned_day, 0);
	});
	while (state.array_size(kept) > 12) {
		gd::pop_back(state, kept);
	}
	return kept;
}

int64_t _ai_hero_task_retention_priority(State &state, DictRef task) {
	const Atom status = text(state, task, key::task_status, key::empty);
	if (status == key::active || status == key::reserved || status == key::suspended) {
		return 4;
	}
	if (status == key::completed) {
		return 3;
	}
	if (status == key::planned) {
		return 2;
	}
	if (status == key::failed || status == key::cancelled || status == key::invalid) {
		return 1;
	}
	return 0;
}

} // namespace enemy_adventure_rules

// ArtifactRules.

namespace artifact_rules {

DictRef _select_rarity_source_reward(State &state, Atom source_tag, Atom rarity, Atom source_key, ArrayRef excluded_artifact_ids) {
	const Atom table_id = gd::format(state, key::placement_rarity_s, {str(rarity)});
	if (rarity == key::empty) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::reason), str(key::placement_holds_no_artifact));
		state.set(result, str(key::source_tag), str(source_tag));
		state.set(result, str(key::source_key), str(source_key));
		return result;
	}
	const ArrayRef rarities = state.new_array();
	state.append(rarities, str(rarity));
	const ArrayRef tiers = state.new_array();
	state.append(tiers, array_value(rarities));
	return _draw_from_rarities(state, source_tag, tiers, table_id, source_key, excluded_artifact_ids);
}

} // namespace artifact_rules

} // namespace aurelion::rules::port
