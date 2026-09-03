extends Node

const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleReportScene = preload("res://scenes/battle/BattleReportShell.tscn")

const REPORT_ID := "POST_BATTLE_REPORT_RUNTIME_REPORT"
const SCENARIO_ID := "river-pass"
const ENCOUNTER_PLACEMENT_ID := "river_pass_hollow_mire"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const OUTCOME_FAMILIES := ["victory", "defeat", "hero_defeat", "town_lost", "retreat", "surrender", "enemy_retreat", "enemy_surrender", "stalemate"]
const CAPTURE_SIZES := [Vector2i(2048, 1079), Vector2i(1280, 720)]

var _original_session
var _original_failure_env := ""
var _original_window_size := Vector2i.ZERO
var _original_autosave_exists := false
var _original_autosave_bytes := PackedByteArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_session = SessionState.active_session
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_window_size = get_window().size
	_original_autosave_exists = FileAccess.file_exists(AUTOSAVE_PATH)
	if _original_autosave_exists:
		_original_autosave_bytes = FileAccess.get_file_as_bytes(AUTOSAVE_PATH)
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_reset_battle_report_state()
	AppRouter.validation_set_battle_report_routing_suppressed(true)

	var casualty_math := _prove_casualty_math()
	if casualty_math.is_empty():
		return
	var outcome_matrix := _prove_outcome_report_matrix()
	if outcome_matrix.is_empty():
		return
	var live_resolution := _prove_live_resolution_and_round_trip()
	if live_resolution.is_empty():
		return
	var layout := await _prove_scene_layout_and_capture()
	if layout.is_empty():
		return
	var routing := _prove_acknowledgement_routing()
	if routing.is_empty():
		return
	var save_failure := _prove_acknowledgement_save_failure()
	if save_failure.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"casualty_math": casualty_math,
		"outcome_matrix": outcome_matrix,
		"live_resolution": live_resolution,
		"layout": layout,
		"routing": routing,
		"save_failure": save_failure,
	})])
	get_tree().quit(0)


func _prove_casualty_math() -> Dictionary:
	var battle := _synthetic_battle()
	var ledger: Dictionary = BattleRulesScript.battle_report_casualty_ledger_bridge(battle)
	var player: Dictionary = ledger.get("player", {})
	var enemy: Dictionary = ledger.get("enemy", {})
	var player_totals: Dictionary = player.get("totals", {})
	var enemy_totals: Dictionary = enemy.get("totals", {})
	if (
		int(player_totals.get("deployed", -1)) != 15
		or int(player_totals.get("surviving", -1)) != 9
		or int(player_totals.get("lost", -1)) != 6
		or int(enemy_totals.get("deployed", -1)) != 11
		or int(enemy_totals.get("surviving", -1)) != 0
		or int(enemy_totals.get("lost", -1)) != 11
		or (player.get("rows", []) as Array).size() != 2
		or (enemy.get("rows", []) as Array).size() != 1
		or not bool((enemy.get("rows", []) as Array)[0].get("destroyed", false))
	):
		return _fail_dictionary("Per-stack casualty ledger was not exact: %s" % JSON.stringify(ledger))
	return {"player": player_totals, "enemy": enemy_totals, "destroyed_company_retained": true}


func _prove_outcome_report_matrix() -> Dictionary:
	var report_ids := []
	for outcome_value in OUTCOME_FAMILIES:
		var outcome := String(outcome_value)
		var session := SessionStateStoreScript.SessionData.new("report-%s" % outcome, SCENARIO_ID, "", 3, {})
		session.battle = _synthetic_battle()
		BattleRulesScript._record_battle_aftermath(session, outcome, "%s resolved." % outcome.capitalize())
		session.battle = {}
		var report := BattleRulesScript.pending_battle_report(session)
		if (
			report.is_empty()
			or String(report.get("outcome", "")) != outcome
			or int(report.get("report_version", 0)) != 1
			or not bool(report.get("pending", false))
			or String(report.get("report_id", "")) == ""
			or report_ids.has(String(report.get("report_id", "")))
		):
			return _fail_dictionary("Outcome %s did not produce one unique pending report: %s" % [outcome, JSON.stringify(report)])
		report_ids.append(String(report.get("report_id", "")))
	return {"families": OUTCOME_FAMILIES.duplicate(), "unique_report_count": report_ids.size()}


