extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_VALIDATION_PROVENANCE_REPORT"

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
	if not capabilities.has("native_random_map_validation_provenance_foundation"):
		_fail("Native validation/provenance capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := {
		"seed": "native-rmg-validation-provenance-parity-10184",
		"size": {
			"width": 48,
			"height": 42,
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
			"id": "native_validation_provenance_profile",
			"template_id": "native_foundation_spoke",
			"terrain_ids": ["grass", "dirt", "rough", "snow", "underground"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}
	var changed_seed_config := config.duplicate(true)
	changed_seed_config["seed"] = "native-rmg-validation-provenance-parity-10184-changed"

	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	var changed: Dictionary = service.generate_random_map(changed_seed_config)

	_assert_validation_provenance_shape(first, 48, 42, 4)
	_assert_validation_provenance_shape(second, 48, 42, 4)
	_assert_validation_provenance_shape(changed, 48, 42, 4)

	var first_report: Dictionary = first.get("validation_report", {})
	var second_report: Dictionary = second.get("validation_report", {})
	var changed_report: Dictionary = changed.get("validation_report", {})
	var first_provenance: Dictionary = first.get("provenance", {})
	var second_provenance: Dictionary = second.get("provenance", {})
	var changed_provenance: Dictionary = changed.get("provenance", {})

	var full_signature := String(first.get("full_output_signature", ""))
	var provenance_signature := String(first_provenance.get("signature", ""))
	if full_signature == "" or provenance_signature == "" or String(first_report.get("report_signature", "")) == "":
		_fail("Validation/provenance signatures must be non-empty.")
		return
	if full_signature != String(second.get("full_output_signature", "")):
		_fail("Same seed/config did not preserve full output signature.")
		return
	if provenance_signature != String(second_provenance.get("signature", "")):
		_fail("Same seed/config did not preserve provenance signature.")
		return
	if full_signature == String(changed.get("full_output_signature", "")):
		_fail("Changed seed did not change full output signature.")
		return
	if provenance_signature == String(changed_provenance.get("signature", "")):
		_fail("Changed seed did not change provenance signature.")
		return
	if String(first_report.get("report_signature", "")) != String(second_report.get("report_signature", "")):
		_fail("Same seed/config did not preserve validation report signature.")
		return
	if String(first_report.get("report_signature", "")) == String(changed_report.get("report_signature", "")):
		_fail("Changed seed did not change validation report signature.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"validation_status": first.get("validation_status", ""),
		"full_generation_status": first.get("full_generation_status", ""),
		"full_output_signature": full_signature,
		"changed_full_output_signature": changed.get("full_output_signature", ""),
		"provenance_signature": provenance_signature,
		"changed_provenance_signature": changed_provenance.get("signature", ""),
		"phase_signature": first_report.get("phase_signature", ""),
		"component_counts": first_report.get("component_counts", {}),
	})])
	get_tree().quit(0)

