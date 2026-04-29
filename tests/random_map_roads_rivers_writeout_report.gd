extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_ROADS_RIVERS_WRITEOUT_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var land_config := _land_config("roads-rivers-writeout-10184")
	var report: Dictionary = generator.roads_rivers_writeout_report(land_config)
	if not bool(report.get("ok", false)):
		_fail("Roads/rivers/writeout report failed: %s" % JSON.stringify(report))
		return
	if not bool(report.get("same_input_roads_rivers_writeout_signature_equivalent", false)):
		_fail("Same seed/template did not preserve roads/rivers/writeout signature.")
		return
	if not bool(report.get("changed_seed_changes_roads_rivers_writeout_signature", false)):
		_fail("Changed seed did not change roads/rivers/writeout signature.")
		return

	var generated: Dictionary = generator.generate(land_config)
	if not bool(generated.get("ok", false)):
		_fail("Generated land payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var writeout: Dictionary = payload.get("staging", {}).get("roads_rivers_writeout", {})
	if not _assert_road_overlay(payload, writeout):
		return
	if not _assert_land_no_river_state(writeout):
		return
	if not _assert_serialization(payload, writeout):
		return
	if not _assert_payload_boundaries(payload):
		return

	var water_payload: Dictionary = generator.generate(_water_config("roads-rivers-writeout-water-10184")).get("generated_map", {})
	if not _assert_payload_boundaries(water_payload):
		return
	var water_writeout: Dictionary = water_payload.get("staging", {}).get("roads_rivers_writeout", {})
	if not _assert_water_overlay_metadata(water_writeout):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"roads_rivers_writeout_signature": writeout.get("roads_rivers_writeout_signature", ""),
		"road_summary": writeout.get("road_overlay", {}).get("summary", {}),
		"river_summary": writeout.get("river_water_coast_overlay", {}).get("summary", {}),
		"serialization_signature": writeout.get("generated_map_serialization", {}).get("round_trip_signature", ""),
		"round_trip": writeout.get("round_trip_validation", {}),
		"water_summary": water_writeout.get("river_water_coast_overlay", {}).get("summary", {}),
	})])
	get_tree().quit(0)

func _land_config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "roads_rivers_writeout", "width": 26, "height": 18, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
		},
	}

