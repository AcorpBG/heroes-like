extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "RANDOM_MAP_GENERATED_DENSITY_DISTRIBUTION_REPORT"
const EXPLICIT_SEED_PREFIX := "generated-density-distribution-10184"
const DIAGNOSTIC_ONLY := false

const SIZE_CLASS_IDS := ["homm3_small", "homm3_medium", "homm3_large", "homm3_extra_large"]
const SIZE_CLASS_SEEDS := {
	"homm3_medium": "density-medium-pass-02",
}
const BASELINE_MAP_EDGE := 36.0
const EARLY_RING_BASE := 6
const MID_RING_BASE := 14
const FRONTIER_RING_BASE := 24
const ROAD_NEAR_DISTANCE_BASE := 2
const EMPTY_WINDOW_BASE := 8
const NEAREST_INTERACTABLE_LIMIT := 12

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var cases := []
	var failures := []
	for size_class_id in SIZE_CLASS_IDS:
		var result := _run_size_case(size_class_id)
		cases.append(result)
		failures.append_array(result.get("failures", []))
	if not DIAGNOSTIC_ONLY and not failures.is_empty():
		_fail("Generated density/distribution regression failed: %s cases=%s" % [JSON.stringify(failures), JSON.stringify(cases)])
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": failures.is_empty(),
		"diagnostic_only": DIAGNOSTIC_ONLY,
		"seed_prefix": EXPLICIT_SEED_PREFIX,
		"failures": failures,
		"cases": cases,
	})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)

func _run_size_case(size_class_id: String) -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var defaults := ScenarioSelectRulesScript.random_map_size_class_default(size_class_id)
	var seed := String(SIZE_CLASS_SEEDS.get(size_class_id, "%s-%s" % [EXPLICIT_SEED_PREFIX, size_class_id]))
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		ScenarioSelectRulesScript.build_random_map_player_config(
			seed,
			String(defaults.get("template_id", "")),
			String(defaults.get("profile_id", "")),
			int(defaults.get("player_count", 3)),
			"land",
			false,
			size_class_id
		),
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		return {
			"ok": false,
			"size_class_id": size_class_id,
			"seed": seed,
			"template_id": String(defaults.get("template_id", "")),
			"profile_id": String(defaults.get("profile_id", "")),
			"player_count": int(defaults.get("player_count", 0)),
			"failures": ["%s setup failed: %s" % [size_class_id, JSON.stringify(setup)]],
		}
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		return {
			"ok": false,
			"size_class_id": size_class_id,
			"seed": seed,
			"failures": ["%s session did not start from setup" % size_class_id],
		}
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	var generated_map: Dictionary = setup.get("generated_map", {}) if setup.get("generated_map", {}) is Dictionary else {}
	var metrics := _distribution_metrics(session, generated_map, setup, size_class_id, seed, defaults)
	var failures := _distribution_failures(metrics)
	return {
		"ok": failures.is_empty(),
		"size_class_id": size_class_id,
		"seed": seed,
		"scenario_id": session.scenario_id,
		"materialized_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		"template_id": String(metrics.get("template_id", "")),
		"profile_id": String(metrics.get("profile_id", "")),
		"player_count": int(metrics.get("player_count", 0)),
		"map_size": metrics.get("map_size", {}),
		"failures": failures,
		"metrics": metrics,
	}

