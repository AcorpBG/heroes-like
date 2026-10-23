// NativeRandomMapPackageSessionBridge: a new game's session from the generated
// map's documents (the map and scenario documents are objects: their methods
// are host calls).

#include "aurelion_rules/port/native_random_map_package_session_bridge.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/generated_neutral_encounter_rules.hpp"
#include "aurelion_rules/port/generated_reward_rules.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/native_scenery_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_state_store.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>
#include <vector>

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
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// SessionStateStore.SAVE_VERSION.
constexpr int64_t kSaveVersion = 9;
// NativeSceneryRules.PRESENTATION_VERSION.
constexpr int64_t kSceneryPresentationVersion = 2;

// SessionStateStoreScript.new_session_data() with its defaults.
Value empty_session(State &state) {
	return session_state_store::new_session_data(state, key::empty, key::empty, key::empty, 1, state.new_dict(), key::normal, key::campaign);
}

// String(d.get(k, "")).
Atom text(State &state, DictRef dict, Atom field) {
	return ai::string_or_empty(state, dict, field);
}

// String(d.get(k, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// String(d.get(k, "")).strip_edges().
Atom stripped(State &state, DictRef dict, Atom field) {
	return gd::strip_edges(state, text(state, dict, field));
}

// d.get(k, {}) if d.get(k, {}) is Dictionary else {}: the field, or a new one.
DictRef dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// d.get(k, {}) / d.get(k, []) where the value is stored: the field as it is,
// or a new container when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// The same read only: the field when it is a Dictionary (an Array), else Nil,
// which reads as the empty {} ([]) GDScript makes.
Value dict_or_nil(const State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found;
	}
	return Value();
}
Value array_or_nil(const State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_array(found)) {
		return found;
	}
	return Value();
}

// x.get(k, fallback) of a Dictionary read as above (Nil: an empty one).
Value get_in(const State &state, const Value &dict, Atom field, const Value &fallback) {
	return gd::is_dict(dict) ? state.get(dict.ref, str(field), fallback) : fallback;
}

// x.duplicate(true) if x is Array else [], and the same for a Dictionary.
ArrayRef duplicated_array_or_new(State &state, const Value &value) {
	return gd::is_array(value) ? gd::deep_duplicate_array(state, value.ref) : state.new_array();
}
DictRef duplicated_dict_or_new(State &state, const Value &value) {
	return gd::is_dict(value) ? gd::deep_duplicate_dict(state, value.ref) : state.new_dict();
}

// d.get(first, d.get(second, [])): the first field, else the second, else Nil
// (a new [], which the callers only duplicate or test).
Value either_field(const State &state, DictRef dict, Atom first, Atom second) {
	Value found;
	if (state.lookup(dict, str(first), found)) {
		return found;
	}
	if (state.lookup(dict, str(second), found)) {
		return found;
	}
	return Value();
}

// push_error(pattern % String(resolved.get("error", "unknown"))).
void push_resolve_error(State &state, Atom pattern, DictRef resolved) {
	const Atom error = text_or(state, resolved, key::error, str(key::unknown));
	state.print_error(state.text(gd::format(state, pattern, {str(error)})));
}

// text.to_lower() (String::to_lower, one character at a time) to compare with
// ASCII words: false when the result keeps a character outside ASCII, so it is
// none of them. Outside ASCII only U+0130 lowers to a letter of the words here
// ("i"); U+212A lowers to "k", which none of them has.
bool lower_ascii(const std::string &text, std::string &out) {
	out.clear();
	out.reserve(text.size());
	for (size_t index = 0; index < text.size(); ++index) {
		const unsigned char c = static_cast<unsigned char>(text[index]);
		if (c < 0x80) {
			out += static_cast<char>(c >= 'A' && c <= 'Z' ? c - 'A' + 'a' : c);
			continue;
		}
		if (c == 0xC4 && index + 1 < text.size() && static_cast<unsigned char>(text[index + 1]) == 0xB0) {
			out += 'i';
			++index;
			continue;
		}
		return false;
	}
	return true;
}

// kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference"].
bool is_site_kind(Atom kind) {
	return kind == key::resource_site || kind == key::mine || kind == key::neutral_dwelling || kind == key::reward_reference;
}

// String(GENERATED_START_ARMY_BY_FACTION.get(faction_id, "army_start_embercourt")).
Atom generated_start_army(Atom faction_id) {
	if (faction_id == key::faction_embercourt) {
		return key::army_start_embercourt;
	}
	if (faction_id == key::faction_mireclaw) {
		return key::army_start_mireclaw;
	}
	if (faction_id == key::faction_sunvault) {
		return key::army_start_sunvault;
	}
	if (faction_id == key::faction_thornwake) {
		return key::army_start_thornwake;
	}
	if (faction_id == key::faction_brasshollow) {
		return key::army_start_brasshollow;
	}
	if (faction_id == key::faction_veilmourn) {
		return key::army_start_veilmourn;
	}
	return key::army_start_embercourt;
}

// The resource ids _generated_resource_node_is_rare_source looks for.
bool is_rare_resource(Atom resource_id) {
	return resource_id == key::aetherglass || resource_id == key::embergrain || resource_id == key::peatwax || resource_id == key::verdant_grafts || resource_id == key::brass_scrip || resource_id == key::memory_salt;
}

// [value]: a new Array holding it.
ArrayRef single(State &state, const Value &value) {
	const ArrayRef array = state.new_array();
	state.append(array, value);
	return array;
}

} // namespace

