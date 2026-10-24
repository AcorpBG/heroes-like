// SaveService: inspecting a slot, restoring a session, the generated map's
// restore from its package provenance, and filling a summary from a save.

#include "aurelion_rules/port/save_service.hpp"

#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/scenario_select_rules_turn.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"

#include <algorithm>

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

// SaveService's constants: SLOT_TYPE_MANUAL is "manual", SLOT_TYPE_FILE "file",
// the SAVE_METADATA_* keys their texts.
constexpr int64_t kSummaryInlinePayloadMaxBytes = 8 * 1024 * 1024;

// String(x) of a Variant: str(x), the engine's text for a float or a container.
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

// String(d.get(k, fallback)).
Atom string_get(State &state, DictRef dict, Atom k, const Value &fallback) {
	return string_of(state, state.get(dict, str(k), fallback));
}

// d.get(k, {}) if d.get(k, {}) is Dictionary else {}: the field when it is a
// Dictionary, else a new empty one.
DictRef dict_or_new(State &state, DictRef dict, Atom k) {
	Value found;
	if (state.lookup(dict, str(k), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// The same for an Array.
ArrayRef array_or_new(State &state, DictRef dict, Atom k) {
	Value found;
	if (state.lookup(dict, str(k), found) && gd::is_array(found)) {
		return found.ref;
	}
	return state.new_array();
}

// d.get(k, []) where the answer is stored: a new Array when it is missing.
Value field_or_new_array(State &state, DictRef dict, Atom k) {
	Value found;
	if (state.lookup(dict, str(k), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// d.clear(): every key erased.
void dict_clear(State &state, DictRef dict) {
	const ArrayRef held = gd::keys(state, dict);
	for (const Value &k : gd::items(state, array_value(held))) {
		state.erase(dict, k);
	}
}

// {"ok": false, "validity": validity, "message": message, "warnings": []}.
DictRef restore_refusal(State &state, Atom validity, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::validity), str(validity));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::warnings), array_value(state.new_array()));
	return result;
}

// {"ok": ok, "registered": registered} and, with a message, "message".
DictRef registration_result(State &state, bool ok, bool registered, Atom message, bool with_message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::registered), bool_value(registered));
	if (with_message) {
		state.set(result, str(key::message), str(message));
	}
	return result;
}

// {"x": x, "y": y}.
DictRef xy(State &state, int64_t x, int64_t y) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::x), int_value(x));
	state.set(result, str(key::y), int_value(y));
	return result;
}

// session.battle (SessionData types it Dictionary), read where GDScript reads it.
DictRef session_battle(State &state, DictRef view) {
	return gd::as_dict(gd::field(state, view, key::battle));
}

} // namespace

