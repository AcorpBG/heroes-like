// OverworldRules for the human seat's arrival (Phase 7, slice 7.2): the
// encounter's texts (readability, battle cue, consequences, guard links, risk).

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::PackedRef;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace ow = overworld_rules;

// OverworldRules.ENCOUNTER_ARMY_DETAIL_GROUP_LIMIT.
constexpr size_t kEncounterArmyDetailGroupLimit = 4;

// String(x): stringify(), and the engine's for a float, a container or an object.
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

// String(d.get(name, fallback)).
Atom text_of(State &state, DictRef dict, Atom name, Atom fallback = key::empty) {
	return string_of(state, state.get(dict, str(name), str(fallback)));
}

// String(d.get(name, "")).strip_edges().
Atom stripped(State &state, DictRef dict, Atom name) {
	return gd::strip_edges(state, text_of(state, dict, name));
}

// String(encounter.get("encounter_id", encounter.get("id", ""))).
Atom encounter_def_id(State &state, DictRef encounter) {
	const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
	return string_of(state, state.get(encounter, str(key::encounter_id), id_fallback));
}

// d.get(name, {}) passed on: the value, or a new Dictionary when missing.
Value field_or_new_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// What `for x in d.get(name, [])` visits, copied: the loop's body makes calls
// that may reach the engine.
std::vector<Value> field_items_of(State &state, DictRef dict, Atom name) {
	const gd::Items listed = gd::field_items(state, dict, str(name));
	return std::vector<Value>(listed.begin(), listed.end());
}

// separator.join(strings) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &strings) {
	std::string joined;
	for (size_t index = 0; index < strings.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(strings[index]);
	}
	return state.intern(joined);
}

// separator.join(strings) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef strings) {
	std::vector<Atom> parts;
	const int64_t count = state.array_size(strings);
	for (int64_t index = 0; index < count; ++index) {
		parts.push_back(gd::to_string(state.at(strings, index)));
	}
	return join_atoms(state, separator, parts);
}

// s.strip_edges() of UTF-8 text: the bytes up to 32 at both ends.
std::string strip_text(const std::string &text) {
	size_t begin = 0;
	size_t end = text.size();
	while (begin < end && static_cast<unsigned char>(text[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(text[end - 1]) <= 32) {
		--end;
	}
	return text.substr(begin, end - begin);
}

// word.left(1).to_upper() + word.substr(1).to_lower() of a word with a
// character outside ASCII: the engine's (String::to_upper, to_lower and their
// Unicode case tables), through an Expression parsed once per call.
Atom engine_title_word(State &state, Atom word, Value &expression) {
	if (expression.kind == Kind::Nil) {
		expression = gd::class_instantiate(state, key::Expression);
		const PackedRef names = gd::new_strings(state);
		gd::packed_append_string(state, names, key::text);
		gd::call_method(state, expression, key::parse, {str(key::text_left_1_to_upper_text), gd::strings_value(names)});
	}
	const ArrayRef inputs = state.new_array();
	state.append(inputs, str(word));
	return gd::to_string(gd::call_method(state, expression, key::execute, {array_value(inputs)}));
}

// OverworldRules._encounter_guard_target_label(session, guard) with the session
// a view or Nil: _encounter_guard_summary(encounter) passes a null one.
Atom guard_target_label(State &state, const Value &session, DictRef guard) {
	const Atom target_kind = stripped(state, guard, key::target_kind);
	const Atom target_placement_id = stripped(state, guard, key::target_placement_id);
	const Atom target_id = stripped(state, guard, key::target_id);
	if (target_kind == key::resource_node) {
		if (session.kind != Kind::Nil && target_placement_id != key::empty) {
			const DictRef node_result = ow::_find_resource_node_by_placement(state, gd::as_dict(session), target_placement_id);
			// var node: Dictionary = node_result.get("node", {})
			Value node_value;
			if (state.lookup(node_result, str(key::node), node_value)) {
				const DictRef node = gd::as_dict(node_value);
				if (!gd::is_empty(state, node)) {
					const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_of(state, node, key::site_id));
					return text_of(state, site, key::name, target_placement_id);
				}
			}
		}
		if (target_id != key::empty) {
			const DictRef site_by_id = gd::content_row(state, ContentTable::ResourceSite, target_id);
			if (!gd::is_empty(state, site_by_id)) {
				return text_of(state, site_by_id, key::name, target_id);
			}
		}
	}
	if (target_kind == key::artifact_node) {
		return ow::_humanize_id(state, target_placement_id != key::empty ? target_placement_id : target_id);
	}
	if (target_kind == key::town) {
		if (session.kind != Kind::Nil && target_placement_id != key::empty) {
			const DictRef town_result = ow::_find_town_by_placement(state, gd::as_dict(session), target_placement_id);
			// var town: Dictionary = town_result.get("town", {})
			Value town_value;
			if (state.lookup(town_result, str(key::town), town_value)) {
				const DictRef town = gd::as_dict(town_value);
				if (!gd::is_empty(state, town)) {
					return ow::_town_name(state, town);
				}
			}
		}
		return ow::_humanize_id(state, target_placement_id != key::empty ? target_placement_id : target_id);
	}
	if (target_kind == key::route) {
		return ow::_humanize_id(state, target_id != key::empty ? target_id : target_placement_id);
	}
	if (target_placement_id != key::empty) {
		return ow::_humanize_id(state, target_placement_id);
	}
	if (target_id != key::empty) {
		return ow::_humanize_id(state, target_id);
	}
	return key::empty;
}

} // namespace

