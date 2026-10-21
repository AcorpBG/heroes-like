// OverworldRules: the normalized read scope's keys and hit counts, terrain
// passability, the per-level spatial lookup index and guard engagement tiles.

#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"

#include <string>

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
using overworld_rules::Tiles;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

// d.clear() (Dictionary::clear): a read-only Dictionary prints an error and stays.
void dict_clear(State &state, DictRef dict) {
	if (state.dict(dict).read_only) {
		state.print_error("Dictionary is in read-only state.");
		return;
	}
	const ArrayRef keys = gd::keys(state, dict);
	for (const Value &entry_key : gd::items(state, array_value(keys))) {
		state.erase(dict, entry_key);
	}
}

// An untyped value passed to a Vector2i parameter.
Vector2i as_vector2i(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Invalid type in function '_tile_key'. Cannot convert argument 1 from ") + gd::type_name(value) + " to Vector2i.");
	}
	return {value.vx(), value.vy()};
}

// A new untyped Array of the tiles as Vector2i values.
ArrayRef tiles_array(State &state, const Tiles &tiles) {
	const ArrayRef array = state.new_array();
	for (const Vector2i tile : tiles) {
		state.append(array, Value::of_vector2i(tile.x, tile.y));
	}
	return array;
}

// {"index": -1, "encounter": {}}.
DictRef no_guard_engagement(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(-1));
	state.set(result, str(key::encounter), dict_value(state.new_dict()));
	return result;
}

} // namespace

namespace overworld_rules {

int64_t _collection_size(State &state, const Value &value) {
	if (gd::is_array(value)) {
		return state.array_size(value.ref);
	}
	if (gd::is_dict(value)) {
		return state.dict_size(value.ref);
	}
	return 0;
}

Atom _town_content_read_scope_key(State &state, Atom kind, DictRef town, Atom extra) {
	if (ai::static_int(state, key::overworld_rules_script, key::_normalized_read_scope_depth) <= 0) {
		return key::empty;
	}
	const Atom digest = _read_scope_town_digest(state, town);
	return gd::format(state, key::content_s_s_s, {str(kind), str(digest), str(extra)});
}

bool _town_read_scope_cache_has(State &state, Atom cache_key) {
	if (cache_key == key::empty || !state.has(ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache), str(cache_key))) {
		if (cache_key != key::empty) {
			const DictRef profile = ai::static_dict(state, key::overworld_rules_script, key::_last_normalized_read_scope_cache_profile);
			state.set(profile, str(key::misses), int_value(gd::add(gd::int_field(state, profile, key::misses, 0), 1)));
		}
		return false;
	}
	const DictRef profile = ai::static_dict(state, key::overworld_rules_script, key::_last_normalized_read_scope_cache_profile);
	state.set(profile, str(key::hits), int_value(gd::add(gd::int_field(state, profile, key::hits, 0), 1)));
	return true;
}

bool terrain_id_is_passable(State &state, Atom terrain_id) {
	const int64_t revision = gd::content_revision(state);
	if (revision != ai::static_int(state, key::overworld_rules_script, key::_terrain_passable_cache_revision)) {
		dict_clear(state, ai::static_dict(state, key::overworld_rules_script, key::_terrain_passable_cache));
		gd::set_static_var(state, key::overworld_rules_script, key::_terrain_passable_cache_revision, int_value(revision));
	}
	const DictRef cache = ai::static_dict(state, key::overworld_rules_script, key::_terrain_passable_cache);
	const Value cached = state.get(cache, str(terrain_id), Value());
	if (cached.kind != Kind::Nil) {
		return gd::to_bool(cached);
	}
	const bool passable = _terrain_id_is_passable_uncached(state, terrain_id);
	state.set(cache, str(terrain_id), bool_value(passable));
	return passable;
}

