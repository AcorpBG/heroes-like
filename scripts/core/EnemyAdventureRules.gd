class_name EnemyAdventureRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")

const COMMANDER_STATUS_AVAILABLE := "available"
const COMMANDER_STATUS_ACTIVE := "active"
const COMMANDER_STATUS_RECOVERING := "recovering"
const COMMANDER_OUTCOME_DEFEATED := "defeated"
const COMMANDER_OUTCOME_ASSAULT_VICTORY := "assault_victory"
const COMMANDER_OUTCOME_DEPLOYED := "deployed"
const COMMANDER_OUTCOME_FIELD_VICTORY := "field_victory"
const COMMANDER_OUTCOME_PURSUIT_VICTORY := "pursuit_victory"
const COMMANDER_OUTCOME_CAPITULATION := "capitulation"
const COMMANDER_OUTCOME_ROUT_VICTORY := "rout_victory"
const COMMANDER_OUTCOME_STALEMATE := "stalemate"
const COMMANDER_RECOVERY_DAYS_DEFEATED := 3
const COMMANDER_RECOVERY_DAYS_ASSAULT_VICTORY := 1
const COMMANDER_EXPERIENCE_DEPLOYED := 90
const COMMANDER_EXPERIENCE_FIELD_VICTORY := 180
const COMMANDER_EXPERIENCE_PURSUIT_VICTORY := 205
const COMMANDER_EXPERIENCE_CAPITULATION := 150
const COMMANDER_EXPERIENCE_ROUT_VICTORY := 230
const COMMANDER_EXPERIENCE_ASSAULT_VICTORY := 210
const COMMANDER_EXPERIENCE_DEFEATED := 45
const COMMANDER_EXPERIENCE_STALEMATE := 30
const COMMANDER_VETERANCY_LABELS := ["", "Blooded", "Veteran", "War-hardened"]
const LOGISTICS_SITE_FAMILIES := ["neutral_dwelling", "faction_outpost", "frontier_shrine"]
const COMMANDER_ROLE_RAIDER := "raider"
const COMMANDER_ROLE_DEFENDER := "defender"
const COMMANDER_ROLE_RETAKER := "retaker"
const COMMANDER_ROLE_STABILIZER := "stabilizer"
const COMMANDER_ROLE_RECOVERING := "recovering"
const COMMANDER_ROLE_RESERVE := "reserve"
const COMMANDER_ROLE_PUBLIC_EVENT_KEYS := [
	"event_id",
	"day",
	"sequence",
	"event_type",
	"faction_id",
	"faction_label",
	"actor_id",
	"actor_label",
	"target_kind",
	"target_id",
	"target_label",
	"target_x",
	"target_y",
	"from_x",
	"from_y",
	"to_x",
	"to_y",
	"phase_id",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
	"debug_reason",
	"state_policy",
]
const COMMANDER_ROLE_BLOCKED_PUBLIC_TOKENS := [
	"base_value",
	"persistent_income_value",
	"recruit_value",
	"scarcity_value",
	"denial_value",
	"route_pressure_value",
	"town_enablement_value",
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
	"garrison_score",
	"raid_score",
	"rebuild_score",
	"resource_score_breakdown",
	"target_memory",
	"commander_role_state",
	"fixture_state",
	"saved",
	"durable",
	"migration",
	"SAVE_VERSION",
	"focus_pressure_count",
	"rivalry_count",
	"fixture_previous_controller",
	"fixture_denial_only",
	"fixture_primary_target_covered",
	"fixture_threatened_by_player_front",
	"fixture_recently_secured",
	"fixture_recent_pressure_count",
]
const COMMANDER_ROLE_TURN_NO_OP_REASONS := [
	"target_unchanged",
	"no_active_commander",
	"commander_recovering",
	"commander_rebuilding",
	"no_valid_target",
	"town_front_dominates_selector",
	"pressure_below_launch_threshold",
	"max_active_raids_reached",
	"no_open_spawn_point",
	"no_available_commander",
	"town_governor_only_turn",
	"battle_queued_before_spawn",
	"no_existing_raid_to_move",
	"report_fixture_not_configured_for_assignment",
]
const AI_HERO_TASK_REPORT_ID := "AI_HERO_TASK_STATE_BOUNDARY_REPORT"
const AI_HERO_TASK_STATE_POLICY := "report_only"
const AI_HERO_TASK_SOURCE_KIND := "commander_role_adapter"
const AI_HERO_TASK_CLASSES := [
	"raid_town",
	"retake_site",
	"contest_site",
	"stabilize_front",
	"defend_front",
	"recover_commander",
	"rebuild_host",
	"reserve",
]
const AI_HERO_TASK_EXCLUSIVE_CLASSES := ["retake_site", "contest_site", "defend_front", "raid_town"]
const AI_HERO_TASK_PUBLIC_EVENT_KEYS := [
	"event_id",
	"day",
	"sequence",
	"event_type",
	"faction_id",
	"faction_label",
	"actor_id",
	"actor_label",
	"task_class",
	"target_kind",
	"target_id",
	"target_label",
	"front_id",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
	"state_policy",
]
const AI_HERO_TASK_BLOCKED_PUBLIC_TOKENS := [
	"resource_score_breakdown",
	"final_priority",
	"debug_reason",
	"target_debug_reason",
	"fixture_",
	"score",
	"priority_table",
	"breakdown",
	"hero_task_state",
	"commander_role_state",
	"SAVE_VERSION",
	"body_tiles",
	"approach",
	"task_id",
	"source_id",
	"assignment_id_hint",
	"route_policy",
	"reservation_key",
	"invalidated_by_task_id",
]

static func assign_target(session: SessionStateStoreScript.SessionData, config: Dictionary, raid: Dictionary) -> Dictionary:
	var previous_target := _current_target_snapshot(raid)
	var had_memory := not commander_target_memory(raid.get("enemy_commander_state", {})).is_empty()
	if _raid_target_valid(session, raid):
		raid = _refresh_target(session, raid)
	else:
		raid = _clear_delivery_intercept_target(raid)
		var plan = choose_target(
			session,
			config,
			{"x": int(raid.get("x", 0)), "y": int(raid.get("y", 0))},
			raid.get("enemy_commander_state", {})
		)
		if not plan.is_empty():
			raid.merge(plan, true)
	var current_target := _current_target_snapshot(raid)
	if _target_signature(current_target) != "" and (
		_target_signature(previous_target) != _target_signature(current_target)
		or not had_memory
	):
		var commander_state = raid.get("enemy_commander_state", {})
		if commander_state is Dictionary and not commander_state.is_empty():
			raid["enemy_commander_state"] = record_target_assignment(
				commander_state,
				String(current_target.get("target_kind", "")),
				String(current_target.get("target_placement_id", "")),
				String(current_target.get("target_label", "")),
				int(current_target.get("target_x", 0)),
				int(current_target.get("target_y", 0))
			)
	return raid

static func advance_raids(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	state: Dictionary = {}
) -> Dictionary:
	DifficultyRulesScript.normalize_session(session)
	var encounters = session.overworld.get("encounters", [])
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var total_pillage = {}
	var marching_counts = {}
	var pressure_counts = {}
	var event_messages = []
	var event_records = []

	for index in range(encounters.size()):
		var encounter = encounters[index]
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue

		encounter = ensure_raid_army(encounter, session)
		var previous_target := _current_target_snapshot(encounter)
		encounter = assign_target(session, config, encounter)
		var assignment_event := ai_target_assignment_event(session, config, encounter, previous_target)
		if not assignment_event.is_empty():
			event_records.append(assignment_event)
		encounter["days_active"] = max(0, int(encounter.get("days_active", 0))) + 1

		var current = Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
		var goal_tiles = _goal_tiles_from_raid(session, encounter)
		var goal_distance = _path_distance(session, current, goal_tiles, String(encounter.get("placement_id", "")))
		if goal_distance > 0 and goal_distance < 9999:
			var next_step = _next_step_toward(session, current, goal_tiles, String(encounter.get("placement_id", "")))
			if next_step != current:
				encounter["x"] = next_step.x
				encounter["y"] = next_step.y
				current = next_step

		goal_tiles = _goal_tiles_from_raid(session, encounter)
		goal_distance = _path_distance(session, current, goal_tiles, String(encounter.get("placement_id", "")))
		encounter["goal_distance"] = 0 if goal_distance == 9999 and current in goal_tiles else goal_distance
		encounter["arrived"] = int(encounter.get("goal_distance", 9999)) == 0

		if bool(encounter.get("arrived", false)):
			var arrival_result = _resolve_arrived_target(session, encounter, state, faction_id)
			encounter = arrival_result.get("encounter", encounter)
			state = arrival_result.get("state", state)
			var event_message = String(arrival_result.get("event_message", ""))
			if event_message != "":
				event_messages.append(event_message)
			var arrival_event: Dictionary = arrival_result.get("ai_event", {})
			if not arrival_event.is_empty():
				event_records.append(arrival_event)
		encounters[index] = encounter

		var target_label = String(encounter.get("target_label", "the frontier"))
		if bool(encounter.get("arrived", false)):
			pressure_counts[target_label] = int(pressure_counts.get(target_label, 0)) + 1
			if int(encounter.get("days_active", 0)) >= max(1, int(config.get("raid_pillage_delay", 1))):
				total_pillage = _merge_resources(
					total_pillage,
					_scale_resources(config.get("raid_pillage", {}), raid_pillage_weight(encounter))
				)
		else:
			marching_counts[target_label] = int(marching_counts.get(target_label, 0)) + 1

	session.overworld["encounters"] = encounters

	var messages = []
	var marching_message = _describe_count_map("march on", marching_counts)
	if marching_message != "":
		messages.append("%s %s." % [String(config.get("label", faction_id)), marching_message])
	var pressure_message = _describe_count_map("press", pressure_counts)
	if pressure_message != "":
		messages.append("%s %s." % [String(config.get("label", faction_id)), pressure_message])
	if not event_messages.is_empty():
		messages.append(" ".join(event_messages))

	var actual_losses = _remove_resources(
		session,
		HeroProgressionRulesScript.scale_raid_pillage(
			session.overworld.get("hero", {}),
			DifficultyRulesScript.scale_raid_pillage(session, total_pillage)
		)
	)
	if not actual_losses.is_empty():
		messages.append("%s pillages %s." % [String(config.get("label", faction_id)), _describe_resource_set(actual_losses)])

	return {
		"message": " ".join(messages),
		"state": state,
		"events": event_records,
	}

static func normalize_raid_armies(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var encounters = session.overworld.get("encounters", [])
	var normalized = []
	var changed = false
	var occupied_commander_ids: Dictionary = {}
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
		if String(encounter.get("spawned_by_faction_id", "")) != "":
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

static func normalize_all_commander_rosters(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return
	var changed := false
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		var faction_id := String(state.get("faction_id", ""))
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
	var existing_map: Dictionary = {}
	if roster_value is Array:
		for entry_value in roster_value:
			if not (entry_value is Dictionary):
				continue
			var roster_hero_id := String(entry_value.get("roster_hero_id", ""))
			if roster_hero_id == "":
				continue
			existing_map[roster_hero_id] = entry_value
	var active_map = _active_commander_map(session, faction_id)
	var normalized := []
	var session_day := int(session.day) if session != null else 0
	for roster_hero_id in _faction_commander_ids(faction_id):
		var existing = existing_map.get(roster_hero_id, {})
		if not (existing is Dictionary):
			existing = {}
		var active_entry: Dictionary = active_map.get(roster_hero_id, {})
		var active_commander_state = active_entry.get("commander_state", {})
		if not (active_commander_state is Dictionary):
			active_commander_state = {}
		var commander_seed = (
			active_commander_state
			if not active_commander_state.is_empty()
			else existing.get("commander_state", {})
		)
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
			}
		)
		var entry := {
			"roster_hero_id": roster_hero_id,
			"status": COMMANDER_STATUS_AVAILABLE,
			"active_placement_id": "",
			"recovery_day": 0,
			"last_outcome": String(existing.get("last_outcome", commander_state.get("last_outcome", ""))),
			"deployments": max(0, int(record.get("deployments", 0))),
			"battle_wins": max(0, int(record.get("battle_wins", 0))),
			"times_defeated": max(0, int(record.get("times_defeated", 0))),
			"renown": max(0, int(record.get("renown", 0))),
			"target_memory": target_memory,
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
		if String(state.get("faction_id", "")) != faction_id:
			continue
		var roster = state.get("commander_roster", [])
		return roster if roster is Array else []
	return []

static func commander_renown(source: Variant) -> int:
	return max(0, int(_normalized_commander_record(source).get("renown", 0)))

static func commander_veterancy_label(source: Variant) -> String:
	return String(
		COMMANDER_VETERANCY_LABELS[
			clamp(_commander_veterancy_rank_from_record(_normalized_commander_record(source)), 0, COMMANDER_VETERANCY_LABELS.size() - 1)
		]
	)

static func commander_display_name(source: Variant, include_veterancy: bool = true) -> String:
	var commander_name := _commander_name_from_source(source)
	if commander_name == "":
		return ""
	var veterancy := commander_veterancy_label(source)
	if include_veterancy and veterancy != "":
		return "%s %s" % [veterancy, commander_name]
	return commander_name

static func commander_record_summary(source: Variant) -> String:
	var record := _normalized_commander_record(source)
	var deployments: int = max(0, int(record.get("deployments", 0)))
	var wins: int = max(0, int(record.get("battle_wins", 0)))
	var defeats: int = max(0, int(record.get("times_defeated", 0)))
	if deployments <= 0 and wins <= 0 and defeats <= 0:
		return ""
	var parts := []
	var veterancy := commander_veterancy_label(record)
	if veterancy != "":
		parts.append(veterancy)
	parts.append("%d raid%s" % [deployments, "" if deployments == 1 else "s"])
	if wins > 0:
		parts.append("%d win%s" % [wins, "" if wins == 1 else "s"])
	if defeats > 0:
		parts.append("%d defeat%s" % [defeats, "" if defeats == 1 else "s"])
	elif wins > 0:
		parts.append("undefeated")
	return " | ".join(parts)

static func commander_target_memory(source: Variant) -> Dictionary:
	return _normalized_commander_memory(source)

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
	match String(_normalized_commander_record(source).get("last_outcome", "")):
		COMMANDER_OUTCOME_ROUT_VICTORY:
			return "fresh from a rout"
		COMMANDER_OUTCOME_PURSUIT_VICTORY:
			return "driving a hard pursuit"
		COMMANDER_OUTCOME_CAPITULATION:
			return "flush with surrender terms"
		_:
			return ""

static func commander_army_summary(source: Variant) -> String:
	return String(_normalized_commander_army_continuity(source).get("summary", ""))

static func commander_can_deploy(source: Variant) -> bool:
	var continuity := _normalized_commander_army_continuity(source)
	if continuity.is_empty() or int(continuity.get("base_strength", 0)) <= 0:
		return true
	return int(continuity.get("current_strength", 0)) > 0

static func raid_commander_memory_summaries(encounters: Array, limit: int = 2) -> Array:
	var summaries: Array = []
	for encounter in encounters:
		if not (encounter is Dictionary):
			continue
		var commander_name := raid_commander_display_name(encounter)
		var memory_brief := commander_memory_brief(encounter.get("enemy_commander_state", {}))
		if commander_name == "" or memory_brief == "":
			continue
		var summary := "%s %s" % [commander_name, memory_brief]
		if summary in summaries:
			continue
		summaries.append(summary)
		if limit > 0 and summaries.size() >= limit:
			break
	return summaries

static func has_available_raid_commander(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_value: Variant = []
) -> bool:
	for entry_value in normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	):
		if not (entry_value is Dictionary):
			continue
		if (
			_normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) == COMMANDER_STATUS_AVAILABLE
			and commander_can_deploy(entry_value)
		):
			return true
	return false

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

static func apply_resolved_commander_aftermath(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_state: Variant,
	outcome_id: String
) -> String:
	if session == null or faction_id == "" or not (commander_state is Dictionary):
		return ""
	var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
	if roster_hero_id == "":
		return ""
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return ""
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster = normalize_commander_roster(session, faction_id, state.get("commander_roster", []))
		for roster_index in range(roster.size()):
			var entry = roster[roster_index]
			if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
				continue
			var updated_state := advance_commander_record(commander_state, outcome_id)
			if outcome_id == COMMANDER_OUTCOME_DEFEATED:
				var continuity := commander_army_continuity(updated_state)
				var defeated_encounter_id := String(continuity.get("encounter_id", ""))
				if defeated_encounter_id == "":
					defeated_encounter_id = String(commander_army_continuity(commander_state).get("encounter_id", ""))
				updated_state = sync_commander_army_continuity(updated_state, {"stacks": []}, defeated_encounter_id)
			entry["status"] = COMMANDER_STATUS_RECOVERING
			entry["active_placement_id"] = ""
			entry["last_outcome"] = outcome_id
			entry["deployments"] = max(0, int(updated_state.get("deployments", entry.get("deployments", 0))))
			entry["battle_wins"] = max(0, int(updated_state.get("battle_wins", entry.get("battle_wins", 0))))
			entry["times_defeated"] = max(0, int(updated_state.get("times_defeated", entry.get("times_defeated", 0))))
			entry["renown"] = commander_renown(updated_state)
			entry["commander_state"] = build_roster_commander_state(
				roster_hero_id,
				faction_id,
				updated_state,
				entry
			)
			entry["target_memory"] = commander_target_memory(entry.get("commander_state", {}))
			entry["army_continuity"] = commander_army_continuity(entry.get("commander_state", {}))
			var recovery_days := 0
			var summary := ""
			match outcome_id:
				COMMANDER_OUTCOME_DEFEATED:
					recovery_days = COMMANDER_RECOVERY_DAYS_DEFEATED
					summary = "%s is routed and cannot lead another raid for %d day%s." % [
						commander_display_name(entry),
						recovery_days,
						"" if recovery_days == 1 else "s",
					]
				COMMANDER_OUTCOME_ASSAULT_VICTORY:
					recovery_days = COMMANDER_RECOVERY_DAYS_ASSAULT_VICTORY
					summary = "%s is consolidating the breach and will not return for %d day%s." % [
						commander_display_name(entry),
						recovery_days,
						"" if recovery_days == 1 else "s",
					]
				_:
					entry["status"] = COMMANDER_STATUS_AVAILABLE
			entry["recovery_day"] = int(session.day) + recovery_days if recovery_days > 0 else 0
			roster[roster_index] = entry
			state["commander_roster"] = roster
			states[index] = state
			session.overworld["enemy_states"] = states
			return summary
	return ""

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
		_hero_battle_spell_ids(hero_template)
	)
	var commander_state = {
		"id": String(existing_state.get("id", "enemy_commander:%s:%s" % [faction_id, roster_hero_id])),
		"roster_hero_id": roster_hero_id,
		"faction_id": faction_id,
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
	}
	commander_state = _normalize_enemy_progression(commander_state)
	return _apply_commander_army_metadata(
		_apply_commander_record_metadata(
			_apply_commander_memory_metadata(
				SpellRulesScript.refresh_daily_mana(
					SpellRulesScript.ensure_hero_spellbook(
						commander_state,
						{
							"command": commander_state.get("command", {}),
							"starting_spell_ids": spell_ids_source,
						}
					)
				),
				target_memory
			),
			record
		),
		army_continuity
	)

static func advance_commander_record(commander_state: Dictionary, outcome_id: String) -> Dictionary:
	if commander_state.is_empty():
		return {}
	var updated := commander_state.duplicate(true)
	var record := _normalized_commander_record({}, updated)
	record["last_outcome"] = outcome_id
	match outcome_id:
		COMMANDER_OUTCOME_DEPLOYED:
			record["deployments"] = int(record.get("deployments", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_DEPLOYED)
		COMMANDER_OUTCOME_FIELD_VICTORY:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_FIELD_VICTORY)
		COMMANDER_OUTCOME_PURSUIT_VICTORY:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_PURSUIT_VICTORY)
		COMMANDER_OUTCOME_CAPITULATION:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_CAPITULATION)
		COMMANDER_OUTCOME_ROUT_VICTORY:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_ROUT_VICTORY)
		COMMANDER_OUTCOME_ASSAULT_VICTORY:
			record["battle_wins"] = int(record.get("battle_wins", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_ASSAULT_VICTORY)
		COMMANDER_OUTCOME_DEFEATED:
			record["times_defeated"] = int(record.get("times_defeated", 0)) + 1
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_DEFEATED)
		COMMANDER_OUTCOME_STALEMATE:
			updated = _award_enemy_commander_experience(updated, COMMANDER_EXPERIENCE_STALEMATE)
		_:
			updated = _normalize_enemy_progression(updated)
	updated["last_outcome"] = outcome_id
	var spellbook = updated.get("spellbook", {})
	if not (spellbook is Dictionary):
		spellbook = {}
	return _apply_commander_army_metadata(
		_apply_commander_record_metadata(
			_apply_commander_memory_metadata(
				SpellRulesScript.ensure_hero_spellbook(
					updated,
					{
						"command": updated.get("command", {}),
						"starting_spell_ids": spellbook.get("known_spell_ids", []),
					}
				),
				updated
			),
			record
		),
		updated
	)

static func record_commander_deployment(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	roster_value: Variant = [],
	placement_id: String = ""
) -> Array:
	var roster = normalize_commander_roster(
		session,
		faction_id,
		roster_value if roster_value is Array else commander_roster_for_faction(session, faction_id)
	)
	for roster_index in range(roster.size()):
		var entry = roster[roster_index]
		if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
			continue
		var updated_state := advance_commander_record(
			entry.get("commander_state", {}),
			COMMANDER_OUTCOME_DEPLOYED
		)
		entry["status"] = COMMANDER_STATUS_ACTIVE if placement_id != "" else COMMANDER_STATUS_AVAILABLE
		entry["active_placement_id"] = placement_id
		entry["recovery_day"] = 0
		entry["last_outcome"] = COMMANDER_OUTCOME_DEPLOYED
		entry["deployments"] = max(0, int(updated_state.get("deployments", entry.get("deployments", 0))))
		entry["battle_wins"] = max(0, int(updated_state.get("battle_wins", entry.get("battle_wins", 0))))
		entry["times_defeated"] = max(0, int(updated_state.get("times_defeated", entry.get("times_defeated", 0))))
		entry["renown"] = commander_renown(updated_state)
		entry["commander_state"] = build_roster_commander_state(
			roster_hero_id,
			faction_id,
			updated_state,
			entry
		)
		entry["target_memory"] = commander_target_memory(entry.get("commander_state", {}))
		entry["army_continuity"] = commander_army_continuity(entry.get("commander_state", {}))
		roster[roster_index] = entry
		break
	return roster

static func sync_commander_state_to_roster(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_state: Variant,
	status_override: String = "",
	active_placement_id: String = "",
	recovery_day: int = -1,
	last_outcome: String = ""
) -> void:
	if session == null or faction_id == "" or not (commander_state is Dictionary):
		return
	var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
	if roster_hero_id == "":
		return
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster = normalize_commander_roster(session, faction_id, state.get("commander_roster", []))
		for roster_index in range(roster.size()):
			var entry = roster[roster_index]
			if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
				continue
			var record := _normalized_commander_record(entry, commander_state)
			entry["deployments"] = max(0, int(record.get("deployments", 0)))
			entry["battle_wins"] = max(0, int(record.get("battle_wins", 0)))
			entry["times_defeated"] = max(0, int(record.get("times_defeated", 0)))
			entry["renown"] = max(0, int(record.get("renown", 0)))
			if status_override != "":
				entry["status"] = _normalize_commander_status(status_override)
			if active_placement_id != "":
				entry["active_placement_id"] = active_placement_id
			elif status_override == COMMANDER_STATUS_RECOVERING:
				entry["active_placement_id"] = ""
			if status_override == COMMANDER_STATUS_ACTIVE and recovery_day < 0:
				entry["recovery_day"] = 0
			if recovery_day >= 0:
				entry["recovery_day"] = recovery_day
			if last_outcome != "":
				entry["last_outcome"] = last_outcome
			entry["commander_state"] = build_roster_commander_state(
				roster_hero_id,
				faction_id,
				commander_state,
				entry
			)
			entry["target_memory"] = commander_target_memory(entry.get("commander_state", {}))
			entry["army_continuity"] = commander_army_continuity(entry.get("commander_state", {}))
			roster[roster_index] = entry
			state["commander_roster"] = roster
			states[state_index] = state
			session.overworld["enemy_states"] = states
			return

