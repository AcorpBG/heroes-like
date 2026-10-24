class_name OverworldRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const NativeTransit = preload("res://scripts/core/NativeTransitRules.gd")
const PlayerEliminationRulesScript = preload("res://scripts/core/PlayerEliminationRules.gd")
const Mines = preload("res://scripts/core/MineRules.gd")
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
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

static func _rules_profile_timer() -> int:
	return Time.get_ticks_usec() if _movement_rules_profile_active else 0

static func _rules_profile_add_ms(bucket: String, started_usec: int) -> void:
	if not _movement_rules_profile_active or started_usec <= 0 or bucket == "":
		return
	var buckets: Dictionary = _movement_rules_profile.get("sub_buckets_ms", {})
	buckets[bucket] = snapped(float(buckets.get(bucket, 0.0)) + float(maxi(0, Time.get_ticks_usec() - started_usec)) / 1000.0, 0.001)
	_movement_rules_profile["sub_buckets_ms"] = buckets

static func _rules_profile_set(section: String, key: String, value: Variant) -> void:
	if not _movement_rules_profile_active or section == "" or key == "":
		return
	var target: Dictionary = _movement_rules_profile.get(section, {}) if _movement_rules_profile.get(section, {}) is Dictionary else {}
	target[key] = value
	_movement_rules_profile[section] = target

static func _scenario_factory() -> Variant:
	return load("res://scripts/core/ScenarioFactory.gd")

static func _scenario_rules() -> Variant:
	return load("res://scripts/core/ScenarioRules.gd")

static func _campaign_rules() -> Variant:
	return load("res://scripts/core/CampaignRules.gd")

static func _scenario_script_rules() -> Variant:
	# Validator anchor: ScenarioScriptRules.describe_recent_events
	return load("res://scripts/core/ScenarioScriptRules.gd")

static func _enemy_turn_rules() -> Variant:
	return load("res://scripts/core/EnemyTurnRules.gd")

static func _enemy_adventure_rules() -> Variant:
	return load("res://scripts/core/EnemyAdventureRules.gd")

static func _battle_rules() -> Variant:
	return load("res://scripts/core/BattleRules.gd")

static func _build_scenario_army_state(army_template: Dictionary) -> Dictionary:
	return _scenario_factory()._build_army_state(army_template)

static func _normalize_scenario_resources(value: Variant) -> Dictionary:
	return _scenario_factory()._normalize_resources(value)

static func _build_scenario_town_states(placements: Variant) -> Array:
	return _scenario_factory()._build_town_states(placements)

static func _build_scenario_resource_states(placements: Variant) -> Array:
	return _scenario_factory()._build_resource_states(placements)

static func _seed_scenario_recruits_for_town_state(town: Dictionary) -> Dictionary:
	return _scenario_factory()._seed_recruits_for_town_state(town)

static func _normalize_scenario_state_rules(session: SessionStateStoreScript.SessionData, normalize_enemies: bool = true) -> void:
	_scenario_rules().normalize_scenario_state(session, normalize_enemies)

static func _normalize_active_town_visit_context(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var placement_id := String(session.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, ""))
	if placement_id == "":
		return
	var town_result := _find_town_by_placement(session, placement_id)
	var town: Dictionary = town_result.get("town", {})
	if int(town_result.get("index", -1)) < 0 or String(town.get("owner", "neutral")) != "player":
		session.flags.erase(ACTIVE_TOWN_PLACEMENT_KEY)

static func _evaluate_scenario_state(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _scenario_rules().evaluate_session(session)

static func _evaluate_scenario_state_for_event(session: SessionStateStoreScript.SessionData, event_facts: Dictionary) -> Dictionary:
	return _scenario_rules().evaluate_session_for_event(session, event_facts)

static func _scenario_opening_objective_summary(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	return _scenario_rules()._opening_objective_summary(session, scenario)

static func _scenario_enemy_operational_lines(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> Array:
	return _scenario_rules()._enemy_operational_lines(session, scenario)

static func _scenario_first_contact_summary(scenario: Dictionary) -> String:
	return _scenario_rules()._first_contact_summary(scenario)

static func _scenario_objective_labels_from_bucket(session: SessionStateStoreScript.SessionData, bucket: Variant, limit: int) -> Array:
	return _scenario_rules()._objective_labels_from_bucket(session, bucket, limit)

static func _scenario_objective_met(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> bool:
	return _scenario_rules()._objective_met(session, objective)

static func _scenario_is_objective_met(session: SessionStateStoreScript.SessionData, objective_id: String, bucket: String) -> bool:
	return _scenario_rules().is_objective_met(session, objective_id, bucket)

static func _scenario_describe_objectives(session: SessionStateStoreScript.SessionData) -> String:
	return _scenario_rules().describe_objectives(session)

static func _describe_recent_events(session: SessionStateStoreScript.SessionData, limit: int) -> String:
	return _scenario_script_rules().describe_recent_events(session, limit)

static func _normalize_enemy_states(session: SessionStateStoreScript.SessionData) -> void:
	_enemy_turn_rules().normalize_enemy_states(session)

static func _run_enemy_turn_cycle(session: SessionStateStoreScript.SessionData) -> Dictionary:
	# end_turn evaluates the scenario right after, which normalizes the enemy
	# states and their commander rosters again.
	return _enemy_turn_rules().run_enemy_turn(session, false)

static func _describe_enemy_threats(session: SessionStateStoreScript.SessionData) -> String:
	return _enemy_turn_rules().describe_threats(session)

static func _enemy_pressure(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return _enemy_turn_rules().get_pressure(session, faction_id)

static func _enemy_active_raids(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return _enemy_turn_rules().active_raid_count(session, faction_id)

static func _enemy_raid_threshold_for_strategy(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String) -> int:
	return _enemy_turn_rules()._raid_threshold_for_strategy(session, config, faction_id)

static func _enemy_max_active_raids_for_strategy(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String) -> int:
	return _enemy_turn_rules()._max_active_raids_for_strategy(session, config, faction_id)

static func _raid_target_is_objective_anchor(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> bool:
	return _enemy_adventure_rules().target_is_objective_anchor(session, target_kind, placement_id)

static func _raid_is_public(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	return _enemy_adventure_rules()._raid_is_public(session, encounter)

static func normalize_overworld_state(session: SessionStateStoreScript.SessionData) -> void:
	DayEngine.native_writing(&"OverworldRules.normalize_overworld_state", [session])

## Older random-map saves picked a random transit object for HoMM3 boats,
## shipyards, whirlpools, gates and portals. Translate them by meaning once:
## boats become boats, shipyards and whirlpools get their sites, unopened gates
## become a gate that suits their terrain, and portals keep their passage with
## matching art. Opened gates stay open. Version 2 gives each portal kind its
## own art and drops portal networks that never leave their zone; saves already
## at version 1 only revisit their portals.
static func _migrate_generated_transit_meanings(session: SessionStateStoreScript.SessionData) -> void:
	var migrated_version := int(session.overworld.get(GENERATED_TRANSIT_TRANSLATION_KEY, 0))
	session.overworld.erase("native_transit_pending_arrival")
	if migrated_version >= GENERATED_TRANSIT_TRANSLATION_VERSION:
		return
	var sources: Variant = session.overworld.get("package_source_objects_by_id", {})
	var nodes: Variant = session.overworld.get("resource_nodes", [])
	if not (sources is Dictionary) or sources.is_empty() or not (nodes is Array):
		session.overworld[GENERATED_TRANSIT_TRANSLATION_KEY] = GENERATED_TRANSIT_TRANSLATION_VERSION
		return
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	var rows: Array = session.overworld.get("map", []) if session.overworld.get("map", []) is Array else []
	var boats: Array = WaterTravel.boats(session).duplicate(true)
	var kept := []
	for node_value in nodes:
		if not (node_value is Dictionary) or int(node_value.get("h3m_type_id", -1)) not in GeneratedRewards.TRANSIT_MEANING_TYPES:
			kept.append(node_value)
			continue
		if migrated_version >= 1 and int(node_value.get("h3m_type_id", -1)) not in GeneratedRewards.PORTAL_TYPES:
			kept.append(node_value)
			continue
		var node: Dictionary = node_value
		var source: Dictionary = sources.get(String(node.get("placement_id", "")), node) if sources.get(String(node.get("placement_id", "")), node) is Dictionary else node
		if GeneratedRewards.is_skipped(source):
			var tile := GeneratedRewards.boat_tile(source)
			if not tile.is_empty():
				boats.append({"id": "boat_%s" % String(node.get("placement_id", "")), "x": int(tile.x), "y": int(tile.y), "level": int(tile.level), "hero_id": ""})
			continue
		if int(node.get("h3m_type_id", -1)) in GeneratedRewards.GATE_TYPES and bool(node.get("collected", false)):
			kept.append(node)
			continue
		var translated := GeneratedRewards.resolve(source, towns, rows)
		if translated.is_empty():
			kept.append(node)
			continue
		if NativeTransit.is_native(node):
			var reskinned: Dictionary = node.duplicate(true)
			reskinned["site_id"] = translated.get("site_id", node.get("site_id", ""))
			reskinned["object_id"] = translated.get("object_id", node.get("object_id", ""))
			kept.append(reskinned)
			continue
		translated["collected"] = false
		kept.append(translated)
	session.overworld["resource_nodes"] = kept
	session.overworld[WaterTravel.BOATS_KEY] = boats
	session.overworld[GENERATED_TRANSIT_TRANSLATION_KEY] = GENERATED_TRANSIT_TRANSLATION_VERSION

static func normalize_overworld_state_for_runtime(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules.normalize_overworld_state_for_runtime", [session])

static func is_runtime_session_normalized(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null:
		return false
	return String(_runtime_normalized_signatures.get(String(session.session_id), "")) == _runtime_normalization_signature(session)

static func mark_runtime_normalized_transition_state(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var session_id := String(session.session_id)
	if not _runtime_normalized_signatures.has(session_id):
		return
	_mark_runtime_normalized(session)

static func _mark_runtime_normalized(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	_runtime_normalized_signatures[String(session.session_id)] = _runtime_normalization_signature(session)

static func _runtime_normalization_signature(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return ""
	var map_size := derive_map_size(session)
	var movement: Dictionary = session.overworld.get("movement", {}) if session.overworld.get("movement", {}) is Dictionary else {}
	var hero_pos := hero_position(session)
	var fog: Dictionary = session.overworld.get(FOG_KEY, {}) if session.overworld.get(FOG_KEY, {}) is Dictionary else {}
	return "|".join([
		str(SessionStateStoreScript.SAVE_VERSION),
		str(session.save_version),
		String(session.session_id),
		String(session.scenario_id),
		String(session.hero_id),
		String(session.difficulty),
		SessionStateStoreScript.normalize_launch_mode(session.launch_mode),
		String(session.game_state),
		String(session.scenario_status),
		str(session.day),
		"%d,%d" % [map_size.x, map_size.y],
		"%d,%d" % [hero_pos.x, hero_pos.y],
		str(hero_level(session)),
		"%d/%d" % [int(movement.get("current", 0)), int(movement.get("max", 0))],
		str(_collection_size(session.overworld.get("map", []))),
		str(_collection_size(session.overworld.get("terrain_layers", {}))),
		str(_collection_size(session.overworld.get("towns", []))),
		str(_collection_size(session.overworld.get("resource_nodes", []))),
		str(_collection_size(session.overworld.get("artifact_nodes", []))),
		str(_collection_size(session.overworld.get("encounters", []))),
		str(_collection_size(session.overworld.get("resolved_encounters", []))),
		str(_collection_size(session.overworld.get("player_heroes", []))),
		str(fog.get("visible_count", -1)),
		str(fog.get("explored_count", -1)),
		String(session.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, "")),
	])

static func _collection_size(value: Variant) -> int:
	if value is Array or value is Dictionary:
		return value.size()
	return 0

static func _normalize_generated_runtime_materialization(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> void:
	if session == null:
		return
	if not bool(scenario.get("generated", false)) and not bool(session.flags.get("generated_random_map", false)) and not bool(session.flags.get("generated_random_map_draft", false)):
		return
	var materialization: Dictionary = session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) if session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) is Dictionary else {}
	var identity: Dictionary = session.overworld.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}) if session.overworld.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}) is Dictionary else {}
	if materialization.is_empty():
		var scenario_materialization: Dictionary = scenario.get("generated_runtime_materialization", {}) if scenario.get("generated_runtime_materialization", {}) is Dictionary else {}
		if not scenario_materialization.is_empty():
			materialization = scenario_materialization.duplicate(true)
	if identity.is_empty() and not materialization.is_empty():
		identity = {
			"schema_id": String(materialization.get("schema_id", "")),
			"scenario_id": String(materialization.get("scenario_id", session.scenario_id)),
			"materialized_map_signature": String(materialization.get("materialized_map_signature", "")),
			"generator_version": String(materialization.get("generator_version", "")),
			"template_id": String(materialization.get("template_id", "")),
			"profile_id": String(materialization.get("profile_id", "")),
			"normalized_seed": String(materialization.get("normalized_seed", "")),
			"content_manifest_fingerprint": String(materialization.get("content_manifest_fingerprint", "")),
			"summary": materialization.get("summary", {}),
			"boundary": materialization.get("boundary", {}),
		}
	if not materialization.is_empty():
		session.overworld[SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY] = materialization
	if not identity.is_empty():
		session.overworld[SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG] = identity
		session.flags[SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG] = identity.duplicate(true)

static func begin_normalized_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if _normalized_read_scope_depth <= 0:
		normalize_overworld_state_for_runtime(session)
		_normalized_read_scope_session_id = String(session.session_id)
		_normalized_read_scope_depth = 1
		_normalized_read_scope_cache = {}
		_normalized_read_scope_town_digests = []
		_last_normalized_read_scope_cache_profile = {"hits": 0, "misses": 0, "entries": 0}
		return
	if String(session.session_id) == _normalized_read_scope_session_id:
		_normalized_read_scope_depth += 1
		return
	normalize_overworld_state_for_runtime(session)

static func end_normalized_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if _normalized_read_scope_depth <= 0 or String(session.session_id) != _normalized_read_scope_session_id:
		return
	_normalized_read_scope_depth -= 1
	if _normalized_read_scope_depth <= 0:
		_last_normalized_read_scope_cache_profile["entries"] = _normalized_read_scope_cache.size()
		_normalized_read_scope_depth = 0
		_normalized_read_scope_session_id = ""
		_normalized_read_scope_cache = {}
		_normalized_read_scope_town_digests = []

static func validation_last_normalized_read_scope_cache_profile() -> Dictionary:
	return _last_normalized_read_scope_cache_profile.duplicate(true)

static func _town_read_scope_cache_key(
		session: SessionStateStoreScript.SessionData,
		kind: String,
		town: Dictionary,
		extra: String = "") -> String:
	if (
		session == null
		or _normalized_read_scope_depth <= 0
		or String(session.session_id) != _normalized_read_scope_session_id
	):
		return ""
	# Nested save-summary reads can inspect a different snapshot with the same
	# persisted session id and town but different sites, threats or current day.
	return "%d|%s|%s|%s" % [session.get_instance_id(), kind, _read_scope_town_digest(town), extra]

## Read-scope key for a town value that depends only on the town record and
## authored content, never on the rest of the session (build status, seeded
## growth). Empty outside a normalized read scope.
static func _town_content_read_scope_key(kind: String, town: Dictionary, extra: String = "") -> String:
	if _normalized_read_scope_depth <= 0:
		return ""
	return "content|%s|%s|%s" % [kind, _read_scope_town_digest(town), extra]

## Content digest of a town for read-scope cache keys. A town screen refresh
## asks for one town's keys hundreds of times; the JSON digest is computed once
## per town dictionary and reused while that same dictionary's content hash is
## unchanged. Copies and edited towns get their own digest.
static func _read_scope_town_digest(town: Dictionary) -> String:
	var content_hash := town.hash()
	for entry in _normalized_read_scope_town_digests:
		if is_same(entry[0], town):
			if int(entry[1]) == content_hash:
				return String(entry[2])
			var refreshed := JSON.stringify(town).sha256_text()
			entry[1] = content_hash
			entry[2] = refreshed
			return refreshed
	var digest := JSON.stringify(town).sha256_text()
	if _normalized_read_scope_town_digests.size() < 64:
		_normalized_read_scope_town_digests.append([town, content_hash, digest])
	return digest

static func _town_read_scope_cache_has(key: String) -> bool:
	if key == "" or not _normalized_read_scope_cache.has(key):
		if key != "":
			_last_normalized_read_scope_cache_profile["misses"] = int(_last_normalized_read_scope_cache_profile.get("misses", 0)) + 1
		return false
	_last_normalized_read_scope_cache_profile["hits"] = int(_last_normalized_read_scope_cache_profile.get("hits", 0)) + 1
	return true

static func _town_read_scope_cache_get(key: String) -> Variant:
	var value: Variant = _normalized_read_scope_cache.get(key)
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

static func _town_read_scope_cache_store(key: String, value: Variant) -> void:
	if key == "":
		return
	_normalized_read_scope_cache[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	_last_normalized_read_scope_cache_profile["entries"] = _normalized_read_scope_cache.size()

static func normalize_overworld_state_bridge(session) -> void:
	normalize_overworld_state(session)

static func validation_pathing_profile_snapshot() -> Dictionary:
	return _pathing_debug_profile.duplicate(true)

static func validation_set_pathing_profile_capture_enabled(enabled: bool) -> void:
	_pathing_debug_profile["capture_enabled"] = enabled
	if enabled:
		_pathing_debug_profile["route_interaction_lookup_count"] = 0
		_pathing_debug_profile["route_interaction_spatial_lookup_count"] = 0
		_pathing_debug_profile["route_interaction_full_scan_count"] = 0
		_pathing_debug_profile["town_placement_lookup_direct_index_count"] = 0
		_pathing_debug_profile["town_placement_lookup_spatial_index_count"] = 0
		_pathing_debug_profile["town_placement_lookup_full_scan_count"] = 0
		_pathing_debug_profile["post_move_global_discovery_count"] = 0
		_pathing_debug_profile["post_action_tile_context_scan_count"] = 0

static func refresh_fog_of_war(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if not session.overworld.has("map") or not (session.overworld.get("map") is Array):
		return
	_normalize_fog_of_war(session)

# Every owned town, player or AI, sees this far from its entrance.
static func town_vision_radius() -> int:
	return TOWN_VISION_RADIUS

# Only a held persistent site keeps watching; a one-shot site's radius is
# spent on the reveal when it is claimed.
static func held_site_vision_radius(site: Dictionary) -> int:
	if not _resource_site_is_persistent(site):
		return 0
	return max(0, int(site.get("vision_radius", 0)))

static func is_tile_visible(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	if session == null:
		return false
	return _grid_cell(_fog_grids(session, level)[1], x, y)

static func is_tile_explored(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	if session == null:
		return false
	return _grid_cell(_fog_grids(session, level)[0], x, y)

static func fog_for_level(session: SessionStateStoreScript.SessionData, level: int = -1) -> Dictionary:
	if session == null:
		return {}
	level = OverworldLevelRulesScript.query_level(session, level)
	var fog: Dictionary = session.overworld.get(FOG_KEY, {}) if session.overworld.get(FOG_KEY) is Dictionary else {}
	var levels: Dictionary = fog.get("levels", {}) if fog.get("levels") is Dictionary else {}
	if levels.get(str(level)) is Dictionary:
		return levels[str(level)]
	# A pre-level save's exploration belongs to surface. Do not reveal another
	# level by copying that grid, and never move a legacy saved hero by inference.
	return fog if level == int(fog.get("active_level", 0)) else {}

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

## [explored grid, visible grid] for a level, as is_tile_explored and
## is_tile_visible read them.
static func _fog_grids(session: SessionStateStoreScript.SessionData, level: int) -> Array:
	if (
		_fog_read_scope_depth > 0
		and session.get_instance_id() == _fog_read_scope_session_id
		and _fog_read_scope_frame == Engine.get_process_frames()
	):
		if is_same(session.overworld.get(FOG_KEY), _fog_read_scope_fog):
			var cached = _fog_read_scope_grids.get(level)
			if cached != null:
				return cached
		else:
			_fog_read_scope_grids = {}
		var grids := _fog_grids_uncached(session, level)
		_fog_read_scope_fog = session.overworld.get(FOG_KEY)
		_fog_read_scope_grids[level] = grids
		return grids
	return _fog_grids_uncached(session, level)

static func _fog_grids_uncached(session: SessionStateStoreScript.SessionData, level: int) -> Array:
	if not _fog_state_ready(session):
		normalize_overworld_state(session)
	var fog = fog_for_level(session, level)
	return [fog.get(EXPLORED_TILES_KEY, []), fog.get(EXPLORED_TILES_KEY, fog.get(VISIBLE_TILES_KEY, []))]

static func _store_level_fog(session: SessionStateStoreScript.SessionData, payload: Dictionary, level: int = -1) -> void:
	HumanEngine.native_writing(&"OverworldRules._store_level_fog", [session, payload, level])

static func describe_visibility(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return "Explored 0/0 | Visible 0"
	if not _fog_state_ready(session):
		normalize_overworld_state(session)
	var fog = session.overworld.get(FOG_KEY, {})
	return "Explored %d/%d | Visible %d" % [
		int(fog.get("explored_count", 0)),
		int(fog.get("total_tiles", 0)),
		int(fog.get("visible_count", 0)),
	]

static func try_move(session: SessionStateStoreScript.SessionData, dx: int, dy: int) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.try_move", [session, dx, dy])

static func route_movement_preview(session: SessionStateStoreScript.SessionData, route_tiles: Variant, movement_budget: int = -1) -> Dictionary:
	return HumanEngine.native(&"OverworldRules.route_movement_preview", [session, route_tiles, movement_budget])

## `fight_on_arrival`: a computer hero that means to fight the guard at the far
## end (AiHeroRules._cross_gate) may come out in its zone, as the human does.
static func native_passage_travel_check(session: SessionStateStoreScript.SessionData, node: Dictionary, actor_position: Vector3i, actor_id: String, target_id: String = "", fight_on_arrival: bool = false) -> Dictionary:
	var resolved := NativeTransit.resolve(session.overworld.get("resource_nodes", []), node, target_id)
	if not bool(resolved.get("ok", false)):
		if bool(resolved.get("native_transit_random_exit", false)):
			if actor_position != NativeTransit.point(NativeTransit.link_of(node).get("entry")):
				return {"ok": false, "message": "Move to the passage entrance first."}
			var source_safety := _native_passage_endpoint_safety(session, node, actor_id)
			if not bool(source_safety.get("ok", false)):
				return source_safety
		return resolved
	if actor_position != resolved.entry:
		return {"ok": false, "message": "Move to the passage entrance first."}
	for endpoint in [node, resolved.peer]:
		# Player arrivals can engage a hostile destination through BattleRules.
		# AI movement has its own combat owner; never grant it an unchecked warp.
		var combat_arrival: bool = endpoint == resolved.peer and actor_id != "" and (fight_on_arrival or actor_id == String(session.overworld.get("active_hero_id", "")))
		var safety := _native_passage_endpoint_safety(session, endpoint, actor_id, null, combat_arrival)
		if not bool(safety.get("ok", false)):
			return safety
	return resolved

## Like HoMM3 monoliths, a portal with several exits sends the traveller to a
## random one. The roll is keyed by portal, day, traveller and that traveller's
## trip count, so a reload replays it and the next trip can land elsewhere. An
## exit that is blocked right now is skipped for the next one in roll order.
static func native_random_exit_check(session: SessionStateStoreScript.SessionData, node: Dictionary, actor_position: Vector3i, actor_id: String) -> Dictionary:
	var first_failure := {}
	for destination in NativeTransit.exit_order(node, native_exit_roll_key(session, node, actor_id)):
		var check := native_passage_travel_check(session, node, actor_position, actor_id, String(destination.get("target_placement_id", "")))
		if bool(check.get("ok", false)):
			return check
		if first_failure.is_empty():
			first_failure = check
	return first_failure if not first_failure.is_empty() else {"ok": false, "error": "native_passage_has_no_exit", "message": "This portal has no exit on this map."}

static func native_exit_roll_key(session: SessionStateStoreScript.SessionData, node: Dictionary, actor_id: String) -> String:
	var trips: Dictionary = session.overworld.get(NATIVE_TRANSIT_TRIPS_KEY, {}) if session.overworld.get(NATIVE_TRANSIT_TRIPS_KEY, {}) is Dictionary else {}
	return "%s|%d|%s|%d" % [String(node.get("placement_id", "")), int(session.day), actor_id, int(trips.get(actor_id, 0))]

static func note_native_trip(session: SessionStateStoreScript.SessionData, actor_id: String) -> void:
	var trips: Dictionary = session.overworld.get(NATIVE_TRANSIT_TRIPS_KEY, {}) if session.overworld.get(NATIVE_TRANSIT_TRIPS_KEY, {}) is Dictionary else {}
	trips[actor_id] = int(trips.get(actor_id, 0)) + 1
	session.overworld[NATIVE_TRANSIT_TRIPS_KEY] = trips

static func _native_passage_endpoint_safety(session: SessionStateStoreScript.SessionData, node: Dictionary, actor_id: String, actor_blocked_indexes: Variant = null, combat_arrival: bool = false) -> Dictionary:
	var tile := NativeTransit.point(NativeTransit.link_of(node).get("entry"))
	var local := Vector2i(tile.x, tile.y)
	var id := String(node.get("placement_id", ""))
	if tile.z < 0 or tile.z >= OverworldLevelRulesScript.level_count(session) or not terrain_id_is_passable(_terrain_id_at(session, tile.x, tile.y, tile.z)):
		return {"ok": false, "message": "The passage destination is impassable."}
	var blocked: Variant = _blocked_tile_index(session, tile.z).get(_tile_key(local), false)
	if combat_arrival:
		# Exclude only armies that this exact arrival can fight. Rebuild from
		# immutable source masks, so a coincident scenery/site body still blocks.
		var defenders := {}
		for encounter in session.overworld.get("encounters", []):
			if encounter is Dictionary and OverworldLevelRulesScript.on_level(encounter, tile.z) and not is_encounter_resolved(session, encounter):
				if NativeTransit.point(encounter) == tile or _guard_engagement_world_tiles(encounter).has(local):
					defenders[encounter_key(encounter)] = true
		if not defenders.is_empty():
			blocked = _build_blocked_tile_index(session, tile.z, actor_id, defenders).get(_tile_key(local), false)
	elif blocked is bool and blocked and actor_id != "":
		# A moving AI army may itself cover the doorway. Re-evaluate without
		# only that actor, preserving every other overlapping source body.
		# AI path construction may supply the exact strict actor-excluded index
		# for this synchronous request. Never substitute its doorway-cleared
		# movement mask. Direct callers retain a fresh independent calculation.
		if actor_blocked_indexes is Dictionary:
			if not actor_blocked_indexes.has(tile.z):
				actor_blocked_indexes[tile.z] = _build_blocked_tile_index(session, tile.z, actor_id)
			blocked = actor_blocked_indexes[tile.z].get(_tile_key(local), false)
		else:
			blocked = _build_blocked_tile_index(session, tile.z, actor_id).get(_tile_key(local), false)
	if not (blocked is bool and not blocked) and not (blocked is String and blocked == id):
		return {"ok": false, "message": "Another object blocks the passage entrance."}
	# A hero's zone does not close a passage: whoever comes out next to a
	# hostile hero fights it there (the human's arrival, the AI's own step).
	var guard := _find_guard_engagement_at_tile(session, tile.x, tile.y, tile.z, false)
	if not combat_arrival and int(guard.get("index", -1)) >= 0 and String(guard.get("encounter", {}).get("placement_id", "")) != actor_id:
		return {"ok": false, "message": "Clear the guard before using this passage."}
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or String(encounter.get("placement_id", "")) == actor_id or is_encounter_resolved(session, encounter):
			continue
		if not combat_arrival and NativeTransit.point(encounter) == tile:
			return {"ok": false, "message": "An army occupies the passage entrance."}
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) != actor_id and NativeTransit.point(hero.get("position")) == tile:
			return {"ok": false, "message": "A hero occupies the passage entrance."}
	var lookup := _spatial_lookup_index(session, tile.z)
	if lookup.get("town_by_tile", {}).has(_tile_key(local)):
		return {"ok": false, "message": "A town occupies the passage entrance."}
	for index in _spatial_lookup_entries(lookup, "resource_by_interaction_tile", local):
		var other: Dictionary = session.overworld.resource_nodes[int(index)]
		if String(other.get("placement_id", "")) != id:
			return {"ok": false, "message": "Another site occupies the passage entrance."}
	for index in _spatial_lookup_entries(lookup, "artifact_by_tile", local):
		if not bool(session.overworld.artifact_nodes[int(index)].get("collected", false)):
			return {"ok": false, "message": "Recover the artifact at the passage entrance first."}
	return {"ok": true}

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

static func _stacks_to_recruits(stacks: Array) -> Dictionary:
	var recruits := {}
	for stack in stacks:
		if stack is Dictionary:
			var unit_id := String(stack.get("unit_id", ""))
			recruits[unit_id] = int(recruits.get(unit_id, 0)) + int(stack.get("count", 0))
	return recruits

## Each flagged dwelling adds +1 weekly growth for its creature in every town
## of the same owner that recruits it.
static func _add_dwelling_town_growth(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	growth: Dictionary
) -> Dictionary:
	var controller := _town_controller_id(town)
	if session == null or controller == "" or growth.is_empty():
		return growth
	var held := {}
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or PlayerRules.resource_controller_id(node) != controller:
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not CreatureDwellings.is_dwelling(site) or CreatureDwellings.is_refugee_camp(site):
			continue
		for unit_id in CreatureDwellings.creatures(node, site, session.day):
			var base := CreatureDwellings.base_unit_id(String(unit_id))
			held[base] = int(held.get(base, 0)) + 1
	if held.is_empty():
		return growth
	var result := growth.duplicate(true)
	for unit_id in result.keys():
		var base := CreatureDwellings.base_unit_id(String(unit_id))
		if held.has(base):
			result[unit_id] = int(result[unit_id]) + int(held[base])
	return result

static func collect_active_artifact(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.collect_active_artifact", [session])

static func _collect_artifact_node_result(session: SessionStateStoreScript.SessionData, node_result: Dictionary, refresh_fog_after_action: bool = true) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._collect_artifact_node_result", [session, node_result, refresh_fog_after_action])

static func perform_context_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.perform_context_action", [session, action_id])

static func set_active_town_visit(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	normalize_overworld_state_for_runtime(session)
	if session == null or placement_id == "":
		return {"ok": false, "message": "No town was selected.", "town": {}}
	var town_result := _find_town_by_placement(session, placement_id)
	var town: Dictionary = town_result.get("town", {})
	if int(town_result.get("index", -1)) < 0 or town.is_empty():
		clear_active_town_visit(session)
		return {"ok": false, "message": "The selected town is no longer available.", "town": {}}
	if String(town.get("owner", "neutral")) != "player":
		clear_active_town_visit(session)
		return {"ok": false, "message": "Only owned towns can be managed remotely.", "town": town}
	session.flags[ACTIVE_TOWN_PLACEMENT_KEY] = placement_id
	_active_town_visit_indexes[String(session.session_id)] = int(town_result.get("index", -1))
	_teach_visiting_town_spells(session, town)
	return {
		"ok": true,
		"message": "%s opens its gates." % _town_name(town),
		"town": town,
	}

static func clear_active_town_visit(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"OverworldRules.clear_active_town_visit", [session])

static func active_town_visit_result(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _find_active_town(session)

static func _teach_visiting_town_spells(session: SessionStateStoreScript.SessionData, town: Dictionary) -> void:
	# TownRules also routes overworld orders: resolve lazily, not as a preload cycle.
	var town_rules: GDScript = load("res://scripts/core/TownRules.gd")
	town_rules.teach_visiting_heroes(session, town)

static func _resolve_post_move_interaction(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._resolve_post_move_interaction", [session])

static func award_hero_artifact(
	session: SessionStateStoreScript.SessionData,
	artifact_id: String,
	source_verb: String = "Awarded",
	auto_equip: bool = true,
	evaluate_session: bool = true
) -> Dictionary:
	var result := _apply_artifact_claim(session, artifact_id, source_verb, auto_equip)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Artifact award failed."))}
	if not evaluate_session:
		return result
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func capture_active_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.capture_active_town", [session])

static func capture_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> String:
	if session == null or placement_id == "":
		return ""
	var town_result := _find_town_by_placement(session, placement_id)
	if int(town_result.get("index", -1)) < 0:
		return ""
	return _claim_town(session, town_result)

static func transition_town_control(
	session: SessionStateStoreScript.SessionData,
	placement_id: String,
	new_owner: String,
	controlling_faction_id: String = "",
	source: String = ""
) -> Dictionary:
	if session == null or placement_id == "":
		return {"ok": false, "changed": false, "town": {}}
	var town_result := _find_town_by_placement(session, placement_id)
	if int(town_result.get("index", -1)) < 0:
		return {"ok": false, "changed": false, "town": {}}
	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	var previous_owner := String(town.get("owner", "neutral"))
	var previous_controller := PlayerRules.town_controller_id(town)
	if controlling_faction_id == "" and previous_owner == "enemy":
		controlling_faction_id = previous_controller
	if previous_owner != new_owner and previous_owner == "player":
		town = _release_town_occupation_reserves(town)
	town["owner"] = new_owner
	if new_owner == "enemy":
		town["controlling_faction_id"] = PlayerRules.faction_id(session, controlling_faction_id)
		town["controlling_player_id"] = String(PlayerRules.player(session, controlling_faction_id).get("player_id", ""))
	else:
		town["controlling_faction_id"] = ""
		if new_owner == "player" and String(session.overworld.get("active_player_id", "")) != "":
			town["controlling_player_id"] = String(session.overworld.active_player_id)
		else:
			town.erase("controlling_player_id")
	var owning_player := PlayerRules.player(session, String(town.get("controlling_player_id", "")))
	if not owning_player.is_empty():
		town["team_id"] = String(owning_player.get("team_id", ""))
	else:
		town.erase("team_id")
	town["front"] = _town_front_after_control_change(
		session,
		town,
		previous_owner,
		new_owner,
		controlling_faction_id,
		source
	)
	var available_recruits = town.get("available_recruits", {})
	if new_owner == "player" and (
		not (available_recruits is Dictionary)
		or (previous_owner != "enemy" and available_recruits is Dictionary and available_recruits.is_empty())
	):
		town["available_recruits"] = _seed_recruits_for_town(town)
	town["occupation"] = _town_occupation_after_control_change(
		session,
		town,
		previous_owner,
		new_owner,
		controlling_faction_id,
		source
	)
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	if new_owner == "player":
		_teach_visiting_town_spells(session, town)
	return {
		"ok": true,
		"changed": previous_owner != new_owner or previous_controller != PlayerRules.town_controller_id(town),
		"previous_owner": previous_owner,
		"town": town,
	}

static func describe_encounter_pressure(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	for_battle_prompt: bool = false
) -> String:
	return _encounter_pressure_summary(session, encounter, for_battle_prompt)

static func describe_encounter_readability_surface(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> String:
	var lines := []
	var role_parts := [
		_encounter_role_label(encounter),
		_encounter_risk_label(encounter),
		_encounter_difficulty_label(encounter),
	]
	var role_line := " | ".join(_non_empty_strings(role_parts))
	if role_line != "":
		lines.append("Role: %s" % role_line)
	var army_line := _encounter_army_surface(encounter, true)
	if army_line != "":
		lines.append("Army: %s" % army_line)
	var readiness_line := _encounter_readiness_surface(session, encounter)
	if readiness_line != "":
		lines.append(readiness_line)
	var reward_line := _encounter_reward_surface(encounter)
	if reward_line != "":
		lines.append("Reward: %s" % reward_line)
	var guard_line := _encounter_guard_summary(encounter, session)
	if guard_line != "":
		lines.append(guard_line)
	var consequence_line := describe_encounter_consequence_surface(session, encounter)
	if consequence_line != "":
		lines.append(consequence_line)
	var field_line := _encounter_field_objective_surface(encounter)
	if field_line != "":
		lines.append("Field: %s" % field_line)
	return "\n".join(lines)

static func describe_encounter_compact_readability(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_compact_readability", [session, encounter])

static func describe_encounter_battle_cue(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_battle_cue", [session, encounter])

static func describe_encounter_guard_link_surface(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> String:
	var guard := _encounter_guard_link(encounter)
	if guard.is_empty():
		return ""
	var role := String(guard.get("guard_role", "")).strip_edges()
	if role == "" or role == "none":
		return ""
	var target_label := _encounter_guard_target_label(session, guard)
	var parts := ["Guard %s" % _humanize_id(role)]
	if target_label != "":
		parts.append("Target %s" % target_label)
	if bool(guard.get("clear_required_for_target", false)):
		parts.append("clear required")
	elif bool(guard.get("blocks_approach", false)):
		parts.append("blocks approach")
	return " | ".join(parts)

static func describe_encounter_consequence_surface(session: SessionStateStoreScript.SessionData, encounter: Dictionary, compact: bool = false) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_encounter_consequence_surface", [session, encounter, compact])

static func build_in_active_town(session: SessionStateStoreScript.SessionData, building_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.build_in_active_town", [session, building_id])

static func recruit_in_active_town(session: SessionStateStoreScript.SessionData, unit_id: String, requested_count: int = -1, runtime_normalized: bool = false) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.recruit_in_active_town", [session, unit_id, requested_count, runtime_normalized])

static func cast_overworld_spell(session: SessionStateStoreScript.SessionData, spell_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.cast_overworld_spell", [session, spell_id])

static func equip_artifact(session: SessionStateStoreScript.SessionData, artifact_id: String) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRulesScript.equip_artifact(session.overworld.get("hero", {}), artifact_id)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to equip artifact."))}

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

static func unequip_artifact(session: SessionStateStoreScript.SessionData, slot: String) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRulesScript.unequip_artifact(session.overworld.get("hero", {}), slot)
	if not bool(result.get("ok", false)):
		return {"ok": false, "message": String(result.get("message", "Unable to stow artifact."))}

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return _finalize_action_result(session, true, String(result.get("message", "")))

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

static func _resource_node_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	var nodes = session.overworld.get("resource_nodes", [])
	var lookup_index := _spatial_lookup_index(session)
	for node_index in _spatial_lookup_entries(lookup_index, "resource_by_tile", Vector2i(x, y)):
		var node = nodes[int(node_index)] if nodes is Array and int(node_index) >= 0 and int(node_index) < nodes.size() else {}
		if node is Dictionary:
			return node
	return {}

static func _encounter_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	var encounters = session.overworld.get("encounters", [])
	var lookup_index := _spatial_lookup_index(session)
	for encounter_index in _spatial_lookup_entries(lookup_index, "encounter_by_tile", Vector2i(x, y)):
		var encounter = encounters[int(encounter_index)] if encounters is Array and int(encounter_index) >= 0 and int(encounter_index) < encounters.size() else {}
		if encounter is Dictionary:
			return encounter
	return {}

static func encounter_commander_name(encounter: Dictionary) -> String:
	if encounter.is_empty() or String(encounter.get("spawned_by_faction_id", "")) == "":
		return ""
	return String(_enemy_adventure_rules().raid_commander_display_name(encounter))

static func encounter_commander_threat_label(encounter: Dictionary) -> String:
	var commander_name := encounter_commander_name(encounter)
	if commander_name == "":
		return ""
	var memory_brief := String(_enemy_adventure_rules().commander_memory_brief(encounter.get("enemy_commander_state", {})))
	var army_brief := String(_enemy_adventure_rules().commander_army_brief(encounter.get("enemy_commander_state", {})))
	var outcome_brief := String(_enemy_adventure_rules().commander_recent_outcome_brief(encounter.get("enemy_commander_state", {})))
	var parts := []
	if outcome_brief != "":
		parts.append(outcome_brief)
	if memory_brief != "":
		parts.append(memory_brief)
	if army_brief != "":
		parts.append(army_brief)
	if parts.is_empty():
		return commander_name
	return "%s (%s)" % [commander_name, "; ".join(parts)]

static func encounter_display_name(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return "Hostile contact"
	if String(encounter.get("spawned_by_faction_id", "")) != "":
		var raid_name: String = String(_enemy_adventure_rules().raid_display_name(encounter))
		if raid_name != "":
			return raid_name
	var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	return String(encounter_def.get("name", encounter.get("placement_id", "Hostile contact")))

static func is_encounter_resolved(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	var resolved = session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		return false
	var cached := _resolved_lookup_entry(session)
	if not bool(cached[3]):
		return encounter_key(encounter) in resolved
	return cached[2].has(encounter_key(encounter))

## The resolved encounter keys as a set: shared, read-only. The list only ever
## grows in place, so the set is rebuilt when it grows or is replaced.
static func resolved_encounter_lookup(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return _resolved_lookup_entry(session)[2]

## [list, its size, set of String(key), whether every key is a String or
## StringName], kept in session meta.
static func _resolved_lookup_entry(session: SessionStateStoreScript.SessionData) -> Array:
	var resolved = session.overworld.get("resolved_encounters", [])
	var size: int = resolved.size() if resolved is Array else -1
	var cached: Array = session.get_meta(RESOLVED_LOOKUP_META, [])
	if cached.size() == 4 and is_same(cached[0], resolved) and int(cached[1]) == size:
		return cached
	var lookup := {}
	var strings_only := true
	if resolved is Array:
		for value in resolved:
			lookup[String(value)] = true
			if not (value is String or value is StringName):
				strings_only = false
	cached = [resolved, size, lookup, strings_only]
	session.set_meta(RESOLVED_LOOKUP_META, cached)
	return cached

static func encounter_key(encounter: Dictionary) -> String:
	var placement_id := String(encounter.get("placement_id", ""))
	if placement_id != "":
		return placement_id
	return "%d,%d,%s" % [
		int(encounter.get("x", -1)),
		int(encounter.get("y", -1)),
		String(encounter.get("encounter_id", encounter.get("id", "")))
	]

static func hero_position(session: SessionStateStoreScript.SessionData) -> Vector2i:
	var pos = session.overworld.get("hero_position", {"x": 0, "y": 0})
	return Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))

static func hero_level(session: SessionStateStoreScript.SessionData) -> int:
	return OverworldLevelRulesScript.hero_level(session)

static func map_for_level(session: SessionStateStoreScript.SessionData, level: int = -1) -> Array:
	return OverworldLevelRulesScript.terrain_rows(session, level)

static func derive_map_size(session: SessionStateStoreScript.SessionData) -> Vector2i:
	var stored_size = session.overworld.get("map_size", {})
	if stored_size is Dictionary:
		var width := int(stored_size.get("width", 0))
		var height := int(stored_size.get("height", 0))
		if width > 0 and height > 0:
			return Vector2i(width, height)

	var map_data = session.overworld.get("map", [])
	var height_from_map = map_data.size() if map_data is Array else 0
	var width_from_map := 0
	if height_from_map > 0 and map_data[0] is Array:
		width_from_map = map_data[0].size()
	return Vector2i(max(width_from_map, 1), max(height_from_map, 1))

static func overworld_object_placement_pathing_surface(
	session: SessionStateStoreScript.SessionData,
	placement_id: String
) -> Dictionary:
	if session == null or placement_id == "":
		return {}
	var node_result := _find_resource_node_by_placement(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0 or node.is_empty():
		return {}
	var map_object := _map_object_for_resource_node(node)
	if map_object.is_empty():
		return {}
	var body_tiles := _map_object_world_body_tiles(map_object, node)
	var interaction_tiles := _resource_node_world_interaction_tiles(map_object, node)
	var footprint: Dictionary = map_object.get("footprint", {}) if map_object.get("footprint", {}) is Dictionary else {}
	var width: int = maxi(1, int(footprint.get("width", 1)))
	var height: int = maxi(1, int(footprint.get("height", 1)))
	var origin := _map_object_footprint_origin(map_object, node)
	var body_payload := []
	for tile in body_tiles:
		body_payload.append(_tile_payload(tile))
	var interaction_payload := []
	for tile in interaction_tiles:
		interaction_payload.append(_tile_payload(tile))
	return {
		"placement_id": placement_id,
		"site_id": String(node.get("site_id", "")),
		"object_id": String(map_object.get("id", "")),
		"footprint": {
			"width": width,
			"height": height,
			"anchor": String(footprint.get("anchor", "bottom_center")),
			"origin": _tile_payload(origin),
			"visual_tile_count": width * height,
		},
		"body_tiles": body_payload,
		"interaction_tiles": interaction_payload,
		"body_tile_count": body_payload.size(),
		"interaction_tile_count": interaction_payload.size(),
		"uses_authored_body_tiles": map_object.get("body_tiles", []) is Array and not map_object.get("body_tiles", []).is_empty(),
		"uses_runtime_body_tiles": _resource_node_has_runtime_object_contract(node),
		"uses_runtime_visit_tile": _resource_node_has_runtime_visit_tile(node),
		"uses_authored_approach": map_object.get("approach", {}) is Dictionary and not map_object.get("approach", {}).is_empty(),
		"blocks_body_tiles": _resource_node_blocks_body_tiles(node, map_object),
		"blocks_visual_footprint_rectangle": false,
	}

static func blocking_object_feedback_surface_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	return HumanEngine.native(&"OverworldRules.blocking_object_feedback_surface_at_tile", [session, x, y])

static func tile_is_blocked(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.tile_is_blocked", [session, x, y, level])

static func terrain_id_is_passable(terrain_id: String) -> bool:
	# Route searches ask this for every neighbour; the biome table only changes
	# when content is reloaded, so remember each terrain id's answer until then.
	var revision := ContentService.get_content_revision()
	if revision != _terrain_passable_cache_revision:
		_terrain_passable_cache.clear()
		_terrain_passable_cache_revision = revision
	var cached: Variant = _terrain_passable_cache.get(terrain_id)
	if cached != null:
		return cached
	var passable := _terrain_id_is_passable_uncached(terrain_id)
	_terrain_passable_cache[terrain_id] = passable
	return passable

static func _terrain_id_is_passable_uncached(terrain_id: String) -> bool:
	var normalized := ContentService.normalize_terrain_id(String(terrain_id))
	if normalized in ["rock", "water"]:
		return false
	var biome := ContentService.get_biome_for_terrain(normalized)
	if not biome.is_empty() and biome.has("passable"):
		return bool(biome.get("passable", true))
	return true

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

static func _tile_blocked_by_resource_object(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> bool:
	if session == null:
		return false
	return _blocked_tile_index(session).has(_tile_key(tile))

static func _refresh_blocked_tile_index(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var capture_enabled := bool(_pathing_debug_profile.get("capture_enabled", false))
	var started_usec := Time.get_ticks_usec() if capture_enabled else 0
	var resource_nodes = session.overworld.get("resource_nodes", [])
	var level_indexes := {}
	for level in range(OverworldLevelRulesScript.level_count(session)):
		level_indexes[level] = _build_blocked_tile_index(session, level)
	session.set_meta(BLOCKED_TILE_INDEX_META, level_indexes)
	var index: Dictionary = level_indexes.get(hero_level(session), {})
	_rules_profile_set("blocked_index", "rebuilt", true)
	_rules_profile_set("blocked_index", "node_count", resource_nodes.size() if resource_nodes is Array else 0)
	_rules_profile_set("blocked_index", "tile_count", index.size())
	if not capture_enabled:
		return
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
	_pathing_debug_profile["blocked_index_rebuild_count"] = int(_pathing_debug_profile.get("blocked_index_rebuild_count", 0)) + 1
	_pathing_debug_profile["last_blocked_index_rebuild_usec"] = elapsed_usec
	_pathing_debug_profile["last_blocked_index_tile_count"] = index.size()
	_pathing_debug_profile["last_blocked_index_session_id"] = str(session.session_id)

static func _refresh_blocked_tile_index_for_interaction(session: SessionStateStoreScript.SessionData, topology_facts: Dictionary) -> void:
	HumanEngine.native_writing(&"OverworldRules._refresh_blocked_tile_index_for_interaction", [session, topology_facts])

static func _blocked_tile_index(session: SessionStateStoreScript.SessionData, level: int = -1) -> Dictionary:
	if session == null:
		return {}
	if not session.has_meta(BLOCKED_TILE_INDEX_META):
		_refresh_blocked_tile_index(session)
	var level_indexes: Dictionary = session.get_meta(BLOCKED_TILE_INDEX_META, {})
	return level_indexes.get(OverworldLevelRulesScript.query_level(session, level), {})

static func _spatial_lookup_index(session: SessionStateStoreScript.SessionData, level: int = -1) -> Dictionary:
	if session == null:
		return {}
	var signature := _spatial_lookup_signature(session)
	if not session.has_meta(SPATIAL_LOOKUP_INDEX_META) or session.get_meta(SPATIAL_LOOKUP_SIGNATURE_META, []) != signature:
		session.set_meta(SPATIAL_LOOKUP_INDEX_META, {})
		session.set_meta(SPATIAL_LOOKUP_SIGNATURE_META, signature)
	var resolved_level := OverworldLevelRulesScript.query_level(session, level)
	var levels: Dictionary = session.get_meta(SPATIAL_LOOKUP_INDEX_META)
	if not levels.has(resolved_level):
		levels[resolved_level] = _build_spatial_lookup_index(session, resolved_level)
	return levels[resolved_level]

static func invalidate_spatial_lookup(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	session.remove_meta(SPATIAL_LOOKUP_INDEX_META)
	session.remove_meta(SPATIAL_LOOKUP_SIGNATURE_META)

static func _spatial_lookup_signature(session: SessionStateStoreScript.SessionData) -> Array:
	# Route searches consult this once per neighbour, so compare plain values
	# instead of formatting and joining a string on every lookup.
	if session == null:
		return []
	return [
		session.scenario_id,
		derive_map_size(session),
		OverworldLevelRulesScript.level_count(session),
		_collection_size(session.overworld.get("towns", [])),
		_collection_size(session.overworld.get("resource_nodes", [])),
		_collection_size(session.overworld.get("artifact_nodes", [])),
		_collection_size(session.overworld.get("encounters", [])),
	]

static func placement_level(session: SessionStateStoreScript.SessionData, placement_id: String, fallback: int = 0) -> int:
	if session == null or placement_id == "":
		return fallback
	# Placement identity is global even though tile indexes are per level.
	var index := _spatial_lookup_index(session, 0)
	for pair in [["town_by_placement", "towns"], ["encounter_by_placement", "encounters"], ["resource_by_placement", "resource_nodes"], ["artifact_by_placement", "artifact_nodes"]]:
		var rows: Array = session.overworld.get(pair[1], [])
		var ordinal := int(index.get(pair[0], {}).get(placement_id, -1))
		if ordinal >= 0 and ordinal < rows.size():
			return OverworldLevelRulesScript.level_of(rows[ordinal])
	return fallback

static func _build_spatial_lookup_index(session: SessionStateStoreScript.SessionData, level: int = 0) -> Dictionary:
	var index := {
		"town_by_tile": {},
		"town_by_placement": {},
		"resource_by_tile": {},
		"resource_by_interaction_tile": {},
		"resource_by_placement": {},
		"artifact_by_tile": {},
		"artifact_by_placement": {},
		"encounter_by_tile": {},
		"encounter_by_placement": {},
		"guard_engagement_by_tile": {},
	}
	var towns = session.overworld.get("towns", [])
	if towns is Array:
		var town_by_tile: Dictionary = index["town_by_tile"]
		for town_index in range(towns.size()):
			var town = towns[town_index]
			if town is Dictionary:
				var placement_id := String(town.get("placement_id", ""))
				if placement_id != "":
					index["town_by_placement"][placement_id] = town_index
				if not OverworldLevelRulesScript.on_level(town, level):
					continue
				town_by_tile[_tile_key(Vector2i(int(town.get("x", -1)), int(town.get("y", -1))))] = town_index
				var visit_tile = town.get("visit_tile", {})
				if visit_tile is Dictionary and not visit_tile.is_empty():
					town_by_tile[_tile_key(Vector2i(int(visit_tile.get("x", -1)), int(visit_tile.get("y", -1))))] = town_index
	var resources = session.overworld.get("resource_nodes", [])
	if resources is Array:
		var resource_section := _spatial_resource_section(session, resources, level)
		index["resource_by_tile"] = resource_section[0]
		index["resource_by_interaction_tile"] = resource_section[1]
		index["resource_by_placement"] = resource_section[2]
	var artifacts = session.overworld.get("artifact_nodes", [])
	if artifacts is Array:
		for artifact_index in range(artifacts.size()):
			var artifact = artifacts[artifact_index]
			if artifact is Dictionary:
				var artifact_placement_id := String(artifact.get("placement_id", ""))
				if artifact_placement_id != "":
					index["artifact_by_placement"][artifact_placement_id] = artifact_index
				if not OverworldLevelRulesScript.on_level(artifact, level):
					continue
				_append_spatial_lookup_entry(
					index["artifact_by_tile"],
					_tile_key(Vector2i(int(artifact.get("x", -1)), int(artifact.get("y", -1)))),
					artifact_index
				)
	var encounters = session.overworld.get("encounters", [])
	if encounters is Array:
		for encounter_index in range(encounters.size()):
			var encounter = encounters[encounter_index]
			if encounter is Dictionary:
				var encounter_placement_id := String(encounter.get("placement_id", encounter.get("id", "")))
				if encounter_placement_id != "":
					index["encounter_by_placement"][encounter_placement_id] = encounter_index
				if not OverworldLevelRulesScript.on_level(encounter, level):
					continue
				_append_spatial_lookup_entry(
					index["encounter_by_tile"],
					_tile_key(Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))),
					encounter_index
				)
				if _encounter_has_guard_engagement_surface(encounter):
					for engagement_tile in _guard_engagement_world_tiles(encounter):
						if engagement_tile is Vector2i:
							_append_spatial_lookup_entry(
								index["guard_engagement_by_tile"],
								_tile_key(engagement_tile),
								encounter_index
							)
				elif _ai_hero_guards_against_player(session, encounter):
					for zone_tile in hero_guard_zone_tiles(session, Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))), level):
						_append_spatial_lookup_entry(index["guard_engagement_by_tile"], _tile_key(zone_tile), encounter_index)
	return index

## The resource tables of one level's spatial index: [by tile, by interaction
## tile, by placement]. AI moves drop the whole index many times a day while the
## sites keep their places, so a level's tables are kept for as long as every
## node still has the fields they are built from, and the site and object
## content is unchanged. Nothing edits the tables after they are built.
static func _spatial_resource_section(session: SessionStateStoreScript.SessionData, resources: Array, level: int) -> Array:
	# Every node field the tables read: the placement id, the tile and level,
	# and what picks the map object and its interaction tiles.
	var fingerprint := []
	for node in resources:
		fingerprint.append([
			node.get("placement_id", SPATIAL_FINGERPRINT_MISSING),
			node.get("x", SPATIAL_FINGERPRINT_MISSING),
			node.get("y", SPATIAL_FINGERPRINT_MISSING),
			node.get("level", SPATIAL_FINGERPRINT_MISSING),
			node.get("position", SPATIAL_FINGERPRINT_MISSING),
			node.get("visit_tile", SPATIAL_FINGERPRINT_MISSING),
			node.get("primary_tile", SPATIAL_FINGERPRINT_MISSING),
			node.get("kind", SPATIAL_FINGERPRINT_MISSING),
			node.get("site_id", SPATIAL_FINGERPRINT_MISSING),
			node.get("object_id", SPATIAL_FINGERPRINT_MISSING),
		] if node is Dictionary else null)
	var revision := ContentService.get_content_revision()
	var map_objects := ContentService.load_json(ContentService.MAP_OBJECTS_PATH)
	var resource_sites := ContentService.load_json(ContentService.RESOURCE_SITES_PATH)
	# level -> [content revision, map objects, resource sites, fingerprint copy, tables]
	var sections: Dictionary = session.get_meta(SPATIAL_RESOURCE_SECTIONS_META, {})
	var cached: Array = sections.get(level, [])
	if (
		cached.size() == 5
		and int(cached[0]) == revision
		and is_same(cached[1], map_objects)
		and is_same(cached[2], resource_sites)
		and cached[3] == fingerprint
	):
		return cached[4]
	var section := _build_spatial_resource_section(resources, level)
	# The copy keeps the fields as they are now, should a node be edited in place.
	sections[level] = [revision, map_objects, resource_sites, fingerprint.duplicate(true), section]
	session.set_meta(SPATIAL_RESOURCE_SECTIONS_META, sections)
	return section

static func _build_spatial_resource_section(resources: Array, level: int) -> Array:
	var by_tile := {}
	var by_interaction_tile := {}
	var by_placement := {}
	for node_index in range(resources.size()):
		var node = resources[node_index]
		if not (node is Dictionary):
			continue
		var resource_placement_id := String(node.get("placement_id", ""))
		if resource_placement_id != "":
			by_placement[resource_placement_id] = node_index
		if not OverworldLevelRulesScript.on_level(node, level):
			continue
		var node_tile_key := _tile_key(Vector2i(int(node.get("x", -1)), int(node.get("y", -1))))
		_append_spatial_lookup_entry(by_tile, node_tile_key, node_index)
		var map_object := _map_object_for_resource_node(node)
		for interaction_tile in _resource_node_world_interaction_tiles(map_object, node):
			if interaction_tile is Vector2i:
				_append_spatial_lookup_entry(by_interaction_tile, _tile_key(interaction_tile), node_index)
	return [by_tile, by_interaction_tile, by_placement]

static func _append_spatial_lookup_entry(index_value: Variant, key: String, entry_index: int) -> void:
	if not (index_value is Dictionary) or key == "":
		return
	var index: Dictionary = index_value
	var entries: Array = index.get(key, []) if index.get(key, []) is Array else []
	entries.append(entry_index)
	index[key] = entries

static func _find_guard_engagement_at_tile(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1, include_heroes: bool = true) -> Dictionary:
	if session == null:
		return {"index": -1, "encounter": {}}
	var encounters = session.overworld.get("encounters", [])
	var lookup_index := _spatial_lookup_index(session, level)
	for encounter_index in _spatial_lookup_entries(lookup_index, "guard_engagement_by_tile", Vector2i(x, y)):
		var index := int(encounter_index)
		var encounter = encounters[index] if encounters is Array and index >= 0 and index < encounters.size() else {}
		if not include_heroes and encounter is Dictionary and encounter.get("ai_hero", null) is Dictionary:
			continue
		if encounter is Dictionary and not is_encounter_resolved(session, encounter):
			return {"index": index, "encounter": encounter}
	return {"index": -1, "encounter": {}}

static func _encounter_has_guard_engagement_surface(encounter: Dictionary) -> bool:
	if encounter.is_empty():
		return false
	var kind := String(encounter.get("kind", encounter.get("package_kind", encounter.get("native_record_kind", ""))))
	var package_kind := String(encounter.get("package_kind", ""))
	var native_kind := String(encounter.get("native_record_kind", ""))
	if kind == "guard" or package_kind == "guard" or native_kind == "guard":
		return true
	if encounter.get("package_guard_engagement_tiles", null) is Array:
		return true
	if encounter.get("package_guard_control_zone_tiles", null) is Array:
		return true
	return String(encounter.get("guard_kind", "")).strip_edges() != ""

## Heroes guard the tiles around them, as neutral armies do: a hero that steps
## next to a hostile hero fights it there, so no army walks past another one.
## A hero inside a town (on its doorway) leaves its defence to the town, and a
## hero on land does not reach a boat at sea or the other way round. Before
## 2026-10-09 a hero blocked only its own tile and rival heroes walked right
## past the player's main hero.
static func hero_guard_zone_tiles(session: SessionStateStoreScript.SessionData, tile: Vector2i, level: int) -> Array:
	if session == null or _town_entrance_at(session, tile, level):
		return []
	var size := derive_map_size(session)
	var on_water := WaterTravel.is_water(session, tile.x, tile.y, level)
	var tiles := []
	for offset in WaterTravel.NEIGHBORS:
		var next: Vector2i = tile + offset
		if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
			continue
		if WaterTravel.is_water(session, next.x, next.y, level) != on_water:
			continue
		tiles.append(next)
	return tiles

## Whether a hero standing on this tile guards it against the human: a computer
## player's hero that is not the human's ally.
static func _ai_hero_guards_against_player(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	if not (encounter.get("ai_hero", null) is Dictionary):
		return false
	var controller := PlayerRules.raid_controller_id(encounter)
	return controller != "" and not PlayerRules.allied(session, controller, "player")

static func _town_entrance_at(session: SessionStateStoreScript.SessionData, tile: Vector2i, level: int) -> bool:
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var entrance := OverworldLevelRulesScript.town_entrance(town)
		if OverworldLevelRulesScript.level_of(entrance) == level and int(entrance.get("x", -1)) == tile.x and int(entrance.get("y", -1)) == tile.y:
			return true
	return false

static func _guard_engagement_world_tiles(encounter: Dictionary) -> Array:
	for key in ["package_guard_engagement_tiles", "package_guard_control_zone_tiles", "guard_control_zone_tiles"]:
		var tiles = encounter.get(key, null)
		if tiles is Array:
			var world_tiles := _world_tiles_from_payload_array(tiles)
			if not world_tiles.is_empty():
				return world_tiles
	if not _encounter_has_guard_engagement_surface(encounter):
		return []
	return [Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))]

static func _spatial_lookup_entries(index: Dictionary, name: String, tile: Vector2i) -> Array:
	var table: Dictionary = index.get(name, {}) if index.get(name, {}) is Dictionary else {}
	return table.get(_tile_key(tile), []) if table.get(_tile_key(tile), []) is Array else []

static func _build_blocked_tile_index(session: SessionStateStoreScript.SessionData, level: int = -1, ignore_actor_id: String = "", combat_defenders: Dictionary = {}) -> Dictionary:
	return DayEngine.native_writing(&"OverworldRules._build_blocked_tile_index", [session, level, ignore_actor_id, combat_defenders])

## The tiles the map objects block on one level, each set to true in the order
## the blocked index first meets them. Map objects are scenery: the session is
## built with them and nothing edits one in place, so a level's layer is kept
## until the list is replaced, resized or has an entry replaced.
static func _blocked_scenery_layer(session: SessionStateStoreScript.SessionData, level: int) -> Dictionary:
	var objects: Variant = session.overworld.get("map_objects", [])
	if not (objects is Array):
		return _build_blocked_scenery_layer(objects, level)
	# [list, a shallow copy of it, level -> layer]. Comparing the copy is cheap:
	# an entry that is still the same dictionary compares equal at once.
	var cached: Array = session.get_meta(BLOCKED_SCENERY_LAYERS_META, [])
	if cached.size() != 3 or not is_same(cached[0], objects) or cached[1] != objects:
		cached = [objects, objects.duplicate(), {}]
		session.set_meta(BLOCKED_SCENERY_LAYERS_META, cached)
	var layers: Dictionary = cached[2]
	if not layers.has(level):
		layers[level] = _build_blocked_scenery_layer(objects, level)
	return layers[level]

static func _build_blocked_scenery_layer(objects: Variant, level: int) -> Dictionary:
	var layer := {}
	for object_value in objects:
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		if not OverworldLevelRulesScript.on_level(object, level):
			continue
		var kind := String(object.get("kind", ""))
		var family := String(object.get("object_family_id", object.get("family_id", "")))
		var blocks_body := bool(object.get("blocking_body", kind == "decorative_obstacle" or family == "decorative_obstacle"))
		_append_generated_body_tiles_to_blocked_index(layer, object, blocks_body)
	return layer

static func _append_generated_body_tiles_to_blocked_index(index: Dictionary, placement: Dictionary, blocks_body: bool) -> void:
	for body_tile in _generated_body_tiles_for_placement(placement, blocks_body):
		index[_tile_key(body_tile)] = true

## Every tile a town stands on: its blocking body and its entrance.
static func town_footprint_tiles(town: Dictionary) -> Array:
	var tiles := _generated_body_tiles_for_placement(town, true)
	var entrance := OverworldLevelRulesScript.town_entrance(town)
	var entrance_tile := Vector2i(int(entrance.get("x", -1)), int(entrance.get("y", -1)))
	if entrance_tile.x >= 0 and entrance_tile.y >= 0 and entrance_tile not in tiles:
		tiles.append(entrance_tile)
	return tiles

## A town completes at most one build order per day.
static func town_built_today(town: Dictionary, day: int) -> bool:
	return HumanEngine.native(&"OverworldRules.town_built_today", [town, day])

## True when the player's hero has used today's overworld spell.
static func hero_cast_spell_today(session: SessionStateStoreScript.SessionData, hero_id: String) -> bool:
	if session == null or hero_id == "":
		return false
	var hero: Dictionary = session.overworld.get("hero", {}) if hero_id == String(session.overworld.get("active_hero_id", "")) else HeroCommandRulesScript.hero_by_id(session, hero_id)
	return SpellRulesScript.cast_overworld_spell_on_day(hero, int(session.day))

## Every tile a mine stands on: its body and its entrance. Empty if the node is not a mine.
static func mine_footprint_tiles(node: Dictionary) -> Array:
	if String(node.get("kind", "")) == "reward_reference":
		return []
	if not Mines.resource(node).is_empty():
		return Mines.body_tiles(node)
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if String(site.get("family", "")) != "mine" and String(node.get("kind", "")) != "mine":
		return []
	var map_object := _map_object_for_resource_node(node)
	var tiles := _map_object_world_body_tiles(map_object, node)
	for tile in _resource_node_world_interaction_tiles(map_object, node):
		if tile not in tiles:
			tiles.append(tile)
	return tiles

static func _generated_body_tiles_for_placement(placement: Dictionary, blocks_body: bool) -> Array:
	if not blocks_body:
		return []
	var block_payload: Variant = placement.get("package_block_tiles", null)
	var body_tiles := _world_tiles_from_payload_array(block_payload) if block_payload is Array else []
	if body_tiles.is_empty() and block_payload is Array:
		return []
	if body_tiles.is_empty():
		body_tiles = _world_tiles_from_payload_array(placement.get("body_tiles", []))
	if body_tiles.is_empty():
		body_tiles = [Vector2i(int(placement.get("x", -1)), int(placement.get("y", -1)))]
	var valid_tiles := []
	for body_tile in body_tiles:
		if body_tile is Vector2i and body_tile.x >= 0 and body_tile.y >= 0:
			valid_tiles.append(body_tile)
	return valid_tiles

static func _map_object_for_resource_node(node: Dictionary) -> Dictionary:
	var object_id := String(node.get("object_id", "")).strip_edges()
	if object_id != "":
		var direct := ContentService.get_map_object(object_id)
		if not direct.is_empty():
			return direct
	return ContentService.get_map_object_for_resource_site(String(node.get("site_id", "")))

static func _map_object_blocks_body_tiles(map_object: Dictionary) -> bool:
	var body_tiles = map_object.get("body_tiles", [])
	if not (body_tiles is Array) or body_tiles.is_empty():
		return false
	var passability_class := String(map_object.get("passability_class", ""))
	if passability_class in ["passable_visit_on_enter", "passable_scenic"]:
		return false
	if passability_class in ["blocking_visitable", "blocking_non_visitable", "edge_blocker", "conditional_pass", "town_blocking", "neutral_stack_blocking"]:
		return true
	return not bool(map_object.get("passable", true))

static func _resource_node_blocks_body_tiles(node: Dictionary, map_object: Dictionary) -> bool:
	# Source masks describe the original placement, not its consumed lifetime.
	# Keep them immutable while removing occupancy with the vanished pickup.
	if not resource_node_is_present(node):
		return false
	if not Mines.resource(node).is_empty(): return true
	if node.get("package_block_tiles", null) is Array:
		return not _world_tiles_from_payload_array(node.get("package_block_tiles", [])).is_empty()
	if map_object.is_empty():
		return bool(node.get("blocking_body", false))
	var passability_class := String(map_object.get("passability_class", ""))
	if passability_class in ["passable_visit_on_enter", "passable_scenic"]:
		return false
	if _resource_node_has_runtime_object_contract(node):
		return bool(node.get("blocking_body", _map_object_blocks_body_tiles(map_object)))
	return _map_object_blocks_body_tiles(map_object)

static func _map_object_world_body_tiles(map_object: Dictionary, placement: Dictionary) -> Array:
	if not Mines.resource(placement).is_empty(): return Mines.block_tiles(placement)
	if placement.get("package_block_tiles", null) is Array:
		var package_tiles := _world_tiles_from_payload_array(placement.get("package_block_tiles", []))
		if not package_tiles.is_empty():
			return package_tiles
	if _resource_node_has_runtime_object_contract(placement):
		var runtime_tiles := _world_tiles_from_payload_array(placement.get("package_block_tiles", []))
		if not runtime_tiles.is_empty():
			return runtime_tiles
		runtime_tiles = _world_tiles_from_payload_array(placement.get("body_tiles", []))
		if not runtime_tiles.is_empty():
			return runtime_tiles
	var tiles := []
	var origin := _map_object_footprint_origin(map_object, placement)
	var body_tiles = map_object.get("body_tiles", [])
	if not (body_tiles is Array):
		return tiles
	for body_value in body_tiles:
		if not (body_value is Dictionary):
			continue
		tiles.append(origin + Vector2i(int(body_value.get("x", 0)), int(body_value.get("y", 0))))
	return tiles

static func _resource_node_world_interaction_tiles(map_object: Dictionary, placement: Dictionary) -> Array:
	if not Mines.resource(placement).is_empty(): return [Mines.entry_tile(placement)]
	if _resource_node_has_runtime_visit_tile(placement):
		var visit_tile: Dictionary = placement.get("visit_tile", {})
		return [Vector2i(int(visit_tile.get("x", 0)), int(visit_tile.get("y", 0)))]
	if String(map_object.get("passability_class", "")) == "passable_visit_on_enter":
		return [Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0)))]
	return _map_object_world_interaction_tiles(map_object, placement)

static func _map_object_world_interaction_tiles(map_object: Dictionary, placement: Dictionary) -> Array:
	var tiles := []
	var origin := _map_object_footprint_origin(map_object, placement)
	var approach: Dictionary = map_object.get("approach", {}) if map_object.get("approach", {}) is Dictionary else {}
	var offsets = approach.get("visit_offsets", [])
	if offsets is Array and not offsets.is_empty():
		for offset_value in offsets:
			if not (offset_value is Dictionary):
				continue
			tiles.append(origin + Vector2i(int(offset_value.get("x", 0)), int(offset_value.get("y", 0))))
		return tiles
	return [Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0)))]

static func _resource_node_has_runtime_object_contract(node: Dictionary) -> bool:
	return node.get("object_footprint_catalog_ref", {}) is Dictionary and not node.get("object_footprint_catalog_ref", {}).is_empty()

static func _resource_node_has_runtime_visit_tile(node: Dictionary) -> bool:
	return node.get("visit_tile", {}) is Dictionary and not node.get("visit_tile", {}).is_empty()

static func _world_tiles_from_payload_array(payload: Variant) -> Array:
	var tiles := []
	if not (payload is Array):
		return tiles
	for value in payload:
		if not (value is Dictionary):
			continue
		tiles.append(Vector2i(int(value.get("x", 0)), int(value.get("y", 0))))
	return tiles

static func _map_object_footprint_origin(map_object: Dictionary, placement: Dictionary) -> Vector2i:
	if not Mines.resource(placement).is_empty(): return Mines.origin(placement)
	var footprint: Dictionary = map_object.get("footprint", {}) if map_object.get("footprint", {}) is Dictionary else {}
	var width: int = maxi(1, int(footprint.get("width", 1)))
	var height: int = maxi(1, int(footprint.get("height", 1)))
	var anchor := String(footprint.get("anchor", "bottom_center"))
	var anchor_tile := Vector2i(int(placement.get("x", 0)), int(placement.get("y", 0)))
	match anchor:
		"top_left":
			return anchor_tile
		"center":
			return anchor_tile - Vector2i(int(width / 2), int(height / 2))
		"bottom_left":
			return anchor_tile - Vector2i(0, height - 1)
		"bottom_right":
			return anchor_tile - Vector2i(width - 1, height - 1)
		_:
			return anchor_tile - Vector2i(int(width / 2), height - 1)

static func _resource_node_matches_interaction_tile(node: Dictionary, tile: Vector2i) -> bool:
	var map_object := _map_object_for_resource_node(node)
	if map_object.is_empty():
		return _position_matches(node, tile)
	for interaction_tile in _resource_node_world_interaction_tiles(map_object, node):
		if interaction_tile == tile:
			return true
	return false

static func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

static func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

static func terrain_profile_at(session: SessionStateStoreScript.SessionData, x: int, y: int) -> Dictionary:
	var terrain_id := _terrain_id_at(session, x, y)
	var biome := ContentService.get_biome_for_terrain(terrain_id)
	if biome.is_empty():
		return {
			"terrain_id": terrain_id,
			"name": terrain_id.capitalize() if terrain_id != "" else "Unknown terrain",
			"movement_cost": 1,
			"sight_modifier": 0,
			"passable": terrain_id_is_passable(terrain_id),
		}
	var profile := biome.duplicate(true)
	profile["terrain_id"] = terrain_id
	return profile

static func describe_resources(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resources", [session])

static func describe_resource_stockpile(resources: Variant, include_zero_rare: bool = false) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resource_stockpile", [resources, include_zero_rare])

static func describe_status(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var pos := hero_position(session)
	var movement = session.overworld.get("movement", {})
	var days_until_growth := days_until_next_weekly_growth(session.day)
	return "Week %d Day %d | Pos %d,%d | Move %d/%d | %s | Muster Day %d in %d day%s" % [
		_week_of_day(session.day),
		_weekday_of_day(session.day),
		pos.x,
		pos.y,
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		describe_visibility(session),
		next_weekly_growth_day(session.day),
		days_until_growth,
		"" if days_until_growth == 1 else "s",
	]

static func describe_objective_brief(session: SessionStateStoreScript.SessionData) -> String:
	return _describe_objective_brief_from_surface(_objective_stakes_surface(session))

static func describe_objective_header_surfaces(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var surface := _objective_stakes_surface(session)
	var progress_recap := ""
	if not surface.is_empty():
		progress_recap = _scenario_rules().describe_session_progress_recap_from_normalized_session(session, false, surface)
	return {
		"objective_brief": _describe_objective_brief_from_surface(surface),
		"objective_stakes": _describe_objective_stakes_board_from_surface(session, surface, {"progress_recap": progress_recap}),
		"progress_recap": progress_recap,
	}

static func _describe_objective_brief_from_surface(surface: Dictionary) -> String:
	if surface.is_empty():
		return "Objectives unavailable"

	var line := "%s | Objectives %d/%d" % [
		String(surface.get("mode_label", "Scenario")),
		int(surface.get("victory_met", 0)),
		int(surface.get("victory_total", 0)),
	]
	var next_objective := String(surface.get("next_objective", ""))
	if next_objective != "":
		line += " | Next %s" % _short_player_text(next_objective, 32)
	elif int(surface.get("victory_total", 0)) > 0:
		line += " | Victory ready"
	var watch_objective := String(surface.get("watch_objective", ""))
	if watch_objective != "":
		line += " | Watch %s" % _short_player_text(watch_objective, 28)
	return line

static func describe_objective_stakes_board(session: SessionStateStoreScript.SessionData) -> String:
	return _describe_objective_stakes_board_from_surface(session, _objective_stakes_surface(session))

static func _describe_objective_stakes_board_from_surface(
	session: SessionStateStoreScript.SessionData,
	surface: Dictionary,
	preloaded_progress: Dictionary = {}
) -> String:
	if surface.is_empty():
		return "Objective Stakes\nNo authored scenario objectives are available."

	var lines := [
		"Objective Stakes",
		String(surface.get("context_line", "Scenario context unavailable.")),
		"Progress: %d/%d victory complete | %d/%d defeat risks triggered" % [
			int(surface.get("victory_met", 0)),
			int(surface.get("victory_total", 0)),
			int(surface.get("defeat_triggered", 0)),
			int(surface.get("defeat_total", 0)),
		],
	]
	var campaign_stakes := String(surface.get("campaign_stakes", ""))
	if campaign_stakes != "":
		lines.append("Campaign stakes: %s" % campaign_stakes)
	else:
		lines.append("Skirmish context: self-contained run; no campaign carryover changes.")
	var next_objective := String(surface.get("next_objective", ""))
	lines.append("Next objective: %s" % (next_objective if next_objective != "" else "All victory objectives are complete."))

	var completed: Array = surface.get("completed_objectives", [])
	var incomplete: Array = surface.get("incomplete_objectives", [])
	lines.append("Complete: %s" % _join_limited_labels(completed, 3, "none"))
	lines.append("Incomplete: %s" % _join_limited_labels(incomplete, 3, "none"))
	var defeat_watch: Array = surface.get("defeat_watch", [])
	lines.append("Defeat watch: %s" % _join_limited_labels(defeat_watch, 2, "clear"))

	var victory_text := String(surface.get("victory_text", ""))
	if victory_text != "":
		lines.append("Win: %s" % victory_text)
	var defeat_text := String(surface.get("defeat_text", ""))
	if defeat_text != "":
		lines.append("Lose: %s" % defeat_text)
	var campaign_arc := String(surface.get("campaign_arc", ""))
	if campaign_arc != "":
		lines.append("Campaign arc: %s" % campaign_arc)
	var progress_recap := ""
	if preloaded_progress.has("progress_recap"):
		progress_recap = String(preloaded_progress.get("progress_recap", ""))
	else:
		progress_recap = _scenario_rules().describe_session_progress_recap(session, false)
	if progress_recap != "":
		lines.append(progress_recap)
	return "\n".join(lines)

static func _week_of_day(day: int) -> int:
	return int(floori(float(max(day, 1) - 1) / 7.0)) + 1

static func _weekday_of_day(day: int) -> int:
	return ((max(day, 1) - 1) % 7) + 1

static func describe_hero(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_hero", [session])

static func _overworld_hero_line(hero: Dictionary) -> String:
	return "%s | %s | %s" % [
		HeroCommandRulesScript.hero_identity_context_line(hero),
		HeroCommandRulesScript.hero_progress_context_line(hero),
		HeroCommandRulesScript.hero_readiness_context_line(hero, true),
	]

static func describe_heroes(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var lines := ["Command Wing"]
	var reserves := []
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		var line := _overworld_hero_line(hero)
		if String(hero.get("id", "")) == active_hero_id:
			lines.append("- Active command: %s" % line)
		else:
			reserves.append("- Reserve command: %s" % line)
	if reserves.is_empty():
		lines.append("- No reserve commanders are currently marching under the banner.")
	else:
		lines.append("- Reserve roster %d" % reserves.size())
		for reserve in reserves:
			lines.append(reserve)
	return "\n".join(lines)

static func describe_army(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_army", [session])

static func describe_stack_inspection_line(stack: Dictionary, options: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_stack_inspection_line", [stack, options])

static func describe_unit_recruit_brief(unit_id: String, count: int = 0) -> String:
	return HumanEngine.native(&"OverworldRules.describe_unit_recruit_brief", [unit_id, count])

static func unit_stack_strength_value(unit_id: String, count: int) -> int:
	return HumanEngine.native(&"OverworldRules.unit_stack_strength_value", [unit_id, count])

static func is_weekly_growth_day(day: int) -> bool:
	return day > 1 and ((day - 1) % WEEKLY_GROWTH_INTERVAL) == 0

static func days_until_next_weekly_growth(day: int) -> int:
	return WEEKLY_GROWTH_INTERVAL - ((max(day, 1) - 1) % WEEKLY_GROWTH_INTERVAL)

static func next_weekly_growth_day(day: int) -> int:
	return max(day, 1) + days_until_next_weekly_growth(day)

static func town_control_label(owner: String) -> String:
	match owner.strip_edges().to_lower():
		"player":
			return "Your Control"
		"enemy":
			return "Enemy Control"
		"neutral":
			return "Neutral Control"
		_:
			return "Unknown Control"

static func describe_town_context(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	var income := _describe_resource_delta(_calculate_town_income(town, session))
	var weekly_growth := _describe_recruit_delta(town_weekly_growth(town, session))
	var defense := _town_defense_summary(town)
	var readiness := town_battle_readiness(town, session)
	var pressure_output := town_pressure_output(town, session)
	var strategic_role := town_strategic_role(town)
	var capital_project := town_capital_project_state(town, session)
	var battlefront := town_battlefront_profile(town)
	var occupation := town_occupation_state(session, town)
	var parts := [
		_town_name(town),
		String(ContentService.get_faction(_town_faction_id(town)).get("name", _town_faction_id(town))),
		town_control_label(String(town.get("owner", "neutral"))),
	]
	if strategic_role == "capital":
		parts.append("Capital Anchor")
	elif strategic_role == "stronghold":
		parts.append("Frontier Stronghold")
	for identity_line in _town_identity_surface(town, session).split("\n"):
		var line := String(identity_line)
		if line.begins_with("Economy: ") or line.begins_with("Magic: ") or line.begins_with("Strategic cue: "):
			parts.append(line)
	if income != "":
		parts.append("Daily %s" % income)
	if weekly_growth != "":
		parts.append("Weekly %s" % weekly_growth)
	if bool(occupation.get("active", false)):
		parts.append("Pacifying %d day%s" % [
			int(occupation.get("days_to_clear", 0)),
			"" if int(occupation.get("days_to_clear", 0)) == 1 else "s",
		])
	if defense != "":
		parts.append("Defense %s" % defense)
	if String(town.get("owner", "neutral")) == "enemy" and _town_garrison_headcount(town) > 0:
		parts.append(
			"Garrison %d troops/%d companies" % [_town_garrison_headcount(town), _town_garrison_company_count(town)]
		)
		if _town_requires_assault(town):
			parts.append("Assault required")
	if readiness > 0:
		parts.append("Readiness %d" % readiness)
	if pressure_output > 0:
		parts.append("%s %d" % [_town_pressure_label(town), pressure_output])
	if String(battlefront.get("label", "")) != "":
		parts.append(String(battlefront.get("label", "")))
	if bool(capital_project.get("active", false)):
		parts.append("Project online")
	elif int(capital_project.get("total", 0)) > 0:
		parts.append("Project dormant")
	if session != null:
		var logistics := town_logistics_state(session, town)
		if String(logistics.get("summary", "")) != "":
			parts.append("Logistics %s" % String(logistics.get("summary", "")))
		var recovery := town_recovery_state(session, town)
		if bool(recovery.get("active", false)):
			parts.append("Recovery %s" % String(recovery.get("summary", "")))
	return " | ".join(parts)

static func describe_visibility_panel(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var controlled_outposts := controlled_resource_site_count(session, "player", "faction_outpost")
	var controlled_shrines := controlled_resource_site_count(session, "player", "frontier_shrine")
	var controlled_scouting := controlled_resource_site_count(session, "player", "scouting_structure")
	var lines := [
		"Scout Net",
		"- %s" % describe_visibility(session),
		"- Controlled heroes %d | Movement permanently maps each commander scout radius." % HeroCommandRulesScript.player_hero_count(session),
	]
	if controlled_outposts > 0:
		lines.append("- Held outposts %d | Frontier relays extend sight beyond commander scout rings." % controlled_outposts)
	if controlled_scouting > 0:
		lines.append("- Held scout structures %d | Watch sites widen route certainty before enemy heroes close in." % controlled_scouting)
	if controlled_shrines > 0:
		lines.append("- Held shrines %d | Sanctums keep spell routes open across the frontier." % controlled_shrines)
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		var position = hero.get("position", {})
		lines.append(
			"- %s | Pos %d,%d | Scout %d%s" % [
				String(hero.get("name", "Hero")),
				int(position.get("x", 0)),
				int(position.get("y", 0)),
				HeroCommandRulesScript.scouting_radius_for_hero(hero),
				" | Active" if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")) else "",
			]
		)
	return "\n".join(lines)

static func describe_context(session: SessionStateStoreScript.SessionData) -> String:
	var context := get_active_context(session)
	var pos := hero_position(session)
	var terrain := _terrain_name_at(session, pos.x, pos.y)
	match String(context.get("type", "empty")):
		"town":
			var town = context.get("town", {})
			return "Town Tile\nTerrain %s | %s\n%s" % [
				terrain,
				_town_name(town),
				describe_town_context(town, session),
			]
		"resource":
			var node = context.get("node", {})
			var site = NodePayload.site_for_node(node)
			return "%s\nTerrain %s | %s\n%s" % [
				_resource_site_role_label(node, site),
				terrain,
				String(site.get("name", "Resource Cache")),
				_resource_site_context_summary(session, node, site),
			]
		"artifact":
			var artifact_node = context.get("node", {})
			return "Artifact Cache\nTerrain %s\n%s" % [
				terrain,
				ArtifactRulesScript.describe_artifact_inspection(
					session.overworld.get("hero", {}),
					String(artifact_node.get("artifact_id", "")),
					bool(artifact_node.get("collected", false)),
					String(artifact_node.get("collected_by_faction_id", ""))
				),
			]
		"encounter":
			var placement = context.get("encounter", {})
			var object_surface := describe_encounter_object_surface(placement)
			return "Hostile Contact\nTerrain %s | %s%s\n%s\n%s" % [
				terrain,
				encounter_display_name(placement),
				"" if object_surface == "" else " | %s" % object_surface,
				describe_encounter_readability_surface(session, placement),
				_encounter_pressure_summary(session, placement),
			]
		"rendezvous":
			return "%s\nTerrain %s\nMeet to exchange troops, artifacts or spells." % [
				HeroCommandRulesScript.describe_field_rendezvous(session),
				terrain,
			]
		_:
			return "Open Ground\nTerrain %s | No immediate site action.\nUse the movement controls to scout, consolidate towns, or intercept enemy heroes." % terrain

static func _terrain_name_at(session: SessionStateStoreScript.SessionData, x: int, y: int) -> String:
	var terrain := _terrain_id_at(session, x, y)
	var biome := ContentService.get_biome_for_terrain(terrain)
	if not biome.is_empty():
		return String(biome.get("name", terrain.capitalize()))
	return terrain.capitalize() if terrain != "" else "Unknown terrain"

static func _terrain_id_at(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> String:
	var map_data = map_for_level(session, level)
	if y < 0 or not (map_data is Array) or y >= map_data.size():
		return ""
	var row = map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return ""
	return String(row[x])

static func describe_objective_board(session: SessionStateStoreScript.SessionData) -> String:
	_normalize_scenario_state_rules(session)
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	var objectives = _scenario_rules().objectives_for_session(session)
	if not (objectives is Dictionary):
		return "Objectives\n- No authored objectives."

	var victory_total := 0
	var victory_met := 0
	var defeat_total := 0
	var defeat_triggered := 0
	for objective in objectives.get("victory", []):
		if objective is Dictionary:
			victory_total += 1
			if _scenario_is_objective_met(session, String(objective.get("id", "")), "victory"):
				victory_met += 1
	for objective in objectives.get("defeat", []):
		if objective is Dictionary:
			defeat_total += 1
			if _scenario_is_objective_met(session, String(objective.get("id", "")), "defeat"):
				defeat_triggered += 1
	return "Objective Board\nVictory %d/%d | Defeat risks %d/%d triggered\n%s" % [
		victory_met,
		victory_total,
		defeat_triggered,
		defeat_total,
		"%s\n%s" % [
			_scenario_describe_objectives(session),
			_scenario_rules().describe_session_progress_recap(session, false),
		],
	]

static func describe_objectives(session: SessionStateStoreScript.SessionData) -> String:
	return describe_objective_board(session)

static func _objective_stakes_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	if session == null or session.scenario_id == "":
		return {}
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	var objectives = _scenario_rules().objectives_for_session(session)
	if not (objectives is Dictionary):
		return {}

	var victory_total := 0
	var victory_met := 0
	var defeat_total := 0
	var defeat_triggered := 0
	var completed: Array = []
	var incomplete: Array = []
	var defeat_watch: Array = []
	var next_objective := ""
	var watch_objective := ""

	for objective in objectives.get("victory", []):
		if not (objective is Dictionary):
			continue
		victory_total += 1
		var label := _scenario_objective_player_label(session, objective)
		if _scenario_objective_met(session, objective):
			victory_met += 1
			if label != "":
				completed.append(label)
		else:
			if label != "":
				incomplete.append(label)
				if next_objective == "":
					next_objective = label

	for objective in objectives.get("defeat", []):
		if not (objective is Dictionary):
			continue
		defeat_total += 1
		var label := _scenario_objective_player_label(session, objective)
		if _scenario_objective_met(session, objective):
			defeat_triggered += 1
		if label != "":
			defeat_watch.append(label)
			if watch_objective == "":
				watch_objective = label

	var campaign_context := _campaign_context_for_session(session, scenario)
	return {
		"mode_label": String(campaign_context.get("mode_label", "Scenario")),
		"context_line": String(campaign_context.get("context_line", "")),
		"campaign_stakes": String(campaign_context.get("campaign_stakes", "")),
		"campaign_arc": String(campaign_context.get("campaign_arc", "")),
		"victory_total": victory_total,
		"victory_met": victory_met,
		"defeat_total": defeat_total,
		"defeat_triggered": defeat_triggered,
		"next_objective": next_objective,
		"watch_objective": watch_objective,
		"completed_objectives": completed,
		"incomplete_objectives": incomplete,
		"defeat_watch": defeat_watch,
		"victory_text": String(objectives.get("victory_text", "")),
		"defeat_text": String(objectives.get("defeat_text", "")),
	}

static func _campaign_context_for_session(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> Dictionary:
	var scenario_name := String(scenario.get("name", session.scenario_id))
	var launch_mode := SessionStateStoreScript.normalize_launch_mode(session.launch_mode)
	if launch_mode != SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN:
		return {
			"mode_label": "Skirmish",
			"context_line": "Skirmish: %s | Day %d" % [scenario_name, session.day],
			"campaign_stakes": "",
			"campaign_arc": "",
		}

	var campaign_id := String(session.flags.get("campaign_id", ""))
	if campaign_id == "":
		campaign_id = _campaign_rules().get_campaign_id_for_scenario(session.scenario_id)
	var campaign := ContentService.get_campaign(campaign_id)
	var entry := _campaign_scenario_entry(campaign, session.scenario_id)
	var campaign_name := String(session.flags.get("campaign_name", campaign.get("name", campaign_id)))
	var chapter_label := String(session.flags.get("campaign_chapter_label", entry.get("label", scenario_name)))
	return {
		"mode_label": "Campaign",
		"context_line": "Campaign: %s | %s | Day %d" % [campaign_name, chapter_label, session.day],
		"campaign_stakes": String(entry.get("stakes", "")),
		"campaign_arc": String(campaign.get("arc_goal", "")),
	}

static func _campaign_scenario_entry(campaign: Dictionary, scenario_id: String) -> Dictionary:
	for entry in campaign.get("scenarios", []):
		if entry is Dictionary and String(entry.get("scenario_id", "")) == scenario_id:
			return entry
	return {}

static func _scenario_objective_player_label(session: SessionStateStoreScript.SessionData, objective: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._scenario_objective_player_label", [session, objective])

static func _join_limited_labels(labels: Array, limit: int, fallback: String) -> String:
	if labels.is_empty():
		return fallback
	var visible := []
	for index in range(min(max(1, limit), labels.size())):
		visible.append(String(labels[index]))
	if labels.size() > visible.size():
		visible.append("%d more" % (labels.size() - visible.size()))
	return "; ".join(visible)

static func _short_player_text(text: String, max_chars: int) -> String:
	var compact := text.strip_edges().replace("\n", " ")
	while compact.find("  ") >= 0:
		compact = compact.replace("  ", " ")
	if compact.length() <= max_chars:
		return compact
	return "%s..." % compact.left(max(1, max_chars - 3)).strip_edges()

static func describe_frontier_threats(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var lines := ["Frontier Watch"]
	var global_threats: String = _describe_enemy_threats(session)
	if global_threats == "":
		lines.append("- No hostile factions are active.")
	else:
		lines.append(global_threats)
	var local_warning := _local_visible_threat_summary(session)
	if local_warning != "":
		lines.append("Local watch: %s" % local_warning)
	var occupation_watch := _occupied_town_watch_summary(session)
	if occupation_watch != "":
		lines.append("Occupation watch: %s" % occupation_watch)
	lines.append("Defense readiness: %s" % describe_defense_readiness_warnings(session))
	return "\n".join(lines)

static func describe_defense_readiness_warnings(session: SessionStateStoreScript.SessionData, limit: int = 2) -> String:
	normalize_overworld_state(session)
	var items := _defense_readiness_warning_items(session)
	if items.is_empty():
		return "No exposed town or route-defense warning is visible."
	var fragments := []
	var max_items := clampi(limit, 1, 4)
	for index in range(min(max_items, items.size())):
		var item: Dictionary = items[index]
		fragments.append("%s: %s Why: %s Next: %s" % [
			String(item.get("label", "Town front")),
			_short_player_text(String(item.get("context", "")), 128),
			_short_player_text(String(item.get("why", "")), 112),
			_short_player_text(String(item.get("next_step", "")), 112),
		])
	if items.size() > max_items:
		fragments.append("+%d more town/front warning%s" % [
			items.size() - max_items,
			"" if items.size() - max_items == 1 else "s",
		])
	return " | ".join(fragments)

static func describe_town_defense_readiness_warning(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary
) -> String:
	normalize_overworld_state(session)
	if town.is_empty():
		return "No town front is selected."
	var item := _defense_readiness_warning_item(session, town, true)
	if item.is_empty():
		return "No town front is selected."
	return "%s: %s Why: %s Next: %s" % [
		String(item.get("label", _town_name(town))),
		_short_player_text(String(item.get("context", "")), 132),
		_short_player_text(String(item.get("why", "")), 112),
		_short_player_text(String(item.get("next_step", "")), 112),
	]

static func _defense_readiness_warning_items(session: SessionStateStoreScript.SessionData) -> Array:
	var items := []
	if session == null:
		return items
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var item := _defense_readiness_warning_item(session, town, false)
		if not item.is_empty():
			items.append(item)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("severity", 0)) > int(b.get("severity", 0))
	)
	return items

static func _defense_readiness_warning_item(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	include_steady: bool
) -> Dictionary:
	if session == null or town.is_empty():
		return {}
	var readiness := town_battle_readiness(town, session)
	var defense := _town_defense_summary(town)
	var logistics := town_logistics_state(session, town)
	var recovery := town_recovery_state(session, town)
	var capital_project := town_capital_project_state(town, session)
	var occupation := town_occupation_state(session, town)
	var front := _town_front_state(session, town)
	var threat_state := _town_command_risk_state(session, town)
	var objective_anchor: bool = _raid_target_is_objective_anchor(
		session,
		"town",
		String(town.get("placement_id", ""))
	)
	var pressure_parts := _defense_readiness_pressure_parts(threat_state, front, occupation)
	var logistics_alert := (
		int(logistics.get("disrupted_count", 0)) > 0
		or int(logistics.get("threatened_count", 0)) > 0
		or int(logistics.get("support_gap", 0)) > 0
	)
	var recovery_alert := bool(recovery.get("active", false))
	var capital_alert := bool(capital_project.get("vulnerable", false))
	var low_readiness := readiness <= 18 or defense == "thin watch"
	var strained_readiness := readiness <= 30
	var has_warning := (
		not pressure_parts.is_empty()
		or logistics_alert
		or recovery_alert
		or capital_alert
		or low_readiness
		or bool(occupation.get("active", false))
	)
	if not has_warning and not include_steady:
		return {}
	var severity := 0
	if int(threat_state.get("visible_pressuring", 0)) > 0 or int(threat_state.get("siege_progress", 0)) > 0:
		severity += 5
	elif int(threat_state.get("visible_marching", 0)) > 0:
		severity += 3
	if bool(threat_state.get("hidden_targeting", false)):
		severity += 2
	if bool(front.get("active", false)):
		severity += 2 if String(front.get("mode", "")) == "retake" else 1
	if bool(occupation.get("active", false)):
		severity += 2
	if low_readiness:
		severity += 2
	elif strained_readiness:
		severity += 1
	if logistics_alert:
		severity += 2
	if recovery_alert or capital_alert or objective_anchor:
		severity += 1
	var status := "ready"
	if low_readiness:
		status = "under-defended"
	elif has_warning:
		status = "pressured"
	elif strained_readiness:
		status = "guarded"
	var context_parts := []
	if not pressure_parts.is_empty():
		context_parts.append("Pressure %s" % "; ".join(pressure_parts))
	context_parts.append("Readiness %d" % readiness)
	if defense != "":
		context_parts.append(defense)
	if String(logistics.get("summary", "")) != "":
		context_parts.append("Routes %s" % String(logistics.get("summary", "")))
	if String(logistics.get("impact_summary", "")) != "" and (logistics_alert or include_steady):
		context_parts.append("Economy/frontier %s" % String(logistics.get("impact_summary", "")))
	if recovery_alert:
		context_parts.append(String(recovery.get("summary", "")))
	if capital_alert and String(capital_project.get("vulnerability_summary", "")) != "":
		context_parts.append(String(capital_project.get("vulnerability_summary", "")))
	if objective_anchor:
		context_parts.append("objective anchor")
	return {
		"label": "%s %s" % [_town_name(town), status],
		"context": " | ".join(context_parts),
		"why": _defense_readiness_warning_why(
			objective_anchor,
			not pressure_parts.is_empty(),
			logistics_alert,
			recovery_alert,
			capital_alert,
			low_readiness
		),
		"next_step": _defense_readiness_next_step(
			not pressure_parts.is_empty(),
			logistics_alert,
			recovery_alert,
			capital_alert,
			low_readiness,
			bool(front.get("active", false)),
			readiness
		),
		"severity": severity,
	}

static func _defense_readiness_pressure_parts(threat_state: Dictionary, front: Dictionary, occupation: Dictionary) -> Array:
	var parts := []
	if int(threat_state.get("visible_pressuring", 0)) > 0:
		var pressuring: Array = threat_state.get("pressuring_commanders", [])
		if int(threat_state.get("visible_pressuring", 0)) == 1 and pressuring is Array and not pressuring.is_empty():
			parts.append("%s at the approaches" % String(pressuring[0]))
		else:
			parts.append("%d enemy heroes at the approaches" % int(threat_state.get("visible_pressuring", 0)))
	if int(threat_state.get("visible_marching", 0)) > 0:
		var marching: Array = threat_state.get("marching_commanders", [])
		var distance: int = max(1, int(threat_state.get("nearest_goal_distance", 9999)))
		if int(threat_state.get("visible_marching", 0)) == 1 and marching is Array and not marching.is_empty():
			parts.append("%s can reach in %d day%s" % [
				String(marching[0]),
				distance,
				"" if distance == 1 else "s",
			])
		else:
			parts.append("%d enemy heroes marching" % int(threat_state.get("visible_marching", 0)))
	if bool(threat_state.get("hidden_targeting", false)):
		parts.append("hostile movement beyond the fog")
	if int(threat_state.get("siege_progress", 0)) > 0:
		parts.append("siege %d/%d" % [
			int(threat_state.get("siege_progress", 0)),
			max(1, int(threat_state.get("siege_capture_progress", 1))),
		])
	if bool(front.get("active", false)) and String(front.get("summary", "")) != "":
		parts.append(String(front.get("summary", "")))
	if bool(occupation.get("active", false)) and String(occupation.get("summary", "")) != "":
		parts.append(String(occupation.get("summary", "")))
	return parts

static func _defense_readiness_warning_why(
	objective_anchor: bool,
	has_pressure: bool,
	logistics_alert: bool,
	recovery_alert: bool,
	capital_alert: bool,
	low_readiness: bool
) -> String:
	if objective_anchor:
		return "This front anchors an objective while control, recruitment, income, and defense tempo stay exposed."
	if has_pressure:
		return "Enemy heroes can take the town, disrupt recruitment, cut convoys or lay siege."
	if logistics_alert:
		return "Route and economy pressure weakens readiness, recruitment, convoy support, and recovery."
	if recovery_alert:
		return "Recovery pressure keeps troops and routes brittle until relief or response orders land."
	if capital_alert:
		return "The capital chain needs linked support before its civic and defense gains are safe."
	if low_readiness:
		return "Low readiness leaves the garrison brittle if an enemy hero reaches the walls."
	return "Control, income, recruitment, and route cover remain stable while the watch holds."

static func _defense_readiness_next_step(
	has_pressure: bool,
	logistics_alert: bool,
	recovery_alert: bool,
	capital_alert: bool,
	low_readiness: bool,
	front_active: bool,
	readiness: int
) -> String:
	if has_pressure and low_readiness:
		return "Recruit reserves or build readiness, then intercept the nearest enemy hero if movement allows."
	if has_pressure:
		return "Intercept the enemy hero before ending the day, or hold reserves if this town must anchor the front."
	if logistics_alert or recovery_alert:
		return "Send a town response order or intercept the route blocker before ending the day."
	if capital_alert:
		return "Restore linked route support or hold until the project is covered."
	if low_readiness or readiness <= 30:
		return "Build readiness or recruit reserves before the next exposed day."
	if front_active:
		return "Hold the watch and keep a response route open for the front."
	return "Hold the watch; build or recruit only if it improves the next defense turn."

static func _local_visible_threat_summary(session: SessionStateStoreScript.SessionData, fallback: String = "") -> String:
	var pos := hero_position(session)
	var visible_contacts := 0
	var local_contacts := 0
	var nearest_contact_name := ""
	var nearest_contact_reason := ""
	var nearest_contact_distance := 99999
	var visible_enemy_towns := 0
	var visible_denied_sites := 0
	var visible_contested_fronts := 0
	var visible_commander_names: Array = []
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or not OverworldLevelRulesScript.on_level(encounter, hero_level(session)):
			continue
		if is_encounter_resolved(session, encounter):
			continue
		var x := int(encounter.get("x", -1))
		var y := int(encounter.get("y", -1))
		if not is_tile_visible(session, x, y):
			continue
		visible_contacts += 1
		var distance = abs(x - pos.x) + abs(y - pos.y)
		if distance <= 3:
			local_contacts += 1
		if distance < nearest_contact_distance:
			nearest_contact_distance = distance
			nearest_contact_name = encounter_display_name(encounter)
			nearest_contact_reason = String(encounter.get("target_public_reason", ""))
		var commander_name := encounter_commander_threat_label(encounter)
		if commander_name != "" and commander_name not in visible_commander_names:
			visible_commander_names.append(commander_name)
		if String(encounter.get("contested_by_faction_id", "")) != "":
			visible_contested_fronts += 1
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or not OverworldLevelRulesScript.on_level(town, hero_level(session)):
			continue
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		var town_x := int(town.get("x", -1))
		var town_y := int(town.get("y", -1))
		if is_tile_visible(session, town_x, town_y):
			visible_enemy_towns += 1
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or not OverworldLevelRulesScript.on_level(node, hero_level(session)):
			continue
		var collector := String(node.get("collected_by_faction_id", ""))
		if collector == "" or collector == "player":
			continue
		if is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1))):
			visible_denied_sites += 1
	for node in session.overworld.get("artifact_nodes", []):
		if not (node is Dictionary) or not OverworldLevelRulesScript.on_level(node, hero_level(session)):
			continue
		var collector := String(node.get("collected_by_faction_id", ""))
		if collector == "" or collector == "player":
			continue
		if is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1))):
			visible_denied_sites += 1
	var parts := []
	if local_contacts > 0:
		var local_clause := "%d hostile contact%s operating within 3 tiles" % [local_contacts, "" if local_contacts == 1 else "s"]
		if nearest_contact_reason != "":
			local_clause += " (%s)" % nearest_contact_reason
		parts.append(local_clause)
	elif nearest_contact_name != "":
		var nearest_clause := "Nearest hostile contact %s at %d tiles" % [nearest_contact_name, nearest_contact_distance]
		if nearest_contact_reason != "":
			nearest_clause += " (%s)" % nearest_contact_reason
		parts.append(nearest_clause)
	elif visible_contacts > 0:
		parts.append("%d hostile contact%s visible on the frontier" % [visible_contacts, "" if visible_contacts == 1 else "s"])
	if visible_enemy_towns > 0:
		parts.append("%d enemy-held town%s currently confirmed by scouts" % [visible_enemy_towns, "" if visible_enemy_towns == 1 else "s"])
	if visible_denied_sites > 0:
		parts.append("%d frontier site%s already denied by hostile forces" % [visible_denied_sites, "" if visible_denied_sites == 1 else "s"])
	if visible_contested_fronts > 0:
		parts.append("%d neutral front%s under hostile contest" % [visible_contested_fronts, "" if visible_contested_fronts == 1 else "s"])
	if not visible_commander_names.is_empty():
		var shown_names = visible_commander_names.slice(0, min(2, visible_commander_names.size()))
		var commander_summary: String = "Commanders sighted %s" % ", ".join(shown_names)
		if visible_commander_names.size() > shown_names.size():
			commander_summary += " (+%d more)" % (visible_commander_names.size() - shown_names.size())
		parts.append(commander_summary)
	if parts.is_empty():
		return fallback
	return " | ".join(parts)

static func _occupied_town_watch_summary(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return ""
	var clauses := []
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary) or String(town_value.get("owner", "neutral")) != "player":
			continue
		var occupation := _town_occupation_state(session, town_value)
		if not bool(occupation.get("active", false)):
			continue
		var clause := String(occupation.get("compact_summary", _town_name(town_value)))
		var front := _town_front_state(session, town_value)
		if bool(front.get("active", false)) and String(front.get("mode", "")) == "retake":
			clause += " under retake pressure"
		clauses.append(clause)
	if clauses.is_empty():
		return ""
	var shown := clauses.slice(0, min(2, clauses.size()))
	var summary := "; ".join(shown)
	if clauses.size() > shown.size():
		summary += "; %d more holding%s" % [clauses.size() - shown.size(), "" if clauses.size() - shown.size() == 1 else "s"]
	return summary

static func describe_enemy_threats(session: SessionStateStoreScript.SessionData) -> String:
	return describe_frontier_threats(session)

static func describe_spellbook(session: SessionStateStoreScript.SessionData, context_filter: String = "") -> String:
	if context_filter == SpellRulesScript.CONTEXT_OVERWORLD:
		return SpellRulesScript.describe_overworld_spellbook(
			session.overworld.get("hero", {}),
			session.overworld.get("movement", {})
		)
	return SpellRulesScript.describe_spellbook(session.overworld.get("hero", {}), context_filter)

static func describe_spellbook_rail(session: SessionStateStoreScript.SessionData, context_filter: String = "") -> String:
	if context_filter == SpellRulesScript.CONTEXT_OVERWORLD:
		return SpellRulesScript.describe_overworld_spell_rail(
			session.overworld.get("hero", {}),
			session.overworld.get("movement", {})
		)
	return SpellRulesScript.describe_spellbook(session.overworld.get("hero", {}), context_filter)

static func describe_specialties(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	return HeroProgressionRulesScript.describe_specialties(session.overworld.get("hero", {}))

static func describe_artifacts(session: SessionStateStoreScript.SessionData) -> String:
	var hero = session.overworld.get("hero", {})
	return ArtifactRulesScript.describe_management(hero)

static func describe_command_briefing(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	if not _should_surface_command_briefing(session):
		return ""
	return "\n".join(_command_briefing_lines(session))

static func consume_command_briefing(session: SessionStateStoreScript.SessionData) -> String:
	var briefing_text := describe_command_briefing(session)
	if briefing_text == "":
		return ""
	var briefing_state = session.overworld.get(COMMAND_BRIEFING_KEY, {})
	if not (briefing_state is Dictionary):
		briefing_state = {}
	briefing_state["shown"] = true
	briefing_state["shown_day"] = session.day
	session.overworld[COMMAND_BRIEFING_KEY] = briefing_state
	return briefing_text

static func describe_command_risk(session: SessionStateStoreScript.SessionData) -> String:
	return String(describe_command_risk_surfaces(session).get("risk", ""))

static func describe_command_risk_from_normalized_session(session: SessionStateStoreScript.SessionData) -> String:
	return String(_command_risk_surfaces_from_forecast(_command_risk_forecast_from_normalized_session(session)).get("risk", ""))

static func describe_command_risk_summary_from_normalized_session(session: SessionStateStoreScript.SessionData) -> String:
	var reduction := _reduce_command_risk_items(_command_risk_items(session, false))
	if not bool(reduction.get("has_risk", false)):
		return "Steady watch | No concrete next-day break is signaled from the current frontier watch."
	return String(reduction.get("summary", ""))

static func _refresh_watch_observation_context(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	return _refresh_watch_observation_context_from_normalized_session(session)

static func _refresh_watch_observation_context_from_normalized_session(
	session: SessionStateStoreScript.SessionData
) -> Dictionary:
	var command_risk_forecast := _command_risk_forecast_from_normalized_session(session)
	return {
		"command_risk_forecast": command_risk_forecast.duplicate(true),
		"command_risk_surfaces": _command_risk_surfaces_from_forecast(command_risk_forecast).duplicate(true),
		"local_pressure": _local_visible_threat_summary(session, ""),
		"management_watch": _describe_management_watch_from_normalized_session(session),
	}.duplicate(true)

static func describe_commitment_board(
	session: SessionStateStoreScript.SessionData,
	refresh_watch_context: Dictionary = {}
) -> String:
	var hold_line := ""
	if refresh_watch_context.is_empty():
		normalize_overworld_state(session)
		hold_line = _command_commitment_hold_line(session)
	else:
		hold_line = _command_commitment_hold_line_from_watch_context(session, refresh_watch_context)
	var lines := [
		"Command Commitment",
		"- Immediate order: %s" % _command_commitment_action_line(session),
		"- Route pressure: %s" % _command_commitment_route_line(session),
		"- Coverage: %s" % _command_commitment_coverage_line(session),
		"- If you hold: %s" % hold_line,
	]
	return "\n".join(lines)

static func describe_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> String:
	return String(describe_command_risk_surfaces(session).get("forecast", ""))

static func describe_end_turn_forecast(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var next_day := session.day + 1
	var lines := [
		"Next day: Day %d | %s | %s" % [
			next_day,
			_end_turn_income_forecast_line(session, next_day),
			_end_turn_muster_forecast_line(session, next_day),
		],
		"- Movement: %s" % _end_turn_movement_forecast_line(session),
	]
	var risk_line := _end_turn_risk_forecast_line(session)
	if risk_line != "":
		lines.append("- Pressure: %s" % risk_line)
	var management_line := describe_management_watch(session)
	if management_line != "":
		lines.append("- Town lines: %s" % management_line)
	return "\n".join(lines)

static func describe_end_turn_forecast_compact(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	var next_day := session.day + 1
	var parts := [
		"Day %d" % next_day,
		_end_turn_income_forecast_line(session, next_day),
		_end_turn_movement_forecast_line(session),
	]
	var risk_line := _end_turn_risk_forecast_line(session)
	if risk_line != "":
		parts.append(risk_line)
	return " | ".join(parts)

static func describe_end_turn_forecast_surfaces(
	session: SessionStateStoreScript.SessionData,
	refresh_watch_context: Dictionary = {}
) -> Dictionary:
	if refresh_watch_context.is_empty():
		normalize_overworld_state(session)
	var next_day := session.day + 1
	var income_line := _end_turn_income_forecast_line(session, next_day)
	var muster_line := _end_turn_muster_forecast_line(session, next_day)
	var movement_line := _end_turn_movement_forecast_line(session)
	var risk_line := ""
	var management_line := ""
	if refresh_watch_context.is_empty():
		risk_line = _end_turn_risk_forecast_line(session)
		management_line = describe_management_watch(session)
	else:
		risk_line = _end_turn_risk_forecast_line_from_watch_context(refresh_watch_context)
		management_line = String(refresh_watch_context.get("management_watch", ""))
	var full_lines := [
		"Next day: Day %d | %s | %s" % [next_day, income_line, muster_line],
		"- Movement: %s" % movement_line,
	]
	if risk_line != "":
		full_lines.append("- Pressure: %s" % risk_line)
	if management_line != "":
		full_lines.append("- Town lines: %s" % management_line)
	var compact_parts := [
		"Day %d" % next_day,
		income_line,
		movement_line,
	]
	if risk_line != "":
		compact_parts.append(risk_line)
	return {
		"forecast": "\n".join(full_lines),
		"forecast_compact": " | ".join(compact_parts),
	}

static func describe_command_risk_surfaces(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_overworld_state(session)
	return _command_risk_surfaces_from_forecast(_command_risk_forecast(session))

static func _command_risk_surfaces_from_forecast(forecast: Dictionary) -> Dictionary:
	if not bool(forecast.get("has_risk", false)):
		return {
			"risk": "Command Risk\nSteady watch | No concrete next-day break is signaled from the current frontier watch.",
			"forecast": "",
			"forecast_data": forecast,
		}
	return {
		"risk": "Command Risk\n%s" % String(forecast.get("summary", "")),
		"forecast": "\n".join(forecast.get("lines", [])),
		"forecast_data": forecast,
	}

static func consume_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> String:
	var forecast_text := describe_command_risk_forecast(session)
	if forecast_text == "" or not _should_surface_command_risk_forecast(session):
		return ""
	var forecast_state = session.overworld.get(COMMAND_RISK_FORECAST_KEY, {})
	if not (forecast_state is Dictionary):
		forecast_state = {}
	forecast_state["shown"] = true
	forecast_state["shown_day"] = session.day
	session.overworld[COMMAND_RISK_FORECAST_KEY] = forecast_state
	return forecast_text

static func describe_dispatch(session: SessionStateStoreScript.SessionData, last_message: String = "") -> String:
	normalize_overworld_state(session)
	return _describe_dispatch_from_observation_context(session, last_message, _event_dispatch_observation_context(session))

static func _describe_dispatch_from_observation_context(
	session: SessionStateStoreScript.SessionData,
	last_message: String,
	observation_context: Dictionary
) -> String:
	var lead_line := "Latest order: %s" % last_message if last_message != "" else "The field table is waiting on fresh orders."
	var local_pressure := String(observation_context.get("local_pressure", ""))
	if local_pressure == "":
		local_pressure = "No visible hostile pressure is crowding the active hero."
	var lines := [
		"Field Dispatch",
		"- %s" % lead_line,
		"- Active tile: %s" % String(observation_context.get("dispatch_context", "")),
		"- %s" % local_pressure,
	]
	var management_watch := String(observation_context.get("management_watch", ""))
	if management_watch != "":
		lines.append("- Management watch: %s" % management_watch)
	var defense_watch := String(observation_context.get("defense_watch", ""))
	if defense_watch != "No exposed town or route-defense warning is visible.":
		lines.append("- Defense readiness: %s" % defense_watch)
	var recent_events := String(observation_context.get("recent_events", ""))
	if recent_events != "":
		lines.append("- Scenario pulse: %s" % recent_events)
	if session.scenario_status != "in_progress" and session.scenario_summary != "":
		lines.append("- Outcome pending: %s" % session.scenario_summary)
	return "\n".join(lines)

static func describe_event_dispatch_surfaces(
	session: SessionStateStoreScript.SessionData,
	last_message: String = "",
	turn_resolution_summary: String = "",
	enemy_activity_summary: String = "",
	enemy_activity_events_value: Variant = [],
	action_recap_value: Variant = {},
	refresh_watch_context: Dictionary = {}
) -> Dictionary:
	if refresh_watch_context.is_empty():
		normalize_overworld_state(session)
	var observation_context := _event_dispatch_observation_context(session, refresh_watch_context)
	return {
		"event_feed": _describe_event_feed_surface_from_observation_context(
			session,
			last_message,
			turn_resolution_summary,
			enemy_activity_summary,
			enemy_activity_events_value,
			action_recap_value,
			observation_context
		),
		"dispatch": _describe_dispatch_from_observation_context(session, last_message, observation_context),
	}

static func _event_dispatch_observation_context(
	session: SessionStateStoreScript.SessionData,
	refresh_watch_context: Dictionary = {}
) -> Dictionary:
	var local_pressure := ""
	var management_watch := ""
	if refresh_watch_context.is_empty():
		local_pressure = _local_visible_threat_summary(session, "")
		management_watch = describe_management_watch(session)
	else:
		local_pressure = String(refresh_watch_context.get("local_pressure", ""))
		management_watch = String(refresh_watch_context.get("management_watch", ""))
	return {
		"recent_events": _describe_recent_events(session, 2),
		"route_pressure": describe_route_interception_surface(session),
		"local_pressure": local_pressure,
		"management_watch": management_watch,
		"defense_watch": describe_defense_readiness_warnings(session, 1),
		"dispatch_context": _dispatch_context_brief(session),
	}

static func describe_event_feed_surface(
	session: SessionStateStoreScript.SessionData,
	last_message: String = "",
	turn_resolution_summary: String = "",
	enemy_activity_summary: String = "",
	enemy_activity_events_value: Variant = [],
	action_recap_value: Variant = {}
) -> Dictionary:
	normalize_overworld_state(session)
	return _describe_event_feed_surface_from_observation_context(
		session,
		last_message,
		turn_resolution_summary,
		enemy_activity_summary,
		enemy_activity_events_value,
		action_recap_value,
		_event_dispatch_observation_context(session)
	)

static func _describe_event_feed_surface_from_observation_context(
	session: SessionStateStoreScript.SessionData,
	last_message: String,
	turn_resolution_summary: String,
	enemy_activity_summary: String,
	enemy_activity_events_value: Variant,
	action_recap_value: Variant,
	observation_context: Dictionary
) -> Dictionary:
	var recent_events := String(observation_context.get("recent_events", ""))
	var action_recap := _normalize_post_action_recap(action_recap_value)
	var use_action_recap := turn_resolution_summary.strip_edges() == "" and enemy_activity_summary.strip_edges() == "" and not action_recap.is_empty()
	var happened := String(action_recap.get("happened", "")) if use_action_recap else _event_feed_happened_line(last_message, turn_resolution_summary, enemy_activity_summary, recent_events)
	var affected := String(action_recap.get("affected", "")) if use_action_recap else _event_feed_affected_line(session, enemy_activity_summary, enemy_activity_events_value)
	var why := String(action_recap.get("why_it_matters", "")) if use_action_recap else _event_feed_why_line(last_message, turn_resolution_summary, enemy_activity_summary, recent_events)
	var next_step := String(action_recap.get("next_step", "")) if use_action_recap else _event_feed_next_step_line(session)
	var watch := _event_feed_watch_line_from_observation_context(observation_context)
	var visible := _event_feed_visible_line(happened, turn_resolution_summary, enemy_activity_summary)
	var tooltip_lines := ["Field Feed"]
	tooltip_lines.append("- Happened: %s" % happened)
	if turn_resolution_summary.strip_edges() != "":
		tooltip_lines.append("- Daybreak result: %s" % turn_resolution_summary.strip_edges())
	if enemy_activity_summary.strip_edges() != "":
		tooltip_lines.append("- Recent enemy activity: %s" % enemy_activity_summary.strip_edges())
	if recent_events != "":
		tooltip_lines.append("- Scenario pulse: %s" % _short_player_text(recent_events, 180))
	if affected != "":
		tooltip_lines.append("- Affected: %s" % affected)
	if why != "":
		tooltip_lines.append("- Why it matters: %s" % why)
	if next_step != "":
		tooltip_lines.append("- Next: %s" % next_step)
	if watch != "":
		tooltip_lines.append("- Watch: %s" % watch)
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"happened": happened,
		"affected": affected,
		"why_it_matters": why,
		"next_step": next_step,
		"watch": watch,
		"recent_events": recent_events,
		"enemy_activity_summary": enemy_activity_summary,
		"turn_resolution_summary": turn_resolution_summary,
		"post_action_recap": action_recap,
	}

static func describe_enemy_activity(events_value: Variant, limit: int = 4) -> String:
	var lines := []
	var seen := {}
	for event_value in _compact_enemy_activity_events(events_value, max(1, limit * 2)):
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var line := _enemy_activity_line(event)
		if line == "" or seen.has(line):
			continue
		seen[line] = true
		lines.append(line)
		if lines.size() >= max(1, limit):
			break
	return " | ".join(lines)

static func _compact_enemy_activity_events(events_value: Variant, limit: int = 6) -> Array:
	return _enemy_adventure_rules().ai_public_event_log(events_value, limit)

static func _enemy_activity_event_is_player_facing(event: Dictionary) -> bool:
	var event_type := String(event.get("event_type", ""))
	if event_type not in [
		"ai_target_assigned",
		"ai_pressure_summary",
		"ai_commander_task_planned",
		"ai_site_seized",
		"ai_site_contested",
		"ai_town_built",
		"ai_town_recruited",
		"ai_garrison_reinforced",
		"ai_raid_reinforced",
		"ai_commander_rebuilt",
		"ai_commander_role_observed",
		"ai_raid_moved",
		"ai_raid_arrived",
		"ai_raid_regrouped",
	]:
		return false
	var text := _enemy_activity_public_text(String(event.get("summary", "")))
	if text == "":
		return String(event.get("target_label", "")) != ""
	return true

static func _enemy_activity_line(event: Dictionary) -> String:
	var summary := _enemy_activity_public_text(String(event.get("summary", "")))
	if summary != "":
		return summary
	var actor := String(event.get("actor_label", event.get("faction_label", "Enemy")))
	var target := String(event.get("target_label", event.get("target_id", "the frontier")))
	var reason := _enemy_activity_public_text(String(event.get("public_reason", "")))
	var suffix := " (%s)" % reason if reason != "" else ""
	match String(event.get("event_type", "")):
		"ai_target_assigned":
			return "%s targets %s%s." % [actor, target, suffix]
		"ai_pressure_summary":
			return "%s pressure centers on %s%s." % [String(event.get("faction_label", actor)), target, suffix]
		"ai_commander_task_planned":
			return "%s plans pressure on %s%s." % [actor, target, suffix]
		"ai_site_seized":
			return "%s seizes %s%s." % [actor, target, suffix]
		"ai_site_contested":
			return "%s contests %s%s." % [actor, target, suffix]
		"ai_town_built":
			return "%s builds %s%s." % [actor, target, suffix]
		"ai_town_recruited":
			return "%s recruits %s%s." % [actor, target, suffix]
		"ai_garrison_reinforced":
			return "%s reinforces %s%s." % [actor, target, suffix]
		"ai_raid_reinforced":
			return "%s feeds %s%s." % [actor, target, suffix]
		"ai_commander_rebuilt":
			return "%s rebuilds %s%s." % [actor, target, suffix]
		_:
			return ""

static func _enemy_activity_public_text(text: String) -> String:
	var output := text.strip_edges().replace("\n", " ")
	while output.find("  ") >= 0:
		output = output.replace("  ", " ")
	for token in [
		"base_value",
		"persistent_income_value",
		"recruit_value",
		"scarcity_value",
		"denial_value",
		"route_pressure_value",
		"town_enablement_value",
		"resource_affinity_value",
		"weighted_claim_value",
		"weighted_income_value",
		"objective_value",
		"faction_bias",
		"travel_cost",
		"guard_cost",
		"assignment_penalty",
		"final_priority",
		"final_score",
		"income_value",
		"growth_value",
		"pressure_value",
		"category_bonus",
		"raid_score",
		"debug_reason",
	]:
		if output.find(token) >= 0:
			return ""
	return output

static func _event_feed_visible_line(happened: String, turn_resolution_summary: String, enemy_activity_summary: String) -> String:
	if turn_resolution_summary.strip_edges() != "":
		return "Turn: %s" % _short_player_text(turn_resolution_summary, 72)
	if enemy_activity_summary.strip_edges() != "":
		return "Enemy: %s" % _short_player_text(enemy_activity_summary, 72)
	var action_text := happened
	if action_text.begins_with("Order resolved: "):
		action_text = action_text.trim_prefix("Order resolved: ")
	elif action_text.begins_with("Scenario pulse: "):
		action_text = action_text.trim_prefix("Scenario pulse: ")
	return "Event: %s" % _short_player_text(action_text, 72)

static func _event_feed_happened_line(
	last_message: String,
	turn_resolution_summary: String,
	enemy_activity_summary: String,
	recent_events: String
) -> String:
	var turn_text := _enemy_activity_public_text(turn_resolution_summary)
	if turn_text != "":
		return "Daybreak resolved: %s" % _short_player_text(turn_text, 160)
	var message_text := _enemy_activity_public_text(last_message)
	if message_text != "":
		return "Order resolved: %s" % _short_player_text(message_text, 160)
	var enemy_text := _enemy_activity_public_text(enemy_activity_summary)
	if enemy_text != "":
		return "Enemy movement reported: %s" % _short_player_text(enemy_text, 160)
	if recent_events != "":
		return "Scenario pulse: %s" % _short_player_text(recent_events, 160)
	return "No new report; the frontier watch is current."

static func _event_feed_affected_line(
	session: SessionStateStoreScript.SessionData,
	enemy_activity_summary: String,
	enemy_activity_events_value: Variant
) -> String:
	var affected := []
	if enemy_activity_summary.strip_edges() != "" and enemy_activity_events_value is Array:
		for event_value in enemy_activity_events_value:
			if not (event_value is Dictionary):
				continue
			var event: Dictionary = event_value
			var target_label := String(event.get("target_label", "")).strip_edges()
			if target_label == "":
				continue
			var target_kind := String(event.get("target_kind", "")).strip_edges()
			var faction_label := String(event.get("faction_label", "")).strip_edges()
			var label := target_label
			if target_kind != "":
				label += " %s" % _humanize_id(target_kind).to_lower()
			if faction_label != "":
				label = "%s: %s" % [faction_label, label]
			if label not in affected:
				affected.append(label)
			if affected.size() >= 2:
				break
	var convoy_line := _event_feed_convoy_line(session)
	if convoy_line != "":
		affected.append(convoy_line)
	if affected.is_empty():
		affected.append(_dispatch_context_brief(session))
	return " | ".join(affected.slice(0, min(3, affected.size())))

static func _event_feed_why_line(
	last_message: String,
	turn_resolution_summary: String,
	enemy_activity_summary: String,
	recent_events: String
) -> String:
	var combined := "%s %s %s %s" % [last_message, turn_resolution_summary, enemy_activity_summary, recent_events]
	var lower := combined.to_lower()
	if enemy_activity_summary.strip_edges() != "":
		return "Enemy moves can close routes, contest sites, or add town pressure before your next turn."
	if lower.find("convoy") >= 0 or lower.find("escort") >= 0 or lower.find("route") >= 0:
		return "Route orders move reinforcements and may need protection from enemy heroes."
	if recent_events != "":
		return "Scenario pulses can open rewards, spawn counterforces, or advance objective stakes."
	if lower.find("claim") >= 0 or lower.find("control") >= 0 or lower.find("captur") >= 0:
		return "Control changes affect income, recruitment, routes, and objective progress."
	if lower.find("recruit") >= 0 or lower.find("muster") >= 0:
		return "Fresh troops change the next battle or town-defense decision."
	return "Use the next order to turn the report into progress toward the active objective."

static func _event_feed_next_step_line(session: SessionStateStoreScript.SessionData) -> String:
	var surface := _objective_stakes_surface(session)
	var next_objective := String(surface.get("next_objective", "")).strip_edges()
	if next_objective != "":
		return "Push toward %s." % _short_player_text(next_objective, 92)
	var watch_objective := String(surface.get("watch_objective", "")).strip_edges()
	if watch_objective != "":
		return "Keep watch on %s." % _short_player_text(watch_objective, 92)
	if session.scenario_status != "in_progress" and session.scenario_summary != "":
		return "Resolve the pending scenario outcome."
	return "Scout, consolidate, or end the turn when orders are spent."

static func _event_feed_watch_line(session: SessionStateStoreScript.SessionData) -> String:
	return _event_feed_watch_line_from_observation_context({
		"route_pressure": describe_route_interception_surface(session),
		"local_pressure": _local_visible_threat_summary(session, ""),
		"management_watch": describe_management_watch(session),
		"defense_watch": describe_defense_readiness_warnings(session, 1),
	})

static func _event_feed_watch_line_from_observation_context(observation_context: Dictionary) -> String:
	var parts := []
	var route_pressure: Dictionary = observation_context.get("route_pressure", {}) if observation_context.get("route_pressure", {}) is Dictionary else {}
	if bool(route_pressure.get("active", false)):
		parts.append(String(route_pressure.get("cue_text", "")))
	var local_pressure := String(observation_context.get("local_pressure", ""))
	if local_pressure != "":
		parts.append(local_pressure)
	var management_watch := String(observation_context.get("management_watch", ""))
	if management_watch != "" and management_watch != "Town lines are stable.":
		parts.append(management_watch)
	var defense_watch := String(observation_context.get("defense_watch", ""))
	if defense_watch != "No exposed town or route-defense warning is visible.":
		parts.append("Defense readiness: %s" % defense_watch)
	if parts.is_empty():
		return "No urgent enemy, convoy, or town-management warning is visible."
	return " | ".join(parts.slice(0, min(3, parts.size())))

static func describe_route_interception_surface(
	session: SessionStateStoreScript.SessionData,
	destination_x: int = -1,
	destination_y: int = -1,
	route_steps: int = 0,
	include_global_fallback: bool = true
) -> Dictionary:
	if session == null:
		return _route_interception_empty_surface()
	if include_global_fallback:
		normalize_overworld_state_for_runtime(session)
	if destination_x >= 0 and destination_y >= 0:
		var selected := _selected_route_interception_surface(
			session,
			Vector2i(destination_x, destination_y),
			route_steps
		)
		if bool(selected.get("active", false)):
			return selected
	if not include_global_fallback:
		return _route_interception_empty_surface()
	var convoy := _best_convoy_interception_surface(session)
	if bool(convoy.get("active", false)):
		return convoy
	var raid := _best_raid_interception_surface(session)
	if bool(raid.get("active", false)):
		return raid
	return _route_interception_empty_surface()

static func _route_interception_empty_surface() -> Dictionary:
	return {
		"active": false,
		"kind": "",
		"cue_text": "",
		"visible_text": "",
		"tooltip_text": "",
		"affected": "",
		"why_it_matters": "",
		"next_step": "",
		"importance": "normal",
	}

static func _route_interception_payload(
	kind: String,
	affected: String,
	why_it_matters: String,
	next_step: String,
	cue_text: String,
	importance: String = "normal"
) -> Dictionary:
	var cleaned_affected := _short_player_text(_enemy_activity_public_text(affected), 150)
	var cleaned_why := _short_player_text(_enemy_activity_public_text(why_it_matters), 160)
	var cleaned_next := _short_player_text(_enemy_activity_public_text(next_step), 140)
	var cleaned_cue := _short_player_text(_enemy_activity_public_text(cue_text), 96)
	if cleaned_affected == "" or cleaned_why == "" or cleaned_next == "" or cleaned_cue == "":
		return _route_interception_empty_surface()
	return {
		"active": true,
		"kind": kind,
		"cue_text": cleaned_cue,
		"visible_text": cleaned_cue,
		"tooltip_text": "Interception Watch\n- Affected: %s\n- Why it matters: %s\n- Next: %s" % [
			cleaned_affected,
			cleaned_why,
			cleaned_next,
		],
		"affected": cleaned_affected,
		"why_it_matters": cleaned_why,
		"next_step": cleaned_next,
		"importance": importance,
	}

static func _selected_route_interception_surface(
	session: SessionStateStoreScript.SessionData,
	tile: Vector2i,
	route_steps: int
) -> Dictionary:
	var encounter := _encounter_at_tile(session, tile.x, tile.y)
	if not encounter.is_empty():
		return _raid_interception_surface(session, encounter, route_steps, true)
	var node := _resource_node_at_tile(session, tile.x, tile.y)
	if node.is_empty():
		return _route_interception_empty_surface()
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
	if bool(delivery_state.get("active", false)):
		return _convoy_interception_surface(session, node, site, true)
	var response_state := _resource_site_response_state(session, node, site)
	if bool(response_state.get("active", false)):
		var impact := _resource_site_response_effect_summary(response_state)
		return _route_interception_payload(
			"route_response",
			"%s response holds %s for %d day%s%s." % [
				String(site.get("name", "Route site")),
				String(response_state.get("action_label", "route security")).to_lower(),
				int(response_state.get("remaining_days", 0)),
				"" if int(response_state.get("remaining_days", 0)) == 1 else "s",
				"" if impact == "" else " (%s)" % impact,
			],
			"Active response orders protect economy links, convoy movement, and nearby control pressure before enemy heroes arrive.",
			"Use the protected lane to intercept a hostile host or keep moving toward the next objective.",
			"%s response active" % String(site.get("name", "Route")),
			"normal"
		)
	if String(node.get("collected_by_faction_id", "")) == "player" and int(response_state.get("watch_days", 0)) > 0:
		return _route_interception_payload(
			"route_response_ready",
			"%s can receive %s." % [
				String(site.get("name", "Route site")),
				String(response_state.get("action_label", "route security")).to_lower(),
			],
			"Response orders spend movement and stores to steady route pressure, protect convoys, and support linked towns.",
			"Stand on the site or use the town response order if this lane matters more than the current march.",
			"%s response ready" % String(site.get("name", "Route")),
			"normal"
		)
	return _route_interception_empty_surface()

static func _best_convoy_interception_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var best := _route_interception_empty_surface()
	var best_score := -99999
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
		if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
			continue
		var interception: Dictionary = _resource_site_delivery_interception(session, node, site)
		var score := int(delivery_state.get("manifest_value", 0))
		score += 10000 if bool(interception.get("blocks_delivery", false)) else 0
		score += 4000 if bool(interception.get("active", false)) else 0
		score += max(0, 20 - int(delivery_state.get("days_remaining", 0))) * 10
		if score <= best_score:
			continue
		best_score = score
		best = _convoy_interception_surface(session, node, site, false)
	return best

static func _convoy_interception_surface(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary,
	selected: bool
) -> Dictionary:
	var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
	if not bool(delivery_state.get("active", false)):
		return _route_interception_empty_surface()
	var interception: Dictionary = _resource_site_delivery_interception(session, node, site)
	var site_name := String(site.get("name", "Frontier route"))
	var target_label := String(delivery_state.get("target_label", "the front"))
	var recruit_summary := String(delivery_state.get("recruit_summary", "the convoy"))
	var route_label := "%s convoy to %s" % [site_name, target_label]
	var affected := "%s carries %s; %s." % [
		route_label,
		recruit_summary,
		_resource_site_delivery_line(session, node, site),
	]
	var why := _convoy_interception_why(String(delivery_state.get("target_kind", "")), target_label)
	var next_step := "Keep the convoy route covered until arrival."
	var cue := "Convoy: %s to %s" % [site_name, target_label]
	var importance := "normal"
	if bool(interception.get("blocks_delivery", false)):
		var blocker := String(interception.get("encounter_name", "Enemy army"))
		next_step = "Break %s before ending the day or the convoy stays intercepted." % blocker
		cue = "Convoy blocked: %s" % blocker
		importance = "high"
	elif bool(interception.get("active", false)):
		var hunter := String(interception.get("encounter_name", "Enemy army"))
		next_step = "Intercept %s or reinforce %s before the convoy lane closes." % [
			hunter,
			target_label,
		]
		cue = "Convoy threatened: %s %d tile%s out" % [
			hunter,
			int(interception.get("goal_distance", 0)),
			"" if int(interception.get("goal_distance", 0)) == 1 else "s",
		]
		importance = "high" if int(interception.get("goal_distance", 9999)) <= 1 else "normal"
	elif selected:
		next_step = "Hold this route response or move to intercept enemy heroes before they reach %s." % target_label
		cue = "Convoy active: %s" % target_label
	return _route_interception_payload("convoy", affected, why, next_step, cue, importance)

static func _convoy_interception_why(target_kind: String, target_label: String) -> String:
	match target_kind:
		"town":
			return "Those reserves change %s defense, recovery, recruitment tempo, and control stability." % target_label
		"hero":
			return "Those reserves change the field army's next battle odds and the route choices it can survive."
		"raid":
			return "Those reserves help answer the enemy directly before it turns pressure into losses."
		_:
			return "Convoys turn controlled sites into practical economy, army, and objective tempo."

static func _best_raid_interception_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var best := _route_interception_empty_surface()
	var best_score := -99999
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("spawned_by_faction_id", "")) == "" or is_encounter_resolved(session, encounter):
			continue
		if not _raid_is_public(session, encounter):
			continue
		var goal_distance := int(encounter.get("goal_distance", 9999))
		var score := 2000 if bool(encounter.get("arrived", false)) or goal_distance <= 0 else 0
		score += max(0, 20 - goal_distance) * 20
		if _raid_target_is_objective_anchor(
			session,
			String(encounter.get("target_kind", "")),
			String(encounter.get("target_placement_id", ""))
		):
			score += 1000
		if score <= best_score:
			continue
		best_score = score
		best = _raid_interception_surface(session, encounter, 0, false)
	return best

static func _raid_interception_surface(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	route_steps: int,
	selected: bool
) -> Dictionary:
	if encounter.is_empty() or is_encounter_resolved(session, encounter):
		return _route_interception_empty_surface()
	var encounter_name := encounter_display_name(encounter)
	var target_kind := String(encounter.get("target_kind", ""))
	var target_label := String(encounter.get("target_label", "the frontier"))
	var goal_distance := int(encounter.get("goal_distance", 9999))
	var objective_anchor: bool = _raid_target_is_objective_anchor(
		session,
		target_kind,
		String(encounter.get("target_placement_id", ""))
	)
	var affected := describe_encounter_pressure(session, encounter)
	var why := _raid_interception_why(target_kind, target_label, objective_anchor)
	var next_step := "Select the hostile contact or a route-response site before ending the day."
	var cue := "Enemy: %s toward %s" % [encounter_name, target_label]
	var importance := "normal"
	if selected:
		next_step = "Enter battle now if this route pressure matters more than another site order."
		if route_steps > 0:
			next_step = "Advance %d step%s toward %s; enter battle when adjacent." % [
				route_steps,
				"" if route_steps == 1 else "s",
				encounter_name,
			]
		cue = "Intercept: %s" % encounter_name
	elif bool(encounter.get("arrived", false)) or goal_distance <= 0:
		next_step = "Break %s now or it can turn pressure into control, convoy, or objective losses." % encounter_name
		cue = "Enemy arrived: %s" % encounter_name
		importance = "high"
	elif goal_distance <= 2:
		next_step = "Move to intercept %s before it reaches %s." % [encounter_name, target_label]
		cue = "Enemy close: %s %d tile%s out" % [
			encounter_name,
			goal_distance,
			"" if goal_distance == 1 else "s",
		]
		importance = "high"
	return _route_interception_payload("raid", affected, why, next_step, cue, importance)

static func _raid_interception_why(target_kind: String, target_label: String, objective_anchor: bool) -> String:
	var objective_clause := " It is tied to objective pressure." if objective_anchor else ""
	match target_kind:
		"town":
			return "Enemy attacks threaten control, recruitment, income, and defense readiness at %s.%s" % [target_label, objective_clause]
		"resource":
			return "Enemy attacks threaten linked economy, route response, convoy support, and town logistics at %s.%s" % [target_label, objective_clause]
		"hero":
			return "Hero hunts can force a field battle and pin the army away from route and objective work.%s" % objective_clause
		"artifact":
			return "Enemy heroes can deny a field upgrade before the hero reaches it.%s" % objective_clause
		"encounter":
			return "Enemy pressure on this guard can lock a route and delay objective progress.%s" % objective_clause
		_:
			return "Enemy pressure can become economy, control, convoy, or objective loss if ignored.%s" % objective_clause

static func _event_feed_convoy_line(session: SessionStateStoreScript.SessionData) -> String:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_line := _resource_site_delivery_line(session, node, site)
		if delivery_line != "":
			return "Convoy: %s" % _short_player_text(delivery_line, 120)
	return ""

static func _dispatch_context_brief(session: SessionStateStoreScript.SessionData) -> String:
	var context := get_active_context(session)
	var pos := hero_position(session)
	var terrain := _terrain_name_at(session, pos.x, pos.y)
	match String(context.get("type", "empty")):
		"town":
			var town = context.get("town", {})
			return "%s on %s" % [_town_name(town), terrain]
		"resource":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			return "%s on %s" % [String(site.get("name", "Resource site")), terrain]
		"artifact":
			var artifact_node = context.get("node", {})
			return "%s on %s" % [
				ArtifactRulesScript.describe_artifact_short(String(artifact_node.get("artifact_id", ""))),
				terrain,
			]
		"encounter":
			var encounter_placement = context.get("encounter", {})
			return "%s on %s" % [encounter_display_name(encounter_placement), terrain]
		_:
			return "Open ground at %d,%d on %s" % [pos.x, pos.y, terrain]

static func town_weekly_growth(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	# Without a session the growth is the town's seeded growth alone.
	var cache_key := _town_read_scope_cache_key(session, "weekly_growth", town) if session != null else _town_content_read_scope_key("seeded_weekly_growth", town)
	if _town_read_scope_cache_has(cache_key):
		return _town_read_scope_cache_get(cache_key)
	var result := _effective_player_town_weekly_growth(session, town) if session != null and String(town.get("owner", "neutral")) == "player" else _town_weekly_growth(town, session)
	_town_read_scope_cache_store(cache_key, result)
	return result

static func town_income(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	return _calculate_town_income(town, session)

static func town_reinforcement_quality(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return HumanEngine.native_writing(&"OverworldRules.town_reinforcement_quality", [town, session])

static func town_battle_readiness(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return HumanEngine.native_writing(&"OverworldRules.town_battle_readiness", [town, session])

static func town_pressure_output(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return HumanEngine.native_writing(&"OverworldRules.town_pressure_output", [town, session])

static func town_development_metrics(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	var cache_key := _town_read_scope_cache_key(session, "development_metrics", town)
	if _town_read_scope_cache_has(cache_key):
		return _town_read_scope_cache_get(cache_key)
	var logistics := _town_logistics_state(session, town) if session != null else _empty_town_logistics_state()
	var recovery := _town_recovery_state(session, town, logistics)
	var capital_project := _town_capital_project_state(town, session, logistics, recovery)
	var occupation := _town_occupation_state(session, town)
	var context := {
		"logistics": logistics,
		"recovery": recovery,
		"capital_project": capital_project,
		"occupation": occupation,
	}
	var quality := _town_reinforcement_quality(town, session, context)
	var result := {
		"reinforcement_quality": quality,
		"battle_readiness": _town_battle_readiness(town, session, context, quality),
		"pressure_output": _town_pressure_output(town, session, context, quality),
		"logistics": logistics,
		"recovery": recovery,
		"capital_project": capital_project,
		"occupation": occupation,
	}
	_town_read_scope_cache_store(cache_key, result)
	return result

static func town_strategic_role(town: Dictionary) -> String:
	return _town_strategic_role(town)

static func town_strategic_summary(town: Dictionary) -> String:
	return _town_strategic_summary(town)

static func describe_faction_identity_surface(faction_id: String) -> String:
	return _faction_identity_surface(faction_id)

static func describe_town_identity_surface(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	return _town_identity_surface(town, session)

static func town_capital_project_state(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	var cache_key := _town_read_scope_cache_key(session, "capital_project", town)
	if _town_read_scope_cache_has(cache_key):
		return _town_read_scope_cache_get(cache_key)
	var result := _town_capital_project_state(town, session)
	_town_read_scope_cache_store(cache_key, result)
	return result

static func town_logistics_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_logistics_state", [session, town])

static func town_recovery_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var cache_key := _town_read_scope_cache_key(session, "recovery", town)
	if _town_read_scope_cache_has(cache_key):
		return _town_read_scope_cache_get(cache_key)
	var result := _town_recovery_state(session, town)
	_town_read_scope_cache_store(cache_key, result)
	return result

static func town_public_threat_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var cache_key := _town_read_scope_cache_key(session, "public_threat", town)
	if _town_read_scope_cache_has(cache_key):
		return _town_read_scope_cache_get(cache_key)
	var result := _town_command_risk_state(session, town)
	_town_read_scope_cache_store(cache_key, result)
	return result

static func town_battlefront_profile(town: Dictionary) -> Dictionary:
	return _town_battlefront_profile(town)

static func town_front_state(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	precomputed_development_metrics: Dictionary = {}
) -> Dictionary:
	var extra := JSON.stringify(precomputed_development_metrics).sha256_text() if not precomputed_development_metrics.is_empty() else ""
	var cache_key := _town_read_scope_cache_key(session, "front", town, extra)
	if _town_read_scope_cache_has(cache_key):
		return _town_read_scope_cache_get(cache_key)
	var result := _town_front_state(session, town, precomputed_development_metrics)
	_town_read_scope_cache_store(cache_key, result)
	return result

static func town_occupation_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var cache_key := _town_read_scope_cache_key(session, "occupation", town)
	if _town_read_scope_cache_has(cache_key):
		return _town_read_scope_cache_get(cache_key)
	var result := _town_occupation_state(session, town)
	_town_read_scope_cache_store(cache_key, result)
	return result

static func town_market_state(town: Dictionary) -> Dictionary:
	return _town_market_state(town)

static func describe_town_market(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	return "\n".join(_town_market_panel_lines(session, town))

static func describe_town_response_panel(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	return "\n".join(_town_response_panel_lines(session, town))

static func controlled_resource_site_income(
	session: SessionStateStoreScript.SessionData,
	controller_id: String,
	income_day: int = -1
) -> Dictionary:
	var income := _empty_live_resource_stockpile()
	var resolved_income_day := int(session.day) if income_day < 0 else income_day
	for node in session.overworld.get("resource_nodes", []):
		# The resource bar asks every refresh: skip unowned sites before the content lookup.
		if not (node is Dictionary) or not _resource_node_matches_controller(node, controller_id):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site):
			continue
		income = _add_resource_sets(income, _resource_site_control_income_for_day(site, resolved_income_day))
	return income

static func _resource_site_control_income_for_day(site: Dictionary, day: int) -> Dictionary:
	var income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
	if String(site.get("control_income_cadence", "daily")) == "weekly" and not is_weekly_growth_day(day):
		return {}
	return income

static func _resource_site_income_cadence_label(site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_income_cadence_label", [site])

## Resources the player receives at the next daybreak: the same projection as
## the end-turn income forecast (towns, hero artifacts/specialties, sites).
static func player_daily_income(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return _empty_live_resource_stockpile()
	return _player_daily_income_projection(session, int(session.day) + 1)

static func _player_daily_income_projection(
	session: SessionStateStoreScript.SessionData,
	next_day: int
) -> Dictionary:
	var town_income := _empty_live_resource_stockpile()
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var projection := _project_player_town_at_daybreak(session, town, index, next_day)
		var projected_session: SessionStateStoreScript.SessionData = projection.get("session", session)
		var projected_town: Dictionary = projection.get("town", town)
		town_income = _add_resource_sets(
			town_income,
			DifficultyRulesScript.scale_income_resources(
				projected_session,
				_calculate_town_income(projected_town, projected_session)
			)
		)
	var hero_income := _player_heroes_daily_income(session)
	var artifact_income: Dictionary = hero_income.get("artifact", {})
	var specialty_income: Dictionary = hero_income.get("specialty", {})
	var site_income = DifficultyRulesScript.scale_income_resources(
		session,
		controlled_resource_site_income(session, "player", next_day)
	)
	return _add_resource_sets(
		_add_resource_sets(_add_resource_sets(town_income, artifact_income), specialty_income),
		site_income
	)

static func _end_turn_income_forecast_line(session: SessionStateStoreScript.SessionData, next_day: int) -> String:
	var income_summary := _describe_resource_delta(_player_daily_income_projection(session, next_day))
	if income_summary == "":
		return "income steady"
	return "income %s" % income_summary

static func _end_turn_muster_forecast_line(session: SessionStateStoreScript.SessionData, next_day: int) -> String:
	if is_weekly_growth_day(next_day):
		var previews := []
		var towns = session.overworld.get("towns", [])
		for index in range(towns.size()):
			var town = towns[index]
			if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
				continue
			var projection := _project_player_town_at_daybreak(session, town, index, next_day)
			var projected_session: SessionStateStoreScript.SessionData = projection.get("session", session)
			var projected_town: Dictionary = projection.get("town", town)
			var growth_summary := _describe_recruit_delta(town_weekly_growth(projected_town, projected_session))
			if growth_summary != "":
				previews.append("%s %s" % [_town_name(town), growth_summary])
			if previews.size() >= 2:
				break
		if previews.is_empty():
			return "weekly muster resolves"
		return "weekly muster %s" % "; ".join(previews)
	var days_until: int = max(1, next_weekly_growth_day(session.day) - next_day)
	return "muster Day %d in %d day%s" % [
		next_weekly_growth_day(session.day),
		days_until,
		"" if days_until == 1 else "s",
	]

static func _project_player_town_at_daybreak(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	town_index: int,
	next_day: int
) -> Dictionary:
	var live_towns = session.overworld.get("towns", [])
	if not (live_towns is Array) or town_index < 0 or town_index >= live_towns.size():
		return {"session": session, "town": town}

	var projected_session := SessionStateStoreScript.SessionData.new()
	projected_session.save_version = session.save_version
	projected_session.session_id = session.session_id
	projected_session.scenario_id = session.scenario_id
	projected_session.hero_id = session.hero_id
	projected_session.day = next_day
	projected_session.difficulty = session.difficulty
	projected_session.launch_mode = session.launch_mode
	projected_session.game_state = session.game_state
	projected_session.scenario_status = session.scenario_status
	projected_session.scenario_summary = session.scenario_summary
	projected_session.overworld = session.overworld.duplicate(false)
	projected_session.battle = session.battle.duplicate(false)
	projected_session.flags = session.flags.duplicate(false)

	var projected_towns: Array = live_towns.duplicate(false)
	var projected_town: Dictionary = town.duplicate(true)
	projected_towns[town_index] = projected_town
	projected_session.overworld["towns"] = projected_towns

	var occupation_result := _advance_town_occupation(projected_session, projected_town)
	projected_town = occupation_result.get("town", projected_town)
	projected_towns[town_index] = projected_town
	projected_session.overworld["towns"] = projected_towns

	var recovery_result := _advance_town_recovery(projected_session, projected_town)
	projected_town = recovery_result.get("town", projected_town)
	projected_towns[town_index] = projected_town
	projected_session.overworld["towns"] = projected_towns
	return {"session": projected_session, "town": projected_town}

static func _end_turn_movement_forecast_line(session: SessionStateStoreScript.SessionData) -> String:
	var max_movement := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	return "move resets %d/%d" % [max_movement, max_movement]

static func _end_turn_risk_forecast_line(session: SessionStateStoreScript.SessionData) -> String:
	var risk_surface := describe_command_risk_surfaces(session)
	var risk_text := String(risk_surface.get("risk", "")).strip_edges()
	if risk_text == "" or risk_text.find("Steady watch") >= 0:
		var local_pressure := _local_visible_threat_summary(session, "")
		return local_pressure if local_pressure != "" else "watch steady"
	var lines := risk_text.split("\n", false)
	return _short_player_text(String(lines[lines.size() - 1]), 96)

static func _end_turn_risk_forecast_line_from_watch_context(refresh_watch_context: Dictionary) -> String:
	var risk_surface_value = refresh_watch_context.get("command_risk_surfaces", {})
	var risk_surface: Dictionary = risk_surface_value if risk_surface_value is Dictionary else {}
	var risk_text := String(risk_surface.get("risk", "")).strip_edges()
	if risk_text == "" or risk_text.find("Steady watch") >= 0:
		var local_pressure := String(refresh_watch_context.get("local_pressure", ""))
		return local_pressure if local_pressure != "" else "watch steady"
	var lines := risk_text.split("\n", false)
	return _short_player_text(String(lines[lines.size() - 1]), 96)

static func _end_turn_muster_summary(weekly_growth_messages: Array, site_muster_messages: Array) -> String:
	var parts := []
	for message in weekly_growth_messages:
		var text := String(message).strip_edges()
		if text != "":
			parts.append(text)
	for message in site_muster_messages:
		var text := String(message).strip_edges()
		if text != "":
			parts.append(text)
	if parts.is_empty():
		return ""
	return "; ".join(parts)

static func _end_turn_town_economy_summary(
	occupation_messages: Array,
	recovery_messages: Array,
	delivery_messages: Array
) -> String:
	var parts := []
	for source in [occupation_messages, recovery_messages, delivery_messages]:
		for message in source:
			var text := String(message).strip_edges()
			if text != "":
				parts.append(text)
			if parts.size() >= 3:
				return "; ".join(parts)
	return "; ".join(parts)

static func _end_turn_resolution_summary(session: SessionStateStoreScript.SessionData, result: Dictionary) -> String:
	var parts := ["Day %d" % session.day]
	var income_summary := String(result.get("resource_income_summary", "")).strip_edges()
	if income_summary != "":
		parts.append("income %s" % income_summary)
	var movement_summary := String(result.get("movement_reset_summary", "")).strip_edges()
	if movement_summary != "":
		parts.append(movement_summary)
	var muster_summary := String(result.get("weekly_muster_summary", "")).strip_edges()
	if muster_summary != "":
		parts.append("muster %s" % _short_player_text(muster_summary, 72))
	var town_summary := String(result.get("town_economy_summary", "")).strip_edges()
	if town_summary != "":
		parts.append("towns %s" % _short_player_text(town_summary, 72))
	var enemy_summary := String(result.get("enemy_activity_summary", "")).strip_edges()
	if enemy_summary != "":
		parts.append("enemy %s" % _short_player_text(enemy_summary, 96))
	return " | ".join(parts)

static func apply_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> Array:
	return _apply_market_cost_coverage(town, pool, cost, current_day)

static func town_cost_readiness(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_cost_readiness", [town, pool, cost, current_day])

static func controlled_resource_site_pressure_bonus(session: SessionStateStoreScript.SessionData, controller_id: String) -> int:
	var total := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		total += max(0, int(site.get("pressure_bonus", 0)))
		var weekly_recruits = _resource_site_weekly_recruits(site)
		if controller_id != "player" and weekly_recruits is Dictionary and not weekly_recruits.is_empty() and not CreatureDwellings.is_dwelling(site):
			total += 1
	return total

static func player_resource_site_pressure_guard(session: SessionStateStoreScript.SessionData) -> int:
	var total := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, "player"):
			continue
		total += max(0, int(site.get("pressure_guard", 0)))
		var response_state := _resource_site_response_state(session, node, site)
		if bool(response_state.get("active", false)):
			total += int(response_state.get("pressure_guard_bonus", 0))
	return total

static func apply_controlled_resource_site_musters(session: SessionStateStoreScript.SessionData, controller_id: String) -> Array:
	var messages := []
	var towns = session.overworld.get("towns", [])
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var weekly_recruits = _resource_site_weekly_recruits(site)
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		# Dwellings are hired at the dwelling; they never feed a town.
		if CreatureDwellings.is_dwelling(site):
			continue
		if not (weekly_recruits is Dictionary) or weekly_recruits.is_empty():
			continue
		var town_result := _nearest_town_for_controller(session, controller_id, int(node.get("x", 0)), int(node.get("y", 0)), OverworldLevelRulesScript.level_of(node))
		if int(town_result.get("index", -1)) < 0:
			continue
		var town = town_result.get("town", {})
		town["available_recruits"] = _add_recruit_growth(town.get("available_recruits", {}), weekly_recruits)
		towns[int(town_result.get("index", -1))] = town
		messages.append(
			"%s feeds %s (%s)" % [
				String(site.get("name", "Frontier site")),
				_town_name(town),
				_describe_recruit_delta(weekly_recruits),
			]
		)
	session.overworld["towns"] = towns
	return messages

static func controlled_resource_site_count(
	session: SessionStateStoreScript.SessionData,
	controller_id: String,
	family_id: String = ""
) -> int:
	var count := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site) or not _resource_node_matches_controller(node, controller_id):
			continue
		if family_id != "" and String(site.get("family", "")) != family_id:
			continue
		count += 1
	return count

static func describe_management_watch(session: SessionStateStoreScript.SessionData) -> String:
	normalize_overworld_state(session)
	return _describe_management_watch_from_normalized_session(session)

static func _describe_management_watch_from_normalized_session(
	session: SessionStateStoreScript.SessionData
) -> String:
	var project_summary := ""
	var disruption_summary := ""
	var recovery_summary := ""
	var delivery_summary := ""
	var project_score := -1
	var disruption_score := -1
	var recovery_score := -1
	var delivery_score := -1
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var town_name := _town_name(town)
		var logistics := town_logistics_state(session, town)
		var recovery := town_recovery_state(session, town)
		var capital_project := town_capital_project_state(town, session)
		var role := town_strategic_role(town)
		var local_project_score := int(capital_project.get("progress_complete", 0))
		if role == "capital":
			local_project_score += 4
		elif role == "stronghold":
			local_project_score += 2
		if bool(capital_project.get("vulnerable", false)):
			local_project_score += 6
		if local_project_score > project_score and (role in ["capital", "stronghold"] or int(capital_project.get("total", 0)) > 0):
			project_score = local_project_score
			project_summary = "%s project %d/%d%s" % [
				town_name,
				int(capital_project.get("progress_complete", 0)),
				int(capital_project.get("progress_total", 0)),
				" vulnerable" if bool(capital_project.get("vulnerable", false)) else "",
			]
		var local_disruption_score := int(logistics.get("disrupted_count", 0)) * 2 + int(logistics.get("threatened_count", 0))
		if local_disruption_score > disruption_score and local_disruption_score > 0:
			disruption_score = local_disruption_score
			disruption_summary = "%s logistics %s" % [town_name, String(logistics.get("summary", ""))]
		var local_recovery_score := int(recovery.get("pressure", 0))
		if local_recovery_score > recovery_score:
			recovery_score = local_recovery_score
			if bool(recovery.get("active", false)):
				recovery_summary = "%s %s" % [town_name, String(recovery.get("summary", ""))]
		var local_delivery_score := int(logistics.get("delivery_count", 0)) * 2 + int(logistics.get("threatened_count", 0))
		if local_delivery_score > delivery_score and int(logistics.get("delivery_count", 0)) > 0:
			delivery_score = local_delivery_score
			var delivery_labels = logistics.get("delivery_site_labels", [])
			if delivery_labels is Array and not delivery_labels.is_empty():
				delivery_summary = "%s %s" % [town_name, String(delivery_labels[0])]
	var parts := []
	if project_summary != "":
		parts.append(project_summary)
	if disruption_summary != "":
		parts.append(disruption_summary)
	if recovery_summary != "":
		parts.append(recovery_summary)
	if delivery_summary != "":
		parts.append(delivery_summary)
	if parts.is_empty():
		return "Town lines are stable."
	return " | ".join(parts)

static func describe_town_build_projection(session: SessionStateStoreScript.SessionData, town: Dictionary, building_id: String) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_town_build_projection", [session, town, building_id])

static func apply_town_recovery_pressure(
	session: SessionStateStoreScript.SessionData,
	town_placement_id: String,
	amount: int,
	source: String = ""
) -> String:
	if session == null or town_placement_id == "" or amount <= 0:
		return ""
	var town_result := _find_town_by_placement(session, town_placement_id)
	if int(town_result.get("index", -1)) < 0:
		return ""
	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	var recovery := _normalize_town_recovery_state(town.get("recovery", {}))
	recovery["pressure"] = max(0, int(recovery.get("pressure", 0))) + amount
	recovery["last_event_day"] = session.day
	recovery["source"] = source
	town["recovery"] = recovery
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	var recovery_state := town_recovery_state(session, town)
	var source_clause := " from %s" % source if source != "" else ""
	return "%s recovery +%d%s | %d day%s to stabilize." % [
		_town_name(town),
		amount,
		source_clause,
		int(recovery_state.get("days_to_clear", 0)),
		"" if int(recovery_state.get("days_to_clear", 0)) == 1 else "s",
	]

static func relieve_town_recovery_pressure(session: SessionStateStoreScript.SessionData, town_placement_id: String, amount: int, source: String = "") -> String:
	return HumanEngine.native_writing(&"OverworldRules.relieve_town_recovery_pressure", [session, town_placement_id, amount, source])

static func apply_resource_site_disruption(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary,
	previous_controller: String,
	attacker_controller: String
) -> String:
	if previous_controller in ["", attacker_controller]:
		return ""
	var town_result := _nearest_town_for_controller(
		session,
		previous_controller,
		int(node.get("x", 0)),
		int(node.get("y", 0)),
		OverworldLevelRulesScript.level_of(node)
	)
	if int(town_result.get("index", -1)) < 0:
		return ""
	var town = town_result.get("town", {})
	var distance = abs(int(node.get("x", 0)) - int(town.get("x", 0))) + abs(int(node.get("y", 0)) - int(town.get("y", 0)))
	if distance > int(_town_logistics_plan(town).get("support_radius", 0)):
		return ""
	var disruption_pressure := int(_resource_site_town_support(site).get("disruption_pressure", 0))
	var response_state := _resource_site_response_state(session, node, site)
	var disruption_source := String(site.get("name", "frontier route"))
	if bool(response_state.get("active", false)):
		disruption_pressure += max(1, int(response_state.get("recovery_relief", 0)))
		disruption_pressure += max(1, int(response_state.get("break_pressure", 0)))
		disruption_source = "%s escort line" % disruption_source
	if disruption_pressure <= 0:
		return ""
	return apply_town_recovery_pressure(
		session,
		String(town.get("placement_id", "")),
		disruption_pressure,
		disruption_source
	)

static func town_recruit_cost(session: SessionStateStoreScript.SessionData, town: Dictionary, unit_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules.town_recruit_cost", [session, town, unit_id])

static func _town_scaling_hero(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	# Recruit prices and growth follow the commander stationed in this town, not
	# whichever hero happens to be selected. No local hero means no hero bonus.
	if session == null or town.is_empty():
		return {}
	var hero := HeroCommandRulesScript.town_defending_hero(session, town)
	var hero_id := String(hero.get("id", ""))
	if hero_id == "":
		return {}
	# The active mirror can be ahead of its roster entry until commit_active_hero.
	var active = session.overworld.get("hero", {})
	if active is Dictionary and hero_id == String(session.overworld.get("active_hero_id", "")) and String(active.get("id", "")) == hero_id:
		return active
	return hero

static func _player_heroes_daily_income(session: SessionStateStoreScript.SessionData) -> Dictionary:
	# Every commander's artifacts and specialties earn income, whichever is selected.
	var artifact_income := {}
	var specialty_income := {}
	for hero in _player_hero_states(session):
		artifact_income = _add_resource_sets(artifact_income, ArtifactRulesScript.aggregate_bonuses(hero).get("daily_income", {}))
		specialty_income = _add_resource_sets(specialty_income, HeroProgressionRulesScript.daily_income_bonus(hero))
	return {
		"artifact": DifficultyRulesScript.scale_income_resources(session, artifact_income),
		"specialty": specialty_income,
	}

static func _player_hero_states(session: SessionStateStoreScript.SessionData) -> Array:
	var heroes := []
	if session == null:
		return heroes
	var active = session.overworld.get("hero", {})
	var active_id := ""
	if active is Dictionary and not active.is_empty():
		active_id = String(active.get("id", ""))
		heroes.append(active)
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and (active_id == "" or String(hero.get("id", "")) != active_id):
			heroes.append(hero)
	return heroes

static func get_town_build_status(town: Dictionary, building_id: String, current_day: int = -1) -> Dictionary:
	# Town screens check every building's status many times per refresh.
	var cache_key := _town_content_read_scope_key("build_status", town, "%s|%d" % [building_id, current_day])
	if _town_read_scope_cache_has(cache_key):
		return _build_status_copy(_normalized_read_scope_cache[cache_key])
	var status := _town_build_status(town, building_id, current_day)
	if cache_key != "":
		_normalized_read_scope_cache[cache_key] = _build_status_copy(status)
		_last_normalized_read_scope_cache_profile["entries"] = _normalized_read_scope_cache.size()
	return status

## A build status as get_town_build_status returns it: its own dictionary and
## blocker list, sharing the authored building record like the original.
static func _build_status_copy(status: Dictionary) -> Dictionary:
	var copy := status.duplicate()
	if copy.get("blockers", null) is Array:
		copy["blockers"] = (copy["blockers"] as Array).duplicate()
	return copy

static func _town_build_status(town: Dictionary, building_id: String, current_day: int = -1) -> Dictionary:
	return _town_build_status_in(_town_build_context(town), town, building_id, current_day)

## What every build status of one town reads from the town and its template:
## the built stages as the rules count them, the stages they satisfy, the
## template's buildable ids and the town's faction. Read-only.
static func _town_build_context(town: Dictionary) -> Dictionary:
	var current := TownDevelopment.is_current(town)
	var built_buildings := _normalize_built_buildings_for_town_state(town)
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var buildable_ids := []
	for buildable_id_value in town_template.get("buildable_building_ids", []):
		buildable_ids.append(String(buildable_id_value))
	return {
		"current": current,
		"built": built_buildings,
		"satisfied": TownDevelopment.satisfied_ids(built_buildings),
		"buildable_ids": buildable_ids,
		"faction_id": String(town_template.get("faction_id", "")),
	}

static func _town_build_status_in(context: Dictionary, town: Dictionary, building_id: String, current_day: int) -> Dictionary:
	var building := ContentService.get_building(building_id)
	if building.is_empty():
		return {
			"buildable": false,
			"blockers": ["Missing authored building data."],
			"blocked_message": "That building has no authored data.",
		}

	var built_buildings: Array = context["built"]
	var satisfied: Dictionary = context["satisfied"]
	# A current town's built stages are its active stages.
	var current := bool(context["current"])
	var blockers := []
	if building_id not in context["buildable_ids"]:
		blockers.append("Not authored for this town.")
	if satisfied.has(building_id):
		blockers.append("Already built.")
	if (TownDevelopment.choice_blocked_among(built_buildings, building) if current else TownDevelopment.choice_blocked(town, building)):
		blockers.append("The other dwelling at this tier has already been chosen.")
	var required_tier := int(building.get("requires_dwelling_tier", 0))
	if required_tier > 0 and not (TownDevelopment.has_dwelling_tier_among(built_buildings, required_tier) if current else TownDevelopment.has_dwelling_tier(town, required_tier)):
		blockers.append("Requires either tier-%d dwelling." % required_tier)
	if current_day > 0 and int(town.get("last_build_day", 0)) == current_day:
		blockers.append("Already built in this town today.")
	var missing_requirements := _missing_build_requirements_among(building, satisfied)
	for requirement_id in missing_requirements:
		var requirement := ContentService.get_building(String(requirement_id))
		var requirement_name := String(requirement.get("name", requirement_id))
		if String(building.get("upgrade_from", "")) == String(requirement_id):
			blockers.append("Upgrade %s first." % requirement_name)
		else:
			blockers.append("Requires %s." % requirement_name)

	var building_faction_id := String(building.get("faction_id", ""))
	var town_faction_id := String(context["faction_id"])
	if building_faction_id != "" and town_faction_id != "" and building_faction_id != town_faction_id:
		var faction_name := String(ContentService.get_faction(building_faction_id).get("name", building_faction_id))
		blockers.append("Belongs to %s towns." % faction_name)

	return {
		"buildable": blockers.is_empty(),
		"blockers": blockers,
		"blocked_message": " ".join(blockers),
		"building": building,
	}

## _missing_build_requirements with the stages the built list satisfies at hand.
static func _missing_build_requirements_among(building: Dictionary, satisfied: Dictionary) -> Array:
	var missing := []
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and not satisfied.has(upgrade_from):
		missing.append(upgrade_from)
	for requirement_value in building.get("requires", []):
		var requirement := String(requirement_value)
		if requirement == "" or satisfied.has(requirement) or requirement in missing:
			continue
		missing.append(requirement)
	return missing

static func get_context_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_context_actions", [session])

static func get_rendezvous_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_overworld_state_for_runtime(session)
	return HeroCommandRulesScript.get_field_transfer_actions(session)

static func get_rendezvous_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_overworld_state_for_runtime(session)
	var actions := HeroCommandRulesScript.get_field_transfer_actions(session)
	actions.append_array(HeroCommandRulesScript.get_field_artifact_transfer_actions(session))
	actions.append_array(HeroCommandRulesScript.get_field_spell_share_actions(session))
	return actions

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

static func get_town_build_options(town: Dictionary, current_day: int = -1) -> Array:
	var options := []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	# Outside a read scope each status is computed afresh, so they can share
	# one reading of the town.
	var context := _town_build_context(town) if _normalized_read_scope_depth <= 0 else {}
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		var status := get_town_build_status(town, building_id, current_day) if context.is_empty() else _town_build_status_in(context, town, building_id, current_day)
		if bool(status.get("buildable", false)):
			options.append(building_id)
	return options

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

static func _normalize_towns(towns: Array, current_day: int = -1) -> Array:
	var normalized := []
	for town in towns:
		if not (town is Dictionary):
			continue
		var built_buildings = town.get("built_buildings", [])
		if not (built_buildings is Array):
			built_buildings = []
		var normalized_town := {
			"placement_id": String(town.get("placement_id", "")),
			"town_id": String(town.get("town_id", "")),
			"x": int(town.get("x", 0)),
			"y": int(town.get("y", 0)),
			"owner": String(town.get("owner", "neutral")),
			"controlling_faction_id": String(town.get("controlling_faction_id", "")),
			"built_buildings": built_buildings.duplicate(true),
			"available_recruits": _normalize_resource_dict(town.get("available_recruits", {})),
			"garrison": town.get("garrison", []).duplicate(true) if town.get("garrison", []) is Array else [],
			"recovery": _normalize_town_recovery_state(town.get("recovery", {})),
			"front": _normalize_town_front_state(town.get("front", {})),
			"occupation": _normalize_town_occupation_state(town.get("occupation", {})),
			"last_build_day": max(0, int(town.get("last_build_day", 0))),
			"market_usage": _normalize_town_market_usage_state(town.get("market_usage", {}), current_day),
		}
		_copy_town_runtime_metadata(normalized_town, town)
		TownDevelopment.migrate_town(normalized_town)
		normalized_town["built_buildings"] = _normalize_built_buildings_for_town_state(normalized_town)
		if not town.has("available_recruits") or not (town.get("available_recruits") is Dictionary):
			normalized_town["available_recruits"] = _seed_recruits_for_town(normalized_town)
		normalized.append(normalized_town)
	return normalized

static func _copy_town_runtime_metadata(target: Dictionary, source: Dictionary) -> void:
	for key in [
		"development_version",
		"garrison_hero_id",
		"legacy_built_buildings",
		"artifact_shop_purchases",
		"town_service_claims",
		"controlling_player_id",
		"owner_slot",
		"level",
		"hero_start_tile",
		"runtime_start_tile",
		"player_slot",
		"player_type",
		"team_id",
		"faction_id",
		"is_start_town",
		"start_anchor",
		"body_tiles",
		"blocking_body",
		"approach_tiles",
		"visit_tile",
		"package_visit_tiles",
		"package_body_tiles",
		"package_block_tiles",
		"passability_class",
		"zone_id",
		"zone_role",
		"ai_defended_by_faction_id",
		"ai_defended_by_player_id",
		"ai_defended_day",
		"ai_defense_until_day",
		"ai_defense_rating",
		"ai_defense_reinforced_strength",
		"ai_defender_commander_state",
		"ai_defender_roster_hero_id",
		"artifact_reward_id",
		"artifact_reward_table_id",
		"artifact_reward_source_key",
		"artifact_reward_claimed_by_owner",
		"artifact_reward_claimed_by_faction_id",
		"artifact_reward_claimed_by_player_id",
		"artifact_reward_claimed_day",
		"artifact_reward_service_building_id",
	]:
		if source.has(key):
			target[key] = source[key].duplicate(true) if source[key] is Array or source[key] is Dictionary else source[key]

static func _normalize_resource_nodes(nodes: Array) -> Array:
	return DayEngine.native(&"OverworldRules._normalize_resource_nodes", [nodes])

static func _copy_resource_runtime_metadata(target: Dictionary, source: Dictionary) -> void:
	for key in [
		"reward_choice_id",
		"route_state_id",
		"state_id",
		"native_transit",
		"h3m_type_id",
		"h3m_subtype",
		"collected_by_player_id",
		"level",
		"content_batch_id",
		"object_id",
		"zone_id",
		"owner",
		"player_slot",
		"player_type",
		"team_id",
		"kind",
		"generated_kind",
		"original_resource_category_id",
		"resource_id",
		"neutral_dwelling_family_id",
		"guard_pressure",
		"guard_front_id",
		"body_tiles",
		"blocking_body",
		"approach_tiles",
		"visit_tile",
		"package_body_tiles",
		"package_block_tiles",
		"package_visit_tiles",
		"passability_class",
		"pathing_status",
		"object_footprint_catalog_ref",
		"footprint",
		"runtime_footprint",
		"body_mask",
		"runtime_body_mask",
		"visit_mask",
		"approach_mask",
		"passability_mask",
		"action_mask",
		"terrain_restrictions",
		"placement_predicates",
		"placement_predicate_results",
		"footprint_deferred",
		"front",
		"ai_defended_by_faction_id",
		"ai_defended_by_player_id",
		"ai_defended_day",
		"ai_defense_until_day",
		"ai_defense_rating",
		"ai_defense_reinforced_strength",
		"ai_defender_army",
		"ai_defender_commander_state",
		"ai_defender_roster_hero_id",
		"development_source_support",
		"source_support_town_placement_id",
		"source_support_faction_id",
		"source_support_missing_resource_ids",
		"artifact_reward_id",
		"artifact_reward_ids",
		"artifact_reward_table_id",
		"artifact_reward_source_key",
		"artifact_reward_claimed_by_faction_id",
		"artifact_reward_claimed_by_player_id",
		"artifact_reward_claimed_day",
		NodePayload.PAYLOAD_REWARDS,
		NodePayload.PAYLOAD_REWARD_CHOICES,
		NodePayload.PAYLOAD_SPELL_IDS,
		NodePayload.CLAIM_PAYLOAD_SPENT,
		NodePayload.PAYLOAD_VISIT,
		NodePayload.PAYLOAD_RECRUITS,
		NodePayload.PAYLOAD_VISION_RADIUS,
		NodePayload.PAYLOAD_ARTIFACT_CLASSES,
		NodePayload.PAYLOAD_ARTIFACT_RARITY,
		"generated_bank_level",
		"generated_reward_unguarded",
		VisitBuildings.HERO_VISITS,
		VisitBuildings.SIDE_VISITS,
		CreatureDwellings.POPULATION,
		CreatureDwellings.POPULATION_WEEK,
		CreatureDwellings.GUARD_BEATEN,
		CreatureDwellings.GUARD_SURVIVORS,
		VisitBuildings.SITE_LAST_VISIT_DAY,
		"generated_reward_translation",
	]:
		if source.has(key):
			target[key] = source[key].duplicate(true) if source[key] is Array or source[key] is Dictionary else source[key]

static func _normalize_artifact_nodes(nodes: Array, scenario_id: String = "") -> Array:
	return ArtifactRulesScript.normalize_artifact_nodes(nodes, scenario_id)

static func _find_resource_node_at(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._find_resource_node_at", [session])

static func _find_context_resource_node(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._find_context_resource_node", [session])

static func _find_resource_node_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "node": {}}
	var lookup_started_usec := _rules_profile_timer()
	var nodes = session.overworld.get("resource_nodes", [])
	_rules_profile_set("descriptor", "lookup_collection_size", nodes.size() if nodes is Array else 0)
	var lookup_index := _spatial_lookup_index(session)
	var by_placement: Dictionary = lookup_index.get("resource_by_placement", {}) if lookup_index.get("resource_by_placement", {}) is Dictionary else {}
	if by_placement.has(placement_id):
		var indexed := int(by_placement.get(placement_id, -1))
		if nodes is Array and indexed >= 0 and indexed < nodes.size():
			var indexed_node = nodes[indexed]
			if indexed_node is Dictionary and String(indexed_node.get("placement_id", "")) == placement_id:
				_rules_profile_set("descriptor", "lookup_mode", "placement_index")
				_rules_profile_add_ms("descriptor_lookup_ms", lookup_started_usec)
				return {"index": indexed, "node": indexed_node}
	_rules_profile_set("descriptor", "lookup_mode", "full_scan_fallback")
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			_rules_profile_add_ms("descriptor_lookup_ms", lookup_started_usec)
			return {"index": index, "node": node}
	_rules_profile_add_ms("descriptor_lookup_ms", lookup_started_usec)
	return {"index": -1, "node": {}}

static func _find_active_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var visit_result := _find_active_town_by_visit_context(session)
	if int(visit_result.get("index", -1)) >= 0:
		return visit_result
	var pos := hero_position(session)
	var towns = session.overworld.get("towns", [])
	var lookup_index := _spatial_lookup_index(session)
	var town_by_tile: Dictionary = lookup_index.get("town_by_tile", {}) if lookup_index.get("town_by_tile", {}) is Dictionary else {}
	var index := int(town_by_tile.get(_tile_key(pos), -1))
	if towns is Array and index >= 0 and index < towns.size() and towns[index] is Dictionary:
		return {"index": index, "town": towns[index]}
	return {"index": -1, "town": {}}

static func _find_active_town_by_visit_context(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {"index": -1, "town": {}}
	var placement_id := String(session.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, ""))
	if placement_id == "":
		return {"index": -1, "town": {}}
	var town_result := _find_town_by_placement(session, placement_id)
	var town: Dictionary = town_result.get("town", {})
	if int(town_result.get("index", -1)) >= 0 and String(town.get("owner", "neutral")) == "player":
		return town_result
	session.flags.erase(ACTIVE_TOWN_PLACEMENT_KEY)
	return {"index": -1, "town": {}}

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
	return bool(site.get("persistent_control", false))

static func resource_node_is_present(node: Dictionary, site: Dictionary = {}) -> bool:
	# Shared by collision, route/context queries and the map renderer. Ownership
	# and cooldowns do not consume a permanent service or a native passage.
	if not bool(node.get("collected", false)) or NativeTransit.is_native(node):
		return true
	if site.is_empty():
		site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if _resource_site_is_persistent(site) or _resource_site_is_repeatable(site):
		return true
	# A one-time site whose object stays after its visit (a looted guarded bank,
	# an opened route camp) remains in its claimed state; pickups are taken.
	return bool(_map_object_for_resource_node(node).get("interaction", {}).get("remains_after_visit", false))

static func _resource_node_matches_controller(node: Dictionary, controller_id: String) -> bool:
	return PlayerRules.resource_controller_id(node) == controller_id

static func _resource_site_is_repeatable(site: Dictionary) -> bool:
	return bool(site.get("repeatable", false)) or String(site.get("family", "")) == "repeatable_service"

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

static func capture_resource_after_defender_victory(
	session: SessionStateStoreScript.SessionData,
	placement_id: String
) -> Dictionary:
	if session == null or placement_id == "":
		return {"ok": false, "message": ""}
	var node_result := _find_resource_node_by_placement(session, placement_id)
	if int(node_result.get("index", -1)) < 0:
		return {"ok": false, "message": ""}
	var node: Dictionary = node_result.get("node", {})
	var site := NodePayload.site_for_node(node)
	if site.is_empty() or not _resource_site_is_persistent(site):
		return {"ok": false, "message": ""}
	var nodes = session.overworld.get("resource_nodes", [])
	node = _clear_resource_ai_defender_metadata(node)
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["resource_nodes"] = nodes
	var refreshed := _find_resource_node_by_placement(session, placement_id)
	return _collect_resource_node_result(session, refreshed)

static func _clear_resource_ai_defender_metadata(node: Dictionary) -> Dictionary:
	var cleared := node.duplicate(true)
	cleared.erase("ai_defender_commander_state")
	cleared.erase("ai_defender_roster_hero_id")
	cleared.erase("ai_defender_army")
	cleared.erase("ai_defended_by_faction_id")
	cleared.erase("ai_defended_by_player_id")
	cleared.erase("ai_defended_day")
	cleared.erase("ai_defense_until_day")
	cleared.erase("ai_defense_rating")
	cleared.erase("ai_defense_reinforced_strength")
	var front: Dictionary = cleared.get("front", {}) if cleared.get("front", {}) is Dictionary else {}
	if String(front.get("source", "")) == "strategic_ai_resource_defense" or String(front.get("state", "")) in ["defend", "stabilizing"]:
		cleared.erase("front")
	return cleared

static func _resource_site_claim_rewards(site: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._resource_site_claim_rewards", [site])

static func _resource_site_claim_recruits(site: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._resource_site_claim_recruits", [site])

static func _resource_site_weekly_recruits(site: Dictionary) -> Dictionary:
	var recruits = site.get("weekly_recruits", {})
	if recruits is Dictionary and not recruits.is_empty():
		return recruits
	var roster = site.get("neutral_roster", {})
	if roster is Dictionary:
		var roster_recruits = roster.get("weekly_recruits", {})
		if roster_recruits is Dictionary:
			return roster_recruits
	return {}

static func resource_site_is_recruit_source(site: Dictionary) -> bool:
	return HumanEngine.native(&"OverworldRules.resource_site_is_recruit_source", [site])

static func describe_recruit_source_compact(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	if not resource_site_is_recruit_source(site):
		return ""
	var parts := []
	var claim_line := _recruit_source_roster_line("Ready", _resource_site_claim_recruits(site), 2)
	if claim_line != "":
		parts.append(claim_line)
	var weekly_line := _recruit_source_roster_line("Weekly", _resource_site_weekly_recruits(site), 1, CreatureDwellings.is_dwelling(site))
	if weekly_line != "":
		parts.append(weekly_line)
	var guard_line := _resource_site_guard_or_contest_line(session, node, site)
	if guard_line != "":
		parts.append(guard_line)
	return " | ".join(_non_empty_strings(parts))

static func describe_recruit_source_inspection(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_recruit_source_inspection", [session, node, site])

static func describe_resource_site_surface(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resource_site_surface", [session, node, site])

static func describe_resource_site_control_summary(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var parts := []
	var control_line := _resource_site_control_brief(node, site)
	if control_line != "":
		parts.append(control_line)
	var yield_line := _resource_site_yield_line(session, node, site)
	if yield_line != "":
		parts.append(yield_line)
	var guard_line := _resource_site_guard_or_contest_line(session, node, site)
	if guard_line != "":
		parts.append(guard_line)
	return " | ".join(_non_empty_strings(parts))

static func describe_resource_site_control_inspection(session: SessionStateStoreScript.SessionData, node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules.describe_resource_site_control_inspection", [session, node, site])

static func describe_resource_site_interaction_surface(node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules.describe_resource_site_interaction_surface", [node, site])

static func describe_encounter_object_surface(encounter: Dictionary) -> String:
	var map_object := ContentService.get_map_object(String(encounter.get("object_id", "")))
	var neutral_metadata = encounter.get("neutral_encounter", {})
	var primary_class := String(map_object.get("primary_class", encounter.get("primary_class", ""))).strip_edges()
	if primary_class == "" and neutral_metadata is Dictionary:
		primary_class = String(neutral_metadata.get("primary_class", "")).strip_edges()
	var parts := []
	if primary_class != "":
		parts.append(_humanize_id(primary_class))
	var tag_summary := _encounter_object_tag_summary(encounter, map_object)
	if tag_summary != "":
		parts.append(tag_summary)
	var risk_summary := _encounter_risk_label(encounter)
	if risk_summary != "":
		parts.append(risk_summary)
	var difficulty_summary := _encounter_difficulty_label(encounter)
	if difficulty_summary != "":
		parts.append(difficulty_summary)
	var interaction_mode := _encounter_object_interaction_label(encounter, map_object)
	if interaction_mode != "":
		parts.append(interaction_mode)
	var guard_summary := _encounter_guard_summary(encounter)
	if guard_summary != "":
		parts.append(guard_summary)
	return " | ".join(_non_empty_strings(parts))

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
static func resource_site_blocking_guard(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary,
	positions: Variant = null
) -> Dictionary:
	var encounter := _resource_site_guard_encounter(session, node, site, positions)
	return encounter if _resource_site_guard_blocks_node(encounter, node) else {}

static func _resource_site_guard_link_for_encounter(encounter: Dictionary) -> Dictionary:
	var guard = encounter.get("guard_link", {})
	if guard is Dictionary and not guard.is_empty():
		return guard
	var metadata := _encounter_neutral_metadata(encounter)
	guard = metadata.get("guard_link", {})
	return guard if guard is Dictionary else {}

static func _interaction_cadence_label(cadence: String) -> String:
	return HumanEngine.native(&"OverworldRules._interaction_cadence_label", [cadence])

static func _encounter_object_tag_summary(encounter: Dictionary, map_object: Dictionary) -> String:
	var tags := _string_array(map_object.get("secondary_tags", []))
	var neutral_metadata = encounter.get("neutral_encounter", {})
	if tags.is_empty() and neutral_metadata is Dictionary:
		tags = _string_array(neutral_metadata.get("secondary_tags", []))
	var visible := []
	for tag in tags:
		var label := _humanize_id(tag)
		if label != "" and label not in visible:
			visible.append(label)
		if visible.size() >= 3:
			break
	return "Tags: %s" % ", ".join(visible) if not visible.is_empty() else ""

static func _encounter_object_interaction_label(encounter: Dictionary, map_object: Dictionary) -> String:
	var interaction = map_object.get("interaction", {})
	if interaction is Dictionary:
		var cadence := String(interaction.get("cadence", "")).strip_edges()
		if cadence != "":
			return _interaction_cadence_label(cadence)
	var neutral_metadata = encounter.get("neutral_encounter", {})
	if neutral_metadata is Dictionary:
		var passability = neutral_metadata.get("passability", {})
		if passability is Dictionary:
			var mode := String(passability.get("interaction_mode", "")).strip_edges()
			if mode != "":
				return "Interaction: %s" % _humanize_id(mode)
	return "Interaction: enter battle"

static func _encounter_guard_link(encounter: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._encounter_guard_link", [encounter])

static func _encounter_guard_summary(encounter: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	return HumanEngine.native_writing(&"OverworldRules._encounter_guard_summary", [encounter, session])

static func _encounter_role_label(encounter: Dictionary) -> String:
	var metadata := _encounter_neutral_metadata(encounter)
	var representation = metadata.get("representation", {})
	if representation is Dictionary:
		var mode := String(representation.get("mode", "")).strip_edges()
		if mode != "":
			return _humanize_id(mode)
	var map_object := ContentService.get_map_object(String(encounter.get("object_id", "")))
	var subtype := String(map_object.get("subtype", "")).strip_edges()
	if subtype != "":
		return _humanize_id(subtype)
	var tags := _encounter_tags(encounter, map_object)
	if "route_block" in tags:
		return "Route Block"
	if "guarded_reward" in tags:
		return "Guarded Reward"
	if "visible_army" in tags:
		return "Visible Stack"
	return "Hostile Contact"

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

static func _encounter_field_objective_surface(encounter: Dictionary) -> String:
	var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var labels := []
	for objective in encounter_def.get("field_objectives", []):
		if not (objective is Dictionary):
			continue
		var label := String(objective.get("label", "")).strip_edges()
		if label != "":
			labels.append(label)
		if labels.size() >= 2:
			break
	return ", ".join(labels)

static func _encounter_guard_target_label(session: SessionStateStoreScript.SessionData, guard: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._encounter_guard_target_label", [session, guard])

static func _encounter_neutral_metadata(encounter: Dictionary) -> Dictionary:
	var metadata = encounter.get("neutral_encounter", {})
	if metadata is Dictionary and not metadata.is_empty():
		return metadata
	var map_object := ContentService.get_map_object(String(encounter.get("object_id", "")))
	metadata = map_object.get("neutral_encounter", {})
	return metadata if metadata is Dictionary else {}

static func _encounter_tags(encounter: Dictionary, map_object: Dictionary) -> Array[String]:
	var tags := _string_array(map_object.get("secondary_tags", []))
	var metadata := _encounter_neutral_metadata(encounter)
	if tags.is_empty():
		tags = _string_array(metadata.get("secondary_tags", []))
	return tags

static func _string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in strings:
				strings.append(text)
	return strings

static func _non_empty_strings(value: Array) -> Array[String]:
	return HumanEngine.native(&"OverworldRules._non_empty_strings", [value])

static func _humanize_id(value: String) -> String:
	return HumanEngine.native(&"OverworldRules._humanize_id", [value])

static func _resource_site_response_profile(site: Dictionary) -> Dictionary:
	var profile := {
		"action_label": "",
		"summary": "",
		"movement_cost": 0,
		"resource_cost": {"gold": 0, "wood": 0, "ore": 0},
		"watch_days": 0,
		"quality_bonus": 0,
		"readiness_bonus": 0,
		"pressure_bonus": 0,
		"recovery_relief": 0,
		"pressure_guard_bonus": 0,
		"growth_bonus_percent": 0,
		"break_pressure": 0,
	}
	var authored_profile = site.get("response_profile", {})
	if authored_profile is Dictionary:
		profile["action_label"] = String(authored_profile.get("action_label", ""))
		profile["summary"] = String(authored_profile.get("summary", ""))
		profile["movement_cost"] = max(0, int(authored_profile.get("movement_cost", 0)))
		profile["resource_cost"] = _normalize_resource_dict(authored_profile.get("resource_cost", {}))
		profile["watch_days"] = max(0, int(authored_profile.get("watch_days", 0)))
		profile["quality_bonus"] = max(0, int(authored_profile.get("quality_bonus", 0)))
		profile["readiness_bonus"] = max(0, int(authored_profile.get("readiness_bonus", 0)))
		profile["pressure_bonus"] = max(0, int(authored_profile.get("pressure_bonus", 0)))
		profile["recovery_relief"] = max(0, int(authored_profile.get("recovery_relief", 0)))
		profile["pressure_guard_bonus"] = max(0, int(authored_profile.get("pressure_guard_bonus", 0)))
		profile["growth_bonus_percent"] = max(0, int(authored_profile.get("growth_bonus_percent", 0)))
		profile["break_pressure"] = max(0, int(authored_profile.get("break_pressure", 0)))
	if String(profile.get("action_label", "")) == "":
		match String(site.get("family", "")):
			"mine":
				profile["action_label"] = "Secure Work Road"
			"neutral_dwelling":
				profile["action_label"] = "Dispatch Relief"
			"faction_outpost":
				profile["action_label"] = "Repair Outpost"
			"frontier_shrine":
				profile["action_label"] = "Relight Shrine"
			"scouting_structure":
				profile["action_label"] = "Staff Watch"
			"transit_object":
				profile["action_label"] = "Repair Route"
			_:
				profile["action_label"] = "Secure Route"
	if int(profile.get("pressure_guard_bonus", 0)) <= 0:
		match String(site.get("family", "")):
			"mine":
				profile["pressure_guard_bonus"] = 1
			"neutral_dwelling":
				profile["pressure_guard_bonus"] = 1
			"faction_outpost":
				profile["pressure_guard_bonus"] = 2
			"frontier_shrine":
				profile["pressure_guard_bonus"] = 1
			"scouting_structure":
				profile["pressure_guard_bonus"] = 2
			"transit_object":
				profile["pressure_guard_bonus"] = 1
	if int(profile.get("growth_bonus_percent", 0)) <= 0:
		match String(site.get("family", "")):
			"mine":
				profile["growth_bonus_percent"] = 3
			"neutral_dwelling":
				profile["growth_bonus_percent"] = 14
			"faction_outpost":
				profile["growth_bonus_percent"] = 4
			"frontier_shrine":
				profile["growth_bonus_percent"] = 6
			"scouting_structure":
				profile["growth_bonus_percent"] = 3
			"transit_object":
				profile["growth_bonus_percent"] = 3
	if int(profile.get("break_pressure", 0)) <= 0:
		match String(site.get("family", "")):
			"mine":
				profile["break_pressure"] = 1
			"neutral_dwelling":
				profile["break_pressure"] = 1
			"faction_outpost":
				profile["break_pressure"] = 2
			"frontier_shrine":
				profile["break_pressure"] = 1
			"scouting_structure":
				profile["break_pressure"] = 2
			"transit_object":
				profile["break_pressure"] = 1
	return profile

static func _route_security_rating_for_hero(hero: Dictionary) -> int:
	if hero.is_empty():
		return 1
	var command = hero.get("command", {})
	var command_total := (
		int(command.get("attack", 0))
		+ int(command.get("defense", 0))
		+ int(command.get("power", 0))
		+ int(command.get("knowledge", 0))
	)
	var level_bonus = max(0, int(hero.get("level", 1)) - 1)
	return clamp(1 + int(floor(float(command_total + level_bonus) / 4.0)), 1, 5)

static func _resource_site_response_state(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> Dictionary:
	var profile := _resource_site_response_profile(site)
	var active := false
	var remaining_days := 0
	var commander_id := String(node.get("response_commander_id", ""))
	var commander_name := ""
	var security_rating = max(0, int(node.get("response_security_rating", 0)))
	if session != null and String(node.get("collected_by_faction_id", "")) == "player":
		var response_until_day = max(0, int(node.get("response_until_day", 0)))
		active = response_until_day >= session.day and int(profile.get("watch_days", 0)) > 0
		if active:
			remaining_days = max(1, response_until_day - session.day + 1)
		if commander_id != "":
			commander_name = String(HeroCommandRulesScript.hero_by_id(session, commander_id).get("name", ""))
		if security_rating <= 0:
			var preview_hero := HeroCommandRulesScript.active_hero(session)
			security_rating = _route_security_rating_for_hero(preview_hero)
			if commander_name == "":
				commander_name = String(preview_hero.get("name", ""))
	if active and security_rating <= 0:
		security_rating = 1
	var pressure_guard_bonus = max(0, int(profile.get("pressure_guard_bonus", 0))) + max(0, security_rating - 1)
	var growth_bonus_percent = max(0, int(profile.get("growth_bonus_percent", 0)))
	if growth_bonus_percent > 0:
		growth_bonus_percent += max(0, security_rating - 1) * 3
	var break_pressure = max(0, int(profile.get("break_pressure", 0))) + max(0, security_rating - 1)
	return {
		"active": active,
		"remaining_days": remaining_days,
		"origin": String(node.get("response_origin", "")),
		"source_town_id": String(node.get("response_source_town_id", "")),
		"commander_id": commander_id,
		"commander_name": commander_name,
		"security_rating": security_rating,
		"action_label": String(profile.get("action_label", "")),
		"summary": String(profile.get("summary", "")),
		"movement_cost": int(profile.get("movement_cost", 0)),
		"resource_cost": profile.get("resource_cost", {"gold": 0, "wood": 0, "ore": 0}),
		"watch_days": int(profile.get("watch_days", 0)),
		"quality_bonus": int(profile.get("quality_bonus", 0)),
		"readiness_bonus": int(profile.get("readiness_bonus", 0)),
		"pressure_bonus": int(profile.get("pressure_bonus", 0)),
		"recovery_relief": int(profile.get("recovery_relief", 0)),
		"pressure_guard_bonus": pressure_guard_bonus,
		"growth_bonus_percent": growth_bonus_percent,
		"break_pressure": break_pressure,
	}

static func _resource_site_response_effect_summary(response_state: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_response_effect_summary", [response_state])

static func _resource_site_delivery_target_label(
	session: SessionStateStoreScript.SessionData,
	target_kind: String,
	target_id: String,
	fallback_label: String = ""
) -> String:
	if session != null:
		match target_kind:
			"hero":
				var hero := HeroCommandRulesScript.hero_by_id(session, target_id)
				if not hero.is_empty():
					return String(hero.get("name", target_id))
			"town":
				var town_result := _find_town_by_placement(session, target_id)
				if int(town_result.get("index", -1)) >= 0:
					return _town_name(town_result.get("town", {}))
			"raid":
				var encounter_result = _find_encounter_by_placement(session, target_id)
				if int(encounter_result.get("index", -1)) >= 0:
					var encounter: Dictionary = encounter_result.get("encounter", {})
					return String(encounter.get("target_label", encounter.get("placement_id", target_id)))
	if fallback_label != "":
		return fallback_label
	match target_kind:
		"hero":
			return "frontline hero"
		"town":
			return "frontline town"
		"raid":
			return "enemy army"
		_:
			return "frontline"

static func _resource_site_delivery_state(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	_site: Dictionary = {}
) -> Dictionary:
	var manifest = _normalize_recruit_payload(node.get("delivery_manifest", {}))
	var controller_id = String(node.get("delivery_controller_id", ""))
	var arrival_day = max(0, int(node.get("delivery_arrival_day", 0)))
	var target_kind = String(node.get("delivery_target_kind", ""))
	var target_id = String(node.get("delivery_target_id", ""))
	var target_label = _resource_site_delivery_target_label(
		session,
		target_kind,
		target_id,
		String(node.get("delivery_target_label", ""))
	)
	var source_town_id = String(node.get("delivery_origin_town_id", ""))
	var source_town_label := ""
	if session != null and source_town_id != "":
		var source_town_result = _find_town_by_placement(session, source_town_id)
		if int(source_town_result.get("index", -1)) >= 0:
			source_town_label = _town_name(source_town_result.get("town", {}))
	var active := false
	var days_remaining := 0
	if session != null and controller_id != "" and not manifest.is_empty() and arrival_day > 0:
		active = PlayerRules.resource_controller_id(node) == controller_id
		if active:
			days_remaining = max(0, arrival_day - session.day)
			if days_remaining > 0:
				days_remaining = max(1, days_remaining)
	return {
		"active": active,
		"controller_id": controller_id,
		"origin_town_id": source_town_id,
		"origin_town_label": source_town_label,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"arrival_day": arrival_day,
		"days_remaining": days_remaining,
		"manifest": manifest,
		"recruit_summary": _describe_recruit_delta(manifest),
		"manifest_value": _weighted_recruit_value(manifest),
	}

static func _delivery_encounter_matches_node(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	node: Dictionary,
	delivery_state: Dictionary
) -> bool:
	if session == null or encounter.is_empty() or node.is_empty() or delivery_state.is_empty():
		return false
	var explicit_node_id := String(encounter.get("delivery_intercept_node_placement_id", ""))
	if explicit_node_id != "" and explicit_node_id == String(node.get("placement_id", "")):
		return true
	match String(encounter.get("target_kind", "")):
		"resource":
			return String(encounter.get("target_placement_id", "")) == String(node.get("placement_id", ""))
		"town":
			return (
				String(delivery_state.get("target_kind", "")) == "town"
				and String(encounter.get("target_placement_id", "")) == String(delivery_state.get("target_id", ""))
			)
		"hero":
			if String(delivery_state.get("target_kind", "")) != "hero":
				return false
			var hero_target_id := String(encounter.get("target_placement_id", ""))
			if hero_target_id == "":
				hero_target_id = String(session.overworld.get("active_hero_id", ""))
			return hero_target_id != "" and hero_target_id == String(delivery_state.get("target_id", ""))
		_:
			return false

static func _resource_site_delivery_interception(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary = {}
) -> Dictionary:
	var empty_state := {
		"active": false,
		"arrived": false,
		"blocks_delivery": false,
		"goal_distance": 9999,
		"strength": 0,
		"encounter_key": "",
		"encounter_name": "",
		"summary": "",
	}
	if session == null or node.is_empty():
		return empty_state
	var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
	if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
		return empty_state
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var best := empty_state.duplicate(true)
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == "":
			continue
		if resolved_encounters is Array and encounter_key(encounter) in resolved_encounters:
			continue
		if not _delivery_encounter_matches_node(session, encounter, node, delivery_state):
			continue
		var goal_distance: int = max(0, int(encounter.get("goal_distance", 9999)))
		var arrived: bool = bool(encounter.get("arrived", false)) or goal_distance <= 0
		var strength: int = int(_enemy_adventure_rules().raid_strength(encounter))
		if bool(best.get("active", false)):
			var best_arrived := bool(best.get("arrived", false))
			var best_distance := int(best.get("goal_distance", 9999))
			var best_strength := int(best.get("strength", 0))
			if arrived == best_arrived:
				if goal_distance == best_distance and strength <= best_strength:
					continue
				if goal_distance > best_distance:
					continue
			elif not arrived:
				continue
		best = {
			"active": true,
			"arrived": arrived,
			"blocks_delivery": arrived,
			"goal_distance": goal_distance,
			"strength": strength,
			"encounter_key": encounter_key(encounter),
			"encounter_name": encounter_display_name(encounter),
			"summary": "",
		}
	var encounter_name := String(best.get("encounter_name", "Enemy army"))
	var target_label := String(delivery_state.get("target_label", "the front"))
	if bool(best.get("active", false)):
		if bool(best.get("blocks_delivery", false)):
			best["summary"] = "%s is contesting %s." % [encounter_name, target_label]
		else:
			best["summary"] = "%s closes on %s in %d tile%s." % [
				encounter_name,
				target_label,
				int(best.get("goal_distance", 0)),
				"" if int(best.get("goal_distance", 0)) == 1 else "s",
			]
	return best

static func delivery_interception_context_for_encounter(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary
) -> Dictionary:
	var empty_context := {
		"active": false,
		"node_placement_id": "",
		"site_name": "",
		"origin_town_id": "",
		"origin_town_label": "",
		"target_kind": "",
		"target_id": "",
		"target_label": "",
		"route_label": "",
		"pressure_label": "",
		"arrival_day": 0,
		"recruit_summary": "",
		"manifest": {},
		"manifest_value": 0,
		"interception": {
			"active": false,
			"arrived": false,
			"blocks_delivery": false,
			"goal_distance": 9999,
			"strength": 0,
			"encounter_key": "",
			"encounter_name": "",
			"summary": "",
		},
	}
	if session == null or encounter.is_empty():
		return empty_context
	var explicit_node_id := String(encounter.get("delivery_intercept_node_placement_id", ""))
	var nodes = session.overworld.get("resource_nodes", [])
	var best := empty_context.duplicate(true)
	for node_value in nodes:
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if explicit_node_id != "" and String(node.get("placement_id", "")) != explicit_node_id:
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
		if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
			continue
		if not _delivery_encounter_matches_node(session, encounter, node, delivery_state):
			continue
		var target_label := String(delivery_state.get("target_label", "the front"))
		var site_name := String(site.get("name", "Frontier route"))
		var route_label := "%s convoy to %s" % [site_name, target_label]
		var pressure_label := route_label
		match String(delivery_state.get("target_kind", "")):
			"town":
				pressure_label = "%s relief lane" % target_label
			"hero":
				pressure_label = "%s convoy" % target_label
		var candidate := {
			"active": true,
			"node_placement_id": String(node.get("placement_id", "")),
			"site_name": site_name,
			"origin_town_id": String(delivery_state.get("origin_town_id", "")),
			"origin_town_label": String(delivery_state.get("origin_town_label", "")),
			"target_kind": String(delivery_state.get("target_kind", "")),
			"target_id": String(delivery_state.get("target_id", "")),
			"target_label": target_label,
			"route_label": route_label,
			"pressure_label": pressure_label,
			"arrival_day": int(delivery_state.get("arrival_day", 0)),
			"recruit_summary": String(delivery_state.get("recruit_summary", "")),
			"manifest": _normalize_recruit_payload(delivery_state.get("manifest", {})),
			"manifest_value": int(delivery_state.get("manifest_value", 0)),
			"interception": _resource_site_delivery_interception(session, node, site),
		}
		if not bool(best.get("active", false)):
			best = candidate
			if explicit_node_id != "":
				break
			continue
		if int(candidate.get("manifest_value", 0)) > int(best.get("manifest_value", 0)):
			best = candidate
			continue
		if int(candidate.get("manifest_value", 0)) == int(best.get("manifest_value", 0)) and int(candidate.get("arrival_day", 0)) < int(best.get("arrival_day", 0)):
			best = candidate
	if explicit_node_id != "" and not bool(best.get("active", false)):
		return empty_context
	return best

static func _resource_site_delivery_line(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> String:
	var delivery_state = _resource_site_delivery_state(session, node, site)
	if not bool(delivery_state.get("active", false)):
		return ""
	var parts := [
		"%s convoy" % String(site.get("name", "Frontier route")),
		"to %s" % String(delivery_state.get("target_label", "the front")),
	]
	var recruit_summary = String(delivery_state.get("recruit_summary", ""))
	if recruit_summary != "":
		parts.append(recruit_summary)
	var days_remaining := int(delivery_state.get("days_remaining", 0))
	if days_remaining > 0:
		parts.append("%d day%s out" % [days_remaining, "" if days_remaining == 1 else "s"])
	else:
		var interception_state: Dictionary = _resource_site_delivery_interception(session, node, site)
		if bool(interception_state.get("blocks_delivery", false)):
			parts.append("holding under interception")
	var interception: Dictionary = _resource_site_delivery_interception(session, node, site)
	if bool(interception.get("active", false)):
		if bool(interception.get("blocks_delivery", false)):
			parts.append("%s blocks the route" % String(interception.get("encounter_name", "Enemy army")))
		else:
			parts.append("%s %d tile%s out" % [
				String(interception.get("encounter_name", "Enemy army")),
				int(interception.get("goal_distance", 0)),
				"" if int(interception.get("goal_distance", 0)) == 1 else "s",
			])
	return " | ".join(parts)

static func _player_reserve_delivery_plan(session: SessionStateStoreScript.SessionData, source_town: Dictionary, response_state: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._player_reserve_delivery_plan", [session, source_town, response_state])

static func _consume_recruit_payload(recruits: Variant, manifest: Variant) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._consume_recruit_payload", [recruits, manifest])

static func _clear_resource_site_delivery(node: Dictionary) -> Dictionary:
	var cleared := node.duplicate(true)
	cleared["delivery_controller_id"] = ""
	cleared["delivery_origin_town_id"] = ""
	cleared["delivery_target_kind"] = ""
	cleared["delivery_target_id"] = ""
	cleared["delivery_target_label"] = ""
	cleared["delivery_arrival_day"] = 0
	cleared["delivery_manifest"] = {}
	return cleared

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

static func _resource_site_spell_ids(site: Dictionary) -> Array:
	var result := []
	var legacy_spell_id := String(site.get("learn_spell_id", "")).strip_edges()
	if legacy_spell_id != "":
		result.append(legacy_spell_id)
	var authored_spell_ids = site.get("learn_spell_ids", [])
	if authored_spell_ids is Array:
		for spell_id_value in authored_spell_ids:
			var spell_id := String(spell_id_value).strip_edges()
			if spell_id != "" and spell_id not in result:
				result.append(spell_id)
	return result

static func _resource_site_spell_names(site: Dictionary) -> Array:
	return HumanEngine.native(&"OverworldRules._resource_site_spell_names", [site])

static func _issue_resource_site_response(session: SessionStateStoreScript.SessionData, placement_id: String, origin: String) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._issue_resource_site_response", [session, placement_id, origin])

static func _resource_node_linked_town(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	controller_id: String
) -> Dictionary:
	var town_result := _nearest_town_for_controller(
		session,
		controller_id,
		int(node.get("x", 0)),
		int(node.get("y", 0)),
		OverworldLevelRulesScript.level_of(node)
	)
	if int(town_result.get("index", -1)) < 0:
		return {"index": -1, "town": {}}
	var town = town_result.get("town", {})
	var distance = abs(int(node.get("x", 0)) - int(town.get("x", 0))) + abs(int(node.get("y", 0)) - int(town.get("y", 0)))
	if distance > int(_town_logistics_plan(town).get("support_radius", 0)):
		return {"index": -1, "town": {}}
	return town_result

static func _advance_player_reserve_deliveries(session: SessionStateStoreScript.SessionData) -> Array:
	var messages := []
	if session == null:
		return messages
	var nodes = session.overworld.get("resource_nodes", [])
	var changed := false
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		var delivery_state: Dictionary = _resource_site_delivery_state(session, node)
		if String(delivery_state.get("controller_id", "")) != "player":
			continue
		if _normalize_recruit_payload(delivery_state.get("manifest", {})).is_empty():
			node = _clear_resource_site_delivery(node)
			nodes[index] = node
			changed = true
			continue
		if String(node.get("collected_by_faction_id", "")) != "player":
			node = _clear_resource_site_delivery(node)
			nodes[index] = node
			changed = true
			continue
		if session.day < int(delivery_state.get("arrival_day", 0)):
			continue
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		var interception_state: Dictionary = _resource_site_delivery_interception(session, node, site)
		if bool(interception_state.get("blocks_delivery", false)):
			continue
		var admission := _delivery_army_admission(session, delivery_state)
		if not bool(admission.get("ok", false)):
			# Keep the existing convoy manifest and receipt untouched. The army may
			# fill after dispatch; waiting is not a failed/lost delivery.
			messages.append("%s convoy waits for army space at %s." % [String(site.get("name", "The route")), String(delivery_state.get("target_label", "its destination"))])
			continue
		var message = _resolve_player_reserve_delivery(session, site, delivery_state, node)
		node = _clear_resource_site_delivery(node)
		var followup_result := _queue_followup_reserve_delivery(session, node, site)
		node = followup_result.get("node", node)
		nodes[index] = node
		changed = true
		if message != "":
			messages.append(message)
		var followup_message := String(followup_result.get("message", ""))
		if followup_message != "":
			messages.append(followup_message)
	if changed:
		session.overworld["resource_nodes"] = nodes
	return messages

static func _queue_followup_reserve_delivery(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	site: Dictionary
) -> Dictionary:
	var result := {"node": node, "message": ""}
	if session == null or node.is_empty() or site.is_empty():
		return result
	if String(node.get("collected_by_faction_id", "")) != "player":
		return result
	var response_state := _resource_site_response_state(session, node, site)
	if not bool(response_state.get("active", false)):
		return result
	if bool(_resource_site_delivery_state(session, node, site).get("active", false)):
		return result
	var linked_town_result := _resource_node_linked_town(session, node, "player")
	if int(linked_town_result.get("index", -1)) < 0:
		return result
	var source_town: Dictionary = linked_town_result.get("town", {})
	var delivery_plan := _player_reserve_delivery_plan(session, source_town, response_state)
	if delivery_plan.is_empty():
		return result
	var towns = session.overworld.get("towns", [])
	source_town["available_recruits"] = _consume_recruit_payload(
		source_town.get("available_recruits", {}),
		delivery_plan.get("manifest", {})
	)
	towns[int(linked_town_result.get("index", -1))] = source_town
	session.overworld["towns"] = towns
	var queued := node.duplicate(true)
	queued["delivery_controller_id"] = "player"
	queued["delivery_origin_town_id"] = String(source_town.get("placement_id", ""))
	queued["delivery_target_kind"] = String(delivery_plan.get("target_kind", ""))
	queued["delivery_target_id"] = String(delivery_plan.get("target_id", ""))
	queued["delivery_target_label"] = String(delivery_plan.get("target_label", ""))
	queued["delivery_arrival_day"] = session.day + max(1, int(delivery_plan.get("eta_days", 1)))
	queued["delivery_manifest"] = _normalize_recruit_payload(delivery_plan.get("manifest", {}))
	result["node"] = queued
	result["message"] = "%s loads a follow-up convoy for %s (%s, %d day%s)." % [
		String(site.get("name", "The route")),
		String(delivery_plan.get("target_label", "the front")),
		_describe_recruit_delta(delivery_plan.get("manifest", {})),
		int(delivery_plan.get("eta_days", 1)),
		"" if int(delivery_plan.get("eta_days", 1)) == 1 else "s",
	]
	return result

static func _resolve_player_reserve_delivery(
	session: SessionStateStoreScript.SessionData,
	site: Dictionary,
	delivery_state: Dictionary,
	node: Dictionary = {}
) -> String:
	var manifest = _normalize_recruit_payload(delivery_state.get("manifest", {}))
	if manifest.is_empty():
		return ""
	var site_name = String(site.get("name", "The route"))
	var target_kind = String(delivery_state.get("target_kind", ""))
	var target_id = String(delivery_state.get("target_id", ""))
	var target_label = String(delivery_state.get("target_label", "the front"))
	var recruit_summary = String(delivery_state.get("recruit_summary", ""))
	var delivered := false
	match target_kind:
		"hero":
			delivered = _deliver_reinforcements_to_hero(session, target_id, manifest)
		"town":
			delivered = _deliver_reinforcements_to_town(session, target_id, manifest)
	if delivered:
		_record_successful_reserve_delivery(node, delivery_state, session.day)
		return "%s convoy reaches %s (%s)." % [site_name, target_label, recruit_summary]
	var returned_to = _return_reinforcements_to_source(session, String(delivery_state.get("origin_town_id", "")), manifest)
	if returned_to != "":
		return "%s convoy turns back to %s after %s closes (%s)." % [
			site_name,
			returned_to,
			target_label,
			recruit_summary,
		]
	return "%s convoy for %s is lost on the frontier (%s)." % [site_name, target_label, recruit_summary]

static func _record_successful_reserve_delivery(node: Dictionary, delivery_state: Dictionary, delivery_day: int) -> void:
	if node.is_empty() or delivery_state.is_empty():
		return
	var target_kind := String(delivery_state.get("target_kind", "")).strip_edges()
	var target_id := String(delivery_state.get("target_id", "")).strip_edges()
	if target_kind == "" or target_id == "":
		return
	var receipt_key := "%s:%s" % [target_kind, target_id]
	var completion_counts := _normalize_delivery_completion_counts(node.get("delivery_completion_counts", {}))
	completion_counts[receipt_key] = max(0, int(completion_counts.get(receipt_key, 0))) + 1
	node["delivery_completion_counts"] = completion_counts
	node["last_delivery_target_kind"] = target_kind
	node["last_delivery_target_id"] = target_id
	node["last_delivery_day"] = max(0, delivery_day)
	node["last_delivery_manifest"] = _normalize_recruit_payload(delivery_state.get("manifest", {}))

static func _delivery_army_admission(session: SessionStateStoreScript.SessionData, delivery_state: Dictionary) -> Dictionary:
	var target_id := String(delivery_state.get("target_id", ""))
	var stacks := []
	if String(delivery_state.get("target_kind", "")) == "hero":
		var hero := HeroCommandRulesScript.hero_by_id(session, target_id)
		if hero.is_empty():
			return {"ok": true} # Existing return/loss rules own missing targets.
		stacks = hero.get("army", {}).get("stacks", [])
	elif String(delivery_state.get("target_kind", "")) == "town":
		var town: Dictionary = _find_town_by_placement(session, target_id).get("town", {})
		if town.is_empty() or String(town.get("owner", "neutral")) != "player":
			return {"ok": true}
		stacks = town.get("garrison", [])
	return HeroCommandRulesScript.army_addition_plan(stacks, delivery_state.get("manifest", {}))

static func _deliver_reinforcements_to_hero(
	session: SessionStateStoreScript.SessionData,
	hero_id: String,
	manifest: Dictionary
) -> bool:
	if session == null or hero_id == "":
		return false
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary) or String(hero.get("id", "")) != hero_id:
			continue
		var army: Dictionary = hero.get("army", {}).duplicate(true)
		var admission := HeroCommandRulesScript.army_addition_plan(army.get("stacks", []), manifest)
		if not bool(admission.get("ok", false)):
			return false
		army["stacks"] = admission.get("stacks", [])
		hero["army"] = army
		heroes[index] = hero
		session.overworld["player_heroes"] = heroes
		if String(session.overworld.get("active_hero_id", "")) == hero_id:
			HeroCommandRulesScript._sync_active_hero_mirror(session)
		return true
	return false

static func _deliver_reinforcements_to_town(
	session: SessionStateStoreScript.SessionData,
	town_placement_id: String,
	manifest: Dictionary
) -> bool:
	if session == null or town_placement_id == "":
		return false
	var town_result = _find_town_by_placement(session, town_placement_id)
	if int(town_result.get("index", -1)) < 0:
		return false
	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return false
	var garrison = town.get("garrison", [])
	var admission := HeroCommandRulesScript.army_addition_plan(garrison, manifest)
	if not bool(admission.get("ok", false)):
		return false
	town["garrison"] = admission.get("stacks", [])
	var towns = session.overworld.get("towns", [])
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return true

static func _return_reinforcements_to_source(
	session: SessionStateStoreScript.SessionData,
	source_town_id: String,
	manifest: Dictionary
) -> String:
	if session == null or source_town_id == "":
		return ""
	var town_result = _find_town_by_placement(session, source_town_id)
	if int(town_result.get("index", -1)) < 0:
		return ""
	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return ""
	town["available_recruits"] = _add_recruit_growth(town.get("available_recruits", {}), manifest)
	var towns = session.overworld.get("towns", [])
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return _town_name(town)

static func _army_strength_value(stacks: Variant) -> int:
	var total_strength := 0
	if not (stacks is Array):
		return total_strength
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var count = max(0, int(stack.get("count", 0)))
		if count <= 0:
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		total_strength += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	return total_strength

static func _nearest_town_for_controller(
	session: SessionStateStoreScript.SessionData,
	controller_id: String,
	x: int,
	y: int,
	level: int = -1
) -> Dictionary:
	level = OverworldLevelRulesScript.query_level(session, level)
	var best_index := -1
	var best_distance := 9999
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or not OverworldLevelRulesScript.on_level(town, level) or not _town_matches_controller(town, controller_id):
			continue
		var distance = abs(x - int(town.get("x", 0))) + abs(y - int(town.get("y", 0)))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index < 0:
		return {"index": -1, "town": {}}
	return {"index": best_index, "town": towns[best_index]}

static func _town_matches_controller(town: Dictionary, controller_id: String) -> bool:
	if controller_id == "player":
		return String(town.get("owner", "neutral")) == "player"
	return String(town.get("owner", "neutral")) == "enemy" and _town_faction_id(town) == controller_id

static func _get_town_at(session: SessionStateStoreScript.SessionData, x: int, y: int, level: int = -1) -> Dictionary:
	level = OverworldLevelRulesScript.query_level(session, level)
	for town in session.overworld.get("towns", []):
		if town is Dictionary and OverworldLevelRulesScript.on_level(town, level) and int(town.get("x", -1)) == x and int(town.get("y", -1)) == y:
			return town
	return {}

static func _position_matches(entry: Dictionary, pos: Vector2i) -> bool:
	return int(entry.get("x", -1)) == pos.x and int(entry.get("y", -1)) == pos.y

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

static func _movement_max_from_hero(hero: Dictionary, session: SessionStateStoreScript.SessionData = null) -> int:
	return HeroCommandRulesScript.movement_max_for_hero(hero, session)

static func _calculate_town_income(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> Dictionary:
	var income := _empty_live_resource_stockpile()
	if TownDevelopment.is_current(town):
		income = _add_resource_sets(income, TownDevelopment.income(town))
		if session != null:
			income = _apply_resource_percent_scale(income, 100 - int(_town_occupation_state(session, town).get("income_penalty_percent", 0)))
		return income
	var built_buildings := _normalize_built_buildings_for_town_state(town)
	for building_id_value in built_buildings:
		var building := ContentService.get_building(String(building_id_value))
		income = _add_resource_sets(income, building.get("income", {}))
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	income = _add_resource_sets(
		income,
		_economy_profile_income(ContentService.get_faction(String(town_template.get("faction_id", ""))).get("economy", {}), built_buildings)
	)
	income = _add_resource_sets(income, _economy_profile_income(town_template.get("economy", {}), built_buildings))
	if session != null:
		var occupation := _town_occupation_state(session, town)
		income = _apply_resource_percent_scale(income, 100 - int(occupation.get("income_penalty_percent", 0)))
	return income

static func _growth_tick_town(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var weekly_growth := _effective_player_town_weekly_growth(session, town)
	town["available_recruits"] = _add_recruit_growth(
		town.get("available_recruits", {}),
		weekly_growth
	)
	return weekly_growth

static func _effective_player_town_weekly_growth(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary
) -> Dictionary:
	return HeroProgressionRulesScript.scale_recruit_growth(
		_town_scaling_hero(session, town),
		_town_weekly_growth(town, session)
	)

static func _seed_recruits_for_town(town: Dictionary) -> Dictionary:
	var normalized_town := town.duplicate(true)
	normalized_town["built_buildings"] = _normalize_built_buildings_for_town_state(normalized_town)
	return _seed_scenario_recruits_for_town_state(normalized_town)

static func _town_weekly_growth(
	town: Dictionary,
	session: SessionStateStoreScript.SessionData = null,
	metric_context: Dictionary = {}
) -> Dictionary:
	var growth := _seed_recruits_for_town(town)
	if session == null:
		return growth
	var growth_percent := 0
	var logistics: Dictionary = metric_context.get("logistics", {})
	if logistics.is_empty():
		logistics = _town_logistics_state(session, town)
	growth_percent += int(logistics.get("growth_bonus_percent", 0))
	growth_percent += int(logistics.get("response_growth_bonus_percent", 0))
	growth_percent -= int(logistics.get("gap_growth_penalty_percent", 0))
	var recovery: Dictionary = metric_context.get("recovery", {})
	if recovery.is_empty():
		recovery = _town_recovery_state(session, town, logistics)
	growth_percent -= int(recovery.get("growth_penalty_percent", 0))
	var capital_project: Dictionary = metric_context.get("capital_project", {})
	if capital_project.is_empty():
		capital_project = _town_capital_project_state(town, session, logistics, recovery)
	growth_percent -= int(capital_project.get("growth_penalty_percent", 0))
	var occupation: Dictionary = metric_context.get("occupation", {})
	if occupation.is_empty():
		occupation = _town_occupation_state(session, town)
	growth_percent -= int(occupation.get("growth_penalty_percent", 0))
	return _add_dwelling_town_growth(session, town, _apply_recruit_percent(growth, growth_percent))

static func _town_reinforcement_quality(
	town: Dictionary,
	session: SessionStateStoreScript.SessionData = null,
	metric_context: Dictionary = {}
) -> int:
	var quality := _weighted_recruit_value(_town_weekly_growth(town, session, metric_context))
	quality += _town_role_quality_bonus(_town_strategic_role(town))
	var logistics: Dictionary = metric_context.get("logistics", {})
	if logistics.is_empty():
		logistics = _town_logistics_state(session, town)
	quality += int(logistics.get("quality_bonus", 0))
	quality += int(logistics.get("response_quality_bonus", 0))
	quality -= int(logistics.get("gap_quality_penalty", 0))
	var recovery: Dictionary = metric_context.get("recovery", {})
	if recovery.is_empty():
		recovery = _town_recovery_state(session, town, logistics)
	quality -= int(recovery.get("quality_penalty", 0))
	var capital_project: Dictionary = metric_context.get("capital_project", {})
	if capital_project.is_empty():
		capital_project = _town_capital_project_state(town, session, logistics, recovery)
	quality += int(capital_project.get("quality_bonus", 0))
	quality -= int(capital_project.get("quality_penalty", 0))
	var occupation: Dictionary = metric_context.get("occupation", {})
	if occupation.is_empty():
		occupation = _town_occupation_state(session, town)
	quality -= int(occupation.get("quality_penalty", 0))
	return max(0, quality)

static func _town_battle_readiness(
	town: Dictionary,
	session: SessionStateStoreScript.SessionData = null,
	metric_context: Dictionary = {},
	reinforcement_quality: int = -1
) -> int:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var readiness := int(round(float(_town_garrison_strength(town)) / 12.0))
	var quality := reinforcement_quality if reinforcement_quality >= 0 else _town_reinforcement_quality(town, session, metric_context)
	readiness += int(round(float(quality) / 6.0))
	readiness += _readiness_bonus_from_profile(faction.get("recruitment", {}))
	readiness += _readiness_bonus_from_profile(town_template.get("recruitment", {}))
	readiness += _town_building_bonus_total(town, "readiness_bonus")
	readiness += _town_spell_tier(town) * 6
	readiness += _town_role_readiness_bonus(_town_strategic_role(town))
	var logistics: Dictionary = metric_context.get("logistics", {})
	if logistics.is_empty():
		logistics = _town_logistics_state(session, town)
	readiness += int(logistics.get("readiness_bonus", 0))
	readiness += int(logistics.get("response_readiness_bonus", 0))
	readiness -= int(logistics.get("gap_readiness_penalty", 0))
	var recovery: Dictionary = metric_context.get("recovery", {})
	if recovery.is_empty():
		recovery = _town_recovery_state(session, town, logistics)
	readiness -= int(recovery.get("readiness_penalty", 0))
	var capital_project: Dictionary = metric_context.get("capital_project", {})
	if capital_project.is_empty():
		capital_project = _town_capital_project_state(town, session, logistics, recovery)
	readiness += int(round(float(int(capital_project.get("defense_bonus", 0))) / 8.0))
	readiness -= int(capital_project.get("readiness_penalty", 0))
	var occupation: Dictionary = metric_context.get("occupation", {})
	if occupation.is_empty():
		occupation = _town_occupation_state(session, town)
	readiness -= int(occupation.get("readiness_penalty", 0))
	return max(0, readiness)

static func _town_pressure_output(
	town: Dictionary,
	session: SessionStateStoreScript.SessionData = null,
	metric_context: Dictionary = {},
	reinforcement_quality: int = -1
) -> int:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var pressure := _pressure_bonus_from_profile(faction.get("economy", {}))
	pressure += _pressure_bonus_from_profile(town_template.get("economy", {}))
	pressure += _town_building_bonus_total(town, "pressure_bonus")
	var quality := reinforcement_quality if reinforcement_quality >= 0 else _town_reinforcement_quality(town, session, metric_context)
	pressure += int(floor(float(quality) / 18.0))
	pressure += max(0, _town_spell_tier(town) - 1)
	pressure += _town_role_pressure_bonus(_town_strategic_role(town))
	var logistics: Dictionary = metric_context.get("logistics", {})
	if logistics.is_empty():
		logistics = _town_logistics_state(session, town)
	pressure += int(logistics.get("pressure_bonus", 0))
	pressure += int(logistics.get("response_pressure_bonus", 0))
	pressure -= int(logistics.get("gap_pressure_penalty", 0))
	var recovery: Dictionary = metric_context.get("recovery", {})
	if recovery.is_empty():
		recovery = _town_recovery_state(session, town, logistics)
	pressure -= int(recovery.get("pressure_penalty", 0))
	var capital_project: Dictionary = metric_context.get("capital_project", {})
	if capital_project.is_empty():
		capital_project = _town_capital_project_state(town, session, logistics, recovery)
	pressure += int(capital_project.get("pressure_bonus", 0))
	pressure -= int(capital_project.get("pressure_penalty", 0))
	var occupation: Dictionary = metric_context.get("occupation", {})
	if occupation.is_empty():
		occupation = _town_occupation_state(session, town)
	pressure -= int(occupation.get("pressure_penalty", 0))
	return max(0, pressure)

static func _town_logistics_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	# Internal development/recovery/front reads must share the same calculation
	# as public UI reads. The existing synchronous scope owns its lifetime; rules
	# outside that scope still calculate from live state on every call. The full
	# town key distinguishes projected building previews from the current town.
	var cache_key := _town_read_scope_cache_key(session, "logistics", town)
	if _town_read_scope_cache_has(cache_key):
		return _town_read_scope_cache_get(cache_key)
	var result := _compute_town_logistics_state(session, town)
	_town_read_scope_cache_store(cache_key, result)
	return result

static func _compute_town_logistics_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var empty_state := _empty_town_logistics_state()
	if session == null or town.is_empty():
		return empty_state
	var controller_id := _town_controller_id(town)
	if controller_id == "":
		return empty_state
	var plan := _town_logistics_plan(town)
	var support_radius := int(plan.get("support_radius", 0))
	var family_counts := {}
	var held_site_labels := []
	var disrupted_site_labels := []
	var threatened_site_labels := []
	var response_site_labels := []
	var delivery_site_labels := []
	var held_site_count := 0
	var disrupted_count := 0
	var threatened_count := 0
	var response_count := 0
	var delivery_count := 0
	var quality_bonus := 0
	var readiness_bonus := 0
	var pressure_bonus := 0
	var growth_bonus_percent := 0
	var recovery_relief_bonus := 0
	var response_quality_bonus := 0
	var response_readiness_bonus := 0
	var response_pressure_bonus := 0
	var response_recovery_relief_bonus := 0
	var response_growth_bonus_percent := 0
	var response_pressure_guard_bonus := 0
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site):
			continue
		var family := String(site.get("family", ""))
		if family == "":
			continue
		var town_result := _resource_node_linked_town(session, node, controller_id)
		if int(town_result.get("index", -1)) < 0:
			continue
		var assigned_town = town_result.get("town", {})
		if String(assigned_town.get("placement_id", "")) != String(town.get("placement_id", "")):
			continue
		var threatened := _resource_site_under_threat(session, node, controller_id)
		var site_name := String(site.get("name", "Frontier site"))
		var controller := PlayerRules.resource_controller_id(node)
		if controller == controller_id:
			held_site_count += 1
			family_counts[family] = int(family_counts.get(family, 0)) + 1
			held_site_labels.append(site_name)
			var support := _resource_site_town_support(site)
			quality_bonus += int(support.get("quality_bonus", 0))
			readiness_bonus += int(support.get("readiness_bonus", 0))
			pressure_bonus += int(support.get("pressure_bonus", 0))
			growth_bonus_percent += int(support.get("growth_bonus_percent", 0))
			recovery_relief_bonus += int(support.get("recovery_relief", 0))
			var response_state := _resource_site_response_state(session, node, site)
			if bool(response_state.get("active", false)):
				response_count += 1
				response_site_labels.append("%s escort (%dd)" % [site_name, int(response_state.get("remaining_days", 0))])
				response_quality_bonus += int(response_state.get("quality_bonus", 0))
				response_readiness_bonus += int(response_state.get("readiness_bonus", 0))
				response_pressure_bonus += int(response_state.get("pressure_bonus", 0))
				response_recovery_relief_bonus += int(response_state.get("recovery_relief", 0))
				response_growth_bonus_percent += int(response_state.get("growth_bonus_percent", 0))
				response_pressure_guard_bonus += int(response_state.get("pressure_guard_bonus", 0))
				var delivery_state: Dictionary = _resource_site_delivery_state(session, node, site)
				if bool(delivery_state.get("active", false)):
					delivery_count += 1
					delivery_site_labels.append(_resource_site_delivery_line(session, node, site))
			if threatened:
				threatened_count += 1
				threatened_site_labels.append(site_name)
		else:
			disrupted_count += 1
			disrupted_site_labels.append(site_name)
			if threatened:
				threatened_count += 1
				threatened_site_labels.append(site_name)
	var requirement_progress := _support_requirement_progress(family_counts, plan.get("support_requirements", {}))
	var missing_family_labels = requirement_progress.get("missing_family_labels", [])
	var gap_penalties := _town_logistics_gap_penalties(town, int(requirement_progress.get("support_gap", 0)))
	var summary_parts := []
	var grade := "stable"
	if held_site_count <= 0 and int(requirement_progress.get("required_total", 0)) > 0:
		grade = "broken"
	elif disrupted_count > 0 or threatened_count > 0 or int(requirement_progress.get("support_gap", 0)) > 0:
		grade = "strained"
	summary_parts.append("%s chain" % grade.capitalize())
	if int(requirement_progress.get("required_total", 0)) > 0:
		summary_parts.append("%d/%d anchors" % [
			int(requirement_progress.get("met_requirements", 0)),
			int(requirement_progress.get("required_total", 0)),
		])
	elif held_site_count > 0:
		summary_parts.append("%d linked" % held_site_count)
	if disrupted_count > 0:
		summary_parts.append("%d denied" % disrupted_count)
	if threatened_count > 0:
		summary_parts.append("%d threatened" % threatened_count)
	if response_count > 0:
		summary_parts.append("%d escorted" % response_count)
	if delivery_count > 0:
		summary_parts.append("%d convoy%s" % [delivery_count, "" if delivery_count == 1 else "s"])
	if missing_family_labels is Array and not missing_family_labels.is_empty():
		summary_parts.append("Missing %s" % ", ".join(missing_family_labels))
	var impact_parts := []
	if quality_bonus > 0:
		impact_parts.append("quality +%d" % quality_bonus)
	if readiness_bonus > 0:
		impact_parts.append("readiness +%d" % readiness_bonus)
	if pressure_bonus > 0:
		impact_parts.append("%s +%d" % [_town_pressure_label(town), pressure_bonus])
	if growth_bonus_percent > 0:
		impact_parts.append("recruits +%d%%" % growth_bonus_percent)
	if recovery_relief_bonus > 0:
		impact_parts.append("recovery +%d/day" % recovery_relief_bonus)
	if response_quality_bonus > 0:
		impact_parts.append("response +%d quality" % response_quality_bonus)
	if response_readiness_bonus > 0:
		impact_parts.append("response +%d readiness" % response_readiness_bonus)
	if response_pressure_bonus > 0:
		impact_parts.append("response +%d %s" % [response_pressure_bonus, _town_pressure_label(town).to_lower()])
	if response_recovery_relief_bonus > 0:
		impact_parts.append("response +%d/day recovery" % response_recovery_relief_bonus)
	if response_growth_bonus_percent > 0:
		impact_parts.append("response +%d%% recruits" % response_growth_bonus_percent)
	if response_pressure_guard_bonus > 0:
		impact_parts.append("escort +%d pressure guard" % response_pressure_guard_bonus)
	if int(gap_penalties.get("quality_penalty", 0)) > 0:
		impact_parts.append("gap -%d quality" % int(gap_penalties.get("quality_penalty", 0)))
	if int(gap_penalties.get("readiness_penalty", 0)) > 0:
		impact_parts.append("gap -%d readiness" % int(gap_penalties.get("readiness_penalty", 0)))
	if int(gap_penalties.get("pressure_penalty", 0)) > 0:
		impact_parts.append("gap -%d %s" % [int(gap_penalties.get("pressure_penalty", 0)), _town_pressure_label(town).to_lower()])
	if int(gap_penalties.get("growth_penalty_percent", 0)) > 0:
		impact_parts.append("gap -%d%% recruits" % int(gap_penalties.get("growth_penalty_percent", 0)))
	return {
		"plan": plan,
		"summary": " | ".join(summary_parts),
		"impact_summary": ", ".join(impact_parts),
		"grade": grade,
		"support_radius": support_radius,
		"held_site_count": held_site_count,
		"disrupted_count": disrupted_count,
		"threatened_count": threatened_count,
		"response_count": response_count,
		"delivery_count": delivery_count,
		"held_site_labels": held_site_labels,
		"disrupted_site_labels": disrupted_site_labels,
		"threatened_site_labels": threatened_site_labels,
		"response_site_labels": response_site_labels,
		"delivery_site_labels": delivery_site_labels,
		"family_counts": family_counts,
		"met_requirements": int(requirement_progress.get("met_requirements", 0)),
		"required_total": int(requirement_progress.get("required_total", 0)),
		"support_gap": int(requirement_progress.get("support_gap", 0)),
		"missing_family_labels": missing_family_labels,
		"quality_bonus": quality_bonus,
		"readiness_bonus": readiness_bonus,
		"pressure_bonus": pressure_bonus,
		"growth_bonus_percent": growth_bonus_percent,
		"recovery_relief_bonus": recovery_relief_bonus,
		"response_quality_bonus": response_quality_bonus,
		"response_readiness_bonus": response_readiness_bonus,
		"response_pressure_bonus": response_pressure_bonus,
		"response_recovery_relief_bonus": response_recovery_relief_bonus,
		"response_growth_bonus_percent": response_growth_bonus_percent,
		"response_pressure_guard_bonus": response_pressure_guard_bonus,
		"gap_quality_penalty": int(gap_penalties.get("quality_penalty", 0)),
		"gap_readiness_penalty": int(gap_penalties.get("readiness_penalty", 0)),
		"gap_pressure_penalty": int(gap_penalties.get("pressure_penalty", 0)),
		"gap_growth_penalty_percent": int(gap_penalties.get("growth_penalty_percent", 0)),
	}

static func _town_recovery_state(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	logistics_state: Dictionary = {}
) -> Dictionary:
	var recovery := _normalize_town_recovery_state(town.get("recovery", {}))
	var pressure = max(0, int(recovery.get("pressure", 0)))
	var relief_rating := _town_recovery_relief_rating(session, town, logistics_state)
	var relief_per_day = max(1, 1 + int(floor(float(relief_rating) / 3.0)))
	var readiness_penalty = pressure * 6
	var quality_penalty = pressure * 4
	var pressure_penalty := int(ceil(float(pressure) / 2.0))
	var growth_penalty_percent = clamp(pressure * 12, 0, 60)
	var days_to_clear := 0 if pressure <= 0 else int(ceil(float(pressure) / float(relief_per_day)))
	var summary := "steady"
	if pressure > 0:
		summary = "%d pressure | -%d readiness | -%d%% recruits | %d/day relief" % [
			pressure,
			readiness_penalty,
			growth_penalty_percent,
			relief_per_day,
		]
	return {
		"active": pressure > 0,
		"pressure": pressure,
		"last_event_day": int(recovery.get("last_event_day", 0)),
		"source": String(recovery.get("source", "")),
		"relief_rating": relief_rating,
		"relief_per_day": relief_per_day,
		"readiness_penalty": readiness_penalty,
		"quality_penalty": quality_penalty,
		"pressure_penalty": pressure_penalty,
		"growth_penalty_percent": growth_penalty_percent,
		"days_to_clear": days_to_clear,
		"summary": summary,
	}

static func _town_strategic_role(town: Dictionary) -> String:
	var role := String(ContentService.get_town(String(town.get("town_id", ""))).get("strategic_role", ""))
	return role if role in ["capital", "stronghold"] else "frontier"

static func _town_strategic_summary(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var summary := String(template.get("strategic_summary", ""))
	if summary != "":
		return summary
	return String(template.get("identity_summary", ""))

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

static func _town_identity_surface(town: Dictionary, session: SessionStateStoreScript.SessionData = null) -> String:
	if town.is_empty():
		return ""
	var template := ContentService.get_town(String(town.get("town_id", "")))
	var faction_id := String(template.get("faction_id", ""))
	var faction := ContentService.get_faction(faction_id)
	var pillars = faction.get("design_pillars", {})
	var role := _town_strategic_role(town)
	var lines := [
		"Identity: %s | %s | %s" % [
			_town_name(town),
			String(faction.get("name", faction_id if faction_id != "" else "Faction")),
			_town_role_label(role),
		]
	]
	var identity := String(template.get("identity_summary", "")).strip_edges()
	if identity == "":
		identity = String(faction.get("identity_summary", "")).strip_edges()
	if identity != "":
		lines.append("Town: %s" % identity)
	var economy_line := _town_economy_identity_line(town, template, faction, session)
	if economy_line != "":
		lines.append(economy_line)
	var magic_line := _town_magic_identity_line(town, template)
	if magic_line != "":
		lines.append(magic_line)
	var strategic_summary := _town_strategic_summary(town).strip_edges()
	if strategic_summary != "":
		lines.append("Role: %s" % strategic_summary)
	if pillars is Dictionary:
		var map_pressure := String(pillars.get("map_pressure", "")).strip_edges()
		if map_pressure != "":
			lines.append("Pressure identity: %s" % map_pressure)
		var battle_style := String(pillars.get("battle_style", "")).strip_edges()
		if battle_style != "":
			lines.append("Strategic cue: %s" % battle_style)
	return "\n".join(lines)

static func _town_economy_identity_line(
	town: Dictionary,
	template: Dictionary,
	faction: Dictionary,
	session: SessionStateStoreScript.SessionData = null
) -> String:
	var parts := []
	var income := _describe_resource_delta(_calculate_town_income(town, session))
	if income != "":
		parts.append("daily %s" % income)
	var pillars = faction.get("design_pillars", {})
	if pillars is Dictionary:
		var economy_style := String(pillars.get("economy_style", "")).strip_edges()
		if economy_style != "":
			parts.append(economy_style)
	var pressure_output := _town_pressure_output(town, session)
	if pressure_output > 0:
		parts.append("%s %d" % [_town_pressure_label(town).to_lower(), pressure_output])
	if parts.is_empty():
		return ""
	return "Economy: %s" % " | ".join(parts)

static func _town_magic_identity_line(town: Dictionary, template: Dictionary) -> String:
	var spell_names := []
	var max_library_tier := 0
	for tier_value in template.get("spell_library", []):
		if not (tier_value is Dictionary):
			continue
		max_library_tier = max(max_library_tier, int(tier_value.get("tier", 0)))
		for spell_id_value in tier_value.get("spell_ids", []):
			if spell_names.size() >= 3:
				break
			var spell_id := String(spell_id_value)
			var spell := ContentService.get_spell(spell_id)
			var spell_name := String(spell.get("name", spell_id))
			if spell_name != "" and spell_name not in spell_names:
				spell_names.append(spell_name)
	if max_library_tier <= 0 and spell_names.is_empty():
		return ""
	var parts := ["tier %d library" % max(max_library_tier, _town_spell_tier(town))]
	if not spell_names.is_empty():
		parts.append("flavor %s" % ", ".join(spell_names))
	return "Magic: %s" % " | ".join(parts)

static func _town_role_label(role: String) -> String:
	match role:
		"capital":
			return "Capital Anchor"
		"stronghold":
			return "Frontier Stronghold"
		_:
			return "Frontier Town"

static func _town_capital_project_state(
	town: Dictionary,
	session: SessionStateStoreScript.SessionData = null,
	logistics_state: Dictionary = {},
	recovery_state: Dictionary = {}
) -> Dictionary:
	var project_ids := _town_capital_project_ids(town)
	var built_buildings := _normalize_built_buildings_for_town_state(town)
	var active_ids := []
	var pressure_bonus := 0
	var defense_bonus := 0
	var threshold_reduction := 0
	var max_active_raids_bonus := 0
	var recovery_guard := 0
	var summary := ""
	var support_requirements := {}
	var vulnerability_penalties := _blank_project_vulnerability_penalties()
	var vulnerability_summary := String(_town_logistics_plan(town).get("vulnerability_summary", ""))
	for project_id in project_ids:
		var project_building := ContentService.get_building(project_id)
		var capital_project = project_building.get("capital_project", {})
		if capital_project is Dictionary and support_requirements.is_empty():
			support_requirements = _normalize_support_requirements(capital_project.get("support_requirements", {}))
			var authored_penalties = capital_project.get("vulnerability_penalties", {})
			if authored_penalties is Dictionary:
				for key in vulnerability_penalties.keys():
					vulnerability_penalties[key] = max(0, int(authored_penalties.get(key, vulnerability_penalties[key])))
		if project_id not in built_buildings:
			continue
		active_ids.append(project_id)
		if capital_project is Dictionary:
			pressure_bonus += max(0, int(capital_project.get("pressure_bonus", 0)))
			defense_bonus += max(0, int(capital_project.get("defense_bonus", 0)))
			threshold_reduction += max(0, int(capital_project.get("raid_threshold_reduction", 0)))
			max_active_raids_bonus += max(0, int(capital_project.get("max_active_raids_bonus", 0)))
			recovery_guard += max(0, int(capital_project.get("recovery_guard", 0)))
			if summary == "":
				summary = String(capital_project.get("summary", ""))
	var primary_project_id := String(project_ids[0]) if not project_ids.is_empty() else ""
	var dependency_ids := _project_dependency_ids(primary_project_id)
	var dependency_complete := 0
	var missing_dependency_labels := []
	for dependency_id in dependency_ids:
		if dependency_id in built_buildings:
			dependency_complete += 1
			continue
		var dependency := ContentService.get_building(dependency_id)
		missing_dependency_labels.append(String(dependency.get("name", dependency_id)))
	var progress_total := dependency_ids.size() + (0 if primary_project_id == "" else 1)
	var progress_complete := dependency_complete + (1 if primary_project_id in built_buildings else 0)
	var next_label := ""
	if primary_project_id != "" and primary_project_id not in built_buildings and missing_dependency_labels.is_empty():
		next_label = String(ContentService.get_building(primary_project_id).get("name", primary_project_id))
	elif not missing_dependency_labels.is_empty():
		next_label = String(missing_dependency_labels[0])
	var support_met := 0
	var support_total := 0
	var support_gap := 0
	var missing_support_labels := []
	var vulnerable := false
	var quality_penalty := 0
	var readiness_penalty := 0
	var pressure_penalty := 0
	var growth_penalty_percent := 0
	if session != null:
		if support_requirements.is_empty():
			support_requirements = _normalize_support_requirements(_town_logistics_plan(town).get("support_requirements", {}))
		var logistics := logistics_state if not logistics_state.is_empty() else _town_logistics_state(session, town)
		var recovery := recovery_state if not recovery_state.is_empty() else _town_recovery_state(session, town, logistics)
		var requirement_progress := _support_requirement_progress(
			logistics.get("family_counts", {}),
			support_requirements
		)
		support_met = int(requirement_progress.get("met_requirements", 0))
		support_total = int(requirement_progress.get("required_total", 0))
		support_gap = int(requirement_progress.get("support_gap", 0))
		missing_support_labels = requirement_progress.get("missing_family_labels", [])
		vulnerable = not active_ids.is_empty() and (support_gap > 0 or bool(recovery.get("active", false)))
		if vulnerable:
			var vulnerability_steps = max(1, support_gap + (1 if bool(recovery.get("active", false)) else 0))
			quality_penalty = int(vulnerability_penalties.get("quality_penalty", 0)) * vulnerability_steps
			readiness_penalty = int(vulnerability_penalties.get("readiness_penalty", 0)) * vulnerability_steps
			pressure_penalty = int(vulnerability_penalties.get("pressure_penalty", 0)) * vulnerability_steps
			growth_penalty_percent = int(vulnerability_penalties.get("growth_penalty_percent", 0)) * vulnerability_steps
	return {
		"total": project_ids.size(),
		"active": not active_ids.is_empty(),
		"active_ids": active_ids,
		"pressure_bonus": pressure_bonus,
		"defense_bonus": defense_bonus,
		"quality_bonus": active_ids.size() * 12,
		"recovery_guard": recovery_guard,
		"raid_threshold_reduction": threshold_reduction,
		"max_active_raids_bonus": max_active_raids_bonus,
		"summary": summary,
		"primary_project_id": primary_project_id,
		"progress_complete": progress_complete,
		"progress_total": progress_total,
		"missing_dependency_labels": missing_dependency_labels,
		"next_label": next_label,
		"support_requirements": support_requirements,
		"support_met": support_met,
		"support_total": support_total,
		"support_gap": support_gap,
		"missing_support_labels": missing_support_labels,
		"vulnerable": vulnerable,
		"quality_penalty": quality_penalty,
		"readiness_penalty": readiness_penalty,
		"pressure_penalty": pressure_penalty,
		"growth_penalty_percent": growth_penalty_percent,
		"vulnerability_summary": vulnerability_summary,
	}

static func _town_controller_id(town: Dictionary) -> String:
	if String(town.get("owner", "neutral")) == "player":
		return "player"
	if String(town.get("owner", "neutral")) == "enemy":
		return PlayerRules.town_controller_id(town)
	return ""

static func _town_logistics_plan(town: Dictionary) -> Dictionary:
	var plan = ContentService.get_town(String(town.get("town_id", ""))).get("logistics_plan", {})
	var role := _town_strategic_role(town)
	return {
		"support_radius": max(0, int(plan.get("support_radius", _default_logistics_support_radius(role)))),
		"support_requirements": _normalize_support_requirements(
			plan.get("support_requirements", _default_logistics_requirements_for_role(role))
		),
		"recovery_relief": max(0, int(plan.get("recovery_relief", 0))),
		"vulnerability_summary": String(plan.get("vulnerability_summary", "")),
	}

static func _default_logistics_support_radius(role: String) -> int:
	match role:
		"capital":
			return 7
		"stronghold":
			return 6
		_:
			return 5

static func _default_logistics_requirements_for_role(role: String) -> Dictionary:
	match role:
		"capital":
			return {"faction_outpost": 1, "frontier_shrine": 1}
		"stronghold":
			return {"faction_outpost": 1, "frontier_shrine": 1}
		_:
			return {"faction_outpost": 1}

static func _normalize_support_requirements(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for family_id_value in value.keys():
			var family_id := String(family_id_value)
			if family_id not in LOGISTICS_SITE_FAMILIES:
				continue
			normalized[family_id] = max(0, int(value.get(family_id, 0)))
	return normalized

static func _support_requirement_progress(family_counts: Variant, requirements: Variant) -> Dictionary:
	var met_requirements := 0
	var required_total := 0
	var missing_family_labels := []
	if not (requirements is Dictionary):
		return {
			"met_requirements": met_requirements,
			"required_total": required_total,
			"support_gap": 0,
			"missing_family_labels": missing_family_labels,
		}
	for family_id_value in requirements.keys():
		var family_id := String(family_id_value)
		var required_count = max(0, int(requirements.get(family_id, 0)))
		if required_count <= 0:
			continue
		required_total += required_count
		var held_count := int(family_counts.get(family_id, 0)) if family_counts is Dictionary else 0
		met_requirements += min(required_count, held_count)
		if held_count < required_count:
			missing_family_labels.append(_resource_site_family_short_label(family_id))
	return {
		"met_requirements": met_requirements,
		"required_total": required_total,
		"support_gap": max(0, required_total - met_requirements),
		"missing_family_labels": missing_family_labels,
	}

static func _empty_town_logistics_state() -> Dictionary:
	return {
		"plan": {"support_radius": 0, "support_requirements": {}, "recovery_relief": 0, "vulnerability_summary": ""},
		"summary": "",
		"impact_summary": "",
		"grade": "stable",
		"support_radius": 0,
		"held_site_count": 0,
		"disrupted_count": 0,
		"threatened_count": 0,
		"response_count": 0,
		"delivery_count": 0,
		"held_site_labels": [],
		"disrupted_site_labels": [],
		"threatened_site_labels": [],
		"response_site_labels": [],
		"delivery_site_labels": [],
		"family_counts": {},
		"met_requirements": 0,
		"required_total": 0,
		"support_gap": 0,
		"missing_family_labels": [],
		"quality_bonus": 0,
		"readiness_bonus": 0,
		"pressure_bonus": 0,
		"growth_bonus_percent": 0,
		"recovery_relief_bonus": 0,
		"response_quality_bonus": 0,
		"response_readiness_bonus": 0,
		"response_pressure_bonus": 0,
		"response_recovery_relief_bonus": 0,
		"response_growth_bonus_percent": 0,
		"response_pressure_guard_bonus": 0,
		"gap_quality_penalty": 0,
		"gap_readiness_penalty": 0,
		"gap_pressure_penalty": 0,
		"gap_growth_penalty_percent": 0,
	}

static func _town_logistics_gap_penalties(town: Dictionary, support_gap: int) -> Dictionary:
	var penalties := {
		"quality_penalty": 0,
		"readiness_penalty": 0,
		"pressure_penalty": 0,
		"growth_penalty_percent": 0,
	}
	if support_gap <= 0:
		return penalties
	match _town_strategic_role(town):
		"capital":
			penalties["quality_penalty"] = support_gap * 4
			penalties["readiness_penalty"] = support_gap * 5
			penalties["pressure_penalty"] = support_gap
			penalties["growth_penalty_percent"] = support_gap * 8
		"stronghold":
			penalties["quality_penalty"] = support_gap * 3
			penalties["readiness_penalty"] = support_gap * 4
			penalties["pressure_penalty"] = support_gap
			penalties["growth_penalty_percent"] = support_gap * 6
	return penalties

static func _normalize_town_recovery_state(value: Variant) -> Dictionary:
	return {
		"pressure": max(0, int(value.get("pressure", 0))) if value is Dictionary else 0,
		"last_event_day": max(0, int(value.get("last_event_day", 0))) if value is Dictionary else 0,
		"source": String(value.get("source", "")) if value is Dictionary else "",
	}

static func _normalize_town_occupation_state(value: Variant) -> Dictionary:
	var normalized := {
		"state": String(value.get("state", "")) if value is Dictionary else "",
		"faction_id": String(value.get("faction_id", "")) if value is Dictionary else "",
		"pressure": max(0, int(value.get("pressure", 0))) if value is Dictionary else 0,
		"initial_pressure": max(0, int(value.get("initial_pressure", 0))) if value is Dictionary else 0,
		"start_day": max(0, int(value.get("start_day", 0))) if value is Dictionary else 0,
		"last_event_day": max(0, int(value.get("last_event_day", 0))) if value is Dictionary else 0,
		"last_owner": String(value.get("last_owner", "")) if value is Dictionary else "",
		"source": String(value.get("source", "")) if value is Dictionary else "",
		"locked_recruits": _normalize_recruit_payload(value.get("locked_recruits", {})) if value is Dictionary else {},
	}

	if value is Dictionary and String(value.get("player_id", "")) != "":
		normalized["player_id"] = String(value.player_id)
	return normalized

static func _normalize_town_front_state(value: Variant) -> Dictionary:
	var normalized := {
		"state": String(value.get("state", "")) if value is Dictionary else "",
		"faction_id": String(value.get("faction_id", "")) if value is Dictionary else "",
		"last_change_day": max(0, int(value.get("last_change_day", 0))) if value is Dictionary else 0,
		"stabilize_until_day": max(0, int(value.get("stabilize_until_day", 0))) if value is Dictionary else 0,
		"defense_until_day": max(0, int(value.get("defense_until_day", 0))) if value is Dictionary else 0,
		"last_defended_day": max(0, int(value.get("last_defended_day", 0))) if value is Dictionary else 0,
		"last_owner": String(value.get("last_owner", "")) if value is Dictionary else "",
		"capture_count": max(0, int(value.get("capture_count", 0))) if value is Dictionary else 0,
		"source": String(value.get("source", "")) if value is Dictionary else "",
	}

	if value is Dictionary and String(value.get("player_id", "")) != "":
		normalized["player_id"] = String(value.player_id)
	return normalized

static func _town_occupation_state(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var occupation := _normalize_town_occupation_state(town.get("occupation", {}))
	var faction_id := PlayerRules.controller_id(occupation)
	var pressure: int = max(0, int(occupation.get("pressure", 0)))
	var result := {
		"active": false,
		"mode": "",
		"faction_id": faction_id,
		"enemy_label": String(ContentService.get_faction(PlayerRules.faction_id(session, faction_id)).get("name", faction_id)) if faction_id != "" else "",
		"pressure": pressure,
		"initial_pressure": max(pressure, int(occupation.get("initial_pressure", 0))),
		"days_active": 0,
		"relief_per_day": 0,
		"days_to_clear": 0,
		"income_penalty_percent": 0,
		"growth_penalty_percent": 0,
		"quality_penalty": 0,
		"readiness_penalty": 0,
		"pressure_penalty": 0,
		"locked_recruits": _normalize_recruit_payload(occupation.get("locked_recruits", {})),
		"locked_headcount": 0,
		"summary": "",
		"compact_summary": "",
		"public_clause": "",
		"target_bonus": 0,
		"state": occupation,
	}
	result.merge(PlayerRules.identity_fields(session, faction_id), true)
	result["locked_headcount"] = _recruit_payload_total(result.get("locked_recruits", {}))
	if session == null:
		return result
	if String(town.get("owner", "neutral")) != "player":
		return result
	if String(occupation.get("state", "")) != "pacifying" or faction_id == "" or pressure <= 0:
		return result
	var logistics := _town_logistics_state(session, town)
	var recovery := _town_recovery_state(session, town)
	var front := _town_occupation_front_proxy(session, town, faction_id)
	var front_active := bool(front.get("active", false)) and PlayerRules.controller_id(front) == faction_id
	var relief_per_day := _town_occupation_relief_per_day(session, town, logistics, recovery, front)
	var days_to_clear := int(ceil(float(pressure) / float(max(1, relief_per_day))))
	var income_penalty := clampi(
		18 + (pressure * 8) + (int(logistics.get("support_gap", 0)) * 6) + (10 if front_active else 0),
		20,
		75
	)
	var growth_penalty := clampi(
		12 + (pressure * 9) + (int(logistics.get("support_gap", 0)) * 5) + (int(recovery.get("pressure", 0)) * 6),
		15,
		80
	)
	var quality_penalty: int = (pressure * 3) + (int(logistics.get("support_gap", 0)) * 2) + (6 if front_active else 0)
	var readiness_penalty: int = (pressure * 4) + (int(logistics.get("support_gap", 0)) * 3) + (8 if front_active else 0)
	var pressure_penalty: int = max(1, int(ceil(float(quality_penalty) / 5.0)))
	var locked_headcount := int(result.get("locked_headcount", 0))
	var reserve_clause := (
		"%d held levy%s" % [locked_headcount, "" if locked_headcount == 1 else "ies"]
		if locked_headcount > 0
		else "musters still sorting under occupation orders"
	)
	result["active"] = true
	result["mode"] = "pacifying"
	result["days_active"] = max(0, session.day - int(occupation.get("start_day", session.day)))
	result["relief_per_day"] = relief_per_day
	result["days_to_clear"] = days_to_clear
	result["income_penalty_percent"] = income_penalty
	result["growth_penalty_percent"] = growth_penalty
	result["quality_penalty"] = quality_penalty
	result["readiness_penalty"] = readiness_penalty
	result["pressure_penalty"] = pressure_penalty
	result["summary"] = "%s remains under pacification for %d day%s | income -%d%% | %s." % [
		_town_name(town),
		days_to_clear,
		"" if days_to_clear == 1 else "s",
		income_penalty,
		reserve_clause,
	]
	result["compact_summary"] = "%s pacifies in %d day%s" % [
		_town_name(town),
		days_to_clear,
		"" if days_to_clear == 1 else "s",
	]
	result["public_clause"] = "occupation still thins the local musters and tax roads"
	result["target_bonus"] = (pressure * 12) + (locked_headcount * 2) + (int(logistics.get("support_gap", 0)) * 10) + (18 if front_active else 0)
	return result

static func _town_occupation_front_proxy(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	faction_id: String
) -> Dictionary:
	var front := _normalize_town_front_state(town.get("front", {}))
	front = _retake_front_from_legacy_state(session, town, front)
	var front_faction_id := _normalized_enemy_front_faction_id(session, front, town)
	var active := (
		String(town.get("owner", "neutral")) == "player"
		and String(front.get("state", "")) == "retake"
		and front_faction_id != ""
		and front_faction_id == faction_id
	)
	return {
		"active": active,
		"mode": "retake" if active else "",
		"faction_id": front_faction_id,
	}.merged(PlayerRules.identity_fields(session, front_faction_id), true)

static func _town_front_state(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	precomputed_development_metrics: Dictionary = {}
) -> Dictionary:
	var front := _normalize_town_front_state(town.get("front", {}))
	front = _retake_front_from_legacy_state(session, town, front)
	var faction_id := _normalized_enemy_front_faction_id(session, front, town)
	var state_id := String(front.get("state", ""))
	var owner := String(town.get("owner", "neutral"))
	var objective_anchor := _town_is_objective_anchor(session, String(town.get("placement_id", "")))
	var role := _town_strategic_role(town)
	var enemy_label := String(ContentService.get_faction(PlayerRules.faction_id(session, faction_id)).get("name", faction_id)) if faction_id != "" else ""
	var base_priority := _town_front_priority_seed(role, objective_anchor)
	var result := {
		"active": false,
		"mode": "",
		"faction_id": faction_id,
		"enemy_label": enemy_label,
		"priority_bonus": 0,
		"pressure_bonus": 0,
		"threshold_reduction": 0,
		"garrison_bonus": 0,
		"build_bonus": 0,
		"days_since_change": max(0, session.day - int(front.get("last_change_day", 0))) if session != null else 0,
		"days_remaining": 0,
		"summary": "",
		"compact_summary": "",
		"public_clause": "",
		"state": front,
	}
	result.merge(PlayerRules.identity_fields(session, faction_id), true)
	if faction_id == "":
		return result
	if state_id not in ["retake", "stabilizing", "defend"]:
		return result
	if state_id == "retake" and owner != "player":
		return result
	if state_id in ["stabilizing", "defend"] and owner != "enemy":
		return result
	var logistics: Dictionary = precomputed_development_metrics.get("logistics", {}) \
		if precomputed_development_metrics.get("logistics", {}) is Dictionary \
		else {}
	if logistics.is_empty():
		logistics = _town_logistics_state(session, town)
	var recovery: Dictionary = precomputed_development_metrics.get("recovery", {}) \
		if precomputed_development_metrics.get("recovery", {}) is Dictionary \
		else {}
	if recovery.is_empty():
		recovery = _town_recovery_state(session, town, logistics)
	var capital_project: Dictionary = precomputed_development_metrics.get("capital_project", {}) \
		if precomputed_development_metrics.get("capital_project", {}) is Dictionary \
		else {}
	if capital_project.is_empty():
		capital_project = _town_capital_project_state(town, session, logistics, recovery)
	match state_id:
		"retake":
			if owner != "player":
				return result
			var recency_bonus: int = max(0, 54 - (int(result.get("days_since_change", 0)) * 8))
			var battle_readiness := int(precomputed_development_metrics.get("battle_readiness", 0)) \
				if precomputed_development_metrics.has("battle_readiness") \
				else _town_battle_readiness(town, session)
			var weakness_bonus: int = max(0, 34 - battle_readiness)
			weakness_bonus += int(recovery.get("pressure", 0)) * 8
			weakness_bonus += int(logistics.get("support_gap", 0)) * 14
			if bool(capital_project.get("vulnerable", false)):
				weakness_bonus += 18
			var priority_bonus: int = base_priority + recency_bonus + weakness_bonus
			var threshold_reduction: int = 1 if priority_bonus >= 140 else 0
			if role == "capital" or objective_anchor:
				threshold_reduction += 1
			result["active"] = true
			result["mode"] = "retake"
			result["priority_bonus"] = priority_bonus
			result["pressure_bonus"] = clampi(int(floor(float(priority_bonus) / 115.0)), 1, 4)
			result["threshold_reduction"] = clampi(threshold_reduction, 0, 2)
			result["summary"] = "%s still treats %s as a retake front." % [enemy_label, _town_name(town)]
			result["compact_summary"] = "retake %s" % _town_name(town)
			result["public_clause"] = "retake orders still center on the lost town"
			return result
		"stabilizing":
			if owner != "enemy":
				return result
			var stabilize_until_day: int = int(front.get("stabilize_until_day", 0))
			var days_remaining: int = max(0, stabilize_until_day - int(session.day) + 1) if session != null else 0
			if days_remaining <= 0 and not bool(recovery.get("active", false)):
				return result
			var pressure_bonus: int = int(recovery.get("pressure", 0)) * 10
			pressure_bonus += int(logistics.get("support_gap", 0)) * 14
			pressure_bonus += int(logistics.get("threatened_count", 0)) * 8
			pressure_bonus += max(0, days_remaining - 1) * 12
			if bool(capital_project.get("vulnerable", false)):
				pressure_bonus += 14
			result["active"] = true
			result["mode"] = "stabilizing"
			result["days_remaining"] = days_remaining
			result["priority_bonus"] = base_priority + pressure_bonus
			result["garrison_bonus"] = 65 + pressure_bonus
			result["build_bonus"] = 45 + int(recovery.get("pressure", 0)) * 10 + max(0, days_remaining - 1) * 8
			result["summary"] = "%s is still stabilizing %s." % [enemy_label, _town_name(town)]
			result["compact_summary"] = "stabilize %s" % _town_name(town)
			result["public_clause"] = (
				"the reclaimed walls stay on stabilization orders for %d day%s"
				% [days_remaining, "" if days_remaining == 1 else "s"]
				if days_remaining > 0
				else "the reclaimed walls are still being stabilized"
			)
			return result
		"defend":
			if owner != "enemy":
				return result
			var defend_until_day: int = max(
				int(front.get("defense_until_day", 0)),
				int(front.get("stabilize_until_day", 0))
			)
			var defend_days_remaining: int = max(0, defend_until_day - int(session.day) + 1) if session != null else 0
			if defend_days_remaining <= 0 and not bool(recovery.get("active", false)):
				return result
			var defense_pressure_bonus: int = int(recovery.get("pressure", 0)) * 8
			defense_pressure_bonus += int(logistics.get("support_gap", 0)) * 10
			defense_pressure_bonus += int(logistics.get("threatened_count", 0)) * 12
			defense_pressure_bonus += max(0, defend_days_remaining - 1) * 10
			if bool(capital_project.get("vulnerable", false)):
				defense_pressure_bonus += 14
			result["active"] = true
			result["mode"] = "stabilizing"
			result["days_remaining"] = defend_days_remaining
			result["priority_bonus"] = base_priority + defense_pressure_bonus
			result["garrison_bonus"] = 70 + defense_pressure_bonus
			result["build_bonus"] = 42 + int(recovery.get("pressure", 0)) * 8 + max(0, defend_days_remaining - 1) * 8
			result["summary"] = "%s is holding %s after a defensive stand." % [enemy_label, _town_name(town)]
			result["compact_summary"] = "defend %s" % _town_name(town)
			result["public_clause"] = (
				"the reclaimed walls stay under defender watch for %d day%s"
				% [defend_days_remaining, "" if defend_days_remaining == 1 else "s"]
				if defend_days_remaining > 0
				else "the reclaimed walls are still under defender watch"
			)
			return result
		_:
			return result

static func _normalized_enemy_front_faction_id(
	session: SessionStateStoreScript.SessionData,
	front: Dictionary,
	town: Dictionary
) -> String:
	var faction_id := PlayerRules.controller_id(front)
	if faction_id != "" and not _enemy_state_for_faction(session, faction_id).is_empty():
		return faction_id
	var template_faction_id := _town_faction_id(town)
	if template_faction_id != "" and not _enemy_state_for_faction(session, template_faction_id).is_empty():
		return template_faction_id
	return ""

static func _retake_front_from_legacy_state(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	front: Dictionary
) -> Dictionary:
	if session == null or town.is_empty():
		return front
	if String(front.get("state", "")) != "":
		return front
	var placement_id := String(town.get("placement_id", ""))
	if String(town.get("owner", "neutral")) != "player" or not _scenario_town_started_enemy(session, placement_id):
		return front
	var faction_id := _town_faction_id(town)
	if faction_id == "" or _enemy_state_for_faction(session, faction_id).is_empty():
		return front
	var inferred := front.duplicate(true)
	inferred["state"] = "retake"
	inferred.merge(PlayerRules.identity_fields(session, faction_id), true)
	inferred["last_change_day"] = max(
		0,
		int(_normalize_town_recovery_state(town.get("recovery", {})).get("last_event_day", session.day))
	)
	inferred["last_owner"] = "enemy"
	inferred["capture_count"] = max(1, int(inferred.get("capture_count", 0)))
	return inferred

static func _town_front_after_control_change(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	previous_owner: String,
	new_owner: String,
	controlling_faction_id: String,
	source: String
) -> Dictionary:
	var front := _normalize_town_front_state(town.get("front", {}))
	var faction_id := controlling_faction_id
	if faction_id == "" and previous_owner == "enemy":
		faction_id = _normalized_enemy_front_faction_id(session, front, town)
	if faction_id == "" and new_owner == "enemy":
		faction_id = _normalized_enemy_front_faction_id(session, front, town)
	if previous_owner == new_owner:
		if new_owner == "enemy" and faction_id != "":
			return _town_front_stabilizing_state(session, town, faction_id, source)
		return front
	if new_owner == "player":
		if faction_id == "":
			return _normalize_town_front_state({})
		front["state"] = "retake"
		front.merge(PlayerRules.identity_fields(session, faction_id), true)
		front["last_change_day"] = int(session.day)
		front["stabilize_until_day"] = 0
		front["last_owner"] = previous_owner
		front["capture_count"] = max(1, int(front.get("capture_count", 0)) + 1)
		front["source"] = source
		return front
	if new_owner == "enemy":
		if faction_id == "":
			return _normalize_town_front_state({})
		return _town_front_stabilizing_state(session, town, faction_id, source, previous_owner)
	return _normalize_town_front_state({})

static func _town_front_stabilizing_state(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	faction_id: String,
	source: String,
	previous_owner: String = "",
	bonus_days: int = 0
) -> Dictionary:
	var front := _normalize_town_front_state(town.get("front", {}))
	front["state"] = "stabilizing"
	front.merge(PlayerRules.identity_fields(session, faction_id), true)
	front["last_change_day"] = int(session.day) if session != null else int(front.get("last_change_day", 0))
	front["stabilize_until_day"] = (
		int(session.day) + clampi(_town_front_stabilize_days(session, town) + max(0, bonus_days), 2, 8)
		if session != null
		else max(0, int(front.get("stabilize_until_day", 0)))
	)
	if previous_owner != "":
		front["last_owner"] = previous_owner
	front["capture_count"] = max(1, int(front.get("capture_count", 0)))
	front["source"] = source
	return front

static func _town_front_priority_seed(role: String, objective_anchor: bool) -> int:
	var priority := 88
	match role:
		"capital":
			priority += 92
		"stronghold":
			priority += 54
	if objective_anchor:
		priority += 30
	return priority

static func _town_front_stabilize_days(session: SessionStateStoreScript.SessionData, town: Dictionary) -> int:
	var days := 2
	match _town_strategic_role(town):
		"capital":
			days += 2
		"stronghold":
			days += 1
	if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
		days += 1
	if bool(_town_recovery_state(session, town).get("active", false)):
		days += 1
	return clampi(days, 2, 6)

static func _town_occupation_relief_per_day(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	logistics: Dictionary = {},
	recovery: Dictionary = {},
	front: Dictionary = {}
) -> int:
	if session == null:
		return 1
	if logistics.is_empty():
		logistics = _town_logistics_state(session, town)
	if recovery.is_empty():
		recovery = _town_recovery_state(session, town)
	if front.is_empty():
		front = _town_front_state(session, town)
	var relief := 1 + int(floor(float(_town_recovery_relief_rating(session, town)) / 4.0))
	relief += min(2, int(logistics.get("met_requirements", 0)))
	relief -= int(logistics.get("support_gap", 0))
	if bool(recovery.get("active", false)):
		relief -= 1
	if bool(front.get("active", false)) and String(front.get("mode", "")) == "retake":
		relief -= 1
	return clampi(relief, 1, 4)

static func _town_occupation_after_control_change(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	previous_owner: String,
	new_owner: String,
	controlling_faction_id: String,
	source: String
) -> Dictionary:
	var occupation := _normalize_town_occupation_state(town.get("occupation", {}))
	if previous_owner == new_owner:
		if new_owner != "player":
			return _normalize_town_occupation_state({})
		return occupation
	if new_owner != "player":
		return _normalize_town_occupation_state({})
	if previous_owner != "enemy":
		return _normalize_town_occupation_state({})
	var faction_id := controlling_faction_id
	if faction_id == "":
		faction_id = _town_faction_id(town)
	if faction_id == "":
		return _normalize_town_occupation_state({})
	var pressure := _town_occupation_seed_pressure(session, town)
	occupation["state"] = "pacifying"
	occupation.merge(PlayerRules.identity_fields(session, faction_id), true)
	occupation["pressure"] = pressure
	occupation["initial_pressure"] = pressure
	occupation["start_day"] = session.day if session != null else 0
	occupation["last_event_day"] = session.day if session != null else 0
	occupation["last_owner"] = previous_owner
	occupation["source"] = source
	occupation["locked_recruits"] = {}
	_lock_town_occupation_reserves(town, occupation)
	return occupation

static func _town_occupation_seed_pressure(session: SessionStateStoreScript.SessionData, town: Dictionary) -> int:
	var pressure := 3
	match _town_strategic_role(town):
		"capital":
			pressure += 4
		"stronghold":
			pressure += 2
		_:
			pressure += 1
	if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
		pressure += 1
	if _town_garrison_headcount(town) > 0:
		pressure += 1
	return clampi(pressure, 4, 10)

static func _lock_town_occupation_reserves(town: Dictionary, occupation: Dictionary) -> void:
	if town.is_empty():
		return
	var available := _normalize_recruit_payload(town.get("available_recruits", {}))
	if available.is_empty():
		occupation["locked_recruits"] = {}
		return
	var access_percent := clampi(80 - (int(occupation.get("initial_pressure", 0)) * 8), 20, 55)
	var accessible := {}
	var locked := {}
	for unit_id_value in available.keys():
		var unit_id := String(unit_id_value)
		var count: int = max(0, int(available.get(unit_id, 0)))
		if unit_id == "" or count <= 0:
			continue
		var released := int(floor(float(count) * float(access_percent) / 100.0))
		if released <= 0:
			released = 1
		released = clampi(released, 0, count)
		if released > 0:
			accessible[unit_id] = released
		if count > released:
			locked[unit_id] = count - released
	town["available_recruits"] = accessible
	occupation["locked_recruits"] = locked

static func _release_town_occupation_reserves(town: Dictionary) -> Dictionary:
	var occupation := _normalize_town_occupation_state(town.get("occupation", {}))
	var locked := _normalize_recruit_payload(occupation.get("locked_recruits", {}))
	if locked.is_empty():
		town["occupation"] = _normalize_town_occupation_state({})
		return town
	town["available_recruits"] = _add_recruit_growth(town.get("available_recruits", {}), locked)
	town["occupation"] = _normalize_town_occupation_state({})
	return town

static func _town_recovery_relief_rating(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	logistics_state: Dictionary = {}
) -> int:
	var relief := int(_town_logistics_plan(town).get("recovery_relief", 0))
	var logistics := logistics_state if not logistics_state.is_empty() else _town_logistics_state(session, town)
	relief += _town_building_bonus_total(town, "recovery_relief")
	relief += int(logistics.get("recovery_relief_bonus", 0))
	relief += int(logistics.get("response_recovery_relief_bonus", 0))
	relief += _town_capital_project_recovery_relief(town)
	return max(0, relief)

static func _town_capital_project_recovery_relief(town: Dictionary) -> int:
	var total := 0
	for building_id_value in _normalize_built_buildings_for_town_state(town):
		var capital_project = ContentService.get_building(String(building_id_value)).get("capital_project", {})
		if capital_project is Dictionary:
			total += max(0, int(capital_project.get("recovery_guard", 0)))
	return total

static func _project_dependency_ids(project_id: String) -> Array:
	var dependency_ids := []
	var building := ContentService.get_building(project_id)
	if building.is_empty():
		return dependency_ids
	for dependency_id_value in building.get("requires", []):
		var dependency_id := String(dependency_id_value)
		if dependency_id != "" and dependency_id not in dependency_ids:
			dependency_ids.append(dependency_id)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and upgrade_from not in dependency_ids:
		dependency_ids.append(upgrade_from)
	return dependency_ids

static func _blank_project_vulnerability_penalties() -> Dictionary:
	return {
		"quality_penalty": 0,
		"readiness_penalty": 0,
		"pressure_penalty": 0,
		"growth_penalty_percent": 0,
	}

static func _resource_site_town_support(site: Dictionary) -> Dictionary:
	var support := {
		"quality_bonus": 0,
		"readiness_bonus": 0,
		"pressure_bonus": 0,
		"growth_bonus_percent": 0,
		"recovery_relief": 0,
		"disruption_pressure": 0,
	}
	var authored_support = site.get("town_support", {})
	if authored_support is Dictionary and not authored_support.is_empty():
		for key in support.keys():
			support[key] = max(0, int(authored_support.get(key, support[key])))
		return support
	match String(site.get("family", "")):
		"mine":
			support["growth_bonus_percent"] = 3
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"neutral_dwelling":
			# Dwellings grow towns by +1 per creature instead (see
			# _add_dwelling_town_growth), not through logistics support.
			pass
		"faction_outpost":
			support["readiness_bonus"] = max(2, max(0, int(site.get("vision_radius", 0))) * 2)
			support["pressure_bonus"] = max(0, int(site.get("pressure_bonus", 0)))
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"frontier_shrine":
			support["quality_bonus"] = 2
			support["pressure_bonus"] = 1
			support["growth_bonus_percent"] = 6
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"scouting_structure":
			support["readiness_bonus"] = max(1, max(0, int(site.get("vision_radius", 0))))
			support["pressure_bonus"] = 1
			support["disruption_pressure"] = 1
		"transit_object":
			support["readiness_bonus"] = 1
			support["recovery_relief"] = 1
			support["disruption_pressure"] = 1
		"repeatable_service":
			support["recovery_relief"] = 1
	return support

static func _resource_site_under_threat(session: SessionStateStoreScript.SessionData, node: Dictionary, controller_id: String) -> bool:
	if session == null:
		return false
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var response_active := bool(_resource_site_response_state(session, node, site).get("active", false))
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or not OverworldLevelRulesScript.same_level(encounter, node):
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if PlayerRules.raid_controller_id(encounter) == "" or PlayerRules.allied(session, PlayerRules.raid_controller_id(encounter), controller_id):
			continue
		if String(encounter.get("target_kind", "")) == "resource" and String(encounter.get("target_placement_id", "")) == String(node.get("placement_id", "")):
			return true
		if response_active:
			continue
		var distance = abs(int(encounter.get("x", 0)) - int(node.get("x", 0))) + abs(int(encounter.get("y", 0)) - int(node.get("y", 0)))
		if distance <= 2 and (bool(encounter.get("arrived", false)) or int(encounter.get("goal_distance", 9999)) <= 2):
			return true
	return false

static func _apply_recruit_percent(recruits: Variant, percent_modifier: int) -> Dictionary:
	var adjusted := {}
	if not (recruits is Dictionary):
		return adjusted
	for unit_id_value in recruits.keys():
		var unit_id := String(unit_id_value)
		var base_count = max(0, int(recruits.get(unit_id, 0)))
		if unit_id == "":
			continue
		if base_count <= 0:
			adjusted[unit_id] = 0
			continue
		adjusted[unit_id] = max(0, int(round(float(base_count) * max(0.0, float(100 + percent_modifier)) / 100.0)))
	return adjusted

static func _apply_resource_percent_scale(resources: Variant, percent: int) -> Dictionary:
	var scaled := _normalize_resource_dict(resources)
	var applied_percent: int = max(0, percent)
	for resource_id in scaled.keys():
		scaled[resource_id] = max(
			0,
			int(round(float(int(scaled.get(resource_id, 0))) * float(applied_percent) / 100.0))
		)
	return scaled

static func _resource_site_family_short_label(family_id: String) -> String:
	match family_id:
		"neutral_dwelling":
			return "dwelling"
		"faction_outpost":
			return "outpost"
		"frontier_shrine":
			return "shrine"
		_:
			return family_id

static func _town_response_panel_lines(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var lines := ["Strategic Response"]
	var logistics := _town_logistics_state(session, town)
	var recovery := _town_recovery_state(session, town)
	var capital_project := _town_capital_project_state(town, session)
	if bool(recovery.get("active", false)):
		lines.append("- Recovery %s" % String(recovery.get("summary", "")))
	else:
		lines.append("- Recovery steady | %d/day relief" % int(recovery.get("relief_per_day", 1)))
	lines.append("- Logistics %s" % String(logistics.get("summary", "No linked routes.")))
	if logistics.get("response_site_labels", []) is Array and not logistics.get("response_site_labels", []).is_empty():
		lines.append("- Active route orders: %s" % ", ".join(logistics.get("response_site_labels", [])))
	if logistics.get("delivery_site_labels", []) is Array and not logistics.get("delivery_site_labels", []).is_empty():
		lines.append("- Reserve deliveries: %s" % ", ".join(logistics.get("delivery_site_labels", [])))
	if logistics.get("threatened_site_labels", []) is Array and not logistics.get("threatened_site_labels", []).is_empty():
		lines.append("- Threat lanes: %s" % ", ".join(logistics.get("threatened_site_labels", [])))
	if logistics.get("disrupted_site_labels", []) is Array and not logistics.get("disrupted_site_labels", []).is_empty():
		lines.append("- Denied routes: %s" % ", ".join(logistics.get("disrupted_site_labels", [])))
	if bool(capital_project.get("vulnerable", false)):
		lines.append("- Capital project is vulnerable while chains stay cut or recovery pressure remains.")
	var action_count := _town_response_actions(session, town).size()
	if action_count > 0:
		lines.append("- %d active order%s ready. Response orders spend commander movement plus stores." % [action_count, "" if action_count == 1 else "s"])
	else:
		lines.append("- No immediate response order is ready. Reclaim denied sites or wait for new threat pressure.")
	return lines

static func _town_response_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._town_response_actions", [session, town])

static func _town_market_panel_lines(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var state := _town_market_state(town)
	var lines := ["Exchange Hall"]
	if not bool(state.get("active", false)):
		lines.append("- No market square stands here. Build a market to liquidate spare stock or buy scarce wood and ore.")
		return lines
	var buy_rates: Dictionary = state.get("buy_rates", {})
	var sell_rates: Dictionary = state.get("sell_rates", {})
	lines.append(
		"- %s | Buy wood %d gold, ore %d gold | Sell wood %d gold, ore %d gold" % [
			String(state.get("building_name", "Market")),
			int(buy_rates.get("wood", 0)),
			int(buy_rates.get("ore", 0)),
			int(sell_rates.get("wood", 0)),
			int(sell_rates.get("ore", 0)),
		]
	)
	var specialty_summary := String(state.get("specialty_summary", ""))
	if specialty_summary != "":
		lines.append("- %s" % specialty_summary)
	var usage := _normalize_town_market_usage_state(
		town.get("market_usage", {}),
		int(session.day) if session != null else -1
	)
	lines.append("- Weekly caps %s." % _market_usage_summary(state, usage))
	var reset_day := int(usage.get("week", 1)) * 7 + 1
	var rare_resources: Array = state.get("rare_resources", [])
	if not rare_resources.is_empty():
		var rare_buy := []
		var rare_sell := []
		for resource in rare_resources:
			rare_buy.append(int(buy_rates.get(resource, 0)))
			rare_sell.append(int(sell_rates.get(resource, 0)))
		lines.append("- Rare resources buy %d-%d gold, sell %d-%d gold; up to %d bought and %d sold of each per week. Limits reset Day %d." % [int(rare_buy.min()), int(rare_buy.max()), int(rare_sell.min()), int(rare_sell.max()), int(state.buy_caps.get(rare_resources[0], 0)), int(state.sell_caps.get(rare_resources[0], 0)), reset_day])
	var bulk_resource := String(state.get("bulk_resource", ""))
	var bulk_resources := _market_bulk_resources(state)
	var bulk_amount := int(state.get("bulk_amount", 0))
	for bulk_resource_value in bulk_resources:
		bulk_resource = String(bulk_resource_value)
		var bulk_buy := _market_quote_from_state(state, "buy", bulk_resource, bulk_amount)
		var bulk_sell := _market_quote_from_state(state, "sell", bulk_resource, bulk_amount)
		lines.append(
			"- Bulk %s lot: buy %d for %d gold or liquidate for %d gold" % [
				bulk_resource,
				bulk_amount,
				int(bulk_buy.get("gold_value", 0)),
				int(bulk_sell.get("gold_value", 0)),
			]
		)
	var ready_count := 0
	for action in _town_market_actions(session, town):
		if action is Dictionary and not bool(action.get("disabled", false)):
			ready_count += 1
	lines.append("- %d exchange order%s ready." % [ready_count, "" if ready_count == 1 else "s"])
	return lines

static func _town_market_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._town_market_actions", [session, town])

static func _town_market_state(town: Dictionary) -> Dictionary:
	var inactive := {
		"active": false,
		"tier": 0,
		"profile": "none",
		"building_id": "",
		"building_name": "",
		"buy_rates": {"wood": 0, "ore": 0},
		"sell_rates": {"wood": 0, "ore": 0},
		"buy_caps": {"wood": 0, "ore": 0},
		"sell_caps": {"wood": 0, "ore": 0},
		"rare_resources": [],
		"refresh_cadence": "weekly",
		"bulk_resource": "",
		"bulk_resources": [],
		"bulk_amount": 0,
		"specialty_summary": "",
		"exchange_value": 0,
	}
	if town.is_empty():
		return inactive
	var built_buildings := _normalize_built_buildings_for_town_state(town)
	var market_building_id := ""
	var market_profile := {}
	for building_id_value in built_buildings:
		var candidate_id := String(building_id_value)
		var candidate_profile_value: Variant = ContentService.get_building(candidate_id).get("market_profile", {})
		if not (candidate_profile_value is Dictionary):
			continue
		var candidate_profile: Dictionary = candidate_profile_value
		if String(candidate_profile.get("id", "")) == "":
			continue
		if market_profile.is_empty() or int(candidate_profile.get("tier", 0)) > int(market_profile.get("tier", 0)):
			market_building_id = candidate_id
			market_profile = candidate_profile.duplicate(true)
	if market_profile.is_empty():
		return inactive
	var profile_id := String(market_profile.get("id", "none"))
	var tier: int = maxi(1, int(market_profile.get("tier", 1)))

	var market_building := ContentService.get_building(market_building_id)
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var buy_rates := {}
	var sell_rates := {}
	var buy_adjustments: Dictionary = market_profile.get("buy_rate_adjustments", {}) if market_profile.get("buy_rate_adjustments", {}) is Dictionary else {}
	var sell_adjustments: Dictionary = market_profile.get("sell_rate_adjustments", {}) if market_profile.get("sell_rate_adjustments", {}) is Dictionary else {}
	# Every market resource prices off the wood/ore curve (local abundance and
	# the market's tier adjustments), scaled by its economy value.
	for resource_key in MARKET_RESOURCE_KEYS:
		var abundance := _market_resource_abundance_score(faction.get("economy", {}), town_template.get("economy", {}), resource_key)
		var buy_rate := 740 - (abundance * 35)
		var sell_rate := 280 + (abundance * 30)
		buy_rate += _market_rate_adjustment(buy_adjustments, resource_key)
		sell_rate += _market_rate_adjustment(sell_adjustments, resource_key)
		buy_rate = clampi(buy_rate, 500, 760)
		sell_rate = clampi(sell_rate, 260, max(260, buy_rate - 120))
		var value_scale := _market_value_scale(resource_key)
		buy_rates[resource_key] = int(round(buy_rate * value_scale))
		sell_rates[resource_key] = int(round(sell_rate * value_scale))
	var bulk_resources := []
	for resource_value in market_profile.get("bulk_resources", []):
		var resource_id := String(resource_value)
		if resource_id in NORMAL_MARKET_RESOURCE_KEYS and resource_id not in bulk_resources:
			bulk_resources.append(resource_id)
	var bulk_resource := String(bulk_resources[0]) if not bulk_resources.is_empty() else ""
	var specialty_summary := String(market_profile.get("specialty_summary", ""))
	var exchange_value := 0
	for resource_key in NORMAL_MARKET_RESOURCE_KEYS:
		exchange_value += int(sell_rates.get(resource_key, 0))
		exchange_value += max(0, 900 - int(buy_rates.get(resource_key, 0)))
	exchange_value += bulk_resources.size() * 120
	var caps := _market_caps_for_profile(market_profile)
	var rare_resources: Array = []
	for resource_key in MARKET_RESOURCE_KEYS:
		if resource_key not in NORMAL_MARKET_RESOURCE_KEYS:
			rare_resources.append(resource_key)
	return {
		"active": true,
		"tier": tier,
		"profile": profile_id,
		"rare_resources": rare_resources,
		"building_id": market_building_id,
		"building_name": String(market_building.get("name", market_building_id)),
		"buy_rates": buy_rates,
		"sell_rates": sell_rates,
		"buy_caps": caps.get("buy_caps", {}),
		"sell_caps": caps.get("sell_caps", {}),
		"refresh_cadence": String(caps.get("refresh_cadence", "weekly")),
		"bulk_resource": bulk_resource,
		"bulk_resources": bulk_resources,
		"bulk_amount": 2 if not bulk_resources.is_empty() else 0,
		"specialty_summary": specialty_summary,
		"exchange_value": exchange_value,
	}

static func _market_buy_resources(state: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._market_buy_resources", [state])

## A market profile's rate adjustment for one resource; rare resources follow
## the profile's wood and ore adjustment.
static func _market_rate_adjustment(adjustments: Dictionary, resource_key: String) -> int:
	if adjustments.has(resource_key):
		return int(adjustments.get(resource_key, 0))
	var total := 0
	for common_key in NORMAL_MARKET_RESOURCE_KEYS:
		total += int(adjustments.get(common_key, 0))
	return int(round(float(total) / float(NORMAL_MARKET_RESOURCE_KEYS.size())))

static func _market_value_scale(resource_key: String) -> float:
	return float(MARKET_RESOURCE_VALUES.get(resource_key, 400)) / float(MARKET_RESOURCE_VALUES.get("wood", 400))

static func bank_town_rare_imports(town: Dictionary, pool: Dictionary, cost: Dictionary, current_day: int, gold_reserve: int = 2000) -> Array:
	# Bank only a selected legal project's shortage. Require funding for its full
	# remaining import bill, ordinary cost and reserve before spending this week.
	var state := _town_market_state(town)
	var resources: Array = state.get("rare_resources", [])
	if resources.is_empty() or current_day < 1:
		return []
	var projected := pool.duplicate(true)
	var import_bill := 0
	for resource in resources:
		var deficit := maxi(0, int(cost.get(resource, 0)) - int(pool.get(resource, 0)))
		import_bill += deficit * int(state.buy_rates[resource])
		projected[resource] = maxi(int(projected.get(resource, 0)), int(cost.get(resource, 0)))
	if import_bill <= 0:
		return []
	projected["gold"] = int(projected.get("gold", 0)) - import_bill - maxi(0, gold_reserve)
	# No liquidation: already-owned staples remain reserved for the project.
	var readiness := _town_market_cost_coverage(town, projected, cost, current_day)
	if not bool(readiness.get("affordable", false)) or int(projected.gold) < int(readiness.get("required_gold_total", 0)):
		return []
	var usage := _normalize_town_market_usage_state(town.get("market_usage", {}), current_day)
	var actions: Array = []
	for resource in resources:
		var deficit := maxi(0, int(cost.get(resource, 0)) - int(pool.get(resource, 0)))
		var quote := _market_quote_from_state(state, "buy", String(resource), 1)
		var cap := _market_cap_state_for_quote({"market_usage": usage}, state, quote, current_day)
		var amount := mini(deficit, int(cap.remaining))
		if amount <= 0:
			continue
		quote = _market_quote_from_state(state, "buy", String(resource), amount)
		_apply_resource_transaction_to_pool(pool, quote.cost, quote.gain)
		usage.buy[resource] = int(usage.buy.get(resource, 0)) + amount
		actions.append("%s buys %d %s for %d gold toward construction." % [_town_name(town), amount, String(resource).replace("_", " "), int(quote.gold_value)])
	if not actions.is_empty():
		town["market_usage"] = usage
	return actions

## Weekly per-town limits: wood and ore 6 bought and 8 sold, rare resources 2
## and 3, plus the market profile's per-resource bonuses.
static func _market_caps_for_profile(profile: Dictionary) -> Dictionary:
	var buy_caps := {}
	var sell_caps := {}
	var buy_bonus: Dictionary = profile.get("buy_cap_bonus", {}) if profile.get("buy_cap_bonus", {}) is Dictionary else {}
	var sell_bonus: Dictionary = profile.get("sell_cap_bonus", {}) if profile.get("sell_cap_bonus", {}) is Dictionary else {}
	for resource_key in MARKET_RESOURCE_KEYS:
		var common: bool = resource_key in NORMAL_MARKET_RESOURCE_KEYS
		buy_caps[resource_key] = (MARKET_BASE_BUY_CAP if common else MARKET_RARE_BUY_CAP) + max(0, int(buy_bonus.get(resource_key, 0)))
		sell_caps[resource_key] = (MARKET_BASE_SELL_CAP if common else MARKET_RARE_SELL_CAP) + max(0, int(sell_bonus.get(resource_key, 0)))
	return {
		"refresh_cadence": "weekly",
		"buy_caps": buy_caps,
		"sell_caps": sell_caps,
	}

static func _market_bulk_resources(state: Dictionary) -> Array:
	var result := []
	var authored = state.get("bulk_resources", [])
	if authored is Array:
		for resource_value in authored:
			var resource_id := String(resource_value)
			if resource_id in NORMAL_MARKET_RESOURCE_KEYS and resource_id not in result:
				result.append(resource_id)
	var legacy_resource := String(state.get("bulk_resource", ""))
	if legacy_resource in NORMAL_MARKET_RESOURCE_KEYS and legacy_resource not in result:
		result.append(legacy_resource)
	return result

static func _empty_market_usage_bucket(default_value: int = 0) -> Dictionary:
	var bucket := {}
	for resource_key in NORMAL_MARKET_RESOURCE_KEYS:
		bucket[resource_key] = default_value
	return bucket

static func _normalize_market_usage_bucket(value: Variant) -> Dictionary:
	var bucket := _empty_market_usage_bucket()
	if not (value is Dictionary):
		return bucket
	for resource_key in LIVE_STOCKPILE_RESOURCE_KEYS:
		if resource_key != "gold" and (resource_key in NORMAL_MARKET_RESOURCE_KEYS or value.has(resource_key)):
			bucket[resource_key] = max(0, int(value.get(resource_key, 0)))
	return bucket

static func _normalize_town_market_usage_state(value: Variant, current_day: int = -1) -> Dictionary:
	var current_week: int = _week_of_day(current_day) if current_day > 0 else 1
	var source: Dictionary = value if value is Dictionary else {}
	var source_week := int(source.get("week", current_week))
	var usage_week: int = current_week if current_day > 0 else max(1, source_week)
	var should_reset: bool = current_day > 0 and source_week != usage_week
	return {
		"week": usage_week,
		"refresh_cadence": "weekly",
		"buy": _empty_market_usage_bucket() if should_reset else _normalize_market_usage_bucket(source.get("buy", {})),
		"sell": _empty_market_usage_bucket() if should_reset else _normalize_market_usage_bucket(source.get("sell", {})),
	}

static func _market_cap_state_for_quote(
	town: Dictionary,
	state: Dictionary,
	quote: Dictionary,
	current_day: int = -1
) -> Dictionary:
	var action_type := String(quote.get("action_type", ""))
	var resource_key := String(quote.get("resource", ""))
	var usage := _normalize_town_market_usage_state(town.get("market_usage", {}), current_day)
	var caps: Dictionary = state.get("%s_caps" % action_type, {}) if state.get("%s_caps" % action_type, {}) is Dictionary else {}
	var bucket: Dictionary = usage.get(action_type, {}) if usage.get(action_type, {}) is Dictionary else {}
	var limit: int = max(0, int(caps.get(resource_key, 0)))
	var used := clampi(int(bucket.get(resource_key, 0)), 0, limit)
	return {
		"week": int(usage.get("week", 1)),
		"refresh_cadence": String(state.get("refresh_cadence", "weekly")),
		"limit": limit,
		"used": used,
		"remaining": max(0, limit - used),
	}

static func _market_usage_summary(state: Dictionary, usage: Dictionary) -> String:
	var parts := []
	for action_type in ["buy", "sell"]:
		var caps: Dictionary = state.get("%s_caps" % action_type, {}) if state.get("%s_caps" % action_type, {}) is Dictionary else {}
		var bucket: Dictionary = usage.get(action_type, {}) if usage.get(action_type, {}) is Dictionary else {}
		var resource_parts := []
		for resource_key in NORMAL_MARKET_RESOURCE_KEYS:
			resource_parts.append("%s %d/%d" % [
				resource_key,
				int(bucket.get(resource_key, 0)),
				int(caps.get(resource_key, 0)),
			])
		parts.append("%s %s" % [action_type, ", ".join(resource_parts)])
	return "; ".join(parts)

static func _market_resource_abundance_score(faction_economy: Variant, town_economy: Variant, resource_key: String) -> int:
	var score := 0
	var faction_base = faction_economy.get("base_income", {}) if faction_economy is Dictionary else {}
	var town_base = town_economy.get("base_income", {}) if town_economy is Dictionary else {}
	var faction_categories = faction_economy.get("per_category_income", {}) if faction_economy is Dictionary else {}
	var town_categories = town_economy.get("per_category_income", {}) if town_economy is Dictionary else {}
	var faction_economy_bucket = faction_categories.get("economy", {}) if faction_categories is Dictionary else {}
	var town_economy_bucket = town_categories.get("economy", {}) if town_categories is Dictionary else {}
	score += 1 if faction_base is Dictionary and int(faction_base.get(resource_key, 0)) > 0 else 0
	score += 1 if town_base is Dictionary and int(town_base.get(resource_key, 0)) > 0 else 0
	score += 1 if faction_economy_bucket is Dictionary and int(faction_economy_bucket.get(resource_key, 0)) > 0 else 0
	score += 1 if town_economy_bucket is Dictionary and int(town_economy_bucket.get(resource_key, 0)) > 0 else 0
	return score

static func _town_market_quote(town: Dictionary, action_type: String, resource_key: String, amount: int) -> Dictionary:
	return _market_quote_from_state(_town_market_state(town), action_type, resource_key, amount)

static func _market_quote_from_state(state: Dictionary, action_type: String, resource_key: String, amount: int) -> Dictionary:
	if not bool(state.get("active", false)):
		return {}
	if resource_key not in MARKET_RESOURCE_KEYS or action_type not in ["buy", "sell"]:
		return {}
	var normalized_amount = max(0, amount)
	if normalized_amount <= 0:
		return {}
	var rates: Dictionary = state.get("buy_rates", {}) if action_type == "buy" else state.get("sell_rates", {})
	var unit_rate := int(rates.get(resource_key, 0))
	if unit_rate <= 0:
		return {}
	var total_value = unit_rate * normalized_amount
	# Every full bulk lot trades at the lot price, so a larger order never costs
	# more than the same units bought in lots and singles.
	var bulk_amount := int(state.get("bulk_amount", 0))
	var bulk_lots := 0
	if bulk_amount > 1 and resource_key in _market_bulk_resources(state):
		bulk_lots = int(normalized_amount / bulk_amount)
	var is_bulk: bool = bulk_lots > 0
	if is_bulk:
		var lot_value: int = max(1, int(round(float(unit_rate * bulk_amount) * (0.9 if action_type == "buy" else 1.1))))
		total_value = bulk_lots * lot_value + (normalized_amount - bulk_lots * bulk_amount) * unit_rate
	var cost := {}
	var gain := {}
	if action_type == "buy":
		cost["gold"] = total_value
		gain[resource_key] = normalized_amount
	else:
		cost[resource_key] = normalized_amount
		gain["gold"] = total_value
	var rate_summary := "%s %d gold per %s" % [
		"Pays" if action_type == "buy" else "Yields",
		int(round(float(total_value) / float(normalized_amount))),
		resource_key,
	]
	if is_bulk:
		rate_summary += " in bulk"
	var summary := ""
	if action_type == "buy":
		summary = "Pay %d gold for %d %s" % [total_value, normalized_amount, resource_key]
	else:
		summary = "Trade %d %s for %d gold" % [normalized_amount, resource_key, total_value]
	return {
		"action_type": action_type,
		"resource": resource_key,
		"amount": normalized_amount,
		"cost": cost,
		"gain": gain,
		"gold_value": total_value,
		"building_name": String(state.get("building_name", "Market")),
		"building_summary": String(state.get("specialty_summary", "")),
		"summary": summary,
		"rate_summary": rate_summary,
	}

static func _town_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldRules._town_market_cost_coverage", [town, pool, cost, current_day])

static func _apply_market_cost_coverage(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._apply_market_cost_coverage", [town, pool, cost, current_day])

static func _town_battlefront_profile(town: Dictionary) -> Dictionary:
	var role := _town_strategic_role(town)
	var faction_id := _town_faction_id(town)
	var capital_project := _town_capital_project_state(town)
	var project_active := bool(capital_project.get("active", false))
	var tags := []
	var label := ""
	var summary := ""
	match faction_id:
		"faction_embercourt":
			label = "Fortress lanes"
			tags.append("fortress_lane")
			summary = "Fortress lanes compress the approach and reward braced pike screens."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				summary = "Fortress lanes compress the approach while reserve columns harden the line after the first exchanges."
		"faction_mireclaw":
			label = "Wall pressure"
			tags.append("wall_pressure")
			summary = "Flooded breach lanes reward late pack surges once the first wall break opens."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("bog_channels")
				summary = "Flooded breach lanes and reserve packs turn a stalled assault into a late marsh surge."
		"faction_sunvault":
			label = "Battery nests"
			tags.append("battery_nest")
			summary = "Battery nests lengthen the approach and reward shielded relay fire."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("elevated_fire")
				summary = "Battery nests lengthen the approach while reserve crews rotate fresh arrays into the line."
		"faction_thornwake":
			label = "Rooted roads"
			tags.append("chokepoint")
			summary = "Rooted roads slow the approach and reward bramble-backed holding actions."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("ambush_cover")
				summary = "Rooted roads and nursery reserves make every breach a slow recovery fight."
		"faction_brasshollow":
			label = "Siege stages"
			tags.append("fortress_lane")
			summary = "Siege stages compress the approach around armor, heat, and engine setup."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("wall_pressure")
				summary = "Siege stages and foundry reserves turn the town front into a pressure-engine kill lane."
		"faction_veilmourn":
			label = "Fog lanes"
			tags.append("fog_bank")
			summary = "Fog lanes break clean approaches and reward marked, isolated attackers."
			if role == "capital" or project_active:
				tags.append("reserve_wave")
				tags.append("ambush_cover")
				summary = "Fog lanes and black-sail reserves let defenders slip behind a stalled assault."
	if role == "capital" and "reserve_wave" not in tags:
		tags.append("reserve_wave")
	elif role == "stronghold" and project_active and "reserve_wave" not in tags:
		tags.append("reserve_wave")
	var normalized_tags := []
	for tag_id in tags:
		if tag_id != "" and tag_id not in normalized_tags:
			normalized_tags.append(tag_id)
	return {
		"role": role,
		"faction_id": faction_id,
		"project_active": project_active,
		"label": label,
		"summary": summary,
		"tags": normalized_tags,
	}

static func _town_capital_project_ids(town: Dictionary) -> Array:
	var ids := []
	var template := ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		if building_id == "":
			continue
		var capital_project: Variant = ContentService.get_building(building_id).get("capital_project", null)
		if capital_project is Dictionary and not capital_project.is_empty():
			ids.append(building_id)
	return ids

static func _town_role_quality_bonus(role: String) -> int:
	match role:
		"capital":
			return 10
		"stronghold":
			return 5
		_:
			return 0

static func _town_role_readiness_bonus(role: String) -> int:
	match role:
		"capital":
			return 12
		"stronghold":
			return 6
		_:
			return 0

static func _town_role_pressure_bonus(role: String) -> int:
	match role:
		"capital":
			return 1
		"stronghold":
			return 1
		_:
			return 0

static func _building_growth_payload(building_id: String) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._building_growth_payload", [building_id])

static func _add_recruit_growth(base_recruits: Variant, delta_recruits: Variant) -> Dictionary:
	var merged := {}
	if base_recruits is Dictionary:
		for unit_id in base_recruits.keys():
			merged[String(unit_id)] = max(0, int(base_recruits[unit_id]))
	if delta_recruits is Dictionary:
		for unit_id in delta_recruits.keys():
			merged[String(unit_id)] = int(merged.get(String(unit_id), 0)) + max(0, int(delta_recruits[unit_id]))
	return merged

static func _weighted_recruit_value(recruits: Variant) -> int:
	var total := 0
	if not (recruits is Dictionary):
		return total
	for unit_id_value in recruits.keys():
		var unit_id := String(unit_id_value)
		var count = max(0, int(recruits[unit_id_value]))
		if unit_id == "" or count <= 0:
			continue
		var unit := ContentService.get_unit(unit_id)
		var tier = max(1, int(unit.get("tier", 1)))
		total += count * (4 + (tier * 3))
		total += count * max(0, int(unit.get("attack", 0)) + int(unit.get("defense", 0)) - 6)
		if bool(unit.get("ranged", false)):
			total += count
	return total

static func _award_experience(session: SessionStateStoreScript.SessionData, amount: int) -> Array:
	return HumanEngine.native_writing(&"OverworldRules._award_experience", [session, amount])

static func _town_name(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("name", town.get("town_id", "Town")))

static func _town_faction_id(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("faction_id", ""))

static func _normalize_built_buildings_for_town_state(town: Dictionary) -> Array:
	if TownDevelopment.is_current(town):
		return TownDevelopment.active_buildings(town)
	var normalized := []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in town_template.get("starting_building_ids", []):
		_append_building_with_requirements(normalized, String(building_id_value))
	for building_id_value in town.get("built_buildings", []):
		_append_building_with_requirements(normalized, String(building_id_value))
	return normalized

static func _append_building_with_requirements(target: Array, building_id: String, trail: Array = []) -> void:
	if building_id == "" or building_id in target or building_id in trail:
		return
	var next_trail := trail.duplicate(true)
	next_trail.append(building_id)
	var building := ContentService.get_building(building_id)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "":
		_append_building_with_requirements(target, upgrade_from, next_trail)
	for requirement_value in building.get("requires", []):
		_append_building_with_requirements(target, String(requirement_value), next_trail)
	target.append(building_id)

static func _economy_profile_income(profile: Variant, built_buildings: Array) -> Dictionary:
	var income := {"gold": 0, "wood": 0, "ore": 0}
	if not (profile is Dictionary):
		return income
	income = _add_resource_sets(income, profile.get("base_income", {}))
	var per_category_income = profile.get("per_category_income", {})
	if not (per_category_income is Dictionary):
		return income
	var category_counts := _building_category_counts(built_buildings)
	for category_value in per_category_income.keys():
		var category := String(category_value)
		income = _add_resource_sets(
			income,
			_multiply_cost(per_category_income[category], int(category_counts.get(category, 0)))
		)
	return income

static func _pressure_bonus_from_profile(profile: Variant) -> int:
	if not (profile is Dictionary):
		return 0
	return max(0, int(profile.get("pressure_bonus", 0)))

static func _readiness_bonus_from_profile(profile: Variant) -> int:
	if not (profile is Dictionary):
		return 0
	return max(0, int(profile.get("readiness_bonus", 0)))

static func _building_category_counts(built_buildings: Array) -> Dictionary:
	var counts := {}
	for category in BUILDING_CATEGORIES:
		counts[category] = 0
	for building_id_value in built_buildings:
		var category := _building_category(String(building_id_value))
		counts[category] = int(counts.get(category, 0)) + 1
	return counts

static func _building_category(building_id: String) -> String:
	var category := String(ContentService.get_building(building_id).get("category", "support"))
	return category if category in BUILDING_CATEGORIES else "support"

static func _town_building_bonus_total(town: Dictionary, key: String) -> int:
	var total := 0
	for building_id_value in _normalize_built_buildings_for_town_state(town):
		total += max(0, int(ContentService.get_building(String(building_id_value)).get(key, 0)))
	return total

static func _town_spell_tier(town: Dictionary) -> int:
	var max_tier := 0
	for building_id_value in _normalize_built_buildings_for_town_state(town):
		max_tier = max(max_tier, int(ContentService.get_building(String(building_id_value)).get("spell_tier", 0)))
	return max_tier

static func _town_garrison_strength(town: Dictionary) -> int:
	var total_strength := 0
	for stack in town.get("garrison", []):
		if not (stack is Dictionary):
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		var count = max(0, int(stack.get("count", 0)))
		total_strength += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	return total_strength

static func _town_pressure_label(town: Dictionary) -> String:
	match _town_faction_id(town):
		"faction_embercourt":
			return "Frontier leverage"
		"faction_mireclaw":
			return "Enemy heroes"
		"faction_sunvault":
			return "Relay reach"
		"faction_thornwake":
			return "Root pressure"
		"faction_brasshollow":
			return "Siege pressure"
		"faction_veilmourn":
			return "Fog pressure"
		_:
			return "Pressure"

static func _missing_build_requirements(building: Dictionary, built_buildings: Variant) -> Array:
	var missing := []
	if not (built_buildings is Array):
		return missing
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and not TownDevelopment.satisfies(built_buildings, upgrade_from):
		missing.append(upgrade_from)
	for requirement_value in building.get("requires", []):
		var requirement := String(requirement_value)
		if requirement == "" or TownDevelopment.satisfies(built_buildings, requirement) or requirement in missing:
			continue
		missing.append(requirement)
	return missing

static func _requirements_met(building: Dictionary, built_buildings: Variant) -> bool:
	return _missing_build_requirements(building, built_buildings).is_empty()

static func _can_afford(session: SessionStateStoreScript.SessionData, cost: Variant) -> bool:
	return HumanEngine.native_writing(&"OverworldRules._can_afford", [session, cost])

static func _max_affordable_count(session: SessionStateStoreScript.SessionData, unit_cost: Variant) -> int:
	return HumanEngine.native_writing(&"OverworldRules._max_affordable_count", [session, unit_cost])

static func _multiply_cost(cost: Variant, multiplier: int) -> Dictionary:
	var scaled := {}
	if cost is Dictionary:
		for key in cost.keys():
			scaled[String(key)] = int(cost[key]) * multiplier
	return scaled

static func _spend_resources(session: SessionStateStoreScript.SessionData, cost: Variant) -> void:
	var resources := _normalize_live_resource_stockpile(session.overworld.get("resources", {}))
	if cost is Dictionary:
		for key in cost.keys():
			var resource_key := String(key)
			resources[resource_key] = max(0, int(resources.get(resource_key, 0)) - int(cost[key]))
	session.overworld["resources"] = resources

## `rewards` with every gold and resource amount raised by `pct` percent
## (Plunderer's Eye); experience and other entries are left as they are.
static func apply_reward_bonus(rewards: Variant, pct: int) -> Dictionary:
	var result: Dictionary = rewards.duplicate(true) if rewards is Dictionary else {}
	if pct <= 0:
		return result
	for key in result.keys():
		var value = result[key]
		if String(key) == "experience" or not (value is int or value is float) or int(value) <= 0:
			continue
		result[key] = int(value) + int(value) * pct / 100
	return result

static func _add_resources(session: SessionStateStoreScript.SessionData, delta: Variant) -> void:
	var resources := _normalize_live_resource_stockpile(session.overworld.get("resources", {}))
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key := String(key)
			if resource_key == "experience":
				continue
			resources[resource_key] = max(0, int(resources.get(resource_key, 0)) + int(delta[key]))
	session.overworld["resources"] = resources

static func _apply_resource_transaction_to_pool(pool: Dictionary, cost: Variant, gain: Variant) -> void:
	HumanEngine.native_writing(&"OverworldRules._apply_resource_transaction_to_pool", [pool, cost, gain])

static func _add_resource_sets(base: Variant, delta: Variant) -> Dictionary:
	var merged := {}
	if base is Dictionary:
		for key in base.keys():
			var resource_key := String(key)
			if resource_key == "experience" or resource_key == "":
				continue
			merged[resource_key] = int(base.get(key, 0))
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key := String(key)
			if resource_key == "experience":
				continue
			merged[resource_key] = int(merged.get(resource_key, 0)) + int(delta[key])
	return merged

static func _normalize_resource_dict(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for key in value.keys():
			normalized[String(key)] = max(0, int(value[key]))
	return normalized

static func resource_definition(resource_id: String) -> Dictionary:
	var normalized_id := resource_id.strip_edges()
	if normalized_id not in LIVE_STOCKPILE_RESOURCE_KEYS:
		return {}
	var resource: Dictionary = ContentService.get_resource(normalized_id)
	return resource.duplicate(true) if String(resource.get("id", "")) == normalized_id and bool(resource.get("stockpile", false)) else {}

static func resource_icon_path(resource_id: String) -> String:
	return HumanEngine.native(&"OverworldRules.resource_icon_path", [resource_id])

static func _empty_live_resource_stockpile() -> Dictionary:
	var resources := {}
	for resource_key in LIVE_STOCKPILE_RESOURCE_KEYS:
		resources[resource_key] = 0
	return resources

static func _normalize_live_resource_stockpile(value: Variant) -> Dictionary:
	var normalized := _empty_live_resource_stockpile()
	if value is Dictionary:
		for key in value.keys():
			var resource_key := String(key)
			if resource_key == "experience" or resource_key == "":
				continue
			normalized[resource_key] = max(0, int(value.get(key, 0)))
	return normalized

static func _resource_display_name(resource_key: String) -> String:
	return HumanEngine.native(&"OverworldRules._resource_display_name", [resource_key])

static func _resource_keys_for_payload(value: Variant) -> Array:
	var keys := []
	for resource_key in LIVE_STOCKPILE_RESOURCE_KEYS:
		if resource_key not in keys:
			keys.append(resource_key)
	if value is Dictionary:
		for key in value.keys():
			var resource_key := String(key)
			if resource_key == "experience" or resource_key == "":
				continue
			if resource_key not in keys:
				keys.append(resource_key)
	return keys

static func _normalize_recruit_payload(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for unit_id_value in value.keys():
			var unit_id := String(unit_id_value)
			var count = max(0, int(value.get(unit_id_value, 0)))
			if unit_id == "" or count <= 0:
				continue
			normalized[unit_id] = count
	return normalized

static func _normalize_delivery_completion_counts(value: Variant) -> Dictionary:
	var normalized := {}
	if value is Dictionary:
		for receipt_key_value in value.keys():
			var receipt_key := String(receipt_key_value).strip_edges()
			var count: int = max(0, int(value.get(receipt_key_value, 0)))
			if receipt_key == "" or count <= 0:
				continue
			normalized[receipt_key] = count
	return normalized

static func _recruit_payload_total(value: Variant) -> int:
	var total := 0
	if value is Dictionary:
		for unit_id_value in value.keys():
			total += max(0, int(value.get(unit_id_value, 0)))
	return total

static func _describe_resource_delta(delta: Variant) -> String:
	if not (delta is Dictionary):
		return ""
	var parts := []
	for key in _resource_keys_for_payload(delta):
		var amount := int(delta.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	return ", ".join(parts)

static func _describe_reward_delta(delta: Variant) -> String:
	if not (delta is Dictionary):
		return ""
	var parts := []
	var resource_summary := _describe_resource_delta(delta)
	if resource_summary != "":
		parts.append(resource_summary)
	var experience := int(delta.get("experience", 0))
	if experience > 0:
		parts.append("%d xp" % experience)
	for key in delta.keys():
		var resource_key := String(key)
		if resource_key in ["gold", "wood", "ore", "experience"]:
			continue
		var amount := int(delta.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, resource_key])
	return ", ".join(parts)

static func _describe_recruit_delta(delta: Variant) -> String:
	if not (delta is Dictionary):
		return ""
	var parts := []
	var unit_ids := []
	for unit_id_value in delta.keys():
		unit_ids.append(String(unit_id_value))
	unit_ids.sort()
	for unit_id in unit_ids:
		var amount := int(delta.get(unit_id, 0))
		if amount <= 0:
			continue
		var unit := ContentService.get_unit(unit_id)
		parts.append("+%d %s" % [amount, String(unit.get("name", unit_id))])
	return ", ".join(parts)

static func _describe_recruit_projection(current: Variant, projected: Variant) -> String:
	return HumanEngine.native(&"OverworldRules._describe_recruit_projection", [current, projected])

static func _describe_signed_int(value: int) -> String:
	return HumanEngine.native(&"OverworldRules._describe_signed_int", [value])

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "town": {}}
	var towns = session.overworld.get("towns", [])
	var session_id := String(session.session_id)
	if String(session.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, "")) == placement_id and _active_town_visit_indexes.has(session_id):
		var direct_index := int(_active_town_visit_indexes.get(session_id, -1))
		if towns is Array and direct_index >= 0 and direct_index < towns.size():
			var direct_town = towns[direct_index]
			if direct_town is Dictionary and String(direct_town.get("placement_id", "")) == placement_id:
				_pathing_debug_profile["town_placement_lookup_direct_index_count"] = int(_pathing_debug_profile.get("town_placement_lookup_direct_index_count", 0)) + 1
				return {"index": direct_index, "town": direct_town}
	var lookup_index := _spatial_lookup_index(session)
	var town_by_placement: Dictionary = lookup_index.get("town_by_placement", {}) if lookup_index.get("town_by_placement", {}) is Dictionary else {}
	if town_by_placement.has(placement_id):
		var placement_index := int(town_by_placement.get(placement_id, -1))
		if towns is Array and placement_index >= 0 and placement_index < towns.size():
			var indexed_town = towns[placement_index]
			if indexed_town is Dictionary and String(indexed_town.get("placement_id", "")) == placement_id:
				_pathing_debug_profile["town_placement_lookup_spatial_index_count"] = int(_pathing_debug_profile.get("town_placement_lookup_spatial_index_count", 0)) + 1
				return {"index": placement_index, "town": indexed_town}
	_pathing_debug_profile["town_placement_lookup_full_scan_count"] = int(_pathing_debug_profile.get("town_placement_lookup_full_scan_count", 0)) + 1
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			if String(session.flags.get(ACTIVE_TOWN_PLACEMENT_KEY, "")) == placement_id:
				_active_town_visit_indexes[session_id] = index
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _find_encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "encounter": {}}
	var lookup_started_usec := _rules_profile_timer()
	var encounters = session.overworld.get("encounters", [])
	_rules_profile_set("descriptor", "lookup_collection_size", encounters.size() if encounters is Array else 0)
	var lookup_index := _spatial_lookup_index(session)
	var by_placement: Dictionary = lookup_index.get("encounter_by_placement", {}) if lookup_index.get("encounter_by_placement", {}) is Dictionary else {}
	if by_placement.has(placement_id):
		var indexed := int(by_placement.get(placement_id, -1))
		if encounters is Array and indexed >= 0 and indexed < encounters.size():
			var indexed_encounter = encounters[indexed]
			if indexed_encounter is Dictionary and String(indexed_encounter.get("placement_id", indexed_encounter.get("id", ""))) == placement_id:
				_rules_profile_set("descriptor", "lookup_mode", "placement_index")
				_rules_profile_add_ms("descriptor_lookup_ms", lookup_started_usec)
				return {"index": indexed, "encounter": indexed_encounter}
	_rules_profile_set("descriptor", "lookup_mode", "full_scan_fallback")
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			_rules_profile_add_ms("descriptor_lookup_ms", lookup_started_usec)
			return {"index": index, "encounter": encounter}
	_rules_profile_add_ms("descriptor_lookup_ms", lookup_started_usec)
	return {"index": -1, "encounter": {}}

static func _advance_all_town_occupations(session: SessionStateStoreScript.SessionData) -> Array:
	var messages := []
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		var result := _advance_town_occupation(session, town)
		town = result.get("town", town)
		towns[index] = town
		var message := String(result.get("message", ""))
		if message != "":
			messages.append(message)
	session.overworld["towns"] = towns
	return messages

static func _advance_town_occupation(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var occupation := _normalize_town_occupation_state(town.get("occupation", {}))
	if String(town.get("owner", "neutral")) != "player":
		town["occupation"] = _normalize_town_occupation_state({})
		return {"town": town, "message": ""}
	if String(occupation.get("state", "")) != "pacifying" or int(occupation.get("pressure", 0)) <= 0:
		town["occupation"] = occupation
		return {"town": town, "message": ""}
	var occupation_state: Dictionary = _town_occupation_state(session, town)
	var relief_per_day: int = max(1, int(occupation_state.get("relief_per_day", 1)))
	var pressure: int = max(0, int(occupation.get("pressure", 0)))
	var relieved: int = min(pressure, relief_per_day)
	occupation["pressure"] = max(0, pressure - relieved)
	occupation["last_event_day"] = session.day if session != null else int(occupation.get("last_event_day", 0))
	town["occupation"] = occupation
	if int(occupation.get("pressure", 0)) <= 0:
		var locked_headcount := _recruit_payload_total(occupation.get("locked_recruits", {}))
		town = _release_town_occupation_reserves(town)
		var release_clause := ""
		if locked_headcount > 0:
			release_clause = " %d held levy%s now answer the banner." % [
				locked_headcount,
				"y" if locked_headcount == 1 else "ies",
			]
		return {
			"town": town,
			"message": "%s pacifies into secure control.%s" % [_town_name(town), release_clause],
		}
	return {
		"town": town,
		"message": "%s pacification sheds %d unrest." % [_town_name(town), relieved],
	}

static func _advance_all_town_recovery(session: SessionStateStoreScript.SessionData) -> Array:
	var messages := []
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		var result := _advance_town_recovery(session, town)
		town = result.get("town", town)
		towns[index] = town
		var message := String(result.get("message", ""))
		if message != "":
			messages.append(message)
	session.overworld["towns"] = towns
	return messages

static func _advance_town_recovery(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	var recovery := _normalize_town_recovery_state(town.get("recovery", {}))
	var pressure := int(recovery.get("pressure", 0))
	if pressure <= 0:
		town["recovery"] = recovery
		return {"town": town, "message": ""}
	var recovery_state := _town_recovery_state(session, town)
	var relief_per_day = max(1, int(recovery_state.get("relief_per_day", 1)))
	var relieved = min(pressure, relief_per_day)
	recovery["pressure"] = max(0, pressure - relieved)
	if int(recovery.get("pressure", 0)) <= 0:
		recovery["source"] = ""
	town["recovery"] = recovery
	if String(town.get("owner", "neutral")) != "player":
		return {"town": town, "message": ""}
	if int(recovery.get("pressure", 0)) <= 0:
		return {"town": town, "message": "%s stabilize." % _town_name(town)}
	return {
		"town": town,
		"message": "%s shed %d recovery pressure." % [_town_name(town), relieved],
	}

static func _town_defense_summary(town: Dictionary) -> String:
	var garrison_strength := 0
	for stack in town.get("garrison", []):
		if not (stack is Dictionary):
			continue
		var unit := ContentService.get_unit(String(stack.get("unit_id", "")))
		var count = max(0, int(stack.get("count", 0)))
		garrison_strength += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	if garrison_strength <= 0:
		return ""
	if garrison_strength >= 260:
		return "fortified walls"
	if garrison_strength >= 140:
		return "steady watch"
	return "thin watch"

static func _sync_movement_to_hero(session: SessionStateStoreScript.SessionData, previous_max: int) -> void:
	var movement_state = session.overworld.get("movement", {})
	if not (movement_state is Dictionary):
		movement_state = {}
	var new_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var current := int(movement_state.get("current", new_max))
	current = clamp(current + (new_max - previous_max), 0, new_max)
	movement_state["current"] = current
	movement_state["max"] = new_max
	session.overworld["movement"] = movement_state

static func _sync_spellbook_to_hero(session: SessionStateStoreScript.SessionData, previous_max: int) -> void:
	HumanEngine.native_writing(&"OverworldRules._sync_spellbook_to_hero", [session, previous_max])

static func _apply_artifact_claim(
	session: SessionStateStoreScript.SessionData,
	artifact_id: String,
	source_verb: String,
	auto_equip: bool
) -> Dictionary:
	normalize_overworld_state(session)
	var previous_max := _movement_max_from_hero(session.overworld.get("hero", {}), session)
	var result := ArtifactRulesScript.claim_artifact(
		session.overworld.get("hero", {}),
		artifact_id,
		source_verb,
		auto_equip
	)
	if not bool(result.get("ok", false)):
		return result

	session.overworld["hero"] = result.get("hero", session.overworld.get("hero", {}))
	_sync_movement_to_hero(session, previous_max)
	return result

static func claim_artifact_for_session(
	session: SessionStateStoreScript.SessionData,
	artifact_id: String,
	source_verb: String,
	auto_equip: bool = true
) -> Dictionary:
	return _apply_artifact_claim(session, artifact_id, source_verb, auto_equip)

static func _claim_town(session: SessionStateStoreScript.SessionData, town_result: Dictionary) -> String:
	var town = town_result.get("town", {})
	if int(town_result.get("index", -1)) < 0 or town.is_empty():
		return ""
	var transition := transition_town_control(
		session,
		String(town.get("placement_id", "")),
		"player",
		"",
		"captured town"
	)
	town = transition.get("town", town)
	town["recovery"] = _normalize_town_recovery_state(town.get("recovery", {}))
	town["occupation"] = _normalize_town_occupation_state(town.get("occupation", {}))
	var towns = session.overworld.get("towns", [])
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns
	return "Captured %s." % _town_name(town)

static func _town_garrison_company_count(town: Dictionary) -> int:
	var companies := 0
	for stack in town.get("garrison", []):
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			companies += 1
	return companies

static func _town_garrison_headcount(town: Dictionary) -> int:
	var headcount := 0
	for stack in town.get("garrison", []):
		if stack is Dictionary:
			headcount += max(0, int(stack.get("count", 0)))
	return headcount

static func _town_requires_assault(town: Dictionary) -> bool:
	return HumanEngine.native(&"OverworldRules._town_requires_assault", [town])

static func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i, level: int = -1) -> void:
	HumanEngine.native_writing(&"OverworldRules._set_active_hero_position", [session, tile, level])

static func _normalize_route_tiles(route_tiles: Variant) -> Array:
	var tiles := []
	if not (route_tiles is Array):
		return tiles
	for tile_value in route_tiles:
		var tile := _route_tile_from_variant(tile_value)
		if tile.x < 0 or tile.y < 0:
			continue
		tiles.append(tile)
	return tiles

static func _route_tile_from_variant(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	return Vector2i(-1, -1)

static func _route_tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

static func _route_tile_payloads(tiles: Array) -> Array:
	var payloads := []
	for tile_value in tiles:
		var tile := _route_tile_from_variant(tile_value)
		if tile.x < 0 or tile.y < 0:
			continue
		payloads.append(_route_tile_payload(tile))
	return payloads

static func _normalize_fog_of_war(session: SessionStateStoreScript.SessionData) -> void:
	DayEngine.native_writing(&"OverworldRules._normalize_fog_of_war", [session])

static func _reveal_current_fog_sources(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	if OverworldLevelRulesScript.level_count(session) > 1:
		_normalize_fog_of_war(session)
		return
	if not _fog_state_ready(session):
		_normalize_fog_of_war(session)
		return
	var map_size := derive_map_size(session)
	var fog: Dictionary = session.overworld.get(FOG_KEY, {})
	var explored_tiles := _normalize_visibility_grid(fog.get(EXPLORED_TILES_KEY, []), map_size)
	_reveal_all_current_fog_sources(session, explored_tiles, map_size)
	session.overworld[FOG_KEY] = _build_fog_payload(_duplicate_visibility_grid(explored_tiles), explored_tiles, map_size)

static func _reveal_all_current_fog_sources(session: SessionStateStoreScript.SessionData, explored_tiles: Array, map_size: Vector2i, level: int = -1) -> void:
	level = OverworldLevelRulesScript.query_level(session, level)
	var source_count := 0
	var heroes = session.overworld.get("player_heroes", [])
	if heroes is Array:
		for hero in heroes:
			if hero is Dictionary and OverworldLevelRulesScript.on_level(hero, level):
				source_count += 1
				_apply_hero_reveal(explored_tiles, hero, map_size)
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "player" or not OverworldLevelRulesScript.on_level(town, level):
			continue
		source_count += 1
		_apply_site_reveal(explored_tiles, OverworldLevelRulesScript.town_entrance(town), TOWN_VISION_RADIUS, map_size)
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or not OverworldLevelRulesScript.on_level(node, level):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site):
			continue
		if String(node.get("collected_by_faction_id", "")) != "player":
			continue
		source_count += 1
		_apply_site_reveal(explored_tiles, node, held_site_vision_radius(site), map_size)
	_rules_profile_set("fog", "source_count", source_count)

static func _fog_state_ready(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null:
		return false
	var fog = session.overworld.get(FOG_KEY, {})
	if not (fog is Dictionary):
		return false
	if int(fog.get("active_level", 0)) != hero_level(session):
		return false
	var visible_tiles = fog.get(VISIBLE_TILES_KEY, [])
	var explored_tiles = fog.get(EXPLORED_TILES_KEY, [])
	var map_size := derive_map_size(session)
	return (
		visible_tiles is Array
		and explored_tiles is Array
		and visible_tiles.size() == map_size.y
		and explored_tiles.size() == map_size.y
	)

static func _build_fog_payload(visible_tiles: Array, explored_tiles: Array, map_size: Vector2i) -> Dictionary:
	var count_started_usec := _rules_profile_timer()
	var explored_count := _count_grid(explored_tiles)
	var visible_count := explored_count if is_same(visible_tiles, explored_tiles) else _count_grid(visible_tiles)
	_rules_profile_add_ms("fog_count_grid_ms", count_started_usec)
	return {
		VISIBLE_TILES_KEY: visible_tiles,
		EXPLORED_TILES_KEY: explored_tiles,
		"visible_count": visible_count,
		"explored_count": explored_count,
		"total_tiles": max(map_size.x, 0) * max(map_size.y, 0),
	}

static func _normalize_visibility_grid(value: Variant, map_size: Vector2i) -> Array:
	var normalized := _blank_visibility_grid(map_size)
	if not (value is Array):
		return normalized
	for y in range(min(value.size(), map_size.y)):
		var row = value[y]
		if not (row is Array):
			continue
		for x in range(min(row.size(), map_size.x)):
			normalized[y][x] = bool(row[x])
	return normalized

static func _merge_visibility_grids(base: Array, overlay: Array, map_size: Vector2i) -> Array:
	for y in range(max(map_size.y, 0)):
		var base_row = base[y] if y >= 0 and y < base.size() else []
		var overlay_row = overlay[y] if y >= 0 and y < overlay.size() else []
		if not (base_row is Array) or not (overlay_row is Array):
			continue
		for x in range(max(map_size.x, 0)):
			if x < overlay_row.size() and bool(overlay_row[x]):
				base_row[x] = true
		base[y] = base_row
	return base

static func _duplicate_visibility_grid(grid: Array) -> Array:
	var duplicate_grid := []
	for row_value in grid:
		if row_value is Array:
			duplicate_grid.append(row_value.duplicate())
		else:
			duplicate_grid.append([])
	return duplicate_grid

static func _blank_visibility_grid(map_size: Vector2i, fill_value: bool = false) -> Array:
	var grid := []
	for y in range(max(map_size.y, 0)):
		var row := []
		for x in range(max(map_size.x, 0)):
			row.append(fill_value)
		grid.append(row)
	return grid

static func _apply_hero_reveal(explored_tiles: Array, hero: Dictionary, map_size: Vector2i) -> void:
	var position = hero.get("position", {})
	var position_dict = position if position is Dictionary else {}
	var origin := Vector2i(int(position_dict.get("x", 0)), int(position_dict.get("y", 0)))
	var radius := HeroCommandRulesScript.scouting_radius_for_hero(hero)
	_apply_site_reveal(explored_tiles, {"x": origin.x, "y": origin.y}, radius, map_size)

static func _apply_site_reveal(explored_tiles: Array, site_state: Dictionary, radius: int, map_size: Vector2i) -> void:
	if radius <= 0:
		return
	var origin := Vector2i(int(site_state.get("x", 0)), int(site_state.get("y", 0)))
	for y in range(max(0, origin.y - radius), min(map_size.y - 1, origin.y + radius) + 1):
		var half_width := HeroCommandRulesScript.scout_row_half_width(y - origin.y, radius)
		for x in range(max(0, origin.x - half_width), min(map_size.x - 1, origin.x + half_width) + 1):
			_set_grid_cell(explored_tiles, x, y, true)

static func _grid_cell(grid: Variant, x: int, y: int) -> bool:
	if not (grid is Array) or y < 0 or y >= grid.size():
		return false
	var row = grid[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return false
	return bool(row[x])

static func _set_grid_cell(grid: Array, x: int, y: int, value: bool) -> void:
	if y < 0 or y >= grid.size():
		return
	var row = grid[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return
	row[x] = value
	grid[y] = row

static func _count_grid(grid: Variant) -> int:
	if not (grid is Array):
		return 0
	var count := 0
	for row in grid:
		if not (row is Array):
			continue
		for value in row:
			if bool(value):
				count += 1
	return count

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

static func _normalize_command_briefing(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.scenario_id == "":
		return
	var briefing_state = session.overworld.get(COMMAND_BRIEFING_KEY, {})
	var had_state := briefing_state is Dictionary
	if not had_state:
		briefing_state = {}
	var signature := "%s|%s" % [session.scenario_id, SessionStateStoreScript.normalize_launch_mode(session.launch_mode)]
	if String(briefing_state.get("signature", "")) != signature:
		briefing_state = {
			"signature": signature,
			"shown": false,
			"shown_day": 0,
		}
	else:
		briefing_state["signature"] = signature
		briefing_state["shown"] = bool(briefing_state.get("shown", false))
		briefing_state["shown_day"] = max(0, int(briefing_state.get("shown_day", 0)))
	if not bool(briefing_state.get("shown", false)) and (session.day > 1 or String(session.flags.get("last_action", "")) != ""):
		briefing_state["shown"] = true
		briefing_state["shown_day"] = max(1, session.day)
	session.overworld[COMMAND_BRIEFING_KEY] = briefing_state

static func _normalize_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.scenario_id == "":
		return
	var forecast_state = session.overworld.get(COMMAND_RISK_FORECAST_KEY, {})
	if not (forecast_state is Dictionary):
		forecast_state = {}
	var forecast := _command_risk_forecast(session)
	var signature := String(forecast.get("signature", ""))
	if signature == "":
		forecast_state = {
			"signature": "",
			"shown": true,
			"shown_day": session.day,
		}
	elif String(forecast_state.get("signature", "")) != signature:
		forecast_state = {
			"signature": signature,
			"shown": false,
			"shown_day": 0,
		}
	else:
		forecast_state = {
			"signature": signature,
			"shown": bool(forecast_state.get("shown", false)),
			"shown_day": max(0, int(forecast_state.get("shown_day", 0))),
		}
	session.overworld[COMMAND_RISK_FORECAST_KEY] = forecast_state

static func _should_surface_command_briefing(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or session.scenario_id == "":
		return false
	if session.scenario_status != "in_progress" or String(session.game_state) != "overworld":
		return false
	if session.day != 1 or String(session.flags.get("last_action", "")) != "":
		return false
	var briefing_state = session.overworld.get(COMMAND_BRIEFING_KEY, {})
	return briefing_state is Dictionary and not bool(briefing_state.get("shown", false))

static func _should_surface_command_risk_forecast(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or session.scenario_id == "":
		return false
	if session.scenario_status != "in_progress" or String(session.game_state) != "overworld":
		return false
	var forecast := _command_risk_forecast(session)
	if not bool(forecast.get("gate_end_turn", false)):
		return false
	var forecast_state = session.overworld.get(COMMAND_RISK_FORECAST_KEY, {})
	return forecast_state is Dictionary and not bool(forecast_state.get("shown", false))

static func _command_briefing_lines(session: SessionStateStoreScript.SessionData) -> Array:
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	var lines := []
	var posture_line := _command_briefing_posture_line(session)
	if posture_line != "":
		lines.append(posture_line)
	if not scenario.is_empty():
		var objective_summary: String = _scenario_opening_objective_summary(session, scenario)
		if objective_summary != "":
			lines.append_array(objective_summary.split("\n"))
	var logistics_line := _command_briefing_logistics_line(session)
	if logistics_line != "":
		lines.append(logistics_line)
	var pressure_line := _command_briefing_pressure_line(session, scenario)
	if pressure_line != "":
		lines.append(pressure_line)
	var orders_line := _command_briefing_orders_line(session, scenario)
	if orders_line != "":
		lines.append(orders_line)
	return lines

static func _command_briefing_posture_line(session: SessionStateStoreScript.SessionData) -> String:
	var hero = session.overworld.get("hero", {})
	if hero.is_empty():
		return ""
	var pos := hero_position(session)
	var terrain := _terrain_name_at(session, pos.x, pos.y)
	var movement = session.overworld.get("movement", {})
	var mana = hero.get("spellbook", {}).get("mana", {})
	var army_totals := _army_totals(hero.get("army", {}))
	return "Command posture: %s deploys on %s at %d,%d | Move %d/%d | Scout %d | Mana %d/%d | %d troops in %d groups" % [
		String(hero.get("name", "Hero")),
		terrain,
		pos.x,
		pos.y,
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		HeroCommandRulesScript.scouting_radius_for_hero(hero),
		int(mana.get("current", 0)),
		int(mana.get("max", 0)),
		int(army_totals.get("headcount", 0)),
		int(army_totals.get("groups", 0)),
	]

static func _command_briefing_logistics_line(session: SessionStateStoreScript.SessionData) -> String:
	var pos := hero_position(session)
	var town_result := _nearest_town_for_controller(session, "player", pos.x, pos.y)
	var site_plan := _nearest_logistics_plan(session)
	if int(town_result.get("index", -1)) < 0:
		if site_plan.is_empty():
			return "Logistics watch: No owned town anchors the front yet. Early site claims will define your first supply line."
		return "Logistics watch: No owned town anchors the front yet. %s" % String(site_plan.get("summary", ""))
	var town = town_result.get("town", {})
	var distance = abs(pos.x - int(town.get("x", 0))) + abs(pos.y - int(town.get("y", 0)))
	var logistics := town_logistics_state(session, town)
	var parts := [
		"%s %d tile%s away" % [_town_name(town), distance, "" if distance == 1 else "s"],
		String(logistics.get("summary", "")),
	]
	if int(logistics.get("disrupted_count", 0)) > 0 and logistics.get("disrupted_site_labels", []) is Array and not logistics.get("disrupted_site_labels", []).is_empty():
		parts.append("Denied: %s" % ", ".join(logistics.get("disrupted_site_labels", []).slice(0, min(2, logistics.get("disrupted_site_labels", []).size()))))
	elif int(logistics.get("threatened_count", 0)) > 0 and logistics.get("threatened_site_labels", []) is Array and not logistics.get("threatened_site_labels", []).is_empty():
		parts.append("Threatened: %s" % ", ".join(logistics.get("threatened_site_labels", []).slice(0, min(2, logistics.get("threatened_site_labels", []).size()))))
	elif logistics.get("missing_family_labels", []) is Array and not logistics.get("missing_family_labels", []).is_empty():
		parts.append("Missing: %s" % ", ".join(logistics.get("missing_family_labels", []).slice(0, min(2, logistics.get("missing_family_labels", []).size()))))
	if not site_plan.is_empty():
		parts.append(String(site_plan.get("summary", "")))
	return "Logistics watch: %s" % " | ".join(parts)

static func _command_briefing_pressure_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var local_summary := _local_visible_threat_summary(session, "")
	if local_summary != "":
		return "Pressure watch: %s" % local_summary
	if scenario.is_empty():
		return "Pressure watch: No hostile lane is confirmed yet. Push scouts forward before rival heroes take the field."
	var operational_lines: Array = _scenario_enemy_operational_lines(session, scenario)
	if not operational_lines.is_empty():
		var line := String(operational_lines[0])
		if line.begins_with("Enemy posture: "):
			return "Pressure watch: %s" % line.trim_prefix("Enemy posture: ")
		return "Pressure watch: %s" % line
	return "Pressure watch: No hostile lane is confirmed yet. Push scouts forward before rival heroes take the field."

static func _command_briefing_orders_line(session: SessionStateStoreScript.SessionData, scenario: Dictionary) -> String:
	var context_actions := get_context_actions(session)
	if not context_actions.is_empty():
		return "Immediate orders: %s" % _context_action_briefing(session, context_actions[0], get_active_context(session))
	var site_plan := _nearest_logistics_plan(session)
	if not site_plan.is_empty():
		return "Immediate orders: %s" % String(site_plan.get("order", "Advance to stabilize the nearest logistics lane."))
	var encounter_plan := _nearest_visible_encounter_plan(session)
	if not encounter_plan.is_empty():
		return "Immediate orders: %s" % String(encounter_plan.get("order", "Advance on the nearest hostile contact."))
	if not scenario.is_empty():
		var first_contact: String = _scenario_first_contact_summary(scenario)
		if first_contact != "":
			var contact_lines := first_contact.split("\n")
			if not contact_lines.is_empty():
				return "Immediate orders: %s" % String(contact_lines[0]).trim_prefix("Likely first contact: ")
	var objectives = _scenario_rules().objectives_for_session(session)
	if objectives is Dictionary:
		var victory_labels: Array = _scenario_objective_labels_from_bucket(session, objectives.get("victory", []), 1)
		if not victory_labels.is_empty():
			return "Immediate orders: Advance on %s while the front is still forming." % String(victory_labels[0])
	return "Immediate orders: Expand the scout ring, secure the nearest lane, and shape the first contact on favorable ground."

static func _context_action_briefing(session: SessionStateStoreScript.SessionData, action: Variant, context: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._context_action_briefing", [session, action, context])

static func _encounter_pressure_summary(session: SessionStateStoreScript.SessionData, encounter: Dictionary, for_battle_prompt: bool = false) -> String:
	return HumanEngine.native_writing(&"OverworldRules._encounter_pressure_summary", [session, encounter, for_battle_prompt])

static func _command_commitment_action_line(session: SessionStateStoreScript.SessionData) -> String:
	var context_actions := get_context_actions(session)
	if not context_actions.is_empty():
		var action = context_actions[0]
		if action is Dictionary:
			return _command_commitment_action_summary(session, action)
	var site_plan := _nearest_logistics_plan(session)
	if not site_plan.is_empty():
		return String(site_plan.get("order", "Advance to stabilize the nearest logistics lane."))
	var encounter_plan := _nearest_visible_encounter_plan(session)
	if not encounter_plan.is_empty():
		return String(encounter_plan.get("order", "Advance on the nearest hostile contact."))
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	var objectives = _scenario_rules().objectives_for_session(session)
	if objectives is Dictionary:
		var victory_labels: Array = _scenario_objective_labels_from_bucket(session, objectives.get("victory", []), 1)
		if not victory_labels.is_empty():
			return "Advance on %s while the front is still forming." % String(victory_labels[0])
	return "Expand the scout ring, secure the nearest lane, and shape the first contact on favorable ground."

static func _command_commitment_action_summary(session: SessionStateStoreScript.SessionData, action: Dictionary) -> String:
	if action.has("summary"):
		return String(action.get("summary", ""))
	return _context_action_briefing(session, action, get_active_context(session))

static func _command_commitment_route_line(session: SessionStateStoreScript.SessionData) -> String:
	var context := get_active_context(session)
	match String(context.get("type", "empty")):
		"town":
			var town = context.get("town", {})
			if String(town.get("owner", "neutral")) == "player":
				var logistics := town_logistics_state(session, town)
				var recovery := town_recovery_state(session, town)
				var parts := [
					"%s anchors this lane" % _town_name(town),
					"Readiness %d" % town_battle_readiness(town, session),
				]
				if String(logistics.get("summary", "")) != "":
					parts.append(String(logistics.get("summary", "")))
				if bool(recovery.get("active", false)):
					parts.append(String(recovery.get("summary", "")))
				return " | ".join(parts)
			return "%s is still off the banner line. Claiming it secures a local foothold and unlocks town command options." % _town_name(town)
		"resource":
			var node = context.get("node", {})
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			var site_name := String(site.get("name", "Frontier site"))
			var response_state := _resource_site_response_state(session, node, site)
			var linked_town_result := _resource_node_linked_town(session, node, "player")
			var linked_town = linked_town_result.get("town", {})
			var linked_clause := ""
			if not linked_town.is_empty():
				linked_clause = " | Linked %s" % _town_name(linked_town)
			if bool(response_state.get("active", false)):
				var response_line := "%s escorted for %d day%s" % [
					site_name,
					int(response_state.get("remaining_days", 0)),
					"" if int(response_state.get("remaining_days", 0)) == 1 else "s",
				]
				if String(response_state.get("commander_name", "")) != "":
					response_line += " | %s detached" % String(response_state.get("commander_name", ""))
				var impact_summary := _resource_site_response_effect_summary(response_state)
				if impact_summary != "":
					response_line += " | %s" % impact_summary
				return response_line + linked_clause
			if _resource_site_is_persistent(site):
				if String(node.get("collected_by_faction_id", "")) == "player" and _resource_site_under_threat(session, node, "player"):
					return "%s is under threat%s. Leaving the lane loose risks losing the route bonus." % [site_name, linked_clause]
				return "%s can %s%s." % [site_name, _resource_site_opening_value(site), linked_clause]
			return "%s remains claimable on the active lane." % site_name
		"encounter":
			var encounter = context.get("encounter", {})
			return "%s blocks the active march line. Leaving it intact keeps hostile pressure on this route." % (
				encounter_display_name(encounter)
			)
		"artifact":
			var artifact_node = context.get("node", {})
			return "%s lies exposed on the active lane. Recovering it adds %s to the current commander before the front tightens." % [
				ArtifactRulesScript.artifact_name(String(artifact_node.get("artifact_id", ""))),
				ArtifactRulesScript.describe_artifact_short(String(artifact_node.get("artifact_id", ""))),
			]
	var site_plan := _nearest_logistics_plan(session)
	if not site_plan.is_empty():
		return String(site_plan.get("summary", "The nearest logistics lane needs attention."))
	var local_pressure := _local_visible_threat_summary(session, "")
	if local_pressure != "":
		return local_pressure
	var management_watch := describe_management_watch(session)
	if management_watch != "":
		return management_watch
	return "No visible hostile pressure is crowding the current route."

static func _command_commitment_coverage_line(session: SessionStateStoreScript.SessionData) -> String:
	var parts := []
	var movement = session.overworld.get("movement", {})
	parts.append("Move %d/%d" % [int(movement.get("current", 0)), int(movement.get("max", 0))])
	var reserve_support := _nearest_reserve_hero_support(session)
	if reserve_support.is_empty():
		parts.append("No reserve commander covers the active lane")
	else:
		var reserve_distance := int(reserve_support.get("distance", 0))
		var reserve_name := String(reserve_support.get("name", "Reserve commander"))
		if reserve_distance <= 0:
			parts.append("Reserve %s is already on this tile" % reserve_name)
		else:
			parts.append("Reserve %s %d tile%s %s" % [
				reserve_name,
				reserve_distance,
				"" if reserve_distance == 1 else "s",
				String(reserve_support.get("direction", "away")),
			])
	var pos := hero_position(session)
	var nearest_town_result := _nearest_town_for_controller(session, "player", pos.x, pos.y)
	if int(nearest_town_result.get("index", -1)) >= 0:
		var town = nearest_town_result.get("town", {})
		var distance = abs(pos.x - int(town.get("x", 0))) + abs(pos.y - int(town.get("y", 0)))
		if distance <= 0:
			parts.append("%s anchors this tile" % _town_name(town))
		else:
			parts.append("%s %d tile%s %s" % [
				_town_name(town),
				distance,
				"" if distance == 1 else "s",
				_direction_from_to(pos, Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))),
			])
	else:
		parts.append("No owned town anchors the current march line")
	return " | ".join(parts)

static func _command_commitment_hold_line(session: SessionStateStoreScript.SessionData) -> String:
	var forecast := _command_risk_forecast(session)
	return _command_commitment_hold_line_from_forecast(session, forecast)

static func _command_commitment_hold_line_from_watch_context(
	session: SessionStateStoreScript.SessionData,
	refresh_watch_context: Dictionary
) -> String:
	var forecast_value = refresh_watch_context.get("command_risk_forecast", {})
	var forecast: Dictionary = forecast_value if forecast_value is Dictionary else {}
	return _command_commitment_hold_line_from_forecast(session, forecast)

static func _command_commitment_hold_line_from_forecast(
	session: SessionStateStoreScript.SessionData,
	forecast: Dictionary
) -> String:
	if bool(forecast.get("has_risk", false)):
		var lines = forecast.get("lines", [])
		if lines is Array and lines.size() > 1:
			return String(lines[1]).trim_prefix("- ")
		return String(forecast.get("summary", "the frontier stays strained"))
	if not get_context_actions(session).is_empty():
		return "No concrete next-day break is signaled, but the current order window stays open only while this lane remains clear."
	return "No concrete next-day break is signaled from the current frontier watch."

static func _nearest_reserve_hero_support(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var best := {}
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		if String(hero.get("id", "")) == active_hero_id:
			continue
		var hero_pos = hero.get("position", {})
		var target := Vector2i(int(hero_pos.get("x", 0)), int(hero_pos.get("y", 0)))
		var distance = abs(pos.x - target.x) + abs(pos.y - target.y)
		var candidate := {
			"id": String(hero.get("id", "")),
			"name": String(hero.get("name", "Reserve commander")),
			"distance": distance,
			"direction": _direction_from_to(pos, target),
		}
		if best.is_empty() or distance < int(best.get("distance", 9999)):
			best = candidate
	return best

static func _nearest_logistics_plan(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var best := {}
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or not OverworldLevelRulesScript.on_level(node, hero_level(session)):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not _resource_site_is_persistent(site):
			continue
		var x := int(node.get("x", -1))
		var y := int(node.get("y", -1))
		if not is_tile_visible(session, x, y):
			continue
		var controller := PlayerRules.resource_controller_id(node)
		var priority := 99
		var summary := ""
		var order := ""
		if controller == "player":
			if _resource_site_under_threat(session, node, "player"):
				var response_state := _resource_site_response_state(session, node, site)
				priority = 0
				summary = "%s is threatened %d tile%s %s" % [
					String(site.get("name", "Frontier site")),
					abs(pos.x - x) + abs(pos.y - y),
					"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
					_direction_from_to(pos, Vector2i(x, y)),
				]
				if bool(response_state.get("active", false)) and String(response_state.get("commander_name", "")) != "":
					summary += " | Escort by %s is being contested" % String(response_state.get("commander_name", ""))
				order = "March %d tile%s %s to secure %s before the escort line breaks." % [
					abs(pos.x - x) + abs(pos.y - y),
					"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
					_direction_from_to(pos, Vector2i(x, y)),
					String(site.get("name", "the route")),
				]
			else:
				var response_state := _resource_site_response_state(session, node, site)
				if int(response_state.get("watch_days", 0)) > 0 and not bool(response_state.get("active", false)):
					priority = 2
					summary = "%s is ready for %s %d tile%s %s" % [
						String(site.get("name", "Frontier site")),
						String(response_state.get("action_label", "route security")).to_lower(),
						abs(pos.x - x) + abs(pos.y - y),
						"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
						_direction_from_to(pos, Vector2i(x, y)),
					]
					order = "March %d tile%s %s and issue %s at %s." % [
						abs(pos.x - x) + abs(pos.y - y),
						"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
						_direction_from_to(pos, Vector2i(x, y)),
						String(response_state.get("action_label", "route security")),
						String(site.get("name", "the site")),
					]
		else:
			priority = 1
			summary = "%s lies %d tile%s %s and can %s" % [
				String(site.get("name", "Frontier site")),
				abs(pos.x - x) + abs(pos.y - y),
				"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
				_direction_from_to(pos, Vector2i(x, y)),
				_resource_site_opening_value(site),
			]
			order = "Claim %s %d tile%s %s to %s." % [
				String(site.get("name", "the frontier site")),
				abs(pos.x - x) + abs(pos.y - y),
				"" if abs(pos.x - x) + abs(pos.y - y) == 1 else "s",
				_direction_from_to(pos, Vector2i(x, y)),
				_resource_site_opening_value(site),
			]
		if priority >= 99:
			continue
		var candidate := {
			"priority": priority,
			"distance": abs(pos.x - x) + abs(pos.y - y),
			"summary": summary,
			"order": order,
		}
		if best.is_empty() or int(candidate.get("priority", 99)) < int(best.get("priority", 99)) or (
			int(candidate.get("priority", 99)) == int(best.get("priority", 99))
			and int(candidate.get("distance", 9999)) < int(best.get("distance", 9999))
		):
			best = candidate
	return best

static func _nearest_visible_encounter_plan(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var pos := hero_position(session)
	var best := {}
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or not OverworldLevelRulesScript.on_level(encounter, hero_level(session)) or is_encounter_resolved(session, encounter):
			continue
		var x := int(encounter.get("x", -1))
		var y := int(encounter.get("y", -1))
		if not is_tile_visible(session, x, y):
			continue
		var distance = abs(pos.x - x) + abs(pos.y - y)
		var candidate := {
			"distance": distance,
			"order": "Advance %d tile%s %s and prepare to engage %s on %s." % [
				distance,
				"" if distance == 1 else "s",
				_direction_from_to(pos, Vector2i(x, y)),
				encounter_display_name(encounter),
				_terrain_name_at(session, x, y),
			],
		}
		if best.is_empty() or int(candidate.get("distance", 9999)) < int(best.get("distance", 9999)):
			best = candidate
	return best

static func _resource_site_opening_value(site: Dictionary) -> String:
	return HumanEngine.native(&"OverworldRules._resource_site_opening_value", [site])

static func _direction_from_to(origin: Vector2i, target: Vector2i) -> String:
	var vertical := ""
	var horizontal := ""
	if target.y < origin.y:
		vertical = "north"
	elif target.y > origin.y:
		vertical = "south"
	if target.x < origin.x:
		horizontal = "west"
	elif target.x > origin.x:
		horizontal = "east"
	if vertical != "" and horizontal != "":
		return "%s-%s" % [vertical, horizontal]
	if vertical != "":
		return vertical
	if horizontal != "":
		return horizontal
	return "here"

static func _command_risk_forecast(session: SessionStateStoreScript.SessionData) -> Dictionary:
	_normalize_enemy_states(session)
	return _command_risk_forecast_from_normalized_session(session)

static func _command_risk_forecast_from_normalized_session(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var reduction := _reduce_command_risk_items(_command_risk_items(session))
	if not bool(reduction.get("has_risk", false)):
		return {
			"has_risk": false,
			"severity": 0,
			"summary": "",
			"lines": [],
			"signature": "",
			"gate_end_turn": false,
		}
	var selected_items: Array = reduction.get("selected_items", [])
	var summary_text := String(reduction.get("summary", ""))
	var lines := ["Next-day posture: %s" % summary_text]
	var signature_payload := {"day": session.day, "summary": summary_text, "details": []}
	for item in selected_items:
		var detail := String(item.get("detail", ""))
		if detail == "":
			continue
		lines.append("- %s" % detail)
		signature_payload["details"].append(detail)
	return {
		"has_risk": true,
		"severity": int(reduction.get("severity", 0)),
		"summary": summary_text,
		"lines": lines,
		"signature": JSON.stringify(signature_payload),
		"gate_end_turn": bool(reduction.get("gate_end_turn", false)),
	}

static func _reduce_command_risk_items(items: Array) -> Dictionary:
	if items.is_empty():
		return {
			"has_risk": false,
			"severity": 0,
			"summary": "",
			"selected_items": [],
			"gate_end_turn": false,
		}
	items.sort_custom(func(a, b):
		if int(a.get("severity", 0)) == int(b.get("severity", 0)):
			return String(a.get("key", "")) < String(b.get("key", ""))
		return int(a.get("severity", 0)) > int(b.get("severity", 0))
	)
	var selected_items := []
	for item in items:
		if not (item is Dictionary):
			continue
		selected_items.append(item)
		if selected_items.size() >= 3:
			break
	var severity := int(selected_items[0].get("severity", 0))
	var summary_parts := []
	var gate_end_turn := false
	for item in selected_items:
		var summary := String(item.get("summary", ""))
		if summary != "" and summary not in summary_parts:
			summary_parts.append(summary)
		gate_end_turn = gate_end_turn or bool(item.get("gate", false))
	var summary_text := "%s risk" % _command_risk_grade_label(severity)
	if not summary_parts.is_empty():
		summary_text = "%s | %s" % [summary_text, " | ".join(summary_parts)]
	return {
		"has_risk": true,
		"severity": severity,
		"summary": summary_text,
		"selected_items": selected_items,
		"gate_end_turn": gate_end_turn or severity >= 3,
	}

static func _command_risk_items(session: SessionStateStoreScript.SessionData, include_details: bool = true) -> Array:
	var items := []
	var pressured_town_ids := {}
	var daybreak_contexts := _command_risk_player_town_daybreak_contexts(session)
	var town_items := _command_risk_town_items(session, daybreak_contexts, include_details)
	for item in town_items:
		items.append(item)
		var town_id := String(item.get("town_placement_id", ""))
		if town_id != "":
			pressured_town_ids[town_id] = true
	items.append_array(_command_risk_logistics_items(session, pressured_town_ids, daybreak_contexts, include_details))
	items.append_array(_command_risk_objective_items(session, pressured_town_ids, include_details))
	items.append_array(_command_risk_posture_items(session, include_details))
	var field_item := _command_risk_field_item(session, include_details)
	if not field_item.is_empty():
		items.append(field_item)
	return items

static func _command_risk_player_town_daybreak_contexts(session: SessionStateStoreScript.SessionData) -> Array:
	var contexts := []
	var towns = session.overworld.get("towns", [])
	if not (towns is Array):
		return contexts
	contexts.resize(towns.size())
	for town_index in range(towns.size()):
		var town = towns[town_index]
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			contexts[town_index] = {}
			continue
		contexts[town_index] = _project_player_town_at_daybreak(
			session,
			town,
			town_index,
			session.day + 1
		)
	return contexts

static func _command_risk_town_items(
	session: SessionStateStoreScript.SessionData,
	daybreak_contexts: Array,
	include_details: bool = true
) -> Array:
	var items := []
	var towns = session.overworld.get("towns", [])
	if not (towns is Array):
		return items
	for town_index in range(towns.size()):
		var town = towns[town_index]
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var threat_state := _town_command_risk_state(session, town, false)
		if int(threat_state.get("visible_pressuring", 0)) <= 0 and int(threat_state.get("visible_marching", 0)) <= 0 and not bool(threat_state.get("hidden_targeting", false)) and int(threat_state.get("siege_progress", 0)) <= 0:
			continue
		var projection: Dictionary = daybreak_contexts[town_index] if town_index < daybreak_contexts.size() and daybreak_contexts[town_index] is Dictionary else {}
		var projected_session: SessionStateStoreScript.SessionData = projection.get("session", session)
		var projected_town: Dictionary = projection.get("town", town)
		var development := town_development_metrics(projected_town, projected_session)
		var readiness := int(development.get("battle_readiness", 0))
		var defense := _town_defense_summary(projected_town)
		var logistics: Dictionary = development.get("logistics", {}) if development.get("logistics", {}) is Dictionary else {}
		var recovery: Dictionary = development.get("recovery", {}) if development.get("recovery", {}) is Dictionary else {}
		var capital_project: Dictionary = development.get("capital_project", {}) if development.get("capital_project", {}) is Dictionary else {}
		var objective_anchor: bool = _raid_target_is_objective_anchor(
			session,
			"town",
			String(town.get("placement_id", ""))
		)
		var severity := 2
		if int(threat_state.get("visible_pressuring", 0)) > 0 or int(threat_state.get("siege_progress", 0)) > 0:
			severity = 5
		elif int(threat_state.get("nearest_goal_distance", 9999)) <= 1:
			severity = 4
		elif int(threat_state.get("nearest_goal_distance", 9999)) <= 2 or bool(threat_state.get("hidden_targeting", false)):
			severity = 3
		if readiness <= 18 or defense == "thin watch":
			severity += 1
		if int(logistics.get("support_gap", 0)) > 0 or bool(recovery.get("active", false)) or bool(capital_project.get("vulnerable", false)):
			severity += 1
		if objective_anchor or town_strategic_role(projected_town) in ["capital", "stronghold"]:
			severity += 1
		severity = clampi(severity, 2, 5)
		var item := {
			"key": "town:%s" % String(town.get("placement_id", "")),
			"town_placement_id": String(town.get("placement_id", "")),
			"severity": severity,
			"gate": severity >= 3,
			"summary": "%s exposed" % _town_name(town),
		}
		if include_details:
			var threat_clauses := []
			if int(threat_state.get("visible_pressuring", 0)) > 0:
				threat_clauses.append("%d known enemy force%s already press the approaches" % [
					int(threat_state.get("visible_pressuring", 0)),
					"" if int(threat_state.get("visible_pressuring", 0)) == 1 else "s",
				])
			if int(threat_state.get("visible_marching", 0)) > 0:
				var days_to_contact = max(1, int(threat_state.get("nearest_goal_distance", 9999)))
				if days_to_contact <= 2:
					threat_clauses.append("%d known host%s can reach the town in %d day%s" % [
						int(threat_state.get("visible_marching", 0)),
						"" if int(threat_state.get("visible_marching", 0)) == 1 else "s",
						days_to_contact,
						"" if days_to_contact == 1 else "s",
					])
				else:
					threat_clauses.append("%d known host%s are marching on the lane" % [
						int(threat_state.get("visible_marching", 0)),
						"" if int(threat_state.get("visible_marching", 0)) == 1 else "s",
					])
			if bool(threat_state.get("hidden_targeting", false)):
				threat_clauses.append("scouts report hostile movement beyond the fog")
			if int(threat_state.get("siege_progress", 0)) > 0:
				threat_clauses.append("siege pressure %d/%d is already building" % [
					int(threat_state.get("siege_progress", 0)),
					max(1, int(threat_state.get("siege_capture_progress", 1))),
				])
			var front_parts := ["Readiness %d" % readiness]
			if defense != "":
				front_parts.append(defense)
			if String(logistics.get("summary", "")) != "" and (int(logistics.get("support_gap", 0)) > 0 or int(logistics.get("threatened_count", 0)) > 0 or int(logistics.get("disrupted_count", 0)) > 0):
				front_parts.append(String(logistics.get("summary", "")))
			if bool(recovery.get("active", false)):
				front_parts.append(String(recovery.get("summary", "")))
			if bool(capital_project.get("vulnerable", false)):
				front_parts.append("capital project vulnerable")
			if objective_anchor:
				front_parts.append("objective anchor")
			item["detail"] = "%s: %s | %s. %s" % [
				_town_name(town),
				"; ".join(threat_clauses),
				" | ".join(front_parts),
				_town_command_risk_consequence(projected_town, readiness, logistics, recovery, capital_project, objective_anchor),
			]
		items.append(item)
	return items

static func _command_risk_logistics_items(
	session: SessionStateStoreScript.SessionData,
	pressured_town_ids: Dictionary,
	daybreak_contexts: Array,
	include_details: bool = true
) -> Array:
	var items := []
	var towns = session.overworld.get("towns", [])
	if not (towns is Array):
		return items
	for town_index in range(towns.size()):
		var town = towns[town_index]
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var placement_id := String(town.get("placement_id", ""))
		if pressured_town_ids.has(placement_id):
			continue
		var projection: Dictionary = daybreak_contexts[town_index] if town_index < daybreak_contexts.size() and daybreak_contexts[town_index] is Dictionary else {}
		var projected_session: SessionStateStoreScript.SessionData = projection.get("session", session)
		var projected_town: Dictionary = projection.get("town", town)
		var logistics := _town_logistics_state(projected_session, projected_town)
		if int(logistics.get("disrupted_count", 0)) <= 0 and int(logistics.get("threatened_count", 0)) <= 0 and int(logistics.get("support_gap", 0)) <= 0:
			continue
		var recovery := _town_recovery_state(projected_session, projected_town, logistics)
		var capital_project := _town_capital_project_state(projected_town, projected_session, logistics, recovery)
		var severity_score := int(logistics.get("disrupted_count", 0)) * 2 + int(logistics.get("threatened_count", 0)) + int(logistics.get("support_gap", 0))
		if int(logistics.get("response_count", 0)) <= 0 and int(logistics.get("threatened_count", 0)) > 0:
			severity_score += 1
		if town_strategic_role(projected_town) in ["capital", "stronghold"]:
			severity_score += 1
		if bool(capital_project.get("vulnerable", false)):
			severity_score += 1
		var severity := 2
		if severity_score >= 6:
			severity = 5
		elif severity_score >= 4:
			severity = 4
		elif severity_score >= 2:
			severity = 3
		var item := {
			"key": "logistics:%s" % placement_id,
			"severity": severity,
			"gate": severity >= 4,
			"summary": "%s routes straining" % _town_name(town),
		}
		if include_details:
			var route_clause := ""
			if logistics.get("disrupted_site_labels", []) is Array and not logistics.get("disrupted_site_labels", []).is_empty():
				route_clause = "Denied routes %s" % ", ".join(logistics.get("disrupted_site_labels", []).slice(0, min(2, logistics.get("disrupted_site_labels", []).size())))
			elif logistics.get("threatened_site_labels", []) is Array and not logistics.get("threatened_site_labels", []).is_empty():
				route_clause = "Threatened routes %s" % ", ".join(logistics.get("threatened_site_labels", []).slice(0, min(2, logistics.get("threatened_site_labels", []).size())))
			elif logistics.get("missing_family_labels", []) is Array and not logistics.get("missing_family_labels", []).is_empty():
				route_clause = "Missing anchors %s" % ", ".join(logistics.get("missing_family_labels", []).slice(0, min(2, logistics.get("missing_family_labels", []).size())))
			var consequence_parts := []
			if int(logistics.get("gap_readiness_penalty", 0)) > 0:
				consequence_parts.append("readiness -%d" % int(logistics.get("gap_readiness_penalty", 0)))
			if int(logistics.get("gap_growth_penalty_percent", 0)) > 0:
				consequence_parts.append("recruits -%d%%" % int(logistics.get("gap_growth_penalty_percent", 0)))
			if int(logistics.get("gap_pressure_penalty", 0)) > 0:
				consequence_parts.append("%s -%d" % [_town_pressure_label(projected_town).to_lower(), int(logistics.get("gap_pressure_penalty", 0))])
			if bool(recovery.get("active", false)):
				consequence_parts.append("%d recovery pressure remains" % int(recovery.get("pressure", 0)))
			if bool(capital_project.get("vulnerable", false)) and String(capital_project.get("vulnerability_summary", "")) != "":
				consequence_parts.append(String(capital_project.get("vulnerability_summary", "")))
			item["detail"] = "%s logistics: %s%s. Next day holds %s." % [
				_town_name(town),
				String(logistics.get("summary", "")),
				" | %s" % route_clause if route_clause != "" else "",
				", ".join(consequence_parts) if not consequence_parts.is_empty() else "the same exposed chain unless new response orders go out",
			]
		items.append(item)
	return items

static func _command_risk_objective_items(session: SessionStateStoreScript.SessionData, pressured_town_ids: Dictionary, include_details: bool = true) -> Array:
	var items := []
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	var objectives = _scenario_rules().objectives_for_session(session)
	if not (objectives is Dictionary):
		return items
	for objective in objectives.get("defeat", []):
		if not (objective is Dictionary):
			continue
		match String(objective.get("type", "")):
			"enemy_pressure_at_least":
				var pressure_item := _command_risk_pressure_objective_item(session, scenario, objective, include_details)
				if not pressure_item.is_empty():
					items.append(pressure_item)
			"encounter_resolved":
				var encounter_item := _command_risk_encounter_objective_item(session, objective, include_details)
				if not encounter_item.is_empty():
					items.append(encounter_item)
			"town_not_owned_by_player", "town_owned_by_player":
				var placement_id := String(objective.get("placement_id", ""))
				if placement_id == "" or pressured_town_ids.has(placement_id):
					continue
				var town_result := _find_town_by_placement(session, placement_id)
				if int(town_result.get("index", -1)) < 0:
					continue
				var town = town_result.get("town", {})
				if String(town.get("owner", "neutral")) != "player":
					var item := {
						"key": "objective-town:%s" % placement_id,
						"severity": 5,
						"gate": true,
						"summary": "%s objective slipping" % _town_name(town),
					}
					if include_details:
						item["detail"] = "%s is already off the banner line, and the defeat watch %s remains live." % [
							_town_name(town),
							String(objective.get("label", objective.get("id", "objective"))),
						]
					items.append(item)
	return items

static func _command_risk_posture_items(session: SessionStateStoreScript.SessionData, include_details: bool = true) -> Array:
	var items := []
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	for config in scenario.get("enemy_factions", []):
		if not (config is Dictionary):
			continue
		var faction_id := String(config.get("faction_id", ""))
		var state := _enemy_state_for_faction(session, faction_id)
		var current_pressure := int(state.get("pressure", 0))
		var threshold: int = _enemy_raid_threshold_for_strategy(session, config, faction_id)
		var active_raids: int = _enemy_active_raids(session, faction_id)
		var max_raids: int = _enemy_max_active_raids_for_strategy(session, config, faction_id)
		var posture := String(state.get("posture", "probing"))
		if active_raids >= max_raids:
			continue
		if current_pressure < max(1, threshold - 1) and posture not in ["massing", "raiding"]:
			continue
		var label := String(config.get("label", ContentService.get_faction(faction_id).get("name", faction_id)))
		var severity := 2
		if posture == "raiding" or current_pressure >= threshold:
			severity = 4
		elif posture == "massing" or current_pressure + _public_enemy_pressure_gain(session, config) >= threshold:
			severity = 3
		var item := {
			"key": "posture:%s" % faction_id,
			"severity": severity,
			"gate": false,
			"summary": "%s is gathering strength" % label,
		}
		if include_details:
			item["detail"] = "%s sits at %d/%d pressure with %d/%d heroes in the field. %s posture makes another attack likely if the day ends without reducing pressure." % [
				label,
				current_pressure,
				threshold,
				active_raids,
				max_raids,
				_posture_label(posture),
			]
		items.append(item)
	return items

static func _command_risk_field_item(session: SessionStateStoreScript.SessionData, include_details: bool = true) -> Dictionary:
	var pos := hero_position(session)
	var local_public_contacts := 0
	var nearest_distance := 9999
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or is_encounter_resolved(session, encounter):
			continue
		if not _raid_is_public(session, encounter):
			continue
		var distance = abs(int(encounter.get("x", 0)) - pos.x) + abs(int(encounter.get("y", 0)) - pos.y)
		if distance <= 2:
			local_public_contacts += 1
		nearest_distance = min(nearest_distance, distance)
	if local_public_contacts <= 0:
		return {}
	var nearest_town_result := _nearest_town_for_controller(session, "player", pos.x, pos.y)
	var nearest_town = nearest_town_result.get("town", {})
	var nearest_town_distance = 9999 if nearest_town.is_empty() else abs(pos.x - int(nearest_town.get("x", 0))) + abs(pos.y - int(nearest_town.get("y", 0)))
	if int(_find_active_town(session).get("index", -1)) >= 0:
		return {}
	if nearest_town_distance <= 2 and local_public_contacts <= 1:
		return {}
	var severity := 3 if local_public_contacts > 1 or nearest_distance <= 1 else 2
	var item := {
		"key": "field:%d:%d" % [pos.x, pos.y],
		"severity": severity,
		"gate": severity >= 3,
		"summary": "Active command exposed",
	}
	if include_details:
		var terrain := _terrain_name_at(session, pos.x, pos.y)
		var town_clause := "no owned town anchors the current march line"
		if not nearest_town.is_empty():
			town_clause = "%s %d tile%s away" % [
				_town_name(nearest_town),
				nearest_town_distance,
				"" if nearest_town_distance == 1 else "s",
			]
		item["detail"] = "The active command ends on %s at %d,%d with %d public hostile contact%s inside 2 tiles and %s. Ending here risks a strike on the march line." % [
			terrain,
			pos.x,
			pos.y,
			local_public_contacts,
			"" if local_public_contacts == 1 else "s",
			town_clause,
		]
	return item

static func _command_risk_pressure_objective_item(
	session: SessionStateStoreScript.SessionData,
	scenario: Dictionary,
	objective: Dictionary,
	include_details: bool = true
) -> Dictionary:
	if _scenario_objective_met(session, objective):
		return {}
	var faction_id := String(objective.get("faction_id", ""))
	var config := _enemy_config_for_faction(scenario, faction_id)
	if config.is_empty():
		return {}
	var current_pressure: int = _enemy_pressure(session, faction_id)
	var threshold := int(objective.get("threshold", 0))
	var gain := _public_enemy_pressure_gain(session, config)
	var posture := String(_enemy_state_for_faction(session, faction_id).get("posture", "probing"))
	if current_pressure + gain < threshold and not (posture == "massing" and threshold - current_pressure <= 2):
		return {}
	var label := String(objective.get("label", objective.get("id", "pressure objective")))
	var item := {
		"key": "objective-pressure:%s:%s" % [faction_id, label],
		"severity": 4,
		"gate": true,
		"summary": "%s near trigger" % label,
	}
	if include_details:
		var faction_label := String(config.get("label", ContentService.get_faction(faction_id).get("name", faction_id)))
		item["detail"] = "%s sits at %d/%d pressure. %s posture plus roughly +%d public pressure/day makes the defeat watch %s a likely next-day trigger." % [
			faction_label,
			current_pressure,
			threshold,
			_posture_label(posture),
			gain,
			label,
		]
	return item

static func _command_risk_encounter_objective_item(session: SessionStateStoreScript.SessionData, objective: Dictionary, include_details: bool = true) -> Dictionary:
	if _scenario_objective_met(session, objective):
		return {}
	var placement_id := String(objective.get("placement_id", ""))
	if placement_id == "":
		return {}
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or String(encounter.get("placement_id", "")) != placement_id:
			continue
		var encounter_def := ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
		if String(encounter.get("contested_by_faction_id", "")) != "":
			var item := {
				"key": "objective-encounter:%s" % placement_id,
				"severity": 4,
				"gate": true,
				"summary": "%s objective contested" % String(encounter_def.get("name", placement_id)),
			}
			if include_details:
				item["detail"] = "%s is already under hostile contest, and the defeat watch %s stays live until the front is cleared." % [
					String(encounter_def.get("name", placement_id)),
					String(objective.get("label", objective.get("id", "objective"))),
				]
			return item
		for raid in session.overworld.get("encounters", []):
			if not (raid is Dictionary) or String(raid.get("spawned_by_faction_id", "")) == "":
				continue
			if String(raid.get("target_kind", "")) != "encounter" or String(raid.get("target_placement_id", "")) != placement_id:
				continue
			var item := {
				"key": "objective-encounter:%s" % placement_id,
				"severity": 3,
				"gate": true,
				"summary": "%s objective pressured" % String(encounter_def.get("name", placement_id)),
			}
			if include_details:
				item["detail"] = "%s is drawing hostile pressure, and leaving the day unresolved risks turning the defeat watch %s into a live front." % [
					String(encounter_def.get("name", placement_id)),
					String(objective.get("label", objective.get("id", "objective"))),
				]
			return item
	return {}

static func _town_command_risk_state(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	include_front: bool = true
) -> Dictionary:
	var state := {
		"visible_marching": 0,
		"visible_pressuring": 0,
		"hidden_targeting": false,
		"nearest_goal_distance": 9999,
		"marching_commanders": [],
		"pressuring_commanders": [],
		"siege_progress": 0,
		"siege_capture_progress": 1,
		"front_active": false,
		"front_mode": "",
		"front_faction_id": "",
		"front_enemy_label": "",
		"front_summary": "",
		"front_public_clause": "",
	}
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	var placement_id := String(town.get("placement_id", ""))
	if placement_id == "":
		return state
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == "":
			continue
		if String(encounter.get("target_kind", "")) != "town" or String(encounter.get("target_placement_id", "")) != placement_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		var is_public: bool = _raid_is_public(session, encounter)
		var goal_distance := int(encounter.get("goal_distance", 9999))
		var is_pressuring := bool(encounter.get("arrived", false)) or goal_distance <= 0
		var commander_name := encounter_commander_threat_label(encounter)
		if is_public:
			if is_pressuring:
				state["visible_pressuring"] = int(state.get("visible_pressuring", 0)) + 1
				if commander_name != "" and commander_name not in state.get("pressuring_commanders", []):
					var pressuring_commanders: Array = state.get("pressuring_commanders", [])
					pressuring_commanders.append(commander_name)
					state["pressuring_commanders"] = pressuring_commanders
			else:
				state["visible_marching"] = int(state.get("visible_marching", 0)) + 1
				state["nearest_goal_distance"] = min(int(state.get("nearest_goal_distance", 9999)), goal_distance)
				if commander_name != "" and commander_name not in state.get("marching_commanders", []):
					var marching_commanders: Array = state.get("marching_commanders", [])
					marching_commanders.append(commander_name)
					state["marching_commanders"] = marching_commanders
		else:
			state["hidden_targeting"] = true
	for config in scenario.get("enemy_factions", []):
		if not (config is Dictionary):
			continue
		if String(config.get("siege_target_placement_id", "")) != placement_id:
			continue
		var faction_state := _enemy_state_for_faction(session, String(config.get("faction_id", "")))
		state["siege_progress"] = max(int(state.get("siege_progress", 0)), int(faction_state.get("siege_progress", 0)))
		state["siege_capture_progress"] = max(1, int(config.get("siege_capture_progress", 1)))
	if int(state.get("nearest_goal_distance", 9999)) == 9999 and int(state.get("visible_pressuring", 0)) > 0:
		state["nearest_goal_distance"] = 0
	if include_front:
		var front_state := _town_front_state(session, town)
		state["front_active"] = bool(front_state.get("active", false))
		state["front_mode"] = String(front_state.get("mode", ""))
		state["front_faction_id"] = String(front_state.get("faction_id", ""))
		state["front_enemy_label"] = String(front_state.get("enemy_label", ""))
		state["front_summary"] = String(front_state.get("summary", ""))
		state["front_public_clause"] = String(front_state.get("public_clause", ""))
	return state

static func _town_command_risk_consequence(
	town: Dictionary,
	readiness: int,
	logistics: Dictionary,
	recovery: Dictionary,
	capital_project: Dictionary,
	objective_anchor: bool
) -> String:
	if bool(capital_project.get("vulnerable", false)) and String(capital_project.get("vulnerability_summary", "")) != "":
		return String(capital_project.get("vulnerability_summary", ""))
	var consequence_parts := []
	if int(logistics.get("gap_readiness_penalty", 0)) > 0:
		consequence_parts.append("readiness stays -%d" % int(logistics.get("gap_readiness_penalty", 0)))
	if int(logistics.get("gap_growth_penalty_percent", 0)) > 0:
		consequence_parts.append("recruits stay -%d%%" % int(logistics.get("gap_growth_penalty_percent", 0)))
	if bool(recovery.get("active", false)):
		consequence_parts.append("%d recovery pressure remains" % int(recovery.get("pressure", 0)))
	if not consequence_parts.is_empty():
		return "If you hold this posture, %s." % ", ".join(consequence_parts)
	if readiness <= 18 or _town_defense_summary(town) == "thin watch":
		return "Ending the day here leaves a live siege window on the town."
	if objective_anchor:
		return "This lane also sits on an active objective track."
	return "Another quiet day leaves the front open to hostile pressure."

static func _public_enemy_pressure_gain(session: SessionStateStoreScript.SessionData, config: Dictionary) -> int:
	return max(
		1,
		DifficultyRulesScript.adjust_enemy_pressure_gain(
			session,
			max(0, int(config.get("pressure_per_day", 0)) + int(config.get("pressure_per_enemy_town", 0)))
		)
	)

static func _enemy_config_for_faction(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and PlayerRules.controller_id(config) == faction_id:
			return config
	return {}

static func _enemy_state_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and PlayerRules.controller_id(state) == faction_id:
			return state
	return {}

static func _scenario_town_started_enemy(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	if session == null or placement_id == "":
		return false
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return String(town.get("owner", "neutral")) == "enemy"
	return false

static func _town_is_objective_anchor(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	if session == null or placement_id == "":
		return false
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
	var objectives = _scenario_rules().objectives_for_session(session)
	if not (objectives is Dictionary):
		return false
	for bucket in ["victory", "defeat"]:
		for objective in objectives.get(bucket, []):
			if objective is Dictionary and String(objective.get("placement_id", "")) == placement_id:
				return true
	return false

static func _command_risk_grade_label(severity: int) -> String:
	match clampi(severity, 0, 5):
		5:
			return "Severe"
		4:
			return "High"
		3:
			return "Elevated"
		2:
			return "Guarded"
		1:
			return "Low"
		_:
			return "Steady"

static func _posture_label(posture: String) -> String:
	match posture:
		"fortifying":
			return "fortifying"
		"raiding":
			return "raiding"
		"massing":
			return "massing"
		"collapsed":
			return "collapsed"
		_:
			return "probing"

static func _army_totals(army: Dictionary) -> Dictionary:
	return HumanEngine.native(&"OverworldRules._army_totals", [army])

static func _refresh_all_player_heroes_for_new_day(session: SessionStateStoreScript.SessionData) -> void:
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array):
		return
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var synced_active := false
	var new_week := VisitBuildings.week_index(session.day) != VisitBuildings.week_index(session.day - 1)
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary):
			continue
		if new_week:
			hero.erase(VisitBuildings.WEEK_BONUSES)
		hero = SpellRulesScript.refresh_daily_mana(hero)
		var carry_limit := int(HeroProgressionRulesScript.aggregate_bonuses(hero).get("movement_carry", 0))
		var leftover := int(hero.get("movement", {}).get("current", 0)) if hero.get("movement", {}) is Dictionary else 0
		hero["movement_carry"] = clampi(leftover, 0, carry_limit)
		var movement_max := _movement_max_from_hero(hero, session)
		hero["movement"] = {"current": movement_max, "max": movement_max}
		heroes[index] = hero
		if String(hero.get("id", "")) != active_hero_id:
			continue
		synced_active = true
		session.overworld["hero"] = hero.duplicate(true)
		session.overworld["army"] = hero.get("army", {}).duplicate(true)
		session.overworld["movement"] = hero.get("movement", {}).duplicate(true)
		session.overworld["hero_position"] = hero.get("position", {}).duplicate(true)
	session.overworld["player_heroes"] = heroes
	if synced_active:
		return
	var active_hero := HeroCommandRulesScript.active_hero(session)
	if active_hero.is_empty():
		return
	session.overworld["hero"] = active_hero.duplicate(true)
	session.overworld["army"] = active_hero.get("army", {}).duplicate(true)
	session.overworld["movement"] = active_hero.get("movement", {}).duplicate(true)
	session.overworld["hero_position"] = active_hero.get("position", {}).duplicate(true)

static func _resource_site_control_label(node: Dictionary, site: Dictionary) -> String:
	return HumanEngine.native_writing(&"OverworldRules._resource_site_control_label", [node, site])

static func can_afford_cost_with_town_market(town: Dictionary, pool: Dictionary, cost: Variant, current_day: int = -1) -> bool:
	return HumanEngine.native_writing(&"OverworldRules.can_afford_cost_with_town_market", [town, pool, cost, current_day])

static func get_town_market_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_town_market_actions", [session, town])

static func get_town_recruit_options(town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"OverworldRules.get_town_recruit_options", [town])
