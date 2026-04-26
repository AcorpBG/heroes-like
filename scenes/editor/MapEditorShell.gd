class_name MapEditorShell
extends Control

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const TerrainPlacementRulesScript = preload("res://scripts/core/TerrainPlacementRules.gd")

const DEFAULT_SCENARIO_ID := "ninefold-confluence"
const DEFAULT_TERRAIN_ID := "grass"
const EDITOR_ROAD_LAYER_ID := "editor_working_road"
const EDITOR_ROAD_OVERLAY_ID := "road_dirt"
const TERRAIN_LINE_RULE_ID := "manhattan_l_horizontal_then_vertical"
const TERRAIN_LINE_RULE_LABEL := "Manhattan L line, horizontal first, then vertical"
const TERRAIN_RECTANGLE_RULE_ID := "inclusive_axis_aligned_corners"
const TERRAIN_RECTANGLE_RULE_LABEL := "Inclusive axis-aligned rectangle between corner tiles"
const TERRAIN_RECTANGLE_TILE_ORDER := "row_major_top_left_to_bottom_right"
const TERRAIN_OPTION_CONTRACT := "homm3_base_family_picker"
const TERRAIN_OPTION_SOURCE := "editor_base_terrain_options"
const TERRAIN_PLACEMENT_MODEL := "homm3_owner_queue_rewrite_final_normalization.v1"
const ROAD_PATH_RULE_ID := "manhattan_l_horizontal_then_vertical"
const ROAD_PATH_RULE_LABEL := "Manhattan L path, horizontal first, then vertical"
const TOOL_INSPECT := "inspect"
const TOOL_TERRAIN := "terrain"
const TOOL_TERRAIN_LINE := "terrain_line"
const TOOL_TERRAIN_RECTANGLE := "terrain_rectangle"
const TOOL_ROAD := "road"
const TOOL_ROAD_PATH := "road_path"
const TOOL_HERO_START := "hero_start"
const TOOL_PLACE_OBJECT := "place_object"
const TOOL_REMOVE_OBJECT := "remove_object"
const TOOL_MOVE_OBJECT := "move_object"
const TOOL_DUPLICATE_OBJECT := "duplicate_object"
const TOOL_RETHEME_OBJECT := "retheme_object"
const OBJECT_FAMILY_TOWN := "town"
const OBJECT_FAMILY_RESOURCE := "resource"
const OBJECT_FAMILY_ARTIFACT := "artifact"
const OBJECT_FAMILY_ENCOUNTER := "encounter"
const DEFAULT_OBJECT_FAMILY := OBJECT_FAMILY_RESOURCE
const EDITOR_DENSITY_REGION_SIZE := 16
const PROPERTY_TOWN_OWNER := "owner"
const PROPERTY_ENCOUNTER_DIFFICULTY := "difficulty"
const PROPERTY_COLLECTED := "collected"
const TOWN_OWNER_OPTIONS := ["neutral", "player", "enemy"]
const ENCOUNTER_DIFFICULTY_OPTIONS := ["low", "medium", "high", "pressure", "scripted"]

@onready var _header_label: Label = %Header
@onready var _scenario_picker: OptionButton = %ScenarioPicker
@onready var _terrain_picker: OptionButton = %TerrainPicker
@onready var _inspect_tool_button: Button = %InspectTool
@onready var _terrain_tool_button: Button = %TerrainTool
@onready var _terrain_line_tool_button: Button = %TerrainLineTool
@onready var _terrain_rectangle_tool_button: Button = %TerrainRectangleTool
@onready var _road_tool_button: Button = %RoadTool
@onready var _road_path_tool_button: Button = %RoadPathTool
@onready var _hero_start_tool_button: Button = %HeroStartTool
@onready var _place_object_tool_button: Button = %PlaceObjectTool
@onready var _remove_object_tool_button: Button = %RemoveObjectTool
@onready var _move_object_tool_button: Button = %MoveObjectTool
@onready var _duplicate_object_tool_button: Button = %DuplicateObjectTool
@onready var _retheme_object_tool_button: Button = %RethemeObjectTool
@onready var _fill_terrain_button: Button = %FillTerrain
@onready var _restore_tile_button: Button = %RestoreSelectedTile
@onready var _tile_info_label: Label = %TileInfo
@onready var _status_label: Label = %Status
@onready var _map_view = %Map
@onready var _play_button: Button = %PlayWorkingCopy
@onready var _menu_button: Button = %Menu
@onready var _object_family_picker: OptionButton = %ObjectFamilyPicker
@onready var _object_content_picker: OptionButton = %ObjectContentPicker
@onready var _object_taxonomy_summary_label: Label = %ObjectTaxonomySummary
@onready var _selected_object_picker: OptionButton = %SelectedObjectPicker
@onready var _property_summary_label: Label = %PropertySummary
@onready var _property_owner_picker: OptionButton = %PropertyOwnerPicker
@onready var _property_difficulty_picker: OptionButton = %PropertyDifficultyPicker
@onready var _property_collected_check: CheckBox = %PropertyCollectedFlag
@onready var _property_apply_button: Button = %ApplyObjectProperties

var _session = null
var _scenario_entries: Array = []
var _terrain_entries: Array = []
var _object_family_entries: Array = []
var _object_content_entries: Array = []
var _selected_scenario_id := ""
var _selected_terrain_id := DEFAULT_TERRAIN_ID
var _selected_object_family := DEFAULT_OBJECT_FAMILY
var _selected_object_content_id := ""
var _selected_property_object_key := ""
var _pending_move_object_key := ""
var _pending_duplicate_object_key := ""
var _pending_terrain_line_start := Vector2i(-1, -1)
var _pending_terrain_rectangle_corner := Vector2i(-1, -1)
var _pending_road_path_start := Vector2i(-1, -1)
var _selected_tile := Vector2i.ZERO
var _hovered_tile := Vector2i(-1, -1)
var _tool := TOOL_INSPECT
var _dirty := false
var _last_message := ""
var _last_object_authoring_recap := {}
var _restored_from_play_copy := false
var _terrain_paint_order := 0
var _last_terrain_placement_result := {}

func _ready() -> void:
	_apply_visual_theme()
	_connect_ui()
	_rebuild_terrain_picker()
	_rebuild_object_family_picker()
	_rebuild_property_option_pickers()
	_rebuild_scenario_picker()
	_select_tool(TOOL_INSPECT)
	var returned_session = SessionState.consume_editor_return_session()
	if returned_session != null and _resume_working_copy_from_memory(returned_session):
		return
	if _selected_scenario_id != "":
		_load_scenario_working_copy(_selected_scenario_id)

func _connect_ui() -> void:
	_scenario_picker.item_selected.connect(_on_scenario_selected)
	_terrain_picker.item_selected.connect(_on_terrain_selected)
	_inspect_tool_button.pressed.connect(func(): _select_tool(TOOL_INSPECT))
	_terrain_tool_button.pressed.connect(func(): _select_tool(TOOL_TERRAIN))
	_terrain_line_tool_button.pressed.connect(func(): _select_tool(TOOL_TERRAIN_LINE))
	_terrain_rectangle_tool_button.pressed.connect(func(): _select_tool(TOOL_TERRAIN_RECTANGLE))
	_road_tool_button.pressed.connect(func(): _select_tool(TOOL_ROAD))
	_road_path_tool_button.pressed.connect(func(): _select_tool(TOOL_ROAD_PATH))
	_hero_start_tool_button.pressed.connect(func(): _select_tool(TOOL_HERO_START))
	_place_object_tool_button.pressed.connect(func(): _select_tool(TOOL_PLACE_OBJECT))
	_remove_object_tool_button.pressed.connect(func(): _select_tool(TOOL_REMOVE_OBJECT))
	_move_object_tool_button.pressed.connect(func(): _select_tool(TOOL_MOVE_OBJECT))
	_duplicate_object_tool_button.pressed.connect(func(): _select_tool(TOOL_DUPLICATE_OBJECT))
	_retheme_object_tool_button.pressed.connect(func(): _select_tool(TOOL_RETHEME_OBJECT))
	_fill_terrain_button.pressed.connect(_on_fill_terrain_pressed)
	_restore_tile_button.pressed.connect(_on_restore_selected_tile_pressed)
	_object_family_picker.item_selected.connect(_on_object_family_selected)
	_object_content_picker.item_selected.connect(_on_object_content_selected)
	_selected_object_picker.item_selected.connect(_on_selected_property_object_selected)
	_property_apply_button.pressed.connect(_on_apply_object_properties_pressed)
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

func _rebuild_property_option_pickers() -> void:
	_property_owner_picker.clear()
	for index in range(TOWN_OWNER_OPTIONS.size()):
		var owner_id := String(TOWN_OWNER_OPTIONS[index])
		_property_owner_picker.add_item(owner_id.capitalize(), index)
		_property_owner_picker.set_item_metadata(index, owner_id)
	_property_difficulty_picker.clear()
	for index in range(ENCOUNTER_DIFFICULTY_OPTIONS.size()):
		var difficulty_id := String(ENCOUNTER_DIFFICULTY_OPTIONS[index])
		_property_difficulty_picker.add_item(difficulty_id.capitalize(), index)
		_property_difficulty_picker.set_item_metadata(index, difficulty_id)

func _sync_property_controls() -> void:
	_rebuild_selected_object_picker()
	_sync_property_value_controls(_selected_property_object_detail())

func _rebuild_selected_object_picker() -> void:
	if _selected_object_picker == null:
		return
	var options := _property_object_options_at(_selected_tile)
	_selected_object_picker.clear()
	var selected_index := -1
	for index in range(options.size()):
		var detail: Dictionary = options[index]
		var property_key := String(detail.get("property_key", ""))
		_selected_object_picker.add_item(_property_object_label(detail), index)
		_selected_object_picker.set_item_metadata(index, property_key)
		if property_key == _selected_property_object_key:
			selected_index = index
	if selected_index < 0 and not options.is_empty():
		selected_index = 0
	if selected_index >= 0:
		_selected_object_picker.select(selected_index)
		_selected_property_object_key = String(_selected_object_picker.get_item_metadata(selected_index))
		_selected_object_picker.disabled = false
	else:
		_selected_property_object_key = ""
		_selected_object_picker.disabled = true

func _sync_property_value_controls(detail: Dictionary) -> void:
	var has_detail := not detail.is_empty()
	var kind := String(detail.get("kind", ""))
	_property_summary_label.text = _property_summary_text(detail)
	_property_summary_label.tooltip_text = _property_summary_label.text
	_property_owner_picker.disabled = kind != OBJECT_FAMILY_TOWN
	_property_difficulty_picker.disabled = kind != OBJECT_FAMILY_ENCOUNTER
	_property_collected_check.disabled = kind != OBJECT_FAMILY_RESOURCE and kind != OBJECT_FAMILY_ARTIFACT
	_property_apply_button.disabled = not has_detail
	if kind == OBJECT_FAMILY_TOWN:
		_select_picker_metadata(_property_owner_picker, String(detail.get("owner", "neutral")))
	elif kind == OBJECT_FAMILY_ENCOUNTER:
		_ensure_picker_metadata(_property_difficulty_picker, String(detail.get("difficulty", "medium")))
		_select_picker_metadata(_property_difficulty_picker, String(detail.get("difficulty", "medium")))
	elif kind == OBJECT_FAMILY_RESOURCE or kind == OBJECT_FAMILY_ARTIFACT:
		_property_collected_check.button_pressed = bool(detail.get("collected", false))
	else:
		_select_picker_metadata(_property_owner_picker, "neutral")
		_select_picker_metadata(_property_difficulty_picker, "medium")
		_property_collected_check.button_pressed = false

func _property_summary_text(detail: Dictionary) -> String:
	if detail.is_empty():
		return "Select a tile with a town, site, artifact, or encounter."
	var taxonomy = detail.get("taxonomy", {})
	var taxonomy_summary := _taxonomy_inline_text(taxonomy) if taxonomy is Dictionary else ""
	match String(detail.get("kind", "")):
		OBJECT_FAMILY_TOWN:
			return "Town owner edit | %s" % taxonomy_summary if taxonomy_summary != "" else "Town owner edits mutate the working-copy town state only."
		OBJECT_FAMILY_RESOURCE:
			return "Site collected edit | %s" % taxonomy_summary if taxonomy_summary != "" else "Site collected edits mutate the working-copy resource node only."
		OBJECT_FAMILY_ARTIFACT:
			return "Artifact collected edit | %s" % taxonomy_summary if taxonomy_summary != "" else "Artifact collected edits mutate the working-copy artifact node only."
		OBJECT_FAMILY_ENCOUNTER:
			return "Encounter difficulty edit | %s" % taxonomy_summary if taxonomy_summary != "" else "Encounter difficulty edits mutate the working-copy encounter only."
		_:
			return "No mutable object property is available for this selection."

func _property_object_options_at(tile: Vector2i) -> Array:
	var options := []
	if _session == null or not _tile_in_bounds(tile):
		return options
	for detail in _object_details_at(tile, false):
		if not (detail is Dictionary):
			continue
		var kind := String(detail.get("kind", ""))
		if kind in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
			options.append(detail)
	return options

func _selected_property_object_detail() -> Dictionary:
	if _selected_property_object_key == "":
		return {}
	for detail in _property_object_options_at(_selected_tile):
		if detail is Dictionary and String(detail.get("property_key", "")) == _selected_property_object_key:
			return detail
	return {}

func _object_detail_by_key(property_key: String) -> Dictionary:
	if _session == null or property_key == "":
		return {}
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var array_key := _placement_array_key(family)
		var placements = _session.overworld.get(array_key, [])
		if not (placements is Array):
			continue
		for placement in placements:
			if not (placement is Dictionary):
				continue
			var placement_id := String(placement.get("placement_id", ""))
			if _object_property_key(family, placement_id) != property_key:
				continue
			return _object_detail_for_placement(family, placement)
	return {}

func _selected_property_object_payload() -> Dictionary:
	var detail := _selected_property_object_detail()
	return _property_object_payload_from_detail(detail)

func _property_object_payload_from_detail(detail: Dictionary) -> Dictionary:
	if detail.is_empty():
		return {}
	var taxonomy = detail.get("taxonomy", {})
	var guidance = detail.get("placement_guidance", {})
	if not (guidance is Dictionary):
		guidance = {}
	if guidance.is_empty() and taxonomy is Dictionary:
		guidance = _placement_guidance_payload(taxonomy, Vector2i(int(detail.get("x", 0)), int(detail.get("y", 0))))
	return {
		"property_key": String(detail.get("property_key", "")),
		"kind": String(detail.get("kind", "")),
		"placement_id": String(detail.get("placement_id", "")),
		"content_id": String(detail.get("content_id", "")),
		"name": String(detail.get("name", "")),
		"editable_properties": _editable_properties_for_object(String(detail.get("kind", ""))),
		"owner": String(detail.get("owner", "")),
		"difficulty": String(detail.get("difficulty", "")),
		"collected": bool(detail.get("collected", false)),
		"collected_by_faction_id": String(detail.get("collected_by_faction_id", "")),
		"collected_day": max(0, int(detail.get("collected_day", 0))),
		"taxonomy": detail.get("taxonomy", {}),
		"taxonomy_summary": String(detail.get("taxonomy_summary", "")),
		"control_summary": String(detail.get("control_summary", "")),
		"control_inspection": String(detail.get("control_inspection", "")),
		"placement_guidance": guidance,
		"authoring_dependencies": detail.get("authoring_dependencies", {}),
		"x": int(detail.get("x", 0)),
		"y": int(detail.get("y", 0)),
	}

func _pending_move_object_payload() -> Dictionary:
	return _property_object_payload_from_detail(_object_detail_by_key(_pending_move_object_key))

func _pending_duplicate_object_payload() -> Dictionary:
	return _property_object_payload_from_detail(_object_detail_by_key(_pending_duplicate_object_key))

func _select_property_object_at_tile(family: String) -> bool:
	for detail in _property_object_options_at(_selected_tile):
		if not (detail is Dictionary):
			continue
		if family != "" and String(detail.get("kind", "")) != family:
			continue
		_selected_property_object_key = String(detail.get("property_key", ""))
		return _selected_property_object_key != ""
	_selected_property_object_key = ""
	return false

func _apply_object_property_value(property_name: String, value: Variant) -> Dictionary:
	var detail := _selected_property_object_detail()
	if detail.is_empty():
		return {"ok": false, "changed": false, "message": "No selected object property target."}
	var kind := String(detail.get("kind", ""))
	var placement_id := String(detail.get("placement_id", ""))
	match property_name:
		PROPERTY_TOWN_OWNER:
			if kind != OBJECT_FAMILY_TOWN:
				return {"ok": false, "changed": false, "message": "Owner is only editable for towns."}
			return _set_town_owner_property(placement_id, String(value))
		PROPERTY_ENCOUNTER_DIFFICULTY:
			if kind != OBJECT_FAMILY_ENCOUNTER:
				return {"ok": false, "changed": false, "message": "Difficulty is only editable for encounters."}
			return _set_encounter_difficulty_property(placement_id, String(value))
		PROPERTY_COLLECTED:
			if kind != OBJECT_FAMILY_RESOURCE and kind != OBJECT_FAMILY_ARTIFACT:
				return {"ok": false, "changed": false, "message": "Collected is only editable for sites and artifacts."}
			return _set_collected_property(kind, placement_id, bool(value))
		_:
			return {"ok": false, "changed": false, "message": "Unsupported editable property %s." % property_name}

func _property_object_label(detail: Dictionary) -> String:
	var kind := String(detail.get("kind", ""))
	var name := String(detail.get("name", detail.get("content_id", "")))
	var placement_id := String(detail.get("placement_id", ""))
	match kind:
		OBJECT_FAMILY_TOWN:
			return "Town | %s | owner %s" % [name, String(detail.get("owner", "neutral"))]
		OBJECT_FAMILY_RESOURCE:
			return "Site | %s | collected %s" % [name, "yes" if bool(detail.get("collected", false)) else "no"]
		OBJECT_FAMILY_ARTIFACT:
			return "Artifact | %s | collected %s" % [name, "yes" if bool(detail.get("collected", false)) else "no"]
		OBJECT_FAMILY_ENCOUNTER:
			return "Encounter | %s | %s" % [name, String(detail.get("difficulty", "medium"))]
		_:
			return "%s | %s" % [kind.capitalize(), placement_id]

func _ensure_picker_metadata(picker: OptionButton, value: String) -> void:
	if value == "":
		return
	for index in range(picker.get_item_count()):
		if String(picker.get_item_metadata(index)) == value:
			return
	var index := picker.get_item_count()
	picker.add_item(value.capitalize(), index)
	picker.set_item_metadata(index, value)

func _select_picker_metadata(picker: OptionButton, value: String) -> bool:
	for index in range(picker.get_item_count()):
		if String(picker.get_item_metadata(index)) == value:
			picker.select(index)
			return true
	return false

func _selected_picker_metadata(picker: OptionButton, fallback: String = "") -> String:
	var selected_index := picker.selected
	if selected_index < 0 or selected_index >= picker.get_item_count():
		return fallback
	return String(picker.get_item_metadata(selected_index))

func _scenario_items() -> Array:
	var raw := ContentService.load_json("res://content/scenarios.json")
	var items = raw.get("items", [])
	return items if items is Array else []

func _terrain_items() -> Array:
	var grammar := ContentService.get_terrain_grammar()
	var class_index := _terrain_class_index(grammar)
	var curated_options = grammar.get(TERRAIN_OPTION_SOURCE, [])
	var curated_items := []
	if curated_options is Array:
		for option in curated_options:
			if not (option is Dictionary):
				continue
			var option_id := String(option.get("id", ""))
			if option_id == "" or not class_index.has(option_id):
				continue
			var terrain_class: Dictionary = class_index.get(option_id, {})
			curated_items.append(
				{
					"id": option_id,
					"label": String(option.get("label", terrain_class.get("label", option_id.capitalize()))),
					"homm3_family": String(option.get("homm3_family", "")),
					"homm3_atlas": String(option.get("homm3_atlas", "")),
				}
			)
	if not curated_items.is_empty():
		return curated_items
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

func _terrain_class_index(grammar: Dictionary) -> Dictionary:
	var classes = grammar.get("terrain_classes", [])
	var index := {}
	if not (classes is Array):
		return index
	for terrain_class in classes:
		if not (terrain_class is Dictionary):
			continue
		var terrain_id := String(terrain_class.get("id", ""))
		if terrain_id != "":
			index[terrain_id] = terrain_class
	return index

func _terrain_label_for_id(terrain_id: String) -> String:
	for entry in _terrain_entries:
		if not (entry is Dictionary):
			continue
		if String(entry.get("id", "")) == terrain_id:
			return String(entry.get("label", terrain_id.capitalize()))
	return terrain_id.capitalize()

func _terrain_option_payload() -> Array:
	var options := []
	for entry in _terrain_entries:
		if not (entry is Dictionary):
			continue
		options.append(
			{
				"id": String(entry.get("id", "")),
				"label": String(entry.get("label", "")),
				"homm3_family": String(entry.get("homm3_family", "")),
				"homm3_atlas": String(entry.get("homm3_atlas", "")),
			}
		)
	return options

func _terrain_option_ids() -> Array:
	var ids := []
	for entry in _terrain_entries:
		if entry is Dictionary:
			ids.append(String(entry.get("id", "")))
	return ids

func _authored_terrain_ids() -> Array:
	var grammar := ContentService.get_terrain_grammar()
	var classes = grammar.get("terrain_classes", [])
	var ids := []
	if not (classes is Array):
		return ids
	for terrain_class in classes:
		if not (terrain_class is Dictionary):
			continue
		var terrain_id := String(terrain_class.get("id", ""))
		if terrain_id != "":
			ids.append(terrain_id)
	return ids

func _hidden_terrain_ids() -> Array:
	var option_ids := _terrain_option_ids()
	var hidden := []
	for terrain_id in _authored_terrain_ids():
		if terrain_id not in option_ids:
			hidden.append(terrain_id)
	return hidden

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

func _object_content_taxonomy_payload(family: String, content_id: String) -> Dictionary:
	if content_id == "":
		return {}
	match family:
		OBJECT_FAMILY_TOWN:
			var town := ContentService.get_town(content_id)
			if town.is_empty():
				return {}
			return _town_taxonomy_payload(town)
		OBJECT_FAMILY_RESOURCE:
			var site := ContentService.get_resource_site(content_id)
			if site.is_empty():
				return {}
			var node := {"site_id": content_id}
			return _resource_taxonomy_payload(node, site)
		OBJECT_FAMILY_ARTIFACT:
			var artifact := ContentService.get_artifact(content_id)
			if artifact.is_empty():
				return {}
			return _artifact_taxonomy_payload(artifact)
		OBJECT_FAMILY_ENCOUNTER:
			var encounter := ContentService.get_encounter(content_id)
			if encounter.is_empty():
				return {}
			var placement := {
				"encounter_id": content_id,
				"difficulty": "medium",
			}
			return _encounter_taxonomy_payload(placement, encounter)
		_:
			return {}

func _town_taxonomy_payload(town: Dictionary) -> Dictionary:
	var faction_id := String(town.get("faction_id", ""))
	var faction := ContentService.get_faction(faction_id)
	var tags := ["settlement", "production", "ownership"]
	if faction_id != "":
		tags.append("faction_presence")
	var town_state := {
		"town_id": String(town.get("id", "")),
		"built_buildings": town.get("starting_building_ids", []),
	}
	return {
		"primary_class": "town",
		"secondary_tags": tags,
		"cadence": "persistent_control",
		"passability_class": "town_blocking",
		"content_link_label": "Town",
		"content_link_id": String(town.get("id", "")),
		"object_family": "town",
		"summary": "Town | Cadence: persistent control | Passability: town blocking",
		"detail": "Faction %s" % String(faction.get("name", faction_id)) if faction_id != "" else "",
		"town_role": String(town.get("strategic_role", "frontier")),
		"identity_summary": OverworldRules.describe_town_identity_surface(town_state),
	}

func _artifact_taxonomy_payload(artifact: Dictionary) -> Dictionary:
	return {
		"primary_class": "artifact_reward",
		"secondary_tags": ["reward", "hero_progression"],
		"cadence": "one_time",
		"passability_class": "passable_visit_on_enter",
		"content_link_label": "Artifact",
		"content_link_id": String(artifact.get("id", "")),
		"object_family": "artifact",
		"summary": "Artifact reward | Cadence: one-time | Passability: visit on enter",
		"detail": String(artifact.get("slot", "")),
	}

func _resource_taxonomy_payload(node: Dictionary, site: Dictionary) -> Dictionary:
	var site_id := String(site.get("id", node.get("site_id", "")))
	var map_object := ContentService.get_map_object_for_resource_site(site_id)
	var primary_class := String(map_object.get("primary_class", "")).strip_edges()
	if primary_class == "":
		primary_class = _fallback_resource_primary_class(site)
	var secondary_tags := _string_array_for_editor(map_object.get("secondary_tags", []))
	if secondary_tags.is_empty():
		secondary_tags = _string_array_for_editor(map_object.get("map_roles", []))
	if secondary_tags.is_empty():
		secondary_tags = _fallback_resource_tags(site)
	var interaction = map_object.get("interaction", {})
	var cadence := ""
	if interaction is Dictionary:
		cadence = String(interaction.get("cadence", "")).strip_edges()
	if cadence == "":
		cadence = _fallback_resource_cadence(site)
	var passability_class := String(map_object.get("passability_class", "")).strip_edges()
	if passability_class == "":
		passability_class = _fallback_passability_class(map_object, String(site.get("family", "")))
	var footprint := _footprint_summary(map_object.get("footprint", {}))
	var surface := OverworldRules.describe_resource_site_interaction_surface(node, site)
	var recruit_source_summary := ""
	var recruit_source_inspection := ""
	var live_surface := ""
	var control_summary := ""
	var control_inspection := ""
	if OverworldRules.resource_site_is_recruit_source(site):
		recruit_source_summary = OverworldRules.describe_recruit_source_compact(_session, node, site)
		recruit_source_inspection = OverworldRules.describe_recruit_source_inspection(_session, node, site)
	if _session != null:
		live_surface = OverworldRules.describe_resource_site_surface(_session, node, site)
		control_summary = OverworldRules.describe_resource_site_control_summary(_session, node, site)
		control_inspection = OverworldRules.describe_resource_site_control_inspection(_session, node, site)
	return {
		"primary_class": primary_class,
		"secondary_tags": secondary_tags,
		"cadence": cadence,
		"passability_class": passability_class,
		"content_link_label": "Resource site",
		"content_link_id": site_id,
		"resource_site_id": site_id,
		"map_object_id": String(map_object.get("id", "")),
		"map_object_name": String(map_object.get("name", "")),
		"object_family": String(map_object.get("family", site.get("family", "one_shot_pickup"))),
		"site_family": String(site.get("family", "one_shot_pickup")),
		"footprint": footprint,
		"summary": surface,
		"detail": live_surface,
		"control_summary": control_summary,
		"control_inspection": control_inspection,
		"recruit_source_summary": recruit_source_summary,
		"recruit_source_inspection": recruit_source_inspection,
	}