namespace overworld_rules {

Atom describe_encounter_compact_readability(State &state, DictRef session, DictRef encounter) {
	const Atom reward_summary = _encounter_reward_surface(state, encounter);
	const ArrayRef parts = state.new_array();
	state.append(parts, str(_encounter_risk_label(state, encounter)));
	state.append(parts, str(_encounter_difficulty_label(state, encounter)));
	state.append(parts, str(_encounter_army_surface(state, encounter, false)));
	state.append(parts, str(_encounter_readiness_surface(state, session, encounter, true)));
	state.append(parts, str(reward_summary == key::empty ? static_cast<Atom>(key::empty) : gd::format(state, key::reward_s, {str(reward_summary)})));
	const Atom guard_line = _encounter_guard_summary(state, encounter, dict_value(session));
	if (guard_line != key::empty) {
		state.append(parts, str(guard_line));
	}
	const Atom consequence_line = describe_encounter_consequence_surface(state, session, encounter, true);
	if (consequence_line != key::empty) {
		state.append(parts, str(consequence_line));
	}
	return join_array(state, key::space_bar_space, _non_empty_strings(state, parts));
}

Atom describe_encounter_battle_cue(State &state, DictRef session, DictRef encounter) {
	const ArrayRef cue_parts = state.new_array();
	state.append(cue_parts, str(_encounter_risk_label(state, encounter)));
	state.append(cue_parts, str(_encounter_difficulty_label(state, encounter)));
	state.append(cue_parts, str(_encounter_army_surface(state, encounter, false)));
	state.append(cue_parts, str(_encounter_readiness_surface(state, session, encounter, true)));
	const Atom guard_line = _encounter_guard_summary(state, encounter, dict_value(session));
	if (guard_line != key::empty) {
		state.append(cue_parts, str(guard_line));
	}
	const Atom consequence_line = describe_encounter_consequence_surface(state, session, encounter, true);
	if (consequence_line != key::empty) {
		state.append(cue_parts, str(consequence_line));
	}
	const Atom cue = join_array(state, key::space_bar_space, _non_empty_strings(state, cue_parts));
	if (cue == key::empty) {
		return gd::format(state, key::battle_is_joined_against_s, {str(encounter_display_name(state, encounter))});
	}
	return gd::format(state, key::battle_is_joined_against_s_s, {str(encounter_display_name(state, encounter)), str(cue)});
}

Atom describe_encounter_consequence_surface(State &state, DictRef session, DictRef encounter, bool compact) {
	std::vector<Atom> lines;
	const Atom guard_consequence = _encounter_guard_consequence_line(state, session, encounter, compact);
	if (guard_consequence != key::empty) {
		lines.push_back(guard_consequence);
	}
	const Atom objective_consequence = _encounter_objective_consequence_line(state, session, encounter);
	if (objective_consequence != key::empty) {
		lines.push_back(objective_consequence);
	}
	const Atom hook_consequence = _encounter_hook_consequence_line(state, session, encounter);
	if (hook_consequence != key::empty) {
		lines.push_back(hook_consequence);
	}
	const size_t limit = compact ? 2 : 3;
	const ArrayRef visible = state.new_array();
	for (size_t index = 0; index < std::min(limit, lines.size()); ++index) {
		state.append(visible, str(lines[index]));
	}
	return join_array(state, key::space_bar_space, _non_empty_strings(state, visible));
}

DictRef _encounter_guard_link(State &state, DictRef encounter) {
	Value guard;
	if (state.lookup(encounter, str(key::guard_link), guard) && gd::is_dict(guard) && !gd::is_empty(state, guard.ref)) {
		return guard.ref;
	}
	// encounter.get("neutral_encounter", {}): a missing one is an empty
	// Dictionary, whose get("guard_link", {}) answers a new {}.
	Value neutral_metadata;
	if (!state.lookup(encounter, str(key::neutral_encounter), neutral_metadata)) {
		return state.new_dict();
	}
	if (gd::is_dict(neutral_metadata)) {
		if (!state.lookup(neutral_metadata.ref, str(key::guard_link), guard)) {
			return state.new_dict();
		}
		if (gd::is_dict(guard)) {
			return guard.ref;
		}
	}
	return state.new_dict();
}

Atom _encounter_guard_summary(State &state, DictRef encounter, const Value &session) {
	const DictRef guard = _encounter_guard_link(state, encounter);
	const Atom role = stripped(state, guard, key::guard_role);
	if (role == key::empty || role == key::none) {
		return key::empty;
	}
	const Atom target_label = guard_target_label(state, session, guard);
	if (target_label != key::empty) {
		return gd::format(state, key::guard_s_for_s, {str(_humanize_id(state, role)), str(target_label)});
	}
	return gd::format(state, key::guard_s, {str(_humanize_id(state, role))});
}

Atom _encounter_readiness_surface(State &state, DictRef session, DictRef encounter, bool compact) {
	// `if session == null`: a view is never null.
	const DictRef enemy_totals = _army_totals(state, _encounter_army_payload(state, encounter));
	const DictRef overworld = session_view::overworld(state, session);
	// session.overworld.get("hero", {}): a missing hero is an empty Dictionary.
	Value hero_value;
	const bool has_hero = state.lookup(overworld, str(key::hero), hero_value);
	if (has_hero && !gd::is_dict(hero_value)) {
		return key::empty;
	}
	// hero.get("army", session.overworld.get("army", {})).
	Value player_army_value;
	const bool hero_army = has_hero && state.lookup(hero_value.ref, str(key::army), player_army_value);
	if (!hero_army && !state.lookup(overworld, str(key::army), player_army_value)) {
		player_army_value = dict_value(state.new_dict());
	}
	if (!gd::is_dict(player_army_value)) {
		return key::empty;
	}
	const DictRef player_totals = _army_totals(state, player_army_value.ref);
	const int64_t player_headcount = gd::int_field(state, player_totals, key::headcount, 0);
	const int64_t enemy_headcount = gd::int_field(state, enemy_totals, key::headcount, 0);
	if (player_headcount <= 0 || enemy_headcount <= 0) {
		return key::empty;
	}
	Atom relation = key::even_contact;
	if (enemy_headcount >= gd::mul(player_headcount, 2)) {
		relation = key::enemy_outnumbers;
	} else if (player_headcount >= gd::mul(enemy_headcount, 2)) {
		relation = key::you_outnumber;
	} else if (enemy_headcount > player_headcount) {
		relation = key::enemy_larger;
	} else if (player_headcount > enemy_headcount) {
		relation = key::you_larger;
	}
	if (compact) {
		return gd::format(state, key::ready_d_vs_d_troops_s, {int_value(player_headcount), int_value(enemy_headcount), str(relation)});
	}
	return gd::format(state, key::readiness_your_army_d_troops_d, {
		int_value(player_headcount),
		int_value(gd::int_field(state, player_totals, key::groups, 0)),
		int_value(enemy_headcount),
		int_value(gd::int_field(state, enemy_totals, key::groups, 0)),
		str(relation),
	});
}

Atom _encounter_guard_consequence_line(State &state, DictRef session, DictRef encounter, bool compact) {
	const DictRef guard = _encounter_guard_link(state, encounter);
	if (gd::is_empty(state, guard)) {
		return key::empty;
	}
	const Atom role = stripped(state, guard, key::guard_role);
	if (role == key::empty || role == key::none) {
		return key::empty;
	}
	Atom target_label = _encounter_guard_target_label(state, dict_value(session), guard);
	const Atom target_kind = stripped(state, guard, key::target_kind);
	if (target_kind == key::route) {
		const Atom route_label = target_label != key::empty ? target_label : static_cast<Atom>(key::this_route);
		return compact ? gd::format(state, key::clear_opens_s_route, {str(route_label)}) : gd::format(state, key::clear_opens_the_s_route_for, {str(route_label)});
	}
	if (target_kind == key::resource_node) {
		if (target_label == key::empty) {
			target_label = key::linked_site;
		}
		Atom value_line = key::empty;
		// `if session != null`: a view is never null.
		const DictRef node_result = _find_resource_node_by_guard(state, guard, session);
		// var node: Dictionary = node_result.get("node", {})
		Value node_value;
		if (state.lookup(node_result, str(key::node), node_value)) {
			const DictRef node = gd::as_dict(node_value);
			if (!gd::is_empty(state, node)) {
				const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
				value_line = _resource_site_yield_line(state, session, node, site);
			}
		}
		if (value_line != key::empty) {
			return gd::format(state, key::clear_access_s_s, {str(target_label), str(value_line)});
		}
		return gd::format(state, key::clear_access_s, {str(target_label)});
	}
	if (target_label != key::empty) {
		const Atom verb = gd::bool_field(state, guard, key::clear_required_for_target, false) ? key::access : key::reach;
		return gd::format(state, key::clear_s_s, {str(verb), str(target_label)});
	}
	return key::empty;
}

Atom _encounter_objective_consequence_line(State &state, DictRef session, DictRef encounter) {
	const ArrayRef objectives = _encounter_clear_objectives(state, session, encounter);
	if (state.array_size(objectives) == 0) {
		return key::empty;
	}
	std::vector<Atom> labels;
	const int64_t count = state.array_size(objectives);
	for (int64_t index = 0; index < count; ++index) {
		const Value objective = state.at(objectives, index);
		if (!gd::is_dict(objective)) {
			continue;
		}
		Atom label = stripped(state, objective.ref, key::label);
		// `and session != null`: a view is never null.
		if (label == key::empty) {
			label = _scenario_objective_player_label(state, session, objective.ref);
		}
		if (label != key::empty) {
			labels.push_back(label);
		}
		if (labels.size() >= 2) {
			break;
		}
	}
	if (labels.empty()) {
		return key::empty;
	}
	return gd::format(state, key::clear_advances_s, {str(join_atoms(state, key::semicolon_space, labels))});
}

Atom _encounter_hook_consequence_line(State &state, DictRef session, DictRef encounter) {
	// `session == null`: a view is never null.
	const Atom scenario_id = gd::to_string(gd::field(state, session, key::scenario_id));
	if (scenario_id == key::empty) {
		return key::empty;
	}
	const ArrayRef objective_ids = _encounter_clear_objective_ids(state, session, encounter);
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, scenario_id);
	std::vector<Atom> summaries;
	for (const Value &hook : field_items_of(state, scenario, key::script_hooks)) {
		if (!gd::is_dict(hook)) {
			continue;
		}
		if (!_hook_follows_encounter_clear(state, hook.ref, encounter, objective_ids)) {
			continue;
		}
		Value effects;
		if (!state.lookup(hook.ref, str(key::effects), effects)) {
			effects = array_value(state.new_array());
		}
		const Atom effect_summary = _script_hook_effect_consequence_summary(state, effects);
		if (effect_summary != key::empty) {
			summaries.push_back(effect_summary);
		}
		if (summaries.size() >= 2) {
			break;
		}
	}
	if (summaries.empty()) {
		return key::empty;
	}
	return gd::format(state, key::after_clear_s, {str(join_atoms(state, key::semicolon_space, summaries))});
}

