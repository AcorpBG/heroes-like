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
	_session.game_state = "town"
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
	_prepare_town_return_handoff()
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
	var build_readiness := _build_readiness_surface()
	var build_text := _join_tooltip_sections([
		String(build_readiness.get("visible_text", "")),
		TownRules.describe_buildings(_session),
	])
	_set_compact_label(_building_label, build_text, 2)
	_building_label.tooltip_text = _join_tooltip_sections([
		String(build_readiness.get("tooltip_text", "")),
		TownRules.describe_buildings(_session),
	])
	var market_readiness := _market_readiness_surface()
	var market_text := _join_tooltip_sections([
		String(market_readiness.get("visible_text", "")),
		TownRules.describe_market(_session),
	])
	_set_compact_label(_market_label, market_text, 2)
	_market_label.tooltip_text = _join_tooltip_sections([
		String(market_readiness.get("tooltip_text", "")),
		TownRules.describe_market(_session),
	])
	var muster_readiness := _muster_readiness_surface()
	var recruit_text := _join_tooltip_sections([
		String(muster_readiness.get("visible_text", "")),
		TownRules.describe_recruitment(_session),
	])
	_set_compact_label(_recruit_label, recruit_text, 2)
	_recruit_label.tooltip_text = _join_tooltip_sections([
		String(muster_readiness.get("tooltip_text", "")),
		TownRules.describe_recruitment(_session),
	])
	_set_compact_label(_tavern_label, TownRules.describe_tavern(_session), 2)
	_set_compact_label(_transfer_label, TownRules.describe_transfer(_session), 2)
	_set_compact_label(_response_label, TownRules.describe_responses(_session), 2)
	var study_readiness := _study_readiness_surface()
	var study_text := _join_tooltip_sections([
		String(study_readiness.get("visible_text", "")),
		TownRules.describe_spell_access(_session),
	])
	_set_compact_label(_study_label, study_text, 2)
	_study_label.tooltip_text = _join_tooltip_sections([
		String(study_readiness.get("tooltip_text", "")),
		TownRules.describe_spell_access(_session),
	])
	_set_compact_label(_spellbook_label, OverworldRules.describe_spellbook(_session), 2)
	var artifact_readiness := _artifact_readiness_surface()
	var artifact_text := _join_tooltip_sections([
		String(artifact_readiness.get("visible_text", "")),
		TownRules.describe_artifacts(_session),
	])
	_set_compact_label(_artifact_label, artifact_text, 2)
	_artifact_label.tooltip_text = _join_tooltip_sections([
		String(artifact_readiness.get("tooltip_text", "")),
		TownRules.describe_artifacts(_session),
	])
	var dispatch_text := TownRules.describe_event_feed(_session, _last_message, _last_action_recap)
	var order_target := TownRules.town_order_target_handoff(_session)
	var town_context_surface := _town_action_context_surface(dispatch_text)
	if town_context_surface.is_empty():
		_set_compact_label(_event_label, "%s\n%s" % [String(order_target.get("visible_text", "")), dispatch_text], 2)
		_event_label.tooltip_text = _join_tooltip_sections([
			String(order_target.get("tooltip_text", "")),
			dispatch_text,
		])
	else:
		_set_compact_label(_event_label, "%s\n%s" % [String(town_context_surface.get("visible_text", "")), String(order_target.get("visible_text", ""))], 2)
		_event_label.tooltip_text = _join_tooltip_sections([
			String(town_context_surface.get("tooltip_text", "")),
			String(order_target.get("tooltip_text", "")),
			dispatch_text,
		])
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
	_refresh_management_tab_cues()
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
	var latest_context := String(surface.get("latest_context", "Latest ready save: none."))
	var save_check := String(surface.get("save_check", ""))
	var save_handoff := String(surface.get("save_handoff", ""))
	var save_handoff_brief := String(surface.get("save_handoff_brief", ""))
	var return_handoff := String(surface.get("return_handoff", ""))
	var current_save_recap := String(surface.get("current_save_recap", ""))
	_save_status_label.visible = save_handoff_brief != ""
	_save_status_label.text = save_handoff_brief if save_handoff_brief != "" else latest_context
	var current_context := String(surface.get("current_context", ""))
	var save_tooltip_lines := [latest_context]
	if save_handoff != "":
		save_tooltip_lines.append(save_handoff)
	if save_check != "":
		save_tooltip_lines.append(save_check)
	if return_handoff != "":
		save_tooltip_lines.append(return_handoff)
	if current_save_recap != "":
		save_tooltip_lines.append("Saving now recap:\n%s" % current_save_recap)
	if current_context != "":
		save_tooltip_lines.append("Saving now: %s" % current_context)
	save_tooltip_lines.append("Selected slot:\n%s" % SaveService.describe_slot_details(summary))
	_save_status_label.tooltip_text = "\n".join(save_tooltip_lines)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Town"))
	_save_button.tooltip_text = _join_tooltip_sections([
		String(surface.get("save_button_tooltip", "Save the active town visit safely.")),
		save_handoff,
		save_check,
	])
	var departure := TownRules.town_departure_confirmation(_session)
	_leave_button.text = String(departure.get("button_label", "Leave"))
	_leave_button.tooltip_text = String(departure.get("tooltip_text", "Return to the overworld without leaving the current expedition."))
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