func _encounter_taxonomy_payload(placement: Dictionary, encounter: Dictionary) -> Dictionary:
	var map_object := ContentService.get_map_object(String(placement.get("object_id", "")))
	var neutral_metadata = placement.get("neutral_encounter", {})
	if not (neutral_metadata is Dictionary) or neutral_metadata.is_empty():
		neutral_metadata = map_object.get("neutral_encounter", {})
	if not (neutral_metadata is Dictionary):
		neutral_metadata = {}
	var primary_class := String(map_object.get("primary_class", placement.get("primary_class", ""))).strip_edges()
	if primary_class == "":
		primary_class = String(neutral_metadata.get("primary_class", "neutral_encounter")).strip_edges()
	var secondary_tags := _string_array_for_editor(map_object.get("secondary_tags", []))
	if secondary_tags.is_empty():
		secondary_tags = _string_array_for_editor(neutral_metadata.get("secondary_tags", []))
	if secondary_tags.is_empty():
		secondary_tags = ["visible_army"]
	var interaction = map_object.get("interaction", {})
	var cadence := ""
	if interaction is Dictionary:
		cadence = String(interaction.get("cadence", "")).strip_edges()
	if cadence == "":
		cadence = "one_time"
	var passability_class := String(map_object.get("passability_class", "")).strip_edges()
	var passability = neutral_metadata.get("passability", {})
	if passability_class == "" and passability is Dictionary:
		passability_class = String(passability.get("passability_class", "")).strip_edges()
	if passability_class == "":
		passability_class = "neutral_stack_blocking"
	var representation = neutral_metadata.get("representation", {})
	var role := ""
	if representation is Dictionary:
		role = String(representation.get("mode", "")).strip_edges()
	if role == "":
		role = _fallback_encounter_role(secondary_tags)
	var reward_guard = neutral_metadata.get("reward_guard_summary", {})
	var risk := ""
	if reward_guard is Dictionary:
		risk = String(reward_guard.get("risk_tier", "")).strip_edges()
	if risk == "":
		risk = _risk_from_difficulty(String(placement.get("difficulty", "medium")))
	var guard = placement.get("guard_link", {})
	if not (guard is Dictionary):
		guard = neutral_metadata.get("guard_link", {})
	if not (guard is Dictionary):
		guard = {}
	var surface := OverworldRules.describe_encounter_object_surface(placement)
	if surface == "":
		surface = "Neutral encounter | Risk %s | Cadence one-time" % _humanize_editor_id(risk)
	var guard_surface := ""
	var consequence_surface := ""
	var readiness_surface := ""
	if _session != null:
		guard_surface = OverworldRules.describe_encounter_guard_link_surface(_session, placement)
		consequence_surface = OverworldRules.describe_encounter_consequence_surface(_session, placement)
		readiness_surface = OverworldRules.describe_encounter_compact_readability(_session, placement)
	return {
		"primary_class": primary_class,
		"secondary_tags": secondary_tags,
		"cadence": cadence,
		"passability_class": passability_class,
		"content_link_label": "Encounter",
		"content_link_id": String(encounter.get("id", placement.get("encounter_id", ""))),
		"map_object_id": String(map_object.get("id", "")),
		"object_placement_id": String(placement.get("object_placement_id", "")),
		"object_family": String(map_object.get("family", "neutral_encounter")),
		"encounter_role": role,
		"risk_tier": risk,
		"guard_role": String(guard.get("guard_role", "")),
		"guard_target_id": String(guard.get("target_id", "")),
		"guard_target_placement_id": String(guard.get("target_placement_id", "")),
		"guard_link_surface": guard_surface,
		"consequence_summary": consequence_surface,
		"readiness_summary": readiness_surface,
		"summary": surface,
		"detail": _encounter_detail_summary(encounter, placement, risk, role, guard),
	}

func _taxonomy_summary_text(payload: Dictionary) -> String:
	if payload.is_empty():
		return ""
	var lines := []
	var class_label := _humanize_editor_id(String(payload.get("primary_class", "")))
	var cadence_label := _humanize_editor_id(String(payload.get("cadence", "")))
	var passability_label := _humanize_editor_id(String(payload.get("passability_class", "")))
	lines.append("Class %s | Cadence %s | Passability %s" % [class_label, cadence_label, passability_label])
	var tag_summary := _tag_summary_for_editor(payload.get("secondary_tags", []), 3)
	if tag_summary != "":
		lines.append("Tags %s" % tag_summary)
	var link_line := _taxonomy_link_line(payload)
	if link_line != "":
		lines.append(link_line)
	var role_line := _taxonomy_role_line(payload)
	if role_line != "":
		lines.append(role_line)
	var guard_link_surface := String(payload.get("guard_link_surface", "")).strip_edges()
	if guard_link_surface != "":
		lines.append("Guard link %s" % guard_link_surface)
	var consequence_summary := String(payload.get("consequence_summary", "")).strip_edges()
	if consequence_summary != "":
		lines.append(consequence_summary)
	lines.append_array(_recruit_source_summary_lines_for_editor(payload, 2))
	lines.append_array(_identity_summary_lines_for_editor(payload, 3))
	return "\n".join(lines)

func _taxonomy_inline_text(payload: Dictionary) -> String:
	if payload.is_empty():
		return ""
	var parts := []
	var primary_class := String(payload.get("primary_class", ""))
	if primary_class != "":
		parts.append("class %s" % _humanize_editor_id(primary_class))
	var cadence := String(payload.get("cadence", ""))
	if cadence != "":
		parts.append("cadence %s" % _humanize_editor_id(cadence))
	var passability_class := String(payload.get("passability_class", ""))
	if passability_class != "":
		parts.append("pass %s" % _humanize_editor_id(passability_class))
	var tag_summary := _tag_summary_for_editor(payload.get("secondary_tags", []), 2)
	if tag_summary != "":
		parts.append("tags %s" % tag_summary)
	return " | ".join(parts)

func _taxonomy_link_line(payload: Dictionary) -> String:
	var links := []
	var map_object_id := String(payload.get("map_object_id", "")).strip_edges()
	if map_object_id != "":
		links.append("Object %s" % map_object_id)
	var resource_site_id := String(payload.get("resource_site_id", "")).strip_edges()
	if resource_site_id != "":
		links.append("Site %s" % resource_site_id)
	var content_link_id := String(payload.get("content_link_id", "")).strip_edges()
	if links.is_empty() and content_link_id != "":
		links.append("%s %s" % [String(payload.get("content_link_label", "Content")), content_link_id])
	var footprint := String(payload.get("footprint", "")).strip_edges()
	if footprint != "":
		links.append("Footprint %s" % footprint)
	return " | ".join(links)

func _taxonomy_role_line(payload: Dictionary) -> String:
	var role := String(payload.get("encounter_role", "")).strip_edges()
	var risk := String(payload.get("risk_tier", "")).strip_edges()
	var guard_role := String(payload.get("guard_role", "")).strip_edges()
	var guard_target := String(payload.get("guard_target_placement_id", payload.get("guard_target_id", ""))).strip_edges()
	var parts := []
	if role != "":
		parts.append("Role %s" % _humanize_editor_id(role))
	if risk != "":
		parts.append("Risk %s" % _humanize_editor_id(risk))
	if guard_role != "":
		var guard_text := "Guard %s" % _humanize_editor_id(guard_role)
		if guard_target != "":
			guard_text = "%s -> %s" % [guard_text, guard_target]
		parts.append(guard_text)
	var site_family := String(payload.get("site_family", "")).strip_edges()
	if parts.is_empty() and site_family != "":
		parts.append("Site family %s" % _humanize_editor_id(site_family))
	return " | ".join(parts)

func _identity_summary_lines_for_editor(payload: Dictionary, limit: int) -> Array:
	var identity_summary := String(payload.get("identity_summary", "")).strip_edges()
	if identity_summary == "":
		return []
	var lines := []
	for raw_line in identity_summary.split("\n"):
		var line := String(raw_line).strip_edges()
		if line == "":
			continue
		lines.append(line)
		if lines.size() >= limit:
			break
	return lines

func _recruit_source_summary_lines_for_editor(payload: Dictionary, limit: int) -> Array:
	var inspection := String(payload.get("recruit_source_inspection", "")).strip_edges()
	if inspection == "":
		return []
	var lines := []
	for raw_line in inspection.split("\n"):
		var line := String(raw_line).strip_edges()
		if line == "":
			continue
		lines.append(line)
		if lines.size() >= limit:
			break
	return lines

func _object_palette_guidance_text(payload: Dictionary, guidance: Dictionary) -> String:
	if payload.is_empty():
		return ""
	var lines := []
	var class_label := _humanize_editor_id(String(payload.get("primary_class", "")))
	var cadence_label := _humanize_editor_id(String(payload.get("cadence", "")))
	var passability_label := _humanize_editor_id(String(payload.get("passability_class", "")))
	lines.append("Class %s | Cadence %s | Passability %s" % [class_label, cadence_label, passability_label])
	if not guidance.is_empty():
		lines.append("Place %s | Density %s" % [
			String(guidance.get("placement_role", "")),
			String(guidance.get("density_target", "")),
		])
		lines.append("Flags %s | Local %d in 16x16" % [
			String(guidance.get("role_flags_text", "")),
			int(guidance.get("local_density_count", 0)),
		])
	else:
		var tag_summary := _tag_summary_for_editor(payload.get("secondary_tags", []), 3)
		if tag_summary != "":
			lines.append("Tags %s" % tag_summary)
	var preview := _selected_object_placement_preview_payload(_placement_preview_tile())
	var preview_text := String(preview.get("text", "")).strip_edges()
	if preview_text != "":
		for raw_line in preview_text.split("\n"):
			var line := String(raw_line).strip_edges()
			if line != "":
				lines.append(line)
	var link_line := _taxonomy_link_line(payload)
	if link_line != "":
		lines.append(link_line)
	var tile_dependency := _selected_tile_authoring_dependency_text()
	if tile_dependency != "":
		lines.append(tile_dependency)
	lines.append_array(_recruit_source_summary_lines_for_editor(payload, 2))
	lines.append_array(_identity_summary_lines_for_editor(payload, 2))
	return "\n".join(lines)

func _placement_preview_tile() -> Vector2i:
	if _tool == TOOL_PLACE_OBJECT and _tile_in_bounds(_hovered_tile):
		return _hovered_tile
	return _selected_tile

func _selected_object_placement_preview_payload(tile: Vector2i) -> Dictionary:
	var payload := _object_content_taxonomy_payload(_selected_object_family, _selected_object_content_id)
	if payload.is_empty() or _selected_object_family == "" or _selected_object_content_id == "":
		return {}
	var guidance := _placement_guidance_payload(payload, tile)
	var availability := _placement_availability_for_selected_object(tile)
	var context_lines := _placement_context_lines(_selected_object_family, _selected_object_content_id, payload, tile)
	var density_warning := _density_warning_for_guidance(guidance, bool(availability.get("can_place", false)))
	var dependency_warning := _placement_dependency_warning(payload)
	var consequence := _placement_authoring_consequence(_selected_object_family, _selected_object_content_id, payload, guidance)
	var warning_lines := []
	var blocked_reason := String(availability.get("blocked_reason", "")).strip_edges()
	if blocked_reason != "":
		warning_lines.append(blocked_reason)
	if density_warning != "":
		warning_lines.append(density_warning)
	if dependency_warning != "":
		warning_lines.append(dependency_warning)
	var text_lines := [
		"Preview %d,%d: %s | %s" % [
			tile.x,
			tile.y,
			String(guidance.get("placement_role", "")),
			"can place" if bool(availability.get("can_place", false)) else "blocked",
		],
	]
	text_lines.append_array(context_lines)
	if not warning_lines.is_empty():
		text_lines.append("Warning: %s" % " | ".join(warning_lines))
	text_lines.append("Consequence: %s" % consequence)
	return {
		"target_tile": {"x": tile.x, "y": tile.y},
		"family": _selected_object_family,
		"content_id": _selected_object_content_id,
		"can_place": bool(availability.get("can_place", false)),
		"blocked_reason": blocked_reason,
		"placement_role": String(guidance.get("placement_role", "")),
		"role_flags_text": String(guidance.get("role_flags_text", "")),
		"terrain_context": _placement_terrain_context_line(tile),
		"affected_context": context_lines,
		"density_warning": density_warning,
		"dependency_warning": dependency_warning,
		"warnings": warning_lines,
		"authoring_consequence": consequence,
		"guidance": guidance,
		"text": "\n".join(text_lines),
	}

func _editor_acceptance_cue_payload() -> Dictionary:
	if _session == null:
		return {}
	var recap: Dictionary = _last_object_authoring_recap if _last_object_authoring_recap is Dictionary else {}
	var recap_next_check := String(recap.get("next_check", "")).strip_edges()
	if not recap.is_empty() and recap_next_check != "":
		return {
			"source": "action_recap",
			"action": String(recap.get("action", "")),
			"placement_id": String(recap.get("placement_id", "")),
			"next_check": recap_next_check,
			"text": "Cue: %s" % recap_next_check,
		}
	var preview := _selected_object_placement_preview_payload(_placement_preview_tile())
	if _tool == TOOL_PLACE_OBJECT and not preview.is_empty():
		var target_tile: Dictionary = preview.get("target_tile", {})
		var target_label := "%d,%d" % [int(target_tile.get("x", _selected_tile.x)), int(target_tile.get("y", _selected_tile.y))]
		var content_id := String(preview.get("content_id", _selected_object_content_id))
		var blocked_reason := String(preview.get("blocked_reason", "")).strip_edges()
		var dependency_warning := String(preview.get("dependency_warning", "")).strip_edges()
		var consequence := String(preview.get("authoring_consequence", "")).strip_edges()
		if not bool(preview.get("can_place", false)):
			var blocked_next := blocked_reason if blocked_reason != "" else "choose an empty destination before placing."
			return {
				"source": "placement_preview",
				"target_tile": target_tile,
				"family": String(preview.get("family", _selected_object_family)),
				"content_id": content_id,
				"can_place": false,
				"next_check": blocked_next,
				"text": "Cue: Pick another tile or remove the blocker at %s; %s" % [target_label, blocked_next],
			}
		var preview_next := dependency_warning if dependency_warning != "" else consequence
		if preview_next == "":
			preview_next = "inspect density, dependency, and route context after placement."
		return {
			"source": "placement_preview",
			"target_tile": target_tile,
			"family": String(preview.get("family", _selected_object_family)),
			"content_id": content_id,
			"can_place": true,
			"next_check": preview_next,
			"text": "Cue: Click %s to place %s; then %s" % [target_label, content_id, preview_next],
		}
	var validation := _scenario_authoring_validation_payload()
	var warnings: Array = validation.get("warnings", [])
	if int(validation.get("warning_count", 0)) > 0 and not warnings.is_empty():
		var warning := String(warnings[0]).strip_edges()
		if warning != "":
			return {
				"source": "scenario_validation",
				"next_check": warning,
				"text": "Cue: Check authoring warning; %s" % warning,
			}
	var summary := String(validation.get("summary", "")).strip_edges()
	if summary != "":
		return {
			"source": "scenario_validation",
			"next_check": summary,
			"text": "Cue: Select a tile or tool; %s before Play Copy." % summary,
		}
	return {}

func _set_object_authoring_recap(
	action: String,
	changed: bool,
	before_detail: Dictionary,
	after_detail: Dictionary,
	from_tile: Vector2i,
	to_tile: Vector2i,
	preview: Dictionary = {},
	property_name: String = "",
	previous_value: Variant = null,
	new_value: Variant = null
) -> Dictionary:
	var recap := _object_authoring_recap_payload(
		action,
		changed,
		before_detail,
		after_detail,
		from_tile,
		to_tile,
		preview,
		property_name,
		previous_value,
		new_value
	)
	_last_object_authoring_recap = recap
	var text := String(recap.get("text", "")).strip_edges()
	if text != "":
		_last_message = text
	return recap

func _object_authoring_recap_payload(
	action: String,
	changed: bool,
	before_detail: Dictionary,
	after_detail: Dictionary,
	from_tile: Vector2i,
	to_tile: Vector2i,
	preview: Dictionary = {},
	property_name: String = "",
	previous_value: Variant = null,
	new_value: Variant = null
) -> Dictionary:
	var detail := after_detail if not after_detail.is_empty() else before_detail
	if detail.is_empty():
		return {}
	var kind := String(detail.get("kind", ""))
	var content_id := String(detail.get("content_id", ""))
	var placement_id := String(detail.get("placement_id", ""))
	var target_tile := to_tile
	if not _tile_in_bounds(target_tile):
		target_tile = Vector2i(int(detail.get("x", from_tile.x)), int(detail.get("y", from_tile.y)))
	var taxonomy = detail.get("taxonomy", {})
	if not (taxonomy is Dictionary):
		taxonomy = _object_content_taxonomy_payload(kind, content_id)
	var enriched_detail := detail.duplicate(true)
	if taxonomy is Dictionary and not taxonomy.is_empty():
		enriched_detail["taxonomy"] = taxonomy
	if not _tile_in_bounds(target_tile):
		target_tile = from_tile
	enriched_detail = _object_detail_with_guidance(enriched_detail, target_tile)
	var dependencies: Dictionary = enriched_detail.get("authoring_dependencies", {})
	var context_lines := []
	if taxonomy is Dictionary and not taxonomy.is_empty() and _tile_in_bounds(target_tile):
		context_lines = _placement_context_lines(kind, content_id, taxonomy, target_tile)
	var dependency_line := _dependency_recap_line(enriched_detail)
	var why_line := _object_action_why_line(action, enriched_detail, preview, property_name)
	var next_check := _object_action_next_check(action, enriched_detail, preview, property_name)
	var headline := _object_action_headline(action, changed, before_detail, after_detail, from_tile, target_tile, property_name, previous_value, new_value)
	var text_lines := [headline]
	if not context_lines.is_empty():
		text_lines.append("Context: %s" % _compact_join_limited(context_lines, 2))
	if dependency_line != "":
		text_lines.append("Dependency: %s" % dependency_line)
	if why_line != "":
		text_lines.append("Matters: %s" % why_line)
	if next_check != "":
		text_lines.append("Next: %s" % next_check)
	return {
		"action": action,
		"changed": changed,
		"family": kind,
		"placement_id": placement_id,
		"content_id": content_id,
		"name": String(detail.get("name", content_id)),
		"from": {"x": from_tile.x, "y": from_tile.y} if _tile_in_bounds(from_tile) else {},
		"to": {"x": target_tile.x, "y": target_tile.y} if _tile_in_bounds(target_tile) else {},
		"property": property_name,
		"previous_value": _editor_variant_text(previous_value) if property_name != "" else "",
		"new_value": _editor_variant_text(new_value) if property_name != "" else "",
		"context": context_lines,
		"dependency_summary": dependency_line,
		"dependency_warning_count": dependencies.get("warnings", []).size() if dependencies is Dictionary else 0,
		"why": why_line,
		"next_check": next_check,
		"text": "\n".join(text_lines),
	}

func _object_action_headline(
	action: String,
	changed: bool,
	before_detail: Dictionary,
	after_detail: Dictionary,
	from_tile: Vector2i,
	to_tile: Vector2i,
	property_name: String,
	previous_value: Variant,
	new_value: Variant
) -> String:
	var detail := after_detail if not after_detail.is_empty() else before_detail
	var object_label := _object_recap_label(detail)
	var changed_prefix := _object_action_label(action, changed)
	match action:
		"place":
			return "%s %s at %d,%d." % [changed_prefix, object_label, to_tile.x, to_tile.y]
		"remove":
			return "%s %s from %d,%d." % [changed_prefix, object_label, from_tile.x, from_tile.y]
		"move":
			return "%s %s from %d,%d to %d,%d." % [changed_prefix, object_label, from_tile.x, from_tile.y, to_tile.x, to_tile.y]
		"duplicate":
			return "%s %s from %d,%d to %d,%d." % [changed_prefix, object_label, from_tile.x, from_tile.y, to_tile.x, to_tile.y]
		"retheme":
			return "%s %s from %s to %s at %d,%d." % [
				changed_prefix,
				_object_recap_label(before_detail),
				String(before_detail.get("content_id", "")),
				String(after_detail.get("content_id", "")),
				to_tile.x,
				to_tile.y,
			]
		"edit_property":
			return "%s %s %s from %s to %s at %d,%d." % [
				changed_prefix,
				object_label,
				_humanize_editor_id(property_name),
				_editor_variant_text(previous_value),
				_editor_variant_text(new_value),
				to_tile.x,
				to_tile.y,
			]
		_:
			return "%s %s." % [changed_prefix, object_label]

func _object_action_label(action: String, changed: bool) -> String:
	if not changed:
		return "No change for"
	match action:
		"place":
			return "Placed"
		"remove":
			return "Removed"
		"move":
			return "Moved"
		"duplicate":
			return "Duplicated"
		"retheme":
			return "Rethemed"
		"edit_property":
			return "Edited"
		_:
			return "Updated"

func _object_recap_label(detail: Dictionary) -> String:
	if detail.is_empty():
		return "object"
	var family_label := _object_family_label(String(detail.get("kind", "")))
	var name := String(detail.get("name", detail.get("content_id", ""))).strip_edges()
	var placement_id := String(detail.get("placement_id", "")).strip_edges()
	if placement_id == "":
		return "%s %s" % [family_label, name]
	return "%s %s (%s)" % [family_label, name, placement_id]

func _dependency_recap_line(detail: Dictionary) -> String:
	var dependencies = detail.get("authoring_dependencies", {})
	if not (dependencies is Dictionary) or dependencies.is_empty():
		return "no authored objective, guard, reward, route, or enemy-focus link found"
	var parts := []
	var summary := String(dependencies.get("summary", "")).strip_edges()
	if summary != "":
		parts.append(summary)
	var warnings: Array = dependencies.get("warnings", [])
	if not warnings.is_empty():
		parts.append("warning: %s" % String(warnings[0]))
	if parts.is_empty():
		return "no authored objective, guard, reward, route, or enemy-focus link found"
	return " | ".join(parts)

func _object_action_why_line(action: String, detail: Dictionary, preview: Dictionary, property_name: String) -> String:
	var taxonomy_value = detail.get("taxonomy", {})
	var taxonomy: Dictionary = taxonomy_value if taxonomy_value is Dictionary else {}
	var flags := _placement_role_flags(taxonomy) if not taxonomy.is_empty() else {}
	var preview_consequence := String(preview.get("authoring_consequence", "")).strip_edges()
	match action:
		"place":
			var guidance_value = detail.get("placement_guidance", {})
			var guidance: Dictionary = guidance_value if guidance_value is Dictionary else {}
			return preview_consequence if preview_consequence != "" else _placement_authoring_consequence(String(detail.get("kind", "")), String(detail.get("content_id", "")), taxonomy, guidance)
		"remove":
			if bool(flags.get("economy", false)):
				return "removes an economy/control source from route and objective planning."
			if bool(flags.get("neutral", false)):
				return "removes a battle gate or recruit/guard anchor from route planning."
			return "removes a reward, town, or route anchor from the authored map state."
		"move":
			return "keeps the placement id stable while changing terrain, road, town-distance, and dependency context."
		"duplicate":
			return "creates a fresh editor id with copied runtime properties; authored links still need deliberate targets."
		"retheme":
			return "keeps the placement id and links but changes object taxonomy, economy role, reward, or encounter identity."
		"edit_property":
			match property_name:
				PROPERTY_TOWN_OWNER:
					return "changes control state used by objectives, enemy focus, and town economy pressure."
				PROPERTY_COLLECTED:
					return "changes whether this reward/site appears and whether its economy value is already claimed."
				PROPERTY_ENCOUNTER_DIFFICULTY:
					return "changes battle pressure without moving the guard, route, or reward anchor."
			return "changes the working-copy runtime state for this authored object."
	return ""

func _object_action_next_check(action: String, detail: Dictionary, preview: Dictionary, property_name: String) -> String:
	var dependencies = detail.get("authoring_dependencies", {})
	var warnings: Array = dependencies.get("warnings", []) if dependencies is Dictionary else []
	if not warnings.is_empty():
		return String(warnings[0])
	if action in ["remove", "move", "retheme"] and dependencies is Dictionary and String(dependencies.get("summary", "")).strip_edges() != "":
		return "recheck linked objectives, guards, rewards, routes, and enemy focus in tile inspection."
	if action in ["place", "duplicate"]:
		var dependency_warning := String(preview.get("dependency_warning", "")).strip_edges()
		if dependency_warning != "":
			return "stabilize the placement id before adding objective, guard, reward, or enemy-focus links."
	var taxonomy_value = detail.get("taxonomy", {})
	var taxonomy: Dictionary = taxonomy_value if taxonomy_value is Dictionary else {}
	var flags := _placement_role_flags(taxonomy) if not taxonomy.is_empty() else {}
	if property_name == PROPERTY_TOWN_OWNER:
		return "check victory/defeat anchors and nearest enemy focus after the ownership change."
	if property_name == PROPERTY_COLLECTED:
		return "check live preview visibility and nearby route reward pacing."
	if property_name == PROPERTY_ENCOUNTER_DIFFICULTY:
		return "check guard pressure against the reward or route it blocks."
	if bool(flags.get("economy", false)) or bool(flags.get("transit", false)):
		return "check road contact, local density, nearest town ownership, and economy pacing."
	if bool(flags.get("neutral", false)):
		return "check guarded target/reward link and whether the route block is intentional."
	return "inspect the tile, density band, and dependency summary before saving author data."

func _compact_join_limited(lines: Array, limit: int) -> String:
	var compact := []
	for line_value in lines:
		var line := String(line_value).strip_edges()
		if line == "":
			continue
		compact.append(line)
		if compact.size() >= limit:
			break
	return " | ".join(compact)

func _editor_variant_text(value: Variant) -> String:
	if value == null:
		return ""
	if value is bool:
		return "true" if bool(value) else "false"
	return String(value)

func _placement_availability_for_selected_object(tile: Vector2i) -> Dictionary:
	if not _tile_in_bounds(tile):
		return {"can_place": false, "blocked_reason": "Target tile is outside the map."}
	if _selected_object_family == "" or _selected_object_content_id == "":
		return {"can_place": false, "blocked_reason": "Choose an object before placing."}
	if _object_content_lookup(_selected_object_family, _selected_object_content_id).is_empty():
		return {
			"can_place": false,
			"blocked_reason": "Unknown %s content id %s." % [_object_family_label(_selected_object_family), _selected_object_content_id],
		}
	if _selected_object_family == OBJECT_FAMILY_ARTIFACT and _artifact_content_id_exists(_selected_object_content_id):
		return {"can_place": false, "blocked_reason": "Artifact is already placed in this working copy."}
	var occupied_label := _first_placement_label_at_tile(tile)
	if occupied_label != "":
		return {
			"can_place": false,
			"blocked_reason": "Tile already has %s." % occupied_label,
		}
	return {"can_place": true, "blocked_reason": ""}

