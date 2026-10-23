// ScenarioSelectRules' random-map setup options: sizes, water, levels, the
// template catalog, templates, profiles and player counts.

#include "aurelion_rules/port/scenario_select_rules_setup.hpp"

#include "aurelion_rules/port/ai_port.hpp"

#include <algorithm>
#include <cstddef>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace aurelion::rules::port::scenario_select_rules {

namespace {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

// RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS: water_modes is ["land"], or
// ["land", "islands"] where islands is set.
struct TemplateOptionRow {
	Atom id;
	Atom label;
	Atom profile_id;
	int64_t player_count;
	bool islands;
	bool supports_underground;
};
constexpr TemplateOptionRow kPlayerTemplateOptions[] = {
	{key::translated_rmg_template_049_v1, key::translated_small, key::translated_rmg_profile_049_v1, 3, false, false},
	{key::border_gate_compact_v1, key::border_gate_compact, key::border_gate_compact_profile_v1, 3, false, false},
	{key::frontier_spokes_v1, key::frontier_spokes, key::frontier_spokes_profile_v1, 3, false, false},
	{key::translated_rmg_template_001_v1, key::translated_islands, key::translated_rmg_profile_001_v1, 4, true, true},
	{key::translated_rmg_template_002_v1, key::translated_ring_mesh, key::translated_rmg_profile_002_v1, 4, false, true},
	{key::translated_rmg_template_042_v1, key::translated_large_mesh, key::translated_rmg_profile_042_v1, 4, false, true},
	{key::translated_rmg_template_043_v1, key::translated_extra_large_mesh, key::translated_rmg_profile_043_v1, 5, false, true},
};

// RANDOM_MAP_PLAYER_PROFILE_OPTIONS: faction_ids is embercourt, mireclaw and
// sunvault, then thornwake where it is set.
struct ProfileOptionRow {
	Atom id;
	Atom label;
	Atom template_id;
	Atom guard_strength_profile;
	bool thornwake;
};
constexpr ProfileOptionRow kPlayerProfileOptions[] = {
	{key::translated_rmg_profile_049_v1, key::translated_small, key::translated_rmg_template_049_v1, key::preserve_source_guard_values, false},
	{key::border_gate_compact_profile_v1, key::border_gate, key::border_gate_compact_v1, key::core_low, false},
	{key::frontier_spokes_profile_v1, key::frontier_spokes, key::frontier_spokes_v1, key::core_low, false},
	{key::translated_rmg_profile_001_v1, key::translated_parity, key::translated_rmg_template_001_v1, key::core_low, true},
	{key::translated_rmg_profile_002_v1, key::translated_ring_mesh, key::translated_rmg_template_002_v1, key::preserve_source_guard_values, true},
	{key::translated_rmg_profile_042_v1, key::translated_large_mesh, key::translated_rmg_template_042_v1, key::preserve_source_guard_values, true},
	{key::translated_rmg_profile_043_v1, key::translated_extra_large_mesh, key::translated_rmg_template_043_v1, key::preserve_source_guard_values, true},
};

// RANDOM_MAP_FALLBACK_PLAYER_COUNT_OPTIONS.
constexpr int64_t kFallbackPlayerCountOptions[] = {2, 3, 4};

// RANDOM_MAP_SIZE_CLASS_DEFAULTS, in its key order.
struct SizeClassDefaultRow {
	Atom size_class_id;
	Atom template_id;
	Atom profile_id;
	int64_t player_count;
};
constexpr SizeClassDefaultRow kSizeClassDefaults[] = {
	{key::homm3_small, key::translated_rmg_template_049_v1, key::translated_rmg_profile_049_v1, 3},
	{key::homm3_medium, key::translated_rmg_template_002_v1, key::translated_rmg_profile_002_v1, 4},
	{key::homm3_large, key::translated_rmg_template_042_v1, key::translated_rmg_profile_042_v1, 4},
	{key::homm3_extra_large, key::translated_rmg_template_043_v1, key::translated_rmg_profile_043_v1, 5},
};

// RANDOM_MAP_SIZE_OPTIONS: source_width and source_height are both size.
struct SizeOptionRow {
	Atom id;
	Atom label;
	int64_t size;
	Atom rationale;
};
constexpr SizeOptionRow kSizeOptions[] = {
	{key::homm3_small, key::small_36x36, 36, key::small_materializes_at_its_source_dimensions},
	{key::homm3_medium, key::medium_72x72, 72, key::medium_materializes_at_its_source_dimensions},
	{key::homm3_large, key::large_108x108, 108, key::large_materializes_at_its_source_dimensions},
	{key::homm3_extra_large, key::extra_large_144x144, 144, key::extra_large_materializes_at_its_source},
};

// RANDOM_MAP_WATER_OPTIONS and RANDOM_MAP_MONSTER_STRENGTH_OPTIONS.
struct LabelRow {
	Atom id;
	Atom label;
};
constexpr LabelRow kWaterOptions[] = {
	{key::land, key::Land},
	{key::normal_water, key::normal_water_2},
	{key::islands, key::Islands},
};
constexpr LabelRow kMonsterStrengthOptions[] = {
	{key::weak, key::weak_monsters},
	{key::normal, key::normal_monsters},
	{key::strong, key::strong_monsters},
};

// RANDOM_MAP_LEVEL_OPTIONS.
struct LevelOptionRow {
	Atom id;
	Atom label;
	int64_t level_count;
	bool underground;
};
constexpr LevelOptionRow kLevelOptions[] = {
	{key::surface, key::surface_only_1_level, 1, false},
	{key::surface_underground, key::surface_underground_2_levels, 2, true},
};

// RANDOM_MAP_PUBLIC_H3MAPED_SCOPES.
struct ScopeRow {
	Atom size_class_id;
	Atom scope_size_id;
	Atom dimensions;
};
constexpr ScopeRow kPublicScopes[] = {
	{key::homm3_small, key::small, key::n36x36},
	{key::homm3_medium, key::medium, key::n72x72},
	{key::homm3_large, key::large, key::n108x108},
	{key::homm3_extra_large, key::extra_large, key::n144x144},
};

// RANDOM_MAP_PUBLIC_H3MAPED_SCOPE's size_class_ids, water_modes, level_counts,
// workflow_count and scope.
constexpr Atom kPublicSizeClassIds[] = {key::homm3_small, key::homm3_medium, key::homm3_large, key::homm3_extra_large};
constexpr Atom kPublicWaterModes[] = {key::land, key::normal_water, key::islands};
constexpr int64_t kPublicLevelCounts[] = {1, 2};
constexpr int64_t kPublicWorkflowCount = 24;
constexpr Atom kPublicScope = key::native_rmg_parity_owned_24_workflow_release_matrix;

template <size_t N>
bool atoms_have(const Atom (&atoms)[N], Atom atom) {
	return std::find(std::begin(atoms), std::end(atoms), atom) != std::end(atoms);
}

template <size_t N>
ArrayRef atom_array(State &state, const Atom (&atoms)[N]) {
	const ArrayRef result = state.new_array();
	for (const Atom atom : atoms) {
		state.append(result, str(atom));
	}
	return result;
}

template <size_t N>
ArrayRef int_array(State &state, const int64_t (&values)[N]) {
	const ArrayRef result = state.new_array();
	for (const int64_t value : values) {
		state.append(result, int_value(value));
	}
	return result;
}

// RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS[i].duplicate(true).
DictRef template_option_dict(State &state, const TemplateOptionRow &row) {
	const DictRef option = state.new_dict();
	state.set(option, str(key::id), str(row.id));
	state.set(option, str(key::label), str(row.label));
	state.set(option, str(key::profile_id), str(row.profile_id));
	state.set(option, str(key::player_count), int_value(row.player_count));
	const ArrayRef water_modes = state.new_array();
	state.append(water_modes, str(key::land));
	if (row.islands) {
		state.append(water_modes, str(key::islands));
	}
	state.set(option, str(key::water_modes), array_value(water_modes));
	state.set(option, str(key::supports_underground), bool_value(row.supports_underground));
	return option;
}

// RANDOM_MAP_PLAYER_PROFILE_OPTIONS[i].duplicate(true).
DictRef profile_option_dict(State &state, const ProfileOptionRow &row) {
	const DictRef option = state.new_dict();
	state.set(option, str(key::id), str(row.id));
	state.set(option, str(key::label), str(row.label));
	state.set(option, str(key::template_id), str(row.template_id));
	state.set(option, str(key::guard_strength_profile), str(row.guard_strength_profile));
	const ArrayRef faction_ids = state.new_array();
	state.append(faction_ids, str(key::faction_embercourt));
	state.append(faction_ids, str(key::faction_mireclaw));
	state.append(faction_ids, str(key::faction_sunvault));
	if (row.thornwake) {
		state.append(faction_ids, str(key::faction_thornwake));
	}
	state.set(option, str(key::faction_ids), array_value(faction_ids));
	return option;
}

// RANDOM_MAP_PLAYER_TEMPLATE_OPTIONS.duplicate(true).
ArrayRef player_template_options(State &state) {
	const ArrayRef result = state.new_array();
	for (const TemplateOptionRow &row : kPlayerTemplateOptions) {
		state.append(result, dict_value(template_option_dict(state, row)));
	}
	return result;
}

// RANDOM_MAP_PLAYER_PROFILE_OPTIONS.duplicate(true).
ArrayRef player_profile_options(State &state) {
	const ArrayRef result = state.new_array();
	for (const ProfileOptionRow &row : kPlayerProfileOptions) {
		state.append(result, dict_value(profile_option_dict(state, row)));
	}
	return result;
}

// RANDOM_MAP_SIZE_OPTIONS[i].duplicate(true).
DictRef size_option_dict(State &state, const SizeOptionRow &row) {
	const DictRef option = state.new_dict();
	state.set(option, str(key::id), str(row.id));
	state.set(option, str(key::label), str(row.label));
	state.set(option, str(key::source_model), str(key::homm3_classic_size_class));
	state.set(option, str(key::source_width), int_value(row.size));
	state.set(option, str(key::source_height), int_value(row.size));
	state.set(option, str(key::materialization_available), bool_value(true));
	state.set(option, str(key::runtime_policy), str(key::materialize_at_source_size_within_current_144x144x2_cap));
	state.set(option, str(key::rationale), str(row.rationale));
	return option;
}

// {"id": ..., "label": ...}.duplicate(true).
DictRef label_dict(State &state, const LabelRow &row) {
	const DictRef option = state.new_dict();
	state.set(option, str(key::id), str(row.id));
	state.set(option, str(key::label), str(row.label));
	return option;
}

// RANDOM_MAP_LEVEL_OPTIONS[i].duplicate(true).
DictRef level_option_dict(State &state, const LevelOptionRow &row) {
	const DictRef option = state.new_dict();
	state.set(option, str(key::id), str(row.id));
	state.set(option, str(key::label), str(row.label));
	state.set(option, str(key::level_count), int_value(row.level_count));
	state.set(option, str(key::underground), bool_value(row.underground));
	return option;
}

// RANDOM_MAP_PUBLIC_H3MAPED_SCOPES[i].duplicate(true).
DictRef scope_dict(State &state, const ScopeRow &row) {
	const DictRef scope = state.new_dict();
	state.set(scope, str(key::size_class_id), str(row.size_class_id));
	state.set(scope, str(key::scope_size_id), str(row.scope_size_id));
	state.set(scope, str(key::dimensions), str(row.dimensions));
	return scope;
}

// RANDOM_MAP_PUBLIC_H3MAPED_SCOPE.duplicate(true).
DictRef public_scope_dict(State &state) {
	const DictRef scope = state.new_dict();
	state.set(scope, str(key::size_class_ids), array_value(atom_array(state, kPublicSizeClassIds)));
	state.set(scope, str(key::water_modes), array_value(atom_array(state, kPublicWaterModes)));
	state.set(scope, str(key::level_counts), array_value(int_array(state, kPublicLevelCounts)));
	state.set(scope, str(key::workflow_count), int_value(kPublicWorkflowCount));
	state.set(scope, str(key::scope), str(kPublicScope));
	const ArrayRef scopes = state.new_array();
	for (const ScopeRow &row : kPublicScopes) {
		state.append(scopes, dict_value(scope_dict(state, row)));
	}
	state.set(scope, str(key::scopes), array_value(scopes));
	return scope;
}

// RANDOM_MAP_SIZE_CLASS_DEFAULTS.duplicate(true).
DictRef size_class_defaults_dict(State &state) {
	const DictRef result = state.new_dict();
	for (const SizeClassDefaultRow &row : kSizeClassDefaults) {
		const DictRef defaults = state.new_dict();
		state.set(defaults, str(key::template_id), str(row.template_id));
		state.set(defaults, str(key::profile_id), str(row.profile_id));
		state.set(defaults, str(key::player_count), int_value(row.player_count));
		state.set(result, str(row.size_class_id), dict_value(defaults));
	}
	return result;
}

// RANDOM_MAP_MONSTER_STRENGTH_OPTIONS.duplicate(true).
ArrayRef monster_strength_options(State &state) {
	const ArrayRef result = state.new_array();
	for (const LabelRow &row : kMonsterStrengthOptions) {
		state.append(result, dict_value(label_dict(state, row)));
	}
	return result;
}

// RANDOM_MAP_PLAYER_RETRY_POLICY.duplicate(true).
DictRef retry_policy_dict(State &state) {
	const DictRef policy = state.new_dict();
	state.set(policy, str(key::max_attempts), int_value(5));
	state.set(policy, str(key::mode), str(key::seed_salt));
	return policy;
}

// String(d.get(key, fallback)).
Atom string_of(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(key, {}) if d.get(key, {}) is Dictionary else {}, where the result is
// only read: the field when it is a Dictionary, else Nil for the empty one.
Value dict_field_or_nil(const State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found;
	}
	return Value();
}

// d.get(key, fallback) of a Dictionary dict_field_or_nil gave.
Value read_field(const State &state, const Value &dict, Atom field, const Value &fallback) {
	return gd::is_dict(dict) ? state.get(dict.ref, str(field), fallback) : fallback;
}

// d.get(key, {}) or d.get(key, []) where the result is stored: a new one when
// the key is missing.
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

// x.duplicate(true) of an untyped value: an Array's or a Dictionary's.
Value deep_duplicate_of(State &state, const Value &value) {
	if (!gd::is_array(value) && !gd::is_dict(value)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'duplicate' in base '") + gd::type_name(value) + "'.");
	}
	return gd::duplicate_value(state, value, true);
}

// What _random_map_template_player_count_options and
// _player_counts_from_catalog_template both do with a catalog template.
ArrayRef catalog_template_player_counts(State &state, DictRef template_, int64_t fallback_count) {
	const Value players = dict_field_or_nil(state, template_, key::players);
	const Value total = gd::is_dict(players) ? dict_field_or_nil(state, players.ref, key::total) : Value();
	int64_t min_count = compat::engine_clamp<int64_t>(gd::to_int(state, read_field(state, total, key::min_, int_value(fallback_count))), 2, 8);
	int64_t max_count = compat::engine_clamp<int64_t>(gd::to_int(state, read_field(state, total, key::max, int_value(fallback_count))), min_count, 8);
	const int64_t capacity = _random_map_template_total_start_capacity(state, template_);
	if (capacity > 0) {
		max_count = compat::engine_min<int64_t>(max_count, capacity);
	}
	if (min_count > max_count) {
		min_count = max_count;
	}
	const ArrayRef counts = state.new_array();
	for (int64_t count = min_count; count < max_count + 1; ++count) {
		if (_random_map_template_active_graph_connected(state, template_, count)) {
			state.append(counts, int_value(count));
		}
	}
	return counts;
}

// player_counts[0] / player_counts[size - 1] if not empty, else
// int(option.get("player_count", 3)).
int64_t player_count_bound(State &state, ArrayRef player_counts, DictRef option, bool last) {
	const int64_t size = state.array_size(player_counts);
	if (size == 0) {
		return gd::int_field(state, option, key::player_count, 3);
	}
	return gd::to_int(state, state.at(player_counts, last ? size - 1 : 0));
}

} // namespace

