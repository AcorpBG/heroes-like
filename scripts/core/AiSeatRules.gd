extends RefCounted

# Seats played by the computer in place of the human: a match with no human
# player, such as an AI-against-AI evaluation or a spectated game. The seat
# keeps its identity, towns and treasury. Its towns become computer towns and
# its heroes leave the map, so on its first turn it starts as every computer
# player does: a start hero with the faction's start army at its capital.
# Nothing ends such a match by itself; standing_players() says who is left.
# place_start_heroes() puts every computer player's start hero on the map
# before a human's first turn.
# The rules are native, one copy with match_sim_cli's seats
# (src/gdextension/rules/core/port/ai_seat_rules.cpp).

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

## Hands the human's seat to the computer. Returns the seat's player id, or ""
## when the session has no human seat to hand over.
static func hand_human_seat_to_ai(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"AiSeatRules.hand_human_seat_to_ai", [session])

## Players that still hold a town or a hero, in seat order. A match with no
## human seat is over once every standing player is on one team.
static func standing_players(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"AiSeatRules.standing_players", [session])

static func match_over(session: SessionStateStoreScript.SessionData) -> bool:
	return HumanEngine.native_writing(&"AiSeatRules.match_over", [session])

## Every computer player's start hero and start army at its capital before the
## human's first turn. Only on the session's first day; a no-op later.
static func place_start_heroes(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"AiSeatRules.place_start_heroes", [session])
