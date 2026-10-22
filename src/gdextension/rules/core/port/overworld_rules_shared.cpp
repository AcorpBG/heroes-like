// OverworldRules ports shared by the computer players' day (Phase 4) and the ends of
// a battle (Phase 5): the debug rules profile, the spatial lookup cache, town control
// changes with their front and occupation, town recovery and town weekly growth.

#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"

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

constexpr Atom kScript = key::overworld_rules_script;

// d.get(field, {}) / d.get(field, []) passed on or stored: the value, or a new container.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value array_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// max(a, b) of two ints (untyped): a, unless it is less than b.
int64_t vmax(int64_t a, int64_t b) {
	return a < b ? b : a;
}

// {"ok": false, "changed": false, "town": {}}.
DictRef no_control_change(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::changed), bool_value(false));
	state.set(result, str(key::town), dict_value(state.new_dict()));
	return result;
}

// var entry: Dictionary = context.get(field, {}); false when it is empty (the caller computes it).
bool context_entry(State &state, DictRef context, Atom field, DictRef &out) {
	Value found;
	if (!state.lookup(context, str(field), found)) {
		return false;
	}
	out = gd::as_dict(found);
	return !gd::is_empty(state, out);
}

bool rules_profile_active(State &state) {
	return ai::static_bool(state, kScript, key::_movement_rules_profile_active);
}

} // namespace

namespace overworld_rules {

int64_t _rules_profile_timer(State &state) {
	return rules_profile_active(state) ? gd::ticks_usec() : 0;
}

void _rules_profile_add_ms(State &state, Atom bucket, int64_t started_usec) {
	if (!rules_profile_active(state) || started_usec <= 0 || bucket == key::empty) {
		return;
	}
	const DictRef profile = ai::static_dict(state, kScript, key::_movement_rules_profile);
	const DictRef buckets = gd::as_dict(dict_or_new(state, profile, key::sub_buckets_ms));
	const double before = gd::to_float(state.get(buckets, str(bucket), gd::float_value(0.0)));
	const double elapsed = static_cast<double>(compat::engine_max<int64_t>(0, gd::sub(gd::ticks_usec(), started_usec)));
	state.set(buckets, str(bucket), gd::float_value(compat::snappedf(before + elapsed / 1000.0, 0.001)));
	state.set(profile, str(key::sub_buckets_ms), dict_value(buckets));
}

void _rules_profile_set(State &state, Atom section, Atom name, const Value &value) {
	if (!rules_profile_active(state) || section == key::empty || name == key::empty) {
		return;
	}
	const DictRef profile = ai::static_dict(state, kScript, key::_movement_rules_profile);
	Value found;
	const DictRef target = state.lookup(profile, str(section), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	state.set(target, str(name), value);
	state.set(profile, str(section), dict_value(target));
}

DictRef _add_dwelling_town_growth(State &state, DictRef session, DictRef town, DictRef growth) {
	const Atom controller = _town_controller_id(state, town);
	if (controller == key::empty || gd::is_empty(state, growth)) {
		return growth;
	}
	const DictRef held = state.new_dict();
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node) || player_identity_rules::resource_controller_id(state, node.ref) != controller) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node.ref, key::site_id));
		if (!creature_dwelling_rules::is_dwelling(state, site) || creature_dwelling_rules::is_refugee_camp(state, site)) {
			continue;
		}
		const ArrayRef units = creature_dwelling_rules::creatures(state, node.ref, site, ai::session_int(state, session, key::day));
		for (const Value &unit_id : gd::items(state, array_value(units))) {
			const Atom base = creature_dwelling_rules::base_unit_id(state, gd::stringify(state, unit_id));
			state.set(held, str(base), int_value(gd::add(gd::int_field(state, held, base, 0), 1)));
		}
	}
	if (gd::is_empty(state, held)) {
		return growth;
	}
	const DictRef result = gd::deep_duplicate_dict(state, growth);
	const ArrayRef unit_ids = gd::keys(state, result);
	for (const Value &unit_id : gd::items(state, array_value(unit_ids))) {
		const Atom base = creature_dwelling_rules::base_unit_id(state, gd::stringify(state, unit_id));
		if (state.has(held, str(base))) {
			const int64_t count = gd::to_int(state, gd::index(state, result, unit_id));
			const int64_t bonus = gd::to_int(state, gd::index(state, held, str(base)));
			state.set(result, unit_id, int_value(gd::add(count, bonus)));
		}
	}
	return result;
}

