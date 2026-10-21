// OverworldRules: a town's logistics, the support plan its role sets, the
// state of the sites that feed it and the penalties of its gaps.

#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>

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

// separator.join(items) of an Array of Strings.
Atom join_items(State &state, Atom separator, ArrayRef items) {
	std::string joined;
	const int64_t count = state.array_size(items);
	for (int64_t index = 0; index < count; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += gd::text(state, state.at(items, index));
	}
	return state.intern(joined);
}

// s.to_lower() of ASCII text (the Unicode case tables are not ported).
Atom to_lower(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

} // namespace

namespace overworld_rules {

DictRef _town_logistics_state(State &state, DictRef session, DictRef town) {
	const Atom cache_key = _town_read_scope_cache_key(state, session, key::logistics, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef result = _compute_town_logistics_state(state, session, town);
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

DictRef _compute_town_logistics_state(State &state, DictRef session, DictRef town) {
	const DictRef empty_state = _empty_town_logistics_state(state);
	if (gd::is_empty(state, town)) {
		return empty_state;
	}
	const Atom controller_id = _town_controller_id(state, town);
	if (controller_id == key::empty) {
		return empty_state;
	}
	const DictRef plan = _town_logistics_plan(state, town);
	const int64_t support_radius = gd::int_field(state, plan, key::support_radius, 0);
	const DictRef family_counts = state.new_dict();
	const ArrayRef held_site_labels = state.new_array();
	const ArrayRef disrupted_site_labels = state.new_array();
	const ArrayRef threatened_site_labels = state.new_array();
	const ArrayRef response_site_labels = state.new_array();
	const ArrayRef delivery_site_labels = state.new_array();
	int64_t held_site_count = 0;
	int64_t disrupted_count = 0;
	int64_t threatened_count = 0;
	int64_t response_count = 0;
	int64_t delivery_count = 0;
	int64_t quality_bonus = 0;
	int64_t readiness_bonus = 0;
	int64_t pressure_bonus = 0;
	int64_t growth_bonus_percent = 0;
	int64_t recovery_relief_bonus = 0;
	int64_t response_quality_bonus = 0;
	int64_t response_readiness_bonus = 0;
	int64_t response_pressure_bonus = 0;
	int64_t response_recovery_relief_bonus = 0;
	int64_t response_growth_bonus_percent = 0;
	int64_t response_pressure_guard_bonus = 0;
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node)) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node.ref, key::site_id));
		if (!_resource_site_is_persistent(state, site)) {
			continue;
		}
		const Atom family = ai::string_or_empty(state, site, key::family);
		if (family == key::empty) {
			continue;
		}
		const DictRef town_result = _resource_node_linked_town(state, session, node.ref, controller_id);
		if (gd::int_field(state, town_result, key::index, -1) < 0) {
			continue;
		}
		// town_result.get("town", {}).get("placement_id", ""): a missing town reads "".
		Value assigned_town;
		const Atom assigned_placement_id = state.lookup(town_result, str(key::town), assigned_town)
				? gd::stringify(state, ai::vget(state, assigned_town, key::placement_id, str(key::empty)))
				: key::empty;
		if (assigned_placement_id != ai::string_or_empty(state, town, key::placement_id)) {
			continue;
		}
		const bool threatened = _resource_site_under_threat(state, session, node.ref, controller_id);
		const Atom site_name = gd::stringify(state, gd::field_or(state, site, key::name, str(key::frontier_site)));
		const Atom controller = player_identity_rules::resource_controller_id(state, node.ref);
		if (controller == controller_id) {
			held_site_count = gd::add(held_site_count, 1);
			state.set(family_counts, str(family), int_value(gd::add(gd::int_field(state, family_counts, family, 0), 1)));
			state.append(held_site_labels, str(site_name));
			const DictRef support = _resource_site_town_support(state, site);
			quality_bonus = gd::add(quality_bonus, gd::int_field(state, support, key::quality_bonus, 0));
			readiness_bonus = gd::add(readiness_bonus, gd::int_field(state, support, key::readiness_bonus, 0));
			pressure_bonus = gd::add(pressure_bonus, gd::int_field(state, support, key::pressure_bonus, 0));
			growth_bonus_percent = gd::add(growth_bonus_percent, gd::int_field(state, support, key::growth_bonus_percent, 0));
			recovery_relief_bonus = gd::add(recovery_relief_bonus, gd::int_field(state, support, key::recovery_relief, 0));
			const DictRef response_state = _resource_site_response_state(state, session, node.ref, site);
			if (gd::bool_field(state, response_state, key::active, false)) {
				response_count = gd::add(response_count, 1);
				state.append(response_site_labels, str(gd::format(state, key::s_escort_dd, {str(site_name), int_value(gd::int_field(state, response_state, key::remaining_days, 0))})));
				response_quality_bonus = gd::add(response_quality_bonus, gd::int_field(state, response_state, key::quality_bonus, 0));
				response_readiness_bonus = gd::add(response_readiness_bonus, gd::int_field(state, response_state, key::readiness_bonus, 0));
				response_pressure_bonus = gd::add(response_pressure_bonus, gd::int_field(state, response_state, key::pressure_bonus, 0));
				response_recovery_relief_bonus = gd::add(response_recovery_relief_bonus, gd::int_field(state, response_state, key::recovery_relief, 0));
				response_growth_bonus_percent = gd::add(response_growth_bonus_percent, gd::int_field(state, response_state, key::growth_bonus_percent, 0));
				response_pressure_guard_bonus = gd::add(response_pressure_guard_bonus, gd::int_field(state, response_state, key::pressure_guard_bonus, 0));
				const DictRef delivery_state = _resource_site_delivery_state(state, session, node.ref, site);
				if (gd::bool_field(state, delivery_state, key::active, false)) {
					delivery_count = gd::add(delivery_count, 1);
					state.append(delivery_site_labels, str(_resource_site_delivery_line(state, session, node.ref, site)));
				}
			}
			if (threatened) {
				threatened_count = gd::add(threatened_count, 1);
				state.append(threatened_site_labels, str(site_name));
			}
		} else {
			disrupted_count = gd::add(disrupted_count, 1);
			state.append(disrupted_site_labels, str(site_name));
			if (threatened) {
				threatened_count = gd::add(threatened_count, 1);
				state.append(threatened_site_labels, str(site_name));
			}
		}
	}
	Value support_requirements;
	if (!state.lookup(plan, str(key::support_requirements), support_requirements)) {
		support_requirements = dict_value(state.new_dict());
	}
	const DictRef requirement_progress = _support_requirement_progress(state, dict_value(family_counts), support_requirements);
	Value missing_family_labels;
	if (!state.lookup(requirement_progress, str(key::missing_family_labels), missing_family_labels)) {
		missing_family_labels = array_value(state.new_array());
	}
	const DictRef gap_penalties = _town_logistics_gap_penalties(state, town, gd::int_field(state, requirement_progress, key::support_gap, 0));
	const ArrayRef summary_parts = state.new_array();
	Atom grade = key::stable;
	if (held_site_count <= 0 && gd::int_field(state, requirement_progress, key::required_total, 0) > 0) {
		grade = key::broken;
	} else if (disrupted_count > 0 || threatened_count > 0 || gd::int_field(state, requirement_progress, key::support_gap, 0) > 0) {
		grade = key::strained;
	}
	state.append(summary_parts, str(gd::format(state, key::s_chain, {str(gd::capitalize(state, grade))})));
	if (gd::int_field(state, requirement_progress, key::required_total, 0) > 0) {
		state.append(summary_parts, str(gd::format(state, key::d_d_anchors, {int_value(gd::int_field(state, requirement_progress, key::met_requirements, 0)), int_value(gd::int_field(state, requirement_progress, key::required_total, 0))})));
	} else if (held_site_count > 0) {
		state.append(summary_parts, str(gd::format(state, key::d_linked, {int_value(held_site_count)})));
	}
	if (disrupted_count > 0) {
		state.append(summary_parts, str(gd::format(state, key::d_denied, {int_value(disrupted_count)})));
	}
	if (threatened_count > 0) {
		state.append(summary_parts, str(gd::format(state, key::d_threatened, {int_value(threatened_count)})));
	}
	if (response_count > 0) {
		state.append(summary_parts, str(gd::format(state, key::d_escorted, {int_value(response_count)})));
	}
	if (delivery_count > 0) {
		state.append(summary_parts, str(gd::format(state, key::d_convoy_s, {int_value(delivery_count), str(delivery_count == 1 ? key::empty : key::s)})));
	}
	if (gd::is_array(missing_family_labels) && state.array_size(missing_family_labels.ref) != 0) {
		state.append(summary_parts, str(gd::format(state, key::missing_s, {str(join_items(state, key::comma_space, missing_family_labels.ref))})));
	}
	const ArrayRef impact_parts = state.new_array();
	if (quality_bonus > 0) {
		state.append(impact_parts, str(gd::format(state, key::quality_d, {int_value(quality_bonus)})));
	}
	if (readiness_bonus > 0) {
		state.append(impact_parts, str(gd::format(state, key::readiness_d, {int_value(readiness_bonus)})));
	}
	if (pressure_bonus > 0) {
		state.append(impact_parts, str(gd::format(state, key::s_d_2, {str(_town_pressure_label(state, town)), int_value(pressure_bonus)})));
	}
	if (growth_bonus_percent > 0) {
		state.append(impact_parts, str(gd::format(state, key::recruits_d, {int_value(growth_bonus_percent)})));
	}
	if (recovery_relief_bonus > 0) {
		state.append(impact_parts, str(gd::format(state, key::recovery_d_day, {int_value(recovery_relief_bonus)})));
	}
	if (response_quality_bonus > 0) {
		state.append(impact_parts, str(gd::format(state, key::response_d_quality, {int_value(response_quality_bonus)})));
	}
	if (response_readiness_bonus > 0) {
		state.append(impact_parts, str(gd::format(state, key::response_d_readiness, {int_value(response_readiness_bonus)})));
	}
	if (response_pressure_bonus > 0) {
		const Atom label = to_lower(state, _town_pressure_label(state, town), "OverworldRules._compute_town_logistics_state");
		state.append(impact_parts, str(gd::format(state, key::response_d_s, {int_value(response_pressure_bonus), str(label)})));
	}
	if (response_recovery_relief_bonus > 0) {
		state.append(impact_parts, str(gd::format(state, key::response_d_day_recovery, {int_value(response_recovery_relief_bonus)})));
	}
	if (response_growth_bonus_percent > 0) {
		state.append(impact_parts, str(gd::format(state, key::response_d_recruits, {int_value(response_growth_bonus_percent)})));
	}
	if (response_pressure_guard_bonus > 0) {
		state.append(impact_parts, str(gd::format(state, key::escort_d_pressure_guard, {int_value(response_pressure_guard_bonus)})));
	}
	if (gd::int_field(state, gap_penalties, key::quality_penalty, 0) > 0) {
		state.append(impact_parts, str(gd::format(state, key::gap_d_quality, {int_value(gd::int_field(state, gap_penalties, key::quality_penalty, 0))})));
	}
	if (gd::int_field(state, gap_penalties, key::readiness_penalty, 0) > 0) {
		state.append(impact_parts, str(gd::format(state, key::gap_d_readiness, {int_value(gd::int_field(state, gap_penalties, key::readiness_penalty, 0))})));
	}
	if (gd::int_field(state, gap_penalties, key::pressure_penalty, 0) > 0) {
		const int64_t pressure_penalty = gd::int_field(state, gap_penalties, key::pressure_penalty, 0);
		const Atom label = to_lower(state, _town_pressure_label(state, town), "OverworldRules._compute_town_logistics_state");
		state.append(impact_parts, str(gd::format(state, key::gap_d_s, {int_value(pressure_penalty), str(label)})));
	}
	if (gd::int_field(state, gap_penalties, key::growth_penalty_percent, 0) > 0) {
		state.append(impact_parts, str(gd::format(state, key::gap_d_recruits, {int_value(gd::int_field(state, gap_penalties, key::growth_penalty_percent, 0))})));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::plan), dict_value(plan));
	state.set(result, str(key::summary), str(join_items(state, key::space_bar_space, summary_parts)));
	state.set(result, str(key::impact_summary), str(join_items(state, key::comma_space, impact_parts)));
	state.set(result, str(key::grade), str(grade));
	state.set(result, str(key::support_radius), int_value(support_radius));
	state.set(result, str(key::held_site_count), int_value(held_site_count));
	state.set(result, str(key::disrupted_count), int_value(disrupted_count));
	state.set(result, str(key::threatened_count), int_value(threatened_count));
	state.set(result, str(key::response_count), int_value(response_count));
	state.set(result, str(key::delivery_count), int_value(delivery_count));
	state.set(result, str(key::held_site_labels), array_value(held_site_labels));
	state.set(result, str(key::disrupted_site_labels), array_value(disrupted_site_labels));
	state.set(result, str(key::threatened_site_labels), array_value(threatened_site_labels));
	state.set(result, str(key::response_site_labels), array_value(response_site_labels));
	state.set(result, str(key::delivery_site_labels), array_value(delivery_site_labels));
	state.set(result, str(key::family_counts), dict_value(family_counts));
	state.set(result, str(key::met_requirements), int_value(gd::int_field(state, requirement_progress, key::met_requirements, 0)));
	state.set(result, str(key::required_total), int_value(gd::int_field(state, requirement_progress, key::required_total, 0)));
	state.set(result, str(key::support_gap), int_value(gd::int_field(state, requirement_progress, key::support_gap, 0)));
	state.set(result, str(key::missing_family_labels), missing_family_labels);
	state.set(result, str(key::quality_bonus), int_value(quality_bonus));
	state.set(result, str(key::readiness_bonus), int_value(readiness_bonus));
	state.set(result, str(key::pressure_bonus), int_value(pressure_bonus));
	state.set(result, str(key::growth_bonus_percent), int_value(growth_bonus_percent));
	state.set(result, str(key::recovery_relief_bonus), int_value(recovery_relief_bonus));
	state.set(result, str(key::response_quality_bonus), int_value(response_quality_bonus));
	state.set(result, str(key::response_readiness_bonus), int_value(response_readiness_bonus));
	state.set(result, str(key::response_pressure_bonus), int_value(response_pressure_bonus));
	state.set(result, str(key::response_recovery_relief_bonus), int_value(response_recovery_relief_bonus));
	state.set(result, str(key::response_growth_bonus_percent), int_value(response_growth_bonus_percent));
	state.set(result, str(key::response_pressure_guard_bonus), int_value(response_pressure_guard_bonus));
	state.set(result, str(key::gap_quality_penalty), int_value(gd::int_field(state, gap_penalties, key::quality_penalty, 0)));
	state.set(result, str(key::gap_readiness_penalty), int_value(gd::int_field(state, gap_penalties, key::readiness_penalty, 0)));
	state.set(result, str(key::gap_pressure_penalty), int_value(gd::int_field(state, gap_penalties, key::pressure_penalty, 0)));
	state.set(result, str(key::gap_growth_penalty_percent), int_value(gd::int_field(state, gap_penalties, key::growth_penalty_percent, 0)));
	return result;
}

