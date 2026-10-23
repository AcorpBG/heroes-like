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

# One immutable battle snapshot, bounded target/action entries. Never saved;
# repeated hover and the legacy summaries share the same exact exchange.
static var _consequence_cache_battle: Dictionary = {}
static var _consequence_cache: Dictionary = {}
# Last resolved hero payload per side, reused while its source dictionaries
# compare equal. Building one deep-copies and re-normalizes the commander, and
# every trait, initiative and damage check asks for it. Never saved.
static var _hero_payload_cache: Dictionary = {}
# Board reads memoized inside a board read scope; see begin_board_read_scope().
# Never saved.
static var _board_read_scope_depth := 0
static var _board_read_scope_battle: Dictionary = {}
static var _board_read_scope_cache: Dictionary = {}
static var _validation_board_read_cache_disabled := false
static var _board_read_cache_hits := 0
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

static func _battle_context_target_hero_id(
	session: SessionStateStoreScript.SessionData,
	context: Dictionary,
	raw_context: Variant
) -> String:
	var target_hero_id := String(context.get("target_hero_id", ""))
	var source: Dictionary = raw_context if raw_context is Dictionary else {}
	if target_hero_id == "":
		var commander_source = source.get("player_commander_source", {})
		if commander_source is Dictionary:
			target_hero_id = String(commander_source.get("hero_id", ""))
	if target_hero_id == "":
		target_hero_id = String(session.overworld.get("active_hero_id", ""))
	if target_hero_id == "" and session.overworld.get("hero", {}) is Dictionary:
		target_hero_id = String(session.overworld.get("hero", {}).get("id", ""))
	if target_hero_id == "":
		return ""
	if HeroCommandRulesScript.hero_by_id(session, target_hero_id).is_empty():
		return ""
	return target_hero_id

static func _find_town_at_position(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = 0) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._find_town_at_position", [session, x, y, level])

static func _battle_context_controller_id(session: SessionStateStoreScript.SessionData, context: Dictionary, raw_context: Variant = {}) -> String:
	return BattleEngine.native_writing(&"BattleRules._battle_context_controller_id", [session, context, raw_context])

static func _normalized_battle_context_fields(session: SessionStateStoreScript.SessionData, raw_context: Variant) -> Dictionary:
	var context = {}
	if raw_context is Dictionary:
		if raw_context.has("battle_context") and raw_context.get("battle_context", {}) is Dictionary:
			context = raw_context.get("battle_context", {})
		else:
			context = raw_context
	var context_type = String(context.get("type", ""))
	if context_type == "" and raw_context is Dictionary:
		var placement = raw_context
		if String(placement.get("spawned_by_faction_id", "")) != "" and String(placement.get("target_kind", "")) == "town":
			var target_town = _find_town_by_placement(session, String(placement.get("target_placement_id", ""))).get("town", {})
			# A strategic town target is not a siege. Field contact with a
			# marching raid must use the active hero's army, not a remote town's
			# garrison. Real siege owners supply an explicit context; retain
			# legacy inference only at this town's actual position/entrance.
			var contact_town: Dictionary = _find_town_at_position(session, int(placement.get("x", -9999)), int(placement.get("y", -9999)), LevelRules.level_of(placement)).get("town", {})
			var at_target_town := not contact_town.is_empty() and String(contact_town.get("placement_id", "")) == String(target_town.get("placement_id", ""))
			var target_owner := String(target_town.get("owner", "neutral"))
			var target_reason_codes := _normalize_string_array(placement.get("target_reason_codes", []))
			var neutral_expansion := target_owner == "neutral" and (
				"town_expansion" in target_reason_codes
				or "neutral_town_claim" in target_reason_codes
				or "neutral_town_siege" in target_reason_codes
			)
			if at_target_town and (target_owner == "player" or neutral_expansion):
				context = {
					"type": "town_defense",
					"town_placement_id": String(target_town.get("placement_id", placement.get("target_placement_id", ""))),
					"defending_hero_id": "",
					"raid_encounter_key": OverworldRulesScript.encounter_key(placement),
					"trigger_faction_id": String(placement.get("spawned_by_faction_id", "")),
					"defender_owner": target_owner,
				}
				context_type = "town_defense"
		elif String(placement.get("encounter_id", "")) == "encounter_town_assault" or String(placement.get("placement_id", "")).begins_with("town_assault:"):
			var assault_town_placement_id := _battle_context_town_placement_id(session, context, placement)
			if assault_town_placement_id != "":
				var assault_town: Dictionary = _find_town_by_placement(session, assault_town_placement_id).get("town", {})
				context = {
					"type": "town_assault",
					"town_placement_id": assault_town_placement_id,
					"trigger_faction_id": _battle_context_trigger_faction_id(session, context, placement, assault_town),
				}
				context_type = "town_assault"
		elif String(placement.get("encounter_id", "")) == "encounter_resource_defense" or String(placement.get("placement_id", "")).begins_with("resource_defense:"):
			var resource_placement_id := _battle_context_resource_placement_id(context, placement)
			if resource_placement_id != "":
				var node: Dictionary = OverworldRulesScript._find_resource_node_by_placement(session, resource_placement_id).get("node", {})
				var site := ContentService.get_resource_site(String(node.get("site_id", "")))
				context = {
					"type": "resource_assault",
					"resource_placement_id": resource_placement_id,
					"resource_site_id": String(node.get("site_id", "")),
					"resource_site_name": String(site.get("name", resource_placement_id)),
					"trigger_faction_id": String(node.get("ai_defended_by_faction_id", node.get("collected_by_faction_id", ""))),
				}
				context_type = "resource_assault"
		elif String(placement.get("spawned_by_faction_id", "")) != "" and String(placement.get("target_kind", "")) == "hero":
			var intercept_target_hero_id := _battle_context_target_hero_id(session, context, placement)
			if intercept_target_hero_id != "":
				context = {
					"type": "hero_intercept",
					"target_hero_id": intercept_target_hero_id,
					"trigger_faction_id": String(placement.get("spawned_by_faction_id", "")),
				}
				context_type = "hero_intercept"
	var delivery_context: Dictionary = OverworldRulesScript.delivery_interception_context_for_encounter(
		session,
		raw_context if raw_context is Dictionary else {}
	)
	var delivery_node_placement_id: String = String(context.get("delivery_node_placement_id", delivery_context.get("node_placement_id", "")))
	var delivery_site_name: String = String(context.get("delivery_site_name", delivery_context.get("site_name", "")))
	var delivery_origin_town_id: String = String(context.get("delivery_origin_town_id", delivery_context.get("origin_town_id", "")))
	var delivery_origin_town_label: String = String(context.get("delivery_origin_town_label", delivery_context.get("origin_town_label", "")))
	var delivery_target_kind: String = String(context.get("delivery_target_kind", delivery_context.get("target_kind", "")))
	var delivery_target_id: String = String(context.get("delivery_target_id", delivery_context.get("target_id", "")))
	var delivery_target_label: String = String(context.get("delivery_target_label", delivery_context.get("target_label", "")))
	var delivery_route_label: String = String(context.get("delivery_route_label", delivery_context.get("route_label", "")))
	var delivery_pressure_label: String = String(context.get("delivery_pressure_label", delivery_context.get("pressure_label", "")))
	var delivery_recruit_summary: String = String(context.get("delivery_recruit_summary", delivery_context.get("recruit_summary", "")))
	var delivery_arrival_day: int = maxi(0, int(context.get("delivery_arrival_day", delivery_context.get("arrival_day", 0))))
	if context_type == "hero_intercept":
		var target_hero_id := _battle_context_target_hero_id(session, context, raw_context)
		return {
			"type": "hero_intercept",
			"town_placement_id": "",
			"town_role": "frontier",
			"battlefront_summary": "",
			"battlefront_tags": [],
			"target_hero_id": target_hero_id,
			"trigger_faction_id": _battle_context_trigger_faction_id(session, context, raw_context),
			"delivery_node_placement_id": delivery_node_placement_id,
			"delivery_site_name": delivery_site_name,
			"delivery_origin_town_id": delivery_origin_town_id,
			"delivery_origin_town_label": delivery_origin_town_label,
			"delivery_target_kind": delivery_target_kind,
			"delivery_target_id": delivery_target_id,
			"delivery_target_label": delivery_target_label,
			"delivery_route_label": delivery_route_label,
			"delivery_pressure_label": delivery_pressure_label,
			"delivery_recruit_summary": delivery_recruit_summary,
			"delivery_arrival_day": delivery_arrival_day,
		}
	if context_type == "resource_assault":
		var resource_placement_id := _battle_context_resource_placement_id(context, raw_context)
		var node: Dictionary = OverworldRulesScript._find_resource_node_by_placement(session, resource_placement_id).get("node", {})
		var site := ContentService.get_resource_site(String(node.get("site_id", context.get("resource_site_id", ""))))
		return {
			"type": "resource_assault",
			"town_placement_id": "",
			"town_role": "frontier",
			"battlefront_summary": "",
			"battlefront_tags": [],
			"resource_placement_id": resource_placement_id,
			"resource_site_id": String(node.get("site_id", context.get("resource_site_id", ""))),
			"resource_site_name": String(site.get("name", context.get("resource_site_name", resource_placement_id))),
			"trigger_faction_id": String(context.get("trigger_faction_id", node.get("ai_defended_by_faction_id", node.get("collected_by_faction_id", "")))),
			"delivery_node_placement_id": delivery_node_placement_id,
			"delivery_site_name": delivery_site_name,
			"delivery_origin_town_id": delivery_origin_town_id,
			"delivery_origin_town_label": delivery_origin_town_label,
			"delivery_target_kind": delivery_target_kind,
			"delivery_target_id": delivery_target_id,
			"delivery_target_label": delivery_target_label,
			"delivery_route_label": delivery_route_label,
			"delivery_pressure_label": delivery_pressure_label,
			"delivery_recruit_summary": delivery_recruit_summary,
			"delivery_arrival_day": delivery_arrival_day,
		}
	if context_type not in ["town_defense", "town_assault"]:
		return {
			"type": "encounter",
			"town_placement_id": "",
			"town_role": "frontier",
			"battlefront_summary": "",
			"battlefront_tags": [],
			"delivery_node_placement_id": delivery_node_placement_id,
			"delivery_site_name": delivery_site_name,
			"delivery_origin_town_id": delivery_origin_town_id,
			"delivery_origin_town_label": delivery_origin_town_label,
			"delivery_target_kind": delivery_target_kind,
			"delivery_target_id": delivery_target_id,
			"delivery_target_label": delivery_target_label,
			"delivery_route_label": delivery_route_label,
			"delivery_pressure_label": delivery_pressure_label,
			"delivery_recruit_summary": delivery_recruit_summary,
			"delivery_arrival_day": delivery_arrival_day,
	}
	var town_placement_id := _battle_context_town_placement_id(session, context, raw_context)
	var town = _find_town_by_placement(session, town_placement_id).get("town", {})
	var battlefront = OverworldRulesScript.town_battlefront_profile(town)
	return {
		"type": context_type,
		"town_placement_id": town_placement_id,
		"defending_hero_id": String(context.get("defending_hero_id", "")),
		"raid_encounter_key": String(context.get("raid_encounter_key", "")),
		"trigger_faction_id": _battle_context_trigger_faction_id(session, context, raw_context, town),
		"defender_owner": String(context.get("defender_owner", town.get("owner", "player" if context_type == "town_defense" else "enemy"))),
		"town_role": OverworldRulesScript.town_strategic_role(town),
		"battlefront_summary": String(battlefront.get("summary", "")),
		"battlefront_tags": battlefront.get("tags", []),
		"delivery_node_placement_id": delivery_node_placement_id,
		"delivery_site_name": delivery_site_name,
		"delivery_origin_town_id": delivery_origin_town_id,
		"delivery_origin_town_label": delivery_origin_town_label,
		"delivery_target_kind": delivery_target_kind,
		"delivery_target_id": delivery_target_id,
		"delivery_target_label": delivery_target_label,
		"delivery_route_label": delivery_route_label,
		"delivery_pressure_label": delivery_pressure_label,
		"delivery_recruit_summary": delivery_recruit_summary,
		"delivery_arrival_day": delivery_arrival_day,
	}

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
static func _enemy_withdrawal_allowed(
	session: SessionStateStoreScript.SessionData,
	battle_context: Dictionary,
	encounter_placement: Dictionary
) -> bool:
	if _is_town_defense_context(battle_context) or _is_town_assault_context(battle_context):
		return false
	if _is_resource_assault_context(battle_context):
		return _enemy_state_exists(session, _battle_context_controller_id(session, battle_context))
	return _enemy_state_exists(session, PlayerRules.raid_controller_id(encounter_placement))

