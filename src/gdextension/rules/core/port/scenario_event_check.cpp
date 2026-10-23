// ScenarioRules for the human seat's actions (Phase 7, slice 7.2): the
// scenario check narrowed to an action's event facts (evaluate_session_for_event).

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <initializer_list>

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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(x): stringify(), and the engine's for a float or a container.
Atom string_of_value(State &state, const Value &value) {
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
Atom string_of(State &state, DictRef dict, Atom name, Atom fallback) {
	return string_of_value(state, state.get(dict, str(name), str(fallback)));
}

void put(State &state, DictRef dict, Atom name, const Value &value) {
	state.set(dict, str(name), value);
}

// d.clear(): every key erased, in order.
void dict_clear(State &state, DictRef dict) {
	const ArrayRef keys = gd::keys(state, dict);
	const int64_t size = state.array_size(keys);
	for (int64_t index = 0; index < size; ++index) {
		state.erase(dict, state.at(keys, index));
	}
}

// The dependency lists _scenario_event_dependency, _scenario_event_affects_dependency
// and _merge_dependency walk, in their order.
constexpr Atom kDependencyKeys[] = {
	key::town_placement_ids,
	key::town_ids,
	key::resource_site_placement_ids,
	key::flags,
	key::enemy_pressure_faction_ids,
	key::active_raid_faction_ids,
	key::encounter_placement_ids,
	key::hook_ids,
	key::resources,
	key::artifact_ids,
	key::spell_ids,
	key::building_ids,
	key::hero_ids,
	key::unit_ids,
};

// The metadata _scenario_dependency_metadata_for_session answers when it knows
// nothing: {"known": false, "unknown_reason": reason, ...}.
DictRef unknown_metadata(State &state, Atom reason) {
	const DictRef result = state.new_dict();
	put(state, result, key::known, bool_value(false));
	put(state, result, key::unknown_reason, str(reason));
	put(state, result, key::objective_count, int_value(0));
	put(state, result, key::hook_count, int_value(0));
	put(state, result, key::objectives, array_value(state.new_array()));
	put(state, result, key::hooks, array_value(state.new_array()));
	put(state, result, key::cache_hit, bool_value(false));
	put(state, result, key::signature, str(key::empty));
	return result;
}

// {"status": status, "message": "", "profile": profile}.
DictRef status_result(State &state, const Value &status, DictRef profile) {
	const DictRef result = state.new_dict();
	put(state, result, key::status, status);
	put(state, result, key::message, str(key::empty));
	put(state, result, key::profile, dict_value(profile));
	return result;
}

// The objectives of both buckets by id, as _scenario_dependency_metadata and
// _scenario_hook_dependency index them (an objective without an id is left out).
void index_objectives(State &state, const Value &objectives, DictRef objective_index) {
	for (const Atom bucket_name : { key::victory, key::defeat }) {
		Value bucket;
		if (!state.lookup(objectives.ref, str(bucket_name), bucket) || !gd::is_array(bucket)) {
			continue;
		}
		for (const Value &objective : gd::items(state, bucket)) {
			if (!gd::is_dict(objective)) {
				continue;
			}
			const Atom objective_id = string_of(state, objective.ref, key::id, key::empty);
			if (objective_id != key::empty) {
				state.set(objective_index, str(objective_id), objective);
			}
		}
	}
}

// JSON.stringify(value): natively where json_stringify covers the value (a
// shadow check may not run the engine), else the engine's.
Atom json_text(State &state, const Value &value) {
	try {
		return state.intern(gd::json_stringify(state, value));
	} catch (const state::NotPorted &) {
		return gd::engine_json_stringify(state, value);
	}
}

} // namespace

namespace generated_scenario_objective_rules {
bool uses_kind(State &state, DictRef scenario);
} // namespace generated_scenario_objective_rules