namespace save_service {

DictRef _inspect_slot(State &state, Atom slot_type, Atom slot_id, Atom file_path) {
	_trace_summary_inspection(state, key::slot_file_inspections);
	const bool transaction_artifacts_present = gd::file_exists(state, _save_transaction_candidate_path(state, file_path))
			|| gd::file_exists(state, _save_transaction_backup_path(state, file_path));
	DictRef recovery = state.new_dict();
	if (transaction_artifacts_present) {
		recovery = _recover_save_transaction(state, file_path, true);
	}
	const DictRef cached_summary = _cached_slot_summary(state, slot_type, slot_id, file_path);
	if (!gd::is_empty(state, cached_summary)) {
		return cached_summary;
	}
	if (!transaction_artifacts_present) {
		recovery = _recover_save_transaction(state, file_path, true);
	}

	DictRef summary = _empty_summary(state, slot_type, slot_id, file_path);
	if (!gd::file_exists(state, file_path)) {
		return _finalize_and_cache_summary(state, summary);
	}

	state.set(summary, str(key::modified_timestamp), int_value(gd::file_modified_time(state, file_path)));
	state.set(summary, str(key::payload_bytes), gd::class_call_static(state, key::FileAccess, key::get_size, { str(file_path) }));
	const DictRef raw_payload = _payload_from_raw_read(state, _recovered_live_read(state, recovery, file_path), file_path, false);
	dict_clear(state, recovery);
	if (gd::is_empty(state, raw_payload)) {
		state.set(summary, str(key::validity), str(key::corrupt_json));
		state.set(summary, str(key::status_text), str(key::corrupt_or_unreadable_save_data));
		return _finalize_and_cache_summary(state, summary);
	}

	summary = _populate_summary_from_payload(state, summary, raw_payload);
	// Restore refuses newer save versions, so they are unloadable here too.
	if (gd::int_field(state, summary, key::source_save_version, 0) > session_state_store::kSaveVersion) {
		state.set(summary, str(key::validity), str(key::newer_version));
		state.set(summary, str(key::status_text), str(key::written_by_a_newer_build_of));
		state.set(summary, str(key::resume_target), str(key::blocked));
		state.set(summary, str(key::loadable), bool_value(false));
		return _finalize_and_cache_summary(state, summary);
	}
	const DictRef structure_report = _payload_structure_report(state, raw_payload, slot_type);
	if (!gd::bool_field(state, structure_report, key::ok, false)) {
		state.set(summary, str(key::validity), str(string_get(state, structure_report, key::validity, str(key::invalid_payload))));
		state.set(summary, str(key::status_text), str(string_get(state, structure_report, key::message, str(key::save_cannot_be_restored))));
		state.set(summary, str(key::warnings), field_or_new_array(state, structure_report, key::warnings));
		state.set(summary, str(key::resume_target), str(key::blocked));
		state.set(summary, str(key::loadable), bool_value(false));
		return _finalize_and_cache_summary(state, summary);
	}

	state.set(summary, str(key::valid), bool_value(true));
	state.set(summary, str(key::validity), str(string_get(state, structure_report, key::validity, str(key::ok))));
	state.set(summary, str(key::warnings), field_or_new_array(state, structure_report, key::warnings));
	const Atom resume_target = _resume_target_from_payload_summary(state, raw_payload);
	state.set(summary, str(key::resume_target), str(resume_target));
	state.set(summary, str(key::loadable), bool_value(resume_target != key::blocked));
	// Named files cache only their summaries; restore reads the file again.
	if (slot_type != key::file && gd::int_field(state, summary, key::payload_bytes, 0) <= kSummaryInlinePayloadMaxBytes) {
		state.set(summary, str(key::payload), dict_value(raw_payload));
		state.set(summary, str(key::payload_deferred), bool_value(false));
	} else {
		state.set(summary, str(key::payload), dict_value(state.new_dict()));
		state.set(summary, str(key::payload_deferred), bool_value(true));
	}
	state.set(summary, str(key::valid), bool_value(true));
	state.set(summary, str(key::status_text), str(_status_text_for_summary(state, summary)));
	const DictRef finalized = _finalize_stored_summary(state, summary);
	_store_slot_summary_cache(state, finalized);
	return finalized;
}

DictRef _normalize_restore_result(State &state, DictRef payload, Atom slot_type) {
	const int64_t source_save_version = std::max<int64_t>(0, gd::int_field(state, payload, key::save_version, session_state_store::kSaveVersion));
	if (source_save_version > session_state_store::kSaveVersion) {
		return restore_refusal(state, key::newer_version, key::written_by_a_newer_save_version);
	}

	const DictRef structure_report = _payload_structure_report(state, payload, slot_type);
	if (!gd::bool_field(state, structure_report, key::ok, false)) {
		return structure_report;
	}

	const DictRef normalized = session_state_store::normalize_payload(state, dict_value(payload));
	const Atom scenario_id = string_get(state, normalized, key::scenario_id, str(key::empty));
	if (scenario_id == key::empty) {
		return restore_refusal(state, key::invalid_payload, key::missing_scenario_id);
	}

	const Value warnings_value = field_or_new_array(state, structure_report, key::warnings);
	const ArrayRef warnings = gd::is_array(warnings_value) ? warnings_value.ref : state.new_array();
	const DictRef generated_registration = _ensure_generated_random_map_scenario_registered(state, normalized);
	if (gd::bool_field(state, generated_registration, key::registered, false)) {
		state.append(warnings, str(string_get(state, generated_registration, key::message, str(key::generated_random_map_scenario_was_restored))));
	} else if (state.has(generated_registration, str(key::ok)) && !gd::bool_field(state, generated_registration, key::ok, false)) {
		state.append(warnings, str(string_get(state, generated_registration, key::message, str(key::generated_random_map_provenance_could_not))));
	}

	const DictRef scenario = gd::content_row(state, state::ContentTable::Scenario, scenario_id);
	if (gd::is_empty(state, scenario)) {
		return restore_refusal(state, key::missing_scenario, key::scenario_content_is_unavailable_in_this);
	}

	const Value session = _session_from_owned_detached_payload(state, normalized);
	if (session.kind == Kind::Nil) {
		return restore_refusal(state, key::invalid_payload, key::session_payload_could_not_be_normalized);
	}
	const DictRef view = gd::object_view(state, session);

	overworld_rules::normalize_overworld_state(state, view);
	// Older saves could hold commanders hired without troops.
	hero_command_rules::restore_empty_hero_armies(state, session);

	Atom validity = string_get(state, structure_report, key::validity, str(key::ok));
	if (source_save_version < session_state_store::kSaveVersion) {
		if (validity == key::ok) {
			validity = key::legacy;
		} else {
			validity = _degraded_validity(state, validity);
		}
		state.append(warnings, str(gd::format(state, key::normalized_legacy_save_version_d, { int_value(source_save_version) })));
	}

	const Atom requested_resume_target = _resume_target_for_session(state, session);
	if (requested_resume_target == key::battle) {
		if (gd::is_empty(state, session_battle(state, view))) {
			state.set(view, str(key::game_state), str(key::overworld));
			validity = _degraded_validity(state, validity);
			state.append(warnings, str(key::battle_payload_was_missing_and_the));
		} else if (!battle_rules::normalize_battle_state(state, session)) {
			state.set(view, str(key::battle), dict_value(state.new_dict()));
			state.set(view, str(key::game_state), str(key::overworld));
			validity = _degraded_validity(state, validity);
			state.append(warnings, str(key::battle_payload_could_not_be_restored));
		}
	} else if (requested_resume_target == key::town) {
		if (!gd::is_empty(state, session_battle(state, view))) {
			state.set(view, str(key::battle), dict_value(state.new_dict()));
			validity = _degraded_validity(state, validity);
			state.append(warnings, str(key::stale_battle_payload_was_ignored_because));
		}
		if (!town_rules::can_visit_active_town(state, view)) {
			state.set(view, str(key::game_state), str(key::overworld));
			validity = _degraded_validity(state, validity);
			state.append(warnings, str(key::town_visit_state_was_invalid_and));
		}
	} else if (requested_resume_target == key::outcome) {
		if (!gd::is_empty(state, session_battle(state, view))) {
			state.set(view, str(key::battle), dict_value(state.new_dict()));
			validity = _degraded_validity(state, validity);
			state.append(warnings, str(key::stale_battle_payload_was_ignored_because_2));
		}
		state.set(view, str(key::game_state), str(key::outcome));
	} else {
		if (!gd::is_empty(state, session_battle(state, view))) {
			state.set(view, str(key::battle), dict_value(state.new_dict()));
			validity = _degraded_validity(state, validity);
			state.append(warnings, str(key::stale_battle_payload_was_ignored_because));
		}
		state.set(view, str(key::game_state), str(key::overworld));
	}

	const Atom resume_target = _resume_target_for_session(state, session);
	if (resume_target == key::battle) {
		state.set(view, str(key::game_state), str(key::battle));
	} else if (resume_target == key::town) {
		state.set(view, str(key::game_state), str(key::town));
	} else if (resume_target == key::outcome) {
		state.set(view, str(key::game_state), str(key::outcome));
	} else if (gd::to_string(gd::field(state, view, key::scenario_status)) == key::in_progress) {
		state.set(view, str(key::game_state), str(key::overworld));
	}

	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::validity), str(validity));
	state.set(result, str(key::warnings), array_value(warnings));
	state.set(result, str(key::session), session);
	state.set(result, str(key::resume_target), str(resume_target));
	state.set(result, str(key::owned_payload_transfer), bool_value(true));
	return result;
}

