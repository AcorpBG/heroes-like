extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_RUNTIME_ZONE_GRAPH_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_runtime_zone_graph_report_v1"

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
	var capabilities: PackedStringArray = service.get_capabilities()
	if not capabilities.has("native_random_map_homm3_runtime_zone_graph"):
		_fail("Native runtime zone graph capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-runtime-zone-graph-10184",
		"frontier_spokes_v1",
		"frontier_spokes_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "homm3_runtime_zone_graph_report"})
	if not bool(generated.get("ok", false)):
		_fail("Native generation failed: %s" % JSON.stringify(generated))
		return
	if String(generated.get("validation_status", "")) != "pass":
		_fail("Native validation did not pass: %s" % JSON.stringify(generated.get("validation_report", {})))
		return
	if String(generated.get("zone_generation_status", "")) != "zones_generated_runtime_template_graph":
		_fail("Catalog template did not use runtime zone graph layout: %s" % JSON.stringify(generated.get("zone_layout", {})))
		return

	var zone_layout: Dictionary = generated.get("zone_layout", {}) if generated.get("zone_layout", {}) is Dictionary else {}
	var runtime_graph: Dictionary = zone_layout.get("runtime_zone_graph", {}) if zone_layout.get("runtime_zone_graph", {}) is Dictionary else {}
	var graph_validation: Dictionary = runtime_graph.get("validation", {}) if runtime_graph.get("validation", {}) is Dictionary else {}
	if String(runtime_graph.get("schema_id", "")) != "aurelion_native_rmg_runtime_zone_graph_v1":
		_fail("Runtime graph schema mismatch: %s" % JSON.stringify(runtime_graph))
		return
	if String(graph_validation.get("status", "")) != "pass":
		_fail("Runtime graph validation failed: %s" % JSON.stringify(graph_validation))
		return
	if int(runtime_graph.get("zone_count", 0)) != 7 or int(runtime_graph.get("link_count", 0)) != 9:
		_fail("Runtime graph did not preserve frontier_spokes catalog counts: %s" % JSON.stringify(runtime_graph))
		return
	if String(zone_layout.get("policy", {}).get("zone_area_model", "")) != "runtime_template_graph_base_size_target_area":
		_fail("Zone layout still reports the old area model: %s" % JSON.stringify(zone_layout.get("policy", {})))
		return
	if String(generated.get("route_graph", {}).get("source_link_model", "")) != "runtime_template_zone_graph_links":
		_fail("Route graph did not consume runtime graph links: %s" % JSON.stringify(generated.get("route_graph", {})))
		return

	var zone_metrics := _validate_zones(runtime_graph.get("zones", []))
	if zone_metrics.is_empty():
		return
	var link_metrics := _validate_links(runtime_graph.get("links", []))
	if link_metrics.is_empty():
		return
	if int(graph_validation.get("target_area_sum", 0)) != 1296 or int(graph_validation.get("cell_count_sum", 0)) != 1296:
		_fail("Runtime target/cell area sums did not match the small surface: %s" % JSON.stringify(graph_validation))
		return
	if int(graph_validation.get("start_zone_count", 0)) != 3 or int(graph_validation.get("neutral_zone_count", 0)) < 1:
		_fail("Runtime graph did not preserve start/neutral zone roles: %s" % JSON.stringify(graph_validation))
		return
	if int(graph_validation.get("wide_link_count", 0)) != 1:
		_fail("Runtime graph did not preserve wide-link payloads: %s" % JSON.stringify(graph_validation))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"template_id": runtime_graph.get("source_template_id", ""),
		"zone_generation_status": generated.get("zone_generation_status", ""),
		"runtime_graph_signature": runtime_graph.get("signature", ""),
		"runtime_graph_validation": graph_validation,
		"zone_metrics": zone_metrics,
		"link_metrics": link_metrics,
		"route_link_model": generated.get("route_graph", {}).get("source_link_model", ""),
		"remaining_gap": "This slice preserves runtime template graph semantics and target areas before terrain/object placement; exact HoMM3 footprint heuristics, roads, guards, and object placement remain later Phase 3 slices.",
	})])
	get_tree().quit(0)

func _validate_zones(zones: Array) -> Dictionary:
	var start_count := 0
	var neutral_count := 0
	var target_sum := 0
	var cell_sum := 0
	var missing := []
	for value in zones:
		if not (value is Dictionary):
			missing.append({"reason": "non_dictionary_zone"})
			continue
		var zone: Dictionary = value
		var zone_id := String(zone.get("id", ""))
		for key in ["runtime_id", "source_template_id", "source_zone_id", "source_role", "base_size", "target_area", "terrain_rules", "town_rules", "mine_rules", "treasure_bands", "monster_rules", "adjacent_zone_ids", "runtime_links", "diagnostics"]:
			if not zone.has(key):
				missing.append({"zone_id": zone_id, "missing_key": key})
		if int(zone.get("target_area", 0)) <= 0 or int(zone.get("cell_count", 0)) <= 0:
			missing.append({"zone_id": zone_id, "reason": "missing_target_or_cells"})
		if String(zone.get("role", "")).contains("start"):
			start_count += 1
		if zone.get("owner_slot", null) == null:
			neutral_count += 1
		target_sum += int(zone.get("target_area", 0))
		cell_sum += int(zone.get("cell_count", 0))
	if not missing.is_empty():
		_fail("Runtime zones missed required semantics: %s" % JSON.stringify(missing.slice(0, min(8, missing.size()))))
		return {}
	return {
		"zone_count": zones.size(),
		"start_count": start_count,
		"neutral_count": neutral_count,
		"target_area_sum": target_sum,
		"cell_count_sum": cell_sum,
	}

func _validate_links(links: Array) -> Dictionary:
	var wide_count := 0
	var border_guard_count := 0
	var guard_value_sum := 0
	var missing := []
	for value in links:
		if not (value is Dictionary):
			missing.append({"reason": "non_dictionary_link"})
			continue
		var link: Dictionary = value
		for key in ["runtime_id", "source_template_id", "from_zone_id", "to_zone_id", "value", "wide", "border_guard", "road_policy", "guard_policy", "diagnostics"]:
			if not link.has(key):
				missing.append({"link": link.get("runtime_id", ""), "missing_key": key})
		if bool(link.get("wide", false)):
			wide_count += 1
			var guard_policy: Dictionary = link.get("guard_policy", {}) if link.get("guard_policy", {}) is Dictionary else {}
			if int(guard_policy.get("normal_guard_value", -1)) != 0:
				missing.append({"link": link.get("runtime_id", ""), "reason": "wide_link_did_not_suppress_normal_guard"})
		if bool(link.get("border_guard", false)):
			border_guard_count += 1
		guard_value_sum += int(link.get("value", 0))
	if not missing.is_empty():
		_fail("Runtime links missed required payload semantics: %s" % JSON.stringify(missing.slice(0, min(8, missing.size()))))
		return {}
	return {
		"link_count": links.size(),
		"wide_count": wide_count,
		"border_guard_count": border_guard_count,
		"guard_value_sum": guard_value_sum,
	}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