DictRef transition_town_control(State &state, DictRef session, Atom placement_id, Atom new_owner, Atom controlling_faction_id, Atom source) {
	if (placement_id == key::empty) {
		return no_control_change(state);
	}
	const DictRef town_result = _find_town_by_placement(state, session, placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return no_control_change(state);
	}
	const Value towns = array_or_new(state, session_view::overworld(state, session), key::towns);
	DictRef town = gd::as_dict(dict_or_new(state, town_result, key::town));
	const Atom previous_owner = gd::stringify(state, state.get(town, str(key::owner), str(key::neutral)));
	const Atom previous_controller = player_identity_rules::town_controller_id(state, town);
	if (controlling_faction_id == key::empty && previous_owner == key::enemy) {
		controlling_faction_id = previous_controller;
	}
	if (previous_owner != new_owner && previous_owner == key::player) {
		town = _release_town_occupation_reserves(state, town);
	}
	state.set(town, str(key::owner), str(new_owner));
	if (new_owner == key::enemy) {
		state.set(town, str(key::controlling_faction_id), str(player_identity_rules::faction_id(state, session, controlling_faction_id)));
		const DictRef controlling_player = player_identity_rules::player(state, session, controlling_faction_id);
		state.set(town, str(key::controlling_player_id), str(ai::string_or_empty(state, controlling_player, key::player_id)));
	} else {
		state.set(town, str(key::controlling_faction_id), str(key::empty));
		if (new_owner == key::player && ai::string_or_empty(state, session_view::overworld(state, session), key::active_player_id) != key::empty) {
			const Value active_player_id = gd::index(state, session_view::overworld(state, session), str(key::active_player_id));
			state.set(town, str(key::controlling_player_id), str(gd::stringify(state, active_player_id)));
		} else {
			state.erase(town, str(key::controlling_player_id));
		}
	}
	const DictRef owning_player = player_identity_rules::player(state, session, ai::string_or_empty(state, town, key::controlling_player_id));
	if (!gd::is_empty(state, owning_player)) {
		state.set(town, str(key::team_id), str(ai::string_or_empty(state, owning_player, key::team_id)));
	} else {
		state.erase(town, str(key::team_id));
	}
	const DictRef front = _town_front_after_control_change(state, session, town, previous_owner, new_owner, controlling_faction_id, source);
	state.set(town, str(key::front), dict_value(front));
	// town.get("available_recruits", {}): a missing entry reads as an empty Dictionary.
	Value available_recruits;
	const bool has_recruits = state.lookup(town, str(key::available_recruits), available_recruits);
	const bool recruits_dict = !has_recruits || gd::is_dict(available_recruits);
	if (new_owner == key::player &&
			(!recruits_dict || (previous_owner != key::enemy && recruits_dict && (!has_recruits || gd::is_empty(state, available_recruits.ref))))) {
		state.set(town, str(key::available_recruits), dict_value(_seed_recruits_for_town(state, town)));
	}
	const DictRef occupation = _town_occupation_after_control_change(state, session, town, previous_owner, new_owner, controlling_faction_id, source);
	state.set(town, str(key::occupation), dict_value(occupation));
	state.set_at(gd::as_array(towns), gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	if (new_owner == key::player) {
		_teach_visiting_town_spells(state, session, town);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(previous_owner != new_owner || previous_controller != player_identity_rules::town_controller_id(state, town)));
	state.set(result, str(key::previous_owner), str(previous_owner));
	state.set(result, str(key::town), dict_value(town));
	return result;
}

void invalidate_spatial_lookup(State &state, DictRef session) {
	ai::meta_remove(state, session, key::_overworld_spatial_lookup_indexes);
	ai::meta_remove(state, session, key::_overworld_spatial_lookup_signature);
}

DictRef _town_weekly_growth(State &state, DictRef town, const Value &session, DictRef metric_context) {
	const DictRef growth = _seed_recruits_for_town(state, town);
	if (session.kind == Kind::Nil) {
		return growth;
	}
	const DictRef view = gd::as_dict(session);
	int64_t growth_percent = 0;
	DictRef logistics = 0;
	if (!context_entry(state, metric_context, key::logistics, logistics)) {
		logistics = _town_logistics_state(state, view, town);
	}
	growth_percent = gd::add(growth_percent, gd::int_field(state, logistics, key::growth_bonus_percent, 0));
	growth_percent = gd::add(growth_percent, gd::int_field(state, logistics, key::response_growth_bonus_percent, 0));
	growth_percent = gd::sub(growth_percent, gd::int_field(state, logistics, key::gap_growth_penalty_percent, 0));
	DictRef recovery = 0;
	if (!context_entry(state, metric_context, key::recovery, recovery)) {
		recovery = _town_recovery_state(state, view, town, logistics);
	}
	growth_percent = gd::sub(growth_percent, gd::int_field(state, recovery, key::growth_penalty_percent, 0));
	DictRef capital_project = 0;
	if (!context_entry(state, metric_context, key::capital_project, capital_project)) {
		capital_project = _town_capital_project_state(state, town, session, logistics, recovery);
	}
	growth_percent = gd::sub(growth_percent, gd::int_field(state, capital_project, key::growth_penalty_percent, 0));
	DictRef occupation = 0;
	if (!context_entry(state, metric_context, key::occupation, occupation)) {
		occupation = _town_occupation_state(state, view, town);
	}
	growth_percent = gd::sub(growth_percent, gd::int_field(state, occupation, key::growth_penalty_percent, 0));
	return _add_dwelling_town_growth(state, view, town, _apply_recruit_percent(state, dict_value(growth), growth_percent));
}

DictRef _town_front_after_control_change(State &state, DictRef session, DictRef town, Atom previous_owner, Atom new_owner, Atom controlling_faction_id, Atom source) {
	const DictRef front = _normalize_town_front_state(state, dict_or_new(state, town, key::front));
	Atom faction_id = controlling_faction_id;
	if (faction_id == key::empty && previous_owner == key::enemy) {
		faction_id = _normalized_enemy_front_faction_id(state, session, front, town);
	}
	if (faction_id == key::empty && new_owner == key::enemy) {
		faction_id = _normalized_enemy_front_faction_id(state, session, front, town);
	}
	if (previous_owner == new_owner) {
		if (new_owner == key::enemy && faction_id != key::empty) {
			return _town_front_stabilizing_state(state, session, town, faction_id, source);
		}
		return front;
	}
	if (new_owner == key::player) {
		if (faction_id == key::empty) {
			return _normalize_town_front_state(state, dict_value(state.new_dict()));
		}
		state.set(front, str(key::state), str(key::retake));
		gd::merge(state, front, player_identity_rules::identity_fields(state, session, faction_id), true);
		state.set(front, str(key::last_change_day), int_value(ai::session_int(state, session, key::day)));
		state.set(front, str(key::stabilize_until_day), int_value(0));
		state.set(front, str(key::last_owner), str(previous_owner));
		state.set(front, str(key::capture_count), int_value(vmax(1, gd::add(gd::int_field(state, front, key::capture_count, 0), 1))));
		state.set(front, str(key::source), str(source));
		return front;
	}
	if (new_owner == key::enemy) {
		if (faction_id == key::empty) {
			return _normalize_town_front_state(state, dict_value(state.new_dict()));
		}
		return _town_front_stabilizing_state(state, session, town, faction_id, source, previous_owner);
	}
	return _normalize_town_front_state(state, dict_value(state.new_dict()));
}

DictRef _town_front_stabilizing_state(State &state, DictRef session, DictRef town, Atom faction_id, Atom source, Atom previous_owner, int64_t bonus_days) {
	const DictRef front = _normalize_town_front_state(state, dict_or_new(state, town, key::front));
	state.set(front, str(key::state), str(key::stabilizing));
	gd::merge(state, front, player_identity_rules::identity_fields(state, session, faction_id), true);
	state.set(front, str(key::last_change_day), int_value(ai::session_int(state, session, key::day)));
	const int64_t day = ai::session_int(state, session, key::day);
	const int64_t days = compat::engine_clamp<int64_t>(gd::add(_town_front_stabilize_days(state, session, town), vmax(0, bonus_days)), 2, 8);
	state.set(front, str(key::stabilize_until_day), int_value(gd::add(day, days)));
	if (previous_owner != key::empty) {
		state.set(front, str(key::last_owner), str(previous_owner));
	}
	state.set(front, str(key::capture_count), int_value(vmax(1, gd::int_field(state, front, key::capture_count, 0))));
	state.set(front, str(key::source), str(source));
	return front;
}

int64_t _town_front_stabilize_days(State &state, DictRef session, DictRef town) {
	int64_t days = 2;
	const Atom role = _town_strategic_role(state, town);
	if (role == key::capital) {
		days += 2;
	} else if (role == key::stronghold) {
		days += 1;
	}
	if (_town_is_objective_anchor(state, session, ai::string_or_empty(state, town, key::placement_id))) {
		days += 1;
	}
	if (gd::bool_field(state, _town_recovery_state(state, session, town, state.new_dict()), key::active, false)) {
		days += 1;
	}
	return compat::engine_clamp<int64_t>(days, 2, 6);
}

DictRef _town_occupation_after_control_change(State &state, DictRef session, DictRef town, Atom previous_owner, Atom new_owner, Atom controlling_faction_id, Atom source) {
	const DictRef occupation = _normalize_town_occupation_state(state, dict_or_new(state, town, key::occupation));
	if (previous_owner == new_owner) {
		if (new_owner != key::player) {
			return _normalize_town_occupation_state(state, dict_value(state.new_dict()));
		}
		return occupation;
	}
	if (new_owner != key::player) {
		return _normalize_town_occupation_state(state, dict_value(state.new_dict()));
	}
	if (previous_owner != key::enemy) {
		return _normalize_town_occupation_state(state, dict_value(state.new_dict()));
	}
	Atom faction_id = controlling_faction_id;
	if (faction_id == key::empty) {
		faction_id = _town_faction_id(state, town);
	}
	if (faction_id == key::empty) {
		return _normalize_town_occupation_state(state, dict_value(state.new_dict()));
	}
	const int64_t pressure = _town_occupation_seed_pressure(state, session, town);
	state.set(occupation, str(key::state), str(key::pacifying));
	gd::merge(state, occupation, player_identity_rules::identity_fields(state, session, faction_id), true);
	state.set(occupation, str(key::pressure), int_value(pressure));
	state.set(occupation, str(key::initial_pressure), int_value(pressure));
	state.set(occupation, str(key::start_day), gd::index(state, session, str(key::day)));
	state.set(occupation, str(key::last_event_day), gd::index(state, session, str(key::day)));
	state.set(occupation, str(key::last_owner), str(previous_owner));
	state.set(occupation, str(key::source), str(source));
	state.set(occupation, str(key::locked_recruits), dict_value(state.new_dict()));
	_lock_town_occupation_reserves(state, town, occupation);
	return occupation;
}

DictRef _apply_recruit_percent(State &state, const Value &recruits, int64_t percent_modifier) {
	const DictRef adjusted = state.new_dict();
	if (!gd::is_dict(recruits)) {
		return adjusted;
	}
	const ArrayRef unit_ids = gd::keys(state, recruits.ref);
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t base_count = vmax(0, gd::to_int(state, state.get(recruits.ref, str(unit_id), int_value(0))));
		if (unit_id == key::empty) {
			continue;
		}
		if (base_count <= 0) {
			state.set(adjusted, str(unit_id), int_value(0));
			continue;
		}
		// max(0.0, float(100 + percent_modifier)) of the untyped max.
		const double percent = static_cast<double>(gd::add(100, percent_modifier));
		const double scale = 0.0 < percent ? percent : 0.0;
		const double scaled = static_cast<double>(base_count) * scale / 100.0;
		state.set(adjusted, str(unit_id), int_value(vmax(0, compat::float_to_int(compat::godot_round(scaled)))));
	}
	return adjusted;
}

