extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_GUARDED_VICTORY_PLAYTEST_REPORT"
const REPORT_SCHEMA_ID := "native_rmg_small_h3maped_guarded_victory_playtest_report_v1"
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
		_fail("Guarded victory playtest failed: %s" % JSON.stringify(summary))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"case": summary,
		"acceptance_scope": "generated Small h3maped route reaches victory only after at least one guard engagement",
		"battle_policy": "deterministic_force_player_victory_for_route_validation_only",
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
		"route_steps": [],
		"guard_battles": [],
		"town_battles": [],
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

	var target_town := _first_enemy_town(session)
	if target_town.is_empty():
		failures.append("missing_enemy_town")
		return _finish_summary(summary, session)
	var target_tile := Vector2i(int(target_town.get("x", -1)), int(target_town.get("y", -1)))
	var guard_budget := 12
	while session.scenario_status == "in_progress" and guard_budget > 0:
		guard_budget -= 1
		var hero_pos := OverworldRulesScript.hero_position(session)
		var path := _build_direct_path(session, hero_pos, target_tile)
		if path.is_empty():
			failures.append("target_town_unreachable")
			break
		var guard_gate := _first_guard_on_path(session, path)
		if guard_gate.is_empty() and _guard_battle_count(summary) == 0:
			guard_gate = _nearest_guard_gate(session, hero_pos, path)
		if not guard_gate.is_empty():
			var guard_path: Array = guard_gate.get("path", []) if guard_gate.get("path", []) is Array else []
			if guard_path.is_empty():
				guard_path = _build_direct_path(session, hero_pos, _tile_from_payload(guard_gate.get("tile", {})))
			if not _walk_path(session, guard_path, summary):
				failures.append("guard_route_walk_failed")
				break
			var guard_result := _start_and_force_guard_battle(session, guard_gate)
			summary["guard_battles"].append(guard_result)
			if not bool(guard_result.get("ok", false)):
				failures.append("guard_battle_failed")
				break
			continue
		if not _walk_path(session, path, summary):
			failures.append("town_route_walk_failed")
			break
		var capture_result := OverworldRulesScript.perform_context_action(session, "capture_town")
		if not bool(capture_result.get("ok", false)) or session.battle.is_empty():
			failures.append("town_assault_not_started")
			summary["town_capture_result"] = capture_result
			break
		var town_result := _force_player_victory(session, "town_assault")
		summary["town_battles"].append(town_result)
		if not bool(town_result.get("ok", false)):
			failures.append("town_battle_failed")
		break
	if _guard_battle_count(summary) <= 0:
		failures.append("victory_route_encountered_no_guards")
	if session.scenario_status != "victory":
		failures.append("scenario_did_not_reach_victory")
	return _finish_summary(summary, session, target_town)

func _finish_summary(summary: Dictionary, session, target_town: Dictionary = {}) -> Dictionary:
	summary["ok"] = (summary.get("failures", []) is Array and summary.get("failures", []).is_empty())
	summary["scenario_id"] = String(session.scenario_id) if session != null else ""
	summary["scenario_status"] = String(session.scenario_status) if session != null else ""
	summary["final_day"] = int(session.day) if session != null else 0
	var final_pos := OverworldRulesScript.hero_position(session) if session != null else Vector2i(-1, -1)
	summary["final_hero_position"] = {"x": final_pos.x, "y": final_pos.y}
	summary["guard_battle_count"] = _guard_battle_count(summary)
	summary["town_battle_count"] = summary.get("town_battles", []).size() if summary.get("town_battles", []) is Array else 0
	summary["target_town"] = _compact_town(target_town)
	return summary

func _first_enemy_town(session) -> Dictionary:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town in towns:
		if town is Dictionary and String(town.get("owner", "neutral")) == "enemy":
			return town
	return {}

func _first_guard_on_path(session, path: Array) -> Dictionary:
	for index in range(1, path.size()):
		if not (path[index] is Vector2i):
			continue
		var tile: Vector2i = path[index]
		var guard := OverworldRulesScript.guard_engagement_encounter_at_tile(session, tile.x, tile.y)
		if guard.is_empty():
			continue
		return _guard_gate_payload(guard, tile, index, path.slice(0, index + 1), "direct_path")
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
				best = _guard_gate_payload(encounter, tile, max(0, path.size() - 1), path, "nearest_unresolved_h3m_guard_engagement")
				best_score = score
	return best

func _guard_gate_payload(encounter: Dictionary, tile: Vector2i, step_index: int, path: Array, source: String) -> Dictionary:
	return {
		"step_index": step_index,
		"tile": {"x": tile.x, "y": tile.y},
		"path": path.duplicate(true),
		"placement_id": String(encounter.get("placement_id", "")),
		"encounter_id": String(encounter.get("encounter_id", "")),
		"guard_value": int(encounter.get("guard_value", 0)),
		"source": source,
	}

