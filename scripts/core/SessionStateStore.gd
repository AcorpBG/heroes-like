class_name SessionStateStore
extends RefCounted

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var _human_engine_mode: int = HumanEngine.mode

const SAVE_VERSION := 9
const SUPPORTED_GAME_STATES := ["overworld", "town", "battle", "outcome"]
const SUPPORTED_SCENARIO_STATUSES := ["in_progress", "victory", "defeat"]
const LAUNCH_MODE_CAMPAIGN := "campaign"
const LAUNCH_MODE_SKIRMISH := "skirmish"
const LAUNCH_MODE_GENERATED_DRAFT := "generated_draft"
const SUPPORTED_LAUNCH_MODES := [LAUNCH_MODE_CAMPAIGN, LAUNCH_MODE_SKIRMISH, LAUNCH_MODE_GENERATED_DRAFT]
const GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG := "generated_random_map_materialization"
const GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY := "generated_map_runtime_materialization"

class SessionData:
	const SAVE_VERSION := 9
	const SUPPORTED_GAME_STATES := ["overworld", "town", "battle", "outcome"]
	const SUPPORTED_SCENARIO_STATUSES := ["in_progress", "victory", "defeat"]
	const LAUNCH_MODE_CAMPAIGN := "campaign"
	const LAUNCH_MODE_SKIRMISH := "skirmish"
	const LAUNCH_MODE_GENERATED_DRAFT := "generated_draft"
	const SUPPORTED_LAUNCH_MODES := [LAUNCH_MODE_CAMPAIGN, LAUNCH_MODE_SKIRMISH, LAUNCH_MODE_GENERATED_DRAFT]
	const GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG := "generated_random_map_materialization"
	const GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY := "generated_map_runtime_materialization"
	const NATIVE_PACKAGE_SESSION_FLAG := "native_random_map_package_session_adoption"
	const NATIVE_RUNTIME_SCENARIO_RECORD_KEY := "native_random_map_runtime_scenario_record"

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
		self.launch_mode = SessionStateStore.normalize_launch_mode(launch_mode)
		self.overworld = overworld_state.duplicate(true)

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

	# The payload normalized natively: its overworld, battle and flags are
	# copies, and flags share the overworld's runtime scenario record.
	func from_dict(payload: Dictionary) -> void:
		var normalized: Dictionary = SessionStateStore.normalize_payload(payload)
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
		overworld = normalized["overworld"]
		battle = normalized["battle"]
		flags = normalized["flags"]

static func normalize_payload(value: Variant) -> Dictionary:
	return HumanEngine.native_writing(&"SessionStateStore.normalize_payload", [value])

static func normalize_launch_mode(value: Variant) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return normalize_launch_mode__gd(value)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"SessionStateStore.normalize_launch_mode", [value])
	var before := HumanEngine.before_writing(&"SessionStateStore.normalize_launch_mode", [value])
	var result = normalize_launch_mode__gd(value)
	HumanEngine.check_writing(&"SessionStateStore.normalize_launch_mode", before, [value], result)
	return result

static func normalize_launch_mode__gd(value: Variant) -> String:
	var launch_mode := String(value)
	return launch_mode if launch_mode in SUPPORTED_LAUNCH_MODES else LAUNCH_MODE_CAMPAIGN

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
