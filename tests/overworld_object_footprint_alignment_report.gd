extends Node
## Generated objects place their sprite over their real footprint (owner
## report 2026-10-08: Bell Spire and smelter sprites drawn beside their
## interaction tiles). A generated object's x/y is its bottom-right tile in
## HoMM3 placement and can even lie outside its body, so the sprite rect must
## come from the body tiles: standing on the bottom row, centred over the
## columns, and covering the interaction tile. Runs on a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const Mines = preload("res://scripts/core/MineRules.gd")
const REPORT_ID := "OVERWORLD_OBJECT_FOOTPRINT_ALIGNMENT_REPORT"
const SEED := "object-footprint-alignment-20261008"

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_check(false, "small generated setup")
		_finish({})
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	session = SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _frames(8)
	var view = shell.get("_map_view")
	var board: Rect2 = view.call("_board_rect")
	var counts := {"sites": 0, "anchor_outside_body": 0, "multi_tile": 0, "mines": 0}
	var misplaced := []
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or not (node.get("body_tiles", []) is Array) or node.get("body_tiles", []).is_empty():
			continue
		var anchor := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
		var anchor_rect: Rect2 = view.call("_tile_rect", board, anchor)
		var tile_size := anchor_rect.size
		var rect: Rect2 = view.call("_resource_footprint_rect", node, anchor_rect, anchor)
		var visit := Vector2i(int(node.get("visit_tile", {}).get("x", anchor.x)), int(node.get("visit_tile", {}).get("y", anchor.y)))
		var visit_rect: Rect2 = view.call("_tile_rect", board, visit)
		counts.sites += 1
		if not Mines.resource(node).is_empty():
			# Mines keep their owner-selected three-by-two art around the entry.
			counts.mines += 1
			if not rect.encloses(visit_rect):
				misplaced.append("%s mine entry outside its art" % node.get("site_id", ""))
			continue
		var body: Rect2i = view.call("_resource_body_bounds", node)
		var body_rect := Rect2(board.position + Vector2(body.position) * tile_size, Vector2(body.size) * tile_size)
		if not body.has_point(anchor):
			counts.anchor_outside_body += 1
		if body.size.x > 1 or body.size.y > 1:
			counts.multi_tile += 1
		var centred := absf(rect.get_center().x - body_rect.get_center().x) < 0.5
		var grounded := absf(rect.end.y - body_rect.end.y) < 0.5
		var covers_visit := rect.encloses(visit_rect)
		if not (centred and grounded and covers_visit):
			misplaced.append("%s at %s: rect %s body %s" % [node.get("site_id", ""), anchor, rect, body])
	_check(counts.sites > 50, "the generated map has sites to check (%d)" % counts.sites)
	_check(counts.multi_tile > 0, "some generated sites are wider than one tile")
	_check(misplaced.is_empty(), "every generated site's sprite stands on its footprint and covers its interaction tile: %s" % str(misplaced.slice(0, 5)))
	shell.queue_free()
	await _frames(2)
	_finish(counts)

func _finish(counts: Dictionary) -> void:
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "counts": counts}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)
