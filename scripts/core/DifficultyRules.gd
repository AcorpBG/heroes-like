class_name DifficultyRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleEngine = preload("res://scripts/core/BattleEngine.gd")
static var _battle_engine_mode: int = BattleEngine.mode

const DIFFICULTY_PROFILES := {
	"story": {
		"movement_bonus": 2,
		"income_multiplier": 1.25,
		"reward_multiplier": 1.25,
		"enemy_pressure_bonus": -1,
		"raid_threshold_offset": 1,
		"raid_pillage_multiplier": 0.75,
		"player_damage_multiplier": 1.1,
		"enemy_damage_multiplier": 0.9,
		"player_initiative_bonus": 1,
		"enemy_initiative_bonus": 0,
	},
	"normal": {
		"movement_bonus": 0,
		"income_multiplier": 1.0,
		"reward_multiplier": 1.0,
		"enemy_pressure_bonus": 0,
		"raid_threshold_offset": 0,
		"raid_pillage_multiplier": 1.0,
		"player_damage_multiplier": 1.0,
		"enemy_damage_multiplier": 1.0,
		"player_initiative_bonus": 0,
		"enemy_initiative_bonus": 0,
	},
	"hard": {
		"movement_bonus": -1,
		"income_multiplier": 0.85,
		"reward_multiplier": 0.85,
		"enemy_pressure_bonus": 1,
		"raid_threshold_offset": -1,
		"raid_pillage_multiplier": 1.25,
		"player_damage_multiplier": 0.95,
		"enemy_damage_multiplier": 1.05,
		"player_initiative_bonus": 0,
		"enemy_initiative_bonus": 1,
	},
}

static func _scenario_select_rules() -> Variant:
	return load("res://scripts/core/ScenarioSelectRules.gd")

static func _default_difficulty_id() -> String:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return _default_difficulty_id__gd()
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"DifficultyRules._default_difficulty_id", [])
	var result = _default_difficulty_id__gd()
	BattleEngine.check(&"DifficultyRules._default_difficulty_id", [], result)
	return result

static func _default_difficulty_id__gd() -> String:
	return _scenario_select_rules().default_difficulty_id()

static func normalize_difficulty(value: Variant) -> String:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return normalize_difficulty__gd(value)
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"DifficultyRules.normalize_difficulty", [value])
	var result = normalize_difficulty__gd(value)
	BattleEngine.check(&"DifficultyRules.normalize_difficulty", [value], result)
	return result

static func normalize_difficulty__gd(value: Variant) -> String:
	return _scenario_select_rules().normalize_difficulty(value)

static func profile_for_difficulty(difficulty_id: Variant) -> Dictionary:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return profile_for_difficulty__gd(difficulty_id)
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"DifficultyRules.profile_for_difficulty", [difficulty_id])
	var result = profile_for_difficulty__gd(difficulty_id)
	BattleEngine.check(&"DifficultyRules.profile_for_difficulty", [difficulty_id], result)
	return result

static func profile_for_difficulty__gd(difficulty_id: Variant) -> Dictionary:
	var normalized_id := normalize_difficulty(difficulty_id)
	return DIFFICULTY_PROFILES.get(normalized_id, DIFFICULTY_PROFILES[_default_difficulty_id()]).duplicate(true)

static func profile_for_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return profile_for_session__gd(session)
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"DifficultyRules.profile_for_session", [session])
	var result = profile_for_session__gd(session)
	BattleEngine.check(&"DifficultyRules.profile_for_session", [session], result)
	return result

static func profile_for_session__gd(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return profile_for_difficulty(_default_difficulty_id())
	return profile_for_difficulty(session.difficulty)

static func normalize_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return profile_for_difficulty(_default_difficulty_id())
	session.difficulty = normalize_difficulty(session.difficulty)
	return profile_for_session(session)

static func movement_bonus(session: SessionStateStoreScript.SessionData) -> int:
	return int(profile_for_session(session).get("movement_bonus", 0))

static func scale_income_resources(session: SessionStateStoreScript.SessionData, payload: Variant) -> Dictionary:
	return scale_resource_payload(payload, float(profile_for_session(session).get("income_multiplier", 1.0)))

static func scale_reward_resources(session: SessionStateStoreScript.SessionData, payload: Variant) -> Dictionary:
	return scale_resource_payload(payload, float(profile_for_session(session).get("reward_multiplier", 1.0)))

static func adjust_enemy_pressure_gain(session: SessionStateStoreScript.SessionData, base_gain: int) -> int:
	var profile := profile_for_session(session)
	return max(0, base_gain + int(profile.get("enemy_pressure_bonus", 0)))

static func adjust_raid_threshold(session: SessionStateStoreScript.SessionData, base_threshold: int) -> int:
	var profile := profile_for_session(session)
	return max(1, base_threshold + int(profile.get("raid_threshold_offset", 0)))

static func scale_raid_pillage(session: SessionStateStoreScript.SessionData, payload: Variant) -> Dictionary:
	return scale_resource_payload(payload, float(profile_for_session(session).get("raid_pillage_multiplier", 1.0)))

static func initiative_bonus_for_side(session: SessionStateStoreScript.SessionData, side: String) -> int:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return initiative_bonus_for_side__gd(session, side)
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"DifficultyRules.initiative_bonus_for_side", [session, side])
	var result = initiative_bonus_for_side__gd(session, side)
	BattleEngine.check(&"DifficultyRules.initiative_bonus_for_side", [session, side], result)
	return result

static func initiative_bonus_for_side__gd(session: SessionStateStoreScript.SessionData, side: String) -> int:
	var profile := profile_for_session(session)
	var key := "player_initiative_bonus" if side == "player" else "enemy_initiative_bonus"
	return int(profile.get(key, 0))

static func damage_multiplier_for_side(session: SessionStateStoreScript.SessionData, side: String) -> float:
	if _battle_engine_mode == BattleEngine.GDSCRIPT:
		return damage_multiplier_for_side__gd(session, side)
	if _battle_engine_mode == BattleEngine.NATIVE:
		return BattleEngine.native(&"DifficultyRules.damage_multiplier_for_side", [session, side])
	var result = damage_multiplier_for_side__gd(session, side)
	BattleEngine.check(&"DifficultyRules.damage_multiplier_for_side", [session, side], result)
	return result

static func damage_multiplier_for_side__gd(session: SessionStateStoreScript.SessionData, side: String) -> float:
	var profile := profile_for_session(session)
	var key := "player_damage_multiplier" if side == "player" else "enemy_damage_multiplier"
	return float(profile.get(key, 1.0))

static func scale_resource_payload(payload: Variant, multiplier: float) -> Dictionary:
	var scaled := {}
	if not (payload is Dictionary):
		return scaled
	for key in payload.keys():
		scaled[String(key)] = _scale_amount(int(payload[key]), multiplier)
	return scaled

static func _scale_amount(amount: int, multiplier: float) -> int:
	if amount == 0 or is_equal_approx(multiplier, 1.0):
		return amount
	var scaled := int(round(float(amount) * multiplier))
	if amount > 0 and scaled <= 0:
		return 1
	if amount < 0 and scaled >= 0:
		return -1
	return scaled