static func reinforce_commander_roster_army(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	unit_id: String,
	count: int
) -> int:
	if session == null or faction_id == "" or roster_hero_id == "" or unit_id == "" or count <= 0:
		return 0
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return 0
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster = normalize_commander_roster(session, faction_id, state.get("commander_roster", []))
		for roster_index in range(roster.size()):
			var entry = roster[roster_index]
			if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
				continue
			if _normalize_commander_status(entry.get("status", COMMANDER_STATUS_AVAILABLE)) == COMMANDER_STATUS_ACTIVE:
				return 0
			var commander_state = entry.get("commander_state", {})
			if not (commander_state is Dictionary) or commander_state.is_empty():
				return 0
			var continuity: Dictionary = _normalized_commander_army_continuity(entry, commander_state)
			var rebuild_need: int = max(0, int(continuity.get("rebuild_need", 0)))
			if rebuild_need <= 0:
				return 0
			var per_unit_strength: int = max(1, _unit_strength_value(unit_id))
			var accepted: int = min(count, max(1, int(ceili(float(rebuild_need) / float(per_unit_strength)))))
			var reinforced_stacks: Array = _add_army_stack(continuity.get("stacks", []), unit_id, accepted)
			var updated_state := sync_commander_army_continuity(
				commander_state,
				{"stacks": reinforced_stacks},
				String(continuity.get("encounter_id", ""))
			)
			entry["commander_state"] = build_roster_commander_state(
				roster_hero_id,
				faction_id,
				updated_state,
				entry
			)
			entry["target_memory"] = commander_target_memory(entry.get("commander_state", {}))
			entry["army_continuity"] = commander_army_continuity(entry.get("commander_state", {}))
			roster[roster_index] = entry
			state["commander_roster"] = roster
			states[state_index] = state
			session.overworld["enemy_states"] = states
			return accepted
	return 0

static func ensure_raid_army(
	encounter: Dictionary,
	session: SessionStateStoreScript.SessionData = null,
	occupied_commander_ids: Dictionary = {}
) -> Dictionary:
	if encounter.is_empty():
		return encounter
	var encounter_id = String(encounter.get("encounter_id", encounter.get("id", "")))
	var commander_state := {}
	if String(encounter.get("spawned_by_faction_id", "")) != "":
		commander_state = build_raid_commander_state(
			encounter,
			"",
			"",
			session,
			occupied_commander_ids,
			commander_roster_for_faction(session, String(encounter.get("spawned_by_faction_id", "")))
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

static func occupied_raid_commander_ids(
	session: SessionStateStoreScript.SessionData,
	faction_id: String = "",
	exclude_placement_id: String = ""
) -> Dictionary:
	var occupied: Dictionary = {}
	if session == null:
		return occupied
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if faction_id != "" and String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if exclude_placement_id != "" and String(encounter.get("placement_id", "")) == exclude_placement_id:
			continue
		var roster_hero_id := String(encounter.get("enemy_commander_state", {}).get("roster_hero_id", ""))
		if roster_hero_id != "":
			occupied[roster_hero_id] = true
	return occupied

static func select_raid_commander_roster_hero_id(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	preferred_index: int = 0,
	occupied_commander_ids: Dictionary = {},
	commander_roster: Variant = []
) -> String:
	if faction_id == "":
		return ""
	var hero_ids: Array = _faction_commander_ids(faction_id)
	if hero_ids.is_empty():
		return ""
	var occupied: Dictionary = occupied_commander_ids
	if occupied.is_empty():
		occupied = occupied_raid_commander_ids(session, faction_id)
	var normalized_roster = normalize_commander_roster(
		session,
		faction_id,
		commander_roster if commander_roster is Array else commander_roster_for_faction(session, faction_id)
	)
	var unavailable: Dictionary = {}
	for entry_value in normalized_roster:
		if not (entry_value is Dictionary):
			continue
		var roster_hero_id := String(entry_value.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		if (
			_normalize_commander_status(entry_value.get("status", COMMANDER_STATUS_AVAILABLE)) != COMMANDER_STATUS_AVAILABLE
			or not commander_can_deploy(entry_value)
		):
			unavailable[roster_hero_id] = true
	var start_index: int = posmod(preferred_index, hero_ids.size())
	for offset in range(hero_ids.size()):
		var candidate_id = String(hero_ids[(start_index + offset) % hero_ids.size()])
		if candidate_id == "" or occupied.has(candidate_id) or unavailable.has(candidate_id):
			continue
		return candidate_id
	return ""

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
	var resolved_faction_id: String = String(existing_state.get("faction_id", faction_id))
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
	var normalized_roster = normalize_commander_roster(
		session,
		resolved_faction_id,
		commander_roster if commander_roster is Array else commander_roster_for_faction(session, resolved_faction_id)
	)
	var roster_entry := _commander_roster_entry(normalized_roster, resolved_roster_hero_id)
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
	commander_state["faction_id"] = resolved_faction_id
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
								_hero_battle_spell_ids(hero_template),
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

static func raid_commander_name(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return ""
	var commander_state = encounter.get("enemy_commander_state", {})
	if commander_state is Dictionary:
		var commander_name := String(commander_state.get("name", ""))
		if commander_name != "":
			return commander_name
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	return String(encounter_template.get("enemy_commander", {}).get("name", ""))

static func raid_commander_display_name(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return ""
	var commander_state = encounter.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		return commander_display_name(commander_state)
	return raid_commander_name(encounter)

static func raid_display_name(encounter: Dictionary) -> String:
	if encounter.is_empty():
		return "Hostile contact"
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var encounter_name := String(encounter_template.get("name", encounter.get("placement_id", "Raid host")))
	var commander_name := raid_commander_display_name(encounter)
	if commander_name == "" or String(encounter.get("spawned_by_faction_id", "")) == "":
		return encounter_name
	return "%s's %s" % [commander_name, encounter_name]

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

static func _active_commander_map(
	session: SessionStateStoreScript.SessionData,
	faction_id: String = ""
) -> Dictionary:
	var active: Dictionary = {}
	if session == null:
		return active
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if faction_id != "" and String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		var commander_state = encounter.get("enemy_commander_state", {})
		if not (commander_state is Dictionary) or commander_state.is_empty():
			continue
		var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
		if roster_hero_id == "":
			continue
		active[roster_hero_id] = {
			"placement_id": String(encounter.get("placement_id", "")),
			"commander_state": commander_state.duplicate(true),
		}
	return active

static func _normalize_commander_status(value: Variant) -> String:
	var status := String(value)
	if status in [COMMANDER_STATUS_AVAILABLE, COMMANDER_STATUS_ACTIVE, COMMANDER_STATUS_RECOVERING]:
		return status
	return COMMANDER_STATUS_AVAILABLE

static func _commander_entry_name(entry: Dictionary) -> String:
	var commander_state = entry.get("commander_state", {})
	if commander_state is Dictionary:
		var commander_name := String(commander_state.get("name", ""))
		if commander_name != "":
			return commander_name
	return String(ContentService.get_hero(String(entry.get("roster_hero_id", ""))).get("name", ""))

static func _commander_roster_entry(roster: Variant, roster_hero_id: String) -> Dictionary:
	if roster_hero_id == "" or not (roster is Array):
		return {}
	for entry_value in roster:
		if entry_value is Dictionary and String(entry_value.get("roster_hero_id", "")) == roster_hero_id:
			return entry_value
	return {}

static func _commander_name_from_source(source: Variant) -> String:
	if source is Dictionary:
		var commander_state = source.get("commander_state", {})
		if commander_state is Dictionary and String(commander_state.get("name", "")) != "":
			return String(commander_state.get("name", ""))
		if String(source.get("name", "")) != "":
			return String(source.get("name", ""))
		if String(source.get("roster_hero_id", "")) != "":
			return String(ContentService.get_hero(String(source.get("roster_hero_id", ""))).get("name", ""))
	return ""

static func record_target_assignment(
	commander_state: Dictionary,
	target_kind: String,
	target_id: String,
	target_label: String,
	target_x: int = 0,
	target_y: int = 0
) -> Dictionary:
	if commander_state.is_empty() or target_kind == "" or target_id == "":
		return _apply_commander_memory_metadata(commander_state, commander_state)
	var updated := commander_state.duplicate(true)
	var memory := _normalized_commander_memory(updated)
	var is_focus_match := (
		target_kind == String(memory.get("focus_target_kind", ""))
		and target_id == String(memory.get("focus_target_id", ""))
	)
	var is_last_match := (
		target_kind == String(memory.get("last_target_kind", ""))
		and target_id == String(memory.get("last_target_id", ""))
	)
	var next_focus_count := 1
	if is_focus_match:
		next_focus_count = max(1, int(memory.get("focus_pressure_count", 0))) + 1
	elif is_last_match:
		next_focus_count = max(2, int(memory.get("focus_pressure_count", 0)))
	memory["focus_target_kind"] = target_kind
	memory["focus_target_id"] = target_id
	memory["focus_target_label"] = target_label
	memory["focus_pressure_count"] = next_focus_count
	memory["last_target_kind"] = target_kind
	memory["last_target_id"] = target_id
	memory["last_target_label"] = target_label
	memory["front_label"] = target_label
	memory["front_x"] = target_x
	memory["front_y"] = target_y
	updated["target_memory"] = memory
	return _apply_commander_memory_metadata(updated, memory)

static func record_rivalry(
	commander_state: Dictionary,
	rival_kind: String,
	rival_id: String,
	rival_label: String
) -> Dictionary:
	if commander_state.is_empty() or rival_kind == "" or rival_id == "":
		return _apply_commander_memory_metadata(commander_state, commander_state)
	var updated := commander_state.duplicate(true)
	var memory := _normalized_commander_memory(updated)
	var rivalry_count := 1
	if rival_kind == String(memory.get("rival_kind", "")) and rival_id == String(memory.get("rival_id", "")):
		rivalry_count = max(1, int(memory.get("rivalry_count", 0))) + 1
	memory["rival_kind"] = rival_kind
	memory["rival_id"] = rival_id
	memory["rival_label"] = rival_label
	memory["rivalry_count"] = rivalry_count
	updated["target_memory"] = memory
	return _apply_commander_memory_metadata(updated, memory)

static func _normalized_commander_record(entry_value: Variant, commander_state_value: Variant = {}) -> Dictionary:
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var commander_state: Dictionary = commander_state_value if commander_state_value is Dictionary else {}
	var deployments: int = max(0, max(int(entry.get("deployments", 0)), int(commander_state.get("deployments", 0))))
	var battle_wins: int = max(0, max(int(entry.get("battle_wins", 0)), int(commander_state.get("battle_wins", 0))))
	var times_defeated: int = max(0, max(int(entry.get("times_defeated", 0)), int(commander_state.get("times_defeated", 0))))
	var last_outcome := String(commander_state.get("last_outcome", ""))
	if last_outcome == "":
		last_outcome = String(entry.get("last_outcome", ""))
	var record := {
		"deployments": deployments,
		"battle_wins": battle_wins,
		"times_defeated": times_defeated,
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
	}
	if (
		String(memory.get("focus_target_id", "")) == ""
		and String(memory.get("last_target_id", "")) == ""
		and String(memory.get("rival_id", "")) == ""
		and String(memory.get("front_label", "")) == ""
		and int(memory.get("focus_pressure_count", 0)) <= 0
		and int(memory.get("rivalry_count", 0)) <= 0
	):
		return {}
	return memory

static func _commander_renown_from_record(record: Dictionary) -> int:
	var deployments: int = max(0, int(record.get("deployments", 0)))
	var battle_wins: int = max(0, int(record.get("battle_wins", 0)))
	var times_defeated: int = max(0, int(record.get("times_defeated", 0)))
	return clamp((deployments + (battle_wins * 2)) - times_defeated, 0, 9)

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
	var memory := _normalized_commander_memory(memory_source, commander)
	commander["target_memory"] = memory
	commander["memory_brief"] = commander_memory_brief(memory)
	commander["memory_summary"] = commander_memory_summary(memory)
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
		_army_strength(_base_enemy_army(resolved_encounter_id).get("stacks", [])),
		_army_strength(stacks)
	)
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
	while HeroProgressionRulesScript.pending_choices_remaining(commander) > 0 and guard < 8:
		var pending_choice := HeroProgressionRulesScript.current_pending_choice(commander)
		if pending_choice.is_empty():
			break
		var chosen_specialty := _preferred_enemy_specialty_id(commander, pending_choice)
		if chosen_specialty == "":
			break
		var choice_result := HeroProgressionRulesScript.choose_specialty(commander, chosen_specialty)
		commander = choice_result.get("hero", commander)
		guard += 1
	return HeroProgressionRulesScript.ensure_hero_progression(commander)

static func _award_enemy_commander_experience(commander_state: Dictionary, amount: int) -> Dictionary:
	if amount <= 0:
		return _normalize_enemy_progression(commander_state)
	var result := HeroProgressionRulesScript.add_experience(commander_state, amount)
	return _normalize_enemy_progression(result.get("hero", commander_state))

static func _preferred_enemy_specialty_id(commander_state: Dictionary, pending_choice: Dictionary) -> String:
	var options = pending_choice.get("options", [])
	if not (options is Array) or options.is_empty():
		return ""
	for specialty_id_value in commander_state.get("specialty_focus_ids", []):
		var specialty_id := String(specialty_id_value)
		if specialty_id in options:
			return specialty_id
	return String(options[0])

static func _normalized_specialty_ranks(primary: Variant, secondary: Variant = []) -> Array:
	var hero_stub := {"specialties": []}
	var normalized := []
	for source in [secondary, primary]:
		if not (source is Array):
			continue
		for specialty_value in source:
			var specialty_id := String(specialty_value)
			if HeroProgressionRulesScript.specialty_definition(specialty_id).is_empty():
				continue
			var trial := normalized.duplicate()
			trial.append(specialty_id)
			hero_stub["specialties"] = trial
			normalized = HeroProgressionRulesScript.ensure_hero_progression(hero_stub).get("specialties", normalized)
	return normalized

static func _normalized_specialty_focus_ids(value: Variant) -> Array:
	var normalized := []
	if not (value is Array):
		return normalized
	for specialty_value in value:
		var specialty_id := String(specialty_value)
		if specialty_id == "" or specialty_id in normalized:
			continue
		if HeroProgressionRulesScript.specialty_definition(specialty_id).is_empty():
			continue
		normalized.append(specialty_id)
	return normalized

static func _hero_battle_spell_ids(hero_template: Dictionary) -> Array:
	var spell_ids := []
	for spell_id_value in hero_template.get("starting_spell_ids", []):
		var spell_id := String(spell_id_value)
		if spell_id == "":
			continue
		if String(ContentService.get_spell(spell_id).get("context", "")) != SpellRulesScript.CONTEXT_BATTLE:
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
	var placement_id := String(encounter.get("placement_id", encounter.get("encounter_id", "")))
	if placement_id == "":
		return 0
	return abs(int(hash(placement_id)))

static func _clear_delivery_intercept_target(raid: Dictionary) -> Dictionary:
	if raid.is_empty():
		return raid
	raid["delivery_intercept_node_placement_id"] = ""
	raid["delivery_intercept_target_kind"] = ""
	raid["delivery_intercept_target_id"] = ""
	raid["delivery_intercept_label"] = ""
	return raid

static func _current_target_snapshot(raid: Dictionary) -> Dictionary:
	if raid.is_empty():
		return {}
	return {
		"target_kind": String(raid.get("target_kind", "")),
		"target_placement_id": String(raid.get("target_placement_id", "")),
		"target_label": String(raid.get("target_label", "")),
		"target_x": int(raid.get("target_x", raid.get("goal_x", 0))),
		"target_y": int(raid.get("target_y", raid.get("goal_y", 0))),
	}

static func _target_signature(target: Dictionary) -> String:
	if target.is_empty():
		return ""
	return "%s:%s" % [String(target.get("target_kind", "")), String(target.get("target_placement_id", ""))]

static func choose_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	origin: Dictionary,
	commander_source: Variant = {}
) -> Dictionary:
	var origin_pos = Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var candidates = _target_candidates(session, config, origin_pos)
	if candidates.is_empty():
		var hero_position: Dictionary = session.overworld.get("hero_position", {"x": 0, "y": 0})
		var active_hero_id := String(session.overworld.get("active_hero_id", ""))
		return {
			"target_kind": "hero",
			"target_placement_id": active_hero_id,
			"target_label": String(session.overworld.get("hero", {}).get("name", "the hero")),
			"target_x": int(hero_position.get("x", 0)),
			"target_y": int(hero_position.get("y", 0)),
			"goal_x": int(hero_position.get("x", 0)),
			"goal_y": int(hero_position.get("y", 0)),
			"goal_distance": abs(origin_pos.x - int(hero_position.get("x", 0))) + abs(origin_pos.y - int(hero_position.get("y", 0))),
		}

	var repeated_rival_memory := _normalized_commander_memory(commander_source)
	var repeated_rival_kind := String(repeated_rival_memory.get("rival_kind", ""))
	var repeated_rival_id := String(repeated_rival_memory.get("rival_id", ""))
	var repeated_rival_count: int = max(0, int(repeated_rival_memory.get("rivalry_count", 0)))
	var repeated_rival_index: int = -1
	var best_priority: int = 0
	for index in range(candidates.size()):
		if not (candidates[index] is Dictionary):
			continue
		var candidate: Dictionary = candidates[index]
		candidate["priority"] = max(
			0,
			int(candidate.get("priority", 0)) + _commander_memory_priority_bonus(session, candidate, commander_source)
		)
		best_priority = max(best_priority, int(candidate.get("priority", 0)))
		if (
			repeated_rival_count >= 2
			and String(candidate.get("target_kind", "")) == repeated_rival_kind
			and String(candidate.get("target_placement_id", "")) == repeated_rival_id
		):
			repeated_rival_index = index
		candidates[index] = candidate
	if repeated_rival_index >= 0:
		var repeated_rival_candidate: Dictionary = candidates[repeated_rival_index]
		repeated_rival_candidate["priority"] = max(
			int(repeated_rival_candidate.get("priority", 0)),
			best_priority + 35 + (min(4, repeated_rival_count) * 10)
		)
		candidates[repeated_rival_index] = repeated_rival_candidate

	var best: Dictionary = candidates[0]
	for index in range(1, candidates.size()):
		var candidate = candidates[index]
		if _candidate_beats(candidate, best):
			best = candidate
	return best

static func enemy_strategy(config: Dictionary, faction_id: String) -> Dictionary:
	var strategy = _default_enemy_strategy()
	var faction = ContentService.get_faction(faction_id)
	if faction.get("enemy_strategy", {}) is Dictionary:
		strategy = _merge_strategy_dict(strategy, faction.get("enemy_strategy", {}))
	if config.get("strategy_overrides", {}) is Dictionary:
		strategy = _merge_strategy_dict(strategy, config.get("strategy_overrides", {}))
	return strategy

static func strategy_scalar(strategy: Dictionary, section: String, key: String, default_value: float = 1.0) -> float:
	var bucket = strategy.get(section, {})
	if not (bucket is Dictionary):
		return default_value
	return float(bucket.get(key, default_value))

static func strategy_int(strategy: Dictionary, section: String, key: String, default_value: int = 0) -> int:
	var bucket = strategy.get(section, {})
	if not (bucket is Dictionary):
		return default_value
	return int(bucket.get(key, default_value))

static func strategy_target_weight(
	config: Dictionary,
	faction_id: String,
	target_kind: String,
	placement_id: String,
	site_family: String = "",
	objective_anchor: bool = false
) -> float:
	var strategy = enemy_strategy(config, faction_id)
	var weight = strategy_scalar(strategy, "raid_target_weights", target_kind, 1.0)
	if target_kind == "town" and placement_id == String(config.get("siege_target_placement_id", "")):
		weight *= max(0.6, strategy_scalar(strategy, "raid", "town_siege_weight", 1.0))
	elif objective_anchor:
		weight *= max(0.6, strategy_scalar(strategy, "raid", "objective_weight", 1.0))
	if target_kind == "hero":
		weight *= max(0.6, strategy_scalar(strategy, "raid", "hero_hunt_weight", 1.0))
	if site_family != "":
		weight *= max(0.6, strategy_scalar(strategy, "site_family_weights", site_family, 1.0))
		if target_kind == "resource":
			weight *= max(0.6, strategy_scalar(strategy, "raid", "site_denial_weight", 1.0))
	return max(0.4, weight)

static func priority_target_bonus(config: Dictionary, placement_id: String) -> int:
	if placement_id == "":
		return 0
	var priority_targets = config.get("priority_target_placement_ids", [])
	if not (priority_targets is Array):
		return 0
	for priority_target in priority_targets:
		if String(priority_target) == placement_id:
			return max(0, int(config.get("priority_target_bonus", 95)))
	return 0

static func public_strategy_summary(config: Dictionary, faction_id: String) -> String:
	match faction_id:
		"faction_embercourt":
			if not (config.get("priority_target_placement_ids", []) is Array) or config.get("priority_target_placement_ids", []).is_empty():
				return "Priorities: hold towns, reinforce outposts, and grind forward on siege lanes"
			return "Priorities: stabilize the line, defend charter assets, and press key crossings"
		"faction_mireclaw":
			return "Priorities: cut logistics sites, chase exposed heroes, and keep raids rolling"
		"faction_sunvault":
			return "Priorities: secure relays and shrines, then align focused pushes on objectives"
		"faction_thornwake":
			return "Priorities: root roads, hold nurseries, and turn neutral lanes into recovery zones"
		"faction_brasshollow":
			return "Priorities: secure mines, stage siege engines, and exhaust resource fronts"
		"faction_veilmourn":
			return "Priorities: scout hidden routes, mark weak backs, and raid through fog lanes"
		_:
			return "Priorities: pressure objectives while contesting frontier assets"

static func target_site_family(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> String:
	if target_kind != "resource" or placement_id == "":
		return ""
	var resource_result = _find_resource_by_placement(session, placement_id)
	if int(resource_result.get("index", -1)) < 0:
		return ""
	return String(ContentService.get_resource_site(String(resource_result.get("node", {}).get("site_id", ""))).get("family", ""))

static func target_is_objective_anchor(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> bool:
	match target_kind:
		"town":
			return _town_is_objective_anchor(session, placement_id)
		"encounter":
			var encounter_result = _find_encounter_by_placement(session, placement_id)
			return int(encounter_result.get("index", -1)) >= 0 and _encounter_is_objective_anchor(session, encounter_result.get("encounter", {}))
		_:
			return false

static func pressuring_raid_count(session: SessionStateStoreScript.SessionData, faction_id: String, target_placement_id: String) -> int:
	var count = 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue
		if String(encounter.get("target_placement_id", "")) != target_placement_id:
			continue
		if bool(encounter.get("arrived", false)) or int(encounter.get("goal_distance", 9999)) == 0:
			count += 1
	return count

static func describe_focus(session: SessionStateStoreScript.SessionData, faction_id: String, public_only: bool = false) -> String:
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	var marching_counts = {}
	var pressure_counts = {}
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue
		if public_only and not _raid_is_public(session, encounter):
			continue
		var target_label = _raid_focus_label(encounter, public_only)
		if bool(encounter.get("arrived", false)) or int(encounter.get("goal_distance", 9999)) == 0:
			pressure_counts[target_label] = int(pressure_counts.get(target_label, 0)) + 1
		else:
			marching_counts[target_label] = int(marching_counts.get(target_label, 0)) + 1

	var parts = []
	var marching = _describe_count_map("march on", marching_counts)
	if marching != "":
		parts.append(marching)
	var pressuring = _describe_count_map("press", pressure_counts)
	if pressuring != "":
		parts.append(pressuring)
	return " | ".join(parts)

static func _raid_focus_label(encounter: Dictionary, public_only: bool = false) -> String:
	var label := String(encounter.get("target_label", "the frontier"))
	var reason := String(encounter.get("target_public_reason", ""))
	if reason == "":
		return label
	if public_only and String(encounter.get("target_public_importance", "low")) == "low":
		return label
	return "%s (%s)" % [label, reason]

static func describe_contestation(session: SessionStateStoreScript.SessionData, faction_id: String, public_only: bool = false) -> String:
	var secured_sites = 0
	var seized_relics = 0
	var contested_fronts = []
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		if String(node.get("collected_by_faction_id", "")) != faction_id:
			continue
		if public_only and not OverworldRulesScript.is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1))):
			continue
		secured_sites += 1
	for node in session.overworld.get("artifact_nodes", []):
		if not (node is Dictionary):
			continue
		if String(node.get("collected_by_faction_id", "")) != faction_id:
			continue
		if public_only and not OverworldRulesScript.is_tile_visible(session, int(node.get("x", -1)), int(node.get("y", -1))):
			continue
		seized_relics += 1
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if OverworldRulesScript.is_encounter_resolved(session, encounter):
			continue
		if String(encounter.get("contested_by_faction_id", "")) != faction_id:
			continue
		if public_only and not OverworldRulesScript.is_tile_visible(session, int(encounter.get("x", -1)), int(encounter.get("y", -1))):
			continue
		var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
		var label = String(encounter_template.get("name", encounter.get("placement_id", "frontier camp")))
		if label != "" and label not in contested_fronts:
			contested_fronts.append(label)

	var parts = []
	if secured_sites > 0:
		parts.append("%d secured site%s" % [secured_sites, "" if secured_sites == 1 else "s"])
	if seized_relics > 0:
		parts.append("%d seized relic%s" % [seized_relics, "" if seized_relics == 1 else "s"])
	if not contested_fronts.is_empty():
		parts.append("contests %s" % ", ".join(contested_fronts.slice(0, min(2, contested_fronts.size()))))
	return " | ".join(parts)

static func visible_raid_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	var count = 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue
		if _raid_is_public(session, encounter):
			count += 1
	return count

static func raid_strength(encounter: Dictionary) -> int:
	var normalized_army = _normalize_army_payload(encounter.get("enemy_army", {}))
	if normalized_army.is_empty():
		normalized_army = _base_enemy_army(String(encounter.get("encounter_id", encounter.get("id", ""))))
	return _army_strength(normalized_army.get("stacks", []))

static func desired_raid_strength(encounter: Dictionary) -> int:
	var base_strength: int = max(
		120,
		_army_strength(
			_base_enemy_army(String(encounter.get("encounter_id", encounter.get("id", "")))).get("stacks", [])
		)
	)
	var multiplier = 1.1
	match String(encounter.get("target_kind", "")):
		"town":
			multiplier = 1.45
		"hero":
			multiplier = 1.25
		"encounter":
			multiplier = 1.35
		"artifact":
			multiplier = 1.25
		"resource":
			multiplier = 1.15
	if String(encounter.get("delivery_intercept_node_placement_id", "")) != "":
		multiplier = max(multiplier, 1.4)
	if bool(encounter.get("arrived", false)):
		multiplier += 0.15
	var commander_state = encounter.get("enemy_commander_state", {})
	var commander_record := _normalized_commander_record(commander_state)
	var veterancy_bonus: int = (max(0, int(commander_record.get("renown", 0))) * 16) + (
		_commander_veterancy_rank_from_record(commander_record) * 12
	)
	match String(commander_record.get("last_outcome", "")):
		COMMANDER_OUTCOME_ROUT_VICTORY:
			multiplier += 0.18
		COMMANDER_OUTCOME_PURSUIT_VICTORY:
			multiplier += 0.1
		COMMANDER_OUTCOME_CAPITULATION:
			multiplier += 0.06
	return int(round(float(base_strength) * multiplier)) + veterancy_bonus

static func raid_pillage_weight(encounter: Dictionary) -> int:
	var base_strength: int = max(
		1,
		_army_strength(
			_base_enemy_army(String(encounter.get("encounter_id", encounter.get("id", "")))).get("stacks", [])
		)
	)
	var current_strength: int = max(1, raid_strength(encounter))
	return clamp(int(ceili(float(current_strength) / float(base_strength))), 1, 3)

static func _target_candidates(session: SessionStateStoreScript.SessionData, config: Dictionary, origin_pos: Vector2i) -> Array:
	var seen = {}
	var candidates = []
	var faction_id = String(config.get("faction_id", ""))
	var scenario = ContentService.get_scenario(session.scenario_id)
	var siege_target_id = String(config.get("siege_target_placement_id", ""))
	if siege_target_id != "":
		_append_town_candidate(session, candidates, seen, siege_target_id, origin_pos, 320, config, faction_id)

	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		for objective in objectives.get("defeat", []):
			if objective is Dictionary and String(objective.get("type", "")) in ["town_owned_by_player", "town_not_owned_by_player"]:
				_append_town_candidate(session, candidates, seen, String(objective.get("placement_id", "")), origin_pos, 260, config, faction_id)
		for objective in objectives.get("victory", []):
			if objective is Dictionary and String(objective.get("type", "")) in ["town_owned_by_player", "town_not_owned_by_player"]:
				_append_town_candidate(session, candidates, seen, String(objective.get("placement_id", "")), origin_pos, 220, config, faction_id)

	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "player":
			continue
		var base_priority = 180
		if _town_started_enemy(session, String(town.get("placement_id", ""))):
			base_priority += 50
		if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
			base_priority += 20
		_append_town_candidate(session, candidates, seen, String(town.get("placement_id", "")), origin_pos, base_priority, config, faction_id)

	for node in session.overworld.get("resource_nodes", []):
		_append_resource_candidate(
			session,
			candidates,
			seen,
			node,
			origin_pos,
			config,
			faction_id
		)

	for node in session.overworld.get("artifact_nodes", []):
		_append_artifact_candidate(
			session,
			candidates,
			seen,
			node,
			origin_pos,
			_artifact_target_priority(session, node),
			config,
			faction_id
		)

	for encounter in session.overworld.get("encounters", []):
		_append_encounter_candidate(
			session,
			candidates,
			seen,
			encounter,
			origin_pos,
			_encounter_target_priority(session, encounter),
			config,
			faction_id
		)

	_append_delivery_interception_candidates(session, candidates, seen, origin_pos, config, faction_id)

	var hero_candidates = _hero_target_candidates(session, origin_pos, config, faction_id)
	for hero_candidate in hero_candidates:
		if hero_candidate is Dictionary and not hero_candidate.is_empty():
			candidates.append(hero_candidate)
	return candidates

static func _append_town_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	placement_id: String,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String
) -> void:
	var seen_key = "town:%s" % placement_id
	if placement_id == "" or seen.has(seen_key):
		return
	var town_result = _find_town_by_placement(session, placement_id)
	if int(town_result.get("index", -1)) < 0:
		return
	var town = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return

	seen[seen_key] = true
	var staging_tiles = _town_staging_tiles(session, town)
	var goal_tile = _best_goal_tile(session, origin_pos, staging_tiles)
	var goal_distance = _path_distance(session, origin_pos, staging_tiles, "")
	if goal_distance >= 9999:
		return
	var objective_anchor = _town_is_objective_anchor(session, placement_id)
	var strategic_bonus = _town_strategic_priority_bonus(session, town, faction_id, objective_anchor)
	var reason_codes := ["town_siege"]
	if objective_anchor:
		reason_codes.append("objective_front")
	candidates.append(
		{
			"target_kind": "town",
			"target_placement_id": placement_id,
			"target_label": _town_name(town),
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				_weighted_priority(
					config,
					faction_id,
					"town",
					placement_id,
					priority + strategic_bonus,
					"",
					objective_anchor
				) - _assignment_penalty(session, "town", placement_id)
			),
			"target_reason_codes": reason_codes,
			"target_public_reason": "town siege remains the main front" if placement_id == String(config.get("siege_target_placement_id", "")) else "town front pressure",
			"target_debug_reason": "town siege and objective pressure" if objective_anchor else "town siege pressure",
			"target_public_importance": "critical" if objective_anchor or placement_id == String(config.get("siege_target_placement_id", "")) else "high",
		}
	)

