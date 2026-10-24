// TerrainPlacementRules (Phase 7, slice 7.13): the editor's terrain
// placement (the owner queues, the final normalization
// and the visual selection).

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/compat/sort_array.hpp"

#include <algorithm>
#include <cstdint>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace aurelion::rules::port {

namespace {

namespace key = state::key;
using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::Kind;
using state::State;
using state::Value;

// TERRAIN_FAMILIES_BY_ID (TERRAIN_FAMILY_IDS is its index).
constexpr Atom kTerrainFamilies[10] = {
	key::dirt,
	key::sand,
	key::grass,
	key::snow,
	key::swamp,
	key::rough,
	key::subterranean,
	key::lava,
	key::water,
	key::rock,
};
constexpr int64_t kSandId = 1;
constexpr int64_t kDirtId = 0;
constexpr int64_t kRockId = 9;
constexpr int64_t kTraitFlag4[10] = {1, 0, 1, 1, 1, 1, 1, 1, 0, 0};
constexpr int64_t kTraitFlag5[10] = {1, 1, 1, 1, 1, 1, 1, 1, 0, 0};
constexpr int64_t kSpecialTileFreq[10] = {50, 70, 50, 80, 80, 80, 60, 80, 0, 0};
constexpr Vector2i kNeighborOffsets[8] = {{0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}};
constexpr Vector2i kCardinalOffsets[4] = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}};
constexpr Vector2i kDiagonalOffsets[4] = {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}};
constexpr Vector2i kBoundaryAdjacencies[4] = {{1, 0}, {0, 1}, {1, 1}, {-1, 1}};
// FLAG_WORDS: (flag_a, flag_b).
constexpr int64_t kFlagWords[4][2] = {{0, 0}, {0, 1}, {1, 0}, {1, 1}};
constexpr int64_t kOrientationPerms[4][8] = {
	{0, 1, 2, 3, 4, 5, 6, 7},
	{4, 3, 2, 1, 0, 7, 6, 5},
	{0, 7, 6, 5, 4, 3, 2, 1},
	{4, 5, 6, 7, 0, 1, 2, 3},
};
// DIAGONAL_PROBE_OFFSETS and TWO_STEP_PROBE_OFFSETS by "%d,%d" % [flag_a,
// flag_b]: [flag_a][flag_b].
constexpr Vector2i kDiagonalProbeOffsets[2][2][2] = {
	{{{-1, 1}, {1, -1}}, {{-1, -1}, {1, 1}}},
	{{{1, 1}, {-1, -1}}, {{1, -1}, {-1, 1}}},
};
constexpr Vector2i kTwoStepProbeOffsets[2][2] = {{{2, 2}, {2, -2}}, {{-2, 2}, {-2, -2}}};

// Every row list of the tables is a run of frame numbers: a slice of these.
constexpr int64_t kFrameNumbers[80] = {
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
	20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
	40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
	60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
};

} // namespace

namespace terrain_placement_rules {

// A const row list (a table's Array of frame numbers).
struct Rows {
	const int64_t *items = nullptr;
	size_t size = 0;
	bool empty() const { return size == 0; }
};

struct Ring {
	bool items[8] = {false, false, false, false, false, false, false, false};
};

struct Relations {
	int64_t items[8] = {0, 0, 0, 0, 0, 0, 0, 0};
};

struct Projection {
	Atom items[4] = {key::empty, key::empty, key::empty, key::empty};
};

struct Quadrants {
	int64_t items[2] = {0, 0};
};

// _class_result's {"class_code", "flag_a", "flag_b", "reason"}.
struct ClassInfo {
	int64_t class_code = 0;
	int64_t flag_a = 0;
	int64_t flag_b = 0;
	Atom reason = key::empty;
};

// _apply_final_corrections' {"class_code", "correction"}.
struct Corrected {
	int64_t class_code = 0;
	Atom correction = key::empty;
};

// The Dictionary _select_*_visual_frame answers.
struct FrameSelection {
	int64_t frame = 0;
	int64_t output_flag_a = 0;
	int64_t output_flag_b = 0;
	Atom row_group = key::empty;
	Atom row_source = key::empty;
	Atom row_table = key::empty;
	bool fallback = false;
	Atom fallback_reason = key::empty;
};

// _normal_row_entry's answer: null, an Array of rows, or class 0's
// {"ordinary": [...], "special": [...]}.
struct RowEntry {
	enum class Kind : uint8_t { none, rows, full };
	Kind kind = Kind::none;
	Rows rows;
	Rows ordinary;
	Rows special;
};

// _full_rows_for_normal_table's {"rows": [...], "bucket": ...}.
struct FullRows {
	Rows rows;
	Atom bucket = key::empty;
};

// The map the functions read: map_data, map_size and terrain_grammar.
struct Terrain {
	Terrain(ArrayRef map_data_value, Vector2i map_size_value, DictRef terrain_grammar_value, bool cache_cells) :
			map_data(map_data_value), map_size(map_size_value), terrain_grammar(terrain_grammar_value) {
		if (cache_cells && map_size.x > 0 && map_size.y > 0) {
			cells.assign(static_cast<size_t>(map_size.x) * static_cast<size_t>(map_size.y), kUnread);
		}
	}

	static constexpr int8_t kUnread = -2;

	ArrayRef map_data;
	Vector2i map_size;
	DictRef terrain_grammar;
	// terrain_owner_id_for_terrain's answers by terrain id.
	std::vector<std::pair<Atom, int64_t>> owners;
	// Each cell's owner id once read, row by row (kUnread before); empty when
	// the cells are not kept (the visual selection reads a few per call).
	std::vector<int8_t> cells;
};

enum class ChangeList : uint8_t {
	changed = 0,
	direct_changed = 1,
	owner_changed = 2,
};

// OrderedPointSet: the tiles on the map it was made for, each once;
// take_first answers the one with the least y, then the least x.
class OrderedPointSet {
public:
	explicit OrderedPointSet(Vector2i map_size) :
			map_size_(map_size) {}

	int64_t size() const { return static_cast<int64_t>(points_.size()); }
	void add(Vector2i tile) {
		if (tile.x >= 0 && tile.y >= 0 && tile.x < map_size_.x && tile.y < map_size_.y) {
			points_.insert(order(tile));
		}
	}
	void erase(Vector2i tile) { points_.erase(order(tile)); }
	bool has(Vector2i tile) const { return points_.count(order(tile)) != 0; }
	Vector2i take_first() {
		if (points_.empty()) {
			return Vector2i{};
		}
		const uint64_t first = *points_.begin();
		points_.erase(points_.begin());
		return Vector2i{static_cast<int32_t>(static_cast<uint32_t>(first)), static_cast<int32_t>(static_cast<uint32_t>(first >> 32))};
	}

private:
	// y, then x: the scan's order for the tiles it keeps (none off the map).
	static uint64_t order(Vector2i tile) {
		return (static_cast<uint64_t>(static_cast<uint32_t>(tile.y)) << 32) | static_cast<uint64_t>(static_cast<uint32_t>(tile.x));
	}

	Vector2i map_size_;
	std::set<uint64_t> points_;
};

// apply_paint's context Dictionary.
struct Context {
	Context(ArrayRef map_data, Vector2i map_size, DictRef terrain_grammar, Atom brush_terrain_id_value, Atom brush_family_value, int64_t brush_owner_id_value) :
			terrain(map_data, map_size, terrain_grammar, true),
			brush_terrain_id(brush_terrain_id_value),
			brush_family(brush_family_value),
			brush_owner_id(brush_owner_id_value),
			changed_keys(terrain.cells.size(), 0),
			set_a(map_size),
			set_b(map_size) {}

	Tiles &tiles(ChangeList list) {
		switch (list) {
			case ChangeList::direct_changed:
				return direct_changed_tiles;
			case ChangeList::owner_changed:
				return owner_changed_tiles;
			default:
				return changed_tiles;
		}
	}

	Terrain terrain;
	Atom brush_terrain_id;
	Atom brush_family;
	int64_t brush_owner_id;
	Tiles changed_tiles;
	Tiles owner_changed_tiles;
	Tiles direct_changed_tiles;
	// changed_keys, direct_changed_keys and owner_changed_keys: a ChangeList
	// bit per cell, and per tile off the map.
	std::vector<uint8_t> changed_keys;
	std::unordered_map<uint64_t, uint8_t> changed_keys_off_map;
	OrderedPointSet set_a;
	OrderedPointSet set_b;
	bool queue_guard_exhausted = false;
};

} // namespace terrain_placement_rules

namespace {

using terrain_placement_rules::Projection;
using terrain_placement_rules::Rows;
using terrain_placement_rules::Terrain;

void put(State &state, DictRef dict, Atom name, const Value &value) {
	state.set(dict, str(name), value);
}

Rows frame_run(int64_t first, size_t count) {
	return Rows{kFrameNumbers + first, count};
}

// The index of a TERRAIN_FAMILY_IDS key, or -1.
int64_t family_index(Atom family) {
	for (int64_t index = 0; index < 10; ++index) {
		if (kTerrainFamilies[index] == family) {
			return index;
		}
	}
	return -1;
}

// String(x): stringify()'s types, and the engine's str() for the others.
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

// text.to_lower(): ASCII here, any other text by the engine (String::to_lower
// and its Unicode case tables, through an Expression).
Atom to_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	bool changed = false;
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			const Value expression = gd::class_instantiate(state, key::Expression);
			const gd::PackedRef names = gd::new_strings(state);
			gd::packed_append_string(state, names, key::text);
			gd::call_method(state, expression, key::parse, {str(key::text_to_lower), gd::strings_value(names)});
			const ArrayRef inputs = state.new_array();
			state.append(inputs, str(text));
			return gd::to_string(gd::call_method(state, expression, key::execute, {array_value(inputs)}));
		}
		if (byte >= 'A' && byte <= 'Z') {
			c = static_cast<char>(byte - 'A' + 'a');
			changed = true;
		}
	}
	return changed ? state.intern(lowered) : text;
}