bool _terrain_id_is_passable_uncached(State &state, Atom terrain_id) {
	const Atom normalized = content_service::normalize_terrain_id(state, terrain_id);
	if (normalized == key::rock || normalized == key::water) {
		return false;
	}
	const DictRef biome = gd::content_row(state, ContentTable::BiomeForTerrain, normalized);
	if (!gd::is_empty(state, biome) && state.has(biome, str(key::passable))) {
		return gd::bool_field(state, biome, key::passable, true);
	}
	return true;
}

DictRef _spatial_lookup_index(State &state, DictRef session, int64_t level) {
	const ArrayRef signature = _spatial_lookup_signature(state, session);
	bool stale = !ai::meta_has(state, session, key::_overworld_spatial_lookup_indexes);
	if (!stale) {
		Value stored_signature;
		if (state.lookup(session_view::meta(state, session), gd::name_value(key::_overworld_spatial_lookup_signature), stored_signature)) {
			stale = !gd::equal(state, stored_signature, array_value(signature));
		} else {
			// [] != signature.
			stale = state.array_size(signature) != 0;
		}
	}
	if (stale) {
		ai::meta_set(state, session, key::_overworld_spatial_lookup_indexes, dict_value(state.new_dict()));
		ai::meta_set(state, session, key::_overworld_spatial_lookup_signature, array_value(signature));
	}
	const int64_t resolved_level = level_rules::query_level(state, session, level);
	const DictRef levels = gd::as_dict(ai::meta_get(state, session, key::_overworld_spatial_lookup_indexes));
	const Value level_key = int_value(resolved_level);
	if (!state.has(levels, level_key)) {
		const DictRef built = _build_spatial_lookup_index(state, session, resolved_level);
		state.set(levels, level_key, dict_value(built));
	}
	return gd::as_dict(gd::index(state, levels, level_key));
}

