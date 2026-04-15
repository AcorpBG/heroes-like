extends Control

@onready var _header_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Header
@onready var _status_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Status
@onready var _resource_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/TopBar/Resources
@onready var _event_label: Label = $Scroll/ContentMargin/Content/Banner/BannerPad/BannerBox/Event
@onready var _outlook_label: Label = $Scroll/ContentMargin/Content/OutlookPanel/OutlookPad/OutlookBox/Outlook
@onready var _command_ledger_label: Label = $Scroll/ContentMargin/Content/CommandLedgerPanel/CommandLedgerPad/CommandLedgerBox/CommandLedger
@onready var _hero_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/CommandPanel/CommandPad/CommandBox/Hero
@onready var _heroes_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/CommandPanel/CommandPad/CommandBox/Heroes
@onready var _specialty_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/CommandPanel/CommandPad/CommandBox/Specialties
@onready var _hero_actions: Container = $Scroll/ContentMargin/Content/Columns/LeftColumn/CommandPanel/CommandPad/CommandBox/HeroBar/Actions
@onready var _specialty_actions: Container = $Scroll/ContentMargin/Content/Columns/LeftColumn/CommandPanel/CommandPad/CommandBox/SpecialtyBar/Actions
@onready var _town_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/TownPanel/TownPad/TownBox/TownSummary
@onready var _defense_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/TownPanel/TownPad/TownBox/Defense
@onready var _pressure_label: Label = $Scroll/ContentMargin/Content/Columns/LeftColumn/TownPanel/TownPad/TownBox/Pressure
@onready var _building_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/BuildPanel/BuildPad/BuildBox/Buildings
@onready var _build_actions: Container = $Scroll/ContentMargin/Content/Columns/RightColumn/BuildPanel/BuildPad/BuildBox/BuildBar/Actions
@onready var _market_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/MarketPanel/MarketPad/MarketBox/Market
@onready var _market_actions: Container = $Scroll/ContentMargin/Content/Columns/RightColumn/MarketPanel/MarketPad/MarketBox/MarketBar/Actions
@onready var _recruit_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/RecruitPanel/RecruitPad/RecruitBox/Recruitment
@onready var _recruit_actions: Container = $Scroll/ContentMargin/Content/Columns/RightColumn/RecruitPanel/RecruitPad/RecruitBox/RecruitBar/Actions
@onready var _study_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/StudyPanel/StudyPad/StudyBox/Study
@onready var _study_actions: Container = $Scroll/ContentMargin/Content/Columns/RightColumn/StudyPanel/StudyPad/StudyBox/StudyBar/Actions
@onready var _spellbook_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/StudyPanel/StudyPad/StudyBox/Spellbook
@onready var _tavern_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/Tavern
@onready var _tavern_actions: Container = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/TavernBar/Actions
@onready var _transfer_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/Transfer
@onready var _transfer_actions: Container = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/TransferBar/Actions
@onready var _response_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/Responses
@onready var _response_actions: Container = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/ResponseBar/Actions
@onready var _artifact_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/Artifacts
@onready var _artifact_actions: Container = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/ArtifactBar/Actions
@onready var _army_label: Label = $Scroll/ContentMargin/Content/Columns/RightColumn/LogisticsPanel/LogisticsPad/LogisticsBox/Army
@onready var _save_status_label: Label = $Scroll/ContentMargin/Content/Footer/SaveStatus
@onready var _save_slot_picker: OptionButton = $Scroll/ContentMargin/Content/Footer/SaveSlot
@onready var _save_button: Button = $Scroll/ContentMargin/Content/Footer/Save
@onready var _menu_button: Button = $Scroll/ContentMargin/Content/Footer/Menu

var _session: SessionStateStore.SessionData
var _last_message := ""

func _ready() -> void:
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
	_outlook_label.text = TownRules.describe_outlook_board(_session)
	_command_ledger_label.text = TownRules.describe_command_ledger(_session)
	_hero_label.text = OverworldRules.describe_hero(_session)
	_heroes_label.text = TownRules.describe_heroes(_session)
	_specialty_label.text = TownRules.describe_specialties(_session)
	_town_label.text = TownRules.describe_summary(_session)
	_defense_label.text = TownRules.describe_defense(_session)
	_pressure_label.text = TownRules.describe_threats(_session)
	_building_label.text = TownRules.describe_buildings(_session)
	_market_label.text = TownRules.describe_market(_session)
	_recruit_label.text = TownRules.describe_recruitment(_session)
	_tavern_label.text = TownRules.describe_tavern(_session)
	_transfer_label.text = TownRules.describe_transfer(_session)
	_response_label.text = TownRules.describe_responses(_session)
	_study_label.text = TownRules.describe_spell_access(_session)
	_spellbook_label.text = OverworldRules.describe_spellbook(_session)
	_artifact_label.text = TownRules.describe_artifacts(_session)
	_army_label.text = OverworldRules.describe_army(_session)
	_event_label.text = TownRules.describe_event_feed(_session, _last_message)
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

	var summary := surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
	_save_status_label.text = String(surface.get("latest_context", "Latest ready save: none."))
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Town"))
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the active town visit safely."))
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func _rebuild_hero_actions() -> void:
	for child in _hero_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_hero_actions(_session)
	if actions.size() <= 1:
		var placeholder := Label.new()
		placeholder.text = "No alternate commanders in town"
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

func _rebuild_build_actions() -> void:
	for child in _build_actions.get_children():
		child.queue_free()

	var actions = TownRules.get_build_actions(_session)
	if actions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No construction orders"
		_build_actions.add_child(placeholder)
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
		var placeholder := Label.new()
		placeholder.text = "No exchange orders ready"
		_market_actions.add_child(placeholder)
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
		var placeholder := Label.new()
		placeholder.text = "No recruits waiting"
		_recruit_actions.add_child(placeholder)
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
		var placeholder := Label.new()
		placeholder.text = "No hires are ready"
		_tavern_actions.add_child(placeholder)
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
		var placeholder := Label.new()
		placeholder.text = "No transfers are ready"
		_transfer_actions.add_child(placeholder)
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
		var placeholder := Label.new()
		placeholder.text = "No response orders ready"
		_response_actions.add_child(placeholder)
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
		var placeholder := Label.new()
		placeholder.text = "No new spells to copy"
		_study_actions.add_child(placeholder)
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
		var placeholder := Label.new()
		placeholder.text = "No artifact orders"
		_artifact_actions.add_child(placeholder)
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

func _handle_session_resolution() -> bool:
	if _session.scenario_status == "in_progress":
		return false
	AppRouter.go_to_scenario_outcome()
	return true

func _style_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(170, 0)
