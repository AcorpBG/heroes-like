#include "scenario_document.hpp"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace {

Dictionary not_implemented(const String &operation) {
	Dictionary result;
	result["ok"] = false;
	result["status"] = "fail";
	result["error_code"] = "not_implemented";
	result["message"] = operation + " is not implemented in the Slice 1 native scenario document skeleton.";
	result["operation"] = operation;
	result["recoverable"] = true;
	return result;
}

} // namespace

void ScenarioDocument::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "initial_state"), &ScenarioDocument::configure);
	ClassDB::bind_method(D_METHOD("get_schema_version"), &ScenarioDocument::get_schema_version);
	ClassDB::bind_method(D_METHOD("get_scenario_id"), &ScenarioDocument::get_scenario_id);
	ClassDB::bind_method(D_METHOD("get_scenario_hash"), &ScenarioDocument::get_scenario_hash);
	ClassDB::bind_method(D_METHOD("get_map_ref"), &ScenarioDocument::get_map_ref);
	ClassDB::bind_method(D_METHOD("get_selection"), &ScenarioDocument::get_selection);
	ClassDB::bind_method(D_METHOD("get_player_slots"), &ScenarioDocument::get_player_slots);
	ClassDB::bind_method(D_METHOD("get_objectives"), &ScenarioDocument::get_objectives);
	ClassDB::bind_method(D_METHOD("get_script_hooks"), &ScenarioDocument::get_script_hooks);
	ClassDB::bind_method(D_METHOD("get_enemy_factions"), &ScenarioDocument::get_enemy_factions);
	ClassDB::bind_method(D_METHOD("get_start_contract"), &ScenarioDocument::get_start_contract);
	ClassDB::bind_method(D_METHOD("to_legacy_scenario_record", "map_document"), &ScenarioDocument::to_legacy_scenario_record);
	ClassDB::bind_method(D_METHOD("get_validation_summary"), &ScenarioDocument::get_validation_summary);
}

void ScenarioDocument::configure(Dictionary initial_state) {
	scenario_id = String(initial_state.get("scenario_id", ""));
	scenario_hash = String(initial_state.get("scenario_hash", ""));
	map_ref = initial_state.get("map_ref", Dictionary());
	selection = initial_state.get("selection", Dictionary());
}

int32_t ScenarioDocument::get_schema_version() const { return SCHEMA_VERSION; }
String ScenarioDocument::get_scenario_id() const { return scenario_id; }
String ScenarioDocument::get_scenario_hash() const { return scenario_hash; }
Dictionary ScenarioDocument::get_map_ref() const { return map_ref.duplicate(true); }
Dictionary ScenarioDocument::get_selection() const { return selection.duplicate(true); }
Array ScenarioDocument::get_player_slots() const { return Array(); }
Dictionary ScenarioDocument::get_objectives() const { return not_implemented("get_objectives"); }
Array ScenarioDocument::get_script_hooks() const { return Array(); }
Array ScenarioDocument::get_enemy_factions() const { return Array(); }
Dictionary ScenarioDocument::get_start_contract() const { return not_implemented("get_start_contract"); }
Dictionary ScenarioDocument::to_legacy_scenario_record(Ref<MapDocument> map_document) const { return not_implemented("to_legacy_scenario_record"); }

Dictionary ScenarioDocument::get_validation_summary() const {
	Dictionary result;
	result["schema_id"] = "aurelion_scenario_validation_report";
	result["schema_version"] = 1;
	result["document_id"] = scenario_id;
	result["document_hash"] = scenario_hash;
	result["status"] = "not_implemented";
	result["failure_count"] = 0;
	result["warning_count"] = 0;
	result["failures"] = Array();
	result["warnings"] = Array();
	result["metrics"] = Dictionary();
	return result;
}
