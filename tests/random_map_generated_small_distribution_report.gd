extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "RANDOM_MAP_GENERATED_SMALL_DISTRIBUTION_REPORT"
const SIZE_CLASS_ID := "homm3_small"
const EXPLICIT_SEED := "generated-small-distribution-10184"
const DIAGNOSTIC_ONLY := false

const EARLY_RING_MAX := 6
const MID_RING_MAX := 14
const FRONTIER_RING_MAX := 24
const ROAD_NEAR_DISTANCE := 2
const EMPTY_WINDOW_SIZE := 8

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		ScenarioSelectRulesScript.build_random_map_player_config(
			EXPLICIT_SEED,
			"border_gate_compact_v1",
			"border_gate_compact_profile_v1",
			3,
			"land",
			false,
			SIZE_CLASS_ID
		),
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		_fail("Generated Small setup failed: %s" % JSON.stringify(setup))
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("Generated Small session did not start from setup: %s" % JSON.stringify(setup))
		return
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)

	var generated_map: Dictionary = setup.get("generated_map", {}) if setup.get("generated_map", {}) is Dictionary else {}
	var metrics := _distribution_metrics(session, generated_map)
	var failures := _distribution_failures(metrics)
	if not DIAGNOSTIC_ONLY and not failures.is_empty():
		_fail("Generated Small distribution regression failed: %s metrics=%s" % [JSON.stringify(failures), JSON.stringify(metrics)])
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": failures.is_empty(),
		"diagnostic_only": DIAGNOSTIC_ONLY,
		"scenario_id": session.scenario_id,
		"seed": EXPLICIT_SEED,
		"materialized_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		"failures": failures,
		"metrics": metrics,
	})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)

func _distribution_metrics(session, generated_map: Dictionary) -> Dictionary:
	var hero_pos: Dictionary = session.overworld.get("hero_position", {}) if session.overworld.get("hero_position", {}) is Dictionary else {}
	var start := Vector2i(int(hero_pos.get("x", 0)), int(hero_pos.get("y", 0)))
	var distances := _reachable_distances(session, start)
	var road_cells := _road_cells(generated_map)
	var interactables := _interactables(session, distances, road_cells)
	var ring_counts := _ring_counts(interactables)
	var counts_by_kind := _counts_by_key(interactables, "kind")
	var counts_by_source := _counts_by_key(interactables, "source")
	var reachable_counts := _reachable_counts(interactables)
	var revealed := _revealed_metrics(session, interactables)
	var road_distribution := _road_distribution(interactables)
	var empty_region := _empty_region_metrics(session, distances, interactables)
	var materialized_summary: Dictionary = generated_map.get("runtime_materialization", {}).get("summary", {}) if generated_map.get("runtime_materialization", {}).get("summary", {}) is Dictionary else {}
	var object_instances: Array = generated_map.get("runtime_materialization", {}).get("objects", {}).get("object_instances", [])
	var reward_refs := 0
	for instance in object_instances:
		if instance is Dictionary and String(instance.get("kind", "")) == "reward_reference":
			reward_refs += 1
	var live_reward_nodes := _live_reward_resource_node_count(session)
	return {
		"map_size": session.overworld.get("map_size", {}),
		"start": {"x": start.x, "y": start.y},
		"runtime_materialization_summary": materialized_summary,
		"runtime_object_instance_count": object_instances.size(),
		"runtime_reward_reference_count": reward_refs,
		"live_reward_resource_node_count": live_reward_nodes,
		"live_interactable_count": interactables.size(),
		"counts_by_kind": counts_by_kind,
		"counts_by_source": counts_by_source,
		"reachable_counts": reachable_counts,
		"distance_rings_from_start": ring_counts,
		"nearest_interactables": _nearest_interactables(interactables, 12),
		"revealed_area": revealed,
		"road_distribution": road_distribution,
		"empty_region": empty_region,
		"root_cause_signals": {
			"staged_reward_references_without_live_resource_node": max(0, reward_refs - live_reward_nodes),
			"live_materialized_reward_resource_nodes": live_reward_nodes,
			"non_rendered_or_serialization_only_objects": max(0, object_instances.size() - interactables.size()),
			"mid_ring_live_interactables": int(ring_counts.get("mid_7_14", 0)),
			"frontier_ring_live_interactables": int(ring_counts.get("frontier_15_24", 0)),
			"largest_empty_8x8_reachable_cells": int(empty_region.get("largest_empty_window_reachable_cells", 0)),
		},
	}

func _live_reward_resource_node_count(session) -> int:
	var count := 0
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var node_kind := String(node.get("kind", ""))
		var placement_id := String(node.get("placement_id", ""))
		if node_kind in ["route_reward_cache", "compact_route_density_support"] or placement_id.begins_with("rmg_reward_") or placement_id.begins_with("rmg_compact_density_cache_"):
			count += 1
	return count

