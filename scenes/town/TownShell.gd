extends Control

@onready var _banner_panel: PanelContainer = $Scroll/ContentMargin/Content/Banner
@onready var _crest_panel: PanelContainer = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/CrestFrame
@onready var _town_stage_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/TownColumn/TownStagePanel
@onready var _town_stage_frame_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/TownColumn/TownStagePanel/TownStagePad/TownStageBox/TownStageFrame
@onready var _town_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/TownColumn/TownBoards/TownPanel
@onready var _outlook_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/TownColumn/TownBoards/OutlookPanel
@onready var _command_ledger_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/TownColumn/TownBoards/CommandLedgerPanel
@onready var _command_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel
@onready var _build_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/BuildPanel
@onready var _recruit_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/RecruitPanel
@onready var _study_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/StudyPanel
@onready var _market_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/MarketPanel
@onready var _logistics_panel: PanelContainer = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel
@onready var _crest_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/CrestFrame/CrestPad/CrestLabel
@onready var _header_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Header
@onready var _status_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Status
@onready var _resource_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Resources
@onready var _event_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/Event
@onready var _town_stage_view = $Scroll/ContentMargin/Content/Columns/TownColumn/TownStagePanel/TownStagePad/TownStageBox/TownStageFrame/TownStageInset/TownStage
@onready var _outlook_label: Label = $Scroll/ContentMargin/Content/Columns/TownColumn/TownBoards/OutlookPanel/OutlookPad/OutlookBox/Outlook
@onready var _command_ledger_label: Label = $Scroll/ContentMargin/Content/Columns/TownColumn/TownBoards/CommandLedgerPanel/CommandLedgerPad/CommandLedgerBox/CommandLedger
@onready var _hero_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Hero
@onready var _heroes_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Heroes
@onready var _specialty_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Specialties
@onready var _hero_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/HeroBar/Actions
@onready var _specialty_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/SpecialtyBar/Actions
@onready var _army_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/CommandPanel/CommandPad/CommandBox/Army
@onready var _town_label: Label = $Scroll/ContentMargin/Content/Columns/TownColumn/TownBoards/TownPanel/TownPad/TownBox/TownSummary
@onready var _defense_label: Label = $Scroll/ContentMargin/Content/Columns/TownColumn/TownBoards/TownPanel/TownPad/TownBox/Defense
@onready var _pressure_label: Label = $Scroll/ContentMargin/Content/Columns/TownColumn/TownBoards/TownPanel/TownPad/TownBox/Pressure
@onready var _building_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/BuildPanel/BuildPad/BuildBox/Buildings
@onready var _build_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/BuildPanel/BuildPad/BuildBox/BuildBar/Actions
@onready var _market_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/MarketPanel/MarketPad/MarketBox/Market
@onready var _market_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/MarketPanel/MarketPad/MarketBox/MarketBar/Actions
@onready var _recruit_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/RecruitPanel/RecruitPad/RecruitBox/Recruitment
@onready var _recruit_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/RecruitPanel/RecruitPad/RecruitBox/RecruitBar/Actions
@onready var _study_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/StudyPanel/StudyPad/StudyBox/Study
@onready var _study_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/StudyPanel/StudyPad/StudyBox/StudyBar/Actions
@onready var _spellbook_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/StudyPanel/StudyPad/StudyBox/Spellbook
@onready var _tavern_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel/LogisticsPad/LogisticsBox/Tavern
@onready var _tavern_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel/LogisticsPad/LogisticsBox/TavernBar/Actions
@onready var _transfer_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel/LogisticsPad/LogisticsBox/Transfer
@onready var _transfer_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel/LogisticsPad/LogisticsBox/TransferBar/Actions
@onready var _response_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel/LogisticsPad/LogisticsBox/Responses
@onready var _response_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel/LogisticsPad/LogisticsBox/ResponseBar/Actions
@onready var _artifact_label: Label = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel/LogisticsPad/LogisticsBox/Artifacts
@onready var _artifact_actions: Container = $Scroll/ContentMargin/Content/Columns/Sidebar/LogisticsPanel/LogisticsPad/LogisticsBox/ArtifactBar/Actions
@onready var _save_status_label: Label = $Scroll/ContentMargin/Content/Footer/SaveStatus
@onready var _save_slot_picker: OptionButton = $Scroll/ContentMargin/Content/Footer/SaveSlot
@onready var _save_button: Button = $Scroll/ContentMargin/Content/Footer/Save
@onready var _leave_button: Button = $Scroll/ContentMargin/Content/Footer/Leave
@onready var _menu_button: Button = $Scroll/ContentMargin/Content/Footer/Menu

