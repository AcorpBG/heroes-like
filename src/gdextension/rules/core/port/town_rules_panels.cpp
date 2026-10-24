// TownRules for the town panels (Phase 7, slice 7.8): the header, summary,
// production, outlook, defense, threats, buildings, recruitment and the other
// panel texts.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules_ai.hpp"
#include "aurelion_rules/port/town_rules.hpp"

#include <algorithm>
#include <cstddef>
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
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, gd::field_or(state, dict, field, fallback));
}

// d.get(field, {}) and d.get(field, []) of a value that may be passed on: the
// field, or a new container.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// What `for x in value` visits, copied: the loop bodies call other ports.
state::ValueList items_of(State &state, const Value &value) {
	return gd::items(state, value).list();
}

// What `for x in d.get(field, [])` visits, copied.
state::ValueList field_list(State &state, DictRef dict, Atom field) {
	return gd::field_items(state, dict, str(field)).list();
}

// int(d.get(field, {}).get(entry, 0)), read only.
int64_t nested_int(State &state, DictRef dict, Atom field, Atom entry) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return 0;
	}
	return gd::to_int(state, ai::vget(state, found, entry, int_value(0)));
}

// d.get(field, []) is Array and not d.get(field, []).is_empty(), read only:
// the Array in out.
bool nonempty_array_field(State &state, DictRef dict, Atom field, ArrayRef &out) {
	Value found;
	if (!state.lookup(dict, str(field), found) || !gd::is_array(found) || state.array_size(found.ref) == 0) {
		return false;
	}
	out = found.ref;
	return true;
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
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

// sep.join(values.slice(0, count)) of an Array: the Array becomes a
// PackedStringArray, each item as String() converts it.
Atom join_first(State &state, Atom separator, ArrayRef values, int64_t count) {
	std::string joined;
	const int64_t size = compat::engine_min<int64_t>(count, state.array_size(values));
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(gd::stringify(state, state.at(values, index)));
	}
	return state.intern(joined);
}

// sep.join(values) of an Array.
Atom join_array(State &state, Atom separator, ArrayRef values) {
	return join_first(state, separator, values, state.array_size(values));
}

// "" if count == 1 else suffix.
Atom plural(int64_t count, Atom suffix) {
	return count == 1 ? static_cast<Atom>(key::empty) : suffix;
}

// a.sort() of an Array of Strings.
void sort_strings(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

// s.to_lower() of the defense grades (ASCII).
Atom ascii_to_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

constexpr int64_t kEnemyHeroWatchRadius = 10;

} // namespace

namespace town_rules {

Atom faction_crest_icon_path(State &state, Atom faction_id) {
	const Atom normalized_faction_id = gd::strip_edges(state, faction_id);
	if (gd::is_empty(state, gd::content_row(state, ContentTable::Faction, normalized_faction_id))) {
		return key::empty;
	}
	const DictRef crest = gd::content_row(state, ContentTable::FactionCrest, normalized_faction_id);
	const Atom icon_path = gd::strip_edges(state, ai::string_or_empty(state, crest, key::icon_path));
	if (ai::string_or_empty(state, crest, key::id) != normalized_faction_id) {
		return key::empty;
	}
	if (ai::string_or_empty(state, crest, key::crest_id) != gd::format(state, key::faction_crest_s, {str(gd::trim_prefix(state, normalized_faction_id, key::faction_))})) {
		return key::empty;
	}
	if (!gd::begins_with(state, icon_path, key::res_art_factions_runtime_crests) || !gd::resource_exists(state, icon_path)) {
		return key::empty;
	}
	return icon_path;
}

Atom describe_status(State &state, DictRef session) {
	const Vector2i pos = overworld_rules::hero_position(state, session);
	const int64_t day = ai::session_int(state, session, key::day);
	const int64_t days_until_growth = overworld_rules::days_until_next_weekly_growth(state, day);
	const int64_t week = _week_of_day(state, day);
	const int64_t weekday = _weekday_of_day(state, day);
	Atom growth_clause = key::weekly_muster_refreshes_today;
	if (!overworld_rules::is_weekly_growth_day(state, day)) {
		growth_clause = gd::format(state, key::next_muster_day_d_in_d, {
				int_value(overworld_rules::next_weekly_growth_day(state, day)),
				int_value(days_until_growth),
				str(plural(days_until_growth, key::s)),
		});
	}
	return gd::format(state, key::week_d_day_d_field_pos, {
			int_value(week),
			int_value(weekday),
			int_value(pos.x),
			int_value(pos.y),
			str(growth_clause),
	});
}

Atom describe_header(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::no_town_is_under_command;
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const DictRef faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, town_template, key::faction_id));
	Atom role_label = key::empty;
	const Atom role = overworld_rules::town_strategic_role(state, town);
	if (role == key::capital) {
		role_label = key::capital_anchor_2;
	} else if (role == key::stronghold) {
		role_label = key::frontier_stronghold_2;
	}
	return gd::format(state, key::s_s_s_s_spell_tier, {
			str(text_field(state, town_template, key::name, gd::field_or(state, town, key::town_id, str(key::Town)))),
			str(text_field(state, faction, key::name, gd::field_or(state, town_template, key::faction_id, str(key::Faction)))),
			str(role_label),
			str(town_control_label(state, text_field(state, town, key::owner, str(key::neutral)))),
			int_value(current_spell_tier(state, town)),
	});
}

Atom town_control_label(State &state, Atom owner) {
	return overworld_rules::town_control_label(state, owner);
}

Atom describe_summary(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::no_active_town;
	}
	const Value session_value = dict_value(session);
	const Atom weekly_growth = _describe_recruit_delta(state, dict_value(overworld_rules::town_weekly_growth(state, town, session_value)));
	const int64_t reinforcement_quality = overworld_rules::town_reinforcement_quality(state, town, session_value);
	const int64_t battle_readiness = overworld_rules::town_battle_readiness(state, town, session_value);
	const int64_t pressure_output = overworld_rules::town_pressure_output(state, town, session_value);
	const Value built_buildings = field_or_new_array(state, town, key::built_buildings);
	const int64_t available_orders = state.array_size(get_build_actions(state, session));
	const int64_t locked_plans = _locked_building_count(state, town);
	const int64_t spell_tier = current_spell_tier(state, town);
	const int64_t day = ai::session_int(state, session, key::day);
	const int64_t days_until_growth = overworld_rules::days_until_next_weekly_growth(state, day);
	const DictRef capital_project = overworld_rules::town_capital_project_state(state, town, session_value);
	const DictRef battlefront = overworld_rules::town_battlefront_profile(state, town);
	const DictRef logistics = overworld_rules::town_logistics_state(state, session, town);
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	const DictRef front = overworld_rules::town_front_state(state, session, town, state.new_dict());
	const DictRef occupation = overworld_rules::town_occupation_state(state, session, town);
	const DictRef market = overworld_rules::town_market_state(state, town);
	std::vector<Atom> parts;
	parts.push_back(overworld_rules::describe_town_identity_surface(state, town, session_value));
	parts.push_back(overworld_rules::town_strategic_summary(state, town));
	parts.push_back(gd::format(state, key::battlefront_s, {str(text_field(state, battlefront, key::summary, str(key::the_defenders_will_meet_the_assault)))}));
	parts.push_back(gd::format(state, key::daily_income_s_spell_tier_d, {
			str(_describe_resources(state, dict_value(overworld_rules::town_income(state, town, session_value)), key::none)),
			int_value(spell_tier),
			int_value(gd::is_array(built_buildings) ? state.array_size(built_buildings.ref) : 0),
	}));
	parts.push_back(gd::format(state, key::next_weekly_muster_day_d_in, {
			int_value(overworld_rules::next_weekly_growth_day(state, day)),
			int_value(days_until_growth),
			str(plural(days_until_growth, key::s)),
			str(weekly_growth),
	}));
	parts.push_back(gd::format(state, key::s_d_reinforcement_s_battle_readiness, {
			str(_town_pressure_label(state, town)),
			int_value(pressure_output),
			str(_reinforcement_grade(state, reinforcement_quality)),
			int_value(battle_readiness),
	}));
	parts.push_back(gd::format(state, key::open_plans_d_deferred_plans_d, {
			int_value(available_orders),
			int_value(locked_plans),
			str(_describe_building_category_counts(state, built_buildings)),
	}));
	parts.push_back(gd::format(state, key::logistics_s_3, {str(_logistics_watch_summary(state, logistics))}));
	if (gd::bool_field(state, front, key::active, false)) {
		parts.push_back(gd::format(state, key::front_s, {str(ai::string_or_empty(state, front, key::summary))}));
	}
	if (gd::bool_field(state, occupation, key::active, false)) {
		parts.push_back(gd::format(state, key::occupation_s, {str(ai::string_or_empty(state, occupation, key::summary))}));
	}
	const Atom delivery_summary = _convoy_watch_summary(state, logistics);
	if (delivery_summary != key::empty) {
		parts.push_back(gd::format(state, key::convoys_s, {str(delivery_summary)}));
	}
	if (gd::bool_field(state, market, key::active, false)) {
		parts.push_back(gd::format(state, key::exchange_s_buy_wood_d_ore, {
				str(text_field(state, market, key::building_name, str(key::Market))),
				int_value(nested_int(state, market, key::buy_rates, key::wood)),
				int_value(nested_int(state, market, key::buy_rates, key::ore)),
				int_value(nested_int(state, market, key::sell_rates, key::wood)),
				int_value(nested_int(state, market, key::sell_rates, key::ore)),
		}));
	}
	if (gd::bool_field(state, recovery, key::active, false)) {
		parts.push_back(gd::format(state, key::recovery_s, {str(ai::string_or_empty(state, recovery, key::summary))}));
	} else {
		parts.push_back(gd::format(state, key::recovery_lines_steady_d_day_relief, {int_value(gd::int_field(state, recovery, key::relief_per_day, 1))}));
	}
	if (gd::bool_field(state, capital_project, key::active, false)) {
		Atom project_line = gd::format(state, key::capital_project_online_d_d_s, {
				int_value(gd::int_field(state, capital_project, key::progress_complete, 0)),
				int_value(gd::int_field(state, capital_project, key::progress_total, 0)),
				str(text_field(state, capital_project, key::summary, str(key::the_stronghold_is_driving_a_theater))),
		});
		const Atom support_summary = _project_support_summary(state, capital_project);
		if (support_summary != key::empty) {
			project_line = concat(state, project_line, gd::format(state, key::space_bar_space_s, {str(support_summary)}));
		}
		parts.push_back(project_line);
	} else if (gd::int_field(state, capital_project, key::total, 0) > 0) {
		parts.push_back(gd::format(state, key::capital_project_d_d_next_s, {
				int_value(gd::int_field(state, capital_project, key::progress_complete, 0)),
				int_value(gd::int_field(state, capital_project, key::progress_total, 0)),
				str(text_field(state, capital_project, key::next_label, str(key::final_anchor_works))),
				str(_project_support_summary(state, capital_project)),
		}));
	}
	return join_atoms(state, key::newline, parts);
}

