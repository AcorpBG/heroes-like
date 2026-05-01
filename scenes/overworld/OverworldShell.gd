extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

@onready var _shell_panel: PanelContainer = %Shell
@onready var _top_strip_panel: PanelContainer = %TopStrip
@onready var _status_chip_panel: PanelContainer = %StatusChip
@onready var _resource_chip_panel: PanelContainer = %ResourceChip
@onready var _cue_chip_panel: PanelContainer = %CueChip
@onready var _event_panel: PanelContainer = %EventPanel
@onready var _briefing_panel: PanelContainer = %BriefingPanel
@onready var _commitment_panel: PanelContainer = %CommitmentPanel
@onready var _map_panel: PanelContainer = %MapPanel
@onready var _map_frame_panel: PanelContainer = %MapFrame
@onready var _sidebar_shell_panel: PanelContainer = %SidebarShell
@onready var _hero_panel: PanelContainer = %HeroPanel
@onready var _action_panel: PanelContainer = %ActionPanel
@onready var _command_spine: VBoxContainer = %CommandSpine
@onready var _command_panel: PanelContainer = %CommandPanel
@onready var _frontier_panel: PanelContainer = %FrontierPanel
@onready var _context_panel: PanelContainer = %ContextPanel
@onready var _command_band_panel: PanelContainer = %CommandBand
@onready var _orders_panel: PanelContainer = %OrdersPanel
@onready var _system_panel: PanelContainer = %SystemPanel
@onready var _header_label: Label = %Header
@onready var _status_label: Label = %Status
@onready var _resource_label: Label = %Resources
@onready var _map_cue_label: Label = %MapCue
@onready var _event_title_label: Label = %EventTitle
@onready var _event_label: Label = %Event
@onready var _briefing_title_label: Label = %BriefingTitle
@onready var _briefing_label: Label = %Briefing
@onready var _commitment_title_label: Label = %CommitmentTitle
@onready var _commitment_label: Label = %Commitment
@onready var _hero_title_label: Label = %HeroTitle
@onready var _hero_label: Label = %Hero
@onready var _army_label: Label = %Army
@onready var _heroes_label: Label = %Heroes
@onready var _action_title_label: Label = %ActionTitle
@onready var _frontier_indicator_label: Label = %FrontierIndicator
@onready var _command_title_label: Label = %CommandTitle
@onready var _specialty_label: Label = %Specialties
@onready var _spell_label: Label = %Spellbook
@onready var _artifact_label: Label = %Artifacts
@onready var _context_title_label: Label = %ContextTitle
@onready var _frontier_title_label: Label = %FrontierTitle
@onready var _visibility_label: Label = %Visibility
@onready var _objective_label: Label = %Objectives
@onready var _threat_label: Label = %Threats
@onready var _forecast_label: Label = %Forecast
@onready var _orders_title_label: Label = %OrdersTitle
@onready var _objective_brief_label: Label = %ObjectiveBrief
@onready var _primary_action_button: Button = %PrimaryAction
@onready var _map_view = %Map
@onready var _context_label: Label = %Context
@onready var _context_actions: Container = %ContextActions
@onready var _hero_actions: Container = %HeroActions
@onready var _spell_actions: Container = %SpellActions
@onready var _specialty_actions: Container = %SpecialtyActions
@onready var _artifact_actions: Container = %ArtifactActions
@onready var _open_command_button: Button = %OpenCommand
@onready var _open_frontier_button: Button = %OpenFrontier
@onready var _close_command_button: Button = %CloseCommand
@onready var _close_frontier_button: Button = %CloseFrontier
@onready var _end_turn_button: Button = %EndTurn
@onready var _save_status_label: Label = %SaveStatus
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _menu_button: Button = %Menu

const DIRECTIONS := [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]
const RAIL_ACTION_WIDTH := 248.0
const RAIL_LINE_CHARS := 42
const ACTION_FEEDBACK_CHARS := 40
const DEBUG_OVERLAY_TOGGLE_KEY := KEY_F3
const OVERWORLD_PROFILE_LOG_PATH := "user://debug/overworld_profile.jsonl"
const REFRESH_PHASE_MAP_VIEW := "map_view"
const REFRESH_PHASE_ACTION_RAILS := "action_rails"
const REFRESH_PHASE_HERO_ACTIONS := "hero_actions"
const REFRESH_PHASE_CONTEXT_ACTIONS := "context_actions"
const REFRESH_PHASE_CONTEXT_ROUTE := "route_preview"
const REFRESH_PHASE_SPELL_RAILS := "spell_rails"
const REFRESH_PHASE_SPECIALTY_RAILS := "specialty_rails"
const REFRESH_PHASE_ARTIFACT_RAILS := "artifact_rails"
const REFRESH_PHASE_STATUS_SURFACES := "status_surfaces"
const REFRESH_PHASE_SAVE_SURFACE := "save_surface"
const REFRESH_PHASE_GENERATED_SURFACES := "generated_surfaces"
const REFRESH_ALL_PHASES := [
	REFRESH_PHASE_MAP_VIEW,
	REFRESH_PHASE_ACTION_RAILS,
	REFRESH_PHASE_HERO_ACTIONS,
	REFRESH_PHASE_CONTEXT_ACTIONS,
	REFRESH_PHASE_CONTEXT_ROUTE,
	REFRESH_PHASE_SPELL_RAILS,
	REFRESH_PHASE_SPECIALTY_RAILS,
	REFRESH_PHASE_ARTIFACT_RAILS,
	REFRESH_PHASE_STATUS_SURFACES,
	REFRESH_PHASE_SAVE_SURFACE,
	REFRESH_PHASE_GENERATED_SURFACES,
]

var _session: SessionStateStore.SessionData
var _map_data: Array = []
var _map_size := Vector2i(1, 1)
var _selected_tile := Vector2i(-1, -1)
var _hovered_tile := Vector2i(-1, -1)
var _last_message := ""
var _last_enemy_activity_text := ""
var _last_enemy_activity_events: Array = []
var _last_turn_resolution_text := ""
var _last_action_recap: Dictionary = {}
var _last_route_execution: Dictionary = {}
var _briefing_title_text := "Command Briefing"
var _command_briefing_text := ""
var _active_drawer := ""
var _refresh_cache: Dictionary = {}
var _hero_actions_cache: Array = []
var _hero_actions_cache_signature := ""
var _selected_route_state: Dictionary = {}
var _selected_context_actions_cache: Array = []
var _selected_context_actions_cache_signature := ""
var _selected_route_decision_surface_cache: Dictionary = {}
var _selected_route_decision_surface_cache_signature := ""
var _selected_route_destination_actions_cache: Array = []
var _selected_route_destination_actions_cache_signature := ""
var _selected_route_state_generation := 0
var _action_feedback: Dictionary = {}
var _action_feedback_sequence := 0
var _action_feedback_tween: Tween = null
var _field_return_handoff: Dictionary = {}
var _validation_profile: Dictionary = {}
var _validation_force_hover_drawer_sync := false
var _debug_overlay_enabled := false
var _debug_overlay_panel: PanelContainer = null
var _debug_overlay_label: Label = null
var _debug_command_in_progress := false
var _debug_command_context: Dictionary = {}
var _debug_last_command_snapshot: Dictionary = {}
var _profile_log_enabled := false
var _refresh_dirty_phases: Dictionary = {}
var _refresh_request_sequence := 0

func _ready() -> void:
	AppRouter.note_overworld_handoff_step("overworld_ready_enter")
	_apply_visual_theme()
	_build_debug_overlay()
	_profile_log_enabled = _profile_log_env_enabled()
	_map_view.tile_pressed.connect(_on_map_tile_pressed)
	_map_view.tile_hovered.connect(_on_map_tile_hovered)

	_session = SessionState.ensure_active_session()
	if _session.scenario_id == "":
		push_warning("Cannot enter overworld without an active scenario session.")
		AppRouter.note_overworld_handoff_step("overworld_ready_missing_session")
		AppRouter.go_to_main_menu()
		return

	AppRouter.note_overworld_handoff_step("overworld_ready_normalize_start")
	OverworldRules.normalize_overworld_state(_session)
	AppRouter.note_overworld_handoff_step("overworld_ready_normalize_done")
	if _session.scenario_status != "in_progress":
		AppRouter.note_overworld_handoff_step("overworld_ready_outcome_redirect")
		AppRouter.go_to_scenario_outcome()
		return
	AppRouter.note_overworld_handoff_step("overworld_ready_save_picker_start")
	_configure_save_slot_picker(not _generated_initial_open_pending())
	if _generated_initial_open_pending():
		_set_deferred_generated_save_status("Save: preparing generated autosave")
	AppRouter.note_overworld_handoff_step("overworld_ready_save_picker_done")
	var return_notice := String(_session.flags.get("return_notice", ""))
	if return_notice != "":
		_session.flags.erase("return_notice")
	var town_return_handoff := _consume_town_return_handoff()
	if not town_return_handoff.is_empty():
		_field_return_handoff = town_return_handoff
		_last_message = String(town_return_handoff.get("visible_text", "Returned to the field."))
		var recap := _duplicate_dictionary(town_return_handoff.get("post_action_recap", {}))
		_last_action_recap = recap
		_record_action_feedback("town", _last_message, "", recap)
	else:
		_last_message = _battle_return_notice(return_notice)
	if _last_message != "" and _last_message != return_notice and town_return_handoff.is_empty():
		_record_action_feedback("battle", _last_message)
	var command_briefing_text = OverworldRules.consume_command_briefing(_session)
	if command_briefing_text != "":
		_set_command_briefing("First Turn Briefing", command_briefing_text)
		if _generated_initial_open_pending():
			_session.flags["generated_overworld_command_briefing_autosave_deferred"] = true
			AppRouter.note_overworld_handoff_step("overworld_ready_briefing_autosave_deferred")
		else:
			AppRouter.note_overworld_handoff_step("overworld_ready_briefing_autosave_start")
			SaveService.save_runtime_autosave_session(_session)
			AppRouter.note_overworld_handoff_step("overworld_ready_briefing_autosave_done")
	_select_hero_tile()
	AppRouter.note_overworld_handoff_step("overworld_ready_render_state_start")
	_render_state()
	AppRouter.note_overworld_handoff_step("overworld_ready_render_state_done")
	call_deferred("_complete_deferred_generated_overworld_autosave")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			DEBUG_OVERLAY_TOGGLE_KEY:
				_set_debug_overlay_enabled(not _debug_overlay_enabled)
				get_viewport().set_input_as_handled()
			KEY_HOME:
				_focus_camera_on_hero()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _activate_primary_action():
					get_viewport().set_input_as_handled()
			KEY_UP, KEY_W:
				if event.shift_pressed:
					_pan_map(Vector2i(0, -3))
				else:
					_move_north()
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S:
				if event.shift_pressed:
					_pan_map(Vector2i(0, 3))
				else:
					_move_south()
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_A:
				if event.shift_pressed:
					_pan_map(Vector2i(-3, 0))
				else:
					_move_west()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				if event.shift_pressed:
					_pan_map(Vector2i(3, 0))
				else:
					_move_east()
				get_viewport().set_input_as_handled()
			KEY_Q, KEY_KP_7:
				if event.shift_pressed:
					_pan_map(Vector2i(-3, -3))
				else:
					_try_move(-1, -1)
				get_viewport().set_input_as_handled()
			KEY_E, KEY_KP_9:
				if event.shift_pressed:
					_pan_map(Vector2i(3, -3))
				else:
					_try_move(1, -1)
				get_viewport().set_input_as_handled()
			KEY_Z, KEY_KP_1:
				if event.shift_pressed:
					_pan_map(Vector2i(-3, 3))
				else:
					_try_move(-1, 1)
				get_viewport().set_input_as_handled()
			KEY_C, KEY_KP_3:
				if event.shift_pressed:
					_pan_map(Vector2i(3, 3))
				else:
					_try_move(1, 1)
				get_viewport().set_input_as_handled()

func _move_north() -> void:
	_try_move(0, -1)

func _move_south() -> void:
	_try_move(0, 1)

func _move_west() -> void:
	_try_move(-1, 0)

func _move_east() -> void:
	_try_move(1, 0)

func _pan_map(delta: Vector2i) -> bool:
	if _map_view == null or not _map_view.has_method("pan_tiles"):
		return false
	var changed := bool(_map_view.call("pan_tiles", delta))
	if changed:
		_update_map_tooltip()
	return changed

func _focus_camera_on_hero() -> bool:
	if _map_view == null or not _map_view.has_method("focus_on_hero"):
		return false
	var changed := bool(_map_view.call("focus_on_hero"))
	if changed:
		_update_map_tooltip()
	return changed

func _on_end_turn_pressed() -> void:
	var profile_start := _profile_begin("end_turn")
	# Validation anchor retained while the forecast stays informational instead of gating the turn.
	# OverworldRules.consume_command_risk_forecast(_session)
	var result = OverworldRules.end_turn(_session)
	_session.flags["last_action"] = "ended_turn"
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = String(result.get("enemy_activity_summary", ""))
	_last_enemy_activity_events = _duplicate_array(result.get("enemy_activity_events", []))
	_last_turn_resolution_text = String(result.get("turn_resolution_summary", ""))
	_last_action_recap = {}
	_record_action_feedback("turn", _last_turn_resolution_text, _turn_resolution_feedback_fallback())
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _session.scenario_status == "in_progress":
		var save_profile_start := _profile_begin("end_turn_autosave")
		SaveService.save_runtime_autosave_session(_session, not bool(_session.flags.get("generated_random_map", false)))
		_profile_end("end_turn_autosave", save_profile_start, {"save_profile": SaveService.validation_last_runtime_save_profile()})
	if _handle_session_resolution():
		_profile_end("end_turn", profile_start, {"resolved": true})
		return
	_refresh()
	_profile_end("end_turn", profile_start, {"resolved": false})

func _on_save_pressed() -> void:
	var result = AppRouter.save_active_session_to_selected_manual_slot()
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_last_action_recap = {}
	_record_result_feedback("system", result, "Save updated.")
	if _handle_session_resolution():
		return
	_refresh()

func _on_save_slot_selected(index: int) -> void:
	if index < 0 or index >= _save_slot_picker.get_item_count():
		return
	SaveService.set_selected_manual_slot(_save_slot_picker.get_item_id(index))
	_refresh_save_slot_picker()

func _on_menu_pressed() -> void:
	AppRouter.return_to_main_menu_from_active_play()

func _on_primary_action_pressed() -> void:
	_activate_primary_action()

func _on_open_command_pressed() -> void:
	_active_drawer = "" if _active_drawer == "command" else "command"
	_sync_context_drawers()

func _on_open_frontier_pressed() -> void:
	_active_drawer = "" if _active_drawer == "frontier" else "frontier"
	if _active_drawer == "frontier":
		_refresh_frontier_drawer()
	_sync_context_drawers()

func _on_close_drawers_pressed() -> void:
	_active_drawer = ""
	_sync_context_drawers()

func _on_context_action_pressed(action_id: String) -> void:
	var dispatch_started_usec := _debug_phase_begin("context_action_dispatch")
	if action_id == "advance_route":
		_move_toward_selected_tile()
		_debug_phase_end("context_action_dispatch", dispatch_started_usec, {"action_id": action_id})
		return
	if action_id == "march_selected":
		_move_toward_selected_tile()
		_debug_phase_end("context_action_dispatch", dispatch_started_usec, {"action_id": action_id})
		return
	if action_id == "enter_battle":
		_start_encounter()
		_debug_phase_end("context_action_dispatch", dispatch_started_usec, {"action_id": action_id})
		return
	if action_id == "visit_town":
		_visit_selected_town()
		_debug_phase_end("context_action_dispatch", dispatch_started_usec, {"action_id": action_id})
		return

	var result = OverworldRules.perform_context_action(_session, action_id)
	if result.is_empty():
		_debug_phase_end("context_action_dispatch", dispatch_started_usec, {"action_id": action_id, "empty_result": true})
		return
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_record_result_feedback(_feedback_kind_for_context_action(action_id), result, String(action_id).capitalize())
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _handle_session_resolution():
		_debug_phase_end("context_action_dispatch", dispatch_started_usec, {"action_id": action_id, "resolved": true})
		return
	_refresh()
	_debug_phase_end("context_action_dispatch", dispatch_started_usec, {"action_id": action_id, "resolved": false})

func _on_artifact_action_pressed(action_id: String) -> void:
	var result = OverworldRules.perform_artifact_action(_session, action_id)
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_record_result_feedback("artifact", result, "Artifact loadout updated.")
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _handle_session_resolution():
		return
	_refresh()

func _on_specialty_action_pressed(action_id: String) -> void:
	var result = {}
	if action_id.begins_with("choose_specialty:"):
		result = OverworldRules.choose_specialty(_session, action_id.trim_prefix("choose_specialty:"))

	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_record_result_feedback("hero", result, "Hero command updated.")
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _handle_session_resolution():
		return
	_refresh()

func _on_hero_action_pressed(action_id: String) -> void:
	var result = {}
	if action_id.begins_with("switch_hero:"):
		result = OverworldRules.switch_active_hero(_session, action_id.trim_prefix("switch_hero:"))

	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_record_result_feedback("hero", result, "Hero command updated.")
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _handle_session_resolution():
		return
	_refresh()

func _on_spell_action_pressed(action_id: String) -> void:
	var result = {}
	if action_id.begins_with("cast_spell:"):
		result = OverworldRules.cast_overworld_spell(_session, action_id.trim_prefix("cast_spell:"))

	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_record_result_feedback("cast", result, "Spell resolved.")
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _handle_session_resolution():
		return
	_refresh()

func _on_map_tile_pressed(tile: Vector2i) -> void:
	var handler_started_usec := Time.get_ticks_usec()
	if not _tile_in_bounds(tile):
		return
	var debug_started := _debug_begin_path_command("click", tile)
	_debug_record_phase_usec("input_handler_entry", Time.get_ticks_usec() - handler_started_usec, {"handler": "map_tile_pressed"})
	var route_tile := _selection_route_tile(tile)
	_debug_set_path_command_target(route_tile)
	if route_tile == _selected_tile:
		_debug_set_path_command_type("click_existing_selection")
		if not _activate_primary_action():
			_move_toward_selected_tile()
		_debug_finish_path_command()
		return

	_set_selected_tile(route_tile)
	if _is_selected_owned_town_visit_target():
		_debug_set_path_command_type("select_town")
		_visit_selected_town()
		_debug_finish_path_command()
		return
	var hero_pos = OverworldRules.hero_position(_session)
	if _is_adjacent_move_target(hero_pos, route_tile):
		_debug_set_path_command_type("adjacent_move")
		_try_move(route_tile.x - hero_pos.x, route_tile.y - hero_pos.y, true)
		_debug_finish_path_command()
		return
	_active_drawer = ""
	_debug_set_path_command_type("select_route")
	_refresh_selected_route_preview("selected_route_changed")
	if debug_started:
		_debug_finish_path_command()

func _on_map_tile_hovered(tile: Vector2i) -> void:
	var profile_start := _profile_begin("hover")
	_hovered_tile = tile
	_update_map_tooltip()
	if _active_drawer != "" or _validation_force_hover_drawer_sync:
		_sync_context_drawers()
	_profile_end("hover", profile_start, {"tile": {"x": tile.x, "y": tile.y}})

func _visit_selected_town() -> bool:
	if not _is_selected_owned_town_visit_target():
		_last_message = "Select an owned town to enter it."
		_last_enemy_activity_text = ""
		_last_turn_resolution_text = ""
		_record_action_feedback("blocked", _last_message)
		_refresh()
		return false
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	var result: Dictionary = OverworldRules.set_active_town_visit(_session, String(town.get("placement_id", "")))
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_record_result_feedback("town", result, "Town opened.")
	if not bool(result.get("ok", false)):
		_refresh()
		return false
	_session.flags["last_action"] = "visited_town"
	AppRouter.go_to_town()
	return true

func _try_move(dx: int, dy: int, preserve_selection: bool = false) -> void:
	var hero_pos_before := OverworldRules.hero_position(_session)
	var debug_started := _debug_begin_path_command("move", hero_pos_before + Vector2i(dx, dy))
	var movement_rules_started_usec := _debug_phase_begin("movement_rules")
	var result = OverworldRules.try_move(_session, dx, dy)
	_debug_phase_end("movement_rules", movement_rules_started_usec, {"ok": bool(result.get("ok", false)), "route": String(result.get("route", ""))})
	_handle_move_result(result, preserve_selection, debug_started)

func _handle_move_result(result: Dictionary, preserve_selection: bool, debug_started: bool) -> void:
	var route := String(result.get("route", ""))
	_last_route_execution = {}
	if result.has("route_execution"):
		_last_route_execution = _duplicate_dictionary(result.get("route_execution", {}))
		var route_steps = result.get("route_steps", [])
		if route_steps is Array:
			_last_route_execution["route_steps"] = route_steps.duplicate(true)
	if route == "battle":
		_session.flags["last_action"] = "entered_battle"
	elif route == "town":
		_session.flags["last_action"] = "visited_town"
	else:
		_session.flags["last_action"] = "moved" if bool(result.get("ok", false)) else "blocked_move"
	_last_message = String(result.get("message", ""))
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_record_result_feedback(_feedback_kind_for_move(result, route), result, _movement_feedback_fallback(result))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		if not preserve_selection:
			_select_hero_tile()
	if _handle_session_resolution():
		if debug_started:
			_debug_finish_path_command()
		return
	if route == "battle":
		if debug_started:
			_debug_finish_path_command()
		AppRouter.go_to_battle()
		return
	if route == "town":
		if debug_started:
			_debug_finish_path_command()
		AppRouter.go_to_town()
		return
	if preserve_selection and _last_route_execution.has("reached_destination"):
		_refresh_selected_route_preview("route_execution_changed")
	else:
		_refresh()
	if debug_started:
		_debug_finish_path_command()

func _move_toward_selected_tile() -> void:
	var debug_started := _debug_begin_path_command("full_route_execute", _selected_tile)
	var route_lookup_started_usec := _debug_phase_begin("route_execution_lookup")
	var route_state := _ensure_selected_route_state("execution")
	var route: Array = route_state.get("route_tiles", []) if route_state.get("route_tiles", []) is Array else []
	var preview: Dictionary = route_state.get("route_preview", {}) if route_state.get("route_preview", {}) is Dictionary else {}
	var fallback_reason := _selected_cached_route_execution_fallback_reason(route_state, route, preview)
	var use_cached_execution := fallback_reason == ""
	_debug_phase_end("route_execution_lookup", route_lookup_started_usec, {
		"path_tiles": route.size(),
		"cached_route_execution": use_cached_execution,
		"fallback_reason": fallback_reason,
	})
	if route.size() <= 1:
		if debug_started:
			_debug_finish_path_command()
		return
	var movement_rules_started_usec := _debug_phase_begin("movement_rules")
	var result: Dictionary = OverworldRules.execute_prevalidated_route(_session, route, preview) if use_cached_execution else OverworldRules.try_move_along_route(_session, route)
	var executed_steps := 0
	var route_steps = result.get("route_steps", [])
	if route_steps is Array:
		executed_steps = route_steps.size()
	var route_execution: Dictionary = result.get("route_execution", {}) if result.get("route_execution", {}) is Dictionary else {}
	var reachable_steps := int(route_execution.get("reachable_steps", executed_steps))
	var destination_reached := bool(route_execution.get("reached_destination", false))
	var validation_mode := String(result.get("route_validation_mode", route_execution.get("route_validation_mode", "cached_prevalidated" if use_cached_execution else "full_revalidation")))
	_debug_phase_end(
		"movement_rules",
		movement_rules_started_usec,
		{
			"ok": bool(result.get("ok", false)),
			"route": String(result.get("route", "")),
			"executed_steps": executed_steps,
			"cached_route_execution": use_cached_execution,
			"fallback_reason": fallback_reason,
			"route_steps": max(0, route.size() - 1),
			"reachable_steps": reachable_steps,
			"destination_reached": destination_reached,
			"route_validation_mode": validation_mode,
		}
	)
	_adopt_selected_route_after_execution(route, result)
	_handle_move_result(result, true, debug_started)

func _selected_cached_route_execution_fallback_reason(route_state: Dictionary, route: Array, preview: Dictionary) -> String:
	if route_state.is_empty() or not bool(route_state.get("valid", false)):
		return "missing_route_state"
	if route.size() <= 1:
		return "empty_route"
	if not (route[0] is Vector2i):
		return "invalid_route_start"
	var hero_pos := OverworldRules.hero_position(_session)
	if route[0] != hero_pos:
		return "route_start_stale"
	var selected_payload = route_state.get("selected_tile", {})
	if not (selected_payload is Dictionary):
		return "missing_selected_tile"
	var selected_from_state := Vector2i(int(selected_payload.get("x", -1)), int(selected_payload.get("y", -1)))
	if selected_from_state != _selected_tile:
		return "selected_tile_stale"
	var movement = _session.overworld.get("movement", {})
	var movement_current := int(movement.get("current", 0)) if movement is Dictionary else 0
	if int(route_state.get("movement_current", -1)) != movement_current:
		return "movement_stale"
	if preview.is_empty():
		return "missing_route_preview"
	var reachable_steps := int(preview.get("reachable_steps", 0))
	if reachable_steps <= 0:
		return "no_reachable_steps"
	if reachable_steps >= route.size():
		return "preview_out_of_range"
	var destination: Vector2i = route[route.size() - 1]
	if not _tile_in_bounds(destination):
		return "destination_out_of_bounds"
	if OverworldRules.tile_is_blocked(_session, destination.x, destination.y):
		return "destination_blocked"
	return ""

func _start_encounter() -> void:
	var placement = OverworldRules.get_active_encounter(_session)
	if placement.is_empty():
		_last_message = "No encounter is active here."
		_last_enemy_activity_text = ""
		_last_turn_resolution_text = ""
		_record_action_feedback("blocked", _last_message)
		_refresh()
		return

	var payload = BattleRules.create_battle_payload(_session, placement)
	if payload.is_empty():
		push_error("Unable to create battle payload for encounter %s." % String(placement.get("encounter_id", placement.get("id", ""))))
		_last_message = "Battle setup failed."
		_last_enemy_activity_text = ""
		_last_turn_resolution_text = ""
		_record_action_feedback("blocked", _last_message)
		_refresh()
		return

	_session.battle = payload
	_session.flags["last_action"] = "entered_battle"
	_last_enemy_activity_text = ""
	_last_turn_resolution_text = ""
	_record_action_feedback("battle", OverworldRules.describe_encounter_battle_cue(_session, placement))
	AppRouter.go_to_battle()

func _render_state() -> void:
	_map_data = _session.overworld.get("map", []) if _session.overworld.get("map", []) is Array else []
	_map_size = OverworldRules.derive_map_size(_session)
	_refresh()

func _refresh() -> void:
	_refresh_with_request(_make_refresh_request("full_refresh", REFRESH_ALL_PHASES, true, true))

func _refresh_selected_route_preview(reason: String = "selected_route_preview") -> void:
	_refresh_with_request(_make_refresh_request(
		reason,
		[
			REFRESH_PHASE_MAP_VIEW,
			REFRESH_PHASE_CONTEXT_ROUTE,
		],
		true,
		false
	))

func _refresh_with_request(request: Dictionary) -> void:
	var profile_start := _profile_begin("refresh")
	AppRouter.note_overworld_handoff_step("overworld_refresh_enter")
	_record_refresh_request(request)
	_refresh_read_scope_and_map_state()
	if _refresh_request_has_phase(request, REFRESH_PHASE_MAP_VIEW):
		_refresh_map_view()
	if _refresh_request_has_any_phase(request, [
		REFRESH_PHASE_ACTION_RAILS,
		REFRESH_PHASE_HERO_ACTIONS,
		REFRESH_PHASE_CONTEXT_ACTIONS,
		REFRESH_PHASE_SPELL_RAILS,
		REFRESH_PHASE_SPECIALTY_RAILS,
		REFRESH_PHASE_ARTIFACT_RAILS,
	]):
		_refresh_action_rails(request)
	elif _refresh_request_has_phase(request, REFRESH_PHASE_CONTEXT_ROUTE):
		_refresh_selected_route_action_surface()
	var generated_surface_start := 0
	if _refresh_request_has_phase(request, REFRESH_PHASE_SAVE_SURFACE):
		generated_surface_start = _refresh_save_surface()
	var compact_generated := false
	if _refresh_request_has_phase(request, REFRESH_PHASE_STATUS_SURFACES):
		compact_generated = _refresh_status_surfaces(generated_surface_start)
	elif _refresh_request_has_phase(request, REFRESH_PHASE_CONTEXT_ROUTE):
		_refresh_context_tile_surface()
		_validation_profile["last_route_tooltip_context_drawers"] = {
			"status": "skipped",
			"reason": "selected_route_destination_only",
		}
		_profile_add("route_tooltip_context_drawers_skipped", 1)
	OverworldRules.end_normalized_read_scope(_session)
	if compact_generated:
		AppRouter.note_overworld_handoff_step("overworld_refresh_text_surfaces_compact")
	AppRouter.note_overworld_handoff_step("overworld_refresh_done")
	_complete_refresh_request(request)
	_profile_end("refresh", profile_start, {
		"compact_generated": compact_generated,
		"request": request.duplicate(true),
	})

func _make_refresh_request(reason: String, phases: Array, include_dirty: bool = true, full_refresh: bool = false) -> Dictionary:
	_refresh_request_sequence += 1
	var phase_map := {}
	for phase in phases:
		phase_map[String(phase)] = true
	if full_refresh:
		for phase in REFRESH_ALL_PHASES:
			phase_map[String(phase)] = true
	elif include_dirty:
		for phase_value in _refresh_dirty_phases.keys():
			phase_map[String(phase_value)] = true
	var ordered_phases := []
	for phase in REFRESH_ALL_PHASES:
		if bool(phase_map.get(String(phase), false)):
			ordered_phases.append(String(phase))
	for phase_value in phase_map.keys():
		var phase_name := String(phase_value)
		if phase_name not in ordered_phases:
			ordered_phases.append(phase_name)
	return {
		"id": _refresh_request_sequence,
		"reason": reason,
		"full": full_refresh,
		"phases": ordered_phases,
		"dirty_before": _refresh_dirty_phase_list(),
	}

func _refresh_request_has_phase(request: Dictionary, phase: String) -> bool:
	var phases: Array = request.get("phases", []) if request.get("phases", []) is Array else []
	return phase in phases

func _refresh_request_has_any_phase(request: Dictionary, phases: Array) -> bool:
	for phase in phases:
		if _refresh_request_has_phase(request, String(phase)):
			return true
	return false

func _record_refresh_request(request: Dictionary) -> void:
	_validation_profile["last_refresh_request"] = request.duplicate(true)
	_profile_add("refresh_request_%s_calls" % _refresh_request_bucket(String(request.get("reason", ""))), 1)
	for phase_value in request.get("phases", []):
		_profile_add("refresh_phase_%s_calls" % _refresh_phase_bucket(String(phase_value)), 1)

func _complete_refresh_request(request: Dictionary) -> void:
	var phases: Array = request.get("phases", []) if request.get("phases", []) is Array else []
	for phase in phases:
		_refresh_dirty_phases.erase(String(phase))
	_validation_profile["last_refresh_dirty_after"] = _refresh_dirty_phase_list()

func _mark_refresh_dirty(phases: Array, reason: String = "") -> void:
	for phase in phases:
		var phase_name := String(phase)
		_refresh_dirty_phases[phase_name] = {
			"reason": reason,
			"sequence": _refresh_request_sequence,
		}
	_validation_profile["last_refresh_dirty_mark"] = {
		"reason": reason,
		"phases": _refresh_dirty_phase_list(),
	}

func _refresh_dirty_phase_list() -> Array:
	var phases := []
	for phase in REFRESH_ALL_PHASES:
		if _refresh_dirty_phases.has(String(phase)):
			phases.append(String(phase))
	for phase_value in _refresh_dirty_phases.keys():
		var phase_name := String(phase_value)
		if phase_name not in phases:
			phases.append(phase_name)
	return phases

func _refresh_phase_bucket(phase: String) -> String:
	return phase.replace("/", "_").replace("-", "_").replace(" ", "_")

func _refresh_request_bucket(reason: String) -> String:
	var bucket := reason.strip_edges().to_lower().replace("/", "_").replace("-", "_").replace(" ", "_")
	return bucket if bucket != "" else "unspecified"

func _refresh_read_scope_and_map_state() -> void:
	var read_scope_profile_start := _debug_refresh_profile_begin("refresh_read_scope_map_state")
	OverworldRules.begin_normalized_read_scope(_session)
	AppRouter.note_overworld_handoff_step("overworld_refresh_read_scope_ready")
	_map_data = _session.overworld.get("map", []) if _session.overworld.get("map", []) is Array else []
	_map_size = OverworldRules.derive_map_size(_session)
	_ensure_selected_tile()
	_invalidate_refresh_cache(true)
	_debug_refresh_profile_end("refresh_read_scope_map_state", read_scope_profile_start)

func _refresh_map_view() -> void:
	AppRouter.note_overworld_handoff_step("overworld_refresh_set_map_state_start")
	var set_map_state_profile_start := _profile_begin("refresh_set_map_state")
	_map_view.set_map_state(_session, _map_data, _map_size, _selected_tile, _selected_route_cache_for_map_view())
	_profile_end("refresh_set_map_state", set_map_state_profile_start)
	AppRouter.note_overworld_handoff_step("overworld_refresh_set_map_state_done")

func _refresh_action_rails(request: Dictionary = {}) -> void:
	AppRouter.note_overworld_handoff_step("overworld_refresh_actions_start")
	var actions_profile_start := _profile_begin("refresh_actions")
	var full_action_rails := request.is_empty() or _refresh_request_has_phase(request, REFRESH_PHASE_ACTION_RAILS)
	if full_action_rails or _refresh_request_has_phase(request, REFRESH_PHASE_HERO_ACTIONS):
		var hero_actions_profile_start := _debug_refresh_profile_begin("refresh_hero_actions")
		_rebuild_hero_actions()
		_debug_refresh_profile_end("refresh_hero_actions", hero_actions_profile_start)
	if full_action_rails or _refresh_request_has_phase(request, REFRESH_PHASE_CONTEXT_ACTIONS):
		var context_actions_profile_start := _debug_refresh_profile_begin("refresh_context_actions")
		_rebuild_context_actions()
		_debug_refresh_profile_end("refresh_context_actions", context_actions_profile_start)
	if full_action_rails or _refresh_request_has_phase(request, REFRESH_PHASE_SPELL_RAILS):
		var spell_actions_profile_start := _debug_refresh_profile_begin("refresh_spell_actions")
		_rebuild_spell_actions()
		_debug_refresh_profile_end("refresh_spell_actions", spell_actions_profile_start)
	if full_action_rails or _refresh_request_has_phase(request, REFRESH_PHASE_SPECIALTY_RAILS):
		var specialty_actions_profile_start := _debug_refresh_profile_begin("refresh_specialty_actions")
		_rebuild_specialty_actions()
		_debug_refresh_profile_end("refresh_specialty_actions", specialty_actions_profile_start)
	if full_action_rails or _refresh_request_has_phase(request, REFRESH_PHASE_ARTIFACT_RAILS):
		var artifact_actions_profile_start := _debug_refresh_profile_begin("refresh_artifact_actions")
		_rebuild_artifact_actions()
		_debug_refresh_profile_end("refresh_artifact_actions", artifact_actions_profile_start)
	_profile_end("refresh_actions", actions_profile_start)
	AppRouter.note_overworld_handoff_step("overworld_refresh_actions_done")

func _refresh_save_surface() -> int:
	AppRouter.note_overworld_handoff_step("overworld_refresh_save_surface_start")
	var generated_surface_start := 0
	if _generated_initial_open_pending():
		generated_surface_start = _profile_begin("refresh_generated_surfaces")
		_set_deferred_generated_save_status("Save: generated autosave pending")
		AppRouter.note_overworld_handoff_step("overworld_refresh_save_surface_deferred")
	elif _use_generated_compact_refresh():
		generated_surface_start = _profile_begin("refresh_generated_surfaces")
		_set_deferred_generated_save_status("Save: ready")
		AppRouter.note_overworld_handoff_step("overworld_refresh_save_surface_compact")
	else:
		_refresh_save_slot_picker()
		AppRouter.note_overworld_handoff_step("overworld_refresh_save_surface_done")
	return generated_surface_start