namespace native_random_map_package_session_bridge {

Value build_session_from_adoption(State &state, DictRef adoption, Atom difficulty, DictRef options) {
	if (!gd::bool_field(state, adoption, key::ok, false)) {
		return empty_session(state);
	}
	const DictRef boundary = dict_or_new(state, adoption, key::session_boundary_record);
	if (gd::is_empty(state, boundary)) {
		return empty_session(state);
	}

	const Atom scenario_id = text(state, boundary, key::scenario_id);
	const Atom session_id = text(state, boundary, key::session_id);
	const Atom hero_id = gd::stringify(state, state.get(boundary, str(key::hero_id), state.get(options, str(key::hero_id), str(key::hero_lyra))));
	const DictRef map_ref = dict_or_new(state, boundary, key::map_package_ref);
	const DictRef scenario_ref = dict_or_new(state, boundary, key::scenario_package_ref);
	const DictRef report = dict_or_new(state, adoption, key::report);
	const DictRef metrics = dict_or_new(state, report, key::metrics);
	const DictRef start = _primary_start(state, adoption);
	const Value map_document = gd::field(state, adoption, key::map_document);
	const Value scenario_document = gd::field(state, adoption, key::scenario_document);
	// The package objects, materialized once and shared by every pass below.
	const ArrayRef source_objects = _document_objects(state, map_document);
	for (int64_t index = 0; index < state.array_size(source_objects); ++index) {
		const DictRef object = gd::as_dict(state.at(source_objects, index));
		if (state.has(object, str(key::native_guard_quantity))) {
			const DictRef resolved = generated_neutral_encounter_rules::resolve(state, object);
			if (!gd::bool_field(state, resolved, key::ok, false)) {
				push_resolve_error(state, key::generated_neutral_adoption_failed_s, resolved);
				return empty_session(state);
			}
		}
	}
	const ArrayRef players = scenario_document.kind != Kind::Nil
			? player_identity_rules::from_slots(state, gd::as_array(gd::call_method(state, scenario_document, key::get_player_slots, {})))
			: state.new_array();
	Atom active_player_id = key::empty;
	for (int64_t index = 0; index < state.array_size(players); ++index) {
		const Value player = state.at(players, index);
		if (gd::to_bool(ai::vget(state, player, key::human, bool_value(false)))) {
			active_player_id = gd::stringify(state, ai::vget(state, player, key::player_id, str(key::empty)));
			break;
		}
	}
	const DictRef map_size = _map_size_from_document(state, map_document, metrics);
	const DictRef terrain_layers = _terrain_layers_from_document(state, map_document);
	const ArrayRef map_rows = _map_rows_from_document(state, map_document);
	const Atom hero_id_from_doc = _primary_hero_id(state, scenario_document, hero_id);
	const DictRef hero_state = _hero_state(state, hero_id_from_doc, start, difficulty);
	if (active_player_id != key::empty) {
		state.set(hero_state, str(key::player_id), str(active_player_id));
	}
	const ArrayRef towns = _town_states_from_objects(state, source_objects);
	for (int64_t town_index = 0; town_index < state.array_size(towns); ++town_index) {
		const DictRef town = gd::as_dict(state.at(towns, town_index));
		if (text_or(state, town, key::owner, str(key::neutral)) == key::neutral) {
			continue;
		}
		for (int64_t index = 0; index < state.array_size(players); ++index) {
			const Value player = state.at(players, index);
			const int64_t slot = gd::to_int(state, ai::vget(state, player, key::slot, int_value(0)));
			if (slot == gd::int_field(state, town, key::owner_slot, -1)) {
				state.set(town, str(key::controlling_player_id), str(gd::stringify(state, ai::vget(state, player, key::player_id, str(key::empty)))));
				state.set(town, str(key::team_id), str(gd::stringify(state, ai::vget(state, player, key::team_id, str(key::empty)))));
				break;
			}
		}
	}
	const ArrayRef resource_nodes = _resource_nodes_from_objects(state, source_objects, towns, map_rows);
	const DictRef scenery_validation = native_scenery_rules::validate(state, source_objects);
	if (!gd::bool_field(state, scenery_validation, key::ok, false)) {
		const Atom json = gd::engine_json_stringify(state, dict_value(scenery_validation));
		state.print_error(state.text(gd::format(state, key::generated_scenery_adoption_failed_s, {str(json)})));
		return empty_session(state);
	}
	const ArrayRef artifact_nodes = _artifact_nodes_from_objects(state, source_objects);
	const ArrayRef source_encounters = _encounters_from_objects(state, source_objects);
	const ArrayRef rare_guarded = _ensure_generated_rare_source_guards(state, resource_nodes, source_encounters);
	const ArrayRef encounters = _ensure_generated_guarded_reward_site_guards(state, resource_nodes, rare_guarded, dict_value(map_size));
	for (int64_t index = 0; index < state.array_size(encounters); ++index) {
		const Value encounter = state.at(encounters, index);
		if (!gd::is_dict(encounter) || gd::is_empty(state, encounter.ref)) {
			state.print_error(state.text(key::generated_guard_adoption_failed_refusing_an));
			return empty_session(state);
		}
	}
	const ArrayRef map_objects = _map_objects_from_objects(state, source_objects);
	const ArrayRef package_source_object_ids = state.new_array();
	const DictRef package_source_objects_by_id = state.new_dict();
	for (int64_t index = 0; index < state.array_size(source_objects); ++index) {
		const DictRef source_object = gd::as_dict(state.at(source_objects, index));
		const Atom source_placement_id = stripped(state, source_object, key::placement_id);
		if (source_placement_id != key::empty) {
			state.append(package_source_object_ids, str(source_placement_id));
			state.set(package_source_objects_by_id, str(source_placement_id), dict_value(gd::deep_duplicate_dict(state, source_object)));
		}
	}

	const bool has_hero = !gd::is_empty(state, hero_state);
	const DictRef overworld_state = state.new_dict();
	state.set(overworld_state, str(key::players), array_value(players));
	state.set(overworld_state, str(key::active_player_id), str(active_player_id));
	state.set(overworld_state, str(key::player_identity_version), int_value(1));
	state.set(overworld_state, str(key::player_identity_mode), str(key::native_player_slots_v1));
	state.set(overworld_state, str(key::map), array_value(map_rows));
	state.set(overworld_state, str(key::map_size), dict_value(map_size));
	state.set(overworld_state, str(key::terrain_layers), dict_value(terrain_layers));
	state.set(overworld_state, str(key::active_hero_id), str(hero_id_from_doc));
	state.set(overworld_state, str(key::player_heroes), array_value(has_hero ? single(state, dict_value(hero_state)) : state.new_array()));
	state.set(overworld_state, str(key::hero_position), dict_value(start));
	state.set(overworld_state, str(key::hero), dict_value(hero_state));
	{
		// hero_state.get("movement", {"current": 0, "max": 0}) if not hero_state.is_empty() else {...}
		Value movement;
		if (!has_hero || !state.lookup(hero_state, str(key::movement), movement)) {
			const DictRef idle = state.new_dict();
			state.set(idle, str(key::current), int_value(0));
			state.set(idle, str(key::max), int_value(0));
			movement = dict_value(idle);
		}
		state.set(overworld_state, str(key::movement), movement);
	}
	state.set(overworld_state, str(key::resources), dict_value(_opening_resource_stockpile(state)));
	state.set(overworld_state, str(key::army), has_hero ? field_or_new_dict(state, hero_state, key::army) : dict_value(state.new_dict()));
	state.set(overworld_state, str(key::encounters), array_value(encounters));
	state.set(overworld_state, str(key::resolved_encounters), array_value(state.new_array()));
	state.set(overworld_state, str(key::towns), array_value(towns));
	state.set(overworld_state, str(key::resource_nodes), array_value(resource_nodes));
	state.set(overworld_state, str(key::boats), array_value(boats_from_objects(state, source_objects)));
	state.set(overworld_state, str(key::map_objects), array_value(map_objects));
	state.set(overworld_state, str(key::package_source_object_ids), array_value(package_source_object_ids));
	state.set(overworld_state, str(key::package_source_objects_by_id), dict_value(package_source_objects_by_id));
	state.set(overworld_state, str(key::artifact_nodes), array_value(artifact_nodes));
	state.set(overworld_state, str(key::enemy_states), array_value(_opening_enemy_states(state, players)));
	state.set(overworld_state, str(key::map_package_ref), dict_value(map_ref));
	state.set(overworld_state, str(key::scenario_package_ref), dict_value(scenario_ref));
	state.set(overworld_state, str(key::native_random_map_package_session_adoption), dict_value(gd::deep_duplicate_dict(state, boundary)));
	state.set(overworld_state, str(key::generated_random_map_identity), field_or_new_dict(state, adoption, key::generated_identity));
	state.set(overworld_state, str(key::generated_random_map_validation), field_or_new_dict(state, adoption, key::validation_report));

	const DictRef runtime_scenario_record = _runtime_scenario_record_from_documents(state, scenario_id, map_document, scenario_document, overworld_state, hero_id_from_doc, start);
	if (!gd::is_empty(state, runtime_scenario_record)) {
		state.set(overworld_state, str(key::native_random_map_runtime_scenario_record), dict_value(runtime_scenario_record));
	}
	const DictRef draft_registration = state.new_dict();
	state.set(draft_registration, str(key::ok), bool_value(true));
	state.set(draft_registration, str(key::status), str(key::skipped_package_session_uses_loaded_documents));
	state.set(draft_registration, str(key::generated_scenario_draft_registry), bool_value(false));

	const Value session = session_state_store::new_session_data(state, session_id, scenario_id, hero_id_from_doc, 1, overworld_state, difficulty, key::skirmish);
	// A game generated from a seed takes its session id from the map, so the
	// same seed rolls the same level-ups.
	hero_command_rules::seed_start_heroes_from_session(state, session);
	const DictRef view = gd::object_view(state, session);
	state.set(view, str(key::save_version), int_value(kSaveVersion));
	state.set(view, str(key::game_state), str(key::overworld));
	state.set(view, str(key::scenario_status), str(key::in_progress));
	const DictRef flags = state.new_dict();
	state.set(flags, str(key::native_random_map_package_session_adoption), bool_value(true));
	state.set(flags, str(key::native_random_map_feature_gate), str(text(state, boundary, key::feature_gate)));
	state.set(flags, str(key::generated_random_map), bool_value(true));
	state.set(flags, str(key::generated_random_map_source), str(key::native_rmg_disk_package));
	const DictRef generated_boundary = state.new_dict();
	state.set(generated_boundary, str(key::authored_content_writeback), bool_value(false));
	state.set(generated_boundary, str(key::campaign_adoption), bool_value(false));
	state.set(generated_boundary, str(key::skirmish_browser_authored_listing), bool_value(false));
	state.set(generated_boundary, str(key::runtime_call_site_adoption), bool_value(true));
	state.set(generated_boundary, str(key::native_runtime_authoritative), bool_value(gd::bool_field(state, boundary, key::native_runtime_authoritative, false)));
	state.set(generated_boundary, str(key::full_parity_claim), bool_value(gd::bool_field(state, boundary, key::full_parity_claim, false)));
	state.set(generated_boundary, str(key::adoption_path), str(key::native_rmg_generated_package_saved_loaded_from_disk));
	state.set(generated_boundary, str(key::content_service_generated_draft), bool_value(false));
	state.set(generated_boundary, str(key::legacy_json_scenario_record), bool_value(false));
	state.set(flags, str(key::generated_random_map_boundary), dict_value(generated_boundary));
	state.set(flags, str(key::map_package_ref), dict_value(map_ref));
	state.set(flags, str(key::scenario_package_ref), dict_value(scenario_ref));
	state.set(flags, str(key::generated_random_map_provenance), field_or_new_dict(state, adoption, key::provenance));
	state.set(flags, str(key::generated_random_map_validation), field_or_new_dict(state, adoption, key::validation_report));
	state.set(flags, str(key::native_random_map_runtime_scenario_record), dict_value(runtime_scenario_record));
	state.set(flags, str(key::native_random_map_scenario_draft_registration), dict_value(draft_registration));
	state.set(view, str(key::flags), dict_value(flags));
	overworld_rules::normalize_overworld_state(state, gd::object_view(state, session));
	return session;
}

Value build_session_from_loaded_packages(State &state, DictRef map_load, DictRef scenario_load, DictRef boundary, Atom difficulty, DictRef options) {
	if (!gd::bool_field(state, map_load, key::ok, false) || !gd::bool_field(state, scenario_load, key::ok, false)) {
		return empty_session(state);
	}
	const DictRef adoption = state.new_dict();
	state.set(adoption, str(key::ok), bool_value(true));
	state.set(adoption, str(key::map_document), gd::field(state, map_load, key::map_document));
	state.set(adoption, str(key::scenario_document), gd::field(state, scenario_load, key::scenario_document));
	state.set(adoption, str(key::map_ref), field_or_new_dict(state, map_load, key::map_ref));
	state.set(adoption, str(key::scenario_ref), field_or_new_dict(state, scenario_load, key::scenario_ref));
	state.set(adoption, str(key::session_boundary_record), dict_value(gd::deep_duplicate_dict(state, boundary)));
	const Value map_document = gd::field(state, map_load, key::map_document);
	const bool has_map = map_document.kind != Kind::Nil;
	const Value width = has_map ? gd::call_method(state, map_document, key::get_width, {}) : int_value(0);
	const Value height = has_map ? gd::call_method(state, map_document, key::get_height, {}) : int_value(0);
	const Value level_count = has_map ? gd::call_method(state, map_document, key::get_level_count, {}) : int_value(1);
	const DictRef report = state.new_dict();
	const DictRef metrics = state.new_dict();
	state.set(metrics, str(key::width), width);
	state.set(metrics, str(key::height), height);
	state.set(metrics, str(key::level_count), level_count);
	state.set(report, str(key::metrics), dict_value(metrics));
	state.set(adoption, str(key::report), dict_value(report));
	return build_session_from_adoption(state, adoption, difficulty, options);
}

DictRef _primary_start(State &state, DictRef adoption) {
	const Value scenario_document = gd::field(state, adoption, key::scenario_document);
	if (scenario_document.kind != Kind::Nil && gd::has_method(state, scenario_document, key::get_start_contract)) {
		const DictRef start_contract = gd::as_dict(gd::call_method(state, scenario_document, key::get_start_contract, {}));
		if (state.has(start_contract, str(key::x)) && state.has(start_contract, str(key::y))) {
			return overworld_level_rules::position(state, start_contract);
		}
		const Value start_towns = array_or_nil(state, start_contract, key::player_start_towns);
		if (gd::is_array(start_towns)) {
			for (int64_t index = 0; index < state.array_size(start_towns.ref); ++index) {
				const Value town_value = state.at(start_towns.ref, index);
				if (gd::is_dict(town_value) && text(state, town_value.ref, key::owner) == key::player) {
					// Old packages may keep an off-road hero_start_tile: a new
					// session always starts at the town's entrance.
					return overworld_level_rules::town_entrance(state, town_value.ref);
				}
			}
		}
		const Value starts = array_or_nil(state, start_contract, key::player_starts);
		if (gd::is_array(starts) && state.array_size(starts.ref) != 0) {
			const Value first = state.at(starts.ref, 0);
			if (gd::is_dict(first)) {
				return overworld_level_rules::position(state, first.ref);
			}
		}
	}
	const DictRef origin = state.new_dict();
	state.set(origin, str(key::x), int_value(0));
	state.set(origin, str(key::y), int_value(0));
	return origin;
}

Atom _primary_hero_id(State &state, const Value &scenario_document, Atom fallback) {
	if (scenario_document.kind != Kind::Nil && gd::has_method(state, scenario_document, key::get_start_contract)) {
		const DictRef start_contract = gd::as_dict(gd::call_method(state, scenario_document, key::get_start_contract, {}));
		const Atom hero_id = text(state, start_contract, key::primary_hero_id);
		if (hero_id != key::empty) {
			return hero_id;
		}
	}
	return fallback != key::empty ? fallback : key::hero_lyra;
}

DictRef _hero_state(State &state, Atom hero_id, DictRef start, Atom difficulty) {
	const DictRef hero_template = gd::content_row(state, ContentTable::Hero, hero_id);
	const Atom faction_id = text_or(state, hero_template, key::faction_id, str(key::faction_embercourt));
	const Atom army_id = generated_start_army(faction_id);
	DictRef army_state = _army_state(state, gd::content_row(state, ContentTable::ArmyGroup, army_id));
	if (!hero_command_rules::army_has_troops(state, dict_value(army_state))) {
		army_state = hero_command_rules::starting_army_for_hero(state, hero_template, gd::format(state, key::generated_start_s, {str(hero_id)}));
	}
	const DictRef hero = hero_command_rules::build_hero_from_template(state, hero_template, start, army_state, str(difficulty));
	if (!gd::is_empty(state, hero)) {
		state.set(hero, str(key::is_primary), bool_value(true));
	}
	return hero;
}

DictRef _army_state(State &state, DictRef army_template) {
	const ArrayRef stacks = state.new_array();
	for (const Value &stack : gd::field_items(state, army_template, str(key::stacks))) {
		if (gd::is_dict(stack)) {
			const Atom unit_id = text(state, stack.ref, key::unit_id);
			const int64_t count = compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0));
			const DictRef entry = state.new_dict();
			state.set(entry, str(key::unit_id), str(unit_id));
			state.set(entry, str(key::count), int_value(count));
			state.append(stacks, dict_value(entry));
		}
	}
	const Atom id = text(state, army_template, key::id);
	const Atom name = text_or(state, army_template, key::name, str(key::field_army));
	const DictRef army = state.new_dict();
	state.set(army, str(key::id), str(id));
	state.set(army, str(key::name), str(name));
	state.set(army, str(key::stacks), array_value(stacks));
	return army;
}