bool cell_index(Vector2i map_size, Vector2i tile, size_t &index) {
	if (tile.x < 0 || tile.y < 0 || tile.x >= map_size.x || tile.y >= map_size.y) {
		return false;
	}
	index = static_cast<size_t>(tile.y) * static_cast<size_t>(map_size.x) + static_cast<size_t>(tile.x);
	return true;
}

uint64_t tile_bits(Vector2i tile) {
	return (static_cast<uint64_t>(static_cast<uint32_t>(tile.y)) << 32) | static_cast<uint64_t>(static_cast<uint32_t>(tile.x));
}

// terrain_owner_id_for_terrain(terrain_grammar, terrain_id), kept per id.
int64_t owner_of_terrain(State &state, Terrain &terrain, Atom terrain_id) {
	for (const auto &entry : terrain.owners) {
		if (entry.first == terrain_id) {
			return entry.second;
		}
	}
	const int64_t owner_id = terrain_placement_rules::terrain_owner_id_for_terrain(state, terrain.terrain_grammar, terrain_id);
	terrain.owners.emplace_back(terrain_id, owner_id);
	return owner_id;
}

// A new Array of a projection's four family Strings.
ArrayRef projection_array(State &state, const Projection &projection) {
	const ArrayRef array = state.new_array();
	for (const Atom token : projection.items) {
		state.append(array, str(token));
	}
	return array;
}

// CLASS_TOPOLOGY.get(class_code, "unlabeled recovered class").
Atom class_topology(int64_t class_code) {
	switch (class_code) {
		case 0:
			return key::full_native;
		case 2:
			return key::relation_1_orthogonal_elbow;
		case 3:
			return key::relation_1_west_east_edge;
		case 4:
			return key::relation_1_north_south_edge;
		case 5:
			return key::relation_1_single_diagonal;
		case 6:
			return key::relation_1_corrected_elbow;
		case 7:
			return key::relation_1_corrected_diagonal;
		case 8:
			return key::relation_2_orthogonal_elbow;
		case 9:
			return key::relation_2_west_east_edge;
		case 10:
			return key::relation_2_north_south_edge;
		case 11:
			return key::relation_2_single_diagonal;
		case 12:
			return key::relation_2_corrected_elbow;
		case 13:
			return key::relation_2_corrected_diagonal;
		case 14:
			return key::opposite_diagonal_pair_1_1;
		case 15:
			return key::opposite_diagonal_pair_1_2;
		case 16:
			return key::opposite_diagonal_pair_2_2;
		case 17:
			return key::relation_1_cardinal_with_relation_2;
		case 18:
			return key::relation_1_cardinal_with_relation_2_2;
		case 19:
			return key::relation_1_cardinal_with_relation_2_3;
		case 20:
			return key::relation_1_cardinal_with_relation_2_4;
		case 21:
			return key::relation_2_cardinal_with_relation_1;
		case 22:
			return key::relation_2_cardinal_with_relation_1_2;
		case 23:
			return key::relation_1_compound_corner;
		case 24:
			return key::relation_2_compound_corner;
		case 25:
			return key::relation_1_corner_with_relation_2;
		case 26:
			return key::relation_2_corner_with_relation_1;
		case 27:
			return key::relation_1_corner_with_relation_2_2;
		case 28:
			return key::relation_1_corner_with_two_relation;
		default:
			return key::unlabeled_recovered_class;
	}
}

// "00_%02d" % frame_number.
Atom frame_id_text(State &state, int64_t frame_number) {
	// Godot pads the digits without the sign to the width less the sign.
	const bool negative = frame_number < 0;
	std::string digits = compat::itos(frame_number);
	if (negative) {
		digits.erase(0, 1);
	}
	const size_t width = negative ? 1 : 2;
	if (digits.size() < width) {
		digits.insert(0, width - digits.size(), '0');
	}
	return state.intern(std::string("00_") + (negative ? "-" : "") + digits);
}

// The code points of UTF-8 text, as unicode_at() reads a String.
uint32_t next_code_point(const std::string &text, size_t &index) {
	const unsigned char lead = static_cast<unsigned char>(text[index]);
	size_t length = 1;
	uint32_t code = lead;
	if (lead >= 0xF0 && lead < 0xF8) {
		length = 4;
		code = lead & 0x07u;
	} else if (lead >= 0xE0) {
		length = lead < 0xF0 ? 3 : 1;
		code = length == 3 ? (lead & 0x0Fu) : lead;
	} else if (lead >= 0xC0) {
		length = 2;
		code = lead & 0x1Fu;
	}
	if (length > 1 && index + length <= text.size()) {
		for (size_t offset = 1; offset < length; ++offset) {
			code = (code << 6) | (static_cast<unsigned char>(text[index + offset]) & 0x3Fu);
		}
		index += length;
		return code;
	}
	index += 1;
	return lead;
}

} // namespace