Atom _town_strategic_role(State &state, DictRef town) {
	const DictRef town_row = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const Atom role = ai::string_or_empty(state, town_row, key::strategic_role);
	return role == key::capital || role == key::stronghold ? role : key::frontier;
}

Atom _town_controller_id(State &state, DictRef town) {
	if (gd::stringify(state, gd::field_or(state, town, key::owner, str(key::neutral))) == key::player) {
		return key::player;
	}
	if (gd::stringify(state, gd::field_or(state, town, key::owner, str(key::neutral))) == key::enemy) {
		return player_identity_rules::town_controller_id(state, town);
	}
	return key::empty;
}

DictRef _town_logistics_plan(State &state, DictRef town) {
	const DictRef town_row = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	Value plan;
	if (!state.lookup(town_row, str(key::logistics_plan), plan)) {
		plan = dict_value(state.new_dict());
	}
	const Atom role = _town_strategic_role(state, town);
	const DictRef result = state.new_dict();
	const Value support_radius = ai::vget(state, plan, key::support_radius, int_value(_default_logistics_support_radius(state, role)));
	state.set(result, str(key::support_radius), int_value(compat::engine_max<int64_t>(0, gd::to_int(state, support_radius))));
	const Value support_requirements = ai::vget(state, plan, key::support_requirements, dict_value(_default_logistics_requirements_for_role(state, role)));
	state.set(result, str(key::support_requirements), dict_value(_normalize_support_requirements(state, support_requirements)));
	state.set(result, str(key::recovery_relief), int_value(compat::engine_max<int64_t>(0, gd::to_int(state, ai::vget(state, plan, key::recovery_relief, int_value(0))))));
	state.set(result, str(key::vulnerability_summary), str(gd::stringify(state, ai::vget(state, plan, key::vulnerability_summary, str(key::empty)))));
	return result;
}

