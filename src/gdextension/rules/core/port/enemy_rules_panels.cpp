// EnemyTurnRules and EnemyAdventureRules for the panels (Phase 7, slice 7.8):
// the public threat, posture and commander summaries.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp (Phase 5) and declared only there.
namespace enemy_turn_rules {
ArrayRef _enemy_faction_configs_for_session(State &state, DictRef session);
DictRef _find_state(State &state, const Value &states, Atom faction_id);
Atom _normalize_posture(State &state, const Value &value);
} // namespace enemy_turn_rules

namespace enemy_adventure_rules {
ArrayRef normalize_commander_roster(State &state, DictRef session, Atom faction_id, const Value &roster_value);
Value commander_roster_for_faction(State &state, DictRef session, Atom faction_id);
DictRef commander_army_continuity(State &state, const Value &source);
Atom commander_army_brief(State &state, const Value &source);
Atom commander_army_summary(State &state, const Value &source);
Atom _normalize_commander_status(State &state, const Value &value);
} // namespace enemy_adventure_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace player_rules = player_identity_rules;

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

// separator.join(parts) of Strings.
std::string join_texts(State &state, const char *separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += separator;
		}
		joined += state.text(parts[index]);
	}
	return joined;
}

// separator.join(array): each item as String(item).
Atom join_array(State &state, const char *separator, ArrayRef parts) {
	std::vector<Atom> atoms;
	for (const Value &part : gd::items(state, array_value(parts))) {
		atoms.push_back(string_of(state, part));
	}
	return state.intern(join_texts(state, separator, atoms));
}

// `roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)`.
Value roster_or_faction_roster(State &state, DictRef session, Atom faction_id, const Value &roster_value) {
	return gd::is_array(roster_value) ? roster_value : enemy_adventure_rules::commander_roster_for_faction(state, session, faction_id);
}

// The status of a roster entry, normalized.
Atom entry_status(State &state, DictRef entry) {
	return enemy_adventure_rules::_normalize_commander_status(state, state.get(entry, str(key::status), str(key::available)));
}

// One posture text per faction, or the fallback.
struct FactionText {
	Atom faction_id;
	Atom text;
};

Atom faction_text(Atom faction_id, std::initializer_list<FactionText> texts, Atom fallback) {
	for (const FactionText &entry : texts) {
		if (entry.faction_id == faction_id) {
			return entry.text;
		}
	}
	return fallback;
}

} // namespace

// EnemyTurnRules.