DictRef _ensure_generated_random_map_scenario_registered(State &state, DictRef normalized_payload) {
	const Atom scenario_id = string_get(state, normalized_payload, key::scenario_id, str(key::empty));
	if (scenario_id == key::empty || !gd::is_empty(state, gd::content_row(state, state::ContentTable::Scenario, scenario_id))) {
		return registration_result(state, true, false, key::empty, false);
	}
	if (string_get(state, normalized_payload, key::launch_mode, str(key::empty)) != key::skirmish) {
		return state.new_dict();
	}
	// A missing flags is a new {}, which has no generated_random_map.
	Value flags;
	if (!state.lookup(normalized_payload, str(key::flags), flags) || !gd::is_dict(flags)
			|| !gd::bool_field(state, flags.ref, key::generated_random_map, false)) {
		return state.new_dict();
	}
	DictRef provenance = dict_or_new(state, flags.ref, key::generated_random_map_provenance);
	if (gd::is_empty(state, provenance)) {
		const DictRef setup = dict_or_new(state, flags.ref, key::generated_random_map_setup);
		provenance = dict_or_new(state, setup, key::provenance);
	}
	if (string_get(state, provenance, key::schema_id, str(key::empty)) == key::aurelion_native_rmg_disk_package_provenance_v1) {
		return _register_native_generated_random_map_scenario_from_payload(state, normalized_payload, provenance);
	}
	// A save from before the map packages: the GDScript generator that rebuilt
	// its map is gone (owner decision D-g, 2026-10-23).
	return registration_result(state, false, false, key::generated_random_map_save_predates_map, true);
}