var _session: SessionStateStore.SessionData
var _last_message := ""

func _ready() -> void:
	_apply_visual_theme()
	_session = SessionState.ensure_active_session()
	if _session.scenario_id == "":
		push_warning("Cannot enter a town without an active scenario session.")
		AppRouter.go_to_main_menu()
		return

	OverworldRules.normalize_overworld_state(_session)
	if _session.scenario_status != "in_progress":
		AppRouter.go_to_scenario_outcome()
		return
	if not TownRules.can_visit_active_town(_session):
		AppRouter.go_to_overworld()
		return
	_configure_save_slot_picker()
	_refresh()

func _on_build_action_pressed(action_id: String) -> void:
	var result := TownRules.build_active_town(_session, action_id)
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_recruit_action_pressed(action_id: String) -> void:
	var result := TownRules.recruit_active_town(_session, action_id)
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_market_action_pressed(action_id: String) -> void:
	var result := TownRules.perform_market_action(_session, action_id)
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_hero_action_pressed(action_id: String) -> void:
	var result := {}
	if action_id.begins_with("switch_hero:"):
		result = TownRules.switch_active_hero_at_town(_session, action_id.trim_prefix("switch_hero:"))
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_tavern_action_pressed(action_id: String) -> void:
	var result := {}
	if action_id.begins_with("hire_hero:"):
		result = TownRules.hire_hero_at_active_town(_session, action_id.trim_prefix("hire_hero:"))
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_transfer_action_pressed(action_id: String) -> void:
	var result := TownRules.transfer_in_active_town(_session, action_id)
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_response_action_pressed(action_id: String) -> void:
	var result := TownRules.perform_response_action(_session, action_id)
	if result.is_empty():
		return
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_study_action_pressed(action_id: String) -> void:
	var result := TownRules.learn_spell_at_active_town(_session, action_id)
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_artifact_action_pressed(action_id: String) -> void:
	var result := TownRules.manage_artifact_at_active_town(_session, action_id)
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_specialty_action_pressed(action_id: String) -> void:
	var result := {}
	if action_id.begins_with("choose_specialty:"):
		result = TownRules.choose_specialty_at_active_town(_session, action_id.trim_prefix("choose_specialty:"))
	_last_message = String(result.get("message", ""))
	if _handle_session_resolution():
		return
	_refresh()

func _on_save_pressed() -> void:
	var result := AppRouter.save_active_session_to_selected_manual_slot()
	_last_message = String(result.get("message", ""))
	_refresh()

func _on_save_slot_selected(index: int) -> void:
	if index < 0 or index >= _save_slot_picker.get_item_count():
		return
	SaveService.set_selected_manual_slot(_save_slot_picker.get_item_id(index))
	_refresh_save_slot_picker()

func _on_leave_pressed() -> void:
	AppRouter.go_to_overworld()

func _on_menu_pressed() -> void:
	AppRouter.return_to_main_menu_from_active_play()

func _refresh() -> void:
	OverworldRules.normalize_overworld_state(_session)
	if not TownRules.can_visit_active_town(_session):
		AppRouter.go_to_overworld()
		return

	_header_label.text = TownRules.describe_header(_session)
	_status_label.text = TownRules.describe_status(_session)
	_resource_label.text = OverworldRules.describe_resources(_session)
	_crest_label.text = _crest_text()
	_set_compact_label(_outlook_label, TownRules.describe_outlook_board(_session), 4)
	_set_compact_label(_command_ledger_label, TownRules.describe_command_ledger(_session), 4)
	_set_compact_label(_hero_label, OverworldRules.describe_hero(_session), 4)
	_set_compact_label(_heroes_label, TownRules.describe_heroes(_session), 4)
	_set_compact_label(_specialty_label, TownRules.describe_specialties(_session), 4)
	_set_compact_label(_army_label, OverworldRules.describe_army(_session), 4)
	_set_compact_label(_town_label, TownRules.describe_summary(_session), 5)
	_set_compact_label(_defense_label, TownRules.describe_defense(_session), 4)
	_set_compact_label(_pressure_label, TownRules.describe_threats(_session), 4)
	_set_compact_label(_building_label, TownRules.describe_buildings(_session), 4)
	_set_compact_label(_market_label, TownRules.describe_market(_session), 4)
	_set_compact_label(_recruit_label, TownRules.describe_recruitment(_session), 4)
	_set_compact_label(_tavern_label, TownRules.describe_tavern(_session), 4)
	_set_compact_label(_transfer_label, TownRules.describe_transfer(_session), 4)
	_set_compact_label(_response_label, TownRules.describe_responses(_session), 4)
	_set_compact_label(_study_label, TownRules.describe_spell_access(_session), 4)
	_set_compact_label(_spellbook_label, OverworldRules.describe_spellbook(_session), 4)
	_set_compact_label(_artifact_label, TownRules.describe_artifacts(_session), 4)
	_set_compact_label(_event_label, TownRules.describe_event_feed(_session, _last_message), 3)
	_town_stage_view.set_town_state(_session)
	_refresh_save_slot_picker()
	_rebuild_hero_actions()
	_rebuild_build_actions()
	_rebuild_market_actions()
	_rebuild_recruit_actions()
	_rebuild_tavern_actions()
	_rebuild_transfer_actions()
	_rebuild_response_actions()
	_rebuild_study_actions()
	_rebuild_specialty_actions()
	_rebuild_artifact_actions()

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
	_save_status_label.tooltip_text = SaveService.describe_slot_details(summary)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Town"))
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the active town visit safely."))
	_leave_button.tooltip_text = "Return to the overworld without leaving the current expedition."
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func _rebuild_hero_actions() -> void:
	for child in _hero_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_hero_actions(_session)
	if actions.size() <= 1:
		_hero_actions.add_child(_make_placeholder_label("No alternate commanders in town"))
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

