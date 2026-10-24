extends Node

# The map editor used by fixed rules through its real screen, for
# tools/rules_parity.py --editor (transition doc, Phase 7, slice 7.13). The
# main menu's route opens the editor, its package picker and Load Map open
# the package, and then, through the editor's own pickers, buttons and map
# clicks, the user:
#   - paints terrain with three brushes, fills a region, draws a line and a
#     rectangle, lays roads (one taken up again) and a road path, and moves
#     the hero start;
#   - for each object family places the first content id on the first free
#     tile near its anchor, edits its property (a town's owner, an
#     encounter's difficulty, a site's or artifact's collected flag),
#     rethemes it to the second content id, moves it, duplicates it and
#     removes the duplicate;
#   - removes one of the map's own objects and restores two edited tiles;
#   - saves a copy, plays it and returns to the editor, and paints once more.
# Every choice is a function of the document, so one package replays one
# edit. It fails only when the editor cannot go on.
#
# HEROES_EDITOR_SEED, HEROES_EDITOR_SIZE, HEROES_EDITOR_PLAYERS,
# HEROES_EDITOR_WATER: the generated package edited (one level: the editor
#                       opens no other).
# HEROES_EDITOR_PACKAGE  instead, the stem of a package in res://maps.
# HEROES_EDITOR_OUT      the JSON record (default user://map_editor_seat.json).
# HEROES_EDITOR_DIGEST   one line per action: "0<TAB>step<TAB>action<TAB>
#                        document<TAB>panels". document is the hash of the
#                        working copy's header, overworld and flags, of its
#                        baseline's and of the editor's own state (8 hex digits
#                        each); panels is the hash of the editor's validation
#                        snapshot (without the package picker's and the map
#                        view's layout) and of the texts the screen shows. Each
#                        is hashed as its JSON text with the clock taken out
#                        (TIMED): the sessions' ids, the package files' times
#                        and the play copy's start time.
# HEROES_EDITOR_DUMP     with HEROES_EDITOR_DUMP_STEP: after that step, the
#                        state and the panels as JSON, and the run stops.

