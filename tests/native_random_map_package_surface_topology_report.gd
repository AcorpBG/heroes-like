extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_PACKAGE_SURFACE_TOPOLOGY_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_package_surface_topology_report_v1"

const OWNER_SMALL_BASELINE := {
	"source": "strict_h3maped_small_validator_gated_package_surface_floor",
	"width": 36,
	"height": 36,
	"level_count": 1,
	"zone_count": 6,
	"town_count": 4,
	"player_start_town_count": 3,
	"neutral_town_count": 1,
	"route_link_count": 5,
	"guarded_route_link_count": 5,
	"min_guard_count": 6,
	"min_object_count": 40,
	"min_road_cell_count": 35,
	"road_route_edge_count": 6,
	"road_route_node_count": 4,
	"road_component_count": 1,
	"min_road_segment_cell_count": 8,
	"min_nearest_town_manhattan": 8,
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"1",
		"",
		"",
		3,
		"land",
		false,
		"homm3_small"
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "package_surface_topology_small"})
	var fast_validator: Dictionary = generated.get("fast_structural_validator", {}) if generated.get("fast_structural_validator", {}) is Dictionary else {}
	if not bool(generated.get("ok", false)) \
			or String(generated.get("status", "")) != "h3maped_small_validated_package_ready" \
			or String(fast_validator.get("status", "")) != "strict_fast_structural_validator_pass_public_generation_ready" \
			or int(fast_validator.get("failure_count", -1)) != 0:
		_fail("Player-facing Small generation failed before package topology analysis: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_package_surface_topology_report",
		"session_save_version": 9,
		"scenario_id": "native_package_surface_topology_small",
	})
	if not bool(adoption.get("ok", false)):
		_fail("convert_generated_payload failed: %s" % JSON.stringify(adoption))
		return
	var converted_document: Variant = adoption.get("map_document", null)
	if converted_document == null:
		_fail("convert_generated_payload missed map_document.")
		return
	var converted_surface := _package_surface_summary(converted_document, "converted_package")
	if not _assert_surface(converted_surface):
		return
	var map_path := "user://native_package_surface_topology_small.amap"
	var save_result: Dictionary = service.save_map_package(converted_document, map_path)
	if not bool(save_result.get("ok", false)):
		_fail("save_map_package failed: %s" % JSON.stringify(save_result))
		return
	var load_result: Dictionary = service.load_map_package(map_path)
	DirAccess.remove_absolute(map_path)
	if not bool(load_result.get("ok", false)):
		_fail("load_map_package failed: %s" % JSON.stringify(load_result))
		return
	var loaded_document: Variant = load_result.get("map_document", null)
	if loaded_document == null:
		_fail("load_map_package missed map_document.")
		return
	var loaded_surface := _package_surface_summary(loaded_document, "loaded_package")
	if not _assert_surface(loaded_surface):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"owner_small_baseline": OWNER_SMALL_BASELINE,
		"generated_status": {
			"validation_status": String(fast_validator.get("status", "")),
			"full_generation_status": String(generated.get("full_generation_status", "")),
		},
		"converted_package": converted_surface,
		"loaded_package": loaded_surface,
	})])
	get_tree().quit(0)