func _start_and_force_guard_battle(session, guard_gate: Dictionary) -> Dictionary:
	var tile := _tile_from_payload(guard_gate.get("tile", {}))
	_set_active_hero_position(session, tile)
	OverworldRulesScript.normalize_overworld_state(session)
	var encounter := OverworldRulesScript.get_active_encounter(session)
	if encounter.is_empty():
		return {"ok": false, "reason": "missing_active_guard_encounter", "guard_gate": guard_gate}
	session.battle = BattleRulesScript.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		return {"ok": false, "reason": "guard_battle_payload_empty", "guard_gate": guard_gate}
	var result := _force_player_victory(session, "guard")
	result["guard_gate"] = guard_gate.duplicate(true)
	result["placement_id"] = String(encounter.get("placement_id", ""))
	return result

func _force_player_victory(session, label: String) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"ok": false, "reason": "missing_battle", "label": label}
	var context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	var stacks: Array = session.battle.get("stacks", []) if session.battle.get("stacks", []) is Array else []
	var has_player := false
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
		elif String(stack.get("side", "")) == "player":
			has_player = true
			stack["total_health"] = max(1, int(stack.get("total_health", stack.get("unit_hp", 1))))
		stacks[index] = stack
	session.battle["stacks"] = stacks
	if not has_player:
		return {"ok": false, "reason": "missing_player_stack", "label": label, "context": context}
	var outcome := BattleRulesScript.resolve_if_battle_ready(session)
	return {
		"ok": String(outcome.get("state", "")) == "victory",
		"label": label,
		"outcome": outcome,
		"context_type": String(context.get("type", "")),
		"town_placement_id": String(context.get("town_placement_id", "")),
		"scenario_status": String(session.scenario_status),
	}

func _walk_path(session, path: Array, summary: Dictionary) -> bool:
	if path.size() <= 1:
		return true
	for index in range(1, path.size()):
		if not (path[index] is Vector2i) or not (path[index - 1] is Vector2i):
			return false
		var before: Vector2i = path[index - 1]
		var target: Vector2i = path[index]
		_set_active_hero_position(session, before)
		var result: Dictionary = OverworldRulesScript.try_move(session, target.x - before.x, target.y - before.y)
		if not bool(result.get("ok", false)) and String(result.get("message", "")).begins_with("No movement left"):
			OverworldRulesScript.end_turn(session)
			_set_active_hero_position(session, before)
			result = OverworldRulesScript.try_move(session, target.x - before.x, target.y - before.y)
		summary["route_steps"].append({
			"from": {"x": before.x, "y": before.y},
			"to": {"x": target.x, "y": target.y},
			"ok": bool(result.get("ok", false)),
			"route": String(result.get("route", "")),
			"message": String(result.get("message", "")),
		})
		if not bool(result.get("ok", false)):
			return false
	return true

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and bool(heroes[index].get("is_active", false)):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _build_direct_path(session, start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return [start]
	var width := int(session.overworld.get("map_size", {}).get("width", 0))
	var height := int(session.overworld.get("map_size", {}).get("height", 0))
	var queue: Array = [start]
	var visited := {_tile_key(start): true}
	var came_from := {}
	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if visited.has(_tile_key(next)):
				continue
			if OverworldRulesScript.tile_step_cuts_blocked_corner(session, current, next):
				continue
			if next != goal and OverworldRulesScript.tile_is_blocked(session, next.x, next.y):
				continue
			visited[_tile_key(next)] = true
			came_from[_tile_key(next)] = current
			if next == goal:
				queue.clear()
				break
			queue.append(next)
	if not visited.has(_tile_key(goal)):
		return []
	var path: Array = [goal]
	var walker := goal
	while walker != start:
		walker = came_from.get(_tile_key(walker), start)
		path.push_front(walker)
	return path

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

func _tile_from_payload(value: Variant) -> Vector2i:
	var tile: Dictionary = value if value is Dictionary else {}
	return Vector2i(int(tile.get("x", -1)), int(tile.get("y", -1)))

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _guard_battle_count(summary: Dictionary) -> int:
	return summary.get("guard_battles", []).size() if summary.get("guard_battles", []) is Array else 0

func _compact_town(town: Dictionary) -> Dictionary:
	if town.is_empty():
		return {}
	return {
		"placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"owner": String(town.get("owner", "")),
		"x": int(town.get("x", -1)),
		"y": int(town.get("y", -1)),
	}

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
