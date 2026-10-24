// OverworldRules for the human seat's choices (Phase 7, slice 7.3): the reward
// choice, dwelling hire, site recruits, level-up and specialties, with
// CreatureDwellingRules.hire_cost, HeroCommandRules' army slot snapshot and
// HeroProgressionRules' choice actions and texts.

#include "aurelion_rules/port/overworld_rules_context.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_turn.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <string>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp (Phase 5) without a header.
namespace hero_progression_rules {
int64_t max_rank_for_specialty(State &state, Atom specialty_id);
int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id);
Atom command_path(State &state, DictRef hero_state);
DictRef current_pending_choice(State &state, DictRef hero_state);
DictRef specialty_definition(State &state, Atom specialty_id);
} // namespace hero_progression_rules

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

// HeroCommandRules.ARMY_SLOT_COUNT.
constexpr int64_t kArmySlotCount = 7;

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

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) of a value that may be stored: the field, or a new {}.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// {"ok": ok, "message": message}.
DictRef outcome(State &state, bool ok, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(message));
	return result;
}

// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	return outcome(state, false, message);
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// var node: Dictionary = node_result.get("node", {}).
DictRef result_node(State &state, DictRef node_result) {
	Value node;
	return state.lookup(node_result, str(key::node), node) ? gd::as_dict(node) : state.new_dict();
}

// session.game_state, a String field.
Atom game_state(State &state, DictRef session) {
	return gd::to_string(gd::index(state, session, str(key::game_state)));
}

// ContentService.get_unit_art(unit_id): no content table holds unit art.
Value unit_art(State &state, Atom unit_id) {
	return gd::call_method(state, gd::autoload(state, key::ContentService), key::get_unit_art, {str(unit_id)});
}

// a.sort() of an Array of Strings: Godot compares Strings by code points, the
// byte order of their UTF-8. Anything else to compare is not ported.
void sort_strings(State &state, ArrayRef array, const char *where) {
	if (state.array_size(array) >= 2) {
		for (const Value &item : gd::items(state, array_value(array))) {
			if (!gd::is_string(item)) {
				throw state::NotPorted(std::string(where) + ": sort() of an Array that is not all Strings");
			}
		}
	}
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

// {"ok": ok, "hero": hero, "message": message}.
DictRef specialty_choice_result(State &state, bool ok, DictRef hero, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::message), str(message));
	return result;
}

// HeroProgressionRules.choose_specialty with its whole result: the port in
// enemy_states.cpp answers only the hero.
DictRef choose_specialty_result(State &state, DictRef hero_state, Atom specialty_id) {
	namespace hpr = hero_progression_rules;
	DictRef hero = hpr::ensure_hero_progression(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero_state), true)));
	const Value pending_choices = state.get(hero, str(key::pending_specialty_choices), array_value(state.new_array()));
	if (!gd::is_array(pending_choices) || state.array_size(pending_choices.ref) == 0) {
		return specialty_choice_result(state, false, hero, key::no_specialty_choice_is_waiting);
	}
	// var current_choice: Dictionary = pending_choices[0]
	const DictRef current_choice = gd::as_dict(state.at(pending_choices.ref, 0));
	// current_choice.get("options", []): a missing list holds nothing.
	Value options;
	const bool has_options = state.lookup(current_choice, str(key::options), options);
	if (!has_options || !gd::is_array(options) || !gd::array_has(state, options.ref, str(specialty_id))) {
		return specialty_choice_result(state, false, hero, key::that_specialty_is_not_available_for);
	}
	if (hpr::specialty_rank(state, hero, specialty_id) >= hpr::max_rank_for_specialty(state, specialty_id)) {
		return specialty_choice_result(state, false, hero, key::that_specialty_is_already_mastered);
	}
	Value specialties = state.get(hero, str(key::specialties), array_value(state.new_array()));
	if (!gd::is_array(specialties)) {
		specialties = array_value(state.new_array());
	}
	state.append(specialties.ref, str(specialty_id));
	state.set(hero, str(key::specialties), specialties);
	gd::remove_at(state, pending_choices.ref, 0);
	state.set(hero, str(key::pending_specialty_choices), pending_choices);
	hero = hpr::ensure_hero_progression(state, hero);

	const DictRef specialty = hpr::specialty_definition(state, specialty_id);
	Atom message = gd::format(state, key::s_adopts_s_s, {
			str(text_or(state, hero, key::name, key::the_hero_text)),
			str(text_or(state, specialty, key::name, specialty_id)),
			str(hpr::rank_label(state, hpr::specialty_rank(state, hero, specialty_id))),
	});
	if (hpr::pending_choices_remaining(state, hero) > 0) {
		const int64_t remaining = hpr::pending_choices_remaining(state, hero);
		const Atom plural = hpr::pending_choices_remaining(state, hero) == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
		message = concat(state, message, gd::format(state, key::d_specialty_choice_s_remain_queued, {int_value(remaining), str(plural)}));
	}
	return specialty_choice_result(state, true, hero, message);
}

} // namespace