func _refresh_status_surfaces(generated_surface_start: int) -> bool:
	AppRouter.note_overworld_handoff_step("overworld_refresh_text_surfaces_start")
	if _generated_initial_open_pending() or _use_generated_compact_refresh():
		_refresh_generated_opening_surfaces()
		if generated_surface_start > 0:
			_profile_end("refresh_generated_surfaces", generated_surface_start)
		return true
	var header_profile_start := _debug_refresh_profile_begin("refresh_header_objective_status_resources")
	var scenario = ContentService.get_scenario(_session.scenario_id)
	_header_label.text = String(scenario.get("name", "Overworld Command"))
	var objective_brief := OverworldRules.describe_objective_brief(_session)
	var objective_stakes := OverworldRules.describe_objective_stakes_board(_session)
	var readiness_surface := _field_readiness_surface()
	_objective_brief_label.text = _compact_text(objective_brief, 1, 72, false)
	_objective_brief_label.tooltip_text = _join_tooltip_sections([
		objective_stakes,
		String(readiness_surface.get("tooltip_text", "")),
	])
	var status_forecast := _status_forecast_surface()
	_status_label.tooltip_text = String(status_forecast.get("tooltip_text", ""))
	_status_label.text = _compact_text(String(status_forecast.get("visible_text", "")), 1, 64, false)
	var resource_text := OverworldRules.describe_resources(_session)
	_resource_label.tooltip_text = resource_text
	_resource_label.text = resource_text
	_map_cue_label.text = _map_cue_text()
	_map_cue_label.tooltip_text = _map_cue_tooltip()
	_debug_refresh_profile_end("refresh_header_objective_status_resources", header_profile_start)
	var commitment_profile_start := _debug_refresh_profile_begin("refresh_commitment_rail")
	_refresh_commitment_panel()
	_debug_refresh_profile_end("refresh_commitment_rail", commitment_profile_start)
	var hero_rail_profile_start := _debug_refresh_profile_begin("refresh_hero_rail")
	var hero_text := _hero_card_text()
	_set_rail_text(_hero_label, hero_text, hero_text, 2)
	_debug_refresh_profile_end("refresh_hero_rail", hero_rail_profile_start)
	var army_rail_profile_start := _debug_refresh_profile_begin("refresh_army_rail")
	var army_text := OverworldRules.describe_army(_session)
	_set_rail_text(_army_label, army_text, _rail_prefixed_summary("Army", army_text), 1)
	_debug_refresh_profile_end("refresh_army_rail", army_rail_profile_start)
	var heroes_rail_profile_start := _debug_refresh_profile_begin("refresh_heroes_rail")
	var heroes_text := OverworldRules.describe_heroes(_session)
	var command_check := _command_check_surface()
	_set_rail_text(
		_heroes_label,
		_join_tooltip_sections([heroes_text, String(command_check.get("tooltip_text", ""))]),
		String(command_check.get("visible_text", _rail_prefixed_summary("Heroes", heroes_text))),
		1
	)
	_debug_refresh_profile_end("refresh_heroes_rail", heroes_rail_profile_start)
	var specialty_rail_profile_start := _debug_refresh_profile_begin("refresh_specialty_rail")
	var specialty_text := OverworldRules.describe_specialties(_session)
	var specialty_check := _specialty_check_surface()
	_set_rail_text(
		_specialty_label,
		_join_tooltip_sections([specialty_text, String(specialty_check.get("tooltip_text", ""))]),
		String(specialty_check.get("visible_text", _rail_prefixed_summary("Spec", specialty_text))),
		1
	)
	_debug_refresh_profile_end("refresh_specialty_rail", specialty_rail_profile_start)
	var spell_rail_profile_start := _debug_refresh_profile_begin("refresh_spell_rail")
	var spell_text := OverworldRules.describe_spellbook(_session, SpellRules.CONTEXT_OVERWORLD)
	var spell_check := _spell_check_surface()
	_set_rail_text(
		_spell_label,
		_join_tooltip_sections([spell_text, String(spell_check.get("tooltip_text", ""))]),
		String(spell_check.get("visible_text", OverworldRules.describe_spellbook_rail(_session, SpellRules.CONTEXT_OVERWORLD))),
		1
	)
	_debug_refresh_profile_end("refresh_spell_rail", spell_rail_profile_start)
	var artifact_rail_profile_start := _debug_refresh_profile_begin("refresh_artifact_rail")
	var artifact_text := OverworldRules.describe_artifacts(_session)
	_set_rail_text(_artifact_label, artifact_text, _rail_prefixed_summary("Gear", artifact_text), 1)
	_debug_refresh_profile_end("refresh_artifact_rail", artifact_rail_profile_start)
	var frontier_profile_start := _debug_refresh_profile_begin("refresh_frontier_drawer")
	var command_risk_surface := {}
	if _active_drawer == "frontier":
		command_risk_surface = _refresh_frontier_drawer()
	else:
		_set_collapsed_frontier_indicator()
	_debug_refresh_profile_end("refresh_frontier_drawer", frontier_profile_start, {"drawer_open": _active_drawer == "frontier"})
	_refresh_context_tile_surface()
	var event_context_profile_start := _debug_refresh_profile_begin("refresh_event_action_context")
	var event_surface := _event_feed_surface()
	var action_context_surface := _action_context_surface(event_surface, readiness_surface)
	_set_rail_text(
		_event_label,
		String(action_context_surface.get("tooltip_text", "")),
		String(action_context_surface.get("visible_text", _rail_log_text())),
		1
	)
	_debug_refresh_profile_end("refresh_event_action_context", event_context_profile_start)
	var end_turn_profile_start := _debug_refresh_profile_begin("refresh_end_turn_surface")
	var end_turn_check := _end_turn_confirmation_surface(readiness_surface)
	_end_turn_button.text = String(end_turn_check.get("button_text", "End Turn"))
	_end_turn_button.tooltip_text = String(end_turn_check.get("tooltip_text", OverworldRules.describe_end_turn_forecast(_session)))
	_debug_refresh_profile_end("refresh_end_turn_surface", end_turn_profile_start)
	_briefing_title_label.text = _briefing_title_text
	_set_rail_label(_briefing_label, _command_briefing_text, 2, RAIL_LINE_CHARS, false)
	_briefing_panel.visible = _command_briefing_text != ""
	_refresh_tooltip_context_drawer_surfaces()
	return false

func _refresh_context_tile_surface() -> void:
	var context_tile_profile_start := _debug_refresh_profile_begin("refresh_context_tile_text")
	var context_text := _cached_focus_tile_text()
	_set_rail_text(_context_label, context_text, _rail_tile_text(), 2)
	_debug_refresh_profile_end("refresh_context_tile_text", context_tile_profile_start)

func _refresh_tooltip_context_drawer_surfaces() -> void:
	var tooltip_context_profile_start := _debug_refresh_profile_begin("refresh_tooltip_context_drawers")
	_update_map_tooltip()
	_sync_context_drawers()
	_debug_refresh_profile_end("refresh_tooltip_context_drawers", tooltip_context_profile_start)

func _refresh_generated_opening_surfaces() -> void:
	var scenario = ContentService.get_scenario(_session.scenario_id)
	var hero: Dictionary = _session.overworld.get("hero", {}) if _session.overworld.get("hero", {}) is Dictionary else {}
	var movement: Dictionary = _session.overworld.get("movement", {}) if _session.overworld.get("movement", {}) is Dictionary else {}
	var resources: Dictionary = _session.overworld.get("resources", {}) if _session.overworld.get("resources", {}) is Dictionary else {}
	var hero_pos := OverworldRules.hero_position(_session)
	var hero_name := String(hero.get("name", "Commander"))
	var opening_pending := _generated_initial_open_pending()
	var move_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", movement.get("current", 0))),
	]
	var resource_line := "Gold %d | Wood %d | Ore %d" % [
		int(resources.get("gold", 0)),
		int(resources.get("wood", 0)),
		int(resources.get("ore", 0)),
	]
	_header_label.text = String(scenario.get("name", "Generated Map"))
	_objective_brief_label.text = "Generated map opening" if opening_pending else "Generated map objective"
	_objective_brief_label.tooltip_text = "Detailed objective and readiness surfaces are available from command/frontier drawers; routine generated-map movement keeps the live frame compact."
	_status_label.text = "Day %d | Pos %d,%d | %s" % [_session.day, hero_pos.x, hero_pos.y, move_line]
	_status_label.tooltip_text = "Generated map is playable; compact live refresh avoids rebuilding detailed rails on every movement."
	_resource_label.text = resource_line
	_resource_label.tooltip_text = resource_line
	_map_cue_label.text = "Opening generated map" if opening_pending else _map_cue_text()
	_map_cue_label.tooltip_text = "Map art and controls are loaded; save summary and detailed rails are deferred off routine generated-map frames."
	_commitment_label.text = ""
	_commitment_label.tooltip_text = ""
	_set_rail_text(_hero_label, "%s | %s" % [hero_name, move_line], "%s | %s" % [hero_name, move_line], 2)
	_set_rail_text(_army_label, "Army ready", "Army ready", 1)
	_set_rail_text(_heroes_label, "Command ready", "Command ready", 1)
	_set_rail_text(_specialty_label, "Spec ready", "Spec ready", 1)
	_set_rail_text(_spell_label, "Spellbook ready", "Spellbook ready", 1)
	_set_rail_text(_artifact_label, "Gear ready", "Gear ready", 1)
	_set_collapsed_generated_opening_frontier_indicator()
	_set_rail_text(_context_label, "Select a visible destination for orders.", "Select a visible destination", 2)
	_set_rail_text(_event_label, _last_message if _last_message != "" else "Generated map ready.", "Generated map ready", 1)
	_end_turn_button.text = "End Turn"
	_end_turn_button.tooltip_text = "Finish the current day after issuing field orders."
	_briefing_title_label.text = _briefing_title_text
	_set_rail_label(_briefing_label, _command_briefing_text, 2, RAIL_LINE_CHARS, false)
	_briefing_panel.visible = _command_briefing_text != ""
	_update_map_tooltip()
	_command_panel.visible = false
	_frontier_panel.visible = false
	_context_panel.visible = false
	_command_spine.visible = false
	_open_command_button.button_pressed = false
	_open_frontier_button.button_pressed = false

func _set_collapsed_generated_opening_frontier_indicator() -> void:
	_frontier_indicator_label.text = "Frontier: opening"
	_frontier_indicator_label.tooltip_text = "Detailed frontier forecast is deferred until generated-map opening completes."

func _complete_deferred_generated_overworld_autosave() -> void:
	if _session == null:
		return
	if not bool(_session.flags.get("generated_overworld_deferred_autosave_pending", false)):
		AppRouter.finish_overworld_handoff_profile({"deferred_autosave": false})
		return
	AppRouter.note_overworld_handoff_step("overworld_deferred_autosave_wait_frame_start")
	await get_tree().process_frame
	AppRouter.note_overworld_handoff_step("overworld_deferred_autosave_start")
	var result := SaveService.save_runtime_autosave_session(_session, false)
	_session.flags.erase("generated_overworld_deferred_autosave_pending")
	_session.flags.erase("generated_overworld_command_briefing_autosave_deferred")
	_session.flags["generated_overworld_initial_autosave_completed"] = bool(result.get("ok", false))
	_set_deferred_generated_save_status("Save: generated autosave ready" if bool(result.get("ok", false)) else "Save: generated autosave failed")
	AppRouter.note_overworld_handoff_step(
		"overworld_deferred_autosave_done",
		{"ok": bool(result.get("ok", false)), "path": String(result.get("path", ""))}
	)
	AppRouter.finish_overworld_handoff_profile({"deferred_autosave": true, "autosave_ok": bool(result.get("ok", false))})

func _configure_save_slot_picker(refresh_now: bool = true) -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("M%d" % int(slot), int(slot))
	if refresh_now:
		_refresh_save_slot_picker()

func _generated_initial_open_pending() -> bool:
	return _session != null and bool(_session.flags.get("generated_overworld_deferred_autosave_pending", false))

func _use_generated_compact_refresh() -> bool:
	return (
		_session != null
		and bool(_session.flags.get("generated_random_map", false))
		and _active_drawer == ""
	)

func _set_deferred_generated_save_status(text: String) -> void:
	var save_ready := text.find("ready") >= 0
	_save_status_label.text = text
	_save_status_label.tooltip_text = "Generated map refresh keeps save summary inspection off first-frame and routine movement paths."
	_save_button.text = "Save"
	_save_button.tooltip_text = "Save the active expedition to the selected manual slot." if save_ready else "Save is available after the generated-map opening autosave settles."
	_menu_button.text = "Menu: Field"
	_menu_button.tooltip_text = "Return to the main menu." if save_ready else "Return to the main menu after the generated-map opening autosave settles."

func _refresh_save_slot_picker() -> void:
	if _save_slot_picker.get_item_count() <= 0:
		return

	var surface = AppRouter.active_save_surface()
	var selected_slot = SaveService.get_selected_manual_slot()
	for index in range(_save_slot_picker.get_item_count()):
		if _save_slot_picker.get_item_id(index) == selected_slot:
			_save_slot_picker.select(index)
			break

	var summary_value: Variant = surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
	var summary: Dictionary = summary_value if summary_value is Dictionary else SaveService.inspect_manual_slot(selected_slot)
	var latest_context := String(surface.get("latest_context", "Latest ready save: none."))
	var current_context := String(surface.get("current_context", ""))
	var save_check := String(surface.get("save_check", ""))
	var return_handoff := String(surface.get("return_handoff", ""))
	var current_save_recap := String(surface.get("current_save_recap", ""))
	var save_tooltip_lines := [latest_context]
	if save_check != "":
		save_tooltip_lines.append(save_check)
	if return_handoff != "":
		save_tooltip_lines.append(return_handoff)
	if current_save_recap != "":
		save_tooltip_lines.append("Saving now recap:\n%s" % current_save_recap)
	if current_context != "":
		save_tooltip_lines.append("Saving now: %s" % current_context)
	save_tooltip_lines.append("Selected slot:\n%s" % SaveService.describe_slot_details(summary))
	_save_status_label.text = _save_status_text(selected_slot, summary, latest_context)
	_save_status_label.tooltip_text = "\n".join(save_tooltip_lines)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = "Save"
	_save_button.tooltip_text = "%s\n%s" % [
		String(surface.get("save_button_tooltip", "Save the active expedition.")),
		save_check,
	]
	if bool(_session.flags.get("editor_working_copy", false)):
		_menu_button.text = "Editor"
		_menu_button.tooltip_text = "%s\n%s" % [
			"Return to the map editor and restore the Play Copy launch snapshot.",
			return_handoff,
		]
	else:
		_menu_button.text = String(surface.get("menu_button_label", "Menu: Field"))
		_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func _refresh_commitment_panel() -> void:
	if not _commitment_panel.visible:
		_commitment_label.text = ""
		_commitment_label.tooltip_text = ""
		return
	var commitment_text := OverworldRules.describe_commitment_board(_session)
	_set_rail_text(_commitment_label, commitment_text, _rail_order_text(commitment_text), 2)

func _refresh_frontier_drawer() -> Dictionary:
	var visibility_text := OverworldRules.describe_visibility_panel(_session)
	_set_rail_text(_visibility_label, visibility_text, _rail_prefixed_summary("Sight", visibility_text), 1)
	var objective_text := _cached_objective_text()
	_set_rail_text(_objective_label, objective_text, _rail_prefixed_summary("Obj", objective_text), 1)
	var threat_text := _cached_frontier_threats()
	_set_rail_text(_threat_label, threat_text, _rail_prefixed_summary("Threat", threat_text), 1)
	var command_risk_surface := _cached_command_risk_surface()
	var forecast_text := OverworldRules.describe_end_turn_forecast(_session)
	command_risk_surface["forecast"] = forecast_text
	_set_rail_text(_forecast_label, forecast_text, _rail_prefixed_summary("Next", forecast_text), 1)
	_frontier_indicator_label.text = _frontier_indicator_text(threat_text, forecast_text)
	_frontier_indicator_label.tooltip_text = "%s\n\n%s" % [threat_text, forecast_text]
	return command_risk_surface

func _set_collapsed_frontier_indicator() -> void:
	var forecast_text := OverworldRules.describe_end_turn_forecast(_session)
	var compact_forecast := OverworldRules.describe_end_turn_forecast_compact(_session)
	_frontier_indicator_label.text = "Next: %s" % _short_text(compact_forecast, 34)
	_frontier_indicator_label.tooltip_text = "%s\n\nOpen Frontier for objectives, threat watch, and next-day risk." % forecast_text

func _rebuild_hero_actions() -> void:
	for child in _hero_actions.get_children():
		child.queue_free()

	var actions = _cached_hero_actions()
	if actions.size() <= 1:
		var placeholder := _make_placeholder_label("Command check: solo")
		placeholder.tooltip_text = String(_command_check_surface().get("tooltip_text", "No reserve switch."))
		_hero_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Command")))
		button.disabled = bool(action.get("disabled", false))
		var switch_check := _hero_switch_check_surface(action)
		button.tooltip_text = _join_tooltip_sections([
			String(action.get("summary", "")),
			String(switch_check.get("tooltip_text", "")),
		])
		_style_rail_action_button(button)
		button.pressed.connect(_on_hero_action_pressed.bind(String(action.get("id", ""))))
		_hero_actions.add_child(button)

func _rebuild_context_actions() -> void:
	var actions := _current_context_actions()
	var primary_action := _first_enabled_action(actions)
	_refresh_primary_action_button(primary_action)
	_render_context_action_buttons(actions, primary_action, "Select a tile for orders")

func _refresh_selected_route_action_surface() -> void:
	var route_action_started := _debug_refresh_profile_begin("refresh_route_destination_action")
	var actions := _selected_route_destination_actions()
	var primary_action := _first_enabled_action(actions)
	_refresh_cache["context_actions"] = actions
	_refresh_cache["primary_action"] = primary_action
	_refresh_primary_action_button(primary_action)
	_render_context_action_buttons(actions, primary_action, "Select a route destination")
	var destination: Dictionary = _selected_route_destination_interaction_surface()
	var profile_payload := {
		"status": "used",
		"destination_only": true,
		"broad_context_actions_skipped": true,
		"hero_actions_skipped": true,
		"tooltip_context_drawers_skipped": true,
		"action_count": actions.size(),
		"primary_action_id": String(primary_action.get("id", "")),
		"destination_interaction_kind": String(destination.get("kind", "")),
		"destination_interaction_status": String(destination.get("status", "")),
		"route_status": String(destination.get("route_status", "")),
	}
	_validation_profile["last_route_destination_only_action_path"] = profile_payload
	_profile_add("route_destination_only_action_path_calls", 1)
	_profile_add("broad_context_actions_skipped", 1)
	_profile_add("hero_actions_skipped_for_route_action", 1)
	_debug_refresh_profile_end("refresh_route_destination_action", route_action_started, profile_payload)

func _render_context_action_buttons(actions: Array, primary_action: Dictionary, placeholder_text: String) -> void:
	for child in _context_actions.get_children():
		child.queue_free()

	if actions.is_empty():
		_context_actions.add_child(_make_placeholder_label(placeholder_text))
		return

	var skipped_primary := false
	for action in actions:
		if not (action is Dictionary):
			continue
		if (
			not skipped_primary
			and not primary_action.is_empty()
			and String(action.get("id", "")) == String(primary_action.get("id", ""))
		):
			skipped_primary = true
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_rail_action_button(button, "primary", 34.0)
		button.pressed.connect(_on_context_action_pressed.bind(String(action.get("id", ""))))
		_context_actions.add_child(button)

func _current_context_actions() -> Array:
	var context_actions_started_usec := _debug_phase_begin("context_actions_computation")
	if _refresh_cache.has("context_actions"):
		var cached_actions: Array = _refresh_cache["context_actions"]
		_debug_phase_end("context_actions_computation", context_actions_started_usec, {"cached": true, "action_count": cached_actions.size()})
		return cached_actions
	var actions: Array = []
	if _selected_tile == OverworldRules.hero_position(_session):
		actions = OverworldRules.get_context_actions(_session)
		actions = _promote_selected_owned_town_action(actions)
	else:
		var selected_signature := _selected_route_destination_action_signature()
		if _selected_context_actions_cache_signature == selected_signature:
			_profile_add("selected_context_actions_cache_hits", 1)
			_validation_profile["last_selected_context_actions_cache"] = {
				"status": "hit",
				"destination_only": true,
				"signature": selected_signature,
				"signature_mode": "destination_minimal",
				"action_count": _selected_context_actions_cache.size(),
			}
			_refresh_cache["context_actions"] = _selected_context_actions_cache
			_debug_phase_end("context_actions_computation", context_actions_started_usec, {
				"cached": true,
				"durable": true,
				"action_count": _selected_context_actions_cache.size(),
			})
			return _selected_context_actions_cache
		_profile_add("selected_context_actions_cache_misses", 1)
		actions = _selected_route_destination_actions()
		_selected_context_actions_cache = actions
		_selected_context_actions_cache_signature = selected_signature
		_validation_profile["last_selected_context_actions_cache"] = {
			"status": "miss",
			"destination_only": true,
			"signature": selected_signature,
			"signature_mode": "destination_minimal",
			"action_count": actions.size(),
		}
	_refresh_cache["context_actions"] = actions
	_debug_phase_end("context_actions_computation", context_actions_started_usec, {"cached": false, "action_count": actions.size()})
	return actions

func _build_selected_route_context_actions() -> Array:
	return _selected_route_destination_actions()

func _first_enabled_action(actions: Array) -> Dictionary:
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if String(action.get("id", "")) == "":
			continue
		if not bool(action.get("disabled", false)):
			return action
	return {}

func _promote_selected_owned_town_action(actions: Array) -> Array:
	var town_action := _selected_owned_town_visit_action()
	if town_action.is_empty():
		return actions
	var promoted: Array = [town_action]
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if String(action.get("id", "")) == String(town_action.get("id", "")):
			continue
		promoted.append(action)
	return promoted

func _selected_owned_town_visit_action() -> Dictionary:
	if not _is_selected_owned_town_visit_target():
		return {}
	var town_name := _selected_tile_destination_name()
	if town_name == "":
		town_name = "this town"
	var handoff := _town_entry_handoff_surface()
	var handoff_summary := String(handoff.get("summary_text", "")).strip_edges()
	return {
		"id": "visit_town",
		"label": "Visit Town",
		"summary": "Enter %s now to review construction, recruitment, market, and recovery orders. %s" % [
			town_name,
			handoff_summary,
		],
		"town_entry_handoff": handoff,
	}

func _is_selected_owned_town_visit_target() -> bool:
	if not _tile_in_bounds(_selected_tile):
		return false
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return false
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	return not town.is_empty() and String(town.get("owner", "neutral")) == "player"

func _town_entry_handoff_surface() -> Dictionary:
	if not _is_selected_owned_town_visit_target():
		return {}
	var town_name := _selected_tile_destination_name()
	if town_name == "":
		town_name = "this town"
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {})
	var movement_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", movement.get("current", 0))),
	]
	var field_position := "%d,%d" % [hero_pos.x, hero_pos.y]
	var summary := "Leave returns to the field at %s with %s; the day does not advance." % [
		field_position,
		movement_line,
	]
	var tooltip := "Town Entry Handoff\n- Enter: Visit Town opens %s management.\n- Field position: active hero remains at %s.\n- Movement: %s is preserved until spent on field movement.\n- Return: Leave returns to the overworld; the day does not advance.\n- State change: town inspection is safe until a town command is committed." % [
		town_name,
		field_position,
		movement_line,
	]
	return {
		"visible_text": "Town handoff: %s | Leave returns field" % _short_action_label(town_name, 20),
		"tooltip_text": tooltip,
		"summary_text": summary,
		"town_name": town_name,
		"field_position": field_position,
		"movement_line": movement_line,
		"return_order": "Leave",
	}

func _current_primary_action() -> Dictionary:
	var primary_action_started_usec := _debug_phase_begin("primary_action_computation")
	if _refresh_cache.has("primary_action"):
		var cached_action: Dictionary = _refresh_cache["primary_action"]
		_debug_phase_end("primary_action_computation", primary_action_started_usec, {"cached": true, "action_id": String(cached_action.get("id", ""))})
		return cached_action
	var action := {}
	if _selected_tile != OverworldRules.hero_position(_session):
		action = _first_enabled_action(_selected_route_destination_actions())
	else:
		action = _first_enabled_action(_current_context_actions())
	_refresh_cache["primary_action"] = action
	_debug_phase_end("primary_action_computation", primary_action_started_usec, {"cached": false, "action_id": String(action.get("id", ""))})
	return action

func _cached_hero_actions() -> Array:
	var signature := _hero_actions_state_signature()
	if _hero_actions_cache_signature == signature:
		_profile_add("hero_actions_cache_hits", 1)
		_validation_profile["last_hero_actions_cache"] = {
			"status": "hit",
			"signature": signature,
			"action_count": _hero_actions_cache.size(),
		}
		return _hero_actions_cache

	_profile_add("hero_actions_cache_misses", 1)
	_hero_actions_cache = OverworldRules.get_hero_actions(_session)
	_hero_actions_cache_signature = _hero_actions_state_signature()
	_validation_profile["last_hero_actions_cache"] = {
		"status": "miss",
		"previous_signature": signature,
		"signature": _hero_actions_cache_signature,
		"action_count": _hero_actions_cache.size(),
	}
	return _hero_actions_cache

func _invalidate_hero_actions_cache(reason: String = "") -> void:
	_hero_actions_cache.clear()
	_hero_actions_cache_signature = ""
	if reason != "":
		_validation_profile["last_hero_actions_cache"] = {"status": "invalidated", "reason": reason}

func _hero_actions_state_signature() -> String:
	if _session == null:
		return "session:null"
	var overworld := _session.overworld
	var player_heroes: Array = overworld.get("player_heroes", []) if overworld.get("player_heroes", []) is Array else []
	var roster := []
	for index in range(player_heroes.size()):
		var hero_value = player_heroes[index]
		if hero_value is Dictionary:
			roster.append(_hero_actions_hero_signature(hero_value, index))
		else:
			roster.append({"index": index, "type": typeof(hero_value), "value": str(hero_value)})
	var payload := {
		"session_id": String(_session.session_id),
		"scenario_id": String(_session.scenario_id),
		"hero_id": String(_session.hero_id),
		"difficulty": String(_session.difficulty),
		"launch_mode": String(_session.launch_mode),
		"game_state": String(_session.game_state),
		"scenario_status": String(_session.scenario_status),
		"active_hero_id": String(overworld.get("active_hero_id", "")),
		"map": _hero_actions_map_identity_signature(),
		"hero_position": _hero_actions_position_signature(overworld.get("hero_position", {})),
		"movement": _hero_actions_movement_signature(overworld.get("movement", {})),
		"hero": _hero_actions_hero_signature(overworld.get("hero", {}) if overworld.get("hero", {}) is Dictionary else {}, -1),
		"roster": roster,
	}
	return JSON.stringify(payload)

func _hero_actions_map_identity_signature() -> Dictionary:
	var materialization = _session.flags.get("generated_random_map_materialization", {}) if _session != null else {}
	var generated_identity = _session.overworld.get("generated_random_map_identity", {}) if _session != null else {}
	return {
		"x": _map_size.x,
		"y": _map_size.y,
		"rows": _map_data.size(),
		"generated_materialized": String(materialization.get("materialized_map_signature", "")) if materialization is Dictionary else "",
		"generated_identity": String(generated_identity.get("materialized_map_signature", "")) if generated_identity is Dictionary else "",
	}

func _hero_actions_hero_signature(hero: Dictionary, index: int) -> Dictionary:
	var spellbook = hero.get("spellbook", {})
	var mana = spellbook.get("mana", {}) if spellbook is Dictionary else {}
	return {
		"index": index,
		"id": String(hero.get("id", "")),
		"name": String(hero.get("name", "")),
		"faction_id": String(hero.get("faction_id", "")),
		"archetype": String(hero.get("archetype", "")),
		"roster_summary": String(hero.get("roster_summary", "")),
		"is_primary": bool(hero.get("is_primary", false)),
		"position": _hero_actions_position_signature(hero.get("position", {})),
		"movement": _hero_actions_movement_signature(hero.get("movement", {})),
		"level": int(hero.get("level", 1)),
		"experience": int(hero.get("experience", 0)),
		"next_level_experience": int(hero.get("next_level_experience", 0)),
		"specialties": _hero_actions_string_array(hero.get("specialties", [])),
		"pending_specialty_choices": _hero_actions_string_array(hero.get("pending_specialty_choices", [])),
		"specialty_focus_ids": _hero_actions_string_array(hero.get("specialty_focus_ids", [])),
		"base_movement": int(hero.get("base_movement", 0)),
		"base_scouting_radius": int(hero.get("base_scouting_radius", 0)),
		"mana": _hero_actions_mana_signature(mana),
		"army": _hero_actions_army_signature(hero.get("army", {})),
		"command": _hero_actions_command_signature(hero.get("command", {})),
		"artifacts": var_to_str(hero.get("artifacts", {})),
		"artifact_ids": _hero_actions_string_array(hero.get("artifact_ids", [])),
	}

