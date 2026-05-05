extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_ROADS_RIVERS_CONNECTIONS_REPORT"

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
	if not capabilities.has("native_random_map_homm3_roads_rivers_connections"):
		_fail("Native roads/rivers/connections capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var border_config := _border_gate_config("native-rmg-connection-border-gate-10184")
	var wide_config := _wide_config("native-rmg-connection-wide-10184")
	var first: Dictionary = service.generate_random_map(border_config)
	var second: Dictionary = service.generate_random_map(border_config.duplicate(true))
	var changed := border_config.duplicate(true)
	changed["seed"] = "native-rmg-connection-border-gate-10184-changed"
	var changed_result: Dictionary = service.generate_random_map(changed)
	var wide_result: Dictionary = service.generate_random_map(wide_config)

	if not _assert_connection_shape(first, true, false):
		return
	if not _assert_connection_shape(second, true, false):
		return
	if not _assert_connection_shape(wide_result, false, true):
		return
	if not _assert_overlay_shape(first):
		return
	if not _assert_overlay_shape(wide_result):
		return

	var first_payload: Dictionary = first.get("connection_payload_resolution", {})
	var second_payload: Dictionary = second.get("connection_payload_resolution", {})
	var changed_payload: Dictionary = changed_result.get("connection_payload_resolution", {})
	var signature := String(first_payload.get("signature", ""))
	if signature == "":
		_fail("Connection payload signature is empty.")
		return
	if signature != String(second_payload.get("signature", "")):
		_fail("Same seed/config did not preserve connection payload signature.")
		return
	if signature == String(changed_payload.get("signature", "")):
		_fail("Changed seed did not change connection payload signature.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"connection_payload_generation_status": first_payload.get("generation_status", ""),
		"connection_payload_summary": first_payload.get("summary", {}),
		"wide_payload_summary": wide_result.get("connection_payload_resolution", {}).get("summary", {}),
		"road_overlay_semantics": first.get("road_network", {}).get("overlay_semantics", ""),
		"river_overlay_semantics": first.get("river_network", {}).get("policy", {}).get("overlay_semantics", ""),
		"connection_payload_signature": signature,
		"changed_connection_payload_signature": changed_payload.get("signature", ""),
	})])
	get_tree().quit(0)

func _border_gate_config(seed: String) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": 40,
			"height": 36,
			"level_count": 1,
			"size_class_id": "homm3_small",
			"water_mode": "land",
		},
		"player_constraints": {
			"human_count": 1,
			"computer_count": 2,
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"terrain_ids": ["grass", "dirt", "rough"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

func _wide_config(seed: String) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": 40,
			"height": 36,
			"level_count": 1,
			"size_class_id": "homm3_small",
			"water_mode": "islands",
		},
		"player_constraints": {
			"human_count": 1,
			"computer_count": 3,
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "native_connection_wide_profile",
			"template_id": "native_foundation_spoke",
			"terrain_ids": ["grass", "dirt", "rough", "snow"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}

func _assert_connection_shape(generated: Dictionary, expect_gate: bool, expect_wide: bool) -> bool:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG returned ok=false: %s" % JSON.stringify(generated.get("report", {})))
		return false
	var payload: Dictionary = generated.get("connection_payload_resolution", {})
	if String(payload.get("schema_id", "")) != "aurelion_native_rmg_connection_payload_resolution_v1":
		_fail("Connection payload schema mismatch: %s" % JSON.stringify(payload))
		return false
	if String(payload.get("validation_status", "")) != "pass" or not payload.get("diagnostics", []).is_empty():
		_fail("Connection payload validation failed: %s" % JSON.stringify(payload))
		return false
	if String(payload.get("phase_order", "")) != "cleanup_late_connection_payload_after_town_castle_placement_before_river_overlay_writeout":
		_fail("Connection payload missed recovered phase order: %s" % JSON.stringify(payload))
		return false
	if String(payload.get("wide_semantics", "")) != "suppresses_normal_guard_not_corridor_width":
		_fail("Wide semantics drifted: %s" % JSON.stringify(payload))
		return false
	var summary: Dictionary = payload.get("summary", {})
	if int(summary.get("required_link_count", 0)) <= 0 or int(summary.get("required_link_failure_count", 0)) != 0:
		_fail("Required links did not all resolve to corridors: %s" % JSON.stringify(summary))
		return false
	if expect_gate:
		if int(summary.get("special_gate_count", 0)) <= 0 or generated.get("connection_gate_records", []).is_empty():
			_fail("Border Guard connection did not materialize original gate records: %s" % JSON.stringify(summary))
			return false
		for gate in generated.get("connection_gate_records", []):
			if not (gate is Dictionary):
				_fail("Invalid connection gate record.")
				return false
			if String(gate.get("source_type_equivalent", "")) != "type_9_border_guard_equivalent_original_gate" or String(gate.get("object_id", "")) == "":
				_fail("Connection gate missed type-9-equivalent original object semantics: %s" % JSON.stringify(gate))
				return false
	if expect_wide:
		if int(summary.get("wide_suppressed_count", 0)) <= 0:
			_fail("Wide links did not emit suppression records: %s" % JSON.stringify(summary))
			return false
		for record in payload.get("wide_suppressions", []):
			if not (record is Dictionary):
				_fail("Invalid wide suppression record.")
				return false
			if bool(record.get("normal_guard_materialized", true)) or int(record.get("normal_guard_value", -1)) != 0:
				_fail("Wide link did not suppress normal guard: %s" % JSON.stringify(record))
				return false
	return true

func _assert_overlay_shape(generated: Dictionary) -> bool:
	var road: Dictionary = generated.get("road_network", {})
	if String(road.get("overlay_semantics", "")) != "deterministic_road_overlay_metadata_separate_from_rand_trn_decoration_object_scoring":
		_fail("Road overlay semantics missing: %s" % JSON.stringify(road))
		return false
	for segment in road.get("road_segments", []):
		if not (segment is Dictionary):
			_fail("Invalid road segment.")
			return false
		if int(segment.get("cell_count", 0)) > 0 and int(segment.get("overlay_tile_count", 0)) != int(segment.get("cell_count", 0)):
			_fail("Road segment overlay tile count mismatch: %s" % JSON.stringify(segment))
			return false
		if int(segment.get("cell_count", 0)) > 0 and String(segment.get("overlay_byte_layout", {}).get("rand_trn_decoration_scoring", "")) != "not_used":
			_fail("Road segment did not separate rand_trn scoring: %s" % JSON.stringify(segment))
			return false
	var river: Dictionary = generated.get("river_network", {})
	if String(river.get("policy", {}).get("overlay_semantics", "")) != "river_overlay_metadata_separate_from_rand_trn_decoration_object_scoring":
		_fail("River overlay semantics missing: %s" % JSON.stringify(river))
		return false
	for segment in river.get("river_segments", []):
		if not (segment is Dictionary):
			_fail("Invalid river segment.")
			return false
		if int(segment.get("cell_count", 0)) > 0 and int(segment.get("overlay_tile_count", 0)) != int(segment.get("cell_count", 0)):
			_fail("River segment overlay tile count mismatch: %s" % JSON.stringify(segment))
			return false
		if int(segment.get("cell_count", 0)) > 0 and String(segment.get("overlay_byte_layout", {}).get("rand_trn_decoration_scoring", "")) != "not_used":
			_fail("River segment did not separate rand_trn scoring: %s" % JSON.stringify(segment))
			return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