func _assert_surface(surface: Dictionary) -> bool:
	var label := String(surface.get("label", "package"))
	if String(surface.get("source_template_authority", "")) != "h3maped_exe_rng" \
			or not String(surface.get("source_template_id", "")).begins_with("h3maped_template_"):
		_fail("%s did not preserve strict h3maped Small executable template provenance: %s" % [label, JSON.stringify(surface)])
		return false
	if int(surface.get("width", 0)) != int(OWNER_SMALL_BASELINE.get("width", 0)) or int(surface.get("height", 0)) != int(OWNER_SMALL_BASELINE.get("height", 0)):
		_fail("%s dimensions drifted from owner Small baseline: %s" % [label, JSON.stringify(surface)])
		return false
	if int(surface.get("zone_count", 0)) != int(OWNER_SMALL_BASELINE.get("zone_count", 0)):
		_fail("%s lost active h3maped Small zone structure: %s" % [label, JSON.stringify(surface)])
		return false
	if int(surface.get("town_count", 0)) != int(OWNER_SMALL_BASELINE.get("town_count", 0)) \
			or int(surface.get("player_start_town_count", 0)) != int(OWNER_SMALL_BASELINE.get("player_start_town_count", 0)) \
			or int(surface.get("neutral_town_count", -1)) != int(OWNER_SMALL_BASELINE.get("neutral_town_count", 0)) \
			or int(surface.get("guard_count", 0)) < int(OWNER_SMALL_BASELINE.get("min_guard_count", 0)):
		_fail("%s lost active h3maped Small town or guard coverage: %s" % [label, JSON.stringify(surface)])
		return false
	if int(surface.get("route_link_count", 0)) != int(OWNER_SMALL_BASELINE.get("route_link_count", 0)) \
			or int(surface.get("guarded_route_link_count", 0)) != int(OWNER_SMALL_BASELINE.get("guarded_route_link_count", 0)):
		_fail("%s route link graph drifted from h3maped Small template links: %s" % [label, JSON.stringify(surface)])
		return false
	if int(surface.get("object_count", 0)) < int(OWNER_SMALL_BASELINE.get("min_object_count", 0)):
		_fail("%s object density fell below the active h3maped Small floor: %s" % [label, JSON.stringify(surface)])
		return false
	if int(surface.get("road_unique_tile_count", 0)) < int(OWNER_SMALL_BASELINE.get("min_road_cell_count", 0)):
		_fail("%s road materialization fell below the active h3maped Small floor: %s" % [label, JSON.stringify(surface)])
		return false
	if int(surface.get("road_unique_tile_count", 0)) != int(surface.get("source_road_cell_count", 0)):
		_fail("%s unique package road tiles do not match native source road cells: %s" % [label, JSON.stringify(surface)])
		return false
	if int(surface.get("zero_tile_road_count", 0)) != 0 \
			or int(surface.get("road_segment_cell_count", 0)) < int(surface.get("road_unique_tile_count", 0)):
		_fail("%s serialized empty or invalid route road records: %s" % [label, JSON.stringify(surface)])
		return false
	var road_infrastructure: Dictionary = surface.get("road_infrastructure", {}) if surface.get("road_infrastructure", {}) is Dictionary else {}
	if int(road_infrastructure.get("route_edge_count", 0)) != int(OWNER_SMALL_BASELINE.get("road_route_edge_count", 0)) \
			or int(road_infrastructure.get("route_node_count", 0)) != int(OWNER_SMALL_BASELINE.get("road_route_node_count", 0)) \
			or String(road_infrastructure.get("route_graph_status", "")) != "h3maped_town_route_segments_connected":
		_fail("%s road route graph is not the expected h3maped town-route infrastructure: %s" % [label, JSON.stringify(road_infrastructure)])
		return false
	if int(road_infrastructure.get("road_component_count", 0)) != int(OWNER_SMALL_BASELINE.get("road_component_count", 0)) \
			or int(road_infrastructure.get("disconnected_segment_count", 0)) != 0 \
			or int(road_infrastructure.get("missing_edge_reference_count", 0)) != 0 \
			or int(road_infrastructure.get("missing_node_reference_count", 0)) != 0 \
			or int(road_infrastructure.get("endpoint_mismatch_count", 0)) != 0 \
			or int(road_infrastructure.get("short_segment_count", 0)) != 0:
		_fail("%s road records do not behave as connected route infrastructure: %s" % [label, JSON.stringify(road_infrastructure)])
		return false
	var route_node_zone_summary: Dictionary = surface.get("route_node_zone_summary", {}) if surface.get("route_node_zone_summary", {}) is Dictionary else {}
	if int(route_node_zone_summary.get("missing_town_reference_count", 0)) != 0 \
			or int(route_node_zone_summary.get("unknown_runtime_zone_count", 0)) != 0 \
			or int(route_node_zone_summary.get("zone_mismatch_count", 0)) != 0:
		_fail("%s route graph nodes lost their h3maped town runtime zones: %s" % [label, JSON.stringify(route_node_zone_summary)])
		return false
	var player_slots: Dictionary = surface.get("player_start_towns_by_slot", {}) if surface.get("player_start_towns_by_slot", {}) is Dictionary else {}
	for slot in ["1", "2", "3"]:
		var towns: Array = player_slots.get(slot, []) if player_slots.get(slot, []) is Array else []
		if towns.size() != 1:
			_fail("%s expected exactly one player start town for slot %s, got %d: %s" % [label, slot, towns.size(), JSON.stringify(player_slots)])
			return false
	var start_zone_ids := {}
	for slot in ["1", "2", "3"]:
		var towns: Array = player_slots.get(slot, []) if player_slots.get(slot, []) is Array else []
		if towns.size() == 1:
			start_zone_ids[String(towns[0].get("zone_id", ""))] = true
	if start_zone_ids.size() != 3:
		_fail("%s player start towns are not in distinct h3maped zones: %s" % [label, JSON.stringify(player_slots)])
		return false
	if int(surface.get("nearest_player_start_town_manhattan", 0)) < int(OWNER_SMALL_BASELINE.get("min_nearest_town_manhattan", 0)) or int(surface.get("nearest_town_manhattan", 0)) < int(OWNER_SMALL_BASELINE.get("min_nearest_town_manhattan", 0)):
		_fail("%s town spacing is too tight for active h3maped Small output: %s" % [label, JSON.stringify(surface)])
		return false
	var topology: Dictionary = surface.get("unresolved_start_town_topology", {}) if surface.get("unresolved_start_town_topology", {}) is Dictionary else {}
	if not topology.get("reachable_pairs", []).is_empty():
		_fail("%s unresolved package surface still allows unguarded start-town traversal: %s" % [label, JSON.stringify(surface)])
		return false
	if int(topology.get("checked_pair_count", 0)) < 3:
		_fail("%s did not inspect all player start-town pairs: %s" % [label, JSON.stringify(surface)])
		return false
	var cross_zone_topology: Dictionary = surface.get("unresolved_cross_zone_town_topology", {}) if surface.get("unresolved_cross_zone_town_topology", {}) is Dictionary else {}
	if not cross_zone_topology.get("reachable_pairs", []).is_empty():
		_fail("%s unresolved package surface still allows unguarded cross-zone town traversal: %s" % [label, JSON.stringify(surface)])
		return false
	var object_only_topology: Dictionary = surface.get("object_only_start_town_topology", {}) if surface.get("object_only_start_town_topology", {}) is Dictionary else {}
	if not object_only_topology.get("reachable_pairs", []).is_empty():
		_fail("%s object masks alone still allow unguarded start-town traversal: %s" % [label, JSON.stringify(surface)])
		return false
	if int(object_only_topology.get("checked_pair_count", 0)) < 3:
		_fail("%s object-only topology did not inspect all player start-town pairs: %s" % [label, JSON.stringify(surface)])
		return false
	var unresolved_cross_zone_topology: Dictionary = surface.get("unresolved_cross_zone_town_topology", {}) if surface.get("unresolved_cross_zone_town_topology", {}) is Dictionary else {}
	if not unresolved_cross_zone_topology.get("reachable_pairs", []).is_empty():
		_fail("%s package terrain and object masks still allow unguarded cross-zone town traversal: %s" % [label, JSON.stringify(surface)])
		return false
	var unresolved_all_town_topology: Dictionary = surface.get("unresolved_town_topology", {}) if surface.get("unresolved_town_topology", {}) is Dictionary else {}
	if not unresolved_all_town_topology.get("reachable_pairs", []).is_empty():
		_fail("%s package terrain and object masks still allow unguarded all-town traversal: %s" % [label, JSON.stringify(surface)])
		return false
	var town_count := int(surface.get("town_count", 0))
	var required_all_town_pairs := town_count * (town_count - 1) / 2
	if int(unresolved_all_town_topology.get("checked_pair_count", 0)) < required_all_town_pairs:
		_fail("%s unresolved topology did not inspect every town pair: %s" % [label, JSON.stringify(surface)])
		return false
	return true

