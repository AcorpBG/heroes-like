// ScenarioRules for the panels (Phase 7, slice 7.8): objectives, their labels
// and the opening and first-contact summaries.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/scenario_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace aurelion::rules::port {

// Declared only in scenario_evaluation.cpp, which defines it.
namespace scenario_rules {
bool _objective_met(state::State &state, gd::DictRef session, gd::DictRef objective);
} // namespace scenario_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

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
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return string_of(state, state.get(dict, str(field), fallback));
}

// session.<field> of SessionData's String fields.
Atom session_text(State &state, DictRef session, Atom field) {
	return gd::to_string(gd::index(state, session, str(field)));
}

// separator.join(parts) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts, size_t count) {
	std::string joined;
	for (size_t index = 0; index < count && index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// separator.join(array): each item as String(item).
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::vector<Atom> atoms;
	for (const Value &part : gd::items(state, array_value(parts))) {
		atoms.push_back(string_of(state, part));
	}
	return join_atoms(state, separator, atoms, atoms.size());
}

bool has_atom(const std::vector<Atom> &atoms, Atom atom) {
	return std::find(atoms.begin(), atoms.end(), atom) != atoms.end();
}

// The name of the content row a placement names, or the placement id.
Atom row_name(State &state, ContentTable table, DictRef placement, Atom id_field, Atom placement_id) {
	const DictRef row = gd::content_row(state, table, text_or(state, placement, id_field, str(key::empty)));
	return text_or(state, row, key::name, str(placement_id));
}

} // namespace

namespace scenario_rules {

bool is_objective_met(State &state, DictRef session, Atom objective_id, Atom bucket) {
	const DictRef objective = get_objective(state, session, objective_id, bucket);
	return !gd::is_empty(state, objective) && _objective_met(state, session, objective);
}

DictRef get_objective(State &state, DictRef session, Atom objective_id, Atom bucket) {
	// session == null cannot happen: a session is its view.
	if (session_text(state, session, key::scenario_id) == key::empty || objective_id == key::empty) {
		return state.new_dict();
	}
	const DictRef scenario = scenario_record_for_session(state, session);
	const Value objectives = objective_definitions(state, scenario);
	if (!gd::is_dict(objectives)) {
		return state.new_dict();
	}

	std::vector<Atom> buckets;
	if (bucket == key::victory || bucket == key::defeat) {
		buckets.push_back(bucket);
	} else {
		buckets.push_back(key::victory);
		buckets.push_back(key::defeat);
	}
	for (const Atom bucket_name : buckets) {
		for (const Value &objective : gd::field_items(state, objectives.ref, str(bucket_name))) {
			if (gd::is_dict(objective) && text_or(state, objective.ref, key::id, str(key::empty)) == objective_id) {
				return objective.ref;
			}
		}
	}
	return state.new_dict();
}

Atom describe_objectives(State &state, DictRef session) {
	normalize_scenario_state(state, session, true);
	const DictRef scenario = scenario_record_for_session(state, session);
	const Value objectives = objective_definitions(state, scenario);
	if (!gd::is_dict(objectives)) {
		return key::no_authored_objectives;
	}

	std::vector<Atom> lines;
	lines.push_back(key::Victory);
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::victory))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom marker = _objective_marker(state, true, _objective_met(state, session, objective.ref));
		const Atom label = _objective_label(state, session, objective.ref);
		lines.push_back(gd::format(state, key::s_s, { str(marker), str(label) }));
	}

	lines.push_back(key::avoid_defeat);
	for (const Value &objective : gd::field_items(state, objectives.ref, str(key::defeat))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom marker = _objective_marker(state, false, _objective_met(state, session, objective.ref));
		const Atom label = _objective_label(state, session, objective.ref);
		lines.push_back(gd::format(state, key::s_s, { str(marker), str(label) }));
	}

	if (session_text(state, session, key::scenario_status) != key::in_progress && session_text(state, session, key::scenario_summary) != key::empty) {
		lines.push_back(gd::format(state, key::outcome_s, { str(session_text(state, session, key::scenario_summary)) }));
	}

	return join_atoms(state, key::newline, lines, lines.size());
}

ArrayRef _enemy_operational_lines(State &state, DictRef session, DictRef scenario) {
	(void)session;
	const ArrayRef lines = state.new_array();
	for (const Value &config : gd::field_items(state, scenario, str(key::enemy_factions))) {
		if (!gd::is_dict(config)) {
			continue;
		}
		const Atom faction_id = text_or(state, config.ref, key::faction_id, str(key::empty));
		Atom label = text_or(state, config.ref, key::label, str(key::empty));
		if (label == key::empty) {
			label = text_or(state, gd::content_row(state, ContentTable::Faction, faction_id), key::name, str(faction_id));
		}
		// Computer players field heroes and build towns under the same rules.
		const Atom strategy_summary = enemy_adventure_rules::public_strategy_summary(state, config.ref, faction_id);
		Atom line = gd::format(state, key::enemy_posture_s_heroes_and_towns, { str(label) });
		if (strategy_summary != key::empty) {
			line = gd::format(state, key::s_s_text, { str(line), str(strategy_summary) });
		}
		const ArrayRef priority_labels = _priority_target_labels(state, scenario, config.ref);
		if (state.array_size(priority_labels) > 0) {
			line = gd::format(state, key::s_focus_s, { str(line), str(join_array(state, key::comma_space, priority_labels)) });
		}
		state.append(lines, str(line));
	}
	return lines;
}

