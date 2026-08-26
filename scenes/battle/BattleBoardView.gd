extends Control

signal stack_focus_requested(battle_id: String)
signal hex_destination_requested(q: int, r: int)
signal controller_navigation_cancelled

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")

const HEX_COLUMNS := 11
const HEX_ROWS := 7
const SQRT_3 := 1.7320508075688772
const BATTLE_BOARD_CURSOR_SEMANTIC_MAX_CHARS := 320
const BATTLE_BOARD_CURSOR_SEMANTIC_DEBOUNCE_SECONDS := 0.42
const BATTLE_BOARD_CURSOR_RESULT_VISIBLE_SECONDS := 1.20

const FRAME_FILL := Color(0.045, 0.052, 0.061, 1.0)
const BOARD_FILL := Color(0.072, 0.078, 0.070, 1.0)
const FRAME_COLOR := Color(0.82, 0.67, 0.37, 0.94)
const HEX_LINE_COLOR := Color(0.93, 0.86, 0.62, 0.28)
const HEX_CENTER_LINE := Color(0.98, 0.86, 0.55, 0.42)
const TEXT_COLOR := Color(0.96, 0.94, 0.89, 1.0)
const SUBTEXT_COLOR := Color(0.83, 0.87, 0.91, 0.95)
const PLAYER_COLOR := Color(0.42, 0.66, 0.90, 0.98)
const ENEMY_COLOR := Color(0.84, 0.38, 0.33, 0.98)
const NEUTRAL_COLOR := Color(0.68, 0.72, 0.78, 0.94)
const ACTIVE_COLOR := Color(0.99, 0.88, 0.48, 1.0)
const TARGET_COLOR := Color(0.97, 0.64, 0.38, 0.98)
const BLOCKED_TARGET_COLOR := Color(0.78, 0.20, 0.18, 0.96)
const TURN_STRIP_PRESENTATION_MODEL := "compact_art_backed_unit_portrait_ribbon"
const TURN_STRIP_MAX_WIDTH := 620.0
const TURN_STRIP_HEIGHT := 36.0
const TURN_STRIP_MARGIN := 10.0
const TURN_STRIP_PORTRAIT_EXTENT := 22.0
const TURN_STRIP_LABEL_LEFT_INSET := 32.0
const TURN_STRIP_FOUNDATION_FILL := Color(0.025, 0.032, 0.038, 0.92)
const TURN_STRIP_CHIP_FILL := Color(0.055, 0.066, 0.072, 0.96)
const TURN_STRIP_ACTIVE_FILL := Color(0.115, 0.102, 0.060, 0.98)
const TURN_STRIP_PORTRAIT_FILL := Color(0.018, 0.024, 0.028, 0.96)
const TURN_STRIP_QUEUED_FRAME := Color(0.45, 0.49, 0.48, 0.78)
const STACK_TOKEN_INNER_FILL := Color(0.035, 0.045, 0.055, 0.94)
const STACK_TOKEN_SIDE_RIM_ALPHA := 0.92
const STACK_TOKEN_SIDE_RIM_WIDTH_FACTOR := 0.15
const STACK_ANIMATION_ART_EXTENT_FACTOR := 1.96
const STACK_ICON_ART_EXTENT_FACTOR := 1.86
const STACK_CAPTION_PLATE_MODEL := "compact_translucent_side_accent_nameplate"
const STACK_CAPTION_FONT_SIZE := 10
const STACK_CAPTION_HORIZONTAL_PADDING := 5.0
const STACK_CAPTION_PLATE_HEIGHT := 16.0
const STACK_CAPTION_TOKEN_GAP := 2.0
const STACK_CAPTION_ACCENT_WIDTH := 2.0
const STACK_CAPTION_PLATE_FILL := Color(0.018, 0.024, 0.029, 0.78)
const STACK_CAPTION_PLATE_FRAME := Color(0.80, 0.74, 0.57, 0.30)
const STACK_CAPTION_PLATE_SHADOW := Color(0.01, 0.014, 0.018, 0.42)
const STACK_CAPTION_ACCENT_ALPHA := 0.82
const MOVE_COLOR := Color(0.42, 0.82, 0.66, 0.48)
const MOVE_RANGE_VISUAL_MODEL := "thin_inset_outline_near_transparent_fill"
const MOVE_RANGE_RADIUS_FACTOR := 0.72
const MOVE_RANGE_FILL_ALPHA := 0.045
const MOVE_RANGE_OUTLINE_WIDTH := 1.15
const LEGAL_MELEE_COLOR := Color(1.0, 0.78, 0.36, 0.90)
const LEGAL_RANGED_COLOR := Color(0.72, 0.88, 1.0, 0.82)
const HEALTH_COLOR := Color(0.95, 0.79, 0.35, 0.96)
const CONTROLLER_CURSOR_COLOR := Color(1.0, 0.92, 0.58, 1.0)
const CONTROLLER_CURSOR_BLOCKED_COLOR := Color(0.94, 0.48, 0.32, 1.0)
const SHADOW_COLOR := Color(0.025, 0.028, 0.031, 0.72)
const TERRAIN_COLORS := {
	"grass": Color(0.31, 0.40, 0.24, 1.0),
	"plains": Color(0.30, 0.38, 0.24, 1.0),
	"forest": Color(0.18, 0.31, 0.22, 1.0),
	"swamp": Color(0.24, 0.29, 0.22, 1.0),
	"rough": Color(0.37, 0.32, 0.24, 1.0),
	"road": Color(0.35, 0.30, 0.24, 1.0),
	"mire": Color(0.21, 0.27, 0.22, 1.0),
}
const TERRAIN_TEXTURE_ALIASES := {
	"plains": "grass",
	"grass": "grass",
	"forest": "forest",
	"swamp": "swamp",
	"rough": "rough",
	"road": "road",
	"mire": "mire",
}
const TERRAIN_TEXTURE_PATHS := {
	"grass": "res://art/battle/terrain/grass.png",
	"forest": "res://art/battle/terrain/forest.png",
	"swamp": "res://art/battle/terrain/swamp.png",
	"rough": "res://art/battle/terrain/hills.png",
	"road": "res://art/battle/terrain/road.png",
	"mire": "res://art/battle/terrain/mire.png",
}
const TERRAIN_TEXTURE_MODULATE := Color(0.98, 0.99, 0.95, 0.98)
const TERRAIN_TEXTURE_READABILITY_WASH := Color(0.02, 0.025, 0.022, 0.045)
const TERRAIN_CONTEXT_TEXTURE_MODULATE := Color(0.56, 0.60, 0.52, 0.72)
const TERRAIN_CONTEXT_READABILITY_WASH := Color(0.015, 0.020, 0.018, 0.24)
const TERRAIN_CONTEXT_MODEL := "subdued_full_field_underlay_beneath_authoritative_hex_grid"
const TERRAIN_HEX_TEXTURE_INSET := 1.0
const TERRAIN_HEX_FALLBACK_INSET := 0.975
const TEXTURED_HEX_LINE_COLOR := Color(0.98, 0.89, 0.62, 0.18)
const TEXTURED_HEX_CENTER_LINE := Color(1.0, 0.86, 0.46, 0.28)
const TEXTURED_DEPLOYMENT_FILL_ALPHA := 0.035
const TEXTURED_CENTER_FILL_ALPHA := 0.045
const TEXTURED_MID_LANE_FILL_ALPHA := 0.018
const TEXTURED_GRID_MAX_CELL_FILL_ALPHA := 0.05
const STACK_ANIMATION_EVENT_PLAYBACK_MSEC := 760
const STACK_ANIMATION_REACTION_DELAY_MSEC := 70
const BATTLE_VFX_PROJECTILE_COLOR := Color(0.94, 0.96, 0.74, 0.88)
const BATTLE_VFX_STATUS_COLOR := Color(0.50, 0.86, 0.74, 0.76)
const BATTLE_VFX_DAMAGE_COLOR := Color(1.0, 0.55, 0.32, 0.82)
const BATTLE_VFX_CAST_COLOR := Color(0.72, 0.80, 1.0, 0.78)
const BATTLE_AUDIO_SAMPLE_RATE := 22050.0
const BATTLE_AUDIO_MAX_ACTIVE_PLAYERS := 8
const BATTLE_AUDIO_REDUCED_REPETITION_MAX_ACTIVE_PLAYERS := 4
const BATTLE_AUDIO_REDUCED_REPETITION_COOLDOWN_MULTIPLIER := 2
const BATTLE_AUDIO_BUS := "Effects"
const BATTLE_SFX_MANIFEST_PATH := "res://content/battle_sfx_manifest.json"
const BATTLE_VFX_MANIFEST_PATH := "res://content/battle_vfx_manifest.json"
const BATTLE_AUDIO_PRIORITY_VALUES := {"low": 1, "normal": 2, "high": 3, "critical": 4}
const BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS := "normal"
const BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC := 80
const BATTLE_CAMERA_MAX_OFFSET_PX := 8.0

var _session = null
var _battle: Dictionary = {}
var _player_stacks: Array = []
var _enemy_stacks: Array = []
var _active_stack: Dictionary = {}
var _target_stack: Dictionary = {}
var _field_objectives: Array = []
var _stack_hit_shapes: Array = []
var _hover_destination_cell := Vector2i(-1, -1)
var _controller_cursor_cell := Vector2i(-1, -1)
var _terrain_textures: Dictionary = {}
var _terrain_texture_missing: Dictionary = {}
var _unit_battle_icon_textures: Dictionary = {}
var _unit_battle_icon_missing: Dictionary = {}
var _unit_animation_sheet_textures: Dictionary = {}
var _unit_animation_sheet_missing: Dictionary = {}
var _stack_animation_playback_records: Dictionary = {}
var _stack_animation_playback_until_msec: Dictionary = {}
var _latest_animation_serial_by_stack: Dictionary = {}
var _stack_animation_cue_playback_records: Dictionary = {}
var _stack_animation_audio_playback_records: Dictionary = {}
var _active_audio_players: Array = []
var _battle_sfx_manifest: Dictionary = {}
var _battle_sfx_manifest_loaded := false
var _battle_vfx_manifest: Dictionary = {}
var _battle_vfx_manifest_loaded := false
var _battle_vfx_textures: Dictionary = {}
var _battle_vfx_texture_missing: Dictionary = {}
var _audio_last_started_msec_by_cue: Dictionary = {}
var _audio_mix_counters: Dictionary = {
	"played": 0,
	"suppressed": 0,
	"evicted": 0,
	"suppressed_by_reason": {},
}
var _presentation_speed := BattleRulesScript.PRESENTATION_SPEED_NORMAL
var _battle_board_cursor_semantic_timer: Timer = null
var _battle_board_cursor_semantic_generation := 0
var _battle_board_cursor_semantic_pending: Dictionary = {}
var _battle_board_cursor_result_request_generation := 0
var _controller_dispatch_in_progress := false

@onready var _battle_board_cursor_live_label: Label = get_node_or_null("%BattleBoardCursorLive") as Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(620.0, 320.0)
	tooltip_text = "Outlined hex click moves. Highlighted enemy click attacks; blocked enemies need movement."
	focus_entered.connect(_on_controller_focus_entered)
	focus_exited.connect(_on_controller_focus_exited)
	_configure_battle_board_cursor_semantic_timer()
	_load_terrain_textures()
	_load_battle_vfx_manifest()

func _exit_tree() -> void:
	_cancel_battle_board_cursor_semantic()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _process(_delta: float) -> void:
	if not _battle.is_empty():
		_expire_animation_playback_records()
		_activate_due_audio_cue_playback()
		_cleanup_audio_players()
		queue_redraw()
	if String(_battle_board_cursor_semantic_pending.get("kind", "")) == "result_clear" and not _battle_board_cursor_result_guard_matches(_battle_board_cursor_semantic_pending):
		_cancel_battle_board_cursor_semantic()

func _gui_input(event: InputEvent) -> void:
	if _handle_controller_navigation_input(event):
		accept_event()
		return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		var hovered_cell := _hex_cell_at_position(motion_event.position)
		if not _is_legal_destination_cell(hovered_cell):
			hovered_cell = Vector2i(-1, -1)
		if hovered_cell != _hover_destination_cell:
			_hover_destination_cell = hovered_cell
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var dispatch := _dispatch_board_click_at_position(mouse_event.position)
	if bool(dispatch.get("accepted", false)):
		accept_event()

func _handle_controller_navigation_input(event: InputEvent) -> bool:
	if not has_focus():
		return false
	if event.is_action_pressed("ui_up"):
		_move_controller_cursor(Vector2i.UP, event is InputEventKey or event is InputEventJoypadButton)
		return true
	if event.is_action_pressed("ui_down"):
		_move_controller_cursor(Vector2i.DOWN, event is InputEventKey or event is InputEventJoypadButton)
		return true
	if event.is_action_pressed("ui_left"):
		_move_controller_cursor(Vector2i.LEFT, event is InputEventKey or event is InputEventJoypadButton)
		return true
	if event.is_action_pressed("ui_right"):
		_move_controller_cursor(Vector2i.RIGHT, event is InputEventKey or event is InputEventJoypadButton)
		return true
	if event.is_action_pressed("ui_accept"):
		return _dispatch_controller_cursor()
	if event.is_action_pressed("ui_cancel"):
		return handle_root_controller_navigation_cancel()
	return false

func handle_root_controller_navigation_cancel() -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or not has_focus():
		return false
	release_focus()
	controller_navigation_cancelled.emit()
	_queue_battle_board_cursor_semantic_result("Battle board navigation ended. Focus returned to battle commands.")
	return true

func _on_controller_focus_entered() -> void:
	_cancel_battle_board_cursor_semantic()
	_ensure_controller_cursor()
	_sync_controller_cursor_preview()
	queue_redraw()

func _on_controller_focus_exited() -> void:
	_cancel_battle_board_cursor_semantic(false)
	_hover_destination_cell = Vector2i(-1, -1)
	queue_redraw()

func _ensure_controller_cursor() -> void:
	if _cell_in_bounds(_controller_cursor_cell):
		return
	var selected_id := String(_battle.get("selected_target_id", ""))
	var selected_cell := _stack_cell_for_battle_id(selected_id)
	if _cell_in_bounds(selected_cell):
		_controller_cursor_cell = selected_cell
		return
	for destination in BattleRulesScript.legal_destinations_for_active_stack(_battle):
		if destination is Dictionary:
			var destination_cell := Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
			if _cell_in_bounds(destination_cell):
				_controller_cursor_cell = destination_cell
				return
	var active_cell := _stack_cell_for_battle_id(String(_battle.get("active_stack_id", "")))
	_controller_cursor_cell = active_cell if _cell_in_bounds(active_cell) else Vector2i(int(HEX_COLUMNS / 2), int(HEX_ROWS / 2))

func _move_controller_cursor(delta: Vector2i, announce_semantic: bool = false) -> void:
	_ensure_controller_cursor()
	var previous_cell := _controller_cursor_cell
	_controller_cursor_cell = Vector2i(
		clampi(_controller_cursor_cell.x + delta.x, 0, HEX_COLUMNS - 1),
		clampi(_controller_cursor_cell.y + delta.y, 0, HEX_ROWS - 1)
	)
	_sync_controller_cursor_preview()
	queue_redraw()
	if announce_semantic and _controller_cursor_cell != previous_cell:
		_schedule_battle_board_cursor_semantic()

func _sync_controller_cursor_preview() -> void:
	_hover_destination_cell = _controller_cursor_cell if has_focus() and _is_legal_destination_cell(_controller_cursor_cell) else Vector2i(-1, -1)

func _dispatch_controller_cursor() -> bool:
	_ensure_controller_cursor()
	if _battle.is_empty() or not _cell_in_bounds(_controller_cursor_cell):
		return false
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	_controller_dispatch_in_progress = true
	if battle_id != "":
		stack_focus_requested.emit(battle_id)
	else:
		hex_destination_requested.emit(_controller_cursor_cell.x, _controller_cursor_cell.y)
	_controller_dispatch_in_progress = false
	return true

func publish_controller_action_result(result: Dictionary) -> void:
	if not _controller_dispatch_in_progress:
		return
	var result_message := String(result.get("message", "")).strip_edges()
	if result_message == "":
		result_message = String(result.get("preview_message", "")).strip_edges()
	if result_message == "":
		result_message = "The selected battle-board action did not report a result."
	_queue_battle_board_cursor_semantic_result(
		"Battle board result: %s" % result_message
	)

func _configure_battle_board_cursor_semantic_timer() -> void:
	if _battle_board_cursor_semantic_timer != null and is_instance_valid(_battle_board_cursor_semantic_timer):
		return
	_battle_board_cursor_semantic_timer = Timer.new()
	_battle_board_cursor_semantic_timer.name = "BattleBoardCursorSemanticTimer"
	_battle_board_cursor_semantic_timer.one_shot = true
	_battle_board_cursor_semantic_timer.timeout.connect(_on_battle_board_cursor_semantic_timeout)
	add_child(_battle_board_cursor_semantic_timer)

func _schedule_battle_board_cursor_semantic() -> void:
	_cancel_battle_board_cursor_semantic()
	if not _battle_board_cursor_context_owned():
		return
	_battle_board_cursor_semantic_pending = {
		"kind": "context",
		"generation": _battle_board_cursor_semantic_generation,
		"session_ref": _session,
		"session_id": _battle_board_cursor_session_id(),
		"battle_ref": _battle,
		"battle_identity": _battle_board_cursor_battle_identity(),
		"turn_signature": _battle_board_cursor_turn_signature(),
		"cursor_cell": _battle_board_cursor_cell_payload(_controller_cursor_cell),
		"label_ref": _battle_board_cursor_live_label,
	}
	_battle_board_cursor_semantic_timer.start(BATTLE_BOARD_CURSOR_SEMANTIC_DEBOUNCE_SECONDS)

func _queue_battle_board_cursor_semantic_result(text: String) -> void:
	var bounded_text := _bounded_battle_board_cursor_semantic_text(
		text,
		BATTLE_BOARD_CURSOR_SEMANTIC_MAX_CHARS
	)
	if bounded_text == "" or not is_inside_tree() or _session == null or _battle.is_empty():
		return
	_cancel_battle_board_cursor_semantic(false)
	_battle_board_cursor_result_request_generation += 1
	var request_generation := _battle_board_cursor_result_request_generation
	call_deferred(
		"_publish_battle_board_cursor_semantic_result",
		bounded_text,
		request_generation,
		_session,
		_battle,
		_battle_board_cursor_session_id(),
		_battle_board_cursor_battle_identity(),
		_battle_board_cursor_turn_signature()
	)

func _publish_battle_board_cursor_semantic_result(
	text: String,
	request_generation: int,
	source_session,
	source_battle: Dictionary,
	source_session_id: String,
	battle_identity: String,
	turn_signature: String
) -> void:
	if (
		request_generation != _battle_board_cursor_result_request_generation
		or not is_inside_tree()
		or _session == null
		or not is_same(source_session, _session)
		or source_session_id != _battle_board_cursor_session_id()
		or not is_same(source_battle, _battle)
		or battle_identity != _battle_board_cursor_battle_identity()
		or turn_signature != _battle_board_cursor_turn_signature()
		or _battle_board_cursor_modal_owner_open()
		or not is_instance_valid(_battle_board_cursor_live_label)
	):
		return
	var expected_focus := get_viewport().gui_get_focus_owner() as Control
	if not _battle_board_cursor_focus_owned_by_shell(expected_focus):
		return
	_cancel_battle_board_cursor_semantic(false)
	_battle_board_cursor_live_label.text = text
	_battle_board_cursor_semantic_pending = {
		"kind": "result_clear",
		"generation": _battle_board_cursor_semantic_generation,
		"session_ref": _session,
		"session_id": _battle_board_cursor_session_id(),
		"battle_ref": _battle,
		"battle_identity": _battle_board_cursor_battle_identity(),
		"turn_signature": _battle_board_cursor_turn_signature(),
		"focus_ref": expected_focus,
		"label_ref": _battle_board_cursor_live_label,
		"label_text": text,
	}
	_battle_board_cursor_semantic_timer.start(BATTLE_BOARD_CURSOR_RESULT_VISIBLE_SECONDS)

func _on_battle_board_cursor_semantic_timeout() -> void:
	var pending := _battle_board_cursor_semantic_pending
	if pending.is_empty() or int(pending.get("generation", -1)) != _battle_board_cursor_semantic_generation:
		return
	_battle_board_cursor_semantic_pending = {}
	match String(pending.get("kind", "")):
		"context":
			_publish_pending_battle_board_cursor_context(pending)
		"result_clear":
			_clear_battle_board_cursor_semantic_result(pending)
		_:
			_cancel_battle_board_cursor_semantic()

func _publish_pending_battle_board_cursor_context(pending: Dictionary) -> void:
	var cursor_value: Variant = pending.get("cursor_cell", {})
	var cursor_payload: Dictionary = cursor_value if cursor_value is Dictionary else {}
	var pending_cell := Vector2i(
		int(cursor_payload.get("q", -1)),
		int(cursor_payload.get("r", -1))
	)
	if (
		not _battle_board_cursor_context_owned()
		or not is_same(pending.get("session_ref"), _session)
		or String(pending.get("session_id", "")) != _battle_board_cursor_session_id()
		or not is_same(pending.get("battle_ref"), _battle)
		or String(pending.get("battle_identity", "")) != _battle_board_cursor_battle_identity()
		or String(pending.get("turn_signature", "")) != _battle_board_cursor_turn_signature()
		or pending_cell != _controller_cursor_cell
		or not is_same(pending.get("label_ref"), _battle_board_cursor_live_label)
	):
		_cancel_battle_board_cursor_semantic()
		return
	var context := _battle_board_cursor_semantic_context()
	if context == "":
		_cancel_battle_board_cursor_semantic()
		return
	_battle_board_cursor_live_label.text = context

func _clear_battle_board_cursor_semantic_result(pending: Dictionary) -> void:
	if int(pending.get("generation", -1)) != _battle_board_cursor_semantic_generation:
		return
	if not _battle_board_cursor_result_guard_matches(pending):
		_cancel_battle_board_cursor_semantic()
		return
	_battle_board_cursor_semantic_generation += 1
	if _battle_board_cursor_live_label.text == String(pending.get("label_text", "")):
		_battle_board_cursor_live_label.text = ""

func _battle_board_cursor_result_guard_matches(pending: Dictionary) -> bool:
	var expected_focus: Variant = pending.get("focus_ref")
	return (
		is_inside_tree()
		and _session != null
		and is_same(pending.get("session_ref"), _session)
		and String(pending.get("session_id", "")) == _battle_board_cursor_session_id()
		and is_same(pending.get("battle_ref"), _battle)
		and String(pending.get("battle_identity", "")) == _battle_board_cursor_battle_identity()
		and String(pending.get("turn_signature", "")) == _battle_board_cursor_turn_signature()
		and is_instance_valid(expected_focus)
		and get_viewport().gui_get_focus_owner() == expected_focus
		and _battle_board_cursor_focus_owned_by_shell(expected_focus)
		and not _battle_board_cursor_modal_owner_open()
		and is_same(pending.get("label_ref"), _battle_board_cursor_live_label)
		and _battle_board_cursor_live_label.text == String(pending.get("label_text", ""))
	)

func _battle_board_cursor_semantic_context() -> String:
	if _battle.is_empty() or not _cell_in_bounds(_controller_cursor_cell):
		return ""
	var role := _controller_cursor_cell_role().replace("_", " ")
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	var active_side := String(_active_stack.get("side", ""))
	var detail := ""
	var action := "check this hex"
	if battle_id != "":
		var stack := _stack_by_id(battle_id)
		var side := String(stack.get("side", "unknown"))
		var name := _bounded_battle_board_cursor_semantic_text(
			String(stack.get("name", stack.get("unit_id", "Stack"))),
			48
		)
		var active_prefix := "active " if battle_id == String(_battle.get("active_stack_id", "")) else ""
		detail = "%s%s stack %s, %d units. %s" % [
			active_prefix,
			side,
			name,
			_stack_alive_count(stack),
			_stack_board_tooltip(battle_id),
		]
		if active_side == "player" and side == "enemy":
			var attack_intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, battle_id)
			var action_label := String(attack_intent.get("label", "")).strip_edges()
			action = action_label if action_label != "" else "select this target"
	else:
		var movement_intent := BattleRulesScript.movement_intent_for_destination(
			_battle,
			_controller_cursor_cell.x,
			_controller_cursor_cell.y
		)
		detail = String(movement_intent.get("message", _movement_board_tooltip(_controller_cursor_cell)))
		action = "move here" if bool(movement_intent.get("movable", false)) else "check this blocked hex"
	if active_side != "player":
		action = "unavailable while input is locked"
	detail = _bounded_battle_board_cursor_semantic_text(detail, 150)
	action = _bounded_battle_board_cursor_semantic_text(action, 44)
	return _bounded_battle_board_cursor_semantic_text(
		"Hex %d,%d; %s. %s A/Enter: %s. B/Escape: return to battle commands." % [
			_controller_cursor_cell.x,
			_controller_cursor_cell.y,
			role,
			detail,
			action,
		],
		BATTLE_BOARD_CURSOR_SEMANTIC_MAX_CHARS
	)

func _battle_board_cursor_context_owned() -> bool:
	return (
		is_inside_tree()
		and has_focus()
		and _session != null
		and not _battle.is_empty()
		and _cell_in_bounds(_controller_cursor_cell)
		and not _battle_board_cursor_modal_owner_open()
		and is_instance_valid(_battle_board_cursor_live_label)
	)

func _battle_board_cursor_modal_owner_open() -> bool:
	var shell := owner
	if shell == null or not is_instance_valid(shell):
		return true
	for dialog_name in [
		"QuickResolveConfirmationDialog",
		"WithdrawalConfirmationDialog",
		"ManualSaveOverwriteDialog",
	]:
		var dialog := shell.get_node_or_null(NodePath(dialog_name))
		if dialog is Window and dialog.visible:
			return true
	var settings_dialog := shell.get_node_or_null(NodePath("ActivePlaySettingsDialog"))
	return (
		settings_dialog != null
		and settings_dialog.has_method("is_open")
		and bool(settings_dialog.call("is_open"))
	)

func _battle_board_cursor_focus_owned_by_shell(focus: Control) -> bool:
	var shell := owner
	return (
		focus != null
		and is_instance_valid(focus)
		and shell != null
		and is_instance_valid(shell)
		and (focus == shell or shell.is_ancestor_of(focus))
	)

func _battle_board_cursor_session_id() -> String:
	return String(_session.session_id) if _session != null else ""

func _battle_board_cursor_battle_identity() -> String:
	return String(_battle.get("encounter_id", ""))

func _battle_board_cursor_turn_signature() -> String:
	return "%d|%d|%s|%s" % [
		int(_battle.get("round", 0)),
		int(_battle.get("turn_index", -1)),
		String(_battle.get("active_stack_id", "")),
		String(_active_stack.get("side", "")),
	]

func _battle_board_cursor_cell_payload(cell: Vector2i) -> Dictionary:
	return {"q": cell.x, "r": cell.y}

func _cancel_battle_board_cursor_semantic(invalidate_staged_result: bool = true) -> void:
	_battle_board_cursor_semantic_generation += 1
	_battle_board_cursor_semantic_pending.clear()
	if invalidate_staged_result:
		_battle_board_cursor_result_request_generation += 1
	if _battle_board_cursor_semantic_timer != null and is_instance_valid(_battle_board_cursor_semantic_timer):
		_battle_board_cursor_semantic_timer.stop()
	if _battle_board_cursor_live_label != null and is_instance_valid(_battle_board_cursor_live_label):
		_battle_board_cursor_live_label.text = ""

func _bounded_battle_board_cursor_semantic_text(value: String, maximum_characters: int) -> String:
	var normalized := " ".join(value.replace("\r", "\n").split("\n", false)).strip_edges()
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	return normalized.left(maximum_characters)