Atom describe_production_overview(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::production_overview_no_active_town;
	}
	const Value session_value = dict_value(session);
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const DictRef faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, town_template, key::faction_id));
	const Value built_buildings = gd::field(state, town, key::built_buildings);
	// A missing field is [] there: 0 either way.
	const int64_t built_count = gd::is_array(built_buildings) ? state.array_size(built_buildings.ref) : 0;
	const ArrayRef build_actions = get_build_actions(state, session);
	const ArrayRef recruit_actions = get_recruit_actions(state, session);
	const DictRef weekly_growth = overworld_rules::town_weekly_growth(state, town, session_value);
	const int64_t ready_builds = _count_ready_actions(state, build_actions);
	const int64_t ready_recruits = _count_ready_actions(state, recruit_actions);
	Atom role = gd::capitalize(state, overworld_rules::town_strategic_role(state, town));
	if (role == key::empty) {
		role = key::Frontier;
	}
	std::vector<Atom> lines;
	lines.push_back(key::production_overview);
	lines.push_back(gd::format(state, key::owner_s_faction_s_s, {
			str(gd::capitalize(state, text_field(state, town, key::owner, str(key::neutral)))),
			str(text_field(state, faction, key::name, gd::field_or(state, town_template, key::faction_id, str(key::Faction)))),
			str(role),
	}));
	lines.push_back(gd::format(state, key::income_day_s_works_d_built, {
			str(_describe_resources(state, dict_value(overworld_rules::town_income(state, town, session_value)), key::none)),
			int_value(built_count),
			int_value(state.array_size(build_actions)),
			int_value(_locked_building_count(state, town)),
	}));
	lines.push_back(gd::format(state, key::muster_d_waiting_weekly_s_on, {
			int_value(_recruit_pool_total(state, field_or_new_dict(state, town, key::available_recruits))),
			str(_describe_recruit_delta(state, dict_value(weekly_growth))),
			int_value(overworld_rules::next_weekly_growth_day(state, ai::session_int(state, session, key::day))),
	}));
	lines.push_back(gd::format(state, key::ready_now_build_d_d_recruit, {
			int_value(ready_builds),
			int_value(state.array_size(build_actions)),
			int_value(ready_recruits),
			int_value(state.array_size(recruit_actions)),
			str(_next_town_action_line(state, session, town)),
	}));
	lines.push_back(gd::format(state, key::practical_priority_s, {str(_town_recommendation_line(state, session, town))}));
	return join_atoms(state, key::newline, lines);
}

Atom describe_outlook_board(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::defense_outlook_no_active_town;
	}
	const Value session_value = dict_value(session);
	const int64_t readiness = overworld_rules::town_battle_readiness(state, town, session_value);
	const int64_t reinforcement_quality = overworld_rules::town_reinforcement_quality(state, town, session_value);
	const int64_t pressure_output = overworld_rules::town_pressure_output(state, town, session_value);
	const DictRef logistics = overworld_rules::town_logistics_state(state, session, town);
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	const DictRef capital_project = overworld_rules::town_capital_project_state(state, town, session_value);
	const DictRef battlefront = overworld_rules::town_battlefront_profile(state, town);
	const DictRef threat_state = overworld_rules::town_public_threat_state(state, session, town);
	const DictRef front_state = overworld_rules::town_front_state(state, session, town, state.new_dict());
	const DictRef occupation_state = overworld_rules::town_occupation_state(state, session, town);
	const ArrayRef stationed = hero_command_rules::stationed_heroes(state, session, town);
	const int64_t reserve_count = _stationed_reserve_count(state, session, stationed);
	const ArrayRef response_actions = get_response_actions(state, session);
	const int64_t ready_response_count = _count_ready_actions(state, response_actions);
	const DictRef movement_state = _active_hero_movement_state(state, session);
	std::vector<Atom> lines;
	lines.push_back(key::defense_outlook);
	lines.push_back(gd::format(state, key::outlook_s_walls_s_readiness_d, {
			str(_town_outlook_grade(state, readiness, threat_state, front_state, occupation_state, logistics, recovery, capital_project, reserve_count, ready_response_count)),
			str(_defense_grade(state, town)),
			int_value(readiness),
			str(_reinforcement_grade(state, reinforcement_quality)),
			str(_town_pressure_label(state, town)),
			int_value(pressure_output),
	}));
	lines.push_back(gd::format(state, key::frontier_watch_s, {str(_town_frontier_outlook_line(state, town, threat_state, front_state, occupation_state, battlefront))}));
	lines.push_back(gd::format(state, key::dispatch_readiness_s, {str(_town_dispatch_readiness_line(state, state.array_size(response_actions), ready_response_count, movement_state, reserve_count))}));
	lines.push_back(gd::format(state, key::support_chain_s, {str(_town_support_watch_line(state, town, logistics, recovery, capital_project))}));
	return join_atoms(state, key::newline, lines);
}

Atom describe_command_ledger(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::order_ledger_no_active_town;
	}
	std::vector<Atom> lines;
	lines.push_back(key::order_ledger);
	lines.push_back(gd::format(state, key::construction_s, {str(_build_order_ledger_line(state, session, town))}));
	lines.push_back(gd::format(state, key::recruitment_s, {str(_recruit_order_ledger_line(state, session, town))}));
	lines.push_back(gd::format(state, key::response_s, {str(_response_order_ledger_line(state, session, town))}));
	lines.push_back(gd::format(state, key::coverage_s, {str(_coverage_order_ledger_line(state, session, town))}));
	return join_atoms(state, key::newline, lines);
}