func _assert_validation_provenance_shape(generated: Dictionary, expected_width: int, expected_height: int, expected_players: int) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG validation/provenance generation returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "partial_foundation":
		_fail("Validation/provenance slice did not preserve partial_foundation status.")
		return
	if String(generated.get("full_generation_status", "")) != "not_implemented":
		_fail("Validation/provenance slice falsely implied full generation.")
		return
	if String(generated.get("validation_status", "")) != "pass":
		_fail("Native validation did not pass: %s" % JSON.stringify(generated.get("validation_report", {})))
		return
	if bool(generated.get("no_authored_writeback", false)) != true:
		_fail("Native output did not expose no-authored-writeback boundary.")
		return

	var report: Dictionary = generated.get("validation_report", {})
	if String(report.get("schema_id", "")) != "aurelion_native_random_map_validation_report_v1":
		_fail("Validation report schema mismatch: %s" % JSON.stringify(report))
		return
	if String(report.get("status", "")) != "pass" or int(report.get("failure_count", -1)) != 0:
		_fail("Validation report did not pass cleanly: %s" % JSON.stringify(report))
		return
	if String(report.get("full_generation_status", "")) != "not_implemented" or bool(report.get("full_parity_claim", true)):
		_fail("Validation report made a false parity claim: %s" % JSON.stringify(report))
		return
	if bool(report.get("no_authored_writeback", false)) != true:
		_fail("Validation report missed no-authored-writeback boundary.")
		return
	var remaining: Array = report.get("remaining_parity_slices", [])
	if remaining.has("native-rmg-validation-provenance-parity-10184") or not remaining.has("native-rmg-gdscript-comparison-harness-10184"):
		_fail("Remaining parity slice list was not advanced correctly: %s" % JSON.stringify(remaining))
		return

	var metrics: Dictionary = report.get("metrics", {})
	if int(metrics.get("width", 0)) != expected_width or int(metrics.get("height", 0)) != expected_height:
		_fail("Validation metrics did not preserve map dimensions: %s" % JSON.stringify(metrics))
		return
	if int(metrics.get("tile_count", 0)) != expected_width * expected_height:
		_fail("Validation metrics tile count mismatch: %s" % JSON.stringify(metrics))
		return
	if int(metrics.get("player_start_count", 0)) != expected_players:
		_fail("Validation metrics player count mismatch: %s" % JSON.stringify(metrics))
		return
	if int(metrics.get("road_segment_count", 0)) <= 0 or int(metrics.get("object_placement_count", 0)) <= 0 or int(metrics.get("town_count", 0)) < expected_players or int(metrics.get("guard_count", 0)) <= 0:
		_fail("Validation metrics missed expected generated components: %s" % JSON.stringify(metrics))
		return

	var signatures: Dictionary = generated.get("component_signatures", {})
	for key in ["terrain_grid", "zone_layout", "player_starts", "road_network", "river_network", "object_placement", "town_guard_placement", "town_guard_occupancy"]:
		if String(signatures.get(key, "")) == "":
			_fail("Missing component signature %s: %s" % [key, JSON.stringify(signatures)])
			return
	if String(generated.get("terrain_grid", {}).get("signature", "")) != String(signatures.get("terrain_grid", "")):
		_fail("Terrain signature did not match component signatures.")
		return
	if String(report.get("route_reachability_status", "")) != "pass":
		_fail("Validation report did not preserve route reachability pass.")
		return

	var phase_names := {}
	for phase in generated.get("phase_pipeline", []):
		if phase is Dictionary:
			phase_names[String(phase.get("component", ""))] = String(phase.get("validation_status", ""))
	for required in ["terrain_grid", "zone_layout", "player_starts", "route_graph", "road_network", "river_network", "object_placement", "town_placement", "guard_placement", "validation_provenance"]:
		if not phase_names.has(required) or String(phase_names.get(required, "")) != "pass":
			_fail("Phase pipeline missed passing component %s: %s" % [required, JSON.stringify(generated.get("phase_pipeline", []))])
			return

	var provenance: Dictionary = generated.get("provenance", {})
	if String(provenance.get("schema_id", "")) != "aurelion_native_random_map_provenance_v1":
		_fail("Provenance schema mismatch: %s" % JSON.stringify(provenance))
		return
	if String(provenance.get("generator_version", "")) == "" or String(provenance.get("normalized_seed", "")) == "":
		_fail("Provenance missed generator version or seed: %s" % JSON.stringify(provenance))
		return
	if String(provenance.get("validation_status", "")) != "pass" or String(provenance.get("full_generation_status", "")) != "not_implemented":
		_fail("Provenance status mismatch: %s" % JSON.stringify(provenance))
		return
	if String(provenance.get("full_output_signature", "")) != String(generated.get("full_output_signature", "")):
		_fail("Provenance full output signature did not match top-level signature.")
		return
	var boundaries: Dictionary = provenance.get("boundaries", {})
	for boundary in ["authored_content_writeback", "authored_tile_writeback", "save_schema_write", "runtime_call_site_adoption", "package_session_adoption", "full_parity_claim"]:
		if bool(boundaries.get(boundary, true)):
			_fail("Provenance boundary %s was not false: %s" % [boundary, JSON.stringify(boundaries)])
			return

	var map_metadata: Dictionary = generated.get("map_metadata", {})
	if String(map_metadata.get("validation_status", "")) != "pass" or bool(map_metadata.get("no_authored_writeback", false)) != true:
		_fail("Map metadata did not carry validation/no-write provenance: %s" % JSON.stringify(map_metadata))
		return

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