static func _append_resource_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String
) -> void:
	if not (node is Dictionary):
		return
	var placement_id = String(node.get("placement_id", ""))
	var seen_key = "resource:%s" % placement_id
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if placement_id == "" or seen.has(seen_key) or not _resource_node_contestable_by_faction(node, site, faction_id):
		return
	seen[seen_key] = true
	var goal_tile = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var goal_distance = _path_distance(session, origin_pos, [goal_tile], "")
	if goal_distance >= 9999:
		return
	var breakdown := resource_target_score_breakdown(session, config, node, origin_pos, faction_id)
	var priority := int(breakdown.get("final_priority", 0))
	var reason_codes: Array = breakdown.get("reason_codes", [])
	candidates.append(
		{
			"target_kind": "resource",
			"target_placement_id": placement_id,
			"target_label": String(site.get("name", "Resource Site")),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": priority,
			"target_debug_reason": String(breakdown.get("debug_reason", "")),
			"target_reason_codes": reason_codes,
			"target_public_reason": String(breakdown.get("public_reason", "")),
			"target_public_importance": String(breakdown.get("public_importance", "low")),
		}
	)

static func _append_artifact_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String
) -> void:
	if not (node is Dictionary):
		return
	var placement_id = String(node.get("placement_id", ""))
	var seen_key = "artifact:%s" % placement_id
	if placement_id == "" or seen.has(seen_key) or bool(node.get("collected", false)):
		return
	seen[seen_key] = true
	var goal_tile = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var goal_distance = _path_distance(session, origin_pos, [goal_tile], "")
	if goal_distance >= 9999:
		return
	candidates.append(
		{
			"target_kind": "artifact",
			"target_placement_id": placement_id,
			"target_label": ArtifactRulesScript.describe_artifact(String(node.get("artifact_id", ""))),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				_weighted_priority(
					config,
					faction_id,
					"artifact",
					placement_id,
					priority,
					"",
					false
				) - _assignment_penalty(session, "artifact", placement_id)
			),
		}
	)

static func _append_encounter_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	encounter: Variant,
	origin_pos: Vector2i,
	priority: int,
	config: Dictionary,
	faction_id: String
) -> void:
	if not (encounter is Dictionary):
		return
	if String(encounter.get("spawned_by_faction_id", "")) != "":
		return
	if OverworldRulesScript.is_encounter_resolved(session, encounter):
		return
	var placement_id = String(encounter.get("placement_id", ""))
	var seen_key = "encounter:%s" % placement_id
	if placement_id == "" or seen.has(seen_key):
		return
	seen[seen_key] = true
	var staging_tiles = _encounter_staging_tiles(session, encounter)
	var goal_distance = _path_distance(session, origin_pos, staging_tiles, "")
	if goal_distance >= 9999:
		return
	var goal_tile = _best_goal_tile(session, origin_pos, staging_tiles)
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var objective_anchor = _encounter_is_objective_anchor(session, encounter)
	candidates.append(
		{
			"target_kind": "encounter",
			"target_placement_id": placement_id,
			"target_label": String(encounter_template.get("name", "Frontier Camp")),
			"target_x": int(encounter.get("x", 0)),
			"target_y": int(encounter.get("y", 0)),
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				_weighted_priority(
					config,
					faction_id,
					"encounter",
					placement_id,
					priority,
					"",
					objective_anchor
				) - _assignment_penalty(session, "encounter", placement_id)
			),
		}
	)

static func _append_delivery_interception_candidates(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	seen: Dictionary,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String
) -> void:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var placement_id := String(node.get("placement_id", ""))
		var seen_key := "delivery:%s" % placement_id
		if placement_id == "" or seen.has(seen_key):
			continue
		var site: Dictionary = ContentService.get_resource_site(String(node.get("site_id", "")))
		var delivery_state: Dictionary = OverworldRulesScript._resource_site_delivery_state(session, node, site)
		if not bool(delivery_state.get("active", false)) or String(delivery_state.get("controller_id", "")) != "player":
			continue
		seen[seen_key] = true
		match String(delivery_state.get("target_kind", "")):
			"town":
				var town_candidate: Dictionary = _delivery_town_candidate(session, origin_pos, config, faction_id, node, site, delivery_state)
				if not town_candidate.is_empty():
					candidates.append(town_candidate)
			"hero":
				var hero_candidate: Dictionary = _delivery_hero_candidate(session, origin_pos, config, faction_id, node, site, delivery_state)
				if not hero_candidate.is_empty():
					candidates.append(hero_candidate)

static func _delivery_town_candidate(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	node: Dictionary,
	site: Dictionary,
	delivery_state: Dictionary
) -> Dictionary:
	var town_result = _find_town_by_placement(session, String(delivery_state.get("target_id", "")))
	if int(town_result.get("index", -1)) < 0:
		return {}
	var town: Dictionary = town_result.get("town", {})
	if String(town.get("owner", "neutral")) != "player":
		return {}
	var staging_tiles = _town_staging_tiles(session, town)
	var goal_distance = _path_distance(session, origin_pos, staging_tiles, "")
	if goal_distance >= 9999:
		return {}
	var goal_tile = _best_goal_tile(session, origin_pos, staging_tiles)
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
	var objective_anchor := _town_is_objective_anchor(session, String(town.get("placement_id", "")))
	var priority = 210 + int(min(180.0, float(int(delivery_state.get("manifest_value", 0))) / 9.0))
	priority += int(max(0, 3 - int(delivery_state.get("days_remaining", 0)))) * 24
	priority += _town_strategic_priority_bonus(session, town, faction_id, objective_anchor)
	priority += int(logistics.get("support_gap", 0)) * 18
	priority += int(logistics.get("delivery_count", 0)) * 12
	priority += int(recovery.get("pressure", 0)) * 12
	if bool(capital_project.get("vulnerable", false)):
		priority += 26
	return {
		"target_kind": "town",
		"target_placement_id": String(town.get("placement_id", "")),
		"target_label": "%s relief lane" % _town_name(town),
		"target_x": int(town.get("x", 0)),
		"target_y": int(town.get("y", 0)),
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": max(
			0,
			_weighted_priority(
				config,
				faction_id,
				"town",
				String(town.get("placement_id", "")),
				priority,
				"",
				objective_anchor
			) - _assignment_penalty(session, "town", String(town.get("placement_id", "")))
		),
		"delivery_intercept_node_placement_id": String(node.get("placement_id", "")),
		"delivery_intercept_target_kind": "town",
		"delivery_intercept_target_id": String(town.get("placement_id", "")),
		"delivery_intercept_label": "%s convoy to %s" % [
			String(site.get("name", "Frontier route")),
			String(delivery_state.get("target_label", _town_name(town))),
		],
	}

static func _delivery_hero_candidate(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	node: Dictionary,
	site: Dictionary,
	delivery_state: Dictionary
) -> Dictionary:
	var hero: Dictionary = _find_player_hero(session, String(delivery_state.get("target_id", "")))
	if hero.is_empty():
		return {}
	var goal_tile := _player_hero_goal_tile(hero)
	var goal_distance = _path_distance(session, origin_pos, [goal_tile], "")
	if goal_distance >= 9999:
		return {}
	var priority = 195 + int(min(170.0, float(int(delivery_state.get("manifest_value", 0))) / 10.0))
	priority += int(max(0, 3 - int(delivery_state.get("days_remaining", 0)))) * 22
	if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
		priority += 28
	if bool(hero.get("is_primary", false)):
		priority += 20
	var hero_strength: int = _army_strength(hero.get("army", {}).get("stacks", []))
	if hero_strength <= 110:
		priority += 34
	elif hero_strength <= 180:
		priority += 18
	return {
		"target_kind": "hero",
		"target_placement_id": String(hero.get("id", "")),
		"target_label": "%s convoy" % String(hero.get("name", "the hero")),
		"target_x": goal_tile.x,
		"target_y": goal_tile.y,
		"goal_x": goal_tile.x,
		"goal_y": goal_tile.y,
		"goal_distance": goal_distance,
		"priority": max(
			0,
			_weighted_priority(
				config,
				faction_id,
				"hero",
				String(hero.get("id", "")),
				priority,
				"",
				false
			) - _assignment_penalty(session, "hero", String(hero.get("id", "")))
		),
		"delivery_intercept_node_placement_id": String(node.get("placement_id", "")),
		"delivery_intercept_target_kind": "hero",
		"delivery_intercept_target_id": String(hero.get("id", "")),
		"delivery_intercept_label": "%s convoy to %s" % [
			String(site.get("name", "Frontier route")),
			String(hero.get("name", "the hero")),
		],
	}

static func _hero_target_candidates(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String
) -> Array:
	var candidates := []
	var seen_hero_ids := {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero_value in session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		var hero_id := String(hero.get("id", ""))
		if hero_id == "":
			continue
		seen_hero_ids[hero_id] = true
		_append_hero_target_candidate(session, candidates, hero, origin_pos, config, faction_id, active_hero_id)
	if active_hero_id != "" and not seen_hero_ids.has(active_hero_id):
		var active_hero_value = session.overworld.get("hero", {})
		if active_hero_value is Dictionary:
			var active_hero: Dictionary = active_hero_value.duplicate(true)
			active_hero["id"] = active_hero_id
			var active_position = active_hero.get("position", {})
			if not (active_position is Dictionary) or active_position.is_empty():
				var position_source = session.overworld.get("hero_position", {"x": 0, "y": 0})
				if position_source is Dictionary:
					active_hero["position"] = position_source.duplicate(true)
			active_hero["is_primary"] = true
			_append_hero_target_candidate(session, candidates, active_hero, origin_pos, config, faction_id, active_hero_id)
	return candidates

static func _append_hero_target_candidate(
	session: SessionStateStoreScript.SessionData,
	candidates: Array,
	hero: Dictionary,
	origin_pos: Vector2i,
	config: Dictionary,
	faction_id: String,
	active_hero_id: String
) -> void:
	var hero_id := String(hero.get("id", ""))
	if hero_id == "":
		return
	var goal_tile := _player_hero_goal_tile(hero)
	var goal_distance: int = _hero_target_goal_distance(session, origin_pos, goal_tile)
	if goal_distance >= 9999:
		return
	var priority = 95
	if hero_id == active_hero_id:
		priority += 26
	if bool(hero.get("is_primary", false)):
		priority += 18
	var army_strength: int = _army_strength(hero.get("army", {}).get("stacks", []))
	if army_strength <= 110:
		priority += 26
	elif army_strength <= 180:
		priority += 14
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		var distance: int = abs(goal_tile.x - int(town.get("x", 0))) + abs(goal_tile.y - int(town.get("y", 0)))
		if distance > 6:
			continue
		var defense_priority: int = 120 + max(0, (6 - distance) * 10)
		match OverworldRulesScript.town_strategic_role(town):
			"capital":
				defense_priority += 44
			"stronghold":
				defense_priority += 24
		if int(OverworldRulesScript.town_capital_project_state(town, session).get("active", 0)) > 0:
			defense_priority += 24
		if _town_is_objective_anchor(session, String(town.get("placement_id", ""))):
			defense_priority += 28
		priority = max(priority, defense_priority)
	candidates.append(
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": String(hero.get("name", "the hero")),
			"target_x": goal_tile.x,
			"target_y": goal_tile.y,
			"goal_x": goal_tile.x,
			"goal_y": goal_tile.y,
			"goal_distance": goal_distance,
			"priority": max(
				0,
				_weighted_priority(config, faction_id, "hero", hero_id, priority, "", false)
				- _assignment_penalty(session, "hero", hero_id)
			),
		}
	)

static func _hero_target_goal_distance(
	session: SessionStateStoreScript.SessionData,
	origin_pos: Vector2i,
	goal_tile: Vector2i
) -> int:
	var direct_distance: int = _path_distance(session, origin_pos, [goal_tile], "")
	if direct_distance < 9999:
		return direct_distance

	var occupied := _occupied_tiles(session, "")
	if not occupied.has(_pos_key(goal_tile)):
		return direct_distance

	var approach_tiles: Array = []
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var approach_tile: Vector2i = goal_tile + delta
		if approach_tile.x < 0 or approach_tile.y < 0 or approach_tile.x >= map_size.x or approach_tile.y >= map_size.y:
			continue
		if OverworldRulesScript.tile_is_blocked(session, approach_tile.x, approach_tile.y):
			continue
		if approach_tile != origin_pos and occupied.has(_pos_key(approach_tile)):
			continue
		approach_tiles.append(approach_tile)

	var approach_distance: int = _path_distance(session, origin_pos, approach_tiles, "")
	if approach_distance >= 9999:
		return direct_distance
	return approach_distance + 1

static func _find_player_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if session == null or hero_id == "":
		return {}
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return hero
	return {}

static func _player_hero_goal_tile(hero: Dictionary) -> Vector2i:
	var hero_position: Dictionary = hero.get("position", {})
	return Vector2i(int(hero_position.get("x", 0)), int(hero_position.get("y", 0)))

static func _hero_position_for_target(session: SessionStateStoreScript.SessionData, hero_id: String) -> Vector2i:
	if hero_id != "":
		var hero := _find_player_hero(session, hero_id)
		if not hero.is_empty():
			return _player_hero_goal_tile(hero)
	var hero_position: Dictionary = session.overworld.get("hero_position", {"x": 0, "y": 0})
	return Vector2i(int(hero_position.get("x", 0)), int(hero_position.get("y", 0)))

static func _hero_label_for_target(session: SessionStateStoreScript.SessionData, hero_id: String) -> String:
	if hero_id != "":
		var hero := _find_player_hero(session, hero_id)
		if not hero.is_empty():
			return String(hero.get("name", hero_id))
	return String(session.overworld.get("hero", {}).get("name", "the hero"))

static func _candidate_beats(candidate: Dictionary, best: Dictionary) -> bool:
	if int(candidate.get("priority", 0)) == int(best.get("priority", 0)):
		if int(candidate.get("goal_distance", 9999)) == int(best.get("goal_distance", 9999)):
			return String(candidate.get("target_label", "")) < String(best.get("target_label", ""))
		return int(candidate.get("goal_distance", 9999)) < int(best.get("goal_distance", 9999))
	return int(candidate.get("priority", 0)) > int(best.get("priority", 0))

static func resource_pressure_report(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	origin: Dictionary,
	faction_id: String = "",
	limit: int = 0
) -> Dictionary:
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var targets := []
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var breakdown := resource_target_score_breakdown(session, config, node_value, origin_pos, resolved_faction_id)
		if int(breakdown.get("final_priority", 0)) <= 0:
			continue
		targets.append(breakdown)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("final_priority", 0)) == int(b.get("final_priority", 0)):
			if int(a.get("travel_cost", 0)) == int(b.get("travel_cost", 0)):
				return String(a.get("placement_id", "")) < String(b.get("placement_id", ""))
			return int(a.get("travel_cost", 0)) < int(b.get("travel_cost", 0))
		return int(a.get("final_priority", 0)) > int(b.get("final_priority", 0))
	)
	if limit > 0 and targets.size() > limit:
		targets = targets.slice(0, limit)
	return {
		"scenario_id": String(session.scenario_id),
		"faction_id": resolved_faction_id,
		"origin": {"x": origin_pos.x, "y": origin_pos.y},
		"target_count": targets.size(),
		"targets": targets,
	}

static func commander_role_front_id(scenario_id: String, target_kind: String, target_id: String) -> String:
	if scenario_id == "river-pass" and target_id in ["river_free_company", "river_signal_post", "riverwatch_hold", "duskfen_bastion"]:
		return "riverwatch_signal_yard"
	if scenario_id == "glassroad-sundering" and target_id in ["glassroad_watch_relay", "glassroad_starlens", "halo_spire_bridgehead", "riverwatch_market"]:
		return "glassroad_charter_front"
	if target_kind == "town" and target_id != "":
		return "town:%s" % target_id
	if target_kind == "resource" and target_id != "":
		return "%s:resource:%s" % [scenario_id, target_id]
	if target_kind != "" and target_id != "":
		return "%s:%s:%s" % [scenario_id, target_kind, target_id]
	return ""

static func commander_role_public_reason_from_codes(reason_codes: Array) -> String:
	return _public_reason_from_codes(reason_codes)

static func commander_role_active_encounter_link(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String
) -> Dictionary:
	if session == null or faction_id == "" or roster_hero_id == "":
		return {
			"linked": false,
			"placement_id": "",
			"target_kind": "",
			"target_id": "",
		}
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue
		var commander_state = encounter.get("enemy_commander_state", {})
		if not (commander_state is Dictionary):
			continue
		if String(commander_state.get("roster_hero_id", "")) != roster_hero_id:
			continue
		return {
			"linked": true,
			"placement_id": String(encounter.get("placement_id", "")),
			"target_kind": String(encounter.get("target_kind", "")),
			"target_id": String(encounter.get("target_placement_id", "")),
			"target_label": String(encounter.get("target_label", "")),
		}
	return {
		"linked": false,
		"placement_id": "",
		"target_kind": "",
		"target_id": "",
	}

static func commander_role_state_view(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_entry: Dictionary
) -> Dictionary:
	var roster_hero_id := String(commander_entry.get("roster_hero_id", ""))
	var active_link := commander_role_active_encounter_link(session, faction_id, roster_hero_id)
	var status := _normalize_commander_status(commander_entry.get("status", COMMANDER_STATUS_AVAILABLE))
	var recovery_day: int = max(0, int(commander_entry.get("recovery_day", 0)))
	var session_day := int(session.day) if session != null else 0
	var role := COMMANDER_ROLE_RESERVE
	var role_status := "available"
	var validation := "valid"
	if status == COMMANDER_STATUS_RECOVERING and recovery_day > session_day:
		role = COMMANDER_ROLE_RECOVERING
		role_status = "cooldown"
		validation = "blocked_recovery"
	elif status == COMMANDER_STATUS_ACTIVE or bool(active_link.get("linked", false)):
		role = COMMANDER_ROLE_RAIDER
		role_status = "active"
	elif not commander_can_deploy(commander_entry):
		role = COMMANDER_ROLE_RECOVERING
		role_status = "rebuilding"
		validation = "blocked_rebuild"
	return {
		"schema_status": "report_fixture_only",
		"roster_hero_id": roster_hero_id,
		"status": status,
		"active_placement_id": String(commander_entry.get("active_placement_id", active_link.get("placement_id", ""))),
		"recovery_day": recovery_day,
		"army_status": commander_army_status(commander_entry),
		"army_summary": commander_army_summary(commander_entry),
		"memory_summary": commander_memory_summary(commander_entry),
		"display_name": commander_display_name(commander_entry, false),
		"role": role,
		"role_status": role_status,
		"last_validation": validation,
	}