DictRef random_map_player_setup_options(State &state) {
	const ArrayRef template_options = _random_map_player_facing_template_options_with_player_counts(state);
	const ArrayRef profile_options = _random_map_player_facing_profile_options(state);
	const ArrayRef faction_options = random_map_faction_options(state);
	const Atom default_faction_id = key::faction_embercourt;
	const Atom default_hero_id = random_map_default_hero_id_for_faction(state, default_faction_id);
	const DictRef result = state.new_dict();
	state.set(result, str(key::templates), array_value(template_options));
	state.set(result, str(key::profiles), array_value(profile_options));
	state.set(result, str(key::size_classes), array_value(_random_map_public_size_options(state)));
	state.set(result, str(key::player_counts), array_value(_random_map_all_player_count_options(state, template_options)));
	state.set(result, str(key::player_count_options_by_template), dict_value(_random_map_player_count_options_by_template(state, template_options)));
	state.set(result, str(key::profile_options_by_template), dict_value(_random_map_profile_options_by_template(state, profile_options)));
	state.set(result, str(key::water_modes), array_value(_random_map_public_water_options(state)));
	state.set(result, str(key::level_options), array_value(_random_map_public_level_options(state)));
	state.set(result, str(key::monster_strengths), array_value(monster_strength_options(state)));
	state.set(result, str(key::factions), array_value(faction_options));
	state.set(result, str(key::default_faction_id), str(default_faction_id));
	state.set(result, str(key::default_hero_id), str(default_hero_id));
	state.set(result, str(key::retry_policy), dict_value(retry_policy_dict(state)));
	state.set(result, str(key::default_seed), str(key::aurelion_random_skirmish_10184));
	state.set(result, str(key::default_size_class_id), str(key::homm3_small));
	state.set(result, str(key::default_template_id), str(key::translated_rmg_template_049_v1));
	state.set(result, str(key::default_profile_id), str(key::translated_rmg_profile_049_v1));
	state.set(result, str(key::size_class_defaults), dict_value(size_class_defaults_dict(state)));
	state.set(result, str(key::default_player_count), int_value(_random_map_normalize_player_count_for_template(state, key::translated_rmg_template_049_v1, 3, 3)));
	state.set(result, str(key::default_water_mode), str(key::land));
	state.set(result, str(key::default_monster_strength), str(key::normal));
	state.set(result, str(key::default_level_count), int_value(1));
	state.set(result, str(key::default_underground), bool_value(false));
	state.set(result, str(key::public_generation_scope), dict_value(public_scope_dict(state)));
	state.set(result, str(key::package_directory_policy), dict_value(generated_map_package_directory_policy(state)));
	state.set(result, str(key::catalog_template_count), int_value(state.array_size(_random_map_template_options(state))));
	state.set(result, str(key::catalog_profile_count), int_value(state.array_size(_random_map_profile_options(state))));
	state.set(result, str(key::player_facing_template_policy), str(key::h3maped_native_24_workflow_release_matrix));
	const DictRef auto_selection = state.new_dict();
	state.set(auto_selection, str(key::mode), str(key::native_catalog_auto));
	state.set(auto_selection, str(key::manual_template_picker_visible), bool_value(false));
	state.set(auto_selection, str(key::manual_profile_picker_visible), bool_value(false));
	state.set(auto_selection, str(key::catalog_template_count), int_value(state.array_size(_random_map_template_options(state))));
	state.set(auto_selection, str(key::catalog_profile_count), int_value(state.array_size(_random_map_profile_options(state))));
	state.set(auto_selection, str(key::launch_filter), str(key::public_generated_skirmish_startup_is_validator));
	state.set(result, str(key::player_facing_auto_selection), dict_value(auto_selection));
	return result;
}