func _dispatch_board_click_at_position(position: Vector2) -> Dictionary:
	var target_cell := _hex_cell_at_position(position)
	var battle_id := _stack_id_at_position(position)
	if battle_id != "":
		if _is_legal_destination_cell(target_cell):
			hex_destination_requested.emit(target_cell.x, target_cell.y)
			return {
				"accepted": true,
				"dispatch": "destination",
				"battle_id": "",
				"shape_battle_id": battle_id,
				"q": target_cell.x,
				"r": target_cell.y,
			}
		var cell_battle_id := _stack_id_at_cell(target_cell)
		if cell_battle_id != "" and cell_battle_id != battle_id:
			stack_focus_requested.emit(cell_battle_id)
			return {
				"accepted": true,
				"dispatch": "stack_hex",
				"battle_id": cell_battle_id,
				"shape_battle_id": battle_id,
				"q": target_cell.x,
				"r": target_cell.y,
			}
	if battle_id == "":
		battle_id = _stack_id_at_cell(target_cell)
		if battle_id != "":
			stack_focus_requested.emit(battle_id)
			return {
				"accepted": true,
				"dispatch": "stack_hex",
				"battle_id": battle_id,
				"q": target_cell.x,
				"r": target_cell.y,
			}
		if target_cell.x < 0:
			return {
				"accepted": false,
				"dispatch": "",
				"battle_id": "",
				"q": target_cell.x,
				"r": target_cell.y,
			}
		if not _is_legal_destination_cell(target_cell):
			var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, target_cell.x, target_cell.y)
			hex_destination_requested.emit(target_cell.x, target_cell.y)
			return {
				"accepted": true,
				"dispatch": "destination_blocked",
				"battle_id": "",
				"q": target_cell.x,
				"r": target_cell.y,
				"message": String(movement_intent.get("message", "")),
			}
		hex_destination_requested.emit(target_cell.x, target_cell.y)
		return {
			"accepted": true,
			"dispatch": "destination",
			"battle_id": "",
			"q": target_cell.x,
			"r": target_cell.y,
		}
	stack_focus_requested.emit(battle_id)
	var stack_cell := _stack_cell_for_battle_id(battle_id)
	return {
		"accepted": true,
		"dispatch": "stack_token",
		"battle_id": battle_id,
		"q": stack_cell.x,
		"r": stack_cell.y,
	}

func _get_tooltip(at_position: Vector2) -> String:
	var turn_strip_entry := _turn_strip_entry_at_position(at_position)
	if not turn_strip_entry.is_empty():
		return _turn_strip_entry_tooltip(turn_strip_entry, _turn_strip_entries(_current_field_rect()).size())
	var destination_cell := _hex_cell_at_position(at_position)
	var battle_id := _stack_id_at_position(at_position)
	if battle_id != "":
		if _is_legal_destination_cell(destination_cell):
			return _movement_board_tooltip(destination_cell)
		var cell_battle_id := _stack_id_at_cell(destination_cell)
		if cell_battle_id != "" and cell_battle_id != battle_id:
			return _stack_board_tooltip(cell_battle_id)
		return _stack_board_tooltip(battle_id)
	battle_id = _stack_id_at_cell(destination_cell)
	if battle_id != "":
		return _stack_board_tooltip(battle_id)
	if _is_legal_destination_cell(destination_cell):
		return _movement_board_tooltip(destination_cell)
	if _cell_in_bounds(destination_cell):
		var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, destination_cell.x, destination_cell.y)
		var message := String(movement_intent.get("message", ""))
		if bool(movement_intent.get("blocked", false)) and message != "":
			return message
	return _fallback_board_tooltip()

func set_battle_state(session) -> void:
	_session = session
	var battle := {}
	if session != null and session.battle is Dictionary:
		battle = session.battle
	_apply_battle_dictionary(battle)

func set_battle_presentation_snapshot(battle_snapshot: Dictionary) -> void:
	_session = null
	_apply_battle_dictionary(battle_snapshot.duplicate(true))

func _apply_battle_dictionary(battle: Dictionary) -> void:
	_cancel_battle_board_cursor_semantic()
	_battle = {}
	_player_stacks = []
	_enemy_stacks = []
	_active_stack = {}
	_target_stack = {}
	_field_objectives = []
	_stack_hit_shapes = []
	if battle.is_empty():
		_controller_cursor_cell = Vector2i(-1, -1)
	if not _is_legal_destination_cell(_hover_destination_cell):
		_hover_destination_cell = Vector2i(-1, -1)
	if not battle.is_empty():
		_battle = battle
		_presentation_speed = String(_battle.get(BattleRulesScript.PRESENTATION_SPEED_KEY, BattleRulesScript.PRESENTATION_SPEED_NORMAL))
		_sync_animation_playback_records()
		_active_stack = BattleRulesScript.get_active_stack(_battle)
		_target_stack = BattleRulesScript.get_selected_target(_battle)
		_field_objectives = _battle.get(BattleRulesScript.FIELD_OBJECTIVES_KEY, []).duplicate(true) if _battle.get(BattleRulesScript.FIELD_OBJECTIVES_KEY, []) is Array else []
		for stack in _battle.get("stacks", []):
			if not (stack is Dictionary) or not _stack_visible_for_presentation(stack):
				continue
			if String(stack.get("side", "")) == "player":
				_player_stacks.append(stack)
			elif String(stack.get("side", "")) == "enemy":
				_enemy_stacks.append(stack)
	if has_focus():
		_ensure_controller_cursor()
		_sync_controller_cursor_preview()
	queue_redraw()

func validation_hex_layout_summary() -> Dictionary:
	var stack_cells := _stack_cells()
	var hex_state := BattleRulesScript.battle_hex_state_summary(_battle) if not _battle.is_empty() else {}
	var layout := _current_hex_layout()
	var hex_radius := float(layout.get("radius", 1.0))
	var terrain_id := _battle_terrain_id()
	var terrain_texture_id := _terrain_texture_id(terrain_id)
	var terrain_texture = _terrain_texture_for(terrain_id)
	var terrain_sampling_summary := _terrain_texture_sampling_summary(terrain_texture)
	var player_input_active := String(_active_stack.get("side", "")) == "player"
	var legal_destinations: Array = hex_state.get("legal_destinations", []) if hex_state.get("legal_destinations", []) is Array else []
	var legal_melee_targets: Array = hex_state.get("legal_melee_targets", []) if hex_state.get("legal_melee_targets", []) is Array else []
	var legal_ranged_targets: Array = hex_state.get("legal_ranged_targets", []) if hex_state.get("legal_ranged_targets", []) is Array else []
	var selected_legality: Dictionary = hex_state.get("selected_target_legality", {}) if hex_state.get("selected_target_legality", {}) is Dictionary else {}
	var selected_click_intent: Dictionary = hex_state.get("selected_target_board_click_intent", {}) if hex_state.get("selected_target_board_click_intent", {}) is Dictionary else {}
	var selected_direct_actionable := bool(hex_state.get("selected_target_direct_actionable", false))
	var selected_continuity_context: Dictionary = hex_state.get("selected_target_continuity_context", {}) if hex_state.get("selected_target_continuity_context", {}) is Dictionary else {}
	var selected_closing_context: Dictionary = hex_state.get("selected_target_closing_context", {}) if hex_state.get("selected_target_closing_context", {}) is Dictionary else {}
	var movement_click_intent: Dictionary = hex_state.get("active_movement_board_click_intent", {}) if hex_state.get("active_movement_board_click_intent", {}) is Dictionary else {}
	var legal_movement_intents: Array = hex_state.get("legal_movement_intents", []) if hex_state.get("legal_movement_intents", []) is Array else []
	if not player_input_active:
		legal_destinations = []
		legal_melee_targets = []
		legal_ranged_targets = []
		legal_movement_intents = []
		if not selected_legality.is_empty():
			selected_legality = selected_legality.duplicate(true)
			selected_legality["melee"] = false
			selected_legality["ranged"] = false
			selected_legality["attackable"] = false
			selected_legality["blocked"] = false
			selected_legality["input_locked"] = true
		if not selected_click_intent.is_empty():
			selected_click_intent = selected_click_intent.duplicate(true)
			selected_click_intent["action"] = ""
			selected_click_intent["label"] = ""
			selected_click_intent["attackable"] = false
			selected_click_intent["blocked"] = false
			selected_click_intent["message"] = "Input locked: it is not the player's turn."
	var hovered_destination_preview := _hover_destination_preview()
	var selected_target_id := String(_battle.get("selected_target_id", ""))
	var selected_target_blocked := selected_target_id != "" and bool(selected_legality.get("blocked", false))
	var stack_entries := []
	for stack in _all_visible_stacks():
		var battle_id := String(stack.get("battle_id", ""))
		var cell: Vector2i = stack_cells.get(battle_id, Vector2i(-1, -1))
		stack_entries.append(
			{
				"battle_id": battle_id,
				"side": String(stack.get("side", "")),
				"unit_id": String(stack.get("unit_id", "")),
				"q": cell.x,
				"r": cell.y,
				"alive_count": _stack_alive_count(stack),
				"active": battle_id == String(_battle.get("active_stack_id", "")),
				"selected_target": battle_id == selected_target_id,
				"preserved_setup_target": battle_id == selected_target_id and not selected_continuity_context.is_empty(),
				"ordinary_closing_target": battle_id == selected_target_id and not selected_closing_context.is_empty(),
				"selected_target_blocked": battle_id == selected_target_id and selected_target_blocked,
				"legal_melee_target": battle_id in legal_melee_targets,
				"legal_ranged_target": battle_id in legal_ranged_targets,
				"legal_attack_target": battle_id in legal_melee_targets or battle_id in legal_ranged_targets,
			}
		)

	var objective_entries := []
	for index in range(_field_objectives.size()):
		var objective_value = _field_objectives[index]
		if not (objective_value is Dictionary):
			continue
		var objective: Dictionary = objective_value
		var cell := _objective_cell(index, String(objective.get("type", "")))
		objective_entries.append(
			{
				"id": String(objective.get("id", "")),
				"type": String(objective.get("type", "")),
				"q": cell.x,
				"r": cell.y,
				"control_side": String(objective.get("control_side", "neutral")),
			}
		)

	return {
		"presentation": "hex",
		"columns": HEX_COLUMNS,
		"rows": HEX_ROWS,
		"hex_count": HEX_COLUMNS * HEX_ROWS,
		"hex_radius": hex_radius,
		"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
		"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
		"terrain": terrain_id,
		"terrain_texture_id": terrain_texture_id,
		"terrain_texture_path": _terrain_texture_path_for(terrain_texture_id),
		"terrain_texture_loaded": terrain_texture != null,
		"terrain_texture_fallback": terrain_texture == null,
		"terrain_rendering_mode": _terrain_rendering_mode(terrain_texture != null),
		"terrain_hex_snapped": true,
		"terrain_hex_tile_count": _terrain_hex_tile_count(),
		"terrain_single_board_backdrop": false,
		"terrain_texture_visible": _terrain_texture_visible(terrain_texture != null),
		"terrain_grid_fill_mode": _terrain_grid_fill_mode(terrain_texture != null),
		"terrain_grid_max_fill_alpha": _terrain_grid_max_fill_alpha(terrain_texture != null),
		"terrain_grid_border_mode": _terrain_grid_border_mode(terrain_texture != null),
		"terrain_grid_repaints_texture_cells": _terrain_grid_repaints_texture_cells(terrain_texture != null),
		"terrain_texture_uv_space": String(terrain_sampling_summary.get("texture_uv_space", "")),
		"terrain_texture_uv_within_0_1": bool(terrain_sampling_summary.get("texture_uv_within_0_1", false)),
		"terrain_texture_source_within_texture": bool(terrain_sampling_summary.get("texture_source_within_texture", false)),
		"terrain_texture_source_sample_count": int(terrain_sampling_summary.get("texture_source_sample_count", 0)),
		"distance": int(_battle.get("distance", 1)),
		"player_stack_count": _player_stacks.size(),
		"enemy_stack_count": _enemy_stacks.size(),
		"stack_cells": stack_entries,
		"field_objective_cells": objective_entries,
		"occupied_hexes": hex_state.get("occupied_hexes", {}),
		"legal_destinations": legal_destinations,
		"legal_destination_count": legal_destinations.size(),
		"movement_range_visual_model": MOVE_RANGE_VISUAL_MODEL,
		"movement_range_cell_count": legal_destinations.size(),
		"movement_range_radius_factor": MOVE_RANGE_RADIUS_FACTOR,
		"movement_range_fill_alpha": MOVE_RANGE_FILL_ALPHA,
		"movement_range_outline_alpha": MOVE_COLOR.a,
		"movement_range_outline_width": MOVE_RANGE_OUTLINE_WIDTH,
		"movement_range_all_legal_cells_drawn": true,
		"movement_range_hover_only": false,
		"movement_range_below_active_targets_and_stacks": true,
		"movement_range_action_authority": "legal_destinations_for_active_stack",
		"legal_movement_intents": legal_movement_intents,
		"hovered_destination_preview": hovered_destination_preview,
		"hovered_destination_detail": String(hovered_destination_preview.get("destination_detail", "")),
		"hovered_destination_sets_up_selected_target_attack": bool(hovered_destination_preview.get("sets_up_selected_target_attack", false)),
		"hovered_destination_closes_on_selected_target": bool(hovered_destination_preview.get("closes_on_selected_target", false)),
		"controller_board_focused": has_focus(),
		"controller_cursor_q": _controller_cursor_cell.x,
		"controller_cursor_r": _controller_cursor_cell.y,
		"controller_cursor_cell_role": _controller_cursor_cell_role(),
		"controller_cursor_battle_id": _stack_id_at_cell(_controller_cursor_cell),
		"controller_cursor_legal_destination": _is_legal_destination_cell(_controller_cursor_cell),
		"active_movement_board_click_intent": movement_click_intent,
		"active_movement_board_click_action": String(movement_click_intent.get("action", "")),
		"active_movement_board_click_label": String(movement_click_intent.get("label", "")),
		"legal_melee_targets": legal_melee_targets,
		"legal_ranged_targets": legal_ranged_targets,
		"legal_attack_target_count": _unique_target_count(legal_melee_targets, legal_ranged_targets),
		"selected_target_battle_id": selected_target_id,
		"selected_target_legality": selected_legality,
		"selected_target_board_click_intent": selected_click_intent,
		"selected_target_board_click_action": String(selected_click_intent.get("action", "")),
		"selected_target_board_click_label": String(selected_click_intent.get("label", "")),
		"selected_target_direct_actionable": selected_direct_actionable,
		"selected_target_continuity_context": selected_continuity_context,
		"selected_target_preserved_setup": not selected_continuity_context.is_empty(),
		"selected_target_continuity_emphasis": String(selected_continuity_context.get("emphasis", "")),
		"selected_target_closing_context": selected_closing_context,
		"selected_target_closing_on_target": not selected_closing_context.is_empty(),
		"selected_target_closing_emphasis": String(selected_closing_context.get("emphasis", "")),
		"selected_target_footer_label": _target_state_label(),
		"selected_target_blocked": selected_target_blocked,
		"selected_target_attackable": bool(selected_legality.get("attackable", false)),
		"has_active_cell": _stack_has_cell(String(_battle.get("active_stack_id", "")), stack_cells),
		"has_selected_target_cell": _stack_has_cell(selected_target_id, stack_cells),
	}

func validation_terrain_backdrop_summary() -> Dictionary:
	return validation_terrain_rendering_summary()

func validation_color_cue_summary() -> Dictionary:
	return {
		"mode": FrontierVisualKitScript.color_cue_mode(),
		"assisted": FrontierVisualKitScript.color_cue_assist_enabled(),
		"player_color": _side_color("player"),
		"enemy_color": _side_color("enemy"),
		"neutral_color": _controller_color("neutral"),
		"player_side_mark": "circle_P" if FrontierVisualKitScript.color_cue_assist_enabled() else "none",
		"enemy_side_mark": "triangle_E" if FrontierVisualKitScript.color_cue_assist_enabled() else "none",
		"side_marks_drawn_with_stack_tokens": FrontierVisualKitScript.color_cue_assist_enabled(),
		"board_tooltip_uses_color_independent_move_wording": "outlined hex" in tooltip_text.to_lower() and "green" not in tooltip_text.to_lower(),
	}

func validation_unit_art_summary() -> Dictionary:
	var stack_entries := []
	var loaded_count := 0
	var missing := []
	var presentation_motion_count := 0
	var presentation_motion_roles := {}
	var stack_cells := _stack_cells()
	var hex_layout := _current_hex_layout()
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		var cell: Vector2i = stack_cells.get(battle_id, Vector2i(-1, -1))
		var presentation := _stack_presentation_summary(stack, cell, hex_layout, stack_cells)
		var unit_id := String(stack.get("unit_id", ""))
		var art := ContentService.get_unit_art(unit_id)
		var path := String(art.get("battle_icon", ""))
		var texture := _unit_battle_icon_for_stack(stack)
		var animation := ContentService.get_unit_animation(unit_id)
		var animation_path := String(animation.get("sprite_sheet", ""))
		var animation_sheet := _unit_animation_sheet_for_stack(stack)
		var loaded := texture != null
		var animation_loaded := animation_sheet != null
		if loaded:
			loaded_count += 1
		else:
			missing.append(unit_id)
		if bool(presentation.get("presentation_motion_active", false)):
			presentation_motion_count += 1
			var role := String(presentation.get("presentation_motion_role", "")).strip_edges()
			if role != "":
				presentation_motion_roles[role] = int(presentation_motion_roles.get(role, 0)) + 1
		stack_entries.append({
			"battle_id": battle_id,
			"unit_id": unit_id,
			"battle_icon": path,
			"loaded": loaded,
			"animation_sheet": animation_path,
			"animation_loaded": animation_loaded,
			"animation_state": _animation_state_for_stack(stack),
			"animation_frame_index": _animation_frame_index_for_stack(stack),
			"cell_q": cell.x,
			"cell_r": cell.y,
			"presentation_x": presentation.get("presentation_x", 0.0),
			"presentation_y": presentation.get("presentation_y", 0.0),
			"presentation_motion_active": bool(presentation.get("presentation_motion_active", false)),
			"presentation_motion_event_id": String(presentation.get("presentation_motion_event_id", "")),
			"presentation_motion_role": String(presentation.get("presentation_motion_role", "")),
			"presentation_motion_source_battle_id": String(presentation.get("presentation_motion_source_battle_id", "")),
			"presentation_motion_target_battle_id": String(presentation.get("presentation_motion_target_battle_id", "")),
			"presentation_motion_from_q": int(presentation.get("presentation_motion_from_q", -1)),
			"presentation_motion_from_r": int(presentation.get("presentation_motion_from_r", -1)),
			"presentation_motion_to_q": int(presentation.get("presentation_motion_to_q", -1)),
			"presentation_motion_to_r": int(presentation.get("presentation_motion_to_r", -1)),
			"presentation_motion_progress": presentation.get("presentation_motion_progress", 1.0),
			"alive_count": _stack_alive_count(stack),
			"event_playback_visible": _stack_alive_count(stack) <= 0 and not _animation_playback_record_for_stack(battle_id).is_empty(),
		})
	return {
		"visible_stack_count": stack_entries.size(),
		"battle_icon_loaded_count": loaded_count,
		"missing_battle_icon_units": missing,
		"animation_sheet_loaded_count": stack_entries.filter(func(entry): return bool(entry.get("animation_loaded", false))).size(),
		"missing_animation_units": stack_entries.filter(func(entry): return not bool(entry.get("animation_loaded", false))).map(func(entry): return String(entry.get("unit_id", ""))),
		"animation_playback": validation_animation_playback_summary(),
		"cue_playback": validation_cue_playback_summary(),
		"vfx_playback": validation_vfx_playback_summary(),
		"audio_playback": validation_audio_playback_summary(),
		"camera_playback": validation_camera_playback_summary(),
		"presentation_motion_count": presentation_motion_count,
		"presentation_motion_roles": presentation_motion_roles,
		"token_visual_contract": _stack_token_visual_contract(hex_layout),
		"stacks": stack_entries,
	}

func _stack_token_visual_contract(hex_layout: Dictionary) -> Dictionary:
	var hex_radius := float(hex_layout.get("radius", 1.0))
	var token_radius := _stack_token_radius(hex_radius)
	return {
		"presentation_model": "character_first_dark_medallion_side_rim",
		"token_radius": token_radius,
		"hit_radius": _stack_hit_shape_radius(hex_radius),
		"inner_fill": STACK_TOKEN_INNER_FILL,
		"side_rim_alpha": STACK_TOKEN_SIDE_RIM_ALPHA,
		"side_rim_width": maxf(2.4, token_radius * STACK_TOKEN_SIDE_RIM_WIDTH_FACTOR),
		"animation_art_extent_factor": STACK_ANIMATION_ART_EXTENT_FACTOR,
		"icon_art_extent_factor": STACK_ICON_ART_EXTENT_FACTOR,
		"animation_art_diameter_fraction": STACK_ANIMATION_ART_EXTENT_FACTOR * 0.5,
		"icon_art_diameter_fraction": STACK_ICON_ART_EXTENT_FACTOR * 0.5,
		"art_contained_within_token": STACK_ANIMATION_ART_EXTENT_FACTOR <= 2.0 and STACK_ICON_ART_EXTENT_FACTOR <= 2.0,
	}

func validation_stack_caption_summary() -> Array:
	var rows: Array = []
	var field_rect := _current_field_rect()
	var hex_layout := _hex_layout(field_rect)
	var stack_cells := _stack_cells()
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if not stack_cells.has(battle_id):
			continue
		var cell: Vector2i = stack_cells.get(battle_id)
		var center := _stack_presentation_center(stack, cell, hex_layout, stack_cells)
		var radius := float(hex_layout.get("radius", 1.0))
		var layout := _stack_caption_layout(center, radius, stack)
		var plate_rect: Rect2 = layout.get("plate_rect", Rect2())
		var text_rect: Rect2 = layout.get("text_rect", Rect2())
		var accent_rect: Rect2 = layout.get("accent_rect", Rect2())
		var token_radius := _stack_token_radius(radius)
		rows.append({
			"battle_id": battle_id,
			"full_name": _stack_full_name(stack),
			"visible_caption": _stack_caption_label(stack),
			"tooltip": _stack_board_tooltip(battle_id),
			"plate_model": STACK_CAPTION_PLATE_MODEL,
			"plate_rect": plate_rect,
			"text_rect": text_rect,
			"accent_rect": accent_rect,
			"field_rect": field_rect,
			"token_center": center,
			"token_radius": token_radius,
			"plate_fill_alpha": STACK_CAPTION_PLATE_FILL.a,
			"plate_frame_alpha": STACK_CAPTION_PLATE_FRAME.a,
			"plate_shadow_alpha": STACK_CAPTION_PLATE_SHADOW.a,
			"accent_side": String(stack.get("side", "")),
			"accent_color": layout.get("accent_color", Color.TRANSPARENT),
			"text_contained": plate_rect.encloses(text_rect),
			"accent_contained": plate_rect.encloses(accent_rect),
			"plate_above_token": plate_rect.end.y <= center.y - token_radius + 0.01,
			"field_contained": field_rect.encloses(plate_rect),
		})
	return rows

func validation_animation_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	var records := {}
	var delayed_record_count := 0
	var max_sequence_delay_msec := 0
	for battle_id in _stack_animation_playback_records.keys():
		var record: Dictionary = _stack_animation_playback_records.get(battle_id, {}) if _stack_animation_playback_records.get(battle_id, {}) is Dictionary else {}
		var sequence_delay := int(record.get("sequence_delay_msec", 0))
		if sequence_delay > 0:
			delayed_record_count += 1
			max_sequence_delay_msec = maxi(max_sequence_delay_msec, sequence_delay)
		records[String(battle_id)] = record.duplicate(true)
	return {
		"playback_duration_msec": STACK_ANIMATION_EVENT_PLAYBACK_MSEC,
		"presentation_speed": _presentation_speed,
		"effective_playback_duration_msec": _presentation_duration_msec(STACK_ANIMATION_EVENT_PLAYBACK_MSEC),
		"reaction_delay_msec": STACK_ANIMATION_REACTION_DELAY_MSEC,
		"active_playback_count": records.size(),
		"delayed_record_count": delayed_record_count,
		"max_sequence_delay_msec": max_sequence_delay_msec,
		"active_records": records,
		"latest_serial_by_stack": _latest_animation_serial_by_stack.duplicate(true),
		"queue_count": BattleRulesScript.animation_event_queue(_battle).size() if not _battle.is_empty() else 0,
	}

func validation_cue_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	_activate_due_audio_cue_playback()
	var records := {}
	var vfx_record_count := 0
	var audio_record_count := 0
	var vfx_cue_count := 0
	var audio_cue_count := 0
	var delayed_record_count := 0
	var max_sequence_delay_msec := 0
	for battle_id in _stack_animation_cue_playback_records.keys():
		var record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
		var vfx_ids: Array = record.get("selected_vfx_cue_ids", []) if record.get("selected_vfx_cue_ids", []) is Array else []
		var audio_ids: Array = record.get("selected_audio_cue_ids", []) if record.get("selected_audio_cue_ids", []) is Array else []
		var sequence_delay := int(record.get("sequence_delay_msec", 0))
		if sequence_delay > 0:
			delayed_record_count += 1
			max_sequence_delay_msec = maxi(max_sequence_delay_msec, sequence_delay)
		if not vfx_ids.is_empty():
			vfx_record_count += 1
			vfx_cue_count += vfx_ids.size()
		if not audio_ids.is_empty():
			audio_record_count += 1
			audio_cue_count += audio_ids.size()
		records[String(battle_id)] = record.duplicate(true)
	return {
		"active_cue_record_count": records.size(),
		"vfx_record_count": vfx_record_count,
		"audio_record_count": audio_record_count,
		"vfx_cue_count": vfx_cue_count,
		"audio_cue_count": audio_cue_count,
		"delayed_record_count": delayed_record_count,
		"max_sequence_delay_msec": max_sequence_delay_msec,
		"reaction_delay_msec": STACK_ANIMATION_REACTION_DELAY_MSEC,
		"active_records": records,
	}

func validation_vfx_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	var stack_cells := _stack_cells()
	var entries := _vfx_draw_entries(_current_hex_layout(), stack_cells)
	var projectile_count := 0
	var status_count := 0
	var impact_count := 0
	var cast_count := 0
	var imported_asset_draw_count := 0
	var procedural_fallback_draw_count := 0
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if bool(entry.get("asset_loaded", false)):
			imported_asset_draw_count += 1
		else:
			procedural_fallback_draw_count += 1
		match String(entry.get("kind", "")):
			"projectile_path":
				projectile_count += 1
			"status_residue", "status_clear":
				status_count += 1
			"damage_tick", "melee_arc", "retaliation_arc", "stack_fade":
				impact_count += 1
			"cast_anchor":
				cast_count += 1
	return {
		"active_vfx_draw_count": entries.size(),
		"projectile_draw_count": projectile_count,
		"status_draw_count": status_count,
		"impact_draw_count": impact_count,
		"cast_draw_count": cast_count,
		"imported_asset_draw_count": imported_asset_draw_count,
		"procedural_fallback_draw_count": procedural_fallback_draw_count,
		"vfx_manifest_path": BATTLE_VFX_MANIFEST_PATH,
		"vfx_manifest_loaded": _battle_vfx_manifest_loaded,
		"active_draw_entries": entries,
	}

