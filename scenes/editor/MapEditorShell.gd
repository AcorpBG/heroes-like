class_name MapEditorShell
extends Control

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")

const DEFAULT_SCENARIO_ID := "ninefold-confluence"
const DEFAULT_TERRAIN_ID := "grass"
const EDITOR_ROAD_LAYER_ID := "editor_working_road"
const EDITOR_ROAD_OVERLAY_ID := "road_dirt"
const TOOL_INSPECT := "inspect"
const TOOL_TERRAIN := "terrain"
const TOOL_ROAD := "road"
const TOOL_HERO_START := "hero_start"

@onready var _header_label: Label = %Header
@onready var _scenario_picker: OptionButton = %ScenarioPicker
@onready var _terrain_picker: OptionButton = %TerrainPicker
@onready var _inspect_tool_button: Button = %InspectTool
@onready var _terrain_tool_button: Button = %TerrainTool
@onready var _road_tool_button: Button = %RoadTool
@onready var _hero_start_tool_button: Button = %HeroStartTool
@onready var _tile_info_label: Label = %TileInfo
@onready var _status_label: Label = %Status
@onready var _map_view = %Map
@onready var _play_button: Button = %PlayWorkingCopy
@onready var _menu_button: Button = %Menu

var _session = null
var _scenario_entries: Array = []
var _terrain_entries: Array = []
var _selected_scenario_id := ""
var _selected_terrain_id := DEFAULT_TERRAIN_ID
var _selected_tile := Vector2i.ZERO
var _hovered_tile := Vector2i(-1, -1)
var _tool := TOOL_INSPECT
var _dirty := false
var _last_message := ""

func _ready() -> void:
	_apply_visual_theme()
	_connect_ui()
	_rebuild_terrain_picker()
	_rebuild_scenario_picker()
	_select_tool(TOOL_INSPECT)
	if _selected_scenario_id != "":
		_load_scenario_working_copy(_selected_scenario_id)

func _connect_ui() -> void:
	_scenario_picker.item_selected.connect(_on_scenario_selected)
	_terrain_picker.item_selected.connect(_on_terrain_selected)
	_inspect_tool_button.pressed.connect(func(): _select_tool(TOOL_INSPECT))
	_terrain_tool_button.pressed.connect(func(): _select_tool(TOOL_TERRAIN))
	_road_tool_button.pressed.connect(func(): _select_tool(TOOL_ROAD))
	_hero_start_tool_button.pressed.connect(func(): _select_tool(TOOL_HERO_START))
	_play_button.pressed.connect(_on_play_working_copy_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	if _map_view != null:
		_map_view.tile_pressed.connect(_on_map_tile_pressed)
		_map_view.tile_hovered.connect(_on_map_tile_hovered)

func _rebuild_scenario_picker() -> void:
	_scenario_entries = _scenario_items()
	_scenario_picker.clear()
	var selected_index := -1
	for index in range(_scenario_entries.size()):
		var scenario: Dictionary = _scenario_entries[index]
		var scenario_id := String(scenario.get("id", ""))
		var map_size: Dictionary = scenario.get("map_size", {})
		var label := "%s | %dx%d" % [
			String(scenario.get("name", scenario_id)),
			int(map_size.get("width", 0)),
			int(map_size.get("height", 0)),
		]
		_scenario_picker.add_item(label, index)
		_scenario_picker.set_item_metadata(index, scenario_id)
		if scenario_id == DEFAULT_SCENARIO_ID:
			selected_index = index
	if selected_index < 0 and not _scenario_entries.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_scenario_picker.select(selected_index)
		_selected_scenario_id = String(_scenario_picker.get_item_metadata(selected_index))

func _rebuild_terrain_picker() -> void:
	_terrain_entries = _terrain_items()
	_terrain_picker.clear()
	var selected_index := -1
	for index in range(_terrain_entries.size()):
		var terrain: Dictionary = _terrain_entries[index]
		var terrain_id := String(terrain.get("id", ""))
		_terrain_picker.add_item(String(terrain.get("label", terrain_id.capitalize())), index)
		_terrain_picker.set_item_metadata(index, terrain_id)
		if terrain_id == DEFAULT_TERRAIN_ID:
			selected_index = index
	if selected_index < 0 and not _terrain_entries.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_terrain_picker.select(selected_index)
		_selected_terrain_id = String(_terrain_picker.get_item_metadata(selected_index))

func _scenario_items() -> Array:
	var raw := ContentService.load_json("res://content/scenarios.json")
	var items = raw.get("items", [])
	return items if items is Array else []

func _terrain_items() -> Array:
	var grammar := ContentService.get_terrain_grammar()
	var classes = grammar.get("terrain_classes", [])
	var items := []
	if not (classes is Array):
		return items
	for terrain_class in classes:
		if not (terrain_class is Dictionary):
			continue
		var terrain_id := String(terrain_class.get("id", ""))
		if terrain_id == "":
			continue
		items.append(
			{
				"id": terrain_id,
				"label": String(terrain_class.get("label", terrain_id.capitalize())),
			}
		)
	return items

func _load_scenario_working_copy(scenario_id: String) -> bool:
	var session = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if session == null or session.scenario_id == "":
		_last_message = "Unable to load scenario %s into the editor." % scenario_id
		_refresh_state()
		return false
	_session = session
	OverworldRules.normalize_overworld_state(_session)
	_make_all_tiles_visible(_session)
	_selected_scenario_id = scenario_id
	_selected_tile = OverworldRules.hero_position(_session)
	_dirty = false
	_last_message = "Loaded authored scenario into a mutable editor working copy."
	_refresh_state()
	return true

func _make_all_tiles_visible(session) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles := []
	var explored_tiles := []
	for y in range(map_size.y):
		var visible_row := []
		var explored_row := []
		for x in range(map_size.x):
			visible_row.append(true)
			explored_row.append(true)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": map_size.x * map_size.y,
		"explored_count": map_size.x * map_size.y,
		"total_tiles": map_size.x * map_size.y,
	}