int64_t _default_logistics_support_radius(State &state, Atom role) {
	(void)state;
	if (role == key::capital) {
		return 7;
	}
	if (role == key::stronghold) {
		return 6;
	}
	return 5;
}

DictRef _default_logistics_requirements_for_role(State &state, Atom role) {
	const DictRef requirements = state.new_dict();
	state.set(requirements, str(key::faction_outpost), int_value(1));
	if (role == key::capital || role == key::stronghold) {
		state.set(requirements, str(key::frontier_shrine), int_value(1));
	}
	return requirements;
}

DictRef _normalize_support_requirements(State &state, const Value &value) {
	const DictRef normalized = state.new_dict();
	if (gd::is_dict(value)) {
		// value.keys(): the loop does not change value.
		for (const Value &family_id_value : gd::items(state, value)) {
			const Atom family_id = gd::stringify(state, family_id_value);
			// LOGISTICS_SITE_FAMILIES.
			if (family_id != key::faction_outpost && family_id != key::frontier_shrine) {
				continue;
			}
			const int64_t count = gd::to_int(state, state.get(value.ref, str(family_id), int_value(0)));
			state.set(normalized, str(family_id), int_value(compat::engine_max<int64_t>(0, count)));
		}
	}
	return normalized;
}

DictRef _support_requirement_progress(State &state, const Value &family_counts, const Value &requirements) {
	int64_t met_requirements = 0;
	int64_t required_total = 0;
	const ArrayRef missing_family_labels = state.new_array();
	if (!gd::is_dict(requirements)) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::met_requirements), int_value(met_requirements));
		state.set(result, str(key::required_total), int_value(required_total));
		state.set(result, str(key::support_gap), int_value(0));
		state.set(result, str(key::missing_family_labels), array_value(missing_family_labels));
		return result;
	}
	// requirements.keys(): the loop does not change requirements.
	for (const Value &family_id_value : gd::items(state, requirements)) {
		const Atom family_id = gd::stringify(state, family_id_value);
		const int64_t required_count = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(requirements.ref, str(family_id), int_value(0))));
		if (required_count <= 0) {
			continue;
		}
		required_total = gd::add(required_total, required_count);
		const int64_t held_count = gd::is_dict(family_counts) ? gd::to_int(state, state.get(family_counts.ref, str(family_id), int_value(0))) : 0;
		met_requirements = gd::add(met_requirements, compat::engine_min<int64_t>(required_count, held_count));
		if (held_count < required_count) {
			state.append(missing_family_labels, str(_resource_site_family_short_label(state, family_id)));
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::met_requirements), int_value(met_requirements));
	state.set(result, str(key::required_total), int_value(required_total));
	state.set(result, str(key::support_gap), int_value(compat::engine_max<int64_t>(0, gd::sub(required_total, met_requirements))));
	state.set(result, str(key::missing_family_labels), array_value(missing_family_labels));
	return result;
}

