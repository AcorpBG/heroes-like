extends Node
## Readability of blocked scenery and pickups (owner request 2026-10-08), on a
## generated small map with only the affected objects checked:
## - every blocked scenery tile shows art (formation gaps and tiny pieces get
##   a filler or a minimum size): the map is rendered screen by screen with and
##   without scenery and each scenery-blocked tile's painted share is measured;
## - pickups are drawn above neighbouring canopy and large enough: artifacts
##   and caches are placed on free tiles just above scenery (where canopy used
##   to cover them) and in open ground, then each is drawn with and without
##   itself.
## Pixel checks need a window; headless runs check the indexes only.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const REPORT_ID := "OVERWORLD_SCENERY_PICKUP_READABILITY_REPORT"
const SEED := "scenery-pickup-readability-20261008"
const CAPTURE_DIR := "res://.artifacts/scenery_pickup_readability"
const MIN_TILE_SHARE := 0.10

var _checks := 0
var _failures := []
var _metrics := {}

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
	_reveal(session)
	var pickups := _place_pickups(session)
	session.game_state = "overworld"
	session = SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _frames(10)
	var view = shell.get("_map_view")
	view.validation_set_force_index_rebuild(true)
	await _redraw(shell, view)
	_index_section(view)
	if DisplayServer.get_name() == "headless":
		print("%s headless: pixel checks skipped" % REPORT_ID)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
		await _pickup_section(shell, view, session, pickups)
		await _scenery_section(shell, view, session)
	shell.queue_free()
	await _frames(2)
	_finish()

func _reveal(session) -> void:
	var size := OverworldRules.derive_map_size(session)
	var grid := []
	for y in range(size.y):
		var row := []
		row.resize(size.x)
		row.fill(true)
		grid.append(row)
	session.overworld[OverworldRules.FOG_KEY] = OverworldRules._build_fog_payload(grid, grid, size)

# --- placement -----------------------------------------------------------------

## Artifacts and caches on free tiles whose southern neighbour is blocked
## scenery (its canopy reaches up over them), plus two in open ground.
func _place_pickups(session) -> Array:
	var size := OverworldRules.derive_map_size(session)
	var scenery := {}
	for object in session.overworld.get("map_objects", []):
		for tile in object.get("package_block_tiles", []):
			scenery[Vector2i(int(tile.x), int(tile.y))] = true
	var taken := {}
	for key in ["resource_nodes", "artifact_nodes", "towns", "encounters"]:
		for entry in session.overworld.get(key, []):
			taken[Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))] = true
			for tile in entry.get("body_tiles", []):
				taken[Vector2i(int(tile.x), int(tile.y))] = true
	taken[OverworldRules.hero_position(session)] = true
	var edge := []
	var open := []
	for y in range(1, size.y - 2):
		for x in range(1, size.x - 1):
			var tile := Vector2i(x, y)
			if scenery.has(tile) or taken.has(tile) or not OverworldRules.terrain_id_is_passable(OverworldRules._terrain_id_at(session, x, y, 0)):
				continue
			if scenery.has(tile + Vector2i.DOWN) and scenery.has(tile + Vector2i.DOWN + Vector2i.LEFT):
				edge.append(tile)
			elif not scenery.has(tile + Vector2i.DOWN) and not scenery.has(tile + Vector2i.UP) and not scenery.has(tile + Vector2i.LEFT) and not scenery.has(tile + Vector2i.RIGHT):
				open.append(tile)
	var picked := []
	for tile in edge:
		if picked.size() >= 6:
			break
		if picked.all(func(other): return (other as Vector2i).distance_to(tile) >= 4.0):
			picked.append(tile)
	var open_picked := []
	for tile in open:
		if open_picked.size() >= 2:
			break
		if open_picked.all(func(other): return (other as Vector2i).distance_to(tile) >= 6.0) and picked.all(func(other): return (other as Vector2i).distance_to(tile) >= 3.0):
			open_picked.append(tile)
	_metrics["edge_pickups"] = picked.size()
	_metrics["open_pickups"] = open_picked.size()
	_check(picked.size() >= 4, "the map has free tiles just above scenery for pickups (%d)" % picked.size())
	var artifact_ids := ["artifact_meridian_choir_prism", "artifact_pollenglass_spore_ampoule", "artifact_wakebell_mourning_ensign", "artifact_quarry_tally_rod"]
	var placed := []
	var index := 0
	for tile in picked + open_picked:
		var id := "readability_pickup_%d" % index
		if index % 2 == 0:
			session.overworld.artifact_nodes.append({"placement_id": id, "artifact_id": artifact_ids[(index / 2) % artifact_ids.size()], "x": tile.x, "y": tile.y, "level": 0, "collected": false})
			placed.append({"id": id, "array": "artifact_nodes", "tile": tile, "edge": tile in picked})
		else:
			var site := ContentService.get_map_object("object_wayfarer_camp_cache")
			session.overworld.resource_nodes.append({"placement_id": id, "site_id": String(site.get("resource_site_id", "")), "object_id": "object_wayfarer_camp_cache", "kind": "resource_site", "x": tile.x, "y": tile.y, "level": 0, "collected": false})
			placed.append({"id": id, "array": "resource_nodes", "tile": tile, "edge": tile in picked})
		index += 1
	OverworldRules.invalidate_spatial_lookup(session)
	return placed

