extends Node

const REPORT_ID := "MANUAL_SAVE_OVERWRITE_REGRESSION"
const CAPTURE_DIR := "res://.artifacts/manual_save_overwrite_regression"

var _original_file_states := {}
var _original_active_session = null
var _original_campaign_profile := {}
var _original_settings := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_file_states = _capture_file_states(_tracked_paths())
	_original_active_session = SessionState.active_session
	_original_campaign_profile = CampaignProgression.ensure_profile().duplicate(true)
	_original_settings = SettingsService.settings.duplicate(true)

	var protected_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	protected_fixture.day = 5
	if SaveService.save_manual_session(protected_fixture.to_dict(), 1) == "":
		_fail("Could not seed Manual Slot 1.")
		return
	if SaveService.save_manual_session(protected_fixture.to_dict(), 3) == "":
		_fail("Could not seed Manual Slot 3.")
		return
	if SaveService.save_autosave_session(protected_fixture.to_dict()) == "":
		_fail("Could not seed autosave.")
		return
	var protected_states := _capture_file_states([
		_manual_slot_path(1),
		_manual_slot_path(3),
		_autosave_path(),
		_progression_path(),
		String(SettingsService.SETTINGS_FILE),
	])
	var campaign_before := CampaignProgression.ensure_profile().duplicate(true)
	var settings_before := SettingsService.settings.duplicate(true)
	var slot1_before_invalid := _file_state(_manual_slot_path(1))
	var active_for_invalid = SessionState.set_active_session(protected_fixture)
	var invalid_action := SaveService.build_manual_save_action(active_for_invalid, 99)
	var invalid_result := AppRouter.save_active_session_to_manual_slot(99)
	if not bool(invalid_action.get("disabled", false)) or bool(invalid_result.get("ok", true)) or _file_state(_manual_slot_path(1)) != slot1_before_invalid:
		_fail("Invalid manual slot 99 was not rejected without changing Manual Slot 1.")
		return

	var route_specs := [
		{"id": "overworld", "scene": "res://scenes/overworld/OverworldShell.tscn", "day": 11},
		{"id": "town", "scene": "res://scenes/town/TownShell.tscn", "day": 12},
		{"id": "battle", "scene": "res://scenes/battle/BattleShell.tscn", "day": 13},
		{"id": "outcome", "scene": "res://scenes/results/ScenarioOutcomeShell.tscn", "day": 14},
	]
	for route_value in route_specs:
		var route: Dictionary = route_value
		if not await _exercise_route(route, protected_states, campaign_before, settings_before):
			return

	if not await _exercise_empty_slot(protected_states, campaign_before, settings_before):
		return
	if not await _exercise_corrupt_slot(protected_states, campaign_before, settings_before):
		return

	_restore_original_state()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"confirmed_routes": ["overworld", "town", "battle", "outcome"],
		"empty_slot_direct_save": true,
		"occupied_slot_confirmation": true,
		"corrupt_slot_confirmation": true,
		"cancel_preserved_exact_bytes": true,
		"safe_cancel_focus": "Keep Save",
		"joypad_b_cancel_exact": true,
		"escape_cancel_exact": true,
		"origin_focus_restored": true,
		"confirm_exactly_once": true,
		"pending_slot_binding_preserved": true,
		"invalid_slot_rejected": true,
		"unrelated_manual_slots_preserved": 2,
		"autosave_preserved": true,
		"campaign_progression_preserved": true,
		"device_settings_preserved": true,
		"active_session_preserved": true,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _exercise_route(
	route: Dictionary,
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var old_fixture = ScenarioFactory.create_session("river-pass", "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	old_fixture.day = 3
	if SaveService.save_manual_session(old_fixture.to_dict(), 2) == "":
		return _fail_bool("Could not seed occupied Manual Slot 2 for %s." % String(route.get("id", "route")))
	var slot2_before := _file_state(_manual_slot_path(2))

	var session = _session_for_route(String(route.get("id", "")), int(route.get("day", 1)))
	if session == null:
		return _fail_bool("Could not create %s route fixture." % String(route.get("id", "route")))
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var shell = load(String(route.get("scene", ""))).instantiate()
	add_child(shell)
	await _settle()
	var active_payload: Dictionary = session.to_dict()
	var origin_button: Button = shell.get_node("%Save")
	var dialog: ConfirmationDialog = shell.get_node("ManualSaveOverwriteDialog")
	origin_button.grab_focus()
	await get_tree().process_frame

	var request: Dictionary = shell.call("validation_request_manual_save")
	await _settle()
	var request_text := "%s\n%s" % [String(request.get("title", "")), String(request.get("text", ""))]
	if not bool(request.get("visible", false)) or int(request.get("pending_slot", 0)) != 2:
		return _fail_shell(shell, "%s did not require Manual Slot 2 confirmation: %s." % [route.get("id", "route"), JSON.stringify(request)])
	for token in ["Manual Slot 2", "Day 3", "Day %d" % int(route.get("day", 1)), "Other manual saves", "autosave"]:
		if not request_text.contains(token):
			return _fail_shell(shell, "%s overwrite confirmation omitted %s: %s." % [route.get("id", "route"), token, request_text])
	if _file_state(_manual_slot_path(2)) != slot2_before:
		return _fail_shell(shell, "%s confirmation request changed Manual Slot 2 before approval." % route.get("id", "route"))
	if not _safe_dialog_ready(dialog, "Keep Save"):
		return _fail_shell(shell, "%s overwrite confirmation did not focus its compact Keep Save action." % route.get("id", "route"))

	if String(route.get("id", "")) == "overworld":
		await _capture("overwrite_confirmation")
		await _press_joypad_button(JOY_BUTTON_B)
		if dialog.visible or get_viewport().gui_get_focus_owner() != origin_button \
				or _file_state(_manual_slot_path(2)) != slot2_before \
				or not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
			return _fail_shell(shell, "Joypad B did not cancel overwrite exactly and restore Save focus.")
		request = shell.call("validation_request_manual_save")
		await _settle()
		if not bool(request.get("visible", false)) or not _safe_dialog_ready(dialog, "Keep Save"):
			return _fail_shell(shell, "Overwrite confirmation did not reopen safely after joypad cancellation.")
		await _press_key(KEY_ESCAPE)
		if dialog.visible or get_viewport().gui_get_focus_owner() != origin_button \
				or _file_state(_manual_slot_path(2)) != slot2_before \
				or not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
			return _fail_shell(shell, "Escape did not cancel overwrite exactly and restore Save focus.")
		request = shell.call("validation_request_manual_save")
		await _settle()
		if not bool(request.get("visible", false)) or not _safe_dialog_ready(dialog, "Keep Save"):
			return _fail_shell(shell, "Overwrite confirmation did not reopen safely for confirmation.")

	if not bool(shell.call("validation_select_save_slot", 3)):
		return _fail_shell(shell, "%s could not change visible selection while confirmation was pending." % route.get("id", "route"))
	var slot3_before := _file_state(_manual_slot_path(3))
	var result: Dictionary = shell.call("validation_confirm_manual_save_overwrite")
	var dialog_after_confirm: Dictionary = dialog.validation_snapshot()
	var saved_summary := SaveService.inspect_manual_slot(2)
	if int(result.get("pending_slot", 0)) != 2 or not SaveService.can_load_summary(saved_summary) or int(saved_summary.get("day", 0)) != int(route.get("day", 0)):
		return _fail_shell(shell, "%s confirmation did not write the originally bound Manual Slot 2: %s." % [route.get("id", "route"), JSON.stringify(result)])
	if _file_state(_manual_slot_path(3)) != slot3_before:
		return _fail_shell(shell, "%s redirected overwrite into the later-selected Manual Slot 3." % route.get("id", "route"))
	if int(dialog_after_confirm.get("confirm_count", 1)) != 1:
		return _fail_shell(shell, "%s overwrite confirmation did not execute exactly once: %s." % [route.get("id", "route"), JSON.stringify(dialog_after_confirm)])
	if not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
		return false
	shell.queue_free()
	await _settle()
	return true

func _exercise_empty_slot(
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_manual_slot_path(2)))
	var session = _session_for_route("overworld", 20)
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var active_payload: Dictionary = session.to_dict()
	var request: Dictionary = shell.call("validation_request_manual_save")
	var summary := SaveService.inspect_manual_slot(2)
	if bool(request.get("visible", false)) or int(request.get("pending_slot", 0)) != 0 or not SaveService.can_load_summary(summary) or int(summary.get("day", 0)) != 20:
		return _fail_shell(shell, "Empty Manual Slot 2 did not save immediately: %s." % JSON.stringify(request))
	if not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
		return false
	shell.queue_free()
	await _settle()
	return true

func _exercise_corrupt_slot(
	protected_states: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary
) -> bool:
	var corrupt_file := FileAccess.open(_manual_slot_path(2), FileAccess.WRITE)
	if corrupt_file == null:
		return _fail_bool("Could not create corrupt Manual Slot 2 fixture.")
	corrupt_file.store_string(JSON.stringify({"not_a_session": true}))
	corrupt_file.close()
	var corrupt_before := _file_state(_manual_slot_path(2))
	var session = _session_for_route("overworld", 21)
	session = SessionState.set_active_session(session)
	SaveService.set_selected_manual_slot(2)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _settle()
	var active_payload: Dictionary = session.to_dict()
	var request: Dictionary = shell.call("validation_request_manual_save")
	if not bool(request.get("visible", false)) or not String(request.get("text", "")).contains("Unreadable expedition save"):
		return _fail_shell(shell, "Corrupt Manual Slot 2 did not require an unreadable-save confirmation: %s." % JSON.stringify(request))
	shell.call("validation_cancel_manual_save_overwrite")
	if _file_state(_manual_slot_path(2)) != corrupt_before:
		return _fail_shell(shell, "Canceling corrupt-slot overwrite changed its exact bytes.")
	if not _require_preserved_state(protected_states, active_payload, campaign_before, settings_before, _manual_slot_path(2)):
		return false
	shell.queue_free()
	await _settle()
	return true

func _session_for_route(route_id: String, day: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	match route_id:
		"town":
			var town := _first_player_town(session)
			if town.is_empty():
				return null
			_move_active_hero_to_town(session, town)
			session.game_state = "town"
		"battle":
			var encounter := _first_encounter(session)
			if encounter.is_empty():
				return null
			session.battle = BattleRules.create_battle_payload(session, encounter)
			session.game_state = "battle"
		"outcome":
			session.scenario_status = "victory"
			session.scenario_summary = "Overwrite confirmation outcome fixture."
			session.game_state = "outcome"
	return session

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["position"] = position.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _require_preserved_state(
	protected_states: Dictionary,
	active_payload: Dictionary,
	campaign_before: Dictionary,
	settings_before: Dictionary,
	excluded_path: String
) -> bool:
	for path_value in protected_states.keys():
		var path := String(path_value)
		if path == excluded_path:
			continue
		if _file_state(path) != protected_states.get(path, {}):
			return _fail_bool("Manual overwrite changed protected file %s." % path)
	if SessionState.active_session == null or SessionState.active_session.to_dict() != active_payload:
		return _fail_bool("Manual overwrite changed the active in-memory expedition.")
	if CampaignProgression.ensure_profile() != campaign_before:
		return _fail_bool("Manual overwrite changed campaign progression.")
	if SettingsService.settings != settings_before:
		return _fail_bool("Manual overwrite changed device settings.")
	if SessionState.SAVE_VERSION != 9:
		return _fail_bool("Manual overwrite changed the save-version contract.")
	return true

func _tracked_paths() -> Array:
	return [
		_autosave_path(),
		_manual_slot_path(1),
		_manual_slot_path(2),
		_manual_slot_path(3),
		_progression_path(),
		String(SettingsService.SETTINGS_FILE),
	]

func _autosave_path() -> String:
	return "%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]

func _manual_slot_path(slot: int) -> String:
	return "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, slot]

func _progression_path() -> String:
	return "%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE]

func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		states[path] = _file_state(path)
	return states

func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}

func _restore_original_state() -> void:
	for path_value in _original_file_states.keys():
		var path := String(path_value)
		var state: Dictionary = _original_file_states.get(path, {})
		if bool(state.get("exists", false)):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(state.get("bytes", PackedByteArray()))
				file.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SessionState.active_session = _original_active_session
	CampaignProgression.profile = _original_campaign_profile.duplicate(true)
	SettingsService.settings = _original_settings.duplicate(true)

func _capture(stem: String) -> void:
	if OS.get_environment("MANUAL_SAVE_OVERWRITE_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%dx%d.png" % [absolute_dir, stem, image.get_width(), image.get_height()])

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _safe_dialog_ready(dialog: ConfirmationDialog, expected_cancel_text: String) -> bool:
	if dialog == null or not dialog.visible or dialog.get_cancel_button().text != expected_cancel_text:
		return false
	var dialog_viewport := dialog.get_cancel_button().get_viewport()
	if dialog_viewport == null or dialog_viewport.gui_get_focus_owner() != dialog.get_cancel_button():
		return false
	return dialog.size.x <= 960 and dialog.size.y <= 540

func _press_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.physical_keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()

func _press_joypad_button(button_index: int) -> void:
	var pressed := InputEventJoypadButton.new()
	pressed.button_index = button_index
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventJoypadButton.new()
	released.button_index = button_index
	released.pressed = false
	Input.parse_input_event(released)
	await _settle()

func _fail_shell(shell, message: String) -> bool:
	if shell != null:
		shell.queue_free()
	return _fail_bool(message)

func _fail_bool(message: String) -> bool:
	_fail(message)
	return false

func _fail(message: String) -> void:
	_restore_original_state()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