namespace overworld_rules {

DictRef choose_resource_reward(State &state, DictRef session, Atom choice_id, DictRef expected_context) {
	normalize_overworld_state_for_runtime(state, session);
	const DictRef node_result = _find_context_resource_node(state, session);
	const DictRef node = result_node(state, node_result);
	if (choice_id == key::empty || gd::int_field(state, node_result, key::index, -1) < 0
			|| !gd::equal(state, dict_value(_resource_reward_choice_context(state, session, node)), dict_value(expected_context))) {
		return refusal(state, key::this_chest_is_no_longer_being);
	}
	return _collect_resource_node_result(state, session, node_result, true, 1, choice_id);
}

DictRef hire_from_dwelling(State &state, DictRef session, DictRef hires, DictRef expected_context) {
	normalize_overworld_state_for_runtime(state, session);
	const DictRef node_result = _find_context_resource_node(state, session);
	const int64_t index = gd::int_field(state, node_result, key::index, -1);
	if (index < 0) {
		return refusal(state, key::no_dwelling_is_being_visited);
	}
	const DictRef node = result_node(state, node_result);
	const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
	if (!creature_dwelling_rules::is_dwelling(state, site)
			|| !gd::equal(state, dict_value(_resource_reward_choice_context(state, session, node)), dict_value(expected_context))) {
		return refusal(state, key::this_dwelling_is_no_longer_being);
	}
	if (player_identity_rules::resource_controller_id(state, node) != key::player) {
		return refusal(state, gd::format(state, key::flag_s_before_hiring_there, {str(text_or(state, site, key::name, key::the_dwelling))}));
	}
	const int64_t day = ai::session_int(state, session, key::day);
	const DictRef available = creature_dwelling_rules::population(state, node, site, day);
	const DictRef chosen = state.new_dict();
	for (const Value &unit_id_value : gd::items(state, array_value(gd::keys(state, hires)))) {
		const Atom unit_id = string_of(state, unit_id_value);
		// mini(max(0, int(hires[unit_id_value])), int(available.get(unit_id, 0))): ints.
		const int64_t requested = compat::engine_max<int64_t>(0, gd::to_int(state, gd::index(state, hires, unit_id_value)));
		const int64_t count = compat::engine_min<int64_t>(requested, gd::to_int(state, state.get(available, str(unit_id), int_value(0))));
		if (count > 0) {
			state.set(chosen, str(unit_id), int_value(count));
		}
	}
	if (gd::is_empty(state, chosen)) {
		return refusal(state, key::choose_how_many_creatures_to_hire);
	}
	const DictRef overworld = session_view::overworld(state, session);
	// session.overworld.get("army", {}).get("stacks", [])
	Value army_value;
	const Value current_stacks = state.lookup(overworld, str(key::army), army_value)
			? ai::vget(state, army_value, key::stacks, array_value(state.new_array()))
			: array_value(state.new_array());
	const DictRef admission = hero_command_rules::army_addition_plan(state, current_stacks, chosen);
	if (!gd::bool_field(state, admission, key::ok, false)) {
		return admission;
	}
	const DictRef price = creature_dwelling_rules::hire_cost(state, chosen);
	if (!gd::is_empty(state, price) && !_can_afford(state, session, dict_value(price))) {
		return refusal(state, gd::format(state, key::you_cannot_afford_s, {str(_describe_resource_delta(state, dict_value(price)))}));
	}
	if (!gd::is_empty(state, price)) {
		_spend_resources(state, session, dict_value(price));
	}
	for (const Value &unit_id : gd::items(state, array_value(gd::keys(state, chosen)))) {
		creature_dwelling_rules::take(state, node, site, gd::to_string(unit_id), gd::to_int(state, gd::index(state, chosen, unit_id)), day);
	}
	// var nodes: Array = session.overworld.get("resource_nodes", [])
	const ArrayRef nodes = gd::as_array(state.get(overworld, str(key::resource_nodes), array_value(state.new_array())));
	state.set_at(nodes, index, dict_value(node));
	state.set(overworld, str(key::resource_nodes), array_value(nodes));
	const Value hero = field_or_new_dict(state, overworld, key::hero);
	const DictRef army = gd::as_dict(gd::engine_duplicate(state, ai::vget(state, hero, key::army, dict_value(state.new_dict())), true));
	state.set(army, str(key::stacks), state.get(admission, str(key::stacks), array_value(state.new_array())));
	state.set(gd::as_dict(hero), str(key::army), dict_value(army));
	state.set(overworld, str(key::hero), hero);
	state.set(overworld, str(key::army), dict_value(army));
	hero_command_rules::commit_active_hero(state, session);
	Atom message = gd::format(state, key::s_hires_s_at_s_2, {
			str(string_of(state, ai::vget(state, hero, key::name, str(key::the_hero_text)))),
			str(_describe_recruit_delta(state, dict_value(chosen))),
			str(text_or(state, site, key::name, key::the_dwelling)),
	});
	message = concat(state, message, !gd::is_empty(state, price)
					? gd::format(state, key::for_s_2, {str(_describe_resource_delta(state, dict_value(price)))})
					: static_cast<Atom>(key::for_free));
	const DictRef facts = state.new_dict();
	state.set(facts, str(key::recruits), gd::engine_duplicate(state, dict_value(chosen), true));
	return _finalize_action_result(state, session, true, message, false, false, facts);
}

DictRef get_level_up_prompt(State &state, DictRef session) {
	// session == null: a view is never null.
	if (game_state(state, session) != key::overworld) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	DictRef hero = gd::as_dict(state.get(overworld, str(key::hero), dict_value(state.new_dict())));
	DictRef summary = hero_progression_rules::level_up_summary(state, hero);
	if (gd::is_empty(state, summary)) {
		for (const Value &candidate : gd::field_items(state, overworld, str(key::player_heroes))) {
			if (string_of(state, ai::vget(state, candidate, key::id, str(key::empty))) == text_or(state, hero, key::id, key::empty)) {
				continue;
			}
			const DictRef candidate_summary = hero_progression_rules::level_up_summary(state, gd::as_dict(candidate));
			if (!gd::is_empty(state, candidate_summary)) {
				hero = candidate.ref;
				summary = candidate_summary;
				break;
			}
		}
	}
	if (gd::is_empty(state, summary)) {
		return state.new_dict();
	}
	state.set(summary, str(key::hero), gd::engine_duplicate(state, dict_value(hero), true));
	const DictRef context = state.new_dict();
	state.set(context, str(key::hero_id), str(text_or(state, hero, key::id, key::empty)));
	state.set(context, str(key::level), gd::index(state, summary, str(key::level)));
	state.set(context, str(key::previous_level), gd::index(state, summary, str(key::previous_level)));
	state.set(context, str(key::choice), gd::engine_duplicate(state, gd::index(state, summary, str(key::choice)), true));
	state.set(summary, str(key::context), dict_value(context));
	return summary;
}

DictRef resolve_level_up(State &state, DictRef session, DictRef context, Atom specialty_id) {
	// session == null: a view is never null.
	if (game_state(state, session) != key::overworld) {
		return refusal(state, key::return_to_the_adventure_map_to);
	}
	normalize_overworld_state(state, session);
	const DictRef prompt = get_level_up_prompt(state, session);
	bool changed = gd::is_empty(state, prompt);
	if (!changed) {
		// prompt.get("context", {}) != context: a missing context is {}.
		Value prompt_context;
		changed = state.lookup(prompt, str(key::context), prompt_context)
				? !gd::equal(state, prompt_context, dict_value(context))
				: !gd::is_empty(state, context);
	}
	if (changed) {
		return refusal(state, key::this_hero_s_level_up_choice);
	}
	DictRef result = outcome(state, true, key::level_up_reviewed_unchosen_specialties_remain);
	const Atom hero_id = string_of(state, ai::vget(state, gd::index(state, prompt, str(key::hero)), key::id, str(key::empty)));
	if (specialty_id != key::empty) {
		result = choose_specialty(state, session, specialty_id, hero_id);
		if (!gd::bool_field(state, result, key::ok, false)) {
			return result;
		}
	}
	const DictRef hero = hero_command_rules::hero_by_id(state, session, hero_id);
	if (specialty_id == key::empty || gd::is_empty(state, hero_progression_rules::current_pending_choice(state, hero))) {
		state.set(hero, str(key::level_up_presented), int_value(gd::to_int(state, gd::index(state, prompt, str(key::level)))));
		if (hero_id == text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty)) {
			// session.overworld["hero"]["level_up_presented"] = int(prompt["level"])
			const DictRef active_hero = gd::as_dict(gd::index(state, session_view::overworld(state, session), str(key::hero)));
			state.set(active_hero, str(key::level_up_presented), int_value(gd::to_int(state, gd::index(state, prompt, str(key::level)))));
			hero_command_rules::commit_active_hero(state, session);
		}
	}
	return result;
}

