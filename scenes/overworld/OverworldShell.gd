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
]
const RAIL_ACTION_WIDTH := 248.0
const RAIL_LINE_CHARS := 42

var _session: SessionStateStore.SessionData
var _map_data: Array = []
var _map_size := Vector2i(1, 1)
var _selected_tile := Vector2i(-1, -1)
var _hovered_tile := Vector2i(-1, -1)
var _last_message := ""
var _briefing_title_text := "Command Briefing"
var _command_briefing_text := ""
var _active_drawer := ""
var _refresh_cache: Dictionary = {}

func _ready() -> void:
	_apply_visual_theme()
	_map_view.tile_pressed.connect(_on_map_tile_pressed)
	_map_view.tile_hovered.connect(_on_map_tile_hovered)

	_session = SessionState.ensure_active_session()
	if _session.scenario_id == "":
		push_warning("Cannot enter overworld without an active scenario session.")
		AppRouter.go_to_main_menu()
		return

	OverworldRules.normalize_overworld_state(_session)
	if _session.scenario_status != "in_progress":
		AppRouter.go_to_scenario_outcome()
		return
	_configure_save_slot_picker()
	_last_message = String(_session.flags.get("return_notice", ""))
	if _last_message != "":
		_session.flags.erase("return_notice")
	var command_briefing_text = OverworldRules.consume_command_briefing(_session)
	if command_briefing_text != "":
		_set_command_briefing("First Turn Briefing", command_briefing_text)
		SaveService.save_runtime_autosave_session(_session)
	_select_hero_tile()
	_render_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _activate_primary_action():
					get_viewport().set_input_as_handled()
			KEY_UP, KEY_W:
				_move_north()
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S:
				_move_south()
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_A:
				_move_west()
				get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_move_east()
				get_viewport().set_input_as_handled()

func _move_north() -> void:
	_try_move(0, -1)

func _move_south() -> void:
	_try_move(0, 1)

func _move_west() -> void:
	_try_move(-1, 0)

func _move_east() -> void:
	_try_move(1, 0)

func _on_end_turn_pressed() -> void:
	# Validation anchor retained while the forecast stays informational instead of gating the turn.
	# OverworldRules.consume_command_risk_forecast(_session)
	var result = OverworldRules.end_turn(_session)
	_session.flags["last_action"] = "ended_turn"
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _session.scenario_status == "in_progress":
		SaveService.save_runtime_autosave_session(_session)
	if _handle_session_resolution():
		return
	_refresh()

func _on_save_pressed() -> void:
	var result = AppRouter.save_active_session_to_selected_manual_slot()
	_last_message = String(result.get("message", ""))
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
	_sync_context_drawers()

func _on_close_drawers_pressed() -> void:
	_active_drawer = ""
	_sync_context_drawers()

func _on_context_action_pressed(action_id: String) -> void:
	if action_id == "advance_route":
		_move_toward_selected_tile()
		return
	if action_id == "march_selected":
		var hero_pos = OverworldRules.hero_position(_session)
		_try_move(_selected_tile.x - hero_pos.x, _selected_tile.y - hero_pos.y, true)
		return
	if action_id == "enter_battle":
		_start_encounter()
		return
	if action_id == "visit_town":
		_session.flags["last_action"] = "visited_town"
		AppRouter.go_to_town()
		return

	var result = OverworldRules.perform_context_action(_session, action_id)
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _handle_session_resolution():
		return
	_refresh()

func _on_artifact_action_pressed(action_id: String) -> void:
	var result = OverworldRules.perform_artifact_action(_session, action_id)
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
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
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		_select_hero_tile()
	if _handle_session_resolution():
		return
	_refresh()

func _on_map_tile_pressed(tile: Vector2i) -> void:
	if not _tile_in_bounds(tile):
		return
	if tile == _selected_tile:
		if tile == OverworldRules.hero_position(_session):
			_activate_primary_action()
		else:
			_move_toward_selected_tile()
		return

	_set_selected_tile(tile)
	var hero_pos = OverworldRules.hero_position(_session)
	if _is_adjacent_move_target(hero_pos, tile):
		_try_move(tile.x - hero_pos.x, tile.y - hero_pos.y, true)
		return
	_active_drawer = ""
	_refresh()

func _on_map_tile_hovered(tile: Vector2i) -> void:
	_hovered_tile = tile
	_update_map_tooltip()
	_sync_context_drawers()

