// OverworldRules for the human seat's arrival (Phase 7, slice 7.2): a site's
// recruits, spells, experience, artifacts and the costs they check.

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <string>
#include <vector>

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
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// d.get(field, {}) of a value that may be stored: the field, or a new {}.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(x) of any value: the engine's text for a float, a vector or a container.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// sep.join(parts) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// clamp(value, lo, hi) of ints, untyped: lo when value < lo, then hi when that is > hi.
int64_t clamp_untyped(int64_t value, int64_t lo, int64_t hi) {
	if (value < lo) {
		value = lo;
	}
	if (value > hi) {
		value = hi;
	}
	return value;
}

// {"applied": false, "reason": reason}.
DictRef not_applied(State &state, Atom reason) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::applied), bool_value(false));
	state.set(result, str(key::reason), str(reason));
	return result;
}

} // namespace

namespace overworld_rules {

Atom _grant_site_claim_recruits(State &state, DictRef session, const Value &recruits, DictRef node, DictRef site) {
	if (!gd::is_dict(recruits) || gd::is_empty(state, recruits.ref)) {
		return key::empty;
	}
	const DictRef split = _add_to_active_army(state, session, recruits.ref);
	const DictRef added = gd::as_dict(field_or_new_dict(state, split, key::added));
	const DictRef overflow = gd::as_dict(field_or_new_dict(state, split, key::overflow));
	std::vector<Atom> messages;
	if (!gd::is_empty(state, added)) {
		messages.push_back(gd::format(state, key::auxiliaries_join_the_field_army_s, {str(_describe_recruit_delta(state, dict_value(added)))}));
	}
	if (!gd::is_empty(state, overflow)) {
		const DictRef pending = state.new_dict();
		state.set(pending, str(key::hero_id), str(ai::string_or_empty(state, session_view::overworld(state, session), key::active_hero_id)));
		state.set(pending, str(key::tile), dict_value(_route_tile_payload(state, hero_position(state, session))));
		state.set(pending, str(key::placement_id), str(ai::string_or_empty(state, node, key::placement_id)));
		state.set(pending, str(key::site_name), str(text_or(state, site, key::name, key::the_site)));
		state.set(pending, str(key::recruits), gd::engine_duplicate(state, dict_value(overflow), true));
		state.set(session_view::overworld(state, session), str(key::pending_site_recruits), dict_value(pending));
		messages.push_back(gd::format(state, key::no_room_for_s_dismiss_a, {str(_describe_recruit_count(state, overflow))}));
	}
	return join_atoms(state, key::space, messages);
}

DictRef _add_to_active_army(State &state, DictRef session, DictRef recruits) {
	const Value hero = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	const Value army_source = ai::vget(state, hero, key::army, dict_value(state.new_dict()));
	const DictRef army = gd::as_dict(gd::engine_duplicate(state, army_source, true));
	const Value stacks = state.get(army, str(key::stacks), array_value(state.new_array()));
	const DictRef split = hero_command_rules::army_addition_split(state, stacks, recruits);
	Value added;
	const bool any_added = state.lookup(split, str(key::added), added) && !ai::vempty(state, added);
	if (any_added) {
		state.set(army, str(key::stacks), state.get(split, str(key::stacks), array_value(state.new_array())));
		state.set(gd::as_dict(hero), str(key::army), dict_value(army));
		state.set(session_view::overworld(state, session), str(key::hero), hero);
		state.set(session_view::overworld(state, session), str(key::army), dict_value(army));
	}
	return split;
}

Atom _describe_recruit_count(State &state, DictRef recruits) {
	return gd::replace(state, _describe_recruit_delta(state, dict_value(recruits)), key::plus, key::empty);
}

Atom _learn_site_spell(State &state, DictRef session, Atom spell_id) {
	if (spell_id == key::empty) {
		return key::empty;
	}
	const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
	const DictRef result = spell_rules::learn_spell(state, hero, spell_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return key::empty;
	}
	const Value fallback = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	state.set(session_view::overworld(state, session), str(key::hero), state.get(result, str(key::hero), fallback));
	return text_or(state, result, key::message, key::empty);
}

ArrayRef _learn_site_spells(State &state, DictRef session, const Value &spell_ids) {
	const ArrayRef messages = state.new_array();
	if (!gd::is_array(spell_ids)) {
		return messages;
	}
	for (int64_t index = 0; index < state.array_size(spell_ids.ref); ++index) {
		const Atom message = _learn_site_spell(state, session, gd::stringify(state, state.at(spell_ids.ref, index)));
		if (message != key::empty) {
			state.append(messages, str(message));
		}
	}
	return messages;
}

ArrayRef _resource_site_spell_names(State &state, DictRef site) {
	const ArrayRef result = state.new_array();
	const ArrayRef spell_ids = _resource_site_spell_ids(state, site);
	for (int64_t index = 0; index < state.array_size(spell_ids); ++index) {
		const Atom spell_id = gd::stringify(state, state.at(spell_ids, index));
		const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
		state.append(result, str(text_or(state, spell, key::name, spell_id)));
	}
	return result;
}

ArrayRef _award_experience(State &state, DictRef session, int64_t amount) {
	if (amount <= 0) {
		return state.new_array();
	}
	const int64_t previous_movement_max = _movement_max_from_hero(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)), dict_value(session));
	// int(hero.get("spellbook", {}).get("mana", {}).get("max", mana_max_from_hero(hero))).
	const Value hero = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	const Value spellbook = ai::vget(state, hero, key::spellbook, dict_value(state.new_dict()));
	const Value mana = ai::vget(state, spellbook, key::mana, dict_value(state.new_dict()));
	const int64_t mana_fallback = spell_rules::mana_max_from_hero(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
	const int64_t previous_mana_max = gd::to_int(state, ai::vget(state, mana, key::max, int_value(mana_fallback)));
	const DictRef result = hero_progression_rules::add_experience(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)), amount);
	const Value fallback = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	const DictRef progressed = gd::as_dict(state.get(result, str(key::hero), fallback));
	const DictRef with_spellbook = spell_rules::ensure_hero_spellbook(state, progressed, state.new_dict());
	state.set(session_view::overworld(state, session), str(key::hero), dict_value(artifact_rules::ensure_hero_artifacts(state, with_spellbook)));
	_sync_movement_to_hero(state, session, previous_movement_max);
	_sync_spellbook_to_hero(state, session, previous_mana_max);
	return gd::as_array(state.get(result, str(key::messages), array_value(state.new_array())));
}