ArrayRef _encounter_clear_objectives(State &state, DictRef session, DictRef encounter) {
	const ArrayRef objectives = state.new_array();
	// `session == null`: a view is never null.
	if (gd::to_string(gd::field(state, session, key::scenario_id)) == key::empty) {
		return objectives;
	}
	const Atom placement_id = encounter_key(state, encounter);
	const DictRef encounter_def = gd::content_row(state, ContentTable::Encounter, encounter_def_id(state, encounter));
	// _string_array(encounter_def.get("victory_flags", [])): a missing field
	// (null here) gives the same empty list.
	const ArrayRef victory_flags = _string_array(state, gd::field(state, encounter_def, key::victory_flags));
	// The GDScript's unused `scenario` (ContentService.get_scenario_readonly) is
	// a read only: left out.
	const Value objective_bucket = scenario_rules::objectives_for_session(state, session);
	if (!gd::is_dict(objective_bucket)) {
		return objectives;
	}
	const Atom bucket_names[] = {key::victory, key::defeat};
	for (const Atom bucket_name : bucket_names) {
		for (const Value &objective : field_items_of(state, objective_bucket.ref, bucket_name)) {
			if (!gd::is_dict(objective)) {
				continue;
			}
			const Atom objective_type = text_of(state, objective.ref, key::type);
			bool linked = objective_type == key::encounter_resolved && text_of(state, objective.ref, key::placement_id) == placement_id;
			linked = linked || (objective_type == key::flag_true && gd::array_has(state, victory_flags, str(text_of(state, objective.ref, key::flag))));
			if (linked) {
				state.append(objectives, objective);
			}
		}
	}
	return objectives;
}

