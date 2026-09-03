extends Control

const FrontierVisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
const COMPACT_WIDTH := 1040.0
const VICTORY_BACKDROP_PATH := "res://art/results/runtime/backdrops/outcome_victory.png"
const DEFEAT_BACKDROP_PATH := "res://art/results/runtime/backdrops/outcome_defeat.png"

@onready var _backdrop_art: TextureRect = %BackdropArt
@onready var _header_panel: PanelContainer = %HeaderPanel
@onready var _outcome_label: Label = %Outcome
@onready var _battle_name_label: Label = %BattleName
@onready var _meta_label: Label = %Meta
@onready var _summary_label: Label = %Summary
@onready var _casualty_scroll: ScrollContainer = %CasualtyScroll
@onready var _casualty_grid: GridContainer = %CasualtyGrid
@onready var _player_panel: PanelContainer = %PlayerPanel
@onready var _enemy_panel: PanelContainer = %EnemyPanel
@onready var _player_title: Label = %PlayerTitle
@onready var _enemy_title: Label = %EnemyTitle
@onready var _player_totals: Label = %PlayerTotals
@onready var _enemy_totals: Label = %EnemyTotals
@onready var _player_rows: VBoxContainer = %PlayerRows
@onready var _enemy_rows: VBoxContainer = %EnemyRows
@onready var _aftermath_panel: PanelContainer = %AftermathPanel
@onready var _aftermath_label: Label = %Aftermath
@onready var _status_label: Label = %Status
@onready var _continue_button: Button = %Continue

var _session
var _report: Dictionary = {}
var _compact_layout := false
var _continue_in_progress := false
var _last_continue_result: Dictionary = {}
var _validation_layout_width_override := 0.0


func _ready() -> void:
	_apply_visual_theme()
	resized.connect(_apply_responsive_layout)
	_session = SessionState.ensure_active_session()
	_report = BattleRules.pending_battle_report(_session)
	if _report.is_empty():
		_route_missing_report()
		return
	_refresh()
	_apply_responsive_layout()
	call_deferred("_focus_continue")


func _route_missing_report() -> void:
	if _session != null and _session.scenario_status != "in_progress":
		AppRouter.go_to_scenario_outcome(true)
	else:
		AppRouter.go_to_overworld()


func _refresh() -> void:
	var outcome := String(_report.get("outcome", "resolved")).replace("_", " ").capitalize()
	var backdrop_path := VICTORY_BACKDROP_PATH if String(_report.get("outcome", "")) in ["victory", "enemy_retreat", "enemy_surrender"] else DEFEAT_BACKDROP_PATH
	if ResourceLoader.exists(backdrop_path, "Texture2D"):
		_backdrop_art.texture = load(backdrop_path) as Texture2D
	_outcome_label.text = outcome
	_outcome_label.accessibility_name = "Battle outcome: %s" % outcome
	_battle_name_label.text = String(_report.get("battle_name", "Battle Report"))
	_battle_name_label.tooltip_text = _battle_name_label.text
	var terrain := String(_report.get("terrain", "")).replace("_", " ").capitalize()
	var meta_parts := ["Day %d" % int(_report.get("day", 1)), "%d round%s" % [int(_report.get("rounds", 1)), "" if int(_report.get("rounds", 1)) == 1 else "s"]]
	if terrain != "":
		meta_parts.append(terrain)
	_meta_label.text = "  •  ".join(meta_parts)
	_summary_label.text = String(_report.get("summary", "The battle is resolved."))
	_summary_label.tooltip_text = _summary_label.text
	var casualties: Dictionary = _report.get("casualties", {}) if _report.get("casualties", {}) is Dictionary else {}
	_populate_side(
		casualties.get("player", {}) if casualties.get("player", {}) is Dictionary else {},
		_player_title,
		_player_totals,
		_player_rows,
		"Your forces"
	)
	_populate_side(
		casualties.get("enemy", {}) if casualties.get("enemy", {}) is Dictionary else {},
		_enemy_title,
		_enemy_totals,
		_enemy_rows,
		"Enemy forces"
	)
	var aftermath_lines: Array[String] = []
	for key in [
		"result_summary",
		"reward_summary",
		"artifact_summary",
		"force_summary",
		"world_summary",
	]:
		var text := String(_report.get(key, "")).strip_edges()
		_append_distinct_aftermath_line(aftermath_lines, text)
	if aftermath_lines.is_empty():
		aftermath_lines.append("No additional rewards or field consequences were recorded.")
	_aftermath_label.text = "\n".join(aftermath_lines)
	_aftermath_label.tooltip_text = _aftermath_label.text
	var entry_snapshot := AppRouter.validation_battle_report_snapshot()
	var entry_result: Dictionary = entry_snapshot.get("last_entry_result", {}) if entry_snapshot.get("last_entry_result", {}) is Dictionary else {}
	if String(entry_result.get("reason", "")) == "autosave_failed":
		_status_label.text = String(entry_result.get("message", "The report is not saved yet. Continue will retry."))
	else:
		_status_label.text = "Review both casualty ledgers, then continue."
	_continue_button.disabled = false
	_continue_button.text = "Continue"
	_continue_button.tooltip_text = "Acknowledge this report, save the result, and continue to %s." % (
		"Scenario Outcome" if _session.scenario_status != "in_progress" else "the Adventure Map"
	)
	_continue_button.accessibility_name = "Continue from battle report"
	_continue_button.accessibility_description = _continue_button.tooltip_text