ArrayRef get_specialty_actions(State &state, DictRef session) {
	normalize_overworld_state_for_runtime(state, session);
	return hero_progression_rules::get_choice_actions(state, gd::as_dict(state.get(session_view::overworld(state, session), str(key::hero), dict_value(state.new_dict()))));
}

DictRef choose_specialty(State &state, DictRef session, Atom specialty_id, Atom hero_id) {
	normalize_overworld_state(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_id = text_or(state, overworld, key::active_hero_id, key::empty);
	if (hero_id == key::empty) {
		hero_id = active_id;
	}
	const DictRef hero = hero_command_rules::hero_by_id(state, session, hero_id);
	if (gd::is_empty(state, hero)) {
		return refusal(state, key::that_hero_is_no_longer_in);
	}
	const int64_t previous_movement_max = _movement_max_from_hero(state, hero, dict_value(session));
	// int(hero.get("spellbook", {}).get("mana", {}).get("max", SpellRulesScript.mana_max_from_hero(hero)))
	const Value spellbook = state.get(hero, str(key::spellbook), dict_value(state.new_dict()));
	const Value mana = ai::vget(state, spellbook, key::mana, dict_value(state.new_dict()));
	const int64_t mana_fallback = spell_rules::mana_max_from_hero(state, hero);
	const int64_t previous_mana_max = gd::to_int(state, ai::vget(state, mana, key::max, int_value(mana_fallback)));
	const DictRef result = choose_specialty_result(state, hero, specialty_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return refusal(state, text_or(state, result, key::message, key::unable_to_choose_specialty));
	}

	const DictRef chosen_hero = gd::as_dict(state.get(result, str(key::hero), dict_value(hero)));
	const DictRef updated = artifact_rules::ensure_hero_artifacts(state, spell_rules::ensure_hero_spellbook(state, chosen_hero, state.new_dict()));
	if (hero_id == active_id) {
		state.set(overworld, str(key::hero), dict_value(updated));
		_sync_movement_to_hero(state, session, previous_movement_max);
		_sync_spellbook_to_hero(state, session, previous_mana_max);
	} else {
		// Town defenders can level while another commander is selected. Apply
		// their bonuses without switching the active hero, camera or route.
		const DictRef movement = gd::as_dict(state.get(updated, str(key::movement), dict_value(state.new_dict())));
		const int64_t new_max = _movement_max_from_hero(state, updated, dict_value(session));
		const int64_t current = gd::to_int(state, state.get(movement, str(key::current), int_value(previous_movement_max)));
		state.set(movement, str(key::current), int_value(compat::engine_clamp<int64_t>(gd::sub(gd::add(current, new_max), previous_movement_max), 0, new_max)));
		state.set(movement, str(key::max), int_value(new_max));
		state.set(updated, str(key::movement), dict_value(movement));
		// var mana: Dictionary = updated.get("spellbook", {}).get("mana", {})
		const Value updated_spellbook = state.get(updated, str(key::spellbook), dict_value(state.new_dict()));
		const DictRef updated_mana = gd::as_dict(ai::vget(state, updated_spellbook, key::mana, dict_value(state.new_dict())));
		const int64_t mana_max = gd::to_int(state, state.get(updated_mana, str(key::max), int_value(previous_mana_max)));
		const int64_t mana_current = gd::to_int(state, state.get(updated_mana, str(key::current), int_value(previous_mana_max)));
		state.set(updated_mana, str(key::current), int_value(compat::engine_clamp<int64_t>(gd::sub(gd::add(mana_current, mana_max), previous_mana_max), 0, mana_max)));
		hero_command_rules::_replace_hero_in_array(state, gd::as_array(gd::index(state, overworld, str(key::player_heroes))), updated);
	}
	return _finalize_action_result(state, session, true, text_or(state, result, key::message, key::empty), true, false, state.new_dict());
}

DictRef _pending_site_recruits(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	// var pending = session.overworld.get(PENDING_SITE_RECRUITS_KEY, {}): a missing one is the empty {}.
	Value pending;
	if (!state.lookup(overworld, str(key::pending_site_recruits), pending) || !gd::is_dict(pending) || gd::is_empty(state, pending.ref)) {
		return state.new_dict();
	}
	// pending.get("tile", {}): a missing tile is an empty Dictionary.
	Value tile;
	const bool has_tile = state.lookup(pending.ref, str(key::tile), tile);
	bool still_there = text_or(state, pending.ref, key::hero_id, key::empty) == text_or(state, overworld, key::active_hero_id, key::empty);
	if (still_there) {
		still_there = !has_tile || gd::is_dict(tile);
	}
	if (still_there) {
		const int64_t x = has_tile ? gd::int_field(state, tile.ref, key::x, -1) : -1;
		const int64_t y = has_tile ? gd::int_field(state, tile.ref, key::y, -1) : -1;
		still_there = Vector2i::of(x, y) == hero_position(state, session);
	}
	// pending.get("recruits", {}): a missing one is an empty Dictionary.
	Value recruits;
	const bool has_recruits = state.lookup(pending.ref, str(key::recruits), recruits);
	if (!still_there || !has_recruits || !gd::is_dict(recruits) || gd::is_empty(state, recruits.ref)) {
		state.erase(overworld, str(key::pending_site_recruits));
		return state.new_dict();
	}
	return pending.ref;
}

DictRef site_recruit_overflow_prompt(State &state, DictRef session) {
	// session == null: a view is never null.
	const DictRef pending = _pending_site_recruits(state, session);
	if (gd::is_empty(state, pending)) {
		return state.new_dict();
	}
	const Atom hero_id = text_or(state, pending, key::hero_id, key::empty);
	const ArrayRef waiting = state.new_array();
	const DictRef recruits = gd::as_dict(state.get(pending, str(key::recruits), dict_value(state.new_dict())));
	const ArrayRef unit_ids = gd::keys(state, recruits);
	sort_strings(state, unit_ids, "OverworldRules.site_recruit_overflow_prompt");
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = string_of(state, unit_id_value);
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::unit_id), str(unit_id));
		state.set(entry, str(key::unit_name), str(text_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, unit_id)));
		state.set(entry, str(key::count), int_value(gd::to_int(state, gd::index(state, recruits, unit_id_value))));
		state.set(entry, str(key::portrait), str(string_of(state, ai::vget(state, unit_art(state, unit_id), key::portrait, str(key::empty)))));
		state.append(waiting, dict_value(entry));
	}
	const DictRef prompt = state.new_dict();
	state.set(prompt, str(key::title), str(text_or(state, pending, key::site_name, key::claimed_site)));
	state.set(prompt, str(key::site_name), str(text_or(state, pending, key::site_name, key::empty)));
	state.set(prompt, str(key::waiting), array_value(waiting));
	const DictRef snapshot = hero_command_rules::army_slot_snapshot(state, session, state.new_dict(), hero_id);
	state.set(prompt, str(key::slots), state.get(snapshot, str(key::slots), array_value(state.new_array())));
	const DictRef context = state.new_dict();
	state.set(context, str(key::hero_id), str(hero_id));
	state.set(context, str(key::placement_id), str(text_or(state, pending, key::placement_id, key::empty)));
	state.set(prompt, str(key::context), dict_value(context));
	return prompt;
}