ArrayRef _random_map_public_size_options(State &state) {
	const ArrayRef options = state.new_array();
	const ArrayRef public_size_ids = _random_map_public_h3maped_size_ids(state);
	for (const SizeOptionRow &row : kSizeOptions) {
		if (gd::array_has(state, public_size_ids, str(row.id))) {
			const DictRef item = size_option_dict(state, row);
			state.set(item, str(key::public_generation_scope), str(_random_map_public_h3maped_scope_label_for_size(state, row.id)));
			state.append(options, dict_value(item));
		}
	}
	return options;
}

ArrayRef _random_map_public_water_options(State &state) {
	const ArrayRef options = state.new_array();
	for (const LabelRow &row : kWaterOptions) {
		if (atoms_have(kPublicWaterModes, row.id)) {
			const DictRef item = label_dict(state, row);
			state.set(item, str(key::public_generation_scope), str(kPublicScope));
			state.append(options, dict_value(item));
		}
	}
	return options;
}

ArrayRef _random_map_public_level_options(State &state) {
	const ArrayRef options = state.new_array();
	for (const LevelOptionRow &row : kLevelOptions) {
		if (std::find(std::begin(kPublicLevelCounts), std::end(kPublicLevelCounts), row.level_count) != std::end(kPublicLevelCounts)) {
			const DictRef item = level_option_dict(state, row);
			state.set(item, str(key::public_generation_scope), str(kPublicScope));
			state.append(options, dict_value(item));
		}
	}
	return options;
}

