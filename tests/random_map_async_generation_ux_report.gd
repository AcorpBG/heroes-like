extends Node

const REPORT_ID := "RANDOM_MAP_ASYNC_GENERATION_UX_REPORT"

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
	if not bool(shell.call("validation_set_generated_seed", "async-generation-ux-10184")):
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

	var pre_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if bool(pre_snapshot.get("generation_progress_visible", true)):
		_fail("Progress bar should be hidden before generated-map launch: %s" % JSON.stringify(pre_snapshot))
		return
	if not bool(pre_snapshot.get("start_enabled", false)):
		_fail("Generated launch should be enabled before staged launch: %s" % JSON.stringify(pre_snapshot))
		return

	var result: Dictionary = await shell.validation_start_generated_skirmish_staged()
	if not bool(result.get("started", false)):
		_fail("Staged generated launch did not start a session: %s" % JSON.stringify(result))
		return
	if int(result.get("yield_count", 0)) < 5:
		_fail("Staged generated launch did not yield frames around major stages: %s" % JSON.stringify(result))
		return
	if not _assert_stage_snapshots(result):
		return
	if not _assert_active_generated_session(result):
		return

	var post_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	if bool(post_snapshot.get("generation_in_progress", true)):
		_fail("Generated launch progress state did not clear after validation launch: %s" % JSON.stringify(post_snapshot))
		return

	ContentService.clear_generated_scenario_drafts()
	var result_snapshots: Array = result.get("snapshots", []) if result.get("snapshots", []) is Array else []
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": String(result.get("active_scenario_id", "")),
		"yield_count": int(result.get("yield_count", 0)),
		"stage_count": result_snapshots.size(),
		"final_stage": result.get("stage", {}),
		"materialized_size": SessionState.ensure_active_session().overworld.get("map_size", {}),
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
		"validation_generated_random_map_snapshot",
	]:
		if not shell.has_method(method_name):
			_fail("Main menu missing async generated random-map validation hook %s." % method_name)
			return false
	return true

func _assert_stage_snapshots(result: Dictionary) -> bool:
	var snapshots: Array = result.get("snapshots", []) if result.get("snapshots", []) is Array else []
	if snapshots.size() < 5:
		_fail("Staged generated launch did not record enough stage snapshots: %s" % JSON.stringify(result))
		return false
	var expected_stages := [
		"Preparing generated map",
		"Validating seed and template",
		"Generation validation complete",
		"Materializing playable session",
		"Opening generated map",
	]
	var last_progress := -1
	for index in range(expected_stages.size()):
		var snapshot: Dictionary = snapshots[index] if snapshots[index] is Dictionary else {}
		if String(snapshot.get("stage", "")) != expected_stages[index]:
			_fail("Generated launch stage %d mismatch: %s" % [index, JSON.stringify(snapshots)])
			return false
		if not bool(snapshot.get("active", false)):
			_fail("Generated launch stage was not marked active: %s" % JSON.stringify(snapshot))
			return false
		var progress := int(snapshot.get("progress", -1))
		if progress <= last_progress:
			_fail("Generated launch progress did not advance monotonically: %s" % JSON.stringify(snapshots))
			return false
		last_progress = progress
		if int(snapshot.get("yield_count_after_stage", 0)) < index + 1:
			_fail("Generated launch did not yield after stage %d: %s" % [index, JSON.stringify(snapshot)])
			return false
	return true

func _assert_active_generated_session(result: Dictionary) -> bool:
	var session = SessionState.ensure_active_session()
	if session.scenario_id == "" or session.scenario_id != String(result.get("active_scenario_id", "")):
		_fail("Active generated session id mismatch: %s / %s" % [session.scenario_id, JSON.stringify(result)])
		return false
	if session.launch_mode != SessionState.LAUNCH_MODE_SKIRMISH or not bool(session.flags.get("generated_random_map", false)):
		_fail("Active session is not a generated skirmish: %s" % JSON.stringify(session.to_dict()))
		return false
	var map_size: Dictionary = session.overworld.get("map_size", {}) if session.overworld.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != 36 or int(map_size.get("height", 0)) != 36:
		_fail("Staged launch did not preserve Small 36x36 materialization: %s" % JSON.stringify(map_size))
		return false
	var provenance: Dictionary = session.flags.get("generated_random_map_provenance", {}) if session.flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	var config: Dictionary = provenance.get("generator_config", {}) if provenance.get("generator_config", {}) is Dictionary else {}
	var size: Dictionary = config.get("size", {}) if config.get("size", {}) is Dictionary else {}
	var runtime_policy: Dictionary = size.get("runtime_size_policy", {}) if size.get("runtime_size_policy", {}) is Dictionary else {}
	if String(size.get("size_class_id", "")) != "homm3_small" or bool(runtime_policy.get("hidden_downscale", true)):
		_fail("Staged launch lost Small/no-downscale provenance: %s" % JSON.stringify(provenance))
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s FAILED: %s" % [REPORT_ID, message])
	get_tree().quit(1)