static func _withdrawal_pressure_label(battle: Dictionary, allowed: bool) -> String:
	if not allowed:
		return "Locked"
	var active_stack := get_active_stack(battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return "Window closed"
	return "Open"

static func _has_delivery_context(context: Variant) -> bool:
	return context is Dictionary and String(context.get("delivery_node_placement_id", "")) != ""

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
	if battle.is_empty():
		return {}
	return _build_occupancy_map(battle)

static func legal_destinations_for_active_stack(battle: Dictionary) -> Array:
	return BattleEngine.native_writing(&"BattleRules.legal_destinations_for_active_stack", [battle])

static func legal_destinations_for_stack(battle: Dictionary, battle_id: String) -> Array:
	return BattleEngine.native_writing(&"BattleRules.legal_destinations_for_stack", [battle, battle_id])

## Opens a scope in which the caller does not move, add, remove or change any
## stack, field objective or town defense of `battle`, as while describing one
## board state. Board reads repeated inside it (reachable hexes per stack) are
## computed once. Target-selection bookkeeping may still change: those reads do
## not depend on it. Scopes nest; only the outermost battle is memoized. Every
## begin needs its end_board_read_scope().
static func begin_board_read_scope(battle: Dictionary) -> void:
	if _board_read_scope_depth == 0:
		_board_read_scope_battle = battle
		_board_read_scope_cache = {}
	_board_read_scope_depth += 1

static func end_board_read_scope() -> void:
	_board_read_scope_depth = maxi(0, _board_read_scope_depth - 1)
	if _board_read_scope_depth == 0:
		_board_read_scope_battle = {}
		_board_read_scope_cache = {}

## Reports compare board reads with and without the scope memo.
static func validation_set_board_read_cache_enabled(enabled: bool) -> void:
	_validation_board_read_cache_disabled = not enabled

static func validation_board_read_cache_hits() -> int:
	return _board_read_cache_hits

static func legal_attack_targets_for_active_stack(battle: Dictionary, ranged: bool = false) -> Array:
	return BattleEngine.native_writing(&"BattleRules.legal_attack_targets_for_active_stack", [battle, ranged])

static func legal_attack_target_ids_for_active_stack(battle: Dictionary) -> Array:
	return _legal_attack_target_ids_for_active_stack(battle)

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

static func active_movement_board_click_intent(
	battle: Dictionary,
	preloaded_legal_destinations: Variant = null
) -> Dictionary:
	var active_stack = get_active_stack(battle)
	var destinations: Array = (
		preloaded_legal_destinations
		if preloaded_legal_destinations is Array
		else legal_destinations_for_active_stack(battle)
	)
	var intent := _movement_intent_skeleton(battle, active_stack, {})
	intent["destination_count"] = destinations.size()
	if battle.is_empty():
		intent["message"] = "Move hex click: no battle is active."
		return intent
	if active_stack.is_empty():
		intent["message"] = "Move hex click: no stack is ready to move."
		return intent
	if String(active_stack.get("side", "")) != "player":
		intent["message"] = "It is not the player's turn."
		return intent
	if destinations.is_empty():
		intent["blocked"] = true
		intent["message"] = _movement_intent_message(battle, active_stack, {}, 0)
		return intent

	intent["action"] = "move"
	intent["label"] = "Move"
	intent["movable"] = true
	intent["message"] = _movement_intent_message(battle, active_stack, {}, destinations.size())
	return intent

static func movement_intent_for_destination(battle: Dictionary, q: int, r: int, preloaded_legal_destinations: Variant = null) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.movement_intent_for_destination", [battle, q, r, preloaded_legal_destinations])

static func legal_movement_intents_for_active_stack(
	battle: Dictionary,
	preloaded_legal_destinations: Variant = null
) -> Array:
	var intents := []
	# Every destination's intent re-reads the same board; read it once.
	begin_board_read_scope(battle)
	var destinations: Array = (
		preloaded_legal_destinations
		if preloaded_legal_destinations is Array
		else legal_destinations_for_active_stack(battle)
	)
	for destination in destinations:
		if not (destination is Dictionary):
			continue
		intents.append(movement_intent_for_destination(
			battle,
			int(destination.get("q", -1)),
			int(destination.get("r", -1)),
			destinations
		))
	end_board_read_scope()
	return intents

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
	var active_stack = get_active_stack(battle)
	var active_hex := _stack_hex(active_stack)
	var legal_destinations := legal_destinations_for_active_stack(battle)
	var selected_legality := selected_target_legality(battle)
	var selected_click_intent := selected_target_board_click_intent(battle)
	var selected_continuity_context := selected_target_continuity_context(battle)
	var selected_closing_context := selected_target_closing_context(battle)
	var movement_click_intent := active_movement_board_click_intent(battle, legal_destinations)
	var selected_action_label := String(selected_click_intent.get("label", ""))
	return {
		"columns": BATTLE_HEX_COLUMNS,
		"rows": BATTLE_HEX_ROWS,
		"occupied_hexes": _build_occupancy_map(battle),
		"legal_destinations": legal_destinations,
		"legal_movement_intents": legal_movement_intents_for_active_stack(battle, legal_destinations),
		"legal_melee_targets": legal_attack_targets_for_active_stack(battle, false),
		"legal_ranged_targets": legal_attack_targets_for_active_stack(battle, true),
		"active_hex": active_hex,
		"active_movement_board_click_intent": movement_click_intent,
		"selected_target_legality": selected_legality,
		"selected_target_board_click_intent": selected_click_intent,
		"selected_target_direct_actionable": (
			selected_continuity_context.is_empty()
			and selected_closing_context.is_empty()
			and bool(selected_legality.get("attackable", false))
			and selected_action_label != ""
		),
		"selected_target_continuity_context": selected_continuity_context,
		"selected_target_closing_context": selected_closing_context,
	}

static func target_cycle_ids(battle: Dictionary) -> Array:
	var enemies := _alive_stacks_for_side(battle, "enemy")
	var legal_ids := _legal_attack_target_ids_for_active_stack(battle)
	var ids := []
	for enemy in enemies:
		var id := String(enemy.get("battle_id", ""))
		if legal_ids.is_empty() or id in legal_ids: ids.append(id)
	return ids

static func cycle_target(session: SessionStateStoreScript.SessionData, direction: int) -> void:
	if session == null or session.battle.is_empty():
		return
	var active_stack = get_active_stack(session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return

	var candidates := target_cycle_ids(session.battle)
	if candidates.is_empty():
		_set_selected_target(session.battle, "", true)
		return

	var current_id = String(session.battle.get("selected_target_id", ""))
	var step := -1 if direction < 0 else 1
	var index := -1 if step > 0 else 0
	for candidate_index in range(candidates.size()):
		if String(candidates[candidate_index]) == current_id:
			index = candidate_index
			break
	index = posmod(index + step, candidates.size())
	_set_selected_target(session.battle, String(candidates[index]), true)

static func spell_target_ids(session: SessionStateStoreScript.SessionData, spell_id: String) -> Array:
	var ids := []
	if session == null or session.battle.is_empty(): return ids
	for stack in session.battle.get("stacks", []):
		var id := String(stack.get("battle_id", ""))
		if id != "" and bool(spell_consequence_preview(session, spell_id, id).get("ok", false)): ids.append(id)
	return ids

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

static func _player_spell_cast_used_summary() -> String:
	return "Commander spell already cast this round; the next spell window opens next round."

static func _player_input_locked_summary() -> String:
	return BattleEngine.native(&"BattleRules._player_input_locked_summary", [])

static func get_spell_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if session == null or session.battle.is_empty():
		return []
	var active_stack := get_active_stack(session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return []
	if _commander_spell_cast_this_round(session.battle, "player"):
		return []
	return SpellRulesScript.get_battle_actions(
		_player_commander_state(session),
		session.battle,
		active_stack,
		get_selected_target(session.battle)
	)

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
	if session == null or session.battle.is_empty():
		return "Battle context unavailable."
	var battle = session.battle
	var encounter = ContentService.get_encounter(String(battle.get("encounter_id", "")))
	var scenario = ContentService.get_scenario_readonly(session.scenario_id)
	var lines := [
		"Matchup: %s vs %s." % [
			_player_force_name_from_battle(battle),
			_enemy_force_name_from_battle(battle, session),
		],
		"Commanders: %s vs %s." % [
			HeroCommandRulesScript.hero_identity_context_line(
				_commander_state_for_side(battle, "player"),
				String(scenario.get("player_faction_id", ""))
			),
			HeroCommandRulesScript.hero_identity_context_line(
				_commander_state_for_side(battle, "enemy"),
				_battle_enemy_faction_id(session)
			),
		],
		"Forces: %s | Friendly %s | Enemy %s." % [
			_battle_entry_risk_label(session, battle),
			_compact_army_total(_army_totals(battle, "player")),
			_compact_army_total(_army_totals(battle, "enemy")),
		],
	]
	var stakes_line := _battle_entry_stakes_line(session, battle, encounter, scenario)
	if stakes_line != "":
		lines.append("Stakes: %s." % stakes_line)
	return "\n".join(lines)

static func _battle_entry_risk_label(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var parts := []
	var difficulty_label := _battle_difficulty_label(battle)
	if difficulty_label != "":
		parts.append(difficulty_label)
	var outlook := _risk_readiness_grade(session, battle).strip_edges()
	var period_index := outlook.find(".")
	if period_index >= 0:
		outlook = outlook.left(period_index)
	if outlook != "":
		parts.append("Outlook %s" % outlook)
	return " | ".join(parts) if not parts.is_empty() else "Outlook unscouted"

static func _battle_entry_stakes_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	encounter: Dictionary,
	scenario: Dictionary
) -> String:
	var parts := []
	var objective_line := _tactical_objective_line(session, battle, scenario).strip_edges()
	if objective_line.begins_with("Battle aim:"):
		objective_line = objective_line.trim_prefix("Battle aim:").strip_edges()
	if objective_line != "":
		parts.append(objective_line)
	var reward_line := _battle_entry_reward_line(session, encounter, battle)
	if reward_line != "":
		parts.append("Reward %s" % reward_line)
	var field_line := _field_objective_status_brief(battle)
	if field_line != "":
		parts.append("Field %s" % field_line)
	return " | ".join(parts)

static func _battle_entry_reward_line(session: SessionStateStoreScript.SessionData, encounter: Dictionary, battle: Dictionary = {}) -> String:
	if encounter.is_empty():
		return ""
	var rewards = DifficultyRulesScript.scale_reward_resources(session, battle_rewards_for_strength(encounter, _starting_enemy_stacks(battle), battle.get("enemy_hero", {})))
	return OverworldRulesScript._describe_resource_delta(rewards)

static func _battle_difficulty_label(battle: Dictionary) -> String:
	var difficulty := String(battle.get("encounter_difficulty", battle.get("difficulty", ""))).strip_edges()
	return "Difficulty %s" % _titleize_token(difficulty) if difficulty != "" else ""

static func _compact_army_total(totals: Dictionary) -> String:
	var ranged_count := int(totals.get("ranged_stacks", 0))
	var text := "%d stacks, %d units, %d HP" % [
		int(totals.get("stacks", 0)),
		int(totals.get("units", 0)),
		int(totals.get("health", 0)),
	]
	if ranged_count > 0:
		text += ", %d ranged" % ranged_count
	return text

static func _player_force_name_from_battle(battle: Dictionary) -> String:
	var commander_state = _commander_state_for_side(battle, "player")
	var commander_name := String(commander_state.get("name", "")).strip_edges()
	if commander_name != "":
		return "%s's command" % commander_name
	return "Friendly command"

static func _enemy_force_name_from_battle(battle: Dictionary, session: SessionStateStoreScript.SessionData) -> String:
	var army_name := String(battle.get("enemy_army_name", "")).strip_edges()
	if army_name == "":
		army_name = _enemy_force_name_from_battle_army_id(battle, session)
	var commander_state = _commander_state_for_side(battle, "enemy")
	var commander_name := String(commander_state.get("name", "")).strip_edges()
	if commander_name != "" and army_name != "" and commander_name != army_name:
		return "%s's %s" % [commander_name, army_name]
	if army_name != "":
		return army_name
	return "Enemy force"

static func _enemy_force_name_from_battle_army_id(
	battle: Dictionary,
	session: SessionStateStoreScript.SessionData
) -> String:
	var army_id := String(battle.get("enemy_army_id", "")).strip_edges()
	if army_id != "":
		var army := ContentService.get_army_group(army_id)
		var army_name := String(army.get("name", "")).strip_edges()
		if army_name != "":
			return army_name
	if _is_town_assault_context(battle.get("context", {})) or _is_town_defense_context(battle.get("context", {})):
		var town_name = _town_name_from_placement_id(
			session,
			String(battle.get("context", {}).get("town_placement_id", ""))
		)
		if town_name != "":
			return "%s Garrison" % town_name
	return ""

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

static func describe_risk_readiness_board(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Outlook: Tactical risk board unavailable."
	var battle = session.battle
	var lines = [
		"Outlook: %s" % _risk_readiness_grade(session, battle),
		"Initiative swing: %s" % _risk_board_initiative_line(battle),
		"Command posture: %s" % _risk_board_commander_line(battle),
		"Line integrity: %s" % _risk_board_line_integrity_line(battle),
		"Fire lane: %s" % _risk_board_ranged_pressure_line(battle),
		"Priority break: %s" % _risk_board_priority_line(battle),
		"Objective urgency: %s" % _risk_board_objective_line(session, battle),
	]
	var dispatch_line = _risk_board_dispatch_line(battle)
	if dispatch_line != "":
		lines.append("Latest shift: %s" % dispatch_line)
	return "\n".join(lines)

static func describe_tactical_briefing(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return ""
	normalize_battle_state(session)
	if not _should_surface_tactical_briefing(session):
		return ""
	return "\n".join(_tactical_briefing_lines(session))

static func consume_tactical_briefing(session: SessionStateStoreScript.SessionData) -> String:
	var briefing_text = describe_tactical_briefing(session)
	if briefing_text == "":
		return ""
	var briefing_state = session.battle.get(TACTICAL_BRIEFING_KEY, {})
	if not (briefing_state is Dictionary):
		briefing_state = {}
	briefing_state["shown"] = true
	briefing_state["shown_round"] = int(session.battle.get("round", 1))
	session.battle[TACTICAL_BRIEFING_KEY] = briefing_state
	return briefing_text

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
	if session == null or session.battle.is_empty():
		return {
			"active_ability_role": "No battle is active.",
			"status_pressure": "No status pressure.",
			"target_range": "No target selected.",
			"confirmation": "Ready check unavailable.",
			"preferred_action_id": "",
			"action_previews": [],
		}
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var target = get_selected_target(battle)
	var surface = get_action_surface(session)
	var preferred_action_id := _preferred_player_action_id(surface, active_stack) if String(active_stack.get("side", "")) == "player" else ""
	return {
		"active_stack_name": _stack_label(active_stack) if not active_stack.is_empty() else "",
		"active_side": String(active_stack.get("side", "")),
		"target_name": _stack_label(target) if not target.is_empty() else "",
		"active_ability_role": _active_ability_role_line(active_stack, battle, target),
		"status_pressure": _stack_status_pressure_line(active_stack, battle),
		"target_range": _target_range_readiness_line(active_stack, target, battle),
		"confirmation": describe_action_readiness_confirmation(session),
		"preferred_action_id": preferred_action_id,
		"action_previews": _action_consequence_preview_list(surface),
	}

static func post_action_recap_context(session: SessionStateStoreScript.SessionData, action_id: String = "") -> Dictionary:
	if session == null or session.battle.is_empty():
		return {}
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var target = get_selected_target(battle)
	return {
		"action_id": action_id,
		"active_battle_id": String(active_stack.get("battle_id", "")),
		"active_name": _stack_label(active_stack) if not active_stack.is_empty() else "",
		"active_side": String(active_stack.get("side", "")),
		"active_count_before": _alive_count(active_stack) if not active_stack.is_empty() else 0,
		"active_health_before": int(active_stack.get("total_health", 0)),
		"active_hex_before": _hex_label(_stack_hex(active_stack)) if not active_stack.is_empty() else "",
		"active_status_before": _stack_status_pressure_short(active_stack, battle) if not active_stack.is_empty() else "",
		"target_battle_id": String(target.get("battle_id", "")),
		"target_name": _stack_label(target) if not target.is_empty() else "",
		"target_side": String(target.get("side", "")),
		"target_count_before": _alive_count(target) if not target.is_empty() else 0,
		"target_health_before": int(target.get("total_health", 0)),
		"target_hex_before": _hex_label(_stack_hex(target)) if not target.is_empty() else "",
		"target_status_before": _stack_status_pressure_short(target, battle) if not target.is_empty() else "",
	}

static func post_action_recap_payload(
	session: SessionStateStoreScript.SessionData,
	result: Dictionary,
	action_id: String = "",
	context: Dictionary = {}
) -> Dictionary:
	if result.is_empty() or not bool(result.get("ok", false)):
		return {}
	var battle: Dictionary = session.battle if session != null and not session.battle.is_empty() else {}
	var normalized_action_id := action_id
	if normalized_action_id == "":
		normalized_action_id = String(context.get("action_id", result.get("attack_action", "")))
	var happened := _post_action_happened_line(result, normalized_action_id)
	var affected := _post_action_affected_line(battle, result, normalized_action_id, context)
	var decision := _post_action_decision_line(session, result, context)
	var next_actor := _post_action_next_actor_line(session)
	var lines := [
		"After order: %s" % happened,
		"Affected: %s" % affected,
		"Why it matters: %s" % decision,
		"Next: %s" % next_actor,
	]
	var tooltip := "Action Recap\n- Happened: %s\n- Affected: %s\n- Why it matters: %s\n- Next: %s" % [
		happened,
		affected,
		decision,
		next_actor,
	]
	return {
		"action_id": normalized_action_id,
		"state": String(result.get("state", "")),
		"happened": happened,
		"affected": affected,
		"why_it_matters": decision,
		"next_step": next_actor,
		"decision": decision,
		"next_actor": next_actor,
		"text": "\n".join(lines),
		"tooltip": tooltip,
		"tooltip_text": tooltip,
	}

static func describe_target_context(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No target selected."
	var battle = session.battle
	var target = get_selected_target(battle)
	if target.is_empty():
		return "No target selected."
	var summary = _stack_focus_summary(target, battle, false)
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		return summary
	var legality_line := _target_legality_line(active_stack, target, battle)
	if legality_line != "":
		return "%s\n%s\nEngagement: %s" % [summary, legality_line, _engagement_preview(active_stack, target, battle)]
	return "%s\nEngagement: %s" % [summary, _engagement_preview(active_stack, target, battle)]

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
	if session == null or session.battle.is_empty():
		return "No battle orders are available."
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		return "No stack is ready to act."
	if String(active_stack.get("side", "")) != "player":
		return "%s is acting now. Hold the line until command returns." % _stack_label(active_stack)
	var target = get_selected_target(battle)
	var actions = get_action_surface(session)
	var target_line := _target_focus_action_line(active_stack, target, battle)
	var click_intent := selected_target_board_click_intent(battle)
	var movement_intent := active_movement_board_click_intent(battle)
	var continuity_context := selected_target_continuity_context(battle)
	var closing_context := selected_target_closing_context(battle)
	var board_click_line := String(click_intent.get("message", ""))
	if board_click_line == "":
		board_click_line = "Board: select an enemy or move hex to preview; confirm to commit."
	if not continuity_context.is_empty():
		board_click_line = String(continuity_context.get("message", board_click_line))
	elif not closing_context.is_empty():
		board_click_line = String(closing_context.get("message", board_click_line))
	var movement_click_line := String(movement_intent.get("message", ""))
	var manual_cue := _manual_battle_action_cue(actions, click_intent, movement_intent)
	var confirmation_line := describe_action_readiness_confirmation(session)
	var lines = [
		"Target focus: %s" % target_line,
		confirmation_line,
		manual_cue,
		board_click_line,
	]
	if movement_click_line != "":
		lines.append(movement_click_line)
	for action_id in ["advance", "strike", "shoot", "defend", "retreat", "surrender"]:
		var action = actions.get(action_id, {})
		lines.append("%s: %s" % [
			String(action.get("label", action_id.capitalize())),
			String(action.get("summary", "")),
		])
	return "\n".join(lines)

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

static func action_readiness_confirmation_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {
			"visible_text": "Ready check unavailable.",
			"tooltip_text": "Action Confirmation\n- No battle is active.",
		}
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		return {
			"visible_text": "Ready check: no stack is queued.",
			"tooltip_text": "Action Confirmation\n- No stack is queued to act.",
			"next_step": "Wait for battle resolution.",
		}
	if String(active_stack.get("side", "")) != "player":
		var enemy_text := "Ready check: %s has initiative; wait for command to return." % _stack_label(active_stack)
		return {
			"visible_text": enemy_text,
			"tooltip_text": "Action Confirmation\n- Active: %s\n- Next: wait for command to return." % _stack_label(active_stack),
			"active_stack": _stack_label(active_stack),
			"next_step": "Wait for command to return.",
		}

	var target = get_selected_target(battle)
	var surface = get_action_surface(session)
	var action_id := _preferred_player_action_id(surface, active_stack)
	var action: Dictionary = surface.get(action_id, {}) if surface.get(action_id, {}) is Dictionary else {}
	var action_label := String(action.get("label", action_id.capitalize())).strip_edges()
	var target_label := String(action.get("target", _stack_label(target) if not target.is_empty() else "current focus")).strip_edges()
	var consequence := String(action.get("consequence", action.get("summary", ""))).strip_edges()
	var spell_action := _preferred_spell_timing_action(session, battle, active_stack, target)
	var spell_label := String(spell_action.get("label", "")).strip_edges()
	var hold_action: Dictionary = surface.get("defend", {}) if surface.get("defend", {}) is Dictionary else {}
	var hold_ready := not bool(hold_action.get("disabled", true))
	if action_id == "":
		var blocked_text := "Ready check: retarget, move, or wait for a legal order."
		return {
			"visible_text": blocked_text,
			"tooltip_text": "Action Confirmation\n- No ready order is open from this posture.\n- Next: retarget, move, or wait for command to return.",
			"next_step": "Retarget or change posture.",
		}

	var option_parts := []
	if spell_label != "":
		option_parts.append("cast %s first (the stack keeps its order)" % spell_label)
	if hold_ready and action_id != "defend":
		option_parts.append("Defend to hold")
	var option_text := ""
	if not option_parts.is_empty():
		option_text = "; or %s" % ", ".join(option_parts)
	var target_text := " on %s" % target_label if target_label != "" and action_id in ["strike", "shoot"] else ""
	var visible := "Ready check: confirm %s%s%s; order ends this stack's action." % [
		action_label,
		target_text,
		option_text,
	]
	var tooltip := "Action Confirmation\n- Confirm: %s%s\n- Readiness: %s\n- Why: %s\n- Result: %s\n- Next: order ends this stack's action and initiative advances." % [
		action_label,
		target_text,
		String(action.get("readiness", "")),
		String(action.get("why", "")),
		consequence,
	]
	if spell_label != "":
		tooltip += "\n- Cast option: %s" % String(spell_action.get("summary", spell_label))
	if hold_ready and action_id != "defend":
		tooltip += "\n- Hold option: %s" % String(hold_action.get("summary", "Defend to hold position."))
	return {
		"visible_text": visible,
		"tooltip_text": tooltip,
		"action_id": action_id,
		"button_label": action_label,
		"target": target_label,
		"readiness": String(action.get("readiness", "")),
		"why": String(action.get("why", "")),
		"consequence": consequence,
		"spell_option": spell_label,
		"hold_option": "Defend" if hold_ready else "",
		"next_step": "Order ends this stack's action and initiative advances.",
	}

static func describe_action_readiness_confirmation(session: SessionStateStoreScript.SessionData) -> String:
	return String(action_readiness_confirmation_payload(session).get("visible_text", "Ready check unavailable."))

static func intent_forecast_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {
			"visible_text": "Suggested order unavailable.",
			"tooltip_text": "Order Preview\n- No battle is loaded.",
			"readiness": "unavailable",
		}
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		return {
			"visible_text": "Suggested order: wait for the next stack.",
			"tooltip_text": "Order Preview\n- No stack is queued to act.",
			"readiness": "waiting",
		}
	if String(active_stack.get("side", "")) != "player":
		var enemy_action := BattleAiRulesScript.choose_enemy_action(battle, active_stack, battle.get("enemy_hero", {}))
		var enemy_reply := _enemy_action_preview_summary(battle, active_stack, enemy_action)
		return {
			"visible_text": "Incoming order: %s" % _intent_forecast_sentence(enemy_reply),
			"tooltip_text": "Order Preview\n- Active: %s\n- Incoming: %s\n- Readiness: player input is locked until command returns." % [
				_stack_label(active_stack),
				enemy_reply,
			],
			"readiness": "locked",
			"action_id": String(enemy_action.get("action", "")),
			"target_battle_id": String(enemy_action.get("target_battle_id", "")),
			"risk": enemy_reply,
		}

	var surface := get_action_surface(session)
	var spell_actions := get_spell_actions(session)
	var tactical_commander_payload: Dictionary = battle.get("player_hero", {}) if battle.get("player_hero", {}) is Dictionary else {}
	if tactical_commander_payload.is_empty() and battle.get("player_commander_state", {}) is Dictionary:
		tactical_commander_payload = battle.get("player_commander_state", {})
	var tactical_order := BattleAiRulesScript.choose_stack_tactical_order(battle, active_stack, "enemy", tactical_commander_payload)
	var action_id := _intent_forecast_action_id(battle, surface, spell_actions, tactical_order, active_stack)
	if action_id == "":
		return {
			"visible_text": "Suggested order: no legal action is open.",
			"tooltip_text": "Order Preview\n- Active: %s\n- No ready action is available from the current posture.\n- Next: retarget, move, or wait for initiative to change." % _stack_label(active_stack),
			"readiness": "blocked",
		}
	var action := _intent_forecast_action(surface, spell_actions, action_id)
	var target := get_selected_target(battle)
	var tactical_target_id := String(tactical_order.get("target_battle_id", ""))
	if tactical_target_id != "" and _intent_forecast_action_matches_tactical_order(action_id, tactical_order):
		var tactical_target := _get_stack_by_id(battle, tactical_target_id)
		if not tactical_target.is_empty():
			target = tactical_target
	var action_label := String(action.get("label", action_id.capitalize())).strip_edges()
	var target_label := _intent_forecast_target_label(action_id, active_stack, target)
	var expected_result := _intent_forecast_expected_result(action_id, session, battle, active_stack, target, action)
	var reason := String(action.get("why", action.get("best_use", ""))).strip_edges()
	if reason == "":
		reason = _action_why_line(action_id, session, battle, active_stack, target, true)
	var risk := _enemy_reply_line(session, battle)
	var confidence := _intent_forecast_confidence_line(tactical_order, action_id)
	var retarget_line := ""
	if tactical_target_id != "" and tactical_target_id != String(get_selected_target(battle).get("battle_id", "")) and action_id in ["strike", "shoot"]:
		retarget_line = "Retarget first: %s." % target_label
	var visible_order := "%s%s" % [
		action_label,
		" -> %s" % target_label if target_label != "" else "",
	]
	var visible_prefix := "Suggested order: %s; " % visible_order
	var visible_result := _intent_forecast_compact_result(expected_result, maxi(24, 95 - visible_prefix.length()))
	var visible := "%s%s." % [visible_prefix, visible_result]
	var tooltip_lines := [
		"Order Preview",
		"- Active: %s" % _stack_label(active_stack),
		"- Preferred order: %s%s" % [action_label, " -> %s" % target_label if target_label != "" else ""],
		"- Expected result: %s" % expected_result,
		"- Why: %s" % reason,
		"- Risk: %s" % risk,
		"- Confidence: %s" % confidence,
		"- Inspection: checking this forecast does not spend an action, move, attack, cast, or advance initiative.",
	]
	if retarget_line != "":
		tooltip_lines.insert(3, "- %s" % retarget_line)
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"readiness": String(action.get("readiness", "Ready")),
		"action_id": action_id,
		"action_label": action_label,
		"target": target_label,
		"target_battle_id": String(target.get("battle_id", "")),
		"expected_result": expected_result,
		"why": reason,
		"risk": risk,
		"confidence": confidence,
		"scoring_policy": String(tactical_order.get("scoring_policy", "")),
		"candidate_scores": tactical_order.get("candidate_scores", {}).duplicate(true) if tactical_order.get("candidate_scores", {}) is Dictionary else {},
	}

static func _intent_forecast_action_id(
	battle: Dictionary,
	surface: Dictionary,
	spell_actions: Array,
	tactical_order: Dictionary,
	active_stack: Dictionary
) -> String:
	var tactical_action := String(tactical_order.get("action", ""))
	if tactical_action == "cast_spell":
		var tactical_spell_action_id := "cast_spell:%s" % String(tactical_order.get("spell_id", ""))
		if _intent_forecast_tactical_spell_target_is_public(battle, active_stack, tactical_order):
			for action_value in spell_actions:
				if not (action_value is Dictionary):
					continue
				var spell_action: Dictionary = action_value
				if String(spell_action.get("id", "")) == tactical_spell_action_id and not bool(spell_action.get("disabled", true)):
					return tactical_spell_action_id
		return _preferred_player_action_id(surface, active_stack)
	if tactical_action != "":
		var tactical_surface: Dictionary = surface.get(tactical_action, {}) if surface.get(tactical_action, {}) is Dictionary else {}
		if not bool(tactical_surface.get("disabled", true)):
			return tactical_action
	return _preferred_player_action_id(surface, active_stack)

static func _intent_forecast_tactical_spell_target_is_public(
	battle: Dictionary,
	active_stack: Dictionary,
	tactical_order: Dictionary
) -> bool:
	var spell_id := String(tactical_order.get("spell_id", ""))
	var tactical_target_id := String(tactical_order.get("target_battle_id", ""))
	if spell_id == "" or tactical_target_id == "":
		return false
	var spell := ContentService.get_spell(spell_id)
	if spell.is_empty():
		return false
	var public_target_id := ""
	match String(spell.get("target_mode", "")):
		"ally_active":
			public_target_id = String(active_stack.get("battle_id", ""))
		"enemy_selected":
			public_target_id = String(get_selected_target(battle).get("battle_id", ""))
		_:
			return false
	return public_target_id != "" and tactical_target_id == public_target_id

static func _intent_forecast_action(surface: Dictionary, spell_actions: Array, action_id: String) -> Dictionary:
	if action_id.begins_with("cast_spell:"):
		for action_value in spell_actions:
			if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
				return (action_value as Dictionary).duplicate(true)
	var surface_action: Variant = surface.get(action_id, {})
	return (surface_action as Dictionary).duplicate(true) if surface_action is Dictionary else {}

static func _intent_forecast_action_matches_tactical_order(action_id: String, tactical_order: Dictionary) -> bool:
	var tactical_action := String(tactical_order.get("action", ""))
	if tactical_action == "cast_spell":
		return action_id == "cast_spell:%s" % String(tactical_order.get("spell_id", ""))
	return action_id == tactical_action

static func _intent_forecast_target_label(action_id: String, active_stack: Dictionary, target: Dictionary) -> String:
	if action_id.begins_with("cast_spell:"):
		return _stack_label(target) if not target.is_empty() else "spell target"
	match action_id:
		"strike", "shoot":
			return _stack_label(target) if not target.is_empty() else "selected target"
		"advance":
			return _stack_label(target) if not target.is_empty() else "nearest lane"
		"defend", "wait":
			return _stack_label(active_stack) if not active_stack.is_empty() else "active stack"
		"retreat", "surrender":
			return "whole army"
	return ""

static func _intent_forecast_expected_result(
	action_id: String,
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary,
	action: Dictionary
) -> String:
	if action_id.begins_with("cast_spell:"):
		var spell_effect := String(action.get("effect", "")).strip_edges()
		if spell_effect != "":
			return spell_effect.trim_suffix(".")
		return String(action.get("summary", "Casting resolves the selected spell consequence")).strip_edges().trim_suffix(".")
	if action_id in ["strike", "shoot"] and not active_stack.is_empty() and not target.is_empty():
		return _attack_action_summary(active_stack, target, battle, action_id == "shoot").trim_suffix(".")
	if action_id == "advance":
		return _intent_forecast_advance_result(battle, active_stack)
	if action_id == "defend":
		return _defend_action_summary(battle, active_stack).trim_suffix(".")
	if action_id == "retreat":
		return _retreat_action_summary(session).trim_suffix(".")
	if action_id == "surrender":
		return _surrender_action_summary(session).trim_suffix(".")
	var consequence := String(action.get("consequence", action.get("summary", ""))).strip_edges()
	return consequence if consequence != "" else "initiative advances after the order resolves"

static func _intent_forecast_advance_result(battle: Dictionary, active_stack: Dictionary) -> String:
	var summary := _advance_action_summary(battle, active_stack).trim_suffix(".")
	if int(battle.get("distance", 1)) <= 0:
		return String(summary.split(";", false)[0]).strip_edges()
	var consequence_clauses := []
	for clause_value in summary.split(" | ", false):
		var clause := String(clause_value).strip_edges()
		if clause.to_lower().contains("click"):
			continue
		if clause != "":
			consequence_clauses.append(clause)
	return " | ".join(consequence_clauses) if not consequence_clauses.is_empty() else "Advance changes the active stack's battle position"

static func _intent_forecast_sentence(text: String) -> String:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return ""
	var split := cleaned.split(". ", false)
	if split.is_empty():
		return cleaned.trim_suffix(".")
	return String(split[0]).strip_edges().trim_suffix(".")

static func _intent_forecast_compact_result(text: String, max_chars: int) -> String:
	var sentence := _intent_forecast_sentence(text)
	if sentence.length() <= max_chars:
		return sentence
	var selected_clauses: Array[String] = []
	for clause_value in sentence.split(" | ", false):
		var clause := String(clause_value).strip_edges()
		if clause == "":
			continue
		var candidate := " | ".join(selected_clauses + [clause])
		if candidate.length() <= max_chars:
			selected_clauses.append(clause)
			continue
		if selected_clauses.is_empty():
			return "%s..." % clause.left(maxi(1, max_chars - 3))
		break
	return " | ".join(selected_clauses)

static func _intent_forecast_confidence_line(tactical_order: Dictionary, action_id: String) -> String:
	var scores: Dictionary = tactical_order.get("candidate_scores", {}) if tactical_order.get("candidate_scores", {}) is Dictionary else {}
	if scores.is_empty():
		return "manual order surface; no score spread is available."
	var chosen_score := -99999.0
	var next_score := -99999.0
	var score_action_id := "cast_spell" if action_id.begins_with("cast_spell:") else action_id
	for key_value in scores.keys():
		var key := String(key_value)
		var score := float(scores.get(key_value, 0.0))
		if key == score_action_id:
			chosen_score = score
		elif score > next_score:
			next_score = score
	if chosen_score <= -99998.0:
		return "fallback from scored order; selected action was not in the candidate spread."
	if next_score <= -99998.0:
		return "single scored option at %.1f." % chosen_score
	var margin := chosen_score - next_score
	var band := "close"
	if margin >= 3.0:
		band = "strong"
	elif margin >= 1.0:
		band = "clear"
	return "%s scored pick: %.1f vs next %.1f." % [band, chosen_score, next_score]

static func _manual_battle_action_cue(actions: Dictionary, click_intent: Dictionary, movement_intent: Dictionary) -> String:
	var click_action := String(click_intent.get("action", ""))
	var click_label := String(click_intent.get("label", "")).strip_edges()
	if click_action != "" and click_label != "":
		return "Try: click the highlighted target to %s, or click %s." % [
			click_label.to_lower(),
			_action_button_label(actions, click_action),
		]

	if String(movement_intent.get("action", "")) == "move":
		var ready_after_move := _first_ready_action_label(actions, ["strike", "shoot", "advance", "defend"])
		if ready_after_move != "":
			return "Try: click a move hex to move, or click %s." % ready_after_move
		return "Try: click a move hex to move this stack."

	var ready_action := _first_ready_action_label(actions, ["strike", "shoot", "advance", "defend", "retreat", "surrender"])
	if ready_action != "":
		return "Try: click %s for the next order." % ready_action
	return "Try: cycle target focus or wait for command to return."

static func _action_button_label(actions: Dictionary, action_id: String) -> String:
	var action_value = actions.get(action_id, {})
	if action_value is Dictionary:
		var label := String(action_value.get("label", action_id.capitalize())).strip_edges()
		if label != "":
			return label
	return action_id.capitalize()

static func _first_ready_action_label(actions: Dictionary, action_ids: Array) -> String:
	for action_id_value in action_ids:
		var action_id := String(action_id_value)
		var action_value = actions.get(action_id, {})
		if not (action_value is Dictionary):
			continue
		if bool(action_value.get("disabled", false)):
			continue
		return _action_button_label(actions, action_id)
	return ""

static func describe_spell_timing_board(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Spell and Ability Timing\n- Timing board unavailable."
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var target = get_selected_target(battle)
	if active_stack.is_empty():
		return "Spell and Ability Timing\n- No active stack is shaping a timing window."
	if String(active_stack.get("side", "")) != "player":
		return "\n".join(
			[
				"Spell and Ability Timing",
				"- Enemy initiative: %s is acting now; the player spell and order windows are closed." % _stack_label(active_stack),
				"- Enemy spell pressure: %s" % _enemy_spell_threat_line(battle, active_stack),
				"- Incoming burst: %s" % _burst_risk_line(session, battle),
			]
		)
	return "\n".join(
		[
			"Spell and Ability Timing",
			"- Spell window: %s" % _spell_window_line(session, battle, active_stack, target),
			"- Support payoff: %s" % _support_payoff_line(session, battle, active_stack, target),
			"- Protection need: %s" % _protection_need_line(session, battle, active_stack, target),
			"- Burst risk: %s" % _burst_risk_line(session, battle),
		]
	)

static func _spell_window_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	if active_stack.is_empty():
		return "No active stack is shaping a timing window."
	if String(active_stack.get("side", "")) != "player":
		return _enemy_spell_threat_line(battle, active_stack)
	if _commander_spell_cast_this_round(battle, "player"):
		return _player_spell_cast_used_summary()
	var preferred_action = _preferred_spell_timing_action(session, battle, active_stack, target)
	if not preferred_action.is_empty():
		return "%s: %s" % [
			String(preferred_action.get("label", "Battle spell")),
			String(preferred_action.get("summary", "A battle spell is ready.")),
		]
	var commander = _player_commander_state(session)
	var mana = SpellRulesScript.mana_state(commander)
	var known_spells = SpellRulesScript.known_spells(commander, SpellRulesScript.CONTEXT_BATTLE)
	if known_spells.is_empty():
		return "No battle spell is authored for this commander; this turn has to come from unit timing."
	if int(mana.get("current", 0)) <= 0:
		return "Mana is dry at %d/%d, so the order has to come from unit timing alone." % [
			int(mana.get("current", 0)),
			int(mana.get("max", 0)),
		]
	if target.is_empty():
		return "Retarget first; the damage spells need a legal enemy stack before the window opens."
	return "No legal spell window is open from this posture; stabilize or change the exchange first."

static func _preferred_spell_timing_action(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> Dictionary:
	var best = {}
	var best_score = -99999.0
	var availability = action_availability(battle)
	for action in get_spell_actions(session):
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var spell_id = String(action.get("id", "")).trim_prefix("cast_spell:")
		var spell = ContentService.get_spell(spell_id)
		if spell.is_empty():
			continue
		var score = _spell_timing_action_score(battle, active_stack, target, spell, availability)
		if best.is_empty() or score > best_score:
			best = action
			best_score = score
	return best

static func _spell_timing_action_score(
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary,
	spell: Dictionary,
	availability: Dictionary
) -> float:
	var effect = spell.get("effect", {})
	var effect_type = String(effect.get("type", ""))
	var score = 0.0
	match effect_type:
		"damage_enemy":
			score = 4.0
			if not target.is_empty():
				score += 2.0
				if bool(target.get("ranged", false)):
					score += 1.0
				if _health_ratio(target) <= 0.75:
					score += 1.0
			var status_effect = effect.get("status_effect", {})
			var effect_id = String(status_effect.get("effect_id", status_effect.get("status_id", "")))
			if effect_id != "" and not target.is_empty() and not SpellRulesScript.has_effect_id(target, battle, effect_id):
				score += 1.5
		"control_enemy":
			score = 3.5
			if not target.is_empty():
				score += 1.5
				if _stack_cohesion_total(target, battle) <= 5:
					score += 1.0
			var control_effect = effect.get("status_effect", {})
			var control_effect_id = String(control_effect.get("effect_id", control_effect.get("status_id", "")))
			if control_effect_id != "" and not target.is_empty() and not SpellRulesScript.has_effect_id(target, battle, control_effect_id):
				score += 2.0
		"recover_ally":
			score = 2.5
			if _health_ratio(active_stack) <= 0.65:
				score += 3.0
			if _stack_cohesion_total(active_stack, battle) <= 5:
				score += 1.0
		"cleanse_ally":
			score = 2.5
			if SpellRulesScript.has_any_effect_ids(active_stack, battle, effect.get("cleanse_effect_ids", [])):
				score += 4.0
			if _stack_cohesion_total(active_stack, battle) <= 5:
				score += 1.0
		"defense_buff":
			score = 2.0
			if _stack_cohesion_total(active_stack, battle) <= 5:
				score += 2.5
			if _stack_is_isolated(battle, active_stack):
				score += 1.5
			if int(battle.get("distance", 1)) <= 0 or bool(active_stack.get("defending", false)):
				score += 1.0
		"initiative_buff":
			score = 2.0
			if int(battle.get("round", 1)) <= 2:
				score += 1.5
			if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
				score += 1.5
			if not bool(active_stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
				score += 1.5
		"attack_buff":
			score = 2.0
			if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
				score += 2.0
			if bool(availability.get("shoot", false)) or bool(availability.get("strike", false)):
				score += 1.5
			if not target.is_empty() and _health_ratio(target) <= 0.75:
				score += 1.0
	return score

static func _support_payoff_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	var followup_line = _support_followup_line(battle, target)
	if followup_line != "":
		return followup_line
	if not active_stack.is_empty() and String(active_stack.get("side", "")) == "player":
		var active_ability = _active_ability_window_summary(active_stack, battle, target)
		if active_ability != "":
			return active_ability
	if _side_has_ability(battle, "player", "formation_guard") and _side_defending_count(battle, "player") > 0 and _allied_ranged_count(battle, "player") > 0:
		return "Formation Guard plus defending screens is still feeding the firing line."
	if _side_has_ability(battle, "player", "volley") and int(battle.get("distance", 1)) > 0:
		return "Volley stacks still want the long lane before melee compresses the board."
	if _side_positive_effect_count(battle, "player") > 0 and _battle_has_any_tags(battle, ["battery_nest", "elevated_fire", "open_lane"]):
		return "Positive effects are amplifying the fire lane; spend them before distance closes."
	return "No major support chain is live beyond the base exchange."

static func _support_followup_line(battle: Dictionary, target: Dictionary) -> String:
	var targets = []
	if not target.is_empty() and String(target.get("side", "")) == "enemy":
		targets.append(target)
	for enemy in _alive_stacks_for_side(battle, "enemy"):
		if target.is_empty() or String(enemy.get("battle_id", "")) != String(target.get("battle_id", "")):
			targets.append(enemy)
	for enemy in targets:
		if not (enemy is Dictionary):
			continue
		if SpellRulesScript.has_effect_id(enemy, battle, STATUS_HARRIED):
			var finisher = _first_stack_with_any_ability(battle, "player", ["backstab", "bloodrush", "shielding"])
			if not finisher.is_empty():
				return "%s is harried; %s can cash that mark once contact holds." % [
					_stack_label(enemy),
					_stack_label(finisher),
				]
		if SpellRulesScript.has_effect_id(enemy, battle, STATUS_STAGGERED):
			var punisher = _first_stack_with_any_ability(battle, "player", ["formation_guard", "reach", "brace"])
			if not punisher.is_empty():
				return "%s is staggered; %s can punish the slowed window on the next grounded trade." % [
					_stack_label(enemy),
					_stack_label(punisher),
				]
	return ""

static func _protection_need_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	var protected_stack = _priority_friendly_protection_stack(battle)
	if protected_stack.is_empty():
		return "No friendly stack is demanding emergency cover yet."
	var threat_stack = get_active_stack(battle)
	if threat_stack.is_empty() or String(threat_stack.get("side", "")) != "enemy":
		threat_stack = _next_enemy_reply_stack(battle)
	var threat_label = _stack_label(threat_stack) if not threat_stack.is_empty() else "the next hostile stack"
	if not active_stack.is_empty() and String(active_stack.get("side", "")) == "player" and String(active_stack.get("battle_id", "")) == String(protected_stack.get("battle_id", "")):
		var support_spell = _best_ready_support_spell_action(session, battle, active_stack, target)
		if not support_spell.is_empty():
			return "%s is the exposed lane; %s" % [
				_stack_label(protected_stack),
				String(support_spell.get("summary", "A support spell is ready.")),
			]
		var defend_surface = get_action_surface(session).get("defend", {})
		if defend_surface is Dictionary and not bool(defend_surface.get("disabled", true)):
			return "%s is the exposed lane; %s" % [
				_stack_label(protected_stack),
				String(defend_surface.get("summary", "Defend and hold the line.")),
			]
	if SpellRulesScript.has_any_effect_ids(protected_stack, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
		return "%s is already pressured and there is no authored cleanse in the current spellbook; blunt %s before the burst lands." % [
			_stack_label(protected_stack),
			threat_label,
		]
	if bool(protected_stack.get("ranged", false)):
		return "%s is the soft back-line point; keep screens intact or break %s before it reaches the firing lane." % [
			_stack_label(protected_stack),
			threat_label,
		]
	return "%s is the softest point in the line; trade this turn to keep %s from getting the next clean burst." % [
		_stack_label(protected_stack),
		threat_label,
	]

static func _priority_friendly_protection_stack(battle: Dictionary) -> Dictionary:
	var threat_stack = get_active_stack(battle)
	if threat_stack.is_empty() or String(threat_stack.get("side", "")) != "enemy":
		threat_stack = _next_enemy_reply_stack(battle)
	var threatened_target_id = ""
	if not threat_stack.is_empty():
		var threat_action = BattleAiRulesScript.choose_enemy_action(
			battle,
			threat_stack,
			battle.get("enemy_hero", {})
		)
		threatened_target_id = String(threat_action.get("target_battle_id", ""))
	var best = {}
	var best_score = 0
	for stack in _alive_stacks_for_side(battle, "player"):
		var score = 0
		if String(stack.get("battle_id", "")) == threatened_target_id:
			score += 3
		if _stack_cohesion_total(stack, battle) <= 4:
			score += 3
		elif _stack_cohesion_total(stack, battle) <= 5:
			score += 1
		if _stack_is_isolated(battle, stack):
			score += 2
		if SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
			score += 2
		if _health_ratio(stack) <= 0.6:
			score += 2
		if bool(stack.get("ranged", false)):
			score += 1
		if _stack_has_positive_effect(stack, battle):
			score += 1
		if best.is_empty() or score > best_score:
			best = stack
			best_score = score
	if best_score >= 3:
		return best
	return {}

static func _best_ready_support_spell_action(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> Dictionary:
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return {}
	var best = {}
	var best_score = -99999.0
	for action in get_spell_actions(session):
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var spell_id = String(action.get("id", "")).trim_prefix("cast_spell:")
		var spell = ContentService.get_spell(spell_id)
		if spell.is_empty():
			continue
		var effect_type = String(spell.get("effect", {}).get("type", ""))
		if effect_type == "damage_enemy":
			continue
		var score = 0.0
		match effect_type:
			"defense_buff":
				score = 4.0
				if _stack_cohesion_total(active_stack, battle) <= 5:
					score += 2.0
				if _stack_is_isolated(battle, active_stack):
					score += 1.5
			"initiative_buff":
				score = 3.0
				if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
					score += 1.5
				if not bool(active_stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					score += 1.5
			"attack_buff":
				score = 2.0
				if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
					score += 2.0
				if not target.is_empty() and _health_ratio(target) <= 0.75:
					score += 1.0
		if best.is_empty() or score > best_score:
			best = action
			best_score = score
	return best

static func _burst_risk_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var reply_stack = get_active_stack(battle)
	if reply_stack.is_empty() or String(reply_stack.get("side", "")) != "enemy":
		reply_stack = _next_enemy_reply_stack(battle)
	if reply_stack.is_empty():
		return "No hostile reply remains after this exchange."
	var action = BattleAiRulesScript.choose_enemy_action(
		battle,
		reply_stack,
		battle.get("enemy_hero", {})
	)
	if action.is_empty():
		return "No hostile burst line is visible yet."
	var summary = _enemy_action_preview_summary(battle, reply_stack, action)
	var target = _get_stack_by_id(battle, String(action.get("target_battle_id", "")))
	match String(action.get("action", "")):
		"cast_spell":
			var spell = ContentService.get_spell(String(action.get("spell_id", "")))
			var timing_hint = SpellRulesScript.battle_spell_timing_summary(
				battle.get("enemy_hero", {}),
				battle,
				reply_stack,
				target,
				spell
			)
			var suffix = ""
			if timing_hint != "":
				suffix = " %s" % timing_hint
			return "%s%s" % [summary, suffix]
		"shoot":
			if not target.is_empty() and bool(target.get("ranged", false)) and _health_ratio(target) <= 0.75:
				return "%s The enemy is lining up a back-line break on %s." % [summary, _stack_label(target)]
		"strike":
			if not target.is_empty() and _has_ability(reply_stack, "bloodrush") and _health_ratio(target) <= 0.75:
				return "%s Bloodrush is live on %s." % [summary, _stack_label(target)]
			if not target.is_empty() and _has_ability(reply_stack, "backstab") and SpellRulesScript.has_any_effect_ids(target, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
				return "%s Backstab payoff is live on %s." % [summary, _stack_label(target)]
			if _brace_available(reply_stack, battle) and bool(reply_stack.get("defending", false)):
				return "%s Brace will punish the first stack that overcommits into it." % summary
		"defend":
			if _has_ability(reply_stack, "formation_guard"):
				return "%s Formation Guard will keep the hostile firing line covered." % summary
	return summary

static func _enemy_spell_threat_line(battle: Dictionary, enemy_stack: Dictionary) -> String:
	var action = BattleAiRulesScript.choose_enemy_action(
		battle,
		enemy_stack,
		battle.get("enemy_hero", {})
	)
	if String(action.get("action", "")) != "cast_spell":
		return "%s is acting now; no enemy spell timing window is leading the exchange." % _stack_label(enemy_stack)
	var spell = ContentService.get_spell(String(action.get("spell_id", "")))
	var target = _get_stack_by_id(battle, String(action.get("target_battle_id", "")))
	var timing_hint = SpellRulesScript.battle_spell_timing_summary(
		battle.get("enemy_hero", {}),
		battle,
		enemy_stack,
		target,
		spell
	)
	var target_suffix = ""
	if not target.is_empty():
		target_suffix = " on %s" % _stack_label(target)
	var timing_suffix = ""
	if timing_hint != "":
		timing_suffix = " %s" % timing_hint
	return "%s can cast %s%s.%s" % [
		_stack_label(enemy_stack),
		String(spell.get("name", "a spell")),
		target_suffix,
		timing_suffix,
	]

static func _first_stack_with_any_ability(battle: Dictionary, side: String, ability_ids: Array) -> Dictionary:
	for stack in _alive_stacks_for_side(battle, side):
		for ability_id_value in ability_ids:
			if _has_ability(stack, String(ability_id_value)):
				return stack
	return {}

static func _preferred_player_action_id(surface: Dictionary, active_stack: Dictionary) -> String:
	if not bool(surface.get("shoot", {}).get("disabled", true)) and bool(active_stack.get("ranged", false)):
		return "shoot"
	if not bool(surface.get("strike", {}).get("disabled", true)):
		return "strike"
	if not bool(surface.get("advance", {}).get("disabled", true)):
		return "advance"
	if not bool(surface.get("defend", {}).get("disabled", true)):
		return "defend"
	if not bool(surface.get("retreat", {}).get("disabled", true)):
		return "retreat"
	if not bool(surface.get("surrender", {}).get("disabled", true)):
		return "surrender"
	return ""

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

static func _enemy_reply_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var reply_stack = _next_enemy_reply_stack(battle)
	if reply_stack.is_empty():
		return "No hostile stack remains to answer the next order."
	var action = BattleAiRulesScript.choose_enemy_action(
		battle,
		reply_stack,
		battle.get("enemy_hero", {})
	)
	return _enemy_action_preview_summary(battle, reply_stack, action)

static func _next_enemy_reply_stack(battle: Dictionary) -> Dictionary:
	var turn_order = battle.get("turn_order", [])
	if turn_order is Array:
		for index in range(int(battle.get("turn_index", 0)) + 1, turn_order.size()):
			var stack = _get_stack_by_id(battle, String(turn_order[index]))
			if not stack.is_empty() and _alive_count(stack) > 0 and String(stack.get("side", "")) == "enemy":
				return stack
	for stack in _alive_stacks_for_side(battle, "enemy"):
		if stack is Dictionary:
			return stack
	return {}

static func _enemy_action_preview_summary(battle: Dictionary, enemy_stack: Dictionary, action: Dictionary) -> String:
	if enemy_stack.is_empty():
		return "Hostile reply is unclear."
	var action_id = String(action.get("action", ""))
	var target = _get_stack_by_id(battle, String(action.get("target_battle_id", "")))
	match action_id:
		"cast_spell":
			var spell = ContentService.get_spell(String(action.get("spell_id", "")))
			return "%s is best placed to cast %s%s." % [
				_stack_label(enemy_stack),
				String(spell.get("name", "a spell")),
				" on %s" % _stack_label(target) if not target.is_empty() else "",
			]
		"shoot":
			return "%s is best placed to fire into %s." % [
				_stack_label(enemy_stack),
				_stack_label(target) if not target.is_empty() else "the exposed line",
			]
		"strike":
			return "%s is set to strike %s in the next exchange." % [
				_stack_label(enemy_stack),
				_stack_label(target) if not target.is_empty() else "the front rank",
			]
		"advance":
			return "%s is set to close the distance and press the lane." % _stack_label(enemy_stack)
		"defend":
			return "%s is set to hold and steady the hostile line." % _stack_label(enemy_stack)
		"wait":
			return "%s is set to wait and let the line come to it." % _stack_label(enemy_stack)
	return "%s is best placed to keep pressure on the line." % _stack_label(enemy_stack)

static func _attack_action_summary(attacker: Dictionary, target: Dictionary, battle: Dictionary, is_ranged: bool) -> String:
	if attacker.is_empty() or target.is_empty():
		return "No clean target is lined up yet."
	if String(attacker.get("battle_id", "")) == String(battle.get("active_stack_id", "")):
		var exchange := attack_consequence_preview(battle, "shoot" if is_ranged else "strike", String(target.get("battle_id", "")))
		if bool(exchange.get("ok", false)): return String(exchange.message).replace("\n", " | ")
	if not is_ranged:
		var approach := melee_approach_destination(battle, attacker, target)
		if not approach.is_empty():
			return "Move to %s and strike %s in one action; retaliation applies." % [_hex_label(approach), _stack_label(target)]
	var attack_distance = _attack_distance_for_action(attacker, target, battle, is_ranged)
	var attack_preview = _damage_range_preview(attacker, target, battle, is_ranged, false, attack_distance)
	if attack_preview.is_empty():
		return "No clean target is lined up yet."
	var clauses = [
		"%s %s for %s" % [
			"Fire on" if is_ranged else "Hit",
			_stack_label(target),
			_damage_preview_text(attack_preview),
		],
	]
	if is_ranged:
		clauses.append("shots after volley %d" % max(0, int(attacker.get("shots_remaining", 0)) - 1))
		var ranged_return := _ranged_damage_return_ratio(target)
		if ranged_return > 0.0:
			var shielding := _ability_by_id(target, "shielding")
			clauses.append("%s returns %d%% of damage received if the target survives" % [
				String(shielding.get("name", "Shielding")),
				int(round(ranged_return * 100.0)),
			])
		if _side_controls_field_objective_type(battle, String(target.get("side", "")), "cover_line") and attack_distance > 0:
			clauses.append("enemy cover will blunt part of the volley")
		elif _side_controls_field_objective_type(battle, String(attacker.get("side", "")), "cover_line") and attack_distance > 0:
			clauses.append("friendly cover keeps the firing angle cleaner")
	else:
		if int(target.get("retaliations_left", 0)) > 0 and _can_make_retaliation(target, attack_distance, battle):
			var retaliation_preview = _retaliation_range_preview(attacker, target, battle, attack_distance, attack_preview)
			if not retaliation_preview.is_empty():
				clauses.append("expect %s retaliation" % _damage_preview_text(retaliation_preview))
		else:
			clauses.append("retaliation is spent or blocked")
	var objective_preview = _field_objective_action_preview(
		battle,
		{
			"action": "shoot" if is_ranged else "strike",
			"side": String(attacker.get("side", "")),
			"battle_id": String(attacker.get("battle_id", "")),
			"target_battle_id": String(target.get("battle_id", "")),
		}
	)
	if objective_preview != "":
		clauses.append(objective_preview)
	return "%s." % " | ".join(clauses)

static func _attack_unavailable_summary(attacker: Dictionary, target: Dictionary, battle: Dictionary, is_ranged: bool) -> String:
	if attacker.is_empty():
		return "No stack is ready to act."
	if target.is_empty():
		return "No target is selected."
	var target_label := _stack_label(target)
	var legality := _attack_legality_for_target(attacker, target, battle)
	if is_ranged:
		if not bool(attacker.get("ranged", false)):
			if bool(legality.get("melee", false)):
				return "%s has no ranged attack; Strike is legal on %s." % [_stack_label(attacker), target_label]
			return "%s has no ranged attack; %s needs melee positioning before it can be attacked." % [_stack_label(attacker), target_label]
		if int(attacker.get("shots_remaining", 0)) <= 0:
			if bool(legality.get("melee", false)):
				return "No shots remain; Strike is legal on %s." % target_label
			return "No shots remain, and %s is blocked from melee at this hex." % target_label
		return "%s is not a legal ranged target from this hex." % target_label
	if bool(legality.get("ranged", false)):
		return "%s is outside melee reach; Shoot is the legal order from this hex." % target_label
	if bool(legality.get("blocked", false)):
		if not _legal_attack_target_ids_for_active_stack(battle).is_empty():
			return "%s is blocked for Strike from this hex; select a highlighted enemy or move hex to preview, then confirm." % target_label
		return "%s is blocked for Strike from this hex; click a move hex to approach attack range." % target_label
	return "Close the distance or secure a target before striking."

static func _target_focus_action_line(active_stack: Dictionary, target: Dictionary, battle: Dictionary) -> String:
	if target.is_empty():
		return "No target selected"
	var target_label := _stack_label(target)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return target_label
	var legality := _attack_legality_for_target(active_stack, target, battle)
	var closing_context := selected_target_closing_context(battle)
	if not closing_context.is_empty():
		if bool(legality.get("attackable", false)):
			var closing_action_label := String(closing_context.get("board_click_label", "attack"))
			return "%s (closing; click: %s)" % [target_label, closing_action_label]
		if bool(legality.get("blocked", false)):
			return "%s (closing; blocked)" % target_label
	if bool(legality.get("attackable", false)):
		var click_intent := board_click_attack_intent_for_target(battle, String(target.get("battle_id", "")))
		var action_label := String(click_intent.get("label", ""))
		if action_label != "":
			return "%s (board click: %s)" % [target_label, action_label]
		return "%s (board click attacks)" % target_label
	if bool(legality.get("blocked", false)):
		return "%s (blocked from current hex)" % target_label
	return target_label

static func _target_legality_line(active_stack: Dictionary, target: Dictionary, battle: Dictionary) -> String:
	if active_stack.is_empty() or target.is_empty() or String(active_stack.get("side", "")) != "player":
		return ""
	var continuity_context := selected_target_continuity_context(battle)
	if not continuity_context.is_empty():
		return String(continuity_context.get("target_line", continuity_context.get("message", "")))
	var closing_context := selected_target_closing_context(battle)
	if not closing_context.is_empty():
		return String(closing_context.get("target_line", closing_context.get("message", "")))
	var legality := _attack_legality_for_target(active_stack, target, battle)
	if bool(legality.get("attackable", false)):
		var click_intent := board_click_attack_intent_for_target(battle, String(target.get("battle_id", "")))
		var action_label := String(click_intent.get("label", "attack"))
		return "Target legality: board click will %s %s now." % [action_label, _stack_label(target)]
	if bool(legality.get("blocked", false)):
		if not _legal_attack_target_ids_for_active_stack(battle).is_empty():
			return "Selected target blocked: this hex cannot attack %s; click a highlighted enemy to attack now, or click a move hex for later reach." % _stack_label(target)
		return "Selected target blocked: this hex cannot attack %s; click a move hex to approach attack range." % _stack_label(target)
	return ""

static func _advance_action_summary(battle: Dictionary, stack: Dictionary) -> String:
	var clauses = []
	var stalled := _advance_stalled_by_obstruction(stack, battle)
	var destination := {}
	if stalled:
		clauses.append("Press into the obstruction line without moving")
	else:
		var nearest := BattleAiRulesScript.advance_target(battle, stack)
		destination = BattleAiRulesScript.best_advance_destination(battle, stack, nearest, _advance_desired_gap(stack, battle))
		if destination.is_empty():
			clauses.append("No open hex to move into")
		else:
			var steps := int(destination.get("steps", 1))
			clauses.append("Move %d hex%s toward %s" % [steps, "" if steps == 1 else "es", _stack_label(nearest)])
			clauses.append("move hex clicks choose exact movement")
	var momentum_gain = _preview_advance_momentum_gain(stack, battle)
	if momentum_gain > 0:
		clauses.append("momentum +%d" % momentum_gain)
	if _side_controls_field_objective_type(battle, _opposing_side(String(stack.get("side", ""))), "obstruction_line"):
		if not stalled:
			clauses.append("enemy obstruction will still tax the push")
		else:
			clauses.append("enemy obstruction can still hold the lane")
	elif _side_controls_field_objective_type(battle, _opposing_side(String(stack.get("side", ""))), "cover_line"):
		clauses.append("closing also strips hostile cover")
	if not bool(stack.get("ranged", false)) and not destination.is_empty() and _projected_min_opposing_hex_distance(battle, stack, destination) <= 1:
		clauses.append("melee contact opens immediately")
	var objective_preview = _field_objective_action_preview(
		battle,
		{
			"action": "advance",
			"side": String(stack.get("side", "")),
			"battle_id": String(stack.get("battle_id", "")),
		}
	)
	if objective_preview != "":
		clauses.append(objective_preview)
	return "%s." % " | ".join(clauses)

static func _defend_action_summary(battle: Dictionary, stack: Dictionary) -> String:
	var clauses = ["Brace this stack for the next exchange"]
	var cohesion_gain = _preview_defend_cohesion_gain(stack, battle)
	if cohesion_gain > 0:
		clauses.append("cohesion +%d" % cohesion_gain)
	if int(stack.get("momentum", 0)) > 0:
		clauses.append("shed 1 momentum")
	if bool(stack.get("ranged", false)):
		clauses.append("protect the firing lane")
	elif int(stack.get("retaliations_left", 0)) > 0:
		clauses.append("retaliation stays live")
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "cover_line"):
		clauses.append("hold the screened cover line")
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line"):
		clauses.append("keep the obstruction sealed")
	if _brace_available(stack, battle):
		clauses.append("Brace can stagger the next attacker")
	elif _has_ability(stack, "formation_guard"):
		clauses.append("Formation Guard steadies nearby lanes")
	var objective_preview = _field_objective_action_preview(
		battle,
		{
			"action": "defend",
			"side": String(stack.get("side", "")),
			"battle_id": String(stack.get("battle_id", "")),
		}
	)
	if objective_preview != "":
		clauses.append(objective_preview)
	return "%s." % " | ".join(clauses)

static func _retreat_action_summary(session: SessionStateStoreScript.SessionData) -> String:
	return BattleEngine.native_writing(&"BattleRules._retreat_action_summary", [session])

static func _surrender_action_summary(session: SessionStateStoreScript.SessionData) -> String:
	return BattleEngine.native_writing(&"BattleRules._surrender_action_summary", [session])

static func _battle_enemy_faction_id(session: SessionStateStoreScript.SessionData) -> String:
	return BattleEngine.native_writing(&"BattleRules._battle_enemy_faction_id", [session])

static func _enemy_state_exists(session: SessionStateStoreScript.SessionData, faction_id: String) -> bool:
	return BattleEngine.native_writing(&"BattleRules._enemy_state_exists", [session, faction_id])

static func _preview_advance_momentum_gain(stack: Dictionary, battle: Dictionary) -> int:
	if stack.is_empty():
		return 0
	var momentum_gain = 1 if not bool(stack.get("ranged", false)) else 0
	if _hero_has_trait(battle, String(stack.get("side", "")), "vanguard") and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _hero_has_trait(battle, String(stack.get("side", "")), "ambusher") and _battle_has_any_tags(battle, ["ambush_cover"]) and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _battle_has_tag(battle, "open_lane") and (not bool(stack.get("ranged", false)) or _hero_has_trait(battle, String(stack.get("side", "")), "artillerist")):
		momentum_gain += 1
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line") and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _side_controls_field_objective_type(battle, _opposing_side(String(stack.get("side", ""))), "obstruction_line"):
		if _stack_can_breach_obstruction(stack, battle):
			momentum_gain -= 1
		else:
			momentum_gain = 0
	return max(0, momentum_gain)

static func _preview_defend_cohesion_gain(stack: Dictionary, battle: Dictionary) -> int:
	if stack.is_empty():
		return 0
	var cohesion_gain = 1
	var brace = _ability_by_id(stack, "brace")
	if not brace.is_empty() and _brace_available(stack, battle):
		cohesion_gain += max(0, int(brace.get("defending_cohesion_bonus", 0)))
	var bramble_ground := _bramble_ground_ability(stack)
	if not bramble_ground.is_empty() and _bramble_ground_available(stack, battle, bramble_ground):
		cohesion_gain += max(0, int(bramble_ground.get("defending_cohesion_bonus", 0)))
	var formation_guard = _ability_by_id(stack, "formation_guard")
	if not formation_guard.is_empty():
		cohesion_gain += max(0, int(formation_guard.get("defending_cohesion_bonus", 0)))
	if _hero_has_trait(battle, String(stack.get("side", "")), "linekeeper"):
		cohesion_gain += 1
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", false)):
		cohesion_gain += 1
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "cover_line"):
		cohesion_gain += 1
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line") and not bool(stack.get("ranged", false)):
		cohesion_gain += 1
	return max(0, cohesion_gain)

static func _active_ability_window_summary(stack: Dictionary, battle: Dictionary, target: Dictionary) -> String:
	if stack.is_empty():
		return ""
	var charter_brace := _ability_by_id(stack, "brace")
	if float(charter_brace.get("ally_retaliation_multiplier", 1.0)) > 1.0:
		for ally in _alive_stacks_for_side(battle, String(stack.get("side", ""))):
			if String(ally.get("battle_id", "")) == String(stack.get("battle_id", "")):
				continue
			var aura_context := _charter_retaliation_aura_context(ally, battle)
			if String(aura_context.get("source", {}).get("battle_id", "")) != String(stack.get("battle_id", "")):
				continue
			if bool(ally.get("defending", false)):
				return "%s is raising %s's retaliation while that veteran line defends." % [String(charter_brace.get("name", "Charter Lock")), _stack_label(ally)]
		return "%s is waiting for another veteran melee line to defend within the formation." % String(charter_brace.get("name", "Charter Lock"))
	var fog_screen := _fog_screen_ability(stack)
	if not fog_screen.is_empty():
		if _fog_screen_available(stack, battle, fog_screen):
			return "%s is live in this fog bank, reducing incoming damage while the screen holds." % String(fog_screen.get("name", "Fog Screen"))
		return "%s is waiting for a natural fog bank." % String(fog_screen.get("name", "Fog Screen"))
	var readiness_writ := _readiness_writ_ability(stack)
	if not readiness_writ.is_empty():
		var readiness_uses = stack.get("ability_uses", {})
		if readiness_uses is Dictionary and int(readiness_uses.get("readiness_writ", 0)) >= int(readiness_writ.get("uses_per_battle", 1)):
			return "%s has already steadied one allied line this battle." % String(readiness_writ.get("name", "Readiness Writ"))
		var readiness_target := _readiness_writ_target(battle, stack, readiness_writ)
		if not readiness_target.is_empty():
			return "%s will clear the disruption from %s after this shot." % [String(readiness_writ.get("name", "Readiness Writ")), _stack_label(readiness_target)]
	var distance = int(battle.get("distance", 1))
	if _reach_available(stack, battle) and not bool(stack.get("ranged", false)) and distance == 1:
		return "Reach makes melee contact live from the current closing distance."
	if _has_ability(stack, "hookline") and int(battle.get("round", 1)) < int(_ability_by_id(stack, "hookline").get("available_from_round", 1)):
		return "%s is waiting for the midline exchange." % String(_ability_by_id(stack, "hookline").get("name", "Hookline"))
	if _hookline_available(stack, battle) and not bool(stack.get("ranged", false)) and distance == 1:
		return "%s can pin the selected line from the current closing distance." % String(_ability_by_id(stack, "hookline").get("name", "Hookline"))
	if _has_ability(stack, "hookline") and not _hookline_available(stack, battle):
		return "%s has already been spent this battle." % String(_ability_by_id(stack, "hookline").get("name", "Hookline"))
	if _has_ability(stack, "volley") and bool(stack.get("ranged", false)) and distance >= int(_ability_by_id(stack, "volley").get("min_distance", 1)):
		var active_volley := _ability_by_id(stack, "volley")
		if bool(active_volley.get("requires_protected_lane", false)):
			if _volley_has_protected_lane(stack, battle, active_volley):
				return "%s has full pressure behind the held line." % String(active_volley.get("name", "Volley"))
			return "%s needs a defending allied screen or controlled firing lane before its heavy shot comes online." % String(active_volley.get("name", "Volley"))
		return "Volley rewards the long lane while the firing line stays open."
	if _has_ability(stack, "obituary") and bool(stack.get("ranged", false)):
		var obituary := _ability_by_id(stack, "obituary")
		var ability_uses = stack.get("ability_uses", {})
		if ability_uses is Dictionary and int(ability_uses.get("obituary", 0)) >= int(obituary.get("uses_per_battle", 1)):
			return "Final Notice has already been issued this battle."
		if not target.is_empty() and _brace_available(target, battle) and int(target.get("tier", 1)) >= int(obituary.get("braced_target_min_tier", 2)):
			return "Final Notice prioritizes this veteran braced line, sharply draining it and weakening its retaliation for this round."
		return "Final Notice will drain the target's cohesion and weaken its retaliation for this round."
	if _has_ability(stack, "rot_cant") and bool(stack.get("ranged", false)):
		var rot_cant := _ability_by_id(stack, "rot_cant")
		if int(battle.get("round", 1)) < int(rot_cant.get("available_from_round", 1)):
			return "%s is waiting for the midline exchange." % String(rot_cant.get("name", "Rot Cant"))
		var rot_uses = stack.get("ability_uses", {})
		if rot_uses is Dictionary and int(rot_uses.get("rot_cant", 0)) >= int(rot_cant.get("uses_per_battle", 1)):
			return "%s has already been placed this battle." % String(rot_cant.get("name", "Rot Cant"))
		var rot_min_tier := int(rot_cant.get("target_min_tier", 1))
		if target.is_empty() or int(target.get("tier", 1)) < rot_min_tier:
			return "%s is waiting for a tier-%d veteran line." % [String(rot_cant.get("name", "Rot Cant")), rot_min_tier]
		return "%s will rot-call this veteran line and weaken its retaliation for the round." % String(rot_cant.get("name", "Rot Cant"))
	if _has_ability(stack, "harry") and bool(stack.get("ranged", false)):
		var harry := _ability_by_id(stack, "harry")
		var uses_per_battle := int(harry.get("uses_per_battle", 0))
		var ability_uses = stack.get("ability_uses", {})
		if uses_per_battle > 0 and ability_uses is Dictionary and int(ability_uses.get("harry", 0)) >= uses_per_battle:
			return "%s has already been placed this battle." % String(harry.get("name", "Harry"))
		var modifier_text := _ability_modifier_text(harry)
		var pressure_summary := " (%s)" % modifier_text if modifier_text != "" else ""
		var target_min_tier := int(harry.get("target_min_tier", 1))
		if target_min_tier > 1 and (target.is_empty() or int(target.get("tier", 1)) < target_min_tier):
			return "%s is waiting for a tier-%d veteran line." % [String(harry.get("name", "Harry")), target_min_tier]
		var authored_harry := _authored_ability_by_id(stack, "harry")
		var target_shielding := _authored_ability_by_id(target, "shielding")
		if not target_shielding.is_empty() and bool(target_shielding.get("snare_vulnerable", false)) and float(authored_harry.get("shielding_damage_multiplier", 1.0)) > 1.0:
			return "%s will foul this shield screen and mark it%s for later breaks." % [String(harry.get("name", "Harry")), pressure_summary]
		return "%s will mark the target%s for later breaks." % [String(harry.get("name", "Harry")), pressure_summary]
	if _has_ability(stack, "harry") and not bool(stack.get("ranged", false)) and int(_ability_by_id(stack, "harry").get("min_adjacent_allies_to_target", 0)) > 0:
		var supported_harry := _ability_by_id(stack, "harry")
		var supported_harry_uses = stack.get("ability_uses", {})
		if supported_harry_uses is Dictionary and int(supported_harry_uses.get("harry", 0)) >= int(supported_harry.get("uses_per_battle", 0)) and int(supported_harry.get("uses_per_battle", 0)) > 0:
			return "%s has already been placed this battle." % String(supported_harry.get("name", "Harry"))
		var target_min_tier := int(supported_harry.get("target_min_tier", 1))
		if target.is_empty() or int(target.get("tier", 1)) < target_min_tier:
			return "%s is waiting for a tier-%d veteran line." % [String(supported_harry.get("name", "Harry")), target_min_tier]
		var target_role := String(supported_harry.get("target_role", ""))
		if target_role != "" and bool(target.get("ranged", false)) != (target_role == "ranged"):
			return "%s is waiting for a %s veteran line." % [String(supported_harry.get("name", "Harry")), target_role]
		var required_support := int(supported_harry.get("min_adjacent_allies_to_target", 0))
		if not _harry_support_ready(stack, target, battle, supported_harry):
			var authored_blocked_summary := String(supported_harry.get("support_blocked_summary", ""))
			if authored_blocked_summary != "":
				return authored_blocked_summary
			return "%s needs %d allied stack%s on the target's far lane before the snare closes." % [
				String(supported_harry.get("name", "Harry")),
				required_support,
				"" if required_support == 1 else "s",
			]
		var authored_ready_summary := String(supported_harry.get("support_ready_summary", ""))
		if authored_ready_summary != "":
			return authored_ready_summary
		return "%s will close the supported snare and mark this target for the pack." % String(supported_harry.get("name", "Harry"))
	if _brace_available(stack, battle) and int(stack.get("retaliations_left", 0)) > 0:
		return "Brace can stagger the next attacker if this stack holds."
	if _has_ability(stack, "formation_guard"):
		return "Formation Guard is live if this stack steadies the line and keeps allies covered."
	if _has_ability(stack, "solar_array_lane"):
		var array_lane := _ability_by_id(stack, "solar_array_lane")
		if _side_has_linked_unit(battle, String(stack.get("side", "")), array_lane.get("linked_unit_ids", [])):
			return "Solar Array Lanes are screening allied Sunvault firing lines from melee pressure while the linked Daybreak Colossus survives."
		return "Solar Array Lanes are waiting for their linked Daybreak Colossus."
	if _has_ability(stack, "sporeglass_mend") and bool(stack.get("ranged", false)):
		return "Mending Fire will repair an injured surviving allied stack after this shot; fallen creatures cannot return."
	if _has_ability(stack, "pressure_artillery") and bool(stack.get("ranged", false)):
		var pressure_artillery := _ability_by_id(stack, "pressure_artillery")
		var clustered_target := _pressure_artillery_secondary_target(battle, stack, target)
		var cluster_text := " and throw fragments into %s" % _stack_label(clustered_target) if not clustered_target.is_empty() else ""
		return "%s will fire%s, then run overheated until its pressure cycle recovers." % [
			String(pressure_artillery.get("name", "Pressure Artillery")),
			cluster_text,
		]
	if _has_ability(stack, "counter_ambush_flare"):
		return "Counter-Ambush Flare is exposing backstab and fogwake lanes and will flare-reveal a denied fogwake ambusher while this Sapper stack survives."
	if _has_ability(stack, "foundry_aura"):
		return "Saint's Temper is hardening overheated Combine machinery and will repair surviving allies when the next round begins."
	if _has_ability(stack, "overheat"):
		if SpellRulesScript.has_effect_id(stack, battle, STATUS_OVERHEATED):
			return "The Debt Furnace is overheated; damage, defense, and initiative stay reduced until pressure recovers."
		return "The Debt Furnace is pressure-ready and will burst on the next primary strike before overheating."
	if not target.is_empty() and _has_ability(stack, "backstab") and not _counter_ambush_flare_context(battle, target, "backstab").is_empty() and (
		SpellRulesScript.has_any_effect_ids(target, battle, _ability_by_id(stack, "backstab").get("status_ids", []))
		or _health_ratio(target) <= float(_ability_by_id(stack, "backstab").get("health_threshold_ratio", 0.0))
	):
		return "Counter-Ambush Flare exposes this backstab lane; the base attack remains, but its ambush bonus is removed."
	if not target.is_empty() and _has_ability(stack, "fogwake") and _stack_is_hex_isolated(battle, target) and not _counter_ambush_flare_context(battle, target, "fogwake").is_empty():
		return "Counter-Ambush Flare exposes this fogwake lane; bonus damage and Fogbound are blocked."
	if not target.is_empty() and _has_ability(stack, "backstab") and (
		SpellRulesScript.has_any_effect_ids(target, battle, _ability_by_id(stack, "backstab").get("status_ids", []))
		or _health_ratio(target) <= float(_ability_by_id(stack, "backstab").get("health_threshold_ratio", 0.0))
	):
		return "Backstab is live on the marked target right now."
	if not target.is_empty() and _has_ability(stack, "bloodrush"):
		var bloodrush := _ability_by_id(stack, "bloodrush")
		if _health_ratio(target) <= float(bloodrush.get("wounded_threshold_ratio", 0.0)) \
				or SpellRulesScript.has_any_effect_ids(target, battle, bloodrush.get("status_ids", [])) \
				or (float(bloodrush.get("isolated_damage_multiplier", 1.0)) > 1.0 and _stack_is_hex_isolated(battle, target)):
			return "Bloodrush is live through the prepared breach and can snowball momentum."
		if float(bloodrush.get("clean_target_damage_multiplier", 1.0)) < 1.0:
			if float(bloodrush.get("isolated_damage_multiplier", 1.0)) > 1.0:
				return "Bloodrush needs wounded, disrupted, or isolated prey; a clean primary attack loses force."
			return "Bloodrush needs a wounded or disrupted breach; a clean primary attack loses force."
	if not target.is_empty() and _has_ability(stack, "shielding") and SpellRulesScript.has_any_effect_ids(target, battle, _ability_by_id(stack, "shielding").get("payoff_status_ids", [STATUS_HARRIED])):
		return "Shielding bites harder into a marked target once the line closes."
	if not target.is_empty() and _has_ability(stack, "fogwake") and _stack_is_hex_isolated(battle, target):
		return "Leviathan Fogwake is live because the target has no adjacent allied stack."
	var ability_summary = _stack_ability_summary(stack)
	return "Abilities in hand: %s." % ability_summary if ability_summary != "" else ""

static func _active_ability_role_line(stack: Dictionary, battle: Dictionary, target: Dictionary) -> String:
	if stack.is_empty():
		return "No active ability role."
	var role_lines := []
	var fog_screen := _fog_screen_ability(stack)
	if not fog_screen.is_empty():
		var fog_state := "reduces incoming damage in a natural fog bank" if _fog_screen_available(stack, battle, fog_screen) else "waits for a natural fog bank before reducing incoming damage"
		role_lines.append("%s %s" % [String(fog_screen.get("name", "Fog Screen")), fog_state])
	var readiness_writ := _readiness_writ_ability(stack)
	if not readiness_writ.is_empty():
		role_lines.append("%s steadies one disrupted allied veteran reactively, after ranged fire, or from one held response" % String(readiness_writ.get("name", "Readiness Writ")))
	for ability in stack.get("abilities", []):
		if not (ability is Dictionary):
			continue
		var line := _ability_role_sentence(stack, ability, battle, target)
		if line != "":
			role_lines.append(line)
		if role_lines.size() >= 2:
			break
	if role_lines.is_empty():
		return "Role: base %s pressure; no special ability is shaping this order." % String(stack.get("role", "combat"))
	return "Role: %s" % "; ".join(role_lines)

static func _ability_role_sentence(stack: Dictionary, ability: Dictionary, battle: Dictionary, target: Dictionary) -> String:
	var ability_id := String(ability.get("id", ""))
	var name := String(ability.get("name", ability_id.capitalize()))
	var status_label := String(ability.get("status_label", "status"))
	var modifier_text := _ability_modifier_text(ability)
	var target_is_marked := false
	if not target.is_empty():
		target_is_marked = SpellRulesScript.has_any_effect_ids(target, battle, ability.get("status_ids", []))
	match ability_id:
		"reach":
			if not ability.get("held_objective_types", []).is_empty():
				return "%s extends melee threat across a half-open lane only while this side controls a listed field objective" % name
			if not target.is_empty() and _stack_hex_distance(stack, target) <= 2:
				return "%s keeps melee live from the half-open lane" % name
			return "%s extends melee threat before full contact" % name
		"hookline":
			return "%s makes one reduced-damage strike across a broken lane and applies %s%s" % [
				name,
				status_label,
				" (%s)" % modifier_text if modifier_text != "" else "",
			]
		"rot_cant":
			return "%s applies %s%s once per battle against tier-%d veteran lines and amplifies wounded-target pressure" % [
				name,
				status_label,
				" (%s)" % modifier_text if modifier_text != "" else "",
				int(ability.get("target_min_tier", 1)),
			]
		"harry":
			var required_support := int(ability.get("min_adjacent_allies_to_target", 0))
			if required_support > 0:
				return "%s applies %s%s only while %d allied stack%s also surrounds the target" % [
					name,
					status_label,
					" (%s)" % modifier_text if modifier_text != "" else "",
					required_support,
					"" if required_support == 1 else "s",
				]
			return "%s applies %s%s%s%s for follow-up pressure" % [
				name,
				status_label,
				" (%s)" % modifier_text if modifier_text != "" else "",
				" once per battle" if int(ability.get("uses_per_battle", 0)) == 1 else "",
				" against tier-%d veteran lines" % int(ability.get("target_min_tier", 1)) if int(ability.get("target_min_tier", 1)) > 1 else "",
			]
		"obituary":
			return "%s applies %s%s once per battle to drain cohesion and weaken retaliation, prioritizing tier-%d-or-higher braced lines for stronger pressure" % [
				name,
				status_label,
				" (%s)" % modifier_text if modifier_text != "" else "",
				int(ability.get("braced_target_min_tier", 2)),
			]
		"brace":
			if float(ability.get("held_objective_retaliation_multiplier", 1.0)) > 1.0:
				return "%s steadies a defended line, applies %s%s on retaliation, and answers harder while this side controls a listed field objective" % [
					name,
					status_label,
					" (%s)" % modifier_text if modifier_text != "" else "",
				]
			return "%s turns a defended retaliation into %s%s" % [
				name,
				status_label,
				" (%s)" % modifier_text if modifier_text != "" else "",
			]
		"formation_guard":
			return "%s steadies allied lanes and improves support fire" % name
		"resonance_relay":
			return "%s synchronizes two or more separately calibrated allied stacks while this choir remains in the battle" % name
		"solar_array_lane":
			return "%s screens allied Sunvault ranged stacks against %d%% of incoming melee damage while the linked Daybreak Colossus survives" % [
				name,
				int(round((1.0 - float(ability.get("incoming_melee_damage_multiplier", 1.0))) * 100.0)),
			]
		"sporeglass_mend":
			return "%s restores up to %d surviving allied health after ranged fire" % [
				name,
				int(ability.get("max_health_per_attack", 0)),
			]
		"pressure_artillery":
			return "%s deals up to %d damage to one enemy adjacent to the primary target, then applies %s for %d rounds" % [
				name,
				int(ability.get("max_secondary_damage", 0)),
				String(ability.get("status_label", "Overheated")),
				int(ability.get("duration_rounds", 1)),
			]
		"counter_ambush_flare":
			return "%s removes bonus damage from backstab and fogwake attacks, prevents Fogbound, and flare-reveals a denied fogwake ambusher for one round while this stack survives" % name
		"foundry_aura":
			return "%s hardens overheated Combine machinery and repairs surviving allies each round" % name
		"volley":
			if bool(ability.get("requires_protected_lane", false)):
				return "%s delivers heavy ranged pressure only behind a defending allied screen or controlled firing lane" % name
			return "%s rewards an open firing lane%s" % [
				name,
				" into marked targets" if target_is_marked else "",
			]
		"backstab":
			return "%s punishes marked or wounded targets%s" % [
				name,
				" now" if target_is_marked or (not target.is_empty() and _health_ratio(target) <= float(ability.get("health_threshold_ratio", 0.0))) else "",
			]
		"fogwake":
			return "%s strikes harder and applies %s%s when the target has no adjacent allied stack%s" % [
				name,
				status_label,
				" (%s)" % modifier_text if modifier_text != "" else "",
				" now" if not target.is_empty() and _stack_is_hex_isolated(battle, target) else "",
			]
		"bloodrush":
			var clean_penalty_pct := int(round((1.0 - float(ability.get("clean_target_damage_multiplier", 1.0))) * 100.0))
			var isolated_payoff := float(ability.get("isolated_damage_multiplier", 1.0)) > 1.0
			var target_is_isolated := isolated_payoff and not target.is_empty() and _stack_is_hex_isolated(battle, target)
			var target_is_prepared := target_is_marked or target_is_isolated or (not target.is_empty() and _health_ratio(target) <= float(ability.get("wounded_threshold_ratio", 0.0)))
			return "%s hits harder through wounded or disrupted lines%s%s%s" % [
				name,
				" or against isolated prey" if isolated_payoff else "",
				" now" if target_is_prepared else "",
				"; clean primary attacks lose %d%% damage" % clean_penalty_pct if clean_penalty_pct > 0 else "",
			]
		"overheat":
			if SpellRulesScript.has_effect_id(stack, battle, STATUS_OVERHEATED):
				return "%s is cooling under reduced damage, defense, and initiative" % name
			return "%s is pressure-ready for one burst strike before overheating" % name
		"shielding":
			var ranged_reduction_pct := int(round((1.0 - float(ability.get("ranged_damage_multiplier", 1.0))) * 100.0))
			var ranged_return_pct := int(round(float(ability.get("ranged_damage_return_ratio", 0.0)) * 100.0))
			var authored_shielding := _authored_ability_by_id(stack, "shielding")
			var linked_screen_pct := int(authored_shielding.get("linked_ranged_damage_reduction_pct", 0))
			if ranged_return_pct > 0:
				if linked_screen_pct > 0:
					return "%s blunts %d%% of incoming ranged damage, returns %d%% of damage received, and screens linked ranged arrays by %d%% while this stack survives" % [
						name,
						ranged_reduction_pct,
						ranged_return_pct,
						linked_screen_pct,
					]
				return "%s blunts %d%% of incoming ranged damage and returns %d%% of damage received while this stack survives" % [
					name,
					ranged_reduction_pct,
					ranged_return_pct,
				]
			var committed_screen_pct := int(authored_shielding.get("committed_assault_screen_reduction_pct", 0))
			if committed_screen_pct > 0:
				return "%s blunts missiles and screens allied ranged relays by %d%% against committed assaults" % [name, committed_screen_pct]
			if int(ability.get("ally_ranged_melee_damage_reduction_pct", 0)) > 0 or int(ability.get("linebreaker_screen_bonus_pct", 0)) > 0:
				return "%s blunts missiles and screens allied engines from frontal pressure" % name
			if float(ability.get("harried_damage_multiplier", 1.0)) > 1.0:
				return "%s blunts %d%% of incoming ranged damage and strikes harder into marked targets" % [name, ranged_reduction_pct]
			return "%s blunts missile pressure and helps the line hold" % name
	if String(ability.get("description", "")) != "":
		return "%s: %s" % [name, String(ability.get("description", ""))]
	return name

static func _ability_modifier_text(ability: Dictionary) -> String:
	var modifiers = ability.get("modifiers", {})
	if not (modifiers is Dictionary):
		return ""
	var parts := []
	for key in ["attack", "defense", "initiative", "cohesion", "momentum"]:
		if not modifiers.has(key):
			continue
		var amount := int(modifiers.get(key, 0))
		if amount == 0:
			continue
		parts.append("%s %s%d" % [
			_status_modifier_label(key),
			"+" if amount > 0 else "",
			amount,
		])
	return ", ".join(parts)

static func _status_modifier_label(key: String) -> String:
	match key:
		"attack":
			return "Atk"
		"defense":
			return "Def"
		"initiative":
			return "Init"
		"cohesion":
			return "Coh"
		"momentum":
			return "Mom"
	return key.capitalize()

static func _stack_status_pressure_line(stack: Dictionary, battle: Dictionary) -> String:
	if stack.is_empty():
		return "Status pressure: no stack selected."
	var effects := SpellRulesScript.active_effects_for_round(stack, int(battle.get("round", 1)))
	var parts := []
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var rounds_left := int(effect.get("expires_after_round", int(battle.get("round", 1)))) - int(battle.get("round", 1)) + 1
		var modifier_text := _effect_modifier_text(effect)
		parts.append("%s %dr%s" % [
			String(effect.get("label", effect.get("kind", "Status"))),
			max(1, rounds_left),
			" (%s)" % modifier_text if modifier_text != "" else "",
		])
	if not parts.is_empty():
		return "Status pressure: %s." % "; ".join(parts)
	var pressure_bits := [
		"Coh %d" % _stack_cohesion_total(stack, battle),
		"Mom %d" % _stack_momentum_total(stack, battle),
	]
	if bool(stack.get("defending", false)):
		pressure_bits.append("Defending")
	if _stack_is_isolated(battle, stack):
		pressure_bits.append("Isolated")
	return "Status pressure: clear; %s." % ", ".join(pressure_bits)

static func _stack_status_pressure_short(stack: Dictionary, battle: Dictionary) -> String:
	var line := _stack_status_pressure_line(stack, battle)
	return line.trim_prefix("Status pressure: ").trim_suffix(".")

static func _effect_modifier_text(effect: Dictionary) -> String:
	var modifiers = effect.get("modifiers", {})
	if not (modifiers is Dictionary):
		return ""
	var parts := []
	for key in ["attack", "defense", "initiative", "cohesion", "momentum"]:
		if not modifiers.has(key):
			continue
		var amount := int(modifiers.get(key, 0))
		if amount == 0:
			continue
		parts.append("%s %s%d" % [
			_status_modifier_label(key),
			"+" if amount > 0 else "",
			amount,
		])
	return ", ".join(parts)

static func _target_range_readiness_line(active_stack: Dictionary, target: Dictionary, battle: Dictionary) -> String:
	if active_stack.is_empty():
		return "Target/range: no active stack."
	if target.is_empty():
		return "Target/range: select an enemy stack; %s." % _distance_label(int(battle.get("distance", 1))).to_lower()
	var legality := _attack_legality_for_target(active_stack, target, battle)
	var readiness := "ready" if bool(legality.get("attackable", false)) else "blocked"
	var options := []
	if bool(legality.get("melee", false)):
		options.append("Strike")
	if bool(legality.get("ranged", false)):
		options.append("Shoot")
	if options.is_empty():
		options.append("move first")
	return "Target/range: %s is %s at hex range %d; %s." % [
		_stack_label(target),
		readiness,
		int(legality.get("hex_distance", -1)),
		" or ".join(options),
	]

static func _field_objective_action_preview(battle: Dictionary, action_context: Dictionary) -> String:
	var acting_side = String(action_context.get("side", ""))
	if acting_side not in ["player", "enemy"]:
		return ""
	var acting_stack = _get_stack_by_id(battle, String(action_context.get("battle_id", "")))
	var target_stack = _get_stack_by_id(battle, String(action_context.get("target_battle_id", "")))
	var notes = []
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var influence = _field_objective_action_influence(objective, battle, acting_side, action_context, acting_stack, target_stack)
		if influence <= 0:
			continue
		var projection = _project_field_objective_state(objective, acting_side, influence)
		var label = _field_objective_label(objective)
		if bool(projection.get("flipped", false)):
			notes.append("%s would swing to %s control" % [label, _side_label(acting_side)])
			continue
		if String(objective.get("control_side", "neutral")) == acting_side:
			notes.append("%s hold strengthens" % label)
			continue
		var progress_side = String(projection.get("progress_side", ""))
		var progress_value = int(projection.get("progress_value", 0))
		var threshold = int(projection.get("capture_threshold", objective.get("capture_threshold", 2)))
		if progress_side == acting_side and progress_value > 0:
			notes.append("%s moves to %d/%d toward %s control" % [label, progress_value, threshold, _side_label(acting_side)])
		if notes.size() >= 2:
			break
	return "; ".join(notes)

static func _project_field_objective_state(objective: Dictionary, acting_side: String, amount: int) -> Dictionary:
	var projection = objective.duplicate(true)
	var controller = String(projection.get("control_side", "neutral"))
	var progress_side = String(projection.get("progress_side", ""))
	var progress_value = max(0, int(projection.get("progress_value", 0)))
	var threshold = max(1, int(projection.get("capture_threshold", 2)))
	var flipped = false
	if controller == acting_side:
		if progress_side != "" and progress_side != acting_side:
			progress_value = max(0, progress_value - amount)
			if progress_value <= 0:
				progress_side = ""
	else:
		if progress_side != "" and progress_side != acting_side:
			progress_value = max(0, progress_value - amount)
			if progress_value <= 0:
				progress_side = acting_side
				progress_value = amount
		else:
			progress_side = acting_side
			progress_value += amount
		if progress_value >= threshold:
			controller = acting_side
			progress_side = ""
			progress_value = 0
			flipped = true
	projection["control_side"] = controller
	projection["progress_side"] = progress_side
	projection["progress_value"] = progress_value if progress_side != "" else 0
	projection["capture_threshold"] = threshold
	projection["flipped"] = flipped
	return projection

static func _should_surface_tactical_briefing(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or session.battle.is_empty():
		return false
	if session.scenario_status != "in_progress":
		return false
	if int(session.battle.get("round", 1)) != 1:
		return false
	var briefing_state = session.battle.get(TACTICAL_BRIEFING_KEY, {})
	return briefing_state is Dictionary and not bool(briefing_state.get("shown", false))

static func _tactical_briefing_lines(session: SessionStateStoreScript.SessionData) -> Array:
	var battle = session.battle
	var scenario = ContentService.get_scenario_readonly(session.scenario_id)
	var lines = []
	var battlefield_line = _tactical_battlefield_line(session, battle)
	if battlefield_line != "":
		lines.append(battlefield_line)
	var objective_line = _tactical_objective_line(session, battle, scenario)
	if objective_line != "":
		lines.append(objective_line)
	var field_objective_line = _tactical_field_objective_line(battle)
	if field_objective_line != "":
		lines.append(field_objective_line)
	var doctrine_line = _tactical_enemy_doctrine_line(battle)
	if doctrine_line != "":
		lines.append(doctrine_line)
	var pressure_line = _tactical_opening_pressure_line(session, battle)
	if pressure_line != "":
		lines.append(pressure_line)
	var decisive_line = _tactical_decisive_target_line(battle)
	if decisive_line != "":
		lines.append(decisive_line)
	var caution_line = _tactical_caution_line(session, battle)
	if caution_line != "":
		lines.append(caution_line)
	return lines

static func _tactical_battlefield_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var parts = [
		String(battle.get("terrain", "plains")).capitalize(),
		_distance_label(int(battle.get("distance", 1))),
	]
	var identity_summary = _battlefield_identity_summary(battle)
	if identity_summary != "":
		parts.append(identity_summary)
	var tag_labels = _battlefield_tag_labels(battle)
	if not tag_labels.is_empty():
		parts.append("Tags %s" % ", ".join(tag_labels))
	if _is_town_defense_context(battle.get("context", {})) or _is_town_assault_context(battle.get("context", {})):
		parts.append(_battle_context_label(session, battle.get("context", {})))
	return "Battlefield: %s" % " | ".join(parts)

static func _tactical_objective_line(session: SessionStateStoreScript.SessionData, battle: Dictionary, scenario: Dictionary) -> String:
	if _is_town_defense_context(battle.get("context", {})):
		var town_name = _town_name_from_placement_id(session, String(battle.get("context", {}).get("town_placement_id", "")))
		return "Battle aim: Hold %s. A collapse here loses the town and cedes the lane." % (
			town_name if town_name != "" else "the walls"
		)
	if _is_town_assault_context(battle.get("context", {})):
		var assault_town_name = _town_name_from_placement_id(session, String(battle.get("context", {}).get("town_placement_id", "")))
		return "Battle aim: Take %s. Breaking the garrison opens the town and collapses this hostile anchor." % (
			assault_town_name if assault_town_name != "" else "the walls"
		)
	var encounter_objective = _encounter_objective_for_battle(session, battle, scenario)
	if not encounter_objective.is_empty():
		return "Battle aim: %s" % ScenarioRulesScript._objective_label(session, encounter_objective)
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		var victory_labels = ScenarioRulesScript._objective_labels_from_bucket(session, objectives.get("victory", []), 1)
		if not victory_labels.is_empty():
			return "Battle aim: %s" % String(victory_labels[0])
	return ""

static func _tactical_field_objective_line(battle: Dictionary) -> String:
	var objective_summary = _field_objective_pressure_summary(battle)
	return "Battlefield objective: %s" % objective_summary if objective_summary != "" else ""

static func _tactical_enemy_doctrine_line(battle: Dictionary) -> String:
	var commander_state = _commander_state_for_side(battle, "enemy")
	var doctrine = _side_doctrine_summary(battle, "enemy")
	var commander_name = String(commander_state.get("name", "Enemy command"))
	var trait_labels = _battle_trait_labels(_normalized_battle_traits(commander_state))
	var parts = ["%s | %s" % [commander_name, doctrine]]
	if not trait_labels.is_empty():
		parts.append("Traits %s" % ", ".join(trait_labels))
	return "Enemy doctrine: %s" % " | ".join(parts)

static func _tactical_opening_pressure_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	return "Opening pressure: %s | Friendly ranged %d | Enemy ranged %d | Retreat %s" % [
		_pressure_brief(session),
		int(player_totals.get("ranged_stacks", 0)),
		int(enemy_totals.get("ranged_stacks", 0)),
		_withdrawal_pressure_label(battle, _battle_retreat_allowed(battle)),
	]

static func _tactical_decisive_target_line(battle: Dictionary) -> String:
	var target = _priority_enemy_stack_for_briefing(battle)
	if target.is_empty():
		return ""
	return "Decisive target: %s | %s" % [
		_stack_label(target),
		_priority_target_reason(target, battle),
	]

static func _tactical_caution_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	if _battle_has_tag(battle, "battery_nest") and int(battle.get("distance", 1)) > 0:
		return "Tactical caution: The approach stays exposed while battery lanes are open; trade shots only if you can win the ranged exchange."
	if _side_controls_field_objective_type(battle, "enemy", "cover_line") and int(battle.get("distance", 1)) > 0:
		return "Tactical caution: Enemy cover still screens the firing line and commander; dislodge it before settling into a long volley."
	if _side_controls_field_objective_type(battle, "enemy", "obstruction_line") and int(battle.get("distance", 1)) > 0:
		return "Tactical caution: The obstruction line can still hold weaker advances. Lead with the toughest breach stack."
	if _battle_has_tag(battle, "fortress_lane"):
		return "Tactical caution: Fortress lanes compress melee into a kill zone. Brace anchors before committing the full assault."
	if _battle_has_tag(battle, "wall_pressure") and int(battle.get("round", 1)) <= 2:
		return "Tactical caution: Delay the breach now and the enemy's late melee pressure will spike after round three."
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	if int(enemy_totals.get("ranged_stacks", 0)) > int(player_totals.get("ranged_stacks", 0)) and int(battle.get("distance", 1)) > 0:
		return "Tactical caution: Enemy shooting outranges your opening line; close distance with the toughest stacks first."
	if int(player_totals.get("ranged_stacks", 0)) > int(enemy_totals.get("ranged_stacks", 0)) and int(battle.get("distance", 1)) > 0:
		return "Tactical edge: You own the cleaner firing line. Spend the opening volleys before the lines fully engage."
	if _is_town_defense_context(battle.get("context", {})):
		return "Tactical caution: Retreat is locked on the walls. Preserve disciplined defenders and trade for position, not speed."
	if _is_town_assault_context(battle.get("context", {})):
		return "Tactical caution: If the breach stalls, the town stays hostile. Keep pressure on the wall lane and decisive stacks."
	return ""

static func _risk_readiness_grade(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var severity = 0
	var stability = 0
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	var player_health = int(player_totals.get("health", 0))
	var enemy_health = int(enemy_totals.get("health", 0))
	var player_wavering = _wavering_stack_count(battle, "player")
	var enemy_wavering = _wavering_stack_count(battle, "enemy")
	var player_steady = _steady_stack_count(battle, "player")
	var next_window = _next_activation_window(battle, 3)
	var player_next = 0
	var enemy_next = 0
	for stack in next_window:
		if String(stack.get("side", "")) == "player":
			player_next += 1
		else:
			enemy_next += 1
	if enemy_next >= 2 and enemy_next > player_next:
		severity += 2
	elif player_next >= 2 and player_next > enemy_next:
		stability += 2
	if player_wavering >= 2:
		severity += 2
	elif player_wavering == 1:
		severity += 1
	if enemy_wavering >= 2:
		stability += 2
	elif enemy_wavering == 1:
		stability += 1
	if player_steady <= 1:
		severity += 1
	elif player_steady >= 3:
		stability += 1
	if player_health > 0 and enemy_health > int(round(float(player_health) * 1.25)):
		severity += 2
	elif enemy_health > 0 and player_health > int(round(float(enemy_health) * 1.25)):
		stability += 2
	if _average_side_cohesion(battle, "player") >= 7.0:
		stability += 1
	if _average_side_cohesion(battle, "player") <= 5.0:
		severity += 1
	if int(battle.get("distance", 1)) > 0:
		var player_shots = _side_shots_remaining(battle, "player")
		var enemy_shots = _side_shots_remaining(battle, "enemy")
		if enemy_shots > player_shots:
			severity += 1
		elif player_shots > enemy_shots:
			stability += 1
	if not _battle_retreat_allowed(battle):
		severity += 1
	if max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1) <= 2:
		severity += 1
	var category = "Balanced posture."
	if stability >= 5 and severity <= 1:
		category = "Strong stabilization posture."
	elif stability >= 3 and severity <= 2:
		category = "Ready pressure posture."
	elif severity >= 6:
		category = "Collapse risk rising."
	elif severity >= 4:
		category = "Fragile exchange."
	elif severity >= 2:
		category = "Contested posture."
	return "%s %s" % [category, _pressure_brief(session)]

static func _risk_board_initiative_line(battle: Dictionary) -> String:
	var next_window = _next_activation_window(battle, 3)
	if next_window.is_empty():
		return "the turn order is rebuilding after a collapse."
	var player_count = 0
	var enemy_count = 0
	for stack in next_window:
		if String(stack.get("side", "")) == "player":
			player_count += 1
		else:
			enemy_count += 1
	var first_stack = next_window[0]
	var window_size = next_window.size()
	if player_count > enemy_count:
		return "friendly line controls %d of the next %d activations, starting with %s at Init %d." % [
			player_count,
			window_size,
			_stack_label(first_stack),
			_stack_initiative_total(first_stack, battle),
		]
	if enemy_count > player_count:
		return "enemy line controls %d of the next %d activations, starting with %s at Init %d." % [
			enemy_count,
			window_size,
			_stack_label(first_stack),
			_stack_initiative_total(first_stack, battle),
		]
	return "the next %d activations are split evenly, with %s acting first at Init %d." % [
		window_size,
		_stack_label(first_stack),
		_stack_initiative_total(first_stack, battle),
	]

static func _risk_board_commander_line(battle: Dictionary) -> String:
	var commander_state = _commander_state_for_side(battle, "player")
	var commander_payload = _hero_payload_for_side(battle, "player")
	var enemy_payload = _hero_payload_for_side(battle, "enemy")
	var commander_name = String(commander_state.get("name", "Field command"))
	var steady_count = _steady_stack_count(battle, "player")
	var wavering_count = _wavering_stack_count(battle, "player")
	var initiative_edge = int(commander_payload.get("initiative", 0)) - int(enemy_payload.get("initiative", 0))
	var aura_summary = "aura even with enemy command"
	if initiative_edge > 0:
		aura_summary = "aura leads enemy command by %d initiative" % initiative_edge
	elif initiative_edge < 0:
		aura_summary = "aura trails enemy command by %d initiative" % abs(initiative_edge)
	var cover_summary = "line covered"
	var command_screen = 0
	if _side_controls_field_objective_type(battle, "player", "cover_line"):
		command_screen += 2
	if _side_controls_field_objective_type(battle, "player", "signal_beacon"):
		command_screen += 1
	if _side_controls_field_objective_type(battle, "enemy", "cover_line"):
		command_screen -= 1
	if _side_controls_field_objective_type(battle, "enemy", "signal_beacon"):
		command_screen -= 1
	if _side_controls_field_objective_type(battle, "enemy", "obstruction_line") and int(battle.get("distance", 1)) > 0:
		command_screen -= 1
	if command_screen >= 2:
		cover_summary = "command screened"
	elif steady_count <= 1 and wavering_count >= 2:
		cover_summary = "command exposed"
	elif wavering_count > 0:
		cover_summary = "cover contested"
	return "%s | Mana %d/%d | %d steady, %d wavering | %s | %s." % [
		commander_name,
		int(commander_payload.get("mana_current", 0)),
		int(commander_payload.get("mana_max", 0)),
		steady_count,
		wavering_count,
		cover_summary,
		aura_summary,
	]

static func _risk_board_line_integrity_line(battle: Dictionary) -> String:
	var player_wavering = _wavering_stack_count(battle, "player")
	var enemy_wavering = _wavering_stack_count(battle, "enemy")
	var player_average = _average_side_cohesion(battle, "player")
	var enemy_average = _average_side_cohesion(battle, "enemy")
	if player_wavering > 0 and (player_wavering >= enemy_wavering or player_average < enemy_average):
		var weakest_player = _weakest_stack_by_cohesion(battle, "player")
		return "%d friendly stack%s are wavering at low cohesion; %s is the softest point." % [
			player_wavering,
			"" if player_wavering == 1 else "s",
			_stack_label(weakest_player),
		]
	if enemy_wavering > 0:
		var weakest_enemy = _weakest_stack_by_cohesion(battle, "enemy")
		return "%d enemy stack%s are wavering at low cohesion; %s is ready to break." % [
			enemy_wavering,
			"" if enemy_wavering == 1 else "s",
			_stack_label(weakest_enemy),
		]
	if player_average >= 7.0 and _side_defending_count(battle, "player") > 0:
		return "friendly anchors are stabilized at %.1f average cohesion with %d defending stacks." % [
			player_average,
			_side_defending_count(battle, "player"),
		]
	return "average cohesion is %.1f friendly to %.1f enemy, so the line has not cracked yet." % [
		player_average,
		enemy_average,
	]

static func _risk_board_ranged_pressure_line(battle: Dictionary) -> String:
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	var player_ranged = int(player_totals.get("ranged_stacks", 0))
	var enemy_ranged = int(enemy_totals.get("ranged_stacks", 0))
	var player_shots = _side_shots_remaining(battle, "player")
	var enemy_shots = _side_shots_remaining(battle, "enemy")
	var lane_label = _risk_board_lane_label(battle)
	if max(player_ranged, enemy_ranged) <= 0:
		return "no ranged pressure remains; melee tempo will decide the exchange."
	if int(battle.get("distance", 1)) <= 0:
		if enemy_ranged > player_ranged:
			return "%d enemy ranged stack%s still threaten from behind the melee." % [
				enemy_ranged,
				"" if enemy_ranged == 1 else "s",
			]
		if player_ranged > enemy_ranged:
			return "your %d ranged stack%s still have protected rear angles." % [
				player_ranged,
				"" if player_ranged == 1 else "s",
			]
		return "the lines are engaged, so surviving shooters now depend on protected rear lanes."
	if enemy_shots > player_shots:
		var enemy_lane = "covered %s" % lane_label if _side_controls_field_objective_type(battle, "enemy", "cover_line") else lane_label
		return "enemy batteries own the %s with %d stack%s and %d shots remaining." % [
			enemy_lane,
			enemy_ranged,
			"" if enemy_ranged == 1 else "s",
			enemy_shots,
		]
	if player_shots > enemy_shots:
		var player_lane = "covered %s" % lane_label if _side_controls_field_objective_type(battle, "player", "cover_line") else lane_label
		return "friendly batteries own the %s with %d stack%s and %d shots remaining." % [
			player_lane,
			player_ranged,
			"" if player_ranged == 1 else "s",
			player_shots,
		]
	if _side_controls_field_objective_type(battle, "enemy", "obstruction_line"):
		return "enemy obstructions are keeping the %s narrow even on even shots." % lane_label
	if _side_controls_field_objective_type(battle, "player", "obstruction_line"):
		return "friendly hands own the %s choke and can blunt the next enemy volley." % lane_label
	if enemy_ranged > player_ranged:
		return "enemy line holds the deeper firing stack count even on equal shots."
	if player_ranged > enemy_ranged:
		return "friendly line holds the deeper firing stack count if the lane stays open."
	return "ranged pressure is even across the %s." % lane_label

static func _risk_board_priority_line(battle: Dictionary) -> String:
	var decisive_target = _priority_enemy_stack_for_briefing(battle)
	if decisive_target.is_empty():
		return "no decisive target is exposed yet."
	var active_stack = get_active_stack(battle)
	if not active_stack.is_empty() and String(active_stack.get("side", "")) != "player":
		return "%s remains the next break point, but enemy initiative is active and retargeting is locked." % _stack_label(decisive_target)
	var selected_target = get_selected_target(battle)
	if not selected_target.is_empty() and String(selected_target.get("battle_id", "")) == String(decisive_target.get("battle_id", "")):
		return "%s is already marked; %s." % [
			_stack_label(decisive_target),
			_priority_target_reason(decisive_target, battle),
		]
	return "shift focus to %s; %s." % [
		_stack_label(decisive_target),
		_priority_target_reason(decisive_target, battle),
	]

static func _risk_board_objective_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var summary = _field_objective_urgency_summary(session, battle)
	return summary if summary != "" else "break the opposing line before the clock turns."

static func _risk_board_dispatch_line(battle: Dictionary) -> String:
	for event_text in battle.get("recent_events", []):
		var line = String(event_text).strip_edges()
		if line != "":
			return line
	return ""

static func _next_activation_window(battle: Dictionary, count: int) -> Array:
	var window = []
	var turn_order = battle.get("turn_order", [])
	if not (turn_order is Array):
		return window
	for index in range(max(0, int(battle.get("turn_index", 0))), turn_order.size()):
		var stack = _get_stack_by_id(battle, String(turn_order[index]))
		if stack.is_empty() or _alive_count(stack) <= 0:
			continue
		window.append(stack)
		if window.size() >= count:
			break
	return window

static func _steady_stack_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if _stack_cohesion_total(stack, battle) >= 6 and not _stack_is_isolated(battle, stack):
			total += 1
	return total

static func _wavering_stack_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if _stack_cohesion_total(stack, battle) <= 4 or _stack_is_isolated(battle, stack) or SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_STAGGERED, STATUS_HARRIED]):
			total += 1
	return total

static func _average_side_cohesion(battle: Dictionary, side: String) -> float:
	var stacks = _alive_stacks_for_side(battle, side)
	if stacks.is_empty():
		return 0.0
	var total = 0.0
	for stack in stacks:
		total += float(_stack_cohesion_total(stack, battle))
	return total / float(stacks.size())

static func _weakest_stack_by_cohesion(battle: Dictionary, side: String) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._weakest_stack_by_cohesion", [battle, side])

static func _side_shots_remaining(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("ranged", false)):
			total += max(0, int(stack.get("shots_remaining", 0)))
	return total

static func _risk_board_lane_label(battle: Dictionary) -> String:
	if _battle_has_tag(battle, "battery_nest"):
		return "battery lane"
	if _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		return "fire lane"
	return _distance_label(int(battle.get("distance", 1))).to_lower()

static func _battlefield_tag_labels(battle: Dictionary) -> Array:
	var labels = []
	for tag_value in battle.get("battlefield_tags", []):
		var label = _titleize_token(String(tag_value))
		if label != "" and label not in labels:
			labels.append(label)
		if labels.size() >= 4:
			break
	return labels

static func _battle_trait_labels(traits: Array) -> Array:
	var labels = []
	for trait_value in traits:
		var label = _titleize_token(String(trait_value))
		if label != "" and label not in labels:
			labels.append(label)
		if labels.size() >= 3:
			break
	return labels

static func _encounter_objective_for_battle(session: SessionStateStoreScript.SessionData, battle: Dictionary, scenario: Dictionary) -> Dictionary:
	if scenario.is_empty():
		return {}
	var encounter_placement = _current_battle_encounter_placement(session)
	var placement_id = String(encounter_placement.get("placement_id", battle.get("resolved_key", "")))
	if placement_id == "":
		return {}
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return {}
	for bucket_name in ["victory", "defeat"]:
		for objective in objectives.get(bucket_name, []):
			if objective is Dictionary and String(objective.get("type", "")) == "encounter_resolved" and String(objective.get("placement_id", "")) == placement_id:
				return objective
	return {}

static func _current_battle_encounter_placement(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules._current_battle_encounter_placement", [session])

static func _priority_enemy_stack_for_briefing(battle: Dictionary) -> Dictionary:
	var best = {}
	var best_score = -99999
	for stack in _alive_stacks_for_side(battle, "enemy"):
		var score = 0
		if bool(stack.get("ranged", false)):
			score += 5 if _battle_has_any_tags(battle, ["battery_nest", "elevated_fire", "open_lane"]) else 3
			if _side_controls_field_objective_type(battle, "enemy", "cover_line"):
				score += 2
		else:
			score += 4 if _battle_has_any_tags(battle, ["fortress_lane", "wall_pressure", "chokepoint"]) else 2
			if _side_controls_field_objective_type(battle, "enemy", "obstruction_line") and (
				_has_ability(stack, "formation_guard")
				or _brace_available(stack, battle)
				or _reach_available(stack, battle)
				or bool(stack.get("defending", false))
			):
				score += 2
		if _side_controls_field_objective_type(battle, "enemy", "cover_line") and _stack_is_cover_screened(stack, battle):
			score += 1
		if _has_ability(stack, "formation_guard") or _brace_available(stack, battle) or _reach_available(stack, battle):
			score += 2
		if _has_ability(stack, "bloodrush") or _has_ability(stack, "backstab") or _has_ability(stack, "harry"):
			score += 2
		score += int(round(float(int(stack.get("total_health", 0))) / 18.0))
		score += int(round(float(_stack_initiative_total(stack, battle)) / 3.0))
		if best.is_empty() or score > best_score:
			best = stack
			best_score = score
	return best

static func _priority_target_reason(stack: Dictionary, battle: Dictionary) -> String:
	if bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["battery_nest", "elevated_fire", "open_lane"]):
		return "its ranged line controls the opening approach"
	if bool(stack.get("ranged", false)) and _side_controls_field_objective_type(battle, String(stack.get("side", "")), "cover_line"):
		return "it is firing from a screened cover line"
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "cover_line") and _stack_is_cover_screened(stack, battle):
		return "it is part of the screen keeping the hostile firing line protected"
	if bool(stack.get("ranged", false)):
		return "it is the sharpest ranged threat on the field"
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line") and (_has_ability(stack, "formation_guard") or _brace_available(stack, battle) or _reach_available(stack, battle)):
		return "it is locking the obstruction line and taxing the approach"
	if _battle_has_any_tags(battle, ["fortress_lane", "wall_pressure", "chokepoint"]) and (_has_ability(stack, "formation_guard") or _brace_available(stack, battle) or _reach_available(stack, battle)):
		return "it anchors the tightest lane in the melee"
	if _has_ability(stack, "bloodrush") or _has_ability(stack, "backstab") or _has_ability(stack, "harry"):
		return "it can snowball fast once the line starts cracking"
	if _stack_initiative_total(stack, battle) >= 10:
		return "it will act early and pressure the first exchange"
	return "breaking it will soften the enemy line before reserves matter"

static func get_action_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var surface = {}
	if session == null or session.battle.is_empty():
		return surface
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var target = get_selected_target(battle)
	var availability = action_availability(battle)
	var player_turn = not active_stack.is_empty() and String(active_stack.get("side", "")) == "player"
	var locked_summary := _player_input_locked_summary()
	var advance_summary = locked_summary
	if player_turn:
		advance_summary = _advance_action_summary(battle, active_stack) if bool(availability.get("advance", false)) else "The lines are already engaged."
	surface["advance"] = {
		"label": "Advance",
		"disabled": not player_turn or not bool(availability.get("advance", false)),
		"summary": advance_summary,
	}
	_enrich_action_surface_entry(surface["advance"], "advance", session, battle, active_stack, target, availability)
	var strike_summary = locked_summary
	if player_turn:
		strike_summary = _attack_action_summary(active_stack, target, battle, false) if bool(availability.get("strike", false)) else _attack_unavailable_summary(active_stack, target, battle, false)
	surface["strike"] = {
		"label": "Strike",
		"disabled": not player_turn or not bool(availability.get("strike", false)),
		"summary": strike_summary,
	}
	_enrich_action_surface_entry(surface["strike"], "strike", session, battle, active_stack, target, availability)
	var shoot_summary = locked_summary
	if player_turn:
		shoot_summary = _attack_action_summary(active_stack, target, battle, true) if bool(availability.get("shoot", false)) else _attack_unavailable_summary(active_stack, target, battle, true)
	surface["shoot"] = {
		"label": "Shoot",
		"disabled": not player_turn or not bool(availability.get("shoot", false)),
		"summary": shoot_summary,
	}
	_enrich_action_surface_entry(surface["shoot"], "shoot", session, battle, active_stack, target, availability)
	surface["defend"] = {
		"label": "Defend",
		"disabled": not player_turn or not bool(availability.get("defend", false)),
		"summary": locked_summary if not player_turn else _defend_action_summary(battle, active_stack),
	}
	_enrich_action_surface_entry(surface["defend"], "defend", session, battle, active_stack, target, availability)
	surface["wait"] = {
		"label": "Wait",
		"disabled": not player_turn or not bool(availability.get("wait", false)),
		"summary": locked_summary if not player_turn else _wait_action_summary(battle, active_stack),
	}
	_enrich_action_surface_entry(surface["wait"], "wait", session, battle, active_stack, target, availability)
	var retreat_summary = locked_summary
	if player_turn:
		retreat_summary = _retreat_action_summary(session)
	surface["retreat"] = {
		"label": "Retreat",
		"disabled": not player_turn or not bool(availability.get("retreat", false)),
		"summary": retreat_summary,
	}
	_enrich_action_surface_entry(surface["retreat"], "retreat", session, battle, active_stack, target, availability)
	var surrender_summary = locked_summary
	if player_turn:
		surrender_summary = _surrender_action_summary(session)
	surface["surrender"] = {
		"label": "Surrender",
		"disabled": not player_turn or not bool(availability.get("surrender", false)),
		"summary": surrender_summary,
	}
	_enrich_action_surface_entry(surface["surrender"], "surrender", session, battle, active_stack, target, availability)
	return surface

static func _enrich_action_surface_entry(
	action: Dictionary,
	action_id: String,
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary,
	availability: Dictionary
) -> void:
	var ready := String(active_stack.get("side", "")) == "player" and bool(availability.get(action_id, false))
	action["readiness"] = "Ready" if ready else "Blocked"
	action["target"] = _action_target_label(action_id, active_stack, target, battle)
	action["range"] = _action_range_line(action_id, active_stack, target, battle)
	action["why"] = _action_why_line(action_id, session, battle, active_stack, target, ready)
	action["consequence"] = _action_consequence_line(action_id, session, battle, active_stack, target, action)
	action["confirmation"] = _action_confirmation_line(action_id, active_stack, target, action)
	action["tooltip"] = _compact_action_tooltip(action)

static func _compact_action_tooltip(action: Dictionary) -> String:
	var lines = [
		"%s | %s" % [String(action.get("label", "Order")), String(action.get("readiness", ""))],
		String(action.get("summary", "")),
		"Target/range: %s | %s" % [String(action.get("target", "")), String(action.get("range", ""))],
		"Why: %s" % String(action.get("why", "")),
		"Consequence: %s" % String(action.get("consequence", "")),
		"Confirm: %s" % String(action.get("confirmation", "")),
	]
	var compact := []
	for line_value in lines:
		var line := String(line_value).strip_edges()
		if line != "":
			compact.append(line)
	return "\n".join(compact)

static func _action_confirmation_line(
	action_id: String,
	active_stack: Dictionary,
	target: Dictionary,
	action: Dictionary
) -> String:
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return "input is locked until command returns."
	var label := String(action.get("label", action_id.capitalize()))
	if bool(action.get("disabled", false)):
		return "%s is not ready from this posture; retarget or change range first." % label
	match action_id:
		"strike", "shoot":
			var target_label := _stack_label(target) if not target.is_empty() else "the selected target"
			return "%s %s; this stack spends its action and initiative advances." % [label, target_label]
		"advance":
			return "move this stack on the tactical grid; initiative advances after the move resolves."
		"defend":
			return "brace in place until this stack's next turn; initiative advances."
		"wait":
			return "step out of the order; this stack acts after every stack that has not waited, slowest first."
		"retreat":
			return "leave the field and route back through the battle outcome."
		"surrender":
			return "concede the field under surrender terms."
	return "confirm this order; initiative advances after it resolves."

static func _action_target_label(action_id: String, active_stack: Dictionary, target: Dictionary, battle: Dictionary) -> String:
	match action_id:
		"strike", "shoot":
			return _stack_label(target) if not target.is_empty() else "Select an enemy"
		"advance":
			if not target.is_empty():
				return "Close toward %s" % _stack_label(target)
			return "Nearest lane"
		"defend", "wait":
			return _stack_label(active_stack) if not active_stack.is_empty() else "Active stack"
		"retreat", "surrender":
			return "Whole army"
	return "Battle line"

static func _action_range_line(action_id: String, active_stack: Dictionary, target: Dictionary, battle: Dictionary) -> String:
	if active_stack.is_empty():
		return "No active stack"
	match action_id:
		"strike":
			if target.is_empty():
				return "Needs target"
			var legality := _attack_legality_for_target(active_stack, target, battle)
			if bool(legality.get("melee", false)):
				return "Melee ready at hex range %d" % int(legality.get("hex_distance", -1))
			if _reach_available(active_stack, battle) or _hookline_available(active_stack, battle):
				return "Chain reach needs hex range 2 or closer"
			return "Needs adjacent contact"
		"shoot":
			if not bool(active_stack.get("ranged", false)):
				return "No ranged attack"
			if target.is_empty():
				return "Needs target"
			var ranged_legality := _attack_legality_for_target(active_stack, target, battle)
			if bool(ranged_legality.get("ranged", false)):
				return "Fire lane ready at %s" % _distance_label(_attack_distance_for_action(active_stack, target, battle, true)).to_lower()
			return "Fire lane blocked"
		"advance":
			var destinations := legal_destinations_for_active_stack(battle)
			if destinations.is_empty() and int(battle.get("distance", 1)) <= 0:
				return "No move lane"
			return "%s | %d move hex%s" % [
				_distance_label(int(battle.get("distance", 1))),
				destinations.size(),
				"" if destinations.size() == 1 else "es",
			]
		"defend", "wait":
			return "Current hex"
		"retreat", "surrender":
			return "Exit order"
	return _distance_label(int(battle.get("distance", 1)))

static func _action_why_line(
	action_id: String,
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary,
	ready: bool
) -> String:
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return _player_input_locked_summary()
	match action_id:
		"strike":
			if target.is_empty():
				return "melee pressure needs a selected enemy."
			if ready:
				var melee_ability := _active_ability_window_summary(active_stack, battle, target)
				return melee_ability if melee_ability != "" else "this trades damage now and can force the next break."
			return _attack_unavailable_summary(active_stack, target, battle, false)
		"shoot":
			if target.is_empty():
				return "ranged pressure needs a selected enemy."
			if ready:
				var ranged_ability := _active_ability_window_summary(active_stack, battle, target)
				return ranged_ability if ranged_ability != "" else "this spends a shot to soften the target before melee closes."
			return _attack_unavailable_summary(active_stack, target, battle, true)
		"advance":
			if ready:
				if not target.is_empty() and bool(_attack_legality_for_target(active_stack, target, battle).get("blocked", false)):
					return "movement turns the selected target from blocked into reachable pressure."
				return "closing changes range, threatens contact, and can pull objectives."
			return "the line is already engaged or no legal movement hex is open."
		"defend":
			return _active_ability_window_summary(active_stack, battle, target) if _active_ability_window_summary(active_stack, battle, target) != "" else "bracing buys cohesion and keeps retaliation or firing posture intact."
		"wait":
			return "waiting lets the enemy move first, so this stack can strike once they come close." if ready else _wait_action_summary(battle, active_stack)
		"retreat":
			return "withdrawal preserves survivors but yields this battle's field result." if ready else _retreat_action_summary(session)
		"surrender":
			return "surrender preserves what terms allow while conceding the field." if ready else _surrender_action_summary(session)
	return "this order changes the next exchange."

static func _action_consequence_line(
	action_id: String,
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary,
	action: Dictionary
) -> String:
	var summary := String(action.get("summary", "")).strip_edges()
	var objective_preview := ""
	if not active_stack.is_empty() and String(active_stack.get("side", "")) == "player":
		objective_preview = _field_objective_action_preview(
			battle,
			{
				"action": action_id,
				"side": "player",
				"battle_id": String(active_stack.get("battle_id", "")),
				"target_battle_id": String(target.get("battle_id", "")),
			}
		)
	if objective_preview != "":
		return objective_preview
	if action_id in ["strike", "shoot"] and not target.is_empty() and not bool(action.get("disabled", false)):
		return _attack_action_summary(active_stack, target, battle, action_id == "shoot")
	if action_id == "defend" and not active_stack.is_empty():
		return "Cohesion can rise by %d; status pressure has a safer round to expire." % _preview_defend_cohesion_gain(active_stack, battle)
	if action_id == "advance":
		return _advance_action_summary(battle, active_stack)
	if summary != "":
		return summary
	return "No immediate consequence preview."

static func _action_consequence_preview_list(surface: Dictionary) -> Array:
	var previews := []
	for action_id in ["advance", "strike", "shoot", "defend", "retreat", "surrender"]:
		var action = surface.get(action_id, {})
		if not (action is Dictionary):
			continue
		previews.append({
			"id": action_id,
			"label": String(action.get("label", action_id.capitalize())),
			"readiness": String(action.get("readiness", "")),
			"target": String(action.get("target", "")),
			"range": String(action.get("range", "")),
			"why": String(action.get("why", "")),
			"consequence": String(action.get("consequence", "")),
		})
	return previews

static func _post_action_happened_line(result: Dictionary, action_id: String) -> String:
	var message := String(result.get("message", "")).strip_edges()
	if message == "":
		return "%s resolved." % _post_action_label(action_id)
	var sentences := message.split(". ", false)
	var happened := String(sentences[0]).strip_edges()
	if happened != "" and not happened.ends_with(".") and not happened.ends_with("!") and not happened.ends_with("?"):
		happened += "."
	return happened

static func _post_action_affected_line(
	battle: Dictionary,
	result: Dictionary,
	action_id: String,
	context: Dictionary
) -> String:
	var attack_target_id := String(result.get("attack_target_battle_id", ""))
	if attack_target_id != "":
		return _post_action_stack_delta_line(
			battle,
			attack_target_id,
			String(result.get("attack_target_name", context.get("target_name", "Target"))),
			int(context.get("target_count_before", 0)),
			int(context.get("target_health_before", 0))
		)

	var movement_value: Variant = result.get("movement_intent", {})
	if movement_value is Dictionary and not movement_value.is_empty():
		var movement_intent: Dictionary = movement_value
		var mover_id := String(movement_intent.get("active_battle_id", context.get("active_battle_id", "")))
		var destination := String(movement_intent.get("destination_detail", movement_intent.get("destination_label", "")))
		var mover_line := _post_action_stack_delta_line(
			battle,
			mover_id,
			String(movement_intent.get("active_stack_name", context.get("active_name", "Acting stack"))),
			int(context.get("active_count_before", 0)),
			int(context.get("active_health_before", 0))
		)
		if destination != "":
			return "%s; position %s." % [mover_line.trim_suffix("."), destination]
		return mover_line

	var actor_id := String(context.get("active_battle_id", ""))
	var actor_name := String(context.get("active_name", "Acting stack"))
	if action_id == "defend":
		return "%s braced; %s." % [
			actor_name,
			_post_action_status_after(battle, actor_id, String(context.get("active_status_before", ""))),
		]
	if action_id == "advance":
		return _post_action_stack_delta_line(
			battle,
			actor_id,
			actor_name,
			int(context.get("active_count_before", 0)),
			int(context.get("active_health_before", 0))
		)
	var target_id := String(context.get("target_battle_id", ""))
	if target_id != "":
		return _post_action_stack_delta_line(
			battle,
			target_id,
			String(context.get("target_name", "Target")),
			int(context.get("target_count_before", 0)),
			int(context.get("target_health_before", 0))
		)
	return "%s resolved; battlefield status updated." % _post_action_label(action_id)

static func _post_action_stack_delta_line(
	battle: Dictionary,
	battle_id: String,
	fallback_name: String,
	count_before: int,
	health_before: int
) -> String:
	var stack := _get_stack_by_id(battle, battle_id)
	if stack.is_empty() or _alive_count(stack) <= 0:
		if count_before > 0 or health_before > 0:
			return "%s removed from the field." % fallback_name
		return "%s changed state." % fallback_name
	var count_after := _alive_count(stack)
	var health_after := int(stack.get("total_health", 0))
	var count_delta := count_after - count_before
	var health_delta := health_after - health_before
	var delta_parts := []
	if count_before > 0 and count_delta != 0:
		delta_parts.append("x%s%d" % ["+" if count_delta > 0 else "", count_delta])
	if health_before > 0 and health_delta != 0:
		delta_parts.append("%s%d HP" % ["+" if health_delta > 0 else "", health_delta])
	var delta_text := " | %s" % ", ".join(delta_parts) if not delta_parts.is_empty() else ""
	return "%s x%d, %d HP at %s%s; %s." % [
		_stack_label(stack),
		count_after,
		health_after,
		_hex_label(_stack_hex(stack)),
		delta_text,
		_stack_status_pressure_short(stack, battle),
	]

static func _post_action_status_after(battle: Dictionary, battle_id: String, fallback_status: String) -> String:
	var stack := _get_stack_by_id(battle, battle_id)
	if not stack.is_empty() and _alive_count(stack) > 0:
		return _stack_status_pressure_short(stack, battle)
	return fallback_status if fallback_status != "" else "status pressure updated"

static func _post_action_decision_line(
	session: SessionStateStoreScript.SessionData,
	result: Dictionary,
	context: Dictionary
) -> String:
	var state := String(result.get("state", "continue"))
	if state != "" and state != "continue":
		return "battle result is %s; routing follows the field outcome." % state.replace("_", " ")
	if session == null or session.battle.is_empty():
		return "battlefield state changed; check the return route."
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		return "no stack is ready; resolution will continue."
	if String(active_stack.get("side", "")) != "player":
		return "%s has initiative; expect enemy pressure before the next order." % _stack_label(active_stack)
	var target = get_selected_target(battle)
	var click_intent := selected_target_board_click_intent(battle)
	var action_label := String(click_intent.get("label", ""))
	if action_label != "" and not target.is_empty():
		return "%s can %s %s now." % [_stack_label(active_stack), action_label, _stack_label(target)]
	var target_range := _target_range_readiness_line(active_stack, target, battle).trim_prefix("Target/range: ")
	if target_range != "":
		return "%s order window: %s" % [_stack_label(active_stack), target_range]
	return "%s has command; choose the next order from current status pressure." % _stack_label(active_stack)

static func _post_action_next_actor_line(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "battle will leave the tactical field."
	var active_stack = get_active_stack(session.battle)
	if active_stack.is_empty():
		return "no living stack is queued."
	return "%s [%s] acts now at Init %d." % [
		_stack_label(active_stack),
		_side_label(String(active_stack.get("side", ""))),
		_stack_initiative_total(active_stack, session.battle),
	]

static func _post_action_label(action_id: String) -> String:
	var normalized := action_id
	if normalized.begins_with("cast_spell:"):
		var spell := ContentService.get_spell(normalized.trim_prefix("cast_spell:"))
		return String(spell.get("name", "Spell")) if not spell.is_empty() else "Spell"
	match normalized:
		"shoot":
			return "Shot"
		"strike":
			return "Strike"
		"advance", "move":
			return "Move"
		"defend":
			return "Defend"
		"wait":
			return "Wait"
		"retreat":
			return "Retreat"
		"surrender":
			return "Surrender"
	return "Order"

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
	return _normalize_animation_event_queue(battle.get(ANIMATION_EVENT_QUEUE_KEY, []))

static func battle_presentation_event_stream(battle: Dictionary) -> Array:
	return _normalize_presentation_event_queue(battle.get(PRESENTATION_EVENT_QUEUE_KEY, []))

static func battle_presentation_speed(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return PRESENTATION_SPEED_NORMAL
	return _normalize_presentation_speed(String(session.battle.get(PRESENTATION_SPEED_KEY, PRESENTATION_SPEED_NORMAL)))

static func set_battle_presentation_speed(session: SessionStateStoreScript.SessionData, speed: String) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"ok": false, "speed": PRESENTATION_SPEED_NORMAL, "message": "No battle is active."}
	var normalized := _normalize_presentation_speed(speed)
	session.battle[PRESENTATION_SPEED_KEY] = normalized
	return {
		"ok": true,
		"speed": normalized,
		"message": "Battle playback speed set to %s." % normalized.capitalize(),
	}

static func battle_presentation_playback_msec(battle: Dictionary) -> int:
	var speed := _normalize_presentation_speed(String(battle.get(PRESENTATION_SPEED_KEY, PRESENTATION_SPEED_NORMAL)))
	match speed:
		PRESENTATION_SPEED_FAST:
			return 320
		PRESENTATION_SPEED_INSTANT:
			return 1
	return 760

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
	if session == null or session.battle.is_empty():
		return {}
	var event := _latest_animation_event(session.battle)
	if event.is_empty():
		return {}
	var battle_id := String(event.get("battle_id", ""))
	var actor := _get_stack_by_id(session.battle, battle_id)
	var source := _get_stack_by_id(session.battle, String(event.get("source_battle_id", "")))
	var target := _get_stack_by_id(session.battle, String(event.get("target_battle_id", "")))
	var actor_label := battle_actor_label(session.battle, battle_id) if is_hero_actor_id(battle_id) else (_stack_label(actor) if not actor.is_empty() else battle_id)
	var target_label := _stack_label(target) if not target.is_empty() else ""
	var source_id := String(event.get("source_battle_id", ""))
	var source_label := battle_actor_label(session.battle, source_id) if is_hero_actor_id(source_id) else (_stack_label(source) if not source.is_empty() else "")
	var event_id := String(event.get("event_id", ""))
	var action_text := _animation_event_action_text(event_id, actor_label, source_label, target_label, event)
	if action_text == "":
		action_text = "%s changes posture." % actor_label
	var visible := "Action cue: %s" % action_text
	var tooltip_lines := [
		"Battle Presentation Event",
		"- Cue: %s" % action_text,
		"- Actor: %s" % actor_label,
		"- Event: %s" % event_id,
		"- State: %s" % String(event.get("state", "")),
		"- Playback: board motion, VFX, and audio resolve from the battle animation event queue.",
	]
	if source_label != "":
		tooltip_lines.append("- Source: %s" % source_label)
	if target_label != "":
		tooltip_lines.append("- Target: %s" % target_label)
	return {
		"ok": true,
		"source": "battle_animation_events",
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"action_text": action_text,
		"event": event.duplicate(true),
		"event_id": event_id,
		"state": String(event.get("state", "")),
		"battle_id": battle_id,
		"actor_name": actor_label,
		"source_name": source_label,
		"target_name": target_label,
		"serial": int(event.get("serial", 0)),
		"round": int(event.get("round", 1)),
		"turn_index": int(event.get("turn_index", 0)),
	}

static func cast_player_spell(session: SessionStateStoreScript.SessionData, spell_id: String, target_id: String = "") -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.cast_player_spell", [session, spell_id, target_id])

static func move_active_stack_to_hex(session: SessionStateStoreScript.SessionData, q: int, r: int) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.move_active_stack_to_hex", [session, q, r])

static func perform_presented_action(session: SessionStateStoreScript.SessionData, action: String, destination: Dictionary = {}) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"ok": false, "state": "invalid", "message": "No battle is active."}
	var original_battle := session.battle
	ActionPlayback.begin(original_battle)
	var result: Dictionary
	if action == "ready":
		result = resolve_if_battle_ready(session)
		result["ok"] = String(result.get("state", "invalid")) != "invalid"
	elif action == "move":
		result = move_active_stack_to_hex(session, int(destination.get("q", -1)), int(destination.get("r", -1)))
	elif action.begins_with("cast_spell:"):
		result = cast_player_spell(session, action.trim_prefix("cast_spell:"), String(destination.get("target_id", "")))
	else:
		# A strike can name the hex to strike from as its destination.
		result = perform_player_action(session, action, destination if action == "strike" else {})
	if action != "ready":
		record_player_order(session.battle, result)
	return ActionPlayback.finish(original_battle, result)

## Counts an order the player gave (a move, attack, defence, wait or the
## hero's cast) once it was carried out. Quick Resolve is offered only before
## the first one (player_has_given_orders).
static func record_player_order(battle: Dictionary, result: Dictionary) -> void:
	if battle.is_empty() or String(result.get("state", "invalid")) == "invalid":
		return
	battle[PLAYER_ORDERS_KEY] = maxi(0, int(battle.get(PLAYER_ORDERS_KEY, 0))) + 1

static func player_has_given_orders(battle: Dictionary) -> bool:
	return int(battle.get(PLAYER_ORDERS_KEY, 0)) > 0

## What the battle screen shows for a side's hero, or {} when no commander
## leads that side. A hero from the content roster stands beside its army
## (has_figure); a town captain or a guard's commander has no figure. mana is
## the commander's spellbook mana, which its casts spend.
static func hero_presentation(battle: Dictionary, side: String) -> Dictionary:
	if battle.is_empty() or side not in ["player", "enemy"]:
		return {}
	var state_value: Variant = _commander_state_for_side(battle, side)
	var state: Dictionary = state_value if state_value is Dictionary else {}
	if state.is_empty():
		return {}
	var hero_id := ""
	if side == "player":
		var source: Dictionary = battle.get("player_commander_source", {}) if battle.get("player_commander_source", {}) is Dictionary else {}
		if String(source.get("type", "")) in ["active_hero", "town_hero"]:
			hero_id = String(source.get("hero_id", "")).strip_edges()
			if hero_id == "":
				hero_id = String(state.get("id", "")).strip_edges()
	else:
		for key in ["roster_hero_id", "hero_id", "id"]:
			var candidate := String(state.get(key, "")).strip_edges()
			if candidate != "" and not ContentService.get_hero(candidate).is_empty():
				hero_id = candidate
				break
	var template: Dictionary = ContentService.get_hero(hero_id) if hero_id != "" else {}
	if template.is_empty():
		hero_id = ""
	var spellbook: Dictionary = state.get("spellbook", {}) if state.get("spellbook", {}) is Dictionary else {}
	var mana: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	var battle_spell_count := SpellRulesScript.known_spells(state, "battle").size()
	var name := commander_name(battle, side)
	return {
		"side": side,
		"actor_id": hero_actor_id(side),
		"name": name if name != "" else ("Your commander" if side == "player" else "Enemy commander"),
		"hero_id": hero_id,
		"faction_id": String(state.get("faction_id", template.get("faction_id", ""))).strip_edges(),
		"has_figure": hero_id != "",
		"role": _commander_role_label(battle, side),
		"level": maxi(1, int(state.get("level", 1))),
		"mana_current": maxi(0, int(mana.get("current", 0))),
		"mana_max": maxi(0, int(mana.get("max", 0))),
		"battle_spell_count": battle_spell_count,
		"cast_this_round": _commander_spell_cast_this_round(battle, side),
	}

## What a stack's details card shows, from the numbers the battle itself
## uses: attack and defense with the commanding hero's bonus (and the Defend
## stance), speed as the hexes the stack may walk this turn, initiative as
## it orders turns. Each stat carries the unit's own value as "base", so the
## card can show what changed it. {} for a stack that is not in the battle.
static func stack_details(battle: Dictionary, battle_id: String) -> Dictionary:
	var stack := _get_stack_by_id(battle, battle_id)
	if stack.is_empty():
		return {}
	var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
	var side := String(stack.get("side", ""))
	var hero := _hero_payload_for_side(battle, side)
	var count := _alive_count(stack)
	var unit_hp := maxi(1, int(stack.get("unit_hp", 1)))
	var stack_health := maxi(0, int(stack.get("total_health", 0)))
	var defending := bool(stack.get("defending", false))
	var defend_bonus := 2 + int(hero.get("defend_defense_bonus", 0)) if defending else 0
	var hero_attack := int(hero.get("attack", 0))
	var hero_defense := int(hero.get("defense", 0))
	var ranged := bool(stack.get("ranged", false))
	var faction_id := String(stack.get("faction_id", ""))
	var faction_name := String(ContentService.get_faction(faction_id).get("name", "")) if faction_id != "" else ""
	var min_damage := int(stack.get("min_damage", 1))
	var shots_left := maxi(0, int(stack.get("shots_remaining", 0)))
	var abilities := []
	for ability in stack.get("abilities", []):
		if ability is Dictionary and String(ability.get("name", "")).strip_edges() != "":
			abilities.append({
				"name": String(ability.get("name", "")).strip_edges(),
				"description": String(ability.get("description", "")).strip_edges(),
			})
	return {
		"battle_id": battle_id,
		"unit_id": String(stack.get("unit_id", "")),
		"name": String(stack.get("name", unit.get("name", ""))),
		"side": side,
		"faction": faction_name if faction_name != "" else "Neutral",
		"tier": int(stack.get("tier", 1)),
		"ranged": ranged,
		"large": Footprint.width(stack) == 2,
		"count": count,
		"unit_health": unit_hp,
		"top_health": stack_health - (count - 1) * unit_hp if count > 0 else 0,
		"stack_health": stack_health,
		"attack": {"base": int(unit.get("attack", stack.get("attack", 0))), "value": _stack_attack_total(stack, battle) + hero_attack},
		"defense": {"base": int(unit.get("defense", stack.get("defense", 0))), "value": _stack_defense_total(stack, battle) + hero_defense + defend_bonus},
		"damage": {"min": min_damage, "max": maxi(min_damage, int(stack.get("max_damage", 1)))},
		"health": {"base": int(unit.get("hp", unit_hp)), "value": unit_hp},
		"speed": {"base": clampi(int(unit.get("speed", stack.get("speed", 1))), 1, 6), "value": _stack_movement_points(stack, battle)},
		"initiative": {"base": int(unit.get("initiative", stack.get("initiative", 1))), "value": _stack_initiative_total(stack, battle)},
		"shots": {"left": shots_left, "max": maxi(shots_left, int(unit.get("shots", shots_left)))} if ranged else {},
		"strike_backs": stack_strike_backs(battle, stack),
		"cohesion": {"value": _stack_cohesion_total(stack, battle), "max": COHESION_MAX},
		"momentum": {"value": _stack_momentum_total(stack, battle), "max": MOMENTUM_MAX},
		"abilities": abilities,
		"effects": stack_effect_rows(stack, battle),
		"defending": defending,
		"defend_bonus": defend_bonus,
		"waiting": stack_is_waiting(battle, battle_id),
		"active": battle_id == String(battle.get("active_stack_id", "")),
		"hero_name": commander_name(battle, side),
		"hero_attack": hero_attack,
		"hero_defense": hero_defense,
	}

## The strike-backs a stack has this round: "max" a round, "left" of them
## still to make (none while Staggered, which "blocked" names).
static func stack_strike_backs(battle: Dictionary, stack: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules.stack_strike_backs", [battle, stack])

## The stack waited this round and has yet to act: it is in the waiting part
## of the turn order, after the stacks still to act at their own speed.
static func stack_is_waiting(battle: Dictionary, battle_id: String) -> bool:
	var active_id := String(battle.get("active_stack_id", ""))
	if battle_id == "" or battle_id == active_id or not stack_has_waited(battle, battle_id):
		return false
	if _alive_count(_get_stack_by_id(battle, battle_id)) <= 0:
		return false
	var turn_order: Array = battle.get("turn_order", []) if battle.get("turn_order", []) is Array else []
	var start := turn_order.find(active_id)
	if start < 0:
		start = clampi(int(battle.get("turn_index", 0)), 0, turn_order.size())
	return turn_order.find(battle_id) >= start

## The effects on a stack now, one row each: its name, what it does, how long
## it has left ("turns" of the "unit" "turn", "round" or "battle";
## "after_this" when the stack is acting and its current turn does not count)
## and whether it helps or hinders ("polarity").
static func stack_effect_rows(stack: Dictionary, battle: Dictionary) -> Array:
	var rows := []
	var current_round := int(battle.get("round", 1))
	for effect in SpellRulesScript.active_effects_for_round(stack, current_round):
		var effect_id := String(effect.get("effect_id", ""))
		var counted: bool = effect.has("turns_left")
		var left := maxi(1, int(effect.get("turns_left", 1))) if counted else maxi(1, int(effect.get("expires_after_round", current_round)) - current_round + 1)
		var unit := "turn" if counted else "round"
		# A preparation held until it is used outlasts any battle.
		if not counted and left > int(battle.get("max_rounds", 12)):
			unit = "battle"
		var parts := PackedStringArray()
		var rules := SpellRulesScript.status_rules_text(effect_id)
		if rules != "":
			parts.append(rules)
		var modifiers := _effect_modifier_phrase(effect)
		if modifiers != "":
			parts.append(modifiers)
		rows.append({
			"effect_id": effect_id,
			"spell_id": String(effect.get("spell_id", "")),
			"name": String(effect.get("label", "Effect")),
			"text": "; ".join(parts),
			"turns": left,
			"unit": unit,
			"after_this": counted and bool(effect.get("skip_current_turn", false)),
			"polarity": effect_polarity(effect),
		})
	return rows

## An effect's changes in words: "+2 defense, -1 initiative", and how much
## weaker its stack strikes back.
static func _effect_modifier_phrase(effect: Dictionary) -> String:
	var modifiers: Dictionary = effect.get("modifiers", {}) if effect.get("modifiers", {}) is Dictionary else {}
	var parts := PackedStringArray()
	for key in ["attack", "defense", "speed", "initiative", "cohesion", "momentum"]:
		var amount := int(modifiers.get(key, 0))
		if amount != 0:
			parts.append("%s%d %s" % ["+" if amount > 0 else "", amount, key])
	var retaliation := int(modifiers.get("retaliation", 0))
	if retaliation < 0:
		parts.append("strikes back %d%% weaker" % mini(75, -retaliation))
	return ", ".join(parts)

## Whether an effect helps its stack ("beneficial") or hinders it
## ("harmful"): a status with rules beyond its numbers, or any lowered
## number, hinders; a raised number or a ward against statuses helps.
static func effect_polarity(effect: Dictionary) -> String:
	if SpellRulesScript.status_rules_text(String(effect.get("effect_id", ""))) != "":
		return "harmful"
	var modifiers: Dictionary = effect.get("modifiers", {}) if effect.get("modifiers", {}) is Dictionary else {}
	var raised := false
	for key in modifiers.keys():
		var amount := int(modifiers[key])
		if amount < 0:
			return "harmful"
		raised = raised or amount > 0
	if raised:
		return "beneficial"
	var wards: Variant = effect.get("blocked_status_ids", [])
	return "beneficial" if wards is Array and not (wards as Array).is_empty() else "harmful"

## What a hero's details card shows: hero_presentation, its attack and
## defense as its stacks fight with them, spell power and knowledge, its
## faction and class, its specialties with their ranks, and its battle
## spells at what they cost it. {} for a side without a commander.
static func hero_details(battle: Dictionary, side: String) -> Dictionary:
	var details := hero_presentation(battle, side)
	if details.is_empty():
		return {}
	var state: Dictionary = _commander_state_for_side(battle, side)
	var payload := _hero_payload_for_side(battle, side)
	var command: Dictionary = state.get("command", {}) if state.get("command", {}) is Dictionary else {}
	var hero_id := String(details.get("hero_id", ""))
	var template_payload := {"id": hero_id} if hero_id != "" else state
	details["attack"] = int(payload.get("attack", 0))
	details["defense"] = int(payload.get("defense", 0))
	details["power"] = SpellRulesScript.spell_power(state)
	details["knowledge"] = maxi(0, int(command.get("knowledge", 0)))
	details["faction"] = HeroCommandRulesScript.hero_faction_label(template_payload, String(details.get("faction_id", "")))
	details["class"] = HeroCommandRulesScript.hero_role_label(template_payload) if hero_id != "" else String(details.get("role", ""))
	var specialties := []
	var seen := {}
	var specialty_ids: Array = state.get("specialties", []) if state.get("specialties", []) is Array else []
	for specialty_value in specialty_ids:
		var specialty_id := String(specialty_value)
		if seen.has(specialty_id):
			continue
		seen[specialty_id] = true
		var definition := HeroProgressionRulesScript.specialty_definition(specialty_id)
		if definition.is_empty():
			continue
		var rank := HeroProgressionRulesScript.specialty_rank(state, specialty_id)
		specialties.append({
			"id": specialty_id,
			"name": String(definition.get("name", specialty_id)),
			"rank": rank,
			"rank_label": HeroProgressionRulesScript.rank_label(rank),
			"text": HeroProgressionRulesScript.rank_text(specialty_id, rank),
		})
	details["specialties"] = specialties
	var spells := []
	for spell_value in SpellRulesScript.known_spells(state, "battle"):
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		spells.append({
			"id": spell_id,
			"name": String(spell.get("name", spell_id)),
			"cost": SpellRulesScript.adjusted_spell_mana_cost(state, spell),
			"icon": SpellRulesScript.spell_icon_path(spell_id),
		})
	details["spells"] = spells
	return details

## approach names the hex a strike is made from (q, r): one of
## melee_approach_cells. Without it the stack strikes from where it stands, or
## walks to the nearest hex it can strike from (melee_approach_destination).
static func perform_player_action(session: SessionStateStoreScript.SessionData, action: String, approach: Dictionary = {}) -> Dictionary:
	return BattleEngine.native_writing(&"BattleRules.perform_player_action", [session, action, approach])

static func roster_lines(battle: Dictionary, side: String) -> Array:
	var lines = []
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != side:
			continue
		lines.append(_stack_summary_line(stack, battle, String(battle.get("active_stack_id", "")), String(battle.get("selected_target_id", ""))))
	return lines

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

static func battle_rewards_for_strength(encounter: Dictionary, beaten_stacks: Variant, commander: Variant = {}) -> Dictionary:
	var listed: Dictionary = encounter.get("rewards", {}) if encounter.get("rewards", {}) is Dictionary else {}
	var strength: float = load("res://scripts/core/AiHeroRules.gd").army_power(beaten_stacks, commander)
	var rewards := {}
	if strength <= 0.0:
		return rewards
	var scale := clampf(strength / REWARD_REFERENCE_STRENGTH, REWARD_RESOURCE_SCALE_MIN, REWARD_RESOURCE_SCALE_MAX)
	for key in listed.keys():
		if String(key) == "experience" or not (listed[key] is int or listed[key] is float):
			continue
		var amount := float(listed[key]) * REWARD_RESOURCE_SHARE * scale
		var paid := int(round(amount / 10.0)) * 10 if String(key) == "gold" else int(round(amount))
		if paid > 0:
			rewards[String(key)] = paid
	var experience := int(round(strength * REWARD_EXPERIENCE_PER_STRENGTH))
	if experience > 0:
		rewards["experience"] = experience
	return rewards

## The whole enemy army as it took the field, for the reward a win would pay.
static func _starting_enemy_stacks(battle: Dictionary) -> Array:
	var stacks := []
	for stack_value in battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy" and int(stack_value.get("base_count", 0)) > 0:
			stacks.append({"unit_id": String(stack_value.get("unit_id", "")), "count": int(stack_value.get("base_count", 0))})
	return stacks

static func _adjust_enemy_pressure(session: SessionStateStoreScript.SessionData, faction_id: String, delta: int) -> int:
	return BattleEngine.native_writing(&"BattleRules._adjust_enemy_pressure", [session, faction_id, delta])

static func _add_enemy_treasury_resources(session: SessionStateStoreScript.SessionData, faction_id: String, delta: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleRules._add_enemy_treasury_resources", [session, faction_id, delta])

static func pending_battle_report(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or not session.battle.is_empty():
		return {}
	var value: Variant = session.flags.get("last_battle_aftermath", {})
	if not (value is Dictionary):
		return {}
	var report: Dictionary = value
	if (
		not bool(report.get("pending", false))
		or int(report.get("report_version", 0)) != 1
		or String(report.get("report_id", "")) == ""
		or not (report.get("casualties", {}) is Dictionary)
	):
		return {}
	return report.duplicate(true)

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

static func _build_battle_stack(
	unit_id: String,
	count: int,
	side: String,
	index: int,
	source: Dictionary = {},
	army_slot_index: int = -1
) -> Dictionary:
	var unit = ContentService.get_unit(unit_id)
	if unit.is_empty():
		return {}
	var unit_hp = max(1, int(unit.get("hp", 1)))
	var cohesion_base = _cohesion_base_for_unit(unit)
	var faction_id := String(unit.get("faction_id", ""))
	var body: Dictionary = ContentService.load_json("res://content/unit_battle_size_manifest.json").get("units", {}).get(unit_id, {})
	var affiliation := String(unit.get("affiliation", ""))
	if affiliation == "":
		affiliation = "faction" if faction_id != "" else "neutral"
	return {
		"battle_id": "%s_%d_%s" % [side, index, unit_id],
		"side": side,
		"faction_id": faction_id,
		"affiliation": affiliation,
		"unit_id": unit_id,
		"army_slot_index": army_slot_index if army_slot_index >= 0 and army_slot_index < 7 else index,
		"battle_footprint": 2 if int(body.get("footprint", 1)) == 2 else 1,
		"battle_visual_scale": clampf(float(body.get("visual_scale", 1.0)), 0.65, 1.6),
		"name": String(unit.get("name", unit_id)),
		"tier": clamp(int(unit.get("tier", 1)), 1, 7),
		"unit_hp": unit_hp,
		"total_health": max(0, count) * unit_hp,
		"base_count": max(0, count),
		"attack": int(unit.get("attack", 0)),
		"defense": int(unit.get("defense", 0)),
		"min_damage": int(unit.get("min_damage", 1)),
		"max_damage": int(unit.get("max_damage", 1)),
		"initiative": int(unit.get("initiative", 1)),
		"speed": int(unit.get("speed", 1)),
		"ranged": bool(unit.get("ranged", false)),
		"retaliations": max(0, int(unit.get("retaliations", 1))),
		"retaliations_left": max(0, int(unit.get("retaliations", 1))),
		"shots_remaining": int(unit.get("shots", 0)),
		"spell_resistance_pct": clamp(int(unit.get("spell_resistance_pct", 0)), 0, SpellRulesScript.MAX_SPELL_RESISTANCE_PCT),
		"control_resistance_pct": clamp(int(unit.get("control_resistance_pct", 0)), 0, SpellRulesScript.MAX_CONTROL_RESISTANCE_PCT),
		"spell_school_resistance_pct": SpellRulesScript.normalize_school_resistance(unit.get("spell_school_resistance_pct", {})),
		"status_immunity_ids": SpellRulesScript.normalize_status_immunity_ids(unit.get("status_immunity_ids", [])),
		"defending": false,
		"cohesion_base": cohesion_base,
		"cohesion": cohesion_base,
		"momentum": 0,
		STACK_HEX_KEY: {},
		"abilities": _normalize_unit_abilities(unit.get("abilities", [])),
		"ability_uses": {},
		"effects": [],
		"source_type": String(source.get("source_type", "")),
		"source_hero_id": String(source.get("hero_id", "")),
		"source_town_placement_id": String(source.get("town_placement_id", "")),
		"source_encounter_key": String(source.get("encounter_key", "")),
	}

static func _commander_spell_cast_this_round(battle: Dictionary, side: String) -> bool:
	return BattleEngine.native(&"BattleRules._commander_spell_cast_this_round", [battle, side])

static func hero_actor_id(side: String) -> String:
	return BattleEngine.native(&"BattleRules.hero_actor_id", [side])

static func is_hero_actor_id(actor_id: String) -> bool:
	return actor_id.begins_with(HERO_ACTOR_PREFIX)

static func hero_actor_side(actor_id: String) -> String:
	return actor_id.trim_prefix(HERO_ACTOR_PREFIX) if is_hero_actor_id(actor_id) else ""

## The name of the hero commanding a side, or "" when the battle has none.
static func commander_name(battle: Dictionary, side: String) -> String:
	return BattleEngine.native(&"BattleRules.commander_name", [battle, side])

## The casting hero in the shape events and labels read from a stack.
static func _hero_caster(battle: Dictionary, side: String) -> Dictionary:
	return BattleEngine.native(&"BattleRules._hero_caster", [battle, side])

## The label of an event's actor: a stack's name or the casting hero's.
static func battle_actor_label(battle: Dictionary, actor_id: String) -> String:
	if is_hero_actor_id(actor_id):
		return String(_hero_caster(battle, hero_actor_side(actor_id)).get("name", ""))
	return _stack_label(_get_stack_by_id(battle, actor_id))

## The side of an event's actor, stack or hero.
static func battle_actor_side(battle: Dictionary, actor_id: String) -> String:
	if is_hero_actor_id(actor_id):
		return hero_actor_side(actor_id)
	return String(_get_stack_by_id(battle, actor_id).get("side", ""))

static func _ensure_battle_hex_state(battle: Dictionary) -> void:
	BattleEngine.native_writing(&"BattleRules._ensure_battle_hex_state", [battle])

## The cell a stack deploys on; the board draws a stack without a saved hex there.
static func default_deployment_hex(side: String, index: int, stack_count: int, stack: Dictionary) -> Dictionary:
	return _default_stack_hex(side, index, stack_count, stack)

static func _default_stack_hex(side: String, index: int, stack_count: int, stack: Dictionary) -> Dictionary:
	return BattleEngine.native(&"BattleRules._default_stack_hex", [side, index, stack_count, stack])

static func battle_obstacles(battle: Dictionary) -> Array:
	var obstacles: Variant = battle.get(OBSTACLES_KEY, [])
	return obstacles.duplicate(true) if obstacles is Array else []

## "q,r" -> "obstacle:<id>" for every obstacle cell.
static func battle_obstacle_cells(battle: Dictionary) -> Dictionary:
	return _obstacle_cell_map(battle)

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

static func _damage_preview_text(preview: Dictionary) -> String:
	if preview.is_empty():
		return "no clean damage"
	var min_damage = int(preview.get("min_damage", 0))
	var max_damage = int(preview.get("max_damage", min_damage))
	var min_units = int(preview.get("min_units", 0))
	var max_units = int(preview.get("max_units", min_units))
	var damage_text = "%d damage" % min_damage if min_damage == max_damage else "%d-%d damage" % [min_damage, max_damage]
	if max_units <= 0:
		return damage_text
	var unit_text = "%d unit" % min_units if min_units == max_units else "%d-%d units" % [min_units, max_units]
	return "%s (%s)" % [damage_text, unit_text]

static func _retaliation_range_preview(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	attack_distance: int,
	attack_preview: Dictionary
) -> Dictionary:
	if attack_preview.is_empty():
		return {}
	var low_state = defender.duplicate(true)
	low_state["total_health"] = max(0, int(defender.get("total_health", 0)) - int(attack_preview.get("max_damage", 0)))
	var high_state = defender.duplicate(true)
	high_state["total_health"] = max(0, int(defender.get("total_health", 0)) - int(attack_preview.get("min_damage", 0)))
	var low_preview = _damage_range_preview(low_state, attacker, battle, false, true, attack_distance)
	var high_preview = _damage_range_preview(high_state, attacker, battle, false, true, attack_distance)
	if low_preview.is_empty() and high_preview.is_empty():
		return {}
	var min_damage = int(low_preview.get("min_damage", high_preview.get("min_damage", 0)))
	var max_damage = int(high_preview.get("max_damage", low_preview.get("max_damage", min_damage)))
	var losses = _unit_loss_range(attacker, min_damage, max_damage)
	return {
		"min_damage": min_damage,
		"max_damage": max_damage,
		"min_units": int(losses.get("min_units", 0)),
		"max_units": int(losses.get("max_units", 0)),
	}

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

static func _wait_action_summary(battle: Dictionary, stack: Dictionary) -> String:
	var battle_id := String(stack.get("battle_id", ""))
	if stack_has_waited(battle, battle_id):
		return "%s has already waited this round." % _stack_label(stack)
	var ahead := _stacks_ahead_after_wait(battle, battle_id)
	if ahead <= 0:
		return "No other stack is left to act this round, so the turn comes straight back."
	return "Act later this round, after %d more stack%s. Once per round; the turn is not spent." % [ahead, "" if ahead == 1 else "s"]

## Turn order forecast: the rest of this round from the active stack, the
## stacks waiting at its end, and the predicted order of the next round once
## this round's turns are spent and its effects run out. Works on a copy; the
## battle and its RNG are untouched.
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

static func _normalize_unit_abilities(value: Variant) -> Array:
	var abilities = []
	var seen = {}
	if not (value is Array):
		return abilities
	for entry in value:
		if not (entry is Dictionary):
			continue
		var ability_id = String(entry.get("id", ""))
		if ability_id == "" or seen.has(ability_id):
			continue
		var normalized = {}
		match ability_id:
			"reach":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Reach")),
					"description": String(entry.get("description", "")),
					"distance_one_multiplier": clampf(float(entry.get("distance_one_multiplier", 1.0)), 0.5, 1.5),
				}
				if entry.has("held_objective_types"):
					normalized["held_objective_types"] = _normalize_string_array(entry.get("held_objective_types", []))
			"hookline":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Hookline")),
					"description": String(entry.get("description", "")),
					"distance_one_multiplier": clampf(float(entry.get("distance_one_multiplier", 0.5)), 0.0, 1.0),
					"uses_per_battle": maxi(1, int(entry.get("uses_per_battle", 1))),
					"available_from_round": maxi(1, int(entry.get("available_from_round", 1))),
					"status_id": String(entry.get("status_id", STATUS_ROOTED)),
					"status_label": String(entry.get("status_label", "Pinned")),
					"duration_rounds": maxi(1, int(entry.get("duration_rounds", 1))),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {})),
				}
			"rot_cant":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Rot Cant")),
					"description": String(entry.get("description", "")),
					"status_id": String(entry.get("status_id", STATUS_HARRIED)),
					"status_label": String(entry.get("status_label", "Rot-Called")),
					"duration_rounds": maxi(1, int(entry.get("duration_rounds", 1))),
					"uses_per_battle": maxi(1, int(entry.get("uses_per_battle", 1))),
					"available_from_round": maxi(1, int(entry.get("available_from_round", 1))),
					"target_min_tier": maxi(2, int(entry.get("target_min_tier", 2))),
					"ai_target_priority_bonus": clampf(float(entry.get("ai_target_priority_bonus", 0.25)), 0.0, 4.0),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"cohesion": -1, "retaliation": -5})),
					"wounded_threshold_ratio": clampf(float(entry.get("wounded_threshold_ratio", 0.5)), 0.1, 1.0),
					"wounded_damage_multiplier": clampf(float(entry.get("wounded_damage_multiplier", 1.02)), 1.0, 1.25),
				}
			"brace":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Brace")),
					"description": String(entry.get("description", "")),
					"retaliation_multiplier": clampf(float(entry.get("retaliation_multiplier", 1.0)), 1.0, 2.0),
					"defending_cohesion_bonus": max(0, int(entry.get("defending_cohesion_bonus", 0))),
					"status_id": String(entry.get("status_id", STATUS_STAGGERED)),
					"status_label": String(entry.get("status_label", "Staggered")),
					"duration_rounds": max(1, int(entry.get("duration_rounds", 1))),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"initiative": -2})),
				}
				if entry.has("grants_base_cohesion"):
					normalized["grants_base_cohesion"] = bool(entry.get("grants_base_cohesion", true))
				if entry.has("held_objective_retaliation_multiplier"):
					normalized["held_objective_retaliation_multiplier"] = clampf(float(entry.get("held_objective_retaliation_multiplier", 1.0)), 1.0, 2.0)
					normalized["held_objective_types"] = _normalize_string_array(entry.get("held_objective_types", []))
				if entry.has("ally_retaliation_multiplier"):
					normalized["ally_retaliation_multiplier"] = clampf(float(entry.get("ally_retaliation_multiplier", 1.0)), 1.0, 1.25)
					normalized["ally_retaliation_min_tier"] = clampi(int(entry.get("ally_retaliation_min_tier", 1)), 1, 7)
					normalized["ally_retaliation_role"] = String(entry.get("ally_retaliation_role", "melee"))
					normalized["ally_retaliation_requires_defending"] = bool(entry.get("ally_retaliation_requires_defending", true))
					normalized["ally_retaliation_ai_defend_bonus"] = clampf(float(entry.get("ally_retaliation_ai_defend_bonus", 0.0)), 0.0, 4.0)
			"harry":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Harry")),
					"description": String(entry.get("description", "")),
					"status_id": String(entry.get("status_id", STATUS_HARRIED)),
					"status_label": String(entry.get("status_label", "Harried")),
					"duration_rounds": max(1, int(entry.get("duration_rounds", 2))),
					"uses_per_battle": max(0, int(entry.get("uses_per_battle", 0))),
					"target_min_tier": maxi(1, int(entry.get("target_min_tier", 1))),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"defense": -1, "initiative": -1})),
					"momentum_gain": max(0, int(entry.get("momentum_gain", 0))),
					"wounded_threshold_ratio": clampf(float(entry.get("wounded_threshold_ratio", 0.0)), 0.0, 1.0),
					"wounded_damage_multiplier": clampf(float(entry.get("wounded_damage_multiplier", 1.0)), 1.0, 2.0),
				}
				if entry.has("target_role"):
					normalized["target_role"] = String(entry.get("target_role", ""))
				if entry.has("ai_target_priority_bonus"):
					normalized["ai_target_priority_bonus"] = clampf(float(entry.get("ai_target_priority_bonus", 2.0)), 0.0, 4.0)
				if entry.has("min_adjacent_allies_to_target"):
					normalized["min_adjacent_allies_to_target"] = clampi(int(entry.get("min_adjacent_allies_to_target", 0)), 0, 3)
				if entry.has("support_ai_target_priority_bonus"):
					normalized["support_ai_target_priority_bonus"] = clampf(float(entry.get("support_ai_target_priority_bonus", 0.0)), 0.0, 4.0)
				if entry.has("support_blocked_summary"):
					normalized["support_blocked_summary"] = String(entry.get("support_blocked_summary", ""))
				if entry.has("support_ready_summary"):
					normalized["support_ready_summary"] = String(entry.get("support_ready_summary", ""))
			"obituary":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Obituary")),
					"description": String(entry.get("description", "")),
					"status_id": String(entry.get("status_id", "status_obituary_marked")),
					"status_label": String(entry.get("status_label", "Obituary-Marked")),
					"duration_rounds": max(1, int(entry.get("duration_rounds", 1))),
					"uses_per_battle": max(1, int(entry.get("uses_per_battle", 1))),
					"braced_target_min_tier": maxi(2, int(entry.get("braced_target_min_tier", 2))),
					"braced_ai_target_priority_bonus": clampf(float(entry.get("braced_ai_target_priority_bonus", 0.25)), 0.0, 10.0),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"cohesion": -1, "retaliation": -10})),
					"braced_modifiers": _normalize_ability_modifiers(entry.get("braced_modifiers", {"cohesion": -2, "retaliation": -20})),
				}
			"backstab":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Backstab")),
					"description": String(entry.get("description", "")),
					"damage_multiplier": clampf(float(entry.get("damage_multiplier", 1.0)), 1.0, 2.0),
					"momentum_gain": max(0, int(entry.get("momentum_gain", 0))),
					"status_ids": _normalize_string_array(entry.get("status_ids", [STATUS_HARRIED, STATUS_STAGGERED])),
					"health_threshold_ratio": clampf(float(entry.get("health_threshold_ratio", 0.0)), 0.0, 1.0),
					"threshold_damage_multiplier": clampf(float(entry.get("threshold_damage_multiplier", 1.0)), 1.0, 2.0),
				}
				if entry.has("primary_melee_only"):
					normalized["primary_melee_only"] = bool(entry.get("primary_melee_only", false))
			"fogwake":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Fogwake")),
					"description": String(entry.get("description", "")),
					"isolated_damage_multiplier": clampf(float(entry.get("isolated_damage_multiplier", 1.0)), 1.0, 2.0),
					"status_id": String(entry.get("status_id", "status_fogbound")),
					"status_label": String(entry.get("status_label", "Fogbound")),
					"duration_rounds": maxi(1, int(entry.get("duration_rounds", 1))),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"defense": -1, "initiative": -1, "cohesion": -1})),
					"ai_target_priority_bonus": clampf(float(entry.get("ai_target_priority_bonus", 0.0)), 0.0, 4.0),
				}
			"shielding":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Shielding")),
					"description": String(entry.get("description", "")),
					"cohesion_hold_bonus": max(0, int(entry.get("cohesion_hold_bonus", 0))),
					"ranged_damage_multiplier": clampf(float(entry.get("ranged_damage_multiplier", 1.0)), 0.25, 1.0),
					"engaged_damage_multiplier": clampf(float(entry.get("engaged_damage_multiplier", 1.0)), 1.0, 2.0),
					"harried_damage_multiplier": clampf(float(entry.get("harried_damage_multiplier", 1.0)), 1.0, 2.0),
					"ally_ranged_melee_damage_reduction_pct": clampi(int(entry.get("ally_ranged_melee_damage_reduction_pct", 0)), 0, 50),
					"linebreaker_screen_bonus_pct": clampi(int(entry.get("linebreaker_screen_bonus_pct", 0)), 0, 50),
					"ranged_damage_return_ratio": clampf(float(entry.get("ranged_damage_return_ratio", 0.0)), 0.0, 0.25),
				}
				if entry.has("payoff_status_ids"):
					normalized["payoff_status_ids"] = _normalize_string_array(entry.get("payoff_status_ids", []))
			"volley":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Volley")),
					"description": String(entry.get("description", "")),
					"damage_multiplier": clampf(float(entry.get("damage_multiplier", 1.0)), 1.0, 2.0),
					"min_distance": max(1, int(entry.get("min_distance", 1))),
					"status_ids": _normalize_string_array(entry.get("status_ids", [])),
					"status_damage_multiplier": clampf(float(entry.get("status_damage_multiplier", 1.0)), 1.0, 2.0),
					"ally_defending_multiplier": clampf(float(entry.get("ally_defending_multiplier", 1.0)), 1.0, 2.0),
				}
				if bool(entry.get("requires_protected_lane", false)):
					normalized["requires_protected_lane"] = true
					normalized["protected_lane_objective_types"] = _normalize_string_array(entry.get("protected_lane_objective_types", []))
			"formation_guard":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Formation Guard")),
					"description": String(entry.get("description", "")),
					"ally_ranged_damage_multiplier": clampf(float(entry.get("ally_ranged_damage_multiplier", 1.0)), 1.0, 2.0),
					"ally_ranged_initiative_bonus": max(0, int(entry.get("ally_ranged_initiative_bonus", 0))),
					"ally_cohesion_bonus": max(0, int(entry.get("ally_cohesion_bonus", 0))),
					"defending_cohesion_bonus": max(0, int(entry.get("defending_cohesion_bonus", 0))),
					"defending_initiative_bonus": max(0, int(entry.get("defending_initiative_bonus", 0))),
					"staggered_damage_multiplier": clampf(float(entry.get("staggered_damage_multiplier", 1.0)), 1.0, 2.0),
				}
			"resonance_relay":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Resonance Relay")),
					"description": String(entry.get("description", "")),
					"minimum_calibrated_stacks": clampi(int(entry.get("minimum_calibrated_stacks", 2)), 2, 6),
					"maximum_calibrated_stacks": clampi(int(entry.get("maximum_calibrated_stacks", 3)), 2, 6),
					"line_damage_per_calibrated_stack": clampf(float(entry.get("line_damage_per_calibrated_stack", 0.0)), 0.0, 0.1),
					"line_initiative_bonus": clampi(int(entry.get("line_initiative_bonus", 0)), 0, 3),
					"late_round_initiative_bonus": clampi(int(entry.get("late_round_initiative_bonus", 0)), 0, 3),
					"terrain_momentum_bonus": clampi(int(entry.get("terrain_momentum_bonus", 0)), 0, 3),
					"linked_unit_ids": _normalize_string_array(entry.get("linked_unit_ids", [])),
					"linked_initiative_bonus": clampi(int(entry.get("linked_initiative_bonus", 0)), 0, 3),
				}
			"solar_array_lane":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Solar Array Lanes")),
					"description": String(entry.get("description", "")),
					"incoming_melee_damage_multiplier": clampf(float(entry.get("incoming_melee_damage_multiplier", 1.0)), 0.75, 1.0),
					"linked_unit_ids": _normalize_string_array(entry.get("linked_unit_ids", [])),
				}
			"bloodrush":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Bloodrush")),
					"description": String(entry.get("description", "")),
					"clean_target_damage_multiplier": clampf(float(entry.get("clean_target_damage_multiplier", 1.0)), 0.25, 1.0),
					"wounded_threshold_ratio": clampf(float(entry.get("wounded_threshold_ratio", 0.0)), 0.0, 1.0),
					"wounded_damage_multiplier": clampf(float(entry.get("wounded_damage_multiplier", 1.0)), 1.0, 2.0),
					"status_ids": _normalize_string_array(entry.get("status_ids", [STATUS_HARRIED, STATUS_STAGGERED])),
					"status_damage_multiplier": clampf(float(entry.get("status_damage_multiplier", 1.0)), 1.0, 2.0),
					"wounded_initiative_bonus": max(0, int(entry.get("wounded_initiative_bonus", 0))),
					"max_initiative_bonus": max(0, int(entry.get("max_initiative_bonus", 0))),
					"momentum_gain": max(0, int(entry.get("momentum_gain", 0))),
					"kill_momentum_gain": max(0, int(entry.get("kill_momentum_gain", 0))),
					"late_round_initiative_bonus": max(0, int(entry.get("late_round_initiative_bonus", 0))),
				}
				# Keep optional contract fields absent from legacy Bloodrush entries so
				# normalized content preserves its authored schema and replay summaries.
				if entry.has("primary_melee_only"):
					normalized["primary_melee_only"] = bool(entry.get("primary_melee_only", false))
				if entry.has("isolated_damage_multiplier"):
					normalized["isolated_damage_multiplier"] = clampf(float(entry.get("isolated_damage_multiplier", 1.0)), 1.0, 1.25)
				if entry.has("isolated_ai_target_priority_bonus"):
					normalized["isolated_ai_target_priority_bonus"] = clampf(float(entry.get("isolated_ai_target_priority_bonus", 0.0)), 0.0, 5.0)
			"overheat":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Overheat")),
					"description": String(entry.get("description", "")),
					"burst_damage_multiplier": clampf(float(entry.get("burst_damage_multiplier", 1.0)), 1.0, 2.0),
					"overheated_damage_multiplier": clampf(float(entry.get("overheated_damage_multiplier", 1.0)), 0.25, 1.0),
					"status_id": String(entry.get("status_id", STATUS_OVERHEATED)),
					"status_label": String(entry.get("status_label", "Overheated")),
					"duration_rounds": max(1, int(entry.get("duration_rounds", 2))),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"defense": -2, "initiative": -2})),
				}
			"pressure_artillery":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Pressure Artillery")),
					"description": String(entry.get("description", "")),
					"cluster_range": clampi(int(entry.get("cluster_range", 1)), 1, 2),
					"secondary_damage_per_unit": clampi(int(entry.get("secondary_damage_per_unit", 1)), 1, 4),
					"max_secondary_damage": clampi(int(entry.get("max_secondary_damage", 1)), 1, 30),
					"max_secondary_targets": 1,
					"status_id": String(entry.get("status_id", STATUS_OVERHEATED)),
					"status_label": String(entry.get("status_label", "Overheated")),
					"duration_rounds": clampi(int(entry.get("duration_rounds", 2)), 1, 3),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"initiative": -1})),
					"ai_heat_score_penalty": clampf(float(entry.get("ai_heat_score_penalty", 0.5)), 0.0, 4.0),
				}
			"counter_ambush_flare":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Counter-Ambush Flare")),
					"description": String(entry.get("description", "")),
					"countered_ability_ids": _normalize_string_array(entry.get("countered_ability_ids", ["backstab", "fogwake"])),
					"ambush_bonus_retention": clampf(float(entry.get("ambush_bonus_retention", 0.0)), 0.0, 1.0),
					"blocks_ambush_status": bool(entry.get("blocks_ambush_status", true)),
					"revealed_status_id": String(entry.get("revealed_status_id", "status_flare_revealed")),
					"revealed_status_label": String(entry.get("revealed_status_label", "Flare-Revealed")),
					"revealed_duration_rounds": clampi(int(entry.get("revealed_duration_rounds", 1)), 1, 2),
					"revealed_ability_ids": _normalize_string_array(entry.get("revealed_ability_ids", ["fogwake"])),
					"revealed_modifiers": _normalize_ability_modifiers(entry.get("revealed_modifiers", {"defense": -1, "initiative": -1})),
				}
			"sporeglass_mend":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Mending Fire")),
					"description": String(entry.get("description", "")),
					"health_per_mender": clampi(int(entry.get("health_per_mender", 1)), 1, 6),
					"max_health_per_attack": clampi(int(entry.get("max_health_per_attack", 1)), 1, 20),
				}
			"foundry_aura":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Foundry Aura")),
					"description": String(entry.get("description", "")),
					"ally_defense_bonus": clampi(int(entry.get("ally_defense_bonus", 0)), 0, 3),
					"hardening_requires_overheated": bool(entry.get("hardening_requires_overheated", true)),
					"round_repair_pct": clampf(float(entry.get("round_repair_pct", 0.0)), 0.0, 0.1),
					"overheated_repair_bonus_pct": clampf(float(entry.get("overheated_repair_bonus_pct", 0.0)), 0.0, 0.1),
					"ai_target_priority_bonus": clampf(float(entry.get("ai_target_priority_bonus", 0.0)), 0.0, 5.0),
				}
			"bramble_ground":
				# Immutable authored content owns this conditional role so inactive
				# bramble metadata cannot perturb deterministic battle RNG state.
				continue
			"fog_screen":
				# Fog screens are resolved from immutable authored content so their
				# inactive metadata cannot perturb deterministic battle RNG state.
				continue
			"readiness_writ":
				# Readiness writs are resolved from immutable authored content so their
				# inactive metadata cannot perturb deterministic battle RNG state.
				continue
			_:
				continue
		abilities.append(normalized)
		seen[ability_id] = true
	return abilities

