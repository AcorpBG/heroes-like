// Layer 2: fog of war, the grids of explored tiles each map level keeps, and
// what the player's heroes, towns and held sites reveal in them.

#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

// OverworldRules.TOWN_VISION_RADIUS.
constexpr int64_t kTownVisionRadius = 8;

// `a[index] if index >= 0 and index < a.size() else []`.
Value row_or_new(State &state, ArrayRef grid, int64_t index) {
	if (index >= 0 && index < state.array_size(grid)) {
		return state.at(grid, index);
	}
	return array_value(state.new_array());
}

// str(level): the key of a level's fog.
Value level_key(State &state, int64_t level) {
	return state.string(compat::itos(level));
}

// A new row of a visibility grid: width cells of fill_value. A new node is built
// in place: it has no container to write back to and no type to check.
ArrayRef new_row(State &state, int64_t width, bool fill_value) {
	const ArrayRef row = state.new_array();
	state::ValueList &items = state.array_node(row).items;
	items.reserve(static_cast<size_t>(width));
	for (int64_t x = 0; x < width; ++x) {
		items.push_back(bool_value(fill_value));
	}
	return row;
}

} // namespace

namespace overworld_rules {

void refresh_fog_of_war(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	Value map;
	if (!state.lookup(overworld, str(key::map), map) || !gd::is_array(map)) {
		return;
	}
	_normalize_fog_of_war(state, session);
}

void _normalize_fog_of_war(State &state, DictRef session) {
	const Vector2i map_size = derive_map_size(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	if (level_rules::level_count(state, session) > 1) {
		const DictRef levels = state.new_dict();
		const int64_t level_count = level_rules::level_count(state, session);
		for (int64_t level = 0; level < level_count; ++level) {
			const DictRef existing = fog_for_level(state, session, level);
			ArrayRef explored = _normalize_visibility_grid(state, gd::field(state, existing, key::explored_tiles), map_size);
			explored = _merge_visibility_grids(state, explored, _normalize_visibility_grid(state, gd::field(state, existing, key::visible_tiles), map_size), map_size);
			_reveal_all_current_fog_sources(state, session, explored, map_size, level);
			state.set(levels, level_key(state, level), dict_value(_build_fog_payload(state, _duplicate_visibility_grid(state, explored), explored, map_size)));
		}
		// levels.get(str(hero_level), {}).duplicate(false)
		Value active_level_fog;
		const DictRef active = state.lookup(levels, level_key(state, hero_level(state, session)), active_level_fog) ? gd::duplicate_dict(state, gd::as_dict(active_level_fog)) : state.new_dict();
		state.set(active, str(key::levels), dict_value(levels));
		state.set(active, str(key::active_level), int_value(hero_level(state, session)));
		state.set(overworld, str(key::fog), dict_value(active));
		return;
	}
	Value fog = gd::field_or(state, overworld, key::fog, Value());
	if (!gd::is_dict(fog)) {
		fog = dict_value(state.new_dict());
	}
	ArrayRef explored_tiles;
	Value grid;
	if (state.lookup(fog.ref, str(key::explored_tiles), grid)) {
		explored_tiles = _normalize_visibility_grid(state, grid, map_size);
	} else {
		explored_tiles = _blank_visibility_grid(state, map_size, false);
	}
	if (state.lookup(fog.ref, str(key::visible_tiles), grid)) {
		explored_tiles = _merge_visibility_grids(state, explored_tiles, _normalize_visibility_grid(state, grid, map_size), map_size);
	}
	_reveal_all_current_fog_sources(state, session, explored_tiles, map_size, -1);
	state.set(overworld, str(key::fog), dict_value(_build_fog_payload(state, _duplicate_visibility_grid(state, explored_tiles), explored_tiles, map_size)));
}

DictRef fog_for_level(State &state, DictRef session, int64_t level) {
	level = level_rules::query_level(state, session, level);
	const DictRef overworld = session_view::overworld(state, session);
	const Value fog_value = gd::field(state, overworld, key::fog);
	const DictRef fog = gd::is_dict(fog_value) ? fog_value.ref : state.new_dict();
	const Value levels_value = gd::field(state, fog, key::levels);
	if (gd::is_dict(levels_value)) {
		const Value level_fog = gd::field_or(state, levels_value.ref, level_key(state, level).ref, Value());
		if (gd::is_dict(level_fog)) {
			return level_fog.ref;
		}
	}
	// A pre-level save's exploration belongs to surface. Do not reveal another
	// level by copying that grid, and never move a legacy saved hero by inference.
	return level == gd::int_field(state, fog, key::active_level, 0) ? fog : state.new_dict();
}

ArrayRef _normalize_visibility_grid(State &state, const Value &value, Vector2i map_size) {
	const ArrayRef normalized = _blank_visibility_grid(state, map_size, false);
	if (!gd::is_array(value)) {
		return normalized;
	}
	const int64_t rows = compat::engine_min<int64_t>(state.array_size(value.ref), map_size.y);
	for (int64_t y = 0; y < rows; ++y) {
		const Value row = state.at(value.ref, y);
		if (!gd::is_array(row)) {
			continue;
		}
		// normalized[y][x] = bool(row[x]), into the new row in place.
		const state::ValueList &source = state.array(row.ref).items;
		const int64_t columns = compat::engine_min<int64_t>(static_cast<int64_t>(source.size()), map_size.x);
		state::ValueList &target = state.array_node(state.at(normalized, y).ref).items;
		for (int64_t x = 0; x < columns; ++x) {
			target[static_cast<size_t>(x)] = bool_value(gd::to_bool(source[static_cast<size_t>(x)]));
		}
	}
	return normalized;
}

ArrayRef _blank_visibility_grid(State &state, Vector2i map_size, bool fill_value) {
	const ArrayRef grid = state.new_array();
	const int64_t height = compat::engine_max<int64_t>(map_size.y, 0);
	const int64_t width = compat::engine_max<int64_t>(map_size.x, 0);
	for (int64_t y = 0; y < height; ++y) {
		state.append(grid, array_value(new_row(state, width, fill_value)));
	}
	return grid;
}

ArrayRef _merge_visibility_grids(State &state, ArrayRef base, ArrayRef overlay, Vector2i map_size) {
	const int64_t height = compat::engine_max<int64_t>(map_size.y, 0);
	const int64_t width = compat::engine_max<int64_t>(map_size.x, 0);
	for (int64_t y = 0; y < height; ++y) {
		const Value base_row = row_or_new(state, base, y);
		const Value overlay_row = row_or_new(state, overlay, y);
		if (!gd::is_array(base_row) || !gd::is_array(overlay_row)) {
			continue;
		}
		const int64_t overlay_size = state.array_size(overlay_row.ref);
		for (int64_t x = 0; x < width; ++x) {
			if (x < overlay_size && gd::to_bool(state.at(overlay_row.ref, x))) {
				state.set_at(base_row.ref, x, bool_value(true));
			}
		}
		state.set_at(base, y, base_row);
	}
	return base;
}

ArrayRef _duplicate_visibility_grid(State &state, ArrayRef grid) {
	const ArrayRef duplicate_grid = state.new_array();
	for (const Value &row_value : gd::items(state, array_value(grid))) {
		if (gd::is_array(row_value)) {
			state.append(duplicate_grid, array_value(gd::duplicate_array(state, row_value.ref)));
		} else {
			state.append(duplicate_grid, array_value(state.new_array()));
		}
	}
	return duplicate_grid;
}

DictRef _build_fog_payload(State &state, ArrayRef visible_tiles, ArrayRef explored_tiles, Vector2i map_size) {
	const int64_t count_started_usec = _rules_profile_timer(state);
	const int64_t explored_count = _count_grid(state, array_value(explored_tiles));
	const int64_t visible_count = visible_tiles == explored_tiles ? explored_count : _count_grid(state, array_value(visible_tiles));
	_rules_profile_add_ms(state, key::fog_count_grid_ms, count_started_usec);
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::visible_tiles), array_value(visible_tiles));
	state.set(payload, str(key::explored_tiles), array_value(explored_tiles));
	state.set(payload, str(key::visible_count), int_value(visible_count));
	state.set(payload, str(key::explored_count), int_value(explored_count));
	state.set(payload, str(key::total_tiles), int_value(gd::mul(compat::engine_max<int64_t>(map_size.x, 0), compat::engine_max<int64_t>(map_size.y, 0))));
	return payload;
}