func _try_move(dx: int, dy: int, preserve_selection: bool = false) -> void:
	var result = OverworldRules.try_move(_session, dx, dy)
	var route := String(result.get("route", ""))
	if route == "battle":
		_session.flags["last_action"] = "entered_battle"
	elif route == "town":
		_session.flags["last_action"] = "visited_town"
	else:
		_session.flags["last_action"] = "moved" if bool(result.get("ok", false)) else "blocked_move"
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		if not preserve_selection:
			_select_hero_tile()
	if _handle_session_resolution():
		return
	if route == "battle":
		AppRouter.go_to_battle()
		return
	if route == "town":
		AppRouter.go_to_town()
		return
	_refresh()

func _move_toward_selected_tile() -> void:
	var route = _selected_route()
	if route.size() <= 1:
		return
	var hero_pos = OverworldRules.hero_position(_session)
	var next_step: Vector2i = route[1]
	_try_move(next_step.x - hero_pos.x, next_step.y - hero_pos.y, true)

func _start_encounter() -> void:
	var placement = OverworldRules.get_active_encounter(_session)
	if placement.is_empty():
		_last_message = "No encounter is active here."
		_refresh()
		return

	var payload = BattleRules.create_battle_payload(_session, placement)
	if payload.is_empty():
		push_error("Unable to create battle payload for encounter %s." % String(placement.get("encounter_id", placement.get("id", ""))))
		_last_message = "Battle setup failed."
		_refresh()
		return

	_session.battle = payload
	_session.flags["last_action"] = "entered_battle"
	AppRouter.go_to_battle()

func _render_state() -> void:
	_map_data = _duplicate_array(_session.overworld.get("map", []))
	_map_size = OverworldRules.derive_map_size(_session)
	_refresh()

func _refresh() -> void:
	OverworldRules.begin_normalized_read_scope(_session)
	_map_data = _duplicate_array(_session.overworld.get("map", []))
	_map_size = OverworldRules.derive_map_size(_session)
	_ensure_selected_tile()
	_invalidate_refresh_cache()
	_map_view.set_map_state(_session, _map_data, _map_size, _selected_tile)
	_rebuild_hero_actions()
	_rebuild_context_actions()
	_rebuild_spell_actions()
	_rebuild_specialty_actions()
	_rebuild_artifact_actions()
	_refresh_save_slot_picker()

	var scenario = ContentService.get_scenario(_session.scenario_id)
	_header_label.text = String(scenario.get("name", "Overworld Command"))
	var status_text := OverworldRules.describe_status(_session)
	_status_label.tooltip_text = status_text
	_status_label.text = _compact_text(status_text, 1, 64, false)
	var resource_text := OverworldRules.describe_resources(_session)
	_resource_label.tooltip_text = resource_text
	_resource_label.text = resource_text
	_map_cue_label.text = _map_cue_text()
	_map_cue_label.tooltip_text = _map_cue_tooltip()
	var commitment_text := OverworldRules.describe_commitment_board(_session)
	_set_rail_text(_commitment_label, commitment_text, _rail_order_text(commitment_text), 2)
	var visibility_text := OverworldRules.describe_visibility_panel(_session)
	_set_rail_text(_visibility_label, visibility_text, _rail_prefixed_summary("Sight", visibility_text), 1)
	var hero_text := _hero_card_text()
	_set_rail_text(_hero_label, hero_text, hero_text, 2)
	var army_text := OverworldRules.describe_army(_session)
	_set_rail_text(_army_label, army_text, _rail_prefixed_summary("Army", army_text), 1)
	var heroes_text := OverworldRules.describe_heroes(_session)
	_set_rail_text(_heroes_label, heroes_text, _rail_prefixed_summary("Heroes", heroes_text), 1)
	var specialty_text := OverworldRules.describe_specialties(_session)
	_set_rail_text(_specialty_label, specialty_text, _rail_prefixed_summary("Spec", specialty_text), 1)
	var spell_text := OverworldRules.describe_spellbook(_session)
	_set_rail_text(_spell_label, spell_text, _rail_prefixed_summary("Spell", spell_text), 1)
	var artifact_text := OverworldRules.describe_artifacts(_session)
	_set_rail_text(_artifact_label, artifact_text, _rail_prefixed_summary("Gear", artifact_text), 1)
	var objective_text := _cached_objective_text()
	_set_rail_text(_objective_label, objective_text, _rail_prefixed_summary("Obj", objective_text), 1)
	var threat_text := _cached_frontier_threats()
	_set_rail_text(_threat_label, threat_text, _rail_prefixed_summary("Threat", threat_text), 1)
	var command_risk_surface := _cached_command_risk_surface()
	var forecast_text := String(command_risk_surface.get("risk", ""))
	_set_rail_text(_forecast_label, forecast_text, _rail_prefixed_summary("Risk", forecast_text), 1)
	_frontier_indicator_label.text = _frontier_indicator_text(threat_text, forecast_text)
	_frontier_indicator_label.tooltip_text = "%s\n\n%s" % [threat_text, forecast_text]
	var context_text := _cached_focus_tile_text()
	_set_rail_text(_context_label, context_text, _rail_tile_text(), 2)
	var dispatch_text := OverworldRules.describe_dispatch(_session, _last_message)
	_set_rail_text(_event_label, dispatch_text, _rail_log_text(), 1)
	_end_turn_button.tooltip_text = String(command_risk_surface.get("forecast", ""))
	_briefing_title_label.text = _briefing_title_text
	_set_rail_label(_briefing_label, _command_briefing_text, 2, RAIL_LINE_CHARS, false)
	_briefing_panel.visible = _command_briefing_text != ""
	_update_map_tooltip()
	_sync_context_drawers()
	OverworldRules.end_normalized_read_scope(_session)