Atom describe_defense(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	const Atom headline = _defense_headline_for_town(state, town);
	if (gd::is_empty(state, town)) {
		return headline;
	}
	const Value session_value = dict_value(session);
	const ArrayRef stationed = hero_command_rules::stationed_heroes(state, session, town);
	const DictRef active_hero = hero_command_rules::town_defending_hero(state, session, town, key::empty);
	const Atom active_hero_id = ai::string_or_empty(state, active_hero, key::id);
	std::vector<Atom> reserve_lines;
	for (const Value &hero : items_of(state, array_value(stationed))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		if (ai::string_or_empty(state, hero.ref, key::id) == active_hero_id) {
			continue;
		}
		reserve_lines.push_back(_hero_command_line(state, hero.ref));
	}
	std::vector<Atom> lines;
	lines.push_back(headline);
	lines.push_back(hero_command_rules::describe_town_defense_force(state, session, town));
	lines.push_back(gd::format(state, key::garrison_posture_s_d_companies_d, {
			str(_defense_grade(state, town)),
			int_value(_garrison_company_count(state, town)),
			int_value(_garrison_headcount(state, town)),
	}));
	lines.push_back(gd::format(state, key::battle_readiness_d_reinforcement_s, {
			int_value(overworld_rules::town_battle_readiness(state, town, session_value)),
			str(_reinforcement_grade(state, overworld_rules::town_reinforcement_quality(state, town, session_value))),
	}));
	lines.push_back(gd::format(state, key::defense_readiness_s_2, {str(overworld_rules::describe_town_defense_readiness_warning(state, session, town))}));
	lines.push_back(gd::format(state, key::garrison_s_2, {str(_describe_garrison(state, town))}));
	lines.push_back(gd::format(state, key::logistics_s_4, {str(_logistics_watch_summary(state, overworld_rules::town_logistics_state(state, session, town)))}));
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	if (gd::bool_field(state, recovery, key::active, false)) {
		lines.push_back(gd::format(state, key::recovery_s_2, {str(ai::string_or_empty(state, recovery, key::summary))}));
	}
	if (!gd::is_empty(state, active_hero)) {
		lines.push_back(gd::format(state, key::defending_commander_s, {str(_hero_command_line(state, active_hero))}));
	}
	if (reserve_lines.empty()) {
		lines.push_back(key::no_reserve_commander_is_stationed_the);
	} else {
		lines.push_back(gd::format(state, key::reserve_commanders_s, {str(join_atoms(state, key::semicolon_space, reserve_lines))}));
	}
	return join_atoms(state, key::newline, lines);
}

Atom describe_defense_headline(State &state, DictRef session) {
	return _defense_headline_for_town(state, get_active_town(state, session));
}

Atom _defense_headline_for_town(State &state, DictRef town) {
	return gd::is_empty(state, town) ? key::defense_unavailable : key::defense_posture;
}

Atom describe_threats(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::threat_watch_unavailable;
	}
	const Value session_value = dict_value(session);
	std::vector<Atom> lines;
	lines.push_back(key::frontier_watch);
	const ArrayRef threat_lines = _town_threat_lines(state, session, town);
	const DictRef capital_project = overworld_rules::town_capital_project_state(state, town, session_value);
	const DictRef battlefront = overworld_rules::town_battlefront_profile(state, town);
	const DictRef logistics = overworld_rules::town_logistics_state(state, session, town);
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	const DictRef front_state = overworld_rules::town_front_state(state, session, town, state.new_dict());
	const DictRef occupation_state = overworld_rules::town_occupation_state(state, session, town);
	if (state.array_size(threat_lines) == 0) {
		lines.push_back(gd::format(state, key::no_hostile_heroes_are_known_to, {str(_town_name(state, town))}));
		lines.push_back(gd::format(state, key::defense_readiness_s_2, {str(overworld_rules::describe_town_defense_readiness_warning(state, session, town))}));
		if (gd::bool_field(state, front_state, key::active, false)) {
			lines.push_back(gd::format(state, key::front_watch_s, {str(ai::string_or_empty(state, front_state, key::summary))}));
		}
		if (gd::bool_field(state, occupation_state, key::active, false)) {
			lines.push_back(gd::format(state, key::occupation_watch_s_2, {str(ai::string_or_empty(state, occupation_state, key::summary))}));
		}
		lines.push_back(gd::format(state, key::the_walls_hold_a_s_over, {str(ascii_to_lower(state, _defense_grade(state, town)))}));
		if (ai::string_or_empty(state, battlefront, key::summary) != key::empty) {
			lines.push_back(gd::format(state, key::siege_profile_s, {str(ai::string_or_empty(state, battlefront, key::summary))}));
		}
		lines.push_back(gd::format(state, key::logistics_chain_s, {str(_logistics_watch_summary(state, logistics))}));
		if (gd::bool_field(state, recovery, key::active, false)) {
			lines.push_back(gd::format(state, key::recovery_watch_s, {str(ai::string_or_empty(state, recovery, key::summary))}));
		}
		if (gd::int_field(state, capital_project, key::total, 0) > 0) {
			lines.push_back(gd::format(state, key::capital_watch_s, {str(_project_watch_summary(state, capital_project))}));
		}
		return join_atoms(state, key::newline, lines);
	}

	for (const Value &threat_line : items_of(state, array_value(threat_lines))) {
		lines.push_back(gd::format(state, key::dash_space_s, {threat_line}));
	}
	lines.push_back(gd::format(state, key::defense_readiness_s_2, {str(overworld_rules::describe_town_defense_readiness_warning(state, session, town))}));
	if (ai::string_or_empty(state, battlefront, key::summary) != key::empty) {
		lines.push_back(gd::format(state, key::siege_profile_s, {str(ai::string_or_empty(state, battlefront, key::summary))}));
	}
	lines.push_back(gd::format(state, key::logistics_chain_s, {str(_logistics_watch_summary(state, logistics))}));
	ArrayRef labels = 0;
	if (nonempty_array_field(state, logistics, key::disrupted_site_labels, labels)) {
		lines.push_back(gd::format(state, key::denied_routes_s_2, {str(join_array(state, key::comma_space, labels))}));
	}
	if (nonempty_array_field(state, logistics, key::threatened_site_labels, labels)) {
		lines.push_back(gd::format(state, key::threatened_routes_s_2, {str(join_array(state, key::comma_space, labels))}));
	}
	if (nonempty_array_field(state, logistics, key::response_site_labels, labels)) {
		lines.push_back(gd::format(state, key::active_route_orders_s, {str(join_array(state, key::comma_space, labels))}));
	}
	if (gd::bool_field(state, recovery, key::active, false)) {
		lines.push_back(gd::format(state, key::recovery_watch_s, {str(ai::string_or_empty(state, recovery, key::summary))}));
	}
	if (gd::bool_field(state, occupation_state, key::active, false)) {
		lines.push_back(gd::format(state, key::occupation_watch_s_2, {str(ai::string_or_empty(state, occupation_state, key::summary))}));
	}
	if (gd::int_field(state, capital_project, key::total, 0) > 0) {
		lines.push_back(gd::format(state, key::capital_watch_s, {str(_project_watch_summary(state, capital_project))}));
	}
	return join_atoms(state, key::newline, lines);
}

Atom describe_buildings(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::buildings_unavailable;
	}

	std::vector<Atom> built_lines;
	for (const Value &building_id_value : field_list(state, town, key::built_buildings)) {
		const Atom building_id = gd::stringify(state, building_id_value);
		if (building_id == key::empty) {
			continue;
		}
		built_lines.push_back(gd::format(state, key::dash_space_s, {str(_building_line(state, building_id, key::built, state.new_dict()))}));
	}

	std::vector<Atom> available_lines;
	for (const Value &action : items_of(state, array_value(get_build_actions(state, session)))) {
		if (!gd::is_dict(action)) {
			continue;
		}
		const Value fallback = gd::field_or(state, action.ref, key::summary, gd::field_or(state, action.ref, key::label, str(key::Build)));
		available_lines.push_back(gd::format(state, key::dash_space_s, {str(text_field(state, action.ref, key::ledger_line, fallback))}));
	}

	std::vector<Atom> locked_lines;
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const Value built_buildings = field_or_new_array(state, town, key::built_buildings);
	const int64_t day = ai::session_int(state, session, key::day);
	for (const Value &building_id_value : field_list(state, town_template, key::buildable_building_ids)) {
		const Atom building_id = gd::stringify(state, building_id_value);
		if (building_id == key::empty || gd::in(state, str(building_id), built_buildings)) {
			continue;
		}
		const DictRef build_status = overworld_rules::get_town_build_status(state, town, building_id, day);
		if (gd::bool_field(state, build_status, key::buildable, false)) {
			continue;
		}
		locked_lines.push_back(gd::format(state, key::dash_space_s, {str(_building_line(state, building_id, key::locked, build_status))}));
	}

	std::vector<Atom> parts;
	parts.push_back(key::construction_ledger);
	parts.push_back(gd::format(state, key::built_works_d_open_orders_d, {
			int_value(gd::is_array(built_buildings) ? state.array_size(built_buildings.ref) : 0),
			int_value(static_cast<int64_t>(available_lines.size())),
			int_value(static_cast<int64_t>(locked_lines.size())),
			str(_describe_building_category_counts(state, built_buildings)),
	}));
	parts.push_back(key::built_works);
	parts.push_back(!built_lines.empty() ? join_atoms(state, key::newline, built_lines) : static_cast<Atom>(key::no_permanent_works_yet));
	parts.push_back(key::open_orders);
	parts.push_back(!available_lines.empty() ? join_atoms(state, key::newline, available_lines) : static_cast<Atom>(key::no_open_construction_orders));
	if (!locked_lines.empty()) {
		parts.push_back(key::deferred_plans);
		parts.push_back(join_atoms(state, key::newline, locked_lines));
	}
	return join_atoms(state, key::newline, parts);
}