namespace terrain_placement_rules {

DictRef apply_paint(State &state, ArrayRef map_data, Vector2i map_size, Atom brush_terrain_id, ArrayRef paint_tiles, DictRef terrain_grammar, bool include_final_normalization) {
	const Atom brush_family = terrain_family_for_id(state, terrain_grammar, brush_terrain_id);
	const int64_t brush_owner_id = terrain_owner_id_for_family(state, brush_family);
	if (brush_terrain_id == key::empty || brush_owner_id < 0) {
		const DictRef result = state.new_dict();
		put(state, result, key::ok, bool_value(false));
		put(state, result, key::changed, bool_value(false));
		put(state, result, key::message, str(gd::format(state, key::terrain_id_s_is_not_mapped, {str(brush_terrain_id)})));
		put(state, result, key::placement_model, str(key::homm3_owner_queue_rewrite_final_normalization));
		return result;
	}
	if (state.array_size(map_data) == 0 || map_size.x <= 0 || map_size.y <= 0) {
		const DictRef result = state.new_dict();
		put(state, result, key::ok, bool_value(false));
		put(state, result, key::changed, bool_value(false));
		put(state, result, key::message, str(key::terrain_placement_requires_a_loaded_map));
		put(state, result, key::placement_model, str(key::homm3_owner_queue_rewrite_final_normalization));
		return result;
	}

	Context context(map_data, map_size, terrain_grammar, brush_terrain_id, brush_family, brush_owner_id);
	const Tiles requested_tiles = _unique_in_bounds_tiles(state, paint_tiles, map_size);
	const DictRef previous_terrain_by_tile = state.new_dict();
	Tiles changed_owner_cells;

	for (const Vector2i tile : requested_tiles) {
		const Atom previous_terrain = _terrain_at(state, map_data, tile);
		put(state, previous_terrain_by_tile, tile_key(state, tile), str(previous_terrain));
		if (previous_terrain == key::empty) {
			continue;
		}
		const int64_t previous_owner_id = owner_of_terrain(state, context.terrain, previous_terrain);
		if (previous_owner_id != brush_owner_id) {
			_write_brush_terrain(state, tile, context, true, true);
			changed_owner_cells.push_back(tile);
		} else if (previous_terrain != brush_terrain_id) {
			_write_brush_terrain(state, tile, context, true, false);
		}
	}

	_drain_terrain_placement_queues(state, changed_owner_cells, context);
	const DictRef final_payload = include_final_normalization ? final_normalization_payload(state, map_data, map_size, terrain_grammar) : state.new_dict();
	const DictRef result = state.new_dict();
	put(state, result, key::ok, bool_value(true));
	put(state, result, key::changed, bool_value(!context.changed_tiles.empty()));
	put(state, result, key::placement_model, str(key::homm3_owner_queue_rewrite_final_normalization));
	put(state, result, key::paint_order_model, str(key::paint_tiles_in_tool_order_then_drain_set_a_set_b));
	put(state, result, key::queue_model, str(key::rewrite_to_current_brush_4bb74b_then_drain_queues_4bc5f0));
	put(state, result, key::final_normalization_model, str(key::final_normalization_4bbfcc_reclassifies_settled_owner_map));
	put(state, result, key::final_normalization_deferred, bool_value(!include_final_normalization));
	put(state, result, key::brush_terrain_id, str(brush_terrain_id));
	put(state, result, key::brush_family, str(brush_family));
	put(state, result, key::brush_owner_id, int_value(brush_owner_id));
	put(state, result, key::requested_tiles, array_value(tile_array_payload(state, requested_tiles)));
	put(state, result, key::requested_count, int_value(static_cast<int64_t>(requested_tiles.size())));
	put(state, result, key::changed_tiles, array_value(tile_array_payload(state, context.changed_tiles)));
	put(state, result, key::changed_count, int_value(static_cast<int64_t>(context.changed_tiles.size())));
	put(state, result, key::owner_changed_tiles, array_value(tile_array_payload(state, context.owner_changed_tiles)));
	put(state, result, key::owner_changed_count, int_value(static_cast<int64_t>(context.owner_changed_tiles.size())));
	put(state, result, key::direct_changed_tiles, array_value(tile_array_payload(state, context.direct_changed_tiles)));
	put(state, result, key::direct_changed_count, int_value(static_cast<int64_t>(context.direct_changed_tiles.size())));
	put(state, result, key::previous_terrain_by_tile, dict_value(previous_terrain_by_tile));
	put(state, result, key::queue_guard_exhausted, bool_value(context.queue_guard_exhausted));
	put(state, result, key::final_normalization, dict_value(final_payload));
	return result;
}

DictRef final_normalization_payload(State &state, ArrayRef map_data, Vector2i map_size, DictRef terrain_grammar) {
	Terrain terrain(map_data, map_size, terrain_grammar, true);
	const std::vector<int64_t> boundary_counts = _compute_boundary_counts(state, terrain);
	// class_counts by class code, in the order the codes first come.
	std::vector<std::pair<int64_t, int64_t>> class_counts;
	const ArrayRef missing_buckets = state.new_array();
	int64_t boundary_cell_count = 0;
	int64_t correction_count = 0;
	int64_t full_native_count = 0;
	int64_t transition_cell_count = 0;
	for (int64_t y = 0; y < map_size.y; ++y) {
		for (int64_t x = 0; x < map_size.x; ++x) {
			const Vector2i tile = Vector2i::of(x, y);
			const int64_t owner_id = _owner_id_at_raw(state, terrain, tile);
			const int64_t boundary_count = boundary_counts[static_cast<size_t>(y) * static_cast<size_t>(map_size.x) + static_cast<size_t>(x)];
			ClassInfo class_info{0, 0, 0, key::no_classed_relation};
			Atom correction = key::empty;
			if (boundary_count > 0) {
				boundary_cell_count += 1;
				class_info = _classify_relations(state, _relation_ring_for_cell(state, terrain, tile));
				const Corrected corrected = _apply_final_corrections(state, class_info.class_code, terrain, tile, class_info.flag_a, class_info.flag_b);
				correction = corrected.correction;
				class_info.class_code = corrected.class_code;
				if (correction != key::empty) {
					correction_count += 1;
				}
			}
			const int64_t class_code = class_info.class_code;
			bool counted = false;
			for (auto &entry : class_counts) {
				if (entry.first == class_code) {
					entry.second += 1;
					counted = true;
					break;
				}
			}
			if (!counted) {
				class_counts.emplace_back(class_code, 1);
			}
			if (class_code == 0) {
				full_native_count += 1;
			} else {
				transition_cell_count += 1;
			}
			if (!_row_bucket_exists(state, owner_id, class_code)) {
				const DictRef bucket = state.new_dict();
				put(state, bucket, key::tile, dict_value(vector2i_payload(state, tile)));
				put(state, bucket, key::owner_id, int_value(owner_id));
				put(state, bucket, key::owner_family, str(terrain_family_for_id_number(state, owner_id)));
				put(state, bucket, key::class_code, int_value(class_code));
				put(state, bucket, key::boundary_count, int_value(boundary_count));
				put(state, bucket, key::correction, str(correction));
				state.append(missing_buckets, dict_value(bucket));
			}
		}
	}
	const DictRef class_counts_dict = state.new_dict();
	for (const auto &entry : class_counts) {
		put(state, class_counts_dict, state.intern(compat::itos(entry.first)), int_value(entry.second));
	}
	const DictRef result = state.new_dict();
	put(state, result, key::model, str(key::final_normalization_4bbfcc_reclassifies_settled_owner_map));
	put(state, result, key::visited_count, int_value(gd::mul(map_size.x, map_size.y)));
	put(state, result, key::boundary_cell_count, int_value(boundary_cell_count));
	put(state, result, key::full_native_count, int_value(full_native_count));
	put(state, result, key::transition_cell_count, int_value(transition_cell_count));
	put(state, result, key::class_counts, dict_value(class_counts_dict));
	put(state, result, key::correction_count, int_value(correction_count));
	put(state, result, key::missing_bucket_count, int_value(state.array_size(missing_buckets)));
	put(state, result, key::missing_buckets, array_value(missing_buckets));
	put(state, result, key::stale_transition_clear_model, str(key::zero_boundary_cells_use_pick_full_branch_and_clear_flags));
	put(state, result, key::owner_map_source, str(key::settled_after_4bc5f0_queue_drain));
	return result;
}

DictRef visual_selection_payload(State &state, ArrayRef map_data, Vector2i map_size, DictRef terrain_grammar, Vector2i tile) {
	if (state.array_size(map_data) == 0 || !_in_bounds(state, tile, map_size)) {
		return state.new_dict();
	}
	Terrain terrain(map_data, map_size, terrain_grammar, false);
	const Atom terrain_id = _terrain_at(state, map_data, tile);
	const Atom owner_family = terrain_family_for_id(state, terrain_grammar, terrain_id);
	const int64_t owner_id = terrain_owner_id_for_family(state, owner_family);
	if (owner_id < 0) {
		return state.new_dict();
	}
	const int64_t boundary_count = _boundary_count_for_cell(state, terrain, tile);
	const Relations relation_ring = _relation_ring_for_cell(state, terrain, tile);
	const bool direct_water_rock_contact = _has_direct_water_rock_contact(state, terrain, tile);
	const Projection owner_projection = _owner_footprint_projection(state, terrain, tile);
	const Projection material_projection = _contact_material_projection(state, terrain, tile);
	const Projection normalized_projection = _normalized_projection_for_owner(state, owner_family, material_projection);
	ClassInfo class_info{0, 0, 0, key::no_classed_relation};
	Atom correction = key::empty;
	if (boundary_count > 0) {
		class_info = _classify_relations(state, relation_ring);
		const Corrected corrected = _apply_final_corrections(state, class_info.class_code, terrain, tile, class_info.flag_a, class_info.flag_b);
		correction = corrected.correction;
		class_info.class_code = corrected.class_code;
	}
	const int64_t class_code = class_info.class_code;
	const FrameSelection selected = _select_visual_frame(state, owner_id, class_code, class_info.flag_a, class_info.flag_b, tile);
	const int64_t frame_number = selected.frame;
	const bool selected_fallback = selected.fallback;
	const Atom selected_frame_block = _visual_frame_block_for(state, owner_family, frame_number, selected_fallback ? 0 : class_code);
	std::vector<Atom> fallback_reasons;
	if (selected_fallback) {
		fallback_reasons.push_back(selected.fallback_reason);
	}
	if (direct_water_rock_contact) {
		fallback_reasons.push_back(key::explicit_direct_water_rock_contact_kept);
	}
	std::string fallback_reason;
	for (size_t index = 0; index < fallback_reasons.size(); ++index) {
		if (index > 0) {
			fallback_reason += state.text(key::semicolon_space);
		}
		fallback_reason += state.text(fallback_reasons[index]);
	}

	const ArrayRef relation_ring_array = state.new_array();
	for (const int64_t relation : relation_ring.items) {
		state.append(relation_ring_array, int_value(relation));
	}
	const Value owner_projection_value = array_value(projection_array(state, owner_projection));
	const Value material_projection_value = array_value(projection_array(state, material_projection));
	const Value normalized_projection_value = array_value(projection_array(state, normalized_projection));

	const DictRef result = state.new_dict();
	put(state, result, key::ok, bool_value(true));
	put(state, result, key::selection_model, str(key::accepted_web_prototype_relation_class_row));
	put(state, result, key::frame_selection_source, str(key::accepted_web_prototype_and_recovered_h3maped_final_normalization));
	put(state, result, key::final_normalization_model, str(key::final_normalization_4bbfcc_reclassifies_settled_owner_map));
	put(state, result, key::owner_id, int_value(owner_id));
	put(state, result, key::owner_family, str(owner_family));
	put(state, result, key::terrain_id, str(terrain_id));
	put(state, result, key::shape_class, int_value(class_code));
	put(state, result, key::class_topology, str(class_topology(class_code)));
	put(state, result, key::class_reason, str(class_info.reason));
	put(state, result, key::correction, str(correction));
	put(state, result, key::boundary_count, int_value(boundary_count));
	put(state, result, key::relation_ring, array_value(relation_ring_array));
	put(state, result, key::relation_grid, str(relation_grid_string(state, relation_ring)));
	put(state, result, key::projection_model, str(key::accepted_web_prototype_cardinal_material_projection));
	put(state, result, key::raw_quadrants, owner_projection_value);
	put(state, result, key::owner_footprint_quadrants, owner_projection_value);
	put(state, result, key::material_quadrants, material_projection_value);
	put(state, result, key::count_quadrants, normalized_projection_value);
	put(state, result, key::normalized_quadrants, normalized_projection_value);
	put(state, result, key::visual_quadrants, material_projection_value);
	put(state, result, key::display_quadrants, material_projection_value);
	put(state, result, key::row_group, str(selected.row_group));
	put(state, result, key::row_source, str(selected.row_source));
	put(state, result, key::row_table, str(selected.row_table));
	put(state, result, key::frame_number, int_value(frame_number));
	put(state, result, key::frame_id, str(frame_id_text(state, frame_number)));
	put(state, result, key::requested_flag_a, int_value(class_info.flag_a));
	put(state, result, key::requested_flag_b, int_value(class_info.flag_b));
	put(state, result, key::flag_a, int_value(selected.output_flag_a));
	put(state, result, key::flag_b, int_value(selected.output_flag_b));
	put(state, result, key::flip_h, bool_value(selected.output_flag_a == 1));
	put(state, result, key::flip_v, bool_value(selected.output_flag_b == 1));
	put(state, result, key::fallback, bool_value(selected.fallback || direct_water_rock_contact));
	put(state, result, key::fallback_reason, str(state.intern(fallback_reason)));
	put(state, result, key::direct_water_rock_contact, bool_value(direct_water_rock_contact));
	put(state, result, key::bridge_family, str(_bridge_family_from_relations(state, relation_ring)));
	put(state, result, key::selected_frame_block, str(selected_frame_block));
	return result;
}

Atom terrain_family_for_id(State &state, DictRef terrain_grammar, Atom terrain_id) {
	const Atom normalized = to_lower(state, gd::strip_edges(state, terrain_id));
	// A missing homm3_local_prototype, terrain_id_map, mapping or family reads
	// as {} or "": no family from the grammar.
	Value homm3;
	Value terrain_id_map;
	Value mapping;
	Value family_value;
	if (state.lookup(terrain_grammar, str(key::homm3_local_prototype), homm3) && homm3.kind == Kind::Dict
			&& state.lookup(homm3.ref, str(key::terrain_id_map), terrain_id_map) && terrain_id_map.kind == Kind::Dict
			&& state.lookup(terrain_id_map.ref, str(normalized), mapping) && mapping.kind == Kind::Dict
			&& state.lookup(mapping.ref, str(key::family), family_value)) {
		const Atom family = gd::strip_edges(state, string_of(state, family_value));
		if (family != key::empty) {
			return family;
		}
	}
	if (family_index(normalized) >= 0) {
		return normalized;
	}
	return key::empty;
}

int64_t terrain_owner_id_for_terrain(State &state, DictRef terrain_grammar, Atom terrain_id) {
	return terrain_owner_id_for_family(state, terrain_family_for_id(state, terrain_grammar, terrain_id));
}

int64_t terrain_owner_id_for_family(State &state, Atom family_id) {
	// A key is its own strip_edges().to_lower().
	const int64_t index = family_index(family_id);
	if (index >= 0) {
		return index;
	}
	return family_index(to_lower(state, gd::strip_edges(state, family_id)));
}

Atom terrain_family_for_id_number(State &state, int64_t owner_id) {
	(void)state;
	if (owner_id >= 0 && owner_id < 10) {
		return kTerrainFamilies[owner_id];
	}
	return key::empty;
}

Atom tile_key(State &state, Vector2i tile) {
	return state.pair_atom(tile.x, tile.y);
}

DictRef vector2i_payload(State &state, Vector2i tile) {
	const DictRef payload = state.new_dict();
	put(state, payload, key::x, int_value(tile.x));
	put(state, payload, key::y, int_value(tile.y));
	return payload;
}

ArrayRef tile_array_payload(State &state, const Tiles &tiles) {
	const ArrayRef payload = state.new_array();
	for (const Vector2i tile : tiles) {
		state.append(payload, dict_value(vector2i_payload(state, tile)));
	}
	return payload;
}

Tiles _unique_in_bounds_tiles(State &state, ArrayRef tiles, Vector2i map_size) {
	Tiles result;
	// seen, by cell (the tiles kept are on the map).
	std::vector<uint8_t> seen;
	for (const Value &tile_value : gd::items(state, array_value(tiles))) {
		if (tile_value.kind != Kind::Vector2i) {
			continue;
		}
		const Vector2i tile{tile_value.vx(), tile_value.vy()};
		size_t index = 0;
		if (!_in_bounds(state, tile, map_size) || !cell_index(map_size, tile, index)) {
			continue;
		}
		if (seen.empty()) {
			seen.assign(static_cast<size_t>(map_size.x) * static_cast<size_t>(map_size.y), 0);
		}
		if (seen[index] != 0) {
			continue;
		}
		seen[index] = 1;
		result.push_back(tile);
	}
	return result;
}

bool _in_bounds(State &state, Vector2i tile, Vector2i map_size) {
	(void)state;
	return tile.x >= 0 && tile.y >= 0 && tile.x < map_size.x && tile.y < map_size.y;
}

Atom _terrain_at(State &state, ArrayRef map_data, Vector2i tile) {
	if (tile.y < 0 || tile.y >= state.array_size(map_data)) {
		return key::empty;
	}
	const Value row = state.at(map_data, tile.y);
	if (row.kind != Kind::Array || tile.x < 0 || tile.x >= state.array_size(row.ref)) {
		return key::empty;
	}
	return string_of(state, state.at(row.ref, tile.x));
}

void _set_terrain_at(State &state, Terrain &terrain, Vector2i tile, Atom terrain_id) {
	const Value row = state.at(terrain.map_data, tile.y);
	if (row.kind == Kind::Array && tile.x >= 0 && tile.x < state.array_size(row.ref)) {
		state.set_at(row.ref, tile.x, str(terrain_id));
		state.set_at(terrain.map_data, tile.y, row);
		// A row may stand in map_data more than once: its column is read again.
		if (!terrain.cells.empty() && tile.x < terrain.map_size.x) {
			for (int32_t y = 0; y < terrain.map_size.y; ++y) {
				terrain.cells[static_cast<size_t>(y) * static_cast<size_t>(terrain.map_size.x) + static_cast<size_t>(tile.x)] = Terrain::kUnread;
			}
		}
	}
}

int64_t _owner_id_at_raw(State &state, Terrain &terrain, Vector2i tile) {
	size_t index = 0;
	if (!terrain.cells.empty() && cell_index(terrain.map_size, tile, index)) {
		if (terrain.cells[index] == Terrain::kUnread) {
			const int64_t owner_id = owner_of_terrain(state, terrain, _terrain_at(state, terrain.map_data, tile));
			terrain.cells[index] = static_cast<int8_t>(owner_id);
			return owner_id;
		}
		return terrain.cells[index];
	}
	return owner_of_terrain(state, terrain, _terrain_at(state, terrain.map_data, tile));
}

int64_t _owner_id_at(State &state, Terrain &terrain, Vector2i tile) {
	const Vector2i clamped = Vector2i::of(
			compat::engine_clamp<int64_t>(tile.x, 0, static_cast<int64_t>(terrain.map_size.x) - 1),
			compat::engine_clamp<int64_t>(tile.y, 0, static_cast<int64_t>(terrain.map_size.y) - 1));
	return _owner_id_at_raw(state, terrain, clamped);
}

bool _write_brush_terrain(State &state, Vector2i tile, Context &context, bool direct_write, bool owner_write) {
	const Atom current = _terrain_at(state, context.terrain.map_data, tile);
	if (current == context.brush_terrain_id) {
		return false;
	}
	_set_terrain_at(state, context.terrain, tile, context.brush_terrain_id);
	_mark_changed(state, tile, context, ChangeList::changed);
	if (direct_write) {
		_mark_changed(state, tile, context, ChangeList::direct_changed);
	}
	if (owner_write) {
		_mark_changed(state, tile, context, ChangeList::owner_changed);
	}
	return true;
}

void _mark_changed(State &state, Vector2i tile, Context &context, ChangeList list) {
	(void)state;
	const uint8_t bit = static_cast<uint8_t>(1u << static_cast<uint8_t>(list));
	size_t index = 0;
	if (!context.changed_keys.empty() && cell_index(context.terrain.map_size, tile, index)) {
		if ((context.changed_keys[index] & bit) != 0) {
			return;
		}
		context.changed_keys[index] = static_cast<uint8_t>(context.changed_keys[index] | bit);
	} else {
		uint8_t &marks = context.changed_keys_off_map[tile_bits(tile)];
		if ((marks & bit) != 0) {
			return;
		}
		marks = static_cast<uint8_t>(marks | bit);
	}
	context.tiles(list).push_back(tile);
}

void _drain_terrain_placement_queues(State &state, const Tiles &changed_owner_cells, Context &context) {
	for (const Vector2i tile : changed_owner_cells) {
		_rewrite_to_current_brush(state, tile, context, true);
	}
	const Vector2i map_size = context.terrain.map_size;
	int64_t guard = gd::mul(gd::mul(map_size.x, map_size.y), 128);
	while (guard > 0) {
		while (context.set_a.size() > 0 && guard > 0) {
			guard -= 1;
			_process_frontier_point(state, context.set_a.take_first(), context);
		}
		while (context.set_b.size() > 0 && guard > 0) {
			guard -= 1;
			const Vector2i tile = context.set_b.take_first();
			if (_should_rewrite_topology_point(state, tile, context)) {
				_rewrite_to_current_brush(state, tile, context, false);
			}
		}
		if (context.set_a.size() == 0) {
			break;
		}
	}
	if (guard == 0) {
		context.queue_guard_exhausted = true;
	}
}

bool _rewrite_to_current_brush(State &state, Vector2i tile, Context &context, bool already_written) {
	if (!_in_bounds(state, tile, context.terrain.map_size)) {
		return false;
	}
	const int64_t brush_owner_id = context.brush_owner_id;
	if (_owner_id_at_raw(state, context.terrain, tile) == brush_owner_id && !already_written) {
		return false;
	}
	if (_owner_id_at_raw(state, context.terrain, tile) != brush_owner_id) {
		_write_brush_terrain(state, tile, context, false, true);
	}

	context.set_b.erase(tile);
	if (_trait_flag5(state, brush_owner_id) != 0) {
		_maintain_normal_neighbor_frontier(state, tile, context);
	} else {
		_maintain_special_neighbor_frontier(state, tile, context);
	}
	if (_should_rewrite_topology_point(state, tile, context)) {
		context.set_a.add(tile);
	} else {
		_enqueue_secondary_candidates(state, tile, context);
	}
	return true;
}

void _maintain_normal_neighbor_frontier(State &state, Vector2i tile, Context &context) {
	for (const Vector2i neighbor : {tile + Vector2i{0, -1}, tile + Vector2i{0, 1}}) {
		if (context.set_a.has(neighbor) && !_is_horizontally_thin(state, neighbor, context)) {
			context.set_a.erase(neighbor);
			_enqueue_secondary_candidates(state, neighbor, context);
		}
	}
	for (const Vector2i neighbor : {tile + Vector2i{-1, 0}, tile + Vector2i{1, 0}}) {
		if (context.set_a.has(neighbor) && !_is_vertically_thin(state, neighbor, context)) {
			context.set_a.erase(neighbor);
			_enqueue_secondary_candidates(state, neighbor, context);
		}
	}
}

void _maintain_special_neighbor_frontier(State &state, Vector2i tile, Context &context) {
	const int64_t brush_owner_id = context.brush_owner_id;
	const Vector2i map_size = context.terrain.map_size;
	for (const Vector2i offset : kNeighborOffsets) {
		const Vector2i neighbor = tile + offset;
		if (!_in_bounds(state, neighbor, map_size) || _owner_id_at_raw(state, context.terrain, neighbor) != brush_owner_id) {
			continue;
		}
		const bool in_set_a = context.set_a.has(neighbor);
		const bool should_rewrite = _should_rewrite_topology_point(state, neighbor, context);
		if (in_set_a && !should_rewrite) {
			context.set_a.erase(neighbor);
			_enqueue_secondary_candidates(state, neighbor, context);
		} else if (!in_set_a && should_rewrite) {
			context.set_a.add(neighbor);
		}
	}
}

void _enqueue_secondary_candidates(State &state, Vector2i tile, Context &context) {
	const int64_t brush_owner_id = context.brush_owner_id;
	const Vector2i map_size = context.terrain.map_size;
	for (const Vector2i offset : kCardinalOffsets) {
		const Vector2i neighbor = tile + offset;
		if (_in_bounds(state, neighbor, map_size) && _owner_id_at_raw(state, context.terrain, neighbor) != brush_owner_id) {
			context.set_b.add(neighbor);
		}
	}
	for (const Vector2i offset : kDiagonalOffsets) {
		const Vector2i neighbor = tile + offset;
		if (!_in_bounds(state, neighbor, map_size)) {
			continue;
		}
		const int64_t neighbor_owner_id = _owner_id_at_raw(state, context.terrain, neighbor);
		if (neighbor_owner_id != brush_owner_id && _trait_flag5(state, neighbor_owner_id) == 0) {
			context.set_b.add(neighbor);
		}
	}
}

void _process_frontier_point(State &state, Vector2i tile, Context &context) {
	const int64_t brush_owner_id = context.brush_owner_id;
	if (!_in_bounds(state, tile, context.terrain.map_size) || _owner_id_at_raw(state, context.terrain, tile) != brush_owner_id) {
		return;
	}
	if (_is_vertically_thin(state, tile, context)) {
		_rewrite_to_current_brush(state, _choose_vertical_frontier_target(state, tile, brush_owner_id, context), context, false);
	}
	if (_is_horizontally_thin(state, tile, context)) {
		_rewrite_to_current_brush(state, _choose_horizontal_frontier_target(state, tile, brush_owner_id, context), context, false);
	}
	if (_trait_flag5(state, brush_owner_id) != 0 || !_fragmented_same_owner_ring(state, tile, brush_owner_id, context)) {
		return;
	}
	for (const int64_t slot : _minimum_fragmented_gap(state, tile, brush_owner_id, context)) {
		_rewrite_to_current_brush(state, tile + kNeighborOffsets[slot], context, false);
	}
}

Vector2i _choose_vertical_frontier_target(State &state, Vector2i tile, int64_t brush_owner_id, Context &context) {
	const Vector2i north = tile + Vector2i{0, -1};
	const Vector2i south = tile + Vector2i{0, 1};
	if (_should_rewrite_topology_point(state, north, context)) {
		return north;
	}
	if (_should_rewrite_topology_point(state, south, context)) {
		return south;
	}
	if (!_is_horizontally_thin_for_owner(state, north, brush_owner_id, context)) {
		return north;
	}
	if (_is_horizontally_thin_for_owner(state, south, brush_owner_id, context)) {
		return north;
	}
	return south;
}

Vector2i _choose_horizontal_frontier_target(State &state, Vector2i tile, int64_t brush_owner_id, Context &context) {
	const Vector2i west = tile + Vector2i{-1, 0};
	const Vector2i east = tile + Vector2i{1, 0};
	if (_should_rewrite_topology_point(state, west, context)) {
		return west;
	}
	if (_should_rewrite_topology_point(state, east, context)) {
		return east;
	}
	if (!_is_vertically_thin_for_owner(state, west, brush_owner_id, context)) {
		return west;
	}
	if (_is_vertically_thin_for_owner(state, east, brush_owner_id, context)) {
		return west;
	}
	return east;
}

bool _should_rewrite_topology_point(State &state, Vector2i tile, Context &context) {
	if (!_in_bounds(state, tile, context.terrain.map_size)) {
		return false;
	}
	const int64_t owner_id = _owner_id_at_raw(state, context.terrain, tile);
	if (owner_id < 0) {
		return false;
	}
	if (_is_horizontally_thin_for_owner(state, tile, owner_id, context) || _is_vertically_thin_for_owner(state, tile, owner_id, context)) {
		return true;
	}
	return _trait_flag5(state, owner_id) == 0 && _fragmented_same_owner_ring(state, tile, owner_id, context);
}

bool _is_horizontally_thin(State &state, Vector2i tile, Context &context) {
	const int64_t owner_id = _owner_id_at_raw(state, context.terrain, tile);
	return _is_horizontally_thin_for_owner(state, tile, owner_id, context);
}

bool _is_vertically_thin(State &state, Vector2i tile, Context &context) {
	const int64_t owner_id = _owner_id_at_raw(state, context.terrain, tile);
	return _is_vertically_thin_for_owner(state, tile, owner_id, context);
}

bool _is_horizontally_thin_for_owner(State &state, Vector2i tile, int64_t owner_id, Context &context) {
	const Vector2i map_size = context.terrain.map_size;
	if (tile.x <= 0 || tile.x >= static_cast<int64_t>(map_size.x) - 1 || tile.y < 0 || tile.y >= map_size.y) {
		return false;
	}
	return _owner_id_at_raw(state, context.terrain, tile + Vector2i{-1, 0}) != owner_id && _owner_id_at_raw(state, context.terrain, tile + Vector2i{1, 0}) != owner_id;
}

bool _is_vertically_thin_for_owner(State &state, Vector2i tile, int64_t owner_id, Context &context) {
	const Vector2i map_size = context.terrain.map_size;
	if (tile.y <= 0 || tile.y >= static_cast<int64_t>(map_size.y) - 1 || tile.x < 0 || tile.x >= map_size.x) {
		return false;
	}
	return _owner_id_at_raw(state, context.terrain, tile + Vector2i{0, -1}) != owner_id && _owner_id_at_raw(state, context.terrain, tile + Vector2i{0, 1}) != owner_id;
}

std::vector<int64_t> _minimum_fragmented_gap(State &state, Vector2i tile, int64_t owner_id, Context &context) {
	const Ring same = _same_owner_ring(state, tile, owner_id, context);
	if (_ring_component_count(state, same) <= 1) {
		return {};
	}
	int64_t first_true = -1;
	for (int64_t index = 0; index < 8; ++index) {
		if (same.items[index]) {
			first_true = index;
			break;
		}
	}
	if (first_true < 0) {
		return {};
	}
	std::vector<std::vector<int64_t>> runs;
	int64_t cursor = (first_true + 1) & 7;
	while (cursor != first_true) {
		if (same.items[cursor]) {
			cursor = (cursor + 1) & 7;
			continue;
		}
		std::vector<int64_t> slots;
		while (!same.items[cursor]) {
			slots.push_back(cursor);
			cursor = (cursor + 1) & 7;
			if (cursor == first_true) {
				break;
			}
		}
		runs.push_back(std::move(slots));
	}
	if (runs.empty()) {
		return {};
	}
	compat::sort_custom(runs.data(), static_cast<int64_t>(runs.size()), [&state](const std::vector<int64_t> &a, const std::vector<int64_t> &b) {
		return _gap_weight(state, a) < _gap_weight(state, b);
	});
	return runs[0];
}

bool _fragmented_same_owner_ring(State &state, Vector2i tile, int64_t owner_id, Context &context) {
	return _ring_component_count(state, _same_owner_ring(state, tile, owner_id, context)) > 1;
}

Ring _same_owner_ring(State &state, Vector2i tile, int64_t owner_id, Context &context) {
	const Vector2i map_size = context.terrain.map_size;
	Terrain &terrain = context.terrain;
	const int64_t left = tile.x > 0 ? static_cast<int64_t>(tile.x) - 1 : tile.x;
	const int64_t right = tile.x < static_cast<int64_t>(map_size.x) - 1 ? static_cast<int64_t>(tile.x) + 1 : tile.x;
	const int64_t top = tile.y > 0 ? static_cast<int64_t>(tile.y) - 1 : tile.y;
	const int64_t bottom = tile.y < static_cast<int64_t>(map_size.y) - 1 ? static_cast<int64_t>(tile.y) + 1 : tile.y;
	Ring raw;
	bool *items = raw.items;
	items[0] = _owner_id_at_raw(state, terrain, Vector2i::of(tile.x, top)) == owner_id;
	items[2] = _owner_id_at_raw(state, terrain, Vector2i::of(right, tile.y)) == owner_id;
	items[4] = _owner_id_at_raw(state, terrain, Vector2i::of(tile.x, bottom)) == owner_id;
	items[6] = _owner_id_at_raw(state, terrain, Vector2i::of(left, tile.y)) == owner_id;
	items[1] = (items[0] || items[2]) && _owner_id_at_raw(state, terrain, Vector2i::of(right, top)) == owner_id;
	items[3] = (items[2] || items[4]) && _owner_id_at_raw(state, terrain, Vector2i::of(right, bottom)) == owner_id;
	items[5] = (items[4] || items[6]) && _owner_id_at_raw(state, terrain, Vector2i::of(left, bottom)) == owner_id;
	items[7] = (items[6] || items[0]) && _owner_id_at_raw(state, terrain, Vector2i::of(left, top)) == owner_id;
	return raw;
}

int64_t _ring_component_count(State &state, const Ring &values) {
	(void)state;
	int64_t components = 0;
	for (int64_t index = 0; index < 8; ++index) {
		const bool previous = values.items[(index + 8 - 1) % 8];
		if (values.items[index] && !previous) {
			components += 1;
		}
	}
	return components;
}

int64_t _gap_weight(State &state, const std::vector<int64_t> &slots) {
	(void)state;
	int64_t weight = 0;
	for (const int64_t slot : slots) {
		weight += slot % 2 == 0 ? 2 : 1;
	}
	return weight;
}

std::vector<int64_t> _compute_boundary_counts(State &state, Terrain &terrain) {
	const Vector2i map_size = terrain.map_size;
	std::vector<int64_t> counts;
	if (map_size.x > 0 && map_size.y > 0) {
		counts.assign(static_cast<size_t>(map_size.x) * static_cast<size_t>(map_size.y), 0);
	}
	for (int32_t y = 0; y < map_size.y; ++y) {
		for (int32_t x = 0; x < map_size.x; ++x) {
			const Vector2i tile{x, y};
			const int64_t owner_id = _owner_id_at_raw(state, terrain, tile);
			for (const Vector2i offset : kBoundaryAdjacencies) {
				const Vector2i neighbor = tile + offset;
				if (!_in_bounds(state, neighbor, map_size)) {
					continue;
				}
				if (_owner_id_at_raw(state, terrain, neighbor) != owner_id) {
					counts[static_cast<size_t>(y) * static_cast<size_t>(map_size.x) + static_cast<size_t>(x)] += 1;
					counts[static_cast<size_t>(neighbor.y) * static_cast<size_t>(map_size.x) + static_cast<size_t>(neighbor.x)] += 1;
				}
			}
		}
	}
	return counts;
}

int64_t _boundary_count_for_cell(State &state, Terrain &terrain, Vector2i tile) {
	if (!_in_bounds(state, tile, terrain.map_size)) {
		return 0;
	}
	const int64_t owner_id = _owner_id_at_raw(state, terrain, tile);
	int64_t count = 0;
	for (const Vector2i offset : kNeighborOffsets) {
		const Vector2i neighbor = tile + offset;
		if (_in_bounds(state, neighbor, terrain.map_size) && _owner_id_at_raw(state, terrain, neighbor) != owner_id) {
			count += 1;
		}
	}
	return count;
}

int64_t _relation_between_ids(State &state, int64_t center_id, int64_t neighbor_id) {
	if (center_id < 0 || neighbor_id < 0) {
		return 0;
	}
	if (center_id == neighbor_id) {
		return 0;
	}
	if (center_id == kSandId) {
		return 0;
	}
	if (_trait_flag4(state, center_id) == 0) {
		return 2;
	}
	if (_trait_flag4(state, neighbor_id) == 0) {
		return 2;
	}
	return center_id != kDirtId ? 1 : 0;
}

Relations _relation_ring_for_cell(State &state, Terrain &terrain, Vector2i tile) {
	const int64_t center_id = _owner_id_at(state, terrain, tile);
	Relations relations;
	for (size_t index = 0; index < 8; ++index) {
		relations.items[index] = _relation_between_ids(state, center_id, _owner_id_at(state, terrain, tile + kNeighborOffsets[index]));
	}
	return relations;
}

bool _has_direct_water_rock_contact(State &state, Terrain &terrain, Vector2i tile) {
	const Atom owner_family = terrain_family_for_id_number(state, _owner_id_at_raw(state, terrain, tile));
	if (owner_family != key::water && owner_family != key::rock) {
		return false;
	}
	const Atom contact_family = owner_family == key::water ? key::rock : key::water;
	const int64_t contact_id = terrain_owner_id_for_family(state, contact_family);
	for (const Vector2i offset : kNeighborOffsets) {
		if (_owner_id_at(state, terrain, tile + offset) == contact_id) {
			return true;
		}
	}
	return false;
}

namespace {

// CARDINAL_PROJECTION_EDGES.
struct ProjectionEdge {
	Vector2i offset;
	Quadrants quadrants;
};
const ProjectionEdge kCardinalProjectionEdges[4] = {
	{{0, -1}, {{0, 1}}},
	{{1, 0}, {{1, 3}}},
	{{0, 1}, {{2, 3}}},
	{{-1, 0}, {{0, 2}}},
};

// owner_family in FULL_LAND_FAMILIES.
bool is_full_land_family(Atom family) {
	return family == key::grass || family == key::snow || family == key::swamp || family == key::rough || family == key::subterranean || family == key::lava;
}

} // namespace

Projection _owner_footprint_projection(State &state, Terrain &terrain, Vector2i tile) {
	const Atom owner_family = terrain_family_for_id_number(state, _owner_id_at(state, terrain, tile));
	Projection projection;
	for (Atom &token : projection.items) {
		token = owner_family;
	}
	for (const ProjectionEdge &edge : kCardinalProjectionEdges) {
		const Atom neighbor_family = terrain_family_for_id_number(state, _owner_id_at(state, terrain, tile + edge.offset));
		if (neighbor_family != key::empty && neighbor_family != owner_family) {
			_apply_edge_projection(state, projection, edge.quadrants, owner_family, neighbor_family);
		}
	}
	return projection;
}

Projection _contact_material_projection(State &state, Terrain &terrain, Vector2i tile) {
	const Atom owner_family = terrain_family_for_id_number(state, _owner_id_at(state, terrain, tile));
	const int64_t owner_id = terrain_owner_id_for_family(state, owner_family);
	Projection projection;
	for (Atom &token : projection.items) {
		token = owner_family;
	}
	for (const ProjectionEdge &edge : kCardinalProjectionEdges) {
		const Atom neighbor_family = terrain_family_for_id_number(state, _owner_id_at(state, terrain, tile + edge.offset));
		const int64_t neighbor_id = terrain_owner_id_for_family(state, neighbor_family);
		const Atom material = _contact_material_for_relation(state, owner_family, neighbor_family, _relation_between_ids(state, owner_id, neighbor_id));
		if (material != key::empty) {
			_apply_edge_projection(state, projection, edge.quadrants, owner_family, material);
		}
	}
	return projection;
}

Atom _contact_material_for_relation(State &state, Atom owner_family, Atom neighbor_family, int64_t relation) {
	(void)state;
	if (relation == 0) {
		return key::empty;
	}
	if (owner_family == key::water) {
		return neighbor_family == key::rock ? key::rock : key::land;
	}
	if (owner_family == key::rock) {
		return neighbor_family == key::water ? key::water : key::sand;
	}
	if (owner_family == key::dirt) {
		return key::sand;
	}
	if (is_full_land_family(owner_family)) {
		return relation == 1 ? key::dirt : key::sand;
	}
	return key::empty;
}

Projection _normalized_projection_for_owner(State &state, Atom owner_family, const Projection &projection) {
	(void)state;
	Projection normalized;
	for (size_t index = 0; index < 4; ++index) {
		const Atom token = projection.items[index];
		if (owner_family == key::water) {
			normalized.items[index] = token == key::water ? key::water : key::land;
		} else if (owner_family == key::rock) {
			normalized.items[index] = token == key::rock ? key::rock : key::sand;
		} else if (is_full_land_family(owner_family)) {
			normalized.items[index] = token == owner_family ? key::native : token;
		} else {
			normalized.items[index] = token;
		}
	}
	return normalized;
}

void _apply_edge_projection(State &state, Projection &projection, const Quadrants &quadrants, Atom owner_family, Atom material) {
	for (const int64_t quadrant : quadrants.items) {
		if (quadrant < 0 || quadrant >= 4) {
			continue;
		}
		projection.items[quadrant] = _merge_projected_material(state, owner_family, projection.items[quadrant], material);
	}
}

Atom _merge_projected_material(State &state, Atom owner_family, Atom current, Atom incoming) {
	(void)state;
	if (current == owner_family || current == incoming) {
		return incoming;
	}
	return key::mixed;
}

ClassInfo _classify_relations(State &state, const Relations &relations) {
	const auto at = [&state, &relations](int64_t flag_a, int64_t flag_b, int64_t slot) {
		return _relation_at(state, relations, flag_a, flag_b, slot);
	};
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 2) == 1 && at(a, b, 4) == 1) {
			if (at(a, b, 1) == 2 && at(a, b, 5) == 2) {
				return _class_result(state, 28, a, b, key::e_1_s_1_ne_2);
			}
			if (at(a, b, 3) == 2) {
				return _class_result(state, 27, a, b, key::e_1_s_1_se_2);
			}
		}
	}
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 0) == 1 && at(a, b, 6) == 1 && at(a, b, 3) != 0) {
			return _class_result(state, at(a, b, 3) == 1 ? 23 : 25, a, b, key::n_1_w_1_se_0);
		}
		if (at(a, b, 0) == 2 && at(a, b, 6) == 2 && at(a, b, 3) != 0) {
			return _class_result(state, at(a, b, 3) == 1 ? 26 : 24, a, b, key::n_2_w_2_se_0);
		}
	}
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 2) == 2 && at(a, b, 4) == 1 && at(a, b, 5) == 2) {
			return _class_result(state, 8, 1 - a, 1 - b, key::e_2_s_1_sw_2);
		}
		if (at(a, b, 2) == 1 && at(a, b, 4) == 2 && at(a, b, 1) == 2) {
			return _class_result(state, 8, 1 - a, 1 - b, key::e_1_s_2_ne_2);
		}
	}
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 2) == 1 && at(a, b, 4) == 1) {
			if (at(a, b, 5) == 2) {
				return _class_result(state, 17, a, b, key::e_1_s_1_sw_2);
			}
			if (at(a, b, 1) == 2) {
				return _class_result(state, 18, a, b, key::e_1_s_1_ne_2_2);
			}
		}
	}
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 0) == 1 && at(a, b, 6) == 1) {
			return _class_result(state, 2, a, b, key::n_1_w_1);
		}
		if (at(a, b, 0) == 2 && at(a, b, 6) == 2) {
			return _class_result(state, 8, a, b, key::n_2_w_2);
		}
		if (at(a, b, 2) == 1 && at(a, b, 5) == 2) {
			return _class_result(state, 17, a, b, key::e_1_sw_2);
		}
		if (at(a, b, 4) == 1 && at(a, b, 1) == 2) {
			return _class_result(state, 18, a, b, key::s_1_ne_2);
		}
		if (at(a, b, 2) == 2 && at(a, b, 5) == 1) {
			return _class_result(state, 21, a, b, key::e_2_sw_1);
		}
		if (at(a, b, 4) == 2 && at(a, b, 1) == 1) {
			return _class_result(state, 22, a, b, key::s_2_ne_1);
		}
		if (at(a, b, 6) == 1 && at(a, b, 1) == 1) {
			return _class_result(state, 2, a, b, key::w_1_ne_1);
		}
		if (at(a, b, 0) == 1 && at(a, b, 5) == 1) {
			return _class_result(state, 2, a, b, key::n_1_sw_1);
		}
		if (at(a, b, 6) == 2 && at(a, b, 1) == 2) {
			return _class_result(state, 8, a, b, key::w_2_ne_2);
		}
		if (at(a, b, 0) == 2 && at(a, b, 5) == 2) {
			return _class_result(state, 8, a, b, key::n_2_sw_2);
		}
	}
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 2) == 1 && at(a, b, 3) == 2) {
			return _class_result(state, 19, a, b, key::e_1_se_2);
		}
		if (at(a, b, 4) == 1 && at(a, b, 3) == 2) {
			return _class_result(state, 20, a, b, key::s_1_se_2);
		}
	}
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 0) == 1) {
			return _class_result(state, 4, a, b, key::n_1);
		}
		if (at(a, b, 0) == 2) {
			return _class_result(state, 10, a, b, key::n_2);
		}
		if (at(a, b, 6) == 1) {
			return _class_result(state, 3, a, b, key::w_1);
		}
		if (at(a, b, 6) == 2) {
			return _class_result(state, 9, a, b, key::w_2);
		}
	}
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 7) == 1 && at(a, b, 3) == 1) {
			return _class_result(state, 14, a, b, key::nw_1_se_1);
		}
		if (at(a, b, 7) == 1 && at(a, b, 3) == 2) {
			return _class_result(state, 15, a, b, key::nw_1_se_2);
		}
		if (at(a, b, 7) == 2 && at(a, b, 3) == 2) {
			return _class_result(state, 16, a, b, key::nw_2_se_2);
		}
	}
	for (const auto &flags : kFlagWords) {
		const int64_t a = flags[0];
		const int64_t b = flags[1];
		if (at(a, b, 3) == 1) {
			return _class_result(state, 5, a, b, key::se_1);
		}
		if (at(a, b, 3) == 2) {
			return _class_result(state, 11, a, b, key::se_2);
		}
	}
	return _class_result(state, 0, 0, 0, key::no_classed_relation);
}