static func _normalize_ability_modifiers(value: Variant) -> Dictionary:
	return BattleEngine.native(&"BattleRules._normalize_ability_modifiers", [value])

static func _normalize_string_array(value: Variant) -> Array:
	var normalized = []
	if value is Array:
		for entry in value:
			var text = String(entry)
			if text != "" and text not in normalized:
				normalized.append(text)
	return normalized

static func _stack_ability_summary(stack: Dictionary) -> String:
	var names = []
	for ability in stack.get("abilities", []):
		if ability is Dictionary:
			var name = String(ability.get("name", ability.get("id", "")))
			if name != "":
				names.append(name)
	var bramble_ground := _bramble_ground_ability(stack)
	var bramble_name := String(bramble_ground.get("name", ""))
	if bramble_name != "" and bramble_name not in names:
		names.append(bramble_name)
	var fog_screen := _fog_screen_ability(stack)
	var fog_screen_name := String(fog_screen.get("name", ""))
	if fog_screen_name != "" and fog_screen_name not in names:
		names.append(fog_screen_name)
	var readiness_writ := _readiness_writ_ability(stack)
	var readiness_writ_name := String(readiness_writ.get("name", ""))
	if readiness_writ_name != "" and readiness_writ_name not in names:
		names.append(readiness_writ_name)
	return ", ".join(names)

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
	if not (context is Dictionary):
		return "Field engagement"
	if _has_delivery_context(context):
		var target_label := String(context.get("delivery_target_label", "the front"))
		if String(context.get("type", "")) == "town_defense":
			return "Relief defense at %s" % (target_label if target_label != "" else "the walls")
		return "Convoy clash near %s" % (target_label if target_label != "" else "the front")
	if String(context.get("type", "")) == "hero_intercept":
		var hero_name := String(
			HeroCommandRulesScript.hero_by_id(session, String(context.get("target_hero_id", ""))).get("name", "the road")
		)
		return "Interception near %s" % hero_name
	if _is_town_assault_context(context):
		var assault_town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
		match String(context.get("town_role", "frontier")):
			"capital":
				return "Capital assault at %s" % (assault_town_name if assault_town_name != "" else "the walls")
			"stronghold":
				return "Stronghold assault at %s" % (assault_town_name if assault_town_name != "" else "the walls")
			_:
				return "Town assault at %s" % (assault_town_name if assault_town_name != "" else "the walls")
	if String(context.get("type", "")) != "town_defense":
		return "Field engagement"
	var town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
	match String(context.get("town_role", "frontier")):
		"capital":
			return "Capital defense at %s" % (town_name if town_name != "" else "the walls")
		"stronghold":
			return "Stronghold defense at %s" % (town_name if town_name != "" else "the walls")
		_:
			return "Town defense at %s" % (town_name if town_name != "" else "the walls")

