extends Node

const REPORT_ID := "MAP_EDITOR_PACKAGE_SAVE_COPY_REPORT"
const SCENARIOS_PATH := "res://content/scenarios.json"
const TERRAIN_LAYERS_PATH := "res://content/terrain_layers.json"

var _test_dir := ""
var _report_scene: Node
var _original_active_session = null
var _original_editor_working_copy = null
var _original_editor_baseline = null
var _original_editor_package_identity: Dictionary = {}
var _original_editor_return_pending := false
var _original_authority: Dictionary = {}
var _expected_authority_after_play: Dictionary = {}
var _original_window_size := Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_report_scene = self
	_original_active_session = SessionState.active_session
	_original_editor_working_copy = SessionState.editor_working_copy_session
	_original_editor_baseline = SessionState._editor_working_copy_baseline_session
	_original_editor_package_identity = SessionState._editor_working_copy_package_identity.duplicate(true)
	_original_editor_return_pending = SessionState.editor_return_pending()
	_original_authority = _durable_authority()
	_expected_authority_after_play = _original_authority.duplicate(true)
	_original_window_size = get_window().size
	if not ClassDB.class_exists("MapPackageService"):
		_fail("Native MapPackageService is unavailable.")
		return
	_test_dir = "user://tests/map_editor_save_copy_%s" % Time.get_ticks_msec()
	var source_stem := "source-editor-package"
	var source_map_path := "%s/%s.amap" % [_test_dir, source_stem]
	var source_scenario_path := "%s/%s.ascenario" % [_test_dir, source_stem]
	var authored_scenario_bytes := FileAccess.get_file_as_bytes(SCENARIOS_PATH)
	var authored_terrain_bytes := FileAccess.get_file_as_bytes(TERRAIN_LAYERS_PATH)
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var source_result := _write_source_fixture(service, source_map_path, source_scenario_path)
	if not bool(source_result.get("ok", false)):
		_fail(String(source_result.get("message", "Could not write source fixture.")))
		return
	var source_map_bytes := FileAccess.get_file_as_bytes(source_map_path)
	var source_scenario_bytes := FileAccess.get_file_as_bytes(source_scenario_path)

	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	shell.set("validation_skip_initial_package_index", true)
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var loaded: Dictionary = shell.call("validation_load_package_from_directory", _test_dir, source_stem)
	if not bool(loaded.get("ok", false)):
		_fail("Editor could not load the package-backed source fixture: %s" % JSON.stringify(loaded.get("package_index", {})))
		return
	if bool(loaded.get("save_copy_button_disabled", true)):
		_fail("Save Copy remained disabled for a validated package working copy.")
		return
	var loaded_scenario_id := String(loaded.get("scenario_id", ""))
	if loaded_scenario_id == "" or ContentService.has_authored_scenario(loaded_scenario_id) or ContentService.has_generated_scenario_draft(loaded_scenario_id):
		_fail("Package fixture did not retain a generated/non-registry scenario identity: %s" % loaded_scenario_id)
		return
	var terrain_edit: Dictionary = shell.call("validation_paint_terrain", 0, 0, "forest")
	var road_edit: Dictionary = shell.call("validation_toggle_road", 0, 0)
	var start_edit: Dictionary = shell.call("validation_set_hero_start", 1, 0)
	if not bool(terrain_edit.get("ok", false)) or not bool(road_edit.get("ok", false)) or not bool(start_edit.get("ok", false)):
		_fail("Could not apply focused editor changes before Save Copy.")
		return
	shell = await _assert_package_play_copy_baseline_companion(
		shell,
		1280,
		source_map_path,
		source_scenario_path,
		source_map_bytes,
		source_scenario_bytes
	)
	if shell == null:
		return

	var first: Dictionary = shell.call("validation_save_copy", _test_dir, "saved-editor-copy")
	if not _assert_save_result(first, "saved-editor-copy"):
		return
	var first_map_bytes := FileAccess.get_file_as_bytes(String(first.get("map_path", "")))
	var first_scenario_bytes := FileAccess.get_file_as_bytes(String(first.get("scenario_path", "")))
	var first_pair := _assert_saved_pair(service, first)
	if not bool(first_pair.get("ok", false)):
		_fail(String(first_pair.get("message", "First saved pair validation failed.")))
		return
	var first_snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(first_snapshot.get("dirty", true)) or String(first_snapshot.get("editor_source_map_path", "")) != String(first.get("map_path", "")):
		_fail("First Save Copy did not adopt a clean package-backed baseline.")
		return
	var adopted_session = shell.get("_session")
	var adopted_baseline = shell.get("_authored_baseline_cache")
	if adopted_session == null or adopted_baseline == null or adopted_session == adopted_baseline \
			or adopted_session.to_dict() != adopted_baseline.to_dict():
		_fail("Save Copy did not adopt an exact detached package baseline companion.")
		return
	if ContentService.has_authored_scenario(adopted_session.scenario_id) or ContentService.has_generated_scenario_draft(adopted_session.scenario_id):
		_fail("First Save Copy adoption leaked its package scenario into a content registry.")
		return
	if String(first.get("map_path", "")) == source_map_path or String(first.get("scenario_path", "")) == source_scenario_path:
		_fail("Second Play Copy row did not receive an independent adopted package path.")
		return
	shell = await _assert_package_play_copy_baseline_companion(
		shell,
		1920,
		String(first.get("map_path", "")),
		String(first.get("scenario_path", "")),
		first_map_bytes,
		first_scenario_bytes
	)
	if shell == null:
		return

	var second: Dictionary = shell.call("validation_save_copy", _test_dir, "saved-editor-copy")
	if not _assert_save_result(second, "saved-editor-copy-2"):
		return
	if FileAccess.get_file_as_bytes(String(first.get("map_path", ""))) != first_map_bytes or FileAccess.get_file_as_bytes(String(first.get("scenario_path", ""))) != first_scenario_bytes:
		_fail("Second Save Copy overwrote the first saved package pair.")
		return
	var second_pair := _assert_saved_pair(service, second)
	if not bool(second_pair.get("ok", false)):
		_fail("Second saved package pair did not reload with the edited state: %s" % String(second_pair.get("message", "")))
		return
	var second_adopted_session = shell.get("_session")
	var second_adopted_baseline = shell.get("_authored_baseline_cache")
	if second_adopted_session == null or second_adopted_baseline == null \
			or second_adopted_session == second_adopted_baseline \
			or second_adopted_session.to_dict() != second_adopted_baseline.to_dict() \
			or ContentService.has_authored_scenario(second_adopted_session.scenario_id) \
			or ContentService.has_generated_scenario_draft(second_adopted_session.scenario_id):
		_fail("Second Save Copy did not adopt an exact detached non-registry package baseline.")
		return

	if FileAccess.get_file_as_bytes(source_map_path) != source_map_bytes or FileAccess.get_file_as_bytes(source_scenario_path) != source_scenario_bytes:
		_fail("Save Copy mutated the source package pair.")
		return
	if FileAccess.get_file_as_bytes(SCENARIOS_PATH) != authored_scenario_bytes or FileAccess.get_file_as_bytes(TERRAIN_LAYERS_PATH) != authored_terrain_bytes:
		_fail("Save Copy mutated authored JSON content.")
		return
	var skirmish_index: Dictionary = ScenarioSelectRules.maps_folder_package_index({"package_dir": _test_dir})
	var editor_index: Dictionary = ScenarioSelectRules.maps_folder_package_index({
		"package_dir": _test_dir,
		"include_non_launchable_generated_packages": true,
		"consumer": "map_editor",
	})
	if not skirmish_index.get("entries", []).is_empty():
		_fail("Editor-authored copies were exposed through the skirmish package index.")
		return
	if editor_index.get("entries", []).size() != 3:
		_fail("Editor package index did not retain source plus two saved copies: %s" % JSON.stringify(editor_index))
		return
	var invalid_session = shell.get("_session")
	invalid_session.overworld["map"][0][0] = "missing_editor_terrain"
	var failed: Dictionary = shell.call("validation_save_copy", _test_dir, "must-fail")
	if bool(failed.get("ok", true)) or String(failed.get("error_code", "")) != "draft_validation_failed":
		_fail("Invalid Save Copy draft did not fail closed: %s" % JSON.stringify(failed))
		return
	if FileAccess.file_exists("%s/must-fail.amap" % _test_dir) or FileAccess.file_exists("%s/must-fail.ascenario" % _test_dir):
		_fail("Failed Save Copy left a partial package output.")
		return
	var final_authority: Dictionary = _durable_authority()
	if not _durable_authority_exact(final_authority, _expected_authority_after_play):
		_fail("Package Play Copy/Restore Tile/Save Copy changed save, cache, settings, or schema authority.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"source_package_unchanged": true,
		"authored_json_unchanged": true,
		"first_stem": first.get("package_stem", ""),
		"second_stem": second.get("package_stem", ""),
		"object_count": first.get("object_count", 0),
		"player_slot_count": first.get("player_slot_count", 0),
		"editor_index_count": editor_index.get("entries", []).size(),
		"skirmish_index_count": skirmish_index.get("entries", []).size(),
		"failed_write_closed": true,
		"play_copy_baseline_companion": true,
		"external_package_move_change_remove": true,
		"restore_selected_tile_only": true,
		"repeat_restore_noop": true,
		"play_copy_widths": [1280, 1920],
		"independent_package_paths": true,
	})])
	_cleanup()
	get_tree().quit(0)

