extends RefCounted

const KEY := "_live_turn_playback"
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")

static func begin(session) -> void:
	session.overworld[KEY] = []

static func finish(session) -> Array:
	var records: Array = session.overworld.get(KEY, [])
	session.overworld.erase(KEY)
	return records
