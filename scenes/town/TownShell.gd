extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

@onready var _banner_panel: PanelContainer = %Banner
@onready var _crest_panel: PanelContainer = %CrestFrame
@onready var _town_stage_panel: PanelContainer = %TownStagePanel
@onready var _town_stage_frame_panel: PanelContainer = %TownStageFrame
@onready var _town_panel: PanelContainer = %TownPanel
@onready var _outlook_panel: PanelContainer = %OutlookPanel
@onready var _command_ledger_panel: PanelContainer = %CommandLedgerPanel
@onready var _sidebar_shell_panel: PanelContainer = %SidebarShell
@onready var _command_panel: PanelContainer = %CommandPanel
@onready var _management_tabs: TabContainer = %ManagementTabs
@onready var _build_panel: PanelContainer = %BuildPanel
@onready var _recruit_panel: PanelContainer = %RecruitPanel
@onready var _study_panel: PanelContainer = %StudyPanel
@onready var _market_panel: PanelContainer = %MarketPanel
@onready var _logistics_panel: PanelContainer = %LogisticsPanel
@onready var _footer_panel: PanelContainer = %FooterPanel
@onready var _crest_glyph = %CrestGlyph
@onready var _crest_label: Label = %CrestLabel
@onready var _header_label: Label = %Header
@onready var _status_label: Label = %Status
@onready var _resource_label: Label = %Resources
@onready var _event_label: Label = %Event
@onready var _town_stage_view = %TownStage
@onready var _outlook_label: Label = %Outlook
@onready var _command_ledger_label: Label = %CommandLedger
@onready var _hero_label: Label = %Hero
@onready var _production_overview_label: Label = %ProductionOverview
@onready var _heroes_label: Label = %Heroes
@onready var _specialty_label: Label = %Specialties
@onready var _hero_actions: Container = %HeroActions
@onready var _specialty_actions: Container = %SpecialtyActions
@onready var _army_label: Label = %Army
@onready var _town_label: Label = %TownSummary
@onready var _defense_label: Label = %Defense
@onready var _pressure_label: Label = %Pressure
@onready var _building_label: Label = %Buildings
@onready var _build_actions: Container = %BuildActions
@onready var _market_label: Label = %Market
@onready var _market_actions: Container = %MarketActions
@onready var _recruit_label: Label = %Recruitment
@onready var _recruit_actions: Container = %RecruitActions
@onready var _study_label: Label = %Study
@onready var _study_actions: Container = %StudyActions
@onready var _spellbook_label: Label = %Spellbook
@onready var _tavern_label: Label = %Tavern
@onready var _tavern_actions: Container = %TavernActions
@onready var _transfer_label: Label = %Transfer
@onready var _transfer_actions: Container = %TransferActions
@onready var _response_label: Label = %Responses
@onready var _response_actions: Container = %ResponseActions
@onready var _artifact_label: Label = %Artifacts
@onready var _artifact_actions: Container = %ArtifactActions
@onready var _save_status_label: Label = %SaveStatus
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _leave_button: Button = %Leave
@onready var _menu_button: Button = %Menu

var _session: SessionStateStore.SessionData
var _last_message := ""
var _last_action_recap := {}