func _distribution_metrics(session, generated_map: Dictionary, setup: Dictionary, size_class_id: String, seed: String, defaults: Dictionary) -> Dictionary:
	var hero_pos: Dictionary = session.overworld.get("hero_position", {}) if session.overworld.get("hero_position", {}) is Dictionary else {}
	var start := Vector2i(int(hero_pos.get("x", 0)), int(hero_pos.get("y", 0)))
	var distances := _reachable_distances(session, start)
	var road_cells := _road_cells(generated_map)
	var ring_policy := _ring_policy(session)
	var interactables := _interactables(session, distances, road_cells, ring_policy)
	var ring_counts := _ring_counts(interactables)
	var counts_by_kind := _counts_by_key(interactables, "kind")
	var counts_by_source := _counts_by_key(interactables, "source")
	var reachable_counts := _reachable_counts(interactables)
	var revealed := _revealed_metrics(session, interactables)
	var road_distribution := _road_distribution(interactables, int(ring_policy.get("road_near_distance", ROAD_NEAR_DISTANCE_BASE)))
	var empty_region := _empty_region_metrics(session, distances, interactables, ring_policy)
	var materialized_summary: Dictionary = generated_map.get("runtime_materialization", {}).get("summary", {}) if generated_map.get("runtime_materialization", {}).get("summary", {}) is Dictionary else {}
	var object_instances: Array = generated_map.get("runtime_materialization", {}).get("objects", {}).get("object_instances", [])
	var materialization_constraints: Dictionary = generated_map.get("scenario_record", {}).get("generated_constraints", {}) if generated_map.get("scenario_record", {}).get("generated_constraints", {}) is Dictionary else {}
	var reward_refs := 0
	for instance in object_instances:
		if instance is Dictionary and String(instance.get("kind", "")) == "reward_reference":
			reward_refs += 1
	var live_reward_nodes := _live_reward_resource_node_counts(session)
	var reachable_tiles := distances.size()
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	var profile: Dictionary = generated_map.get("metadata", {}).get("profile", {}) if generated_map.get("metadata", {}).get("profile", {}) is Dictionary else {}
	var template_id := String(generated_map.get("metadata", {}).get("template_id", defaults.get("template_id", "")))
	var profile_id := String(profile.get("id", defaults.get("profile_id", "")))
	var materialized_route_rewards: Array = materialization_constraints.get("materialized_route_rewards", []) if materialization_constraints.get("materialized_route_rewards", []) is Array else []
	var materialized_density_support: Array = materialization_constraints.get("materialized_route_density_support", materialization_constraints.get("materialized_compact_density_support", [])) if materialization_constraints.get("materialized_route_density_support", materialization_constraints.get("materialized_compact_density_support", [])) is Array else []
	return {
		"size_class_id": size_class_id,
		"size_class_label": ScenarioSelectRulesScript.random_map_size_class_label(size_class_id),
		"seed": seed,
		"template_id": template_id,
		"profile_id": profile_id,
		"player_count": int(generated_map.get("metadata", {}).get("player_constraints", {}).get("player_count", defaults.get("player_count", 0))),
		"map_size": map_size,
		"start": {"x": start.x, "y": start.y},
		"ring_policy": ring_policy,
		"runtime_materialization_summary": materialized_summary,
		"runtime_object_instance_count": object_instances.size(),
		"runtime_reward_reference_count": reward_refs,
		"live_reward_resource_node_count": int(live_reward_nodes.get("total_reward_resource_count", 0)),
		"live_route_reward_resource_count": int(live_reward_nodes.get("route_reward_resource_count", 0)),
		"live_density_support_resource_count": int(live_reward_nodes.get("density_support_resource_count", 0)),
		"materialized_route_reward_resource_count": max(materialized_route_rewards.size(), int(live_reward_nodes.get("route_reward_resource_count", 0))),
		"materialized_density_support_resource_count": max(materialized_density_support.size(), int(live_reward_nodes.get("density_support_resource_count", 0))),
		"live_interactable_count": interactables.size(),
		"counts_by_kind": counts_by_kind,
		"counts_by_source": counts_by_source,
		"reachable_counts": reachable_counts,
		"reachable_tiles": reachable_tiles,
		"reachable_interactables_per_1000_reachable_tiles": _density_per_1000(int(reachable_counts.get("reachable_interactable_count", 0)), reachable_tiles),
		"distance_rings_from_start": ring_counts,
		"nearest_interactables": _nearest_interactables(interactables, NEAREST_INTERACTABLE_LIMIT),
		"revealed_area": revealed,
		"road_distribution": road_distribution,
		"empty_region": empty_region,
		"root_cause_signals": {
			"staged_reward_references_without_live_resource_node": max(0, reward_refs - int(live_reward_nodes.get("total_reward_resource_count", 0))),
			"live_materialized_reward_resource_nodes": int(live_reward_nodes.get("total_reward_resource_count", 0)),
			"non_rendered_or_serialization_only_objects": max(0, object_instances.size() - interactables.size()),
			"mid_ring_live_interactables": int(ring_counts.get("mid", 0)),
			"frontier_ring_live_interactables": int(ring_counts.get("frontier", 0)),
			"largest_empty_window_reachable_ratio": float(empty_region.get("largest_empty_window_reachable_ratio", 0.0)),
		},
	}

func _live_reward_resource_node_counts(session) -> Dictionary:
	var route_count := 0
	var support_count := 0
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var node_kind := String(node.get("kind", ""))
		var placement_id := String(node.get("placement_id", ""))
		if node_kind == "route_reward_cache" or placement_id.begins_with("rmg_reward_"):
			route_count += 1
		elif node_kind in ["compact_route_density_support", "route_density_support"] or placement_id.begins_with("rmg_compact_density_cache_") or placement_id.begins_with("rmg_route_density_cache_"):
			support_count += 1
	return {
		"route_reward_resource_count": route_count,
		"density_support_resource_count": support_count,
		"total_reward_resource_count": route_count + support_count,
	}