func _refresh_state() -> void:
	_sync_tool_buttons()
	_sync_preview()
	_refresh_labels()

func _sync_preview() -> void:
	if _session == null or _map_view == null:
		return
	var map_size := OverworldRules.derive_map_size(_session)
	var map_data: Array = _session.overworld.get("map", [])
	_map_view.set_map_state(_session, map_data, map_size, _selected_tile)

func _refresh_labels() -> void:
	if _session == null:
		_header_label.text = "Map Editor"
		_set_compact_label(_tile_info_label, "No scenario loaded.", 4)
		_set_compact_label(_status_label, _last_message, 2)
		return
	var scenario := ContentService.get_scenario(_session.scenario_id)
	var map_size := OverworldRules.derive_map_size(_session)
	_header_label.text = "Map Editor | %s" % String(scenario.get("name", _session.scenario_id))
	var state_line := "Working copy | %dx%d | Tool %s | Terrain %s | Roads %d" % [
		map_size.x,
		map_size.y,
		_tool_label(_tool),
		_selected_terrain_id,
		_road_tile_count(),
	]
	if _dirty:
		state_line = "%s | Unsaved in memory" % state_line
	_set_compact_label(_status_label, "%s\n%s" % [state_line, _last_message], 3)
	_set_compact_label(_tile_info_label, _tile_inspection_text(_selected_tile), 12)

func _tool_label(tool: String) -> String:
	match tool:
		TOOL_TERRAIN:
			return "Terrain"
		TOOL_ROAD:
			return "Road"
		TOOL_HERO_START:
			return "Hero Start"
		_:
			return "Inspect"

func _select_tool(tool: String) -> void:
	_tool = tool if tool in [TOOL_INSPECT, TOOL_TERRAIN, TOOL_ROAD, TOOL_HERO_START] else TOOL_INSPECT
	_sync_tool_buttons()
	_refresh_labels()

