extends Node

const PackageSurfaceReportScript = preload("res://tests/native_random_map_package_surface_topology_report.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_PACKAGE_OBJECT_ONLY_BREADTH_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_package_object_only_breadth_report_v1"

const CASES := [
	{"id": "default_small_049", "size_class_id": "homm3_small"},
	{"id": "default_medium_002", "size_class_id": "homm3_medium"},
	{"id": "default_large_042", "size_class_id": "homm3_large"},
	{"id": "default_extra_large_043", "size_class_id": "homm3_extra_large"},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return

	var helper: Node = PackageSurfaceReportScript.new()
	var summaries := []
	for case_record in CASES:
		var summary := _run_case(service, helper, case_record)
		if summary.is_empty():
			helper.free()
			return
		summaries.append(summary)
	helper.free()

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"case_count": summaries.size(),
		"cases": summaries,
		"remaining_gap": "Breadth gate covers player-facing default translated size templates only; it does not claim all 56 recovered templates or exact HoMM3 pathing/byte parity.",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, helper: Node, case_record: Dictionary) -> Dictionary:
	var case_id := String(case_record.get("id", "case"))
	var size_class_id := String(case_record.get("size_class_id", "homm3_small"))
	var defaults := ScenarioSelectRulesScript.random_map_size_class_default(size_class_id)
	var expected_player_count := int(defaults.get("player_count", 3))
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"package-object-only-breadth-%s-10184" % size_class_id,
		"",
		"",
		expected_player_count,
		"land",
		false,
		size_class_id
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "package_object_only_breadth_%s" % case_id})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("%s generation failed validation: %s" % [case_id, JSON.stringify(generated.get("validation_report", generated))])
		return {}
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	if String(normalized.get("template_id", "")) != String(defaults.get("template_id", "")) or String(normalized.get("profile_id", "")) != String(defaults.get("profile_id", "")):
		_fail("%s did not use the size-class default translated template/profile: %s defaults=%s" % [case_id, JSON.stringify(normalized), JSON.stringify(defaults)])
		return {}

	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_package_object_only_breadth_report",
		"session_save_version": 9,
		"scenario_id": "native_package_object_only_breadth_%s" % case_id,
	})
	if not bool(adoption.get("ok", false)):
		_fail("%s package conversion failed: %s" % [case_id, JSON.stringify(adoption)])
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("%s package conversion missed map_document." % case_id)
		return {}
	var converted_surface: Dictionary = helper._package_surface_summary(map_document, "converted_package")
	if not _assert_surface(case_id, converted_surface, defaults, expected_player_count):
		return {}

	var map_path := "user://native_package_object_only_breadth_%s.amap" % case_id
	var save_result: Dictionary = service.save_map_package(map_document, map_path)
	if not bool(save_result.get("ok", false)):
		_fail("%s save_map_package failed: %s" % [case_id, JSON.stringify(save_result)])
		return {}
	var load_result: Dictionary = service.load_map_package(map_path)
	DirAccess.remove_absolute(map_path)
	if not bool(load_result.get("ok", false)):
		_fail("%s load_map_package failed: %s" % [case_id, JSON.stringify(load_result)])
		return {}
	var loaded_document: Variant = load_result.get("map_document", null)
	if loaded_document == null:
		_fail("%s load_map_package missed map_document." % case_id)
		return {}
	var loaded_surface: Dictionary = helper._package_surface_summary(loaded_document, "loaded_package")
	if not _assert_surface(case_id, loaded_surface, defaults, expected_player_count):
		return {}

	return {
		"id": case_id,
		"size_class_id": size_class_id,
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"validation_status": String(generated.get("validation_status", "")),
		"converted_package": _surface_brief(converted_surface),
		"loaded_package": _surface_brief(loaded_surface),
	}

