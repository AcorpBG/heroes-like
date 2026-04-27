extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")

@onready var _backdrop: ColorRect = %Backdrop
@onready var _header_label: Label = %Header
@onready var _summary_label: Label = %Summary
@onready var _mode_label: Label = %Mode
@onready var _result_glyph: Control = %ResultGlyph
@onready var _result_badge_label: Label = %ResultBadge
@onready var _result_badge_panel: PanelContainer = %ResultBadgePanel
@onready var _outcome_banner: Control = %OutcomeBanner
@onready var _recap_tabs: TabContainer = %RecapTabs
@onready var _hero_label: Label = %Hero
@onready var _army_label: Label = %Army
@onready var _resource_label: Label = %Resources
@onready var _progression_label: Label = %Progression
@onready var _campaign_arc_label: Label = %CampaignArc
@onready var _carryover_label: Label = %Carryover
@onready var _aftermath_label: Label = %Aftermath
@onready var _journal_label: Label = %Journal
@onready var _actions_hint_label: Label = %ActionsHint
@onready var _save_status_label: Label = %SaveStatus
@onready var _return_cue_label: Label = %ReturnCue
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _menu_button: Button = %Menu
@onready var _guide_button: Button = %Guide
@onready var _guide_panel: PanelContainer = %GuidePanel
@onready var _guide_label: Label = %OutcomeGuide
@onready var _action_status_label: Label = %ActionStatus
@onready var _actions_bar: HFlowContainer = %Actions

var _session: SessionStateStore.SessionData
var _model: Dictionary = {}
var _last_action_message := ""

func _ready() -> void:
	_apply_visual_theme()
	_session = SessionState.ensure_active_session()
	if _session.scenario_id == "":
		AppRouter.go_to_main_menu()
		return
	if _session.scenario_status == "in_progress":
		AppRouter.resume_active_session()
		return
	_configure_save_slot_picker()
	_refresh()

func _refresh() -> void:
	_model = ScenarioRules.build_outcome_model(_session)
	var status := String(_session.scenario_status)
	_apply_result_palette(status)
	_header_label.text = String(_model.get("header", "Scenario Outcome"))
	_set_compact_label(_summary_label, String(_model.get("summary", "Scenario resolution recorded.")), 4)
	_mode_label.text = String(_model.get("mode_summary", ""))
	_result_badge_label.text = _result_status_label(status)
	if _outcome_banner.has_method("set_outcome"):
		_outcome_banner.call("set_outcome", status)
	_set_compact_label(_hero_label, String(_model.get("hero_summary", "Hero data unavailable.")), 5)
	_set_compact_label(_army_label, String(_model.get("army_summary", "Army data unavailable.")), 5)
	_set_compact_label(_resource_label, String(_model.get("resource_summary", "Resource data unavailable.")), 5)
	_set_compact_label(_progression_label, String(_model.get("progression_summary", "")), 4)
	_set_compact_label(_campaign_arc_label, String(_model.get("campaign_arc_summary", "")), 4)
	_set_compact_label(_carryover_label, String(_model.get("carryover_summary", "")), 4)
	_set_compact_label(_aftermath_label, String(_model.get("aftermath_summary", "")), 4)
	_set_compact_label(_journal_label, String(_model.get("journal_summary", "")), 4)
	_refresh_save_surface()
	var next_step_summary := String(_model.get("next_step_summary", ""))
	var next_play_action_summary := String(_model.get("next_play_action_summary", ""))
	var continuity_choice_summary := String(_model.get("continuity_choice_summary", ""))
	var post_result_handoff := String(_model.get("post_result_handoff_summary", ""))
	var action_cue_summary := String(_model.get("action_cue_summary", ""))
	var follow_up_check := _outcome_follow_up_check(AppRouter.active_save_surface())
	var follow_up_visible := String(follow_up_check.get("visible_text", ""))
	var follow_up_tooltip := String(follow_up_check.get("tooltip_text", ""))
	var resolution_handoff := _outcome_resolution_handoff_text()
	var action_status_lines := []
	if next_step_summary != "":
		action_status_lines.append(next_step_summary)
	if follow_up_visible != "":
		action_status_lines.append(follow_up_visible)
	if resolution_handoff != "":
		action_status_lines.append(resolution_handoff)
	if post_result_handoff != "":
		action_status_lines.append(post_result_handoff)
	if continuity_choice_summary != "":
		action_status_lines.append(continuity_choice_summary)
	if next_play_action_summary != "":
		action_status_lines.append(next_play_action_summary)
	var visible_action_hint := action_cue_summary
	if follow_up_visible != "":
		visible_action_hint = "%s\n%s" % [follow_up_visible, visible_action_hint] if visible_action_hint != "" else follow_up_visible
	if post_result_handoff != "":
		visible_action_hint = "%s\n%s" % [post_result_handoff, action_cue_summary] if action_cue_summary != "" else post_result_handoff
		if follow_up_visible != "":
			visible_action_hint = "%s\n%s" % [follow_up_visible, visible_action_hint]
	var action_status_text := "\n".join(action_status_lines)
	_set_compact_label(
		_action_status_label,
		_last_action_message if _last_action_message != "" else (action_status_text if action_status_text != "" else "Review the outcome, then choose the next step."),
		3
	)
	_set_compact_label(
		_actions_hint_label,
		visible_action_hint if visible_action_hint != "" else "Action cue: choose the follow-up action that matches the saved outcome you want to keep.",
		3
	)
	_actions_hint_label.tooltip_text = "\n".join(action_status_lines + [follow_up_tooltip, action_cue_summary]).strip_edges()
	_refresh_guide_surface()
	_rebuild_actions()