func validation_snapshot() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var occupation := OverworldRules.town_occupation_state(_session, town)
	var front := OverworldRules.town_front_state(_session, town)
	var handoff := TownRules.town_handoff_recap(_session)
	var departure := TownRules.town_departure_confirmation(_session)
	var order_target := TownRules.town_order_target_handoff(_session)
	var dispatch_text := TownRules.describe_event_feed(_session, _last_message, _last_action_recap)
	var town_context_surface := _town_action_context_surface(dispatch_text)
	var tab_readiness := _management_tab_readiness_payload()
	var build_readiness := _build_readiness_surface()
	var market_readiness := _market_readiness_surface()
	var muster_readiness := _muster_readiness_surface()
	var study_readiness := _study_readiness_surface()
	var artifact_readiness := _artifact_readiness_surface()
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
		"build_text": TownRules.describe_buildings(_session),
		"build_visible_text": _building_label.text,
		"build_tooltip_text": _building_label.tooltip_text,
		"build_readiness": build_readiness,
		"build_readiness_visible_text": String(build_readiness.get("visible_text", "")),
		"build_readiness_tooltip_text": String(build_readiness.get("tooltip_text", "")),
		"market_text": TownRules.describe_market(_session),
		"market_visible_text": _market_label.text,
		"market_tooltip_text": _market_label.tooltip_text,
		"market_readiness": market_readiness,
		"market_readiness_visible_text": String(market_readiness.get("visible_text", "")),
		"market_readiness_tooltip_text": String(market_readiness.get("tooltip_text", "")),
		"recruit_text": TownRules.describe_recruitment(_session),
		"recruit_visible_text": _recruit_label.text,
		"recruit_tooltip_text": _recruit_label.tooltip_text,
		"muster_readiness": muster_readiness,
		"muster_readiness_visible_text": String(muster_readiness.get("visible_text", "")),
		"muster_readiness_tooltip_text": String(muster_readiness.get("tooltip_text", "")),
		"study_text": TownRules.describe_spell_access(_session),
		"study_visible_text": _study_label.text,
		"study_tooltip_text": _study_label.tooltip_text,
		"study_readiness": study_readiness,
		"study_readiness_visible_text": String(study_readiness.get("visible_text", "")),
		"study_readiness_tooltip_text": String(study_readiness.get("tooltip_text", "")),
		"spellbook_text": OverworldRules.describe_spellbook(_session),
		"spellbook_visible_text": _spellbook_label.text,
		"spellbook_tooltip_text": _spellbook_label.tooltip_text,
		"artifact_text": TownRules.describe_artifacts(_session),
		"artifact_visible_text": _artifact_label.text,
		"artifact_tooltip_text": _artifact_label.tooltip_text,
		"artifact_readiness": artifact_readiness,
		"artifact_readiness_visible_text": String(artifact_readiness.get("visible_text", "")),
		"artifact_readiness_tooltip_text": String(artifact_readiness.get("tooltip_text", "")),
		"artifact_actions": _duplicate_action_array(TownRules.get_artifact_actions(_session)),
		"town_action_recap": _duplicate_dictionary(_last_action_recap),
		"town_action_recap_text": String(_last_action_recap.get("text", "")),
		"town_handoff": handoff,
		"town_handoff_visible_text": String(handoff.get("visible_text", "")),
		"town_handoff_tooltip_text": String(handoff.get("tooltip_text", "")),
		"town_departure_confirmation": departure,
		"town_departure_visible_text": String(departure.get("visible_text", "")),
		"town_order_target_handoff": order_target,
		"town_order_target_visible_text": String(order_target.get("visible_text", "")),
		"town_order_target_tooltip_text": String(order_target.get("tooltip_text", "")),
		"town_action_context": town_context_surface,
		"town_action_context_text": String(town_context_surface.get("visible_text", "")),
		"town_action_context_tooltip_text": String(town_context_surface.get("tooltip_text", "")),
		"town_tab_readiness": tab_readiness,
		"town_tab_titles": _management_tab_titles(),
		"town_tab_readiness_tooltip_text": _management_tabs.tooltip_text,
		"town_action_button_tooltips": _town_action_button_tooltip_snapshot(),
		"town_active_tab": _management_tabs.current_tab,
		"leave_button_text": _leave_button.text,
		"leave_button_tooltip_text": _leave_button.tooltip_text,
		"save_surface": AppRouter.active_save_surface(),
		"save_handoff_visible_text": _save_status_label.text,
		"save_handoff_visible": _save_status_label.visible,
		"save_button_text": _save_button.text,
		"save_button_tooltip_text": _save_button.tooltip_text,
		"save_status_visible_text": _save_status_label.text,
		"save_status_tooltip_text": _save_status_label.tooltip_text,
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