static func _battlefield_identity_summary(battle: Dictionary) -> String:
	var parts = []
	if _has_delivery_context(battle.get("context", {})):
		parts.append("the fight is sitting on a live reinforcement route")
	if _battle_has_tag(battle, "fortress_lane"):
		parts.append("fortress lanes compress the approach")
	if _battle_has_tag(battle, "battery_nest"):
		parts.append("battery nests punish long approaches")
	if _battle_has_tag(battle, "wall_pressure"):
		parts.append("wall pressure favors late breach fighting")
	if _battle_has_tag(battle, "reserve_wave"):
		parts.append("reserve waves matter after the opening exchanges")
	var terrain_effect = _terrain_effect_brief(battle)
	if terrain_effect != "":
		parts.append(terrain_effect)
	var objective_brief = _field_objective_status_brief(battle)
	if objective_brief != "":
		parts.append(objective_brief.to_lower())
	if parts.is_empty() and String(battle.get("context", {}).get("battlefront_summary", "")) != "":
		return String(battle.get("context", {}).get("battlefront_summary", ""))
	return ", ".join(parts)

static func _distance_label(distance: int) -> String:
	match max(0, distance):
		0:
			return "Lines engaged"
		1:
			return "Closing distance"
		_:
			return "Long approach"

static func _side_label(side: String) -> String:
	return BattleEngine.native(&"BattleRules._side_label", [side])