static func commander_role_resource_target_view(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	placement_id: String,
	origin: Dictionary
) -> Dictionary:
	if session == null or placement_id == "":
		return {}
	var node_result := _find_resource_by_placement(session, placement_id)
	var node: Dictionary = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0:
		return {}
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var origin_pos := Vector2i(int(origin.get("x", 0)), int(origin.get("y", 0)))
	var breakdown := resource_target_score_breakdown(session, config, node, origin_pos, faction_id)
	var reason_codes: Array = _normalize_string_array(breakdown.get("reason_codes", []))
	if reason_codes.is_empty():
		reason_codes = _resource_target_reason_codes(
			site,
			String(node.get("collected_by_faction_id", "")) == "player",
			_resource_site_is_persistent(site),
			_target_resource_value(site.get("control_income", {})),
			_recruit_payload_value(site.get("claim_recruits", {})) + _recruit_payload_value(site.get("weekly_recruits", {})),
			_resource_route_pressure_value(site),
			_linked_player_town_bonus(session, node)
		)
	var target_x := int(node.get("x", 0))
	var target_y := int(node.get("y", 0))
	return {
		"target_kind": "resource",
		"target_id": placement_id,
		"target_label": String(site.get("name", placement_id)),
		"target_x": target_x,
		"target_y": target_y,
		"front_id": commander_role_front_id(String(session.scenario_id), "resource", placement_id),
		"origin_kind": "town",
		"origin_id": commander_role_origin_id(String(session.scenario_id), faction_id),
		"controller_id": String(node.get("collected_by_faction_id", "")),
		"site_id": String(node.get("site_id", "")),
		"site_family": String(site.get("family", "")),
		"reason_codes": reason_codes,
		"public_reason": _public_reason_from_codes(reason_codes),
		"public_importance": String(breakdown.get("public_importance", _resource_target_public_importance(String(node.get("collected_by_faction_id", "")) == "player", _resource_site_is_persistent(site), reason_codes, int(breakdown.get("final_priority", 0))))),
		"debug_reason": String(breakdown.get("debug_reason", "")),
		"resource_breakdown": breakdown,
	}

static func commander_role_origin_id(scenario_id: String, faction_id: String) -> String:
	if scenario_id == "river-pass" and faction_id == "faction_mireclaw":
		return "duskfen_bastion"
	if scenario_id == "glassroad-sundering" and faction_id == "faction_embercourt":
		return "riverwatch_market"
	return ""

static func commander_role_proposal_for_resource_target(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	commander_entry: Dictionary,
	target_view: Dictionary,
	fixture_state: Dictionary = {}
) -> Dictionary:
	var state_view := commander_role_state_view(session, faction_id, commander_entry)
	var blocked_proposal := commander_role_proposal_for_recovery(session, faction_id, commander_entry)
	if not blocked_proposal.is_empty():
		return blocked_proposal
	if target_view.is_empty():
		return {
			"role": COMMANDER_ROLE_RESERVE,
			"role_status": "available",
			"validity": "invalid_target_missing",
			"assignment_id_hint": "",
			"priority_reason_codes": [],
			"public_reason": "",
			"report_debug_reason": "report-only target missing",
			"expected_next_transition": "wait_for_target",
		}
	var role := COMMANDER_ROLE_RAIDER
	if String(fixture_state.get("fixture_previous_controller", "")) == faction_id:
		role = COMMANDER_ROLE_RETAKER
	elif bool(fixture_state.get("fixture_threatened_by_player_front", false)):
		role = COMMANDER_ROLE_DEFENDER
	elif bool(fixture_state.get("fixture_recently_secured", false)):
		role = COMMANDER_ROLE_STABILIZER
	elif bool(fixture_state.get("fixture_denial_only", false)):
		role = COMMANDER_ROLE_RAIDER
	var reason_codes: Array = _normalize_string_array(target_view.get("reason_codes", []))
	if role in [COMMANDER_ROLE_RETAKER, COMMANDER_ROLE_RAIDER, COMMANDER_ROLE_DEFENDER]:
		var target_id := String(target_view.get("target_id", ""))
		if target_id in ["river_free_company", "glassroad_watch_relay"] and "persistent_income_denial" not in reason_codes:
			reason_codes.push_front("persistent_income_denial")
		if target_id == "river_free_company" and "recruit_denial" not in reason_codes:
			reason_codes.append("recruit_denial")
		if target_id in ["river_signal_post", "glassroad_watch_relay"] and "route_vision" not in reason_codes:
			reason_codes.append("route_vision")
		if target_id in ["river_free_company", "river_signal_post", "glassroad_watch_relay"] and "player_town_support" not in reason_codes:
			reason_codes.append("player_town_support")
	if role == COMMANDER_ROLE_STABILIZER:
		reason_codes = ["route_pressure"] if String(target_view.get("target_id", "")) == "glassroad_starlens" else reason_codes
	var report_reason := "report-only role proposal"
	if String(state_view.get("memory_summary", "")) != "":
		report_reason += "; target memory: %s" % String(state_view.get("memory_summary", ""))
	return {
		"role": role,
		"role_status": "assigned",
		"validity": "valid",
		"assignment_id_hint": _commander_role_assignment_id_hint(session, faction_id, String(commander_entry.get("roster_hero_id", "")), role, "resource", String(target_view.get("target_id", ""))),
		"priority_reason_codes": reason_codes,
		"public_reason": _public_reason_from_codes(reason_codes),
		"report_debug_reason": report_reason,
		"expected_next_transition": _commander_role_expected_transition(role),
	}

static func commander_role_proposal_for_recovery(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_entry: Dictionary
) -> Dictionary:
	var state_view := commander_role_state_view(session, faction_id, commander_entry)
	match String(state_view.get("last_validation", "")):
		"blocked_recovery":
			return {
				"role": COMMANDER_ROLE_RECOVERING,
				"role_status": "cooldown",
				"validity": "blocked",
				"assignment_id_hint": "",
				"priority_reason_codes": ["commander_recovery"],
				"public_reason": "commander recovering",
				"report_debug_reason": "report-only recovery blocks active assignment until day %d" % int(state_view.get("recovery_day", 0)),
				"expected_next_transition": "wait_until_recovery_day",
			}
		"blocked_rebuild":
			return {
				"role": COMMANDER_ROLE_RECOVERING,
				"role_status": "rebuilding",
				"validity": "blocked",
				"assignment_id_hint": "",
				"priority_reason_codes": ["commander_rebuild"],
				"public_reason": "commander rebuilding",
				"report_debug_reason": "report-only rebuild blocks active assignment",
				"expected_next_transition": "rebuild_host_then_reserve",
			}
	return {}

static func commander_role_public_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	commander_entry: Dictionary,
	target_view: Dictionary,
	role_proposal: Dictionary
) -> Dictionary:
	var actor_id := String(commander_entry.get("roster_hero_id", ""))
	var actor_label := commander_display_name(commander_entry, false)
	if actor_label == "":
		actor_label = actor_id
	var target_kind := String(target_view.get("target_kind", ""))
	var target_id := String(target_view.get("target_id", ""))
	var target_label := String(target_view.get("target_label", target_id))
	if target_kind == "" or target_id == "":
		target_kind = "commander"
		target_id = actor_id
		target_label = actor_label
	var reason_codes: Array = _normalize_string_array(role_proposal.get("priority_reason_codes", []))
	var public_reason := String(role_proposal.get("public_reason", _public_reason_from_codes(reason_codes)))
	var summary := "%s assigned as %s for %s" % [
		actor_label,
		String(role_proposal.get("role", COMMANDER_ROLE_RESERVE)),
		target_label,
	]
	if public_reason != "":
		summary += " (%s)" % public_reason
	summary += "."
	return {
		"event_id": "%d:%s:ai_commander_role_assigned:%s:%s" % [int(session.day), faction_id, actor_id, target_id],
		"day": int(session.day),
		"sequence": 0,
		"event_type": "ai_commander_role_assigned",
		"faction_id": faction_id,
		"faction_label": String(config.get("label", faction_id)),
		"actor_id": actor_id,
		"actor_label": actor_label,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"target_x": int(target_view.get("target_x", 0)),
		"target_y": int(target_view.get("target_y", 0)),
		"visibility": _event_visibility(session, int(target_view.get("target_x", 0)), int(target_view.get("target_y", 0)), String(target_view.get("public_importance", "medium"))),
		"public_importance": String(target_view.get("public_importance", "medium")),
		"summary": summary,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"debug_reason": "derived commander role",
		"state_policy": "derived",
	}

static func commander_role_public_leak_check(public_surfaces: Variant) -> Dictionary:
	var blocked := COMMANDER_ROLE_BLOCKED_PUBLIC_TOKENS
	var allowed := COMMANDER_ROLE_PUBLIC_EVENT_KEYS
	var stack := [public_surfaces]
	var checked_events := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if not (value is Dictionary):
			var value_text := String(value)
			for token in blocked:
				if value_text.contains(String(token)):
					return {"ok": false, "error": "public surface leaked token %s" % String(token)}
			continue
		if String(value.get("event_type", "")) != "":
			checked_events += 1
			for key in value.keys():
				if String(key) not in allowed:
					return {"ok": false, "error": "%s leaked non-compact key %s" % [value.get("event_type", "event"), key]}
		var text := JSON.stringify(value)
		for token in blocked:
			if text.contains(String(token)):
				return {"ok": false, "error": "%s leaked blocked token %s" % [value.get("event_type", "event"), token]}
		for nested_key in value.keys():
			var nested = value[nested_key]
			if nested is Array or nested is Dictionary:
				stack.append(nested)
	return {
		"ok": true,
		"checked_events": checked_events,
		"allowed_public_event_keys": allowed,
		"blocked_public_tokens": blocked,
	}

static func ai_target_assignment_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	actor: Dictionary,
	previous_target: Dictionary = {}
) -> Dictionary:
	var target_kind := String(actor.get("target_kind", ""))
	var target_id := String(actor.get("target_placement_id", ""))
	if target_kind == "" or target_id == "":
		return {}
	if not previous_target.is_empty() and _target_signature(previous_target) == _target_signature(_current_target_snapshot(actor)):
		return {}
	var target := {
		"target_kind": target_kind,
		"target_placement_id": target_id,
		"target_label": String(actor.get("target_label", target_id)),
		"target_x": int(actor.get("target_x", actor.get("goal_x", 0))),
		"target_y": int(actor.get("target_y", actor.get("goal_y", 0))),
		"target_public_reason": String(actor.get("target_public_reason", "")),
		"target_reason_codes": actor.get("target_reason_codes", []),
		"target_public_importance": String(actor.get("target_public_importance", "")),
		"target_debug_reason": String(actor.get("target_debug_reason", "")),
	}
	return build_ai_event_record(
		session,
		config,
		"ai_target_assigned",
		actor,
		target,
		{
			"state_policy": "derived",
			"summary_prefix": "targets",
		}
	)

static func ai_pressure_summary_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	target: Dictionary,
	state: Dictionary = {}
) -> Dictionary:
	if target.is_empty():
		return {}
	var summary_target := target.duplicate(true)
	if String(summary_target.get("target_public_reason", "")) == "":
		match String(summary_target.get("target_kind", "")):
			"town":
				summary_target["target_public_reason"] = "town siege remains the main front"
				summary_target["target_reason_codes"] = ["town_siege", "objective_front"]
				summary_target["target_public_importance"] = "critical"
			"resource":
				summary_target["target_public_reason"] = "site denial pressure"
				summary_target["target_reason_codes"] = ["persistent_income_denial"]
				summary_target["target_public_importance"] = "high"
	var actor := {
		"placement_id": String(config.get("faction_id", "")),
		"name": String(config.get("label", config.get("faction_id", "Enemy"))),
	}
	return build_ai_event_record(
		session,
		config,
		"ai_pressure_summary",
		actor,
		summary_target,
		{
			"public_importance": String(summary_target.get("target_public_importance", "medium")),
			"state_policy": "derived",
			"summary": "%s pressure centers on %s." % [
				String(config.get("label", config.get("faction_id", "Enemy"))),
				String(summary_target.get("target_label", summary_target.get("target_placement_id", "the frontier"))),
			],
			"debug_reason": String(summary_target.get("target_debug_reason", "")),
		}
	)

static func build_ai_event_record(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	event_type: String,
	actor: Dictionary,
	target: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var faction_id := String(options.get("faction_id", config.get("faction_id", actor.get("spawned_by_faction_id", ""))))
	var faction_label := String(options.get("faction_label", config.get("label", faction_id)))
	var actor_id := String(options.get("actor_id", actor.get("placement_id", actor.get("id", ""))))
	var actor_label := String(options.get("actor_label", _raid_name(actor) if actor.has("encounter_id") else actor.get("name", actor_id)))
	var target_kind := String(options.get("target_kind", target.get("target_kind", "")))
	var target_id := String(options.get("target_id", target.get("target_placement_id", target.get("placement_id", ""))))
	var target_label := String(options.get("target_label", target.get("target_label", target.get("name", target_id))))
	var target_x := int(options.get("target_x", target.get("target_x", target.get("x", 0))))
	var target_y := int(options.get("target_y", target.get("target_y", target.get("y", 0))))
	var reason_codes: Array = _normalize_string_array(options.get("reason_codes", target.get("target_reason_codes", [])))
	if reason_codes.is_empty():
		reason_codes = _default_reason_codes_for_target(target_kind, target_id, target)
	var public_reason := String(options.get("public_reason", target.get("target_public_reason", _public_reason_from_codes(reason_codes))))
	if public_reason == "":
		public_reason = _public_reason_from_codes(reason_codes)
	var debug_reason := String(options.get("debug_reason", target.get("target_debug_reason", public_reason)))
	var importance := String(options.get("public_importance", target.get("target_public_importance", _default_public_importance(target_kind, reason_codes))))
	var visibility := String(options.get("visibility", _event_visibility(session, target_x, target_y, importance)))
	var summary := String(options.get("summary", ""))
	if summary == "":
		summary = _ai_event_summary(event_type, faction_label, actor_label, target_label, public_reason, String(options.get("summary_prefix", "")))
	var event_id := "%d:%s:%s:%s:%s" % [int(session.day), faction_id, event_type, actor_id, target_id]
	return {
		"event_id": event_id,
		"day": int(session.day),
		"sequence": int(options.get("sequence", 0)),
		"event_type": event_type,
		"faction_id": faction_id,
		"faction_label": faction_label,
		"actor_id": actor_id,
		"actor_label": actor_label,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"target_x": target_x,
		"target_y": target_y,
		"visibility": visibility,
		"public_importance": importance,
		"summary": summary,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"debug_reason": debug_reason,
		"state_policy": String(options.get("state_policy", "ephemeral")),
	}

static func resource_target_score_breakdown(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	node: Variant,
	origin_pos: Vector2i,
	faction_id: String = ""
) -> Dictionary:
	if not (node is Dictionary):
		return {}
	var resolved_faction_id := faction_id
	if resolved_faction_id == "":
		resolved_faction_id = String(config.get("faction_id", ""))
	var placement_id := String(node.get("placement_id", ""))
	var site_id := String(node.get("site_id", ""))
	var site := ContentService.get_resource_site(site_id)
	var site_family := String(site.get("family", ""))
	var label := String(site.get("name", "Resource Site"))
	var target_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var goal_distance := _path_distance(session, origin_pos, [target_tile], "")
	var claim_value := _target_resource_value(_resource_site_claim_rewards(site))
	var income_value := _target_resource_value(site.get("control_income", {}))
	var claim_recruit_value := _recruit_payload_value(site.get("claim_recruits", {}))
	var weekly_recruit_value := _recruit_payload_value(site.get("weekly_recruits", {}))
	var recruit_payload_value := claim_recruit_value + weekly_recruit_value
	var persistent := _resource_site_is_persistent(site)
	var player_controlled := String(node.get("collected_by_faction_id", "")) == "player"
	var contestable := placement_id != "" and _resource_node_contestable_by_faction(node, site, resolved_faction_id)

	var base_value := 0
	var persistent_income_value := 0
	var recruit_value := 0
	var scarcity_value := 0
	var denial_value := 0
	var route_pressure_value := 0
	var town_enablement_value := 0
	var objective_value := 0
	var faction_bias := 0
	var travel_cost := 0
	var guard_cost := 0
	var assignment_penalty := 0
	var final_priority := 0
	var debug_reason := "not contestable"

	if contestable and goal_distance < 9999:
		base_value = 85 + int(min(45.0, float(claim_value) / 150.0))
		persistent_income_value = int(min(45.0, float(income_value * 4) / 8.0)) if persistent else 0
		recruit_value = int(min(70.0, float(recruit_payload_value) / 40.0))
		scarcity_value = _resource_scarcity_value(session, _resource_site_claim_rewards(site))
		if player_controlled and persistent:
			denial_value = 45 + int(min(35.0, float(income_value * 4) / 20.0)) + int(min(40.0, float(recruit_payload_value) / 80.0))
		if player_controlled and int(node.get("response_until_day", 0)) >= int(session.day):
			denial_value += 20 + (max(1, int(node.get("response_security_rating", 0))) * 6)
		var delivery_value := _recruit_payload_value(node.get("delivery_manifest", {}))
		if player_controlled and delivery_value > 0:
			denial_value += 28 + int(min(95.0, float(delivery_value) / 10.0))
		route_pressure_value = _resource_route_pressure_value(site)
		town_enablement_value = _linked_player_town_bonus(session, node)
		objective_value = _objective_proximity_bonus(session, target_tile.x, target_tile.y)
		var target_weight := strategy_target_weight(config, resolved_faction_id, "resource", placement_id, site_family, false)
		faction_bias = priority_target_bonus(config, placement_id) + int(round(max(0.0, target_weight - 1.0) * 50.0))
		travel_cost = max(0, goal_distance - 1) * 3
		guard_cost = _resource_guard_cost(site)
		assignment_penalty = _assignment_penalty(session, "resource", placement_id)
		final_priority = max(
			0,
			base_value
			+ persistent_income_value
			+ recruit_value
			+ scarcity_value
			+ denial_value
			+ route_pressure_value
			+ town_enablement_value
			+ objective_value
			+ faction_bias
			- travel_cost
			- guard_cost
			- assignment_penalty
		)
		debug_reason = _resource_target_debug_reason(site, player_controlled, persistent, claim_value, income_value, recruit_payload_value, route_pressure_value, town_enablement_value)
	elif contestable:
		debug_reason = "unreachable from current raid origin"
	var reason_codes := _resource_target_reason_codes(site, player_controlled, persistent, income_value, recruit_payload_value, route_pressure_value, town_enablement_value)
	var public_reason := _public_reason_from_codes(reason_codes)
	var public_importance := _resource_target_public_importance(player_controlled, persistent, reason_codes, final_priority)

	return {
		"target_kind": "resource",
		"placement_id": placement_id,
		"site_id": site_id,
		"site_family": site_family,
		"target_label": label,
		"controller_id": String(node.get("collected_by_faction_id", "")),
		"player_controlled": player_controlled,
		"base_value": base_value,
		"persistent_income_value": persistent_income_value,
		"recruit_value": recruit_value,
		"scarcity_value": scarcity_value,
		"denial_value": denial_value,
		"route_pressure_value": route_pressure_value,
		"town_enablement_value": town_enablement_value,
		"objective_value": objective_value,
		"faction_bias": faction_bias,
		"travel_cost": travel_cost,
		"guard_cost": guard_cost,
		"assignment_penalty": assignment_penalty,
		"final_priority": final_priority,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"public_importance": public_importance,
		"debug_reason": debug_reason,
	}

static func _weighted_priority(
	config: Dictionary,
	faction_id: String,
	target_kind: String,
	placement_id: String,
	base_priority: int,
	site_family: String,
	objective_anchor: bool
) -> int:
	var weighted_priority = int(
		round(
			float(max(0, base_priority))
			* strategy_target_weight(config, faction_id, target_kind, placement_id, site_family, objective_anchor)
		)
	)
	return max(0, weighted_priority + priority_target_bonus(config, placement_id))

static func _commander_memory_priority_bonus(
	session: SessionStateStoreScript.SessionData,
	candidate: Dictionary,
	commander_source: Variant
) -> int:
	var memory := _normalized_commander_memory(commander_source)
	if memory.is_empty():
		return 0
	var target_kind := String(candidate.get("target_kind", ""))
	var target_id := String(candidate.get("target_placement_id", ""))
	var bonus := 0
	if target_kind != "" and target_id != "":
		if (
			target_kind == String(memory.get("focus_target_kind", ""))
			and target_id == String(memory.get("focus_target_id", ""))
		):
			bonus += 70 + (min(3, max(1, int(memory.get("focus_pressure_count", 0)))) * 22)
		if (
			target_kind == String(memory.get("rival_kind", ""))
			and target_id == String(memory.get("rival_id", ""))
		):
			bonus += 140 + (min(4, max(1, int(memory.get("rivalry_count", 0)))) * 40)
	if String(memory.get("front_label", "")) != "" or String(memory.get("focus_target_id", "")) != "":
		var target_x := int(candidate.get("target_x", candidate.get("goal_x", 0)))
		var target_y := int(candidate.get("target_y", candidate.get("goal_y", 0)))
		var front_distance: int = abs(target_x - int(memory.get("front_x", target_x))) + abs(
			target_y - int(memory.get("front_y", target_y))
		)
		if front_distance <= 1:
			bonus += 28
		elif front_distance <= 3:
			bonus += 16
		elif front_distance <= 5:
			bonus += 8
	return bonus

static func _town_strategic_priority_bonus(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	faction_id: String,
	objective_anchor: bool = false
) -> int:
	var bonus = _objective_proximity_bonus(session, int(town.get("x", 0)), int(town.get("y", 0)))
	match OverworldRulesScript.town_strategic_role(town):
		"capital":
			bonus += 80
		"stronghold":
			bonus += 45
	var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, town)
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
	if int(capital_project.get("active", 0)) > 0:
		bonus += 25 + (int(capital_project.get("pressure_bonus", 0)) * 12)
	elif int(capital_project.get("total", 0)) > 0:
		bonus += 15
	bonus += int(logistics.get("support_gap", 0)) * 16
	bonus += int(logistics.get("threatened_count", 0)) * 6
	bonus += int(recovery.get("pressure", 0)) * 10
	if bool(capital_project.get("vulnerable", false)):
		bonus += 30
	var front_state: Dictionary = OverworldRulesScript.town_front_state(session, town)
	if bool(front_state.get("active", false)) and String(front_state.get("faction_id", "")) == faction_id:
		bonus += int(front_state.get("priority_bonus", 0))
	var occupation_state: Dictionary = OverworldRulesScript.town_occupation_state(session, town)
	if bool(occupation_state.get("active", false)) and String(occupation_state.get("faction_id", "")) == faction_id:
		bonus += int(occupation_state.get("target_bonus", 0))
	if objective_anchor:
		bonus += 20
	return max(0, bonus)