namespace enemy_turn_rules {

Atom describe_threats(State &state, DictRef session) {
	normalize_enemy_states(state, session);
	const ArrayRef configs = _enemy_faction_configs_for_session(state, session);
	if (state.array_size(configs) == 0) {
		return key::no_hostile_factions_are_active_3;
	}

	std::vector<Atom> lines;
	for (const Value &config : gd::items(state, array_value(configs))) {
		if (!gd::is_dict(config)) {
			continue;
		}
		// Only what a player could know: the rival's stance, its capital and the
		// heroes currently in sight.
		const Atom faction_id = player_rules::controller_id(state, config.ref, key::empty);
		const DictRef overworld = session_view::overworld(state, session);
		const DictRef enemy_state = _find_state(state, state.get(overworld, str(key::enemy_states), array_value(state.new_array())), faction_id);
		const DictRef front_state = _faction_front_state(state, session, faction_id);
		std::vector<Atom> line_parts;
		line_parts.push_back(text_or(state, config.ref, key::label, str(faction_id)));
		line_parts.push_back(_public_posture_label(state, enemy_state, 0, player_rules::faction_id(state, session, faction_id)));
		const Atom strategy_summary = enemy_adventure_rules::public_strategy_summary(state, config.ref, faction_id);
		if (strategy_summary != key::empty) {
			line_parts.push_back(strategy_summary);
		}
		const Atom capital_watch = _capital_watch_summary(state, _faction_capital_state(state, session, faction_id));
		if (capital_watch != key::empty) {
			line_parts.push_back(capital_watch);
		}
		const ArrayRef visible_heroes = _visible_raids_for_faction(state, session, faction_id);
		const ArrayRef hero_names = enemy_adventure_rules::raid_commander_summaries(state, visible_heroes, 2);
		if (state.array_size(hero_names) > 0) {
			std::string sighting = state.text(gd::format(state, key::heroes_sighted_s, { str(join_array(state, ", ", hero_names)) }));
			const int64_t hidden_count = compat::engine_max<int64_t>(0, gd::sub(state.array_size(visible_heroes), state.array_size(hero_names)));
			if (hidden_count > 0) {
				sighting += state.text(gd::format(state, key::d_more_3, { int_value(hidden_count) }));
			}
			line_parts.push_back(state.intern(sighting));
		}
		const Atom front_summary = text_or(state, front_state, key::summary, str(key::empty));
		if (front_summary != key::empty) {
			line_parts.push_back(front_summary);
		}
		lines.push_back(state.intern(join_texts(state, " | ", line_parts)));
	}

	return state.intern(join_texts(state, "\n", lines));
}

ArrayRef _visible_raids_for_faction(State &state, DictRef session, Atom faction_id) {
	const ArrayRef visible = state.new_array();
	const DictRef overworld = session_view::overworld(state, session);
	// The [] fallback holds no placement.
	Value resolved_encounters;
	const bool has_resolved = state.lookup(overworld, str(key::resolved_encounters), resolved_encounters);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter)) {
			continue;
		}
		if (player_rules::raid_controller_id(state, encounter.ref) != faction_id) {
			continue;
		}
		if (has_resolved && gd::is_array(resolved_encounters)
				&& gd::array_has(state, resolved_encounters.ref, str(text_or(state, encounter.ref, key::placement_id, str(key::empty))))) {
			continue;
		}
		if (!enemy_adventure_rules::_raid_is_public(state, session, encounter.ref)) {
			continue;
		}
		state.append(visible, encounter);
	}
	return visible;
}

