// ScenarioRules, ScenarioScriptRules and ScenarioFactory: the paths of the computer players' day the six seeds do not
// run (Phase 4, slice 4.2): objective progress, the script state's checks, and town and resource states from placements.

#include "aurelion_rules/port/scenario_factory_turn.hpp"
#include "aurelion_rules/port/scenario_rules_turn.hpp"
#include "aurelion_rules/port/scenario_script_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules_turn.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

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
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// max(a, b) of ints.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}

// d.get(key, {}) and d.get(key, []) where the result is kept: a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// value.size() if value is Array else 0, for value = d.get(key, []) (a missing key reads as []).
int64_t array_field_size(State &state, DictRef dict, Atom field) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return 0;
	}
	return gd::is_array(found) ? state.array_size(found.ref) : 0;
}

// value.duplicate() of an untyped value.
Value duplicate_untyped(State &state, const Value &value) {
	if (gd::is_dict(value) || gd::is_array(value) || gd::is_packed(value)) {
		return gd::duplicate_value(state, value, false);
	}
	if (value.kind == state::Kind::Nil) {
		throw state::ScriptError("Cannot call method 'duplicate' on a null value.");
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'duplicate' in base '") + gd::type_name(value) + "'.");
}

// s.split(delimiter) with allow_empty (String::split): the pieces between the delimiters.
std::vector<std::string> split_text(const std::string &text, const std::string &delimiter) {
	std::vector<std::string> pieces;
	if (text.empty()) {
		pieces.emplace_back();
		return pieces;
	}
	size_t from = 0;
	while (true) {
		const size_t found = text.find(delimiter, from);
		if (found == std::string::npos) {
			pieces.push_back(text.substr(from));
			break;
		}
		pieces.push_back(text.substr(from, found - from));
		from = found + delimiter.size();
	}
	return pieces;
}

// ScenarioFactory._copy_resource_runtime_metadata's key list, in its order.
constexpr Atom kResourceRuntimeMetadataKeys[] = {
	key::content_batch_id, key::object_id, key::zone_id, key::owner, key::player_slot, key::player_type, key::team_id,
	key::kind, key::generated_kind, key::original_resource_category_id, key::resource_id,
	key::neutral_dwelling_family_id, key::guard_pressure, key::guard_front_id, key::body_tiles, key::blocking_body,
	key::approach_tiles, key::visit_tile, key::pathing_status, key::object_footprint_catalog_ref, key::footprint,
	key::runtime_footprint, key::body_mask, key::runtime_body_mask, key::visit_mask, key::approach_mask,
	key::passability_mask, key::action_mask, key::terrain_restrictions, key::placement_predicates,
	key::placement_predicate_results, key::footprint_deferred, key::development_source_support,
	key::source_support_town_placement_id, key::source_support_faction_id, key::source_support_missing_resource_ids,
	key::artifact_reward_id, key::artifact_reward_table_id, key::artifact_reward_source_key,
	key::artifact_reward_claimed_by_faction_id, key::artifact_reward_claimed_day,
};

// The requirement loop _hero_army_requirement_progress and _town_garrison_requirement_progress share: a row per
// Dictionary in objective.requirements (when it is an Array) with the army's count of its unit; the ready count.
int64_t append_unit_requirement_rows(State &state, DictRef objective, DictRef army, ArrayRef rows) {
	Value requirements;
	if (!state.lookup(objective, str(key::requirements), requirements) || !gd::is_array(requirements)) {
		return 0;
	}
	int64_t ready_count = 0;
	for (const Value &requirement : gd::items(state, requirements)) {
		if (!gd::is_dict(requirement)) {
			continue;
		}
		const Atom unit_id = ai::string_or_empty(state, requirement.ref, key::unit_id);
		const int64_t minimum_count = imax(1, gd::int_field(state, requirement.ref, key::minimum_count, 0));
		const int64_t current_count = scenario_rules::_army_unit_count(state, army, unit_id);
		const bool met = current_count >= minimum_count;
		if (met) {
			ready_count += 1;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const DictRef row = state.new_dict();
		state.set(row, str(key::unit_id), str(unit_id));
		state.set(row, str(key::unit_name), str(text(state, unit, key::name, unit_id)));
		state.set(row, str(key::minimum_count), int_value(minimum_count));
		state.set(row, str(key::current_count), int_value(current_count));
		state.set(row, str(key::met), bool_value(met));
		state.append(rows, dict_value(row));
	}
	return ready_count;
}

} // namespace

namespace scenario_rules {

Value _overworld_rules(State &state) {
	(void)state;
	// load("res://scripts/core/OverworldRules.gd"): a script object has no native value. The ported callers call
	// overworld_rules:: directly.
	throw state::NotPorted("ScenarioRules._overworld_rules: a script reference has no native value");
}

Atom _titleize_token(State &state, Atom value) {
	if (value == key::empty) {
		return key::empty;
	}
	const std::vector<std::string> words = split_text(state.text(value), "_");
	std::string joined;
	for (size_t index = 0; index < words.size(); ++index) {
		if (index > 0) {
			joined += " ";
		}
		joined += state.text(gd::capitalize(state, state.intern(words[index])));
	}
	return state.intern(joined);
}

DictRef _hero_stationing_progress(State &state, DictRef session, DictRef objective) {
	const Atom hero_id = ai::string_or_empty(state, objective, key::hero_id);
	const DictRef hero = _controlled_hero_state(state, session, hero_id);
	const DictRef town = _find_town(state, session, objective);
	const bool hero_found = !gd::is_empty(state, hero);
	const bool town_found = !gd::is_empty(state, town);
	const bool town_controlled = town_found && text(state, town, key::owner, key::neutral) == key::player;
	Value hero_position;
	if (!hero_found || !state.lookup(hero, str(key::position), hero_position)) {
		hero_position = dict_value(state.new_dict());
	}
	bool position_matches = false;
	if (gd::is_dict(hero_position) && town_found) {
		const DictRef hero_tile = overworld_level_rules::position(state, hero_position.ref);
		const DictRef entrance = overworld_level_rules::town_entrance(state, town);
		position_matches = gd::equal(state, dict_value(hero_tile), dict_value(entrance));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::hero_id), str(hero_id));
	state.set(result, str(key::hero_found), bool_value(hero_found));
	state.set(result, str(key::town_found), bool_value(town_found));
	state.set(result, str(key::town_controlled), bool_value(town_controlled));
	state.set(result, str(key::position_matches), bool_value(position_matches));
	state.set(result, str(key::complete), bool_value(hero_found && town_controlled && position_matches));
	return result;
}

DictRef _reserve_delivery_progress(State &state, DictRef session, DictRef objective) {
	const Atom site_placement_id = gd::strip_edges(state, ai::string_or_empty(state, objective, key::site_placement_id));
	const Atom target_kind = gd::strip_edges(state, text(state, objective, key::target_kind, key::town));
	const Atom target_id = gd::strip_edges(state, ai::string_or_empty(state, objective, key::target_id));
	const int64_t minimum_count = imax(1, gd::int_field(state, objective, key::minimum_count, 1));
	DictRef relay = state.new_dict();
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (gd::is_dict(node) && ai::string_or_empty(state, node.ref, key::placement_id) == site_placement_id) {
			relay = node.ref;
			break;
		}
	}
	const Atom receipt_key = gd::format(state, key::s_s_6, { str(target_kind), str(target_id) });
	// A missing count table reads as {}: no receipts.
	int64_t completed_count = 0;
	if (!gd::is_empty(state, relay)) {
		Value completion_counts;
		if (state.lookup(relay, str(key::delivery_completion_counts), completion_counts) && gd::is_dict(completion_counts)) {
			completed_count = imax(0, gd::int_field(state, completion_counts.ref, receipt_key, 0));
		}
	}
	const bool relay_found = !gd::is_empty(state, relay);
	const DictRef result = state.new_dict();
	state.set(result, str(key::site_placement_id), str(site_placement_id));
	state.set(result, str(key::target_kind), str(target_kind));
	state.set(result, str(key::target_id), str(target_id));
	state.set(result, str(key::relay_found), bool_value(relay_found));
	state.set(result, str(key::completed_count), int_value(completed_count));
	state.set(result, str(key::minimum_count), int_value(minimum_count));
	state.set(result, str(key::complete), bool_value(relay_found && completed_count >= minimum_count));
	return result;
}

