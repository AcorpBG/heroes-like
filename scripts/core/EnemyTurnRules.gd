class_name EnemyTurnRules
extends RefCounted
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")

const TurnPlayback = preload("res://scripts/core/OverworldTurnPlayback.gd")

const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const DayEngine = preload("res://scripts/core/DayEngine.gd")
const TurnEngine = preload("res://scripts/core/TurnEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
# Computer-player state AiHeroRules keeps between days.
const AI_PLAYER_STATE_KEYS := ["ai_start_hero_granted", "ai_opening_granted", "ai_hero_counter", "ai_explored", "ai_boat_wanted_day", "ai_sightings", "ai_weight_set"]
static var TownRulesScript: Variant = load("res://scripts/core/TownRules.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")

const TRACKED_RESOURCES := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
# rebuild_pressure_request comes only from older saves (nothing writes it any
# more); it lapses after this many days.
const REBUILD_PRESSURE_LAUNCH_WINDOW_DAYS := 5

static func build_enemy_states(configs: Variant) -> Array:
	var states = []
	if not (configs is Array):
		return states

	for config in configs:
		if not (config is Dictionary):
			continue
		states.append(
			{
				"faction_id": String(config.get("faction_id", "")),
				"pressure": 0,
				"raid_counter": 0,
				"commander_counter": 0,
				"siege_progress": 0,
				"treasury": _blank_resource_pool(),
				"posture": "probing",
				"captured_artifact_ids": [],
				"commander_roster": [],
			}
		)
		for key in ["player_id", "player_slot", "team_id"]:
			if config.has(key):
				states[-1][key] = config[key]
	return states

static func normalize_enemy_states(session: SessionStateStoreScript.SessionData) -> void:
	DayEngine.native_writing(&"EnemyTurnRules.normalize_enemy_states", [session])

static func normalize_optional_hero_task_state(value: Variant) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTurnRules.normalize_optional_hero_task_state", [value])

## settle_rosters false: the caller normalizes the enemy states right after.
static func run_enemy_turn(session: SessionStateStoreScript.SessionData, settle_rosters: bool = true) -> Dictionary:
	var result: Variant = TurnEngine.native_writing(&"EnemyTurnRules.run_enemy_turn", [session, settle_rosters])
	return result if result is Dictionary else {"ok": false, "message": "", "events": []}

static func get_pressure(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return TurnEngine.native_writing(&"EnemyTurnRules.get_pressure", [session, faction_id])

static func active_raid_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return TurnEngine.native_writing(&"EnemyTurnRules.active_raid_count", [session, faction_id])

static func _faction_front_state(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTurnRules._faction_front_state", [session, faction_id])

static func _latest_enemy_state(session: SessionStateStoreScript.SessionData, faction_id: String, fallback: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTurnRules._latest_enemy_state", [session, faction_id, fallback])

static func _enemy_faction_configs_for_session(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"EnemyTurnRules._enemy_faction_configs_for_session", [session])

static func _valid_enemy_faction_configs(configs: Array) -> Array:
	return TurnEngine.native_writing(&"EnemyTurnRules._valid_enemy_faction_configs", [configs])

static func _config_was_runtime_defaulted(source: Dictionary, normalized: Dictionary) -> bool:
	return TurnEngine.native_writing(&"EnemyTurnRules._config_was_runtime_defaulted", [source, normalized])

static func _owned_town_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return TurnEngine.native_writing(&"EnemyTurnRules._owned_town_count", [session, faction_id])

static func _owned_town_entries(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	return HumanEngine.native_writing(&"EnemyTurnRules._owned_town_entries", [session, faction_id])

static func _faction_capital_state(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTurnRules._faction_capital_state", [session, faction_id])

static func _max_active_raids_for_strategy(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String, launch_policy_context: Dictionary = {}) -> int:
	return TurnEngine.native_writing(&"EnemyTurnRules._max_active_raids_for_strategy", [session, config, faction_id, launch_policy_context])

static func _enemy_recruit_cost(town: Dictionary, unit_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTurnRules._enemy_recruit_cost", [town, unit_id])

static func _blank_resource_pool() -> Dictionary:
	return HumanEngine.native(&"EnemyTurnRules._blank_resource_pool", [])

static func _town_name(town_state: Dictionary) -> String:
	return TurnEngine.native_writing(&"EnemyTurnRules._town_name", [town_state])