func _distribution_failures(metrics: Dictionary) -> Array:
	var failures := []
	var rings: Dictionary = metrics.get("distance_rings_from_start", {}) if metrics.get("distance_rings_from_start", {}) is Dictionary else {}
	var reachable: Dictionary = metrics.get("reachable_counts", {}) if metrics.get("reachable_counts", {}) is Dictionary else {}
	var empty_region: Dictionary = metrics.get("empty_region", {}) if metrics.get("empty_region", {}) is Dictionary else {}
	var road_distribution: Dictionary = metrics.get("road_distribution", {}) if metrics.get("road_distribution", {}) is Dictionary else {}
	if int(reachable.get("reachable_interactable_count", 0)) < 20:
		failures.append("reachable meaningful interactables below Small compact minimum")
	if int(rings.get("early_0_6", 0)) < 4:
		failures.append("early ring has too few meaningful reachable interactables")
	if int(rings.get("mid_7_14", 0)) < 8:
		failures.append("mid ring has too few meaningful reachable interactables")
	if int(road_distribution.get("near_road_count", 0)) < 10:
		failures.append("too few meaningful interactables are near generated roads")
	if int(empty_region.get("largest_empty_window_reachable_cells", 0)) > 44:
		failures.append("large reachable 8x8 window near start has no meaningful interactables")
	return failures

func _interactables(session, distances: Dictionary, road_cells: Array) -> Array:
	var records := []
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var owner := String(town.get("owner", "neutral"))
		records.append(_interactable_record(
			"town:%s" % String(town.get("placement_id", "")),
			"town",
			"%s_town" % owner,
			String(town.get("placement_id", "")),
			String(town.get("town_id", "")),
			_best_interaction_tile(town),
			distances,
			road_cells,
			_point_dict(int(town.get("x", 0)), int(town.get("y", 0)))
		))
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var kind := _resource_kind(node)
		records.append(_interactable_record(
			"resource:%s" % String(node.get("placement_id", "")),
			kind,
			"resource_node",
			String(node.get("placement_id", "")),
			String(node.get("site_id", "")),
			_best_interaction_tile(node),
			distances,
			road_cells,
			_point_dict(int(node.get("x", 0)), int(node.get("y", 0)))
		))
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if OverworldRules.is_encounter_resolved(session, encounter):
			continue
		records.append(_interactable_record(
			"encounter:%s" % String(encounter.get("placement_id", "")),
			"guard",
			"encounter",
			String(encounter.get("placement_id", "")),
			String(encounter.get("encounter_id", "")),
			_point_dict(int(encounter.get("x", 0)), int(encounter.get("y", 0))),
			distances,
			road_cells,
			_point_dict(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
		))
	for artifact_value in session.overworld.get("artifact_nodes", []):
		if not (artifact_value is Dictionary):
			continue
		var artifact: Dictionary = artifact_value
		if bool(artifact.get("collected", false)):
			continue
		records.append(_interactable_record(
			"artifact:%s" % String(artifact.get("placement_id", "")),
			"artifact",
			"artifact_node",
			String(artifact.get("placement_id", "")),
			String(artifact.get("artifact_id", "")),
			_point_dict(int(artifact.get("x", 0)), int(artifact.get("y", 0))),
			distances,
			road_cells,
			_point_dict(int(artifact.get("x", 0)), int(artifact.get("y", 0)))
		))
	return records

func _resource_kind(node: Dictionary) -> String:
	if String(node.get("neutral_dwelling_family_id", "")) != "":
		return "dwelling"
	if String(node.get("original_resource_category_id", "")) != "":
		return "mine"
	var map_object := ContentService.get_map_object(String(node.get("object_id", "")))
	if map_object.is_empty():
		map_object = ContentService.get_map_object_for_resource_site(String(node.get("site_id", "")))
	var family := String(map_object.get("family", "pickup"))
	if family in ["pickup", "one_shot_pickup", "reward_cache_small"]:
		return "pickup"
	return "resource"

func _best_interaction_tile(record: Dictionary) -> Dictionary:
	var visit: Dictionary = record.get("visit_tile", {}) if record.get("visit_tile", {}) is Dictionary else {}
	if not visit.is_empty():
		return _point_dict(int(visit.get("x", 0)), int(visit.get("y", 0)))
	var approaches: Array = record.get("approach_tiles", []) if record.get("approach_tiles", []) is Array else []
	if not approaches.is_empty() and approaches[0] is Dictionary:
		return _point_dict(int(approaches[0].get("x", 0)), int(approaches[0].get("y", 0)))
	return _point_dict(int(record.get("x", 0)), int(record.get("y", 0)))

func _interactable_record(id: String, kind: String, source: String, placement_id: String, content_id: String, point: Dictionary, distances: Dictionary, road_cells: Array, visual_point: Dictionary) -> Dictionary:
	var key := _point_key(int(point.get("x", 0)), int(point.get("y", 0)))
	var distance := int(distances.get(key, -1))
	var road_distance := _min_road_distance(point, road_cells)
	if visual_point.is_empty():
		visual_point = point
	return {
		"id": id,
		"kind": kind,
		"source": source,
		"placement_id": placement_id,
		"content_id": content_id,
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
		"visual_x": int(visual_point.get("x", point.get("x", 0))),
		"visual_y": int(visual_point.get("y", point.get("y", 0))),
		"reachable": distance >= 0,
		"distance_from_start": distance,
		"distance_ring": _distance_ring(distance),
		"road_distance": road_distance,
		"near_road": road_distance >= 0 and road_distance <= ROAD_NEAR_DISTANCE,
	}

func _reachable_distances(session, start: Vector2i) -> Dictionary:
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	var width := int(map_size.get("width", 0))
	var height := int(map_size.get("height", 0))
	var distances := {}
	var queue := [start]
	distances[_point_key(start.x, start.y)] = 0
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		var current_distance := int(distances.get(_point_key(current.x, current.y), 0))
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var next_tile: Vector2i = current + offset
			if next_tile.x < 0 or next_tile.y < 0 or next_tile.x >= width or next_tile.y >= height:
				continue
			var key := _point_key(next_tile.x, next_tile.y)
			if distances.has(key):
				continue
			if OverworldRules.tile_is_blocked(session, next_tile.x, next_tile.y):
				continue
			distances[key] = current_distance + 1
			queue.append(next_tile)
	return distances

func _road_cells(generated_map: Dictionary) -> Array:
	var cells := []
	var seen := {}
	var roads: Dictionary = generated_map.get("scenario_record", {}).get("generated_constraints", {}).get("roads", {}) if generated_map.get("scenario_record", {}).get("generated_constraints", {}).get("roads", {}) is Dictionary else {}
	for segment in roads.get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if not (cell is Dictionary):
				continue
			var key := _point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))
			if seen.has(key):
				continue
			seen[key] = true
			cells.append(_point_dict(int(cell.get("x", 0)), int(cell.get("y", 0))))
	return cells