ArrayRef _opening_enemy_states(State &state, ArrayRef players) {
	const ArrayRef states = state.new_array();
	const ArrayRef configs = player_identity_rules::enemy_configs(state, players);
	for (int64_t index = 0; index < state.array_size(configs); ++index) {
		const Value config = state.at(configs, index);
		const DictRef treasury = _opening_resource_stockpile(state);
		state.set(gd::as_dict(config), str(key::treasury), dict_value(treasury));
		state.append(states, config);
	}
	return states;
}

DictRef _opening_resource_stockpile(State &state) {
	const DictRef resources = state.new_dict();
	// OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS, in order.
	for (const Atom resource_key : {key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt}) {
		state.set(resources, str(resource_key), int_value(0));
	}
	state.set(resources, str(key::gold), int_value(5000));
	state.set(resources, str(key::wood), int_value(10));
	state.set(resources, str(key::ore), int_value(10));
	return resources;
}

DictRef _map_size_from_document(State &state, const Value &map_document, DictRef metrics) {
	int64_t width = gd::int_field(state, metrics, key::width, 0);
	int64_t height = gd::int_field(state, metrics, key::height, 0);
	int64_t level_count = gd::int_field(state, metrics, key::level_count, 1);
	if (map_document.kind != Kind::Nil) {
		width = gd::to_int(state, gd::call_method(state, map_document, key::get_width, {}));
		height = gd::to_int(state, gd::call_method(state, map_document, key::get_height, {}));
		level_count = gd::to_int(state, gd::call_method(state, map_document, key::get_level_count, {}));
	}
	const DictRef size = state.new_dict();
	state.set(size, str(key::width), int_value(width));
	state.set(size, str(key::height), int_value(height));
	state.set(size, str(key::x), int_value(width));
	state.set(size, str(key::y), int_value(height));
	state.set(size, str(key::level_count), int_value(level_count));
	return size;
}