func _configure_save_slot_picker() -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("M%d" % int(slot), int(slot))
	_refresh_save_slot_picker()

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
	_save_status_label.tooltip_text = latest_context
	_save_status_label.text = _save_status_text(selected_slot, summary, latest_context)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = "Save"
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the active expedition."))
	_menu_button.text = "Menu"
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func _rebuild_hero_actions() -> void:
	for child in _hero_actions.get_children():
		child.queue_free()

	var actions = _cached_hero_actions()
	if actions.size() <= 1:
		_hero_actions.add_child(_make_placeholder_label("No reserve switch"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Command")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_rail_action_button(button)
		button.pressed.connect(_on_hero_action_pressed.bind(String(action.get("id", ""))))
		_hero_actions.add_child(button)

func _rebuild_context_actions() -> void:
	for child in _context_actions.get_children():
		child.queue_free()

	var actions := _current_context_actions()
	var primary_action := _first_enabled_action(actions)
	_refresh_primary_action_button(primary_action)

	if actions.is_empty():
		_context_actions.add_child(_make_placeholder_label("Select a tile for orders"))
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
	if _refresh_cache.has("context_actions"):
		return _refresh_cache["context_actions"]
	var actions: Array = []
	if _selected_tile == OverworldRules.hero_position(_session):
		actions = OverworldRules.get_context_actions(_session)
		actions = _promote_selected_owned_town_action(actions)
	else:
		var movement_action = _selected_tile_movement_action()
		if not movement_action.is_empty():
			actions.append(movement_action)
	_refresh_cache["context_actions"] = actions
	return actions

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
	if not _tile_in_bounds(_selected_tile):
		return {}
	if _selected_tile != OverworldRules.hero_position(_session):
		return {}
	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if town.is_empty() or String(town.get("owner", "neutral")) != "player":
		return {}
	var town_name := _selected_tile_destination_name()
	if town_name == "":
		town_name = "this town"
	return {
		"id": "visit_town",
		"label": "Visit Town",
		"summary": "Enter %s now to review construction, recruitment, market, and recovery orders." % town_name,
	}

func _current_primary_action() -> Dictionary:
	if _refresh_cache.has("primary_action"):
		return _refresh_cache["primary_action"]
	var action := _first_enabled_action(_current_context_actions())
	_refresh_cache["primary_action"] = action
	return action

func _cached_hero_actions() -> Array:
	if not _refresh_cache.has("hero_actions"):
		_refresh_cache["hero_actions"] = OverworldRules.get_hero_actions(_session)
	return _refresh_cache["hero_actions"]

func _cached_spell_actions() -> Array:
	if not _refresh_cache.has("spell_actions"):
		_refresh_cache["spell_actions"] = OverworldRules.get_spell_actions(_session)
	return _refresh_cache["spell_actions"]

func _cached_specialty_actions() -> Array:
	if not _refresh_cache.has("specialty_actions"):
		_refresh_cache["specialty_actions"] = OverworldRules.get_specialty_actions(_session)
	return _refresh_cache["specialty_actions"]

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
		_primary_action_button.tooltip_text = "Select a visible destination or stand on a site to reveal its primary order."
		return

	_primary_action_button.text = "%s [Enter]" % _short_action_label(String(action.get("label", "Action")), 22)
	_primary_action_button.disabled = bool(action.get("disabled", false))
	var summary := String(action.get("summary", ""))
	if summary == "":
		summary = "Commit %s." % String(action.get("label", "the primary order")).to_lower()
	_primary_action_button.tooltip_text = "%s\nPress Enter or Space to commit this order." % summary

func _activate_primary_action() -> bool:
	var action := _current_primary_action()
	if action.is_empty() or bool(action.get("disabled", false)):
		return false
	var action_id := String(action.get("id", ""))
	if action_id == "":
		return false
	_on_context_action_pressed(action_id)
	return true

func _selected_tile_movement_action() -> Dictionary:
	if not _tile_in_bounds(_selected_tile):
		return {}
	if OverworldRules.tile_is_blocked(_session, _selected_tile.x, _selected_tile.y):
		return {}
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return {}

	var hero_pos = OverworldRules.hero_position(_session)
	if _is_adjacent_move_target(hero_pos, _selected_tile):
		return {
			"id": "march_selected",
			"label": _selected_tile_order_label(true),
			"summary": _selected_tile_order_summary(true),
		}

	var route = _selected_route()
	if route.size() > 1:
		var steps = route.size() - 1
		return {
			"id": "advance_route",
			"label": _selected_tile_order_label(false),
			"summary": "%s Route length %d step%s." % [
				_selected_tile_order_summary(false),
				steps,
				"" if steps == 1 else "s",
			],
		}
	return {}

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
		return ArtifactRules.describe_artifact(String(artifact_node.get("artifact_id", "")))

	var encounter := _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		return OverworldRules.encounter_display_name(encounter)

	return ""

func _map_cue_text() -> String:
	var action := _current_primary_action()
	if action.is_empty():
		var movement = _session.overworld.get("movement", {})
		return "Move %d/%d | Select destination" % [
			int(movement.get("current", 0)),
			int(movement.get("max", 0)),
		]
	return "Action: %s [Enter]" % _short_action_label(String(action.get("label", "Action")), 20)

func _map_cue_tooltip() -> String:
	var action := _current_primary_action()
	if action.is_empty():
		return "Click a visible adjacent tile to move now, or select a farther visible tile to set the next route step."
	return "Press Enter or Space for %s. Click the map to move or change the selected route." % String(action.get("label", "the primary order"))

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
		_specialty_actions.add_child(_make_placeholder_label("No specialty pick"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Choose Specialty")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_rail_action_button(button)
		button.pressed.connect(_on_specialty_action_pressed.bind(String(action.get("id", ""))))
		_specialty_actions.add_child(button)

func _rebuild_spell_actions() -> void:
	for child in _spell_actions.get_children():
		child.queue_free()

	var actions = _cached_spell_actions()
	if actions.is_empty():
		_spell_actions.add_child(_make_placeholder_label("No field spell"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
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
	var message := _last_message.strip_edges()
	if message == "":
		message = "Awaiting order"
	return "Log: %s" % message

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
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return "Tile %s | Unexplored\nScout closer" % coords
	if not OverworldRules.is_tile_visible(_session, _selected_tile.x, _selected_tile.y):
		return "Tile %s | Mapped %s\nOut of scout net" % [coords, terrain]

	var town := _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		var town_line := "Town: %s" % _selected_tile_destination_name()
		var owner := String(town.get("owner", "neutral")).capitalize()
		return "%s\n%s%s" % [town_line, "Owner %s | %s" % [owner, terrain], "" if action_hint == "" else " | %s" % action_hint]

	var node := _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var site_state := "Ready"
		if bool(site.get("persistent_control", false)):
			match String(node.get("collected_by_faction_id", "")):
				"player":
					site_state = "Held"
				"enemy":
					site_state = "Hostile"
				_:
					site_state = "Unclaimed"
		elif bool(node.get("collected", false)):
			site_state = "Spent"
		return "Site: %s\n%s | %s%s" % [
			String(site.get("name", "Frontier site")),
			site_state,
			terrain,
			"" if action_hint == "" else " | %s" % action_hint,
		]

	var artifact_node := _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		return "Artifact: %s\n%s%s" % [
			ArtifactRules.describe_artifact(String(artifact_node.get("artifact_id", ""))),
			terrain,
			"" if action_hint == "" else " | %s" % action_hint,
		]

	var encounter := _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		return "Hostile: %s\n%s%s" % [
			OverworldRules.encounter_display_name(encounter),
			terrain,
			"" if action_hint == "" else " | %s" % action_hint,
		]

	var heroes_here := _hero_entries_at(_selected_tile.x, _selected_tile.y)
	if not heroes_here.is_empty():
		var names := []
		for entry in heroes_here:
			if entry is Dictionary:
				names.append(String(entry.get("name", "Hero")))
		return "Marker: %s\n%s" % [", ".join(names), terrain]

	return "Open: %s | %s\n%s" % [coords, terrain, action_hint if action_hint != "" else "Route or march"]

func _rail_action_hint() -> String:
	var primary_action := _current_primary_action()
	if primary_action.is_empty():
		return ""
	var label := _short_action_label(String(primary_action.get("label", "Action")), 20)
	if bool(primary_action.get("disabled", false)):
		return "Locked %s" % label
	return "Enter %s" % label

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
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return "Unexplored Frontier\nCoords %d,%d | Terrain unknown\nScouts have not charted this ground yet." % [_selected_tile.x, _selected_tile.y]
	if not OverworldRules.is_tile_visible(_session, _selected_tile.x, _selected_tile.y):
		return "Mapped Ground\nCoords %d,%d | Terrain %s\nThis tile is outside the current scout net." % [_selected_tile.x, _selected_tile.y, terrain]

	var town = _town_at(_selected_tile.x, _selected_tile.y)
	if not town.is_empty():
		return "Town Site\nCoords %d,%d | Terrain %s\n%s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			OverworldRules.describe_town_context(town, _session),
		]

	var node = _resource_node_at(_selected_tile.x, _selected_tile.y)
	if not node.is_empty():
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		var control_line = "Ready to collect."
		if bool(site.get("persistent_control", false)):
			match String(node.get("collected_by_faction_id", "")):
				"player":
					control_line = "Held by your frontier network."
				"enemy":
					control_line = "Denied by hostile control."
				_:
					control_line = "Unclaimed strategic site."
		elif bool(node.get("collected", false)):
			control_line = "Already recovered this cycle."
		return "Resource Site\nCoords %d,%d | Terrain %s\n%s\n%s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			String(site.get("name", "Frontier cache")),
			control_line,
		]

	var artifact_node = _artifact_node_at(_selected_tile.x, _selected_tile.y)
	if not artifact_node.is_empty():
		return "Artifact Cache\nCoords %d,%d | Terrain %s\n%s\nRecover the relic by marching onto the cache." % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			ArtifactRules.describe_artifact(String(artifact_node.get("artifact_id", ""))),
		]

	var encounter = _encounter_at(_selected_tile.x, _selected_tile.y)
	if not encounter.is_empty():
		var encounter_data = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
		return "Hostile Contact\nCoords %d,%d | Terrain %s\n%s\n%s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			String(encounter_data.get("name", "Skirmish host")),
			OverworldRules.describe_encounter_pressure(_session, encounter),
		]

	var heroes_here = _hero_entries_at(_selected_tile.x, _selected_tile.y)
	if not heroes_here.is_empty():
		var names = []
		for entry in heroes_here:
			if entry is Dictionary:
				names.append(String(entry.get("name", "Hero")))
		return "Command Marker\nCoords %d,%d | Terrain %s\nReserve commanders: %s" % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			", ".join(names),
		]

	return "Open Ground\nCoords %d,%d | Terrain %s\nSelect a route and march the active hero through the frontier." % [
		_selected_tile.x,
		_selected_tile.y,
		terrain,
	]

func _update_map_tooltip() -> void:
	_map_view.tooltip_text = _map_tooltip_text()

func _map_tooltip_text() -> String:
	if _tile_in_bounds(_hovered_tile) and _hovered_tile != _selected_tile:
		return _tile_visibility_tooltip(_hovered_tile, "Hover")
	var hero_pos = OverworldRules.hero_position(_session)
	var movement_left = int(_session.overworld.get("movement", {}).get("current", 0))
	var primary_action := _current_primary_action()
	if _selected_tile == hero_pos:
		if not primary_action.is_empty():
			return "%s | Enter: %s" % [
				OverworldRules.describe_visibility(_session),
				_short_action_label(String(primary_action.get("label", "Action")), 22),
			]
		return "%s | Select a mapped destination on the map." % OverworldRules.describe_visibility(_session)
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return "Selected %d,%d | Unexplored ground | Move closer to reveal it." % [_selected_tile.x, _selected_tile.y]
	if OverworldRules.tile_is_blocked(_session, _selected_tile.x, _selected_tile.y):
		return "Selected %d,%d | Sea blocks travel." % [_selected_tile.x, _selected_tile.y]
	var route = _selected_route()
	if route.size() > 1:
		var steps = route.size() - 1
		return "Selected %d,%d | Route %d step%s | Move %d today | Enter: %s." % [
			_selected_tile.x,
			_selected_tile.y,
			steps,
			"" if steps == 1 else "s",
			movement_left,
			_short_action_label(String(primary_action.get("label", "Advance")), 22),
		]
	return "Selected %d,%d | No clear route from the active hero." % [_selected_tile.x, _selected_tile.y]

func _tile_visibility_tooltip(tile: Vector2i, prefix: String) -> String:
	if not OverworldRules.is_tile_explored(_session, tile.x, tile.y):
		return "%s %d,%d | Unexplored ground | Scout closer" % [prefix, tile.x, tile.y]
	var terrain := _terrain_name_at(tile.x, tile.y)
	if not OverworldRules.is_tile_visible(_session, tile.x, tile.y):
		return "%s %d,%d | Mapped %s | Out of scout net" % [prefix, tile.x, tile.y, terrain]
	return "%s %d,%d | %s" % [prefix, tile.x, tile.y, terrain]

func _selected_route() -> Array:
	if not _refresh_cache.has("selected_route"):
		_refresh_cache["selected_route"] = _build_path(OverworldRules.hero_position(_session), _selected_tile)
	return _refresh_cache["selected_route"]

func _build_path(start: Vector2i, goal: Vector2i) -> Array:
	if not _tile_in_bounds(goal):
		return []
	if start == goal:
		return [start]
	if OverworldRules.tile_is_blocked(_session, goal.x, goal.y):
		return []
	if not OverworldRules.is_tile_explored(_session, goal.x, goal.y):
		return []

	var queue: Array = [start]
	var visited = {_tile_key(start): true}
	var came_from = {_tile_key(start): start}
	var found = false

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			found = true
			break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if not _tile_in_bounds(next):
				continue
			if OverworldRules.tile_is_blocked(_session, next.x, next.y):
				continue
			var key = _tile_key(next)
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

func _tile_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _map_size.x and tile.y < _map_size.y

func _is_adjacent_move_target(hero_pos: Vector2i, tile: Vector2i) -> bool:
	if abs(hero_pos.x - tile.x) + abs(hero_pos.y - tile.y) != 1:
		return false
	return not OverworldRules.tile_is_blocked(_session, tile.x, tile.y)

func _ensure_selected_tile() -> void:
	if not _tile_in_bounds(_selected_tile):
		_select_hero_tile()

func _select_hero_tile() -> void:
	_set_selected_tile(OverworldRules.hero_position(_session))

func _set_selected_tile(tile: Vector2i) -> void:
	if _selected_tile == tile:
		return
	_selected_tile = tile
	_invalidate_refresh_cache()

func _invalidate_refresh_cache() -> void:
	_refresh_cache.clear()

func _town_at(x: int, y: int) -> Dictionary:
	for town in _session.overworld.get("towns", []):
		if town is Dictionary and int(town.get("x", -1)) == x and int(town.get("y", -1)) == y:
			return town
	return {}

func _resource_node_at(x: int, y: int) -> Dictionary:
	for node in _session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		if int(node.get("x", -1)) != x or int(node.get("y", -1)) != y:
			continue
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		if bool(site.get("persistent_control", false)) or not bool(node.get("collected", false)):
			return node
	return {}

func _artifact_node_at(x: int, y: int) -> Dictionary:
	for node in _session.overworld.get("artifact_nodes", []):
		if node is Dictionary and not bool(node.get("collected", false)) and int(node.get("x", -1)) == x and int(node.get("y", -1)) == y:
			return node
	return {}

func _encounter_at(x: int, y: int) -> Dictionary:
	for encounter in _session.overworld.get("encounters", []):
		if encounter is Dictionary and int(encounter.get("x", -1)) == x and int(encounter.get("y", -1)) == y:
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

func validation_snapshot() -> Dictionary:
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {})
	var active_context: Dictionary = _cached_active_context()
	var active_town := _validation_active_town_state()
	var primary_action := _current_primary_action()
	return {
		"scene_path": scene_file_path,
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"campaign_id": String(_session.flags.get("campaign_id", "")),
		"campaign_name": String(_session.flags.get("campaign_name", "")),
		"campaign_chapter_label": String(_session.flags.get("campaign_chapter_label", "")),
		"campaign_previous_scenario_id": String(_session.flags.get("campaign_previous_scenario_id", "")),
		"scenario_status": _session.scenario_status,
		"game_state": _session.game_state,
		"day": _session.day,
		"hero_position": {
			"x": hero_pos.x,
			"y": hero_pos.y,
		},
		"movement_current": int(movement.get("current", 0)),
		"movement_max": int(movement.get("max", 0)),
		"map_size": {
			"x": _map_size.x,
			"y": _map_size.y,
		},
		"selected_tile": {
			"x": _selected_tile.x,
			"y": _selected_tile.y,
		},
		"context_summary": _cached_focus_tile_text(),
		"active_context_type": String(active_context.get("type", "")),
		"primary_action_id": String(primary_action.get("id", "")),
		"primary_action": _validation_action_payload(primary_action),
		"primary_action_button_text": _primary_action_button.text,
		"primary_action_button_disabled": _primary_action_button.disabled,
		"context_action_ids": _validation_context_action_ids(),
		"active_town": active_town,
		"resources": _duplicate_dictionary(_session.overworld.get("resources", {})),
		"commander_state": _validation_commander_state(),
		"carryover_flags": _validation_carryover_flags(),
		"objective_summary": _cached_objective_text(),
		"threat_summary": _cached_frontier_threats(),
		"frontier_watch": _cached_frontier_threats(),
		"enemy_pressure_states": _validation_enemy_pressure_states(),
		"latest_save_summary": SaveService.latest_loadable_summary(),
		"map_viewport": _validation_map_viewport_state(),
		"chrome": _validation_chrome_state(),
	}

