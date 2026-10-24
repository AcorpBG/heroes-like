class_name EnemyAdventureRules
extends RefCounted

const TurnPlayback = preload("res://scripts/core/OverworldTurnPlayback.gd")

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const NativeTransit = preload("res://scripts/core/NativeTransitRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")
const VisitBuildings = preload("res://scripts/core/VisitBuildingRules.gd")
const CreatureDwellings = preload("res://scripts/core/CreatureDwellingRules.gd")
const TurnEngine = preload("res://scripts/core/TurnEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")
static var _path_distance_surface_cache: Dictionary = {}
static var _native_navigation_surface_cache: Dictionary = {}
static var _enemy_turn_terrain_surfaces: Dictionary = {}
static var _enemy_turn_path_caches_active := false

const COMMANDER_STATUS_AVAILABLE := "available"
const COMMANDER_STATUS_ACTIVE := "active"
const COMMANDER_STATUS_RECOVERING := "recovering"
const COMMANDER_OUTCOME_DEPLOYED := "deployed"
const COMMANDER_OUTCOME_FIELD_VICTORY := "field_victory"
const COMMANDER_OUTCOME_RESOURCE_SECURED := "resource_secured"
const COMMANDER_OUTCOME_ARTIFACT_SECURED := "artifact_secured"
const COMMANDER_OUTCOME_OBJECTIVE_SECURED := "objective_secured"
const COMMANDER_OUTCOME_SITE_DEFENDED := "site_defended"
const COMMANDER_OUTCOME_TOWN_DEFENDED := "town_defended"
const COMMANDER_EXPERIENCE_DEPLOYED := 90
const COMMANDER_EXPERIENCE_FIELD_VICTORY := 180
const COMMANDER_EXPERIENCE_PURSUIT_VICTORY := 205
const COMMANDER_EXPERIENCE_CAPITULATION := 150
const COMMANDER_EXPERIENCE_ROUT_VICTORY := 230
const COMMANDER_EXPERIENCE_ASSAULT_VICTORY := 210
const COMMANDER_EXPERIENCE_DEFEATED := 45
const COMMANDER_EXPERIENCE_STALEMATE := 30
const COMMANDER_EXPERIENCE_RESOURCE_SECURED := 70
const COMMANDER_EXPERIENCE_ARTIFACT_SECURED := 100
const COMMANDER_EXPERIENCE_OBJECTIVE_SECURED := 90
const COMMANDER_EXPERIENCE_SITE_DEFENDED := 45
const COMMANDER_EXPERIENCE_TOWN_DEFENDED := 65
const COMMANDER_VETERANCY_LABELS := ["", "Blooded", "Veteran", "War-hardened"]
# known_world_memory comes only from older saves (nothing writes it any more);
# these bound it while it expires.
const RAID_ADVENTURE_SCOUTING_MEMORY_DAYS := 7
const RAID_ADVENTURE_SCOUTING_MAX_TARGET_RECORDS := 24
const AI_HERO_SIGHTING_MEMORY_DAYS := 3
const AI_HERO_SIGHTING_MAX_RECORDS := 16
const PATH_DISTANCE_SURFACE_CACHE_LIMIT := 96
const PATH_MOVEMENT_DELTAS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]
# Enemy-state fields that commander and memory helpers persist directly on the
# session entry during a turn. Everything else in an enemy state (treasury,
# posture, pressure) comes back from AiHeroRules.run_faction_turn.
const SESSION_OWNED_ENEMY_STATE_KEYS := ["commander_roster", "known_world_memory", "hero_task_state", "rebuild_pressure_request"]
const LOGISTICS_SITE_FAMILIES := ["faction_outpost", "frontier_shrine"]
## AI weight (content/ai_hero_weights.json): an own dwelling is worth a trip
## while its week of creatures is worth this much
## (_resource_node_contestable_by_faction). AiHeroRules puts a computer
## player's set in place (apply_ai_weights); until it does, the default set.
static var DWELLING_HIRE_MIN_VALUE: int
static var _ai_weights_ready := false
## How computer heroes choose specialties (_preferred_enemy_specialty_id):
## "specialty_pick" in content/ai_hero_weights.json, the same for every player
## because heroes also level up in battles outside their own turn. Read again
## whenever the content revision changes.
static var SPECIALTY_FOCUS_SCORE: float
static var SPECIALTY_PATH_SCORE: float
static var SPECIALTY_NOT_ADVENTURE_SCORE: float
static var SPECIALTY_RANK_UP_SCORE: float
static var _specialty_pick_revision := -1
# Only the event log's reason codes read these, and only whether a value is
# above zero (_resource_target_reason_codes).
const AI_RESOURCE_VALUE_BY_ID := {
	"gold": 1,
	"wood": 350,
	"ore": 350,
	"aetherglass": 700,
	"embergrain": 700,
	"peatwax": 700,
	"verdant_grafts": 700,
	"brass_scrip": 700,
	"memory_salt": 700,
	"experience": 1,
}
const COMMANDER_ROLE_RAIDER := "raider"
const COMMANDER_ROLE_DEFENDER := "defender"
const COMMANDER_ROLE_RETAKER := "retaker"
const COMMANDER_ROLE_STABILIZER := "stabilizer"
const COMMANDER_ROLE_SCOUT := "scout"
const COMMANDER_ROLE_RECOVERING := "recovering"
const COMMANDER_ROLE_RESERVE := "reserve"
const AI_PUBLIC_EVENT_LOG_KEYS := [
	"day",
	"event_type",
	"faction_id",
	"player_id",
	"faction_label",
	"actor_label",
	"target_kind",
	"target_id",
	"target_label",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
]
const AI_PUBLIC_EVENT_LOG_TYPES := [
	"ai_target_assigned",
	"ai_pressure_summary",
	"ai_commander_task_planned",
	"ai_site_seized",
	"ai_site_contested",
	"ai_site_defended",
	"ai_town_captured",
	"ai_town_defended",
	"ai_town_built",
	"ai_town_recruited",
	"ai_garrison_reinforced",
	"ai_raid_reinforced",
	"ai_commander_rebuilt",
	"ai_commander_prepared",
	"ai_commander_role_observed",
	"ai_raid_moved",
	"ai_raid_arrived",
	"ai_raid_regrouped",
	"ai_raid_grouped",
	"ai_adventure_spell_cast",
	"ai_artifact_secured",
	"ai_hero_hired",
	"ai_guard_defeated",
	"ai_hero_defeated",
]
const AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS := [
	"event_id",
	"sequence",
	"target_x",
	"target_y",
	"from_x",
	"from_y",
	"to_x",
	"to_y",
	"phase_id",
	"state_policy",
	"debug_reason",
	"target_debug_reason",
	"score_ref",
	"score",
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
	"object_metadata_value",
	"object_route_pressure_value",
	"priority_without_object_metadata",
	"priority_with_object_metadata",
	"final_priority",
	"final_score",
	"income_value",
	"growth_value",
	"pressure_value",
	"category_bonus",
	"garrison_score",
	"raid_score",
	"resource_score_breakdown",
	"resource_breakdown",
	"priority_table",
	"breakdown",
	"target_memory",
	"commander_role_state",
	"hero_task_state",
	"fixture_state",
	"internal",
	"saved",
	"durable",
	"migration",
	"SAVE_VERSION",
]

