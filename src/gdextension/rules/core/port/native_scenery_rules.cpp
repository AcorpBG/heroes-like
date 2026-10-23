// NativeSceneryRules: which random map objects are scenery, their art
// candidates (memoized in _candidate_cache, shared with the GDScript copy) and
// whether the art covers every scenery object of a map.

#include "aurelion_rules/port/native_scenery_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"

#include <cstdint>
#include <initializer_list>
#include <unordered_set>
#include <utility>

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
using state::State;
using state::Value;
namespace key = state::key;

constexpr Atom kScript = key::native_scenery_rules_script;
constexpr Atom kManifest = key::res_art_overworld_native_scenery_json;
// NativeSceneryRules.PRESENTATION_VERSION.
constexpr int64_t kPresentationVersion = 2;

// {"a": x, "b": y}: the keys set in the literal's order.
DictRef dict_of(State &state, std::initializer_list<std::pair<Atom, Value>> fields) {
	const DictRef dict = state.new_dict();
	for (const auto &field : fields) {
		state.set(dict, str(field.first), field.second);
	}
	return dict;
}

// a.get(k1, {}).get(k2, {})...: false when a key is missing (the chain then
// answers its new fallback, which the caller only reads); a value on the way
// that is not a Dictionary is GDScript's error.
bool get_chain(const State &state, const Value &start, std::initializer_list<Value> path, Value &found) {
	Value at = start;
	for (const Value &step : path) {
		if (!gd::is_dict(at)) {
			(void)ai::vget(state, at, step);
		}
		Value next;
		if (!state.lookup(at.ref, step, next)) {
			return false;
		}
		at = next;
	}
	found = at;
	return true;
}

// var x: Array = <chain>: the Array, or false for the chain's new [] (only read).
bool array_chain(const State &state, const Value &start, std::initializer_list<Value> path, ArrayRef &found) {
	Value value;
	if (!get_chain(state, start, path, value)) {
		return false;
	}
	found = gd::as_array(value);
	return true;
}

// object.get(field, []).is_empty().
bool field_is_empty(const State &state, DictRef object, Atom field) {
	Value found;
	return !state.lookup(object, str(field), found) || ai::vempty(state, found);
}

} // namespace