ArrayRef _random_map_public_h3maped_size_ids(State &state) {
	return atom_array(state, kPublicSizeClassIds);
}

Atom _random_map_public_h3maped_scope_label_for_size(State &state, Atom size_class_id) {
	for (const ScopeRow &scope : kPublicScopes) {
		if (scope.size_class_id == size_class_id) {
			return gd::format(state, key::native_rmg_parity_owned_s_release, {str(scope.dimensions)});
		}
	}
	return key::empty;
}

DictRef _random_map_public_h3maped_scope_for(State &state, Atom size_class_id, Atom water_mode, int64_t level_count) {
	if (!atoms_have(kPublicSizeClassIds, size_class_id)) {
		return state.new_dict();
	}
	if (!atoms_have(kPublicWaterModes, water_mode)) {
		return state.new_dict();
	}
	if (std::find(std::begin(kPublicLevelCounts), std::end(kPublicLevelCounts), level_count) == std::end(kPublicLevelCounts)) {
		return state.new_dict();
	}
	for (const ScopeRow &scope : kPublicScopes) {
		if (scope.size_class_id != size_class_id) {
			continue;
		}
		const DictRef resolved = scope_dict(state, scope);
		state.set(resolved, str(key::water_mode), str(water_mode));
		state.set(resolved, str(key::level_count), int_value(level_count));
		const Atom level_label = level_count == 2 ? key::two_level : key::one_level;
		const Atom land_suffix = level_count == 1 && water_mode == key::land ? key::land_only : water_mode;
		state.set(resolved, str(key::scope), str(gd::format(state, key::strict_s_s_s_s, {str(scope.scope_size_id), str(scope.dimensions), str(level_label), str(land_suffix)})));
		return resolved;
	}
	return state.new_dict();
}