Atom describe_recruitment(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::recruitment_unavailable;
	}

	const Value session_value = dict_value(session);
	std::vector<Atom> lines;
	const Value recruits = field_or_new_dict(state, town, key::available_recruits);
	const DictRef weekly_growth = overworld_rules::town_weekly_growth(state, town, session_value);
	const int64_t day = ai::session_int(state, session, key::day);
	const int64_t days_until_growth = overworld_rules::days_until_next_weekly_growth(state, day);
	const Atom reinforcement_grade = _reinforcement_grade(state, overworld_rules::town_reinforcement_quality(state, town, session_value));
	const DictRef logistics = overworld_rules::town_logistics_state(state, session, town);
	const DictRef recovery = overworld_rules::town_recovery_state(state, session, town);
	const DictRef occupation = overworld_rules::town_occupation_state(state, session, town);
	for (const Value &unit_id_value : items_of(state, array_value(_town_unit_ids(state, town)))) {
		const Atom unit_id = gd::to_string(unit_id_value);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const int64_t unit_tier = gd::int_field(state, unit, key::tier, 0);
		const int64_t available = gd::to_int(state, ai::vget(state, recruits, unit_id_value, int_value(0)));
		const int64_t growth = gd::to_int(state, state.get(weekly_growth, unit_id_value, int_value(0)));
		if (_unit_is_unlocked_in_town(state, town, unit_id)) {
			const Atom growth_sources = _growth_source_summary(state, town, unit_id);
			const Atom reserve_label = available > 0 ? gd::format(state, key::x_d, {int_value(available)}) : static_cast<Atom>(key::reserve_empty);
			lines.push_back(gd::format(state, key::s_s_s_s_weekly_d, {
					str(_unit_tier_label(state, unit_tier)),
					str(text_field(state, unit, key::name, unit_id_value)),
					str(reserve_label),
					str(overworld_rules::describe_unit_recruit_brief(state, unit_id, available)),
					int_value(compat::engine_max<int64_t>(0, growth)),
					str(growth_sources != key::empty ? gd::format(state, key::via_s, {str(growth_sources)}) : static_cast<Atom>(key::empty)),
					str(_describe_resources(state, dict_value(overworld_rules::town_recruit_cost(state, session, town, unit_id)), key::none)),
			}));
			continue;
		}
		const Atom unlock_building_id = _unlock_building_for_unit(state, town, unit_id);
		const DictRef unlock_building = gd::content_row(state, ContentTable::Building, unlock_building_id);
		const DictRef build_status = overworld_rules::get_town_build_status(state, town, unlock_building_id, -1);
		const Atom build_hint = gd::format(state, key::build_s_3, {str(text_field(state, unlock_building, key::name, str(unlock_building_id)))});
		lines.push_back(gd::format(state, key::s_s_locked_s, {
				str(_unit_tier_label(state, unit_tier)),
				str(text_field(state, unit, key::name, unit_id_value)),
				str(text_field(state, build_status, key::blocked_message, str(build_hint))),
		}));
	}
	const int64_t next_day = overworld_rules::next_weekly_growth_day(state, day);
	const Atom convoys = _convoy_watch_summary(state, logistics);
	const Atom convoy_clause = convoys != key::empty ? gd::format(state, key::convoys_s_2, {str(convoys)}) : static_cast<Atom>(key::empty);
	const bool occupied = gd::bool_field(state, occupation, key::active, false);
	Atom body = key::empty;
	if (!lines.empty()) {
		Atom watch_clause = key::empty;
		if (occupied) {
			watch_clause = gd::format(state, key::occupation_s_2, {str(text_field(state, occupation, key::compact_summary, str(key::pacifying)))});
		} else if (gd::bool_field(state, recovery, key::active, false)) {
			watch_clause = gd::format(state, key::recovery_s_3, {str(ai::string_or_empty(state, recovery, key::summary))});
		}
		body = gd::format(state, key::reserve_quality_s_logistics_s_s, {
				str(reinforcement_grade),
				str(_logistics_watch_summary(state, logistics)),
				str(convoy_clause),
				str(watch_clause),
				str(join_atoms(state, key::newline, lines)),
		});
	} else {
		const Atom occupation_clause = occupied ? gd::format(state, key::occupation_s_2, {str(text_field(state, occupation, key::compact_summary, str(key::pacifying)))}) : static_cast<Atom>(key::empty);
		body = gd::format(state, key::reserve_quality_s_s_s_no, {
				str(reinforcement_grade),
				str(convoy_clause),
				str(occupation_clause),
		});
	}
	return gd::format(state, key::recruit_reserves_next_levy_day_d, {
			int_value(next_day),
			int_value(days_until_growth),
			str(plural(days_until_growth, key::s)),
			str(body),
	});
}

Atom describe_market(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::exchange_hall_no_active_town;
	}
	return overworld_rules::describe_town_market(state, session, town);
}

Atom describe_spell_access(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::spell_study_unavailable;
	}

	const int64_t tier = current_spell_tier(state, town);
	if (tier <= 0) {
		return key::spell_study_no_archive_halls_are;
	}

	std::vector<Atom> lines;
	const Value hero = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	for (const Value &spell_id_value : items_of(state, array_value(accessible_spell_ids(state, town)))) {
		const Atom spell_id = gd::to_string(spell_id_value);
		const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
		if (gd::is_empty(state, spell)) {
			continue;
		}
		const Atom status = spell_rules::knows_spell(state, gd::as_dict(hero), spell_id) ? key::Known : key::ready_to_learn;
		lines.push_back(gd::format(state, key::s_s_s_13, {
				str(status),
				str(spell_rules::spell_category_label(state, spell)),
				str(spell_rules::describe_spell_inspection_line(state, gd::as_dict(hero), spell, state.new_dict())),
		}));
	}
	return gd::format(state, key::spell_study_tier_d_archive_access, {
			int_value(tier),
			str(!lines.empty() ? join_atoms(state, key::newline, lines) : static_cast<Atom>(key::no_spell_leaves_are_catalogued_here)),
	});
}

Atom describe_artifacts(State &state, DictRef session) {
	return artifact_rules::describe_management(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
}

Atom describe_heroes(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::command_no_active_town;
	}
	const ArrayRef stationed = hero_command_rules::stationed_heroes(state, session, town);
	const Atom active_hero_id = ai::string_or_empty(state, session_view::overworld(state, session), key::active_hero_id);
	const state::ValueList heroes = items_of(state, array_value(stationed));
	std::vector<Atom> lines;
	lines.push_back(key::command_wing);
	bool active_found = false;
	for (const Value &hero : heroes) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		if (ai::string_or_empty(state, hero.ref, key::id) == active_hero_id) {
			lines.push_back(gd::format(state, key::gate_command_s, {str(_hero_command_line(state, hero.ref))}));
			active_found = true;
			break;
		}
	}
	if (!active_found) {
		lines.push_back(key::no_hero_is_currently_commanding_from);
	}
	for (const Value &hero : heroes) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		if (ai::string_or_empty(state, hero.ref, key::id) == active_hero_id) {
			continue;
		}
		lines.push_back(gd::format(state, key::stationed_reserve_s, {str(_hero_command_line(state, hero.ref))}));
	}
	if (lines.size() == 2 && !active_found) {
		lines.push_back(key::the_town_captain_will_anchor_the);
	} else if (lines.size() == 1) {
		lines.push_back(key::no_stationed_heroes);
	}
	return join_atoms(state, key::newline, lines);
}