ArrayRef _encounter_clear_objective_ids(State &state, DictRef session, DictRef encounter) {
	const ArrayRef ids = gd::new_typed_array(state, state::variant_type::STRING);
	const ArrayRef objectives = _encounter_clear_objectives(state, session, encounter);
	const int64_t count = state.array_size(objectives);
	for (int64_t index = 0; index < count; ++index) {
		const Value objective = state.at(objectives, index);
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom objective_id = stripped(state, objective.ref, key::id);
		if (objective_id != key::empty && !gd::array_has(state, ids, str(objective_id))) {
			state.append(ids, str(objective_id));
		}
	}
	return ids;
}

bool _hook_follows_encounter_clear(State &state, DictRef hook, DictRef encounter, ArrayRef objective_ids) {
	const Atom placement_id = encounter_key(state, encounter);
	for (const Value &condition : field_items_of(state, hook, key::conditions)) {
		if (!gd::is_dict(condition)) {
			continue;
		}
		const Atom condition_type = text_of(state, condition.ref, key::type);
		if (condition_type == key::encounter_resolved) {
			if (text_of(state, condition.ref, key::placement_id) == placement_id) {
				return true;
			}
		} else if (condition_type == key::objective_met) {
			if (gd::array_has(state, objective_ids, str(text_of(state, condition.ref, key::objective_id)))) {
				return true;
			}
		}
	}
	return false;
}