namespace scenario_rules {

DictRef evaluate_session_for_event(State &state, DictRef session, DictRef event_facts) {
	normalize_scenario_state(state, session, true);
	const DictRef profile = _scenario_event_dependency_profile(state, session, event_facts);
	// session == null cannot happen: a session is its view.
	if (string_of(state, session, key::scenario_id, key::empty) == key::empty) {
		put(state, profile, key::dependency_mode, str(key::full_fallback_unknown));
		put(state, profile, key::fallback_reason, str(key::missing_session_or_scenario));
		const DictRef result = state.new_dict();
		put(state, result, key::status, str(key::invalid));
		put(state, result, key::message, str(key::empty));
		put(state, result, key::profile, dict_value(profile));
		return result;
	}

	if (string_of(state, session, key::scenario_status, key::empty) != key::in_progress) {
		put(state, profile, key::dependency_mode, str(key::full_fallback_not_in_progress));
		put(state, profile, key::fallback_reason, str(key::scenario_not_in_progress));
		const DictRef inactive_result = evaluate_session(state, session);
		put(state, inactive_result, key::profile, dict_value(profile));
		return inactive_result;
	}

	if (gd::is_empty(state, event_facts) || gd::bool_field(state, event_facts, key::requires_full_scenario_eval, false)) {
		put(state, profile, key::dependency_mode, str(key::full));
		put(state, profile, key::fallback_reason, str(string_of(state, event_facts, key::fallback_reason, key::no_event_facts)));
		put(state, profile, key::fallback_used, bool_value(true));
		const DictRef full_result = evaluate_session(state, session);
		put(state, full_result, key::profile, dict_value(profile));
		return full_result;
	}

	const DictRef dependency = _scenario_dependency_metadata_for_session(state, session);
	put(state, profile, key::objective_count, int_value(gd::int_field(state, dependency, key::objective_count, 0)));
	put(state, profile, key::hook_count, int_value(gd::int_field(state, dependency, key::hook_count, 0)));
	put(state, profile, key::dependency_metadata_known, bool_value(gd::bool_field(state, dependency, key::known, false)));
	put(state, profile, key::dependency_cache_hit, bool_value(gd::bool_field(state, dependency, key::cache_hit, false)));
	put(state, profile, key::dependency_cache_signature, str(string_of(state, dependency, key::signature, key::empty)));
	if (!gd::bool_field(state, dependency, key::known, false)) {
		put(state, profile, key::dependency_mode, str(key::full_fallback_unknown));
		put(state, profile, key::fallback_reason, str(string_of(state, dependency, key::unknown_reason, key::unknown_dependency)));
		put(state, profile, key::fallback_used, bool_value(true));
		const DictRef unknown_result = evaluate_session(state, session);
		put(state, unknown_result, key::profile, dict_value(profile));
		return unknown_result;
	}

	const DictRef event_dependency = _scenario_event_dependency(state, event_facts);
	if (gd::bool_field(state, event_dependency, key::broad, false)) {
		put(state, profile, key::dependency_mode, str(key::full_fallback_unknown));
		put(state, profile, key::fallback_reason, str(string_of(state, event_dependency, key::reason, key::broad_event)));
		put(state, profile, key::fallback_used, bool_value(true));
		const DictRef broad_result = evaluate_session(state, session);
		put(state, broad_result, key::profile, dict_value(profile));
		return broad_result;
	}

	if (gd::int_field(state, profile, key::objective_count, 0) == 0 && gd::int_field(state, profile, key::hook_count, 0) == 0) {
		put(state, profile, key::dependency_mode, str(key::event_gated_skip));
		put(state, profile, key::skip_reason, str(key::no_observable_dependencies));
		put(state, profile, key::fallback_reason, str(key::empty));
		return status_result(state, str(string_of(state, session, key::scenario_status, key::empty)), profile);
	}

	// var objectives: Array = dependency.get("objectives", []) if ... is Array else []
	int64_t affected_objectives = 0;
	Value objectives;
	if (state.lookup(dependency, str(key::objectives), objectives) && gd::is_array(objectives)) {
		for (const Value &objective_dependency : gd::items(state, objectives)) {
			if (gd::is_dict(objective_dependency) && _scenario_event_affects_dependency(state, event_dependency, objective_dependency.ref)) {
				affected_objectives = gd::add(affected_objectives, 1);
			}
		}
	}
	int64_t affected_hooks = 0;
	Value hooks;
	if (state.lookup(dependency, str(key::hooks), hooks) && gd::is_array(hooks)) {
		for (const Value &hook_dependency : gd::items(state, hooks)) {
			if (gd::is_dict(hook_dependency) && _scenario_event_affects_dependency(state, event_dependency, hook_dependency.ref)) {
				affected_hooks = gd::add(affected_hooks, 1);
			}
		}
	}

	put(state, profile, key::objectives_checked, int_value(affected_objectives));
	put(state, profile, key::objectives_skipped, int_value(compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, profile, key::objective_count, 0), affected_objectives))));
	put(state, profile, key::hooks_checked, int_value(affected_hooks));
	put(state, profile, key::hooks_skipped, int_value(compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, profile, key::hook_count, 0), affected_hooks))));
	put(state, profile, key::affected_objective_count, int_value(affected_objectives));
	put(state, profile, key::affected_hook_count, int_value(affected_hooks));
	if (affected_objectives <= 0 && affected_hooks <= 0) {
		put(state, profile, key::dependency_mode, str(key::event_gated_skip));
		put(state, profile, key::skip_reason, str(key::no_affected_dependencies));
		put(state, profile, key::fallback_reason, str(key::empty));
		return status_result(state, str(string_of(state, session, key::scenario_status, key::empty)), profile);
	}

	put(state, profile, key::dependency_mode, str(key::scoped));
	put(state, profile, key::fallback_reason, str(key::empty));
	put(state, profile, key::semantic_evaluation, str(key::full_existing_evaluator_for_affected_dependencies));
	const DictRef scoped_result = evaluate_session(state, session);
	put(state, scoped_result, key::profile, dict_value(profile));
	return scoped_result;
}

