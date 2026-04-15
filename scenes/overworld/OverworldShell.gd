extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

@onready var _banner_panel: PanelContainer = $Scroll/ContentMargin/Content/Banner
@onready var _briefing_panel: PanelContainer = $Scroll/ContentMargin/Content/BriefingPanel
@onready var _commitment_panel: PanelContainer = $Scroll/ContentMargin/Content/CommitmentPanel
@onready var _map_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel
@onready var _map_frame_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/MapFrame
@onready var _command_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel
@onready var _frontier_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel
@onready var _context_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/ContextPanel
@onready var _header_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Header
@onready var _status_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Status
@onready var _resource_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Resources
@onready var _event_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/Event
@onready var _briefing_title_label: Label = $Scroll/ContentMargin/Content/BriefingPanel/BriefingPad/BriefingBox/BriefingTitle
@onready var _briefing_label: Label = $Scroll/ContentMargin/Content/BriefingPanel/BriefingPad/BriefingBox/Briefing
@onready var _commitment_label: Label = $Scroll/ContentMargin/Content/CommitmentPanel/CommitmentPad/CommitmentBox/Commitment
@onready var _map_hint_label: Label = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/MapHeader/MapHint
@onready var _hero_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Hero
@onready var _army_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Army
@onready var _heroes_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Heroes
@onready var _specialty_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Specialties
@onready var _spell_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Spellbook
@onready var _artifact_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Artifacts
@onready var _visibility_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel/FrontierPad/FrontierBox/Visibility
@onready var _objective_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel/FrontierPad/FrontierBox/Objectives
@onready var _threat_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel/FrontierPad/FrontierBox/Threats
@onready var _forecast_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/FrontierPanel/FrontierPad/FrontierBox/Forecast
@onready var _map_view = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/MapFrame/MapInset/Map
@onready var _context_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/ContextPanel/ContextPad/ContextBox/Context
@onready var _context_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/ContextPanel/ContextPad/ContextBox/Actions
@onready var _hero_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/HeroBar/Actions
@onready var _spell_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/SpellBar/Actions
@onready var _specialty_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/SpecialtyBar/Actions
@onready var _artifact_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/ArtifactBar/Actions
@onready var _move_north_button: Button = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/MoveBar/MoveNorth
@onready var _move_south_button: Button = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/MoveBar/MoveSouth
@onready var _move_west_button: Button = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/MoveBar/MoveWest
@onready var _move_east_button: Button = $Scroll/ContentMargin/Content/Columns/MapColumn/MapPanel/MapPad/MapBox/MoveBar/MoveEast
@onready var _end_turn_button: Button = $Scroll/ContentMargin/Content/Footer/EndTurn
@onready var _save_status_label: Label = $Scroll/ContentMargin/Content/Footer/SaveStatus
@onready var _save_slot_picker: OptionButton = $Scroll/ContentMargin/Content/Footer/SaveSlot
@onready var _save_button: Button = $Scroll/ContentMargin/Content/Footer/Save
@onready var _menu_button: Button = $Scroll/ContentMargin/Content/Footer/Menu