func validation_vfx_asset_summary() -> Dictionary:
	_load_battle_vfx_manifest()
	var cues: Dictionary = _battle_vfx_manifest.get("cues", {}) if _battle_vfx_manifest.get("cues", {}) is Dictionary else {}
	var cue_ids: Array = cues.keys()
	cue_ids.sort()
	var texture_paths: Array = []
	var loaded_texture_paths: Array = []
	var missing_texture_paths: Array = []
	for cue_id_value in cue_ids:
		var cue: Dictionary = cues.get(cue_id_value, {}) if cues.get(cue_id_value, {}) is Dictionary else {}
		var texture_path := String(cue.get("texture_path", "")).strip_edges()
		if texture_path == "" or texture_paths.has(texture_path):
			continue
		texture_paths.append(texture_path)
		if _battle_vfx_texture_for_path(texture_path) != null:
			loaded_texture_paths.append(texture_path)
		else:
			missing_texture_paths.append(texture_path)
	return {
		"manifest_path": BATTLE_VFX_MANIFEST_PATH,
		"manifest_loaded": _battle_vfx_manifest_loaded,
		"schema_id": String(_battle_vfx_manifest.get("schema_id", "")),
		"mapped_cue_count": cue_ids.size(),
		"mapped_cue_ids": cue_ids,
		"unique_texture_count": texture_paths.size(),
		"texture_paths": texture_paths,
		"loaded_texture_count": loaded_texture_paths.size(),
		"loaded_texture_paths": loaded_texture_paths,
		"missing_texture_paths": missing_texture_paths,
	}

func validation_audio_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	_activate_due_audio_cue_playback()
	_cleanup_audio_players()
	var records := {}
	var audio_cue_count := 0
	var generated_waveform_count := 0
	var imported_asset_count := 0
	var generated_fallback_count := 0
	var scheduled_record_count := 0
	var played_audio_cue_count := 0
	var suppressed_audio_cue_count := 0
	for battle_id in _stack_animation_audio_playback_records.keys():
		var record: Dictionary = _stack_animation_audio_playback_records.get(battle_id, {}) if _stack_animation_audio_playback_records.get(battle_id, {}) is Dictionary else {}
		var audio_ids: Array = record.get("selected_audio_cue_ids", []) if record.get("selected_audio_cue_ids", []) is Array else []
		audio_cue_count += audio_ids.size()
		generated_waveform_count += int(record.get("generated_waveform_count", 0))
		imported_asset_count += int(record.get("imported_asset_count", 0))
		generated_fallback_count += int(record.get("generated_fallback_count", 0))
		played_audio_cue_count += int(record.get("played_audio_cue_count", 0))
		suppressed_audio_cue_count += int(record.get("suppressed_audio_cue_count", 0))
		if bool(record.get("scheduled", false)):
			scheduled_record_count += 1
		records[String(battle_id)] = record.duplicate(true)
	return {
		"active_audio_record_count": records.size(),
		"audio_cue_count": audio_cue_count,
		"generated_waveform_count": generated_waveform_count,
		"imported_asset_count": imported_asset_count,
		"generated_fallback_count": generated_fallback_count,
		"played_audio_cue_count": played_audio_cue_count,
		"suppressed_audio_cue_count": suppressed_audio_cue_count,
		"scheduled_record_count": scheduled_record_count,
		"active_player_count": _active_audio_player_count(),
		"active_voice_mix": _active_audio_voice_mix(),
		"mix_counters": _audio_mix_counters.duplicate(true),
		"audio_bus": BATTLE_AUDIO_BUS,
		"sfx_manifest_path": BATTLE_SFX_MANIFEST_PATH,
		"sfx_manifest_loaded": _battle_sfx_manifest_loaded,
		"muted": SettingsService.effects_audio_muted(),
		"reduced_repetitive_sounds": SettingsService.reduced_repetitive_sounds_enabled(),
		"effective_voice_budget": _effective_battle_audio_voice_budget(),
		"active_records": records,
	}

func validation_reset_audio_mix() -> void:
	for entry in _active_audio_players:
		if entry is Dictionary:
			var player = entry.get("player", null)
			if player is AudioStreamPlayer and is_instance_valid(player):
				player.queue_free()
	_active_audio_players.clear()
	_audio_last_started_msec_by_cue.clear()
	_audio_mix_counters = {
		"played": 0,
		"suppressed": 0,
		"evicted": 0,
		"suppressed_by_reason": {},
	}

func validation_play_audio_cue(audio_id: String, battle_id: String = "validation", serial: int = 1) -> Dictionary:
	return _play_audio_cue(audio_id, battle_id, serial)

func validation_camera_playback_summary() -> Dictionary:
	_expire_animation_playback_records()
	var stack_cells := _stack_cells()
	var hex_layout := _current_hex_layout()
	var records := _camera_playback_records(hex_layout, stack_cells)
	var focus_kind_counts := {}
	var shake_record_count := 0
	var strongest_record := {}
	for record in records:
		if not (record is Dictionary):
			continue
		var focus_kind := String(record.get("focus_kind", "")).strip_edges()
		if focus_kind != "":
			focus_kind_counts[focus_kind] = int(focus_kind_counts.get(focus_kind, 0)) + 1
		if float(record.get("shake_strength", 0.0)) > 0.0:
			shake_record_count += 1
		if strongest_record.is_empty() or float(record.get("shake_strength", 0.0)) > float(strongest_record.get("shake_strength", 0.0)):
			strongest_record = record
	var offset := _battle_camera_offset_for_records(records)
	return {
		"active_camera_record_count": records.size(),
		"focus_kind_counts": focus_kind_counts,
		"shake_record_count": shake_record_count,
		"strongest_event_id": String(strongest_record.get("event_id", "")),
		"strongest_focus_kind": String(strongest_record.get("focus_kind", "")),
		"strongest_shake_strength": snappedf(float(strongest_record.get("shake_strength", 0.0)), 0.001),
		"configured_shake_mode": SettingsService.battle_camera_shake_mode_id(),
		"configured_shake_scale": SettingsService.battle_camera_shake_scale(),
		"offset_x": snappedf(offset.x, 0.01),
		"offset_y": snappedf(offset.y, 0.01),
		"max_offset_px": BATTLE_CAMERA_MAX_OFFSET_PX,
		"records": records,
	}

func validation_terrain_rendering_summary() -> Dictionary:
	var terrain_id := _battle_terrain_id()
	var texture_id := _terrain_texture_id(terrain_id)
	var texture_path := _terrain_texture_path_for(texture_id)
	var texture = _terrain_texture_for(terrain_id)
	var sampling_summary := _terrain_texture_sampling_summary(texture)
	var texture_size := Vector2.ZERO
	var source_size := Vector2.ZERO
	var field_rect := _current_field_rect()
	if texture != null:
		texture_size = texture.get_size()
		source_size = _terrain_hex_texture_source_size(texture_size)
	return {
		"terrain": terrain_id,
		"texture_id": texture_id,
		"texture_path": texture_path,
		"texture_loaded": texture != null,
		"fallback": texture == null,
		"mapped": terrain_id != texture_id,
		"texture_width": texture_size.x,
		"texture_height": texture_size.y,
		"rendering_mode": _terrain_rendering_mode(texture != null),
		"hex_snapped": true,
		"single_board_backdrop": false,
		"hex_tile_count": _terrain_hex_tile_count(),
		"texture_sample_mode": "per_hex_clipped" if texture != null else "",
		"source_tile_width": source_size.x,
		"source_tile_height": source_size.y,
		"texture_modulate_alpha": TERRAIN_TEXTURE_MODULATE.a if texture != null else 0.0,
		"texture_readability_wash_alpha": TERRAIN_TEXTURE_READABILITY_WASH.a if texture != null else 0.0,
		"terrain_context_underlay_enabled": texture != null,
		"terrain_context_model": TERRAIN_CONTEXT_MODEL if texture != null else "disabled_for_texture_fallback",
		"terrain_context_rect": {"x": field_rect.position.x, "y": field_rect.position.y, "width": field_rect.size.x, "height": field_rect.size.y} if texture != null else {},
		"terrain_context_covers_full_field": texture != null and field_rect.size.x > 0.0 and field_rect.size.y > 0.0,
		"terrain_context_texture_modulate_alpha": TERRAIN_CONTEXT_TEXTURE_MODULATE.a if texture != null else 0.0,
		"terrain_context_readability_wash_alpha": TERRAIN_CONTEXT_READABILITY_WASH.a if texture != null else 0.0,
		"terrain_context_preserves_hex_authority": texture != null and int(sampling_summary.get("texture_source_sample_count", 0)) == _terrain_hex_tile_count(),
		"texture_hex_inset": TERRAIN_HEX_TEXTURE_INSET if texture != null else TERRAIN_HEX_FALLBACK_INSET,
		"texture_visible": _terrain_texture_visible(texture != null),
		"grid_fill_mode": _terrain_grid_fill_mode(texture != null),
		"grid_max_fill_alpha": _terrain_grid_max_fill_alpha(texture != null),
		"grid_border_mode": _terrain_grid_border_mode(texture != null),
		"grid_border_deduplicated": _terrain_grid_border_deduplicated(texture != null),
		"grid_repaints_texture_cells": _terrain_grid_repaints_texture_cells(texture != null),
		"texture_uv_space": String(sampling_summary.get("texture_uv_space", "")),
		"texture_uv_min_x": float(sampling_summary.get("texture_uv_min_x", 0.0)),
		"texture_uv_min_y": float(sampling_summary.get("texture_uv_min_y", 0.0)),
		"texture_uv_max_x": float(sampling_summary.get("texture_uv_max_x", 0.0)),
		"texture_uv_max_y": float(sampling_summary.get("texture_uv_max_y", 0.0)),
		"texture_uv_within_0_1": bool(sampling_summary.get("texture_uv_within_0_1", false)),
		"texture_source_min_x": float(sampling_summary.get("texture_source_min_x", 0.0)),
		"texture_source_min_y": float(sampling_summary.get("texture_source_min_y", 0.0)),
		"texture_source_max_x": float(sampling_summary.get("texture_source_max_x", 0.0)),
		"texture_source_max_y": float(sampling_summary.get("texture_source_max_y", 0.0)),
		"texture_source_within_texture": bool(sampling_summary.get("texture_source_within_texture", false)),
		"texture_source_sample_count": int(sampling_summary.get("texture_source_sample_count", 0)),
	}

