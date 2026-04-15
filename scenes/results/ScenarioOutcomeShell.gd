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
@onready var _hero_label: Label = %Hero
@onready var _army_label: Label = %Army
@onready var _resource_label: Label = %Resources
@onready var _progression_label: Label = %Progression
@onready var _campaign_arc_label: Label = %CampaignArc
@onready var _carryover_label: Label = %Carryover
@onready var _aftermath_label: Label = %Aftermath
@onready var _journal_label: Label = %Journal
@onready var _save_status_label: Label = %SaveStatus
@onready var _save_slot_picker: OptionButton = %SaveSlot
@onready var _save_button: Button = %Save
@onready var _menu_button: Button = %Menu
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
	_set_compact_label(_action_status_label, _last_action_message if _last_action_message != "" else "Review the outcome, then choose the next step.", 3)
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
	_set_compact_label(_save_status_label, String(surface.get("latest_context", "Latest ready save: none.")), 3)
	_save_slot_picker.tooltip_text = SaveService.describe_slot_details(summary)
	_save_button.text = String(surface.get("save_button_label", "Save Outcome"))
	_save_button.tooltip_text = String(surface.get("save_button_tooltip", "Save the current outcome safely."))
	_menu_button.text = String(surface.get("menu_button_label", "Return to Menu"))
	_menu_button.tooltip_text = String(surface.get("menu_button_tooltip", "Return to the main menu after updating autosave."))

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
		button.tooltip_text = String(action.get("summary", ""))
		FrontierVisualKit.apply_button(button, "primary", 172.0, 36.0)
		button.pressed.connect(_on_action_pressed.bind(String(action.get("id", ""))))
		_actions_bar.add_child(button)

func _on_action_pressed(action_id: String) -> void:
	var result := ScenarioRules.perform_outcome_action(_session, action_id)
	_last_action_message = String(result.get("message", ""))
	match String(result.get("route", "stay")):
		"overworld":
			AppRouter.go_to_overworld()
		"main_menu":
			AppRouter.return_to_main_menu_from_active_play()
		_:
			_refresh()

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

	FrontierVisualKit.apply_option_button(_save_slot_picker, "secondary", 180.0, 36.0)
	FrontierVisualKit.apply_button(_save_button, "primary", 150.0, 36.0)
	FrontierVisualKit.apply_button(_menu_button, "secondary", 170.0, 36.0)

	for label in find_children("*", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "body")

	for label_name in ["HeroTitle", "ArmyTitle", "ResourceTitle", "ProgressionTitle", "AftermathTitle", "CampaignArcTitle", "CarryoverTitle", "JournalTitle", "SaveTitle", "ActionsTitle"]:
		for title_label in find_children(label_name, "Label", true, false):
			if title_label is Label:
				FrontierVisualKit.apply_label(title_label, "title")
	FrontierVisualKit.apply_label(_header_label, "title", 26)
	FrontierVisualKit.apply_label(_save_status_label, "muted")