Atom _script_hook_effect_consequence_summary(State &state, const Value &effects) {
	if (!gd::is_array(effects)) {
		return key::empty;
	}
	const ArrayRef parts = state.new_array();
	Atom fallback_message = key::empty;
	const gd::Items listed = gd::items(state, effects);
	const std::vector<Value> effect_list(listed.begin(), listed.end());
	for (const Value &effect : effect_list) {
		if (!gd::is_dict(effect)) {
			continue;
		}
		const Atom effect_type = text_of(state, effect.ref, key::type);
		if (effect_type == key::spawn_resource_node) {
			const Value resource_placement = field_or_new_dict(state, effect.ref, key::placement);
			if (gd::is_dict(resource_placement)) {
				const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_of(state, resource_placement.ref, key::site_id));
				state.append(parts, str(gd::format(state, key::reveals_s, {str(text_of(state, site, key::name, key::supplies))})));
			}
		} else if (effect_type == key::spawn_artifact_node) {
			const Value artifact_placement = field_or_new_dict(state, effect.ref, key::placement);
			if (gd::is_dict(artifact_placement)) {
				const Atom artifact_name = artifact_rules::artifact_name(state, text_of(state, artifact_placement.ref, key::artifact_id));
				state.append(parts, str(gd::format(state, key::reveals_s, {str(artifact_name)})));
			}
		} else if (effect_type == key::award_experience) {
			const int64_t amount = gd::int_field(state, effect.ref, key::amount, 0);
			if (amount > 0) {
				state.append(parts, str(gd::format(state, key::d_xp_2, {int_value(amount)})));
			}
		} else if (effect_type == key::add_resources) {
			const Atom resources = _describe_reward_delta(state, field_or_new_dict(state, effect.ref, key::resources));
			if (resources != key::empty) {
				state.append(parts, str(gd::format(state, key::s_2, {str(resources)})));
			}
		} else if (effect_type == key::town_add_recruits) {
			state.append(parts, str(key::reinforces_a_town));
		} else if (effect_type == key::town_add_building) {
			const DictRef building = gd::content_row(state, ContentTable::Building, text_of(state, effect.ref, key::building_id));
			state.append(parts, str(gd::format(state, key::unlocks_s, {str(text_of(state, building, key::name, key::town_support_2))})));
		} else if (effect_type == key::spawn_encounter) {
			state.append(parts, str(key::may_draw_a_counterforce));
		} else if (effect_type == key::message) {
			if (fallback_message == key::empty) {
				fallback_message = _short_player_text(state, text_of(state, effect.ref, key::text), 96);
			}
		}
		if (state.array_size(parts) >= 2) {
			break;
		}
	}
	if (state.array_size(parts) == 0 && fallback_message != key::empty) {
		state.append(parts, str(fallback_message));
	}
	return join_array(state, key::comma_space, _non_empty_strings(state, parts));
}