const RAID_RECENT_EXPLORATION_TARGET_LIMIT := 12
# Session meta, not saved: placement id -> the day a fallen AI hero was first
# seen resolved.
const FALLEN_HERO_SEEN_DAY_META := &"_enemy_fallen_hero_seen_day"
# Session meta, not saved, present only while EnemyTurnRules.normalize_enemy_states
# runs: the roster entries normalized so far, keyed by everything an entry is
# built from (see _normalize_commander_roster_entries).
const COMMANDER_ENTRY_MEMO_META := &"_enemy_commander_entry_memo"

static func _enemy_hero_sighting_sources(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String) -> Array:
	return TurnEngine.native_writing(&"EnemyAdventureRules._enemy_hero_sighting_sources", [session, config, faction_id])

# Like the player, a full army does not stop the claim: troops that fit join
# and the rest stay behind.
static func _player_hero_snapshots_for_intercept(session: SessionStateStoreScript.SessionData, read_only: bool = false) -> Array:
	return TurnEngine.native_writing(&"EnemyAdventureRules._player_hero_snapshots_for_intercept", [session, read_only])

static func commander_display_name(source: Variant, include_veterancy: bool = true) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_display_name", [source, include_veterancy])

static func commander_record_summary(source: Variant) -> String:
	return HumanEngine.native_writing(&"EnemyAdventureRules.commander_record_summary", [source])

static func commander_target_memory(source: Variant) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_target_memory", [source])

static func commander_memory_summary(source: Variant) -> String:
	return HumanEngine.native_writing(&"EnemyAdventureRules.commander_memory_summary", [source])

static func commander_recent_outcome_brief(source: Variant) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_recent_outcome_brief", [source])

static func commander_army_summary(source: Variant) -> String:
	return HumanEngine.native_writing(&"EnemyAdventureRules.commander_army_summary", [source])

static func commander_can_deploy(source: Variant) -> bool:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_can_deploy", [source])

static func build_roster_commander_state(roster_hero_id: String, faction_id: String, existing_state: Dictionary = {}, record_source: Variant = {}) -> Dictionary:
	return HumanEngine.native_writing(&"EnemyAdventureRules.build_roster_commander_state", [roster_hero_id, faction_id, existing_state, record_source])

