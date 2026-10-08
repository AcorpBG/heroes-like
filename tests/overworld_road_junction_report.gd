extends Node
## Road junctions (owner report 2026-10-08: two meeting roads drew a doubled
## connection instead of a T). A cleared yard on a generated small map holds
## hand-built road layouts; the map view's road connections must turn fat
## two-tile clumps into one tree while leaving real loops and plain crossings
## alone. Presentation only: roads do not change movement.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const REPORT_ID := "OVERWORLD_ROAD_JUNCTION_REPORT"
const SEED := "road-junction-20261008"
const YARD := Rect2i(3, 3, 30, 18)
const CAPTURE := "res://.artifacts/overworld_road_junction.png"

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
		_finish()
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	var cases := _build_yard(session)
	session.game_state = "overworld"
	session = SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _frames(8)
	var view = shell.get("_map_view")
	var roads: Dictionary = view.get("_road_tiles")
	for name in cases:
		_check_case(roads, name, cases[name])
	if DisplayServer.get_name() != "headless":
		view.call("focus_on_tile", YARD.get_center())
		shell.call("_refresh_map_view")
		view.queue_redraw()
		await _frames(4)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts"))
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURE))
	shell.queue_free()
	await _frames(2)
	_finish()

## Grass yard, nothing on it, and only these roads on the map.
func _build_yard(session) -> Dictionary:
	var rows: Array = session.overworld.get("map", [])
	for y in range(YARD.position.y, YARD.end.y):
		var row: Array = rows[y]
		for x in range(YARD.position.x, YARD.end.x):
			row[x] = "grass"
		rows[y] = row
	session.overworld["map"] = rows
	for key in ["map_objects", "encounters", "artifact_nodes", "resource_nodes", "towns"]:
		session.overworld[key] = session.overworld.get(key, []).filter(func(entry): return not _near_yard(entry))
	var o := YARD.position
	var cases := {
		# A road from the north meets an east-west road; one extra tile closes
		# a 2x2 block at the junction.
		"t_with_fat_corner": {"tiles": _line(o + Vector2i(1, 4), o + Vector2i(8, 4)) + _line(o + Vector2i(4, 0), o + Vector2i(4, 3)) + [o + Vector2i(5, 3)],
			"ends": [o + Vector2i(1, 4), o + Vector2i(8, 4), o + Vector2i(4, 0)], "junctions": 1},
		# Two roads joined by a stretch two tiles wide.
		"double_stretch": {"tiles": _line(o + Vector2i(11, 2), o + Vector2i(14, 2)) + _line(o + Vector2i(15, 2), o + Vector2i(18, 2)) + _line(o + Vector2i(15, 3), o + Vector2i(18, 3)) + _line(o + Vector2i(19, 3), o + Vector2i(22, 3)),
			"ends": [o + Vector2i(11, 2), o + Vector2i(22, 3)], "junctions": 0},
		# A ring road around a field: a real loop that must stay a loop.
		"ring": {"tiles": _ring(o + Vector2i(1, 8), o + Vector2i(5, 12)) + _line(o + Vector2i(6, 10), o + Vector2i(8, 10)),
			"ends": [o + Vector2i(8, 10)], "ring": _ring(o + Vector2i(1, 8), o + Vector2i(5, 12))},
		# A plain crossing stays a crossing.
		"cross": {"tiles": _line(o + Vector2i(11, 10), o + Vector2i(17, 10)) + _line(o + Vector2i(14, 7), o + Vector2i(14, 9)) + _line(o + Vector2i(14, 11), o + Vector2i(14, 13)),
			"ends": [o + Vector2i(11, 10), o + Vector2i(17, 10), o + Vector2i(14, 7), o + Vector2i(14, 13)], "junctions": 1, "cross": o + Vector2i(14, 10)},
	}
	var road_tiles := []
	for name in cases:
		for tile in cases[name].tiles:
			road_tiles.append({"x": tile.x, "y": tile.y, "level": 0})
	var layers: Dictionary = session.overworld.get("terrain_layers", {})
	layers["roads"] = [{"id": "junction_report_roads", "overlay_id": "road_dirt", "tiles": road_tiles}]
	session.overworld["terrain_layers"] = layers
	var stand := {"x": o.x + 12, "y": YARD.end.y - 1}
	session.overworld["hero_position"] = stand
	var hero: Dictionary = session.overworld.hero
	hero["position"] = stand
	session.overworld["hero"] = hero
	HeroCommandRules.commit_active_hero(session)
	var size := OverworldRules.derive_map_size(session)
	var grid := []
	for y in range(size.y):
		var row := []
		row.resize(size.x)
		row.fill(true)
		grid.append(row)
	session.overworld[OverworldRules.FOG_KEY] = OverworldRules._build_fog_payload(grid, grid, size)
	OverworldRules.invalidate_spatial_lookup(session)
	return cases

