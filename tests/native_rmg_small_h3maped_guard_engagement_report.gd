extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_GUARD_ENGAGEMENT_REPORT"
const REPORT_SCHEMA_ID := "native_rmg_small_h3maped_guard_engagement_report_v1"
const DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var summary := _run_case("1", 3)
	if not bool(summary.get("ok", false)):
		_fail("Guard engagement gate failed: %s" % JSON.stringify(summary))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"case": summary,
		"acceptance_scope": "strict Small h3maped generated hostile-town routes must hit guard engagement before town assault",
	})])
	get_tree().quit(0)

func _run_case(seed: String, player_count: int) -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		"",
		"",
		player_count,
		"land",
		false,
		"homm3_small"
	)
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	var summary := {
		"ok": false,
		"seed": seed,
		"player_count": player_count,
		"failures": [],
	}
	var failures: Array = summary["failures"]
	if not bool(setup.get("ok", false)):
		failures.append("setup_not_ok")
		summary["setup"] = setup
		return summary
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or String(session.scenario_id) == "":
		failures.append("session_start_failed")
		return summary
	OverworldRulesScript.normalize_overworld_state(session)
	var guards: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	var hero_pos := OverworldRulesScript.hero_position(session)
	var best := {}
	for town in towns:
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) == "player":
			continue
		var town_tile := Vector2i(int(town.get("x", -1)), int(town.get("y", -1)))
		var path := _build_direct_path(session, hero_pos, town_tile)
		if path.is_empty():
			continue
		var guard_gate := _first_guard_on_path(session, path)
		var candidate := {
			"town": town,
			"path": _path_payload(path),
			"distance": maxi(0, path.size() - 1),
			"guard_gate": guard_gate,
		}
		if best.is_empty() or int(candidate.get("distance", 999999)) < int(best.get("distance", 999999)):
			best = candidate
	if best.is_empty():
		failures.append("no_reachable_hostile_town")
	else:
		var guard_gate: Dictionary = best.get("guard_gate", {}) if best.get("guard_gate", {}) is Dictionary else {}
		if guard_gate.is_empty():
			guard_gate = _nearest_guard_gate(session, hero_pos, best.get("path", []))
			best["guard_gate"] = guard_gate
		if guard_gate.is_empty():
			failures.append("hostile_town_route_has_no_guard_engagement_fallback")
		else:
			var tile: Dictionary = guard_gate.get("tile", {}) if guard_gate.get("tile", {}) is Dictionary else {}
			session.overworld["hero_position"] = {"x": int(tile.get("x", -1)), "y": int(tile.get("y", -1))}
			var context: Dictionary = OverworldRulesScript.get_active_context(session)
			if String(context.get("type", "")) != "encounter":
				failures.append("guard_engagement_tile_did_not_expose_encounter_context")
			var action_ids := []
			for action in OverworldRulesScript.get_context_actions(session):
				if action is Dictionary:
					action_ids.append(String(action.get("id", "")))
			if not action_ids.has("enter_battle"):
				failures.append("guard_engagement_tile_did_not_expose_enter_battle")
			guard_gate["active_context_type"] = String(context.get("type", ""))
			guard_gate["context_action_ids"] = action_ids
			best["guard_gate"] = guard_gate
	summary["ok"] = failures.is_empty()
	summary["scenario_id"] = String(session.scenario_id)
	summary["hero_start"] = {"x": hero_pos.x, "y": hero_pos.y}
	summary["guard_count"] = guards.size()
	summary["town_count"] = towns.size()
	summary["nearest_hostile_town_gate"] = best
	return summary

func _build_direct_path(session, start: Vector2i, goal: Vector2i) -> Array:
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	if goal.x < 0 or goal.y < 0 or goal.x >= map_size.x or goal.y >= map_size.y:
		return []
	var queue: Array = [start]
	var queue_index := 0
	var visited := {_tile_key(start): true}
	var came_from := {_tile_key(start): start}
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		if current == goal:
			break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= map_size.x or next.y >= map_size.y:
				continue
			if visited.has(_tile_key(next)):
				continue
			if OverworldRulesScript.tile_step_cuts_blocked_corner(session, current, next):
				continue
			if OverworldRulesScript.tile_is_blocked(session, next.x, next.y) and next != goal:
				continue
			visited[_tile_key(next)] = true
			came_from[_tile_key(next)] = current
			queue.append(next)
	if not visited.has(_tile_key(goal)):
		return []
	var path: Array = [goal]
	var walker := goal
	while walker != start:
		walker = came_from.get(_tile_key(walker), start)
		path.push_front(walker)
	return path

func _first_guard_on_path(session, path: Array) -> Dictionary:
	for index in range(1, path.size()):
		if not (path[index] is Vector2i):
			continue
		var tile: Vector2i = path[index]
		var guard := OverworldRulesScript.guard_engagement_encounter_at_tile(session, tile.x, tile.y)
		if guard.is_empty():
			continue
		return {
			"step_index": index,
			"tile": {"x": tile.x, "y": tile.y},
			"placement_id": String(guard.get("placement_id", "")),
			"encounter_id": String(guard.get("encounter_id", "")),
			"guard_value": int(guard.get("guard_value", 0)),
		}
	return {}

func _nearest_guard_gate(session, start: Vector2i, preferred_path: Array) -> Dictionary:
	var best := {}
	var best_score := 999999
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	for encounter in encounters:
		if not (encounter is Dictionary):
			continue
		if OverworldRulesScript.is_encounter_resolved(session, encounter):
			continue
		for tile in _guard_engagement_tiles(encounter):
			if not (tile is Vector2i):
				continue
			var path := _build_direct_path(session, start, tile)
			if path.is_empty():
				continue
			var start_tile_penalty := 0
			if tile == start:
				start_tile_penalty = 100000
			var score: int = start_tile_penalty + _path_proximity_score(tile, preferred_path) * 1000 + max(0, path.size() - 1)
			if best.is_empty() or score < best_score:
				best = {
					"step_index": max(0, path.size() - 1),
					"tile": {"x": tile.x, "y": tile.y},
					"placement_id": String(encounter.get("placement_id", "")),
					"encounter_id": String(encounter.get("encounter_id", "")),
					"guard_value": int(encounter.get("guard_value", 0)),
					"fallback": "nearest_unresolved_h3m_guard_engagement",
				}
				best_score = score
	return best

func _guard_engagement_tiles(encounter: Dictionary) -> Array:
	for key in ["package_guard_engagement_tiles", "package_guard_control_zone_tiles", "guard_control_zone_tiles"]:
		var tiles: Array = encounter.get(key, []) if encounter.get(key, []) is Array else []
		var result := []
		for tile in tiles:
			if tile is Dictionary:
				result.append(Vector2i(int(tile.get("x", -1)), int(tile.get("y", -1))))
		if not result.is_empty():
			return result
	return [Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))]

func _path_proximity_score(tile: Vector2i, path: Array) -> int:
	if path.is_empty():
		return 0
	var best := 999
	for path_tile in path:
		if path_tile is Vector2i:
			best = mini(best, abs(tile.x - path_tile.x) + abs(tile.y - path_tile.y))
	return best

func _path_payload(path: Array) -> Array:
	var result := []
	for tile in path:
		if tile is Vector2i:
			result.append({"x": tile.x, "y": tile.y})
	return result

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