ArrayRef random_map_player_count_options_for_template(State &state, Atom template_id) {
	return _random_map_template_player_count_options(state, template_id, _random_map_template_option(state, template_id));
}

ArrayRef random_map_profile_options_for_template(State &state, Atom template_id) {
	ArrayRef options = state.new_array();
	const ArrayRef profile_options = _random_map_profile_options(state);
	for (const Value &option : gd::items(state, array_value(profile_options))) {
		if (gd::is_dict(option) && string_of(state, option.ref, key::template_id, key::empty) == template_id) {
			state.append(options, deep_duplicate_of(state, option));
		}
	}
	if (state.array_size(options) == 0) {
		options = _random_map_profile_options(state);
	}
	return options;
}

DictRef _random_map_template_option(State &state, Atom template_id) {
	const ArrayRef options = _random_map_template_options(state);
	for (const Value &option : gd::items(state, array_value(options))) {
		if (gd::stringify(state, ai::vget(state, option, key::id, str(key::empty))) == template_id) {
			return gd::as_dict(deep_duplicate_of(state, option));
		}
	}
	for (const Value &option : gd::items(state, array_value(options))) {
		if (gd::stringify(state, ai::vget(state, option, key::id, str(key::empty))) == key::translated_rmg_template_049_v1) {
			return gd::as_dict(deep_duplicate_of(state, option));
		}
	}
	if (state.array_size(options) != 0) {
		return gd::as_dict(deep_duplicate_of(state, state.at(options, 0)));
	}
	return template_option_dict(state, kPlayerTemplateOptions[0]);
}

ArrayRef _random_map_player_facing_template_options_with_player_counts(State &state) {
	const DictRef allowed_ids = _random_map_size_default_template_ids(state);
	const ArrayRef options = state.new_array();
	const ArrayRef raw_options = _random_map_template_options(state);
	for (const Value &raw_option : gd::items(state, array_value(raw_options))) {
		if (!gd::is_dict(raw_option)) {
			continue;
		}
		if (!state.has(allowed_ids, str(string_of(state, raw_option.ref, key::id, key::empty)))) {
			continue;
		}
		const DictRef option = gd::deep_duplicate_dict(state, raw_option.ref);
		const ArrayRef player_counts = _random_map_template_player_count_options(state, string_of(state, option, key::id, key::empty), option);
		state.set(option, str(key::player_counts), array_value(player_counts));
		state.set(option, str(key::player_count_min), int_value(player_count_bound(state, player_counts, option, false)));
		state.set(option, str(key::player_count_max), int_value(player_count_bound(state, player_counts, option, true)));
		state.set(option, str(key::player_facing_policy), str(key::size_default_owner_compared_not_full_parity));
		state.append(options, dict_value(option));
	}
	return options;
}

ArrayRef _random_map_player_facing_profile_options(State &state) {
	const DictRef allowed_ids = _random_map_size_default_profile_ids(state);
	const ArrayRef options = state.new_array();
	const ArrayRef profile_options = _random_map_profile_options(state);
	for (const Value &option : gd::items(state, array_value(profile_options))) {
		if (gd::is_dict(option) && state.has(allowed_ids, str(string_of(state, option.ref, key::id, key::empty)))) {
			const DictRef item = gd::deep_duplicate_dict(state, option.ref);
			state.set(item, str(key::player_facing_policy), str(key::size_default_owner_compared_not_full_parity));
			state.append(options, dict_value(item));
		}
	}
	return options;
}

DictRef _random_map_size_default_template_ids(State &state) {
	const DictRef result = state.new_dict();
	for (const SizeClassDefaultRow &row : kSizeClassDefaults) {
		state.set(result, str(row.template_id), bool_value(true));
	}
	return result;
}

DictRef _random_map_size_default_profile_ids(State &state) {
	const DictRef result = state.new_dict();
	for (const SizeClassDefaultRow &row : kSizeClassDefaults) {
		state.set(result, str(row.profile_id), bool_value(true));
	}
	return result;
}

ArrayRef _random_map_all_player_count_options(State &state, ArrayRef template_options) {
	const DictRef counts = state.new_dict();
	for (const Value &option : gd::items(state, array_value(template_options))) {
		if (!gd::is_dict(option)) {
			continue;
		}
		for (const Value &count : gd::field_items(state, option.ref, str(key::player_counts))) {
			state.set(counts, str(gd::stringify(state, int_value(gd::to_int(state, count)))), bool_value(true));
		}
	}
	if (gd::is_empty(state, counts)) {
		for (const int64_t fallback_count : kFallbackPlayerCountOptions) {
			state.set(counts, str(gd::stringify(state, int_value(fallback_count))), bool_value(true));
		}
	}
	return _sorted_int_keys(state, counts);
}

DictRef _random_map_player_count_options_by_template(State &state, ArrayRef template_options) {
	const DictRef result = state.new_dict();
	for (const Value &option : gd::items(state, array_value(template_options))) {
		if (!gd::is_dict(option)) {
			continue;
		}
		const Atom id = string_of(state, option.ref, key::id, key::empty);
		state.set(result, str(id), deep_duplicate_of(state, field_or_new_array(state, option.ref, key::player_counts)));
	}
	return result;
}

DictRef _random_map_profile_options_by_template(State &state, ArrayRef profile_options) {
	const DictRef result = state.new_dict();
	for (const Value &option : gd::items(state, array_value(profile_options))) {
		if (!gd::is_dict(option)) {
			continue;
		}
		const Atom template_id = string_of(state, option.ref, key::template_id, key::empty);
		if (template_id == key::empty) {
			continue;
		}
		if (!state.has(result, str(template_id))) {
			state.set(result, str(template_id), array_value(state.new_array()));
		}
		const ArrayRef list = gd::as_array(gd::index(state, result, str(template_id)));
		state.append(list, deep_duplicate_of(state, option));
	}
	return result;
}

