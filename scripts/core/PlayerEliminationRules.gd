extends RefCounted

## Who is still in the game on a generated map (owner decisions 2026-10-09):
## a player is out when it holds no town and no hero, or when it has held no
## town for TOWNLESS_DAYS days in a row, as in the classic games. Losing the
## starting hero does not end the game; another hero leads
## (`HeroCommandRules.hand_over_primary`). Authored scenarios keep their own
## defeat rules.
##
## Without the townless rule a beaten player kept a single hero of about 200
## strength alive for weeks, and in four of ten large-map AI games the leader
## could not finish players that held no town at all.

const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

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

## Whether the human has neither a town nor a hero left.
static func human_has_nothing_left(session: SessionStateStoreScript.SessionData) -> bool:
	for player in session.overworld.get("players", []):
		if player is Dictionary and bool(player.get("human", false)):
			return towns_held(session, player) == 0 and heroes_held(session, player) == 0
	return false

## Runs once a day, after every player has moved. Counts the days each player
## has gone without a town, removes computer players whose time is up and ends
## the game for the human whose time is up. Returns messages for the human.
static func apply_daily(session: SessionStateStoreScript.SessionData) -> Array:
	var messages := []
	if not applies(session):
		return messages
	var since: Dictionary = session.overworld.get(TOWNLESS_SINCE_KEY, {}) if session.overworld.get(TOWNLESS_SINCE_KEY, {}) is Dictionary else {}
	var rosters_settled := false
	for player in session.overworld.get("players", []):
		if not (player is Dictionary):
			continue
		var player_id := String(player.get("player_id", ""))
		var human := bool(player.get("human", false))
		if towns_held(session, player) > 0:
			since.erase(player_id)
			continue
		if heroes_held(session, player) == 0:
			since.erase(player_id)
			if human and session.scenario_status == "in_progress":
				_defeat_human(session, "Your realm has no town and no hero left.")
			continue
		if not since.has(player_id):
			since[player_id] = int(session.day)
		var left := TOWNLESS_DAYS - (int(session.day) - int(since[player_id]))
		if left > 0:
			if human:
				messages.append("You hold no town. Take one within %d day%s or your realm falls." % [left, "" if left == 1 else "s"])
			continue
		since.erase(player_id)
		if human:
			_defeat_human(session, "Your realm has held no town for %d days." % TOWNLESS_DAYS)
		else:
			if not rosters_settled:
				# The enemy turn leaves its rosters to the scenario check after this.
				_enemy_adventure().normalize_all_commander_rosters(session)
				rosters_settled = true
			_remove_computer_player(session, player_id)
			messages.append("%s has held no town for %d days and leaves the war." % [String(ContentService.get_faction(String(player.get("faction_id", ""))).get("name", player_id)), TOWNLESS_DAYS])
	session.overworld[TOWNLESS_SINCE_KEY] = since
	return messages

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
