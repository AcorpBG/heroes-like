extends RefCounted

# Seats played by the computer in place of the human: a match with no human
# player, such as an AI-against-AI evaluation or a spectated game. The seat
# keeps its identity, towns and treasury. Its towns become computer towns and
# its heroes leave the map, so on its first turn it starts as every computer
# player does: a start hero with the faction's start army at its capital.
# Nothing ends such a match by itself; standing_players() says who is left.

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
const AI_SEAT_SOURCE := "ai_seat"

static func _overworld_rules() -> Variant:
	return load("res://scripts/core/OverworldRules.gd")

## Hands the human's seat to the computer. Returns the seat's player id, or ""
## when the session has no human seat to hand over.
static func hand_human_seat_to_ai(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or not PlayerRules.has_human_seat(session):
		return ""
	var seat := String(session.overworld.get("active_player_id", ""))
	var players: Array = session.overworld.get("players", [])
	var found := false
	for index in range(players.size()):
		var record = players[index]
		if record is Dictionary and String(record.get("player_id", "")) == seat:
			record["human"] = false
			record["computer"] = true
			record["owner"] = "enemy"
			players[index] = record
			found = true
	if not found:
		return ""
	session.overworld["players"] = players
	var overworld_rules = _overworld_rules()
	for town in session.overworld.get("towns", []).duplicate():
		if town is Dictionary and String(town.get("owner", "")) == "player":
			overworld_rules.transition_town_control(session, String(town.get("placement_id", "")), "enemy", seat, AI_SEAT_SOURCE)
	var treasury: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	session.overworld["resources"] = {"gold": 0, "wood": 0, "ore": 0}
	session.overworld["player_heroes"] = []
	session.overworld["active_hero_id"] = ""
	session.hero_id = ""
	overworld_rules.normalize_overworld_state(session)
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and PlayerRules.controller_id(state) == seat:
			state["treasury"] = treasury
			states[index] = state
	session.overworld["enemy_states"] = states
	overworld_rules.invalidate_spatial_lookup(session)
	return seat

## Players that still hold a town or a hero, in seat order. A match with no
## human seat is over once every standing player is on one team.
static func standing_players(session: SessionStateStoreScript.SessionData) -> Array:
	var result := []
	if session == null:
		return result
	var turn_rules = load("res://scripts/core/EnemyTurnRules.gd")
	for record in session.overworld.get("players", []):
		if not (record is Dictionary):
			continue
		var player_id := String(record.get("player_id", ""))
		if not turn_rules._owned_town_entries(session, player_id).is_empty() or AiHeroRulesScript.active_hero_count(session, player_id) > 0:
			result.append(player_id)
	return result

static func match_over(session: SessionStateStoreScript.SessionData) -> bool:
	var standing := standing_players(session)
	for player_id in standing:
		if not PlayerRules.allied(session, String(standing[0]), String(player_id)):
			return false
	return true