Atom _encounter_risk_label(State &state, DictRef encounter) {
	const DictRef metadata = _encounter_neutral_metadata(state, encounter);
	// metadata.get("reward_guard_summary", {}): a missing one has no risk_tier.
	Value reward_guard;
	if (state.lookup(metadata, str(key::reward_guard_summary), reward_guard) && gd::is_dict(reward_guard)) {
		const Atom risk = stripped(state, reward_guard.ref, key::risk_tier);
		if (risk != key::empty) {
			return gd::format(state, key::risk_s, {str(_humanize_id(state, risk))});
		}
	}
	const Atom difficulty = stripped(state, encounter, key::difficulty);
	if (difficulty == key::low) {
		return key::risk_light;
	}
	if (difficulty == key::medium || difficulty == key::normal) {
		return key::risk_standard;
	}
	if (difficulty == key::high) {
		return key::risk_heavy;
	}
	if (difficulty == key::scripted) {
		return key::risk_scripted;
	}
	return key::empty;
}

Atom _encounter_difficulty_label(State &state, DictRef encounter) {
	Atom difficulty = stripped(state, encounter, key::difficulty);
	if (difficulty == key::empty) {
		// encounter.get("encounter_ref", {}): a missing one has no difficulty.
		Value encounter_ref;
		if (state.lookup(encounter, str(key::encounter_ref), encounter_ref) && gd::is_dict(encounter_ref)) {
			difficulty = stripped(state, encounter_ref.ref, key::difficulty);
		}
	}
	if (difficulty == key::empty) {
		return key::empty;
	}
	return gd::format(state, key::difficulty_s, {str(_humanize_id(state, difficulty))});
}

