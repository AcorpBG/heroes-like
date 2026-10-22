// Layer 11: the battle aftermath report and its summaries, the casualty ledger, and the withdrawal and collapse
// previews with the losses they take from the treasury and the army.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <algorithm>
#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
using compat::float_to_int;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// String(d.get(field, fallback)).
Atom string_of(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, gd::field_or(state, dict, field, str(fallback)));
}

// session.battle and session.overworld: SessionData's typed Dictionaries.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

DictRef session_overworld(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

// session == null or session.battle.is_empty()
bool no_battle(State &state, const Value &session) {
	return session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session));
}

// d.get(field, {}) handed on: a new Dictionary when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// separator.join(parts) of Strings.
Atom join(State &state, const std::vector<Atom> &parts, Atom separator) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// "" if count == 1 else "s", and "y" if count == 1 else "ies".
Atom plural_s(int64_t count) {
	return count == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
}

Atom plural_y(int64_t count) {
	return count == 1 ? static_cast<Atom>(key::y) : static_cast<Atom>(key::ies);
}

// clamp(value, lo, hi) of ints (the untyped utility).
int64_t clamp_untyped(int64_t value, int64_t lo, int64_t hi) {
	return compat::variant_clamp(compat::Number::of_int(value), compat::Number::of_int(lo), compat::Number::of_int(hi)).i;
}

// text.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string &source = state.text(text);
	const std::string trimmed = source.substr(0, source.size() - state.text(suffix).size());
	return state.intern(trimmed);
}

// text.split(delimiter) (allow_empty true) of a one-character delimiter.
std::vector<Atom> split(State &state, Atom text, char delimiter) {
	const std::string source = state.text(text);
	std::vector<Atom> pieces;
	size_t from = 0;
	while (true) {
		size_t end = source.find(delimiter, from);
		if (end == std::string::npos) {
			end = source.size();
		}
		pieces.push_back(state.intern(source.substr(from, end - from)));
		if (end == source.size()) {
			break;
		}
		from = end + 1;
	}
	return pieces;
}

// var text := String(d.get(field, "")).strip_edges(); if text != "" and text not in parts: parts.append(text)
void append_unique_text(State &state, std::vector<Atom> &parts, DictRef dict, Atom field) {
	const Atom text = gd::strip_edges(state, string_of(state, dict, field, key::empty));
	if (text != key::empty && std::find(parts.begin(), parts.end(), text) == parts.end()) {
		parts.push_back(text);
	}
}

// String(battle.get("encounter_name", battle.get("encounter_id", "Battle"))).
Atom battle_label(State &state, DictRef battle) {
	const Value fallback = gd::field_or(state, battle, key::encounter_id, str(key::Battle));
	return gd::stringify(state, gd::field_or(state, battle, key::encounter_name, fallback));
}

// _battle_survivor_stacks' filters {"source_type": source_type, field: value}.
DictRef survivor_filters(State &state, Atom source_type, Atom field, Atom value) {
	const DictRef filters = state.new_dict();
	state.set(filters, str(key::source_type), str(source_type));
	state.set(filters, str(field), str(value));
	return filters;
}

// The enemy's survivors from the encounter's army, or all of them when none match.
ArrayRef enemy_survivor_stacks(State &state, const Value &session) {
	const Atom encounter_key = string_of(state, session_battle(state, session), key::resolved_key, key::empty);
	ArrayRef survivors = _battle_survivor_stacks(state, session, key::enemy, survivor_filters(state, key::encounter_army, key::encounter_key, encounter_key));
	if (state.array_size(survivors) == 0) {
		survivors = _battle_survivor_stacks(state, session, key::enemy, state.new_dict());
	}
	return survivors;
}

// OverworldRulesScript._nearest_town_for_controller(session, "player", ...) at the battle's position.
DictRef nearest_player_town(State &state, const Value &session) {
	const Value battle_position = get_or_new_dict(state, session_battle(state, session), key::position);
	const int64_t x = gd::to_int(state, ai::vget(state, battle_position, key::x, int_value(0)));
	const int64_t y = gd::to_int(state, ai::vget(state, battle_position, key::y, int_value(0)));
	const int64_t level = overworld_level_rules::level_of(state, battle_position);
	return overworld_rules::_nearest_town_for_controller(state, gd::object_view(state, session), key::player, x, y, level);
}

} // namespace