int64_t _count_grid(State &state, const Value &grid) {
	if (!gd::is_array(grid)) {
		return 0;
	}
	int64_t count = 0;
	for (const Value &row : gd::items(state, grid)) {
		if (!gd::is_array(row)) {
			continue;
		}
		for (const Value &value : gd::items(state, row)) {
			if (gd::to_bool(value)) {
				count = gd::add(count, 1);
			}
		}
	}
	return count;
}

void _reveal_all_current_fog_sources(State &state, DictRef session, ArrayRef explored_tiles, Vector2i map_size, int64_t level) {
	level = level_rules::query_level(state, session, level);
	int64_t source_count = 0;
	const DictRef overworld = session_view::overworld(state, session);
	const Value heroes = gd::field(state, overworld, key::player_heroes);
	if (gd::is_array(heroes)) {
		for (const Value &hero : gd::items(state, heroes)) {
			if (gd::is_dict(hero) && level_rules::on_level(state, hero, level)) {
				source_count = gd::add(source_count, 1);
				_apply_hero_reveal(state, explored_tiles, hero.ref, map_size);
			}
		}
	}
	Value towns;
	if (state.lookup(overworld, str(key::towns), towns)) {
		for (const Value &town_value : gd::items(state, towns)) {
			if (!gd::is_dict(town_value)) {
				continue;
			}
			const DictRef town = town_value.ref;
			if (gd::stringify(state, state.get(town, str(key::owner), str(key::neutral))) != key::player || !level_rules::on_level(state, town_value, level)) {
				continue;
			}
			source_count = gd::add(source_count, 1);
			_apply_site_reveal(state, explored_tiles, level_rules::town_entrance(state, town), kTownVisionRadius, map_size);
		}
	}
	Value nodes;
	if (state.lookup(overworld, str(key::resource_nodes), nodes)) {
		for (const Value &node : gd::items(state, nodes)) {
			if (!gd::is_dict(node) || !level_rules::on_level(state, node, level)) {
				continue;
			}
			// The holder first: the site row is read only for the player's nodes.
			// Both checks read without writing, so their order changes nothing.
			if (gd::stringify(state, state.get(node.ref, str(key::collected_by_faction_id), str(key::empty))) != key::player) {
				continue;
			}
			const DictRef site = gd::content_row(state, state::ContentTable::ResourceSite, gd::stringify(state, state.get(node.ref, str(key::site_id), str(key::empty))));
			if (!_resource_site_is_persistent(state, site)) {
				continue;
			}
			source_count = gd::add(source_count, 1);
			_apply_site_reveal(state, explored_tiles, node.ref, held_site_vision_radius(state, site), map_size);
		}
	}
	_rules_profile_set(state, key::fog, key::source_count, int_value(source_count));
}

