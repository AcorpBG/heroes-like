extends Control

@onready var _header_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Header
@onready var _status_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Status
@onready var _resource_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Resources
@onready var _event_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/Event
@onready var _briefing_panel: PanelContainer = $Scroll/ContentMargin/Content/BriefingPanel
@onready var _briefing_title_label: Label = $Scroll/ContentMargin/Content/BriefingPanel/BriefingPad/BriefingBox/BriefingTitle
@onready var _briefing_label: Label = $Scroll/ContentMargin/Content/BriefingPanel/BriefingPad/BriefingBox/Briefing
@onready var _commitment_label: Label = $Scroll/ContentMargin/Content/CommitmentPanel/CommitmentPad/CommitmentBox/Commitment
@onready var _hero_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Hero
@onready var _heroes_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Heroes
@onready var _specialty_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Specialties
@onready var _spell_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Spellbook
@onready var _artifact_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Artifacts
@onready var _army_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Army
@onready var _visibility_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel/FrontierPad/FrontierBox/Visibility
@onready var _objective_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel/FrontierPad/FrontierBox/Objectives
@onready var _threat_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel/FrontierPad/FrontierBox/Threats
@onready var _forecast_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel/FrontierPad/FrontierBox/Forecast
@onready var _map_grid: GridContainer = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/Map
@onready var _context_label: Label = $Scroll/ContentMargin/Content/Columns/MapColumn/ContextPanel/ContextPad/ContextBox/Context
@onready var _context_actions: Container = $Scroll/ContentMargin/Content/Columns/MapColumn/ContextPanel/ContextPad/ContextBox/Actions
@onready var _hero_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/HeroBar/Actions
@onready var _spell_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/SpellBar/Actions
@onready var _specialty_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/SpecialtyBar/Actions
@onready var _artifact_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/ArtifactBar/Actions
@onready var _end_turn_button: Button = $Scroll/ContentMargin/Content/Footer/EndTurn
@onready var _save_status_label: Label = $Scroll/ContentMargin/Content/Footer/SaveStatus
@onready var _save_slot_picker: OptionButton = $Scroll/ContentMargin/Content/Footer/SaveSlot
@onready var _save_button: Button = $Scroll/ContentMargin/Content/Footer/Save
@onready var _menu_button: Button = $Scroll/ContentMargin/Content/Footer/Menu

var _session: SessionStateStore.SessionData
var _map_data: Array = []
var _map_size := Vector2i(1, 1)
var _last_message := ""
var _briefing_title_text := "Command Briefing"
var _command_briefing_text := ""

func _ready() -> void:
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
	var command_briefing_text := OverworldRules.consume_command_briefing(_session)
	if command_briefing_text != "":
		_set_command_briefing("First Turn Briefing", command_briefing_text)
		SaveService.save_runtime_autosave_session(_session)
	_render_state()

func _move_north() -> void:
	_try_move(0, -1)

func _move_south() -> void:
	_try_move(0, 1)

func _move_west() -> void:
	_try_move(-1, 0)

func _move_east() -> void:
	_try_move(1, 0)

func _on_end_turn_pressed() -> void:
	var risk_forecast := OverworldRules.consume_command_risk_forecast(_session)
	if risk_forecast != "":
		_set_command_briefing("Next-Day Risk Forecast", risk_forecast)
		SaveService.save_runtime_autosave_session(_session)
		_refresh()
		return
	var result := OverworldRules.end_turn(_session)
	_session.flags["last_action"] = "ended_turn"
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
	if _session.scenario_status == "in_progress":
		SaveService.save_runtime_autosave_session(_session)
	if _handle_session_resolution():
		return
	_refresh()

func _on_save_pressed() -> void:
	var result := AppRouter.save_active_session_to_selected_manual_slot()
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

func _on_context_action_pressed(action_id: String) -> void:
	if action_id == "enter_battle":
		_start_encounter()
		return
	if action_id == "visit_town":
		AppRouter.go_to_town()
		return

	var result := OverworldRules.perform_context_action(_session, action_id)
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
	if _handle_session_resolution():
		return
	_refresh()

func _on_artifact_action_pressed(action_id: String) -> void:
	var result := OverworldRules.perform_artifact_action(_session, action_id)
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
	if _handle_session_resolution():
		return
	_refresh()

func _on_specialty_action_pressed(action_id: String) -> void:
	var result := {}
	if action_id.begins_with("choose_specialty:"):
		result = OverworldRules.choose_specialty(_session, action_id.trim_prefix("choose_specialty:"))

	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
	if _handle_session_resolution():
		return
	_refresh()

func _on_hero_action_pressed(action_id: String) -> void:
	var result := {}
	if action_id.begins_with("switch_hero:"):
		result = OverworldRules.switch_active_hero(_session, action_id.trim_prefix("switch_hero:"))

	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
	if _handle_session_resolution():
		return
	_refresh()

func _on_spell_action_pressed(action_id: String) -> void:
	var result := {}
	if action_id.begins_with("cast_spell:"):
		result = OverworldRules.cast_overworld_spell(_session, action_id.trim_prefix("cast_spell:"))

	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
	if _handle_session_resolution():
		return
	_refresh()