void _record_battle_aftermath(State &state, const Value &session, Atom outcome, Atom summary, DictRef details) {
	if (session.kind == Kind::Nil) {
		return;
	}
	const Atom display_outcome = _battle_aftermath_display_outcome(state, outcome, details);
	Atom headline = gd::format(state, key::battle_aftermath_s, { str(_titleize_token(state, display_outcome)) });
	if (!gd::is_empty(state, session_battle(state, session))) {
		headline = gd::format(state, key::s_s_text, { str(headline), str(battle_label(state, session_battle(state, session))) });
	}
	const Atom result_summary = _battle_aftermath_result_summary(state, summary);
	const Atom reward_summary = _battle_aftermath_reward_summary(state, details);
	const Atom artifact_summary = _battle_aftermath_artifact_summary(state, details);
	const Atom force_summary = _battle_aftermath_force_summary(state, session);
	const Atom world_summary = _battle_aftermath_world_summary(state, session, outcome, details);
	const DictRef casualty_ledger = _battle_report_casualty_ledger(state, session_battle(state, session));
	const DictRef battle = session_battle(state, session);
	const Atom battle_name = battle_label(state, battle);
	const DictRef report = state.new_dict();
	state.set(report, str(key::report_version), int_value(1));
	state.set(report, str(key::pending), bool_value(true));
	state.set(report, str(key::outcome), str(outcome));
	state.set(report, str(key::headline), str(headline));
	state.set(report, str(key::battle_name), str(battle_name));
	state.set(report, str(key::terrain), str(string_of(state, battle, key::terrain, key::empty)));
	state.set(report, str(key::rounds), int_value(engine_max<int64_t>(1, gd::int_field(state, battle, key::round, 1))));
	state.set(report, str(key::summary), str(summary));
	state.set(report, str(key::result_summary), str(result_summary));
	state.set(report, str(key::reward_summary), str(reward_summary));
	state.set(report, str(key::artifact_summary), str(artifact_summary));
	state.set(report, str(key::force_summary), str(force_summary));
	state.set(report, str(key::world_summary), str(world_summary));
	state.set(report, str(key::resource_summary), str(string_of(state, details, key::resource_summary, key::empty)));
	state.set(report, str(key::army_summary), str(string_of(state, details, key::army_summary, key::empty)));
	state.set(report, str(key::pressure_summary), str(string_of(state, details, key::pressure_summary, key::empty)));
	state.set(report, str(key::recovery_summary), str(string_of(state, details, key::recovery_summary, key::empty)));
	state.set(report, str(key::front_summary), str(string_of(state, details, key::front_summary, key::empty)));
	state.set(report, str(key::logistics_summary), str(string_of(state, details, key::logistics_summary, key::empty)));
	state.set(report, str(key::commander_summary), str(string_of(state, details, key::commander_summary, key::empty)));
	state.set(report, str(key::casualties), dict_value(casualty_ledger));
	state.set(report, str(key::day), gd::member(state, session, key::day));
	state.set(report, str(key::scenario_id), gd::member(state, session, key::scenario_id));
	const DictRef report_identity = state.new_dict();
	state.set(report_identity, str(key::scenario_id), gd::member(state, session, key::scenario_id));
	state.set(report_identity, str(key::day), gd::member(state, session, key::day));
	const Value battle_key_fallback = gd::field_or(state, battle, key::encounter_id, str(key::empty));
	state.set(report_identity, str(key::battle_key), str(gd::stringify(state, gd::field_or(state, battle, key::resolved_key, battle_key_fallback))));
	state.set(report_identity, str(key::outcome), str(outcome));
	state.set(report_identity, str(key::casualties), dict_value(casualty_ledger));
	const std::string report_id = compat::sha256_text(gd::json_stringify(state, dict_value(report_identity)));
	state.set(report, str(key::report_id), str(state.intern(report_id)));
	state.set(report, str(key::return_summary), str(_battle_aftermath_return_summary(state, report)));
	state.set(gd::as_dict(gd::member(state, session, key::flags)), str(key::last_battle_aftermath), dict_value(report));
}

Atom _battle_aftermath_display_outcome(State &state, Atom outcome, DictRef details) {
	const Atom explicit_label = string_of(state, details, key::display_outcome, key::empty);
	if (explicit_label != key::empty) {
		return explicit_label;
	}
	if (outcome == key::retreat) {
		return key::withdrawal;
	}
	if (outcome == key::hero_defeat || outcome == key::defeat) {
		return key::rout;
	}
	if (outcome == key::town_lost) {
		return key::collapse;
	}
	return outcome;
}

Atom _battle_aftermath_result_summary(State &state, Atom summary) {
	const Atom clean_summary = gd::strip_edges(state, summary);
	if (clean_summary == key::empty) {
		return key::empty;
	}
	return gd::format(state, key::result_s, { str(clean_summary) });
}