namespace native_scenery_rules {

ArrayRef asset_candidates(State &state, DictRef object, Atom biome_id, Atom terrain_id) {
	const int64_t version = gd::int_field(state, object, key::native_scenery_art_version, 0);
	if (version < 1) {
		return state.new_array();
	}
	const Value cache_key = str(gd::format(state, key::d_s_s_s, { int_value(version), gd::field_or(state, object, key::h3m_type_id, int_value(-1)), str(biome_id), str(terrain_id) }));
	const DictRef cache = ai::static_dict(state, kScript, key::_candidate_cache);
	if (state.has(cache, cache_key)) {
		return gd::as_array(gd::index(state, cache, cache_key));
	}
	const DictRef manifest = gd::content_file(state, kManifest);
	const DictRef entry = policy(state, object);
	if (version >= kPresentationVersion) {
		const Value variation_family = state.get(entry, str(key::variation_family), str(key::empty));
		const Atom family = gd::stringify(state, state.get(entry, str(key::landscape_family), variation_family));
		if (family != key::empty) {
			ArrayRef terrain_pool = 0;
			const bool has_pool = array_chain(state, dict_value(manifest), { str(key::terrain_component_palettes), str(terrain_id), str(family) }, terrain_pool);
			if (!state.has(entry, str(key::variation_biome)) && has_pool && state.array_size(terrain_pool) > 0) {
				state.set(cache, cache_key, array_value(terrain_pool));
				return terrain_pool;
			}
			const Atom art_biome = gd::stringify(state, state.get(entry, str(key::variation_biome), str(biome_id)));
			// Production component palettes replace the old few-source clusters.
			ArrayRef components = 0;
			if (array_chain(state, dict_value(manifest), { str(key::component_palettes), str(family), str(art_biome) }, components) && state.array_size(components) > 0) {
				state.set(cache, cache_key, array_value(components));
				return components;
			}
			ArrayRef seeds = 0;
			const bool has_seeds = array_chain(state, dict_value(manifest), { str(key::landscape_palettes), str(family), str(art_biome) }, seeds);
			Value asset_ids;
			const ArrayRef candidates = state.lookup(entry, str(key::asset_ids), asset_ids)
					? gd::as_array(gd::duplicate_value(state, asset_ids, false))
					: state.new_array();
			const ArrayRef additions = has_seeds ? gd::duplicate_array(state, seeds) : state.new_array();
			ArrayRef library = 0;
			if (array_chain(state, dict_value(manifest), { str(key::library_palettes), str(family), str(art_biome) }, library)) {
				ai::append_array(state, additions, library);
			}
			// Harsh-biome woods use their native dead trees, and the assembled
			// deadwood too.
			if (has_seeds) {
				for (int64_t index = 0; index < state.array_size(seeds); ++index) {
					const Atom asset = gd::stringify(state, state.at(seeds, index));
					if (gd::begins_with(state, asset, key::cohesive_library_) && gd::ends_with(state, asset, key::_000)) {
						ArrayRef deadwood = 0;
						if (array_chain(state, dict_value(manifest), { str(key::library_palettes), str(key::deadwood), str(art_biome) }, deadwood)) {
							ai::append_array(state, additions, deadwood);
						}
						break;
					}
				}
			}
			for (int64_t index = 0; index < state.array_size(additions); ++index) {
				const Value asset = state.at(additions, index);
				if (!gd::array_has(state, candidates, asset)) {
					state.append(candidates, asset);
				}
			}
			state.set(cache, cache_key, array_value(candidates));
			return candidates;
		}
	}
	Value asset_ids;
	if (state.lookup(entry, str(key::asset_ids), asset_ids)) {
		return gd::as_array(asset_ids);
	}
	return state.new_array();
}

DictRef policy(State &state, DictRef object) {
	const DictRef manifest = gd::content_file(state, kManifest);
	const Atom type_key = gd::stringify(state, int_value(gd::int_field(state, object, key::h3m_type_id, -1)));
	Value found;
	if (get_chain(state, dict_value(manifest), { str(key::source_types), str(type_key) }, found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

bool is_scenery(State &state, DictRef object) {
	return !gd::is_empty(state, policy(state, object));
}

DictRef validate(State &state, ArrayRef objects) {
	std::unordered_set<int64_t> checked;
	Value assets_value;
	const DictRef assets = state.lookup(gd::content_file(state, key::res_art_overworld_manifest_json), str(key::object_assets), assets_value)
			? gd::as_dict(assets_value)
			: state.new_dict();
	for (int64_t object_index = 0; object_index < state.array_size(objects); ++object_index) {
		const Value item = state.at(objects, object_index);
		const int64_t type_id = gd::to_int(state, ai::vget(state, item, str(key::h3m_type_id), int_value(-1)));
		if (type_id < 0) {
			continue;
		}
		const DictRef object = gd::as_dict(item);
		const DictRef entry = policy(state, object);
		const Atom kind = ai::string_or_empty(state, object, key::kind);
		if (gd::is_empty(state, entry)) {
			if (kind == key::decorative_obstacle || (kind == key::h3m_object && field_is_empty(state, object, key::package_visit_tiles))) {
				return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_scenery_type_unmapped) }, { key::type_id, int_value(type_id) } });
			}
			continue;
		}
		if (!field_is_empty(state, object, key::package_visit_tiles)) {
			return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_scenery_unexpected_interaction) }, { key::type_id, int_value(type_id) } });
		}
		if (checked.count(type_id) > 0) {
			continue;
		}
		checked.insert(type_id);
		Value asset_ids;
		const ArrayRef candidates = state.lookup(entry, str(key::asset_ids), asset_ids)
				? gd::as_array(gd::duplicate_value(state, asset_ids, false))
				: state.new_array();
		const Atom family = ai::string_or_empty(state, entry, key::landscape_family);
		if (family != key::empty) {
			Value palettes_value;
			const bool has_palettes = get_chain(state, dict_value(gd::content_file(state, kManifest)), { str(key::landscape_palettes), str(family) }, palettes_value);
			if (has_palettes) {
				(void)gd::as_dict(palettes_value);
			}
			if (!has_palettes || state.dict_size(palettes_value.ref) != 9) {
				return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_scenery_biome_palette_missing) }, { key::family, str(family) } });
			}
			const DictRef palettes = palettes_value.ref;
			for (const Value &palette_biome : gd::items(state, dict_value(palettes))) {
				const Value palette = gd::index(state, palettes, palette_biome);
				if (ai::vempty(state, palette)) {
					return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_scenery_biome_palette_empty) }, { key::family, str(family) }, { key::biome_id, palette_biome } });
				}
				ai::append_array(state, candidates, gd::as_array(palette));
			}
		} else if (state.array_size(candidates) == 0) {
			return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_scenery_semantic_art_missing) }, { key::type_id, int_value(type_id) } });
		}
		Value rock;
		if (get_chain(state, dict_value(gd::content_file(state, kManifest)), { str(key::landscape_palettes), str(key::rock) }, rock)) {
			for (const Value &biome_id : gd::items(state, rock)) {
				ai::append_array(state, candidates, asset_candidates(state, object, gd::to_string(biome_id)));
			}
		}
		for (int64_t index = 0; index < state.array_size(candidates); ++index) {
			const Value asset_id = state.at(candidates, index);
			Value asset;
			Value path_value = str(key::empty);
			if (state.lookup(assets, asset_id, asset)) {
				path_value = ai::vget(state, asset, str(key::path), str(key::empty));
			}
			const Atom path = gd::stringify(state, path_value);
			if (path == key::empty || !gd::resource_exists(state, path)) {
				return dict_of(state, { { key::ok, bool_value(false) }, { key::error, str(key::native_scenery_raster_missing) }, { key::asset_id, asset_id } });
			}
		}
	}
	return dict_of(state, { { key::ok, bool_value(true) } });
}

} // namespace native_scenery_rules

} // namespace aurelion::rules::port