ClassInfo _class_result(State &state, int64_t class_code, int64_t flag_a, int64_t flag_b, Atom reason) {
	(void)state;
	return ClassInfo{class_code, flag_a, flag_b, reason};
}

int64_t _relation_at(State &state, const Relations &relations, int64_t flag_a, int64_t flag_b, int64_t slot) {
	(void)state;
	// ORIENTATION_PERMS[flag_b + flag_a * 2][slot], then relations[...]: Array
	// indices, negative from the end.
	int64_t perm_index = flag_b + flag_a * 2;
	if (perm_index < 0) {
		perm_index += 4;
	}
	int64_t slot_index = slot < 0 ? slot + 8 : slot;
	if (perm_index < 0 || perm_index >= 4 || slot_index < 0 || slot_index >= 8) {
		throw state::ScriptError("Out of bounds get index");
	}
	int64_t relation_index = kOrientationPerms[perm_index][slot_index];
	return relations.items[relation_index];
}

Corrected _apply_final_corrections(State &state, int64_t class_code, Terrain &terrain, Vector2i tile, int64_t flag_a, int64_t flag_b) {
	if ((class_code == 2 || class_code == 8) && _diagonal_probe_same_owner(state, terrain, tile, flag_a, flag_b)) {
		const int64_t corrected = class_code == 2 ? 6 : 12;
		return Corrected{corrected, gd::format(state, key::d_d_via_diagonal_same_owner, {int_value(class_code), int_value(corrected)})};
	}
	if ((class_code == 5 || class_code == 11) && _two_step_probe_same_owner(state, terrain, tile, flag_a, flag_b)) {
		const int64_t corrected = class_code == 5 ? 7 : 13;
		return Corrected{corrected, gd::format(state, key::d_d_via_two_step_same, {int_value(class_code), int_value(corrected)})};
	}
	return Corrected{class_code, key::empty};
}