func _rebuild_build_actions() -> void:
	for child in _build_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_build_actions(_session)
	if actions.is_empty():
		_build_actions.add_child(_make_placeholder_label("No construction orders"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Build")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_build_action_pressed.bind(String(action.get("id", "")).trim_prefix("build:")))
		_build_actions.add_child(button)

func _rebuild_market_actions() -> void:
	for child in _market_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_market_actions(_session)
	if actions.is_empty():
		_market_actions.add_child(_make_placeholder_label("No exchange orders ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Trade")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_market_action_pressed.bind(String(action.get("id", ""))))
		_market_actions.add_child(button)

func _rebuild_recruit_actions() -> void:
	for child in _recruit_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_recruit_actions(_session)
	if actions.is_empty():
		_recruit_actions.add_child(_make_placeholder_label("No recruits waiting"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Recruit")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_recruit_action_pressed.bind(String(action.get("id", "")).trim_prefix("recruit:")))
		_recruit_actions.add_child(button)

func _rebuild_tavern_actions() -> void:
	for child in _tavern_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_tavern_actions(_session)
	if actions.is_empty():
		_tavern_actions.add_child(_make_placeholder_label("No hires are ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Hire")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_tavern_action_pressed.bind(String(action.get("id", ""))))
		_tavern_actions.add_child(button)

func _rebuild_transfer_actions() -> void:
	for child in _transfer_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_transfer_actions(_session)
	if actions.is_empty():
		_transfer_actions.add_child(_make_placeholder_label("No transfers are ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Transfer")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_transfer_action_pressed.bind(String(action.get("id", ""))))
		_transfer_actions.add_child(button)

func _rebuild_response_actions() -> void:
	for child in _response_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_response_actions(_session)
	if actions.is_empty():
		_response_actions.add_child(_make_placeholder_label("No response orders ready"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Respond")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_response_action_pressed.bind(String(action.get("id", ""))))
		_response_actions.add_child(button)

func _rebuild_study_actions() -> void:
	for child in _study_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_spell_learning_actions(_session)
	if actions.is_empty():
		_study_actions.add_child(_make_placeholder_label("No new spells to copy"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Learn")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_study_action_pressed.bind(String(action.get("id", "")).trim_prefix("learn_spell:")))
		_study_actions.add_child(button)

func _rebuild_artifact_actions() -> void:
	for child in _artifact_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_artifact_actions(_session)
	if actions.is_empty():
		_artifact_actions.add_child(_make_placeholder_label("No artifact orders"))
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Artifact")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = String(action.get("summary", ""))
		_style_action_button(button)
		button.pressed.connect(_on_artifact_action_pressed.bind(String(action.get("id", ""))))
		_artifact_actions.add_child(button)

func _rebuild_specialty_actions() -> void:
	for child in _specialty_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_specialty_actions(_session)
	if actions.is_empty():
		_specialty_actions.add_child(_make_placeholder_label("No specialty choice waiting"))
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

func _handle_session_resolution() -> bool:
	if _session.scenario_status == "in_progress":
		return false
	AppRouter.go_to_scenario_outcome()
	return true

func _make_placeholder_label(text: String) -> Label:
	var placeholder := Label.new()
	placeholder.text = text
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.add_theme_color_override("font_color", Color(0.72, 0.77, 0.82))
	return placeholder

func _set_compact_label(label: Label, full_text: String, max_lines: int) -> void:
	label.tooltip_text = full_text
	label.text = _compact_text(full_text, max_lines)

func _compact_text(full_text: String, max_lines: int) -> String:
	var raw_lines := full_text.split("\n", false)
	var lines := []
	for raw_line in raw_lines:
		var line := raw_line.strip_edges()
		if line == "":
			continue
		if raw_lines.size() > 1 and not line.begins_with("-") and "|" not in line and ":" not in line and line == line.capitalize():
			continue
		if line.begins_with("- "):
			line = line.trim_prefix("- ").strip_edges()
		if line.length() > 92:
			line = "%s..." % line.left(89)
		lines.append(line)
	if lines.is_empty():
		return full_text.strip_edges()
	if lines.size() > max_lines:
		var hidden := lines.size() - max_lines
		lines = lines.slice(0, max_lines)
		lines.append("+ %d more" % hidden)
	return "\n".join(lines)

func _crest_text() -> String:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return "TOWN"
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(template.get("faction_id", "")))
	var name := String(faction.get("name", template.get("faction_id", "Town")))
	return name.left(4).to_upper()

func _style_action_button(button: Button, primary: bool = false) -> void:
	button.custom_minimum_size = Vector2(132, 34)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	_apply_button_theme(button, primary)

func _apply_button_theme(button: Button, primary: bool) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.34, 0.27, 0.18, 0.96) if primary else Color(0.18, 0.22, 0.25, 0.96)
	normal.border_color = Color(0.88, 0.71, 0.38, 0.96) if primary else Color(0.52, 0.62, 0.68, 0.95)
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(2)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	normal.shadow_size = 3
	var hover = normal.duplicate()
	hover.bg_color = Color(0.41, 0.31, 0.20, 1.0) if primary else Color(0.24, 0.28, 0.32, 1.0)
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.25, 0.19, 0.13, 1.0) if primary else Color(0.14, 0.17, 0.20, 1.0)
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.12, 0.14, 0.15, 0.92)
	disabled.border_color = Color(0.28, 0.32, 0.35, 0.72)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.50, 0.53))

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	return style

func _apply_visual_theme() -> void:
	_banner_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.18, 0.15, 0.96), Color(0.86, 0.71, 0.40, 0.95)))
	_crest_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.20, 0.15, 0.09, 0.96), Color(0.88, 0.72, 0.40, 0.95)))
	_town_stage_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.11, 0.10, 0.96), Color(0.76, 0.64, 0.35, 0.95)))
	_town_stage_frame_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.08, 0.09, 1.0), Color(0.56, 0.66, 0.71, 0.95)))
	_command_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.13, 0.15, 0.97), Color(0.50, 0.61, 0.68, 0.95)))
	_town_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.14, 0.12, 0.10, 0.97), Color(0.84, 0.68, 0.38, 0.95)))
	_outlook_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.15, 0.17, 0.97), Color(0.43, 0.69, 0.74, 0.95)))
	_command_ledger_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.17, 0.16, 0.11, 0.97), Color(0.73, 0.66, 0.34, 0.95)))
	_build_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.15, 0.13, 0.11, 0.97), Color(0.78, 0.58, 0.34, 0.95)))
	_recruit_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.16, 0.13, 0.97), Color(0.56, 0.74, 0.43, 0.95)))
	_study_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.14, 0.20, 0.97), Color(0.54, 0.62, 0.90, 0.95)))
	_market_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.17, 0.15, 0.10, 0.97), Color(0.88, 0.72, 0.40, 0.95)))
	_logistics_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.14, 0.16, 0.97), Color(0.47, 0.68, 0.72, 0.95)))

	for button in [_save_button, _leave_button, _menu_button]:
		_style_action_button(button, true)
	_save_slot_picker.custom_minimum_size = Vector2(150, 36)
	_apply_button_theme(_save_slot_picker, false)

	_header_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	_status_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.96))
	_resource_label.add_theme_color_override("font_color", Color(0.97, 0.88, 0.61))
	_crest_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.82))
	_event_label.add_theme_color_override("font_color", Color(0.84, 0.89, 0.93))
	_save_status_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.87))

	for label in [
		_outlook_label,
		_command_ledger_label,
		_hero_label,
		_heroes_label,
		_specialty_label,
		_army_label,
		_town_label,
		_defense_label,
		_pressure_label,
		_building_label,
		_market_label,
		_recruit_label,
		_study_label,
		_spellbook_label,
		_tavern_label,
		_transfer_label,
		_response_label,
		_artifact_label,
	]:
		label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.93))
		label.add_theme_font_size_override("font_size", 13)