DictRef _register_native_generated_random_map_scenario_from_payload(State &state, DictRef normalized_payload, DictRef provenance) {
	const Atom scenario_id = string_get(state, normalized_payload, key::scenario_id, str(key::empty));
	if (scenario_id == key::empty) {
		return registration_result(state, false, false, key::native_generated_random_map_save_is, true);
	}
	if (!gd::is_empty(state, gd::content_row(state, state::ContentTable::Scenario, scenario_id))) {
		return registration_result(state, true, false, key::empty, false);
	}
	const DictRef overworld = dict_or_new(state, normalized_payload, key::overworld);
	const DictRef map_size = dict_or_new(state, overworld, key::map_size);
	const DictRef terrain_layers = dict_or_new(state, overworld, key::terrain_layers);
	const DictRef generated_identity = dict_or_new(state, provenance, key::generated_identity);
	const DictRef normalized_config = dict_or_new(state, provenance, key::normalized_config);
	const DictRef scenario_ref = dict_or_new(state, provenance, key::scenario_ref);
	const DictRef start = _native_generated_restore_start(state, overworld);

	const DictRef scenario_record = state.new_dict();
	state.set(scenario_record, str(key::id), str(scenario_id));
	state.set(scenario_record, str(key::name), str(string_get(state, scenario_ref, key::name, str(scenario_id))));
	state.set(scenario_record, str(key::generated), bool_value(true));
	state.set(scenario_record, str(key::source), str(key::native_rmg_disk_package_save_restore));
	const DictRef availability = state.new_dict();
	state.set(availability, str(key::campaign), bool_value(false));
	state.set(availability, str(key::skirmish), bool_value(false));
	const DictRef selection = state.new_dict();
	state.set(selection, str(key::availability), dict_value(availability));
	state.set(scenario_record, str(key::selection), dict_value(selection));
	state.set(scenario_record, str(key::map_size), dict_value(map_size));
	state.set(scenario_record, str(key::map), array_value(array_or_new(state, overworld, key::map)));
	state.set(scenario_record, str(key::player_faction_id), str(_native_generated_restore_player_faction(state, overworld)));
	state.set(scenario_record, str(key::starting_hero_id), str(string_get(state, normalized_payload, key::hero_id, str(key::hero_lyra))));
	state.set(scenario_record, str(key::starting_position), dict_value(start));
	state.set(scenario_record, str(key::towns), array_value(array_or_new(state, overworld, key::towns)));
	state.set(scenario_record, str(key::resource_nodes), array_value(array_or_new(state, overworld, key::resource_nodes)));
	state.set(scenario_record, str(key::encounters), array_value(array_or_new(state, overworld, key::encounters)));
	state.set(scenario_record, str(key::map_objects), array_value(array_or_new(state, overworld, key::map_objects)));
	state.set(scenario_record, str(key::objectives), dict_value(_native_generated_restore_objectives(state, overworld)));
	const DictRef package = state.new_dict();
	state.set(package, str(key::schema_id), str(key::aurelion_native_rmg_disk_package_restore_record_v1));
	state.set(package, str(key::template_id),
			str(string_get(state, generated_identity, key::template_id, state.get(normalized_config, str(key::template_id), str(key::empty)))));
	state.set(package, str(key::profile_id),
			str(string_get(state, generated_identity, key::profile_id, state.get(normalized_config, str(key::profile_id), str(key::empty)))));
	state.set(package, str(key::normalized_seed),
			str(string_get(state, generated_identity, key::normalized_seed, state.get(normalized_config, str(key::normalized_seed), str(key::empty)))));
	state.set(package, str(key::map_ref), dict_value(dict_or_new(state, provenance, key::map_ref)));
	state.set(package, str(key::scenario_ref), dict_value(scenario_ref));
	state.set(package, str(key::boundaries), dict_value(dict_or_new(state, provenance, key::boundaries)));
	state.set(scenario_record, str(key::native_generated_package), dict_value(package));

	const DictRef registration = gd::as_dict(gd::call_method(state, gd::autoload(state, key::ContentService), key::register_generated_scenario_draft,
			{ dict_value(scenario_record), dict_value(terrain_layers) }));
	if (!gd::bool_field(state, registration, key::ok, false)) {
		const Atom message = string_get(state, registration, key::message, str(key::empty));
		return registration_result(state, false, false, gd::format(state, key::native_generated_random_map_save_could, { str(message) }), true);
	}
	return registration_result(state, true, true, key::native_generated_random_map_scenario_restored, true);
}