func validation_preview_hex_destination(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if _is_legal_destination_cell(cell):
		_hover_destination_cell = cell
	else:
		_hover_destination_cell = Vector2i(-1, -1)
	queue_redraw()
	return BattleRulesScript.movement_intent_for_destination(_battle, q, r)

func validation_perform_hex_cell_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_click_position_for_cell(cell)
	if probe.is_empty():
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click could not resolve a point inside the requested cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var cell_target_before := _stack_id_at_cell(resolved_cell)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["cell_target_before"] = cell_target_before
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_shape_miss_position"] = bool(probe.get("found_shape_miss_position", false))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	return dispatch

func validation_perform_outer_hex_ring_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_outer_ring_click_position_for_cell(cell)
	if probe.is_empty():
		var layout := _current_hex_layout()
		var hex_radius := float(layout.get("radius", 1.0))
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"found_outer_ring_position": false,
			"hex_radius": hex_radius,
			"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
			"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
			"message": "Validation click could not find a token-miss point in the visible outer hex ring.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var cell_target_before := _stack_id_at_cell(resolved_cell)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["cell_target_before"] = cell_target_before
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_outer_ring_position"] = bool(probe.get("found_outer_ring_position", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	dispatch["stack_hit_shape_radius"] = _stack_hit_shape_radius(float(probe.get("hex_radius", 1.0)))
	dispatch["neighboring_stack_hit_shape_overlap_possible"] = _neighboring_stack_hit_shape_overlap_possible(float(probe.get("hex_radius", 1.0)))
	return dispatch

func validation_perform_overlapped_hex_destination_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_overlapped_destination_click_position_for_cell(cell)
	if probe.is_empty():
		var layout := _current_hex_layout()
		var hex_radius := float(layout.get("radius", 1.0))
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"hex_radius": hex_radius,
			"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
			"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
			"message": "Validation click could not find a friendly-shape overlap inside the requested movement cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var legal_destination_before := _is_legal_destination_cell(resolved_cell)
	var movement_intent_before := BattleRulesScript.movement_intent_for_destination(_battle, resolved_cell.x, resolved_cell.y)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["legal_destination_before"] = legal_destination_before
	dispatch["movement_tooltip_before"] = String(movement_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_friendly_shape_overlap"] = bool(probe.get("found_shape_overlap", probe.get("found_friendly_shape_overlap", false)))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	dispatch["stack_hit_shape_radius"] = _stack_hit_shape_radius(float(probe.get("hex_radius", 1.0)))
	dispatch["neighboring_stack_hit_shape_overlap_possible"] = _neighboring_stack_hit_shape_overlap_possible(float(probe.get("hex_radius", 1.0)))
	return dispatch

func validation_perform_enemy_overlapped_hex_destination_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var probe := _validation_overlapped_destination_click_position_for_cell(cell, "enemy")
	if probe.is_empty():
		var layout := _current_hex_layout()
		var hex_radius := float(layout.get("radius", 1.0))
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"hex_radius": hex_radius,
			"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
			"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
			"message": "Validation click could not find an enemy-shape overlap inside the requested movement cell.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	var legal_destination_before := _is_legal_destination_cell(resolved_cell)
	var movement_intent_before := BattleRulesScript.movement_intent_for_destination(_battle, resolved_cell.x, resolved_cell.y)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["legal_destination_before"] = legal_destination_before
	dispatch["movement_tooltip_before"] = String(movement_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_enemy_shape_overlap"] = bool(probe.get("found_shape_overlap", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	dispatch["stack_hit_shape_radius"] = _stack_hit_shape_radius(float(probe.get("hex_radius", 1.0)))
	dispatch["neighboring_stack_hit_shape_overlap_possible"] = _neighboring_stack_hit_shape_overlap_possible(float(probe.get("hex_radius", 1.0)))
	return dispatch

func validation_perform_enemy_overlapped_occupied_hex_mouse_click(q: int, r: int) -> Dictionary:
	var cell := Vector2i(q, r)
	if not _cell_in_bounds(cell):
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is outside the battlefield.",
		}
	var cell_target_before := _stack_id_at_cell(cell)
	if cell_target_before == "":
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"message": "Validation click cell is not occupied by a stack.",
		}
	var probe := _validation_overlapped_occupied_hex_click_position_for_cell(cell, "enemy")
	if probe.is_empty():
		var layout := _current_hex_layout()
		var hex_radius := float(layout.get("radius", 1.0))
		return {
			"accepted": false,
			"dispatch": "",
			"battle_id": "",
			"q": q,
			"r": r,
			"hex_radius": hex_radius,
			"stack_hit_shape_radius": _stack_hit_shape_radius(hex_radius),
			"neighboring_stack_hit_shape_overlap_possible": _neighboring_stack_hit_shape_overlap_possible(hex_radius),
			"message": "Validation click could not find an enemy-shape overlap inside the occupied hex.",
		}
	var position: Vector2 = probe.get("position", Vector2.ZERO)
	var shape_target_before := _stack_id_at_position(position)
	var resolved_cell := _hex_cell_at_position(position)
	cell_target_before = _stack_id_at_cell(resolved_cell)
	var cell_target_intent_before := BattleRulesScript.board_click_attack_intent_for_target(_battle, cell_target_before)
	var tooltip_before := _get_tooltip(position)
	var dispatch := _dispatch_board_click_at_position(position)
	dispatch["shape_target_before"] = shape_target_before
	dispatch["shape_target_side_before"] = String(_stack_by_id(shape_target_before).get("side", ""))
	dispatch["cell_target_before"] = cell_target_before
	dispatch["cell_target_side_before"] = String(_stack_by_id(cell_target_before).get("side", ""))
	dispatch["cell_target_click_action_before"] = String(cell_target_intent_before.get("action", ""))
	dispatch["cell_target_tooltip_before"] = String(cell_target_intent_before.get("message", ""))
	dispatch["tooltip_before"] = tooltip_before
	dispatch["resolved_q"] = resolved_cell.x
	dispatch["resolved_r"] = resolved_cell.y
	dispatch["position_x"] = position.x
	dispatch["position_y"] = position.y
	dispatch["found_enemy_shape_overlap"] = bool(probe.get("found_shape_overlap", false))
	dispatch["radius_factor"] = float(probe.get("radius_factor", 0.0))
	dispatch["hex_radius"] = float(probe.get("hex_radius", 0.0))
	dispatch["stack_hit_shape_radius"] = _stack_hit_shape_radius(float(probe.get("hex_radius", 1.0)))
	dispatch["neighboring_stack_hit_shape_overlap_possible"] = _neighboring_stack_hit_shape_overlap_possible(float(probe.get("hex_radius", 1.0)))
	return dispatch

func validation_board_fallback_tooltip() -> Dictionary:
	var position := _validation_fallback_tooltip_position()
	if position.x < 0.0:
		return {
			"ok": false,
			"message": "Validation could not find an empty board fallback tooltip position.",
		}
	var resolved_cell := _hex_cell_at_position(position)
	var shape_target := _stack_id_at_position(position)
	return {
		"ok": true,
		"tooltip": _get_tooltip(position),
		"position_x": position.x,
		"position_y": position.y,
		"resolved_q": resolved_cell.x,
		"resolved_r": resolved_cell.y,
		"shape_target": shape_target,
	}

func validation_turn_strip_identity_surface() -> Dictionary:
	var field_rect := _current_field_rect()
	var strip_rect := _turn_strip_rect(field_rect)
	var entries := _turn_strip_entries(field_rect)
	var rows: Array = []
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var stack: Dictionary = entry.get("stack", {}) if entry.get("stack", {}) is Dictionary else {}
		var rect: Rect2 = entry.get("rect", Rect2())
		var center := rect.get_center()
		var visible_label := _turn_strip_chip_label(stack, rect.size.x)
		var portrait := _turn_strip_portrait_payload(stack, rect)
		var font = get_theme_default_font()
		rows.append({
			"slot": int(entry.get("slot", 0)),
			"battle_id": String(stack.get("battle_id", "")),
			"full_name": _stack_full_name(stack),
			"alive_count": _stack_alive_count(stack),
			"side": String(stack.get("side", "")),
			"unit_id": String(stack.get("unit_id", "")),
			"current": String(stack.get("battle_id", "")) == String(_battle.get("active_stack_id", "")),
			"visible_label": visible_label,
			"visible_label_width": font.get_string_size(visible_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x if font != null else 0.0,
			"visible_label_max_width": maxf(24.0, rect.size.x - TURN_STRIP_LABEL_LEFT_INSET - 6.0),
			"portrait": portrait,
			"tooltip": _get_tooltip(center),
			"rect": rect,
			"center": center,
		})
	return {
		"rows": rows,
		"visible_count": rows.size(),
		"visible_cap": 5,
		"presentation_model": TURN_STRIP_PRESENTATION_MODEL,
		"strip_rect": strip_rect,
		"portrait_extent": TURN_STRIP_PORTRAIT_EXTENT,
		"label_left_inset": TURN_STRIP_LABEL_LEFT_INSET,
		"missing_portrait_control": _turn_strip_portrait_payload({"unit_id": "unit_missing_turn_strip_portrait"}, Rect2(Vector2.ZERO, Vector2(112.0, 28.0))),
		"field_rect": field_rect,
		"active_stack_id": String(_battle.get("active_stack_id", "")),
		"turn_order": (_battle.get("turn_order", []) as Array).duplicate(true) if _battle.get("turn_order", []) is Array else [],
	}

func _draw() -> void:
	_stack_hit_shapes = []
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _battle.is_empty():
		return

	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	draw_rect(board_rect, BOARD_FILL, true)
	draw_rect(board_rect, FRAME_COLOR, false, 3.0)

	var field_rect := _current_field_rect()
	var hex_field_rect := _hex_field_rect(field_rect)
	var hex_layout := _hex_layout(hex_field_rect)
	hex_layout = _camera_adjusted_hex_layout(hex_layout)
	var terrain_texture_loaded := _draw_terrain(field_rect, hex_layout)
	_draw_hex_grid(hex_layout, terrain_texture_loaded)
	_draw_field_objectives(hex_layout)
	var stack_cells := _stack_cells()
	_draw_tactical_affordances(hex_layout, stack_cells)
	_draw_controller_cursor(hex_layout)
	_draw_vfx_cues(hex_layout, stack_cells)
	_draw_stack_tokens(hex_layout, stack_cells)
	_draw_turn_strip(field_rect)
	_draw_footer_line(field_rect)

func _draw_terrain(field_rect: Rect2, hex_layout: Dictionary) -> bool:
	var terrain := _battle_terrain_id()
	var base_color := _terrain_color_for(terrain)
	draw_rect(field_rect, base_color, true)
	var terrain_texture = _terrain_texture_for(terrain)
	if terrain_texture != null:
		_draw_terrain_context_underlay(field_rect, terrain_texture)
		_draw_hex_snapped_terrain_texture(hex_layout, terrain_texture)
		draw_rect(field_rect, TERRAIN_TEXTURE_READABILITY_WASH, true)
		draw_rect(field_rect, Color(0.0, 0.0, 0.0, 0.14), false, 2.0)
		return true
	else:
		_draw_hex_snapped_procedural_terrain(hex_layout, terrain)
	draw_rect(field_rect, Color(0.0, 0.0, 0.0, 0.14), false, 2.0)
	return false

func _draw_terrain_context_underlay(field_rect: Rect2, texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or field_rect.size.x <= 0.0 or field_rect.size.y <= 0.0:
		return
	draw_texture_rect(texture, field_rect, false, TERRAIN_CONTEXT_TEXTURE_MODULATE)
	draw_rect(field_rect, TERRAIN_CONTEXT_READABILITY_WASH, true)

func _draw_hex_snapped_terrain_texture(hex_layout: Dictionary, texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var radius := float(hex_layout.get("radius", 1.0))
	var source_size := _terrain_hex_texture_source_size(texture_size)
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			var points := _hex_points(center, radius * TERRAIN_HEX_TEXTURE_INSET)
			var bounds := _points_bounds(points)
			if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
				continue
			var source_rect := Rect2(_terrain_hex_texture_source_position(cell, texture_size, source_size), source_size)
			var uvs := _terrain_hex_texture_uvs(points, bounds, source_rect, texture_size)
			if uvs.size() != points.size():
				continue
			var shade := 0.92 + _hex_variation(cell, 43.0) * 0.10
			var modulate := Color(
				clampf(TERRAIN_TEXTURE_MODULATE.r * shade, 0.0, 1.0),
				clampf(TERRAIN_TEXTURE_MODULATE.g * shade, 0.0, 1.0),
				clampf(TERRAIN_TEXTURE_MODULATE.b * shade, 0.0, 1.0),
				TERRAIN_TEXTURE_MODULATE.a
			)
			var colors := PackedColorArray()
			for _point in points:
				colors.append(modulate)
			draw_polygon(points, colors, uvs, texture)

func _draw_hex_snapped_procedural_terrain(hex_layout: Dictionary, terrain: String) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	var base_color := _terrain_color_for(terrain)
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			var shade := 0.88 + _hex_variation(cell, 11.0) * 0.18
			var fill := Color(
				clampf(base_color.r * shade, 0.0, 1.0),
				clampf(base_color.g * shade, 0.0, 1.0),
				clampf(base_color.b * shade, 0.0, 1.0),
				0.92
			)
			_draw_hex(center, radius * TERRAIN_HEX_FALLBACK_INSET, fill, Color(0.0, 0.0, 0.0, 0.0), 0.0)
			_draw_hex_procedural_detail(center, radius, terrain, cell)

func _draw_hex_procedural_detail(center: Vector2, radius: float, terrain: String, cell: Vector2i) -> void:
	var detail_roll := _hex_variation(cell, 29.0)
	match terrain:
		"forest":
			if detail_roll > 0.34:
				_draw_tree(center + Vector2(radius * 0.12, -radius * 0.08), radius * (0.26 + detail_roll * 0.08))
		"swamp", "mire":
			if detail_roll > 0.24:
				draw_circle(center + Vector2(radius * 0.12, radius * 0.04), radius * 0.24, Color(0.10, 0.17, 0.16, 0.28))
				draw_circle(center + Vector2(radius * 0.02, -radius * 0.04), radius * 0.12, Color(0.36, 0.42, 0.31, 0.15))
		"rough":
			if detail_roll > 0.30:
				_draw_hill(center + Vector2(0.0, radius * 0.06), radius * 0.88, radius * 0.38)
		"road":
			if cell.y == 3 or (cell.y == 2 and cell.x < 4) or (cell.y == 4 and cell.x > 6):
				draw_line(center + Vector2(-radius * 0.46, radius * 0.18), center + Vector2(radius * 0.46, -radius * 0.12), Color(0.50, 0.39, 0.24, 0.36), radius * 0.20, true)
		_:
			if detail_roll > 0.48:
				draw_line(center + Vector2(-radius * 0.26, radius * 0.22), center + Vector2(radius * 0.18, radius * 0.02), Color(0.16, 0.23, 0.12, 0.24), 1.6, true)

func _load_terrain_textures() -> void:
	for terrain_id_value in TERRAIN_TEXTURE_PATHS.keys():
		_load_terrain_texture(String(terrain_id_value))

func _load_terrain_texture(terrain_id: String) -> void:
	if _terrain_textures.has(terrain_id) or _terrain_texture_missing.has(terrain_id):
		return
	var texture_path := _terrain_texture_path_for(terrain_id)
	if texture_path == "":
		_terrain_texture_missing[terrain_id] = texture_path
		return
	if ResourceLoader.exists(texture_path):
		var resource = load(texture_path)
		if resource is Texture2D:
			_terrain_textures[terrain_id] = resource
			return
	if FileAccess.file_exists(texture_path):
		var image := Image.new()
		var load_result := image.load(texture_path)
		if load_result == OK:
			_terrain_textures[terrain_id] = ImageTexture.create_from_image(image)
			return
	_terrain_texture_missing[terrain_id] = texture_path

func _terrain_texture_for(terrain_id: String):
	var texture_id := _terrain_texture_id(terrain_id)
	if texture_id == "":
		return null
	_load_terrain_texture(texture_id)
	return _terrain_textures.get(texture_id, null)

func _terrain_texture_id(terrain_id: String) -> String:
	var normalized := terrain_id.strip_edges().to_lower()
	if normalized == "":
		normalized = "plains"
	return String(TERRAIN_TEXTURE_ALIASES.get(normalized, normalized))

func _terrain_texture_path_for(texture_id: String) -> String:
	return String(TERRAIN_TEXTURE_PATHS.get(texture_id, ""))

func _unit_battle_icon_for_stack(stack: Dictionary) -> Texture2D:
	var unit_id := String(stack.get("unit_id", ""))
	if unit_id == "":
		return null
	var art := ContentService.get_unit_art(unit_id)
	var path := String(art.get("battle_icon", ""))
	if path == "":
		return null
	return _unit_battle_icon_texture(path)

func _unit_battle_icon_texture(path: String) -> Texture2D:
	if _unit_battle_icon_textures.has(path):
		return _unit_battle_icon_textures[path]
	if _unit_battle_icon_missing.has(path):
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			texture = resource
	if texture == null and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		_unit_battle_icon_textures[path] = texture
		return texture
	_unit_battle_icon_missing[path] = true
	return null

func _unit_animation_sheet_for_stack(stack: Dictionary) -> Texture2D:
	var unit_id := String(stack.get("unit_id", ""))
	if unit_id == "":
		return null
	var animation := ContentService.get_unit_animation(unit_id)
	var path := String(animation.get("sprite_sheet", ""))
	if path == "":
		return null
	return _unit_animation_sheet_texture(path)

func _unit_animation_sheet_texture(path: String) -> Texture2D:
	if _unit_animation_sheet_textures.has(path):
		return _unit_animation_sheet_textures[path]
	if _unit_animation_sheet_missing.has(path):
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			texture = resource
	if texture == null and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture != null:
		_unit_animation_sheet_textures[path] = texture
		return texture
	_unit_animation_sheet_missing[path] = true
	return null

func _animation_frame_region_for_stack(stack: Dictionary) -> Rect2:
	var state_name := _animation_state_for_stack(stack)
	var row := _animation_state_row_for_unit(String(stack.get("unit_id", "")), state_name)
	var frame := _animation_frame_index_for_stack(stack)
	return Rect2(Vector2(64.0 * float(frame), 64.0 * float(row)), Vector2(64.0, 64.0))

func _animation_frame_index_for_stack(stack: Dictionary) -> int:
	var battle_id := String(stack.get("battle_id", ""))
	var playback_record := _animation_playback_record_for_stack(battle_id)
	if playback_record.is_empty():
		return int(Time.get_ticks_msec() / 180) % 4
	var progress := _stack_presentation_progress(battle_id)
	return clampi(int(floor(progress * 4.0)), 0, 3)

func _animation_state_for_stack(stack: Dictionary) -> String:
	var playback_record := _animation_playback_record_for_stack(String(stack.get("battle_id", "")))
	if not playback_record.is_empty():
		return String(playback_record.get("state", ""))
	return _fallback_animation_state_for_stack(stack)

func _fallback_animation_state_for_stack(stack: Dictionary) -> String:
	var battle_id := String(stack.get("battle_id", ""))
	if battle_id != "" and battle_id == String(_battle.get("active_stack_id", "")):
		return "ready_active"
	if bool(stack.get("defending", false)):
		return "defend_brace"
	return "idle_hold"

func _animation_playback_record_for_stack(battle_id: String) -> Dictionary:
	if battle_id == "":
		return {}
	var expires_at := int(_stack_animation_playback_until_msec.get(battle_id, 0))
	if expires_at <= int(Time.get_ticks_msec()):
		_stack_animation_playback_records.erase(battle_id)
		_stack_animation_playback_until_msec.erase(battle_id)
		_stack_animation_cue_playback_records.erase(battle_id)
		_stack_animation_audio_playback_records.erase(battle_id)
		return {}
	var record: Dictionary = _stack_animation_playback_records.get(battle_id, {}) if _stack_animation_playback_records.get(battle_id, {}) is Dictionary else {}
	return record.duplicate(true)

func _sync_animation_playback_records() -> void:
	var now := int(Time.get_ticks_msec())
	var stack_ids := {}
	for stack in _battle.get("stacks", []):
		if stack is Dictionary:
			var battle_id := String(stack.get("battle_id", ""))
			if battle_id != "":
				stack_ids[battle_id] = true
	for battle_id in _stack_animation_playback_records.keys():
		if not stack_ids.has(String(battle_id)):
			_stack_animation_playback_records.erase(battle_id)
			_stack_animation_playback_until_msec.erase(battle_id)
			_stack_animation_cue_playback_records.erase(battle_id)
			_stack_animation_audio_playback_records.erase(battle_id)
	for event in BattleRulesScript.animation_event_queue(_battle):
		if not (event is Dictionary):
			continue
		var battle_id := String(event.get("battle_id", ""))
		if battle_id == "" or not stack_ids.has(battle_id):
			continue
		var serial := int(event.get("serial", 0))
		if serial <= int(_latest_animation_serial_by_stack.get(battle_id, 0)):
			continue
		_latest_animation_serial_by_stack[battle_id] = serial
		var cue_record := _animation_cue_playback_record_for_event(event)
		var sequence_delay_msec := _presentation_sequence_delay_msec(_sequence_delay_msec_for_event(event, cue_record))
		var base_duration_msec: int = int(cue_record.get("max_duration_ms", STACK_ANIMATION_EVENT_PLAYBACK_MSEC)) if not cue_record.is_empty() else STACK_ANIMATION_EVENT_PLAYBACK_MSEC
		var duration_msec: int = _presentation_duration_msec(base_duration_msec)
		var started_at_msec := now + sequence_delay_msec
		var expires_at_msec: int = started_at_msec + max(1, duration_msec)
		var playback_record: Dictionary = event.duplicate(true)
		playback_record["observed_at_msec"] = now
		playback_record["started_at_msec"] = started_at_msec
		playback_record["expires_at_msec"] = expires_at_msec
		playback_record["sequence_delay_msec"] = sequence_delay_msec
		playback_record["max_duration_ms"] = duration_msec
		_stack_animation_playback_records[battle_id] = playback_record
		if not cue_record.is_empty():
			cue_record["observed_at_msec"] = now
			cue_record["started_at_msec"] = started_at_msec
			cue_record["expires_at_msec"] = expires_at_msec
			cue_record["sequence_delay_msec"] = sequence_delay_msec
			cue_record["max_duration_ms"] = duration_msec
			_stack_animation_cue_playback_records[battle_id] = cue_record
			_register_audio_cue_playback(cue_record)
		else:
			_stack_animation_cue_playback_records.erase(battle_id)
			_stack_animation_audio_playback_records.erase(battle_id)
		_stack_animation_playback_until_msec[battle_id] = expires_at_msec

func _sequence_delay_msec_for_event(event: Dictionary, cue_record: Dictionary) -> int:
	var event_id := String(event.get("event_id", "")).strip_edges()
	var policy := String(cue_record.get("selected_playback_policy", "")).strip_edges()
	if policy.begins_with("queue_after_"):
		return STACK_ANIMATION_REACTION_DELAY_MSEC
	if event_id in ["battle_unit_hit", "battle_unit_death", "battle_status_applied", "battle_status_expired"] and String(event.get("source_battle_id", "")).strip_edges() != "":
		return STACK_ANIMATION_REACTION_DELAY_MSEC
	if event_id == "battle_retaliation":
		return STACK_ANIMATION_REACTION_DELAY_MSEC
	return 0

func _presentation_duration_msec(base_duration_msec: int) -> int:
	match _presentation_speed:
		BattleRulesScript.PRESENTATION_SPEED_FAST:
			return max(1, int(round(float(max(1, base_duration_msec)) * 0.42)))
		BattleRulesScript.PRESENTATION_SPEED_INSTANT:
			return 1
	return max(1, base_duration_msec)

func _presentation_sequence_delay_msec(base_delay_msec: int) -> int:
	match _presentation_speed:
		BattleRulesScript.PRESENTATION_SPEED_FAST:
			return max(0, int(round(float(max(0, base_delay_msec)) * 0.42)))
		BattleRulesScript.PRESENTATION_SPEED_INSTANT:
			return 0
	return max(0, base_delay_msec)

func _expire_animation_playback_records() -> void:
	var now := int(Time.get_ticks_msec())
	for battle_id in _stack_animation_playback_until_msec.keys():
		if int(_stack_animation_playback_until_msec.get(battle_id, 0)) <= now:
			_stack_animation_playback_until_msec.erase(battle_id)
			_stack_animation_playback_records.erase(battle_id)
			_stack_animation_cue_playback_records.erase(battle_id)
			_stack_animation_audio_playback_records.erase(battle_id)

func _animation_cue_playback_record_for_event(event: Dictionary) -> Dictionary:
	var event_id := String(event.get("event_id", "")).strip_edges()
	var battle_id := String(event.get("battle_id", "")).strip_edges()
	if event_id == "" or battle_id == "":
		return {}
	var policy := AnimationCueCatalogScript.cue_playback_policy_for_event(event_id, _animation_preferences())
	if policy.is_empty():
		return {}
	var selected_vfx_cue_ids: Array = policy.get("selected_vfx_cue_ids", []) if policy.get("selected_vfx_cue_ids", []) is Array else []
	var selected_audio_cue_ids: Array = policy.get("selected_audio_cue_ids", []) if policy.get("selected_audio_cue_ids", []) is Array else []
	var allows_strong_flash := bool(policy.get("allows_strong_flash", true))
	if allows_strong_flash:
		selected_vfx_cue_ids = _spell_specific_vfx_cue_ids_for_event(event, selected_vfx_cue_ids)
	selected_audio_cue_ids = _spell_specific_audio_cue_ids_for_event(event, selected_audio_cue_ids)
	return {
		"battle_id": battle_id,
		"event_id": event_id,
		"state": String(event.get("state", "")),
		"serial": int(event.get("serial", 0)),
		"target_battle_id": String(event.get("target_battle_id", "")),
		"source_battle_id": String(event.get("source_battle_id", "")),
		"from_q": int(event.get("from_q", -1)),
		"from_r": int(event.get("from_r", -1)),
		"to_q": int(event.get("to_q", -1)),
		"to_r": int(event.get("to_r", -1)),
		"spell_id": String(event.get("spell_id", "")),
		"resolution_type": String(event.get("resolution_type", "")),
		"cue_id": String(policy.get("cue_id", "")),
		"mode": String(policy.get("mode", AnimationCueCatalogScript.MODE_NORMAL)),
		"selected_animation_state": String(policy.get("selected_animation_state", "")),
		"selected_visual_policy": String(policy.get("selected_visual_policy", "")),
		"selected_playback_policy": String(policy.get("selected_playback_policy", "")),
		"selected_blocking_policy": String(policy.get("selected_blocking_policy", "")),
		"selected_vfx_cue_ids": selected_vfx_cue_ids,
		"selected_audio_cue_ids": selected_audio_cue_ids,
		"allows_strong_flash": allows_strong_flash,
		"max_duration_ms": int(policy.get("max_duration_ms", STACK_ANIMATION_EVENT_PLAYBACK_MSEC)),
		"audio_policy": String(policy.get("audio_policy", "")),
	}

func _spell_specific_vfx_cue_ids_for_event(event: Dictionary, base_ids: Array) -> Array:
	var event_id := String(event.get("event_id", "")).strip_edges()
	if not ["battle_unit_cast", "battle_unit_hit", "battle_unit_death", "battle_status_applied", "battle_status_expired"].has(event_id):
		return base_ids.duplicate(true)
	var cue_id := _spell_specific_vfx_cue_id(String(event.get("spell_id", "")), String(event.get("resolution_type", "")))
	if cue_id == "":
		return base_ids.duplicate(true)
	return _prepend_unique_string(cue_id, base_ids)

func _spell_specific_audio_cue_ids_for_event(event: Dictionary, base_ids: Array) -> Array:
	var event_id := String(event.get("event_id", "")).strip_edges()
	if not ["battle_unit_cast", "battle_unit_hit", "battle_unit_death", "battle_status_applied", "battle_status_expired"].has(event_id):
		return base_ids.duplicate(true)
	var cue_id := _spell_specific_audio_cue_id(String(event.get("spell_id", "")), String(event.get("resolution_type", "")))
	if cue_id == "":
		return base_ids.duplicate(true)
	return _prepend_unique_string(cue_id, base_ids)

func _prepend_unique_string(value: String, items: Array) -> Array:
	var result := []
	var normalized := value.strip_edges()
	if normalized != "":
		result.append(normalized)
	for item in items:
		var item_text := String(item).strip_edges()
		if item_text != "" and not result.has(item_text):
			result.append(item_text)
	return result

func _spell_specific_vfx_cue_id(spell_id: String, resolution_type: String) -> String:
	match spell_id.strip_edges():
		"spell_cinder_burst":
			return "vfx_spell_cinder_burst"
		"spell_coal_rain":
			return "vfx_spell_coal_rain"
		"spell_sunlance_arc":
			return "vfx_spell_sunlance_arc"
		"spell_briar_bind":
			return "vfx_spell_briar_bind"
		"spell_graft_mend":
			return "vfx_spell_graft_mend"
		"spell_prism_bastion":
			return "vfx_spell_prism_bastion"
		"spell_resonant_chorus":
			return "vfx_spell_resonant_chorus"
	var family := resolution_type.strip_edges()
	match family:
		"effect":
			return "vfx_spell_command_ward"
	return ""

func _spell_specific_audio_cue_id(spell_id: String, resolution_type: String) -> String:
	match spell_id.strip_edges():
		"spell_cinder_burst":
			return "audio_spell_cinder_burst"
		"spell_coal_rain":
			return "audio_spell_coal_rain"
		"spell_sunlance_arc":
			return "audio_spell_sunlance_arc"
		"spell_briar_bind":
			return "audio_spell_briar_bind"
		"spell_graft_mend":
			return "audio_spell_graft_mend"
		"spell_prism_bastion":
			return "audio_spell_prism_bastion"
		"spell_resonant_chorus":
			return "audio_spell_resonant_chorus"
	var family := resolution_type.strip_edges()
	match family:
		"effect":
			return "audio_spell_command_ward"
	return ""

func _animation_preferences() -> Dictionary:
	return SettingsService.animation_preferences()

func _animation_state_row_for_unit(unit_id: String, state_name: String) -> int:
	var animation := ContentService.get_unit_animation(unit_id)
	var states: Array = animation.get("states", []) if animation.get("states", []) is Array else []
	for index in range(states.size()):
		if String(states[index]) == state_name:
			return index
	return 0

func _battle_terrain_id() -> String:
	var terrain_id := String(_battle.get("terrain", "plains")).strip_edges().to_lower()
	return terrain_id if terrain_id != "" else "plains"

func _terrain_color_for(terrain_id: String) -> Color:
	if TERRAIN_COLORS.has(terrain_id):
		return TERRAIN_COLORS[terrain_id]
	var texture_id := _terrain_texture_id(terrain_id)
	return TERRAIN_COLORS.get(texture_id, TERRAIN_COLORS["plains"])

func _draw_hex_grid(hex_layout: Dictionary, terrain_texture_loaded: bool) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	var distance := clampi(int(_battle.get("distance", 1)), 0, 2)
	var player_front := _front_column("player", distance)
	var enemy_front := _front_column("enemy", distance)
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			var fill := _cell_fill_color(column, player_front, enemy_front, terrain_texture_loaded)
			if terrain_texture_loaded:
				_draw_hex(center, radius * TERRAIN_HEX_TEXTURE_INSET, fill, Color(0.0, 0.0, 0.0, 0.0), 0.0)
			else:
				_draw_hex(center, radius * 0.96, fill, HEX_LINE_COLOR, 1.6)
			if column >= player_front and column <= enemy_front:
				var lane_alpha := TEXTURED_MID_LANE_FILL_ALPHA if terrain_texture_loaded else 0.035
				_draw_hex(center, radius * 0.82, Color(0.93, 0.79, 0.47, lane_alpha), Color(0.0, 0.0, 0.0, 0.0), 0.0)

	if terrain_texture_loaded:
		_draw_unique_hex_grid_lines(hex_layout, TEXTURED_HEX_LINE_COLOR, 1.05, TERRAIN_HEX_TEXTURE_INSET)

	for row in range(HEX_ROWS):
		var center_cell := Vector2i(int(HEX_COLUMNS / 2), row)
		var center_color := TEXTURED_HEX_CENTER_LINE if terrain_texture_loaded else HEX_CENTER_LINE
		var center_width := 1.1 if terrain_texture_loaded else 1.4
		_draw_hex_outline(_hex_center(center_cell, hex_layout), radius * 0.98, center_color, center_width)

func _draw_field_objectives(hex_layout: Dictionary) -> void:
	var marker_count: int = mini(_field_objectives.size(), 5)
	for index in range(marker_count):
		var objective_value = _field_objectives[index]
		if not (objective_value is Dictionary):
			continue
		var objective: Dictionary = objective_value
		var objective_type := String(objective.get("type", ""))
		var cell := _objective_cell(index, objective_type)
		var center := _hex_center(cell, hex_layout)
		var color := _controller_color(String(objective.get("control_side", "neutral")))
		_draw_objective_marker(center, objective, color, float(hex_layout.get("radius", 1.0)))

func _draw_tactical_affordances(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	if _active_stack.is_empty():
		return
	var active_id := String(_active_stack.get("battle_id", ""))
	if not stack_cells.has(active_id):
		return
	var radius := float(hex_layout.get("radius", 1.0))
	var active_cell: Vector2i = stack_cells.get(active_id)
	var active_center := _hex_center(active_cell, hex_layout)
	var player_input_active := String(_active_stack.get("side", "")) == "player"

	if player_input_active:
		for destination in BattleRulesScript.legal_destinations_for_active_stack(_battle):
			if not (destination is Dictionary):
				continue
			var cell := Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
			if not _cell_in_bounds(cell):
				continue
			_draw_hex(
				_hex_center(cell, hex_layout),
				radius * MOVE_RANGE_RADIUS_FACTOR,
				Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, MOVE_RANGE_FILL_ALPHA),
				MOVE_COLOR,
				MOVE_RANGE_OUTLINE_WIDTH
			)

	_draw_hex_outline(active_center, radius * 1.02, ACTIVE_COLOR, 3.4)

	if player_input_active:
		var legal_melee_targets: Array = BattleRulesScript.legal_attack_targets_for_active_stack(_battle, false)
		var legal_ranged_targets: Array = BattleRulesScript.legal_attack_targets_for_active_stack(_battle, true)
		for battle_id_value in legal_ranged_targets:
			var ranged_id := String(battle_id_value)
			if not stack_cells.has(ranged_id):
				continue
			_draw_hex_outline(_hex_center(stack_cells.get(ranged_id), hex_layout), radius * 0.90, LEGAL_RANGED_COLOR, 2.0)
		for battle_id_value in legal_melee_targets:
			var melee_id := String(battle_id_value)
			if not stack_cells.has(melee_id):
				continue
			_draw_hex_outline(_hex_center(stack_cells.get(melee_id), hex_layout), radius * 0.96, LEGAL_MELEE_COLOR, 2.4)

	if player_input_active and not _target_stack.is_empty():
		var target_id := String(_target_stack.get("battle_id", ""))
		if stack_cells.has(target_id):
			var target_cell: Vector2i = stack_cells.get(target_id)
			var target_center := _hex_center(target_cell, hex_layout)
			var continuity_context := BattleRulesScript.selected_target_continuity_context(_battle)
			var preserved_setup_target := not continuity_context.is_empty() and String(continuity_context.get("battle_id", "")) == target_id
			if _selected_target_is_blocked():
				_draw_hex_outline(target_center, radius * 1.02, BLOCKED_TARGET_COLOR, 3.2)
				if preserved_setup_target:
					_draw_hex_outline(target_center, radius * 1.11, BLOCKED_TARGET_COLOR.lightened(0.18), 2.0)
				_draw_blocked_target_marker(target_center, radius)
			else:
				if preserved_setup_target:
					var setup_color := LEGAL_RANGED_COLOR if String(continuity_context.get("board_click_action", "")) == "shoot" else LEGAL_MELEE_COLOR
					_draw_hex_outline(target_center, radius * 1.12, setup_color, 2.4)
				_draw_hex_outline(target_center, radius * 1.02, TARGET_COLOR, 3.2)
				_draw_focus_link(active_center, target_center, String(_active_stack.get("side", "")))

func _draw_controller_cursor(hex_layout: Dictionary) -> void:
	if not has_focus() or not _cell_in_bounds(_controller_cursor_cell):
		return
	var radius := float(hex_layout.get("radius", 1.0))
	var color := CONTROLLER_CURSOR_COLOR
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	if battle_id == "" and not _is_legal_destination_cell(_controller_cursor_cell):
		color = CONTROLLER_CURSOR_BLOCKED_COLOR
	var center := _hex_center(_controller_cursor_cell, hex_layout)
	_draw_hex_outline(center, radius * 1.13, color, 3.6)
	draw_circle(center, clampf(radius * 0.09, 2.5, 4.5), color)

func _draw_stack_tokens(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	var radius := float(hex_layout.get("radius", 1.0))
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if not stack_cells.has(battle_id):
			continue
		var cell: Vector2i = stack_cells.get(battle_id)
		var center := _stack_presentation_center(stack, cell, hex_layout, stack_cells)
		var token_radius: float = _stack_token_radius(radius)
		var side := String(stack.get("side", ""))
		var is_active := battle_id == String(_battle.get("active_stack_id", ""))
		var is_target := battle_id == String(_battle.get("selected_target_id", ""))
		var is_blocked_target := is_target and _selected_target_is_blocked()
		var fill := _side_color(side)
		if bool(stack.get("defending", false)):
			fill = fill.lightened(0.16)
		draw_circle(center + Vector2(2.0, 3.0), token_radius + 4.0, SHADOW_COLOR)
		draw_circle(center, token_radius + 3.0, ACTIVE_COLOR if is_active else (BLOCKED_TARGET_COLOR if is_blocked_target else (TARGET_COLOR if is_target else Color(0.11, 0.13, 0.15, 0.90))))
		draw_circle(center, token_radius, STACK_TOKEN_INNER_FILL)
		var side_rim := Color(fill.r, fill.g, fill.b, STACK_TOKEN_SIDE_RIM_ALPHA)
		draw_circle(center, token_radius - 1.0, side_rim, false, maxf(2.4, token_radius * STACK_TOKEN_SIDE_RIM_WIDTH_FACTOR), true)
		var animation_sheet: Texture2D = _unit_animation_sheet_for_stack(stack)
		if animation_sheet != null:
			var frame_size := token_radius * STACK_ANIMATION_ART_EXTENT_FACTOR
			var frame_rect := Rect2(center - Vector2(frame_size * 0.5, frame_size * 0.55), Vector2(frame_size, frame_size))
			draw_texture_rect_region(animation_sheet, frame_rect, _animation_frame_region_for_stack(stack), Color(1.0, 1.0, 1.0, 0.96))
		else:
			var battle_icon: Texture2D = _unit_battle_icon_for_stack(stack)
			if battle_icon != null:
				var icon_size := token_radius * STACK_ICON_ART_EXTENT_FACTOR
				var icon_rect := Rect2(center - Vector2(icon_size * 0.5, icon_size * 0.5), Vector2(icon_size, icon_size))
				draw_texture_rect(battle_icon, icon_rect, false, Color(1.0, 1.0, 1.0, 0.96))
			else:
				_draw_unit_glyph(center, token_radius, stack)
		_draw_stack_side_cue(center, token_radius, side)
		_draw_stack_health_bar(center, radius, stack)
		_draw_count_badge(center, token_radius, stack)
		_draw_stack_caption(center, radius, stack)
		_stack_hit_shapes.append(
			{
				"battle_id": battle_id,
				"side": side,
				"center": center,
				"radius": _stack_hit_shape_radius(radius),
			}
		)

func _stack_presentation_center(stack: Dictionary, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary) -> Vector2:
	var motion := _stack_presentation_motion(stack, cell, hex_layout, stack_cells)
	if motion.is_empty():
		return _hex_center(cell, hex_layout)
	return Vector2(float(motion.get("center_x", 0.0)), float(motion.get("center_y", 0.0)))

func _stack_presentation_summary(stack: Dictionary, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary) -> Dictionary:
	var center := _hex_center(cell, hex_layout)
	var summary := {
		"presentation_x": snappedf(center.x, 0.01),
		"presentation_y": snappedf(center.y, 0.01),
		"presentation_motion_active": false,
		"presentation_motion_event_id": "",
		"presentation_motion_role": "",
		"presentation_motion_source_battle_id": "",
		"presentation_motion_target_battle_id": "",
		"presentation_motion_from_q": -1,
		"presentation_motion_from_r": -1,
		"presentation_motion_to_q": -1,
		"presentation_motion_to_r": -1,
		"presentation_motion_progress": 1.0,
	}
	var motion := _stack_presentation_motion(stack, cell, hex_layout, stack_cells)
	if motion.is_empty():
		return summary
	summary["presentation_x"] = motion.get("center_x", summary.get("presentation_x"))
	summary["presentation_y"] = motion.get("center_y", summary.get("presentation_y"))
	summary["presentation_motion_active"] = true
	summary["presentation_motion_event_id"] = String(motion.get("event_id", ""))
	summary["presentation_motion_role"] = String(motion.get("role", ""))
	summary["presentation_motion_source_battle_id"] = String(motion.get("source_battle_id", ""))
	summary["presentation_motion_target_battle_id"] = String(motion.get("target_battle_id", ""))
	summary["presentation_motion_from_q"] = int(motion.get("from_q", -1))
	summary["presentation_motion_from_r"] = int(motion.get("from_r", -1))
	summary["presentation_motion_to_q"] = int(motion.get("to_q", -1))
	summary["presentation_motion_to_r"] = int(motion.get("to_r", -1))
	summary["presentation_motion_progress"] = motion.get("progress", 0.0)
	return summary

func _stack_presentation_motion(stack: Dictionary, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary) -> Dictionary:
	var battle_id := String(stack.get("battle_id", ""))
	var record := _animation_playback_record_for_stack(battle_id)
	if record.is_empty():
		return {}
	var event_id := String(record.get("event_id", ""))
	var progress := _stack_presentation_progress(battle_id)
	match event_id:
		"battle_unit_move":
			return _movement_presentation_motion(record, cell, hex_layout, progress)
		"battle_unit_melee_attack", "battle_retaliation":
			return _attack_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress, "melee_lunge")
		"battle_unit_ranged_attack":
			return _attack_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress, "ranged_recoil")
		"battle_unit_cast":
			return _attack_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress, "cast_anchor")
		"battle_unit_hit", "battle_status_applied", "battle_unit_death":
			return _impact_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress)
		"battle_status_expired":
			return _status_clear_presentation_motion(record, battle_id, cell, hex_layout, stack_cells, progress)
		"battle_unit_retreat":
			return _exit_presentation_motion(record, battle_id, cell, hex_layout, progress, "retreat_withdraw")
		"battle_unit_surrender":
			return _exit_presentation_motion(record, battle_id, cell, hex_layout, progress, "surrender_stand_down")
	return {}

func _stack_presentation_progress(battle_id: String) -> float:
	var cue_record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
	var progress := 1.0
	if not cue_record.is_empty():
		progress = _cue_playback_progress(cue_record)
		var mode := String(cue_record.get("mode", AnimationCueCatalogScript.MODE_NORMAL))
		if mode == AnimationCueCatalogScript.MODE_FAST or mode == AnimationCueCatalogScript.MODE_REDUCED_MOTION or mode == AnimationCueCatalogScript.MODE_REDUCED_MOTION_FAST:
			progress = 1.0
	return clampf(progress, 0.0, 1.0)

func _movement_presentation_motion(record: Dictionary, cell: Vector2i, hex_layout: Dictionary, progress: float) -> Dictionary:
	var from_cell := Vector2i(int(record.get("from_q", -1)), int(record.get("from_r", -1)))
	var to_cell := Vector2i(int(record.get("to_q", -1)), int(record.get("to_r", -1)))
	if not _cell_in_bounds(from_cell) or not _cell_in_bounds(to_cell):
		return {}
	if to_cell != cell:
		return {}
	var from_center := _hex_center(from_cell, hex_layout)
	var to_center := _hex_center(to_cell, hex_layout)
	var center := from_center.lerp(to_center, clampf(progress, 0.0, 1.0))
	return {
		"event_id": String(record.get("event_id", "")),
		"role": "move_path",
		"source_battle_id": String(record.get("source_battle_id", "")),
		"target_battle_id": String(record.get("target_battle_id", "")),
		"from_q": from_cell.x,
		"from_r": from_cell.y,
		"to_q": to_cell.x,
		"to_r": to_cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _attack_presentation_motion(record: Dictionary, battle_id: String, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary, progress: float, role: String) -> Dictionary:
	var target_id := String(record.get("target_battle_id", "")).strip_edges()
	if target_id == "" or not stack_cells.has(target_id):
		return {}
	var target_cell: Vector2i = stack_cells.get(target_id)
	if not _cell_in_bounds(cell) or not _cell_in_bounds(target_cell):
		return {}
	var origin := _hex_center(cell, hex_layout)
	var target := _hex_center(target_cell, hex_layout)
	var direction := (target - origin).normalized()
	if direction.length() <= 0.0:
		return {}
	var radius := float(hex_layout.get("radius", 1.0))
	var travel := 0.0
	match role:
		"melee_lunge":
			travel = sin(progress * PI) * radius * 0.34
		"ranged_recoil":
			travel = -sin(progress * PI) * radius * 0.12
		"cast_anchor":
			travel = -sin(progress * PI) * radius * 0.07
	var center := origin + direction * travel
	return {
		"event_id": String(record.get("event_id", "")),
		"role": role,
		"source_battle_id": battle_id,
		"target_battle_id": target_id,
		"from_q": cell.x,
		"from_r": cell.y,
		"to_q": target_cell.x,
		"to_r": target_cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _impact_presentation_motion(record: Dictionary, battle_id: String, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary, progress: float) -> Dictionary:
	var source_id := String(record.get("source_battle_id", "")).strip_edges()
	if source_id == "" or not stack_cells.has(source_id):
		return {}
	var source_cell: Vector2i = stack_cells.get(source_id)
	if not _cell_in_bounds(cell) or not _cell_in_bounds(source_cell):
		return {}
	var source := _hex_center(source_cell, hex_layout)
	var origin := _hex_center(cell, hex_layout)
	var direction := (origin - source).normalized()
	if direction.length() <= 0.0:
		return {}
	var radius := float(hex_layout.get("radius", 1.0))
	var event_id := String(record.get("event_id", ""))
	var role := "hit_stagger"
	var travel := (1.0 - progress) * radius * 0.18
	if event_id == "battle_status_applied":
		role = "status_pulse"
		travel = sin(progress * TAU) * radius * 0.06
	elif event_id == "battle_unit_death":
		role = "death_fall_back"
		travel = (1.0 - progress) * radius * 0.26
	var center := origin + direction * travel
	return {
		"event_id": event_id,
		"role": role,
		"source_battle_id": source_id,
		"target_battle_id": battle_id,
		"from_q": source_cell.x,
		"from_r": source_cell.y,
		"to_q": cell.x,
		"to_r": cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _status_clear_presentation_motion(record: Dictionary, battle_id: String, cell: Vector2i, hex_layout: Dictionary, stack_cells: Dictionary, progress: float) -> Dictionary:
	if not _cell_in_bounds(cell):
		return {}
	var source_id := String(record.get("source_battle_id", "")).strip_edges()
	var source_cell := cell
	if source_id != "" and stack_cells.has(source_id):
		source_cell = stack_cells.get(source_id)
	var origin := _hex_center(cell, hex_layout)
	var radius := float(hex_layout.get("radius", 1.0))
	var lift := sin(progress * PI) * radius * 0.08
	var center := origin + Vector2(0.0, -lift)
	return {
		"event_id": String(record.get("event_id", "")),
		"role": "status_clear",
		"source_battle_id": source_id,
		"target_battle_id": battle_id,
		"from_q": source_cell.x,
		"from_r": source_cell.y,
		"to_q": cell.x,
		"to_r": cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _exit_presentation_motion(record: Dictionary, battle_id: String, cell: Vector2i, hex_layout: Dictionary, progress: float, role: String) -> Dictionary:
	if not _cell_in_bounds(cell):
		return {}
	var origin := _hex_center(cell, hex_layout)
	var radius := float(hex_layout.get("radius", 1.0))
	var direction := -1.0 if String(record.get("event_id", "")) == "battle_unit_retreat" else 1.0
	var retreat_dx := direction * sin(progress * PI) * radius * 0.18
	var surrender_lift := sin(progress * PI) * radius * 0.06 if role == "surrender_stand_down" else 0.0
	var center := origin + Vector2(retreat_dx, surrender_lift)
	return {
		"event_id": String(record.get("event_id", "")),
		"role": role,
		"source_battle_id": battle_id,
		"target_battle_id": String(record.get("target_battle_id", "")),
		"from_q": cell.x,
		"from_r": cell.y,
		"to_q": cell.x,
		"to_r": cell.y,
		"center_x": snappedf(center.x, 0.01),
		"center_y": snappedf(center.y, 0.01),
		"progress": snappedf(progress, 0.001),
	}

func _draw_vfx_cues(hex_layout: Dictionary, stack_cells: Dictionary) -> void:
	for entry in _vfx_draw_entries(hex_layout, stack_cells):
		if not (entry is Dictionary):
			continue
		var start := Vector2(float(entry.get("start_x", 0.0)), float(entry.get("start_y", 0.0)))
		var end := Vector2(float(entry.get("end_x", 0.0)), float(entry.get("end_y", 0.0)))
		var center := Vector2(float(entry.get("center_x", end.x)), float(entry.get("center_y", end.y)))
		var radius := float(entry.get("hex_radius", 12.0))
		var progress := float(entry.get("progress", 0.0))
		if _draw_imported_vfx_asset(entry, start, end, center, radius, progress):
			continue
		match String(entry.get("kind", "")):
			"idle_shadow":
				_draw_idle_shadow_vfx(center, radius, progress)
			"active_ring":
				_draw_active_ring_vfx(center, radius, progress)
			"projectile_path":
				_draw_projectile_vfx(start, end, radius, progress)
			"status_residue":
				_draw_status_residue_vfx(center, radius, progress)
			"status_clear":
				_draw_status_clear_vfx(center, radius, progress)
			"damage_tick":
				_draw_damage_tick_vfx(center, radius, progress)
			"melee_arc":
				_draw_melee_arc_vfx(start, end, radius, progress)
			"retaliation_arc":
				_draw_retaliation_arc_vfx(start, end, radius, progress)
			"stack_fade":
				_draw_stack_fade_vfx(center, radius, progress)
			"cast_anchor":
				_draw_cast_anchor_vfx(center, radius, progress)
			"brace_outline":
				_draw_brace_outline_vfx(center, radius, progress)
			"surrender_marker":
				_draw_surrender_marker_vfx(center, radius, progress)
			"path_ghost":
				_draw_path_ghost_vfx(center, radius, progress)
			"spell_cinder_burst":
				_draw_spell_cinder_burst_vfx(center, radius, progress)
			"spell_coal_rain":
				_draw_spell_coal_rain_vfx(center, radius, progress)
			"spell_sunlance_arc":
				_draw_spell_sunlance_arc_vfx(start, end, radius, progress)
			"spell_briar_bind":
				_draw_spell_briar_bind_vfx(center, radius, progress)
			"spell_graft_mend":
				_draw_spell_graft_mend_vfx(center, radius, progress)
			"spell_prism_bastion":
				_draw_spell_prism_bastion_vfx(center, radius, progress)
			"spell_resonant_chorus":
				_draw_spell_resonant_chorus_vfx(center, radius, progress)
			"spell_command_ward":
				_draw_spell_command_ward_vfx(center, radius, progress)

func _draw_imported_vfx_asset(entry: Dictionary, start: Vector2, end: Vector2, center: Vector2, radius: float, progress: float) -> bool:
	var cue_id := String(entry.get("cue_id", ""))
	var spec := _battle_vfx_manifest_cue(cue_id)
	if spec.is_empty():
		return false
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var texture: Texture2D = _battle_vfx_texture_for_path(texture_path) as Texture2D
	if texture == null:
		return false
	var render_mode := String(spec.get("render_mode", ""))
	var draw_center := center
	var rotation := deg_to_rad(float(spec.get("base_rotation_degrees", 0.0)))
	match render_mode:
		"projectile":
			if start.distance_to(end) > 1.0:
				var direction := (end - start).normalized()
				var head := start.lerp(end, clampf(progress, 0.08, 0.96))
				draw_center = head - direction * radius * 0.16
				rotation += direction.angle()
		"spell_projectile":
			if start.distance_to(end) > 1.0:
				var direction := (end - start).normalized()
				draw_center = start.lerp(end, clampf(progress, 0.12, 0.94))
				rotation += direction.angle()
		"slash":
			if start.distance_to(end) > 1.0:
				draw_center = start.lerp(end, 0.52)
				rotation += (end - start).angle()
		"impact":
			rotation += progress * TAU * 0.10
		"ward":
			rotation += progress * TAU * 0.08
		"spell_target":
			draw_center = end
			rotation += progress * TAU * 0.04
		"state_center":
			draw_center = center
			rotation += progress * TAU * 0.025
		"state_marker":
			draw_center = center + Vector2(radius * 0.38, -radius * 0.42)
		"path_follow":
			draw_center = center
			if start.distance_to(end) > 1.0:
				rotation += (end - start).angle()
		_:
			return false
	var draw_size := radius * float(spec.get("scale", 1.0))
	var alpha := clampf(0.82 - progress * 0.30, 0.42, 0.82)
	draw_set_transform(draw_center, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(Vector2(-draw_size, -draw_size) * 0.5, Vector2(draw_size, draw_size)), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

func _vfx_draw_entries(hex_layout: Dictionary, stack_cells: Dictionary) -> Array:
	var entries: Array = []
	var radius := float(hex_layout.get("radius", 1.0))
	for battle_id_value in _stack_animation_cue_playback_records.keys():
		var battle_id := String(battle_id_value)
		var record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
		var cue_ids: Array = record.get("selected_vfx_cue_ids", []) if record.get("selected_vfx_cue_ids", []) is Array else []
		if cue_ids.is_empty() or not stack_cells.has(battle_id):
			continue
		var subject_cell: Vector2i = stack_cells.get(battle_id)
		if not _cell_in_bounds(subject_cell):
			continue
		var source_id := String(record.get("source_battle_id", "")).strip_edges()
		if source_id == "":
			source_id = battle_id
		var target_id := String(record.get("target_battle_id", "")).strip_edges()
		if target_id == "":
			target_id = battle_id
		var source_cell: Vector2i = stack_cells.get(source_id, subject_cell)
		var target_cell: Vector2i = stack_cells.get(target_id, subject_cell)
		var has_event_path := _cell_in_bounds(Vector2i(int(record.get("from_q", -1)), int(record.get("from_r", -1)))) and _cell_in_bounds(Vector2i(int(record.get("to_q", -1)), int(record.get("to_r", -1))))
		if has_event_path:
			source_cell = Vector2i(int(record.get("from_q", -1)), int(record.get("from_r", -1)))
			target_cell = Vector2i(int(record.get("to_q", -1)), int(record.get("to_r", -1)))
		var source_center := _hex_center(source_cell, hex_layout)
		var target_center := _hex_center(target_cell, hex_layout)
		var subject_center := _hex_center(subject_cell, hex_layout)
		var progress := _cue_playback_progress(record)
		for cue_id_value in cue_ids:
			var cue_id := String(cue_id_value)
			var kind := _vfx_kind_for_cue_id(cue_id)
			if kind == "":
				continue
			var start := source_center
			var end := target_center
			var center := subject_center
			if kind == "projectile_path" or kind == "melee_arc" or kind == "retaliation_arc":
				start = subject_center
				end = target_center
				center = target_center
			elif kind == "path_ghost" and has_event_path:
				start = source_center
				end = target_center
				center = source_center.lerp(target_center, progress)
			elif source_id != "" and stack_cells.has(source_id):
				start = source_center
			var asset_spec := _battle_vfx_manifest_cue(cue_id)
			var asset_path := String(asset_spec.get("texture_path", "")).strip_edges()
			var asset_loaded := asset_path != "" and _battle_vfx_texture_for_path(asset_path) != null
			entries.append({
				"cue_id": cue_id,
				"kind": kind,
				"battle_id": battle_id,
				"event_id": String(record.get("event_id", "")),
				"serial": int(record.get("serial", 0)),
				"source_battle_id": source_id,
				"target_battle_id": target_id,
				"start_q": source_cell.x,
				"start_r": source_cell.y,
				"target_q": target_cell.x,
				"target_r": target_cell.y,
				"subject_q": subject_cell.x,
				"subject_r": subject_cell.y,
				"start_x": snappedf(start.x, 0.01),
				"start_y": snappedf(start.y, 0.01),
				"end_x": snappedf(end.x, 0.01),
				"end_y": snappedf(end.y, 0.01),
				"center_x": snappedf(center.x, 0.01),
				"center_y": snappedf(center.y, 0.01),
				"hex_radius": snappedf(radius, 0.01),
				"progress": snappedf(progress, 0.001),
				"asset_path": asset_path,
				"asset_render_mode": String(asset_spec.get("render_mode", "")),
				"asset_loaded": asset_loaded,
			})
	return entries

func _vfx_kind_for_cue_id(cue_id: String) -> String:
	match cue_id:
		"vfx_placeholder_idle_shadow":
			return "idle_shadow"
		"vfx_placeholder_active_ring":
			return "active_ring"
		"vfx_placeholder_projectile_path":
			return "projectile_path"
		"vfx_placeholder_status_residue":
			return "status_residue"
		"vfx_placeholder_status_clear":
			return "status_clear"
		"vfx_placeholder_damage_tick":
			return "damage_tick"
		"vfx_placeholder_melee_arc":
			return "melee_arc"
		"vfx_placeholder_retaliation_arc":
			return "retaliation_arc"
		"vfx_placeholder_stack_fade":
			return "stack_fade"
		"vfx_placeholder_cast_anchor":
			return "cast_anchor"
		"vfx_placeholder_brace_outline":
			return "brace_outline"
		"vfx_placeholder_surrender_marker":
			return "surrender_marker"
		"vfx_placeholder_battle_path_ghost", "vfx_placeholder_withdraw_path":
			return "path_ghost"
		"vfx_spell_cinder_burst":
			return "spell_cinder_burst"
		"vfx_spell_coal_rain":
			return "spell_coal_rain"
		"vfx_spell_sunlance_arc":
			return "spell_sunlance_arc"
		"vfx_spell_briar_bind":
			return "spell_briar_bind"
		"vfx_spell_graft_mend":
			return "spell_graft_mend"
		"vfx_spell_prism_bastion":
			return "spell_prism_bastion"
		"vfx_spell_resonant_chorus":
			return "spell_resonant_chorus"
		"vfx_spell_command_ward":
			return "spell_command_ward"
	return ""

func _cue_playback_progress(record: Dictionary) -> float:
	var started := int(record.get("started_at_msec", Time.get_ticks_msec()))
	var duration := maxi(1, int(record.get("max_duration_ms", STACK_ANIMATION_EVENT_PLAYBACK_MSEC)))
	return clampf(float(Time.get_ticks_msec() - started) / float(duration), 0.0, 1.0)

func _draw_idle_shadow_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.12, 0.28 - progress * 0.08)
	draw_circle(center + Vector2(0.0, radius * 0.24), radius * 0.32, Color(0.02, 0.025, 0.03, alpha))

func _draw_active_ring_vfx(center: Vector2, radius: float, progress: float) -> void:
	var pulse := 0.88 + sin(progress * TAU) * 0.05
	draw_circle(center, radius * pulse, Color(ACTIVE_COLOR.r, ACTIVE_COLOR.g, ACTIVE_COLOR.b, 0.42), false, maxf(2.0, radius * 0.05), true)

func _draw_projectile_vfx(start: Vector2, end: Vector2, radius: float, progress: float) -> void:
	if start.distance_to(end) <= 1.0:
		return
	var alpha := maxf(0.20, 1.0 - progress * 0.42)
	var color := Color(BATTLE_VFX_PROJECTILE_COLOR.r, BATTLE_VFX_PROJECTILE_COLOR.g, BATTLE_VFX_PROJECTILE_COLOR.b, BATTLE_VFX_PROJECTILE_COLOR.a * alpha)
	var head := start.lerp(end, clampf(progress, 0.08, 0.96))
	var tail := start.lerp(end, clampf(progress - 0.16, 0.0, 0.84))
	draw_line(start, end, Color(color.r, color.g, color.b, 0.22), maxf(1.6, radius * 0.045), true)
	draw_line(tail, head, color, maxf(2.4, radius * 0.075), true)
	draw_circle(head, maxf(3.0, radius * 0.105), Color(color.r, color.g, color.b, 0.94))

func _draw_status_residue_vfx(center: Vector2, radius: float, progress: float) -> void:
	var pulse := 1.0 + sin(progress * TAU) * 0.10
	var alpha := maxf(0.18, 1.0 - progress * 0.35)
	var color := Color(BATTLE_VFX_STATUS_COLOR.r, BATTLE_VFX_STATUS_COLOR.g, BATTLE_VFX_STATUS_COLOR.b, BATTLE_VFX_STATUS_COLOR.a * alpha)
	draw_circle(center, radius * 0.58 * pulse, Color(color.r, color.g, color.b, 0.08), true)
	draw_circle(center, radius * 0.70 * pulse, color, false, maxf(1.8, radius * 0.045), true)
	for index in range(3):
		var angle := progress * TAU + float(index) * TAU / 3.0
		var pip := center + Vector2(cos(angle), sin(angle)) * radius * 0.46
		draw_circle(pip, maxf(2.4, radius * 0.055), Color(color.r, color.g, color.b, 0.86))

func _draw_status_clear_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.12, 1.0 - progress)
	var color := Color(0.72, 0.88, 1.0, 0.72 * alpha)
	var inner := radius * (0.24 + progress * 0.14)
	var outer := radius * (0.64 + progress * 0.24)
	draw_circle(center, outer, Color(color.r, color.g, color.b, 0.06), true)
	draw_circle(center, outer, color, false, maxf(1.6, radius * 0.04), true)
	draw_line(center + Vector2(-inner, 0.0), center + Vector2(inner, 0.0), color, maxf(1.6, radius * 0.045), true)
	draw_line(center + Vector2(0.0, -inner), center + Vector2(0.0, inner), color, maxf(1.6, radius * 0.045), true)

func _draw_damage_tick_vfx(center: Vector2, radius: float, progress: float) -> void:
	var span := radius * (0.26 + progress * 0.18)
	var alpha := maxf(0.18, 1.0 - progress * 0.45)
	var color := Color(BATTLE_VFX_DAMAGE_COLOR.r, BATTLE_VFX_DAMAGE_COLOR.g, BATTLE_VFX_DAMAGE_COLOR.b, BATTLE_VFX_DAMAGE_COLOR.a * alpha)
	draw_line(center + Vector2(-span, -span * 0.40), center + Vector2(span, span * 0.40), color, maxf(2.0, radius * 0.06), true)
	draw_line(center + Vector2(span * 0.32, -span), center + Vector2(-span * 0.32, span), color, maxf(1.8, radius * 0.05), true)

func _draw_melee_arc_vfx(start: Vector2, end: Vector2, radius: float, progress: float) -> void:
	var direction := (end - start).normalized() if start.distance_to(end) > 1.0 else Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var center := start.lerp(end, 0.55) + normal * radius * 0.18
	var alpha := maxf(0.20, 1.0 - progress * 0.55)
	var color := Color(BATTLE_VFX_DAMAGE_COLOR.r, BATTLE_VFX_DAMAGE_COLOR.g, BATTLE_VFX_DAMAGE_COLOR.b, 0.72 * alpha)
	draw_line(start.lerp(center, 0.35), center, color, maxf(2.4, radius * 0.07), true)
	draw_line(center, end.lerp(center, 0.35), color, maxf(2.4, radius * 0.07), true)

func _draw_retaliation_arc_vfx(start: Vector2, end: Vector2, radius: float, progress: float) -> void:
	var direction := (end - start).normalized() if start.distance_to(end) > 1.0 else Vector2.LEFT
	var normal := Vector2(direction.y, -direction.x)
	var center := start.lerp(end, 0.48) + normal * radius * 0.24
	var alpha := maxf(0.18, 1.0 - progress * 0.60)
	var color := Color(1.0, 0.76, 0.42, 0.74 * alpha)
	draw_line(start.lerp(center, 0.30), center, color, maxf(2.2, radius * 0.065), true)
	draw_line(center, end.lerp(center, 0.30), color, maxf(2.2, radius * 0.065), true)

func _draw_stack_fade_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.10, 1.0 - progress)
	draw_circle(center, radius * (0.44 + progress * 0.38), Color(0.86, 0.88, 0.92, 0.34 * alpha), false, maxf(2.0, radius * 0.055), true)
	draw_circle(center, radius * 0.22, Color(0.08, 0.09, 0.10, 0.18 * alpha), true)

func _draw_cast_anchor_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.35)
	var color := Color(BATTLE_VFX_CAST_COLOR.r, BATTLE_VFX_CAST_COLOR.g, BATTLE_VFX_CAST_COLOR.b, BATTLE_VFX_CAST_COLOR.a * alpha)
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.74),
		center + Vector2(radius * 0.54, 0.0),
		center + Vector2(0.0, radius * 0.74),
		center + Vector2(-radius * 0.54, 0.0),
		center + Vector2(0.0, -radius * 0.74),
	])
	draw_polyline(points, color, maxf(1.8, radius * 0.045), true)
	draw_circle(center, radius * 0.18, Color(color.r, color.g, color.b, 0.38), true)

