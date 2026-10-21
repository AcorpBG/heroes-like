// OverworldLevelRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/overworld_level_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
// d.clear() (Dictionary::clear): a read-only Dictionary prints an error and stays.
void dict_clear(State &state, DictRef dict) {
	if (state.dict(dict).read_only) {
		state.print_error("Dictionary is in read-only state.");
		return;
	}
	state::DictNode &node = state.dict_node(dict);
	node.keys.clear();
	node.values.clear();
	node.dirty = true;
}
// OverworldLevelRules.level_of, with a Vector3i's level (its z).
int64_t level_of_value(State &state, const Value &value) {
	if (gd::is_vector3i(value)) {
		return value.vz();
	}
	return overworld_level_rules::level_of(state, value);
}

} // namespace

namespace overworld_level_rules {

bool same_level(State &state, const Value &a, const Value &b) {
	const int64_t level_a = level_of_value(state, a);
	return level_a == level_of_value(state, b);
}

ArrayRef terrain_rows(State &state, const Value &session_value, int64_t requested) {
	if (session_value.kind == Kind::Nil) {
		return state.new_array();
	}
	if (!gd::is_dict(session_value)) {
		throw state::NotPorted("OverworldLevelRules.terrain_rows: a session that is not a view");
	}
	const DictRef session = session_value.ref;
	const int64_t level = query_level(state, session, requested);
	if (level < 0 || level >= level_count(state, session)) {
		return state.new_array();
	}
	const DictRef overworld = session_view::overworld(state, session);
	if (level == 0) {
		Value map;
		if (!state.lookup(overworld, str(key::map), map)) {
			return state.new_array();
		}
		return ai::typed_array(map, "OverworldLevelRules.terrain_rows");
	}
	// A missing terrain_layers, terrain or levels reads as empty: no rows.
	Value layers_value;
	if (!state.lookup(overworld, str(key::terrain_layers), layers_value)) {
		return state.new_array();
	}
	const DictRef layers = gd::as_dict(layers_value);
	Value terrain;
	if (!state.lookup(layers, str(key::terrain), terrain)) {
		return state.new_array();
	}
	if (!gd::is_dict(terrain)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(terrain) + "'.");
	}
	Value levels_value;
	if (!state.lookup(terrain.ref, str(key::levels), levels_value)) {
		return state.new_array();
	}
	const ArrayRef levels = ai::typed_array(levels_value, "OverworldLevelRules.terrain_rows");
	if (level >= state.array_size(levels)) {
		return state.new_array();
	}
	const Value codes = state.at(levels, level);
	Value ids;
	if (!state.lookup(layers, str(key::terrain_id_by_code), ids)) {
		ids = array_value(state.new_array());
	}
	if (!(gd::is_array(codes) || codes.kind == Kind::PackedInt32) || !(gd::is_array(ids) || ids.kind == Kind::PackedString)) {
		return state.new_array();
	}
	// session.overworld.get("map_size", {}): a missing size is 0 by 0.
	int64_t width = 0;
	int64_t height = 0;
	Value size_value;
	if (state.lookup(overworld, str(key::map_size), size_value)) {
		const DictRef size = gd::as_dict(size_value);
		width = gd::to_int(state, state.get(size, str(key::width), state.get(size, str(key::x), int_value(0))));
		height = gd::to_int(state, state.get(size, str(key::height), state.get(size, str(key::y), int_value(0))));
	}
	if (width <= 0 || height <= 0 || ai::vsize(state, codes) != gd::mul(width, height)) {
		return state.new_array();
	}
	const Atom cache_key = gd::format(state, key::s_d, {str(gd::stringify(state, gd::index(state, session, str(key::session_id)))), int_value(level)});
	const Value size_vector = Value::of_vector2i(static_cast<int32_t>(width), static_cast<int32_t>(height));
	const DictRef cache = ai::static_dict(state, key::overworld_level_rules_script, key::_terrain_rows);
	// _terrain_rows.get(key, {}): a missing entry matches nothing.
	Value cached_value;
	if (state.lookup(cache, str(cache_key), cached_value)) {
		const DictRef cached = gd::as_dict(cached_value);
		if (gd::is_same(state, gd::field(state, cached, key::codes), codes) && gd::is_same(state, gd::field(state, cached, key::ids), ids) && gd::equal(state, gd::field(state, cached, key::size), size_vector)) {
			return ai::typed_array(gd::index(state, cached, str(key::rows)), "OverworldLevelRules.terrain_rows");
		}
	}
	const bool packed_codes = codes.kind == Kind::PackedInt32;
	const bool packed_ids = ids.kind == Kind::PackedString;
	const ArrayRef rows = state.new_array();
	for (int64_t y = 0; y < height; ++y) {
		const ArrayRef row = state.new_array();
		for (int64_t x = 0; x < width; ++x) {
			const int64_t index = y * width + x;
			const int64_t code = packed_codes ? gd::packed_int(state, codes.ref, index) : gd::to_int(state, state.at(codes.ref, index));
			Atom terrain_id = key::rock;
			if (code >= 0 && code < ai::vsize(state, ids)) {
				terrain_id = packed_ids ? gd::packed_string(state, ids.ref, code) : gd::stringify(state, state.at(ids.ref, code));
			}
			state.append(row, str(terrain_id));
		}
		state.append(rows, array_value(row));
	}
	if (state.dict_size(cache) >= 16) {
		dict_clear(state, cache);
	}
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::codes), codes);
	state.set(entry, str(key::ids), ids);
	state.set(entry, str(key::size), size_vector);
	state.set(entry, str(key::rows), array_value(rows));
	state.set(cache, str(cache_key), dict_value(entry));
	return rows;
}

} // namespace overworld_level_rules

} // namespace aurelion::rules::port