DictRef _map_exploration_progress(State &state, DictRef session, DictRef objective) {
	const int64_t minimum_percent = compat::engine_clamp<int64_t>(gd::int_field(state, objective, key::minimum_percent, 1), 1, 100);
	// A missing or non-Dictionary fog reads as {}.
	Value fog;
	const bool has_fog = state.lookup(session_view::overworld(state, session), str(key::fog), fog) && gd::is_dict(fog);
	const Vector2i map_size = overworld_rules::derive_map_size(state, session);
	const int64_t expected_total_tiles = gd::mul(imax(0, map_size.x), imax(0, map_size.y));
	int64_t total_tiles = imax(0, has_fog ? gd::int_field(state, fog.ref, key::total_tiles, expected_total_tiles) : expected_total_tiles);
	if (total_tiles != expected_total_tiles) {
		total_tiles = expected_total_tiles;
	}
	const int64_t explored_count = compat::engine_clamp<int64_t>(has_fog ? gd::int_field(state, fog.ref, key::explored_count, 0) : 0, 0, total_tiles);
	int64_t required_count = 1;
	int64_t explored_percent = 0;
	if (total_tiles > 0) {
		required_count = compat::float_to_int(compat::godot_ceil(static_cast<double>(gd::mul(total_tiles, minimum_percent)) / 100.0));
		explored_percent = compat::float_to_int(compat::godot_floor(static_cast<double>(gd::mul(explored_count, 100)) / static_cast<double>(total_tiles)));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::explored_count), int_value(explored_count));
	state.set(result, str(key::total_tiles), int_value(total_tiles));
	state.set(result, str(key::required_count), int_value(required_count));
	state.set(result, str(key::explored_percent), int_value(explored_percent));
	state.set(result, str(key::minimum_percent), int_value(minimum_percent));
	state.set(result, str(key::complete), bool_value(total_tiles > 0 && explored_count >= required_count));
	return result;
}

