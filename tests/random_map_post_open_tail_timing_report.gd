extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "RANDOM_MAP_POST_OPEN_TAIL_TIMING_REPORT"
const FIRST_VISIBLE_BUDGET_MS := 2500
const TAIL_WITH_DEFERRED_AUTOSAVE_BUDGET_MS := 2500
const GENERATED_OPENING_SAVE_FAILURE_ENV := "HEROES_LIKE_GENERATED_OPENING_AUTOSAVE_FORCE_FAILURE"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const CANONICAL_SESSION_KEYS := [
	"save_version",
	"session_id",
	"scenario_id",
	"hero_id",
	"day",
	"difficulty",
	"launch_mode",
	"game_state",
	"scenario_status",
	"scenario_summary",
	"overworld",
	"battle",
	"flags",
]

var _original_autosave_state := {}
var _original_active_payload := {}
var _original_failure_env := ""
var _owned_nodes: Array[Node] = []
var _cleanup_done := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_capture_original_state()
	ContentService.clear_generated_scenario_drafts()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	_owned_nodes.append(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not _assert_hooks(shell):
		return
	shell.call("validation_open_skirmish_stage")
	if not bool(shell.call("validation_set_generated_seed", "post-open-tail-10184")):
		_fail("Seed control hook did not update generated setup.")
		return
	if not bool(shell.call("validation_select_generated_size_class", "homm3_small")):
		_fail("Size-class control hook did not select Small.")
		return
	if not bool(shell.call("validation_select_generated_water_mode", "land")):
		_fail("Water control hook did not select land.")
		return
	if not bool(shell.call("validation_set_generated_underground", false)):
		_fail("Underground control hook did not disable underground.")
		return

	var start_msec := Time.get_ticks_msec()
	var result: Dictionary = await shell.validation_start_generated_skirmish_staged()
	if not bool(result.get("started", false)):
		_fail("Generated staged launch did not start: %s" % JSON.stringify(result))
		return
	AppRouter.begin_overworld_handoff_profile(
		"generated_random_map_post_open_tail",
		{
			"stage": String(result.get("stage", {}).get("stage", "")),
			"scenario_id": String(result.get("active_scenario_id", "")),
			"size_class_id": "homm3_small",
		}
	)
	var prepare_result: Dictionary = AppRouter.validation_prepare_overworld_handoff_without_scene_change()
	if not bool(prepare_result.get("ok", false)):
		_fail("AppRouter did not prepare generated overworld handoff: %s" % JSON.stringify(prepare_result))
		return
	var scene: Node = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(scene)
	_owned_nodes.append(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if scene == null:
		_fail("Generated route did not reach OverworldShell.")
		return
	var route_elapsed := Time.get_ticks_msec() - start_msec
	var profile: Dictionary = AppRouter.validation_latest_overworld_handoff_profile()
	var save_profile: Dictionary = SaveService.validation_last_runtime_save_profile()
	var session = SessionState.ensure_active_session()

	if profile.is_empty():
		_fail("Post-open route profile was not recorded.")
		return
	if bool(profile.get("active", true)):
		_fail("Post-open route profile did not finish: %s" % JSON.stringify(profile))
		return
	var first_visible_ms := _profile_step_elapsed(profile, "overworld_ready_render_state_done")
	if first_visible_ms < 0:
		_fail("Post-open route profile missed first visible marker: %s" % JSON.stringify(profile))
		return
	if first_visible_ms > FIRST_VISIBLE_BUDGET_MS:
		_fail("Post-open first visible frame exceeded budget: %s" % JSON.stringify({
			"first_visible_ms": first_visible_ms,
			"profile": profile,
			"save_profile": save_profile,
		}))
		return
	if int(profile.get("total_ms", 0)) > TAIL_WITH_DEFERRED_AUTOSAVE_BUDGET_MS:
		_fail("Post-open tail with deferred autosave exceeded budget: %s" % JSON.stringify({
			"total_ms": int(profile.get("total_ms", 0)),
			"profile": profile,
			"save_profile": save_profile,
		}))
		return
	if not _assert_profile_steps(profile):
		return
	if not _assert_generated_overworld(session):
		return
	var generated_completion := _assert_generated_opening_completion(session)
	if generated_completion.is_empty():
		return
	var restored_route := _assert_restore_has_no_second_opening_save()
	if restored_route.is_empty():
		return
	var forced_failure := _assert_forced_opening_save_failure(generated_completion.get("raw_payload", {}))
	if forced_failure.is_empty():
		return
	var ordinary_control := _assert_ordinary_autosave_control()
	if ordinary_control.is_empty():
		return

	var report := {
		"ok": true,
		"route_elapsed_ms": route_elapsed,
		"first_visible_ms": first_visible_ms,
		"tail_with_deferred_autosave_ms": int(profile.get("total_ms", 0)),
		"profile": profile,
		"save_profile": save_profile,
		"map_size": session.overworld.get("map_size", {}),
		"scenario_id": session.scenario_id,
		"generated_completion": generated_completion.get("summary", {}),
		"restored_route": restored_route,
		"forced_failure": forced_failure,
		"ordinary_autosave_control": ordinary_control,
		"save_version": SessionState.SAVE_VERSION,
	}
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _assert_generated_opening_completion(session) -> Dictionary:
	var raw_payload := _read_raw_payload(AUTOSAVE_PATH)
	if raw_payload.is_empty():
		_fail("Generated opening autosave did not produce a readable raw payload.")
		return {}
	var raw_flags: Dictionary = raw_payload.get("flags", {}) if raw_payload.get("flags", {}) is Dictionary else {}
	if bool(raw_flags.get("generated_overworld_deferred_autosave_pending", false)) \
			or raw_flags.has("generated_overworld_deferred_autosave_pending"):
		_fail("Generated opening autosave persisted its deferred pending flag: %s" % JSON.stringify(raw_flags))
		return {}
	if bool(raw_flags.get("generated_overworld_command_briefing_autosave_deferred", false)) \
			or raw_flags.has("generated_overworld_command_briefing_autosave_deferred"):
		_fail("Generated opening autosave persisted its briefing defer flag: %s" % JSON.stringify(raw_flags))
		return {}
	if not bool(raw_flags.get("generated_overworld_initial_autosave_completed", false)):
		_fail("Generated opening autosave did not persist completion=true: %s" % JSON.stringify(raw_flags))
		return {}
	if not _assert_transition_intent_absent(raw_flags, "generated raw payload"):
		return {}
	var canonical_live_flags := _canonical_json_dictionary(session.flags)
	if canonical_live_flags != raw_flags:
		_fail("Generated opening save did not mirror the completed flag set to the live session: %s" % JSON.stringify({
			"different_keys": _different_dictionary_keys(canonical_live_flags, raw_flags),
			"live_key_count": canonical_live_flags.size(),
			"saved_key_count": raw_flags.size(),
		}))
		return {}
	if int(raw_payload.get("save_version", 0)) != 9 or SessionState.SAVE_VERSION != 9:
		_fail("Generated opening autosave changed the save-version contract: %s" % raw_payload.get("save_version", null))
		return {}
	if not _assert_payload_breadth(raw_payload, session.to_dict(), "generated opening"):
		return {}
	return {
		"raw_payload": raw_payload,
		"summary": {
			"saved_pending_absent": true,
			"saved_briefing_defer_absent": true,
			"saved_completion_true": true,
			"live_flags_match_saved": true,
			"transition_intent_absent": true,
			"payload_breadth_preserved": true,
		},
	}

func _assert_restore_has_no_second_opening_save() -> Dictionary:
	var restored = SaveService.restore_autosave_session()
	if restored == null:
		_fail("Completed generated opening autosave could not be restored.")
		return {}
	var restored_flags: Dictionary = restored.flags
	if bool(restored_flags.get("generated_overworld_deferred_autosave_pending", false)) \
			or bool(restored_flags.get("generated_overworld_command_briefing_autosave_deferred", false)) \
			or not bool(restored_flags.get("generated_overworld_initial_autosave_completed", false)):
		_fail("Restored generated opening save reintroduced an opening-save obligation: %s" % JSON.stringify(restored_flags))
		return {}
	if not _assert_transition_intent_absent(restored_flags, "restored generated session"):
		return {}
	SessionState.set_active_session(restored)
	var prepare_result: Dictionary = AppRouter.validation_prepare_overworld_handoff_without_scene_change()
	var live = SessionState.ensure_active_session()
	if not bool(prepare_result.get("ok", false)) \
			or bool(prepare_result.get("deferred_autosave", true)) \
			or bool(prepare_result.get("generated_deferred_autosave", true)) \
			or bool(live.flags.get("generated_overworld_deferred_autosave_pending", false)):
		_fail("Restored generated session scheduled a second opening autosave: %s" % JSON.stringify({
			"prepare": prepare_result,
			"flags": live.flags,
		}))
		return {}
	return {
		"restored": true,
		"completion_true": true,
		"second_opening_save_pending": false,
		"app_router_deferred_autosave": false,
	}

func _assert_forced_opening_save_failure(completed_payload_value: Variant) -> Dictionary:
	var completed_payload: Dictionary = completed_payload_value if completed_payload_value is Dictionary else {}
	var failure_session := SessionStateStoreScript.new_session_data()
	failure_session.from_dict(completed_payload)
	failure_session.flags["generated_random_map"] = true
	failure_session.flags["generated_overworld_deferred_autosave_pending"] = true
	failure_session.flags["generated_overworld_command_briefing_autosave_deferred"] = true
	failure_session.flags["generated_overworld_initial_autosave_completed"] = false
	for key in SaveService.TRANSITION_AUTOSAVE_INTENT_FLAGS:
		failure_session.flags[String(key)] = _transition_intent_fixture_value(String(key))
	var flags_before := failure_session.flags.duplicate(true)
	var file_before := _file_state(AUTOSAVE_PATH)
	OS.set_environment(GENERATED_OPENING_SAVE_FAILURE_ENV, "1")
	var failure_result: Dictionary = SaveService.save_runtime_autosave_session(failure_session, false)
	_restore_failure_env()
	if bool(failure_result.get("ok", true)):
		_fail("Forced generated opening autosave failure unexpectedly succeeded: %s" % JSON.stringify(failure_result))
		return {}
	if _file_state(AUTOSAVE_PATH) != file_before:
		_fail("Forced generated opening autosave failure changed autosave bytes.")
		return {}
	if failure_session.flags != flags_before:
		_fail("Forced generated opening autosave failure changed the live retry flags: %s" % JSON.stringify({
			"before": flags_before,
			"after": failure_session.flags,
		}))
		return {}
	if not bool(failure_session.flags.get("generated_overworld_deferred_autosave_pending", false)) \
			or not bool(failure_session.flags.get("generated_overworld_command_briefing_autosave_deferred", false)) \
			or bool(failure_session.flags.get("generated_overworld_initial_autosave_completed", true)):
		_fail("Forced failure did not retain pending/briefing with completion=false: %s" % JSON.stringify(failure_session.flags))
		return {}
	return {
		"ok": true,
		"file_bytes_unchanged": true,
		"live_retry_flags_unchanged": true,
		"pending_retained": true,
		"briefing_defer_retained": true,
		"completion_false": true,
		"transition_intent_retained": true,
	}

func _assert_ordinary_autosave_control() -> Dictionary:
	var ordinary = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	if ordinary == null or ordinary.scenario_id == "":
		_fail("Could not build ordinary authored autosave control session.")
		return {}
	ordinary.flags["ordinary_autosave_breadth_marker"] = {
		"route": "authored_control",
		"values": [1, 2, 3],
	}
	for key in SaveService.TRANSITION_AUTOSAVE_INTENT_FLAGS:
		ordinary.flags[String(key)] = _transition_intent_fixture_value(String(key))
	var source_payload: Dictionary = ordinary.to_dict()
	var result: Dictionary = SaveService.save_runtime_autosave_session(ordinary)
	if not bool(result.get("ok", false)):
		_fail("Ordinary authored autosave control failed: %s" % JSON.stringify(result))
		return {}
	var summary: Dictionary = result.get("summary", {}) if result.get("summary", {}) is Dictionary else {}
	if summary.is_empty() or not SaveService.can_load_summary(summary):
		_fail("Ordinary autosave lost its normal loadable summary: %s" % JSON.stringify(summary))
		return {}
	var raw_payload := _read_raw_payload(AUTOSAVE_PATH)
	var raw_flags: Dictionary = raw_payload.get("flags", {}) if raw_payload.get("flags", {}) is Dictionary else {}
	if int(raw_payload.get("save_version", 0)) != 9 or SessionState.SAVE_VERSION != 9:
		_fail("Ordinary autosave changed the save-version contract: %s" % raw_payload.get("save_version", null))
		return {}
	var source_marker_value: Variant = source_payload.get("flags", {}).get("ordinary_autosave_breadth_marker", {})
	var source_marker: Dictionary = source_marker_value if source_marker_value is Dictionary else {}
	if raw_flags.get("ordinary_autosave_breadth_marker", {}) != _canonical_json_dictionary(source_marker):
		_fail("Ordinary autosave dropped its nested payload breadth marker: %s" % JSON.stringify(raw_flags))
		return {}
	if raw_flags.has("generated_overworld_deferred_autosave_pending") \
			or raw_flags.has("generated_overworld_command_briefing_autosave_deferred") \
			or raw_flags.has("generated_overworld_initial_autosave_completed"):
		_fail("Ordinary autosave acquired generated-opening lifecycle flags: %s" % JSON.stringify(raw_flags))
		return {}
	if not _assert_transition_intent_absent(raw_flags, "ordinary raw payload") \
			or not _assert_transition_intent_absent(ordinary.flags, "ordinary live session"):
		return {}
	if not _assert_payload_breadth(raw_payload, source_payload, "ordinary autosave"):
		return {}
	var restored = SaveService.restore_autosave_session()
	if restored == null:
		_fail("Ordinary autosave could not be restored from its loadable summary.")
		return {}
	var restored_marker_value: Variant = restored.flags.get("ordinary_autosave_breadth_marker", {})
	var restored_marker: Dictionary = restored_marker_value if restored_marker_value is Dictionary else {}
	if restored.session_id != ordinary.session_id \
			or restored.scenario_id != ordinary.scenario_id \
			or _canonical_json_dictionary(restored_marker) != raw_flags.get("ordinary_autosave_breadth_marker", {}):
		_fail("Ordinary autosave did not restore its canonical payload breadth: %s" % JSON.stringify({
			"expected_session_id": ordinary.session_id,
			"restored_session_id": restored.session_id,
			"expected_scenario_id": ordinary.scenario_id,
			"restored_scenario_id": restored.scenario_id,
			"marker_matches": _canonical_json_dictionary(restored_marker) == raw_flags.get("ordinary_autosave_breadth_marker", {}),
		}))
		return {}
	return {
		"ok": true,
		"loadable_summary": true,
		"restored": true,
		"save_version": int(raw_payload.get("save_version", 0)),
		"payload_breadth_preserved": true,
		"transition_intent_absent": true,
		"generated_lifecycle_flags_absent": true,
	}

func _assert_transition_intent_absent(flags: Dictionary, context: String) -> bool:
	for key in SaveService.TRANSITION_AUTOSAVE_INTENT_FLAGS:
		if flags.has(String(key)):
			_fail("%s retained transition autosave intent flag %s: %s" % [context, key, JSON.stringify(flags)])
			return false
	return true

func _assert_payload_breadth(raw_payload: Dictionary, source_payload: Dictionary, context: String) -> bool:
	for key in CANONICAL_SESSION_KEYS:
		if not raw_payload.has(key):
			_fail("%s dropped canonical payload key %s." % [context, key])
			return false
	var source_overworld: Dictionary = source_payload.get("overworld", {}) if source_payload.get("overworld", {}) is Dictionary else {}
	var raw_overworld: Dictionary = raw_payload.get("overworld", {}) if raw_payload.get("overworld", {}) is Dictionary else {}
	for key in source_overworld.keys():
		if not raw_overworld.has(key):
			_fail("%s dropped overworld payload key %s." % [context, key])
			return false
	return true

func _transition_intent_fixture_value(key: String) -> Variant:
	match key:
		"runtime_autosave_dirty", "runtime_autosave_pending_intent":
			return true
		"runtime_autosave_pending_unix":
			return 10184
		"runtime_autosave_pending_game_state":
			return "overworld"
		"runtime_autosave_pending_route":
			return "generated_opening_test"
		_:
			return "forced_failure_retry"

func _read_raw_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _canonical_json_dictionary(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}

func _different_dictionary_keys(left: Dictionary, right: Dictionary) -> Array[String]:
	var different: Array[String] = []
	var keys := left.keys()
	for key in right.keys():
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		if not left.has(key) or not right.has(key) or left.get(key) != right.get(key):
			different.append(String(key))
	different.sort()
	return different

func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}

func _capture_original_state() -> void:
	_original_autosave_state = _file_state(AUTOSAVE_PATH)
	_original_active_payload = SessionState.ensure_active_session().to_dict()
	_original_failure_env = OS.get_environment(GENERATED_OPENING_SAVE_FAILURE_ENV)
	OS.unset_environment(GENERATED_OPENING_SAVE_FAILURE_ENV)

func _restore_failure_env() -> void:
	if _original_failure_env == "":
		OS.unset_environment(GENERATED_OPENING_SAVE_FAILURE_ENV)
	else:
		OS.set_environment(GENERATED_OPENING_SAVE_FAILURE_ENV, _original_failure_env)

func _cleanup() -> void:
	if _cleanup_done:
		return
	_cleanup_done = true
	_restore_failure_env()
	if bool(_original_autosave_state.get("exists", false)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveService.SAVE_DIR))
		var file := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_original_autosave_state.get("bytes", PackedByteArray()))
			file.close()
	elif FileAccess.file_exists(AUTOSAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTOSAVE_PATH))
	var original_session := SessionStateStoreScript.new_session_data()
	original_session.from_dict(_original_active_payload)
	SessionState.set_active_session(original_session)
	ContentService.clear_generated_scenario_drafts()
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.queue_free()