DictRef _empty_town_logistics_state(State &state) {
	const DictRef plan = state.new_dict();
	state.set(plan, str(key::support_radius), int_value(0));
	state.set(plan, str(key::support_requirements), dict_value(state.new_dict()));
	state.set(plan, str(key::recovery_relief), int_value(0));
	state.set(plan, str(key::vulnerability_summary), str(key::empty));
	const DictRef result = state.new_dict();
	state.set(result, str(key::plan), dict_value(plan));
	state.set(result, str(key::summary), str(key::empty));
	state.set(result, str(key::impact_summary), str(key::empty));
	state.set(result, str(key::grade), str(key::stable));
	state.set(result, str(key::support_radius), int_value(0));
	state.set(result, str(key::held_site_count), int_value(0));
	state.set(result, str(key::disrupted_count), int_value(0));
	state.set(result, str(key::threatened_count), int_value(0));
	state.set(result, str(key::response_count), int_value(0));
	state.set(result, str(key::delivery_count), int_value(0));
	state.set(result, str(key::held_site_labels), array_value(state.new_array()));
	state.set(result, str(key::disrupted_site_labels), array_value(state.new_array()));
	state.set(result, str(key::threatened_site_labels), array_value(state.new_array()));
	state.set(result, str(key::response_site_labels), array_value(state.new_array()));
	state.set(result, str(key::delivery_site_labels), array_value(state.new_array()));
	state.set(result, str(key::family_counts), dict_value(state.new_dict()));
	state.set(result, str(key::met_requirements), int_value(0));
	state.set(result, str(key::required_total), int_value(0));
	state.set(result, str(key::support_gap), int_value(0));
	state.set(result, str(key::missing_family_labels), array_value(state.new_array()));
	state.set(result, str(key::quality_bonus), int_value(0));
	state.set(result, str(key::readiness_bonus), int_value(0));
	state.set(result, str(key::pressure_bonus), int_value(0));
	state.set(result, str(key::growth_bonus_percent), int_value(0));
	state.set(result, str(key::recovery_relief_bonus), int_value(0));
	state.set(result, str(key::response_quality_bonus), int_value(0));
	state.set(result, str(key::response_readiness_bonus), int_value(0));
	state.set(result, str(key::response_pressure_bonus), int_value(0));
	state.set(result, str(key::response_recovery_relief_bonus), int_value(0));
	state.set(result, str(key::response_growth_bonus_percent), int_value(0));
	state.set(result, str(key::response_pressure_guard_bonus), int_value(0));
	state.set(result, str(key::gap_quality_penalty), int_value(0));
	state.set(result, str(key::gap_readiness_penalty), int_value(0));
	state.set(result, str(key::gap_pressure_penalty), int_value(0));
	state.set(result, str(key::gap_growth_penalty_percent), int_value(0));
	return result;
}