func _package_surface_summary(map_document: Variant, label: String) -> Dictionary:
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var metadata: Dictionary = map_document.get_metadata()
	var normalized: Dictionary = metadata.get("normalized_config", {}) if metadata.get("normalized_config", {}) is Dictionary else {}
	var component_counts: Dictionary = metadata.get("component_counts", {}) if metadata.get("component_counts", {}) is Dictionary else {}
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var road_summary := _road_summary(roads)
	var object_summary := _object_summary(map_document)
	var route_graph: Dictionary = map_document.get_route_graph()
	var terrain_blocked := _terrain_blocked_tiles(map_document, terrain_layers)
	var road_infrastructure := _road_infrastructure_summary(route_graph, roads)
	var route_node_zone_summary := _route_node_zone_summary(route_graph, object_summary.get("towns", []))
	var unresolved_blocked := _package_blocked_tiles(map_document, terrain_blocked)
	var object_only_blocked := _package_blocked_tiles(map_document, {})
	var topology := _start_town_topology(
		unresolved_blocked,
		int(map_document.get_width()),
		int(map_document.get_height()),
		int(map_document.get_level_count()),
		object_summary.get("player_start_towns", [])
	)
	var object_only_topology := _start_town_topology(
		object_only_blocked,
		int(map_document.get_width()),
		int(map_document.get_height()),
		int(map_document.get_level_count()),
		object_summary.get("player_start_towns", [])
	)
	var all_town_topology := _town_pair_topology(
		unresolved_blocked,
		int(map_document.get_width()),
		int(map_document.get_height()),
		int(map_document.get_level_count()),
		object_summary.get("towns", []),
		false
	)
	var object_only_all_town_topology := _town_pair_topology(
		object_only_blocked,
		int(map_document.get_width()),
		int(map_document.get_height()),
		int(map_document.get_level_count()),
		object_summary.get("towns", []),
		false
	)
	var cross_zone_topology := _cross_zone_town_topology(
		unresolved_blocked,
		int(map_document.get_width()),
		int(map_document.get_height()),
		int(map_document.get_level_count()),
		object_summary.get("towns", [])
	)
	var object_only_cross_zone_topology := _cross_zone_town_topology(
		object_only_blocked,
		int(map_document.get_width()),
		int(map_document.get_height()),
		int(map_document.get_level_count()),
		object_summary.get("towns", [])
	)
	return {
		"label": label,
		"width": int(map_document.get_width()),
		"height": int(map_document.get_height()),
		"level_count": int(map_document.get_level_count()),
		"zone_count": int(component_counts.get("zone_count", 0)),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"source_template_id": String(metadata.get("source_template_id", "")),
		"source_template_authority": String(metadata.get("source_template_authority", "")),
		"road_count": roads.size(),
		"road_tile_count": int(road_summary.get("road_tile_count", 0)),
		"road_unique_tile_count": int(road_summary.get("road_unique_tile_count", 0)),
		"road_duplicate_tile_count": int(road_summary.get("road_duplicate_tile_count", 0)),
		"source_road_cell_count": int(component_counts.get("road_cell_count", 0)),
		"road_segment_cell_count": int(component_counts.get("road_segment_cell_count", road_summary.get("road_tile_count", 0))),
		"source_road_duplicate_tile_count": int(component_counts.get("road_duplicate_tile_count", 0)),
		"zero_tile_road_count": int(road_summary.get("zero_tile_road_count", 0)),
		"road_infrastructure": road_infrastructure,
		"route_node_zone_summary": route_node_zone_summary,
		"object_count": int(map_document.get_object_count()),
		"town_count": int(object_summary.get("town_count", 0)),
		"player_start_town_count": int(object_summary.get("player_start_town_count", 0)),
		"neutral_town_count": int(object_summary.get("neutral_town_count", 0)),
		"guard_count": int(object_summary.get("guard_count", 0)),
		"route_link_count": int(route_graph.get("link_count", 0)),
		"guarded_route_link_count": int(route_graph.get("guarded_link_count", 0)),
		"nearest_town_manhattan": int(object_summary.get("nearest_town_manhattan", 0)),
		"nearest_player_start_town_manhattan": int(object_summary.get("nearest_player_start_town_manhattan", 0)),
		"player_start_towns_by_slot": object_summary.get("player_start_towns_by_slot", {}),
		"towns": object_summary.get("towns", []),
		"connection_blockers": object_summary.get("connection_blockers", []),
		"connection_guards": object_summary.get("connection_guards", []),
		"object_counts_by_kind": object_summary.get("object_counts_by_kind", {}),
		"terrain_blocked_tile_count": terrain_blocked.size(),
		"unresolved_blocked_tile_count": unresolved_blocked.size(),
		"object_only_blocked_tile_count": object_only_blocked.size(),
		"unresolved_start_town_topology": topology,
		"unresolved_town_topology": all_town_topology,
		"unresolved_cross_zone_town_topology": cross_zone_topology,
		"object_only_start_town_topology": object_only_topology,
		"object_only_town_topology": object_only_all_town_topology,
		"object_only_cross_zone_town_topology": object_only_cross_zone_topology,
	}