DictRef _terrain_layers_from_document(State &state, const Value &map_document) {
	if (map_document.kind != Kind::Nil && gd::has_method(state, map_document, key::get_terrain_layers)) {
		const DictRef layers = gd::as_dict(gd::call_method(state, map_document, key::get_terrain_layers, {}));
		if (!gd::is_empty(state, layers)) {
			return layers;
		}
	}
	return state.new_dict();
}

ArrayRef _map_rows_from_document(State &state, const Value &map_document) {
	if (map_document.kind == Kind::Nil) {
		return state.new_array();
	}
	const int64_t width = gd::to_int(state, gd::call_method(state, map_document, key::get_width, {}));
	const int64_t height = gd::to_int(state, gd::call_method(state, map_document, key::get_height, {}));
	const gd::PackedRef codes = gd::as_ints(gd::call_method(state, map_document, key::get_tile_layer_u16, {str(key::terrain), int_value(0)}));
	const DictRef layers = _terrain_layers_from_document(state, map_document);
	const Value ids_by_code = field_or_new_array(state, layers, key::terrain_id_by_code);
	const int64_t code_count = gd::packed_size(state, codes);
	std::vector<int32_t> code_values;
	if (code_count > 0) {
		const int32_t *raw = gd::packed_ints(state, codes);
		code_values.assign(raw, raw + code_count);
	}
	const ArrayRef rows = state.new_array();
	for (int64_t y = 0; y < height; ++y) {
		const ArrayRef row = state.new_array();
		for (int64_t x = 0; x < width; ++x) {
			const int64_t index = gd::add(gd::mul(y, width), x);
			const int64_t code = index >= 0 && index < code_count ? code_values[static_cast<size_t>(index)] : 0;
			state.append(row, str(_terrain_id_for_code(state, ids_by_code, code)));
		}
		state.append(rows, array_value(row));
	}
	return rows;
}

Atom _terrain_id_for_code(State &state, const Value &ids_by_code, int64_t code) {
	if (gd::is_array(ids_by_code)) {
		if (code >= 0 && code < state.array_size(ids_by_code.ref)) {
			return gd::stringify(state, state.at(ids_by_code.ref, code));
		}
	} else if (ids_by_code.kind == Kind::PackedString) {
		if (code >= 0 && code < gd::packed_size(state, ids_by_code.ref)) {
			return gd::packed_string(state, ids_by_code.ref, code);
		}
	}
	return key::grass;
}

ArrayRef _document_objects(State &state, const Value &map_document) {
	const ArrayRef objects = state.new_array();
	if (map_document.kind == Kind::Nil) {
		return objects;
	}
	const int64_t count = gd::to_int(state, gd::call_method(state, map_document, key::get_object_count, {}));
	for (int64_t index = 0; index < count; ++index) {
		const DictRef object = gd::as_dict(gd::call_method(state, map_document, key::get_object_by_index, {int_value(index)}));
		if (!gd::is_empty(state, object)) {
			state.append(objects, dict_value(object));
		}
	}
	return objects;
}

ArrayRef _town_states_from_objects(State &state, ArrayRef objects) {
	const ArrayRef towns = state.new_array();
	for (int64_t index = 0; index < state.array_size(objects); ++index) {
		const DictRef object = gd::as_dict(state.at(objects, index));
		const Atom record_kind = gd::stringify(state, state.get(object, str(key::native_record_kind), state.get(object, str(key::kind), str(key::empty))));
		if (record_kind != key::town && text(state, object, key::kind) != key::town) {
			continue;
		}
		const DictRef town_identity = _project_town_identity_from_h3m_record(state, object);
		const Atom identity_town_id = gd::stringify(state, state.get(town_identity, str(key::town_id), state.get(object, str(key::town_id), str(key::empty))));
		const Atom town_id = gd::to_string(gd::call_method(state, gd::autoload(state, key::ContentService), key::canonical_town_id, {str(identity_town_id)}));
		Atom town_faction_id = gd::stringify(state, state.get(town_identity, str(key::faction_id), state.get(object, str(key::faction_id), str(key::empty))));
		const DictRef town_template = gd::content_row(state, ContentTable::Town, town_id);
		if (gd::is_empty(state, gd::content_row(state, ContentTable::Faction, town_faction_id))) {
			town_faction_id = text_or(state, town_template, key::faction_id, str(town_faction_id));
		}
		const int64_t owner_slot = _int_or_default(state, state.get(object, str(key::owner_slot), state.get(object, str(key::player_slot), int_value(-1))), -1);
		const int64_t player_slot = _int_or_default(state, state.get(object, str(key::player_slot), state.get(object, str(key::owner_slot), int_value(-1))), -1);
		const DictRef town_state = gd::deep_duplicate_dict(state, object);
		const DictRef fields = state.new_dict();
		state.set(fields, str(key::placement_id), str(text(state, object, key::placement_id)));
		state.set(fields, str(key::town_id), str(town_id));
		state.set(fields, str(key::x), int_value(gd::int_field(state, object, key::x, 0)));
		state.set(fields, str(key::y), int_value(gd::int_field(state, object, key::y, 0)));
		state.set(fields, str(key::owner), str(text_or(state, object, key::owner, str(key::neutral))));
		state.set(fields, str(key::owner_slot), int_value(owner_slot));
		state.set(fields, str(key::player_slot), int_value(player_slot));
		state.set(fields, str(key::player_type), str(text(state, object, key::player_type)));
		state.set(fields, str(key::team_id), str(text(state, object, key::team_id)));
		state.set(fields, str(key::faction_id), str(town_faction_id));
		state.set(fields, str(key::source_h3maped_faction_id), str(gd::stringify(state, state.get(object, str(key::h3maped_faction_id), state.get(object, str(key::faction_id), str(key::empty))))));
		state.set(fields, str(key::source_package_town_id), str(text(state, object, key::town_id)));
		state.set(fields, str(key::is_start_town), bool_value(_bool_or_default(state, state.get(object, str(key::is_start_town), state.get(object, str(key::start_anchor), bool_value(false))), false)));
		state.set(fields, str(key::start_anchor), bool_value(_bool_or_default(state, state.get(object, str(key::start_anchor), state.get(object, str(key::is_start_town), bool_value(false))), false)));
		state.set(fields, str(key::body_tiles), array_value(duplicated_array_or_new(state, either_field(state, object, key::package_body_tiles, key::body_tiles))));
		state.set(fields, str(key::package_block_tiles), array_value(duplicated_array_or_new(state, gd::field(state, object, key::package_block_tiles))));
		state.set(fields, str(key::visit_tile), dict_value(duplicated_dict_or_new(state, gd::field(state, object, key::visit_tile))));
		state.set(fields, str(key::package_visit_tiles), array_value(duplicated_array_or_new(state, gd::field(state, object, key::package_visit_tiles))));
		state.set(fields, str(key::blocking_body), bool_value(_bool_or_default(state, state.get(object, str(key::blocking_body), bool_value(true)), true)));
		state.set(fields, str(key::built_buildings), array_value(duplicated_array_or_new(state, gd::field(state, town_template, key::starting_building_ids))));
		state.set(fields, str(key::available_recruits), dict_value(state.new_dict()));
		state.set(fields, str(key::garrison), array_value(duplicated_array_or_new(state, gd::field(state, town_template, key::garrison))));
		gd::merge(state, town_state, fields, true);
		state.append(towns, dict_value(town_state));
	}
	return towns;
}

DictRef _project_town_identity_from_h3m_record(State &state, DictRef object) {
	for (const Atom field : {key::h3maped_faction_id, key::faction_id, key::source_h3maped_faction_id}) {
		const Atom token = stripped(state, object, field);
		const DictRef identity = _project_town_identity_for_h3m_token(state, token);
		if (!gd::is_empty(state, identity)) {
			return identity;
		}
	}
	const Atom faction_id = stripped(state, object, key::faction_id);
	if (!gd::is_empty(state, gd::content_row(state, ContentTable::Faction, faction_id))) {
		Atom town_id = stripped(state, object, key::town_id);
		if (gd::is_empty(state, gd::content_row(state, ContentTable::Town, town_id))) {
			town_id = _project_town_id_for_faction(state, faction_id);
		}
		const DictRef identity = state.new_dict();
		state.set(identity, str(key::faction_id), str(faction_id));
		state.set(identity, str(key::town_id), str(town_id));
		return identity;
	}
	const DictRef identity = state.new_dict();
	state.set(identity, str(key::faction_id), str(key::empty));
	state.set(identity, str(key::town_id), str(text(state, object, key::town_id)));
	return identity;
}