func _hero_actions_position_signature(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {"x": int(value.get("x", 0)), "y": int(value.get("y", 0))}
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	return {"x": 0, "y": 0}

func _hero_actions_movement_signature(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {"current": int(value.get("current", 0)), "max": int(value.get("max", 0))}
	return {"current": 0, "max": 0}

func _hero_actions_mana_signature(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {"current": int(value.get("current", 0)), "max": int(value.get("max", 0))}
	return {"current": 0, "max": 0}

func _hero_actions_army_signature(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"id": "", "name": "", "stacks": []}
	var army: Dictionary = value
	var stacks := []
	var source_stacks: Array = army.get("stacks", []) if army.get("stacks", []) is Array else []
	for stack_value in source_stacks:
		if stack_value is Dictionary:
			var stack: Dictionary = stack_value
			stacks.append({
				"unit_id": String(stack.get("unit_id", "")),
				"count": int(stack.get("count", 0)),
			})
		else:
			stacks.append(str(stack_value))
	return {
		"id": String(army.get("id", "")),
		"name": String(army.get("name", "")),
		"stacks": stacks,
	}

func _hero_actions_command_signature(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {
			"attack": int(value.get("attack", 0)),
			"defense": int(value.get("defense", 0)),
			"power": int(value.get("power", 0)),
			"knowledge": int(value.get("knowledge", 0)),
		}
	return {"attack": 0, "defense": 0, "power": 0, "knowledge": 0}

func _hero_actions_string_array(value: Variant) -> Array:
	var items := []
	if not (value is Array):
		return items
	for item in value:
		items.append(String(item))
	return items

func _command_check_surface() -> Dictionary:
	var hero: Dictionary = _session.overworld.get("hero", {}) if _session.overworld.get("hero", {}) is Dictionary else {}
	var active_name := String(hero.get("name", "Commander")).strip_edges()
	if active_name == "":
		active_name = "Commander"
	var movement: Dictionary = _session.overworld.get("movement", {}) if _session.overworld.get("movement", {}) is Dictionary else {}
	var movement_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", movement.get("current", 0))),
	]
	var actions: Array = _cached_hero_actions()
	var roster_count: int = actions.size()
	var reserve_count: int = maxi(0, roster_count - 1)
	var switchable_count := 0
	var first_switch_label := ""
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			continue
		switchable_count += 1
		if first_switch_label == "":
			first_switch_label = String(action.get("label", "reserve commander")).trim_prefix("Command ").strip_edges()
	var readiness := "Solo command"
	var switch_line := "No reserve switch is available."
	var next_step := "Keep %s active and select a visible destination." % active_name
	if switchable_count > 0:
		readiness = "%d reserve%s ready" % [switchable_count, "" if switchable_count == 1 else "s"]
		switch_line = "Switch ready: %s." % first_switch_label
		next_step = "Open Command and choose %s if that commander should take the next field order." % first_switch_label
	else:
		var primary_action := _current_primary_action()
		if not primary_action.is_empty() and not bool(primary_action.get("disabled", false)):
			next_step = "Keep %s active and commit %s when ready." % [
				active_name,
				String(primary_action.get("label", "the primary order")),
			]
	var roster_line := "%d commander%s, %d reserve%s" % [
		roster_count,
		"" if roster_count == 1 else "s",
		reserve_count,
		"" if reserve_count == 1 else "s",
	]
	var visible := "Command check: %s | %s | %s" % [
		_short_action_label(active_name, 18),
		readiness,
		movement_line,
	]
	var tooltip := "Command Check\n- Active: %s\n- Roster: %s\n- Readiness: %s | %s\n- Switch: %s\n- Next practical action: %s\n- State change: choosing a reserve makes that commander active; inspection alone does not spend movement or end the day." % [
		active_name,
		roster_line,
		readiness,
		movement_line,
		switch_line,
		next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"active_name": active_name,
		"roster_count": roster_count,
		"reserve_count": reserve_count,
		"switchable_count": switchable_count,
		"readiness": readiness,
		"movement_line": movement_line,
		"switch_line": switch_line,
		"next_step": next_step,
	}

func _hero_switch_check_surface(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}
	var label := String(action.get("label", "Command")).trim_prefix("Command ").strip_edges()
	if label == "":
		label = String(action.get("label", "Commander")).strip_edges()
	var summary := String(action.get("summary", "")).strip_edges()
	var disabled := bool(action.get("disabled", false))
	var readiness := "active now" if disabled else "switch ready"
	var next_step := "Already active; keep planning from this commander's current field position." if disabled else "Select this command to make %s the active field commander." % label
	var tooltip := "Command Switch Check\n- Target: %s\n- Readiness: %s\n- Summary: %s\n- Next practical action: %s\n- State change: switching changes the active commander; it does not end the day by itself." % [
		label,
		readiness,
		summary if summary != "" else "No roster summary available.",
		next_step,
	]
	return {
		"tooltip_text": tooltip,
		"target_label": label,
		"readiness": readiness,
		"summary": summary,
		"next_step": next_step,
	}

func _cached_spell_actions() -> Array:
	if not _refresh_cache.has("spell_actions"):
		_refresh_cache["spell_actions"] = OverworldRules.get_spell_actions(_session)
	return _refresh_cache["spell_actions"]

func _spell_check_surface() -> Dictionary:
	var hero: Dictionary = _session.overworld.get("hero", {}) if _session.overworld.get("hero", {}) is Dictionary else {}
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	var mana: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	var mana_line := "Mana %d/%d" % [
		int(mana.get("current", 0)),
		int(mana.get("max", mana.get("current", 0))),
	]
	var movement: Dictionary = _session.overworld.get("movement", {}) if _session.overworld.get("movement", {}) is Dictionary else {}
	var movement_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", movement.get("current", 0))),
	]
	var actions: Array = _cached_spell_actions()
	if actions.is_empty():
		return {
			"visible_text": "Spell check: no field spell | %s" % mana_line,
			"tooltip_text": "Spell Check\n- Spellbook: no known field spell.\n- Mana: %s\n- Movement: %s\n- Next practical action: use map orders; no field spell can be cast from this command drawer." % [
				mana_line,
				movement_line,
			],
			"readiness": "no field spell",
			"mana_line": mana_line,
			"movement_line": movement_line,
			"ready_count": 0,
			"spell_count": 0,
		}

	var ready_count := 0
	var blocked_count := 0
	var best_action: Dictionary = {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if not bool(action.get("disabled", false)):
			ready_count += 1
			if best_action.is_empty():
				best_action = action
		else:
			blocked_count += 1
			if best_action.is_empty():
				best_action = action
	if best_action.is_empty():
		best_action = actions[0] if actions[0] is Dictionary else {}
	var spell_name := _spell_action_name(best_action)
	var readiness := "Ready x%d/%d" % [ready_count, actions.size()] if ready_count > 0 else "Blocked x0/%d" % actions.size()
	var action_readiness := String(best_action.get("readiness", readiness)).strip_edges()
	if action_readiness == "":
		action_readiness = readiness
	var next_step := "Open Command and cast %s when route tempo matters." % spell_name
	if ready_count <= 0:
		var invalid_reason := String(best_action.get("invalid_reason", "")).strip_edges()
		if invalid_reason == "":
			invalid_reason = action_readiness
		next_step = "Resolve %s before casting %s." % [invalid_reason.to_lower(), spell_name]
	var tooltip := "Spell Check\n- Mana: %s\n- Movement: %s\n- Field spells: %d ready, %d blocked.\n- Best spell: %s\n- Readiness: %s\n- Target: %s\n- Effect: %s\n- Best use: %s\n- Next practical action: %s" % [
		mana_line,
		movement_line,
		ready_count,
		blocked_count,
		spell_name,
		action_readiness,
		String(best_action.get("target_requirement", best_action.get("target", "No map target"))),
		String(best_action.get("effect", "No effect summary available.")),
		String(best_action.get("best_use", "Use when the field state supports it.")),
		next_step,
	]
	return {
		"visible_text": "Spell check: %s | %s | %s" % [
			readiness,
			_short_action_label(spell_name, 18),
			movement_line,
		],
		"tooltip_text": tooltip,
		"readiness": readiness,
		"action_readiness": action_readiness,
		"best_spell": spell_name,
		"ready_count": ready_count,
		"blocked_count": blocked_count,
		"spell_count": actions.size(),
		"mana_line": mana_line,
		"movement_line": movement_line,
		"next_step": next_step,
	}

func _spell_action_check_surface(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}
	var spell_name := _spell_action_name(action)
	var readiness := String(action.get("readiness", "")).strip_edges()
	if readiness == "":
		readiness = "Ready" if not bool(action.get("disabled", false)) else "Blocked"
	var mana_line := String(action.get("mana_state", "")).strip_edges()
	if mana_line == "":
		mana_line = String(_spell_check_surface().get("mana_line", "Mana unavailable"))
	var target := String(action.get("target_requirement", action.get("target", "No map target"))).strip_edges()
	if target == "":
		target = "No map target"
	var effect := String(action.get("effect", action.get("consequence", ""))).strip_edges()
	if effect == "":
		effect = "No effect summary available."
	var why_cast := String(action.get("why_cast", action.get("best_use", ""))).strip_edges()
	if why_cast == "":
		why_cast = "Use when the field state supports it."
	var next_step := "Cast now from Command when the field order needs this effect."
	if bool(action.get("disabled", false)):
		var invalid_reason := String(action.get("invalid_reason", "")).strip_edges()
		if invalid_reason == "":
			invalid_reason = readiness
		next_step = "Resolve %s before casting." % invalid_reason.to_lower()
	var tooltip := "Spell Cast Check\n- Spell: %s\n- Readiness: %s\n- Mana: %s\n- Target: %s\n- Effect: %s\n- Why cast: %s\n- Next practical action: %s\n- State change: casting spends mana and updates the field state; inspection alone changes nothing." % [
		spell_name,
		readiness,
		mana_line,
		target,
		effect,
		why_cast,
		next_step,
	]
	return {
		"tooltip_text": tooltip,
		"spell_name": spell_name,
		"readiness": readiness,
		"mana_line": mana_line,
		"target": target,
		"effect": effect,
		"why_cast": why_cast,
		"next_step": next_step,
	}

func _spell_action_name(action: Dictionary) -> String:
	var spell_name := String(action.get("spell_name", "")).strip_edges()
	if spell_name != "":
		return spell_name
	var label := String(action.get("label", "Field spell")).strip_edges()
	if label.begins_with("Cast "):
		label = label.trim_prefix("Cast ").strip_edges()
	var cost_start := label.find(" (")
	if cost_start >= 0:
		label = label.left(cost_start).strip_edges()
	return label if label != "" else "Field spell"

func _cached_specialty_actions() -> Array:
	if not _refresh_cache.has("specialty_actions"):
		_refresh_cache["specialty_actions"] = OverworldRules.get_specialty_actions(_session)
	return _refresh_cache["specialty_actions"]

func _specialty_check_surface() -> Dictionary:
	var hero: Dictionary = _session.overworld.get("hero", {}) if _session.overworld.get("hero", {}) is Dictionary else {}
	var active_name := String(hero.get("name", "Commander")).strip_edges()
	if active_name == "":
		active_name = "Commander"
	var movement: Dictionary = _session.overworld.get("movement", {}) if _session.overworld.get("movement", {}) is Dictionary else {}
	var movement_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", movement.get("current", 0))),
	]
	var build_summary := HeroProgressionRules.brief_summary(hero)
	var pending_count := HeroProgressionRules.pending_choices_remaining(hero)
	var actions: Array = _cached_specialty_actions()
	if pending_count <= 0 or actions.is_empty():
		var visible := "Specialty check: no pick | %s | %s" % [
			_short_action_label(build_summary, 22),
			movement_line,
		]
		var tooltip := "Specialty Check\n- Active: %s\n- Current build: %s\n- Readiness: no pending specialty pick.\n- Movement: %s\n- Next practical action: keep resolving field goals; a new specialty pick appears after a level gain.\n- State change: inspection alone does not change the commander build, spend movement, or end the day." % [
			active_name,
			build_summary,
			movement_line,
		]
		return {
			"visible_text": visible,
			"tooltip_text": tooltip,
			"active_name": active_name,
			"build_summary": build_summary,
			"pending_count": 0,
			"option_count": 0,
			"readiness": "no pending specialty pick",
			"movement_line": movement_line,
			"next_step": "Keep resolving field goals until a level gain offers a specialty pick.",
		}

	var pending_choice := HeroProgressionRules.current_pending_choice(hero)
	var option_summary := HeroProgressionRules.pending_choice_summary(pending_choice)
	var first_action: Dictionary = {}
	for action_value in actions:
		if action_value is Dictionary:
			first_action = action_value
			break
	var first_label := _specialty_action_choice_label(first_action)
	var readiness := "%d pick%s ready" % [pending_count, "" if pending_count == 1 else "s"]
	var next_step := "Open Command and choose %s for the waiting level-up pick." % first_label
	var visible := "Specialty check: %s | %s | %s" % [
		readiness,
		_short_action_label(option_summary, 22),
		movement_line,
	]
	var tooltip := "Specialty Check\n- Active: %s\n- Current build: %s\n- Readiness: %s at Level %d.\n- Options: %s\n- Movement: %s\n- Next practical action: %s\n- State change: choosing a specialty updates the commander build; inspection alone changes nothing." % [
		active_name,
		build_summary,
		readiness,
		int(pending_choice.get("level", int(hero.get("level", 1)))),
		option_summary if option_summary != "" else "specialty options are waiting",
		movement_line,
		next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"active_name": active_name,
		"build_summary": build_summary,
		"pending_count": pending_count,
		"option_count": actions.size(),
		"readiness": readiness,
		"options": option_summary,
		"movement_line": movement_line,
		"next_step": next_step,
		"level": int(pending_choice.get("level", int(hero.get("level", 1)))),
	}

func _specialty_action_check_surface(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}
	var hero: Dictionary = _session.overworld.get("hero", {}) if _session.overworld.get("hero", {}) is Dictionary else {}
	var active_name := String(hero.get("name", "Commander")).strip_edges()
	if active_name == "":
		active_name = "Commander"
	var label := _specialty_action_choice_label(action)
	var summary := String(action.get("summary", "")).strip_edges()
	var effect := _specialty_action_effect_text(action)
	var readiness := "pick ready" if not bool(action.get("disabled", false)) else "blocked"
	var next_step := "Select this specialty to apply it to %s." % active_name
	if bool(action.get("disabled", false)):
		next_step = "Resolve the listed blocker before choosing this specialty."
	var tooltip := "Specialty Pick Check\n- Choice: %s\n- Readiness: %s\n- Current build: %s\n- Effect: %s\n- Next practical action: %s\n- State change: choosing this specialty updates the commander build; inspection alone changes nothing." % [
		label,
		readiness,
		HeroProgressionRules.brief_summary(hero),
		effect,
		next_step,
	]
	return {
		"tooltip_text": tooltip,
		"choice_label": label,
		"readiness": readiness,
		"summary": summary,
		"effect": effect,
		"next_step": next_step,
	}

func _specialty_action_choice_label(action: Dictionary) -> String:
	var label := String(action.get("label", "Choose Specialty")).strip_edges()
	if label.begins_with("Choose "):
		label = label.trim_prefix("Choose ").strip_edges()
	return label if label != "" else "Specialty"

func _specialty_action_effect_text(action: Dictionary) -> String:
	var summary := String(action.get("summary", "")).strip_edges()
	if summary == "":
		return "Applies the selected specialty bonus."
	var separator := summary.find("|")
	if separator >= 0 and separator + 1 < summary.length():
		return summary.substr(separator + 1).strip_edges()
	return summary

func _cached_artifact_actions() -> Array:
	if not _refresh_cache.has("artifact_actions"):
		_refresh_cache["artifact_actions"] = OverworldRules.get_artifact_actions(_session)
	return _refresh_cache["artifact_actions"]

func _cached_active_context() -> Dictionary:
	if not _refresh_cache.has("active_context"):
		_refresh_cache["active_context"] = OverworldRules.get_active_context(_session)
	return _refresh_cache["active_context"]

func _cached_focus_tile_text() -> String:
	if not _refresh_cache.has("focus_tile_text"):
		_refresh_cache["focus_tile_text"] = _describe_focus_tile()
	return String(_refresh_cache["focus_tile_text"])

func _cached_active_context_text() -> String:
	if not _refresh_cache.has("active_context_text"):
		_refresh_cache["active_context_text"] = OverworldRules.describe_context(_session)
	return String(_refresh_cache["active_context_text"])

func _cached_objective_text() -> String:
	if not _refresh_cache.has("objective_text"):
		_refresh_cache["objective_text"] = OverworldRules.describe_objectives(_session)
	return String(_refresh_cache["objective_text"])

func _cached_frontier_threats() -> String:
	if not _refresh_cache.has("frontier_threats"):
		# Validation anchor: OverworldRules.describe_enemy_threats still maps to this frontier surface.
		_refresh_cache["frontier_threats"] = OverworldRules.describe_frontier_threats(_session)
	return String(_refresh_cache["frontier_threats"])

func _cached_command_risk_surface() -> Dictionary:
	if not _refresh_cache.has("command_risk_surface"):
		_refresh_cache["command_risk_surface"] = OverworldRules.describe_command_risk_surfaces(_session)
	return _refresh_cache["command_risk_surface"]

func _refresh_primary_action_button(action: Dictionary) -> void:
	if action.is_empty():
		_primary_action_button.text = "Select Site"
		_primary_action_button.disabled = true
		var route_decision := _selected_route_decision_surface()
		var route_tooltip := _route_decision_tooltip(route_decision)
		_primary_action_button.tooltip_text = route_tooltip if route_tooltip != "" else "Select a visible destination or stand on a site to reveal its primary order."
		return

	_primary_action_button.text = "%s [Enter]" % _short_action_label(String(action.get("label", "Action")), 22)
	_primary_action_button.disabled = bool(action.get("disabled", false))
	var summary := String(action.get("summary", ""))
	if summary == "":
		summary = "Commit %s." % String(action.get("label", "the primary order")).to_lower()
	var commit_check := _primary_order_commit_check_surface(action)
	var active_site_order := _active_site_order_surface(action)
	_primary_action_button.tooltip_text = _join_tooltip_sections([
		summary,
		String(active_site_order.get("tooltip_text", "")),
		String(_town_entry_handoff_surface().get("tooltip_text", "")),
		String(commit_check.get("tooltip_text", "")),
		"Press Enter or Space to commit this order.",
	])

func _activate_primary_action() -> bool:
	var activation_started_usec := _debug_phase_begin("primary_action_activation")
	var action := _current_primary_action()
	if action.is_empty() or bool(action.get("disabled", false)):
		_debug_phase_end("primary_action_activation", activation_started_usec, {"activated": false, "reason": "empty_or_disabled"})
		return false
	var action_id := String(action.get("id", ""))
	if action_id == "":
		_debug_phase_end("primary_action_activation", activation_started_usec, {"activated": false, "reason": "missing_action_id"})
		return false
	_on_context_action_pressed(action_id)
	_debug_phase_end("primary_action_activation", activation_started_usec, {"activated": true, "action_id": action_id})
	return true

func _primary_order_commit_check_surface(action: Dictionary = {}) -> Dictionary:
	var primary_action := action
	if primary_action.is_empty():
		primary_action = _current_primary_action()
	if primary_action.is_empty():
		return {}
	var label := String(primary_action.get("label", "Primary order")).strip_edges()
	if label == "":
		label = "Primary order"
	var action_id := String(primary_action.get("id", "")).strip_edges()
	var route_value: Variant = primary_action.get("route_decision", {})
	var route_decision: Dictionary = route_value if route_value is Dictionary else {}
	if route_decision.is_empty():
		route_decision = _selected_route_decision_surface()
	var destination := String(route_decision.get("destination", _selected_tile_destination_name())).strip_edges()
	if destination == "":
		destination = "selected context" if _selected_tile != OverworldRules.hero_position(_session) else "current tile"
	var movement = _session.overworld.get("movement", {})
	var movement_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", movement.get("current", 0))),
	]
	var readiness := "ready"
	var affected := destination
	var why := String(primary_action.get("summary", "")).strip_edges()
	var next_step := "Press Enter or Space to commit %s." % label
	if not route_decision.is_empty():
		readiness = _route_decision_status_label(route_decision)
		var route_movement := String(_route_target_handoff_surface(route_decision).get("movement_line", "")).strip_edges()
		if route_movement != "":
			movement_line = route_movement
		var brief := _route_decision_brief(route_decision)
		affected = String(brief.get("affected", affected)).strip_edges()
		why = String(brief.get("why_it_matters", why)).strip_edges()
		next_step = String(brief.get("next_step", next_step)).strip_edges()
	if why == "":
		why = "This order changes the next field commitment."
	var confirmation := "Enter/Space commits this order from the primary button."
	if bool(primary_action.get("disabled", false)):
		confirmation = "This order is unavailable; inspect the selected context or choose another route."
	elif action_id in ["advance_route", "march_selected"]:
		confirmation = "Enter/Space spends movement along this route as far as today's budget allows."
	elif action_id == "enter_battle":
		confirmation = "Enter/Space opens the battle handoff for this encounter."
	elif action_id == "visit_town":
		confirmation = "Enter/Space enters the town without ending the day."
	elif action_id == "collect_resource":
		confirmation = "Enter/Space resolves the site order and updates the field state."
	elif action_id == "collect_artifact":
		confirmation = "Enter/Space recovers the artifact for the active commander."
	var tooltip := "Primary Order Check\n- Commit: %s\n- Target: %s\n- Readiness: %s | %s\n- Affected: %s\n- Why it matters: %s\n- Next: %s\n- Confirmation: %s" % [
		label,
		destination,
		readiness,
		movement_line,
		affected,
		why,
		next_step,
		confirmation,
	]
	return {
		"visible_text": "Order check: %s | %s | %s" % [
			_short_action_label(label, 18),
			_short_action_label(destination, 18),
			readiness,
		],
		"tooltip_text": tooltip,
		"commit_label": label,
		"target": destination,
		"readiness": readiness,
		"movement_line": movement_line,
		"affected": affected,
		"why_it_matters": why,
		"next_step": next_step,
		"confirmation": confirmation,
	}

func _active_site_order_surface(action: Dictionary = {}) -> Dictionary:
	if _selected_tile != OverworldRules.hero_position(_session):
		return {}
	var primary_action := action
	if primary_action.is_empty():
		primary_action = _current_primary_action()
	if primary_action.is_empty():
		return {}
	var action_id := String(primary_action.get("id", "")).strip_edges()
	if action_id not in ["collect_resource", "collect_artifact", "enter_battle", "capture_town", "site_response"]:
		return {}
	var active_context := _cached_active_context()
	var context_type := String(active_context.get("type", "")).strip_edges()
	if context_type == "" or context_type == "empty":
		return {}
	var label := String(primary_action.get("label", "Resolve Site")).strip_edges()
	if label == "":
		label = "Resolve Site"
	var target := _active_site_order_target_label(active_context)
	if target == "":
		target = "current tile"
	var movement = _session.overworld.get("movement", {})
	var movement_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", movement.get("current", 0))),
	]
	var readiness := "Ready"
	if bool(primary_action.get("disabled", false)):
		readiness = "Blocked"
	var affected := String(primary_action.get("summary", "")).strip_edges()
	if affected == "":
		affected = "This current-tile order changes the field state."
	var next_step := _active_site_order_next_step(action_id, label)
	var tooltip := "Active Site Handoff\n- Current tile: %s\n- Order: %s\n- Readiness: %s | %s\n- Affected: %s\n- Next: %s\n- State change: Enter/Space commits this current-tile order; inspection alone does not spend movement." % [
		target,
		label,
		readiness,
		movement_line,
		affected,
		next_step,
	]
	return {
		"visible_text": "Site handoff: %s | %s | %s" % [
			_short_action_label(target, 22),
			_short_action_label(label, 18),
			readiness,
		],
		"tooltip_text": tooltip,
		"context_type": context_type,
		"action_id": action_id,
		"target_label": target,
		"order_label": label,
		"readiness": readiness,
		"movement_line": movement_line,
		"affected": affected,
		"next_step": next_step,
	}

func _active_site_order_target_label(active_context: Dictionary) -> String:
	match String(active_context.get("type", "")):
		"resource":
			var node: Dictionary = active_context.get("node", {}) if active_context.get("node", {}) is Dictionary else {}
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			return String(site.get("name", node.get("placement_id", "Resource site")))
		"artifact":
			var artifact_node: Dictionary = active_context.get("node", {}) if active_context.get("node", {}) is Dictionary else {}
			return ArtifactRules.artifact_name(String(artifact_node.get("artifact_id", "")))
		"encounter":
			var encounter: Dictionary = active_context.get("encounter", {}) if active_context.get("encounter", {}) is Dictionary else {}
			return OverworldRules.encounter_display_name(encounter)
		"town":
			var town: Dictionary = active_context.get("town", {}) if active_context.get("town", {}) is Dictionary else {}
			return String(town.get("name", town.get("placement_id", "Town")))
		_:
			return ""

func _active_site_order_next_step(action_id: String, label: String) -> String:
	match action_id:
		"collect_resource":
			return "Resolve %s, then review the claim recap before ending the day." % label
		"collect_artifact":
			return "Recover the artifact, then check the commander gear rail."
		"enter_battle":
			return "Open the battle handoff and resolve the hostile contact."
		"capture_town":
			return "Commit the town assault or claim order before planning the next field move."
		"site_response":
			return "Dispatch the response order, then watch the route and end-turn forecast."
		_:
			return "Commit the current-tile order before ending the day."

func _selected_tile_movement_action() -> Dictionary:
	if not _tile_in_bounds(_selected_tile):
		return {}
	if OverworldRules.tile_is_blocked(_session, _selected_tile.x, _selected_tile.y):
		return {}

	var hero_pos = OverworldRules.hero_position(_session)
	if _is_adjacent_move_target(hero_pos, _selected_tile):
		var route_decision := _selected_route_decision_surface()
		return {
			"id": "march_selected",
			"label": _selected_tile_order_label(true),
			"summary": _selected_tile_order_summary(true),
			"route_decision": route_decision,
		}

	var route = _selected_route()
	if route.size() > 1:
		var route_decision := _selected_route_decision_surface()
		return {
			"id": "advance_route",
			"label": _selected_tile_order_label(false),
			"summary": "%s %s" % [
				_selected_tile_order_summary(false),
				_route_decision_tooltip(route_decision),
			],
			"route_decision": route_decision,
		}
	return {}

func _selected_route_destination_actions() -> Array:
	var signature := _selected_route_destination_action_signature()
	if _selected_route_destination_actions_cache_signature == signature:
		_profile_add("selected_route_destination_action_cache_hits", 1)
		_validation_profile["last_selected_route_destination_action_cache"] = {
			"status": "hit",
			"signature": signature,
			"signature_mode": "destination_minimal",
			"action_count": _selected_route_destination_actions_cache.size(),
		}
		return _selected_route_destination_actions_cache
	_profile_add("selected_route_destination_action_cache_misses", 1)
	var actions := _build_selected_route_destination_actions()
	signature = _selected_route_destination_action_signature()
	_selected_route_destination_actions_cache = actions
	_selected_route_destination_actions_cache_signature = signature
	_validation_profile["last_selected_route_destination_action_cache"] = {
		"status": "miss",
		"signature": signature,
		"signature_mode": "destination_minimal",
		"action_count": actions.size(),
	}
	return actions

func _build_selected_route_destination_actions() -> Array:
	var destination := _selected_route_destination_interaction_surface()
	var route_decision: Dictionary = destination.get("route_decision", {}) if destination.get("route_decision", {}) is Dictionary else {}
	var kind := String(destination.get("kind", "open"))
	var status := String(destination.get("status", ""))
	if kind == "current":
		return [_disabled_route_destination_action("hold_position", "Current Position", "The selected destination is the active hero's current tile.", route_decision, destination)]
	if status in ["blocked", "out_of_bounds"]:
		var reason := String(destination.get("blocked_reason", "")).strip_edges()
		if reason == "":
			reason = "No clear route from the active hero."
		return [_disabled_route_destination_action("route_blocked", "Route Blocked", reason, route_decision, destination)]
	var route: Array = destination.get("route_tiles", []) if destination.get("route_tiles", []) is Array else []
	if route.size() <= 1:
		return [_disabled_route_destination_action("route_unavailable", "No Route", "No clear route from the active hero.", route_decision, destination)]
	var adjacent := bool(destination.get("adjacent", false))
	var action := {
		"id": "march_selected" if adjacent else "advance_route",
		"label": _selected_route_destination_action_label(destination, adjacent),
		"summary": _selected_route_destination_action_summary(destination, adjacent),
		"route_decision": route_decision,
		"destination_interaction": destination,
		"destination_only": true,
	}
	if status == "no_movement":
		action["disabled"] = true
	return [action]

func _disabled_route_destination_action(
	action_id: String,
	label: String,
	summary: String,
	route_decision: Dictionary,
	destination: Dictionary
) -> Dictionary:
	return {
		"id": action_id,
		"label": label,
		"summary": summary,
		"disabled": true,
		"route_decision": route_decision,
		"destination_interaction": destination,
		"destination_only": true,
	}

func _selected_route_destination_action_label(destination: Dictionary, adjacent: bool) -> String:
	match String(destination.get("kind", "open")):
		"town":
			return "Visit Town" if String(destination.get("owner", "")) == "player" else ("Approach Town" if adjacent else "Advance to Town")
		"resource":
			if adjacent:
				return String(destination.get("interaction_label", "Secure Site"))
			return "Advance to Site"
		"artifact":
			return "Recover Artifact" if adjacent else "Advance to Artifact"
		"encounter":
			return "Enter Battle" if adjacent else "Advance to Battle"
		_:
			return "March" if adjacent else "Advance"

func _selected_route_destination_action_summary(destination: Dictionary, adjacent: bool) -> String:
	var route_decision: Dictionary = destination.get("route_decision", {}) if destination.get("route_decision", {}) is Dictionary else {}
	var route_text := _route_decision_tooltip(route_decision)
	var interaction_summary := String(destination.get("summary", "")).strip_edges()
	if interaction_summary == "":
		interaction_summary = _selected_tile_order_summary(adjacent)
	if route_text == "":
		return interaction_summary
	return "%s %s" % [interaction_summary, route_text]

func _selected_route_destination_interaction_surface() -> Dictionary:
	var route_decision := _selected_route_decision_surface()
	var route_state := _ensure_selected_route_state("destination_action")
	var route: Array = route_state.get("route_tiles", []) if route_state.get("route_tiles", []) is Array else []
	var hero_pos := OverworldRules.hero_position(_session)
	var status := String(route_decision.get("status", ""))
	var destination := {
		"kind": "open",
		"status": "ready",
		"route_status": status,
		"x": _selected_tile.x,
		"y": _selected_tile.y,
		"adjacent": _is_adjacent_move_target(hero_pos, _selected_tile),
		"route_tiles": route,
		"route_decision": route_decision,
		"blocked_reason": String(route_decision.get("blocked_reason", "")),
		"summary": "",
	}
	if not _tile_in_bounds(_selected_tile):
		destination["kind"] = "invalid"
		destination["status"] = "out_of_bounds"
		return destination
	if _selected_tile == hero_pos:
		destination["kind"] = "current"
		destination["status"] = "hold"
		return destination
	if status in ["blocked", "no_movement"]:
		destination["status"] = status
		return destination
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		destination["kind"] = "town"
		destination["owner"] = String(town.get("owner", "neutral"))
		destination["placement_id"] = String(town.get("placement_id", ""))
		destination["summary"] = _selected_tile_order_summary(bool(destination.get("adjacent", false)))
		return destination
	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		destination["kind"] = "resource"
		destination["placement_id"] = String(node.get("placement_id", ""))
		destination["site_id"] = String(node.get("site_id", ""))
		destination["interaction_label"] = _resource_site_action_label_for_destination(node, site)
		destination["summary"] = _selected_tile_order_summary(bool(destination.get("adjacent", false)))
		return destination
	var artifact_node := _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		destination["kind"] = "artifact"
		destination["artifact_id"] = String(artifact_node.get("artifact_id", ""))
		destination["summary"] = _selected_tile_order_summary(bool(destination.get("adjacent", false)))
		return destination
	var encounter := _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		destination["kind"] = "encounter"
		destination["placement_id"] = String(encounter.get("placement_id", encounter.get("id", "")))
		destination["summary"] = _selected_tile_order_summary(bool(destination.get("adjacent", false)))
		return destination
	return destination

func _resource_site_action_label_for_destination(node: Dictionary, site: Dictionary) -> String:
	if bool(site.get("persistent_control", false)) and String(node.get("collected_by_faction_id", "")) == "player":
		return "Enter Site"
	return _selected_tile_order_label(true)

func _selected_route_decision_surface() -> Dictionary:
	var decision_started_usec := _debug_phase_begin("route_decision_construction")
	if _refresh_cache.has("selected_route_decision_surface"):
		var cached_surface: Dictionary = _refresh_cache["selected_route_decision_surface"]
		_debug_phase_end("route_decision_construction", decision_started_usec, {
			"cached": true,
			"status": String(cached_surface.get("status", "")),
			"steps": int(cached_surface.get("steps", 0)),
			"action_kind": String(cached_surface.get("action_kind", "")),
		})
		return cached_surface
	var decision_signature := _selected_route_action_surface_signature()
	if _selected_route_decision_surface_cache_signature == decision_signature:
		_profile_add("selected_route_decision_surface_cache_hits", 1)
		_validation_profile["last_selected_route_decision_surface_cache"] = {
			"status": "hit",
			"signature": decision_signature,
			"signature_mode": "destination_minimal",
			"action_kind": String(_selected_route_decision_surface_cache.get("action_kind", "")),
			"route_status": String(_selected_route_decision_surface_cache.get("status", "")),
			"steps": int(_selected_route_decision_surface_cache.get("steps", 0)),
		}
		_refresh_cache["selected_route_decision_surface"] = _selected_route_decision_surface_cache
		_debug_phase_end("route_decision_construction", decision_started_usec, {
			"cached": true,
			"durable": true,
			"status": String(_selected_route_decision_surface_cache.get("status", "")),
			"steps": int(_selected_route_decision_surface_cache.get("steps", 0)),
			"action_kind": String(_selected_route_decision_surface_cache.get("action_kind", "")),
		})
		return _selected_route_decision_surface_cache
	if not _tile_in_bounds(_selected_tile):
		_debug_phase_end("route_decision_construction", decision_started_usec, {"status": "out_of_bounds"})
		return {}
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {})
	var movement_current := int(movement.get("current", 0))
	var movement_max := int(movement.get("max", movement_current))
	var selected_is_hero := _selected_tile == hero_pos
	var explored := OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y)
	var visible := OverworldRules.is_tile_visible(_session, _selected_tile.x, _selected_tile.y)
	var blocked := OverworldRules.tile_is_blocked(_session, _selected_tile.x, _selected_tile.y)
	var destination_name := _selected_tile_destination_name()
	if destination_name == "":
		destination_name = "%d,%d" % [_selected_tile.x, _selected_tile.y]
	var route: Array = []
	var route_state: Dictionary = {}
	if not selected_is_hero and not blocked:
		route_state = _ensure_selected_route_state("decision")
		route = route_state.get("route_tiles", []) if route_state.get("route_tiles", []) is Array else []
	var steps: int = max(0, route.size() - 1)
	var preview: Dictionary = route_state.get("route_preview", {}) if route_state.get("route_preview", {}) is Dictionary else {}
	if preview.is_empty():
		preview = OverworldRules.route_movement_preview(_session, route, movement_current)
	var reachable_steps := int(preview.get("reachable_steps", 0))
	var unreachable_steps := int(preview.get("unreachable_steps", 0))
	var destination_reachable := bool(preview.get("destination_reachable", false))
	var movement_after_reachable := int(preview.get("movement_after_reachable", movement_current))
	var next_step := Vector2i(-1, -1)
	var next_step_label := ""
	var next_step_terrain := ""
	var next_step_line := ""
	var steps_after_next := 0
	if route.size() > 1 and route[1] is Vector2i:
		next_step = route[1]
		next_step_label = "%d,%d" % [next_step.x, next_step.y]
		next_step_terrain = _terrain_name_at(next_step.x, next_step.y)
		steps_after_next = max(0, steps - 1)
		var remaining_text := "arrives at target" if steps_after_next <= 0 else "%d step%s remains" % [
			steps_after_next,
			"" if steps_after_next == 1 else "s",
		]
		next_step_line = "Next step: %s via %s (%s)" % [
			next_step_label,
			next_step_terrain,
			remaining_text,
		]
	var adjacent: bool = _is_adjacent_move_target(hero_pos, _selected_tile)
	var action_kind := _selected_route_action_kind(adjacent)
	var action_label := _selected_tile_order_label(adjacent) if not selected_is_hero else "Hold"
	var movement_cost: int = steps if steps > 0 else 0
	var reachable_today: bool = steps > 0 and destination_reachable
	var route_clear: bool = steps > 0
	var status := "selected"
	var blocked_reason := ""
	if selected_is_hero:
		status = "current"
		action_kind = "hold"
		action_label = "Current Position"
		reachable_today = true
	elif blocked:
		status = "blocked"
		blocked_reason = "%s blocks travel." % _terrain_name_at(_selected_tile.x, _selected_tile.y)
	elif route_clear and movement_current <= 0:
		status = "no_movement"
		blocked_reason = "No movement left today."
	elif route_clear and reachable_today:
		status = "reachable"
	elif route_clear:
		status = "not_today"
		blocked_reason = "Route is clear; %d step%s remain after today's movement." % [
			unreachable_steps,
			"" if unreachable_steps == 1 else "s",
		]
	else:
		status = "blocked"
		blocked_reason = "No clear route from the active hero."
	var interception_surface := OverworldRules.describe_route_interception_surface(
		_session,
		_selected_tile.x,
		_selected_tile.y,
		steps,
		false
	)
	var remote_owned_town := _is_selected_owned_town_visit_target()
	if remote_owned_town:
		action_kind = "town"
		action_label = "Visit Town"
		status = "reachable"
		reachable_today = true
		route_clear = true
		blocked_reason = ""
		if steps <= 0:
			movement_cost = 0
	var surface := {
		"destination": destination_name,
		"x": _selected_tile.x,
		"y": _selected_tile.y,
		"action_kind": action_kind,
		"action_label": action_label,
		"status": status,
		"reachable_today": reachable_today,
		"route_clear": route_clear,
		"blocked_reason": blocked_reason,
		"steps": steps,
		"distance": steps,
		"movement_current": movement_current,
		"movement_max": movement_max,
		"movement_cost": movement_cost,
		"movement_after_order": movement_after_reachable if route_clear else max(0, movement_current - movement_cost),
		"total_cost": steps,
		"reachable_steps": reachable_steps,
		"reachable_cost": int(preview.get("reachable_cost", 0)),
		"unreachable_steps": unreachable_steps,
		"destination_reachable": destination_reachable,
		"route_preview": preview,
		"next_step": {
			"x": next_step.x,
			"y": next_step.y,
			"label": next_step_label,
			"terrain": next_step_terrain,
			"remaining_steps_after": steps_after_next,
		},
		"next_step_label": next_step_label,
		"next_step_terrain": next_step_terrain,
		"next_step_line": next_step_line,
		"remaining_steps_after_next": steps_after_next,
		"visible": visible,
		"explored": explored,
		"terrain": _terrain_name_at(_selected_tile.x, _selected_tile.y),
		"interception": interception_surface,
		"interception_active": bool(interception_surface.get("active", false)),
		"interception_cue": String(interception_surface.get("cue_text", "")),
		"interception_tooltip": String(interception_surface.get("tooltip_text", "")),
	}
	var decision_brief := _route_decision_brief(surface)
	surface["decision_brief"] = decision_brief
	surface["decision_brief_text"] = String(decision_brief.get("tooltip_text", ""))
	decision_signature = _selected_route_action_surface_signature()
	_refresh_cache["selected_route_decision_surface"] = surface
	_selected_route_decision_surface_cache = surface
	_selected_route_decision_surface_cache_signature = decision_signature
	_profile_add("selected_route_decision_surface_cache_misses", 1)
	_validation_profile["last_selected_route_decision_surface_cache"] = {
		"status": "miss",
		"signature": decision_signature,
		"signature_mode": "destination_minimal",
		"action_kind": action_kind,
		"route_status": status,
		"steps": steps,
	}
	_debug_phase_end("route_decision_construction", decision_started_usec, {"status": status, "steps": steps, "action_kind": action_kind})
	return surface

func _selected_route_action_kind(adjacent: bool) -> String:
	if not _tile_in_bounds(_selected_tile):
		return "select"
	if not _town_at(_selected_tile.x, _selected_tile.y).is_empty():
		return "town" if adjacent or _is_selected_owned_town_visit_target() else "move/town"
	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if adjacent:
			if bool(site.get("persistent_control", false)) and String(node.get("collected_by_faction_id", "")) == "player":
				return "enter"
			return "collect"
		return "move/collect"
	if not _artifact_node_at(_selected_tile.x, _selected_tile.y).is_empty():
		return "collect" if adjacent else "move/collect"
	if not _encounter_at(_selected_tile.x, _selected_tile.y).is_empty():
		return "enter" if adjacent else "move/enter"
	return "move"

func _route_decision_line(surface: Dictionary) -> String:
	if surface.is_empty():
		return ""
	var status := String(surface.get("status", ""))
	var steps := int(surface.get("steps", 0))
	var step_text := "%d step%s" % [steps, "" if steps == 1 else "s"] if steps > 0 else "no path"
	if status == "current":
		step_text = "current tile"
	var movement_current := int(surface.get("movement_current", 0))
	var movement_after := int(surface.get("movement_after_order", movement_current))
	var movement_text := "Move %d/%d" % [movement_current, int(surface.get("movement_max", movement_current))]
	if int(surface.get("movement_cost", 0)) > 0:
		movement_text = "Move %d->%d" % [movement_current, movement_after]
	var status_text := _route_decision_status_label(surface)
	var line := "Route: %s | %s | %s | %s | %s" % [
		_short_action_label(String(surface.get("destination", "Selected")), 22),
		String(surface.get("action_kind", "move")).capitalize(),
		step_text,
		status_text,
		movement_text,
	]
	var next_step_line := String(surface.get("next_step_line", "")).strip_edges()
	if next_step_line != "" and status != "current":
		line += " | %s" % next_step_line
	var reason := String(surface.get("blocked_reason", "")).strip_edges()
	if reason != "":
		line += " | %s" % reason
	var interception := _route_decision_interception(surface)
	if bool(interception.get("active", false)) and status != "current":
		line += " | Watch: %s" % _short_action_label(String(interception.get("cue_text", "")), 34)
	return line

func _route_decision_cue(surface: Dictionary) -> String:
	if surface.is_empty():
		return ""
	var status := String(surface.get("status", ""))
	if status == "current":
		return ""
	var destination := _short_action_label(String(surface.get("destination", "Selected")), 18)
	var movement_current := int(surface.get("movement_current", 0))
	var movement_after := int(surface.get("movement_after_order", movement_current))
	var movement_text := "%d/%d" % [movement_current, int(surface.get("movement_max", movement_current))]
	if int(surface.get("movement_cost", 0)) > 0:
		movement_text = "%d->%d" % [movement_current, movement_after]
	if status in ["blocked", "no_movement"]:
		return "Route: %s | %s | Move %s" % [destination, _route_decision_status_label(surface), movement_text]
	var next_step_label := String(surface.get("next_step_label", "")).strip_edges()
	var next_step_text := ""
	if next_step_label != "":
		next_step_text = " | Next %s" % next_step_label
	return "%s: %s | %d step%s | Move %s%s" % [
		String(surface.get("action_kind", "move")).capitalize(),
		destination,
		int(surface.get("steps", 0)),
		"" if int(surface.get("steps", 0)) == 1 else "s",
		movement_text,
		next_step_text,
	]

func _route_decision_tooltip(surface: Dictionary) -> String:
	var text_started_usec := _debug_phase_begin("route_text_generation")
	if surface.is_empty():
		_debug_phase_end("route_text_generation", text_started_usec, {"empty": true})
		return ""
	var line := _route_decision_line(surface)
	var reason := String(surface.get("blocked_reason", "")).strip_edges()
	var interception := _route_decision_interception(surface)
	var interception_tooltip := String(interception.get("tooltip_text", "")).strip_edges()
	var decision_brief := _route_decision_brief_text(surface)
	var sections := []
	if reason != "":
		if interception_tooltip != "":
			sections.append("%s. %s" % [line, reason])
			sections.append(interception_tooltip)
			sections.append(decision_brief)
			var blocked_interception_text := _join_tooltip_sections(sections)
			_debug_phase_end("route_text_generation", text_started_usec, {"status": String(surface.get("status", "")), "sections": sections.size()})
			return blocked_interception_text
		sections.append("%s. %s" % [line, reason])
		sections.append(decision_brief)
		var blocked_text := _join_tooltip_sections(sections)
		_debug_phase_end("route_text_generation", text_started_usec, {"status": String(surface.get("status", "")), "sections": sections.size()})
		return blocked_text
	var commit_line := "%s. Commit %s." % [line, String(surface.get("action_label", "the selected order"))]
	if interception_tooltip != "":
		sections.append(commit_line)
		sections.append(interception_tooltip)
		sections.append(decision_brief)
		var interception_text := _join_tooltip_sections(sections)
		_debug_phase_end("route_text_generation", text_started_usec, {"status": String(surface.get("status", "")), "sections": sections.size()})
		return interception_text
	sections.append(commit_line)
	sections.append(decision_brief)
	var tooltip_text := _join_tooltip_sections(sections)
	_debug_phase_end("route_text_generation", text_started_usec, {"status": String(surface.get("status", "")), "sections": sections.size()})
	return tooltip_text