func _draw_brace_outline_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.50)
	var color := Color(0.76, 0.88, 1.0, 0.58 * alpha)
	draw_circle(center, radius * 0.68, color, false, maxf(2.0, radius * 0.055), true)
	draw_arc(center, radius * 0.48, PI * 0.12, PI * 0.88, 12, color, maxf(2.0, radius * 0.055), true)

func _draw_surrender_marker_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.55)
	var color := Color(0.92, 0.92, 0.86, 0.70 * alpha)
	var pole_top := center + Vector2(0.0, -radius * 0.44)
	var pole_bottom := center + Vector2(0.0, radius * 0.30)
	draw_line(pole_top, pole_bottom, color, maxf(1.8, radius * 0.04), true)
	var flag := PackedVector2Array([
		pole_top,
		pole_top + Vector2(radius * 0.34, radius * 0.10),
		pole_top + Vector2(0.0, radius * 0.22),
	])
	draw_colored_polygon(flag, Color(color.r, color.g, color.b, 0.42 * alpha))

func _draw_path_ghost_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.60)
	_draw_hex(center, radius * (0.50 + progress * 0.16), Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, 0.08 * alpha), Color(MOVE_COLOR.r, MOVE_COLOR.g, MOVE_COLOR.b, 0.48 * alpha), maxf(1.6, radius * 0.04))

func _draw_spell_cinder_burst_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.14, 1.0 - progress * 0.72)
	var flare := Color(1.0, 0.42, 0.16, 0.72 * alpha)
	draw_circle(center, radius * (0.26 + progress * 0.34), Color(flare.r, flare.g, flare.b, 0.14 * alpha), true)
	for index in range(6):
		var angle := progress * TAU * 0.35 + float(index) * TAU / 6.0
		var inner := center + Vector2(cos(angle), sin(angle)) * radius * 0.18
		var outer := center + Vector2(cos(angle), sin(angle)) * radius * (0.52 + progress * 0.20)
		draw_line(inner, outer, flare, maxf(1.8, radius * 0.045), true)

func _draw_spell_coal_rain_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.62)
	for index in range(5):
		var lane := (float(index) - 2.0) * radius * 0.16
		var head := center + Vector2(lane, -radius * 0.56 + radius * progress * 0.82)
		var tail := head + Vector2(-radius * 0.14, -radius * 0.22)
		draw_line(tail, head, Color(0.92, 0.32, 0.18, 0.76 * alpha), maxf(1.8, radius * 0.045), true)
		draw_circle(head, maxf(2.2, radius * 0.05), Color(0.12, 0.10, 0.08, 0.72 * alpha))

func _draw_spell_sunlance_arc_vfx(start: Vector2, end: Vector2, radius: float, progress: float) -> void:
	var source := start if start.distance_to(end) > 1.0 else end + Vector2(-radius, 0.0)
	var alpha := maxf(0.18, 1.0 - progress * 0.46)
	var head := source.lerp(end, clampf(progress, 0.12, 1.0))
	draw_line(source, end, Color(1.0, 0.90, 0.46, 0.24 * alpha), maxf(2.0, radius * 0.05), true)
	draw_line(source.lerp(head, 0.38), head, Color(1.0, 0.78, 0.24, 0.86 * alpha), maxf(2.8, radius * 0.08), true)
	draw_circle(head, maxf(3.0, radius * 0.08), Color(1.0, 0.96, 0.58, 0.82 * alpha))

func _draw_spell_briar_bind_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.58)
	var color := Color(0.36, 0.74, 0.40, 0.78 * alpha)
	draw_arc(center, radius * (0.34 + progress * 0.16), PI * 0.10, PI * 1.78, 18, color, maxf(2.0, radius * 0.052), true)
	draw_arc(center, radius * (0.50 + progress * 0.10), PI * 1.08, PI * 2.78, 18, color, maxf(1.8, radius * 0.046), true)
	for index in range(3):
		var angle := float(index) * TAU / 3.0 + progress * 0.8
		draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.24, center + Vector2(cos(angle), sin(angle)) * radius * 0.62, color, maxf(1.6, radius * 0.04), true)

func _draw_spell_graft_mend_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.54)
	var color := Color(0.58, 1.0, 0.70, 0.74 * alpha)
	var span := radius * (0.22 + progress * 0.10)
	draw_circle(center, radius * (0.46 + progress * 0.12), Color(color.r, color.g, color.b, 0.08 * alpha), true)
	draw_line(center + Vector2(-span, 0.0), center + Vector2(span, 0.0), color, maxf(2.2, radius * 0.06), true)
	draw_line(center + Vector2(0.0, -span), center + Vector2(0.0, span), color, maxf(2.2, radius * 0.06), true)

func _draw_spell_prism_bastion_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.50)
	var color := Color(0.66, 0.90, 1.0, 0.72 * alpha)
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.62),
		center + Vector2(radius * 0.48, -radius * 0.10),
		center + Vector2(radius * 0.32, radius * 0.54),
		center + Vector2(-radius * 0.32, radius * 0.54),
		center + Vector2(-radius * 0.48, -radius * 0.10),
		center + Vector2(0.0, -radius * 0.62),
	])
	draw_polyline(points, color, maxf(1.9, radius * 0.05), true)
	draw_circle(center, radius * (0.18 + progress * 0.10), Color(color.r, color.g, color.b, 0.18 * alpha), true)

func _draw_spell_resonant_chorus_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.16, 1.0 - progress * 0.48)
	var gold := Color(1.0, 0.82, 0.34, 0.76 * alpha)
	var glass := Color(0.70, 0.94, 1.0, 0.68 * alpha)
	var pulse := 0.32 + progress * 0.16
	for ring_index in range(3):
		var ring_radius := radius * (pulse + float(ring_index) * 0.14)
		var color := gold if ring_index % 2 == 0 else glass
		draw_arc(center, ring_radius, -PI * 0.94, PI * 0.94, 28, color, maxf(1.8, radius * 0.045), true)
	for shard_index in range(6):
		var angle := float(shard_index) * TAU / 6.0 - PI * 0.5 + progress * 0.20
		var shard_start := center + Vector2(cos(angle), sin(angle)) * radius * 0.42
		var shard_end := center + Vector2(cos(angle), sin(angle)) * radius * 0.64
		draw_line(shard_start, shard_end, glass, maxf(1.7, radius * 0.04), true)
	draw_circle(center, radius * (0.13 + progress * 0.06), Color(gold.r, gold.g, gold.b, 0.22 * alpha), true)

func _draw_spell_command_ward_vfx(center: Vector2, radius: float, progress: float) -> void:
	var alpha := maxf(0.18, 1.0 - progress * 0.44)
	var color := Color(1.0, 0.84, 0.42, 0.72 * alpha)
	draw_circle(center, radius * (0.58 + progress * 0.10), Color(color.r, color.g, color.b, 0.06 * alpha), true)
	draw_arc(center, radius * 0.60, PI * 0.08, PI * 0.92, 14, color, maxf(2.0, radius * 0.05), true)
	draw_arc(center, radius * 0.60, PI * 1.08, PI * 1.92, 14, color, maxf(2.0, radius * 0.05), true)