func _road_summary(roads: Array) -> Dictionary:
	var road_tile_count := 0
	var zero_tile_road_count := 0
	var road_duplicate_tile_count := 0
	var road_tile_lookup := {}
	for road in roads:
		if not (road is Dictionary):
			continue
		var tile_count := int(road.get("tile_count", road.get("cell_count", 0)))
		road_tile_count += tile_count
		if tile_count <= 0:
			zero_tile_road_count += 1
		var road_tiles: Array = road.get("tiles", road.get("cells", [])) if road.get("tiles", road.get("cells", [])) is Array else []
		for tile in road_tiles:
			if not (tile is Dictionary):
				continue
			var key := "%d:%d,%d" % [int(tile.get("level", 0)), int(tile.get("x", 0)), int(tile.get("y", 0))]
			if road_tile_lookup.has(key):
				road_duplicate_tile_count += 1
			else:
				road_tile_lookup[key] = true
	return {
		"road_tile_count": road_tile_count,
		"road_unique_tile_count": road_tile_lookup.size(),
		"road_duplicate_tile_count": road_duplicate_tile_count,
		"zero_tile_road_count": zero_tile_road_count,
	}

func _road_infrastructure_summary(route_graph: Dictionary, roads: Array) -> Dictionary:
	var nodes: Dictionary = route_graph.get("nodes", {}) if route_graph.get("nodes", {}) is Dictionary else {}
	var edges: Array = route_graph.get("edges", []) if route_graph.get("edges", []) is Array else []
	var edges_by_id := {}
	for edge in edges:
		if not (edge is Dictionary):
			continue
		var edge_id := String(edge.get("id", ""))
		if not edge_id.is_empty():
			edges_by_id[edge_id] = edge
	var disconnected_segment_count := 0
	var missing_edge_reference_count := 0
	var missing_node_reference_count := 0
	var endpoint_mismatch_count := 0
	var short_segment_count := 0
	var min_segment_cell_count := 999999
	var max_segment_cell_count := 0
	var segment_summaries := []
	var road_tile_lookup := {}
	for road in roads:
		if not (road is Dictionary):
			continue
		var route_edge_id := String(road.get("route_edge_id", ""))
		var edge: Dictionary = edges_by_id.get(route_edge_id, {}) if edges_by_id.get(route_edge_id, {}) is Dictionary else {}
		var cells: Array = road.get("cells", road.get("tiles", [])) if road.get("cells", road.get("tiles", [])) is Array else []
		var connected := _road_cells_connected(cells)
		if not connected or not bool(road.get("connected_cell_chain", true)):
			disconnected_segment_count += 1
		if edge.is_empty():
			missing_edge_reference_count += 1
		var from_node: Dictionary = nodes.get(String(road.get("from_node_id", "")), {}) if nodes.get(String(road.get("from_node_id", "")), {}) is Dictionary else {}
		var to_node: Dictionary = nodes.get(String(road.get("to_node_id", "")), {}) if nodes.get(String(road.get("to_node_id", "")), {}) is Dictionary else {}
		if from_node.is_empty() or to_node.is_empty():
			missing_node_reference_count += 1
		if cells.size() < int(OWNER_SMALL_BASELINE.get("min_road_segment_cell_count", 0)):
			short_segment_count += 1
		if not from_node.is_empty() and not to_node.is_empty() and not _road_endpoints_match_nodes(cells, from_node, to_node):
			endpoint_mismatch_count += 1
		min_segment_cell_count = min(min_segment_cell_count, cells.size())
		max_segment_cell_count = max(max_segment_cell_count, cells.size())
		for cell in cells:
			if cell is Dictionary:
				road_tile_lookup[_tile_key(cell)] = true
		segment_summaries.append({
			"id": String(road.get("id", "")),
			"route_edge_id": route_edge_id,
			"from_node_id": String(road.get("from_node_id", "")),
			"to_node_id": String(road.get("to_node_id", "")),
			"cell_count": cells.size(),
			"connected": connected,
			"endpoints_match_nodes": _road_endpoints_match_nodes(cells, from_node, to_node) if not from_node.is_empty() and not to_node.is_empty() else false,
		})
	if roads.is_empty():
		min_segment_cell_count = 0
	return {
		"route_graph_status": String(route_graph.get("road_infrastructure_status", "")),
		"route_edge_count": edges.size(),
		"route_node_count": nodes.size(),
		"road_component_count": _road_component_count(road_tile_lookup),
		"disconnected_segment_count": disconnected_segment_count,
		"missing_edge_reference_count": missing_edge_reference_count,
		"missing_node_reference_count": missing_node_reference_count,
		"endpoint_mismatch_count": endpoint_mismatch_count,
		"short_segment_count": short_segment_count,
		"min_segment_cell_count": min_segment_cell_count,
		"max_segment_cell_count": max_segment_cell_count,
		"segment_summaries": segment_summaries,
	}