func _route_target_handoff_surface(surface: Dictionary = {}) -> Dictionary:
	var route_surface := surface
	if route_surface.is_empty():
		route_surface = _selected_route_decision_surface()
	if route_surface.is_empty() or String(route_surface.get("status", "")) == "current":
		return {}
	var destination := String(route_surface.get("destination", "Selected route")).strip_edges()
	if destination == "":
		destination = "%d,%d" % [int(route_surface.get("x", _selected_tile.x)), int(route_surface.get("y", _selected_tile.y))]
	var action_label := String(route_surface.get("action_label", "Route order")).strip_edges()
	if action_label == "":
		action_label = String(route_surface.get("action_kind", "Route order")).capitalize()
	var status_label := _route_decision_status_label(route_surface)
	var steps := int(route_surface.get("steps", 0))
	var step_text := "%d step%s" % [steps, "" if steps == 1 else "s"] if steps > 0 else "no path"
	var movement_current := int(route_surface.get("movement_current", 0))
	var movement_max := int(route_surface.get("movement_max", movement_current))
	var movement_after := int(route_surface.get("movement_after_order", movement_current))
	var movement_text := "Move %d/%d" % [movement_current, movement_max]
	if int(route_surface.get("movement_cost", 0)) > 0:
		movement_text = "Move %d->%d" % [movement_current, movement_after]
	var brief := _route_decision_brief(route_surface)
	var why := String(brief.get("why_it_matters", "")).strip_edges()
	if why == "":
		why = _route_decision_why_it_matters(route_surface)
	var next_step := String(brief.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = _route_decision_next_practical_action(route_surface)
	var readiness := "%s, %s, %s" % [step_text, status_label, movement_text]
	var next_step_line := String(route_surface.get("next_step_line", "")).strip_edges()
	if next_step_line != "":
		readiness = "%s, %s" % [readiness, next_step_line]
	var visible := "Route target: %s | %s | %s" % [
		_short_action_label(destination, 22),
		_short_action_label(action_label, 18),
		status_label,
	]
	var tooltip := "Route Target Handoff\n- Target: %s at %d,%d\n- Order: %s\n- Readiness: %s\n- Why it matters: %s\n- Next: %s" % [
		destination,
		int(route_surface.get("x", _selected_tile.x)),
		int(route_surface.get("y", _selected_tile.y)),
		action_label,
		readiness,
		why,
		next_step,
	]
	if next_step_line != "":
		tooltip += "\n- Route step: %s" % next_step_line
	var blocked_reason := String(route_surface.get("blocked_reason", "")).strip_edges()
	if blocked_reason != "":
		tooltip += "\n- Blocked: %s" % blocked_reason
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"target_label": destination,
		"action_label": action_label,
		"status": String(route_surface.get("status", "")),
		"status_label": status_label,
		"steps": steps,
		"movement_line": movement_text,
		"readiness": readiness,
		"why_it_matters": why,
		"next_step": next_step,
		"blocked_reason": blocked_reason,
	}

func _route_decision_brief_text(surface: Dictionary) -> String:
	var brief_value: Variant = surface.get("decision_brief", {})
	var brief: Dictionary = brief_value if brief_value is Dictionary else _route_decision_brief(surface)
	return String(brief.get("tooltip_text", "")).strip_edges()

func _route_decision_brief(surface: Dictionary) -> Dictionary:
	if surface.is_empty():
		return {}
	var affected := _route_decision_affected_text(surface)
	var why := _route_decision_why_it_matters(surface)
	var next_step := _route_decision_next_practical_action(surface)
	if affected == "" or why == "" or next_step == "":
		return {}
	var tooltip := "Decision Brief\n- Affected: %s\n- Why it matters: %s\n- Next: %s" % [
		affected,
		why,
		next_step,
	]
	return {
		"affected": affected,
		"why_it_matters": why,
		"next_step": next_step,
		"tooltip_text": tooltip,
	}

func _route_decision_affected_text(surface: Dictionary) -> String:
	var destination := String(surface.get("destination", "Selected")).strip_edges()
	if destination == "":
		destination = "%d,%d" % [int(surface.get("x", _selected_tile.x)), int(surface.get("y", _selected_tile.y))]
	var route_label := "%s route" % destination
	var objective_label := _selected_tile_objective_label()
	if objective_label == "":
		objective_label = _current_objective_next_label()
	if objective_label != "":
		return "%s | Objective: %s" % [route_label, objective_label]
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		return "%s | Town: %s" % [route_label, String(town.get("owner", "neutral")).capitalize()]
	return route_label

func _route_decision_why_it_matters(surface: Dictionary) -> String:
	var status := String(surface.get("status", ""))
	var reason := String(surface.get("blocked_reason", "")).strip_edges()
	if status in ["blocked", "no_movement"] and reason != "":
		return reason
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		var context := OverworldRules.describe_town_context(town, _session).replace("\n", " ")
		return _short_player_sentence(context, "Town control shapes recruitment, defense, route support, and objective pressure.")
	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var control := OverworldRules.describe_resource_site_control_summary(_session, node, site)
		if control == "":
			control = OverworldRules.describe_resource_site_interaction_surface(node, site)
		return _short_player_sentence(control, "This site can change income, scouting, recruits, or route control.")
	var encounter := _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		var pressure := OverworldRules.describe_encounter_pressure(_session, encounter).replace("\n", " ")
		if pressure == "":
			pressure = OverworldRules.describe_encounter_compact_readability(_session, encounter)
		return _short_player_sentence(pressure, "Breaking this host can open the route, reward, or objective lane.")
	var artifact_node := _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		return _short_player_sentence(
			ArtifactRules.describe_single_artifact_impact(String(artifact_node.get("artifact_id", ""))),
			"Recovering the artifact changes the active commander's field options."
		)
	if status == "reachable":
		return "The route can be acted on with today's movement."
	if status == "not_today":
		return "The route is clear, but it needs more movement than remains today."
	return "This route decides where the active hero spends the next field order."

func _route_decision_next_practical_action(surface: Dictionary) -> String:
	var status := String(surface.get("status", ""))
	var action_label := String(surface.get("action_label", "the selected order")).strip_edges()
	var destination := String(surface.get("destination", "the destination")).strip_edges()
	match status:
		"current":
			return "Select a visible destination or open a command drawer."
		"blocked":
			var reason := String(surface.get("blocked_reason", "")).strip_edges()
			return reason if reason != "" else "Choose a different visible route."
		"no_movement":
			return "End the turn after checking town orders, then continue toward %s." % destination
		"not_today":
			return "Move as far as today's movement allows toward %s, then continue next day." % destination
		"reachable":
			return "Commit %s now." % action_label
	return "Review the selected tile, then choose the next route order."

func _selected_tile_objective_label() -> String:
	var placement_id := _selected_tile_objective_placement_id()
	if placement_id == "":
		return ""
	var scenario := ContentService.get_scenario(_session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return ""
	for bucket in ["victory", "defeat"]:
		var bucket_values = objectives.get(bucket, [])
		if not (bucket_values is Array):
			continue
		for objective_value in bucket_values:
			if not (objective_value is Dictionary):
				continue
			var objective: Dictionary = objective_value
			if String(objective.get("placement_id", "")) == placement_id:
				var label := String(objective.get("label", objective.get("id", "objective"))).strip_edges()
				if label != "":
					return label
	return ""

func _selected_tile_objective_placement_id() -> String:
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		return String(town.get("placement_id", ""))
	var encounter := _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		return String(encounter.get("placement_id", encounter.get("id", "")))
	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		return String(node.get("placement_id", ""))
	return ""

func _current_objective_next_label() -> String:
	var progress_recap := ScenarioRules.describe_session_progress_recap(_session, false)
	var next_line := _line_with_prefix(progress_recap, "Next step:").trim_prefix("Next step:").strip_edges()
	if next_line.begins_with("Push toward "):
		next_line = next_line.trim_prefix("Push toward ").strip_edges()
	if next_line.ends_with("."):
		next_line = next_line.left(next_line.length() - 1)
	return next_line

func _short_player_sentence(text: String, fallback: String) -> String:
	var cleaned := text.strip_edges().replace("\n", " ")
	while cleaned.find("  ") >= 0:
		cleaned = cleaned.replace("  ", " ")
	if cleaned == "":
		cleaned = fallback
	var sentence_end := cleaned.find(". ")
	if sentence_end >= 0:
		cleaned = cleaned.left(sentence_end + 1)
	if cleaned.length() > 150:
		cleaned = "%s..." % cleaned.left(147)
	return cleaned

func _route_decision_interception(surface: Dictionary) -> Dictionary:
	var value: Variant = surface.get("interception", {})
	if value is Dictionary:
		return value
	return {}

func _route_decision_status_label(surface: Dictionary) -> String:
	match String(surface.get("status", "")):
		"reachable":
			return "reachable today"
		"not_today":
			return "not reachable today"
		"no_movement":
			return "no movement"
		"blocked":
			return "blocked"
		"current":
			return "current"
		_:
			return "selected"

func _selected_tile_order_label(adjacent: bool) -> String:
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		var owner := String(town.get("owner", "neutral"))
		if adjacent:
			return "Visit Town" if owner == "player" else "Approach Town"
		return "Advance to Town"

	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		if adjacent:
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			if bool(site.get("persistent_control", false)) and String(node.get("collected_by_faction_id", "")) == "player":
				return "Enter Site"
			return "Secure Site"
		return "Advance to Site"

	if not _artifact_node_at(_selected_tile.x, _selected_tile.y).is_empty():
		return "Recover Artifact" if adjacent else "Advance to Artifact"

	if not _encounter_at(_selected_tile.x, _selected_tile.y).is_empty():
		return "Enter Battle" if adjacent else "Advance to Battle"

	return "March" if adjacent else "Advance"

func _selected_tile_order_summary(adjacent: bool) -> String:
	var artifact_node := _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		var artifact_id := String(artifact_node.get("artifact_id", ""))
		var state := ArtifactRules.artifact_collection_state(
			_session.overworld.get("hero", {}),
			artifact_id,
			bool(artifact_node.get("collected", false)),
			String(artifact_node.get("collected_by_faction_id", ""))
		)
		if adjacent:
			return "Recover %s. %s." % [ArtifactRules.describe_artifact_short(artifact_id), state]
		return "Take the next step toward %s. %s." % [ArtifactRules.artifact_name(artifact_id), state]
	var encounter := _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		var readout := OverworldRules.describe_encounter_compact_readability(_session, encounter)
		if adjacent:
			return "Enter battle with %s%s." % [
				OverworldRules.encounter_display_name(encounter),
				"" if readout == "" else ". %s" % readout,
			]
		return "Take the next step toward %s%s." % [
			OverworldRules.encounter_display_name(encounter),
			"" if readout == "" else ". %s" % readout,
		]
	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var control_summary := OverworldRules.describe_resource_site_control_summary(_session, node, site)
		var site_name := String(site.get("name", "Frontier site"))
		if adjacent:
			return "%s %s%s." % [
				_selected_tile_order_label(true),
				site_name,
				"" if control_summary == "" else ". %s" % control_summary,
			]
		return "Take the next step toward %s%s." % [
			site_name,
			"" if control_summary == "" else ". %s" % control_summary,
		]
	var destination := _selected_tile_destination_name()
	var target := "%d,%d" % [_selected_tile.x, _selected_tile.y]
	if destination != "":
		target = "%s at %s" % [destination, target]
	if adjacent:
		return "%s %s." % [_selected_tile_order_label(true), target]
	return "Take the next step toward %s." % target

func _selected_tile_destination_name() -> String:
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		var town_data := ContentService.get_town(String(town.get("town_id", "")))
		return String(town_data.get("name", town.get("placement_id", "Town")))

	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		return String(site.get("name", "Resource site"))

	var artifact_node := _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		return ArtifactRules.artifact_name(String(artifact_node.get("artifact_id", "")))

	var encounter := _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		return OverworldRules.encounter_display_name(encounter)

	return ""

func _record_result_feedback(kind: String, result: Dictionary, fallback: String = "") -> void:
	var feedback_kind := kind
	if not bool(result.get("ok", false)):
		feedback_kind = "blocked"
	var recap := _result_post_action_recap(result)
	_last_action_recap = recap
	var message := String(result.get("message", ""))
	if not recap.is_empty() and String(recap.get("cue_text", "")).strip_edges() != "":
		message = String(recap.get("cue_text", ""))
	_record_action_feedback(feedback_kind, message, fallback, recap)

func _record_action_feedback(kind: String, message: String, fallback: String = "", recap: Dictionary = {}) -> void:
	if recap.is_empty():
		_last_action_recap = {}
	var body := _feedback_body(message, fallback)
	if body == "":
		return
	var label := _feedback_kind_label(kind)
	var text := "%s: %s" % [label, body]
	var full_text := text
	if not recap.is_empty():
		var recap_tooltip := String(recap.get("tooltip_text", "")).strip_edges()
		if recap_tooltip != "":
			full_text = "%s\n%s" % [text, recap_tooltip]
	_action_feedback_sequence += 1
	_action_feedback = {
		"kind": kind,
		"label": label,
		"text": _short_text(text, ACTION_FEEDBACK_CHARS),
		"full_text": full_text,
		"post_action_recap": recap.duplicate(true),
		"sequence": _action_feedback_sequence,
	}
	if not recap.is_empty():
		_session.flags["last_overworld_action_recap"] = recap.duplicate(true)
	_pulse_action_feedback()

func _result_post_action_recap(result: Dictionary) -> Dictionary:
	var recap_value: Variant = result.get("post_action_recap", {})
	if not (recap_value is Dictionary):
		return {}
	var recap: Dictionary = recap_value
	for key in ["happened", "affected", "why_it_matters", "next_step"]:
		if String(recap.get(key, "")).strip_edges() == "":
			return {}
	return recap.duplicate(true)

func _feedback_body(message: String, fallback: String = "") -> String:
	var body := message.strip_edges()
	if body == "":
		body = fallback.strip_edges()
	body = _strip_moved_feedback_prefix(body)
	body = body.replace("\n", " ")
	while body.find("  ") >= 0:
		body = body.replace("  ", " ")
	if body.ends_with("."):
		body = body.left(body.length() - 1)
	return body

func _strip_moved_feedback_prefix(message: String) -> String:
	if not message.begins_with("Moved to "):
		return message
	var sentence_break := message.find(". ")
	if sentence_break < 0 or sentence_break + 2 >= message.length():
		return message
	return message.substr(sentence_break + 2).strip_edges()

func _feedback_kind_label(kind: String) -> String:
	match kind:
		"artifact":
			return "Artifact"
		"battle":
			return "Battle"
		"blocked":
			return "Blocked"
		"cast":
			return "Cast"
		"collect":
			return "Collected"
		"enemy":
			return "Enemy"
		"hero":
			return "Hero"
		"move":
			return "Moved"
		"system":
			return "System"
		"town":
			return "Town"
		"turn":
			return "Turn"
		_:
			return "Action"

func _battle_return_notice(fallback: String) -> String:
	var report = _session.flags.get("last_battle_aftermath", {}) if _session != null else {}
	if not (report is Dictionary) or report.is_empty():
		return fallback
	var handoff := _battle_return_handoff_summary(report)
	var compact := String(report.get("return_summary", "")).strip_edges()
	if compact != "":
		if handoff != "":
			return "%s %s" % [compact, handoff]
		return compact
	var lines := []
	for key in ["result_summary", "reward_summary", "artifact_summary", "force_summary", "world_summary"]:
		var line := String(report.get(key, "")).strip_edges()
		if line != "" and line not in lines:
			lines.append(line)
	if handoff != "":
		lines.append(handoff)
	if not lines.is_empty():
		return " ".join(lines)
	return fallback

func _consume_town_return_handoff() -> Dictionary:
	if _session == null:
		return {}
	var handoff_value: Variant = _session.flags.get("town_return_handoff", {})
	if not (handoff_value is Dictionary):
		return {}
	var handoff: Dictionary = handoff_value
	_session.flags.erase("town_return_handoff")
	if handoff.is_empty():
		return {}
	var visible := String(handoff.get("visible_text", "")).strip_edges()
	if visible == "":
		visible = "Town return: back on the field."
		handoff["visible_text"] = visible
	var tooltip := String(handoff.get("tooltip_text", "")).strip_edges()
	if tooltip == "":
		tooltip = "Town Return Handoff\n- Returned to the overworld without advancing the day."
		handoff["tooltip_text"] = tooltip
	var recap := _duplicate_dictionary(handoff.get("post_action_recap", {}))
	if recap.is_empty():
		var next_step := String(handoff.get("next_step", "Select the next destination or end the turn when field orders are spent."))
		recap = {
			"happened": visible,
			"affected": "%s | %s" % [
				String(handoff.get("town_name", "Town")),
				String(handoff.get("movement_line", "field movement")),
			],
			"why_it_matters": "Leaving town returns control to overworld field orders.",
			"next_step": next_step,
			"cue_text": visible,
			"tooltip_text": tooltip,
			"text": "After town: %s Next: %s" % [visible, next_step],
		}
		handoff["post_action_recap"] = recap
	return handoff.duplicate(true)

func _battle_return_handoff_summary(report: Dictionary) -> String:
	var affected := _battle_handoff_affected(report)
	var why := _battle_handoff_why(report)
	var next_action := String(_field_readiness_surface().get("next_step", "")).strip_edges()
	if next_action == "":
		next_action = "Select the next destination or end the turn when field orders are spent."
	if affected == "" and why == "":
		return ""
	return "Handoff: Affected: %s Why it matters: %s Next practical action: %s" % [
		affected if affected != "" else "the field state after battle",
		why if why != "" else "the battle result changes what the commander should do next",
		next_action,
	]

func _battle_handoff_affected(report: Dictionary) -> String:
	var world_summary := String(report.get("world_summary", "")).strip_edges()
	if world_summary != "":
		return _trim_known_prefix(world_summary, "Overworld:")
	var headline := String(report.get("headline", "")).strip_edges()
	if headline != "":
		return headline
	var result_summary := String(report.get("result_summary", "")).strip_edges()
	if result_summary != "":
		return _trim_known_prefix(result_summary, "Result:")
	return ""

func _battle_handoff_why(report: Dictionary) -> String:
	for key in ["reward_summary", "artifact_summary", "force_summary", "result_summary"]:
		var text := String(report.get(key, "")).strip_edges()
		if text != "":
			return _trim_known_prefix(text, "Result:")
	return ""

func _trim_known_prefix(text: String, prefix: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed.begins_with(prefix):
		return trimmed.trim_prefix(prefix).strip_edges()
	return trimmed

func _feedback_kind_for_context_action(action_id: String) -> String:
	match action_id:
		"collect_artifact":
			return "artifact"
		"collect_resource":
			return "collect"
		"capture_town", "visit_town":
			return "town"
		"enter_battle":
			return "battle"
		"site_response":
			return "collect"
		_:
			return "system"

func _feedback_kind_for_move(result: Dictionary, route: String) -> String:
	if not bool(result.get("ok", false)):
		return "blocked"
	if route == "battle":
		return "battle"
	if route == "town":
		return "town"
	var message := String(result.get("message", ""))
	if message.find("Recovered ") >= 0 or message.find("Equipped in ") >= 0:
		return "artifact"
	if message.find("Stores ") >= 0 or message.find("claimed") >= 0 or message.find("Claimed") >= 0:
		return "collect"
	return "move"

func _movement_feedback_fallback(result: Dictionary) -> String:
	if bool(result.get("ok", false)):
		var pos := OverworldRules.hero_position(_session)
		return "%d,%d" % [pos.x, pos.y]
	return "Route did not resolve."

func _turn_resolution_feedback_fallback() -> String:
	if _last_turn_resolution_text != "":
		return _last_turn_resolution_text
	return "Day %d begins." % _session.day

func _action_feedback_text() -> String:
	if _action_feedback.is_empty():
		return ""
	return String(_action_feedback.get("text", ""))

func _action_feedback_tooltip() -> String:
	if _action_feedback.is_empty():
		return ""
	return String(_action_feedback.get("full_text", _action_feedback.get("text", "")))

func _pulse_action_feedback() -> void:
	if _cue_chip_panel == null:
		return
	_cue_chip_panel.pivot_offset = _cue_chip_panel.size * 0.5
	if _action_feedback_tween != null:
		_action_feedback_tween.kill()
		_action_feedback_tween = null
	_cue_chip_panel.scale = Vector2.ONE
	_cue_chip_panel.modulate = Color.WHITE
	if SettingsService.reduced_motion_enabled():
		return
	_action_feedback_tween = create_tween()
	_action_feedback_tween.set_trans(Tween.TRANS_QUAD)
	_action_feedback_tween.set_ease(Tween.EASE_OUT)
	_action_feedback_tween.tween_property(_cue_chip_panel, "scale", Vector2(1.025, 1.025), 0.08)
	_action_feedback_tween.parallel().tween_property(_cue_chip_panel, "modulate", Color(1.0, 0.94, 0.72, 1.0), 0.08)
	_action_feedback_tween.tween_property(_cue_chip_panel, "scale", Vector2.ONE, 0.18)
	_action_feedback_tween.parallel().tween_property(_cue_chip_panel, "modulate", Color.WHITE, 0.18)

func _map_cue_text() -> String:
	var feedback := _action_feedback_text()
	if feedback != "":
		return feedback
	var action := _current_primary_action()
	var acceptance_cue := _manual_play_acceptance_cue(action)
	if acceptance_cue != "":
		return acceptance_cue
	var route_cue := _route_decision_cue(_selected_route_decision_surface())
	if route_cue != "":
		return _short_text(route_cue, 52)
	if action.is_empty():
		var movement = _session.overworld.get("movement", {})
		var cue := "Move %d/%d | Select destination" % [
			int(movement.get("current", 0)),
			int(movement.get("max", 0)),
		]
		if _map_view != null and _map_view.has_method("validation_view_metrics"):
			var metrics: Dictionary = _map_view.call("validation_view_metrics")
			if bool(metrics.get("pan_supported", false)):
				cue = "Move %d/%d | Drag pan | Select" % [
					int(movement.get("current", 0)),
					int(movement.get("max", 0)),
				]
		return cue
	return "Action: %s [Enter]" % _short_action_label(String(action.get("label", "Action")), 20)

func _manual_play_acceptance_cue(action: Dictionary) -> String:
	if action.is_empty() or bool(action.get("disabled", false)):
		return ""
	var label := _short_action_label(String(action.get("label", "Action")), 22)
	if label == "":
		return ""
	return _short_text("Try: %s [Enter]" % label, 52)

func _map_cue_tooltip() -> String:
	var feedback := _action_feedback_tooltip()
	var action := _current_primary_action()
	var route_tooltip := _route_decision_tooltip(_selected_route_decision_surface())
	var pan_hint := ""
	if _map_view != null and _map_view.has_method("validation_view_metrics"):
		var metrics: Dictionary = _map_view.call("validation_view_metrics")
		if bool(metrics.get("pan_supported", false)):
			pan_hint = " Drag the map, use the mouse wheel, or hold Shift with arrow/WASD keys to pan. Home returns to the active hero."
	if feedback != "":
		var next_hint := " Select another destination or press Enter/Space for the current primary order." if not action.is_empty() else " Select a destination or open a command drawer for the next order."
		return "%s.%s%s" % [feedback, next_hint, pan_hint]
	if route_tooltip != "":
		var commit_hint := " Try %s with Enter or Space now." % String(action.get("label", "the primary order")) if not action.is_empty() and not bool(action.get("disabled", false)) else ""
		return "%s%s%s" % [route_tooltip, commit_hint, pan_hint]
	if action.is_empty():
		return "Click a visible adjacent tile to move now, or select a farther visible tile to set the next route step.%s" % pan_hint
	return "Press Enter or Space for %s. Click the map to move or change the selected route.%s" % [String(action.get("label", "the primary order")), pan_hint]

func _short_action_label(label: String, max_chars: int) -> String:
	var trimmed := label.strip_edges()
	if trimmed.length() <= max_chars:
		return trimmed
	return "%s..." % trimmed.left(max(1, max_chars - 3))

func _rebuild_artifact_actions() -> void:
	for child in _artifact_actions.get_children():
		child.queue_free()

	var actions = _cached_artifact_actions()
	if actions.is_empty():
		_artifact_actions.add_child(_make_placeholder_label("No loadout action"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_rail_action_button(button)
		button.pressed.connect(_on_artifact_action_pressed.bind(String(action.get("id", ""))))
		_artifact_actions.add_child(button)

func _rebuild_specialty_actions() -> void:
	for child in _specialty_actions.get_children():
		child.queue_free()

	var actions = _cached_specialty_actions()
	if actions.is_empty():
		var placeholder := _make_placeholder_label("Specialty check: none")
		placeholder.tooltip_text = String(_specialty_check_surface().get("tooltip_text", "No specialty pick."))
		_specialty_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Choose Specialty")))
		button.disabled = bool(action.get("disabled", false))
		var specialty_check := _specialty_action_check_surface(action)
		button.tooltip_text = _join_tooltip_sections([
			String(action.get("summary", "")),
			String(specialty_check.get("tooltip_text", "")),
		])
		_style_rail_action_button(button)
		button.pressed.connect(_on_specialty_action_pressed.bind(String(action.get("id", ""))))
		_specialty_actions.add_child(button)

func _rebuild_spell_actions() -> void:
	for child in _spell_actions.get_children():
		child.queue_free()

	var actions = _cached_spell_actions()
	if actions.is_empty():
		var placeholder := _make_placeholder_label("Spell check: none")
		placeholder.tooltip_text = String(_spell_check_surface().get("tooltip_text", "No field spell."))
		_spell_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		var spell_check := _spell_action_check_surface(action)
		button.tooltip_text = _join_tooltip_sections([
			String(action.get("summary", "")),
			String(spell_check.get("tooltip_text", "")),
		])
		_style_rail_action_button(button)
		button.pressed.connect(_on_spell_action_pressed.bind(String(action.get("id", ""))))
		_spell_actions.add_child(button)

func _hero_card_text() -> String:
	var hero = _session.overworld.get("hero", {})
	var command = hero.get("command", {})
	var mana = hero.get("spellbook", {}).get("mana", {})
	var movement = _session.overworld.get("movement", {})
	return "%s Lv%d | Move %d/%d | Mana %d/%d\nA%d D%d P%d K%d | Scout %d" % [
		String(hero.get("name", "Hero")),
		int(hero.get("level", 1)),
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		int(mana.get("current", 0)),
		int(mana.get("max", 0)),
		int(command.get("attack", 0)),
		int(command.get("defense", 0)),
		int(command.get("power", 0)),
		int(command.get("knowledge", 0)),
		HeroCommandRules.scouting_radius_for_hero(hero),
	]

func _describe_focus_tile() -> String:
	if _selected_tile == OverworldRules.hero_position(_session):
		return _cached_active_context_text()
	return _describe_selected_tile()

func _rail_log_text() -> String:
	if _last_turn_resolution_text != "":
		return "Turn: %s" % _last_turn_resolution_text
	if _last_enemy_activity_text != "":
		return "Enemy: %s" % _last_enemy_activity_text
	var message := _last_message.strip_edges()
	if message == "":
		message = "Awaiting order"
	return "Log: %s" % message

func _event_feed_surface() -> Dictionary:
	var surface := OverworldRules.describe_event_feed_surface(
		_session,
		_last_message,
		_last_turn_resolution_text,
		_last_enemy_activity_text,
		_last_enemy_activity_events,
		_last_action_recap
	)
	var readiness_surface := _field_readiness_surface(surface)
	surface["field_readiness"] = readiness_surface
	if _field_feed_is_idle():
		var visible_text := String(readiness_surface.get("visible_text", "")).strip_edges()
		if visible_text != "":
			surface["visible_text"] = visible_text
		surface["tooltip_text"] = _join_tooltip_sections([
			String(surface.get("tooltip_text", "")),
			String(readiness_surface.get("tooltip_text", "")),
		])
	surface["dispatch_text"] = OverworldRules.describe_dispatch(_session, _last_message)
	return surface

func _action_context_surface(event_surface: Dictionary, readiness_surface: Dictionary = {}) -> Dictionary:
	var recap := _duplicate_dictionary(event_surface.get("post_action_recap", {}))
	if recap.is_empty() and not _last_action_recap.is_empty():
		recap = _last_action_recap.duplicate(true)
	if recap.is_empty():
		return event_surface

	var latest_action := String(recap.get("happened", "")).strip_edges()
	if latest_action == "":
		latest_action = String(recap.get("cue_text", _action_feedback_text())).strip_edges()
	if latest_action == "":
		return event_surface

	var next_step := String(recap.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = String(readiness_surface.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = String(event_surface.get("next_step", "")).strip_edges()
	var handoff_check := _action_context_handoff_check(next_step, readiness_surface)

	var surface := event_surface.duplicate(true)
	var visible := "Latest: %s" % _short_text(_context_strip_sentence(latest_action), 38)
	if next_step != "":
		visible = "%s | Next: %s" % [
			visible,
			_short_text(_context_strip_sentence(next_step).trim_suffix("."), 34),
		]
	surface["visible_text"] = visible
	surface["tooltip_text"] = _join_tooltip_sections([
		"Current Turn Context\n- Latest action: %s\n- Next practical step: %s\n- Handoff check: %s" % [
			latest_action,
			next_step if next_step != "" else "Select the next destination or end the turn when field orders are spent.",
			handoff_check,
		],
		String(event_surface.get("tooltip_text", "")),
		String(readiness_surface.get("tooltip_text", "")),
	])
	surface["latest_action"] = latest_action
	surface["next_practical_step"] = next_step
	surface["handoff_check"] = handoff_check
	surface["source"] = "post_action_recap"
	return surface

func _action_context_handoff_check(next_step: String, readiness_surface: Dictionary = {}) -> String:
	var cleaned_next := _context_strip_sentence(next_step).trim_suffix(".")
	if cleaned_next == "":
		cleaned_next = "choose the next field order"
	var movement_line := String(readiness_surface.get("movement_line", "")).strip_edges()
	if movement_line != "":
		return "%s with %s available." % [cleaned_next.capitalize(), movement_line]
	return "%s before saving, entering a surface, or ending the turn." % cleaned_next.capitalize()

func _context_strip_sentence(text: String) -> String:
	var cleaned := text.strip_edges().replace("\n", " ")
	while cleaned.find("  ") >= 0:
		cleaned = cleaned.replace("  ", " ")
	for prefix in ["Order resolved: ", "Scenario pulse: "]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.trim_prefix(prefix).strip_edges()
	return cleaned

func _field_feed_is_idle() -> bool:
	return (
		_last_message.strip_edges() == ""
		and _last_turn_resolution_text.strip_edges() == ""
		and _last_enemy_activity_text.strip_edges() == ""
		and _last_action_recap.is_empty()
	)

func _field_readiness_surface(base_event_surface: Dictionary = {}) -> Dictionary:
	var movement = _session.overworld.get("movement", {})
	var movement_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
	]
	var progress_recap := ScenarioRules.describe_session_progress_recap(_session, false)
	var progress_line := _line_with_prefix(progress_recap, "Current progress:")
	var next_step := String(base_event_surface.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = _line_with_prefix(progress_recap, "Next step:").trim_prefix("Next step:").strip_edges()
	if next_step == "":
		next_step = "Select the next destination or end the turn when field orders are spent."
	var primary_action := _current_primary_action()
	var primary_line := "Primary order: select a visible destination."
	if not primary_action.is_empty():
		primary_line = "Primary order: %s." % String(primary_action.get("label", "Commit order"))
		var summary := String(primary_action.get("summary", "")).strip_edges()
		if summary != "":
			primary_line = "%s %s" % [primary_line, summary]
	var route_decision := _selected_route_decision_surface()
	var route_line := _route_decision_line(route_decision)
	var route_target_handoff := _route_target_handoff_surface(route_decision)
	var town_entry_handoff := _town_entry_handoff_surface()
	var active_site_order := _active_site_order_surface(primary_action)
	var forecast := OverworldRules.describe_end_turn_forecast_compact(_session)
	var visible_next := _short_text(next_step.trim_suffix("."), 44)
	var visible := "Ready: %s | %s" % [visible_next, movement_line]
	var active_site_visible := String(active_site_order.get("visible_text", "")).strip_edges()
	if active_site_visible != "":
		visible = "Ready: %s | %s" % [
			visible_next,
			_short_text(active_site_visible.trim_prefix("Site handoff: "), 36),
		]
	var route_target_visible := String(route_target_handoff.get("visible_text", "")).strip_edges()
	if route_target_visible != "":
		visible = "Ready: %s | %s" % [
			visible_next,
			_short_text(route_target_visible.trim_prefix("Route target: "), 36),
		]
	var town_entry_visible := String(town_entry_handoff.get("visible_text", "")).strip_edges()
	if town_entry_visible != "":
		visible = "Ready: %s | %s" % [
			visible_next,
			_short_text(town_entry_visible.trim_prefix("Town handoff: "), 36),
		]
	var tooltip_lines := [
		"Field Readiness",
		"- %s" % (progress_line if progress_line != "" else "Current progress: no authored objective progress is available."),
		"- Next practical action: %s" % next_step,
		"- %s" % primary_line,
	]
	var active_site_tooltip := String(active_site_order.get("tooltip_text", "")).strip_edges()
	if active_site_tooltip != "":
		tooltip_lines.append(active_site_tooltip)
	var route_target_tooltip := String(route_target_handoff.get("tooltip_text", "")).strip_edges()
	if route_target_tooltip != "":
		tooltip_lines.append(route_target_tooltip)
	var town_entry_tooltip := String(town_entry_handoff.get("tooltip_text", "")).strip_edges()
	if town_entry_tooltip != "":
		tooltip_lines.append(town_entry_tooltip)
	if route_line != "":
		tooltip_lines.append("- %s" % route_line)
	if forecast != "":
		tooltip_lines.append("- End turn forecast: %s" % forecast)
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"progress_line": progress_line,
		"next_step": next_step,
		"primary_order": primary_line,
		"active_site_order": active_site_order,
		"route_line": route_line,
		"route_target_handoff": route_target_handoff,
		"town_entry_handoff": town_entry_handoff,
		"movement_line": movement_line,
		"end_turn_forecast": forecast,
	}

func _status_forecast_surface() -> Dictionary:
	var status_text := OverworldRules.describe_status(_session)
	var movement = _session.overworld.get("movement", {})
	var next_day := _session.day + 1
	var week: int = int(floori(float(max(_session.day, 1) - 1) / 7.0)) + 1
	var weekday: int = ((max(_session.day, 1) - 1) % 7) + 1
	var visible_text := "Week %d Day %d | Move %d/%d | Next: Day %d" % [
		week,
		weekday,
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		next_day,
	]
	var forecast_text := OverworldRules.describe_end_turn_forecast(_session)
	var forecast_compact := OverworldRules.describe_end_turn_forecast_compact(_session)
	var tooltip_lines := [
		"Status Forecast",
		"- Current: %s" % status_text,
		"- Next day: %s" % (forecast_compact if forecast_compact != "" else "forecast unavailable"),
	]
	if forecast_text != "":
		tooltip_lines.append(forecast_text)
	return {
		"visible_text": visible_text,
		"tooltip_text": "\n".join(tooltip_lines),
		"current_status": status_text,
		"next_day": next_day,
		"forecast": forecast_text,
		"forecast_compact": forecast_compact,
	}

func _end_turn_confirmation_surface(field_readiness: Dictionary = {}) -> Dictionary:
	var readiness := field_readiness
	if readiness.is_empty():
		readiness = _field_readiness_surface()
	var movement = _session.overworld.get("movement", {})
	var move_current := int(movement.get("current", 0))
	var move_max := int(movement.get("max", 0))
	var primary_action := _current_primary_action()
	var action_id := String(primary_action.get("id", ""))
	var action_label := String(primary_action.get("label", "")).strip_edges()
	var button_text := "End Turn"
	var confirmation := "End the day when field orders are complete."
	if move_current <= 0:
		confirmation = "Movement is spent; ending the day is the practical next step."
	elif action_id == "enter_battle":
		button_text = "End? Battle"
		confirmation = "An encounter order is available before ending the day."
	elif action_id == "visit_town":
		button_text = "End? Town"
		confirmation = "A town entry order is available before ending the day."
	elif action_id in ["advance_route", "march_selected"]:
		button_text = "End? Route"
		confirmation = "A route order is available before ending the day."
	elif action_label != "" and not bool(primary_action.get("disabled", false)):
		button_text = "End? Action"
		confirmation = "%s is available before ending the day." % action_label
	else:
		button_text = "End? %d Left" % move_current
		confirmation = "Movement remains before ending the day."
	var spend_check := "No movement remains; next day refreshes to %d move." % move_max
	if move_current > 0:
		spend_check = "%d unspent move will not carry over; next day refreshes to %d move." % [
			move_current,
			move_max,
		]
	var next_step := String(readiness.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = confirmation
	var primary_line := String(readiness.get("primary_order", "")).strip_edges()
	if primary_line == "":
		primary_line = "Primary order: select a visible destination."
	var route_line := String(readiness.get("route_line", "")).strip_edges()
	var forecast := String(readiness.get("end_turn_forecast", "")).strip_edges()
	if forecast == "":
		forecast = OverworldRules.describe_end_turn_forecast_compact(_session)
	var tooltip_lines := [
		"End Turn Check",
		"- Field readiness: %s" % String(readiness.get("visible_text", "Ready: field orders")).strip_edges(),
		"- Next practical action: %s" % next_step,
		"- %s" % primary_line,
		"- Confirmation: %s" % confirmation,
		"- Spend check: %s" % spend_check,
	]
	if route_line != "":
		tooltip_lines.append("- %s" % route_line)
	if forecast != "":
		tooltip_lines.append("- End turn forecast: %s" % forecast)
	return {
		"button_text": button_text,
		"tooltip_text": "\n".join(tooltip_lines),
		"confirmation": confirmation,
		"next_step": next_step,
		"primary_order": primary_line,
		"route_line": route_line,
		"movement_line": "Move %d/%d" % [move_current, move_max],
		"spend_check": spend_check,
		"end_turn_forecast": forecast,
	}

func _refresh_drawer_handoff_cues(field_readiness: Dictionary = {}) -> void:
	var surfaces := _drawer_handoff_surfaces(field_readiness)
	var command_surface: Dictionary = surfaces.get("command", {}) if surfaces.get("command", {}) is Dictionary else {}
	var frontier_surface: Dictionary = surfaces.get("frontier", {}) if surfaces.get("frontier", {}) is Dictionary else {}
	_open_command_button.text = String(command_surface.get("button_text", "Command"))
	_open_command_button.tooltip_text = String(command_surface.get("tooltip_text", "Open command panels."))
	_open_frontier_button.text = String(frontier_surface.get("button_text", "Frontier"))
	_open_frontier_button.tooltip_text = String(frontier_surface.get("tooltip_text", "Open frontier panels."))
	_close_command_button.tooltip_text = "Close Command drawer and return to the selected tile context."
	_close_frontier_button.tooltip_text = "Close Frontier drawer and return to the selected tile context."

func _drawer_handoff_surfaces(field_readiness: Dictionary = {}) -> Dictionary:
	var readiness := field_readiness
	if readiness.is_empty():
		readiness = _field_readiness_surface()
	var primary_action := _current_primary_action()
	var primary_label := String(primary_action.get("label", "")).strip_edges()
	if primary_label == "":
		primary_label = "select a destination"
	var next_step := String(readiness.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = "Select the next destination or end the turn when field orders are spent."
	var movement_line := String(readiness.get("movement_line", "")).strip_edges()
	if movement_line == "":
		var movement = _session.overworld.get("movement", {})
		movement_line = "Move %d/%d" % [int(movement.get("current", 0)), int(movement.get("max", 0))]
	var command_state := "Open" if _active_drawer == "command" else ("Ready" if not primary_action.is_empty() else "Select")
	var frontier_state := "Open" if _active_drawer == "frontier" else "Next"
	var command_tooltip := "Command Drawer Handoff\n- Opens: hero, army, spell, artifact, and selected-order panels.\n- Current order: %s.\n- Readiness: %s | %s.\n- Next: %s\n- State change: inspection only until an order button or Enter is committed." % [
		primary_label,
		String(readiness.get("visible_text", "Ready: field orders")).strip_edges(),
		movement_line,
		next_step,
	]
	var forecast := OverworldRules.describe_end_turn_forecast_compact(_session)
	var objective_line := _line_with_prefix(_cached_objective_text(), "Next step:")
	if objective_line == "":
		objective_line = String(readiness.get("progress_line", "")).strip_edges()
	var threat_line := _compact_rail_text(_cached_frontier_threats(), 1, 38, true)
	if threat_line == "":
		threat_line = "No immediate frontier warning."
	var frontier_tooltip := "Frontier Drawer Handoff\n- Opens: objectives, scout net, threat watch, and end-turn forecast.\n- Objective: %s\n- Watch: %s\n- Forecast: %s\n- State change: inspection only; End Turn remains the commit." % [
		objective_line if objective_line != "" else "review current objectives.",
		threat_line,
		forecast if forecast != "" else "next day forecast unavailable.",
	]
	return {
		"command": {
			"button_text": "Command %s" % command_state,
			"tooltip_text": command_tooltip,
			"state": command_state.to_lower(),
			"current_order": primary_label,
			"next_step": next_step,
			"movement_line": movement_line,
		},
		"frontier": {
			"button_text": "Frontier %s" % frontier_state,
			"tooltip_text": frontier_tooltip,
			"state": frontier_state.to_lower(),
			"objective_line": objective_line,
			"watch_line": threat_line,
			"forecast": forecast,
		},
	}

func _line_with_prefix(text: String, prefix: String) -> String:
	for raw_line in text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line.begins_with(prefix):
			return line
	return ""

func _join_tooltip_sections(sections: Array) -> String:
	var lines := []
	for section_value in sections:
		var section := String(section_value).strip_edges()
		if section != "" and section not in lines:
			lines.append(section)
	return "\n\n".join(lines)

func _rail_order_text(commitment_text: String) -> String:
	var primary_action := _current_primary_action()
	var order_line := "Order: select tile"
	if not primary_action.is_empty():
		order_line = "Order: %s" % _short_action_label(String(primary_action.get("label", "Action")), 24)
		if bool(primary_action.get("disabled", false)):
			order_line += " locked"
	var support_line := ""
	for raw_line in commitment_text.split("\n", false):
		var line := _clean_rail_line(raw_line)
		if line.begins_with("Route:") or line.begins_with("Cover:") or line.begins_with("Hold:"):
			support_line = line
			break
	if support_line == "":
		var movement = _session.overworld.get("movement", {})
		var hero_pos := OverworldRules.hero_position(_session)
		support_line = "Move %d/%d | Pos %d,%d" % [
			int(movement.get("current", 0)),
			int(movement.get("max", 0)),
			hero_pos.x,
			hero_pos.y,
		]
	return "%s\n%s" % [order_line, support_line]

func _rail_tile_text() -> String:
	if not _tile_in_bounds(_selected_tile):
		return "Tile: none\nSelect map"
	var terrain := _terrain_name_at(_selected_tile.x, _selected_tile.y)
	var coords := "%d,%d" % [_selected_tile.x, _selected_tile.y]
	var action_hint := _rail_action_hint()
	var route_line := _route_decision_line(_selected_route_decision_surface())
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return "Tile %s | Unexplored\n%s\nScout closer" % [coords, route_line]
	if not OverworldRules.is_tile_visible(_session, _selected_tile.x, _selected_tile.y):
		var remembered_rail := _remembered_tile_rail_text(terrain, coords, action_hint)
		if remembered_rail != "":
			return "%s\n%s" % [remembered_rail, route_line]
		return "Tile %s | Mapped %s\n%s\nOut of scout net" % [coords, terrain, route_line]

	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		var town_line := "Town: %s" % _selected_tile_destination_name()
		var owner := String(town.get("owner", "neutral")).capitalize()
		var handoff := String(_town_entry_handoff_surface().get("visible_text", "")).strip_edges()
		return "%s\n%s\n%s%s%s" % [
			town_line,
			route_line,
			"Owner %s | %s" % [owner, terrain],
			"" if action_hint == "" else " | %s" % action_hint,
			"" if handoff == "" else "\n%s" % handoff,
		]

	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var site_state := OverworldRules.describe_resource_site_surface(_session, node, site)
		var control_summary := OverworldRules.describe_resource_site_control_summary(_session, node, site)
		var recruit_summary := OverworldRules.describe_recruit_source_compact(_session, node, site)
		if site_state == "":
			site_state = "Ready"
		if control_summary != "":
			site_state = "%s | %s" % [site_state, control_summary]
		if recruit_summary != "":
			site_state = "%s | %s" % [site_state, recruit_summary]
		return "Site: %s\n%s\n%s | %s%s" % [
			String(site.get("name", "Frontier site")),
			route_line,
			site_state,
			terrain,
			"" if action_hint == "" else " | %s" % action_hint,
		]

	var artifact_node := _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		var artifact_id := String(artifact_node.get("artifact_id", ""))
		return "Artifact: %s\n%s\n%s | %s | %s%s" % [
			ArtifactRules.artifact_name(artifact_id),
			route_line,
			"%s | %s" % [ArtifactRules.artifact_slot_label(artifact_id), ArtifactRules.artifact_reward_role(artifact_id)],
			ArtifactRules.artifact_set_context(artifact_id),
			ArtifactRules.artifact_effect_summary(artifact_id),
			"" if action_hint == "" else " | %s" % action_hint,
		]

	var encounter := _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		var object_surface := OverworldRules.describe_encounter_object_surface(encounter)
		var readability := OverworldRules.describe_encounter_compact_readability(_session, encounter)
		var encounter_surface := terrain if object_surface == "" else "%s | %s" % [terrain, object_surface]
		if readability != "":
			encounter_surface = "%s | %s" % [encounter_surface, readability]
		return "Hostile: %s\n%s\n%s%s" % [
			OverworldRules.encounter_display_name(encounter),
			route_line,
			encounter_surface,
			"" if action_hint == "" else " | %s" % action_hint,
		]

	var heroes_here := _hero_entries_at(_selected_tile.x, _selected_tile.y)
	if not heroes_here.is_empty():
		var names := []
		for entry in heroes_here:
			if entry is Dictionary:
				names.append(String(entry.get("name", "Hero")))
		return "Marker: %s\n%s\n%s" % [", ".join(names), route_line, terrain]

	return "Open: %s | %s\n%s\n%s" % [coords, terrain, route_line, action_hint if action_hint != "" else "Route or march"]

func _rail_action_hint() -> String:
	var primary_action := _current_primary_action()
	if primary_action.is_empty():
		return ""
	var label := _short_action_label(String(primary_action.get("label", "Action")), 20)
	if bool(primary_action.get("disabled", false)):
		return "Locked %s" % label
	return "Enter %s" % label

func _remembered_tile_rail_text(terrain: String, coords: String, action_hint: String) -> String:
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		var owner := String(town.get("owner", "neutral"))
		var owner_label := "Own" if owner == "player" else "Mapped"
		return "Town: %s\n%s | %s%s" % [
			_selected_tile_destination_name(),
			"Remembered %s" % owner_label,
			terrain,
			"" if action_hint == "" else " | %s" % action_hint,
		]
	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var remembered_surface := OverworldRules.describe_resource_site_surface(_session, node, site)
		var recruit_summary := OverworldRules.describe_recruit_source_compact(_session, node, site)
		if remembered_surface == "":
			remembered_surface = "Remembered"
		if recruit_summary != "":
			remembered_surface = "%s | %s" % [remembered_surface, recruit_summary]
		return "Site: %s\n%s | %s | Out of scout net" % [
			String(site.get("name", "Frontier site")),
			remembered_surface,
			terrain,
		]
	var artifact_node := _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		var artifact_id := String(artifact_node.get("artifact_id", ""))
		return "Artifact: %s\nRemembered | %s | Out of scout net" % [
			ArtifactRules.describe_artifact_short(artifact_id),
			terrain,
		]
	var encounter := _rememberable_encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		var object_surface := OverworldRules.describe_encounter_object_surface(encounter)
		return "Hostile: %s\nRemembered | %s | Scout to confirm" % [
			OverworldRules.encounter_display_name(encounter),
			terrain if object_surface == "" else "%s | %s" % [terrain, object_surface],
		]
	return ""

func _remembered_selected_tile_text(terrain: String) -> String:
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		var owner := String(town.get("owner", "neutral"))
		var owner_text := "Owned town" if owner == "player" else "Mapped town"
		var order_text := "Enter Visit Town to manage it without moving the field hero." if owner == "player" else "Scout again before committing field orders here."
		return "Remembered Town\nCoords %d,%d | Terrain %s\n%s | %s\n%s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			_selected_tile_destination_name(),
			owner_text,
			order_text,
		]
	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var control_inspection := OverworldRules.describe_resource_site_control_inspection(_session, node, site)
		return "Remembered Site\nCoords %d,%d | Terrain %s\n%s\n%s\nThis mapped site is outside the current scout net." % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			String(site.get("name", "Frontier site")),
			OverworldRules.describe_resource_site_surface(_session, node, site) if control_inspection == "" else "%s\n%s" % [
				OverworldRules.describe_resource_site_surface(_session, node, site),
				control_inspection,
			],
		]
	var artifact_node := _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		var artifact_id := String(artifact_node.get("artifact_id", ""))
		return "Remembered Artifact\nCoords %d,%d | Terrain %s\n%s\nThe cache remains mapped outside the current scout net." % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			ArtifactRules.describe_artifact_inspection(
				_session.overworld.get("hero", {}),
				artifact_id,
				bool(artifact_node.get("collected", false)),
				String(artifact_node.get("collected_by_faction_id", ""))
			),
		]
	var encounter := _rememberable_encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		return "Remembered Hostile Contact\nCoords %d,%d | Terrain %s\n%s\n%s\nA fixed guard was mapped here; scout again before engaging." % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			OverworldRules.encounter_display_name(encounter),
			OverworldRules.describe_encounter_object_surface(encounter),
		]
	return ""

func _sync_context_drawers() -> void:
	var show_command := _active_drawer == "command"
	var show_frontier := _active_drawer == "frontier"
	var show_tile := not show_command and not show_frontier and _should_show_tile_context()
	_command_panel.visible = show_command
	_frontier_panel.visible = show_frontier
	_context_panel.visible = show_tile
	_command_spine.visible = show_command or show_frontier or show_tile
	_open_command_button.button_pressed = show_command
	_open_frontier_button.button_pressed = show_frontier
	_refresh_drawer_handoff_cues()

func _should_show_tile_context() -> bool:
	if not _tile_in_bounds(_selected_tile):
		return false
	if _selected_tile == OverworldRules.hero_position(_session):
		return false
	return true

func _frontier_indicator_text(threat_text: String, forecast_text: String) -> String:
	var threat_line := _compact_rail_text(threat_text, 1, 26, true)
	if threat_line == "":
		threat_line = "steady"
	var forecast_line := _compact_rail_text(forecast_text, 1, 26, true)
	if forecast_line == "":
		return "Frontier: %s" % _short_text(threat_line, 24)
	return "Frontier: %s" % _short_text(_strip_repeated_rail_prefix(forecast_line), 24)

func _describe_selected_tile() -> String:
	if not _tile_in_bounds(_selected_tile):
		return OverworldRules.describe_context(_session)

	var terrain = _terrain_name_at(_selected_tile.x, _selected_tile.y)
	var route_line := _route_decision_line(_selected_route_decision_surface())
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return "Unexplored Frontier\nCoords %d,%d | Terrain unknown\n%s\nScouts have not charted this ground yet." % [_selected_tile.x, _selected_tile.y, route_line]
	if not OverworldRules.is_tile_visible(_session, _selected_tile.x, _selected_tile.y):
		var remembered_text := _remembered_selected_tile_text(terrain)
		if remembered_text != "":
			return "%s\n%s" % [remembered_text, route_line]
		return "Mapped Ground\nCoords %d,%d | Terrain %s\n%s\nThis tile is outside the current scout net." % [_selected_tile.x, _selected_tile.y, terrain, route_line]

	var town = _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		return "Town Site\nCoords %d,%d | Terrain %s\n%s\n%s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			route_line,
			OverworldRules.describe_town_context(town, _session),
		]

	var node = _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		var control_inspection := OverworldRules.describe_resource_site_control_inspection(_session, node, site)
		return "Resource Site\nCoords %d,%d | Terrain %s\n%s\n%s\n%s\n%s%s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			route_line,
			String(site.get("name", "Frontier cache")),
			OverworldRules.describe_resource_site_surface(_session, node, site),
			OverworldRules.describe_resource_site_interaction_surface(node, site),
			"" if control_inspection == "" else "\n%s" % control_inspection,
		]

	var artifact_node = _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		var artifact_id := String(artifact_node.get("artifact_id", ""))
		return "Artifact Cache\nCoords %d,%d | Terrain %s\n%s\n%s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			route_line,
			ArtifactRules.describe_artifact_inspection(
				_session.overworld.get("hero", {}),
				artifact_id,
				bool(artifact_node.get("collected", false)),
				String(artifact_node.get("collected_by_faction_id", ""))
			),
		]

	var encounter = _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		var encounter_data = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
		return "Hostile Contact\nCoords %d,%d | Terrain %s\n%s\n%s\n%s\n%s\n%s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			route_line,
			String(encounter_data.get("name", "Skirmish host")),
			OverworldRules.describe_encounter_object_surface(encounter),
			OverworldRules.describe_encounter_readability_surface(_session, encounter),
			OverworldRules.describe_encounter_pressure(_session, encounter),
		]

	var heroes_here = _hero_entries_at(_selected_tile.x, _selected_tile.y)
	if not heroes_here.is_empty():
		var names = []
		for entry in heroes_here:
			if entry is Dictionary:
				names.append(String(entry.get("name", "Hero")))
		return "Command Marker\nCoords %d,%d | Terrain %s\n%s\nReserve commanders: %s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			route_line,
			", ".join(names),
		]

	return "Open Ground\nCoords %d,%d | Terrain %s\n%s\nSelect a route and march the active hero through the frontier." % [
		_selected_tile.x,
		_selected_tile.y,
		terrain,
		route_line,
	]