DictRef _native_generated_restore_objectives(State &state, DictRef overworld) {
	const ArrayRef towns = array_or_new(state, overworld, key::towns);
	Atom starting_town_id = key::empty;
	Atom rival_town_id = key::empty;
	for (const Value &town_value : gd::items(state, array_value(towns))) {
		if (!gd::is_dict(town_value)) {
			continue;
		}
		const DictRef town = town_value.ref;
		const Atom placement_id = string_get(state, town, key::placement_id, str(key::empty));
		if (placement_id == key::empty) {
			continue;
		}
		const Atom owner = string_get(state, town, key::owner, str(key::empty));
		if (starting_town_id == key::empty && owner == key::player) {
			starting_town_id = placement_id;
			continue;
		}
		if (rival_town_id == key::empty && owner != key::player) {
			rival_town_id = placement_id;
		}
	}
	if (rival_town_id == key::empty) {
		for (const Value &town_value : gd::items(state, array_value(towns))) {
			if (!gd::is_dict(town_value)) {
				continue;
			}
			const Atom placement_id = string_get(state, town_value.ref, key::placement_id, str(key::empty));
			if (placement_id != key::empty && placement_id != starting_town_id) {
				rival_town_id = placement_id;
				break;
			}
		}
	}
	const ArrayRef victory_objectives = state.new_array();
	const ArrayRef defeat_objectives = state.new_array();
	if (rival_town_id != key::empty) {
		const DictRef objective = state.new_dict();
		state.set(objective, str(key::id), str(key::generated_capture_rival_town));
		state.set(objective, str(key::type), str(key::town_owned_by_player));
		state.set(objective, str(key::placement_id), str(rival_town_id));
		state.set(objective, str(key::label), str(key::claim_a_generated_rival_town));
		state.set(objective, str(key::generated_support), str(key::scenariorules_town_owned_by_player));
		state.append(victory_objectives, dict_value(objective));
	} else {
		const DictRef objective = state.new_dict();
		state.set(objective, str(key::id), str(key::generated_hold_until_day_14));
		state.set(objective, str(key::type), str(key::day_at_least));
		state.set(objective, str(key::day), int_value(14));
		state.set(objective, str(key::label), str(key::hold_the_generated_frontier_until_day));
		state.set(objective, str(key::generated_support), str(key::scenariorules_day_at_least));
		state.append(victory_objectives, dict_value(objective));
	}
	if (starting_town_id != key::empty) {
		const DictRef objective = state.new_dict();
		state.set(objective, str(key::id), str(key::generated_primary_town_lost));
		state.set(objective, str(key::type), str(key::town_not_owned_by_player));
		state.set(objective, str(key::placement_id), str(starting_town_id));
		state.set(objective, str(key::label), str(key::do_not_lose_the_generated_starting));
		state.set(objective, str(key::generated_support), str(key::scenariorules_town_not_owned_by_player));
		state.append(defeat_objectives, dict_value(objective));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::victory_text), str(key::generated_objective_completed));
	state.set(result, str(key::defeat_text), str(key::generated_objective_failed));
	state.set(result, str(key::victory), array_value(victory_objectives));
	state.set(result, str(key::defeat), array_value(defeat_objectives));
	return result;
}

DictRef _native_generated_restore_start(State &state, DictRef overworld) {
	const DictRef position = dict_or_new(state, overworld, key::hero_position);
	if (!gd::is_empty(state, position)) {
		return xy(state, gd::int_field(state, position, key::x, 0), gd::int_field(state, position, key::y, 0));
	}
	const DictRef hero = dict_or_new(state, overworld, key::hero);
	const DictRef hero_pos = dict_or_new(state, hero, key::position);
	if (!gd::is_empty(state, hero_pos)) {
		return xy(state, gd::int_field(state, hero_pos, key::x, 0), gd::int_field(state, hero_pos, key::y, 0));
	}
	return xy(state, 0, 0);
}