Atom describe_specialties(State &state, DictRef session) {
	return hero_progression_rules::describe_specialties(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
}

Atom describe_tavern(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::wayfarers_hall_no_active_town;
	}
	return hero_command_rules::describe_tavern(state, session, town);
}

Atom describe_transfer(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::transfer_no_active_town;
	}
	return hero_command_rules::describe_town_transfer(state, session, town);
}

Atom describe_responses(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return key::strategic_response_no_active_town;
	}
	return overworld_rules::describe_town_response_panel(state, session, town);
}

DictRef _army_unit_counts(State &state, const Value &army) {
	const DictRef counts = state.new_dict();
	// army.get("stacks", []) if army is Dictionary else []: a missing field
	// or another army walks no stacks.
	Value stacks;
	if (!gd::is_dict(army) || !state.lookup(army.ref, str(key::stacks), stacks)) {
		return counts;
	}
	if (!gd::is_array(stacks)) {
		return counts;
	}
	for (const Value &stack : gd::items(state, stacks)) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const Atom unit_id = ai::string_or_empty(state, stack.ref, key::unit_id);
		if (unit_id == key::empty) {
			continue;
		}
		state.set(counts, str(unit_id), int_value(gd::add(gd::int_field(state, counts, unit_id, 0), compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0)))));
	}
	return counts;
}

DictRef _duplicate_dictionary(State &state, const Value &value) {
	return gd::is_dict(value) ? gd::as_dict(gd::engine_duplicate(state, value, true)) : state.new_dict();
}

ArrayRef _normalize_string_array(State &state, const Value &value) {
	const ArrayRef normalized = gd::new_typed_array(state, state::variant_type::STRING);
	if (!gd::is_array(value)) {
		return normalized;
	}
	for (const Value &entry : gd::items(state, value)) {
		const Atom text = gd::stringify(state, entry);
		if (text != key::empty) {
			state.append(normalized, str(text));
		}
	}
	return normalized;
}

int64_t _week_of_day(State &state, int64_t day) {
	(void)state;
	return gd::add(compat::float_to_int(compat::godot_floor(static_cast<double>(gd::sub(compat::engine_max<int64_t>(day, 1), 1)) / 7.0)), 1);
}

int64_t _weekday_of_day(State &state, int64_t day) {
	(void)state;
	return compat::int_mod(gd::sub(compat::engine_max<int64_t>(day, 1), 1), 7) + 1;
}

int64_t _locked_building_count(State &state, DictRef town) {
	int64_t locked_count = 0;
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const Value built_buildings = field_or_new_array(state, town, key::built_buildings);
	for (const Value &building_id_value : field_list(state, town_template, key::buildable_building_ids)) {
		const Atom building_id = gd::stringify(state, building_id_value);
		if (building_id == key::empty || gd::in(state, str(building_id), built_buildings)) {
			continue;
		}
		if (!gd::bool_field(state, overworld_rules::get_town_build_status(state, town, building_id, -1), key::buildable, false)) {
			locked_count += 1;
		}
	}
	return locked_count;
}

Atom _describe_building_category_counts(State &state, const Value &building_ids) {
	if (!gd::is_array(building_ids)) {
		return key::no_standing_works;
	}
	const DictRef counts = state.new_dict();
	for (const Value &building_id_value : items_of(state, building_ids)) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id_value));
		Atom category = text_field(state, building, key::category, str(key::support));
		if (category == key::empty) {
			category = key::support;
		}
		state.set(counts, str(category), int_value(gd::add(gd::int_field(state, counts, category, 0), 1)));
	}
	if (gd::is_empty(state, counts)) {
		return key::no_standing_works;
	}
	const ArrayRef categories = gd::keys(state, counts);
	sort_strings(state, categories);
	std::vector<Atom> parts;
	for (const Value &category_value : items_of(state, array_value(categories))) {
		const Atom category = gd::stringify(state, category_value);
		parts.push_back(gd::format(state, key::s_d_6, {str(gd::capitalize(state, category)), int_value(gd::int_field(state, counts, category, 0))}));
	}
	return join_atoms(state, key::comma_space, parts);
}

Atom _describe_garrison(State &state, DictRef town) {
	std::vector<Atom> lines;
	for (const Value &stack : field_list(state, town, key::garrison)) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		lines.push_back(overworld_rules::describe_stack_inspection_line(state, stack.ref, state.new_dict()));
	}
	return !lines.empty() ? join_atoms(state, key::semicolon_space, lines) : static_cast<Atom>(key::no_standing_garrison);
}

int64_t _garrison_company_count(State &state, DictRef town) {
	int64_t companies = 0;
	for (const Value &stack : gd::field_items(state, town, str(key::garrison))) {
		if (gd::is_dict(stack) && gd::int_field(state, stack.ref, key::count, 0) > 0) {
			companies += 1;
		}
	}
	return companies;
}

int64_t _garrison_headcount(State &state, DictRef town) {
	int64_t headcount = 0;
	for (const Value &stack : gd::field_items(state, town, str(key::garrison))) {
		if (gd::is_dict(stack)) {
			headcount = gd::add(headcount, compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0)));
		}
	}
	return headcount;
}

int64_t _garrison_strength(State &state, DictRef town) {
	int64_t total_strength = 0;
	for (const Value &stack : field_list(state, town, key::garrison)) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, ai::string_or_empty(state, stack.ref, key::unit_id));
		const int64_t count = compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0));
		int64_t unit_value = gd::add(gd::int_field(state, unit, key::hp, 1), gd::int_field(state, unit, key::min_damage, 1));
		unit_value = gd::add(unit_value, gd::int_field(state, unit, key::max_damage, 1));
		unit_value = gd::add(unit_value, gd::bool_field(state, unit, key::ranged, false) ? 3 : 0);
		total_strength = gd::add(total_strength, gd::mul(count, compat::engine_max<int64_t>(6, unit_value)));
	}
	return total_strength;
}

Atom _defense_grade(State &state, DictRef town) {
	const int64_t strength = _garrison_strength(state, town);
	if (strength >= 260) {
		return key::fortified_watch;
	}
	if (strength >= 140) {
		return key::steady_watch_3;
	}
	if (strength > 0) {
		return key::thin_watch_2;
	}
	return key::open_walls;
}

Atom _hero_command_line(State &state, DictRef hero) {
	return gd::format(state, key::s_s_s_6, {
			str(hero_command_rules::hero_identity_context_line(state, hero, key::empty)),
			str(hero_command_rules::hero_progress_context_line(state, hero)),
			str(hero_command_rules::hero_readiness_context_line(state, hero, true)),
	});
}

Atom _growth_source_summary(State &state, DictRef town, Atom unit_id) {
	const ArrayRef source_names = state.new_array();
	for (const Value &building_id_value : field_list(state, town, key::built_buildings)) {
		const Atom building_id = gd::stringify(state, building_id_value);
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		if (ai::string_or_empty(state, building, key::unlock_unit_id) == unit_id) {
			state.append(source_names, str(text_field(state, building, key::name, str(building_id))));
			continue;
		}
		const Value growth_bonus = gd::field(state, building, key::growth_bonus);
		// A missing field is {} there: no bonus either way.
		if (gd::is_dict(growth_bonus) && gd::int_field(state, growth_bonus.ref, unit_id, 0) > 0) {
			state.append(source_names, str(text_field(state, building, key::name, str(building_id))));
		}
	}
	sort_strings(state, source_names);
	return join_array(state, key::comma_space, source_names);
}

Atom _reinforcement_grade(State &state, int64_t quality) {
	(void)state;
	if (quality >= 60) {
		return key::surge_ready;
	}
	if (quality >= 36) {
		return key::field_ready;
	}
	if (quality > 0) {
		return key::thin;
	}
	return key::stalled;
}