func _update_map_tooltip() -> void:
	var profile_start := _profile_begin("map_tooltip")
	_map_view.tooltip_text = _map_tooltip_text()
	_profile_end("map_tooltip", profile_start, {
		"hovered_tile": {"x": _hovered_tile.x, "y": _hovered_tile.y},
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
	})

func _map_tooltip_text() -> String:
	if _tile_in_bounds(_hovered_tile) and _hovered_tile != _selected_tile:
		return _tile_visibility_tooltip(_hovered_tile, "Hover")
	var hero_pos = OverworldRules.hero_position(_session)
	var primary_action := _current_primary_action()
	if _selected_tile == hero_pos:
		if not primary_action.is_empty():
			return "%s | Enter: %s" % [
				OverworldRules.describe_visibility(_session),
				_short_action_label(String(primary_action.get("label", "Action")), 22),
			]
		return "%s | Select a mapped destination on the map." % OverworldRules.describe_visibility(_session)
	var route_tooltip := _route_decision_tooltip(_selected_route_decision_surface())
	if route_tooltip != "":
		if not _resource_node_at(_selected_tile.x, _selected_tile.y).is_empty():
			return "%s\n%s" % [route_tooltip, _tile_visibility_tooltip(_selected_tile, "Selected")]
		return route_tooltip
	return "Selected %d,%d | No clear route from the active hero." % [_selected_tile.x, _selected_tile.y]

func _tile_visibility_tooltip(tile: Vector2i, prefix: String) -> String:
	if not OverworldRules.is_tile_explored(_session, tile.x, tile.y):
		return "%s %d,%d | Unexplored ground | Scout closer" % [prefix, tile.x, tile.y]
	var terrain := _terrain_name_at(tile.x, tile.y)
	if not OverworldRules.is_tile_visible(_session, tile.x, tile.y):
		return "%s %d,%d | Mapped %s | Out of scout net" % [prefix, tile.x, tile.y, terrain]
	var hover_order := _hover_tile_order_cue(tile)
	var town := _town_at(tile.x, tile.y)
	if not town.is_empty():
		var town_data := ContentService.get_town(String(town.get("town_id", "")))
		return _append_hover_order_cue("%s %d,%d | Town: %s | Owner %s | %s" % [
			prefix,
			tile.x,
			tile.y,
			String(town_data.get("name", town.get("placement_id", "Town"))),
			String(town.get("owner", "neutral")).capitalize(),
			terrain,
		], hover_order)
	var node := _resource_node_at(tile.x, tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var surface := OverworldRules.describe_resource_site_surface(_session, node, site)
		var interaction_surface := OverworldRules.describe_resource_site_interaction_surface(node, site)
		var control_summary := OverworldRules.describe_resource_site_control_summary(_session, node, site)
		var recruit_summary := OverworldRules.describe_recruit_source_compact(_session, node, site)
		return _append_hover_order_cue("%s %d,%d | %s | %s%s%s%s" % [
			prefix,
			tile.x,
			tile.y,
			String(site.get("name", "Frontier site")),
			surface,
			"" if interaction_surface == "" else " | %s" % interaction_surface,
			"" if control_summary == "" else " | %s" % control_summary,
			"" if recruit_summary == "" else " | %s" % recruit_summary,
		], hover_order)
	var encounter := _encounter_at(tile.x, tile.y)
	if not encounter.is_empty():
		var object_surface := OverworldRules.describe_encounter_object_surface(encounter)
		var readability := OverworldRules.describe_encounter_compact_readability(_session, encounter)
		return _append_hover_order_cue("%s %d,%d | %s | %s%s%s" % [
			prefix,
			tile.x,
			tile.y,
			OverworldRules.encounter_display_name(encounter),
			terrain,
			"" if object_surface == "" else " | %s" % object_surface,
			"" if readability == "" else " | %s" % readability,
		], hover_order)
	var artifact_node := _artifact_node_at(tile.x, tile.y)
	if not artifact_node.is_empty():
		var artifact_id := String(artifact_node.get("artifact_id", ""))
		return _append_hover_order_cue("%s %d,%d | Artifact: %s | %s | %s | %s | %s" % [
			prefix,
			tile.x,
			tile.y,
			ArtifactRules.artifact_name(artifact_id),
			ArtifactRules.artifact_reward_role(artifact_id),
			ArtifactRules.artifact_effect_summary(artifact_id),
			ArtifactRules.describe_single_artifact_impact(artifact_id),
			terrain,
		], hover_order)
	return _append_hover_order_cue("%s %d,%d | %s" % [prefix, tile.x, tile.y, terrain], hover_order)

func _append_hover_order_cue(text: String, hover_order: String) -> String:
	if hover_order.strip_edges() == "":
		return text
	return "%s | %s" % [text, hover_order]

func _hover_tile_order_cue(tile: Vector2i) -> String:
	var movement = _session.overworld.get("movement", {})
	var movement_line := "Move %d/%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
	]
	var hero_pos := OverworldRules.hero_position(_session)
	if tile == hero_pos:
		return "Hover order: current hero; %s" % movement_line
	var order := "select route"
	var adjacent := maxi(abs(hero_pos.x - tile.x), abs(hero_pos.y - tile.y)) == 1
	var town := _town_at(tile.x, tile.y)
	if not town.is_empty():
		if String(town.get("owner", "neutral")) == "player":
			order = "select Visit Town"
		elif adjacent:
			order = "select Approach Town"
	var node := _resource_node_at(tile.x, tile.y)
	if not node.is_empty():
		order = "select Secure Site" if adjacent else "select route"
	if not _artifact_node_at(tile.x, tile.y).is_empty():
		order = "select Recover Artifact" if adjacent else "select route"
	if not _encounter_at(tile.x, tile.y).is_empty():
		order = "select Enter Battle" if adjacent else "select route"
	if order == "select route" and OverworldRules.tile_is_blocked(_session, tile.x, tile.y):
		return "Hover order: blocked; %s" % movement_line
	if order == "select route" and _is_adjacent_move_target(hero_pos, tile):
		order = "select March"
	return "Hover order: %s, then commit if ready; %s" % [order, movement_line]

func _selected_route() -> Array:
	var route_state := _ensure_selected_route_state("shell")
	return route_state.get("route_tiles", []) if route_state.get("route_tiles", []) is Array else []

func _selected_route_cache_for_map_view() -> Dictionary:
	return _ensure_selected_route_state("map_view").duplicate(true)

func _ensure_selected_route_state(requester: String = "shell") -> Dictionary:
	var signature := _selected_route_signature()
	if not _selected_route_state.is_empty() and String(_selected_route_state.get("signature", "")) == signature:
		_profile_add("selected_route_cache_hits", 1)
		_validation_profile["last_selected_route_cache"] = {
			"status": "hit",
			"requester": requester,
			"signature": signature,
			"path_tiles": int((_selected_route_state.get("route_tiles", []) if _selected_route_state.get("route_tiles", []) is Array else []).size()),
		}
		return _selected_route_state

	_profile_add("selected_route_cache_misses", 1)
	var hero_pos := OverworldRules.hero_position(_session)
	var route: Array = []
	if not _tile_in_bounds(_selected_tile):
		route = []
	elif _selected_tile == hero_pos:
		route = [hero_pos]
	else:
		route = _build_path(hero_pos, _selected_tile)
	_store_selected_route_state(route, "miss:%s" % requester, signature)
	return _selected_route_state

func _store_selected_route_state(route: Array, source: String, signature: String = "") -> void:
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {}) if _session != null else {}
	var movement_current := int(movement.get("current", 0)) if movement is Dictionary else 0
	var movement_max := int(movement.get("max", movement_current)) if movement is Dictionary else movement_current
	var route_signature := signature if signature != "" else _selected_route_signature()
	var route_copy := route.duplicate(true)
	var preview := OverworldRules.route_movement_preview(_session, route_copy, movement_current)
	_selected_route_state_generation += 1
	_selected_route_state = {
		"valid": true,
		"signature": route_signature,
		"generation": _selected_route_state_generation,
		"source": source,
		"selected_tile": _debug_tile_payload(_selected_tile),
		"start_tile": _debug_tile_payload(hero_pos),
		"hero_tile": _debug_tile_payload(hero_pos),
		"movement_current": movement_current,
		"movement_max": movement_max,
		"map_size": {"x": _map_size.x, "y": _map_size.y},
		"session_signature": _selected_route_session_signature(),
		"route_tiles": route_copy,
		"route_preview": preview.duplicate(true),
	}
	_validation_profile["last_selected_route_cache"] = {
		"status": "stored",
		"source": source,
		"signature": route_signature,
		"generation": _selected_route_state_generation,
		"path_tiles": route_copy.size(),
		"reachable_steps": int(preview.get("reachable_steps", 0)),
		"unreachable_steps": int(preview.get("unreachable_steps", 0)),
	}

func _adopt_selected_route_after_execution(route: Array, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_invalidate_selected_route_state("route_execution_failed")
		return
	var route_steps: Array = result.get("route_steps", []) if result.get("route_steps", []) is Array else []
	var executed_steps := route_steps.size()
	if executed_steps <= 0:
		_invalidate_selected_route_state("route_execution_no_steps")
		return
	var hero_pos := OverworldRules.hero_position(_session)
	var remaining_route: Array = []
	for index in range(executed_steps, route.size()):
		remaining_route.append(route[index])
	if remaining_route.is_empty() or not (remaining_route[0] is Vector2i) or remaining_route[0] != hero_pos:
		remaining_route.push_front(hero_pos)
	if remaining_route.size() > 0 and remaining_route[remaining_route.size() - 1] is Vector2i:
		var destination: Vector2i = remaining_route[remaining_route.size() - 1]
		if destination != _selected_tile and _tile_in_bounds(_selected_tile):
			_invalidate_selected_route_state("route_execution_destination_changed")
			return
	_store_selected_route_state(remaining_route, "route_execution_remaining")

func _invalidate_selected_route_state(reason: String = "") -> void:
	_invalidate_selected_route_action_surfaces(reason)
	if _selected_route_state.is_empty():
		return
	_selected_route_state.clear()
	_selected_route_state_generation += 1
	if reason != "":
		_validation_profile["last_selected_route_cache"] = {"status": "invalidated", "reason": reason}

func _invalidate_selected_route_action_surfaces(reason: String = "") -> void:
	_selected_context_actions_cache.clear()
	_selected_context_actions_cache_signature = ""
	_selected_route_decision_surface_cache.clear()
	_selected_route_decision_surface_cache_signature = ""
	_selected_route_destination_actions_cache.clear()
	_selected_route_destination_actions_cache_signature = ""
	if reason != "":
		_validation_profile["last_selected_context_actions_cache"] = {"status": "invalidated", "reason": reason}
		_validation_profile["last_selected_route_decision_surface_cache"] = {"status": "invalidated", "reason": reason}
		_validation_profile["last_selected_route_destination_action_cache"] = {"status": "invalidated", "reason": reason}

func _selected_route_destination_action_signature() -> String:
	return _selected_route_action_surface_signature()

func _selected_route_action_surface_signature() -> String:
	if _session == null:
		return "session:null"
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {})
	var movement_current := int(movement.get("current", 0)) if movement is Dictionary else 0
	var movement_max := int(movement.get("max", movement_current)) if movement is Dictionary else movement_current
	var route_generation := int(_selected_route_state.get("generation", _selected_route_state_generation)) if _selected_route_state is Dictionary else _selected_route_state_generation
	var route_valid := bool(_selected_route_state.get("valid", false)) if _selected_route_state is Dictionary else false
	return "|".join([
		"route_action:min:v2",
		_selected_route_session_signature(),
		"active_hero:%s" % String(_session.overworld.get("active_hero_id", "")),
		"hero:%d,%d" % [hero_pos.x, hero_pos.y],
		"move:%d/%d" % [movement_current, movement_max],
		"selected:%d,%d" % [_selected_tile.x, _selected_tile.y],
		"route_gen:%d" % route_generation,
		"route_valid:%s" % ("1" if route_valid else "0"),
		_selected_route_destination_state_signature(_selected_tile),
	])

func _selected_route_signature() -> String:
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {}) if _session != null else {}
	var movement_current := int(movement.get("current", 0)) if movement is Dictionary else 0
	var movement_max := int(movement.get("max", movement_current)) if movement is Dictionary else movement_current
	return "|".join([
		"selected_route:min:v2",
		_selected_route_session_signature(),
		"selected:%d,%d" % [_selected_tile.x, _selected_tile.y],
		"hero:%d,%d" % [hero_pos.x, hero_pos.y],
		"move:%d/%d" % [movement_current, movement_max],
		_selected_route_destination_state_signature(_selected_tile),
	])

func _selected_route_destination_state_signature(tile: Vector2i) -> String:
	if not _tile_in_bounds(tile):
		return "dest:out_of_bounds:%d,%d" % [tile.x, tile.y]
	var blocked := OverworldRules.tile_is_blocked(_session, tile.x, tile.y)
	return "|".join([
		"dest:%d,%d" % [tile.x, tile.y],
		"blocked:%s" % ("1" if blocked else "0"),
		"interaction:%s" % _selected_route_destination_interaction_signature(tile),
	])

func _selected_route_destination_interaction_signature(tile: Vector2i) -> String:
	var town := _town_at(tile.x, tile.y)
	if not town.is_empty():
		return "town:%s:%s:%s" % [
			String(town.get("placement_id", "")),
			String(town.get("town_id", "")),
			String(town.get("owner", "neutral")),
		]
	var node := _resource_node_at(tile.x, tile.y)
	if not node.is_empty():
		return "resource:%s:%s:%s:%s" % [
			String(node.get("placement_id", "")),
			String(node.get("site_id", "")),
			"1" if bool(node.get("collected", false)) else "0",
			String(node.get("collected_by_faction_id", "")),
		]
	var artifact_node := _artifact_node_at(tile.x, tile.y)
	if not artifact_node.is_empty():
		return "artifact:%s:%s:%s" % [
			String(artifact_node.get("placement_id", "")),
			String(artifact_node.get("artifact_id", "")),
			"1" if bool(artifact_node.get("collected", false)) else "0",
		]
	var encounter := _encounter_at(tile.x, tile.y)
	if not encounter.is_empty():
		return "encounter:%s:%s:%s" % [
			String(encounter.get("placement_id", encounter.get("id", ""))),
			String(encounter.get("encounter_id", "")),
			"1" if bool(encounter.get("resolved", false)) else "0",
		]
	return "open"

func _selected_route_session_signature() -> String:
	if _session == null:
		return "session:null"
	var identity := [
		String(_session.session_id),
		String(_session.scenario_id),
		String(_session.difficulty),
		String(_session.launch_mode),
		String(_session.game_state),
		String(_session.scenario_status),
		String(_session.overworld.get("active_hero_id", "")),
	]
	var materialization = _session.flags.get("generated_random_map_materialization", {})
	if materialization is Dictionary:
		identity.append(String(materialization.get("materialized_map_signature", "")))
	var generated_identity = _session.overworld.get("generated_random_map_identity", {})
	if generated_identity is Dictionary:
		identity.append(String(generated_identity.get("materialized_map_signature", "")))
	return "session:%s" % "|".join(identity)

func _selected_route_map_signature() -> String:
	_profile_add("selected_route_broad_map_signature_calls", 1)
	if _refresh_cache.has("selected_route_map_signature"):
		return String(_refresh_cache["selected_route_map_signature"])
	var signature := int(2166136261)
	signature = int(((signature * 16777619) + _map_size.x + 1013904223) & 0x7fffffff)
	signature = int(((signature * 16777619) + _map_size.y + 1013904223) & 0x7fffffff)
	signature = int(((signature * 16777619) + _map_data.size() + 1013904223) & 0x7fffffff)
	for row in _map_data:
		signature = int(((signature * 16777619) + hash(var_to_str(row)) + 1013904223) & 0x7fffffff)
	var result := "map:%d" % signature
	_refresh_cache["selected_route_map_signature"] = result
	return result

func _selected_route_topology_signature() -> String:
	_profile_add("selected_route_broad_topology_signature_calls", 1)
	if _session == null:
		return "topology:null"
	if _refresh_cache.has("selected_route_topology_signature"):
		return String(_refresh_cache["selected_route_topology_signature"])
	var overworld := _session.overworld
	var signature := int(2166136261)
	signature = _combine_selected_route_signature(signature, _route_array_signature(overworld.get("towns", []), ["placement_id", "town_id", "owner", "garrison", "front_state", "occupation_state"]))
	signature = _combine_selected_route_signature(signature, _route_array_signature(overworld.get("resource_nodes", []), [
		"placement_id",
		"site_id",
		"object_id",
		"collected",
		"collected_by_faction_id",
		"body_tiles",
		"visit_tile",
		"interaction_tiles",
		"response_until_day",
		"response_commander_id",
		"delivery_target_kind",
		"delivery_target_id",
		"delivery_arrival_day",
		"delivery_manifest",
	]))
	signature = _combine_selected_route_signature(signature, _route_array_signature(overworld.get("artifact_nodes", []), ["placement_id", "artifact_id", "collected", "collected_by_faction_id"]))
	signature = _combine_selected_route_signature(signature, _route_array_signature(overworld.get("encounters", []), ["placement_id", "encounter_id", "id", "resolved", "spawned_by_faction_id", "enemy_commander_state", "army"]))
	signature = _combine_selected_route_signature(signature, _route_array_signature(overworld.get("resolved_encounters", []), ["placement_id", "encounter_id", "id"]))
	signature = _combine_selected_route_signature(signature, _route_array_signature(overworld.get("player_heroes", []), ["id", "is_active", "is_primary"]))
	var result := "topology:%d" % signature
	_refresh_cache["selected_route_topology_signature"] = result
	return result

func _route_array_signature(values: Variant, fields: Array) -> int:
	if not (values is Array):
		return hash(typeof(values))
	var signature := int(2166136261)
	signature = _combine_selected_route_signature(signature, values.size())
	for value in values:
		if not (value is Dictionary):
			signature = _combine_selected_route_signature(signature, hash(var_to_str(value)))
			continue
		var entry: Dictionary = value
		var position = entry.get("position", {})
		var x = int(entry.get("x", position.get("x", -1) if position is Dictionary else -1))
		var y = int(entry.get("y", position.get("y", -1) if position is Dictionary else -1))
		signature = _combine_selected_route_signature(signature, x)
		signature = _combine_selected_route_signature(signature, y)
		for field in fields:
			signature = _combine_selected_route_signature(signature, hash(str(entry.get(str(field), ""))))
	return signature

func _combine_selected_route_signature(signature: int, value: int) -> int:
	return int(((signature * 16777619) + value + 1013904223) & 0x7fffffff)

func _build_path(start: Vector2i, goal: Vector2i) -> Array:
	var debug_timing_enabled := _debug_route_timing_active()
	var debug_profile_start := _profile_begin("route_bfs") if debug_timing_enabled else 0
	if not _tile_in_bounds(goal):
		_debug_finish_route_bfs_profile(debug_timing_enabled, debug_profile_start, start, goal, "goal_out_of_bounds", 0, 0, 0, 0)
		return []
	if start == goal:
		_debug_finish_route_bfs_profile(debug_timing_enabled, debug_profile_start, start, goal, "same_tile", 1, 1, 0, 0)
		return [start]
	if OverworldRules.tile_is_blocked(_session, goal.x, goal.y):
		_debug_finish_route_bfs_profile(debug_timing_enabled, debug_profile_start, start, goal, "goal_blocked", 0, 0, 1, 0)
		return []
	var queue: Array = [start]
	var queue_index := 0
	var visited = {_tile_key(start): true}
	var came_from = {_tile_key(start): start}
	var found = false
	var blocked_tile_lookup_count := 1 if debug_timing_enabled else 0
	var enqueued_count := 1 if debug_timing_enabled else 0

	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		if current == goal:
			found = true
			break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if not _tile_in_bounds(next):
				continue
			if debug_timing_enabled:
				blocked_tile_lookup_count += 1
			if OverworldRules.tile_is_blocked(_session, next.x, next.y):
				continue
			if next != goal and OverworldRules.tile_has_route_interaction(_session, next.x, next.y):
				continue
			var key = _tile_key(next)
			if visited.has(key):
				continue
			visited[key] = true
			came_from[key] = current
			queue.append(next)
			if debug_timing_enabled:
				enqueued_count += 1

	if not found:
		_debug_finish_route_bfs_profile(debug_timing_enabled, debug_profile_start, start, goal, "not_found", 0, visited.size(), blocked_tile_lookup_count, enqueued_count)
		return []

	var path: Array = [goal]
	var walker: Vector2i = goal
	while walker != start:
		walker = came_from.get(_tile_key(walker), start)
		path.push_front(walker)
	_debug_finish_route_bfs_profile(debug_timing_enabled, debug_profile_start, start, goal, "found", path.size(), visited.size(), blocked_tile_lookup_count, enqueued_count)
	return path