const NativeRulesScript = preload("res://scripts/core/NativeRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "MAP_EDITOR_SEAT_REPORT"
const DEFAULT_OUT := "user://map_editor_seat.json"
const EDITOR_SCENE := "res://scenes/editor/MapEditorShell.tscn"
const OVERWORLD_SCENE := "res://scenes/overworld/OverworldShell.tscn"
const MAPS_DIR := "res://maps"
const SCENE_WAIT_FRAMES := 1200
const FAMILIES := ["town", "resource", "artifact", "encounter"]
# Where each family's objects go, from the map's centre.
const FAMILY_ANCHORS := {"town": Vector2i(-7, 6), "resource": Vector2i(6, 6), "artifact": Vector2i(-6, -7), "encounter": Vector2i(7, -6)}
const PROPERTY_EDITS := {"town": ["PropertyOwnerPicker", "enemy"], "encounter": ["PropertyDifficultyPicker", "high"]}
# The editor's own state the edits leave, compared with the document.
const EDITOR_STATE := [
	"_selected_map_package_id", "_selected_terrain_id", "_selected_object_family", "_selected_object_content_id",
	"_selected_property_object_key", "_pending_move_object_key", "_pending_duplicate_object_key",
	"_pending_terrain_line_start", "_pending_terrain_rectangle_corner", "_pending_road_path_start", "_selected_tile",
	"_hovered_tile", "_tool", "_dirty", "_last_message", "_last_object_authoring_recap", "_restored_from_play_copy",
	"_terrain_paint_order", "_last_terrain_placement_result", "_last_save_copy_result",
]
# Snapshot keys that show the side's maps folder or the map view's layout, not the edit.
const SNAPSHOT_LEFT_OUT := [
	"map_package_picker_tooltip", "map_package_picker_item_count", "map_package_picker_labels",
	"map_package_picker_metadata", "map_package_index_status", "scenario_picker_tooltip", "map_viewport",
	"export_intent", "export_intent_text", "export_intent_tooltip", "authored_scenario_export_contract",
]
# Keys of the snapshot's payloads, likewise ([payload, key]), and the working copy's hash, clock included, which the
# document parts hold.
const SNAPSHOT_NESTED_LEFT_OUT := [
	["map_load_handoff", "map_package_count"], ["scenario_switch_handoff", "map_package_count"],
	["dirty_transition", "working_copy_signature"],
]
# Nodes whose texts are left out: the package picker lists the side's maps folder; the cursor's live text follows
# a timer.
const TEXTS_LEFT_OUT := ["MapPackagePicker", "EditorMapCursorLive"]
# The clock in the record: a loaded session's id ends in the engine's ticks, a package entry keeps its files' times,
# the play copy its start time.
const TIMED := [
	["(editor_maps_folder_package|maps_folder_package_session)-[0-9]+", "$1-0"],
	["\"modified_time\":[0-9]+", "\"modified_time\":0"],
	["[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}", "T"],
]

var _failed := false
var _shell = null
var _digest_file: FileAccess = null
var _dump_path := ""
var _dump_step := -1
var _step := 0
var _timing := {}
var _action_counts := {}
var _setup := {}
var _saved := {}
var _stopped := false
var _centre := Vector2i.ZERO
var _map_size := Vector2i.ZERO
var _timed: Array = []

func _ready() -> void:
	for pair in TIMED:
		var pattern := RegEx.new()
		pattern.compile(pair[0])
		_timed.append([pattern, pair[1]])
	call_deferred("_run")

func _run() -> void:
	if not NativeRulesScript.available():
		_fail("The native rules library is not loaded: %s." % NativeRulesScript.REGISTER_HINT)
		return
	var out_path := OS.get_environment("HEROES_EDITOR_OUT").strip_edges()
	if out_path == "":
		out_path = DEFAULT_OUT
	var digest_path := OS.get_environment("HEROES_EDITOR_DIGEST").strip_edges()
	if digest_path != "":
		_digest_file = FileAccess.open(digest_path, FileAccess.WRITE)
		if _digest_file == null:
			_fail("HEROES_EDITOR_DIGEST %s cannot be written." % digest_path)
			return
	_dump_path = OS.get_environment("HEROES_EDITOR_DUMP").strip_edges()
	if _dump_path != "" and OS.get_environment("HEROES_EDITOR_DUMP_STEP").strip_edges() != "":
		_dump_step = int(OS.get_environment("HEROES_EDITOR_DUMP_STEP"))
	var stem := _package_stem()
	if stem == "":
		return
	_setup["package_stem"] = stem
	if FileAccess.file_exists("%s/%s-copy.amap" % [MAPS_DIR, stem]):
		_fail("%s/%s-copy.amap is left from another run; remove it first." % [MAPS_DIR, stem])
		return

	# The screens replace the current scene; this node stays beside them.
	var tree := get_tree()
	tree.root.remove_child.call_deferred(self)
	await tree.process_frame
	tree.root.add_child(self)
	AppRouter.go_to_map_editor()
	_shell = await _wait_for_scene([EDITOR_SCENE])
	if _shell == null:
		_fail("The map editor did not open.")
		return
	var package_id := ScenarioSelectRulesScript.maps_folder_package_id_for_stem(stem)
	await _act("pick_package", func(): return _pick("MapPackagePicker", package_id))
	await _act("load", func(): _press("LoadMap"))
	if _stopped or _failed:
		_finish(out_path)
		return
	if _shell._session == null or String(_shell._session.flags.get("editor_source_package_id", "")) != package_id:
		_fail("Load Map did not open %s: %s" % [package_id, _shell._last_message])
		return
	_setup["scenario_id"] = String(_shell._session.scenario_id)
	_map_size = OverworldRules.derive_map_size(_shell._session)
	_centre = Vector2i(_map_size.x / 2, _map_size.y / 2)

	await _edit_terrain()
	await _edit_roads()
	for family in FAMILIES:
		await _edit_family(family)
	await _remove_map_object()
	await _restore_tiles()
	await _save_play_and_return()
	if _failed:
		return
	_finish(out_path)

## The package edited: generated from the setup, or one in res://maps.
func _package_stem() -> String:
	var named := OS.get_environment("HEROES_EDITOR_PACKAGE").strip_edges()
	if named != "":
		if not FileAccess.file_exists("%s/%s.amap" % [MAPS_DIR, named]):
			_fail("%s/%s.amap does not exist." % [MAPS_DIR, named])
			return ""
		return named
	var seed := OS.get_environment("HEROES_EDITOR_SEED").strip_edges()
	var players := int(OS.get_environment("HEROES_EDITOR_PLAYERS")) if OS.get_environment("HEROES_EDITOR_PLAYERS") != "" else 2
	var size := OS.get_environment("HEROES_EDITOR_SIZE").strip_edges()
	var water := OS.get_environment("HEROES_EDITOR_WATER").strip_edges()
	_setup.merge({"seed": seed, "players": players, "size": size, "water": water})
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup(
		ScenarioSelectRulesScript.build_random_map_player_config(seed, "", "", players, water if water != "" else "land", false,
			size if size != "" else "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO),
		"normal")
	var startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	if not bool(setup.get("ok", false)) or String(startup.get("package_stem", "")) == "":
		_fail("The package could not be generated: %s" % JSON.stringify(setup).left(400))
		return ""
	return String(startup.get("package_stem", ""))

# ---------------------------------------------------------------- the edits

func _edit_terrain() -> void:
	var terrains := _metadata("TerrainPicker")
	if terrains.is_empty():
		_fail("The terrain picker is empty.")
		return
	await _act("tool:inspect", func(): _press("InspectTool"))
	await _act("inspect", func(): _click(OverworldRules.hero_position(_shell._session)))
	for index in range(3):
		var terrain: String = terrains[(index * 2 + 1) % terrains.size()]
		await _act("terrain:%s" % terrain, func(): return _pick("TerrainPicker", terrain))
		await _act("hover", func(): _hover(_tile(index - 1, -1)))
		await _act("paint", func(): _click(_tile(index - 1, -1)))
	await _act("paint", func(): _click(_tile(1, -1)))
	await _act("tool:inspect", func(): _press("InspectTool"))
	await _act("inspect", func(): _click(_tile(4, 4)))
	await _act("terrain:%s" % terrains[2 % terrains.size()], func(): return _pick("TerrainPicker", terrains[2 % terrains.size()]))
	await _act("fill", func(): _press("FillTerrain"))
	await _act("tool:terrain_line", func(): _press("TerrainLineTool"))
	await _act("terrain:%s" % terrains[3 % terrains.size()], func(): return _pick("TerrainPicker", terrains[3 % terrains.size()]))
	await _act("line_start", func(): _click(_tile(-5, 2)))
	await _act("hover", func(): _hover(_tile(-2, 4)))
	await _act("line_end", func(): _click(_tile(-1, 5)))
	await _act("tool:terrain_rectangle", func(): _press("TerrainRectangleTool"))
	await _act("terrain:%s" % terrains[4 % terrains.size()], func(): return _pick("TerrainPicker", terrains[4 % terrains.size()]))
	await _act("rectangle_start", func(): _click(_tile(2, -6)))
	await _act("rectangle_end", func(): _click(_tile(5, -4)))

func _edit_roads() -> void:
	await _act("tool:road", func(): _press("RoadTool"))
	await _act("road", func(): _click(_tile(-2, -2)))
	await _act("road", func(): _click(_tile(-2, -3)))
	await _act("road", func(): _click(_tile(-2, -2)))
	await _act("tool:road_path", func(): _press("RoadPathTool"))
	await _act("road_path_start", func(): _click(_tile(-6, -3)))
	await _act("road_path_end", func(): _click(_tile(-3, 0)))
	await _act("tool:hero_start", func(): _press("HeroStartTool"))
	await _act("hero_start", func(): _click(_tile(3, 3)))

func _edit_family(family: String) -> void:
	if _stopped or _failed:
		return
	await _act("family:%s" % family, func(): return _pick("ObjectFamilyPicker", family))
	var contents := _metadata("ObjectContentPicker")
	if contents.is_empty():
		return
	await _act("content:%s" % contents[0], func(): return _pick("ObjectContentPicker", contents[0]))
	await _act("tool:place", func(): _press("PlaceObjectTool"))
	var anchor: Vector2i = FAMILY_ANCHORS[family]
	var at := _free_tile(anchor, [])
	if at.x < 0:
		return
	await _act("hover", func(): _hover(at))
	await _act("place", func(): _click(at))
	await _act("tool:inspect", func(): _press("InspectTool"))
	await _act("inspect", func(): _click(at))
	var edit: Array = PROPERTY_EDITS.get(family, [])
	if not edit.is_empty():
		await _act("property:%s" % edit[1], func(): return _choose(edit[0], edit[1]))
	else:
		await _act("property:collected", func(): _shell.get_node("%PropertyCollectedFlag").button_pressed = true)
	await _act("apply_properties", func(): _press("ApplyObjectProperties"))
	if contents.size() > 1:
		await _act("tool:retheme", func(): _press("RethemeObjectTool"))
		await _act("content:%s" % contents[1], func(): return _pick("ObjectContentPicker", contents[1]))
		await _act("retheme", func(): _click(at))
	var moved := _free_tile(anchor + Vector2i(0, 2), [at])
	if moved.x < 0:
		return
	await _act("tool:move", func(): _press("MoveObjectTool"))
	await _act("move_from", func(): _click(at))
	await _act("move_to", func(): _click(moved))
	var copy := _free_tile(anchor + Vector2i(2, 0), [at, moved])
	if copy.x < 0:
		return
	await _act("tool:duplicate", func(): _press("DuplicateObjectTool"))
	await _act("duplicate_from", func(): _click(moved))
	await _act("duplicate_to", func(): _click(copy))
	await _act("tool:remove", func(): _press("RemoveObjectTool"))
	await _act("remove", func(): _click(copy))

## One of the map's own objects: the first town, else the first resource site.
func _remove_map_object() -> void:
	if _stopped or _failed:
		return
	for family in ["town", "resource"]:
		var key: String = "towns" if family == "town" else "resource_nodes"
		for placement in _shell._session.overworld.get(key, []):
			if placement is Dictionary and not bool(placement.get("editor_authored_placement", false)):
				var tile := Vector2i(int(placement.get("x", -1)), int(placement.get("y", -1)))
				await _act("family:%s" % family, func(): return _pick("ObjectFamilyPicker", family))
				await _act("tool:remove", func(): _press("RemoveObjectTool"))
				await _act("remove", func(): _click(tile))
				return

func _restore_tiles() -> void:
	await _act("tool:inspect", func(): _press("InspectTool"))
	await _act("inspect", func(): _click(_tile(0, -1)))
	await _act("restore", func(): _press("RestoreSelectedTile"))
	await _act("inspect", func(): _click(_tile(3, -5)))
	await _act("restore", func(): _press("RestoreSelectedTile"))

func _save_play_and_return() -> void:
	if _stopped or _failed:
		return
	await _act("save_copy", func(): _press("SaveCopy"))
	var result: Dictionary = _shell._last_save_copy_result
	if not bool(result.get("ok", false)):
		_fail("Save Copy failed: %s" % JSON.stringify(result).left(600))
		return
	for path_key in ["map_path", "scenario_path"]:
		var path := String(result.get(path_key, ""))
		_saved[path_key] = path
		_setup["saved_" + path_key.get_slice("_", 0) + "_sha256"] = FileAccess.get_sha256(path)
	if _stopped:
		return
	_press("PlayWorkingCopy")
	var overworld = await _wait_for_scene([OVERWORLD_SCENE])
	if overworld == null:
		_fail("Play did not open the overworld.")
		return
	_shell = null
	_record("play")
	if _stopped:
		return
	AppRouter.return_to_main_menu_from_active_play()
	_shell = await _wait_for_scene([EDITOR_SCENE])
	if _shell == null:
		_fail("The overworld did not return to the editor.")
		return
	_record("return")
	await _act("tool:terrain", func(): _press("TerrainTool"))
	await _act("paint", func(): _click(_tile(-1, 1)))

## The first tile near anchor, ring by ring, that the selected object may take and that is none of taken.
func _free_tile(anchor: Vector2i, taken: Array) -> Vector2i:
	var start := _tile(anchor.x, anchor.y)
	for radius in range(0, 6):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var tile := start + Vector2i(dx, dy)
				if tile in taken or not _shell._tile_in_bounds(tile):
					continue
				if bool(_shell._placement_availability_for_selected_object(tile).get("can_place", false)):
					return tile
	return Vector2i(-1, -1)

func _tile(dx: int, dy: int) -> Vector2i:
	return Vector2i(clampi(_centre.x + dx, 0, maxi(0, _map_size.x - 1)), clampi(_centre.y + dy, 0, maxi(0, _map_size.y - 1)))

# ---------------------------------------------------------------- the screen

func _press(name: String) -> void:
	_shell.get_node("%" + name).pressed.emit()

## Selects the picker's item with that metadata, as a click on it.
func _pick(name: String, metadata: String) -> bool:
	var picker: OptionButton = _shell.get_node("%" + name)
	for index in range(picker.get_item_count()):
		if String(picker.get_item_metadata(index)) == metadata:
			picker.select(index)
			picker.item_selected.emit(index)
			return true
	return false

## Selects the item of a picker that has no handler of its own (Apply reads it).
func _choose(name: String, metadata: String) -> bool:
	var picker: OptionButton = _shell.get_node("%" + name)
	for index in range(picker.get_item_count()):
		if String(picker.get_item_metadata(index)) == metadata:
			picker.select(index)
			return true
	return false

func _metadata(name: String) -> Array:
	var picker: OptionButton = _shell.get_node("%" + name)
	var out := []
	for index in range(picker.get_item_count()):
		var value := String(picker.get_item_metadata(index))
		if value != "":
			out.append(value)
	return out

## As the map view's signals: the pointer moves onto the tile, then clicks it.
func _click(tile: Vector2i) -> void:
	_shell._on_map_tile_hovered(tile)
	_shell._on_map_tile_pressed(tile)

func _hover(tile: Vector2i) -> void:
	_shell._on_map_tile_hovered(tile)

# ---------------------------------------------------------------- the record

func _act(action: String, body: Callable) -> void:
	if _stopped or _failed:
		return
	var started := Time.get_ticks_usec()
	body.call()
	var ms := float(Time.get_ticks_usec() - started) / 1000.0
	var kind := action.get_slice(":", 0)
	var entry: Dictionary = _timing.get(kind, {"n": 0, "ms": 0.0, "max_ms": 0.0})
	entry.n += 1
	entry.ms += ms
	entry.max_ms = maxf(float(entry.max_ms), ms)
	_timing[kind] = entry
	_action_counts[kind] = int(_action_counts.get(kind, 0)) + 1
	await _frames(1)
	_record(action)

## One digest row after each action, once its deferred calls have run.
func _record(action: String) -> void:
	_step += 1
	if _digest_file == null and _dump_step != _step:
		return
	var parts := _state_parts()
	var panels := _panels()
	if _digest_file != null:
		var line := "0\t%d\t%s\t" % [_step, action]
		for part in parts:
			line += "%08x" % hash(_untimed_text(part))
		line += "\t%08x" % hash(_untimed_text(panels))
		_digest_file.store_line(line)
		_digest_file.flush()
	if _dump_step == _step:
		var dump := FileAccess.open(_dump_path, FileAccess.WRITE)
		if dump != null:
			dump.store_string(_untimed_text({"step": _step, "action": action, "scene": _current_scene_path(), "state": parts, "panels": panels}))
			dump.close()
		_stopped = true

## A value's JSON text, its key order kept, with the clock taken out.
func _untimed_text(value) -> String:
	var text := JSON.stringify(value, "", false, true)
	for pair in _timed:
		text = pair[0].sub(text, pair[1], true)
	return text

## The working copy (in the editor) or the played session: its header, overworld and flags; the baseline's; the
## editor's own state.
func _state_parts() -> Array:
	var session = _shell._session if _shell != null else SessionState.ensure_active_session()
	var parts := _session_parts(session)
	if _shell == null:
		return parts
	parts.append_array(_session_parts(_shell._authored_baseline_cache))
	var own := {}
	for name in EDITOR_STATE:
		own[name] = _shell.get(name)
	parts.append(own)
	return parts

func _session_parts(session) -> Array:
	if session == null:
		return [{}, {}, {}]
	var flags: Dictionary = session.flags
	if flags.has(AppRouter.AUTOSAVE_PENDING_UNIX_FLAG):
		flags = flags.duplicate()
		flags[AppRouter.AUTOSAVE_PENDING_UNIX_FLAG] = 0
	var header := {
		"day": session.day,
		"session_id": session.session_id,
		"scenario_id": session.scenario_id,
		"game_state": session.game_state,
		"scenario_status": session.scenario_status,
		"scenario_summary": session.scenario_summary,
	}
	return [header, session.overworld, flags]

## The editor's validation snapshot and the texts the screen shows.
func _panels() -> Dictionary:
	var out := {"texts": {}}
	var scene := get_tree().current_scene
	if scene != null:
		_collect_texts(scene, "", out.texts)
	if _shell != null:
		var snapshot: Dictionary = _shell.validation_snapshot()
		for key in SNAPSHOT_LEFT_OUT:
			snapshot.erase(key)
		for pair in SNAPSHOT_NESTED_LEFT_OUT:
			if snapshot.get(pair[0]) is Dictionary:
				snapshot[pair[0]] = snapshot[pair[0]].duplicate()
				snapshot[pair[0]].erase(pair[1])
		out["snapshot"] = snapshot
	return out

func _collect_texts(node: Node, path: String, out: Dictionary) -> void:
	if (node is CanvasItem and not node.visible) or (node is Window and not node.visible) or String(node.name) in TEXTS_LEFT_OUT:
		return
	var text := ""
	if node is Label or node is Button or node is LineEdit:
		text = node.text
	elif node is RichTextLabel:
		text = node.get_parsed_text()
	if node is Control and node.tooltip_text != "":
		text += "␟" + node.tooltip_text
	if text != "":
		out[path] = text
	var counts := {}
	for child in node.get_children():
		var name := String(child.name)
		if name.begins_with("@"):
			var index := int(counts.get(child.get_class(), 0))
			counts[child.get_class()] = index + 1
			name = "@%s#%d" % [child.get_class(), index]
		_collect_texts(child, name if path == "" else path + "/" + name, out)

func _finish(out_path: String) -> void:
	_remove_saved_copy()
	var record := {
		"report_id": REPORT_ID,
		"setup": _setup,
		"final_day": 0,
		"final_scene": _current_scene_path(),
		"actions": _step,
		"action_counts": _action_counts,
		"timing": _timing,
	}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record, "  "))
		file.close()
	var port_failures := _native_port_failures()
	if port_failures != "":
		_fail(port_failures)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true, "setup": _setup, "final_day": 0, "actions": _step, "dumped": _stopped,
		"out": ProjectSettings.globalize_path(out_path),
	})])
	get_tree().quit(0)