bool _pending_matches(State &state, DictRef pending, DictRef expected_context) {
	return !gd::is_empty(state, pending)
			&& text_or(state, pending, key::hero_id, key::empty) == text_or(state, expected_context, key::hero_id, key::empty)
			&& text_or(state, pending, key::placement_id, key::empty) == text_or(state, expected_context, key::placement_id, key::empty);
}

DictRef take_site_recruits_by_dismissing(State &state, DictRef session, int64_t slot_index, DictRef expected_context) {
	const DictRef pending = _pending_site_recruits(state, session);
	if (!_pending_matches(state, pending, expected_context)) {
		return refusal(state, key::those_troops_are_no_longer_waiting);
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Value hero = field_or_new_dict(state, overworld, key::hero);
	const DictRef army = gd::as_dict(gd::engine_duplicate(state, ai::vget(state, hero, key::army, dict_value(state.new_dict())), true));
	const ArrayRef kept = state.new_array();
	DictRef dismissed = state.new_dict();
	const ArrayRef slotted = hero_command_rules::_slotted_stacks(state, state.get(army, str(key::stacks), array_value(state.new_array())));
	for (const Value &stack : gd::items(state, array_value(slotted))) {
		if (gd::is_empty(state, dismissed) && gd::to_int(state, ai::vget(state, stack, key::slot_index, int_value(-1))) == slot_index) {
			dismissed = gd::as_dict(stack);
		} else {
			state.append(kept, stack);
		}
	}
	if (gd::is_empty(state, dismissed)) {
		return refusal(state, key::choose_one_of_your_stacks_to);
	}
	const DictRef split = hero_command_rules::army_addition_split(state, array_value(kept), gd::as_dict(state.get(pending, str(key::recruits), dict_value(state.new_dict()))));
	const DictRef added = gd::as_dict(state.get(split, str(key::added), dict_value(state.new_dict())));
	state.set(army, str(key::stacks), state.get(split, str(key::stacks), array_value(kept)));
	state.set(gd::as_dict(hero), str(key::army), dict_value(army));
	state.set(overworld, str(key::hero), hero);
	state.set(overworld, str(key::army), dict_value(army));
	hero_command_rules::commit_active_hero(state, session);
	const DictRef remaining = gd::as_dict(state.get(split, str(key::overflow), dict_value(state.new_dict())));
	if (gd::is_empty(state, remaining)) {
		state.erase(overworld, str(key::pending_site_recruits));
	} else {
		state.set(pending, str(key::recruits), dict_value(remaining));
		state.set(overworld, str(key::pending_site_recruits), dict_value(pending));
	}
	// String(ContentService.get_unit(String(dismissed.get("unit_id", ""))).get("name", dismissed.get("unit_id", "")))
	const DictRef unit = gd::content_row(state, ContentTable::Unit, text_or(state, dismissed, key::unit_id, key::empty));
	const Atom unit_name = string_of(state, state.get(unit, str(key::name), state.get(dismissed, str(key::unit_id), str(key::empty))));
	const Atom message = gd::format(state, key::dismissed_d_s_s_join_the, {
			int_value(gd::int_field(state, dismissed, key::count, 0)),
			str(unit_name),
			str(_describe_recruit_count(state, added)),
	});
	const DictRef result = outcome(state, true, message);
	state.set(result, str(key::dismissed), dict_value(dismissed));
	state.set(result, str(key::added), dict_value(added));
	state.set(result, str(key::remaining), gd::engine_duplicate(state, dict_value(remaining), true));
	return result;
}

DictRef leave_site_recruits(State &state, DictRef session, DictRef expected_context) {
	const DictRef pending = _pending_site_recruits(state, session);
	if (!_pending_matches(state, pending, expected_context)) {
		return refusal(state, key::those_troops_are_no_longer_waiting);
	}
	state.erase(session_view::overworld(state, session), str(key::pending_site_recruits));
	const DictRef recruits = gd::as_dict(state.get(pending, str(key::recruits), dict_value(state.new_dict())));
	return outcome(state, true, gd::format(state, key::s_stay_behind_at_s, {
			str(_describe_recruit_count(state, recruits)),
			str(text_or(state, pending, key::site_name, key::the_site)),
	}));
}

} // namespace overworld_rules

