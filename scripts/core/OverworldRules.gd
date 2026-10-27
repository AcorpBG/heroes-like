class_name OverworldRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const NativeTransit = preload("res://scripts/core/NativeTransitRules.gd")
const PlayerEliminationRulesScript = preload("res://scripts/core/PlayerEliminationRules.gd")
const Mines = preload("res://scripts/core/MineRules.gd")
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")
const VisitBuildings = preload("res://scripts/core/VisitBuildingRules.gd")
const WaterTravel = preload("res://scripts/core/WaterTravelRules.gd")
const GeneratedRewards = preload("res://scripts/persistence/GeneratedRewardRules.gd")
const GENERATED_TRANSIT_TRANSLATION_KEY := "generated_transit_translation_version"
const GENERATED_TRANSIT_TRANSLATION_VERSION := 2
# Portal trips per traveller, part of the random-exit roll (docs/portal-networks.md).
const NATIVE_TRANSIT_TRIPS_KEY := "native_transit_trips"
const ROUTE_LOCK_CHOICE_ID := "open_route"
## The steps of the active hero's route search, in the order it tries them:
## the overworld's, and the map view's own search (hero_route_path's `plain`).
const ROUTE_DIRECTIONS := [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]
const PLAIN_ROUTE_DIRECTIONS := [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]
# Troops a claimed site offered that did not fit the visiting hero's army; the
# hero may dismiss a stack to take them or leave them behind.
const PENDING_SITE_RECRUITS_KEY := "pending_site_recruits"
const CreatureDwellings = preload("res://scripts/core/CreatureDwellingRules.gd")