func _configure_save_slot_picker() -> void:
	_save_slot_picker.clear()
	for slot in SaveService.get_manual_slot_ids():
		_save_slot_picker.add_item("Manual %d" % int(slot), int(slot))
	_refresh_save_surface()

func _refresh_save_surface() -> void:
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
	var current_save_recap := String(surface.get("current_save_recap", ""))
	var current_context := String(surface.get("current_context", ""))
	var save_check := String(surface.get("save_check", "")).strip_edges()
	var play_check := String(surface.get("play_check", "")).strip_edges()
	var return_handoff := String(surface.get("return_handoff", "")).strip_edges()
	var visible_save_text := save_check if save_check != "" else (current_save_recap if current_save_recap != "" else latest_context)
	_set_compact_label(_save_status_label, visible_save_text, 3)
	var return_cue := _outcome_return_cue_text(surface)
	_set_compact_label(_return_cue_label, return_cue, 2, 108)
	var save_tooltip_lines := [latest_context]
	if save_check != "":
		save_tooltip_lines.append(save_check)
	if play_check != "":
		save_tooltip_lines.append(play_check)
	if return_handoff != "":
		save_tooltip_lines.append(return_handoff)
	if current_save_recap != "":
		save_tooltip_lines.append("Saving now recap:\n%s" % current_save_recap)
	if current_context != "":
		save_tooltip_lines.append("Saving now: %s" % current_context)
	var slot_resume_recap := String(surface.get("slot_resume_recap", ""))
	if slot_resume_recap != "":
		save_tooltip_lines.append("Selected slot recap:\n%s" % slot_resume_recap)
	save_tooltip_lines.append("Selected slot:\n%s" % SaveService.describe_slot_details(summary))
	_save_status_label.tooltip_text = "\n".join(save_tooltip_lines)
	_return_cue_label.tooltip_text = _join_tooltip_sections([
		return_cue,
		return_handoff,
		String(surface.get("menu_button_tooltip", "")),
	])
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Outcome"))
	_save_button.tooltip_text = _join_tooltip_sections([
		String(surface.get("save_button_tooltip", "Save the current outcome safely.")),
		save_check,
		return_handoff,
	])
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))
	_refresh_guide_surface()