bool _town_is_objective_anchor(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return false;
	}
	// GDScript also reads the scenario record here, and never uses it.
	const Value objectives = scenario_rules::objectives_for_session(state, session);
	if (!gd::is_dict(objectives)) {
		return false;
	}
	const Atom buckets[2] = {key::victory, key::defeat};
	for (const Atom bucket : buckets) {
		for (const Value &objective : gd::field_items(state, objectives.ref, str(bucket))) {
			if (gd::is_dict(objective) && ai::string_or_empty(state, objective.ref, key::placement_id) == placement_id) {
				return true;
			}
		}
	}
	return false;
}

void _lock_town_occupation_reserves(State &state, DictRef town, DictRef occupation) {
	if (gd::is_empty(state, town)) {
		return;
	}
	const DictRef available = _normalize_recruit_payload(state, dict_or_new(state, town, key::available_recruits));
	if (gd::is_empty(state, available)) {
		state.set(occupation, str(key::locked_recruits), dict_value(state.new_dict()));
		return;
	}
	const int64_t access_percent = compat::engine_clamp<int64_t>(gd::sub(80, gd::mul(gd::int_field(state, occupation, key::initial_pressure, 0), 8)), 20, 55);
	const DictRef accessible = state.new_dict();
	const DictRef locked = state.new_dict();
	const ArrayRef unit_ids = gd::keys(state, available);
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t count = vmax(0, gd::to_int(state, state.get(available, str(unit_id), int_value(0))));
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		int64_t released = compat::float_to_int(compat::godot_floor(static_cast<double>(count) * static_cast<double>(access_percent) / 100.0));
		if (released <= 0) {
			released = 1;
		}
		released = compat::engine_clamp<int64_t>(released, 0, count);
		if (released > 0) {
			state.set(accessible, str(unit_id), int_value(released));
		}
		if (count > released) {
			state.set(locked, str(unit_id), int_value(gd::sub(count, released)));
		}
	}
	state.set(town, str(key::available_recruits), dict_value(accessible));
	state.set(occupation, str(key::locked_recruits), dict_value(locked));
}