Atom _opening_objective_summary(State &state, DictRef session, DictRef scenario) {
	const Value objectives = objective_definitions(state, scenario);
	if (!gd::is_dict(objectives)) {
		return key::empty;
	}
	std::vector<Atom> lines;
	const ArrayRef victory_labels = _objective_labels_from_bucket(state, session, state.get(objectives.ref, str(key::victory), array_value(state.new_array())), 3);
	if (state.array_size(victory_labels) > 0) {
		lines.push_back(gd::format(state, key::opening_objectives_s, { str(join_array(state, key::semicolon_space, victory_labels)) }));
	}
	const ArrayRef defeat_labels = _objective_labels_from_bucket(state, session, state.get(objectives.ref, str(key::defeat), array_value(state.new_array())), 2);
	if (state.array_size(defeat_labels) > 0) {
		lines.push_back(gd::format(state, key::failure_watch_s, { str(join_array(state, key::semicolon_space, defeat_labels)) }));
	}
	return join_atoms(state, key::newline, lines, lines.size());
}

Atom _first_contact_summary(State &state, DictRef scenario) {
	const ArrayRef contacts = _nearest_encounter_placements(state, scenario, 3);
	if (state.array_size(contacts) == 0) {
		return key::empty;
	}
	std::vector<Atom> labels;
	std::vector<Atom> tag_labels;
	std::vector<Atom> trait_labels;
	for (const Value &placement : gd::items(state, array_value(contacts))) {
		if (!gd::is_dict(placement)) {
			continue;
		}
		const DictRef encounter = gd::content_row(state, ContentTable::Encounter, text_or(state, placement.ref, key::encounter_id, str(key::empty)));
		if (gd::is_empty(state, encounter)) {
			continue;
		}
		const Value name_fallback = state.get(placement.ref, str(key::encounter_id), str(key::hostile_contact));
		const Atom encounter_name = text_or(state, encounter, key::name, name_fallback);
		const Atom terrain = _terrain_label(state, text_or(state, encounter, key::terrain, str(key::grass)));
		labels.push_back(gd::format(state, key::s_on_s, { str(encounter_name), str(terrain) }));
		for (const Value &tag_value : gd::field_items(state, encounter, str(key::battlefield_tags))) {
			const Atom tag_label = _titleize_token(state, string_of(state, tag_value));
			if (tag_label != key::empty && !has_atom(tag_labels, tag_label)) {
				tag_labels.push_back(tag_label);
			}
		}
		// encounter.get("enemy_commander", {}).get("battle_traits", []).
		Value commander;
		if (state.lookup(encounter, str(key::enemy_commander), commander)) {
			for (const Value &trait_value : gd::items(state, ai::vget(state, commander, key::battle_traits, array_value(state.new_array())))) {
				const Atom trait_label = _titleize_token(state, string_of(state, trait_value));
				if (trait_label != key::empty && !has_atom(trait_labels, trait_label)) {
					trait_labels.push_back(trait_label);
				}
			}
		}
	}
	std::vector<Atom> lines;
	if (!labels.empty()) {
		lines.push_back(gd::format(state, key::likely_first_contact_s, { str(join_atoms(state, key::comma_space, labels, labels.size())) }));
	}
	if (!tag_labels.empty()) {
		const size_t count = std::min<size_t>(4, tag_labels.size());
		lines.push_back(gd::format(state, key::battlefield_identity_s, { str(join_atoms(state, key::comma_space, tag_labels, count)) }));
	}
	if (!trait_labels.empty()) {
		const size_t count = std::min<size_t>(4, trait_labels.size());
		lines.push_back(gd::format(state, key::enemy_doctrine_s, { str(join_atoms(state, key::comma_space, trait_labels, count)) }));
	}
	return join_atoms(state, key::newline, lines, lines.size());
}

ArrayRef _objective_labels_from_bucket(State &state, DictRef session, const Value &bucket, int64_t limit) {
	const ArrayRef labels = state.new_array();
	if (!gd::is_array(bucket)) {
		return labels;
	}
	for (const Value &objective : gd::items(state, bucket)) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom label = _objective_label(state, session, objective.ref);
		if (label != key::empty && !gd::array_has(state, labels, str(label))) {
			state.append(labels, str(label));
		}
		if (state.array_size(labels) >= limit) {
			break;
		}
	}
	return labels;
}

