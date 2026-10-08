extends Node
## Focused check on a custom map with only the affected objects (owner request
## 2026-10-08): a cleared yard on a generated small map holds hand-built
## HoMM3-style footprints for the sites whose art is narrower than the tiles
## they block (Bell Spire on grass and snow, Slipgate Mirror, Tide Kiln, Basalt
## Oath Tomb, a sawmill) and for claimed one-time sites (a looted Glassbound
## Eyrie and Barrow Vault, an opened Railblock Camp) next to an unclaimed Eyrie
## and a collected pickup.
##
## Rules: claimed sites that remain after their visit stay present and keep
## blocking; an opened route camp stays present but no longer blocks; a taken
## pickup is gone. Map: every bare blocked tile gets a terrain rock, the
## entrance never does. With a window, the yard is rendered and every object
## is drawn again without itself: each blocked tile must show its art or a
## rock, and the claimed sites must draw their secured art.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const REPORT_ID := "GENERATED_SITE_FOOTPRINT_DRESSING_REPORT"
const SEED := "site-footprint-dressing-20261008"
const YARD := Rect2i(4, 6, 19, 12)
const CAPTURE := "res://.artifacts/generated_site_footprint_dressing.png"

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
	SettingsService.ensure_settings()["accessibility"]["reduce_motion"] = true
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_check(false, "small generated setup")
		_finish()
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	var sites := _build_yard(session)
	session = SessionState.set_active_session(session)
	_rules_section(session, sites)
	await _map_section(session, sites)
	_finish()

# --- custom yard ---------------------------------------------------------------

## Clears the yard (grass west, snow east), keeps towns and heroes outside it,
## and places the test sites. Anchors are bottom-right tiles, as in a package.
func _build_yard(session) -> Dictionary:
	var rows: Array = session.overworld.get("map", [])
	for y in range(YARD.position.y, YARD.end.y):
		var row: Array = rows[y]
		for x in range(YARD.position.x, YARD.end.x):
			row[x] = "grass" if x < YARD.position.x + 10 else "snow"
		rows[y] = row
	session.overworld["map"] = rows
	for key in ["map_objects", "encounters", "artifact_nodes", "resource_nodes"]:
		session.overworld[key] = session.overworld.get(key, []).filter(func(entry): return not _touches_yard(entry))
	session.overworld["towns"] = session.overworld.get("towns", []).filter(func(entry): return not (entry is Dictionary and YARD.grow(2).has_point(Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1))))))
	var o := YARD.position
	var sites := {
		"bell_spire": _site("object_visit_bell_spire", _row(o + Vector2i(0, 2), 3), o + Vector2i(1, 2)),
		"slipgate": _site("object_slipgate_mirror", _row(o + Vector2i(4, 2), 2), o + Vector2i(4, 2)),
		"eyrie": _site("object_glassbound_eyrie", _row(o + Vector2i(7, 2), 3), o + Vector2i(8, 2)),
		"eyrie_looted": _site("object_glassbound_eyrie", _row(o + Vector2i(11, 2), 3), o + Vector2i(12, 2), "looted"),
		"railblock_opened": _site("object_railblock_camp", _row(o + Vector2i(15, 2), 3), o + Vector2i(16, 2), "opened"),
		"tide_kiln": _site("object_tide_kiln", _row(o + Vector2i(0, 5), 3) + _row(o + Vector2i(0, 6), 3), o + Vector2i(2, 6)),
		"tomb": _site("object_basalt_oath_tomb", _row(o + Vector2i(5, 5), 4) + _row(o + Vector2i(4, 6), 5), o + Vector2i(8, 6)),
		"sawmill": _site("object_brightwood_sawmill", _row(o + Vector2i(12, 5), 2) + _row(o + Vector2i(10, 6), 4), o + Vector2i(12, 6)),
		"bell_spire_snow": _site("object_visit_bell_spire", _row(o + Vector2i(11, 10), 3), o + Vector2i(12, 10)),
		"barrow_looted": _site("object_barrow_vault", _row(o + Vector2i(15, 10), 2), o + Vector2i(15, 10), "looted"),
		"cache_taken": _site("object_wayfarer_camp_cache", _row(o + Vector2i(2, 10), 1), o + Vector2i(2, 10), "looted"),
	}
	for key in sites:
		session.overworld.resource_nodes.append(sites[key])
	# The hero waits just below the yard.
	var stand := {"x": o.x + 7, "y": YARD.end.y}
	session.overworld["hero_position"] = stand
	var hero: Dictionary = session.overworld.hero
	hero["position"] = stand
	session.overworld["hero"] = hero
	HeroCommandRules.commit_active_hero(session)
	# The yard is fully explored so every site draws.
	var size := OverworldRules.derive_map_size(session)
	var grid := []
	for y in range(size.y):
		var fog_row := []
		fog_row.resize(size.x)
		fog_row.fill(true)
		grid.append(fog_row)
	session.overworld[OverworldRules.FOG_KEY] = OverworldRules._build_fog_payload(grid, grid, size)
	OverworldRules.invalidate_spatial_lookup(session)
	return sites