DictRef _resource_stockpile_progress(State &state, DictRef session, DictRef objective) {
	Value authored_requirements;
	if (!state.lookup(objective, str(key::requirements), authored_requirements) || !gd::is_dict(authored_requirements) ||
			gd::is_empty(state, authored_requirements.ref)) {
		const DictRef empty_result = state.new_dict();
		state.set(empty_result, str(key::requirements), array_value(state.new_array()));
		state.set(empty_result, str(key::complete), bool_value(false));
		return empty_result;
	}
	const DictRef requirements = authored_requirements.ref;
	const ArrayRef resource_ids = gd::new_typed_array(state, state::variant_type::STRING);
	for (const Value &resource_id : gd::items(state, dict_value(requirements))) {
		state.append(resource_ids, str(gd::stringify(state, resource_id)));
	}
	gd::sort_custom(state, resource_ids, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	const ArrayRef rows = gd::new_typed_array(state, state::variant_type::DICTIONARY);
	bool complete = true;
	// A missing or non-Dictionary stockpile reads as {}.
	Value resources;
	const bool has_resources = state.lookup(session_view::overworld(state, session), str(key::resources), resources) && gd::is_dict(resources);
	for (const Value &resource_id_value : gd::items(state, array_value(resource_ids))) {
		const Atom resource_id = resource_id_value.ref;
		const int64_t minimum_count = imax(1, gd::int_field(state, requirements, resource_id, 1));
		const int64_t current_count = imax(0, has_resources ? gd::int_field(state, resources.ref, resource_id, 0) : 0);
		const DictRef resource = gd::content_row(state, ContentTable::Resource, resource_id);
		const bool met = current_count >= minimum_count;
		// resource.get("display_name", resource.get("name", _titleize_token(resource_id))): inner first.
		const Atom titled = _titleize_token(state, resource_id);
		const Value name = state.get(resource, str(key::name), str(titled));
		const Atom resource_name = gd::stringify(state, state.get(resource, str(key::display_name), name));
		const DictRef row = state.new_dict();
		state.set(row, str(key::resource_id), str(resource_id));
		state.set(row, str(key::resource_name), str(resource_name));
		state.set(row, str(key::current_count), int_value(current_count));
		state.set(row, str(key::minimum_count), int_value(minimum_count));
		state.set(row, str(key::met), bool_value(met));
		state.append(rows, dict_value(row));
		complete = complete && met;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::requirements), array_value(rows));
	state.set(result, str(key::complete), bool_value(complete));
	return result;
}

