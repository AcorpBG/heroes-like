#pragma once

#include "map_document.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class ScenarioDocument : public RefCounted {
	GDCLASS(ScenarioDocument, RefCounted)

	String scenario_id;
	String scenario_hash;
	Dictionary map_ref;
	Dictionary selection;
	Array player_slots;
	Dictionary objectives;
	Array script_hooks;
	Array enemy_factions;
	Dictionary start_contract;

protected:
	static void _bind_methods();

public:
	static constexpr int32_t SCHEMA_VERSION = 1;

	void configure(Dictionary initial_state);
	int32_t get_schema_version() const;
	String get_scenario_id() const;
	String get_scenario_hash() const;
	Dictionary get_map_ref() const;
	Dictionary get_selection() const;
	Array get_player_slots() const;
	Dictionary get_objectives() const;
	Array get_script_hooks() const;
	Array get_enemy_factions() const;
	Dictionary get_start_contract() const;
	Dictionary to_legacy_scenario_record(Ref<MapDocument> map_document) const;
	Dictionary get_validation_summary() const;
};

} // namespace godot