Atom _public_posture_label(State &state, DictRef enemy_state, int64_t raid_threshold, Atom faction_id) {
	const Atom posture = _normalize_posture(state, state.get(enemy_state, str(key::posture), str(key::probing)));
	if (posture == key::reorganizing) {
		return faction_text(faction_id, {
			{ key::faction_embercourt, key::road_captains_are_reorganizing_after_the },
			{ key::faction_mireclaw, key::wounded_warbands_are_slipping_back_into },
			{ key::faction_sunvault, key::relay_commanders_are_recalibrating_after_the },
			{ key::faction_thornwake, key::graftwardens_are_regrowing_lanes_after_the },
			{ key::faction_brasshollow, key::foundry_officers_are_cooling_engines_before },
			{ key::faction_veilmourn, key::black_sail_crews_are_vanishing_into },
		}, key::hostile_commanders_are_regrouping_before_the);
	}
	if (posture == key::fortifying) {
		return faction_text(faction_id, {
			{ key::faction_embercourt, key::beacon_towns_are_drawing_disciplined_levies },
			{ key::faction_mireclaw, key::stockades_are_beating_the_drums_for },
			{ key::faction_sunvault, key::relay_keeps_are_locking_into_prepared },
			{ key::faction_thornwake, key::root_towns_are_thickening_bramble_roads },
			{ key::faction_brasshollow, key::foundries_are_plating_the_wall_engines },
			{ key::faction_veilmourn, key::bell_harbors_are_masking_their_docks },
		}, key::border_towns_are_pulling_fresh_troops);
	}
	if (posture == key::raiding) {
		return faction_text(faction_id, {
			{ key::faction_embercourt, key::charter_columns_are_pushing_measured_strikes },
			{ key::faction_mireclaw, key::warbands_are_spilling_forward_in_staggered },
			{ key::faction_sunvault, key::compact_sorties_are_testing_the_frontier },
			{ key::faction_thornwake, key::root_pilgrims_are_spreading_bramble_tolls },
			{ key::faction_brasshollow, key::contract_columns_are_rolling_engines_toward },
			{ key::faction_veilmourn, key::black_sail_crews_are_slipping_through },
		}, key::enemy_heroes_are_driving_into_the);
	}
	if (posture == key::massing) {
		if (gd::to_int(state, state.get(enemy_state, str(key::pressure), int_value(0))) >= gd::mul(raid_threshold, 2)) {
			return faction_text(faction_id, {
				{ key::faction_embercourt, key::a_heavier_charter_assault_is_assembling },
				{ key::faction_mireclaw, key::a_deeper_mire_surge_is_gathering },
				{ key::faction_sunvault, key::another_calibrated_battery_strike_is_aligning },
				{ key::faction_thornwake, key::a_rooted_nursery_front_is_spreading },
				{ key::faction_brasshollow, key::a_heavy_foundry_assault_is_staging },
				{ key::faction_veilmourn, key::a_deeper_fog_wake_is_gathering },
			}, key::a_heavier_strike_is_gathering_behind);
		}
		return faction_text(faction_id, {
			{ key::faction_embercourt, key::quartermasters_are_assembling_another_road_bound },
			{ key::faction_mireclaw, key::fresh_cutters_are_massing_for_another },
			{ key::faction_sunvault, key::arrays_are_lining_up_for_another },
			{ key::faction_thornwake, key::graft_hosts_are_massing_around_newly },
			{ key::faction_brasshollow, key::boiler_crews_are_massing_for_another },
			{ key::faction_veilmourn, key::mist_crews_are_massing_around_a },
		}, key::war_bands_are_massing_for_another);
	}
	if (posture == key::collapsed) {
		return key::the_hostile_empire_has_lost_its;
	}
	if (posture == key::attacking) {
		return key::enemy_heroes_are_on_the_attack;
	}
	if (posture == key::expanding) {
		return key::enemy_heroes_are_claiming_the_countryside;
	}
	if (posture == key::building) {
		return key::enemy_towns_are_building_up_their;
	}
	return faction_text(faction_id, {
		{ key::faction_embercourt, key::scouts_report_charter_patrols_measuring_the },
		{ key::faction_mireclaw, key::scouts_report_mire_runners_probing_for },
		{ key::faction_sunvault, key::scouts_report_relay_pickets_calibrating_the },
		{ key::faction_thornwake, key::scouts_report_root_pilgrims_seeding_the },
		{ key::faction_brasshollow, key::scouts_report_ore_contracts_and_pressure },
		{ key::faction_veilmourn, key::scouts_report_bell_wakes_sounding_from },
	}, key::scouts_report_patrols_probing_for_openings);
}

Atom _capital_watch_summary(State &state, DictRef capital_state) {
	Value active_labels;
	if (state.lookup(capital_state, str(key::active_project_labels), active_labels) && gd::is_array(active_labels)
			&& state.array_size(active_labels.ref) > 0) {
		std::vector<Atom> parts;
		parts.push_back(gd::format(state, key::capital_watch_s_online, { str(join_array(state, ", ", active_labels.ref)) }));
		if (gd::to_int(state, state.get(capital_state, str(key::support_gap), int_value(0))) > 0) {
			parts.push_back(gd::format(state, key::logistics_gaps_d, { int_value(gd::to_int(state, state.get(capital_state, str(key::support_gap), int_value(0)))) }));
		}
		if (gd::to_int(state, state.get(capital_state, str(key::recovery_pressure), int_value(0))) > 0) {
			parts.push_back(gd::format(state, key::recovery_d_4, { int_value(gd::to_int(state, state.get(capital_state, str(key::recovery_pressure), int_value(0)))) }));
		}
		return state.intern(join_texts(state, ", ", parts));
	}
	Value dormant_labels;
	if (state.lookup(capital_state, str(key::dormant_project_labels), dormant_labels) && gd::is_array(dormant_labels)
			&& state.array_size(dormant_labels.ref) > 0) {
		return gd::format(state, key::capital_watch_s_still_anchors_the, { str(join_array(state, ", ", dormant_labels.ref)) });
	}
	Value anchor_labels;
	if (state.lookup(capital_state, str(key::anchor_labels), anchor_labels) && gd::is_array(anchor_labels)
			&& state.array_size(anchor_labels.ref) > 0) {
		return gd::format(state, key::anchor_watch_s_remain_the_backbone, { str(join_array(state, ", ", anchor_labels.ref)) });
	}
	return key::empty;
}

} // namespace enemy_turn_rules