Atom _battle_aftermath_reward_summary(State &state, DictRef details) {
	const Atom explicit_summary = gd::strip_edges(state, string_of(state, details, key::reward_summary, key::empty));
	if (explicit_summary != key::empty) {
		return explicit_summary;
	}
	const Atom resource_summary = gd::strip_edges(state, string_of(state, details, key::resource_summary, key::empty));
	if (resource_summary == key::empty) {
		return key::empty;
	}
	if (gd::begins_with(state, resource_summary, key::battle_rewards)) {
		const Atom reward_text = gd::strip_edges(state, trim_suffix(state, gd::trim_prefix(state, resource_summary, key::battle_rewards), key::period));
		if (reward_text != key::empty) {
			return gd::format(state, key::rewards_s, { str(reward_text) });
		}
	}
	return resource_summary;
}

Atom _battle_aftermath_artifact_summary(State &state, DictRef details) {
	const Atom artifact_summary = gd::strip_edges(state, string_of(state, details, key::artifact_summary, key::empty));
	if (artifact_summary == key::empty) {
		return key::empty;
	}
	if (gd::begins_with(state, artifact_summary, key::Artifact)) {
		return artifact_summary;
	}
	return gd::format(state, key::artifact_s, { str(artifact_summary) });
}

Atom _battle_aftermath_force_summary(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return key::empty;
	}
	const Atom player_clause = _battle_aftermath_side_force_clause(state, session_battle(state, session), key::player, key::your_forces);
	const Atom enemy_clause = _battle_aftermath_side_force_clause(state, session_battle(state, session), key::enemy, key::Enemy);
	std::vector<Atom> clauses;
	if (player_clause != key::empty) {
		clauses.push_back(player_clause);
	}
	if (enemy_clause != key::empty) {
		clauses.push_back(enemy_clause);
	}
	if (clauses.empty()) {
		return key::empty;
	}
	return gd::format(state, key::forces_s, { str(join(state, clauses, key::semicolon_space)) });
}

Atom _battle_aftermath_side_force_clause(State &state, DictRef battle, Atom side, Atom label) {
	int64_t starting_troops = 0;
	int64_t surviving_troops = 0;
	int64_t surviving_companies = 0;
	int64_t broken_companies = 0;
	for (const Value &stack_value : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		const DictRef stack = stack_value.ref;
		if (string_of(state, stack, key::side, key::empty) != side) {
			continue;
		}
		const int64_t base_count = engine_max<int64_t>(0, gd::int_field(state, stack, key::base_count, 0));
		const int64_t alive_count = _alive_count(state, stack);
		starting_troops = gd::add(starting_troops, base_count);
		surviving_troops = gd::add(surviving_troops, alive_count);
		if (alive_count > 0) {
			surviving_companies += 1;
		} else if (base_count > 0) {
			broken_companies += 1;
		}
	}
	if (starting_troops <= 0) {
		return gd::format(state, key::s_had_no_formed_companies, { str(label) });
	}
	const int64_t lost_troops = engine_max<int64_t>(0, gd::sub(starting_troops, surviving_troops));
	if (surviving_troops <= 0) {
		return gd::format(state, key::s_defeated_d_troop_s_lost, { str(label), int_value(starting_troops), str(plural_s(starting_troops)) });
	}
	std::string clause = state.text(gd::format(state, key::s_d_d_troop_s_remain, {
			str(label),
			int_value(surviving_troops),
			int_value(starting_troops),
			str(plural_s(starting_troops)),
			int_value(surviving_companies),
			str(plural_y(surviving_companies)),
	}));
	if (lost_troops > 0) {
		clause += state.text(gd::format(state, key::d_lost, { int_value(lost_troops) }));
	}
	if (broken_companies > 0) {
		clause += state.text(gd::format(state, key::d_compan_s_broken, { int_value(broken_companies), str(plural_y(broken_companies)) }));
	}
	return state.intern(clause);
}

Atom _battle_aftermath_world_summary(State &state, const Value &session, Atom outcome, DictRef details) {
	std::vector<Atom> parts;
	for (const Atom field : { key::front_summary, key::pressure_summary, key::recovery_summary, key::logistics_summary, key::commander_summary }) {
		append_unique_text(state, parts, details, field);
	}
	if (parts.empty() && !no_battle(state, session)) {
		const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
		if (outcome == key::victory) {
			if (_is_town_assault_context(state, context)) {
				parts.push_back(key::town_control_is_updated_on_the);
			} else if (string_of(state, session_battle(state, session), key::resolved_key, key::empty) != key::empty) {
				parts.push_back(key::the_encounter_is_cleared_from_the);
			}
		} else if (outcome == key::retreat || outcome == key::surrender || outcome == key::stalemate || outcome == key::hero_defeat || outcome == key::defeat || outcome == key::town_lost) {
			parts.push_back(key::army_and_frontier_state_are_updated);
		}
	}
	if (parts.empty()) {
		return key::empty;
	}
	return gd::format(state, key::overworld_s, { str(join(state, parts, key::space)) });
}

