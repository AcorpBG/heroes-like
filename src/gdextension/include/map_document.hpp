#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/rect2i.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class MapDocument : public RefCounted {
	GDCLASS(MapDocument, RefCounted)

	String map_id;
	String map_hash;
	String source_kind = "test_fixture";
	int32_t width = 0;
	int32_t height = 0;
	int32_t level_count = 1;
	Dictionary metadata;
	Array objects;

protected:
	static void _bind_methods();

public:
	static constexpr int32_t SCHEMA_VERSION = 1;

	void configure(Dictionary initial_state);
	int32_t get_schema_version() const;
	String get_map_id() const;
	String get_map_hash() const;
	String get_source_kind() const;
	int32_t get_width() const;
	int32_t get_height() const;
	int32_t get_level_count() const;
	int32_t get_tile_count() const;
	Dictionary get_metadata() const;
	PackedStringArray get_terrain_layer_ids() const;
	PackedInt32Array get_tile_layer_u16(String layer_id, int32_t level = 0) const;
	int32_t get_object_count() const;
	Dictionary get_object_by_index(int32_t index) const;
	Dictionary get_object_by_placement_id(String placement_id) const;
	Array get_objects_in_rect(Rect2i rect, int32_t level = 0) const;
	Dictionary get_route_graph() const;
	Dictionary get_validation_summary() const;
	Dictionary to_legacy_scenario_record_patch() const;
	Dictionary to_legacy_terrain_layers_record() const;
};

} // namespace godot