func _tile_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _map_size.x and tile.y < _map_size.y

func _is_adjacent_move_target(hero_pos: Vector2i, tile: Vector2i) -> bool:
	if maxi(abs(hero_pos.x - tile.x), abs(hero_pos.y - tile.y)) != 1:
		return false
	return not OverworldRules.tile_is_blocked(_session, tile.x, tile.y)

func _ensure_selected_tile() -> void:
	if not _tile_in_bounds(_selected_tile):
		_select_hero_tile()

func _select_hero_tile() -> void:
	_set_selected_tile(OverworldRules.hero_position(_session))

func _set_selected_tile(tile: Vector2i) -> void:
	var route_tile := _selection_route_tile(tile)
	if _selected_tile == route_tile:
		return
	_selected_tile = route_tile
	_invalidate_selected_route_state("selected_tile_changed")
	_invalidate_refresh_cache()
	var dirty_phases := [
		REFRESH_PHASE_MAP_VIEW,
		REFRESH_PHASE_CONTEXT_ROUTE,
	]
	if route_tile == OverworldRules.hero_position(_session):
		dirty_phases.append(REFRESH_PHASE_CONTEXT_ACTIONS)
	_mark_refresh_dirty(dirty_phases, "selected_tile_changed")

func _invalidate_refresh_cache(preserve_selected_route_signatures: bool = false) -> void:
	if preserve_selected_route_signatures:
		var preserved := {}
		for key in ["selected_route_map_signature", "selected_route_topology_signature"]:
			if _refresh_cache.has(key):
				preserved[key] = _refresh_cache[key]
		_refresh_cache.clear()
		for key in preserved.keys():
			_refresh_cache[key] = preserved[key]
		return
	_refresh_cache.clear()

func _town_at(x: int, y: int) -> Dictionary:
	var cache_key := "town_at:%d,%d" % [x, y]
	if _refresh_cache.has(cache_key):
		return _refresh_cache[cache_key]
	for town in _session.overworld.get("towns", []):
		if town is Dictionary and int(town.get("x", -1)) == x and int(town.get("y", -1)) == y:
			_refresh_cache[cache_key] = town
			return town
	_refresh_cache[cache_key] = {}
	return {}

func _resource_node_at(x: int, y: int) -> Dictionary:
	var cache_key := "resource_node_at:%d,%d" % [x, y]
	if _refresh_cache.has(cache_key):
		return _refresh_cache[cache_key]
	var tile := Vector2i(x, y)
	for node in _active_resource_nodes():
		if _resource_node_matches_interaction_tile(node, tile):
			_refresh_cache[cache_key] = node
			return node
	for node in _active_resource_nodes():
		if _resource_node_contains_visual_tile(node, tile):
			_refresh_cache[cache_key] = node
			return node
	_refresh_cache[cache_key] = {}
	return {}

func _active_resource_nodes() -> Array:
	if _refresh_cache.has("active_resource_nodes"):
		return _refresh_cache["active_resource_nodes"]
	var nodes := []
	for node in _session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		if bool(site.get("persistent_control", false)) or not bool(node.get("collected", false)):
			nodes.append(node)
	_refresh_cache["active_resource_nodes"] = nodes
	return nodes

func _selection_route_tile(tile: Vector2i) -> Vector2i:
	var selection_started_usec := _debug_phase_begin("tile_object_selection_resolution")
	var node := _resource_node_at(tile.x, tile.y)
	if node.is_empty():
		_debug_phase_end("tile_object_selection_resolution", selection_started_usec, {"raw": _debug_tile_payload(tile), "resolved": _debug_tile_payload(tile), "object": false})
		return tile
	var resolved := _resource_node_route_tile(node, tile)
	_debug_phase_end("tile_object_selection_resolution", selection_started_usec, {
		"raw": _debug_tile_payload(tile),
		"resolved": _debug_tile_payload(resolved),
		"object": true,
		"placement_id": String(node.get("placement_id", "")),
	})
	return resolved

func _resource_node_route_tile(node: Dictionary, fallback: Vector2i) -> Vector2i:
	var body_visit_started_usec := _debug_phase_begin("body_visit_tile_resolution")
	var surface := _resource_node_pathing_surface(node)
	var interaction_tiles: Array = surface.get("interaction_tiles", []) if surface.get("interaction_tiles", []) is Array else []
	for value in interaction_tiles:
		if not (value is Dictionary):
			continue
		var candidate := Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
		if not OverworldRules.tile_is_blocked(_session, candidate.x, candidate.y):
			_debug_phase_end("body_visit_tile_resolution", body_visit_started_usec, {
				"fallback": _debug_tile_payload(fallback),
				"resolved": _debug_tile_payload(candidate),
				"interaction_tile_count": interaction_tiles.size(),
			})
			return candidate
	_debug_phase_end("body_visit_tile_resolution", body_visit_started_usec, {
		"fallback": _debug_tile_payload(fallback),
		"resolved": _debug_tile_payload(fallback),
		"interaction_tile_count": interaction_tiles.size(),
	})
	return fallback

func _resource_node_matches_interaction_tile(node: Dictionary, tile: Vector2i) -> bool:
	var surface := _resource_node_pathing_surface(node)
	var interaction_tiles: Array = surface.get("interaction_tiles", []) if surface.get("interaction_tiles", []) is Array else []
	for value in interaction_tiles:
		if value is Dictionary and int(value.get("x", -999)) == tile.x and int(value.get("y", -999)) == tile.y:
			return true
	return false

func _resource_node_contains_visual_tile(node: Dictionary, tile: Vector2i) -> bool:
	var surface := _resource_node_pathing_surface(node)
	var footprint: Dictionary = surface.get("footprint", {}) if surface.get("footprint", {}) is Dictionary else {}
	var origin: Dictionary = footprint.get("origin", {}) if footprint.get("origin", {}) is Dictionary else {}
	var width := maxi(1, int(footprint.get("width", 1)))
	var height := maxi(1, int(footprint.get("height", 1)))
	var origin_x := int(origin.get("x", node.get("x", 0)))
	var origin_y := int(origin.get("y", node.get("y", 0)))
	if tile.x >= origin_x and tile.x < origin_x + width and tile.y >= origin_y and tile.y < origin_y + height:
		return true
	var body_tiles: Array = surface.get("body_tiles", []) if surface.get("body_tiles", []) is Array else []
	for value in body_tiles:
		if value is Dictionary and int(value.get("x", -999)) == tile.x and int(value.get("y", -999)) == tile.y:
			return true
	return int(node.get("x", -1)) == tile.x and int(node.get("y", -1)) == tile.y

func _resource_node_pathing_surface(node: Dictionary) -> Dictionary:
	var placement_id := String(node.get("placement_id", ""))
	if placement_id == "":
		return {}
	return OverworldRules.overworld_object_placement_pathing_surface(_session, placement_id)

func _artifact_node_at(x: int, y: int) -> Dictionary:
	var cache_key := "artifact_node_at:%d,%d" % [x, y]
	if _refresh_cache.has(cache_key):
		return _refresh_cache[cache_key]
	for node in _session.overworld.get("artifact_nodes", []):
		if node is Dictionary and not bool(node.get("collected", false)) and int(node.get("x", -1)) == x and int(node.get("y", -1)) == y:
			_refresh_cache[cache_key] = node
			return node
	_refresh_cache[cache_key] = {}
	return {}

func _encounter_at(x: int, y: int) -> Dictionary:
	var cache_key := "encounter_at:%d,%d" % [x, y]
	if _refresh_cache.has(cache_key):
		return _refresh_cache[cache_key]
	for encounter in _session.overworld.get("encounters", []):
		if encounter is Dictionary and int(encounter.get("x", -1)) == x and int(encounter.get("y", -1)) == y:
			if not OverworldRules.is_encounter_resolved(_session, encounter):
				_refresh_cache[cache_key] = encounter
				return encounter
	_refresh_cache[cache_key] = {}
	return {}

func _rememberable_encounter_at(x: int, y: int) -> Dictionary:
	for encounter in _session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != "":
			continue
		if int(encounter.get("x", -1)) == x and int(encounter.get("y", -1)) == y:
			if not OverworldRules.is_encounter_resolved(_session, encounter):
				return encounter
	return {}

func _hero_entries_at(x: int, y: int) -> Array:
	var entries = []
	for entry in HeroCommandRules.hero_positions(_session):
		if entry is Dictionary and int(entry.get("x", -1)) == x and int(entry.get("y", -1)) == y:
			entries.append(entry)
	return entries

func _terrain_name_at(x: int, y: int) -> String:
	if y < 0 or y >= _map_data.size():
		return "Unknown terrain"
	var row = _map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return "Unknown terrain"
	match String(row[x]):
		"grass":
			return "Grassland"
		"forest":
			return "Forest"
		"water":
			return "Sea"
		_:
			var terrain = String(row[x])
			return terrain.capitalize() if terrain != "" else "Open ground"

func _terrain_memory_label(x: int, y: int) -> String:
	if OverworldRules.tile_is_blocked(_session, x, y):
		return "~"
	match _terrain_name_at(x, y):
		"Forest":
			return "F"
		"Grassland":
			return "."
		"Sea":
			return "~"
		_:
			var terrain = _terrain_name_at(x, y)
			return terrain.left(1).capitalize() if terrain != "" else "."

func _memory_cell_color(x: int, y: int) -> Color:
	if OverworldRules.tile_is_blocked(_session, x, y):
		return Color(0.14, 0.20, 0.26, 1.0)
	match _terrain_name_at(x, y):
		"Forest":
			return Color(0.16, 0.22, 0.16, 1.0)
		"Grassland":
			return Color(0.20, 0.25, 0.18, 1.0)
		"Sea":
			return Color(0.12, 0.16, 0.22, 1.0)
		_:
			return Color(0.18, 0.19, 0.20, 1.0)

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _duplicate_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

func _validation_enemy_pressure_states() -> Array:
	var rows := []
	var enemy_states = _session.overworld.get("enemy_states", [])
	if not (enemy_states is Array):
		return rows
	for state in enemy_states:
		if not (state is Dictionary):
			continue
		rows.append(
			{
				"faction_id": String(state.get("faction_id", "")),
				"pressure": int(state.get("pressure", 0)),
				"posture": String(state.get("posture", "")),
				"active_raid_count": int(state.get("active_raid_count", 0)),
				"siege_progress": int(state.get("siege_progress", 0)),
			}
		)
	return rows

func _validation_carryover_flags() -> Dictionary:
	var flags := {}
	for flag_key_value in _session.flags.keys():
		var flag_key := String(flag_key_value)
		if not flag_key.begins_with("carryover_"):
			continue
		flags[flag_key] = bool(_session.flags.get(flag_key, false))
	return flags

func _validation_commander_state() -> Dictionary:
	var hero := _duplicate_dictionary(_session.overworld.get("hero", {}))
	var spellbook := _duplicate_dictionary(hero.get("spellbook", {}))
	var mana := _duplicate_dictionary(spellbook.get("mana", {}))
	return {
		"hero_id": String(hero.get("id", "")),
		"hero_name": String(hero.get("name", "")),
		"level": int(hero.get("level", 1)),
		"experience": int(hero.get("experience", 0)),
		"next_level_experience": int(hero.get("next_level_experience", 250)),
		"command": _validation_command_state(hero.get("command", {})),
		"specialties": _validation_string_array(hero.get("specialties", [])),
		"pending_specialty_choices": _validation_string_array(hero.get("pending_specialty_choices", [])),
		"spell_ids": _validation_string_array(spellbook.get("known_spell_ids", [])),
		"mana": {
			"current": int(mana.get("current", 0)),
			"max": int(mana.get("max", 0)),
		},
		"artifact_ids": _validation_string_array(ArtifactRules.owned_artifact_ids(hero)),
		"artifacts": ArtifactRules.normalize_hero_artifacts(hero.get("artifacts", {})),
		"army": _validation_army_state(hero.get("army", _session.overworld.get("army", {}))),
	}

func _validation_army_state(value: Variant) -> Dictionary:
	var army := _duplicate_dictionary(value)
	var stacks := []
	var stack_values = army.get("stacks", [])
	if stack_values is Array:
		for stack_value in stack_values:
			if not (stack_value is Dictionary):
				continue
			stacks.append(
				{
					"unit_id": String(stack_value.get("unit_id", "")),
					"count": int(stack_value.get("count", 0)),
				}
			)
	return {
		"army_id": String(army.get("id", "")),
		"army_name": String(army.get("name", "")),
		"stacks": stacks,
	}

func _validation_command_state(value: Variant) -> Dictionary:
	var command := _duplicate_dictionary(value)
	return {
		"attack": int(command.get("attack", 0)),
		"defense": int(command.get("defense", 0)),
		"power": int(command.get("power", 0)),
		"knowledge": int(command.get("knowledge", 0)),
	}

func _validation_string_array(value: Variant) -> Array:
	var items := []
	if value is Array:
		for item_value in value:
			var item := ""
			if item_value is Dictionary:
				var item_dictionary: Dictionary = item_value
				item = String(item_dictionary.get("id", item_dictionary.get("specialty_id", "")))
			else:
				item = str(item_value)
			if item != "" and item not in items:
				items.append(item)
	items.sort()
	return items

func validation_reset_profile(clear_refresh_cache: bool = false) -> void:
	_validation_profile.clear()
	if clear_refresh_cache:
		_invalidate_refresh_cache()
	if _map_view != null and _map_view.has_method("validation_reset_profile"):
		_map_view.call("validation_reset_profile")

func validation_profile_snapshot() -> Dictionary:
	var snapshot := _validation_profile.duplicate(true)
	if _map_view != null and _map_view.has_method("validation_profile_snapshot"):
		snapshot["map_view"] = _map_view.call("validation_profile_snapshot")
	snapshot["last_save_profile"] = SaveService.validation_last_runtime_save_profile()
	return snapshot

func validation_set_force_map_index_rebuild(enabled: bool) -> void:
	if _map_view != null and _map_view.has_method("validation_set_force_index_rebuild"):
		_map_view.call("validation_set_force_index_rebuild", enabled)

func validation_set_force_hover_drawer_sync(enabled: bool) -> void:
	_validation_force_hover_drawer_sync = enabled

func _profile_begin(_name: String) -> int:
	return Time.get_ticks_usec()

func _profile_end(name: String, started_usec: int, details: Dictionary = {}) -> void:
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
	_profile_add("%s_calls" % name, 1)
	_profile_add("%s_usec" % name, elapsed_usec)
	_validation_profile["last_%s_usec" % name] = elapsed_usec
	if not details.is_empty():
		_validation_profile["last_%s" % name] = details.duplicate(true)

func _profile_add(key: String, amount: int) -> void:
	_validation_profile[key] = int(_validation_profile.get(key, 0)) + amount

func _debug_phase_begin(_name: String) -> int:
	if not _debug_command_in_progress:
		return 0
	return Time.get_ticks_usec()

func _debug_phase_end(name: String, started_usec: int, details: Dictionary = {}) -> void:
	if not _debug_command_in_progress or started_usec <= 0:
		return
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
	_debug_record_phase_usec(name, elapsed_usec, details)

func _debug_record_phase_usec(name: String, elapsed_usec: int, details: Dictionary = {}) -> void:
	if not _debug_command_in_progress:
		return
	var profile_name := "cmd_%s" % name
	_profile_add("%s_calls" % profile_name, 1)
	_profile_add("%s_usec" % profile_name, maxi(0, elapsed_usec))
	_validation_profile["last_%s_usec" % profile_name] = maxi(0, elapsed_usec)
	if not details.is_empty():
		_validation_profile["last_%s" % profile_name] = details.duplicate(true)

func _debug_refresh_profile_begin(_name: String) -> int:
	if not _debug_command_in_progress:
		return 0
	return Time.get_ticks_usec()

func _debug_refresh_profile_end(name: String, started_usec: int, details: Dictionary = {}) -> void:
	if started_usec <= 0:
		return
	_profile_end(name, started_usec, details)

func _build_debug_overlay() -> void:
	_debug_overlay_panel = PanelContainer.new()
	_debug_overlay_panel.name = "PathDebugOverlay"
	_debug_overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_overlay_panel.visible = false
	_debug_overlay_panel.custom_minimum_size = Vector2(430.0, 0.0)
	_debug_overlay_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_overlay_panel.position = Vector2(18.0, 18.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.025, 0.03, 0.90)
	panel_style.border_color = Color(0.42, 0.55, 0.62, 0.92)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	_debug_overlay_panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_debug_overlay_panel.add_child(margin)
	_debug_overlay_label = Label.new()
	_debug_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_overlay_label.add_theme_font_size_override("font_size", 12)
	_debug_overlay_label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.91, 1.0))
	_debug_overlay_label.text = "Path Debug (F3)\nNo pathing command captured."
	margin.add_child(_debug_overlay_label)
	add_child(_debug_overlay_panel)
	_debug_overlay_panel.move_to_front()

func _set_debug_overlay_enabled(enabled: bool) -> void:
	_debug_overlay_enabled = enabled
	if _debug_overlay_panel != null:
		_debug_overlay_panel.visible = enabled
		if enabled:
			_debug_overlay_panel.move_to_front()
	_debug_update_overlay_text()

func _debug_begin_path_command(command_type: String, target_tile: Vector2i) -> bool:
	if not _debug_capture_enabled() or _debug_command_in_progress:
		return false
	_debug_command_in_progress = true
	OverworldRules.validation_set_pathing_profile_capture_enabled(true)
	_validation_profile.clear()
	if _map_view != null and _map_view.has_method("validation_reset_profile"):
		_map_view.call("validation_reset_profile")
	if _map_view != null and _map_view.has_method("validation_set_path_detail_profile_enabled"):
		_map_view.call("validation_set_path_detail_profile_enabled", true)
	var save_profile_before: Dictionary = SaveService.validation_last_runtime_save_profile()
	var rules_profile_before: Dictionary = OverworldRules.validation_pathing_profile_snapshot()
	_debug_command_context = {
		"command_type": command_type,
		"raw_target_tile": _debug_tile_payload(target_tile),
		"selected_before": _debug_tile_payload(_selected_tile),
		"selected_tile": _debug_tile_payload(_selected_tile),
		"hero_before": _debug_tile_payload(OverworldRules.hero_position(_session)),
		"started_usec": Time.get_ticks_usec(),
		"save_started_msec_before": int(save_profile_before.get("started_msec", -1)),
		"blocked_index_rebuild_count_before": int(rules_profile_before.get("blocked_index_rebuild_count", 0)),
	}
	return true

func _debug_set_path_command_type(command_type: String) -> void:
	if _debug_command_in_progress:
		_debug_command_context["command_type"] = command_type

func _debug_set_path_command_target(target_tile: Vector2i) -> void:
	if _debug_command_in_progress:
		_debug_command_context["selected_tile"] = _debug_tile_payload(target_tile)

func _debug_finish_path_command() -> void:
	if not _debug_command_in_progress:
		return
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - int(_debug_command_context.get("started_usec", Time.get_ticks_usec())))
	var snapshot := _debug_build_command_snapshot(elapsed_usec)
	_debug_last_command_snapshot = snapshot
	_profile_log_append_command_snapshot(snapshot)
	_debug_command_in_progress = false
	OverworldRules.validation_set_pathing_profile_capture_enabled(false)
	if _map_view != null and _map_view.has_method("validation_set_path_detail_profile_enabled"):
		_map_view.call("validation_set_path_detail_profile_enabled", false)
	_debug_command_context.clear()
	var overlay_update_started_usec := Time.get_ticks_usec()
	_debug_update_overlay_text()
	_debug_last_command_snapshot["debug_overlay_update_ms"] = _debug_usec_to_ms(Time.get_ticks_usec() - overlay_update_started_usec)
	_debug_last_command_snapshot["deferred_wait_start_usec"] = Time.get_ticks_usec()
	call_deferred("_debug_refresh_overlay_after_frame")

func _debug_refresh_overlay_after_frame() -> void:
	var wait_started_usec := int(_debug_last_command_snapshot.get("deferred_wait_start_usec", Time.get_ticks_usec()))
	await get_tree().process_frame
	if _debug_last_command_snapshot.is_empty():
		return
	var deferred_wait_usec := maxi(0, Time.get_ticks_usec() - wait_started_usec)
	_debug_last_command_snapshot = _debug_enrich_command_snapshot(_debug_last_command_snapshot)
	_debug_last_command_snapshot["deferred_frame_wait_ms"] = _debug_usec_to_ms(deferred_wait_usec)
	var overlay_update_started_usec := Time.get_ticks_usec()
	_debug_update_overlay_text()
	_debug_last_command_snapshot["debug_overlay_update_ms"] = _debug_usec_to_ms(
		int(_debug_last_command_snapshot.get("debug_overlay_update_ms", 0.0) * 1000.0) + Time.get_ticks_usec() - overlay_update_started_usec
	)
	_debug_update_overlay_text()

func _debug_build_command_snapshot(elapsed_usec: int) -> Dictionary:
	var snapshot := _debug_command_context.duplicate(true)
	snapshot["total_command_ms"] = _debug_usec_to_ms(elapsed_usec)
	snapshot["hero_after"] = _debug_tile_payload(OverworldRules.hero_position(_session))
	snapshot["profile"] = validation_profile_snapshot()
	snapshot = _debug_enrich_command_snapshot(snapshot)
	return snapshot

func _debug_enrich_command_snapshot(snapshot: Dictionary) -> Dictionary:
	var enriched := snapshot.duplicate(true)
	var profile: Dictionary = validation_profile_snapshot()
	var map_profile: Dictionary = profile.get("map_view", {}) if profile.get("map_view", {}) is Dictionary else {}
	var route_details: Dictionary = profile.get("last_route_bfs", {}) if profile.get("last_route_bfs", {}) is Dictionary else {}
	var map_route_details: Dictionary = map_profile.get("last_path_recompute", {}) if map_profile.get("last_path_recompute", {}) is Dictionary else {}
	var route_cache_details: Dictionary = profile.get("last_selected_route_cache", {}) if profile.get("last_selected_route_cache", {}) is Dictionary else {}
	var map_route_cache_details: Dictionary = map_profile.get("last_selected_route_cache", {}) if map_profile.get("last_selected_route_cache", {}) is Dictionary else {}
	var rules_profile: Dictionary = OverworldRules.validation_pathing_profile_snapshot()
	var save_profile: Dictionary = SaveService.validation_last_runtime_save_profile()
	var save_before := int(enriched.get("save_started_msec_before", -1))
	var save_after := int(save_profile.get("started_msec", -1))
	var save_observed := save_after >= 0 and save_after != save_before
	var blocked_rebuilds_before := int(enriched.get("blocked_index_rebuild_count_before", 0))
	var blocked_rebuilds_after := int(rules_profile.get("blocked_index_rebuild_count", blocked_rebuilds_before))
	var shell_bfs_usec := int(profile.get("route_bfs_usec", 0))
	var map_path_usec := int(map_profile.get("path_recompute_usec", 0))
	enriched["profile"] = profile
	enriched["route_bfs_ms"] = _debug_usec_to_ms(shell_bfs_usec)
	enriched["route_bfs_calls"] = int(profile.get("route_bfs_calls", 0))
	enriched["route_bfs"] = route_details
	enriched["route_cache_hits"] = int(profile.get("selected_route_cache_hits", 0))
	enriched["route_cache_misses"] = int(profile.get("selected_route_cache_misses", 0))
	enriched["route_cache"] = route_cache_details
	enriched["map_view_path_ms"] = _debug_usec_to_ms(map_path_usec)
	enriched["map_view_path"] = map_route_details
	enriched["map_view_route_cache_reused"] = bool(map_route_details.get("cache_reused", false)) or String(map_route_cache_details.get("status", "")) == "reused"
	enriched["map_view_route_cache"] = map_route_cache_details
	enriched["pathfinding_ms"] = _debug_usec_to_ms(shell_bfs_usec if shell_bfs_usec > 0 else map_path_usec)
	enriched["blocked_tile_lookup_count"] = int(route_details.get("blocked_tile_lookup_count", map_route_details.get("blocked_tile_lookup_count", 0)))
	enriched["blocked_index_rebuild_count_delta"] = max(0, blocked_rebuilds_after - blocked_rebuilds_before)
	enriched["blocked_index_rebuild_ms"] = _debug_usec_to_ms(int(rules_profile.get("last_blocked_index_rebuild_usec", 0))) if int(enriched.get("blocked_index_rebuild_count_delta", 0)) > 0 else -1.0
	enriched["blocked_index_tile_count"] = int(rules_profile.get("last_blocked_index_tile_count", 0))
	enriched["refresh_ms"] = _debug_usec_to_ms(int(profile.get("refresh_usec", 0)))
	enriched["refresh_set_map_state_ms"] = _debug_usec_to_ms(int(profile.get("refresh_set_map_state_usec", 0)))
	enriched["map_view_set_map_state_ms"] = _debug_usec_to_ms(int(map_profile.get("set_map_state_usec", 0)))
	enriched["object_index_ms"] = _debug_usec_to_ms(int(map_profile.get("object_index_usec", 0)))
	enriched["object_index_rebuilds"] = int(map_profile.get("object_index_rebuilds", 0))
	enriched["object_index_skips"] = int(map_profile.get("object_index_skips", 0))
	enriched["hero_index_rebuilds"] = int(map_profile.get("hero_index_rebuilds", 0))
	enriched["hero_index_skips"] = int(map_profile.get("hero_index_skips", 0))
	enriched["road_index_ms"] = _debug_usec_to_ms(int(map_profile.get("road_index_usec", 0)))
	enriched["road_index_rebuilds"] = int(map_profile.get("road_index_rebuilds", 0))
	enriched["road_index_skips"] = int(map_profile.get("road_index_skips", 0))
	enriched["draw_session_static_ms"] = _debug_usec_to_ms(int(map_profile.get("draw_session_static_usec", 0)))
	enriched["draw_state_ms"] = _debug_usec_to_ms(int(map_profile.get("draw_state_usec", 0)))
	enriched["draw_dynamic_ms"] = _debug_usec_to_ms(int(map_profile.get("draw_dynamic_usec", 0)))
	enriched["dynamic_tile_checks"] = int(map_profile.get("dynamic_tile_checks", 0))
	enriched["object_presentation_checks"] = int(map_profile.get("object_presentation_checks", 0))
	enriched["terrain_tile_draws"] = int(map_profile.get("terrain_tile_draws", 0))
	enriched["road_tile_draws"] = int(map_profile.get("road_tile_draws", 0))
	var view_metrics: Dictionary = _validation_map_viewport_state()
	var render_cache: Dictionary = view_metrics.get("render_cache", {}) if view_metrics.get("render_cache", {}) is Dictionary else {}
	enriched["dynamic_layer_reason"] = String(render_cache.get("dynamic_reason", "n/a"))
	enriched["dynamic_layer_generation"] = int(render_cache.get("dynamic_generation", 0))
	enriched["refresh_request"] = _profile_log_duplicate_dict(profile.get("last_refresh_request", {}))
	enriched["refresh_dirty_after"] = profile.get("last_refresh_dirty_after", [])
	enriched["refresh_phase_counts"] = _debug_refresh_phase_counts(profile)
	enriched["hero_actions_cache"] = {
		"hits": int(profile.get("hero_actions_cache_hits", 0)),
		"misses": int(profile.get("hero_actions_cache_misses", 0)),
		"last": _profile_log_duplicate_dict(profile.get("last_hero_actions_cache", {})),
	}
	enriched["selected_context_actions_cache"] = {
		"hits": int(profile.get("selected_context_actions_cache_hits", 0)),
		"misses": int(profile.get("selected_context_actions_cache_misses", 0)),
		"last": _profile_log_duplicate_dict(profile.get("last_selected_context_actions_cache", {})),
	}
	enriched["selected_route_decision_surface_cache"] = {
		"hits": int(profile.get("selected_route_decision_surface_cache_hits", 0)),
		"misses": int(profile.get("selected_route_decision_surface_cache_misses", 0)),
		"last": _profile_log_duplicate_dict(profile.get("last_selected_route_decision_surface_cache", {})),
	}
	enriched["route_destination_only_action"] = _profile_log_duplicate_dict(profile.get("last_route_destination_only_action_path", {}))
	enriched["selected_route_destination_action_cache"] = {
		"hits": int(profile.get("selected_route_destination_action_cache_hits", 0)),
		"misses": int(profile.get("selected_route_destination_action_cache_misses", 0)),
		"last": _profile_log_duplicate_dict(profile.get("last_selected_route_destination_action_cache", {})),
	}
	enriched["save_observed"] = save_observed
	enriched["save_profile"] = save_profile if save_observed else {}
	enriched["save_summary"] = _debug_save_summary(save_profile) if save_observed else "none observed"
	var fps := float(Engine.get_frames_per_second())
	enriched["fps"] = fps
	enriched["frame_ms"] = snapped(1000.0 / max(fps, 0.001), 0.001)
	var phase_buckets := _debug_command_phase_buckets(profile)
	var refresh_sections := _debug_refresh_section_buckets(profile)
	enriched["phase_buckets_ms"] = phase_buckets
	enriched["refresh_sections_ms"] = refresh_sections
	enriched["refresh_call_count"] = int(profile.get("refresh_calls", 0))
	enriched["measured_sum_ms"] = _debug_measured_sum_ms(enriched, phase_buckets)
	enriched["unaccounted_ms"] = snapped(float(enriched.get("total_command_ms", 0.0)) - float(enriched.get("measured_sum_ms", 0.0)), 0.001)
	enriched["top_offenders"] = _debug_top_timing_buckets(_debug_top_offender_source_buckets(enriched, phase_buckets, refresh_sections), 6)
	return enriched

func _debug_refresh_phase_counts(profile: Dictionary) -> Dictionary:
	var counts := {}
	for phase in REFRESH_ALL_PHASES:
		var phase_name := String(phase)
		counts[phase_name] = int(profile.get("refresh_phase_%s_calls" % _refresh_phase_bucket(phase_name), 0))
	return counts

func _debug_command_phase_buckets(profile: Dictionary) -> Dictionary:
	var buckets := {}
	for key_value in profile.keys():
		var key := String(key_value)
		if not key.begins_with("cmd_") or not key.ends_with("_usec") or key.begins_with("last_"):
			continue
		var phase_name := key.trim_prefix("cmd_").trim_suffix("_usec")
		buckets[phase_name] = _debug_usec_to_ms(int(profile.get(key, 0)))
	return buckets

func _debug_refresh_section_buckets(profile: Dictionary) -> Dictionary:
	var buckets := {}
	for section in [
		"refresh_read_scope_map_state",
		"refresh_set_map_state",
		"refresh_actions",
		"refresh_hero_actions",
		"refresh_context_actions",
		"refresh_spell_actions",
		"refresh_specialty_actions",
		"refresh_artifact_actions",
		"refresh_generated_surfaces",
		"refresh_header_objective_status_resources",
		"refresh_commitment_rail",
		"refresh_hero_rail",
		"refresh_army_rail",
		"refresh_heroes_rail",
		"refresh_specialty_rail",
		"refresh_spell_rail",
		"refresh_artifact_rail",
		"refresh_frontier_drawer",
		"refresh_context_tile_text",
		"refresh_event_action_context",
		"refresh_end_turn_surface",
		"refresh_tooltip_context_drawers",
	]:
		var usec_key := "%s_usec" % section
		if profile.has(usec_key):
			buckets[section.trim_prefix("refresh_")] = _debug_usec_to_ms(int(profile.get(usec_key, 0)))
	return buckets

func _debug_measured_sum_ms(snapshot: Dictionary, phase_buckets: Dictionary) -> float:
	var sum := 0.0
	for phase in [
		"input_handler_entry",
		"validation_select_entry",
		"tile_object_selection_resolution",
		"route_execution_lookup",
		"movement_rules",
	]:
		sum += float(phase_buckets.get(phase, 0.0))
	sum += float(snapshot.get("refresh_ms", 0.0))
	return snapped(sum, 0.001)

func _debug_top_offender_source_buckets(snapshot: Dictionary, phase_buckets: Dictionary, refresh_sections: Dictionary) -> Dictionary:
	var buckets := {}
	for key_value in phase_buckets.keys():
		buckets["cmd/%s" % String(key_value)] = float(phase_buckets.get(key_value, 0.0))
	buckets["refresh/total"] = float(snapshot.get("refresh_ms", 0.0))
	for key_value in refresh_sections.keys():
		buckets["refresh/%s" % String(key_value)] = float(refresh_sections.get(key_value, 0.0))
	buckets["map_view/set_map_state"] = float(snapshot.get("map_view_set_map_state_ms", 0.0))
	buckets["map_view/object_index"] = float(snapshot.get("object_index_ms", 0.0))
	buckets["map_view/road_index"] = float(snapshot.get("road_index_ms", 0.0))
	buckets["map_view/draw_dynamic"] = float(snapshot.get("draw_dynamic_ms", 0.0))
	buckets["unaccounted"] = max(0.0, float(snapshot.get("unaccounted_ms", 0.0)))
	return buckets

func _debug_top_timing_buckets(buckets: Dictionary, limit: int) -> Array:
	var remaining := buckets.duplicate(true)
	var offenders := []
	while offenders.size() < limit and not remaining.is_empty():
		var best_key := ""
		var best_ms := -1.0
		for key_value in remaining.keys():
			var key := String(key_value)
			var value_ms := float(remaining.get(key, 0.0))
			if value_ms > best_ms:
				best_key = key
				best_ms = value_ms
		if best_key == "" or best_ms <= 0.0:
			break
		offenders.append({"name": best_key, "ms": snapped(best_ms, 0.001)})
		remaining.erase(best_key)
	return offenders

func _debug_update_overlay_text() -> void:
	if _debug_overlay_label == null:
		return
	if not _debug_overlay_enabled:
		return
	if _debug_last_command_snapshot.is_empty():
		_debug_overlay_label.text = "Path Debug (F3)\nNo pathing command captured."
		return
	_debug_overlay_label.text = _debug_overlay_text(_debug_last_command_snapshot)

func _debug_overlay_text(snapshot: Dictionary) -> String:
	var route_status := String(snapshot.get("route_bfs", {}).get("status", snapshot.get("map_view_path", {}).get("status", "n/a"))) if snapshot.get("route_bfs", {}) is Dictionary else "n/a"
	var blocked_index_ms = snapshot.get("blocked_index_rebuild_ms", -1.0)
	var blocked_index_text := "n/a"
	if float(blocked_index_ms) >= 0.0:
		blocked_index_text = "%.3f ms / %d tiles" % [float(blocked_index_ms), int(snapshot.get("blocked_index_tile_count", 0))]
	return "\n".join([
		"Path Debug (F3)",
		"cmd %s | target %s | selected %s" % [
			String(snapshot.get("command_type", "n/a")),
			_debug_tile_text(snapshot.get("raw_target_tile", {})),
			_debug_tile_text(snapshot.get("selected_tile", {})),
		],
		"total %.3f ms | route %.3f ms | status %s" % [
			float(snapshot.get("total_command_ms", 0.0)),
			float(snapshot.get("pathfinding_ms", 0.0)),
			route_status,
		],
		"BFS %.3f ms (%d calls) | lookups %d" % [
			float(snapshot.get("route_bfs_ms", 0.0)),
			int(snapshot.get("route_bfs_calls", 0)),
			int(snapshot.get("blocked_tile_lookup_count", 0)),
		],
		"route cache h%d/m%d | map reuse %s" % [
			int(snapshot.get("route_cache_hits", 0)),
			int(snapshot.get("route_cache_misses", 0)),
			"yes" if bool(snapshot.get("map_view_route_cache_reused", false)) else "no",
		],
		"refresh %.3f ms | set_map_state %.3f/%.3f ms" % [
			float(snapshot.get("refresh_ms", 0.0)),
			float(snapshot.get("refresh_set_map_state_ms", 0.0)),
			float(snapshot.get("map_view_set_map_state_ms", 0.0)),
		],
		"refresh calls %d | measured %.3f ms | unaccounted %.3f ms" % [
			int(snapshot.get("refresh_call_count", 0)),
			float(snapshot.get("measured_sum_ms", 0.0)),
			float(snapshot.get("unaccounted_ms", 0.0)),
		],
		"top %s" % _debug_top_offenders_text(snapshot.get("top_offenders", [])),
		"blocked index %s | rebuilds +%d" % [
			blocked_index_text,
			int(snapshot.get("blocked_index_rebuild_count_delta", 0)),
		],
		"object index %.3f ms | r%d/s%d hero r%d/s%d" % [
			float(snapshot.get("object_index_ms", 0.0)),
			int(snapshot.get("object_index_rebuilds", 0)),
			int(snapshot.get("object_index_skips", 0)),
			int(snapshot.get("hero_index_rebuilds", 0)),
			int(snapshot.get("hero_index_skips", 0)),
		],
		"road index %.3f ms | r%d/s%d" % [
			float(snapshot.get("road_index_ms", 0.0)),
			int(snapshot.get("road_index_rebuilds", 0)),
			int(snapshot.get("road_index_skips", 0)),
		],
		"draw static/state/dyn %.3f/%.3f/%.3f ms | dyn %s #%d" % [
			float(snapshot.get("draw_session_static_ms", 0.0)),
			float(snapshot.get("draw_state_ms", 0.0)),
			float(snapshot.get("draw_dynamic_ms", 0.0)),
			String(snapshot.get("dynamic_layer_reason", "n/a")),
			int(snapshot.get("dynamic_layer_generation", 0)),
		],
		"save %s" % String(snapshot.get("save_summary", "none observed")),
		"deferred %.3f ms | overlay %.3f ms" % [
			float(snapshot.get("deferred_frame_wait_ms", 0.0)),
			float(snapshot.get("debug_overlay_update_ms", 0.0)),
		],
		"fps %.1f | frame %.3f ms" % [float(snapshot.get("fps", 0.0)), float(snapshot.get("frame_ms", 0.0))],
	])