DictRef _project_town_identity_for_h3m_token(State &state, Atom token) {
	std::string lowered;
	if (lower_ascii(state.text(gd::strip_edges(state, token)), lowered)) {
		// Every character is ASCII now, so substr counts bytes.
		if (lowered.compare(0, 3, "h3_") == 0) {
			lowered = lowered.substr(3);
		}
		if (lowered.compare(0, 4, "h3m_") == 0) {
			lowered = lowered.substr(4);
		}
		// H3M_TOWN_TYPE_PROJECT_IDENTITY.
		const Atom normalized = state.intern(lowered);
		Atom faction_id = key::empty;
		Atom town_id = key::empty;
		if (normalized == key::castle) {
			faction_id = key::faction_embercourt;
			town_id = key::town_riverwatch;
		} else if (normalized == key::rampart) {
			faction_id = key::faction_thornwake;
			town_id = key::town_thornwake_graftroot_caravan;
		} else if (normalized == key::tower || normalized == key::elemental) {
			faction_id = key::faction_sunvault;
			town_id = key::town_prismhearth;
		} else if (normalized == key::inferno || normalized == key::stronghold) {
			faction_id = key::faction_brasshollow;
			town_id = key::town_brasshollow_orevein_gantry;
		} else if (normalized == key::necropolis || normalized == key::dungeon) {
			faction_id = key::faction_veilmourn;
			town_id = key::town_veilmourn_bellwake_harbor;
		} else if (normalized == key::fortress) {
			faction_id = key::faction_mireclaw;
			town_id = key::town_duskfen;
		}
		if (faction_id != key::empty) {
			const DictRef identity = state.new_dict();
			state.set(identity, str(key::faction_id), str(faction_id));
			state.set(identity, str(key::town_id), str(town_id));
			return identity;
		}
	}
	return state.new_dict();
}

Atom _project_town_id_for_faction(State &state, Atom faction_id) {
	const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
	const Atom seed_town_id = text(state, faction, key::seed_town_id);
	if (!gd::is_empty(state, gd::content_row(state, ContentTable::Town, seed_town_id))) {
		return seed_town_id;
	}
	for (const Value &town_id_value : gd::field_items(state, faction, str(key::town_ids))) {
		const Atom town_id = gd::stringify(state, town_id_value);
		if (!gd::is_empty(state, gd::content_row(state, ContentTable::Town, town_id))) {
			return town_id;
		}
	}
	return key::town_riverwatch;
}

int64_t _int_or_default(State &state, const Value &value, int64_t default_value) {
	if (value.kind == Kind::Nil) {
		return default_value;
	}
	return gd::to_int(state, value);
}

bool _bool_or_default(State &state, const Value &value, bool default_value) {
	if (value.kind == Kind::Nil) {
		return default_value;
	}
	if (value.kind == Kind::Bool) {
		return gd::to_bool(value);
	}
	if (value.kind == Kind::Int || value.kind == Kind::Float) {
		return gd::to_int(state, value) != 0;
	}
	std::string lowered;
	if (!lower_ascii(state.text(gd::strip_edges(state, gd::stringify(state, value))), lowered)) {
		return default_value;
	}
	const Atom text_value = state.intern(lowered);
	if (text_value == key::true_ || text_value == key::n1 || text_value == key::yes || text_value == key::on) {
		return true;
	}
	if (text_value == key::false_ || text_value == key::k_0 || text_value == key::no || text_value == key::off || text_value == key::empty) {
		return false;
	}
	return default_value;
}

ArrayRef _resource_nodes_from_objects(State &state, ArrayRef objects, ArrayRef towns, ArrayRef map_rows) {
	const ArrayRef nodes = state.new_array();
	for (int64_t index = 0; index < state.array_size(objects); ++index) {
		const DictRef object = gd::as_dict(state.at(objects, index));
		const Atom kind = text(state, object, key::kind);
		if (!is_site_kind(kind)) {
			continue;
		}
		if (generated_reward_rules::is_skipped(state, object)) {
			continue;
		}
		const DictRef translated = generated_reward_rules::resolve(state, object, towns, map_rows);
		if (!gd::is_empty(state, translated)) {
			state.set(translated, str(key::collected), bool_value(false));
			state.append(nodes, dict_value(translated));
			continue;
		}
		const Atom site_id = _resource_site_id_for_object(state, object);
		if (site_id == key::empty) {
			continue;
		}
		const DictRef node = gd::deep_duplicate_dict(state, object);
		state.set(node, str(key::site_id), str(site_id));
		state.set(node, str(key::collected), bool_value(false));
		state.append(nodes, dict_value(node));
	}
	return nodes;
}

ArrayRef boats_from_objects(State &state, ArrayRef objects) {
	const ArrayRef boats = state.new_array();
	for (int64_t index = 0; index < state.array_size(objects); ++index) {
		const Value object = state.at(objects, index);
		const DictRef tile = gd::is_dict(object) ? generated_reward_rules::boat_tile(state, object.ref) : state.new_dict();
		if (gd::is_empty(state, tile)) {
			continue;
		}
		const Atom placement_id = text_or(state, object.ref, key::placement_id, int_value(state.array_size(boats)));
		const Atom id = gd::format(state, key::boat_s, {str(placement_id)});
		const int64_t x = gd::to_int(state, gd::index(state, tile, str(key::x)));
		const int64_t y = gd::to_int(state, gd::index(state, tile, str(key::y)));
		const int64_t level = gd::to_int(state, gd::index(state, tile, str(key::level)));
		const DictRef boat = state.new_dict();
		state.set(boat, str(key::id), str(id));
		state.set(boat, str(key::x), int_value(x));
		state.set(boat, str(key::y), int_value(y));
		state.set(boat, str(key::level), int_value(level));
		state.set(boat, str(key::hero_id), str(key::empty));
		state.append(boats, dict_value(boat));
	}
	return boats;
}

ArrayRef _artifact_nodes_from_objects(State &state, ArrayRef objects) {
	const ArrayRef nodes = state.new_array();
	for (int64_t index = 0; index < state.array_size(objects); ++index) {
		const DictRef object = gd::as_dict(state.at(objects, index));
		if (text(state, object, key::artifact_id) == key::empty) {
			continue;
		}
		const DictRef node = gd::deep_duplicate_dict(state, object);
		state.set(node, str(key::collected), bool_value(false));
		state.append(nodes, dict_value(node));
	}
	return nodes;
}

ArrayRef _encounters_from_objects(State &state, ArrayRef objects) {
	const ArrayRef encounters = state.new_array();
	for (int64_t index = 0; index < state.array_size(objects); ++index) {
		const DictRef object = gd::as_dict(state.at(objects, index));
		const Atom kind = text(state, object, key::kind);
		const Atom native_kind = text(state, object, key::native_record_kind);
		if (kind != key::guard && native_kind != key::guard) {
			continue;
		}
		const DictRef encounter = gd::deep_duplicate_dict(state, object);
		if (state.has(encounter, str(key::native_guard_quantity))) {
			const DictRef resolved = generated_neutral_encounter_rules::resolve(state, encounter);
			if (!gd::bool_field(state, resolved, key::ok, false)) {
				push_resolve_error(state, key::generated_neutral_adoption_failed_s, resolved);
				return state.new_array();
			}
			state.append(encounters, gd::index(state, resolved, str(key::encounter)));
			continue;
		}
		Atom encounter_id = text(state, encounter, key::encounter_id);
		if (encounter_id == key::empty) {
			encounter_id = text(state, encounter, key::object_id);
		}
		if (encounter_id != key::empty && gd::is_empty(state, gd::content_row(state, ContentTable::Encounter, encounter_id))) {
			state.set(encounter, str(key::native_guard_object_id), str(encounter_id));
			encounter_id = key::empty;
		}
		if (encounter_id == key::empty) {
			encounter_id = key::encounter_mire_raid;
		}
		state.set(encounter, str(key::encounter_id), str(encounter_id));
		if (text(state, encounter, key::object_id) == key::empty) {
			state.set(encounter, str(key::object_id), str(encounter_id));
		}
		state.append(encounters, dict_value(encounter));
	}
	return encounters;
}

