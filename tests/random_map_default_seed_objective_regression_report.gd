extends Node

const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "RANDOM_MAP_DEFAULT_SEED_OBJECTIVE_REGRESSION_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not _assert_hooks(shell):
		return
	shell.call("validation_open_skirmish_stage")
	if not _select_default_small(shell):
		return

	var auto_first: Dictionary = await _launch_blank_seed(shell, "first blank/default Small launch")
	if auto_first.is_empty():
		return
	var auto_second: Dictionary = await _launch_blank_seed(shell, "second blank/default Small launch")
	if auto_second.is_empty():
		return
	if not _assert_auto_seed_variation(auto_first, auto_second):
		return

	var deterministic := _assert_explicit_seed_determinism()
	if deterministic.is_empty():
		return
	var movement := _assert_first_small_move_stays_in_progress()
	if movement.is_empty():
		return

	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"auto_first_seed": String(auto_first.get("normalized_seed", "")),
		"auto_second_seed": String(auto_second.get("normalized_seed", "")),
		"auto_first_signature": _materialized_signature(auto_first),
		"auto_second_signature": _materialized_signature(auto_second),
		"explicit_seed": deterministic.get("seed", ""),
		"explicit_signature": deterministic.get("signature", ""),
		"movement_status": movement.get("scenario_status", ""),
		"movement_message": movement.get("message", ""),
		"objective_ids": movement.get("objective_ids", []),
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
			_fail("Main menu missing generated-map hook %s." % method_name)
			return false
	return true

func _select_default_small(shell: Node) -> bool:
	if not bool(shell.call("validation_set_generated_seed", "")):
		_fail("Seed hook could not leave generated seed blank for auto mode.")
		return false
	if not bool(shell.call("validation_select_generated_size_class", "homm3_small")):
		_fail("Size hook could not select Small.")
		return false
	if not bool(shell.call("validation_select_generated_water_mode", "land")):
		_fail("Water hook could not select land.")
		return false
	if not bool(shell.call("validation_set_generated_underground", false)):
		_fail("Underground hook could not disable underground.")
		return false
	return true

func _launch_blank_seed(shell: Node, label: String) -> Dictionary:
	if not bool(shell.call("validation_set_generated_seed", "")):
		_fail("%s could not reset seed to blank auto mode." % label)
		return {}
	var result: Dictionary = await shell.validation_start_generated_skirmish_staged()
	if not bool(result.get("started", false)):
		_fail("%s did not start: %s" % [label, JSON.stringify(result)])
		return {}
	var setup: Dictionary = result.get("setup", {}) if result.get("setup", {}) is Dictionary else {}
	if String(setup.get("normalized_seed", "")) == "" or String(setup.get("normalized_seed", "")) == "auto on launch":
		_fail("%s did not resolve a concrete effective seed: %s" % [label, JSON.stringify(setup)])
		return {}
	return setup

func _assert_auto_seed_variation(first: Dictionary, second: Dictionary) -> bool:
	var first_seed := String(first.get("normalized_seed", ""))
	var second_seed := String(second.get("normalized_seed", ""))
	if first_seed == second_seed:
		_fail("Blank/default launches reused the same effective seed %s." % first_seed)
		return false
	if _materialized_signature(first) == "" or _materialized_signature(first) == _materialized_signature(second):
		_fail("Blank/default launches did not produce distinct generated topology signatures: %s / %s." % [
			JSON.stringify(first.get("generated_identity", {})),
			JSON.stringify(second.get("generated_identity", {})),
		])
		return false
	return true

func _assert_explicit_seed_determinism() -> Dictionary:
	var seed := "default-seed-objective-regression-fixed-10184"
	var first := ScenarioSelectRulesScript.build_random_map_skirmish_setup(_small_config(seed), "normal")
	var second := ScenarioSelectRulesScript.build_random_map_skirmish_setup(_small_config(seed), "normal")
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
		_fail("Explicit seeded Small setup failed: %s / %s" % [JSON.stringify(first), JSON.stringify(second)])
		return {}
	var first_signature := _materialized_signature(first)
	var second_signature := _materialized_signature(second)
	if String(first.get("normalized_seed", "")) != seed or String(second.get("normalized_seed", "")) != seed:
		_fail("Explicit seed was not preserved as the effective seed.")
		return {}
	if first_signature == "" or first_signature != second_signature:
		_fail("Explicit same seed did not reproduce the same generated topology signature.")
		return {}
	return {"seed": seed, "signature": first_signature}

func _assert_first_small_move_stays_in_progress() -> Dictionary:
	var seed := "default-seed-objective-regression-move-10184"
	var session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session(_small_config(seed), "normal")
	if session == null or session.scenario_id == "":
		_fail("Generated Small session did not start for movement regression.")
		return {}
	OverworldRulesScript.normalize_overworld_state(session)
	var initial_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(initial_result.get("status", "")) != "in_progress":
		_fail("Generated Small objective is already complete before movement: %s" % JSON.stringify(initial_result))
		return {}
	var movement := _first_successful_move(session)
	if movement.is_empty():
		_fail("Generated Small session had no adjacent passable first movement.")
		return {}
	if String(session.scenario_status) != "in_progress":
		_fail("Generated Small first movement completed scenario unexpectedly: %s / %s" % [session.scenario_status, JSON.stringify(movement)])
		return {}
	var objectives := _objective_ids(session)
	if "generated_capture_rival_town" not in objectives:
		_fail("Generated Small scenario did not use the rival-town capture objective: %s" % JSON.stringify(objectives))
		return {}
	return {
		"scenario_status": session.scenario_status,
		"message": String(movement.get("message", "")),
		"objective_ids": objectives,
	}

func _first_successful_move(session: SessionStateStoreScript.SessionData) -> Dictionary:
	for direction in [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
	]:
		var pos := OverworldRulesScript.hero_position(session)
		var nx := int(pos.x + direction.x)
		var ny := int(pos.y + direction.y)
		if OverworldRulesScript.tile_is_blocked(session, nx, ny):
			continue
		var result: Dictionary = OverworldRulesScript.try_move(session, direction.x, direction.y)
		if bool(result.get("ok", false)):
			return result
	return {}

func _small_config(seed: String) -> Dictionary:
	return ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		"border_gate_compact_v1",
		"border_gate_compact_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)

func _materialized_signature(setup: Dictionary) -> String:
	return String(setup.get("generated_identity", {}).get("materialized_map_signature", ""))

func _objective_ids(session: SessionStateStoreScript.SessionData) -> Array:
	var scenario := ContentService.get_scenario(session.scenario_id)
	var objectives: Dictionary = scenario.get("objectives", {}) if scenario.get("objectives", {}) is Dictionary else {}
	var ids := []
	for bucket in ["victory", "defeat"]:
		for objective in objectives.get(bucket, []):
			if objective is Dictionary:
				ids.append(String(objective.get("id", "")))
	return ids

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