Atom _project_support_summary(State &state, DictRef capital_project) {
	std::vector<Atom> parts;
	const int64_t support_total = gd::int_field(state, capital_project, key::support_total, 0);
	if (support_total > 0) {
		Atom support_summary = gd::format(state, key::d_d_support_anchors, {
				int_value(gd::int_field(state, capital_project, key::support_met, 0)),
				int_value(support_total),
		});
		ArrayRef missing = 0;
		if (nonempty_array_field(state, capital_project, key::missing_support_labels, missing)) {
			support_summary = concat(state, support_summary, gd::format(state, key::missing_s_4, {str(join_array(state, key::comma_space, missing))}));
		}
		parts.push_back(support_summary);
	} else {
		const Atom next_label = ai::string_or_empty(state, capital_project, key::next_label);
		if (next_label != key::empty) {
			parts.push_back(gd::format(state, key::next_s_4, {str(next_label)}));
		} else {
			parts.push_back(key::build_the_final_anchor_works_here);
		}
	}
	if (gd::int_field(state, capital_project, key::recovery_guard, 0) > 0) {
		parts.push_back(gd::format(state, key::recovery_d_day_2, {int_value(gd::int_field(state, capital_project, key::recovery_guard, 0))}));
	}
	if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
		const DictRef penalty_values = state.new_dict();
		state.set(penalty_values, str(key::quality_penalty), int_value(gd::int_field(state, capital_project, key::quality_penalty, 0)));
		state.set(penalty_values, str(key::readiness_penalty), int_value(gd::int_field(state, capital_project, key::readiness_penalty, 0)));
		state.set(penalty_values, str(key::pressure_penalty), int_value(gd::int_field(state, capital_project, key::pressure_penalty, 0)));
		state.set(penalty_values, str(key::growth_penalty_percent), int_value(gd::int_field(state, capital_project, key::growth_penalty_percent, 0)));
		const Atom penalties = _describe_vulnerability_penalties(state, penalty_values);
		if (penalties != key::empty) {
			parts.push_back(gd::format(state, key::cut_chain_s, {str(penalties)}));
		}
		const Atom vulnerability_summary = ai::string_or_empty(state, capital_project, key::vulnerability_summary);
		if (vulnerability_summary != key::empty) {
			parts.push_back(vulnerability_summary);
		}
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom _project_watch_summary(State &state, DictRef capital_project) {
	Atom summary = _project_support_summary(state, capital_project);
	if (gd::bool_field(state, capital_project, key::active, false)) {
		summary = gd::format(state, key::online_s, {str(summary)});
	}
	if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
		summary = concat(state, summary, key::vulnerable_3);
	}
	return summary;
}

Atom _logistics_watch_summary(State &state, DictRef logistics) {
	const Atom summary = text_field(state, logistics, key::summary, str(key::no_linked_frontier_routes));
	const Atom impact_summary = ai::string_or_empty(state, logistics, key::impact_summary);
	if (impact_summary != key::empty) {
		return gd::format(state, key::s_s_text, {str(summary), str(impact_summary)});
	}
	return summary;
}

Atom _convoy_watch_summary(State &state, DictRef logistics) {
	ArrayRef delivery_lines = 0;
	// A missing field is [] there: "" either way.
	if (!nonempty_array_field(state, logistics, key::delivery_site_labels, delivery_lines)) {
		return key::empty;
	}
	const int64_t size = state.array_size(delivery_lines);
	std::vector<Atom> shown;
	for (int64_t index = 0; index < compat::engine_min<int64_t>(2, size); ++index) {
		shown.push_back(gd::stringify(state, state.at(delivery_lines, index)));
	}
	Atom summary = join_atoms(state, key::semicolon_space, shown);
	if (size > 2) {
		summary = concat(state, summary, gd::format(state, key::d_more_line_s, {int_value(size - 2), str(plural(size - 2, key::s))}));
	}
	return summary;
}

Atom _town_outlook_grade(State &state, int64_t readiness, DictRef threat_state, DictRef front_state, DictRef occupation_state, DictRef logistics, DictRef recovery, DictRef capital_project, int64_t reserve_count, int64_t ready_response_count) {
	int64_t severity = 0;
	if (gd::int_field(state, threat_state, key::visible_pressuring, 0) > 0 || gd::int_field(state, threat_state, key::siege_progress, 0) > 0) {
		severity += 3;
	} else if (gd::int_field(state, threat_state, key::visible_marching, 0) > 0) {
		severity += gd::int_field(state, threat_state, key::nearest_goal_distance, 9999) <= 1 ? 2 : 1;
	} else if (gd::bool_field(state, threat_state, key::hidden_targeting, false)) {
		severity += 1;
	}
	if (gd::bool_field(state, front_state, key::active, false)) {
		severity += ai::string_or_empty(state, front_state, key::mode) == key::retake ? 2 : 1;
	}
	if (gd::bool_field(state, occupation_state, key::active, false)) {
		severity += 2;
	}
	if (readiness <= 18) {
		severity += 2;
	} else if (readiness <= 30) {
		severity += 1;
	}
	if (gd::int_field(state, logistics, key::disrupted_count, 0) > 0 || gd::int_field(state, logistics, key::support_gap, 0) > 0) {
		severity += 2;
	} else if (gd::int_field(state, logistics, key::threatened_count, 0) > 0) {
		severity += 1;
	}
	if (gd::bool_field(state, recovery, key::active, false)) {
		severity += 1;
	}
	if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
		severity += 1;
	}
	if (reserve_count <= 0) {
		severity += 1;
	}
	if (ready_response_count <= 0 && (gd::int_field(state, logistics, key::threatened_count, 0) > 0 || gd::bool_field(state, recovery, key::active, false))) {
		severity += 1;
	}
	if (severity >= 7) {
		return key::brittle_perimeter;
	}
	if (severity >= 4) {
		return key::contested_watch;
	}
	if (readiness >= 40 && reserve_count > 0) {
		return key::strong_defensive_posture;
	}
	if (severity >= 2) {
		return key::guarded_but_strained;
	}
	return key::ready_watch;
}

Atom _town_frontier_outlook_line(State &state, DictRef town, DictRef threat_state, DictRef front_state, DictRef occupation_state, DictRef battlefront) {
	std::vector<Atom> clauses;
	const int64_t visible_pressuring = gd::int_field(state, threat_state, key::visible_pressuring, 0);
	const int64_t visible_marching = gd::int_field(state, threat_state, key::visible_marching, 0);
	const int64_t nearest_goal_distance = gd::int_field(state, threat_state, key::nearest_goal_distance, 9999);
	// A missing commanders field is [] there: an empty Array either way.
	ArrayRef pressuring_commanders = 0;
	const bool has_pressuring_commanders = nonempty_array_field(state, threat_state, key::pressuring_commanders, pressuring_commanders);
	ArrayRef marching_commanders = 0;
	const bool has_marching_commanders = nonempty_array_field(state, threat_state, key::marching_commanders, marching_commanders);
	const int64_t siege_progress = gd::int_field(state, threat_state, key::siege_progress, 0);
	const int64_t siege_capture_progress = compat::engine_max<int64_t>(1, gd::int_field(state, threat_state, key::siege_capture_progress, 1));
	if (visible_pressuring > 0) {
		if (visible_pressuring == 1 && has_pressuring_commanders) {
			clauses.push_back(gd::format(state, key::s_already_presses_the_approaches, {str(gd::stringify(state, state.at(pressuring_commanders, 0)))}));
		} else {
			Atom pressure_clause = gd::format(state, key::d_known_enemy_hero_s_already, {
					int_value(visible_pressuring),
					str(plural(visible_pressuring, key::es)),
			});
			if (has_pressuring_commanders) {
				pressure_clause = concat(state, pressure_clause, gd::format(state, key::s_3, {str(join_first(state, key::comma_space, pressuring_commanders, 2))}));
			}
			clauses.push_back(pressure_clause);
		}
	}
	if (visible_marching > 0) {
		const int64_t days = compat::engine_max<int64_t>(1, nearest_goal_distance);
		if (nearest_goal_distance <= 2) {
			if (visible_marching == 1 && has_marching_commanders) {
				clauses.push_back(gd::format(state, key::s_can_reach_in_d_day, {
						str(gd::stringify(state, state.at(marching_commanders, 0))),
						int_value(days),
						str(plural(days, key::s)),
				}));
			} else {
				Atom marching_clause = gd::format(state, key::d_known_enemy_force_s_can, {
						int_value(visible_marching),
						str(plural(visible_marching, key::s)),
						int_value(days),
						str(plural(days, key::s)),
				});
				if (has_marching_commanders) {
					marching_clause = concat(state, marching_clause, gd::format(state, key::s_3, {str(join_first(state, key::comma_space, marching_commanders, 2))}));
				}
				clauses.push_back(marching_clause);
			}
		} else {
			Atom distant_clause = gd::format(state, key::d_known_enemy_force_s_are, {
					int_value(visible_marching),
					str(plural(visible_marching, key::s)),
			});
			if (has_marching_commanders) {
				distant_clause = concat(state, distant_clause, gd::format(state, key::s_3, {str(join_first(state, key::comma_space, marching_commanders, 2))}));
			}
			clauses.push_back(distant_clause);
		}
	}
	if (gd::bool_field(state, threat_state, key::hidden_targeting, false)) {
		clauses.push_back(key::scouts_report_hostile_movement_beyond_the);
	}
	if (siege_progress > 0) {
		clauses.push_back(gd::format(state, key::siege_pressure_d_d_is_already, {int_value(siege_progress), int_value(siege_capture_progress)}));
	}
	if (gd::bool_field(state, front_state, key::active, false)) {
		const Atom front_summary = ai::string_or_empty(state, front_state, key::summary);
		if (front_summary != key::empty) {
			clauses.push_back(front_summary);
		}
	}
	if (gd::bool_field(state, occupation_state, key::active, false)) {
		clauses.push_back(ai::string_or_empty(state, occupation_state, key::summary));
	}
	if (clauses.empty()) {
		const Atom battlefront_summary = text_field(state, battlefront, key::summary, str(key::the_approaches_currently_favor_the_defenders));
		return gd::format(state, key::no_known_enemy_hero_is_heading, {str(_town_name(state, town)), str(battlefront_summary)});
	}
	return join_atoms(state, key::semicolon_space, clauses);
}