func _touches_yard(entry: Variant) -> bool:
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

func _row(start: Vector2i, width: int) -> Array:
	var tiles := []
	for x in range(width):
		tiles.append({"x": start.x + x, "y": start.y, "level": 0})
	return tiles

func _site(object_id: String, body: Array, visit: Vector2i, state: String = "") -> Dictionary:
	var anchor := Vector2i(-1, -1)
	for tile in body:
		anchor = Vector2i(maxi(anchor.x, int(tile.x)), maxi(anchor.y, int(tile.y)))
	var object := ContentService.get_map_object(object_id)
	var node := {
		"placement_id": "dressing_%s_%d_%d" % [object_id.trim_prefix("object_"), anchor.x, anchor.y],
		"site_id": String(object.get("resource_site_id", "")),
		"object_id": object_id,
		"kind": "resource_site",
		"x": anchor.x,
		"y": anchor.y,
		"level": 0,
		"collected": false,
		"blocking_body": true,
		"body_tiles": body.duplicate(true),
		"package_body_tiles": body.duplicate(true),
		"package_block_tiles": body.duplicate(true),
		"package_visit_tiles": [{"x": visit.x, "y": visit.y, "level": 0}],
		"visit_tile": {"x": visit.x, "y": visit.y, "level": 0},
	}
	if state != "":
		node["collected"] = true
		node["collected_by_faction_id"] = "player"
		node["collected_day"] = 1
	if state == "opened":
		node["blocking_body"] = false
		node["package_block_tiles"] = []
		node["route_state_id"] = "opened"
		node["state_id"] = "opened"
	return node

# --- rules -------------------------------------------------------------------------

func _rules_section(session, sites: Dictionary) -> void:
	var live := {}
	for node in session.overworld.get("resource_nodes", []):
		live[String(node.get("placement_id", ""))] = node
	_check(live.has(String(sites.tomb.placement_id)) and not live[String(sites.tomb.placement_id)].get("package_block_tiles", []).is_empty(), "the yard survives normalization with its package footprints")
	for key in ["eyrie_looted", "barrow_looted", "railblock_opened"]:
		_check(OverworldRules.resource_node_is_present(live.get(String(sites[key].placement_id), {})), "%s stays on the map after its visit" % key)
	_check(not OverworldRules.resource_node_is_present(live.get(String(sites.cache_taken.placement_id), {})), "a taken pickup is gone")
	for tile in sites.eyrie_looted.package_block_tiles:
		_check(OverworldRules.hero_route_tile_blocked(session, int(tile.x), int(tile.y), 0), "the looted Eyrie still blocks %d,%d" % [int(tile.x), int(tile.y)])
	for tile in sites.railblock_opened.package_body_tiles:
		_check(not OverworldRules.hero_route_tile_blocked(session, int(tile.x), int(tile.y), 0), "the opened Railblock Camp lets heroes through %d,%d" % [int(tile.x), int(tile.y)])

# --- map ---------------------------------------------------------------------------