DictRef _scenario_event_dependency_profile(State &state, DictRef session, DictRef event_facts) {
	(void)session;
	const DictRef profile = state.new_dict();
	put(state, profile, key::dependency_mode, str(key::full));
	put(state, profile, key::fallback_reason, str(key::empty));
	// String(event_facts.get("event_type", event_facts.get("event", "")))
	const Value event_fallback = state.get(event_facts, str(key::event), str(key::empty));
	put(state, profile, key::event_type, str(string_of_value(state, state.get(event_facts, str(key::event_type), event_fallback))));
	put(state, profile, key::event_family, str(string_of(state, event_facts, key::family, key::empty)));
	put(state, profile, key::objective_count, int_value(0));
	put(state, profile, key::hook_count, int_value(0));
	put(state, profile, key::objectives_checked, int_value(0));
	put(state, profile, key::objectives_skipped, int_value(0));
	put(state, profile, key::hooks_checked, int_value(0));
	put(state, profile, key::hooks_skipped, int_value(0));
	put(state, profile, key::affected_objective_count, int_value(0));
	put(state, profile, key::affected_hook_count, int_value(0));
	put(state, profile, key::dependency_metadata_known, bool_value(false));
	put(state, profile, key::dependency_cache_hit, bool_value(false));
	put(state, profile, key::dependency_cache_signature, str(key::empty));
	put(state, profile, key::fallback_used, bool_value(false));
	put(state, profile, key::skip_reason, str(key::empty));
	return profile;
}