const DIRECTIONS := [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

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
	var risk_forecast = OverworldRules.consume_command_risk_forecast(_session)
	if risk_forecast != "":
		_set_command_briefing("Next-Day Risk Forecast", risk_forecast)
		SaveService.save_runtime_autosave_session(_session)
		_refresh()
		return
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
	_session.flags["last_action"] = "moved" if bool(result.get("ok", false)) else "blocked_move"
	_last_message = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		_dismiss_command_briefing()
		if not preserve_selection:
			_select_hero_tile()
	if _handle_session_resolution():
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
	_status_label.text = OverworldRules.describe_status(_session)
	_resource_label.text = OverworldRules.describe_resources(_session)
	_set_compact_label(_commitment_label, OverworldRules.describe_commitment_board(_session), 4)
	_set_compact_label(_visibility_label, OverworldRules.describe_visibility_panel(_session), 4)
	_set_compact_label(_hero_label, _hero_card_text(), 4)
	_set_compact_label(_army_label, OverworldRules.describe_army(_session), 4)
	_set_compact_label(_heroes_label, OverworldRules.describe_heroes(_session), 4)
	_set_compact_label(_specialty_label, OverworldRules.describe_specialties(_session), 4)
	_set_compact_label(_spell_label, OverworldRules.describe_spellbook(_session), 4)
	_set_compact_label(_artifact_label, OverworldRules.describe_artifacts(_session), 4)
	_set_compact_label(_objective_label, OverworldRules.describe_objectives(_session), 4)
	_set_compact_label(_threat_label, OverworldRules.describe_enemy_threats(_session), 4)
	_set_compact_label(_forecast_label, OverworldRules.describe_command_risk(_session), 4)
	_set_compact_label(_context_label, _describe_focus_tile(), 5)
	_set_compact_label(_event_label, OverworldRules.describe_dispatch(_session, _last_message), 3)
	_end_turn_button.tooltip_text = OverworldRules.describe_command_risk_forecast(_session)
	_briefing_title_label.text = _briefing_title_text
	_set_compact_label(_briefing_label, _command_briefing_text, 4)
	_briefing_panel.visible = _command_briefing_text != ""
	_update_map_hint()

func _configure_save_slot_picker() -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))
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
	_save_status_label.text = String(surface.get("latest_context", "Latest ready save: none."))
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Expedition"))
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the active expedition."))
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func _rebuild_hero_actions() -> void:
	for child in _hero_actions.get_children():
		child.queue_free()

	var actions = OverworldRules.get_hero_actions(_session)
	if actions.size() <= 1:
		_hero_actions.add_child(_make_placeholder_label("Only one commander is ready"))
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
		_context_actions.add_child(_make_placeholder_label("Select a tile to inspect or route toward it"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button = Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
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
			"label": "March Here",
			"summary": "Advance one tile to %d,%d." % [_selected_tile.x, _selected_tile.y],
		}

	var route = _selected_route()
	if route.size() > 1:
		var steps = route.size() - 1
		return {
			"id": "advance_route",
			"label": "Advance Route",
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
		_artifact_actions.add_child(_make_placeholder_label("No loadout actions"))
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
		_specialty_actions.add_child(_make_placeholder_label("No specialty choice waiting"))
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
		_spell_actions.add_child(_make_placeholder_label("No field spells"))
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
	return "%s\nLv%d | Move %d/%d | Mana %d/%d\nA%d D%d P%d K%d | Scout %d" % [
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
		return "Hostile Contact\nCoords %d,%d | Terrain %s\n%s\nAdvance toward the contact to trigger battle." % [
			_selected_tile.x,
			_selected_tile.y,
			terrain,
			String(encounter_data.get("name", "Skirmish host")),
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
		return "%s | Click adjacent tiles to march. Click distant tiles to plot a route. Arrows or WASD also move." % OverworldRules.describe_visibility(_session)
	if not OverworldRules.is_tile_explored(_session, _selected_tile.x, _selected_tile.y):
		return "Selected %d,%d | Unexplored ground. Move closer to reveal this frontier." % [_selected_tile.x, _selected_tile.y]
	if OverworldRules.tile_is_blocked(_session, _selected_tile.x, _selected_tile.y):
		return "Selected %d,%d | Sea blocks overland travel." % [_selected_tile.x, _selected_tile.y]
	var route = _selected_route()
	if route.size() > 1:
		var steps = route.size() - 1
		return "Selected %d,%d | Route %d step%s | Move %d today. Click again to advance." % [
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

func _make_placeholder_label(text: String) -> Label:
	return FrontierVisualKit.placeholder_label(text)

func _set_compact_label(label: Label, full_text: String, max_lines: int) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines)

func _style_action_button(button: Button) -> void:
	FrontierVisualKit.apply_button(button, "secondary", 126.0, 34.0)

func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_panel(_banner_panel, "banner")
	FrontierVisualKit.apply_panel(_briefing_panel, "gold")
	FrontierVisualKit.apply_panel(_commitment_panel, "green")
	FrontierVisualKit.apply_panel(_map_panel, "earth")
	FrontierVisualKit.apply_panel(_map_frame_panel, "frame")
	FrontierVisualKit.apply_panel(_command_panel, "ink")
	FrontierVisualKit.apply_panel(_frontier_panel, "teal")
	FrontierVisualKit.apply_panel(_context_panel, "gold")

	for button in [_move_north_button, _move_south_button, _move_west_button, _move_east_button]:
		_style_action_button(button)
	for button in [_end_turn_button, _save_button, _menu_button]:
		FrontierVisualKit.apply_button(button, "primary", 132.0, 36.0)
	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 150.0, 36.0)

	FrontierVisualKit.apply_label(_header_label, "title")
	FrontierVisualKit.apply_label(_status_label, "body")
	FrontierVisualKit.apply_label(_resource_label, "gold")
	FrontierVisualKit.apply_label(_event_label, "body")
	FrontierVisualKit.apply_label(_briefing_title_label, "gold")
	FrontierVisualKit.apply_label(_save_status_label, "muted")
	FrontierVisualKit.apply_label(_map_hint_label, "blue")
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
