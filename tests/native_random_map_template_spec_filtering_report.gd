extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_TEMPLATE_SPEC_FILTERING_REPORT"

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

	var filtered_config := {
		"seed": "native-rmg-template-filtering-10184",
		"template_id": "translated_rmg_template_001_v1",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land"},
		"player_constraints": {"human_count": 1, "player_count": 2, "team_mode": "free_for_all"},
	}
	var filtered: Dictionary = service.generate_random_map(filtered_config)
	var filtered_graph: Dictionary = _runtime_graph(filtered)
	if int(filtered_graph.get("zone_count", -1)) != 4 or int(filtered_graph.get("link_count", -1)) != 4:
		_fail("Translated template 001 did not use the recovered active 1/2 row set: %s" % JSON.stringify(filtered_graph))
		return
	if not _assert_all_records_active(filtered_graph):
		return

	var two_human_config := filtered_config.duplicate(true)
	two_human_config["seed"] = "native-rmg-template-filtering-two-human-10184"
	two_human_config["player_constraints"] = {"human_count": 2, "player_count": 2, "team_mode": "free_for_all"}
	var two_human: Dictionary = service.generate_random_map(two_human_config)
	if not _assert_owner_slot_two_is_human(_runtime_graph(two_human)):
		return

	var selected_config := filtered_config.duplicate(true)
	selected_config.erase("template_id")
	selected_config["seed"] = "native-rmg-template-accepted-vector-10184"
	var selected: Dictionary = service.generate_random_map(selected_config)
	var normalized: Dictionary = selected.get("normalized_config", {}) if selected.get("normalized_config", {}) is Dictionary else {}
	if String(normalized.get("template_id", "")) == "":
		_fail("Native template selection did not choose from the accepted catalog vector: %s" % JSON.stringify(normalized))
		return
	if _runtime_graph(selected).is_empty():
		_fail("Native accepted-vector selection did not produce a catalog runtime graph.")
		return

	var wide_config := {
		"seed": "native-rmg-template-wide-raw-value-10184",
		"template_id": "frontier_spokes_v1",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}
	var wide_payload: Dictionary = service.generate_random_map(wide_config)
	if not _assert_wide_raw_guard_preserved_without_normal_control(wide_payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"filtered_template_001": {
			"zone_count": filtered_graph.get("zone_count", 0),
			"link_count": filtered_graph.get("link_count", 0),
		},
		"selected_template_id": normalized.get("template_id", ""),
	})])
	get_tree().quit(0)

func _runtime_graph(payload: Dictionary) -> Dictionary:
	return payload.get("zone_layout", {}).get("runtime_zone_graph", {}) if payload.get("zone_layout", {}).get("runtime_zone_graph", {}) is Dictionary else {}

func _assert_all_records_active(graph: Dictionary) -> bool:
	for zone in graph.get("zones", []):
		if zone is Dictionary and not bool(zone.get("template_player_filter_active", false)):
			_fail("Inactive zone survived native graph filtering: %s" % JSON.stringify(zone))
			return false
	for link in graph.get("links", []):
		if link is Dictionary and not bool(link.get("template_player_filter_active", false)):
			_fail("Inactive link survived native graph filtering: %s" % JSON.stringify(link))
			return false
	return true

func _assert_owner_slot_two_is_human(graph: Dictionary) -> bool:
	for zone in graph.get("zones", []):
		if not (zone is Dictionary):
			continue
		if int(zone.get("owner_slot", 0)) == 2:
			if String(zone.get("role", "")) != "human_start" or String(zone.get("player_type", "")) != "human":
				_fail("Owner slot 2 did not follow requested human-count assignment: %s" % JSON.stringify(zone))
				return false
			return true
	_fail("Owner slot 2 was missing from the two-human filtered runtime graph: %s" % JSON.stringify(graph))
	return false

func _assert_wide_raw_guard_preserved_without_normal_control(payload: Dictionary) -> bool:
	var graph := _runtime_graph(payload)
	var saw_wide := false
	for edge in payload.get("road_network", {}).get("route_graph", {}).get("edges", []):
		if not (edge is Dictionary) or not bool(edge.get("wide", false)):
			continue
		saw_wide = true
		if int(edge.get("guard_value", 0)) <= 0:
			_fail("Wide route edge lost its raw guard value: %s" % JSON.stringify(edge))
			return false
		if edge.has("connection_control"):
			_fail("Wide route edge materialized normal connection control: %s" % JSON.stringify(edge))
			return false
	for link in graph.get("links", []):
		if not (link is Dictionary) or not bool(link.get("wide", false)):
			continue
		var guard_policy: Dictionary = link.get("guard_policy", {}) if link.get("guard_policy", {}) is Dictionary else {}
		if int(guard_policy.get("raw_value", -1)) <= 0 or int(guard_policy.get("normal_guard_value", -1)) != 0:
			_fail("Wide link did not preserve raw value while suppressing normal guard: %s" % JSON.stringify(link))
			return false
	if not saw_wide:
		_fail("Wide-link fixture did not expose a wide route edge: %s" % JSON.stringify(payload.get("road_network", {}).get("route_graph", {})))
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