func _first_placement_label_at_tile(tile: Vector2i) -> String:
	if _session == null or not _tile_in_bounds(tile):
		return ""
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var placements = _session.overworld.get(_placement_array_key(family), [])
		if not (placements is Array):
			continue
		for placement in placements:
			if placement is Dictionary and _placement_at_tile(placement, tile):
				var placement_id := String(placement.get("placement_id", ""))
				return placement_id if placement_id != "" else family
	return ""

func _placement_context_lines(family: String, content_id: String, payload: Dictionary, tile: Vector2i) -> Array:
	var lines := []
	var terrain_context := _placement_terrain_context_line(tile)
	if terrain_context != "":
		lines.append(terrain_context)
	var faction_context := _placement_faction_context_line(family, content_id, tile)
	if faction_context != "":
		lines.append(faction_context)
	var economy_context := _placement_economy_context_line(family, content_id)
	if economy_context != "":
		lines.append(economy_context)
	var route_context := _placement_route_context_line(tile)
	if route_context != "":
		lines.append(route_context)
	var dependency_context := _placement_dependency_context_line(payload, tile)
	if dependency_context != "":
		lines.append(dependency_context)
	return lines

func _placement_terrain_context_line(tile: Vector2i) -> String:
	if not _tile_in_bounds(tile):
		return ""
	var terrain_id := _terrain_at(tile)
	var biome := ContentService.get_biome_for_terrain(terrain_id)
	var biome_name := String(biome.get("name", "Unknown biome"))
	var passable := bool(biome.get("passable", terrain_id != "water"))
	return "Terrain: %s / %s | passable %s" % [terrain_id, biome_name, "yes" if passable else "no"]

func _placement_faction_context_line(family: String, content_id: String, tile: Vector2i) -> String:
	if family == OBJECT_FAMILY_TOWN:
		var town := ContentService.get_town(content_id)
		var faction_id := String(town.get("faction_id", ""))
		var faction := ContentService.get_faction(faction_id)
		var faction_name := String(faction.get("name", faction_id))
		return "Faction: %s | %s" % [faction_name, String(town.get("strategic_role", "frontier")).capitalize()] if faction_name != "" else ""
	var nearest := _nearest_town_context(tile)
	if nearest.is_empty():
		return ""
	return "Faction: nearest %s (%s, %s) %d tiles" % [
		String(nearest.get("name", "town")),
		String(nearest.get("owner", "neutral")),
		String(nearest.get("faction_name", "")),
		int(nearest.get("distance", 0)),
	]

func _nearest_town_context(tile: Vector2i) -> Dictionary:
	if _session == null:
		return {}
	var best := {}
	var best_distance := 999999
	for town_placement in _session.overworld.get("towns", []):
		if not (town_placement is Dictionary):
			continue
		var town_tile := Vector2i(int(town_placement.get("x", 0)), int(town_placement.get("y", 0)))
		var distance: int = abs(town_tile.x - tile.x) + abs(town_tile.y - tile.y)
		if distance >= best_distance:
			continue
		var town := ContentService.get_town(String(town_placement.get("town_id", "")))
		var faction_id := String(town.get("faction_id", ""))
		var faction := ContentService.get_faction(faction_id)
		best_distance = distance
		best = {
			"name": String(town.get("name", town_placement.get("town_id", "town"))),
			"owner": String(town_placement.get("owner", "neutral")),
			"faction_name": String(faction.get("name", faction_id)),
			"distance": distance,
		}
	return best

func _placement_economy_context_line(family: String, content_id: String) -> String:
	match family:
		OBJECT_FAMILY_RESOURCE:
			var site := ContentService.get_resource_site(content_id)
			var parts := []
			var rewards = site.get("rewards", {})
			if rewards is Dictionary and not rewards.is_empty():
				parts.append("one-time %s" % _resource_delta_text(rewards))
			var claim_rewards = site.get("claim_rewards", {})
			if claim_rewards is Dictionary and not claim_rewards.is_empty():
				parts.append("claim %s" % _resource_delta_text(claim_rewards))
			var control_income = site.get("control_income", {})
			if control_income is Dictionary and not control_income.is_empty():
				parts.append("income %s/day" % _resource_delta_text(control_income))
			var weekly_recruits = site.get("weekly_recruits", {})
			if weekly_recruits is Dictionary and not weekly_recruits.is_empty():
				parts.append("weekly recruits %s" % _resource_delta_text(weekly_recruits))
			return "Economy: %s" % "; ".join(parts) if not parts.is_empty() else ""
		OBJECT_FAMILY_TOWN:
			var town := ContentService.get_town(content_id)
			var economy = town.get("economy", {})
			if economy is Dictionary:
				var base_income = economy.get("base_income", {})
				if base_income is Dictionary and not base_income.is_empty():
					return "Economy: town base %s/day" % _resource_delta_text(base_income)
		OBJECT_FAMILY_ENCOUNTER:
			var encounter := ContentService.get_encounter(content_id)
			var rewards = encounter.get("rewards", {})
			if rewards is Dictionary and not rewards.is_empty():
				return "Economy: battle reward %s" % _resource_delta_text(rewards)
		OBJECT_FAMILY_ARTIFACT:
			var artifact := ContentService.get_artifact(content_id)
			var slot := String(artifact.get("slot", "")).strip_edges()
			return "Economy: hero progression reward%s" % (" | slot %s" % _humanize_editor_id(slot) if slot != "" else "")
	return ""

func _placement_route_context_line(tile: Vector2i) -> String:
	if not _tile_in_bounds(tile):
		return ""
	if _has_road_at(tile):
		return "Route: on road %s" % ", ".join(_road_layer_ids_at(tile))
	var adjacent_roads := 0
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _tile_in_bounds(tile + offset) and _has_road_at(tile + offset):
			adjacent_roads += 1
	if adjacent_roads > 0:
		return "Route: adjacent to %d road tile%s" % [adjacent_roads, "" if adjacent_roads == 1 else "s"]
	return "Route: no immediate road contact"

func _placement_dependency_context_line(payload: Dictionary, tile: Vector2i) -> String:
	if _first_placement_label_at_tile(tile) != "":
		return "Dependency: inspect existing placement links before replacing this tile"
	var primary_class := String(payload.get("primary_class", ""))
	var flags := _placement_role_flags(payload)
	if primary_class in ["town", "neutral_encounter", "neutral_dwelling"] or bool(flags.get("transit", false)) or bool(flags.get("faction_landmark", false)):
		return "Dependency: new editor id starts unlinked until objectives, guards, rewards, or enemy focus target it"
	return "Dependency: no authored objective/guard link is created automatically"

func _placement_dependency_warning(payload: Dictionary) -> String:
	var primary_class := String(payload.get("primary_class", ""))
	var flags := _placement_role_flags(payload)
	if primary_class in ["town", "neutral_encounter"] or bool(flags.get("transit", false)) or bool(flags.get("faction_landmark", false)):
		return "Stable placement id needed before linking objectives, guards, rewards, or enemy focus."
	return ""

func _density_warning_for_guidance(guidance: Dictionary, can_place: bool) -> String:
	if guidance.is_empty() or not can_place:
		return ""
	var target := String(guidance.get("density_target", ""))
	var upper_bound := _density_target_upper_bound(target)
	if upper_bound <= 0:
		return ""
	var projected_count := int(guidance.get("local_density_count", 0)) + 1
	if projected_count > upper_bound:
		return "Density after placement is %d, above target %s." % [projected_count, target]
	if projected_count == upper_bound:
		return "Density after placement reaches target cap %s." % target
	return ""

func _density_target_upper_bound(target: String) -> int:
	var first_token := String(target.strip_edges().split(" ")[0]) if target.strip_edges() != "" else ""
	if first_token.find("-") < 0:
		return -1
	var range_parts := first_token.split("-")
	if range_parts.size() < 2:
		return -1
	return int(String(range_parts[1]))

func _placement_authoring_consequence(family: String, content_id: String, payload: Dictionary, guidance: Dictionary) -> String:
	var role := String(guidance.get("placement_role", _placement_role_label(payload, _placement_role_flags(payload))))
	match family:
		OBJECT_FAMILY_TOWN:
			return "creates a persistent town anchor for %s; authoring links must choose whether it is an objective, front, or enemy focus." % content_id
		OBJECT_FAMILY_RESOURCE:
			return "creates a %s site for %s; economy/control and route context update from this tile." % [role.to_lower(), content_id]
		OBJECT_FAMILY_ARTIFACT:
			return "creates a one-time hero progression reward for %s; collection removes it from the field." % content_id
		OBJECT_FAMILY_ENCOUNTER:
			return "creates a blocking battle threat for %s; use guard/reward links when it gates a lane or prize." % content_id
	return "creates a %s placement for %s." % [role.to_lower(), content_id]

func _placement_guidance_payload(payload: Dictionary, tile: Vector2i) -> Dictionary:
	if payload.is_empty():
		return {}
	var flags := _placement_role_flags(payload)
	var density := _density_guidance_for_payload(payload, flags)
	var density_group := String(density.get("group", ""))
	var local_count := 0
	var region := {}
	if _session != null and _tile_in_bounds(tile):
		local_count = _local_density_count(tile, density_group)
		region = _density_region_bounds(tile)
	var link_line := _taxonomy_link_line(payload)
	return {
		"placement_role": _placement_role_label(payload, flags),
		"role_flags": flags,
		"role_flags_text": _role_flags_text(flags),
		"density_group": density_group,
		"density_band": String(density.get("band", "")),
		"density_target": String(density.get("target", "")),
		"density_note": String(density.get("note", "")),
		"local_density_count": local_count,
		"local_density_region": region,
		"content_link": link_line,
	}

func _selected_tile_authoring_dependency_text() -> String:
	if _session == null or not _tile_in_bounds(_selected_tile):
		return ""
	var summaries := []
	for detail in _object_details_at(_selected_tile, false):
		if not (detail is Dictionary):
			continue
		var dependencies: Dictionary = detail.get("authoring_dependencies", {})
		var summary := String(dependencies.get("summary", "")).strip_edges()
		if summary != "" and summary not in summaries:
			summaries.append(summary)
		if summaries.size() >= 2:
			break
	if summaries.is_empty():
		var scenario_validation := _scenario_authoring_validation_payload()
		var missing_count := int(scenario_validation.get("missing_objective_anchor_count", 0))
		if missing_count > 0:
			return "Scenario warnings: %d missing objective anchor%s" % [
				missing_count,
				"" if missing_count == 1 else "s",
			]
		return ""
	return "Tile links: %s" % " | ".join(summaries)

func _authoring_dependencies_for_detail(detail: Dictionary) -> Dictionary:
	if _session == null or detail.is_empty():
		return {}
	var placement_id := String(detail.get("placement_id", ""))
	if placement_id == "":
		return {}
	var kind := String(detail.get("kind", ""))
	var content_id := String(detail.get("content_id", ""))
	var objective_links := _objective_links_for_placement(placement_id)
	var guard_links := _guard_links_for_placement(kind, placement_id, content_id)
	var route_links := _route_links_for_placement(kind, placement_id, content_id, guard_links)
	var reward_links := _reward_links_for_placement(placement_id, objective_links)
	var enemy_focus_links := _enemy_focus_links_for_placement(placement_id)
	var warnings := _authoring_warnings_for_detail(detail, objective_links, guard_links, reward_links, enemy_focus_links)
	var summary_parts := []
	if not objective_links.is_empty():
		summary_parts.append("objectives %d" % objective_links.size())
	if not guard_links.is_empty():
		summary_parts.append("guards %d" % guard_links.size())
	if not route_links.is_empty():
		summary_parts.append("routes %d" % route_links.size())
	if not reward_links.is_empty():
		summary_parts.append("rewards %d" % reward_links.size())
	if not enemy_focus_links.is_empty():
		summary_parts.append("enemy focus %d" % enemy_focus_links.size())
	if not warnings.is_empty():
		summary_parts.append("warnings %d" % warnings.size())
	return {
		"placement_id": placement_id,
		"kind": kind,
		"objective_links": objective_links,
		"guard_links": guard_links,
		"route_links": route_links,
		"reward_links": reward_links,
		"enemy_focus_links": enemy_focus_links,
		"warnings": warnings,
		"summary": " | ".join(summary_parts),
	}