func _map_section(session, sites: Dictionary) -> void:
	session.game_state = "overworld"
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _frames(10)
	var view = shell.get("_map_view")
	view.validation_set_force_index_rebuild(true)
	view.call("focus_on_tile", YARD.get_center())
	await _redraw(shell, view)
	var board: Rect2 = view.call("_board_rect")
	var expected_rocks := {"bell_spire": 2, "bell_spire_snow": 2, "slipgate": 1, "railblock_opened": 0}
	var rock_tiles := {}
	for key in sites:
		var node: Dictionary = sites[key]
		var anchor := Vector2i(int(node.x), int(node.y))
		var anchor_rect: Rect2 = view.call("_tile_rect", board, anchor)
		var rect: Rect2 = view.call("_resource_draw_rect", node, anchor_rect, anchor)
		var rocks: Array = view.call("_resource_flank_rock_tiles", node, rect, anchor_rect, anchor)
		rock_tiles[key] = rocks
		var visit := Vector2i(int(node.visit_tile.x), int(node.visit_tile.y))
		_check(not rocks.has(visit), "%s keeps its entrance clear of rocks" % key)
		if expected_rocks.has(key):
			_check(rocks.size() == int(expected_rocks[key]), "%s gets %d flank rocks (got %d: %s)" % [key, int(expected_rocks[key]), rocks.size(), rocks])
	_check(not rock_tiles.tide_kiln.is_empty() and not rock_tiles.tomb.is_empty(), "wide sites with an end entrance get rocks on their bare tiles")
	if DisplayServer.get_name() == "headless":
		print("%s headless: pixel checks skipped" % REPORT_ID)
		shell.queue_free()
		return
	await RenderingServer.frame_post_draw
	var full := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts"))
	full.save_png(ProjectSettings.globalize_path(CAPTURE))
	for key in sites:
		if key == "cache_taken":
			continue
		var node: Dictionary = sites[key]
		var drawn := await _drawn_mask(shell, view, session, node)
		var blocked: Array = node.get("package_block_tiles", [])
		var visit := Vector2i(int(node.visit_tile.x), int(node.visit_tile.y))
		_check(_coverage(drawn, view, visit) > 0.08, "%s draws over its entrance" % key)
		for tile in blocked:
			var cover := _coverage(drawn, view, Vector2i(int(tile.x), int(tile.y)))
			_check(cover > 0.06, "%s: blocked tile %d,%d shows art or a rock (%.2f)" % [key, int(tile.x), int(tile.y), cover])
	shell.queue_free()
	await _frames(2)

func _redraw(shell, view) -> void:
	OverworldRules.invalidate_spatial_lookup(SessionState.ensure_active_session())
	shell.call("_refresh_map_view")
	for method in ["_invalidate_session_static_cache", "_invalidate_state_cache", "_invalidate_dynamic_layer", "_invalidate_terrain_ambient_layer"]:
		view.call(method, "dressing_report")
	view.queue_redraw()
	await _frames(3)
	await RenderingServer.frame_post_draw

## Pixels this object draws: the yard with it, minus the yard without it.
func _drawn_mask(shell, view, session, node: Dictionary) -> Dictionary:
	var with_image := get_viewport().get_texture().get_image()
	var nodes: Array = session.overworld.resource_nodes
	var index := -1
	for i in range(nodes.size()):
		if String(nodes[i].get("placement_id", "")) == String(node.placement_id):
			index = i
	var removed = nodes[index]
	nodes.remove_at(index)
	await _redraw(shell, view)
	var without := get_viewport().get_texture().get_image()
	nodes.insert(index, removed)
	await _redraw(shell, view)
	return {"with": with_image, "without": without}

func _coverage(drawn: Dictionary, view, tile: Vector2i) -> float:
	var board: Rect2 = view.call("_board_rect")
	var origin := (view as Control).get_global_rect().position
	var cell: Rect2 = view.call("_tile_rect", board, tile)
	cell.position += origin
	var a: Image = drawn.with
	var b: Image = drawn.without
	var hit := 0
	var total := 0
	for y in range(int(cell.position.y), int(cell.end.y), 2):
		for x in range(int(cell.position.x), int(cell.end.x), 2):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += 1
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.16:
				hit += 1
	return float(hit) / float(maxi(total, 1))

func _finish() -> void:
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)