bool _diagonal_probe_same_owner(State &state, Terrain &terrain, Vector2i tile, int64_t flag_a, int64_t flag_b) {
	const int64_t center_id = _owner_id_at_raw(state, terrain, tile);
	// DIAGONAL_PROBE_OFFSETS.get("%d,%d" % [flag_a, flag_b], []).
	if (flag_a < 0 || flag_a > 1 || flag_b < 0 || flag_b > 1) {
		return false;
	}
	for (const Vector2i offset : kDiagonalProbeOffsets[flag_a][flag_b]) {
		const Vector2i neighbor = tile + offset;
		if (_in_bounds(state, neighbor, terrain.map_size) && _owner_id_at_raw(state, terrain, neighbor) == center_id) {
			return true;
		}
	}
	return false;
}

bool _two_step_probe_same_owner(State &state, Terrain &terrain, Vector2i tile, int64_t flag_a, int64_t flag_b) {
	const int64_t center_id = _owner_id_at_raw(state, terrain, tile);
	// TWO_STEP_PROBE_OFFSETS.get("%d,%d" % [flag_a, flag_b], Vector2i.ZERO).
	Vector2i offset{};
	if (flag_a >= 0 && flag_a <= 1 && flag_b >= 0 && flag_b <= 1) {
		offset = kTwoStepProbeOffsets[flag_a][flag_b];
	}
	const Vector2i neighbor = tile + offset;
	return _in_bounds(state, neighbor, terrain.map_size) && _owner_id_at_raw(state, terrain, neighbor) == center_id;
}