func _objective_links_for_placement(placement_id: String) -> Array:
	var links := []
	var scenario := ContentService.get_scenario(_session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return links
	for bucket in ["victory", "defeat"]:
		var objective_bucket = objectives.get(bucket, [])
		if not (objective_bucket is Array):
			continue
		for objective in objective_bucket:
			if not (objective is Dictionary):
				continue
			if String(objective.get("placement_id", "")) != placement_id:
				continue
			links.append(
				{
					"id": String(objective.get("id", "")),
					"bucket": bucket,
					"type": String(objective.get("type", "")),
					"label": String(objective.get("label", objective.get("id", "Objective"))),
					"covered": _placement_id_exists(placement_id),
				}
			)
	return links

func _guard_links_for_placement(kind: String, placement_id: String, content_id: String) -> Array:
	var links := []
	for encounter in _session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		var guard := _guard_link_for_editor(encounter)
		if guard.is_empty():
			continue
		var source_placement_id := String(encounter.get("placement_id", ""))
		var target_placement_id := String(guard.get("target_placement_id", ""))
		var target_id := String(guard.get("target_id", ""))
		var target_kind := String(guard.get("target_kind", ""))
		var is_source := kind == OBJECT_FAMILY_ENCOUNTER and source_placement_id == placement_id
		var is_target := target_placement_id == placement_id or (target_placement_id == "" and target_id in [placement_id, content_id])
		if not is_source and not is_target:
			continue
		links.append(
			{
				"role": "guards" if is_source else "guarded_by",
				"guard_role": String(guard.get("guard_role", "")),
				"source_placement_id": source_placement_id,
				"source_label": _placement_label_for_editor(source_placement_id),
				"target_kind": target_kind,
				"target_id": target_id,
				"target_placement_id": target_placement_id,
				"target_label": _guard_target_label_for_editor(guard),
				"clear_required": bool(guard.get("clear_required_for_target", false)),
				"blocks_approach": bool(guard.get("blocks_approach", false)),
				"target_present": _guard_target_present_for_editor(guard),
			}
		)
	return links

func _route_links_for_placement(kind: String, placement_id: String, content_id: String, guard_links: Array) -> Array:
	var links := []
	for link in guard_links:
		if not (link is Dictionary):
			continue
		if String(link.get("target_kind", "")) == "route" or String(link.get("guard_role", "")).find("route") >= 0:
			links.append(
				{
					"route_id": String(link.get("target_id", "")),
					"source_placement_id": String(link.get("source_placement_id", "")),
					"role": String(link.get("role", "")),
					"blocks_approach": bool(link.get("blocks_approach", false)),
				}
			)
	if kind == OBJECT_FAMILY_RESOURCE:
		var site := ContentService.get_resource_site(content_id)
		var route_effect = site.get("transit_profile", {})
		if not (route_effect is Dictionary) or route_effect.is_empty():
			route_effect = site.get("route_effect", {})
		if route_effect is Dictionary and not route_effect.is_empty():
			links.append(
				{
					"route_id": String(route_effect.get("route_id", route_effect.get("route_role", ""))),
					"source_placement_id": placement_id,
					"role": String(route_effect.get("route_role", "route effect")),
					"blocks_approach": false,
				}
			)
	return links

func _reward_links_for_placement(placement_id: String, objective_links: Array) -> Array:
	var links := []
	var objective_ids := []
	for objective_link in objective_links:
		if objective_link is Dictionary:
			var objective_id := String(objective_link.get("id", ""))
			if objective_id != "":
				objective_ids.append(objective_id)
	var scenario := ContentService.get_scenario(_session.scenario_id)
	for hook in scenario.get("script_hooks", []):
		if not (hook is Dictionary):
			continue
		var hook_id := String(hook.get("id", ""))
		var gated_by_selected_objective := false
		for condition in hook.get("conditions", []):
			if condition is Dictionary and String(condition.get("objective_id", "")) in objective_ids:
				gated_by_selected_objective = true
				break
		for effect in hook.get("effects", []):
			if not (effect is Dictionary):
				continue
			var effect_type := String(effect.get("type", ""))
			var spawned = effect.get("placement", {})
			var spawned_placement_id := ""
			if spawned is Dictionary:
				spawned_placement_id = String(spawned.get("placement_id", ""))
			if spawned_placement_id == placement_id or (gated_by_selected_objective and effect_type in ["spawn_resource_node", "spawn_encounter", "add_resources", "award_experience", "town_add_recruits"]):
				links.append(
					{
						"hook_id": hook_id,
						"effect_type": effect_type,
						"placement_id": spawned_placement_id,
						"label": _effect_label_for_editor(effect),
						"gated_by_selected_objective": gated_by_selected_objective,
					}
				)
	return links

func _enemy_focus_links_for_placement(placement_id: String) -> Array:
	var links := []
	var scenario := ContentService.get_scenario(_session.scenario_id)
	for config in scenario.get("enemy_factions", []):
		if not (config is Dictionary):
			continue
		var faction_id := String(config.get("faction_id", ""))
		var label := String(config.get("label", ContentService.get_faction(faction_id).get("name", faction_id)))
		if String(config.get("siege_target_placement_id", "")) == placement_id:
			links.append({"faction_id": faction_id, "label": label, "role": "siege target"})
		var targets = config.get("priority_target_placement_ids", [])
		if targets is Array and placement_id in targets:
			links.append({"faction_id": faction_id, "label": label, "role": "priority target"})
	return links

func _authoring_warnings_for_detail(
	detail: Dictionary,
	objective_links: Array,
	guard_links: Array,
	reward_links: Array,
	enemy_focus_links: Array
) -> Array:
	var warnings := []
	var placement_id := String(detail.get("placement_id", ""))
	for link in guard_links:
		if not (link is Dictionary):
			continue
		if String(link.get("role", "")) == "guards" and not bool(link.get("target_present", false)):
			warnings.append("Guard target is missing: %s" % String(link.get("target_label", "target")))
	var kind := String(detail.get("kind", ""))
	var taxonomy = detail.get("taxonomy", {})
	var primary_class := String(taxonomy.get("primary_class", "")) if taxonomy is Dictionary else ""
	if kind == OBJECT_FAMILY_TOWN and objective_links.is_empty() and not enemy_focus_links.is_empty():
		warnings.append("Enemy focus has no matching scenario objective anchor.")
	if kind == OBJECT_FAMILY_ENCOUNTER and primary_class == "neutral_encounter" and objective_links.is_empty() and reward_links.is_empty() and not _guard_link_for_detail(detail).is_empty():
		warnings.append("Guard has no objective or reward hook tied to this placement.")
	if placement_id.begins_with("editor_") and (not objective_links.is_empty() or not guard_links.is_empty() or not enemy_focus_links.is_empty()):
		warnings.append("Editor placement id is linked; keep the id stable before saving author data.")
	return warnings

func _scenario_authoring_validation_payload() -> Dictionary:
	if _session == null:
		return {}
	var scenario := ContentService.get_scenario(_session.scenario_id)
	var placement_ids := _all_current_placement_ids()
	var objective_anchors := []
	var missing_objective_anchors := []
	var covered_objective_anchors := []
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		for bucket in ["victory", "defeat"]:
			var objective_bucket = objectives.get(bucket, [])
			if not (objective_bucket is Array):
				continue
			for objective in objective_bucket:
				if not (objective is Dictionary):
					continue
				var placement_id := String(objective.get("placement_id", ""))
				if placement_id == "":
					continue
				var entry := {
					"id": String(objective.get("id", "")),
					"bucket": bucket,
					"type": String(objective.get("type", "")),
					"placement_id": placement_id,
					"label": String(objective.get("label", objective.get("id", "Objective"))),
					"covered": placement_ids.has(placement_id),
				}
				objective_anchors.append(entry)
				if bool(entry.get("covered", false)):
					covered_objective_anchors.append(entry)
				else:
					missing_objective_anchors.append(entry)
	var guard_warnings := []
	for encounter in _session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		var guard := _guard_link_for_editor(encounter)
		if guard.is_empty() or String(guard.get("guard_role", "")) in ["", "none"]:
			continue
		if not _guard_target_present_for_editor(guard):
			guard_warnings.append(
				{
					"placement_id": String(encounter.get("placement_id", "")),
					"warning": "Guard target is missing: %s" % _guard_target_label_for_editor(guard),
				}
			)
	var warning_lines := []
	for missing in missing_objective_anchors:
		if missing is Dictionary:
			warning_lines.append("Missing objective anchor: %s" % String(missing.get("placement_id", "")))
	for warning in guard_warnings:
		if warning is Dictionary:
			warning_lines.append(String(warning.get("warning", "")))
	return {
		"objective_anchors": objective_anchors,
		"covered_objective_anchors": covered_objective_anchors,
		"missing_objective_anchors": missing_objective_anchors,
		"covered_objective_anchor_count": covered_objective_anchors.size(),
		"missing_objective_anchor_count": missing_objective_anchors.size(),
		"guard_warnings": guard_warnings,
		"warning_count": warning_lines.size(),
		"warnings": warning_lines,
		"summary": "Objectives %d/%d covered | Warnings %d" % [
			covered_objective_anchors.size(),
			objective_anchors.size(),
			warning_lines.size(),
		],
	}

func _all_current_placement_ids() -> Dictionary:
	var ids := {}
	if _session == null:
		return ids
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var placements = _session.overworld.get(_placement_array_key(family), [])
		if not (placements is Array):
			continue
		for placement in placements:
			if placement is Dictionary:
				var placement_id := String(placement.get("placement_id", ""))
				if placement_id != "":
					ids[placement_id] = true
	return ids

func _guard_link_for_detail(detail: Dictionary) -> Dictionary:
	if String(detail.get("kind", "")) != OBJECT_FAMILY_ENCOUNTER:
		return {}
	var placement_id := String(detail.get("placement_id", ""))
	for encounter in _session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return _guard_link_for_editor(encounter)
	return {}

func _guard_link_for_editor(encounter: Dictionary) -> Dictionary:
	var guard = encounter.get("guard_link", {})
	if guard is Dictionary and not guard.is_empty():
		return guard
	var metadata = encounter.get("neutral_encounter", {})
	if metadata is Dictionary:
		guard = metadata.get("guard_link", {})
		if guard is Dictionary:
			return guard
	var map_object := ContentService.get_map_object(String(encounter.get("object_id", "")))
	metadata = map_object.get("neutral_encounter", {})
	if metadata is Dictionary:
		guard = metadata.get("guard_link", {})
		if guard is Dictionary:
			return guard
	return {}

func _guard_target_present_for_editor(guard: Dictionary) -> bool:
	var target_kind := String(guard.get("target_kind", ""))
	if target_kind == "route":
		return String(guard.get("target_id", "")) != ""
	var target_placement_id := String(guard.get("target_placement_id", ""))
	if target_placement_id != "":
		return _placement_id_exists(target_placement_id)
	var target_id := String(guard.get("target_id", ""))
	if target_id == "":
		return false
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var placements = _session.overworld.get(_placement_array_key(family), [])
		if not (placements is Array):
			continue
		var content_key := _placement_content_key(family)
		for placement in placements:
			if not (placement is Dictionary):
				continue
			if String(placement.get("placement_id", "")) == target_id or (content_key != "" and String(placement.get(content_key, "")) == target_id):
				return true
	return false

func _guard_target_label_for_editor(guard: Dictionary) -> String:
	var target_placement_id := String(guard.get("target_placement_id", ""))
	if target_placement_id != "":
		return _placement_label_for_editor(target_placement_id)
	var target_id := String(guard.get("target_id", ""))
	if target_id == "":
		return _humanize_editor_id(String(guard.get("target_kind", "target")))
	if String(guard.get("target_kind", "")) == "route":
		return "route %s" % target_id
	var placement_label := _placement_label_for_editor(target_id)
	return placement_label if placement_label != "" else target_id

func _placement_label_for_editor(placement_id: String) -> String:
	if placement_id == "":
		return ""
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var placements = _session.overworld.get(_placement_array_key(family), []) if _session != null else []
		if not (placements is Array):
			continue
		for placement in placements:
			if placement is Dictionary and String(placement.get("placement_id", "")) == placement_id:
				var detail := _object_detail_for_placement(family, placement)
				var name := String(detail.get("name", ""))
				return "%s (%s)" % [name, placement_id] if name != "" else placement_id
	return _humanize_editor_id(placement_id)

func _effect_label_for_editor(effect: Dictionary) -> String:
	var effect_type := String(effect.get("type", ""))
	match effect_type:
		"spawn_resource_node":
			var placement = effect.get("placement", {})
			if placement is Dictionary:
				var site := ContentService.get_resource_site(String(placement.get("site_id", "")))
				return "spawns %s" % String(site.get("name", placement.get("placement_id", "resource")))
		"spawn_encounter":
			var encounter_placement = effect.get("placement", {})
			if encounter_placement is Dictionary:
				var encounter := ContentService.get_encounter(String(encounter_placement.get("encounter_id", "")))
				return "spawns %s" % String(encounter.get("name", encounter_placement.get("placement_id", "encounter")))
		"add_resources":
			var resources = effect.get("resources", {})
			return "grants %s" % _resource_delta_text(resources) if resources is Dictionary else "grants resources"
		"award_experience":
			return "grants +%d experience" % int(effect.get("amount", 0))
		"town_add_recruits":
			return "adds recruits to %s" % _placement_label_for_editor(String(effect.get("placement_id", "")))
	return _humanize_editor_id(effect_type)

func _placement_role_flags(payload: Dictionary) -> Dictionary:
	var primary_class := String(payload.get("primary_class", "")).strip_edges()
	var object_family := String(payload.get("object_family", "")).strip_edges()
	var site_family := String(payload.get("site_family", "")).strip_edges()
	var tags := _string_array_for_editor(payload.get("secondary_tags", []))
	var economy := primary_class in ["persistent_economy_site", "mine", "resource_front"]
	economy = economy or site_family == "mine" or "resource_front" in tags or "income" in tags or "build_resource" in tags
	var reward := primary_class in ["pickup", "artifact_reward", "guarded_reward_site"]
	reward = reward or "small_reward" in tags or "guarded_reward" in tags or "hero_progression" in tags
	var transit := primary_class in ["transit_route_object", "transit_object"]
	transit = transit or site_family == "transit_object" or "road_control" in tags or "conditional_route" in tags or "water_route_control" in tags
	var neutral := primary_class in ["neutral_dwelling", "neutral_encounter"]
	neutral = neutral or object_family in ["neutral_dwelling", "neutral_encounter"] or site_family == "neutral_dwelling" or "neutral_recruit_source" in tags
	var faction_landmark := primary_class == "faction_landmark"
	faction_landmark = faction_landmark or site_family == "faction_outpost" or "faction_pressure" in tags or "faction_presence" in tags
	return {
		"economy": economy,
		"reward": reward,
		"transit": transit,
		"neutral": neutral,
		"faction_landmark": faction_landmark,
	}

func _role_flags_text(flags: Dictionary) -> String:
	var labels := []
	if bool(flags.get("economy", false)):
		labels.append("economy")
	if bool(flags.get("reward", false)):
		labels.append("reward")
	if bool(flags.get("transit", false)):
		labels.append("transit")
	if bool(flags.get("neutral", false)):
		labels.append("neutral")
	if bool(flags.get("faction_landmark", false)):
		labels.append("faction landmark")
	return ", ".join(labels) if not labels.is_empty() else "general"

func _placement_role_label(payload: Dictionary, flags: Dictionary) -> String:
	var primary_class := String(payload.get("primary_class", "")).strip_edges()
	if primary_class == "town":
		return "Town anchor"
	if primary_class == "neutral_dwelling":
		return "Neutral recruit source"
	if primary_class == "neutral_encounter":
		return "Guard or route threat"
	if bool(flags.get("transit", false)) and bool(flags.get("economy", false)):
		return "Route/economy control"
	if bool(flags.get("transit", false)):
		return "Route control"
	if bool(flags.get("faction_landmark", false)):
		return "Faction landmark"
	if bool(flags.get("economy", false)) and bool(flags.get("reward", false)):
		return "Resource reward pacing"
	if bool(flags.get("economy", false)):
		return "Economy pressure"
	if bool(flags.get("reward", false)):
		return "Reward pacing"
	return _humanize_editor_id(primary_class)

func _density_guidance_for_payload(payload: Dictionary, flags: Dictionary) -> Dictionary:
	var primary_class := String(payload.get("primary_class", "")).strip_edges()
	var site_family := String(payload.get("site_family", "")).strip_edges()
	if primary_class == "town":
		return {"group": "town_anchor", "band": "town_influence", "target": "leave town breathing room", "note": "Keep nearby lanes and approach tiles readable."}
	if primary_class == "neutral_encounter":
		return {"group": "guard_encounter", "band": "standard_adventure", "target": "2-4 guards/encounters per 16x16", "note": "Use to guard lanes, rewards, or territory without hiding the target."}
	if primary_class == "guarded_reward_site":
		return {"group": "guarded_reward", "band": "ruin_reward_pocket", "target": "2-4 guarded sites per 16x16", "note": "Pair with visible danger and clear reward category."}
	if primary_class == "neutral_dwelling" or site_family == "neutral_dwelling":
		return {"group": "interactable", "band": "standard_adventure", "target": "3-5 interactables per 16x16", "note": "Leave gate/approach space and show recruit-source identity."}
	if bool(flags.get("transit", false)) or site_family == "transit_object":
		return {"group": "economy_transit", "band": "contested_economy", "target": "4-7 economy/transit sites per 16x16", "note": "Place on junctions, chokepoints, or route alternatives."}
	if bool(flags.get("faction_landmark", false)):
		return {"group": "faction_landmark", "band": "town_influence", "target": "1-3 landmarks per 16x16", "note": "Use near faction fronts or territory identity pockets."}
	if bool(flags.get("economy", false)) and not bool(flags.get("reward", false)):
		return {"group": "economy_transit", "band": "contested_economy", "target": "4-7 economy/transit sites per 16x16", "note": "Make resource fronts contestable and route-visible."}
	if bool(flags.get("reward", false)):
		return {"group": "pickup_reward", "band": "standard_adventure", "target": "4-7 pickups/rewards per 16x16", "note": "Use on side routes and reward pockets; keep main lanes legible."}
	return {"group": "interactable", "band": "standard_adventure", "target": "3-5 interactables per 16x16", "note": "Mix with scenery and negative space instead of uniform scatter."}

func _local_density_count(tile: Vector2i, density_group: String) -> int:
	if density_group == "" or _session == null:
		return 0
	var bounds := _density_region_bounds(tile)
	var count := 0
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var placements = _session.overworld.get(_placement_array_key(family), [])
		if not (placements is Array):
			continue
		for placement in placements:
			if not (placement is Dictionary):
				continue
			var object_tile := Vector2i(int(placement.get("x", -999)), int(placement.get("y", -999)))
			if object_tile.x < int(bounds.get("min_x", 0)) or object_tile.x > int(bounds.get("max_x", 0)):
				continue
			if object_tile.y < int(bounds.get("min_y", 0)) or object_tile.y > int(bounds.get("max_y", 0)):
				continue
			if _density_group_for_placement(family, placement) == density_group:
				count += 1
	return count

func _density_region_bounds(tile: Vector2i) -> Dictionary:
	var map_size := OverworldRules.derive_map_size(_session) if _session != null else Vector2i.ZERO
	var min_x := int(floor(float(tile.x) / float(EDITOR_DENSITY_REGION_SIZE))) * EDITOR_DENSITY_REGION_SIZE
	var min_y := int(floor(float(tile.y) / float(EDITOR_DENSITY_REGION_SIZE))) * EDITOR_DENSITY_REGION_SIZE
	return {
		"min_x": min_x,
		"min_y": min_y,
		"max_x": min(map_size.x - 1, min_x + EDITOR_DENSITY_REGION_SIZE - 1),
		"max_y": min(map_size.y - 1, min_y + EDITOR_DENSITY_REGION_SIZE - 1),
		"size": EDITOR_DENSITY_REGION_SIZE,
	}

func _density_group_for_placement(family: String, placement: Dictionary) -> String:
	match family:
		OBJECT_FAMILY_TOWN:
			return "town_anchor"
		OBJECT_FAMILY_ARTIFACT:
			return "pickup_reward"
		OBJECT_FAMILY_RESOURCE:
			var site := ContentService.get_resource_site(String(placement.get("site_id", "")))
			var site_id := String(site.get("id", placement.get("site_id", "")))
			var map_object := ContentService.get_map_object_for_resource_site(site_id)
			var primary_class := String(map_object.get("primary_class", "")).strip_edges()
			if primary_class == "":
				primary_class = _fallback_resource_primary_class(site)
			var secondary_tags := _string_array_for_editor(map_object.get("secondary_tags", []))
			if secondary_tags.is_empty():
				secondary_tags = _string_array_for_editor(map_object.get("map_roles", []))
			if secondary_tags.is_empty():
				secondary_tags = _fallback_resource_tags(site)
			var payload := {
				"primary_class": primary_class,
				"secondary_tags": secondary_tags,
				"object_family": String(map_object.get("family", site.get("family", ""))),
				"site_family": String(site.get("family", "")),
			}
			return String(_density_guidance_for_payload(payload, _placement_role_flags(payload)).get("group", ""))
		OBJECT_FAMILY_ENCOUNTER:
			var map_object := ContentService.get_map_object(String(placement.get("object_id", "")))
			var neutral_metadata = placement.get("neutral_encounter", {})
			if not (neutral_metadata is Dictionary) or neutral_metadata.is_empty():
				neutral_metadata = map_object.get("neutral_encounter", {})
			if not (neutral_metadata is Dictionary):
				neutral_metadata = {}
			var primary_class := String(map_object.get("primary_class", placement.get("primary_class", ""))).strip_edges()
			if primary_class == "":
				primary_class = String(neutral_metadata.get("primary_class", "neutral_encounter")).strip_edges()
			var tags := _string_array_for_editor(map_object.get("secondary_tags", []))
			if tags.is_empty():
				tags = _string_array_for_editor(neutral_metadata.get("secondary_tags", []))
			var payload := {
				"primary_class": primary_class,
				"secondary_tags": tags,
				"object_family": String(map_object.get("family", "neutral_encounter")),
			}
			return String(_density_guidance_for_payload(payload, _placement_role_flags(payload)).get("group", ""))
		_:
			return ""

func _fallback_resource_primary_class(site: Dictionary) -> String:
	if bool(site.get("persistent_control", false)):
		match String(site.get("family", "")):
			"neutral_dwelling":
				return "neutral_dwelling"
			"transit_object":
				return "transit_route_object"
			"guarded_reward_site":
				return "guarded_reward_site"
			_:
				return "persistent_economy_site"
	if bool(site.get("repeatable", false)):
		return "interactable_site"
	match String(site.get("family", "")):
		"guarded_reward_site":
			return "guarded_reward_site"
		"transit_object":
			return "transit_route_object"
		_:
			return "pickup"

func _fallback_resource_tags(site: Dictionary) -> Array:
	match String(site.get("family", "")):
		"mine":
			return ["resource_front", "income"]
		"neutral_dwelling":
			return ["neutral_recruit_source", "weekly_muster"]
		"faction_outpost":
			return ["faction_pressure", "road_control"]
		"frontier_shrine":
			return ["spell_access", "recovery"]
		"scouting_structure":
			return ["sightline", "scouting"]
		"transit_object":
			return ["conditional_route", "road_control"]
		"guarded_reward_site":
			return ["guarded_reward"]
		"repeatable_service":
			return ["recovery", "market"]
		_:
			return ["small_reward", "route_pacing"]

func _fallback_resource_cadence(site: Dictionary) -> String:
	if bool(site.get("persistent_control", false)):
		return "persistent_control"
	if bool(site.get("repeatable", false)):
		return "repeatable"
	return "one_time"

func _fallback_passability_class(map_object: Dictionary, family: String) -> String:
	if map_object.is_empty():
		match family:
			"", "one_shot_pickup", "pickup":
				return "passable_visit_on_enter"
			"transit_object":
				return "conditional_pass"
			"blocker":
				return "blocking_non_visitable"
			_:
				return "blocking_visitable"
	if bool(map_object.get("passable", false)) and bool(map_object.get("visitable", false)):
		return "passable_visit_on_enter"
	if bool(map_object.get("passable", false)):
		return "passable_scenic"
	if bool(map_object.get("visitable", false)):
		return "conditional_pass" if family == "transit_object" else "blocking_visitable"
	return "blocking_non_visitable"

func _fallback_encounter_role(tags: Array) -> String:
	if "guarded_reward" in tags:
		return "guard_linked_stack"
	if "route_block" in tags or "route_pacing" in tags:
		return "visible_stack"
	if "camp_anchor" in tags:
		return "camp_anchor"
	return "visible_stack"

func _risk_from_difficulty(difficulty: String) -> String:
	match difficulty:
		"low":
			return "light"
		"high":
			return "heavy"
		"pressure", "scripted":
			return difficulty
		_:
			return "standard"

func _encounter_detail_summary(encounter: Dictionary, placement: Dictionary, risk: String, role: String, guard: Dictionary) -> String:
	var parts := []
	parts.append("Role %s" % _humanize_editor_id(role))
	parts.append("Risk %s" % _humanize_editor_id(risk))
	var difficulty := String(placement.get("difficulty", "")).strip_edges()
	if difficulty != "":
		parts.append("Difficulty %s" % _humanize_editor_id(difficulty))
	var rewards = encounter.get("rewards", {})
	if rewards is Dictionary and not rewards.is_empty():
		parts.append("Reward %s" % _resource_delta_text(rewards))
	var guard_role := String(guard.get("guard_role", "")).strip_edges()
	if guard_role != "":
		var target := String(guard.get("target_placement_id", guard.get("target_id", ""))).strip_edges()
		parts.append("Guard %s%s" % [_humanize_editor_id(guard_role), " -> %s" % target if target != "" else ""])
	return " | ".join(parts)

func _footprint_summary(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var footprint: Dictionary = value
	var width: int = max(1, int(footprint.get("width", 1)))
	var height: int = max(1, int(footprint.get("height", 1)))
	var tier := String(footprint.get("tier", "")).strip_edges()
	if tier != "":
		return "%dx%d %s" % [width, height, _humanize_editor_id(tier)]
	return "%dx%d" % [width, height]

func _tag_summary_for_editor(value: Variant, limit: int) -> String:
	var tags := _string_array_for_editor(value)
	var labels := []
	for tag in tags:
		labels.append(_humanize_editor_id(tag))
		if labels.size() >= limit:
			break
	if tags.size() > labels.size():
		labels.append("+%d" % (tags.size() - labels.size()))
	return ", ".join(labels)

func _string_array_for_editor(value: Variant) -> Array:
	var strings := []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in strings:
				strings.append(text)
	return strings

func _humanize_editor_id(value: String) -> String:
	var normalized := value.strip_edges().replace("_", " ").replace("-", " ")
	if normalized == "":
		return ""
	var words := []
	for word_value in normalized.split(" ", false):
		var word := String(word_value).strip_edges()
		if word == "":
			continue
		words.append(word.left(1).to_upper() + word.substr(1).to_lower())
	return " ".join(words)

func _resource_delta_text(resources: Dictionary) -> String:
	var parts := []
	for key in resources.keys():
		var amount := int(resources[key])
		if amount == 0:
			continue
		parts.append("%+d %s" % [amount, _humanize_editor_id(String(key))])
	return ", ".join(parts)

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
	_select_scenario_picker_by_id(scenario_id)
	_selected_tile = OverworldRules.hero_position(_session)
	_selected_property_object_key = ""
	_pending_move_object_key = ""
	_pending_duplicate_object_key = ""
	_pending_terrain_line_start = Vector2i(-1, -1)
	_pending_road_path_start = Vector2i(-1, -1)
	_terrain_paint_order = 0
	_dirty = false
	_restored_from_play_copy = false
	_last_message = "Loaded authored scenario into a mutable editor working copy."
	_refresh_state()
	return true

func _resume_working_copy_from_memory(session) -> bool:
	if session == null or session.scenario_id == "":
		return false
	_session = session
	OverworldRules.normalize_overworld_state(_session)
	_make_all_tiles_visible(_session)
	_selected_scenario_id = _session.scenario_id
	_select_scenario_picker_by_id(_selected_scenario_id)
	_restore_editor_ui_metadata()
	_restored_from_play_copy = true
	_last_message = "Returned from Play Copy with the editor launch snapshot still in memory."
	_refresh_state()
	return true

func _restore_editor_ui_metadata() -> void:
	var selected_tile_value = _session.flags.get("editor_selected_tile", {})
	if selected_tile_value is Dictionary:
		_selected_tile = Vector2i(
			int(selected_tile_value.get("x", OverworldRules.hero_position(_session).x)),
			int(selected_tile_value.get("y", OverworldRules.hero_position(_session).y))
		)
	else:
		_selected_tile = OverworldRules.hero_position(_session)
	if not _tile_in_bounds(_selected_tile):
		_selected_tile = OverworldRules.hero_position(_session)
	var restored_terrain_id := String(_session.flags.get("editor_selected_terrain_id", _selected_terrain_id))
	if not _select_terrain_by_id(restored_terrain_id):
		_select_terrain_by_id(DEFAULT_TERRAIN_ID)
	var restored_family := String(_session.flags.get("editor_selected_object_family", _selected_object_family))
	if _select_object_family_by_id(restored_family):
		var restored_content_id := String(_session.flags.get("editor_selected_object_content_id", _selected_object_content_id))
		if restored_content_id != "":
			_select_object_content_by_id(restored_content_id)
	_selected_property_object_key = String(_session.flags.get("editor_selected_property_object_key", ""))
	_pending_move_object_key = String(_session.flags.get("editor_pending_move_object_key", ""))
	_pending_duplicate_object_key = String(_session.flags.get("editor_pending_duplicate_object_key", ""))
	var pending_terrain_line_value = _session.flags.get("editor_pending_terrain_line_start", {})
	if pending_terrain_line_value is Dictionary:
		_pending_terrain_line_start = Vector2i(
			int(pending_terrain_line_value.get("x", -1)),
			int(pending_terrain_line_value.get("y", -1))
		)
	else:
		_pending_terrain_line_start = Vector2i(-1, -1)
	if not _tile_in_bounds(_pending_terrain_line_start):
		_pending_terrain_line_start = Vector2i(-1, -1)
	var pending_terrain_rectangle_value = _session.flags.get("editor_pending_terrain_rectangle_corner", {})
	if pending_terrain_rectangle_value is Dictionary:
		_pending_terrain_rectangle_corner = Vector2i(
			int(pending_terrain_rectangle_value.get("x", -1)),
			int(pending_terrain_rectangle_value.get("y", -1))
		)
	else:
		_pending_terrain_rectangle_corner = Vector2i(-1, -1)
	if not _tile_in_bounds(_pending_terrain_rectangle_corner):
		_pending_terrain_rectangle_corner = Vector2i(-1, -1)
	var pending_road_path_value = _session.flags.get("editor_pending_road_path_start", {})
	if pending_road_path_value is Dictionary:
		_pending_road_path_start = Vector2i(
			int(pending_road_path_value.get("x", -1)),
			int(pending_road_path_value.get("y", -1))
		)
	else:
		_pending_road_path_start = Vector2i(-1, -1)
	if not _tile_in_bounds(_pending_road_path_start):
		_pending_road_path_start = Vector2i(-1, -1)
	_dirty = bool(_session.flags.get("editor_dirty", true))
	_terrain_paint_order = 0

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
	_sync_property_controls()
	_sync_object_taxonomy_summary()
	_sync_play_handoff_surface()
	_sync_preview()
	_refresh_labels()

func _sync_play_handoff_surface() -> void:
	if _play_button == null:
		return
	var handoff := _editor_play_handoff_payload()
	var gate := _editor_play_readiness_gate_payload()
	_play_button.disabled = _session == null
	_play_button.text = String(gate.get("button_label", handoff.get("button_label", "Play Copy")))
	var tooltip_lines := []
	var gate_text := String(gate.get("text", "")).strip_edges()
	if gate_text != "":
		tooltip_lines.append(gate_text)
	var handoff_tooltip := String(handoff.get("tooltip", "")).strip_edges()
	if handoff_tooltip != "":
		tooltip_lines.append(handoff_tooltip)
	var return_context := _editor_play_return_context_payload()
	var return_tooltip := String(return_context.get("tooltip", "")).strip_edges()
	if return_tooltip != "":
		tooltip_lines.append(return_tooltip)
	_play_button.tooltip_text = "\n".join(tooltip_lines) if not tooltip_lines.is_empty() else "Load a scenario working copy before play-testing it."

func _sync_object_taxonomy_summary() -> void:
	if _object_taxonomy_summary_label == null:
		return
	var payload := _object_content_taxonomy_payload(_selected_object_family, _selected_object_content_id)
	var guidance := _placement_guidance_payload(payload, _selected_tile)
	var text := _object_palette_guidance_text(payload, guidance)
	if text == "":
		text = "Choose an object to see taxonomy, placement role, density, and links."
	_set_compact_label(_object_taxonomy_summary_label, text, 4)
	_object_content_picker.tooltip_text = text

func _sync_preview() -> void:
	if _session == null or _map_view == null:
		return
	var map_size := OverworldRules.derive_map_size(_session)
	var map_data: Array = _session.overworld.get("map", [])
	_map_view.set_map_state(_session, map_data, map_size, _selected_tile)
	_map_view.tooltip_text = String(_editor_active_tool_cue_payload().get("tooltip", ""))

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
		_terrain_label_for_id(_selected_terrain_id),
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
	var authoring_validation := _scenario_authoring_validation_payload()
	var authoring_warning_count := int(authoring_validation.get("warning_count", 0))
	if authoring_warning_count > 0:
		state_line = "%s | Authoring warnings %d" % [state_line, authoring_warning_count]
	if _pending_move_object_key != "":
		var pending_detail := _object_detail_by_key(_pending_move_object_key)
		state_line = "%s | Move %s" % [
			state_line,
			String(pending_detail.get("placement_id", _pending_move_object_key)),
		]
	if _pending_duplicate_object_key != "":
		var pending_duplicate_detail := _object_detail_by_key(_pending_duplicate_object_key)
		state_line = "%s | Duplicate %s" % [
			state_line,
			String(pending_duplicate_detail.get("placement_id", _pending_duplicate_object_key)),
		]
	if _has_pending_terrain_line_start():
		state_line = "%s | Terrain line start %d,%d" % [
			state_line,
			_pending_terrain_line_start.x,
			_pending_terrain_line_start.y,
		]
	if _has_pending_terrain_rectangle_corner():
		state_line = "%s | Terrain rectangle corner %d,%d" % [
			state_line,
			_pending_terrain_rectangle_corner.x,
			_pending_terrain_rectangle_corner.y,
		]
	if _has_pending_road_path_start():
		state_line = "%s | Road path start %d,%d" % [
			state_line,
			_pending_road_path_start.x,
			_pending_road_path_start.y,
		]
	var status_lines := [state_line]
	var active_tool_text := String(_editor_active_tool_cue_payload().get("text", "")).strip_edges()
	if active_tool_text != "":
		status_lines.append(active_tool_text)
	var return_context_text := String(_editor_play_return_context_payload().get("text", "")).strip_edges()
	if return_context_text != "":
		status_lines.append(return_context_text)
	var play_readiness_text := String(_editor_play_readiness_gate_payload().get("text", "")).strip_edges()
	if play_readiness_text != "":
		status_lines.append(play_readiness_text)
	var play_handoff_text := String(_editor_play_handoff_payload().get("text", "")).strip_edges()
	if play_handoff_text != "":
		status_lines.append(play_handoff_text)
	var cue_text := String(_editor_acceptance_cue_payload().get("text", "")).strip_edges()
	if cue_text != "":
		status_lines.append(cue_text)
	if _last_message != "":
		status_lines.append(_last_message)
	_set_compact_label(_status_label, "\n".join(status_lines), 4)
	_set_compact_label(_tile_info_label, _tile_inspection_text(_selected_tile), 12)

func _tool_label(tool: String) -> String:
	match tool:
		TOOL_TERRAIN:
			return "Terrain"
		TOOL_TERRAIN_LINE:
			return "Terrain Line"
		TOOL_TERRAIN_RECTANGLE:
			return "Terrain Rect"
		TOOL_ROAD:
			return "Road"
		TOOL_ROAD_PATH:
			return "Road Path"
		TOOL_HERO_START:
			return "Hero Start"
		TOOL_PLACE_OBJECT:
			return "Place Object"
		TOOL_REMOVE_OBJECT:
			return "Remove Object"
		TOOL_MOVE_OBJECT:
			return "Move Object"
		TOOL_DUPLICATE_OBJECT:
			return "Duplicate Object"
		TOOL_RETHEME_OBJECT:
			return "Retheme Object"
		_:
			return "Inspect"

func _select_tool(tool: String) -> void:
	var valid_tools := [
		TOOL_INSPECT,
		TOOL_TERRAIN,
		TOOL_TERRAIN_LINE,
		TOOL_TERRAIN_RECTANGLE,
		TOOL_ROAD,
		TOOL_ROAD_PATH,
		TOOL_HERO_START,
		TOOL_PLACE_OBJECT,
		TOOL_REMOVE_OBJECT,
		TOOL_MOVE_OBJECT,
		TOOL_DUPLICATE_OBJECT,
		TOOL_RETHEME_OBJECT,
	]
	_tool = tool if tool in valid_tools else TOOL_INSPECT
	if _tool != TOOL_MOVE_OBJECT:
		_pending_move_object_key = ""
	if _tool != TOOL_DUPLICATE_OBJECT:
		_pending_duplicate_object_key = ""
	if _tool != TOOL_TERRAIN_LINE:
		_pending_terrain_line_start = Vector2i(-1, -1)
	if _tool != TOOL_TERRAIN_RECTANGLE:
		_pending_terrain_rectangle_corner = Vector2i(-1, -1)
	if _tool != TOOL_ROAD_PATH:
		_pending_road_path_start = Vector2i(-1, -1)
	_sync_tool_buttons()
	_sync_object_taxonomy_summary()
	_refresh_labels()

func _sync_tool_buttons() -> void:
	var buttons := {
		TOOL_INSPECT: _inspect_tool_button,
		TOOL_TERRAIN: _terrain_tool_button,
		TOOL_TERRAIN_LINE: _terrain_line_tool_button,
		TOOL_TERRAIN_RECTANGLE: _terrain_rectangle_tool_button,
		TOOL_ROAD: _road_tool_button,
		TOOL_ROAD_PATH: _road_path_tool_button,
		TOOL_HERO_START: _hero_start_tool_button,
		TOOL_PLACE_OBJECT: _place_object_tool_button,
		TOOL_REMOVE_OBJECT: _remove_object_tool_button,
		TOOL_MOVE_OBJECT: _move_object_tool_button,
		TOOL_DUPLICATE_OBJECT: _duplicate_object_tool_button,
		TOOL_RETHEME_OBJECT: _retheme_object_tool_button,
	}
	for tool_id in buttons.keys():
		var button: Button = buttons[tool_id]
		if button == null:
			continue
		button.button_pressed = tool_id == _tool
		button.tooltip_text = String(_editor_active_tool_cue_payload(String(tool_id)).get("tooltip", _tool_label(String(tool_id))))

func _on_scenario_selected(index: int) -> void:
	if index < 0 or index >= _scenario_picker.get_item_count():
		return
	var scenario_id := String(_scenario_picker.get_item_metadata(index))
	_load_scenario_working_copy(scenario_id)

func _on_terrain_selected(index: int) -> void:
	if index < 0 or index >= _terrain_picker.get_item_count():
		return
	_selected_terrain_id = String(_terrain_picker.get_item_metadata(index))
	var terrain_tool := _tool if _tool in [TOOL_TERRAIN_LINE, TOOL_TERRAIN_RECTANGLE] else TOOL_TERRAIN
	_select_tool(terrain_tool)
	_last_message = "Terrain brush set to %s." % _terrain_label_for_id(_selected_terrain_id)
	_refresh_state()

func _on_object_family_selected(index: int) -> void:
	if index < 0 or index >= _object_family_picker.get_item_count():
		return
	_selected_object_family = String(_object_family_picker.get_item_metadata(index))
	_selected_object_content_id = ""
	_rebuild_object_content_picker()
	_select_tool(TOOL_RETHEME_OBJECT if _tool == TOOL_RETHEME_OBJECT else TOOL_PLACE_OBJECT)
	_last_message = "Object family set to %s." % _object_family_label(_selected_object_family)
	_refresh_state()

func _on_object_content_selected(index: int) -> void:
	if index < 0 or index >= _object_content_picker.get_item_count():
		return
	_selected_object_content_id = String(_object_content_picker.get_item_metadata(index))
	_select_tool(TOOL_RETHEME_OBJECT if _tool == TOOL_RETHEME_OBJECT else TOOL_PLACE_OBJECT)
	_last_message = "Object palette set to %s." % _selected_object_content_id
	_refresh_state()

func _on_selected_property_object_selected(index: int) -> void:
	if index < 0 or index >= _selected_object_picker.get_item_count():
		return
	_selected_property_object_key = String(_selected_object_picker.get_item_metadata(index))
	_last_message = "Selected runtime properties for %s." % _selected_property_object_key
	_refresh_state()

func _on_apply_object_properties_pressed() -> void:
	var detail := _selected_property_object_detail()
	if detail.is_empty():
		_last_message = "Select a supported overworld object before editing properties."
		_refresh_state()
		return
	var property_name := _primary_editable_property_for_kind(String(detail.get("kind", "")))
	var previous_value: Variant = null
	if property_name != "":
		previous_value = detail.get(property_name, null)
	var result := _apply_selected_object_properties(detail)
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
		var after_detail := _object_detail_by_key(String(detail.get("property_key", "")))
		var tile := Vector2i(int(detail.get("x", _selected_tile.x)), int(detail.get("y", _selected_tile.y)))
		var new_value: Variant = null
		if property_name != "":
			new_value = after_detail.get(property_name, null)
		_set_object_authoring_recap(
			"edit_property",
			bool(result.get("changed", false)),
			detail,
			after_detail,
			tile,
			tile,
			{},
			property_name,
			previous_value,
			new_value
		)
	else:
		_last_message = String(result.get("message", "Could not update selected object properties."))
	_refresh_state()

func _on_fill_terrain_pressed() -> void:
	var result := _fill_terrain_from_selected_tile()
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", "Could not fill selected terrain region."))
	_refresh_state()

func _on_restore_selected_tile_pressed() -> void:
	var result := _restore_selected_tile_from_authored()
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", "Could not restore selected tile."))
	_refresh_state()

func _on_map_tile_hovered(tile: Vector2i) -> void:
	_hovered_tile = tile
	if _tool == TOOL_PLACE_OBJECT:
		_sync_object_taxonomy_summary()

func _on_map_tile_pressed(tile: Vector2i) -> void:
	if _session == null or not _tile_in_bounds(tile):
		return
	_selected_tile = tile
	match _tool:
		TOOL_TERRAIN:
			_paint_terrain(tile, _selected_terrain_id)
		TOOL_TERRAIN_LINE:
			_terrain_line_tool_click(tile)
		TOOL_TERRAIN_RECTANGLE:
			_terrain_rectangle_tool_click(tile)
		TOOL_ROAD:
			_toggle_road(tile)
		TOOL_ROAD_PATH:
			_road_path_tool_click(tile)
		TOOL_HERO_START:
			_set_hero_start(tile)
		TOOL_PLACE_OBJECT:
			_place_object(tile)
		TOOL_REMOVE_OBJECT:
			_remove_object(tile)
		TOOL_MOVE_OBJECT:
			_move_object_tool_click(tile)
		TOOL_DUPLICATE_OBJECT:
			_duplicate_object_tool_click(tile)
		TOOL_RETHEME_OBJECT:
			_retheme_object(tile)
		_:
			_last_message = "Inspected tile %d,%d." % [tile.x, tile.y]
	_refresh_state()

func _paint_terrain(tile: Vector2i, terrain_id: String) -> bool:
	if not _tile_in_bounds(tile) or terrain_id == "":
		return false
	var previous := _terrain_at(tile)
	var result := _apply_terrain_placement([tile], terrain_id)
	if not bool(result.get("ok", false)):
		_last_message = String(result.get("message", "Could not paint terrain."))
		return false
	if not bool(result.get("changed", false)):
		_last_message = "Tile %d,%d already uses %s." % [tile.x, tile.y, _terrain_label_for_id(terrain_id)]
		return true
	_last_message = "Painted %d,%d from %s to %s; HoMM3 owner writes %d." % [
		tile.x,
		tile.y,
		_terrain_label_for_id(previous),
		_terrain_label_for_id(terrain_id),
		int(result.get("owner_changed_count", 0)),
	]
	return true

func _apply_terrain_placement(paint_tiles: Array, terrain_id: String) -> Dictionary:
	if _session == null:
		_last_terrain_placement_result = {
			"ok": false,
			"changed": false,
			"message": "No editor working copy is loaded.",
		}
		return _last_terrain_placement_result
	var map_data = _session.overworld.get("map", [])
	if not (map_data is Array):
		_last_terrain_placement_result = {
			"ok": false,
			"changed": false,
			"message": "Working copy has no terrain map array.",
		}
		return _last_terrain_placement_result
	var result: Dictionary = TerrainPlacementRulesScript.apply_paint(
		map_data,
		OverworldRules.derive_map_size(_session),
		terrain_id,
		paint_tiles,
		ContentService.get_terrain_grammar()
	)
	_last_terrain_placement_result = result
	if bool(result.get("ok", false)):
		_session.overworld["map"] = map_data
		if bool(result.get("changed", false)):
			_terrain_paint_order += 1
			_dirty = true
	return result

func _fill_terrain_from_selected_tile() -> Dictionary:
	return _fill_terrain_region(_selected_tile, _selected_terrain_id)

func _terrain_line_tool_click(tile: Vector2i) -> bool:
	if not _tile_in_bounds(tile):
		return false
	if not _has_pending_terrain_line_start():
		_pending_terrain_line_start = tile
		_last_message = "Terrain line start set at %d,%d. Next click paints %s with %s." % [
			tile.x,
			tile.y,
			TERRAIN_LINE_RULE_LABEL,
			_terrain_label_for_id(_selected_terrain_id),
		]
		return true
	var result := _apply_terrain_line(_pending_terrain_line_start, tile, _selected_terrain_id)
	if bool(result.get("ok", false)):
		_pending_terrain_line_start = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
		_last_message = String(result.get("message", "Applied terrain line."))
	else:
		_last_message = String(result.get("message", "Could not apply terrain line."))
	return bool(result.get("ok", false))

func _apply_terrain_line(start_tile: Vector2i, end_tile: Vector2i, terrain_id: String) -> Dictionary:
	if _session == null:
		return {"ok": false, "changed": false, "message": "No editor working copy is loaded."}
	if not _tile_in_bounds(start_tile) or not _tile_in_bounds(end_tile):
		return {"ok": false, "changed": false, "message": "Terrain line start or end is outside the map."}
	if terrain_id == "":
		return {"ok": false, "changed": false, "message": "Choose an active terrain id before painting a terrain line."}
	if not _terrain_id_in_grammar(terrain_id):
		return {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not in the authored terrain grammar." % terrain_id,
			"path_rule": TERRAIN_LINE_RULE_ID,
			"path_rule_label": TERRAIN_LINE_RULE_LABEL,
		}
	var map_data = _session.overworld.get("map", [])
	if not (map_data is Array):
		return {"ok": false, "changed": false, "message": "Working copy has no terrain map array."}
	var path_tiles := _terrain_line_tiles(start_tile, end_tile)
	var previous_terrain_by_tile := {}
	for tile in path_tiles:
		if not _tile_in_bounds(tile):
			continue
		previous_terrain_by_tile[_tile_key(tile)] = _terrain_at(tile)
	var placement_result := _apply_terrain_placement(path_tiles, terrain_id)
	if not bool(placement_result.get("ok", false)):
		return placement_result
	var changed := bool(placement_result.get("changed", false))
	var active_label := _terrain_label_for_id(terrain_id)
	var affected_count := int(placement_result.get("changed_count", 0))
	var owner_write_count := int(placement_result.get("owner_changed_count", 0))
	var message := "Painted %d terrain line tile%s with %s on %s from %d,%d to %d,%d; HoMM3 owner writes %d." % [
		affected_count,
		"" if affected_count == 1 else "s",
		active_label,
		TERRAIN_LINE_RULE_LABEL,
		start_tile.x,
		start_tile.y,
		end_tile.x,
		end_tile.y,
		owner_write_count,
	]
	if not changed:
		message = "Terrain line made no working-copy changes with %s on %s from %d,%d to %d,%d." % [
			active_label,
			TERRAIN_LINE_RULE_LABEL,
			start_tile.x,
			start_tile.y,
			end_tile.x,
			end_tile.y,
		]
	return {
		"ok": true,
		"changed": changed,
		"message": message,
		"active_terrain_id": terrain_id,
		"path_rule": TERRAIN_LINE_RULE_ID,
		"path_rule_label": TERRAIN_LINE_RULE_LABEL,
		"start_tile": {"x": start_tile.x, "y": start_tile.y},
		"end_tile": {"x": end_tile.x, "y": end_tile.y},
		"path_tiles": _tile_array_payload(path_tiles),
		"changed_tiles": placement_result.get("changed_tiles", []),
		"owner_changed_tiles": placement_result.get("owner_changed_tiles", []),
		"previous_terrain_by_tile": previous_terrain_by_tile,
		"path_count": path_tiles.size(),
		"affected_count": affected_count,
		"owner_changed_count": owner_write_count,
		"terrain_placement": placement_result,
	}

func _terrain_line_tiles(start_tile: Vector2i, end_tile: Vector2i) -> Array[Vector2i]:
	return _manhattan_l_path_tiles(start_tile, end_tile)

func _terrain_rectangle_tool_click(tile: Vector2i) -> bool:
	if not _tile_in_bounds(tile):
		return false
	if not _has_pending_terrain_rectangle_corner():
		_pending_terrain_rectangle_corner = tile
		_last_message = "Terrain rectangle corner set at %d,%d. Next click paints %s with %s." % [
			tile.x,
			tile.y,
			TERRAIN_RECTANGLE_RULE_LABEL,
			_terrain_label_for_id(_selected_terrain_id),
		]
		return true
	var result := _apply_terrain_rectangle(_pending_terrain_rectangle_corner, tile, _selected_terrain_id)
	if bool(result.get("ok", false)):
		_pending_terrain_rectangle_corner = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
		_last_message = String(result.get("message", "Applied terrain rectangle."))
	else:
		_last_message = String(result.get("message", "Could not apply terrain rectangle."))
	return bool(result.get("ok", false))

func _apply_terrain_rectangle(corner_tile: Vector2i, opposite_tile: Vector2i, terrain_id: String) -> Dictionary:
	if _session == null:
		return {"ok": false, "changed": false, "message": "No editor working copy is loaded."}
	if not _tile_in_bounds(corner_tile) or not _tile_in_bounds(opposite_tile):
		return {"ok": false, "changed": false, "message": "Terrain rectangle corner or opposite corner is outside the map."}
	if terrain_id == "":
		return {"ok": false, "changed": false, "message": "Choose an active terrain id before painting a terrain rectangle."}
	if not _terrain_id_in_grammar(terrain_id):
		return {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not in the authored terrain grammar." % terrain_id,
			"rectangle_rule": TERRAIN_RECTANGLE_RULE_ID,
			"rectangle_rule_label": TERRAIN_RECTANGLE_RULE_LABEL,
			"tile_order": TERRAIN_RECTANGLE_TILE_ORDER,
		}
	var map_data = _session.overworld.get("map", [])
	if not (map_data is Array):
		return {"ok": false, "changed": false, "message": "Working copy has no terrain map array."}
	var rectangle_tiles := _terrain_rectangle_tiles(corner_tile, opposite_tile)
	var previous_terrain_by_tile := {}
	for tile in rectangle_tiles:
		if not _tile_in_bounds(tile):
			continue
		previous_terrain_by_tile[_tile_key(tile)] = _terrain_at(tile)
	var placement_result := _apply_terrain_placement(rectangle_tiles, terrain_id)
	if not bool(placement_result.get("ok", false)):
		return placement_result
	var changed := bool(placement_result.get("changed", false))
	var active_label := _terrain_label_for_id(terrain_id)
	var affected_count := int(placement_result.get("changed_count", 0))
	var owner_write_count := int(placement_result.get("owner_changed_count", 0))
	var message := "Painted %d terrain rectangle tile%s with %s on %s from %d,%d to %d,%d; HoMM3 owner writes %d." % [
		affected_count,
		"" if affected_count == 1 else "s",
		active_label,
		TERRAIN_RECTANGLE_RULE_LABEL,
		corner_tile.x,
		corner_tile.y,
		opposite_tile.x,
		opposite_tile.y,
		owner_write_count,
	]
	if not changed:
		message = "Terrain rectangle made no working-copy changes with %s on %s from %d,%d to %d,%d." % [
			active_label,
			TERRAIN_RECTANGLE_RULE_LABEL,
			corner_tile.x,
			corner_tile.y,
			opposite_tile.x,
			opposite_tile.y,
		]
	return {
		"ok": true,
		"changed": changed,
		"message": message,
		"active_terrain_id": terrain_id,
		"rectangle_rule": TERRAIN_RECTANGLE_RULE_ID,
		"rectangle_rule_label": TERRAIN_RECTANGLE_RULE_LABEL,
		"tile_order": TERRAIN_RECTANGLE_TILE_ORDER,
		"corner_tile": {"x": corner_tile.x, "y": corner_tile.y},
		"opposite_tile": {"x": opposite_tile.x, "y": opposite_tile.y},
		"bounds": _terrain_rectangle_bounds(corner_tile, opposite_tile),
		"rectangle_tiles": _tile_array_payload(rectangle_tiles),
		"changed_tiles": placement_result.get("changed_tiles", []),
		"owner_changed_tiles": placement_result.get("owner_changed_tiles", []),
		"previous_terrain_by_tile": previous_terrain_by_tile,
		"rectangle_count": rectangle_tiles.size(),
		"affected_count": affected_count,
		"owner_changed_count": owner_write_count,
		"terrain_placement": placement_result,
	}

func _terrain_rectangle_tiles(corner_tile: Vector2i, opposite_tile: Vector2i) -> Array[Vector2i]:
	var bounds := _terrain_rectangle_bounds(corner_tile, opposite_tile)
	var tiles: Array[Vector2i] = []
	for y in range(int(bounds.get("min_y", 0)), int(bounds.get("max_y", 0)) + 1):
		for x in range(int(bounds.get("min_x", 0)), int(bounds.get("max_x", 0)) + 1):
			tiles.append(Vector2i(x, y))
	return tiles

func _terrain_rectangle_bounds(corner_tile: Vector2i, opposite_tile: Vector2i) -> Dictionary:
	return {
		"min_x": min(corner_tile.x, opposite_tile.x),
		"min_y": min(corner_tile.y, opposite_tile.y),
		"max_x": max(corner_tile.x, opposite_tile.x),
		"max_y": max(corner_tile.y, opposite_tile.y),
	}

func _fill_terrain_region(start_tile: Vector2i, terrain_id: String) -> Dictionary:
	if _session == null:
		return {"ok": false, "changed": false, "message": "No editor working copy is loaded."}
	if not _tile_in_bounds(start_tile):
		return {"ok": false, "changed": false, "message": "Selected tile is outside the map."}
	if terrain_id == "":
		return {"ok": false, "changed": false, "message": "Choose an active terrain id before filling."}
	if not _terrain_id_in_grammar(terrain_id):
		return {"ok": false, "changed": false, "message": "Terrain id %s is not in the authored terrain grammar." % terrain_id}
	var source_terrain := _terrain_at(start_tile)
	if source_terrain == "":
		return {"ok": false, "changed": false, "message": "Selected tile has no terrain to fill."}
	if source_terrain == terrain_id:
		return {
			"ok": true,
			"changed": false,
			"message": "Tile %d,%d already uses %s; fill skipped." % [start_tile.x, start_tile.y, _terrain_label_for_id(terrain_id)],
			"start_tile": {"x": start_tile.x, "y": start_tile.y},
			"source_terrain_id": source_terrain,
			"active_terrain_id": terrain_id,
			"filled_count": 0,
			"contiguity": "cardinal",
		}

	var map_data = _session.overworld.get("map", [])
	if not (map_data is Array):
		return {"ok": false, "changed": false, "message": "Working copy has no terrain map array."}
	var visited := {}
	var frontier: Array[Vector2i] = [start_tile]
	var filled_tiles: Array[Vector2i] = []
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_back()
		if not _tile_in_bounds(tile):
			continue
		var tile_key := _tile_key(tile)
		if visited.has(tile_key):
			continue
		visited[tile_key] = true
		if _terrain_at(tile) != source_terrain:
			continue
		filled_tiles.append(tile)
		for direction_value in directions:
			var direction: Vector2i = direction_value
			var neighbor: Vector2i = tile + direction
			if not _tile_in_bounds(neighbor):
				continue
			var neighbor_key := _tile_key(neighbor)
			if visited.has(neighbor_key):
				continue
			if _terrain_at(neighbor) == source_terrain:
				frontier.append(neighbor)

	var placement_result := _apply_terrain_placement(filled_tiles, terrain_id)
	if not bool(placement_result.get("ok", false)):
		return placement_result
	var affected_count := int(placement_result.get("changed_count", 0))
	var owner_write_count := int(placement_result.get("owner_changed_count", 0))
	return {
		"ok": true,
		"changed": bool(placement_result.get("changed", false)),
		"message": "Filled %d contiguous %s tile%s from %d,%d with %s; HoMM3 owner writes %d and affected %d tile%s." % [
			filled_tiles.size(),
			_terrain_label_for_id(source_terrain),
			"" if filled_tiles.size() == 1 else "s",
			start_tile.x,
			start_tile.y,
			_terrain_label_for_id(terrain_id),
			owner_write_count,
			affected_count,
			"" if affected_count == 1 else "s",
		],
		"start_tile": {"x": start_tile.x, "y": start_tile.y},
		"source_terrain_id": source_terrain,
		"active_terrain_id": terrain_id,
		"filled_count": filled_tiles.size(),
		"changed_tiles": placement_result.get("changed_tiles", []),
		"owner_changed_tiles": placement_result.get("owner_changed_tiles", []),
		"affected_count": affected_count,
		"owner_changed_count": owner_write_count,
		"contiguity": "cardinal",
		"terrain_placement": placement_result,
	}

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

func _road_path_tool_click(tile: Vector2i) -> bool:
	if not _tile_in_bounds(tile):
		return false
	if not _has_pending_road_path_start():
		_pending_road_path_start = tile
		_last_message = "Road path start set at %d,%d. Next click applies %s." % [
			tile.x,
			tile.y,
			ROAD_PATH_RULE_LABEL,
		]
		return true
	var result := _apply_road_path(_pending_road_path_start, tile, "toggle")
	if bool(result.get("ok", false)):
		_pending_road_path_start = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
		_last_message = String(result.get("message", "Applied road path."))
	else:
		_last_message = String(result.get("message", "Could not apply road path."))
	return bool(result.get("ok", false))

func _apply_road_path(start_tile: Vector2i, end_tile: Vector2i, requested_action: String = "toggle") -> Dictionary:
	if _session == null:
		return {"ok": false, "changed": false, "message": "No editor working copy is loaded."}
	if not _tile_in_bounds(start_tile) or not _tile_in_bounds(end_tile):
		return {"ok": false, "changed": false, "message": "Road path start or end is outside the map."}
	var action := requested_action if requested_action != "" else "toggle"
	if action not in ["toggle", "add", "remove"]:
		return {
			"ok": false,
			"changed": false,
			"message": "Road path action must be toggle, add, or remove.",
			"requested_action": requested_action,
			"path_rule": ROAD_PATH_RULE_ID,
			"path_rule_label": ROAD_PATH_RULE_LABEL,
		}
	var path_tiles := _road_path_tiles(start_tile, end_tile)
	var resolved_action := action
	if action == "toggle":
		resolved_action = "remove" if _all_road_path_tiles_have_roads(path_tiles) else "add"
	var changed_tiles: Array[Vector2i] = []
	if resolved_action == "remove":
		changed_tiles = _remove_road_tiles(path_tiles)
	else:
		changed_tiles = _add_road_tiles(path_tiles)
	var changed := not changed_tiles.is_empty()
	var verb := "Added"
	if resolved_action == "remove":
		verb = "Removed"
	var message := "%s %d road tile%s on %s from %d,%d to %d,%d." % [
		verb,
		changed_tiles.size(),
		"" if changed_tiles.size() == 1 else "s",
		ROAD_PATH_RULE_LABEL,
		start_tile.x,
		start_tile.y,
		end_tile.x,
		end_tile.y,
	]
	if not changed:
		message = "Road path made no working-copy changes on %s from %d,%d to %d,%d." % [
			ROAD_PATH_RULE_LABEL,
			start_tile.x,
			start_tile.y,
			end_tile.x,
			end_tile.y,
		]
	return {
		"ok": true,
		"changed": changed,
		"message": message,
		"requested_action": action,
		"road_path_action": resolved_action,
		"path_rule": ROAD_PATH_RULE_ID,
		"path_rule_label": ROAD_PATH_RULE_LABEL,
		"start_tile": {"x": start_tile.x, "y": start_tile.y},
		"end_tile": {"x": end_tile.x, "y": end_tile.y},
		"path_tiles": _tile_array_payload(path_tiles),
		"changed_tiles": _tile_array_payload(changed_tiles),
		"path_count": path_tiles.size(),
		"affected_count": changed_tiles.size(),
	}

func _road_path_tiles(start_tile: Vector2i, end_tile: Vector2i) -> Array[Vector2i]:
	return _manhattan_l_path_tiles(start_tile, end_tile)

func _manhattan_l_path_tiles(start_tile: Vector2i, end_tile: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var cursor := start_tile
	tiles.append(cursor)
	while cursor.x != end_tile.x:
		cursor.x += 1 if end_tile.x > cursor.x else -1
		tiles.append(cursor)
	while cursor.y != end_tile.y:
		cursor.y += 1 if end_tile.y > cursor.y else -1
		tiles.append(cursor)
	return tiles

func _all_road_path_tiles_have_roads(path_tiles: Array[Vector2i]) -> bool:
	if path_tiles.is_empty():
		return false
	for tile in path_tiles:
		if not _has_road_at(tile):
			return false
	return true

func _add_road_tiles(path_tiles: Array[Vector2i]) -> Array[Vector2i]:
	var terrain_layers := _terrain_layers()
	var roads = terrain_layers.get("roads", [])
	if not (roads is Array):
		roads = []
	var existing_keys := _road_tile_keys_from_layers(roads)
	var tiles_to_add: Array[Vector2i] = []
	for tile in path_tiles:
		var key := _tile_key(tile)
		if existing_keys.has(key):
			continue
		existing_keys[key] = true
		tiles_to_add.append(tile)
	if tiles_to_add.is_empty():
		return []
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
	var editor_tiles = editor_layer.get("tiles", [])
	if not (editor_tiles is Array):
		editor_tiles = []
	for tile in tiles_to_add:
		editor_tiles.append({"x": tile.x, "y": tile.y})
	editor_layer["tiles"] = editor_tiles
	roads[editor_layer_index] = editor_layer
	terrain_layers["roads"] = roads
	_session.overworld["terrain_layers"] = terrain_layers
	return tiles_to_add

func _remove_road_tiles(path_tiles: Array[Vector2i]) -> Array[Vector2i]:
	var terrain_layers := _terrain_layers()
	var roads = terrain_layers.get("roads", [])
	if not (roads is Array):
		return []
	var path_keys := {}
	for tile in path_tiles:
		path_keys[_tile_key(tile)] = true
	var removed_keys := {}
	for index in range(roads.size()):
		var road = roads[index]
		if not (road is Dictionary):
			continue
		var tiles = road.get("tiles", [])
		if not (tiles is Array):
			continue
		var updated_tiles := []
		for tile_value in tiles:
			if not (tile_value is Dictionary):
				updated_tiles.append(tile_value)
				continue
			var tile := Vector2i(int(tile_value.get("x", -1)), int(tile_value.get("y", -1)))
			var key := _tile_key(tile)
			if path_keys.has(key):
				removed_keys[key] = tile
				continue
			updated_tiles.append(tile_value)
		road["tiles"] = updated_tiles
		roads[index] = road
	if removed_keys.is_empty():
		return []
	terrain_layers["roads"] = roads
	_session.overworld["terrain_layers"] = terrain_layers
	var removed_tiles: Array[Vector2i] = []
	for tile in path_tiles:
		var key := _tile_key(tile)
		if removed_keys.has(key):
			removed_tiles.append(tile)
	return removed_tiles

func _road_tile_keys_from_layers(roads: Array) -> Dictionary:
	var keys := {}
	for road in roads:
		if not (road is Dictionary):
			continue
		var tiles = road.get("tiles", [])
		if not (tiles is Array):
			continue
		for tile_value in tiles:
			if tile_value is Dictionary:
				keys["%d,%d" % [int(tile_value.get("x", -1)), int(tile_value.get("y", -1))]] = true
	return keys

func _has_pending_terrain_line_start() -> bool:
	return _pending_terrain_line_start.x >= 0 and _pending_terrain_line_start.y >= 0 and _tile_in_bounds(_pending_terrain_line_start)

func _pending_terrain_line_start_payload() -> Dictionary:
	if not _has_pending_terrain_line_start():
		return {}
	return {"x": _pending_terrain_line_start.x, "y": _pending_terrain_line_start.y}

func _has_pending_terrain_rectangle_corner() -> bool:
	return _pending_terrain_rectangle_corner.x >= 0 and _pending_terrain_rectangle_corner.y >= 0 and _tile_in_bounds(_pending_terrain_rectangle_corner)

func _pending_terrain_rectangle_corner_payload() -> Dictionary:
	if not _has_pending_terrain_rectangle_corner():
		return {}
	return {"x": _pending_terrain_rectangle_corner.x, "y": _pending_terrain_rectangle_corner.y}

func _has_pending_road_path_start() -> bool:
	return _pending_road_path_start.x >= 0 and _pending_road_path_start.y >= 0 and _tile_in_bounds(_pending_road_path_start)

func _pending_road_path_start_payload() -> Dictionary:
	if not _has_pending_road_path_start():
		return {}
	return {"x": _pending_road_path_start.x, "y": _pending_road_path_start.y}

func _tile_array_payload(tiles: Array[Vector2i]) -> Array:
	var payload := []
	for tile in tiles:
		payload.append({"x": tile.x, "y": tile.y})
	return payload

func _editor_road_layer_index(roads: Array) -> int:
	for index in range(roads.size()):
		var road = roads[index]
		if road is Dictionary and String(road.get("id", "")) == EDITOR_ROAD_LAYER_ID:
			return index
	return -1

func _set_hero_start(tile: Vector2i) -> bool:
	if not _set_hero_position(tile):
		return false
	_dirty = true
	_last_message = "Moved the working-copy hero start to %d,%d." % [tile.x, tile.y]
	return true

func _set_hero_position(tile: Vector2i) -> bool:
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

	var preview := _selected_object_placement_preview_payload(tile)
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
	var after_detail := _object_detail_by_key(_object_property_key(_selected_object_family, placement_id))
	_set_object_authoring_recap("place", true, {}, after_detail, tile, tile, preview)
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
	var removed_details := []
	for placement in placements:
		if placement is Dictionary and _placement_at_tile(placement, tile):
			removed_ids.append(String(placement.get("placement_id", "")))
			removed_details.append(_object_detail_with_guidance(_object_detail_for_placement(_selected_object_family, placement), tile))
			continue
		updated.append(placement)
	if removed_ids.is_empty():
		_last_message = "No %s placement at %d,%d." % [_object_family_label(_selected_object_family), tile.x, tile.y]
		return false
	_session.overworld[array_key] = updated
	if _selected_object_family == OBJECT_FAMILY_ENCOUNTER:
		_remove_resolved_encounter_ids(removed_ids)
	_dirty = true
	var before_detail: Dictionary = removed_details[0] if not removed_details.is_empty() else {}
	_set_object_authoring_recap("remove", true, before_detail, {}, tile, tile)
	return true

func _move_object_tool_click(tile: Vector2i) -> bool:
	if _pending_move_object_key == "":
		var detail := _preferred_move_detail_at(tile)
		if detail.is_empty():
			_last_message = "Choose a supported town, site, artifact, or encounter to move."
			return false
		_pending_move_object_key = String(detail.get("property_key", ""))
		_selected_property_object_key = _pending_move_object_key
		_last_message = "Move source selected: %s at %d,%d. Choose a destination tile." % [
			String(detail.get("placement_id", "")),
			tile.x,
			tile.y,
		]
		return true
	var before_detail := _object_detail_by_key(_pending_move_object_key)
	var source_tile := Vector2i(int(before_detail.get("x", tile.x)), int(before_detail.get("y", tile.y)))
	var result := _move_object_by_key(_pending_move_object_key, tile)
	if bool(result.get("ok", false)):
		_pending_move_object_key = ""
		_dirty = _dirty or bool(result.get("changed", false))
		var after_detail := _object_detail_by_key(String(before_detail.get("property_key", "")))
		_set_object_authoring_recap("move", bool(result.get("changed", false)), before_detail, after_detail, source_tile, tile)
	else:
		_last_message = String(result.get("message", "Could not move object placement."))
	return bool(result.get("ok", false))

func _preferred_move_detail_at(tile: Vector2i) -> Dictionary:
	var options := _property_object_options_at(tile)
	if options.is_empty():
		return {}
	for detail in options:
		if detail is Dictionary and String(detail.get("property_key", "")) == _selected_property_object_key:
			return detail
	for detail in options:
		if detail is Dictionary:
			return detail
	return {}

func _move_object_by_key(property_key: String, destination_tile: Vector2i) -> Dictionary:
	if not _tile_in_bounds(destination_tile):
		return {"ok": false, "changed": false, "message": "Destination tile is outside the map."}
	var detail := _object_detail_by_key(property_key)
	if detail.is_empty():
		return {"ok": false, "changed": false, "message": "No movable object %s exists in the working copy." % property_key}
	var kind := String(detail.get("kind", ""))
	var placement_id := String(detail.get("placement_id", ""))
	var blocker := _first_blocking_object_detail_at(destination_tile, property_key)
	if not blocker.is_empty():
		return {
			"ok": false,
			"changed": false,
			"message": "Destination %d,%d already has %s." % [
				destination_tile.x,
				destination_tile.y,
				String(blocker.get("placement_id", blocker.get("kind", "object"))),
			],
		}
	var source_tile := Vector2i(int(detail.get("x", 0)), int(detail.get("y", 0)))
	if source_tile == destination_tile:
		_selected_property_object_key = property_key
		return {
			"ok": true,
			"changed": false,
			"message": "%s %s is already at %d,%d." % [
				_object_family_label(kind),
				placement_id,
				destination_tile.x,
				destination_tile.y,
			],
			"object": detail,
			"from": {"x": source_tile.x, "y": source_tile.y},
			"to": {"x": destination_tile.x, "y": destination_tile.y},
		}
	var array_key := _placement_array_key(kind)
	var placements = _session.overworld.get(array_key, [])
	if array_key == "" or not (placements is Array):
		return {"ok": false, "changed": false, "message": "Working copy has no %s array." % _object_family_label(kind)}
	for index in range(placements.size()):
		var placement = placements[index]
		if not (placement is Dictionary):
			continue
		if String(placement.get("placement_id", "")) != placement_id:
			continue
		var before: Dictionary = placement.duplicate(true)
		placement["x"] = destination_tile.x
		placement["y"] = destination_tile.y
		placements[index] = placement
		_session.overworld[array_key] = placements
		_selected_property_object_key = property_key
		return {
			"ok": true,
			"changed": before != placement,
			"message": "Moved %s %s from %d,%d to %d,%d." % [
				_object_family_label(kind),
				placement_id,
				source_tile.x,
				source_tile.y,
				destination_tile.x,
				destination_tile.y,
			],
			"object": placement,
			"from": {"x": source_tile.x, "y": source_tile.y},
			"to": {"x": destination_tile.x, "y": destination_tile.y},
		}
	return {"ok": false, "changed": false, "message": "No %s placement %s in the working copy." % [_object_family_label(kind), placement_id]}

func _duplicate_object_tool_click(tile: Vector2i) -> bool:
	if _pending_duplicate_object_key == "":
		var detail := _preferred_move_detail_at(tile)
		if detail.is_empty():
			_last_message = "Choose a supported town, site, artifact, or encounter to duplicate."
			return false
		_pending_duplicate_object_key = String(detail.get("property_key", ""))
		_selected_property_object_key = _pending_duplicate_object_key
		_last_message = "Duplicate source selected: %s at %d,%d. Choose an empty destination tile." % [
			String(detail.get("placement_id", "")),
			tile.x,
			tile.y,
		]
		return true
	var before_detail := _object_detail_by_key(_pending_duplicate_object_key)
	var source_tile := Vector2i(int(before_detail.get("x", tile.x)), int(before_detail.get("y", tile.y)))
	var result := _duplicate_object_by_key(_pending_duplicate_object_key, tile)
	if bool(result.get("ok", false)):
		_pending_duplicate_object_key = ""
		_dirty = _dirty or bool(result.get("changed", false))
		var duplicate_key := _object_property_key(String(before_detail.get("kind", "")), String(result.get("object", {}).get("placement_id", "")))
		var after_detail := _object_detail_by_key(duplicate_key)
		_set_object_authoring_recap("duplicate", bool(result.get("changed", false)), before_detail, after_detail, source_tile, tile)
	else:
		_last_message = String(result.get("message", "Could not duplicate object placement."))
	return bool(result.get("ok", false))

func _duplicate_object_by_key(property_key: String, destination_tile: Vector2i) -> Dictionary:
	if not _tile_in_bounds(destination_tile):
		return {"ok": false, "changed": false, "message": "Destination tile is outside the map."}
	var detail := _object_detail_by_key(property_key)
	if detail.is_empty():
		return {"ok": false, "changed": false, "message": "No duplicable object %s exists in the working copy." % property_key}
	var blocker := _first_blocking_object_detail_at(destination_tile)
	if not blocker.is_empty():
		return {
			"ok": false,
			"changed": false,
			"message": "Destination %d,%d already has %s." % [
				destination_tile.x,
				destination_tile.y,
				String(blocker.get("placement_id", blocker.get("kind", "object"))),
			],
		}
	var kind := String(detail.get("kind", ""))
	var placement_id := String(detail.get("placement_id", ""))
	var array_key := _placement_array_key(kind)
	var placements = _session.overworld.get(array_key, [])
	if array_key == "" or not (placements is Array):
		return {"ok": false, "changed": false, "message": "Working copy has no %s array." % _object_family_label(kind)}
	for placement in placements:
		if not (placement is Dictionary):
			continue
		if String(placement.get("placement_id", "")) != placement_id:
			continue
		var source_tile := Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0)))
		var duplicated_placement: Dictionary = placement.duplicate(true)
		var duplicated_placement_id := _generate_duplicate_placement_id(kind, placement_id, destination_tile)
		duplicated_placement["placement_id"] = duplicated_placement_id
		duplicated_placement["x"] = destination_tile.x
		duplicated_placement["y"] = destination_tile.y
		placements.append(duplicated_placement)
		_session.overworld[array_key] = placements
		_selected_property_object_key = _object_property_key(kind, duplicated_placement_id)
		return {
			"ok": true,
			"changed": true,
			"message": "Duplicated %s %s from %d,%d to %d,%d as %s." % [
				_object_family_label(kind),
				placement_id,
				source_tile.x,
				source_tile.y,
				destination_tile.x,
				destination_tile.y,
				duplicated_placement_id,
			],
			"object": duplicated_placement,
			"source_object": placement,
			"from": {"x": source_tile.x, "y": source_tile.y},
			"to": {"x": destination_tile.x, "y": destination_tile.y},
		}
	return {"ok": false, "changed": false, "message": "No %s placement %s in the working copy." % [_object_family_label(kind), placement_id]}

