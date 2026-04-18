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

	for index in range(encounters.size()):
		var encounter = encounters[index]
		if not _is_active_raid(encounter, faction_id, resolved_encounters):
			continue

		encounter = ensure_raid_army(encounter, session)
		encounter = assign_target(session, config, encounter)
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
		var target_label = String(encounter.get("target_label", "the frontier"))
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
			_resource_target_priority(session, node, faction_id),
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
		}
	)

static func _append_resource_candidate(
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
	var seen_key = "resource:%s" % placement_id
	var site = ContentService.get_resource_site(String(node.get("site_id", "")))
	if placement_id == "" or seen.has(seen_key) or not _resource_node_contestable_by_faction(node, site, faction_id):
		return
	seen[seen_key] = true
	var goal_tile = Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
	var goal_distance = _path_distance(session, origin_pos, [goal_tile], "")
	if goal_distance >= 9999:
		return
	var site_family = String(site.get("family", ""))
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
			"priority": max(
				0,
				_weighted_priority(
					config,
					faction_id,
					"resource",
					placement_id,
					priority,
					site_family,
					false
				) - _assignment_penalty(session, "resource", placement_id)
			),
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
	return {"encounter": raid, "state": state, "event_message": message}

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
			return {
				"encounter": raid,
				"state": state,
				"event_message": "%s locks down %s and turns it into a live front." % [
					_raid_name(raid),
					String(ContentService.get_encounter(String(encounter_state.get("encounter_id", encounter_state.get("id", "")))).get("name", "the outpost")),
				],
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