static func _town_staging_tiles(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var options = []
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	var town_x = int(town.get("x", 0))
	var town_y = int(town.get("y", 0))
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = town_x + delta.x
		var ny: int = town_y + delta.y
		if nx < 0 or ny < 0 or nx >= map_size.x or ny >= map_size.y:
			continue
		if OverworldRulesScript.tile_is_blocked(session, nx, ny):
			continue
		options.append(Vector2i(nx, ny))
	if options.is_empty():
		options.append(Vector2i(town_x, town_y))
	return options

static func _encounter_staging_tiles(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> Array:
	var options = []
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	var encounter_x = int(encounter.get("x", 0))
	var encounter_y = int(encounter.get("y", 0))
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = encounter_x + delta.x
		var ny: int = encounter_y + delta.y
		if nx < 0 or ny < 0 or nx >= map_size.x or ny >= map_size.y:
			continue
		if OverworldRulesScript.tile_is_blocked(session, nx, ny):
			continue
		options.append(Vector2i(nx, ny))
	if options.is_empty():
		options.append(Vector2i(encounter_x, encounter_y))
	return options

static func _resource_target_priority(session: SessionStateStoreScript.SessionData, node: Variant, faction_id: String) -> int:
	if not (node is Dictionary):
		return 0
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if not _resource_node_contestable_by_faction(node, site, faction_id):
		return 0
	var priority = 85 + int(min(110, _resource_site_strategic_value(site) / 120))
	if _resource_site_is_persistent(site) and String(node.get("collected_by_faction_id", "")) == "player":
		priority += 35
	if String(node.get("collected_by_faction_id", "")) == "player" and int(node.get("response_until_day", 0)) >= session.day:
		priority += 20 + (max(1, int(node.get("response_security_rating", 0))) * 6)
	var delivery_value := _recruit_payload_value(node.get("delivery_manifest", {}))
	if String(node.get("collected_by_faction_id", "")) == "player" and delivery_value > 0:
		priority += 28 + int(min(95, float(delivery_value) / 10.0))
	priority += _linked_player_town_bonus(session, node)
	priority += _objective_proximity_bonus(session, int(node.get("x", 0)), int(node.get("y", 0)))
	return priority

static func _resource_scarcity_value(session: SessionStateStoreScript.SessionData, rewards: Variant) -> int:
	if not (rewards is Dictionary):
		return 0
	var player_resources: Dictionary = session.overworld.get("resources", {})
	var value := 0
	for resource_key in ["wood", "ore"]:
		var amount: int = max(0, int(rewards.get(resource_key, 0)))
		if amount <= 0:
			continue
		var current: int = max(0, int(player_resources.get(resource_key, 0)))
		if current < 4:
			value += amount * 16
		elif current < 7:
			value += amount * 11
		elif current < 10:
			value += amount * 6
	if max(0, int(player_resources.get("gold", 0))) < 1400:
		value += int(min(18.0, float(max(0, int(rewards.get("gold", 0)))) / 90.0))
	return clampi(value, 0, 42)

static func _resource_route_pressure_value(site: Dictionary) -> int:
	var value := 0
	value += max(0, int(site.get("vision_radius", 0))) * 8
	value += max(0, int(site.get("pressure_guard", 0))) * 12
	value += max(0, int(site.get("pressure_bonus", 0))) * 14
	if String(site.get("family", "")) in LOGISTICS_SITE_FAMILIES:
		value += 12
	value += int(min(30.0, float(_resource_site_support_value(site)) / 45.0))
	return value

static func _resource_guard_cost(site: Dictionary) -> int:
	var neutral_roster: Variant = site.get("neutral_roster", {})
	if not (neutral_roster is Dictionary):
		return 0
	if String(neutral_roster.get("guard_encounter_id", "")) == "" and String(neutral_roster.get("guard_army_group_id", "")) == "":
		return 0
	return 12

static func _resource_target_debug_reason(
	site: Dictionary,
	player_controlled: bool,
	persistent: bool,
	claim_value: int,
	income_value: int,
	recruit_payload_value: int,
	route_pressure_value: int,
	town_enablement_value: int
) -> String:
	var parts := []
	if player_controlled and persistent:
		if income_value > 0:
			parts.append("denies %s daily" % _resource_payload_summary(site.get("control_income", {})))
		else:
			parts.append("denies persistent site control")
	if recruit_payload_value > 0:
		parts.append("recruit denial")
	if route_pressure_value > 0:
		if max(0, int(site.get("vision_radius", 0))) > 0:
			parts.append("route vision")
		elif max(0, int(site.get("pressure_guard", 0))) > 0 or max(0, int(site.get("pressure_bonus", 0))) > 0:
			parts.append("route pressure")
	if town_enablement_value > 0:
		parts.append("player-town support")
	if parts.is_empty() and claim_value > 0:
		parts.append("claims %s" % _resource_payload_summary(_resource_site_claim_rewards(site)))
	if parts.is_empty():
		parts.append("frontier denial")
	return ", ".join(parts)

static func _resource_target_reason_codes(
	site: Dictionary,
	player_controlled: bool,
	persistent: bool,
	income_value: int,
	recruit_payload_value: int,
	route_pressure_value: int,
	town_enablement_value: int
) -> Array:
	var codes := []
	if player_controlled and persistent and income_value > 0:
		codes.append("persistent_income_denial")
	if recruit_payload_value > 0:
		codes.append("recruit_denial")
	if route_pressure_value > 0:
		if max(0, int(site.get("vision_radius", 0))) > 0:
			codes.append("route_vision")
		else:
			codes.append("route_pressure")
	if town_enablement_value > 0:
		codes.append("player_town_support")
	if codes.is_empty():
		codes.append("route_pressure")
	return codes

static func _resource_target_public_importance(player_controlled: bool, persistent: bool, reason_codes: Array, final_priority: int) -> String:
	if player_controlled and persistent and ("persistent_income_denial" in reason_codes or "recruit_denial" in reason_codes):
		return "high"
	if final_priority >= 260:
		return "medium"
	return "low"

static func _public_reason_from_codes(reason_codes: Array) -> String:
	var codes := _normalize_string_array(reason_codes)
	if "town_siege" in codes:
		return "town siege remains the main front"
	if "persistent_income_denial" in codes and "recruit_denial" in codes:
		return "recruit and income denial"
	if "persistent_income_denial" in codes and "route_vision" in codes:
		return "income and route vision denial"
	if "persistent_income_denial" in codes:
		return "income denial"
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
	if "commander_memory" in codes:
		return "known commander focus"
	return ""

static func commander_role_turn_snapshot(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	options: Dictionary = {}
) -> Dictionary:
	if session == null:
		return {}
	normalize_all_commander_rosters(session)
	var roster := commander_roster_for_faction(session, faction_id)
	var role_assignments: Array = options.get("role_assignments", [])
	var origin: Dictionary = options.get("origin", {})
	var role_proposals := []
	for assignment_value in role_assignments:
		if not (assignment_value is Dictionary):
			continue
		var assignment: Dictionary = assignment_value
		var roster_hero_id := String(assignment.get("roster_hero_id", ""))
		var target_id := String(assignment.get("target_id", ""))
		var commander_entry := _commander_roster_entry(roster, roster_hero_id)
		if commander_entry.is_empty():
			continue
		var target_view := commander_role_resource_target_view(session, config, faction_id, target_id, origin)
		var proposal := commander_role_proposal_for_resource_target(
			session,
			config,
			faction_id,
			commander_entry,
			target_view,
			assignment.get("fixture_state", {})
		)
		role_proposals.append(_turn_transcript_role_proposal(session, faction_id, commander_entry, target_view, proposal))
	return {
		"schema_status": "derived_turn_transcript_report_only",
		"source_policy": "snapshot_derived",
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"faction_id": faction_id,
		"faction_label": String(config.get("label", faction_id)),
		"enemy_state": _turn_transcript_enemy_state_counts(session, faction_id),
		"active_raids": _turn_transcript_active_raid_snapshots(session, faction_id),
		"commander_links": _turn_transcript_commander_links(session, faction_id),
		"resource_controllers": _turn_transcript_resource_controller_map(session),
		"derived_role_proposals": role_proposals,
		"town_governor_supporting_event_refs": _turn_transcript_town_governor_refs(
			options.get("town_governor_reports", []),
			String(options.get("supporting_front_id", ""))
		),
		"battle_pending": not session.battle.is_empty(),
	}

static func commander_role_turn_transcript_report(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	config: Dictionary,
	turn_result: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var faction_id := String(after_snapshot.get("faction_id", before_snapshot.get("faction_id", config.get("faction_id", ""))))
	var scenario_id := String(after_snapshot.get("scenario_id", before_snapshot.get("scenario_id", "")))
	var case_id := String(options.get("case_id", "%s_%s_turn" % [scenario_id, faction_id]))
	var before_proposals := _turn_transcript_timed_proposals(before_snapshot.get("derived_role_proposals", []), "before_turn")
	var after_proposals := _turn_transcript_timed_proposals(after_snapshot.get("derived_role_proposals", []), "after_turn")
	var assignment_records := _turn_transcript_target_assignment_records(before_snapshot, after_snapshot)
	var no_op_records := _turn_transcript_target_no_op_records(before_snapshot, before_proposals, assignment_records)
	var movement_summary := _turn_transcript_raid_movement_summary(before_snapshot, after_snapshot)
	var arrival_summary := _turn_transcript_raid_arrival_summary(before_snapshot, after_snapshot)
	var town_refs := _turn_transcript_merge_town_refs(
		before_snapshot.get("town_governor_supporting_event_refs", []),
		after_snapshot.get("town_governor_supporting_event_refs", [])
	)
	var phase_records := _turn_transcript_phase_records(
		before_snapshot,
		after_snapshot,
		assignment_records,
		movement_summary,
		arrival_summary,
		town_refs
	)
	var public_events := _turn_transcript_public_events(
		before_snapshot,
		after_snapshot,
		before_proposals,
		assignment_records,
		movement_summary,
		arrival_summary,
		town_refs,
		phase_records
	)
	var leak_check := commander_role_public_leak_check(public_events)
	var source_marker_check := _turn_transcript_source_marker_check(
		[
			phase_records,
			before_snapshot.get("commander_links", []),
			after_snapshot.get("commander_links", []),
			before_proposals,
			after_proposals,
			assignment_records,
			no_op_records,
			movement_summary,
			arrival_summary,
			town_refs,
			public_events,
		]
	)
	var pass_criteria := [
		"Existing EnemyTurnRules.run_enemy_turn executed once for this fixture.",
		"Before/after commander links and role proposals are snapshot-derived only.",
		"Relevant commanders have either a target assignment record or a recognized no-op reason.",
		"Public transcript events pass compact leak checks.",
	]
	var ok := bool(turn_result.get("ok", false)) and bool(leak_check.get("ok", false)) and bool(source_marker_check.get("ok", false)) and _turn_transcript_no_ops_valid(no_op_records)
	return {
		"case_id": case_id,
		"scenario_id": scenario_id,
		"faction_id": faction_id,
		"day_before": int(before_snapshot.get("day", 0)),
		"day_after": int(after_snapshot.get("day", 0)),
		"fixture_setup": options.get("fixture_setup", {}),
		"turn_result": {
			"ok": bool(turn_result.get("ok", false)),
			"message_summary": String(turn_result.get("message", "")),
		},
		"phase_records": phase_records,
		"active_commander_links": {
			"before": before_snapshot.get("commander_links", []),
			"after": after_snapshot.get("commander_links", []),
		},
		"derived_role_proposals": {
			"before_turn": before_proposals,
			"after_turn": after_proposals,
		},
		"target_assignment_records": assignment_records,
		"target_no_op_records": no_op_records,
		"raid_movement_summary": movement_summary,
		"raid_arrival_summary": arrival_summary,
		"town_governor_supporting_event_refs": town_refs,
		"public_transcript_events": public_events,
		"public_leak_check": leak_check,
		"source_marker_check": source_marker_check,
		"case_pass_criteria": pass_criteria,
		"ok": ok,
	}

static func commander_role_turn_transcript_public_leak_check(public_surfaces: Variant) -> Dictionary:
	return commander_role_public_leak_check(public_surfaces)

static func ai_hero_task_candidate_from_role(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	commander_entry: Dictionary,
	role_record: Dictionary,
	local_sequence: int,
	options: Dictionary = {}
) -> Dictionary:
	var actor_id := String(role_record.get("roster_hero_id", commander_entry.get("roster_hero_id", "")))
	var actor_label := String(role_record.get("commander_label", commander_display_name(commander_entry, false)))
	if actor_label == "":
		actor_label = actor_id
	var source_role := String(role_record.get("role", COMMANDER_ROLE_RESERVE))
	var role_status := String(role_record.get("role_status", ""))
	var target_kind := String(role_record.get("target_kind", ""))
	var target_id := String(role_record.get("target_id", ""))
	var task_class := String(options.get("task_class", _ai_hero_task_class_for_role(source_role, target_kind, role_status)))
	if task_class in ["recover_commander", "rebuild_host", "reserve"]:
		target_kind = "commander"
		target_id = actor_id
	var assigned_day := int(options.get("assigned_day", int(session.day) if session != null else 0))
	var task_id := ai_hero_task_candidate_id(
		String(session.scenario_id) if session != null else "",
		faction_id,
		actor_id,
		task_class,
		target_kind,
		target_id,
		assigned_day,
		local_sequence
	)
	var source_id := String(role_record.get("assignment_id_hint", ""))
	if source_id == "":
		source_id = _ai_hero_task_source_id(
			String(session.scenario_id) if session != null else "",
			faction_id,
			actor_id,
			source_role,
			target_kind,
			target_id,
			assigned_day
		)
	var controller_before := String(role_record.get("target_controller_before", ""))
	var target_label := String(role_record.get("target_label", target_id))
	var target_x := int(role_record.get("target_x", 0))
	var target_y := int(role_record.get("target_y", 0))
	if target_kind == "resource":
		var target_view := ai_hero_task_resource_target_snapshot(session, target_id)
		if not target_view.is_empty():
			if controller_before == "":
				controller_before = String(target_view.get("controller_id", ""))
			target_label = String(target_view.get("target_label", target_label))
			target_x = int(target_view.get("x", target_x))
			target_y = int(target_view.get("y", target_y))
	var validation := "valid"
	var task_status := String(options.get("task_status", "candidate"))
	if task_class == "recover_commander":
		task_status = "blocked"
		validation = "invalid_actor_recovering"
	elif task_class == "rebuild_host":
		task_status = "blocked"
		validation = "invalid_actor_rebuilding"
	elif target_kind == "resource" and ai_hero_task_resource_target_snapshot(session, target_id).is_empty():
		task_status = "invalid"
		validation = "invalid_target_missing"
	validation = String(options.get("last_validation", validation))
	var reservation := _ai_hero_task_default_reservation(task_class, target_kind, target_id)
	var active_link := commander_role_active_encounter_link(session, faction_id, actor_id)
	return {
		"task_id": task_id,
		"task_status": task_status,
		"owner_faction_id": faction_id,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"actor_label": actor_label,
		"actor_active_linked": bool(active_link.get("linked", false)),
		"active_placement_id": String(active_link.get("placement_id", "")),
		"source_kind": AI_HERO_TASK_SOURCE_KIND,
		"source_id": source_id,
		"source_role": source_role,
		"source_timing": String(role_record.get("timing", options.get("source_timing", "before_turn"))),
		"source_policy": String(role_record.get("state_policy", "report_only")),
		"task_class": task_class,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label,
		"target_x": target_x,
		"target_y": target_y,
		"target_controller_before": controller_before,
		"target_controller_after": String(options.get("target_controller_after", controller_before)),
		"target_owner_expected": String(options.get("target_owner_expected", _ai_hero_task_target_owner_expected(task_class, controller_before, faction_id))),
		"front_id": String(role_record.get("front_id", commander_role_front_id(String(session.scenario_id) if session != null else "", target_kind, target_id))),
		"origin_kind": "town",
		"origin_id": String(options.get("origin_id", commander_role_origin_id(String(session.scenario_id) if session != null else "", faction_id))),
		"priority_reason_codes": _normalize_string_array(role_record.get("priority_reason_codes", [])),
		"assigned_day": assigned_day,
		"expires_day": assigned_day + 3,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"reservation": reservation,
		"claim_status": String(options.get("claim_status", "")),
		"last_validation": validation,
		"state_policy": AI_HERO_TASK_STATE_POLICY,
	}

static func ai_hero_task_candidate_id(
	scenario_id: String,
	faction_id: String,
	actor_id: String,
	task_class: String,
	target_kind: String,
	target_id: String,
	assigned_day: int,
	local_sequence: int
) -> String:
	return "task:%s:%s:%s:%s:%s:%s:day_%d:seq_%d" % [
		scenario_id,
		faction_id,
		actor_id,
		task_class,
		target_kind,
		target_id,
		assigned_day,
		max(1, local_sequence),
	]

static func ai_hero_task_resource_target_snapshot(
	session: SessionStateStoreScript.SessionData,
	target_id: String
) -> Dictionary:
	if session == null or target_id == "":
		return {}
	var node_result := _find_resource_by_placement(session, target_id)
	var node: Dictionary = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0:
		return {}
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	return {
		"target_kind": "resource",
		"target_id": target_id,
		"target_label": String(site.get("name", target_id)),
		"controller_id": String(node.get("collected_by_faction_id", "")),
		"site_id": String(node.get("site_id", "")),
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"state_policy": "derived",
	}

static func ai_hero_task_apply_reservations(tasks_value: Variant) -> Array:
	var tasks: Array = tasks_value.duplicate(true) if tasks_value is Array else []
	var exclusive_by_key := {}
	for index in range(tasks.size()):
		if not (tasks[index] is Dictionary):
			continue
		var task: Dictionary = tasks[index]
		var reservation: Dictionary = task.get("reservation", {})
		if String(reservation.get("reservation_scope", "")) != "exclusive_target":
			continue
		var key := String(reservation.get("reservation_key", ""))
		if key == "":
			continue
		if not exclusive_by_key.has(key):
			exclusive_by_key[key] = []
		exclusive_by_key[key].append(index)
	for key in exclusive_by_key.keys():
		var indexes: Array = exclusive_by_key[key]
		if indexes.size() <= 1:
			continue
		indexes.sort_custom(func(a: int, b: int) -> bool:
			return _ai_hero_task_reservation_sort_key(tasks[a]) < _ai_hero_task_reservation_sort_key(tasks[b])
		)
		var primary_index := int(indexes[0])
		var primary_task: Dictionary = tasks[primary_index]
		var primary_reservation: Dictionary = primary_task.get("reservation", {})
		primary_reservation["reservation_status"] = "primary"
		primary_task["reservation"] = primary_reservation
		if String(primary_task.get("last_validation", "")) == "invalid_target_reserved":
			primary_task["last_validation"] = "valid"
			primary_task["task_status"] = "candidate"
		tasks[primary_index] = primary_task
		for loser_position in range(1, indexes.size()):
			var loser_index := int(indexes[loser_position])
			var loser: Dictionary = tasks[loser_index]
			var loser_reservation: Dictionary = loser.get("reservation", {})
			loser_reservation["reservation_status"] = "rejected_duplicate"
			loser_reservation["reservation_scope"] = "exclusive_target"
			loser["reservation"] = loser_reservation
			loser["task_status"] = "invalid"
			loser["last_validation"] = "invalid_target_reserved"
			loser["invalidated_by_task_id"] = String(primary_task.get("task_id", ""))
			tasks[loser_index] = loser
	return tasks

static func ai_hero_task_transition_from_arrival(retake_task: Dictionary, arrival: Dictionary) -> Dictionary:
	var task_target := "%s:%s" % [String(retake_task.get("target_kind", "")), String(retake_task.get("target_id", ""))]
	var arrival_target := "%s:%s" % [String(arrival.get("target_kind", "")), String(arrival.get("target_id", ""))]
	var owner_faction_id := String(retake_task.get("owner_faction_id", ""))
	var controller_after := String(arrival.get("target_controller_after", ""))
	var completed := (
		String(retake_task.get("task_class", "")) == "retake_site"
		and task_target == arrival_target
		and owner_faction_id != ""
		and controller_after == owner_faction_id
	)
	var reservation: Dictionary = retake_task.get("reservation", {})
	return {
		"task_id": String(retake_task.get("task_id", "")),
		"target_kind": String(retake_task.get("target_kind", "")),
		"target_id": String(retake_task.get("target_id", "")),
		"arrival_placement_id": String(arrival.get("placement_id", "")),
		"target_controller_before": String(arrival.get("target_controller_before", "")),
		"target_controller_after": controller_after,
		"transition_result": "completed_by_controller_flip" if completed else "no_completion",
		"retake_open_after_arrival": not completed,
		"released_reservation_key": String(reservation.get("reservation_key", "")) if completed else "",
		"last_validation_after_arrival": "invalid_controller_changed" if completed else String(retake_task.get("last_validation", "")),
		"state_policy": "derived",
	}

static func ai_hero_task_old_save_absence_check(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var saved_present := false
	var saved_count := 0
	if session != null:
		for state_value in session.overworld.get("enemy_states", []):
			if not (state_value is Dictionary):
				continue
			var state: Dictionary = state_value
			if not state.has("hero_task_state"):
				continue
			saved_present = true
			var task_state = state.get("hero_task_state", {})
			if task_state is Dictionary:
				var tasks = task_state.get("tasks", [])
				if tasks is Array:
					saved_count += tasks.size()
	var save_version := int(SessionStateStoreScript.SAVE_VERSION)
	return {
		"ok": not saved_present and saved_count == 0,
		"saved_task_board_present": saved_present,
		"saved_task_count": saved_count,
		"derived_candidate_tasks_allowed": true,
		"save_version_before": save_version,
		"save_version_after": save_version,
		"normalization_policy": "missing_hero_task_state_means_no_saved_tasks",
		"write_check": "no_hero_task_state_write",
		"state_policy": "derived",
	}

static func ai_hero_task_public_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	candidate_task: Dictionary,
	sequence: int,
	event_type: String = "ai_hero_task_candidate"
) -> Dictionary:
	var reason_codes := _normalize_string_array(candidate_task.get("priority_reason_codes", []))
	var public_reason := _public_reason_from_codes(reason_codes)
	if public_reason == "" and String(candidate_task.get("task_class", "")) == "recover_commander":
		public_reason = "commander recovering"
	elif public_reason == "" and String(candidate_task.get("task_class", "")) == "rebuild_host":
		public_reason = "commander rebuilding"
	var actor_label := String(candidate_task.get("actor_label", candidate_task.get("actor_id", "")))
	var target_label := String(candidate_task.get("target_label", candidate_task.get("target_id", "")))
	var summary := "%s has %s intent for %s" % [
		actor_label,
		String(candidate_task.get("task_class", "front")),
		target_label,
	]
	if public_reason != "":
		summary += " (%s)" % public_reason
	summary += "."
	var day := int(candidate_task.get("assigned_day", int(session.day) if session != null else 0))
	var faction_id := String(candidate_task.get("owner_faction_id", config.get("faction_id", "")))
	var actor_id := String(candidate_task.get("actor_id", ""))
	var target_id := String(candidate_task.get("target_id", ""))
	return {
		"event_id": "%d:%s:%s:%s:%s:%d" % [day, faction_id, event_type, actor_id, target_id, sequence],
		"day": day,
		"sequence": sequence,
		"event_type": event_type,
		"faction_id": faction_id,
		"faction_label": String(config.get("label", faction_id)),
		"actor_id": actor_id,
		"actor_label": actor_label,
		"task_class": String(candidate_task.get("task_class", "")),
		"target_kind": String(candidate_task.get("target_kind", "")),
		"target_id": target_id,
		"target_label": target_label,
		"front_id": String(candidate_task.get("front_id", "")),
		"visibility": "hidden_debug",
		"public_importance": _ai_hero_task_public_importance(candidate_task),
		"summary": summary,
		"reason_codes": reason_codes,
		"public_reason": public_reason,
		"state_policy": AI_HERO_TASK_STATE_POLICY,
	}

static func ai_hero_task_public_leak_check(public_surfaces: Variant) -> Dictionary:
	var stack := [public_surfaces]
	var checked_events := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if not (value is Dictionary):
			var value_text := String(value)
			for token in AI_HERO_TASK_BLOCKED_PUBLIC_TOKENS:
				if value_text.contains(String(token)):
					return {"ok": false, "error": "public task surface leaked token %s" % String(token)}
			continue
		if String(value.get("event_type", "")) != "":
			checked_events += 1
			for key in value.keys():
				if String(key) not in AI_HERO_TASK_PUBLIC_EVENT_KEYS:
					return {"ok": false, "error": "%s leaked non-compact key %s" % [value.get("event_type", "event"), key]}
		var text := JSON.stringify(value)
		for token in AI_HERO_TASK_BLOCKED_PUBLIC_TOKENS:
			if text.contains(String(token)):
				return {"ok": false, "error": "%s leaked blocked token %s" % [value.get("event_type", "event"), token]}
		for nested_key in value.keys():
			var nested = value[nested_key]
			if nested is Array or nested is Dictionary:
				stack.append(nested)
	return {
		"ok": true,
		"checked_events": checked_events,
		"allowed_public_event_keys": AI_HERO_TASK_PUBLIC_EVENT_KEYS,
		"blocked_public_tokens": AI_HERO_TASK_BLOCKED_PUBLIC_TOKENS,
	}

static func ai_hero_task_candidate_task_id_check(tasks: Array) -> Dictionary:
	var ids := {}
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			return {"ok": false, "error": "candidate task record is not a dictionary"}
		var task: Dictionary = task_value
		var task_id := String(task.get("task_id", ""))
		var source_id := String(task.get("source_id", ""))
		var parts := task_id.split(":")
		if parts.size() != 9 or parts[0] != "task":
			return {"ok": false, "error": "invalid candidate task id format %s" % task_id}
		if not String(parts[7]).begins_with("day_") or not String(parts[8]).begins_with("seq_"):
			return {"ok": false, "error": "candidate task id missing day/sequence %s" % task_id}
		if task_id.contains(" ") or task_id.contains("/") or task_id.contains("\\"):
			return {"ok": false, "error": "candidate task id contains display/path text %s" % task_id}
		if ids.has(task_id):
			return {"ok": false, "error": "duplicate candidate task id %s" % task_id}
		if source_id == "" or source_id == task_id:
			return {"ok": false, "error": "candidate task %s has invalid source id %s" % [task_id, source_id]}
		ids[task_id] = true
		checked += 1
	return {"ok": true, "checked_tasks": checked, "task_ids": ids.keys()}

static func ai_hero_task_actor_ownership_check(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	tasks: Array
) -> Dictionary:
	var roster := commander_roster_for_faction(session, faction_id)
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("owner_faction_id", "")) != faction_id:
			return {"ok": false, "error": "task owner mismatch for %s" % String(task.get("task_id", ""))}
		if String(task.get("actor_kind", "")) != "commander_roster":
			return {"ok": false, "error": "unsupported task actor kind %s" % String(task.get("actor_kind", ""))}
		var actor_id := String(task.get("actor_id", ""))
		if _commander_roster_entry(roster, actor_id).is_empty():
			return {"ok": false, "error": "task actor %s missing from %s roster" % [actor_id, faction_id]}
		checked += 1
	return {"ok": true, "checked_tasks": checked, "actor_kind": "commander_roster"}

static func ai_hero_task_target_ownership_check(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	tasks: Array
) -> Dictionary:
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		var target_kind := String(task.get("target_kind", ""))
		var task_class := String(task.get("task_class", ""))
		if target_kind == "resource":
			var target_snapshot := ai_hero_task_resource_target_snapshot(session, String(task.get("target_id", "")))
			if target_snapshot.is_empty():
				return {"ok": false, "error": "task target missing %s" % String(task.get("target_id", ""))}
			var before_controller := String(task.get("target_controller_before", ""))
			if task_class == "retake_site" and before_controller == faction_id:
				return {"ok": false, "error": "retake task target already controlled by owner %s" % String(task.get("target_id", ""))}
			if task_class in ["defend_front", "stabilize_front"] and before_controller != faction_id:
				return {"ok": false, "error": "%s target not owner-held %s" % [task_class, String(task.get("target_id", ""))]}
		elif target_kind == "commander":
			if String(task.get("target_id", "")) != String(task.get("actor_id", "")):
				return {"ok": false, "error": "commander task target must be its actor"}
		else:
			return {"ok": false, "error": "unsupported task target kind %s" % target_kind}
		checked += 1
	return {"ok": true, "checked_tasks": checked}

static func ai_hero_task_role_to_task_source_check(tasks: Array) -> Dictionary:
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("source_kind", "")) != AI_HERO_TASK_SOURCE_KIND:
			return {"ok": false, "error": "task source kind is not commander role adapter"}
		if String(task.get("state_policy", "")) != AI_HERO_TASK_STATE_POLICY:
			return {"ok": false, "error": "task state policy is not report-only"}
		if _ai_hero_task_class_for_role(String(task.get("source_role", "")), String(task.get("target_kind", "")), _ai_hero_task_role_status_from_task_class(String(task.get("task_class", "")))) != String(task.get("task_class", "")):
			return {"ok": false, "error": "source role %s did not map to task class %s" % [task.get("source_role", ""), task.get("task_class", "")]}
		if String(task.get("source_id", "")) == "" or String(task.get("source_id", "")) == String(task.get("task_id", "")):
			return {"ok": false, "error": "task source id is missing or reused"}
		checked += 1
	return {"ok": true, "checked_tasks": checked, "source_kind": AI_HERO_TASK_SOURCE_KIND}

static func ai_hero_task_target_reservation_check(tasks: Array) -> Dictionary:
	var primary_by_key := {}
	var checked := 0
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		var task_class := String(task.get("task_class", ""))
		var reservation: Dictionary = task.get("reservation", {})
		var scope := String(reservation.get("reservation_scope", ""))
		var status := String(reservation.get("reservation_status", ""))
		var key := String(reservation.get("reservation_key", ""))
		if task_class in AI_HERO_TASK_EXCLUSIVE_CLASSES:
			if String(task.get("task_status", "")) == "completed" and status == "released":
				checked += 1
				continue
			if scope != "exclusive_target" or key == "":
				return {"ok": false, "error": "%s task missing exclusive reservation" % task_class}
			if status == "primary":
				if primary_by_key.has(key):
					return {"ok": false, "error": "duplicate primary reservation for %s" % key}
				primary_by_key[key] = String(task.get("task_id", ""))
		elif task_class == "stabilize_front":
			if scope not in ["shared_front", "none"]:
				return {"ok": false, "error": "stabilizer used invalid reservation scope %s" % scope}
		elif task_class in ["recover_commander", "rebuild_host"]:
			if scope != "none":
				return {"ok": false, "error": "%s must not reserve map targets" % task_class}
		checked += 1
	return {
		"ok": true,
		"checked_tasks": checked,
		"primary_reservation_count": primary_by_key.keys().size(),
		"primary_reservations": primary_by_key,
	}

static func ai_hero_task_invalidation_check(tasks: Array, transitions: Array = []) -> Dictionary:
	var checked := 0
	var codes := {}
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		var validation := String(task.get("last_validation", ""))
		if validation == "":
			return {"ok": false, "error": "task missing validation %s" % String(task.get("task_id", ""))}
		codes[validation] = int(codes.get(validation, 0)) + 1
		if validation == "invalid_target_reserved" and String(task.get("invalidated_by_task_id", "")) == "":
			return {"ok": false, "error": "duplicate-reserved task missing invalidating task id"}
		if String(task.get("task_class", "")) in ["recover_commander", "rebuild_host"] and String(task.get("reservation", {}).get("reservation_scope", "")) != "none":
			return {"ok": false, "error": "blocked commander task reserved a map target"}
		checked += 1
	for transition_value in transitions:
		if not (transition_value is Dictionary):
			continue
		var transition: Dictionary = transition_value
		if String(transition.get("transition_result", "")) == "completed_by_controller_flip":
			if bool(transition.get("retake_open_after_arrival", true)):
				return {"ok": false, "error": "completed controller flip still leaves retake open"}
			if String(transition.get("last_validation_after_arrival", "")) != "invalid_controller_changed":
				return {"ok": false, "error": "controller flip transition missing invalid_controller_changed"}
			codes["invalid_controller_changed"] = int(codes.get("invalid_controller_changed", 0)) + 1
	return {"ok": true, "checked_tasks": checked, "validation_codes": codes}

static func _ai_hero_task_class_for_role(role: String, target_kind: String, role_status: String = "") -> String:
	if role == COMMANDER_ROLE_RAIDER and target_kind == "town":
		return "raid_town"
	if role == COMMANDER_ROLE_RAIDER:
		return "contest_site"
	if role == COMMANDER_ROLE_RETAKER:
		return "retake_site"
	if role == COMMANDER_ROLE_DEFENDER:
		return "defend_front"
	if role == COMMANDER_ROLE_STABILIZER:
		return "stabilize_front"
	if role == COMMANDER_ROLE_RECOVERING and role_status == "cooldown":
		return "recover_commander"
	if role == COMMANDER_ROLE_RECOVERING and role_status == "rebuilding":
		return "rebuild_host"
	return "reserve"

static func _ai_hero_task_role_status_from_task_class(task_class: String) -> String:
	if task_class == "recover_commander":
		return "cooldown"
	if task_class == "rebuild_host":
		return "rebuilding"
	return "assigned"

static func _ai_hero_task_source_id(
	scenario_id: String,
	faction_id: String,
	actor_id: String,
	role: String,
	target_kind: String,
	target_id: String,
	assigned_day: int
) -> String:
	if scenario_id == "" or faction_id == "" or actor_id == "" or role == "" or target_kind == "" or target_id == "":
		return ""
	return "role:%s:%s:%s:%s:%s:%s:day_%d" % [
		scenario_id,
		faction_id,
		actor_id,
		role,
		target_kind,
		target_id,
		assigned_day,
	]

static func _ai_hero_task_default_reservation(task_class: String, target_kind: String, target_id: String) -> Dictionary:
	if task_class in AI_HERO_TASK_EXCLUSIVE_CLASSES:
		return {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "%s:%s" % [target_kind, target_id],
		}
	if task_class == "stabilize_front":
		return {
			"reservation_status": "shared",
			"reservation_scope": "shared_front",
			"reservation_key": "",
		}
	return {
		"reservation_status": "none",
		"reservation_scope": "none",
		"reservation_key": "",
	}

static func _ai_hero_task_target_owner_expected(task_class: String, controller_id: String, faction_id: String) -> String:
	if task_class in ["retake_site", "contest_site"] and controller_id == "player":
		return "player-held contested resource"
	if task_class in ["defend_front", "stabilize_front"] and controller_id == faction_id:
		return "owner-held front"
	if task_class in ["recover_commander", "rebuild_host"]:
		return "own commander"
	return "contested target"

static func _ai_hero_task_reservation_sort_key(task: Dictionary) -> String:
	var active_rank := "0" if bool(task.get("actor_active_linked", false)) else "1"
	var class_rank_map := {
		"retake_site": 0,
		"defend_front": 1,
		"contest_site": 2,
		"stabilize_front": 3,
		"raid_town": 4,
		"reserve": 5,
		"recover_commander": 6,
		"rebuild_host": 7,
	}
	var class_rank := int(class_rank_map.get(String(task.get("task_class", "")), 99))
	return "%s:%02d:%s:%s" % [
		active_rank,
		class_rank,
		String(task.get("actor_id", "")),
		String(task.get("task_id", "")),
	]

static func _ai_hero_task_public_importance(task: Dictionary) -> String:
	var task_class := String(task.get("task_class", ""))
	if task_class in ["retake_site", "defend_front", "raid_town"]:
		return "high"
	if task_class in ["contest_site", "stabilize_front"]:
		return "medium"
	return "low"

static func _turn_transcript_role_proposal(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	commander_entry: Dictionary,
	target_view: Dictionary,
	proposal: Dictionary
) -> Dictionary:
	var target_kind := String(target_view.get("target_kind", ""))
	var target_id := String(target_view.get("target_id", ""))
	return {
		"timing": "",
		"roster_hero_id": String(commander_entry.get("roster_hero_id", "")),
		"commander_label": commander_display_name(commander_entry, false),
		"role": String(proposal.get("role", COMMANDER_ROLE_RESERVE)),
		"role_status": String(proposal.get("role_status", "")),
		"validity": String(proposal.get("validity", "")),
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": String(target_view.get("target_label", target_id)),
		"target_x": int(target_view.get("target_x", 0)),
		"target_y": int(target_view.get("target_y", 0)),
		"front_id": String(target_view.get("front_id", commander_role_front_id(String(session.scenario_id), target_kind, target_id))),
		"priority_reason_codes": _normalize_string_array(proposal.get("priority_reason_codes", [])),
		"public_reason": String(proposal.get("public_reason", "")),
		"assignment_id_hint": String(proposal.get("assignment_id_hint", "")),
		"expected_next_transition": String(proposal.get("expected_next_transition", "")),
		"state_policy": "report_only",
	}

static func _turn_transcript_enemy_state_counts(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	var state := {}
	for state_value in session.overworld.get("enemy_states", []):
		if state_value is Dictionary and String(state_value.get("faction_id", "")) == faction_id:
			state = state_value
			break
	var roster: Array = state.get("commander_roster", [])
	var commander_counts := {"available": 0, "active": 0, "recovering": 0, "rebuilding": 0}
	for entry_value in roster:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var status := _normalize_commander_status(entry.get("status", COMMANDER_STATUS_AVAILABLE))
		if commander_can_deploy(entry):
			commander_counts[status] = int(commander_counts.get(status, 0)) + 1
		else:
			commander_counts["rebuilding"] = int(commander_counts.get("rebuilding", 0)) + 1
	return {
		"pressure": int(state.get("pressure", 0)),
		"raid_counter": int(state.get("raid_counter", 0)),
		"commander_counter": int(state.get("commander_counter", 0)),
		"siege_progress": int(state.get("siege_progress", 0)),
		"posture": String(state.get("posture", "")),
		"active_raid_count": _turn_transcript_active_raid_snapshots(session, faction_id).size(),
		"commander_counts": commander_counts,
		"state_policy": "derived",
	}

static func _turn_transcript_active_raid_snapshots(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> Array:
	var snapshots := []
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter_value in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter_value, faction_id, resolved_encounters):
			continue
		var encounter: Dictionary = encounter_value
		var commander_state = encounter.get("enemy_commander_state", {})
		if not (commander_state is Dictionary):
			commander_state = {}
		var current := Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
		var goal_tiles := _goal_tiles_from_raid(session, encounter)
		var goal_distance := int(encounter.get("goal_distance", 9999))
		if not goal_tiles.is_empty():
			goal_distance = _path_distance(session, current, goal_tiles, String(encounter.get("placement_id", "")))
			if goal_distance == 9999 and current in goal_tiles:
				goal_distance = 0
		var target := _current_target_snapshot(encounter)
		snapshots.append(
			{
				"placement_id": String(encounter.get("placement_id", "")),
				"encounter_id": String(encounter.get("encounter_id", encounter.get("id", ""))),
				"raid_label": raid_display_name(encounter),
				"roster_hero_id": String(commander_state.get("roster_hero_id", "")),
				"commander_label": commander_display_name(commander_state, false),
				"x": current.x,
				"y": current.y,
				"arrived": bool(encounter.get("arrived", false)),
				"goal_distance": goal_distance,
				"target_kind": String(target.get("target_kind", "")),
				"target_id": String(target.get("target_placement_id", "")),
				"target_label": String(target.get("target_label", "")),
				"target_x": int(target.get("target_x", 0)),
				"target_y": int(target.get("target_y", 0)),
				"target_signature": _target_signature(target),
				"reason_codes": _normalize_string_array(encounter.get("target_reason_codes", [])),
				"public_reason": String(encounter.get("target_public_reason", "")),
				"public_importance": String(encounter.get("target_public_importance", "medium")),
				"state_policy": "derived",
			}
		)
	return snapshots

static func _turn_transcript_commander_links(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> Array:
	var links := []
	var roster := commander_roster_for_faction(session, faction_id)
	for commander_entry_value in roster:
		if not (commander_entry_value is Dictionary):
			continue
		var commander_entry: Dictionary = commander_entry_value
		var roster_hero_id := String(commander_entry.get("roster_hero_id", ""))
		var active_link := commander_role_active_encounter_link(session, faction_id, roster_hero_id)
		var linked := bool(active_link.get("linked", false))
		var status := _normalize_commander_status(commander_entry.get("status", COMMANDER_STATUS_AVAILABLE))
		var no_link_reason := ""
		if not linked:
			if status == COMMANDER_STATUS_RECOVERING:
				no_link_reason = "recovering"
			elif not commander_can_deploy(commander_entry):
				no_link_reason = "rebuilding"
			else:
				no_link_reason = "reserve"
		links.append(
			{
				"roster_hero_id": roster_hero_id,
				"commander_label": commander_display_name(commander_entry, false),
				"status": status,
				"active_placement_id": String(active_link.get("placement_id", "")),
				"linked": linked,
				"no_link_reason": no_link_reason,
				"target_kind": String(active_link.get("target_kind", "")),
				"target_id": String(active_link.get("target_id", "")),
				"target_label": String(active_link.get("target_label", "")),
				"army_status": commander_army_status(commander_entry),
				"memory_summary": commander_memory_summary(commander_entry),
				"state_policy": "derived",
			}
		)
	return links

static func _turn_transcript_resource_controller_map(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var controllers := {}
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var placement_id := String(node.get("placement_id", ""))
		if placement_id == "":
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		controllers[placement_id] = {
			"controller_id": String(node.get("collected_by_faction_id", "")),
			"target_label": String(site.get("name", placement_id)),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"state_policy": "derived",
		}
	return controllers

static func _turn_transcript_town_governor_refs(reports_value: Variant, fallback_front_id: String = "") -> Array:
	var reports: Array = reports_value if reports_value is Array else [reports_value]
	var refs := []
	var allowed_types := [
		"ai_town_built",
		"ai_town_recruited",
		"ai_garrison_reinforced",
		"ai_raid_reinforced",
		"ai_commander_rebuilt",
	]
	for report_value in reports:
		if not (report_value is Dictionary):
			continue
		for town_value in report_value.get("towns", []):
			if not (town_value is Dictionary):
				continue
			var town: Dictionary = town_value
			for event_value in town.get("events", []):
				if not (event_value is Dictionary):
					continue
				var event: Dictionary = event_value
				var event_type := String(event.get("event_type", ""))
				if event_type not in allowed_types:
					continue
				var target_kind := String(event.get("target_kind", ""))
				var target_id := String(event.get("target_id", ""))
				var front_id := commander_role_front_id(String(report_value.get("scenario_id", "")), target_kind, target_id)
				if front_id == "":
					front_id = fallback_front_id
				refs.append(
					{
						"event_ref_id": String(event.get("event_id", "")),
						"event_type": event_type,
						"town_placement_id": String(town.get("placement_id", event.get("actor_id", ""))),
						"target_kind": target_kind,
						"target_id": target_id,
						"target_label": String(event.get("target_label", target_id)),
						"public_reason": String(event.get("public_reason", "")),
						"reason_codes": _normalize_string_array(event.get("reason_codes", [])),
						"supports_front_id": front_id,
						"state_policy": "derived",
					}
				)
	return refs

static func _turn_transcript_timed_proposals(proposals_value: Variant, timing: String) -> Array:
	var timed := []
	if not (proposals_value is Array):
		return timed
	for proposal_value in proposals_value:
		if not (proposal_value is Dictionary):
			continue
		var proposal: Dictionary = proposal_value.duplicate(true)
		proposal["timing"] = timing
		proposal["state_policy"] = "report_only"
		timed.append(proposal)
	return timed

static func _turn_transcript_target_assignment_records(before_snapshot: Dictionary, after_snapshot: Dictionary) -> Array:
	var before_map := _turn_transcript_raid_map(before_snapshot.get("active_raids", []))
	var records := []
	for after_raid_value in after_snapshot.get("active_raids", []):
		if not (after_raid_value is Dictionary):
			continue
		var after_raid: Dictionary = after_raid_value
		var placement_id := String(after_raid.get("placement_id", ""))
		var before_raid: Dictionary = before_map.get(placement_id, {})
		var previous_signature := String(before_raid.get("target_signature", ""))
		var current_signature := String(after_raid.get("target_signature", ""))
		if current_signature == "" or previous_signature == current_signature:
			continue
		var event_ref_id := _turn_transcript_event_ref_id(
			int(after_snapshot.get("day", 0)),
			String(after_snapshot.get("faction_id", "")),
			"ai_target_assigned",
			placement_id,
			String(after_raid.get("target_id", ""))
		)
		records.append(
			{
				"placement_id": placement_id,
				"roster_hero_id": String(after_raid.get("roster_hero_id", "")),
				"previous_target_signature": previous_signature,
				"current_target_signature": current_signature,
				"assignment_changed": true,
				"target_kind": String(after_raid.get("target_kind", "")),
				"target_id": String(after_raid.get("target_id", "")),
				"target_label": String(after_raid.get("target_label", "")),
				"target_x": int(after_raid.get("target_x", 0)),
				"target_y": int(after_raid.get("target_y", 0)),
				"reason_codes": _normalize_string_array(after_raid.get("reason_codes", [])),
				"public_reason": String(after_raid.get("public_reason", "")),
				"event_ref_id": event_ref_id,
				"state_policy": "derived",
			}
		)
	return records

static func _turn_transcript_target_no_op_records(
	before_snapshot: Dictionary,
	before_proposals: Array,
	assignment_records: Array
) -> Array:
	var assigned_commanders := {}
	for record_value in assignment_records:
		if record_value is Dictionary:
			assigned_commanders[String(record_value.get("roster_hero_id", ""))] = true
	var raid_by_commander := _turn_transcript_raid_by_commander(before_snapshot.get("active_raids", []))
	var no_ops := []
	for proposal_value in before_proposals:
		if not (proposal_value is Dictionary):
			continue
		var proposal: Dictionary = proposal_value
		var roster_hero_id := String(proposal.get("roster_hero_id", ""))
		if roster_hero_id == "" or assigned_commanders.has(roster_hero_id):
			continue
		var role_status := String(proposal.get("role_status", ""))
		var role := String(proposal.get("role", ""))
		var no_op_reason := "no_active_commander"
		var raid: Dictionary = raid_by_commander.get(roster_hero_id, {})
		if role == COMMANDER_ROLE_RECOVERING and role_status == "cooldown":
			no_op_reason = "commander_recovering"
		elif role == COMMANDER_ROLE_RECOVERING and role_status == "rebuilding":
			no_op_reason = "commander_rebuilding"
		elif String(proposal.get("validity", "")) == "invalid_target_missing":
			no_op_reason = "no_valid_target"
		elif not raid.is_empty():
			no_op_reason = "target_unchanged"
		no_ops.append(
			{
				"placement_id": String(raid.get("placement_id", "")),
				"roster_hero_id": roster_hero_id,
				"target_kind": String(proposal.get("target_kind", "")),
				"target_id": String(proposal.get("target_id", "")),
				"target_label": String(proposal.get("target_label", "")),
				"no_op_reason": no_op_reason,
				"public_reason": String(proposal.get("public_reason", "")),
				"reason_codes": _normalize_string_array(proposal.get("priority_reason_codes", [])),
				"state_policy": "derived",
			}
		)
	return no_ops

static func _turn_transcript_raid_movement_summary(before_snapshot: Dictionary, after_snapshot: Dictionary) -> Array:
	var before_map := _turn_transcript_raid_map(before_snapshot.get("active_raids", []))
	var movements := []
	for after_raid_value in after_snapshot.get("active_raids", []):
		if not (after_raid_value is Dictionary):
			continue
		var after_raid: Dictionary = after_raid_value
		var placement_id := String(after_raid.get("placement_id", ""))
		var before_raid: Dictionary = before_map.get(placement_id, {})
		if before_raid.is_empty():
			continue
		var moved := int(before_raid.get("x", 0)) != int(after_raid.get("x", 0)) or int(before_raid.get("y", 0)) != int(after_raid.get("y", 0))
		if not moved and String(after_raid.get("target_signature", "")) == "":
			continue
		movements.append(
			{
				"placement_id": placement_id,
				"roster_hero_id": String(after_raid.get("roster_hero_id", "")),
				"from": {"x": int(before_raid.get("x", 0)), "y": int(before_raid.get("y", 0))},
				"to": {"x": int(after_raid.get("x", 0)), "y": int(after_raid.get("y", 0))},
				"target_kind": String(after_raid.get("target_kind", "")),
				"target_id": String(after_raid.get("target_id", "")),
				"target_label": String(after_raid.get("target_label", "")),
				"goal_distance_before": int(before_raid.get("goal_distance", 9999)),
				"goal_distance_after": int(after_raid.get("goal_distance", 9999)),
				"arrived_before": bool(before_raid.get("arrived", false)),
				"arrived_after": bool(after_raid.get("arrived", false)),
				"movement_policy": "existing_advance_raids",
				"state_policy": "derived",
			}
		)
	return movements

static func _turn_transcript_raid_arrival_summary(before_snapshot: Dictionary, after_snapshot: Dictionary) -> Array:
	var before_map := _turn_transcript_raid_map(before_snapshot.get("active_raids", []))
	var before_controllers: Dictionary = before_snapshot.get("resource_controllers", {})
	var after_controllers: Dictionary = after_snapshot.get("resource_controllers", {})
	var arrivals := []
	for after_raid_value in after_snapshot.get("active_raids", []):
		if not (after_raid_value is Dictionary):
			continue
		var after_raid: Dictionary = after_raid_value
		var placement_id := String(after_raid.get("placement_id", ""))
		var before_raid: Dictionary = before_map.get(placement_id, {})
		if before_raid.is_empty() or not bool(after_raid.get("arrived", false)):
			continue
		var target_kind := String(after_raid.get("target_kind", ""))
		var target_id := String(after_raid.get("target_id", ""))
		var controller_before := ""
		var controller_after := ""
		if target_kind == "resource":
			controller_before = String(before_controllers.get(target_id, {}).get("controller_id", ""))
			controller_after = String(after_controllers.get(target_id, {}).get("controller_id", ""))
		if bool(before_raid.get("arrived", false)) and controller_before == controller_after:
			continue
		var event_type := "ai_raid_arrived"
		if target_kind == "resource" and controller_before != controller_after and controller_after == String(after_snapshot.get("faction_id", "")):
			event_type = "ai_site_seized"
		elif target_kind == "encounter":
			event_type = "ai_site_contested"
		var event_ref_id := _turn_transcript_event_ref_id(
			int(after_snapshot.get("day", 0)),
			String(after_snapshot.get("faction_id", "")),
			event_type,
			placement_id,
			target_id
		)
		arrivals.append(
			{
				"placement_id": placement_id,
				"roster_hero_id": String(after_raid.get("roster_hero_id", "")),
				"event_type": event_type,
				"event_ref_id": event_ref_id,
				"target_kind": target_kind,
				"target_id": target_id,
				"target_label": String(after_raid.get("target_label", "")),
				"target_controller_before": controller_before,
				"target_controller_after": controller_after,
				"site_event_ref_ids": [event_ref_id] if event_type in ["ai_site_seized", "ai_site_contested"] else [],
				"battle_queue_ref_ids": [],
				"pillage_message_ref_ids": [],
				"state_policy": "derived",
			}
		)
	return arrivals

static func _turn_transcript_phase_records(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	assignment_records: Array,
	movement_summary: Array,
	arrival_summary: Array,
	town_refs: Array
) -> Array:
	var phase_ids := [
		"normalize_enemy_states",
		"town_income_and_governor_projection",
		"town_build_recruit_reinforce",
		"pressure_gain",
		"advance_existing_raids",
		"battle_queue_checks",
		"spawn_raid_if_ready",
		"siege_and_posture",
		"turn_summary",
	]
	var phases := []
	for phase_id in phase_ids:
		var event_ref_ids := []
		var no_op_reason := ""
		match String(phase_id):
			"town_income_and_governor_projection", "town_build_recruit_reinforce":
				for ref_value in town_refs:
					if ref_value is Dictionary:
						event_ref_ids.append(String(ref_value.get("event_ref_id", "")))
				if event_ref_ids.is_empty():
					no_op_reason = "town_governor_only_turn"
			"advance_existing_raids":
				for record in assignment_records:
					event_ref_ids.append(String(record.get("event_ref_id", "")))
				for arrival in arrival_summary:
					event_ref_ids.append(String(arrival.get("event_ref_id", "")))
				if movement_summary.is_empty() and arrival_summary.is_empty():
					no_op_reason = "no_existing_raid_to_move"
			"spawn_raid_if_ready":
				if _turn_transcript_active_raid_count_delta(before_snapshot, after_snapshot) <= 0:
					no_op_reason = "pressure_below_launch_threshold"
			_:
				pass
		phases.append(
			{
				"phase_id": String(phase_id),
				"source_policy": "snapshot_derived",
				"faction_id": String(after_snapshot.get("faction_id", before_snapshot.get("faction_id", ""))),
				"before_counts": before_snapshot.get("enemy_state", {}),
				"after_counts": after_snapshot.get("enemy_state", {}),
				"event_ref_ids": _turn_transcript_non_empty_strings(event_ref_ids),
				"no_op_reason": no_op_reason,
			}
		)
	return phases

static func _turn_transcript_public_events(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	before_proposals: Array,
	assignment_records: Array,
	movement_summary: Array,
	arrival_summary: Array,
	town_refs: Array,
	phase_records: Array
) -> Array:
	var events := []
	var sequence := 1
	var faction_id := String(after_snapshot.get("faction_id", before_snapshot.get("faction_id", "")))
	var faction_label := String(after_snapshot.get("faction_label", before_snapshot.get("faction_label", faction_id)))
	var day := int(after_snapshot.get("day", before_snapshot.get("day", 0)))
	for proposal_value in before_proposals:
		if not (proposal_value is Dictionary):
			continue
		var proposal: Dictionary = proposal_value
		events.append(_turn_transcript_public_event(
			day,
			sequence,
			"ai_commander_role_observed",
			faction_id,
			faction_label,
			String(proposal.get("roster_hero_id", "")),
			String(proposal.get("commander_label", "")),
			String(proposal.get("target_kind", "")),
			String(proposal.get("target_id", "")),
			String(proposal.get("target_label", "")),
			int(proposal.get("target_x", 0)),
			int(proposal.get("target_y", 0)),
			"%s observed as %s for %s." % [
				String(proposal.get("commander_label", proposal.get("roster_hero_id", ""))),
				String(proposal.get("role", COMMANDER_ROLE_RESERVE)),
				String(proposal.get("target_label", proposal.get("target_id", "the front"))),
			],
			_normalize_string_array(proposal.get("priority_reason_codes", [])),
			String(proposal.get("public_reason", "")),
			"derived commander role",
			"medium",
			String(proposal.get("front_id", ""))
		))
		sequence += 1
	for record_value in assignment_records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		events.append(_turn_transcript_public_event(
			day,
			sequence,
			"ai_target_assigned",
			faction_id,
			faction_label,
			String(record.get("placement_id", "")),
			String(record.get("roster_hero_id", record.get("placement_id", ""))),
			String(record.get("target_kind", "")),
			String(record.get("target_id", "")),
			String(record.get("target_label", "")),
			int(record.get("target_x", 0)),
			int(record.get("target_y", 0)),
			"%s targets %s." % [String(record.get("roster_hero_id", "Raid host")), String(record.get("target_label", "the front"))],
			_normalize_string_array(record.get("reason_codes", [])),
			String(record.get("public_reason", "")),
			"existing target assignment",
			"high"
		))
		sequence += 1
	for movement_value in movement_summary:
		if not (movement_value is Dictionary):
			continue
		var movement: Dictionary = movement_value
		var event := _turn_transcript_public_event(
			day,
			sequence,
			"ai_raid_moved",
			faction_id,
			faction_label,
			String(movement.get("placement_id", "")),
			String(movement.get("roster_hero_id", movement.get("placement_id", ""))),
			String(movement.get("target_kind", "")),
			String(movement.get("target_id", "")),
			String(movement.get("target_label", "")),
			0,
			0,
			"%s moves toward %s." % [String(movement.get("roster_hero_id", "Raid host")), String(movement.get("target_label", "the front"))],
			[],
			"",
			"existing raid movement",
			"medium"
		)
		var from_pos: Dictionary = movement.get("from", {})
		var to_pos: Dictionary = movement.get("to", {})
		event["from_x"] = int(from_pos.get("x", 0))
		event["from_y"] = int(from_pos.get("y", 0))
		event["to_x"] = int(to_pos.get("x", 0))
		event["to_y"] = int(to_pos.get("y", 0))
		events.append(event)
		sequence += 1
	for arrival_value in arrival_summary:
		if not (arrival_value is Dictionary):
			continue
		var arrival: Dictionary = arrival_value
		events.append(_turn_transcript_public_event(
			day,
			sequence,
			String(arrival.get("event_type", "ai_raid_arrived")),
			faction_id,
			faction_label,
			String(arrival.get("placement_id", "")),
			String(arrival.get("roster_hero_id", arrival.get("placement_id", ""))),
			String(arrival.get("target_kind", "")),
			String(arrival.get("target_id", "")),
			String(arrival.get("target_label", "")),
			0,
			0,
			"%s reaches %s." % [String(arrival.get("roster_hero_id", "Raid host")), String(arrival.get("target_label", "the front"))],
			["site_seized"] if String(arrival.get("event_type", "")) == "ai_site_seized" else [],
			"site seized" if String(arrival.get("event_type", "")) == "ai_site_seized" else "",
			"existing raid arrival",
			"high"
		))
		sequence += 1
	for ref_value in town_refs:
		if not (ref_value is Dictionary):
			continue
		var ref: Dictionary = ref_value
		events.append(_turn_transcript_public_event(
			day,
			sequence,
			"ai_town_governor_support_ref",
			faction_id,
			faction_label,
			String(ref.get("town_placement_id", "")),
			String(ref.get("town_placement_id", "")),
			String(ref.get("target_kind", "")),
			String(ref.get("target_id", "")),
			String(ref.get("target_label", "")),
			0,
			0,
			"Town governor support noted for %s." % String(ref.get("target_label", ref.get("target_id", "the front"))),
			_normalize_string_array(ref.get("reason_codes", [])),
			String(ref.get("public_reason", "")),
			"supporting town governor event",
			"medium",
			String(ref.get("supports_front_id", ""))
		))
		sequence += 1
	events.append(_turn_transcript_public_event(
		day,
		sequence,
		"ai_turn_phase_summary",
		faction_id,
		faction_label,
		faction_id,
		faction_label,
		"front",
		String(options_get_case_front_id(before_proposals)),
		"enemy turn",
		0,
		0,
		"%s enemy turn summarized in %d phases." % [faction_label, phase_records.size()],
		[],
		"",
		"snapshot phase summary",
		"low",
		"turn_summary"
	))
	return events

static func _turn_transcript_public_event(
	day: int,
	sequence: int,
	event_type: String,
	faction_id: String,
	faction_label: String,
	actor_id: String,
	actor_label: String,
	target_kind: String,
	target_id: String,
	target_label: String,
	target_x: int,
	target_y: int,
	summary: String,
	reason_codes: Array,
	public_reason: String,
	debug_reason: String,
	public_importance: String = "medium",
	phase_id: String = ""
) -> Dictionary:
	return {
		"event_id": "%d:%s:%s:%s:%s:%d" % [day, faction_id, event_type, actor_id, target_id, sequence],
		"day": day,
		"sequence": sequence,
		"event_type": event_type,
		"phase_id": phase_id,
		"faction_id": faction_id,
		"faction_label": faction_label,
		"actor_id": actor_id,
		"actor_label": actor_label if actor_label != "" else actor_id,
		"target_kind": target_kind,
		"target_id": target_id,
		"target_label": target_label if target_label != "" else target_id,
		"target_x": target_x,
		"target_y": target_y,
		"visibility": "hidden_debug",
		"public_importance": public_importance,
		"summary": summary,
		"reason_codes": _normalize_string_array(reason_codes),
		"public_reason": public_reason,
		"debug_reason": debug_reason,
		"state_policy": "derived",
	}

static func _turn_transcript_source_marker_check(values: Array) -> Dictionary:
	var stack := values.duplicate(true)
	var checked := 0
	while not stack.is_empty():
		var value = stack.pop_back()
		if value is Array:
			for item in value:
				stack.append(item)
			continue
		if not (value is Dictionary):
			continue
		if value.has("phase_id") or value.has("event_type") or value.has("role") or value.has("placement_id") or value.has("event_ref_id") or value.has("roster_hero_id"):
			checked += 1
			if not (
				String(value.get("state_policy", "")) in ["derived", "report_only"]
				or String(value.get("source_policy", "")) == "snapshot_derived"
				or String(value.get("schema_status", "")) == "report_fixture_only"
			):
				return {"ok": false, "error": "transcript record missing derived/report-only source marker: %s" % JSON.stringify(value)}
		for nested_key in value.keys():
			var nested = value[nested_key]
			if nested is Array or nested is Dictionary:
				stack.append(nested)
	return {"ok": true, "checked_records": checked}

static func _turn_transcript_no_ops_valid(no_ops: Array) -> bool:
	for record_value in no_ops:
		if not (record_value is Dictionary):
			return false
		if String(record_value.get("no_op_reason", "")) not in COMMANDER_ROLE_TURN_NO_OP_REASONS:
			return false
	return true

static func _turn_transcript_raid_map(raids_value: Variant) -> Dictionary:
	var output := {}
	if not (raids_value is Array):
		return output
	for raid_value in raids_value:
		if raid_value is Dictionary:
			output[String(raid_value.get("placement_id", ""))] = raid_value
	return output

static func _turn_transcript_raid_by_commander(raids_value: Variant) -> Dictionary:
	var output := {}
	if not (raids_value is Array):
		return output
	for raid_value in raids_value:
		if raid_value is Dictionary:
			output[String(raid_value.get("roster_hero_id", ""))] = raid_value
	return output

static func _turn_transcript_merge_town_refs(before_refs_value: Variant, after_refs_value: Variant) -> Array:
	var output := []
	var seen := {}
	for source in [before_refs_value, after_refs_value]:
		if not (source is Array):
			continue
		for ref_value in source:
			if not (ref_value is Dictionary):
				continue
			var ref_id := String(ref_value.get("event_ref_id", ""))
			if ref_id == "" or seen.has(ref_id):
				continue
			seen[ref_id] = true
			output.append(ref_value)
	return output

static func _turn_transcript_non_empty_strings(values: Array) -> Array:
	var output := []
	for value in values:
		var text := String(value)
		if text != "" and text not in output:
			output.append(text)
	return output

static func _turn_transcript_active_raid_count_delta(before_snapshot: Dictionary, after_snapshot: Dictionary) -> int:
	return int(after_snapshot.get("active_raids", []).size()) - int(before_snapshot.get("active_raids", []).size())

static func _turn_transcript_event_ref_id(day: int, faction_id: String, event_type: String, actor_id: String, target_id: String) -> String:
	return "%d:%s:%s:%s:%s" % [day, faction_id, event_type, actor_id, target_id]

static func options_get_case_front_id(proposals: Array) -> String:
	for proposal_value in proposals:
		if proposal_value is Dictionary and String(proposal_value.get("front_id", "")) != "":
			return String(proposal_value.get("front_id", ""))
	return "turn_summary"

static func _commander_role_assignment_id_hint(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	roster_hero_id: String,
	role: String,
	target_kind: String,
	target_id: String
) -> String:
	if session == null or faction_id == "" or roster_hero_id == "" or role == "" or target_kind == "" or target_id == "":
		return ""
	return "role:%s:%s:%s:%s:%s:%s:day_%d" % [
		String(session.scenario_id),
		faction_id,
		roster_hero_id,
		role,
		target_kind,
		target_id,
		int(session.day),
	]

static func _commander_role_expected_transition(role: String) -> String:
	match role:
		COMMANDER_ROLE_DEFENDER:
			return "hold_front_or_intercept"
		COMMANDER_ROLE_STABILIZER:
			return "support_front_stabilization"
		COMMANDER_ROLE_RECOVERING:
			return "wait_until_recovery_day"
		COMMANDER_ROLE_RESERVE:
			return "wait_for_target"
		_:
			return "spawn_or_link_raid"

static func _default_reason_codes_for_target(target_kind: String, target_id: String, target: Dictionary = {}) -> Array:
	match target_kind:
		"town":
			var codes := ["town_siege"]
			if bool(target.get("objective_anchor", true)) or target_id == "riverwatch_hold":
				codes.append("objective_front")
			return codes
		"resource":
			return ["route_pressure"]
		"encounter":
			return ["site_contested", "objective_front"]
		_:
			return []

static func _default_public_importance(target_kind: String, reason_codes: Array) -> String:
	if target_kind == "town" or "town_siege" in reason_codes:
		return "critical"
	if "persistent_income_denial" in reason_codes or "recruit_denial" in reason_codes or "objective_front" in reason_codes:
		return "high"
	if "site_seized" in reason_codes or "site_contested" in reason_codes:
		return "medium"
	return "low"

static func _event_visibility(session: SessionStateStoreScript.SessionData, x: int, y: int, public_importance: String) -> String:
	if OverworldRulesScript.is_tile_visible(session, x, y):
		return "visible"
	if OverworldRulesScript.is_tile_explored(session, x, y):
		return "scouted"
	if public_importance in ["critical", "high"]:
		return "rumored"
	return "hidden_debug"

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
		"ai_pressure_summary":
			return "%s pressure centers on %s%s." % [faction_label, target_label, reason_suffix]
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

static func _resource_payload_summary(payload: Variant) -> String:
	if not (payload is Dictionary):
		return "site value"
	var parts := []
	for key in ["gold", "wood", "ore", "experience"]:
		var amount: int = max(0, int(payload.get(key, 0)))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	if parts.is_empty():
		return "site value"
	return ", ".join(parts)

static func _linked_player_town_bonus(session: SessionStateStoreScript.SessionData, node: Dictionary) -> int:
	var linked_town = {}
	var best_distance = 9999
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		var logistics: Dictionary = OverworldRulesScript.town_logistics_state(session, town)
		var distance: int = abs(int(node.get("x", 0)) - int(town.get("x", 0))) + abs(int(node.get("y", 0)) - int(town.get("y", 0)))
		if distance > int(logistics.get("support_radius", 0)):
			continue
		if distance < best_distance:
			best_distance = distance
			linked_town = town
	if linked_town.is_empty():
		return 0
	var bonus = 0
	match OverworldRulesScript.town_strategic_role(linked_town):
		"capital":
			bonus += 35
		"stronghold":
			bonus += 18
	var recovery: Dictionary = OverworldRulesScript.town_recovery_state(session, linked_town)
	bonus += int(recovery.get("pressure", 0)) * 8
	var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(linked_town, session)
	if bool(capital_project.get("active", false)):
		bonus += 18
	if bool(capital_project.get("vulnerable", false)):
		bonus += 22
	return bonus

static func _artifact_target_priority(session: SessionStateStoreScript.SessionData, node: Variant) -> int:
	if not (node is Dictionary) or bool(node.get("collected", false)):
		return 0
	var artifact = ContentService.get_artifact(String(node.get("artifact_id", "")))
	var bonuses = artifact.get("bonuses", {})
	var priority = 105
	priority += max(0, int(bonuses.get("overworld_movement", 0))) * 20
	priority += max(0, int(bonuses.get("scouting_radius", 0))) * 18
	priority += max(0, int(bonuses.get("battle_attack", 0))) * 15
	priority += max(0, int(bonuses.get("battle_defense", 0))) * 15
	priority += max(0, int(bonuses.get("battle_initiative", 0))) * 16
	priority += int(min(50, _target_resource_value(bonuses.get("daily_income", {})) / 80))
	priority += _objective_proximity_bonus(session, int(node.get("x", 0)), int(node.get("y", 0)))
	return priority

static func _encounter_target_priority(session: SessionStateStoreScript.SessionData, encounter: Variant) -> int:
	if not (encounter is Dictionary):
		return 0
	if String(encounter.get("spawned_by_faction_id", "")) != "" or OverworldRulesScript.is_encounter_resolved(session, encounter):
		return 0
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var priority = 95 + int(min(80, _target_resource_value(encounter_template.get("rewards", {})) / 130))
	if _encounter_is_objective_anchor(session, encounter):
		priority += 70
	priority += _objective_proximity_bonus(session, int(encounter.get("x", 0)), int(encounter.get("y", 0)))
	return priority

static func _target_resource_value(rewards: Variant) -> int:
	if not (rewards is Dictionary):
		return 0
	return max(0, int(rewards.get("gold", 0))) + (max(0, int(rewards.get("wood", 0))) * 350) + (max(0, int(rewards.get("ore", 0))) * 350) + max(0, int(rewards.get("experience", 0)))

static func _objective_proximity_bonus(session: SessionStateStoreScript.SessionData, x: int, y: int) -> int:
	var best_distance = 9999
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary):
			continue
		var placement_id = String(town.get("placement_id", ""))
		if placement_id == "" or not _town_is_objective_anchor(session, placement_id):
			continue
		var distance: int = abs(x - int(town.get("x", 0))) + abs(y - int(town.get("y", 0)))
		if distance < best_distance:
			best_distance = distance
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if not _encounter_is_objective_anchor(session, encounter):
			continue
		var distance: int = abs(x - int(encounter.get("x", 0))) + abs(y - int(encounter.get("y", 0)))
		if distance < best_distance:
			best_distance = distance
	if best_distance == 9999:
		return 0
	if best_distance <= 1:
		return 45
	if best_distance <= 3:
		return 25
	if best_distance <= 5:
		return 10
	return 0

static func _assignment_penalty(session: SessionStateStoreScript.SessionData, target_kind: String, placement_id: String) -> int:
	if placement_id == "":
		return 0
	var penalty = 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not _is_active_raid(encounter, "", resolved_encounters):
			continue
		if String(encounter.get("target_kind", "")) != target_kind:
			continue
		if String(encounter.get("target_placement_id", "")) != placement_id:
			continue
		penalty += 90 if bool(encounter.get("arrived", false)) else 45
	return penalty

static func _town_started_enemy(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var scenario = ContentService.get_scenario(session.scenario_id)
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return String(town.get("owner", "neutral")) == "enemy"
	return false

static func _town_is_objective_anchor(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	var scenario = ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return false
	for bucket in ["victory", "defeat"]:
		for objective in objectives.get(bucket, []):
			if objective is Dictionary and String(objective.get("placement_id", "")) == placement_id:
				return true
	return false

static func _encounter_is_objective_anchor(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", ""))))
	var victory_flags: Array = encounter_template.get("victory_flags", [])
	if not (victory_flags is Array) or victory_flags.is_empty():
		return false
	var scenario = ContentService.get_scenario(session.scenario_id)
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return false
	for bucket in ["victory", "defeat"]:
		for objective in objectives.get(bucket, []):
			if not (objective is Dictionary):
				continue
			if String(objective.get("type", "")) != "flag_true":
				continue
			if String(objective.get("flag", "")) in victory_flags:
				return true
	return false

static func _best_goal_tile(session: SessionStateStoreScript.SessionData, origin_pos: Vector2i, goal_tiles: Array) -> Vector2i:
	if goal_tiles.is_empty():
		return origin_pos
	var best_tile: Vector2i = goal_tiles[0]
	var best_distance = _path_distance(session, origin_pos, goal_tiles, "")
	for tile in goal_tiles:
		if not (tile is Vector2i):
			continue
		var distance = _path_distance(session, origin_pos, [tile], "")
		if distance < best_distance:
			best_distance = distance
			best_tile = tile
	return best_tile

static func _resolve_arrived_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	match String(raid.get("target_kind", "")):
		"resource":
			return _secure_resource_target(session, raid, state, faction_id)
		"artifact":
			return _secure_artifact_target(session, raid, state, faction_id)
		"encounter":
			return _contest_encounter_target(session, raid, state, faction_id)
		_:
			return {"encounter": raid, "state": state, "event_message": ""}

static func _secure_resource_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var node_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
	var node = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0:
		return {"encounter": raid, "state": state, "event_message": ""}
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if not _resource_node_contestable_by_faction(node, site, faction_id):
		return {"encounter": raid, "state": state, "event_message": ""}
	var nodes = session.overworld.get("resource_nodes", [])
	var previous_node: Dictionary = node.duplicate(true)
	var previous_controller = String(node.get("collected_by_faction_id", ""))
	var escorted_route = int(previous_node.get("response_until_day", 0)) >= session.day
	var escort_strength: int = max(0, int(previous_node.get("response_security_rating", 0)))
	var delivery_value := _recruit_payload_value(previous_node.get("delivery_manifest", {}))
	var delivery_target_label := String(previous_node.get("delivery_target_label", "the front"))
	if delivery_target_label == "":
		delivery_target_label = "the front"
	node["collected"] = true
	node["collected_by_faction_id"] = faction_id
	node["collected_day"] = session.day
	node["response_origin"] = ""
	node["response_source_town_id"] = ""
	node["response_last_day"] = 0
	node["response_until_day"] = 0
	node["response_commander_id"] = ""
	node["response_security_rating"] = 0
	node["delivery_controller_id"] = ""
	node["delivery_origin_town_id"] = ""
	node["delivery_target_kind"] = ""
	node["delivery_target_id"] = ""
	node["delivery_target_label"] = ""
	node["delivery_arrival_day"] = 0
	node["delivery_manifest"] = {}
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["resource_nodes"] = nodes

	var spoils = _reward_resources_for_empire(_resource_site_claim_rewards(site))
	state["treasury"] = _merge_resources(state.get("treasury", {}), spoils)
	state["pressure"] = max(0, int(state.get("pressure", 0))) + _resource_site_pressure_value(site)
	if escorted_route:
		state["pressure"] += max(1, escort_strength)
	if delivery_value > 0:
		state["pressure"] = max(0, int(state.get("pressure", 0))) + clamp(int(ceili(float(delivery_value) / 220.0)), 1, 3)
	var message = "%s seizes %s." % [_raid_name(raid), String(site.get("name", "the site"))]
	if not spoils.is_empty():
		message = "%s seizes %s and strips %s." % [
			_raid_name(raid),
			String(site.get("name", "the site")),
			_describe_resource_set(spoils),
		]
	if delivery_value > 0:
		message = "%s The convoy bound for %s is scattered." % [message.trim_suffix("."), delivery_target_label]
	elif escorted_route:
		message = "%s seizes %s and breaks its escorted logistics route." % [
			_raid_name(raid),
			String(site.get("name", "the site")),
		]
	elif _resource_site_is_persistent(site):
		message = "%s seizes %s and denies its logistics route." % [
			_raid_name(raid),
			String(site.get("name", "the site")),
		]
	var disruption_message: String = OverworldRulesScript.apply_resource_site_disruption(
		session,
		previous_node,
		site,
		previous_controller,
		faction_id
	)
	if disruption_message != "":
		message = "%s %s" % [message, disruption_message]
	var seized_codes := ["site_seized"]
	seized_codes.append_array(
		_resource_target_reason_codes(
			site,
			previous_controller == "player",
			_resource_site_is_persistent(site),
			_target_resource_value(site.get("control_income", {})),
			_recruit_payload_value(site.get("claim_recruits", {})) + _recruit_payload_value(site.get("weekly_recruits", {})),
			_resource_route_pressure_value(site),
			_linked_player_town_bonus(session, previous_node)
		)
	)
	var event := build_ai_event_record(
		session,
		{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
		"ai_site_seized",
		raid,
		{
			"target_kind": "resource",
			"target_placement_id": String(raid.get("target_placement_id", "")),
			"target_label": String(site.get("name", "the site")),
			"target_x": int(node.get("x", 0)),
			"target_y": int(node.get("y", 0)),
			"target_reason_codes": seized_codes,
			"target_public_reason": _public_reason_from_codes(seized_codes),
			"target_public_importance": "high" if previous_controller == "player" or _resource_site_is_persistent(site) else "medium",
			"target_debug_reason": String(raid.get("target_debug_reason", "")),
		},
		{
			"summary": message,
			"state_policy": "durable_state_reference",
		}
	)
	return {"encounter": raid, "state": state, "event_message": message, "ai_event": event}

static func _secure_artifact_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var node_result = _find_artifact_by_placement(session, String(raid.get("target_placement_id", "")))
	var node = node_result.get("node", {})
	if int(node_result.get("index", -1)) < 0 or bool(node.get("collected", false)):
		return {"encounter": raid, "state": state, "event_message": ""}
	var nodes = session.overworld.get("artifact_nodes", [])
	node["collected"] = true
	node["collected_by_faction_id"] = faction_id
	node["collected_day"] = session.day
	nodes[int(node_result.get("index", -1))] = node
	session.overworld["artifact_nodes"] = nodes

	var captured_artifacts = []
	if state.get("captured_artifact_ids", []) is Array:
		for artifact_id_value in state.get("captured_artifact_ids", []):
			var artifact_id = String(artifact_id_value)
			if artifact_id != "" and artifact_id not in captured_artifacts:
				captured_artifacts.append(artifact_id)
	var claimed_artifact_id = String(node.get("artifact_id", ""))
	if claimed_artifact_id != "" and claimed_artifact_id not in captured_artifacts:
		captured_artifacts.append(claimed_artifact_id)
	state["captured_artifact_ids"] = captured_artifacts
	state["pressure"] = max(0, int(state.get("pressure", 0))) + _artifact_pressure_value(claimed_artifact_id)
	return {
		"encounter": raid,
		"state": state,
		"event_message": "%s secures %s for the warhost." % [
			_raid_name(raid),
			ArtifactRulesScript.describe_artifact(claimed_artifact_id),
		],
	}

static func _contest_encounter_target(
	session: SessionStateStoreScript.SessionData,
	raid: Dictionary,
	state: Dictionary,
	faction_id: String
) -> Dictionary:
	var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
	var encounter_state = encounter_result.get("encounter", {})
	if int(encounter_result.get("index", -1)) < 0 or OverworldRulesScript.is_encounter_resolved(session, encounter_state):
		return {"encounter": raid, "state": state, "event_message": ""}
	if _encounter_is_objective_anchor(session, encounter_state):
		var encounters = session.overworld.get("encounters", [])
		var claimed_now = String(encounter_state.get("contested_by_faction_id", "")) != faction_id
		encounter_state["contested_by_faction_id"] = faction_id
		encounter_state["contested_day"] = session.day
		encounters[int(encounter_result.get("index", -1))] = encounter_state
		session.overworld["encounters"] = encounters
		if claimed_now:
			state["pressure"] = max(0, int(state.get("pressure", 0))) + 1
			var contest_message := "%s locks down %s and turns it into a live front." % [
				_raid_name(raid),
				String(ContentService.get_encounter(String(encounter_state.get("encounter_id", encounter_state.get("id", "")))).get("name", "the outpost")),
			]
			var contest_event := build_ai_event_record(
				session,
				{"faction_id": faction_id, "label": String(ContentService.get_faction(faction_id).get("name", faction_id))},
				"ai_site_contested",
				raid,
				{
					"target_kind": "encounter",
					"target_placement_id": String(encounter_state.get("placement_id", "")),
					"target_label": String(ContentService.get_encounter(String(encounter_state.get("encounter_id", encounter_state.get("id", "")))).get("name", "the outpost")),
					"target_x": int(encounter_state.get("x", 0)),
					"target_y": int(encounter_state.get("y", 0)),
					"target_reason_codes": ["site_contested", "objective_front"],
					"target_public_reason": "objective front",
					"target_public_importance": "high",
					"target_debug_reason": "objective encounter contested",
				},
				{
					"summary": contest_message,
					"state_policy": "durable_state_reference",
				}
			)
			return {
				"encounter": raid,
				"state": state,
				"event_message": contest_message,
				"ai_event": contest_event,
			}
		return {"encounter": raid, "state": state, "event_message": ""}

	var resolved = session.overworld.get("resolved_encounters", [])
	var placement_id = String(encounter_state.get("placement_id", ""))
	if resolved is Array and placement_id not in resolved:
		resolved.append(placement_id)
		session.overworld["resolved_encounters"] = resolved
	var encounter_template = ContentService.get_encounter(String(encounter_state.get("encounter_id", encounter_state.get("id", ""))))
	var spoils = _reward_resources_for_empire(encounter_template.get("rewards", {}))
	state["treasury"] = _merge_resources(state.get("treasury", {}), spoils)
	state["pressure"] = max(0, int(state.get("pressure", 0))) + _pressure_from_rewards(encounter_template.get("rewards", {}))
	var message = "%s breaks %s." % [_raid_name(raid), String(encounter_template.get("name", "the frontier camp"))]
	if not spoils.is_empty():
		message = "%s breaks %s and absorbs %s." % [
			_raid_name(raid),
			String(encounter_template.get("name", "the frontier camp")),
			_describe_resource_set(spoils),
		]
	return {"encounter": raid, "state": state, "event_message": message}

static func _reward_resources_for_empire(rewards: Variant) -> Dictionary:
	var treasury = {}
	if not (rewards is Dictionary):
		return treasury
	for key in ["gold", "wood", "ore"]:
		var amount: int = max(0, int(rewards.get(key, 0)))
		if amount > 0:
			treasury[key] = amount
	return treasury

static func _pressure_from_rewards(rewards: Variant) -> int:
	if not (rewards is Dictionary):
		return 0
	var pressure = 0
	pressure += int(floor(float(_target_resource_value(_reward_resources_for_empire(rewards))) / 400.0))
	var experience: int = max(0, int(rewards.get("experience", 0)))
	if experience > 0:
		pressure += max(1, int(floor(float(experience) / 180.0)))
	return clamp(pressure, 0, 3)

static func _artifact_pressure_value(artifact_id: String) -> int:
	var artifact = ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return 0
	var bonuses = artifact.get("bonuses", {})
	var pressure = 1
	pressure += max(0, int(bonuses.get("overworld_movement", 0)))
	pressure += max(0, int(bonuses.get("scouting_radius", 0)))
	pressure += max(0, int(bonuses.get("battle_initiative", 0)))
	if max(0, int(bonuses.get("battle_attack", 0))) + max(0, int(bonuses.get("battle_defense", 0))) > 0:
		pressure += 1
	if _target_resource_value(bonuses.get("daily_income", {})) >= 300:
		pressure += 1
	return clamp(pressure, 1, 3)

static func _raid_name(raid: Dictionary) -> String:
	var encounter = ContentService.get_encounter(String(raid.get("encounter_id", raid.get("id", ""))))
	return String(encounter.get("name", "The raid"))

static func _goal_tiles_from_raid(session: SessionStateStoreScript.SessionData, raid: Dictionary) -> Array:
	match String(raid.get("target_kind", "")):
		"town":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0:
				return _town_staging_tiles(session, town_result.get("town", {}))
		"resource", "artifact":
			return [Vector2i(int(raid.get("target_x", int(raid.get("goal_x", 0)))), int(raid.get("target_y", int(raid.get("goal_y", 0)))))]
		"encounter":
			var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(encounter_result.get("index", -1)) >= 0:
				return _encounter_staging_tiles(session, encounter_result.get("encounter", {}))
		"hero":
			var hero_position := _hero_position_for_target(session, String(raid.get("target_placement_id", "")))
			return [hero_position]
	return [Vector2i(int(raid.get("goal_x", int(raid.get("x", 0)))), int(raid.get("goal_y", int(raid.get("y", 0)))))]

static func _next_step_toward(session: SessionStateStoreScript.SessionData, start: Vector2i, goal_tiles: Array, ignore_placement_id: String) -> Vector2i:
	if goal_tiles.is_empty():
		return start
	var blocked = _occupied_tiles(session, ignore_placement_id)
	var visited = {}
	var queue = [start]
	var parents = {}
	visited[_pos_key(start)] = true
	var found_key = ""

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current in goal_tiles:
			found_key = _pos_key(current)
			break

		for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + delta
			var key = _pos_key(next)
			if visited.has(key):
				continue
			if _position_blocked(session, next, goal_tiles, blocked):
				continue
			visited[key] = true
			parents[key] = current
			queue.append(next)

	if found_key == "":
		return start

	var cursor = _vector_from_key(found_key)
	while parents.has(_pos_key(cursor)) and parents[_pos_key(cursor)] != start:
		cursor = parents[_pos_key(cursor)]
	return cursor if cursor != start else start

static func _path_distance(session: SessionStateStoreScript.SessionData, start: Vector2i, goal_tiles: Array, ignore_placement_id: String) -> int:
	if goal_tiles.is_empty():
		return 9999
	if start in goal_tiles:
		return 0
	var blocked = _occupied_tiles(session, ignore_placement_id)
	var visited = {}
	var queue = [{"pos": start, "distance": 0}]
	visited[_pos_key(start)] = true

	while not queue.is_empty():
		var current = queue.pop_front()
		var pos: Vector2i = current["pos"]
		var distance = int(current["distance"])
		for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = pos + delta
			var key = _pos_key(next)
			if visited.has(key):
				continue
			if _position_blocked(session, next, goal_tiles, blocked):
				continue
			if next in goal_tiles:
				return distance + 1
			visited[key] = true
			queue.append({"pos": next, "distance": distance + 1})
	return 9999

static func _occupied_tiles(session: SessionStateStoreScript.SessionData, ignore_placement_id: String) -> Dictionary:
	var occupied = {}
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		var placement_id = String(encounter.get("placement_id", ""))
		if placement_id == ignore_placement_id:
			continue
		if resolved_encounters is Array and placement_id in resolved_encounters:
			continue
		occupied[_pos_key(Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0))))] = true
	return occupied

static func _position_blocked(session: SessionStateStoreScript.SessionData, pos: Vector2i, goal_tiles: Array, blocked: Dictionary) -> bool:
	var map_size: Vector2i = OverworldRulesScript.derive_map_size(session)
	if pos.x < 0 or pos.y < 0 or pos.x >= map_size.x or pos.y >= map_size.y:
		return true
	if pos in goal_tiles:
		return blocked.has(_pos_key(pos))
	if OverworldRulesScript.tile_is_blocked(session, pos.x, pos.y):
		return true
	return blocked.has(_pos_key(pos))

static func _refresh_target(session: SessionStateStoreScript.SessionData, raid: Dictionary) -> Dictionary:
	var origin = Vector2i(int(raid.get("x", 0)), int(raid.get("y", 0)))
	match String(raid.get("target_kind", "")):
		"town":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0:
				var town = town_result.get("town", {})
				var staging_tiles = _town_staging_tiles(session, town)
				var goal_tile = _best_goal_tile(session, origin, staging_tiles)
				raid["target_label"] = _town_name(town)
				raid["target_x"] = int(town.get("x", 0))
				raid["target_y"] = int(town.get("y", 0))
				raid["goal_x"] = goal_tile.x
				raid["goal_y"] = goal_tile.y
				raid["goal_distance"] = _path_distance(session, origin, staging_tiles, String(raid.get("placement_id", "")))
		"resource":
			var resource_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(resource_result.get("index", -1)) >= 0:
				var node = resource_result.get("node", {})
				raid["target_label"] = String(ContentService.get_resource_site(String(node.get("site_id", ""))).get("name", "Resource Site"))
				raid["target_x"] = int(node.get("x", 0))
				raid["target_y"] = int(node.get("y", 0))
				raid["goal_x"] = int(node.get("x", 0))
				raid["goal_y"] = int(node.get("y", 0))
				raid["goal_distance"] = _path_distance(session, origin, [Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))], String(raid.get("placement_id", "")))
		"artifact":
			var artifact_result = _find_artifact_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(artifact_result.get("index", -1)) >= 0:
				var node = artifact_result.get("node", {})
				raid["target_label"] = ArtifactRulesScript.describe_artifact(String(node.get("artifact_id", "")))
				raid["target_x"] = int(node.get("x", 0))
				raid["target_y"] = int(node.get("y", 0))
				raid["goal_x"] = int(node.get("x", 0))
				raid["goal_y"] = int(node.get("y", 0))
				raid["goal_distance"] = _path_distance(session, origin, [Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))], String(raid.get("placement_id", "")))
		"encounter":
			var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(encounter_result.get("index", -1)) >= 0:
				var placement = encounter_result.get("encounter", {})
				var staging_tiles = _encounter_staging_tiles(session, placement)
				var goal_tile = _best_goal_tile(session, origin, staging_tiles)
				raid["target_label"] = String(ContentService.get_encounter(String(placement.get("encounter_id", placement.get("id", "")))).get("name", "Frontier Camp"))
				raid["target_x"] = int(placement.get("x", 0))
				raid["target_y"] = int(placement.get("y", 0))
				raid["goal_x"] = goal_tile.x
				raid["goal_y"] = goal_tile.y
				raid["goal_distance"] = _path_distance(session, origin, staging_tiles, String(raid.get("placement_id", "")))
		"hero":
			var hero_target_id := String(raid.get("target_placement_id", ""))
			var hero_position := _hero_position_for_target(session, hero_target_id)
			raid["target_label"] = _hero_label_for_target(session, hero_target_id)
			raid["target_x"] = hero_position.x
			raid["target_y"] = hero_position.y
			raid["goal_x"] = hero_position.x
			raid["goal_y"] = hero_position.y
			raid["goal_distance"] = _path_distance(
				session,
				origin,
				[hero_position],
				String(raid.get("placement_id", ""))
			)
	if String(raid.get("delivery_intercept_node_placement_id", "")) != "":
		var delivery_context: Dictionary = OverworldRulesScript.delivery_interception_context_for_encounter(session, raid)
		if bool(delivery_context.get("active", false)):
			raid["delivery_intercept_target_kind"] = String(delivery_context.get("target_kind", ""))
			raid["delivery_intercept_target_id"] = String(delivery_context.get("target_id", ""))
			raid["delivery_intercept_label"] = String(delivery_context.get("route_label", raid.get("delivery_intercept_label", "")))
			raid["target_label"] = String(delivery_context.get("pressure_label", raid.get("target_label", "")))
	return raid