// EnemyAdventureRules.

namespace enemy_adventure_rules {

int64_t recovering_commander_count(State &state, DictRef session, Atom faction_id, const Value &roster_value) {
	int64_t count = 0;
	const ArrayRef roster = normalize_commander_roster(state, session, faction_id, roster_or_faction_roster(state, session, faction_id, roster_value));
	for (const Value &entry_value : gd::items(state, array_value(roster))) {
		if (!gd::is_dict(entry_value)) {
			continue;
		}
		if (entry_status(state, entry_value.ref) == key::recovering) {
			count = gd::add(count, 1);
		}
	}
	return count;
}

int64_t rebuilding_commander_count(State &state, DictRef session, Atom faction_id, const Value &roster_value) {
	int64_t count = 0;
	const ArrayRef roster = normalize_commander_roster(state, session, faction_id, roster_or_faction_roster(state, session, faction_id, roster_value));
	for (const Value &entry_value : gd::items(state, array_value(roster))) {
		if (!gd::is_dict(entry_value)) {
			continue;
		}
		const Atom status = entry_status(state, entry_value.ref);
		if (status == key::active || status == key::recovering) {
			continue;
		}
		const DictRef continuity = commander_army_continuity(state, entry_value);
		if (gd::is_empty(state, continuity) || gd::to_int(state, state.get(continuity, str(key::base_strength), int_value(0))) <= 0
				|| commander_can_deploy(state, entry_value)) {
			continue;
		}
		count = gd::add(count, 1);
	}
	return count;
}

Atom public_commander_recovery_summary(State &state, DictRef session, Atom faction_id, const Value &roster_value) {
	// session != null always: a session is its view.
	const int64_t session_day = gd::to_int(state, gd::index(state, session, str(key::day)));
	std::vector<Atom> recovering;
	const ArrayRef roster = normalize_commander_roster(state, session, faction_id, roster_or_faction_roster(state, session, faction_id, roster_value));
	for (const Value &entry_value : gd::items(state, array_value(roster))) {
		if (!gd::is_dict(entry_value)) {
			continue;
		}
		if (entry_status(state, entry_value.ref) != key::recovering) {
			continue;
		}
		const int64_t recovery_day = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(entry_value.ref, str(key::recovery_day), int_value(0))));
		const int64_t remaining_days = compat::engine_max<int64_t>(1, gd::sub(recovery_day, session_day));
		const Atom commander_name = commander_display_name(state, entry_value);
		if (commander_name == key::empty) {
			continue;
		}
		std::string descriptor = state.text(gd::format(state, key::dd, { int_value(remaining_days) }));
		const Atom army_brief = commander_army_brief(state, entry_value);
		if (army_brief != key::empty) {
			descriptor += state.text(gd::format(state, key::s_6, { str(army_brief) }));
		}
		recovering.push_back(gd::format(state, key::phrase_with_steps_text, { str(commander_name), str(state.intern(descriptor)) }));
		if (recovering.size() >= 2) {
			break;
		}
	}
	if (recovering.empty()) {
		return key::empty;
	}
	std::string summary = state.text(gd::format(state, key::command_recovering_s, { str(state.intern(join_texts(state, ", ", recovering))) }));
	const int64_t total_recovering = recovering_commander_count(state, session, faction_id, roster_or_faction_roster(state, session, faction_id, roster_value));
	const int64_t shown = static_cast<int64_t>(recovering.size());
	if (total_recovering > shown) {
		summary += state.text(gd::format(state, key::d_more_3, { int_value(gd::sub(total_recovering, shown)) }));
	}
	return state.intern(summary);
}