static func advance_commander_record(commander_state: Dictionary, outcome_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules.advance_commander_record", [commander_state, outcome_id])

static func sync_commander_state_to_roster(session: SessionStateStoreScript.SessionData, faction_id: String, commander_state: Variant, status_override: String = "", active_placement_id: String = "", recovery_day: int = -1, last_outcome: String = "") -> void:
	TurnEngine.native_writing(&"EnemyAdventureRules.sync_commander_state_to_roster", [session, faction_id, commander_state, status_override, active_placement_id, recovery_day, last_outcome])

static func select_raid_commander_roster_hero_id(session: SessionStateStoreScript.SessionData, faction_id: String, preferred_index: int = 0, occupied_commander_ids: Dictionary = {}, commander_roster: Variant = []) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.select_raid_commander_roster_hero_id", [session, faction_id, preferred_index, occupied_commander_ids, commander_roster])

static func raid_commander_display_name(encounter: Dictionary) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.raid_commander_display_name", [encounter])

static func raid_display_name(encounter: Dictionary) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.raid_display_name", [encounter])

static func commander_live_role_state(source: Variant) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_live_role_state", [source])

static func _preferred_commander_index_for_encounter(encounter: Dictionary) -> int:
	return TurnEngine.native_writing(&"EnemyAdventureRules._preferred_commander_index_for_encounter", [encounter])

static func target_is_objective_anchor(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> bool:
	return TurnEngine.native_writing(&"EnemyAdventureRules.target_is_objective_anchor", [session, target_kind, placement_id])

static func raid_strength(encounter: Dictionary) -> int:
	return TurnEngine.native_writing(&"EnemyAdventureRules.raid_strength", [encounter])

static func _find_player_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._find_player_hero", [session, hero_id])

static func _ai_hero_task_finish_live_assignment(session: SessionStateStoreScript.SessionData, faction_id: String, raid: Dictionary, task_status: String, validation: String) -> void:
	TurnEngine.native_writing(&"EnemyAdventureRules._ai_hero_task_finish_live_assignment", [session, faction_id, raid, task_status, validation])

static func _town_is_objective_anchor(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	return TurnEngine.native_writing(&"EnemyAdventureRules._town_is_objective_anchor", [session, placement_id])

static func _secure_resource_target(session: SessionStateStoreScript.SessionData, raid: Dictionary, state: Dictionary, faction_id: String, config: Dictionary = {}) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._secure_resource_target", [session, raid, state, faction_id, config])

static func _break_dwelling_guard_by_raid(session: SessionStateStoreScript.SessionData, raid: Dictionary, faction_id: String, index: int, site: Dictionary) -> bool:
	return TurnEngine.native_writing(&"EnemyAdventureRules._break_dwelling_guard_by_raid", [session, raid, faction_id, index, site])

## Hires as much of the dwelling's week as the faction can pay for and the
## raid can carry, strongest creatures first. Tier 1 is free.
static func _hire_dwelling_creatures_into_raid(session: SessionStateStoreScript.SessionData, faction_id: String, raid: Dictionary, index: int, site: Dictionary, state: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._hire_dwelling_creatures_into_raid", [session, faction_id, raid, index, site, state])

static func _apply_resource_site_artifact_reward_to_raid(session: SessionStateStoreScript.SessionData, faction_id: String, raid: Dictionary, node: Dictionary, site: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._apply_resource_site_artifact_reward_to_raid", [session, faction_id, raid, node, site])

static func _apply_resource_site_claim_recruits_to_raid(session: SessionStateStoreScript.SessionData, faction_id: String, raid: Dictionary, site: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._apply_resource_site_claim_recruits_to_raid", [session, faction_id, raid, site])

static func _apply_resource_site_spell_reward_to_commander(session: SessionStateStoreScript.SessionData, faction_id: String, raid: Dictionary, site: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._apply_resource_site_spell_reward_to_commander", [session, faction_id, raid, site])

static func _target_level(session: SessionStateStoreScript.SessionData, kind: String, target_id: String, faction_id: String = "", fallback: int = 0) -> int:
	return TurnEngine.native_writing(&"EnemyAdventureRules._target_level", [session, kind, target_id, faction_id, fallback])

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._find_town_by_placement", [session, placement_id])

static func _find_encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._find_encounter_by_placement", [session, placement_id])

# Controlling player (or legacy faction key) of the town, matching
# EnemyTurnRules._town_controller_faction_id. Not the town's content faction.
static func _town_controller_faction_id(town_state: Dictionary) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules._town_controller_faction_id", [town_state])

static var _unit_strength_memo := {}
static var _unit_strength_sources := []

static func _resource_interaction_tile(node: Dictionary) -> Vector2i:
	var visit_tile: Variant = node.get("visit_tile", {})
	if visit_tile is Dictionary and not visit_tile.is_empty():
		return Vector2i(
			int(visit_tile.get("x", node.get("x", 0))),
			int(visit_tile.get("y", node.get("y", 0)))
		)
	return Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))

static func clear_path_caches() -> void:
	_path_distance_surface_cache.clear()
	_native_navigation_surface_cache.clear()
	_enemy_turn_terrain_surfaces.clear()
