extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_ROAD_RIVER_REPORT"

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
	if not capabilities.has("native_random_map_road_river_network_foundation"):
		_fail("Native road/river capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := {
		"seed": "native-rmg-road-river-network-10184",
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
			"id": "native_road_river_profile",
			"template_id": "native_foundation_spoke",
			"terrain_ids": ["grass", "dirt", "rough", "snow"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}
	var changed_seed_config := config.duplicate(true)
	changed_seed_config["seed"] = "native-rmg-road-river-network-10184-changed"

	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	var changed: Dictionary = service.generate_random_map(changed_seed_config)

	_assert_network_shape(first, 40, 36, 4)
	_assert_network_shape(second, 40, 36, 4)
	_assert_network_shape(changed, 40, 36, 4)

	var first_road: Dictionary = first.get("road_network", {})
	var second_road: Dictionary = second.get("road_network", {})
	var changed_road: Dictionary = changed.get("road_network", {})
	var first_river: Dictionary = first.get("river_network", {})
	var second_river: Dictionary = second.get("river_network", {})
	var changed_river: Dictionary = changed.get("river_network", {})
	var road_signature := String(first_road.get("signature", ""))
	var river_signature := String(first_river.get("signature", ""))
	if road_signature == "" or river_signature == "":
		_fail("Road/river signatures must be non-empty.")
		return
	if road_signature != String(second_road.get("signature", "")) or river_signature != String(second_river.get("signature", "")):
		_fail("Same seed/config did not preserve road/river signatures.")
		return
	if road_signature == String(changed_road.get("signature", "")):
		_fail("Changed seed did not change road network signature.")
		return
	if river_signature == String(changed_river.get("signature", "")):
		_fail("Changed seed did not change river network signature.")
		return

	var report: Dictionary = first.get("report", {})
	if String(report.get("road_generation_status", "")) != "roads_generated_foundation":
		_fail("Report did not carry road_generation_status: %s" % JSON.stringify(report))
		return
	if String(report.get("river_generation_status", "")) != "rivers_generated_foundation":
		_fail("Report did not carry river_generation_status: %s" % JSON.stringify(report))
		return
	if String(report.get("route_reachability_status", "")) != "pass":
		_fail("Report did not carry passing route reachability: %s" % JSON.stringify(report))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"full_generation_status": first.get("full_generation_status", ""),
		"road_generation_status": first.get("road_generation_status", ""),
		"river_generation_status": first.get("river_generation_status", ""),
		"road_segment_count": first_road.get("road_segment_count", 0),
		"road_cell_count": first_road.get("road_cell_count", 0),
		"river_segment_count": first_river.get("river_segment_count", 0),
		"river_cell_count": first_river.get("river_cell_count", 0),
		"route_reachability_status": first_road.get("route_reachability_proof", {}).get("status", ""),
		"start_coverage": first_road.get("required_start_coverage", {}),
		"road_signature": road_signature,
		"changed_road_signature": changed_road.get("signature", ""),
		"river_signature": river_signature,
		"changed_river_signature": changed_river.get("signature", ""),
	})])
	get_tree().quit(0)

func _assert_network_shape(generated: Dictionary, expected_width: int, expected_height: int, expected_players: int) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG road/river generation returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "partial_foundation":
		_fail("Road/river slice did not preserve partial_foundation status.")
		return
	if String(generated.get("full_generation_status", "")) != "not_implemented":
		_fail("Road/river slice falsely implied full generation.")
		return
	if String(generated.get("road_generation_status", "")) != "roads_generated_foundation":
		_fail("Missing top-level road_generation_status.")
		return
	if String(generated.get("river_generation_status", "")) != "rivers_generated_foundation":
		_fail("Missing top-level river_generation_status.")
		return

	var road: Dictionary = generated.get("road_network", {})
	if String(road.get("schema_id", "")) != "aurelion_native_rmg_road_network_v1":
		_fail("Road network schema mismatch: %s" % JSON.stringify(road))
		return
	if String(road.get("generation_status", "")) != "roads_generated_foundation":
		_fail("Road network generation status mismatch.")
		return
	if String(road.get("writeout_policy", "")) != "final_generated_tile_stream_no_authored_tile_write":
		_fail("Road network missed no-authored-write boundary.")
		return
	var route_graph: Dictionary = road.get("route_graph", {})
	if String(route_graph.get("schema_id", "")) != "aurelion_native_rmg_route_graph_v1":
		_fail("Route graph schema mismatch: %s" % JSON.stringify(route_graph))
		return
	if String(route_graph.get("signature", "")) == "":
		_fail("Route graph signature missing.")
		return
	if route_graph.get("edges", []).is_empty() or route_graph.get("nodes", {}).is_empty():
		_fail("Route graph must expose nodes and edges.")
		return
	if String(road.get("route_reachability_proof", {}).get("status", "")) != "pass":
		_fail("Road reachability proof did not pass: %s" % JSON.stringify(road.get("route_reachability_proof", {})))
		return
	var coverage: Dictionary = road.get("required_start_coverage", {})
	if int(coverage.get("expected_player_start_count", 0)) != expected_players or int(coverage.get("covered_player_start_count", 0)) != expected_players:
		_fail("Road network did not cover expected player starts: %s" % JSON.stringify(coverage))
		return
	if int(road.get("road_segment_count", 0)) <= 0 or int(road.get("road_cell_count", 0)) <= 0:
		_fail("Road network did not emit staged road segments.")
		return
	for segment in road.get("road_segments", []):
		if not (segment is Dictionary):
			_fail("Non-dictionary road segment.")
			return
		if String(segment.get("route_edge_id", "")) == "" or int(segment.get("cell_count", 0)) <= 0:
			_fail("Road segment missed route id or cells: %s" % JSON.stringify(segment))
			return
		_assert_cells_valid(segment.get("cells", []), expected_width, expected_height, "road segment %s" % String(segment.get("id", "")))

	var river: Dictionary = generated.get("river_network", {})
	if String(river.get("schema_id", "")) != "aurelion_native_rmg_river_network_v1":
		_fail("River network schema mismatch: %s" % JSON.stringify(river))
		return
	if String(river.get("generation_status", "")) != "rivers_generated_foundation":
		_fail("River network generation status mismatch.")
		return
	if String(river.get("signature", "")) == "":
		_fail("River network signature missing.")
		return
	if bool(river.get("policy", {}).get("enabled", false)) and (int(river.get("river_segment_count", 0)) <= 0 or int(river.get("river_cell_count", 0)) <= 0):
		_fail("Enabled river/waterline policy produced no bounded cells.")
		return
	for segment in river.get("river_segments", []):
		if not (segment is Dictionary):
			_fail("Non-dictionary river segment.")
			return
		if int(segment.get("cell_count", 0)) <= 0:
			_fail("River segment has no cells: %s" % JSON.stringify(segment))
			return
		_assert_cells_valid(segment.get("cells", []), expected_width, expected_height, "river segment %s" % String(segment.get("id", "")))

func _assert_cells_valid(cells: Array, width: int, height: int, label: String) -> void:
	if cells.is_empty():
		_fail("%s emitted no cells." % label)
		return
	for cell in cells:
		if not (cell is Dictionary):
			_fail("%s emitted a non-dictionary cell." % label)
			return
		var x := int(cell.get("x", -1))
		var y := int(cell.get("y", -1))
		var level := int(cell.get("level", -1))
		if x < 0 or x >= width or y < 0 or y >= height or level != 0:
			_fail("%s emitted out-of-bounds cell: %s" % [label, JSON.stringify(cell)])
			return

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