func _sync_tool_buttons() -> void:
	var buttons := {
		TOOL_INSPECT: _inspect_tool_button,
		TOOL_TERRAIN: _terrain_tool_button,
		TOOL_ROAD: _road_tool_button,
		TOOL_HERO_START: _hero_start_tool_button,
	}
	for tool_id in buttons.keys():
		var button: Button = buttons[tool_id]
		if button == null:
			continue
		button.button_pressed = tool_id == _tool

func _on_scenario_selected(index: int) -> void:
	if index < 0 or index >= _scenario_picker.get_item_count():
		return
	var scenario_id := String(_scenario_picker.get_item_metadata(index))
	_load_scenario_working_copy(scenario_id)

func _on_terrain_selected(index: int) -> void:
	if index < 0 or index >= _terrain_picker.get_item_count():
		return
	_selected_terrain_id = String(_terrain_picker.get_item_metadata(index))
	_select_tool(TOOL_TERRAIN)
	_last_message = "Terrain brush set to %s." % _selected_terrain_id
	_refresh_state()

func _on_map_tile_hovered(tile: Vector2i) -> void:
	_hovered_tile = tile

func _on_map_tile_pressed(tile: Vector2i) -> void:
	if _session == null or not _tile_in_bounds(tile):
		return
	_selected_tile = tile
	match _tool:
		TOOL_TERRAIN:
			_paint_terrain(tile, _selected_terrain_id)
		TOOL_ROAD:
			_toggle_road(tile)
		TOOL_HERO_START:
			_set_hero_start(tile)
		_:
			_last_message = "Inspected tile %d,%d." % [tile.x, tile.y]
	_refresh_state()

func _paint_terrain(tile: Vector2i, terrain_id: String) -> bool:
	if not _tile_in_bounds(tile) or terrain_id == "":
		return false
	var map_data = _session.overworld.get("map", [])
	if not (map_data is Array) or tile.y >= map_data.size():
		return false
	var row = map_data[tile.y]
	if not (row is Array) or tile.x >= row.size():
		return false
	var previous := String(row[tile.x])
	if previous == terrain_id:
		_last_message = "Tile %d,%d already uses %s." % [tile.x, tile.y, terrain_id]
		return true
	row[tile.x] = terrain_id
	map_data[tile.y] = row
	_session.overworld["map"] = map_data
	_dirty = true
	_last_message = "Painted %d,%d from %s to %s." % [tile.x, tile.y, previous, terrain_id]
	return true

func _toggle_road(tile: Vector2i) -> bool:
	if not _tile_in_bounds(tile):
		return false
	var terrain_layers := _terrain_layers()
	var roads = terrain_layers.get("roads", [])
	if not (roads is Array):
		roads = []
	var had_road := _has_road_at(tile)
	if had_road:
		for index in range(roads.size()):
			var road = roads[index]
			if not (road is Dictionary):
				continue
			var tiles = road.get("tiles", [])
			if not (tiles is Array):
				continue
			var updated_tiles := []
			for tile_value in tiles:
				if tile_value is Dictionary and int(tile_value.get("x", -1)) == tile.x and int(tile_value.get("y", -1)) == tile.y:
					continue
				updated_tiles.append(tile_value)
			road["tiles"] = updated_tiles
			roads[index] = road
	else:
		var editor_layer_index := _editor_road_layer_index(roads)
		if editor_layer_index < 0:
			roads.append(
				{
					"id": EDITOR_ROAD_LAYER_ID,
					"overlay_id": EDITOR_ROAD_OVERLAY_ID,
					"role": "editor_working_copy",
					"tiles": [],
				}
			)
			editor_layer_index = roads.size() - 1
		var editor_layer: Dictionary = roads[editor_layer_index]
		var tiles = editor_layer.get("tiles", [])
		if not (tiles is Array):
			tiles = []
		tiles.append({"x": tile.x, "y": tile.y})
		editor_layer["tiles"] = tiles
		roads[editor_layer_index] = editor_layer
	terrain_layers["roads"] = roads
	_session.overworld["terrain_layers"] = terrain_layers
	_dirty = true
	_last_message = "%s road at %d,%d." % ["Removed" if had_road else "Added", tile.x, tile.y]
	return true