Atom _encounter_army_surface(State &state, DictRef encounter, bool include_units) {
	const DictRef army = _encounter_army_payload(state, encounter);
	if (gd::is_empty(state, army)) {
		return key::empty;
	}
	const DictRef totals = _army_totals(state, army);
	const ArrayRef parts = state.new_array();
	const Atom army_name = stripped(state, army, key::name);
	if (army_name != key::empty) {
		state.append(parts, str(army_name));
	}
	state.append(parts, str(gd::format(state, key::d_troops_d_groups, {int_value(gd::int_field(state, totals, key::headcount, 0)), int_value(gd::int_field(state, totals, key::groups, 0))})));
	if (include_units) {
		const Atom unit_summary = _encounter_army_unit_summary(state, army);
		if (unit_summary != key::empty) {
			state.append(parts, str(unit_summary));
		}
	}
	return join_array(state, key::space_bar_space, _non_empty_strings(state, parts));
}

DictRef _encounter_army_payload(State &state, DictRef encounter) {
	const DictRef encounter_def = gd::content_row(state, ContentTable::Encounter, encounter_def_id(state, encounter));
	DictRef army = gd::content_row(state, ContentTable::ArmyGroup, text_of(state, encounter_def, key::enemy_group_id));
	// placement_army.get("stacks", []) if placement_army is Dictionary else []:
	// only a non-empty Array of stacks takes the placement's army.
	Value placement_army;
	if (state.lookup(encounter, str(key::enemy_army), placement_army) && gd::is_dict(placement_army)) {
		Value placement_stacks;
		if (state.lookup(placement_army.ref, str(key::stacks), placement_stacks) && gd::is_array(placement_stacks) && state.array_size(placement_stacks.ref) != 0) {
			army = placement_army.ref;
		}
	}
	return army;
}

Atom _encounter_army_unit_summary(State &state, DictRef army) {
	std::vector<Atom> labels;
	for (const Value &stack : field_items_of(state, army, key::stacks)) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const int64_t count = gd::int_field(state, stack.ref, key::count, 0);
		if (count <= 0) {
			continue;
		}
		const Atom unit_id = text_of(state, stack.ref, key::unit_id);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		labels.push_back(gd::format(state, key::s_x_d, {str(text_of(state, unit, key::name, unit_id)), int_value(count)}));
		if (labels.size() >= kEncounterArmyDetailGroupLimit) {
			break;
		}
	}
	const int64_t total_groups = gd::int_field(state, _army_totals(state, army), key::groups, 0);
	const int64_t label_count = static_cast<int64_t>(labels.size());
	if (total_groups > label_count) {
		const int64_t more = gd::sub(total_groups, label_count);
		labels.push_back(gd::format(state, key::d_group_s, {int_value(more), str(more == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s))}));
	}
	return join_atoms(state, key::comma_space, labels);
}