DictRef _town_logistics_gap_penalties(State &state, DictRef town, int64_t support_gap) {
	const DictRef penalties = state.new_dict();
	state.set(penalties, str(key::quality_penalty), int_value(0));
	state.set(penalties, str(key::readiness_penalty), int_value(0));
	state.set(penalties, str(key::pressure_penalty), int_value(0));
	state.set(penalties, str(key::growth_penalty_percent), int_value(0));
	if (support_gap <= 0) {
		return penalties;
	}
	const Atom role = _town_strategic_role(state, town);
	if (role == key::capital) {
		state.set(penalties, str(key::quality_penalty), int_value(gd::mul(support_gap, 4)));
		state.set(penalties, str(key::readiness_penalty), int_value(gd::mul(support_gap, 5)));
		state.set(penalties, str(key::pressure_penalty), int_value(support_gap));
		state.set(penalties, str(key::growth_penalty_percent), int_value(gd::mul(support_gap, 8)));
	} else if (role == key::stronghold) {
		state.set(penalties, str(key::quality_penalty), int_value(gd::mul(support_gap, 3)));
		state.set(penalties, str(key::readiness_penalty), int_value(gd::mul(support_gap, 4)));
		state.set(penalties, str(key::pressure_penalty), int_value(support_gap));
		state.set(penalties, str(key::growth_penalty_percent), int_value(gd::mul(support_gap, 6)));
	}
	return penalties;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