func validation_prepare_town_return_handoff() -> Dictionary:
	return _prepare_town_return_handoff()

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
		button.tooltip_text = _town_action_button_tooltip(action, "hero")
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
		button.tooltip_text = _town_action_button_tooltip(action, "build")
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
		button.tooltip_text = _town_action_button_tooltip(action, "market")
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
		button.tooltip_text = _town_action_button_tooltip(action, "recruit")
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
		button.tooltip_text = _town_action_button_tooltip(action, "tavern")
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
		button.tooltip_text = _town_action_button_tooltip(action, "transfer")
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
		button.tooltip_text = _town_action_button_tooltip(action, "response")
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
		button.tooltip_text = _town_action_button_tooltip(action, "study")
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
		button.tooltip_text = _town_action_button_tooltip(action, "artifact")
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
		button.tooltip_text = _town_action_button_tooltip(action, "specialty")
		_style_action_button(button)
		button.pressed.connect(_on_specialty_action_pressed.bind(String(action.get("id", ""))))
		_specialty_actions.add_child(button)

func _town_action_button_tooltip(action: Dictionary, lane: String) -> String:
	var summary := String(action.get("summary", "")).strip_edges()
	return _join_tooltip_sections([
		_town_action_button_cue_text(action, lane),
		summary,
	])

func _town_action_button_cue_text(action: Dictionary, lane: String) -> String:
	var label := String(action.get("button_label", action.get("label", action.get("id", "Order")))).strip_edges()
	if label == "":
		label = "Order"
	var lane_label := _town_action_lane_label(lane)
	var surface := _town_action_surface_label(lane)
	var readiness := _town_action_button_readiness(action, lane)
	var impact := _town_action_button_impact(action, lane)
	var next_step := _town_action_button_next_step(action, lane, label, surface, readiness)
	return "Command cue: %s | %s | %s | Next: %s" % [
		lane_label,
		_short_text(readiness, 46),
		_short_text(impact, 54),
		_short_text(next_step, 72),
	]

func _town_action_button_readiness(action: Dictionary, lane: String) -> String:
	if bool(action.get("disabled", false)):
		if lane == "market":
			return "Blocked by current stores"
		return String(action.get("disabled_reason", "Blocked by current town state")).strip_edges()
	if lane == "build":
		if bool(action.get("direct_affordable", false)):
			return "Ready now"
		if bool(action.get("market_coverable", false)):
			var market_summary := String(action.get("market_summary", "")).strip_edges()
			return "Needs exchange first%s" % (": %s" % market_summary if market_summary != "" else "")
	if lane == "recruit":
		var direct_count := int(action.get("direct_affordable_count", 0))
		if direct_count > 0:
			return "Ready x%d" % direct_count
		var market_count := int(action.get("market_affordable_count", 0))
		if market_count > 0:
			var recruit_market := String(action.get("market_summary", "")).strip_edges()
			return "Needs exchange x%d%s" % [market_count, ": %s" % recruit_market if recruit_market != "" else ""]
	var affordability := String(action.get("affordability_label", "")).strip_edges()
	if affordability != "":
		return affordability
	return "Ready now"

func _town_action_button_impact(action: Dictionary, lane: String) -> String:
	for key in ["impact_line", "recommendation_line", "delivery_summary"]:
		var value := String(action.get(key, "")).strip_edges()
		if value != "":
			return value.trim_suffix(".")
	var summary := String(action.get("summary", "")).strip_edges()
	if summary != "":
		for line_value in summary.split("\n", false):
			var line := String(line_value).strip_edges()
			if line != "":
				return line.trim_suffix(".")
	return "%s keeps the town plan moving" % _town_action_lane_label(lane).to_lower()

func _town_action_button_next_step(action: Dictionary, lane: String, label: String, surface: String, readiness: String) -> String:
	if bool(action.get("disabled", false)):
		return "Resolve %s before pressing %s in %s." % [readiness.to_lower(), label, surface]
	if lane in ["build", "recruit"] and readiness.begins_with("Needs exchange"):
		return "Use Trade, then press %s in %s." % [label, surface]
	return "Press %s in %s, or leave when town orders are set." % [label, surface]

func _town_action_lane_label(lane: String) -> String:
	match lane:
		"build":
			return "Construction"
		"recruit":
			return "Recruitment"
		"market":
			return "Exchange"
		"study":
			return "Spell study"
		"hero":
			return "Commander"
		"tavern":
			return "Hero hire"
		"transfer":
			return "Transfer"
		"response":
			return "Strategic response"
		"artifact":
			return "Artifact"
		"specialty":
			return "Specialty"
		_:
			return "Town order"

func _town_action_surface_label(lane: String) -> String:
	match lane:
		"build":
			return "Build tab"
		"recruit", "hero", "tavern", "transfer", "specialty":
			return "Muster tab"
		"study", "artifact":
			return "Spells tab"
		"market":
			return "Trade tab"
		"response":
			return "Log tab"
		_:
			return "Town orders"

