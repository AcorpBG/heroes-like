extends Node

const REPORT_SCHEMA := "active_scenario_town_economy_source_route_report_v1"
const REQUIRED_COMMON_RESOURCE_IDS := ["wood", "ore"]
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const MAX_COMMON_ROUTE_STEPS := 24
const MAX_RARE_ROUTE_STEPS := 40

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenario_count := 0
	var player_town_case_count := 0
	var player_resource_route_case_count := 0
	var player_reachable_route_case_count := 0
	var enemy_town_case_count := 0
	var enemy_resource_route_case_count := 0
	var enemy_reachable_route_case_count := 0
	var rows := []
	for scenario_id_value in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if not _is_active_authored_scenario(scenario):
			continue
		scenario_count += 1
		var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		if session == null:
			_errors.append("%s failed: ScenarioFactory.create_session returned null" % scenario_id)
			continue
		OverworldRules.normalize_overworld_state(session)
		for authored_town in _player_towns(scenario):
			var row := _run_town_case(session, scenario_id, authored_town, "player")
			rows.append(row)
			player_town_case_count += 1
			player_resource_route_case_count += int(row.get("resource_route_case_count", 0))
			player_reachable_route_case_count += int(row.get("reachable_route_case_count", 0))
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed: %s" % [
					scenario_id,
					String(authored_town.get("placement_id", "")),
					String(row.get("error", "unknown route failure")),
				])
		for authored_town in _enemy_towns(scenario):
			var row := _run_town_case(session, scenario_id, authored_town, "enemy")
			rows.append(row)
			enemy_town_case_count += 1
			enemy_resource_route_case_count += int(row.get("resource_route_case_count", 0))
			enemy_reachable_route_case_count += int(row.get("reachable_route_case_count", 0))
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed: %s" % [
					scenario_id,
					String(authored_town.get("placement_id", "")),
					String(row.get("error", "unknown route failure")),
				])

	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"active_scenario_count": scenario_count,
		"player_town_case_count": player_town_case_count,
		"resource_route_case_count": player_resource_route_case_count,
		"reachable_route_case_count": player_reachable_route_case_count,
		"enemy_town_case_count": enemy_town_case_count,
		"enemy_resource_route_case_count": enemy_resource_route_case_count,
		"enemy_reachable_route_case_count": enemy_reachable_route_case_count,
		"required_common_resource_ids": REQUIRED_COMMON_RESOURCE_IDS,
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"max_common_route_steps": MAX_COMMON_ROUTE_STEPS,
		"max_rare_route_steps": MAX_RARE_ROUTE_STEPS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"This report verifies authored economy source reachability through live terrain, blocker, and route-interaction rules.",
			"It does not auto-resolve battles or claim final encounter pacing; guarded sources remain combat/balance surfaces.",
			"The existing development runway reports still prove 30-turn construction after reachable sources are secured.",
		],
	}
	print("ACTIVE_SCENARIO_TOWN_ECONOMY_SOURCE_ROUTE_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town_case(session, scenario_id: String, authored_town: Dictionary, owner: String) -> Dictionary:
	var placement_id := String(authored_town.get("placement_id", ""))
	var town_id := String(authored_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var rare_id := String(profile.get("rare_resource_id", ""))
	var required_resource_ids := REQUIRED_COMMON_RESOURCE_IDS.duplicate()
	required_resource_ids.append(rare_id)
	var start_tile := Vector2i(int(authored_town.get("x", 0)), int(authored_town.get("y", 0)))
	var route_rows := []
	var errors := []
	var reachable_count := 0
	for resource_id_value in required_resource_ids:
		var resource_id := String(resource_id_value)
		var route_row := _best_resource_route(session, start_tile, resource_id)
		route_rows.append(route_row)
		if bool(route_row.get("reachable", false)):
			reachable_count += 1
		else:
			errors.append("%s source unreachable" % resource_id)
		var route_steps := int(route_row.get("route_steps", 999999))
		var max_steps := MAX_COMMON_ROUTE_STEPS if resource_id in REQUIRED_COMMON_RESOURCE_IDS else MAX_RARE_ROUTE_STEPS
		if route_steps > max_steps:
			errors.append("%s source route too long: %d > %d" % [resource_id, route_steps, max_steps])
	var ok: bool = errors.is_empty() and route_rows.size() == 3
	return {
		"ok": ok,
		"scenario_id": scenario_id,
		"owner": owner,
		"town_placement_id": placement_id,
		"town_id": town_id,
		"rare_resource_id": rare_id,
		"start_tile": _tile_payload(start_tile),
		"resource_route_case_count": route_rows.size(),
		"reachable_route_case_count": reachable_count,
		"routes": route_rows,
		"errors": errors,
		"error": "; ".join(errors),
	}

func _best_resource_route(session, start_tile: Vector2i, resource_id: String) -> Dictionary:
	var candidates := []
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var output := _resource_node_output(node)
		if int(output.get(resource_id, 0)) <= 0:
			continue
		var target_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
		var route := _find_route(session, start_tile, target_tile)
		var row := {
			"resource_id": resource_id,
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"site_name": String(ContentService.get_resource_site(String(node.get("site_id", ""))).get("name", "")),
			"target_tile": _tile_payload(target_tile),
			"output": output,
			"reachable": not route.is_empty(),
			"route_steps": max(0, route.size() - 1) if not route.is_empty() else 999999,
			"route_tiles": _route_payload(route),
			"guarded": _resource_source_has_guard(session, node),
		}
		candidates.append(row)
	if candidates.is_empty():
		return {
			"resource_id": resource_id,
			"reachable": false,
			"route_steps": 999999,
			"error": "no authored resource source",
		}
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if bool(left.get("reachable", false)) != bool(right.get("reachable", false)):
			return bool(left.get("reachable", false))
		return int(left.get("route_steps", 999999)) < int(right.get("route_steps", 999999))
	)
	var best: Dictionary = candidates[0]
	best["candidate_count"] = candidates.size()
	best["reachable_candidate_count"] = _reachable_candidate_count(candidates)
	return best

func _find_route(session, start_tile: Vector2i, target_tile: Vector2i) -> Array:
	var map_size := OverworldRules.derive_map_size(session)
	if not _in_bounds(start_tile, map_size) or not _in_bounds(target_tile, map_size):
		return []
	var start_key := _tile_key(start_tile)
	var target_key := _tile_key(target_tile)
	var queue := [start_tile]
	var visited := {start_key: true}
	var parent := {}
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == target_tile:
			return _reconstruct_route(parent, start_tile, target_tile)
		for neighbor in _neighbors(current):
			if not _in_bounds(neighbor, map_size):
				continue
			var neighbor_key := _tile_key(neighbor)
			if bool(visited.get(neighbor_key, false)):
				continue
			if OverworldRules.tile_step_cuts_blocked_corner(session, current, neighbor):
				continue
			var is_destination: bool = neighbor == target_tile
			if OverworldRules.tile_is_blocked(session, neighbor.x, neighbor.y) and not (is_destination and OverworldRules.tile_is_actionable_route_destination(session, neighbor.x, neighbor.y)):
				continue
			if not is_destination and OverworldRules.tile_has_route_interaction(session, neighbor.x, neighbor.y):
				continue
			visited[neighbor_key] = true
			parent[neighbor_key] = current
			queue.append(neighbor)
	return []

func _reconstruct_route(parent: Dictionary, start_tile: Vector2i, target_tile: Vector2i) -> Array:
	var route := [target_tile]
	var current := target_tile
	var guard := 0
	while current != start_tile and guard < 10000:
		guard += 1
		var current_key := _tile_key(current)
		if not parent.has(current_key):
			return []
		current = parent[current_key]
		route.push_front(current)
	return route

func _neighbors(tile: Vector2i) -> Array:
	return [
		Vector2i(tile.x - 1, tile.y - 1),
		Vector2i(tile.x, tile.y - 1),
		Vector2i(tile.x + 1, tile.y - 1),
		Vector2i(tile.x - 1, tile.y),
		Vector2i(tile.x + 1, tile.y),
		Vector2i(tile.x - 1, tile.y + 1),
		Vector2i(tile.x, tile.y + 1),
		Vector2i(tile.x + 1, tile.y + 1),
	]

func _resource_node_output(node: Dictionary) -> Dictionary:
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var result := {}
	for bucket in [site.get("claim_rewards", site.get("rewards", {})), site.get("control_income", {})]:
		if not (bucket is Dictionary):
			continue
		for key in bucket.keys():
			var resource_id := String(key)
			if resource_id == "experience" or resource_id == "":
				continue
			result[resource_id] = int(result.get(resource_id, 0)) + int(bucket.get(key, 0))
	return result

func _resource_source_has_guard(session, node: Dictionary) -> bool:
	var placement_id := String(node.get("placement_id", ""))
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if OverworldRules.is_encounter_resolved(session, encounter):
			continue
		if String(encounter.get("target_kind", "")) == "resource" and String(encounter.get("target_placement_id", "")) == placement_id:
			return true
		var dx: int = abs(int(encounter.get("x", 0)) - int(node.get("x", 0)))
		var dy: int = abs(int(encounter.get("y", 0)) - int(node.get("y", 0)))
		if max(dx, dy) <= 1:
			return true
	return false

func _is_active_authored_scenario(scenario: Dictionary) -> bool:
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	return bool(availability.get("campaign", false)) or bool(availability.get("skirmish", false))

func _player_towns(scenario: Dictionary) -> Array:
	var result := []
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			result.append(town)
	return result

func _enemy_towns(scenario: Dictionary) -> Array:
	var result := []
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy":
			result.append(town)
	return result

func _reachable_candidate_count(candidates: Array) -> int:
	var count := 0
	for candidate in candidates:
		if candidate is Dictionary and bool(candidate.get("reachable", false)):
			count += 1
	return count

func _in_bounds(tile: Vector2i, map_size: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _route_payload(route: Array) -> Array:
	var payload := []
	for tile in route:
		if tile is Vector2i:
			payload.append(_tile_payload(tile))
	return payload