bool _can_afford(State &state, DictRef session, const Value &cost) {
	// resources: read only, a missing one is the {} fallback.
	Value resources;
	const bool has_resources = state.lookup(session_view::overworld(state, session), str(key::resources), resources);
	if (!gd::is_dict(cost)) {
		return true;
	}
	// for key in cost.keys(): a copy of the keys.
	const state::ValueList cost_keys = state.dict(cost.ref).keys.list();
	for (const Value &cost_key : cost_keys) {
		const Value resource_key = str(string_of(state, cost_key));
		const Value held = has_resources ? ai::vget(state, resources, resource_key, int_value(0)) : int_value(0);
		const int64_t held_amount = gd::to_int(state, held);
		if (held_amount < gd::to_int(state, gd::index(state, cost.ref, cost_key))) {
			return false;
		}
	}
	return true;
}

void _sync_spellbook_to_hero(State &state, DictRef session, int64_t previous_max) {
	const Value hero = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	const Value spellbook = ai::vget(state, hero, key::spellbook, dict_value(state.new_dict()));
	if (!gd::is_dict(spellbook)) {
		return;
	}
	const Value mana = ai::vget(state, spellbook, key::mana, dict_value(state.new_dict()));
	if (!gd::is_dict(mana)) {
		return;
	}
	const int64_t fallback = spell_rules::mana_max_from_hero(state, gd::as_dict(hero));
	const int64_t new_max = gd::to_int(state, state.get(mana.ref, str(key::max), int_value(fallback)));
	int64_t current = gd::to_int(state, state.get(mana.ref, str(key::current), int_value(new_max)));
	current = clamp_untyped(gd::add(current, gd::sub(new_max, previous_max)), 0, new_max);
	state.set(mana.ref, str(key::current), int_value(current));
	state.set(mana.ref, str(key::max), int_value(new_max));
	state.set(spellbook.ref, str(key::mana), mana);
	state.set(gd::as_dict(hero), str(key::spellbook), spellbook);
	state.set(session_view::overworld(state, session), str(key::hero), hero);
}