func _rebuild_actions() -> void:
	for child in _actions_bar.get_children():
		child.queue_free()

	var actions = _model.get("actions", [])
	if not (actions is Array) or actions.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No follow-up actions are available."
		_actions_bar.add_child(placeholder)
		return

	for action in actions:
		if not (action is Dictionary):
			continue
		var button := Button.new()
		button.text = String(action.get("label", action.get("id", "Action")))
		button.disabled = bool(action.get("disabled", false))
		button.tooltip_text = _outcome_action_tooltip(action)
		FrontierVisualKit.apply_button(button, "primary", 172.0, 36.0)
		button.pressed.connect(_on_action_pressed.bind(String(action.get("id", ""))))
		_actions_bar.add_child(button)

func _on_action_pressed(action_id: String) -> void:
	_perform_outcome_action(action_id)

func _perform_outcome_action(action_id: String) -> Dictionary:
	var result := ScenarioRules.perform_outcome_action(_session, action_id)
	_last_action_message = String(result.get("message", ""))
	match String(result.get("route", "stay")):
		"overworld":
			AppRouter.go_to_overworld()
		"main_menu":
			AppRouter.return_to_main_menu_from_active_play()
		_:
			_refresh()
	return result

func _on_save_pressed() -> void:
	var result := AppRouter.save_active_session_to_selected_manual_slot()
	_last_action_message = String(result.get("message", ""))
	_refresh()

func _on_save_slot_selected(index: int) -> void:
	if index < 0 or index >= _save_slot_picker.get_item_count():
		return
	SaveService.set_selected_manual_slot(_save_slot_picker.get_item_id(index))
	_refresh_save_surface()

func _on_menu_pressed() -> void:
	AppRouter.return_to_main_menu_from_active_play()

func _on_guide_pressed() -> void:
	_guide_panel.visible = not _guide_panel.visible
	_refresh_guide_surface()

func validation_snapshot() -> Dictionary:
	var action_ids: Array[String] = []
	var action_payloads := []
	var actions = _model.get("actions", [])
	if actions is Array:
		for action in actions:
			if action is Dictionary:
				action_ids.append(String(action.get("id", "")))
				action_payloads.append(action.duplicate(true))
	var save_surface := AppRouter.active_save_surface()
	return {
		"scene_path": scene_file_path,
		"scenario_id": _session.scenario_id,
		"difficulty": _session.difficulty,
		"launch_mode": _session.launch_mode,
		"scenario_status": _session.scenario_status,
		"scenario_summary": _session.scenario_summary,
		"game_state": _session.game_state,
		"day": _session.day,
		"resume_target": SaveService.resume_target_for_session(_session),
		"header": String(_model.get("header", "")),
		"summary": String(_model.get("summary", "")),
		"mode_summary": String(_model.get("mode_summary", "")),
		"progression_summary": String(_model.get("progression_summary", "")),
		"campaign_arc_summary": String(_model.get("campaign_arc_summary", "")),
		"carryover_summary": String(_model.get("carryover_summary", "")),
		"aftermath_summary": String(_model.get("aftermath_summary", "")),
		"journal_summary": String(_model.get("journal_summary", "")),
		"next_step_summary": String(_model.get("next_step_summary", "")),
		"outcome_resolution_handoff": _outcome_resolution_handoff_text(),
		"continuity_choice_summary": String(_model.get("continuity_choice_summary", "")),
		"post_result_handoff_summary": String(_model.get("post_result_handoff_summary", "")),
		"outcome_follow_up_check": _outcome_follow_up_check(save_surface),
		"next_play_action_summary": String(_model.get("next_play_action_summary", "")),
		"action_cue_summary": String(_model.get("action_cue_summary", "")),
		"actions_hint": _actions_hint_label.text,
		"actions_hint_tooltip": _actions_hint_label.tooltip_text,
		"action_status": _action_status_label.text,
		"action_ids": action_ids,
		"action_tooltips": _outcome_action_tooltip_snapshot(),
		"actions": action_payloads,
		"latest_save_summary": SaveService.latest_loadable_summary(),
		"save_surface": save_surface,
		"save_status": _save_status_label.text,
		"save_status_tooltip": _save_status_label.tooltip_text,
		"save_button_tooltip": _save_button.tooltip_text,
		"menu_button_tooltip": _menu_button.tooltip_text,
		"return_cue": _return_cue_label.text,
		"return_cue_tooltip": _return_cue_label.tooltip_text,
		"outcome_guide_visible": _guide_panel.visible,
		"outcome_guide_button": _guide_button.text,
		"outcome_guide_tooltip": _guide_button.tooltip_text,
		"outcome_guide": _guide_label.text,
		"outcome_guide_full": _guide_label.tooltip_text,
		"save_check": String(save_surface.get("save_check", "")),
		"play_check": String(save_surface.get("play_check", "")),
		"return_handoff": String(save_surface.get("return_handoff", "")),
		"current_save_recap": String(save_surface.get("current_save_recap", "")),
		"slot_resume_recap": String(save_surface.get("slot_resume_recap", "")),
	}