DictRef _scenario_dependency_metadata_for_session(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	const Atom scenario_id = string_of(state, session, key::scenario_id, key::empty);
	if (scenario_id == key::empty) {
		return unknown_metadata(state, key::missing_scenario_id_2);
	}
	const DictRef source = scenario_record_for_session(state, session);
	DictRef dependency_record;
	if (generated_scenario_objective_rules::uses_kind(state, source)) {
		dependency_record = state.new_dict();
		put(state, dependency_record, key::objectives, state.get(source, str(key::objectives), dict_value(state.new_dict())));
		put(state, dependency_record, key::script_hooks, state.get(source, str(key::script_hooks), array_value(state.new_array())));
		// JSON.stringify(dependency_record).sha256_text()
		const Atom json = json_text(state, dict_value(dependency_record));
		put(state, dependency_record, key::dependency_signature, str(state.intern(compat::sha256_text(state.text(json)))));
	} else {
		dependency_record = gd::as_dict(gd::call_method(state, gd::autoload(state, key::ContentService), key::get_scenario_dependency_record, { str(scenario_id) }));
	}
	if (gd::is_empty(state, dependency_record)) {
		return unknown_metadata(state, key::missing_scenario_dependency_record);
	}
	const Atom signature = string_of(state, dependency_record, key::dependency_signature, key::empty);
	const Atom cache_key = gd::format(state, key::s_bar_s, { str(scenario_id), str(signature) });
	const DictRef cache = gd::as_dict(gd::static_var(state, key::scenario_rules_script, key::_scenario_dependency_metadata_cache));
	Value cached_value;
	if (state.lookup(cache, str(cache_key), cached_value)) {
		const DictRef cached = gd::as_dict(gd::engine_duplicate(state, cached_value, true));
		put(state, cached, key::cache_hit, bool_value(true));
		put(state, cached, key::signature, str(signature));
		return cached;
	}
	const DictRef metadata = _scenario_dependency_metadata(state, dependency_record);
	put(state, metadata, key::cache_hit, bool_value(false));
	put(state, metadata, key::signature, str(signature));
	if (state.dict_size(cache) > 128) {
		dict_clear(state, cache);
	}
	state.set(cache, str(cache_key), gd::engine_duplicate(state, dict_value(metadata), true));
	return metadata;
}

DictRef _scenario_dependency_metadata(State &state, DictRef scenario) {
	const DictRef result = state.new_dict();
	put(state, result, key::known, bool_value(true));
	put(state, result, key::unknown_reason, str(key::empty));
	put(state, result, key::objective_count, int_value(0));
	put(state, result, key::hook_count, int_value(0));
	const ArrayRef result_objectives = state.new_array();
	put(state, result, key::objectives, array_value(result_objectives));
	const ArrayRef result_hooks = state.new_array();
	put(state, result, key::hooks, array_value(result_hooks));

	const Value objectives = objective_definitions(state, scenario);
	if (gd::is_dict(objectives)) {
		const DictRef objective_index = state.new_dict();
		index_objectives(state, objectives, objective_index);
		for (const Atom bucket_name : { key::victory, key::defeat }) {
			Value bucket;
			if (!state.lookup(objectives.ref, str(bucket_name), bucket) || !gd::is_array(bucket)) {
				continue;
			}
			for (const Value &objective : gd::items(state, bucket)) {
				if (!gd::is_dict(objective)) {
					const DictRef unknown_objective_dependency = _empty_dependency(state);
					put(state, unknown_objective_dependency, key::known, bool_value(false));
					put(state, unknown_objective_dependency, key::unknown_reason, str(key::objective_not_dictionary));
					put(state, result, key::known, bool_value(false));
					put(state, result, key::unknown_reason, str(key::objective_not_dictionary));
					put(state, result, key::objective_count, int_value(gd::add(gd::int_field(state, result, key::objective_count, 0), 1)));
					state.append(result_objectives, dict_value(unknown_objective_dependency));
					continue;
				}
				const DictRef objective_dependency = _scenario_objective_dependency(state, objective.ref, objective_index, state.new_dict());
				if (!gd::bool_field(state, objective_dependency, key::known, false)) {
					put(state, result, key::known, bool_value(false));
					put(state, result, key::unknown_reason, str(string_of(state, objective_dependency, key::unknown_reason, key::unsupported_objective)));
				}
				put(state, result, key::objective_count, int_value(gd::add(gd::int_field(state, result, key::objective_count, 0), 1)));
				state.append(result_objectives, dict_value(objective_dependency));
			}
		}
	} else if (state.has(scenario, str(key::objectives))) {
		put(state, result, key::known, bool_value(false));
		put(state, result, key::unknown_reason, str(key::objectives_not_dictionary));
	}

	// var raw_hooks = scenario.get("script_hooks", []): a missing list holds no hook.
	Value raw_hooks;
	if (state.lookup(scenario, str(key::script_hooks), raw_hooks)) {
		if (gd::is_array(raw_hooks)) {
			for (const Value &hook : gd::items(state, raw_hooks)) {
				if (!gd::is_dict(hook)) {
					const DictRef unknown_hook_dependency = _empty_dependency(state);
					put(state, unknown_hook_dependency, key::known, bool_value(false));
					put(state, unknown_hook_dependency, key::unknown_reason, str(key::hook_not_dictionary));
					put(state, result, key::known, bool_value(false));
					put(state, result, key::unknown_reason, str(key::hook_not_dictionary));
					put(state, result, key::hook_count, int_value(gd::add(gd::int_field(state, result, key::hook_count, 0), 1)));
					state.append(result_hooks, dict_value(unknown_hook_dependency));
					continue;
				}
				const DictRef hook_dependency = _scenario_hook_dependency(state, hook.ref, result_objectives, objectives);
				if (!gd::bool_field(state, hook_dependency, key::known, false)) {
					put(state, result, key::known, bool_value(false));
					put(state, result, key::unknown_reason, str(string_of(state, hook_dependency, key::unknown_reason, key::unsupported_hook)));
				}
				put(state, result, key::hook_count, int_value(gd::add(gd::int_field(state, result, key::hook_count, 0), 1)));
				state.append(result_hooks, dict_value(hook_dependency));
			}
		} else {
			put(state, result, key::known, bool_value(false));
			put(state, result, key::unknown_reason, str(key::script_hooks_not_array));
		}
	}
	return result;
}