func _editor_road_layer_index(roads: Array) -> int:
	for index in range(roads.size()):
		var road = roads[index]
		if road is Dictionary and String(road.get("id", "")) == EDITOR_ROAD_LAYER_ID:
			return index
	return -1

func _set_hero_start(tile: Vector2i) -> bool:
	if not _tile_in_bounds(tile):
		return false
	var position_payload := {"x": tile.x, "y": tile.y}
	_session.overworld["hero_position"] = position_payload.duplicate(true)
	var hero = _session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position_payload.duplicate(true)
		_session.overworld["hero"] = hero
	var heroes = _session.overworld.get("player_heroes", [])
	if heroes is Array:
		for index in range(heroes.size()):
			var hero_state = heroes[index]
			if not (hero_state is Dictionary):
				continue
			if String(hero_state.get("id", "")) == String(_session.overworld.get("active_hero_id", _session.hero_id)):
				hero_state["position"] = position_payload.duplicate(true)
				heroes[index] = hero_state
				break
		_session.overworld["player_heroes"] = heroes
	_dirty = true
	_last_message = "Moved the working-copy hero start to %d,%d." % [tile.x, tile.y]
	return true

func _on_play_working_copy_pressed() -> void:
	if _session == null:
		return
	_prepare_working_copy_for_play()
	SessionState.set_active_session(_session)
	AppRouter.go_to_overworld()

func _prepare_working_copy_for_play() -> void:
	_session.flags["editor_working_copy"] = true
	_session.flags["editor_source_scenario_id"] = _session.scenario_id
	_session.flags["editor_started_at"] = Time.get_datetime_string_from_system(true)
	_session.game_state = "overworld"
	_session.scenario_status = "in_progress"
	OverworldRules.refresh_fog_of_war(_session)

func _on_menu_pressed() -> void:
	AppRouter.go_to_main_menu()

func _tile_inspection_text(tile: Vector2i) -> String:
	if _session == null:
		return "No working copy is loaded."
	if not _tile_in_bounds(tile):
		return "Select a tile inside the map."
	var terrain_id := _terrain_at(tile)
	var biome := ContentService.get_biome_for_terrain(terrain_id)
	var lines := [
		"Tile %d,%d" % [tile.x, tile.y],
		"Terrain: %s | %s | passable %s" % [
			terrain_id,
			String(biome.get("name", "Unknown biome")),
			"yes" if bool(biome.get("passable", terrain_id != "water")) else "no",
		],
	]
	if _has_road_at(tile):
		lines.append("Road: %s" % ", ".join(_road_layer_ids_at(tile)))
	else:
		lines.append("Road: none")
	var object_lines := _object_lines_at(tile)
	if object_lines.is_empty():
		lines.append("Objects: none")
	else:
		lines.append("Objects:")
		lines.append_array(object_lines)
	return "\n".join(lines)

func _object_lines_at(tile: Vector2i) -> Array:
	var lines := []
	if OverworldRules.hero_position(_session) == tile:
		var hero = _session.overworld.get("hero", {})
		lines.append("Hero start: %s" % String(hero.get("name", _session.hero_id)))
	for town_value in _session.overworld.get("towns", []):
		if town_value is Dictionary and _placement_at_tile(town_value, tile):
			var town := ContentService.get_town(String(town_value.get("town_id", "")))
			lines.append("Town: %s | %s | %s" % [
				String(town.get("name", town_value.get("town_id", ""))),
				String(town_value.get("placement_id", "")),
				String(town_value.get("owner", "neutral")),
			])
	for node_value in _session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and _placement_at_tile(node_value, tile):
			var site := ContentService.get_resource_site(String(node_value.get("site_id", "")))
			lines.append("Site: %s | %s | collected %s" % [
				String(site.get("name", node_value.get("site_id", ""))),
				String(site.get("family", "one_shot_pickup")),
				"yes" if bool(node_value.get("collected", false)) else "no",
			])
	for artifact_value in _session.overworld.get("artifact_nodes", []):
		if artifact_value is Dictionary and _placement_at_tile(artifact_value, tile):
			var artifact := ContentService.get_artifact(String(artifact_value.get("artifact_id", "")))
			lines.append("Artifact: %s | %s" % [
				String(artifact.get("name", artifact_value.get("artifact_id", ""))),
				String(artifact_value.get("placement_id", "")),
			])
	for encounter_value in _session.overworld.get("encounters", []):
		if encounter_value is Dictionary and _placement_at_tile(encounter_value, tile):
			var encounter := ContentService.get_encounter(String(encounter_value.get("encounter_id", "")))
			lines.append("Encounter: %s | %s" % [
				String(encounter.get("name", encounter_value.get("encounter_id", ""))),
				String(encounter_value.get("placement_id", "")),
			])
	return lines