bool _row_bucket_exists(State &state, int64_t owner_id, int64_t class_code) {
	(void)state;
	// NORMAL_TABLE_CLASS_COVERAGE.
	switch (owner_id) {
		case 0:
			return class_code == 0 || (class_code >= 8 && class_code <= 13) || class_code == 16 || class_code == 24;
		case 1:
			return class_code == 0;
		case 2:
		case 3:
		case 4:
		case 5:
		case 6:
		case 7:
			return class_code == 0 || (class_code >= 2 && class_code <= 28);
		case 8:
			return class_code == 0 || (class_code >= 8 && class_code <= 13) || class_code == 16;
		case 9:
			return class_code == 0 || (class_code >= 8 && class_code <= 13);
		default:
			return false;
	}
}

FrameSelection _select_visual_frame(State &state, int64_t owner_id, int64_t shape_class, int64_t flag_a, int64_t flag_b, Vector2i tile) {
	if (owner_id == kRockId) {
		return _select_rock_visual_frame(state, shape_class, flag_a, flag_b, tile);
	}
	return _select_normal_visual_frame(state, owner_id, shape_class, flag_a, flag_b, tile);
}

FrameSelection _select_normal_visual_frame(State &state, int64_t owner_id, int64_t shape_class, int64_t flag_a, int64_t flag_b, Vector2i tile) {
	// NORMAL_TABLE_BY_OWNER_ID.get(owner_id, "").
	Atom table_name = key::empty;
	switch (owner_id) {
		case 0:
			table_name = key::dirt;
			break;
		case 1:
			table_name = key::sand;
			break;
		case 2:
		case 3:
		case 4:
		case 5:
		case 6:
		case 7:
			table_name = key::normal79;
			break;
		case 8:
			table_name = key::water;
			break;
		default:
			break;
	}
	const RowEntry row_entry = _normal_row_entry(state, table_name, shape_class);
	FrameSelection selected;
	selected.row_table = table_name;
	if (_row_entry_empty(state, row_entry)) {
		const FullRows fallback_rows = _full_rows_for_normal_table(state, table_name, owner_id, tile);
		const std::string salt = compat::itos(owner_id) + ":missing:" + compat::itos(shape_class);
		const Atom ranges = compact_ranges(state, fallback_rows.rows);
		selected.frame = _choose_visual_frame(state, fallback_rows.rows, tile.x, tile.y, salt);
		selected.row_group = ranges;
		selected.row_source = gd::format(state, key::s_missing_class_d_fallback_full, {str(table_name), int_value(shape_class), str(ranges)});
		selected.fallback = true;
		selected.fallback_reason = gd::format(state, key::missing_row_bucket_for_terrain_d, {int_value(owner_id), int_value(shape_class)});
		return selected;
	}
	if (shape_class == 0) {
		const FullRows full = _full_rows_for_normal_table(state, table_name, owner_id, tile);
		const std::string salt = compat::itos(owner_id) + ":full:" + state.text(full.bucket);
		const Atom ranges = compact_ranges(state, full.rows);
		selected.frame = _choose_visual_frame(state, full.rows, tile.x, tile.y, salt);
		selected.row_group = ranges;
		selected.row_source = gd::format(state, key::s_class_0_s_rows_s, {str(table_name), str(full.bucket), str(ranges)});
		return selected;
	}
	const Rows rows = row_entry.kind == RowEntry::Kind::rows ? row_entry.rows : Rows{};
	const std::string salt = compat::itos(owner_id) + ":class:" + compat::itos(shape_class);
	const Atom ranges = compact_ranges(state, rows);
	selected.frame = _choose_visual_frame(state, rows, tile.x, tile.y, salt);
	selected.output_flag_a = flag_a;
	selected.output_flag_b = flag_b;
	selected.row_group = ranges;
	selected.row_source = gd::format(state, key::s_class_d_rows_s, {str(table_name), int_value(shape_class), str(ranges)});
	return selected;
}