namespace hero_command_rules {

DictRef army_slot_snapshot(State &state, DictRef session, DictRef town, Atom holder_id) {
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	// session == null: a view is never null.
	if (holder_id == key::empty) {
		return state.new_dict();
	}
	if (!_army_slot_holder_is_available(state, session, town, holder_id)) {
		return state.new_dict();
	}
	const ArrayRef holder_stacks = _holder_stacks(state, session, town, holder_id);
	const int64_t occupied_count = _valid_stack_count(state, array_value(holder_stacks));
	const ArrayRef overflow_stacks = state.new_array();
	int64_t troop_count = 0;
	int64_t valid_index = 0;
	for (const Value &stack : gd::items(state, array_value(holder_stacks))) {
		if (!gd::is_dict(stack) || text_or(state, stack.ref, key::unit_id, key::empty) == key::empty || gd::int_field(state, stack.ref, key::count, 0) <= 0) {
			continue;
		}
		troop_count = gd::add(troop_count, gd::int_field(state, stack.ref, key::count, 0));
		if (valid_index >= kArmySlotCount) {
			const Atom unit_id = text_or(state, stack.ref, key::unit_id, key::empty);
			const DictRef overflow = state.new_dict();
			state.set(overflow, str(key::unit_id), str(unit_id));
			state.set(overflow, str(key::unit_name), str(text_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, unit_id)));
			state.set(overflow, str(key::count), int_value(gd::int_field(state, stack.ref, key::count, 0)));
			state.append(overflow_stacks, dict_value(overflow));
		}
		valid_index += 1;
	}
	const ArrayRef stacks = _slotted_stacks(state, array_value(holder_stacks));
	const DictRef by_slot = state.new_dict();
	for (const Value &stack_value : gd::items(state, array_value(stacks))) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		state.set(by_slot, int_value(gd::int_field(state, stack_value.ref, key::slot_index, -1)), stack_value);
	}
	const ArrayRef slots = state.new_array();
	for (int64_t slot_index = 0; slot_index < kArmySlotCount; ++slot_index) {
		// var stack: Dictionary = by_slot.get(slot_index, {}): a missing one is empty.
		Value stack;
		const bool has_stack = state.lookup(by_slot, int_value(slot_index), stack);
		const Atom unit_id = has_stack ? text_or(state, gd::as_dict(stack), key::unit_id, key::empty) : static_cast<Atom>(key::empty);
		const int64_t count = has_stack ? gd::int_field(state, stack.ref, key::count, 0) : 0;
		const DictRef slot = state.new_dict();
		state.set(slot, str(key::slot_index), int_value(slot_index));
		if (unit_id == key::empty || count <= 0) {
			state.set(slot, str(key::occupied), bool_value(false));
			state.set(slot, str(key::holder_id), str(holder_id));
			state.append(slots, dict_value(slot));
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const Value art = unit_art(state, unit_id);
		state.set(slot, str(key::occupied), bool_value(true));
		state.set(slot, str(key::holder_id), str(holder_id));
		state.set(slot, str(key::unit_id), str(unit_id));
		state.set(slot, str(key::unit_name), str(text_or(state, unit, key::name, unit_id)));
		state.set(slot, str(key::count), int_value(count));
		state.set(slot, str(key::tier), int_value(compat::engine_clamp<int64_t>(gd::int_field(state, unit, key::tier, 1), 1, 7)));
		state.set(slot, str(key::role), str(text_or(state, unit, key::role, key::empty)));
		state.set(slot, str(key::battle_icon), str(string_of(state, ai::vget(state, art, key::battle_icon, str(key::empty)))));
		state.set(slot, str(key::portrait), str(string_of(state, ai::vget(state, art, key::portrait, str(key::empty)))));
		state.append(slots, dict_value(slot));
	}
	const DictRef snapshot = state.new_dict();
	state.set(snapshot, str(key::model), str(key::authoritative_seven_slot_army_bar));
	state.set(snapshot, str(key::holder_id), str(holder_id));
	state.set(snapshot, str(key::holder_label), str(_holder_label(state, session, town, holder_id)));
	state.set(snapshot, str(key::slot_count), int_value(kArmySlotCount));
	state.set(snapshot, str(key::capacity_valid), bool_value(occupied_count <= kArmySlotCount));
	state.set(snapshot, str(key::occupied_slot_count), int_value(occupied_count));
	state.set(snapshot, str(key::overflow_stack_count), int_value(state.array_size(overflow_stacks)));
	state.set(snapshot, str(key::overflow_stacks), array_value(overflow_stacks));
	state.set(snapshot, str(key::message), str(occupied_count > kArmySlotCount
					? gd::format(state, key::d_stacks_exceed_the_seven_slot, {int_value(occupied_count)})
					: static_cast<Atom>(key::empty)));
	state.set(snapshot, str(key::troop_count), int_value(troop_count));
	state.set(snapshot, str(key::slots), array_value(slots));
	return snapshot;
}

