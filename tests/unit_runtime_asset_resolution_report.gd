extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const TownShellScene = preload("res://scenes/town/TownShell.tscn")

const OUTPUT_DIR := "res://.artifacts/unit_runtime_asset_resolution_report"
const EXPECTED_ART_SIZES := {
	"portrait": Vector2i(384, 512),
	"battle_icon": Vector2i(160, 160),
	"overworld_icon": Vector2i(96, 96),
}
const EXPECTED_ANIMATION_SHEET_SIZE := Vector2i(256, 896)
const REQUIRED_ANIMATION_STATES := [
	"idle_hold",
	"ready_active",
	"move_path_step",
	"melee_windup_release",
	"ranged_aim_release",
	"hit_stagger",
	"death_rout_remove",
	"cast_support_anchor",
	"status_applied",
	"status_expired",
	"defend_brace",
	"retaliation_release",
	"retreat_withdraw_column",
	"surrender_stand_down",
]

var _errors: Array[String] = []
var _battle_board = null
var _overworld_view = null
var _town_shell = null
var _report := {
	"ok": false,
	"unit_count": 0,
	"content_service_art_record_count": 0,
	"content_service_animation_record_count": 0,
	"stack_materialized_count": 0,
	"battle_icon_runtime_resolved_count": 0,
	"overworld_icon_runtime_resolved_count": 0,
	"portrait_runtime_resolved_count": 0,
	"animation_sheet_runtime_resolved_count": 0,
	"animation_state_runtime_row_count": 0,
	"units": [],
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dir()
	_battle_board = BattleBoardViewScript.new()
	_overworld_view = OverworldMapViewScript.new()
	_town_shell = TownShellScene.instantiate()
	var units := _items(ContentService.load_json(ContentService.UNITS_PATH))
	_report["unit_count"] = units.size()
	for unit in units:
		if not (unit is Dictionary):
			_error("Unit record is not a dictionary.")
			continue
		_validate_unit(unit)
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if is_instance_valid(_battle_board):
		_battle_board.free()
	if is_instance_valid(_overworld_view):
		_overworld_view.free()
	if is_instance_valid(_town_shell):
		_town_shell.free()
	if _errors.is_empty():
		print("UNIT_RUNTIME_ASSET_RESOLUTION_REPORT %s" % JSON.stringify(_summary_payload()))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_unit(unit: Dictionary) -> void:
	var unit_id := String(unit.get("id", "")).strip_edges()
	if unit_id == "":
		_error("Unit is missing id.")
		return
	var art: Dictionary = ContentService.get_unit_art(unit_id)
	var animation: Dictionary = ContentService.get_unit_animation(unit_id)
	var stack: Dictionary = BattleRulesScript._build_battle_stack(unit_id, 3, "player", 0, {"source_type": "unit_runtime_asset_resolution_report"})
	if art.is_empty():
		_error("ContentService.get_unit_art returned no record for %s." % unit_id)
	else:
		_report["content_service_art_record_count"] = int(_report["content_service_art_record_count"]) + 1
	if animation.is_empty():
		_error("ContentService.get_unit_animation returned no record for %s." % unit_id)
	else:
		_report["content_service_animation_record_count"] = int(_report["content_service_animation_record_count"]) + 1
	if stack.is_empty():
		_error("BattleRules could not materialize stack for %s." % unit_id)
	else:
		stack["battle_id"] = "asset_resolution_%s" % unit_id
		_report["stack_materialized_count"] = int(_report["stack_materialized_count"]) + 1

	var portrait_summary := _validate_surface(unit_id, art, "portrait")
	var battle_icon_summary := _validate_surface(unit_id, art, "battle_icon")
	var overworld_icon_summary := _validate_surface(unit_id, art, "overworld_icon")
	var animation_summary := _validate_animation(unit_id, animation, stack)
	_report["units"].append({
		"unit_id": unit_id,
		"name": String(unit.get("name", unit_id)),
		"portrait": portrait_summary,
		"battle_icon": battle_icon_summary,
		"overworld_icon": overworld_icon_summary,
		"animation": animation_summary,
	})

func _validate_surface(unit_id: String, art: Dictionary, surface: String) -> Dictionary:
	var path := String(art.get(surface, "")).strip_edges()
	var expected_size: Vector2i = EXPECTED_ART_SIZES[surface]
	var actual_size := _png_size(path)
	var content_path_ok := path.begins_with("res://")
	var size_ok := actual_size == expected_size
	var runtime_loaded := false
	match surface:
		"portrait":
			runtime_loaded = _town_shell.call("_unit_art_texture", path) is Texture2D
			if runtime_loaded:
				_report["portrait_runtime_resolved_count"] = int(_report["portrait_runtime_resolved_count"]) + 1
		"battle_icon":
			var stack: Dictionary = BattleRulesScript._build_battle_stack(unit_id, 3, "player", 0, {"source_type": "unit_runtime_asset_resolution_report"})
			stack["battle_id"] = "asset_resolution_%s" % unit_id
			runtime_loaded = _battle_board.call("_unit_battle_icon_for_stack", stack) is Texture2D
			if runtime_loaded:
				_report["battle_icon_runtime_resolved_count"] = int(_report["battle_icon_runtime_resolved_count"]) + 1
		"overworld_icon":
			var encounter := {"unit_id": unit_id}
			var resolved_path := String(_overworld_view.call("_encounter_overworld_icon_path", encounter))
			if resolved_path != path:
				_error("Overworld icon resolver returned %s for %s, expected %s." % [resolved_path, unit_id, path])
			runtime_loaded = _overworld_view.call("_unit_art_texture", path) is Texture2D
			if runtime_loaded:
				_report["overworld_icon_runtime_resolved_count"] = int(_report["overworld_icon_runtime_resolved_count"]) + 1
	if path == "":
		_error("Unit %s has no %s path from ContentService." % [unit_id, surface])
	if not content_path_ok:
		_error("Unit %s %s path is not a res:// path: %s." % [unit_id, surface, path])
	if not size_ok:
		_error("Unit %s %s expected %s but got %s." % [unit_id, surface, expected_size, actual_size])
	if not runtime_loaded:
		_error("Unit %s %s did not resolve through runtime texture path: %s." % [unit_id, surface, path])
	return {
		"path": path,
		"content_path_ok": content_path_ok,
		"size": {"x": actual_size.x, "y": actual_size.y},
		"runtime_loaded": runtime_loaded,
	}

func _validate_animation(unit_id: String, animation: Dictionary, stack: Dictionary) -> Dictionary:
	var path := String(animation.get("sprite_sheet", "")).strip_edges()
	var actual_size := _png_size(path)
	var runtime_loaded := false
	var state_rows := {}
	if not stack.is_empty():
		runtime_loaded = _battle_board.call("_unit_animation_sheet_for_stack", stack) is Texture2D
		if runtime_loaded:
			_report["animation_sheet_runtime_resolved_count"] = int(_report["animation_sheet_runtime_resolved_count"]) + 1
	var states: Array = animation.get("states", []) if animation.get("states", []) is Array else []
	for index in range(REQUIRED_ANIMATION_STATES.size()):
		var state_name := String(REQUIRED_ANIMATION_STATES[index])
		var row := int(_battle_board.call("_animation_state_row_for_unit", unit_id, state_name))
		state_rows[state_name] = row
		if state_name not in states:
			_error("Unit %s animation is missing state %s." % [unit_id, state_name])
		elif row != states.find(state_name):
			_error("Unit %s animation state %s resolved to row %d, expected %d." % [unit_id, state_name, row, states.find(state_name)])
		else:
			_report["animation_state_runtime_row_count"] = int(_report["animation_state_runtime_row_count"]) + 1
	if path == "":
		_error("Unit %s has no animation sprite_sheet path from ContentService." % unit_id)
	if not path.begins_with("res://"):
		_error("Unit %s animation path is not a res:// path: %s." % [unit_id, path])
	if actual_size != EXPECTED_ANIMATION_SHEET_SIZE:
		_error("Unit %s animation sheet expected %s but got %s." % [unit_id, EXPECTED_ANIMATION_SHEET_SIZE, actual_size])
	if not runtime_loaded:
		_error("Unit %s animation sheet did not resolve through battle runtime texture path: %s." % [unit_id, path])
	return {
		"sprite_sheet": path,
		"size": {"x": actual_size.x, "y": actual_size.y},
		"runtime_loaded": runtime_loaded,
		"state_rows": state_rows,
	}

func _items(raw: Dictionary) -> Array:
	var items = raw.get("items", [])
	return items if items is Array else []

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to open %s for writing." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _summary_payload() -> Dictionary:
	return {
		"ok": bool(_report.get("ok", false)),
		"unit_count": int(_report.get("unit_count", 0)),
		"content_service_art_record_count": int(_report.get("content_service_art_record_count", 0)),
		"content_service_animation_record_count": int(_report.get("content_service_animation_record_count", 0)),
		"stack_materialized_count": int(_report.get("stack_materialized_count", 0)),
		"battle_icon_runtime_resolved_count": int(_report.get("battle_icon_runtime_resolved_count", 0)),
		"overworld_icon_runtime_resolved_count": int(_report.get("overworld_icon_runtime_resolved_count", 0)),
		"portrait_runtime_resolved_count": int(_report.get("portrait_runtime_resolved_count", 0)),
		"animation_sheet_runtime_resolved_count": int(_report.get("animation_sheet_runtime_resolved_count", 0)),
		"animation_state_runtime_row_count": int(_report.get("animation_state_runtime_row_count", 0)),
	}

func _png_size(path: String) -> Vector2i:
	if path == "":
		return Vector2i.ZERO
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO
	var header := file.get_buffer(24)
	if header.size() < 24:
		return Vector2i.ZERO
	var signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	for index in range(signature.size()):
		if header[index] != signature[index]:
			return Vector2i.ZERO
	var width := _be_u32(header, 16)
	var height := _be_u32(header, 20)
	return Vector2i(width, height)

func _be_u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		(int(bytes[offset]) << 24)
		| (int(bytes[offset + 1]) << 16)
		| (int(bytes[offset + 2]) << 8)
		| int(bytes[offset + 3])
	)

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