func _retheme_object(tile: Vector2i) -> bool:
	if not _tile_in_bounds(tile):
		return false
	if _selected_object_family == "" or _selected_object_content_id == "":
		_last_message = "Choose an object family and replacement content id before retheming."
		return false
	if _object_content_lookup(_selected_object_family, _selected_object_content_id).is_empty():
		_last_message = "Unknown %s content id %s." % [_object_family_label(_selected_object_family), _selected_object_content_id]
		return false
	var source_detail := _object_detail_for_family_at(tile, _selected_object_family)
	if source_detail.is_empty():
		_last_message = "No %s placement at %d,%d to retheme." % [
			_object_family_label(_selected_object_family),
			tile.x,
			tile.y,
		]
		return false
	var result := _retheme_object_by_key(String(source_detail.get("property_key", "")), _selected_object_content_id)
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
		var after_detail := _object_detail_by_key(String(source_detail.get("property_key", "")))
		_set_object_authoring_recap("retheme", bool(result.get("changed", false)), source_detail, after_detail, tile, tile)
	else:
		_last_message = String(result.get("message", "Could not retheme object placement."))
	return bool(result.get("ok", false))

func _object_detail_for_family_at(tile: Vector2i, family: String) -> Dictionary:
	for detail in _property_object_options_at(tile):
		if detail is Dictionary and String(detail.get("kind", "")) == family:
			return detail
	return {}