Atom public_commander_rebuild_summary(State &state, DictRef session, Atom faction_id, const Value &roster_value) {
	std::vector<Atom> rebuilding;
	const ArrayRef roster = normalize_commander_roster(state, session, faction_id, roster_or_faction_roster(state, session, faction_id, roster_value));
	for (const Value &entry_value : gd::items(state, array_value(roster))) {
		if (!gd::is_dict(entry_value)) {
			continue;
		}
		const Atom status = entry_status(state, entry_value.ref);
		if (status == key::active || status == key::recovering) {
			continue;
		}
		if (commander_can_deploy(state, entry_value)) {
			continue;
		}
		const Atom commander_name = commander_display_name(state, entry_value);
		const Atom army_summary = commander_army_summary(state, entry_value);
		if (commander_name == key::empty || army_summary == key::empty) {
			continue;
		}
		rebuilding.push_back(gd::format(state, key::phrase_with_steps_text, { str(commander_name), str(army_summary) }));
		if (rebuilding.size() >= 2) {
			break;
		}
	}
	if (rebuilding.empty()) {
		return key::empty;
	}
	std::string summary = state.text(gd::format(state, key::command_rebuilding_s, { str(state.intern(join_texts(state, ", ", rebuilding))) }));
	const int64_t total_rebuilding = rebuilding_commander_count(state, session, faction_id, roster_or_faction_roster(state, session, faction_id, roster_value));
	const int64_t shown = static_cast<int64_t>(rebuilding.size());
	if (total_rebuilding > shown) {
		summary += state.text(gd::format(state, key::d_more_3, { int_value(gd::sub(total_rebuilding, shown)) }));
	}
	return state.intern(summary);
}

ArrayRef raid_commander_summaries(State &state, ArrayRef encounters, int64_t limit) {
	const ArrayRef names = state.new_array();
	for (const Value &encounter : gd::items(state, array_value(encounters))) {
		if (!gd::is_dict(encounter)) {
			continue;
		}
		const Atom commander_name = raid_commander_display_name(state, encounter.ref);
		if (commander_name == key::empty || gd::array_has(state, names, str(commander_name))) {
			continue;
		}
		state.append(names, str(commander_name));
		if (limit > 0 && state.array_size(names) >= limit) {
			break;
		}
	}
	return names;
}

Atom public_strategy_summary(State &state, DictRef config, Atom faction_id) {
	if (faction_id == key::faction_embercourt) {
		Value targets;
		const bool has_targets = state.lookup(config, str(key::priority_target_placement_ids), targets);
		// A missing list reads as a new [], which is empty.
		if (!has_targets || !gd::is_array(targets) || state.array_size(targets.ref) == 0) {
			return key::priorities_hold_towns_reinforce_outposts_and;
		}
		return key::priorities_stabilize_the_line_defend_charter;
	}
	if (faction_id == key::faction_mireclaw) {
		return key::priorities_cut_logistics_sites_chase_exposed;
	}
	if (faction_id == key::faction_sunvault) {
		return key::priorities_secure_relays_and_shrines_then;
	}
	if (faction_id == key::faction_thornwake) {
		return key::priorities_root_roads_hold_nurseries_and;
	}
	if (faction_id == key::faction_brasshollow) {
		return key::priorities_secure_mines_stage_siege_engines;
	}
	if (faction_id == key::faction_veilmourn) {
		return key::priorities_scout_hidden_routes_mark_weak;
	}
	return key::priorities_pressure_objectives_while_contesting_frontier;
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
