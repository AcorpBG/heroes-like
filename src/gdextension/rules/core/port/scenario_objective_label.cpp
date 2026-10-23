// ScenarioRules for the human seat's arrival (Phase 7, slice 7.2): an
// objective's label with its progress (_objective_label).

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/scenario_rules_turn.hpp"
#include "aurelion_rules/port/scenario_script_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port {

// Declared only in scenario_evaluation.cpp, which defines it.
namespace generated_scenario_objective_rules {
gd::DictRef progress(state::State &state, gd::DictRef session);
} // namespace generated_scenario_objective_rules

namespace {

using gd::Atom;
using gd::DictRef;
using gd::int_value;
using gd::str;
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

// String(row.get(first, row.get(second, fallback))).
Atom text_or_other(State &state, DictRef dict, Atom first, Atom second, Atom fallback) {
	const Value inner = state.get(dict, str(second), str(fallback));
	return string_of(state, state.get(dict, str(first), inner));
}

// int(d.get(field, fallback)).
int64_t int_of(State &state, DictRef dict, Atom field, int64_t fallback) {
	return gd::int_field(state, dict, field, fallback);
}

// bool(d.get(field, false)).
bool flag_of(State &state, DictRef dict, Atom field) {
	return gd::bool_field(state, dict, field, false);
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

// "%s (%s)" % [base_label, detail].
Atom with_detail(State &state, Atom base_label, Atom detail) {
	return gd::format(state, key::phrase_with_steps_text, {str(base_label), str(detail)});
}

// "%s (... unavailable)" % base_label and the like.
Atom with_pattern(State &state, Atom pattern, Atom base_label) {
	return gd::format(state, pattern, {str(base_label)});
}

// The not-ready rows of a requirement progress (hero army, town garrison):
// "; need %s" % missing_summary if missing_summary != "" else "".
Atom need_suffix(State &state, DictRef progress) {
	std::vector<Atom> missing_parts;
	int64_t missing_count = 0;
	for (const Value &row : gd::field_items(state, progress, str(key::requirements))) {
		if (!gd::is_dict(row) || flag_of(state, row.ref, key::met)) {
			continue;
		}
		missing_count = gd::add(missing_count, 1);
		if (missing_parts.size() < 2) {
			missing_parts.push_back(gd::format(state, key::s_d_d_3, {
				str(text_or_other(state, row.ref, key::unit_name, key::unit_id, key::Unit)),
				int_value(int_of(state, row.ref, key::current_count, 0)),
				int_value(int_of(state, row.ref, key::minimum_count, 0)),
			}));
		}
	}
	Atom missing_summary = join_atoms(state, key::comma_space, missing_parts);
	const int64_t shown = static_cast<int64_t>(missing_parts.size());
	if (missing_count > shown) {
		const Atom more = gd::format(state, key::d_more, {int_value(gd::sub(missing_count, shown))});
		missing_summary = state.intern(state.text(missing_summary) + state.text(more));
	}
	return missing_summary != key::empty ? gd::format(state, key::need_s, {str(missing_summary)}) : static_cast<Atom>(key::empty);
}

// "%s (%d/%d ready%s)" % [base_label, ready_count, requirement_count, need_suffix].
Atom ready_label(State &state, Atom base_label, int64_t ready_count, int64_t requirement_count, DictRef progress) {
	return gd::format(state, key::s_d_d_ready_s, {str(base_label), int_value(ready_count), int_value(requirement_count), str(need_suffix(state, progress))});
}

} // namespace

namespace scenario_rules {

Atom _objective_label(State &state, DictRef session, DictRef objective) {
	const Value id_fallback = state.get(objective, str(key::id), str(key::Objective));
	const Atom base_label = text_or(state, objective, key::label, id_fallback);
	const Atom type = text_or(state, objective, key::type, str(key::empty));
	if (type == key::defeat_generated_rivals) {
		const DictRef progress = generated_scenario_objective_rules::progress(state, session);
		if (!flag_of(state, progress, key::known)) {
			return with_pattern(state, key::s_player_ownership_unavailable, base_label);
		}
		return gd::format(state, key::s_d_d_rivals_defeated, {
			str(base_label),
			int_value(gd::to_int(state, gd::index(state, progress, str(key::defeated)))),
			int_value(gd::to_int(state, gd::index(state, progress, str(key::total)))),
		});
	}
	if (type == key::artifact_owned_by_player) {
		const bool owned = _player_owns_artifact(state, session, text_or(state, objective, key::artifact_id, str(key::empty)));
		return with_detail(state, base_label, owned ? static_cast<Atom>(key::Recovered) : static_cast<Atom>(key::Missing));
	}
	if (type == key::hero_artifact_set_equipped) {
		const DictRef set_progress = _artifact_set_equipment_progress(state, session, objective);
		if (!flag_of(state, set_progress, key::hero_found)) {
			return with_pattern(state, key::s_commander_unavailable, base_label);
		}
		return gd::format(state, key::s_d_d_regalia_pieces_equipped, {
			str(base_label),
			int_value(int_of(state, set_progress, key::equipped_piece_count, 0)),
			int_value(int_of(state, set_progress, key::piece_count, 0)),
			str(flag_of(state, set_progress, key::complete) ? static_cast<Atom>(key::set_active) : static_cast<Atom>(key::empty)),
		});
	}
	if (type == key::spell_known_by_player) {
		const bool known = _player_knows_spell(state, session, text_or(state, objective, key::spell_id, str(key::empty)));
		return with_detail(state, base_label, known ? static_cast<Atom>(key::Learned) : static_cast<Atom>(key::Unknown));
	}
	if (type == key::building_built_in_player_town) {
		const DictRef building_town = _find_town(state, session, objective);
		const Atom building_id = text_or(state, objective, key::building_id, str(key::empty));
		const bool completed = !gd::is_empty(state, building_town)
				&& text_or(state, building_town, key::owner, str(key::neutral)) == key::player
				&& _town_has_objective_building(state, building_town, building_id);
		return with_detail(state, base_label, completed ? static_cast<Atom>(key::Built) : static_cast<Atom>(key::Unbuilt));
	}
	if (type == key::hero_stationed_at_player_town) {
		const DictRef stationing = _hero_stationing_progress(state, session, objective);
		if (!flag_of(state, stationing, key::hero_found)) {
			return with_pattern(state, key::s_commander_unavailable, base_label);
		}
		if (!flag_of(state, stationing, key::town_found)) {
			return with_pattern(state, key::s_town_unavailable, base_label);
		}
		if (!flag_of(state, stationing, key::town_controlled)) {
			return with_pattern(state, key::s_town_uncontrolled, base_label);
		}
		return with_detail(state, base_label, flag_of(state, stationing, key::position_matches) ? static_cast<Atom>(key::Stationed) : static_cast<Atom>(key::en_route));
	}
	if (type == key::reserve_delivery_completed) {
		const DictRef delivery = _reserve_delivery_progress(state, session, objective);
		if (!flag_of(state, delivery, key::relay_found)) {
			return with_pattern(state, key::s_relay_unavailable, base_label);
		}
		return gd::format(state, key::s_d_d_delivered, {
			str(base_label),
			int_value(int_of(state, delivery, key::completed_count, 0)),
			int_value(int_of(state, delivery, key::minimum_count, 1)),
		});
	}
	if (type == key::map_explored_at_least) {
		const DictRef exploration = _map_exploration_progress(state, session, objective);
		return gd::format(state, key::s_d_d_charted, {
			str(base_label),
			int_value(int_of(state, exploration, key::explored_percent, 0)),
			int_value(int_of(state, exploration, key::minimum_percent, 1)),
		});
	}
	if (type == key::resource_stockpile_at_least) {
		const DictRef stockpile = _resource_stockpile_progress(state, session, objective);
		std::vector<Atom> stockpile_parts;
		for (const Value &row : gd::field_items(state, stockpile, str(key::requirements))) {
			if (gd::is_dict(row)) {
				stockpile_parts.push_back(gd::format(state, key::s_d_d_3, {
					str(text_or_other(state, row.ref, key::resource_name, key::resource_id, key::Resource)),
					int_value(int_of(state, row.ref, key::current_count, 0)),
					int_value(int_of(state, row.ref, key::minimum_count, 0)),
				}));
			}
		}
		return with_detail(state, base_label, join_atoms(state, key::comma_space, stockpile_parts));
	}
	if (type == key::resource_sites_controlled_at_least) {
		const DictRef site_control = _resource_site_control_progress(state, session, objective);
		return gd::format(state, key::s_d_d_controlled, {
			str(base_label),
			int_value(int_of(state, site_control, key::controlled_count, 0)),
			int_value(int_of(state, site_control, key::minimum_count, 1)),
		});
	}
	if (type == key::hero_army_meets_requirements) {
		const DictRef progress = _hero_army_requirement_progress(state, session, objective);
		if (!flag_of(state, progress, key::hero_found)) {
			return with_pattern(state, key::s_commander_unavailable, base_label);
		}
		const int64_t ready_count = int_of(state, progress, key::ready_count, 0);
		const int64_t requirement_count = int_of(state, progress, key::requirement_count, 0);
		if (flag_of(state, progress, key::complete)) {
			return gd::format(state, key::s_d_d_companies_ready, {str(base_label), int_value(ready_count), int_value(requirement_count)});
		}
		return ready_label(state, base_label, ready_count, requirement_count, progress);
	}
	if (type == key::town_garrison_meets_requirements) {
		const DictRef progress = _town_garrison_requirement_progress(state, session, objective);
		if (!flag_of(state, progress, key::town_found)) {
			return with_pattern(state, key::s_garrison_unavailable, base_label);
		}
		if (!flag_of(state, progress, key::town_controlled)) {
			return with_pattern(state, key::s_town_uncontrolled, base_label);
		}
		const int64_t ready_count = int_of(state, progress, key::ready_count, 0);
		const int64_t requirement_count = int_of(state, progress, key::requirement_count, 0);
		if (flag_of(state, progress, key::complete)) {
			return gd::format(state, key::s_d_d_garrison_companies_ready, {str(base_label), int_value(ready_count), int_value(requirement_count)});
		}
		return ready_label(state, base_label, ready_count, requirement_count, progress);
	}
	if (type == key::hero_progression_meets_requirements) {
		const DictRef progress = _hero_progression_requirement_progress(state, session, objective);
		if (!flag_of(state, progress, key::hero_found)) {
			return with_pattern(state, key::s_commander_unavailable, base_label);
		}
		const Atom level_text = gd::format(state, key::lv_d_d, {
			int_value(int_of(state, progress, key::current_level, 1)),
			int_value(int_of(state, progress, key::minimum_level, 1)),
		});
		const Atom choice_text = gd::format(state, key::d_d_choices, {
			int_value(int_of(state, progress, key::resolved_choice_count, 0)),
			int_value(int_of(state, progress, key::minimum_resolved_choice_count, 0)),
		});
		const int64_t pending_count = int_of(state, progress, key::pending_choice_count, 0);
		if (flag_of(state, progress, key::complete)) {
			return gd::format(state, key::s_s_s_resolved, {str(base_label), str(level_text), str(choice_text)});
		}
		if (flag_of(state, progress, key::require_no_pending_choices) && pending_count > 0) {
			return gd::format(state, key::s_s_s_d_pending, {str(base_label), str(level_text), str(choice_text), int_value(pending_count)});
		}
		return gd::format(state, key::s_s_s_10, {str(base_label), str(level_text), str(choice_text)});
	}
	if (type == key::enemy_pressure_at_least) {
		const int64_t pressure = enemy_turn_rules::get_pressure(state, session, text_or(state, objective, key::faction_id, str(key::empty)));
		return gd::format(state, key::s_d_d_4, {str(base_label), int_value(pressure), int_value(int_of(state, objective, key::threshold, 0))});
	}
	if (type == key::encounter_resolved) {
		const bool cleared = scenario_script_rules::_encounter_resolved(state, session, text_or(state, objective, key::placement_id, str(key::empty)));
		return with_detail(state, base_label, cleared ? static_cast<Atom>(key::Cleared) : static_cast<Atom>(key::Active));
	}
	if (type == key::hook_fired) {
		const bool fired = scenario_script_rules::_hook_fired(state, session, text_or(state, objective, key::hook_id, str(key::empty)));
		return with_detail(state, base_label, fired ? static_cast<Atom>(key::Triggered) : static_cast<Atom>(key::Pending));
	}
	if (type == key::town_owned_by_player || type == key::town_not_owned_by_player) {
		const DictRef town = _find_town(state, session, objective);
		if (!gd::is_empty(state, town)) {
			return with_detail(state, base_label, gd::capitalize(state, text_or(state, town, key::owner, str(key::neutral))));
		}
		return base_label;
	}
	if (type == key::session_flag_equals) {
		const DictRef flags = gd::as_dict(gd::index(state, session, str(key::flags)));
		const Atom flag = text_or(state, objective, key::flag, str(key::empty));
		return with_detail(state, base_label, text_or(state, flags, flag, str(key::unset)));
	}
	return base_label;
}

} // namespace scenario_rules

} // namespace aurelion::rules::port