ArrayRef _random_map_template_player_count_options(State &state, Atom template_id, DictRef fallback_option) {
	const int64_t fallback_count = gd::int_field(state, fallback_option, key::player_count, 3);
	const DictRef template_ = _random_map_catalog_template(state, template_id);
	if (gd::is_empty(state, template_)) {
		if (fallback_count > 0) {
			const ArrayRef result = state.new_array();
			state.append(result, int_value(fallback_count));
			return result;
		}
		return int_array(state, kFallbackPlayerCountOptions);
	}
	return catalog_template_player_counts(state, template_, fallback_count);
}

int64_t _random_map_normalize_player_count_for_template(State &state, Atom template_id, int64_t player_count, int64_t fallback_count) {
	const DictRef fallback_option = _random_map_template_option(state, template_id);
	if (fallback_count > 0) {
		state.set(fallback_option, str(key::player_count), int_value(fallback_count));
	}
	const ArrayRef counts = _random_map_template_player_count_options(state, template_id, fallback_option);
	if (state.array_size(counts) == 0) {
		return compat::engine_clamp<int64_t>(player_count > 0 ? player_count : fallback_count, 2, 8);
	}
	const int64_t requested = player_count > 0 ? player_count : fallback_count;
	const int64_t first_count = gd::to_int(state, state.at(counts, 0));
	const int64_t last_count = gd::to_int(state, state.at(counts, state.array_size(counts) - 1));
	return compat::engine_clamp<int64_t>(requested, first_count, last_count);
}

DictRef _random_map_catalog_template(State &state, Atom template_id) {
	const DictRef catalog = _random_map_catalog(state);
	for (const Value &template_value : gd::field_items(state, catalog, str(key::templates))) {
		if (gd::is_dict(template_value) && string_of(state, template_value.ref, key::id, key::empty) == template_id) {
			return gd::deep_duplicate_dict(state, template_value.ref);
		}
	}
	return state.new_dict();
}

DictRef _random_map_catalog(State &state) {
	// RandomMapGeneratorRules.TEMPLATE_CATALOG_PATH; load_json answers a Dictionary.
	return gd::content_file(state, key::random_map_template_catalog_path);
}

ArrayRef _random_map_template_options(State &state) {
	const DictRef catalog = _random_map_catalog(state);
	const DictRef profiles_by_template = state.new_dict();
	for (const Value &profile : gd::field_items(state, catalog, str(key::profiles))) {
		if (gd::is_dict(profile)) {
			state.set(profiles_by_template, str(string_of(state, profile.ref, key::template_id, key::empty)), profile);
		}
	}
	const ArrayRef options = state.new_array();
	for (const Value &template_value : gd::field_items(state, catalog, str(key::templates))) {
		if (!gd::is_dict(template_value)) {
			continue;
		}
		const DictRef template_ = template_value.ref;
		const Atom template_id = string_of(state, template_, key::id, key::empty);
		if (template_id == key::empty) {
			continue;
		}
		const Value profile = dict_field_or_nil(state, profiles_by_template, template_id);
		const ArrayRef player_counts = _player_counts_from_catalog_template(state, template_, 3);
		const Atom label = string_of(state, template_, key::label, template_id);
		const Atom profile_id = gd::stringify(state, read_field(state, profile, key::id, str(key::empty)));
		const int64_t count_size = state.array_size(player_counts);
		const int64_t player_count = count_size != 0 ? gd::to_int(state, state.at(player_counts, compat::engine_min<int64_t>(count_size - 1, 2))) : 3;
		const ArrayRef water_modes = _water_modes_from_catalog_template(state, template_);
		const bool supports_underground = _template_supports_underground(state, template_);
		const Atom family = string_of(state, template_, key::family, key::empty);
		const Value size_score = field_or_new_dict(state, template_, key::size_score);
		const DictRef option = state.new_dict();
		state.set(option, str(key::id), str(template_id));
		state.set(option, str(key::label), str(label));
		state.set(option, str(key::profile_id), str(profile_id));
		state.set(option, str(key::player_count), int_value(player_count));
		state.set(option, str(key::water_modes), array_value(water_modes));
		state.set(option, str(key::supports_underground), bool_value(supports_underground));
		state.set(option, str(key::catalog_source), str(key::content_random_map_template_catalog_json));
		state.set(option, str(key::family), str(family));
		state.set(option, str(key::size_score), size_score);
		state.append(options, dict_value(option));
	}
	if (state.array_size(options) != 0) {
		return options;
	}
	return player_template_options(state);
}

ArrayRef _random_map_profile_options(State &state) {
	const DictRef catalog = _random_map_catalog(state);
	const ArrayRef options = state.new_array();
	for (const Value &profile_value : gd::field_items(state, catalog, str(key::profiles))) {
		if (!gd::is_dict(profile_value)) {
			continue;
		}
		const DictRef profile = profile_value.ref;
		const Atom profile_id = string_of(state, profile, key::id, key::empty);
		if (profile_id == key::empty) {
			continue;
		}
		const Atom label = string_of(state, profile, key::label, profile_id);
		const Atom template_id = string_of(state, profile, key::template_id, key::empty);
		const Atom guard_strength_profile = string_of(state, profile, key::guard_strength_profile, key::core_low);
		const Value terrain_ids = field_or_new_array(state, profile, key::terrain_ids);
		const Value faction_ids = field_or_new_array(state, profile, key::faction_ids);
		const Atom encounter_id = string_of(state, profile, key::encounter_id, key::empty);
		const DictRef option = state.new_dict();
		state.set(option, str(key::id), str(profile_id));
		state.set(option, str(key::label), str(label));
		state.set(option, str(key::template_id), str(template_id));
		state.set(option, str(key::guard_strength_profile), str(guard_strength_profile));
		state.set(option, str(key::terrain_ids), terrain_ids);
		state.set(option, str(key::faction_ids), faction_ids);
		state.set(option, str(key::encounter_id), str(encounter_id));
		state.set(option, str(key::catalog_source), str(key::content_random_map_template_catalog_json));
		state.append(options, dict_value(option));
	}
	if (state.array_size(options) != 0) {
		return options;
	}
	return player_profile_options(state);
}

