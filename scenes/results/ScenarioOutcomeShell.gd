extends Control

@onready var _header_label: Label = $VBox/Header
@onready var _summary_label: Label = $VBox/Summary
@onready var _mode_label: Label = $VBox/Mode
@onready var _hero_label: Label = $VBox/ForceSplit/Hero
@onready var _army_label: Label = $VBox/ForceSplit/Army
@onready var _resource_label: Label = $VBox/ForceSplit/Resources
@onready var _progression_label: Label = $VBox/Progression
@onready var _campaign_arc_label: Label = $VBox/CampaignArc
@onready var _carryover_label: Label = $VBox/Carryover
@onready var _aftermath_label: Label = $VBox/Aftermath
@onready var _journal_label: Label = $VBox/Journal
@onready var _save_status_label: Label = $VBox/SaveStatus
@onready var _save_slot_picker: OptionButton = $VBox/SaveBar/SaveSlot
@onready var _save_button: Button = $VBox/SaveBar/Save
@onready var _menu_button: Button = $VBox/SaveBar/Menu
@onready var _action_status_label: Label = $VBox/ActionStatus
@onready var _actions_bar: HBoxContainer = $VBox/Actions

var _session: SessionStateStore.SessionData
var _model: Dictionary = {}
var _last_action_message := ""

func _ready() -> void:
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
	_header_label.text = String(_model.get("header", "Scenario Outcome"))
	_summary_label.text = String(_model.get("summary", "Scenario resolution recorded."))
	_mode_label.text = String(_model.get("mode_summary", ""))
	_hero_label.text = String(_model.get("hero_summary", "Hero data unavailable."))
	_army_label.text = String(_model.get("army_summary", "Army data unavailable."))
	_resource_label.text = String(_model.get("resource_summary", "Resource data unavailable."))
	_progression_label.text = String(_model.get("progression_summary", ""))
	_campaign_arc_label.text = String(_model.get("campaign_arc_summary", ""))
	_carryover_label.text = String(_model.get("carryover_summary", ""))
	_aftermath_label.text = String(_model.get("aftermath_summary", ""))
	_journal_label.text = String(_model.get("journal_summary", ""))
	_refresh_save_surface()
	_action_status_label.text = _last_action_message if _last_action_message != "" else "Review the outcome, then choose the next step."
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
	var summary := surface.get("slot_summary", SaveService.inspect_manual_slot(selected_slot))
	_save_status_label.text = String(surface.get("latest_context", "Latest ready save: none."))
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