DictRef _release_town_occupation_reserves(State &state, DictRef town) {
	const DictRef occupation = _normalize_town_occupation_state(state, dict_or_new(state, town, key::occupation));
	const DictRef locked = _normalize_recruit_payload(state, dict_or_new(state, occupation, key::locked_recruits));
	if (!gd::is_empty(state, locked)) {
		state.set(town, str(key::available_recruits), dict_value(_add_recruit_growth(state, dict_or_new(state, town, key::available_recruits), dict_value(locked))));
	}
	state.set(town, str(key::occupation), dict_value(_normalize_town_occupation_state(state, dict_value(state.new_dict()))));
	return town;
}

DictRef town_recovery_state(State &state, DictRef session, DictRef town) {
	const Atom cache_key = _town_read_scope_cache_key(state, session, key::recovery, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef result = _town_recovery_state(state, session, town, state.new_dict());
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

Atom apply_town_recovery_pressure(State &state, DictRef session, Atom town_placement_id, int64_t amount, Atom source) {
	if (town_placement_id == key::empty || amount <= 0) {
		return key::empty;
	}
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return key::empty;
	}
	const Value towns = array_or_new(state, session_view::overworld(state, session), key::towns);
	const DictRef town = gd::as_dict(dict_or_new(state, town_result, key::town));
	const DictRef recovery = _normalize_town_recovery_state(state, dict_or_new(state, town, key::recovery));
	state.set(recovery, str(key::pressure), int_value(gd::add(vmax(0, gd::int_field(state, recovery, key::pressure, 0)), amount)));
	state.set(recovery, str(key::last_event_day), int_value(ai::session_int(state, session, key::day)));
	state.set(recovery, str(key::source), str(source));
	state.set(town, str(key::recovery), dict_value(recovery));
	state.set_at(gd::as_array(towns), gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	const DictRef recovery_state = town_recovery_state(state, session, town);
	const Atom source_clause = source != key::empty ? gd::format(state, key::from_s, {str(source)}) : key::empty;
	const int64_t days_to_clear = gd::int_field(state, recovery_state, key::days_to_clear, 0);
	return gd::format(state, key::s_recovery_d_s_d_day, {str(_town_name(state, town)), int_value(amount), str(source_clause), int_value(days_to_clear), str(days_to_clear == 1 ? key::empty : key::s)});
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
