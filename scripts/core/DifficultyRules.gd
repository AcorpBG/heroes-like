class_name DifficultyRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleEngine = preload("res://scripts/core/BattleEngine.gd")

static func _default_difficulty_id() -> String:
	return BattleEngine.native(&"DifficultyRules._default_difficulty_id", [])

static func normalize_difficulty(value: Variant) -> String:
	return BattleEngine.native(&"DifficultyRules.normalize_difficulty", [value])

static func profile_for_difficulty(difficulty_id: Variant) -> Dictionary:
	return BattleEngine.native(&"DifficultyRules.profile_for_difficulty", [difficulty_id])

static func profile_for_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return BattleEngine.native(&"DifficultyRules.profile_for_session", [session])

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

static func scale_raid_pillage(session: SessionStateStoreScript.SessionData, payload: Variant) -> Dictionary:
	return scale_resource_payload(payload, float(profile_for_session(session).get("raid_pillage_multiplier", 1.0)))

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
