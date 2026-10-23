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

static func normalize_enemy_known_world_memory(value: Variant, current_day: int = 0) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	var memory := {"schema_version": 1}
	var scouted_targets := _normalize_enemy_scouted_target_records(source.get("scouted_targets", []), current_day)
	if not scouted_targets.is_empty():
		memory["scouted_targets"] = scouted_targets
		memory["last_scouted_day"] = max(0, int(source.get("last_scouted_day", scouted_targets[0].get("scouted_day", 0))))
	var hero_sightings := _normalize_enemy_hero_sighting_records(source.get("player_hero_sightings", []), current_day)
	if not hero_sightings.is_empty():
		memory["player_hero_sightings"] = hero_sightings
		memory["last_hero_sighting_day"] = max(0, int(source.get("last_hero_sighting_day", hero_sightings[0].get("seen_day", 0))))
	if not memory.has("scouted_targets") and not memory.has("player_hero_sightings"):
		return {}
	return memory

static func _normalize_enemy_scouted_target_records(value: Variant, current_day: int = 0) -> Array:
	var normalized := []
	if not (value is Array):
		return LevelRules.canonical_spatial_records(normalized)
	for record_value in value:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var target_kind := String(record.get("target_kind", ""))
		var target_id := String(record.get("target_id", ""))
		if target_kind == "" or target_id == "":
			continue
		var scouted_day: int = max(0, int(record.get("scouted_day", 0)))
		var expires_day: int = max(scouted_day, int(record.get("expires_day", scouted_day + RAID_ADVENTURE_SCOUTING_MEMORY_DAYS)))
		if current_day > 0 and expires_day < current_day:
			continue
		normalized.append(
			{
				"target_kind": target_kind,
				"target_id": target_id,
				"target_label": String(record.get("target_label", target_id)),
				"x": int(record.get("x", 0)),
				"y": int(record.get("y", 0)),
				"level": LevelRules.level_of(record),
				"scouted_day": scouted_day,
				"expires_day": expires_day,
				"source_spell_id": String(record.get("source_spell_id", "")),
				"source_spell_name": String(record.get("source_spell_name", "")),
				"source_kind": String(record.get("source_kind", "")),
				"source_id": String(record.get("source_id", "")),
				"source_raid_id": String(record.get("source_raid_id", "")),
				"state_policy": "ai_known_world_memory",
			}
		)
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("scouted_day", 0)) == int(b.get("scouted_day", 0)):
			return String(a.get("target_label", "")) < String(b.get("target_label", ""))
		return int(a.get("scouted_day", 0)) > int(b.get("scouted_day", 0))
	)
	while normalized.size() > RAID_ADVENTURE_SCOUTING_MAX_TARGET_RECORDS:
		normalized.pop_back()
	return LevelRules.canonical_spatial_records(normalized)

static func _normalize_enemy_hero_sighting_records(value: Variant, current_day: int = 0) -> Array:
	var normalized := []
	if not (value is Array):
		return LevelRules.canonical_spatial_records(normalized)
	for record_value in value:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var hero_id := String(record.get("hero_id", ""))
		if hero_id == "":
			continue
		var seen_day: int = max(0, int(record.get("seen_day", 0)))
		var expires_day: int = max(seen_day, int(record.get("expires_day", seen_day + AI_HERO_SIGHTING_MEMORY_DAYS)))
		if current_day > 0 and expires_day < current_day:
			continue
		normalized.append(
			{
				"hero_id": hero_id,
				"hero_label": String(record.get("hero_label", hero_id)),
				"x": int(record.get("x", 0)),
				"y": int(record.get("y", 0)),
				"level": LevelRules.level_of(record),
				"army_strength": max(0, int(record.get("army_strength", 0))),
				"seen_day": seen_day,
				"expires_day": expires_day,
				"source_kind": String(record.get("source_kind", "")),
				"source_id": String(record.get("source_id", "")),
				"confidence": String(record.get("confidence", "recent")),
				"state_policy": "ai_known_world_memory",
			}
		)
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("seen_day", 0)) == int(b.get("seen_day", 0)):
			return String(a.get("hero_id", "")) < String(b.get("hero_id", ""))
		return int(a.get("seen_day", 0)) > int(b.get("seen_day", 0))
	)
	while normalized.size() > AI_HERO_SIGHTING_MAX_RECORDS:
		normalized.pop_back()
	return LevelRules.canonical_spatial_records(normalized)

static func _enemy_hero_sighting_sources(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String) -> Array:
	return TurnEngine.native_writing(&"EnemyAdventureRules._enemy_hero_sighting_sources", [session, config, faction_id])

# Like the player, a full army does not stop the claim: troops that fit join
# and the rest stay behind.
static func _player_hero_snapshots_for_intercept(session: SessionStateStoreScript.SessionData, read_only: bool = false) -> Array:
	return TurnEngine.native_writing(&"EnemyAdventureRules._player_hero_snapshots_for_intercept", [session, read_only])