DictRef _resource_site_control_progress(State &state, DictRef session, DictRef objective) {
	Value authored_placement_ids;
	if (!state.lookup(objective, str(key::placement_ids), authored_placement_ids) || !gd::is_array(authored_placement_ids) ||
			state.array_size(authored_placement_ids.ref) == 0) {
		const DictRef empty_result = state.new_dict();
		state.set(empty_result, str(key::placement_ids), array_value(state.new_array()));
		state.set(empty_result, str(key::controlled_count), int_value(0));
		state.set(empty_result, str(key::minimum_count), int_value(1));
		state.set(empty_result, str(key::complete), bool_value(false));
		return empty_result;
	}
	const ArrayRef placement_ids = gd::new_typed_array(state, state::variant_type::STRING);
	for (const Value &placement_id : gd::items(state, authored_placement_ids)) {
		const Atom normalized_id = gd::strip_edges(state, gd::stringify(state, placement_id));
		if (normalized_id != key::empty && !gd::array_has(state, placement_ids, str(normalized_id))) {
			state.append(placement_ids, str(normalized_id));
		}
	}
	const int64_t placement_count = state.array_size(placement_ids);
	const int64_t minimum_count = compat::engine_clamp<int64_t>(gd::int_field(state, objective, key::minimum_count, placement_count), 1, imax(1, placement_count));
	const ArrayRef controlled_ids = gd::new_typed_array(state, state::variant_type::STRING);
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node)) {
			continue;
		}
		const Atom placement_id = ai::string_or_empty(state, node.ref, key::placement_id);
		if (gd::array_has(state, placement_ids, str(placement_id)) && ai::string_or_empty(state, node.ref, key::collected_by_faction_id) == key::player) {
			state.append(controlled_ids, str(placement_id));
		}
	}
	const int64_t controlled_count = state.array_size(controlled_ids);
	const DictRef result = state.new_dict();
	state.set(result, str(key::placement_ids), array_value(placement_ids));
	state.set(result, str(key::controlled_placement_ids), array_value(controlled_ids));
	state.set(result, str(key::controlled_count), int_value(controlled_count));
	state.set(result, str(key::minimum_count), int_value(minimum_count));
	state.set(result, str(key::complete), bool_value(controlled_count >= minimum_count));
	return result;
}

DictRef _hero_army_requirement_progress(State &state, DictRef session, DictRef objective) {
	const Atom hero_id = ai::string_or_empty(state, objective, key::hero_id);
	const DictRef army = _controlled_hero_army(state, session, hero_id);
	const ArrayRef rows = state.new_array();
	const int64_t ready_count = append_unit_requirement_rows(state, objective, army, rows);
	const int64_t requirement_count = state.array_size(rows);
	const bool hero_found = !gd::is_empty(state, army);
	const DictRef result = state.new_dict();
	state.set(result, str(key::hero_id), str(hero_id));
	state.set(result, str(key::hero_found), bool_value(hero_found));
	state.set(result, str(key::requirement_count), int_value(requirement_count));
	state.set(result, str(key::ready_count), int_value(ready_count));
	state.set(result, str(key::requirements), array_value(rows));
	state.set(result, str(key::complete), bool_value(requirement_count > 0 && hero_found && ready_count == requirement_count));
	return result;
}

DictRef _town_garrison_requirement_progress(State &state, DictRef session, DictRef objective) {
	const DictRef town = _find_town(state, session, objective);
	const bool town_found = !gd::is_empty(state, town);
	const ArrayRef rows = state.new_array();
	// {"stacks": town.garrison if the town has an Array there, else []}.
	Value stacks;
	if (!town_found || !state.lookup(town, str(key::garrison), stacks) || !gd::is_array(stacks)) {
		stacks = array_value(state.new_array());
	}
	const DictRef garrison_army = state.new_dict();
	state.set(garrison_army, str(key::stacks), stacks);
	const int64_t ready_count = append_unit_requirement_rows(state, objective, garrison_army, rows);
	const bool town_controlled = town_found && text(state, town, key::owner, key::neutral) == key::player;
	const int64_t requirement_count = state.array_size(rows);
	const DictRef result = state.new_dict();
	state.set(result, str(key::placement_id), str(ai::string_or_empty(state, objective, key::placement_id)));
	state.set(result, str(key::town_found), bool_value(town_found));
	state.set(result, str(key::town_controlled), bool_value(town_controlled));
	state.set(result, str(key::requirement_count), int_value(requirement_count));
	state.set(result, str(key::ready_count), int_value(ready_count));
	state.set(result, str(key::requirements), array_value(rows));
	state.set(result, str(key::complete), bool_value(requirement_count > 0 && town_controlled && ready_count == requirement_count));
	return result;
}