func _assert_package_play_copy_baseline_companion(
	shell: Node,
	width: int,
	map_path: String,
	scenario_path: String,
	map_bytes: PackedByteArray,
	scenario_bytes: PackedByteArray
):
	var row_authority_before: Dictionary = _durable_authority()
	get_window().size = Vector2i(width, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != Vector2i(width, 720):
		_fail("Package Play Copy row did not establish exact %d-wide host geometry." % width)
		return null
	var baseline_session = shell.get("_authored_baseline_cache")
	var working_session = shell.get("_session")
	if baseline_session == null or working_session == null or baseline_session == working_session:
		_fail("Loaded package did not start with a detached baseline companion.")
		return null
	var baseline_before: Dictionary = baseline_session.to_dict()
	var selected_before: Dictionary = shell.call("validation_select_tile", 0, 2)
	var selected_inspection_before: Dictionary = selected_before.get("tile_inspection", {}).duplicate(true)
	var town_before: Dictionary = _object_for_family(selected_inspection_before, "town")
	if String(town_before.get("placement_id", "")) != "riverwatch_hold":
		_fail("Package baseline fixture did not expose Riverwatch Hold on selected tile 0,2.")
		return null
	var selected_terrain_before := String(selected_inspection_before.get("terrain_id", ""))
	var alternate_terrain := "forest" if selected_terrain_before != "forest" else "grass"
	var terrain_edit: Dictionary = shell.call("validation_paint_terrain", 0, 2, alternate_terrain)
	var road_edit: Dictionary = shell.call("validation_toggle_road", 0, 2)
	var town_edit: Dictionary = shell.call("validation_edit_object_property", 0, 2, "town", "owner", "neutral")
	if not bool(terrain_edit.get("ok", false)) or not bool(road_edit.get("ok", false)) or not bool(town_edit.get("ok", false)):
		_fail("Could not edit representative terrain/road/object domains before package Play Copy.")
		return null
	if baseline_session.to_dict() != baseline_before:
		_fail("Package baseline companion aliased representative working-copy edits before Play Copy.")
		return null
	shell.call("_select_tool", "terrain")
	var restore_button: Control = shell.get_node("%RestoreSelectedTile")
	restore_button.grab_focus()
	await get_tree().process_frame
	shell.call("_prepare_working_copy_snapshot_for_return")
	var working_before_play: Dictionary = shell.get("_session").to_dict()
	var dirty_before_play: bool = bool(shell.call("validation_snapshot").get("dirty", false))
	if not dirty_before_play:
		_fail("Representative package edits did not leave the working copy dirty before Play Copy.")
		return null

	var parent := shell.get_parent()
	if parent != get_tree().root:
		parent.remove_child(shell)
		get_tree().root.add_child(shell)
	get_tree().current_scene = shell
	var return_route_before: Dictionary = AppRouter.validation_active_play_return_snapshot()
	var unrelated_routes_before := {
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
		"close_guard": AppRouter.validation_safe_close_guard_snapshot(),
		"outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
	}
	var launch: Dictionary = shell.call("validation_launch_working_copy")
	if not bool(launch.get("ok", false)) or not bool(launch.get("editor_snapshot_available", false)):
		_fail("Generated package Play Copy did not stage its working-copy/baseline companion: %s" % JSON.stringify(launch))
		return null
	var staged_working = SessionState.duplicate_editor_working_copy_session()
	var staged_baseline = SessionState.duplicate_editor_working_copy_baseline_session()
	var staged_identity: Dictionary = SessionState._editor_working_copy_package_identity.duplicate(true)
	if staged_working == null or staged_baseline == null \
			or staged_working.to_dict() != working_before_play \
			or staged_baseline.to_dict() != baseline_before \
			or staged_working == shell.get("_session") \
			or staged_baseline == baseline_session \
			or staged_identity != SessionState.editor_package_identity(staged_working) \
			or staged_identity != SessionState.editor_package_identity(staged_baseline):
		_fail("Play Copy did not stage exact detached and identity-aligned package companions.")
		return null

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var overworld := get_tree().current_scene
	if overworld == null or not overworld.has_method("validation_return_to_menu"):
		_fail("Package Play Copy did not reach the real Overworld return surface.")
		return null
	var play_entry_authority: Dictionary = _durable_authority()
	var play_entry_files: Dictionary = play_entry_authority.get("files", {}).duplicate(true)
	var autosave_path := "%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]
	var play_entry_file_differences: Array[String] = _file_state_differences(
		row_authority_before.get("files", {}),
		play_entry_files
	)
	var play_entry_autosave: Dictionary = play_entry_files.get(autosave_path, {}) if play_entry_files.get(autosave_path, {}) is Dictionary else {}
	var play_entry_checks := {
		"play_entry_only_autosave_changed": play_entry_file_differences == [autosave_path],
		"play_entry_autosave_present": bool(play_entry_autosave.get("exists", false)),
		"play_entry_autosave_nonempty": play_entry_autosave.get("bytes", PackedByteArray()) is PackedByteArray and not play_entry_autosave.get("bytes", PackedByteArray()).is_empty(),
	}
	if not _checks_exact(play_entry_checks):
		_fail("Package Play Copy row %d entry autosave authority failed: %s values=%s" % [
			width,
			JSON.stringify(_failed_check_names(play_entry_checks)),
			JSON.stringify({
				"file_differences": play_entry_file_differences,
				"autosave_path": autosave_path,
				"autosave_exists": play_entry_autosave.get("exists", null),
				"autosave_size": play_entry_autosave.get("bytes", PackedByteArray()).size() if play_entry_autosave.get("bytes", PackedByteArray()) is PackedByteArray else -1,
			})
		])
		return null
	_expected_authority_after_play = play_entry_authority.duplicate(true)
	SessionState.ensure_active_session().day += 4
	SessionState.ensure_active_session().flags["live_play_only_marker"] = "discard-me"

	var moved_map_path := "%s.moved" % map_path
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(map_path), ProjectSettings.globalize_path(moved_map_path)) != OK:
		_fail("Could not move the package map while Play Copy was active.")
		return null
	if not _write_bytes(moved_map_path, "externally changed package map".to_utf8_buffer()):
		_fail("Could not change the moved package map while Play Copy was active.")
		return null
	_remove_path(moved_map_path)
	_remove_path(scenario_path)
	if FileAccess.file_exists(map_path) or FileAccess.file_exists(moved_map_path) or FileAccess.file_exists(scenario_path):
		_fail("External package move/change/remove fixture did not remove both live package paths.")
		return null

	var return_result: Dictionary = overworld.call("validation_return_to_menu")
	if not bool(return_result.get("ok", false)) or String(return_result.get("reason", "")) != "editor_return":
		_fail("Real package Play Copy return did not choose the editor-return route: %s" % JSON.stringify(return_result))
		return null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var returned_shell := get_tree().current_scene
	if returned_shell == null or not returned_shell.has_method("validation_restore_selected_tile"):
		_fail("Package Play Copy return did not instantiate MapEditorShell.")
		return null
	var returned_snapshot: Dictionary = returned_shell.call("validation_snapshot")
	var return_route_after: Dictionary = AppRouter.validation_active_play_return_snapshot()
	var last_route: Dictionary = return_route_after.get("last_route", {}) if return_route_after.get("last_route", {}) is Dictionary else {}
	var unrelated_routes_after := {
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
		"close_guard": AppRouter.validation_safe_close_guard_snapshot(),
		"outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
	}
	var returned_session = returned_shell.get("_session")
	var returned_baseline = returned_shell.get("_authored_baseline_cache")
	var second_consume: Dictionary = SessionState.consume_editor_return_snapshot()
	var returned_working_payload: Dictionary = returned_session.to_dict() if returned_session != null else {}
	var returned_baseline_payload: Dictionary = returned_baseline.to_dict() if returned_baseline != null else {}
	var returned_working_identity: Dictionary = SessionState.editor_package_identity(returned_session)
	var returned_baseline_identity: Dictionary = SessionState.editor_package_identity(returned_baseline)
	var restore_cue: Dictionary = returned_snapshot.get("restore_tile_cue", {}) if returned_snapshot.get("restore_tile_cue", {}) is Dictionary else {}
	var last_result: Dictionary = return_route_after.get("last_result", {}) if return_route_after.get("last_result", {}) is Dictionary else {}
	var working_session_field_checks := {
		"working_save_version_exact": working_before_play.has("save_version") and returned_working_payload.has("save_version") and returned_working_payload["save_version"] == working_before_play["save_version"],
		"working_session_id_exact": working_before_play.has("session_id") and returned_working_payload.has("session_id") and returned_working_payload["session_id"] == working_before_play["session_id"],
		"working_scenario_id_exact": working_before_play.has("scenario_id") and returned_working_payload.has("scenario_id") and returned_working_payload["scenario_id"] == working_before_play["scenario_id"],
		"working_hero_id_exact": working_before_play.has("hero_id") and returned_working_payload.has("hero_id") and returned_working_payload["hero_id"] == working_before_play["hero_id"],
		"working_day_exact": working_before_play.has("day") and returned_working_payload.has("day") and returned_working_payload["day"] == working_before_play["day"],
		"working_difficulty_exact": working_before_play.has("difficulty") and returned_working_payload.has("difficulty") and returned_working_payload["difficulty"] == working_before_play["difficulty"],
		"working_launch_mode_exact": working_before_play.has("launch_mode") and returned_working_payload.has("launch_mode") and returned_working_payload["launch_mode"] == working_before_play["launch_mode"],
		"working_game_state_exact": working_before_play.has("game_state") and returned_working_payload.has("game_state") and returned_working_payload["game_state"] == working_before_play["game_state"],
		"working_scenario_status_exact": working_before_play.has("scenario_status") and returned_working_payload.has("scenario_status") and returned_working_payload["scenario_status"] == working_before_play["scenario_status"],
		"working_scenario_summary_exact": working_before_play.has("scenario_summary") and returned_working_payload.has("scenario_summary") and returned_working_payload["scenario_summary"] == working_before_play["scenario_summary"],
		"working_overworld_exact": working_before_play.has("overworld") and returned_working_payload.has("overworld") and returned_working_payload["overworld"] == working_before_play["overworld"],
		"working_battle_exact": working_before_play.has("battle") and returned_working_payload.has("battle") and returned_working_payload["battle"] == working_before_play["battle"],
		"working_flags_exact": working_before_play.has("flags") and returned_working_payload.has("flags") and returned_working_payload["flags"] == working_before_play["flags"],
	}
	var working_overworld_before: Dictionary = working_before_play.get("overworld", {}) if working_before_play.get("overworld", {}) is Dictionary else {}
	var working_overworld_after: Dictionary = returned_working_payload.get("overworld", {}) if returned_working_payload.get("overworld", {}) is Dictionary else {}
	var working_overworld_checks: Dictionary = _dictionary_union_exact_checks(
		working_overworld_before,
		working_overworld_after,
		"working_overworld"
	)
	var return_checks := {
		"working_session_present": returned_session != null,
		"baseline_session_present": returned_baseline != null,
		"working_payload_exact": returned_working_payload == working_before_play,
		"baseline_payload_exact": returned_baseline_payload == baseline_before,
		"working_baseline_distinct_refs": returned_session != null and returned_baseline != null and returned_session != returned_baseline,
		"working_identity_exact": returned_working_identity == staged_identity,
		"baseline_identity_exact": returned_baseline_identity == staged_identity,
		"restored_from_play_copy": bool(returned_snapshot.get("restored_from_play_copy", false)),
		"source_map_path_exact": String(returned_snapshot.get("editor_source_map_path", "")) == map_path,
		"source_scenario_path_exact": String(returned_snapshot.get("editor_source_scenario_path", "")) == scenario_path,
		"restore_cue_changed": bool(restore_cue.get("changed", false)),
		"stored_working_copy_absent": SessionState.editor_working_copy_session == null,
		"stored_baseline_absent": SessionState._editor_working_copy_baseline_session == null,
		"stored_package_identity_absent": SessionState._editor_working_copy_package_identity.is_empty(),
		"return_pending_false": not SessionState.editor_return_pending(),
		"second_consume_empty": second_consume.is_empty(),
		"authored_registry_absent": returned_session != null and not ContentService.has_authored_scenario(returned_session.scenario_id),
		"generated_registry_absent": returned_session != null and not ContentService.has_generated_scenario_draft(returned_session.scenario_id),
		"return_request_plus_one": int(return_route_after.get("request_count", -1)) == int(return_route_before.get("request_count", -1)) + 1,
		"return_route_plus_one": int(return_route_after.get("route_attempt_count", -1)) == int(return_route_before.get("route_attempt_count", -1)) + 1,
		"return_save_unchanged": int(return_route_after.get("save_attempt_count", -1)) == int(return_route_before.get("save_attempt_count", -1)),
		"return_target_editor": String(last_route.get("target_scene", "")) == AppRouter.MAP_EDITOR_SCENE,
		"return_reason_editor": String(last_result.get("reason", "")) == "editor_return",
		"unrelated_routes_exact": unrelated_routes_after == unrelated_routes_before,
	}
	if not _checks_exact(return_checks) \
			or not _checks_exact(working_session_field_checks) \
			or not _checks_exact(working_overworld_checks):
		_fail("Returned package editor companion checks failed: %s values=%s" % [
			JSON.stringify(return_checks),
			JSON.stringify({
				"working_session_failed_checks": _failed_check_names(working_session_field_checks),
				"working_overworld_failed_checks": _failed_check_names(working_overworld_checks),
				"working_payload_differences": _recursive_exact_differences(working_before_play, returned_working_payload),
				"working_before_sha": JSON.stringify(working_before_play).sha256_text(),
				"working_after_sha": JSON.stringify(returned_working_payload).sha256_text(),
				"baseline_before_sha": JSON.stringify(baseline_before).sha256_text(),
				"baseline_after_sha": JSON.stringify(returned_baseline_payload).sha256_text(),
				"working_ref": returned_session.get_instance_id() if returned_session != null else -1,
				"baseline_ref": returned_baseline.get_instance_id() if returned_baseline != null else -1,
				"staged_identity": staged_identity,
				"working_identity": returned_working_identity,
				"baseline_identity": returned_baseline_identity,
				"paths": {"expected_map": map_path, "actual_map": returned_snapshot.get("editor_source_map_path", ""), "expected_scenario": scenario_path, "actual_scenario": returned_snapshot.get("editor_source_scenario_path", "")},
				"route_counts_before": {"request": return_route_before.get("request_count", -1), "route": return_route_before.get("route_attempt_count", -1), "save": return_route_before.get("save_attempt_count", -1)},
				"route_counts_after": {"request": return_route_after.get("request_count", -1), "route": return_route_after.get("route_attempt_count", -1), "save": return_route_after.get("save_attempt_count", -1)},
				"last_route": last_route,
				"last_result_reason": last_result.get("reason", ""),
			})
		])
		return null

	returned_shell.call("validation_set_tool", "terrain")
	var returned_restore_button: Control = returned_shell.get_node("%RestoreSelectedTile")
	returned_restore_button.grab_focus()
	await get_tree().process_frame
	var returned_focus := returned_shell.get_viewport().gui_get_focus_owner()
	var unrelated_tile_before: Dictionary = _detached_tile_content(returned_shell, Vector2i(0, 0))
	var unrelated_hero_before: Dictionary = returned_shell.call("validation_snapshot").get("hero_position", {}).duplicate(true)
	var restore: Dictionary = returned_shell.call("validation_restore_selected_tile", 0, 2)
	var restored_inspection: Dictionary = restore.get("tile_inspection", {}).duplicate(true)
	var restored_snapshot: Dictionary = returned_shell.call("validation_snapshot").duplicate(true)
	var unrelated_tile_after: Dictionary = _detached_tile_content(returned_shell, Vector2i(0, 0))
	var unrelated_hero_after: Dictionary = restored_snapshot.get("hero_position", {}).duplicate(true)
	var returned_focus_after := returned_shell.get_viewport().gui_get_focus_owner()
	var restore_checks := {
		"restore_ok": bool(restore.get("ok", false)),
		"restore_changed": bool(restore.get("changed", false)),
		"selected_exact": restored_inspection == selected_inspection_before,
		"unrelated_exact": unrelated_tile_after == unrelated_tile_before,
		"hero_exact": unrelated_hero_after == unrelated_hero_before,
		"dirty_true": bool(restored_snapshot.get("dirty", false)),
		"tool_terrain": String(restored_snapshot.get("tool", "")) == "terrain",
		"focus_expected_nonnull": returned_focus != null,
		"focus_is_same": returned_focus != null and returned_focus_after != null and is_same(returned_focus_after, returned_focus),
	}
	if not _checks_exact(restore_checks):
		_fail("Restore Tile exact checks failed: %s values=%s" % [
			JSON.stringify(_failed_check_names(restore_checks)),
			JSON.stringify({
				"selected_before_sha": JSON.stringify(selected_inspection_before).sha256_text(),
				"selected_after_sha": JSON.stringify(restored_inspection).sha256_text(),
				"selected_differences": _recursive_exact_differences(selected_inspection_before, restored_inspection),
				"unrelated_before_sha": JSON.stringify(unrelated_tile_before).sha256_text(),
				"unrelated_after_sha": JSON.stringify(unrelated_tile_after).sha256_text(),
				"unrelated_differences": _recursive_exact_differences(unrelated_tile_before, unrelated_tile_after),
				"hero_before": unrelated_hero_before,
				"hero_after": unrelated_hero_after,
				"dirty_after": restored_snapshot.get("dirty", null),
				"tool_after": restored_snapshot.get("tool", null),
				"focus_before_id": returned_focus.get_instance_id() if returned_focus != null else -1,
				"focus_after_id": returned_focus_after.get_instance_id() if returned_focus_after != null else -1,
				"focus_before_name": returned_focus.name if returned_focus != null else "",
				"focus_after_name": returned_focus_after.name if returned_focus_after != null else "",
			})
		])
		return null
	var after_first_restore: Dictionary = returned_shell.get("_session").to_dict()
	var repeated: Dictionary = returned_shell.call("validation_restore_selected_tile", 0, 2)
	if not bool(repeated.get("ok", false)) or bool(repeated.get("changed", true)) \
			or returned_shell.get("_session").to_dict() != after_first_restore:
		_fail("Repeated package Restore Tile was not an exact no-op.")
		return null

	if not _write_bytes(map_path, map_bytes) or not _write_bytes(scenario_path, scenario_bytes):
		_fail("Could not restore exact package bytes after external move/change/remove proof.")
		return null
	if FileAccess.get_file_as_bytes(map_path) != map_bytes or FileAccess.get_file_as_bytes(scenario_path) != scenario_bytes:
		_fail("External package fixture restoration did not recover exact original bytes.")
		return null
	var row_authority_after: Dictionary = _durable_authority()
	var durable_checks := {
		"durable_files_exact": row_authority_after.get("files", {}) == play_entry_files,
		"summary_cache_exact": row_authority_after.get("summary_cache", {}) == row_authority_before.get("summary_cache", {}),
		"save_version_exact": row_authority_after.get("save_version", -1) == row_authority_before.get("save_version", -1),
		"settings_transaction_exact": row_authority_after.get("settings_transaction_canonical", {}) == row_authority_before.get("settings_transaction_canonical", {}),
	}
	if not _checks_exact(durable_checks):
		_fail("Package Play Copy row %d durable authority failed: %s values=%s" % [
			width,
			JSON.stringify(durable_checks),
			JSON.stringify({
				"file_differences": _file_state_differences(play_entry_files, row_authority_after.get("files", {})),
				"cache_before_sha": JSON.stringify(row_authority_before.get("summary_cache", {})).sha256_text(),
				"cache_after_sha": JSON.stringify(row_authority_after.get("summary_cache", {})).sha256_text(),
				"save_version_before": row_authority_before.get("save_version", -1),
				"save_version_after": row_authority_after.get("save_version", -1),
				"settings_raw_equal_diagnostic": row_authority_after.get("settings_transaction_raw", {}) == row_authority_before.get("settings_transaction_raw", {}),
				"settings_before_sha": JSON.stringify(row_authority_before.get("settings_transaction_canonical", {})).sha256_text(),
				"settings_after_sha": JSON.stringify(row_authority_after.get("settings_transaction_canonical", {})).sha256_text(),
			})
		])
		return null
	get_window().size = _original_window_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != _original_window_size:
		_fail("Package Play Copy row %d did not restore the exact original window size." % width)
		return null
	return returned_shell