# --- index -----------------------------------------------------------------------

func _index_section(view) -> void:
	var cells: Dictionary = view.get("_generated_decorative_bodies_by_tile")
	var fillers := 0
	for key in cells:
		if not cells[key].get("generated_body_fillers", []).is_empty():
			fillers += 1
	_metrics["scenery_cells"] = cells.size()
	_metrics["filler_cells"] = fillers
	_check(cells.size() > 100, "the map has scenery to check (%d cells)" % cells.size())
	_check(fillers > 0 and fillers < cells.size() / 3, "only bare cells get a filler (%d of %d)" % [fillers, cells.size()])

# --- pixels ------------------------------------------------------------------------

func _pickup_section(shell, view, session, pickups: Array) -> void:
	for pickup in pickups:
		var tile: Vector2i = pickup.tile
		view.call("focus_on_tile", tile)
		await _redraw(shell, view)
		var with_image := get_viewport().get_texture().get_image()
		var array: Array = session.overworld.get(String(pickup.array), [])
		var index := -1
		for i in range(array.size()):
			if String(array[i].get("placement_id", "")) == String(pickup.id):
				index = i
		var removed = array[index]
		array.remove_at(index)
		await _redraw(shell, view)
		var without := get_viewport().get_texture().get_image()
		array.insert(index, removed)
		var cell := _cell_rect(view, tile)
		var drawn := _diff_box(with_image, without, cell.grow(cell.size.x * 0.5))
		var share := _diff_share(with_image, without, cell)
		_check(share > 0.06, "%s at %s is visible (%.2f of its tile drawn)" % [pickup.id, tile, share])
		_check(drawn.size.x >= cell.size.x * 0.45 or drawn.size.y >= cell.size.y * 0.5, "%s at %s reads at a glance (%.0fx%.0f px on a %.0f px tile)" % [pickup.id, tile, drawn.size.x, drawn.size.y, cell.size.x])
		if pickup.edge and pickup.id.ends_with("0"):
			with_image.get_region(Rect2i(cell.grow(cell.size.x * 2.0).intersection(Rect2(Vector2.ZERO, Vector2(with_image.get_size()))))).save_png(ProjectSettings.globalize_path("%s/%s.png" % [CAPTURE_DIR, pickup.id]))
	await _redraw(shell, view)