ArrayRef _stationed_holder_ids(State &state, DictRef session, DictRef town) {
	const ArrayRef holders = state.new_array();
	state.append(holders, str(key::garrison));
	for (const Value &hero : gd::items(state, array_value(stationed_heroes(state, session, town)))) {
		state.append(holders, str(string_of(state, ai::vget(state, hero, key::id, str(key::empty)))));
	}
	return holders;
}

bool _army_slot_holder_is_available(State &state, DictRef session, DictRef town, Atom holder_id) {
	// session == null: a view is never null.
	if (holder_id == key::empty) {
		return false;
	}
	if (!gd::is_empty(state, town)) {
		return gd::array_has(state, _stationed_holder_ids(state, session, town), str(holder_id));
	}
	if (holder_id == text_or(state, session_view::overworld(state, session), key::active_hero_id, key::empty)) {
		return !gd::is_empty(state, hero_by_id(state, session, holder_id));
	}
	// In the field, a commander sharing the active commander's tile joins the
	// hero meeting, so slot orders may move troops between the two.
	return _is_field_exchange_partner(state, session, holder_id);
}

bool _is_field_exchange_partner(State &state, DictRef session, Atom hero_id) {
	const DictRef active = active_hero(state, session);
	const DictRef partner = hero_by_id(state, session, hero_id);
	if (gd::is_empty(state, active) || gd::is_empty(state, partner) || hero_id == text_or(state, active, key::id, key::empty)) {
		return false;
	}
	const DictRef partner_position = _normalize_position(state, state.get(partner, str(key::position), dict_value(state.new_dict())));
	const DictRef active_position = _normalize_position(state, state.get(active, str(key::position), dict_value(state.new_dict())));
	return gd::equal(state, dict_value(partner_position), dict_value(active_position));
}