func validation_select_save_slot(slot: int) -> bool:
	var normalized_slot := int(slot)
	if not SaveService.get_manual_slot_ids().has(normalized_slot):
		return false
	SaveService.set_selected_manual_slot(normalized_slot)
	_refresh_save_surface()
	return SaveService.get_selected_manual_slot() == normalized_slot

func validation_save_to_selected_slot() -> Dictionary:
	var selected_slot := SaveService.get_selected_manual_slot()
	_on_save_pressed()
	var summary := SaveService.inspect_manual_slot(selected_slot)
	return {
		"ok": SaveService.can_load_summary(summary),
		"selected_slot": selected_slot,
		"summary": summary,
		"message": _last_action_message,
	}

func validation_perform_action(action_id: String) -> Dictionary:
	var expected_route := "stay"
	var found := false
	var actions = _model.get("actions", [])
	if actions is Array:
		for action in actions:
			if action is Dictionary and String(action.get("id", "")) == action_id:
				found = true
				if bool(action.get("disabled", false)):
					return {"ok": false, "action_id": action_id, "message": "Outcome action is disabled."}
				if action_id == "return_to_menu":
					expected_route = "main_menu"
				elif action_id.begins_with("campaign_start:") or action_id.begins_with("skirmish_start:"):
					expected_route = "overworld"
				break
	if not found:
		return {"ok": false, "action_id": action_id, "message": "Outcome action is not available."}
	var source_scenario_id := _session.scenario_id
	var source_scenario_status := _session.scenario_status
	var result := _perform_outcome_action(action_id)
	var active_session := SessionState.ensure_active_session()
	var result_route := String(result.get("route", "stay"))
	return {
		"ok": bool(result.get("ok", false)) and result_route == expected_route,
		"action_id": action_id,
		"expected_route": expected_route,
		"route": result_route,
		"action_result": result.duplicate(true),
		"source_scenario_id": source_scenario_id,
		"source_scenario_status": source_scenario_status,
		"active_scenario_id": active_session.scenario_id,
		"active_scenario_status": active_session.scenario_status,
		"active_game_state": active_session.game_state,
		"active_resume_target": SaveService.resume_target_for_session(active_session),
		"active_battle_empty": active_session.battle.is_empty(),
		"message": _last_action_message,
	}

func validation_return_to_menu() -> Dictionary:
	_on_menu_pressed()
	return {
		"ok": true,
		"scenario_id": _session.scenario_id,
		"scenario_status": _session.scenario_status,
		"message": "Outcome route returned to the main menu.",
	}

func validation_open_outcome_guide() -> void:
	if not _guide_panel.visible:
		_on_guide_pressed()

func validation_close_outcome_guide() -> void:
	if _guide_panel.visible:
		_on_guide_pressed()