Atom _battle_aftermath_return_summary(State &state, DictRef report) {
	std::vector<Atom> parts;
	for (const Atom field : { key::result_summary, key::reward_summary, key::artifact_summary, key::force_summary, key::world_summary }) {
		append_unique_text(state, parts, report, field);
	}
	return join(state, parts, key::space);
}

DictRef _battle_report_casualty_ledger(State &state, DictRef battle) {
	const DictRef player = _battle_report_side_casualties(state, battle, key::player);
	const DictRef enemy = _battle_report_side_casualties(state, battle, key::enemy);
	const DictRef ledger = state.new_dict();
	state.set(ledger, str(key::player), dict_value(player));
	state.set(ledger, str(key::enemy), dict_value(enemy));
	return ledger;
}

DictRef _battle_report_side_casualties(State &state, DictRef battle, Atom side) {
	const ArrayRef rows = state.new_array();
	int64_t deployed = 0;
	int64_t surviving = 0;
	int64_t companies_deployed = 0;
	int64_t companies_surviving = 0;
	for (const Value &stack_value : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack_value)) {
			continue;
		}
		const DictRef stack = stack_value.ref;
		if (string_of(state, stack, key::side, key::empty) != side) {
			continue;
		}
		const int64_t starting_count = engine_max<int64_t>(0, gd::int_field(state, stack, key::base_count, 0));
		const int64_t surviving_count = engine_max<int64_t>(0, _alive_count(state, stack));
		const int64_t lost_count = engine_max<int64_t>(0, gd::sub(starting_count, surviving_count));
		deployed = gd::add(deployed, starting_count);
		surviving = gd::add(surviving, surviving_count);
		if (starting_count > 0) {
			companies_deployed += 1;
		}
		if (surviving_count > 0) {
			companies_surviving += 1;
		}
		const Atom battle_id = string_of(state, stack, key::battle_id, key::empty);
		const Atom unit_id = string_of(state, stack, key::unit_id, key::empty);
		const Value name_fallback = gd::field_or(state, stack, key::unit_id, str(key::unknown_company));
		const Atom name = gd::stringify(state, gd::field_or(state, stack, key::name, name_fallback));
		const int64_t tier = clamp_untyped(gd::int_field(state, stack, key::tier, 1), 1, 7);
		const DictRef row = state.new_dict();
		state.set(row, str(key::battle_id), str(battle_id));
		state.set(row, str(key::unit_id), str(unit_id));
		state.set(row, str(key::name), str(name));
		state.set(row, str(key::tier), int_value(tier));
		state.set(row, str(key::starting), int_value(starting_count));
		state.set(row, str(key::surviving), int_value(surviving_count));
		state.set(row, str(key::lost), int_value(lost_count));
		state.set(row, str(key::destroyed), bool_value(starting_count > 0 && surviving_count <= 0));
		state.append(rows, dict_value(row));
	}
	Atom label = side == key::player ? static_cast<Atom>(key::your_forces) : string_of(state, battle, key::enemy_army_name, key::enemy_forces);
	Value commander;
	if (side == key::player) {
		if (state.lookup(battle, str(key::player_commander_state), commander) && gd::is_dict(commander)
				&& gd::strip_edges(state, string_of(state, commander.ref, key::name, key::empty)) != key::empty) {
			label = string_of(state, commander.ref, key::name, key::empty);
		}
	} else {
		if (state.lookup(battle, str(key::enemy_hero), commander) && gd::is_dict(commander)
				&& gd::strip_edges(state, string_of(state, commander.ref, key::name, key::empty)) != key::empty) {
			label = string_of(state, commander.ref, key::name, key::empty);
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::side), str(side));
	state.set(result, str(key::label), str(label));
	state.set(result, str(key::rows), array_value(rows));
	const DictRef totals = state.new_dict();
	state.set(totals, str(key::deployed), int_value(deployed));
	state.set(totals, str(key::surviving), int_value(surviving));
	state.set(totals, str(key::lost), int_value(engine_max<int64_t>(0, gd::sub(deployed, surviving))));
	state.set(totals, str(key::companies_deployed), int_value(companies_deployed));
	state.set(totals, str(key::companies_surviving), int_value(companies_surviving));
	state.set(totals, str(key::companies_destroyed), int_value(engine_max<int64_t>(0, gd::sub(companies_deployed, companies_surviving))));
	state.set(result, str(key::totals), dict_value(totals));
	return result;
}

