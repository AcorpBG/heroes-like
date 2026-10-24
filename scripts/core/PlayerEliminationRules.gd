extends RefCounted

## Who is still in the game on a generated map (owner decisions 2026-10-09):
## a player is out when it holds no town and no hero, or when it has held no
## town for TOWNLESS_DAYS days in a row, as in the classic games. Losing the
## starting hero does not end the game; another hero leads
## (`hand_over_primary` in core/port/battle_end_heroes.cpp). Authored scenarios keep their own
## defeat rules.
##
## Without the townless rule a beaten player kept a single hero of about 200
## strength alive for weeks, and in four of ten large-map AI games the leader
## could not finish players that held no town at all.

const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DayEngine = preload("res://scripts/core/DayEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const TOWNLESS_DAYS := 7
const NATIVE_SESSION_FLAG := "native_random_map_package_session_adoption"
## Day each player lost its last town, by player id (cleared when it takes one).
const TOWNLESS_SINCE_KEY := "townless_since"

static func applies(session: SessionStateStoreScript.SessionData) -> bool:
	return HumanEngine.native_writing(&"PlayerEliminationRules.applies", [session])

static func apply_daily(session: SessionStateStoreScript.SessionData) -> Array:
	return DayEngine.native_writing(&"PlayerEliminationRules.apply_daily", [session])

static func _defeat_human(session: SessionStateStoreScript.SessionData, summary: String) -> void:
	session.flags["campaign"] = "defeat"
	session.scenario_status = "defeat"
	if session.scenario_summary == "":
		session.scenario_summary = summary

## A computer player's heroes leave the map; its record stays, out of the game.
static func _remove_computer_player(session: SessionStateStoreScript.SessionData, player_id: String) -> void:
	var ai_heroes = _ai_heroes()
	for entry in ai_heroes.active_hero_entries(session, player_id):
		ai_heroes._mark_resolved(session, String(entry.get("placement_id", "")))
		ai_heroes._record_hero_defeat(session, player_id, entry)

static func _ai_heroes():
	# Loaded when needed: OverworldRules preloads this script.
	return load("res://scripts/core/AiHeroRules.gd")

static func _enemy_adventure():
	return load("res://scripts/core/EnemyAdventureRules.gd")