func _retheme_object_by_key(property_key: String, replacement_content_id: String) -> Dictionary:
	var detail := _object_detail_by_key(property_key)
	if detail.is_empty():
		return {"ok": false, "changed": false, "message": "No rethemeable object %s exists in the working copy." % property_key}
	var kind := String(detail.get("kind", ""))
	var placement_id := String(detail.get("placement_id", ""))
	if _object_content_lookup(kind, replacement_content_id).is_empty():
		return {
			"ok": false,
			"changed": false,
			"message": "Unknown %s content id %s." % [_object_family_label(kind), replacement_content_id],
		}
	var content_key := _placement_content_key(kind)
	var array_key := _placement_array_key(kind)
	var placements = _session.overworld.get(array_key, [])
	if content_key == "" or array_key == "" or not (placements is Array):
		return {"ok": false, "changed": false, "message": "Working copy has no %s array." % _object_family_label(kind)}
	for index in range(placements.size()):
		var placement = placements[index]
		if not (placement is Dictionary):
			continue
		if String(placement.get("placement_id", "")) != placement_id:
			continue
		var previous_content_id := String(placement.get(content_key, ""))
		_selected_property_object_key = property_key
		if previous_content_id == replacement_content_id:
			return {
				"ok": true,
				"changed": false,
				"message": "%s %s already uses %s." % [
					_object_family_label(kind),
					placement_id,
					replacement_content_id,
				],
				"object": _object_detail_for_placement(kind, placement),
				"previous_content_id": previous_content_id,
				"content_id": replacement_content_id,
			}
		var before: Dictionary = placement.duplicate(true)
		placement[content_key] = replacement_content_id
		placements[index] = placement
		_session.overworld[array_key] = placements
		return {
			"ok": true,
			"changed": before != placement,
			"message": "Rethemed %s %s from %s to %s." % [
				_object_family_label(kind),
				placement_id,
				previous_content_id,
				replacement_content_id,
			],
			"object": _object_detail_for_placement(kind, placement),
			"object_before": _object_detail_for_placement(kind, before),
			"previous_content_id": previous_content_id,
			"content_id": replacement_content_id,
		}
	return {"ok": false, "changed": false, "message": "No %s placement %s in the working copy." % [_object_family_label(kind), placement_id]}

func _first_blocking_object_detail_at(tile: Vector2i, ignored_property_key: String = "") -> Dictionary:
	for detail in _object_details_at(tile, false):
		if not (detail is Dictionary):
			continue
		if ignored_property_key != "" and String(detail.get("property_key", "")) == ignored_property_key:
			continue
		return detail
	return {}

func _apply_selected_object_properties(detail: Dictionary) -> Dictionary:
	var kind := String(detail.get("kind", ""))
	var placement_id := String(detail.get("placement_id", ""))
	if placement_id == "":
		return {"ok": false, "changed": false, "message": "Selected object has no placement id."}
	match kind:
		OBJECT_FAMILY_TOWN:
			var owner := _selected_picker_metadata(_property_owner_picker, String(detail.get("owner", "neutral")))
			return _set_town_owner_property(placement_id, owner)
		OBJECT_FAMILY_RESOURCE:
			return _set_collected_property(OBJECT_FAMILY_RESOURCE, placement_id, _property_collected_check.button_pressed)
		OBJECT_FAMILY_ARTIFACT:
			return _set_collected_property(OBJECT_FAMILY_ARTIFACT, placement_id, _property_collected_check.button_pressed)
		OBJECT_FAMILY_ENCOUNTER:
			var difficulty := _selected_picker_metadata(_property_difficulty_picker, String(detail.get("difficulty", "medium")))
			return _set_encounter_difficulty_property(placement_id, difficulty)
		_:
			return {"ok": false, "changed": false, "message": "No mutable properties for %s." % kind}

func _set_town_owner_property(placement_id: String, owner: String) -> Dictionary:
	if owner == "":
		owner = "neutral"
	if owner not in TOWN_OWNER_OPTIONS:
		return {"ok": false, "changed": false, "message": "Unsupported town owner %s." % owner}
	var result: Dictionary = OverworldRules.transition_town_control(
		_session,
		placement_id,
		owner,
		"",
		"map_editor_working_copy"
	)
	if not bool(result.get("ok", false)):
		return {"ok": false, "changed": false, "message": "Could not update town owner for %s." % placement_id}
	return {
		"ok": true,
		"changed": bool(result.get("changed", false)),
		"message": "Set town %s owner to %s." % [placement_id, owner],
		"object": result.get("town", {}),
	}

func _set_encounter_difficulty_property(placement_id: String, difficulty: String) -> Dictionary:
	if difficulty == "":
		difficulty = "medium"
	if difficulty not in ENCOUNTER_DIFFICULTY_OPTIONS:
		return {"ok": false, "changed": false, "message": "Unsupported encounter difficulty %s." % difficulty}
	var encounters = _session.overworld.get("encounters", [])
	if not (encounters is Array):
		return {"ok": false, "changed": false, "message": "Working copy has no encounter array."}
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("placement_id", "")) != placement_id:
			continue
		var previous := String(encounter.get("difficulty", "medium"))
		encounter["difficulty"] = difficulty
		encounters[index] = encounter
		_session.overworld["encounters"] = encounters
		return {
			"ok": true,
			"changed": previous != difficulty,
			"message": "Set encounter %s difficulty to %s." % [placement_id, difficulty],
			"object": encounter,
		}
	return {"ok": false, "changed": false, "message": "No encounter placement %s in the working copy." % placement_id}

func _set_collected_property(family: String, placement_id: String, collected: bool) -> Dictionary:
	var array_key := _placement_array_key(family)
	var placements = _session.overworld.get(array_key, [])
	if array_key == "" or not (placements is Array):
		return {"ok": false, "changed": false, "message": "Working copy has no %s array." % _object_family_label(family)}
	for index in range(placements.size()):
		var placement = placements[index]
		if not (placement is Dictionary):
			continue
		if String(placement.get("placement_id", "")) != placement_id:
			continue
		var before: Dictionary = placement.duplicate(true)
		placement["collected"] = collected
		if collected:
			if String(placement.get("collected_by_faction_id", "")) == "":
				placement["collected_by_faction_id"] = "player"
			if int(placement.get("collected_day", 0)) <= 0:
				placement["collected_day"] = _session.day
		else:
			placement["collected_by_faction_id"] = ""
			placement["collected_day"] = 0
		placements[index] = placement
		_session.overworld[array_key] = placements
		return {
			"ok": true,
			"changed": before != placement,
			"message": "Set %s %s collected to %s." % [
				_object_family_label(family),
				placement_id,
				"true" if collected else "false",
			],
			"object": placement,
		}
	return {"ok": false, "changed": false, "message": "No %s placement %s in the working copy." % [_object_family_label(family), placement_id]}

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

func _restore_selected_tile_from_authored() -> Dictionary:
	if _session == null:
		return {"ok": false, "changed": false, "message": "No editor working copy is loaded."}
	var tile := _selected_tile
	if not _tile_in_bounds(tile):
		return {"ok": false, "changed": false, "message": "Selected tile is outside the map."}
	var baseline = _authored_baseline_session()
	if baseline == null or baseline.scenario_id == "":
		return {
			"ok": false,
			"changed": false,
			"message": "Could not read authored baseline for %s." % _session.scenario_id,
		}

	var before_overworld: Dictionary = _session.overworld.duplicate(true)
	var before_inspection := _tile_inspection_payload(tile)
	var terrain_result := _restore_tile_terrain_from_baseline(tile, baseline)
	if not bool(terrain_result.get("ok", false)):
		return terrain_result
	var road_result := _restore_tile_roads_from_baseline(tile, baseline)
	var hero_result := _restore_tile_hero_start_from_baseline(tile, baseline)
	var object_result := _restore_tile_objects_from_baseline(tile, baseline)
	_remove_stale_editor_object_keys()

	var changed: bool = before_overworld != _session.overworld
	var message: String = "Restored tile %d,%d from authored baseline." % [tile.x, tile.y]
	if not changed:
		message = "Tile %d,%d already matches the authored baseline." % [tile.x, tile.y]
	return {
		"ok": true,
		"changed": changed,
		"message": message,
		"tile": {"x": tile.x, "y": tile.y},
		"before_tile_inspection": before_inspection,
		"terrain_restore": terrain_result,
		"road_restore": road_result,
		"hero_restore": hero_result,
		"object_restore": object_result,
	}

func _authored_baseline_session():
	if _session == null or _session.scenario_id == "":
		return null
	var baseline = ScenarioFactoryScript.create_session(
		_session.scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if baseline == null or baseline.scenario_id == "":
		return null
	OverworldRules.normalize_overworld_state(baseline)
	return baseline

func _restore_tile_terrain_from_baseline(tile: Vector2i, baseline) -> Dictionary:
	var authored_terrain := _terrain_at_in_overworld(baseline.overworld, tile)
	if authored_terrain == "":
		return {
			"ok": false,
			"changed": false,
			"message": "Authored baseline has no terrain at %d,%d." % [tile.x, tile.y],
		}
	var previous_terrain := _terrain_at(tile)
	if previous_terrain != authored_terrain:
		_set_tile_terrain(tile, authored_terrain)
	return {
		"ok": true,
		"changed": previous_terrain != authored_terrain,
		"previous_terrain_id": previous_terrain,
		"authored_terrain_id": authored_terrain,
	}

func _restore_tile_roads_from_baseline(tile: Vector2i, baseline) -> Dictionary:
	var authored_road_layers := _road_layers_at_in_overworld(baseline.overworld, tile)
	var authored_by_id := {}
	for road in authored_road_layers:
		if not (road is Dictionary):
			continue
		authored_by_id[String(road.get("id", ""))] = road

	var terrain_layers := _terrain_layers()
	var roads = terrain_layers.get("roads", [])
	if not (roads is Array):
		roads = []

	var restored_layer_ids := []
	var removed_layer_ids := []
	var found_authored_ids := {}
	for index in range(roads.size()):
		var road = roads[index]
		if not (road is Dictionary):
			continue
		var road_id := String(road.get("id", ""))
		var should_keep_tile := authored_by_id.has(road_id)
		var tiles = road.get("tiles", [])
		if not (tiles is Array):
			tiles = []
		var updated_tiles := []
		var kept_tile := false
		for tile_value in tiles:
			if _tile_payload_matches(tile_value, tile):
				if should_keep_tile and not kept_tile:
					updated_tiles.append(_authored_road_tile_payload(authored_by_id[road_id], tile))
					kept_tile = true
				else:
					removed_layer_ids.append(road_id)
				continue
			updated_tiles.append(tile_value)
		if should_keep_tile:
			found_authored_ids[road_id] = true
			if not kept_tile:
				updated_tiles.append(_authored_road_tile_payload(authored_by_id[road_id], tile))
				restored_layer_ids.append(road_id)
		road["tiles"] = updated_tiles
		roads[index] = road

	for road in authored_road_layers:
		if not (road is Dictionary):
			continue
		var road_id := String(road.get("id", ""))
		if found_authored_ids.has(road_id):
			continue
		var restored_road: Dictionary = road.duplicate(true)
		restored_road["tiles"] = [_authored_road_tile_payload(road, tile)]
		roads.append(restored_road)
		restored_layer_ids.append(road_id)

	terrain_layers["roads"] = roads
	_session.overworld["terrain_layers"] = terrain_layers
	return {
		"ok": true,
		"changed": not restored_layer_ids.is_empty() or not removed_layer_ids.is_empty(),
		"authored_road_layers": authored_by_id.keys(),
		"restored_road_layers": restored_layer_ids,
		"removed_road_layers": removed_layer_ids,
	}

func _restore_tile_hero_start_from_baseline(tile: Vector2i, baseline) -> Dictionary:
	var authored_start := OverworldRules.hero_position(baseline)
	var current_start := OverworldRules.hero_position(_session)
	var applies := tile == authored_start or tile == current_start
	if not applies:
		return {
			"applied": false,
			"changed": false,
			"authored_start": {"x": authored_start.x, "y": authored_start.y},
			"previous_start": {"x": current_start.x, "y": current_start.y},
		}
	if current_start != authored_start:
		_set_hero_position(authored_start)
	return {
		"applied": true,
		"changed": current_start != authored_start,
		"authored_start": {"x": authored_start.x, "y": authored_start.y},
		"previous_start": {"x": current_start.x, "y": current_start.y},
	}

func _restore_tile_objects_from_baseline(tile: Vector2i, baseline) -> Dictionary:
	var restored_ids := []
	var removed_ids := []
	for family in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER]:
		var baseline_placements := _placements_for_family_at_in_session(baseline, family, tile)
		var baseline_by_id := {}
		for baseline_placement in baseline_placements:
			if baseline_placement is Dictionary:
				baseline_by_id[String(baseline_placement.get("placement_id", ""))] = baseline_placement
		var array_key := _placement_array_key(family)
		var placements = _session.overworld.get(array_key, [])
		if not (placements is Array):
			placements = []
		var updated := []
		var restored_for_family := []
		var removed_for_family := []
		for placement in placements:
			if not (placement is Dictionary):
				updated.append(placement)
				continue
			var placement_id := String(placement.get("placement_id", ""))
			if baseline_by_id.has(placement_id):
				if placement_id not in restored_for_family:
					var restored_placement: Dictionary = baseline_by_id[placement_id].duplicate(true)
					updated.append(restored_placement)
					restored_for_family.append(placement_id)
				else:
					removed_for_family.append(placement_id)
				continue
			if _placement_at_tile(placement, tile):
				removed_for_family.append(placement_id)
				continue
			updated.append(placement)
		for baseline_placement in baseline_placements:
			if not (baseline_placement is Dictionary):
				continue
			var placement_id := String(baseline_placement.get("placement_id", ""))
			if placement_id in restored_for_family:
				continue
			updated.append(baseline_placement.duplicate(true))
			restored_for_family.append(placement_id)
		_session.overworld[array_key] = updated
		restored_ids.append_array(restored_for_family)
		removed_ids.append_array(removed_for_family)
		if family == OBJECT_FAMILY_ENCOUNTER:
			var encounter_ids_to_unresolve := []
			encounter_ids_to_unresolve.append_array(restored_for_family)
			encounter_ids_to_unresolve.append_array(removed_for_family)
			_remove_resolved_encounter_ids(encounter_ids_to_unresolve)
	return {
		"ok": true,
		"restored_ids": restored_ids,
		"removed_ids": removed_ids,
	}

func _placements_for_family_at_in_session(session, family: String, tile: Vector2i) -> Array:
	var placements_at_tile := []
	if session == null:
		return placements_at_tile
	var array_key := _placement_array_key(family)
	var placements = session.overworld.get(array_key, [])
	if not (placements is Array):
		return placements_at_tile
	for placement in placements:
		if placement is Dictionary and _placement_at_tile(placement, tile):
			placements_at_tile.append(placement.duplicate(true))
	return placements_at_tile

func _road_layers_at_in_overworld(overworld: Dictionary, tile: Vector2i) -> Array:
	var matching_roads := []
	var terrain_layers = overworld.get("terrain_layers", {})
	if not (terrain_layers is Dictionary):
		return matching_roads
	var roads = terrain_layers.get("roads", [])
	if not (roads is Array):
		return matching_roads
	for road in roads:
		if not (road is Dictionary):
			continue
		var tiles = road.get("tiles", [])
		if not (tiles is Array):
			continue
		for tile_value in tiles:
			if _tile_payload_matches(tile_value, tile):
				matching_roads.append(road.duplicate(true))
				break
	return matching_roads

func _authored_road_tile_payload(road: Dictionary, tile: Vector2i) -> Dictionary:
	var tiles = road.get("tiles", [])
	if tiles is Array:
		for tile_value in tiles:
			if _tile_payload_matches(tile_value, tile):
				return _tile_payload_for_restore(tile_value, tile)
	return {"x": tile.x, "y": tile.y}

func _tile_payload_for_restore(value: Variant, tile: Vector2i) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {"x": tile.x, "y": tile.y}

func _tile_payload_matches(value: Variant, tile: Vector2i) -> bool:
	return value is Dictionary and int(value.get("x", -999)) == tile.x and int(value.get("y", -999)) == tile.y

func _terrain_at_in_overworld(overworld: Dictionary, tile: Vector2i) -> String:
	var map_data = overworld.get("map", [])
	if not (map_data is Array) or tile.y < 0 or tile.y >= map_data.size():
		return ""
	var row = map_data[tile.y]
	if not (row is Array) or tile.x < 0 or tile.x >= row.size():
		return ""
	return String(row[tile.x])

func _set_tile_terrain(tile: Vector2i, terrain_id: String) -> bool:
	if not _tile_in_bounds(tile) or terrain_id == "":
		return false
	var map_data = _session.overworld.get("map", [])
	if not (map_data is Array) or tile.y >= map_data.size():
		return false
	var row = map_data[tile.y]
	if not (row is Array) or tile.x >= row.size():
		return false
	row[tile.x] = terrain_id
	map_data[tile.y] = row
	_session.overworld["map"] = map_data
	return true

func _remove_stale_editor_object_keys() -> void:
	if _selected_property_object_key != "" and _object_detail_by_key(_selected_property_object_key).is_empty():
		_selected_property_object_key = ""
	if _pending_move_object_key != "" and _object_detail_by_key(_pending_move_object_key).is_empty():
		_pending_move_object_key = ""
	if _pending_duplicate_object_key != "" and _object_detail_by_key(_pending_duplicate_object_key).is_empty():
		_pending_duplicate_object_key = ""

func _on_play_working_copy_pressed() -> void:
	if _session == null:
		return
	_prepare_working_copy_snapshot_for_return()
	SessionState.set_editor_working_copy_session(_session)
	var play_session = SessionState.duplicate_editor_working_copy_session()
	if play_session == null:
		_last_message = "Could not stage the editor working copy for play."
		_refresh_state()
		return
	_prepare_working_copy_for_play(play_session)
	SessionState.set_active_session(play_session)
	AppRouter.go_to_overworld()