func _placement_at_tile(placement: Dictionary, tile: Vector2i) -> bool:
	return int(placement.get("x", -999)) == tile.x and int(placement.get("y", -999)) == tile.y

func _terrain_layers() -> Dictionary:
	var layers = _session.overworld.get("terrain_layers", {})
	if layers is Dictionary:
		return layers.duplicate(true)
	return {"id": _session.scenario_id, "terrain_layer_status": "editor_working_copy", "roads": []}

func _has_road_at(tile: Vector2i) -> bool:
	return not _road_layer_ids_at(tile).is_empty()

func _road_layer_ids_at(tile: Vector2i) -> Array:
	if _session == null:
		return []
	var ids := []
	var roads = _session.overworld.get("terrain_layers", {}).get("roads", [])
	if not (roads is Array):
		return ids
	for road in roads:
		if not (road is Dictionary):
			continue
		var tiles = road.get("tiles", [])
		if not (tiles is Array):
			continue
		for tile_value in tiles:
			if tile_value is Dictionary and int(tile_value.get("x", -1)) == tile.x and int(tile_value.get("y", -1)) == tile.y:
				ids.append(String(road.get("id", EDITOR_ROAD_LAYER_ID)))
				break
	return ids

func _road_tile_count() -> int:
	if _session == null:
		return 0
	var unique_tiles := {}
	var roads = _session.overworld.get("terrain_layers", {}).get("roads", [])
	if not (roads is Array):
		return 0
	for road in roads:
		if not (road is Dictionary):
			continue
		var tiles = road.get("tiles", [])
		if not (tiles is Array):
			continue
		for tile_value in tiles:
			if tile_value is Dictionary:
				unique_tiles["%d,%d" % [int(tile_value.get("x", -1)), int(tile_value.get("y", -1))]] = true
	return unique_tiles.size()

func _terrain_at(tile: Vector2i) -> String:
	if _session == null:
		return ""
	var map_data = _session.overworld.get("map", [])
	if not (map_data is Array) or tile.y < 0 or tile.y >= map_data.size():
		return ""
	var row = map_data[tile.y]
	if not (row is Array) or tile.x < 0 or tile.x >= row.size():
		return ""
	return String(row[tile.x])

func _tile_in_bounds(tile: Vector2i) -> bool:
	if _session == null:
		return false
	var map_size := OverworldRules.derive_map_size(_session)
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y

func _set_compact_label(label: Label, text: String, max_lines: int) -> void:
	label.text = text
	label.tooltip_text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.max_lines_visible = max_lines

func _apply_visual_theme() -> void:
	var panel_style := _panel_style(Color(0.08, 0.10, 0.11, 0.94), Color(0.50, 0.44, 0.30, 0.72), 1)
	for panel in get_tree().get_nodes_in_group("map_editor_panel"):
		if panel is PanelContainer:
			panel.add_theme_stylebox_override("panel", panel_style.duplicate())
	var button_style := _panel_style(Color(0.16, 0.14, 0.10, 0.86), Color(0.62, 0.52, 0.30, 0.72), 1)
	var button_hover := _panel_style(Color(0.24, 0.20, 0.13, 0.92), Color(0.82, 0.66, 0.34, 0.90), 1)
	for button in [_inspect_tool_button, _terrain_tool_button, _road_tool_button, _hero_start_tool_button, _play_button, _menu_button]:
		if button == null:
			continue
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", button_style.duplicate())
		button.add_theme_stylebox_override("pressed", button_hover.duplicate())
		button.add_theme_stylebox_override("hover", button_hover.duplicate())