func _near_yard(entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var area := YARD.grow(1)
	if area.has_point(Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))):
		return true
	for key in ["package_block_tiles", "body_tiles"]:
		for tile in entry.get(key, []):
			if tile is Dictionary and area.has_point(Vector2i(int(tile.get("x", -1)), int(tile.get("y", -1)))):
				return true
	return false

func _line(from: Vector2i, to: Vector2i) -> Array:
	var tiles := []
	var step := (to - from).sign()
	var tile := from
	tiles.append(tile)
	while tile != to:
		tile += step
		tiles.append(tile)
	return tiles

func _ring(low: Vector2i, high: Vector2i) -> Array:
	var tiles := []
	for x in range(low.x, high.x + 1):
		tiles.append(Vector2i(x, low.y))
		tiles.append(Vector2i(x, high.y))
	for y in range(low.y + 1, high.y):
		tiles.append(Vector2i(low.x, y))
		tiles.append(Vector2i(high.x, y))
	return tiles

func _check_case(roads: Dictionary, name: String, spec: Dictionary) -> void:
	var drawn := {}
	for tile in spec.tiles:
		var payload: Dictionary = roads.get("%d,%d" % [tile.x, tile.y], {})
		if not payload.is_empty() and not bool(payload.get("presentation_hidden", false)):
			drawn[tile] = payload.get("connections", [])
	var neighbours := func(tile: Vector2i) -> Array:
		var result := []
		for pair in [["N", Vector2i.UP], ["E", Vector2i.RIGHT], ["S", Vector2i.DOWN], ["W", Vector2i.LEFT]]:
			if pair[0] in drawn.get(tile, []):
				result.append(tile + pair[1])
		return result
	var symmetric := true
	for tile in drawn:
		for next in neighbours.call(tile):
			if not drawn.has(next) or not (tile in neighbours.call(next)):
				symmetric = false
	_check(symmetric, "%s: drawn connections are mutual and lead only to drawn tiles" % name)
	var closed := 0
	for tile in drawn:
		if tile + Vector2i.RIGHT in neighbours.call(tile) and tile + Vector2i.DOWN in neighbours.call(tile) \
			and tile + Vector2i(1, 1) in neighbours.call(tile + Vector2i.RIGHT) and tile + Vector2i(1, 1) in neighbours.call(tile + Vector2i.DOWN):
			closed += 1
	_check(closed == 0, "%s: no doubled 2x2 connection is drawn (%d)" % [name, closed])
	var reached := {}
	var queue: Array = [spec.ends[0]]
	reached[spec.ends[0]] = true
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		for next in neighbours.call(tile):
			if not reached.has(next):
				reached[next] = true
				queue.append(next)
	_check(spec.ends.all(func(end): return reached.has(end)), "%s: every road end still connects (%s)" % [name, spec.ends])
	if spec.has("junctions"):
		var branching := 0
		for tile in drawn:
			if neighbours.call(tile).size() >= 3:
				branching += 1
		_check(branching == int(spec.junctions), "%s: %d junction tile(s) drawn (got %d)" % [name, int(spec.junctions), branching])
	if spec.has("cross"):
		_check(neighbours.call(spec.cross).size() == 4, "%s: the crossing keeps all four arms" % name)
	if spec.has("ring"):
		_check(drawn.size() == spec.tiles.size() and spec.ring.all(func(tile): return neighbours.call(tile).size() >= 2), "%s: the ring stays whole" % name)

func _finish() -> void:
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)