Atom _native_generated_restore_player_faction(State &state, DictRef overworld) {
	const DictRef hero = dict_or_new(state, overworld, key::hero);
	const Atom faction_id = string_get(state, hero, key::faction_id, str(key::empty));
	if (faction_id != key::empty) {
		return faction_id;
	}
	const ArrayRef heroes = array_or_new(state, overworld, key::player_heroes);
	for (const Value &hero_entry : gd::items(state, array_value(heroes))) {
		if (gd::is_dict(hero_entry) && string_get(state, hero_entry.ref, key::faction_id, str(key::empty)) != key::empty) {
			return string_get(state, hero_entry.ref, key::faction_id, str(key::empty));
		}
	}
	const ArrayRef towns = array_or_new(state, overworld, key::towns);
	for (const Value &town : gd::items(state, array_value(towns))) {
		if (gd::is_dict(town) && string_get(state, town.ref, key::owner, str(key::empty)) == key::player
				&& string_get(state, town.ref, key::faction_id, str(key::empty)) != key::empty) {
			return string_get(state, town.ref, key::faction_id, str(key::empty));
		}
	}
	return key::faction_embercourt;
}

DictRef _populate_summary_from_payload(State &state, DictRef summary, DictRef payload) {
	const Atom scenario_id = string_get(state, payload, key::scenario_id, str(key::empty));
	const DictRef scenario = gd::content_row(state, state::ContentTable::Scenario, scenario_id);
	const Atom launch_mode = session_state_store::normalize_launch_mode(state, state.get(payload, str(key::launch_mode), str(key::campaign)));
	const DictRef campaign_metadata = _campaign_metadata_for_scenario(state, scenario_id, launch_mode);
	// A missing flags is a new {}, which changes nothing here.
	Value session_flags;
	if (state.lookup(payload, str(key::flags), session_flags) && gd::is_dict(session_flags)
			&& session_state_store::normalize_launch_mode(state, str(launch_mode)) == key::campaign) {
		const Atom flagged_campaign_id = string_get(state, session_flags.ref, key::campaign_id, str(key::empty));
		if (flagged_campaign_id != key::empty) {
			state.set(campaign_metadata, str(key::campaign_id), str(flagged_campaign_id));
			if (string_get(state, campaign_metadata, key::campaign_name, str(key::empty)) == key::empty) {
				const DictRef flagged_campaign = gd::as_dict(gd::call_method(state, gd::autoload(state, key::ContentService), key::get_campaign,
						{ str(flagged_campaign_id) }));
				state.set(campaign_metadata, str(key::campaign_name), str(string_get(state, flagged_campaign, key::name, str(flagged_campaign_id))));
			}
		}
		const Atom flagged_campaign_name = string_get(state, session_flags.ref, key::campaign_name, str(key::empty));
		if (flagged_campaign_name != key::empty) {
			state.set(campaign_metadata, str(key::campaign_name), str(flagged_campaign_name));
		}
		const Atom flagged_chapter_label = string_get(state, session_flags.ref, key::campaign_chapter_label, str(key::empty));
		if (flagged_chapter_label != key::empty) {
			state.set(campaign_metadata, str(key::chapter_label), str(flagged_chapter_label));
		}
	}
	const Atom hero_id = string_get(state, payload, key::hero_id, str(key::empty));
	// overworld_state.get("hero", {}) if overworld_state is Dictionary else {},
	// then the Dictionary or {}.
	Value overworld_state;
	Value hero_state_value;
	if (state.lookup(payload, str(key::overworld), overworld_state) && gd::is_dict(overworld_state)) {
		state.lookup(overworld_state.ref, str(key::hero), hero_state_value);
	}
	const DictRef hero_state = gd::is_dict(hero_state_value) ? hero_state_value.ref : state.new_dict();
	const DictRef hero_template = gd::content_row(state, state::ContentTable::Hero, hero_id);

	const int64_t save_version = std::max<int64_t>(0, gd::int_field(state, payload, key::save_version, session_state_store::kSaveVersion));
	state.set(summary, str(key::source_save_version), int_value(save_version));
	state.set(summary, str(key::save_version),
			int_value(std::max<int64_t>(0, gd::int_field(state, payload, key::save_version, session_state_store::kSaveVersion))));
	state.set(summary, str(key::recorded_timestamp_precise), gd::float_value(_recorded_timestamp_precise_from_payload(state, payload)));
	state.set(summary, str(key::recorded_timestamp),
			int_value(_recorded_timestamp_from_payload(state, payload, gd::int_field(state, summary, key::modified_timestamp, 0))));
	state.set(summary, str(key::scenario_id), str(scenario_id));
	state.set(summary, str(key::scenario_name), str(string_get(state, scenario, key::name, str(scenario_id))));
	state.set(summary, str(key::scenario_summary), str(string_get(state, payload, key::scenario_summary, str(key::empty))));
	state.set(summary, str(key::campaign_id), str(string_get(state, campaign_metadata, key::campaign_id, str(key::empty))));
	state.set(summary, str(key::campaign_name), str(string_get(state, campaign_metadata, key::campaign_name, str(key::empty))));
	state.set(summary, str(key::chapter_label), str(string_get(state, campaign_metadata, key::chapter_label, str(key::empty))));
	state.set(summary, str(key::day), int_value(std::max<int64_t>(0, gd::int_field(state, payload, key::day, 0))));
	state.set(summary, str(key::hero_id), str(hero_id));
	state.set(summary, str(key::hero_name), str(_hero_name(state, dict_value(hero_state), hero_template, hero_id)));
	state.set(summary, str(key::hero_specialties_summary), str(hero_progression_rules::brief_summary(state, hero_state)));
	const Value difficulty_fallback = str(scenario_select_rules::default_difficulty_id(state));
	state.set(summary, str(key::difficulty),
			str(scenario_select_rules::normalize_difficulty(state, state.get(payload, str(key::difficulty), difficulty_fallback))));
	state.set(summary, str(key::launch_mode), str(launch_mode));
	state.set(summary, str(key::scenario_status),
			str(session_state_store::_normalize_scenario_status(state, state.get(payload, str(key::scenario_status), str(key::in_progress)))));
	state.set(summary, str(key::game_state),
			str(session_state_store::_normalize_game_state(state, state.get(payload, str(key::game_state), str(key::overworld)))));
	state.set(summary, str(key::battle_name), str(_battle_name_from_payload(state, payload)));
	state.set(summary, str(key::resume_location), str(_resume_location_from_payload(state, payload)));
	state.set(summary, str(key::saved_from_game_state),
			str(string_get(state, payload, key::saved_from_game_state, state.get(summary, str(key::game_state), str(key::overworld)))));
	state.set(summary, str(key::saved_from_scenario_status),
			str(string_get(state, payload, key::saved_from_scenario_status, state.get(summary, str(key::scenario_status), str(key::in_progress)))));
	state.set(summary, str(key::saved_from_launch_mode),
			str(string_get(state, payload, key::saved_from_launch_mode, state.get(summary, str(key::launch_mode), str(key::campaign)))));
	const bool manual = string_get(state, summary, key::slot_type, str(key::empty)) == key::manual;
	state.set(summary, str(key::manual_slot_name), str(manual ? _manual_slot_name_from_payload(state, payload) : key::empty));
	return summary;
}