DictRef _scenario_objective_dependency(State &state, DictRef objective, DictRef objective_index, DictRef seen) {
	// The GDScript body reads neither the index nor the ids seen.
	(void)objective_index;
	(void)seen;
	const DictRef dependency = _empty_dependency(state);
	put(state, dependency, key::id, str(string_of(state, objective, key::id, key::empty)));
	const Atom type = string_of(state, objective, key::type, key::empty);
	if (type == key::defeat_generated_rivals) {
		// GeneratedObjectives.KIND.
		put(state, dependency, key::rival_presence, bool_value(true));
	} else if (type == key::artifact_owned_by_player) {
		_add_dependency_value(state, dependency, key::artifact_ids, string_of(state, objective, key::artifact_id, key::empty));
	} else if (type == key::hero_artifact_set_equipped) {
		_add_dependency_value(state, dependency, key::hero_ids, string_of(state, objective, key::hero_id, key::empty));
		const DictRef artifact_set = artifact_rules::artifact_set_record(state, string_of(state, objective, key::set_id, key::empty));
		for (const Value &artifact_id : gd::field_items(state, artifact_set, str(key::piece_ids))) {
			_add_dependency_value(state, dependency, key::artifact_ids, string_of_value(state, artifact_id));
		}
	} else if (type == key::spell_known_by_player) {
		_add_dependency_value(state, dependency, key::spell_ids, string_of(state, objective, key::spell_id, key::empty));
	} else if (type == key::building_built_in_player_town) {
		_add_dependency_value(state, dependency, key::town_placement_ids, string_of(state, objective, key::placement_id, key::empty));
		_add_dependency_value(state, dependency, key::town_ids, string_of(state, objective, key::town_id, key::empty));
		_add_dependency_value(state, dependency, key::building_ids, string_of(state, objective, key::building_id, key::empty));
	} else if (type == key::hero_stationed_at_player_town) {
		_add_dependency_value(state, dependency, key::hero_ids, string_of(state, objective, key::hero_id, key::empty));
		_add_dependency_value(state, dependency, key::town_placement_ids, string_of(state, objective, key::placement_id, key::empty));
		_add_dependency_value(state, dependency, key::town_ids, string_of(state, objective, key::town_id, key::empty));
	} else if (type == key::reserve_delivery_completed) {
		_add_dependency_value(state, dependency, key::resource_site_placement_ids, string_of(state, objective, key::site_placement_id, key::empty));
		const Atom target_kind = string_of(state, objective, key::target_kind, key::town);
		if (target_kind == key::town) {
			_add_dependency_value(state, dependency, key::town_placement_ids, string_of(state, objective, key::target_id, key::empty));
		} else if (target_kind == key::hero) {
			_add_dependency_value(state, dependency, key::hero_ids, string_of(state, objective, key::target_id, key::empty));
		}
	} else if (type == key::map_explored_at_least) {
		put(state, dependency, key::fog_exploration, bool_value(true));
	} else if (type == key::resource_stockpile_at_least) {
		// objective.get("requirements", {}): a missing one holds no resource.
		Value stockpile_requirements;
		if (state.lookup(objective, str(key::requirements), stockpile_requirements) && gd::is_dict(stockpile_requirements)) {
			const ArrayRef resource_ids = gd::keys(state, stockpile_requirements.ref);
			for (const Value &resource_id : gd::items(state, array_value(resource_ids))) {
				_add_dependency_value(state, dependency, key::resources, string_of_value(state, resource_id));
			}
		}
	} else if (type == key::resource_sites_controlled_at_least) {
		Value controlled_site_placement_ids;
		if (state.lookup(objective, str(key::placement_ids), controlled_site_placement_ids) && gd::is_array(controlled_site_placement_ids)) {
			for (const Value &placement_id : gd::items(state, controlled_site_placement_ids)) {
				_add_dependency_value(state, dependency, key::resource_site_placement_ids, string_of_value(state, placement_id));
			}
		}
	} else if (type == key::hero_army_meets_requirements || type == key::town_garrison_meets_requirements) {
		if (type == key::hero_army_meets_requirements) {
			_add_dependency_value(state, dependency, key::hero_ids, string_of(state, objective, key::hero_id, key::empty));
		} else {
			_add_dependency_value(state, dependency, key::town_placement_ids, string_of(state, objective, key::placement_id, key::empty));
		}
		Value requirements;
		if (state.lookup(objective, str(key::requirements), requirements) && gd::is_array(requirements)) {
			for (const Value &requirement : gd::items(state, requirements)) {
				if (gd::is_dict(requirement)) {
					_add_dependency_value(state, dependency, key::unit_ids, string_of(state, requirement.ref, key::unit_id, key::empty));
				}
			}
		}
	} else if (type == key::hero_progression_meets_requirements) {
		_add_dependency_value(state, dependency, key::hero_ids, string_of(state, objective, key::hero_id, key::empty));
	} else if (type == key::town_owned_by_player || type == key::town_not_owned_by_player) {
		_add_dependency_value(state, dependency, key::town_placement_ids, string_of(state, objective, key::placement_id, key::empty));
		_add_dependency_value(state, dependency, key::town_ids, string_of(state, objective, key::town_id, key::empty));
	} else if (type == key::flag_true || type == key::session_flag_equals) {
		_add_dependency_value(state, dependency, key::flags, string_of(state, objective, key::flag, key::empty));
	} else if (type == key::enemy_pressure_at_least) {
		_add_dependency_value(state, dependency, key::enemy_pressure_faction_ids, string_of(state, objective, key::faction_id, key::empty));
	} else if (type == key::encounter_resolved) {
		_add_dependency_value(state, dependency, key::encounter_placement_ids, string_of(state, objective, key::placement_id, key::empty));
	} else if (type == key::hook_fired) {
		_add_dependency_value(state, dependency, key::hook_ids, string_of(state, objective, key::hook_id, key::empty));
	} else if (type == key::day_at_least) {
		put(state, dependency, key::day, bool_value(true));
	} else {
		put(state, dependency, key::known, bool_value(false));
		put(state, dependency, key::unknown_reason, str(gd::format(state, key::unsupported_objective_type_s, { str(type) })));
	}
	return dependency;
}