func _prove_live_resolution_and_round_trip() -> Dictionary:
	var session = _active_encounter_session()
	if session == null:
		return {}
	var result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	var report := BattleRulesScript.pending_battle_report(session)
	if not bool(result.get("ok", false)) or String(result.get("state", "")) != "victory" or report.is_empty():
		return _fail_dictionary("Live quick resolve did not produce a pending victory report: %s" % JSON.stringify(result))
	var casualties: Dictionary = report.get("casualties", {})
	var player: Dictionary = casualties.get("player", {})
	var enemy: Dictionary = casualties.get("enemy", {})
	if (
		int((player.get("totals", {}) as Dictionary).get("lost", 0)) <= 0
		or int((enemy.get("totals", {}) as Dictionary).get("surviving", -1)) != 0
		or int((enemy.get("totals", {}) as Dictionary).get("lost", 0)) <= 0
	):
		return _fail_dictionary("Live report did not retain both sides' casualties: %s" % JSON.stringify(casualties))
	var save_result: Dictionary = SaveService.save_runtime_autosave_session(session)
	var restored = SaveService.restore_autosave_session()
	if not bool(save_result.get("ok", false)) or restored == null:
		return _fail_dictionary("Pending battle report could not pass through the autosave service: %s" % JSON.stringify(save_result))
	var restored_report := BattleRulesScript.pending_battle_report(restored)
	if restored_report != report:
		return _fail_dictionary("Pending battle report did not survive the save-payload round trip.")
	SessionState.set_active_session(session)
	var entry: Dictionary = AppRouter.go_to_battle_report(true)
	var router_snapshot: Dictionary = AppRouter.validation_battle_report_snapshot()
	if String(entry.get("target", "")) != "battle_report" or String(router_snapshot.get("last_route", {}).get("target", "")) != "battle_report":
		return _fail_dictionary("Live report entry did not route through battle-report authority: %s" % JSON.stringify(router_snapshot))
	return {
		"state": String(result.get("state", "")),
		"report_id": String(report.get("report_id", "")),
		"player_lost": int((player.get("totals", {}) as Dictionary).get("lost", 0)),
		"enemy_lost": int((enemy.get("totals", {}) as Dictionary).get("lost", 0)),
		"autosave_round_trip_exact": true,
	}