func _town_action_button_tooltip_snapshot() -> Dictionary:
	return {
		"build": _button_tooltips(_build_actions),
		"recruit": _button_tooltips(_recruit_actions),
		"study": _button_tooltips(_study_actions),
		"market": _button_tooltips(_market_actions),
		"hero": _button_tooltips(_hero_actions),
		"tavern": _button_tooltips(_tavern_actions),
		"transfer": _button_tooltips(_transfer_actions),
		"response": _button_tooltips(_response_actions),
		"artifact": _button_tooltips(_artifact_actions),
		"specialty": _button_tooltips(_specialty_actions),
	}

func _button_tooltips(container: Container) -> Array:
	var tooltips := []
	for child in container.get_children():
		if child is Button:
			tooltips.append({
				"text": child.text,
				"tooltip": child.tooltip_text,
				"disabled": child.disabled,
			})
	return tooltips

func _build_readiness_surface() -> Dictionary:
	var actions := TownRules.get_build_actions(_session)
	var town := TownRules.get_active_town(_session)
	var built_buildings := _normalize_string_array(town.get("built_buildings", []))
	var ready_orders := 0
	var market_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_market := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("direct_affordable", false)):
			ready_orders += 1
			if best_ready.is_empty():
				best_ready = action
			continue
		if bool(action.get("market_coverable", false)):
			market_orders += 1
			if best_market.is_empty():
				best_market = action
			continue
		blocked_orders += 1
		if best_blocked.is_empty():
			best_blocked = action

	var selected_action := best_ready
	var state_line := "no open construction orders"
	var visible := "Build check: no open orders"
	if ready_orders > 0:
		state_line = "Ready now: %d construction order%s" % [ready_orders, "" if ready_orders == 1 else "s"]
		visible = "Build check: Ready x%d | %d built" % [ready_orders, built_buildings.size()]
	elif market_orders > 0:
		selected_action = best_market
		state_line = "Trade path: %d construction order%s can be unlocked through Exchange" % [
			market_orders,
			"" if market_orders == 1 else "s",
		]
		visible = "Build check: Trade unlocks x%d" % market_orders
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d construction order%s waiting on stores or prerequisites" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Build check: Blocked x%d waiting" % blocked_orders
	elif not actions.is_empty() and actions[0] is Dictionary:
		selected_action = actions[0]

	var label := "No build order"
	var readiness := state_line
	var impact := "Construction timing shapes town income, defenses, and future muster options."
	var next_step := "Review another town order or leave when the build plan is set."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Build order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "build")
		impact = _town_action_button_impact(selected_action, "build")
		next_step = _town_action_button_next_step(
			selected_action,
			"build",
			label,
			_town_action_surface_label("build"),
			readiness
		)
	var tooltip_lines := [
		"Build Readiness",
		"- Town works: %d built, %d open order%s" % [
			built_buildings.size(),
			actions.size(),
			"" if actions.size() == 1 else "s",
		],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"built_count": built_buildings.size(),
		"open_order_count": actions.size(),
		"ready_order_count": ready_orders,
		"market_order_count": market_orders,
		"blocked_order_count": blocked_orders,
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _market_readiness_surface() -> Dictionary:
	var actions := TownRules.get_market_actions(_session)
	var ready_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if best_blocked.is_empty():
				best_blocked = action
			continue
		ready_orders += 1
		if best_ready.is_empty():
			best_ready = action

	var selected_action := best_ready
	var state_line := "no exchange orders listed"
	var visible := "Trade check: no exchange orders"
	if ready_orders > 0:
		state_line = "Ready now: %d exchange order%s" % [ready_orders, "" if ready_orders == 1 else "s"]
		visible = "Trade check: Ready x%d/%d" % [ready_orders, actions.size()]
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d exchange order%s waiting on stores" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Trade check: Blocked x0/%d" % blocked_orders

	var label := "No exchange order"
	var readiness := state_line
	var impact := "Exchange timing converts spare stock into the resource needed for build or muster orders."
	var next_step := "Build a market before using Trade orders, or return to Build and Muster planning."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Exchange order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "market")
		impact = _town_action_button_impact(selected_action, "market")
		next_step = _town_action_button_next_step(
			selected_action,
			"market",
			label,
			_town_action_surface_label("market"),
			readiness
		)
	elif actions.is_empty():
		var market_text := TownRules.describe_market(_session)
		if market_text.find("No market square") >= 0:
			state_line = "No market square is built here"
			readiness = state_line
			visible = "Trade check: no market"

	var tooltip_lines := [
		"Trade Readiness",
		"- Exchange orders: %d ready, %d blocked, %d listed" % [
			ready_orders,
			blocked_orders,
			actions.size(),
		],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"listed_order_count": actions.size(),
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _study_readiness_surface() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	var actions := TownRules.get_spell_learning_actions(_session)
	var hero_value: Variant = _session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var tier := TownRules.current_spell_tier(town) if not town.is_empty() else 0
	var accessible_count := 0
	var known_count := 0
	if not town.is_empty():
		for spell_id_value in TownRules.accessible_spell_ids(town):
			var spell_id := String(spell_id_value)
			if spell_id == "":
				continue
			accessible_count += 1
			if SpellRules.knows_spell(hero, spell_id):
				known_count += 1

	var ready_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if best_blocked.is_empty():
				best_blocked = action
			continue
		ready_orders += 1
		if best_ready.is_empty():
			best_ready = action

	var selected_action := best_ready
	var state_line := "no archive halls are standing"
	var visible := "Study check: no archive"
	if tier > 0:
		state_line = "no uncatalogued spells remain for this hero"
		visible = "Study check: learned %d/%d" % [known_count, accessible_count]
	if ready_orders > 0:
		state_line = "Ready now: %d spell%s can be learned" % [ready_orders, "" if ready_orders == 1 else "s"]
		visible = "Study check: Ready x%d/%d" % [ready_orders, max(accessible_count, ready_orders)]
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d spell stud%s waiting on town or hero state" % [
			blocked_orders,
			"y" if blocked_orders == 1 else "ies",
		]
		visible = "Study check: Blocked x0/%d" % blocked_orders

	var label := "No spell study order"
	var readiness := state_line
	var impact := "Spell study expands the hero's field and battle options before leaving town."
	var next_step := "Build archive halls, review the spellbook, or leave when study is settled."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Spell study order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "study")
		impact = _town_action_button_impact(selected_action, "study")
		next_step = _town_action_button_next_step(
			selected_action,
			"study",
			label,
			_town_action_surface_label("study"),
			readiness
		)
	elif tier > 0:
		next_step = "Review the spellbook or leave when town orders are set."

	var tooltip_lines := [
		"Study Readiness",
		"- Archive tier: %d" % tier,
		"- Catalog: %d known, %d learnable, %d accessible" % [
			known_count,
			ready_orders,
			accessible_count,
		],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"archive_tier": tier,
		"accessible_count": accessible_count,
		"known_count": known_count,
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _muster_readiness_surface() -> Dictionary:
	var actions := TownRules.get_recruit_actions(_session)
	var town := TownRules.get_active_town(_session)
	var reserve_total := 0
	var ready_units := 0
	var market_units := 0
	var blocked_reserve := 0
	var ready_orders := 0
	var market_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_market := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var available := int(action.get("available_count", 0))
		var direct_count := int(action.get("direct_affordable_count", 0))
		var market_count := int(action.get("market_affordable_count", 0))
		reserve_total += max(0, available)
		if direct_count > 0:
			ready_orders += 1
			ready_units += direct_count
			if best_ready.is_empty() or direct_count > int(best_ready.get("direct_affordable_count", 0)):
				best_ready = action
			continue
		if market_count > 0:
			market_orders += 1
			market_units += market_count
			if best_market.is_empty() or market_count > int(best_market.get("market_affordable_count", 0)):
				best_market = action
			continue
		if available > 0:
			blocked_orders += 1
			blocked_reserve += available
			if best_blocked.is_empty() or available > int(best_blocked.get("available_count", 0)):
				best_blocked = action

	var selected_action := best_ready
	var state_line := "no recruits waiting"
	var visible := "Muster check: no recruits waiting"
	if ready_units > 0:
		state_line = "Ready now: %d recruit%s across %d order%s" % [
			ready_units,
			"" if ready_units == 1 else "s",
			ready_orders,
			"" if ready_orders == 1 else "s",
		]
		visible = "Muster check: Ready x%d/%d | %d order%s" % [
			ready_units,
			reserve_total,
			ready_orders,
			"" if ready_orders == 1 else "s",
		]
	elif market_units > 0:
		selected_action = best_market
		state_line = "Trade path: %d recruit%s can be unlocked through Exchange" % [
			market_units,
			"" if market_units == 1 else "s",
		]
		visible = "Muster check: Trade unlocks x%d/%d" % [market_units, reserve_total]
	elif blocked_reserve > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d recruit%s waiting on stores or prerequisites" % [
			blocked_reserve,
			"" if blocked_reserve == 1 else "s",
		]
		visible = "Muster check: Blocked x0/%d waiting" % blocked_reserve
	elif not actions.is_empty() and actions[0] is Dictionary:
		selected_action = actions[0]

	var label := "No recruit order"
	var readiness := state_line
	var impact := "Muster timing shapes field army strength before leaving town."
	var next_step := "Review another town order or leave when the muster plan is set."
	var cap_line := "No recruit stack is waiting in reserve."
	var best_available := 0
	var best_direct := 0
	var best_market_count := 0
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Recruit order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "recruit")
		impact = _town_action_button_impact(selected_action, "recruit")
		best_available = max(0, int(selected_action.get("available_count", 0)))
		best_direct = max(0, int(selected_action.get("direct_affordable_count", 0)))
		best_market_count = max(0, int(selected_action.get("market_affordable_count", 0)))
		var stack_label := _short_text(label.trim_prefix("Recruit "), 32)
		if best_direct > 0:
			cap_line = "%s can field %d of %d now; %d stay in reserve." % [
				stack_label,
				best_direct,
				best_available,
				max(0, best_available - best_direct),
			]
		elif best_market_count > 0:
			cap_line = "%s can unlock %d of %d through Exchange; %d still wait." % [
				stack_label,
				best_market_count,
				best_available,
				max(0, best_available - best_market_count),
			]
		elif best_available > 0:
			cap_line = "%s has %d waiting; stores field 0 now." % [stack_label, best_available]
		else:
			cap_line = "%s has no reserve waiting; next levy refills later." % stack_label
		next_step = _town_action_button_next_step(
			selected_action,
			"recruit",
			label,
			_town_action_surface_label("recruit"),
			readiness
		)
	var weekly_line := ""
	if not town.is_empty():
		weekly_line = "Weekly reserve: %s on Day %d" % [
			TownRules._describe_recruit_delta(OverworldRules.town_weekly_growth(town, _session)),
			OverworldRules.next_weekly_growth_day(_session.day),
		]
	var tooltip_lines := [
		"Muster Readiness",
		"- Town reserve: %d waiting across %d order%s" % [
			reserve_total,
			actions.size(),
			"" if actions.size() == 1 else "s",
		],
		"- %s" % state_line,
	]
	if weekly_line != "":
		tooltip_lines.append("- %s" % weekly_line)
	tooltip_lines.append("- Best order: %s" % label)
	tooltip_lines.append("- Best cap: %s" % cap_line)
	tooltip_lines.append("- Readiness: %s" % readiness)
	tooltip_lines.append("- Why it matters: %s" % impact)
	tooltip_lines.append("- Next practical action: %s" % next_step)
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"reserve_total": reserve_total,
		"ready_units": ready_units,
		"market_units": market_units,
		"blocked_reserve": blocked_reserve,
		"ready_order_count": ready_orders,
		"market_order_count": market_orders,
		"blocked_order_count": blocked_orders,
		"best_order_label": label,
		"best_order_available_count": best_available,
		"best_order_direct_count": best_direct,
		"best_order_market_count": best_market_count,
		"cap_line": cap_line,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _artifact_readiness_surface() -> Dictionary:
	var actions := TownRules.get_artifact_actions(_session)
	var hero_value: Variant = _session.overworld.get("hero", {})
	var hero: Dictionary = hero_value if hero_value is Dictionary else {}
	var artifacts := ArtifactRules.normalize_hero_artifacts(hero.get("artifacts", {}))
	var equipped: Dictionary = artifacts.get("equipped", {}) if artifacts.get("equipped", {}) is Dictionary else {}
	var inventory: Array = artifacts.get("inventory", []) if artifacts.get("inventory", []) is Array else []
	var equipped_count := 0
	var empty_slot_count := 0
	for slot in ArtifactRules.EQUIPMENT_SLOTS:
		if String(equipped.get(slot, "")) != "":
			equipped_count += 1
		else:
			empty_slot_count += 1

	var ready_orders := 0
	var blocked_orders := 0
	var best_ready := {}
	var best_blocked := {}
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		if bool(action.get("disabled", false)):
			blocked_orders += 1
			if best_blocked.is_empty():
				best_blocked = action
			continue
		ready_orders += 1
		if best_ready.is_empty():
			best_ready = action

	var owned_count := ArtifactRules.owned_artifact_ids(hero).size()
	var total_known := ContentService.get_content_ids(ContentService.ARTIFACTS_PATH).size()
	var selected_action := best_ready
	var state_line := "no relics owned yet"
	var visible := "Gear check: no relics"
	if ready_orders > 0:
		state_line = "Ready now: %d gear order%s can adjust the loadout" % [
			ready_orders,
			"" if ready_orders == 1 else "s",
		]
		visible = "Gear check: Ready x%d | %d equipped" % [ready_orders, equipped_count]
	elif blocked_orders > 0:
		selected_action = best_blocked
		state_line = "Blocked: %d gear order%s waiting on current loadout state" % [
			blocked_orders,
			"" if blocked_orders == 1 else "s",
		]
		visible = "Gear check: Blocked x0/%d" % blocked_orders
	elif owned_count > 0:
		state_line = "Loadout set: %d equipped, %d in pack" % [equipped_count, inventory.size()]
		visible = "Gear check: Loadout %d/%d | Pack %d" % [
			equipped_count,
			ArtifactRules.EQUIPMENT_SLOTS.size(),
			inventory.size(),
		]

	var label := "No gear order"
	var readiness := state_line
	var impact := "Gear changes shape field movement, scouting, economy, and battle command before leaving town."
	var next_step := "Recover relics in the field, or leave when the current loadout is settled."
	if not selected_action.is_empty():
		label = String(selected_action.get("button_label", selected_action.get("label", "Gear order"))).strip_edges()
		readiness = _town_action_button_readiness(selected_action, "artifact")
		impact = _town_action_button_impact(selected_action, "artifact")
		next_step = _town_action_button_next_step(
			selected_action,
			"artifact",
			label,
			_town_action_surface_label("artifact"),
			readiness
		)
	elif owned_count > 0:
		next_step = "Review the loadout or leave when town orders are set."

	var collection_line := "%d owned" % owned_count
	if total_known > 0:
		collection_line = "%d/%d owned" % [owned_count, total_known]
	var tooltip_lines := [
		"Gear Readiness",
		"- Loadout: %d equipped, %d empty slot%s, %d in pack" % [
			equipped_count,
			empty_slot_count,
			"" if empty_slot_count == 1 else "s",
			inventory.size(),
		],
		"- Collection: %s" % collection_line,
		"- Gear orders: %d ready, %d blocked, %d listed" % [
			ready_orders,
			blocked_orders,
			actions.size(),
		],
		"- %s" % state_line,
		"- Best order: %s" % label,
		"- Readiness: %s" % readiness,
		"- Why it matters: %s" % impact,
		"- Next practical action: %s" % next_step,
	]
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"equipped_count": equipped_count,
		"empty_slot_count": empty_slot_count,
		"pack_count": inventory.size(),
		"owned_count": owned_count,
		"known_count": total_known,
		"ready_order_count": ready_orders,
		"blocked_order_count": blocked_orders,
		"listed_order_count": actions.size(),
		"best_order_label": label,
		"readiness": readiness,
		"why_it_matters": impact,
		"next_step": next_step,
	}

