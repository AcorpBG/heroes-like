#include "aurelion_rules/port/adventure_services.hpp"
// VisitBuildingRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/visit_building_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;
// String(site.get("name", fallback)).
Atom site_name(State &state, DictRef site, Atom fallback) {
	return gd::stringify(state, gd::field_or(state, site, key::name, str(fallback)));
}
// {"ok": false, "message": message}.
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

} // namespace

namespace visit_building_rules {

bool is_visit_building(State &state, DictRef site) {
	if (ai::string_or_empty(state, site, key::family) != key::visit_building) {
		return false;
	}
	Value visit;
	return !state.lookup(site, str(key::visit), visit) || gd::is_dict(visit);
}

DictRef spec(State &state, DictRef site) {
	Value value;
	if (state.lookup(site, str(key::visit), value) && gd::is_dict(value)) {
		return value.ref;
	}
	return state.new_dict();
}

Atom cadence(State &state, DictRef site) {
	return gd::stringify(state, gd::field_or(state, spec(state, site), key::cadence, str(key::once_per_hero)));
}

DictRef cost(State &state, DictRef site, Atom choice_id) {
	if (choice_id != key::empty) {
		for (const Value &choice : gd::items(state, array_value(choices(state, site)))) {
			if (!gd::is_dict(choice) || ai::string_or_empty(state, choice.ref, key::id) != choice_id) {
				continue;
			}
			Value choice_cost;
			if (state.lookup(choice.ref, str(key::cost), choice_cost) && gd::is_dict(choice_cost) && !gd::is_empty(state, choice_cost.ref)) {
				return gd::deep_duplicate_dict(state, choice_cost.ref);
			}
		}
	}
	return ai::duplicate_field(state, spec(state, site), key::cost);
}

int64_t week_index(State &state, int64_t day) {
	(void)state;
	const int64_t first = day > 1 ? day : 1;
	return compat::float_to_int(compat::godot_floor(static_cast<double>(gd::sub(first, 1)) / 7.0));
}

int64_t required_level(State &state, DictRef site) {
	const int64_t level = gd::int_field(state, spec(state, site), key::required_level, 0);
	return level > 0 ? level : 0;
}

ArrayRef choices(State &state, DictRef site) {
	Value value;
	if (state.lookup(spec(state, site), str(key::choices), value) && gd::is_array(value)) {
		return value.ref;
	}
	return state.new_array();
}

DictRef effects(State &state, DictRef site, Atom choice_id) {
	if (choice_id != key::empty) {
		for (const Value &choice : gd::items(state, array_value(choices(state, site)))) {
			if (gd::is_dict(choice) && ai::string_or_empty(state, choice.ref, key::id) == choice_id) {
				return ai::duplicate_field(state, choice.ref, key::effects);
			}
		}
		return state.new_dict();
	}
	return ai::duplicate_field(state, spec(state, site), key::effects);
}

DictRef readiness(State &state, DictRef node, DictRef site, Atom visitor_key, int64_t day, Atom side) {
	// visits: an empty Dictionary when missing or not one.
	Value visits;
	const bool has_visits = state.lookup(node, str(key::hero_visits), visits) && gd::is_dict(visits);
	const bool visited = has_visits && state.has(visits.ref, str(visitor_key));
	const Atom mode = cadence(state, site);
	if (mode == key::always) {
		// pass
	} else if (mode == key::once_per_side) {
		Value side_visits;
		if (state.lookup(node, str(key::side_visits), side_visits) && gd::is_dict(side_visits) && state.has(side_visits.ref, str(side != key::empty ? side : visitor_key))) {
			return refusal(state, gd::format(state, key::you_have_already_used_s_what, {str(site_name(state, site, key::this_site))}));
		}
	} else if (mode == key::weekly_site) {
		const int64_t last_site_day = gd::int_field(state, node, key::site_last_visit_day, 0);
		if (last_site_day > 0 && week_index(state, last_site_day) == week_index(state, day)) {
			const Atom name = site_name(state, site, key::this_site_2);
			return refusal(state, gd::format(state, key::s_is_spent_until_the_new, {str(name), int_value(gd::add(gd::mul(gd::add(week_index(state, day), 1), 7), 1))}));
		}
	} else if (mode == key::weekly_per_hero) {
		if (visited && week_index(state, gd::to_int(state, gd::index(state, visits.ref, str(visitor_key)))) == week_index(state, day)) {
			return refusal(state, gd::format(state, key::this_hero_already_visited_s_this, {str(site_name(state, site, key::this_site))}));
		}
	} else if (mode == key::daily_per_hero) {
		if (visited && gd::to_int(state, gd::index(state, visits.ref, str(visitor_key))) >= day) {
			return refusal(state, gd::format(state, key::this_hero_already_visited_s_today, {str(site_name(state, site, key::this_site))}));
		}
	} else if (visited) {
		return refusal(state, gd::format(state, key::this_hero_has_already_visited_s, {str(site_name(state, site, key::this_site))}));
	}
	const DictRef ready = state.new_dict();
	state.set(ready, str(key::ok), bool_value(true));
	state.set(ready, str(key::message), str(key::empty));
	return ready;
}

int64_t ai_value(State &state, DictRef site) {
	if (adventure_services::handles(state, site)) {
		auto service = gd::stringify(state, gd::field(state, site, state.intern("adventure_service")));
		if (service == state.intern("intelligence")) return 350;
		if (service == state.intern("freelancer_guild")) return 300;
		return 900;
	}
	if (!ai::static_bool(state, key::visit_building_rules_script, key::_ai_weights_ready)) {
		apply_ai_weights(state, content_service::default_ai_hero_weights(state));
	}
	DictRef effect = effects(state, site, key::empty);
	if (state.array_size(choices(state, site)) != 0) {
		const Value first = state.at(choices(state, site), 0);
		if (gd::is_dict(first)) {
			Value chosen;
			effect = state.lookup(first.ref, str(key::effects), chosen) ? gd::as_dict(chosen) : state.new_dict();
		} else {
			effect = state.new_dict();
		}
	}
	int64_t value = 0;
	// stats: an empty Dictionary when missing.
	Value stats;
	const bool has_stats = state.lookup(effect, str(key::stats), stats);
	if (!has_stats || gd::is_dict(stats)) {
		for (const Atom stat : {key::attack, key::defense, key::power, key::knowledge}) {
			const int64_t stat_value = ai::static_int(state, key::visit_building_rules_script, key::AI_STAT_VALUE);
			const int64_t points = has_stats ? gd::int_field(state, stats.ref, stat, 0) : 0;
			value = gd::add(value, gd::mul(stat_value, points > 0 ? points : 0));
		}
	}
	const double experience = static_cast<double>(gd::int_field(state, effect, key::experience, 0));
	value = gd::add(value, compat::float_to_int(experience * ai::static_float(state, key::visit_building_rules_script, key::AI_EXPERIENCE_SHARE)));
	const int64_t level_value = ai::static_int(state, key::visit_building_rules_script, key::AI_LEVEL_VALUE);
	const int64_t levels = gd::int_field(state, effect, key::levels, 0);
	value = gd::add(value, gd::mul(level_value, levels > 0 ? levels : 0));
	const int64_t tier_value = ai::static_int(state, key::visit_building_rules_script, key::AI_SPELL_TIER_VALUE);
	const int64_t spell_tier = gd::int_field(state, effect, key::spell_tier, 0);
	value = gd::add(value, gd::mul(tier_value, spell_tier > 0 ? spell_tier : 0));
	const double gold = static_cast<double>(gd::int_field(state, cost(state, site, key::empty), key::gold, 0));
	value = gd::sub(value, compat::float_to_int(gold * ai::static_float(state, key::visit_building_rules_script, key::AI_COST_SHARE)));
	return value > 0 ? value : 0;
}

void apply_ai_weights(State &state, DictRef weights) {
	const Atom script = key::visit_building_rules_script;
	ai::assign_int(state, script, key::AI_STAT_VALUE, weights, key::visit_stat_value);
	ai::assign_float(state, script, key::AI_EXPERIENCE_SHARE, weights, key::visit_experience_share);
	ai::assign_int(state, script, key::AI_LEVEL_VALUE, weights, key::visit_level_value);
	ai::assign_int(state, script, key::AI_SPELL_TIER_VALUE, weights, key::visit_spell_tier_value);
	ai::assign_float(state, script, key::AI_COST_SHARE, weights, key::visit_cost_share);
	gd::set_static_var(state, script, key::_ai_weights_ready, bool_value(true));
}

} // namespace visit_building_rules

} // namespace aurelion::rules::port