static func _commander_state_for_side(battle: Dictionary, side: String) -> Dictionary:
	if side == "enemy":
		return battle.get("enemy_hero", {})
	return battle.get("player_commander_state", {})

static func _commander_role_label(battle: Dictionary, side: String) -> String:
	if side == "enemy":
		return "Enemy commander" if not _commander_state_for_side(battle, side).is_empty() else "Uncommanded host"
	var source = battle.get("player_commander_source", {})
	match String(source.get("type", "")):
		"active_hero":
			return "Field commander"
		"town_hero":
			return "Town defender"
		"town_captain":
			return "Town captain"
		_:
			return "Commander"

static func _pressure_brief(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No pressure data."
	var battle = session.battle
	var objective_pressure = _field_objective_pressure_brief(battle)
	if objective_pressure != "":
		return objective_pressure
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	var player_health = max(1, int(player_totals.get("health", 0)))
	var enemy_health = max(1, int(enemy_totals.get("health", 0)))
	var rounds_remaining = max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1)
	if _side_controls_field_objective_type(battle, "enemy", "cover_line") and _side_controls_field_objective_type(battle, "enemy", "lane_battery") and int(battle.get("distance", 1)) > 0:
		return "Enemy guns are firing from cover and screening their commander."
	if _side_controls_field_objective_type(battle, "enemy", "cover_line") and int(battle.get("distance", 1)) > 0:
		return "Enemy cover lines are still screening the approach."
	if _side_controls_field_objective_type(battle, "player", "cover_line") and int(battle.get("distance", 1)) > 0:
		return "Friendly cover is blunting the opening volleys."
	if _side_controls_field_objective_type(battle, "enemy", "obstruction_line") and int(battle.get("distance", 1)) > 0:
		return "Enemy obstructions can still hold weaker advances off the line."
	if _side_controls_field_objective_type(battle, "player", "obstruction_line") and int(battle.get("distance", 1)) > 0:
		return "Friendly hands now own the choke and can force the enemy to breach it."
	if _battle_has_tag(battle, "battery_nest") and int(battle.get("round", 1)) <= 2 and int(battle.get("distance", 1)) > 0:
		return "Battery lanes are still punishing the approach."
	if _battle_has_tag(battle, "fortress_lane") and int(battle.get("round", 1)) <= 2:
		return "Fortress lanes are compressing the assault into a kill zone."
	if _reserve_wave_is_active_for_side(battle, _capital_front_anchor_side(battle)):
		return "Reserve companies are reaching the line and changing the exchange."
	if _battle_has_tag(battle, "wall_pressure") and int(battle.get("round", 1)) >= 3:
		return "The breach is widening; late melee exchanges will snowball fast."
	if _is_town_defense_context(battle.get("context", {})) and enemy_health > player_health:
		return "The walls are under strain; a collapse here costs the town."
	if _is_town_assault_context(battle.get("context", {})) and enemy_health >= player_health:
		return "The breach is stalling; the town stays hostile unless the wall line breaks."
	if rounds_remaining <= 2:
		return "The clock is tightening; one more slow round risks stalemate."
	if enemy_health <= int(round(float(player_health) * 0.65)):
		return "The enemy line is wavering."
	if player_health <= int(round(float(enemy_health) * 0.65)):
		return "The friendly line is under heavy pressure."
	if int(battle.get("round", 1)) >= 3:
		var player_doctrine = _side_doctrine_summary(battle, "player")
		var enemy_doctrine = _side_doctrine_summary(battle, "enemy")
		if player_doctrine != enemy_doctrine:
			return "%s versus %s is defining the late exchanges." % [player_doctrine, enemy_doctrine]
	return "The exchange is still balanced."