func _prove_scene_layout_and_capture() -> Dictionary:
	var shell = BattleReportScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var rows_by_size := {}
	for requested_size in CAPTURE_SIZES:
		get_window().size = requested_size
		await get_tree().process_frame
		await get_tree().process_frame
		var snapshot: Dictionary = shell.validation_snapshot()
		if (
			not (snapshot.get("clipped_controls", []) as Array).is_empty()
			or int(snapshot.get("grid_columns", 0)) != 2
			or int(snapshot.get("player_row_count", 0)) <= 0
			or int(snapshot.get("enemy_row_count", 0)) <= 0
			or String(snapshot.get("continue_accessibility_name", "")) == ""
			or int(snapshot.get("continue_focus_mode", 0)) != Control.FOCUS_ALL
		):
			shell.queue_free()
			return _fail_dictionary("Battle report layout failed at %s: %s" % [requested_size, JSON.stringify(snapshot)])
		var capture_path := ""
		if DisplayServer.get_name().to_lower() != "headless":
			capture_path = _capture_path(requested_size)
			var capture_image := get_viewport().get_texture().get_image()
			if capture_image == null:
				shell.queue_free()
				return _fail_dictionary("Renderer did not provide a report capture at %s." % requested_size)
			var capture_error := capture_image.save_png(capture_path)
			if capture_error != OK:
				shell.queue_free()
				return _fail_dictionary("Could not save report capture %s (error %d)." % [capture_path, capture_error])
		rows_by_size["%dx%d" % [requested_size.x, requested_size.y]] = {
			"grid_columns": int(snapshot.get("grid_columns", 0)),
			"clipped_controls": snapshot.get("clipped_controls", []),
			"capture": capture_path,
		}
	get_window().size = Vector2i(960, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.validation_apply_layout_width(960.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var compact: Dictionary = shell.validation_snapshot()
	if not bool(compact.get("compact_layout", false)) or int(compact.get("grid_columns", 0)) != 1:
		shell.queue_free()
		return _fail_dictionary("Compact report did not stack casualty cards: %s" % JSON.stringify(compact))
	shell.queue_free()
	await get_tree().process_frame
	return {"sizes": rows_by_size, "compact_960x720_columns": 1, "initial_focus": true}


func _prove_acknowledgement_routing() -> Dictionary:
	var continuing = _resolved_report_session("continuing", "in_progress")
	continuing = SessionState.set_active_session(continuing)
	AppRouter.validation_reset_battle_report_state()
	AppRouter.validation_set_battle_report_routing_suppressed(true)
	var continuing_id := String(BattleRulesScript.pending_battle_report(continuing).get("report_id", ""))
	var continuing_result: Dictionary = AppRouter.complete_battle_report(true)
	if (
		not bool(continuing_result.get("ok", false))
		or String(continuing_result.get("target", "")) != "overworld"
		or not BattleRulesScript.pending_battle_report(continuing).is_empty()
		or String(continuing.flags.get("last_battle_report_acknowledged_id", "")) != continuing_id
	):
		return _fail_dictionary("Continuing report did not acknowledge to Overworld: %s" % JSON.stringify({"result": continuing_result, "pending": BattleRulesScript.pending_battle_report(continuing), "expected_id": continuing_id, "acknowledged_id": continuing.flags.get("last_battle_report_acknowledged_id", "")}))

	var terminal = _resolved_report_session("terminal", "defeat")
	terminal = SessionState.set_active_session(terminal)
	AppRouter.validation_reset_battle_report_state()
	AppRouter.validation_set_battle_report_routing_suppressed(true)
	var terminal_result: Dictionary = AppRouter.complete_battle_report(true)
	if (
		not bool(terminal_result.get("ok", false))
		or String(terminal_result.get("target", "")) != "scenario_outcome"
		or terminal.game_state != "outcome"
		or not BattleRulesScript.pending_battle_report(terminal).is_empty()
	):
		return _fail_dictionary("Terminal report did not acknowledge to Scenario Outcome: %s" % JSON.stringify(terminal_result))
	return {"continuing_target": "overworld", "terminal_target": "scenario_outcome", "acknowledged_once": true}


func _prove_acknowledgement_save_failure() -> Dictionary:
	var session = _resolved_report_session("save-failure", "in_progress")
	session = SessionState.set_active_session(session)
	AppRouter.validation_reset_battle_report_state()
	AppRouter.validation_set_battle_report_routing_suppressed(true)
	var report_before := BattleRulesScript.pending_battle_report(session)
	OS.set_environment(FAILURE_ENV, "precommit")
	var result: Dictionary = AppRouter.complete_battle_report(false)
	OS.unset_environment(FAILURE_ENV)
	var report_after := BattleRulesScript.pending_battle_report(session)
	if (
		bool(result.get("ok", true))
		or String(result.get("reason", "")) != "autosave_failed"
		or report_after != report_before
		or not bool(report_after.get("pending", false))
	):
		return _fail_dictionary("Failed acknowledgement save did not retain the pending report: %s" % JSON.stringify(result))
	return {"reason": "autosave_failed", "pending_retained": true, "retry_available": true}


func _active_encounter_session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == ENCOUNTER_PLACEMENT_ID:
			session.battle = BattleRulesScript.create_battle_payload(session, value)
			session.game_state = "battle"
			session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
			return session
	return _fail_null("Authored encounter %s is missing." % ENCOUNTER_PLACEMENT_ID)


func _resolved_report_session(suffix: String, scenario_status: String):
	var session := SessionStateStoreScript.SessionData.new("battle-report-%s" % suffix, SCENARIO_ID, "", 4, {})
	session.battle = _synthetic_battle()
	BattleRulesScript._record_battle_aftermath(session, "defeat" if scenario_status != "in_progress" else "victory", "The battle is resolved.")
	session.battle = {}
	session.scenario_status = scenario_status
	session.game_state = "outcome" if scenario_status != "in_progress" else "overworld"
	return session


func _synthetic_battle() -> Dictionary:
	return {
		"encounter_id": "encounter_report_fixture",
		"encounter_name": "Report Fixture",
		"resolved_key": "report_fixture",
		"terrain": "grass",
		"round": 4,
		"enemy_army_name": "Ashen Test Host",
		"player_commander_state": {"name": "Captain Ledger"},
		"enemy_hero": {"name": "Marshal Tally"},
		"stacks": [
			{"battle_id": "p1", "side": "player", "unit_id": "unit_river_guard", "name": "River Guard", "tier": 1, "base_count": 10, "unit_hp": 10, "total_health": 61},
			{"battle_id": "p2", "side": "player", "unit_id": "unit_beacon_archer", "name": "Beacon Archers", "tier": 2, "base_count": 5, "unit_hp": 8, "total_health": 16},
			{"battle_id": "e1", "side": "enemy", "unit_id": "unit_mireling", "name": "Mirelings", "tier": 1, "base_count": 11, "unit_hp": 6, "total_health": 0},
		],
	}


func _capture_path(size: Vector2i) -> String:
	var relative_dir := ".artifacts/post_battle_report_10224"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://%s" % relative_dir))
	return ProjectSettings.globalize_path("res://%s/battle_report_%dx%d.png" % [relative_dir, size.x, size.y])


func _cleanup() -> void:
	AppRouter.validation_set_battle_report_routing_suppressed(false)
	if _original_failure_env == "":
		OS.unset_environment(FAILURE_ENV)
	else:
		OS.set_environment(FAILURE_ENV, _original_failure_env)
	if _original_window_size != Vector2i.ZERO:
		get_window().size = _original_window_size
	var autosave_absolute := ProjectSettings.globalize_path(AUTOSAVE_PATH)
	if _original_autosave_exists:
		var autosave_file := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
		if autosave_file != null:
			autosave_file.store_buffer(_original_autosave_bytes)
			autosave_file.close()
	elif FileAccess.file_exists(AUTOSAVE_PATH):
		DirAccess.remove_absolute(autosave_absolute)
	SessionState.active_session = _original_session


func _fail_dictionary(message: String) -> Dictionary:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
	return {}


func _fail_null(message: String):
	_fail_dictionary(message)
	return null
