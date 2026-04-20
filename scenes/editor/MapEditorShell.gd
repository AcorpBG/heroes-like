class_name MapEditorShell
extends Control

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")

const DEFAULT_SCENARIO_ID := "ninefold-confluence"
const DEFAULT_TERRAIN_ID := "grass"
const EDITOR_ROAD_LAYER_ID := "editor_working_road"
const EDITOR_ROAD_OVERLAY_ID := "road_dirt"
const TOOL_INSPECT := "inspect"
const TOOL_TERRAIN := "terrain"
const TOOL_ROAD := "road"
const TOOL_HERO_START := "hero_start"
const TOOL_PLACE_OBJECT := "place_object"
const TOOL_REMOVE_OBJECT := "remove_object"
const OBJECT_FAMILY_TOWN := "town"
const OBJECT_FAMILY_RESOURCE := "resource"
const OBJECT_FAMILY_ARTIFACT := "artifact"
const OBJECT_FAMILY_ENCOUNTER := "encounter"
const DEFAULT_OBJECT_FAMILY := OBJECT_FAMILY_RESOURCE

@onready var _header_label: Label = %Header
@onready var _scenario_picker: OptionButton = %ScenarioPicker
@onready var _terrain_picker: OptionButton = %TerrainPicker
@onready var _inspect_tool_button: Button = %InspectTool
@onready var _terrain_tool_button: Button = %TerrainTool
@onready var _road_tool_button: Button = %RoadTool
@onready var _hero_start_tool_button: Button = %HeroStartTool
@onready var _place_object_tool_button: Button = %PlaceObjectTool
@onready var _remove_object_tool_button: Button = %RemoveObjectTool
@onready var _tile_info_label: Label = %TileInfo
@onready var _status_label: Label = %Status
@onready var _map_view = %Map
@onready var _play_button: Button = %PlayWorkingCopy
@onready var _menu_button: Button = %Menu
@onready var _object_family_picker: OptionButton = %ObjectFamilyPicker
@onready var _object_content_picker: OptionButton = %ObjectContentPicker

var _session = null
var _scenario_entries: Array = []
var _terrain_entries: Array = []
var _object_family_entries: Array = []
var _object_content_entries: Array = []
var _selected_scenario_id := ""
var _selected_terrain_id := DEFAULT_TERRAIN_ID
var _selected_object_family := DEFAULT_OBJECT_FAMILY
var _selected_object_content_id := ""
var _selected_tile := Vector2i.ZERO
var _hovered_tile := Vector2i(-1, -1)
var _tool := TOOL_INSPECT
var _dirty := false
var _last_message := ""

func _ready() -> void:
	_apply_visual_theme()
	_connect_ui()
	_rebuild_terrain_picker()
	_rebuild_object_family_picker()
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
	_place_object_tool_button.pressed.connect(func(): _select_tool(TOOL_PLACE_OBJECT))
	_remove_object_tool_button.pressed.connect(func(): _select_tool(TOOL_REMOVE_OBJECT))
	_object_family_picker.item_selected.connect(_on_object_family_selected)
	_object_content_picker.item_selected.connect(_on_object_content_selected)
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

func _rebuild_object_family_picker() -> void:
	_object_family_entries = [
		{"id": OBJECT_FAMILY_TOWN, "label": "Towns"},
		{"id": OBJECT_FAMILY_RESOURCE, "label": "Resource Sites"},
		{"id": OBJECT_FAMILY_ARTIFACT, "label": "Artifacts"},
		{"id": OBJECT_FAMILY_ENCOUNTER, "label": "Encounters"},
	]
	_object_family_picker.clear()
	var selected_index := -1
	for index in range(_object_family_entries.size()):
		var entry: Dictionary = _object_family_entries[index]
		var family_id := String(entry.get("id", ""))
		_object_family_picker.add_item(String(entry.get("label", family_id.capitalize())), index)
		_object_family_picker.set_item_metadata(index, family_id)
		if family_id == _selected_object_family:
			selected_index = index
	if selected_index < 0:
		selected_index = 0
	if selected_index >= 0:
		_object_family_picker.select(selected_index)
		_selected_object_family = String(_object_family_picker.get_item_metadata(selected_index))
	_rebuild_object_content_picker()