namespace {

// ROCK_ROWS.get(shape_class, {}).get("%d,%d" % [flag_a, flag_b], []).
Rows rock_rows(int64_t shape_class, int64_t flag_a, int64_t flag_b) {
	if (flag_a < 0 || flag_a > 1 || flag_b < 0 || flag_b > 1) {
		return Rows{};
	}
	// The flag keys "0,0", "1,0", "0,1", "1,1" in that order.
	const int64_t slot = flag_a + flag_b * 2;
	switch (shape_class) {
		case 0:
			return slot == 0 ? frame_run(0, 8) : Rows{};
		case 8:
			return frame_run(8 + slot * 2, 2);
		case 9:
			return slot <= 1 ? frame_run(16 + slot * 2, 2) : Rows{};
		case 10:
			if (slot == 0) {
				return frame_run(20, 2);
			}
			return slot == 2 ? frame_run(22, 2) : Rows{};
		case 11:
			return frame_run(24 + slot * 2, 2);
		case 12:
			return frame_run(32 + slot * 2, 2);
		case 13:
			return frame_run(40 + slot * 2, 2);
		default:
			return Rows{};
	}
}

} // namespace

FrameSelection _select_rock_visual_frame(State &state, int64_t shape_class, int64_t flag_a, int64_t flag_b, Vector2i tile) {
	const Rows rows = rock_rows(shape_class, flag_a, flag_b);
	const std::string flags = compat::itos(shape_class) + ":" + compat::itos(flag_a) + ":" + compat::itos(flag_b);
	FrameSelection selected;
	selected.row_table = key::rock;
	if (rows.empty()) {
		const Rows fallback_rows = frame_run(0, 8);
		const Atom ranges = compact_ranges(state, fallback_rows);
		selected.frame = _choose_visual_frame(state, fallback_rows, tile.x, tile.y, "rock:missing:" + flags);
		selected.row_group = ranges;
		selected.row_source = gd::format(state, key::rock_missing_class_d_flags_d, {int_value(shape_class), int_value(flag_a), int_value(flag_b), str(ranges)});
		selected.fallback = true;
		selected.fallback_reason = gd::format(state, key::missing_rock_row_bucket_for_class, {int_value(shape_class), int_value(flag_a), int_value(flag_b)});
		return selected;
	}
	const Atom ranges = compact_ranges(state, rows);
	selected.frame = _choose_visual_frame(state, rows, tile.x, tile.y, "rock:" + flags);
	selected.row_group = ranges;
	selected.row_source = gd::format(state, key::rock_class_d_requested_flags_d, {int_value(shape_class), int_value(flag_a), int_value(flag_b), str(ranges)});
	return selected;
}