func _register_audio_cue_playback(cue_record: Dictionary) -> void:
	var battle_id := String(cue_record.get("battle_id", "")).strip_edges()
	if battle_id == "":
		return
	var audio_ids: Array = cue_record.get("selected_audio_cue_ids", []) if cue_record.get("selected_audio_cue_ids", []) is Array else []
	if audio_ids.is_empty():
		_stack_animation_audio_playback_records.erase(battle_id)
		return
	var now := int(Time.get_ticks_msec())
	var started_at := int(cue_record.get("started_at_msec", now))
	if started_at > now:
		_stack_animation_audio_playback_records[battle_id] = {
			"battle_id": battle_id,
			"event_id": String(cue_record.get("event_id", "")),
			"serial": int(cue_record.get("serial", 0)),
			"cue_id": String(cue_record.get("cue_id", "")),
			"selected_audio_cue_ids": audio_ids.duplicate(true),
			"generated_waveform_count": 0,
			"imported_asset_count": 0,
			"generated_fallback_count": 0,
			"generated_waveforms": [],
			"imported_assets": [],
			"asset_playbacks": [],
			"started_at_msec": started_at,
			"expires_at_msec": int(cue_record.get("expires_at_msec", started_at + STACK_ANIMATION_EVENT_PLAYBACK_MSEC)),
			"sequence_delay_msec": int(cue_record.get("sequence_delay_msec", 0)),
			"audio_bus": BATTLE_AUDIO_BUS,
			"muted": SettingsService.effects_audio_muted(),
			"scheduled": true,
		}
		return
	var generated_records := []
	var imported_records := []
	var suppressed_records := []
	var asset_records := []
	for audio_id_value in audio_ids:
		var audio_id := String(audio_id_value).strip_edges()
		if audio_id == "":
			continue
		var playback := _play_audio_cue(audio_id, battle_id, int(cue_record.get("serial", 0)))
		if playback.is_empty():
			continue
		asset_records.append(playback)
		match String(playback.get("source", "")):
			"imported_wav":
				imported_records.append(playback)
			"generated_waveform":
				generated_records.append(playback)
			"suppressed":
				suppressed_records.append(playback)
	_stack_animation_audio_playback_records[battle_id] = {
		"battle_id": battle_id,
		"event_id": String(cue_record.get("event_id", "")),
		"serial": int(cue_record.get("serial", 0)),
		"cue_id": String(cue_record.get("cue_id", "")),
		"selected_audio_cue_ids": audio_ids.duplicate(true),
		"generated_waveform_count": generated_records.size(),
		"imported_asset_count": imported_records.size(),
		"generated_fallback_count": generated_records.size(),
		"played_audio_cue_count": imported_records.size() + generated_records.size(),
		"suppressed_audio_cue_count": suppressed_records.size(),
		"generated_waveforms": generated_records,
		"imported_assets": imported_records,
		"suppressed_cues": suppressed_records,
		"asset_playbacks": asset_records,
		"started_at_msec": int(cue_record.get("started_at_msec", Time.get_ticks_msec())),
		"expires_at_msec": int(cue_record.get("expires_at_msec", Time.get_ticks_msec() + STACK_ANIMATION_EVENT_PLAYBACK_MSEC)),
		"sequence_delay_msec": int(cue_record.get("sequence_delay_msec", 0)),
		"audio_bus": BATTLE_AUDIO_BUS,
		"muted": SettingsService.effects_audio_muted(),
		"scheduled": false,
	}

func _play_audio_cue(audio_id: String, battle_id: String, serial: int) -> Dictionary:
	var admission := _audio_mix_admission(audio_id)
	if not bool(admission.get("allowed", false)):
		return {
			"audio_id": audio_id,
			"source": "suppressed",
			"played": false,
			"priority_class": String(admission.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)),
			"priority": int(admission.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS])),
			"repeat_cooldown_msec": int(admission.get("repeat_cooldown_msec", BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC)),
			"effective_voice_budget": int(admission.get("effective_voice_budget", BATTLE_AUDIO_MAX_ACTIVE_PLAYERS)),
			"reduced_repetitive_sounds": bool(admission.get("reduced_repetitive_sounds", false)),
			"suppressed_reason": String(admission.get("reason", "mix_policy")),
		}
	var imported := _play_imported_audio_cue(audio_id, battle_id, serial, admission)
	if not imported.is_empty():
		_record_audio_cue_started(audio_id, imported, admission)
		return imported
	var generated := _play_generated_audio_cue(audio_id, battle_id, serial, admission)
	if not generated.is_empty():
		generated["source"] = "generated_waveform"
		_record_audio_cue_started(audio_id, generated, admission)
	return generated

func _play_imported_audio_cue(audio_id: String, battle_id: String, serial: int, mix_policy: Dictionary) -> Dictionary:
	var cue := _battle_sfx_manifest_cue(audio_id)
	if cue.is_empty():
		return {}
	var path := String(cue.get("path", "")).strip_edges()
	if path == "":
		return {}
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is AudioStream:
			stream = resource
	if stream == null and FileAccess.file_exists(path):
		var wav_stream := AudioStreamWAV.load_from_file(path)
		if wav_stream is AudioStream:
			stream = wav_stream
	if stream == null:
		return {}
	var duration_msec := int(cue.get("duration_msec", 120))
	var stream_length := stream.get_length()
	if stream_length > 0.0:
		duration_msec = maxi(1, int(ceil(stream_length * 1000.0)))
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SettingsService.effects_audio_bus_name()
	player.volume_db = float(cue.get("volume_db", -12.0))
	add_child(player)
	_active_audio_players.append({
		"player": player,
		"battle_id": battle_id,
		"audio_id": audio_id,
		"source": "imported_wav",
		"asset_path": path,
		"serial": serial,
		"priority_class": String(mix_policy.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)),
		"priority": int(mix_policy.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS])),
		"started_at_msec": int(Time.get_ticks_msec()),
		"expires_at_msec": int(Time.get_ticks_msec()) + duration_msec + 180,
	})
	_trim_audio_players()
	player.play()
	return {
		"audio_id": audio_id,
		"source": "imported_wav",
		"asset_path": path,
		"role": String(cue.get("role", "")),
		"duration_msec": duration_msec,
		"volume_db": float(cue.get("volume_db", -12.0)),
		"played": true,
		"player_created": true,
	}

func _play_generated_audio_cue(audio_id: String, battle_id: String, serial: int, mix_policy: Dictionary) -> Dictionary:
	var spec := _audio_cue_wave_spec(audio_id)
	if spec.is_empty():
		return {}
	var duration_msec := int(spec.get("duration_msec", 120))
	var frame_count := maxi(1, int(BATTLE_AUDIO_SAMPLE_RATE * float(duration_msec) / 1000.0))
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = BATTLE_AUDIO_SAMPLE_RATE
	stream.buffer_length = maxf(0.05, float(duration_msec) / 1000.0 + 0.04)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SettingsService.effects_audio_bus_name()
	player.volume_db = float(spec.get("volume_db", -12.0))
	add_child(player)
	_active_audio_players.append({
		"player": player,
		"battle_id": battle_id,
		"audio_id": audio_id,
		"serial": serial,
		"priority_class": String(mix_policy.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)),
		"priority": int(mix_policy.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS])),
		"started_at_msec": int(Time.get_ticks_msec()),
		"expires_at_msec": int(Time.get_ticks_msec()) + duration_msec + 180,
	})
	_trim_audio_players()
	player.play()
	var playback = player.get_stream_playback()
	if playback is AudioStreamGeneratorPlayback:
		_push_generated_audio_frames(playback, spec, frame_count)
	return {
		"audio_id": audio_id,
		"waveform": String(spec.get("waveform", "sine")),
		"frequency_hz": float(spec.get("frequency_hz", 440.0)),
		"secondary_frequency_hz": float(spec.get("secondary_frequency_hz", 0.0)),
		"duration_msec": duration_msec,
		"frame_count": frame_count,
		"played": true,
		"player_created": true,
	}

func _audio_mix_admission(audio_id: String) -> Dictionary:
	var policy := _audio_mix_policy(audio_id)
	var priority := int(policy.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS]))
	var priority_class := String(policy.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS))
	var cooldown_msec := int(policy.get("repeat_cooldown_msec", BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC))
	var voice_budget := _effective_battle_audio_voice_budget()
	var reduced_repetition := SettingsService.reduced_repetitive_sounds_enabled()
	if SettingsService.effects_audio_muted():
		_record_audio_cue_suppressed("effects_muted")
		return {"allowed": false, "reason": "effects_muted", "priority": priority, "priority_class": priority_class, "repeat_cooldown_msec": cooldown_msec, "effective_voice_budget": voice_budget, "reduced_repetitive_sounds": reduced_repetition}
	_cleanup_audio_players()
	while _active_audio_players.size() > voice_budget:
		_evict_audio_voice(_audio_eviction_candidate_index())
	var now := int(Time.get_ticks_msec())
	var last_started := int(_audio_last_started_msec_by_cue.get(audio_id, -1000000000))
	if cooldown_msec > 0 and now - last_started < cooldown_msec:
		_record_audio_cue_suppressed("repeat_cooldown")
		return {"allowed": false, "reason": "repeat_cooldown", "priority": priority, "priority_class": priority_class, "repeat_cooldown_msec": cooldown_msec, "effective_voice_budget": voice_budget, "reduced_repetitive_sounds": reduced_repetition}
	var evicted := {}
	if _active_audio_players.size() >= voice_budget:
		var candidate_index := _audio_eviction_candidate_index()
		var candidate: Dictionary = _active_audio_players[candidate_index] if candidate_index >= 0 and _active_audio_players[candidate_index] is Dictionary else {}
		if candidate.is_empty() or priority <= int(candidate.get("priority", 0)):
			_record_audio_cue_suppressed("voice_budget")
			return {"allowed": false, "reason": "voice_budget", "priority": priority, "priority_class": priority_class, "repeat_cooldown_msec": cooldown_msec, "effective_voice_budget": voice_budget, "reduced_repetitive_sounds": reduced_repetition}
		evicted = _evict_audio_voice(candidate_index)
	return {
		"allowed": true,
		"priority": priority,
		"priority_class": priority_class,
		"repeat_cooldown_msec": cooldown_msec,
		"effective_voice_budget": voice_budget,
		"reduced_repetitive_sounds": reduced_repetition,
		"evicted_audio_id": String(evicted.get("audio_id", "")),
		"evicted_priority_class": String(evicted.get("priority_class", "")),
	}

func _audio_mix_policy(audio_id: String) -> Dictionary:
	var cue := _battle_sfx_manifest_cue(audio_id)
	var priority_class := String(cue.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)).strip_edges()
	if not BATTLE_AUDIO_PRIORITY_VALUES.has(priority_class):
		priority_class = BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS
	var repeat_cooldown_msec := maxi(0, int(cue.get("repeat_cooldown_msec", BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC)))
	if SettingsService.reduced_repetitive_sounds_enabled():
		repeat_cooldown_msec *= BATTLE_AUDIO_REDUCED_REPETITION_COOLDOWN_MULTIPLIER
	return {
		"priority_class": priority_class,
		"priority": int(BATTLE_AUDIO_PRIORITY_VALUES[priority_class]),
		"repeat_cooldown_msec": repeat_cooldown_msec,
	}

func _effective_battle_audio_voice_budget() -> int:
	return BATTLE_AUDIO_REDUCED_REPETITION_MAX_ACTIVE_PLAYERS if SettingsService.reduced_repetitive_sounds_enabled() else BATTLE_AUDIO_MAX_ACTIVE_PLAYERS

func _audio_eviction_candidate_index() -> int:
	var candidate_index := -1
	var candidate_priority := 1000000
	var candidate_started_at := 1000000000000
	for index in range(_active_audio_players.size()):
		var entry: Dictionary = _active_audio_players[index] if _active_audio_players[index] is Dictionary else {}
		if entry.is_empty():
			continue
		var priority := int(entry.get("priority", 0))
		var started_at := int(entry.get("started_at_msec", 0))
		if priority < candidate_priority or (priority == candidate_priority and started_at < candidate_started_at):
			candidate_index = index
			candidate_priority = priority
			candidate_started_at = started_at
	return candidate_index

func _evict_audio_voice(index: int) -> Dictionary:
	if index < 0 or index >= _active_audio_players.size():
		return {}
	var entry = _active_audio_players.pop_at(index)
	if entry is Dictionary:
		var player = entry.get("player", null)
		if player is AudioStreamPlayer and is_instance_valid(player):
			player.queue_free()
		_audio_mix_counters["evicted"] = int(_audio_mix_counters.get("evicted", 0)) + 1
		return entry.duplicate(true)
	return {}

func _record_audio_cue_started(audio_id: String, playback: Dictionary, admission: Dictionary) -> void:
	_audio_last_started_msec_by_cue[audio_id] = int(Time.get_ticks_msec())
	_audio_mix_counters["played"] = int(_audio_mix_counters.get("played", 0)) + 1
	playback["priority_class"] = String(admission.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS))
	playback["priority"] = int(admission.get("priority", BATTLE_AUDIO_PRIORITY_VALUES[BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS]))
	playback["repeat_cooldown_msec"] = int(admission.get("repeat_cooldown_msec", BATTLE_AUDIO_DEFAULT_REPEAT_COOLDOWN_MSEC))
	playback["effective_voice_budget"] = int(admission.get("effective_voice_budget", BATTLE_AUDIO_MAX_ACTIVE_PLAYERS))
	playback["reduced_repetitive_sounds"] = bool(admission.get("reduced_repetitive_sounds", false))
	playback["evicted_audio_id"] = String(admission.get("evicted_audio_id", ""))
	playback["evicted_priority_class"] = String(admission.get("evicted_priority_class", ""))

func _record_audio_cue_suppressed(reason: String) -> void:
	_audio_mix_counters["suppressed"] = int(_audio_mix_counters.get("suppressed", 0)) + 1
	var reasons: Dictionary = _audio_mix_counters.get("suppressed_by_reason", {}) if _audio_mix_counters.get("suppressed_by_reason", {}) is Dictionary else {}
	reasons[reason] = int(reasons.get(reason, 0)) + 1
	_audio_mix_counters["suppressed_by_reason"] = reasons

func _active_audio_voice_mix() -> Array:
	_cleanup_audio_players()
	var result := []
	for entry in _active_audio_players:
		if entry is Dictionary:
			result.append({
				"audio_id": String(entry.get("audio_id", "")),
				"battle_id": String(entry.get("battle_id", "")),
				"priority_class": String(entry.get("priority_class", BATTLE_AUDIO_DEFAULT_PRIORITY_CLASS)),
				"priority": int(entry.get("priority", 0)),
				"source": String(entry.get("source", "generated_waveform")),
			})
	return result