func _editor_play_readiness_gate_payload() -> Dictionary:
	if _session == null:
		return {
			"button_label": "Play Copy",
			"text": "",
			"tooltip": "Load a scenario working copy before play-testing it.",
			"state": "no_working_copy",
		}
	var validation := _scenario_authoring_validation_payload()
	var warning_count := int(validation.get("warning_count", 0))
	var covered_count := int(validation.get("covered_objective_anchor_count", 0))
	var objective_count := int(validation.get("objective_anchors", []).size())
	var missing_count := int(validation.get("missing_objective_anchor_count", 0))
	var hero_position := OverworldRules.hero_position(_session)
	var ready := warning_count == 0 and missing_count == 0
	var state := "ready" if ready else "review"
	var action := "Play Copy can smoke-test this working copy" if ready else "Review warnings before Play Copy"
	var text := "Play gate: %s | Objectives %d/%d covered | Warnings %d | Hero %d,%d | Objects %d." % [
		action,
		covered_count,
		objective_count,
		warning_count,
		hero_position.x,
		hero_position.y,
		_placement_count(),
	]
	var warnings: Array = validation.get("warnings", [])
	var first_warning := String(warnings[0]).strip_edges() if not warnings.is_empty() else ""
	return {
		"button_label": "Play Copy Ready" if ready else "Play Copy Check",
		"text": text,
		"tooltip": "%s\n%s" % [text, first_warning] if first_warning != "" else text,
		"state": state,
		"ready": ready,
		"action": action,
		"covered_objective_anchor_count": covered_count,
		"objective_anchor_count": objective_count,
		"missing_objective_anchor_count": missing_count,
		"warning_count": warning_count,
		"first_warning": first_warning,
		"hero_position": {"x": hero_position.x, "y": hero_position.y},
		"object_count": _placement_count(),
	}

func _editor_play_handoff_payload() -> Dictionary:
	if _session == null:
		return {
			"button_label": "Play Copy",
			"text": "",
			"tooltip": "Load a scenario working copy before play-testing it.",
			"state_context": "no_working_copy",
		}
	var scenario := ContentService.get_scenario(_session.scenario_id)
	var scenario_name := String(scenario.get("name", _session.scenario_id))
	var map_size := OverworldRules.derive_map_size(_session)
	var hero_position := OverworldRules.hero_position(_session)
	var state_context := "edited in-memory working copy" if _dirty else "authored working copy"
	var return_context := "return restores the editor launch snapshot"
	var write_context := "no authored file or campaign progress is written"
	var text := "Play handoff: %s launches %s; %s; %s." % [
		scenario_name,
		state_context,
		return_context,
		write_context,
	]
	return {
		"button_label": "Play Copy",
		"text": text,
		"tooltip": "%s\nMap %dx%d | Objects %d | Hero start %d,%d." % [
			text,
			map_size.x,
			map_size.y,
			_placement_count(),
			hero_position.x,
			hero_position.y,
		],
		"scenario_id": _session.scenario_id,
		"scenario_name": scenario_name,
		"state_context": state_context,
		"return_context": return_context,
		"write_context": write_context,
		"return_model": "launch_snapshot",
		"dirty": _dirty,
		"map_size": {"x": map_size.x, "y": map_size.y},
		"object_count": _placement_count(),
		"hero_position": {"x": hero_position.x, "y": hero_position.y},
	}

func _editor_play_return_context_payload() -> Dictionary:
	if _session == null or not _restored_from_play_copy:
		return {
			"text": "",
			"tooltip": "",
			"restored": false,
		}
	var scenario := ContentService.get_scenario(_session.scenario_id)
	var scenario_name := String(scenario.get("name", _session.scenario_id))
	var map_size := OverworldRules.derive_map_size(_session)
	var hero_position := OverworldRules.hero_position(_session)
	var return_model := String(_session.flags.get("editor_return_model", "launch_snapshot"))
	var dirty_text := "unsaved edits still in memory" if _dirty else "authored working copy unchanged"
	var text := "Play return: launch snapshot restored; live play mutations discarded; Hero %d,%d | Selected %d,%d | Objects %d | Next: edit the working copy or launch Play Copy again." % [
		hero_position.x,
		hero_position.y,
		_selected_tile.x,
		_selected_tile.y,
		_placement_count(),
	]
	return {
		"text": text,
		"tooltip": "%s\n%s | Map %dx%d | Return model %s | %s | Next: edit the working copy or launch Play Copy again." % [
			text,
			scenario_name,
			map_size.x,
			map_size.y,
			return_model,
			dirty_text,
		],
		"restored": true,
		"scenario_id": _session.scenario_id,
		"scenario_name": scenario_name,
		"return_model": return_model,
		"hero_position": {"x": hero_position.x, "y": hero_position.y},
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"object_count": _placement_count(),
		"dirty": _dirty,
	}

func _editor_active_tool_cue_payload(tool: String = "") -> Dictionary:
	var tool_id := _tool if tool == "" else tool
	var selected_text := "%d,%d" % [_selected_tile.x, _selected_tile.y]
	var hovered_text := "%d,%d" % [_hovered_tile.x, _hovered_tile.y] if _tile_in_bounds(_hovered_tile) else "none"
	var action := ""
	var next_step := ""
	var detail := ""
	match tool_id:
		TOOL_TERRAIN:
			action = "paint %s terrain" % _terrain_label_for_id(_selected_terrain_id)
			next_step = "click a map tile to apply the active brush"
			detail = "Brush %s" % _terrain_label_for_id(_selected_terrain_id)
		TOOL_TERRAIN_LINE:
			action = "paint a %s terrain line" % _terrain_label_for_id(_selected_terrain_id)
			if _has_pending_terrain_line_start():
				next_step = "click the line end; start is %d,%d" % [_pending_terrain_line_start.x, _pending_terrain_line_start.y]
			else:
				next_step = "click the first line tile"
			detail = TERRAIN_LINE_RULE_LABEL
		TOOL_TERRAIN_RECTANGLE:
			action = "paint a %s terrain rectangle" % _terrain_label_for_id(_selected_terrain_id)
			if _has_pending_terrain_rectangle_corner():
				next_step = "click the opposite corner; first corner is %d,%d" % [_pending_terrain_rectangle_corner.x, _pending_terrain_rectangle_corner.y]
			else:
				next_step = "click the first rectangle corner"
			detail = TERRAIN_RECTANGLE_RULE_LABEL
		TOOL_ROAD:
			action = "toggle the editor road overlay"
			next_step = "click a map tile to add or remove road"
			detail = "Road layer %s" % EDITOR_ROAD_LAYER_ID
		TOOL_ROAD_PATH:
			action = "paint a road path"
			if _has_pending_road_path_start():
				next_step = "click the path end; start is %d,%d" % [_pending_road_path_start.x, _pending_road_path_start.y]
			else:
				next_step = "click the first path tile"
			detail = ROAD_PATH_RULE_LABEL
		TOOL_HERO_START:
			action = "move the playable hero start"
			next_step = "click the new starting tile"
			var hero_position := OverworldRules.hero_position(_session) if _session != null else _selected_tile
			detail = "Current hero start %d,%d" % [hero_position.x, hero_position.y]
		TOOL_PLACE_OBJECT:
			action = "place %s %s" % [_object_family_label(_selected_object_family).to_lower(), _selected_object_content_label()]
			next_step = "click a valid map tile or review the placement preview"
			detail = "Palette %s:%s" % [_object_family_label(_selected_object_family), _selected_object_content_id]
		TOOL_REMOVE_OBJECT:
			action = "remove an object from the selected family"
			next_step = "click a tile containing a %s" % _object_family_label(_selected_object_family).to_lower()
			detail = "Family %s" % _object_family_label(_selected_object_family)
		TOOL_MOVE_OBJECT:
			action = "move an existing object"
			if _pending_move_object_key != "":
				var move_detail := _object_detail_by_key(_pending_move_object_key)
				next_step = "click the destination for %s" % String(move_detail.get("placement_id", _pending_move_object_key))
			else:
				next_step = "click an object to pick it up"
			detail = "Family %s" % _object_family_label(_selected_object_family)
		TOOL_DUPLICATE_OBJECT:
			action = "duplicate an existing object"
			if _pending_duplicate_object_key != "":
				var duplicate_detail := _object_detail_by_key(_pending_duplicate_object_key)
				next_step = "click the destination for a copy of %s" % String(duplicate_detail.get("placement_id", _pending_duplicate_object_key))
			else:
				next_step = "click an object to copy it"
			detail = "Family %s" % _object_family_label(_selected_object_family)
		TOOL_RETHEME_OBJECT:
			action = "replace an object's content with %s" % _selected_object_content_label()
			next_step = "click a matching object to retheme it"
			detail = "Palette %s:%s" % [_object_family_label(_selected_object_family), _selected_object_content_id]
		_:
			action = "inspect map content"
			next_step = "click a tile to show terrain, objects, links, and authoring checks"
			detail = "Read-only selection"
	var action_sentence := action.substr(0, 1).to_upper() + action.substr(1)
	var text := "Tool cue: Selected %s | %s; next: %s | %s." % [selected_text, action_sentence, next_step, detail]
	return {
		"tool": tool_id,
		"label": _tool_label(tool_id),
		"text": text,
		"tooltip": "Active tool: %s\n%s\nSelected %s | Hover %s | %s." % [
			_tool_label(tool_id),
			text,
			selected_text,
			hovered_text,
			detail,
		],
		"action": action,
		"next_step": next_step,
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"hovered_tile": {"x": _hovered_tile.x, "y": _hovered_tile.y} if _tile_in_bounds(_hovered_tile) else {},
		"detail": detail,
	}

func _selected_object_content_label() -> String:
	if _selected_object_content_id == "":
		return "selected content"
	var entry := _object_content_lookup(_selected_object_family, _selected_object_content_id)
	if entry.is_empty():
		return _selected_object_content_id
	return String(entry.get("name", _selected_object_content_id))

func _prepare_working_copy_snapshot_for_return() -> void:
	_session.flags["editor_working_copy"] = true
	_session.flags["editor_source_scenario_id"] = _session.scenario_id
	_session.flags["editor_return_model"] = "launch_snapshot"
	_session.flags["editor_dirty"] = _dirty
	_session.flags["editor_selected_tile"] = {"x": _selected_tile.x, "y": _selected_tile.y}
	_session.flags["editor_selected_terrain_id"] = _selected_terrain_id
	_session.flags["editor_selected_object_family"] = _selected_object_family
	_session.flags["editor_selected_object_content_id"] = _selected_object_content_id
	_session.flags["editor_selected_property_object_key"] = _selected_property_object_key
	_session.flags["editor_pending_move_object_key"] = _pending_move_object_key
	_session.flags["editor_pending_duplicate_object_key"] = _pending_duplicate_object_key
	_session.flags["editor_pending_terrain_line_start"] = _pending_terrain_line_start_payload()
	_session.flags["editor_pending_terrain_rectangle_corner"] = _pending_terrain_rectangle_corner_payload()
	_session.flags["editor_pending_road_path_start"] = _pending_road_path_start_payload()
	_session.game_state = "overworld"
	_session.scenario_status = "in_progress"
	_session.battle = {}

func _prepare_working_copy_for_play(session) -> void:
	session.flags["editor_working_copy"] = true
	session.flags["editor_source_scenario_id"] = session.scenario_id
	session.flags["editor_return_model"] = "launch_snapshot"
	session.flags["editor_started_at"] = Time.get_datetime_string_from_system(true)
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	session.battle = {}
	OverworldRules.refresh_fog_of_war(session)

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
				_append_taxonomy_object_lines(lines, detail)
				_append_authoring_dependency_lines(lines, detail)
			OBJECT_FAMILY_RESOURCE:
				lines.append("Site: %s | placement %s | content %s | family %s | collected %s" % [
					String(detail.get("name", "")),
					String(detail.get("placement_id", "")),
					String(detail.get("content_id", "")),
					String(detail.get("family", "")),
					"yes" if bool(detail.get("collected", false)) else "no",
				])
				_append_resource_control_lines(lines, detail)
				_append_taxonomy_object_lines(lines, detail)
				_append_authoring_dependency_lines(lines, detail)
			OBJECT_FAMILY_ARTIFACT:
				lines.append("Artifact: %s | placement %s | content %s | collected %s" % [
					String(detail.get("name", "")),
					String(detail.get("placement_id", "")),
					String(detail.get("content_id", "")),
					"yes" if bool(detail.get("collected", false)) else "no",
				])
				_append_taxonomy_object_lines(lines, detail)
				_append_authoring_dependency_lines(lines, detail)
			OBJECT_FAMILY_ENCOUNTER:
				lines.append("Encounter: %s | placement %s | content %s | difficulty %s" % [
					String(detail.get("name", "")),
					String(detail.get("placement_id", "")),
					String(detail.get("content_id", "")),
					String(detail.get("difficulty", "medium")),
				])
				_append_taxonomy_object_lines(lines, detail)
				_append_authoring_dependency_lines(lines, detail)
	return lines

func _append_taxonomy_object_lines(lines: Array, detail: Dictionary) -> void:
	var taxonomy = detail.get("taxonomy", {})
	if not (taxonomy is Dictionary) or taxonomy.is_empty():
		return
	var summary := _taxonomy_inline_text(taxonomy)
	if summary != "":
		lines.append("  Taxonomy: %s" % summary)
	var link_line := _taxonomy_link_line(taxonomy)
	if link_line != "":
		lines.append("  Link: %s" % link_line)
	var role_line := _taxonomy_role_line(taxonomy)
	if role_line != "":
		lines.append("  Role: %s" % role_line)
	var guard_link_surface := String(taxonomy.get("guard_link_surface", "")).strip_edges()
	if guard_link_surface != "":
		lines.append("  Guard Link: %s" % guard_link_surface)
	var consequence_summary := String(taxonomy.get("consequence_summary", "")).strip_edges()
	if consequence_summary != "":
		lines.append("  %s" % consequence_summary)
	for identity_line in _identity_summary_lines_for_editor(taxonomy, 3):
		lines.append("  %s" % identity_line)
	var guidance := _placement_guidance_payload(taxonomy, Vector2i(int(detail.get("x", 0)), int(detail.get("y", 0))))
	if not guidance.is_empty():
		lines.append("  Place: %s | Density %s" % [
			String(guidance.get("placement_role", "")),
			String(guidance.get("density_target", "")),
		])
		lines.append("  Flags: %s | Local %d in 16x16" % [
			String(guidance.get("role_flags_text", "")),
			int(guidance.get("local_density_count", 0)),
		])

func _append_authoring_dependency_lines(lines: Array, detail: Dictionary) -> void:
	var dependencies = detail.get("authoring_dependencies", {})
	if not (dependencies is Dictionary) or dependencies.is_empty():
		return
	var objective_links: Array = dependencies.get("objective_links", [])
	for index in range(min(2, objective_links.size())):
		var link = objective_links[index]
		if not (link is Dictionary):
			continue
		lines.append("  Objective: %s %s" % [
			String(link.get("bucket", "")).capitalize(),
			String(link.get("label", link.get("id", ""))),
		])
	var guard_links: Array = dependencies.get("guard_links", [])
	for index in range(min(2, guard_links.size())):
		var guard = guard_links[index]
		if not (guard is Dictionary):
			continue
		if String(guard.get("role", "")) == "guards":
			lines.append("  Guards: %s%s" % [
				String(guard.get("target_label", "target")),
				" | clear required" if bool(guard.get("clear_required", false)) else "",
			])
		else:
			lines.append("  Guarded by: %s" % String(guard.get("source_label", "encounter")))
	var route_links: Array = dependencies.get("route_links", [])
	if not route_links.is_empty():
		var route = route_links[0]
		if route is Dictionary:
			lines.append("  Route: %s" % String(route.get("route_id", route.get("role", ""))))
	var reward_links: Array = dependencies.get("reward_links", [])
	if not reward_links.is_empty():
		var reward_labels := []
		for index in range(min(2, reward_links.size())):
			var reward = reward_links[index]
			if reward is Dictionary:
				reward_labels.append(String(reward.get("label", reward.get("effect_type", ""))))
		if not reward_labels.is_empty():
			lines.append("  Follow-up: %s" % "; ".join(reward_labels))
	var enemy_focus_links: Array = dependencies.get("enemy_focus_links", [])
	if not enemy_focus_links.is_empty():
		var focus = enemy_focus_links[0]
		if focus is Dictionary:
			lines.append("  Enemy focus: %s | %s" % [
				String(focus.get("label", "")),
				String(focus.get("role", "")),
			])
	var warnings: Array = dependencies.get("warnings", [])
	for index in range(min(2, warnings.size())):
		lines.append("  Warning: %s" % String(warnings[index]))

func _append_resource_control_lines(lines: Array, detail: Dictionary) -> void:
	var control_inspection := String(detail.get("control_inspection", "")).strip_edges()
	if control_inspection == "":
		var taxonomy = detail.get("taxonomy", {})
		if taxonomy is Dictionary:
			control_inspection = String(taxonomy.get("control_inspection", "")).strip_edges()
	if control_inspection == "":
		return
	for raw_line in control_inspection.split("\n"):
		var line := String(raw_line).strip_edges()
		if line != "":
			lines.append("  %s" % line)
	var recruit_inspection := String(detail.get("recruit_source_inspection", "")).strip_edges()
	if recruit_inspection == "":
		var recruit_taxonomy = detail.get("taxonomy", {})
		if recruit_taxonomy is Dictionary:
			recruit_inspection = String(recruit_taxonomy.get("recruit_source_inspection", "")).strip_edges()
	if recruit_inspection == "" or control_inspection.find(recruit_inspection) >= 0:
		return
	for raw_line in recruit_inspection.split("\n"):
		var line := String(raw_line).strip_edges()
		if line != "":
			lines.append("  %s" % line)

func _object_detail_for_placement(family: String, placement: Dictionary) -> Dictionary:
	match family:
		OBJECT_FAMILY_TOWN:
			var town := ContentService.get_town(String(placement.get("town_id", "")))
			var town_taxonomy := _town_taxonomy_payload(town)
			return {
				"kind": OBJECT_FAMILY_TOWN,
				"placement_id": String(placement.get("placement_id", "")),
				"content_id": String(placement.get("town_id", "")),
				"name": String(town.get("name", placement.get("town_id", ""))),
				"owner": String(placement.get("owner", "neutral")),
				"taxonomy": town_taxonomy,
				"taxonomy_summary": _taxonomy_inline_text(town_taxonomy),
				"property_key": _object_property_key(OBJECT_FAMILY_TOWN, String(placement.get("placement_id", ""))),
				"editable_properties": _editable_properties_for_object(OBJECT_FAMILY_TOWN),
				"x": int(placement.get("x", 0)),
				"y": int(placement.get("y", 0)),
			}
		OBJECT_FAMILY_RESOURCE:
			var site := ContentService.get_resource_site(String(placement.get("site_id", "")))
			var resource_taxonomy := _resource_taxonomy_payload(placement, site)
			var control_inspection := OverworldRules.describe_resource_site_control_inspection(_session, placement, site)
			return {
				"kind": OBJECT_FAMILY_RESOURCE,
				"placement_id": String(placement.get("placement_id", "")),
				"content_id": String(placement.get("site_id", "")),
				"name": String(site.get("name", placement.get("site_id", ""))),
				"family": String(site.get("family", "one_shot_pickup")),
				"collected": bool(placement.get("collected", false)),
				"collected_by_faction_id": String(placement.get("collected_by_faction_id", "")),
				"collected_day": max(0, int(placement.get("collected_day", 0))),
				"taxonomy": resource_taxonomy,
				"taxonomy_summary": _taxonomy_inline_text(resource_taxonomy),
				"control_summary": OverworldRules.describe_resource_site_control_summary(_session, placement, site),
				"control_inspection": control_inspection,
				"recruit_source_inspection": String(resource_taxonomy.get("recruit_source_inspection", "")),
				"property_key": _object_property_key(OBJECT_FAMILY_RESOURCE, String(placement.get("placement_id", ""))),
				"editable_properties": _editable_properties_for_object(OBJECT_FAMILY_RESOURCE),
				"x": int(placement.get("x", 0)),
				"y": int(placement.get("y", 0)),
			}
		OBJECT_FAMILY_ARTIFACT:
			var artifact := ContentService.get_artifact(String(placement.get("artifact_id", "")))
			var artifact_taxonomy := _artifact_taxonomy_payload(artifact)
			return {
				"kind": OBJECT_FAMILY_ARTIFACT,
				"placement_id": String(placement.get("placement_id", "")),
				"content_id": String(placement.get("artifact_id", "")),
				"name": String(artifact.get("name", placement.get("artifact_id", ""))),
				"collected": bool(placement.get("collected", false)),
				"collected_by_faction_id": String(placement.get("collected_by_faction_id", "")),
				"collected_day": max(0, int(placement.get("collected_day", 0))),
				"taxonomy": artifact_taxonomy,
				"taxonomy_summary": _taxonomy_inline_text(artifact_taxonomy),
				"property_key": _object_property_key(OBJECT_FAMILY_ARTIFACT, String(placement.get("placement_id", ""))),
				"editable_properties": _editable_properties_for_object(OBJECT_FAMILY_ARTIFACT),
				"x": int(placement.get("x", 0)),
				"y": int(placement.get("y", 0)),
			}
		OBJECT_FAMILY_ENCOUNTER:
			var encounter := ContentService.get_encounter(String(placement.get("encounter_id", "")))
			var encounter_taxonomy := _encounter_taxonomy_payload(placement, encounter)
			return {
				"kind": OBJECT_FAMILY_ENCOUNTER,
				"placement_id": String(placement.get("placement_id", "")),
				"content_id": String(placement.get("encounter_id", "")),
				"name": String(encounter.get("name", placement.get("encounter_id", ""))),
				"difficulty": String(placement.get("difficulty", "medium")),
				"combat_seed": int(placement.get("combat_seed", 0)),
				"taxonomy": encounter_taxonomy,
				"taxonomy_summary": _taxonomy_inline_text(encounter_taxonomy),
				"property_key": _object_property_key(OBJECT_FAMILY_ENCOUNTER, String(placement.get("placement_id", ""))),
				"editable_properties": _editable_properties_for_object(OBJECT_FAMILY_ENCOUNTER),
				"x": int(placement.get("x", 0)),
				"y": int(placement.get("y", 0)),
			}
		_:
			return {}

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
			details.append(_object_detail_with_guidance(_object_detail_for_placement(OBJECT_FAMILY_TOWN, town_value), tile))
	for node_value in _session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and _placement_at_tile(node_value, tile):
			details.append(_object_detail_with_guidance(_object_detail_for_placement(OBJECT_FAMILY_RESOURCE, node_value), tile))
	for artifact_value in _session.overworld.get("artifact_nodes", []):
		if artifact_value is Dictionary and _placement_at_tile(artifact_value, tile):
			details.append(_object_detail_with_guidance(_object_detail_for_placement(OBJECT_FAMILY_ARTIFACT, artifact_value), tile))
	for encounter_value in _session.overworld.get("encounters", []):
		if encounter_value is Dictionary and _placement_at_tile(encounter_value, tile):
			details.append(_object_detail_with_guidance(_object_detail_for_placement(OBJECT_FAMILY_ENCOUNTER, encounter_value), tile))
	return details

func _object_detail_with_guidance(detail: Dictionary, tile: Vector2i) -> Dictionary:
	if detail.is_empty():
		return detail
	var taxonomy = detail.get("taxonomy", {})
	if taxonomy is Dictionary:
		detail["placement_guidance"] = _placement_guidance_payload(taxonomy, tile)
	detail["authoring_dependencies"] = _authoring_dependencies_for_detail(detail)
	return detail

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

func _placement_content_key(family: String) -> String:
	match family:
		OBJECT_FAMILY_TOWN:
			return "town_id"
		OBJECT_FAMILY_RESOURCE:
			return "site_id"
		OBJECT_FAMILY_ARTIFACT:
			return "artifact_id"
		OBJECT_FAMILY_ENCOUNTER:
			return "encounter_id"
		_:
			return ""

func _object_property_key(kind: String, placement_id: String) -> String:
	if kind == "" or placement_id == "":
		return ""
	return "%s:%s" % [kind, placement_id]

func _editable_properties_for_object(kind: String) -> Array:
	match kind:
		OBJECT_FAMILY_TOWN:
			return [PROPERTY_TOWN_OWNER]
		OBJECT_FAMILY_RESOURCE:
			return [PROPERTY_COLLECTED]
		OBJECT_FAMILY_ARTIFACT:
			return [PROPERTY_COLLECTED]
		OBJECT_FAMILY_ENCOUNTER:
			return [PROPERTY_ENCOUNTER_DIFFICULTY]
		_:
			return []

func _primary_editable_property_for_kind(kind: String) -> String:
	var properties := _editable_properties_for_object(kind)
	return String(properties[0]) if not properties.is_empty() else ""

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