DictRef _campaign_metadata_for_scenario(State &state, Atom scenario_id, Atom launch_mode) {
	const DictRef metadata = state.new_dict();
	state.set(metadata, str(key::campaign_id), str(key::empty));
	state.set(metadata, str(key::campaign_name), str(key::empty));
	state.set(metadata, str(key::chapter_label), str(key::empty));
	if (scenario_id == key::empty || session_state_store::normalize_launch_mode(state, str(launch_mode)) != key::campaign) {
		return metadata;
	}

	const Atom campaign_id = gd::to_string(gd::call_static(state, key::campaign_rules_script, key::get_campaign_id_for_scenario, { str(scenario_id) }));
	if (campaign_id == key::empty) {
		return metadata;
	}

	const DictRef campaign = gd::as_dict(gd::call_method(state, gd::autoload(state, key::ContentService), key::get_campaign, { str(campaign_id) }));
	state.set(metadata, str(key::campaign_id), str(campaign_id));
	state.set(metadata, str(key::campaign_name), str(string_get(state, campaign, key::name, str(campaign_id))));
	for (const Value &scenario_entry : gd::field_items(state, campaign, str(key::scenarios))) {
		if (!gd::is_dict(scenario_entry)) {
			continue;
		}
		if (string_get(state, scenario_entry.ref, key::scenario_id, str(key::empty)) != scenario_id) {
			continue;
		}
		state.set(metadata, str(key::chapter_label), str(string_get(state, scenario_entry.ref, key::label, str(key::empty))));
		break;
	}
	return metadata;
}

Atom _hero_name(State &state, const Value &hero_state, DictRef hero_template, Atom hero_id) {
	if (gd::is_dict(hero_state)) {
		const Atom hero_name = string_get(state, hero_state.ref, key::name, str(key::empty));
		if (hero_name != key::empty) {
			return hero_name;
		}
	}
	return string_get(state, hero_template, key::name, str(hero_id));
}