DictRef _artifact_set_equipment_progress(State &state, DictRef session, DictRef objective) {
	const Atom hero_id = ai::string_or_empty(state, objective, key::hero_id);
	const Atom set_id = ai::string_or_empty(state, objective, key::set_id);
	const DictRef hero = _controlled_hero_state(state, session, hero_id);
	const DictRef artifact_set = artifact_rules::artifact_set_record(state, set_id);
	const bool hero_found = !gd::is_empty(state, hero);
	const DictRef result = state.new_dict();
	state.set(result, str(key::hero_id), str(hero_id));
	state.set(result, str(key::set_id), str(set_id));
	state.set(result, str(key::set_name), str(text(state, artifact_set, key::name, set_id)));
	state.set(result, str(key::hero_found), bool_value(hero_found));
	state.set(result, str(key::piece_count), int_value(array_field_size(state, artifact_set, key::piece_ids)));
	state.set(result, str(key::equipped_piece_count), int_value(0));
	state.set(result, str(key::equipped_piece_ids), array_value(state.new_array()));
	state.set(result, str(key::complete), bool_value(false));
	if (!hero_found || gd::is_empty(state, artifact_set)) {
		return result;
	}
	const ArrayRef set_states = artifact_rules::artifact_set_runtime_state(state, hero);
	for (const Value &set_state_value : gd::items(state, array_value(set_states))) {
		if (!gd::is_dict(set_state_value)) {
			continue;
		}
		const DictRef set_state = set_state_value.ref;
		if (ai::string_or_empty(state, set_state, key::set_id) != set_id) {
			continue;
		}
		state.set(result, str(key::equipped_piece_count), int_value(gd::int_field(state, set_state, key::equipped_piece_count, 0)));
		Value piece_ids;
		const Value equipped_piece_ids = state.lookup(set_state, str(key::equipped_piece_ids), piece_ids) ? duplicate_untyped(state, piece_ids) : array_value(state.new_array());
		state.set(result, str(key::equipped_piece_ids), equipped_piece_ids);
		state.set(result, str(key::complete), bool_value(gd::bool_field(state, set_state, key::complete, false)));
		break;
	}
	return result;
}

DictRef _hero_progression_requirement_progress(State &state, DictRef session, DictRef objective) {
	const Atom hero_id = ai::string_or_empty(state, objective, key::hero_id);
	const DictRef hero = _controlled_hero_state(state, session, hero_id);
	const bool hero_found = !gd::is_empty(state, hero);
	const int64_t minimum_level = imax(1, gd::int_field(state, objective, key::minimum_level, 1));
	const int64_t minimum_resolved_choice_count = imax(0, gd::int_field(state, objective, key::minimum_resolved_specialty_choices, 0));
	const int64_t current_level = hero_found ? imax(1, gd::int_field(state, hero, key::level, 1)) : 0;
	const DictRef hero_template = gd::content_row(state, ContentTable::Hero, hero_id);
	const int64_t starting_specialty_count = array_field_size(state, hero_template, key::starting_specialties);
	const int64_t resolved_choice_count = imax(0, gd::sub(array_field_size(state, hero, key::specialties), starting_specialty_count));
	const int64_t pending_choice_count = array_field_size(state, hero, key::pending_specialty_choices);
	const bool require_no_pending_choices = gd::bool_field(state, objective, key::require_no_pending_specialty_choices, false);
	const DictRef result = state.new_dict();
	state.set(result, str(key::hero_id), str(hero_id));
	state.set(result, str(key::hero_found), bool_value(hero_found));
	state.set(result, str(key::minimum_level), int_value(minimum_level));
	state.set(result, str(key::current_level), int_value(current_level));
	state.set(result, str(key::minimum_resolved_choice_count), int_value(minimum_resolved_choice_count));
	state.set(result, str(key::resolved_choice_count), int_value(resolved_choice_count));
	state.set(result, str(key::starting_specialty_count), int_value(starting_specialty_count));
	state.set(result, str(key::require_no_pending_choices), bool_value(require_no_pending_choices));
	state.set(result, str(key::pending_choice_count), int_value(pending_choice_count));
	state.set(result, str(key::complete),
			bool_value(hero_found && current_level >= minimum_level && resolved_choice_count >= minimum_resolved_choice_count &&
					(!require_no_pending_choices || pending_choice_count == 0)));
	return result;
}