static func _raid_target_valid(session: SessionStateStoreScript.SessionData, raid: Dictionary) -> bool:
	var target_kind = String(raid.get("target_kind", ""))
	var valid := false
	match target_kind:
		"town":
			var town_result = _find_town_by_placement(session, String(raid.get("target_placement_id", "")))
			valid = int(town_result.get("index", -1)) >= 0 and String(town_result.get("town", {}).get("owner", "neutral")) == "player"
		"resource":
			var resource_result = _find_resource_by_placement(session, String(raid.get("target_placement_id", "")))
			if int(resource_result.get("index", -1)) < 0:
				return false
			var node: Dictionary = resource_result.get("node", {})
			var site = ContentService.get_resource_site(String(node.get("site_id", "")))
			valid = _resource_node_contestable_by_faction(node, site, String(raid.get("spawned_by_faction_id", "")))
		"artifact":
			var artifact_result = _find_artifact_by_placement(session, String(raid.get("target_placement_id", "")))
			valid = int(artifact_result.get("index", -1)) >= 0 and not bool(artifact_result.get("node", {}).get("collected", false))
		"encounter":
			var encounter_result = _find_encounter_by_placement(session, String(raid.get("target_placement_id", "")))
			valid = int(encounter_result.get("index", -1)) >= 0 and not OverworldRulesScript.is_encounter_resolved(session, encounter_result.get("encounter", {}))
		"hero":
			var hero_target_id := String(raid.get("target_placement_id", ""))
			valid = hero_target_id == "" or not _find_player_hero(session, hero_target_id).is_empty()
		_:
			return false
	if not valid:
		return false
	if String(raid.get("delivery_intercept_node_placement_id", "")) != "":
		return bool(OverworldRulesScript.delivery_interception_context_for_encounter(session, raid).get("active", false))
	return true