const FOG_KEY := "fog"
const VISIBLE_TILES_KEY := "visible_tiles"
const EXPLORED_TILES_KEY := "explored_tiles"
const TOWN_VISION_RADIUS := 8
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const DayEngine = preload("res://scripts/core/DayEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
const ACTIVE_TOWN_PLACEMENT_KEY := "active_town_placement_id"
const COMMAND_BRIEFING_KEY := "command_briefing"
const COMMAND_RISK_FORECAST_KEY := "command_risk_forecast"
const WEEKLY_GROWTH_INTERVAL := 7
const BUILDING_CATEGORIES := ["civic", "dwelling", "economy", "support", "magic"]
const LOGISTICS_SITE_FAMILIES := ["faction_outpost", "frontier_shrine"]
const LIVE_STOCKPILE_RESOURCE_KEYS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
## Common construction staples: bulk lots and automatic cost coverage sell them.
const NORMAL_MARKET_RESOURCE_KEYS := ["wood", "ore"]
## Every stockpile resource but gold trades at a town market: buy, sell or
## convert, rare resources included (owner decision, 2026-10-07).
const MARKET_RESOURCE_KEYS := ["wood", "ore", "aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]
## Gold value per unit at the market: rare resources are worth twice wood or
## ore. Computer players trade through the same quotes.
const MARKET_RESOURCE_VALUES := {"wood": 400, "ore": 400, "aetherglass": 800, "embergrain": 800, "peatwax": 800, "verdant_grafts": 800, "brass_scrip": 800, "memory_salt": 800}
const MARKET_BASE_BUY_CAP := 12
const MARKET_BASE_SELL_CAP := 16
const MARKET_RARE_BUY_CAP := 2
const MARKET_RARE_SELL_CAP := 3
const ENCOUNTER_ARMY_DETAIL_GROUP_LIMIT := 4

static var _normalized_read_scope_session_id := ""
static var _normalized_read_scope_depth := 0
static var _normalized_read_scope_cache: Dictionary = {}
# [town dictionary, content hash, content digest] seen in the current read scope.
static var _normalized_read_scope_town_digests: Array = []
static var _last_normalized_read_scope_cache_profile: Dictionary = {}
static var _runtime_normalized_signatures: Dictionary = {}
static var _active_town_visit_indexes: Dictionary = {}
# Pathing indexes live on the session object itself (metadata is never
# serialized). A save summary loaded from the same campaign run shares the
# persisted session_id, so keying these by id let it replace the live game's
# blocked-tile and spatial indexes.
const BLOCKED_TILE_INDEX_META := &"_overworld_blocked_tile_indexes"
const SPATIAL_LOOKUP_INDEX_META := &"_overworld_spatial_lookup_indexes"
const SPATIAL_LOOKUP_SIGNATURE_META := &"_overworld_spatial_lookup_signature"
const RESOLVED_LOOKUP_META := &"_overworld_resolved_encounter_lookup"
const BLOCKED_SCENERY_LAYERS_META := &"_overworld_blocked_scenery_layers"
const SPATIAL_RESOURCE_SECTIONS_META := &"_overworld_spatial_resource_sections"
# Stands for a key a resource node does not have in its spatial fingerprint;
# saved state is JSON and never holds a StringName.
const SPATIAL_FINGERPRINT_MISSING := &"_overworld_spatial_fingerprint_missing"
# Session meta, not saved. A caller that changes nothing between two end_turn
# calls (the AI match runner) sets SESSION_UNTOUCHED_BETWEEN_DAYS_META; end_turn
# then skips its opening normalize while the session is still as the previous
# end_turn's closing normalize left it, on the day CLOSING_NORMALIZE_DAY_META
# records.
const SESSION_UNTOUCHED_BETWEEN_DAYS_META := &"_overworld_session_untouched_between_days"
const CLOSING_NORMALIZE_DAY_META := &"_overworld_end_turn_closing_normalize_day"
static var _fog_read_scope_session_id := 0
static var _fog_read_scope_depth := 0
static var _fog_read_scope_frame := -1
static var _fog_read_scope_fog: Variant = null
static var _fog_read_scope_grids: Dictionary = {}
static var _terrain_passable_cache: Dictionary = {}
static var _terrain_passable_cache_revision := -1
static var _movement_rules_profile_active := false
static var _movement_rules_profile: Dictionary = {}
static var _pathing_debug_profile: Dictionary = {
	"capture_enabled": false,
	"blocked_index_rebuild_count": 0,
	"last_blocked_index_rebuild_usec": 0,
	"last_blocked_index_tile_count": 0,
	"last_blocked_index_session_id": "",
	"route_interaction_lookup_count": 0,
	"route_interaction_spatial_lookup_count": 0,
	"route_interaction_full_scan_count": 0,
	"town_placement_lookup_direct_index_count": 0,
	"town_placement_lookup_spatial_index_count": 0,
	"town_placement_lookup_full_scan_count": 0,
	"post_move_global_discovery_count": 0,
	"post_action_tile_context_scan_count": 0,
}

static func _enemy_turn_rules() -> Variant:
	return load("res://scripts/core/EnemyTurnRules.gd")

static func _battle_rules() -> Variant:
	return load("res://scripts/core/BattleRules.gd")

static func _run_enemy_turn_cycle(session: SessionStateStoreScript.SessionData) -> Dictionary:
	# end_turn evaluates the scenario right after, which normalizes the enemy
	# states and their commander rosters again.
	return _enemy_turn_rules().run_enemy_turn(session, false)

static func normalize_overworld_state(session: SessionStateStoreScript.SessionData) -> void:
	DayEngine.native_writing(&"OverworldRules.normalize_overworld_state", [session])

static func normalize_overworld_state_for_runtime(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules.normalize_overworld_state_for_runtime", [session])

static func is_runtime_session_normalized(session: SessionStateStoreScript.SessionData) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.is_runtime_session_normalized", [session])

static func mark_runtime_normalized_transition_state(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var session_id := String(session.session_id)
	if not _runtime_normalized_signatures.has(session_id):
		return
	_mark_runtime_normalized(session)

static func _mark_runtime_normalized(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules._mark_runtime_normalized", [session])

static func begin_normalized_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules.begin_normalized_read_scope", [session])

static func end_normalized_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules.end_normalized_read_scope", [session])

static func validation_last_normalized_read_scope_cache_profile() -> Dictionary:
	return HumanEngine.native(&"OverworldRules.validation_last_normalized_read_scope_cache_profile", [])

static func normalize_overworld_state_bridge(session) -> void:
	normalize_overworld_state(session)

static func validation_pathing_profile_snapshot() -> Dictionary:
	return HumanEngine.native(&"OverworldRules.validation_pathing_profile_snapshot", [])

static func validation_set_pathing_profile_capture_enabled(enabled: bool) -> void:
	HumanEngine.native_writing(&"OverworldRules.validation_set_pathing_profile_capture_enabled", [enabled])

static func refresh_fog_of_war(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules.refresh_fog_of_war", [session])

# Every owned town, player or AI, sees this far from its entrance.
static func town_vision_radius() -> int:
	return TOWN_VISION_RADIUS

static func is_tile_visible(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.is_tile_visible", [session, x, y, level])

static func is_tile_explored(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.is_tile_explored", [session, x, y, level])

static func fog_for_level(session: SessionStateStoreScript.SessionData, level: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.fog_for_level", [session, level])

## Opens a fog read scope for one presentation pass (a map layer redraw).
## Until the matching end call in the same frame, fog lookups for this session
## skip the readiness check and reuse each level's grids. The grids are live
## references, so in-place reveals still show; storing a new fog dictionary
## drops the cache, and a scope left open past its frame is ignored.
static func begin_fog_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var frame := Engine.get_process_frames()
	if _fog_read_scope_depth > 0 and _fog_read_scope_frame != frame:
		_fog_read_scope_depth = 0
	if _fog_read_scope_depth == 0:
		_fog_read_scope_session_id = session.get_instance_id()
		_fog_read_scope_frame = frame
		_fog_read_scope_fog = null
		_fog_read_scope_grids = {}
	if session.get_instance_id() == _fog_read_scope_session_id:
		_fog_read_scope_depth += 1

static func end_fog_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or _fog_read_scope_depth <= 0 or session.get_instance_id() != _fog_read_scope_session_id:
		return
	_fog_read_scope_depth -= 1
	if _fog_read_scope_depth == 0:
		_fog_read_scope_fog = null
		_fog_read_scope_grids = {}

static func _fog_grids_uncached(session: SessionStateStoreScript.SessionData, level: int) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._fog_grids_uncached", [session, level])

static func _store_level_fog(session: SessionStateStoreScript.SessionData, payload: Dictionary, level: int = -1) -> void:
	HumanEngine.native_writing(&"OverworldRules._store_level_fog", [session, payload, level])

static func describe_visibility(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_visibility", [session])

static func try_move(session: SessionStateStoreScript.SessionData, dx: int, dy: int) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.try_move", [session, dx, dy])

static func route_movement_preview(session: SessionStateStoreScript.SessionData, route_tiles: Variant, movement_budget: int = -1) -> Dictionary:
	return HumanEngine.native(&"OverworldRules.route_movement_preview", [session, route_tiles, movement_budget])

static func travel_native_passage(session: SessionStateStoreScript.SessionData, node: Dictionary, movement_cost: int = 1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.travel_native_passage", [session, node, movement_cost])

## "Azure Wayring": the network colour, then the portal's name.
static func native_portal_display_name(node: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules.native_portal_display_name", [node])

## Says what kind of portal this is, its network and where it can take you.
## Exits on tiles the player has not explored are counted but not located.
static func describe_native_portal(session: SessionStateStoreScript.SessionData, node: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_native_portal", [session, node])

static func active_linked_transit_edges(session: SessionStateStoreScript.SessionData, level: int = -1) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.active_linked_transit_edges", [session, level])

static func linked_transit_neighbors_from_edges(edges: Array, tile: Vector2i) -> Array:
	return HumanEngine.native(&"OverworldRules.linked_transit_neighbors_from_edges", [edges, tile])

static func active_linked_transit_signature(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.active_linked_transit_signature", [session])

static func try_move_along_route(session: SessionStateStoreScript.SessionData, route_tiles: Variant, movement_budget: int = -1, resolve_destination_interaction: bool = true) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.try_move_along_route", [session, route_tiles, movement_budget, resolve_destination_interaction])

static func execute_prevalidated_route(session: SessionStateStoreScript.SessionData, route_tiles: Variant, route_preview: Dictionary = {}, movement_budget: int = -1, destination_descriptor: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.execute_prevalidated_route", [session, route_tiles, route_preview, movement_budget, destination_descriptor])

static func end_turn(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return DayEngine.native_writing(&"OverworldRules.end_turn", [session])

## end_turn up to the AI turn: the closing normalize, the new day's economy
## and its messages.
static func _end_turn_open_day(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return DayEngine.native_writing(&"OverworldRules._end_turn_open_day", [session])

## end_turn after the AI turn: elimination, the action result, the closing
## normalize and the day's summaries.
static func _end_turn_close_day(session: SessionStateStoreScript.SessionData, opened: Dictionary, enemy_turn_result: Dictionary) -> Dictionary:
	return DayEngine.native_writing(&"OverworldRules._end_turn_close_day", [session, opened, enemy_turn_result])

static func collect_active_resource(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.collect_active_resource", [session])

static func choose_resource_reward(session: SessionStateStoreScript.SessionData, choice_id: String, expected_context: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.choose_resource_reward", [session, choice_id, expected_context])

static func _route_lock_prompt(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._route_lock_prompt", [session, node, site])

static func _resource_reward_choice_context(session: SessionStateStoreScript.SessionData, node: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._resource_reward_choice_context", [session, node])

## The artifacts a generated bank, tomb or casket holds, by HoMM3 class.
static func _resource_site_artifact_summary(site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_artifact_summary", [site])

## Up to three spell names, or how many spells there are.
static func _spell_list_text(names: Array) -> String:
	return HumanEngine.native(&"OverworldRules._spell_list_text", [names])

static func _resource_site_reward_summary(site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_reward_summary", [site])

static func _collect_resource_node_result(session: SessionStateStoreScript.SessionData, node_result: Dictionary, refresh_fog_after_action: bool = true, native_transit_cost: int = 1, reward_choice_id: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._collect_resource_node_result", [session, node_result, refresh_fog_after_action, native_transit_cost, reward_choice_id])

## Hires creatures at the dwelling the active hero is visiting. hires maps
## unit ids to counts; tier 1 creatures are free.
static func hire_from_dwelling(session: SessionStateStoreScript.SessionData, hires: Dictionary, expected_context: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.hire_from_dwelling", [session, hires, expected_context])

static func collect_active_artifact(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.collect_active_artifact", [session])

static func _collect_artifact_node_result(session: SessionStateStoreScript.SessionData, node_result: Dictionary, refresh_fog_after_action: bool = true) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._collect_artifact_node_result", [session, node_result, refresh_fog_after_action])

static func perform_context_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.perform_context_action", [session, action_id])

static func set_active_town_visit(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.set_active_town_visit", [session, placement_id])

static func clear_active_town_visit(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules.clear_active_town_visit", [session])

static func _resolve_post_move_interaction(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._resolve_post_move_interaction", [session])

static func capture_active_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.capture_active_town", [session])

static func transition_town_control(session: SessionStateStoreScript.SessionData, placement_id: String, new_owner: String, controlling_faction_id: String = "", source: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.transition_town_control", [session, placement_id, new_owner, controlling_faction_id, source])

static func describe_encounter_pressure(session: SessionStateStoreScript.SessionData, encounter: Dictionary, for_battle_prompt: bool = false) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_pressure", [session, encounter, for_battle_prompt])

static func describe_encounter_readability_surface(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_readability_surface", [session, encounter])

static func describe_encounter_compact_readability(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_compact_readability", [session, encounter])

static func describe_encounter_battle_cue(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_battle_cue", [session, encounter])

static func describe_encounter_guard_link_surface(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_guard_link_surface", [session, encounter])

static func describe_encounter_consequence_surface(session: SessionStateStoreScript.SessionData, encounter: Dictionary, compact: bool = false) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_consequence_surface", [session, encounter, compact])

static func build_in_active_town(session: SessionStateStoreScript.SessionData, building_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.build_in_active_town", [session, building_id])

static func recruit_in_active_town(session: SessionStateStoreScript.SessionData, unit_id: String, requested_count: int = -1, runtime_normalized: bool = false) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.recruit_in_active_town", [session, unit_id, requested_count, runtime_normalized])

static func cast_overworld_spell(session: SessionStateStoreScript.SessionData, spell_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.cast_overworld_spell", [session, spell_id])

static func perform_artifact_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.perform_artifact_action", [session, action_id])

static func get_active_context(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.get_active_context", [session])

static func _field_rendezvous_hero_at_tile(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._field_rendezvous_hero_at_tile", [session, tile])

static func get_active_encounter(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.get_active_encounter", [session])

static func guard_engagement_encounter_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.guard_engagement_encounter_at_tile", [session, x, y, level])

static func guard_engagement_approach_route(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.guard_engagement_approach_route", [session, encounter])

static func encounter_display_name(encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.encounter_display_name", [encounter])

static func is_encounter_resolved(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.is_encounter_resolved", [session, encounter])

static func encounter_key(encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.encounter_key", [encounter])

static func hero_position(session: SessionStateStoreScript.SessionData) -> Vector2i:
	return HumanEngine.native_writing(&"OverworldRules.hero_position", [session])

static func derive_map_size(session: SessionStateStoreScript.SessionData) -> Vector2i:
	return HumanEngine.native_writing(&"OverworldRules.derive_map_size", [session])

static func overworld_object_placement_pathing_surface(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.overworld_object_placement_pathing_surface", [session, placement_id])

static func blocking_object_feedback_surface_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	return HumanEngine.native(&"OverworldRules.blocking_object_feedback_surface_at_tile", [session, x, y])

static func tile_is_blocked(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.tile_is_blocked", [session, x, y, level])

static func terrain_id_is_passable(terrain_id: String) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.terrain_id_is_passable", [terrain_id])

static func tile_has_route_interaction(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1, exact_target_only: bool = false) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.tile_has_route_interaction", [session, x, y, level, exact_target_only])

static func tile_is_actionable_route_destination(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.tile_is_actionable_route_destination", [session, x, y, level])

## Route blocking for the active hero. A walking hero treats water as blocked;
## a sailing hero moves only on open water (WaterTravelRules).
static func hero_route_tile_blocked(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.hero_route_tile_blocked", [session, x, y, level])

## Where the active hero's route may end on a blocked tile. A walking hero may
## end on a free boat to board it, never on other water. A sailing hero may end
## on a water interaction, or on open shore or a shore interaction to step off.
static func hero_route_destination(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.hero_route_destination", [session, x, y, level])

## The active hero's route from start to goal, both included, or [] when there
## is none: the first route a breadth-first search finds, stepping in the eight
## directions without cutting a blocked corner, through tiles the hero may
## cross that hold no interaction, and along the active linked transit edges.
## A blocked goal ends a route when it is a route destination (a free boat to
## board, a site on an object body). `plain` is the map view's own search for
## a screen without the overworld's route: no blocked goal ends a route, no
## linked transit edge is crossed, and the steps go in its order.
static func hero_route_path(session: SessionStateStoreScript.SessionData, start: Vector2i, goal: Vector2i, level: int = -1, plain: bool = false) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.hero_route_path", [session, start, goal, level, plain])

## Route lengths in tiles (start included) to several goals from one
## breadth-first flood, by goal. Each length equals hero_route_path(session,
## start, goal).size(): a goal is recorded where that search would first reach
## it, while the flood itself only crosses tiles an ordinary route may cross,
## so no goal changes the path to another. Unreachable goals are left out.
static func hero_route_path_lengths(session: SessionStateStoreScript.SessionData, start: Vector2i, goals: Array) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.hero_route_path_lengths", [session, start, goals])

static func resource_node_interaction_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.resource_node_interaction_at_tile", [session, x, y, level])

static func tile_step_cuts_blocked_corner(session: SessionStateStoreScript.SessionData, from_tile: Vector2i, to_tile: Vector2i, level: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.tile_step_cuts_blocked_corner", [session, from_tile, to_tile, level])

static func _refresh_blocked_tile_index_for_interaction(session: SessionStateStoreScript.SessionData, topology_facts: Dictionary) -> void:
	HumanEngine.native_writing(&"OverworldRules._refresh_blocked_tile_index_for_interaction", [session, topology_facts])

static func invalidate_spatial_lookup(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules.invalidate_spatial_lookup", [session])

static func _guard_engagement_world_tiles(encounter: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._guard_engagement_world_tiles", [encounter])

static func _build_blocked_tile_index(session: SessionStateStoreScript.SessionData, level: int = -1, ignore_actor_id: String = "", combat_defenders: Dictionary = {}) -> Dictionary:
	return DayEngine.native_writing(&"OverworldRules._build_blocked_tile_index", [session, level, ignore_actor_id, combat_defenders])

static func town_footprint_tiles(town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.town_footprint_tiles", [town])

## A town completes at most one build order per day.
static func town_built_today(town: Dictionary, day: int) -> bool:
	return HumanEngine.native(&"OverworldRules.town_built_today", [town, day])

## True when the player's hero has used today's overworld spell.
static func hero_cast_spell_today(session: SessionStateStoreScript.SessionData, hero_id: String) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.hero_cast_spell_today", [session, hero_id])

## Every tile a mine stands on: its body and its entrance. Empty if the node is not a mine.
static func mine_footprint_tiles(node: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.mine_footprint_tiles", [node])

static func describe_resources(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resources", [session])

static func describe_resource_stockpile(resources: Variant, include_zero_rare: bool = false) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resource_stockpile", [resources, include_zero_rare])

static func describe_status(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_status", [session])

static func describe_objective_brief(session: SessionStateStoreScript.SessionData) -> String:
	return _describe_objective_brief_from_surface(_objective_stakes_surface(session))

static func describe_objective_header_surfaces(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.describe_objective_header_surfaces", [session])

static func _describe_objective_brief_from_surface(surface: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._describe_objective_brief_from_surface", [surface])

static func describe_objective_stakes_board(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_objective_stakes_board", [session])

static func describe_hero(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_hero", [session])

static func describe_heroes(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_heroes", [session])

static func describe_army(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_army", [session])

static func describe_stack_inspection_line(stack: Dictionary, options: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_stack_inspection_line", [stack, options])

static func describe_unit_recruit_brief(unit_id: String, count: int = 0) -> String:
	return HumanEngine.native(&"OverworldRules.describe_unit_recruit_brief", [unit_id, count])

static func unit_stack_strength_value(unit_id: String, count: int) -> int:
	return HumanEngine.native(&"OverworldRules.unit_stack_strength_value", [unit_id, count])

static func next_weekly_growth_day(day: int) -> int:
	return HumanEngine.native(&"OverworldRules.next_weekly_growth_day", [day])

static func town_control_label(owner: String) -> String:
	return HumanEngine.native(&"OverworldRules.town_control_label", [owner])

static func describe_town_context(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_town_context", [town, session])

static func describe_context(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_context", [session])

static func describe_objectives(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_objectives", [session])

static func _objective_stakes_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._objective_stakes_surface", [session])

static func _scenario_objective_player_label(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._scenario_objective_player_label", [session, objective])

static func describe_frontier_threats(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_frontier_threats", [session])

static func describe_defense_readiness_warnings(session: SessionStateStoreScript.SessionData, limit: int = 2) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_defense_readiness_warnings", [session, limit])

static func describe_town_defense_readiness_warning(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_town_defense_readiness_warning", [session, town])

static func _local_visible_threat_summary(session: SessionStateStoreScript.SessionData, fallback: String = "") -> String:
	return HumanEngine.native_writing(&"OverworldRules._local_visible_threat_summary", [session, fallback])

static func describe_enemy_threats(session: SessionStateStoreScript.SessionData) -> String:
	return describe_frontier_threats(session)

static func describe_spellbook(session: SessionStateStoreScript.SessionData, context_filter: String = "") -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_spellbook", [session, context_filter])

static func describe_spellbook_rail(session: SessionStateStoreScript.SessionData, context_filter: String = "") -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_spellbook_rail", [session, context_filter])

static func describe_specialties(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_specialties", [session])

static func describe_artifacts(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_artifacts", [session])

static func consume_command_briefing(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.consume_command_briefing", [session])

static func _refresh_watch_observation_context(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._refresh_watch_observation_context", [session])

static func describe_commitment_board(session: SessionStateStoreScript.SessionData, refresh_watch_context: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_commitment_board", [session, refresh_watch_context])

static func describe_end_turn_forecast(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_end_turn_forecast", [session])

static func describe_end_turn_forecast_compact(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_end_turn_forecast_compact", [session])

static func describe_end_turn_forecast_surfaces(session: SessionStateStoreScript.SessionData, refresh_watch_context: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.describe_end_turn_forecast_surfaces", [session, refresh_watch_context])

static func describe_command_risk_surfaces(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.describe_command_risk_surfaces", [session])

static func _command_risk_surfaces_from_forecast(forecast: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._command_risk_surfaces_from_forecast", [forecast])

static func consume_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.consume_command_risk_forecast", [session])

static func describe_dispatch(session: SessionStateStoreScript.SessionData, last_message: String = "") -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_dispatch", [session, last_message])

static func describe_event_dispatch_surfaces(session: SessionStateStoreScript.SessionData, last_message: String = "", turn_resolution_summary: String = "", enemy_activity_summary: String = "", enemy_activity_events_value: Variant = [], action_recap_value: Variant = {}, refresh_watch_context: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.describe_event_dispatch_surfaces", [session, last_message, turn_resolution_summary, enemy_activity_summary, enemy_activity_events_value, action_recap_value, refresh_watch_context])

static func describe_event_feed_surface(session: SessionStateStoreScript.SessionData, last_message: String = "", turn_resolution_summary: String = "", enemy_activity_summary: String = "", enemy_activity_events_value: Variant = [], action_recap_value: Variant = {}) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.describe_event_feed_surface", [session, last_message, turn_resolution_summary, enemy_activity_summary, enemy_activity_events_value, action_recap_value])

static func _event_feed_watch_line(session: SessionStateStoreScript.SessionData) -> String:
	return _event_feed_watch_line_from_observation_context({
		"route_pressure": describe_route_interception_surface(session),
		"local_pressure": _local_visible_threat_summary(session, ""),
		"management_watch": describe_management_watch(session),
		"defense_watch": describe_defense_readiness_warnings(session, 1),
	})

static func _event_feed_watch_line_from_observation_context(observation_context: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._event_feed_watch_line_from_observation_context", [observation_context])

static func describe_route_interception_surface(session: SessionStateStoreScript.SessionData, destination_x: int = -1, destination_y: int = -1, route_steps: int = 0, include_global_fallback: bool = true) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.describe_route_interception_surface", [session, destination_x, destination_y, route_steps, include_global_fallback])

static func town_weekly_growth(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_weekly_growth", [town, session])

static func town_income(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_income", [town, session])

static func town_reinforcement_quality(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return HumanEngine.native_writing(&"OverworldRules.town_reinforcement_quality", [town, session])

static func town_battle_readiness(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return HumanEngine.native_writing(&"OverworldRules.town_battle_readiness", [town, session])

static func town_pressure_output(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return HumanEngine.native_writing(&"OverworldRules.town_pressure_output", [town, session])

static func town_strategic_role(town: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.town_strategic_role", [town])

static func describe_faction_identity_surface(faction_id: String) -> String:
	return _faction_identity_surface(faction_id)

static func describe_town_identity_surface(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_town_identity_surface", [town, session])

static func town_logistics_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_logistics_state", [session, town])

static func town_recovery_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_recovery_state", [session, town])

static func town_public_threat_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_public_threat_state", [session, town])

static func town_front_state(session: SessionStateStoreScript.SessionData, town: Dictionary, precomputed_development_metrics: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_front_state", [session, town, precomputed_development_metrics])

static func town_occupation_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_occupation_state", [session, town])

static func controlled_resource_site_income(session: SessionStateStoreScript.SessionData, controller_id: String, income_day: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.controlled_resource_site_income", [session, controller_id, income_day])

static func _resource_site_income_cadence_label(site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_income_cadence_label", [site])

## Resources the player receives at the next daybreak: the same projection as
## the end-turn income forecast (towns, hero artifacts/specialties, sites).
static func player_daily_income(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.player_daily_income", [session])

static func apply_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> Array:
	return _apply_market_cost_coverage(town, pool, cost, current_day)

static func town_cost_readiness(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_cost_readiness", [town, pool, cost, current_day])

static func describe_management_watch(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_management_watch", [session])

static func describe_town_build_projection(session: SessionStateStoreScript.SessionData, town: Dictionary, building_id: String) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_town_build_projection", [session, town, building_id])

static func relieve_town_recovery_pressure(session: SessionStateStoreScript.SessionData, town_placement_id: String, amount: int, source: String = "") -> String:
	return HumanEngine.native_writing(&"OverworldRules.relieve_town_recovery_pressure", [session, town_placement_id, amount, source])

static func town_recruit_cost(session: SessionStateStoreScript.SessionData, town: Dictionary, unit_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_recruit_cost", [session, town, unit_id])

static func get_context_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_context_actions", [session])

static func perform_rendezvous_transfer_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.perform_rendezvous_transfer_action", [session, action_id])

static func perform_rendezvous_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.perform_rendezvous_action", [session, action_id])

static func get_artifact_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_artifact_actions", [session])

static func get_spell_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_spell_actions", [session])

static func get_hero_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_hero_actions", [session])

static func switch_active_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.switch_active_hero", [session, hero_id])

static func get_level_up_prompt(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.get_level_up_prompt", [session])

static func resolve_level_up(session: SessionStateStoreScript.SessionData, context: Dictionary, specialty_id: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.resolve_level_up", [session, context, specialty_id])

static func get_specialty_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_specialty_actions", [session])

static func choose_specialty(session: SessionStateStoreScript.SessionData, specialty_id: String, hero_id: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.choose_specialty", [session, specialty_id, hero_id])

static func _normalize_army_state(army: Dictionary) -> Dictionary:
	var normalized_stacks := []
	for stack in army.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var unit_id := String(stack.get("unit_id", ""))
		if unit_id == "":
			continue
		normalized_stacks.append({"unit_id": unit_id, "count": max(0, int(stack.get("count", 0)))})
	return {
		"id": String(army.get("id", "")),
		"name": String(army.get("name", "Field Army")),
		"stacks": normalized_stacks,
	}

static func _normalize_resource_nodes(nodes: Array) -> Array:
	return DayEngine.native(&"OverworldRules._normalize_resource_nodes", [nodes])

static func _find_resource_node_at(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._find_resource_node_at", [session])

static func _find_context_resource_node(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._find_context_resource_node", [session])

static func _find_resource_node_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._find_resource_node_by_placement", [session, placement_id])

static func _find_active_resource_node(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var node_result := _find_resource_node_at(session)
	if int(node_result.get("index", -1)) < 0:
		return {"index": -1, "node": {}}
	var node = node_result.get("node", {})
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if _resource_node_claimable_by_player(node, site, session):
		return node_result
	return {"index": -1, "node": {}}

static func _find_active_artifact_node(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._find_active_artifact_node", [session])

static func _resource_site_is_persistent(site: Dictionary) -> bool:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_is_persistent", [site])

static func resource_node_is_present(node: Dictionary, site: Dictionary = {}) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.resource_node_is_present", [node, site])

static func _resource_site_is_repeatable(site: Dictionary) -> bool:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_is_repeatable", [site])

static func _resource_site_visit_cost(site: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._resource_site_visit_cost", [site])

static func _resource_site_repeat_ready(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> bool:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_repeat_ready", [session, node, site])

static func _resource_site_next_visit_day(node: Dictionary, site: Dictionary) -> int:
	return HumanEngine.native(&"OverworldRules._resource_site_next_visit_day", [node, site])

static func _resource_node_claimable_by_player(node: Dictionary, site: Dictionary, session: SessionStateStoreScript.SessionData = null) -> bool:
	return HumanEngine.native_writing(&"OverworldRules._resource_node_claimable_by_player", [node, site, session])

static func _resource_node_has_live_ai_defender(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> bool:
	return HumanEngine.native_writing(&"OverworldRules._resource_node_has_live_ai_defender", [session, node, site])

static func _resource_site_claim_rewards(site: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._resource_site_claim_rewards", [site])

static func _resource_site_claim_recruits(site: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._resource_site_claim_recruits", [site])

static func resource_site_is_recruit_source(site: Dictionary) -> bool:
	return HumanEngine.native(&"OverworldRules.resource_site_is_recruit_source", [site])

static func describe_recruit_source_compact(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_recruit_source_compact", [session, node, site])

static func describe_recruit_source_inspection(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_recruit_source_inspection", [session, node, site])

static func describe_resource_site_surface(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resource_site_surface", [session, node, site])

static func describe_resource_site_control_summary(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resource_site_control_summary", [session, node, site])

static func describe_resource_site_control_inspection(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resource_site_control_inspection", [session, node, site])

static func describe_resource_site_interaction_surface(node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules.describe_resource_site_interaction_surface", [node, site])

static func describe_encounter_object_surface(encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_object_surface", [encounter])

static func _recruit_source_roster_line(label: String, recruits: Variant, limit: int, dwelling_prices: bool = false) -> String:
	return HumanEngine.native(&"OverworldRules._recruit_source_roster_line", [label, recruits, limit, dwelling_prices])

static func _resource_site_action_label(node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_action_label", [node, site])

static func _resource_site_role_label(node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_role_label", [node, site])

static func _resource_site_control_brief(node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_control_brief", [node, site])

static func _resource_site_yield_line(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_yield_line", [session, node, site])

static func _resource_site_guard_or_contest_line(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_guard_or_contest_line", [session, node, site])

## positions: an Array limits the scan to the encounters at these list
## positions, in ascending order, for a caller that knows no other encounter can
## match (AiHeroRules._encounter_guard_index); null scans them all.
static func _resource_site_guard_encounter(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary, positions: Variant = null) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_guard_encounter", [session, node, site, positions])

static func _resource_site_guard_blocks_node(encounter: Dictionary, node: Dictionary) -> bool:
	return HumanEngine.native(&"OverworldRules._resource_site_guard_blocks_node", [encounter, node])

## positions: see _resource_site_guard_encounter.
static func resource_site_blocking_guard(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary, positions: Variant = null) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.resource_site_blocking_guard", [session, node, site, positions])

static func _interaction_cadence_label(cadence: String) -> String:
	return HumanEngine.native(&"OverworldRules._interaction_cadence_label", [cadence])

static func _encounter_guard_link(encounter: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._encounter_guard_link", [encounter])

static func _encounter_guard_summary(encounter: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	return HumanEngine.native_writing(&"OverworldRules._encounter_guard_summary", [encounter, session])

static func _encounter_readiness_surface(session: SessionStateStoreScript.SessionData, encounter: Dictionary, compact: bool = false) -> String:
	return HumanEngine.native_writing(&"OverworldRules._encounter_readiness_surface", [session, encounter, compact])

static func _encounter_risk_label(encounter: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._encounter_risk_label", [encounter])

static func _encounter_difficulty_label(encounter: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._encounter_difficulty_label", [encounter])

static func _encounter_army_surface(encounter: Dictionary, include_units: bool) -> String:
	return HumanEngine.native(&"OverworldRules._encounter_army_surface", [encounter, include_units])

static func _encounter_army_payload(encounter: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._encounter_army_payload", [encounter])

static func _encounter_reward_surface(encounter: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._encounter_reward_surface", [encounter])

static func _encounter_guard_target_label(session: SessionStateStoreScript.SessionData, guard: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._encounter_guard_target_label", [session, guard])

static func _non_empty_strings(value: Array) -> Array[String]:
	return HumanEngine.native(&"OverworldRules._non_empty_strings", [value])

static func _humanize_id(value: String) -> String:
	return HumanEngine.native(&"OverworldRules._humanize_id", [value])

static func _resource_site_response_state(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_response_state", [session, node, site])

static func _resource_site_response_effect_summary(response_state: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_response_effect_summary", [response_state])

static func _resource_site_delivery_state(session: SessionStateStoreScript.SessionData, node: Dictionary, _site: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_delivery_state", [session, node, _site])

static func _resource_site_delivery_interception(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_delivery_interception", [session, node, site])

static func _player_reserve_delivery_plan(session: SessionStateStoreScript.SessionData, source_town: Dictionary, response_state: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._player_reserve_delivery_plan", [session, source_town, response_state])

static func _consume_recruit_payload(recruits: Variant, manifest: Variant) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._consume_recruit_payload", [recruits, manifest])

static func _resource_site_context_summary(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_context_summary", [session, node, site])

static func _describe_recruit_count(recruits: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._describe_recruit_count", [recruits])

## Dialog payload for troops that did not fit: the site, the waiting troops
## (the first one takes the next freed slot) and the hero's seven slots.
static func site_recruit_overflow_prompt(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.site_recruit_overflow_prompt", [session])

## Dismisses the stack in slot_index; the first waiting unit type takes its
## place and any other waiting troops that now fit join too.
static func take_site_recruits_by_dismissing(session: SessionStateStoreScript.SessionData, slot_index: int, expected_context: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.take_site_recruits_by_dismissing", [session, slot_index, expected_context])

## Leaves the waiting troops behind; they are lost.
static func leave_site_recruits(session: SessionStateStoreScript.SessionData, expected_context: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.leave_site_recruits", [session, expected_context])

static func _resource_site_spell_names(site: Dictionary) -> Array:
	return HumanEngine.native(&"OverworldRules._resource_site_spell_names", [site])

static func _issue_resource_site_response(session: SessionStateStoreScript.SessionData, placement_id: String, origin: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._issue_resource_site_response", [session, placement_id, origin])

static func _army_strength_value(stacks: Variant) -> int:
	return HumanEngine.native_writing(&"OverworldRules._army_strength_value", [stacks])

static func _add_army_stack(stacks: Variant, unit_id: String, amount: int) -> Array:
	var normalized := []
	var added := false
	if stacks is Array:
		for stack_value in stacks:
			if not (stack_value is Dictionary):
				continue
			var stack: Dictionary = stack_value.duplicate(true)
			stack["unit_id"] = String(stack.get("unit_id", ""))
			stack["count"] = max(0, int(stack.get("count", 0)))
			if not added and stack["unit_id"] == unit_id:
				stack["count"] = int(stack.get("count", 0)) + max(0, amount)
				added = true
			if stack["unit_id"] != "" and int(stack.get("count", 0)) > 0:
				normalized.append(stack)
	if not added and unit_id != "" and amount > 0:
		normalized.append({"unit_id": unit_id, "count": amount})
	return normalized

static func _army_unit_count(stacks: Variant, unit_id: String) -> int:
	return HumanEngine.native(&"OverworldRules._army_unit_count", [stacks, unit_id])

static func _faction_identity_surface(faction_id: String) -> String:
	var faction := ContentService.get_faction(faction_id)
	if faction.is_empty():
		return ""
	var pillars = faction.get("design_pillars", {})
	var lines := ["Faction Identity: %s" % String(faction.get("name", faction_id))]
	var identity := String(faction.get("identity_summary", "")).strip_edges()
	if identity != "":
		lines.append("Theme: %s" % identity)
	if pillars is Dictionary:
		var economy_style := String(pillars.get("economy_style", "")).strip_edges()
		if economy_style != "":
			lines.append("Economy: %s" % economy_style)
		var map_pressure := String(pillars.get("map_pressure", "")).strip_edges()
		if map_pressure != "":
			lines.append("Pressure: %s" % map_pressure)
		var battle_style := String(pillars.get("battle_style", "")).strip_edges()
		if battle_style != "":
			lines.append("Strategic cue: %s" % battle_style)
	return "\n".join(lines)

static func _town_response_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._town_response_actions", [session, town])

static func _town_market_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._town_market_actions", [session, town])

static func _market_buy_resources(state: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._market_buy_resources", [state])

static func _town_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._town_market_cost_coverage", [town, pool, cost, current_day])

static func _apply_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._apply_market_cost_coverage", [town, pool, cost, current_day])

static func _building_growth_payload(building_id: String) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._building_growth_payload", [building_id])

static func _award_experience(session: SessionStateStoreScript.SessionData, amount: int) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._award_experience", [session, amount])

static func _can_afford(session: SessionStateStoreScript.SessionData, cost: Variant) -> bool:
	return HumanEngine.native_writing(&"OverworldRules._can_afford", [session, cost])

static func _max_affordable_count(session: SessionStateStoreScript.SessionData, unit_cost: Variant) -> int:
	return HumanEngine.native_writing(&"OverworldRules._max_affordable_count", [session, unit_cost])

static func _apply_resource_transaction_to_pool(pool: Dictionary, cost: Variant, gain: Variant) -> void:
	HumanEngine.native_writing(&"OverworldRules._apply_resource_transaction_to_pool", [pool, cost, gain])

static func resource_definition(resource_id: String) -> Dictionary:
	return HumanEngine.native(&"OverworldRules.resource_definition", [resource_id])

static func resource_icon_path(resource_id: String) -> String:
	return HumanEngine.native(&"OverworldRules.resource_icon_path", [resource_id])

static func _resource_display_name(resource_key: String) -> String:
	return HumanEngine.native(&"OverworldRules._resource_display_name", [resource_key])

static func _describe_resource_delta(delta: Variant) -> String:
	return HumanEngine.native_writing(&"OverworldRules._describe_resource_delta", [delta])

static func _describe_recruit_projection(current: Variant, projected: Variant) -> String:
	return HumanEngine.native(&"OverworldRules._describe_recruit_projection", [current, projected])

static func _describe_signed_int(value: int) -> String:
	return HumanEngine.native(&"OverworldRules._describe_signed_int", [value])

static func _find_encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._find_encounter_by_placement", [session, placement_id])

static func _sync_spellbook_to_hero(session: SessionStateStoreScript.SessionData, previous_max: int) -> void:
	HumanEngine.native_writing(&"OverworldRules._sync_spellbook_to_hero", [session, previous_max])

static func _town_requires_assault(town: Dictionary) -> bool:
	return HumanEngine.native(&"OverworldRules._town_requires_assault", [town])

static func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i, level: int = -1) -> void:
	HumanEngine.native_writing(&"OverworldRules._set_active_hero_position", [session, tile, level])

static func _normalize_fog_of_war(session: SessionStateStoreScript.SessionData) -> void:
	DayEngine.native_writing(&"OverworldRules._normalize_fog_of_war", [session])

static func _attach_post_action_recap(result: Dictionary, session: SessionStateStoreScript.SessionData, action_kind: String, context: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._attach_post_action_recap", [result, session, action_kind, context])

static func _normalize_post_action_recap(value: Variant) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._normalize_post_action_recap", [value])

static func _visible_tile_count(session: SessionStateStoreScript.SessionData) -> int:
	var fog = session.overworld.get(FOG_KEY, {})
	return int(fog.get("visible_count", 0))

static func _explored_tile_count(session: SessionStateStoreScript.SessionData) -> int:
	var fog = session.overworld.get(FOG_KEY, {})
	return int(fog.get("explored_count", 0))

static func _finalize_action_result(session: SessionStateStoreScript.SessionData, ok: bool, base_message: String, refresh_fog: bool = true, incremental_fog: bool = false, scenario_event_facts: Dictionary = {}) -> Dictionary:
	return DayEngine.native_writing(&"OverworldRules._finalize_action_result", [session, ok, base_message, refresh_fog, incremental_fog, scenario_event_facts])

static func _context_action_briefing(session: SessionStateStoreScript.SessionData, action: Variant, context: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._context_action_briefing", [session, action, context])

static func _encounter_pressure_summary(session: SessionStateStoreScript.SessionData, encounter: Dictionary, for_battle_prompt: bool = false) -> String:
	return HumanEngine.native_writing(&"OverworldRules._encounter_pressure_summary", [session, encounter, for_battle_prompt])

static func _resource_site_opening_value(site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_opening_value", [site])

static func _army_totals(army: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._army_totals", [army])

static func _resource_site_control_label(node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_control_label", [node, site])

static func can_afford_cost_with_town_market(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.can_afford_cost_with_town_market", [town, pool, cost, current_day])

static func get_town_market_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_town_market_actions", [session, town])

static func get_town_recruit_options(town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_town_recruit_options", [town])