Atom _battle_name_from_payload(State &state, DictRef normalized_payload) {
	// A missing battle is a new {}: empty.
	Value battle_state;
	if (!state.lookup(normalized_payload, str(key::battle), battle_state) || !gd::is_dict(battle_state) || gd::is_empty(state, battle_state.ref)) {
		return key::empty;
	}
	const Value encounter_id = state.get(battle_state.ref, str(key::encounter_id), str(key::empty));
	return string_get(state, battle_state.ref, key::encounter_name, encounter_id);
}

Atom _resume_location_from_payload(State &state, DictRef normalized_payload) {
	if (string_get(state, normalized_payload, key::scenario_status, str(key::in_progress)) != key::in_progress) {
		return _humanize_label(state, string_get(state, normalized_payload, key::scenario_status, str(key::outcome)));
	}
	const Atom battle_name = _battle_name_from_payload(state, normalized_payload);
	if (battle_name != key::empty) {
		return battle_name;
	}
	if (string_get(state, normalized_payload, key::game_state, str(key::overworld)) == key::town) {
		const Atom town_name = _active_town_name_from_payload(state, normalized_payload);
		if (town_name != key::empty) {
			return town_name;
		}
	}
	const Vector2i hero_pos = _hero_position_from_payload(state, normalized_payload);
	return gd::format(state, key::overworld_d_d, { int_value(hero_pos.x), int_value(hero_pos.y) });
}

Atom _active_town_name_from_payload(State &state, DictRef normalized_payload) {
	// A missing overworld is a new {}: no towns, so "".
	Value overworld_state;
	if (!state.lookup(normalized_payload, str(key::overworld), overworld_state) || !gd::is_dict(overworld_state)) {
		return key::empty;
	}
	Value flags;
	Atom active_placement_id = key::empty;
	if (state.lookup(normalized_payload, str(key::flags), flags) && gd::is_dict(flags)) {
		active_placement_id = string_get(state, flags.ref, key::active_town_placement_id, str(key::empty));
	}
	// Missing towns are a new []: no town matches.
	Value towns;
	if (!state.lookup(overworld_state.ref, str(key::towns), towns) || !gd::is_array(towns)) {
		return key::empty;
	}
	if (active_placement_id != key::empty) {
		for (const Value &town : gd::items(state, towns)) {
			if (gd::is_dict(town) && string_get(state, town.ref, key::placement_id, str(key::empty)) == active_placement_id) {
				return _town_name_for_summary(state, town.ref);
			}
		}
	}
	const Vector2i hero_pos = _hero_position_from_payload(state, normalized_payload);
	for (const Value &town : gd::items(state, towns)) {
		if (gd::is_dict(town) && gd::int_field(state, town.ref, key::x, 0) == static_cast<int64_t>(hero_pos.x)
				&& gd::int_field(state, town.ref, key::y, 0) == static_cast<int64_t>(hero_pos.y)) {
			return _town_name_for_summary(state, town.ref);
		}
	}
	return key::empty;
}

Atom _town_name_for_summary(State &state, DictRef town) {
	const Atom town_id = string_get(state, town, key::town_id, str(key::empty));
	const DictRef town_template = gd::content_row(state, state::ContentTable::Town, town_id);
	return string_get(state, town_template, key::name, str(town_id));
}

Vector2i _hero_position_from_payload(State &state, DictRef normalized_payload) {
	// A missing overworld, hero_position, hero or position is a new {}: (0, 0).
	Value overworld_state;
	if (!state.lookup(normalized_payload, str(key::overworld), overworld_state) || !gd::is_dict(overworld_state)) {
		return Vector2i{};
	}
	Value position;
	if (!state.lookup(overworld_state.ref, str(key::hero_position), position)) {
		return Vector2i{};
	}
	if (!gd::is_dict(position)) {
		Value hero_state;
		if (!state.lookup(overworld_state.ref, str(key::hero), hero_state) || !gd::is_dict(hero_state)
				|| !state.lookup(hero_state.ref, str(key::position), position)) {
			return Vector2i{};
		}
	}
	if (gd::is_dict(position)) {
		return Vector2i::of(gd::int_field(state, position.ref, key::x, 0), gd::int_field(state, position.ref, key::y, 0));
	}
	return Vector2i{};
}

} // namespace save_service

} // namespace aurelion::rules::port