func _try_move(dx: int, dy: int) -> void:
	var result := OverworldRules.try_move(_session, dx, dy)
	_session.flags["last_action"] = "moved" if bool(result.get("ok", false)) else "blocked_move"
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
	if _handle_session_resolution():
		return
	_refresh()

func _start_encounter() -> void:
	var placement := OverworldRules.get_active_encounter(_session)
	if placement.is_empty():
		_last_message = "No encounter is active here."
		_refresh()
		return

	var payload := BattleRules.create_battle_payload(_session, placement)
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
	_map_grid.columns = max(_map_size.x, 1)
	_refresh()

func _refresh() -> void:
	OverworldRules.normalize_overworld_state(_session)
	_map_data = _duplicate_array(_session.overworld.get("map", []))
	_map_size = OverworldRules.derive_map_size(_session)
	_map_grid.columns = max(_map_size.x, 1)
	_update_map()
	_rebuild_hero_actions()
	_rebuild_context_actions()
	_rebuild_spell_actions()
	_rebuild_specialty_actions()
	_rebuild_artifact_actions()
	_refresh_save_slot_picker()

	var scenario := ContentService.get_scenario(_session.scenario_id)
	_header_label.text = String(scenario.get("name", "Overworld Command"))
	_status_label.text = OverworldRules.describe_status(_session)
	_resource_label.text = OverworldRules.describe_resources(_session)
	_commitment_label.text = OverworldRules.describe_commitment_board(_session)
	_visibility_label.text = OverworldRules.describe_visibility_panel(_session)
	_hero_label.text = OverworldRules.describe_hero(_session)
	_heroes_label.text = OverworldRules.describe_heroes(_session)
	_specialty_label.text = OverworldRules.describe_specialties(_session)
	_spell_label.text = OverworldRules.describe_spellbook(_session)
	_artifact_label.text = OverworldRules.describe_artifacts(_session)
	_army_label.text = OverworldRules.describe_army(_session)
	_objective_label.text = OverworldRules.describe_objectives(_session)
	_threat_label.text = OverworldRules.describe_enemy_threats(_session)
	_forecast_label.text = OverworldRules.describe_command_risk(_session)
	_context_label.text = OverworldRules.describe_context(_session)
	_event_label.text = OverworldRules.describe_dispatch(_session, _last_message)
	_end_turn_button.tooltip_text = OverworldRules.describe_command_risk_forecast(_session)
	_briefing_title_label.text = _briefing_title_text
	_briefing_label.text = _command_briefing_text
	_briefing_panel.visible = _command_briefing_text != ""

func _configure_save_slot_picker() -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))
	_refresh_save_slot_picker()

func _refresh_save_slot_picker() -> void:
	if _save_slot_picker.get_item_count() <= 0:
		return

	var surface := AppRouter.active_save_surface()
	var selected_slot := SaveService.get_selected_manual_slot()
	for index in range(_save_slot_picker.get_item_count()):
		if _save_slot_picker.get_item_id(index) == selected_slot:
			_save_slot_picker.select(index)
			break

	var summary_value: Variant = surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
	var summary: Dictionary = summary_value if summary_value is Dictionary else SaveService.inspect_manual_slot(selected_slot)
	_save_status_label.text = String(surface.get("latest_context", "Latest ready save: none."))
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Expedition"))
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the active expedition."))
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func _update_map() -> void:
	for child in _map_grid.get_children():
		child.queue_free()

	for y in range(_map_size.y):
		for x in range(_map_size.x):
			var cell := Button.new()
			cell.focus_mode = Control.FOCUS_NONE
			cell.disabled = true
			cell.custom_minimum_size = Vector2(96, 48)
			cell.text = _cell_label(x, y)
			cell.modulate = _cell_color(x, y)
			_map_grid.add_child(cell)

func _cell_label(x: int, y: int) -> String:
	if not OverworldRules.is_tile_explored(_session, x, y):
		return "?"
	if not OverworldRules.is_tile_visible(_session, x, y):
		return "%d,%d %s" % [x, y, _terrain_memory_label(x, y)]
	var parts := ["%d,%d" % [x, y]]
	var hero_marker := _hero_marker_at(x, y)
	if hero_marker != "":
		parts.append(hero_marker)
	if _is_town_cell(x, y):
		parts.append("T")
	if _is_resource_cell(x, y):
		parts.append("R")
	if _is_artifact_cell(x, y):
		parts.append("A")
	if _is_encounter_cell(x, y):
		parts.append("!")
	return " ".join(parts)

func _cell_color(x: int, y: int) -> Color:
	if not OverworldRules.is_tile_explored(_session, x, y):
		return Color(0.10, 0.10, 0.12)
	if not OverworldRules.is_tile_visible(_session, x, y):
		return _memory_cell_color(x, y)
	if OverworldRules.tile_is_blocked(_session, x, y):
		return Color(0.32, 0.48, 0.76)
	var town_owner := _town_owner_at(x, y)
	if town_owner == "player":
		return Color(0.76, 0.68, 0.38)
	if town_owner == "enemy":
		return Color(0.68, 0.34, 0.34)
	if _is_resource_cell(x, y):
		return Color(0.42, 0.66, 0.44)
	if _is_artifact_cell(x, y):
		return Color(0.78, 0.58, 0.30)
	if _is_encounter_cell(x, y):
		return Color(0.72, 0.38, 0.38)
	return Color(0.46, 0.62, 0.44)