func _route_node_zone_summary(route_graph: Dictionary, towns: Array) -> Dictionary:
	var nodes: Dictionary = route_graph.get("nodes", {}) if route_graph.get("nodes", {}) is Dictionary else {}
	var towns_by_placement := {}
	for town in towns:
		if not (town is Dictionary):
			continue
		var placement_id := String(town.get("placement_id", ""))
		if not placement_id.is_empty():
			towns_by_placement[placement_id] = town
	var missing_town_reference_count := 0
	var unknown_runtime_zone_count := 0
	var zone_mismatch_count := 0
	var node_summaries := []
	for node_id in nodes.keys():
		var node: Dictionary = nodes.get(node_id, {}) if nodes.get(node_id, {}) is Dictionary else {}
		var placement_id := String(node.get("placement_id", ""))
		var town: Dictionary = towns_by_placement.get(placement_id, {}) if towns_by_placement.get(placement_id, {}) is Dictionary else {}
		var node_runtime_zone := _int_value(node.get("runtime_zone_index", -1), -1)
		var town_runtime_zone := _int_value(town.get("runtime_zone_index", -1), -1)
		if town.is_empty():
			missing_town_reference_count += 1
		if node_runtime_zone < 0:
			unknown_runtime_zone_count += 1
		if not town.is_empty() and node_runtime_zone != town_runtime_zone:
			zone_mismatch_count += 1
		node_summaries.append({
			"id": String(node_id),
			"placement_id": placement_id,
			"node_runtime_zone_index": node_runtime_zone,
			"town_runtime_zone_index": town_runtime_zone,
		})
	return {
		"route_node_count": nodes.size(),
		"missing_town_reference_count": missing_town_reference_count,
		"unknown_runtime_zone_count": unknown_runtime_zone_count,
		"zone_mismatch_count": zone_mismatch_count,
		"nodes": node_summaries,
	}