func _record_town_action_result(
	lane: String,
	action_id: String,
	action: Dictionary,
	result: Dictionary,
	before: Dictionary
) -> void:
	_last_message = String(result.get("message", ""))
	_last_action_recap = TownRules.build_town_action_recap(_session, lane, action_id, action, result, before)
	if bool(_last_action_recap.get("active", false)):
		_session.flags["last_town_action_recap"] = _last_action_recap.duplicate(true)

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

func _town_action_context_surface(dispatch_text: String = "") -> Dictionary:
	if _last_action_recap.is_empty():
		return {}
	var latest_action := String(_last_action_recap.get("happened", "")).strip_edges()
	if latest_action == "":
		latest_action = String(_last_action_recap.get("message", "")).strip_edges()
	if latest_action == "":
		latest_action = _last_message.strip_edges()
	if latest_action == "":
		return {}
	var departure := TownRules.town_departure_confirmation(_session)
	var next_step := String(_last_action_recap.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = String(departure.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = "Review the next town order or leave to the field."
	var handoff_check := _town_action_handoff_check(next_step, departure)
	var visible := "Latest: %s" % _short_text(_strip_sentence(latest_action), 42)
	visible = "%s | Next: %s" % [
		visible,
		_short_text(_strip_sentence(next_step).trim_suffix("."), 36),
	]
	var save_surface := AppRouter.active_save_surface()
	var save_lines := []
	var save_check := String(save_surface.get("save_check", "")).strip_edges()
	var save_recap := String(save_surface.get("current_save_recap", "")).strip_edges()
	if save_check != "":
		save_lines.append(save_check)
	if save_recap != "":
		save_lines.append("Saving now recap:\n%s" % save_recap)
	var tooltip := _join_tooltip_sections([
		"Town Turn Context\n- Latest action: %s\n- Next practical step: %s\n- Handoff check: %s\n- Town status: %s" % [
			latest_action,
			next_step,
			handoff_check,
			TownRules.describe_status(_session),
		],
		String(_last_action_recap.get("tooltip_text", "")),
		String(departure.get("tooltip_text", "")),
		"\n".join(save_lines),
		dispatch_text,
	])
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"latest_action": latest_action,
		"next_step": next_step,
		"handoff_check": handoff_check,
		"source": "town_action_recap",
	}

func _prepare_town_return_handoff() -> Dictionary:
	var town := TownRules.get_active_town(_session)
	if town.is_empty():
		return {}
	var town_name := _town_display_name(town)
	var hero_pos := OverworldRules.hero_position(_session)
	var movement = _session.overworld.get("movement", {})
	var move_current := int(movement.get("current", 0))
	var move_max := int(movement.get("max", move_current))
	var movement_line := "Move %d/%d" % [move_current, move_max]
	var field_position := "%d,%d" % [hero_pos.x, hero_pos.y]
	var departure := TownRules.town_departure_confirmation(_session)
	var next_step := String(departure.get("next_step", "")).strip_edges()
	if next_step == "":
		next_step = "Select the next destination or end the turn when field orders are spent."
	var visible := "Town return: %s | %s" % [_short_text(town_name, 24), movement_line]
	var tooltip := "Town Return Handoff\n- Returned: Leave closed %s and reopened the overworld.\n- Field position: active hero remains at %s.\n- Movement: %s remains for field orders.\n- Day: Day %d did not advance.\n- Next practical action: %s" % [
		town_name,
		field_position,
		movement_line,
		_session.day,
		next_step,
	]
	var recap := {
		"happened": "Left %s for the field." % town_name,
		"affected": "%s at %s | %s" % [town_name, field_position, movement_line],
		"why_it_matters": "Leaving town returns to overworld control without advancing the day or spending field movement.",
		"next_step": next_step,
		"cue_text": visible,
		"tooltip_text": tooltip,
		"text": "After town: %s Next: %s" % [visible, next_step],
	}
	var handoff := {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"town_name": town_name,
		"town_placement_id": String(town.get("placement_id", "")),
		"field_position": field_position,
		"movement_line": movement_line,
		"day": _session.day,
		"next_step": next_step,
		"post_action_recap": recap,
	}
	_session.flags["town_return_handoff"] = handoff.duplicate(true)
	_session.flags["last_action"] = "left_town"
	return handoff

func _town_display_name(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("name", town.get("placement_id", "Town")))

func _town_action_handoff_check(next_step: String, departure: Dictionary = {}) -> String:
	var cleaned_next := _strip_sentence(next_step).trim_suffix(".")
	if cleaned_next == "":
		cleaned_next = "review the next town order"
	var departure_text := _strip_sentence(String(departure.get("visible_text", ""))).trim_suffix(".")
	if departure_text != "":
		return "%s; %s." % [cleaned_next.capitalize(), departure_text]
	return "%s before leaving, saving, or returning to the menu." % cleaned_next.capitalize()

func _strip_sentence(text: String) -> String:
	var cleaned := text.strip_edges().replace("\n", " ")
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	return cleaned

func _short_text(text: String, max_chars: int) -> String:
	var cleaned := _strip_sentence(text)
	if max_chars <= 0 or cleaned.length() <= max_chars:
		return cleaned
	return "%s..." % cleaned.left(max(0, max_chars - 3)).strip_edges()

func _join_tooltip_sections(sections: Array) -> String:
	var lines := []
	for section in sections:
		var text := String(section).strip_edges()
		if text != "":
			lines.append(text)
	return "\n".join(lines)

func _refresh_management_tab_cues() -> void:
	var payload := _management_tab_readiness_payload()
	var tabs: Array = payload.get("tabs", [])
	for index in range(min(_management_tabs.get_tab_count(), tabs.size())):
		var tab: Dictionary = tabs[index]
		_management_tabs.set_tab_title(index, String(tab.get("title", "")))
	_management_tabs.tooltip_text = String(payload.get("tooltip_text", ""))

func _management_tab_readiness_payload() -> Dictionary:
	var tabs := [
		_tab_readiness_entry("Build", TownRules.get_build_actions(_session)),
		_tab_readiness_entry("Muster", TownRules.get_recruit_actions(_session)),
		_tab_readiness_entry("Spells", TownRules.get_spell_learning_actions(_session)),
		_tab_readiness_entry("Trade", TownRules.get_market_actions(_session)),
		_tab_readiness_entry("Log", _logistics_tab_actions()),
	]
	var selected_index := clampi(_management_tabs.current_tab, 0, max(0, tabs.size() - 1))
	var selected: Dictionary = tabs[selected_index] if selected_index < tabs.size() else {}
	var tooltip_lines := ["Town command tabs:"]
	for tab in tabs:
		tooltip_lines.append("- %s" % String(tab.get("summary", "")))
	if not selected.is_empty():
		tooltip_lines.append("Selected: %s" % String(selected.get("focus", "")))
	return {
		"tabs": tabs,
		"selected_tab": selected.duplicate(true),
		"tooltip_text": "\n".join(tooltip_lines),
	}

func _tab_readiness_entry(base_title: String, actions: Variant) -> Dictionary:
	var total := 0
	var ready := 0
	if actions is Array:
		for action in actions:
			if not (action is Dictionary):
				continue
			total += 1
			if not bool(action.get("disabled", false)):
				ready += 1
	var title := base_title
	if ready > 0:
		title = "%s %d" % [base_title, ready]
	var summary := "%s: %d ready of %d orders" % [base_title, ready, total]
	var focus := "%s has %d ready order%s." % [
		base_title,
		ready,
		"" if ready == 1 else "s",
	]
	if ready <= 0 and total > 0:
		focus = "%s has %d blocked or spent order%s." % [
			base_title,
			total,
			"" if total == 1 else "s",
		]
	elif total <= 0:
		focus = "%s has no listed orders." % base_title
	return {
		"base_title": base_title,
		"title": title,
		"ready_count": ready,
		"total_count": total,
		"summary": summary,
		"focus": focus,
	}

func _logistics_tab_actions() -> Array:
	var actions := []
	actions.append_array(TownRules.get_tavern_actions(_session))
	actions.append_array(TownRules.get_transfer_actions(_session))
	actions.append_array(TownRules.get_response_actions(_session))
	actions.append_array(TownRules.get_artifact_actions(_session))
	return actions

func _management_tab_titles() -> Array:
	var titles := []
	for index in range(_management_tabs.get_tab_count()):
		titles.append(_management_tabs.get_tab_title(index))
	return titles

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