func _scenery_section(shell, view, session) -> void:
	var size := OverworldRules.derive_map_size(session)
	var blocked := {}
	for object in session.overworld.get("map_objects", []):
		for tile in object.get("package_block_tiles", []):
			blocked[Vector2i(int(tile.x), int(tile.y))] = true
	var objects := {}
	for key in ["resource_nodes", "towns", "encounters", "artifact_nodes"]:
		for entry in session.overworld.get(key, []):
			for tile in entry.get("body_tiles", [{"x": entry.get("x", -1), "y": entry.get("y", -1)}]):
				objects[Vector2i(int(tile.x), int(tile.y))] = true
	var best := {}
	var scenery: Array = session.overworld.get("map_objects", []).duplicate()
	var centers := []
	for y in range(5, size.y + 9, 9):
		for x in range(9, size.x + 15, 15):
			centers.append(Vector2i(mini(x, size.x - 1), mini(y, size.y - 1)))
	for center in centers:
		view.call("focus_on_tile", center)
		session.overworld["map_objects"] = scenery
		await _redraw(shell, view)
		var with_image := get_viewport().get_texture().get_image()
		if center == centers[0]:
			with_image.save_png(ProjectSettings.globalize_path("%s/scenery_screen.png" % CAPTURE_DIR))
		session.overworld["map_objects"] = []
		await _redraw(shell, view)
		var without := get_viewport().get_texture().get_image()
		var map_rect := (view as Control).get_global_rect()
		for tile in blocked:
			var cell := _cell_rect(view, tile)
			if not map_rect.encloses(cell):
				continue
			best[tile] = maxf(float(best.get(tile, 0.0)), _diff_share(with_image, without, cell))
	session.overworld["map_objects"] = scenery
	await _redraw(shell, view)
	var bare := []
	for tile in best:
		if float(best[tile]) < MIN_TILE_SHARE and not objects.has(tile):
			bare.append(tile)
	_metrics["scenery_tiles_measured"] = best.size()
	_metrics["bare_scenery_tiles"] = bare.size()
	_check(best.size() > 100, "scenery tiles were measured (%d)" % best.size())
	_check(bare.is_empty(), "every blocked scenery tile shows art (%d bare: %s)" % [bare.size(), str(bare.slice(0, 8))])

func _redraw(shell, view) -> void:
	OverworldRules.invalidate_spatial_lookup(SessionState.ensure_active_session())
	shell.call("_refresh_map_view")
	for method in ["_invalidate_session_static_cache", "_invalidate_state_cache", "_invalidate_dynamic_layer", "_invalidate_terrain_ambient_layer"]:
		view.call(method, "readability_report")
	view.queue_redraw()
	await _frames(3)
	await RenderingServer.frame_post_draw

func _cell_rect(view, tile: Vector2i) -> Rect2:
	var cell: Rect2 = view.call("_tile_rect", view.call("_board_rect"), tile)
	cell.position += (view as Control).get_global_rect().position
	return cell

func _changed(a: Image, b: Image, x: int, y: int) -> bool:
	var ca := a.get_pixel(x, y)
	var cb := b.get_pixel(x, y)
	return absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.16

func _diff_share(a: Image, b: Image, cell: Rect2) -> float:
	var hit := 0
	var total := 0
	for y in range(int(cell.position.y), int(cell.end.y), 2):
		for x in range(int(cell.position.x), int(cell.end.x), 2):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			total += 1
			if _changed(a, b, x, y):
				hit += 1
	return float(hit) / float(maxi(total, 1))

func _diff_box(a: Image, b: Image, area: Rect2) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for y in range(int(area.position.y), int(area.end.y)):
		for x in range(int(area.position.x), int(area.end.x)):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			if _changed(a, b, x, y):
				low = Vector2(minf(low.x, x), minf(low.y, y))
				high = Vector2(maxf(high.x, x), maxf(high.y, y))
	return Rect2(low, high - low) if high.x >= low.x else Rect2()

func _finish() -> void:
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "metrics": _metrics}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)