func _assert_hooks(shell: Node) -> bool:
	for method_name in [
		"validation_open_skirmish_stage",
		"validation_set_generated_seed",
		"validation_select_generated_size_class",
		"validation_select_generated_water_mode",
		"validation_set_generated_underground",
		"validation_start_generated_skirmish_staged",
	]:
		if not shell.has_method(method_name):
			_fail("Main menu missing generated route validation hook %s." % method_name)
			return false
	return true

func _assert_profile_steps(profile: Dictionary) -> bool:
	var names := []
	for step_value in profile.get("steps", []):
		if step_value is Dictionary:
			names.append(String(step_value.get("name", "")))
	for required_name in [
		"go_to_overworld_enter",
		"go_to_overworld_autosave_deferred",
		"go_to_overworld_scene_change_skipped_for_validation",
		"overworld_ready_enter",
		"overworld_refresh_set_map_state_done",
		"overworld_deferred_autosave_done",
	]:
		if not names.has(required_name):
			_fail("Post-open route profile missed %s: %s" % [required_name, JSON.stringify(profile)])
			return false
	return true

func _assert_generated_overworld(session) -> bool:
	if session == null:
		_fail("Generated route left no active session.")
		return false
	if not bool(session.flags.get("generated_random_map", false)):
		_fail("Generated route did not preserve generated map flag: %s" % JSON.stringify(session.flags))
		return false
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != 36 or int(map_size.get("height", 0)) != 36:
		_fail("Generated route did not preserve Small 36x36 map size: %s" % JSON.stringify(map_size))
		return false
	if String(session.scenario_status) != "in_progress" or String(session.game_state) != "overworld":
		_fail("Generated route did not remain playable/in progress: %s/%s" % [session.scenario_status, session.game_state])
		return false
	return true

func _profile_step_elapsed(profile: Dictionary, step_name: String) -> int:
	for step_value in profile.get("steps", []):
		if not (step_value is Dictionary):
			continue
		var step: Dictionary = step_value
		if String(step.get("name", "")) == step_name:
			return int(step.get("elapsed_ms", -1))
	return -1

func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