DictRef _scenario_hook_dependency(State &state, DictRef hook, ArrayRef objective_dependencies, const Value &objectives) {
	// The GDScript body does not read the objectives' dependencies.
	(void)objective_dependencies;
	const DictRef dependency = _empty_dependency(state);
	put(state, dependency, key::id, str(string_of(state, hook, key::id, key::empty)));
	// var conditions = hook.get("conditions", []): a missing list is empty.
	Value conditions;
	if (!state.lookup(hook, str(key::conditions), conditions)) {
		return dependency;
	}
	if (!gd::is_array(conditions)) {
		put(state, dependency, key::known, bool_value(false));
		put(state, dependency, key::unknown_reason, str(key::hook_conditions_not_array));
		return dependency;
	}
	if (state.array_size(conditions.ref) == 0) {
		return dependency;
	}
	const DictRef objective_index = state.new_dict();
	if (gd::is_dict(objectives)) {
		index_objectives(state, objectives, objective_index);
	}
	for (const Value &condition : gd::items(state, conditions)) {
		if (!gd::is_dict(condition)) {
			put(state, dependency, key::known, bool_value(false));
			put(state, dependency, key::unknown_reason, str(key::hook_condition_not_dictionary));
			continue;
		}
		const DictRef condition_dependency = _scenario_condition_dependency(state, condition.ref, objective_index);
		_merge_dependency(state, dependency, condition_dependency);
	}
	return dependency;
}