Atom _encounter_reward_surface(State &state, DictRef encounter) {
	const DictRef encounter_def = gd::content_row(state, ContentTable::Encounter, encounter_def_id(state, encounter));
	// encounter.get("enemy_commander_state", encounter_def.get("enemy_commander", {})).
	Value commander;
	if (!state.lookup(encounter, str(key::enemy_commander_state), commander) && !state.lookup(encounter_def, str(key::enemy_commander), commander)) {
		commander = dict_value(state.new_dict());
	}
	// _encounter_army_payload(encounter).get("stacks", []).
	const DictRef army = _encounter_army_payload(state, encounter);
	Value stacks;
	if (!state.lookup(army, str(key::stacks), stacks)) {
		stacks = array_value(state.new_array());
	}
	const DictRef rewards = battle_rules::battle_rewards_for_strength(state, encounter_def, stacks, commander);
	const Atom reward_summary = _describe_reward_delta(state, dict_value(rewards));
	if (reward_summary != key::empty) {
		return reward_summary;
	}
	const DictRef metadata = _encounter_neutral_metadata(state, encounter);
	// metadata.get("reward_guard_summary", {}): a missing one has no categories.
	Value reward_guard;
	if (state.lookup(metadata, str(key::reward_guard_summary), reward_guard) && gd::is_dict(reward_guard)) {
		std::vector<Atom> categories;
		// _string_array(reward_guard.get("reward_categories", [])): a missing
		// field (null here) gives the same empty list.
		const ArrayRef category_ids = _string_array(state, gd::field(state, reward_guard.ref, key::reward_categories));
		const int64_t count = state.array_size(category_ids);
		for (int64_t index = 0; index < count; ++index) {
			categories.push_back(_humanize_id(state, gd::to_string(state.at(category_ids, index))));
		}
		if (!categories.empty()) {
			return gd::format(state, key::categories_s, {str(join_atoms(state, key::comma_space, categories))});
		}
	}
	return key::empty;
}

Atom _encounter_guard_target_label(State &state, const Value &session, DictRef guard) {
	return guard_target_label(state, session, guard);
}

ArrayRef _non_empty_strings(State &state, ArrayRef value) {
	const ArrayRef strings = gd::new_typed_array(state, state::variant_type::STRING);
	const int64_t count = state.array_size(value);
	for (int64_t index = 0; index < count; ++index) {
		const Atom text = gd::strip_edges(state, string_of(state, state.at(value, index)));
		if (text != key::empty) {
			state.append(strings, str(text));
		}
	}
	return strings;
}

Atom _humanize_id(State &state, Atom value) {
	std::string normalized = strip_text(state.text(value));
	for (char &c : normalized) {
		if (c == '_' || c == '-') {
			c = ' ';
		}
	}
	if (normalized.empty()) {
		return key::empty;
	}
	std::string joined;
	bool first = true;
	Value expression;
	// normalized.split(" ", false): the pieces between spaces, empty ones dropped.
	size_t at = 0;
	while (at <= normalized.size()) {
		size_t end = normalized.find(' ', at);
		if (end == std::string::npos) {
			end = normalized.size();
		}
		const std::string word = strip_text(normalized.substr(at, end - at));
		at = end + 1;
		if (word.empty()) {
			continue;
		}
		bool ascii = true;
		for (const char c : word) {
			if (static_cast<unsigned char>(c) >= 0x80) {
				ascii = false;
				break;
			}
		}
		std::string titled;
		if (ascii) {
			titled = word;
			if (titled[0] >= 'a' && titled[0] <= 'z') {
				titled[0] = static_cast<char>(titled[0] - 'a' + 'A');
			}
			for (size_t index = 1; index < titled.size(); ++index) {
				if (titled[index] >= 'A' && titled[index] <= 'Z') {
					titled[index] = static_cast<char>(titled[index] - 'A' + 'a');
				}
			}
		} else {
			titled = state.text(engine_title_word(state, state.intern(word), expression));
		}
		if (!first) {
			joined += ' ';
		}
		joined += titled;
		first = false;
	}
	return state.intern(joined);
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