func _ring_counts(records: Array) -> Dictionary:
	var counts := {"early_0_6": 0, "mid_7_14": 0, "frontier_15_24": 0, "far_25_plus": 0, "unreachable": 0}
	for record in records:
		if not (record is Dictionary):
			continue
		var ring := String(record.get("distance_ring", "unreachable"))
		counts[ring] = int(counts.get(ring, 0)) + 1
	return counts

func _distance_ring(distance: int) -> String:
	if distance < 0:
		return "unreachable"
	if distance <= EARLY_RING_MAX:
		return "early_0_6"
	if distance <= MID_RING_MAX:
		return "mid_7_14"
	if distance <= FRONTIER_RING_MAX:
		return "frontier_15_24"
	return "far_25_plus"

func _counts_by_key(records: Array, key_name: String) -> Dictionary:
	var counts := {}
	for record in records:
		if record is Dictionary:
			var value := String(record.get(key_name, ""))
			counts[value] = int(counts.get(value, 0)) + 1
	return _sorted_dict(counts)

func _reachable_counts(records: Array) -> Dictionary:
	var reachable := 0
	var unreachable := 0
	for record in records:
		if record is Dictionary and bool(record.get("reachable", false)):
			reachable += 1
		else:
			unreachable += 1
	return {"reachable_interactable_count": reachable, "unreachable_interactable_count": unreachable}

func _revealed_metrics(session, records: Array) -> Dictionary:
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	var width := int(map_size.get("width", 0))
	var height := int(map_size.get("height", 0))
	var visible_tiles := 0
	var explored_tiles := 0
	for y in range(height):
		for x in range(width):
			if OverworldRules.is_tile_visible(session, x, y):
				visible_tiles += 1
			if OverworldRules.is_tile_explored(session, x, y):
				explored_tiles += 1
	var visible_interactables := 0
	var explored_interactables := 0
	for record in records:
		if not (record is Dictionary):
			continue
		var x := int(record.get("x", 0))
		var y := int(record.get("y", 0))
		if OverworldRules.is_tile_visible(session, x, y):
			visible_interactables += 1
		if OverworldRules.is_tile_explored(session, x, y):
			explored_interactables += 1
	return {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_interactables": visible_interactables,
		"explored_interactables": explored_interactables,
		"visible_interactables_per_100_tiles": _density_per_100(visible_interactables, visible_tiles),
		"explored_interactables_per_100_tiles": _density_per_100(explored_interactables, explored_tiles),
	}