DictRef _scenario_condition_dependency(State &state, DictRef condition, DictRef objective_index) {
	const DictRef dependency = _empty_dependency(state);
	const Atom type = string_of(state, condition, key::type, key::empty);
	if (type == key::day_at_least) {
		put(state, dependency, key::day, bool_value(true));
	} else if (type == key::town_owned_by_player || type == key::town_not_owned_by_player) {
		_add_dependency_value(state, dependency, key::town_placement_ids, string_of(state, condition, key::placement_id, key::empty));
		_add_dependency_value(state, dependency, key::town_ids, string_of(state, condition, key::town_id, key::empty));
	} else if (type == key::flag_true || type == key::session_flag_equals) {
		_add_dependency_value(state, dependency, key::flags, string_of(state, condition, key::flag, key::empty));
	} else if (type == key::enemy_pressure_at_least) {
		_add_dependency_value(state, dependency, key::enemy_pressure_faction_ids, string_of(state, condition, key::faction_id, key::empty));
	} else if (type == key::encounter_resolved) {
		_add_dependency_value(state, dependency, key::encounter_placement_ids, string_of(state, condition, key::placement_id, key::empty));
	} else if (type == key::objective_met || type == key::objective_not_met) {
		const Atom objective_id = string_of(state, condition, key::objective_id, key::empty);
		// var objective = objective_index.get(objective_id, {})
		Value objective;
		if (state.lookup(objective_index, str(objective_id), objective) && gd::is_dict(objective) && !gd::is_empty(state, objective.ref)) {
			// {objective_id: true}
			const DictRef seen = state.new_dict();
			state.set(seen, str(objective_id), bool_value(true));
			_merge_dependency(state, dependency, _scenario_objective_dependency(state, objective.ref, objective_index, seen));
		} else {
			put(state, dependency, key::known, bool_value(false));
			put(state, dependency, key::unknown_reason, str(gd::format(state, key::hook_objective_dependency_missing_s, { str(objective_id) })));
		}
	} else if (type == key::active_raid_count_at_least || type == key::active_raid_count_at_most) {
		_add_dependency_value(state, dependency, key::active_raid_faction_ids, string_of(state, condition, key::faction_id, key::empty));
	} else if (type == key::hook_fired || type == key::hook_not_fired) {
		_add_dependency_value(state, dependency, key::hook_ids, string_of(state, condition, key::hook_id, key::empty));
	} else {
		put(state, dependency, key::known, bool_value(false));
		put(state, dependency, key::unknown_reason, str(gd::format(state, key::unsupported_hook_condition_type_s, { str(type) })));
	}
	return dependency;
}

DictRef _empty_dependency(State &state) {
	const DictRef dependency = state.new_dict();
	put(state, dependency, key::known, bool_value(true));
	put(state, dependency, key::unknown_reason, str(key::empty));
	for (const Atom list_key : kDependencyKeys) {
		put(state, dependency, list_key, array_value(state.new_array()));
	}
	put(state, dependency, key::day, bool_value(false));
	put(state, dependency, key::fog_exploration, bool_value(false));
	return dependency;
}