func _rebuild_object_content_picker() -> void:
	_object_content_entries = _object_content_items(_selected_object_family)
	_object_content_picker.clear()
	var selected_index := -1
	for index in range(_object_content_entries.size()):
		var entry: Dictionary = _object_content_entries[index]
		var content_id := String(entry.get("id", ""))
		_object_content_picker.add_item(_object_content_label(entry), index)
		_object_content_picker.set_item_metadata(index, content_id)
		if content_id == _selected_object_content_id:
			selected_index = index
	if selected_index < 0 and not _object_content_entries.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_object_content_picker.select(selected_index)
		_selected_object_content_id = String(_object_content_picker.get_item_metadata(selected_index))
	else:
		_selected_object_content_id = ""

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

func _object_content_items(family: String) -> Array:
	var path := _object_content_path(family)
	if path == "":
		return []
	var raw := ContentService.load_json(path)
	var raw_items = raw.get("items", [])
	var items := []
	if not (raw_items is Array):
		return items
	for item in raw_items:
		if not (item is Dictionary):
			continue
		var content_id := String(item.get("id", ""))
		if content_id == "":
			continue
		items.append(
			{
				"id": content_id,
				"name": String(item.get("name", item.get("label", content_id))),
				"family": String(item.get("family", "")),
			}
		)
	return items

func _object_content_path(family: String) -> String:
	match family:
		OBJECT_FAMILY_TOWN:
			return "res://content/towns.json"
		OBJECT_FAMILY_RESOURCE:
			return "res://content/resource_sites.json"
		OBJECT_FAMILY_ARTIFACT:
			return "res://content/artifacts.json"
		OBJECT_FAMILY_ENCOUNTER:
			return "res://content/encounters.json"
		_:
			return ""