func _validation_map_viewport_state() -> Dictionary:
	if _map_view == null or not _map_view.has_method("validation_view_metrics"):
		return {}
	return _map_view.call("validation_view_metrics")

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
		"frontier_indicator": _frontier_indicator_label.text,
	}

func validation_open_command_drawer() -> Dictionary:
	_active_drawer = "command"
	_sync_context_drawers()
	return _validation_chrome_state()

func validation_open_frontier_drawer() -> Dictionary:
	_active_drawer = "frontier"
	_sync_context_drawers()
	return _validation_chrome_state()

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

func _validation_action_payload(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}
	return {
		"id": String(action.get("id", "")),
		"label": String(action.get("label", "")),
		"summary": String(action.get("summary", "")),
		"disabled": bool(action.get("disabled", false)),
	}

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
	var visited = {_tile_key(start): true}
	var came_from = {_tile_key(start): start}
	var found := false

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
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
	var town := _town_at(tile.x, tile.y)
	if not town.is_empty():
		return not (
			target_kind == "town"
			and String(town.get("placement_id", "")) == target_placement_id
		)
	if not _resource_node_at(tile.x, tile.y).is_empty():
		if target_kind == "resource" and String(_resource_node_at(tile.x, tile.y).get("placement_id", "")) == target_placement_id:
			return false
		if target_kind in ["encounter", "town"]:
			return false
		return true
	if not _artifact_node_at(tile.x, tile.y).is_empty():
		if target_kind == "artifact" and String(_artifact_node_at(tile.x, tile.y).get("placement_id", "")) == target_placement_id:
			return false
		if target_kind in ["encounter", "town"]:
			return false
		return true
	var encounter := _encounter_at(tile.x, tile.y)
	if not encounter.is_empty() and not OverworldRules.is_encounter_resolved(_session, encounter):
		if target_kind == "encounter" and String(encounter.get("placement_id", "")) == target_placement_id:
			return false
		return true
	if not _hero_entries_at(tile.x, tile.y).is_empty():
		return true
	return false

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