func _append_distinct_aftermath_line(lines: Array[String], text: String) -> void:
	if text == "":
		return
	for existing in lines:
		if existing == text or existing.contains(text) or text.contains(existing):
			return
	lines.append(text)


func _populate_side(
	side: Dictionary,
	title: Label,
	totals_label: Label,
	rows_container: VBoxContainer,
	fallback_title: String
) -> void:
	for child in rows_container.get_children():
		child.queue_free()
	var side_label := String(side.get("label", fallback_title)).strip_edges()
	title.text = side_label if side_label != "" else fallback_title
	title.tooltip_text = title.text
	var totals: Dictionary = side.get("totals", {}) if side.get("totals", {}) is Dictionary else {}
	var deployed: int = max(0, int(totals.get("deployed", 0)))
	var surviving: int = max(0, int(totals.get("surviving", 0)))
	var lost: int = max(0, int(totals.get("lost", 0)))
	totals_label.text = "Deployed %d   Survived %d   Lost %d" % [deployed, surviving, lost]
	totals_label.accessibility_name = "%s totals: %d deployed, %d survived, %d lost" % [title.text, deployed, surviving, lost]
	var rows = side.get("rows", [])
	if not (rows is Array) or rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No formed companies"
		FrontierVisualKit.apply_label(empty_label, "muted", 13)
		rows_container.add_child(empty_label)
		return
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		_add_casualty_row(rows_container, row_value)


func _add_casualty_row(container: VBoxContainer, row: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.name = "CasualtyRow"
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = String(row.get("name", row.get("unit_id", "Unknown company")))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.tooltip_text = name_label.text
	FrontierVisualKit.apply_label(name_label, "body", 14)
	line.add_child(name_label)
	var counts := Label.new()
	var starting: int = max(0, int(row.get("starting", 0)))
	var surviving: int = max(0, int(row.get("surviving", 0)))
	var lost: int = max(0, int(row.get("lost", 0)))
	counts.text = "%d → %d   −%d" % [starting, surviving, lost]
	counts.custom_minimum_size.x = 132.0
	counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counts.accessibility_name = "%s: %d started, %d survived, %d lost" % [name_label.text, starting, surviving, lost]
	FrontierVisualKit.apply_label(counts, "red" if lost > 0 else "green", 14)
	line.add_child(counts)
	container.add_child(line)


func _on_continue_pressed() -> void:
	if _continue_in_progress:
		return
	_continue_in_progress = true
	_continue_button.disabled = true
	_continue_button.text = "Saving…"
	_status_label.text = "Saving the acknowledged battle report…"
	_last_continue_result = AppRouter.complete_battle_report()
	if not bool(_last_continue_result.get("ok", false)):
		_continue_in_progress = false
		_continue_button.disabled = false
		_continue_button.text = "Retry Continue"
		_status_label.text = String(_last_continue_result.get("message", "The report could not be saved. Try again."))
		_continue_button.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_focus_continue()


func _focus_continue() -> void:
	if is_instance_valid(_continue_button) and not _continue_button.disabled:
		_continue_button.grab_focus()


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_casualty_grid):
		return
	var layout_width := _validation_layout_width_override if _validation_layout_width_override > 0.0 else size.x
	_compact_layout = layout_width < COMPACT_WIDTH
	_casualty_grid.columns = 1 if _compact_layout else 2
	_meta_label.visible = not _compact_layout
	var card_width: float = max(360.0, layout_width - 56.0) if _compact_layout else max(420.0, (layout_width - 72.0) * 0.5)
	_player_panel.custom_minimum_size.x = card_width
	_enemy_panel.custom_minimum_size.x = card_width