Atom _titleize_token(State &state, Atom value) {
	if (value == key::empty) {
		return key::empty;
	}
	std::vector<Atom> words = split(state, value, '_');
	for (Atom &word : words) {
		word = gd::capitalize(state, word);
	}
	return join(state, words, key::space);
}

DictRef _army_totals(State &state, DictRef battle, Atom side) {
	const DictRef totals = state.new_dict();
	state.set(totals, str(key::stacks), int_value(0));
	state.set(totals, str(key::units), int_value(0));
	state.set(totals, str(key::health), int_value(0));
	state.set(totals, str(key::ranged_stacks), int_value(0));
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || string_of(state, stack.ref, key::side, key::empty) != side) {
			continue;
		}
		const int64_t count = _alive_count(state, stack.ref);
		if (count <= 0) {
			continue;
		}
		state.set(totals, str(key::stacks), int_value(gd::add(gd::int_field(state, totals, key::stacks, 0), 1)));
		state.set(totals, str(key::units), int_value(gd::add(gd::int_field(state, totals, key::units, 0), count)));
		state.set(totals, str(key::health), int_value(gd::add(gd::int_field(state, totals, key::health, 0), gd::int_field(state, stack.ref, key::total_health, 0))));
		if (gd::bool_field(state, stack.ref, key::ranged, false)) {
			state.set(totals, str(key::ranged_stacks), int_value(gd::add(gd::int_field(state, totals, key::ranged_stacks, 0), 1)));
		}
	}
	return totals;
}

DictRef _build_withdrawal_aftermath_preview(State &state, const Value &session, Atom outcome) {
	const DictRef preview = state.new_dict();
	state.set(preview, str(key::enemy_faction_id), str(key::empty));
	state.set(preview, str(key::enemy_label), str(key::the_opposing_host));
	state.set(preview, str(key::resource_loss), dict_value(state.new_dict()));
	state.set(preview, str(key::casualty_units), int_value(0));
	state.set(preview, str(key::pressure_delta), int_value(0));
	state.set(preview, str(key::nearest_town_placement_id), str(key::empty));
	state.set(preview, str(key::nearest_town_name), str(key::empty));
	state.set(preview, str(key::recovery_pressure), int_value(0));
	if (no_battle(state, session)) {
		return preview;
	}

	const Atom enemy_faction_id = _battle_enemy_faction_id(state, session);
	state.set(preview, str(key::enemy_faction_id), str(enemy_faction_id));
	state.set(preview, str(key::enemy_label), str(_battle_enemy_label(state, session, enemy_faction_id)));

	// String(commander_source.get("hero_id", session.overworld.get("active_hero_id", ""))) of
	// session.battle.get("player_commander_source", {}).
	Value commander_source;
	const bool has_commander_source = state.lookup(session_battle(state, session), str(key::player_commander_source), commander_source);
	Value hero_value = gd::field_or(state, session_overworld(state, session), key::active_hero_id, str(key::empty));
	if (has_commander_source) {
		hero_value = ai::vget(state, commander_source, key::hero_id, hero_value);
	}
	const Atom hero_id = gd::stringify(state, hero_value);
	ArrayRef player_survivors = _battle_survivor_stacks(state, session, key::player, survivor_filters(state, key::hero_army, key::hero_id, hero_id));
	if (state.array_size(player_survivors) == 0) {
		player_survivors = _battle_survivor_stacks(state, session, key::player, state.new_dict());
	}
	const ArrayRef enemy_survivors = enemy_survivor_stacks(state, session);

	const int64_t player_units = _stack_count_total(state, array_value(player_survivors));
	const int64_t player_strength = _army_strength_from_stacks(state, array_value(player_survivors));
	const int64_t enemy_strength = _army_strength_from_stacks(state, array_value(enemy_survivors));
	const double strength_ratio = static_cast<double>(enemy_strength) / static_cast<double>(engine_max<int64_t>(1, player_strength));
	const int64_t severity = engine_clamp<int64_t>(gd::add(1, float_to_int(compat::godot_floor(strength_ratio))), 1, 4);
	const DictRef desired_loss = state.new_dict();
	state.set(desired_loss, str(key::gold), int_value(0));
	state.set(desired_loss, str(key::wood), int_value(0));
	state.set(desired_loss, str(key::ore), int_value(0));

	if (outcome == key::surrender) {
		const int64_t strength_gold = float_to_int(compat::godot_round(static_cast<double>(enemy_strength) / 12.0));
		state.set(desired_loss, str(key::gold), int_value(gd::add(gd::add(180, gd::mul(severity, 90)), strength_gold)));
		state.set(desired_loss, str(key::wood), int_value(engine_max<int64_t>(0, severity - 1)));
		state.set(desired_loss, str(key::ore), int_value(severity >= 3 ? 1 : 0));
		state.set(preview, str(key::casualty_units), int_value(_casualty_units_from_ratio(player_units, 0.04 + (static_cast<double>(severity) * 0.03))));
		state.set(preview, str(key::pressure_delta), int_value(enemy_faction_id != key::empty && severity >= 4 ? 1 : 0));
		state.set(preview, str(key::recovery_pressure), int_value(1));
	} else {
		const int64_t strength_gold = float_to_int(compat::godot_round(static_cast<double>(enemy_strength) / 18.0));
		state.set(desired_loss, str(key::gold), int_value(gd::add(gd::add(90, gd::mul(severity, 70)), strength_gold)));
		state.set(desired_loss, str(key::wood), int_value(engine_max<int64_t>(0, severity - 1)));
		state.set(desired_loss, str(key::ore), int_value(severity >= 4 ? 1 : 0));
		state.set(preview, str(key::casualty_units), int_value(_casualty_units_from_ratio(player_units, 0.12 + (static_cast<double>(severity) * 0.06))));
		state.set(preview, str(key::pressure_delta), int_value(enemy_faction_id != key::empty ? 1 + compat::int_div(severity, 2) : 0));
		state.set(preview, str(key::recovery_pressure), int_value(1 + (severity >= 3 ? 1 : 0)));
	}

	state.set(preview, str(key::resource_loss), dict_value(_clamped_resource_loss(state, session, desired_loss)));
	const DictRef nearest_town_result = nearest_player_town(state, session);
	if (gd::int_field(state, nearest_town_result, key::index, -1) >= 0) {
		const Value town = get_or_new_dict(state, nearest_town_result, key::town);
		state.set(preview, str(key::nearest_town_placement_id), str(gd::stringify(state, ai::vget(state, town, key::placement_id, str(key::empty)))));
		state.set(preview, str(key::nearest_town_name), str(_town_name(state, gd::as_dict(town))));
	}
	return preview;
}