ArrayRef _spatial_lookup_signature(State &state, DictRef session) {
	const Atom scenario_id = gd::to_string(gd::index(state, session, str(key::scenario_id)));
	const Vector2i map_size = derive_map_size(state, session);
	const int64_t level_count = level_rules::level_count(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef signature = state.new_array();
	state.append(signature, str(scenario_id));
	state.append(signature, Value::of_vector2i(map_size.x, map_size.y));
	state.append(signature, int_value(level_count));
	state.append(signature, int_value(_collection_size(state, state.get(overworld, str(key::towns), Value()))));
	state.append(signature, int_value(_collection_size(state, state.get(overworld, str(key::resource_nodes), Value()))));
	state.append(signature, int_value(_collection_size(state, state.get(overworld, str(key::artifact_nodes), Value()))));
	state.append(signature, int_value(_collection_size(state, state.get(overworld, str(key::encounters), Value()))));
	return signature;
}

DictRef _build_spatial_lookup_index(State &state, DictRef session, int64_t level) {
	const DictRef index = state.new_dict();
	const auto table = [&](Atom name) {
		const DictRef made = state.new_dict();
		state.set(index, str(name), dict_value(made));
		return made;
	};
	const DictRef town_by_tile = table(key::town_by_tile);
	const DictRef town_by_placement = table(key::town_by_placement);
	table(key::resource_by_tile);
	table(key::resource_by_interaction_tile);
	table(key::resource_by_placement);
	const DictRef artifact_by_tile = table(key::artifact_by_tile);
	const DictRef artifact_by_placement = table(key::artifact_by_placement);
	const DictRef encounter_by_tile = table(key::encounter_by_tile);
	const DictRef encounter_by_placement = table(key::encounter_by_placement);
	const DictRef guard_engagement_by_tile = table(key::guard_engagement_by_tile);
	const DictRef overworld = session_view::overworld(state, session);

	const Value towns = state.get(overworld, str(key::towns), Value());
	if (gd::is_array(towns)) {
		const int64_t count = state.array_size(towns.ref);
		for (int64_t town_index = 0; town_index < count; ++town_index) {
			const Value town = state.at(towns.ref, town_index);
			if (!gd::is_dict(town)) {
				continue;
			}
			const Atom placement_id = ai::string_or_empty(state, town.ref, key::placement_id);
			if (placement_id != key::empty) {
				state.set(town_by_placement, str(placement_id), int_value(town_index));
			}
			if (!level_rules::on_level(state, town, level)) {
				continue;
			}
			const int64_t x = gd::int_field(state, town.ref, key::x, -1);
			state.set(town_by_tile, str(_tile_key(state, Vector2i::of(x, gd::int_field(state, town.ref, key::y, -1)))), int_value(town_index));
			Value visit_tile;
			if (state.lookup(town.ref, str(key::visit_tile), visit_tile) && gd::is_dict(visit_tile) && !gd::is_empty(state, visit_tile.ref)) {
				const int64_t visit_x = gd::int_field(state, visit_tile.ref, key::x, -1);
				state.set(town_by_tile, str(_tile_key(state, Vector2i::of(visit_x, gd::int_field(state, visit_tile.ref, key::y, -1)))), int_value(town_index));
			}
		}
	}

	Value resources;
	if (!state.lookup(overworld, str(key::resource_nodes), resources)) {
		resources = array_value(state.new_array());
	}
	if (gd::is_array(resources)) {
		const ArrayRef resource_section = _spatial_resource_section(state, session, resources.ref, level);
		state.set(index, str(key::resource_by_tile), state.at(resource_section, 0));
		state.set(index, str(key::resource_by_interaction_tile), state.at(resource_section, 1));
		state.set(index, str(key::resource_by_placement), state.at(resource_section, 2));
	}

	const Value artifacts = state.get(overworld, str(key::artifact_nodes), Value());
	if (gd::is_array(artifacts)) {
		const int64_t count = state.array_size(artifacts.ref);
		for (int64_t artifact_index = 0; artifact_index < count; ++artifact_index) {
			const Value artifact = state.at(artifacts.ref, artifact_index);
			if (!gd::is_dict(artifact)) {
				continue;
			}
			const Atom artifact_placement_id = ai::string_or_empty(state, artifact.ref, key::placement_id);
			if (artifact_placement_id != key::empty) {
				state.set(artifact_by_placement, str(artifact_placement_id), int_value(artifact_index));
			}
			if (!level_rules::on_level(state, artifact, level)) {
				continue;
			}
			const int64_t x = gd::int_field(state, artifact.ref, key::x, -1);
			const Atom tile_key = _tile_key(state, Vector2i::of(x, gd::int_field(state, artifact.ref, key::y, -1)));
			_append_spatial_lookup_entry(state, dict_value(artifact_by_tile), tile_key, artifact_index);
		}
	}

	const Value encounters = state.get(overworld, str(key::encounters), Value());
	if (gd::is_array(encounters)) {
		const int64_t count = state.array_size(encounters.ref);
		for (int64_t encounter_index = 0; encounter_index < count; ++encounter_index) {
			const Value encounter = state.at(encounters.ref, encounter_index);
			if (!gd::is_dict(encounter)) {
				continue;
			}
			const Value id_fallback = state.get(encounter.ref, str(key::id), str(key::empty));
			const Atom encounter_placement_id = gd::stringify(state, state.get(encounter.ref, str(key::placement_id), id_fallback));
			if (encounter_placement_id != key::empty) {
				state.set(encounter_by_placement, str(encounter_placement_id), int_value(encounter_index));
			}
			if (!level_rules::on_level(state, encounter, level)) {
				continue;
			}
			const int64_t x = gd::int_field(state, encounter.ref, key::x, -1);
			const Atom tile_key = _tile_key(state, Vector2i::of(x, gd::int_field(state, encounter.ref, key::y, -1)));
			_append_spatial_lookup_entry(state, dict_value(encounter_by_tile), tile_key, encounter_index);
			if (_encounter_has_guard_engagement_surface(state, encounter.ref)) {
				const ArrayRef engagement_tiles = _guard_engagement_world_tiles(state, encounter.ref);
				for (const Value &engagement_tile : gd::items(state, array_value(engagement_tiles))) {
					if (gd::is_vector2i(engagement_tile)) {
						_append_spatial_lookup_entry(state, dict_value(guard_engagement_by_tile), _tile_key(state, as_vector2i(engagement_tile)), encounter_index);
					}
				}
			} else if (_ai_hero_guards_against_player(state, session, encounter.ref)) {
				const int64_t hero_x = gd::int_field(state, encounter.ref, key::x, -1);
				const Vector2i hero_tile = Vector2i::of(hero_x, gd::int_field(state, encounter.ref, key::y, -1));
				const ArrayRef zone_tiles = hero_guard_zone_tiles(state, session, hero_tile, level);
				for (const Value &zone_tile : gd::items(state, array_value(zone_tiles))) {
					_append_spatial_lookup_entry(state, dict_value(guard_engagement_by_tile), _tile_key(state, as_vector2i(zone_tile)), encounter_index);
				}
			}
		}
	}
	return index;
}

ArrayRef _spatial_resource_section(State &state, DictRef session, ArrayRef resources, int64_t level) {
	// Every node field the tables read: the placement id, the tile and level,
	// and what picks the map object and its interaction tiles.
	static constexpr Atom kFingerprintFields[] = {
		key::placement_id,
		key::x,
		key::y,
		key::level,
		key::position,
		key::visit_tile,
		key::primary_tile,
		key::kind,
		key::site_id,
		key::object_id,
	};
	const Value missing = gd::name_value(key::_overworld_spatial_fingerprint_missing);
	const ArrayRef fingerprint = state.new_array();
	for (const Value &node : gd::items(state, array_value(resources))) {
		if (!gd::is_dict(node)) {
			state.append(fingerprint, Value());
			continue;
		}
		const ArrayRef fields = state.new_array();
		for (const Atom field : kFingerprintFields) {
			state.append(fields, state.get(node.ref, str(field), missing));
		}
		state.append(fingerprint, array_value(fields));
	}
	const int64_t revision = gd::content_revision(state);
	const DictRef map_objects = gd::content_file(state, key::map_objects_path);
	const DictRef resource_sites = gd::content_file(state, key::resource_sites_path);
	// level -> [content revision, map objects, resource sites, fingerprint copy, tables]
	const DictRef sections = ai::meta_has(state, session, key::_overworld_spatial_resource_sections)
			? gd::as_dict(ai::meta_get(state, session, key::_overworld_spatial_resource_sections))
			: state.new_dict();
	const Value level_key = int_value(level);
	Value found;
	if (state.lookup(sections, level_key, found)) {
		const ArrayRef cached = gd::as_array(found);
		if (state.array_size(cached) == 5 &&
				gd::to_int(state, state.at(cached, 0)) == revision &&
				gd::is_same(state, state.at(cached, 1), dict_value(map_objects)) &&
				gd::is_same(state, state.at(cached, 2), dict_value(resource_sites)) &&
				gd::equal(state, state.at(cached, 3), array_value(fingerprint))) {
			return gd::as_array(state.at(cached, 4));
		}
	}
	const ArrayRef section = _build_spatial_resource_section(state, resources, level);
	const ArrayRef entry = state.new_array();
	state.append(entry, int_value(revision));
	state.append(entry, dict_value(map_objects));
	state.append(entry, dict_value(resource_sites));
	state.append(entry, array_value(gd::deep_duplicate_array(state, fingerprint)));
	state.append(entry, array_value(section));
	state.set(sections, level_key, array_value(entry));
	ai::meta_set(state, session, key::_overworld_spatial_resource_sections, dict_value(sections));
	return section;
}

ArrayRef _build_spatial_resource_section(State &state, ArrayRef resources, int64_t level) {
	const DictRef by_tile = state.new_dict();
	const DictRef by_interaction_tile = state.new_dict();
	const DictRef by_placement = state.new_dict();
	const int64_t count = state.array_size(resources);
	for (int64_t node_index = 0; node_index < count; ++node_index) {
		const Value node = state.at(resources, node_index);
		if (!gd::is_dict(node)) {
			continue;
		}
		const Atom resource_placement_id = ai::string_or_empty(state, node.ref, key::placement_id);
		if (resource_placement_id != key::empty) {
			state.set(by_placement, str(resource_placement_id), int_value(node_index));
		}
		if (!level_rules::on_level(state, node, level)) {
			continue;
		}
		const int64_t x = gd::int_field(state, node.ref, key::x, -1);
		const Atom node_tile_key = _tile_key(state, Vector2i::of(x, gd::int_field(state, node.ref, key::y, -1)));
		_append_spatial_lookup_entry(state, dict_value(by_tile), node_tile_key, node_index);
		const DictRef map_object = _map_object_for_resource_node(state, node.ref);
		const ArrayRef interaction_tiles = _resource_node_world_interaction_tiles(state, map_object, node.ref);
		for (const Value &interaction_tile : gd::items(state, array_value(interaction_tiles))) {
			if (gd::is_vector2i(interaction_tile)) {
				_append_spatial_lookup_entry(state, dict_value(by_interaction_tile), _tile_key(state, as_vector2i(interaction_tile)), node_index);
			}
		}
	}
	const ArrayRef section = state.new_array();
	state.append(section, dict_value(by_tile));
	state.append(section, dict_value(by_interaction_tile));
	state.append(section, dict_value(by_placement));
	return section;
}

void _append_spatial_lookup_entry(State &state, const Value &index_value, Atom entry_key, int64_t entry_index) {
	if (!gd::is_dict(index_value) || entry_key == key::empty) {
		return;
	}
	const DictRef index = index_value.ref;
	Value found;
	const ArrayRef entries = state.lookup(index, str(entry_key), found) && gd::is_array(found) ? found.ref : state.new_array();
	state.append(entries, int_value(entry_index));
	state.set(index, str(entry_key), array_value(entries));
}

DictRef _find_guard_engagement_at_tile(State &state, DictRef session, int64_t x, int64_t y, int64_t level, bool include_heroes) {
	// A missing list reads as [], which has no index in range, as null does.
	const Value encounters = state.get(session_view::overworld(state, session), str(key::encounters), Value());
	const DictRef lookup_index = _spatial_lookup_index(state, session, level);
	const ArrayRef entries = _spatial_lookup_entries(state, lookup_index, key::guard_engagement_by_tile, Vector2i::of(x, y));
	for (const Value &encounter_index : gd::items(state, array_value(entries))) {
		const int64_t index = gd::to_int(state, encounter_index);
		const Value encounter = gd::is_array(encounters) && index >= 0 && index < state.array_size(encounters.ref)
				? state.at(encounters.ref, index)
				: dict_value(state.new_dict());
		if (!include_heroes && gd::is_dict(encounter) && gd::is_dict(state.get(encounter.ref, str(key::ai_hero), Value()))) {
			continue;
		}
		if (gd::is_dict(encounter) && !is_encounter_resolved(state, session, encounter.ref)) {
			const DictRef result = state.new_dict();
			state.set(result, str(key::index), int_value(index));
			state.set(result, str(key::encounter), encounter);
			return result;
		}
	}
	return no_guard_engagement(state);
}

bool _encounter_has_guard_engagement_surface(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return false;
	}
	const Value native_fallback = state.get(encounter, str(key::native_record_kind), str(key::empty));
	const Value package_fallback = state.get(encounter, str(key::package_kind), native_fallback);
	const Atom kind = gd::stringify(state, state.get(encounter, str(key::kind), package_fallback));
	const Atom package_kind = ai::string_or_empty(state, encounter, key::package_kind);
	const Atom native_kind = ai::string_or_empty(state, encounter, key::native_record_kind);
	if (kind == key::guard || package_kind == key::guard || native_kind == key::guard) {
		return true;
	}
	if (gd::is_array(state.get(encounter, str(key::package_guard_engagement_tiles), Value()))) {
		return true;
	}
	if (gd::is_array(state.get(encounter, str(key::package_guard_control_zone_tiles), Value()))) {
		return true;
	}
	return gd::strip_edges(state, ai::string_or_empty(state, encounter, key::guard_kind)) != key::empty;
}