func _terrain_memory_label(x: int, y: int) -> String:
	if OverworldRules.tile_is_blocked(_session, x, y):
		return "~"
	var terrain := _terrain_at(x, y)
	match terrain:
		"forest":
			return "F"
		"grass":
			return "."
		_:
			return terrain.left(1).capitalize() if terrain != "" else "."

func _memory_cell_color(x: int, y: int) -> Color:
	if OverworldRules.tile_is_blocked(_session, x, y):
		return Color(0.16, 0.22, 0.30)
	match _terrain_at(x, y):
		"forest":
			return Color(0.18, 0.24, 0.18)
		"grass":
			return Color(0.22, 0.26, 0.22)
		_:
			return Color(0.20, 0.20, 0.22)

func _rebuild_hero_actions() -> void:
	for child in _hero_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_hero_actions(_session)
	if actions.size() <= 1:
		var placeholder := Label.new()
		placeholder.text = "Only one commander is ready"
		_hero_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Command")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_hero_action_pressed.bind(String(action.get("id", ""))))
		_hero_actions.add_child(button)

func _rebuild_context_actions() -> void:
	for child in _context_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_context_actions(_session)
	if actions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No site actions"
		_context_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_context_action_pressed.bind(String(action.get("id", ""))))
		_context_actions.add_child(button)

func _rebuild_artifact_actions() -> void:
	for child in _artifact_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_artifact_actions(_session)
	if actions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No loadout actions"
		_artifact_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_artifact_action_pressed.bind(String(action.get("id", ""))))
		_artifact_actions.add_child(button)

func _rebuild_specialty_actions() -> void:
	for child in _specialty_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_specialty_actions(_session)
	if actions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No specialty choice waiting"
		_specialty_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Choose Specialty")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_specialty_action_pressed.bind(String(action.get("id", ""))))
		_specialty_actions.add_child(button)

func _rebuild_spell_actions() -> void:
	for child in _spell_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_spell_actions(_session)
	if actions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No field spells"
		_spell_actions.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_spell_action_pressed.bind(String(action.get("id", ""))))
		_spell_actions.add_child(button)

func _hero_marker_at(x: int, y: int) -> String:
	if not OverworldRules.is_tile_visible(_session, x, y):
		return ""
	var active_here := false
	var other_count := 0
	for entry in HeroCommandRules.hero_positions(_session):
		if not (entry is Dictionary):
			continue
		if int(entry.get("x", -1)) != x or int(entry.get("y", -1)) != y:
			continue
		if bool(entry.get("is_active", false)):
			active_here = true
		else:
			other_count += 1
	if active_here and other_count > 0:
		return "A+%d" % other_count
	if active_here:
		return "A"
	if other_count > 1:
		return "H%d" % other_count
	if other_count == 1:
		return "H"
	return ""

func _is_town_cell(x: int, y: int) -> bool:
	if not OverworldRules.is_tile_visible(_session, x, y):
		return false
	for town in _session.overworld.get("towns", []):
		if town is Dictionary and int(town.get("x", -1)) == x and int(town.get("y", -1)) == y:
			return true
	return false

func _town_owner_at(x: int, y: int) -> String:
	if not OverworldRules.is_tile_visible(_session, x, y):
		return "neutral"
	for town in _session.overworld.get("towns", []):
		if town is Dictionary and int(town.get("x", -1)) == x and int(town.get("y", -1)) == y:
			return String(town.get("owner", "neutral"))
	return "neutral"

func _is_resource_cell(x: int, y: int) -> bool:
	if not OverworldRules.is_tile_visible(_session, x, y):
		return false
	for node in _session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or int(node.get("x", -1)) != x or int(node.get("y", -1)) != y:
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if bool(site.get("persistent_control", false)) or not bool(node.get("collected", false)):
			return true
	return false

func _is_artifact_cell(x: int, y: int) -> bool:
	if not OverworldRules.is_tile_visible(_session, x, y):
		return false
	for node in _session.overworld.get("artifact_nodes", []):
		if node is Dictionary and not bool(node.get("collected", false)) and int(node.get("x", -1)) == x and int(node.get("y", -1)) == y:
			return true
	return false

func _is_encounter_cell(x: int, y: int) -> bool:
	if not OverworldRules.is_tile_visible(_session, x, y):
		return false
	for encounter in _session.overworld.get("encounters", []):
		if encounter is Dictionary and int(encounter.get("x", -1)) == x and int(encounter.get("y", -1)) == y:
			if not OverworldRules.is_encounter_resolved(_session, encounter):
				return true
	return false

func _terrain_at(x: int, y: int) -> String:
	if y < 0 or y >= _map_data.size():
		return ""
	var row = _map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return ""
	return String(row[x])

func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

func _style_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(170, 0)

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