func _object_for_family(inspection: Dictionary, family: String) -> Dictionary:
	for detail_value in inspection.get("object_details", []):
		if detail_value is Dictionary and String(detail_value.get("kind", "")) == family:
			return detail_value
	return {}

func _detached_tile_content(shell: Node, tile: Vector2i) -> Dictionary:
	return {
		"x": tile.x,
		"y": tile.y,
		"terrain_id": shell.call("_terrain_at", tile),
		"road": shell.call("_has_road_at", tile),
		"road_layers": shell.call("_road_layer_ids_at", tile).duplicate(true),
		"object_details": shell.call("_object_details_at", tile, true).duplicate(true),
	}

func _durable_authority() -> Dictionary:
	var paths: Array[String] = [
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE],
		"%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE],
		SettingsService.SETTINGS_FILE,
		SettingsService.SETTINGS_CANDIDATE_FILE,
		SettingsService.SETTINGS_BACKUP_FILE,
	]
	for slot in [1, 2, 3]:
		paths.append("%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot])
	var files := {}
	for path in paths:
		files[path] = {
			"exists": FileAccess.file_exists(path),
			"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
		}
	var settings_transaction_raw: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	return {
		"files": files,
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
		"save_version": SessionState.SAVE_VERSION,
		"settings_transaction_raw": settings_transaction_raw,
		"settings_transaction_canonical": _canonical_settings_transaction(settings_transaction_raw),
	}

func _durable_authority_exact(after: Dictionary, before: Dictionary) -> bool:
	return (
		after.get("files", {}) == before.get("files", {})
		and after.get("summary_cache", {}) == before.get("summary_cache", {})
		and after.get("save_version", -1) == before.get("save_version", -1)
		and after.get("settings_transaction_canonical", {}) == before.get("settings_transaction_canonical", {})
	)

func _canonical_settings_transaction(transaction: Dictionary) -> Dictionary:
	var canonical: Dictionary = transaction.duplicate(true)
	var canonical_input_map := {}
	var input_map: Dictionary = transaction.get("input_map", {}) if transaction.get("input_map", {}) is Dictionary else {}
	for action_value in input_map.keys():
		var action := String(action_value)
		var action_state: Dictionary = input_map.get(action_value, {}) if input_map.get(action_value, {}) is Dictionary else {}
		var canonical_events: Array = []
		var events: Array = action_state.get("events", []) if action_state.get("events", []) is Array else []
		for event_value in events:
			if event_value is InputEvent:
				canonical_events.append(_canonical_stored_input_event(event_value as InputEvent))
			else:
				canonical_events.append({
					"class": "",
					"as_text": var_to_str(event_value),
					"stored_properties": [],
				})
		canonical_input_map[action] = {
			"action": action,
			"exists": bool(action_state.get("exists", false)),
			"deadzone": float(action_state.get("deadzone", 0.5)),
			"events": canonical_events,
		}
	canonical["input_map"] = canonical_input_map
	return canonical

func _canonical_stored_input_event(event: InputEvent) -> Dictionary:
	var stored_properties: Array = []
	for property_value in event.get_property_list():
		if not (property_value is Dictionary):
			continue
		var property: Dictionary = property_value
		var property_name := String(property.get("name", ""))
		var property_usage := int(property.get("usage", 0))
		if property_name == "script" or (property_usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		stored_properties.append({
			"name": property_name,
			"value": var_to_str(event.get(property_name)),
		})
	return {
		"class": event.get_class(),
		"as_text": event.as_text(),
		"stored_properties": stored_properties,
	}

func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true

func _failed_check_names(checks: Dictionary) -> Array[String]:
	var failed: Array[String] = []
	for check_value in checks.keys():
		var check_name := String(check_value)
		if not bool(checks.get(check_value, false)):
			failed.append(check_name)
	failed.sort()
	return failed

func _dictionary_union_exact_checks(before: Dictionary, after: Dictionary, prefix: String) -> Dictionary:
	var union_keys: Array = before.keys()
	for key_value in after.keys():
		if key_value not in union_keys:
			union_keys.append(key_value)
	union_keys.sort()
	var checks := {}
	for key_value in union_keys:
		var check_name := "%s[%s]" % [prefix, JSON.stringify(String(key_value))]
		checks[check_name] = before.has(key_value) and after.has(key_value) and before[key_value] == after[key_value]
	return checks

func _recursive_exact_differences(before: Variant, after: Variant, path: String = "$") -> Array[Dictionary]:
	var differences: Array[Dictionary] = []
	_collect_recursive_exact_differences(before, true, after, true, path, differences)
	return differences

func _collect_recursive_exact_differences(
	before: Variant,
	before_present: bool,
	after: Variant,
	after_present: bool,
	path: String,
	differences: Array[Dictionary]
) -> void:
	if not before_present or not after_present:
		differences.append({
			"path": path,
			"before": _compact_diff_value(before, before_present),
			"after": _compact_diff_value(after, after_present),
		})
		return
	if typeof(before) != typeof(after):
		differences.append({
			"path": path,
			"before": _compact_diff_value(before, true),
			"after": _compact_diff_value(after, true),
		})
		return
	if before is Dictionary:
		var before_dictionary: Dictionary = before
		var after_dictionary: Dictionary = after
		var union_keys: Array = before_dictionary.keys()
		for key_value in after_dictionary.keys():
			if key_value not in union_keys:
				union_keys.append(key_value)
		union_keys.sort()
		for key_value in union_keys:
			_collect_recursive_exact_differences(
				before_dictionary.get(key_value),
				before_dictionary.has(key_value),
				after_dictionary.get(key_value),
				after_dictionary.has(key_value),
				"%s[%s]" % [path, JSON.stringify(String(key_value))],
				differences
			)
		return
	if before is Array:
		var before_array: Array = before
		var after_array: Array = after
		if before_array.size() != after_array.size():
			differences.append({
				"path": "%s.length" % path,
				"before": _compact_diff_value(before_array.size(), true),
				"after": _compact_diff_value(after_array.size(), true),
			})
		for index in range(min(before_array.size(), after_array.size())):
			_collect_recursive_exact_differences(
				before_array[index],
				true,
				after_array[index],
				true,
				"%s[%d]" % [path, index],
				differences
			)
		for index in range(after_array.size(), before_array.size()):
			_collect_recursive_exact_differences(before_array[index], true, null, false, "%s[%d]" % [path, index], differences)
		for index in range(before_array.size(), after_array.size()):
			_collect_recursive_exact_differences(null, false, after_array[index], true, "%s[%d]" % [path, index], differences)
		return
	if before != after:
		differences.append({
			"path": path,
			"before": _compact_diff_value(before, true),
			"after": _compact_diff_value(after, true),
		})

func _compact_diff_value(value: Variant, present: bool) -> Dictionary:
	if not present:
		return {"present": false, "type": "missing"}
	var encoded := var_to_str(value).replace("\n", "\\n")
	return {
		"present": true,
		"type": type_string(typeof(value)),
		"preview": encoded.left(160),
		"sha256": encoded.sha256_text(),
	}

func _file_state_differences(before: Dictionary, after: Dictionary) -> Array[String]:
	var paths: Array = before.keys()
	for path in after.keys():
		if path not in paths:
			paths.append(path)
	paths.sort()
	var differences: Array[String] = []
	for path_value in paths:
		var path := String(path_value)
		if not before.has(path) or not after.has(path) or before.get(path, {}) != after.get(path, {}):
			differences.append(path)
	return differences

func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true

func _remove_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _write_source_fixture(service: Variant, map_path: String, scenario_path: String) -> Dictionary:
	var scenario := ContentService.get_authored_scenario("river-pass")
	var terrain_layers := ContentService.get_terrain_layers_for_scenario("river-pass")
	if scenario.is_empty() or terrain_layers.is_empty():
		return {"ok": false, "message": "River Pass fixture records are unavailable."}
	scenario = scenario.duplicate(true)
	var towns: Array = scenario.get("towns", [])
	var first_town: Dictionary = towns[0].duplicate(true)
	first_town["opaque_town_fixture_field"] = {"preserve": "town-exactly"}
	towns[0] = first_town
	scenario["towns"] = towns
	scenario["map_objects"] = [{
		"placement_id": "editor-copy-decor-1",
		"kind": "decorative_obstacle",
		"native_record_kind": "decorative_obstacle",
		"object_id": "object_editor_copy_stone",
		"object_family_id": "decorative_obstacle",
		"x": 0,
		"y": 0,
		"level": 0,
		"opaque_fixture_field": {"preserve": "exactly"},
	}]
	scenario["player_slots"] = [
		{"slot": 1, "owner": "player", "human": true, "computer": false, "faction_id": "faction_embercourt", "team": 7},
		{"slot": 2, "owner": "enemy", "human": false, "computer": true, "faction_id": "faction_mireclaw", "team": 9},
	]
	var conversion: Dictionary = service.convert_legacy_scenario_record(scenario, terrain_layers, {
		"map_id": "source-editor-package-map",
		"scenario_id": source_stem_from_path(scenario_path),
	})
	if not bool(conversion.get("ok", false)):
		return {"ok": false, "message": "Source conversion failed: %s" % JSON.stringify(conversion)}
	var map_document: Variant = conversion.get("map_document", null)
	var scenario_document: Variant = conversion.get("scenario_document", null)
	var converted_town: Dictionary = map_document.get_object_by_placement_id("riverwatch_hold")
	if converted_town.get("opaque_town_fixture_field", {}) != {"preserve": "town-exactly"}:
		return {"ok": false, "message": "Source conversion dropped opaque town fields: %s" % JSON.stringify(converted_town)}
	var map_save: Dictionary = service.save_map_package(map_document, map_path, {"path_policy": "editor_save_copy_fixture", "return_package": false})
	var map_load: Dictionary = service.load_map_package(map_path)
	if not bool(map_save.get("ok", false)) or not bool(map_load.get("ok", false)):
		return {"ok": false, "message": "Source map package write failed."}
	var reloaded_town: Dictionary = map_load.get("map_document", null).get_object_by_placement_id("riverwatch_hold")
	if reloaded_town.get("opaque_town_fixture_field", {}) != {"preserve": "town-exactly"}:
		return {"ok": false, "message": "Source package reload dropped opaque town fields: %s" % JSON.stringify(reloaded_town)}
	scenario_document.configure({
		"scenario_id": scenario_document.get_scenario_id(),
		"scenario_hash": scenario_document.get_scenario_hash(),
		"map_ref": map_load.get("map_ref", {}),
		"selection": scenario_document.get_selection(),
		"player_slots": scenario_document.get_player_slots(),
		"objectives": scenario_document.get_objectives(),
		"script_hooks": scenario_document.get_script_hooks(),
		"enemy_factions": scenario_document.get_enemy_factions(),
		"start_contract": scenario_document.get_start_contract(),
	})
	var scenario_save: Dictionary = service.save_scenario_package(scenario_document, scenario_path, {"path_policy": "editor_save_copy_fixture", "return_package": false})
	return {"ok": bool(scenario_save.get("ok", false)), "message": JSON.stringify(scenario_save)}

func _assert_save_result(result: Dictionary, expected_stem: String) -> bool:
	if not bool(result.get("ok", false)) or String(result.get("package_stem", "")) != expected_stem:
		_fail("Save Copy result mismatch: %s" % JSON.stringify(result))
		return false
	if not bool(result.get("editor_inspection_only", false)) or bool(result.get("authored_json_writeback", true)):
		_fail("Save Copy lost its editor-only/no-writeback boundary: %s" % JSON.stringify(result))
		return false
	if not FileAccess.file_exists(String(result.get("map_path", ""))) or not FileAccess.file_exists(String(result.get("scenario_path", ""))):
		_fail("Save Copy did not write both package files.")
		return false
	return true

func _assert_saved_pair(service: Variant, result: Dictionary) -> Dictionary:
	var map_load: Dictionary = service.load_map_package(String(result.get("map_path", "")))
	var scenario_load: Dictionary = service.load_scenario_package(String(result.get("scenario_path", "")))
	if not bool(map_load.get("ok", false)) or not bool(scenario_load.get("ok", false)):
		return {"ok": false, "message": "Saved pair did not reload."}
	var map_document: Variant = map_load.get("map_document", null)
	var scenario_document: Variant = scenario_load.get("scenario_document", null)
	if not bool(service.validate_map_document(map_document).get("ok", false)) or not bool(service.validate_scenario_document(scenario_document, map_document).get("ok", false)):
		return {"ok": false, "message": "Saved pair failed structural validation."}
	var decor: Dictionary = map_document.get_object_by_placement_id("editor-copy-decor-1")
	if decor.get("opaque_fixture_field", {}) != {"preserve": "exactly"}:
		return {"ok": false, "message": "Standalone decorative object fields were not preserved."}
	var town: Dictionary = map_document.get_object_by_placement_id("riverwatch_hold")
	if town.get("opaque_town_fixture_field", {}) != {"preserve": "town-exactly"}:
		return {"ok": false, "message": "Editable town object fields were not preserved: %s" % JSON.stringify(town)}
	if map_document.get_object_count() != 21:
		return {"ok": false, "message": "Saved object topology changed: %d" % map_document.get_object_count()}
	var terrain_ids: Array = map_document.get_terrain_layers().get("terrain_id_by_code", [])
	var terrain_codes: PackedInt32Array = map_document.get_tile_layer_u16("terrain", 0)
	if terrain_codes.is_empty() or String(terrain_ids[int(terrain_codes[0])]) != "forest":
		return {"ok": false, "message": "Saved terrain edit was not preserved."}
	var start: Dictionary = scenario_document.get_start_contract()
	if int(start.get("x", -1)) != 1 or int(start.get("y", -1)) != 0:
		return {"ok": false, "message": "Saved hero start edit was not preserved."}
	var slots: Array = scenario_document.get_player_slots()
	if slots.size() != 2 or int(slots[0].get("team", -1)) != 7 or int(slots[1].get("team", -1)) != 9:
		return {"ok": false, "message": "Explicit player slots were not preserved."}
	return {"ok": true}

func source_stem_from_path(path: String) -> String:
	return path.get_file().get_basename()

func _cleanup() -> void:
	if _original_window_size != Vector2i.ZERO:
		get_window().size = _original_window_size
	SessionState.active_session = _original_active_session
	SessionState.editor_working_copy_session = _original_editor_working_copy
	SessionState._editor_working_copy_baseline_session = _original_editor_baseline
	SessionState._editor_working_copy_package_identity = _original_editor_package_identity.duplicate(true)
	SessionState._editor_return_pending = _original_editor_return_pending
	if _test_dir == "":
		return
	var dir := DirAccess.open(_test_dir)
	if dir != null:
		dir.list_dir_begin()
		var filename := dir.get_next()
		while filename != "":
			if not dir.current_is_dir():
				DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [_test_dir, filename]))
			filename = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_dir))

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	_cleanup()
	get_tree().quit(1)