func _ready() -> void:
	_apply_visual_theme()
	_management_tabs.current_tab = 0
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
	var full_action_id := "build:%s" % action_id
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(full_action_id)
	var result := TownRules.build_active_town(_session, action_id)
	_record_town_action_result("build", full_action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_recruit_action_pressed(action_id: String) -> void:
	var full_action_id := "recruit:%s" % action_id
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(full_action_id)
	var result := TownRules.recruit_active_town(_session, action_id)
	_record_town_action_result("recruit", full_action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_market_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := TownRules.perform_market_action(_session, action_id)
	if result.is_empty():
		return
	_record_town_action_result("market", action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_hero_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := {}
	if action_id.begins_with("switch_hero:"):
		result = TownRules.switch_active_hero_at_town(_session, action_id.trim_prefix("switch_hero:"))
	if result.is_empty():
		return
	_record_town_action_result("order", action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_tavern_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := {}
	if action_id.begins_with("hire_hero:"):
		result = TownRules.hire_hero_at_active_town(_session, action_id.trim_prefix("hire_hero:"))
	if result.is_empty():
		return
	_record_town_action_result("order", action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_transfer_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := TownRules.transfer_in_active_town(_session, action_id)
	if result.is_empty():
		return
	_record_town_action_result("order", action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_response_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := TownRules.perform_response_action(_session, action_id)
	if result.is_empty():
		return
	_record_town_action_result("response", action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_study_action_pressed(action_id: String) -> void:
	var full_action_id := "learn_spell:%s" % action_id
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(full_action_id)
	var result := TownRules.learn_spell_at_active_town(_session, action_id)
	_record_town_action_result("order", full_action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_artifact_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := TownRules.manage_artifact_at_active_town(_session, action_id)
	_record_town_action_result("order", action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_specialty_action_pressed(action_id: String) -> void:
	var before := TownRules.town_action_consequence_signature(_session)
	var action := _validation_action_for_id(action_id)
	var result := {}
	if action_id.begins_with("choose_specialty:"):
		result = TownRules.choose_specialty_at_active_town(_session, action_id.trim_prefix("choose_specialty:"))
	_record_town_action_result("order", action_id, action, result, before)
	if _handle_session_resolution():
		return
	_refresh()

func _on_save_pressed() -> void:
	var result := AppRouter.save_active_session_to_selected_manual_slot()
	_last_message = String(result.get("message", ""))
	_last_action_recap = {}
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
	OverworldRules.begin_normalized_read_scope(_session)
	TownRules.begin_read_scope(_session)
	if not TownRules.can_visit_active_town(_session):
		TownRules.end_read_scope(_session)
		OverworldRules.end_normalized_read_scope(_session)
		AppRouter.go_to_overworld()
		return

	_header_label.text = TownRules.describe_header(_session)
	_status_label.text = TownRules.describe_status(_session)
	_resource_label.text = OverworldRules.describe_resources(_session)
	_crest_label.text = _crest_text()
	if _crest_glyph.has_method("set_glyph"):
		_crest_glyph.call("set_glyph", "town", _faction_accent())
	_set_compact_label(_outlook_label, TownRules.describe_outlook_board(_session), 4)
	_set_compact_label(_command_ledger_label, TownRules.describe_command_ledger(_session), 4)
	_set_compact_label(_hero_label, OverworldRules.describe_hero(_session), 2)
	_set_compact_label(_production_overview_label, TownRules.describe_production_overview(_session), 4)
	_set_compact_label(_heroes_label, TownRules.describe_heroes(_session), 2)
	_set_compact_label(_specialty_label, TownRules.describe_specialties(_session), 2)
	_set_compact_label(_army_label, OverworldRules.describe_army(_session), 2)
	_set_compact_label(_town_label, TownRules.describe_summary(_session), 5)
	_set_compact_label(_defense_label, TownRules.describe_defense(_session), 4)
	_set_compact_label(_pressure_label, TownRules.describe_threats(_session), 4)
	_set_compact_label(_building_label, TownRules.describe_buildings(_session), 2)
	_set_compact_label(_market_label, TownRules.describe_market(_session), 2)
	_set_compact_label(_recruit_label, TownRules.describe_recruitment(_session), 2)
	_set_compact_label(_tavern_label, TownRules.describe_tavern(_session), 2)
	_set_compact_label(_transfer_label, TownRules.describe_transfer(_session), 2)
	_set_compact_label(_response_label, TownRules.describe_responses(_session), 2)
	_set_compact_label(_study_label, TownRules.describe_spell_access(_session), 2)
	_set_compact_label(_spellbook_label, OverworldRules.describe_spellbook(_session), 2)
	_set_compact_label(_artifact_label, TownRules.describe_artifacts(_session), 2)
	_set_compact_label(_event_label, TownRules.describe_event_feed(_session, _last_message, _last_action_recap), 2)
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
	TownRules.end_read_scope(_session)
	OverworldRules.end_normalized_read_scope(_session)

func _configure_save_slot_picker() -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))

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
	var current_context := String(surface.get("current_context", ""))
	var save_tooltip_lines := [_save_status_label.text]
	if current_context != "":
		save_tooltip_lines.append("Saving now: %s" % current_context)
	save_tooltip_lines.append("Selected slot:\n%s" % SaveService.describe_slot_details(summary))
	_save_status_label.tooltip_text = "\n".join(save_tooltip_lines)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Town"))
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the active town visit safely."))
	_leave_button.tooltip_text = "Return to the overworld without leaving the current expedition."
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func validation_snapshot() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var occupation := OverworldRules.town_occupation_state(_session, town)
	var front := OverworldRules.town_front_state(_session, town)
	return {
		"scene_path": scene_file_path,
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"scenario_status": _session.scenario_status,
		"game_state": _session.game_state,
		"day": _session.day,
		"town_placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"town_owner": String(town.get("owner", "")),
		"built_building_count": _normalize_string_array(town.get("built_buildings", [])).size(),
		"available_recruits": _duplicate_dictionary(town.get("available_recruits", {})),
		"resources": _duplicate_dictionary(_session.overworld.get("resources", {})),
		"hero_text": OverworldRules.describe_hero(_session),
		"hero_visible_text": _hero_label.text,
		"hero_tooltip_text": _hero_label.tooltip_text,
		"heroes_text": TownRules.describe_heroes(_session),
		"heroes_visible_text": _heroes_label.text,
		"heroes_tooltip_text": _heroes_label.tooltip_text,
		"summary": TownRules.describe_summary(_session),
		"production_overview": TownRules.describe_production_overview(_session),
		"visible_production_overview": _production_overview_label.text,
		"army_text": OverworldRules.describe_army(_session),
		"army_visible_text": _army_label.text,
		"defense_text": TownRules.describe_defense(_session),
		"defense_visible_text": _defense_label.text,
		"recruit_text": TownRules.describe_recruitment(_session),
		"recruit_visible_text": _recruit_label.text,
		"study_text": TownRules.describe_spell_access(_session),
		"study_visible_text": _study_label.text,
		"study_tooltip_text": _study_label.tooltip_text,
		"spellbook_text": OverworldRules.describe_spellbook(_session),
		"spellbook_visible_text": _spellbook_label.text,
		"spellbook_tooltip_text": _spellbook_label.tooltip_text,
		"artifact_text": TownRules.describe_artifacts(_session),
		"artifact_visible_text": _artifact_label.text,
		"artifact_tooltip_text": _artifact_label.tooltip_text,
		"artifact_actions": _duplicate_action_array(TownRules.get_artifact_actions(_session)),
		"town_action_recap": _duplicate_dictionary(_last_action_recap),
		"town_action_recap_text": String(_last_action_recap.get("text", "")),
		"visible_consequence_text": _event_label.text,
		"consequence_tooltip_text": _event_label.tooltip_text,
		"front": front,
		"occupation": occupation,
		"base_income": OverworldRules.town_income(town),
		"income": OverworldRules.town_income(town, _session),
		"base_battle_readiness": OverworldRules.town_battle_readiness(town),
		"battle_readiness": OverworldRules.town_battle_readiness(town, _session),
		"frontier_watch": OverworldRules.describe_frontier_threats(_session),
		"build_action_count": TownRules.get_build_actions(_session).size(),
		"recruit_action_count": TownRules.get_recruit_actions(_session).size(),
		"study_action_count": TownRules.get_spell_learning_actions(_session).size(),
		"latest_save_summary": SaveService.latest_loadable_summary(),
	}

func validation_try_progress_action() -> Dictionary:
	var before_signature := JSON.stringify(_validation_progress_signature())
	var lanes := [
		{"lane": "recruit", "actions": TownRules.get_recruit_actions(_session)},
		{"lane": "build", "actions": TownRules.get_build_actions(_session)},
		{"lane": "study", "actions": TownRules.get_spell_learning_actions(_session)},
		{"lane": "market", "actions": TownRules.get_market_actions(_session)},
		{"lane": "response", "actions": TownRules.get_response_actions(_session)},
		{"lane": "tavern", "actions": TownRules.get_tavern_actions(_session)},
		{"lane": "transfer", "actions": TownRules.get_transfer_actions(_session)},
		{"lane": "artifact", "actions": TownRules.get_artifact_actions(_session)},
		{"lane": "specialty", "actions": TownRules.get_specialty_actions(_session)},
		{"lane": "hero", "actions": TownRules.get_hero_actions(_session)},
	]

	for lane_entry in lanes:
		if not (lane_entry is Dictionary):
			continue
		var action := _first_enabled_validation_action(lane_entry.get("actions", []))
		if action.is_empty():
			continue
		var lane := String(lane_entry.get("lane", ""))
		var action_id := String(action.get("id", ""))
		match lane:
			"recruit":
				_on_recruit_action_pressed(action_id.trim_prefix("recruit:"))
			"build":
				_on_build_action_pressed(action_id.trim_prefix("build:"))
			"study":
				_on_study_action_pressed(action_id.trim_prefix("learn_spell:"))
			"market":
				_on_market_action_pressed(action_id)
			"response":
				_on_response_action_pressed(action_id)
			"tavern":
				_on_tavern_action_pressed(action_id)
			"transfer":
				_on_transfer_action_pressed(action_id)
			"artifact":
				_on_artifact_action_pressed(action_id)
			"specialty":
				_on_specialty_action_pressed(action_id)
			"hero":
				_on_hero_action_pressed(action_id)
			_:
				continue

		var after_signature := JSON.stringify(_validation_progress_signature())
		return {
			"ok": before_signature != after_signature,
			"lane": lane,
			"action_id": action_id,
			"label": String(action.get("label", action_id)),
			"message": _last_message,
			"town_action_recap": _duplicate_dictionary(_last_action_recap),
			"town_action_recap_text": String(_last_action_recap.get("text", "")),
			"visible_consequence_text": _event_label.text,
			"consequence_tooltip_text": _event_label.tooltip_text,
			"state_changed": before_signature != after_signature,
		}

	return {
		"ok": false,
		"message": "No enabled town validation action is available.",
	}

func validation_action_catalog() -> Dictionary:
	return {
		"recruit": _duplicate_action_array(TownRules.get_recruit_actions(_session)),
		"build": _duplicate_action_array(TownRules.get_build_actions(_session)),
		"study": _duplicate_action_array(TownRules.get_spell_learning_actions(_session)),
		"market": _duplicate_action_array(TownRules.get_market_actions(_session)),
		"response": _duplicate_action_array(TownRules.get_response_actions(_session)),
		"tavern": _duplicate_action_array(TownRules.get_tavern_actions(_session)),
		"transfer": _duplicate_action_array(TownRules.get_transfer_actions(_session)),
		"artifact": _duplicate_action_array(TownRules.get_artifact_actions(_session)),
		"specialty": _duplicate_action_array(TownRules.get_specialty_actions(_session)),
		"hero": _duplicate_action_array(TownRules.get_hero_actions(_session)),
	}

func validation_perform_town_action(action_id: String) -> Dictionary:
	var action := _validation_action_for_id(action_id)
	if action.is_empty():
		return {
			"ok": false,
			"action_id": action_id,
			"message": "No enabled town validation action matched the requested id.",
		}

	var before_signature := JSON.stringify(_validation_progress_signature())
	var lane := String(action.get("lane", ""))
	match lane:
		"recruit":
			_on_recruit_action_pressed(action_id.trim_prefix("recruit:"))
		"build":
			_on_build_action_pressed(action_id.trim_prefix("build:"))
		"study":
			_on_study_action_pressed(action_id.trim_prefix("learn_spell:"))
		"market":
			_on_market_action_pressed(action_id)
		"response":
			_on_response_action_pressed(action_id)
		"tavern":
			_on_tavern_action_pressed(action_id)
		"transfer":
			_on_transfer_action_pressed(action_id)
		"artifact":
			_on_artifact_action_pressed(action_id)
		"specialty":
			_on_specialty_action_pressed(action_id)
		"hero":
			_on_hero_action_pressed(action_id)
		_:
			return {
				"ok": false,
				"action_id": action_id,
				"message": "Unsupported town validation action lane.",
			}

	var after_signature := JSON.stringify(_validation_progress_signature())
	return {
		"ok": before_signature != after_signature,
		"lane": lane,
		"action_id": action_id,
		"label": String(action.get("label", action_id)),
		"message": _last_message,
		"town_action_recap": _duplicate_dictionary(_last_action_recap),
		"town_action_recap_text": String(_last_action_recap.get("text", "")),
		"visible_consequence_text": _event_label.text,
		"consequence_tooltip_text": _event_label.tooltip_text,
		"state_changed": before_signature != after_signature,
	}

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
	var town := TownRules.get_active_town(_session)
	_on_menu_pressed()
	return {
		"ok": true,
		"town_placement_id": String(town.get("placement_id", "")),
		"message": "Town route returned to the main menu.",
	}

func validation_leave_town() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	_on_leave_pressed()
	return {
		"ok": true,
		"town_placement_id": String(town.get("placement_id", "")),
		"message": "Town route closed.",
	}

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
		button.text = String(action.get("button_label", action.get("label", action.get("id", "Build"))))
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
		button.text = String(action.get("button_label", action.get("label", action.get("id", "Recruit"))))
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

func _record_town_action_result(
	lane: String,
	action_id: String,
	action: Dictionary,
	result: Dictionary,
	before: Dictionary
) -> void:
	_last_message = String(result.get("message", ""))
	_last_action_recap = TownRules.build_town_action_recap(_session, lane, action_id, action, result, before)

func _handle_session_resolution() -> bool:
	if _session.scenario_status == "in_progress":
		return false
	AppRouter.go_to_scenario_outcome()
	return true

func _first_enabled_validation_action(actions: Variant) -> Dictionary:
	if not (actions is Array):
		return {}
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return action
	return {}

func _duplicate_action_array(actions: Variant) -> Array:
	var duplicated := []
	if not (actions is Array):
		return duplicated
	for action in actions:
		if action is Dictionary:
			duplicated.append(action.duplicate(true))
	return duplicated

func _validation_action_for_id(action_id: String) -> Dictionary:
	var catalog := validation_action_catalog()
	for lane in catalog.keys():
		var actions = catalog.get(lane, [])
		if not (actions is Array):
			continue
		for action in actions:
			if not (action is Dictionary):
				continue
			if bool(action.get("disabled", false)):
				continue
			if String(action.get("id", "")) != action_id:
				continue
			var result: Dictionary = action.duplicate(true)
			result["lane"] = String(lane)
			return result
	return {}

func _validation_progress_signature() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var hero_value: Variant = _session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var spellbook_value: Variant = hero.get("spellbook", {})
	var spellbook: Dictionary = spellbook_value if spellbook_value is Dictionary else {}
	return {
		"active_hero_id": String(_session.overworld.get("active_hero_id", "")),
		"resources": _duplicate_dictionary(_session.overworld.get("resources", {})),
		"army": _duplicate_dictionary(_session.overworld.get("army", {})),
		"specialties": _normalize_string_array(hero.get("specialties", [])),
		"pending_specialty_choices": _duplicate_array(hero.get("pending_specialty_choices", [])),
		"built_buildings": _normalize_string_array(town.get("built_buildings", [])),
		"available_recruits": _duplicate_dictionary(town.get("available_recruits", {})),
		"known_spell_ids": _normalize_string_array(spellbook.get("known_spell_ids", [])),
		"artifacts": _duplicate_dictionary(hero.get("artifacts", {})),
	}

func _duplicate_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _duplicate_array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []

func _normalize_string_array(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not (value is Array):
		return normalized
	for entry in value:
		var text := String(entry)
		if text != "":
			normalized.append(text)
	return normalized

func _make_placeholder_label(text: String) -> Label:
	var label := FrontierVisualKit.placeholder_label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.custom_minimum_size = Vector2(188.0, 24.0)
	label.tooltip_text = text
	return label

func _set_compact_label(label: Label, full_text: String, max_lines: int) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines)

func _crest_text() -> String:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return "TOWN"
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(template.get("faction_id", "")))
	var name := String(faction.get("name", template.get("faction_id", "Town")))
	return name.left(4).to_upper()

func _style_action_button(button: Button, primary: bool = false) -> void:
	FrontierVisualKit.apply_button(button, "primary" if primary else "secondary", 108.0, 30.0, 12)

func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_panel(_banner_panel, "banner")
	FrontierVisualKit.apply_badge(_crest_panel, "gold")
	FrontierVisualKit.apply_panel(_town_stage_panel, "earth")
	FrontierVisualKit.apply_panel(_town_stage_frame_panel, "frame")
	FrontierVisualKit.apply_panel(_sidebar_shell_panel, "ink")
	FrontierVisualKit.apply_panel(_command_panel, "ink")
	FrontierVisualKit.apply_panel(_town_panel, "gold")
	FrontierVisualKit.apply_panel(_outlook_panel, "teal")
	FrontierVisualKit.apply_panel(_command_ledger_panel, "earth")
	FrontierVisualKit.apply_panel(_build_panel, "earth")
	FrontierVisualKit.apply_panel(_recruit_panel, "green")
	FrontierVisualKit.apply_panel(_study_panel, "blue")
	FrontierVisualKit.apply_panel(_market_panel, "gold")
	FrontierVisualKit.apply_panel(_logistics_panel, "teal")
	FrontierVisualKit.apply_panel(_footer_panel, "banner")
	FrontierVisualKit.apply_tab_container(_management_tabs)
	_management_tabs.set_tab_title(0, "Build")
	_management_tabs.set_tab_title(1, "Muster")
	_management_tabs.set_tab_title(2, "Spells")
	_management_tabs.set_tab_title(3, "Trade")
	_management_tabs.set_tab_title(4, "Log")

	for button in [_save_button, _leave_button, _menu_button]:
		_style_action_button(button, true)
	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 112.0, 32.0, 12)

	for label in find_children("*Title", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "title", 13)

	FrontierVisualKit.apply_label(_header_label, "title", 20)
	FrontierVisualKit.apply_label(_status_label, "body", 12)
	FrontierVisualKit.apply_label(_resource_label, "gold", 12)
	FrontierVisualKit.apply_label(_crest_label, "title", 16)
	FrontierVisualKit.apply_label(_event_label, "body", 12)
	FrontierVisualKit.apply_label(_save_status_label, "muted", 12)

	FrontierVisualKit.apply_labels([
		_outlook_label,
		_command_ledger_label,
		_hero_label,
		_production_overview_label,
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
	], "body", 12)

func _faction_accent() -> Color:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return Color(0.88, 0.72, 0.40, 1.0)
	var template := ContentService.get_town(String(town.get("town_id", "")))
	match String(template.get("faction_id", "")):
		"faction_embercourt":
			return Color(0.88, 0.58, 0.34, 1.0)
		"faction_mireclaw":
			return Color(0.52, 0.74, 0.43, 1.0)
		"faction_sunvault":
			return Color(0.89, 0.77, 0.36, 1.0)
		"faction_thornwake":
			return Color(0.54, 0.70, 0.40, 1.0)
		"faction_brasshollow":
			return Color(0.76, 0.57, 0.34, 1.0)
		"faction_veilmourn":
			return Color(0.50, 0.62, 0.72, 1.0)
		_:
			return Color(0.88, 0.72, 0.40, 1.0)
