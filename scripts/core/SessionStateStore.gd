class_name SessionStateStore
extends RefCounted

const SAVE_VERSION := 9
const SUPPORTED_GAME_STATES := ["overworld", "town", "battle"]
const SUPPORTED_SCENARIO_STATUSES := ["in_progress", "victory", "defeat"]
const LAUNCH_MODE_CAMPAIGN := "campaign"
const LAUNCH_MODE_SKIRMISH := "skirmish"
const SUPPORTED_LAUNCH_MODES := [LAUNCH_MODE_CAMPAIGN, LAUNCH_MODE_SKIRMISH]

class SessionData:
	const SAVE_VERSION := 9
	const SUPPORTED_GAME_STATES := ["overworld", "town", "battle"]
	const SUPPORTED_SCENARIO_STATUSES := ["in_progress", "victory", "defeat"]
	const LAUNCH_MODE_CAMPAIGN := "campaign"
	const LAUNCH_MODE_SKIRMISH := "skirmish"
	const SUPPORTED_LAUNCH_MODES := [LAUNCH_MODE_CAMPAIGN, LAUNCH_MODE_SKIRMISH]

	var save_version: int = SAVE_VERSION
	var session_id: String = ""
	var scenario_id: String = ""
	var hero_id: String = ""
	var day: int = 1
	var difficulty: String = "normal"
	var launch_mode: String = LAUNCH_MODE_CAMPAIGN
	var game_state: String = "overworld"
	var scenario_status: String = "in_progress"
	var scenario_summary: String = ""
	var overworld: Dictionary = {}
	var battle: Dictionary = {}
	var flags: Dictionary = {}

	func _init(
		session_id: String = "",
		scenario_id: String = "",
		hero_id: String = "",
		day: int = 1,
		overworld_state: Dictionary = {},
		difficulty: String = "normal",
		launch_mode: String = LAUNCH_MODE_CAMPAIGN
	) -> void:
		self.session_id = session_id if session_id != "" else str(Time.get_ticks_msec())
		self.scenario_id = scenario_id
		self.hero_id = hero_id
		self.day = day
		self.difficulty = difficulty
		self.launch_mode = _normalize_launch_mode(launch_mode)
		self.overworld = _dict_or_empty(overworld_state)

	func _dict_or_empty(value: Variant) -> Dictionary:
		return value.duplicate(true) if value is Dictionary else {}

	func to_dict() -> Dictionary:
		return {
			"save_version": save_version,
			"session_id": session_id,
			"scenario_id": scenario_id,
			"hero_id": hero_id,
			"day": day,
			"difficulty": difficulty,
			"launch_mode": launch_mode,
			"game_state": game_state,
			"scenario_status": scenario_status,
			"scenario_summary": scenario_summary,
			"overworld": overworld.duplicate(true),
			"battle": battle.duplicate(true),
			"flags": flags.duplicate(true),
		}

	func from_dict(payload: Dictionary) -> void:
		var normalized: Dictionary = _normalize_payload(payload)
		save_version = int(normalized.get("save_version", SAVE_VERSION))
		session_id = String(normalized.get("session_id", str(Time.get_ticks_msec())))
		scenario_id = String(normalized.get("scenario_id", ""))
		hero_id = String(normalized.get("hero_id", ""))
		day = int(normalized.get("day", 1))
		difficulty = String(normalized.get("difficulty", "normal"))
		launch_mode = String(normalized.get("launch_mode", LAUNCH_MODE_CAMPAIGN))
		game_state = String(normalized.get("game_state", "overworld"))
		scenario_status = String(normalized.get("scenario_status", "in_progress"))
		scenario_summary = String(normalized.get("scenario_summary", ""))
		overworld = _dict_or_empty(normalized.get("overworld", {}))
		battle = _dict_or_empty(normalized.get("battle", {}))
		flags = _dict_or_empty(normalized.get("flags", {}))

	static func _normalize_payload(value: Variant) -> Dictionary:
		var payload: Dictionary = value if value is Dictionary else {}
		return {
			"save_version": max(0, int(payload.get("save_version", SAVE_VERSION))),
			"session_id": String(payload.get("session_id", str(Time.get_ticks_msec()))),
			"scenario_id": String(payload.get("scenario_id", "")),
			"hero_id": String(payload.get("hero_id", "")),
			"day": max(1, int(payload.get("day", 1))),
			"difficulty": String(payload.get("difficulty", "normal")),
			"launch_mode": _normalize_launch_mode(payload.get("launch_mode", LAUNCH_MODE_CAMPAIGN)),
			"game_state": _normalize_game_state(payload.get("game_state", "overworld")),
			"scenario_status": _normalize_scenario_status(payload.get("scenario_status", "in_progress")),
			"scenario_summary": String(payload.get("scenario_summary", "")),
			"overworld": _dict_or_empty_value(payload.get("overworld", {})),
			"battle": _dict_or_empty_value(payload.get("battle", {})),
			"flags": _dict_or_empty_value(payload.get("flags", {})),
		}

	static func _normalize_launch_mode(value: Variant) -> String:
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

static func normalize_payload(value: Variant) -> Dictionary:
	var payload: Dictionary = value if value is Dictionary else {}
	return {
		"save_version": max(0, int(payload.get("save_version", SAVE_VERSION))),
		"session_id": String(payload.get("session_id", str(Time.get_ticks_msec()))),
		"scenario_id": String(payload.get("scenario_id", "")),
		"hero_id": String(payload.get("hero_id", "")),
		"day": max(1, int(payload.get("day", 1))),
		"difficulty": String(payload.get("difficulty", "normal")),
		"launch_mode": normalize_launch_mode(payload.get("launch_mode", LAUNCH_MODE_CAMPAIGN)),
		"game_state": _normalize_game_state(payload.get("game_state", "overworld")),
		"scenario_status": _normalize_scenario_status(payload.get("scenario_status", "in_progress")),
		"scenario_summary": String(payload.get("scenario_summary", "")),
		"overworld": _dict_or_empty_value(payload.get("overworld", {})),
		"battle": _dict_or_empty_value(payload.get("battle", {})),
		"flags": _dict_or_empty_value(payload.get("flags", {})),
	}

static func _normalize_game_state(value: Variant) -> String:
	var game_state := String(value)
	return game_state if game_state in SUPPORTED_GAME_STATES else "overworld"

static func _normalize_scenario_status(value: Variant) -> String:
	var scenario_status := String(value)
	return scenario_status if scenario_status in SUPPORTED_SCENARIO_STATUSES else "in_progress"

static func normalize_launch_mode(value: Variant) -> String:
	var launch_mode := String(value)
	return launch_mode if launch_mode in SUPPORTED_LAUNCH_MODES else LAUNCH_MODE_CAMPAIGN

static func _dict_or_empty_value(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}

static func new_session_data(
	session_id: String = "",
	scenario_id: String = "",
	hero_id: String = "",
	day: int = 1,
	overworld_state: Dictionary = {},
	difficulty: String = "normal",
	launch_mode: String = LAUNCH_MODE_CAMPAIGN
) -> SessionData:
	return SessionData.new(session_id, scenario_id, hero_id, day, overworld_state, difficulty, launch_mode)
