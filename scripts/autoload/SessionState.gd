extends Node

const SessionStateStore = preload("res://scripts/core/SessionStateStore.gd")

const SAVE_VERSION := 9
const SUPPORTED_GAME_STATES := ["overworld", "town", "battle"]
const SUPPORTED_SCENARIO_STATUSES := ["in_progress", "victory", "defeat"]
const LAUNCH_MODE_CAMPAIGN := "campaign"
const LAUNCH_MODE_SKIRMISH := "skirmish"
const SUPPORTED_LAUNCH_MODES := [LAUNCH_MODE_CAMPAIGN, LAUNCH_MODE_SKIRMISH]

var active_session: SessionStateStore.SessionData = null

static func normalize_payload(value: Variant) -> Dictionary:
	var normalized: Dictionary = SessionStateStore.normalize_payload(value)
	return {
		"save_version": max(0, int(normalized.get("save_version", SAVE_VERSION))),
		"session_id": String(normalized.get("session_id", str(Time.get_ticks_msec()))),
		"scenario_id": String(normalized.get("scenario_id", "")),
		"hero_id": String(normalized.get("hero_id", "")),
		"day": max(1, int(normalized.get("day", 1))),
		"difficulty": String(normalized.get("difficulty", "normal")),
		"launch_mode": normalize_launch_mode(normalized.get("launch_mode", LAUNCH_MODE_CAMPAIGN)),
		"game_state": _normalize_game_state(normalized.get("game_state", "overworld")),
		"scenario_status": _normalize_scenario_status(normalized.get("scenario_status", "in_progress")),
		"scenario_summary": String(normalized.get("scenario_summary", "")),
		"overworld": _dict_or_empty_value(normalized.get("overworld", {})),
		"battle": _dict_or_empty_value(normalized.get("battle", {})),
		"flags": _dict_or_empty_value(normalized.get("flags", {})),
	}

static func normalize_launch_mode(value: Variant) -> String:
	var launch_mode := String(value)
	return launch_mode if launch_mode in SUPPORTED_LAUNCH_MODES else LAUNCH_MODE_CAMPAIGN

static func _normalize_game_state(value: Variant) -> String:
	var game_state := String(value)
	return game_state if game_state in SUPPORTED_GAME_STATES else "overworld"

static func _normalize_scenario_status(value: Variant) -> String:
	var scenario_status := String(value)
	return scenario_status if scenario_status in SUPPORTED_SCENARIO_STATUSES else "in_progress"

static func _dict_or_empty_value(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

func _ready() -> void:
	ensure_active_session()

func reset_session() -> void:
	active_session = SessionStateStore.new_session_data()

func ensure_active_session() -> SessionStateStore.SessionData:
	if active_session == null:
		active_session = SessionStateStore.new_session_data()
	return active_session

func has_playable_session() -> bool:
	return ensure_active_session().scenario_id != ""

func has_battle_state() -> bool:
	return has_playable_session() and not ensure_active_session().battle.is_empty()

func set_active_session(session: SessionStateStore.SessionData) -> SessionStateStore.SessionData:
	if session == null:
		reset_session()
		return active_session
	active_session = _normalized_session_copy(session.to_dict())
	return active_session

func restore_session(payload: Variant) -> SessionStateStore.SessionData:
	active_session = _normalized_session_copy(payload)
	return active_session

func duplicate_active_session() -> SessionStateStore.SessionData:
	return _normalized_session_copy(ensure_active_session().to_dict())

func current_payload() -> Dictionary:
	return ensure_active_session().to_dict()

func clear_battle_state() -> void:
	var session := ensure_active_session()
	session.battle = {}
	if session.game_state == "battle":
		session.game_state = "overworld"

func is_campaign_session() -> bool:
	return normalize_launch_mode(ensure_active_session().launch_mode) == LAUNCH_MODE_CAMPAIGN

func is_skirmish_session() -> bool:
	return normalize_launch_mode(ensure_active_session().launch_mode) == LAUNCH_MODE_SKIRMISH

func _normalized_session_copy(value: Variant) -> SessionStateStore.SessionData:
	var session := SessionStateStore.new_session_data()
	session.from_dict(normalize_payload(value))
	session.save_version = SAVE_VERSION
	return session