func _distribution_failures(metrics: Dictionary) -> Array:
	var failures := []
	var rings: Dictionary = metrics.get("distance_rings_from_start", {}) if metrics.get("distance_rings_from_start", {}) is Dictionary else {}
	var reachable: Dictionary = metrics.get("reachable_counts", {}) if metrics.get("reachable_counts", {}) is Dictionary else {}
	var empty_region: Dictionary = metrics.get("empty_region", {}) if metrics.get("empty_region", {}) is Dictionary else {}
	var road_distribution: Dictionary = metrics.get("road_distribution", {}) if metrics.get("road_distribution", {}) is Dictionary else {}
	var label := String(metrics.get("size_class_id", "generated"))
	if int(reachable.get("reachable_interactable_count", 0)) < 20:
		failures.append("%s reachable meaningful interactables below normalized minimum" % label)
	if int(rings.get("early", 0)) < 4:
		failures.append("%s early normalized ring has too few meaningful reachable interactables" % label)
	if int(rings.get("mid", 0)) < 8:
		failures.append("%s mid normalized ring has too few meaningful reachable interactables" % label)
	if int(rings.get("frontier", 0)) < 8:
		failures.append("%s frontier normalized ring has too few meaningful reachable interactables" % label)
	if int(road_distribution.get("near_road_count", 0)) < 10:
		failures.append("%s has too few meaningful interactables near generated roads" % label)
	if float(empty_region.get("largest_empty_window_reachable_ratio", 0.0)) > 0.75:
		failures.append("%s has a normalized reachable empty window above threshold" % label)
	if int(metrics.get("materialized_route_reward_resource_count", 0)) <= 0:
		failures.append("%s materialized no route reward resource nodes" % label)
	return failures

func _interactables(session, distances: Dictionary, road_cells: Array, ring_policy: Dictionary) -> Array:
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
			_point_dict(int(town.get("x", 0)), int(town.get("y", 0))),
			ring_policy
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
			_point_dict(int(node.get("x", 0)), int(node.get("y", 0))),
			ring_policy
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
			_point_dict(int(encounter.get("x", 0)), int(encounter.get("y", 0))),
			ring_policy
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
			_point_dict(int(artifact.get("x", 0)), int(artifact.get("y", 0))),
			ring_policy
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

func _interactable_record(id: String, kind: String, source: String, placement_id: String, content_id: String, point: Dictionary, distances: Dictionary, road_cells: Array, visual_point: Dictionary, ring_policy: Dictionary) -> Dictionary:
	var key := _point_key(int(point.get("x", 0)), int(point.get("y", 0)))
	var distance := int(distances.get(key, -1))
	var road_distance := _min_road_distance(point, road_cells)
	var road_near_distance := int(ring_policy.get("road_near_distance", ROAD_NEAR_DISTANCE_BASE))
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
		"distance_ring": _distance_ring(distance, ring_policy),
		"road_distance": road_distance,
		"near_road": road_distance >= 0 and road_distance <= road_near_distance,
	}

func _reachable_distances(session, start: Vector2i) -> Dictionary:
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	var width := int(map_size.get("width", 0))
	var height := int(map_size.get("height", 0))
	var blocked := _blocked_lookup(session, width, height, start)
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
			if blocked.has(key):
				continue
			distances[key] = current_distance + 1
			queue.append(next_tile)
	return distances