func _water_config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "roads_rivers_writeout_water", "width": 36, "height": 30, "water_mode": "islands", "level_count": 1},
		"player_constraints": {"human_count": 2, "player_count": 4, "team_mode": "free_for_all"},
		"profile": {
			"id": "translated_rmg_profile_001_v1",
			"template_id": "translated_rmg_template_001_v1",
			"guard_strength_profile": "core_low",
			"terrain_ids": ["grass", "plains", "forest", "swamp", "highland"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}

func _assert_road_overlay(payload: Dictionary, writeout: Dictionary) -> bool:
	if String(writeout.get("schema_id", "")) != RandomMapGeneratorRulesScript.ROADS_RIVERS_WRITEOUT_SCHEMA_ID:
		_fail("Missing roads/rivers/writeout schema payload: %s" % JSON.stringify(writeout))
		return false
	var road: Dictionary = writeout.get("road_overlay", {})
	if road.get("tiles", []).is_empty() or road.get("segments", []).is_empty():
		_fail("Road overlay missed tiles or segments: %s" % JSON.stringify(road.get("summary", {})))
		return false
	if int(road.get("summary", {}).get("body_conflict_count", 0)) != 0:
		_fail("Road overlay crossed footprint bodies: %s" % JSON.stringify(road.get("summary", {})))
		return false
	var road_ids := {}
	for edge_id in road.get("route_edge_ids", []):
		road_ids[String(edge_id)] = true
	for edge in payload.get("staging", {}).get("route_graph", {}).get("edges", []):
		if not (edge is Dictionary) or not bool(edge.get("required", false)) or not bool(edge.get("path_found", false)):
			continue
		if not road_ids.has(String(edge.get("id", ""))):
			_fail("Required route has no road overlay cells: %s" % JSON.stringify(edge))
			return false
	for tile in road.get("tiles", []):
		if not (tile is Dictionary):
			_fail("Road tile is invalid.")
			return false
		if String(tile.get("passability", "")) != "passable" or bool(tile.get("body_conflict", true)):
			_fail("Road tile was not passable or crossed a body: %s" % JSON.stringify(tile))
			return false
		if String(tile.get("road_type_id", "")) == "" or String(tile.get("road_class", "")) == "":
			_fail("Road tile missed deterministic class/type metadata: %s" % JSON.stringify(tile))
			return false
	return true

func _assert_land_no_river_state(writeout: Dictionary) -> bool:
	var river: Dictionary = writeout.get("river_water_coast_overlay", {})
	if river.get("explicit_no_river_state", {}).is_empty():
		_fail("Land config did not expose explicit no-river state: %s" % JSON.stringify(river))
		return false
	if String(river.get("explicit_no_river_state", {}).get("state", "")) != "explicit_land_no_river_overlay_candidates":
		_fail("Land config no-river state used unexpected marker: %s" % JSON.stringify(river.get("explicit_no_river_state", {})))
		return false
	return true

func _assert_water_overlay_metadata(writeout: Dictionary) -> bool:
	var river: Dictionary = writeout.get("river_water_coast_overlay", {})
	if String(river.get("water_mode", "")) != "islands":
		_fail("Water config did not preserve island mode in overlay metadata: %s" % JSON.stringify(river))
		return false
	if int(river.get("summary", {}).get("water_tile_count", 0)) <= 0 or int(river.get("summary", {}).get("coast_tile_count", 0)) <= 0:
		_fail("Water config missed water/coast overlay metadata: %s" % JSON.stringify(river.get("summary", {})))
		return false
	if int(river.get("summary", {}).get("river_candidate_count", 0)) <= 0:
		_fail("Water config missed deferred river/water transit candidates: %s" % JSON.stringify(river))
		return false
	for candidate in river.get("river_candidates", []):
		if candidate is Dictionary and String(candidate.get("writeout_state", "")) == "final_generated_river_candidate_tile_bytes_written":
			return true
	_fail("River/water candidates did not preserve final generated writeout metadata.")
	return false

func _assert_serialization(payload: Dictionary, writeout: Dictionary) -> bool:
	var serialization: Dictionary = writeout.get("generated_map_serialization", {})
	if String(serialization.get("schema_id", "")) != RandomMapGeneratorRulesScript.GENERATED_MAP_SERIALIZATION_SCHEMA_ID:
		_fail("Generated map serialization schema mismatch: %s" % JSON.stringify(serialization))
		return false
	if serialization.get("terrain_layers", []).is_empty() or serialization.get("overlay_layers", []).is_empty() or serialization.get("object_instances", []).is_empty():
		_fail("Serialization missed terrain, overlays, or objects: %s" % JSON.stringify(serialization))
		return false
	if serialization.get("final_tile_stream", []).is_empty() or serialization.get("object_writeout_records", []).is_empty():
		_fail("Serialization missed final tile stream or object writeout records: %s" % JSON.stringify(serialization))
		return false
	if String(serialization.get("tile_stream_signature", "")) == "" or String(serialization.get("object_writeout_signature", "")) == "":
		_fail("Serialization missed durable writeout signatures: %s" % JSON.stringify(serialization))
		return false
	var provenance: Dictionary = serialization.get("provenance", {})
	for key in ["template_id", "profile_id", "normalized_seed", "content_manifest_fingerprint"]:
		if String(provenance.get(key, "")) == "":
			_fail("Serialization missed provenance key %s: %s" % [key, JSON.stringify(provenance)])
			return false
	if String(serialization.get("generator_version", "")) == "":
		_fail("Serialization missed generator version.")
		return false
	var completeness: Dictionary = serialization.get("writeout_completeness", {}) if serialization.get("writeout_completeness", {}) is Dictionary else {}
	for key in ["terrain_tile_bytes", "road_tile_bytes", "river_tile_bytes", "object_instances", "multi_tile_bodies", "round_trip_without_staging_metadata"]:
		if not bool(completeness.get(key, false)):
			_fail("Serialization missed writeout completeness key %s: %s" % [key, JSON.stringify(completeness)])
			return false
	if bool(serialization.get("validation_status", {}).get("staging_metadata_required_for_round_trip", true)):
		_fail("Serialization still requires staging metadata for round-trip.")
		return false
	var saw_body_instance := false
	for instance in serialization.get("object_instances", []):
		if instance is Dictionary and not instance.get("multitile_body_writeout", {}).is_empty():
			saw_body_instance = true
			break
	if not saw_body_instance:
		_fail("Object instance serialization did not preserve durable multi-tile/writeout state.")
		return false
	var round_trip: Dictionary = writeout.get("round_trip_validation", {})
	if String(round_trip.get("status", "")) != "pass" or not bool(round_trip.get("signature_stable", false)) or not bool(round_trip.get("key_counts_stable", false)):
		_fail("Serialization round-trip was not stable: %s" % JSON.stringify(round_trip))
		return false
	if payload.get("scenario_record", {}).get("generated_constraints", {}).get("roads_rivers_writeout", {}).is_empty():
		_fail("Scenario generated_constraints missed roads/rivers/writeout.")
		return false
	return true

func _assert_payload_boundaries(payload: Dictionary) -> bool:
	if payload.is_empty():
		_fail("Expected generated payload.")
		return false
	if String(payload.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
		_fail("Generated payload lost generated export no-write policy.")
		return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Roads/rivers/writeout adopted generated map into campaign or skirmish UI.")
		return false
	if scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or payload.has("save_adoption"):
		_fail("Roads/rivers/writeout exposed save/writeback/parity claim metadata.")
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