DictRef _controlled_hero_state(State &state, DictRef session, Atom hero_id) {
	if (hero_id == key::empty) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_hero_id = ai::string_or_empty(state, overworld, key::active_hero_id);
	if (active_hero_id == hero_id) {
		Value active_hero;
		if (!state.lookup(overworld, str(key::hero), active_hero)) {
			// The fallback {}: its id reads as active_hero_id, so it is the answer.
			return state.new_dict();
		}
		if (gd::is_dict(active_hero) && text(state, active_hero.ref, key::id, active_hero_id) == hero_id) {
			return active_hero.ref;
		}
	}
	Value heroes;
	if (!state.lookup(overworld, str(key::player_heroes), heroes) || !gd::is_array(heroes)) {
		return state.new_dict();
	}
	for (const Value &hero : gd::items(state, heroes)) {
		if (gd::is_dict(hero) && ai::string_or_empty(state, hero.ref, key::id) == hero_id) {
			return hero.ref;
		}
	}
	return state.new_dict();
}

DictRef _controlled_hero_army(State &state, DictRef session, Atom hero_id) {
	if (hero_id == key::empty) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_hero_id = ai::string_or_empty(state, overworld, key::active_hero_id);
	if (active_hero_id == hero_id) {
		const Value active_army = get_or_new_dict(state, overworld, key::army);
		if (gd::is_dict(active_army)) {
			return active_army.ref;
		}
	}
	const DictRef hero = _controlled_hero_state(state, session, hero_id);
	const Value hero_army = get_or_new_dict(state, hero, key::army);
	return gd::is_dict(hero_army) ? hero_army.ref : state.new_dict();
}

int64_t _army_unit_count(State &state, DictRef army, Atom unit_id) {
	if (gd::is_empty(state, army) || unit_id == key::empty) {
		return 0;
	}
	int64_t total = 0;
	Value stacks;
	if (!state.lookup(army, str(key::stacks), stacks) || !gd::is_array(stacks)) {
		return 0;
	}
	for (const Value &stack : gd::items(state, stacks)) {
		if (gd::is_dict(stack) && ai::string_or_empty(state, stack.ref, key::unit_id) == unit_id) {
			total = gd::add(total, imax(0, gd::int_field(state, stack.ref, key::count, 0)));
		}
	}
	return total;
}

bool _player_owns_artifact(State &state, DictRef session, Atom artifact_id) {
	if (artifact_id == key::empty) {
		return false;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Value active_hero = get_or_new_dict(state, overworld, key::hero);
	if (gd::is_dict(active_hero) && artifact_rules::has_artifact(state, active_hero.ref, artifact_id)) {
		return true;
	}
	const Value fallback_id = gd::is_dict(active_hero) ? state.get(active_hero.ref, str(key::id), str(key::empty)) : str(key::empty);
	const Atom active_hero_id = gd::stringify(state, state.get(overworld, str(key::active_hero_id), fallback_id));
	Value heroes;
	if (!state.lookup(overworld, str(key::player_heroes), heroes) || !gd::is_array(heroes)) {
		return false;
	}
	for (const Value &hero : gd::items(state, heroes)) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		if (ai::string_or_empty(state, hero.ref, key::id) == active_hero_id) {
			continue;
		}
		if (artifact_rules::has_artifact(state, hero.ref, artifact_id)) {
			return true;
		}
	}
	return false;
}