Atom _town_dispatch_readiness_line(State &state, int64_t response_count, int64_t ready_response_count, DictRef movement_state, int64_t reserve_count) {
	const int64_t movement_current = gd::int_field(state, movement_state, key::current, 0);
	const int64_t movement_max = gd::int_field(state, movement_state, key::max, 0);
	std::vector<Atom> parts;
	if (response_count <= 0) {
		parts.push_back(key::no_immediate_route_or_recovery_order_2);
	} else if (ready_response_count > 0) {
		parts.push_back(gd::format(state, key::d_response_order_s_ready, {int_value(ready_response_count), str(plural(ready_response_count, key::s))}));
	} else {
		parts.push_back(key::response_orders_exist_but_current_stores);
	}
	parts.push_back(gd::format(state, key::commander_move_d_d, {int_value(movement_current), int_value(movement_max)}));
	if (reserve_count > 0) {
		parts.push_back(gd::format(state, key::d_reserve_commander_s_cover_the, {int_value(reserve_count), str(plural(reserve_count, key::s))}));
	} else {
		parts.push_back(key::no_reserve_commander_covers_the_walls_2);
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom _town_support_watch_line(State &state, DictRef town, DictRef logistics, DictRef recovery, DictRef capital_project) {
	std::vector<Atom> parts;
	if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
		std::vector<Atom> capital_parts;
		capital_parts.push_back(key::capital_chain_exposed);
		ArrayRef missing_support = 0;
		if (nonempty_array_field(state, capital_project, key::missing_support_labels, missing_support)) {
			capital_parts.push_back(gd::format(state, key::missing_s, {str(join_first(state, key::comma_space, missing_support, 2))}));
		} else if (ai::string_or_empty(state, capital_project, key::vulnerability_summary) != key::empty) {
			capital_parts.push_back(ai::string_or_empty(state, capital_project, key::vulnerability_summary));
		}
		parts.push_back(join_atoms(state, key::space_bar_space, capital_parts));
	}
	if (gd::int_field(state, logistics, key::disrupted_count, 0) > 0 || gd::int_field(state, logistics, key::threatened_count, 0) > 0 || gd::int_field(state, logistics, key::support_gap, 0) > 0) {
		Atom logistics_line = text_field(state, logistics, key::summary, str(key::strained_chain));
		std::vector<Atom> impact_parts;
		ArrayRef labels = 0;
		if (nonempty_array_field(state, logistics, key::disrupted_site_labels, labels)) {
			impact_parts.push_back(gd::format(state, key::denied_s_2, {str(join_first(state, key::comma_space, labels, 2))}));
		} else if (nonempty_array_field(state, logistics, key::threatened_site_labels, labels)) {
			impact_parts.push_back(gd::format(state, key::threatened_s_2, {str(join_first(state, key::comma_space, labels, 2))}));
		} else if (nonempty_array_field(state, logistics, key::missing_family_labels, labels)) {
			impact_parts.push_back(gd::format(state, key::missing_s, {str(join_first(state, key::comma_space, labels, 2))}));
		}
		if (gd::int_field(state, logistics, key::gap_readiness_penalty, 0) > 0) {
			impact_parts.push_back(gd::format(state, key::readiness_d_4, {int_value(gd::int_field(state, logistics, key::gap_readiness_penalty, 0))}));
		}
		if (gd::int_field(state, logistics, key::gap_growth_penalty_percent, 0) > 0) {
			impact_parts.push_back(gd::format(state, key::recruits_d_2, {int_value(gd::int_field(state, logistics, key::gap_growth_penalty_percent, 0))}));
		}
		if (gd::int_field(state, logistics, key::gap_pressure_penalty, 0) > 0) {
			impact_parts.push_back(gd::format(state, key::s_d_text, {str(_town_pressure_label(state, town)), int_value(gd::int_field(state, logistics, key::gap_pressure_penalty, 0))}));
		}
		if (!impact_parts.empty()) {
			logistics_line = concat(state, logistics_line, gd::format(state, key::space_bar_space_s, {str(join_atoms(state, key::comma_space, impact_parts))}));
		}
		parts.push_back(logistics_line);
	}
	if (gd::bool_field(state, recovery, key::active, false)) {
		const int64_t days_to_clear = gd::int_field(state, recovery, key::days_to_clear, 0);
		parts.push_back(gd::format(state, key::recovery_delayed_d_day_s_at, {
				int_value(days_to_clear),
				str(plural(gd::int_field(state, recovery, key::days_to_clear, 0), key::s)),
				int_value(gd::int_field(state, recovery, key::relief_per_day, 1)),
		}));
	}
	if (parts.empty()) {
		return gd::format(state, key::s_recovery_lines_clear, {str(text_field(state, logistics, key::summary, str(key::stable_chain)))});
	}
	return join_atoms(state, key::space_bar_space, parts);
}

DictRef _active_hero_movement_state(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const Value hero = field_or_new_dict(state, overworld, key::hero);
	const Value hero_movement = gd::is_dict(hero) ? field_or_new_dict(state, hero.ref, key::movement) : dict_value(state.new_dict());
	const Value overworld_movement = field_or_new_dict(state, overworld, key::movement);
	const DictRef result = state.new_dict();
	const Value current = ai::vget(state, hero_movement, key::current, ai::vget(state, overworld_movement, key::current, int_value(0)));
	state.set(result, str(key::current), int_value(compat::engine_max<int64_t>(0, gd::to_int(state, current))));
	const Value maximum = ai::vget(state, hero_movement, key::max, ai::vget(state, overworld_movement, key::max, int_value(0)));
	state.set(result, str(key::max), int_value(compat::engine_max<int64_t>(0, gd::to_int(state, maximum))));
	return result;
}

int64_t _count_ready_actions(State &state, ArrayRef actions) {
	int64_t ready_count = 0;
	for (const Value &action : gd::items(state, array_value(actions))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			ready_count += 1;
		}
	}
	return ready_count;
}

int64_t _stationed_reserve_count(State &state, DictRef session, ArrayRef stationed) {
	int64_t reserve_count = 0;
	const Atom active_hero_id = ai::string_or_empty(state, session_view::overworld(state, session), key::active_hero_id);
	for (const Value &hero : gd::items(state, array_value(stationed))) {
		if (gd::is_dict(hero) && ai::string_or_empty(state, hero.ref, key::id) != active_hero_id) {
			reserve_count += 1;
		}
	}
	return reserve_count;
}

int64_t _enemy_hero_distance_to_town(State &state, DictRef encounter, DictRef town) {
	if (!gd::is_dict(gd::field(state, encounter, key::ai_hero)) || gd::int_field(state, encounter, key::level, 0) != gd::int_field(state, town, key::level, 0)) {
		return int64_t(1) << 20;
	}
	return compat::engine_max<int64_t>(
			compat::absi(gd::sub(gd::int_field(state, encounter, key::x, 0), gd::int_field(state, town, key::x, 0))),
			compat::absi(gd::sub(gd::int_field(state, encounter, key::y, 0), gd::int_field(state, town, key::y, 0))));
}