DictRef _build_collapse_aftermath_preview(State &state, const Value &session, Atom outcome) {
	const DictRef preview = state.new_dict();
	state.set(preview, str(key::enemy_faction_id), str(key::empty));
	state.set(preview, str(key::enemy_label), str(key::the_opposing_host));
	state.set(preview, str(key::resource_loss), dict_value(state.new_dict()));
	state.set(preview, str(key::pressure_delta), int_value(0));
	state.set(preview, str(key::nearest_town_placement_id), str(key::empty));
	state.set(preview, str(key::nearest_town_name), str(key::empty));
	state.set(preview, str(key::recovery_pressure), int_value(0));
	if (no_battle(state, session)) {
		return preview;
	}
	const Atom enemy_faction_id = _battle_enemy_faction_id(state, session);
	state.set(preview, str(key::enemy_faction_id), str(enemy_faction_id));
	state.set(preview, str(key::enemy_label), str(_battle_enemy_label(state, session, enemy_faction_id)));
	const ArrayRef enemy_survivors = enemy_survivor_stacks(state, session);
	const int64_t enemy_strength = _army_strength_from_stacks(state, array_value(enemy_survivors));
	const int64_t severity = engine_clamp<int64_t>(gd::add(1, float_to_int(compat::godot_floor(static_cast<double>(enemy_strength) / 150.0))), 1, 4);
	const int64_t strength_gold = float_to_int(compat::godot_round(static_cast<double>(enemy_strength) / 15.0));
	const DictRef desired_loss = state.new_dict();
	state.set(desired_loss, str(key::gold), int_value(gd::add(gd::add(140, gd::mul(severity, 110)), strength_gold)));
	state.set(desired_loss, str(key::wood), int_value(engine_max<int64_t>(0, severity)));
	state.set(desired_loss, str(key::ore), int_value(severity >= 2 ? 1 : 0));
	if (outcome == key::town_lost) {
		state.set(desired_loss, str(key::gold), int_value(gd::add(gd::int_field(state, desired_loss, key::gold, 0), 80)));
		state.set(desired_loss, str(key::wood), int_value(gd::add(gd::int_field(state, desired_loss, key::wood, 0), 1)));
	}
	state.set(preview, str(key::resource_loss), dict_value(_clamped_resource_loss(state, session, desired_loss)));
	const int64_t pressure_delta = enemy_faction_id != key::empty ? 2 + compat::int_div(severity, 2) + (outcome == key::town_lost ? 1 : 0) : 0;
	state.set(preview, str(key::pressure_delta), int_value(pressure_delta));
	const Value context = get_or_new_dict(state, session_battle(state, session), key::context);
	if (!_is_town_defense_context(state, context)) {
		state.set(preview, str(key::recovery_pressure), int_value(2 + (severity >= 3 ? 1 : 0)));
	}
	Atom target_town_id = key::empty;
	if (_is_town_defense_context(state, context)) {
		target_town_id = gd::stringify(state, ai::vget(state, context, key::town_placement_id, str(key::empty)));
	} else {
		const DictRef nearest_town_result = nearest_player_town(state, session);
		if (gd::int_field(state, nearest_town_result, key::index, -1) >= 0) {
			const Value town = get_or_new_dict(state, nearest_town_result, key::town);
			target_town_id = gd::stringify(state, ai::vget(state, town, key::placement_id, str(key::empty)));
		}
	}
	if (target_town_id != key::empty) {
		state.set(preview, str(key::nearest_town_placement_id), str(target_town_id));
		state.set(preview, str(key::nearest_town_name), str(_town_name_from_placement_id(state, session, target_town_id)));
	}
	return preview;
}

