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