static func _is_active_raid(encounter: Variant, faction_id: String, resolved_encounters: Variant) -> bool:
	if not (encounter is Dictionary):
		return false
	var raid_faction = String(encounter.get("spawned_by_faction_id", ""))
	if faction_id == "":
		if raid_faction == "":
			return false
	elif raid_faction != faction_id:
		return false
	var placement_id = String(encounter.get("placement_id", ""))
	return not (resolved_encounters is Array and placement_id in resolved_encounters)

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for index in range(session.overworld.get("towns", []).size()):
		var town = session.overworld.get("towns", [])[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _find_resource_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for index in range(session.overworld.get("resource_nodes", []).size()):
		var node = session.overworld.get("resource_nodes", [])[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _resource_site_is_persistent(site: Dictionary) -> bool:
	return bool(site.get("persistent_control", false))

static func _resource_node_contestable_by_faction(node: Dictionary, site: Dictionary, faction_id: String) -> bool:
	if _resource_site_is_persistent(site):
		return String(node.get("collected_by_faction_id", "")) != faction_id
	return not bool(node.get("collected", false))

static func _resource_site_claim_rewards(site: Dictionary) -> Dictionary:
	var rewards = site.get("claim_rewards", site.get("rewards", {}))
	return rewards if rewards is Dictionary else {}

static func _resource_site_strategic_value(site: Dictionary) -> int:
	var value = _target_resource_value(_resource_site_claim_rewards(site))
	value += _target_resource_value(site.get("control_income", {})) / 2
	value += _recruit_payload_value(site.get("weekly_recruits", {}))
	value += _recruit_payload_value(site.get("claim_recruits", {}))
	value += max(0, int(site.get("vision_radius", 0))) * 140
	value += max(0, int(site.get("pressure_guard", 0))) * 160
	value += max(0, int(site.get("pressure_bonus", 0))) * 180
	value += _resource_site_support_value(site)
	if String(site.get("learn_spell_id", "")) != "":
		value += 220
	return value

static func _resource_site_pressure_value(site: Dictionary) -> int:
	var pressure = _pressure_from_rewards(_resource_site_claim_rewards(site))
	pressure += max(0, int(site.get("pressure_bonus", 0)))
	pressure += int(floor(float(_resource_site_support_value(site)) / 220.0))
	if max(0, int(site.get("vision_radius", 0))) > 0:
		pressure += 1
	if String(site.get("learn_spell_id", "")) != "":
		pressure += 1
	if site.get("weekly_recruits", {}) is Dictionary and not site.get("weekly_recruits", {}).is_empty():
		pressure += 1
	return clamp(pressure, 0, 4)

static func _resource_site_support_value(site: Dictionary) -> int:
	var support = site.get("town_support", {})
	if not (support is Dictionary):
		return 0
	var value = 0
	value += max(0, int(support.get("quality_bonus", 0))) * 85
	value += max(0, int(support.get("readiness_bonus", 0))) * 70
	value += max(0, int(support.get("pressure_bonus", 0))) * 120
	value += max(0, int(support.get("growth_bonus_percent", 0))) * 16
	value += max(0, int(support.get("recovery_relief", 0))) * 120
	value += max(0, int(support.get("disruption_pressure", 0))) * 90
	return value

static func _recruit_payload_value(recruits: Variant) -> int:
	var value = 0
	if not (recruits is Dictionary):
		return value
	for unit_id_value in recruits.keys():
		var unit_id = String(unit_id_value)
		var count: int = max(0, int(recruits[unit_id_value]))
		if unit_id == "" or count <= 0:
			continue
		var unit = ContentService.get_unit(unit_id)
		var tier: int = max(1, int(unit.get("tier", 1)))
		value += count * (120 + (tier * 60))
		if bool(unit.get("ranged", false)):
			value += count * 30
	return value

static func _default_enemy_strategy() -> Dictionary:
	return {
		"build_category_weights": {
			"civic": 1.0,
			"dwelling": 1.0,
			"economy": 1.0,
			"support": 1.0,
			"magic": 1.0,
		},
		"build_value_weights": {
			"income": 1.0,
			"growth": 1.0,
			"quality": 1.0,
			"readiness": 1.0,
			"pressure": 1.0,
		},
		"raid_target_weights": {
			"town": 1.0,
			"resource": 1.0,
			"artifact": 1.0,
			"encounter": 1.0,
			"hero": 1.0,
		},
		"site_family_weights": {
			"neutral_dwelling": 1.0,
			"faction_outpost": 1.0,
			"frontier_shrine": 1.0,
		},
		"reinforcement": {
			"garrison_bias": 1.0,
			"raid_bias": 1.0,
			"ranged_weight": 1.0,
			"melee_weight": 1.0,
			"low_tier_weight": 1.0,
			"high_tier_weight": 1.0,
		},
		"raid": {
			"threshold_scale": 1.0,
			"max_active_bonus": 0,
			"pressure_commitment_scale": 1.0,
			"objective_weight": 1.0,
			"town_siege_weight": 1.0,
			"site_denial_weight": 1.0,
			"hero_hunt_weight": 1.0,
		},
	}

static func _merge_strategy_dict(base: Dictionary, override: Dictionary) -> Dictionary:
	var merged = base.duplicate(true)
	for key in override.keys():
		var value = override[key]
		if value is Dictionary and merged.get(key, {}) is Dictionary:
			merged[String(key)] = _merge_strategy_dict(merged.get(key, {}), value)
		else:
			merged[String(key)] = value
	return merged

static func _find_artifact_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for index in range(session.overworld.get("artifact_nodes", []).size()):
		var node = session.overworld.get("artifact_nodes", [])[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

static func _find_encounter_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for index in range(session.overworld.get("encounters", []).size()):
		var encounter = session.overworld.get("encounters", [])[index]
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return {"index": index, "encounter": encounter}
	return {"index": -1, "encounter": {}}

static func _town_name(town_state: Dictionary) -> String:
	var town = ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("name", town_state.get("town_id", "Town")))

static func _describe_count_map(verb: String, counts: Dictionary) -> String:
	if counts.is_empty():
		return ""
	var parts = []
	var keys = counts.keys()
	keys.sort()
	for key in keys:
		var count = int(counts[key])
		parts.append("%d raid%s %s %s" % [count, "" if count == 1 else "s", verb, String(key)])
	return ", ".join(parts)

static func _merge_resources(base: Variant, delta: Variant) -> Dictionary:
	var merged = {}
	if base is Dictionary:
		for key in base.keys():
			merged[String(key)] = int(base[key])
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key = String(key)
			merged[resource_key] = int(merged.get(resource_key, 0)) + max(0, int(delta[key]))
	return merged

static func _remove_resources(session: SessionStateStoreScript.SessionData, losses: Variant) -> Dictionary:
	var actual = {}
	if not (losses is Dictionary) or losses.is_empty():
		return actual
	var resources = session.overworld.get("resources", {}).duplicate(true)
	for key in losses.keys():
		var resource_key = String(key)
		var available: int = max(0, int(resources.get(resource_key, 0)))
		var loss: int = min(available, max(0, int(losses[key])))
		if loss > 0:
			resources[resource_key] = available - loss
			actual[resource_key] = loss
	session.overworld["resources"] = resources
	return actual

static func _describe_resource_set(resources: Dictionary) -> String:
	var parts = []
	var keys = resources.keys()
	keys.sort()
	for key in keys:
		parts.append("%d %s" % [int(resources[key]), String(key)])
	return ", ".join(parts)

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
	var unit = ContentService.get_unit(unit_id)
	return max(
		6,
		int(unit.get("hp", 1))
		+ int(unit.get("min_damage", 1))
		+ int(unit.get("max_damage", 1))
		+ (3 if bool(unit.get("ranged", false)) else 0)
	)

static func _add_army_stack(stacks: Variant, unit_id: String, amount: int) -> Array:
	var normalized := []
	var added := false
	if stacks is Array:
		for stack_value in stacks:
			if not (stack_value is Dictionary):
				continue
			var stack := {
				"unit_id": String(stack_value.get("unit_id", "")),
				"count": max(0, int(stack_value.get("count", 0))),
			}
			if stack["unit_id"] == unit_id:
				stack["count"] = int(stack.get("count", 0)) + max(0, amount)
				added = true
			if stack["unit_id"] != "" and int(stack.get("count", 0)) > 0:
				normalized.append(stack)
	if not added and unit_id != "" and amount > 0:
		normalized.append({"unit_id": unit_id, "count": amount})
	return normalized

static func _scale_resources(payload: Variant, multiplier: int) -> Dictionary:
	var scaled = {}
	if not (payload is Dictionary) or multiplier <= 0:
		return scaled
	for key in payload.keys():
		scaled[String(key)] = max(0, int(payload[key])) * multiplier
	return scaled

static func _raid_is_public(session: SessionStateStoreScript.SessionData, encounter: Dictionary) -> bool:
	if session == null:
		return false
	if bool(encounter.get("arrived", false)):
		if String(encounter.get("target_kind", "")) == "town":
			var town_result = _find_town_by_placement(session, String(encounter.get("target_placement_id", "")))
			if int(town_result.get("index", -1)) >= 0 and String(town_result.get("town", {}).get("owner", "neutral")) == "player":
				return true
	if OverworldRulesScript.is_tile_visible(session, int(encounter.get("x", 0)), int(encounter.get("y", 0))):
		return true
	return false

static func _pos_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]

static func _vector_from_key(key: String) -> Vector2i:
	var parts = key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