func _object_content_label(entry: Dictionary) -> String:
	var content_id := String(entry.get("id", ""))
	var label := String(entry.get("name", content_id))
	var family := String(entry.get("family", ""))
	if family != "":
		return "%s | %s" % [label, family]
	return label

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
	state_line = "%s | Objects %d | Palette %s:%s" % [
		state_line,
		_placement_count(),
		_object_family_label(_selected_object_family),
		_selected_object_content_id,
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
		TOOL_PLACE_OBJECT:
			return "Place Object"
		TOOL_REMOVE_OBJECT:
			return "Remove Object"
		_:
			return "Inspect"

func _select_tool(tool: String) -> void:
	_tool = tool if tool in [TOOL_INSPECT, TOOL_TERRAIN, TOOL_ROAD, TOOL_HERO_START, TOOL_PLACE_OBJECT, TOOL_REMOVE_OBJECT] else TOOL_INSPECT
	_sync_tool_buttons()
	_refresh_labels()

func _sync_tool_buttons() -> void:
	var buttons := {
		TOOL_INSPECT: _inspect_tool_button,
		TOOL_TERRAIN: _terrain_tool_button,
		TOOL_ROAD: _road_tool_button,
		TOOL_HERO_START: _hero_start_tool_button,
		TOOL_PLACE_OBJECT: _place_object_tool_button,
		TOOL_REMOVE_OBJECT: _remove_object_tool_button,
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

func _on_object_family_selected(index: int) -> void:
	if index < 0 or index >= _object_family_picker.get_item_count():
		return
	_selected_object_family = String(_object_family_picker.get_item_metadata(index))
	_selected_object_content_id = ""
	_rebuild_object_content_picker()
	_select_tool(TOOL_PLACE_OBJECT)
	_last_message = "Object family set to %s." % _object_family_label(_selected_object_family)
	_refresh_state()

func _on_object_content_selected(index: int) -> void:
	if index < 0 or index >= _object_content_picker.get_item_count():
		return
	_selected_object_content_id = String(_object_content_picker.get_item_metadata(index))
	_select_tool(TOOL_PLACE_OBJECT)
	_last_message = "Object palette set to %s." % _selected_object_content_id
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
		TOOL_PLACE_OBJECT:
			_place_object(tile)
		TOOL_REMOVE_OBJECT:
			_remove_object(tile)
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

func _place_object(tile: Vector2i) -> bool:
	if not _tile_in_bounds(tile):
		return false
	if _selected_object_family == "" or _selected_object_content_id == "":
		_last_message = "Choose an object family and authored content id before placing."
		return false
	if _object_content_lookup(_selected_object_family, _selected_object_content_id).is_empty():
		_last_message = "Unknown %s content id %s." % [_object_family_label(_selected_object_family), _selected_object_content_id]
		return false
	if _selected_object_family == OBJECT_FAMILY_ARTIFACT and _artifact_content_id_exists(_selected_object_content_id):
		_last_message = "Artifact %s is already placed in this working copy; remove it before placing it elsewhere." % _selected_object_content_id
		return false
	var existing_objects := _object_details_at(tile, false)
	if not existing_objects.is_empty():
		_last_message = "Tile %d,%d already has %s. Remove it before placing another object." % [
			tile.x,
			tile.y,
			String(existing_objects[0].get("placement_id", existing_objects[0].get("kind", "object"))),
		]
		return false

	var placement_id := _generate_editor_placement_id(_selected_object_family, _selected_object_content_id, tile)
	var built_placement := _build_runtime_placement(_selected_object_family, _selected_object_content_id, placement_id, tile)
	if built_placement.is_empty():
		_last_message = "Could not build %s placement for %s." % [_object_family_label(_selected_object_family), _selected_object_content_id]
		return false

	var array_key := _placement_array_key(_selected_object_family)
	var placements = _session.overworld.get(array_key, [])
	if not (placements is Array):
		placements = []
	placements.append(built_placement)
	_session.overworld[array_key] = placements
	_dirty = true
	_last_message = "Placed %s %s at %d,%d as %s." % [
		_object_family_label(_selected_object_family),
		_selected_object_content_id,
		tile.x,
		tile.y,
		placement_id,
	]
	return true

func _remove_object(tile: Vector2i) -> bool:
	if not _tile_in_bounds(tile):
		return false
	var array_key := _placement_array_key(_selected_object_family)
	if array_key == "":
		return false
	var placements = _session.overworld.get(array_key, [])
	if not (placements is Array):
		_last_message = "No %s placements exist in this working copy." % _object_family_label(_selected_object_family)
		return false
	var updated := []
	var removed_ids := []
	for placement in placements:
		if placement is Dictionary and _placement_at_tile(placement, tile):
			removed_ids.append(String(placement.get("placement_id", "")))
			continue
		updated.append(placement)
	if removed_ids.is_empty():
		_last_message = "No %s placement at %d,%d." % [_object_family_label(_selected_object_family), tile.x, tile.y]
		return false
	_session.overworld[array_key] = updated
	if _selected_object_family == OBJECT_FAMILY_ENCOUNTER:
		_remove_resolved_encounter_ids(removed_ids)
	_dirty = true
	_last_message = "Removed %d %s placement%s at %d,%d: %s." % [
		removed_ids.size(),
		_object_family_label(_selected_object_family),
		"" if removed_ids.size() == 1 else "s",
		tile.x,
		tile.y,
		", ".join(removed_ids),
	]
	return true

func _build_runtime_placement(family: String, content_id: String, placement_id: String, tile: Vector2i) -> Dictionary:
	match family:
		OBJECT_FAMILY_TOWN:
			var town_placements: Array = ScenarioFactoryScript._build_town_states(
				[
					{
						"placement_id": placement_id,
						"town_id": content_id,
						"x": tile.x,
						"y": tile.y,
						"owner": "neutral",
					}
				]
			)
			return town_placements[0] if not town_placements.is_empty() else {}
		OBJECT_FAMILY_RESOURCE:
			var resource_placements: Array = ScenarioFactoryScript._build_resource_states(
				[
					{
						"placement_id": placement_id,
						"site_id": content_id,
						"x": tile.x,
						"y": tile.y,
					}
				]
			)
			return resource_placements[0] if not resource_placements.is_empty() else {}
		OBJECT_FAMILY_ARTIFACT:
			var artifact_placements: Array = ArtifactRulesScript.build_artifact_nodes(
				[
					{
						"placement_id": placement_id,
						"artifact_id": content_id,
						"x": tile.x,
						"y": tile.y,
					}
				]
			)
			return artifact_placements[0] if not artifact_placements.is_empty() else {}
		OBJECT_FAMILY_ENCOUNTER:
			return {
				"placement_id": placement_id,
				"encounter_id": content_id,
				"x": tile.x,
				"y": tile.y,
				"difficulty": "medium",
				"combat_seed": hash("%s:%s:%d:%d" % [_session.scenario_id, placement_id, tile.x, tile.y]),
			}
		_:
			return {}

func _remove_resolved_encounter_ids(placement_ids: Array) -> void:
	var resolved = _session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		return
	var updated := []
	for value in resolved:
		if String(value) in placement_ids:
			continue
		updated.append(value)
	_session.overworld["resolved_encounters"] = updated

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
	for detail in _object_details_at(tile, true):
		if not (detail is Dictionary):
			continue
		match String(detail.get("kind", "")):
			"hero_start":
				lines.append("Hero start: %s | id %s" % [
					String(detail.get("name", "")),
					String(detail.get("content_id", "")),
				])
			OBJECT_FAMILY_TOWN:
				lines.append("Town: %s | placement %s | content %s | owner %s" % [
					String(detail.get("name", "")),
					String(detail.get("placement_id", "")),
					String(detail.get("content_id", "")),
					String(detail.get("owner", "neutral")),
				])
			OBJECT_FAMILY_RESOURCE:
				lines.append("Site: %s | placement %s | content %s | family %s | collected %s" % [
					String(detail.get("name", "")),
					String(detail.get("placement_id", "")),
					String(detail.get("content_id", "")),
					String(detail.get("family", "")),
					"yes" if bool(detail.get("collected", false)) else "no",
				])
			OBJECT_FAMILY_ARTIFACT:
				lines.append("Artifact: %s | placement %s | content %s | collected %s" % [
					String(detail.get("name", "")),
					String(detail.get("placement_id", "")),
					String(detail.get("content_id", "")),
					"yes" if bool(detail.get("collected", false)) else "no",
				])
			OBJECT_FAMILY_ENCOUNTER:
				lines.append("Encounter: %s | placement %s | content %s | difficulty %s" % [
					String(detail.get("name", "")),
					String(detail.get("placement_id", "")),
					String(detail.get("content_id", "")),
					String(detail.get("difficulty", "medium")),
				])
	return lines

func _object_details_at(tile: Vector2i, include_hero: bool = true) -> Array:
	var details := []
	if OverworldRules.hero_position(_session) == tile:
		var hero = _session.overworld.get("hero", {})
		if include_hero:
			details.append(
				{
					"kind": "hero_start",
					"content_id": String(hero.get("id", _session.hero_id)),
					"name": String(hero.get("name", _session.hero_id)),
					"x": tile.x,
					"y": tile.y,
				}
			)
	for town_value in _session.overworld.get("towns", []):
		if town_value is Dictionary and _placement_at_tile(town_value, tile):
			var town := ContentService.get_town(String(town_value.get("town_id", "")))
			details.append(
				{
					"kind": OBJECT_FAMILY_TOWN,
					"placement_id": String(town_value.get("placement_id", "")),
					"content_id": String(town_value.get("town_id", "")),
					"name": String(town.get("name", town_value.get("town_id", ""))),
					"owner": String(town_value.get("owner", "neutral")),
					"x": int(town_value.get("x", 0)),
					"y": int(town_value.get("y", 0)),
				}
			)
	for node_value in _session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and _placement_at_tile(node_value, tile):
			var site := ContentService.get_resource_site(String(node_value.get("site_id", "")))
			details.append(
				{
					"kind": OBJECT_FAMILY_RESOURCE,
					"placement_id": String(node_value.get("placement_id", "")),
					"content_id": String(node_value.get("site_id", "")),
					"name": String(site.get("name", node_value.get("site_id", ""))),
					"family": String(site.get("family", "one_shot_pickup")),
					"collected": bool(node_value.get("collected", false)),
					"x": int(node_value.get("x", 0)),
					"y": int(node_value.get("y", 0)),
				}
			)
	for artifact_value in _session.overworld.get("artifact_nodes", []):
		if artifact_value is Dictionary and _placement_at_tile(artifact_value, tile):
			var artifact := ContentService.get_artifact(String(artifact_value.get("artifact_id", "")))
			details.append(
				{
					"kind": OBJECT_FAMILY_ARTIFACT,
					"placement_id": String(artifact_value.get("placement_id", "")),
					"content_id": String(artifact_value.get("artifact_id", "")),
					"name": String(artifact.get("name", artifact_value.get("artifact_id", ""))),
					"collected": bool(artifact_value.get("collected", false)),
					"x": int(artifact_value.get("x", 0)),
					"y": int(artifact_value.get("y", 0)),
				}
			)
	for encounter_value in _session.overworld.get("encounters", []):
		if encounter_value is Dictionary and _placement_at_tile(encounter_value, tile):
			var encounter := ContentService.get_encounter(String(encounter_value.get("encounter_id", "")))
			details.append(
				{
					"kind": OBJECT_FAMILY_ENCOUNTER,
					"placement_id": String(encounter_value.get("placement_id", "")),
					"content_id": String(encounter_value.get("encounter_id", "")),
					"name": String(encounter.get("name", encounter_value.get("encounter_id", ""))),
					"difficulty": String(encounter_value.get("difficulty", "medium")),
					"combat_seed": int(encounter_value.get("combat_seed", 0)),
					"x": int(encounter_value.get("x", 0)),
					"y": int(encounter_value.get("y", 0)),
				}
			)
	return details

func _placement_at_tile(placement: Dictionary, tile: Vector2i) -> bool:
	return int(placement.get("x", -999)) == tile.x and int(placement.get("y", -999)) == tile.y

func _placement_array_key(family: String) -> String:
	match family:
		OBJECT_FAMILY_TOWN:
			return "towns"
		OBJECT_FAMILY_RESOURCE:
			return "resource_nodes"
		OBJECT_FAMILY_ARTIFACT:
			return "artifact_nodes"
		OBJECT_FAMILY_ENCOUNTER:
			return "encounters"
		_:
			return ""

func _object_family_label(family: String) -> String:
	match family:
		OBJECT_FAMILY_TOWN:
			return "Town"
		OBJECT_FAMILY_RESOURCE:
			return "Resource"
		OBJECT_FAMILY_ARTIFACT:
			return "Artifact"
		OBJECT_FAMILY_ENCOUNTER:
			return "Encounter"
		_:
			return "Object"

func _object_content_lookup(family: String, content_id: String) -> Dictionary:
	match family:
		OBJECT_FAMILY_TOWN:
			return ContentService.get_town(content_id)
		OBJECT_FAMILY_RESOURCE:
			return ContentService.get_resource_site(content_id)
		OBJECT_FAMILY_ARTIFACT:
			return ContentService.get_artifact(content_id)
		OBJECT_FAMILY_ENCOUNTER:
			return ContentService.get_encounter(content_id)
		_:
			return {}

func _generate_editor_placement_id(family: String, content_id: String, tile: Vector2i) -> String:
	var base_id := "editor_%s_%s_%d_%d" % [
		_safe_id_segment(family),
		_safe_id_segment(content_id),
		tile.x,
		tile.y,
	]
	var candidate := base_id
	var suffix := 2
	while _placement_id_exists(candidate):
		candidate = "%s_%d" % [base_id, suffix]
		suffix += 1
	return candidate

func _safe_id_segment(value: String) -> String:
	var normalized := ""
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_"
	for index in range(value.length()):
		var character := value.substr(index, 1).to_lower()
		if character == "-":
			character = "_"
		if allowed.find(character) >= 0:
			normalized += character
		else:
			normalized += "_"
	while normalized.find("__") >= 0:
		normalized = normalized.replace("__", "_")
	if normalized == "" or normalized == "_":
		return "object"
	return normalized

func _placement_id_exists(placement_id: String) -> bool:
	if _session == null or placement_id == "":
		return false
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var array_key := _placement_array_key(family)
		var placements = _session.overworld.get(array_key, [])
		if not (placements is Array):
			continue
		for placement in placements:
			if placement is Dictionary and String(placement.get("placement_id", "")) == placement_id:
				return true
	return false

func _artifact_content_id_exists(artifact_id: String) -> bool:
	if _session == null or artifact_id == "":
		return false
	var artifact_nodes = _session.overworld.get("artifact_nodes", [])
	if not (artifact_nodes is Array):
		return false
	for node in artifact_nodes:
		if node is Dictionary and String(node.get("artifact_id", "")) == artifact_id:
			return true
	return false

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

func _placement_count() -> int:
	if _session == null:
		return 0
	var total := 0
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var placements = _session.overworld.get(_placement_array_key(family), [])
		if placements is Array:
			total += placements.size()
	return total

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
	for button in [_inspect_tool_button, _terrain_tool_button, _road_tool_button, _hero_start_tool_button, _place_object_tool_button, _remove_object_tool_button, _play_button, _menu_button]:
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
		"selected_object_family": _selected_object_family,
		"selected_object_content_id": _selected_object_content_id,
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"hovered_tile": {"x": _hovered_tile.x, "y": _hovered_tile.y},
		"map_size": {"x": map_size.x, "y": map_size.y},
		"road_tile_count": _road_tile_count(),
		"placement_count": _placement_count(),
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

func validation_select_object_family(family: String) -> Dictionary:
	var selected := _select_object_family_by_id(family)
	var snapshot := validation_snapshot()
	snapshot["ok"] = selected
	return snapshot

func validation_select_object_content(content_id: String) -> Dictionary:
	var selected := _select_object_content_by_id(content_id)
	var snapshot := validation_snapshot()
	snapshot["ok"] = selected
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

func validation_place_object(x: int, y: int, family: String, content_id: String) -> Dictionary:
	var family_selected := true
	var content_selected := true
	if family != "":
		family_selected = _select_object_family_by_id(family)
	if content_id != "":
		content_selected = _select_object_content_by_id(content_id)
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_PLACE_OBJECT
	var changed := family_selected and content_selected and _place_object(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	snapshot["family_selected"] = family_selected
	snapshot["content_selected"] = content_selected
	return snapshot

func validation_remove_object(x: int, y: int, family: String) -> Dictionary:
	var family_selected := true
	if family != "":
		family_selected = _select_object_family_by_id(family)
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_REMOVE_OBJECT
	var changed := family_selected and _remove_object(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	snapshot["family_selected"] = family_selected
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
		"object_details": _object_details_at(tile, true),
		"text": _tile_inspection_text(tile),
	}

func _select_object_family_by_id(family: String) -> bool:
	for index in range(_object_family_picker.get_item_count()):
		if String(_object_family_picker.get_item_metadata(index)) == family:
			_object_family_picker.select(index)
			_selected_object_family = family
			_selected_object_content_id = ""
			_rebuild_object_content_picker()
			return true
	return false

func _select_object_content_by_id(content_id: String) -> bool:
	for index in range(_object_content_picker.get_item_count()):
		if String(_object_content_picker.get_item_metadata(index)) == content_id:
			_object_content_picker.select(index)
			_selected_object_content_id = content_id
			return true
	return false