func _debug_top_offenders_text(value: Variant) -> String:
	var offenders: Array = value if value is Array else []
	var parts := []
	for index in range(mini(offenders.size(), 4)):
		var offender: Dictionary = offenders[index] if offenders[index] is Dictionary else {}
		var name := String(offender.get("name", "n/a"))
		var short_name := name
		if short_name.length() > 24:
			short_name = "...%s" % short_name.right(21)
		parts.append("%s %.1f" % [short_name, float(offender.get("ms", 0.0))])
	if parts.is_empty():
		return "n/a"
	return " | ".join(parts)

func _debug_route_timing_active() -> bool:
	return _debug_command_in_progress

func _debug_capture_enabled() -> bool:
	return _debug_overlay_enabled or _profile_log_enabled

func _debug_finish_route_bfs_profile(
	enabled: bool,
	started_usec: int,
	start_tile: Vector2i,
	goal_tile: Vector2i,
	status: String,
	path_size: int,
	visited_count: int,
	blocked_tile_lookup_count: int,
	enqueued_count: int
) -> void:
	if not enabled:
		return
	_profile_end("route_bfs", started_usec, {
		"start": _debug_tile_payload(start_tile),
		"goal": _debug_tile_payload(goal_tile),
		"status": status,
		"path_tiles": path_size,
		"visited_count": visited_count,
		"blocked_tile_lookup_count": blocked_tile_lookup_count,
		"enqueued_count": enqueued_count,
	})

func _debug_save_summary(save_profile: Dictionary) -> String:
	if save_profile.is_empty():
		return "none observed"
	var slot_type := String(save_profile.get("slot_type", "save"))
	var total_ms := int(save_profile.get("total_ms", 0))
	var bytes := int(save_profile.get("written_bytes", 0))
	return "%s %d ms %d bytes" % [slot_type, total_ms, bytes]

func _profile_log_env_enabled() -> bool:
	var value := OS.get_environment("HEROES_OVERWORLD_PROFILE_LOG").strip_edges().to_lower()
	return value in ["1", "true", "yes", "on", "enabled"]

func _profile_log_append_command_snapshot(snapshot: Dictionary) -> void:
	if not _profile_log_enabled:
		return
	var record := _profile_log_record_from_snapshot(snapshot)
	if record.is_empty():
		return
	_profile_log_ensure_directory()
	if not FileAccess.file_exists(OVERWORLD_PROFILE_LOG_PATH):
		var created := FileAccess.open(OVERWORLD_PROFILE_LOG_PATH, FileAccess.WRITE)
		if created == null:
			push_warning("Unable to create overworld profile log at %s: %s" % [OVERWORLD_PROFILE_LOG_PATH, error_string(FileAccess.get_open_error())])
			return
		created.close()
	var file := FileAccess.open(OVERWORLD_PROFILE_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		push_warning("Unable to append overworld profile log at %s: %s" % [OVERWORLD_PROFILE_LOG_PATH, error_string(FileAccess.get_open_error())])
		return
	file.seek_end()
	file.store_string("%s\n" % JSON.stringify(_profile_log_json_safe(record)))
	file.close()

func _profile_log_record_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var profile: Dictionary = snapshot.get("profile", {}) if snapshot.get("profile", {}) is Dictionary else {}
	var map_profile: Dictionary = profile.get("map_view", {}) if profile.get("map_view", {}) is Dictionary else {}
	var route_bfs: Dictionary = snapshot.get("route_bfs", {}) if snapshot.get("route_bfs", {}) is Dictionary else {}
	var map_view_path: Dictionary = snapshot.get("map_view_path", {}) if snapshot.get("map_view_path", {}) is Dictionary else {}
	var phase_buckets: Dictionary = snapshot.get("phase_buckets_ms", {}) if snapshot.get("phase_buckets_ms", {}) is Dictionary else {}
	var route_bfs_status := String(route_bfs.get("status", map_view_path.get("status", "n/a")))
	var route_bfs_path_tiles := int(route_bfs.get("path_tiles", map_view_path.get("path_tiles", 0)))
	var route_bfs_visited := int(route_bfs.get("visited_count", map_view_path.get("visited_count", 0)))
	var route_bfs_enqueued := int(route_bfs.get("enqueued_count", map_view_path.get("enqueued_count", 0)))
	var route_bfs_lookups := int(snapshot.get("blocked_tile_lookup_count", route_bfs.get("blocked_tile_lookup_count", map_view_path.get("blocked_tile_lookup_count", 0))))
	var movement_rules := {}
	if profile.get("last_cmd_movement_rules", {}) is Dictionary:
		movement_rules = profile.get("last_cmd_movement_rules", {}).duplicate(true)
	var route_execution_lookup := {}
	if profile.get("last_cmd_route_execution_lookup", {}) is Dictionary:
		route_execution_lookup = profile.get("last_cmd_route_execution_lookup", {}).duplicate(true)
	var context_dispatch := {}
	if profile.get("last_cmd_context_action_dispatch", {}) is Dictionary:
		context_dispatch = profile.get("last_cmd_context_action_dispatch", {}).duplicate(true)
	var primary_activation := {}
	if profile.get("last_cmd_primary_action_activation", {}) is Dictionary:
		primary_activation = profile.get("last_cmd_primary_action_activation", {}).duplicate(true)
	return {
		"schema": "heroes_like.overworld_profile.v1",
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"monotonic_msec": Time.get_ticks_msec(),
		"session": _profile_log_session_metadata(),
		"command_type": String(snapshot.get("command_type", "")),
		"raw_target": _profile_log_duplicate_dict(snapshot.get("raw_target_tile", {})),
		"selected_target": _profile_log_duplicate_dict(snapshot.get("selected_tile", {})),
		"selected_before": _profile_log_duplicate_dict(snapshot.get("selected_before", {})),
		"hero_before": _profile_log_duplicate_dict(snapshot.get("hero_before", {})),
		"hero_after": _profile_log_duplicate_dict(snapshot.get("hero_after", {})),
		"total_command_ms": float(snapshot.get("total_command_ms", 0.0)),
		"phase_buckets_ms": phase_buckets.duplicate(true),
		"refresh_sections_ms": _profile_log_duplicate_dict(snapshot.get("refresh_sections_ms", {})),
		"route_bfs": {
			"ms": float(snapshot.get("route_bfs_ms", 0.0)),
			"calls": int(snapshot.get("route_bfs_calls", 0)),
			"lookups": route_bfs_lookups,
			"status": route_bfs_status,
			"visited": route_bfs_visited,
			"enqueued": route_bfs_enqueued,
			"path_tiles": route_bfs_path_tiles,
			"details": route_bfs.duplicate(true),
			"map_view_details": map_view_path.duplicate(true),
		},
		"route_cache": {
			"hits": int(snapshot.get("route_cache_hits", 0)),
			"misses": int(snapshot.get("route_cache_misses", 0)),
			"status": String(snapshot.get("route_cache", {}).get("status", "")) if snapshot.get("route_cache", {}) is Dictionary else "",
			"details": _profile_log_duplicate_dict(snapshot.get("route_cache", {})),
			"map_view_reused": bool(snapshot.get("map_view_route_cache_reused", false)),
			"map_view_details": _profile_log_duplicate_dict(snapshot.get("map_view_route_cache", {})),
		},
		"incremental_refresh": {
			"request": _profile_log_duplicate_dict(snapshot.get("refresh_request", {})),
			"dirty_after": snapshot.get("refresh_dirty_after", []),
			"phase_counts": _profile_log_duplicate_dict(snapshot.get("refresh_phase_counts", {})),
			"hero_actions_cache": _profile_log_duplicate_dict(snapshot.get("hero_actions_cache", {})),
			"selected_context_actions_cache": _profile_log_duplicate_dict(snapshot.get("selected_context_actions_cache", {})),
			"selected_route_decision_surface_cache": _profile_log_duplicate_dict(snapshot.get("selected_route_decision_surface_cache", {})),
			"selected_route_destination_action_cache": _profile_log_duplicate_dict(snapshot.get("selected_route_destination_action_cache", {})),
			"route_destination_only_action": _profile_log_duplicate_dict(snapshot.get("route_destination_only_action", {})),
		},
		"map_view_timings_ms": {
			"set_map_state": float(snapshot.get("map_view_set_map_state_ms", 0.0)),
			"path_recompute": float(snapshot.get("map_view_path_ms", 0.0)),
			"draw_session_static": float(snapshot.get("draw_session_static_ms", 0.0)),
			"draw_state": float(snapshot.get("draw_state_ms", 0.0)),
			"draw_dynamic": float(snapshot.get("draw_dynamic_ms", 0.0)),
			"object_index": float(snapshot.get("object_index_ms", 0.0)),
			"road_index": float(snapshot.get("road_index_ms", 0.0)),
		},
		"map_view_counts": {
			"object_index_rebuilds": int(snapshot.get("object_index_rebuilds", 0)),
			"object_index_skips": int(snapshot.get("object_index_skips", 0)),
			"hero_index_rebuilds": int(snapshot.get("hero_index_rebuilds", 0)),
			"hero_index_skips": int(snapshot.get("hero_index_skips", 0)),
			"road_index_rebuilds": int(snapshot.get("road_index_rebuilds", 0)),
			"road_index_skips": int(snapshot.get("road_index_skips", 0)),
			"dynamic_tile_checks": int(snapshot.get("dynamic_tile_checks", 0)),
			"object_presentation_checks": int(snapshot.get("object_presentation_checks", 0)),
			"terrain_tile_draws": int(snapshot.get("terrain_tile_draws", 0)),
			"road_tile_draws": int(snapshot.get("road_tile_draws", 0)),
		},
		"movement_rules": {
			"ms": float(phase_buckets.get("movement_rules", 0.0)),
			"details": movement_rules,
		},
		"route_execution": {
			"lookup_ms": float(phase_buckets.get("route_execution_lookup", 0.0)),
			"lookup_details": route_execution_lookup,
			"last_execution": _last_route_execution.duplicate(true),
		},
		"action_dispatch": {
			"context_action_dispatch_ms": float(phase_buckets.get("context_action_dispatch", 0.0)),
			"context_action_dispatch": context_dispatch,
			"primary_action_activation_ms": float(phase_buckets.get("primary_action_activation", 0.0)),
			"primary_action_activation": primary_activation,
		},
		"save": {
			"observed": bool(snapshot.get("save_observed", false)),
			"summary": String(snapshot.get("save_summary", "none observed")),
			"profile": _profile_log_duplicate_dict(snapshot.get("save_profile", {})),
		},
		"fps": float(snapshot.get("fps", 0.0)),
		"frame_ms": float(snapshot.get("frame_ms", 0.0)),
		"top_offenders": snapshot.get("top_offenders", []),
		"measured_sum_ms": float(snapshot.get("measured_sum_ms", 0.0)),
		"unaccounted_ms": float(snapshot.get("unaccounted_ms", 0.0)),
		"raw_profile": profile.duplicate(true),
	}

func _profile_log_session_metadata() -> Dictionary:
	if _session == null:
		return {}
	var generated_identity = _session.overworld.get("generated_random_map_identity", {})
	var materialization = _session.flags.get("generated_random_map_materialization", {})
	return {
		"session_id": String(_session.session_id),
		"scenario_id": String(_session.scenario_id),
		"difficulty": String(_session.difficulty),
		"launch_mode": String(_session.launch_mode),
		"day": int(_session.day),
		"map_size": {"x": _map_size.x, "y": _map_size.y, "width": _map_size.x, "height": _map_size.y},
		"generated_random_map": bool(_session.flags.get("generated_random_map", false)),
		"generated_identity": generated_identity.duplicate(true) if generated_identity is Dictionary else {},
		"generated_materialization": materialization.duplicate(true) if materialization is Dictionary else {},
	}

func _profile_log_duplicate_dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _profile_log_ensure_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("debug")

func _profile_log_clear() -> Dictionary:
	_profile_log_ensure_directory()
	var file := FileAccess.open(OVERWORLD_PROFILE_LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.close()
	return validation_overworld_profile_log_snapshot()

func _profile_log_record_count() -> int:
	if not FileAccess.file_exists(OVERWORLD_PROFILE_LOG_PATH):
		return 0
	var file := FileAccess.open(OVERWORLD_PROFILE_LOG_PATH, FileAccess.READ)
	if file == null:
		return 0
	var count := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "":
			count += 1
	file.close()
	return count

func _profile_log_last_records(limit: int) -> Array:
	var records := []
	if limit <= 0 or not FileAccess.file_exists(OVERWORLD_PROFILE_LOG_PATH):
		return records
	var file := FileAccess.open(OVERWORLD_PROFILE_LOG_PATH, FileAccess.READ)
	if file == null:
		return records
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			records.append(parsed)
			while records.size() > limit:
				records.pop_front()
	file.close()
	return records

func _profile_log_json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			var dictionary: Dictionary = value
			for key_value in dictionary.keys():
				result[String(key_value)] = _profile_log_json_safe(dictionary.get(key_value))
			return result
		TYPE_ARRAY:
			var result := []
			var array: Array = value
			for item in array:
				result.append(_profile_log_json_safe(item))
			return result
		TYPE_VECTOR2I:
			var tile: Vector2i = value
			return {"x": tile.x, "y": tile.y}
		TYPE_VECTOR2:
			var vector: Vector2 = value
			return {"x": vector.x, "y": vector.y}
		TYPE_COLOR:
			var color: Color = value
			return {"r": color.r, "g": color.g, "b": color.b, "a": color.a}
		_:
			return value

func _debug_tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _debug_tile_text(value: Variant) -> String:
	if value is Dictionary:
		return "%d,%d" % [int(value.get("x", -1)), int(value.get("y", -1))]
	return "n/a"

func _debug_usec_to_ms(usec: int) -> float:
	return snapped(float(maxi(usec, 0)) / 1000.0, 0.001)

func validation_set_debug_overlay_enabled(enabled: bool) -> Dictionary:
	_set_debug_overlay_enabled(enabled)
	return validation_debug_overlay_snapshot()

func validation_set_overworld_profile_log_enabled(enabled: bool, clear_existing: bool = false) -> Dictionary:
	_profile_log_enabled = enabled
	if clear_existing:
		_profile_log_clear()
	return validation_overworld_profile_log_snapshot()

func validation_clear_overworld_profile_log() -> Dictionary:
	return _profile_log_clear()

func validation_overworld_profile_log_path() -> String:
	return OVERWORLD_PROFILE_LOG_PATH

func validation_overworld_profile_log_snapshot() -> Dictionary:
	return {
		"enabled": _profile_log_enabled,
		"path": OVERWORLD_PROFILE_LOG_PATH,
		"absolute_path": ProjectSettings.globalize_path(OVERWORLD_PROFILE_LOG_PATH),
		"record_count": _profile_log_record_count(),
	}

func validation_overworld_profile_log_record_count() -> int:
	return _profile_log_record_count()

func validation_overworld_profile_log_last_records(limit: int = 5) -> Array:
	return _profile_log_last_records(limit)

func validation_debug_overlay_snapshot() -> Dictionary:
	return {
		"enabled": _debug_overlay_enabled,
		"visible": _debug_overlay_panel != null and _debug_overlay_panel.visible,
		"toggle_key": "F3",
		"text": _debug_overlay_label.text if _debug_overlay_label != null else "",
		"last_command": _debug_last_command_snapshot.duplicate(true),
	}

func validation_snapshot() -> Dictionary:
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {})
	var active_context: Dictionary = _cached_active_context()
	var active_town := _validation_active_town_state()
	var selected_town := _validation_selected_town_state()
	var primary_action := _current_primary_action()
	var route_decision := _selected_route_decision_surface()
	var route_target_handoff := _route_target_handoff_surface(route_decision)
	var town_entry_handoff := _town_entry_handoff_surface()
	var primary_order_commit_check := _primary_order_commit_check_surface(primary_action)
	var active_site_order := _active_site_order_surface(primary_action)
	var field_readiness := _field_readiness_surface()
	var end_turn_check := _end_turn_confirmation_surface(field_readiness)
	var event_feed := _event_feed_surface()
	var action_context := _action_context_surface(event_feed, field_readiness)
	var drawer_handoff := _drawer_handoff_surfaces(field_readiness)
	var status_forecast := _status_forecast_surface()
	var command_check := _command_check_surface()
	var specialty_check := _specialty_check_surface()
	var spell_check := _spell_check_surface()
	return {
		"scene_path": scene_file_path,
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"generated_random_map": bool(_session.flags.get("generated_random_map", false)),
		"campaign_id": String(_session.flags.get("campaign_id", "")),
		"campaign_name": String(_session.flags.get("campaign_name", "")),
		"campaign_chapter_label": String(_session.flags.get("campaign_chapter_label", "")),
		"campaign_previous_scenario_id": String(_session.flags.get("campaign_previous_scenario_id", "")),
		"editor_working_copy": bool(_session.flags.get("editor_working_copy", false)),
		"editor_return_model": String(_session.flags.get("editor_return_model", "")),
		"scenario_status": _session.scenario_status,
		"game_state": _session.game_state,
		"day": _session.day,
		"hero_position": {
			"x": hero_pos.x,
			"y": hero_pos.y,
		},
		"movement_current": int(movement.get("current", 0)),
		"movement_max": int(movement.get("max", 0)),
		"status_visible_text": _status_label.text,
		"status_tooltip_text": _status_label.tooltip_text,
		"status_forecast": status_forecast,
		"map_size": {
			"x": _map_size.x,
			"y": _map_size.y,
			"width": _map_size.x,
			"height": _map_size.y,
		},
		"selected_tile": {
			"x": _selected_tile.x,
			"y": _selected_tile.y,
		},
		"context_summary": _cached_focus_tile_text(),
		"context_visible_text": _context_label.text,
		"hero_text": OverworldRules.describe_hero(_session),
		"hero_visible_text": _hero_label.text,
		"hero_tooltip_text": _hero_label.tooltip_text,
		"heroes_text": OverworldRules.describe_heroes(_session),
		"heroes_visible_text": _heroes_label.text,
		"heroes_tooltip_text": _heroes_label.tooltip_text,
		"command_check": command_check,
		"command_check_visible_text": String(command_check.get("visible_text", "")),
		"command_check_tooltip_text": String(command_check.get("tooltip_text", "")),
		"hero_action_surfaces": _validation_control_surfaces(_hero_actions),
		"army_text": OverworldRules.describe_army(_session),
		"army_visible_text": _army_label.text,
		"army_tooltip_text": _army_label.tooltip_text,
		"specialty_text": OverworldRules.describe_specialties(_session),
		"specialty_visible_text": _specialty_label.text,
		"specialty_tooltip_text": _specialty_label.tooltip_text,
		"specialty_check": specialty_check,
		"specialty_check_visible_text": String(specialty_check.get("visible_text", "")),
		"specialty_check_tooltip_text": String(specialty_check.get("tooltip_text", "")),
		"specialty_actions": _validation_specialty_action_payloads(),
		"specialty_action_surfaces": _validation_control_surfaces(_specialty_actions),
		"spellbook_text": OverworldRules.describe_spellbook(_session, SpellRules.CONTEXT_OVERWORLD),
		"spellbook_visible_text": _spell_label.text,
		"spellbook_tooltip_text": _spell_label.tooltip_text,
		"spellbook_rail_text": OverworldRules.describe_spellbook_rail(_session, SpellRules.CONTEXT_OVERWORLD),
		"spell_check": spell_check,
		"spell_check_visible_text": String(spell_check.get("visible_text", "")),
		"spell_check_tooltip_text": String(spell_check.get("tooltip_text", "")),
		"spell_action_surfaces": _validation_control_surfaces(_spell_actions),
		"event_visible_text": _event_label.text,
		"event_tooltip_text": _event_label.tooltip_text,
		"event_feed": event_feed,
		"action_context": action_context,
		"field_readiness": field_readiness,
		"field_return_handoff": _field_return_handoff.duplicate(true),
		"field_return_handoff_visible_text": String(_field_return_handoff.get("visible_text", "")),
		"field_return_handoff_tooltip_text": String(_field_return_handoff.get("tooltip_text", "")),
		"post_action_recap": _last_action_recap.duplicate(true),
		"objective_brief_visible_text": _objective_brief_label.text,
		"objective_brief_tooltip_text": _objective_brief_label.tooltip_text,
		"enemy_activity_summary": _last_enemy_activity_text,
		"turn_resolution_summary": _last_turn_resolution_text,
		"end_turn_forecast": OverworldRules.describe_end_turn_forecast(_session),
		"end_turn_forecast_compact": OverworldRules.describe_end_turn_forecast_compact(_session),
		"end_turn_button_text": _end_turn_button.text,
		"end_turn_tooltip_text": _end_turn_button.tooltip_text,
		"end_turn_confirmation": end_turn_check,
		"drawer_handoff": drawer_handoff,
		"command_drawer_button_text": _open_command_button.text,
		"command_drawer_tooltip_text": _open_command_button.tooltip_text,
		"frontier_drawer_button_text": _open_frontier_button.text,
		"frontier_drawer_tooltip_text": _open_frontier_button.tooltip_text,
		"close_command_tooltip_text": _close_command_button.tooltip_text,
		"close_frontier_tooltip_text": _close_frontier_button.tooltip_text,
		"action_feedback": _validation_action_feedback(),
		"action_feedback_text": _action_feedback_text(),
		"map_cue_text": _map_cue_label.text,
		"map_cue_tooltip_text": _map_cue_label.tooltip_text,
		"selected_route_decision": route_decision,
		"selected_route_decision_text": _route_decision_line(route_decision),
		"selected_route_decision_brief": _duplicate_dictionary(route_decision.get("decision_brief", {})),
		"selected_route_preview": _duplicate_dictionary(route_decision.get("route_preview", {})),
		"last_route_execution": _duplicate_dictionary(_last_route_execution),
		"route_target_handoff": route_target_handoff,
		"route_target_handoff_visible_text": String(route_target_handoff.get("visible_text", "")),
		"route_target_handoff_tooltip_text": String(route_target_handoff.get("tooltip_text", "")),
		"town_entry_handoff": town_entry_handoff,
		"town_entry_handoff_visible_text": String(town_entry_handoff.get("visible_text", "")),
		"town_entry_handoff_tooltip_text": String(town_entry_handoff.get("tooltip_text", "")),
		"active_site_order": active_site_order,
		"active_site_order_visible_text": String(active_site_order.get("visible_text", "")),
		"active_site_order_tooltip_text": String(active_site_order.get("tooltip_text", "")),
		"selected_tile_rail_text": _rail_tile_text(),
		"map_tooltip": _map_tooltip_text(),
		"active_context_type": String(active_context.get("type", "")),
		"primary_action_id": String(primary_action.get("id", "")),
		"primary_action": _validation_action_payload(primary_action),
		"primary_action_button_text": _primary_action_button.text,
		"primary_action_button_disabled": _primary_action_button.disabled,
		"primary_action_button_tooltip_text": _primary_action_button.tooltip_text,
		"primary_order_commit_check": primary_order_commit_check,
		"context_action_ids": _validation_context_action_ids(),
		"spell_actions": _validation_spell_action_payloads(),
		"artifact_text": _artifact_label.text,
		"artifact_tooltip_text": _artifact_label.tooltip_text,
		"artifact_actions": _validation_artifact_action_payloads(),
		"active_town": active_town,
		"selected_town": selected_town,
		"resources": _duplicate_dictionary(_session.overworld.get("resources", {})),
		"commander_state": _validation_commander_state(),
		"carryover_flags": _validation_carryover_flags(),
		"objective_summary": _cached_objective_text(),
		"threat_summary": _cached_frontier_threats(),
		"frontier_watch": _cached_frontier_threats(),
		"enemy_pressure_states": _validation_enemy_pressure_states(),
		"latest_save_summary": SaveService.latest_loadable_summary(),
		"save_surface": AppRouter.active_save_surface(),
		"save_status_visible_text": _save_status_label.text,
		"save_status_tooltip_text": _save_status_label.tooltip_text,
		"map_viewport": _validation_map_viewport_state(),
		"town_presentation_profiles": _validation_town_presentation_profiles(),
		"chrome": _validation_chrome_state(),
		"debug_overlay": validation_debug_overlay_snapshot(),
		"profile": validation_profile_snapshot(),
	}

func _validation_map_viewport_state() -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_view_metrics"):
		return {}
	return _map_view.call("validation_view_metrics")

func _validation_town_presentation_profiles() -> Array:
	if _map_view == null or not _map_view.has_method("validation_town_presentation_profiles"):
		return []
	return _map_view.call("validation_town_presentation_profiles")

func _validation_chrome_state() -> Dictionary:
	return {
		"active_drawer": _active_drawer,
		"command_drawer_visible": _command_panel.visible,
		"frontier_drawer_visible": _frontier_panel.visible,
		"tile_context_visible": _context_panel.visible,
		"order_panel_visible": _commitment_panel.visible,
		"command_spine_visible": _command_spine.visible,
		"has_map_hint": get_node_or_null("%MapHint") != null,
		"has_march_panel": get_node_or_null("%MarchPanel") != null,
		"has_march_direction_buttons": (
			get_node_or_null("%MoveNorth") != null
			or get_node_or_null("%MoveSouth") != null
			or get_node_or_null("%MoveWest") != null
			or get_node_or_null("%MoveEast") != null
		),
		"map_cue_text": _map_cue_label.text,
		"action_feedback": _validation_action_feedback(),
		"frontier_indicator": _frontier_indicator_label.text,
		"command_drawer_button_text": _open_command_button.text,
		"command_drawer_tooltip_text": _open_command_button.tooltip_text,
		"frontier_drawer_button_text": _open_frontier_button.text,
		"frontier_drawer_tooltip_text": _open_frontier_button.tooltip_text,
	}

func _validation_action_feedback() -> Dictionary:
	if _action_feedback.is_empty():
		return {
			"active": false,
			"kind": "",
			"text": "",
			"full_text": "",
			"post_action_recap": {},
			"sequence": 0,
			"cue_chip_text": _map_cue_label.text if _map_cue_label != null else "",
		}
	return {
		"active": true,
		"kind": String(_action_feedback.get("kind", "")),
		"label": String(_action_feedback.get("label", "")),
		"text": String(_action_feedback.get("text", "")),
		"full_text": String(_action_feedback.get("full_text", "")),
		"post_action_recap": _duplicate_dictionary(_action_feedback.get("post_action_recap", {})),
		"sequence": int(_action_feedback.get("sequence", 0)),
		"cue_chip_text": _map_cue_label.text if _map_cue_label != null else "",
		"reduced_motion": SettingsService.reduced_motion_enabled(),
	}

func _validation_control_surfaces(container: Node) -> Array:
	var surfaces := []
	if container == null:
		return surfaces
	for child in container.get_children():
		if child.is_queued_for_deletion():
			continue
		var surface := {
			"text": "",
			"tooltip": "",
			"disabled": false,
		}
		if child is Button:
			var button := child as Button
			surface["text"] = button.text
			surface["tooltip"] = button.tooltip_text
			surface["disabled"] = button.disabled
		elif child is Label:
			var label := child as Label
			surface["text"] = label.text
			surface["tooltip"] = label.tooltip_text
		elif child is Control:
			var control := child as Control
			surface["tooltip"] = control.tooltip_text
		surfaces.append(surface)
	return surfaces

func validation_open_command_drawer() -> Dictionary:
	_active_drawer = "command"
	_sync_context_drawers()
	return _validation_chrome_state()

func validation_open_frontier_drawer() -> Dictionary:
	_active_drawer = "frontier"
	_refresh_frontier_drawer()
	_sync_context_drawers()
	return _validation_chrome_state()

func validation_select_tile(x: int, y: int) -> Dictionary:
	var handler_started_usec := Time.get_ticks_usec()
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile is outside the overworld map."}
	var debug_started := _debug_begin_path_command("select_route", tile)
	_debug_record_phase_usec("validation_select_entry", Time.get_ticks_usec() - handler_started_usec, {"handler": "validation_select_tile"})
	_set_selected_tile(tile)
	_debug_set_path_command_target(_selected_tile)
	_active_drawer = ""
	_refresh_selected_route_preview("validation_selected_route_changed")
	if debug_started:
		_debug_finish_path_command()
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	return snapshot

func validation_click_tile(x: int, y: int) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile is outside the overworld map."}
	_on_map_tile_pressed(tile)
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	return snapshot

func validation_hover_tile(x: int, y: int) -> Dictionary:
	var tile := Vector2i(x, y)
	if not _tile_in_bounds(tile):
		return {"ok": false, "message": "Tile is outside the overworld map."}
	_on_map_tile_hovered(tile)
	var snapshot := validation_snapshot()
	snapshot["ok"] = true
	return snapshot

func validation_pan_map(dx: int, dy: int) -> Dictionary:
	var before := _validation_map_viewport_state()
	var changed := _pan_map(Vector2i(dx, dy))
	var after := _validation_map_viewport_state()
	return {
		"ok": changed,
		"changed": changed,
		"before": before,
		"after": after,
	}

func validation_focus_map_on_hero() -> Dictionary:
	var before := _validation_map_viewport_state()
	var changed := _focus_camera_on_hero()
	var after := _validation_map_viewport_state()
	return {
		"ok": changed or not bool(after.get("manual_camera", false)),
		"changed": changed,
		"before": before,
		"after": after,
	}

func validation_tile_presentation(x: int, y: int) -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_tile_presentation"):
		return {}
	return _map_view.call("validation_tile_presentation", Vector2i(x, y))

func validation_editor_restamp_payload(x: int, y: int) -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_editor_restamp_payload"):
		return {}
	return _map_view.call("validation_editor_restamp_payload", Vector2i(x, y))

func validation_town_presentation_profiles() -> Array:
	return _validation_town_presentation_profiles()

func validation_town_state_for_placement(placement_id: String) -> Dictionary:
	return _validation_town_state_for_placement(placement_id)

func validation_resource_site_state(placement_id: String) -> Dictionary:
	for node_value in _session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if String(node.get("placement_id", "")) != placement_id:
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var response_state: Dictionary = OverworldRules._resource_site_response_state(_session, node, site)
		var delivery_state: Dictionary = OverworldRules._resource_site_delivery_state(_session, node, site)
		var interception_state: Dictionary = OverworldRules._resource_site_delivery_interception(_session, node, site)
		return {
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"site_name": String(site.get("name", "")),
			"surface": OverworldRules.describe_resource_site_surface(_session, node, site),
			"interaction_surface": OverworldRules.describe_resource_site_interaction_surface(node, site),
			"control_summary": OverworldRules.describe_resource_site_control_summary(_session, node, site),
			"control_inspection": OverworldRules.describe_resource_site_control_inspection(_session, node, site),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"collected": bool(node.get("collected", false)),
			"collected_by_faction_id": String(node.get("collected_by_faction_id", "")),
			"response_origin": String(node.get("response_origin", "")),
			"response_source_town_id": String(node.get("response_source_town_id", "")),
			"response_until_day": max(0, int(node.get("response_until_day", 0))),
			"response_commander_id": String(node.get("response_commander_id", "")),
			"response_security_rating": max(0, int(node.get("response_security_rating", 0))),
			"delivery_origin_town_id": String(node.get("delivery_origin_town_id", "")),
			"delivery_target_kind": String(node.get("delivery_target_kind", "")),
			"delivery_target_id": String(node.get("delivery_target_id", "")),
			"delivery_target_label": String(node.get("delivery_target_label", "")),
			"delivery_arrival_day": max(0, int(node.get("delivery_arrival_day", 0))),
			"delivery_manifest": _duplicate_dictionary(node.get("delivery_manifest", {})),
			"response": response_state,
			"delivery": delivery_state,
			"interception": interception_state,
		}
	return {}

func validation_select_save_slot(slot: int) -> bool:
	var normalized_slot := int(slot)
	if not SaveService.get_manual_slot_ids().has(normalized_slot):
		return false
	SaveService.set_selected_manual_slot(normalized_slot)
	_refresh_save_slot_picker()
	return SaveService.get_selected_manual_slot() == normalized_slot

func validation_save_to_selected_slot() -> Dictionary:
	var selected_slot := SaveService.get_selected_manual_slot()
	_on_save_pressed()
	var summary := SaveService.inspect_manual_slot(selected_slot)
	return {
		"ok": SaveService.can_load_summary(summary),
		"selected_slot": selected_slot,
		"summary": summary,
		"message": _last_message,
	}

func validation_return_to_menu() -> Dictionary:
	var scenario_id := _session.scenario_id
	var resume_target := SaveService.resume_target_for_session(_session)
	_on_menu_pressed()
	return {
		"ok": true,
		"scenario_id": scenario_id,
		"resume_target": resume_target,
	}

func validation_end_turn() -> Dictionary:
	var day_before := _session.day
	var status_before := _session.scenario_status
	var pressure_before := _validation_enemy_pressure_states()
	_on_end_turn_pressed()
	return {
		"ok": _session.day > day_before or _session.scenario_status != status_before or not _session.battle.is_empty(),
		"action": "end_turn",
		"day_before": day_before,
		"day_after": _session.day,
		"scenario_status_before": status_before,
		"scenario_status_after": _session.scenario_status,
		"battle_started": not _session.battle.is_empty(),
		"enemy_pressure_before": pressure_before,
		"enemy_pressure_after": _validation_enemy_pressure_states(),
		"last_action": String(_session.flags.get("last_action", "")),
		"message": _last_message,
		"enemy_activity_summary": _last_enemy_activity_text,
		"turn_resolution_summary": _last_turn_resolution_text,
		"end_turn_forecast": OverworldRules.describe_end_turn_forecast(_session),
		"end_turn_forecast_compact": OverworldRules.describe_end_turn_forecast_compact(_session),
		"event_visible_text": _event_label.text,
		"event_tooltip_text": _event_label.tooltip_text,
		"event_feed": _event_feed_surface(),
		"action_feedback": _validation_action_feedback(),
		"post_action_recap": _last_action_recap.duplicate(true),
	}

func validation_cast_overworld_spell(spell_id: String) -> Dictionary:
	var movement_before := int(_session.overworld.get("movement", {}).get("current", 0))
	var mana_before := _duplicate_dictionary(_session.overworld.get("hero", {}).get("spellbook", {}).get("mana", {}))
	_on_spell_action_pressed("cast_spell:%s" % spell_id)
	var movement_after := int(_session.overworld.get("movement", {}).get("current", 0))
	var mana_after := _duplicate_dictionary(_session.overworld.get("hero", {}).get("spellbook", {}).get("mana", {}))
	return {
		"ok": movement_after > movement_before,
		"action": "cast_spell:%s" % spell_id,
		"movement_before": movement_before,
		"movement_after": movement_after,
		"mana_before": mana_before,
		"mana_after": mana_after,
		"scenario_status": _session.scenario_status,
		"message": _last_message,
		"action_feedback": _validation_action_feedback(),
		"post_action_recap": _last_action_recap.duplicate(true),
	}

func validation_perform_specialty_action(action_id: String) -> Dictionary:
	var action_ids := []
	for action in _cached_specialty_actions():
		if not (action is Dictionary):
			continue
		action_ids.append(String(action.get("id", "")))
	if action_id not in action_ids:
		return {
			"ok": false,
			"action_id": action_id,
			"specialty_action_ids": action_ids,
			"message": "The requested specialty action is not available on the live overworld shell.",
		}
	var before_state := {
		"specialties": _validation_string_array(_session.overworld.get("hero", {}).get("specialties", [])),
		"pending_specialty_choices": _duplicate_array(_session.overworld.get("hero", {}).get("pending_specialty_choices", [])),
	}
	_on_specialty_action_pressed(action_id)
	var after_state := {
		"specialties": _validation_string_array(_session.overworld.get("hero", {}).get("specialties", [])),
		"pending_specialty_choices": _duplicate_array(_session.overworld.get("hero", {}).get("pending_specialty_choices", [])),
	}
	var changed := JSON.stringify(before_state) != JSON.stringify(after_state)
	return {
		"ok": changed,
		"action_id": action_id,
		"specialty_action_ids": action_ids,
		"state_changed": changed,
		"before": before_state,
		"after": after_state,
		"message": _last_message,
		"specialty_text": _specialty_label.text,
		"specialty_tooltip_text": _specialty_label.tooltip_text,
		"specialty_actions": _validation_specialty_action_payloads(),
		"action_feedback": _validation_action_feedback(),
		"post_action_recap": _last_action_recap.duplicate(true),
	}

func validation_perform_artifact_action(action_id: String) -> Dictionary:
	var action_ids := []
	for action in _cached_artifact_actions():
		if not (action is Dictionary):
			continue
		action_ids.append(String(action.get("id", "")))
	if action_id not in action_ids:
		return {
			"ok": false,
			"action_id": action_id,
			"artifact_action_ids": action_ids,
			"message": "The requested artifact action is not available on the live overworld shell.",
		}
	var before := JSON.stringify(_validation_commander_state().get("artifacts", {}))
	_on_artifact_action_pressed(action_id)
	var after := JSON.stringify(_validation_commander_state().get("artifacts", {}))
	return {
		"ok": before != after,
		"action_id": action_id,
		"artifact_action_ids": action_ids,
		"state_changed": before != after,
		"message": _last_message,
		"artifact_text": _artifact_label.text,
		"artifact_tooltip_text": _artifact_label.tooltip_text,
		"artifact_actions": _validation_artifact_action_payloads(),
		"action_feedback": _validation_action_feedback(),
		"post_action_recap": _last_action_recap.duplicate(true),
	}

func validation_try_progress_action() -> Dictionary:
	var start := OverworldRules.hero_position(_session)
	var safe_step := _first_validation_safe_step(start)
	if safe_step.x >= 0:
		_on_map_tile_pressed(safe_step)
		var finish := OverworldRules.hero_position(_session)
		return {
			"ok": finish != start,
			"action": "move",
			"start": {"x": start.x, "y": start.y},
			"target": {"x": safe_step.x, "y": safe_step.y},
			"finish": {"x": finish.x, "y": finish.y},
			"last_action": String(_session.flags.get("last_action", "")),
			"message": _last_message,
		}

	var day_before := _session.day
	_on_end_turn_pressed()
	return {
		"ok": _session.day > day_before,
		"action": "end_turn",
		"day_before": day_before,
		"day_after": _session.day,
		"last_action": String(_session.flags.get("last_action", "")),
		"message": _last_message,
	}

func validation_perform_context_action(action_id: String) -> Dictionary:
	var action_ids := _validation_context_action_ids()
	if action_id not in action_ids:
		return {
			"ok": false,
			"action_id": action_id,
			"context_action_ids": action_ids,
			"message": "The requested context action is not available on the live overworld shell.",
		}
	var before_signature := JSON.stringify(_validation_context_action_signature())
	_on_context_action_pressed(action_id)
	var after_signature := JSON.stringify(_validation_context_action_signature())
	return {
		"ok": before_signature != after_signature or not _session.battle.is_empty() or _session.scenario_status != "in_progress",
		"action_id": action_id,
		"context_action_ids": action_ids,
		"state_changed": before_signature != after_signature,
		"battle_started": not _session.battle.is_empty(),
		"scenario_status": _session.scenario_status,
		"message": _last_message,
		"action_feedback": _validation_action_feedback(),
		"post_action_recap": _last_action_recap.duplicate(true),
	}

func validation_perform_primary_action() -> Dictionary:
	var primary_action := _current_primary_action()
	if primary_action.is_empty():
		return {
			"ok": false,
			"action_id": "",
			"primary_action": {},
			"message": "No primary order is available on the live overworld shell.",
		}
	var before_signature := JSON.stringify(_validation_context_action_signature())
	var action_id := String(primary_action.get("id", ""))
	var activated := _activate_primary_action()
	var after_signature := JSON.stringify(_validation_context_action_signature())
	return {
		"ok": activated and (
			before_signature != after_signature
			or not _session.battle.is_empty()
			or _session.scenario_status != "in_progress"
			or String(_session.game_state) != "overworld"
		),
		"action_id": action_id,
		"primary_action": _validation_action_payload(primary_action),
		"state_changed": before_signature != after_signature,
		"battle_started": not _session.battle.is_empty(),
		"game_state": _session.game_state,
		"scenario_status": _session.scenario_status,
		"last_action": String(_session.flags.get("last_action", "")),
		"message": _last_message,
		"action_feedback": _validation_action_feedback(),
		"post_action_recap": _last_action_recap.duplicate(true),
		"route_execution": _duplicate_dictionary(_last_route_execution),
	}

func validation_route_step_to_nearest_target(target_kind: String, owner_id: String = "") -> Dictionary:
	return _validation_route_step(target_kind, owner_id, "")

func validation_route_step_to_target_placement(target_kind: String, placement_id: String) -> Dictionary:
	return _validation_route_step(target_kind, "", placement_id)

func _validation_route_step(target_kind: String, owner_id: String = "", placement_id: String = "") -> Dictionary:
	var route_plan := _validation_route_plan(target_kind, owner_id, placement_id)
	if not bool(route_plan.get("ok", false)):
		return route_plan

	var hero_pos := OverworldRules.hero_position(_session)
	var target: Dictionary = route_plan.get("target", {})
	var path: Array = route_plan.get("path", [])
	var target_tile := Vector2i(int(target.get("x", hero_pos.x)), int(target.get("y", hero_pos.y)))
	_set_selected_tile(target_tile)

	var movement = _session.overworld.get("movement", {})
	if path.size() > 1 and int(movement.get("current", 0)) <= 0:
		var day_before := _session.day
		_on_end_turn_pressed()
		return {
			"ok": _session.day > day_before,
			"action": "end_turn_for_route",
			"target_kind": target_kind,
			"target": target.duplicate(true),
			"start": _validation_tile_payload(hero_pos),
			"finish": _validation_tile_payload(OverworldRules.hero_position(_session)),
			"remaining_steps": maxi(0, path.size() - 1),
			"last_action": String(_session.flags.get("last_action", "")),
			"message": _last_message,
			"action_feedback": _validation_action_feedback(),
		}

	if path.size() <= 1:
		match target_kind:
			"town":
				var active_town := _validation_town_state_for_placement(String(target.get("placement_id", "")))
				if active_town.is_empty():
					return {
						"ok": false,
						"action": "enter_town",
						"target_kind": target_kind,
						"target": target.duplicate(true),
						"start": _validation_tile_payload(hero_pos),
						"finish": _validation_tile_payload(hero_pos),
						"remaining_steps": 0,
						"last_action": String(_session.flags.get("last_action", "")),
						"message": "The routed town target is no longer active on this tile.",
				}
				var owner := String(active_town.get("owner", "neutral"))
				if owner == "player":
					var visit_primary_action := _current_primary_action()
					if String(visit_primary_action.get("id", "")) != "visit_town":
						return {
							"ok": false,
							"action": "enter_town",
							"target_kind": target_kind,
							"target": target.duplicate(true),
							"start": _validation_tile_payload(hero_pos),
							"finish": _validation_tile_payload(hero_pos),
							"remaining_steps": 0,
							"town_state": active_town,
							"primary_action": _validation_action_payload(visit_primary_action),
							"last_action": String(_session.flags.get("last_action", "")),
							"message": "The player town did not expose Visit Town as the primary order.",
						}
					var visit_result := validation_perform_primary_action()
					return {
						"ok": bool(visit_result.get("ok", false)) and String(_session.game_state) == "town",
						"action": "enter_town",
						"target_kind": target_kind,
						"target": target.duplicate(true),
						"start": _validation_tile_payload(hero_pos),
						"finish": _validation_tile_payload(hero_pos),
						"remaining_steps": 0,
						"town_state": active_town,
						"primary_action": visit_result.get("primary_action", {}),
						"primary_result": visit_result,
						"last_action": String(_session.flags.get("last_action", "visited_town")),
						"message": _last_message if _last_message != "" else "Town route opened.",
					}
				var context_action_ids := _validation_context_action_ids()
				if not context_action_ids.has("capture_town"):
					return {
						"ok": false,
						"action": "capture_town",
						"target_kind": target_kind,
						"target": target.duplicate(true),
						"start": _validation_tile_payload(hero_pos),
						"finish": _validation_tile_payload(hero_pos),
						"remaining_steps": 0,
						"town_state": active_town,
						"context_action_ids": context_action_ids,
						"last_action": String(_session.flags.get("last_action", "")),
						"message": "The hostile town did not expose the shipped capture action.",
					}
				var capture_primary_action := _current_primary_action()
				if String(capture_primary_action.get("id", "")) != "capture_town":
					return {
						"ok": false,
						"action": "capture_town",
						"target_kind": target_kind,
						"target": target.duplicate(true),
						"start": _validation_tile_payload(hero_pos),
						"finish": _validation_tile_payload(hero_pos),
						"remaining_steps": 0,
						"town_state": active_town,
						"context_action_ids": context_action_ids,
						"primary_action": _validation_action_payload(capture_primary_action),
						"last_action": String(_session.flags.get("last_action", "")),
						"message": "The hostile town did not expose Capture Town as the primary order.",
					}
				var capture_result := validation_perform_primary_action()
				var post_town_state := _validation_town_state_for_placement(String(target.get("placement_id", "")))
				var battle_context: Dictionary = _duplicate_dictionary(_session.battle.get("context", {}))
				return {
					"ok": bool(capture_result.get("ok", false)) and (not _session.battle.is_empty() or owner != String(post_town_state.get("owner", owner))),
					"action": "capture_town",
					"target_kind": target_kind,
					"target": target.duplicate(true),
					"start": _validation_tile_payload(hero_pos),
					"finish": _validation_tile_payload(hero_pos),
					"remaining_steps": 0,
					"pre_action_town_owner": owner,
					"post_action_town_state": post_town_state,
					"context_action_ids": context_action_ids,
					"primary_action": capture_result.get("primary_action", {}),
					"primary_result": capture_result,
					"route": "battle" if not _session.battle.is_empty() else "",
					"battle_context_type": String(battle_context.get("type", "")),
					"battle_context_town_placement_id": String(battle_context.get("town_placement_id", "")),
					"battle_context_trigger_faction_id": String(battle_context.get("trigger_faction_id", "")),
					"last_action": String(_session.flags.get("last_action", "")),
					"message": _last_message if _last_message != "" else "Town capture route opened.",
				}
			"encounter":
				var encounter_primary_action := _current_primary_action()
				if String(encounter_primary_action.get("id", "")) != "enter_battle":
					return {
						"ok": false,
						"action": "enter_battle",
						"target_kind": target_kind,
						"target": target.duplicate(true),
						"start": _validation_tile_payload(hero_pos),
						"finish": _validation_tile_payload(hero_pos),
						"remaining_steps": 0,
						"primary_action": _validation_action_payload(encounter_primary_action),
						"last_action": String(_session.flags.get("last_action", "")),
						"message": "The encounter did not expose Enter Battle as the primary order.",
					}
				var battle_result := validation_perform_primary_action()
				return {
					"ok": bool(battle_result.get("ok", false)) and not _session.battle.is_empty(),
					"action": "enter_battle",
					"target_kind": target_kind,
					"target": target.duplicate(true),
					"start": _validation_tile_payload(hero_pos),
					"finish": _validation_tile_payload(hero_pos),
					"remaining_steps": 0,
					"primary_action": battle_result.get("primary_action", {}),
					"primary_result": battle_result,
					"last_action": String(_session.flags.get("last_action", "")),
					"message": _last_message if _last_message != "" else "Encounter route opened.",
				}
			"resource":
				var resource_context_action_ids := _validation_context_action_ids()
				if resource_context_action_ids.has("collect_resource"):
					var resource_primary_action := _current_primary_action()
					if String(resource_primary_action.get("id", "")) != "collect_resource":
						return {
							"ok": false,
							"action": "collect_resource",
							"target_kind": target_kind,
							"target": target.duplicate(true),
							"start": _validation_tile_payload(hero_pos),
							"finish": _validation_tile_payload(hero_pos),
							"remaining_steps": 0,
							"context_action_ids": resource_context_action_ids,
							"primary_action": _validation_action_payload(resource_primary_action),
							"last_action": String(_session.flags.get("last_action", "")),
							"message": "The resource site did not expose collection as the primary order.",
						}
					var collect_result := validation_perform_primary_action()
					return {
						"ok": bool(collect_result.get("ok", false)),
						"action": "collect_resource",
						"target_kind": target_kind,
						"target": target.duplicate(true),
						"start": _validation_tile_payload(hero_pos),
						"finish": _validation_tile_payload(OverworldRules.hero_position(_session)),
						"remaining_steps": 0,
						"context_action_ids": resource_context_action_ids,
						"primary_action": collect_result.get("primary_action", {}),
						"primary_result": collect_result,
						"last_action": String(_session.flags.get("last_action", "")),
						"message": _last_message if _last_message != "" else "Resource route claimed.",
					}
				return {
					"ok": true,
					"action": "hold_resource",
					"target_kind": target_kind,
					"target": target.duplicate(true),
					"start": _validation_tile_payload(hero_pos),
					"finish": _validation_tile_payload(hero_pos),
					"remaining_steps": 0,
					"context_action_ids": resource_context_action_ids,
					"last_action": String(_session.flags.get("last_action", "")),
					"message": _last_message if _last_message != "" else "Resource route reached.",
				}
			"artifact":
				var artifact_context_action_ids := _validation_context_action_ids()
				if artifact_context_action_ids.has("collect_artifact"):
					var artifact_primary_action := _current_primary_action()
					if String(artifact_primary_action.get("id", "")) != "collect_artifact":
						return {
							"ok": false,
							"action": "collect_artifact",
							"target_kind": target_kind,
							"target": target.duplicate(true),
							"start": _validation_tile_payload(hero_pos),
							"finish": _validation_tile_payload(hero_pos),
							"remaining_steps": 0,
							"context_action_ids": artifact_context_action_ids,
							"primary_action": _validation_action_payload(artifact_primary_action),
							"last_action": String(_session.flags.get("last_action", "")),
							"message": "The artifact cache did not expose recovery as the primary order.",
						}
					var artifact_result := validation_perform_primary_action()
					return {
						"ok": bool(artifact_result.get("ok", false)),
						"action": "collect_artifact",
						"target_kind": target_kind,
						"target": target.duplicate(true),
						"start": _validation_tile_payload(hero_pos),
						"finish": _validation_tile_payload(OverworldRules.hero_position(_session)),
						"remaining_steps": 0,
						"context_action_ids": artifact_context_action_ids,
						"primary_action": artifact_result.get("primary_action", {}),
						"primary_result": artifact_result,
						"last_action": String(_session.flags.get("last_action", "")),
						"message": _last_message if _last_message != "" else "Artifact route claimed.",
					}
			_:
				return {
					"ok": true,
					"action": "hold_position",
					"target_kind": target_kind,
					"target": target.duplicate(true),
					"start": _validation_tile_payload(hero_pos),
					"finish": _validation_tile_payload(hero_pos),
					"remaining_steps": 0,
					"last_action": String(_session.flags.get("last_action", "")),
					"message": "Already holding the requested target tile.",
				}

	var next_step: Vector2i = path[1]
	_try_move(next_step.x - hero_pos.x, next_step.y - hero_pos.y, true)
	var finish := OverworldRules.hero_position(_session)
	return {
		"ok": finish != hero_pos or String(_session.flags.get("last_action", "")) in ["visited_town", "entered_battle"],
		"action": "route_step",
		"target_kind": target_kind,
		"target": target.duplicate(true),
		"start": _validation_tile_payload(hero_pos),
		"step": _validation_tile_payload(next_step),
		"finish": _validation_tile_payload(finish),
		"remaining_steps": maxi(0, path.size() - 2),
		"last_action": String(_session.flags.get("last_action", "")),
		"message": _last_message,
		"action_feedback": _validation_action_feedback(),
	}

func _first_validation_safe_step(start: Vector2i) -> Vector2i:
	for direction in DIRECTIONS:
		var tile: Vector2i = start + direction
		if not _tile_in_bounds(tile):
			continue
		if OverworldRules.tile_is_blocked(_session, tile.x, tile.y):
			continue
		if not OverworldRules.is_tile_explored(_session, tile.x, tile.y):
			continue
		if not _town_at(tile.x, tile.y).is_empty():
			continue
		if not _resource_node_at(tile.x, tile.y).is_empty():
			continue
		if not _artifact_node_at(tile.x, tile.y).is_empty():
			continue
		if not _encounter_at(tile.x, tile.y).is_empty():
			continue
		if not _hero_entries_at(tile.x, tile.y).is_empty():
			continue
		return tile
	return Vector2i(-1, -1)

func _validation_route_plan(target_kind: String, owner_id: String = "", placement_id: String = "") -> Dictionary:
	var hero_pos := OverworldRules.hero_position(_session)
	var best_target := {}
	var best_path: Array = []
	var best_priority := 999999
	for candidate in _validation_targets(target_kind, owner_id, placement_id):
		if not (candidate is Dictionary):
			continue
		var tile := Vector2i(int(candidate.get("x", -1)), int(candidate.get("y", -1)))
		if not _tile_in_bounds(tile):
			continue
		var target_placement_id := String(candidate.get("placement_id", ""))
		var path := _build_validation_path(
			hero_pos,
			tile,
			target_kind in ["town", "encounter", "resource", "artifact"],
			target_kind,
			target_placement_id
		)
		if path.is_empty():
			continue
		var priority := _validation_target_priority(target_kind, candidate)
		if best_target.is_empty() or priority < best_priority or (priority == best_priority and path.size() < best_path.size()):
			best_target = candidate
			best_path = path
			best_priority = priority
	if best_target.is_empty():
		return {
			"ok": false,
			"target_kind": target_kind,
			"placement_id": placement_id,
			"message": "No reachable %s target is available for validation." % target_kind,
		}
	return {
		"ok": true,
		"target_kind": target_kind,
		"target": best_target.duplicate(true),
		"path": best_path.duplicate(true),
		"distance": maxi(0, best_path.size() - 1),
	}

func _validation_targets(target_kind: String, owner_id: String = "", placement_id: String = "") -> Array:
	var targets := []
	match target_kind:
		"town":
			for town in _session.overworld.get("towns", []):
				if not (town is Dictionary):
					continue
				if owner_id != "" and String(town.get("owner", "")) != owner_id:
					continue
				if placement_id != "" and String(town.get("placement_id", "")) != placement_id:
					continue
				targets.append(town)
		"encounter":
			for encounter in _session.overworld.get("encounters", []):
				if not (encounter is Dictionary):
					continue
				if placement_id != "" and String(encounter.get("placement_id", "")) != placement_id:
					continue
				if OverworldRules.is_encounter_resolved(_session, encounter):
					continue
				targets.append(encounter)
		"resource":
			for node in _session.overworld.get("resource_nodes", []):
				if not (node is Dictionary):
					continue
				if placement_id != "" and String(node.get("placement_id", "")) != placement_id:
					continue
				var site := ContentService.get_resource_site(String(node.get("site_id", "")))
				if (
					placement_id != ""
					and bool(site.get("persistent_control", false))
					and String(node.get("collected_by_faction_id", "")) == "player"
				):
					targets.append(node)
					continue
				if bool(site.get("persistent_control", false)):
					if String(node.get("collected_by_faction_id", "")) == "player":
						continue
				elif bool(node.get("collected", false)):
					continue
				targets.append(node)
		"artifact":
			for node in _session.overworld.get("artifact_nodes", []):
				if not (node is Dictionary):
					continue
				if placement_id != "" and String(node.get("placement_id", "")) != placement_id:
					continue
				if bool(node.get("collected", false)):
					continue
				targets.append(node)
	return targets

func _validation_context_action_ids() -> Array[String]:
	var ids: Array[String] = []
	for action in OverworldRules.get_context_actions(_session):
		if not (action is Dictionary):
			continue
		ids.append(String(action.get("id", "")))
	return ids

func _validation_spell_action_payloads() -> Array:
	var payloads := []
	for action in OverworldRules.get_spell_actions(_session):
		if not (action is Dictionary):
			continue
		var payload := _validation_action_payload(action)
		var spell_check := _spell_action_check_surface(action)
		payload["cost"] = int(action.get("cost", 0))
		payload["category"] = String(action.get("category", ""))
		payload["effect"] = String(action.get("effect", ""))
		payload["readiness"] = String(action.get("readiness", ""))
		payload["best_use"] = String(action.get("best_use", ""))
		payload["target"] = String(action.get("target", ""))
		payload["target_requirement"] = String(action.get("target_requirement", ""))
		payload["mana_state"] = String(action.get("mana_state", ""))
		payload["mana_ready"] = bool(action.get("mana_ready", false))
		payload["mana_shortfall"] = int(action.get("mana_shortfall", 0))
		payload["consequence"] = String(action.get("consequence", ""))
		payload["why_cast"] = String(action.get("why_cast", ""))
		payload["availability"] = String(action.get("availability", ""))
		payload["invalid_reason"] = String(action.get("invalid_reason", ""))
		payload["spell_check"] = spell_check
		payload["spell_check_tooltip_text"] = String(spell_check.get("tooltip_text", ""))
		payloads.append(payload)
	return payloads

func _validation_specialty_action_payloads() -> Array:
	var payloads := []
	for action in OverworldRules.get_specialty_actions(_session):
		if not (action is Dictionary):
			continue
		var payload := _validation_action_payload(action)
		var specialty_check := _specialty_action_check_surface(action)
		payload["specialty_check"] = specialty_check
		payload["specialty_check_tooltip_text"] = String(specialty_check.get("tooltip_text", ""))
		payloads.append(payload)
	return payloads

func _validation_artifact_action_payloads() -> Array:
	var payloads := []
	for action in OverworldRules.get_artifact_actions(_session):
		if not (action is Dictionary):
			continue
		payloads.append(_validation_action_payload(action))
	return payloads

func _validation_action_payload(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}
	var payload := {
		"id": String(action.get("id", "")),
		"label": String(action.get("label", "")),
		"summary": String(action.get("summary", "")),
		"disabled": bool(action.get("disabled", false)),
	}
	if action.get("route_decision", {}) is Dictionary:
		payload["route_decision"] = action.get("route_decision", {})
	if action.get("town_entry_handoff", {}) is Dictionary:
		payload["town_entry_handoff"] = action.get("town_entry_handoff", {})
	return payload

func _validation_context_action_signature() -> Dictionary:
	var hero_pos := OverworldRules.hero_position(_session)
	var active_context: Dictionary = OverworldRules.get_active_context(_session)
	var resource_sites := []
	for node_value in _session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		resource_sites.append(
			{
				"placement_id": String(node.get("placement_id", "")),
				"collected_by_faction_id": String(node.get("collected_by_faction_id", "")),
				"response_until_day": max(0, int(node.get("response_until_day", 0))),
				"response_commander_id": String(node.get("response_commander_id", "")),
				"delivery_target_kind": String(node.get("delivery_target_kind", "")),
				"delivery_target_id": String(node.get("delivery_target_id", "")),
				"delivery_arrival_day": max(0, int(node.get("delivery_arrival_day", 0))),
				"delivery_manifest": _duplicate_dictionary(node.get("delivery_manifest", {})),
			}
		)
	return {
		"game_state": _session.game_state,
		"scenario_status": _session.scenario_status,
		"day": _session.day,
		"hero_position": {"x": hero_pos.x, "y": hero_pos.y},
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"movement": _duplicate_dictionary(_session.overworld.get("movement", {})),
		"resources": _duplicate_dictionary(_session.overworld.get("resources", {})),
		"active_context_type": String(active_context.get("type", "")),
		"active_town": _validation_active_town_state(),
		"resource_sites": resource_sites,
	}

func _validation_active_town_state() -> Dictionary:
	var context: Dictionary = _cached_active_context()
	if String(context.get("type", "")) != "town":
		return {}
	return _validation_town_state_for_placement(String(_duplicate_dictionary(context.get("town", {})).get("placement_id", "")))

func _validation_selected_town_state() -> Dictionary:
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if town.is_empty():
		return {}
	return _validation_town_state_for_placement(String(town.get("placement_id", "")))

func _validation_town_state_for_placement(placement_id: String) -> Dictionary:
	if placement_id == "":
		return {}
	for town_value in _session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		if String(town_value.get("placement_id", "")) != placement_id:
			continue
		var town: Dictionary = town_value
		return {
			"placement_id": String(town.get("placement_id", "")),
			"town_id": String(town.get("town_id", "")),
			"owner": String(town.get("owner", "")),
			"front": OverworldRules.town_front_state(_session, town),
			"occupation": OverworldRules.town_occupation_state(_session, town),
			"base_income": OverworldRules.town_income(town),
			"income": OverworldRules.town_income(town, _session),
			"base_battle_readiness": OverworldRules.town_battle_readiness(town),
			"battle_readiness": OverworldRules.town_battle_readiness(town, _session),
			"garrison": _duplicate_array(town.get("garrison", [])),
			"garrison_headcount": _validation_stack_headcount(town.get("garrison", [])),
		}
	return {}

func _validation_stack_headcount(stacks_value: Variant) -> int:
	var headcount := 0
	if not (stacks_value is Array):
		return headcount
	for stack in stacks_value:
		if not (stack is Dictionary):
			continue
		headcount += max(0, int(stack.get("count", 0)))
	return headcount

func _validation_target_priority(target_kind: String, target: Dictionary) -> int:
	if target_kind != "encounter":
		return 0
	match String(target.get("difficulty", "medium")):
		"low":
			return 0
		"medium":
			return 1
		"high":
			return 2
		_:
			return 3

func _validation_tile_payload(tile: Vector2i) -> Dictionary:
	return {
		"x": tile.x,
		"y": tile.y,
	}

func _build_validation_path(
	start: Vector2i,
	goal: Vector2i,
	avoid_interactables: bool = false,
	target_kind: String = "",
	target_placement_id: String = ""
) -> Array:
	if not _tile_in_bounds(goal):
		return []
	if start == goal:
		return [start]
	if OverworldRules.tile_is_blocked(_session, goal.x, goal.y):
		return []

	var queue: Array = [start]
	var queue_index := 0
	var visited = {_tile_key(start): true}
	var came_from = {_tile_key(start): start}
	var found := false

	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		if current == goal:
			found = true
			break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if not _tile_in_bounds(next):
				continue
			if OverworldRules.tile_is_blocked(_session, next.x, next.y):
				continue
			if avoid_interactables and _validation_tile_has_route_hazard(next, goal, target_kind, target_placement_id):
				continue
			var key := _tile_key(next)
			if visited.has(key):
				continue
			visited[key] = true
			came_from[key] = current
			queue.append(next)

	if not found:
		return []

	var path: Array = [goal]
	var walker: Vector2i = goal
	while walker != start:
		walker = came_from.get(_tile_key(walker), start)
		path.push_front(walker)
	return path

func _validation_tile_has_route_hazard(
	tile: Vector2i,
	goal: Vector2i,
	target_kind: String,
	target_placement_id: String
) -> bool:
	if tile == goal:
		return false
	return OverworldRules.tile_has_route_interaction(_session, tile.x, tile.y)

func _make_placeholder_label(text: String) -> Label:
	var placeholder := FrontierVisualKit.placeholder_label(text)
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.autowrap_mode = TextServer.AUTOWRAP_OFF
	placeholder.clip_text = true
	return placeholder

func _compact_text(full_text: String, max_lines: int, max_chars: int = 92, drop_headings: bool = true) -> String:
	return FrontierVisualKit.compact_text(full_text, max_lines, max_chars, drop_headings)

func _set_compact_label(label: Label, full_text: String, max_lines: int, max_chars: int = 92, drop_headings: bool = true) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, max_chars, drop_headings)