## The copy Save Copy wrote: the parity tool removes the package it generated, by its scenario id.
func _remove_saved_copy() -> void:
	for path in _saved.values():
		if String(path) != "" and FileAccess.file_exists(String(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(String(path)))

## As the human seat's: failed native calls, shadow mismatches and unknown names.
func _native_port_failures() -> String:
	var stats: Dictionary = NativeRulesScript.api().port_stats()
	var failed := PackedStringArray()
	for name in stats:
		var entry = stats[name]
		if entry is Dictionary and int(entry.get("errors", 0)) + int(entry.get("mismatches", 0)) > 0:
			failed.append("%s (%d errors, %d mismatches)" % [name, int(entry.get("errors", 0)), int(entry.get("mismatches", 0))])
	if int(stats.get("unknown_calls", 0)) > 0:
		failed.append("%d calls of names it does not have" % int(stats.unknown_calls))
	if failed.is_empty():
		return ""
	return "The native rules port failed: %s." % ", ".join(failed)

# ---------------------------------------------------------------- scenes

func _wait_for_scene(paths: Array):
	for _frame in range(SCENE_WAIT_FRAMES):
		var current := get_tree().current_scene
		if current != null and current.is_node_ready() and String(current.scene_file_path) in paths:
			await _frames(2)
			if get_tree().current_scene == current:
				return current
		await get_tree().process_frame
	return null

func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame

func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return String(current.scene_file_path) if current != null else ""

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_remove_saved_copy()
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message, "step": _step})])
	get_tree().quit(1)