void _apply_hero_reveal(State &state, ArrayRef explored_tiles, DictRef hero, Vector2i map_size) {
	const Value position = gd::field(state, hero, key::position);
	const DictRef position_dict = gd::is_dict(position) ? position.ref : state.new_dict();
	// Vector2i(int(...), int(...)): 32-bit components.
	const int32_t origin_x = static_cast<int32_t>(gd::int_field(state, position_dict, key::x, 0));
	const int32_t origin_y = static_cast<int32_t>(gd::int_field(state, position_dict, key::y, 0));
	const int64_t radius = hero_command_rules::scouting_radius_for_hero(state, hero);
	const DictRef origin = state.new_dict();
	state.set(origin, str(key::x), int_value(origin_x));
	state.set(origin, str(key::y), int_value(origin_y));
	_apply_site_reveal(state, explored_tiles, origin, radius, map_size);
}

void _apply_site_reveal(State &state, ArrayRef explored_tiles, DictRef site_state, int64_t radius, Vector2i map_size) {
	if (radius <= 0) {
		return;
	}
	const int64_t origin_x = static_cast<int32_t>(gd::int_field(state, site_state, key::x, 0));
	const int64_t origin_y = static_cast<int32_t>(gd::int_field(state, site_state, key::y, 0));
	const int64_t last_y = compat::engine_min<int64_t>(map_size.y - 1, gd::add(origin_y, radius));
	for (int64_t y = compat::engine_max<int64_t>(0, gd::sub(origin_y, radius)); y < last_y + 1; ++y) {
		const int64_t half_width = hero_command_rules::scout_row_half_width(gd::sub(y, origin_y), radius);
		const int64_t last_x = compat::engine_min<int64_t>(map_size.x - 1, gd::add(origin_x, half_width));
		for (int64_t x = compat::engine_max<int64_t>(0, gd::sub(origin_x, half_width)); x < last_x + 1; ++x) {
			_set_grid_cell(state, explored_tiles, x, y, true);
		}
	}
}

void _set_grid_cell(State &state, ArrayRef grid, int64_t x, int64_t y, bool value) {
	if (y < 0 || y >= state.array_size(grid)) {
		return;
	}
	const Value row = state.at(grid, y);
	if (!gd::is_array(row) || x < 0 || x >= state.array_size(row.ref)) {
		return;
	}
	state.set_at(row.ref, x, bool_value(value));
	state.set_at(grid, y, row);
}

int64_t held_site_vision_radius(State &state, DictRef site) {
	if (!_resource_site_is_persistent(state, site)) {
		return 0;
	}
	return compat::engine_max<int64_t>(0, gd::int_field(state, site, key::vision_radius, 0));
}

int64_t hero_level(State &state, DictRef session) {
	return level_rules::hero_level(state, session);
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
