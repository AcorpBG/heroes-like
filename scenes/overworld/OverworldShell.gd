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
@onready var _sidebar_tabs: TabContainer = %SidebarTabs
@onready var _command_panel: PanelContainer = %CommandPanel
@onready var _frontier_panel: PanelContainer = %FrontierPanel
@onready var _context_panel: PanelContainer = %ContextPanel
@onready var _command_band_panel: PanelContainer = %CommandBand
@onready var _march_panel: PanelContainer = %MarchPanel
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
@onready var _map_hint_label: Label = %MapHint
@onready var _hero_title_label: Label = %HeroTitle
@onready var _hero_label: Label = %Hero
@onready var _army_label: Label = %Army
@onready var _heroes_label: Label = %Heroes
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
@onready var _move_state_label: Label = %MoveState
@onready var _orders_title_label: Label = %OrdersTitle
@onready var _map_view = %Map
@onready var _context_label: Label = %Context
@onready var _context_actions: Container = %ContextActions
@onready var _hero_actions: Container = %HeroActions
@onready var _spell_actions: Container = %SpellActions
@onready var _specialty_actions: Container = %SpecialtyActions
@onready var _artifact_actions: Container = %ArtifactActions
@onready var _move_north_button: Button = %MoveNorth
@onready var _move_south_button: Button = %MoveSouth
@onready var _move_west_button: Button = %MoveWest
@onready var _move_east_button: Button = %MoveEast
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
const SIDEBAR_TAB_CONTEXT := 0
const SIDEBAR_TAB_COMMAND := 1
const SIDEBAR_TAB_FRONTIER := 2

var _session: SessionStateStore.SessionData
var _map_data: Array = []
var _map_size := Vector2i(1, 1)
var _selected_tile := Vector2i(-1, -1)
var _hovered_tile := Vector2i(-1, -1)
var _last_message := ""
var _briefing_title_text := "Command Briefing"
var _command_briefing_text := ""

func _ready() -> void:
	_apply_visual_theme()
	_sidebar_tabs.current_tab = SIDEBAR_TAB_CONTEXT
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
		_move_toward_selected_tile()
		return

	_selected_tile = tile
	_sidebar_tabs.current_tab = SIDEBAR_TAB_CONTEXT
	var hero_pos = OverworldRules.hero_position(_session)
	if _is_adjacent_move_target(hero_pos, tile):
		_try_move(tile.x - hero_pos.x, tile.y - hero_pos.y, true)
		return
	_refresh()

func _on_map_tile_hovered(tile: Vector2i) -> void:
	_hovered_tile = tile
	_update_map_hint()

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
	OverworldRules.normalize_overworld_state(_session)
	_map_data = _duplicate_array(_session.overworld.get("map", []))
	_map_size = OverworldRules.derive_map_size(_session)
	_ensure_selected_tile()
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
	_move_state_label.tooltip_text = status_text
	_move_state_label.text = _march_state_text()
	var resource_text := OverworldRules.describe_resources(_session)
	_resource_label.tooltip_text = resource_text
	_resource_label.text = resource_text
	_map_cue_label.text = "Click route | WASD march"
	_map_cue_label.tooltip_text = "Click adjacent tiles to march, click distant tiles to set a route, or use WASD and arrow keys."
	_set_compact_label(_commitment_label, OverworldRules.describe_commitment_board(_session), 2, 72)
	_set_compact_label(_visibility_label, OverworldRules.describe_visibility_panel(_session), 3, 72)
	_set_compact_label(_hero_label, _hero_card_text(), 2, 72)
	_set_compact_label(_army_label, OverworldRules.describe_army(_session), 2, 72)
	_set_compact_label(_heroes_label, OverworldRules.describe_heroes(_session), 2, 72)
	_set_compact_label(_specialty_label, OverworldRules.describe_specialties(_session), 2, 72)
	_set_compact_label(_spell_label, OverworldRules.describe_spellbook(_session), 2, 72)
	_set_compact_label(_artifact_label, OverworldRules.describe_artifacts(_session), 2, 72)
	_set_compact_label(_objective_label, OverworldRules.describe_objectives(_session), 3, 72)
	_set_compact_label(_threat_label, OverworldRules.describe_enemy_threats(_session), 3, 72)
	_set_compact_label(_forecast_label, OverworldRules.describe_command_risk(_session), 2, 72)
	_set_compact_label(_context_label, _describe_focus_tile(), 5, 74)
	_set_compact_label(_event_label, OverworldRules.describe_dispatch(_session, _last_message), 2, 68)
	_end_turn_button.tooltip_text = OverworldRules.describe_command_risk_forecast(_session)
	_briefing_title_label.text = _briefing_title_text
	_set_compact_label(_briefing_label, _command_briefing_text, 2, 68, false)
	_briefing_panel.visible = _command_briefing_text != ""
	_update_map_hint()

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

	var actions = OverworldRules.get_hero_actions(_session)
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
		_style_action_button(button)
		button.pressed.connect(_on_hero_action_pressed.bind(String(action.get("id", ""))))
		_hero_actions.add_child(button)

