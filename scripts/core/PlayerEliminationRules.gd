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

const TOWNLESS_DAYS := 7
const NATIVE_SESSION_FLAG := "native_random_map_package_session_adoption"
## Day each player lost its last town, by player id (cleared when it takes one).
const TOWNLESS_SINCE_KEY := "townless_since"

static func applies(session: SessionStateStoreScript.SessionData) -> bool:
	return session != null and bool(session.flags.get(NATIVE_SESSION_FLAG, false))

## Towns a player holds: the human's are owner "player", a computer player's
## owner "enemy" under its id.
static func towns_held(session: SessionStateStoreScript.SessionData, player: Dictionary) -> int:
	var player_id := String(player.get("player_id", ""))
	var count := 0
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var owner := String(town.get("owner", "neutral"))
		if bool(player.get("human", false)):
			if owner == "player":
				count += 1
		elif owner == "enemy" and PlayerRules.town_controller_id(town) == player_id:
			count += 1
	return count

static func heroes_held(session: SessionStateStoreScript.SessionData, player: Dictionary) -> int:
	if bool(player.get("human", false)):
		return (session.overworld.get("player_heroes", []) as Array).size()
	return _ai_heroes().active_hero_count(session, String(player.get("player_id", "")))

## Runs once a day, after every player has moved. Counts the days each player
## has gone without a town, removes computer players whose time is up and ends
## the game for the human whose time is up. Returns messages for the human.
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