func _blocked_lookup(session, width: int, height: int, start: Vector2i) -> Dictionary:
	var blocked := {}
	var map_rows: Array = session.overworld.get("map", []) if session.overworld.get("map", []) is Array else []
	for y in range(height):
		var row: Array = map_rows[y] if y >= 0 and y < map_rows.size() and map_rows[y] is Array else []
		for x in range(width):
			var terrain_id: String = String(row[x] if x >= 0 and x < row.size() else "")
			if terrain_id in ["water", "coast", "shore"]:
				blocked[_point_key(x, y)] = true
	for collection_name in ["towns", "resource_nodes", "artifact_nodes"]:
		for record_value in session.overworld.get(collection_name, []):
			if not (record_value is Dictionary):
				continue
			var record: Dictionary = record_value
			if not _record_blocks_body(record):
				continue
			for body in _record_body_tiles(record):
				if body is Dictionary:
					blocked[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = true
	blocked.erase(_point_key(start.x, start.y))
	return blocked

func _record_blocks_body(record: Dictionary) -> bool:
	if record.has("blocking_body"):
		return bool(record.get("blocking_body", true))
	return false

func _record_body_tiles(record: Dictionary) -> Array:
	var body_tiles: Array = record.get("body_tiles", []) if record.get("body_tiles", []) is Array else []
	if not body_tiles.is_empty():
		return body_tiles
	var runtime_body: Array = record.get("runtime_body_mask", []) if record.get("runtime_body_mask", []) is Array else []
	if not runtime_body.is_empty():
		var result: Array = []
		var origin_x := int(record.get("x", 0))
		var origin_y := int(record.get("y", 0))
		for offset in runtime_body:
			if offset is Dictionary:
				result.append({"x": origin_x + int(offset.get("x", 0)), "y": origin_y + int(offset.get("y", 0))})
		return result
	return [_point_dict(int(record.get("x", 0)), int(record.get("y", 0)))]

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
	var counts := {"early": 0, "mid": 0, "frontier": 0, "far": 0, "unreachable": 0}
	for record in records:
		if not (record is Dictionary):
			continue
		var ring := String(record.get("distance_ring", "unreachable"))
		counts[ring] = int(counts.get(ring, 0)) + 1
	return counts

func _distance_ring(distance: int, ring_policy: Dictionary) -> String:
	if distance < 0:
		return "unreachable"
	if distance <= int(ring_policy.get("early_max", EARLY_RING_BASE)):
		return "early"
	if distance <= int(ring_policy.get("mid_max", MID_RING_BASE)):
		return "mid"
	if distance <= int(ring_policy.get("frontier_max", FRONTIER_RING_BASE)):
		return "frontier"
	return "far"

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

func _ring_policy(session) -> Dictionary:
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	var width: int = max(1, int(map_size.get("width", 36)))
	var height: int = max(1, int(map_size.get("height", 36)))
	var scale: float = max(1.0, float(min(width, height)) / BASELINE_MAP_EDGE)
	return {
		"scale": snapped(scale, 0.001),
		"early_max": int(ceil(float(EARLY_RING_BASE) * scale)),
		"mid_max": int(ceil(float(MID_RING_BASE) * scale)),
		"frontier_max": int(ceil(float(FRONTIER_RING_BASE) * scale)),
		"road_near_distance": int(ceil(float(ROAD_NEAR_DISTANCE_BASE) * sqrt(scale))),
		"empty_window_size": int(ceil(float(EMPTY_WINDOW_BASE) * scale)),
		"normalization": "thresholds_scale_from_36x36_baseline_by_min_map_edge",
	}

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

func _road_distribution(records: Array, near_distance: int) -> Dictionary:
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
		"near_distance": near_distance,
		"near_road_count": near_count,
		"reachable_near_road_count": reachable_near,
		"road_distance_spread": _spread(distances),
	}

func _empty_region_metrics(session, distances: Dictionary, records: Array, ring_policy: Dictionary) -> Dictionary:
	var object_lookup := {}
	var frontier_max := int(ring_policy.get("frontier_max", FRONTIER_RING_BASE))
	for record in records:
		if not (record is Dictionary) or not bool(record.get("reachable", false)):
			continue
		var distance := int(record.get("distance_from_start", -1))
		if distance < 0 or distance > frontier_max:
			continue
		object_lookup[_point_key(int(record.get("x", 0)), int(record.get("y", 0)))] = true
		object_lookup[_point_key(int(record.get("visual_x", record.get("x", 0))), int(record.get("visual_y", record.get("y", 0))))] = true
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	var width := int(map_size.get("width", 0))
	var height := int(map_size.get("height", 0))
	var window_size := int(ring_policy.get("empty_window_size", EMPTY_WINDOW_BASE))
	var scan_stride: int = max(1, int(floor(float(window_size) / 4.0)))
	var max_empty_reachable := 0
	var max_window := {}
	for y0 in range(0, max(0, height - window_size + 1), scan_stride):
		for x0 in range(0, max(0, width - window_size + 1), scan_stride):
			var reachable_cells := 0
			var object_count := 0
			for y in range(y0, y0 + window_size):
				for x in range(x0, x0 + window_size):
					var key := _point_key(x, y)
					var distance := int(distances.get(key, -1))
					if distance < 0 or distance > frontier_max:
						continue
					reachable_cells += 1
					if object_lookup.has(key):
						object_count += 1
			if object_count == 0 and reachable_cells > max_empty_reachable:
				max_empty_reachable = reachable_cells
				max_window = {"x": x0, "y": y0, "width": window_size, "height": window_size}
	var window_area: int = max(1, window_size * window_size)
	return {
		"window_size": window_size,
		"scan_stride": scan_stride,
		"scan_distance_limit": frontier_max,
		"largest_empty_window_reachable_cells": max_empty_reachable,
		"largest_empty_window_reachable_ratio": snapped(float(max_empty_reachable) / float(window_area), 0.001),
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

func _density_per_1000(count: int, tiles: int) -> float:
	if tiles <= 0:
		return 0.0
	return snapped(float(count) * 1000.0 / float(tiles), 0.001)

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