func _road_cells_connected(cells: Array) -> bool:
	if cells.is_empty():
		return false
	var previous: Dictionary = cells[0] if cells[0] is Dictionary else {}
	if previous.is_empty():
		return false
	for index in range(1, cells.size()):
		if not (cells[index] is Dictionary):
			return false
		var current: Dictionary = cells[index]
		if int(current.get("level", 0)) != int(previous.get("level", 0)):
			return false
		if abs(int(current.get("x", 0)) - int(previous.get("x", 0))) > 1 or abs(int(current.get("y", 0)) - int(previous.get("y", 0))) > 1:
			return false
		previous = current
	return true

func _road_endpoints_match_nodes(cells: Array, from_node: Dictionary, to_node: Dictionary) -> bool:
	if cells.is_empty():
		return false
	var first: Dictionary = cells[0] if cells[0] is Dictionary else {}
	var last: Dictionary = cells[cells.size() - 1] if cells[cells.size() - 1] is Dictionary else {}
	if first.is_empty() or last.is_empty():
		return false
	return (_cell_matches_node(first, from_node) and _cell_matches_node(last, to_node)) \
			or (_cell_matches_node(first, to_node) and _cell_matches_node(last, from_node))

func _cell_matches_node(cell: Dictionary, node: Dictionary) -> bool:
	return int(cell.get("level", 0)) == int(node.get("level", 0)) \
			and int(cell.get("x", -1)) == int(node.get("x", -2)) \
			and int(cell.get("y", -1)) == int(node.get("y", -2))

func _road_component_count(road_tile_lookup: Dictionary) -> int:
	var remaining := road_tile_lookup.duplicate()
	var component_count := 0
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	while not remaining.is_empty():
		var start_key := String(remaining.keys()[0])
		var start := _point_from_tile_key(start_key)
		remaining.erase(start_key)
		component_count += 1
		var queue: Array[Vector3i] = [start]
		var cursor := 0
		while cursor < queue.size():
			var current := queue[cursor]
			cursor += 1
			for dir_value in dirs:
				var next := Vector3i(current.x, current.y + dir_value.x, current.z + dir_value.y)
				var key := "%d:%d,%d" % [next.x, next.y, next.z]
				if remaining.has(key):
					remaining.erase(key)
					queue.append(next)
	return component_count

func _point_from_tile_key(key: String) -> Vector3i:
	var parts := key.split(":")
	if parts.size() != 2:
		return Vector3i.ZERO
	var level := int(parts[0])
	var xy := String(parts[1]).split(",")
	if xy.size() != 2:
		return Vector3i(level, 0, 0)
	return Vector3i(level, int(xy[0]), int(xy[1]))

func _tile_key(tile: Dictionary) -> String:
	return "%d:%d,%d" % [int(tile.get("level", 0)), int(tile.get("x", 0)), int(tile.get("y", 0))]

func _object_summary(map_document: Variant) -> Dictionary:
	var counts := {}
	var towns := []
	var connection_blockers := []
	var connection_guards := []
	var player_start_towns := []
	var player_start_towns_by_slot := {}
	var neutral_town_count := 0
	var town_points := []
	var player_start_points := []
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var kind := String(object.get("kind", object.get("native_record_kind", object.get("category_id", "object"))))
		counts[kind] = int(counts.get(kind, 0)) + 1
		if kind == "connection_blocker":
			connection_blockers.append(_brief_connection_object(object))
		elif kind == "guard":
			connection_guards.append(_brief_connection_object(object))
		if kind != "town":
			continue
		var brief := _brief_town(object)
		brief["package_visit_tiles"] = object.get("package_visit_tiles", [])
		towns.append(brief)
		town_points.append(Vector2i(int(object.get("x", 0)), int(object.get("y", 0))))
		var player_slot := _int_value(object.get("player_slot", 0), 0)
		if player_slot <= 0 or String(object.get("record_type", "")) != "player_start_town":
			neutral_town_count += 1
			continue
		var slot_key := str(player_slot)
		if not player_start_towns_by_slot.has(slot_key):
			player_start_towns_by_slot[slot_key] = []
		player_start_towns_by_slot[slot_key].append(brief)
		player_start_towns.append(object)
		player_start_points.append(Vector2i(int(object.get("x", 0)), int(object.get("y", 0))))
	return {
		"object_counts_by_kind": counts,
		"town_count": towns.size(),
		"guard_count": int(counts.get("guard", 0)),
		"towns": towns,
		"player_start_town_count": player_start_towns.size(),
		"neutral_town_count": neutral_town_count,
		"connection_blockers": connection_blockers,
		"connection_guards": connection_guards,
		"player_start_towns": player_start_towns,
		"player_start_towns_by_slot": player_start_towns_by_slot,
		"nearest_town_manhattan": _nearest_manhattan(town_points),
		"nearest_player_start_town_manhattan": _nearest_manhattan(player_start_points),
	}