func _generate_duplicate_placement_id(family: String, source_placement_id: String, tile: Vector2i) -> String:
	var base_id := "editor_duplicate_%s_%s_%d_%d" % [
		_safe_id_segment(family),
		_safe_id_segment(source_placement_id),
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

func _terrain_id_in_grammar(terrain_id: String) -> bool:
	if terrain_id == "":
		return false
	for authored_terrain_id in _authored_terrain_ids():
		if String(authored_terrain_id) == terrain_id:
			return true
	return false

func _tile_in_bounds(tile: Vector2i) -> bool:
	if _session == null:
		return false
	var map_size := OverworldRules.derive_map_size(_session)
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

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
	for button in [_inspect_tool_button, _terrain_tool_button, _terrain_line_tool_button, _terrain_rectangle_tool_button, _road_tool_button, _road_path_tool_button, _hero_start_tool_button, _place_object_tool_button, _remove_object_tool_button, _move_object_tool_button, _duplicate_object_tool_button, _retheme_object_tool_button, _fill_terrain_button, _restore_tile_button, _property_apply_button, _play_button, _menu_button]:
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
	var hero_pos := OverworldRules.hero_position(_session) if _session != null else Vector2i.ZERO
	return {
		"scene_path": scene_file_path,
		"scenario_id": _session.scenario_id if _session != null else "",
		"working_copy": _session != null,
		"restored_from_play_copy": _restored_from_play_copy,
		"return_model": String(_session.flags.get("editor_return_model", "")) if _session != null else "",
		"dirty": _dirty,
		"status_text": _last_message,
		"visible_status_text": _status_label.text if _status_label != null else "",
		"visible_status_full": _status_label.tooltip_text if _status_label != null else "",
		"play_readiness_gate": _editor_play_readiness_gate_payload(),
		"play_readiness_gate_text": String(_editor_play_readiness_gate_payload().get("text", "")),
		"play_handoff": _editor_play_handoff_payload(),
		"play_handoff_text": String(_editor_play_handoff_payload().get("text", "")),
		"play_return_context": _editor_play_return_context_payload(),
		"play_return_context_text": String(_editor_play_return_context_payload().get("text", "")),
		"play_button_text": _play_button.text if _play_button != null else "",
		"play_button_tooltip": _play_button.tooltip_text if _play_button != null else "",
		"active_tool_cue": _editor_active_tool_cue_payload(),
		"active_tool_cue_text": String(_editor_active_tool_cue_payload().get("text", "")),
		"active_tool_cue_tooltip": String(_editor_active_tool_cue_payload().get("tooltip", "")),
		"map_tooltip": _map_view.tooltip_text if _map_view != null else "",
		"editor_acceptance_cue": _editor_acceptance_cue_payload(),
		"last_object_authoring_recap": _last_object_authoring_recap,
		"tool": _tool,
		"selected_terrain_id": _selected_terrain_id,
		"selected_terrain_label": _terrain_label_for_id(_selected_terrain_id),
		"terrain_option_contract": TERRAIN_OPTION_CONTRACT,
		"terrain_option_source": TERRAIN_OPTION_SOURCE,
		"terrain_options": _terrain_option_payload(),
		"terrain_option_ids": _terrain_option_ids(),
		"authored_terrain_ids": _authored_terrain_ids(),
		"hidden_terrain_ids": _hidden_terrain_ids(),
		"terrain_paint_order": _terrain_paint_order,
		"terrain_placement": _last_terrain_placement_result,
		"editor_restamp": _editor_restamp_payload_for_tile(_selected_tile),
		"selected_object_family": _selected_object_family,
		"selected_object_content_id": _selected_object_content_id,
		"selected_object_taxonomy": _object_content_taxonomy_payload(_selected_object_family, _selected_object_content_id),
		"selected_object_guidance": _placement_guidance_payload(_object_content_taxonomy_payload(_selected_object_family, _selected_object_content_id), _selected_tile),
		"selected_object_placement_preview": _selected_object_placement_preview_payload(_placement_preview_tile()),
		"selected_object_palette_text": _object_taxonomy_summary_label.tooltip_text if _object_taxonomy_summary_label != null else "",
		"selected_property_object_key": _selected_property_object_key,
		"selected_property_object": _selected_property_object_payload(),
		"pending_move_object_key": _pending_move_object_key,
		"pending_move_object": _pending_move_object_payload(),
		"pending_duplicate_object_key": _pending_duplicate_object_key,
		"pending_duplicate_object": _pending_duplicate_object_payload(),
		"pending_terrain_line_start": _pending_terrain_line_start_payload(),
		"terrain_line_rule": TERRAIN_LINE_RULE_ID,
		"terrain_line_rule_label": TERRAIN_LINE_RULE_LABEL,
		"pending_terrain_rectangle_corner": _pending_terrain_rectangle_corner_payload(),
		"terrain_rectangle_rule": TERRAIN_RECTANGLE_RULE_ID,
		"terrain_rectangle_rule_label": TERRAIN_RECTANGLE_RULE_LABEL,
		"terrain_rectangle_tile_order": TERRAIN_RECTANGLE_TILE_ORDER,
		"pending_road_path_start": _pending_road_path_start_payload(),
		"road_path_rule": ROAD_PATH_RULE_ID,
		"road_path_rule_label": ROAD_PATH_RULE_LABEL,
		"hero_position": {"x": hero_pos.x, "y": hero_pos.y},
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"hovered_tile": {"x": _hovered_tile.x, "y": _hovered_tile.y},
		"map_size": {"x": map_size.x, "y": map_size.y},
		"road_tile_count": _road_tile_count(),
		"placement_count": _placement_count(),
		"scenario_authoring_validation": _scenario_authoring_validation_payload(),
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
	if _select_terrain_by_id(terrain_id):
		var terrain_tool := _tool if _tool in [TOOL_TERRAIN_LINE, TOOL_TERRAIN_RECTANGLE] else TOOL_TERRAIN
		_select_tool(terrain_tool)
		var snapshot := validation_snapshot()
		snapshot["ok"] = true
		return snapshot
	return {"ok": false, "message": "Terrain id is not in the editor base terrain options."}

func validation_paint_terrain(x: int, y: int, terrain_id: String) -> Dictionary:
	if not _terrain_id_in_grammar(terrain_id):
		var invalid_snapshot := validation_snapshot()
		invalid_snapshot["ok"] = false
		invalid_snapshot["message"] = "Terrain id %s is not in the authored terrain grammar." % terrain_id
		return invalid_snapshot
	_selected_tile = Vector2i(x, y)
	var previous_terrain := _terrain_at(_selected_tile)
	_select_terrain_by_id(terrain_id)
	_tool = TOOL_TERRAIN
	var changed := _paint_terrain(_selected_tile, terrain_id)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	snapshot["painted_tile"] = {"x": _selected_tile.x, "y": _selected_tile.y}
	snapshot["paint_previous_terrain_id"] = previous_terrain
	snapshot["paint_new_terrain_id"] = terrain_id
	snapshot["paint_changed"] = previous_terrain != terrain_id and changed
	snapshot["terrain_paint_order"] = _terrain_paint_order
	snapshot["terrain_placement"] = _last_terrain_placement_result
	snapshot["owner_changed_count"] = int(_last_terrain_placement_result.get("owner_changed_count", 0))
	snapshot["changed_tiles"] = _last_terrain_placement_result.get("changed_tiles", [])
	snapshot["owner_changed_tiles"] = _last_terrain_placement_result.get("owner_changed_tiles", [])
	snapshot["final_normalization"] = _last_terrain_placement_result.get("final_normalization", {})
	snapshot["editor_restamp"] = _editor_restamp_payload_for_tile(_selected_tile)
	return snapshot

func validation_seed_terrain_direct(x: int, y: int, terrain_id: String) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	if not _terrain_id_in_grammar(terrain_id):
		return {"ok": false, "message": "Terrain id %s is not in the authored terrain grammar." % terrain_id}
	_selected_tile = tile
	var previous_terrain := _terrain_at(tile)
	var changed := previous_terrain != terrain_id and _set_tile_terrain(tile, terrain_id)
	if changed:
		_dirty = true
	var previous_terrain_by_tile := {}
	previous_terrain_by_tile[_tile_key(tile)] = previous_terrain
	_last_terrain_placement_result = {
		"ok": true,
		"changed": changed,
		"placement_model": "direct_validation_seed_no_homm3_queue",
		"brush_terrain_id": terrain_id,
		"requested_tiles": [{"x": tile.x, "y": tile.y}],
		"changed_tiles": [{"x": tile.x, "y": tile.y}] if changed else [],
		"owner_changed_tiles": [],
		"owner_changed_count": 0,
		"previous_terrain_by_tile": previous_terrain_by_tile,
	}
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	snapshot["changed"] = changed
	snapshot["seed_previous_terrain_id"] = previous_terrain
	snapshot["seed_new_terrain_id"] = terrain_id
	return snapshot

func validation_fill_terrain(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	_selected_tile = tile
	var result := {}
	if terrain_selected:
		result = _fill_terrain_region(_selected_tile, _selected_terrain_id)
	else:
		result = {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not in the editor base terrain options." % terrain_id,
		}
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["terrain_selected"] = terrain_selected
	snapshot["fill_result"] = result
	snapshot["filled_count"] = int(result.get("filled_count", 0))
	snapshot["affected_count"] = int(result.get("affected_count", 0))
	snapshot["owner_changed_count"] = int(result.get("owner_changed_count", 0))
	snapshot["changed_tiles"] = result.get("changed_tiles", [])
	snapshot["owner_changed_tiles"] = result.get("owner_changed_tiles", [])
	snapshot["terrain_placement"] = result.get("terrain_placement", _last_terrain_placement_result)
	snapshot["source_terrain_id"] = String(result.get("source_terrain_id", ""))
	snapshot["active_terrain_id"] = String(result.get("active_terrain_id", _selected_terrain_id))
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_set_terrain_line_start(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map.", "path_rule": TERRAIN_LINE_RULE_ID}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	_selected_tile = tile
	_tool = TOOL_TERRAIN_LINE
	_pending_terrain_line_start = tile
	_last_message = "Terrain line start set at %d,%d. Apply uses %s with %s." % [
		x,
		y,
		TERRAIN_LINE_RULE_LABEL,
		_selected_terrain_id,
	]
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = terrain_selected
	snapshot["terrain_selected"] = terrain_selected
	snapshot["path_rule"] = TERRAIN_LINE_RULE_ID
	snapshot["path_rule_label"] = TERRAIN_LINE_RULE_LABEL
	return snapshot

func validation_apply_terrain_line(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var end_tile := Vector2i(x, y)
	if not _tile_in_bounds(end_tile):
		return {"ok": false, "message": "Tile outside map.", "path_rule": TERRAIN_LINE_RULE_ID}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	if not _has_pending_terrain_line_start():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["terrain_selected"] = terrain_selected
		missing_snapshot["message"] = "Set a terrain line start tile before applying the line."
		missing_snapshot["path_rule"] = TERRAIN_LINE_RULE_ID
		missing_snapshot["path_rule_label"] = TERRAIN_LINE_RULE_LABEL
		return missing_snapshot
	var start_tile := _pending_terrain_line_start
	_selected_tile = end_tile
	_tool = TOOL_TERRAIN_LINE
	var result := {}
	if terrain_selected:
		result = _apply_terrain_line(start_tile, end_tile, _selected_terrain_id)
	else:
		result = {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not in the editor base terrain options." % terrain_id,
			"path_rule": TERRAIN_LINE_RULE_ID,
			"path_rule_label": TERRAIN_LINE_RULE_LABEL,
		}
	if bool(result.get("ok", false)):
		_pending_terrain_line_start = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["terrain_selected"] = terrain_selected
	snapshot["terrain_line_result"] = result
	snapshot["active_terrain_id"] = String(result.get("active_terrain_id", _selected_terrain_id))
	snapshot["path_rule"] = String(result.get("path_rule", TERRAIN_LINE_RULE_ID))
	snapshot["path_rule_label"] = String(result.get("path_rule_label", TERRAIN_LINE_RULE_LABEL))
	snapshot["path_tiles"] = result.get("path_tiles", [])
	snapshot["changed_tiles"] = result.get("changed_tiles", [])
	snapshot["previous_terrain_by_tile"] = result.get("previous_terrain_by_tile", {})
	snapshot["path_count"] = int(result.get("path_count", 0))
	snapshot["affected_count"] = int(result.get("affected_count", 0))
	snapshot["owner_changed_count"] = int(result.get("owner_changed_count", 0))
	snapshot["owner_changed_tiles"] = result.get("owner_changed_tiles", [])
	snapshot["terrain_placement"] = result.get("terrain_placement", _last_terrain_placement_result)
	snapshot["start_tile"] = result.get("start_tile", {"x": start_tile.x, "y": start_tile.y})
	snapshot["end_tile"] = result.get("end_tile", {"x": end_tile.x, "y": end_tile.y})
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_set_terrain_rectangle_corner(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map.", "rectangle_rule": TERRAIN_RECTANGLE_RULE_ID}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	_selected_tile = tile
	_tool = TOOL_TERRAIN_RECTANGLE
	_pending_terrain_rectangle_corner = tile
	_last_message = "Terrain rectangle corner set at %d,%d. Apply uses %s with %s." % [
		x,
		y,
		TERRAIN_RECTANGLE_RULE_LABEL,
		_selected_terrain_id,
	]
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = terrain_selected
	snapshot["terrain_selected"] = terrain_selected
	snapshot["rectangle_rule"] = TERRAIN_RECTANGLE_RULE_ID
	snapshot["rectangle_rule_label"] = TERRAIN_RECTANGLE_RULE_LABEL
	snapshot["tile_order"] = TERRAIN_RECTANGLE_TILE_ORDER
	return snapshot

func validation_apply_terrain_rectangle(x: int, y: int, terrain_id: String = "") -> Dictionary:
	var opposite_tile := Vector2i(x, y)
	if not _tile_in_bounds(opposite_tile):
		return {"ok": false, "message": "Tile outside map.", "rectangle_rule": TERRAIN_RECTANGLE_RULE_ID}
	var terrain_selected := true
	if terrain_id != "":
		terrain_selected = _select_terrain_by_id(terrain_id)
	if not _has_pending_terrain_rectangle_corner():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["terrain_selected"] = terrain_selected
		missing_snapshot["message"] = "Set a terrain rectangle corner tile before applying the rectangle."
		missing_snapshot["rectangle_rule"] = TERRAIN_RECTANGLE_RULE_ID
		missing_snapshot["rectangle_rule_label"] = TERRAIN_RECTANGLE_RULE_LABEL
		missing_snapshot["tile_order"] = TERRAIN_RECTANGLE_TILE_ORDER
		return missing_snapshot
	var corner_tile := _pending_terrain_rectangle_corner
	_selected_tile = opposite_tile
	_tool = TOOL_TERRAIN_RECTANGLE
	var result := {}
	if terrain_selected:
		result = _apply_terrain_rectangle(corner_tile, opposite_tile, _selected_terrain_id)
	else:
		result = {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not in the editor base terrain options." % terrain_id,
			"rectangle_rule": TERRAIN_RECTANGLE_RULE_ID,
			"rectangle_rule_label": TERRAIN_RECTANGLE_RULE_LABEL,
			"tile_order": TERRAIN_RECTANGLE_TILE_ORDER,
		}
	if bool(result.get("ok", false)):
		_pending_terrain_rectangle_corner = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["terrain_selected"] = terrain_selected
	snapshot["terrain_rectangle_result"] = result
	snapshot["active_terrain_id"] = String(result.get("active_terrain_id", _selected_terrain_id))
	snapshot["rectangle_rule"] = String(result.get("rectangle_rule", TERRAIN_RECTANGLE_RULE_ID))
	snapshot["rectangle_rule_label"] = String(result.get("rectangle_rule_label", TERRAIN_RECTANGLE_RULE_LABEL))
	snapshot["tile_order"] = String(result.get("tile_order", TERRAIN_RECTANGLE_TILE_ORDER))
	snapshot["rectangle_tiles"] = result.get("rectangle_tiles", [])
	snapshot["changed_tiles"] = result.get("changed_tiles", [])
	snapshot["previous_terrain_by_tile"] = result.get("previous_terrain_by_tile", {})
	snapshot["rectangle_count"] = int(result.get("rectangle_count", 0))
	snapshot["affected_count"] = int(result.get("affected_count", 0))
	snapshot["owner_changed_count"] = int(result.get("owner_changed_count", 0))
	snapshot["owner_changed_tiles"] = result.get("owner_changed_tiles", [])
	snapshot["terrain_placement"] = result.get("terrain_placement", _last_terrain_placement_result)
	snapshot["corner_tile"] = result.get("corner_tile", {"x": corner_tile.x, "y": corner_tile.y})
	snapshot["opposite_tile"] = result.get("opposite_tile", {"x": opposite_tile.x, "y": opposite_tile.y})
	snapshot["bounds"] = result.get("bounds", _terrain_rectangle_bounds(corner_tile, opposite_tile))
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_toggle_road(x: int, y: int) -> Dictionary:
	_selected_tile = Vector2i(x, y)
	_tool = TOOL_ROAD
	var changed := _toggle_road(_selected_tile)
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = changed
	return snapshot

func validation_set_road_path_start(x: int, y: int) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map.", "path_rule": ROAD_PATH_RULE_ID}
	_selected_tile = tile
	_tool = TOOL_ROAD_PATH
	_pending_road_path_start = tile
	_last_message = "Road path start set at %d,%d. Apply uses %s." % [x, y, ROAD_PATH_RULE_LABEL]
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	snapshot["path_rule"] = ROAD_PATH_RULE_ID
	snapshot["path_rule_label"] = ROAD_PATH_RULE_LABEL
	return snapshot

func validation_apply_road_path(x: int, y: int, action: String = "toggle") -> Dictionary:
	var end_tile := Vector2i(x, y)
	if not _tile_in_bounds(end_tile):
		return {"ok": false, "message": "Tile outside map.", "path_rule": ROAD_PATH_RULE_ID}
	if not _has_pending_road_path_start():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["message"] = "Set a road path start tile before applying the path."
		missing_snapshot["path_rule"] = ROAD_PATH_RULE_ID
		missing_snapshot["path_rule_label"] = ROAD_PATH_RULE_LABEL
		return missing_snapshot
	var start_tile := _pending_road_path_start
	_selected_tile = end_tile
	_tool = TOOL_ROAD_PATH
	var result := _apply_road_path(start_tile, end_tile, action)
	if bool(result.get("ok", false)):
		_pending_road_path_start = Vector2i(-1, -1)
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["road_path_result"] = result
	snapshot["road_path_action"] = String(result.get("road_path_action", ""))
	snapshot["requested_action"] = String(result.get("requested_action", action))
	snapshot["path_rule"] = String(result.get("path_rule", ROAD_PATH_RULE_ID))
	snapshot["path_rule_label"] = String(result.get("path_rule_label", ROAD_PATH_RULE_LABEL))
	snapshot["path_tiles"] = result.get("path_tiles", [])
	snapshot["changed_tiles"] = result.get("changed_tiles", [])
	snapshot["path_count"] = int(result.get("path_count", 0))
	snapshot["affected_count"] = int(result.get("affected_count", 0))
	snapshot["start_tile"] = result.get("start_tile", {"x": start_tile.x, "y": start_tile.y})
	snapshot["end_tile"] = result.get("end_tile", {"x": end_tile.x, "y": end_tile.y})
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
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
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	return snapshot

func validation_preview_object_placement(x: int, y: int, family: String, content_id: String) -> Dictionary:
	var family_selected := true
	var content_selected := true
	if family != "":
		family_selected = _select_object_family_by_id(family)
	if content_id != "":
		content_selected = _select_object_content_by_id(content_id)
	_selected_tile = Vector2i(x, y)
	_hovered_tile = _selected_tile
	_tool = TOOL_PLACE_OBJECT
	_last_object_authoring_recap = {}
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = family_selected and content_selected and not snapshot.get("selected_object_placement_preview", {}).is_empty()
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
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	return snapshot

func validation_move_object(from_x: int, from_y: int, to_x: int, to_y: int, family: String = "") -> Dictionary:
	var source_tile := Vector2i(from_x, from_y)
	var destination_tile := Vector2i(to_x, to_y)
	if not _tile_in_bounds(source_tile) or not _tile_in_bounds(destination_tile):
		return {"ok": false, "message": "Source or destination tile outside map."}
	_selected_tile = source_tile
	_tool = TOOL_MOVE_OBJECT
	var source_detail := _preferred_move_detail_at(source_tile)
	if family != "":
		source_detail = {}
		for detail in _property_object_options_at(source_tile):
			if detail is Dictionary and String(detail.get("kind", "")) == family:
				source_detail = detail
				break
	if source_detail.is_empty():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["message"] = "No movable %s object at %d,%d." % [family if family != "" else "supported", from_x, from_y]
		return missing_snapshot
	var move_key := String(source_detail.get("property_key", ""))
	_pending_move_object_key = move_key
	_selected_property_object_key = move_key
	var before_detail: Dictionary = source_detail.duplicate(true)
	var result := _move_object_by_key(move_key, destination_tile)
	if bool(result.get("ok", false)):
		_pending_move_object_key = ""
		_dirty = _dirty or bool(result.get("changed", false))
		_selected_tile = destination_tile
		var after_detail := _object_detail_by_key(move_key)
		_set_object_authoring_recap("move", bool(result.get("changed", false)), before_detail, after_detail, source_tile, destination_tile)
	else:
		_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	snapshot["from"] = result.get("from", {"x": from_x, "y": from_y})
	snapshot["to"] = result.get("to", {"x": to_x, "y": to_y})
	snapshot["source_detail_before"] = before_detail
	snapshot["source_tile_inspection"] = _tile_inspection_payload(source_tile)
	snapshot["destination_tile_inspection"] = _tile_inspection_payload(destination_tile)
	return snapshot

func validation_duplicate_object(from_x: int, from_y: int, to_x: int, to_y: int, family: String = "") -> Dictionary:
	var source_tile := Vector2i(from_x, from_y)
	var destination_tile := Vector2i(to_x, to_y)
	if not _tile_in_bounds(source_tile) or not _tile_in_bounds(destination_tile):
		return {"ok": false, "message": "Source or destination tile outside map."}
	_selected_tile = source_tile
	_tool = TOOL_DUPLICATE_OBJECT
	var source_detail := _preferred_move_detail_at(source_tile)
	if family != "":
		source_detail = {}
		for detail in _property_object_options_at(source_tile):
			if detail is Dictionary and String(detail.get("kind", "")) == family:
				source_detail = detail
				break
	if source_detail.is_empty():
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["message"] = "No duplicable %s object at %d,%d." % [family if family != "" else "supported", from_x, from_y]
		return missing_snapshot
	var duplicate_key := String(source_detail.get("property_key", ""))
	_pending_duplicate_object_key = duplicate_key
	_selected_property_object_key = duplicate_key
	var before_detail: Dictionary = source_detail.duplicate(true)
	var before_count := _placement_count()
	var result := _duplicate_object_by_key(duplicate_key, destination_tile)
	if bool(result.get("ok", false)):
		_pending_duplicate_object_key = ""
		_dirty = _dirty or bool(result.get("changed", false))
		_selected_tile = destination_tile
		var duplicated_placement = result.get("object", {})
		var duplicated_key := ""
		if duplicated_placement is Dictionary:
			duplicated_key = _object_property_key(String(before_detail.get("kind", "")), String(duplicated_placement.get("placement_id", "")))
		var after_detail := _object_detail_by_key(duplicated_key)
		_set_object_authoring_recap("duplicate", bool(result.get("changed", false)), before_detail, after_detail, source_tile, destination_tile)
	else:
		_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	snapshot["from"] = result.get("from", {"x": from_x, "y": from_y})
	snapshot["to"] = result.get("to", {"x": to_x, "y": to_y})
	snapshot["source_detail_before"] = before_detail
	snapshot["source_tile_inspection"] = _tile_inspection_payload(source_tile)
	snapshot["destination_tile_inspection"] = _tile_inspection_payload(destination_tile)
	snapshot["placement_count_before"] = before_count
	return snapshot

func validation_retheme_object(x: int, y: int, family: String, replacement_content_id: String) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	var family_selected := _select_object_family_by_id(family)
	var content_selected := false
	if family_selected:
		content_selected = _select_object_content_by_id(replacement_content_id)
	_selected_tile = tile
	_tool = TOOL_RETHEME_OBJECT
	var source_detail := _object_detail_for_family_at(tile, family)
	if not family_selected or not content_selected or source_detail.is_empty():
		_refresh_state()
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["family_selected"] = family_selected
		missing_snapshot["content_selected"] = content_selected
		missing_snapshot["message"] = "No rethemeable %s object at %d,%d for %s." % [family, x, y, replacement_content_id]
		return missing_snapshot
	var before_detail: Dictionary = source_detail.duplicate(true)
	var before_count := _placement_count()
	var result := _retheme_object_by_key(String(source_detail.get("property_key", "")), replacement_content_id)
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
		var after_detail := _object_detail_by_key(String(source_detail.get("property_key", "")))
		_set_object_authoring_recap("retheme", bool(result.get("changed", false)), before_detail, after_detail, tile, tile)
	else:
		_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	snapshot["family_selected"] = family_selected
	snapshot["content_selected"] = content_selected
	snapshot["source_detail_before"] = before_detail
	snapshot["object_before"] = result.get("object_before", before_detail)
	snapshot["object_after"] = result.get("object", {})
	snapshot["previous_content_id"] = String(result.get("previous_content_id", ""))
	snapshot["content_id"] = String(result.get("content_id", ""))
	snapshot["tile_inspection"] = _tile_inspection_payload(tile)
	snapshot["placement_count_before"] = before_count
	return snapshot

func validation_edit_object_property(x: int, y: int, family: String, property_name: String, value: Variant) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile outside map."}
	_selected_tile = tile
	var selected := _select_property_object_at_tile(family)
	if not selected:
		var missing_snapshot := validation_snapshot()
		missing_snapshot["ok"] = false
		missing_snapshot["message"] = "No editable %s object at %d,%d." % [family, x, y]
		return missing_snapshot
	var before_detail := _object_detail_by_key(String(_selected_property_object_key))
	var previous_value = before_detail.get(property_name, null)
	var result := _apply_object_property_value(property_name, value)
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
		var after_detail := _object_detail_by_key(String(_selected_property_object_key))
		_set_object_authoring_recap(
			"edit_property",
			bool(result.get("changed", false)),
			before_detail,
			after_detail,
			tile,
			tile,
			{},
			property_name,
			previous_value,
			after_detail.get(property_name, null)
		)
	else:
		_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = _last_message
	snapshot["authoring_recap"] = _last_object_authoring_recap
	return snapshot

func validation_restore_selected_tile(x: int = -999, y: int = -999) -> Dictionary:
	if x != -999 and y != -999:
		var tile := Vector2i(x, y)
		if not _tile_in_bounds(tile):
			return {"ok": false, "message": "Tile outside map."}
		_selected_tile = tile
	var result := _restore_selected_tile_from_authored()
	if bool(result.get("ok", false)):
		_dirty = _dirty or bool(result.get("changed", false))
	_last_message = String(result.get("message", ""))
	_refresh_state()
	var snapshot := validation_snapshot()
	snapshot["ok"] = bool(result.get("ok", false))
	snapshot["changed"] = bool(result.get("changed", false))
	snapshot["message"] = String(result.get("message", ""))
	snapshot["restore_result"] = result
	snapshot["tile_inspection"] = _tile_inspection_payload(_selected_tile)
	return snapshot

func validation_tile_presentation(x: int, y: int) -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_tile_presentation"):
		return {}
	return _map_view.call("validation_tile_presentation", Vector2i(x, y))

func validation_editor_restamp_payload(x: int, y: int) -> Dictionary:
	return _editor_restamp_payload_for_tile(Vector2i(x, y))

func _editor_restamp_payload_for_tile(tile: Vector2i) -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_editor_restamp_payload"):
		return {}
	return _map_view.call("validation_editor_restamp_payload", tile)

func validation_launch_working_copy() -> Dictionary:
	if _session == null:
		return {"ok": false, "message": "No editor working copy is loaded."}
	var scenario_id := String(_session.scenario_id)
	var launch_readiness_gate := _editor_play_readiness_gate_payload()
	var launch_handoff := _editor_play_handoff_payload()
	_on_play_working_copy_pressed()
	return {
		"ok": SessionState.ensure_active_session().scenario_id == scenario_id,
		"scenario_id": scenario_id,
		"active_scenario_id": SessionState.ensure_active_session().scenario_id,
		"editor_working_copy": bool(SessionState.ensure_active_session().flags.get("editor_working_copy", false)),
		"editor_snapshot_available": SessionState.has_editor_working_copy_session(),
		"return_model": String(SessionState.ensure_active_session().flags.get("editor_return_model", "")),
		"launch_readiness_gate": launch_readiness_gate,
		"launch_handoff": launch_handoff,
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
		"selected_property_object": _selected_property_object_payload(),
		"pending_move_object": _pending_move_object_payload(),
		"pending_duplicate_object": _pending_duplicate_object_payload(),
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

func _select_terrain_by_id(terrain_id: String) -> bool:
	for index in range(_terrain_picker.get_item_count()):
		if String(_terrain_picker.get_item_metadata(index)) == terrain_id:
			_terrain_picker.select(index)
			_selected_terrain_id = terrain_id
			return true
	return false

func _select_scenario_picker_by_id(scenario_id: String) -> bool:
	for index in range(_scenario_picker.get_item_count()):
		if String(_scenario_picker.get_item_metadata(index)) == scenario_id:
			_scenario_picker.select(index)
			return true
	return false

func _select_object_content_by_id(content_id: String) -> bool:
	for index in range(_object_content_picker.get_item_count()):
		if String(_object_content_picker.get_item_metadata(index)) == content_id:
			_object_content_picker.select(index)
			_selected_object_content_id = content_id
			return true
	return false