func _battle_sfx_manifest_cue(audio_id: String) -> Dictionary:
	_load_battle_sfx_manifest()
	var cues: Dictionary = _battle_sfx_manifest.get("cues", {}) if _battle_sfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(audio_id, {}) if cues.get(audio_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _battle_vfx_manifest_cue(cue_id: String) -> Dictionary:
	_load_battle_vfx_manifest()
	var cues: Dictionary = _battle_vfx_manifest.get("cues", {}) if _battle_vfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _load_battle_vfx_manifest() -> void:
	if _battle_vfx_manifest_loaded:
		return
	_battle_vfx_manifest_loaded = true
	_battle_vfx_manifest = {}
	_battle_vfx_textures.clear()
	_battle_vfx_texture_missing.clear()
	if not FileAccess.file_exists(BATTLE_VFX_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(BATTLE_VFX_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_battle_vfx_manifest = parsed

func _battle_vfx_texture_for_path(texture_path: String):
	if texture_path == "" or _battle_vfx_texture_missing.has(texture_path):
		return null
	if _battle_vfx_textures.has(texture_path):
		return _battle_vfx_textures.get(texture_path)
	if not ResourceLoader.exists(texture_path):
		_battle_vfx_texture_missing[texture_path] = true
		return null
	var loaded = load(texture_path)
	if loaded is Texture2D:
		_battle_vfx_textures[texture_path] = loaded
		return loaded
	_battle_vfx_texture_missing[texture_path] = true
	return null

func _load_battle_sfx_manifest() -> void:
	if _battle_sfx_manifest_loaded:
		return
	_battle_sfx_manifest_loaded = true
	_battle_sfx_manifest = {}
	if not FileAccess.file_exists(BATTLE_SFX_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(BATTLE_SFX_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_battle_sfx_manifest = parsed

func _push_generated_audio_frames(playback: AudioStreamGeneratorPlayback, spec: Dictionary, frame_count: int) -> void:
	var frequency := float(spec.get("frequency_hz", 440.0))
	var secondary_frequency := float(spec.get("secondary_frequency_hz", 0.0))
	var amplitude := float(spec.get("amplitude", 0.18))
	var noise_amount := float(spec.get("noise", 0.0))
	var waveform := String(spec.get("waveform", "sine"))
	for index in range(frame_count):
		var t := float(index) / BATTLE_AUDIO_SAMPLE_RATE
		var progress := float(index) / float(maxi(1, frame_count - 1))
		var envelope := _audio_envelope(progress)
		var sample := 0.0
		match waveform:
			"triangle":
				sample = _triangle_wave(frequency * t)
			"square":
				sample = 1.0 if sin(TAU * frequency * t) >= 0.0 else -1.0
			_:
				sample = sin(TAU * frequency * t)
		if secondary_frequency > 0.0:
			sample = sample * 0.72 + sin(TAU * secondary_frequency * t) * 0.28
		if noise_amount > 0.0:
			sample = sample * (1.0 - noise_amount) + _deterministic_audio_noise(index) * noise_amount
		sample = clampf(sample * amplitude * envelope, -0.90, 0.90)
		playback.push_frame(Vector2(sample, sample))

func _audio_envelope(progress: float) -> float:
	var attack := smoothstep(0.0, 0.12, progress)
	var release := 1.0 - smoothstep(0.68, 1.0, progress)
	return clampf(attack * release, 0.0, 1.0)

func _triangle_wave(phase: float) -> float:
	var wrapped: float = phase - floor(phase)
	return 4.0 * abs(wrapped - 0.5) - 1.0

func _deterministic_audio_noise(index: int) -> float:
	var value := sin(float(index) * 12.9898 + 78.233) * 43758.5453
	return (value - floor(value)) * 2.0 - 1.0

func _audio_cue_wave_spec(audio_id: String) -> Dictionary:
	match audio_id:
		"audio_placeholder_ranged_release":
			return {"waveform": "sine", "frequency_hz": 760.0, "secondary_frequency_hz": 1140.0, "duration_msec": 150, "amplitude": 0.16, "volume_db": -13.0}
		"audio_placeholder_status_apply":
			return {"waveform": "triangle", "frequency_hz": 420.0, "secondary_frequency_hz": 630.0, "duration_msec": 190, "amplitude": 0.14, "volume_db": -14.0}
		"audio_placeholder_melee_release":
			return {"waveform": "triangle", "frequency_hz": 260.0, "secondary_frequency_hz": 520.0, "duration_msec": 120, "amplitude": 0.18, "noise": 0.18, "volume_db": -12.0}
		"audio_placeholder_hit":
			return {"waveform": "square", "frequency_hz": 150.0, "duration_msec": 100, "amplitude": 0.13, "noise": 0.34, "volume_db": -13.0}
		"audio_placeholder_unit_rout":
			return {"waveform": "triangle", "frequency_hz": 180.0, "secondary_frequency_hz": 120.0, "duration_msec": 260, "amplitude": 0.13, "noise": 0.12, "volume_db": -14.0}
		"audio_placeholder_cast":
			return {"waveform": "sine", "frequency_hz": 520.0, "secondary_frequency_hz": 780.0, "duration_msec": 220, "amplitude": 0.14, "volume_db": -14.0}
		"audio_placeholder_unit_step":
			return {"waveform": "triangle", "frequency_hz": 220.0, "duration_msec": 80, "amplitude": 0.09, "noise": 0.18, "volume_db": -17.0}
		"audio_placeholder_defend":
			return {"waveform": "triangle", "frequency_hz": 300.0, "duration_msec": 100, "amplitude": 0.10, "volume_db": -16.0}
		"audio_placeholder_retaliation":
			return {"waveform": "triangle", "frequency_hz": 340.0, "secondary_frequency_hz": 170.0, "duration_msec": 130, "amplitude": 0.16, "noise": 0.12, "volume_db": -13.0}
		"audio_placeholder_retreat_order", "audio_placeholder_surrender_order":
			return {"waveform": "sine", "frequency_hz": 330.0, "secondary_frequency_hz": 250.0, "duration_msec": 210, "amplitude": 0.12, "volume_db": -15.0}
		"audio_placeholder_turn_ready":
			return {"waveform": "sine", "frequency_hz": 640.0, "duration_msec": 110, "amplitude": 0.09, "volume_db": -18.0}
		"audio_placeholder_status_clear":
			return {"waveform": "sine", "frequency_hz": 360.0, "secondary_frequency_hz": 540.0, "duration_msec": 150, "amplitude": 0.10, "volume_db": -17.0}
		"audio_placeholder_idle_soft":
			return {"waveform": "sine", "frequency_hz": 180.0, "duration_msec": 70, "amplitude": 0.04, "volume_db": -24.0}
		"audio_spell_cinder_burst":
			return {"waveform": "triangle", "frequency_hz": 220.0, "secondary_frequency_hz": 760.0, "duration_msec": 260, "amplitude": 0.18, "noise": 0.18, "volume_db": -12.0}
		"audio_spell_coal_rain":
			return {"waveform": "triangle", "frequency_hz": 185.0, "secondary_frequency_hz": 520.0, "duration_msec": 300, "amplitude": 0.16, "noise": 0.24, "volume_db": -12.5}
		"audio_spell_sunlance_arc":
			return {"waveform": "sine", "frequency_hz": 690.0, "secondary_frequency_hz": 1380.0, "duration_msec": 240, "amplitude": 0.16, "volume_db": -12.0}
		"audio_spell_briar_bind":
			return {"waveform": "triangle", "frequency_hz": 260.0, "secondary_frequency_hz": 390.0, "duration_msec": 270, "amplitude": 0.14, "noise": 0.12, "volume_db": -13.0}
		"audio_spell_graft_mend":
			return {"waveform": "sine", "frequency_hz": 380.0, "secondary_frequency_hz": 570.0, "duration_msec": 280, "amplitude": 0.13, "volume_db": -13.5}
		"audio_spell_prism_bastion":
			return {"waveform": "sine", "frequency_hz": 510.0, "secondary_frequency_hz": 1020.0, "duration_msec": 270, "amplitude": 0.13, "volume_db": -13.5}
		"audio_spell_resonant_chorus":
			return {"waveform": "sine", "frequency_hz": 294.0, "secondary_frequency_hz": 882.0, "duration_msec": 290, "amplitude": 0.14, "volume_db": -13.0}
		"audio_spell_command_ward":
			return {"waveform": "sine", "frequency_hz": 330.0, "secondary_frequency_hz": 495.0, "duration_msec": 240, "amplitude": 0.12, "volume_db": -14.0}
	return {}

func _cleanup_audio_players() -> void:
	var now := int(Time.get_ticks_msec())
	var retained := []
	for entry in _active_audio_players:
		if not (entry is Dictionary):
			continue
		var player = entry.get("player", null)
		var expired := int(entry.get("expires_at_msec", 0)) <= now
		if player is AudioStreamPlayer and is_instance_valid(player) and not expired:
			retained.append(entry)
		elif player is AudioStreamPlayer and is_instance_valid(player):
			player.queue_free()
	_active_audio_players = retained

func _activate_due_audio_cue_playback() -> void:
	var now := int(Time.get_ticks_msec())
	for battle_id_value in _stack_animation_cue_playback_records.keys():
		var battle_id := String(battle_id_value)
		var cue_record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
		if cue_record.is_empty() or int(cue_record.get("started_at_msec", now)) > now:
			continue
		var audio_record: Dictionary = _stack_animation_audio_playback_records.get(battle_id, {}) if _stack_animation_audio_playback_records.get(battle_id, {}) is Dictionary else {}
		if audio_record.is_empty() or bool(audio_record.get("scheduled", false)):
			_register_audio_cue_playback(cue_record)

func _trim_audio_players() -> void:
	_cleanup_audio_players()
	while _active_audio_players.size() > BATTLE_AUDIO_MAX_ACTIVE_PLAYERS:
		var entry = _active_audio_players.pop_front()
		if entry is Dictionary:
			var player = entry.get("player", null)
			if player is AudioStreamPlayer and is_instance_valid(player):
				player.queue_free()

func _active_audio_player_count() -> int:
	_cleanup_audio_players()
	return _active_audio_players.size()

func _draw_turn_strip(field_rect: Rect2) -> void:
	var strip_rect := _turn_strip_rect(field_rect)
	draw_rect(strip_rect, TURN_STRIP_FOUNDATION_FILL, true)
	draw_rect(strip_rect, FRAME_COLOR.darkened(0.22), false, 1.4)
	for entry_value in _turn_strip_entries(field_rect):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var stack: Dictionary = entry.get("stack", {}) if entry.get("stack", {}) is Dictionary else {}
		var rect: Rect2 = entry.get("rect", Rect2())
		var current := String(stack.get("battle_id", "")) == String(_battle.get("active_stack_id", ""))
		var side_color := _side_color(String(stack.get("side", "")))
		draw_rect(rect, TURN_STRIP_ACTIVE_FILL if current else TURN_STRIP_CHIP_FILL, true)
		var accent_rect := Rect2(rect.position + Vector2(0.0, rect.size.y - 3.0), Vector2(rect.size.x, 3.0))
		draw_rect(accent_rect, side_color, true)
		var portrait := _turn_strip_portrait_payload(stack, rect)
		var portrait_rect: Rect2 = portrait.get("rect", Rect2())
		draw_rect(portrait_rect, TURN_STRIP_PORTRAIT_FILL, true)
		var portrait_texture = portrait.get("texture", null)
		if portrait_texture is Texture2D:
			draw_texture_rect(portrait_texture, portrait_rect, false, Color(0.96, 0.97, 0.92, 1.0))
		draw_rect(portrait_rect, side_color.darkened(0.14), false, 1.0)
		draw_rect(rect, ACTIVE_COLOR if current else TURN_STRIP_QUEUED_FRAME, false, 2.0 if current else 1.0)
		_draw_text(_turn_strip_chip_label(stack, rect.size.x), rect.position + Vector2(TURN_STRIP_LABEL_LEFT_INSET, 18.0), TEXT_COLOR, 10)

func _turn_strip_rect(field_rect: Rect2) -> Rect2:
	var strip_width := maxf(0.0, minf(field_rect.size.x - TURN_STRIP_MARGIN * 2.0, TURN_STRIP_MAX_WIDTH))
	return Rect2(field_rect.position + Vector2(TURN_STRIP_MARGIN, TURN_STRIP_MARGIN), Vector2(strip_width, TURN_STRIP_HEIGHT))

func _turn_strip_entries(field_rect: Rect2) -> Array:
	var entries: Array = []
	var turn_order = _battle.get("turn_order", [])
	if not (turn_order is Array):
		return entries
	var strip_rect := _turn_strip_rect(field_rect)
	var chip_width: float = minf(122.0, (strip_rect.size.x - 14.0) / float(maxi(1, mini(turn_order.size(), 5))))
	for battle_id_value in turn_order:
		if entries.size() >= 5:
			break
		var stack: Dictionary = _stack_by_id(String(battle_id_value))
		if stack.is_empty() or _stack_alive_count(stack) <= 0:
			continue
		entries.append({
			"slot": entries.size() + 1,
			"stack": stack,
			"rect": Rect2(
				strip_rect.position + Vector2(7.0 + float(entries.size()) * chip_width, 5.0),
				Vector2(chip_width - 5.0, strip_rect.size.y - 10.0)
			),
		})
	return entries

func _turn_strip_portrait_rect(chip_rect: Rect2) -> Rect2:
	var extent := minf(TURN_STRIP_PORTRAIT_EXTENT, maxf(0.0, chip_rect.size.y - 6.0))
	var center := chip_rect.position + Vector2(4.0 + extent * 0.5, chip_rect.size.y * 0.5)
	return Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))

func _turn_strip_portrait_payload(stack: Dictionary, chip_rect: Rect2) -> Dictionary:
	var unit_id := String(stack.get("unit_id", "")).strip_edges()
	var art := ContentService.get_unit_art(unit_id) if unit_id != "" else {}
	var path := String(art.get("battle_icon", "")).strip_edges()
	var texture: Texture2D = _unit_battle_icon_for_stack(stack) if unit_id != "" else null
	var portrait_rect := _turn_strip_portrait_rect(chip_rect)
	return {
		"model": TURN_STRIP_PRESENTATION_MODEL,
		"unit_id": unit_id,
		"path": path,
		"loaded": texture != null,
		"iconless_fallback": texture == null,
		"rect": portrait_rect,
		"contained": chip_rect.encloses(portrait_rect),
		"texture": texture,
	}

func _turn_strip_entry_at_position(position: Vector2) -> Dictionary:
	if _battle.is_empty():
		return {}
	for entry_value in _turn_strip_entries(_current_field_rect()):
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			var rect: Rect2 = entry.get("rect", Rect2())
			if rect.has_point(position):
				return entry
	return {}

func _turn_strip_entry_tooltip(entry: Dictionary, visible_count: int) -> String:
	var stack: Dictionary = entry.get("stack", {}) if entry.get("stack", {}) is Dictionary else {}
	if stack.is_empty():
		return tooltip_text
	var current := String(stack.get("battle_id", "")) == String(_battle.get("active_stack_id", ""))
	return "Initiative Strip\n- Visible slot: %d of %d\n- Stack: %s x%d\n- Side: %s\n- State: %s\n- Inspection: hovering this chip does not advance initiative or spend an action." % [
		int(entry.get("slot", 0)),
		visible_count,
		_stack_full_name(stack),
		_stack_alive_count(stack),
		String(stack.get("side", "neutral")).capitalize(),
		"current stack" if current else "queued stack",
	]

func _turn_strip_chip_label(stack: Dictionary, chip_width: float) -> String:
	var full_name := _stack_full_name(stack)
	var suffix := " x%d" % _stack_alive_count(stack)
	var font = get_theme_default_font()
	var words := full_name.split(" ", false)
	if font == null:
		var fallback_name := full_name if full_name.length() <= 6 else full_name.left(6)
		return "%s%s" % [fallback_name, suffix] if fallback_name == full_name else "%s…%s" % [fallback_name, suffix]
	var max_text_width := maxf(24.0, chip_width - TURN_STRIP_LABEL_LEFT_INSET - 6.0)
	var candidate := "%s%s" % [full_name, suffix]
	if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x <= max_text_width:
		return candidate
	for word_count in range(words.size() - 1, 0, -1):
		var word_prefix := " ".join(words.slice(0, word_count))
		candidate = "%s…%s" % [word_prefix, suffix]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x <= max_text_width:
			return candidate
	var compact_name := String(words[0]) if not words.is_empty() else full_name
	while compact_name.length() > 3:
		candidate = "%s…%s" % [compact_name, suffix]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x <= max_text_width:
			return candidate
		compact_name = compact_name.left(compact_name.length() - 1)
	return "%s…%s" % [full_name.left(3), suffix]

func _draw_footer_line(field_rect: Rect2) -> void:
	var footer_width: float = minf(field_rect.size.x - 20.0, 520.0)
	var footer_rect := Rect2(field_rect.position + Vector2(10.0, field_rect.end.y - 28.0), Vector2(footer_width, 22.0))
	draw_rect(footer_rect, Color(0.08, 0.10, 0.12, 0.82), true)
	draw_rect(footer_rect, FRAME_COLOR, false, 1.2)
	var fit := _footer_summary_fit(_footer_summary_text(), footer_width)
	_draw_text(String(fit.get("visible_text", "")), footer_rect.position + Vector2(9.0, 15.0), SUBTEXT_COLOR, 11)

func _footer_summary_text() -> String:
	var summary := "%s | R%d/%d | %s | %s" % [
		String(_battle.get("encounter_name", "Battle")),
		int(_battle.get("round", 1)),
		int(_battle.get("max_rounds", 12)),
		String(_battle.get("terrain", "plains")).capitalize(),
		_distance_label(int(_battle.get("distance", 1))),
	]
	var target_state := _target_state_label()
	if target_state != "":
		summary = "%s | %s" % [summary, target_state]
	var movement_state := _movement_state_label()
	if movement_state != "":
		summary = "%s | %s" % [summary, movement_state]
	var cursor_state := _controller_cursor_state_label()
	if cursor_state != "":
		summary = "%s | %s" % [summary, cursor_state]
	return summary

func _footer_summary_fit(summary: String, footer_width: float) -> Dictionary:
	var full_text := summary.strip_edges()
	var max_text_width := maxf(0.0, footer_width - 18.0)
	var font = get_theme_default_font()
	if full_text == "" or font == null or max_text_width <= 0.0:
		return {
			"full_text": full_text,
			"visible_text": "",
			"visible_width": 0.0,
			"max_text_width": max_text_width,
			"fits": full_text == "",
			"truncated": full_text != "",
		}
	var full_width := font.get_string_size(full_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x
	if full_width <= max_text_width:
		return {
			"full_text": full_text,
			"visible_text": full_text,
			"visible_width": full_width,
			"max_text_width": max_text_width,
			"fits": true,
			"truncated": false,
		}
	var candidate := full_text
	while candidate != "":
		var boundary := candidate.rfind(" ")
		candidate = candidate.left(boundary).strip_edges() if boundary > 0 else ""
		candidate = candidate.trim_suffix("|").strip_edges()
		var visible_text := "%s…" % candidate if candidate != "" else "…"
		var visible_width := font.get_string_size(visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x
		if visible_width <= max_text_width:
			return {
				"full_text": full_text,
				"visible_text": visible_text,
				"visible_width": visible_width,
				"max_text_width": max_text_width,
				"fits": true,
				"truncated": true,
			}
	return {
		"full_text": full_text,
		"visible_text": "",
		"visible_width": 0.0,
		"max_text_width": max_text_width,
		"fits": false,
		"truncated": true,
	}

func validation_footer_summary() -> Dictionary:
	var field_rect := _current_field_rect()
	var footer_width: float = minf(field_rect.size.x - 20.0, 520.0)
	var footer_rect := Rect2(field_rect.position + Vector2(10.0, field_rect.end.y - 28.0), Vector2(footer_width, 22.0))
	var board_rect := Rect2(Vector2.ZERO, size)
	var summary := _footer_summary_fit(_footer_summary_text(), footer_width)
	summary["footer_rect"] = footer_rect
	summary["field_rect"] = field_rect
	summary["board_rect"] = board_rect
	summary["footer_contained"] = board_rect.encloses(footer_rect)
	return summary

func validation_footer_fit_summary(text: String) -> Dictionary:
	var field_rect := _current_field_rect()
	var footer_width: float = minf(field_rect.size.x - 20.0, 520.0)
	return _footer_summary_fit(text, footer_width)

func _controller_cursor_state_label() -> String:
	if not has_focus() or not _cell_in_bounds(_controller_cursor_cell):
		return ""
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	if battle_id != "":
		return "Cursor: %s" % _stack_short_label(_stack_by_id(battle_id))
	return "Cursor: %d,%d %s" % [
		_controller_cursor_cell.x,
		_controller_cursor_cell.y,
		"move" if _is_legal_destination_cell(_controller_cursor_cell) else "blocked",
	]

func _controller_cursor_cell_role() -> String:
	if not _cell_in_bounds(_controller_cursor_cell):
		return ""
	var battle_id := _stack_id_at_cell(_controller_cursor_cell)
	if battle_id != "":
		var stack := _stack_by_id(battle_id)
		return "%s_stack" % String(stack.get("side", "unknown"))
	return "legal_destination" if _is_legal_destination_cell(_controller_cursor_cell) else "blocked_hex"

func _draw_objective_marker(center: Vector2, objective: Dictionary, color: Color, radius: float) -> void:
	var objective_type := String(objective.get("type", ""))
	var size: float = clampf(radius * 0.46, 10.0, 20.0)
	match objective_type:
		"cover_line":
			var cover_rect := Rect2(center - Vector2(size * 1.15, size * 0.38), Vector2(size * 2.3, size * 0.76))
			draw_rect(cover_rect, color.darkened(0.08), true)
			draw_rect(cover_rect, Color(0.08, 0.10, 0.12, 0.80), false, 1.6)
			draw_line(cover_rect.position + Vector2(3.0, 0.0), cover_rect.end - Vector2(3.0, 0.0), Color(0.98, 0.90, 0.66, 0.36), 1.2)
		"obstruction_line":
			draw_line(center + Vector2(-size, -size * 0.68), center + Vector2(size, size * 0.68), color, 4.0)
			draw_line(center + Vector2(size, -size * 0.68), center + Vector2(-size, size * 0.68), color, 4.0)
			draw_circle(center, size * 0.24, TEXT_COLOR)
		"lane_battery":
			draw_circle(center, size * 0.74, color)
			draw_rect(Rect2(center - Vector2(size * 0.20, size * 0.92), Vector2(size * 0.40, size * 1.12)), Color(0.08, 0.10, 0.12, 0.78), true)
			draw_line(center + Vector2(-size * 0.82, size * 0.38), center + Vector2(size * 0.82, size * 0.38), Color(0.08, 0.10, 0.12, 0.78), 3.0)
		"hazard_zone":
			var points := PackedVector2Array([
				center + Vector2(0.0, -size),
				center + Vector2(size * 0.90, size * 0.60),
				center + Vector2(-size * 0.90, size * 0.60),
			])
			draw_colored_polygon(points, color)
			draw_polyline(_closed_points(points), Color(0.08, 0.10, 0.12, 0.86), 1.8, true)
		_:
			draw_circle(center, size * 0.76, color)
			draw_circle(center, size * 0.76, Color(0.08, 0.10, 0.12, 0.82), false, 1.8)
	var progress_side := String(objective.get("progress_side", ""))
	var progress_value := int(objective.get("progress_value", 0))
	var threshold: int = maxi(1, int(objective.get("capture_threshold", 2)))
	if progress_side != "" and progress_value > 0:
		for pip in range(threshold):
			var pip_center := center + Vector2((float(pip) - float(threshold - 1) * 0.5) * 6.0, size + 5.0)
			draw_circle(pip_center, 2.0, _controller_color(progress_side) if pip < progress_value else Color(0.08, 0.10, 0.12, 0.55))

func _draw_unit_glyph(center: Vector2, radius: float, stack: Dictionary) -> void:
	var glyph_color := Color(0.08, 0.10, 0.12, 0.88)
	if bool(stack.get("ranged", false)):
		draw_line(center + Vector2(-radius * 0.52, radius * 0.25), center + Vector2(radius * 0.50, -radius * 0.28), glyph_color, 2.6)
		draw_line(center + Vector2(radius * 0.50, -radius * 0.28), center + Vector2(radius * 0.22, -radius * 0.32), glyph_color, 2.2)
		draw_line(center + Vector2(radius * 0.50, -radius * 0.28), center + Vector2(radius * 0.38, -radius * 0.02), glyph_color, 2.2)
	else:
		draw_line(center + Vector2(-radius * 0.42, radius * 0.34), center + Vector2(radius * 0.38, -radius * 0.38), glyph_color, 3.0)
		draw_line(center + Vector2(-radius * 0.20, radius * 0.10), center + Vector2(radius * 0.10, radius * 0.38), glyph_color, 2.2)
	if bool(stack.get("defending", false)):
		var shield := PackedVector2Array([
			center + Vector2(0.0, -radius * 0.58),
			center + Vector2(radius * 0.34, -radius * 0.22),
			center + Vector2(radius * 0.23, radius * 0.36),
			center + Vector2(0.0, radius * 0.58),
			center + Vector2(-radius * 0.23, radius * 0.36),
			center + Vector2(-radius * 0.34, -radius * 0.22),
		])
		draw_polyline(_closed_points(shield), Color(0.98, 0.93, 0.74, 0.80), 1.6, true)

func _draw_stack_side_cue(center: Vector2, token_radius: float, side: String) -> void:
	if not FrontierVisualKitScript.color_cue_assist_enabled():
		return
	var marker_center := center + Vector2(-token_radius * 0.72, -token_radius * 0.70)
	var marker_radius := maxf(7.0, token_radius * 0.34)
	var outline := Color(0.98, 0.98, 0.94, 0.96)
	var fill := _side_color(side).darkened(0.18)
	if side == "player":
		draw_circle(marker_center, marker_radius, fill)
		draw_circle(marker_center, marker_radius, outline, false, 1.6)
		_draw_centered_text("P", marker_center + Vector2(0.0, 3.4), outline, 9)
		return
	var triangle := PackedVector2Array([
		marker_center + Vector2(0.0, -marker_radius),
		marker_center + Vector2(marker_radius * 0.92, marker_radius * 0.78),
		marker_center + Vector2(-marker_radius * 0.92, marker_radius * 0.78),
	])
	draw_colored_polygon(triangle, fill)
	draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), outline, 1.6, true)
	_draw_centered_text("E", marker_center + Vector2(0.0, 3.8), outline, 9)

func _draw_stack_health_bar(center: Vector2, radius: float, stack: Dictionary) -> void:
	var bar_size := Vector2(radius * 0.96, 5.0)
	var bar_rect := Rect2(center + Vector2(-bar_size.x * 0.5, radius * 0.54), bar_size)
	draw_rect(bar_rect, Color(0.07, 0.08, 0.09, 0.82), true)
	var hp_rect := bar_rect
	hp_rect.size.x *= _stack_health_ratio(stack)
	draw_rect(hp_rect, HEALTH_COLOR, true)

func _draw_count_badge(center: Vector2, token_radius: float, stack: Dictionary) -> void:
	var count := _stack_alive_count(stack)
	var badge_center := center + Vector2(token_radius * 0.70, token_radius * 0.68)
	draw_circle(badge_center, max(8.0, token_radius * 0.38), Color(0.08, 0.10, 0.12, 0.92))
	draw_circle(badge_center, max(8.0, token_radius * 0.38), Color(0.96, 0.90, 0.68, 0.76), false, 1.2)
	_draw_centered_text(str(count), badge_center + Vector2(0.0, 3.5), TEXT_COLOR, 10)

func _draw_stack_caption(center: Vector2, radius: float, stack: Dictionary) -> void:
	var layout := _stack_caption_layout(center, radius, stack)
	var plate_rect: Rect2 = layout.get("plate_rect", Rect2())
	var accent_rect: Rect2 = layout.get("accent_rect", Rect2())
	var text_position: Vector2 = layout.get("text_position", Vector2.ZERO)
	var accent_color: Color = layout.get("accent_color", Color.TRANSPARENT)
	draw_rect(Rect2(plate_rect.position + Vector2(1.0, 2.0), plate_rect.size), STACK_CAPTION_PLATE_SHADOW, true)
	draw_rect(plate_rect, STACK_CAPTION_PLATE_FILL, true)
	draw_rect(plate_rect, STACK_CAPTION_PLATE_FRAME, false, 1.0)
	draw_rect(accent_rect, accent_color, true)
	_draw_text(String(layout.get("label", "")), text_position, TEXT_COLOR, STACK_CAPTION_FONT_SIZE)

func _stack_caption_layout(center: Vector2, radius: float, stack: Dictionary) -> Dictionary:
	var label := _stack_caption_label(stack)
	var font := get_theme_default_font()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, STACK_CAPTION_FONT_SIZE) if font != null else Vector2(float(label.length()) * 5.5, 10.0)
	var plate_size := Vector2(ceil(text_size.x) + STACK_CAPTION_HORIZONTAL_PADDING * 2.0 + STACK_CAPTION_ACCENT_WIDTH, STACK_CAPTION_PLATE_HEIGHT)
	var token_radius := _stack_token_radius(radius)
	var plate_position := Vector2(round(center.x - plate_size.x * 0.5), round(center.y - token_radius - STACK_CAPTION_TOKEN_GAP - plate_size.y))
	var plate_rect := Rect2(plate_position, plate_size)
	var text_position := plate_position + Vector2(STACK_CAPTION_HORIZONTAL_PADDING + STACK_CAPTION_ACCENT_WIDTH, 12.0)
	var text_rect := Rect2(Vector2(text_position.x, plate_position.y + 2.0), text_size)
	var accent_rect := Rect2(plate_position, Vector2(STACK_CAPTION_ACCENT_WIDTH, plate_size.y))
	var side_color := _side_color(String(stack.get("side", "")))
	var accent_color := Color(side_color.r, side_color.g, side_color.b, STACK_CAPTION_ACCENT_ALPHA)
	return {
		"model": STACK_CAPTION_PLATE_MODEL,
		"label": label,
		"plate_rect": plate_rect,
		"text_position": text_position,
		"text_rect": text_rect,
		"accent_rect": accent_rect,
		"accent_color": accent_color,
	}

func _draw_focus_link(start: Vector2, end: Vector2, active_side: String) -> void:
	var color := ACTIVE_COLOR if active_side == "player" else TARGET_COLOR
	draw_line(start, end, Color(color.r, color.g, color.b, 0.52), 3.0, true)
	var delta := end - start
	if delta.length() <= 1.0:
		return
	var direction := delta.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	for step in range(1, 4):
		var point := start.lerp(end, float(step) / 4.0)
		var arrow := PackedVector2Array([
			point + direction * 8.0,
			point - direction * 6.0 + perpendicular * 5.0,
			point - direction * 6.0 - perpendicular * 5.0,
		])
		draw_colored_polygon(arrow, Color(color.r, color.g, color.b, 0.58))

func _draw_blocked_target_marker(center: Vector2, radius: float) -> void:
	var marker_radius: float = clampf(radius * 0.34, 7.0, 14.0)
	var marker_center := center + Vector2(radius * 0.36, -radius * 0.36)
	draw_circle(marker_center, marker_radius, Color(0.08, 0.09, 0.10, 0.86))
	draw_line(marker_center + Vector2(-marker_radius * 0.48, -marker_radius * 0.48), marker_center + Vector2(marker_radius * 0.48, marker_radius * 0.48), BLOCKED_TARGET_COLOR, 2.2)
	draw_line(marker_center + Vector2(marker_radius * 0.48, -marker_radius * 0.48), marker_center + Vector2(-marker_radius * 0.48, marker_radius * 0.48), BLOCKED_TARGET_COLOR, 2.2)

func _draw_tree(center: Vector2, scale: float) -> void:
	var crown := PackedVector2Array([
		center + Vector2(0.0, -scale),
		center + Vector2(scale * 0.78, scale * 0.48),
		center + Vector2(-scale * 0.78, scale * 0.48),
	])
	draw_colored_polygon(crown, Color(0.10, 0.21, 0.13, 0.34))
	draw_rect(Rect2(center + Vector2(-2.0, scale * 0.28), Vector2(4.0, scale * 0.46)), Color(0.16, 0.11, 0.07, 0.26), true)

func _draw_hill(center: Vector2, width: float, height: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(-width * 0.50, height * 0.35),
		center + Vector2(-width * 0.22, -height * 0.34),
		center + Vector2(width * 0.04, -height * 0.08),
		center + Vector2(width * 0.34, -height * 0.42),
		center + Vector2(width * 0.50, height * 0.35),
	])
	draw_colored_polygon(points, Color(0.18, 0.14, 0.09, 0.20))

func _draw_hex(center: Vector2, radius: float, fill: Color, stroke: Color, width: float) -> void:
	var points := _hex_points(center, radius)
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	if stroke.a > 0.0 and width > 0.0:
		draw_polyline(_closed_points(points), stroke, width, true)

func _draw_hex_outline(center: Vector2, radius: float, stroke: Color, width: float) -> void:
	draw_polyline(_closed_points(_hex_points(center, radius)), stroke, width, true)

func _draw_unique_hex_grid_lines(hex_layout: Dictionary, stroke: Color, width: float, radius_scale: float) -> void:
	var radius := float(hex_layout.get("radius", 1.0)) * radius_scale
	var drawn_edges := {}
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var points := _hex_points(_hex_center(cell, hex_layout), radius)
			for index in range(points.size()):
				var start := points[index]
				var end := points[(index + 1) % points.size()]
				var edge_key := _edge_key(start, end)
				if drawn_edges.has(edge_key):
					continue
				drawn_edges[edge_key] = true
				draw_line(start, end, stroke, width, true)

func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(30.0 + 60.0 * float(index))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	return closed

func _points_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_position := points[0]
	var max_position := points[0]
	for point in points:
		min_position.x = minf(min_position.x, point.x)
		min_position.y = minf(min_position.y, point.y)
		max_position.x = maxf(max_position.x, point.x)
		max_position.y = maxf(max_position.y, point.y)
	return Rect2(min_position, max_position - min_position)

func _edge_key(start: Vector2, end: Vector2) -> String:
	var start_key := _point_grid_key(start)
	var end_key := _point_grid_key(end)
	if start_key.x > end_key.x or (start_key.x == end_key.x and start_key.y > end_key.y):
		var swap_key := start_key
		start_key = end_key
		end_key = swap_key
	return "%d:%d|%d:%d" % [start_key.x, start_key.y, end_key.x, end_key.y]

func _point_grid_key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 10.0), roundi(point.y * 10.0))

func _terrain_hex_texture_source_size(texture_size: Vector2) -> Vector2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ZERO
	var source_height: float = clampf(texture_size.y * 0.24, 48.0, texture_size.y)
	var source_width: float = clampf(source_height * 0.92, 48.0, texture_size.x)
	return Vector2(source_width, source_height)

func _terrain_hex_texture_source_position(cell: Vector2i, texture_size: Vector2, source_size: Vector2) -> Vector2:
	var usable := Vector2(maxf(0.0, texture_size.x - source_size.x), maxf(0.0, texture_size.y - source_size.y))
	return Vector2(
		floor(usable.x * _hex_variation(cell, 3.0)),
		floor(usable.y * _hex_variation(cell, 17.0))
	)

func _terrain_hex_texture_uvs(points: PackedVector2Array, bounds: Rect2, source_rect: Rect2, texture_size: Vector2) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return uvs
	for point in points:
		var relative := Vector2(
			(point.x - bounds.position.x) / bounds.size.x,
			(point.y - bounds.position.y) / bounds.size.y
		)
		var source_point := source_rect.position + Vector2(
			relative.x * source_rect.size.x,
			relative.y * source_rect.size.y
		)
		# CanvasItem.draw_polygon samples Texture2D with normalized UVs.
		uvs.append(_terrain_texture_normalized_uv(source_point, texture_size))
	return uvs

func _terrain_texture_normalized_uv(source_point: Vector2, texture_size: Vector2) -> Vector2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(
		clampf(source_point.x / texture_size.x, 0.0, 1.0),
		clampf(source_point.y / texture_size.y, 0.0, 1.0)
	)

func _terrain_texture_sampling_summary(texture) -> Dictionary:
	var empty_summary := {
		"texture_uv_space": "",
		"texture_uv_min_x": 0.0,
		"texture_uv_min_y": 0.0,
		"texture_uv_max_x": 0.0,
		"texture_uv_max_y": 0.0,
		"texture_uv_within_0_1": false,
		"texture_source_min_x": 0.0,
		"texture_source_min_y": 0.0,
		"texture_source_max_x": 0.0,
		"texture_source_max_y": 0.0,
		"texture_source_within_texture": false,
		"texture_source_sample_count": 0,
	}
	if texture == null:
		return empty_summary
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return empty_summary
	var source_size := _terrain_hex_texture_source_size(texture_size)
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return empty_summary
	var min_source := texture_size
	var max_source := Vector2.ZERO
	var min_uv := Vector2(1.0, 1.0)
	var max_uv := Vector2.ZERO
	var sample_count := 0
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var source_rect := Rect2(_terrain_hex_texture_source_position(cell, texture_size, source_size), source_size)
			var source_min := source_rect.position
			var source_max := source_rect.position + source_rect.size
			var uv_min := _terrain_texture_normalized_uv(source_min, texture_size)
			var uv_max := _terrain_texture_normalized_uv(source_max, texture_size)
			min_source.x = minf(min_source.x, source_min.x)
			min_source.y = minf(min_source.y, source_min.y)
			max_source.x = maxf(max_source.x, source_max.x)
			max_source.y = maxf(max_source.y, source_max.y)
			min_uv.x = minf(min_uv.x, uv_min.x)
			min_uv.y = minf(min_uv.y, uv_min.y)
			max_uv.x = maxf(max_uv.x, uv_max.x)
			max_uv.y = maxf(max_uv.y, uv_max.y)
			sample_count += 1
	return {
		"texture_uv_space": "normalized_0_1",
		"texture_uv_min_x": min_uv.x,
		"texture_uv_min_y": min_uv.y,
		"texture_uv_max_x": max_uv.x,
		"texture_uv_max_y": max_uv.y,
		"texture_uv_within_0_1": min_uv.x >= 0.0 and min_uv.y >= 0.0 and max_uv.x <= 1.0 and max_uv.y <= 1.0,
		"texture_source_min_x": min_source.x,
		"texture_source_min_y": min_source.y,
		"texture_source_max_x": max_source.x,
		"texture_source_max_y": max_source.y,
		"texture_source_within_texture": min_source.x >= 0.0 and min_source.y >= 0.0 and max_source.x <= texture_size.x and max_source.y <= texture_size.y,
		"texture_source_sample_count": sample_count,
	}

func _hex_variation(cell: Vector2i, salt: float) -> float:
	var value := sin(float(cell.x) * 12.9898 + float(cell.y) * 78.233 + salt) * 43758.5453
	return value - floor(value)

func _terrain_hex_tile_count() -> int:
	return HEX_COLUMNS * HEX_ROWS

func _terrain_rendering_mode(texture_loaded: bool) -> String:
	return "hex_snapped_texture" if texture_loaded else "hex_snapped_color_fallback"

func _hex_field_rect(field_rect: Rect2) -> Rect2:
	return Rect2(
		field_rect.position + Vector2(10.0, 44.0),
		Vector2(max(1.0, field_rect.size.x - 20.0), max(1.0, field_rect.size.y - 78.0))
	)

func _hex_layout(hex_field_rect: Rect2) -> Dictionary:
	var radius_x := hex_field_rect.size.x / (SQRT_3 * (float(HEX_COLUMNS) + 0.5))
	var radius_y := hex_field_rect.size.y / (1.5 * float(HEX_ROWS - 1) + 2.0)
	var radius: float = maxf(8.0, minf(radius_x, radius_y))
	var grid_size := Vector2(
		SQRT_3 * radius * (float(HEX_COLUMNS) + 0.5),
		radius * (1.5 * float(HEX_ROWS - 1) + 2.0)
	)
	var origin := hex_field_rect.position + (hex_field_rect.size - grid_size) * 0.5
	return {
		"origin": origin,
		"radius": radius,
		"hex_width": SQRT_3 * radius,
		"grid_size": grid_size,
		"rect": Rect2(origin, grid_size),
	}

func _hex_center(cell: Vector2i, layout: Dictionary) -> Vector2:
	var origin: Vector2 = layout.get("origin", Vector2.ZERO)
	var radius := float(layout.get("radius", 1.0))
	var hex_width := float(layout.get("hex_width", SQRT_3 * radius))
	return origin + Vector2(
		hex_width * (float(cell.x) + 0.5 * float(cell.y % 2)) + hex_width * 0.5,
		radius * (1.5 * float(cell.y) + 1.0)
	)

func _cell_fill_color(column: int, player_front: int, enemy_front: int, terrain_texture_loaded: bool = false) -> Color:
	if terrain_texture_loaded:
		if column < player_front:
			return Color(0.13, 0.25, 0.31, TEXTURED_DEPLOYMENT_FILL_ALPHA)
		if column > enemy_front:
			return Color(0.34, 0.13, 0.12, TEXTURED_DEPLOYMENT_FILL_ALPHA)
		if column == int(HEX_COLUMNS / 2):
			return Color(0.50, 0.38, 0.18, TEXTURED_CENTER_FILL_ALPHA)
		return Color(0.09, 0.12, 0.10, 0.0)
	if column < player_front:
		return Color(0.13, 0.25, 0.31, 0.22)
	if column > enemy_front:
		return Color(0.34, 0.13, 0.12, 0.22)
	if column == int(HEX_COLUMNS / 2):
		return Color(0.50, 0.38, 0.18, 0.18)
	return Color(0.09, 0.12, 0.10, 0.12)