ArrayRef hero_guard_zone_tiles(State &state, DictRef session, Vector2i tile, int64_t level) {
	if (_town_entrance_at(state, session, tile, level)) {
		return state.new_array();
	}
	// WaterTravelRules.NEIGHBORS, in its order.
	static constexpr int32_t kNeighbors[8][2] = {{0, 1}, {-1, 0}, {1, 0}, {0, -1}, {-1, 1}, {1, 1}, {-1, -1}, {1, -1}};
	const Vector2i size = derive_map_size(state, session);
	const Value session_value = dict_value(session);
	const bool on_water = water_travel_rules::is_water(state, session_value, tile.x, tile.y, level);
	const ArrayRef tiles = state.new_array();
	for (const auto &offset : kNeighbors) {
		const Vector2i next = tile + Vector2i{offset[0], offset[1]};
		if (next.x < 0 || next.y < 0 || next.x >= size.x || next.y >= size.y) {
			continue;
		}
		if (water_travel_rules::is_water(state, session_value, next.x, next.y, level) != on_water) {
			continue;
		}
		state.append(tiles, Value::of_vector2i(next.x, next.y));
	}
	return tiles;
}

bool _ai_hero_guards_against_player(State &state, DictRef session, DictRef encounter) {
	if (!gd::is_dict(state.get(encounter, str(key::ai_hero), Value()))) {
		return false;
	}
	const Atom controller = player_identity_rules::raid_controller_id(state, encounter);
	return controller != key::empty && !player_identity_rules::allied(state, dict_value(session), controller, key::player);
}