ArrayRef _ensure_generated_rare_source_guards(State &state, ArrayRef resource_nodes, ArrayRef encounters) {
	const ArrayRef result = gd::deep_duplicate_array(state, encounters);
	for (int64_t index = 0; index < state.array_size(resource_nodes); ++index) {
		const Value node_value = state.at(resource_nodes, index);
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		if (!_generated_resource_node_is_rare_source(state, node)) {
			continue;
		}
		if (_resource_node_has_linked_guard(state, result, node)) {
			continue;
		}
		state.append(result, dict_value(_supplemental_rare_source_guard(state, node)));
	}
	return result;
}

ArrayRef _ensure_generated_guarded_reward_site_guards(State &state, ArrayRef resource_nodes, ArrayRef encounters, const Value &map_size) {
	const ArrayRef result = gd::deep_duplicate_array(state, encounters);
	for (int64_t index = 0; index < state.array_size(resource_nodes); ++index) {
		const Value node_value = state.at(resource_nodes, index);
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text(state, node, key::site_id));
		if (!_generated_guarded_reward_site_contract_is_live(state, site)) {
			continue;
		}
		// A Warrior's Tomb fights no guard of its own; the native one beside it
		// already holds it.
		if (gd::bool_field(state, node, key::generated_reward_unguarded, false)) {
			continue;
		}
		if (_resource_node_has_linked_guard(state, result, node)) {
			continue;
		}
		const DictRef guard = _supplemental_guarded_reward_site_guard(state, node, site, map_size);
		if (!gd::is_empty(state, guard)) {
			state.append(result, dict_value(guard));
		}
	}
	return result;
}

bool _generated_guarded_reward_site_contract_is_live(State &state, DictRef site) {
	if (gd::is_empty(state, site) || text(state, site, key::family) != key::guarded_reward_site) {
		return false;
	}
	const Value runtime_boundary = dict_or_nil(state, site, key::runtime_boundary);
	const Value contract = dict_or_nil(state, site, key::guarded_reward_contract);
	const Value guard_profile = dict_or_nil(state, site, key::guard_profile);
	const Atom encounter_id = gd::strip_edges(state, gd::stringify(state, get_in(state, contract, key::guard_encounter_id, str(key::empty))));
	const Atom army_group_id = gd::strip_edges(state, gd::stringify(state, get_in(state, contract, key::guard_army_group_id, str(key::empty))));
	return gd::to_bool(get_in(state, runtime_boundary, key::guard_resolution_runtime_adopted, bool_value(false)))
			&& gd::to_bool(get_in(state, contract, key::runtime_guard_resolution_adopted, bool_value(false)))
			&& !gd::to_bool(get_in(state, contract, key::metadata_only_guard_contract, bool_value(true)))
			&& gd::to_bool(get_in(state, contract, key::clear_required_for_reward, bool_value(false)))
			&& gd::to_bool(get_in(state, guard_profile, key::runtime_guard_resolution_adopted, bool_value(false)))
			&& !gd::to_bool(get_in(state, guard_profile, key::metadata_only, bool_value(true)))
			&& encounter_id != key::empty
			&& army_group_id != key::empty
			&& !gd::is_empty(state, gd::content_row(state, ContentTable::Encounter, encounter_id))
			&& !gd::is_empty(state, gd::content_row(state, ContentTable::ArmyGroup, army_group_id));
}

DictRef _supplemental_guarded_reward_site_guard(State &state, DictRef node, DictRef site, const Value &map_size) {
	const Atom placement_id = stripped(state, node, key::placement_id);
	const Atom site_id = gd::strip_edges(state, gd::stringify(state, state.get(site, str(key::id), state.get(node, str(key::site_id), str(key::empty)))));
	const Value contract = dict_or_nil(state, site, key::guarded_reward_contract);
	if (placement_id == key::empty || site_id == key::empty || gd::stringify(state, get_in(state, contract, key::resource_site_id, str(key::empty))) != site_id) {
		return state.new_dict();
	}
	const Atom encounter_id = gd::strip_edges(state, gd::stringify(state, get_in(state, contract, key::guard_encounter_id, str(key::empty))));
	const Atom army_group_id = gd::strip_edges(state, gd::stringify(state, get_in(state, contract, key::guard_army_group_id, str(key::empty))));
	// visit_tiles: the node's package_visit_tiles when it is an Array, else an
	// empty one (which returns at once).
	const Value visit_tiles_value = array_or_nil(state, node, key::package_visit_tiles);
	if (!gd::is_array(visit_tiles_value) || state.array_size(visit_tiles_value.ref) == 0) {
		return state.new_dict();
	}
	const ArrayRef visit_tiles = visit_tiles_value.ref;
	const Value first_visit = state.at(visit_tiles, 0);
	const DictRef visit_tile = gd::is_dict(first_visit) ? gd::deep_duplicate_dict(state, first_visit.ref) : state.new_dict();
	if (gd::is_empty(state, visit_tile)) {
		return state.new_dict();
	}
	const int64_t level = gd::to_int(state, state.get(visit_tile, str(key::level), state.get(node, str(key::level), int_value(0))));
	state.set(visit_tile, str(key::level), int_value(level));
	const ArrayRef engagement_tiles = state.new_array();
	for (int64_t index = 0; index < state.array_size(visit_tiles); ++index) {
		const Value entrance = state.at(visit_tiles, index);
		if (gd::is_dict(entrance)) {
			const ArrayRef tiles = _generated_guarded_reward_engagement_tiles(state, entrance.ref, map_size);
			for (int64_t tile_index = 0; tile_index < state.array_size(tiles); ++tile_index) {
				const Value tile = state.at(tiles, tile_index);
				if (!gd::array_has(state, engagement_tiles, tile)) {
					state.append(engagement_tiles, tile);
				}
			}
		}
	}
	if (state.array_size(engagement_tiles) == 0) {
		return state.new_dict();
	}
	const Value body_tiles = array_or_nil(state, node, key::package_body_tiles);
	const DictRef guard_link = state.new_dict();
	state.set(guard_link, str(key::guard_role), str(key::guards_resource_site));
	state.set(guard_link, str(key::target_kind), str(key::resource_node));
	state.set(guard_link, str(key::target_id), str(site_id));
	state.set(guard_link, str(key::target_placement_id), str(placement_id));
	state.set(guard_link, str(key::blocks_approach), bool_value(true));
	state.set(guard_link, str(key::clear_required_for_target), bool_value(true));
	state.set(guard_link, str(key::guard_army_group_id), str(army_group_id));
	state.set(guard_link, str(key::guard_encounter_id), str(encounter_id));
	state.set(guard_link, str(key::source), str(key::generated_package_live_guarded_reward_contract));
	state.set(guard_link, str(key::target_body_tiles), array_value(duplicated_array_or_new(state, body_tiles)));
	state.set(guard_link, str(key::target_visit_tiles), array_value(gd::deep_duplicate_array(state, visit_tiles)));
	DictRef guard = state.new_dict();
	state.set(guard, str(key::placement_id), str(gd::format(state, key::generated_guarded_reward_s, {str(placement_id)})));
	state.set(guard, str(key::kind), str(key::guard));
	state.set(guard, str(key::package_kind), str(key::guard));
	state.set(guard, str(key::encounter_id), str(encounter_id));
	state.set(guard, str(key::object_id), str(encounter_id));
	state.set(guard, str(key::enemy_group_id), str(army_group_id));
	state.set(guard, str(key::generated_package_guard_policy), str(key::live_guarded_reward_contract));
	state.set(guard, str(key::generated_guard_engagement_policy), str(key::site_entrances_only_v1));
	state.set(guard, str(key::target_kind), str(key::resource));
	state.set(guard, str(key::target_placement_id), str(placement_id));
	state.set(guard, str(key::guard_link), dict_value(guard_link));
	state.set(guard, str(key::x), int_value(gd::to_int(state, state.get(visit_tile, str(key::x), state.get(node, str(key::x), int_value(0))))));
	state.set(guard, str(key::y), int_value(gd::to_int(state, state.get(visit_tile, str(key::y), state.get(node, str(key::y), int_value(0))))));
	state.set(guard, str(key::level), int_value(level));
	state.set(guard, str(key::primary_tile), dict_value(gd::deep_duplicate_dict(state, visit_tile)));
	state.set(guard, str(key::body_tiles), array_value(single(state, dict_value(gd::deep_duplicate_dict(state, visit_tile)))));
	state.set(guard, str(key::package_body_tiles), array_value(single(state, dict_value(gd::deep_duplicate_dict(state, visit_tile)))));
	state.set(guard, str(key::package_block_tiles), array_value(state.new_array()));
	state.set(guard, str(key::package_visit_tiles), array_value(single(state, dict_value(gd::deep_duplicate_dict(state, visit_tile)))));
	state.set(guard, str(key::visit_tile), dict_value(gd::deep_duplicate_dict(state, visit_tile)));
	state.set(guard, str(key::blocking_body), bool_value(false));
	state.set(guard, str(key::passability_class), str(key::neutral_stack_blocking));
	state.set(guard, str(key::package_guard_engagement_tiles), array_value(engagement_tiles));
	state.set(guard, str(key::package_guard_engagement_tile_count), int_value(state.array_size(engagement_tiles)));
	guard = generated_neutral_encounter_rules::with_authored_guard_art(state, guard);
	// A translated creature bank fields the guard of its rolled level.
	const ArrayRef bank_stacks = generated_reward_rules::bank_guard_stacks(state, node);
	if (state.array_size(bank_stacks) != 0) {
		const int64_t bank_level = gd::int_field(state, node, key::generated_bank_level, 0);
		const DictRef army = gd::deep_duplicate_dict(state, gd::content_row(state, ContentTable::ArmyGroup, army_group_id));
		state.set(army, str(key::id), str(gd::format(state, key::s_bank_level_d, {str(army_group_id), int_value(bank_level)})));
		state.set(army, str(key::stacks), array_value(bank_stacks));
		state.set(guard, str(key::enemy_army), dict_value(army));
		state.set(guard, str(key::generated_bank_level), int_value(bank_level));
		guard = generated_neutral_encounter_rules::with_lead_unit_art(state, guard, key::creature_bank_level_v1);
	}
	return guard;
}