func _result_status_label(status: String) -> String:
	var normalized := status.replace("_", " ").strip_edges()
	if normalized == "":
		return "OUTCOME"
	return normalized.to_upper()

func _apply_result_palette(status: String) -> void:
	var backdrop_color := Color(0.07, 0.08, 0.10, 1.0)
	var accent := Color(0.84, 0.74, 0.47, 1.0)
	match status:
		"victory":
			backdrop_color = Color(0.05, 0.09, 0.10, 1.0)
			accent = Color(0.87, 0.74, 0.38, 1.0)
		"defeat":
			backdrop_color = Color(0.11, 0.05, 0.07, 1.0)
			accent = Color(0.88, 0.48, 0.35, 1.0)
		_:
			backdrop_color = Color(0.08, 0.08, 0.11, 1.0)
			accent = Color(0.80, 0.74, 0.52, 1.0)

	_backdrop.color = backdrop_color
	_header_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90, 1.0))
	FrontierVisualKit.apply_label(_summary_label, "body", 14)
	_mode_label.add_theme_color_override("font_color", accent.lightened(0.08))
	_action_status_label.add_theme_color_override("font_color", accent)
	_result_badge_label.add_theme_color_override("font_color", accent)
	if _result_glyph.has_method("set_glyph"):
		_result_glyph.call("set_glyph", "outcome", accent)

	var badge_style := FrontierVisualKit.badge_style("gold")
	badge_style.bg_color = Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.95)
	badge_style.border_color = accent
	_result_badge_panel.add_theme_stylebox_override("panel", badge_style)

func _set_compact_label(label: Label, full_text: String, max_lines: int, max_chars: int = 96) -> void:
	FrontierVisualKit.set_compact_label(label, full_text, max_lines, max_chars)

func _join_tooltip_sections(sections: Array) -> String:
	var lines := []
	for section in sections:
		var text := String(section).strip_edges()
		if text != "":
			lines.append(text)
	return "\n".join(lines)

func _outcome_return_cue_text(surface: Dictionary) -> String:
	var return_handoff := String(surface.get("return_handoff", "")).strip_edges()
	if return_handoff.find("Editor restores") >= 0:
		return "Return cue: Editor restores the Play Copy launch snapshot."
	if SaveService.resume_target_for_session(_session) == "outcome":
		return "Return cue: Menu autosaves this outcome; Continue Latest reviews it later."
	if return_handoff != "":
		return return_handoff.replace("Return handoff:", "Return cue:")
	return "Return cue: Menu refreshes autosave before opening the main menu."

func _outcome_resolution_handoff_text() -> String:
	var status_text := String(_session.scenario_status).replace("_", " ").strip_edges()
	if status_text == "":
		status_text = "outcome"
	var primary_label := _primary_outcome_action_label()
	var launch_mode := SessionStateStore.normalize_launch_mode(_session.launch_mode)
	if launch_mode == SessionStateStore.LAUNCH_MODE_CAMPAIGN:
		if primary_label != "" and primary_label != "Return to Menu":
			return "Outcome handoff: %s recorded; %s is the primary follow-up for this result path, while Return to Menu keeps outcome review resumable." % [
				status_text.capitalize(),
				primary_label,
			]
		return "Outcome handoff: %s recorded; Return to Menu keeps this campaign result available from Continue Latest." % status_text.capitalize()
	if primary_label != "" and primary_label != "Return to Menu":
		return "Outcome handoff: %s recorded; %s is the primary follow-up and starts fresh, while Return to Menu keeps this outcome resumable." % [
			status_text.capitalize(),
			primary_label,
		]
	return "Outcome handoff: %s recorded; Return to Menu keeps this outcome resumable from Continue Latest." % status_text.capitalize()