bool _player_knows_spell(State &state, DictRef session, Atom spell_id) {
	if (spell_id == key::empty) {
		return false;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Value active_hero = get_or_new_dict(state, overworld, key::hero);
	if (gd::is_dict(active_hero) && spell_rules::knows_spell(state, active_hero.ref, spell_id)) {
		return true;
	}
	const Value fallback_id = gd::is_dict(active_hero) ? state.get(active_hero.ref, str(key::id), str(key::empty)) : str(key::empty);
	const Atom active_hero_id = gd::stringify(state, state.get(overworld, str(key::active_hero_id), fallback_id));
	Value heroes;
	if (!state.lookup(overworld, str(key::player_heroes), heroes) || !gd::is_array(heroes)) {
		return false;
	}
	for (const Value &hero : gd::items(state, heroes)) {
		if (!gd::is_dict(hero) || ai::string_or_empty(state, hero.ref, key::id) == active_hero_id) {
			continue;
		}
		if (spell_rules::knows_spell(state, hero.ref, spell_id)) {
			return true;
		}
	}
	return false;
}

bool _town_has_objective_building(State &state, DictRef town, Atom building_id) {
	if (building_id == key::empty) {
		return false;
	}
	const Value built = get_or_new_array(state, town, key::built_buildings);
	if (!gd::is_array(built)) {
		return false;
	}
	if (gd::array_has(state, built.ref, str(building_id))) {
		return true;
	}
	// Current-development towns store only the active stage of each building line under current ids. Map older
	// objective ids through the faction's migration table and accept any later stage of that line.
	const Value migration_table = get_or_new_dict(state, town_development_rules::data(state), key::migration);
	const Atom faction_id = town_development_rules::faction_id(state, town);
	const DictRef migration = gd::as_dict(ai::vget(state, migration_table, str(faction_id), dict_value(state.new_dict())));
	const Atom required = gd::stringify(state, state.get(migration, str(building_id), str(building_id)));
	return town_development_rules::satisfies(state, built.ref, required);
}

DictRef _find_town(State &state, DictRef session, DictRef objective) {
	const Atom placement_id = ai::string_or_empty(state, objective, key::placement_id);
	const Atom town_id = ai::string_or_empty(state, objective, key::town_id);
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town)) {
			continue;
		}
		if (placement_id != key::empty && ai::string_or_empty(state, town.ref, key::placement_id) == placement_id) {
			return town.ref;
		}
		if (town_id != key::empty && ai::string_or_empty(state, town.ref, key::town_id) == town_id) {
			return town.ref;
		}
	}
	return state.new_dict();
}

} // namespace scenario_rules

namespace scenario_script_rules {

DictRef build_script_state(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::fired_hook_ids), array_value(state.new_array()));
	state.set(result, str(key::event_log), array_value(state.new_array()));
	return result;
}

bool _hook_fired(State &state, DictRef session, Atom hook_id) {
	if (hook_id == key::empty) {
		return false;
	}
	// A missing script state reads as {}, and a missing hook list as []: nothing fired.
	Value script_state_value;
	if (!state.lookup(session_view::overworld(state, session), str(key::scenario_script_state), script_state_value)) {
		return false;
	}
	const DictRef script_state = gd::as_dict(script_state_value);
	Value fired_hook_ids;
	if (!state.lookup(script_state, str(key::fired_hook_ids), fired_hook_ids)) {
		return false;
	}
	return gd::is_array(fired_hook_ids) && gd::array_has(state, fired_hook_ids.ref, str(hook_id));
}

bool _encounter_resolved(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return false;
	}
	Value resolved;
	if (!state.lookup(session_view::overworld(state, session), str(key::resolved_encounters), resolved)) {
		return false;
	}
	return gd::is_array(resolved) && gd::array_has(state, resolved.ref, str(placement_id));
}

} // namespace scenario_script_rules