func _terrain_blocked_tiles(map_document: Variant, terrain_layers: Dictionary) -> Dictionary:
	var blocked := {}
	var terrain: Dictionary = terrain_layers.get("terrain", {}) if terrain_layers.get("terrain", {}) is Dictionary else {}
	var terrain_levels: Array = terrain.get("levels", []) if terrain.get("levels", []) is Array else []
	var ids_by_code: Variant = terrain_layers.get("terrain_id_by_code", terrain_layers.get("terrain_id_by_h3maped_code", []))
	var width := int(map_document.get_width())
	var height := int(map_document.get_height())
	var level_count: int = min(int(map_document.get_level_count()), terrain_levels.size())
	for level_index in range(level_count):
		var codes := _terrain_codes_for_level(terrain_levels[level_index])
		for y in range(height):
			for x in range(width):
				var index := y * width + x
				var terrain_id := _terrain_id_for_code(ids_by_code, int(codes[index]) if index >= 0 and index < codes.size() else 0)
				if terrain_id in ["rock", "water"]:
					blocked["%d:%d,%d" % [level_index, x, y]] = true
	return blocked

func _terrain_codes_for_level(level_record: Variant) -> Array:
	if level_record is Dictionary:
		var values: Variant = level_record.get("terrain_code_u16", [])
		return Array(values)
	if level_record is PackedInt32Array:
		return Array(level_record)
	if level_record is Array:
		return level_record
	return []

func _package_blocked_tiles(map_document: Variant, base_blocked: Dictionary) -> Dictionary:
	var blocked := base_blocked.duplicate(true)
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var block_tiles: Array = object.get("package_block_tiles", []) if object.get("package_block_tiles", []) is Array else []
		for tile in block_tiles:
			if tile is Dictionary:
				blocked["%d:%d,%d" % [int(tile.get("level", 0)), int(tile.get("x", 0)), int(tile.get("y", 0))]] = true
	return blocked

func _start_town_topology(blocked: Dictionary, width: int, height: int, level_count: int, player_start_towns: Array) -> Dictionary:
	return _town_pair_topology(blocked, width, height, level_count, player_start_towns, false)

func _cross_zone_town_topology(blocked: Dictionary, width: int, height: int, level_count: int, towns: Array) -> Dictionary:
	return _town_pair_topology(blocked, width, height, level_count, towns, true)

func _town_pair_topology(blocked: Dictionary, width: int, height: int, level_count: int, towns: Array, cross_zone_only: bool) -> Dictionary:
	var reachable_pairs := []
	var checked_pair_count := 0
	for left_index in range(towns.size()):
		for right_index in range(left_index + 1, towns.size()):
			var left: Dictionary = towns[left_index]
			var right: Dictionary = towns[right_index]
			if cross_zone_only and String(left.get("zone_id", "")) == String(right.get("zone_id", "")):
				continue
			checked_pair_count += 1
			var left_visits := _visit_points_for_town(left, width, height, level_count)
			var right_visits := _visit_points_for_town(right, width, height, level_count)
			if left_visits.is_empty() or right_visits.is_empty():
				reachable_pairs.append({
					"reason": "missing_visit_tiles",
					"left": _brief_town(left),
					"right": _brief_town(right),
				})
				continue
			var reachable_path := _find_any_path(blocked.duplicate(true), width, height, level_count, left_visits, right_visits)
			if not reachable_path.is_empty():
				reachable_pairs.append({
					"left": _brief_town(left),
					"right": _brief_town(right),
					"path_length": reachable_path.size(),
					"path_sample": _path_sample(reachable_path),
				})
	return {
		"checked_pair_count": checked_pair_count,
		"reachable_pairs": reachable_pairs,
		"reachable_pair_count": reachable_pairs.size(),
	}

func _visit_points_for_town(town: Dictionary, width: int, height: int, level_count: int) -> Array:
	var points := []
	var visit_tiles: Array = town.get("package_visit_tiles", []) if town.get("package_visit_tiles", []) is Array else []
	for tile in visit_tiles:
		if not (tile is Dictionary):
			continue
		var point := Vector3i(int(tile.get("level", town.get("level", 0))), int(tile.get("x", 0)), int(tile.get("y", 0)))
		if point.x >= 0 and point.x < max(1, level_count) and point.y >= 0 and point.z >= 0 and point.y < width and point.z < height:
			points.append(point)
	if not points.is_empty():
		return points
	var anchor := Vector3i(clampi(int(town.get("level", 0)), 0, max(1, level_count) - 1), int(town.get("x", 0)), int(town.get("y", 0)))
	for dir_value in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate := Vector3i(anchor.x, anchor.y + dir_value.x, anchor.z + dir_value.y)
		if candidate.y >= 0 and candidate.z >= 0 and candidate.y < width and candidate.z < height:
			points.append(candidate)
	return points