func _set_rail_label(label: Label, full_text: String, max_lines: int = 1, max_chars: int = RAIL_LINE_CHARS, drop_headings: bool = true) -> void:
	_set_rail_text(label, full_text, _compact_rail_text(full_text, max_lines, max_chars, drop_headings), max_lines, max_chars)

func _set_rail_text(label: Label, full_text: String, visible_text: String, max_lines: int = 1, max_chars: int = RAIL_LINE_CHARS) -> void:
	label.tooltip_text = full_text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text = _trim_rail_visible_text(visible_text, max_lines, max_chars)

func _rail_prefixed_summary(prefix: String, full_text: String, max_chars: int = RAIL_LINE_CHARS) -> String:
	var line := _compact_rail_text(full_text, 1, max_chars, true)
	if line == "":
		line = "Ready"
	if line.begins_with("%s:" % prefix):
		return line
	return "%s: %s" % [prefix, _strip_repeated_rail_prefix(line)]

func _compact_rail_text(full_text: String, max_lines: int, max_chars: int = RAIL_LINE_CHARS, drop_headings: bool = true) -> String:
	var raw_lines := full_text.split("\n", false)
	var lines: Array[String] = []
	for raw_line in raw_lines:
		var line := _clean_rail_line(raw_line)
		if line == "":
			continue
		if drop_headings and _rail_line_is_heading(line, raw_lines.size()):
			continue
		lines.append(_short_text(line, max_chars))
		if lines.size() >= max_lines:
			break
	if lines.is_empty():
		var fallback := full_text.strip_edges().replace("\n", " | ")
		if fallback == "":
			fallback = "Ready"
		lines.append(_short_text(fallback, max_chars))
	return "\n".join(lines)

func _trim_rail_visible_text(visible_text: String, max_lines: int, max_chars: int) -> String:
	var lines: Array[String] = []
	for raw_line in visible_text.split("\n", false):
		var line := _short_text(raw_line, max_chars)
		if line == "":
			continue
		lines.append(line)
		if lines.size() >= max_lines:
			break
	if lines.is_empty():
		lines.append("Ready")
	return "\n".join(lines)

func _clean_rail_line(raw_line: String) -> String:
	var line := raw_line.strip_edges()
	if line.begins_with("- "):
		line = line.trim_prefix("- ").strip_edges()
	var replacements := [
		["Latest order:", "Log:"],
		["Active tile:", "Tile:"],
		["Immediate order:", "Order:"],
		["Route pressure:", "Route:"],
		["Coverage:", "Cover:"],
		["If you hold:", "Hold:"],
		["Controlled heroes", "Heroes"],
		["Held outposts", "Outposts"],
		["Held shrines", "Shrines"],
		["Local watch:", "Local:"],
		["Occupation watch:", "Occupy:"],
		["Management watch:", "Mgmt:"],
		["Scenario pulse:", "Pulse:"],
		["Next-day posture:", "Risk:"],
		["Steady watch", "Steady"],
		["Command posture:", "Posture:"],
		["Logistics watch:", "Logistics:"],
		["Pressure watch:", "Pressure:"],
		["Immediate orders:", "Orders:"],
	]
	for replacement in replacements:
		var source := String(replacement[0])
		var target := String(replacement[1])
		if line.begins_with(source):
			line = "%s %s" % [target, line.trim_prefix(source).strip_edges()]
			break
	return line

func _strip_repeated_rail_prefix(line: String) -> String:
	var separator := line.find(":")
	if separator > 0 and separator <= 10:
		return line.substr(separator + 1).strip_edges()
	return line

func _rail_line_is_heading(line: String, raw_count: int) -> bool:
	if raw_count <= 1:
		return false
	if line in [
		"Field Dispatch",
		"Command Commitment",
		"Scout Net",
		"Objective Board",
		"Frontier Watch",
		"Command Risk",
		"Command Wing",
		"Marching Army",
		"Specialties",
		"Equipped",
		"Pack",
	]:
		return true
	if line.find(":") >= 0 or line.find("|") >= 0 or line.find(".") >= 0:
		return false
	return line.split(" ", false).size() <= 3

func _short_text(text: String, max_chars: int) -> String:
	var normalized := text.strip_edges().replace("\n", " ")
	while normalized.find("  ") >= 0:
		normalized = normalized.replace("  ", " ")
	if normalized.length() <= max_chars:
		return normalized
	return "%s..." % normalized.left(max(1, max_chars - 3)).strip_edges()

func _save_status_text(selected_slot: int, summary: Dictionary, latest_context: String) -> String:
	var status := "M%d" % selected_slot
	if latest_context == "Latest ready save: none.":
		return "%s none" % status
	if SaveService.can_load_summary(summary):
		return "%s ready" % status
	if bool(summary.get("valid", false)):
		return "%s hold" % status
	return "%s lock" % status

func _style_action_button(button: Button, width: float = 96.0, height: float = 30.0) -> void:
	FrontierVisualKit.apply_button(button, "secondary", width, height, 13)

func _style_rail_action_button(button: Button, role: String = "secondary", height: float = 32.0) -> void:
	FrontierVisualKit.apply_button(button, role, RAIL_ACTION_WIDTH, height, 13)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true

func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_panel(_shell_panel, "earth", 24)
	FrontierVisualKit.apply_panel(_top_strip_panel, "banner", 20)
	FrontierVisualKit.apply_badge(_status_chip_panel, "ink")
	FrontierVisualKit.apply_badge(_resource_chip_panel, "gold")
	FrontierVisualKit.apply_badge(_cue_chip_panel, "teal")
	FrontierVisualKit.apply_badge(_event_panel, "ink")
	FrontierVisualKit.apply_badge(_briefing_panel, "gold")
	FrontierVisualKit.apply_badge(_commitment_panel, "green")
	FrontierVisualKit.apply_panel(_map_panel, "earth", 22)
	FrontierVisualKit.apply_panel(_map_frame_panel, "frame", 18)
	FrontierVisualKit.apply_panel(_sidebar_shell_panel, "frame", 22)
	FrontierVisualKit.apply_panel(_hero_panel, "banner", 18)
	FrontierVisualKit.apply_panel(_action_panel, "ink", 18)
	FrontierVisualKit.apply_panel(_command_panel, "ink", 18)
	FrontierVisualKit.apply_panel(_frontier_panel, "teal", 18)
	FrontierVisualKit.apply_panel(_context_panel, "gold", 18)
	FrontierVisualKit.apply_panel(_command_band_panel, "earth", 22)
	FrontierVisualKit.apply_panel(_orders_panel, "ink", 18)
	FrontierVisualKit.apply_panel(_system_panel, "banner", 18)
	_command_spine.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	FrontierVisualKit.apply_button(_open_command_button, "secondary", 128.0, 34.0, 13)
	FrontierVisualKit.apply_button(_open_frontier_button, "secondary", 128.0, 34.0, 13)
	FrontierVisualKit.apply_button(_close_command_button, "secondary", 108.0, 30.0, 12)
	FrontierVisualKit.apply_button(_close_frontier_button, "secondary", 108.0, 30.0, 12)
	FrontierVisualKit.apply_button(_primary_action_button, "primary", 210.0, 36.0, 13)
	FrontierVisualKit.apply_button(_end_turn_button, "primary", 104.0, 34.0, 13)
	FrontierVisualKit.apply_button(_save_button, "secondary", 78.0, 32.0, 13)
	FrontierVisualKit.apply_button(_menu_button, "secondary", 78.0, 32.0, 13)
	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 92.0, 32.0, 13)

	FrontierVisualKit.apply_label(_header_label, "title", 22)
	FrontierVisualKit.apply_label(_objective_brief_label, "muted", 11)
	FrontierVisualKit.apply_label(_status_label, "body", 12)
	FrontierVisualKit.apply_label(_resource_label, "gold", 12)
	FrontierVisualKit.apply_label(_map_cue_label, "blue", 12)
	FrontierVisualKit.apply_label(_event_title_label, "muted", 11)
	FrontierVisualKit.apply_label(_event_label, "body", 12)
	FrontierVisualKit.apply_label(_briefing_title_label, "gold", 11)
	FrontierVisualKit.apply_label(_commitment_title_label, "green", 11)
	FrontierVisualKit.apply_label(_hero_title_label, "gold", 13)
	FrontierVisualKit.apply_label(_action_title_label, "muted", 12)
	FrontierVisualKit.apply_label(_frontier_indicator_label, "teal", 12)
	FrontierVisualKit.apply_label(_command_title_label, "muted", 13)
	FrontierVisualKit.apply_label(_context_title_label, "gold", 13)
	FrontierVisualKit.apply_label(_frontier_title_label, "teal", 13)
	FrontierVisualKit.apply_label(_orders_title_label, "gold", 13)
	FrontierVisualKit.apply_label(_save_status_label, "muted", 12)
	FrontierVisualKit.apply_labels([
		_commitment_label,
		_briefing_label,
		_hero_label,
		_army_label,
		_heroes_label,
		_specialty_label,
		_spell_label,
		_artifact_label,
		_visibility_label,
		_objective_label,
		_threat_label,
		_forecast_label,
		_context_label,
	], "body", 13)

func _set_command_briefing(title: String, text: String) -> void:
	_briefing_title_text = title if title != "" else "Command Briefing"
	_command_briefing_text = text

func _dismiss_command_briefing() -> void:
	_briefing_title_text = "Command Briefing"
	_command_briefing_text = ""

func _handle_session_resolution() -> bool:
	if _session.scenario_status == "in_progress" and not _session.battle.is_empty():
		AppRouter.go_to_battle()
		return true
	if _session.scenario_status == "in_progress":
		return false
	AppRouter.go_to_scenario_outcome()
	return true