namespace scenario_factory {

ArrayRef _build_town_states(State &state, const Value &placements) {
	const ArrayRef towns = state.new_array();
	if (!gd::is_array(placements)) {
		return towns;
	}
	for (const Value &placement_value : gd::items(state, placements)) {
		if (!gd::is_dict(placement_value)) {
			continue;
		}
		const DictRef placement = placement_value.ref;
		const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, placement, key::town_id));
		const ArrayRef built_buildings = _duplicate_array(state, get_or_new_array(state, town_template, key::starting_building_ids));
		Value authored_buildings;
		if (state.lookup(placement, str(key::built_buildings), authored_buildings) && gd::is_array(authored_buildings)) {
			for (const Value &building_id_value : gd::items(state, authored_buildings)) {
				const Atom building_id = gd::stringify(state, building_id_value);
				if (building_id != key::empty && !gd::array_has(state, built_buildings, str(building_id))) {
					state.append(built_buildings, str(building_id));
				}
			}
		}
		const DictRef town_state = state.new_dict();
		state.set(town_state, str(key::placement_id), str(ai::string_or_empty(state, placement, key::placement_id)));
		state.set(town_state, str(key::town_id), str(ai::string_or_empty(state, placement, key::town_id)));
		state.set(town_state, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(town_state, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		state.set(town_state, str(key::owner), str(text(state, placement, key::owner, key::neutral)));
		state.set(town_state, str(key::controlling_faction_id), str(ai::string_or_empty(state, placement, key::controlling_faction_id)));
		state.set(town_state, str(key::built_buildings), array_value(built_buildings));
		state.set(town_state, str(key::available_recruits), dict_value(state.new_dict()));
		state.set(town_state, str(key::garrison), array_value(_duplicate_array(state, get_or_new_array(state, town_template, key::garrison))));
		state.set(town_state, str(key::recovery), dict_value(_duplicate_dict(state, get_or_new_dict(state, placement, key::recovery))));
		state.set(town_state, str(key::front), dict_value(_duplicate_dict(state, get_or_new_dict(state, placement, key::front))));
		state.set(town_state, str(key::occupation), dict_value(_duplicate_dict(state, get_or_new_dict(state, placement, key::occupation))));
		state.set(town_state, str(key::last_build_day), int_value(imax(0, gd::int_field(state, placement, key::last_build_day, 0))));
		town_development_rules::migrate_town(state, town_state);
		state.set(town_state, str(key::available_recruits), dict_value(_seed_recruits_for_town_state(state, town_state)));
		state.append(towns, dict_value(town_state));
	}
	return towns;
}

ArrayRef _build_resource_states(State &state, const Value &placements) {
	const ArrayRef nodes = state.new_array();
	if (!gd::is_array(placements)) {
		return nodes;
	}
	for (const Value &placement_value : gd::items(state, placements)) {
		if (!gd::is_dict(placement_value)) {
			continue;
		}
		const DictRef placement = placement_value.ref;
		const DictRef node = state.new_dict();
		state.set(node, str(key::placement_id), str(ai::string_or_empty(state, placement, key::placement_id)));
		state.set(node, str(key::site_id), str(ai::string_or_empty(state, placement, key::site_id)));
		state.set(node, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(node, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		state.set(node, str(key::collected), bool_value(gd::bool_field(state, placement, key::collected, false)));
		state.set(node, str(key::collected_by_faction_id), str(ai::string_or_empty(state, placement, key::collected_by_faction_id)));
		state.set(node, str(key::collected_day), int_value(imax(0, gd::int_field(state, placement, key::collected_day, 0))));
		state.set(node, str(key::response_origin), str(ai::string_or_empty(state, placement, key::response_origin)));
		state.set(node, str(key::response_source_town_id), str(ai::string_or_empty(state, placement, key::response_source_town_id)));
		state.set(node, str(key::response_last_day), int_value(imax(0, gd::int_field(state, placement, key::response_last_day, 0))));
		state.set(node, str(key::response_until_day), int_value(imax(0, gd::int_field(state, placement, key::response_until_day, 0))));
		_copy_resource_runtime_metadata(state, node, placement);
		state.append(nodes, dict_value(node));
	}
	return nodes;
}

void _copy_resource_runtime_metadata(State &state, DictRef target, DictRef source) {
	for (const Atom field : kResourceRuntimeMetadataKeys) {
		if (state.has(source, str(field))) {
			const Value value = gd::index(state, source, str(field));
			state.set(target, str(field), gd::is_array(value) || gd::is_dict(value) ? gd::duplicate_value(state, value, true) : value);
		}
	}
}

DictRef _duplicate_dict(State &state, const Value &value) {
	return gd::is_dict(value) ? gd::deep_duplicate_dict(state, value.ref) : state.new_dict();
}

} // namespace scenario_factory

} // namespace aurelion::rules::port
