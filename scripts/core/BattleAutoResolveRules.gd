class_name BattleAutoResolveRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleEngine = preload("res://scripts/core/BattleEngine.gd")

## A loop guard: the battle clock ends every battle first. Each of up to seven
## stacks a side may wait and then act in each of twelve rounds, and the hero
## casts once a round.
const DEFAULT_STEP_LIMIT := 240
## The next order on a player stack's turn: the hero's free cast when it
## should cast now, else the stack's own order. allow_hero_cast false asks for
## the stack's order only. An advance is carried out as the enemy's is
## (BattleRules.ai_advance_plan): a strike on the best enemy in reach, a wait
## while enemies still close in, else the walk.
static func player_autoplay_decision(session: SessionStateStoreScript.SessionData, apply_selection: bool = false, allow_hero_cast: bool = true) -> Dictionary:
	return BattleEngine.native_writing(&"BattleAutoResolveRules.player_autoplay_decision", [session, apply_selection, allow_hero_cast])

## stop_below_player_creatures > 0 ends the battle early, unresolved, once the
## player side has fewer creatures standing than that: for a caller that only
## asks whether the player wins without a loss. Nothing brings a fallen
## creature back before the battle ends except the victory recovery of the
## player's hero, so with that the battle always runs to its end.
static func resolve_active_battle(session: SessionStateStoreScript.SessionData, step_limit: int = DEFAULT_STEP_LIMIT, stop_below_player_creatures: int = 0) -> Dictionary:
	return BattleEngine.native_writing(&"BattleAutoResolveRules.resolve_active_battle", [session, step_limit, stop_below_player_creatures])

static func is_terminal_state(state: String) -> bool:
	return BattleEngine.native(&"BattleAutoResolveRules.is_terminal_state", [state])

static func _perform_player_order(session: SessionStateStoreScript.SessionData, decision: Dictionary, action: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleAutoResolveRules._perform_player_order", [session, decision, action])