static func _engagement_preview(active_stack: Dictionary, target: Dictionary, battle: Dictionary) -> String:
	if active_stack.is_empty() or target.is_empty():
		return "No engagement forecast."
	if String(active_stack.get("side", "")) == String(target.get("side", "")):
		return "Friendly stack selected."
	if String(active_stack.get("side", "")) == "player":
		var click_intent := board_click_attack_intent_for_target(battle, String(target.get("battle_id", "")))
		var action_label := String(click_intent.get("label", ""))
		if action_label != "":
			return "Board click will %s %s now." % [action_label, _stack_label(target)]
		if not _legal_attack_target_ids_for_active_stack(battle).is_empty():
			return "%s is blocked from this hex; click a highlighted enemy to attack, or click a move hex to reposition." % _stack_label(target)
		return "Movement is needed before %s can be reached." % _stack_label(target)
	return "%s is threatening %s." % [_stack_label(active_stack), _stack_label(target)]

static func _stack_focus_summary(stack: Dictionary, battle: Dictionary, is_active: bool) -> String:
	if stack.is_empty():
		return "No stack is selected."
	var side = String(stack.get("side", ""))
	var comparison_stack := get_selected_target(battle) if is_active else get_active_stack(battle)
	var lines = [
		"%s [%s]%s" % [
			_stack_label(stack),
			_side_label(side),
			" | Acting now" if is_active else "",
		],
		OverworldRulesScript.describe_stack_inspection_line(stack, {"include_name": false}),
		"Dmg %d-%d | Speed %d" % [
			int(stack.get("min_damage", 1)),
			int(stack.get("max_damage", 1)),
			int(stack.get("speed", 1)),
		],
		"Attack %d | Defense %d | Initiative %d" % [
			_stack_attack_total(stack, battle),
			_stack_defense_total(stack, battle),
			_stack_initiative_total(stack, battle),
		],
		"Cohesion %d | Momentum %d%s" % [
			_stack_cohesion_total(stack, battle),
			_stack_momentum_total(stack, battle),
			" | Isolated" if _stack_is_isolated(battle, stack) else "",
		],
	]
	if bool(stack.get("ranged", false)):
		lines.append("Ranged pressure | Shots %d" % int(stack.get("shots_remaining", 0)))
	else:
		lines.append("Melee pressure | Retaliations %d/%d" % [
			int(stack.get("retaliations_left", 0)),
			int(stack.get("retaliations", 0)),
		])
	if bool(stack.get("defending", false)):
		lines.append("Stance: Defending")
	var effect_summary = SpellRulesScript.effect_summary(stack, battle)
	lines.append("Effects: %s" % (effect_summary if effect_summary != "" else "none"))
	var town_defense := TownBattle.summary(battle, stack)
	if town_defense != "": lines.append("Town defense: " + town_defense)
	lines.append(_stack_status_pressure_line(stack, battle))
	var ability_summary = _stack_ability_summary(stack)
	if ability_summary != "":
		lines.append("Abilities: %s" % ability_summary)
	lines.append(_active_ability_role_line(stack, battle, comparison_stack))
	if is_active:
		lines.append(_target_range_readiness_line(stack, comparison_stack, battle))
	var objective_summary = _field_objective_focus_line(battle, side, stack)
	if objective_summary != "":
		lines.append(objective_summary)
	return "\n".join(lines)

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