ArrayRef _player_counts_from_catalog_template(State &state, DictRef template_, int64_t fallback_count) {
	return catalog_template_player_counts(state, template_, fallback_count);
}

bool _random_map_template_active_graph_connected(State &state, DictRef template_, int64_t player_count) {
	// active_zone_ids in insertion order, each with its adjacency list in
	// append order; the walk only counts what it reaches.
	std::vector<Atom> active_zone_ids;
	std::unordered_map<Atom, std::vector<Atom>> adjacency;
	for (const Value &zone : gd::field_items(state, template_, str(key::zones))) {
		if (gd::is_dict(zone) && _template_player_filter_allows(state, zone.ref, player_count)) {
			const Atom zone_id = string_of(state, zone.ref, key::id, key::empty);
			if (zone_id != key::empty && adjacency.find(zone_id) == adjacency.end()) {
				active_zone_ids.push_back(zone_id);
				adjacency[zone_id];
			}
		}
	}
	if (active_zone_ids.empty()) {
		return false;
	}
	for (const Value &link : gd::field_items(state, template_, str(key::links))) {
		if (!gd::is_dict(link) || !_template_player_filter_allows(state, link.ref, player_count)) {
			continue;
		}
		const Atom from_zone = string_of(state, link.ref, key::from, key::empty);
		const Atom to_zone = string_of(state, link.ref, key::to, key::empty);
		const auto from_found = adjacency.find(from_zone);
		const auto to_found = adjacency.find(to_zone);
		if (from_found == adjacency.end() || to_found == adjacency.end()) {
			continue;
		}
		std::vector<Atom> &from_links = from_found->second;
		if (std::find(from_links.begin(), from_links.end(), to_zone) == from_links.end()) {
			from_links.push_back(to_zone);
		}
		std::vector<Atom> &to_links = to_found->second;
		if (std::find(to_links.begin(), to_links.end(), from_zone) == to_links.end()) {
			to_links.push_back(from_zone);
		}
	}
	const Atom start_zone = active_zone_ids[0];
	std::unordered_set<Atom> visited{start_zone};
	std::vector<Atom> queue{start_zone};
	size_t cursor = 0;
	while (cursor < queue.size()) {
		const Atom current = queue[cursor];
		cursor += 1;
		const auto found = adjacency.find(current);
		if (found == adjacency.end()) {
			continue;
		}
		for (const Atom next : found->second) {
			if (visited.insert(next).second) {
				queue.push_back(next);
			}
		}
	}
	return visited.size() == active_zone_ids.size();
}

bool _template_player_filter_allows(State &state, DictRef record, int64_t player_count) {
	const Value player_filter = dict_field_or_nil(state, record, key::player_filter);
	if (!gd::is_dict(player_filter) || gd::is_empty(state, player_filter.ref)) {
		return true;
	}
	const int64_t min_total = gd::int_field(state, player_filter.ref, key::min_total, 1);
	const int64_t max_total = gd::int_field(state, player_filter.ref, key::max_total, 8);
	return player_count >= min_total && player_count <= max_total;
}

ArrayRef _water_modes_from_catalog_template(State &state, DictRef template_) {
	const DictRef result = state.new_dict();
	const auto add_mode = [&](Atom mode) {
		if (mode == key::land) {
			state.set(result, str(key::land), bool_value(true));
		} else if (mode == key::normal_water) {
			state.set(result, str(key::normal_water), bool_value(true));
		} else if (state.text(mode).find("islands") != std::string::npos) {
			state.set(result, str(key::islands), bool_value(true));
			state.set(result, str(key::normal_water), bool_value(true));
		}
	};
	const Value support = dict_field_or_nil(state, template_, key::map_support);
	Value water_modes;
	if (gd::is_dict(support) && state.lookup(support.ref, str(key::water_modes), water_modes)) {
		for (const Value &mode_value : gd::items(state, water_modes)) {
			add_mode(gd::stringify(state, mode_value));
		}
	} else {
		// The default ["land"].
		add_mode(key::land);
	}
	if (gd::is_empty(state, result)) {
		state.set(result, str(key::land), bool_value(true));
	}
	return _sorted_string_keys(state, result);
}

bool _template_supports_underground(State &state, DictRef template_) {
	const Value support = dict_field_or_nil(state, template_, key::map_support);
	const Value levels = gd::is_dict(support) ? dict_field_or_nil(state, support.ref, key::levels) : Value();
	if (!gd::is_dict(levels)) {
		return false;
	}
	for (const Value &count : gd::field_items(state, levels.ref, str(key::supported_counts))) {
		if (gd::to_int(state, count) >= 2) {
			return true;
		}
	}
	return false;
}

int64_t _random_map_template_total_start_capacity(State &state, DictRef template_) {
	// owner_slots' keys are str(slot): one per distinct slot.
	std::vector<int64_t> owner_slots;
	for (const Value &zone : gd::field_items(state, template_, str(key::zones))) {
		if (!gd::is_dict(zone) || state.get(zone.ref, str(key::owner_slot), Value()).kind == Kind::Nil) {
			continue;
		}
		const int64_t slot = gd::int_field(state, zone.ref, key::owner_slot, 0);
		const Atom role = string_of(state, zone.ref, key::role, key::empty);
		if (slot > 0 && (role == key::human_start || role == key::computer_start || gd::ends_with(state, role, key::_start))) {
			if (std::find(owner_slots.begin(), owner_slots.end(), slot) == owner_slots.end()) {
				owner_slots.push_back(slot);
			}
		}
	}
	return static_cast<int64_t>(owner_slots.size());
}