func _apply_visual_theme() -> void:
	FrontierVisualKit.apply_panel(_header_panel, "banner")
	FrontierVisualKit.apply_panel(_player_panel, "teal")
	FrontierVisualKit.apply_panel(_enemy_panel, "red")
	FrontierVisualKit.apply_panel(_aftermath_panel, "earth")
	FrontierVisualKit.apply_button(_continue_button, "primary", 176.0, 42.0, 15)
	for label in find_children("*", "Label", true, false):
		if label is Label:
			FrontierVisualKit.apply_label(label, "body")
	FrontierVisualKit.apply_label(_outcome_label, "gold", 16)
	FrontierVisualKit.apply_label(_battle_name_label, "title", 24)
	FrontierVisualKit.apply_label(_meta_label, "muted", 13)
	FrontierVisualKit.apply_label(_player_title, "title", 18)
	FrontierVisualKit.apply_label(_enemy_title, "title", 18)
	FrontierVisualKit.apply_label(_player_totals, "teal", 14)
	FrontierVisualKit.apply_label(_enemy_totals, "red", 14)
	FrontierVisualKit.apply_label(_status_label, "muted", 12)


func validation_press_continue(skip_required_save: bool = true) -> Dictionary:
	_last_continue_result = AppRouter.complete_battle_report(skip_required_save)
	return _last_continue_result.duplicate(true)


func validation_apply_layout_width(width: float) -> void:
	_validation_layout_width_override = max(0.0, width)
	_apply_responsive_layout()


func validation_snapshot() -> Dictionary:
	var casualties: Dictionary = _report.get("casualties", {}) if _report.get("casualties", {}) is Dictionary else {}
	var player: Dictionary = casualties.get("player", {}) if casualties.get("player", {}) is Dictionary else {}
	var enemy: Dictionary = casualties.get("enemy", {}) if casualties.get("enemy", {}) is Dictionary else {}
	var viewport_rect := get_global_rect()
	var control_rects := {
		"header": _header_panel.get_global_rect(),
		"casualty_scroll": _casualty_scroll.get_global_rect(),
		"player_panel": _player_panel.get_global_rect(),
		"enemy_panel": _enemy_panel.get_global_rect(),
		"aftermath": _aftermath_panel.get_global_rect(),
		"continue": _continue_button.get_global_rect(),
	}
	var clipped := []
	for key in control_rects:
		var rect: Rect2 = control_rects[key]
		if not viewport_rect.encloses(rect):
			clipped.append(String(key))
	return {
		"report_id": String(_report.get("report_id", "")),
		"outcome": String(_report.get("outcome", "")),
		"pending": bool(_report.get("pending", false)),
		"compact_layout": _compact_layout,
		"grid_columns": _casualty_grid.columns,
		"player_row_count": (player.get("rows", []) as Array).size() if player.get("rows", []) is Array else 0,
		"enemy_row_count": (enemy.get("rows", []) as Array).size() if enemy.get("rows", []) is Array else 0,
		"player_totals": player.get("totals", {}).duplicate(true) if player.get("totals", {}) is Dictionary else {},
		"enemy_totals": enemy.get("totals", {}).duplicate(true) if enemy.get("totals", {}) is Dictionary else {},
		"continue_focus_mode": _continue_button.focus_mode,
		"continue_has_focus": _continue_button.has_focus(),
		"continue_accessibility_name": _continue_button.accessibility_name,
		"clipped_controls": clipped,
		"control_rects": control_rects,
		"viewport_size": size,
		"last_continue_result": _last_continue_result.duplicate(true),
	}