DictRef _scenario_event_dependency(State &state, DictRef event_facts) {
	const DictRef dependency = _empty_dependency(state);
	if (gd::bool_field(state, event_facts, key::broad, false)) {
		put(state, dependency, key::broad, bool_value(true));
		put(state, dependency, key::reason, str(string_of(state, event_facts, key::fallback_reason, key::broad_event)));
		return dependency;
	}
	for (const Atom list_key : kDependencyKeys) {
		// _string_array(event_facts.get(key, [])): a missing list holds nothing.
		Value listed;
		if (!state.lookup(event_facts, str(list_key), listed)) {
			continue;
		}
		const ArrayRef values = _string_array(state, listed);
		for (const Value &value : gd::items(state, array_value(values))) {
			_add_dependency_value(state, dependency, list_key, gd::to_string(value));
		}
	}
	put(state, dependency, key::day, bool_value(gd::bool_field(state, event_facts, key::day_changed, false)));
	put(state, dependency, key::fog_exploration, bool_value(gd::bool_field(state, event_facts, key::fog_exploration_changed, false)));
	return dependency;
}

bool _scenario_event_affects_dependency(State &state, DictRef event_dependency, DictRef dependency) {
	if (!gd::bool_field(state, dependency, key::known, false)) {
		return true;
	}
	if (gd::bool_field(state, dependency, key::rival_presence, false)) {
		// Completion can change through conquest, battle, defender expiry or
		// an old eligible save's next ordinary action. Never cache live presence.
		return true;
	}
	if (gd::bool_field(state, event_dependency, key::day, false) && gd::bool_field(state, dependency, key::day, false)) {
		return true;
	}
	if (gd::bool_field(state, event_dependency, key::fog_exploration, false) && gd::bool_field(state, dependency, key::fog_exploration, false)) {
		return true;
	}
	for (const Atom list_key : kDependencyKeys) {
		// _arrays_intersect(event_dependency.get(key, []), dependency.get(key, [])):
		// a missing list meets nothing.
		Value left;
		Value right;
		if (state.lookup(event_dependency, str(list_key), left) && state.lookup(dependency, str(list_key), right) &&
				_arrays_intersect(state, left, right)) {
			return true;
		}
	}
	return false;
}

void _merge_dependency(State &state, DictRef target, DictRef source) {
	if (!gd::bool_field(state, source, key::known, false)) {
		put(state, target, key::known, bool_value(false));
		put(state, target, key::unknown_reason, str(string_of(state, source, key::unknown_reason, key::unknown_dependency)));
	}
	for (const Atom list_key : kDependencyKeys) {
		// _string_array(source.get(key, [])): a missing list holds nothing.
		Value listed;
		if (!state.lookup(source, str(list_key), listed)) {
			continue;
		}
		const ArrayRef values = _string_array(state, listed);
		for (const Value &value : gd::items(state, array_value(values))) {
			_add_dependency_value(state, target, list_key, gd::to_string(value));
		}
	}
	if (gd::bool_field(state, source, key::day, false)) {
		put(state, target, key::day, bool_value(true));
	}
	if (gd::bool_field(state, source, key::fog_exploration, false)) {
		put(state, target, key::fog_exploration, bool_value(true));
	}
}

void _add_dependency_value(State &state, DictRef dependency, Atom list_key, Atom value) {
	const Atom normalized = gd::strip_edges(state, value);
	if (normalized == key::empty) {
		return;
	}
	// var values: Array = dependency.get(key, []) if dependency.get(key, []) is Array else []
	Value found;
	const ArrayRef values = state.lookup(dependency, str(list_key), found) && gd::is_array(found) ? found.ref : state.new_array();
	if (!gd::array_has(state, values, str(normalized))) {
		state.append(values, str(normalized));
	}
	state.set(dependency, str(list_key), array_value(values));
}

ArrayRef _string_array(State &state, const Value &value) {
	const ArrayRef result = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &item : gd::items(state, value)) {
			const Atom text = gd::strip_edges(state, string_of_value(state, item));
			if (text != key::empty && !gd::array_has(state, result, str(text))) {
				state.append(result, str(text));
			}
		}
	} else {
		const Atom text = gd::strip_edges(state, string_of_value(state, value));
		if (text != key::empty) {
			state.append(result, str(text));
		}
	}
	return result;
}

bool _arrays_intersect(State &state, const Value &left, const Value &right) {
	if (!gd::is_array(left) || !gd::is_array(right)) {
		return false;
	}
	for (const Value &value : gd::items(state, left)) {
		if (gd::array_has(state, right.ref, value)) {
			return true;
		}
	}
	return false;
}

} // namespace scenario_rules

} // namespace aurelion::rules::port