DictRef _grant_resource_site_artifact_reward(State &state, DictRef session, DictRef node, DictRef site) {
	const Atom source_tag = artifact_rules::live_source_reward_tag(state, site);
	if (source_tag == key::empty) {
		return not_applied(state, key::source_not_opted_in);
	}
	if (ai::string_or_empty(state, node, key::artifact_reward_id) != key::empty) {
		return not_applied(state, key::source_reward_already_claimed);
	}
	const Value scenario_id = gd::index(state, session, str(key::scenario_id));
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(scenario_id));
	const Atom faction_id = ai::string_or_empty(state, scenario, key::player_faction_id);
	const Atom source_key = gd::format(state, key::consequence_cache_key_text, {
		scenario_id,
		str(ai::string_or_empty(state, node, key::placement_id)),
		str(ai::string_or_empty(state, node, key::site_id)),
	});
	// A generated bank or tomb can hold several artifacts, one per HoMM3 class.
	const ArrayRef owned = artifact_rules::owned_artifact_ids(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
	const ArrayRef selections = artifact_rules::select_live_source_rewards(state, source_tag, site, source_key, faction_id, owned);
	if (state.array_size(selections) == 0) {
		const ArrayRef owned_again = artifact_rules::owned_artifact_ids(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
		return artifact_rules::select_live_source_reward(state, source_tag, site, source_key, faction_id, owned_again);
	}
	const DictRef result = gd::as_dict(gd::engine_duplicate(state, state.at(selections, 0), true));
	const ArrayRef artifact_ids = state.new_array();
	std::vector<Atom> messages;
	for (int64_t index = 0; index < state.array_size(selections); ++index) {
		const Value selection = state.at(selections, index);
		const Atom artifact_id = gd::stringify(state, ai::vget(state, selection, key::artifact_id, str(key::empty)));
		const Atom source_verb = source_tag == key::shrine
				? gd::format(state, key::s_grants, {str(text_or(state, site, key::name, key::the_shrine))})
				: gd::format(state, key::recovered_from_s, {str(text_or(state, site, key::name, key::the_reward_site))});
		const DictRef claim = _apply_artifact_claim(state, session, artifact_id, source_verb, true);
		if (gd::bool_field(state, claim, key::ok, false) && !gd::bool_field(state, claim, key::duplicate, false)) {
			state.append(artifact_ids, str(gd::stringify(state, ai::vget(state, selection, key::artifact_id, str(key::empty)))));
			messages.push_back(text_or(state, claim, key::message, key::empty));
		}
		if (!state.has(result, str(key::claim))) {
			state.set(result, str(key::claim), dict_value(claim));
		}
	}
	state.set(result, str(key::applied), bool_value(state.array_size(artifact_ids) != 0));
	if (state.array_size(artifact_ids) != 0) {
		state.set(result, str(key::artifact_id), str(gd::stringify(state, state.at(artifact_ids, 0))));
	}
	state.set(result, str(key::artifact_ids), array_value(artifact_ids));
	state.set(result, str(key::message), str(join_atoms(state, key::space, messages)));
	return result;
}

DictRef _army_totals(State &state, DictRef army) {
	int64_t headcount = 0;
	int64_t groups = 0;
	Value stacks;
	// for stack in army.get("stacks", []): a missing list holds nothing. A
	// String, a number, a vector or a packed array yields no Dictionary;
	// anything else GDScript cannot iterate fails in items() as it fails there.
	const bool has_stacks = state.lookup(army, str(key::stacks), stacks);
	const bool yields_no_dicts = stacks.kind == Kind::String || stacks.kind == Kind::Int || stacks.kind == Kind::Float || stacks.kind == Kind::Vector2i || stacks.kind == Kind::Vector3i || stacks.is_packed();
	if (has_stacks && !yields_no_dicts) {
		for (const Value &stack : gd::items(state, stacks)) {
			if (!gd::is_dict(stack)) {
				continue;
			}
			const int64_t count = compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0));
			if (count <= 0) {
				continue;
			}
			headcount = gd::add(headcount, count);
			groups = gd::add(groups, 1);
		}
	}
	const DictRef totals = state.new_dict();
	state.set(totals, str(key::headcount), int_value(headcount));
	state.set(totals, str(key::groups), int_value(groups));
	return totals;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