Atom _holder_label(State &state, DictRef session, DictRef town, Atom holder_id) {
	if (holder_id == key::garrison) {
		const DictRef town_row = gd::content_row(state, ContentTable::Town, text_or(state, town, key::town_id, key::empty));
		const Value fallback = state.get(town, str(key::town_id), str(key::Town));
		return gd::format(state, key::s_garrison_2, {str(string_of(state, state.get(town_row, str(key::name), fallback)))});
	}
	const DictRef hero = hero_by_id(state, session, holder_id);
	return text_or(state, hero, key::name, holder_id);
}

} // namespace hero_command_rules

namespace hero_progression_rules {

DictRef level_up_summary(State &state, DictRef hero_state) {
	const DictRef hero = ensure_hero_progression(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero_state), true)));
	const int64_t previous = gd::to_int(state, gd::index(state, hero, str(key::level_up_presented)));
	const int64_t level = gd::to_int(state, gd::index(state, hero, str(key::level)));
	if (previous >= level) {
		return state.new_dict();
	}
	DictRef gains = state.new_dict();
	const ArrayRef rolls = state.new_array();
	for (int64_t earned_level = gd::add(previous, 1); earned_level < gd::add(level, 1); ++earned_level) {
		const Atom stat = command_gain_stat(state, hero, earned_level);
		gains = _apply_command_gain(state, dict_value(gains), stat);
		const DictRef roll = state.new_dict();
		state.set(roll, str(key::level), int_value(earned_level));
		state.set(roll, str(key::stat), str(stat));
		state.append(rolls, dict_value(roll));
	}
	const Atom path = command_path(state, hero);
	// (COMMAND_GAIN_WEIGHTS[path] as Dictionary).duplicate()
	if (path != key::might && path != key::magic) {
		throw state::ScriptError("Invalid access to property or key '" + state.text(path) + "' on a base object of type 'Dictionary'.");
	}
	const bool magic = path == key::magic;
	const DictRef odds = state.new_dict();
	state.set(odds, str(key::attack), int_value(magic ? 10 : 40));
	state.set(odds, str(key::defense), int_value(magic ? 10 : 40));
	state.set(odds, str(key::power), int_value(magic ? 40 : 10));
	state.set(odds, str(key::knowledge), int_value(magic ? 40 : 10));
	const DictRef summary = state.new_dict();
	state.set(summary, str(key::previous_level), int_value(previous));
	state.set(summary, str(key::level), int_value(level));
	state.set(summary, str(key::command_gains), dict_value(gains));
	state.set(summary, str(key::command_rolls), array_value(rolls));
	state.set(summary, str(key::command_path), str(path));
	state.set(summary, str(key::command_odds), dict_value(odds));
	state.set(summary, str(key::movement_gain), int_value(gd::sub(level, previous)));
	state.set(summary, str(key::choice), dict_value(current_pending_choice(state, hero)));
	state.set(summary, str(key::choices_remaining), int_value(pending_choices_remaining(state, hero)));
	return summary;
}

