#pragma once

#include "map_document.hpp"
#include "scenario_document.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

class MapPackageService : public RefCounted {
	GDCLASS(MapPackageService, RefCounted)

protected:
	static void _bind_methods();

public:
	String get_api_version() const;
	Dictionary get_api_metadata() const;
	PackedStringArray get_capabilities() const;
	Dictionary get_schema_ids() const;
	Ref<MapDocument> create_map_document_stub(Dictionary initial_state = Dictionary()) const;
	Ref<ScenarioDocument> create_scenario_document_stub(Dictionary initial_state = Dictionary()) const;
	Dictionary load_map_package(String path, Dictionary options = Dictionary()) const;
	Dictionary load_scenario_package(String path, Dictionary options = Dictionary()) const;
	Dictionary validate_map_document(Ref<MapDocument> map_document, Dictionary options = Dictionary()) const;
	Dictionary validate_scenario_document(Ref<ScenarioDocument> scenario_document, Ref<MapDocument> map_document, Dictionary options = Dictionary()) const;
	Dictionary save_map_package(Ref<MapDocument> map_document, String path, Dictionary options = Dictionary()) const;
	Dictionary save_scenario_package(Ref<ScenarioDocument> scenario_document, String path, Dictionary options = Dictionary()) const;
	Dictionary migrate_map_package(String source_path, String target_path, int32_t target_version, Dictionary options = Dictionary()) const;
	Dictionary migrate_scenario_package(String source_path, String target_path, int32_t target_version, Dictionary options = Dictionary()) const;
	Dictionary convert_legacy_scenario_record(Dictionary scenario_record, Dictionary terrain_layers_record, Dictionary options = Dictionary()) const;
	Dictionary convert_generated_payload(Dictionary generated_map, Dictionary options = Dictionary()) const;
	Dictionary compute_document_hash(Variant document, Dictionary options = Dictionary()) const;
	Dictionary inspect_package(String path, Dictionary options = Dictionary()) const;
	Dictionary inspect_random_map_generator_data_model(Dictionary options = Dictionary()) const;
	Dictionary normalize_random_map_config(Dictionary config) const;
	Dictionary random_map_config_identity(Dictionary config) const;
	Dictionary generate_random_map(Dictionary config, Dictionary options = Dictionary()) const;
};

} // namespace godot