func _rebuild_context_actions() -> void:
	for child in _context_actions.get_children():
		child.queue_free()

	var actions = []
	if _selected_tile == OverworldRules.hero_position(_session):
		actions = OverworldRules.get_context_actions(_session)
	else:
		var movement_action = _selected_tile_movement_action()
		if not movement_action.is_empty():
			actions.append(movement_action)

	if actions.is_empty():
		_context_actions.add_child(_make_placeholder_label("Select a tile for orders"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		FrontierVisualKit.apply_button(button, "primary", 112.0, 34.0, 13)
		button.pressed.connect(_on_context_action_pressed.bind(String(action.get("id", ""))))
		_context_actions.add_child(button)

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
			"label": "March",
			"summary": "Advance one tile to %d,%d." % [_selected_tile.x, _selected_tile.y],
		}

	var route = _selected_route()
	if route.size() > 1:
		var steps = route.size() - 1
		return {
			"id": "advance_route",
			"label": "Advance",
			"summary": "Take the next step toward %d,%d. Route length %d step%s." % [
				_selected_tile.x,
				_selected_tile.y,
				steps,
				"" if steps == 1 else "s",
			],
		}
	return {}

func _rebuild_artifact_actions() -> void:
	for child in _artifact_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_artifact_actions(_session)
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
		_style_action_button(button)
		button.pressed.connect(_on_artifact_action_pressed.bind(String(action.get("id", ""))))
		_artifact_actions.add_child(button)

func _rebuild_specialty_actions() -> void:
	for child in _specialty_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_specialty_actions(_session)
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
		_style_action_button(button)
		button.pressed.connect(_on_specialty_action_pressed.bind(String(action.get("id", ""))))
		_specialty_actions.add_child(button)

func _rebuild_spell_actions() -> void:
	for child in _spell_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_spell_actions(_session)
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
		_style_action_button(button)
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

func _march_state_text() -> String:
	var movement = _session.overworld.get("movement", {})
	var hero_pos = OverworldRules.hero_position(_session)
	return "Mv %d/%d\nPos %d,%d" % [
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		hero_pos.x,
		hero_pos.y,
	]

func _describe_focus_tile() -> String:
	if _selected_tile == OverworldRules.hero_position(_session):
		return OverworldRules.describe_context(_session)
	return _describe_selected_tile()

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

func _update_map_hint() -> void:
	_map_hint_label.text = _map_hint_text()

func _map_hint_text() -> String:
	var hero_pos = OverworldRules.hero_position(_session)
	var movement_left = int(_session.overworld.get("movement", {}).get("current", 0))
	if _hovered_tile.x >= 0 and _hovered_tile != _selected_tile:
		return "Hover %d,%d | %s" % [_hovered_tile.x, _hovered_tile.y, _terrain_name_at(_hovered_tile.x, _hovered_tile.y)]
	if _selected_tile == hero_pos:
		return "%s | Click adjacent to move, distant to route | WASD works" % OverworldRules.describe_visibility(_session)
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return "Selected %d,%d | Unexplored ground | Move closer to reveal it." % [_selected_tile.x, _selected_tile.y]
	if OverworldRules.tile_is_blocked(_session, _selected_tile.x, _selected_tile.y):
		return "Selected %d,%d | Sea blocks travel." % [_selected_tile.x, _selected_tile.y]
	var route = _selected_route()
	if route.size() > 1:
		var steps = route.size() - 1
		return "Selected %d,%d | Route %d step%s | Move %d today | Click again to advance." % [
			_selected_tile.x,
			_selected_tile.y,
			steps,
			"" if steps == 1 else "s",
			movement_left,
		]
	return "Selected %d,%d | No clear route from the active hero." % [_selected_tile.x, _selected_tile.y]

func _selected_route() -> Array:
	return _build_path(OverworldRules.hero_position(_session), _selected_tile)

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
	_selected_tile = OverworldRules.hero_position(_session)

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

func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

func validation_snapshot() -> Dictionary:
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {})
	return {
		"scene_path": scene_file_path,
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
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
		"context_summary": _describe_focus_tile(),
		"objective_summary": OverworldRules.describe_objectives(_session),
		"threat_summary": OverworldRules.describe_enemy_threats(_session),
		"latest_save_summary": SaveService.latest_loadable_summary(),
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

func _make_placeholder_label(text: String) -> Label:
	return FrontierVisualKit.placeholder_label(text)

func _compact_text(full_text: String, max_lines: int, max_chars: int = 92, drop_headings: bool = true) -> String:
	return FrontierVisualKit.compact_text(full_text, max_lines, max_chars, drop_headings)

func _set_compact_label(label: Label, full_text: String, max_lines: int, max_chars: int = 92, drop_headings: bool = true) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, max_chars, drop_headings)

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
	FrontierVisualKit.apply_panel(_command_panel, "ink", 18)
	FrontierVisualKit.apply_panel(_frontier_panel, "teal", 18)
	FrontierVisualKit.apply_panel(_context_panel, "gold", 18)
	FrontierVisualKit.apply_panel(_command_band_panel, "earth", 22)
	FrontierVisualKit.apply_panel(_march_panel, "frame", 18)
	FrontierVisualKit.apply_panel(_orders_panel, "ink", 18)
	FrontierVisualKit.apply_panel(_system_panel, "banner", 18)
	FrontierVisualKit.apply_tab_container(_sidebar_tabs)
	_sidebar_tabs.set_tab_title(SIDEBAR_TAB_CONTEXT, "Tile")
	_sidebar_tabs.set_tab_title(SIDEBAR_TAB_COMMAND, "Kit")
	_sidebar_tabs.set_tab_title(SIDEBAR_TAB_FRONTIER, "Intel")

	for button in [_move_north_button, _move_south_button, _move_west_button, _move_east_button]:
		_style_action_button(button, 50.0, 34.0)
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
	FrontierVisualKit.apply_label(_command_title_label, "muted", 13)
	FrontierVisualKit.apply_label(_context_title_label, "gold", 13)
	FrontierVisualKit.apply_label(_frontier_title_label, "teal", 13)
	FrontierVisualKit.apply_label(_orders_title_label, "gold", 13)
	FrontierVisualKit.apply_label(_move_state_label, "gold", 13)
	FrontierVisualKit.apply_label(_save_status_label, "muted", 12)
	FrontierVisualKit.apply_label(_map_hint_label, "blue", 12)
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