static func _cohesion_base_for_unit(unit: Dictionary) -> int:
	var base = 5 + max(0, int(unit.get("tier", 1)) - 1)
	if not bool(unit.get("ranged", false)):
		base += 1
	for ability in unit.get("abilities", []):
		if not (ability is Dictionary):
			continue
		var ability_id = String(ability.get("id", ""))
		if (
			(ability_id == "brace" and bool(ability.get("grants_base_cohesion", true)))
			or ability_id == "formation_guard"
			or (ability_id == "shielding" and int(ability.get("cohesion_hold_bonus", 0)) > 0)
		):
			base += 1
			break
	if bool(unit.get("ranged", false)) and int(unit.get("hp", 1)) <= 6:
		base -= 1
	return clamp(base, 4, 8)

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

static func _allied_ranged_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("ranged", false)):
			total += 1
	return total

static func _side_has_role_mix(battle: Dictionary, side: String) -> bool:
	return BattleEngine.native(&"BattleRules._side_has_role_mix", [battle, side])

static func _enemy_wounded_count(battle: Dictionary, side: String) -> int:
	return BattleEngine.native(&"BattleRules._enemy_wounded_count", [battle, side])

static func _side_doctrine_summary(battle: Dictionary, side: String) -> String:
	var faction_id = _side_faction_id(battle, side)
	match faction_id:
		"faction_embercourt":
			for stack in _alive_stacks_for_side(battle, side):
				if bool(stack.get("defending", false)) and not _charter_retaliation_aura_context(stack, battle).is_empty():
					return "The Charter Colossus is magnifying the compact line's retaliation"
			if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side({"side": side}, battle):
				if _reserve_wave_is_active_for_side(battle, side):
					return "Fortress lanes are feeding reserve columns into the pike line"
				return "Fortress lanes are locking the assault into disciplined pike fire"
			if _side_has_ability(battle, side, "formation_guard") and _side_defending_count(battle, side) > 0 and _side_has_role_mix(battle, side):
				return "Pike screens are feeding lantern volleys"
			if _side_has_ability(battle, side, "formation_guard") and _side_defending_count(battle, side) > 0:
				return "Pikewards are locking the firing line"
			if int(battle.get("round", 1)) >= 3 and _side_has_role_mix(battle, side):
				return "Formation fire is tightening the line"
			if _side_defending_count(battle, side) > 0:
				return "Shielded volleys are covering the line"
			return "The line is still forming"
		"faction_mireclaw":
			if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side({"side": side}, battle) and int(battle.get("round", 1)) >= 3:
				return "Breach packs are climbing over the line"
			if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side({"side": side}, battle):
				return "Reserve packs are flooding the breach behind the first wave"
			if _side_has_ability(battle, side, "bloodrush") and _enemy_wounded_count(battle, side) > 0 and int(battle.get("round", 1)) >= 3:
				return "Rippers are driving the collapse"
			if _enemy_wounded_count(battle, side) > 0 and int(battle.get("round", 1)) >= 3:
				return "Blood-rush finishers are cresting"
			if _enemy_wounded_count(battle, side) > 0:
				return "The pack is scenting weakness"
			return "The pack is probing for the first break"
		"faction_sunvault":
			var positive_effect_count = _side_positive_effect_count(battle, side)
			var resonance_relay := _side_resonance_relay(battle, side)
			if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side({"side": side}, battle):
				if _reserve_wave_is_active_for_side(battle, side):
					return "Battery nests are rotating fresh arrays into the firing line"
				return "Battery nests are turning the approach into a relay kill lane"
			if not resonance_relay.is_empty() and positive_effect_count >= 3 and _battle_has_any_tags(battle, ["elevated_fire", "fortified_line"]):
				return "Resonant arrays are firing in sequence"
			if not resonance_relay.is_empty() and positive_effect_count >= int(resonance_relay.get("minimum_calibrated_stacks", 2)):
				return "Relay chants are syncing the line"
			if positive_effect_count >= 2:
				return "Separate calibrations are waiting for a living relay"
			if not resonance_relay.is_empty() and positive_effect_count >= 1:
				return "The relay is waiting for a second calibrated stack"
			if positive_effect_count >= 1:
				return "A resonant array is coming online"
			return "The array is still gathering signal"
		"faction_thornwake":
			if _battle_has_any_tags(battle, ["chokepoint", "ambush_cover"]) and _side_defending_count(battle, side) > 0:
				return "Rooted lanes are turning the fight into a slow bramble grind"
			if _side_has_ability(battle, side, "formation_guard"):
				return "Graft leaders are holding the regrowth line together"
			if int(battle.get("round", 1)) >= 4:
				return "The battlefield is starting to root around the fight"
			return "Seed carriers are looking for ground to claim"
		"faction_brasshollow":
			if _battle_has_any_tags(battle, ["fortress_lane", "wall_pressure"]) and _side_has_ability(battle, side, "shielding"):
				return "Foundry armor is turning the lane into a siege stage"
			if _side_has_ability(battle, side, "volley"):
				return "Boiler crews are setting pressure shots behind the line"
			if int(battle.get("round", 1)) >= 3:
				return "Heat and contract pressure are building"
			return "The engines are still coming up to pressure"
		"faction_veilmourn":
			if _battle_has_any_tags(battle, ["fog_bank", "ambush_cover"]) and _side_has_ability(battle, side, "backstab"):
				return "Fog lanes are opening routes into the enemy back"
			if _enemy_wounded_count(battle, side) > 0:
				return "Marked victims are losing their clean exits"
			if _side_has_ability(battle, side, "harry"):
				return "Lantern marks are testing the enemy formation"
			return "The fog fleet is measuring the first hidden route"
		_:
			return "No doctrine is asserting itself"

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