ArrayRef _generated_guarded_reward_engagement_tiles(State &state, DictRef visit_tile, const Value &map_size) {
	const int64_t center_x = gd::int_field(state, visit_tile, key::x, -1);
	const int64_t center_y = gd::int_field(state, visit_tile, key::y, -1);
	const Vector2i center = Vector2i::of(center_x, center_y);
	if (!_generated_source_in_bounds(state, center, map_size)) {
		return state.new_array();
	}
	// The site's own defenders: entering starts their battle, and no ring
	// around the site overrides the native road and guard control.
	const DictRef tile = state.new_dict();
	state.set(tile, str(key::x), int_value(center.x));
	state.set(tile, str(key::y), int_value(center.y));
	state.set(tile, str(key::level), int_value(gd::int_field(state, visit_tile, key::level, 0)));
	return single(state, dict_value(tile));
}

bool _generated_resource_node_is_rare_source(State &state, DictRef node) {
	const Atom placement_id = text(state, node, key::placement_id);
	if (!gd::begins_with(state, placement_id, key::h3maped_small_)) {
		return false;
	}
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text(state, node, key::site_id));
	// [site.get("claim_rewards", site.get("rewards", {})), site.get("control_income", {})],
	// read only: a missing bucket is an empty Dictionary, which has no keys.
	const Value buckets[2] = {either_field(state, site, key::claim_rewards, key::rewards), gd::field(state, site, key::control_income)};
	for (const Value &bucket : buckets) {
		if (!gd::is_dict(bucket)) {
			continue;
		}
		for (const Value &resource_key : gd::items(state, bucket)) {
			const Atom resource_id = gd::stringify(state, resource_key);
			if (is_rare_resource(resource_id) && gd::to_int(state, state.get(bucket.ref, resource_key, int_value(0))) > 0) {
				return true;
			}
		}
	}
	return false;
}

bool _resource_node_has_linked_guard(State &state, ArrayRef encounters, DictRef node) {
	const Atom placement_id = text(state, node, key::placement_id);
	for (int64_t index = 0; index < state.array_size(encounters); ++index) {
		const Value encounter_value = state.at(encounters, index);
		if (!gd::is_dict(encounter_value)) {
			continue;
		}
		const DictRef encounter = encounter_value.ref;
		if (text(state, encounter, key::target_kind) == key::resource && text(state, encounter, key::target_placement_id) == placement_id) {
			return true;
		}
		const Value guard_link = dict_or_nil(state, encounter, key::guard_link);
		if (gd::stringify(state, get_in(state, guard_link, key::target_placement_id, str(key::empty))) == placement_id) {
			return true;
		}
	}
	return false;
}

DictRef _supplemental_rare_source_guard(State &state, DictRef node) {
	const Atom placement_id = text(state, node, key::placement_id);
	const int64_t x = gd::int_field(state, node, key::x, 0);
	const int64_t y = gd::int_field(state, node, key::y, 0);
	const int64_t level = gd::int_field(state, node, key::level, 0);
	// One tile Dictionary, shared by every field that names it.
	const DictRef tile = state.new_dict();
	state.set(tile, str(key::x), int_value(x));
	state.set(tile, str(key::y), int_value(y));
	state.set(tile, str(key::level), int_value(level));
	const DictRef guard_link = state.new_dict();
	state.set(guard_link, str(key::guard_role), str(key::guards_resource_source));
	state.set(guard_link, str(key::target_kind), str(key::resource_node));
	state.set(guard_link, str(key::target_id), str(text(state, node, key::site_id)));
	state.set(guard_link, str(key::target_placement_id), str(placement_id));
	state.set(guard_link, str(key::blocks_approach), bool_value(true));
	state.set(guard_link, str(key::clear_required_for_target), bool_value(true));
	state.set(guard_link, str(key::source), str(key::generated_package_rare_source_guard_pressure_runtime_adoption));
	const DictRef guard = state.new_dict();
	state.set(guard, str(key::placement_id), str(gd::format(state, key::h3maped_small_rare_source_guard_s, {str(placement_id)})));
	state.set(guard, str(key::kind), str(key::guard));
	state.set(guard, str(key::package_kind), str(key::guard));
	state.set(guard, str(key::encounter_id), str(key::encounter_mire_raid));
	state.set(guard, str(key::object_id), str(key::encounter_mire_raid));
	state.set(guard, str(key::native_guard_object_id), str(key::encounter_h3maped_mine_guard));
	state.set(guard, str(key::generated_package_guard_policy), str(key::rare_economy_source_requires_runtime_guard_link));
	state.set(guard, str(key::target_kind), str(key::resource));
	state.set(guard, str(key::target_placement_id), str(placement_id));
	state.set(guard, str(key::guard_link), dict_value(guard_link));
	state.set(guard, str(key::guard_value), int_value(600));
	state.set(guard, str(key::x), int_value(x));
	state.set(guard, str(key::y), int_value(y));
	state.set(guard, str(key::level), int_value(level));
	state.set(guard, str(key::primary_tile), dict_value(tile));
	state.set(guard, str(key::body_tiles), array_value(single(state, dict_value(tile))));
	state.set(guard, str(key::package_body_tiles), array_value(single(state, dict_value(tile))));
	state.set(guard, str(key::package_block_tiles), array_value(single(state, dict_value(tile))));
	state.set(guard, str(key::package_visit_tiles), array_value(single(state, dict_value(tile))));
	state.set(guard, str(key::visit_tile), dict_value(tile));
	state.set(guard, str(key::blocking_body), bool_value(true));
	state.set(guard, str(key::passability_class), str(key::neutral_stack_blocking));
	state.set(guard, str(key::package_guard_engagement_tiles), array_value(single(state, dict_value(tile))));
	state.set(guard, str(key::package_guard_engagement_tile_count), int_value(1));
	const DictRef resolved = generated_neutral_encounter_rules::resolve_supplemental(state, guard, text(state, node, key::site_id));
	if (!gd::bool_field(state, resolved, key::ok, false)) {
		push_resolve_error(state, key::supplemental_neutral_adoption_failed_s, resolved);
		return state.new_dict();
	}
	return gd::as_dict(gd::index(state, resolved, str(key::encounter)));
}

bool _generated_source_in_bounds(State &state, Vector2i tile, const Value &map_size) {
	if (gd::is_vector2i(map_size)) {
		return tile.x >= 0 && tile.y >= 0 && tile.x < map_size.vx() && tile.y < map_size.vy();
	}
	if (gd::is_dict(map_size)) {
		if (!(tile.x >= 0 && tile.y >= 0)) {
			return false;
		}
		if (!(tile.x < gd::to_int(state, state.get(map_size.ref, str(key::x), state.get(map_size.ref, str(key::width), int_value(0)))))) {
			return false;
		}
		return tile.y < gd::to_int(state, state.get(map_size.ref, str(key::y), state.get(map_size.ref, str(key::height), int_value(0))));
	}
	return false;
}