RowEntry _normal_row_entry(State &state, Atom table_name, int64_t shape_class) {
	(void)state;
	RowEntry entry;
	const auto rows = [&entry](int64_t first, size_t count) {
		entry.kind = RowEntry::Kind::rows;
		entry.rows = frame_run(first, count);
	};
	const auto full = [&entry](Rows ordinary, Rows special) {
		entry.kind = RowEntry::Kind::full;
		entry.ordinary = ordinary;
		entry.special = special;
	};
	if (table_name == key::normal79) {
		// NORMAL79_ROWS.
		if (shape_class == 0) {
			full(frame_run(49, 8), frame_run(57, 16));
		} else if (shape_class >= 2 && shape_class <= 5) {
			rows((shape_class - 2) * 4, 4);
		} else if (shape_class == 6 || shape_class == 7) {
			rows(16 + (shape_class - 6) * 2, 2);
		} else if (shape_class >= 8 && shape_class <= 11) {
			rows(20 + (shape_class - 8) * 4, 4);
		} else if (shape_class == 12 || shape_class == 13) {
			rows(36 + (shape_class - 12) * 2, 2);
		} else if (shape_class >= 14 && shape_class <= 22) {
			rows(40 + (shape_class - 14), 1);
		} else if (shape_class >= 23 && shape_class <= 26) {
			rows(73 + (shape_class - 23), 1);
		} else if (shape_class == 27) {
			rows(78, 1);
		} else if (shape_class == 28) {
			rows(77, 1);
		}
	} else if (table_name == key::dirt || table_name == key::water) {
		// DIRT_ROWS and WATER_ROWS: the same transition rows.
		if (shape_class == 0) {
			if (table_name == key::dirt) {
				full(frame_run(21, 8), frame_run(29, 16));
			} else {
				full(frame_run(21, 12), Rows{});
			}
		} else if (shape_class >= 8 && shape_class <= 11) {
			rows((shape_class - 8) * 4, 4);
		} else if (shape_class == 12 || shape_class == 13) {
			rows(16 + (shape_class - 12) * 2, 2);
		} else if (shape_class == 16) {
			rows(20, 1);
		} else if (shape_class == 24 && table_name == key::dirt) {
			rows(45, 1);
		}
	} else if (table_name == key::sand) {
		// SAND_ROWS.
		if (shape_class == 0) {
			full(frame_run(0, 8), frame_run(8, 16));
		}
	}
	return entry;
}

bool _row_entry_empty(State &state, const RowEntry &row_entry) {
	(void)state;
	switch (row_entry.kind) {
		case RowEntry::Kind::rows:
			return row_entry.rows.empty();
		case RowEntry::Kind::full:
			return row_entry.ordinary.empty() && row_entry.special.empty();
		default:
			return true;
	}
}

FullRows _full_rows_for_normal_table(State &state, Atom table_name, int64_t owner_id, Vector2i tile) {
	const RowEntry row_entry = _normal_row_entry(state, table_name, 0);
	if (row_entry.kind != RowEntry::Kind::full) {
		return FullRows{frame_run(0, 1), key::fallback};
	}
	const Rows ordinary_rows = row_entry.ordinary;
	const Rows special_rows = row_entry.special;
	const int64_t frequency = _special_tile_frequency(state, owner_id);
	const bool use_special = !special_rows.empty()
			&& _positive_visual_hash(state, "special:" + compat::itos(owner_id) + ":" + compat::itos(tile.x) + ":" + compat::itos(tile.y)) % 100 < frequency;
	if (use_special) {
		return FullRows{special_rows, key::special};
	}
	return FullRows{!ordinary_rows.empty() ? ordinary_rows : special_rows, key::ordinary};
}

int64_t _special_tile_frequency(State &state, int64_t owner_id) {
	(void)state;
	if (owner_id >= 0 && owner_id < 10) {
		return kSpecialTileFreq[owner_id];
	}
	return 0;
}

int64_t _choose_visual_frame(State &state, const Rows &rows, int64_t x, int64_t y, const std::string &salt) {
	if (rows.empty()) {
		return 0;
	}
	const int64_t index = _positive_visual_hash(state, salt + ":" + compat::itos(x) + ":" + compat::itos(y)) % static_cast<int64_t>(rows.size);
	return rows.items[index];
}

int64_t _positive_visual_hash(State &state, const std::string &text) {
	return compat::absi(_visual_hash(state, text));
}

int64_t _visual_hash(State &state, const std::string &text) {
	(void)state;
	uint64_t hash_value = 2166136261u;
	size_t index = 0;
	while (index < text.size()) {
		hash_value = hash_value ^ next_code_point(text, index);
		hash_value = (hash_value * 16777619u) & 0xffffffffu;
	}
	int64_t result = static_cast<int64_t>(hash_value);
	if (result >= 0x80000000LL) {
		result -= 0x100000000LL;
	}
	return result;
}

Atom _bridge_family_from_relations(State &state, const Relations &relations) {
	(void)state;
	bool has_relation_1 = false;
	bool has_relation_2 = false;
	for (const int64_t relation : relations.items) {
		if (relation == 1) {
			has_relation_1 = true;
		} else if (relation == 2) {
			has_relation_2 = true;
		}
	}
	if (has_relation_1 && has_relation_2) {
		return key::mixed;
	}
	if (has_relation_2) {
		return key::sand;
	}
	if (has_relation_1) {
		return key::dirt;
	}
	return key::empty;
}

Atom _visual_frame_block_for(State &state, Atom owner_family, int64_t frame_number, int64_t shape_class) {
	(void)state;
	if (shape_class == 0) {
		if (owner_family == key::dirt) {
			return key::dirt_base_interiors;
		}
		if (owner_family == key::sand) {
			return key::sand_base_interiors;
		}
		if (owner_family == key::water) {
			return key::open_water_interiors;
		}
		if (owner_family == key::rock) {
			return key::rock_black_void;
		}
		return key::native_interiors;
	}
	if (owner_family == key::dirt) {
		return key::dirt_to_sand_transition;
	}
	if (owner_family == key::water) {
		return key::shoreline_frames;
	}
	if (owner_family == key::rock) {
		return key::rock_light_ground_context;
	}
	if (owner_family == key::sand) {
		return key::sand_base_interiors;
	}
	if (frame_number >= 0 && frame_number <= 19) {
		return key::native_to_dirt_transition;
	}
	if (frame_number >= 20 && frame_number <= 39) {
		return key::native_to_sand_transition;
	}
	return key::mixed_junction_reserved;
}

Atom relation_grid_string(State &state, const Relations &relations) {
	// "%d%d%d/%dC%d/%d%d%d" % [NW, N, NE, W, E, SW, S, SE].
	const int64_t *r = relations.items;
	std::string grid = compat::itos(r[7]) + compat::itos(r[0]) + compat::itos(r[1]) + "/" + compat::itos(r[6]) + "C" + compat::itos(r[2]) + "/"
			+ compat::itos(r[5]) + compat::itos(r[4]) + compat::itos(r[3]);
	return state.intern(grid);
}

Atom compact_ranges(State &state, const Rows &indices) {
	if (indices.empty()) {
		return key::dash;
	}
	std::vector<int64_t> sorted(indices.items, indices.items + indices.size);
	std::sort(sorted.begin(), sorted.end());
	std::string ranges;
	const auto add_range = [&ranges](int64_t range_start, int64_t previous) {
		if (!ranges.empty()) {
			ranges += ",";
		}
		ranges += range_start == previous ? compat::itos(range_start) : compat::itos(range_start) + "-" + compat::itos(previous);
	};
	int64_t range_start = sorted[0];
	int64_t previous = sorted[0];
	for (size_t value_index = 1; value_index < sorted.size(); ++value_index) {
		const int64_t value = sorted[value_index];
		if (value == previous + 1) {
			previous = value;
			continue;
		}
		add_range(range_start, previous);
		range_start = value;
		previous = value;
	}
	add_range(range_start, previous);
	return state.intern(ranges);
}

int64_t _trait_flag4(State &state, int64_t owner_id) {
	(void)state;
	if (owner_id >= 0 && owner_id < 10) {
		return kTraitFlag4[owner_id];
	}
	return 1;
}

int64_t _trait_flag5(State &state, int64_t owner_id) {
	(void)state;
	if (owner_id >= 0 && owner_id < 10) {
		return kTraitFlag5[owner_id];
	}
	return 1;
}

} // namespace terrain_placement_rules

} // namespace aurelion::rules::port