bool _town_entrance_at(State &state, DictRef session, Vector2i tile, int64_t level) {
	for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town)) {
			continue;
		}
		const DictRef entrance = level_rules::town_entrance(state, town.ref);
		if (level_rules::level_of(state, dict_value(entrance)) == level &&
				gd::int_field(state, entrance, key::x, -1) == tile.x &&
				gd::int_field(state, entrance, key::y, -1) == tile.y) {
			return true;
		}
	}
	return false;
}

ArrayRef _guard_engagement_world_tiles(State &state, DictRef encounter) {
	static constexpr Atom kTileFields[] = {key::package_guard_engagement_tiles, key::package_guard_control_zone_tiles, key::guard_control_zone_tiles};
	for (const Atom field : kTileFields) {
		const Value tiles = state.get(encounter, str(field), Value());
		if (gd::is_array(tiles)) {
			const Tiles world_tiles = _world_tiles_from_payload_array(state, tiles);
			if (!world_tiles.empty()) {
				return tiles_array(state, world_tiles);
			}
		}
	}
	if (!_encounter_has_guard_engagement_surface(state, encounter)) {
		return state.new_array();
	}
	const int64_t x = gd::int_field(state, encounter, key::x, -1);
	const Vector2i tile = Vector2i::of(x, gd::int_field(state, encounter, key::y, -1));
	const ArrayRef result = state.new_array();
	state.append(result, Value::of_vector2i(tile.x, tile.y));
	return result;
}

ArrayRef _spatial_lookup_entries(State &state, DictRef index, Atom name, Vector2i tile) {
	Value table;
	if (!state.lookup(index, str(name), table) || !gd::is_dict(table)) {
		return state.new_array();
	}
	Value entries;
	if (state.lookup(table.ref, str(_tile_key(state, tile)), entries) && gd::is_array(entries)) {
		return entries.ref;
	}
	return state.new_array();
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