ArrayRef _map_objects_from_objects(State &state, ArrayRef source_objects) {
	const ArrayRef objects = state.new_array();
	for (int64_t index = 0; index < state.array_size(source_objects); ++index) {
		const DictRef object = gd::as_dict(state.at(source_objects, index));
		const Atom kind = text(state, object, key::kind);
		const Atom native_kind = text(state, object, key::native_record_kind);
		if (kind == key::town || native_kind == key::town) {
			continue;
		}
		if (kind == key::guard || native_kind == key::guard) {
			continue;
		}
		if (is_site_kind(kind) || is_site_kind(native_kind)) {
			continue;
		}
		const Atom family = gd::stringify(state, state.get(object, str(key::object_family_id), state.get(object, str(key::family_id), str(key::empty))));
		const bool scenery = native_scenery_rules::is_scenery(state, object);
		if (!scenery && kind != key::decorative_obstacle && family != key::decorative_obstacle && text(state, object, key::object_id) == key::empty) {
			continue;
		}
		const DictRef node = gd::deep_duplicate_dict(state, object);
		if (scenery || kind == key::decorative_obstacle || family == key::decorative_obstacle) {
			state.set(node, str(key::runtime_object_role), str(key::decorative_blocker_sprite));
			if (scenery) {
				state.set(node, str(key::native_scenery_art_version), int_value(kSceneryPresentationVersion));
			}
		}
		state.set(node, str(key::collected), bool_value(false));
		state.append(objects, dict_value(node));
	}
	return objects;
}

Atom _resource_site_id_for_object(State &state, DictRef object) {
	const Atom rare_mine_site_id = _live_rare_site_id_for_h3m_mine(state, object);
	if (rare_mine_site_id != key::empty) {
		return rare_mine_site_id;
	}
	const Atom site_id = stripped(state, object, key::site_id);
	if (site_id != key::empty) {
		return site_id;
	}
	const Atom object_id = stripped(state, object, key::object_id);
	if (object_id == key::empty) {
		return key::empty;
	}
	const DictRef map_object = gd::content_row(state, ContentTable::MapObject, object_id);
	return stripped(state, map_object, key::resource_site_id);
}

Atom _live_rare_site_id_for_h3m_mine(State &state, DictRef object) {
	const Atom kind = text(state, object, key::kind);
	const Atom native_kind = text(state, object, key::native_record_kind);
	if (kind != key::mine && native_kind != key::mine) {
		return key::empty;
	}
	const Atom object_id = stripped(state, object, key::object_id);
	if (object_id == key::object_marsh_peat_yard) {
		return key::site_peatwax_reed_yard;
	}
	if (object_id == key::object_floodplain_sluice_camp) {
		return key::site_embergrain_warm_granary;
	}
	if (object_id == key::object_cinder_ore_face) {
		return key::site_aetherglass_lens_house;
	}
	if (object_id == key::object_badlands_coin_sluice) {
		return key::site_memory_salt_pan;
	}
	return key::empty;
}

DictRef _runtime_scenario_record_from_documents(State &state, Atom scenario_id, const Value &map_document, const Value &scenario_document, DictRef overworld_state, Atom hero_id, DictRef start) {
	if (scenario_id == key::empty || map_document.kind == Kind::Nil || scenario_document.kind == Kind::Nil) {
		return state.new_dict();
	}
	const DictRef selection = gd::has_method(state, scenario_document, key::get_selection)
			? gd::as_dict(gd::call_method(state, scenario_document, key::get_selection, {}))
			: state.new_dict();
	const DictRef objectives = gd::has_method(state, scenario_document, key::get_objectives)
			? gd::as_dict(gd::call_method(state, scenario_document, key::get_objectives, {}))
			: state.new_dict();
	const DictRef start_contract = gd::has_method(state, scenario_document, key::get_start_contract)
			? gd::as_dict(gd::call_method(state, scenario_document, key::get_start_contract, {}))
			: state.new_dict();
	const DictRef record = state.new_dict();
	state.set(record, str(key::id), str(scenario_id));
	state.set(record, str(key::name), str(text_or(state, selection, key::name, str(scenario_id))));
	state.set(record, str(key::generated), bool_value(true));
	state.set(record, str(key::source), str(key::native_rmg_disk_package_runtime));
	state.set(record, str(key::selection), dict_value(selection));
	state.set(record, str(key::map_size), field_or_new_dict(state, overworld_state, key::map_size));
	state.set(record, str(key::map), field_or_new_array(state, overworld_state, key::map));
	state.set(record, str(key::player_faction_id), str(_player_faction_from_document(state, scenario_document, overworld_state)));
	state.set(record, str(key::starting_hero_id), str(hero_id));
	state.set(record, str(key::hero_id), str(text_or(state, start_contract, key::hero_id, str(hero_id))));
	state.set(record, str(key::player_army_id), str(text(state, start_contract, key::player_army_id)));
	state.set(record, str(key::starting_resources), field_or_new_dict(state, start_contract, key::starting_resources));
	state.set(record, str(key::hero_starts), field_or_new_array(state, start_contract, key::hero_starts));
	state.set(record, str(key::starting_position), dict_value(start));
	state.set(record, str(key::start), dict_value(gd::deep_duplicate_dict(state, start)));
	state.set(record, str(key::towns), field_or_new_array(state, overworld_state, key::towns));
	state.set(record, str(key::resource_nodes), field_or_new_array(state, overworld_state, key::resource_nodes));
	state.set(record, str(key::artifact_nodes), field_or_new_array(state, overworld_state, key::artifact_nodes));
	state.set(record, str(key::encounters), field_or_new_array(state, overworld_state, key::encounters));
	state.set(record, str(key::map_objects), field_or_new_array(state, overworld_state, key::map_objects));
	state.set(record, str(key::player_slots), gd::has_method(state, scenario_document, key::get_player_slots)
					? gd::call_method(state, scenario_document, key::get_player_slots, {})
					: array_value(state.new_array()));
	state.set(record, str(key::objectives), dict_value(objectives));
	state.set(record, str(key::script_hooks), gd::has_method(state, scenario_document, key::get_script_hooks)
					? gd::call_method(state, scenario_document, key::get_script_hooks, {})
					: array_value(state.new_array()));
	state.set(record, str(key::enemy_factions), array_value(player_identity_rules::enemy_configs(state, gd::as_array(field_or_new_array(state, overworld_state, key::players)))));
	const DictRef package = state.new_dict();
	state.set(package, str(key::schema_id), str(key::aurelion_native_rmg_disk_package_runtime_record_v1));
	state.set(package, str(key::map_ref), field_or_new_dict(state, overworld_state, key::map_package_ref));
	state.set(package, str(key::scenario_ref), field_or_new_dict(state, overworld_state, key::scenario_package_ref));
	state.set(record, str(key::native_generated_package), dict_value(package));
	return record;
}

Atom _player_faction_from_document(State &state, const Value &scenario_document, DictRef overworld_state) {
	if (scenario_document.kind != Kind::Nil && gd::has_method(state, scenario_document, key::get_start_contract)) {
		const DictRef start_contract = gd::as_dict(gd::call_method(state, scenario_document, key::get_start_contract, {}));
		const Value starts = array_or_nil(state, start_contract, key::player_starts);
		if (gd::is_array(starts)) {
			for (int64_t index = 0; index < state.array_size(starts.ref); ++index) {
				const Value start = state.at(starts.ref, index);
				if (gd::is_dict(start) && text(state, start.ref, key::owner) == key::player) {
					const Atom start_faction_id = text(state, start.ref, key::faction_id);
					if (!gd::is_empty(state, gd::content_row(state, ContentTable::Faction, start_faction_id))) {
						return start_faction_id;
					}
				}
			}
		}
	}
	const Value towns = array_or_nil(state, overworld_state, key::towns);
	if (gd::is_array(towns)) {
		for (int64_t index = 0; index < state.array_size(towns.ref); ++index) {
			const Value town = state.at(towns.ref, index);
			if (gd::is_dict(town) && text(state, town.ref, key::owner) == key::player) {
				return text(state, town.ref, key::faction_id);
			}
		}
	}
	return key::faction_embercourt;
}

} // namespace native_random_map_package_session_bridge

} // namespace aurelion::rules::port