ArrayRef get_choice_actions(State &state, DictRef hero_state) {
	const DictRef hero = ensure_hero_progression(state, gd::as_dict(gd::engine_duplicate(state, dict_value(hero_state), true)));
	const DictRef pending_choice = current_pending_choice(state, hero);
	if (gd::is_empty(state, pending_choice)) {
		return state.new_array();
	}

	const ArrayRef actions = state.new_array();
	for (const Value &specialty_id_value : gd::field_items(state, pending_choice, str(key::options))) {
		const Atom specialty_id = string_of(state, specialty_id_value);
		const DictRef specialty = specialty_definition(state, specialty_id);
		if (gd::is_empty(state, specialty)) {
			continue;
		}
		const int64_t next_rank = gd::add(specialty_rank(state, hero, specialty_id), 1);
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::choose_specialty_s, {str(specialty_id)})));
		state.set(action, str(key::label), str(gd::format(state, key::choose_s_2, {str(text_or(state, specialty, key::short_name, specialty_id))})));
		state.set(action, str(key::summary), str(gd::format(state, key::s_s_s_2, {
				str(text_or(state, specialty, key::name, specialty_id)),
				str(rank_label(state, next_rank)),
				str(rank_text(state, specialty_id, next_rank)),
		})));
		state.set(action, str(key::disabled), bool_value(false));
		state.append(actions, dict_value(action));
	}
	return actions;
}

Atom rank_text(State &state, Atom specialty_id, int64_t rank) {
	// var ranks: Array = _specialty_row(specialty_id).get("ranks", []): a missing list is empty.
	Value ranks;
	const bool has_ranks = state.lookup(_specialty_row(state, specialty_id), str(key::ranks), ranks);
	const int64_t size = has_ranks ? state.array_size(gd::as_array(ranks)) : 0;
	if (rank < 1 || rank > size) {
		return key::empty;
	}
	return string_of(state, ai::vget(state, state.at(ranks.ref, rank - 1), key::text, str(key::empty)));
}

} // namespace hero_progression_rules

namespace creature_dwelling_rules {

DictRef hire_cost(State &state, DictRef hires) {
	const DictRef total = state.new_dict();
	for (const Value &unit_id : gd::items(state, array_value(gd::keys(state, hires)))) {
		const int64_t count = gd::to_int(state, gd::index(state, hires, unit_id));
		const DictRef cost = unit_cost(state, string_of(state, unit_id));
		for (const Value &cost_key : gd::items(state, array_value(gd::keys(state, cost)))) {
			const int64_t held = gd::to_int(state, state.get(total, cost_key, int_value(0)));
			state.set(total, cost_key, int_value(gd::add(held, gd::mul(gd::to_int(state, gd::index(state, cost, cost_key)), count))));
		}
	}
	return total;
}

} // namespace creature_dwelling_rules

} // namespace aurelion::rules::port