func _panel_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style

func validation_snapshot() -> Dictionary:
	var map_size := OverworldRules.derive_map_size(_session) if _session != null else Vector2i.ZERO
	return {
		"scene_path": scene_file_path,
		"scenario_id": _session.scenario_id if _session != null else "",
		"working_copy": _session != null,
		"dirty": _dirty,
		"tool": _tool,
		"selected_terrain_id": _selected_terrain_id,
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"hovered_tile": {"x": _hovered_tile.x, "y": _hovered_tile.y},
		"map_size": {"x": map_size.x, "y": map_size.y},
		"road_tile_count": _road_tile_count(),
		"tile_inspection": _tile_inspection_payload(_selected_tile),
		"map_viewport": _map_view.call("validation_view_metrics") if _map_view != null and _map_view.has_method("validation_view_metrics") else {},
	}

func validation_load_scenario(scenario_id: String) -> Dictionary:
	var loaded := _load_scenario_working_copy(scenario_id)
	var snapshot := validation_snapshot()
	snapshot["ok"] = loaded
	return snapshot

func validation_select_tile(x: int, y: int) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	_selected_tile = tile
	_tool = TOOL_INSPECT
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	return snapshot

func validation_set_tool(tool: String) -> Dictionary:
	_select_tool(tool)
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	return snapshot

func validation_select_terrain(terrain_id: String) -> Dictionary:
	for index in range(_terrain_picker.get_item_count()):
		if String(_terrain_picker.get_item_metadata(index)) == terrain_id:
			_terrain_picker.select(index)
			_selected_terrain_id = terrain_id
			_select_tool(TOOL_TERRAIN)
			var snapshot := validation_snapshot()
			snapshot["ok"] = true
			return snapshot
	return {"ok": false, "message": "Terrain id is not in the authored terrain grammar."}

func validation_paint_terrain(x: int, y: int, terrain_id: String) -> Dictionary:
	_selected_tile = Vector2i(x, y)
	_selected_terrain_id = terrain_id
	_tool = TOOL_TERRAIN
	var changed := _paint_terrain(_selected_tile, terrain_id)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	return snapshot

func validation_toggle_road(x: int, y: int) -> Dictionary:
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_ROAD
	var changed := _toggle_road(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	return snapshot

func validation_set_hero_start(x: int, y: int) -> Dictionary:
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_HERO_START
	var changed := _set_hero_start(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	snapshot["hero_position"] = {"x": OverworldRules.hero_position(_session).x, "y": OverworldRules.hero_position(_session).y}
	return snapshot

func validation_tile_presentation(x: int, y: int) -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_tile_presentation"):
		return {}
	return _map_view.call("validation_tile_presentation", Vector2i(x, y))

func validation_launch_working_copy() -> Dictionary:
	if _session == null:
		return {"ok": false, "message": "No editor working copy is loaded."}
	var scenario_id := String(_session.scenario_id)
	_on_play_working_copy_pressed()
	return {
		"ok": SessionState.ensure_active_session().scenario_id == scenario_id,
		"scenario_id": scenario_id,
		"active_scenario_id": SessionState.ensure_active_session().scenario_id,
		"editor_working_copy": bool(SessionState.ensure_active_session().flags.get("editor_working_copy", false)),
	}

func _tile_inspection_payload(tile: Vector2i) -> Dictionary:
	if _session == null or not _tile_in_bounds(tile):
		return {}
	var object_lines := _object_lines_at(tile)
	return {
		"x": tile.x,
		"y": tile.y,
		"terrain_id": _terrain_at(tile),
		"road": _has_road_at(tile),
		"road_layers": _road_layer_ids_at(tile),
		"object_count": object_lines.size(),
		"objects": object_lines,
		"text": _tile_inspection_text(tile),
	}
