extends Node

const REPORT_ID := "RANDOM_MAP_POST_OPEN_TAIL_TIMING_REPORT"
const FIRST_VISIBLE_BUDGET_MS := 2500
const TAIL_WITH_DEFERRED_AUTOSAVE_BUDGET_MS := 2500

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
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

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"route_elapsed_ms": route_elapsed,
		"first_visible_ms": first_visible_ms,
		"tail_with_deferred_autosave_ms": int(profile.get("total_ms", 0)),
		"profile": profile,
		"save_profile": save_profile,
		"map_size": session.overworld.get("map_size", {}),
		"scenario_id": session.scenario_id,
	})])
	get_tree().quit(0)

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
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