Atom _withdrawal_preview_summary(State &state, DictRef preview, Atom outcome) {
	std::vector<Atom> clauses;
	const int64_t casualty_units = gd::int_field(state, preview, key::casualty_units, 0);
	if (casualty_units > 0) {
		const Atom tail = outcome == key::surrender ? static_cast<Atom>(key::lost_while_the_enemy_collects_the) : static_cast<Atom>(key::lost_to_the_pursuit);
		clauses.push_back(gd::format(state, key::about_d_troop_s_s, { int_value(casualty_units), str(plural_s(casualty_units)), str(tail) }));
	}
	const Value resource_loss = get_or_new_dict(state, preview, key::resource_loss);
	const Atom resource_summary = overworld_rules::_describe_resource_delta(state, resource_loss);
	if (resource_summary != key::empty) {
		if (outcome == key::surrender) {
			clauses.push_back(gd::format(state, key::pay_s_to_the_enemy, { str(resource_summary) }));
		} else {
			clauses.push_back(gd::format(state, key::abandon_s_to_the_enemy, { str(resource_summary) }));
		}
	}
	const int64_t pressure_delta = gd::int_field(state, preview, key::pressure_delta, 0);
	const Atom enemy_label = string_of(state, preview, key::enemy_label, key::enemy_pressure);
	if (pressure_delta > 0) {
		clauses.push_back(gd::format(state, key::s_pressure_d, { str(enemy_label), int_value(pressure_delta) }));
	} else if (gd::int_field(state, preview, key::recovery_pressure, 0) > 0 && string_of(state, preview, key::nearest_town_name, key::empty) != key::empty) {
		const Atom town_name = string_of(state, preview, key::nearest_town_name, key::empty);
		clauses.push_back(gd::format(state, key::s_recovery_d, { str(town_name), int_value(gd::int_field(state, preview, key::recovery_pressure, 0)) }));
	}
	return join(state, clauses, key::space_bar_space);
}

Atom _withdrawal_resource_summary(State &state, Atom outcome, DictRef resource_loss, Atom enemy_label) {
	const Atom resource_summary = overworld_rules::_describe_resource_delta(state, dict_value(resource_loss));
	if (resource_summary == key::empty) {
		return key::empty;
	}
	if (outcome == key::surrender) {
		return gd::format(state, key::s_confiscates_s_as_surrender_terms, { str(enemy_label), str(resource_summary) });
	}
	if (enemy_label != key::empty) {
		return gd::format(state, key::s_seizes_s_from_the_baggage, { str(enemy_label), str(resource_summary) });
	}
	return gd::format(state, key::the_withdrawal_abandons_s_on_the, { str(resource_summary) });
}

