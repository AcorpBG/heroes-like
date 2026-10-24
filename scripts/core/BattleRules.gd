class_name BattleRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const TownBattle = preload("res://scripts/core/TownBattleRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")
const ActionPlayback = preload("res://scripts/core/BattleActionPlayback.gd")
const Footprint = preload("res://scripts/core/BattleFootprint.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const BattleEngine = preload("res://scripts/core/BattleEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

# One immutable battle snapshot, bounded target/action entries. Never saved;
# repeated hover and the legacy summaries share the same exact exchange.
static var _consequence_cache_battle: Dictionary = {}
static var _consequence_cache: Dictionary = {}
# Last resolved hero payload per side, reused while its source dictionaries
# compare equal. Building one deep-copies and re-normalizes the commander, and
# every trait, initiative and damage check asks for it. Never saved.
static var _hero_payload_cache: Dictionary = {}
# The presentation queue _append_presentation_event stored last, never changed
# in place afterwards: all its entries but the last are normalized, so the next
# append onto it normalizes only that one. Never saved.
static var _presentation_queue_written: Array = []

const STATUS_HARRIED := "status_harried"
const STATUS_STAGGERED := "status_staggered"
const STATUS_ROOTED := "status_rooted"
const STATUS_OVERHEATED := "status_overheated"
const TACTICAL_BRIEFING_KEY := "tactical_briefing"
const FIELD_OBJECTIVES_KEY := "field_objectives"
const STACK_HEX_KEY := "hex"
# Obstacles block standing and movement, never shots. A record is
# {id, kind, size, variant, cells}: the cells are the rule, kind and variant pick the art.
const OBSTACLES_KEY := "obstacles"
const OBSTACLE_KINDS := ["rock", "deadwood"]
const OBSTACLE_VARIANT_COUNT := 25
const STACK_ANIMATION_STATES_KEY := "stack_animation_states"
const ANIMATION_EVENT_SERIAL_KEY := "animation_event_serial"
const ANIMATION_EVENT_QUEUE_KEY := "battle_animation_events"
const PRESENTATION_EVENT_QUEUE_KEY := "battle_presentation_events"
const PRESENTATION_SPEED_KEY := "battle_presentation_speed"
const PRESENTATION_SPEED_NORMAL := "normal"
const PRESENTATION_SPEED_FAST := "fast"
const PRESENTATION_SPEED_INSTANT := "instant"
const DAMAGE_RNG_VERSION_KEY := "damage_rng_version"
const DAMAGE_RNG_STATE_KEY := "damage_rng_state"
const DAMAGE_RNG_ROLL_COUNT_KEY := "damage_rng_roll_count"
const DAMAGE_RNG_INTEGRITY_KEY := "damage_rng_integrity"
const DAMAGE_RNG_VERSION := 1
# A hero casts from beside its army, not from a stack: its animation and
# presentation events name it "hero:player" or "hero:enemy".
const HERO_ACTOR_PREFIX := "hero:"
# Stacks that waited this round, in the order they waited; cleared each round.
const WAITED_STACK_IDS_KEY := "waited_stack_ids"
# How many orders the player has given in this battle (player_has_given_orders).
const PLAYER_ORDERS_KEY := "player_orders_given"
const BATTLE_HEX_COLUMNS := 11
const BATTLE_HEX_ROWS := 9
const COHESION_MAX := 10
const MOMENTUM_MAX := 4
static func create_town_assault_payload(session: SessionStateStoreScript.SessionData, town_placement_id: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.create_town_assault_payload", [session, town_placement_id])

static func create_resource_defense_payload(session: SessionStateStoreScript.SessionData, resource_placement_id: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.create_resource_defense_payload", [session, resource_placement_id])

## A hero attacks the guard of a tier 5+ creature dwelling. The guard is a
## plain neutral encounter keyed "dwelling_guard:<placement>", so the battle
## resolves through the normal encounter flow; only its outcome is written back
## to the dwelling (see update_dwelling_guard_after_battle in core/port/battle_end_sites.cpp).
static func create_dwelling_guard_payload(session: SessionStateStoreScript.SessionData, resource_placement_id: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.create_dwelling_guard_payload", [session, resource_placement_id])

static func create_battle_payload(session: SessionStateStoreScript.SessionData, encounter_placement: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.create_battle_payload", [session, encounter_placement])

static func normalize_battle_state_bridge(session) -> bool:
	return normalize_battle_state(session)

static func battle_payload_can_resume_bridge(session) -> bool:
	return battle_payload_can_resume(session)

static func battle_payload_can_resume(session: SessionStateStoreScript.SessionData) -> bool:
	return BattleEngine.native_writing(&"BattleRules.battle_payload_can_resume", [session])

static func _battle_context_town_placement_id(session: SessionStateStoreScript.SessionData, context: Dictionary, raw_context: Variant) -> String:
	return BattleEngine.native_writing(&"BattleRules._battle_context_town_placement_id", [session, context, raw_context])

static func _battle_context_resource_placement_id(context: Dictionary, raw_context: Variant) -> String:
	return BattleEngine.native_writing(&"BattleRules._battle_context_resource_placement_id", [context, raw_context])

static func _battle_context_trigger_faction_id(session: SessionStateStoreScript.SessionData, context: Dictionary, raw_context: Variant, town: Dictionary = {}) -> String:
	return BattleEngine.native_writing(&"BattleRules._battle_context_trigger_faction_id", [session, context, raw_context, town])

static func _find_town_at_position(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = 0) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._find_town_at_position", [session, x, y, level])

static func _battle_context_controller_id(session: SessionStateStoreScript.SessionData, context: Dictionary, raw_context: Variant = {}) -> String:
	return BattleEngine.native_writing(&"BattleRules._battle_context_controller_id", [session, context, raw_context])

static func _is_town_defense_context(context: Variant) -> bool:
	return BattleEngine.native(&"BattleRules._is_town_defense_context", [context])

static func _is_town_assault_context(context: Variant) -> bool:
	return BattleEngine.native(&"BattleRules._is_town_assault_context", [context])

static func _is_resource_assault_context(context: Variant) -> bool:
	return BattleEngine.native_writing(&"BattleRules._is_resource_assault_context", [context])

static func _battle_retreat_allowed(battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._battle_retreat_allowed", [battle])

static func _battle_surrender_allowed(battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._battle_surrender_allowed", [battle])

## Whether the enemy side may retreat or surrender. Only a force a player owns
## (an AI hero, or a hero holding a site) keeps its survivors when it leaves the
## field. A neutral guard has nowhere to go, so it fights to the end; its units
## may still belong to a faction, so the stacks' faction does not count.
static func _enemy_withdrawal_allowed(session: SessionStateStoreScript.SessionData, battle_context: Dictionary, encounter_placement: Dictionary) -> bool:
	return HumanEngine.native_writing(&"BattleRules._enemy_withdrawal_allowed", [session, battle_context, encounter_placement])

static func _withdrawal_pressure_label(battle: Dictionary, allowed: bool) -> String:
	return HumanEngine.native_writing(&"BattleRules._withdrawal_pressure_label", [battle, allowed])

static func _player_commander_state(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return BattleEngine.native(&"BattleRules._player_commander_state", [session])

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._find_town_by_placement", [session, placement_id])

static func _town_name_from_placement_id(session: SessionStateStoreScript.SessionData, placement_id: String) -> String:
	return BattleEngine.native_writing(&"BattleRules._town_name_from_placement_id", [session, placement_id])

static func _town_name(town: Dictionary) -> String:
	return BattleEngine.native_writing(&"BattleRules._town_name", [town])

static func normalize_battle_state(session: SessionStateStoreScript.SessionData) -> bool:
	return BattleEngine.native_writing(&"BattleRules.normalize_battle_state", [session])

static func resolve_if_battle_ready(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.resolve_if_battle_ready", [session])

static func get_active_stack(battle: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules.get_active_stack", [battle])

static func get_selected_target(battle: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules.get_selected_target", [battle])

static func select_target(session: SessionStateStoreScript.SessionData, battle_id: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.select_target", [session, battle_id])

static func battle_occupancy_map(battle: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.battle_occupancy_map", [battle])

static func legal_destinations_for_active_stack(battle: Dictionary) -> Array:
	return BattleEngine.native_writing(&"BattleRules.legal_destinations_for_active_stack", [battle])

static func legal_destinations_for_stack(battle: Dictionary, battle_id: String) -> Array:
	return BattleEngine.native_writing(&"BattleRules.legal_destinations_for_stack", [battle, battle_id])

static func legal_attack_targets_for_active_stack(battle: Dictionary, ranged: bool = false) -> Array:
	return BattleEngine.native_writing(&"BattleRules.legal_attack_targets_for_active_stack", [battle, ranged])

static func legal_attack_target_ids_for_active_stack(battle: Dictionary) -> Array:
	return HumanEngine.native_writing(&"BattleRules.legal_attack_target_ids_for_active_stack", [battle])

static func selected_target_legality(battle: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.selected_target_legality", [battle])

static func selected_target_board_click_intent(battle: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.selected_target_board_click_intent", [battle])

static func selected_target_continuity_context(battle: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.selected_target_continuity_context", [battle])

## clear_stale: false makes this a pure query (for drawing); by default a
## stale or superseded closing target is also erased from the battle.
static func selected_target_closing_context(battle: Dictionary, clear_stale: bool = true) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.selected_target_closing_context", [battle, clear_stale])

static func active_movement_board_click_intent(battle: Dictionary, preloaded_legal_destinations: Variant = null) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.active_movement_board_click_intent", [battle, preloaded_legal_destinations])

static func movement_intent_for_destination(battle: Dictionary, q: int, r: int, preloaded_legal_destinations: Variant = null) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.movement_intent_for_destination", [battle, q, r, preloaded_legal_destinations])

static func board_click_attack_intent_for_target(battle: Dictionary, battle_id: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.board_click_attack_intent_for_target", [battle, battle_id])

static func _movement_intent_skeleton(battle: Dictionary, active_stack: Dictionary, destination: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._movement_intent_skeleton", [battle, active_stack, destination])

static func _movement_intent_message(battle: Dictionary, active_stack: Dictionary, destination: Dictionary, destination_count: int) -> String:
	return BattleEngine.native_writing(&"BattleRules._movement_intent_message", [battle, active_stack, destination, destination_count])

static func melee_approach_destination(battle: Dictionary, stack: Dictionary, target: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.melee_approach_destination", [battle, stack, target])

## Every hex the stack can strike target from this turn: the hex it stands on
## when it can already strike from there (two hexes off counts with reach or a
## hookline), then each hex next to the target it can reach this turn, in
## walking order. A stack that walks always ends next to the target. A two-hex
## body lists each placement by its head's hex; strike_q and strike_r give the
## body cell nearest the target and strike_part says whether that is the head
## or the tail. A rooted stack strikes only from where it stands.
static func melee_approach_cells(battle: Dictionary, stack: Dictionary, target: Dictionary) -> Array:
	return BattleEngine.native_writing(&"BattleRules.melee_approach_cells", [battle, stack, target])

## The hex a computer-driven stack strikes target from: the legal approach the
## AI scores best (the native BattleAiRules.choose_melee_approach), or {} when it cannot
## strike target this turn.
static func ai_melee_approach(battle: Dictionary, stack: Dictionary, target: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.ai_melee_approach", [battle, stack, target])

## How a computer-driven stack carries out an advance order
## (the native BattleAiRules.advance_plan): a strike on the best enemy in reach, a wait,
## the walk, or a defend for a rooted stack.
static func ai_advance_plan(battle: Dictionary, stack: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.ai_advance_plan", [battle, stack])

## Whether extra movement points would let the stack reach a hex next to an
## enemy this turn when it reaches none now (the AI weighs haste by it).
static func extra_speed_reaches_strike(battle: Dictionary, stack: Dictionary, extra: int) -> bool:
	return BattleEngine.native_writing(&"BattleRules.extra_speed_reaches_strike", [battle, stack, extra])

static func _attack_legality_for_target(active_stack: Dictionary, target: Dictionary, battle: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._attack_legality_for_target", [active_stack, target, battle])

static func battle_hex_state_summary(battle: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.battle_hex_state_summary", [battle])

static func cycle_target(session: SessionStateStoreScript.SessionData, direction: int) -> void:
	HumanEngine.native_writing(&"BattleRules.cycle_target", [session, direction])

static func spell_target_ids(session: SessionStateStoreScript.SessionData, spell_id: String) -> Array:
	return HumanEngine.native_writing(&"BattleRules.spell_target_ids", [session, spell_id])

static func describe_spellbook(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return "Battle Spells | Mana 0/0 | No known spells"
	var battle = session.battle if not session.battle.is_empty() else {}
	var summary := SpellRulesScript.describe_battle_spellbook(
		_player_commander_state(session),
		battle,
		get_active_stack(battle) if not battle.is_empty() else {},
		get_selected_target(battle) if not battle.is_empty() else {}
	)
	if not session.battle.is_empty() and _commander_spell_cast_this_round(session.battle, "player"):
		summary += " | Commander spell already cast this round"
	return summary

static func _player_input_locked_summary() -> String:
	return BattleEngine.native(&"BattleRules._player_input_locked_summary", [])

static func get_spell_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"BattleRules.get_spell_actions", [session])

static func describe_header(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Battle"
	var battle = session.battle
	return String(battle.get("encounter_name", battle.get("encounter_id", "Battle")))

static func describe_status(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Round 0 | Battlefield unavailable"
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var status = "Round %d/%d | %s | Terrain %s | %s | Active %s" % [
		int(battle.get("round", 1)),
		int(battle.get("max_rounds", 12)),
		_battle_context_label(session, battle.get("context", {})),
		String(battle.get("terrain", "plains")).capitalize(),
		_distance_label(int(battle.get("distance", 1))),
		String(active_stack.get("name", "No active stack")),
	]
	var objective_brief = _field_objective_status_brief(battle)
	if objective_brief != "":
		status += " | %s" % objective_brief
	return status

static func describe_entry_context(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"BattleRules.describe_entry_context", [session])

static func describe_pressure(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Outcome pressure unavailable."
	var battle = session.battle
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	var rounds_remaining = max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1)
	var lines = [
		"Friendly line: %d stacks | %d units | %d HP" % [
			int(player_totals.get("stacks", 0)),
			int(player_totals.get("units", 0)),
			int(player_totals.get("health", 0)),
		],
		"Enemy line: %d stacks | %d units | %d HP" % [
			int(enemy_totals.get("stacks", 0)),
			int(enemy_totals.get("units", 0)),
			int(enemy_totals.get("health", 0)),
		],
		"Clock: %d rounds before stalemate" % rounds_remaining,
	]
	var battlefront_summary = _battlefield_identity_summary(battle)
	if battlefront_summary != "":
		lines.append("Battlefront: %s" % battlefront_summary)
	var terrain_effect = _terrain_effect_brief(battle)
	if terrain_effect != "":
		lines.append("Terrain effect: %s" % terrain_effect)
	var objective_pressure = _field_objective_pressure_summary(battle)
	if objective_pressure != "":
		lines.append("Objective pressure: %s" % objective_pressure)
	lines.append("Pressure: %s" % _pressure_brief(session))
	lines.append("Retreat: %s" % _withdrawal_pressure_label(battle, _battle_retreat_allowed(battle)))
	lines.append("Surrender: %s" % _withdrawal_pressure_label(battle, _battle_surrender_allowed(battle)))
	return "\n".join(lines)

static func consume_tactical_briefing(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"BattleRules.consume_tactical_briefing", [session])

static func describe_commander_summary(session: SessionStateStoreScript.SessionData, side: String) -> String:
	if session == null or session.battle.is_empty():
		return "Commander summary unavailable."
	var battle = session.battle
	var commander_state = _commander_state_for_side(battle, side)
	var commander_payload = _hero_payload_for_side(battle, side)
	var command = commander_state.get("command", {}) if commander_state is Dictionary else {}
	var army_totals = _army_totals(battle, side)
	if commander_state.is_empty():
		return "\n".join(
			[
				"No named commander is attached to this force.",
				"Army: %d stacks | %d units | %d HP | %d ranged" % [
					int(army_totals.get("stacks", 0)),
					int(army_totals.get("units", 0)),
					int(army_totals.get("health", 0)),
					int(army_totals.get("ranged_stacks", 0)),
				],
			]
		)
	var battle_attack = int(commander_payload.get("attack", int(command.get("attack", 0))))
	var battle_defense = int(commander_payload.get("defense", int(command.get("defense", 0))))
	var battle_initiative = int(commander_payload.get("initiative", 0))
	var initiative_label = "%d" % battle_initiative
	if battle_initiative > 0:
		initiative_label = "+%d" % battle_initiative
	var lines := [
		"%s | %s" % [
			HeroCommandRulesScript.hero_identity_context_line(
				commander_state,
				String(ContentService.get_scenario_readonly(session.scenario_id).get("player_faction_id", "")) if side == "player" else _battle_enemy_faction_id(session)
			),
			_commander_role_label(battle, side),
		],
		HeroCommandRulesScript.hero_progress_context_line(commander_state),
		"Readiness: %s" % HeroCommandRulesScript.hero_readiness_context_line(commander_state, false),
		"Battle aura: Atk %d | Def %d | Init %s" % [
			battle_attack,
			battle_defense,
			initiative_label,
		],
		"Gear impact: %s" % ArtifactRulesScript.describe_battle_impact_summary(commander_state),
		"Mana %d/%d | Army %d stacks | %d units | %d HP" % [
			int(commander_payload.get("mana_current", 0)),
			int(commander_payload.get("mana_max", 0)),
			int(army_totals.get("stacks", 0)),
			int(army_totals.get("units", 0)),
			int(army_totals.get("health", 0)),
		],
		"Doctrine: %s" % _side_doctrine_summary(battle, side),
	]
	var continuity_summary := EnemyAdventureRulesScript.commander_record_summary(commander_state) if side == "enemy" else ""
	var army_summary := EnemyAdventureRulesScript.commander_army_summary(commander_state) if side == "enemy" else ""
	var memory_summary := EnemyAdventureRulesScript.commander_memory_summary(commander_state) if side == "enemy" else ""
	if continuity_summary != "":
		lines.insert(1, "Record: %s" % continuity_summary)
	if army_summary != "":
		lines.insert(2 if continuity_summary != "" else 1, "Army: %s" % army_summary)
	if memory_summary != "":
		var memory_index := 1
		if continuity_summary != "":
			memory_index += 1
		if army_summary != "":
			memory_index += 1
		lines.insert(memory_index, "Memory: %s" % memory_summary)
	return "\n".join(lines)

## Enumerate the authored primary damage rolls on isolated battle copies.
## Retaliation is evaluated AFTER abilities, morale and surviving headcounts,
## using the same modifier as resolution, without creating/advancing an RNG.
## approach names the hex a strike is made from (one of melee_approach_cells);
## without it the stack strikes from where it stands, or walks to the nearest
## hex it can strike from (melee_approach_destination). The forecast says the
## kills and damage, the strike-back or why there is none, the walk (steps and
## path) and the shots, as forecast_lines for the battle screen's badge.
static func attack_consequence_preview(battle: Dictionary, action: String, target_id: String, approach: Dictionary = {}) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.attack_consequence_preview", [battle, action, target_id, approach])

## A forecast's lines as one sentence each, for the log, tooltips and F1.
static func forecast_text(lines: Array) -> String:
	return BattleEngine.native(&"BattleRules.forecast_text", [lines])

static func spell_consequence_preview(session: SessionStateStoreScript.SessionData, spell_id: String, target_id: String = "") -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.spell_consequence_preview", [session, spell_id, target_id])

static func describe_initiative_track(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Initiative track unavailable."
	var battle = session.battle
	var turn_order = battle.get("turn_order", [])
	if not (turn_order is Array) or turn_order.is_empty():
		return "Initiative is still being established."
	var lines = []
	for index in range(turn_order.size()):
		var battle_id = String(turn_order[index])
		var stack = _get_stack_by_id(battle, battle_id)
		if stack.is_empty() or _alive_count(stack) <= 0:
			continue
		var marker = "UP"
		if battle_id == String(battle.get("active_stack_id", "")):
			marker = "NOW"
		elif index < int(battle.get("turn_index", 0)):
			marker = "DONE"
		lines.append("%s %s [%s] | Init %d | x%d | HP %d" % [
			marker,
			_stack_label(stack),
			_side_label(String(stack.get("side", ""))),
			_stack_initiative_total(stack, battle),
			_alive_count(stack),
			int(stack.get("total_health", 0)),
		])
	return "\n".join(lines) if not lines.is_empty() else "No active stacks remain."

static func describe_active_context(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No active stack."
	return _stack_focus_summary(get_active_stack(session.battle), session.battle, true)

static func active_consequence_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.active_consequence_payload", [session])

static func post_action_recap_context(session: SessionStateStoreScript.SessionData, action_id: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.post_action_recap_context", [session, action_id])

static func post_action_recap_payload(session: SessionStateStoreScript.SessionData, result: Dictionary, action_id: String = "", context: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.post_action_recap_payload", [session, result, action_id, context])

static func describe_target_context(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"BattleRules.describe_target_context", [session])

static func describe_effect_board(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No active effects."
	var lines = []
	for stack in session.battle.get("stacks", []):
		if not (stack is Dictionary) or _alive_count(stack) <= 0:
			continue
		var effect_summary = SpellRulesScript.effect_summary(stack, session.battle)
		if effect_summary != "":
			lines.append("%s [%s]: %s" % [
				_stack_label(stack),
				_side_label(String(stack.get("side", ""))),
				effect_summary,
			])
	return "\n".join(lines) if not lines.is_empty() else "No active spell or status effects are shaping this round."

static func describe_dispatch(session: SessionStateStoreScript.SessionData, last_message: String = "") -> String:
	if session == null or session.battle.is_empty():
		return last_message if last_message != "" else "Battle dispatch unavailable."
	var lines = []
	var latest = last_message.strip_edges()
	if latest != "":
		lines.append("Latest: %s" % latest)
	var appended = 0
	for event_text in session.battle.get("recent_events", []):
		var event_line = String(event_text).strip_edges()
		if event_line == "" or event_line == latest:
			continue
		lines.append("Feed: %s" % event_line)
		appended += 1
		if appended >= 4:
			break
	lines.append("Pressure: %s" % _pressure_brief(session))
	return "\n".join(lines)

static func describe_action_surface(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"BattleRules.describe_action_surface", [session])

static func target_handoff_cue_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {
			"visible_text": "Target handoff: no battle is loaded.",
			"tooltip_text": "Target Handoff\n- No battle is loaded.",
			"focus": "",
			"board_click": "",
			"cycle": "",
			"move": "",
		}
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var target = get_selected_target(battle)
	var target_label := _stack_label(target) if not target.is_empty() else "no target"
	var legal_target_ids := _legal_attack_target_ids_for_active_stack(battle)
	var enemy_count := _alive_stacks_for_side(battle, "enemy").size()
	var cycle_line := ""
	if legal_target_ids.size() > 1:
		cycle_line = "Prev/Next cycles %d legal targets." % legal_target_ids.size()
	elif legal_target_ids.size() == 1:
		cycle_line = "Only one legal target is ready."
	elif enemy_count > 1:
		cycle_line = "Prev/Next checks %d enemy stacks." % enemy_count
	elif enemy_count == 1:
		cycle_line = "Only one enemy stack remains."
	else:
		cycle_line = "No living enemy target remains."

	var visible := ""
	var board_line := ""
	var move_line := ""
	if active_stack.is_empty():
		visible = "Target handoff: wait for the next stack."
		board_line = "No stack is ready to act."
	elif String(active_stack.get("side", "")) != "player":
		visible = "Target handoff: enemy initiative; command returns after this action."
		board_line = _player_input_locked_summary()
	else:
		var click_intent := selected_target_board_click_intent(battle)
		var movement_intent := active_movement_board_click_intent(battle)
		var continuity_context := selected_target_continuity_context(battle)
		var closing_context := selected_target_closing_context(battle)
		board_line = String(click_intent.get("message", ""))
		if not continuity_context.is_empty():
			board_line = String(continuity_context.get("message", board_line))
		elif not closing_context.is_empty():
			board_line = String(closing_context.get("message", board_line))
		if board_line == "":
			board_line = "Board: select an enemy or move hex to preview; confirm to commit."
		move_line = String(movement_intent.get("message", ""))
		var click_action := String(click_intent.get("action", ""))
		var click_label := String(click_intent.get("label", "")).strip_edges()
		if click_action != "" and click_label != "" and not target.is_empty():
			visible = "Target handoff: %s | Try: click target to %s." % [
				target_label,
				click_label.to_lower(),
			]
		elif String(movement_intent.get("action", "")) == "move":
			visible = "Target handoff: %s | Try: click move hex to move." % target_label
		else:
			visible = "Target handoff: %s | Try: cycle or use a ready order." % target_label

	var tooltip := "Target Handoff\n- Focus: %s\n- Board click: %s\n- Cycle: %s" % [
		target_label,
		board_line,
		cycle_line,
	]
	if move_line != "":
		tooltip += "\n- Move: %s" % move_line
	tooltip += "\n- Ready check: %s" % describe_action_readiness_confirmation(session)
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"focus": target_label,
		"board_click": board_line,
		"cycle": cycle_line,
		"move": move_line,
	}

static func objective_check_cue_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {
			"visible_text": "Objective check: no battle is loaded.",
			"tooltip_text": "Objective Check\n- No battle is loaded.",
			"field": "",
			"pressure": "",
			"next_step": "",
			"readiness": "unavailable",
		}
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var target = get_selected_target(battle)
	var surface := get_action_surface(session)
	var field_line := _field_objective_status_brief(battle)
	var pressure_line := _field_objective_pressure_summary(battle)
	var next_step := _objective_pull_line(session, battle, surface, active_stack, target)
	var readiness := "Ready"
	var order_line := ""
	if active_stack.is_empty():
		readiness = "Waiting"
		next_step = "Wait for the next stack or battle resolution."
	elif String(active_stack.get("side", "")) != "player":
		readiness = "Locked"
		next_step = "Enemy initiative is active; wait for command to return."
	else:
		var action_id := _preferred_player_action_id(surface, active_stack)
		if action_id != "":
			var action: Dictionary = surface.get(action_id, {}) if surface.get(action_id, {}) is Dictionary else {}
			var action_label := String(action.get("label", action_id.capitalize())).strip_edges()
			var action_readiness := String(action.get("readiness", "")).strip_edges()
			order_line = "%s%s" % [
				action_label,
				" (%s)" % action_readiness if action_readiness != "" else "",
			]
		else:
			readiness = "Check"
	if field_line == "":
		field_line = "no active field objective"
	if pressure_line == "":
		pressure_line = "line break is the main battle pressure"
	if next_step.strip_edges() == "":
		next_step = "Choose the next legal order."
	var visible := "Objective check: %s; %s." % [field_line, next_step]
	var tooltip_lines := [
		"Objective Check",
		"- Field: %s" % field_line,
		"- Pressure: %s" % pressure_line,
		"- Readiness: %s" % readiness,
		"- Next practical action: %s" % next_step,
		"- Inspection: checking this cue does not spend an action or advance initiative.",
	]
	if order_line != "":
		tooltip_lines.insert(4, "- Current order lever: %s" % order_line)
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"field": field_line,
		"pressure": pressure_line,
		"next_step": next_step,
		"readiness": readiness,
		"order": order_line,
	}

static func describe_action_readiness_confirmation(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"BattleRules.describe_action_readiness_confirmation", [session])

static func intent_forecast_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.intent_forecast_payload", [session])

static func _preferred_spell_timing_action(session: SessionStateStoreScript.SessionData, battle: Dictionary, active_stack: Dictionary, target: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules._preferred_spell_timing_action", [session, battle, active_stack, target])

static func _preferred_player_action_id(surface: Dictionary, active_stack: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._preferred_player_action_id", [surface, active_stack])

static func _objective_pull_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	surface: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	if not active_stack.is_empty() and String(active_stack.get("side", "")) == "player":
		var action_id = _preferred_player_action_id(surface, active_stack)
		if action_id != "":
			var preview = _field_objective_action_preview(
				battle,
				{
					"action": action_id,
					"side": "player",
					"battle_id": String(active_stack.get("battle_id", "")),
					"target_battle_id": String(target.get("battle_id", "")),
				}
			)
			if preview != "":
				return preview
	var urgency = _field_objective_urgency_summary(session, battle)
	if urgency != "":
		return urgency
	var scenario = ContentService.get_scenario_readonly(session.scenario_id)
	var encounter_objective = _encounter_objective_for_battle(session, battle, scenario)
	if not encounter_objective.is_empty():
		return "Clearing this host advances %s." % ScenarioRulesScript._objective_label(session, encounter_objective)
	var objective_brief = _field_objective_pressure_brief(battle)
	if objective_brief != "":
		return objective_brief
	return "No battlefield objective is pulling harder than the line break."

static func _next_enemy_reply_stack(battle: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules._next_enemy_reply_stack", [battle])

static func _enemy_action_preview_summary(battle: Dictionary, enemy_stack: Dictionary, action: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._enemy_action_preview_summary", [battle, enemy_stack, action])

static func _retreat_action_summary(session: SessionStateStoreScript.SessionData) -> String:
	return BattleEngine.native_writing(&"BattleRules._retreat_action_summary", [session])

static func _surrender_action_summary(session: SessionStateStoreScript.SessionData) -> String:
	return BattleEngine.native_writing(&"BattleRules._surrender_action_summary", [session])

static func _battle_enemy_faction_id(session: SessionStateStoreScript.SessionData) -> String:
	return BattleEngine.native_writing(&"BattleRules._battle_enemy_faction_id", [session])

static func _enemy_state_exists(session: SessionStateStoreScript.SessionData, faction_id: String) -> bool:
	return BattleEngine.native_writing(&"BattleRules._enemy_state_exists", [session, faction_id])

static func _active_ability_window_summary(stack: Dictionary, battle: Dictionary, target: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._active_ability_window_summary", [stack, battle, target])

static func _field_objective_action_preview(battle: Dictionary, action_context: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._field_objective_action_preview", [battle, action_context])

static func _weakest_stack_by_cohesion(battle: Dictionary, side: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._weakest_stack_by_cohesion", [battle, side])

static func _encounter_objective_for_battle(session: SessionStateStoreScript.SessionData, battle: Dictionary, scenario: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules._encounter_objective_for_battle", [session, battle, scenario])

static func _current_battle_encounter_placement(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._current_battle_encounter_placement", [session])

static func _priority_enemy_stack_for_briefing(battle: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules._priority_enemy_stack_for_briefing", [battle])

static func get_action_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.get_action_surface", [session])

static func animation_state_for_stack(battle: Dictionary, stack: Dictionary) -> String:
	var battle_id := String(stack.get("battle_id", ""))
	var event_states: Dictionary = battle.get(STACK_ANIMATION_STATES_KEY, {}) if battle.get(STACK_ANIMATION_STATES_KEY, {}) is Dictionary else {}
	var record: Dictionary = event_states.get(battle_id, {}) if event_states.get(battle_id, {}) is Dictionary else {}
	var event_state := String(record.get("state", "")).strip_edges()
	if event_state != "":
		return event_state
	if battle_id != "" and battle_id == String(battle.get("active_stack_id", "")):
		return "ready_active"
	if bool(stack.get("defending", false)):
		return "defend_brace"
	return "idle_hold"

static func animation_event_states(battle: Dictionary) -> Dictionary:
	var normalized := {}
	var event_states: Dictionary = battle.get(STACK_ANIMATION_STATES_KEY, {}) if battle.get(STACK_ANIMATION_STATES_KEY, {}) is Dictionary else {}
	for battle_id in event_states.keys():
		var record: Dictionary = event_states.get(battle_id, {}) if event_states.get(battle_id, {}) is Dictionary else {}
		if String(record.get("state", "")).strip_edges() == "":
			continue
		normalized[String(battle_id)] = record.duplicate(true)
	return normalized

static func animation_event_queue(battle: Dictionary) -> Array:
	return HumanEngine.native_writing(&"BattleRules.animation_event_queue", [battle])

static func battle_presentation_event_stream(battle: Dictionary) -> Array:
	return HumanEngine.native_writing(&"BattleRules.battle_presentation_event_stream", [battle])

static func battle_presentation_speed(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"BattleRules.battle_presentation_speed", [session])

static func set_battle_presentation_speed(session: SessionStateStoreScript.SessionData, speed: String) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.set_battle_presentation_speed", [session, speed])

static func battle_presentation_playback_msec(battle: Dictionary) -> int:
	return HumanEngine.native_writing(&"BattleRules.battle_presentation_playback_msec", [battle])

static func describe_battle_presentation_stream(session: SessionStateStoreScript.SessionData, max_events: int = 5) -> String:
	if session == null or session.battle.is_empty():
		return ""
	var events := battle_presentation_event_stream(session.battle)
	var lines := []
	for index in range(events.size() - 1, -1, -1):
		if lines.size() >= max(1, max_events):
			break
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		var text := String(event.get("visible_text", event.get("text", ""))).strip_edges()
		if text == "":
			continue
		lines.append(text)
	return "\n".join(lines)

static func latest_battle_presentation_event_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {}
	var events := battle_presentation_event_stream(session.battle)
	if events.is_empty():
		return {}
	return events[events.size() - 1].duplicate(true)

static func latest_animation_event_presentation_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.latest_animation_event_presentation_payload", [session])

static func cast_player_spell(session: SessionStateStoreScript.SessionData, spell_id: String, target_id: String = "") -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.cast_player_spell", [session, spell_id, target_id])

static func move_active_stack_to_hex(session: SessionStateStoreScript.SessionData, q: int, r: int) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.move_active_stack_to_hex", [session, q, r])

static func perform_presented_action(session: SessionStateStoreScript.SessionData, action: String, destination: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.perform_presented_action", [session, action, destination])

## Counts an order the player gave (a move, attack, defence, wait or the
## hero's cast) once it was carried out. Quick Resolve is offered only before
## the first one (player_has_given_orders).
static func record_player_order(battle: Dictionary, result: Dictionary) -> void:
	HumanEngine.native_writing(&"BattleRules.record_player_order", [battle, result])

static func player_has_given_orders(battle: Dictionary) -> bool:
	return HumanEngine.native_writing(&"BattleRules.player_has_given_orders", [battle])

## What the battle screen shows for a side's hero, or {} when no commander
## leads that side. A hero from the content roster stands beside its army
## (has_figure); a town captain or a guard's commander has no figure. mana is
## the commander's spellbook mana, which its casts spend.
static func hero_presentation(battle: Dictionary, side: String) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.hero_presentation", [battle, side])

## What a stack's details card shows, from the numbers the battle itself
## uses: attack and defense with the commanding hero's bonus (and the Defend
## stance), speed as the hexes the stack may walk this turn, initiative as
## it orders turns. Each stat carries the unit's own value as "base", so the
## card can show what changed it. {} for a stack that is not in the battle.
static func stack_details(battle: Dictionary, battle_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.stack_details", [battle, battle_id])

## The strike-backs a stack has this round: "max" a round, "left" of them
## still to make (none while Staggered, which "blocked" names).
static func stack_strike_backs(battle: Dictionary, stack: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules.stack_strike_backs", [battle, stack])

## The stack waited this round and has yet to act: it is in the waiting part
## of the turn order, after the stacks still to act at their own speed.
static func stack_is_waiting(battle: Dictionary, battle_id: String) -> bool:
	return HumanEngine.native_writing(&"BattleRules.stack_is_waiting", [battle, battle_id])

static func effect_polarity(effect: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules.effect_polarity", [effect])

## What a hero's details card shows: hero_presentation, its attack and
## defense as its stacks fight with them, spell power and knowledge, its
## faction and class, its specialties with their ranks, and its battle
## spells at what they cost it. {} for a side without a commander.
static func hero_details(battle: Dictionary, side: String) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.hero_details", [battle, side])

## approach names the hex a strike is made from (q, r): one of
## melee_approach_cells. Without it the stack strikes from where it stands, or
## walks to the nearest hex it can strike from (melee_approach_destination).
static func perform_player_action(session: SessionStateStoreScript.SessionData, action: String, approach: Dictionary = {}) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.perform_player_action", [session, action, approach])

static func roster_lines(battle: Dictionary, side: String) -> Array:
	return HumanEngine.native_writing(&"BattleRules.roster_lines", [battle, side])

static func action_availability(battle: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.action_availability", [battle])

static func _resolve_attack_action(session: SessionStateStoreScript.SessionData, attacker: Dictionary, target: Dictionary, is_ranged: bool) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._resolve_attack_action", [session, attacker, target, is_ranged])

static func advance_turn(battle: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleRules.advance_turn", [battle])

static func _run_enemy_turn(session: SessionStateStoreScript.SessionData, active_stack: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._run_enemy_turn", [session, active_stack])

## The active enemy stack's own order (never a cast: the hero casts first).
static func _run_enemy_stack_order(session: SessionStateStoreScript.SessionData, active_stack: Dictionary, action: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._run_enemy_stack_order", [session, active_stack, action])

static func _resolve_ai_attack(session: SessionStateStoreScript.SessionData, attacker: Dictionary, target: Dictionary, is_ranged: bool) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._resolve_ai_attack", [session, attacker, target, is_ranged])

## A battle pays by the strength of the army beaten (the AI's army rating,
## AiHeroRules.army_power), mostly in experience: half a point of experience
## per point of strength, so a typical guard (about 300) pays about what the
## encounter tables paid before. Gold and resources are half of the
## encounter's own, scaled the same way against that typical guard, between a
## quarter and four times.
const REWARD_REFERENCE_STRENGTH := 300.0
const REWARD_EXPERIENCE_PER_STRENGTH := 0.5
const REWARD_RESOURCE_SHARE := 0.5
const REWARD_RESOURCE_SCALE_MIN := 0.25
const REWARD_RESOURCE_SCALE_MAX := 4.0

static func _adjust_enemy_pressure(session: SessionStateStoreScript.SessionData, faction_id: String, delta: int) -> int:
	return BattleEngine.native_writing(&"BattleRules._adjust_enemy_pressure", [session, faction_id, delta])

static func _add_enemy_treasury_resources(session: SessionStateStoreScript.SessionData, faction_id: String, delta: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleRules._add_enemy_treasury_resources", [session, faction_id, delta])

static func pending_battle_report(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.pending_battle_report", [session])

static func acknowledge_pending_battle_report(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var report := pending_battle_report(session)
	if report.is_empty():
		return {"ok": false, "reason": "missing_pending_report", "report_id": ""}
	report["pending"] = false
	report["acknowledged"] = true
	session.flags["last_battle_aftermath"] = report
	session.flags["last_battle_report_acknowledged_id"] = String(report.get("report_id", ""))
	return {
		"ok": true,
		"reason": "acknowledged",
		"report_id": String(report.get("report_id", "")),
		"report": report.duplicate(true),
	}

static func _battle_report_casualty_ledger(battle: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._battle_report_casualty_ledger", [battle])

static func battle_report_casualty_ledger_bridge(battle: Dictionary) -> Dictionary:
	return _battle_report_casualty_ledger(battle).duplicate(true)

static func _build_battle_stack(unit_id: String, count: int, side: String, index: int, source: Dictionary = {}, army_slot_index: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules._build_battle_stack", [unit_id, count, side, index, source, army_slot_index])

static func _commander_spell_cast_this_round(battle: Dictionary, side: String) -> bool:
	return BattleEngine.native(&"BattleRules._commander_spell_cast_this_round", [battle, side])

static func hero_actor_id(side: String) -> String:
	return BattleEngine.native(&"BattleRules.hero_actor_id", [side])

static func is_hero_actor_id(actor_id: String) -> bool:
	return HumanEngine.native(&"BattleRules.is_hero_actor_id", [actor_id])

static func commander_name(battle: Dictionary, side: String) -> String:
	return BattleEngine.native(&"BattleRules.commander_name", [battle, side])

## The casting hero in the shape events and labels read from a stack.
static func _hero_caster(battle: Dictionary, side: String) -> Dictionary:
	return BattleEngine.native(&"BattleRules._hero_caster", [battle, side])

## The label of an event's actor: a stack's name or the casting hero's.
static func battle_actor_label(battle: Dictionary, actor_id: String) -> String:
	return HumanEngine.native_writing(&"BattleRules.battle_actor_label", [battle, actor_id])

## The side of an event's actor, stack or hero.
static func battle_actor_side(battle: Dictionary, actor_id: String) -> String:
	return HumanEngine.native_writing(&"BattleRules.battle_actor_side", [battle, actor_id])

static func _ensure_battle_hex_state(battle: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleRules._ensure_battle_hex_state", [battle])

## The cell a stack deploys on; the board draws a stack without a saved hex there.
static func default_deployment_hex(side: String, index: int, stack_count: int, stack: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.default_deployment_hex", [side, index, stack_count, stack])

static func _default_stack_hex(side: String, index: int, stack_count: int, stack: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._default_stack_hex", [side, index, stack_count, stack])

static func battle_obstacles(battle: Dictionary) -> Array:
	return HumanEngine.native_writing(&"BattleRules.battle_obstacles", [battle])

## "q,r" -> "obstacle:<id>" for every obstacle cell.
static func battle_obstacle_cells(battle: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules.battle_obstacle_cells", [battle])

static func _obstacle_cell_map(battle: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._obstacle_cell_map", [battle])

static func _hex_key(cell: Dictionary) -> String:
	return BattleEngine.native(&"BattleRules._hex_key", [cell])

static func _stack_hex(stack: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._stack_hex", [stack])

static func _stack_movement_points(stack: Dictionary, battle: Dictionary = {}) -> int:
	return BattleEngine.native(&"BattleRules._stack_movement_points", [stack, battle])

static func _stack_is_rooted(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._stack_is_rooted", [stack, battle])

static func _build_occupancy_map(battle: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._build_occupancy_map", [battle])

static func _sync_occupied_hexes(battle: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleRules._sync_occupied_hexes", [battle])

static func _presentation_walk_path(battle: Dictionary, start: Dictionary, destination: Dictionary) -> Array:
	return BattleEngine.native(&"BattleRules._presentation_walk_path", [battle, start, destination])

static func _hex_neighbors(cell: Dictionary) -> Array:
	return BattleEngine.native(&"BattleRules._hex_neighbors", [cell])

static func _stack_hex_distance(lhs: Dictionary, rhs: Dictionary) -> int:
	return BattleEngine.native(&"BattleRules._stack_hex_distance", [lhs, rhs])

static func _sync_distance_from_hexes(battle: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleRules._sync_distance_from_hexes", [battle])

static func _set_selected_target(battle: Dictionary, target_id: String, explicit_retarget: bool = false) -> void:
	BattleEngine.native_writing(&"BattleRules._set_selected_target", [battle, target_id, explicit_retarget])

static func _advance_desired_gap(stack: Dictionary, battle: Dictionary) -> int:
	return BattleEngine.native(&"BattleRules._advance_desired_gap", [stack, battle])

## The enemy's obstruction line holds a stack that cannot breach it in place
## until the lines meet somewhere on the board.
static func _advance_stalled_by_obstruction(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native_writing(&"BattleRules._advance_stalled_by_obstruction", [stack, battle])

static func _hex_label(cell: Dictionary) -> String:
	return BattleEngine.native(&"BattleRules._hex_label", [cell])

static func _projected_min_opposing_hex_distance(battle: Dictionary, stack: Dictionary, destination: Dictionary) -> int:
	return BattleEngine.native(&"BattleRules._projected_min_opposing_hex_distance", [battle, stack, destination])

static func _attack_distance_for_action(attacker: Dictionary, target: Dictionary, battle: Dictionary, is_ranged: bool) -> int:
	return BattleEngine.native(&"BattleRules._attack_distance_for_action", [attacker, target, battle, is_ranged])

static func _legal_attack_target_ids_for_active_stack(battle: Dictionary) -> Array:
	return BattleEngine.native_writing(&"BattleRules._legal_attack_target_ids_for_active_stack", [battle])

static func _calculate_damage(attacker: Dictionary, defender: Dictionary, battle: Dictionary, rng: RandomNumberGenerator, is_ranged: bool, is_retaliation: bool = false, attack_distance: int = -1) -> int:
	return BattleEngine.native_writing(&"BattleRules._calculate_damage", [attacker, defender, battle, rng, is_ranged, is_retaliation, attack_distance])

static func _damage_range_preview(attacker: Dictionary, defender: Dictionary, battle: Dictionary, is_ranged: bool, is_retaliation: bool = false, attack_distance: int = -1) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._damage_range_preview", [attacker, defender, battle, is_ranged, is_retaliation, attack_distance])

static func _unit_loss_range(defender: Dictionary, min_damage: int, max_damage: int) -> Dictionary:
	return BattleEngine.native(&"BattleRules._unit_loss_range", [defender, min_damage, max_damage])

static func _ranged_damage_return_ratio(stack: Dictionary) -> float:
	return BattleEngine.native(&"BattleRules._ranged_damage_return_ratio", [stack])

static func _readiness_writ_ability(stack: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._readiness_writ_ability", [stack])

static func _readiness_writ_target(battle: Dictionary, source: Dictionary, ability: Dictionary = {}) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._readiness_writ_target", [battle, source, ability])

## Wait: once per round a stack steps out of the order and acts after every
## stack that has not waited, slowest first (HoMM3). Its turn is not spent,
## so its effects do not count down.
static func waited_stack_ids(battle: Dictionary) -> Array:
	return BattleEngine.native(&"BattleRules.waited_stack_ids", [battle])

static func stack_has_waited(battle: Dictionary, battle_id: String) -> bool:
	return BattleEngine.native(&"BattleRules.stack_has_waited", [battle, battle_id])

## How many living stacks would act before this one if it waited now.
static func _stacks_ahead_after_wait(battle: Dictionary, battle_id: String) -> int:
	return BattleEngine.native_writing(&"BattleRules._stacks_ahead_after_wait", [battle, battle_id])

static func turn_order_forecast(battle: Dictionary) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.turn_order_forecast", [battle])

static func _reach_available(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._reach_available", [stack, battle])

static func _hookline_available(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._hookline_available", [stack, battle])

static func _pressure_artillery_secondary_target(battle: Dictionary, attacker: Dictionary, primary_target: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._pressure_artillery_secondary_target", [battle, attacker, primary_target])

static func _can_make_retaliation(stack: Dictionary, attack_distance: int, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._can_make_retaliation", [stack, attack_distance, battle])

static func _side_has_linked_unit(battle: Dictionary, side: String, unit_ids: Variant) -> bool:
	return BattleEngine.native(&"BattleRules._side_has_linked_unit", [battle, side, unit_ids])

static func _ability_by_id(stack: Dictionary, ability_id: String) -> Dictionary:
	return BattleEngine.native(&"BattleRules._ability_by_id", [stack, ability_id])

static func _authored_ability_by_id(stack: Dictionary, ability_id: String) -> Dictionary:
	return BattleEngine.native(&"BattleRules._authored_ability_by_id", [stack, ability_id])

static func _has_ability(stack: Dictionary, ability_id: String) -> bool:
	return BattleEngine.native(&"BattleRules._has_ability", [stack, ability_id])

static func _side_has_ability(battle: Dictionary, side: String, ability_id: String) -> bool:
	return BattleEngine.native(&"BattleRules._side_has_ability", [battle, side, ability_id])

static func _charter_retaliation_aura_context(stack: Dictionary, battle: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._charter_retaliation_aura_context", [stack, battle])

static func _counter_ambush_flare_context(battle: Dictionary, protected_stack: Dictionary, ambush_ability_id: String) -> Dictionary:
	return BattleEngine.native(&"BattleRules._counter_ambush_flare_context", [battle, protected_stack, ambush_ability_id])

static func _side_resonance_relay(battle: Dictionary, side: String) -> Dictionary:
	return BattleEngine.native(&"BattleRules._side_resonance_relay", [battle, side])

static func _battle_has_tag(battle: Dictionary, tag: String) -> bool:
	return BattleEngine.native(&"BattleRules._battle_has_tag", [battle, tag])

static func _battle_has_any_tags(battle: Dictionary, tags: Array) -> bool:
	return BattleEngine.native(&"BattleRules._battle_has_any_tags", [battle, tags])

static func _capital_front_anchor_side(battle: Dictionary) -> String:
	return BattleEngine.native(&"BattleRules._capital_front_anchor_side", [battle])

static func _stack_is_anchor_side(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._stack_is_anchor_side", [stack, battle])

static func _stack_is_assault_side(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._stack_is_assault_side", [stack, battle])

static func _hero_has_trait(battle: Dictionary, side: String, trait_id: String) -> bool:
	return BattleEngine.native_writing(&"BattleRules._hero_has_trait", [battle, side, trait_id])

static func _normalize_ability_modifiers(value: Variant) -> Dictionary:
	return BattleEngine.native(&"BattleRules._normalize_ability_modifiers", [value])

static func _set_enemy_siege_progress(session: SessionStateStoreScript.SessionData, faction_id: String, progress: int) -> void:
	BattleEngine.native_writing(&"BattleRules._set_enemy_siege_progress", [session, faction_id, progress])

static func _alive_count(stack: Dictionary) -> int:
	return BattleEngine.native(&"BattleRules._alive_count", [stack])

static func _health_ratio(stack: Dictionary) -> float:
	return BattleEngine.native(&"BattleRules._health_ratio", [stack])

static func _alive_stacks_for_side(battle: Dictionary, side: String) -> Array:
	return BattleEngine.native(&"BattleRules._alive_stacks_for_side", [battle, side])

static func _stack_has_positive_effect(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._stack_has_positive_effect", [stack, battle])

static func _side_positive_effect_count(battle: Dictionary, side: String) -> int:
	return BattleEngine.native(&"BattleRules._side_positive_effect_count", [battle, side])

static func _army_totals(battle: Dictionary, side: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._army_totals", [battle, side])

static func _battle_context_label(session: SessionStateStoreScript.SessionData, context: Variant) -> String:
	return HumanEngine.native_writing(&"BattleRules._battle_context_label", [session, context])

static func _battlefield_identity_summary(battle: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._battlefield_identity_summary", [battle])

static func _distance_label(distance: int) -> String:
	return HumanEngine.native(&"BattleRules._distance_label", [distance])

static func _side_label(side: String) -> String:
	return BattleEngine.native(&"BattleRules._side_label", [side])

static func _commander_state_for_side(battle: Dictionary, side: String) -> Dictionary:
	return HumanEngine.native_writing(&"BattleRules._commander_state_for_side", [battle, side])

static func _commander_role_label(battle: Dictionary, side: String) -> String:
	return HumanEngine.native_writing(&"BattleRules._commander_role_label", [battle, side])

static func _pressure_brief(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"BattleRules._pressure_brief", [session])

static func _stack_focus_summary(stack: Dictionary, battle: Dictionary, is_active: bool) -> String:
	return HumanEngine.native_writing(&"BattleRules._stack_focus_summary", [stack, battle, is_active])

static func _stack_attack_total(stack: Dictionary, battle: Dictionary) -> int:
	return BattleEngine.native_writing(&"BattleRules._stack_attack_total", [stack, battle])

static func _stack_defense_total(stack: Dictionary, battle: Dictionary) -> int:
	return BattleEngine.native_writing(&"BattleRules._stack_defense_total", [stack, battle])

static func _stack_initiative_total(stack: Dictionary, battle: Dictionary) -> int:
	return BattleEngine.native_writing(&"BattleRules._stack_initiative_total", [stack, battle])

static func _stack_cohesion_total(stack: Dictionary, battle: Dictionary) -> int:
	return BattleEngine.native_writing(&"BattleRules._stack_cohesion_total", [stack, battle])

static func _stack_momentum_total(stack: Dictionary, battle: Dictionary) -> int:
	return BattleEngine.native_writing(&"BattleRules._stack_momentum_total", [stack, battle])

static func _stack_is_isolated(battle: Dictionary, stack: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._stack_is_isolated", [battle, stack])

static func _stack_is_hex_isolated(battle: Dictionary, stack: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._stack_is_hex_isolated", [battle, stack])

static func _harry_support_ready(attacker: Dictionary, target: Dictionary, battle: Dictionary, ability: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._harry_support_ready", [attacker, target, battle, ability])

static func _side_defending_count(battle: Dictionary, side: String) -> int:
	return BattleEngine.native(&"BattleRules._side_defending_count", [battle, side])

static func _brace_available(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._brace_available", [stack, battle])

static func _bramble_ground_ability(stack: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._bramble_ground_ability", [stack])

static func _bramble_ground_available(stack: Dictionary, battle: Dictionary, ability: Dictionary = {}) -> bool:
	return BattleEngine.native(&"BattleRules._bramble_ground_available", [stack, battle, ability])

static func _fog_screen_ability(stack: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._fog_screen_ability", [stack])

static func _fog_screen_available(stack: Dictionary, battle: Dictionary, ability: Dictionary = {}) -> bool:
	return BattleEngine.native(&"BattleRules._fog_screen_available", [stack, battle, ability])

static func _volley_has_protected_lane(stack: Dictionary, battle: Dictionary, volley: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._volley_has_protected_lane", [stack, battle, volley])

static func _side_has_role_mix(battle: Dictionary, side: String) -> bool:
	return BattleEngine.native(&"BattleRules._side_has_role_mix", [battle, side])

static func _enemy_wounded_count(battle: Dictionary, side: String) -> int:
	return BattleEngine.native(&"BattleRules._enemy_wounded_count", [battle, side])

static func _side_doctrine_summary(battle: Dictionary, side: String) -> String:
	return HumanEngine.native_writing(&"BattleRules._side_doctrine_summary", [battle, side])

static func _side_faction_id(battle: Dictionary, side: String) -> String:
	return BattleEngine.native_writing(&"BattleRules._side_faction_id", [battle, side])

## Read-only: the result may be shared with later calls on an unchanged side.
static func _hero_payload_for_side(battle: Dictionary, side: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._hero_payload_for_side", [battle, side])

static func _normalized_battle_traits(value: Variant) -> Array:
	return BattleEngine.native(&"BattleRules._normalized_battle_traits", [value])

static func _opposing_side(side: String) -> String:
	return BattleEngine.native(&"BattleRules._opposing_side", [side])

static func _field_objectives(battle: Dictionary) -> Array:
	return BattleEngine.native(&"BattleRules._field_objectives", [battle])

static func _field_objective_label(objective: Dictionary) -> String:
	return BattleEngine.native(&"BattleRules._field_objective_label", [objective])

static func _field_objective_status_brief(battle: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._field_objective_status_brief", [battle])

static func _field_objective_pressure_summary(battle: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._field_objective_pressure_summary", [battle])

static func _field_objective_pressure_brief(battle: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._field_objective_pressure_brief", [battle])

static func _field_objective_urgency_summary(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._field_objective_urgency_summary", [session, battle])

static func _side_controls_field_objective_type(battle: Dictionary, side: String, objective_type: String) -> bool:
	return BattleEngine.native(&"BattleRules._side_controls_field_objective_type", [battle, side, objective_type])

static func _reserve_wave_is_active_for_side(battle: Dictionary, side: String) -> bool:
	return BattleEngine.native(&"BattleRules._reserve_wave_is_active_for_side", [battle, side])

static func _terrain_effect_brief(battle: Dictionary) -> String:
	return HumanEngine.native_writing(&"BattleRules._terrain_effect_brief", [battle])

static func _stack_is_cover_screened(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native(&"BattleRules._stack_is_cover_screened", [stack, battle])

static func _stack_can_breach_obstruction(stack: Dictionary, battle: Dictionary) -> bool:
	return BattleEngine.native_writing(&"BattleRules._stack_can_breach_obstruction", [stack, battle])

static func _field_objective_action_influence(objective: Dictionary, battle: Dictionary, acting_side: String, action_context: Dictionary, acting_stack: Dictionary, target_stack: Dictionary) -> int:
	return BattleEngine.native(&"BattleRules._field_objective_action_influence", [objective, battle, acting_side, action_context, acting_stack, target_stack])

static func _ensure_damage_rng_state(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleRules._ensure_damage_rng_state", [session, battle])

static func _damage_rng_for_battle(session: SessionStateStoreScript.SessionData) -> RandomNumberGenerator:
	return BattleEngine.native_writing(&"BattleRules._damage_rng_for_battle", [session])

static func _normalize_presentation_speed(speed: String) -> String:
	return BattleEngine.native_writing(&"BattleRules._normalize_presentation_speed", [speed])

static func _normalize_presentation_event_queue(value: Variant) -> Array:
	return BattleEngine.native(&"BattleRules._normalize_presentation_event_queue", [value])

static func _normalize_animation_event_queue(value: Variant) -> Array:
	return BattleEngine.native(&"BattleRules._normalize_animation_event_queue", [value])

static func _titleize_token(value: String) -> String:
	return BattleEngine.native_writing(&"BattleRules._titleize_token", [value])

static func _get_stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	return BattleEngine.native(&"BattleRules._get_stack_by_id", [battle, battle_id])

static func _stack_label(stack: Dictionary) -> String:
	return BattleEngine.native(&"BattleRules._stack_label", [stack])