func _outcome_follow_up_check(surface: Dictionary = {}) -> Dictionary:
	var status_text := String(_session.scenario_status).replace("_", " ").strip_edges()
	if status_text == "":
		status_text = "outcome"
	var status_label := status_text.capitalize()
	var launch_mode := SessionStateStore.normalize_launch_mode(_session.launch_mode)
	var primary_label := _primary_outcome_action_label()
	var primary_action_id := _primary_outcome_action_id()
	if primary_label == "":
		primary_label = "Return to Menu"
	var save_label := String(surface.get("save_button_label", "Save Outcome")).strip_edges()
	if save_label == "":
		save_label = "Save Outcome"
	var return_line := _outcome_return_cue_text(surface)
	var primary_effect := _outcome_primary_follow_up_effect(primary_action_id, primary_label, launch_mode)
	var save_effect := "%s keeps this review available from the selected manual slot." % save_label
	var return_effect := "Return to Menu keeps Continue Latest pointed at this outcome review."
	if return_line != "":
		return_effect = return_line.replace("Return cue:", "").strip_edges()
	var visible := "Follow-up check: %s | %s | Return keeps review" % [
		primary_label,
		"save first" if primary_action_id != "return_to_menu" else "menu route",
	]
	var tooltip := "Outcome Follow-up Check\n- Result: %s recorded.\n- Primary follow-up: %s.\n- Save first: %s\n- Return: %s\n- State change: pressing a follow-up starts fresh play or routes to the menu; it does not rewrite the resolved result.\n- Inspection: reading this check does not save, route, or change campaign progression." % [
		status_label,
		primary_effect,
		save_effect,
		return_effect,
	]
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"primary_label": primary_label,
		"primary_action_id": primary_action_id,
		"save_label": save_label,
		"return_effect": return_effect,
	}

func _primary_outcome_action_label() -> String:
	var actions = _model.get("actions", [])
	if not (actions is Array):
		return ""
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			var action_id := String(action.get("id", ""))
			if action_id != "" and action_id != "return_to_menu":
				return String(action.get("label", action_id)).strip_edges()
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			var label := String(action.get("label", action.get("id", ""))).strip_edges()
			if label != "":
				return label
	return ""

func _primary_outcome_action_id() -> String:
	var actions = _model.get("actions", [])
	if not (actions is Array):
		return ""
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			var action_id := String(action.get("id", ""))
			if action_id != "" and action_id != "return_to_menu":
				return action_id
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return String(action.get("id", ""))
	return ""

func _outcome_primary_follow_up_effect(action_id: String, label: String, launch_mode: String) -> String:
	if action_id.begins_with("campaign_start:"):
		if launch_mode == SessionStateStore.LAUNCH_MODE_CAMPAIGN:
			return "%s starts a fresh campaign chapter from recorded campaign progress" % label
		return "%s starts a fresh campaign expedition" % label
	if action_id.begins_with("skirmish_start:"):
		return "%s starts a fresh skirmish expedition" % label
	if action_id == "" or action_id == "return_to_menu":
		return "%s opens the menu and keeps the outcome review resumable" % label
	return "%s follows the resolved outcome action" % label

func _outcome_action_tooltip(action: Dictionary) -> String:
	var follow_up_check := _outcome_follow_up_check(AppRouter.active_save_surface())
	return _join_tooltip_sections([
		String(action.get("summary", "")),
		String(follow_up_check.get("tooltip_text", "")),
		_outcome_resolution_handoff_text(),
		String(_model.get("post_result_handoff_summary", "")),
	])

func _outcome_action_tooltip_snapshot() -> Array:
	var tooltips := []
	for child in _actions_bar.get_children():
		if child is Button:
			tooltips.append({
				"label": String((child as Button).text),
				"tooltip": String((child as Button).tooltip_text),
			})
	return tooltips

