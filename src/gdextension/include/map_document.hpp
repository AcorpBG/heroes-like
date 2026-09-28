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
	Dictionary terrain_layers;
	Dictionary route_graph;
	Array objects;

protected:
	static void _bind_methods();

	void assign_state(const Dictionary &initial_state, bool copy_containers);

public:
	static constexpr int32_t SCHEMA_VERSION = 1;
	// Upper bounds for loaded and validated documents. XL maps are 144 tiles
	// wide with two levels; anything larger is rejected before it is expanded.
	static constexpr int32_t MAX_DIMENSION = 256;
	static constexpr int32_t MAX_LEVEL_COUNT = 2;

	void configure(Dictionary initial_state);
	// Native-only: takes containers the caller just built and will not touch
	// again, without the defensive deep copy configure() makes.
	void configure_owned(const Dictionary &initial_state);
	// Native-only read access to the stored containers, without copying.
	const Dictionary &metadata_view() const { return metadata; }
	const Dictionary &terrain_layers_view() const { return terrain_layers; }
	const Dictionary &route_graph_view() const { return route_graph; }
	const Array &objects_view() const { return objects; }

	int32_t get_schema_version() const;
	String get_map_id() const;
	String get_map_hash() const;
	String get_source_kind() const;
	int32_t get_width() const;
	int32_t get_height() const;
	int32_t get_level_count() const;
	int64_t get_tile_count() const;
	Dictionary get_metadata() const;
	PackedStringArray get_terrain_layer_ids() const;
	PackedInt32Array get_tile_layer_u16(String layer_id, int32_t level = 0) const;
	Dictionary get_terrain_layers() const;
	int32_t get_object_count() const;
	Array get_objects() const;
	Dictionary get_object_by_index(int32_t index) const;
	Dictionary get_object_by_placement_id(String placement_id) const;
	Array get_objects_in_rect(Rect2i rect, int32_t level = 0) const;
	Dictionary get_route_graph() const;
	Dictionary get_validation_summary() const;
	Dictionary to_legacy_scenario_record_patch() const;
	Dictionary to_legacy_terrain_layers_record() const;
};

} // namespace godot