static func _field_objective_progress_text(objective: Dictionary) -> String:
	var controller = String(objective.get("control_side", "neutral"))
	var progress_side = String(objective.get("progress_side", ""))
	var progress_value = int(objective.get("progress_value", 0))
	var threshold = max(1, int(objective.get("capture_threshold", 2)))
	if controller in ["player", "enemy"]:
		if progress_side != "" and progress_side != controller and progress_value > 0:
			return "%s-held, %s pressure %d/%d" % [
				_side_label(controller),
				_side_label(progress_side),
				progress_value,
				threshold,
			]
		return "%s-held" % _side_label(controller)
	if progress_side != "" and progress_value > 0:
		return "contested toward %s %d/%d" % [_side_label(progress_side), progress_value, threshold]
	return "unclaimed"

static func _field_objective_short_status(objective: Dictionary) -> String:
	return "%s %s" % [_field_objective_label(objective), _field_objective_progress_text(objective)]

static func _field_objective_status_brief(battle: Dictionary) -> String:
	var objectives = _field_objectives(battle)
	if objectives.is_empty():
		return ""
	var primary = objectives[0]
	if primary is Dictionary:
		return _field_objective_short_status(primary)
	return ""

static func _field_objective_pressure_summary(battle: Dictionary) -> String:
	var parts = []
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		parts.append("%s | %s" % [_field_objective_short_status(objective), String(objective.get("summary", ""))])
		if parts.size() >= 2:
			break
	return " ; ".join(parts)

static func _field_objective_pressure_brief(battle: Dictionary) -> String:
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var objective_type = String(objective.get("type", ""))
		var controller = String(objective.get("control_side", "neutral"))
		var urgency_round = int(objective.get("urgency_round", 2))
		match objective_type:
			"lane_battery":
				if controller == "enemy" and int(battle.get("distance", 1)) > 0:
					return "%s still controls the firing lane." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("distance", 1)) > 0:
					return "%s now favors the friendly guns." % _field_objective_label(objective)
			"cover_line":
				if controller == "enemy" and int(battle.get("distance", 1)) > 0:
					return "%s is still screening the enemy guns and commander." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("distance", 1)) > 0:
					return "Friendly cover is blunting the opening volleys. %s now shelters the friendly firing line." % _field_objective_label(objective)
			"obstruction_line":
				if controller == "enemy" and int(battle.get("distance", 1)) > 0:
					return "%s is still compressing the approach." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("distance", 1)) > 0:
					return "%s has turned the choke back on the enemy push." % _field_objective_label(objective)
			"ritual_pylon":
				if controller == "enemy" and int(battle.get("round", 1)) >= urgency_round:
					return "%s is grinding the line's cohesion." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("round", 1)) >= urgency_round:
					return "%s now breaks the enemy rhythm." % _field_objective_label(objective)
			"supply_post":
				if controller == "enemy" and _battle_has_tag(battle, "reserve_wave"):
					return "%s is feeding enemy reserves to the front." % _field_objective_label(objective)
				if controller == "player" and _battle_has_tag(battle, "reserve_wave"):
					return "%s is delaying enemy reserve timing." % _field_objective_label(objective)
			"signal_beacon":
				if controller == "enemy":
					return "%s is keeping enemy command ahead of the exchange." % _field_objective_label(objective)
				if controller == "player":
					return "%s is stabilizing friendly command tempo." % _field_objective_label(objective)
			"breach_point":
				if controller in ["player", "enemy"] and int(battle.get("round", 1)) >= urgency_round:
					return "%s is deciding the melee collapse." % _field_objective_label(objective)
			"hazard_zone":
				if controller == "enemy" and int(battle.get("round", 1)) >= urgency_round:
					return "%s is still punishing the approach." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("round", 1)) >= urgency_round:
					return "%s has been turned back on the enemy line." % _field_objective_label(objective)
	return ""

static func _field_objective_urgency_summary(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var parts = []
	var urgent = []
	for objective in _field_objectives(battle):
		if objective is Dictionary and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
			urgent.append(_field_objective_short_status(objective))
	if urgent.is_empty():
		var objective_brief = _field_objective_status_brief(battle)
		if objective_brief != "":
			parts.append(objective_brief)
	else:
		parts.append("Active pressure %s" % "; ".join(urgent.slice(0, min(2, urgent.size()))))
	var scenario_line = _tactical_objective_line(session, battle, ContentService.get_scenario_readonly(session.scenario_id)).trim_prefix("Battle aim: ").strip_edges()
	if scenario_line != "":
		parts.append(scenario_line)
	var rounds_remaining = max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1)
	if rounds_remaining <= 2:
		parts.append("%d round%s remain before stalemate" % [rounds_remaining, "" if rounds_remaining == 1 else "s"])
	if not _battle_retreat_allowed(battle):
		parts.append("retreat locked")
	return " | ".join(parts)

static func _field_objective_focus_line(battle: Dictionary, side: String, stack: Dictionary = {}) -> String:
	if side == "":
		return ""
	var preferred_ranged = stack is Dictionary and bool(stack.get("ranged", false))
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var controller = String(objective.get("control_side", "neutral"))
		var objective_type = String(objective.get("type", ""))
		if controller == side:
			match objective_type:
				"lane_battery":
					if preferred_ranged:
						return "Objective: %s supports this firing line." % _field_objective_label(objective)
				"cover_line":
					return "Objective: %s is screening this side from hostile fire." % _field_objective_label(objective)
				"obstruction_line":
					return "Objective: %s is choking the lane in this side's favor." % _field_objective_label(objective)
				"supply_post":
					return "Objective: %s is keeping this side steadier." % _field_objective_label(objective)
				"signal_beacon":
					return "Objective: %s is guiding command tempo here." % _field_objective_label(objective)
				"breach_point":
					return "Objective: %s currently favors this side's melee." % _field_objective_label(objective)
				"ritual_pylon", "hazard_zone":
					return "Objective: %s currently pressures the enemy line." % _field_objective_label(objective)
		elif controller in ["player", "enemy"]:
			match objective_type:
				"lane_battery":
					if preferred_ranged or int(battle.get("distance", 1)) > 0:
						return "Objective: %s is still working against this side." % _field_objective_label(objective)
				"cover_line":
					return "Objective: %s is still screening the hostile line." % _field_objective_label(objective)
				"obstruction_line":
					return "Objective: %s is still clogging this push." % _field_objective_label(objective)
				"ritual_pylon", "hazard_zone":
					return "Objective: %s is dragging this side under pressure." % _field_objective_label(objective)
				"supply_post", "signal_beacon", "breach_point":
					return "Objective: %s is still in hostile hands." % _field_objective_label(objective)
	return ""

static func _side_controls_field_objective_type(battle: Dictionary, side: String, objective_type: String) -> bool:
	return BattleEngine.native(&"BattleRules._side_controls_field_objective_type", [battle, side, objective_type])

static func _reserve_wave_is_active_for_side(battle: Dictionary, side: String) -> bool:
	return BattleEngine.native(&"BattleRules._reserve_wave_is_active_for_side", [battle, side])

static func _terrain_effect_brief(battle: Dictionary) -> String:
	if battle.is_empty():
		return ""
	var parts = []
	var distance = int(battle.get("distance", 1))
	if distance > 0:
		if _side_controls_field_objective_type(battle, "enemy", "cover_line"):
			parts.append("enemy cover still screens ranged stacks and command")
		elif _side_controls_field_objective_type(battle, "player", "cover_line"):
			parts.append("friendly cover is screening the firing line")
		if _side_controls_field_objective_type(battle, "enemy", "obstruction_line"):
			parts.append("enemy obstruction can hold weak advances at %s" % _distance_label(distance).to_lower())
		elif _side_controls_field_objective_type(battle, "player", "obstruction_line"):
			parts.append("friendly obstruction forces the enemy to breach the choke")
	return " | ".join(parts)

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

static func _latest_animation_event(battle: Dictionary) -> Dictionary:
	var events := animation_event_queue(battle)
	var latest := {}
	var latest_serial := -1
	for event in events:
		if not (event is Dictionary):
			continue
		var serial := int(event.get("serial", 0))
		if latest.is_empty() or serial >= latest_serial:
			latest = event
			latest_serial = serial
	return latest.duplicate(true) if latest is Dictionary else {}

static func _animation_event_action_text(
	event_id: String,
	actor_label: String,
	source_label: String,
	target_label: String,
	event: Dictionary
) -> String:
	match event_id:
		"battle_unit_move":
			var to_q := int(event.get("to_q", -1))
			var to_r := int(event.get("to_r", -1))
			if to_q >= 0 and to_r >= 0:
				return "%s moves to %d,%d." % [actor_label, to_q, to_r]
			return "%s moves." % actor_label
		"battle_unit_melee_attack":
			return "%s strikes %s." % [actor_label, target_label if target_label != "" else "the target"]
		"battle_unit_ranged_attack":
			return "%s fires on %s." % [actor_label, target_label if target_label != "" else "the target"]
		"battle_unit_hit":
			if source_label != "":
				return "%s is hit by %s." % [actor_label, source_label]
			return "%s is hit." % actor_label
		"battle_unit_death":
			return "%s falls." % actor_label
		"battle_unit_cast":
			var spell_id := String(event.get("spell_id", "")).strip_edges()
			if spell_id != "":
				return "%s casts %s." % [actor_label, spell_id.capitalize()]
			return "%s casts." % actor_label
		"battle_status_applied":
			if source_label != "":
				return "%s is affected by %s." % [actor_label, source_label]
			return "%s gains a status effect." % actor_label
		"battle_status_expired":
			return "%s has a status cleared." % actor_label
		"battle_unit_defend":
			return "%s braces." % actor_label
		"battle_unit_wait":
			return "%s waits." % actor_label
		"battle_retaliation":
			return "%s retaliates against %s." % [actor_label, target_label if target_label != "" else "the attacker"]
		"battle_unit_retreat":
			return "%s retreats." % actor_label
		"battle_unit_surrender":
			return "%s surrenders." % actor_label
	return ""

static func _titleize_token(value: String) -> String:
	return BattleEngine.native_writing(&"BattleRules._titleize_token", [value])

static func _get_stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	return BattleEngine.native(&"BattleRules._get_stack_by_id", [battle, battle_id])

static func _stack_label(stack: Dictionary) -> String:
	return BattleEngine.native(&"BattleRules._stack_label", [stack])

static func _stack_summary_line(stack: Dictionary, battle: Dictionary, active_id: String, selected_id: String) -> String:
	var markers = []
	if String(stack.get("battle_id", "")) == active_id:
		markers.append("ACT")
	if String(stack.get("battle_id", "")) == selected_id:
		markers.append("TGT")
	var role_summary = (
		"Shots %d" % int(stack.get("shots_remaining", 0))
		if bool(stack.get("ranged", false))
		else "Retal %d/%d" % [int(stack.get("retaliations_left", 0)), int(stack.get("retaliations", 0))]
	)
	var ability_summary = _stack_ability_summary(stack)
	var ability_role = _active_ability_role_line(stack, battle, get_selected_target(battle)).trim_prefix("Role: ")
	var effect_summary = SpellRulesScript.effect_summary(stack, battle)
	var status_pressure = _stack_status_pressure_short(stack, battle)
	var stance = " | Defending" if bool(stack.get("defending", false)) else ""
	return "%s%s | Atk %d Def %d Init %d | %s%s%s%s" % [
		("[%s] " % ",".join(markers)) if not markers.is_empty() else "",
		OverworldRulesScript.describe_stack_inspection_line(stack),
		_stack_attack_total(stack, battle),
		_stack_defense_total(stack, battle),
		_stack_initiative_total(stack, battle),
		"%s | Coh %d Mom %d%s" % [
			role_summary,
			_stack_cohesion_total(stack, battle),
			_stack_momentum_total(stack, battle),
			" Iso" if _stack_is_isolated(battle, stack) else "",
		],
		stance,
		(" | Role %s" % ability_role) if ability_role != "" else ((" | %s" % ability_summary) if ability_summary != "" else ""),
		(" | Status %s" % status_pressure) if status_pressure != "" else ((" | %s" % effect_summary) if effect_summary != "" else ""),
	]