ArrayRef _town_threat_lines(State &state, DictRef session, DictRef town) {
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(gd::index(state, session, str(key::scenario_id))));
	const ArrayRef threat_lines = state.new_array();
	const Atom town_placement_id = ai::string_or_empty(state, town, key::placement_id);
	const DictRef front_state = overworld_rules::town_front_state(state, session, town, state.new_dict());
	if (town_placement_id == key::empty) {
		return threat_lines;
	}

	const DictRef overworld = session_view::overworld(state, session);
	// A missing field is [] there: no placement is in it either way.
	const Value resolved_encounters = gd::field(state, overworld, key::resolved_encounters);
	for (const Value &config : field_list(state, scenario, key::enemy_factions)) {
		if (!gd::is_dict(config)) {
			continue;
		}
		const Atom faction_id = ai::string_or_empty(state, config.ref, key::faction_id);
		if (faction_id == key::empty) {
			continue;
		}
		int64_t visible_marching = 0;
		int64_t visible_pressuring = 0;
		bool hidden_targeting = false;
		std::vector<Atom> pressuring_commanders;
		std::vector<Atom> marching_commanders;
		for (const Value &encounter : field_list(state, overworld, key::encounters)) {
			if (!gd::is_dict(encounter)) {
				continue;
			}
			if (ai::string_or_empty(state, encounter.ref, key::spawned_by_faction_id) != faction_id) {
				continue;
			}
			// An enemy hero's plans are hidden; a sighted hero close to the walls
			// is the threat a player can see.
			const int64_t hero_distance = _enemy_hero_distance_to_town(state, encounter.ref, town);
			if (ai::string_or_empty(state, encounter.ref, key::target_placement_id) != town_placement_id && hero_distance > kEnemyHeroWatchRadius) {
				continue;
			}
			if (gd::is_array(resolved_encounters) && gd::array_has(state, resolved_encounters.ref, str(ai::string_or_empty(state, encounter.ref, key::placement_id)))) {
				continue;
			}
			const bool is_public = enemy_adventure_rules::_raid_is_public(state, session, encounter.ref);
			if (hero_distance <= kEnemyHeroWatchRadius && !is_public) {
				continue;
			}
			const bool is_pressuring = gd::bool_field(state, encounter.ref, key::arrived, false) || gd::int_field(state, encounter.ref, key::goal_distance, 9999) <= 0 || hero_distance <= 2;
			const Atom commander_name = overworld_rules::encounter_commander_threat_label(state, encounter.ref);
			if (is_public) {
				if (is_pressuring) {
					visible_pressuring += 1;
					if (commander_name != key::empty && std::find(pressuring_commanders.begin(), pressuring_commanders.end(), commander_name) == pressuring_commanders.end()) {
						pressuring_commanders.push_back(commander_name);
					}
				} else {
					visible_marching += 1;
					if (commander_name != key::empty && std::find(marching_commanders.begin(), marching_commanders.end(), commander_name) == marching_commanders.end()) {
						marching_commanders.push_back(commander_name);
					}
				}
			} else {
				hidden_targeting = true;
			}
		}

		const DictRef enemy_state = _enemy_state_for_faction(state, session, faction_id);
		int64_t siege_progress = 0;
		if (ai::string_or_empty(state, config.ref, key::siege_target_placement_id) == town_placement_id) {
			siege_progress = compat::engine_max<int64_t>(0, gd::int_field(state, enemy_state, key::siege_progress, 0));
		}
		Atom commander_recovery = key::empty;
		Atom commander_rebuild = key::empty;
		if (ai::string_or_empty(state, config.ref, key::siege_target_placement_id) == town_placement_id
				|| visible_marching > 0
				|| visible_pressuring > 0
				|| hidden_targeting
				|| siege_progress > 0) {
			commander_recovery = enemy_adventure_rules::public_commander_recovery_summary(state, session, faction_id, field_or_new_array(state, enemy_state, key::commander_roster));
			commander_rebuild = enemy_adventure_rules::public_commander_rebuild_summary(state, session, faction_id, field_or_new_array(state, enemy_state, key::commander_roster));
		}
		if (visible_marching <= 0
				&& visible_pressuring <= 0
				&& !hidden_targeting
				&& siege_progress <= 0
				&& commander_recovery == key::empty
				&& commander_rebuild == key::empty) {
			continue;
		}

		std::vector<Atom> clauses;
		if (visible_pressuring > 0) {
			if (visible_pressuring == 1 && !pressuring_commanders.empty()) {
				clauses.push_back(gd::format(state, key::s_presses_the_approaches, {str(pressuring_commanders[0])}));
			} else {
				Atom pressure_clause = gd::format(state, key::d_known_enemy_hero_s_press, {
						int_value(visible_pressuring),
						str(plural(visible_pressuring, key::es)),
				});
				if (!pressuring_commanders.empty()) {
					const std::vector<Atom> shown(pressuring_commanders.begin(), pressuring_commanders.begin() + static_cast<std::ptrdiff_t>(std::min<size_t>(2, pressuring_commanders.size())));
					pressure_clause = concat(state, pressure_clause, gd::format(state, key::s_3, {str(join_atoms(state, key::comma_space, shown))}));
				}
				clauses.push_back(pressure_clause);
			}
		}
		if (visible_marching > 0) {
			if (visible_marching == 1 && !marching_commanders.empty()) {
				clauses.push_back(gd::format(state, key::s_is_marching_on_the_town, {str(marching_commanders[0])}));
			} else {
				Atom marching_clause = gd::format(state, key::d_known_enemy_force_s_are_2, {
						int_value(visible_marching),
						str(plural(visible_marching, key::s)),
				});
				if (!marching_commanders.empty()) {
					const std::vector<Atom> shown(marching_commanders.begin(), marching_commanders.begin() + static_cast<std::ptrdiff_t>(std::min<size_t>(2, marching_commanders.size())));
					marching_clause = concat(state, marching_clause, gd::format(state, key::s_3, {str(join_atoms(state, key::comma_space, shown))}));
				}
				clauses.push_back(marching_clause);
			}
		}
		if (hidden_targeting) {
			clauses.push_back(key::scouts_report_hostile_movement_beyond_the);
		}
		if (siege_progress > 0) {
			clauses.push_back(gd::format(state, key::siege_pressure_d_d, {
					int_value(siege_progress),
					int_value(compat::engine_max<int64_t>(1, gd::int_field(state, config.ref, key::siege_capture_progress, 1))),
			}));
		}
		if (gd::bool_field(state, front_state, key::active, false) && ai::string_or_empty(state, front_state, key::faction_id) == faction_id) {
			const Atom front_clause = ai::string_or_empty(state, front_state, key::public_clause);
			if (front_clause != key::empty) {
				clauses.push_back(front_clause);
			}
		}
		if (commander_recovery != key::empty) {
			clauses.push_back(commander_recovery);
		}
		if (commander_rebuild != key::empty) {
			clauses.push_back(commander_rebuild);
		}
		const Value faction_name = gd::field_or(state, gd::content_row(state, ContentTable::Faction, faction_id), key::name, str(faction_id));
		state.append(threat_lines, str(gd::format(state, key::s_colon_s_text, {
				str(text_field(state, config.ref, key::label, faction_name)),
				str(join_atoms(state, key::semicolon_space, clauses)),
		})));
	}
	return threat_lines;
}

Atom _pressure_brief(State &state, DictRef session, DictRef town) {
	const ArrayRef threat_lines = _town_threat_lines(state, session, town);
	if (state.array_size(threat_lines) == 0) {
		return gd::format(state, key::s_reports_quiet_roads_beyond_the, {str(_town_name(state, town))});
	}
	return gd::to_string(state.at(threat_lines, 0));
}

DictRef _enemy_state_for_faction(State &state, DictRef session, Atom faction_id) {
	for (const Value &enemy_state : gd::field_items(state, session_view::overworld(state, session), str(key::enemy_states))) {
		if (gd::is_dict(enemy_state) && ai::string_or_empty(state, enemy_state.ref, key::faction_id) == faction_id) {
			return enemy_state.ref;
		}
	}
	return state.new_dict();
}

} // namespace town_rules

} // namespace aurelion::rules::port