Atom _collapse_resource_summary(State &state, Atom outcome, DictRef resource_loss, Atom enemy_label) {
	const Atom resource_summary = overworld_rules::_describe_resource_delta(state, dict_value(resource_loss));
	if (resource_summary == key::empty) {
		return key::empty;
	}
	if (outcome == key::town_lost) {
		return gd::format(state, key::s_strips_s_from_the_broken, { str(enemy_label), str(resource_summary) });
	}
	return gd::format(state, key::s_strips_s_from_the_routed, { str(enemy_label), str(resource_summary) });
}

DictRef _clamped_resource_loss(State &state, const Value &session, DictRef desired_loss) {
	// session.overworld.get("resources", {}), only read.
	Value available;
	const bool has_available = state.lookup(session_overworld(state, session), str(key::resources), available);
	const DictRef loss = state.new_dict();
	for (const Value &resource_key_value : gd::items(state, dict_value(desired_loss))) {
		const Atom resource_key = gd::stringify(state, resource_key_value);
		const int64_t desired = engine_max<int64_t>(0, gd::to_int(state, state.get(desired_loss, str(resource_key), int_value(0))));
		const Value held_value = has_available ? ai::vget(state, available, resource_key, int_value(0)) : int_value(0);
		const int64_t held = engine_max<int64_t>(0, gd::to_int(state, held_value));
		const int64_t amount = engine_min(desired, held);
		if (amount > 0) {
			state.set(loss, str(resource_key), int_value(amount));
		}
	}
	return loss;
}

int64_t _casualty_units_from_ratio(int64_t total_units, double ratio) {
	if (total_units <= 1) {
		return 0;
	}
	int64_t casualties = float_to_int(compat::godot_round(static_cast<double>(total_units) * engine_clamp(ratio, 0.0, 0.9)));
	if (casualties <= 0 && total_units >= 5 && ratio >= 0.12) {
		casualties = 1;
	}
	return clamp_untyped(casualties, 0, total_units - 1);
}

int64_t _remove_units_from_stacks(State &state, ArrayRef stacks, int64_t unit_losses) {
	const int64_t total_units = _stack_count_total(state, array_value(stacks));
	int64_t remaining_losses = engine_clamp<int64_t>(unit_losses, 0, engine_max<int64_t>(0, gd::sub(total_units, 1)));
	int64_t applied = 0;
	while (remaining_losses > 0 && state.array_size(stacks) != 0) {
		int64_t largest_index = -1;
		int64_t largest_count = -1;
		const int64_t size = state.array_size(stacks);
		for (int64_t index = 0; index < size; ++index) {
			const Value stack = state.at(stacks, index);
			if (!gd::is_dict(stack)) {
				continue;
			}
			const int64_t count = engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0));
			if (count > largest_count) {
				largest_count = count;
				largest_index = index;
			}
		}
		if (largest_index < 0 || largest_count <= 0) {
			break;
		}
		const Value target = state.at(stacks, largest_index);
		state.set(target.ref, str(key::count), int_value(engine_max<int64_t>(0, gd::sub(gd::int_field(state, target.ref, key::count, 0), 1))));
		if (gd::int_field(state, target.ref, key::count, 0) <= 0) {
			gd::remove_at(state, stacks, largest_index);
		} else {
			state.set_at(stacks, largest_index, target);
		}
		remaining_losses -= 1;
		applied += 1;
	}
	return applied;
}

int64_t _stack_count_total(State &state, const Value &stacks) {
	int64_t total = 0;
	if (!gd::is_array(stacks)) {
		return total;
	}
	for (const Value &stack : gd::items(state, stacks)) {
		if (gd::is_dict(stack)) {
			total = gd::add(total, engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0)));
		}
	}
	return total;
}

int64_t _army_strength_from_stacks(State &state, const Value &stacks) {
	int64_t total = 0;
	if (!gd::is_array(stacks)) {
		return total;
	}
	const int64_t size = state.array_size(stacks.ref);
	for (int64_t index = 0; index < size; ++index) {
		const Value stack = state.at(stacks.ref, index);
		if (!gd::is_dict(stack)) {
			continue;
		}
		const DictRef unit = gd::content_row(state, state::ContentTable::Unit, string_of(state, stack.ref, key::unit_id, key::empty));
		const int64_t count = engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0));
		int64_t power = gd::add(gd::int_field(state, unit, key::hp, 1), gd::int_field(state, unit, key::min_damage, 1));
		power = gd::add(power, gd::int_field(state, unit, key::max_damage, 1));
		power = gd::add(power, gd::bool_field(state, unit, key::ranged, false) ? 3 : 0);
		total = gd::add(total, gd::mul(count, engine_max<int64_t>(6, power)));
	}
	return total;
}

} // namespace aurelion::rules::port::battle_rules