static func normalize_raid_armies(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var encounters = session.overworld.get("encounters", [])
	var normalized = []
	var changed = false
	var occupied_commander_ids: Dictionary = {}
	var resolved_lookup := _resolved_encounter_lookup(session.overworld.get("resolved_encounters", []))
	var fallen_seen_day: Dictionary = session.get_meta(FALLEN_HERO_SEEN_DAY_META, {})
	session.set_meta(FALLEN_HERO_SEEN_DAY_META, fallen_seen_day)
	for encounter_value in encounters:
		if not (encounter_value is Dictionary):
			continue
		var existing_commander = encounter_value.get("enemy_commander_state", {})
		if not (existing_commander is Dictionary):
			continue
		var roster_hero_id := String(existing_commander.get("roster_hero_id", ""))
		if roster_hero_id != "":
			occupied_commander_ids[roster_hero_id] = true
	for encounter_value in encounters:
		if not (encounter_value is Dictionary):
			normalized.append(encounter_value)
			continue
		var encounter = encounter_value
		if PlayerRules.raid_controller_id(encounter) != "":
			if _fallen_hero_settled(session, encounter, resolved_lookup, fallen_seen_day):
				normalized.append(encounter)
				continue
			var previous_army = encounter.get("enemy_army", {})
			var previous_commander = encounter.get("enemy_commander_state", {})
			encounter = ensure_raid_army(encounter, session, occupied_commander_ids)
			var roster_hero_id := String(encounter.get("enemy_commander_state", {}).get("roster_hero_id", ""))
			if roster_hero_id != "":
				occupied_commander_ids[roster_hero_id] = true
			if encounter.get("enemy_army", {}) != previous_army or encounter.get("enemy_commander_state", {}) != previous_commander:
				changed = true
		normalized.append(encounter)
	if changed:
		session.overworld["encounters"] = normalized

## A fallen hero's entry is normalized through the day it fell, when the day's
## reports read it, and then kept as it is: nothing plays it again. An entry
## without a roster hero is still normalized, since that can claim one.
static func _fallen_hero_settled(
	session: SessionStateStoreScript.SessionData,
	encounter: Dictionary,
	resolved_lookup: Dictionary,
	fallen_seen_day: Dictionary
) -> bool:
	var placement_id := String(encounter.get("placement_id", ""))
	if not resolved_lookup.has(placement_id):
		return false
	var commander_state = encounter.get("enemy_commander_state", {})
	if not (commander_state is Dictionary) or String(commander_state.get("roster_hero_id", "")) == "":
		return false
	if not fallen_seen_day.has(placement_id):
		fallen_seen_day[placement_id] = int(session.day)
	return int(fallen_seen_day[placement_id]) < int(session.day)

static func normalize_all_commander_rosters(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	_normalize_town_defender_commander_states(session)
	_normalize_resource_defender_commander_states(session)
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return
	var changed := false
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		var faction_id := PlayerRules.controller_id(state)
		if faction_id == "":
			continue
		var normalized_roster = normalize_commander_roster(
			session,
			faction_id,
			state.get("commander_roster", [])
		)
		if state.get("commander_roster", []) != normalized_roster:
			state["commander_roster"] = normalized_roster
			states[index] = state
			changed = true
	if changed:
		session.overworld["enemy_states"] = states

static func normalize_commander_roster(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant
) -> Array:
	return _normalize_commander_roster_entries(session, faction_id, roster_value)

static func _normalize_commander_roster_entry(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant,
	roster_hero_id: String
) -> Dictionary:
	# Raid construction consumes one entry. Keep its exact catalog membership
	# and normalization without rebuilding every unrelated faction commander.
	if roster_hero_id == "" or roster_hero_id not in _faction_commander_ids(PlayerRules.faction_id(session, faction_id)):
		return {}
	var entries := _normalize_commander_roster_entries(session, faction_id, roster_value, [roster_hero_id])
	return entries[0]

static func _normalize_commander_roster_entries(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant,
	selected_hero_ids: Variant = null
) -> Array:
	var existing_map: Dictionary = {}
	if roster_value is Array:
		for entry_value in roster_value:
			if not (entry_value is Dictionary):
				continue
			var roster_hero_id := String(entry_value.get("roster_hero_id", ""))
			if roster_hero_id == "":
				continue
			existing_map[roster_hero_id] = entry_value
	var active_map = _active_commander_map(session, faction_id, selected_hero_ids)
	var normalized := []
	var session_day := int(session.day) if session != null else 0
	var hero_ids: Array = selected_hero_ids if selected_hero_ids is Array else _faction_commander_ids(PlayerRules.faction_id(session, faction_id))
	# The enemy state normalization rebuilds each roster several times over,
	# mostly from entries it built a moment before. An entry is a function of
	# the existing entry, the active commander, the controller's identity, the
	# day and the content; while that normalization runs, those inputs, the
	# entries serialized with their exact types and key order, key the entry
	# built from them.
	var use_memo := session != null and session.has_meta(COMMANDER_ENTRY_MEMO_META)
	var memo: Dictionary = session.get_meta(COMMANDER_ENTRY_MEMO_META, {}) if use_memo else {}
	var memo_identity := var_to_bytes(PlayerRules.identity_fields(session, faction_id)) if use_memo else PackedByteArray()
	var memo_revision := ContentService.get_content_revision() if use_memo else -1
	for roster_hero_id in hero_ids:
		var existing = existing_map.get(roster_hero_id, {})
		if not (existing is Dictionary):
			existing = {}
		var memo_key: Array = []
		if use_memo:
			memo_key = [
				faction_id,
				roster_hero_id,
				session_day,
				memo_identity,
				memo_revision,
				var_to_bytes(existing),
				var_to_bytes(active_map.get(roster_hero_id)),
			]
			if memo.has(memo_key):
				normalized.append(memo[memo_key].duplicate(true))
				continue
		var active_entry: Dictionary = active_map.get(roster_hero_id, {})
		var active_commander_state = active_entry.get("commander_state", {})
		if not (active_commander_state is Dictionary):
			active_commander_state = {}
		var commander_seed = (
			active_commander_state
			if not active_commander_state.is_empty()
			else existing.get("commander_state", {})
		)
		commander_seed = commander_seed.duplicate(true)
		commander_seed.merge(PlayerRules.identity_fields(session, faction_id), true)
		var record := _normalized_commander_record(existing, commander_seed)
		var target_memory := _normalized_commander_memory(existing, commander_seed)
		var army_continuity := _normalized_commander_army_continuity(existing, commander_seed)
		var commander_state = build_roster_commander_state(
			roster_hero_id,
			faction_id,
			commander_seed,
			{
				"record": record,
				"target_memory": target_memory,
				"army_continuity": army_continuity,
				"commander_role_state": _normalized_commander_role_state(existing, commander_seed),
			}
		)
		var role_state := _normalized_commander_role_state(existing, commander_state)
		var entry := {
			"roster_hero_id": roster_hero_id,
			"status": COMMANDER_STATUS_AVAILABLE,
			"active_placement_id": "",
			"recovery_day": 0,
			"last_outcome": String(existing.get("last_outcome", commander_state.get("last_outcome", ""))),
			"deployments": max(0, int(record.get("deployments", 0))),
			"battle_wins": max(0, int(record.get("battle_wins", 0))),
			"times_defeated": max(0, int(record.get("times_defeated", 0))),
			"strategic_successes": max(0, int(record.get("strategic_successes", 0))),
			"renown": max(0, int(record.get("renown", 0))),
			"target_memory": target_memory,
			"commander_role_state": role_state,
			"army_continuity": commander_army_continuity(commander_state),
			"commander_state": commander_state,
		}
		if active_map.has(roster_hero_id):
			entry["status"] = COMMANDER_STATUS_ACTIVE
			entry["active_placement_id"] = String(active_entry.get("placement_id", ""))
		else:
			var existing_status: String = _normalize_commander_status(
				existing.get("status", COMMANDER_STATUS_AVAILABLE)
			)
			var recovery_day: int = max(0, int(existing.get("recovery_day", 0)))
			if existing_status == COMMANDER_STATUS_RECOVERING and recovery_day > session_day:
				entry["status"] = COMMANDER_STATUS_RECOVERING
				entry["recovery_day"] = recovery_day
		if use_memo:
			memo[memo_key] = entry.duplicate(true)
		normalized.append(entry)
	return normalized

static func commander_roster_for_faction(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> Array:
	if session == null or faction_id == "":
		return []
	for state in session.overworld.get("enemy_states", []):
		if not (state is Dictionary):
			continue
		if PlayerRules.controller_id(state) != faction_id:
			continue
		var roster = state.get("commander_roster", [])
		return roster if roster is Array else []
	return []

static func commander_veterancy_label(source: Variant) -> String:
	return String(
		COMMANDER_VETERANCY_LABELS[
			clamp(_commander_veterancy_rank_from_record(_normalized_commander_record(source)), 0, COMMANDER_VETERANCY_LABELS.size() - 1)
		]
	)

static func commander_display_name(source: Variant, include_veterancy: bool = true) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_display_name", [source, include_veterancy])

static func commander_record_summary(source: Variant) -> String:
	var record := _normalized_commander_record(source)
	var deployments: int = max(0, int(record.get("deployments", 0)))
	var wins: int = max(0, int(record.get("battle_wins", 0)))
	var defeats: int = max(0, int(record.get("times_defeated", 0)))
	var strategic_successes: int = max(0, int(record.get("strategic_successes", 0)))
	if deployments <= 0 and wins <= 0 and defeats <= 0 and strategic_successes <= 0:
		return ""
	var parts := []
	var veterancy := commander_veterancy_label(record)
	if veterancy != "":
		parts.append(veterancy)
	parts.append("%d raid%s" % [deployments, "" if deployments == 1 else "s"])
	if wins > 0:
		parts.append("%d win%s" % [wins, "" if wins == 1 else "s"])
	if strategic_successes > 0:
		parts.append("%d objective%s" % [strategic_successes, "" if strategic_successes == 1 else "s"])
	if defeats > 0:
		parts.append("%d defeat%s" % [defeats, "" if defeats == 1 else "s"])
	elif wins > 0:
		parts.append("undefeated")
	return " | ".join(parts)

static func commander_target_memory(source: Variant) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_target_memory", [source])

static func commander_memory_brief(source: Variant) -> String:
	var memory := _normalized_commander_memory(source)
	if memory.is_empty():
		return ""
	var rival_label := String(memory.get("rival_label", ""))
	var rivalry_count: int = max(0, int(memory.get("rivalry_count", 0)))
	if rival_label != "" and rivalry_count >= 2:
		return "holds a grudge against %s" % rival_label
	var focus_label := String(memory.get("focus_target_label", ""))
	var focus_count: int = max(0, int(memory.get("focus_pressure_count", 0)))
	if focus_label != "" and focus_count >= 2:
		return "returns to %s" % focus_label
	return ""

static func commander_memory_summary(source: Variant) -> String:
	var memory := _normalized_commander_memory(source)
	if memory.is_empty():
		return ""
	var parts := []
	var focus_label := String(memory.get("focus_target_label", ""))
	var focus_count: int = max(0, int(memory.get("focus_pressure_count", 0)))
	if focus_label != "":
		var focus_summary := "Target %s" % focus_label
		if focus_count > 1:
			focus_summary += " (%d raids)" % focus_count
		parts.append(focus_summary)
	var rival_label := String(memory.get("rival_label", ""))
	var rivalry_count: int = max(0, int(memory.get("rivalry_count", 0)))
	if rival_label != "":
		var rival_summary := "Rival %s" % rival_label
		if rivalry_count > 1:
			rival_summary += " x%d" % rivalry_count
		parts.append(rival_summary)
	return " | ".join(parts)

static func commander_army_continuity(source: Variant) -> Dictionary:
	return _normalized_commander_army_continuity(source)

static func commander_army_status(source: Variant) -> String:
	return String(_normalized_commander_army_continuity(source).get("status", ""))

static func commander_army_brief(source: Variant) -> String:
	match commander_army_status(source):
		"shattered":
			return "shattered host"
		"rebuilding":
			return "rebuilding host"
		"scarred":
			return "scarred host"
	return ""

static func commander_recent_outcome_brief(source: Variant) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_recent_outcome_brief", [source])

static func commander_army_summary(source: Variant) -> String:
	return String(_normalized_commander_army_continuity(source).get("summary", ""))

static func commander_can_deploy(source: Variant) -> bool:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_can_deploy", [source])

static func recovering_commander_count(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> int:
	var count := 0
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		if _normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) == COMMANDER_STATUS_RECOVERING:
			count += 1
	return count

static func rebuilding_commander_count(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> int:
	var count := 0
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		var status := _normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE))
		if status in [COMMANDER_STATUS_ACTIVE, COMMANDER_STATUS_RECOVERING]:
			continue
		var continuity := commander_army_continuity(entry_value)
		if continuity.is_empty() or int(continuity.get("base_strength", 0)) <= 0 or commander_can_deploy(entry_value):
			continue
		count += 1
	return count

static func public_commander_recovery_summary(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> String:
	var session_day := int(session.day) if session != null else 0
	var recovering := []
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		if _normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) != COMMANDER_STATUS_RECOVERING:
			continue
		var recovery_day: int = max(0, int(entry_value.get("recovery_day", 0)))
		var remaining_days: int = max(1, recovery_day - session_day)
		var commander_name := commander_display_name(entry_value)
		if commander_name == "":
			continue
		var descriptor := "%dd" % remaining_days
		var army_brief := commander_army_brief(entry_value)
		if army_brief != "":
			descriptor += ", %s" % army_brief
		recovering.append("%s (%s)" % [commander_name, descriptor])
		if recovering.size() >= 2:
			break
	if recovering.is_empty():
		return ""
	var summary := "Command recovering %s" % ", ".join(recovering)
	var total_recovering := recovering_commander_count(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	)
	if total_recovering > recovering.size():
		summary += " (+%d more)" % (total_recovering - recovering.size())
	return summary

static func public_commander_rebuild_summary(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> String:
	var rebuilding := []
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		var status := _normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE))
		if status in [COMMANDER_STATUS_ACTIVE, COMMANDER_STATUS_RECOVERING]:
			continue
		if commander_can_deploy(entry_value):
			continue
		var commander_name := commander_display_name(entry_value)
		var army_summary := commander_army_summary(entry_value)
		if commander_name == "" or army_summary == "":
			continue
		rebuilding.append("%s (%s)" % [commander_name, army_summary])
		if rebuilding.size() >= 2:
			break
	if rebuilding.is_empty():
		return ""
	var summary := "Command rebuilding %s" % ", ".join(rebuilding)
	var total_rebuilding := rebuilding_commander_count(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	)
	if total_rebuilding > rebuilding.size():
		summary += " (+%d more)" % (total_rebuilding - rebuilding.size())
	return summary

static func build_roster_commander_state(
	roster_hero_id: String,
	faction_id: String,
	existing_state: Dictionary = {},
	record_source: Variant = {}
) -> Dictionary:
	var hero_template = ContentService.get_hero(roster_hero_id)
	var record_value: Variant = record_source.get("record", record_source) if record_source is Dictionary else record_source
	var record := _normalized_commander_record(record_value, existing_state)
	var target_memory := _normalized_commander_memory(record_source, existing_state)
	var army_continuity := _normalized_commander_army_continuity(record_source, existing_state)
	var existing_spellbook = existing_state.get("spellbook", {})
	if not (existing_spellbook is Dictionary):
		existing_spellbook = {}
	var command_source = existing_state.get("command", hero_template.get("command", {}))
	var battle_traits_source = _merge_unique_strings(
		existing_state.get("battle_traits", []),
		hero_template.get("battle_traits", [])
	)
	var existing_specialties = existing_state.get("specialties", [])
	var specialties_source = _normalized_specialty_ranks(
		existing_specialties if existing_specialties is Array and not existing_specialties.is_empty() else hero_template.get("starting_specialties", [])
	)
	var specialty_focus_source = _normalized_specialty_focus_ids(
		_merge_unique_strings(
			existing_state.get("specialty_focus_ids", []),
			hero_template.get("specialty_focus_ids", [])
		)
	)
	var spell_ids_source = _merge_unique_strings(
		existing_spellbook.get("known_spell_ids", []),
		_hero_starting_spell_ids(hero_template)
	)
	var artifacts_source = existing_state.get(
		"artifacts",
		record_source.get("artifacts", {}) if record_source is Dictionary else {}
	)
	var commander_state = {
		"id": String(existing_state.get("id", "enemy_commander:%s:%s" % [faction_id, roster_hero_id])),
		"roster_hero_id": roster_hero_id,
		"faction_id": String(hero_template.get("faction_id", existing_state.get("faction_id", faction_id))),
		"name": String(existing_state.get("name", hero_template.get("name", "Enemy Commander"))),
		"archetype": String(existing_state.get("archetype", hero_template.get("archetype", ""))),
		"identity_summary": String(
			existing_state.get("identity_summary", hero_template.get("identity_summary", ""))
		),
		"command": _normalize_command_payload(command_source),
		"battle_traits": battle_traits_source,
		"specialties": specialties_source,
		"specialty_focus_ids": specialty_focus_source,
		"level": max(1, int(existing_state.get("level", 1))),
		"experience": max(0, int(existing_state.get("experience", 0))),
		"next_level_experience": max(250, int(existing_state.get("next_level_experience", 250))),
		"pending_specialty_choices": existing_state.get("pending_specialty_choices", []),
		"last_outcome": String(existing_state.get("last_outcome", record.get("last_outcome", ""))),
		"artifacts": ArtifactRulesScript.normalize_hero_artifacts(artifacts_source),
		"town_training_claims": _normalize_string_array(existing_state.get("town_training_claims", [])),
		"last_town_trade_day": int(existing_state.get("last_town_trade_day", -1)),
		"town_service_claims": existing_state.get("town_service_claims", {}).duplicate(true) if existing_state.get("town_service_claims", {}) is Dictionary else {},
	}
	if String(existing_state.get("player_id", "")) != "":
		commander_state["player_id"] = String(existing_state.player_id)
	# Level-up rolls (HeroProgressionRules.command_gain_stat) keep their path and seed.
	for key in ["command_path", "growth_seed"]:
		if String(existing_state.get(key, "")) != "":
			commander_state[key] = String(existing_state.get(key, ""))
	commander_state = _normalize_enemy_progression(commander_state)
	SpellRulesScript.ensure_hero_spellbook(
		commander_state,
		{
			"command": commander_state.get("command", {}),
			"starting_spell_ids": spell_ids_source,
		}
	)
	# Full mana, as refresh_daily_mana would give; commander_state is a fresh copy.
	var mana: Dictionary = commander_state["spellbook"]["mana"]
	mana["current"] = int(mana.get("max", 0))
	var with_metadata := _apply_commander_army_metadata(
		_apply_commander_record_metadata(
			_apply_commander_memory_metadata(commander_state, target_memory),
			record
		),
		army_continuity
	)
	return _apply_commander_role_metadata(with_metadata, record_source)

static func advance_commander_record(commander_state: Dictionary, outcome_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules.advance_commander_record", [commander_state, outcome_id])

static func sync_commander_state_to_roster(session: SessionStateStoreScript.SessionData, faction_id: String, commander_state: Variant, status_override: String = "", active_placement_id: String = "", recovery_day: int = -1, last_outcome: String = "") -> void:
	TurnEngine.native_writing(&"EnemyAdventureRules.sync_commander_state_to_roster", [session, faction_id, commander_state, status_override, active_placement_id, recovery_day, last_outcome])

static func ensure_raid_army(
	encounter: Dictionary,
	session: SessionStateStoreScript.SessionData = null,
	occupied_commander_ids: Dictionary = {}
) -> Dictionary:
	if encounter.is_empty():
		return encounter
	var encounter_id = String(encounter.get("encounter_id", encounter.get("id", "")))
	var commander_state := {}
	if PlayerRules.raid_controller_id(encounter) != "" and not bool(encounter.get("commanderless_support_column", false)):
		commander_state = build_raid_commander_state(
			encounter,
			"",
			"",
			session,
			occupied_commander_ids,
			commander_roster_for_faction(session, PlayerRules.raid_controller_id(encounter))
		)
	var normalized_army = _normalize_army_payload(encounter.get("enemy_army", {}))
	if normalized_army.is_empty():
		var continuity_army = _normalize_army_payload(
			{"stacks": commander_army_continuity(commander_state).get("stacks", [])}
		)
		if not continuity_army.is_empty():
			normalized_army = {
				"id": String(encounter.get("enemy_army", {}).get("id", encounter_id)),
				"name": String(encounter.get("enemy_army", {}).get("name", "Raid Host")),
				"stacks": continuity_army.get("stacks", []).duplicate(true),
			}
		else:
			normalized_army = _base_enemy_army(encounter_id)
	if not normalized_army.is_empty():
		normalized_army["id"] = String(normalized_army.get("id", encounter_id))
		normalized_army["name"] = String(normalized_army.get("name", "Raid Host"))
		encounter["enemy_army"] = normalized_army
	if not commander_state.is_empty():
		encounter["enemy_commander_state"] = sync_commander_army_continuity(
			commander_state,
			normalized_army,
			encounter_id
		)
	return encounter

static func select_raid_commander_roster_hero_id(session: SessionStateStoreScript.SessionData, faction_id: String, preferred_index: int = 0, occupied_commander_ids: Dictionary = {}, commander_roster: Variant = []) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.select_raid_commander_roster_hero_id", [session, faction_id, preferred_index, occupied_commander_ids, commander_roster])

static func build_raid_commander_state(
	encounter: Dictionary,
	roster_hero_id: String = "",
	faction_id: String = "",
	session: SessionStateStoreScript.SessionData = null,
	occupied_commander_ids: Dictionary = {},
	commander_roster: Variant = []
) -> Dictionary:
	if encounter.is_empty():
		return {}
	var existing_state = encounter.get("enemy_commander_state", {})
	if not (existing_state is Dictionary):
		existing_state = {}
	var resolved_faction_id: String = PlayerRules.raid_controller_id(encounter)
	if resolved_faction_id == "":
		resolved_faction_id = PlayerRules.controller_id(existing_state, faction_id)
	if resolved_faction_id == "":
		resolved_faction_id = String(encounter.get("spawned_by_faction_id", faction_id))
	var resolved_roster_hero_id: String = String(existing_state.get("roster_hero_id", roster_hero_id))
	if resolved_roster_hero_id == "" and resolved_faction_id != "":
		resolved_roster_hero_id = select_raid_commander_roster_hero_id(
			session,
			resolved_faction_id,
			_preferred_commander_index_for_encounter(encounter),
			occupied_commander_ids,
			commander_roster
		)
	if resolved_roster_hero_id == "" and resolved_faction_id != "" and existing_state.is_empty():
		return {}
	var hero_template = ContentService.get_hero(resolved_roster_hero_id)
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var encounter_commander = encounter_template.get("enemy_commander", {})
	if not (encounter_commander is Dictionary):
		encounter_commander = {}
	var roster_entry := _normalize_commander_roster_entry(
		session,
		resolved_faction_id,
		commander_roster if commander_roster is Array else commander_roster_for_faction(session, resolved_faction_id),
		resolved_roster_hero_id
	)
	var roster_commander_state = roster_entry.get("commander_state", {})
	if not (roster_commander_state is Dictionary):
		roster_commander_state = {}
	var commander_seed := build_roster_commander_state(
		resolved_roster_hero_id,
		resolved_faction_id,
		roster_commander_state if not roster_commander_state.is_empty() else existing_state,
		roster_entry
	)
	var command_source = encounter_commander.get(
		"command",
		commander_seed.get("command", hero_template.get("command", {}))
	)
	var commander_state = existing_state.duplicate(true) if not existing_state.is_empty() else commander_seed.duplicate(true)
	commander_state["id"] = String(
		commander_state.get(
			"id",
			commander_seed.get(
				"id",
				"raid_commander:%s" % String(encounter.get("placement_id", encounter.get("encounter_id", "raid")))
			)
		)
	)
	commander_state["roster_hero_id"] = resolved_roster_hero_id
	commander_state["faction_id"] = PlayerRules.faction_id(session, resolved_faction_id)
	if not PlayerRules.player(session, resolved_faction_id).is_empty():
		commander_state["player_id"] = resolved_faction_id
	commander_state["name"] = String(
		commander_state.get(
			"name",
			commander_seed.get("name", hero_template.get("name", encounter_commander.get("name", "Enemy Commander")))
		)
	)
	commander_state["archetype"] = String(
		commander_state.get("archetype", commander_seed.get("archetype", hero_template.get("archetype", "")))
	)
	commander_state["identity_summary"] = String(
		commander_state.get(
			"identity_summary",
			commander_seed.get("identity_summary", hero_template.get("identity_summary", ""))
		)
	)
	commander_state["command"] = _normalize_command_payload(commander_state.get("command", command_source))
	commander_state["battle_traits"] = _merge_unique_strings(
		commander_seed.get("battle_traits", hero_template.get("battle_traits", [])),
		commander_state.get("battle_traits", encounter_commander.get("battle_traits", []))
	)
	var resolved_specialties = commander_state.get("specialties", [])
	if not (resolved_specialties is Array) or resolved_specialties.is_empty():
		resolved_specialties = commander_seed.get("specialties", hero_template.get("starting_specialties", []))
	commander_state["specialties"] = _normalized_specialty_ranks(resolved_specialties)
	commander_state["specialty_focus_ids"] = _normalized_specialty_focus_ids(
		_merge_unique_strings(
			commander_state.get("specialty_focus_ids", []),
			commander_seed.get("specialty_focus_ids", hero_template.get("specialty_focus_ids", []))
		)
	)
	commander_state["level"] = max(1, int(commander_state.get("level", commander_seed.get("level", 1))))
	commander_state["experience"] = max(0, int(commander_state.get("experience", commander_seed.get("experience", 0))))
	commander_state["next_level_experience"] = max(
		250,
		int(commander_state.get("next_level_experience", commander_seed.get("next_level_experience", 250)))
	)
	commander_state["pending_specialty_choices"] = commander_state.get(
		"pending_specialty_choices",
		commander_seed.get("pending_specialty_choices", [])
	)
	commander_state["last_outcome"] = String(
		commander_state.get("last_outcome", commander_seed.get("last_outcome", ""))
	)
	commander_state["artifacts"] = ArtifactRulesScript.normalize_hero_artifacts(
		commander_state.get("artifacts", commander_seed.get("artifacts", {}))
	)
	commander_state = _normalize_enemy_progression(commander_state)
	var commander_spellbook = commander_state.get("spellbook", {})
	if not (commander_spellbook is Dictionary):
		commander_spellbook = {}
	return _apply_commander_army_metadata(
		_apply_commander_record_metadata(
			_apply_commander_memory_metadata(
				SpellRulesScript.ensure_hero_spellbook(
					commander_state,
					{
						"command": commander_state.get("command", {}),
						"starting_spell_ids": _merge_unique_strings(
							commander_spellbook.get("known_spell_ids", []),
							_merge_unique_strings(
								_hero_starting_spell_ids(hero_template),
								encounter_commander.get("starting_spell_ids", [])
							)
						),
					}
				),
				_normalized_commander_memory(roster_entry, commander_state)
			),
			_normalized_commander_record(roster_entry, commander_state)
		),
		_normalized_commander_army_continuity(
			roster_entry,
			commander_state,
			String(encounter.get("encounter_id", encounter.get("id", "")))
		)
	)

static func raid_commander_display_name(encounter: Dictionary) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.raid_commander_display_name", [encounter])

static func raid_display_name(encounter: Dictionary) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules.raid_display_name", [encounter])

static func raid_commander_summaries(encounters: Array, limit: int = 2) -> Array:
	var names: Array = []
	for encounter in encounters:
		if not (encounter is Dictionary):
			continue
		var commander_name := raid_commander_display_name(encounter)
		if commander_name == "" or commander_name in names:
			continue
		names.append(commander_name)
		if limit > 0 and names.size() >= limit:
			break
	return names

static func _faction_commander_ids(faction_id: String) -> Array:
	var hero_ids: Array = []
	if faction_id == "":
		return hero_ids
	var faction = ContentService.get_faction(faction_id)
	for hero_id_value in faction.get("hero_ids", []):
		var hero_id := String(hero_id_value)
		if hero_id != "" and hero_id not in hero_ids:
			hero_ids.append(hero_id)
	return hero_ids

## hero_ids: an Array limits the map to those roster heroes (null: all).
static func _active_commander_map(
	session: SessionStateStoreScript.SessionData,
	faction_id: String = "",
	hero_ids: Variant = null
) -> Dictionary:
	var active: Dictionary = {}
	if session == null:
		return active
	var resolved_lookup := _resolved_encounter_lookup(session.overworld.get("resolved_encounters", []))
	var limited := hero_ids is Array
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if faction_id != "" and PlayerRules.raid_controller_id(encounter) != faction_id:
			continue
		if _placement_resolved(String(encounter.get("placement_id", "")), resolved_lookup):
			continue
		var commander_state = encounter.get("enemy_commander_state", {})
		if not (commander_state is Dictionary) or commander_state.is_empty():
			continue
		var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
		if roster_hero_id == "" or (limited and roster_hero_id not in hero_ids):
			continue
		active[roster_hero_id] = {
			"placement_id": String(encounter.get("placement_id", "")),
			"commander_state": commander_state.duplicate(true),
		}
	# Only a site or town holding a defender's state can add one (see the
	# defender entries), so the rest are skipped before the full check.
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or not town.has("ai_defender_commander_state"):
			continue
		var defender_entry := _active_town_defender_entry(session, town, faction_id)
		if defender_entry.is_empty():
			continue
		var defender_state: Dictionary = defender_entry.get("commander_state", {})
		var defender_roster_hero_id := String(defender_state.get("roster_hero_id", ""))
		if defender_roster_hero_id == "" or (limited and defender_roster_hero_id not in hero_ids):
			continue
		active[defender_roster_hero_id] = defender_entry
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or not node.has("ai_defender_commander_state"):
			continue
		var defender_entry := _active_resource_defender_entry(session, node, faction_id)
		if defender_entry.is_empty():
			continue
		var defender_state: Dictionary = defender_entry.get("commander_state", {})
		var defender_roster_hero_id := String(defender_state.get("roster_hero_id", ""))
		if defender_roster_hero_id == "" or (limited and defender_roster_hero_id not in hero_ids):
			continue
		active[defender_roster_hero_id] = defender_entry
	return active

static func _normalize_town_defender_commander_states(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var towns = session.overworld.get("towns", [])
	if not (towns is Array):
		return
	var changed := false
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if not _town_has_ai_defender(town):
			continue
		if _active_town_defender_entry(session, town).is_empty():
			town = town.duplicate(true)
			_clear_town_defender_metadata(town)
			towns[index] = town
			changed = true
	if changed:
		session.overworld["towns"] = towns

static func _town_has_ai_defender(town: Dictionary) -> bool:
	return (
		town.has("ai_defender_commander_state")
		or String(town.get("ai_defender_roster_hero_id", "")) != ""
		or String(town.get("ai_defended_by_faction_id", "")) != ""
	)

static func _active_town_defender_entry(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	faction_filter: String = ""
) -> Dictionary:
	if session == null or town.is_empty():
		return {}
	var commander_state = town.get("ai_defender_commander_state", {})
	if not (commander_state is Dictionary) or commander_state.is_empty():
		return {}
	var roster_hero_id := String(commander_state.get("roster_hero_id", town.get("ai_defender_roster_hero_id", "")))
	if roster_hero_id == "":
		return {}
	var faction_id := PlayerRules.defender_controller_id(town)
	if faction_id == "":
		faction_id = _town_controller_faction_id(town)
	if faction_filter != "" and faction_id != faction_filter:
		return {}
	if String(town.get("owner", "neutral")) != "enemy" or _town_controller_faction_id(town) != faction_id:
		return {}
	var front: Dictionary = town.get("front", {}) if town.get("front", {}) is Dictionary else {}
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
	var raw_front_state := String(front.get("state", ""))
	if raw_front_state not in ["defend", "stabilizing"]:
		return {}
	if not bool(front_state.get("active", false)) or String(front_state.get("mode", "")) != "stabilizing":
		return {}
	if PlayerRules.controller_id(front_state) != "" and PlayerRules.controller_id(front_state) != faction_id:
		return {}
	var defense_until: int = max(
		int(town.get("ai_defense_until_day", 0)),
		int(front.get("defense_until_day", 0))
	)
	if defense_until < int(session.day):
		return {}
	var entry_state: Dictionary = commander_state.duplicate(true)
	entry_state["roster_hero_id"] = roster_hero_id
	entry_state.merge(PlayerRules.identity_fields(session, faction_id), true)
	return {
		"placement_id": "town_defense:%s" % String(town.get("placement_id", "")),
		"commander_state": entry_state,
	}

static func _clear_town_defender_metadata(town: Dictionary) -> void:
	town.erase("ai_defender_commander_state")
	town.erase("ai_defender_roster_hero_id")
	town.erase("ai_defended_by_faction_id")
	town.erase("ai_defended_by_player_id")
	town.erase("ai_defended_day")
	town.erase("ai_defense_until_day")
	town.erase("ai_defense_rating")
	town.erase("ai_defense_reinforced_strength")

static func _normalize_resource_defender_commander_states(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var nodes = session.overworld.get("resource_nodes", [])
	if not (nodes is Array):
		return
	var changed := false
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if not _resource_has_ai_defender(node):
			continue
		if _active_resource_defender_entry(session, node).is_empty():
			node = node.duplicate(true)
			_clear_resource_defender_metadata(node)
			nodes[index] = node
			changed = true
	if changed:
		session.overworld["resource_nodes"] = nodes

static func _resource_has_ai_defender(node: Dictionary) -> bool:
	return (
		node.has("ai_defender_commander_state")
		or String(node.get("ai_defender_roster_hero_id", "")) != ""
		or String(node.get("ai_defended_by_faction_id", "")) != ""
	)

static func _active_resource_defender_entry(
	session: SessionStateStoreScript.SessionData,
	node: Dictionary,
	faction_filter: String = ""
) -> Dictionary:
	if session == null or node.is_empty():
		return {}
	var commander_state = node.get("ai_defender_commander_state", {})
	if not (commander_state is Dictionary) or commander_state.is_empty():
		return {}
	var roster_hero_id := String(commander_state.get("roster_hero_id", node.get("ai_defender_roster_hero_id", "")))
	if roster_hero_id == "":
		return {}
	var faction_id := PlayerRules.defender_controller_id(node)
	if faction_filter != "" and faction_id != faction_filter:
		return {}
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if not _resource_site_is_persistent(site):
		return {}
	if faction_id == "" or PlayerRules.resource_controller_id(node) != faction_id:
		return {}
	var front: Dictionary = node.get("front", {}) if node.get("front", {}) is Dictionary else {}
	var raw_front_state := String(front.get("state", ""))
	var defense_until: int = max(
		int(node.get("ai_defense_until_day", 0)),
		int(front.get("defense_until_day", 0))
	)
	if defense_until < int(session.day):
		return {}
	if raw_front_state != "" and raw_front_state not in ["defend", "stabilizing"]:
		return {}
	var entry_state: Dictionary = commander_state.duplicate(true)
	entry_state["roster_hero_id"] = roster_hero_id
	entry_state.merge(PlayerRules.identity_fields(session, faction_id), true)
	return {
		"placement_id": "resource_defense:%s" % String(node.get("placement_id", "")),
		"commander_state": entry_state,
	}

static func _clear_resource_defender_metadata(node: Dictionary) -> void:
	node.erase("ai_defender_commander_state")
	node.erase("ai_defender_roster_hero_id")
	node.erase("ai_defender_army")
	node.erase("ai_defended_by_faction_id")
	node.erase("ai_defended_by_player_id")
	node.erase("ai_defended_day")
	node.erase("ai_defense_until_day")
	node.erase("ai_defense_rating")
	node.erase("ai_defense_reinforced_strength")

static func _normalize_commander_status(value: Variant) -> String:
	var status := String(value)
	if status in [COMMANDER_STATUS_AVAILABLE, COMMANDER_STATUS_ACTIVE, COMMANDER_STATUS_RECOVERING]:
		return status
	return COMMANDER_STATUS_AVAILABLE

static func _normalized_commander_record(entry_value: Variant, commander_state_value: Variant = {}) -> Dictionary:
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var commander_state: Dictionary = commander_state_value if commander_state_value is Dictionary else {}
	var deployments: int = max(0, max(int(entry.get("deployments", 0)), int(commander_state.get("deployments", 0))))
	var battle_wins: int = max(0, max(int(entry.get("battle_wins", 0)), int(commander_state.get("battle_wins", 0))))
	var times_defeated: int = max(0, max(int(entry.get("times_defeated", 0)), int(commander_state.get("times_defeated", 0))))
	var strategic_successes: int = max(0, max(int(entry.get("strategic_successes", 0)), int(commander_state.get("strategic_successes", 0))))
	var last_outcome := String(commander_state.get("last_outcome", ""))
	if last_outcome == "":
		last_outcome = String(entry.get("last_outcome", ""))
	var record := {
		"deployments": deployments,
		"battle_wins": battle_wins,
		"times_defeated": times_defeated,
		"strategic_successes": strategic_successes,
		"last_outcome": last_outcome,
	}
	record["renown"] = _commander_renown_from_record(record)
	return record

static func _normalized_commander_memory(entry_value: Variant, commander_state_value: Variant = {}) -> Dictionary:
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var commander_state: Dictionary = commander_state_value if commander_state_value is Dictionary else {}
	var entry_commander_state = entry.get("commander_state", {})
	if not (entry_commander_state is Dictionary):
		entry_commander_state = {}
	var raw_memory: Dictionary = {}
	for key in [
		"focus_target_kind",
		"focus_target_id",
		"focus_target_label",
		"focus_pressure_count",
		"last_target_kind",
		"last_target_id",
		"last_target_label",
		"front_label",
		"front_x",
		"front_y",
		"rival_kind",
		"rival_id",
		"rival_label",
		"rivalry_count",
		"target_success_counts",
		"target_failure_counts",
		"last_success_target_kind",
		"last_success_outcome",
		"last_failure_target_kind",
		"last_failure_outcome",
	]:
		if entry.has(key):
			raw_memory[String(key)] = entry[key]
	for source_value in [
		entry.get("target_memory", {}),
		entry_commander_state.get("target_memory", {}),
		commander_state.get("target_memory", {}),
	]:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		for key in source.keys():
			raw_memory[String(key)] = source[key]
	var memory := {
		"focus_target_kind": String(raw_memory.get("focus_target_kind", "")),
		"focus_target_id": String(raw_memory.get("focus_target_id", "")),
		"focus_target_label": String(raw_memory.get("focus_target_label", "")),
		"focus_pressure_count": max(0, int(raw_memory.get("focus_pressure_count", 0))),
		"last_target_kind": String(raw_memory.get("last_target_kind", "")),
		"last_target_id": String(raw_memory.get("last_target_id", "")),
		"last_target_label": String(raw_memory.get("last_target_label", "")),
		"front_label": String(raw_memory.get("front_label", "")),
		"front_x": int(raw_memory.get("front_x", 0)),
		"front_y": int(raw_memory.get("front_y", 0)),
		"rival_kind": String(raw_memory.get("rival_kind", "")),
		"rival_id": String(raw_memory.get("rival_id", "")),
		"rival_label": String(raw_memory.get("rival_label", "")),
		"rivalry_count": max(0, int(raw_memory.get("rivalry_count", 0))),
		"target_success_counts": _normalized_commander_target_kind_counts(raw_memory.get("target_success_counts", {})),
		"target_failure_counts": _normalized_commander_target_kind_counts(raw_memory.get("target_failure_counts", {})),
		"last_success_target_kind": String(raw_memory.get("last_success_target_kind", "")),
		"last_success_outcome": String(raw_memory.get("last_success_outcome", "")),
		"last_failure_target_kind": String(raw_memory.get("last_failure_target_kind", "")),
		"last_failure_outcome": String(raw_memory.get("last_failure_outcome", "")),
	}
	if (
		String(memory.get("focus_target_id", "")) == ""
		and String(memory.get("last_target_id", "")) == ""
		and String(memory.get("rival_id", "")) == ""
		and String(memory.get("front_label", "")) == ""
		and int(memory.get("focus_pressure_count", 0)) <= 0
		and int(memory.get("rivalry_count", 0)) <= 0
		and (memory.get("target_success_counts", {}) as Dictionary).is_empty()
		and (memory.get("target_failure_counts", {}) as Dictionary).is_empty()
		and String(memory.get("last_success_target_kind", "")) == ""
		and String(memory.get("last_failure_target_kind", "")) == ""
	):
		return {}
	return memory

static func _normalized_commander_target_kind_counts(value: Variant) -> Dictionary:
	var counts := {}
	if not (value is Dictionary):
		return counts
	for key_value in value.keys():
		var key := String(key_value)
		if not ["resource", "town", "artifact", "encounter", "hero"].has(key):
			continue
		var count := clampi(int(value[key_value]), 0, 9)
		if count > 0:
			counts[key] = count
	return counts

static func _commander_renown_from_record(record: Dictionary) -> int:
	var deployments: int = max(0, int(record.get("deployments", 0)))
	var battle_wins: int = max(0, int(record.get("battle_wins", 0)))
	var times_defeated: int = max(0, int(record.get("times_defeated", 0)))
	var strategic_successes: int = max(0, int(record.get("strategic_successes", 0)))
	return clamp((deployments + (battle_wins * 2) + int(floor(float(strategic_successes) / 2.0))) - times_defeated, 0, 9)

static func _commander_veterancy_rank_from_record(record: Dictionary) -> int:
	var deployments: int = max(0, int(record.get("deployments", 0)))
	var battle_wins: int = max(0, int(record.get("battle_wins", 0)))
	var renown: int = max(0, int(record.get("renown", _commander_renown_from_record(record))))
	if battle_wins >= 3 or renown >= 8:
		return 3
	if battle_wins >= 2 or renown >= 5:
		return 2
	if battle_wins >= 1 or deployments >= 2 or renown >= 2:
		return 1
	return 0

static func _apply_commander_record_metadata(commander_state: Dictionary, record_source: Variant) -> Dictionary:
	var commander := commander_state.duplicate(true)
	var record := _normalized_commander_record(record_source, commander)
	commander["deployments"] = max(0, int(record.get("deployments", 0)))
	commander["battle_wins"] = max(0, int(record.get("battle_wins", 0)))
	commander["times_defeated"] = max(0, int(record.get("times_defeated", 0)))
	commander["strategic_successes"] = max(0, int(record.get("strategic_successes", 0)))
	commander["renown"] = max(0, int(record.get("renown", 0)))
	commander["veterancy_rank"] = _commander_veterancy_rank_from_record(record)
	commander["veterancy_label"] = commander_veterancy_label(record)
	commander["record_summary"] = commander_record_summary(record)
	commander["last_outcome"] = String(record.get("last_outcome", commander.get("last_outcome", "")))
	return commander

static func _apply_commander_memory_metadata(commander_state: Dictionary, memory_source: Variant) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var commander := commander_state.duplicate(true)
	var memory := _normalized_commander_memory(memory_source)
	if memory.is_empty():
		memory = _normalized_commander_memory(commander)
	commander["target_memory"] = memory
	commander["memory_brief"] = commander_memory_brief(memory)
	commander["memory_summary"] = commander_memory_summary(memory)
	return commander

static func commander_live_role_state(source: Variant) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules.commander_live_role_state", [source])

static func _normalized_commander_role_state(source: Variant, fallback_source: Variant = {}) -> Dictionary:
	var source_dict: Dictionary = source if source is Dictionary else {}
	var fallback_dict: Dictionary = fallback_source if fallback_source is Dictionary else {}
	var role_value: Variant = source_dict.get("commander_role_state", {})
	if not (role_value is Dictionary) and source_dict.get("commander_state", {}) is Dictionary:
		role_value = source_dict.get("commander_state", {}).get("commander_role_state", {})
	if not (role_value is Dictionary):
		role_value = fallback_dict.get("commander_role_state", {})
	if not (role_value is Dictionary) and fallback_dict.get("commander_state", {}) is Dictionary:
		role_value = fallback_dict.get("commander_state", {}).get("commander_role_state", {})
	if not (role_value is Dictionary):
		return {}
	var role_payload: Dictionary = role_value
	var role := String(role_payload.get("role", ""))
	if role not in [
		COMMANDER_ROLE_RAIDER,
		COMMANDER_ROLE_DEFENDER,
		COMMANDER_ROLE_RETAKER,
		COMMANDER_ROLE_STABILIZER,
		COMMANDER_ROLE_SCOUT,
		COMMANDER_ROLE_RECOVERING,
		COMMANDER_ROLE_RESERVE,
	]:
		role = ""
	var target_kind := String(role_payload.get("target_kind", ""))
	var target_id := String(role_payload.get("target_id", ""))
	if role == "" and target_kind == "" and target_id == "":
		return {}
	return {
		"role": role if role != "" else COMMANDER_ROLE_RESERVE,
		"role_status": String(role_payload.get("role_status", "")),
		"task_class": String(role_payload.get("task_class", "")),
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": String(role_payload.get("target_label", target_id)),
		"front_id": String(role_payload.get("front_id", "")),
		"origin_id": String(role_payload.get("origin_id", "")),
		"assigned_day": max(0, int(role_payload.get("assigned_day", 0))),
		"expires_day": max(0, int(role_payload.get("expires_day", 0))),
		"last_validation": String(role_payload.get("last_validation", "valid")),
		"reason_codes": _normalize_string_array(role_payload.get("reason_codes", [])),
		"source_policy": String(role_payload.get("source_policy", "live")),
	}

static func _apply_commander_role_metadata(commander_state: Dictionary, role_source: Variant) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var commander := commander_state.duplicate(true)
	var role_state := _normalized_commander_role_state(role_source, commander)
	if role_state.is_empty():
		commander.erase("commander_role_state")
	else:
		commander["commander_role_state"] = role_state
	return commander

static func _normalized_commander_army_continuity(
	entry_value: Variant,
	commander_state_value: Variant = {},
	encounter_id: String = ""
) -> Dictionary:
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var commander_state: Dictionary = commander_state_value if commander_state_value is Dictionary else {}
	var entry_commander_state = entry.get("commander_state", {})
	if not (entry_commander_state is Dictionary):
		entry_commander_state = {}
	var raw_continuity: Dictionary = {}
	var continuity_sources := []
	if _is_army_continuity_payload(entry):
		continuity_sources.append(entry)
	continuity_sources.append(entry.get("army_continuity", {}))
	continuity_sources.append(entry_commander_state.get("army_continuity", {}))
	continuity_sources.append(commander_state.get("army_continuity", {}))
	for source_value in continuity_sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		for key in source.keys():
			raw_continuity[String(key)] = source[key]
	var resolved_encounter_id := String(raw_continuity.get("encounter_id", encounter_id))
	var normalized_payload := _normalize_army_payload({"stacks": raw_continuity.get("stacks", [])})
	var stacks: Array = normalized_payload.get("stacks", [])
	var base_strength: int = max(0, int(raw_continuity.get("base_strength", 0)))
	if base_strength <= 0 and resolved_encounter_id != "":
		base_strength = _army_strength(_base_enemy_army(resolved_encounter_id).get("stacks", []))
	if base_strength <= 0 and stacks.is_empty():
		return {}
	if base_strength <= 0:
		base_strength = _army_strength(stacks)
	var current_strength: int = _army_strength(stacks)
	var status := String(raw_continuity.get("status", ""))
	if status == "":
		status = _army_continuity_status(current_strength, base_strength)
	var strength_percent := 100 if base_strength <= 0 else int(round((float(current_strength) * 100.0) / float(base_strength)))
	return {
		"encounter_id": resolved_encounter_id,
		"stacks": stacks.duplicate(true),
		"base_strength": base_strength,
		"current_strength": current_strength,
		"rebuild_need": max(0, base_strength - current_strength),
		"strength_percent": clamp(strength_percent, 0, 100),
		"status": status,
		"headcount": _army_headcount(stacks),
		"company_count": stacks.size(),
		"summary": _army_continuity_summary(status, current_strength, base_strength),
	}

static func _is_army_continuity_payload(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var payload: Dictionary = value
	return (
		payload.has("base_strength")
		or payload.has("current_strength")
		or payload.has("rebuild_need")
		or payload.has("strength_percent")
		or payload.has("stacks")
	)

static func sync_commander_army_continuity(
	commander_state: Dictionary,
	army_source: Variant,
	encounter_id: String = ""
) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var updated := commander_state.duplicate(true)
	var continuity := _normalized_commander_army_continuity(updated, updated, encounter_id)
	var army_payload: Variant = army_source if army_source is Dictionary else {"stacks": army_source}
	var explicit_stacks: bool = (
		army_payload is Dictionary
		and army_payload.has("stacks")
		and army_payload.get("stacks", []) is Array
	)
	var normalized_army := _normalize_army_payload(army_payload)
	var stacks: Array = []
	if normalized_army.has("stacks"):
		stacks = normalized_army.get("stacks", [])
	elif explicit_stacks:
		stacks = []
	else:
		stacks = continuity.get("stacks", [])
	var resolved_encounter_id := encounter_id if encounter_id != "" else String(continuity.get("encounter_id", ""))
	var base_strength: int = max(
		int(continuity.get("base_strength", 0)),
		_army_strength(_base_enemy_army(resolved_encounter_id).get("stacks", []))
	)
	if base_strength <= 0:
		base_strength = _army_strength(stacks)
	if base_strength <= 0 and stacks.is_empty():
		return _apply_commander_army_metadata(updated, {})
	var current_strength: int = _army_strength(stacks)
	var status := _army_continuity_status(current_strength, base_strength)
	updated["army_continuity"] = {
		"encounter_id": resolved_encounter_id,
		"stacks": stacks.duplicate(true),
		"base_strength": base_strength,
		"current_strength": current_strength,
		"rebuild_need": max(0, base_strength - current_strength),
		"strength_percent": 100 if base_strength <= 0 else clamp(
			int(round((float(current_strength) * 100.0) / float(base_strength))),
			0,
			100
		),
		"status": status,
		"headcount": _army_headcount(stacks),
		"company_count": stacks.size(),
	}
	return _apply_commander_army_metadata(updated, updated)

static func _apply_commander_army_metadata(commander_state: Dictionary, army_source: Variant) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var commander := commander_state.duplicate(true)
	var continuity := _normalized_commander_army_continuity(army_source, commander)
	commander["army_continuity"] = continuity
	commander["army_status"] = String(continuity.get("status", ""))
	commander["army_brief"] = commander_army_brief(continuity)
	commander["army_summary"] = commander_army_summary(continuity)
	commander["army_base_strength"] = max(0, int(continuity.get("base_strength", 0)))
	commander["army_current_strength"] = max(0, int(continuity.get("current_strength", 0)))
	commander["army_rebuild_need"] = max(0, int(continuity.get("rebuild_need", 0)))
	return commander

static func _army_continuity_status(current_strength: int, base_strength: int) -> String:
	if base_strength <= 0:
		return ""
	if current_strength <= 0:
		return "shattered"
	if current_strength >= base_strength:
		return "ready"
	if (float(current_strength) / float(base_strength)) >= 0.7:
		return "scarred"
	return "rebuilding"

static func _army_continuity_summary(status: String, current_strength: int, base_strength: int) -> String:
	if base_strength <= 0:
		return ""
	var prefix := "Battle-ready host"
	match status:
		"shattered":
			prefix = "Shattered host"
		"rebuilding":
			prefix = "Rebuilding host"
		"scarred":
			prefix = "Scarred host"
	return "%s %d/%d" % [prefix, max(0, current_strength), max(0, base_strength)]

static func _army_headcount(stacks: Variant) -> int:
	var count := 0
	if not (stacks is Array):
		return count
	for stack_value in stacks:
		if not (stack_value is Dictionary):
			continue
		count += max(0, int(stack_value.get("count", 0)))
	return count

static func _normalize_enemy_progression(commander_state: Dictionary) -> Dictionary:
	var commander := HeroProgressionRulesScript.ensure_hero_progression(commander_state.duplicate(true))
	var guard := 0
	# commander stays progression-ensured: the ensure above, then choose_specialty's result.
	while HeroProgressionRulesScript.raw_pending_choices_remaining(commander) > 0 and guard < 8:
		var pending_choice := HeroProgressionRulesScript.current_pending_choice(commander)
		if pending_choice.is_empty():
			break
		var chosen_specialty := _preferred_enemy_specialty_id(commander, pending_choice)
		if chosen_specialty == "":
			break
		var choice_result := HeroProgressionRulesScript.choose_specialty(commander, chosen_specialty)
		commander = choice_result.get("hero", commander)
		guard += 1
	return HeroProgressionRulesScript.ensure_hero_progression(commander) if guard > 0 else commander

## A computer commander's pick: its focus specialties first, then those of
## its command path, battle and magic ones over adventure ones (whose economy
## and map effects reach only player heroes so far), and ranking up what it
## holds over starting something new.
static func _preferred_enemy_specialty_id(commander_state: Dictionary, pending_choice: Dictionary) -> String:
	var options = pending_choice.get("options", [])
	if not (options is Array) or options.is_empty():
		return ""
	_sync_specialty_pick()
	var focus: Array = commander_state.get("specialty_focus_ids", []) if commander_state.get("specialty_focus_ids", []) is Array else []
	var path := HeroProgressionRulesScript.command_path(commander_state)
	var best := String(options[0])
	var best_score := -1.0
	for option in options:
		var specialty_id := String(option)
		var specialty := HeroProgressionRulesScript.specialty_definition(specialty_id)
		var score := 0.0
		if specialty_id in focus:
			score += SPECIALTY_FOCUS_SCORE
		if String(specialty.get("path", "any")) == path:
			score += SPECIALTY_PATH_SCORE
		if String(specialty.get("group", "")) != "adventure":
			score += SPECIALTY_NOT_ADVENTURE_SCORE
		if HeroProgressionRulesScript.specialty_rank(commander_state, specialty_id) > 0:
			score += SPECIALTY_RANK_UP_SCORE
		if score > best_score:
			best_score = score
			best = specialty_id
	return best

static func _sync_specialty_pick() -> void:
	var revision: int = ContentService.get_content_revision()
	if revision == _specialty_pick_revision:
		return
	var pick: Dictionary = ContentService.load_json(ContentService.AI_HERO_WEIGHTS_PATH)["specialty_pick"]
	SPECIALTY_FOCUS_SCORE = float(pick["focus"])
	SPECIALTY_PATH_SCORE = float(pick["path"])
	SPECIALTY_NOT_ADVENTURE_SCORE = float(pick["not_adventure"])
	SPECIALTY_RANK_UP_SCORE = float(pick["rank_up"])
	_specialty_pick_revision = revision

## The AI weights read here (DWELLING_HIRE_MIN_VALUE) from a computer player's
## weight set; AiHeroRules._apply_weights calls it.
static func apply_ai_weights(weights: Dictionary) -> void:
	DWELLING_HIRE_MIN_VALUE = int(weights["dwelling_hire_min_value"])
	_ai_weights_ready = true

static func _normalized_specialty_ranks(primary: Variant, secondary: Variant = []) -> Array:
	# Each known specialty up to its max rank, secondary first.
	var normalized := []
	for source in [secondary, primary]:
		if not (source is Array):
			continue
		for specialty_value in source:
			var specialty_id := String(specialty_value)
			if not HeroProgressionRulesScript.has_specialty(specialty_id):
				continue
			if normalized.count(specialty_id) < HeroProgressionRulesScript.max_rank_for_specialty(specialty_id):
				normalized.append(specialty_id)
	return normalized

static func _normalized_specialty_focus_ids(value: Variant) -> Array:
	var normalized := []
	if not (value is Array):
		return normalized
	for specialty_value in value:
		var specialty_id := String(specialty_value)
		if specialty_id == "" or specialty_id in normalized:
			continue
		if not HeroProgressionRulesScript.has_specialty(specialty_id):
			continue
		normalized.append(specialty_id)
	return normalized

static func _hero_starting_spell_ids(hero_template: Dictionary) -> Array:
	var spell_ids := []
	for spell_id_value in hero_template.get("starting_spell_ids", []):
		var spell_id := String(spell_id_value)
		if spell_id == "":
			continue
		if ContentService.get_spell(spell_id).is_empty():
			continue
		if spell_id not in spell_ids:
			spell_ids.append(spell_id)
	return spell_ids

static func _normalize_command_payload(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"attack": 0, "defense": 0, "power": 0, "knowledge": 0}
	return {
		"attack": max(0, int(value.get("attack", 0))),
		"defense": max(0, int(value.get("defense", 0))),
		"power": max(0, int(value.get("power", 0))),
		"knowledge": max(0, int(value.get("knowledge", 0))),
	}

static func _merge_unique_strings(primary: Variant, secondary: Variant) -> Array:
	var merged := []
	for source in [primary, secondary]:
		if not (source is Array):
			continue
		for entry in source:
			var text := String(entry)
			if text != "" and text not in merged:
				merged.append(text)
	return merged

static func _preferred_commander_index_for_encounter(encounter: Dictionary) -> int:
	return TurnEngine.native_writing(&"EnemyAdventureRules._preferred_commander_index_for_encounter", [encounter])

static func public_strategy_summary(config: Dictionary, faction_id: String) -> String:
	match faction_id:
		"faction_embercourt":
			if not (config.get("priority_target_placement_ids", []) is Array) or config.get("priority_target_placement_ids", []).is_empty():
				return "Priorities: hold towns, reinforce outposts, and grind forward on siege lanes"
			return "Priorities: stabilize the line, defend charter assets, and press key crossings"
		"faction_mireclaw":
			return "Priorities: cut logistics sites, chase exposed heroes, and keep their heroes on the move"
		"faction_sunvault":
			return "Priorities: secure relays and shrines, then align focused pushes on objectives"
		"faction_thornwake":
			return "Priorities: root roads, hold nurseries, and turn neutral lanes into recovery zones"
		"faction_brasshollow":
			return "Priorities: secure mines, stage siege engines, and exhaust resource fronts"
		"faction_veilmourn":
			return "Priorities: scout hidden routes, mark weak backs, and strike through fog lanes"
		_:
			return "Priorities: pressure objectives while contesting frontier assets"

static func target_is_objective_anchor(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> bool:
	return TurnEngine.native_writing(&"EnemyAdventureRules.target_is_objective_anchor", [session, target_kind, placement_id])

static func raid_strength(encounter: Dictionary) -> int:
	return TurnEngine.native_writing(&"EnemyAdventureRules.raid_strength", [encounter])

static func _find_player_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._find_player_hero", [session, hero_id])

static func ai_public_event_log(events_value: Variant, limit: int = 6) -> Array:
	var public_events := []
	if not (events_value is Array):
		return public_events
	for event_value in events_value:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var public_event := ai_public_event_log_entry(event)
		if public_event.is_empty():
			continue
		var leak_check := ai_public_event_log_leak_check([public_event])
		if not bool(leak_check.get("ok", false)):
			continue
		public_events.append(public_event)
		if public_events.size() >= max(1, limit):
			break
	return public_events

static func ai_public_event_log_entry(event: Dictionary) -> Dictionary:
	var event_type := String(event.get("event_type", ""))
	if event_type not in AI_PUBLIC_EVENT_LOG_TYPES:
		return {}
	var visibility := String(event.get("visibility", ""))
	if visibility == "hidden_debug":
		return {}
	var reason_codes: Array = _normalize_string_array(event.get("reason_codes", []))
	var public_reason := _public_event_log_text(String(event.get("public_reason", "")))
	if public_reason == "":
		public_reason = _public_event_log_text(_public_reason_from_codes(reason_codes))
	var faction_label := _public_event_log_text(String(event.get("faction_label", event.get("faction_id", ""))))
	var actor_label := _public_event_log_text(String(event.get("actor_label", "")))
	var target_label := _public_event_log_text(String(event.get("target_label", event.get("target_id", ""))))
	var summary := _public_event_log_text(String(event.get("summary", "")))
	if summary == "":
		summary = _public_event_log_text(
			_ai_event_summary(
				event_type,
				faction_label,
				actor_label,
				target_label,
				public_reason
			)
		)
	if summary == "" and target_label == "":
		return {}
	var public_event := {
		"day": int(event.get("day", 0)),
		"event_type": event_type,
		"faction_id": _public_event_log_text(String(event.get("faction_id", ""))),
		"faction_label": faction_label,
		"actor_label": actor_label,
		"target_kind": _public_event_log_text(String(event.get("target_kind", ""))),
		"target_id": _public_event_log_text(String(event.get("target_id", ""))),
		"target_label": target_label,
		"visibility": visibility,
		"public_importance": _public_event_log_text(String(event.get("public_importance", "low"))),
		"summary": summary,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
	}
	if String(event.get("player_id", "")) != "":
		public_event["player_id"] = _public_event_log_text(String(event.player_id))
	return public_event

static func ai_public_event_log_boundary_report(events_value: Variant, limit: int = 6) -> Dictionary:
	var source_count := 0
	if events_value is Array:
		source_count = events_value.size()
	var public_events := ai_public_event_log(events_value, limit)
	var leak_check := ai_public_event_log_leak_check(public_events)
	var meaningful_count := 0
	for event_value in public_events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		if String(event.get("event_type", "")) != "" and String(event.get("summary", "")) != "" and not _normalize_string_array(event.get("reason_codes", [])).is_empty():
			meaningful_count += 1
	return {
		"ok": bool(leak_check.get("ok", false)) and meaningful_count == public_events.size(),
		"boundary_id": "strategic-ai-public-event-log-boundary-10184",
		"source_event_count": source_count,
		"public_event_count": public_events.size(),
		"meaningful_public_event_count": meaningful_count,
		"limit": max(1, limit),
		"storage_policy": "derived_ephemeral_report_only",
		"durable_log_selected": false,
		"save_migration_required": false,
		"allowed_public_key_count": AI_PUBLIC_EVENT_LOG_KEYS.size(),
		"blocked_token_count": AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS.size(),
		"leak_check": leak_check,
		"public_events": public_events,
	}

static func ai_public_event_log_leak_check(public_surfaces: Variant) -> Dictionary:
	var stack := [public_surfaces]
	var checked_events := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if value is Dictionary:
			if String(value.get("event_type", "")) != "":
				checked_events += 1
				for key in value.keys():
					if String(key) not in AI_PUBLIC_EVENT_LOG_KEYS:
						return {"ok": false, "error": "%s leaked public-log key %s" % [value.get("event_type", "event"), key]}
			var text := JSON.stringify(value)
			for token in AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS:
				if text.contains(String(token)):
					return {"ok": false, "error": "%s leaked blocked public-log token %s" % [value.get("event_type", "event"), token]}
			for nested_key in value.keys():
				var nested = value[nested_key]
				if nested is Array or nested is Dictionary:
					stack.append(nested)
			continue
		var value_text := String(value)
		for token in AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS:
			if value_text.contains(String(token)):
				return {"ok": false, "error": "public log leaked token %s" % String(token)}
	return {
		"ok": true,
		"checked_events": checked_events,
		"allowed_public_key_count": AI_PUBLIC_EVENT_LOG_KEYS.size(),
		"blocked_token_count": AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS.size(),
	}

static func _public_reason_from_codes(reason_codes: Array) -> String:
	var codes := _normalize_string_array(reason_codes)
	if "regroup_understrength" in codes:
		return "regrouping understrength host"
	if "town_defense" in codes:
		return "defending threatened town"
	if "site_defense" in codes:
		return "defending held site"
	if "front_stabilization" in codes:
		return "front stabilization"
	if "frontier_scouting" in codes or "search_contact" in codes or "no_known_targets" in codes:
		return "scouting the frontier"
	if "retake_front" in codes:
		return "retaking captured town"
	if "town_expansion" in codes or "neutral_town_claim" in codes:
		return "neutral town expansion"
	if "resource_risk_staging" in codes or "resource_risk_regroup" in codes:
		return "gathering strength for resource claim"
	if "town_siege" in codes:
		return "town siege remains the main front"
	if "persistent_income_denial" in codes and "recruit_denial" in codes:
		return "recruit and income denial"
	if "persistent_income_denial" in codes and "route_vision" in codes:
		return "income and route vision denial"
	if "persistent_income_denial" in codes:
		return "income denial"
	if "resource_scarcity" in codes:
		return "seeking scarce resources"
	if "recruit_denial" in codes:
		return "recruit denial"
	if "route_vision" in codes:
		return "route vision denial"
	if "route_pressure" in codes:
		return "route pressure"
	if "objective_front" in codes:
		return "objective front"
	if "site_seized" in codes:
		return "site seized"
	if "site_contested" in codes:
		return "site contested"
	if "artifact_secured" in codes:
		return "artifact secured"
	if "commander_memory" in codes:
		return "known commander focus"
	if "enemy_scouting" in codes:
		return "scouted target"
	return ""

static func _public_event_log_text(text: String) -> String:
	var output := text.strip_edges().replace("\n", " ")
	while output.find("  ") >= 0:
		output = output.replace("  ", " ")
	for token in AI_PUBLIC_EVENT_LOG_BLOCKED_TOKENS:
		if output.contains(String(token)):
			return ""
	return output

static func _ai_hero_task_finish_live_assignment(session: SessionStateStoreScript.SessionData, faction_id: String, raid: Dictionary, task_status: String, validation: String) -> void:
	TurnEngine.native_writing(&"EnemyAdventureRules._ai_hero_task_finish_live_assignment", [session, faction_id, raid, task_status, validation])

static func _ai_hero_task_retention_priority(task: Dictionary) -> int:
	match String(task.get("task_status", "")):
		"active", "reserved", "suspended":
			return 4
		"completed":
			return 3
		"planned":
			return 2
		"failed", "cancelled", "invalid":
			return 1
	return 0

static func _ai_event_summary(
	event_type: String,
	faction_label: String,
	actor_label: String,
	target_label: String,
	public_reason: String,
	summary_prefix: String = ""
) -> String:
	var actor_clause := actor_label if actor_label != "" else faction_label
	var reason_suffix := " (%s)" % public_reason if public_reason != "" else ""
	match event_type:
		"ai_target_assigned":
			var verb := summary_prefix if summary_prefix != "" else "targets"
			return "%s %s %s%s." % [actor_clause, verb, target_label, reason_suffix]
		"ai_site_seized":
			return "%s seizes %s%s." % [actor_clause, target_label, reason_suffix]
		"ai_site_contested":
			return "%s contests %s%s." % [actor_clause, target_label, reason_suffix]
		"ai_site_defended":
			return "%s defends %s%s." % [actor_clause, target_label, reason_suffix]
		"ai_town_captured":
			return "%s claims %s%s." % [actor_clause, target_label, reason_suffix]
		"ai_pressure_summary":
			return "%s pressure centers on %s%s." % [faction_label, target_label, reason_suffix]
		"ai_raid_grouped":
			return "%s consolidates on %s%s." % [actor_clause, target_label, reason_suffix]
		_:
			return "%s marks %s%s." % [actor_clause, target_label, reason_suffix]

static func _normalize_string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "" and text not in output:
			output.append(text)
	return output

static func _town_is_objective_anchor(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	return TurnEngine.native_writing(&"EnemyAdventureRules._town_is_objective_anchor", [session, placement_id])

static func _secure_resource_target(session: SessionStateStoreScript.SessionData, raid: Dictionary, state: Dictionary, faction_id: String, config: Dictionary = {}) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._secure_resource_target", [session, raid, state, faction_id, config])

static func _visit_key(faction_id: String) -> String:
	return "ai:%s" % faction_id

# A raid commander visits a stat, experience or spell building: the building
# stays neutral, the commander grows, and the faction cannot use it again
# until its cadence allows.
## A computer side fights the dwelling guard it has not yet beaten, settled the
## same way as its other neutral fights: a host at 90% of the guard's strength
## wins. Returns false when the guard still stands.
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

static func _is_active_raid(encounter: Variant, faction_id: String, resolved_encounters: Variant) -> bool:
	if not (encounter is Dictionary):
		return false
	if bool(encounter.get("raid_retired_to_rebuild", false)):
		return false
	var raid_faction = PlayerRules.raid_controller_id(encounter)
	if faction_id == "":
		if raid_faction == "":
			return false
	elif raid_faction != faction_id:
		return false
	var placement_id = String(encounter.get("placement_id", ""))
	return not _placement_resolved(placement_id, resolved_encounters)

static func is_active_pressure_host(encounter: Variant, faction_id: String = "", resolved_encounters: Variant = []) -> bool:
	if not _is_active_raid(encounter, faction_id, resolved_encounters):
		return false
	var raid: Dictionary = encounter
	if String(raid.get("difficulty", "")) == "pressure":
		return true
	if raid.has("days_active"):
		return true
	if String(raid.get("target_kind", "")) != "" and String(raid.get("target_placement_id", "")) != "":
		return true
	if bool(raid.get("commanderless_support_column", false)):
		return true
	var commander_state = raid.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		return true
	return String(raid.get("delivery_intercept_node_placement_id", "")) != ""

static func _encounter_is_pressure_host_candidate(encounter: Variant, faction_id: String = "", resolved_encounters: Variant = []) -> bool:
	if not (encounter is Dictionary):
		return false
	var raid: Dictionary = encounter
	if bool(raid.get("raid_retired_to_rebuild", false)):
		return false
	var placement_id := String(raid.get("placement_id", ""))
	if _is_active_raid(raid, faction_id, resolved_encounters):
		return true
	if _placement_resolved(placement_id, resolved_encounters):
		return false
	if PlayerRules.raid_controller_id(raid) != "":
		return true
	if String(raid.get("difficulty", "")) == "pressure":
		return true
	if raid.has("days_active"):
		return true
	if bool(raid.get("commanderless_support_column", false)):
		return true
	if String(raid.get("delivery_intercept_node_placement_id", "")) != "":
		return true
	var commander_state = raid.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		return true
	return placement_id.begins_with("faction_") and placement_id.find("_raid_") >= 0

static func _placement_resolved(placement_id: String, resolved_encounters: Variant) -> bool:
	# resolved_encounters is the session's list, or a lookup from
	# _resolved_encounter_lookup when a caller checks many encounters at once.
	if resolved_encounters is Dictionary:
		return resolved_encounters.has(placement_id)
	return resolved_encounters is Array and placement_id in resolved_encounters

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._find_town_by_placement", [session, placement_id])

static func _guard_link_for_encounter(encounter: Dictionary) -> Dictionary:
	var guard = encounter.get("guard_link", {})
	if guard is Dictionary and not guard.is_empty():
		return guard
	var neutral_metadata = encounter.get("neutral_encounter", {})
	if neutral_metadata is Dictionary:
		guard = neutral_metadata.get("guard_link", {})
		if guard is Dictionary:
			return guard
	return {}

## positions: an Array limits the scan to the encounters at these list
## positions, in ascending order, for a caller that knows no other encounter can
## match (AiHeroRules._encounter_guard_index); null scans them all.
static func _artifact_guard_encounter_for_node(session: SessionStateStoreScript.SessionData, node: Dictionary, positions: Variant = null) -> Dictionary:
	if session == null or node.is_empty():
		return {}
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var encounters = session.overworld.get("encounters", [])
	if positions is Array:
		var listed := []
		for position in positions:
			listed.append(encounters[int(position)])
		encounters = listed
	for encounter_value in encounters:
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		var guard := _guard_link_for_encounter(encounter)
		if not (
			(not guard.is_empty() and _artifact_guard_link_targets_node(guard, node))
			or _generated_object_guard_targets(encounter, "artifact", String(node.get("placement_id", "")))
		):
			continue
		if OverworldRulesScript.is_encounter_resolved(session, encounter):
			continue
		if _encounter_is_pressure_host_candidate(encounter, "", resolved_encounters):
			continue
		return encounter
	return {}

static func _artifact_guard_link_targets_node(guard: Dictionary, node: Dictionary) -> bool:
	var role := String(guard.get("guard_role", ""))
	var target_kind := String(guard.get("target_kind", ""))
	if role not in ["guards_reward", "guards_object"] and target_kind not in ["artifact", "artifact_node", "reward", "object"]:
		return false
	if not bool(guard.get("clear_required_for_target", false)) and not bool(guard.get("blocks_approach", false)):
		return false
	var node_placement_id := String(node.get("placement_id", ""))
	var artifact_id := String(node.get("artifact_id", ""))
	var target_placement_id := String(guard.get("target_placement_id", ""))
	var target_id := String(guard.get("target_id", ""))
	return (
		(target_placement_id != "" and target_placement_id == node_placement_id)
		or (target_id != "" and target_id in [node_placement_id, artifact_id])
	)

static func _generated_object_guard_targets(encounter: Dictionary, target_kind: String, target_placement_id: String) -> bool:
	if target_placement_id == "":
		return false
	if String(encounter.get("guarded_object_placement_id", "")) != target_placement_id:
		return false
	var guarded_kind := String(encounter.get("guarded_object_kind", ""))
	if target_kind == "artifact":
		return guarded_kind == "artifact"
	return guarded_kind in ["resource", "resource_site", "mine", "neutral_dwelling", "faction_outpost", "frontier_shrine", "reward_reference", "mine_placeholder"]

static func _resource_site_is_persistent(site: Dictionary) -> bool:
	return bool(site.get("persistent_control", false))

static func _resource_node_contestable_by_faction(node: Dictionary, site: Dictionary, faction_id: String, session: SessionStateStoreScript.SessionData = null) -> bool:
	if NativeTransit.is_native(node):
		return not NativeTransit.destinations(node).is_empty()
	if VisitBuildings.is_visit_building(site):
		return (
			session != null
			and VisitBuildings.cadence(site) != VisitBuildings.CADENCE_ALWAYS
			and VisitBuildings.ai_value(site) > 0
			and bool(VisitBuildings.readiness(node, site, _visit_key(faction_id), session.day).get("ok", false))
		)
	if CreatureDwellings.is_dwelling(site) and session != null and PlayerRules.resource_controller_id(node) == faction_id:
		if not _ai_weights_ready:
			apply_ai_weights(ContentService.default_ai_hero_weights())
		return CreatureDwellings.week_value(node, site, session.day, true) >= DWELLING_HIRE_MIN_VALUE
	if _resource_site_is_persistent(site):
		return not PlayerRules.allied(session, PlayerRules.resource_controller_id(node), faction_id)
	return not bool(node.get("collected", false))

static func _find_encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyAdventureRules._find_encounter_by_placement", [session, placement_id])

# Controlling player (or legacy faction key) of the town, matching
# EnemyTurnRules._town_controller_faction_id. Not the town's content faction.
static func _town_controller_faction_id(town_state: Dictionary) -> String:
	return TurnEngine.native_writing(&"EnemyAdventureRules._town_controller_faction_id", [town_state])

static func _base_enemy_army(encounter_id: String) -> Dictionary:
	var encounter = ContentService.get_encounter(encounter_id)
	if encounter.is_empty():
		return {}
	return _normalize_army_payload(ContentService.get_army_group(String(encounter.get("enemy_group_id", ""))))

static func _normalize_army_payload(army: Variant) -> Dictionary:
	if not (army is Dictionary):
		return {}
	var normalized_stacks = []
	for stack_value in army.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var unit_id = String(stack_value.get("unit_id", ""))
		var count: int = max(0, int(stack_value.get("count", 0)))
		if unit_id == "" or count <= 0:
			continue
		normalized_stacks.append({"unit_id": unit_id, "count": count})
	if normalized_stacks.is_empty():
		return {}
	return {
		"id": String(army.get("id", "")),
		"name": String(army.get("name", "Raid Host")),
		"stacks": normalized_stacks,
	}

static func _army_strength(stacks: Variant) -> int:
	var total = 0
	if not (stacks is Array):
		return total
	_sync_unit_strength_memo()
	for stack_value in stacks:
		if not (stack_value is Dictionary):
			continue
		var unit_id = String(stack_value.get("unit_id", ""))
		var count: int = max(0, int(stack_value.get("count", 0)))
		if unit_id == "" or count <= 0:
			continue
		total += _unit_strength_value(unit_id) * count
	return total

static func _unit_strength_value(unit_id: String) -> int:
	var strength = _unit_strength_memo.get(unit_id)
	if strength == null:
		var unit = ContentService.get_unit(unit_id)
		strength = max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
		_unit_strength_memo[unit_id] = strength
	return strength

## Roster normalization weighs every commander's army each pass, so unit
## strengths are memoized and dropped whenever the content cache reloads.
static var _unit_strength_memo := {}
static var _unit_strength_sources := []

static func _sync_unit_strength_memo() -> void:
	var sources := [ContentService.get_content_revision(), ContentService.load_json(ContentService.UNITS_PATH)]
	if _unit_strength_sources.size() != sources.size() or _unit_strength_sources[0] != sources[0] or not is_same(_unit_strength_sources[1], sources[1]):
		_unit_strength_memo = {}
		_unit_strength_sources = sources

static func _raid_is_public(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	if session == null:
		return false
	if bool(encounter.get("arrived", false)):
		if String(encounter.get("target_kind", "")) == "town":
			var town_result = _find_town_by_placement(session, String(encounter.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0 and String(town_result.get("town", {}).get("owner", "neutral")) == "player":
				return true
	if OverworldRulesScript.is_tile_visible(session, int(encounter.get("x", 0)), int(encounter.get("y", 0)), LevelRules.level_of(encounter)):
		return true
	return false

# --- Multi-level path surfaces ----------------------------------------------
# Distance fields over both map levels and native passages, with the occupancy
# an army sees. Live play does not call these: AiHeroRules plans its own routes
# on one level and weighs subterranean gates separately (docs/ai-plays-by-player-rules.md).
# The RMG transit and start placement validation tools plan journeys with them.

static func _player_hero_sheltered_in_town(session: SessionStateStoreScript.SessionData, hero: Dictionary) -> bool:
	if session == null or hero.is_empty():
		return false
	var hero_position: Dictionary = hero.get("position", {})
	var hero_x := int(hero_position.get("x", -1))
	var hero_y := int(hero_position.get("y", -1))
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary) or not LevelRules.same_level(town_value, hero):
			continue
		if String(town_value.get("owner", "neutral")) != "player":
			continue
		var entrance := LevelRules.town_entrance(town_value)
		if int(entrance.x) == hero_x and int(entrance.y) == hero_y:
			return true
	return false

static func _resource_interaction_tile(node: Dictionary) -> Vector2i:
	var visit_tile: Variant = node.get("visit_tile", {})
	if visit_tile is Dictionary and not visit_tile.is_empty():
		return Vector2i(
			int(visit_tile.get("x", node.get("x", 0))),
			int(visit_tile.get("y", node.get("y", 0)))
		)
	return Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))

static func _path_plan_toward(
	session: SessionStateStoreScript.SessionData,
	start: Vector2i,
	goal_tiles: Array,
	ignore_placement_id: String,
	observer_faction_id: String = "",
	goal_level: int = -1
) -> Dictionary:
	var unreachable := {
		"goal_distance": 9999,
		"next_step": start,
		"next_goal_distance": 9999,
		"goal_field_count": 0,
	}
	if goal_tiles.is_empty():
		return unreachable
	var path_context := _path_distance_surface_context(session, ignore_placement_id, observer_faction_id)
	var actor: Dictionary = _find_encounter_by_placement(session, ignore_placement_id).get("encounter", {})
	var destination_level := goal_level if goal_level >= 0 else _target_level(session, String(actor.get("target_kind", "")), String(actor.get("target_placement_id", "")), observer_faction_id, int(path_context.get("level", 0)))
	if path_context.has("native_navigation"):
		return _native_navigation_plan(path_context, start, goal_tiles, destination_level)
	if destination_level != int(path_context.get("level", 0)):
		return unreachable
	var map_size: Vector2i = path_context.get("map_size", OverworldRulesScript.derive_map_size(session))
	var encounter_blocked: Dictionary = path_context.get("encounter_blocked_indices", {})
	var resource_blocked: Dictionary = path_context.get("resource_blocked_indices", {})
	var hero_blocked: Dictionary = path_context.get("hero_blocked_indices", {})
	var terrain_blocked: Dictionary = path_context.get("terrain_blocked_indices", {})
	var start_index := _tile_index(start, map_size)
	if start_index < 0:
		return unreachable
	var goal_lookup := _tile_index_lookup(goal_tiles, map_size)
	if goal_lookup.has(start_index):
		return {
			"goal_distance": 0,
			"next_step": start,
			"next_goal_distance": 0,
			"goal_field_count": 0,
		}
	var goal_field_indexes := []
	for goal_index_value in goal_lookup.keys():
		var goal_index := int(goal_index_value)
		if goal_index < 0 or encounter_blocked.has(goal_index) or hero_blocked.has(goal_index):
			continue
		goal_field_indexes.append(goal_index)
	if goal_field_indexes.is_empty():
		return unreachable
	# One search seeded with every usable goal gives each tile its distance to
	# the nearest goal, the same minimum the per-goal fields produced.
	var goal_field := _path_distance_field_for_goals(path_context, goal_field_indexes)
	var best_step := start
	var best_distance := 9999
	for delta in PATH_MOVEMENT_DELTAS:
		var candidate: Vector2i = start + delta
		var candidate_index := _tile_index(candidate, map_size)
		if _position_blocked_index(candidate_index, goal_lookup, encounter_blocked, resource_blocked, hero_blocked, terrain_blocked):
			continue
		if _path_step_cuts_blocked_corner_index(start_index, candidate_index, map_size, encounter_blocked, resource_blocked, hero_blocked, terrain_blocked):
			continue
		var candidate_distance := 9999
		if candidate_index >= 0 and candidate_index < goal_field.size():
			var distance := int(goal_field[candidate_index])
			if distance >= 0:
				candidate_distance = distance
		if candidate_distance < best_distance:
			best_step = candidate
			best_distance = candidate_distance
	# A live raid can share its current tile with a visible hero or a body tile.
	# Distance fields may leave that occupied origin, while reverse fields cannot
	# enter it, so derive the current distance from the best legal exit.
	var current_distance := best_distance + 1 if best_step != start and best_distance < 9999 else 9999
	return {
		"goal_distance": current_distance,
		"next_step": best_step,
		"next_goal_distance": best_distance,
		"goal_field_count": goal_field_indexes.size(),
	}

static func clear_path_caches() -> void:
	_path_distance_surface_cache.clear()
	_native_navigation_surface_cache.clear()
	_enemy_turn_terrain_surfaces.clear()

static func _path_distance_surface_context(
	session: SessionStateStoreScript.SessionData,
	ignore_placement_id: String,
	observer_faction_id: String,
	level: int = -1
) -> Dictionary:
	if level < 0:
		level = OverworldRulesScript.placement_level(session, ignore_placement_id)
	# These synchronous reads do not mutate gameplay state. Compute the same
	# base identity once for this request, then preserve each level's exact key.
	# Nothing survives this call beyond the existing independently keyed caches.
	var base_key := _path_distance_surface_cache_key(session, ignore_placement_id, observer_faction_id, 0)
	var actor_blocked_indexes := {}
	var context := _local_path_distance_surface_context_for_key(session, ignore_placement_id, observer_faction_id, level, _path_distance_level_cache_key(base_key, level), actor_blocked_indexes)
	var navigation := _native_navigation_surface_for_key(session, ignore_placement_id, observer_faction_id, base_key, actor_blocked_indexes)
	if navigation.is_empty():
		return context
	var extended := context.duplicate(false)
	extended["native_navigation"] = navigation
	return extended

static func _native_navigation_surface_for_key(session: SessionStateStoreScript.SessionData, actor_id: String, observer: String, key: String, preloaded_actor_blocked_indexes: Variant = null) -> Dictionary:
	if _native_navigation_surface_cache.has(key):
		return _native_navigation_surface_cache[key]
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var native_nodes := []
	for node in nodes:
		if node is Dictionary and NativeTransit.is_native(node):
			native_nodes.append(node)
	var navigation := {}
	if not native_nodes.is_empty() or NativeTransit.uses_native_adjacency(session):
		var actor_blocked_indexes: Dictionary = preloaded_actor_blocked_indexes if preloaded_actor_blocked_indexes is Dictionary else {}
		var errors := NativeTransit.validate(nodes)
		if not errors.is_empty():
			# Invalid native contracts never become guessed local-offset paths.
			navigation = {"ok": false, "error": "invalid_native_navigation_contracts", "errors": errors}
		else:
			var size: Vector2i = OverworldRulesScript.derive_map_size(session)
			var levels := LevelRules.level_count(session)
			var surfaces := []
			var mask := PackedByteArray()
			for spatial_level in range(levels):
				var surface := _local_path_distance_surface_context_for_key(session, actor_id, observer, spatial_level, _path_distance_level_cache_key(key, spatial_level), actor_blocked_indexes)
				surfaces.append(surface)
				mask.append_array(_blocked_tile_mask(size.x * size.y, surface.encounter_blocked_indices, surface.resource_blocked_indices, surface.hero_blocked_indices, surface.terrain_blocked_indices))
			var safe := {}
			for node in native_nodes:
				if bool(OverworldRulesScript._native_passage_endpoint_safety(session, node, actor_id, actor_blocked_indexes).get("ok", false)):
					safe[String(node.get("placement_id", ""))] = true
			var links := []
			for node in native_nodes:
				var id := String(node.get("placement_id", ""))
				if not safe.has(id):
					continue
				for destination in NativeTransit.destinations(node):
					if not safe.has(String(destination.get("target_placement_id", ""))):
						continue
					var entry := NativeTransit.point(NativeTransit.link_of(node).get("entry"))
					var exit := NativeTransit.point(destination.get("exit"))
					var entry_index := NativeTransit.navigation_index(entry, size, levels)
					var exit_index := NativeTransit.navigation_index(exit, size, levels)
					if entry_index >= 0 and exit_index >= 0 and mask[entry_index] == 0 and mask[exit_index] == 0:
						links.append({"entry": LevelRules.position(entry), "exit": LevelRules.position(exit), "source_placement_id": id, "target_placement_id": destination.target_placement_id})
			navigation = {"ok": true, "map_size": size, "level_count": levels, "surfaces": surfaces, "blocked": mask, "links": links, "fields": {}, "native_adjacency": NativeTransit.uses_native_adjacency(session)}
	if _native_navigation_surface_cache.size() >= 32:
		_native_navigation_surface_cache.clear()
	_native_navigation_surface_cache[key] = navigation
	return navigation

static func _native_navigation_plan(context: Dictionary, start: Vector2i, goals: Array, goal_level: int) -> Dictionary:
	var unreachable := {"goal_distance": 9999, "next_step": start, "next_goal_distance": 9999, "goal_field_count": 0}
	var navigation: Dictionary = context.get("native_navigation", {})
	if not bool(navigation.get("ok", false)) or goal_level < 0 or goal_level >= int(navigation.get("level_count", 0)):
		return unreachable
	var size: Vector2i = navigation.map_size
	var origin := Vector3i(start.x, start.y, int(context.get("level", 0)))
	var start_index := NativeTransit.navigation_index(origin, size, int(navigation.level_count))
	if start_index < 0:
		return unreachable
	if goal_level == origin.z and start in goals:
		return {"goal_distance": 0, "next_step": start, "next_goal_distance": 0, "goal_field_count": 0}
	var fields: Dictionary = navigation.fields
	if not fields.has(start_index):
		# Bound per-actor fields as it moves. One search covers every endpoint
		# and goal on both levels, not one full walking search per portal.
		if fields.size() >= 8:
			fields.clear()
		fields[start_index] = NativeTransit.navigation_field(size, int(navigation.level_count), navigation.blocked, navigation.links, origin, bool(navigation.get("native_adjacency", false)))
	var field: Dictionary = fields[start_index]
	if not bool(field.get("ok", false)):
		return unreachable
	var best := 9999
	var best_index := -1
	var terminal_step := Vector2i(-1, -1)
	var surface: Dictionary = navigation.surfaces[goal_level]
	var area := size.x * size.y
	for goal in goals:
		if not (goal is Vector2i):
			continue
		var local_index := _tile_index(goal, size)
		if local_index < 0 or surface.encounter_blocked_indices.has(local_index) or surface.hero_blocked_indices.has(local_index) or surface.terrain_blocked_indices.has(local_index):
			continue
		var goal_index := goal_level * area + local_index
		var distance := int(field.distances[goal_index])
		if navigation.blocked[goal_index] == 0:
			if distance >= 0 and distance < best:
				best = distance
				best_index = goal_index
				terminal_step = Vector2i(-1, -1)
			continue
		# Preserve the existing AI terminal-object rule; blocked goal bodies
		# may be approached, but never become through-route cells.
		for delta in PATH_MOVEMENT_DELTAS:
			var neighbor := _tile_index(goal + delta, size)
			if neighbor < 0 or (not bool(navigation.get("native_adjacency", false)) and _path_step_cuts_blocked_corner_index(neighbor, local_index, size, surface.encounter_blocked_indices, surface.resource_blocked_indices, surface.hero_blocked_indices, surface.terrain_blocked_indices)):
				continue
			var global_neighbor := goal_level * area + neighbor
			var neighbor_distance := int(field.distances[global_neighbor])
			if neighbor_distance >= 0 and neighbor_distance + 1 < best:
				best = neighbor_distance + 1
				best_index = global_neighbor
				terminal_step = goal if global_neighbor == start_index else Vector2i(-1, -1)
	if best_index < 0:
		return unreachable
	var first := NativeTransit.navigation_point(int(field.first_steps[best_index]), size)
	var result := {"goal_distance": best, "next_step": terminal_step if terminal_step.x >= 0 else Vector2i(first.x, first.y), "next_goal_distance": maxi(0, best - 1), "goal_field_count": 1}
	var link_index := int(field.first_links[best_index])
	if link_index >= 0:
		result["native_transit"] = navigation.links[link_index]
	return result

static func _local_path_distance_surface_context_for_key(
	session: SessionStateStoreScript.SessionData,
	ignore_placement_id: String,
	observer_faction_id: String,
	level: int,
	cache_key: String,
	actor_blocked_indexes: Variant = null
) -> Dictionary:
	if cache_key != "" and _path_distance_surface_cache.has(cache_key):
		return _path_distance_surface_cache[cache_key]
	var encounter_blocked := _occupied_tiles(session, ignore_placement_id, level)
	var resource_blocked := _overworld_body_blocked_tiles(session, ignore_placement_id, observer_faction_id, level, actor_blocked_indexes)
	var hero_blocked := _player_hero_blocked_tiles(session, observer_faction_id, level)
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	var terrain_surface := _terrain_blocked_surface(session, level, map_size)
	var terrain_blocked: Dictionary = terrain_surface.get("tiles", {})
	var context := {
		"map_size": map_size,
		"level": level,
		"encounter_blocked": encounter_blocked,
		"resource_blocked": resource_blocked,
		"hero_blocked": hero_blocked,
		"terrain_blocked": terrain_blocked,
		"encounter_blocked_indices": _blocked_tile_index_lookup(encounter_blocked, map_size),
		"resource_blocked_indices": _blocked_tile_index_lookup(resource_blocked, map_size),
		"hero_blocked_indices": _blocked_tile_index_lookup(hero_blocked, map_size),
		"terrain_blocked_indices": terrain_surface.get("indices", {}),
		"distance_field_cache": {},
	}
	if cache_key != "":
		if _path_distance_surface_cache.size() >= PATH_DISTANCE_SURFACE_CACHE_LIMIT:
			_path_distance_surface_cache.clear()
		_path_distance_surface_cache[cache_key] = context
	return context

static func _terrain_blocked_surface(
	session: SessionStateStoreScript.SessionData,
	level: int,
	map_size: Vector2i
) -> Dictionary:
	# Terrain never changes during an enemy turn, but the surface cache key
	# includes every army's position, so each raid step misses it. Inside a
	# turn, reuse each level's blocked terrain instead of rescanning the map.
	var rows = LevelRules.terrain_rows(session, level)
	var key := ""
	if _enemy_turn_path_caches_active and session != null:
		key = "%s|%s|%d|%d,%d" % [String(session.session_id), String(session.scenario_id), level, map_size.x, map_size.y]
		var cached: Dictionary = _enemy_turn_terrain_surfaces.get(key, {})
		if not cached.is_empty() and is_same(cached.get("rows"), rows):
			return cached
	var tiles := _impassable_terrain_tiles(session, level)
	var surface := {"rows": rows, "tiles": tiles, "indices": _blocked_tile_index_lookup(tiles, map_size)}
	if key != "":
		_enemy_turn_terrain_surfaces[key] = surface
	return surface

static func _path_distance_surface_cache_key(
	session: SessionStateStoreScript.SessionData,
	ignore_placement_id: String,
	observer_faction_id: String,
	level: int = -1
) -> String:
	if session == null:
		return ""
	if level < 0:
		level = OverworldRulesScript.placement_level(session, ignore_placement_id)
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	var key := "%s|%s|%d|%d|%d|%s|%s|%s|%s|%s" % [
		String(session.session_id),
		String(session.scenario_id),
		int(session.day),
		map_size.x,
		map_size.y,
		ignore_placement_id,
		observer_faction_id,
		_path_distance_encounter_fingerprint(session, ignore_placement_id),
		_path_distance_resource_fingerprint(session),
		_path_distance_hero_fingerprint(session, observer_faction_id),
	]
	return _path_distance_level_cache_key(key, level)

static func _path_distance_level_cache_key(base_key: String, level: int) -> String:
	return base_key if level == 0 or base_key == "" else base_key + "|level:%d" % level

static func _path_distance_encounter_fingerprint(session: SessionStateStoreScript.SessionData, ignore_placement_id: String = "") -> String:
	var resolved_lookup := {}
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	if resolved_encounters is Array:
		for value in resolved_encounters:
			resolved_lookup[String(value)] = true
	var fingerprint := _fingerprint_seed()
	var count := 0
	var unresolved_count := 0
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		var placement_id := String(encounter.get("placement_id", ""))
		if placement_id == ignore_placement_id:
			continue
		var resolved_flag := 1 if resolved_lookup.has(placement_id) else 0
		count += 1
		if resolved_flag == 0:
			unresolved_count += 1
		fingerprint = _fingerprint_mix(fingerprint, _stable_string_hash(placement_id))
		fingerprint = _fingerprint_mix(fingerprint, int(encounter.get("x", 0)))
		fingerprint = _fingerprint_mix(fingerprint, int(encounter.get("y", 0)))
		fingerprint = _fingerprint_mix(fingerprint, resolved_flag)
		if LevelRules.level_of(encounter) != 0:
			fingerprint = _fingerprint_mix(fingerprint, LevelRules.level_of(encounter))
	return "%d:%d:%d" % [count, unresolved_count, fingerprint]

static func _path_distance_resource_fingerprint(session: SessionStateStoreScript.SessionData) -> String:
	var fingerprint := _fingerprint_seed()
	var count := 0
	var collected_count := 0
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var collected_flag := 1 if bool(node.get("collected", false)) else 0
		count += 1
		collected_count += collected_flag
		fingerprint = _fingerprint_mix(fingerprint, _stable_string_hash(String(node.get("placement_id", ""))))
		fingerprint = _fingerprint_mix(fingerprint, int(node.get("x", 0)))
		fingerprint = _fingerprint_mix(fingerprint, int(node.get("y", 0)))
		fingerprint = _fingerprint_mix(fingerprint, collected_flag)
		if LevelRules.level_of(node) != 0:
			fingerprint = _fingerprint_mix(fingerprint, LevelRules.level_of(node))
	return "%d:%d:%d" % [count, collected_count, fingerprint]

static func _path_distance_hero_fingerprint(
	session: SessionStateStoreScript.SessionData,
	observer_faction_id: String
) -> String:
	var fingerprint := _fingerprint_seed()
	var count := 0
	var sheltered_count := 0
	# Every path query builds this key, so scan the observer's sighting sources
	# once for all heroes rather than once per hero, and read heroes in place.
	var sighting_sources: Array = []
	var sighting_sources_loaded := false
	for hero_value in _player_hero_snapshots_for_intercept(session, true):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		var position: Dictionary = hero.get("position", {}) if hero.get("position", {}) is Dictionary else {}
		var sheltered := _player_hero_sheltered_in_town(session, hero)
		var sheltered_flag := 1 if sheltered else 0
		if not sheltered and not sighting_sources_loaded and observer_faction_id != "":
			sighting_sources = _enemy_hero_sighting_sources(session, {}, observer_faction_id)
			sighting_sources_loaded = true
		var blocked_for_observer_flag := 1 if (
			not sheltered
			and _player_hero_currently_visible_to_enemy_faction(session, hero, observer_faction_id, sighting_sources)
		) else 0
		count += 1
		sheltered_count += sheltered_flag
		fingerprint = _fingerprint_mix(fingerprint, _stable_string_hash(String(hero.get("hero_id", hero.get("id", "")))))
		fingerprint = _fingerprint_mix(fingerprint, int(position.get("x", -9999)))
		fingerprint = _fingerprint_mix(fingerprint, int(position.get("y", -9999)))
		fingerprint = _fingerprint_mix(fingerprint, sheltered_flag)
		fingerprint = _fingerprint_mix(fingerprint, blocked_for_observer_flag)
		if LevelRules.level_of(position) != 0:
			fingerprint = _fingerprint_mix(fingerprint, LevelRules.level_of(position))
	return "%d:%d:%d" % [count, sheltered_count, fingerprint]

static func _tile_index_lookup(tiles: Array, map_size: Vector2i) -> Dictionary:
	var lookup = {}
	for tile in tiles:
		if not (tile is Vector2i):
			continue
		var index := _tile_index(tile, map_size)
		if index >= 0:
			lookup[index] = true
	return lookup

static func _blocked_tile_index_lookup(blocked_tiles: Dictionary, map_size: Vector2i) -> Dictionary:
	var lookup = {}
	for key_value in blocked_tiles.keys():
		var tile := _vector_from_key(String(key_value))
		var index := _tile_index(tile, map_size)
		if index >= 0:
			lookup[index] = true
	return lookup

static func _blocked_tile_mask(
		tile_count: int,
		encounter_blocked: Dictionary,
		resource_blocked: Dictionary,
		hero_blocked: Dictionary,
		terrain_blocked: Dictionary) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(tile_count)
	mask.fill(0)
	for blocked_lookup in [encounter_blocked, resource_blocked, hero_blocked, terrain_blocked]:
		for index_value in blocked_lookup.keys():
			var index := int(index_value)
			if index >= 0 and index < tile_count:
				mask[index] = 1
	return mask

static func _path_distance_field_for_start(path_context: Dictionary, start_index: int) -> PackedInt32Array:
	var field_cache: Dictionary = path_context.get("distance_field_cache", {}) if path_context.get("distance_field_cache", {}) is Dictionary else {}
	if field_cache.has(start_index):
		return field_cache[start_index]
	var distances := _path_distance_field_from_seeds(path_context, [start_index])
	var tile_count: int = distances.size()
	if start_index < 0 or start_index >= tile_count:
		return distances
	field_cache[start_index] = distances
	path_context["distance_field_cache"] = field_cache
	return distances

static func _path_distance_field_for_goals(path_context: Dictionary, goal_indexes: Array) -> PackedInt32Array:
	# A single goal keeps its per-tile cache entry. Several goals share one
	# multi-source field, cached under the sorted goal set.
	if goal_indexes.size() == 1:
		return _path_distance_field_for_start(path_context, int(goal_indexes[0]))
	var sorted_indexes := goal_indexes.duplicate()
	sorted_indexes.sort()
	var cache_key := "goals:" + ",".join(sorted_indexes.map(func(index): return str(index)))
	var field_cache: Dictionary = path_context.get("distance_field_cache", {}) if path_context.get("distance_field_cache", {}) is Dictionary else {}
	if field_cache.has(cache_key):
		return field_cache[cache_key]
	var distances := _path_distance_field_from_seeds(path_context, sorted_indexes)
	field_cache[cache_key] = distances
	path_context["distance_field_cache"] = field_cache
	return distances

static func _path_distance_field_from_seeds(path_context: Dictionary, seed_indexes: Array) -> PackedInt32Array:
	# Breadth-first walking distances from every seed at once. The step rules
	# never depend on which seed a tile was reached from, so each tile gets the
	# minimum over single-seed searches. Seeds may sit on blocked tiles.
	var map_size: Vector2i = path_context.get("map_size", Vector2i.ZERO)
	var tile_count: int = max(0, map_size.x * map_size.y)
	var distances := PackedInt32Array()
	distances.resize(tile_count)
	distances.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(tile_count)
	var tail := 0
	for seed_value in seed_indexes:
		var seed_index := int(seed_value)
		if seed_index < 0 or seed_index >= tile_count or int(distances[seed_index]) == 0:
			continue
		distances[seed_index] = 0
		queue[tail] = seed_index
		tail += 1
	if tail == 0:
		return distances
	var blocked_mask: PackedByteArray = path_context.get("blocked_tile_mask", PackedByteArray())
	if blocked_mask.size() != tile_count:
		blocked_mask = _blocked_tile_mask(
			tile_count,
			path_context.get("encounter_blocked_indices", {}),
			path_context.get("resource_blocked_indices", {}),
			path_context.get("hero_blocked_indices", {}),
			path_context.get("terrain_blocked_indices", {})
		)
		path_context["blocked_tile_mask"] = blocked_mask
	var head := 0
	var width := map_size.x
	var height := map_size.y
	while head < tail:
		var pos_index: int = int(queue[head])
		head += 1
		var pos_x := pos_index % width
		var pos_y := int(pos_index / width)
		var next_distance := int(distances[pos_index]) + 1
		for delta in PATH_MOVEMENT_DELTAS:
			var next_x: int = pos_x + delta.x
			var next_y: int = pos_y + delta.y
			if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
				continue
			var next_index := next_y * width + next_x
			if int(distances[next_index]) >= 0 or blocked_mask[next_index] != 0:
				continue
			if delta.x != 0 and delta.y != 0:
				var side_a_index := pos_y * width + next_x
				var side_b_index := next_y * width + pos_x
				if blocked_mask[side_a_index] != 0 and blocked_mask[side_b_index] != 0:
					continue
			distances[next_index] = next_distance
			queue[tail] = next_index
			tail += 1
	return distances

static func _occupied_tiles(session: SessionStateStoreScript.SessionData, ignore_placement_id: String, level: int = 0) -> Dictionary:
	var occupied = {}
	var resolved_lookup := _resolved_encounter_lookup(session.overworld.get("resolved_encounters", []))
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary) or not LevelRules.on_level(encounter, level):
			continue
		var placement_id = String(encounter.get("placement_id", ""))
		if placement_id == ignore_placement_id:
			continue
		if resolved_lookup.has(placement_id):
			continue
		occupied[_pos_key(Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0))))] = true
	return occupied

static func _overworld_body_blocked_tiles(
	session: SessionStateStoreScript.SessionData,
	ignore_placement_id: String,
	observer_faction_id: String = "",
	level: int = 0,
	actor_blocked_indexes: Variant = null
) -> Dictionary:
	var ignore_army: bool = not _find_encounter_by_placement(session, ignore_placement_id).get("encounter", {}).is_empty()
	var blocked: Dictionary = OverworldRulesScript._build_blocked_tile_index(session, level, ignore_placement_id if ignore_army else "")
	if actor_blocked_indexes is Dictionary:
		# Endpoint safety needs strict occupancy, before the AI movement surface
		# removes the actor's body or observer-visible interaction doorways.
		# The request owns this copy; it is never retained in a path cache.
		actor_blocked_indexes[level] = blocked.duplicate(false)
	if not ignore_army:
		for tile in _placement_body_tiles_for_ignore(session, ignore_placement_id):
			if tile is Vector2i:
				blocked.erase(_pos_key(tile))
	if observer_faction_id != "":
		for node_value in session.overworld.get("resource_nodes", []):
			if not (node_value is Dictionary) or not LevelRules.on_level(node_value, level):
				continue
			var node: Dictionary = node_value
			var visit_tile: Variant = node.get("visit_tile", {})
			if visit_tile is Dictionary and not visit_tile.is_empty():
				var key := _pos_key(Vector2i(int(visit_tile.get("x", -1)), int(visit_tile.get("y", -1))))
				if not NativeTransit.is_native(node) or (blocked.get(key) is String and blocked.get(key) == String(node.get("placement_id", ""))):
					blocked.erase(key)
	return blocked

static func _placement_body_tiles_for_ignore(session: SessionStateStoreScript.SessionData, ignore_placement_id: String) -> Array:
	var tiles := []
	if session == null or ignore_placement_id == "":
		return tiles
	for collection_name in ["towns", "encounters", "map_objects", "resource_nodes", "artifact_nodes"]:
		for placement_value in session.overworld.get(collection_name, []):
			if not (placement_value is Dictionary):
				continue
			var placement: Dictionary = placement_value
			if String(placement.get("placement_id", placement.get("id", ""))) != ignore_placement_id:
				continue
			tiles.append_array(OverworldRulesScript._world_tiles_from_payload_array(placement.get("package_block_tiles", [])))
			if tiles.is_empty():
				tiles.append_array(OverworldRulesScript._world_tiles_from_payload_array(placement.get("body_tiles", [])))
			if tiles.is_empty():
				tiles.append(Vector2i(int(placement.get("x", -1)), int(placement.get("y", -1))))
			return tiles
	return tiles

static func _player_hero_blocked_tiles(
	session: SessionStateStoreScript.SessionData,
	observer_faction_id: String,
	level: int = 0
) -> Dictionary:
	var blocked := {}
	if session == null or observer_faction_id == "":
		return blocked
	var sighting_sources: Array = []
	var sighting_sources_loaded := false
	for hero_value in _player_hero_snapshots_for_intercept(session, true):
		if not (hero_value is Dictionary) or not LevelRules.on_level(hero_value, level):
			continue
		var hero: Dictionary = hero_value
		if _player_hero_sheltered_in_town(session, hero):
			continue
		if not sighting_sources_loaded:
			sighting_sources = _enemy_hero_sighting_sources(session, {}, observer_faction_id)
			sighting_sources_loaded = true
		if not _player_hero_currently_visible_to_enemy_faction(session, hero, observer_faction_id, sighting_sources):
			continue
		var position: Dictionary = hero.get("position", {}) if hero.get("position", {}) is Dictionary else {}
		if position.is_empty():
			continue
		blocked[_pos_key(Vector2i(int(position.get("x", -9999)), int(position.get("y", -9999))))] = true
	return blocked

static func _player_hero_currently_visible_to_enemy_faction(
	session: SessionStateStoreScript.SessionData,
	hero: Dictionary,
	observer_faction_id: String,
	preloaded_sources: Variant = null
) -> bool:
	if session == null or hero.is_empty() or observer_faction_id == "":
		return false
	var position: Dictionary = hero.get("position", {}) if hero.get("position", {}) is Dictionary else {}
	if position.is_empty():
		return false
	var tile := Vector2i(int(position.get("x", 0)), int(position.get("y", 0)))
	var sources: Array = preloaded_sources if preloaded_sources is Array else _enemy_hero_sighting_sources(session, {}, observer_faction_id)
	for source_value in sources:
		if not (source_value is Dictionary) or not LevelRules.same_level(source_value, hero):
			continue
		var source: Dictionary = source_value
		var distance: int = abs(tile.x - int(source.get("x", 0))) + abs(tile.y - int(source.get("y", 0)))
		if distance <= int(source.get("radius", 0)):
			return true
	return false

static func _impassable_terrain_tiles(session: SessionStateStoreScript.SessionData, level: int = 0) -> Dictionary:
	var blocked = {}
	# Terrain definitions are stable during this synchronous scan, not between
	# scans. Resolve each raw id once through the same authoritative rule.
	var impassable_by_id := {}
	var map_data = LevelRules.terrain_rows(session, level)
	if not (map_data is Array):
		return blocked
	for y in range(map_data.size()):
		var row = map_data[y]
		if not (row is Array):
			continue
		for x in range(row.size()):
			var terrain_id := String(row[x])
			if not impassable_by_id.has(terrain_id):
				impassable_by_id[terrain_id] = not OverworldRulesScript.terrain_id_is_passable(terrain_id)
			var impassable: bool = impassable_by_id[terrain_id]
			if impassable:
				blocked[_pos_key(Vector2i(x, y))] = true
	return blocked

static func _position_blocked_index(
	pos_index: int,
	goal_lookup: Dictionary,
	encounter_blocked: Dictionary,
	resource_blocked: Dictionary,
	hero_blocked: Dictionary,
	terrain_blocked: Dictionary
) -> bool:
	if pos_index < 0:
		return true
	if goal_lookup.has(pos_index):
		return encounter_blocked.has(pos_index) or hero_blocked.has(pos_index)
	if terrain_blocked.has(pos_index):
		return true
	return encounter_blocked.has(pos_index) or resource_blocked.has(pos_index) or hero_blocked.has(pos_index)

static func _position_blocked_for_distance_field(
	pos_index: int,
	encounter_blocked: Dictionary,
	resource_blocked: Dictionary,
	hero_blocked: Dictionary,
	terrain_blocked: Dictionary
) -> bool:
	if pos_index < 0:
		return true
	return encounter_blocked.has(pos_index) \
		or resource_blocked.has(pos_index) \
		or hero_blocked.has(pos_index) \
		or terrain_blocked.has(pos_index)

static func _path_step_cuts_blocked_corner_index(
	from_index: int,
	to_index: int,
	map_size: Vector2i,
	encounter_blocked: Dictionary,
	resource_blocked: Dictionary,
	hero_blocked: Dictionary,
	terrain_blocked: Dictionary
) -> bool:
	if from_index < 0 or to_index < 0:
		return true
	var from_tile := _vector_from_index(from_index, map_size)
	var to_tile := _vector_from_index(to_index, map_size)
	var dx := to_tile.x - from_tile.x
	var dy := to_tile.y - from_tile.y
	if abs(dx) != 1 or abs(dy) != 1:
		return false
	var side_a_index := _tile_index(Vector2i(from_tile.x + dx, from_tile.y), map_size)
	var side_b_index := _tile_index(Vector2i(from_tile.x, from_tile.y + dy), map_size)
	return _position_blocked_for_distance_field(side_a_index, encounter_blocked, resource_blocked, hero_blocked, terrain_blocked) \
		and _position_blocked_for_distance_field(side_b_index, encounter_blocked, resource_blocked, hero_blocked, terrain_blocked)

static func _resolved_encounter_lookup(resolved_encounters: Variant) -> Dictionary:
	# The resolved list grows all game. Loops over every encounter build this
	# once instead of scanning the list for each encounter.
	var lookup := {}
	if resolved_encounters is Array:
		for value in resolved_encounters:
			lookup[String(value)] = true
	return lookup

static func _pos_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]

static func _tile_index(pos: Vector2i, map_size: Vector2i) -> int:
	if pos.x < 0 or pos.y < 0 or pos.x >= map_size.x or pos.y >= map_size.y:
		return -1
	return pos.y * map_size.x + pos.x

static func _fingerprint_seed() -> int:
	return 2166136261

static func _stable_string_hash(value: String) -> int:
	return int(value.hash()) & 0x7fffffff

static func _fingerprint_mix(fingerprint: int, value: int) -> int:
	return int((int(fingerprint) * 16777619 + (int(value) & 0x7fffffff)) & 0x7fffffff)

static func _vector_from_index(index: int, map_size: Vector2i) -> Vector2i:
	if index < 0 or map_size.x <= 0:
		return Vector2i.ZERO
	return Vector2i(index % map_size.x, int(floor(float(index) / float(map_size.x))))

static func _vector_from_key(key: String) -> Vector2i:
	var parts = key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