ArrayRef _sorted_int_keys(State &state, DictRef values) {
	const ArrayRef result = state.new_array();
	for (const Value &item : gd::items(state, dict_value(values))) {
		state.append(result, int_value(gd::to_int(state, item)));
	}
	gd::sort_custom(state, result, [](const Value &a, const Value &b) { return gd::op_less(a, b); });
	return result;
}

ArrayRef _sorted_string_keys(State &state, DictRef values) {
	const ArrayRef result = state.new_array();
	for (const Value &item : gd::items(state, dict_value(values))) {
		state.append(result, str(gd::stringify(state, item)));
	}
	gd::sort_custom(state, result, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	return result;
}

DictRef _random_map_size_option(State &state, Atom size_class_id) {
	for (const SizeOptionRow &row : kSizeOptions) {
		if (row.id == size_class_id) {
			return size_option_dict(state, row);
		}
	}
	return size_option_dict(state, kSizeOptions[0]);
}

DictRef _random_map_profile_option(State &state, Atom profile_id) {
	const ArrayRef options = _random_map_profile_options(state);
	for (const Value &option : gd::items(state, array_value(options))) {
		if (gd::stringify(state, ai::vget(state, option, key::id, str(key::empty))) == profile_id) {
			return gd::as_dict(deep_duplicate_of(state, option));
		}
	}
	for (const Value &option : gd::items(state, array_value(options))) {
		if (gd::stringify(state, ai::vget(state, option, key::id, str(key::empty))) == key::translated_rmg_profile_049_v1) {
			return gd::as_dict(deep_duplicate_of(state, option));
		}
	}
	if (state.array_size(options) != 0) {
		return gd::as_dict(deep_duplicate_of(state, state.at(options, 0)));
	}
	return profile_option_dict(state, kPlayerProfileOptions[0]);
}

DictRef _random_map_public_h3maped_launch_config(State &state, DictRef input_config) {
	const Value size = dict_field_or_nil(state, input_config, key::size);
	// input_config.get("player_constraints", input_config.get("players", {})),
	// kept when it is a Dictionary.
	Value player_constraints;
	{
		Value found;
		const bool has_constraints = state.lookup(input_config, str(key::player_constraints), found);
		if (!has_constraints && !state.lookup(input_config, str(key::players), found)) {
			found = Value();
		}
		if (gd::is_dict(found)) {
			player_constraints = found;
		}
	}
	const Atom size_class_id = gd::stringify(state, read_field(state, size, key::size_class_id, state.get(input_config, str(key::size_class_id), str(key::empty))));
	const Atom water_mode = gd::stringify(state, read_field(state, size, key::water_mode, state.get(input_config, str(key::water_mode), str(key::land))));
	const int64_t level_count = gd::to_int(state, read_field(state, size, key::level_count, state.get(input_config, str(key::level_count), int_value(1))));
	if (gd::is_empty(state, _random_map_public_h3maped_scope_for(state, size_class_id, water_mode, level_count))) {
		return gd::deep_duplicate_dict(state, input_config);
	}
	const Atom seed_source = string_of(state, input_config, key::seed_source, key::explicit_);
	const Value seed_identity = dict_field_or_nil(state, input_config, key::seed_identity);
	const Value player_setup = dict_field_or_nil(state, input_config, key::player_setup);
	Atom source_seed = string_of(state, input_config, key::seed, key::empty);
	if (seed_source != key::auto_on_launch) {
		source_seed = gd::stringify(state, state.get(input_config, str(key::seed_input), read_field(state, seed_identity, key::input_seed, str(source_seed))));
	}
	// A catalog-auto setup, or any setup whose caller chose a strength, carries
	// the monster strength across the rebuild.
	const Value template_selection = dict_field_or_nil(state, input_config, key::template_selection);
	Atom monster_strength = key::empty;
	if (gd::stringify(state, read_field(state, template_selection, key::mode, str(key::empty))) == key::native_catalog_auto
			|| gd::to_bool(state.get(input_config, str(key::monster_strength_selected), bool_value(false)))) {
		monster_strength = string_of(state, input_config, key::monster_strength, key::empty);
	}
	Atom player_faction_id = gd::stringify(state, read_field(state, player_setup, key::faction_id, str(key::empty)));
	ArrayRef seat_faction_ids;
	{
		Value found;
		if (!state.lookup(input_config, str(key::seat_faction_ids), found)) {
			seat_faction_ids = state.new_array();
		} else if (gd::is_array(found)) {
			seat_faction_ids = gd::duplicate_array(state, found.ref);
		} else {
			seat_faction_ids = state.new_array();
		}
	}
	// A drawn player faction is drawn again, from the same seed.
	if (gd::stringify(state, read_field(state, player_setup, key::selection_mode, str(key::empty))) == key::random_from_seed) {
		player_faction_id = key::random;
		if (state.array_size(seat_faction_ids) != 0) {
			state.set_at(seat_faction_ids, 0, str(key::random));
		}
	}
	const int64_t player_count = gd::to_int(state, read_field(state, player_constraints, key::player_count, int_value(3)));
	const Atom player_hero_id = gd::stringify(state, read_field(state, player_setup, key::hero_id, str(key::empty)));
	const DictRef config = build_random_map_player_config(
			state,
			source_seed,
			key::empty,
			key::empty,
			player_count,
			water_mode,
			level_count > 1,
			size_class_id,
			key::native_catalog_auto,
			player_faction_id,
			player_hero_id,
			monster_strength,
			seat_faction_ids);
	state.set(config, str(key::seed_source), str(seed_source));
	state.set(config, str(key::seed_input), str(gd::stringify(state, state.get(input_config, str(key::seed_input), read_field(state, seed_identity, key::input_seed, str(source_seed))))));
	return config;
}

} // namespace aurelion::rules::port::scenario_select_rules