func _find_any_path(blocked: Dictionary, width: int, height: int, level_count: int, starts: Array, goals: Array) -> Array:
	var goal_lookup := {}
	for goal in goals:
		if goal is Vector3i:
			goal_lookup["%d:%d,%d" % [goal.x, goal.y, goal.z]] = true
			blocked.erase("%d:%d,%d" % [goal.x, goal.y, goal.z])
	var queue := []
	var seen := {}
	var previous_by_key := {}
	for start in starts:
		if not (start is Vector3i):
			continue
		var start_key := "%d:%d,%d" % [start.x, start.y, start.z]
		blocked.erase(start_key)
		if seen.has(start_key):
			continue
		seen[start_key] = true
		queue.append(start)
	var cursor := 0
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	while cursor < queue.size():
		var current: Vector3i = queue[cursor]
		cursor += 1
		var current_key := "%d:%d,%d" % [current.x, current.y, current.z]
		if goal_lookup.has(current_key):
			return _reconstruct_path(previous_by_key, current)
		for dir_value in dirs:
			var dir: Vector2i = dir_value
			var next := Vector3i(current.x, current.y + dir.x, current.z + dir.y)
			if next.x < 0 or next.x >= max(1, level_count) or next.y < 0 or next.z < 0 or next.y >= width or next.z >= height:
				continue
			var key := "%d:%d,%d" % [next.x, next.y, next.z]
			if seen.has(key) or blocked.has(key):
				continue
			if _step_cuts_blocked_corner(blocked, current, next):
				continue
			seen[key] = true
			previous_by_key[key] = current
			queue.append(next)
	return []

func _step_cuts_blocked_corner(blocked: Dictionary, current: Vector3i, next: Vector3i) -> bool:
	var dx := next.y - current.y
	var dy := next.z - current.z
	if abs(dx) != 1 or abs(dy) != 1:
		return false
	var side_a := "%d:%d,%d" % [current.x, current.y + dx, current.z]
	var side_b := "%d:%d,%d" % [current.x, current.y, current.z + dy]
	return blocked.has(side_a) and blocked.has(side_b)

func _reconstruct_path(previous_by_key: Dictionary, goal: Vector3i) -> Array:
	var path: Array = [goal]
	var current := goal
	var guard := 0
	while guard < 4096:
		guard += 1
		var current_key := "%d:%d,%d" % [current.x, current.y, current.z]
		if not previous_by_key.has(current_key):
			break
		current = previous_by_key[current_key]
		path.push_front(current)
	return path

func _path_sample(path: Array) -> Array:
	if path.size() <= 24:
		return _path_points(path)
	var sample := []
	sample.append_array(_path_points(path.slice(0, 12)))
	sample.append({"omitted": path.size() - 24})
	sample.append_array(_path_points(path.slice(path.size() - 12, path.size())))
	return sample

func _path_points(path: Array) -> Array:
	var points := []
	for point in path:
		if point is Vector3i:
			points.append({"level": point.x, "x": point.y, "y": point.z})
	return points

func _terrain_id_for_code(ids_by_code: Variant, code: int) -> String:
	if (ids_by_code is Array or ids_by_code is PackedStringArray) and code >= 0 and code < ids_by_code.size():
		return String(ids_by_code[code])
	return "grass"

func _brief_town(town: Dictionary) -> Dictionary:
	return {
		"placement_id": str(town.get("placement_id", "")),
		"record_type": str(town.get("record_type", "")),
		"zone_id": str(town.get("zone_id", "")),
		"runtime_zone_index": _int_value(town.get("runtime_zone_index", -1), -1),
		"player_slot": _int_value(town.get("player_slot", 0), 0),
		"level": _int_value(town.get("level", 0), 0),
		"x": _int_value(town.get("x", 0), 0),
		"y": _int_value(town.get("y", 0), 0),
	}

func _brief_connection_object(object: Dictionary) -> Dictionary:
	return {
		"placement_id": str(object.get("placement_id", "")),
		"connection_id": str(object.get("connection_id", "")),
		"kind": str(object.get("kind", "")),
		"runtime_zone_a": _int_value(object.get("runtime_zone_a", -1), -1),
		"runtime_zone_b": _int_value(object.get("runtime_zone_b", -1), -1),
		"guard_value": _int_value(object.get("guard_value", 0), 0),
		"level": _int_value(object.get("level", 0), 0),
		"x": _int_value(object.get("x", 0), 0),
		"y": _int_value(object.get("y", 0), 0),
		"package_block_tiles": object.get("package_block_tiles", []),
	}

func _nearest_manhattan(points: Array) -> int:
	if points.size() < 2:
		return 0
	var best := 999999
	for left_index in range(points.size()):
		var left: Vector2i = points[left_index]
		for right_index in range(left_index + 1, points.size()):
			var right: Vector2i = points[right_index]
			best = min(best, abs(left.x - right.x) + abs(left.y - right.y))
	return best

func _int_value(value: Variant, default_value: int) -> int:
	if value == null:
		return default_value
	return int(value)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": false,
		"error": message,
	})])
	get_tree().quit(1)