func _road_distribution(records: Array) -> Dictionary:
	var near_count := 0
	var reachable_near := 0
	var distances := []
	for record in records:
		if not (record is Dictionary):
			continue
		var road_distance := int(record.get("road_distance", -1))
		if road_distance >= 0:
			distances.append(road_distance)
		if bool(record.get("near_road", false)):
			near_count += 1
			if bool(record.get("reachable", false)):
				reachable_near += 1
	return {
		"near_road_count": near_count,
		"reachable_near_road_count": reachable_near,
		"road_distance_spread": _spread(distances),
	}

func _empty_region_metrics(session, distances: Dictionary, records: Array) -> Dictionary:
	var object_lookup := {}
	for record in records:
		if not (record is Dictionary) or not bool(record.get("reachable", false)):
			continue
		var distance := int(record.get("distance_from_start", -1))
		if distance < 0 or distance > FRONTIER_RING_MAX:
			continue
		object_lookup[_point_key(int(record.get("x", 0)), int(record.get("y", 0)))] = true
		object_lookup[_point_key(int(record.get("visual_x", record.get("x", 0))), int(record.get("visual_y", record.get("y", 0))))] = true
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	var width := int(map_size.get("width", 0))
	var height := int(map_size.get("height", 0))
	var max_empty_reachable := 0
	var max_window := {}
	for y0 in range(0, max(0, height - EMPTY_WINDOW_SIZE + 1)):
		for x0 in range(0, max(0, width - EMPTY_WINDOW_SIZE + 1)):
			var reachable_cells := 0
			var object_count := 0
			for y in range(y0, y0 + EMPTY_WINDOW_SIZE):
				for x in range(x0, x0 + EMPTY_WINDOW_SIZE):
					var key := _point_key(x, y)
					var distance := int(distances.get(key, -1))
					if distance < 0 or distance > FRONTIER_RING_MAX:
						continue
					if OverworldRules.tile_is_blocked(session, x, y):
						continue
					reachable_cells += 1
					if object_lookup.has(key):
						object_count += 1
			if object_count == 0 and reachable_cells > max_empty_reachable:
				max_empty_reachable = reachable_cells
				max_window = {"x": x0, "y": y0, "width": EMPTY_WINDOW_SIZE, "height": EMPTY_WINDOW_SIZE}
	return {
		"window_size": EMPTY_WINDOW_SIZE,
		"scan_distance_limit": FRONTIER_RING_MAX,
		"largest_empty_window_reachable_cells": max_empty_reachable,
		"largest_empty_window": max_window,
	}

func _nearest_interactables(records: Array, limit: int) -> Array:
	var sorted := []
	for record in records:
		if record is Dictionary and bool(record.get("reachable", false)):
			sorted.append(record)
	sorted.sort_custom(Callable(self, "_compare_interactable_distance"))
	var result := []
	for index in range(min(limit, sorted.size())):
		var record: Dictionary = sorted[index]
		result.append({
			"kind": String(record.get("kind", "")),
			"placement_id": String(record.get("placement_id", "")),
			"content_id": String(record.get("content_id", "")),
			"x": int(record.get("x", 0)),
			"y": int(record.get("y", 0)),
			"distance_from_start": int(record.get("distance_from_start", -1)),
			"road_distance": int(record.get("road_distance", -1)),
		})
	return result

func _compare_interactable_distance(a: Dictionary, b: Dictionary) -> bool:
	var da := int(a.get("distance_from_start", 999999))
	var db := int(b.get("distance_from_start", 999999))
	if da != db:
		return da < db
	return String(a.get("placement_id", "")) < String(b.get("placement_id", ""))

func _min_road_distance(point: Dictionary, road_cells: Array) -> int:
	if road_cells.is_empty():
		return -1
	var best := 999999
	var x := int(point.get("x", 0))
	var y := int(point.get("y", 0))
	for cell in road_cells:
		if not (cell is Dictionary):
			continue
		var distance: int = abs(x - int(cell.get("x", 0))) + abs(y - int(cell.get("y", 0)))
		best = min(best, distance)
	return best

func _density_per_100(count: int, tiles: int) -> float:
	if tiles <= 0:
		return 0.0
	return snapped(float(count) * 100.0 / float(tiles), 0.001)

func _spread(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "min": 0, "max": 0, "avg": 0.0}
	var min_value := 999999
	var max_value := -999999
	var total := 0
	for value in values:
		var int_value := int(value)
		min_value = min(min_value, int_value)
		max_value = max(max_value, int_value)
		total += int_value
	return {"count": values.size(), "min": min_value, "max": max_value, "avg": snapped(float(total) / float(values.size()), 0.001)}

func _point_dict(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y}

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _sorted_dict(input: Dictionary) -> Dictionary:
	var result := {}
	var keys := input.keys()
	keys.sort()
	for key in keys:
		result[key] = input[key]
	return result

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(1)