func _terrain_texture_visible(texture_loaded: bool) -> bool:
	return texture_loaded \
		and not _terrain_grid_repaints_texture_cells(texture_loaded) \
		and TERRAIN_TEXTURE_MODULATE.a >= 0.94 \
		and TERRAIN_TEXTURE_READABILITY_WASH.a <= 0.08 \
		and TERRAIN_HEX_TEXTURE_INSET >= 0.995

func _terrain_grid_fill_mode(texture_loaded: bool) -> String:
	return "texture_transparent_tactical_tint" if texture_loaded else "fallback_readability_fill"

func _terrain_grid_border_mode(texture_loaded: bool) -> String:
	return "deduplicated_texture_grid" if texture_loaded else "per_cell_fallback_grid"

func _terrain_grid_border_deduplicated(texture_loaded: bool) -> bool:
	return texture_loaded

func _terrain_grid_repaints_texture_cells(texture_loaded: bool) -> bool:
	return texture_loaded and _terrain_grid_max_fill_alpha(texture_loaded) > TEXTURED_GRID_MAX_CELL_FILL_ALPHA

func _terrain_grid_max_fill_alpha(texture_loaded: bool) -> float:
	var distance := clampi(int(_battle.get("distance", 1)), 0, 2)
	var player_front := _front_column("player", distance)
	var enemy_front := _front_column("enemy", distance)
	var max_alpha := 0.0
	for column in range(HEX_COLUMNS):
		var fill := _cell_fill_color(column, player_front, enemy_front, texture_loaded)
		max_alpha = maxf(max_alpha, fill.a)
		if column >= player_front and column <= enemy_front:
			max_alpha = maxf(max_alpha, TEXTURED_MID_LANE_FILL_ALPHA if texture_loaded else 0.035)
	return max_alpha

func _stack_cells() -> Dictionary:
	var cells := {}
	var distance := clampi(int(_battle.get("distance", 1)), 0, 2)
	_assign_stack_cells(cells, _visible_stack_list(_player_stacks), "player", distance)
	_assign_stack_cells(cells, _visible_stack_list(_enemy_stacks), "enemy", distance)
	return cells

func _assign_stack_cells(cells: Dictionary, stacks: Array, side: String, distance: int) -> void:
	var rows := _formation_rows(stacks.size())
	for index in range(stacks.size()):
		var stack_value = stacks[index]
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		var hex := _stack_hex_cell(stack)
		if hex.x < 0:
			var column := _front_column(side, distance)
			if bool(stack.get("ranged", false)):
				column += -1 if side == "player" else 1
			column = clampi(column, 0, HEX_COLUMNS - 1)
			var row := int(rows[index]) if index < rows.size() else clampi(index, 0, HEX_ROWS - 1)
			hex = Vector2i(column, row)
		cells[String(stack.get("battle_id", ""))] = hex

func _formation_rows(stack_count: int) -> Array:
	match stack_count:
		0:
			return []
		1:
			return [3]
		2:
			return [2, 4]
		3:
			return [1, 3, 5]
		4:
			return [1, 2, 4, 5]
		5:
			return [0, 2, 3, 4, 6]
		6:
			return [0, 1, 2, 4, 5, 6]
		_:
			return [0, 1, 2, 3, 4, 5, 6]

func _front_column(side: String, distance: int) -> int:
	var normalized_distance := clampi(distance, 0, 2)
	if side == "player":
		return [4, 3, 1][normalized_distance]
	return [5, 7, 9][normalized_distance]

func _objective_cell(index: int, objective_type: String) -> Vector2i:
	match objective_type:
		"lane_battery":
			return Vector2i(5, 1 if index % 2 == 0 else 5)
		"cover_line":
			return Vector2i(4, 2 + (index % 3))
		"obstruction_line":
			return Vector2i(5, 3)
		"hazard_zone":
			return Vector2i(6, 2 + (index % 3))
		"signal_beacon":
			return Vector2i(5, 0 if index % 2 == 0 else 6)
		"breach_point":
			return Vector2i(5, 3)
		_:
			var defaults := [Vector2i(5, 3), Vector2i(5, 2), Vector2i(5, 4), Vector2i(4, 3), Vector2i(6, 3)]
			return defaults[index % defaults.size()]

func _stack_hex_cell(stack: Dictionary) -> Vector2i:
	var hex = stack.get("hex", {})
	if not (hex is Dictionary):
		return Vector2i(-1, -1)
	var cell := Vector2i(int(hex.get("q", -1)), int(hex.get("r", -1)))
	return cell if _cell_in_bounds(cell) else Vector2i(-1, -1)

func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < HEX_COLUMNS and cell.y >= 0 and cell.y < HEX_ROWS

func _hex_cell_at_position(position: Vector2) -> Vector2i:
	if _battle.is_empty():
		return Vector2i(-1, -1)
	var hex_layout := _current_hex_layout()
	var radius := float(hex_layout.get("radius", 1.0))
	var best_cell := Vector2i(-1, -1)
	var best_distance := 999999.0
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var center := _hex_center(cell, hex_layout)
			if not Geometry2D.is_point_in_polygon(position, _hex_points(center, radius)):
				continue
			var distance := position.distance_to(center)
			if distance < best_distance:
				best_distance = distance
				best_cell = cell
	if best_cell.x >= 0:
		return best_cell

	best_distance = radius * 0.92
	for row in range(HEX_ROWS):
		for column in range(HEX_COLUMNS):
			var cell := Vector2i(column, row)
			var distance := position.distance_to(_hex_center(cell, hex_layout))
			if distance <= best_distance:
				best_distance = distance
				best_cell = cell
	return best_cell

func _current_hex_layout() -> Dictionary:
	return _hex_layout(_hex_field_rect(_current_field_rect()))

func _current_field_rect() -> Rect2:
	var board_rect := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	return board_rect.grow(-12.0)

func _camera_adjusted_hex_layout(hex_layout: Dictionary) -> Dictionary:
	var adjusted := hex_layout.duplicate(true)
	var offset := _battle_camera_offset_for_records(_camera_playback_records(hex_layout, _stack_cells()))
	if offset.length() <= 0.01:
		return adjusted
	var origin: Vector2 = adjusted.get("origin", Vector2.ZERO)
	adjusted["origin"] = origin + offset
	var rect: Rect2 = adjusted.get("rect", Rect2())
	adjusted["rect"] = Rect2(rect.position + offset, rect.size)
	return adjusted

func _camera_playback_records(hex_layout: Dictionary, stack_cells: Dictionary) -> Array:
	var records: Array = []
	for battle_id_value in _stack_animation_cue_playback_records.keys():
		var battle_id := String(battle_id_value)
		var cue_record: Dictionary = _stack_animation_cue_playback_records.get(battle_id, {}) if _stack_animation_cue_playback_records.get(battle_id, {}) is Dictionary else {}
		if cue_record.is_empty() or not stack_cells.has(battle_id):
			continue
		var camera_record := _camera_playback_record_for_cue(cue_record, hex_layout, stack_cells)
		if not camera_record.is_empty():
			records.append(camera_record)
	return records

func _camera_playback_record_for_cue(cue_record: Dictionary, hex_layout: Dictionary, stack_cells: Dictionary) -> Dictionary:
	var battle_id := String(cue_record.get("battle_id", "")).strip_edges()
	if battle_id == "" or not stack_cells.has(battle_id):
		return {}
	var subject_cell: Vector2i = stack_cells.get(battle_id)
	var source_id := String(cue_record.get("source_battle_id", "")).strip_edges()
	if source_id == "":
		source_id = battle_id
	var target_id := String(cue_record.get("target_battle_id", "")).strip_edges()
	if target_id == "":
		target_id = battle_id
	var source_cell: Vector2i = stack_cells.get(source_id, subject_cell)
	var target_cell: Vector2i = stack_cells.get(target_id, subject_cell)
	var from_cell := Vector2i(int(cue_record.get("from_q", -1)), int(cue_record.get("from_r", -1)))
	var to_cell := Vector2i(int(cue_record.get("to_q", -1)), int(cue_record.get("to_r", -1)))
	if _cell_in_bounds(from_cell) and _cell_in_bounds(to_cell):
		source_cell = from_cell
		target_cell = to_cell
	var subject_center := _hex_center(subject_cell, hex_layout)
	var source_center := _hex_center(source_cell, hex_layout)
	var target_center := _hex_center(target_cell, hex_layout)
	var event_id := String(cue_record.get("event_id", ""))
	var focus_kind := _camera_focus_kind_for_event(event_id)
	if focus_kind == "":
		return {}
	var focus := subject_center
	match focus_kind:
		"travel":
			focus = source_center.lerp(target_center, _cue_playback_progress(cue_record))
		"source_target", "spell":
			focus = source_center.lerp(target_center, 0.5)
		"impact", "status", "exit":
			focus = target_center
	var shake_strength := _camera_shake_strength_for_event(event_id)
	var mode := String(cue_record.get("mode", AnimationCueCatalogScript.MODE_NORMAL))
	if mode == AnimationCueCatalogScript.MODE_FAST or mode == AnimationCueCatalogScript.MODE_REDUCED_MOTION or mode == AnimationCueCatalogScript.MODE_REDUCED_MOTION_FAST:
		shake_strength = 0.0
	else:
		shake_strength *= SettingsService.battle_camera_shake_scale()
	return {
		"battle_id": battle_id,
		"event_id": event_id,
		"serial": int(cue_record.get("serial", 0)),
		"focus_kind": focus_kind,
		"source_battle_id": source_id,
		"target_battle_id": target_id,
		"subject_q": subject_cell.x,
		"subject_r": subject_cell.y,
		"source_q": source_cell.x,
		"source_r": source_cell.y,
		"target_q": target_cell.x,
		"target_r": target_cell.y,
		"focus_x": snappedf(focus.x, 0.01),
		"focus_y": snappedf(focus.y, 0.01),
		"progress": snappedf(_cue_playback_progress(cue_record), 0.001),
		"shake_strength": snappedf(shake_strength, 0.001),
		"mode": mode,
	}

func _camera_focus_kind_for_event(event_id: String) -> String:
	match event_id:
		"battle_unit_move":
			return "travel"
		"battle_unit_ranged_attack", "battle_unit_melee_attack", "battle_retaliation":
			return "source_target"
		"battle_unit_cast":
			return "spell"
		"battle_unit_hit", "battle_unit_death":
			return "impact"
		"battle_status_applied", "battle_status_expired":
			return "status"
		"battle_unit_retreat", "battle_unit_surrender":
			return "exit"
	return ""

func _camera_shake_strength_for_event(event_id: String) -> float:
	match event_id:
		"battle_unit_death":
			return 0.62
		"battle_unit_hit":
			return 0.38
		"battle_unit_melee_attack", "battle_retaliation":
			return 0.24
		"battle_unit_ranged_attack":
			return 0.16
		"battle_unit_cast":
			return 0.12
		"battle_status_applied", "battle_status_expired":
			return 0.10
		"battle_unit_retreat", "battle_unit_surrender":
			return 0.08
	return 0.0

func _battle_camera_offset_for_records(records: Array) -> Vector2:
	if records.is_empty():
		return Vector2.ZERO
	var strongest := {}
	for record in records:
		if not (record is Dictionary):
			continue
		if strongest.is_empty() or float(record.get("shake_strength", 0.0)) > float(strongest.get("shake_strength", 0.0)):
			strongest = record
	if strongest.is_empty():
		return Vector2.ZERO
	var progress := clampf(float(strongest.get("progress", 0.0)), 0.0, 1.0)
	var shake_strength := clampf(float(strongest.get("shake_strength", 0.0)), 0.0, 1.0)
	if shake_strength <= 0.0:
		return Vector2.ZERO
	var decay := 1.0 - progress
	var serial := float(int(strongest.get("serial", 0)))
	var pulse := Vector2(sin(progress * TAU * 2.0 + serial), cos(progress * TAU * 1.5 + serial * 0.61))
	if pulse.length() > 0.0:
		pulse = pulse.normalized()
	var offset := pulse * BATTLE_CAMERA_MAX_OFFSET_PX * shake_strength * decay
	if offset.length() > BATTLE_CAMERA_MAX_OFFSET_PX:
		offset = offset.normalized() * BATTLE_CAMERA_MAX_OFFSET_PX
	return offset

func _is_legal_destination_cell(cell: Vector2i) -> bool:
	if not _cell_in_bounds(cell):
		return false
	for destination in BattleRulesScript.legal_destinations_for_active_stack(_battle):
		if not (destination is Dictionary):
			continue
		if int(destination.get("q", -1)) == cell.x and int(destination.get("r", -1)) == cell.y:
			return true
	return false

func _selected_target_is_blocked() -> bool:
	var selected_target_id := String(_battle.get("selected_target_id", ""))
	if selected_target_id == "" or _battle.is_empty():
		return false
	var legality := BattleRulesScript.selected_target_legality(_battle)
	return bool(legality.get("blocked", false))

func _target_state_label() -> String:
	if _target_stack.is_empty():
		return ""
	var active_side := String(_active_stack.get("side", ""))
	if active_side != "" and active_side != "player":
		return "Input locked"
	var continuity_context := BattleRulesScript.selected_target_continuity_context(_battle)
	if not continuity_context.is_empty():
		return String(continuity_context.get("footer_label", "Setup target"))
	var closing_context := BattleRulesScript.selected_target_closing_context(_battle)
	if not closing_context.is_empty():
		return String(closing_context.get("footer_label", "Closing target"))
	var click_intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, String(_target_stack.get("battle_id", "")))
	var action_label := String(click_intent.get("label", ""))
	if action_label != "":
		return "Click: %s" % action_label
	var legality := BattleRulesScript.selected_target_legality(_battle)
	if bool(legality.get("melee", false)) and bool(legality.get("ranged", false)):
		return "Target: melee/ranged"
	if bool(legality.get("melee", false)):
		return "Target: melee"
	if bool(legality.get("ranged", false)):
		return "Target: ranged"
	if bool(legality.get("blocked", false)):
		return "Target: blocked"
	return ""

func _movement_state_label() -> String:
	if String(_active_stack.get("side", "")) != "player":
		return ""
	var hovered_preview := _hover_destination_preview()
	if not hovered_preview.is_empty():
		var detail := String(hovered_preview.get("destination_detail", ""))
		var setup_label := String(hovered_preview.get("selected_target_setup_label", ""))
		if bool(hovered_preview.get("sets_up_selected_target_attack", false)) and setup_label != "":
			return "Move: %s -> later %s" % [detail, setup_label]
		if bool(hovered_preview.get("closes_on_selected_target", false)):
			return "Move: %s -> close target" % detail
		if detail != "":
			return "Move: %s" % detail
	var movement_intent := BattleRulesScript.active_movement_board_click_intent(_battle)
	if String(movement_intent.get("action", "")) == "move":
		if bool(movement_intent.get("selected_target_blocked", false)):
			return "Move: choose destination"
		return "Move: available"
	if bool(movement_intent.get("blocked", false)) and bool(movement_intent.get("selected_target_blocked", false)):
		return "Move: unavailable"
	return ""

func _hover_destination_preview() -> Dictionary:
	if _is_legal_destination_cell(_hover_destination_cell):
		return BattleRulesScript.movement_intent_for_destination(_battle, _hover_destination_cell.x, _hover_destination_cell.y)
	return {}

func _stack_board_tooltip(battle_id: String) -> String:
	var stack := _stack_by_id(battle_id)
	if stack.is_empty():
		return tooltip_text
	var side := String(stack.get("side", ""))
	var active_side := String(_active_stack.get("side", ""))
	if active_side != "" and active_side != "player":
		if battle_id == String(_battle.get("active_stack_id", "")):
			return "Active: %s. It is not the player's turn." % String(stack.get("name", "Stack"))
		return "%s is %s stack. It is not the player's turn." % [
			String(stack.get("name", "Stack")),
			"a friendly" if side == "player" else "an enemy",
		]
	if String(_active_stack.get("side", "")) == "player" and side == "enemy":
		var continuity_context := BattleRulesScript.selected_target_continuity_context(_battle)
		if not continuity_context.is_empty() and String(continuity_context.get("battle_id", "")) == battle_id:
			return String(continuity_context.get("message", tooltip_text))
		var closing_context := BattleRulesScript.selected_target_closing_context(_battle)
		if not closing_context.is_empty() and String(closing_context.get("battle_id", "")) == battle_id:
			return String(closing_context.get("message", tooltip_text))
		var click_intent := BattleRulesScript.board_click_attack_intent_for_target(_battle, battle_id)
		var message := String(click_intent.get("message", ""))
		if message != "":
			return message
	if battle_id == String(_battle.get("active_stack_id", "")):
		return "Active: %s. Click outlined move hexes to reposition; highlighted enemies show attacks." % String(stack.get("name", "Stack"))
	if side == "player":
		return "%s is a friendly stack." % String(stack.get("name", "Stack"))
	return "%s is an enemy stack." % String(stack.get("name", "Stack"))

func _movement_board_tooltip(cell: Vector2i) -> String:
	var movement_intent := BattleRulesScript.movement_intent_for_destination(_battle, cell.x, cell.y)
	var message := String(movement_intent.get("message", ""))
	return message if message != "" else tooltip_text

func _fallback_board_tooltip() -> String:
	if String(_active_stack.get("side", "")) != "" and String(_active_stack.get("side", "")) != "player":
		return "Input locked: it is not the player's turn."
	return tooltip_text

func _unique_target_count(primary: Array, secondary: Array) -> int:
	var seen := {}
	for value in primary:
		seen[String(value)] = true
	for value in secondary:
		seen[String(value)] = true
	return seen.size()

func _stack_id_at_position(position: Vector2) -> String:
	for index in range(_stack_hit_shapes.size() - 1, -1, -1):
		var shape_value = _stack_hit_shapes[index]
		if not (shape_value is Dictionary):
			continue
		var shape: Dictionary = shape_value
		var center: Vector2 = shape.get("center", Vector2.ZERO)
		var radius := float(shape.get("radius", 0.0))
		if position.distance_to(center) <= radius:
			return String(shape.get("battle_id", ""))
	return ""

func _stack_token_radius(hex_radius: float) -> float:
	return clampf(hex_radius * 0.58, 13.0, 28.0)

func _stack_hit_shape_radius(hex_radius: float) -> float:
	return _stack_token_radius(hex_radius) + 10.0

func _neighboring_stack_hit_shape_overlap_possible(hex_radius: float) -> bool:
	return _stack_hit_shape_radius(hex_radius) >= cos(deg_to_rad(30.0)) * hex_radius

func _stack_id_at_cell(cell: Vector2i) -> String:
	if not _cell_in_bounds(cell):
		return ""
	var stack_cells := _stack_cells()
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "":
			continue
		var stack_cell: Vector2i = stack_cells.get(battle_id, Vector2i(-1, -1))
		if stack_cell == cell:
			return battle_id
	return ""

func _stack_cell_for_battle_id(battle_id: String) -> Vector2i:
	if battle_id == "":
		return Vector2i(-1, -1)
	var stack_cells := _stack_cells()
	return stack_cells.get(battle_id, Vector2i(-1, -1))

func _validation_click_position_for_cell(cell: Vector2i) -> Dictionary:
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var fallback_position := center
	var angles := [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 30.0, 90.0, 150.0, 210.0, 270.0, 330.0]
	for factor in [0.91, 0.86, 0.80, 0.72, 0.64, 0.56, 0.48]:
		for angle_degrees in angles:
			var angle := deg_to_rad(float(angle_degrees))
			var position := center + Vector2(cos(angle), sin(angle)) * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			fallback_position = position
			if _stack_id_at_position(position) == "":
				return {
					"position": position,
					"found_shape_miss_position": true,
					"hex_radius": radius,
				}
	return {
		"position": fallback_position,
		"found_shape_miss_position": false,
		"hex_radius": radius,
	}

func _validation_outer_ring_click_position_for_cell(cell: Vector2i) -> Dictionary:
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var angles := []
	for angle_index in range(24):
		angles.append(float(angle_index) * 15.0)
	for factor in [0.995, 0.99, 0.985, 0.98, 0.975, 0.97, 0.965, 0.96, 0.955, 0.95, 0.945, 0.94, 0.935, 0.93]:
		for angle_degrees in angles:
			var angle := deg_to_rad(float(angle_degrees))
			var position := center + Vector2(cos(angle), sin(angle)) * radius * float(factor)
			if position.distance_to(center) <= radius * 0.92:
				continue
			if _hex_cell_at_position(position) != cell:
				continue
			if _stack_id_at_position(position) != "":
				continue
			return {
				"position": position,
				"found_outer_ring_position": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
	return {}

func _validation_overlapped_destination_click_position_for_cell(cell: Vector2i, overlap_side: String = "player") -> Dictionary:
	if not _is_legal_destination_cell(cell):
		return {}
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var stack_cells := _stack_cells()
	var candidate_ids := []
	var active_id := String(_battle.get("active_stack_id", ""))
	if active_id != "" and overlap_side == "player":
		candidate_ids.append(active_id)
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "" or battle_id in candidate_ids:
			continue
		if overlap_side != "" and String(stack.get("side", "")) != overlap_side:
			continue
		candidate_ids.append(battle_id)
	for battle_id in candidate_ids:
		var stack_cell: Vector2i = stack_cells.get(String(battle_id), Vector2i(-1, -1))
		if not _cell_in_bounds(stack_cell) or stack_cell == cell:
			continue
		var stack_center := _hex_center(stack_cell, layout)
		var toward_stack := stack_center - center
		if toward_stack.length() <= 0.01:
			continue
		var direction := toward_stack.normalized()
		for factor in [0.86, 0.84, 0.82, 0.78, 0.74, 0.70, 0.66, 0.62, 0.58, 0.54, 0.50]:
			var position := center + direction * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			var overlap_id := _stack_id_at_position(position)
			if overlap_id == "":
				continue
			if overlap_side != "" and String(_stack_by_id(overlap_id).get("side", "")) != overlap_side:
				continue
			var overlap_result := {
				"position": position,
				"found_shape_overlap": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
			overlap_result["found_%s_shape_overlap" % overlap_side] = true
			return overlap_result
	return {}

func _validation_overlapped_occupied_hex_click_position_for_cell(cell: Vector2i, overlap_side: String = "enemy") -> Dictionary:
	var cell_battle_id := _stack_id_at_cell(cell)
	if cell_battle_id == "":
		return {}
	var layout := _current_hex_layout()
	var center := _hex_center(cell, layout)
	var radius := float(layout.get("radius", 1.0))
	var stack_cells := _stack_cells()
	var candidate_ids := []
	for stack in _all_visible_stacks():
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if battle_id == "" or battle_id == cell_battle_id:
			continue
		if overlap_side != "" and String(stack.get("side", "")) != overlap_side:
			continue
		candidate_ids.append(battle_id)
	for battle_id in candidate_ids:
		var stack_cell: Vector2i = stack_cells.get(String(battle_id), Vector2i(-1, -1))
		if not _cell_in_bounds(stack_cell) or stack_cell == cell:
			continue
		var stack_center := _hex_center(stack_cell, layout)
		var toward_stack := stack_center - center
		if toward_stack.length() <= 0.01:
			continue
		var direction := toward_stack.normalized()
		for factor in [0.86, 0.84, 0.82, 0.78, 0.74, 0.70, 0.66, 0.62, 0.58, 0.54, 0.50]:
			var position := center + direction * radius * float(factor)
			if _hex_cell_at_position(position) != cell:
				continue
			var overlap_id := _stack_id_at_position(position)
			if overlap_id == "" or overlap_id == cell_battle_id:
				continue
			if overlap_side != "" and String(_stack_by_id(overlap_id).get("side", "")) != overlap_side:
				continue
			var overlap_result := {
				"position": position,
				"found_shape_overlap": true,
				"radius_factor": float(factor),
				"hex_radius": radius,
			}
			overlap_result["found_%s_shape_overlap" % overlap_side] = true
			return overlap_result
	return {}

func _validation_fallback_tooltip_position() -> Vector2:
	var candidates := [
		Vector2(4.0, 4.0),
		Vector2(maxf(4.0, size.x - 4.0), 4.0),
		Vector2(4.0, maxf(4.0, size.y - 4.0)),
		Vector2(maxf(4.0, size.x - 4.0), maxf(4.0, size.y - 4.0)),
		Vector2(size.x * 0.5, 20.0),
		Vector2(size.x * 0.5, maxf(20.0, size.y - 20.0)),
	]
	for position in candidates:
		if position.x < 0.0 or position.y < 0.0 or position.x > size.x or position.y > size.y:
			continue
		if _hex_cell_at_position(position).x >= 0:
			continue
		if _stack_id_at_position(position) != "":
			continue
		return position
	return Vector2(-1.0, -1.0)

func _all_visible_stacks() -> Array:
	var stacks := []
	stacks.append_array(_visible_stack_list(_player_stacks))
	stacks.append_array(_visible_stack_list(_enemy_stacks))
	return stacks

func _visible_stack_list(source_stacks: Array) -> Array:
	var stacks := []
	for stack in source_stacks:
		if stack is Dictionary and _stack_visible_for_presentation(stack):
			stacks.append(stack)
	return stacks

func _stack_visible_for_presentation(stack: Dictionary) -> bool:
	if _stack_alive_count(stack) > 0:
		return true
	return not _animation_playback_record_for_stack(String(stack.get("battle_id", ""))).is_empty()

func _stack_has_cell(battle_id: String, stack_cells: Dictionary) -> bool:
	if battle_id == "" or not stack_cells.has(battle_id):
		return false
	var cell: Vector2i = stack_cells.get(battle_id)
	return cell.x >= 0 and cell.x < HEX_COLUMNS and cell.y >= 0 and cell.y < HEX_ROWS

func _stack_by_id(battle_id: String) -> Dictionary:
	for stack in _battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _stack_alive_count(stack: Dictionary) -> int:
	var unit_hp: int = maxi(1, int(stack.get("unit_hp", stack.get("hp", 1))))
	var total_health: int = maxi(0, int(stack.get("total_health", 0)))
	if total_health <= 0:
		return 0
	return int(ceil(float(total_health) / float(unit_hp)))

func _stack_health_ratio(stack: Dictionary) -> float:
	var unit_hp: int = maxi(1, int(stack.get("unit_hp", stack.get("hp", 1))))
	var base_count: int = maxi(1, int(stack.get("base_count", _stack_alive_count(stack))))
	var max_health: int = maxi(1, unit_hp * base_count)
	return clampf(float(max(0, int(stack.get("total_health", 0)))) / float(max_health), 0.0, 1.0)

func _stack_full_name(stack: Dictionary) -> String:
	var name := String(stack.get("name", stack.get("unit_id", "Stack"))).strip_edges()
	return name if name != "" else "Stack"

func _stack_short_label(stack: Dictionary) -> String:
	var name := String(stack.get("name", stack.get("unit_id", "Stack")))
	return name.left(13)

func _stack_caption_label(stack: Dictionary) -> String:
	var full_name := _stack_full_name(stack)
	if full_name.length() <= 13:
		return full_name
	var prefix := full_name.left(12)
	var boundary := prefix.rfind(" ")
	if boundary <= 0:
		return "…"
	return "%s…" % prefix.left(boundary).strip_edges()

func _side_color(side: String) -> Color:
	var fallback := PLAYER_COLOR if side == "player" else ENEMY_COLOR
	return FrontierVisualKitScript.semantic_color(side, fallback)

func _controller_color(controller: String) -> Color:
	match controller:
		"player":
			return FrontierVisualKitScript.semantic_color("player", PLAYER_COLOR)
		"enemy":
			return FrontierVisualKitScript.semantic_color("enemy", ENEMY_COLOR)
		_:
			return FrontierVisualKitScript.semantic_color("neutral", NEUTRAL_COLOR)

func _distance_label(distance: int) -> String:
	match clampi(distance, 0, 2):
		0:
			return "Engaged"
		1:
			return "Closing"
		_:
			return "Long lane"

func _draw_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_centered_text(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var font = get_theme_default_font()
	if font == null:
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(font, position - Vector2(text_size.x * 0.5, text_size.y * 0.45), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
