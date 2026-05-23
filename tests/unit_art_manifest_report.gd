extends Node

const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const OUTPUT_DIR := "res://.artifacts/unit_art_manifest_report"
const UNIT_ART_MANIFEST := "res://content/unit_art_manifest.json"
const EXPECTED_SURFACES := {
	"portrait": Vector2i(384, 512),
	"battle_icon": Vector2i(160, 160),
	"overworld_icon": Vector2i(96, 96),
}

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"unit_count": 0,
	"manifest_count": 0,
	"surface_counts": {},
	"runtime_battle_art": {},
	"runtime_overworld_art": {},
	"runtime_town_art": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dir()
	_validate_manifest_assets()
	await _validate_town_runtime_wiring()
	await _validate_overworld_runtime_wiring()
	await _validate_battle_runtime_wiring()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_manifest_assets() -> void:
	var units := _items(ContentService.load_json(ContentService.UNITS_PATH))
	var manifest := ContentService.load_json(UNIT_ART_MANIFEST)
	var records := _items(manifest)
	_report["unit_count"] = units.size()
	_report["manifest_count"] = records.size()
	if records.size() != units.size():
		_error("Unit art manifest count %d does not match unit count %d." % [records.size(), units.size()])

	var records_by_unit := {}
	for record in records:
		if not (record is Dictionary):
			continue
		var unit_id := String(record.get("unit_id", record.get("id", "")))
		if unit_id == "":
			_error("Unit art manifest contains a record without unit_id.")
			continue
		if records_by_unit.has(unit_id):
			_error("Unit art manifest has duplicate record for %s." % unit_id)
		records_by_unit[unit_id] = record

	var surface_path_sets := {}
	for surface in EXPECTED_SURFACES.keys():
		surface_path_sets[surface] = {}
		_report["surface_counts"][surface] = 0

	for unit in units:
		if not (unit is Dictionary):
			continue
		var unit_id := String(unit.get("id", ""))
		if not records_by_unit.has(unit_id):
			_error("Unit art manifest is missing %s." % unit_id)
			continue
		var record: Dictionary = records_by_unit[unit_id]
		for surface in EXPECTED_SURFACES.keys():
			var path := String(record.get(surface, ""))
			if path == "":
				_error("Unit %s is missing %s art path." % [unit_id, surface])
				continue
			if not FileAccess.file_exists(path):
				_error("Unit %s %s art path does not exist: %s." % [unit_id, surface, path])
				continue
			if surface_path_sets[surface].has(path):
				_error("Unit art path is reused for %s: %s." % [surface, path])
			surface_path_sets[surface][path] = true
			var expected_size: Vector2i = EXPECTED_SURFACES[surface]
			var actual_size := _png_size(path)
			if actual_size == Vector2i.ZERO:
				_error("Unit %s %s art is not a readable PNG: %s." % [unit_id, surface, path])
				continue
			if actual_size != expected_size:
				_error("Unit %s %s art expected %s but got %s." % [unit_id, surface, expected_size, actual_size])
			_report["surface_counts"][surface] = int(_report["surface_counts"].get(surface, 0)) + 1

func _validate_town_runtime_wiring() -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var active_town := _first_player_town(session)
	if active_town.is_empty():
		_error("Unit art runtime report could not find a player town.")
		return
	_move_active_hero_to_town(session, active_town)
	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if not shell.has_method("validation_unit_art_summary"):
		_error("Town shell does not expose validation_unit_art_summary.")
		shell.queue_free()
		return
	var summary: Dictionary = shell.call("validation_unit_art_summary")
	_report["runtime_town_art"] = summary
	if int(summary.get("recruit_action_count", 0)) <= 0:
		_error("Town runtime unit art report did not see recruit actions.")
	if int(summary.get("portrait_loaded_count", 0)) != int(summary.get("recruit_action_count", 0)):
		_error("Town runtime did not load unit portraits for every recruit action: %s." % JSON.stringify(summary))
	shell.queue_free()
	await get_tree().process_frame

func _validate_overworld_runtime_wiring() -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	var view = OverworldMapViewScript.new()
	view.size = Vector2(960, 640)
	add_child(view)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(3, 1))
	await get_tree().process_frame
	if not view.has_method("validation_unit_art_summary"):
		_error("Overworld map view does not expose validation_unit_art_summary.")
		view.queue_free()
		return
	var summary: Dictionary = view.call("validation_unit_art_summary")
	_report["runtime_overworld_art"] = summary
	if int(summary.get("encounter_count", 0)) <= 0:
		_error("Overworld runtime unit art report did not see encounters.")
	if int(summary.get("overworld_icon_loaded_count", 0)) != int(summary.get("encounter_count", 0)):
		_error("Overworld runtime did not load unit icons for every encounter: %s." % JSON.stringify(summary))
	view.queue_free()
	await get_tree().process_frame

func _validate_battle_runtime_wiring() -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		_error("Unit art runtime report could not find a battle encounter.")
		return
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		_error("Unit art runtime report could not create battle payload.")
		return
	SessionState.set_active_session(session)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var board = shell.get_node_or_null("%BattleBoard")
	if board == null or not board.has_method("validation_unit_art_summary"):
		_error("Battle board does not expose validation_unit_art_summary.")
		shell.queue_free()
		return
	var summary: Dictionary = board.call("validation_unit_art_summary")
	_report["runtime_battle_art"] = summary
	if int(summary.get("visible_stack_count", 0)) <= 0:
		_error("Battle runtime unit art report did not see visible stacks.")
	if int(summary.get("battle_icon_loaded_count", 0)) != int(summary.get("visible_stack_count", 0)):
		_error("Battle runtime did not load unit art for every visible stack: %s." % JSON.stringify(summary))
	shell.queue_free()
	await get_tree().process_frame

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _items(raw: Dictionary) -> Array:
	var items = raw.get("items", [])
	return items if items is Array else []

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _png_size(path: String) -> Vector2i:
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
	push_error(message)
	_errors.append(message)