ArrayRef _nearest_encounter_placements(State &state, DictRef scenario, int64_t limit) {
	const DictRef start = gd::as_dict(state.get(scenario, str(key::start), dict_value(state.new_dict())));
	const int64_t start_x = gd::to_int(state, state.get(start, str(key::x), int_value(0)));
	const int64_t start_y = gd::to_int(state, state.get(start, str(key::y), int_value(0)));
	const ArrayRef placements = state.new_array();
	for (const Value &placement : gd::field_items(state, scenario, str(key::encounters))) {
		if (!gd::is_dict(placement)) {
			continue;
		}
		const DictRef entry = gd::as_dict(gd::engine_duplicate(state, placement, true));
		const int64_t dx = compat::absi(gd::sub(gd::to_int(state, state.get(entry, str(key::x), int_value(0))), start_x));
		const int64_t dy = compat::absi(gd::sub(gd::to_int(state, state.get(entry, str(key::y), int_value(0))), start_y));
		state.set(entry, str(key::distance), int_value(gd::add(dx, dy)));
		state.append(placements, dict_value(entry));
	}
	gd::sort_custom(state, placements, [&](const Value &a, const Value &b) {
		return gd::to_int(state, ai::vget(state, a, key::distance, int_value(9999))) < gd::to_int(state, ai::vget(state, b, key::distance, int_value(9999)));
	});
	if (state.array_size(placements) <= limit) {
		return placements;
	}
	return gd::slice(state, placements, 0, limit);
}

ArrayRef _priority_target_labels(State &state, DictRef scenario, DictRef config) {
	const ArrayRef labels = state.new_array();
	Value targets;
	if (!state.lookup(config, str(key::priority_target_placement_ids), targets)) {
		// The [] fallback is an Array with nothing in it.
		return labels;
	}
	if (!gd::is_array(targets)) {
		return labels;
	}
	for (const Value &placement_id_value : gd::items(state, targets)) {
		const Atom label = _placement_label_for_scenario(state, scenario, string_of(state, placement_id_value));
		if (label != key::empty && !gd::array_has(state, labels, str(label))) {
			state.append(labels, str(label));
		}
		if (state.array_size(labels) >= 3) {
			break;
		}
	}
	return labels;
}

Atom _placement_label_for_scenario(State &state, DictRef scenario, Atom placement_id) {
	if (placement_id == key::empty) {
		return key::empty;
	}
	for (const Value &town : gd::field_items(state, scenario, str(key::towns))) {
		if (gd::is_dict(town) && text_or(state, town.ref, key::placement_id, str(key::empty)) == placement_id) {
			return row_name(state, ContentTable::Town, town.ref, key::town_id, placement_id);
		}
	}
	for (const Value &node : gd::field_items(state, scenario, str(key::resource_nodes))) {
		if (gd::is_dict(node) && text_or(state, node.ref, key::placement_id, str(key::empty)) == placement_id) {
			return row_name(state, ContentTable::ResourceSite, node.ref, key::site_id, placement_id);
		}
	}
	for (const Value &node : gd::field_items(state, scenario, str(key::artifact_nodes))) {
		if (gd::is_dict(node) && text_or(state, node.ref, key::placement_id, str(key::empty)) == placement_id) {
			return row_name(state, ContentTable::Artifact, node.ref, key::artifact_id, placement_id);
		}
	}
	for (const Value &encounter : gd::field_items(state, scenario, str(key::encounters))) {
		if (gd::is_dict(encounter) && text_or(state, encounter.ref, key::placement_id, str(key::empty)) == placement_id) {
			return row_name(state, ContentTable::Encounter, encounter.ref, key::encounter_id, placement_id);
		}
	}
	return _titleize_token(state, placement_id);
}

Atom _terrain_label(State &state, Atom terrain_id) {
	const DictRef biome = gd::content_row(state, ContentTable::BiomeForTerrain, terrain_id);
	if (!gd::is_empty(state, biome)) {
		// The fallback is evaluated first, as GDScript evaluates the argument.
		const Atom titled = _titleize_token(state, terrain_id);
		return text_or(state, biome, key::name, str(titled));
	}
	return terrain_id != key::empty ? _titleize_token(state, terrain_id) : static_cast<Atom>(key::unknown_terrain);
}

Atom _objective_marker(State &state, bool is_victory, bool met) {
	(void)state;
	if (is_victory) {
		return met ? static_cast<Atom>(key::x_2) : static_cast<Atom>(key::text_6);
	}
	return met ? static_cast<Atom>(key::text_7) : static_cast<Atom>(key::text_6);
}

} // namespace scenario_rules

} // namespace aurelion::rules::port