func _assert_surface(case_id: String, surface: Dictionary, defaults: Dictionary, expected_player_count: int) -> bool:
	var label := String(surface.get("label", "package"))
	if String(surface.get("template_id", "")) != String(defaults.get("template_id", "")) or String(surface.get("profile_id", "")) != String(defaults.get("profile_id", "")):
		_fail("%s %s did not preserve default template/profile provenance: %s defaults=%s" % [case_id, label, JSON.stringify(surface), JSON.stringify(defaults)])
		return false
	if int(surface.get("object_count", 0)) <= expected_player_count * 10:
		_fail("%s %s package object count is too low for a usable generated map: %s" % [case_id, label, JSON.stringify(surface)])
		return false
	if int(surface.get("guard_count", 0)) <= 0:
		_fail("%s %s package has no guards: %s" % [case_id, label, JSON.stringify(surface)])
		return false
	if int(surface.get("road_unique_tile_count", 0)) <= 0:
		_fail("%s %s package has no materialized roads: %s" % [case_id, label, JSON.stringify(surface)])
		return false
	if int(surface.get("zero_tile_road_count", 0)) != 0 or int(surface.get("road_duplicate_tile_count", 0)) != 0:
		_fail("%s %s serialized empty or duplicate road records: %s" % [case_id, label, JSON.stringify(surface)])
		return false
	var player_slots: Dictionary = surface.get("player_start_towns_by_slot", {}) if surface.get("player_start_towns_by_slot", {}) is Dictionary else {}
	for slot in range(1, expected_player_count + 1):
		var towns: Array = player_slots.get(str(slot), []) if player_slots.get(str(slot), []) is Array else []
		if towns.is_empty():
			_fail("%s %s expected at least one owned/player start town for slot %d: %s" % [case_id, label, slot, JSON.stringify(player_slots)])
			return false
	var object_only_start: Dictionary = surface.get("object_only_start_town_topology", {}) if surface.get("object_only_start_town_topology", {}) is Dictionary else {}
	if not object_only_start.get("reachable_pairs", []).is_empty():
		_fail("%s %s object masks alone allow unguarded start-town traversal: %s" % [case_id, label, JSON.stringify(surface)])
		return false
	var required_start_pairs := expected_player_count * (expected_player_count - 1) / 2
	if int(object_only_start.get("checked_pair_count", 0)) < required_start_pairs:
		_fail("%s %s object-only start topology did not inspect all player-start pairs: %s" % [case_id, label, JSON.stringify(surface)])
		return false
	var object_only_cross_zone: Dictionary = surface.get("object_only_cross_zone_town_topology", {}) if surface.get("object_only_cross_zone_town_topology", {}) is Dictionary else {}
	if not object_only_cross_zone.get("reachable_pairs", []).is_empty():
		_fail("%s %s object masks alone allow unguarded cross-zone town traversal: %s" % [case_id, label, JSON.stringify(surface)])
		return false
	if int(object_only_cross_zone.get("checked_pair_count", 0)) < required_start_pairs:
		_fail("%s %s object-only cross-zone topology inspected too few pairs: %s" % [case_id, label, JSON.stringify(surface)])
		return false
	return true

func _surface_brief(surface: Dictionary) -> Dictionary:
	return {
		"width": int(surface.get("width", 0)),
		"height": int(surface.get("height", 0)),
		"zone_count": int(surface.get("zone_count", 0)),
		"town_count": int(surface.get("town_count", 0)),
		"guard_count": int(surface.get("guard_count", 0)),
		"object_count": int(surface.get("object_count", 0)),
		"road_unique_tile_count": int(surface.get("road_unique_tile_count", 0)),
		"object_only_blocked_tile_count": int(surface.get("object_only_blocked_tile_count", 0)),
		"object_only_start_checked_pair_count": int(surface.get("object_only_start_town_topology", {}).get("checked_pair_count", 0)),
		"object_only_cross_zone_checked_pair_count": int(surface.get("object_only_cross_zone_town_topology", {}).get("checked_pair_count", 0)),
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