func _apply_visual_theme() -> void:
	var panel_tones := {
		"Banner": "banner",
		"BannerArtPanel": "earth",
		"ActionStatusPanel": "earth",
		"HeroPanel": "teal",
		"ArmyPanel": "earth",
		"ResourcePanel": "gold",
		"ProgressionPanel": "ink",
		"AftermathPanel": "earth",
		"CampaignArcPanel": "ink",
		"CarryoverPanel": "teal",
		"JournalPanel": "ink",
		"SavePanel": "ink",
		"ActionsPanel": "gold",
	}
	for panel in find_children("*", "PanelContainer", true, false):
		if panel is PanelContainer:
			FrontierVisualKit.apply_panel(panel, String(panel_tones.get(panel.name, "ink")))

	FrontierVisualKit.apply_tab_container(_recap_tabs)
	_recap_tabs.set_tab_title(0, "Progress")
	_recap_tabs.set_tab_title(1, "Arc")
	_recap_tabs.set_tab_title(2, "Carry")
	_recap_tabs.set_tab_title(3, "After")
	_recap_tabs.set_tab_title(4, "Journal")

	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 132.0, 34.0, 13)
	FrontierVisualKit.apply_button(_save_button, "primary", 126.0, 34.0, 13)
	FrontierVisualKit.apply_button(_menu_button, "secondary", 138.0, 34.0, 13)
	FrontierVisualKit.apply_button(_guide_button, "secondary", 96.0, 34.0, 13)

	for label in find_children("*", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "body")

	for label_name in ["HeroTitle", "ArmyTitle", "ResourceTitle", "ProgressionTitle", "AftermathTitle", "CampaignArcTitle", "CarryoverTitle", "JournalTitle", "SaveTitle", "ActionsTitle", "GuideTitle"]:
		for title_label in find_children(label_name, "Label", true, false):
			if title_label is Label:
				FrontierVisualKit.apply_label(title_label, "title", 14)
	FrontierVisualKit.apply_label(_header_label, "title", 24)
	FrontierVisualKit.apply_label(_save_status_label, "muted", 12)
	FrontierVisualKit.apply_label(_return_cue_label, "muted", 12)

func _refresh_guide_surface() -> void:
	if _guide_button == null or _guide_label == null or _guide_panel == null:
		return
	_guide_button.text = "Hide Guide" if _guide_panel.visible else "Guide"
	_guide_button.tooltip_text = (
		"Hide the outcome Field Manual without saving, loading, routing, or changing campaign progression."
		if _guide_panel.visible
		else "Open the outcome Field Manual. This does not save, load, route, or change campaign progression."
	)
	var guide_text := _build_outcome_guide_text()
	_set_compact_label(_guide_label, guide_text, 8, 92)

func _build_outcome_guide_text() -> String:
	var lines := [SettingsService.describe_help_topic("outcome")]
	var continuity_choice := String(_model.get("continuity_choice_summary", "")).strip_edges()
	var next_play_action := String(_model.get("next_play_action_summary", "")).strip_edges()
	var action_cue := String(_model.get("action_cue_summary", "")).strip_edges()
	var post_result_handoff := String(_model.get("post_result_handoff_summary", "")).strip_edges()
	var resolution_handoff := _outcome_resolution_handoff_text()
	var save_surface := AppRouter.active_save_surface()
	var follow_up_check := _outcome_follow_up_check(save_surface)
	var save_check := String(save_surface.get("save_check", "")).strip_edges()
	var play_check := String(save_surface.get("play_check", "")).strip_edges()
	var return_handoff := String(save_surface.get("return_handoff", "")).strip_edges()
	if continuity_choice != "":
		lines.append(continuity_choice)
	if next_play_action != "":
		lines.append(next_play_action)
	if String(follow_up_check.get("tooltip_text", "")).strip_edges() != "":
		lines.append(String(follow_up_check.get("tooltip_text", "")).strip_edges())
	if resolution_handoff != "":
		lines.append(resolution_handoff)
	if post_result_handoff != "":
		lines.append(post_result_handoff)
	if action_cue != "":
		lines.append(action_cue)
	if save_check != "":
		lines.append(save_check)
	if play_check != "":
		lines.append(play_check)
	if return_handoff != "":
		lines.append(return_handoff)
	lines.append("Guide handoff: this panel is informational; close it to keep choosing from the same outcome actions.")
	return "\n".join(lines)
