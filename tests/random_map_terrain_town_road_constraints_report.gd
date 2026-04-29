extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_TERRAIN_TOWN_ROAD_CONSTRAINTS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "terrain-town-road-10184",
		"size": {"preset": "constraint_test", "width": 22, "height": 14},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "terrain_town_road_constraint_profile",
			"label": "Terrain Town Road Constraint Profile",
			"terrain_ids": ["grass", "plains", "forest", "swamp", "highland", "water"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
			"guard_strength_profile": "core_low",
		},
	}

	var generator = RandomMapGeneratorRulesScript.new()
	var report: Dictionary = generator.seed_determinism_report(config)
	if not bool(report.get("ok", false)):
		_fail("Determinism report failed: %s" % JSON.stringify(report))
		return

	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated constraints validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var staging: Dictionary = payload.get("staging", {})
	var terrain: Dictionary = staging.get("terrain_constraints", {})
	var starts: Dictionary = staging.get("town_start_constraints", {})
	var roads: Dictionary = staging.get("road_network", {})
	var route_graph: Dictionary = staging.get("route_graph", {})
	var proof: Dictionary = staging.get("route_reachability_proof", {})

	if String(terrain.get("coherence_model", "")) == "":
		_fail("Terrain constraints did not expose a coherence model.")
		return
	if terrain.get("passability_grid", []).is_empty() or terrain.get("zone_biome_summary", []).is_empty():
		_fail("Terrain constraints missed passability grid or zone biome summary.")
		return
	for zone_summary in terrain.get("zone_biome_summary", []):
		if zone_summary is Dictionary and String(zone_summary.get("role", "")).contains("start") and not bool(zone_summary.get("passable", false)):
			_fail("Start zone used impassable terrain: %s" % JSON.stringify(zone_summary))
			return

	if starts.get("player_starts", []).size() != 3:
		_fail("Expected one viable primary town/start per player slot.")
		return
	for start in starts.get("player_starts", []):
		if not (start is Dictionary) or String(start.get("viability", "")) != "pass":
			_fail("Start viability failed: %s" % JSON.stringify(start))
			return
		if start.get("approach_tiles", []).size() < int(start.get("minimum_approach_tiles_required", 2)):
			_fail("Start did not reserve required approach tiles: %s" % JSON.stringify(start))
			return
		if int(start.get("expansion_route_count", 0)) < 1 or int(start.get("contest_route_count", 0)) < 1:
			_fail("Start missed expansion or contest route metadata: %s" % JSON.stringify(start))
			return

	if String(roads.get("writeout_policy", "")) != "final_generated_tile_stream_no_authored_tile_write":
		_fail("Road payload lost final generated tile-stream boundary.")
		return
	if roads.get("road_segments", []).is_empty() or roads.get("road_stubs", []).is_empty():
		_fail("Road payload missed segments or stubs.")
		return
	if String(proof.get("status", "")) != "pass":
		_fail("Required route reachability proof did not pass: %s" % JSON.stringify(proof))
		return

	var classifications := {}
	for edge in route_graph.get("edges", []):
		if edge is Dictionary:
			classifications[String(edge.get("connectivity_classification", ""))] = true
			if bool(edge.get("required", false)) and not bool(edge.get("path_found", false)):
				_fail("Required route edge has no path: %s" % JSON.stringify(edge))
				return
	if not classifications.has("guarded_connectivity") or not classifications.has("full_connectivity"):
		_fail("Route graph did not distinguish guarded and full connectivity: %s" % JSON.stringify(classifications))
		return

	if not _assert_roads_avoid_blocked_cells(roads, payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"terrain_counts": terrain.get("terrain_counts", {}),
		"region_count_by_terrain": terrain.get("region_count_by_terrain", {}),
		"start_count": starts.get("player_starts", []).size(),
		"road_segment_count": roads.get("road_segments", []).size(),
		"route_edge_count": route_graph.get("edges", []).size(),
		"reachability": proof,
		"validation": generated.get("report", {}),
	})])
	get_tree().quit(0)

func _assert_roads_avoid_blocked_cells(roads: Dictionary, payload: Dictionary) -> bool:
	var terrain_rows: Array = payload.get("scenario_record", {}).get("map", [])
	var occupied := {}
	for placement in payload.get("staging", {}).get("object_placements", []):
		if not (placement is Dictionary):
			continue
		for body in placement.get("body_tiles", []):
			if body is Dictionary:
				occupied["%d,%d" % [int(body.get("x", 0)), int(body.get("y", 0))]] = true
	for segment in roads.get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if not (cell is Dictionary):
				_fail("Road segment has invalid cell payload.")
				return false
			var x := int(cell.get("x", -1))
			var y := int(cell.get("y", -1))
			if y < 0 or y >= terrain_rows.size() or not (terrain_rows[y] is Array) or x < 0 or x >= terrain_rows[y].size():
				_fail("Road cell left map bounds: %s" % JSON.stringify(cell))
				return false
			if String(terrain_rows[y][x]) == "water":
				_fail("Road crossed impassable water at %d,%d." % [x, y])
				return false
			if occupied.has("%d,%d" % [x, y]):
				_fail("Road crossed blocked object body at %d,%d." % [x, y])
				return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
